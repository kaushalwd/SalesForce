// File: LPCWaiverPDFController.cls
public with sharing class LPCWaiverPDFController {
    public User currentUser { get; private set; }
    public List<StepRow> approvalSteps { get; private set; }

    public class StepRow {
        public String ApproverName { get; set; }
        public String Title        { get; set; }
        public String Status       { get; set; }
    }

    private final ApexPages.StandardController std;

    public LPCWaiverPDFController(ApexPages.StandardController sc) {
        this.std = sc;
        currentUser = [
            SELECT Id, Name, Title
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        approvalSteps = fetchApprovalSteps((Id)std.getId());
    }

    private List<StepRow> fetchApprovalSteps(Id targetId) {
        List<StepRow> rows = new List<StepRow>();
        if (targetId == null) return rows;

        for (ProcessInstance pi : [
            SELECT Id,
                   (SELECT Id, StepStatus, CreatedDate, ActorId, Actor.Name, Actor.Title
                    FROM Steps ORDER BY CreatedDate ASC)
            FROM ProcessInstance
            WHERE TargetObjectId = :targetId
            ORDER BY CreatedDate ASC
        ]) {
            for (ProcessInstanceStep st : pi.Steps) {
                if (st.StepStatus == 'Started') continue;
                StepRow r = new StepRow();
                r.ApproverName = (st.Actor != null) ? st.Actor.Name  : '';
                r.Title        = (st.Actor != null) ? st.Actor.Title : '';
                r.Status       = st.StepStatus;
                rows.add(r);
            }
        }
        return rows;
    }
}