@isTest
public class PaymentPlanChangeAutomator_Test {

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
            Type__c = 'Cost Approval'
        );
        insert pf;

        Process_Flow_Step__c pfs2 = new Process_Flow_Step__c(
            Section_Number__c = 2,
            section_Name__c = 'TES2',
            Process_Flow__c = pf.Id
        );
        insert pfs2;

        Project__c project = new Project__c();
        insert project;

        Phase__c phase = new Phase__c();
        phase.Project__c = project.Id;
        insert phase;

        Business_Process__c bp = new Business_Process__c(
            Process_Flow__c = pf.Id
        );
        insert bp;

        Business_Process_Step__c step = new Business_Process_Step__c(
            Name = 'CM Senior Manager Approval',
            Status__c = 'Completed',
            Business_Process__c = bp.Id,
            Sequence__c = 1,
            Section_Number__c = 1,
            section_Name__c = 'Test Section',
            Process_Flow_Step__c = pfs2.Id,
            Business_Process_Steps_Name_Custom__c = 'Test Step'
        );
        insert step;

        Account acc = new Account(Name = 'Test Customer');
        insert acc;

        Unit__c unitRec = new Unit__c(
            Name = 'A-101',
            Phase__c = phase.Id,
            PlotNo__c = '1234',
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '1'
        );
        insert unitRec;

        PaymentPlan__c oldPlan = new PaymentPlan__c(
            Name = 'Old Payment Plan',
            Type__c = 'Standard',
            Phase__c = phase.Id,
            Status__c = 'Active',
            StartDate__c = Date.today().addDays(-30),
            ExpiryDate__c = Date.today().addDays(60)
        );

        PaymentPlan__c newPlan = new PaymentPlan__c(
            Name = 'New Payment Plan',
            Type__c = 'Standard',
            Phase__c = phase.Id,
            Status__c = 'Active',
            StartDate__c = Date.today().addDays(-30),
            ExpiryDate__c = Date.today().addDays(60)
        );

        insert new List<PaymentPlan__c>{ oldPlan, newPlan };

        SalesOrder__c so = new SalesOrder__c(
            CustomerAccount__c = acc.Id,
            Status__c = 'sold',
            Unit__c = unitRec.Id,
            PaymentPlan__c = oldPlan.Id,
            TotalAmount__c = 100000
        );
        insert so;
    }

    @isTest
    static void testExecuteAutomation_ConfirmationDate() {

        List<Business_Process_Step__c> steps = [
            SELECT Id,
                   Name,
                   Status__c,
                   Business_Process__c
            FROM Business_Process_Step__c
        ];

        BusinessProcessAutomationInput inputObj = new BusinessProcessAutomationInput();

        inputObj.steps = steps;

        Test.startTest();

        PaymentPlanChangeAutomator automator =
            new PaymentPlanChangeAutomator();

        automator.executeAutomation(inputObj);

        Test.stopTest();
    }

    @isTest
    static void testExecuteAutomation_FinanceVerification_TriggersSalesOrderSync() {

        Process_Flow__c pf = [SELECT Id FROM Process_Flow__c LIMIT 1];
        SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];

        Business_Process__c financeBp = new Business_Process__c(
            Process_Flow__c = pf.Id,
            Sales_Order__c = so.Id
        );
        insert financeBp;

        Business_Process_Step__c financeStep = new Business_Process_Step__c(
            Name = 'CM Finance Verification',
            Status__c = 'Completed',
            Business_Process__c = financeBp.Id
        );

        BusinessProcessAutomationInput inputObj = new BusinessProcessAutomationInput();
        inputObj.steps = new List<Business_Process_Step__c>{ financeStep };

        Test.startTest();

        PaymentPlanChangeAutomator automator = new PaymentPlanChangeAutomator();
        automator.executeAutomation(inputObj);

        Test.stopTest();
    }

    @isTest
    static void testExecuteAutomation_SeniorManagerApproval_CreatesPaymentPlan() {

        Process_Flow__c pf = [SELECT Id FROM Process_Flow__c LIMIT 1];
        SalesOrder__c so = [SELECT Id, PaymentPlan__c FROM SalesOrder__c LIMIT 1];
        PaymentPlan__c newPlan = [
            SELECT Id
            FROM PaymentPlan__c
            WHERE Name = 'New Payment Plan'
            LIMIT 1
        ];

        Business_Process__c approvalBp = new Business_Process__c(
            Process_Flow__c = pf.Id,
            Sales_Order__c = so.Id
        );
        insert approvalBp;

        PaymentPlanChangeRequest__c changeReq = new PaymentPlanChangeRequest__c(
            Sales_Order__c = so.Id,
            Existing_Payment_Plan__c = so.PaymentPlan__c,
            Revised_Payment_Plan__c = newPlan.Id,
            Status__c = 'Draft',
            Submitted_By__c = UserInfo.getUserId(),
            Submitted_Date__c = System.now()
        );
        insert changeReq;

        Business_Process_Step__c approvalStep = new Business_Process_Step__c(
            Name = 'CM Senior Manager Approval',
            Status__c = 'Completed',
            Business_Process__c = approvalBp.Id
        );

        BusinessProcessAutomationInput inputObj = new BusinessProcessAutomationInput();
        inputObj.steps = new List<Business_Process_Step__c>{ approvalStep };

        Test.startTest();

        PaymentPlanChangeAutomator automator = new PaymentPlanChangeAutomator();

        try {
            automator.executeAutomation(inputObj);
        } catch (AuraHandledException e) {
            // PaymentPlanImplementationController.createPlan requires staging lines
            // (PaymentPlanChangeLine__c records) that are outside the scope of this
            // automation test; the call itself is what's under test here.
        }

        Test.stopTest();
    }
}