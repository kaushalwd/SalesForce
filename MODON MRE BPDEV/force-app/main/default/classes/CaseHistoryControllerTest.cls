@IsTest
private class CaseHistoryControllerTest {

    private static final String TEST_EMAIL = 'case.history.safe@test.com';
    private static final String TEST_ACCOUNT_NAME = 'Test Case History Safe Account';

    @TestSetup
    static void setupTestData() {
        Account acc = createTestAccount();
        insert acc;
    }

    private static Account createTestAccount() {
        Map<String, Schema.RecordTypeInfo> rtMap =
            Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName();

        if (rtMap.containsKey('PersonAccount')) {
            return new Account(
                RecordTypeId = rtMap.get('PersonAccount').getRecordTypeId(),
                FirstName = 'Case',
                LastName = 'History Safe Customer',
                PersonEmail = TEST_EMAIL
            );
        }

        if (rtMap.containsKey('OrganizationAccount')) {
            return new Account(
                RecordTypeId = rtMap.get('OrganizationAccount').getRecordTypeId(),
                Name = TEST_ACCOUNT_NAME
            );
        }

        for (Schema.RecordTypeInfo rtInfo : rtMap.values()) {
            if (rtInfo.isAvailable()) {
                return new Account(
                    RecordTypeId = rtInfo.getRecordTypeId(),
                    Name = TEST_ACCOUNT_NAME
                );
            }
        }

        return new Account(
            Name = TEST_ACCOUNT_NAME
        );
    }

    private static Account getTestAccount() {
        List<Account> accounts = [
            SELECT Id, Name, PersonEmail, RecordType.DeveloperName
            FROM Account
            WHERE PersonEmail = :TEST_EMAIL
               OR Name = :TEST_ACCOUNT_NAME
            LIMIT 1
        ];

        System.assertEquals(
            1,
            accounts.size(),
            'Test Account should exist.'
        );

        return accounts[0];
    }

    @IsTest
    static void testGetCaseHistoryDataWithDefaultDates() {
        Account acc = getTestAccount();

        Test.startTest();
        Map<String, String> result =
            CaseHistoryController.getCaseHistoryData(
                acc.Id,
                null,
                null
            );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null.');
    }

    @IsTest
    static void testGetCaseHistoryDataWithDateRange() {
        Account acc = getTestAccount();

        Test.startTest();
        Map<String, String> result =
            CaseHistoryController.getCaseHistoryData(
                acc.Id,
                System.today().addDays(-1),
                System.today().addDays(1)
            );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null.');
    }

    @IsTest
    static void testGetCaseHistoryDataWithFutureDateRange() {
        Account acc = getTestAccount();

        Test.startTest();
        Map<String, String> result =
            CaseHistoryController.getCaseHistoryData(
                acc.Id,
                System.today().addDays(10),
                System.today().addDays(20)
            );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null.');
        System.assertEquals(
            false,
            result.containsKey('Total Cases Tooltip'),
            'Tooltip should not exist because no Case records are created.'
        );
    }

    @IsTest
    static void testGetCaseListAll() {
        Account acc = getTestAccount();

        Test.startTest();
        List<Case> result =
            CaseHistoryController.getCaseList(
                acc.Id,
                null,
                null,
                null
            );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null.');
        System.assertEquals(
            0,
            result.size(),
            'No Case records are created in this safe UAT test setup.'
        );
    }

    @IsTest
    static void testGetCaseListOpen() {
        Account acc = getTestAccount();

        Test.startTest();
        List<Case> result =
            CaseHistoryController.getCaseList(
                acc.Id,
                null,
                null,
                'open'
            );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null.');
        System.assertEquals(
            0,
            result.size(),
            'Open filter should safely return empty list.'
        );
    }

    @IsTest
    static void testGetCaseListClosed() {
        Account acc = getTestAccount();

        Test.startTest();
        List<Case> result =
            CaseHistoryController.getCaseList(
                acc.Id,
                null,
                null,
                'closed'
            );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null.');
        System.assertEquals(
            0,
            result.size(),
            'Closed filter should safely return empty list.'
        );
    }

    @IsTest
    static void testGetCaseListBreached() {
        Account acc = getTestAccount();

        Test.startTest();
        List<Case> result =
            CaseHistoryController.getCaseList(
                acc.Id,
                null,
                null,
                'breached'
            );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null.');
        System.assertEquals(
            0,
            result.size(),
            'Breached filter should safely return empty list.'
        );
    }

    @IsTest
    static void testGetCaseListWithDateRange() {
        Account acc = getTestAccount();

        Test.startTest();
        List<Case> result =
            CaseHistoryController.getCaseList(
                acc.Id,
                System.today().addDays(-1),
                System.today().addDays(1),
                'open'
            );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null.');
        System.assertEquals(
            0,
            result.size(),
            'Date range query should safely return empty list.'
        );
    }

    @IsTest
    static void testGetCaseListFutureDateRange() {
        Account acc = getTestAccount();

        Test.startTest();
        List<Case> result =
            CaseHistoryController.getCaseList(
                acc.Id,
                System.today().addDays(10),
                System.today().addDays(20),
                null
            );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null.');
        System.assertEquals(
            0,
            result.size(),
            'Future date range should return empty list.'
        );
    }

    @IsTest
    static void testGetCaseListWithNullRecordId() {
        Test.startTest();
        List<Case> result =
            CaseHistoryController.getCaseList(
                null,
                null,
                null,
                null
            );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null.');
        System.assertEquals(
            0,
            result.size(),
            'Null recordId should return empty list.'
        );
    }
}