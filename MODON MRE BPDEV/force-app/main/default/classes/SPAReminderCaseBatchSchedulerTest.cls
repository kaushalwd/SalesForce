@IsTest
public class SPAReminderCaseBatchSchedulerTest {

    @IsTest
    static void testScheduler() {
        // Test scheduler
        Test.startTest();
        SPAReminderCaseBatchScheduler scheduler = new SPAReminderCaseBatchScheduler();
        String cronExp = '0 0 * * * ?'; // every hour
        System.schedule('Test SPAReminderCaseBatchScheduler Scheduler', cronExp, scheduler);
        Test.stopTest();
    }
    
}