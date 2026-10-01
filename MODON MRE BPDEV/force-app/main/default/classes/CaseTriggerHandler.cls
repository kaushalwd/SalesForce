/**********************************************************************************************************************
* Name               : CaseTriggerHandler                                                        
* Description        : Main trigger handler for Case object.Controls execution flow, prevents recursion, and delegates business logic to helper classes.
* Usage              : This class is used handle Case triggering scenarios
* Created By         : Active Minds Global Solutions Pvt Ltd                                                     
* ---------------------------------------------------------------------------------------------------------------------
* Version       Author                                      Date            Comment                                                                       
* 1.0           ravikumar.pasumarthi@activemindsit.com      11 Dec 2024     Initial Draft 
* 2.0           Raghu Gajjela                               28 jan 2025     Intial Draft
* 3.0           ravikumar.pasumarthi@activemindsit.com      17 Dec 2025     Added new methods needed for Case Mgmt 2.0 and removed unwanted methods not needed in 2.0
* 4.0           ravikumar.pasumarthi@activemindsit.com      08 May 2026     Added new method validateOwnerQueue
                                                                            Added new method capturePreviousValues
                                                                            Added new method validateCaseUpdateAccess
* 5.0          Raghu.chilukuri@activemindsit.com            20 May 2026     called a New Method related to Case Spa task Creation in after update method. 
                                                                            Removed checkNeedForTaskCreation as no longer needed
* 6.0          Sivannarayana                                27 June 2026    Added Case Closure Refund whats APP Message changes
***********************************************************************************************************************/
public without sharing class CaseTriggerHandler implements ITriggerHandler
{
    // Use this variable to disable the trigger during tests or specific scenarios
    public static Boolean isTestRun = false; 
    
    //Use this variable to disable this trigger from transaction
    public static Boolean isTriggerDisabled = false;
    
    //Use this variable to disable this trigger from environment
    public static Boolean caseTriggerIsDisabled = 'TRUE'.equalsIgnoreCase(System.Label.caseTriggerIsDisabled);
    
    /**
     * Method Name: isDisabled
     * Determines whether Case trigger logic should execute.
     * @return  Boolean indicating trigger execution status.
     */
    public Boolean isDisabled()
    {
        system.debug('debug: in CaseTriggerHandler.isDisabled method');system.debug('debug: isTestRun ' + isTestRun);
        system.debug('debug: isTriggerDisabled ' + isTriggerDisabled);system.debug('debug: caseTriggerIsDisabled ' + caseTriggerIsDisabled);
        return isTestRun || isTriggerDisabled || caseTriggerIsDisabled;
    } 
    
    //Static variables to stop recurssive calling of the trigger
    public static Boolean isBeforeInsertFirstRun = true;
    public static Boolean isAfterInsertFirstRun = true;
    public static Boolean isBeforeUpdateFirstRun = true;
    public static Boolean isAfterUpdateFirstRun = true;
    
     /**
     * Method Name: beforeInsert
     * Before Insert logic for Case.
     * @param newList  Trigger.new Case records.
     */
        
    public void beforeInsert(List<sObject> newList) 
    {system.debug('debug: in CaseTriggerHandler.beforeInsert method');
     if (isDisabled()) 
     {
         system.debug('Trigger is disabled; skipping logic in beforeInsert.');
         return;
     }
     //CaseTriggerHelper.performVisitorValidations(newList,null);
     CaseTriggerHelper.updateCaseOriginAndRecordType(newList);
     CaseConfigService.applyOriginConfig((List<Case>)newList, null);
     CaseConfigService.applyCategoryConfig((List<Case>)newList, null);
     CaseTriggerHelper.identifyCustomer(newList);
     CaseTriggerHelper.emailMaskingBeforeInsert(newList);
     CaseTriggerHelper.assignToQueueOwner_Updated(newList);
     CaseTriggerHelper.assignCreatorAsOwnerIfApplicable(newList);
     CaseTriggerHelper.assignComplaintCasesToSpecificUser(newList);
     CaseTriggerHelper.validateUnit(newList,'beforeInsert');
     CaseTriggerHelper.updateOwnerEmail(newList);  
     //CaseTriggerHelper.assignCaseType(newList,'beforeInsert'); // moved from above    
     for(Case cs: (List<Case>)newList)
     {
         system.debug('debug: cs.Owner_Email__c ' + cs.Owner_Email__c);system.debug('debug: cs.Previous_Owner_Email__c ' + cs.Previous_Owner_Email__c);
         system.debug('debug: cs.New_Owner_Email__c ' + cs.New_Owner_Email__c);system.debug('debug: cs.Primary_Owner_Name__c ' + cs.Primary_Owner_Name__c);
         system.debug('debug: cs.Account_Manager_Email__c ' + cs.Account_Manager_Email__c);system.debug('debug: cs.Case_Approver__c ' + cs.Case_Approver__c);
     }
     CaseTriggerHelper.updateCaseCreationEmailSendingFlagsOnInsert(newList);
     isBeforeInsertFirstRun = false;
    }
    
    /**
     * Method Name: afterInsert
     * After Insert logic for Case.
     * @param newList  Inserted Case records.
     * @param newMap   Map of inserted records.
     */
    public void afterInsert(List<sObject> newList , Map<Id, sObject> newMap) 
    {system.debug('debug: in CaseTriggerHandler.afterInsert method');    
     if (isDisabled()) 
     {
         system.debug('Trigger is disabled; skipping logic in afterInsert.');
         return;
     }       
     if(newList.size() > 0 && isAfterInsertFirstRun)
     {

         isAfterInsertFirstRun = false;
         CaseTriggerHelper.assignSharing(newList);
         CaseTriggerHelper.creatingDocument(newList);
         CaseTriggerHelper.createCaseSLAWhenCaseOwnerUpdated(newList, null);
         CaseTriggerHelper.handleCaseSPASignatureFlow(newList, null);//New
         system.debug('calling CaseTriggerHelper.sendCustomerEmailsCaseCreated method.');
         CaseTriggerHelper.sendCustomerEmailsCaseCreated(newList);         
     }
    }
    
    /**
     * Method Name: beforeUpdate
     * Before Update logic for Case
     * @param newList  Updated Case records.
     * @param newMap   Map of updated records.
     * @param oldList  Previous Case records.
     * @param oldMap   Map of previous records.
     */
    public void beforeUpdate(List<sObject> newList, Map<Id, sObject> newMap, List<sObject> oldList, Map<Id, sObject> oldMap) 
    {system.debug('debug: in CaseTriggerHandler.beforeUpdate method');
     if (isDisabled()) 
     {
         system.debug('Trigger is disabled; skipping logic in beforeUpdate.');
         return;
     }
     if(newList.size() > 0 && isBeforeUpdateFirstRun && isBeforeInsertFirstRun && ServiceConstants.FromSendGrid == false)
     {
         isBeforeUpdateFirstRun = false;
        
         CaseConfigService.applyCategoryConfig((List<Case>)newList,(Map<Id, Case>)oldMap);
         CaseConfigService.applyOriginConfig((List<Case>)newList,(Map<Id, Case>)oldMap);
         CaseTriggerHelper.identifyCustomer(newList);
         system.debug('debug: executing CaseTriggerHandler.beforeUpdate method');
         CaseTriggerHelper.emailMaskingBeforeUpdate(newMap,oldMap);
         CaseTriggerHelper.updateNewOwnerWhenOwnerChanged(newList,oldMap);
       
         if(newList != null && newList.size() > 0)
         {
             CaseTriggerHelper.validateUnit(newList,'beforeUpdate');                
         }
         CaseTriggerHelper.updatePreviousOwner(newList,oldMap);
         CaseTriggerHelper.updateQueueWhenCategoryUpdated(newList,oldMap);
         CaseTriggerHelper.assignComplaintCasesToSpecificUser(newList);
         CaseTriggerHelper.caseClosed(newList,oldMap);
         CaseTriggerHelper.updateOwnerEmail(newList);
         CaseTriggerHelper.updateInProgressSLA(newList);
         CaseTriggerHelper.validateOwnerQueue(newList, oldMap);//4.0
         CaseTriggerHelper.capturePreviousValues(newList, oldMap);//Update version 4.0 //This is To capture Previous Values of Few Case Fields
         CaseTriggerHelper.validateCaseUpdateAccess(newList, oldMap);//Update version 4.0 //This is To Restrict Case Update Access
     }
    }
    
    /**
     * Method Name: afterUpdate
     * After Update logic for Case
     * Handles approval-process exception gracefully.
     * @param newList  Updated Case records.
     * @param newMap   Map of updated records.
     * @param oldList  Previous Case records.
     * @param oldMap   Map of previous records.
     */
    public void afterUpdate(List<sObject> newList, Map<Id, sObject> newMap,  List<sObject> oldList, Map<Id, sObject> oldMap) 
    {system.debug('debug: in CaseTriggerHandler.afterUpdate method');
     if (isDisabled()) 
     {
         system.debug('Trigger is disabled; skipping logic in afterUpdate.');
         return;
     }     
     try
     {
         if(newList.size() > 0 && isAfterUpdateFirstRun && isBeforeInsertFirstRun && ServiceConstants.FromSendGrid == false) 
         {
             isAfterUpdateFirstRun = false;system.debug('debug: executing CaseTriggerHandler.afterUpdate method');
             CaseTriggerHelper.assignSharing(newList);  
             CaseTriggerHelper.closeCaseSLAWhenQueueUpdated(newList, oldMap);
             CaseTriggerHelper.createCaseSLAWhenCaseOwnerUpdated(newList, oldMap);
             CaseTriggerHelper.caseResolvedCloseSLA(newList,oldMap); 
             CaseTriggerHelper.handleCaseSPASignatureFlow(newList,oldMap);//New
               // EOI Refund closure WhatsApp confirmation
            CaseTriggerHelper.sendEOIRefundClosureWhatsApp(newList, oldMap);
         }
     }
     CATCH(Exception e)
     {
         String exceptionMessage = e.getMessage(); 
         if (exceptionMessage.contains('This record is currently in an approval process.')) 
         { 
             System.debug('debug: exceptionMessage :' + exceptionMessage); // Handle the specific scenario, such as logging or notifying the user 
             Case rec = (Case)newList[0];
             rec.Status.addError('This record is currently in an approval process.');
         } 
         else 
         { 
             System.debug('debug: Other error: ' + exceptionMessage); // Handle other exceptions 
         }
     }
    }
    
    public void beforeDelete(List<sObject> oldList , Map<Id, sObject> oldMap) 
    {system.debug('debug: in CaseTriggerHandler.beforeDelete method');
     if (isDisabled()) 
     {
         system.debug('Trigger is disabled; skipping logic in beforeDelete.');
         return;
     }
    }
    
    public void afterDelete(List<sObject> oldList , Map<Id, sObject> oldMap) 
    {system.debug('debug: in CaseTriggerHandler.afterDelete method');
     if (isDisabled()) {
         system.debug('Trigger is disabled; skipping logic in beforeDelete.');
         return;
     }     
    }
    
    public void afterUnDelete(List<sObject> newList, Map<Id, sObject> newMap) 
    {system.debug('debug: in CaseTriggerHandler.afterUnDelete method');
     if (isDisabled()) {
         system.debug('Trigger is disabled; skipping logic in beforeDelete.');
         return;
     }
    }
}