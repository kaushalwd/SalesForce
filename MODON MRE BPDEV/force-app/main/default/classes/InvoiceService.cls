public without sharing class InvoiceService{
    
     public static List<Invoice__c> getDebitMemoInvoiceBySalesOrderID(Id SalesOrderId){
        
        
        
        List<Invoice__c> invoice = [SELECT Id, InvoiceAmount__c,AppliedAmount__c,OICIntegrationStatus__c,Sales_Order__c,
                                    OracleSyncStatus__c
                                    FROM Invoice__c
                                    WHERE RecordTypeId =:InvoiceService.recordTypeIdByDevName(Invoice__c.SobjectType, 'Debit_Memo') 
                                    AND Sales_Order__c= :SalesOrderId];
        System.debug('>>>>>>invoice>>>>'+invoice);
        return invoice;
    }
    
    public static Id recordTypeIdByDevName(String objectName, String recTypeDevName){
        Schema.SObjectType sObjType = Schema.getGlobalDescribe().get(objectName);
        return recordTypeIdByDevName(sObjType,recTypeDevName);
    }
    
    public static Id recordTypeIdByDevName(Schema.SObjectType sObjType, string recTypeDevName){
        Id recTypeId;
        if(sObjType != NULL && String.isNotBlank(recTypeDevName)){
            recTypeId = sObjType.getDescribe().getRecordTypeInfosByDeveloperName().get(recTypeDevName).getRecordTypeId();
        }
        return recTypeId;  
    }
    
     public static Invoice__c createDebitNote(string transactionTypeId, string accountId, string salesOrderId, Decimal amount){
        
        //create debit memo
        Invoice__c debitMemo = new Invoice__c();
        debitMemo.RecordTypeId = InvoiceService.recordTypeIdByDevName(Invoice__c.SobjectType,'Debit_Memo');
        debitMemo.Sales_Order__c= salesOrderId;
        debitMemo.InvoiceAmount__c = amount;
        debitMemo.Account__c = accountId;
        debitMemo.InvoiceDate__c=  Date.today();
        debitMemo.OICIntegrationStatus__c= 'S';
        return debitMemo;
    }
}