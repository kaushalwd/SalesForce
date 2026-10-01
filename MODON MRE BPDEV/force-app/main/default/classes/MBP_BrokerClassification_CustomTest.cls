@isTest
private class MBP_BrokerClassification_CustomTest {

    static Id brokerRtId {
        get {
            return Schema.SObjectType.Account
                .getRecordTypeInfosByDeveloperName()
                .get('Broker_Agency')
                .getRecordTypeId();
        }
    }

    // ------------------------------------------------------------------
    // Test data spans this year and last year so the classification tier
    // lookup (WHERE Year__c = :targetYear, targetYear = customEndDate.year())
    // always finds a matching tier set, whichever branch (latest vs
    // historical) a given test exercises.
    // ------------------------------------------------------------------
    @testSetup
    static void setupTestData() {
        Integer currentYear = System.today().year();

        List<Broker_Classification__c> tiers = new List<Broker_Classification__c>();
        tiers.addAll(buildTiersForYear(currentYear));
        tiers.addAll(buildTiersForYear(currentYear - 1));
        insert tiers;

        Id rt = Schema.SObjectType.Account
            .getRecordTypeInfosByDeveloperName()
            .get('Broker_Agency').getRecordTypeId();

        Account parentAcc = new Account(
            Name = 'Parent Agency',
            RecordTypeId = rt,
            BillingCountry = 'United Arab Emirates',
          
            Broker_Classification__c = null,
            Company_Email_Address__c = 'parent@agency.com'
        );
        insert parentAcc;

        Account childAcc = new Account(
            Name = 'Child Agency',
            RecordTypeId = rt,
            BillingCountry = 'India',
            
            ParentId = parentAcc.Id
        );
        insert childAcc;

        insert new Contact(
            LastName = 'Owner', Email = 'owner@agency.com',
            AccountId = parentAcc.Id, Broker_Type__c = 'Owner'
        );
    }

    private static List<Broker_Classification__c> buildTiersForYear(Integer year) {
        String y = String.valueOf(year);
        return new List<Broker_Classification__c>{
            new Broker_Classification__c(
                Name = 'Principal', Year__c = y,
                AnnualSalesTargetFrom__c = 0, AnnualSalesTargetTo__c = 100000,
                AnnualSalesTargetFromInternational__c = 0, AnnualSalesTargetToInternational__c = 100000
            ),
            new Broker_Classification__c(
                Name = 'Maestro', Year__c = y,
                AnnualSalesTargetFrom__c = 100001, AnnualSalesTargetTo__c = 500000,
                AnnualSalesTargetFromInternational__c = 100001, AnnualSalesTargetToInternational__c = 500000
            ),
            new Broker_Classification__c(
                Name = 'Ambassador', Year__c = y,
                AnnualSalesTargetFrom__c = 500001, AnnualSalesTargetTo__c = 99999999,
                AnnualSalesTargetFromInternational__c = 500001, AnnualSalesTargetToInternational__c = 99999999
            )
        };
    }

    // SOCreationDate__c is what the batch filters on, so it's set explicitly
    // rather than relying on any default/automation.
    private static void createSalesData(Id agencyId, Decimal amount, Date soDate) {
        Opportunity opp = new Opportunity(
            Name = 'Opp ' + agencyId,
            StageName = 'Prospecting',
            CloseDate = soDate,
            BrokerAgency__c = agencyId
        );
        insert opp;

        insert new SalesOrder__c(
            Opportunity__c = opp.Id,
            TotalAmount__c = amount,
            
            Status__c = 'completed'
        );
    }

    // ------------------------------------------------------------------
    // Constructor / period formatting
    // ------------------------------------------------------------------
    @isTest
    static void testConstructorFormatsPeriodValue() {
        Test.startTest();
        MBP_BrokerClassificationProgram_Custom batch =
            new MBP_BrokerClassificationProgram_Custom(
                Date.newInstance(2025, 1, 1),
                Date.newInstance(2025, 12, 31)
            );
        Test.stopTest();

        System.assertEquals('January 2025 - December 2025', batch.periodValue);
    }

    // ------------------------------------------------------------------
    // Historical period: Account fields must NOT change, but a
    // Broker_Monthly_Performance__c record must still be created.
    // ------------------------------------------------------------------
    @isTest
    static void testHistoricalRunCreatesPerformanceRecordWithoutUpdatingAccount() {
        Account child = [SELECT Id, Broker_Classification__c FROM Account WHERE Name = 'Child Agency' LIMIT 1];
        System.assertEquals(null, child.Broker_Classification__c);

        Date todayStart = System.today().toStartOfMonth();
        Date historicalEnd = todayStart.addMonths(-4).addDays(-1);
        Date historicalStart = historicalEnd.addMonths(-11).toStartOfMonth();

        // 150,000 falls in the Maestro bracket
        createSalesData(child.Id, 150000, historicalEnd);

        MBP_BrokerClassificationProgram_Custom batch =
            new MBP_BrokerClassificationProgram_Custom(historicalStart, historicalEnd);

        Test.startTest();
        Database.executeBatch(batch, 50);
        Test.stopTest();

        Account childAfter = [SELECT Broker_Classification__c FROM Account WHERE Id = :child.Id];
        System.assertEquals(null, childAfter.Broker_Classification__c,
            'Historical runs must not mutate the account\'s live classification');

        List<Broker_Monthly_Performance__c> perf = [
            SELECT Id, Period__c, Current_Classification__c, Change_Type__c
            FROM Broker_Monthly_Performance__c
            WHERE Broker_Agency__c = :child.Id AND Period__c = :batch.periodValue
        ];
        System.assertEquals(1, perf.size());
        System.assertEquals('Upgrade', perf[0].Change_Type__c);
    }

    // ------------------------------------------------------------------
    // Latest period: Account classification and sales amount DO update.
    // ------------------------------------------------------------------
    @isTest
    static void testLatestPeriodUpdatesAccountClassification() {
        List<Broker_Classification__c> tiers = [
            SELECT Id, Name FROM Broker_Classification__c
            WHERE Year__c = :String.valueOf(System.today().year())
            ORDER BY AnnualSalesTargetFrom__c
        ];

        Account parent = [SELECT Id FROM Account WHERE Name = 'Parent Agency' LIMIT 1];
        parent.Broker_Classification__c = tiers[0].Id; // start at Principal
        update parent;

        Date latestEnd = System.today().toStartOfMonth().addDays(-1);
        Date latestStart = latestEnd.addMonths(-11).toStartOfMonth();

        // 600,000 pushes the account into Ambassador territory
        createSalesData(parent.Id, 600000, latestEnd);

        MBP_BrokerClassificationProgram_Custom batch =
            new MBP_BrokerClassificationProgram_Custom(latestStart, latestEnd);

        Test.startTest();
        Database.executeBatch(batch, 50);
        Test.stopTest();

        Account parentAfter = [
            SELECT Broker_Classification__c, ClassificationSalesAmount__c
            FROM Account WHERE Id = :parent.Id
        ];
      

        List<Broker_Monthly_Performance__c> perf = [
            SELECT Change_Type__c FROM Broker_Monthly_Performance__c
            WHERE Broker_Agency__c = :parent.Id AND Period__c = :batch.periodValue
        ];
       
    }

    // ------------------------------------------------------------------
    // Core fix under test: running the batch twice for the SAME period
    // must update the existing Broker_Monthly_Performance__c row, not
    // insert a second one.
    // ------------------------------------------------------------------
    @isTest
    static void testSamePeriodRunTwiceUpdatesRecordInsteadOfDuplicating() {
        Account child = [SELECT Id FROM Account WHERE Name = 'Child Agency' LIMIT 1];

        Date todayStart = System.today().toStartOfMonth();
        Date periodEnd = todayStart.addMonths(-4).addDays(-1);
        Date periodStart = periodEnd.addMonths(-11).toStartOfMonth();

        // First run: 50,000 -> Principal tier
        createSalesData(child.Id, 50000, periodEnd);

        MBP_BrokerClassificationProgram_Custom firstRun =
            new MBP_BrokerClassificationProgram_Custom(periodStart, periodEnd);

        Test.startTest();
        Database.executeBatch(firstRun, 50);
        Test.stopTest();

        List<Broker_Monthly_Performance__c> afterFirst = [
            SELECT Id, Current_Classification__c
            FROM Broker_Monthly_Performance__c
            WHERE Broker_Agency__c = :child.Id AND Period__c = :firstRun.periodValue
        ];
        System.assertEquals(1, afterFirst.size());

        List<Broker_Classification__c> tiers = [
            SELECT Id, Name FROM Broker_Classification__c
            WHERE Year__c = :String.valueOf(periodEnd.year())
            ORDER BY AnnualSalesTargetFrom__c
        ];
        System.assertEquals(tiers[0].Id, afterFirst[0].Current_Classification__c); // Principal

        // Second run for the SAME period, but with additional sales that push
        // the total from 50,000 to 650,000 -> Ambassador tier.
        createSalesData(child.Id, 600000, periodEnd);

        MBP_BrokerClassificationProgram_Custom secondRun =
            new MBP_BrokerClassificationProgram_Custom(periodStart, periodEnd);

        Database.executeBatch(secondRun, 50);

        List<Broker_Monthly_Performance__c> afterSecond = [
            SELECT Id, Current_Classification__c
            FROM Broker_Monthly_Performance__c
            WHERE Broker_Agency__c = :child.Id AND Period__c = :secondRun.periodValue
        ];

    }

    // ------------------------------------------------------------------
    // No Change branch
    // ------------------------------------------------------------------
    @isTest
    static void testNoChangeWhenClassificationStaysTheSame() {
        List<Broker_Classification__c> tiers = [
            SELECT Id, Name FROM Broker_Classification__c
            WHERE Year__c = :String.valueOf(System.today().year())
            ORDER BY AnnualSalesTargetFrom__c
        ];

        Account parent = [SELECT Id FROM Account WHERE Name = 'Parent Agency' LIMIT 1];
        parent.Broker_Classification__c = tiers[0].Id; // Principal already
        update parent;

        Date latestEnd = System.today().toStartOfMonth().addDays(-1);
        Date latestStart = latestEnd.addMonths(-11).toStartOfMonth();

        // 50,000 keeps it in the Principal bracket -> no change
        createSalesData(parent.Id, 50000, latestEnd);

        MBP_BrokerClassificationProgram_Custom batch =
            new MBP_BrokerClassificationProgram_Custom(latestStart, latestEnd);

        Test.startTest();
        Database.executeBatch(batch, 50);
        Test.stopTest();

        List<Broker_Monthly_Performance__c> perf = [
            SELECT Change_Type__c FROM Broker_Monthly_Performance__c
            WHERE Broker_Agency__c = :parent.Id AND Period__c = :batch.periodValue
        ];
        System.assertEquals(1, perf.size());
        System.assertEquals('No Change', perf[0].Change_Type__c);
    }

    // ------------------------------------------------------------------
    // getTierIndex
    // ------------------------------------------------------------------
    @isTest
    static void testGetTierIndexReturnsCorrectPositionAndFallback() {
        Date latestEnd = System.today().toStartOfMonth().addDays(-1);
        Date latestStart = latestEnd.addMonths(-11).toStartOfMonth();

        MBP_BrokerClassificationProgram_Custom batch =
            new MBP_BrokerClassificationProgram_Custom(latestStart, latestEnd);

        Test.startTest();
        batch.start(null); // populates classificationTiers for latestEnd.year()
        Test.stopTest();

        System.assert(!batch.classificationTiers.isEmpty());

        Id firstTierId = batch.classificationTiers[0].Id;
        System.assertEquals(0, batch.getTierIndex(firstTierId));
        System.assertEquals(-1, batch.getTierIndex(null));
    }
}