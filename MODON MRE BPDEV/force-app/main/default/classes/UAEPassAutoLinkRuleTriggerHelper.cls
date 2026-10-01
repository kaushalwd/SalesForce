/**********************************************************************************************************************
* Name               : UAEPassAutoLinkRuleTriggerHelper                                                        
* Description        : This class is used as a helper for UAEPassAutoLinkRuleTrigger
* Usage              : Called from UAEPassAutoLinkRuleTrigger
* Created By         : Suresh                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh                      05 08 2026     Initial Draft
* 1.1 			Suresh						17 08 2026 	   Empty contact verification added
******************************************************************************************************************/
public with sharing class UAEPassAutoLinkRuleTriggerHelper {

    public static void sendEmailMessage(List<SObject> newList, Map<Id, SObject> oldMap){
        try {
            Set<String> lst_UAEPassLinkId = new Set<String>();
            
            for(SObject sObj : newList) {
                UAEPassAutoLinkRule__c obj_UAEPassLink = (UAEPassAutoLinkRule__c) sObj;
                
                if (oldMap != null) {
                    UAEPassAutoLinkRule__c obj_PrevUAEPassAutoLink = (UAEPassAutoLinkRule__c) oldMap.get(obj_UAEPassLink.Id);
                    
                    Boolean emailChanged = obj_PrevUAEPassAutoLink.Email__c != obj_UAEPassLink.Email__c ;
                    Boolean hasMismatch = obj_UAEPassLink.Email__c != obj_UAEPassLink.CustomerEmail__c;
                    //1.1 added
                    if ((emailChanged || hasMismatch) && obj_UAEPassLink.Contact__c != null) {
                        lst_UAEPassLinkId.add(obj_UAEPassLink.Id);
                    }
                } else {
                    //1.1 added
                    if ((obj_UAEPassLink.Email__c != obj_UAEPassLink.CustomerEmail__c) && obj_UAEPassLink.Contact__c != null) {
                        lst_UAEPassLinkId.add(obj_UAEPassLink.Id);
                    }
                }
            }
            
            if (!lst_UAEPassLinkId.isEmpty()) {
                List<AsyncApexJob> activeJobs = [SELECT Id FROM AsyncApexJob WHERE Status IN ('Queued', 'Preparing', 'Processing')];
                
                if (activeJobs.size() < 100) { 
                    Database.executeBatch(new UAEPassAutoLinkRuleEmailBatch(lst_UAEPassLinkId), 1);
                } else {
                     System.debug(LoggingLevel.WARN, 'UAEPass Batch execution deferred: Apex Flex Queue is full.');
                }
            }
            
        } catch(Exception exe) {
            LoggerService.save(LoggerService.createApexLog(exe, 'UAEPassAutoLinkRuleTriggerHelper', 'UAEPassAutoLinkRuleTriggerHelper', 'sendEmailMessage'));
            System.debug(LoggingLevel.ERROR, 'Error inside UAEPassAutoLinkRuleTriggerHelper: ' + exe.getMessage());
        }
    }
}