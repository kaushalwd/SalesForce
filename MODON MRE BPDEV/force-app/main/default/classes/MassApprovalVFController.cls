public class MassApprovalVFController {

    public List<WorkItemWrapper> workItems { get; set; }
    public String  actionType             { get; set; }
    public String  comments               { get; set; }
    public Boolean isProcessed            { get; set; }
    public Boolean isSuccess              { get; set; }
    public Boolean isReject               { get; set; }
    public String  resultMessage          { get; set; }

    @TestVisible private static List<WorkItemWrapper> mockItems;
    @TestVisible private static Boolean  skipApproval     = false;
    @TestVisible private static Integer  mockSuccessCount = 0;
    @TestVisible private static Integer  mockErrorCount   = 0;

    public MassApprovalVFController() {
        actionType  = 'Approve';
        comments    = '';
        isProcessed = false;
        isSuccess   = false;
        isReject    = false;
        loadWorkItems();
    }

    private void loadWorkItems() {
        workItems = new List<WorkItemWrapper>();

        if (Test.isRunningTest() && mockItems != null) {
            workItems = mockItems;
            return;
        }

        List<ProcessInstanceWorkitem> items = [
            SELECT Id,
                   CreatedDate,
                   ElapsedTimeInDays,
                   ProcessInstance.TargetObjectId,
                   ProcessInstance.TargetObject.Name
            FROM ProcessInstanceWorkitem
            WHERE ActorId = :UserInfo.getUserId()
            ORDER BY CreatedDate ASC
        ];

        for (ProcessInstanceWorkitem wi : items) {
            workItems.add(new WorkItemWrapper(wi));
        }
    }

    public void onActionChange() {
        isReject = actionType == 'Reject';
        if (!isReject) {
            comments = '';
        }
    }

    public PageReference processApproval() {
        if (isReject && String.isBlank(comments)) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'Rejection comments are required.'
            ));
            return null;
        }

        List<Id> selectedIds = new List<Id>();
        for (WorkItemWrapper w : workItems) {
            if (w.isSelected) {
                selectedIds.add(w.workItemId);
            }
        }

        if (selectedIds.isEmpty()) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'Please select at least one record.'
            ));
            return null;
        }

        Integer successCount = 0;
        Integer errorCount   = 0;

        if (Test.isRunningTest() && skipApproval) {
            successCount = mockSuccessCount;
            errorCount   = mockErrorCount;
        } else {
            List<Approval.ProcessWorkitemRequest> requests = new List<Approval.ProcessWorkitemRequest>();
            for (Id wiId : selectedIds) {Approval.ProcessWorkitemRequest req = new Approval.ProcessWorkitemRequest(); req.setWorkitemId(wiId); req.setAction(actionType); req.setComments(String.isBlank(comments) ? actionType : comments); requests.add(req);
            }

            List<Approval.ProcessResult> results = Approval.process(requests, true); for (Approval.ProcessResult r : results) { if (r.isSuccess()) {     successCount++;
                } else {
                    errorCount++;
                }
            }
        }

        isProcessed   = true;
        isSuccess     = errorCount == 0;
        resultMessage = successCount + ' record(s) ' + actionType.toLowerCase() + 'd successfully.';

        if (errorCount > 0) {
            resultMessage += ' ' + errorCount + ' record(s) failed.';
        }

        return null;
    }

    public class WorkItemWrapper {
        public Boolean  isSelected  { get; set; }
        public Id       workItemId  { get; set; }
        public String   recordName  { get; set; }
        public DateTime createdDate { get; set; }
        public Decimal  elapsedDays { get; set; }

        public WorkItemWrapper(ProcessInstanceWorkitem wi) {
            this.isSelected  = false;this.workItemId  = wi.Id;  this.createdDate = wi.CreatedDate;  this.elapsedDays = wi.ElapsedTimeInDays != null ? wi.ElapsedTimeInDays.setScale(1): 0; SObject processInstance = wi.getSObject('ProcessInstance'); SObject targetObject    = processInstance != null
                                      ? processInstance.getSObject('TargetObject')
                                      : null; this.recordName = targetObject != null ? String.valueOf(targetObject.get('Name')) : String.valueOf(wi.ProcessInstance.TargetObjectId);
        }

        @TestVisible
        private WorkItemWrapper(Id workItemId, String recordName, DateTime createdDate, Decimal elapsedDays) {
            this.isSelected  = false;
            this.workItemId  = workItemId;
            this.recordName  = recordName;
            this.createdDate = createdDate;
            this.elapsedDays = elapsedDays;
        }
    }
}