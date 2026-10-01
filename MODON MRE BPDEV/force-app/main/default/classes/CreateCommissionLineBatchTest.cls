@isTest
public class CreateCommissionLineBatchTest {
    @isTest
    static void testBatchable() {
        // Prepare test data matching query conditions
        List<SalesOrder__c> testOrders = new List<SalesOrder__c>();
        for (Integer i = 0; i < 3; i++) {
            SalesOrder__c so = new SalesOrder__c();
            so.Status__c = 'Completed'; 
            so.SPAStatus__c = 'Pending for Validation'; 
            so.Resale__c = false;
            so.UsedForCommissionTesting__c = true; 
            so.OwnerId = UserInfo.getUserId();
            testOrders.add(so);
        }
        insert testOrders;

        Test.startTest();
        CreateCommissionLineBatch batch = new CreateCommissionLineBatch(null);
        Database.executeBatch(batch);
        Test.stopTest();
        
        CreateExternalCommissionLineBatch batch1 = new CreateExternalCommissionLineBatch();
        Database.executeBatch(batch1);
        List<SalesOrder__c> result = [
            SELECT Id, Status__c, SPAStatus__c, Resale__c, UsedForCommissionTesting__c
            FROM SalesOrder__c
            WHERE UsedForCommissionTesting__c = true
        ];
        System.assertEquals(3, result.size());
    }
    @isTest public static void schedulableTestClass(){
        Test.startTest();
        String cronExp = '0 0 0 ? * * *'; // runs at midnight (example)
        String jobId = System.schedule('CreateCommissionLineBatch', cronExp, new CreateCommissionLineBatch(null));
        Test.stopTest();
    }
}