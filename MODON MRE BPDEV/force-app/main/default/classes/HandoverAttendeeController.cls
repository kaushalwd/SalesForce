public with sharing class HandoverAttendeeController {

    @AuraEnabled(cacheable=true)
    public static List<JointOwner__c> getJointOwners(Id accountId) {
        if (accountId == null) {
            return new List<JointOwner__c>();
        }
        return [
            SELECT Id, Name
            FROM JointOwner__c
            WHERE JointOwnerAccount__c = :accountId
            ORDER BY Name ASC
            LIMIT 20
        ];
    }
}