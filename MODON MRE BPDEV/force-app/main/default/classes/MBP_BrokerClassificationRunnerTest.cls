/**
 * @description Test class for MBP_BrokerClassificationRunner
 * @author Sanath Manohar
 * @date July 2026
 *
 * NOTE: Adjust the Broker_Classification__c object/field API names below if they
 * differ in your org (assumed based on the Broker_Classification__r relationship
 * and AnnualSalesTargetFrom__c field referenced in the controller's SOQL).
 */
@isTest
private class MBP_BrokerClassificationRunnerTest {

    private static Id brokerRecordTypeId;

    @testSetup
    static void setupData() {
        brokerRecordTypeId = Schema.SObjectType.Account
            .getRecordTypeInfosByDeveloperName()
            .get('Broker_Agency')
            .getRecordTypeId();

        // Classification tiers
        Broker_Classification__c standardTier = new Broker_Classification__c(
            Name = 'Standard',
            AnnualSalesTargetFrom__c = 0
        );
        Broker_Classification__c principalTier = new Broker_Classification__c(
            Name = 'Principal',
            AnnualSalesTargetFrom__c = 1000000
        );
        insert new List<Broker_Classification__c>{ standardTier, principalTier };

        // Classified broker accounts
        List<Account> brokerAccounts = new List<Account>();
        brokerAccounts.add(new Account(
            Name = 'Test Broker Agency - Standard',
            RecordTypeId = brokerRecordTypeId,
            Broker_Classification__c = standardTier.Id
        ));
        brokerAccounts.add(new Account(
            Name = 'Test Broker Agency - Principal',
            RecordTypeId = brokerRecordTypeId,
            Broker_Classification__c = principalTier.Id
        ));

        // Unclassified broker account
        brokerAccounts.add(new Account(
            Name = 'Test Broker Agency - Unclassified',
            RecordTypeId = brokerRecordTypeId
        ));

        insert brokerAccounts;
    }

    // ------------------------------------------------------------------
    // runBatchForPeriod - success path
    // ------------------------------------------------------------------
    @isTest
    static void testRunBatchForPeriod_Success() {
        Date endDate = System.today().toStartOfMonth().addDays(-1); // last day of previous month
        Date startDate = endDate.addMonths(-11).toStartOfMonth();

        String startDateStr = String.valueOf(startDate);
        String endDateStr = String.valueOf(endDate);

        Test.startTest();
        Map<String, Object> result = MBP_BrokerClassificationRunner.runBatchForPeriod(startDateStr, endDateStr);
        Test.stopTest();

        System.assertNotEquals(null, result.get('jobId'), 'Expected a batch job Id to be returned');
        System.assertEquals(3, (Integer) result.get('accountCount'), 'Expected 3 broker accounts to be counted');
        System.assertEquals(startDate, result.get('startDate'), 'Start date should match input');
        System.assertEquals(endDate, result.get('endDate'), 'End date should match input');
    }

    // ------------------------------------------------------------------
    // runBatchForPeriod - validation failures
    // ------------------------------------------------------------------
    @isTest
    static void testRunBatchForPeriod_EndDateInFuture_ThrowsException() {
        Date endDate = System.today().addDays(5);
        Date startDate = endDate.addMonths(-11);

        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            MBP_BrokerClassificationRunner.runBatchForPeriod(String.valueOf(startDate), String.valueOf(endDate));
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Expected exception when end date is in the future or current month');
    }

    @isTest
    static void testRunBatchForPeriod_EndDateInCurrentMonth_ThrowsException() {
        Date endDate = System.today();
        Date startDate = endDate.addMonths(-11);

        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            MBP_BrokerClassificationRunner.runBatchForPeriod(String.valueOf(startDate), String.valueOf(endDate));
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Expected exception when end date falls in the current month');
    }

    @isTest
    static void testRunBatchForPeriod_StartAfterEnd_ThrowsException() {
        Date endDate = System.today().toStartOfMonth().addDays(-1);
        Date startDate = endDate.addDays(5); // start after end

        Boolean exceptionThrown = false;
        String errorMessage = '';
        Test.startTest();
        try {
            MBP_BrokerClassificationRunner.runBatchForPeriod(String.valueOf(startDate), String.valueOf(endDate));
        } catch (AuraHandledException e) {
            exceptionThrown = true;
            errorMessage = e.getMessage();
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Expected exception when start date is after end date');
    }

    @isTest
    static void testRunBatchForPeriod_NotTwelveMonths_ThrowsException() {
        Date endDate = System.today().toStartOfMonth().addDays(-1);
        Date startDate = endDate.addMonths(-5); // only 5 months, not 11

        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            MBP_BrokerClassificationRunner.runBatchForPeriod(String.valueOf(startDate), String.valueOf(endDate));
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Expected exception when period is not exactly 12 months');
    }

    @isTest
    static void testRunBatchForPeriod_InvalidDateFormat_ThrowsException() {
        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            MBP_BrokerClassificationRunner.runBatchForPeriod('not-a-date', '2025-12-31');
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Expected exception when date string cannot be parsed');
    }

    // ------------------------------------------------------------------
    // getClassificationSummary
    // ------------------------------------------------------------------
    @isTest
    static void testGetClassificationSummary_ReturnsClassifiedAndUnclassifiedCounts() {
        Test.startTest();
        List<Map<String, Object>> summary = MBP_BrokerClassificationRunner.getClassificationSummary();
        Test.stopTest();

        System.assertNotEquals(0, summary.size(), 'Expected at least one tier in the summary');

        Boolean foundUnclassified = false;
        for (Map<String, Object> tier : summary) {
            if (tier.get('tierName') == 'Unclassified') {
                foundUnclassified = true;
                System.assertEquals(1, (Integer) tier.get('count'), 'Expected exactly 1 unclassified account');
            }
        }
        System.assert(foundUnclassified, 'Expected an Unclassified tier entry given one unclassified account exists');
    }

    @isTest
    static void testGetClassificationSummary_NoUnclassifiedAccounts() {
        // Classify the previously unclassified account so no unclassified accounts remain
        Account unclassified = [
            SELECT Id
            FROM Account
            WHERE Name = 'Test Broker Agency - Unclassified'
            LIMIT 1
        ];
        Broker_Classification__c anyTier = [SELECT Id FROM Broker_Classification__c LIMIT 1];
        unclassified.Broker_Classification__c = anyTier.Id;
        update unclassified;

        Test.startTest();
        List<Map<String, Object>> summary = MBP_BrokerClassificationRunner.getClassificationSummary();
        Test.stopTest();

        for (Map<String, Object> tier : summary) {
            System.assertNotEquals('Unclassified', tier.get('tierName'), 'Should not have an Unclassified tier when all accounts are classified');
        }
    }
}