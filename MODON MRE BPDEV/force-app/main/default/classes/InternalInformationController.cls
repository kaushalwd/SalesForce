/*
@description       : Internal Information controller for customer360
@author            : Chaitanya N
@group             : 
@last modified on  : 22-05-2026
@last modified by  : Chaitanya N.
*/
public with sharing class InternalInformationController {

    @AuraEnabled(cacheable=true)
    public static Map<String, String> getInternalInformationData(String recordId, Date startDate, Date endDate) {
        Map<String, String> fieldToValueMap = new Map<String, String>();

        if (String.isBlank(recordId) || !recordId.startsWith('001')) {
            return fieldToValueMap;
        }

        Date currentDate = System.today();
        Date defaultStart = Date.newInstance(currentDate.year(), 1, 1);
        Date defaultEnd = Date.newInstance(currentDate.year(), 12, 31);

        Date effectiveStart = (startDate == null) ? defaultStart : startDate;
        Date effectiveEnd = (endDate == null) ? defaultEnd : endDate;
        Datetime endDTExclusive = DateTime.newInstance(effectiveEnd.addDays(1), Time.newInstance(0,0,0,0));

        // Fetch metadata configuration
        List<Customer360_Field_Config__mdt> metadataList = [
            SELECT DeveloperName, Component_Name__c, Field_Name_In_Object__c, Data_Type__c,
                   Order__c, MasterLabel
            FROM Customer360_Field_Config__mdt
            WHERE Active__c = TRUE
              AND Component_Name__c = :Constants.INTERNAL_INFORMATION_CUSTOMER_360
            ORDER BY Order__c
        ];

        // Account lookup (now includes CountryOfResidence__pc and Owner.Name)
        Account acc = [
            SELECT Id, Account_Manager__r.Name, Owner.Name, CountryOfResidence__pc, RecordType.DeveloperName, CustomerType__c,
           UAE_Resident_Status__pc
            FROM Account
            WHERE Id = :recordId
            LIMIT 1
        ];

        Id effectiveAccountId = acc.Id;
        String recordTypeLabel = 'Person';
        String accountManager = acc.Account_Manager__r != null ? acc.Account_Manager__r.Name : 'N/A';
        String residentialStatus = String.isNotBlank(acc.UAE_Resident_Status__pc)
            ? acc.UAE_Resident_Status__pc
            : 'N/A';

        // Organization Account logic
        if (acc.RecordType.DeveloperName == 'OrganizationAccount') {
            recordTypeLabel = 'Organization';
            List<Contact> orgContacts = [
                SELECT Id, AccountId, UAE_Resident_Status__c, Primary_Owner__c
                FROM Contact
                WHERE AccountId = :acc.Id
                AND UAE_Resident_Status__c != null
                ORDER BY Primary_Owner__c DESC, LastModifiedDate DESC
                LIMIT 1
            ];
            
            if (!orgContacts.isEmpty()) {
                effectiveAccountId = acc.Id;
            
                if (String.isNotBlank(orgContacts[0].UAE_Resident_Status__c)) {
                    residentialStatus = orgContacts[0].UAE_Resident_Status__c;
                }
            } else {
                System.debug('No contact with UAE Resident Status found for OrganizationAccount: ' + acc.Id);
            }
        }

        // Defensive check before SalesOrder query
        if (effectiveAccountId == null) {
           
            fieldToValueMap.put('RecordTypeLabel', recordTypeLabel);
            return fieldToValueMap;
        }

        // Sales Order query
        List<SalesOrder__c> salesOrderList = [
            SELECT OwnerId, Owner.Name, CreatedDate
            FROM SalesOrder__c
            WHERE CustomerAccount__c = :effectiveAccountId
              AND CreatedDate >= :effectiveStart
              AND CreatedDate <= :endDTExclusive
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        String salesExec = 'N/A';
        if (!salesOrderList.isEmpty()) {
            SalesOrder__c latestOrder = salesOrderList[0];
            if (latestOrder.Owner != null) {
                salesExec = latestOrder.Owner.Name;
            }

            Id ownerId = latestOrder.OwnerId;
            String ownerName;
            String empNumber;

            if (latestOrder.Owner != null) {
                ownerName = latestOrder.Owner.Name;
            }

            if (ownerId != null && ownerId.getSObjectType() == User.SObjectType) {
                List<User> userList = [
                    SELECT EmployeeNumber
                    FROM User
                    WHERE Id = :ownerId
                    LIMIT 1
                ];
                if (!userList.isEmpty() && String.isNotBlank(userList[0].EmployeeNumber)) {
                    empNumber = userList[0].EmployeeNumber;
                }
            }

            // Populate metadata-driven fields
            for (Customer360_Field_Config__mdt meta : metadataList) {
                String val;
                if (meta.Field_Name_In_Object__c == 'OwnerId') {
                    val = ownerName;
                } else if (meta.Field_Name_In_Object__c == 'EmpNumber__c') {
                    val = empNumber;
                } else if (meta.Field_Name_In_Object__c == 'Account_Manager__.Name') {
                    val = accountManager;
                }
                if (String.isNotBlank(val)) {
                    fieldToValueMap.put(meta.MasterLabel, val);
                }
            }
        }

        // Add/override fixed & derived fields — ensure label order exists even if null
        fieldToValueMap.put('Sales Executive', salesExec);
        fieldToValueMap.put('Customer Type', String.isNotBlank(acc.CustomerType__c) ? acc.CustomerType__c : 'N/A');
        fieldToValueMap.put('Account Manager', accountManager);
        //fieldToValueMap.put('Residential Status', String.isNotBlank(acc.CountryOfResidence__pc) ? acc.CountryOfResidence__pc : 'N/A');
        //fieldToValueMap.put('Residential Status', String.isNotBlank(acc.UAE_Resident_Status__pc) ? acc.UAE_Resident_Status__pc : 'N/A');
        fieldToValueMap.put('Residential Status', residentialStatus);
        fieldToValueMap.put('Customer Segmentation', 'Signature Service');
        fieldToValueMap.put('Relationship Manager', acc.Owner != null ? acc.Owner.Name : 'N/A');
       

        fieldToValueMap.put('RecordTypeLabel', recordTypeLabel);

        return fieldToValueMap;
    }
}