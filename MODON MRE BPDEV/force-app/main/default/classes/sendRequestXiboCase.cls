/**********************************************************************************************************************
* Name               : sendRequestXiboCase                                                        
* Description        : Handles survey API integration for Case closure.Sends case details to Xibo service and processes response.
* Usage              : Called from sendRequestXibo
* Created By         : Active Minds Global Solutions Pvt Ltd                                                     
* ---------------------------------------------------------------------------------------------------------------------
* Version       Author                                      Date            Comment                                                                       
* 1.0           Raghu Gajjela      							24 Sep 2025     Initial Draft 
* 2.0			ravikumar.pasumarthi@activemindsit.com		05 Dec 2025		Add changes related to Email-to-Case and email sender address configurations
* 3.0			ravikumar.pasumarthi@activemindsit.com		23 Dec 1015		Added new fields in SOQL 
***********************************************************************************************************************/
public class sendRequestXiboCase {
    
    /**3.0
     * Method Name: callCaseXIboService
     * Sends closed Case details to Xibo API.
     * - Builds JSON payload
     * - Calls external API
     * - Extracts survey URL from response
     * - Updates Case with Survey link
     * - Triggers email notification via Queueable
     * @param recordIds Set of Case Ids.
     */
    public static void callCaseXIboService(Set<String> recordIds){
        Organization this_org = [Select Id, Name, IsSandbox from Organization];
        sendXiboconfig__mdt pg_metadata = this_org.IsSandbox ? sendXiboconfig__mdt.getInstance('xeboAPI_Case_Sandbox'): sendXiboconfig__mdt.getInstance('xeboAPI_Case');
        system.debug('pg_metadata'+ pg_metadata); 
        
        List<Case> casesClosedList = [SELECT Id, Subject,AccountId,Account.Name, Description, Status,Unit__r.Name, Customer_Email__c,Visitor_Email__c,RecordType.Name,//3.0
                                      Unit__c,Customer_Type__c,Resolution_Comments__c, ContactId,CaseCategory__c, CaseSubCategory__c,Send_Survey__c,SendEmail_CaseClosed__c,SendEmail_CaseClosed_FCR__c 
                                      FROM Case WHERE Id IN :recordIds];
        WrapperClass wrapper = new WrapperClass();
        date closeddate=system.today();
        string typeService = 'case';
        for (Case c : casesClosedList) {
            //These four line added when prod validation failing time 
            String unitName =  c.Unit__r != null ? c.Unit__r.Name : '';
            String accountName = c.AccountId != null ? c.Account.Name : '';
            String caseCategory = String.isNotBlank(c.CaseCategory__c) ? c.CaseCategory__c : '';
            String caseSubCategory = String.isNotBlank(c.CaseSubCategory__c) ? c.CaseSubCategory__c : '';
            wrapper.contacts.add(new WrapperClass.cls_cases(c.Id, c.Customer_Email__c,unitName,accountName,closeddate,typeService,c.RecordType.Name,caseCategory,caseSubCategory));
        }
        String jsonBody = JSON.serialize(wrapper);
        sendRequestToXiboApi.requestWrapper cWrapper = new sendRequestToXiboApi.requestWrapper(pg_metadata, jsonBody, 'Case');
        HttpResponse resp = sendRequestToXiboApi.sendRequest(cWrapper);
        if (resp.getStatusCode() == 200) {
            System.debug('Request successfully sent to Xibo.');
            Map<String, Object> parsedJson = (Map<String, Object>) JSON.deserializeUntyped(resp.getBody());
            List<Object> dataList = (List<Object>) parsedJson.get('data');
            Map<String, Object> firstItem = (Map<String, Object>) dataList[0];
            String message = (String) firstItem.get('message');
            
            Pattern urlPattern = Pattern.compile('https?://\\S+');
            Matcher matcher = urlPattern.matcher(message);
            String extractedUrl = matcher.find() ? matcher.group() : '';
            System.debug('Extracted URL: ' + extractedUrl);
            List<Id> idList = new List<id>();
                        
            System.debug('debug: in case scenario 2 ');
            List<Case> updatecaseList = new List<Case>();
            
            for (Case c : casesClosedList) {
                c.SurveyLink__c = extractedUrl;
                c.SendEmail_CaseClosed__c = false;
                system.debug('debug: extractedUrl ' + extractedUrl);
                updatecaseList.add(c);
                idList.add(c.Id);                
            }
            
            // SendGridCaseCustomerEmail.executeEmailSending(idList,ServiceConstants.CEMAIL_CASE_CLOSED,extractedUrl);
            updateRecords(updatecaseList);
            system.debug('updatecaseList:'+ updatecaseList);
            		//[V2.0]
                 string Email_to_Customer_From_Address = '';
                 string Email_To_Customer_From_Display = '';
                 
                List<Communication_Email_Setting__mdt> commSettings = [ SELECT Id, DeveloperName, Display_Name__c, OrgEmail__c, Process__c from Communication_Email_Setting__mdt where process__C = 'Case Customer Communication'];
                for(Communication_Email_Setting__mdt commSetting: commSettings)
                {
                    if(commSetting.DeveloperName == 'Case_Customer_Communication')
                    {
                        Email_to_Customer_From_Address = commSetting.OrgEmail__c;
                        Email_To_Customer_From_Display = commSetting.Display_Name__c;
                    }
                }
                        
            for (case c : casesClosedList) {
                system.debug('emailsending method ==========');
                //3.0 start
                string templatename = (c.SendEmail_CaseClosed_FCR__c == true) ? 'Case_Closure_FCR' : 'Case_Closure'; 
                system.debug('templatename ========== ' + templatename);
                string receiverEmail = (c.Customer_Type__c == 'Visitor') ? c.Visitor_Email__c : c.Customer_Email__c;
                system.debug('receiverEmail ' + receiverEmail);
                if(receiverEmail != null)
                {
                	System.enqueueJob(new SendGridNotificationUtilityQueueable(null,null,templatename,receiverEmail,Email_to_Customer_From_Address,Email_To_Customer_From_Display,c.CaseCategory__c,
                                                                           c.CaseSubCategory__c,'Case clousre confirmation','Customer Management',null,null,c.Id ));
                }
                /*
                if(c.Send_Survey__c == true)
                {
                    System.enqueueJob(new SendGridNotificationUtilityQueueable(null,null,templatename,receiverEmail,Email_to_Customer_From_Address,Email_To_Customer_From_Display,c.CaseCategory__c,
                                                                           c.CaseSubCategory__c,'Case clousre confirmation','Customer Management',null,null,c.Id ));
                }
                else
                {
                    System.enqueueJob(new SendGridNotificationUtilityQueueable(null,null,'Case_Closure_No_Survey_Link',receiverEmail,Email_to_Customer_From_Address,Email_To_Customer_From_Display,c.CaseCategory__c,
                                                                           c.CaseSubCategory__c,'Case clousre confirmation','Customer Management',null,null,c.Id ));
                }*/
                
            }
  			//[V2.0]
        } else {
            logError(resp, 'Case', recordIds);
        }   //3.0 end     
    }
    
    /**3.0
     * Method Name: updateRecords
     * Performs safe database update for provided records.Uses partial success mode.
     * @param records List of SObjects to update.
     */    
    private static void updateRecords(List<SObject> records) {
        System.debug('debug: in sendRequestToXiboApi.updateRecords method ');
        if (!records.isEmpty()) {
            try {
                System.debug('debug: before db call');
                Database.update(records, false);
                System.debug('debug: after db call');
            } catch (Exception e) {
                System.debug('Error updating records: ' + e.getMessage());
            }
        }
    }
    
    /**3.0
     * Method Name: logError
     * Logs API error details when callout fails.
     * @param res HTTP response object.
     * @param sObjectName Object name context.
     * @param recordIds Set of record Ids sent in request.
     */
    private static void logError(HttpResponse res, String sObjectName, Set<String> recordIds) {
        String error = res.getStatusCode() + ' - ' + res.getBody();
        LoggerService.save(LoggerService.createAPILog(
            'Survey API', 'sendRequestToXiboApi', 'SendRequest',
            JSON.serialize(recordIds), '', error, 'Update Log'
        ));
    }    
}