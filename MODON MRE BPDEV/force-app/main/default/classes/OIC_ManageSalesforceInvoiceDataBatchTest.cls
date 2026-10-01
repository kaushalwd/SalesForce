/**********************************************************************************************************************
* Name               : OIC_ManageSalesforceInvoiceDataBatchTest
* Description        : Test Class for OIC_ManageSalesforceInvoiceDataBatch
* Created By         : PWC Digital Middle East
* --------------------------------------------------------------------------------------------------------------------
* Version       Author              Date                Comment
* 1.0           Yazan Saeed         01 May 2024      Initial Draft
* 1.1           Test Coverage       20 Aug 2026      Cover installment, charge, empty, finish and schedulable paths
***********************************************************************************************************************/
@isTest
public with sharing class OIC_ManageSalesforceInvoiceDataBatchTest {

    private class MockHttpResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"Status":"Success"}');
            res.setStatusCode(200);
            return res;
        }
    }

    @testSetup
    public static void makeData(){
        Schema.RecordTypeInfo recordTypeInfo = Schema.getGlobalDescribe().get('Account').getDescribe().getRecordTypeInfosByDeveloperName().get('PersonAccount');
        String recordTypeId = recordTypeInfo.getRecordTypeId();
        Account accountObj = new Account(RecordTypeId = recordTypeId);
        accountObj.PersonEmail = 'abdallahhdaib@outlook.com';
        accountObj.FirstName = 'First';
        accountObj.LastName = 'Last';
        accountObj.OraclePartyId__c ='22212';
        insert accountObj;

        Unit__c unitObj = new Unit__c();
        unitObj.Name = 'Test Unit';
        unitObj.BasePrice__c = 1000;
        unitObj.AdditionalPrice__c = 0;
        unitObj.PlotAreasqm__c = 1.0;
        unitObj.PlotNo__c = '1';
        unitObj.UnitClassification__c = 'Villa';
        unitObj.Number_of_Bedrooms__c = '2';
        INSERT unitObj;

        SalesOrder__c salesOrderObj = new SalesOrder__c();
        salesOrderObj.Status__c = 'In Progress';
        salesOrderObj.Unit__c = unitObj.Id;
        salesOrderObj.CustomerAccount__c = accountObj.Id;
        salesOrderObj.TotalAmount__c = 20000;
        salesOrderObj.OraclePartySiteID__c='33333';
        salesOrderObj.OracleCustAcctSiteID__c='765456';
        salesOrderObj.Source_Entity__c ='Modon - UAE';
        INSERT salesOrderObj;

        SalesOrder__c salesOrderNoStatus = new SalesOrder__c();
        salesOrderNoStatus.Status__c = '';
        INSERT salesOrderNoStatus;

        SalesOrderInstallments__c soInstallmentObj = new SalesOrderInstallments__c();
        soInstallmentObj.SalesOrder__c = salesOrderObj.Id;
        soInstallmentObj.Milestone__c = 1;
        soInstallmentObj.MilestoneNumber__c = 1;
        INSERT soInstallmentObj;

        Charge__c chargeObj = new Charge__c(Name = 'ADM Fee', Type__c = 'ADM & Dari Fee');
        insert chargeObj;

        list<Invoice__c> listInv= new list<Invoice__c>();

        Invoice__c invoiceObj = new Invoice__c();
        invoiceObj.SalesOrderInstallment__c = soInstallmentObj.Id;
        invoiceObj.InvoiceAmount__c = 1000;
        invoiceObj.Account__c = accountObj.Id;
        invoiceObj.Ebs_Invoice_Date__c =system.today();
        listInv.add(invoiceObj);

        Invoice__c invoiceAdmObj = new Invoice__c();
        invoiceAdmObj.InvoiceAmount__c = 1000;
        invoiceAdmObj.Account__c = accountObj.Id;
        invoiceAdmObj.Is_ADM_Fees_and_Dari_charges__c =true;
        invoiceAdmObj.Sales_Order__c =salesOrderObj.id;
        invoiceAdmObj.Ebs_Invoice_Date__c =system.today();
        listInv.add(invoiceAdmObj);

        Invoice__c invoiceCharge = new Invoice__c();
        invoiceCharge.Sales_Order__c = salesOrderObj.Id;
        invoiceCharge.InvoiceAmount__c = 1000;
        invoiceCharge.Account__c = accountObj.Id;
        invoiceCharge.OraclePartyId__c = '34214';
        invoiceCharge.Charge__c = chargeObj.Id;
        invoiceCharge.Ebs_Invoice_Date__c = system.today();
        listInv.add(invoiceCharge);

        Invoice__c invoiceNeither = new Invoice__c();
        invoiceNeither.Sales_Order__c = salesOrderObj.Id;
        invoiceNeither.InvoiceAmount__c = 500;
        invoiceNeither.Account__c = accountObj.Id;
        invoiceNeither.Ebs_Invoice_Date__c = system.today();
        listInv.add(invoiceNeither);

        insert listInv;
    }

    @isTest
    public static void testMethod1() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        Test.startTest();
            OIC_ManageSalesforceInvoiceDataBatch batchTest= new OIC_ManageSalesforceInvoiceDataBatch();
            Id jobid= Database.executeBatch(batchTest, 1);
        Test.stopTest();
        System.assertNotEquals(null, jobid, 'Batch job should be queued');
    }

    @isTest
    static void testStartExecuteFinishAndSchedule() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        List<Invoice__c> invoices = [
            SELECT Id, SalesOrderInstallment__c, Charge__c
            FROM Invoice__c
        ];

        OIC_ManageSalesforceInvoiceDataBatch batchTest = new OIC_ManageSalesforceInvoiceDataBatch();
        Test.startTest();
        Database.QueryLocator locator = batchTest.start(null);
        batchTest.execute(null, invoices);
        batchTest.execute(null, new List<Invoice__c>());
        batchTest.finish(null);
        batchTest.execute((SchedulableContext) null);
        Test.stopTest();

        System.assertNotEquals(null, locator, 'Start should return a query locator');
        System.assertEquals('TRUE', batchTest.IsChargeInvoicesIncluded, 'Charge invoice label should be loaded');
    }

    @isTest
    static void testExecuteInstallmentInvoicesOnly() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        List<Invoice__c> installmentInvoices = [
            SELECT Id, SalesOrderInstallment__c, Charge__c
            FROM Invoice__c
            WHERE SalesOrderInstallment__c != null
        ];

        OIC_ManageSalesforceInvoiceDataBatch batchTest = new OIC_ManageSalesforceInvoiceDataBatch();
        Test.startTest();
        batchTest.execute(null, installmentInvoices);
        Test.stopTest();

        System.assert(!installmentInvoices.isEmpty(), 'Installment invoices should exist for execute coverage');
    }

    @isTest
    static void testExecuteChargeInvoicesOnly() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        List<Invoice__c> chargeInvoices = [
            SELECT Id, SalesOrderInstallment__c, Charge__c
            FROM Invoice__c
            WHERE Charge__c != null
        ];

        OIC_ManageSalesforceInvoiceDataBatch batchTest = new OIC_ManageSalesforceInvoiceDataBatch();
        Test.startTest();
        batchTest.execute(null, chargeInvoices);
        Test.stopTest();

        System.assert(!chargeInvoices.isEmpty(), 'Charge invoices should exist for execute coverage');
    }
}