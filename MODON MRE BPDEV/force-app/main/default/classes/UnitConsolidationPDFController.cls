public class UnitConsolidationPDFController {
    public ServiceRequest__c serviceRequest { get; private set; }
    public List<Unit_Consolidation__c> consolidations { get; private set; }
    public List<ApprovalStepWrapper> approvalSteps { get; private set; }
    public User currentUser { get; private set; }

    public UnitConsolidationPDFController(ApexPages.StandardController std) {
        Id srId = ApexPages.currentPage().getParameters().get('id');
        if (srId == null) return;

        serviceRequest = [
            SELECT Id, Name, Description__c,
                   Equity_Transfer_Amount__c, Forfeiture__c, Market_Loss__c, Total_Amount__c, Payable_to_Customer__c,
                   SalesOrder__r.CustomerAccount__r.Name
            FROM ServiceRequest__c
            WHERE Id = :srId
        ];

        consolidations = [
            SELECT Unit__c, Sales_Order__c, IsConsolidated__c, Fund_Transfer__c, Amount_Paid__c,Unit__r.Name,Sales_Order__r.Name,
                   Secondary_Market_Value__c, Transfer_Amount__c
            FROM Unit_Consolidation__c
            WHERE Service_Request__c = :srId
        ];

        approvalSteps = new List<ApprovalStepWrapper>();
        for (ProcessInstance pi : [
            SELECT Id, (SELECT StepStatus, Actor.Name, Actor.Title FROM Steps)
            FROM ProcessInstance
            WHERE TargetObjectId = :srId
        ]) {
            for (ProcessInstanceStep step : pi.Steps) {
                if (step.StepStatus != 'Started') {
                    approvalSteps.add(new ApprovalStepWrapper(step.Actor.Name, step.Actor.Title, step.StepStatus));
                }
            }
        }

        currentUser = [
            SELECT Name, Title
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
    }

    public class ApprovalStepWrapper {
        public String ApproverName { get; set; }
        public String Title { get; set; }
        public String Status { get; set; }

        public ApprovalStepWrapper(String name, String title, String status) {
            this.ApproverName = name;
            this.Title = title;
            this.Status = status;
        }
    }
}