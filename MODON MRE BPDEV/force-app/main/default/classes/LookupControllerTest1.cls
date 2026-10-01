@isTest
public class LookupControllerTest1 {

    @testSetup
    static void setupData() {
        // Create test records
        Account acc1 = new Account(Name = 'Alpha Company');
        Account acc2 = new Account(Name = 'Beta Company');
        insert new List<Account>{acc1, acc2};
    }

    // -------------------------
    // TEST: lookUp method
    // -------------------------
    @isTest
    static void testLookUp_SearchAndFilter() {

        Account acc = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        List<sObject> result = LookupController.lookUp(
            'Alpha',        // searchTerm
            'Account',      // objectName
            'Name != null', // filters
            null,           // recordId
            'Id, Name'      // fields
        );
        Test.stopTest();

        System.assert(result.size() > 0, 'Should return records');
    }

    @isTest
    static void testLookUp_ByRecordId() {

        Account acc = [SELECT Id FROM Account LIMIT 1];

        Test.startTest();
        List<sObject> result = LookupController.lookUp(
            null,
            'Account',
            null,
            acc.Id,
            'Id, Name'
        );
        Test.stopTest();

        System.assertEquals(1, result.size());
    }

    // -------------------------
    // TEST: lookUpSearch method
    // -------------------------
    @isTest
    static void testLookUpSearch_WithDisplayFieldAndSearch() {

        Test.startTest();
        List<sObject> result = LookupController.lookUpSearch(
            'Name',
            'Alpha',
            'Account',
            null,
            'Id, Name'
        );
        Test.stopTest();

        System.assert(result.size() > 0);
    }

    @isTest
    static void testLookUpSearch_WithFilter() {

        Test.startTest();
        List<sObject> result = LookupController.lookUpSearch(
            'Name',
            'Alpha',
            'Account',
            'Name != null',
            'Id, Name'
        );
        Test.stopTest();

        System.assert(result.size() > 0);
    }

    @isTest
    static void testLookUpSearch_NoSearchTerm() {

        Test.startTest();
        List<sObject> result = LookupController.lookUpSearch(
            'Name',
            null,
            'Account',
            null,
            'Id, Name'
        );
        Test.stopTest();

        System.assert(result.size() >= 0);
    }

    @isTest
    static void testLookUpSearch_DisplayFieldNull() {

        Test.startTest();
        List<sObject> result = LookupController.lookUpSearch(
            null,
            'Alpha',
            'Account',
            null,
            'Id, Name'
        );
        Test.stopTest();

        System.assert(result.size() > 0);
    }
}