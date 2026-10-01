/*
@description       : Customer 360 main controller
@author            : Chaitanya N
@group             : 
@last modified on  : 22-05-2026
@last modified by  : Chaitanya N.
*/
public without sharing class Customer360Controller {
      @AuraEnabled(cacheable=true)
    public static String getRecordTypeName(Id recordId) {
        try {
            Account acc = [SELECT RecordType.Name FROM Account WHERE Id = :recordId LIMIT 1];
            System.debug('Record Type: ' + acc.RecordType.Name);
            return acc.RecordType.Name;
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching record type: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static String getAccountOwnerPhotoUrl(Id accountId) {
        if (accountId == null) return null;

        Account a = [
            SELECT OwnerId
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];

        User u = [
            SELECT SmallPhotoUrl, FullPhotoUrl
            FROM User
            WHERE Id = :a.OwnerId
            LIMIT 1
        ];

        String url = String.isNotBlank(u.FullPhotoUrl) ? u.FullPhotoUrl : u.SmallPhotoUrl;
        return String.isNotBlank(url) ? url : null;
    }

    @AuraEnabled(cacheable=true)
    public static String getAccountOwnerName(Id accountId) {
        if (accountId == null) return null;

        Account a = [
            SELECT Owner.Name
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];
        return a.Owner != null ? a.Owner.Name : null;
    }

    @AuraEnabled(cacheable=true)
    public static Account getAccountSegmentation(Id accountId) {
        if (accountId == null) return null;

        return [
            SELECT Customer_Segmentation__c, Customer_Segemnt_Group__c
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];
    }




}