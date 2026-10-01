@IsTest
private class UpdateAccountTotalSoldBatchTest {
    @testSetup
    static void seed() {
        // Accounts
        Account a1 = new Account(Name = 'Alpha LLC');
        Account a2 = new Account(Name = 'Beta LLC');
        Account a3 = new Account(Name = 'Gamma LLC'); // will have no qualifying orders
        insert new List<Account>{ a1, a2, a3 };

        // Helper to shorten creation (ADD ANY ORG-REQUIRED FIELDS HERE)
        List<SalesOrder__c> orders = new List<SalesOrder__c>();
        orders.add(newSO(a1.Id, 1000, 'Sold'));       // qualifies
        orders.add(newSO(a1.Id, 250.50, 'Completed'));// qualifies
        orders.add(newSO(a1.Id, 999, 'Cancelled'));       // ignored

        orders.add(newSO(a2.Id, 10, 'Completed'));    // qualifies
        orders.add(newSO(a2.Id, 20, 'Sold'));         // qualifies
        orders.add(newSO(a2.Id, 30, 'Cancelled'));    // ignored

        insert orders;
    }

    @IsTest
    static void testBatchUpdatesTotals() {
        // Run with small batch size to exercise chunking
        Test.startTest();
        Database.executeBatch(new UpdateAccountTotalSoldBatch(), 20);
        Test.stopTest();
    }

    // --- Helpers ---
    private static SalesOrder__c newSO(Id accountId, Decimal amount, String status) {
        SalesOrder__c so = new SalesOrder__c();
        so.CustomerAccount__c = accountId;
        so.TotalAmount__c = amount;
        so.Status__c = status;

        return so;
    }
}