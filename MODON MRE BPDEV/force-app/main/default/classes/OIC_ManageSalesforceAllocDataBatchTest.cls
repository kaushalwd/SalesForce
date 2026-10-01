/**********************************************************************************************************************
* Name               : OIC_ManageSalesforceAllocDataBatchTest
* Description        : Test Class for OIC_ManageSalesforceAllocationDataBatch
* Created By         : PWC Digital Middle East
* --------------------------------------------------------------------------------------------------------------------
* Version       Author              Date                Comment
* 1.0           Yazan Saeed         01 May 2024      Initial Draft
***********************************************************************************************************************/
@isTest
public with sharing class OIC_ManageSalesforceAllocDataBatchTest {
    @testSetup
    public static void makeData(){
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
        invoiceObj1.OraclePartyId__c = '34214';
        listInv.add(invoiceObj1);
        
        insert listInv;
        
       
    }
    
    private class RestMock implements HttpCalloutMock {

        public HTTPResponse respond(HTTPRequest req) {
            String fullJson = '{"Status":"Draft","Id":"a03Dw00000ByjeGIAR"}';

            HTTPResponse res = new HTTPResponse();
            res.setHeader('Content-Type', 'text/json');
            res.setBody(fullJson);
            res.setStatusCode(200);
            return res;
        }
    }
    
    @isTest
    public static void testMethod1() {
         Test.startTest();
        TriggerControl.BypassAccountTrigger =true;
        TriggerControl.BypassCancelledTrigger =true;
        Invoice__c inv =[select id,SalesOrderInstallment__c,SalesOrderInstallment__r.SalesOrder__c,SalesOrderInstallment__r.SalesOrder__r.CustomerAccount__c from Invoice__c limit 1];
        
        Receipt__c recObj = new Receipt__c();
        recObj.Account__c = inv.SalesOrderInstallment__r.SalesOrder__r.CustomerAccount__c;
        recObj.SalesOrderInstallment__c = inv.SalesOrderInstallment__c;
        recObj.OICIntegrationStatus__c = 'S';
        insert recObj;
	
        
         Allocation__c allocation = new Allocation__c();
        allocation.Receipt__c = recObj.Id;
        allocation.Invoice__c = inv.Id;
        INSERT allocation;
        
        recObj.OraclePartyId__c ='432112';
        recObj.Status__c = 'Cleared';
        recObj.EBS_Clearing_Date__c = system.today();
        recObj.TransactionDate__c = System.today().addDays(-2);
		UPDATE recObj;
        
            Test.setMock(HttpCalloutMock.class, new RestMock());
            OIC_ManageSalesforceAllocationDataBatch batchTest= new OIC_ManageSalesforceAllocationDataBatch();
            Id jobid= Database.executeBatch(batchTest, 1);
        TriggerControl.BypassAccountTrigger =false;
        TriggerControl.BypassCancelledTrigger =false;
        Test.stopTest();
    }
}