@IsTest
private class InternalInformationControllerTest {

    private static final String TEST_PERSON_EMAIL = 'internal.info.test@test.com';
    private static final String TEST_ORG_NAME = 'Internal Test Organization';

    @TestSetup
    static void setupTestData() {
        Account acc = createPersonAccount();
        insert acc;

        SalesOrder__c salesOrder = new SalesOrder__c(
            CustomerAccount__c = acc.Id,
            OwnerId = UserInfo.getUserId()
        );

        String soStatus = getPicklistValue(
            SalesOrder__c.Status__c,
            new List<String>{ 'Completed', 'Sold', 'New', 'In Progress' },
            getCancelledStatuses()
        );

        if (soStatus != null) {
            salesOrder.Status__c = soStatus;
        }

        /*
         * If SalesOrder__c has mandatory fields in your org,
         * add them here only.
         *
         * Example:
         * salesOrder.TotalAmount__c = 100000;
         * salesOrder.Totalpaidamount__c = 50000;
         */

        insert salesOrder;

        // Optional Organization Account data to cover Organization branch
        Id orgRtId = getAccountRecordTypeIdIfExists('OrganizationAccount');

        if (orgRtId != null) {
            Account orgAcc = new Account(
                RecordTypeId = orgRtId,
                Name = TEST_ORG_NAME
            );

            String customerType = getPicklistValue(
                Account.CustomerType__c,
                new List<String>{ 'New Client', 'Existing Client' },
                new Set<String>()
            );
            if (customerType != null) {
                orgAcc.CustomerType__c = customerType;
            }

            insert orgAcc;

            Contact primaryContact = new Contact(
                FirstName = 'Primary',
                LastName = 'Owner',
                AccountId = orgAcc.Id,
                Primary_Owner__c = true
            );
            insert primaryContact;

            SalesOrder__c orgSalesOrder = new SalesOrder__c(
                CustomerAccount__c = orgAcc.Id,
                OwnerId = UserInfo.getUserId()
            );

            if (soStatus != null) {
                orgSalesOrder.Status__c = soStatus;
            }

            insert orgSalesOrder;
        }
    }

    private static Account createPersonAccount() {
        Account acc;

        Id personRtId = getAccountRecordTypeIdIfExists('PersonAccount');

        if (personRtId != null) {
            acc = new Account(
                RecordTypeId = personRtId,
                FirstName = 'Internal',
                LastName = 'Test',
                PersonEmail = TEST_PERSON_EMAIL
            );
        } else {
            acc = new Account(
                Name = 'Internal Test Account'
            );
        }

        String customerType = getPicklistValue(
            Account.CustomerType__c,
            new List<String>{ 'New Client', 'Existing Client' },
            new Set<String>()
        );
        if (customerType != null) {
            acc.CustomerType__c = customerType;
        }

        String residentStatus = getPicklistValue(
            Account.UAE_Resident_Status__pc,
            new List<String>{ 'Resident', 'Non-Resident' },
            new Set<String>()
        );
        if (residentStatus != null && personRtId != null) {
            acc.UAE_Resident_Status__pc = residentStatus;
        }

        return acc;
    }

    private static Id getAccountRecordTypeIdIfExists(String developerName) {
        Map<String, Schema.RecordTypeInfo> rtMap =
            Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName();

        if (rtMap.containsKey(developerName)) {
            return rtMap.get(developerName).getRecordTypeId();
        }

        return null;
    }

    private static Account getPersonAccount() {
        List<Account> accounts = [
            SELECT Id, Name, PersonEmail
            FROM Account
            WHERE PersonEmail = :TEST_PERSON_EMAIL
               OR Name = 'Internal Test Account'
            LIMIT 1
        ];

        System.assertEquals(1, accounts.size(), 'Test Account should exist.');
        return accounts[0];
    }

    private static Account getOrganizationAccount() {
        List<Account> accounts = [
            SELECT Id, Name
            FROM Account
            WHERE Name = :TEST_ORG_NAME
            LIMIT 1
        ];

        return accounts.isEmpty() ? null : accounts[0];
    }

    private static String getPicklistValue(
        Schema.SObjectField fieldToken,
        List<String> preferredValues,
        Set<String> excludedValues
    ) {
        List<Schema.PicklistEntry> values =
            fieldToken.getDescribe().getPicklistValues();

        for (String preferred : preferredValues) {
            for (Schema.PicklistEntry pe : values) {
                if (pe.isActive() && pe.getValue() == preferred) {
                    return pe.getValue();
                }
            }
        }

        for (Schema.PicklistEntry pe : values) {
            if (pe.isActive() && !excludedValues.contains(pe.getValue())) {
                return pe.getValue();
            }
        }

        return null;
    }

    private static Set<String> getCancelledStatuses() {
        return new Set<String>{
            'Cancelled',
            'System cancelled',
            'Cancelled SR',
            'Voided',
            'Property Transfer Cancelled - SR',
            'Unit Swap Cancelled - SR',
            'Unit Upgrade Cancelled - SR',
            'Unit Cancellation Cancelled - SR',
            'Unit Consolidation Cancelled - SR',
            'Property Transfer Title Deed Cancelled - SR'
        };
    }

    @IsTest
    static void testGetInternalInformationDataWithValidId() {
        Account acc = getPersonAccount();

        Test.startTest();
        Map<String, String> result =
            InternalInformationController.getInternalInformationData(
                acc.Id,
                null,
                null
            );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null.');
        System.assert(result.containsKey('Sales Executive'), 'Should contain Sales Executive.');
        System.assert(result.containsKey('Customer Type'), 'Should contain Customer Type.');
        System.assert(result.containsKey('Account Manager'), 'Should contain Account Manager.');
        System.assert(result.containsKey('Residential Status'), 'Should contain Residential Status.');
        System.assert(result.containsKey('Customer Segmentation'), 'Should contain Customer Segmentation.');
        System.assert(result.containsKey('Relationship Manager'), 'Should contain Relationship Manager.');
        System.assert(result.containsKey('RecordTypeLabel'), 'Should contain RecordTypeLabel.');

        System.assertNotEquals(
            null,
            result.get('Sales Executive'),
            'Sales Executive value should be available.'
        );

        System.assertEquals(
            'Person',
            result.get('RecordTypeLabel'),
            'RecordTypeLabel should be Person.'
        );
    }

    @IsTest
    static void testGetInternalInformationDataWithDateRange() {
        Account acc = getPersonAccount();

        Test.startTest();
        Map<String, String> result =
            InternalInformationController.getInternalInformationData(
                acc.Id,
                System.today().addDays(-1),
                System.today().addDays(1)
            );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null.');
        System.assert(result.containsKey('Sales Executive'), 'Should contain Sales Executive.');
        System.assertEquals('Person', result.get('RecordTypeLabel'), 'Record type should be Person.');
    }

    @IsTest
    static void testGetInternalInformationDataWithFutureDateRange() {
        Account acc = getPersonAccount();

        Test.startTest();
        Map<String, String> result =
            InternalInformationController.getInternalInformationData(
                acc.Id,
                System.today().addDays(10),
                System.today().addDays(20)
            );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null.');

        System.assertEquals(
            'N/A',
            result.get('Sales Executive'),
            'Future date range should not find Sales Order, so Sales Executive should be N/A.'
        );

        System.assertEquals(
            'Person',
            result.get('RecordTypeLabel'),
            'RecordTypeLabel should still be Person.'
        );
    }

    @IsTest
    static void testGetInternalInformationDataWithOrganizationAccount() {
        Account orgAcc = getOrganizationAccount();

        if (orgAcc == null) {
            return;
        }

        Test.startTest();
        Map<String, String> result =
            InternalInformationController.getInternalInformationData(
                orgAcc.Id,
                null,
                null
            );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null.');
        System.assertEquals(
            'Organization',
            result.get('RecordTypeLabel'),
            'RecordTypeLabel should be Organization.'
        );
        System.assert(result.containsKey('Sales Executive'), 'Should contain Sales Executive.');
    }

    @IsTest
    static void testGetInternalInformationDataWithNullId() {
        Test.startTest();
        Map<String, String> result =
            InternalInformationController.getInternalInformationData(
                null,
                null,
                null
            );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null.');
        System.assertEquals(0, result.size(), 'Null recordId should return empty map.');
    }

    @IsTest
    static void testGetInternalInformationDataWithBlankId() {
        Test.startTest();
        Map<String, String> result =
            InternalInformationController.getInternalInformationData(
                '',
                null,
                null
            );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null.');
        System.assertEquals(0, result.size(), 'Blank recordId should return empty map.');
    }

    @IsTest
    static void testGetInternalInformationDataWithNonAccountId() {
        Test.startTest();
        Map<String, String> result =
            InternalInformationController.getInternalInformationData(
                UserInfo.getUserId(),
                null,
                null
            );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null.');
        System.assertEquals(0, result.size(), 'Non-Account Id should return empty map.');
    }
}