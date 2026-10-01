/**********************************************************************************************************************
* Name               : OIC_ManageSalesforceBusAccDataBatchTest
* Description        : Test Class for OIC_ManageSalesforceBusinessAccDataBatch
* Created By         : PWC Digital Middle East
* --------------------------------------------------------------------------------------------------------------------
* Version       Author              Date                Comment
* 1.0           Yazan Saeed         01 May 2024      Initial Draft
***********************************************************************************************************************/
@isTest
public with sharing class OIC_ManageSalesforceBusAccDataBatchTest {
    @testSetup
    public static void makeData(){
        
       TriggerControl.BypassAccountTrigger   = true;
        TriggerControl.BypassCancelledTrigger = true;

        Schema.RecordTypeInfo recordTypeInfo =
            Schema.getGlobalDescribe()
                .get('Account')
                .getDescribe()
                .getRecordTypeInfosByDeveloperName()
                .get('PersonAccount');

        String recordTypeId = recordTypeInfo.getRecordTypeId();

        Account accountObj          = new Account(RecordTypeId = recordTypeId);
        accountObj.PersonEmail      = 'abdallahhdaib@outlook.com';
        accountObj.FirstName        = 'First';
        accountObj.LastName         = 'Last';
        accountObj.OraclePartyId__c = '22212';
        insert accountObj;

        Project__c projectObj = new Project__c();
        insert projectObj;

        EscrowAccount__c escrowObj       = new EscrowAccount__c();
        escrowObj.Name                   = 'OIC Escrow';
        escrowObj.AccountNumber__c       = 'ESC-001';
        escrowObj.IBANNo__c              = 'AE070331234567890123456';
        escrowObj.StoreId__c             = 'STORE-001';
        escrowObj.SwiftCode__c           = 'SWIFT001';
        escrowObj.TradeID__c             = 'TRADE-001';
        escrowObj.BankName__c            = 'Test Bank';
        escrowObj.BeneficiaryName__c     = 'Test Beneficiary';
        insert escrowObj;

        VirtualAccount__c vaObj           = new VirtualAccount__c();
        vaObj.Name                        = 'Test Virtual Account';
        vaObj.Status__c                   = 'Available';
        vaObj.EscrowAccount__c            = escrowObj.Id;
        vaObj.VirtualAccountNumber__c     = '124567642';
        vaObj.VirtualIBANNumber__c        = 'AE3456789456789';
        insert vaObj;

        Phase__c phaseObj         = new Phase__c();
        phaseObj.Project__c       = projectObj.Id;
        phaseObj.EscrowAccount__c = escrowObj.Id;
        phaseObj.EntityName__c    = 'Modon Properties PJSC';
        insert phaseObj;

        Unit__c unitObj                  = new Unit__c();
        unitObj.Name                     = 'Test Unit';
        unitObj.BasePrice__c             = 1000;
        unitObj.AdditionalPrice__c       = 0;
        unitObj.PlotAreasqm__c           = 1.0;
        unitObj.PlotNo__c                = '1';
        unitObj.UnitClassification__c    = 'Villa';
        unitObj.Number_of_Bedrooms__c    = '2';
        unitObj.NotToBeShownOnRD__c      = false;
        unitObj.Phase__c                 = phaseObj.Id;
        insert unitObj;

        Unit_Option__c unitOptionObj  = new Unit_Option__c();
        unitOptionObj.Unit__c         = unitObj.Id;
        unitOptionObj.Phase__c        = phaseObj.Id;
        unitOptionObj.PlotAreasqm__c  = 1.0;
        unitOptionObj.PlotNo__c       = '1';
        insert unitOptionObj;

        PaymentPlan__c paymentPlanObj  = new PaymentPlan__c();
        paymentPlanObj.Type__c         = 'Standard';
        paymentPlanObj.Unit__c         = unitObj.Id;
        paymentPlanObj.Status__c       = 'Active';
        paymentPlanObj.StartDate__c    = System.today().addDays(-2);
        paymentPlanObj.ExpiryDate__c   = System.today().addDays(5);
        insert paymentPlanObj;

        PaymentInstallements__c paymentInstallmentObj     = new PaymentInstallements__c();
        paymentInstallmentObj.PaymentInstallment__c       = paymentPlanObj.Id;
        paymentInstallmentObj.BrokerPayout__c             = 10;
        paymentInstallmentObj.Milestone__c                = 1;
        paymentInstallmentObj.MilestoneNumber__c          = 1;
        paymentInstallmentObj.MilestoneDescription__c     = 'OIC Test Milestone';
        insert paymentInstallmentObj;

        SalesOrder__c salesOrderObj               = new SalesOrder__c();
        salesOrderObj.Status__c                   = 'In Progress';
        salesOrderObj.Unit__c                     = unitObj.Id;
        salesOrderObj.UnitOption__c               = unitOptionObj.Id;
        salesOrderObj.PaymentPlan__c              = paymentPlanObj.Id;
        salesOrderObj.VirtualAccount__c           = vaObj.Id;
        salesOrderObj.CustomerAccount__c          = accountObj.Id;
        salesOrderObj.TotalAmount__c              = 20000;
        salesOrderObj.CustAcctId__c               = 'CUST-001';
        salesOrderObj.OraclePartySiteID__c        = '33333';
        salesOrderObj.OracleCustAcctSiteID__c     = '765456';
        salesOrderObj.OracleSiteUseID__c          = 'SITE-USE-001';
        salesOrderObj.OraclePartyId__c            = '34346';
        salesOrderObj.Source_Entity__c            = 'Modon - UAE';
        salesOrderObj.SalesAssociate__c           = UserInfo.getUserId();
        insert salesOrderObj;

        SalesOrder__c salesOrderNoStatus = new SalesOrder__c();
        salesOrderNoStatus.Status__c = '';
        insert salesOrderNoStatus;

        SalesOrderInstallments__c soInstallmentObj    = new SalesOrderInstallments__c();
        soInstallmentObj.SalesOrder__c                = salesOrderObj.Id;
        soInstallmentObj.PaymentInstallments__c       = paymentInstallmentObj.Id;
        soInstallmentObj.Milestone__c                 = 1;
        soInstallmentObj.MilestoneNumber__c           = 1;
        soInstallmentObj.MilestoneDescription__c      = 'OIC Test Installment';
        soInstallmentObj.InstallmentAmount__c         = 1000;
        soInstallmentObj.MilestoneDate__c             = System.today();
        insert soInstallmentObj;

        List<Invoice__c> listInv = new List<Invoice__c>();

        Invoice__c invoiceObj               = new Invoice__c();
        invoiceObj.SalesOrderInstallment__c = soInstallmentObj.Id;
        invoiceObj.Sales_Order__c           = salesOrderObj.Id;
        invoiceObj.InvoiceAmount__c         = 1000;
        invoiceObj.Account__c               = accountObj.Id;
        invoiceObj.Ebs_Invoice_Date__c      = System.today();
        invoiceObj.InvoiceDate__c           = System.today();
        listInv.add(invoiceObj);

        Invoice__c invoiceAdmObj                        = new Invoice__c();
        invoiceAdmObj.InvoiceAmount__c                  = 1000;
        invoiceAdmObj.Account__c                        = accountObj.Id;
        invoiceAdmObj.Is_ADM_Fees_and_Dari_charges__c   = true;
        invoiceAdmObj.Sales_Order__c                    = salesOrderObj.Id;
        invoiceAdmObj.Ebs_Invoice_Date__c               = System.today();
        invoiceAdmObj.InvoiceDate__c                    = System.today();
        listInv.add(invoiceAdmObj);

        Invoice__c invoiceObj1          = new Invoice__c();
        invoiceObj1.Sales_Order__c      = salesOrderObj.Id;
        invoiceObj1.InvoiceAmount__c    = 1000;
        invoiceObj1.Account__c          = accountObj.Id;
        invoiceObj1.Ebs_Invoice_Date__c = System.today();
        invoiceObj1.InvoiceDate__c      = System.today();
        listInv.add(invoiceObj1);

       // insert listInv;

        TriggerControl.BypassAccountTrigger   = false;
        TriggerControl.BypassCancelledTrigger = false;
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
            Test.setMock(HttpCalloutMock.class, new RestMock());
            OIC_ManageSalesforceBusinessAccDataBatch batchTest= new OIC_ManageSalesforceBusinessAccDataBatch();
            Id jobid= Database.executeBatch(batchTest, 1);
        Test.stopTest();
    }
}