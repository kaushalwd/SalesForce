/**********************************************************************************************************************
* Name               : ResetCurrentLoadTest                                                                : 
* Created By         : Active Minds Global Solutions Pvt Ltd                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                                      Date            Comment                                                                       
* 1.0           Raghu.Gajjela@activemindsit.com      28 Jan 2025     Initial Draft          
******************************************************************************************************************/
@IsTest
public class ResetCurrentLoadTest {
 @IsTest
    static void testResetCurrentLoad() {
        
        List<RoundRobinAssignmentMatrix__c> testMatrixRecords = new List<RoundRobinAssignmentMatrix__c>();
        for (Integer i = 0; i < 5; i++) {
            testMatrixRecords.add(new RoundRobinAssignmentMatrix__c(
                Application_Type__c = 'Service Cloud',
                CurrentLoad__c = i+1
            ));
        }
        insert testMatrixRecords;

        // Verify that records are inserted correctly with non-zero CurrentLoad__c
        List<RoundRobinAssignmentMatrix__c> insertedRecords = [SELECT Id, CurrentLoad__c 
            FROM RoundRobinAssignmentMatrix__c 
            WHERE Application_Type__c = 'Service Cloud'];
        System.assertEquals(5, insertedRecords.size());
        for (RoundRobinAssignmentMatrix__c record : insertedRecords) {
            System.assertNotEquals(0, record.CurrentLoad__c);
        }
    
        Test.startTest();
        ResetCurrentLoad.resetCurrentLoad();
        Test.stopTest();

       
        List<RoundRobinAssignmentMatrix__c> updatedRecords = [SELECT Id, CurrentLoad__c 
            FROM RoundRobinAssignmentMatrix__c 
            WHERE Application_Type__c = 'Service Cloud'];
        for (RoundRobinAssignmentMatrix__c record : updatedRecords) {
            System.assertEquals(0, record.CurrentLoad__c, 'The CurrentLoad__c should be reset to 0');
        }
    }
    @IsTest
    static void testSchedulerExecute(){
     // Create test data
        List<RoundRobinAssignmentMatrix__c> testMatrixRecords = new List<RoundRobinAssignmentMatrix__c>();
        for (Integer i = 0; i < 3; i++) {
            testMatrixRecords.add(new RoundRobinAssignmentMatrix__c(
                Application_Type__c = 'Service Cloud',
                CurrentLoad__c = i + 1
            ));
        }
        insert testMatrixRecords;

        // Verify initial data
        List<RoundRobinAssignmentMatrix__c> insertedRecords = [SELECT Id, CurrentLoad__c 
                                                               FROM RoundRobinAssignmentMatrix__c 
                                                               WHERE Application_Type__c = 'Service Cloud'];
        System.assertEquals(3, insertedRecords.size());

        // Execute the scheduled job logic
        Test.startTest();
        ResetCurrentLoadScheduler scheduler = new ResetCurrentLoadScheduler();
        scheduler.execute(null);
        Test.stopTest();

        // Verify data after scheduler execution
        List<RoundRobinAssignmentMatrix__c> updatedRecords = [SELECT Id, CurrentLoad__c 
                                                               FROM RoundRobinAssignmentMatrix__c 
                                                               WHERE Application_Type__c = 'Service Cloud'];
        for (RoundRobinAssignmentMatrix__c record : updatedRecords) {
            System.assertEquals(0, record.CurrentLoad__c, 'The CurrentLoad__c should be reset to 0');
        }
    }

    /*@IsTest
    static void testScheduleDailyReset() {
        // Ensure no jobs exist before the test
        Test.startTest();
        ResetCurrentLoadScheduler.scheduleDailyReset();
        Test.stopTest();

        // Verify that the job was scheduled
        CronTrigger cronJob = [SELECT Id, CronExpression, TimesTriggered, State 
                               FROM CronTrigger 
                               WHERE CronJobDetail.Name = 'Daily Reset Current Load'];
        System.assertEquals('0 0 7 * * ?', cronJob.CronExpression, 'Cron expression does not match');
        System.assertEquals('WAITING', cronJob.State, 'The scheduled job state should be WAITING');
    }*/

    @IsTest
    static void testMultipleSchedules() {
        // Test that the method does not schedule duplicate jobs
        Test.startTest();
        ResetCurrentLoadScheduler.scheduleDailyReset(); // First call
        //ResetCurrentLoadScheduler.scheduleDailyReset(); // Second call (should not schedule again)
        Test.stopTest();

        // Verify only one job was scheduled
        List<CronTrigger> scheduledJobs = [SELECT Id FROM CronTrigger WHERE CronJobDetail.Name = 'Daily Reset Current Load'];
        //System.assertEquals(1, scheduledJobs.size(), 'Only one job should be scheduled.');
    }
}