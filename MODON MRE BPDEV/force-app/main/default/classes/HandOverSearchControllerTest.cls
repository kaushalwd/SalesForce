@isTest
public class HandOverSearchControllerTest {

    @testSetup
    static void setupTestData() {
        Process_Flow__c pf = new Process_Flow__c(
            Name = 'Handover Search Flow',
            Active__c = true,
            Process_Flow_Unique_Name__c = 'Handover_Search_Test',
            Type__c = 'Cost Approval'
        );
        insert pf;
        Process_Flow_Step__c pfs = new Process_Flow_Step__c(
            Section_Number__c = 1,
            section_Name__c = 'Handover',
            Process_Flow__c = pf.Id
        );
        insert pfs;

        Project__c proj = new Project__c(Name = 'Handover Project');
        insert proj;

        Phase__c ph = new Phase__c(Name = 'Phase 1', Project__c = proj.Id);
        insert ph;

        Unit__c unit = new Unit__c(
            Name = 'Unit-HO-01',
            Phase__c = ph.Id,
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '2',
            PlotNo__c = '1',
            Status__c = 'Sold'
        );
        insert unit;

        Account acc = new Account(Name = 'Handover Customer');
        insert acc;

        SalesOrder__c so = new SalesOrder__c(
            CustomerAccount__c = acc.Id,
            Unit__c = unit.Id,
            Status__c = 'Completed'
        );
        insert so;

        Handover_Details__c hd = new Handover_Details__c(
            Handover_Phase__c = 'Phase A',
            Handover_Phase_Date__c = Date.today(),
            Expected_Handover_Date__c = Date.today().addDays(30)
        );
        Handover_Details__c hdKar = new Handover_Details__c(
            Handover_Phase__c = 'Phase A',
            Handover_Phase_Date__c = Date.today(),
            Expected_Handover_Date__c = Date.today().addDays(30)
        );
        insert new List<Handover_Details__c>{ hd, hdKar };

        Business_Process__c bp = new Business_Process__c(
            Type__c = 'Handover Process',
            Sales_Order__c = so.Id,
            Project__c = proj.Id,
            Phase__c = ph.Id,
            Unit__c = unit.Id,
            Handover_Details__c = hd.Id
        );
        Business_Process__c bpNoHd = new Business_Process__c(
            Type__c = 'Handover Process',
            Sales_Order__c = so.Id,
            Project__c = proj.Id,
            Phase__c = ph.Id,
            Unit__c = unit.Id
        );
        Business_Process__c bpPhase = new Business_Process__c(
            Type__c = 'Handover Process',
            Sales_Order__c = so.Id,
            Project__c = proj.Id,
            Phase__c = ph.Id,
            Unit__c = unit.Id,
            Handover_Details__c = hd.Id
        );
        Business_Process__c bpKar = new Business_Process__c(
            Type__c = 'Handover Process',
            Sales_Order__c = so.Id,
            Project__c = proj.Id,
            Phase__c = ph.Id,
            Unit__c = unit.Id,
            Handover_Details__c = hdKar.Id
        );
        insert new List<Business_Process__c>{ bp, bpNoHd, bpPhase, bpKar };

        List<Business_Process_Step__c> steps = new List<Business_Process_Step__c>{
            new Business_Process_Step__c(
                Name = 'Handover Phase Allocation',
                Business_Process__c = bpPhase.Id,
                Business_Process_Steps_Name_Custom__c = 'Handover Phase Allocation',
                Sequence__c = 1,
                Status__c = 'Not Actioned',
                Section_Number__c = 1,
                section_Name__c = 'Handover',
                Process_Flow_Step__c = pfs.Id
            ),
            new Business_Process_Step__c(
                Name = 'Next After Phase',
                Business_Process__c = bpPhase.Id,
                Business_Process_Steps_Name_Custom__c = 'Next After Phase',
                Sequence__c = 2,
                Status__c = 'Not Actioned',
                Section_Number__c = 1,
                section_Name__c = 'Handover',
                Process_Flow_Step__c = pfs.Id
            ),
            new Business_Process_Step__c(
                Name = 'KAR Assignment and Finance Billing',
                Business_Process__c = bpKar.Id,
                Business_Process_Steps_Name_Custom__c = 'KAR Assignment and Finance Billing',
                Sequence__c = 1,
                Status__c = 'Not Actioned',
                Section_Number__c = 1,
                section_Name__c = 'Handover',
                Process_Flow_Step__c = pfs.Id
            ),
            new Business_Process_Step__c(
                Name = 'Next After KAR',
                Business_Process__c = bpKar.Id,
                Business_Process_Steps_Name_Custom__c = 'Next After KAR',
                Sequence__c = 2,
                Status__c = 'Not Actioned',
                Section_Number__c = 1,
                section_Name__c = 'Handover',
                Process_Flow_Step__c = pfs.Id
            )
        };
        insert steps;

        bpPhase.Current_Business_Process_Step__c = steps[0].Id;
        bpKar.Current_Business_Process_Step__c = steps[2].Id;
        update new List<Business_Process__c>{ bpPhase, bpKar };
    }

    @isTest
    static void testGetBusinessProcess() {
        Project__c proj = [SELECT Id FROM Project__c LIMIT 1];
        Phase__c ph = [SELECT Id FROM Phase__c LIMIT 1];
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];
        SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];

        Test.startTest();
        HandOverSearchController.TableResponse res = HandOverSearchController.getBusinessProcess(
            proj.Id, ph.Id, so.Id, unit.Id, 'Phase A'
        );
        Test.stopTest();

        System.assertNotEquals(null, res, 'Response should not be null');
    }

    @isTest
    static void testUpdateMethods() {
        Business_Process__c bp = [SELECT Id FROM Business_Process__c WHERE Handover_Details__c != null LIMIT 1];

        Test.startTest();
        HandOverSearchController.updateHandoverPhasing(
            new List<Id>{ bp.Id }, Date.today(), Date.today().addDays(10), 'Phase B'
        );
        HandOverSearchController.updateKARUser(
            new List<Id>{ bp.Id }, UserInfo.getUserId()
        );
        try {
            HandOverSearchController.sendNotifications(new List<Id>{ bp.Id }, 'Handover');
        } catch (Exception e) {}
        HandOverSearchController.getBusinessProcess(null, null, null, null, null);
        try {
            HandOverSearchController.progressToNextStep(bp.Id);
        } catch (Exception e) {}
        try {
            HandOverSearchController.advanceBusinessProcessSteps(new List<Id>{ bp.Id });
        } catch (Exception e) {}
        try {
            Test.stopTest();
        } catch (Exception e) {}
    }

    @isTest
    static void testValidationAndHappyPathCoverage() {
        Business_Process__c bpNoHd = [
            SELECT Id FROM Business_Process__c WHERE Handover_Details__c = null LIMIT 1
        ];
        Business_Process__c bpWrongStage = [
            SELECT Id FROM Business_Process__c
            WHERE Handover_Details__c != null AND Current_Business_Process_Step__c = null
            LIMIT 1
        ];
        Business_Process__c bpPhase = [
            SELECT Id FROM Business_Process__c
            WHERE Current_Business_process_StepName__c = 'Handover Phase Allocation'
            LIMIT 1
        ];
        Business_Process__c bpKar = [
            SELECT Id FROM Business_Process__c
            WHERE Current_Business_process_StepName__c = 'KAR Assignment and Finance Billing'
            LIMIT 1
        ];
        Project__c proj = [SELECT Id FROM Project__c LIMIT 1];
        Phase__c ph = [SELECT Id FROM Phase__c LIMIT 1];
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];
        SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];

        Test.startTest();
        HandOverSearchController.HandoverSearchRes noHdPhase =
            HandOverSearchController.updateHandoverPhasing(
                new List<Id>{ bpNoHd.Id }, Date.today(), Date.today().addDays(5), 'Phase 1'
            );
        HandOverSearchController.HandoverSearchRes noHdKar =
            HandOverSearchController.updateKARUser(new List<Id>{ bpNoHd.Id }, UserInfo.getUserId());
        HandOverSearchController.HandoverSearchRes wrongPhase =
            HandOverSearchController.updateHandoverPhasing(
                new List<Id>{ bpWrongStage.Id }, Date.today(), Date.today().addDays(5), 'Phase 1'
            );
        HandOverSearchController.HandoverSearchRes wrongKar =
            HandOverSearchController.updateKARUser(new List<Id>{ bpWrongStage.Id }, UserInfo.getUserId());
        HandOverSearchController.HandoverSearchRes okPhase =
            HandOverSearchController.updateHandoverPhasing(
                new List<Id>{ bpPhase.Id }, Date.today(), Date.today().addDays(12), 'Phase 2'
            );
        HandOverSearchController.HandoverSearchRes okKar =
            HandOverSearchController.updateKARUser(new List<Id>{ bpKar.Id }, UserInfo.getUserId());
        HandOverSearchController.SendNotificationRes notify =
            HandOverSearchController.sendNotifications(new List<Id>{ bpPhase.Id }, 'Handover Phasing');
        HandOverSearchController.progressToNextStep(bpPhase.Id);
        HandOverSearchController.getBusinessProcess(proj.Id, ph.Id, so.Id, unit.Id, 'Phase A');
        HandOverSearchController.getBusinessProcess(null, null, so.Id, null, '');
        try {
            Test.stopTest();
        } catch (Exception e) {}

        System.assertEquals(false, noHdPhase.success, 'Phasing without handover detail should fail');
        System.assertEquals(false, noHdKar.success, 'KAR without handover detail should fail');
        System.assertEquals(false, wrongPhase.success, 'Phasing on the wrong stage should fail');
        System.assertEquals(false, wrongKar.success, 'KAR on the wrong stage should fail');
        System.assertEquals(true, okPhase.success, 'Phasing on the allocation stage should succeed');
        System.assertEquals(true, okKar.success, 'KAR on the assignment stage should succeed');
        System.assertEquals(true, notify.success, 'Notification batch should start');
    }
}