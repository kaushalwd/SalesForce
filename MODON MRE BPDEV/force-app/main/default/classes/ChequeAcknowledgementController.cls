public with sharing class ChequeAcknowledgementController {
    public Id salesOrderId { get; set; }
    public User currentUser { get; set; }
    public SalesOrder__c salesOrder { get; set; }

    public ChequeAcknowledgementController() {
        salesOrderId = ApexPages.currentPage().getParameters().get('id');
        loadSalesOrderDetails();
        Id userId = UserInfo.getUserId();
        currentUser = [SELECT Id, Name, Email FROM User WHERE Id = :userId LIMIT 1];
    }

    private void loadSalesOrderDetails() {
        salesOrder = [
            SELECT Id, Name, ProjectName__c,
                   Unit__r.Name,
                   CustomerAccount__r.Name,
                   (SELECT Id, Milestone__c, SalesOrderInstallment__r.Milestone__c, Bank__c, 
                           TransactionNumber__c, ChequeDate__c, TotalAmount__c, AppliedAmount__c, BankName__c,
                           Charge__c, Cheque_Number__c, Milestone_Description__c, Modeofpayment__c, ProjectName__c,
                           ReceiptDate__c, TransactionID__c, TransactionDate__c
                           FROM Payments__r where Status__c NOT IN ('Cancelled', 'Rejected') 
                           ORDER BY ChequeDate__c ASC)
            FROM SalesOrder__c
            WHERE Id = :salesOrderId
            LIMIT 1
        ];
    }

    public SalesOrder__c getSalesOrder() {
        return salesOrder;
    }
}