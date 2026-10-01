public class UnitUpgradeOrSwapPDFController {
    public ServiceRequest__c serviceRequest { get; private set; }
    public List<SalesOrderInstallments__c> installments { get; private set; }
    public List<ProcessInstanceStep> approvalSteps { get; private set; }
    public String latestApproverName { get; private set; }

    public UnitUpgradeOrSwapPDFController() {
        Id srId = ApexPages.currentPage().getParameters().get('id');
        if(srId == null) return;

        serviceRequest = [
            SELECT Id, Name,Selected_Unit__r.Name,Actual_Requested_Date__c,New_Payment_Plan__c,Last_Payment_Plan__c,Previous_Payment_Plan__c,Payment_Extension_Date__c, Description__c,
                   SalesOrder__r.Name, SalesOrder__r.TotalAmount__c, SalesOrder__r.Totalpaidamount__c,
                   SalesOrder__r.Collect_Amount__c, SalesOrder__r.Unit__r.Name,ServiceRequest__c.Sales_Order_Installment__c,
                   SalesOrder__r.CustomerAccount__r.Name, SalesOrder__r.Unit__r.Phase__r.Name
            FROM ServiceRequest__c
            WHERE Id = :srId
        ];

        installments = [
            SELECT Name, MilestoneDate__c, InstallmentAmount__c
            FROM SalesOrderInstallments__c
            WHERE Id = :serviceRequest.Sales_Order_Installment__c 
        ];

        approvalSteps = [
            SELECT Actor.Name, Actor.Title, StepStatus, CreatedDate
            FROM ProcessInstanceStep
            WHERE ProcessInstance.TargetObjectId = :srId
            ORDER BY CreatedDate ASC
        ];

        ProcessInstanceStep latestApprovedStep = null;
        for(ProcessInstanceStep step : approvalSteps){
            if(step.StepStatus == 'Approved'){
                latestApprovedStep = step;
            }
        }
        latestApproverName = latestApprovedStep != null ? latestApprovedStep.Actor.Name : 'Approver';
    }
}