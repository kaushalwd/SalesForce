@isTest
public class ProjectMileStoneValidator_Test {
    @testSetup
    static void setupData() {

        Project__c project = new Project__c();
        insert project;

        Phase__c phase = new Phase__c(
            Project__c = project.Id
        );
        insert phase;

        Milestone__c milestoneRec = new Milestone__c(
            Name = 'Test Milestone',
            Phase__c = phase.Id,
            Milestone_Due_Date__c = Date.today()
        );
        insert milestoneRec;

        Process_Flow__c pf = new Process_Flow__c(
            Name = 'Milestone Flow',
            Active__c = true,
            Process_Flow_Unique_Name__c = 'Milestone_Test',
            Type__c = 'Cost Approval'
        );
        insert pf;
         Process_Flow_Step__c pfs2 = new Process_Flow_Step__c(
            Section_Number__c=2,
            section_Name__c='TES2',
            Process_Flow__c = pf.Id
        );
        insert pfs2;
        Business_Process__c bp = new Business_Process__c(
            Process_Flow__c = pf.Id,
            Milestone__c = milestoneRec.Id
        );
        insert bp;


        Business_Process_Step__c step = new Business_Process_Step__c(
            Name = 'Project Team to Confirm Date',
            Status__c = 'Completed',
            Business_Process__c = bp.Id,
            Sequence__c = 1,
            Section_Number__c = 1,
            section_Name__c = 'Test Section',
            Process_Flow_Step__c=pfs2.Id,
            Business_Process_Steps_Name_Custom__c = 'Test Step'
        );
        insert step;
    }


    @isTest
    static void testValidateSteps_Success() {

        Business_Process__c bp = [
            SELECT Id,
                   Milestone__r.Milestone_Due_Date__c
            FROM Business_Process__c
            LIMIT 1
        ];

        bp.MileStone_Confirmation_Date__c =
            bp.Milestone__r.Milestone_Due_Date__c;

        update bp;

        Business_Process_Step__c step = [
            SELECT Id,
                   Name,
                   Business_Process__c
            FROM Business_Process_Step__c
            LIMIT 1
        ];

        Test.startTest();

        ProjectMileStoneConfirmationValidator validator =
            new ProjectMileStoneConfirmationValidator();

        validator.ValidateSteps(step);

        Test.stopTest();

       
    }

    @isTest
    static void testValidateSteps_NoDates() {

        Business_Process_Step__c step = [
            SELECT Id,
                   Name,
                   Business_Process__c
            FROM Business_Process_Step__c
            LIMIT 1
        ];

        Test.startTest();

        try {

            ProjectMileStoneConfirmationValidator validator =
                new ProjectMileStoneConfirmationValidator();

            validator.ValidateSteps(step);



        } catch (AuraHandledException e) {

        }

        Test.stopTest();
    }

 
    @isTest
    static void testValidateSteps_BothDates() {

        Business_Process__c bp = [
            SELECT Id
            FROM Business_Process__c
            LIMIT 1
        ];

        bp.MileStone_Confirmation_Date__c = Date.today();
        bp.MileStone_Extension_Date__c = Date.today().addDays(5);

        update bp;

        Business_Process_Step__c step = [
            SELECT Id,
                   Name,
                   Business_Process__c
            FROM Business_Process_Step__c
            LIMIT 1
        ];

        Test.startTest();

        try {

            ProjectMileStoneConfirmationValidator validator =
                new ProjectMileStoneConfirmationValidator();

            validator.ValidateSteps(step);



        } catch (AuraHandledException e) {

           
        }

        Test.stopTest();
    }

    @isTest
    static void testValidateSteps_InvalidConfirmationDate() {

        Business_Process__c bp = [
            SELECT Id
            FROM Business_Process__c
            LIMIT 1
        ];

        bp.MileStone_Confirmation_Date__c =
            Date.today().addDays(1);

        update bp;

        Business_Process_Step__c step = [
            SELECT Id,
                   Name,
                   Business_Process__c
            FROM Business_Process_Step__c
            LIMIT 1
        ];

        Test.startTest();

        try {

            ProjectMileStoneConfirmationValidator validator =
                new ProjectMileStoneConfirmationValidator();

            validator.ValidateSteps(step);



        } catch (AuraHandledException e) {


        }

        Test.stopTest();
    }

    @isTest
    static void testValidateSteps_InvalidExtensionDate() {

        Business_Process__c bp = [
            SELECT Id
            FROM Business_Process__c
            LIMIT 1
        ];

        bp.MileStone_Extension_Date__c =
            Date.today().addDays(10);

        update bp;

        Business_Process_Step__c step = [
            SELECT Id,
                   Name,
                   Business_Process__c
            FROM Business_Process_Step__c
            LIMIT 1
        ];

        Test.startTest();

        try {

            ProjectMileStoneConfirmationValidator validator =
                new ProjectMileStoneConfirmationValidator();

            validator.ValidateSteps(step);



        } catch (AuraHandledException e) {


        }

        Test.stopTest();
    }

    @isTest
    static void testValidateSteps_WhenElse() {

        Business_Process_Step__c step = new Business_Process_Step__c(
            Name = 'Other Step'
        );

        Test.startTest();

        ProjectMileStoneConfirmationValidator validator =
            new ProjectMileStoneConfirmationValidator();

        validator.ValidateSteps(step);

        Test.stopTest();

    }

    @isTest
    static void testMilestoneConfirmationValidator() {
        Business_Process_Step__c s1 = new Business_Process_Step__c(Name = 'DLD Registration Process Initiation');
        Business_Process_Step__c s2 = new Business_Process_Step__c(Name = 'Other Step');
        MilestoneConfirmationValidator v = new MilestoneConfirmationValidator();
        v.ValidateSteps(s1);
        v.ValidateSteps(s2);
    }
}