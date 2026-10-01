/**********************************************************************************************************************
* Name               : BucketAssignmentTriggerHelper                                                        
* Description        : This class is helper for BucketAssignment trigger
* Usage              : Called from BucketAssignmentTriggerHandler
* Created By         :                                          
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0                
******************************************************************************************************************/
public without sharing class BucketAssignmentTriggerHelper {
    public static void handleUnitSharing(List<Bucket_Assignment__c> newBAs) {
        set<Id> bucketIds = new set<Id>();
        for(Bucket_Assignment__c baObj : newBAs){
            bucketIds.add(baObj.Bucket__c);
        }
        Map<String, String> unitBucketMap = new Map<String, String>();
        for(Unit__c unitObj : [SELECT Id, Bucket__c FROM Unit__c WHERE Bucket__c IN :bucketIds]){
            unitBucketMap.put(unitObj.Id, unitObj.Bucket__c);
        }
        if(unitBucketMap != NULL && unitBucketMap.keySet().size() > 0){
            UnitTriggerHelper.handleUnitSharing(unitBucketMap, unitBucketMap);
        }
    }
}