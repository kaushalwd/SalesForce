@isTest
public class BlockRequestTriggerHelperTest {
    @isTest
    static void testCheckBlockApproval() {
        Unit__c testUnit = new Unit__c();
        testUnit.PlotAreasqm__c = 1.0;
        testUnit.PlotNo__c = '1';
        testUnit.Status__c='Available';
        testUnit.Sub_Status__c='Un-Assigned';
        testUnit.BlockedBy__c=null;
        insert testUnit;

        Block_Request__c testBlockRequest = new Block_Request__c(
            Status__c = 'In Progress',
            Unit__c = testUnit.Id,
            Hourstoblock__c = '2'
        );
        insert testBlockRequest;
        
        Block_Request__c oldBr = [SELECT id, Status__c,Unit__c FROM Block_Request__c WHERE Id =: testBlockRequest.Id];
        
        testBlockRequest.Status__c = 'Approved';
        update testBlockRequest;
        
        Block_Request__c newBr = [SELECT id, Status__c,Unit__c FROM Block_Request__c WHERE Id =: testBlockRequest.Id];

        Approval.ProcessSubmitRequest req1 = new Approval.ProcessSubmitRequest();
        req1.setComments('Submitting request for approval.');
        req1.setObjectId(testBlockRequest.Id);
        List<ProcessInstance> approvalProcesses = [SELECT Id, TargetObjectId, status FROM ProcessInstance WHERE TargetObjectId =: testBlockRequest.Id];

        List<ProcessInstanceWorkitem> workItems = [SELECT Id, ProcessInstanceId FROM ProcessInstanceWorkitem WHERE ProcessInstanceId IN :approvalProcesses];
        System.debug('asdsad ' + workitems);

        if (!workItems.isEmpty()) {
            Approval.ProcessWorkitemRequest req = new Approval.ProcessWorkitemRequest();
            req.setComments('Approving the request.');
            req.setAction('Approve');
            req.setWorkitemId(workItems[0].Id);

            Approval.ProcessResult result = Approval.process(req);
        }

        testBlockRequest = [SELECT Id, Status__c FROM Block_Request__c WHERE Id =: testBlockRequest.Id];

        Map<Id, SObject> oldMap = new Map<Id, SObject>{oldBr.Id => oldBr};
        Map<Id, SObject> newMap = new Map<Id, SObject>{newBr.Id => newBr};

        Test.startTest();
        BlockRequestTriggerHelper.checkBlockApproval(oldMap, newMap);
        Test.stopTest();

        testUnit = [SELECT Id, Status__c, BlockedFor__c, BlockedBy__c, BlockUntil__c FROM Unit__c WHERE Id =: testUnit.Id];
    }
}