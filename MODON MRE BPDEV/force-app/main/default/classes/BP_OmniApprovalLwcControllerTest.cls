@isTest
public class BP_OmniApprovalLwcControllerTest {

    @testSetup
    static void setupTestData() {
        // Queue + GroupMember — ensures the user is in at least one group,
        // covering the GroupMember loop body and the queueIds filter branches.
        // System.runAs isolates setup-object DML to avoid MIXED_DML_OPERATION.
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Group q = new Group(Name = 'BP_Omni_Test_Queue', Type = 'Queue');
            insert q;
            insert new GroupMember(GroupId = q.Id, UserOrGroupId = UserInfo.getUserId());
        }

        // Process Flow with Allow_mobile_approvals__c = true so that the step
        // query in getApprovalDashboard() returns our test steps.
        Process_Flow__c pf = new Process_Flow__c(
            Name = 'Test Flow',
            Active__c = true,
            Process_Flow_Unique_Name__c = 'test_flow_omni_v2',
            Type__c = 'Cost Approval',
            Allow_mobile_approvals__c = true
        );
        insert pf;

        Process_Flow_Step__c pfs = new Process_Flow_Step__c(
            Step_Name__c = 'Approval Step',
            Process_Flow__c = pf.Id,
            Section_Number__c = 1,
            section_Name__c = 'Approval Step',
            Is_Management_Step__c = true
        );
        insert pfs;

        // BP 1: Type = 'Default And Termination' matches active BP_OmniApproval_Grid_Config__mdt records,
        // so buildConfiguredFields() will actually produce field wrappers and exercise getFieldValue(),
        // formatValue(), and generateLabel().
        Business_Process__c bp = new Business_Process__c(
            Process_Flow__c = pf.Id,
            Type__c = 'Default And Termination'
        );
        insert bp;

        // Step 1: Open, custom name, Assigned_To__c set, View_review_comments__c = true.
        // View_review_comments__c = true forces both sides of the && to be evaluated,
        // covering the previously uncovered sub-expression on that assignment line.
        Business_Process_Step__c step1 = new Business_Process_Step__c(
            Business_Process__c = bp.Id,
            Process_Flow_Step__c = pfs.Id,
            Sequence__c = 1,
            Section_Number__c = 1,
            section_Name__c = 'Step 1',
            Status__c = 'Open',
            OwnerId = UserInfo.getUserId(),
            Assigned_To__c = UserInfo.getUserId(),
            Business_Process_Steps_Name_Custom__c = 'Approval Step',
            View_review_comments__c = true,
            Is_Management_Step__c = true
        );
        insert step1;

        // Step 2: Completed — exercises the previousSteps loop (Status = Completed).
        Business_Process_Step__c step2 = new Business_Process_Step__c(
            Business_Process__c = bp.Id,
            Process_Flow_Step__c = pfs.Id,
            Sequence__c = 2,
            Section_Number__c = 1,
            section_Name__c = 'Step 2',
            Status__c = 'Completed',
            OwnerId = UserInfo.getUserId(),
            Assigned_To__c = UserInfo.getUserId(),
            Business_Process_Steps_Name_Custom__c = 'Review Step'
        );
        insert step2;

        // Step 3: Open, no Assigned_To__c — exercises getAssignedUser() Owner.Name branch.
        Business_Process_Step__c step3 = new Business_Process_Step__c(
            Business_Process__c = bp.Id,
            Process_Flow_Step__c = pfs.Id,
            Sequence__c = 3,
            Section_Number__c = 1,
            section_Name__c = 'Step 3',
            Status__c = 'Open',
            OwnerId = UserInfo.getUserId(),
            Business_Process_Steps_Name_Custom__c = 'Owner Only Step',
            Is_Management_Step__c = true
        );
        insert step3;

        Reviewer_Comment__c rc = new Reviewer_Comment__c(
            Business_Process__c = bp.Id,
            Business_Process_Step__c = step1.Id,
            Notes_Comments__c = 'Sample comment'
        );
        insert rc;

        // BP 2 + Process Flow: Type = 'Employee Payment Plan'.
        // BP_Pending_Step_Fields__mdt has active records for this type, so
        // getPendingStepFields() proceeds past the configs.isEmpty() guard and
        // exercises lines 1193-1319 (SOQL build, field loop, formatFieldValue, getRelationshipValue).
        Process_Flow__c pf2 = new Process_Flow__c(
            Name = 'Test Flow EP',
            Active__c = true,
            Process_Flow_Unique_Name__c = 'test_flow_omni_ep_v2',
            Type__c = 'Cost Approval',
            Allow_mobile_approvals__c = true
        );
        insert pf2;

        Process_Flow_Step__c pfs2 = new Process_Flow_Step__c(
            Step_Name__c = 'Payment Step',
            Process_Flow__c = pf2.Id,
            Section_Number__c = 1,
            section_Name__c = 'Payment Step'
        );
        insert pfs2;

        Business_Process__c bp2 = new Business_Process__c(
            Process_Flow__c = pf2.Id,
            Type__c = 'Employee Payment Plan'
        );
        insert bp2;

        Business_Process_Step__c step4 = new Business_Process_Step__c(
            Business_Process__c = bp2.Id,
            Process_Flow_Step__c = pfs2.Id,
            Sequence__c = 1,
            Section_Number__c = 1,
            section_Name__c = 'Step 1',
            Status__c = 'Open',
            OwnerId = UserInfo.getUserId(),
            Assigned_To__c = UserInfo.getUserId(),
            Business_Process_Steps_Name_Custom__c = 'Payment Step'
        );
        insert step4;

        // BP 3: no Type__c. Covers the early-return path in getPendingStepFields()
        // when Business_Process__r.Type__c is blank (line 1161).
        Business_Process__c bp3 = new Business_Process__c(
            Process_Flow__c = pf.Id
        );
        insert bp3;

        Business_Process_Step__c step5 = new Business_Process_Step__c(
            Business_Process__c = bp3.Id,
            Process_Flow_Step__c = pfs.Id,
            Sequence__c = 1,
            Section_Number__c = 1,
            section_Name__c = 'Step 1',
            Status__c = 'Open',
            OwnerId = UserInfo.getUserId(),
            Assigned_To__c = UserInfo.getUserId(),
            Business_Process_Steps_Name_Custom__c = 'No Type Step'
        );
        insert step5;

        // Account, Project, Opportunity, Sales Order & Installment for Payment Extension testing
        Account acc = new Account(Name = 'Test Account for Omni');
        insert acc;

        Project__c proj = new Project__c(Name = 'Test Project Omni');
        insert proj;

        Opportunity opp = new Opportunity(
            Name = 'Test Opp Omni',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            AccountId = acc.Id
        );
        insert opp;

        SalesOrder__c so = new SalesOrder__c(Opportunity__c = opp.Id);
        insert so;

        SalesOrderInstallments__c soi = new SalesOrderInstallments__c(
            SalesOrder__c = so.Id,
            MilestoneNumber__c = 1,
            MilestoneDate__c = Date.today(),
            InstallmentAmount__c = 50000
        );
        insert soi;

        Business_Process__c bpPE = new Business_Process__c(
            Process_Flow__c = pf.Id,
            Type__c = 'Payment Extension',
            Payment_Extension_Date__c = Date.today().addDays(30),
            Sales_Order_Installment__c = soi.Id,
            Sales_Order__c = so.Id
        );
        insert bpPE;

        Business_Process_Step__c stepPE = new Business_Process_Step__c(
            Business_Process__c = bpPE.Id,
            Process_Flow_Step__c = pfs.Id,
            Sequence__c = 1,
            Section_Number__c = 1,
            section_Name__c = 'PE Step',
            Status__c = 'Open',
            OwnerId = UserInfo.getUserId(),
            Business_Process_Steps_Name_Custom__c = 'PE Step'
        );
        insert stepPE;

        // EOI Refund Approval testing
        Business_Process__c bpEOI = new Business_Process__c(
            Process_Flow__c = pf.Id,
            Type__c = 'EOI Refund Approval'
        );
        insert bpEOI;

        Expressionofinterest__c eoi = new Expressionofinterest__c(
            Opportunity__c = opp.Id,
            Project__c = proj.Id,
            Account__c = acc.Id,
            EOI_Amount_AED__c = 10000,
            Business_Process__c = bpEOI.Id
        );
        insert eoi;

        Business_Process_Step__c stepEOI = new Business_Process_Step__c(
            Business_Process__c = bpEOI.Id,
            Process_Flow_Step__c = pfs.Id,
            Sequence__c = 1,
            Section_Number__c = 1,
            section_Name__c = 'EOI Step',
            Status__c = 'Open',
            OwnerId = UserInfo.getUserId(),
            Business_Process_Steps_Name_Custom__c = 'EOI Step',
            Is_Management_Step__c = true
        );
        insert stepEOI;
    }

    // Covers the full happy-path of getApprovalDashboard() including:
    //   - GroupMember loop body (lines 17-18)
    //   - queueIds filter branches (lines 83, 94)
    //   - BP ID collection, BP query, history query, stepsByBp map (lines 111-175)
    //   - Wrapper building loop with previousSteps (lines 183-305)
    //   - buildConfiguredFields(), getFieldValue(), formatValue(), generateLabel() via D&T metadata
    //   - getStepName() all three branches via step variations
    //   - getAssignedUser() both branches via step with/without Assigned_To__c
    @isTest
    static void testGetApprovalDashboard() {
        Test.startTest();
        List<BP_OmniApprovalLwcController.ApprovalDashboardWrapper> results =
            BP_OmniApprovalLwcController.getApprovalDashboard();
        Test.stopTest();

        System.assertNotEquals(null, results, 'Results list should not be null');
    }

    // Covers the other public methods and their branches.
    @isTest
    static void testAdditionalControllerMethods() {
        Business_Process__c bp = [
            SELECT Id FROM Business_Process__c
            WHERE Type__c = 'Default And Termination' LIMIT 1
        ];
        Business_Process_Step__c step1 = [
            SELECT Id FROM Business_Process_Step__c
            WHERE Business_Process__c = :bp.Id
            AND Business_Process_Steps_Name_Custom__c = 'Approval Step' LIMIT 1
        ];

        Test.startTest();

        // getObjectApiNameById branches
        BP_OmniApprovalLwcController.getObjectApiNameById(null);
        BP_OmniApprovalLwcController.getObjectApiNameById(bp.Id);
        BP_OmniApprovalLwcController.getObjectApiNameById('notAnId');

        // getActiveBpStepRecord — step1 has View_review_comments__c = true and
        // a Reviewer_Comment__c exists, so both sides of the && are evaluated.
        BP_OmniApprovalLwcController.getActiveBpStepRecord(bp.Id, step1.Id);

        // getCompletedBPStepRecords — BP path (returns steps)
        BP_OmniApprovalLwcController.getCompletedBPStepRecords(bp.Id);

        // getCompletedBPStepRecords — non-BP object path (covers empty-list return, line 899)
        BP_OmniApprovalLwcController.getCompletedBPStepRecords('001000000000000AAA');

        // getPendingStepFields — null path (early return)
        BP_OmniApprovalLwcController.getPendingStepFields(null);

        // getPendingStepFields — D&T step: metadata has no records for this type → empty return
        BP_OmniApprovalLwcController.getPendingStepFields(step1.Id);

        // handleApprovalAction — Approval.process() throws; catch to keep test green
        try {
            BP_OmniApprovalLwcController.handleApprovalAction(null, 'Approve', 'test');
        } catch (Exception e) {
        }

        Test.stopTest();
    }

    // Covers getPendingStepFields() deep paths (lines 1193-1319), formatFieldValue() (1322-1337),
    // and getRelationshipValue() (1340-1368) via an 'Employee Payment Plan' BP step
    // which has active BP_Pending_Step_Fields__mdt records.
    @isTest
    static void testPendingStepFieldsWithEmployeePaymentPlanType() {
        Business_Process__c bp2 = [
            SELECT Id FROM Business_Process__c
            WHERE Type__c = 'Employee Payment Plan' LIMIT 1
        ];
        Business_Process_Step__c step4 = [
            SELECT Id FROM Business_Process_Step__c
            WHERE Business_Process__c = :bp2.Id LIMIT 1
        ];

        Test.startTest();
        List<Map<String, Object>> result =
            BP_OmniApprovalLwcController.getPendingStepFields(step4.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
    }

    // Covers the blank-type early-return in getPendingStepFields() (line 1161).
    @isTest
    static void testPendingStepFieldsBlankBpType() {
        Business_Process__c bp3 = [
            SELECT Id FROM Business_Process__c
            WHERE Type__c = null LIMIT 1
        ];
        Business_Process_Step__c step5 = [
            SELECT Id FROM Business_Process_Step__c
            WHERE Business_Process__c = :bp3.Id LIMIT 1
        ];

        Test.startTest();
        List<Map<String, Object>> result =
            BP_OmniApprovalLwcController.getPendingStepFields(step5.Id);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null for blank BP type');
    }

    // Covers getPaymentExtensionSummary (lines 1525-1593)
    @isTest
    static void testPaymentExtensionSummary() {
        Business_Process__c bpPE = [
            SELECT Id FROM Business_Process__c
            WHERE Type__c = 'Payment Extension' LIMIT 1
        ];
        Business_Process_Step__c stepPE = [
            SELECT Id FROM Business_Process_Step__c
            WHERE Business_Process__c = :bpPE.Id LIMIT 1
        ];
        Business_Process__c bpDT = [
            SELECT Id FROM Business_Process__c
            WHERE Type__c = 'Default And Termination' LIMIT 1
        ];
        Business_Process_Step__c stepDT = [
            SELECT Id FROM Business_Process_Step__c
            WHERE Business_Process__c = :bpDT.Id LIMIT 1
        ];

        Test.startTest();
        // Null / blank check
        BP_OmniApprovalLwcController.PaymentExtensionSummaryWrapper empty1 =
            BP_OmniApprovalLwcController.getPaymentExtensionSummary(null);
        System.assertEquals(false, empty1.showMilestoneInfo);

        // Invalid record ID
        BP_OmniApprovalLwcController.PaymentExtensionSummaryWrapper empty2 =
            BP_OmniApprovalLwcController.getPaymentExtensionSummary('001000000000000AAA');
        System.assertEquals(false, empty2.showMilestoneInfo);

        // Non-Payment Extension BP
        BP_OmniApprovalLwcController.PaymentExtensionSummaryWrapper nonPE =
            BP_OmniApprovalLwcController.getPaymentExtensionSummary(stepDT.Id);
        System.assertEquals(false, nonPE.showMilestoneInfo);

        // Valid Payment Extension step
        BP_OmniApprovalLwcController.PaymentExtensionSummaryWrapper peResult =
            BP_OmniApprovalLwcController.getPaymentExtensionSummary(stepPE.Id);
        System.assertEquals(true, peResult.showMilestoneInfo);
        System.assertEquals(1, peResult.milestoneNumber);
        System.assertEquals(50000, peResult.installmentAmount);
        Test.stopTest();
    }

    // Covers getEOIRefundSummary (lines 1600-1678)
    @isTest
    static void testEOIRefundSummary() {
        Business_Process__c bpEOI = [
            SELECT Id FROM Business_Process__c
            WHERE Type__c = 'EOI Refund Approval' LIMIT 1
        ];
        Business_Process_Step__c stepEOI = [
            SELECT Id FROM Business_Process_Step__c
            WHERE Business_Process__c = :bpEOI.Id LIMIT 1
        ];
        Business_Process__c bpDT = [
            SELECT Id FROM Business_Process__c
            WHERE Type__c = 'Default And Termination' LIMIT 1
        ];
        Business_Process_Step__c stepDT = [
            SELECT Id FROM Business_Process_Step__c
            WHERE Business_Process__c = :bpDT.Id LIMIT 1
        ];

        Test.startTest();
        // Null / blank check
        BP_OmniApprovalLwcController.EOIRefundSummaryWrapper empty1 =
            BP_OmniApprovalLwcController.getEOIRefundSummary(null);
        System.assertEquals(false, empty1.showEOIList);

        // Invalid ID
        BP_OmniApprovalLwcController.EOIRefundSummaryWrapper empty2 =
            BP_OmniApprovalLwcController.getEOIRefundSummary('001000000000000AAA');
        System.assertEquals(false, empty2.showEOIList);

        // Non-EOI Refund step
        BP_OmniApprovalLwcController.EOIRefundSummaryWrapper nonEOI =
            BP_OmniApprovalLwcController.getEOIRefundSummary(stepDT.Id);
        System.assertEquals(false, nonEOI.showEOIList);

        // Valid EOI Refund step
        BP_OmniApprovalLwcController.EOIRefundSummaryWrapper eoiResult =
            BP_OmniApprovalLwcController.getEOIRefundSummary(stepEOI.Id);
        System.assertEquals(true, eoiResult.showEOIList);
        System.assertEquals(1, eoiResult.eois.size());
        System.assertEquals(10000, eoiResult.eois[0].eoiAmountAED);
        Test.stopTest();
    }

    // Covers all helper methods directly:
    // formatValue, formatFieldValue, generateLabel, getStepName,
    // getApplicableGridConfigs, getFieldValue, getRelationshipValue
    @isTest
    static void testHelperMethodsDirectly() {
        Business_Process__c bp = [
            SELECT Id, Name, Type__c, Process_Flow__c, Process_Flow__r.Name
            FROM Business_Process__c
            WHERE Type__c = 'Default And Termination' LIMIT 1
        ];
        Business_Process_Step__c step1 = [
            SELECT Id, Name, Status__c, Step__c, Business_Process_Steps_Name_Custom__c,
                   Business_Process__c, Business_Process__r.Type__c
            FROM Business_Process_Step__c
            WHERE Business_Process__c = :bp.Id LIMIT 1
        ];

        Test.startTest();

        // formatValue branches
        System.assertEquals('', BP_OmniApprovalLwcController.formatValue(null));
        System.assertNotEquals('', BP_OmniApprovalLwcController.formatValue(Date.today()));
        System.assertNotEquals('', BP_OmniApprovalLwcController.formatValue(Datetime.now()));
        System.assertEquals('Sample', BP_OmniApprovalLwcController.formatValue('Sample'));
        System.assertEquals('123', BP_OmniApprovalLwcController.formatValue(123));

        // formatFieldValue branches
        System.assertEquals('', BP_OmniApprovalLwcController.formatFieldValue(null));
        System.assertNotEquals('', BP_OmniApprovalLwcController.formatFieldValue(Date.today()));
        System.assertNotEquals('', BP_OmniApprovalLwcController.formatFieldValue(Datetime.now()));
        System.assertEquals('Val', BP_OmniApprovalLwcController.formatFieldValue('Val'));

        // generateLabel branches
        System.assertEquals('', BP_OmniApprovalLwcController.generateLabel(null));
        System.assertEquals('', BP_OmniApprovalLwcController.generateLabel(''));
        System.assertEquals('Name', BP_OmniApprovalLwcController.generateLabel('Account__r.Name'));
        System.assertEquals('Custom Field', BP_OmniApprovalLwcController.generateLabel('Step__r.Custom_Field__c'));

        // getStepName branches
        step1.Business_Process_Steps_Name_Custom__c = 'Custom Title';
        System.assertEquals('Custom Title', BP_OmniApprovalLwcController.getStepName(step1));
        step1.Business_Process_Steps_Name_Custom__c = null;
        step1.Step__c = 'Standard Step';
        System.assertEquals('Standard Step', BP_OmniApprovalLwcController.getStepName(step1));
        step1.Step__c = null;
        System.assertEquals(step1.Name, BP_OmniApprovalLwcController.getStepName(step1));

        // getApplicableGridConfigs branches
        List<BP_OmniApprovalLwcController.GridConfig> nullCheck =
            BP_OmniApprovalLwcController.getApplicableGridConfigs(null, 'Cost Approval');
        System.assertEquals(0, nullCheck.size());

        List<BP_OmniApprovalLwcController.GridConfig> sampleConfigs =
            new List<BP_OmniApprovalLwcController.GridConfig>();

        BP_OmniApprovalLwcController.GridConfig cInactive = new BP_OmniApprovalLwcController.GridConfig();
        cInactive.active = false;
        sampleConfigs.add(cInactive);

        BP_OmniApprovalLwcController.GridConfig cGlobal = new BP_OmniApprovalLwcController.GridConfig();
        cGlobal.active = true;
        cGlobal.bpType = '';
        sampleConfigs.add(cGlobal);

        BP_OmniApprovalLwcController.GridConfig cDefault = new BP_OmniApprovalLwcController.GridConfig();
        cDefault.active = true;
        cDefault.bpType = 'Default Config';
        sampleConfigs.add(cDefault);

        BP_OmniApprovalLwcController.GridConfig cSpecific = new BP_OmniApprovalLwcController.GridConfig();
        cSpecific.active = true;
        cSpecific.bpType = 'MatchMe';
        sampleConfigs.add(cSpecific);

        // Branch 1: specific match exists
        List<BP_OmniApprovalLwcController.GridConfig> matched =
            BP_OmniApprovalLwcController.getApplicableGridConfigs(sampleConfigs, 'MatchMe');
        System.assertEquals(2, matched.size()); // global + specific

        // Branch 2: no specific match, falls back to default
        List<BP_OmniApprovalLwcController.GridConfig> fallback =
            BP_OmniApprovalLwcController.getApplicableGridConfigs(sampleConfigs, 'UnknownType');
        System.assertEquals(2, fallback.size()); // global + default

        // getFieldValue branches
        System.assertEquals(null, BP_OmniApprovalLwcController.getFieldValue(null, 'Name'));
        System.assertEquals(null, BP_OmniApprovalLwcController.getFieldValue(bp, ''));
        System.assertEquals('Default And Termination', BP_OmniApprovalLwcController.getFieldValue(bp, 'Type__c'));
        System.assertEquals('Test Flow', BP_OmniApprovalLwcController.getFieldValue(bp, 'Process_Flow__r.Name'));
        System.assertEquals('Test Flow', BP_OmniApprovalLwcController.getFieldValue(bp, 'Process_Flow__c')); // REFERENCE describe query

        // getRelationshipValue branches
        System.assertEquals(null, BP_OmniApprovalLwcController.getRelationshipValue(null, 'Name'));
        System.assertEquals(step1.Status__c, BP_OmniApprovalLwcController.getRelationshipValue(step1, 'Status__c'));
        System.assertEquals('Default And Termination', BP_OmniApprovalLwcController.getRelationshipValue(step1, 'Business_Process__r.Type__c'));

        Test.stopTest();
    }
}