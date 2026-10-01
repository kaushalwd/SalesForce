/**********************************************************************************************************************
* Name               : OIC_ManageSalesforceDataControllerTestV1
* Description        : Test Class for desc component OIC_ManageSalesforceDataController 
* Created By         : Active Minds
* --------------------------------------------------------------------------------------------------------------------
* Version       Author              Date                Comment
* 1.0           Manoj         21 OCT 2025     Initial Draft
***********************************************************************************************************************/
@isTest
public class OIC_ManageSalesforceDataControllerTestV1 {
    
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
 
         //Create a new SPA document with status as Uploaded 
         /*Documents__c documentObj = new Documents__c();
         documentObj.Name = 'SPA';
         documentObj.SalesOrder__c = salesOrderObj.Id;
         documentObj.Status__c = 'Uploaded';
         INSERT documentObj;*/
         
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
         receiptObj.TotalAmount__c = 1000;
         receiptObj.Account__c = accountObj.Id;
         receiptObj.SalesOrderInstallment__c=soInstallmentObj.Id;
         receiptObj.SalesOrder__c= salesOrderObj.Id;
         receiptObj.TransactionDate__c =system.now();        
         inserRec.add(receiptObj);

         //Create a new receipt for charges
         Receipt__c receiptObj1 = new Receipt__c();
         receiptObj1.TotalAmount__c = 1000;
         receiptObj1.Account__c = accountObj.Id;
         //receiptObj.SalesOrderInstallment__c=soInstallmentObj.Id;
         receiptObj1.SalesOrder__c= salesOrderObj.Id;
         receiptObj1.TransactionDate__c =system.now();
        
         inserRec.add(receiptObj1);
        
         insert inserRec;		 
         
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
        account acc=new account();
        for(Account accObj : [SELECT Id,LastName,FirstName FROM Account]){
            personAccountIdSet.add(accObj.Id);
            acc.id=accObj.id;
            acc.LastName =accObj.LastName;
            acc.FirstName=accObj.FirstName;
        }
        Test.startTest();
            Test.setMock(HttpCalloutMock.class, new RestMock());
            OIC_ManageSalesforceDataController.createAccount(personAccountIdSet);
        	OIC_ManageSalesforceDataController.createOrganizationWrapper(acc);
        Test.stopTest();
    }

    @isTest
    public static void createReceiptTest(){

        Set<String> receiptIdSet = new Set<String>();
        for(Receipt__c receiptObj : [SELECT Id,TransactionDate__c FROM Receipt__c]){
            receiptIdSet.add(receiptObj.Id);
            
        }
        Set<String> allocationIdSet = new Set<String>();
        for(Allocation__c allocationObj : [SELECT Id FROM Allocation__c]){
            allocationIdSet.add(allocationObj.Id);
        }

        Test.startTest();
            Test.setMock(HttpCalloutMock.class, new RestMock());
            
            OIC_ManageSalesforceDataController.createReceipt(receiptIdSet);
             
            //OIC_ManageSalesforceDataController.createReceipt(null);
        Test.stopTest();
    }

    @isTest
    public static void createSalesOrderAndSOInstallmentsTest(){

        Set<String> salesOrderIdSet = new Set<String>();
        for(SalesOrder__c salesOrderObj : [SELECT Id FROM SalesOrder__c]){
            salesOrderIdSet.add(salesOrderObj.Id);
        }        
        Test.startTest();
            Test.setMock(HttpCalloutMock.class, new RestMock());
            OIC_ManageSalesforceDataController.createSalesOrderAndSOInstallments(salesOrderIdSet);
        Test.stopTest();
    }

    @isTest
    public static void createInstallmentTest(){
		SalesOrder__c So =[SELECT Id FROM SalesOrder__c limit 1];
        So.OracleCustAcctSiteID__c ='34314';
        so.OraclePartyId__c = '12334';   
        so.OraclePartySiteID__c ='32432';
        so.OracleSiteUseID__c ='45434';
        Test.startTest();
        update so;
         Set<String> invoiceIdSet = new Set<String>();
        for(Invoice__c invoiceObj : [SELECT Id FROM Invoice__c where Sales_Order__c =: so.id]){
            invoiceIdSet.add(invoiceObj.Id);
        }
            Test.setMock(HttpCalloutMock.class, new RestMock());
            OIC_ManageSalesforceDataController.createInstallment(invoiceIdSet);
        	OIC_ManageSalesforceDataController.createInstallment(null);
        Test.stopTest();
    }

    @isTest
    public static void createAllocationTest(){

        Set<String> allocationIdSet = new Set<String>();
        Invoice__c invoiceInv =[select id from Invoice__c limit 1];
        invoiceInv.OraclePartyId__c ='332343';
        Test.startTest();
        update invoiceInv;
        Receipt__c receiptRec = [select id from Receipt__c limit 1];
        receiptRec.OraclePartyId__c ='32545';
        
        update receiptRec;
        //Create a new allocation related to the invoice so it is fully paid
         Allocation__c allocationObj = new Allocation__c();
         allocationObj.Invoice__c = invoiceInv.Id;
         allocationObj.AllocationAmount__c = 1000;
         allocationObj.Status__c = 'Applied';
         allocationObj.Receipt__c = receiptRec.Id;
        
         INSERT allocationObj;
        
        
            Test.setMock(HttpCalloutMock.class, new RestMock());
            OIC_ManageSalesforceDataController.createAllocation(allocationIdSet);
            OIC_ManageSalesforceDataController.createAllocation(null);
        Test.stopTest();
    }

    @isTest
    public static void updateUnitStatusTest(){

        Set<String> unitIdSet = new Set<String>();
        for(Unit__c unitObj : [SELECT Id FROM Unit__c]){
            unitIdSet.add(unitObj.Id);
        }
        Test.setMock(HttpCalloutMock.class, new RestMock());
        Test.startTest();
        OIC_ManageSalesforceDataController.updateUnitStatus(unitIdSet);
        Test.stopTest();
    }
    @isTest
    public static void createInstallmentTest1(){

        Set<String> invoiceIdSet = new Set<String>();
        for(Invoice__c invoiceObj : [SELECT Id FROM Invoice__c where Sales_Order__c = null]){
            invoiceIdSet.add(invoiceObj.Id);
        }
        
        Test.startTest();
            Test.setMock(HttpCalloutMock.class, new RestMock());
            OIC_ManageSalesforceDataController.createInstallment(invoiceIdSet);
        	OIC_ManageSalesforceDataController.createInstallment(null);
        Test.stopTest();
    }
     public static void accountOrgTest(){

         Id OrgConRtId = [SELECT Id FROM RecordType WHERE SObjectType = 'Contact' AND DeveloperName = 'Individual' LIMIT 1].Id;

		 Id OrgAccRtId = [SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND DeveloperName = 'OrganizationAccount' LIMIT 1].Id;

       

          // Create Business Account (OrganizationAccount) and Contact

        Id businessRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('OrganizationAccount').getRecordTypeId();

        Account businessAcc = new Account(Name = 'Test Business', RecordTypeId = OrgAccRtId);

        insert businessAcc;

        

        Contact con = new Contact(

            LastName = 'Test Contact',

            AccountId = businessAcc.Id,

            Email = 'test@example.com',

            Is_Active__c = true,

            RecordTypeId =OrgConRtId

        );

        insert con;

         Set<String> orgAccountIdSet = new Set<String>();        

         orgAccountIdSet.add(businessAcc.Id);        

         OIC_ManageSalesforceDataController.createAccount(orgAccountIdSet);        

    }
}