public with sharing class ProspectController {

    public class ResolveResult {
        @AuraEnabled public Id accountId;
        @AuraEnabled public Id contactId;
        @AuraEnabled public Id prospectParentId;
    }

    public class PrimaryInfo {
        @AuraEnabled public Boolean hasPrimary;
        @AuraEnabled public Boolean isFirst;
    }

    @AuraEnabled
    public static PrimaryInfo checkPrimary(Id srId) {
        PrimaryInfo res = new PrimaryInfo();

        Integer total = [
            SELECT COUNT()
            FROM Prospect_Account__c
            WHERE Service_Request__c = :srId
        ];

        Integer primaryCount = [
            SELECT COUNT()
            FROM Prospect_Account__c
            WHERE Service_Request__c = :srId
            AND Is_Primary__c = true
        ];

        res.hasPrimary = primaryCount > 0;
        res.isFirst = total == 0;

        return res;
    }

    @AuraEnabled
    public static ResolveResult resolve(
        String type,
        Map<String, Object> fields,
        Id accountId,
        Id contactId,
        Id srId
    ) {
        ResolveResult res = new ResolveResult();

        // find existing ORG Prospect (for linking)
        Prospect_Account__c orgProspect = [
            SELECT Id
            FROM Prospect_Account__c
            WHERE Service_Request__c = :srId
            AND IsPersonAccount__c = false
            LIMIT 1
        ];

        if (contactId != null) {
            res.contactId = contactId;
        }

        if (accountId != null) {
            if (type == 'ORG' || type == 'PERSON') {
                res.accountId = accountId;
            }
            if (type == 'CONTACT') {
                Contact c = new Contact(
                    AccountId = accountId,
                    FirstName = (String)fields.get('First_Name__c'),
                    LastName = (String)fields.get('Last_Name__c')
                );
                insert c;
                res.contactId = c.Id;
            }
        }

        if (res.accountId == null && res.contactId == null) {
            if (type == 'ORG') {
                Account acc = new Account(Name = (String)fields.get('Account_Name__c'));
                insert acc;
                res.accountId = acc.Id;
            }
            else if (type == 'PERSON') {
                Account acc = new Account(
                    FirstName = (String)fields.get('First_Name__c'),
                    LastName = (String)fields.get('Last_Name__c'),
                    RecordTypeId = getPersonRT()
                );
                insert acc;
                res.accountId = acc.Id;
            }
            else {
                Contact c = new Contact(
                    FirstName = (String)fields.get('First_Name__c'),
                    LastName = (String)fields.get('Last_Name__c')
                );
                insert c;
                res.contactId = c.Id;
            }
        }

        // 🔥 NEW LOGIC
        if (type == 'CONTACT' && orgProspect != null) {
            res.prospectParentId = orgProspect.Id;
        }

        return res;
    }

    private static Id getPersonRT() {
        return Account.SObjectType.getDescribe()
            .getRecordTypeInfosByName()
            .get('Person Account')
            .getRecordTypeId();
    }
}