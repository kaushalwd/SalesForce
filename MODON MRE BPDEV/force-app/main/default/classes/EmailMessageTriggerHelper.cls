/**********************************************************************************************************************
* Name               : EmailMessageTriggerHelper                                                        
* Description        : Handles SLA updates when EmailMessage records are created against Cases.
* Usage              : Called from EmailMessageTriggerHandler
* Created By         : Active Minds Global Solutions Pvt Ltd                                                     
* ---------------------------------------------------------------------------------------------------------------------
* Version       Author                                      Date            Comment                                                                       
* 1.0           ravikumar.pasumarthi@activemindsit.com      02 Mar 2026     Initial Draft 
* 2.0           ravikumar.pasumarthi@activemindsit.com      11 May 2026     Catch exception if any during case email sending  
* 3.0           ravikumar.pasumarthi@activemindsit.com      22 May 2026     Updated the exception type  
***********************************************************************************************************************/
public without sharing class EmailMessageTriggerHelper 
{ 
    @TestVisible
    static String testLabelOverride;//adding this to handle blank value for the custom label from test methods
    
    /**
* Method Name: updateSLACommunicationMethod
* Updates active CaseSLA__c records when an email is sent.
* @param newList  Trigger.new EmailMessage records.
*/
    public static void updateSLACommunicationMethod(List<SObject> newList)
    {system.debug('debug: in EmailMessageTriggerHelper.updateSLACommunicationMethod method');
     Set<Id> setCaseId = new Set<Id>();
     List<EmailMessage> newEmailList = (List<EmailMessage>)newList;
     List<CaseSLA__c> updateSLAList = new List<CaseSLA__c>();
     for(EmailMessage fi: newEmailList)
     {
         //system.debug('debug: fi.ParentId.getSObjectType() ' + fi.ParentId.getSObjectType());
         if(fi.ParentId != null && fi.ParentId.getSObjectType() == Case.SObjectType && !setCaseId.Contains(fi.ParentId)){
             system.debug('debug: fi.ParentId ' + fi.ParentId);
             setCaseId.add(fi.ParentId);
         }
     }
     
     if(setCaseId != null && setCaseId.size() > 0)
     {
         system.debug('debug: setCaseId.size ' + setCaseId.size());
         List<CaseSLA__c> lstSLA = [SELECT ID,Name,CaseID__c,CaseID__r.CaseNumber,Customer_Communication__c,Comments__c FROM CaseSLA__c WHERE Status__c = 'OnTrack' AND CaseID__c IN :setCaseId];
         system.debug('debug: lstSLA.size ' + lstSLA.size());
         if(lstSLA != null && lstSLA.size() > 0)
         {             
             for(CaseSLA__c sla: lstSLA)
             {
                 system.debug('debug: sla.CaseID__r.CaseNumber ' + sla.CaseID__r.CaseNumber);
                 if(sla.Customer_Communication__c != 'Email Sent')
                 {
                     sla.Customer_Communication__c = 'Email Sent';
                     sla.Comments__c = (sla.Comments__c == null) ? '.' : sla.Comments__c;
                     updateSLAList.add(sla);
                     system.debug('debug: added to updateSLAList ');
                 }
             }
         }
     }
     if(updateSLAList.size() > 0)
     {
         system.debug('debug: updateSLAList.size() ' + updateSLAList.size());
         update updateSLAList;
     }
    }
    
    public static void updateCaseLastUpdatedActivity(List<SObject> newList) 
    {System.debug('debug: in EmailMessageTriggerHelper.updateCaseLastUpdatedActivity');
     
     Set<Id> caseIds = new Set<Id>();
     List<EmailMessage> emailList = (List<EmailMessage>)newList;
     
     // Map to store latest activity per Case
     Map<Id, String> caseActivityMap = new Map<Id, String>();
     
     // Collect Case Ids and determine activity
     for (EmailMessage em : emailList) {
         
         if (em.ParentId != null && em.ParentId.getSObjectType() == Case.SObjectType) {
             
             caseIds.add(em.ParentId);
             
             if (em.Incoming == true) {
                 caseActivityMap.put(em.ParentId, 'Customer Replied');
                 System.debug('debug: Customer Replied');
             } else {
                 caseActivityMap.put(em.ParentId, 'Agent Responded');
                 System.debug('debug: Agent Responded');
             }
         }
     }
     
     // Update Cases
     if (!caseIds.isEmpty()) {
         
         List<Case> casesToUpdate = new List<Case>();
         
         for (Id caseId : caseIds) {
             
             if (caseActivityMap.containsKey(caseId)) {
                 
                 casesToUpdate.add(new Case(
                     Id = caseId,
                     Last_Updated_Activity__c = caseActivityMap.get(caseId),
                     Last_Activity_Date__c = system.now()
                 ));
                 System.debug('debug: caseActivityMap.get(caseId)' + caseActivityMap.get(caseId));
             }
         }
         
         if (!casesToUpdate.isEmpty()) {
             System.debug('debug: casesToUpdate.size()' + casesToUpdate.size());
             //2.0 start
            try{
             update casesToUpdate;
             }
             catch(DmlException ex)//3.0
             {
                 System.debug('Error updating case activity fields: ' + ex.getMessage());

             }
             //2.0 end
         }
     }
    }
}