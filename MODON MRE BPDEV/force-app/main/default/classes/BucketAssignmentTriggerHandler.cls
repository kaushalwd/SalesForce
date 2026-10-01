public without sharing class BucketAssignmentTriggerHandler implements ITriggerHandler {
    //Use this variable to disable this trigger from transaction
    public static Boolean isTriggerDisabled = false;
    
    //check if the trigger is disabled from transaction
    public Boolean isDisabled(){
        return isTriggerDisabled;
    }
    
    public void beforeInsert(List<SObject> newList) {
    }
    
    public void afterInsert(List<SObject> newList, Map<Id, SObject> newMap) {
        List<Bucket_Assignment__c> newBAs = (List<Bucket_Assignment__c>) newList;
        BucketAssignmentTriggerHelper.handleUnitSharing(newBAs);
    }

    
    public void beforeUpdate(List<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap) {
    }

    
    public void afterUpdate(List<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap) {
        List<Bucket_Assignment__c> newBAs = (List<Bucket_Assignment__c>) newList;
        BucketAssignmentTriggerHelper.handleUnitSharing(newBAs);
    }

    
    public void beforeDelete(List<sObject> oldList , Map<Id, sObject> oldMap) {
    }
    
    public void afterDelete(List<sObject> oldList , Map<Id, sObject> oldMap) {
        List<Bucket_Assignment__c> oldBAs = (List<Bucket_Assignment__c>) oldList;
        BucketAssignmentTriggerHelper.handleUnitSharing(oldBAs);
    }
    
    public void afterUnDelete(List<sObject> newList, Map<Id, sObject> newMap) {
        List<Bucket_Assignment__c> newBAs = (List<Bucket_Assignment__c>) newList;
        BucketAssignmentTriggerHelper.handleUnitSharing(newBAs);
    }
}