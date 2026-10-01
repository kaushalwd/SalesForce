/**********************************************************************************************************************
* Name               : SendRequestToXiboSalesOrder                                                         
* Created By         : Active Minds Middle East                                                      
* @author            : Raghu Gajjela
* @group             : 
* Created			 : 05 June 2025
* @last modified on  : 29-09-2025,13-10-25
* @last modified by  : Raghu Gajjela
******************************************************************************************************************/
public class SendRequestToXiboSalesOrder {
    
    public static void callSalesOrderXiboService(Set<String> recordIds) {
        if (recordIds == null || recordIds.isEmpty()) return;
        
        Organization thisOrg = [SELECT IsSandbox FROM Organization LIMIT 1];
        Boolean isSandbox = thisOrg.IsSandbox;
        
        Set<Id> salesOrderIds = new Set<Id>();
        for (String rid : recordIds) {
            salesOrderIds.add(Id.valueOf(rid));
        }
        
        List<SalesOrder__c> salesOrders = [SELECT Id, CustomerAccount__c, CustomerAccount__r.IsPersonAccount, CustomerAccount__r.PersonEmail,CustomerAccount__r.Name,
                                           Unit__r.Name,SalesAssociate__r.name, ProjectName__c, Sales_Type__c,ReminderCount__c,Source_Entity__c,NextReminder__c FROM
                                           SalesOrder__c WHERE Id IN :salesOrderIds and Source_Entity__c != 'Modon - Egypt' ];
        
        if (salesOrders.isEmpty()) return;
        
        List<SalesOrder__c> directOrders = new List<SalesOrder__c>();
        List<SalesOrder__c> inDirectOrders = new List<SalesOrder__c>();
        for(SalesOrder__c so : salesOrders){
            if(so.Sales_Type__c == 'Direct'){
                directOrders.add(so); 
            } else if(so.Sales_Type__c == 'Indirect'){
                inDirectOrders.add(so); 
            }
        }
        
        List<SalesOrder__c> updateSOList = new List<SalesOrder__c>();
        Map<Id, String> clientSurveyLinks = new Map<Id, String>();
        Map<Id, String> brokerSurveyLinks = new Map<Id, String>();
        
        if(directOrders.size() > 0){
            handleSurveyCallout(directOrders, isSandbox, true, clientSurveyLinks);
        }
        
        if(inDirectOrders.size() > 0){
            // handleSurveyCallout(inDirectOrders, isSandbox, true, clientSurveyLinks);
            handleSurveyCallout(inDirectOrders, isSandbox, false, brokerSurveyLinks);
        }
        
        // Update and email after both callouts
        Map<String, String> surveyLinkMap = new Map<String, String>();
        List<Id> soIdsToSend = new List<Id>();
        Date nextReminderDate = System.today().addMonths(6);
        for (SalesOrder__c so : salesOrders) {
            Boolean updated = false;
            if (clientSurveyLinks.containsKey(so.Id)) {
                so.SurveyLink__c = clientSurveyLinks.get(so.Id);
                surveyLinkMap.put('ClientSurveylink', clientSurveyLinks.get(so.Id));
                updated = true;
            }
            if (brokerSurveyLinks.containsKey(so.Id)) {
                so.InDirect_SurveyLink__c = brokerSurveyLinks.get(so.Id);
                surveyLinkMap.put('BrokerSurveyLink', brokerSurveyLinks.get(so.Id));
                updated = true;
            }
            
            if (updated) {
                if (so.ReminderCount__c == null) {
                    so.ReminderCount__c = 1;
                    so.NextReminder__c = nextReminderDate;
                } else {
                    so.ReminderCount__c += 1;
                    so.NextReminder__c = nextReminderDate;
                }
                
               /* if (so.ReminderCount__c >= 3) { chnage on 13-102025
                    so.NextReminder__c = null;
                } else {
                    so.NextReminder__c = nextReminderDate;
                }*/
                updateSOList.add(so);
                soIdsToSend.add(so.Id);
            }
        }
        
        if(updateSOList.size()>0){
            
            
            //SendGridSalesOrderCustomerEmail.executeEmailSending(soIdsToSend, '',surveyLinkMap);
            updateRecords(updateSOList);
            //updateNextReminderAsync(new List<Id>(soIdsToSend));
            Map<Id, Set<String>> emailMap = getSalesOrderEmails(new Set<Id>(soIdsToSend));
            for (SalesOrder__c so : updateSOList) {
                system.debug ('emailsending method ==========');
                if (emailMap.containsKey(so.Id) && Label.Email_To_Customer_In_SO_Enabled == 'True') {// enable Custom label to send emails.
                     String combinedEmails = String.join(new List<String>(emailMap.get(so.Id)), ',');
                   //for (String customerEmail : emailMap.get(so.Id)) {
                        if (so.Sales_Type__c == 'Direct' ){
                            System.enqueueJob(new SendGridNotificationUtilityQueueable(null,null,'Salesorder_Completed',combinedEmails,'opinions@modon.com','Modon Survey',null,
                                                                                       null,'Salesorder Direct clousre confirmation','Customer Management',null,null,so.Id ));
                        }else if(so.Sales_Type__c == 'Indirect'){
                            System.enqueueJob(new SendGridNotificationUtilityQueueable(null,null,'Salesorder_Completed_Indirect',combinedEmails,'opinions@modon.com','Modon Survey',null,
                                                                                       null,'Salesorder Indirect clousre confirmation','Customer Management',null,null,so.Id ));
                        }
                        
                   // }
                }else{system.debug('Custom lable Disabled ==========');}
            }
            
            
        }
        
    }
    
    /* public static void updateNextReminderAsync(List<Id> salesOrderIds) {
List<SalesOrder__c> ordersToUpdate = [
SELECT Id, ReminderCount__c, NextReminder__c FROM SalesOrder__c WHERE Id IN :salesOrderIds ];

// Datetime currentDt = System.now();
//Datetime nextReminderDt = currentDt.addMinutes(5);
// Date nextReminderDate = nextReminderDt.date();

Date nextReminderDate = System.today().addMonths(6);

for (SalesOrder__c so : ordersToUpdate) {

if (so.ReminderCount__c == null) {
so.ReminderCount__c = 1;
} else {
so.ReminderCount__c += 1;
}

if (so.ReminderCount__c >= 3) {
so.NextReminder__c = null;
} else {
so.NextReminder__c = nextReminderDate;
}
}

try {
update ordersToUpdate;
} catch (Exception e) {
System.debug('Update error: ' + e.getMessage());
}
}*/
    
    
    private static void handleSurveyCallout(List<SalesOrder__c> salesOrders, Boolean isSandbox, Boolean isClient, Map<Id, String> surveyLinks) {
        String scenarioKey = isClient ? (isSandbox ? '%SO_Direct_Sandbox' : 'xeboAPI_SO_Direct%')
            : (isSandbox ? '%SO_InDirect_Sandbox' : 'xeboAPI_SO_InDirect%');
                
                List<SendXiboConfig__mdt> metadataList = [SELECT MasterLabel, DeveloperName, ObjectName__c,
                                                          End_Point_URL__c, API_Key__c, CollectionId__c, ProcessType__c
                                                          FROM SendXiboConfig__mdt WHERE ObjectName__c = 'SalesOrder' AND MasterLabel LIKE :scenarioKey];
        
        if(metadataList.isEmpty()) return;
        
        String jsonBody = getJsonBody(salesOrders);
        SendXiboConfig__mdt metadata = metadataList[0];
        
        sendRequestToXiboApi.requestWrapper wrapperRequest = new sendRequestToXiboApi.requestWrapper(metadata, jsonBody, 'SalesOrder__c');
        HttpResponse res = sendRequestToXiboApi.sendRequest(wrapperRequest);
        
        extractSurveyLinks(res, salesOrders, surveyLinks);
    }
    
    private static void extractSurveyLinks(HttpResponse res, List<SalesOrder__c> salesOrders, Map<Id, String> surveyLinks) {
        if (res.getStatusCode() == 200) {
            Map<String, Object> parsedJson = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            List<Object> dataList = (List<Object>) parsedJson.get('data');
            if (dataList != null && !dataList.isEmpty()) {
                Map<String, Object> firstItem = (Map<String, Object>) dataList[0];
                String message = (String) firstItem.get('message');
                
                Pattern urlPattern = Pattern.compile('https?://\\S+');
                Matcher matcher = urlPattern.matcher(message);
                String extractedUrl = matcher.find() ? matcher.group() : '';
                
                for (SalesOrder__c so : salesOrders) {
                    surveyLinks.put(so.Id, extractedUrl);
                }
            }
        } else {
            Set<String> soIdStrings = new Set<String>();
            for (SalesOrder__c so : salesOrders) {
                soIdStrings.add(String.valueOf(so.Id));
            }
            logError(res, 'SalesOrder__c', soIdStrings);
        }
    }
    
    private static String getJsonBody(List<SalesOrder__c> salesOrders){
        List<WrapperClass.SalesOrderWrapper> wrapperList = new List<WrapperClass.SalesOrderWrapper>();
        Date closedDate = System.today();
        
        for (SalesOrder__c so : salesOrders) {
            String email = (so.CustomerAccount__r != null && so.CustomerAccount__r.IsPersonAccount) 
                ? so.CustomerAccount__r.PersonEmail : null;
            
            wrapperList.add(new WrapperClass.SalesOrderWrapper(so.Id,email,so.Unit__r != null ? so.Unit__r.Name : null,
                                                               so.CustomerAccount__r != null ? so.CustomerAccount__r.Name : null,closedDate,so.Sales_Type__c, 
                                                               so.ProjectName__c,so.SalesAssociate__r != null ? so.SalesAssociate__r.name : null ));
        }
        
        Map<String, Object> payload = new Map<String, Object>{
            'contacts' => wrapperList,
                'medium'   => 10
                };
                    
                    return JSON.serialize(payload);
    }
    
    private static void updateRecords(List<SObject> records) {
        if (!records.isEmpty()) {
            try {
                Database.update(records, false);
            } catch (Exception e) {
                System.debug('Error updating records: ' + e.getMessage());
            }
        }
    }
    
    private static void logError(HttpResponse res, String sObjectName, Set<String> recordIds) {
        String error = res.getStatusCode() + ' - ' + res.getBody();
        LoggerService.save(LoggerService.createAPILog(
            'Survey API', 'SendRequestToXiboSalesOrder', 'SendRequest',
            JSON.serialize(recordIds), '', error, 'Update Log'
        ));
    }
    public static  Map<Id, Set<String>> getSalesOrderEmails(Set<Id> salesOrderIds) {
        Map<Id, Set<String>> emailMap = new Map<Id, Set<String>>();
        
        if (salesOrderIds.isEmpty()) return emailMap;
        
        Id personRecTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();
        
        // Query SalesOrders with Accounts
        List<SalesOrder__c> orders = [SELECT Id,CustomerAccount__c,CustomerAccount__r.RecordTypeId,CustomerAccount__r.PersonEmail,CustomerAccount__r.Name FROM SalesOrder__c 
                                      WHERE Id IN :salesOrderIds ];
        
        // Query Joint Owners
        Map<Id, List<JointOwner__c>> jointOwnersMap = new Map<Id, List<JointOwner__c>>();
        for (JointOwner__c jo : [SELECT SalesOrder__c,JointOwnerAccount__r.PersonEmail FROM JointOwner__c WHERE SalesOrder__c IN :salesOrderIds]) {
            if (!jointOwnersMap.containsKey(jo.SalesOrder__c)) {
                jointOwnersMap.put(jo.SalesOrder__c, new List<JointOwner__c>());
            }
            jointOwnersMap.get(jo.SalesOrder__c).add(jo);
        }
        
        for (SalesOrder__c so : orders) {
            Set<String> emails = new Set<String>();
            
            // Primary Owner
            if (so.CustomerAccount__r != null) {
                if (so.CustomerAccount__r.RecordTypeId == personRecTypeId &&
                    String.isNotBlank(so.CustomerAccount__r.PersonEmail)) {
                        emails.add(so.CustomerAccount__r.PersonEmail);
                    } else {
                        // Business Account → pick one active contact
                        List<Contact> contacts = [ SELECT Email FROM Contact WHERE AccountId = :so.CustomerAccount__c AND Email != NULL ORDER BY CreatedDate ASC LIMIT 1];
                        if (!contacts.isEmpty()) {
                            emails.add(contacts[0].Email);
                        }
                    }
            }
            
            //  Joint Owners
            if (jointOwnersMap.containsKey(so.Id)) {
                for (JointOwner__c jo : jointOwnersMap.get(so.Id)) {
                    if (String.isNotBlank(jo.JointOwnerAccount__r.PersonEmail)) {
                        emails.add(jo.JointOwnerAccount__r.PersonEmail);
                    }
                }
            }
            
            if (!emails.isEmpty()) {
                emailMap.put(so.Id, emails);
            }
        }
        
        return emailMap;
    }
    
}