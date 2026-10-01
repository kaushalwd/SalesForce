@IsTest
private class SPAWhatsappSchedulerTest {

    @IsTest
    static void testScheduler() {
        // Test scheduler
        Test.startTest();
        SPAWhatsappScheduler scheduler = new SPAWhatsappScheduler();
        String cronExp = '0 0 * * * ?'; // every hour
        System.schedule('Test SPAWhatsapp Scheduler', cronExp, scheduler);
        Test.stopTest();
    }
}