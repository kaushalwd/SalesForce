/**********************************************************************************************************************
* Name               : OIC_ManageReceiptReversal
* Description        : Controller for is used for  Receipt Reversal from payemnt record
* Created By         : Active Minds
* --------------------------------------------------------------------------------------------------------------------
* Version       Author              Date                Comment
* 1.0           Manoj            22 Jan 2026          Initial Draft

***********************************************************************************************************************/
@isTest
public class OIC_ManageReceiptReversalTest {
    
    @TestSetup static void setupData() {
        //Create an account
        Schema.RecordTypeInfo recordTypeInfo = Schema.getGlobalDescribe().get('Account').getDescribe().getRecordTypeInfosByDeveloperName().get('PersonAccount');
        String recordTypeId = recordTypeInfo.getRecordTypeId();
        Account accountObj = new Account(RecordTypeId = recordTypeId);
        accountObj.PersonEmail = 'abdallahhdaib@outlook.com';
        accountObj.FirstName = 'First';
        accountObj.LastName = 'Last';
        accountObj.OraclePartyId__c ='22212';
        insert accountObj;
        
        //Create a new Unit
        Unit__c unitObj = new Unit__c();
        unitObj.Name = 'Test Unit';
        unitObj.BasePrice__c = 1000;
        unitObj.AdditionalPrice__c = 0;
        unitObj.PlotAreasqm__c = 1.0;
        unitObj.PlotNo__c = '1';
        unitObj.UnitClassification__c = 'Villa';
        unitObj.Number_of_Bedrooms__c = '2'; 
        INSERT unitObj;
        
        //Create a new sales order with a populated status
        SalesOrder__c salesOrderObj = new SalesOrder__c();
        salesOrderObj.Status__c = 'In Progress';
        salesOrderObj.Unit__c = unitObj.Id;
        SalesOrderObj.CustomerAccount__c = accountObj.Id;
        salesOrderObj.TotalAmount__c = 20000;
        salesOrderObj.OraclePartySiteID__c='33333';
        salesOrderObj.OracleCustAcctSiteID__c='765456';
        salesOrderObj.Source_Entity__c ='Modon - UAE';
        INSERT salesOrderObj;
        
        //Create a new sales order with no populated status
        SalesOrder__c salesOrderNoStatus = new SalesOrder__c();
        salesOrderNoStatus.Status__c = '';
        
        INSERT salesOrderNoStatus;
        
        //Create a new Sales Order Installment with milestone of 1
        SalesOrderInstallments__c soInstallmentObj = new SalesOrderInstallments__c();
        soInstallmentObj.SalesOrder__c = salesOrderObj.Id;
        soInstallmentObj.Milestone__c = 1;
        soInstallmentObj.MilestoneNumber__c = 1;
        INSERT soInstallmentObj;
        list<Invoice__c> listInv= new list<Invoice__c>();
        //Create a new invoice related to soInstallmentObj
        Invoice__c invoiceObj = new Invoice__c();
        invoiceObj.SalesOrderInstallment__c = soInstallmentObj.Id;
        invoiceObj.InvoiceAmount__c = 1000;
        invoiceObj.Account__c = accountObj.Id;   
        invoiceObj.Ebs_Invoice_Date__c =system.today();
        listInv.add(invoiceObj);
        
        //Create a new invoice related to soInstallmentObj
        Invoice__c invoiceAdmObj = new Invoice__c();         
        invoiceAdmObj.InvoiceAmount__c = 1000;
        invoiceAdmObj.Account__c = accountObj.Id;  
        invoiceAdmObj.Is_ADM_Fees_and_Dari_charges__c =true;
        invoiceAdmObj.Sales_Order__c =salesOrderObj.id;
        invoiceAdmObj.Ebs_Invoice_Date__c =system.today();
        listInv.add(invoiceAdmObj);
        
        
        //Create a new invoice related to charges
        Invoice__c invoiceObj1 = new Invoice__c();
        invoiceObj1.Sales_Order__c = salesOrderObj.Id;
        invoiceObj1.InvoiceAmount__c = 1000;
        invoiceObj1.Account__c = accountObj.Id;         
        listInv.add(invoiceObj1);
        
        insert listInv;
       	 
        
    }
    private class RestMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            OIC_RequestWrapperController.OICResponseWrapperList responseWrapperList = new OIC_RequestWrapperController.OICResponseWrapperList();
            OIC_RequestWrapperController.OICResponseWrapper responseWrapper = new OIC_RequestWrapperController.OICResponseWrapper();
            Receipt__c rec = [Select Id From Receipt__c LIMIT 1];
            responseWrapper.Sfid = rec.Id;
            responseWrapper.Status = 'Reversed';
            responseWrapper.ErrorMsg = '';
            responseWrapper.OracleId = 'Test123';
            responseWrapper.ReversalReason = 'Insufficient Funds';
            responseWrapperList.ResponseArray = new List<OIC_RequestWrapperController.OICResponseWrapper>{responseWrapper};
                
                String jsonResponse = JSON.serialize(responseWrapperList);
            Blob jsonBlob = Blob.valueOf(jsonResponse);
            String base64EncodedResponse = EncodingUtil.base64Encode(jsonBlob);
            
            OIC_RequestWrapperController.Base64ResponseWrapper base64RespWrap = new OIC_RequestWrapperController.Base64ResponseWrapper();
            base64RespWrap.Base64Response = base64EncodedResponse;
            
            HTTPResponse res = new HTTPResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody(JSON.serialize(base64RespWrap));
            res.setStatusCode(200);
            
            return res;
        }
        
    }
    private class ResterrorMock implements HttpCalloutMock {
        
        public HTTPResponse respond(HTTPRequest req) {
            OIC_RequestWrapperController.OICResponseWrapperList responseWrapperList = new OIC_RequestWrapperController.OICResponseWrapperList();
            OIC_RequestWrapperController.OICResponseWrapper responseWrapper = new OIC_RequestWrapperController.OICResponseWrapper();
            Receipt__c rec = [Select Id From Receipt__c LIMIT 1];
            responseWrapper.Sfid = rec.Id;
            responseWrapper.Status = 'E';
            responseWrapper.ErrorMsg = 'An unexpected error';
            responseWrapperList.ResponseArray = new List<OIC_RequestWrapperController.OICResponseWrapper>{responseWrapper};
                
                String jsonResponse = JSON.serialize(responseWrapperList);
            Blob jsonBlob = Blob.valueOf(jsonResponse);
            String base64EncodedResponse = EncodingUtil.base64Encode(jsonBlob);
            
            OIC_RequestWrapperController.Base64ResponseWrapper base64RespWrap = new OIC_RequestWrapperController.Base64ResponseWrapper();
            base64RespWrap.Base64Response = base64EncodedResponse;
            
            HTTPResponse res = new HTTPResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody(JSON.serialize(base64RespWrap));
            res.setStatusCode(200);
            
            return res;
        }
    }
    @isTest
    public static void createReceiptError(){
          Test.startTest();
        //Receipt__c receiptObj = [SELECT Id,TransactionDate__c FROM Receipt__c where OraclePartyId__c != null and SalesOrderInstallment__c != null limit 1];
        Invoice__c inv =[select id,SalesOrderInstallment__c,SalesOrderInstallment__r.SalesOrder__c,SalesOrderInstallment__r.SalesOrder__r.CustomerAccount__c from Invoice__c limit 1];
        list<Receipt__c> inserRec =new list<Receipt__c>();
        //Create a new receipt 
        Receipt__c receiptObj = new Receipt__c();
        receiptObj.TotalAmount__c = 1000;
        receiptObj.Account__c = inv.SalesOrderInstallment__r.SalesOrder__r.CustomerAccount__c;
        receiptObj.SalesOrderInstallment__c=inv.SalesOrderInstallment__c;
        receiptObj.SalesOrder__c= inv.SalesOrderInstallment__r.SalesOrder__c;
        receiptObj.TransactionDate__c =system.now(); 
        receiptObj.OraclePartyId__c ='34324';
        inserRec.add(receiptObj);   
        TriggerControl.BypassCancelledTrigger =true;

        insert inserRec;	
        // Create input wrapper
        OIC_ManageReceiptReversal.InputWrapper input =  new OIC_ManageReceiptReversal.InputWrapper();
        
        input.value1 = receiptObj.Id;
        input.value2 = 'Insufficient Funds';
        List<OIC_ManageReceiptReversal.InputWrapper> inputs =  new List<OIC_ManageReceiptReversal.InputWrapper>{ input };
            
            
          
        try{
        Test.setMock(HttpCalloutMock.class, new RestMock());
        TriggerControl.BypassAccountTrigger =true;
        TriggerControl.BypassCancelledTrigger =true;
        OIC_ManageReceiptReversal.processValues(inputs); 
        TriggerControl.BypassAccountTrigger =False;
        TriggerControl.BypassCancelledTrigger =False;
        }catch(Exception ex){    
            
        }
        Test.stopTest();
    }
    @isTest
    public static void createReceiptTest(){
          Test.startTest();
        Invoice__c inv =[select id,SalesOrderInstallment__c,SalesOrderInstallment__r.SalesOrder__c,SalesOrderInstallment__r.SalesOrder__r.CustomerAccount__c from Invoice__c limit 1];
        list<Receipt__c> inserRec =new list<Receipt__c>();
        //Create a new receipt 
        Receipt__c receiptObj = new Receipt__c();
        receiptObj.TotalAmount__c = 1000;
        receiptObj.Account__c = inv.SalesOrderInstallment__r.SalesOrder__r.CustomerAccount__c;
        receiptObj.SalesOrderInstallment__c=inv.SalesOrderInstallment__c;
        receiptObj.SalesOrder__c= inv.SalesOrderInstallment__r.SalesOrder__c;
        receiptObj.TransactionDate__c =system.now(); 
        receiptObj.OraclePartyId__c ='34324';
        inserRec.add(receiptObj); 
        TriggerControl.BypassCancelledTrigger =true;

        insert inserRec;	
        // Create input wrapper
        OIC_ManageReceiptReversal.InputWrapper input =  new OIC_ManageReceiptReversal.InputWrapper();
        
        input.value1 = receiptObj.Id;
        input.value2 = 'Insufficient Funds';
        List<OIC_ManageReceiptReversal.InputWrapper> inputs =  new List<OIC_ManageReceiptReversal.InputWrapper>{ input };
            
            
        
        try{
        Test.setMock(HttpCalloutMock.class, new ResterrorMock());
            TriggerControl.BypassAccountTrigger =true;
        TriggerControl.BypassCancelledTrigger =true;
        OIC_ManageReceiptReversal.processValues(inputs);  
            TriggerControl.BypassAccountTrigger =false;
        TriggerControl.BypassCancelledTrigger =false;
        }catch(Exception ex){    
            
        }
        Test.stopTest();
    }
    @isTest
    public static void createReceiptTest1(){
          Test.startTest();
        account accid =[select id from account limit 1];
        SalesOrder__c soRec = [select id from SalesOrder__c limit 1];
         //Create a new receipt for charges
        Receipt__c receiptObj1 = new Receipt__c();
        receiptObj1.TotalAmount__c = 1000;
        receiptObj1.Account__c = accid.id;
        receiptObj1.Is_ADM_Fees_and_Dari_charges__c =true;
        //receiptObj.SalesOrderInstallment__c=soInstallmentObj.Id;
        receiptObj1.SalesOrder__c= soRec.id;
        receiptObj1.OraclePartyId__c ='34328';
        receiptObj1.TransactionDate__c =system.now();
        TriggerControl.BypassCancelledTrigger =true;

       insert receiptObj1;
        
        // Create input wrapper
        OIC_ManageReceiptReversal.InputWrapper input =  new OIC_ManageReceiptReversal.InputWrapper();
        
        input.value1 = receiptObj1.Id;
        input.value2 = 'Insufficient Funds';
        List<OIC_ManageReceiptReversal.InputWrapper> inputs =  new List<OIC_ManageReceiptReversal.InputWrapper>{ input };
                    
       
        try{
        Test.setMock(HttpCalloutMock.class, new ResterrorMock());
            TriggerControl.BypassAccountTrigger =true;
        TriggerControl.BypassCancelledTrigger =true;
        OIC_ManageReceiptReversal.processValues(inputs);   
            TriggerControl.BypassAccountTrigger =false;
        TriggerControl.BypassCancelledTrigger =false;
        }catch(Exception ex){    
            
        }
        Test.stopTest();
    }
}