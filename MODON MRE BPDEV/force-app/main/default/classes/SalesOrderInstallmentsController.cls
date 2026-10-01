public class SalesOrderInstallmentsController {
    private Id internalSalesOrderId;
    public string salesOrderId {get;set;}
    

    public List<SalesOrderInstallments__c> getInstallments() {
        return [SELECT MilestoneNumber__c,MilestoneDescription__c,Milestone__c,MilestoneDate__c,InstallmentAmount__c
                FROM SalesOrderInstallments__c 
                WHERE SalesOrder__c = :salesOrderId Order By MilestoneNumber__c ASC];
    }
}