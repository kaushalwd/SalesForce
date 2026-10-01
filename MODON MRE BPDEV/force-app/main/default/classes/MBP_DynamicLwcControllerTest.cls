@isTest
private class MBP_DynamicLwcControllerTest {

    @testSetup
    static void setupData() {
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 10; i++) {
            accounts.add(new Account(Name = 'Test Account ' + i));
        }
        insert accounts;
    }

    @isTest
    static void testFetchRecords() {
        Test.startTest();
        List<String> fields = new List<String>{'Id', 'Name'};
        List<SObject> results = MBP_DynamicLwcController.fetchRecords(
            'Account',
            fields,
            5,           // pageSize
            1,           // pageNumber
            'Name',      // sortBy
            false        // isDesc
        );
        Test.stopTest();

        System.assertEquals(5, results.size(), 'Should return 5 records');
        System.assertEquals(true, results[0] instanceof Account);
        System.assertNotEquals(null, results[0].get('Name'));
    }

    @isTest
    static void testFetchRecordsDescending() {
        Test.startTest();
        List<String> fields = new List<String>{'Id', 'Name'};
        List<SObject> results = MBP_DynamicLwcController.fetchRecords(
            'Account',
            fields,
            5,           // pageSize
            2,           // pageNumber
            'Name',      // sortBy
            true         // isDesc
        );
        Test.stopTest();

        System.assertEquals(5, results.size(), 'Should return second page of 5 records');
    }

    @isTest
    static void testFetchTotalCount() {
        Test.startTest();
        Integer count = MBP_DynamicLwcController.fetchTotalCount('Account');
        Integer countNull = MBP_DynamicLwcController.fetchTotalCount(null);
        Test.stopTest();

        System.assertEquals(10, count, 'Total count should match number of inserted Accounts');
        System.assertEquals(0, countNull, 'Total count should be 0 for null input');
    }

    @isTest
    static void testFetchRecordsWithInvalidInputs() {
        List<SObject> emptyList = MBP_DynamicLwcController.fetchRecords('', null, 5, 1, 'Name', false);
        List<SObject> emptyFields = MBP_DynamicLwcController.fetchRecords('Account', new List<String>{' '}, 5, 1, 'Name', false);
        System.assertEquals(0, emptyList.size(), 'Should return empty list for invalid input');
        System.assertEquals(0, emptyFields.size(), 'Should return empty list for blank field list');
    }
}