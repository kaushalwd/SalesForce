/**********************************************************************************************************************
* Name               : CaseTriggerHelperBroker                                                        
* Description        : This class is used as a helper for CaseTriggerHandler
* Usage              : Called from CaseTriggerHandler
* Created By         : Active Minds Global Solutions Pvt Ltd                                                     
* ---------------------------------------------------------------------------------------------------------------------
* Version       Author                                      Date            Comment                                                                       
* 1.0           ravikumar.pasumarthi@activemindsit.com      12 May 2025     Initial Draft          
***********************************************************************************************************************/
public without sharing class CaseTriggerHelperBroker 
{
    public static void emptyMethod(){system.debug('debug: in emptyMethod()');}
   /* 
    public static void updateCategory(List<SObject> newList)// from CaseTriggerHandler.beforeInsert, CaseTriggerHandler.beforeUpdate
    {system.debug('debug: in CaseTriggerHelperBroker.updateCategory method');
     for(Case cs: (List<Case>)newList)
     {
         cs.CaseCategory__c = ServiceConstants.CASE_CATEGORY_BROKER_ENQUIRY;
     }
    }
    
    public static void updateRequestorEmail(List<SObject> newList)// from CaseTriggerHandler.beforeInsert, CaseTriggerHandler.beforeUpdate
    {system.debug('debug: in CaseTriggerHelperBroker.updateRequestorEmail method');
     for(Case cs: (List<Case>)newList)
     {
         cs.Requestor_Email__c = cs.SuppliedEmail;
     }
    }
    
    public static void updateSubCategory(List<SObject> newList)// from CaseTriggerHandler.beforeInsert, CaseTriggerHandler.beforeUpdate
    {system.debug('debug: in CaseTriggerHelperBroker.updateSubCategory method');
     for(Case cs: (List<Case>)newList)
     {
         system.debug('debug: cs.Description ' + cs.Description);
         cs.CaseSubCategory__c = null;
         system.debug('debug: cs.CaseSubCategory__c ' + cs.CaseSubCategory__c);
     }
    }
    
    public static void updateOrigin(List<SObject> newList)// from CaseTriggerHandler.beforeInsert, CaseTriggerHandler.beforeUpdate
    {system.debug('debug: in CaseTriggerHelperBroker.updateOrigin method');
     for(Case cs: (List<Case>)newList)
     {
         cs.Origin = ServiceConstants.CASE_ORIGIN_EMAIL;
     }
    }*/
}