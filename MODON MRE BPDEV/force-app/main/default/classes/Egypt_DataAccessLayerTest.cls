/**********************************************************************************************************************
* Name               : Egypt_DataAccessLayerTest
* Description        : Test class for Egypt_DataAccessLayer.
* Usage              : Executed during test runs
* Created By         : Shahil Sinha
* --------------------------------------------------------------------------------------------------------------------
* Version       Author           Date            Comment
* 1.0           Shahil Sinha     09 Jun 2026     Initial Draft
******************************************************************************************************************/
@isTest
private class Egypt_DataAccessLayerTest {

    @isTest
    static void testQueryConfiguredObject() {
        Account testAcc = new Account(Name = 'Test Account');
        insert testAcc;

        Map<String, Object> bindParams = new Map<String, Object>{
            'accId' => testAcc.Id
        };

        Test.startTest();
        List<SObject> results = Egypt_DataAccessLayer.query(
            'SalesOrder__c', // Any configured object, though we query with empty results
            'Id = :accId',
            null,
            1,
            bindParams
        );
        Test.stopTest();

        System.assertNotEquals(null, results, 'Results list should not be null');
    }

    @isTest
    static void testQueryDynamicSchemaFallback() {
        // Querying an object not configured in OBJECT_FIELDS like Profile
        Profile p = [SELECT Id FROM Profile LIMIT 1];
        Map<String, Object> bindParams = new Map<String, Object>{
            'profileId' => p.Id
        };

        Test.startTest();
        List<SObject> results = Egypt_DataAccessLayer.query(
            'Profile',
            'Id = :profileId',
            'Name ASC',
            1,
            bindParams
        );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should find one profile record');
        System.assertEquals(p.Id, results[0].Id, 'Profile Id should match');
    }

    @isTest
    static void testQuerySingleRecord() {
        Account testAcc = new Account(Name = 'Single Test Account');
        insert testAcc;

        Map<String, Object> bindParams = new Map<String, Object>{
            'accId' => testAcc.Id
        };

        Test.startTest();
        SObject result = Egypt_DataAccessLayer.querySingle(
            'Account',
            'Id = :accId',
            bindParams
        );
        SObject nullResult = Egypt_DataAccessLayer.querySingle(
            'Account',
            'Id = \'001000000000000AAA\'',
            null
        );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Should find the account record');
        System.assertEquals(testAcc.Id, result.Id, 'Id should match');
        System.assertEquals(null, nullResult, 'Should return null when no record matches');
    }

    @isTest
    static void testQueryAllFields() {
        Account testAcc = new Account(Name = 'All Fields Account');
        insert testAcc;

        Map<String, Object> bindParams = new Map<String, Object>{
            'accId' => testAcc.Id
        };

        Test.startTest();
        List<SObject> results = Egypt_DataAccessLayer.queryAllFields(
            'Account',
            'Id = :accId',
            bindParams
        );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should find the account record');
        System.assertEquals(testAcc.Id, results[0].Id, 'Id should match');
    }

    @isTest
    static void testInvalidObjectNames() {
        Test.startTest();
        try {
            Egypt_DataAccessLayer.query('NonExistentObject__c', 'Id != null', null, 1, null);
            System.assert(false, 'Should throw exception for invalid object name in query');
        } catch (IllegalArgumentException e) {
            System.assert(e.getMessage().contains('schema not found'), 'Expected schema not found exception');
        }

        try {
            Egypt_DataAccessLayer.queryAllFields('NonExistentObject__c', 'Id != null', null);
            System.assert(false, 'Should throw exception for invalid object name in queryAllFields');
        } catch (IllegalArgumentException e) {
            System.assert(e.getMessage().contains('Object type not found'), 'Expected Object type not found exception');
        }
        Test.stopTest();
    }
}