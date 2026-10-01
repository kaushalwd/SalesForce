@isTest
private class PurchaseInformationControllerTest {

    @TestSetup
    static void setupTestData() {
        // Create test Account
        Account testAccount = new Account(
            FirstName = 'Test',
            LastName = 'Buyer'
        );
        insert testAccount;

        // Create Unit
        Unit__c unit = new Unit__c(
            Name = 'Unit A',
            Status__c = 'Sold',
            PlotNo__c = 'AB2-CK071'
        );
        insert unit;
        
        // Create Unit2
        Unit__c unit2 = new Unit__c(
            Name = 'Unit B',
            Status__c = 'Sold',
            PlotNo__c = 'AB2-CK072'
        );
        insert unit2;
        
        // Create Opportunity
        Opportunity testOpp = new Opportunity(
            Name = 'Test Purchase Opportunity',
            AccountId = testAccount.Id,
            StageName = 'Closed Won',
            CloseDate = Date.today().addDays(10),
            LanguagePreference__c = 'English'
        );
        insert testOpp;

        // Create SalesOrder
        SalesOrder__c so = new SalesOrder__c(
            CustomerAccount__c = testAccount.Id,
            Status__c = 'Completed',
            Unit__c = unit.Id,
            Opportunity__c = testOpp.Id,
            TotalAmount__c = 100000000,
            Totalpaidamount__c = 5000000
        );
        insert so;
        
        // Create SalesOrder2
        SalesOrder__c so2 = new SalesOrder__c(
            CustomerAccount__c = testAccount.Id,
            Status__c = 'Completed',
            Unit__c = unit2.Id,
            Opportunity__c = testOpp.Id,
            TotalAmount__c = 1000000000,
            Totalpaidamount__c = 50000000
        );
        insert so2;
    }

    @isTest
    static void testGetPurchaseInformationDataWithValidId() {
        Account acc = [SELECT Id FROM Account WHERE LastName = 'Buyer' LIMIT 1];
        
        // Fetch sales order again to make sure record is really inserted
        List<SalesOrder__c> salesOrders = [SELECT Id,Status__c,Unit__r.Status__c FROM SalesOrder__c WHERE CustomerAccount__c = :acc.Id];
        for(SalesOrder__c so:salesOrders){
            system.debug(so.Unit__r.Status__c);
        }
        System.assert(!salesOrders.isEmpty(), 'Test SalesOrder was not created properly!');

        Test.startTest();
        Map<String, String> result = PurchaseInformationController.getPurchaseInformationData(acc.Id);
        Test.stopTest();

        System.debug('Valid Id Result: ' + result);

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.size() > 0, 'Should return at least one field value');

        // Key assertions
        System.assert(result.containsKey('Owned Properties'), 'Should contain Owned Properties');
        System.assert(result.containsKey('Collected Amount'), 'Should contain Collected Amount');
    }

    @isTest
    static void testGetPurchaseInformationDataWithInvalidId() {
        Test.startTest();
        Map<String, String> result = PurchaseInformationController.getPurchaseInformationData('');
        Test.stopTest();

        System.assertEquals(0, result.size(), 'Should return empty map for invalid ID');
    }

    @isTest
    static void testGetPurchaseInformationDataWithNullId() {
        Test.startTest();
        Map<String, String> result = PurchaseInformationController.getPurchaseInformationData(null);
        Test.stopTest();

        System.assertEquals(0, result.size(), 'Should return empty map for null ID');
    }

    @isTest
    static void testGetPurchaseInformationDataWithMissingOpportunity() {
        Account acc = [SELECT Id FROM Account WHERE LastName = 'Buyer' LIMIT 1];

        // Delete Opportunity linked to Account
        List<Opportunity> oppList = [SELECT Id FROM Opportunity WHERE AccountId = :acc.Id];
        if (!oppList.isEmpty()) {
            delete oppList;
        }

        // Fetch existing SalesOrder
        List<SalesOrder__c> existingSalesOrders = [SELECT Id FROM SalesOrder__c WHERE CustomerAccount__c = :acc.Id];
        System.assert(!existingSalesOrders.isEmpty(), 'No SalesOrder exists for test Account!');

        Test.startTest();
        Map<String, String> result = PurchaseInformationController.getPurchaseInformationData(acc.Id);
        Test.stopTest();

        System.debug('Missing Opportunity Result: ' + result);

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.size() > 0, 'Should return some field values even without Opportunity');
        System.assert(result.containsKey('Owned Properties'), 'Should contain Owned Properties');
        System.assert(result.containsKey('Collected Amount'), 'Should contain Collected Amount');
    }
}