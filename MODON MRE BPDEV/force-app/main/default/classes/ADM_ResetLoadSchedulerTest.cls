@isTest
private class ADM_ResetLoadSchedulerTest {
        @IsTest
    static void testSchedule() {
        Test.startTest();  
                    AssignmentRule__c asr = new AssignmentRule__c(
                //Name = 'Test ADM Sales Rule',
                IsActive__c = true,
                RecordType__c = 'Service Request', // Set the controlling field
                ProcessName__c = 'ADM',            // Set the dependent value
                ProcessType__c = 'Sales'
            );
            insert asr;
        AssignmentUser__c testUser = new AssignmentUser__c(
            IsActive__c = true,
            Current_Load__c = 5,
            User__c = UserInfo.getUserId(),
            AssignmentRule__c = asr.Id,
            BusinessHours__c = [SELECT Id FROM BusinessHours WHERE IsDefault = true LIMIT 1].Id,
            MondayStartTime__c = Time.newInstance(9, 0, 0, 0),
            MondayEndTime__c = Time.newInstance(17, 0, 0, 0),
            TuesdayStartTime__c = Time.newInstance(9, 0, 0, 0),
            TuesdayEndTime__c = Time.newInstance(17, 0, 0, 0),
            WednesdayStartTime__c = Time.newInstance(9, 0, 0, 0),
            WednesdayEndTime__c = Time.newInstance(17, 0, 0, 0),
            ThursdayStartTime__c = Time.newInstance(9, 0, 0, 0),
            ThursdayEndTime__c = Time.newInstance(17, 0, 0, 0),
            FridayStartTime__c = Time.newInstance(9, 0, 0, 0),
            FridayEndTime__c = Time.newInstance(17, 0, 0, 0),
            SaturdayStartTime__c = Time.newInstance(9, 0, 0, 0),
            SaturdayEndTime__c = Time.newInstance(17, 0, 0, 0),
            SundayStartTime__c = Time.newInstance(9, 0, 0, 0),
            SundayEndTime__c = Time.newInstance(17, 0, 0, 0),
            MaximumCapacity__c = 10
        );
        insert testUser;
        String cronExp = '0 0 0 ? * MON-FRI'; // Every weekday at midnight
        ADM_ResetLoadScheduler scheduler = new ADM_ResetLoadScheduler();
        String jobId = System.schedule('Test Reset Load Scheduler', cronExp, scheduler);
        Test.stopTest();
        List<AssignmentUser__c> updatedUsers = [
            SELECT Id, Current_Load__c
            FROM AssignmentUser__c
            WHERE Id = :testUser.Id
        ];
        System.assertEquals(0, updatedUsers[0].Current_Load__c, 'The Current Load should be reset to 0');
    }           

}