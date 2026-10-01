/**********************************************************************************************************************
* Name               : OIC_ManageEbsDataControllerTest
* Description        : Controller for is used for Un Applied Allocation and Unidentified Receipt
* Created By         : Active Minds
* --------------------------------------------------------------------------------------------------------------------
* Version       Author              Date                Comment
* 1.0           Manoj            22 Jan 2026          Initial Draft

***********************************************************************************************************************/
@isTest
public class OIC_ManageEbsDataControllerTest {
    @TestSetup static void setupData() {
        // Bypass EBS/Fusion sync side effects (SalesOrderTriggerHandler / ReceiptTriggerHelper
        // enqueue salesorderQueuableService, which chains into InvoiceQueueable). Chained
        // Queueable jobs exceed the test-context stack depth limit, throwing
        // System.AsyncException: Maximum stack depth has been reached. These flags only
        // control whether the sync is kicked off, not the data being set up here.
        TriggerControl.bypassTransferTrigger = true;
        TriggerControl.BypassCancelledTrigger = true;
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
        list<Receipt__c> inserRec =new list<Receipt__c>();
        //Create a new receipt 
        Receipt__c receiptObj = new Receipt__c();
        receiptObj.TotalAmount__c = 500;
        receiptObj.Account__c = accountObj.Id;
        receiptObj.SalesOrderInstallment__c=soInstallmentObj.Id;
        receiptObj.SalesOrder__c= salesOrderObj.Id;
        receiptObj.TransactionDate__c =system.now(); 
        receiptObj.Receipt_Approved_Date__c=system.now();
        receiptObj.OraclePartyId__c ='34324';
        inserRec.add(receiptObj);
        
        //Create a new receipt for charges
        Receipt__c receiptObj1 = new Receipt__c();
        receiptObj1.TotalAmount__c = 500;
        receiptObj1.Account__c = accountObj.Id;
        receiptObj1.SalesOrder__c= salesOrderObj.Id;
        receiptObj1.TransactionDate__c =system.now();
        receiptObj1.Receipt_Approved_Date__c=system.now();
        receiptObj1.OraclePartyId__c ='36364';
        inserRec.add(receiptObj1);
        
        insert inserRec;	
        
        Allocation__c allocationObj = new Allocation__c();
        allocationObj.Invoice__c = listInv[0].Id;
        allocationObj.AllocationAmount__c = 500;
        allocationObj.Status__c = 'Applied';
        allocationObj.Receipt__c = inserRec[0].Id;
        
        INSERT allocationObj;
        
    }
    private class RestMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            OIC_RequestWrapperController.OICResponseWrapperList responseWrapperList = new OIC_RequestWrapperController.OICResponseWrapperList();
            OIC_RequestWrapperController.OICResponseWrapper responseWrapper = new OIC_RequestWrapperController.OICResponseWrapper();
            Allocation__c rec = [Select Id From Allocation__c LIMIT 1];
            responseWrapper.Sfid = rec.Id;
            responseWrapper.Status = 'S';
            responseWrapper.ErrorMsg = 'Success';
            responseWrapper.OracleId = 'Test123';            
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
            Allocation__c rec = [Select Id From Allocation__c LIMIT 1];
            responseWrapper.Sfid = rec.Id;
            responseWrapper.Status = 'E';
            responseWrapper.ErrorMsg = 'An unexpected error occurred while processing your request. Please contact support.';
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
    
    private class RestMockReceipt implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            OIC_RequestWrapperController.OICResponseWrapperList responseWrapperList = new OIC_RequestWrapperController.OICResponseWrapperList();
            OIC_RequestWrapperController.OICResponseWrapper responseWrapper = new OIC_RequestWrapperController.OICResponseWrapper();
            Receipt__c rec = [Select Id,Receipt_Approved_Date__c From Receipt__c LIMIT 1];
            responseWrapper.Sfid = rec.Id;
            responseWrapper.Status = 'S';
            responseWrapper.ErrorMsg = 'Success';
            responseWrapper.OracleId = 'Test123';            
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
    private class ResterrorMockReceipt implements HttpCalloutMock {
        
        public HTTPResponse respond(HTTPRequest req) {
            OIC_RequestWrapperController.OICResponseWrapperList responseWrapperList = new OIC_RequestWrapperController.OICResponseWrapperList();
            OIC_RequestWrapperController.OICResponseWrapper responseWrapper = new OIC_RequestWrapperController.OICResponseWrapper();
            Receipt__c rec = [Select Id,Receipt_Approved_Date__c From Receipt__c LIMIT 1];
            responseWrapper.Sfid = rec.Id;
            responseWrapper.Status = 'E';
            responseWrapper.ErrorMsg = 'An unexpected error occurred while processing your request. Please contact support.';
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
    public static void createAlloaction(){
        // See setupData() note: bypass EBS/Fusion sync Queueable chain during this test's DML too.
        TriggerControl.bypassTransferTrigger = true;
        TriggerControl.BypassCancelledTrigger = true;

        Set<String> allocationIdSet = new Set<String>();
        Test.startTest();
        //Create a new allocation related to the invoice so it is fully paid
        // Get Allocation
        Allocation__c alloc = [SELECT Id FROM Allocation__c LIMIT 1];
        
        Set<String> allIds = new Set<String>(); 
        allIds.add(alloc.id);
        Test.setMock(HttpCalloutMock.class, new RestMock());
        OIC_ManageEbsDataController.createUnAppliedAllocation(allIds);
        
        Test.setMock(HttpCalloutMock.class, new ResterrorMock());
        OIC_ManageEbsDataController.createUnAppliedAllocation(allIds);
        Test.stopTest();
    }
    @isTest
    public static void testCreateUnidentifiedReceipt() {
        // See setupData() note: bypass EBS/Fusion sync Queueable chain during this test's DML too.
        TriggerControl.bypassTransferTrigger = true;
        TriggerControl.BypassCancelledTrigger = true;

        // Get existing data from @TestSetup
        Receipt__c rec = [SELECT Id, SalesOrder__c FROM Receipt__c LIMIT 1];
        
        Set<String> receiptIds = new Set<String>();
        receiptIds.add(rec.Id);
        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new RestMockReceipt());
        OIC_ManageEbsDataController.createUnidentifiedReceipt(receiptIds);
        
        Test.setMock(HttpCalloutMock.class, new ResterrorMockReceipt());
        OIC_ManageEbsDataController.createUnidentifiedReceipt(receiptIds);
        Test.stopTest();
    }    
    
}