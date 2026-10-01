@IsTest
private class CollectionInsightSOControllerTest {

    private static final String TEST_EMAIL = 'collection.insight@test.com';
    private static final String TEST_ACCOUNT_NAME = 'Test Collection Account';
    private static final String TEST_PROJECT_NAME = 'Test Project';
    private static final String TEST_UNIT_NAME = 'Test Unit';

    @TestSetup
    static void setupData() {
        Account acc = createTestAccount();
        insert acc;

        /*
         * This setup assumes:
         * Project__c -> Phase__c -> Unit__c -> SalesOrder__c
         * and SalesOrder__c.ProjectName__c / Unit_Name__c are formula fields.
         * If your org has different lookup names, adjust only this setup block.
         */

        Project__c projectRec = new Project__c(
            Name = TEST_PROJECT_NAME
        );
        insert projectRec;

        Phase__c phaseRec = new Phase__c(
            Name = 'Test Phase',
            Project__c = projectRec.Id
        );
        insert phaseRec;

        Unit__c unitRec = new Unit__c(
            Name = TEST_UNIT_NAME,
            Phase__c = phaseRec.Id,
            PlotNo__c = '1234',
            UnitClassification__c = 'Villa', 
            Number_of_Bedrooms__c = '2'
        );

        String unitStatus = getPicklistValue(
            Unit__c.Status__c,
            new List<String>{ 'Sold', 'Available' },
            new Set<String>()
        );
        if (unitStatus != null) {
            unitRec.Status__c = unitStatus;
        }

        insert unitRec;

        SalesOrder__c so = new SalesOrder__c(
            CustomerAccount__c = acc.Id,
            Unit__c = unitRec.Id,
            TotalAmount__c = 10000,
            Totalpaidamount__c = 0
        );

        String soStatus = getPicklistValue(
            SalesOrder__c.Status__c,
            new List<String>{ 'Sold', 'Completed', 'Booked' },
            getCancelledStatuses()
        );
        if (soStatus != null) {
            so.Status__c = soStatus;
        }

        /*
         * If SalesOrder__c has mandatory fields in your org,
         * add them here only.
         */

        insert so;

        List<SalesOrderInstallments__c> installments = new List<SalesOrderInstallments__c>();

        // Past milestone => billed amount
        installments.add(new SalesOrderInstallments__c(
            SalesOrder__c = so.Id,
            InstallmentAmount__c = 100,
            MilestoneDate__c = System.today().addDays(-10)
        ));

        // Future milestone => future collection amount
        installments.add(new SalesOrderInstallments__c(
            SalesOrder__c = so.Id,
            InstallmentAmount__c = 200,
            MilestoneDate__c = System.today().addDays(30)
        ));

        // Null milestone date => treated as future by controller
        installments.add(new SalesOrderInstallments__c(
            SalesOrder__c = so.Id,
            InstallmentAmount__c = 300,
            MilestoneDate__c = null
        ));

        insert installments;
    }

    private static Account createTestAccount() {
        Map<String, Schema.RecordTypeInfo> rtMap =
            Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName();

        if (rtMap.containsKey('PersonAccount')) {
            return new Account(
                RecordTypeId = rtMap.get('PersonAccount').getRecordTypeId(),
                FirstName = 'Collection',
                LastName = 'Customer',
                PersonEmail = TEST_EMAIL
            );
        }

        if (rtMap.containsKey('OrganizationAccount')) {
            return new Account(
                RecordTypeId = rtMap.get('OrganizationAccount').getRecordTypeId(),
                Name = TEST_ACCOUNT_NAME
            );
        }

        return new Account(
            Name = TEST_ACCOUNT_NAME
        );
    }

    private static Account getTestAccount() {
        List<Account> accounts = [
            SELECT Id, Name, PersonEmail
            FROM Account
            WHERE PersonEmail = :TEST_EMAIL
               OR Name = :TEST_ACCOUNT_NAME
            LIMIT 1
        ];

        System.assertEquals(1, accounts.size(), 'Test Account should exist.');
        return accounts[0];
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
    static void testGetSalesOrderDataWithDefaultDates() {
        Account acc = getTestAccount();

        Test.startTest();
        Map<String, Decimal> result =
            CollectionInsightSalesOrderController.getSalesOrderData(
                acc.Id,
                null,
                null,
                null,
                null
            );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null.');
        System.assert(result.containsKey('totalAmount'), 'Should contain totalAmount.');
        System.assert(result.containsKey('totalPaidAmount'), 'Should contain totalPaidAmount.');
        System.assert(result.containsKey('outstandingAmount'), 'Should contain outstandingAmount.');
        System.assert(result.containsKey('futureCollectionAmount'), 'Should contain futureCollectionAmount.');

        System.assertEquals(100, result.get('totalAmount'), 'Past installment should be billed.');
        System.assertEquals(0, result.get('totalPaidAmount'), 'No cleared receipts were created.');
        System.assertEquals(100, result.get('outstandingAmount'), 'Outstanding should be billed minus collected.');
        System.assertEquals(500, result.get('futureCollectionAmount'), 'Future and null milestone installments should be future collection.');
    }

    @IsTest
    static void testGetSalesOrderDataWithDateRange() {
        Account acc = getTestAccount();

        Test.startTest();
        Map<String, Decimal> result =
            CollectionInsightSalesOrderController.getSalesOrderData(
                acc.Id,
                System.today().addDays(-1),
                System.today().addDays(1),
                null,
                null
            );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null.');
        System.assertEquals(100, result.get('totalAmount'), 'Billed amount should match.');
        System.assertEquals(500, result.get('futureCollectionAmount'), 'Future collection amount should match.');
    }

    @IsTest
    static void testGetSalesOrderDataWithProjectAndUnitFilters() {
        Account acc = getTestAccount();

        Test.startTest();
        Map<String, Decimal> result =
            CollectionInsightSalesOrderController.getSalesOrderData(
                acc.Id,
                null,
                null,
                TEST_PROJECT_NAME,
                TEST_UNIT_NAME
            );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null.');
        System.assert(result.containsKey('totalAmount'), 'Should contain totalAmount.');
        System.assert(result.containsKey('futureCollectionAmount'), 'Should contain futureCollectionAmount.');
    }

    @IsTest
    static void testGetSalesOrderDataWithWrongFilters() {
        Account acc = getTestAccount();

        Test.startTest();
        Map<String, Decimal> result =
            CollectionInsightSalesOrderController.getSalesOrderData(
                acc.Id,
                null,
                null,
                'Wrong Project',
                'Wrong Unit'
            );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null.');

        System.assertEquals(0, result.get('totalAmount'), 'Wrong filters should return zero billed.');
        System.assertEquals(0, result.get('totalPaidAmount'), 'Wrong filters should return zero collected.');
        System.assertEquals(0, result.get('outstandingAmount'), 'Wrong filters should return zero outstanding.');
        System.assertEquals(0, result.get('futureCollectionAmount'), 'Wrong filters should return zero future collection.');
    }

    @IsTest
    static void testGetSalesOrderDataWithFutureCreatedDateRange() {
        Account acc = getTestAccount();

        Test.startTest();
        Map<String, Decimal> result =
            CollectionInsightSalesOrderController.getSalesOrderData(
                acc.Id,
                System.today().addDays(10),
                System.today().addDays(20),
                null,
                null
            );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null.');

        System.assertEquals(0, result.get('totalAmount'), 'Future created date range should return zero billed.');
        System.assertEquals(0, result.get('totalPaidAmount'), 'Future created date range should return zero collected.');
        System.assertEquals(0, result.get('outstandingAmount'), 'Future created date range should return zero outstanding.');
        System.assertEquals(0, result.get('futureCollectionAmount'), 'Future created date range should return zero future collection.');
    }
    @IsTest
    static void testOrganizationAccountBranchNoOrders() {
        Id orgRtId;
        Map<String, Schema.RecordTypeInfo> rtMap =
            Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName();
    
        if (!rtMap.containsKey('OrganizationAccount')) {
            return;
        }
    
        orgRtId = rtMap.get('OrganizationAccount').getRecordTypeId();
    
        Account orgAcc = new Account(
            RecordTypeId = orgRtId,
            Name = 'Org Collection Test Account'
        );
        insert orgAcc;
    
        Contact primaryContact = new Contact(
            FirstName = 'Primary',
            LastName = 'Owner',
            AccountId = orgAcc.Id,
            Primary_Owner__c = true
        );
        insert primaryContact;
    
        Test.startTest();
        Map<String, Decimal> result =
            CollectionInsightSalesOrderController.getSalesOrderData(
                orgAcc.Id,
                null,
                null,
                null,
                null
            );
        Test.stopTest();
    
        System.assertNotEquals(null, result, 'Result should not be null.');
        System.assertEquals(0, result.get('totalAmount'), 'No orders should return zero billed.');
        System.assertEquals(0, result.get('totalPaidAmount'), 'No orders should return zero paid.');
        System.assertEquals(0, result.get('outstandingAmount'), 'No orders should return zero outstanding.');
        System.assertEquals(0, result.get('futureCollectionAmount'), 'No orders should return zero future.');
    }
    @IsTest
    static void testOrdersExistButNoInstallments() {
        Account acc = new Account(
            FirstName = 'No',
            LastName = 'Installments',
            PersonEmail = 'no.installments@test.com'
        );
    
        Map<String, Schema.RecordTypeInfo> rtMap =
            Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName();
    
        if (rtMap.containsKey('PersonAccount')) {
            acc.RecordTypeId = rtMap.get('PersonAccount').getRecordTypeId();
        }
    
        insert acc;
    
        Project__c projectRec = new Project__c(
            Name = 'No Installment Project'
        );
        insert projectRec;
    
        Phase__c phaseRec = new Phase__c(
            Name = 'No Installment Phase',
            Project__c = projectRec.Id
        );
        insert phaseRec;
    
        Unit__c unitRec = new Unit__c(
            Name = 'No Installment Unit',
            Phase__c = phaseRec.Id,
            PlotNo__c = 'NO-INST-1',
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '2'
        );
    
        String unitStatus = getPicklistValue(
            Unit__c.Status__c,
            new List<String>{ 'Sold', 'Available' },
            new Set<String>()
        );
        if (unitStatus != null) {
            unitRec.Status__c = unitStatus;
        }
    
        insert unitRec;
    
        SalesOrder__c so = new SalesOrder__c(
            CustomerAccount__c = acc.Id,
            Unit__c = unitRec.Id,
            TotalAmount__c = 5000,
            Totalpaidamount__c = 0
        );
    
        String soStatus = getPicklistValue(
            SalesOrder__c.Status__c,
            new List<String>{ 'Sold', 'Completed', 'Booked' },
            getCancelledStatuses()
        );
        if (soStatus != null) {
            so.Status__c = soStatus;
        }
    
        insert so;
    
        Test.startTest();
        Map<String, Decimal> result =
            CollectionInsightSalesOrderController.getSalesOrderData(
                acc.Id,
                null,
                null,
                null,
                null
            );
        Test.stopTest();
    
        System.assertNotEquals(null, result, 'Result should not be null.');
        System.assertEquals(0, result.get('totalAmount'), 'Order without installments should return zero billed.');
        System.assertEquals(0, result.get('totalPaidAmount'), 'Order without installments should return zero paid.');
        System.assertEquals(0, result.get('outstandingAmount'), 'Order without installments should return zero outstanding.');
        System.assertEquals(0, result.get('futureCollectionAmount'), 'Order without installments should return zero future.');
    }
    
}