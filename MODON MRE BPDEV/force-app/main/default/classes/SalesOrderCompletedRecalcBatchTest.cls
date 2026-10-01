/**
 * @description       : 
 * @author            : Krishna Chaitanya
 * @group             : 
 * @last modified on  : 12-08-2025
 * @last modified by  : Krishna Chaitanya
**/
@IsTest
public class SalesOrderCompletedRecalcBatchTest {

    @IsTest
    static void testBatchProcessesOnlyCompletedSO() {

        // Create test SalesOrders
        List<SalesOrder__c> testSOs = new List<SalesOrder__c>();
        
        // 3 completed SOs
        for (Integer i = 0; i < 3; i++) {
            testSOs.add(new SalesOrder__c(
                Status__c = 'Completed'
            ));
        }

        // 2 NON-completed SOs — should NOT be processed
        for (Integer i = 0; i < 2; i++) {
            testSOs.add(new SalesOrder__c(
                Status__c = 'Completed'
            ));
        }

        insert testSOs;


        Test.startTest();
        // Execute batch
        Database.executeBatch(new SalesOrderCompletedRecalcBatch(), 200);
        Test.stopTest();

      
    }
}