@isTest
public class PushToebsAccountTest {
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
 		 EscrowAccount__c escAccount = new EscrowAccount__c(name='Phase 1 Escrow Account',
                                                            AccountNumber__c='124567642',IBANNo__c='AE3456789456789',StoreId__c='weqqw',
                                                           SwiftCode__c='23333',TradeID__c='Test account',BankName__c='Test account',BeneficiaryName__c='Test account');
        insert escAccount;
        
        VirtualAccount__c vaObj = new VirtualAccount__c();
        vaObj.Name = 'Test account';
        vaObj.Status__c = 'Available';
        vaObj.EscrowAccount__c = escAccount.Id;
        vaObj.VirtualAccountNumber__c = '124567642';
        vaObj.VirtualIBANNumber__c = 'AE3456789456789';
        vaObj.Unit__c=unitObj.id;
        INSERT vaObj;
         //Create a new sales order with a populated status
         SalesOrder__c salesOrderObj = new SalesOrder__c();
         salesOrderObj.Status__c = 'In Progress';
         salesOrderObj.Unit__c = unitObj.Id;
         SalesOrderObj.CustomerAccount__c = accountObj.Id;
         salesOrderObj.TotalAmount__c = 20000;
         salesOrderObj.OraclePartySiteID__c='33333';
         salesOrderObj.OracleCustAcctSiteID__c='765456';
         salesOrderObj.Source_Entity__c ='Modon - UAE';
         salesOrderObj.VirtualAccount__c =vaObj.id;
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
 		list<Invoice__c> listInset =new list<Invoice__c>();
         //Create a new invoice related to soInstallmentObj
         Invoice__c invoiceObj = new Invoice__c();
         invoiceObj.SalesOrderInstallment__c = soInstallmentObj.Id;
         invoiceObj.InvoiceAmount__c = 1000;
         invoiceObj.Account__c = accountObj.Id;   
         invoiceObj.Ebs_Invoice_Date__c =system.today();
         listInset.add(invoiceObj);
        
         //Create a new invoice related to soInstallmentObj
         Invoice__c invoiceAdmObj = new Invoice__c();         
         invoiceAdmObj.InvoiceAmount__c = 1000;
         invoiceAdmObj.Account__c = accountObj.Id;  
         invoiceAdmObj.Is_ADM_Fees_and_Dari_charges__c =true;
         invoiceAdmObj.Sales_Order__c =salesOrderObj.id;
         invoiceAdmObj.Ebs_Invoice_Date__c =system.today();
          listInset.add(invoiceAdmObj);


         //Create a new invoice related to charges
         Invoice__c invoiceObj1 = new Invoice__c();
         invoiceObj1.Sales_Order__c = salesOrderObj.Id;
         invoiceObj1.InvoiceAmount__c = 1000;
         invoiceObj1.Account__c = accountObj.Id;         
          listInset.add(invoiceObj1);    
 		insert listInset;
        List<Receipt__c> RecInst =new list<Receipt__c>();
         //Create a new receipt 
         Receipt__c receiptObj = new Receipt__c();
         receiptObj.TotalAmount__c = 1000;
         receiptObj.Account__c = accountObj.Id;
         receiptObj.SalesOrderInstallment__c=soInstallmentObj.Id;
         receiptObj.SalesOrder__c= salesOrderObj.Id;
         receiptObj.Modeofpayment__c ='Credit Note';
         receiptObj.TransactionDate__c =system.now();
        
         RecInst.add(receiptObj);

         //Create a new receipt for charges
         Receipt__c receiptObj1 = new Receipt__c();
         receiptObj1.TotalAmount__c = 1000;
         receiptObj1.Account__c = accountObj.Id;
         //receiptObj.SalesOrderInstallment__c=soInstallmentObj.Id;
         receiptObj1.SalesOrder__c= salesOrderObj.Id;
         receiptObj1.Modeofpayment__c ='Credit Note';
         receiptObj1.TransactionDate__c =system.now();
         
         RecInst.add(receiptObj1);
		 
        insert RecInst;
    }
 
    private class RestMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            OIC_RequestWrapperController.OICResponseWrapperList responseWrapperList = new OIC_RequestWrapperController.OICResponseWrapperList();
            OIC_RequestWrapperController.OICResponseWrapper responseWrapper = new OIC_RequestWrapperController.OICResponseWrapper();
            Receipt__c rec = [Select Id From Receipt__c LIMIT 1];
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


    @isTest
    public static void createAccountTest(){

        Set<String> personAccountIdSet = new Set<String>();
        List<String> personAccountIdSet1 = new List<String>();
        account acc=new account();
        for(Account accObj : [SELECT Id,LastName,FirstName FROM Account]){
            personAccountIdSet.add(accObj.Id);
            acc.id=accObj.id;
            acc.LastName =accObj.LastName;
            acc.FirstName=accObj.FirstName;
        }
        Test.startTest();
        	TriggerControl.bypassTransferTrigger = true;
        	TriggerControl.BypassAccountTrigger = true;
        	PushToebsAccount.accountCalloutInvokeFromFlowDetailsPageAction(personAccountIdSet1);
            Test.setMock(HttpCalloutMock.class, new RestMock());
            OIC_ManageSalesforceDataController.createAccount(personAccountIdSet);
        	OIC_ManageSalesforceDataController.createOrganizationWrapper(acc);
        Test.stopTest();
    }

    @isTest
    public static void createReceiptTest(){
        Set<String> receiptIdSet = new Set<String>();
        List<String> receiptIdSet1 = new List<String>();
        for(Receipt__c receiptObj : [SELECT Id,TransactionDate__c FROM Receipt__c]){
            receiptIdSet.add(receiptObj.Id);            
        }
        Test.startTest();
        	TriggerControl.bypassTransferTrigger = true;
        	TriggerControl.BypassAccountTrigger = true;
        	PushToebsReceipt.receiptCalloutInvokeFromFlowDetailsPageAction(receiptIdSet1);
            Test.setMock(HttpCalloutMock.class, new RestMock());
            OIC_ManageSalesforceDataController.createReceipt(receiptIdSet);
             
            //OIC_ManageSalesforceDataController.createReceipt(null);
        Test.stopTest();
    }
    
    @isTest
    public static void createSalesOrderAndSOInstallmentsTest(){

        Set<String> salesOrderIdSet = new Set<String>();
        List<String> salesOrderIdSet1 = new List<String>();
        for(SalesOrder__c salesOrderObj : [SELECT Id FROM SalesOrder__c]){
            salesOrderIdSet.add(salesOrderObj.Id);
        }        
        Test.startTest();
        	TriggerControl.bypassTransferTrigger = true;
        	TriggerControl.BypassAccountTrigger = true;
        	PushToebsSO.soCalloutInvokeFromFlowDetailsPageAction(salesOrderIdSet1);
            Test.setMock(HttpCalloutMock.class, new RestMock());
            OIC_ManageSalesforceDataController.createSalesOrderAndSOInstallments(salesOrderIdSet);
        Test.stopTest();
    }
    
    @isTest
    public static void createInstallmentTest(){
		List<String> invoiceIdSet1 = new List<String>();
        Set<String> invoiceIdSet = new Set<String>();
        for(Invoice__c invoiceObj : [SELECT Id FROM Invoice__c]){
            invoiceIdSet.add(invoiceObj.Id);
        }
        
        Test.startTest();
        	TriggerControl.bypassTransferTrigger = true;
        	TriggerControl.BypassAccountTrigger = true;
        	PushToebsInvoice.invoiceCalloutInvokeFromFlowDetailsPageAction(invoiceIdSet1);
            Test.setMock(HttpCalloutMock.class, new RestMock());
            OIC_ManageSalesforceDataController.createInstallment(invoiceIdSet);
        	OIC_ManageSalesforceDataController.createInstallment(null);
        Test.stopTest();
    }

    @isTest
    public static void createAllocationTest(){
		List<String> allocationIdSet1 = new List<String>();
        Set<String> allocationIdSet = new Set<String>();
        for(Allocation__c allocationObj : [SELECT Id FROM Allocation__c]){
            allocationIdSet.add(allocationObj.Id);
        }
        
        Test.startTest();
        TriggerControl.bypassTransferTrigger = true;
        TriggerControl.BypassAccountTrigger = true;
        PushToebsAllocation.allocationCalloutInvokeFromFlowDetailsPageAction(allocationIdSet1);
            Test.setMock(HttpCalloutMock.class, new RestMock());
            OIC_ManageSalesforceDataController.createAllocation(allocationIdSet);
            OIC_ManageSalesforceDataController.createAllocation(null);
        Test.stopTest();
    }
    
    
}