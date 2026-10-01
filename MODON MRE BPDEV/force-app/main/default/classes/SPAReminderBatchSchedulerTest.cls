@IsTest
private class SPAReminderBatchSchedulerTest {
	@IsTest
    static void testScheduler() {
        // Test scheduler
        Test.startTest();
        SPAReminderBatchScheduler scheduler = new SPAReminderBatchScheduler();
        String cronExp = '0 0 * * * ?'; // every hour
        System.schedule('Test SPAWhatsapp Scheduler', cronExp, scheduler);
        Test.stopTest();
    }
}