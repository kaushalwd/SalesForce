public without sharing class ReceiptService { 
    
    public static  Map<Id, Receipt__c> getClearedReceiptsBySalesOrder(Set<Id> salesOrderIds){

       Map<Id, Receipt__c> receiptMap = new Map<Id, Receipt__c>();
       receiptMap = new Map<Id, Receipt__c>([SELECT Id, Name, TotalAmount__c, ReceiptDate__c,Account__c,
            Modeofpayment__c,RemainingAmount__c,Allocation_Amount_on_Transfer__c ,
             Status__c, TransactionNumber__c,
            TransactionDate__c,SalesOrder__c,
            OraclePartyId__c,OICIntegrationStatus__c
            FROM Receipt__c WHERE 
            SalesOrder__c IN :salesOrderIds
            AND Status__c = 'Cleared'
            ORDER BY CreatedDate
        ]);
        return receiptMap;
    }
    
    public static  List<Receipt__c> getClearedAndConfirmedReceiptsBySalesOrderIds(Set<Id> salesOrderIds){
    List<Receipt__c> receiptList = [SELECT Id, Name, TotalAmount__c, ReceiptDate__c,Account__c,
            Modeofpayment__c,RemainingAmount__c,Allocation_Amount_on_Transfer__c ,
             Status__c, TransactionNumber__c,
            TransactionDate__c,SalesOrder__c,
            OraclePartyId__c,OICIntegrationStatus__c 
            FROM Receipt__c
            WHERE SalesOrder__c IN :salesOrderIds
                                          AND (Status__c = 'Cleared' OR
                                          Status__c = 'Approved')
                                          ORDER BY CreatedDate];
    return receiptList;
}

    public static Receipt__c createLogicalReceipt(string transactionTypeId, string salesOrderId,
        Decimal amount, string accountId,
        String PaymentPurpose
    ){
      
        Receipt__c receipt = new Receipt__c();
        receipt.TotalAmount__c = amount;
        receipt.Account__c = accountId; 
        receipt.Modeofpayment__c =PaymentPurpose;//Constants.RECEIPT_PAYMENT_TYPE_EQUITY_TRANSFER;
        receipt.Status__c= 'Cleared';
        receipt.SalesOrder__c = salesOrderId;
        receipt.TransactionDate__c= System.today(); 
        receipt.OICIntegrationStatus__c = Constants.SUCCESS_STATUS;
        receipt.ReceiptDate__c = System.today();
        return receipt;
    }
}