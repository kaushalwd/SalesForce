@isTest
public class MileStonePaymentReadValidator_Test {



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

        Process_Flow_Step__c pfs = new Process_Flow_Step__c(
            Section_Number__c = 1,
            section_Name__c = 'Validation',
            Process_Flow__c = pf.Id
        );
        insert pfs;

        Business_Process__c bp = new Business_Process__c(
            Process_Flow__c = pf.Id,
            Milestone__c = milestoneRec.Id
        );
        insert bp;

        Business_Process_Step__c step =
            new Business_Process_Step__c(
                Name = 'DLD Registration Process Initiation',
                Status__c = 'Completed',
                Business_Process__c = bp.Id,
                Sequence__c = 1,
                Section_Number__c = 1,
                section_Name__c = 'Section',
                Process_Flow_Step__c = pfs.Id,
                Business_Process_Steps_Name_Custom__c = 'Test'
            );

        insert step;
    }

    @isTest
    static void testValidateSteps_MainFlow() {

        Business_Process_Step__c step = [
            SELECT Id,
                   Name,
                   Business_Process__c
            FROM Business_Process_Step__c
            LIMIT 1
        ];

        Test.startTest();

        MilestonePaymentReadinessValidator validator =
            new MilestonePaymentReadinessValidator();

        validator.ValidateSteps(step);

        Test.stopTest();
    }

    @isTest
    static void testValidateSteps_WhenElse() {

        Business_Process_Step__c step =
            new Business_Process_Step__c(
                Name = 'Other Step'
            );

        Test.startTest();

        MilestonePaymentReadinessValidator validator =
            new MilestonePaymentReadinessValidator();

        validator.ValidateSteps(step);

        Test.stopTest();
    }
}