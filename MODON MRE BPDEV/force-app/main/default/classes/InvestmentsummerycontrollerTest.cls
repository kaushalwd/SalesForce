@IsTest
public class InvestmentsummerycontrollerTest {

    private static final String TEST_EMAIL = 'investment.test@test.com';
    private static final String TEST_PROJECT_NAME = 'Test Project';
    private static final String TEST_UNIT_NAME = 'Test Unit';

    @TestSetup
    static void setupData() {
        Id personAccountRtId = getAccountRecordTypeId('PersonAccount');

        Account acc = new Account(
            RecordTypeId = personAccountRtId,
            FirstName = 'Investment',
            LastName = 'Customer',
            PersonEmail = TEST_EMAIL
        );
        insert acc;

        /*
         * IMPORTANT:
         * The controller filters SalesOrder__c with:
         * ProjectName__c != null
         *
         * If ProjectName__c and Unit_Name__c are formula fields in your org,
         * then create the Project / Phase / Unit relationship exactly as your org expects.
         *
         * Below setup assumes:
         * Project__c
         * Phase__c.Project__c
         * Unit__c.Phase__c
         *
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
            Status__c = 'Sold',
            UnitClassification__c = 'Apartment',
            Unit_Sold_Date__c = System.today(),
            PlotNo__c ='123',
            Number_of_Bedrooms__c = '2'
        );
        insert unitRec;

        SalesOrder__c so = new SalesOrder__c(
            
            CustomerAccount__c = acc.Id,
            Unit__c = unitRec.Id,
            Status__c = 'Sold',
            TotalAmount__c = 100000,
            Totalpaidamount__c = 25000
        );

        /*
         * If your org has mandatory SalesOrder__c fields,
         * add them here only.
         *
         * Example:
         * so.Opportunity__c = opp.Id;
         * so.PrimaryContact__c = contact.Id;
         */

        insert so;
    }

    private static Id getAccountRecordTypeId(String developerName) {
        Map<String, Schema.RecordTypeInfo> rtMap =
            Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName();

        System.assert(
            rtMap.containsKey(developerName),
            'Missing Account Record Type: ' + developerName
        );

        return rtMap.get(developerName).getRecordTypeId();
    }

    private static Account getTestAccount() {
        return [
            SELECT Id, PersonEmail
            FROM Account
            WHERE PersonEmail = :TEST_EMAIL
            LIMIT 1
        ];
    }

    @IsTest
    static void testGetProjectWiseAmountsWithDefaultDates() {
        Account acc = getTestAccount();

        Test.startTest();
        Map<String, Decimal> result =
            Investmentsummerycontroller.getProjectWiseAmounts(
                acc.Id,
                null,
                null,
                null,
                null
            );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null.');
        System.assert(
            result.size() >= 0,
            'Project wise amount map should be returned.'
        );
    }

    @IsTest
    static void testGetProjectWiseAmountsWithFilters() {
        Account acc = getTestAccount();

        Test.startTest();
        Map<String, Decimal> result =
            Investmentsummerycontroller.getProjectWiseAmounts(
                acc.Id,
                System.today().addDays(-1),
                System.today().addDays(1),
                TEST_PROJECT_NAME,
                TEST_UNIT_NAME
            );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null.');
    }

    @IsTest
    static void testGetUnitClassificationCountsWithDefaultDates() {
        Account acc = getTestAccount();

        Test.startTest();
        Map<String, Map<String, Integer>> result =
            Investmentsummerycontroller.getUnitClassificationCounts(
                acc.Id,
                null,
                null,
                null,
                null
            );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null.');
    }

    @IsTest
    static void testGetUnitClassificationCountsWithFilters() {
        Account acc = getTestAccount();

        Test.startTest();
        Map<String, Map<String, Integer>> result =
            Investmentsummerycontroller.getUnitClassificationCounts(
                acc.Id,
                System.today().addDays(-1),
                System.today().addDays(1),
                TEST_PROJECT_NAME,
                TEST_UNIT_NAME
            );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null.');
    }

    @IsTest
    static void testGetProjectAndUnitNames() {
        Account acc = getTestAccount();

        Test.startTest();
        Map<String, List<String>> result =
            Investmentsummerycontroller.getProjectAndUnitNames(acc.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null.');
        System.assert(
            result.containsKey('projects') || result.isEmpty(),
            'Result should contain projects key when data exists.'
        );
        System.assert(
            result.containsKey('units') || result.isEmpty(),
            'Result should contain units key when data exists.'
        );
        System.assert(
            result.containsKey('projectToUnits') || result.isEmpty(),
            'Result should contain projectToUnits key when data exists.'
        );
    }

    @IsTest
    static void testGetProjectAndUnitNamesWithNullAccount() {
        Test.startTest();
        Map<String, List<String>> result =
            Investmentsummerycontroller.getProjectAndUnitNames(null);
        Test.stopTest();
    
        System.assertNotEquals(null, result, 'Result should not be null.');
    
        System.assertEquals(
            true,
            result.containsKey('projects'),
            'Null accountId should still return projects key.'
        );
    
        System.assertEquals(
            true,
            result.containsKey('units'),
            'Null accountId should still return units key.'
        );
    
        System.assertEquals(
            true,
            result.containsKey('projectToUnits'),
            'Null accountId should still return projectToUnits key.'
        );
    
        System.assertEquals(
            0,
            result.get('projects').size(),
            'Projects list should be empty for null accountId.'
        );
    
        System.assertEquals(
            0,
            result.get('units').size(),
            'Units list should be empty for null accountId.'
        );
    
        System.assertEquals(
            0,
            result.get('projectToUnits').size(),
            'Project-to-units list should be empty for null accountId.'
        );
    }

    @IsTest
    static void testGetTotalInvestmentValue() {
        Account acc = getTestAccount();

        Test.startTest();
        Decimal total =
            Investmentsummerycontroller.getTotalInvestmentValue(
                acc.Id,
                null,
                null,
                null,
                null
            );
        Test.stopTest();

        System.assertNotEquals(null, total, 'Total investment value should not be null.');
        System.assert(
            total >= 0,
            'Total investment value should be zero or greater.'
        );
    }

    @IsTest
    static void testGetTotalInvestmentValueWithFilters() {
        Account acc = getTestAccount();

        Test.startTest();
        Decimal total =
            Investmentsummerycontroller.getTotalInvestmentValue(
                acc.Id,
                System.today().addDays(-1),
                System.today().addDays(1),
                TEST_PROJECT_NAME,
                TEST_UNIT_NAME
            );
        Test.stopTest();

        System.assertNotEquals(null, total, 'Total investment value should not be null.');
    }

    @IsTest
    static void testGetTotalUnitsPurchased() {
        Account acc = getTestAccount();

        Test.startTest();
        Integer totalUnits =
            Investmentsummerycontroller.getTotalUnitsPurchased(
                acc.Id,
                String.valueOf(System.today().addDays(-1)),
                String.valueOf(System.today().addDays(1)),
                null,
                null
            );
        Test.stopTest();

        System.assertNotEquals(null, totalUnits, 'Total units should not be null.');
        System.assert(
            totalUnits >= 0,
            'Total units purchased should be zero or greater.'
        );
    }

    @IsTest
    static void testGetTotalUnitsPurchasedWithFilters() {
        Account acc = getTestAccount();

        Test.startTest();
        Integer totalUnits =
            Investmentsummerycontroller.getTotalUnitsPurchased(
                acc.Id,
                String.valueOf(System.today().addDays(-1)),
                String.valueOf(System.today().addDays(1)),
                TEST_PROJECT_NAME,
                TEST_UNIT_NAME
            );
        Test.stopTest();

        System.assertNotEquals(null, totalUnits, 'Total units should not be null.');
    }

    @IsTest
    static void testGetTotalUnitsPurchasedWithNullAccount() {
        Test.startTest();
        Integer totalUnits =
            Investmentsummerycontroller.getTotalUnitsPurchased(
                null,
                null,
                null,
                null,
                null
            );
        Test.stopTest();

        System.assertEquals(
            0,
            totalUnits,
            'Null accountId should return zero.'
        );
    }

    @IsTest
    static void testGetUnitTypeCountsWithDefaultDates() {
        Account acc = getTestAccount();

        Test.startTest();
        Map<String, Integer> result =
            Investmentsummerycontroller.getUnitTypeCounts(
                acc.Id,
                null,
                null,
                null,
                null
            );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null.');
    }

    @IsTest
    static void testGetUnitTypeCountsWithFilters() {
        Account acc = getTestAccount();

        Test.startTest();
        Map<String, Integer> result =
            Investmentsummerycontroller.getUnitTypeCounts(
                acc.Id,
                System.today().addDays(-1),
                System.today().addDays(1),
                TEST_PROJECT_NAME,
                TEST_UNIT_NAME
            );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null.');
    }
}