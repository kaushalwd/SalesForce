@isTest
private class BusinessProcessStepTriggerTest {

    @testSetup
    static void setupData() {

        BusinessHours bh = [
            SELECT Id FROM BusinessHours WHERE IsDefault = true LIMIT 1
        ];

        Process_Flow__c pf = new Process_Flow__c(
            Name = 'Test Flow',
            Active__c = true,
            Process_Flow_Unique_Name__c = 'PF1',
            Type__c = 'Cost Approval',
            Business_Hours_ID__c = bh.Id
        );
        insert pf;

        List<Process_Flow_Step__c> steps = new List<Process_Flow_Step__c>{
            new Process_Flow_Step__c(
                Section_Number__c = 1,
                Section_Name__c = 'Step1',
                Process_Flow__c = pf.Id,
                Duration_To_Complete_In_Hourss__c = '2'
            ),
            new Process_Flow_Step__c(
                Section_Number__c = 2,
                Section_Name__c = 'Step2',
                Process_Flow__c = pf.Id,
                Duration_To_Complete_In_Hourss__c = '2'
            )
        };
        insert steps;

        Business_Process__c bp = new Business_Process__c(
            Process_Flow__c = pf.Id
        );
        insert bp;

        List<Business_Process_Step__c> bpSteps = new List<Business_Process_Step__c>{
            createStep(bp.Id, steps[0].Id, 1),
            createStep(bp.Id, steps[1].Id, 2)
        };
        insert bpSteps;
    }

    // HELPER METHOD
    private static Business_Process_Step__c createStep(Id bpId, Id pfsId, Integer seq) {
        return new Business_Process_Step__c(
            Name = 'Step ' + seq,
            Business_Process__c = bpId,
            Process_Flow_Step__c = pfsId,
            Sequence__c = seq,
            Status__c = 'Not Actioned',
            OwnerId = UserInfo.getUserId(),
            Business_Process_Steps_Name_Custom__c = 'Test',
            Section_Number__c = seq,
            Section_Name__c = 'Test'
        );
    }

    // TEST: BEFORE INSERT (OPEN)
    @isTest
    static void testBeforeInsert_Open() {

        Business_Process__c bp = [SELECT Id FROM Business_Process__c LIMIT 1];
        Process_Flow_Step__c pfs = [SELECT Id FROM Process_Flow_Step__c LIMIT 1];

        Business_Process_Step__c step = createStep(bp.Id, pfs.Id, 1);
        step.Status__c = 'Open';

        insert step;

        step = [SELECT Step_Open_Time__c, Expected_Completion_Time__c FROM Business_Process_Step__c WHERE Id = :step.Id];

        System.assertNotEquals(null, step.Step_Open_Time__c);
    }

    // TEST: ASSIGN
    @isTest
    static void testAssign() {

        Business_Process_Step__c step = [SELECT Id FROM Business_Process_Step__c LIMIT 1];

        Test.startTest();
        step.Assigned_To__c = UserInfo.getUserId();
        update step;
        Test.stopTest();

        step = [SELECT Status__c, Assigned_Time__c FROM Business_Process_Step__c WHERE Id = :step.Id];

        System.assertEquals('Assigned', step.Status__c);
    }

    // TEST: RE-ASSIGN 
    @isTest
    static void testReAssign() {

        Business_Process_Step__c step = [SELECT Id FROM Business_Process_Step__c LIMIT 1];

        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        User u1 = new User(
            Alias='u1',
            Email='u1@test.com',
            EmailEncodingKey='UTF-8',
            LastName='U1',
            LanguageLocaleKey='en_US',
            LocaleSidKey='en_US',
            ProfileId=p.Id,
            TimeZoneSidKey='Asia/Kolkata',
            UserName='u1' + System.currentTimeMillis() + '@test.com'
        );
        insert u1;

        User u2 = new User(
            Alias='u2',
            Email='u2@test.com',
            EmailEncodingKey='UTF-8',
            LastName='U2',
            LanguageLocaleKey='en_US',
            LocaleSidKey='en_US',
            ProfileId=p.Id,
            TimeZoneSidKey='Asia/Kolkata',
            UserName='u2' + System.currentTimeMillis() + '@test.com'
        );
        insert u2;

        Test.startTest();

        // First assignment
        step.Assigned_To__c = u1.Id;
        update step;

        // Reload
        step = [SELECT Id, Assigned_To__c FROM Business_Process_Step__c WHERE Id = :step.Id];

        // Reassign
        step.Assigned_To__c = u2.Id;
        update step;

        Test.stopTest();
    }

    // TEST: COMPLETED FLOW
    @isTest
    static void testCompleted() {

        Business_Process_Step__c step = [SELECT Id FROM Business_Process_Step__c LIMIT 1];

        Test.startTest();
        step.Status__c = 'Completed';
        update step;
        Test.stopTest();

        step = [SELECT Completed_Time__c FROM Business_Process_Step__c WHERE Id = :step.Id];

        System.assertNotEquals(null, step.Completed_Time__c);
    }
    // TEST: LOG CREATION
    @isTest
    static void testLogs() {

        Business_Process_Step__c step = [SELECT Id FROM Business_Process_Step__c LIMIT 1];

        Test.startTest();
        step.Status__c = 'Open';
        update step;
        Test.stopTest();

        List<Business_Process_Step_Time_Log__c> logs = [
            SELECT Id FROM Business_Process_Step_Time_Log__c WHERE Business_Process_Step__c = :step.Id
        ];

        System.assert(logs.size() > 0);
    }

    // TEST: CANCELLED
    @isTest
    static void testCancelled() {

        Business_Process_Step__c step = [SELECT Id,Business_Process__c FROM Business_Process_Step__c LIMIT 1];

        Test.startTest();
        step.Status__c = 'Cancelled';
        update step;
        Test.stopTest();

        Business_Process__c bp = [
            SELECT Status__c FROM Business_Process__c
            WHERE Id = :step.Business_Process__c
        ];

    }
    @isTest
static void testReOpenBranchCoverage() {

    // Get existing step
    Business_Process_Step__c step = [
        SELECT Id, Status__c, Re_Open_Count__c
        FROM Business_Process_Step__c
        LIMIT 1
    ];

    Test.startTest();

    // First change → triggers RE_OPEN (count = 1)
    step.Status__c = 'Re Open';
    update step;

    // Reload to simulate real oldMap behavior
    step = [
        SELECT Id, Status__c, Re_Open_Count__c
        FROM Business_Process_Step__c
        WHERE Id = :step.Id
    ];

    // Change again → increment count (count = 2)
    step.Status__c = 'Open'; 
    update step;

    step.Status__c = 'Re Open';
    update step;

    Test.stopTest();

}
    @isTest
static void testRequiredAndProvidedInfoCoverage() {

    Business_Process_Step__c step = [
        SELECT Id, Status__c
        FROM Business_Process_Step__c
        LIMIT 1
    ];

    Test.startTest();

    // Change to REQUIRED_INFO
    step.Status__c = 'Required Info';
    update step;

    // Reload to simulate oldMap properly
    step = [
        SELECT Id, Status__c
        FROM Business_Process_Step__c
        WHERE Id = :step.Id
    ];

    // Change to PROVIDED_INFO
    step.Status__c = 'Provided Info';
    update step;

    Test.stopTest();

}

}