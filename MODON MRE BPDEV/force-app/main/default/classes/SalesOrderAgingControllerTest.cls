@IsTest
private class SalesOrderAgingControllerTest {

    private static final String TEST_EMAIL = 'aging.test@test.com';
    private static final String TEST_ACCOUNT_NAME = 'Test Aging Account';
    private static final String TEST_PROJECT_NAME = 'Test Project';
    private static final String TEST_UNIT_NAME = 'Test Unit';

    @TestSetup
    static void setupData() {
        Account acc = createTestAccount();
        insert acc;

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
            TotalAmount__c = 100000,
            Totalpaidamount__c = 10000
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

        String unpaidStatus = getPicklistValue(
            SalesOrderInstallments__c.PaymentStatus__c,
            new List<String>{ 'Pending', 'Unpaid', 'Not Paid' },
            new Set<String>{ 'Paid' }
        );

        List<SalesOrderInstallments__c> installments = new List<SalesOrderInstallments__c>();

        installments.add(createInstallment(so.Id, 100, System.today().addDays(-10), unpaidStatus));
        installments.add(createInstallment(so.Id, 200, System.today().addDays(-45), unpaidStatus));
        installments.add(createInstallment(so.Id, 300, System.today().addDays(-75), unpaidStatus));
        installments.add(createInstallment(so.Id, 400, System.today().addDays(-120), unpaidStatus));

        // Future installment should be ignored by controller
        installments.add(createInstallment(so.Id, 999, System.today().addDays(10), unpaidStatus));

        insert installments;

        ServiceRequest__c sr1 = createServiceRequest(acc.Id);
        ServiceRequest__c sr2 = createServiceRequest(acc.Id);

        insert new List<ServiceRequest__c>{ sr1, sr2 };
    }

    private static Account createTestAccount() {
        Map<String, Schema.RecordTypeInfo> rtMap =
            Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName();

        if (rtMap.containsKey('PersonAccount')) {
            return new Account(
                RecordTypeId = rtMap.get('PersonAccount').getRecordTypeId(),
                FirstName = 'Aging',
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

    private static SalesOrderInstallments__c createInstallment(
        Id salesOrderId,
        Decimal amountValue,
        Date milestoneDate,
        String paymentStatus
    ) {
        SalesOrderInstallments__c inst = new SalesOrderInstallments__c(
            SalesOrder__c = salesOrderId,
            InstallmentAmount__c = amountValue,
            Balance_Amount__c = amountValue,
            MilestoneDate__c = milestoneDate
        );

        if (paymentStatus != null) {
            inst.PaymentStatus__c = paymentStatus;
        }

        /*
         * If SalesOrderInstallments__c has mandatory fields in your org,
         * add them here only.
         */

        return inst;
    }

    private static ServiceRequest__c createServiceRequest(Id accountId) {
        ServiceRequest__c sr = new ServiceRequest__c(
            AccountId__c = accountId
        );

        String srStatus = getPicklistValue(
            ServiceRequest__c.Status__c,
            new List<String>{ 'New', 'In-progress' },
            new Set<String>{ 'Closed', 'Cancelled' }
        );
        if (srStatus != null) {
            sr.Status__c = srStatus;
        }

        /*
         * If ServiceRequest__c has mandatory fields in your org,
         * add them here only.
         */

        return sr;
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
    static void testGetAgingSummaryWithDefaultDates() {
        Account acc = getTestAccount();

        Test.startTest();
        Map<String, Decimal> result =
            SalesOrderAgingController.getAgingSummary(
                acc.Id,
                null,
                null,
                null,
                null
            );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null.');
        System.assert(result.containsKey('< 30 Days'), 'Should contain < 30 Days bucket.');
        System.assert(result.containsKey('30-60 Days'), 'Should contain 30-60 Days bucket.');
        System.assert(result.containsKey('60-90 Days'), 'Should contain 60-90 Days bucket.');
        System.assert(result.containsKey('> 90 Days'), 'Should contain > 90 Days bucket.');

        System.assertEquals(100, result.get('< 30 Days'), '< 30 Days bucket should match.');
        System.assertEquals(200, result.get('30-60 Days'), '30-60 Days bucket should match.');
        System.assertEquals(300, result.get('60-90 Days'), '60-90 Days bucket should match.');
        System.assertEquals(400, result.get('> 90 Days'), '> 90 Days bucket should match.');
    }

    @IsTest
    static void testGetAgingSummaryWithProjectAndUnitFilters() {
        Account acc = getTestAccount();

        Test.startTest();
        Map<String, Decimal> result =
            SalesOrderAgingController.getAgingSummary(
                acc.Id,
                System.today().addDays(-1),
                System.today().addDays(1),
                TEST_PROJECT_NAME,
                TEST_UNIT_NAME
            );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null.');

        Decimal totalAmount =
            result.get('< 30 Days') +
            result.get('30-60 Days') +
            result.get('60-90 Days') +
            result.get('> 90 Days');

        System.assert(
            totalAmount >= 0,
            'Filtered aging summary should return valid bucket values.'
        );
    }

    @IsTest
    static void testGetAgingSummaryWithWrongFilters() {
        Account acc = getTestAccount();

        Test.startTest();
        Map<String, Decimal> result =
            SalesOrderAgingController.getAgingSummary(
                acc.Id,
                null,
                null,
                'Wrong Project',
                'Wrong Unit'
            );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null.');
        System.assertEquals(0, result.get('< 30 Days'));
        System.assertEquals(0, result.get('30-60 Days'));
        System.assertEquals(0, result.get('60-90 Days'));
        System.assertEquals(0, result.get('> 90 Days'));
    }

    @IsTest
    static void testGetAgingSummaryWithFutureDateRange() {
        Account acc = getTestAccount();

        Test.startTest();
        Map<String, Decimal> result =
            SalesOrderAgingController.getAgingSummary(
                acc.Id,
                System.today().addDays(10),
                System.today().addDays(20),
                null,
                null
            );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null.');
        System.assertEquals(0, result.get('< 30 Days'));
        System.assertEquals(0, result.get('30-60 Days'));
        System.assertEquals(0, result.get('60-90 Days'));
        System.assertEquals(0, result.get('> 90 Days'));
    }

    @IsTest
    static void testGetAgingSummaryWithNullAccount() {
        Test.startTest();
        Map<String, Decimal> result =
            SalesOrderAgingController.getAgingSummary(
                null,
                null,
                null,
                null,
                null
            );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null.');
        System.assertEquals(0, result.get('< 30 Days'));
        System.assertEquals(0, result.get('30-60 Days'));
        System.assertEquals(0, result.get('60-90 Days'));
        System.assertEquals(0, result.get('> 90 Days'));
    }

    @IsTest
    static void testGetServiceRequestSummaryWithDefaultDates() {
        Account acc = getTestAccount();

        Test.startTest();
        Map<String, Integer> result =
            SalesOrderAgingController.getServiceRequestSummary(
                acc.Id,
                null,
                null
            );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null.');

        Integer totalCount = 0;
        for (Integer countValue : result.values()) {
            totalCount += countValue;
        }

        System.assertEquals(
            2,
            totalCount,
            'Service Request summary should count 2 records.'
        );
    }

    @IsTest
    static void testGetServiceRequestSummaryWithDateRange() {
        Account acc = getTestAccount();

        Test.startTest();
        Map<String, Integer> result =
            SalesOrderAgingController.getServiceRequestSummary(
                acc.Id,
                System.today().addDays(-1),
                System.today().addDays(1)
            );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null.');

        Integer totalCount = 0;
        for (Integer countValue : result.values()) {
            totalCount += countValue;
        }

        System.assertEquals(
            2,
            totalCount,
            'Service Request summary should count 2 records within date range.'
        );
    }

    @IsTest
    static void testGetServiceRequestSummaryWithFutureDateRange() {
        Account acc = getTestAccount();

        Test.startTest();
        Map<String, Integer> result =
            SalesOrderAgingController.getServiceRequestSummary(
                acc.Id,
                System.today().addDays(10),
                System.today().addDays(20)
            );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null.');
        System.assertEquals(
            0,
            result.size(),
            'Future date range should return empty service request summary.'
        );
    }

    @IsTest
    static void testGetServiceRequestSummaryWithNullAccount() {
        Test.startTest();
        Map<String, Integer> result =
            SalesOrderAgingController.getServiceRequestSummary(
                null,
                null,
                null
            );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null.');
        System.assertEquals(
            0,
            result.size(),
            'Null accountId should return empty map.'
        );
    }
}