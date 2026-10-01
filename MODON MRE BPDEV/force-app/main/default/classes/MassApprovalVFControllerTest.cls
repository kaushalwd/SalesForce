@isTest
public class MassApprovalVFControllerTest {

    private static MassApprovalVFController.WorkItemWrapper buildMockItem(Boolean selected) {
        MassApprovalVFController.WorkItemWrapper wi =
            new MassApprovalVFController.WorkItemWrapper(
                UserInfo.getUserId(),
                'Test Record',
                DateTime.now(),
                2.0
            );
        wi.isSelected = selected;
        return wi;
    }

    private static void injectMockItems(Integer count, Boolean selected) {
        List<MassApprovalVFController.WorkItemWrapper> items =
            new List<MassApprovalVFController.WorkItemWrapper>();
        for (Integer i = 0; i < count; i++) {
            items.add(buildMockItem(selected));
        }
        MassApprovalVFController.mockItems = items;
    }

    private static void setupApprovalMock(Integer successCount, Integer errorCount) {
        MassApprovalVFController.skipApproval     = true;
        MassApprovalVFController.mockSuccessCount = successCount;
        MassApprovalVFController.mockErrorCount   = errorCount;
    }

    @isTest
    static void testConstructorDefaults() {
        Test.startTest();
        MassApprovalVFController ctrl = new MassApprovalVFController();
        Test.stopTest();

        System.assertNotEquals(null,   ctrl.workItems);
        System.assertEquals('Approve', ctrl.actionType);
        System.assertEquals('',        ctrl.comments);
        System.assertEquals(false,     ctrl.isProcessed);
        System.assertEquals(false,     ctrl.isReject);
        System.assertEquals(false,     ctrl.isSuccess);
    }

    @isTest
    static void testConstructorLoadsMockItems() {
        injectMockItems(3, false);

        Test.startTest();
        MassApprovalVFController ctrl = new MassApprovalVFController();
        Test.stopTest();

        System.assertEquals(3, ctrl.workItems.size());
    }

    @isTest
    static void testMockWorkItemWrapper() {
        Test.startTest();
        MassApprovalVFController.WorkItemWrapper wi = buildMockItem(false);
        Test.stopTest();

        System.assertEquals(false,        wi.isSelected);
        System.assertEquals('Test Record', wi.recordName);
        System.assertEquals(2.0,           wi.elapsedDays);
        System.assertNotEquals(null,        wi.createdDate);
        System.assertNotEquals(null,        wi.workItemId);
    }

    @isTest
    static void testOnActionChangeToReject() {
        MassApprovalVFController ctrl = new MassApprovalVFController();
        ctrl.actionType = 'Reject';

        Test.startTest();
        ctrl.onActionChange();
        Test.stopTest();

        System.assertEquals(true, ctrl.isReject);
    }

    @isTest
    static void testOnActionChangeToApprove() {
        MassApprovalVFController ctrl = new MassApprovalVFController();
        ctrl.actionType = 'Reject';
        ctrl.onActionChange();
        ctrl.comments   = 'Some reason';
        ctrl.actionType = 'Approve';

        Test.startTest();
        ctrl.onActionChange();
        Test.stopTest();

        System.assertEquals(false, ctrl.isReject);
        System.assertEquals('',    ctrl.comments);
    }

    @isTest
    static void testProcessApprovalRejectNoComments() {
        MassApprovalVFController ctrl = new MassApprovalVFController();
        ctrl.actionType = 'Reject';
        ctrl.onActionChange();
        ctrl.comments   = '';

        Test.startTest();
        PageReference result = ctrl.processApproval();
        Test.stopTest();

        System.assertEquals(null,  result);
        System.assertEquals(false, ctrl.isProcessed);
        List<ApexPages.Message> msgs = ApexPages.getMessages();
        System.assert(msgs.size() > 0);
        System.assertEquals('Rejection comments are required.', msgs[0].getSummary());
    }

    @isTest
    static void testProcessApprovalNothingSelected() {
        injectMockItems(2, false);

        MassApprovalVFController ctrl = new MassApprovalVFController();

        Test.startTest();
        PageReference result = ctrl.processApproval();
        Test.stopTest();

        System.assertEquals(null,  result);
        System.assertEquals(false, ctrl.isProcessed);
        List<ApexPages.Message> msgs = ApexPages.getMessages();
        System.assert(msgs.size() > 0);
        System.assertEquals('Please select at least one record.', msgs[0].getSummary());
    }

    @isTest
    static void testProcessApprovalApproveAllSuccess() {
        injectMockItems(2, true);
        setupApprovalMock(2, 0);

        MassApprovalVFController ctrl = new MassApprovalVFController();
        ctrl.actionType = 'Approve';

        Test.startTest();
        PageReference result = ctrl.processApproval();
        Test.stopTest();

        System.assertEquals(null,  result);
        System.assertEquals(true,  ctrl.isProcessed);
        System.assertEquals(true,  ctrl.isSuccess);
        System.assert(ctrl.resultMessage.contains('2'));
    }

    @isTest
    static void testProcessApprovalApprovePartialFailure() {
        injectMockItems(2, true);
        setupApprovalMock(1, 1);

        MassApprovalVFController ctrl = new MassApprovalVFController();
        ctrl.actionType = 'Approve';

        Test.startTest();
        ctrl.processApproval();
        Test.stopTest();

        System.assertEquals(true,  ctrl.isProcessed);
        System.assertEquals(false, ctrl.isSuccess);
        System.assert(ctrl.resultMessage.contains('failed'));
    }

    @isTest
    static void testProcessApprovalAllFailed() {
        injectMockItems(2, true);
        setupApprovalMock(0, 2);

        MassApprovalVFController ctrl = new MassApprovalVFController();
        ctrl.actionType = 'Approve';

        Test.startTest();
        ctrl.processApproval();
        Test.stopTest();

        System.assertEquals(true,  ctrl.isProcessed);
        System.assertEquals(false, ctrl.isSuccess);
        System.assert(ctrl.resultMessage.contains('failed'));
    }

    @isTest
    static void testProcessApprovalRejectSuccess() {
        injectMockItems(2, true);
        setupApprovalMock(2, 0);

        MassApprovalVFController ctrl = new MassApprovalVFController();
        ctrl.actionType = 'Reject';
        ctrl.onActionChange();
        ctrl.comments   = 'Rejected in test';

        Test.startTest();
        PageReference result = ctrl.processApproval();
        Test.stopTest();

        System.assertEquals(null,  result);
        System.assertEquals(true,  ctrl.isProcessed);
        System.assertEquals(true,  ctrl.isSuccess);
        System.assert(ctrl.resultMessage.contains('reject'));
    }

    @isTest
    static void testProcessApprovalRejectPartialFailure() {
        injectMockItems(3, true);
        setupApprovalMock(2, 1);

        MassApprovalVFController ctrl = new MassApprovalVFController();
        ctrl.actionType = 'Reject';
        ctrl.onActionChange();
        ctrl.comments   = 'Partial rejection test';

        Test.startTest();
        ctrl.processApproval();
        Test.stopTest();

        System.assertEquals(true,  ctrl.isProcessed);
        System.assertEquals(false, ctrl.isSuccess);
        System.assert(ctrl.resultMessage.contains('failed'));
    }

    @isTest
    static void testProcessApprovalMixedSelection() {
        List<MassApprovalVFController.WorkItemWrapper> items =
            new List<MassApprovalVFController.WorkItemWrapper>();
        items.add(buildMockItem(true));
        items.add(buildMockItem(false));
        items.add(buildMockItem(true));
        MassApprovalVFController.mockItems = items;
        setupApprovalMock(2, 0);

        MassApprovalVFController ctrl = new MassApprovalVFController();
        ctrl.actionType = 'Approve';

        Test.startTest();
        ctrl.processApproval();
        Test.stopTest();

        System.assertEquals(true, ctrl.isProcessed);
        System.assertEquals(true, ctrl.isSuccess);
        System.assertEquals(3,    ctrl.workItems.size());
    }

    @isTest
    static void testRealWorkItemsIfApprovalProcessExists() {
        List<ProcessInstanceWorkitem> wis = [
            SELECT Id, ActorId
            FROM ProcessInstanceWorkitem
            LIMIT 1
        ];

        if (wis.isEmpty()) return;

        User approver = [SELECT Id FROM User WHERE Id = :wis[0].ActorId LIMIT 1];

        System.runAs(approver) {
            Test.startTest();
            MassApprovalVFController ctrl = new MassApprovalVFController();
            Test.stopTest();

            if (!ctrl.workItems.isEmpty()) {
                System.assertEquals(false,  ctrl.workItems[0].isSelected);
                System.assertNotEquals(null, ctrl.workItems[0].workItemId);
                System.assertNotEquals(null, ctrl.workItems[0].recordName);
            }
        }
    }
}