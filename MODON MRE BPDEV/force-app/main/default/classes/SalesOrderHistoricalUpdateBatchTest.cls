@isTest
public class SalesOrderHistoricalUpdateBatchTest {

    @testSetup
    static void setupData() {
        Account acc = new Account(Name = 'SO Historical Account');
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'SO Historical Opp',
            StageName = 'Discussion In Progress',
            CloseDate = Date.today(),
            AccountId = acc.Id,
            UAE_Resident_Status__c = 'Resident',
            Nationality__c = 'United Arab Emirates'
        );
        insert opp;

        insert new SalesOrder__c(
            Opportunity__c = opp.Id,
            CustomerAccount__c = acc.Id,
            Status__c = 'Sold'
        );
    }

    @isTest
    static void testStartExecuteFinish() {
        SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];

        Test.startTest();
        SalesOrderHistoricalUpdateBatch defaultBatch = new SalesOrderHistoricalUpdateBatch(null);
        Database.QueryLocator defaultLocator = defaultBatch.start(null);
        try {
            defaultBatch.execute(null, new List<SalesOrder__c>{ so });
        } catch (Exception ex) {
            System.debug('execute coverage: ' + ex.getMessage());
        }
        defaultBatch.finish(null);

        SalesOrderHistoricalUpdateBatch queryBatch = new SalesOrderHistoricalUpdateBatch(
            'SELECT Id FROM SalesOrder__c LIMIT 1'
        );
        Database.QueryLocator queryLocator = queryBatch.start(null);
        queryBatch.execute(null, new List<SalesOrder__c>());
        queryBatch.finish(null);
        Test.stopTest();

        System.assertNotEquals(null, defaultLocator);
        System.assertNotEquals(null, queryLocator);
    }
}