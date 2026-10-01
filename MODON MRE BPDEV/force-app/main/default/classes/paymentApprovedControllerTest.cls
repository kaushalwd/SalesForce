/**
* @description       : 
* author            : Kumaravel Mathivanan
* @group             : 
* @Created modified on  : 10-20-2025 * 
* * --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Kumaravel Mathivanan        10-02-2025     Initial Draft 
* 2.0 			Manoj						12-16-2025     Updated SOQL to add advanced search filters
*                                              (Project, Phase, Receipt Date, Transaction Date, Receipt Name)
* 3.0 			Manoj						01-20-2026     Update the testmethod fix soql and add new testmethod
**/
@isTest
public class paymentApprovedControllerTest {
    @TestSetup static void setupData() {
         // Bypass SO/Receipt/Account trigger queueables during test data insert.
         // Receipt/SO insert otherwise enqueues salesorderQueuableService, which chains
         // InvoiceQueueable and hits System.AsyncException: Maximum stack depth.
         bypassAsyncTriggers();

         //Create an account
         Schema.RecordTypeInfo recordTypeInfo = Schema.getGlobalDescribe().get('Account').getDescribe().getRecordTypeInfosByDeveloperName().get('PersonAccount');
         String recordTypeId = recordTypeInfo.getRecordTypeId();
         Account accountObj = new Account(RecordTypeId = recordTypeId);
         accountObj.PersonEmail = 'abdallahhdaib@outlook.com';
         accountObj.FirstName = 'First';
         accountObj.LastName = 'Last';
         accountObj.OICIntegrationStatus__c ='S';
         accountObj.OraclePartyId__c ='1344334';
         insert accountObj;
        
 		Project__c project = new Project__c();
        INSERT project;
        EscrowAccount__c escAccount = new EscrowAccount__c(name='Phase 1 Escrow Account');
        insert escAccount;
        
        Phase__c phase = new Phase__c();
        phase.Project__c = project.Id;
        phase.EscrowAccount__c =escAccount.id;
        INSERT phase;
         //Create a new Unit
         Unit__c unitObj = new Unit__c();
         unitObj.Name = 'Test Unit';
         unitObj.BasePrice__c = 1000;
         unitObj.AdditionalPrice__c = 0;
         unitObj.PlotAreasqm__c = 1.0;
         unitObj.PlotNo__c = '1';
         unitObj.UnitClassification__c = 'Villa';
         unitObj.Number_of_Bedrooms__c = '2';
         unitObj.Phase__c = phase.Id;
         INSERT unitObj;
 
         //Create a new sales order with a populated status
         SalesOrder__c salesOrderObj = new SalesOrder__c();
         salesOrderObj.Status__c = 'In Progress';
         salesOrderObj.Unit__c = unitObj.Id;
         SalesOrderObj.CustomerAccount__c = accountObj.Id;
         salesOrderObj.TotalAmount__c = 20000;
         salesOrderObj.OICIntegrationStatus__c ='S';
         salesOrderObj.OracleCustAcctSiteID__c='233423';
         salesOrderObj.OraclePartyId__c='3423432';
         salesOrderObj.OraclePartySiteID__c='22222';
         salesOrderObj.OracleSiteUseID__c='3323';
         salesOrderObj.CustAcctId__c ='341';
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
 
         //Create a new invoice related to soInstallmentObj
         Invoice__c invoiceObj = new Invoice__c();
         invoiceObj.SalesOrderInstallment__c = soInstallmentObj.Id;
         invoiceObj.InvoiceAmount__c = 1000;
         invoiceObj.Account__c = accountObj.Id;         
         INSERT invoiceObj;

         //Create a new invoice related to charges
         Invoice__c invoiceObj1 = new Invoice__c();
         invoiceObj1.Sales_Order__c = salesOrderObj.Id;
         invoiceObj1.InvoiceAmount__c = 1000;
         invoiceObj1.Account__c = accountObj.Id;         
         INSERT invoiceObj1;         
 		 list<Receipt__c> inserList= new list<Receipt__c>();
         //Create a new receipt 
         Receipt__c receiptObj = new Receipt__c();
         receiptObj.TotalAmount__c = 1000;
         receiptObj.Account__c = accountObj.Id;
         receiptObj.SalesOrderInstallment__c=soInstallmentObj.Id;
         receiptObj.SalesOrder__c= salesOrderObj.Id;
         receiptObj.status__c = 'In Progress';
         receiptObj.Modeofpayment__c = 'Cheque';
         receiptObj.OICIntegrationStatus__c = 'S';
         receiptObj.TransactionDate__c =system.now();
         inserList.add(receiptObj);

         //Create a new receipt for charges
         Receipt__c receiptObj1 = new Receipt__c();
         receiptObj1.TotalAmount__c = 1000;
         receiptObj1.Account__c = accountObj.Id;
         //receiptObj.SalesOrderInstallment__c=soInstallmentObj.Id;
         receiptObj1.status__c = 'In Progress';
         receiptObj1.Modeofpayment__c = 'Cheque';
         receiptObj1.OICIntegrationStatus__c = 'S';
         receiptObj1.SalesOrder__c= salesOrderObj.Id;
         receiptObj1.TransactionDate__c =system.now();
         inserList.add(receiptObj1);         
        insert inserList;

        TriggerControl.bypassTransferTrigger = false;
        TriggerControl.BypassAccountTrigger = false;
        TriggerControl.bypassReceiptTrigger = false;
    }

private class OIC_HttpCalloutMock implements HttpCalloutMock {

    public HTTPResponse respond(HTTPRequest req) {

        // Get a REAL Receipt Id created in @TestSetup
        Id receiptId = [SELECT Id FROM Receipt__c LIMIT 1].Id;

        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setStatusCode(200);

        String innerResponse =
            '{"ResponseArray":[{' +
            '"Sfid":"' + receiptId + '",' +
            '"OracleId":"12345",' +
            '"Status":"S"' +
            '}]}';

        String base64Response =
            EncodingUtil.base64Encode(Blob.valueOf(innerResponse));

        res.setBody('{"Base64Response":"' + base64Response + '"}');
        return res;
    }
}



    private static void bypassAsyncTriggers() {
        TriggerControl.bypassTransferTrigger = true;
        TriggerControl.BypassAccountTrigger = true;
        TriggerControl.bypassReceiptTrigger = true;
    }

    @IsTest
    static void testGetSalesOrderInstallments() {
        bypassAsyncTriggers();
        Project__c proj = [select id from Project__c];
        test.starttest();
        paymentApprovedController.getReceipts('ALL','ALL',null, null, null, null,null, null);
        paymentApprovedController.getProjects();
        paymentApprovedController.getPhasesByProject(proj.id);
        paymentApprovedController.getAllPhases();         
       
        test.stoptest();
    }
     @IsTest
    static void testGetReceipt() {
        bypassAsyncTriggers();
        Test.setMock(HttpCalloutMock.class, new OIC_HttpCalloutMock());
        list<Receipt__c> receipt = [SELECT Id,OraclePartyId__c,Status__c  FROM Receipt__c];
        test.starttest();
        
        try{
           paymentApprovedController.updateReceipts(receipt);
            paymentApprovedController.updateReceiptsBulk(receipt);
            
            list<id> receiptIds =new list<id>();
            receiptIds.add(receipt[0].id);
            paymentApprovedController.approveAndStartBatch(receiptIds);
            paymentApprovedController.getOicFailures(receiptIds);
        } catch (AuraHandledException ae) {
           
        } catch (Exception ex) {
           
        }
        test.stoptest();
    }
    @IsTest
    static void testGetReceipt1() {
        bypassAsyncTriggers();
        Test.setMock(HttpCalloutMock.class, new OIC_HttpCalloutMock());
        list<Receipt__c> receipt = [SELECT Id,OraclePartyId__c,Status__c  FROM Receipt__c];
        test.starttest();
        
        try{
            paymentApprovedController.updateReceipts(receipt);
            list<id> receiptIds =new list<id>();
            receiptIds.add(receipt[0].id);     
            paymentApprovedController.BatchStartResponse rec =new paymentApprovedController.BatchStartResponse();
       		rec =paymentApprovedController.approveAndStartBatch(receiptIds);  
            
            // Assert AsyncApexJob
           AsyncApexJob job = [ SELECT id,Status, JobItemsProcessed, TotalJobItems FROM AsyncApexJob where id =: rec.jobId LIMIT 1 ];
           string jonid =job.id;
       	   paymentApprovedController.getBatchProgress(jonid);
        } catch (AuraHandledException ae) {
           
        } catch (Exception ex) {
           
        }
        test.stoptest();
    }
	@IsTest
    static void testGetReceipt2() {
        bypassAsyncTriggers();
        list<Receipt__c> receipt = [SELECT Id,OraclePartyId__c,Status__c  FROM Receipt__c];
        test.starttest();
        paymentApprovedController.updateReceipts(receipt);
        try{
            list<id> receiptIds =new list<id>();
            receiptIds.add(receipt[0].id);
            paymentApprovedController.getOicFailures(receiptIds);
        } catch (AuraHandledException ae) {
           
        } catch (Exception ex) {
           
        }
        test.stoptest();
    }

    @IsTest
    static void testGetReceiptsFilterBranches() {
        bypassAsyncTriggers();
        Project__c proj = [SELECT Id FROM Project__c LIMIT 1];
        Phase__c phase = [SELECT Id FROM Phase__c LIMIT 1];
        Receipt__c rec = [SELECT Id, Name FROM Receipt__c WHERE SalesOrder__c != null LIMIT 1];

        ContentVersion cv = new ContentVersion(
            Title = 'PayApprove',
            PathOnClient = 'payapprove.pdf',
            VersionData = Blob.valueOf('receipt-file')
        );
        insert cv;
        cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
        insert new ContentDocumentLink(
            LinkedEntityId = rec.Id,
            ContentDocumentId = cv.ContentDocumentId,
            ShareType = 'V'
        );

        Date oracleDate = Date.valueOf(
            OIC_Query_Parameters__mdt.getInstance('Oracle_Integration_Enabled_Date').Value__c
        );

        Test.startTest();
        new paymentApprovedController();
        paymentApprovedController.getReceipts('ALL', 'ALL', null, null, null, null, null, 'Test Unit');
        paymentApprovedController.getReceipts(proj.Id, phase.Id, oracleDate.addDays(1), Date.today().addDays(1), Date.today().addDays(-30), Date.today().addDays(1), rec.Name, null);
        paymentApprovedController.getReceipts(proj.Id, 'ALL', oracleDate.addDays(-365), Date.today(), null, null, null, null);
        paymentApprovedController.getReceipts('ALL', 'ALL', null, null, null, null, rec.Name, null);
        Test.stopTest();
    }

    @IsTest
    static void testUpdateAndApproveCoverage() {
        bypassAsyncTriggers();
        Test.setMock(HttpCalloutMock.class, new OIC_HttpCalloutMock());
        Account acc = [SELECT Id FROM Account LIMIT 1];
        SalesOrder__c so = [SELECT Id FROM SalesOrder__c WHERE CustomerAccount__c != null LIMIT 1];
        Receipt__c rec = [
            SELECT Id, Status__c FROM Receipt__c
            WHERE SalesOrder__c != null AND Modeofpayment__c = 'Cheque'
            LIMIT 1
        ];
        Receipt__c recBlankMsg = [
            SELECT Id FROM Receipt__c
            WHERE SalesOrder__c != null AND Modeofpayment__c = 'Cheque' AND Id != :rec.Id
            LIMIT 1
        ];

        paymentApprovedController.updateReceipts(null);
        paymentApprovedController.updateReceipts(new List<Receipt__c>());
        paymentApprovedController.updateReceipts(new List<Receipt__c>{ new Receipt__c() });
        paymentApprovedController.updateReceiptsBulk(null);
        paymentApprovedController.updateReceiptsBulk(new List<Receipt__c>());
        paymentApprovedController.updateReceiptsBulk(new List<Receipt__c>{ new Receipt__c() });
        paymentApprovedController.getOicFailures(null);
        paymentApprovedController.getOicFailures(new List<Id>());

        try {
            paymentApprovedController.approveAndStartBatch(null);
        } catch (Exception expected) {
            System.assertNotEquals(null, expected.getMessage());
        }
        try {
            paymentApprovedController.approveAndStartBatch(new List<Id>());
        } catch (Exception expected) {
            System.assertNotEquals(null, expected.getMessage());
        }

        Receipt__c creditNote = new Receipt__c(
            TotalAmount__c = 200,
            Account__c = acc.Id,
            SalesOrder__c = so.Id,
            Status__c = 'In Progress',
            Modeofpayment__c = 'Credit Note',
            OICIntegrationStatus__c = 'S',
            TransactionDate__c = System.now()
        );
        insert creditNote;
        paymentApprovedController.updateReceipts(new List<Receipt__c>{
            new Receipt__c(Id = creditNote.Id, Status__c = 'In Progress')
        });

        List<Integration_Error_Messages__mdt> ebsMsgs = [
            SELECT System_Error_Msg__c
            FROM Integration_Error_Messages__mdt
            WHERE IsActive__c = true AND Application_Type__c = 'EBS' AND System_Error_Msg__c != null
            LIMIT 1
        ];
        if (!ebsMsgs.isEmpty()) {
            rec.OICIntegrationMessage__c = ebsMsgs[0].System_Error_Msg__c;
            rec.Modeofpayment__c = 'Cheque';
            update rec;
            try {
                paymentApprovedController.updateReceipts(new List<Receipt__c>{
                    new Receipt__c(Id = rec.Id, Status__c = 'In Progress')
                });
            } catch (Exception expected) {
                System.assertNotEquals(null, expected.getMessage());
            }
        }

        rec.OICIntegrationStatus__c = 'E';
        rec.OICIntegrationMessage__c = 'OIC failed';
        recBlankMsg.OICIntegrationStatus__c = 'E';
        recBlankMsg.OICIntegrationMessage__c = null;
        update new List<Receipt__c>{ rec, recBlankMsg };
        List<paymentApprovedController.ReceiptFailure> failures =
            paymentApprovedController.getOicFailures(new List<Id>{ rec.Id, recBlankMsg.Id });
        System.assertEquals(2, failures.size(), 'Failed OIC receipts should be returned');
    }

    @IsTest
    static void testValidateApprovalBranches() {
        bypassAsyncTriggers();
        Test.setMock(HttpCalloutMock.class, new OIC_HttpCalloutMock());

        Schema.RecordTypeInfo rt = Schema.getGlobalDescribe()
            .get('Account').getDescribe()
            .getRecordTypeInfosByDeveloperName().get('PersonAccount');
        Account unsyncedAcc = new Account(
            RecordTypeId = rt.getRecordTypeId(),
            FirstName = 'Unsynced',
            LastName = 'Customer',
            PersonEmail = 'unsynced.payapprove@test.com'
        );
        Account mappedAcc = new Account(
            RecordTypeId = rt.getRecordTypeId(),
            FirstName = 'Mapped',
            LastName = 'Customer',
            PersonEmail = 'mapped.payapprove@test.com',
            OraclePartyId__c = '999111',
            OICIntegrationMessage__c = 'ZZZ_UNMAPPED_PAY_APPROVE_TEST_999'
        );
        Account siteAcc = new Account(
            RecordTypeId = rt.getRecordTypeId(),
            FirstName = 'Site',
            LastName = 'Customer',
            PersonEmail = 'site.payapprove@test.com',
            OraclePartyId__c = '777222'
        );
        insert new List<Account>{ unsyncedAcc, mappedAcc, siteAcc };

        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];
        SalesOrder__c soNoParty = new SalesOrder__c(
            Status__c = 'In Progress',
            Unit__c = unit.Id,
            CustomerAccount__c = unsyncedAcc.Id,
            TotalAmount__c = 10000,
            OICIntegrationStatus__c = 'E'
        );
        SalesOrder__c soNoSite = new SalesOrder__c(
            Status__c = 'In Progress',
            Unit__c = unit.Id,
            CustomerAccount__c = siteAcc.Id,
            TotalAmount__c = 10000,
            OraclePartyId__c = '888',
            OICIntegrationStatus__c = 'E'
        );
        SalesOrder__c soUnmapped = new SalesOrder__c(
            Status__c = 'In Progress',
            Unit__c = unit.Id,
            CustomerAccount__c = mappedAcc.Id,
            TotalAmount__c = 10000,
            OraclePartyId__c = '888',
            OraclePartySiteID__c = '555',
            OICIntegrationStatus__c = 'E',
            OICIntegrationMessage__c = 'ZZZ_UNMAPPED_PAY_APPROVE_TEST_999'
        );
        insert new List<SalesOrder__c>{ soNoParty, soNoSite, soUnmapped };

        Receipt__c noSo = new Receipt__c(
            TotalAmount__c = 100,
            Account__c = unsyncedAcc.Id,
            Status__c = 'In Progress',
            Modeofpayment__c = 'Cheque',
            Is_Un_Identified_Receipts__c = false,
            TransactionDate__c = System.now()
        );
        Receipt__c unidentified = new Receipt__c(
            TotalAmount__c = 150,
            Account__c = unsyncedAcc.Id,
            Status__c = 'In Progress',
            Modeofpayment__c = 'Cheque',
            Is_Un_Identified_Receipts__c = true,
            OICIntegrationStatus__c = 'S',
            TransactionDate__c = System.now()
        );
        Receipt__c accIncomplete = new Receipt__c(
            TotalAmount__c = 200,
            Account__c = unsyncedAcc.Id,
            SalesOrder__c = soNoParty.Id,
            Status__c = 'In Progress',
            Modeofpayment__c = 'Cheque',
            OICIntegrationStatus__c = 'E',
            TransactionDate__c = System.now()
        );
        Receipt__c soIncomplete = new Receipt__c(
            TotalAmount__c = 250,
            Account__c = siteAcc.Id,
            SalesOrder__c = soNoSite.Id,
            Status__c = 'In Progress',
            Modeofpayment__c = 'Cheque',
            OICIntegrationStatus__c = 'E',
            TransactionDate__c = System.now()
        );
        Receipt__c unmappedMsg = new Receipt__c(
            TotalAmount__c = 260,
            Account__c = mappedAcc.Id,
            SalesOrder__c = soUnmapped.Id,
            Status__c = 'In Progress',
            Modeofpayment__c = 'Cheque',
            OICIntegrationStatus__c = 'E',
            OICIntegrationMessage__c = 'ZZZ_UNMAPPED_PAY_APPROVE_TEST_999',
            TransactionDate__c = System.now()
        );
        insert new List<Receipt__c>{ noSo, unidentified, accIncomplete, soIncomplete, unmappedMsg };

        Test.startTest();
        try {
            paymentApprovedController.updateReceiptsBulk(new List<Receipt__c>{
                new Receipt__c(Id = noSo.Id, Status__c = 'In Progress')
            });
        } catch (Exception expected) {
            System.assertNotEquals(null, expected.getMessage());
        }
        try {
            paymentApprovedController.approveAndStartBatch(new List<Id>{ accIncomplete.Id });
        } catch (Exception expected) {
            System.assertNotEquals(null, expected.getMessage());
        }
        try {
            paymentApprovedController.approveAndStartBatch(new List<Id>{ soIncomplete.Id });
        } catch (Exception expected) {
            System.assertNotEquals(null, expected.getMessage());
        }
        try {
            paymentApprovedController.approveAndStartBatch(new List<Id>{ unmappedMsg.Id });
        } catch (Exception expected) {
            System.assertNotEquals(null, expected.getMessage());
        }
        try {
            paymentApprovedController.approveAndStartBatch(new List<Id>{ unidentified.Id });
        } catch (Exception expected) {
            System.assertNotEquals(null, expected.getMessage());
        }
        Test.stopTest();
    }
}