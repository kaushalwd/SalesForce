@isTest
private class LPCWaiverPDFControllerTest {
    @isTest
    static void testControllerApprovalFlow() {
        User testUser = [SELECT Id, Name, Title FROM User WHERE Id = :UserInfo.getUserId()];

        System.runAs(testUser) {
            ServiceRequest__c sr = new ServiceRequest__c(
                Status__c = 'New'
            );
            insert sr;

            Approval.ProcessSubmitRequest submitReq = new Approval.ProcessSubmitRequest();
            submitReq.setObjectId(sr.Id);
            submitReq.setSkipEntryCriteria(true);
            submitReq.setNextApproverIds(new Id[] { UserInfo.getUserId() });
            submitReq.setComments('Submit from test');
            Approval.ProcessResult submitResult = Approval.process(submitReq);

            Id workItemId = [
                SELECT Id
                FROM ProcessInstanceWorkitem
                WHERE ProcessInstance.TargetObjectId = :sr.Id
                LIMIT 1
            ].Id;

            Approval.ProcessWorkitemRequest approveReq = new Approval.ProcessWorkitemRequest();
            approveReq.setWorkitemId(workItemId);
            approveReq.setAction('Approve');
            approveReq.setComments('Approved from test');
            Approval.ProcessResult approveResult = Approval.process(approveReq);

            ApexPages.StandardController sc = new ApexPages.StandardController(sr);
            LPCWaiverPDFController controller = new LPCWaiverPDFController(sc);

        }
    }
}