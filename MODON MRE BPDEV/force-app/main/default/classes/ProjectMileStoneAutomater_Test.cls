@isTest
public class ProjectMileStoneAutomater_Test {
    @testSetup
    static void setupData() {
        BusinessHours bh = [
    SELECT Id, Name, IsActive
    FROM BusinessHours
    WHERE IsDefault = true
    LIMIT 1
];

        Process_Flow__c pf = new Process_Flow__c(
            Name = 'MileStone Payment Readiness',
            Active__c = true,
            Process_Flow_Unique_Name__c = 'Milestone_Test',
            Type__c='Cost Approval'

        );
        insert pf;
         Process_Flow_Step__c pfs2 = new Process_Flow_Step__c(
            Section_Number__c=2,
            section_Name__c='TES2',
            Process_Flow__c = pf.Id
        );
        insert pfs2;
         Project__c project = new Project__c();
        insert project;
        
        Phase__c phase = new Phase__c();
        phase.Project__c = project.Id;  
        insert phase;

        Milestone__c milestoneRec = new Milestone__c(
            Name = 'Test Milestone',
            Milestone_Due_Date__c=Date.today(),
            Phase__c=phase.Id
        );
        insert milestoneRec;

        Business_Process__c bp = new Business_Process__c(
             Process_Flow__c=pf.Id,
            Milestone__c = milestoneRec.Id,
            MileStone_Confirmation_Date__c = Date.today()
        );
        insert bp;

     
        Business_Process_Step__c step = new Business_Process_Step__c(
            Name = 'Execute Milestone Update',
            Status__c = 'Completed',
            Business_Process__c = bp.Id,
            Sequence__c = 1,
            Section_Number__c = 1,
            section_Name__c = 'Test Section',
            Process_Flow_Step__c =pfs2.Id,
            Business_Process_Steps_Name_Custom__c = 'Test Step'
        );
        insert step;
    }

    @isTest
    static void testExecuteAutomation_ConfirmationDate() {

        /* -----------------------------
           Fetch Test Step
        ------------------------------*/
        List<Business_Process_Step__c> steps = [
            SELECT Id,
                   Name,
                   Status__c,
                   Business_Process__c
            FROM Business_Process_Step__c
        ];

        /* -----------------------------
           Prepare Input
        ------------------------------*/
        BusinessProcessAutomationInput inputObj =
            new BusinessProcessAutomationInput();

        inputObj.steps = steps;

        Test.startTest();

        ProjectMileStoneConfirmationAutomator automator =
            new ProjectMileStoneConfirmationAutomator();

        automator.executeAutomation(inputObj);

        Test.stopTest();

        /* -----------------------------
           Verify Milestone Updated
        ------------------------------*/
        Milestone__c updatedMilestone = [
            SELECT Id,
                   ConfirmedMilestoneDate__c
            FROM Milestone__c
            LIMIT 1
        ];

        System.assertEquals(
            Date.today(),
            updatedMilestone.ConfirmedMilestoneDate__c
        );
    }

    @isTest
    static void testExecuteAutomation_ExtensionDate() {


         Project__c project = new Project__c();
        insert project;
        
        Phase__c phase = new Phase__c();
        phase.Project__c = project.Id;  
        insert phase;

        Milestone__c milestoneRec = new Milestone__c(
            Name = 'Extension Milestone',
            Phase__C=phase.Id,
             Milestone_Due_Date__c=Date.today()
        );
        insert milestoneRec;
         
        
         Process_Flow__c pf = new Process_Flow__c(
            Name = 'MileStone Payment Readiness',
            Active__c = true,
            Process_Flow_Unique_Name__c = 'MilestoneTest',
            Type__c='Cost Approval'

        );
        insert pf;
         Process_Flow_Step__c pfs2 = new Process_Flow_Step__c(
            Section_Number__c=2,
            section_Name__c='TES2',
            Process_Flow__c = pf.Id
        );
        insert pfs2;
        Business_Process__c bp = new Business_Process__c(
            process_Flow__c=pf.Id,
            Milestone__c = milestoneRec.Id,
            MileStone_Extension_Date__c = Date.today().addDays(10)
        );
        insert bp;

        /* -----------------------------
           Create Step
        ------------------------------*/
        Business_Process_Step__c step = new Business_Process_Step__c(
            Name = 'Execute Milestone Update',
            Status__c = 'Completed',
            Business_Process__c = bp.Id,
            Sequence__c = 1,
            Section_Number__c = 1,
            section_Name__c = 'Section',
            process_flow_step__c=pfs2.Id,
            Business_Process_Steps_Name_Custom__c = 'Step'
        );
        insert step;

        /* -----------------------------
           Prepare Input
        ------------------------------*/
        BusinessProcessAutomationInput inputObj =
            new BusinessProcessAutomationInput();

        inputObj.steps =
            new List<Business_Process_Step__c>{ step };

        /* -----------------------------
           Execute
        ------------------------------*/
        Test.startTest();

        ProjectMileStoneConfirmationAutomator automator =
            new ProjectMileStoneConfirmationAutomator();

        automator.executeAutomation(inputObj);

        Test.stopTest();

        /* -----------------------------
           Validate
        ------------------------------*/
        Milestone__c updatedMilestone = [
            SELECT Id,
                   Milestone_Due_Date__c
            FROM Milestone__c
            WHERE Id = :milestoneRec.Id
        ];

       
    }

    @isTest
    static void testExecuteAutomation_NoMatchingStep() {


        Business_Process_Step__c step = new Business_Process_Step__c(
            Name = 'Other Step',
            Status__c = 'Pending',
            Sequence__c = 1,
            Section_Number__c = 1,
            section_Name__c = 'Test',
            Business_Process_Steps_Name_Custom__c = 'Other'
        );

        BusinessProcessAutomationInput inputObj =
            new BusinessProcessAutomationInput();

        inputObj.steps =
            new List<Business_Process_Step__c>{ step };

        Test.startTest();

        ProjectMileStoneConfirmationAutomator automator =
            new ProjectMileStoneConfirmationAutomator();

        automator.executeAutomation(inputObj);

        Test.stopTest();

    }

    @isTest
    static void testMilestoneConfirmationAutomater() {
        BusinessProcessAutomationInput input = new BusinessProcessAutomationInput();
        Business_Process_Step__c s1 = new Business_Process_Step__c(Name = 'DLD Completion with Payment', Status__c = 'Completed');
        Business_Process_Step__c s2 = new Business_Process_Step__c(Name = 'Other', Status__c = 'Pending');
        input.steps = new List<Business_Process_Step__c>{ s1, s2 };
        new MilestoneConfirmationAutomater().executeAutomation(input);
    }
}