/**********************************************************************************************************************
* Name               : SalesOrderFollowupEmailBatch                                                         
* Created By         : Active Minds Middle East                                                      
* @author            : Raghu Gajjela
* @group             : 
* Created			 : 05 June 2025
* @last modified on  : 29-09-2025, 13-10-2025
* @last modified by  : Raghu Gajjela
******************************************************************************************************************/
global class SalesOrderFollowupEmailBatch implements Database.Batchable<SObject>, Database.Stateful,Database.AllowsCallouts {
    
    global Database.QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator([SELECT Id, CustomerAccount__c, CustomerAccount__r.IsPersonAccount, CustomerAccount__r.PersonEmail, 
                                         CustomerAccount__r.Name,Unit__r.Name,NextReminder__c,ReminderCount__c,Source_Entity__c,SalesAssociate__r.name,SPAStatus__c,
                                         ProjectName__c, Sales_Type__c FROM SalesOrder__c WHERE NextReminder__c = TODAY and Source_Entity__c != 'Modon - Egypt'
                                        AND Id NOT IN (SELECT SalesOrder__c FROM ServiceRequest__c WHERE RecordType.DeveloperName = 'Unit_Handover')]);
    }
    
    global void execute(Database.BatchableContext BC, List<SObject> scope) {
        List<SalesOrder__c> salesOrders = (List<SalesOrder__c>) scope;
        if (salesOrders.isEmpty()) return;
        
        Organization orgInfo = [SELECT IsSandbox FROM Organization LIMIT 1];
        Boolean isSandbox = orgInfo.IsSandbox;
        
        String followupMetadataKey = isSandbox ? '%SO_Followup_Sandbox' : 'xeboAPI_SO_Followup%';
        
        List<SendXiboConfig__mdt> metadataList = [SELECT MasterLabel, DeveloperName, ObjectName__c,End_Point_URL__c, API_Key__c, CollectionId__c, ProcessType__c
                                                  FROM SendXiboConfig__mdt WHERE ObjectName__c = 'SalesOrder' AND MasterLabel LIKE :followupMetadataKey ];
        
        if (metadataList.isEmpty()) {
            System.debug('No follow-up metadata found.');
            return;
        }
        
        SendXiboConfig__mdt metadata = metadataList[0];
        
        String jsonBody = getJsonBody(salesOrders);
        sendRequestToXiboApi.requestWrapper wrapperRequest = new sendRequestToXiboApi.requestWrapper(metadata, jsonBody, 'SalesOrder__c');
        HttpResponse res = sendRequestToXiboApi.sendRequest(wrapperRequest);
        processFollowupResponse(res, salesOrders, 'Salesorder_Completed_6_Months');
    }
    
    private String getJsonBody(List<SalesOrder__c> salesOrders) {
        List<WrapperClass.SalesOrderWrapper> wrapperList = new List<WrapperClass.SalesOrderWrapper>();
        Date closedDate = System.today();
        
        for (SalesOrder__c so : salesOrders) {
            String email = (so.CustomerAccount__r != null && so.CustomerAccount__r.IsPersonAccount)
                ? so.CustomerAccount__r.PersonEmail : null;
            
            wrapperList.add(new WrapperClass.SalesOrderWrapper(
                so.Id, email, so.Unit__r != null ? so.Unit__r.Name : null,
                so.CustomerAccount__r != null ? so.CustomerAccount__r.Name : null,
                closedDate, so.Sales_Type__c, so.ProjectName__c,so.SalesAssociate__r != null ? so.SalesAssociate__r.name : null));
        }
        
        //WrapperClass wrapper = new WrapperClass();
        //wrapper.solst = wrapperList;
        // return JSON.serialize(wrapper);
        Map<String, Object> payload = new Map<String, Object>{
            'contacts' => wrapperList,
                'medium'   => 10
                };
                    
                    return JSON.serialize(payload);
    }
    
    private void processFollowupResponse(HttpResponse res, List<SalesOrder__c> salesOrders, String scenarioName) {
        
        
        if (res.getStatusCode() == 200) {
            Map<String, Object> parsedJson = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            List<Object> dataList = (List<Object>) parsedJson.get('data');
            Map<String, Object> firstItem = (Map<String, Object>) dataList[0];
            String message = (String) firstItem.get('message');
            
            Pattern urlPattern = Pattern.compile('https?://\\S+');
            Matcher matcher = urlPattern.matcher(message);
            String extractedUrl = matcher.find() ? matcher.group() : '';
            system.debug('extractedUrl============='+ extractedUrl);
            Map<String, String> surveyLinkMap = new Map<String, String>{ 'ClientSurveylink' => extractedUrl };
                
                Date nextReminder = System.today().addMonths(6);
            List<Id> soIds = new List<Id>();
            List<SalesOrder__c> updateList = new List<SalesOrder__c>();
            
            for (SalesOrder__c so : salesOrders) {
                so.SurveyLink__c = extractedUrl;
                soIds.add(so.Id);
            }
            // SendGridSalesOrderCustomerEmail.executeEmailSending(soIds, scenarioName, surveyLinkMap);
            
            // Move logic AFTER email
            for (SalesOrder__c so : salesOrders) {
                
                if (so.ReminderCount__c == null) {
                    so.ReminderCount__c = 1;
                    so.NextReminder__c = nextReminder;
                } else {
                    so.ReminderCount__c += 1;
                    so.NextReminder__c = nextReminder;
                }
                
               /* if (so.ReminderCount__c >= 3) {
                    so.NextReminder__c = null;
                } else {
                    so.NextReminder__c = nextReminder;
                }*/
                
                updateList.add(so);
            }
            
            update updateList;
            Map<Id, Set<String>> emailMap = SendRequestToXiboSalesOrder.getSalesOrderEmails(new Set<Id>(soIds));
            for (SalesOrder__c so: updateList){
                system.debug('this for loop==========');
                if (emailMap.containsKey(so.Id)) {
                   // for (String customerEmail : emailMap.get(so.Id)) {
                   String combinedEmails = String.join(new List<String>(emailMap.get(so.Id)), ',');
                        System.enqueueJob(new SendGridNotificationUtilityQueueable(null,null,'Salesorder_Completed_Followup',combinedEmails,'opinions@modon.com','Modon Survey',null,
                                                                                   null,'Salesorder clousre followup','Customer Management',null,null,so.Id ));
                   // }
                }
            }
            
        } else {
            System.debug('Follow-up survey request failed: ' + res.getStatusCode() + ' - ' + res.getBody());
        }
    }
    
    global void finish(Database.BatchableContext BC) {
        System.debug('SalesOrderSixMonthFollowupBatch execution complete.');
        
        
    }
}