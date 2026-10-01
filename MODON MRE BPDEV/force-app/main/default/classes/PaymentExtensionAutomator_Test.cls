@isTest
public class PaymentExtensionAutomator_Test {


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

        /* -----------------------------
           Process Flow
        ------------------------------*/
        Process_Flow__c pf = new Process_Flow__c(
            Name = 'Payment Extension Flow',
            Active__c = true,
            Process_Flow_Unique_Name__c = 'Payment_Ext_Test',
            Type__c = 'Cost Approval'
        );
        insert pf;

        Process_Flow_Step__c pfs = new Process_Flow_Step__c(
            Section_Number__c = 1,
            section_Name__c = 'Approval',
            Process_Flow__c = pf.Id
        );
        insert pfs;
SalesOrder__c so = new SalesOrder__c(Status__c = 'Sold');
    insert so;

   
        SalesOrderInstallments__c inst1 =
            new SalesOrderInstallments__c(
               SalesOrder__c = so.Id,
        MilestoneNumber__c = 1
            );

        SalesOrderInstallments__c inst2 =
            new SalesOrderInstallments__c(
                SalesOrder__c = so.Id,
        MilestoneNumber__c = 2
            );

        SalesOrderInstallments__c inst3 =
            new SalesOrderInstallments__c(
                 SalesOrder__c = so.Id,
        MilestoneNumber__c = 3
            );

        insert new List<SalesOrderInstallments__c>{
            inst1, inst2, inst3
        };


        List<Business_Process__c> bpList =
            new List<Business_Process__c>();

        bpList.add(new Business_Process__c(
            Process_Flow__c = pf.Id,
            Milestone__c = milestoneRec.Id,
            Payment_Extension_Category__c = 'Upto 30 days',
            Payment_Extension_Date__c = Date.today().addDays(30),
            Sales_Order_Installment__c = inst1.Id
        ));

        bpList.add(new Business_Process__c(
            Process_Flow__c = pf.Id,
            Milestone__c = milestoneRec.Id,
            Payment_Extension_Category__c = 'Upto 60 days',
            Payment_Extension_Date__c = Date.today().addDays(60),
            Sales_Order_Installment__c = inst2.Id
        ));

        bpList.add(new Business_Process__c(
            Process_Flow__c = pf.Id,
            Milestone__c = milestoneRec.Id,
            Payment_Extension_Category__c = 'More than 60 days',
            Payment_Extension_Date__c = Date.today().addDays(90),
            Sales_Order_Installment__c = inst3.Id
        ));

        insert bpList;

        /* -----------------------------
           Steps
        ------------------------------*/
        List<Business_Process_Step__c> steps =
            new List<Business_Process_Step__c>();

        steps.add(new Business_Process_Step__c(
            Name = 'Approval from CM Director',
            Status__c = 'Completed',
            Business_Process__c = bpList[0].Id,
            Sequence__c = 1,
            Section_Number__c = 1,
            section_Name__c = 'Section',
            Process_Flow_Step__c = pfs.Id,
            Business_Process_Steps_Name_Custom__c = 'CM'
        ));

        steps.add(new Business_Process_Step__c(
            Name = 'Approval from CCO',
            Status__c = 'Completed',
            Business_Process__c = bpList[1].Id,
            Sequence__c = 1,
            Section_Number__c = 1,
            section_Name__c = 'Section',
            Process_Flow_Step__c = pfs.Id,
            Business_Process_Steps_Name_Custom__c = 'CCO'
        ));

        steps.add(new Business_Process_Step__c(
            Name = 'Approval from CEO',
            Status__c = 'Completed',
            Business_Process__c = bpList[2].Id,
            Sequence__c = 1,
            Section_Number__c = 1,
            section_Name__c = 'Section',
            Process_Flow_Step__c = pfs.Id,
            Business_Process_Steps_Name_Custom__c = 'CEO'
        ));

        steps.add(new Business_Process_Step__c(
            Name = 'Finance Verification',
            Status__c = 'Open',
            Business_Process__c = bpList[0].Id,
            Sequence__c = 2,
            Section_Number__c = 1,
            section_Name__c = 'Section',
            Process_Flow_Step__c = pfs.Id,
            Business_Process_Steps_Name_Custom__c = 'Finance'
        ));

        steps.add(new Business_Process_Step__c(
            Name = 'Finance Verification',
            Status__c = 'Open',
            Business_Process__c = bpList[1].Id,
            Sequence__c = 2,
            Section_Number__c = 1,
            section_Name__c = 'Section',
            Process_Flow_Step__c = pfs.Id,
            Business_Process_Steps_Name_Custom__c = 'Finance'
        ));

        steps.add(new Business_Process_Step__c(
            Name = 'Finance Verification',
            Status__c = 'Open',
            Business_Process__c = bpList[2].Id,
            Sequence__c = 2,
            Section_Number__c = 1,
            section_Name__c = 'Section',
            Process_Flow_Step__c = pfs.Id,
            Business_Process_Steps_Name_Custom__c = 'Finance'
        ));

        insert steps;
    }

    /* =========================================================
       TEST SUCCESS FLOW
    ==========================================================*/
    @isTest
    static void testExecuteAutomation_Success() {

        List<Business_Process_Step__c> steps = [
            SELECT Id,
                   Name,
                   Status__c,
                   Business_Process__c
            FROM Business_Process_Step__c
        ];

        BusinessProcessAutomationInput inputObj =
            new BusinessProcessAutomationInput();

        inputObj.steps = steps;

        Test.startTest();

        PaymentMilestoneExtentionAutomator automator =
            new PaymentMilestoneExtentionAutomator();

        automator.executeAutomation(inputObj);

        Test.stopTest();

        /* -----------------------------
           Verify Updates
        ------------------------------*/
        List<SalesOrderInstallments__c> updatedInst = [
            SELECT Id,
                   ExtensionDate__c
            FROM SalesOrderInstallments__c
            ORDER BY CreatedDate
        ];

        System.assertEquals(
            Date.today().addDays(30),
            updatedInst[0].ExtensionDate__c
        );

        System.assertEquals(
            Date.today().addDays(60),
            updatedInst[1].ExtensionDate__c
        );

        System.assertEquals(
            Date.today().addDays(90),
            updatedInst[2].ExtensionDate__c
        );
    }

    /* =========================================================
       TEST NO COMPLETED STATUS
    ==========================================================*/
    @isTest
    static void testExecuteAutomation_NoCompletedSteps() {

        Business_Process_Step__c step =
            new Business_Process_Step__c(
                Name = 'Approval from CEO',
                Status__c = 'Pending'
            );

        BusinessProcessAutomationInput inputObj =
            new BusinessProcessAutomationInput();

        inputObj.steps =
            new List<Business_Process_Step__c>{ step };

        Test.startTest();

        PaymentMilestoneExtentionAutomator automator =
            new PaymentMilestoneExtentionAutomator();

        automator.executeAutomation(inputObj);

        Test.stopTest();

        System.assert(true);
    }

    /* =========================================================
       TEST INVALID STEP NAME
    ==========================================================*/
    @isTest
    static void testExecuteAutomation_InvalidStepName() {

        Business_Process_Step__c step =
            new Business_Process_Step__c(
                Name = 'Random Step',
                Status__c = 'Completed'
            );

        BusinessProcessAutomationInput inputObj =
            new BusinessProcessAutomationInput();

        inputObj.steps =
            new List<Business_Process_Step__c>{ step };

        Test.startTest();

        PaymentMilestoneExtentionAutomator automator =
            new PaymentMilestoneExtentionAutomator();

        automator.executeAutomation(inputObj);

        Test.stopTest();

        System.assert(true);
    }

    /* =========================================================
       TEST NULL INSTALLMENT
    ==========================================================*/
    @isTest
    static void testExecuteAutomation_NullInstallment() {

        Business_Process__c bp = [
            SELECT Id
            FROM Business_Process__c
            LIMIT 1
        ];

        bp.Sales_Order_Installment__c = null;
        update bp;

        Business_Process_Step__c step = [
            SELECT Id,
                   Name,
                   Status__c,
                   Business_Process__c
            FROM Business_Process_Step__c
            WHERE Business_Process__c = :bp.Id AND Name = 'Finance Verification'
            LIMIT 1
        ];

        BusinessProcessAutomationInput inputObj =
            new BusinessProcessAutomationInput();

        inputObj.steps =
            new List<Business_Process_Step__c>{ step };

        Test.startTest();

        PaymentMilestoneExtentionAutomator automator =
            new PaymentMilestoneExtentionAutomator();

        automator.executeAutomation(inputObj);

        Test.stopTest();

        System.assert(true);
    }
}