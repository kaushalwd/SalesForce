/**********************************************************************************************************************
* Name               : OIC_ManageSalesforceDataControllerTest
* Description        : Test Class for OIC_ManageSalesforceDataController
* Created By         : PWC Digital Middle East
* --------------------------------------------------------------------------------------------------------------------
* Version       Author              Date                Comment
* 1.0           Yazan Saeed         05 April 2024      Initial Draft
* 2.0           Manoj               13 Jan 2026        Update the Fix
* 3.0           Active Minds        May 2026           Coverage fix
***********************************************************************************************************************/
@isTest
public class OIC_ManageSalesforceDataControllerTest {

    // ─────────────────────────────────────────────────────────────────────────
    // SHARED TEST SETUP
    // Receipt__c and Allocation__c are NOT created here.
    // They are inserted inside each test method via createReceiptsAndAllocation()
    // with TriggerControl bypass flags applied.
    // ─────────────────────────────────────────────────────────────────────────
    @TestSetup
    static void setupData() {
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

        // This is the Invoice createReceiptsAndAllocation() allocates against, so its
        // amount has to cover the full Applied roll-up (Invoice__c.AppliedAmount__c sums
        // every Allocation with Status = 'Applied'). The org's validation rule rejects an
        // Applied amount greater than the Invoice amount, so keep enough headroom here for
        // the 500 + 2000 allocated below.
        Invoice__c invoiceObj1          = new Invoice__c();
        invoiceObj1.Sales_Order__c      = salesOrderObj.Id;
        invoiceObj1.InvoiceAmount__c    = 5000;
        invoiceObj1.Account__c          = accountObj.Id;
        invoiceObj1.Ebs_Invoice_Date__c = System.today();
        invoiceObj1.InvoiceDate__c      = System.today();
        listInv.add(invoiceObj1);

        insert listInv;

        TriggerControl.BypassAccountTrigger   = false;
        TriggerControl.BypassCancelledTrigger = false;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // HELPER — creates Receipt__c + Allocation__c records inside each test
    // ─────────────────────────────────────────────────────────────────────────
    private static void createReceiptsAndAllocation() {
        TriggerControl.BypassAccountTrigger   = true;
        TriggerControl.BypassCancelledTrigger = true;

        Account              acc    = [SELECT Id FROM Account LIMIT 1];
        SalesOrder__c        so     = [SELECT Id FROM SalesOrder__c WHERE Status__c = 'In Progress' LIMIT 1];
        EscrowAccount__c     escrow = [SELECT Id FROM EscrowAccount__c LIMIT 1];
        SalesOrderInstallments__c soi = [SELECT Id FROM SalesOrderInstallments__c LIMIT 1];

        // Allocation__c rows are only picked up by createAllocation() when the parent
        // Invoice already carries an Oracle Id, so stamp it here. The non-SOI /
        // non-ADM Invoice is used on purpose: allocating against it keeps the
        // down-payment and ADM-fee automation out of this setup. It is created with a
        // 5000 InvoiceAmount__c so the allocations below stay within the org's
        // "Applied amount should not be greater than the Invoice amount" rule.
        Invoice__c inv = [
            SELECT Id, InvoiceAmount__c, OraclePartyId__c FROM Invoice__c
            WHERE SalesOrderInstallment__c = null AND Is_ADM_Fees_and_Dari_charges__c = false
            LIMIT 1
        ];
        inv.OraclePartyId__c = 'ORA-INV-001';
        update inv;

        List<Receipt__c> insertRec = new List<Receipt__c>();

        Receipt__c receiptObj               = new Receipt__c();
        receiptObj.TotalAmount__c           = 1000;
        receiptObj.Receipt_Amount__c        = 1000;
        receiptObj.Account__c               = acc.Id;
        receiptObj.SalesOrderInstallment__c = soi.Id;
        receiptObj.SalesOrder__c            = so.Id;
        receiptObj.PaymentEscrowAccount__c  = escrow.Id;
        receiptObj.TransactionDate__c       = System.now();
        receiptObj.ReceiptDate__c           = System.today();
        receiptObj.ChequeDate__c            = System.today();
        receiptObj.EBS_Clearing_Date__c     = System.today();
        receiptObj.Modeofpayment__c         = 'Cheque';
        receiptObj.Bank__c                  = 'CitiBank';
        receiptObj.TransactionNumber__c     = 'TXN-001';
        receiptObj.Status__c                = 'In Progress';
        // Deliberately left un-synced (no OraclePartyId__c): createReceipt() stamps
        // Oracle_Id_Temporary__c on success, and the org rejects that write on a Receipt
        // that already carries an Oracle Id ("This Receipt has already been synced to
        // Oracle"). TXN-001 carries no Allocation, so no test needs it pre-synced.
        insertRec.add(receiptObj);

        // TXN-002 carries the allocation that has to exceed Receipt__r.TotalAmount__c so
        // createUnAppliedAllocation() takes the receipt-total side of its min(). The org's
        // "Applied amount should not be greater than the Receipt amount" rule measures the
        // Applied roll-up against Receipt_Amount__c (a different field), so TotalAmount__c
        // is kept low for the min() while Receipt_Amount__c stays above the allocation.
        Receipt__c receiptObj1              = new Receipt__c();
        receiptObj1.TotalAmount__c          = 400;
        receiptObj1.Receipt_Amount__c       = 1000;
        receiptObj1.Account__c              = acc.Id;
        receiptObj1.SalesOrder__c           = so.Id;
        receiptObj1.PaymentEscrowAccount__c = escrow.Id;
        receiptObj1.TransactionDate__c      = System.now();
        receiptObj1.ReceiptDate__c          = System.today();
        receiptObj1.ChequeDate__c           = System.today();
        receiptObj1.EBS_Clearing_Date__c    = System.today();
        receiptObj1.Modeofpayment__c        = 'Cheque';
        receiptObj1.Bank__c                 = 'CitiBank';
        receiptObj1.TransactionNumber__c    = 'TXN-002';
        receiptObj1.Status__c               = 'In Progress';
        receiptObj1.OraclePartyId__c        = 'ORA-REC-002';
        insertRec.add(receiptObj1);

        Receipt__c approvedReceiptObj               = new Receipt__c();
        approvedReceiptObj.TotalAmount__c           = 500;
        approvedReceiptObj.Receipt_Amount__c        = 500;
        approvedReceiptObj.Account__c               = acc.Id;
        approvedReceiptObj.SalesOrderInstallment__c = soi.Id;
        approvedReceiptObj.SalesOrder__c            = so.Id;
        approvedReceiptObj.PaymentEscrowAccount__c  = escrow.Id;
        approvedReceiptObj.TransactionDate__c       = System.now();
        approvedReceiptObj.ReceiptDate__c           = System.today();
        approvedReceiptObj.ChequeDate__c            = System.today();
        approvedReceiptObj.EBS_Clearing_Date__c     = System.today();
        approvedReceiptObj.Modeofpayment__c         = 'Cheque';
        approvedReceiptObj.Bank__c                  = 'CitiBank';
        approvedReceiptObj.TransactionNumber__c     = 'TXN-003';
        approvedReceiptObj.Status__c                = 'In Progress';
        approvedReceiptObj.Receipt_Approved_Date__c = System.now();
        approvedReceiptObj.OraclePartyId__c         = 'ORA-REC-003';
        insertRec.add(approvedReceiptObj);

        insert insertRec;

        Map<String, Id> receiptByTxn = new Map<String, Id>();
        for (Receipt__c r : [
            SELECT Id, TransactionNumber__c FROM Receipt__c
            WHERE TransactionNumber__c IN ('TXN-001', 'TXN-002', 'TXN-003')
        ]) {
            receiptByTxn.put(r.TransactionNumber__c, r.Id);
        }

        List<Allocation__c> allocs = new List<Allocation__c>();

        // Receipt with a Sales Order Installment — satisfies every createAllocation() filter
        // and drives the SOI branch of the ProjectPhase / EntityName resolution.
        Allocation__c alloc       = new Allocation__c();
        alloc.Receipt__c          = receiptByTxn.get('TXN-003');
        alloc.Invoice__c          = inv.Id;
        alloc.AllocationAmount__c = 500;
        alloc.AllocationDate__c   = System.today();
        alloc.Status__c           = 'Applied';
        allocs.add(alloc);

        // Receipt without a Sales Order Installment — drives the Sales Order branch
        // of the ProjectPhase / EntityName resolution in createUnAppliedAllocation().
        Allocation__c allocNoSoi       = new Allocation__c();
        allocNoSoi.Receipt__c          = receiptByTxn.get('TXN-002');
        allocNoSoi.Invoice__c          = inv.Id;
        // > Receipt TotalAmount__c (400) -> other side of the min(), while staying under the
        // receipt's Receipt_Amount__c (1000). Together with the 500 above this keeps the
        // Invoice's Applied roll-up at 1300, under its 5000 amount.
        allocNoSoi.AllocationAmount__c = 800;
        allocNoSoi.AllocationDate__c   = System.today();
        allocNoSoi.Status__c           = 'Applied';
        allocs.add(allocNoSoi);

        insert allocs;

        TriggerControl.BypassAccountTrigger   = false;
        TriggerControl.BypassCancelledTrigger = false;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MOCK CLASSES
    // ─────────────────────────────────────────────────────────────────────────

    /** Generic success mock — extracts all Sfid values from any base64 payload */
    private class RestMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            Set<String> sfids = new Set<String>();
            try {
                if (String.isNotBlank(req.getBody())) {
                    Map<String, Object> bodyMap =
                        (Map<String, Object>) JSON.deserializeUntyped(req.getBody());
                    String base64Payload;
                    if (bodyMap.containsKey('Base64RequestPayload'))
                        base64Payload = (String) bodyMap.get('Base64RequestPayload');
                    else if (bodyMap.containsKey('Base64Request'))
                        base64Payload = (String) bodyMap.get('Base64Request');
                    if (String.isNotBlank(base64Payload))
                        collectSfidValues(
                            JSON.deserializeUntyped(EncodingUtil.base64Decode(base64Payload).toString()),
                            sfids
                        );
                }
            } catch (Exception ex) {}

            List<Object> responseArray = new List<Object>();
            for (String sfid : sfids) {
                Map<String, Object> row = new Map<String, Object>();
                row.put('Sfid',                sfid);
                row.put('Status',              'S');
                row.put('ErrorMsg',            null);
                row.put('OracleId',            'ORACLE-' + sfid.right(6));
                row.put('OracleRef',           'ORACLE-REF-' + sfid.right(6));
                row.put('CustAcctId',          'CUST-' + sfid.right(6));
                row.put('OraclePartySiteID',   'OPS-' + sfid.right(6));
                row.put('OracleCustAcctSiteID','OCAS-' + sfid.right(6));
                row.put('OracleSiteUseID',     'OSU-' + sfid.right(6));
                responseArray.add(row);
            }
            return buildResponse(responseArray);
        }

        private void collectSfidValues(Object obj, Set<String> sfids) {
            if (obj == null) return;
            if (obj instanceof Map<String, Object>) {
                Map<String, Object> m = (Map<String, Object>) obj;
                for (String key : m.keySet()) {
                    if (key != null && key.toLowerCase() == 'sfid' && m.get(key) != null)
                        sfids.add(String.valueOf(m.get(key)));
                    else
                        collectSfidValues(m.get(key), sfids);
                }
            } else if (obj instanceof List<Object>) {
                for (Object item : (List<Object>) obj) collectSfidValues(item, sfids);
            }
        }

        private HTTPResponse buildResponse(List<Object> responseArray) {
            Map<String, Object> decoded = new Map<String, Object>();
            decoded.put('ResponseArray', responseArray);
            OIC_RequestWrapperController.Base64ResponseWrapper b64 =
                new OIC_RequestWrapperController.Base64ResponseWrapper();
            b64.Base64Response =
                EncodingUtil.base64Encode(Blob.valueOf(JSON.serialize(decoded)));
            HTTPResponse res = new HTTPResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody(JSON.serialize(b64));
            res.setStatusCode(200);
            res.setStatus('OK');
            return res;
        }
    }

    /** Generic error mock — returns Status = 'E' with Unknown integration error */
    private class RestErrorMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            Set<String> sfids = new Set<String>();
            try {
                if (String.isNotBlank(req.getBody())) {
                    Map<String, Object> bodyMap =
                        (Map<String, Object>) JSON.deserializeUntyped(req.getBody());
                    String base64Payload;
                    if (bodyMap.containsKey('Base64RequestPayload'))
                        base64Payload = (String) bodyMap.get('Base64RequestPayload');
                    else if (bodyMap.containsKey('Base64Request'))
                        base64Payload = (String) bodyMap.get('Base64Request');
                    if (String.isNotBlank(base64Payload))
                        collectSfidValues(
                            JSON.deserializeUntyped(EncodingUtil.base64Decode(base64Payload).toString()),
                            sfids
                        );
                }
            } catch (Exception ex) {}

            List<Object> responseArray = new List<Object>();
            for (String sfid : sfids) {
                Map<String, Object> row = new Map<String, Object>();
                row.put('Sfid',                sfid);
                row.put('Status',              'E');
                row.put('ErrorMsg',            'Unknown integration error from test');
                row.put('OracleId',            null);
                row.put('OracleRef',           null);
                row.put('CustAcctId',          null);
                row.put('OraclePartySiteID',   null);
                row.put('OracleCustAcctSiteID', null);
                row.put('OracleSiteUseID',     null);
                responseArray.add(row);
            }
            Map<String, Object> decoded = new Map<String, Object>();
            decoded.put('ResponseArray', responseArray);
            OIC_RequestWrapperController.Base64ResponseWrapper b64 =
                new OIC_RequestWrapperController.Base64ResponseWrapper();
            b64.Base64Response =
                EncodingUtil.base64Encode(Blob.valueOf(JSON.serialize(decoded)));
            HTTPResponse res = new HTTPResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody(JSON.serialize(b64));
            res.setStatusCode(200);
            res.setStatus('OK');
            return res;
        }

        private void collectSfidValues(Object obj, Set<String> sfids) {
            if (obj == null) return;
            if (obj instanceof Map<String, Object>) {
                Map<String, Object> m = (Map<String, Object>) obj;
                for (String key : m.keySet()) {
                    if (key != null && key.toLowerCase() == 'sfid' && m.get(key) != null)
                        sfids.add(String.valueOf(m.get(key)));
                    else
                        collectSfidValues(m.get(key), sfids);
                }
            } else if (obj instanceof List<Object>) {
                for (Object item : (List<Object>) obj) collectSfidValues(item, sfids);
            }
        }
    }

    /** Error mock returning a non-Unknown error (exercises resolveErrMsg non-null branch) */
    private class RestKnownErrorMock implements HttpCalloutMock {
        private String sfidToReturn;
        public RestKnownErrorMock(String sfid) { this.sfidToReturn = sfid; }
        public HTTPResponse respond(HTTPRequest req) {
            List<Object> responseArray = new List<Object>();
            Map<String, Object> row = new Map<String, Object>();
            row.put('Sfid',     sfidToReturn);
            row.put('Status',   'E');
            row.put('ErrorMsg', 'Specific known error');
            row.put('OracleId', null);
            responseArray.add(row);
            Map<String, Object> decoded = new Map<String, Object>();
            decoded.put('ResponseArray', responseArray);
            OIC_RequestWrapperController.Base64ResponseWrapper b64 =
                new OIC_RequestWrapperController.Base64ResponseWrapper();
            b64.Base64Response =
                EncodingUtil.base64Encode(Blob.valueOf(JSON.serialize(decoded)));
            HTTPResponse res = new HTTPResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody(JSON.serialize(b64));
            res.setStatusCode(200);
            res.setStatus('OK');
            return res;
        }
    }

    /** Success mock for Project */
    private class RestProjectMock implements HttpCalloutMock {
        private String sfidToReturn;
        public RestProjectMock(String sfid) { this.sfidToReturn = sfid; }
        public HTTPResponse respond(HTTPRequest req) {
            List<Object> responseArray = new List<Object>();
            Map<String, Object> row = new Map<String, Object>();
            row.put('Sfid',     sfidToReturn);
            row.put('Status',   'S');
            row.put('ErrorMsg', null);
            row.put('OracleId', 'ORA-PROJ-001');
            responseArray.add(row);
            Map<String, Object> decoded = new Map<String, Object>();
            decoded.put('ResponseArray', responseArray);
            OIC_RequestWrapperController.Base64ResponseWrapper b64 =
                new OIC_RequestWrapperController.Base64ResponseWrapper();
            b64.Base64Response =
                EncodingUtil.base64Encode(Blob.valueOf(JSON.serialize(decoded)));
            HTTPResponse res = new HTTPResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody(JSON.serialize(b64));
            res.setStatusCode(200);
            res.setStatus('OK');
            return res;
        }
    }

    /** Error mock for Project with null ErrorMsg */
    private class RestProjectNullErrorMock implements HttpCalloutMock {
        private String sfidToReturn;
        public RestProjectNullErrorMock(String sfid) { this.sfidToReturn = sfid; }
        public HTTPResponse respond(HTTPRequest req) {
            List<Object> responseArray = new List<Object>();
            Map<String, Object> row = new Map<String, Object>();
            row.put('Sfid',     sfidToReturn);
            row.put('Status',   'E');
            row.put('ErrorMsg', null);
            row.put('OracleId', null);
            responseArray.add(row);
            Map<String, Object> decoded = new Map<String, Object>();
            decoded.put('ResponseArray', responseArray);
            OIC_RequestWrapperController.Base64ResponseWrapper b64 =
                new OIC_RequestWrapperController.Base64ResponseWrapper();
            b64.Base64Response =
                EncodingUtil.base64Encode(Blob.valueOf(JSON.serialize(decoded)));
            HTTPResponse res = new HTTPResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody(JSON.serialize(b64));
            res.setStatusCode(200);
            res.setStatus('OK');
            return res;
        }
    }

    private class RestInvErroMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            OIC_RequestWrapperController.OICResponseWrapperList wl =
                new OIC_RequestWrapperController.OICResponseWrapperList();
            OIC_RequestWrapperController.OICResponseWrapper rw =
                new OIC_RequestWrapperController.OICResponseWrapper();
            rw.Sfid = [SELECT Id FROM Invoice__c LIMIT 1].Id;
            rw.Status = 'E'; rw.ErrorMsg = 'integration error'; rw.OracleId = null;
            wl.ResponseArray = new List<OIC_RequestWrapperController.OICResponseWrapper>{ rw };
            OIC_RequestWrapperController.Base64ResponseWrapper b64 =
                new OIC_RequestWrapperController.Base64ResponseWrapper();
            b64.Base64Response = EncodingUtil.base64Encode(Blob.valueOf(JSON.serialize(wl)));
            HTTPResponse res = new HTTPResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody(JSON.serialize(b64));
            res.setStatusCode(200);
            return res;
        }
    }

    private class RestInvMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            OIC_RequestWrapperController.OICResponseWrapperList wl =
                new OIC_RequestWrapperController.OICResponseWrapperList();
            OIC_RequestWrapperController.OICResponseWrapper rw =
                new OIC_RequestWrapperController.OICResponseWrapper();
            rw.Sfid = [SELECT Id FROM Invoice__c LIMIT 1].Id;
            rw.Status = 'S'; rw.ErrorMsg = null; rw.OracleId = '23244325432';
            wl.ResponseArray = new List<OIC_RequestWrapperController.OICResponseWrapper>{ rw };
            OIC_RequestWrapperController.Base64ResponseWrapper b64 =
                new OIC_RequestWrapperController.Base64ResponseWrapper();
            b64.Base64Response = EncodingUtil.base64Encode(Blob.valueOf(JSON.serialize(wl)));
            HTTPResponse res = new HTTPResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody(JSON.serialize(b64));
            res.setStatusCode(200);
            return res;
        }
    }

    /** Mock that fails the callout, so every method's catch (Exception) block runs. */
    private class RestThrowMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            CalloutException e = new CalloutException();
            e.setMessage('Simulated OIC callout failure');
            throw e;
        }
    }

    /** Mock returning an empty body, so the `response != ''` guard short-circuits. */
    private class RestEmptyBodyMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('');
            res.setStatusCode(200);
            res.setStatus('OK');
            return res;
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // TEST METHODS — TriggerControl bypass applied to every method
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    public static void calloutExceptionBranches_Part1Test() {
        TriggerControl.BypassAccountTrigger   = true;
        TriggerControl.BypassCancelledTrigger = true;

        createReceiptsAndAllocation();

        Set<String> accountIds   = new Set<String>();
        Set<String> salesOrderIds = new Set<String>();
        Set<String> receiptIds   = new Set<String>();
        Set<String> unitIds      = new Set<String>();
        for (Account a : [SELECT Id FROM Account])                 { accountIds.add(a.Id); }
        for (SalesOrder__c s : [SELECT Id FROM SalesOrder__c])      { salesOrderIds.add(s.Id); }
        for (Receipt__c r : [SELECT Id FROM Receipt__c])            { receiptIds.add(r.Id); }
        for (Unit__c u : [SELECT Id FROM Unit__c])                  { unitIds.add(u.Id); }

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new RestThrowMock());
        OIC_ManageSalesforceDataController.updateUnitStatus(unitIds);
        OIC_ManageSalesforceDataController.createAccount(accountIds);
        OIC_ManageSalesforceDataController.createSalesOrderAndSOInstallments(salesOrderIds);
        OIC_ManageSalesforceDataController.createCreditReceipt(receiptIds);
        try {
            // createReceipt re-throws after logging
            OIC_ManageSalesforceDataController.createReceipt(receiptIds);
        } catch (Exception ex) { /* expected */ }
        Test.stopTest();

        TriggerControl.BypassAccountTrigger   = false;
        TriggerControl.BypassCancelledTrigger = false;
    }

    @isTest
    public static void calloutExceptionBranches_Part2Test() {
        TriggerControl.BypassAccountTrigger   = true;
        TriggerControl.BypassCancelledTrigger = true;

        createReceiptsAndAllocation();

        Set<String> allocationIds = new Set<String>();
        Set<String> invoiceIds    = new Set<String>();
        Set<Id>     projectIds    = new Set<Id>();
        for (Allocation__c a : [SELECT Id FROM Allocation__c])  { allocationIds.add(a.Id); }
        for (Invoice__c i : [SELECT Id FROM Invoice__c])        { invoiceIds.add(i.Id); }
        for (Project__c p : [SELECT Id FROM Project__c])        { projectIds.add(p.Id); }

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new RestThrowMock());
        OIC_ManageSalesforceDataController.createAllocation(allocationIds);
        OIC_ManageSalesforceDataController.createUnAppliedAllocation(allocationIds);
        OIC_ManageSalesforceDataController.createProject(projectIds);
        OIC_ManageSalesforceDataController.createInstallment(invoiceIds);
        Test.stopTest();

        TriggerControl.BypassAccountTrigger   = false;
        TriggerControl.BypassCancelledTrigger = false;
    }

    /**
     * createCreditReceipt() resolves the Sales Order straight off the Receipt when the
     * Receipt has no Sales Order Installment. Only that path has every VirtualAccount /
     * Escrow field in the SOQL, so it is the path that reaches the callout and the
     * response handling.
     */
    @isTest
    public static void createCreditReceipt_NonSoiSuccessTest() {
        TriggerControl.BypassAccountTrigger   = true;
        TriggerControl.BypassCancelledTrigger = true;

        createReceiptsAndAllocation();

        Receipt__c rec = [SELECT Id FROM Receipt__c WHERE TransactionNumber__c = 'TXN-002' LIMIT 1];

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new RestMock());
        OIC_ManageSalesforceDataController.createCreditReceipt(new Set<String>{ rec.Id });
        Test.stopTest();

        TriggerControl.BypassAccountTrigger   = false;
        TriggerControl.BypassCancelledTrigger = false;
    }

    @isTest
    public static void createCreditReceipt_NonSoiErrorTest() {
        TriggerControl.BypassAccountTrigger   = true;
        TriggerControl.BypassCancelledTrigger = true;

        createReceiptsAndAllocation();

        Receipt__c rec = [SELECT Id FROM Receipt__c WHERE TransactionNumber__c = 'TXN-002' LIMIT 1];

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new RestErrorMock());
        OIC_ManageSalesforceDataController.createCreditReceipt(new Set<String>{ rec.Id });
        Test.stopTest();

        TriggerControl.BypassAccountTrigger   = false;
        TriggerControl.BypassCancelledTrigger = false;
    }

    /** Same path, but with a mapped (non-"Unknown") error message. */
    @isTest
    public static void createCreditReceipt_NonSoiKnownErrorTest() {
        TriggerControl.BypassAccountTrigger   = true;
        TriggerControl.BypassCancelledTrigger = true;

        createReceiptsAndAllocation();

        Receipt__c rec = [SELECT Id FROM Receipt__c WHERE TransactionNumber__c = 'TXN-002' LIMIT 1];

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new RestKnownErrorMock(rec.Id));
        OIC_ManageSalesforceDataController.createCreditReceipt(new Set<String>{ rec.Id });
        Test.stopTest();

        TriggerControl.BypassAccountTrigger   = false;
        TriggerControl.BypassCancelledTrigger = false;
    }

    @isTest
    public static void emptyResponseBodyBranchesTest() {
        TriggerControl.BypassAccountTrigger   = true;
        TriggerControl.BypassCancelledTrigger = true;

        createReceiptsAndAllocation();

        Set<String> allocationIds = new Set<String>();
        Set<String> accountIds    = new Set<String>();
        Set<Id>     projectIds    = new Set<Id>();
        for (Allocation__c a : [SELECT Id FROM Allocation__c]) { allocationIds.add(a.Id); }
        for (Account a : [SELECT Id FROM Account])             { accountIds.add(a.Id); }
        for (Project__c p : [SELECT Id FROM Project__c])       { projectIds.add(p.Id); }

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new RestEmptyBodyMock());
        OIC_ManageSalesforceDataController.createAllocation(allocationIds);
        OIC_ManageSalesforceDataController.createUnAppliedAllocation(allocationIds);
        OIC_ManageSalesforceDataController.createAccount(accountIds);
        OIC_ManageSalesforceDataController.createProject(projectIds);
        Test.stopTest();

        TriggerControl.BypassAccountTrigger   = false;
        TriggerControl.BypassCancelledTrigger = false;
    }

    @isTest
    public static void createAccountTest() {
        TriggerControl.BypassAccountTrigger   = true;
        TriggerControl.BypassCancelledTrigger = true;

        Set<String> personAccountIdSet = new Set<String>();
        Account acc = new Account();
        for (Account a : [SELECT Id, LastName, FirstName FROM Account]) {
            personAccountIdSet.add(a.Id);
            acc.Id = a.Id; acc.LastName = a.LastName; acc.FirstName = a.FirstName;
        }

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new RestAccMock());
        OIC_ManageSalesforceDataController.createAccount(personAccountIdSet);
        OIC_ManageSalesforceDataController.createOrganizationWrapper(acc);
        Test.stopTest();

        TriggerControl.BypassAccountTrigger   = false;
        TriggerControl.BypassCancelledTrigger = false;
    }

    @isTest
    public static void createReceiptTest() {
        TriggerControl.BypassAccountTrigger   = true;
        TriggerControl.BypassCancelledTrigger = true;

        createReceiptsAndAllocation();

        // Only the un-synced Receipt is sent: createReceipt() writes Oracle_Id_Temporary__c
        // on a success response, which the org blocks on a Receipt that already carries an
        // Oracle Id. That mirrors production, where this API runs before the receipt syncs.
        Set<String> receiptIdSet = new Set<String>();
        for (Receipt__c r : [SELECT Id FROM Receipt__c WHERE OraclePartyId__c = null]) { receiptIdSet.add(r.Id); }

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new RestreceiptMock());
        OIC_ManageSalesforceDataController.createReceipt(receiptIdSet);
        Test.stopTest();

        TriggerControl.BypassAccountTrigger   = false;
        TriggerControl.BypassCancelledTrigger = false;
    }

    @isTest
    public static void createSalesOrderAndSOInstallmentsTest() {
        TriggerControl.BypassAccountTrigger   = true;
        TriggerControl.BypassCancelledTrigger = true;

        Set<String> salesOrderIdSet = new Set<String>();
        for (SalesOrder__c so : [SELECT Id FROM SalesOrder__c]) { salesOrderIdSet.add(so.Id); }

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new RestMock());
        OIC_ManageSalesforceDataController.createSalesOrderAndSOInstallments(salesOrderIdSet);
        Test.stopTest();

        TriggerControl.BypassAccountTrigger   = false;
        TriggerControl.BypassCancelledTrigger = false;
    }

    @isTest
    public static void createInstallmentTest() {
        TriggerControl.BypassAccountTrigger   = true;
        TriggerControl.BypassCancelledTrigger = true;

        Set<String> invoiceIdSet = new Set<String>();
        for (Invoice__c inv : [
            SELECT Id FROM Invoice__c WHERE Is_ADM_Fees_and_Dari_charges__c = false LIMIT 1
        ]) { invoiceIdSet.add(inv.Id); }

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new RestInvMock());
        OIC_ManageSalesforceDataController.createInstallment(invoiceIdSet);
        OIC_ManageSalesforceDataController.createInstallment(null);
        Test.stopTest();

        TriggerControl.BypassAccountTrigger   = false;
        TriggerControl.BypassCancelledTrigger = false;
    }

    @isTest
    public static void createAllocationTest() {
        TriggerControl.BypassAccountTrigger   = true;
        TriggerControl.BypassCancelledTrigger = true;

        createReceiptsAndAllocation();

        Set<String> allocationIdSet = new Set<String>();
        for (Allocation__c a : [SELECT Id FROM Allocation__c]) { allocationIdSet.add(a.Id); }

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new RestMock());
        OIC_ManageSalesforceDataController.createAllocation(allocationIdSet);
        OIC_ManageSalesforceDataController.createAllocation(null);
        Test.stopTest();

        TriggerControl.BypassAccountTrigger   = false;
        TriggerControl.BypassCancelledTrigger = false;
    }

    @isTest
    public static void updateUnitStatusTest() {
        TriggerControl.BypassAccountTrigger   = true;
        TriggerControl.BypassCancelledTrigger = true;

        Set<String> unitIdSet = new Set<String>();
        for (Unit__c u : [SELECT Id FROM Unit__c]) { unitIdSet.add(u.Id); }

        Test.setMock(HttpCalloutMock.class, new RestMock());
        Test.startTest();
        OIC_ManageSalesforceDataController.updateUnitStatus(unitIdSet);
        Test.stopTest();

        TriggerControl.BypassAccountTrigger   = false;
        TriggerControl.BypassCancelledTrigger = false;
    }

    @isTest
    public static void accountOrgTest() {
        TriggerControl.BypassAccountTrigger   = true;
        TriggerControl.BypassCancelledTrigger = true;

        Id orgConRtId = [
            SELECT Id FROM RecordType WHERE SObjectType = 'Contact' AND DeveloperName = 'Individual' LIMIT 1
        ].Id;
        Id orgAccRtId = [
            SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND DeveloperName = 'OrganizationAccount' LIMIT 1
        ].Id;

        Account businessAcc = new Account(Name = 'Test Business', RecordTypeId = orgAccRtId);
        insert businessAcc;

        Contact con = new Contact(
            LastName = 'Test Contact', AccountId = businessAcc.Id,
            Email = 'test@example.com', Is_Active__c = true, RecordTypeId = orgConRtId
        );
        insert con;

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new RestMock());
        OIC_ManageSalesforceDataController.createAccount(new Set<String>{ businessAcc.Id });
        Test.stopTest();

        TriggerControl.BypassAccountTrigger   = false;
        TriggerControl.BypassCancelledTrigger = false;
    }

    @isTest
    public static void createCreditReceiptTest() {
        TriggerControl.BypassAccountTrigger   = true;
        TriggerControl.BypassCancelledTrigger = true;

        createReceiptsAndAllocation();

        Set<String> receiptIds = new Set<String>();
        for (Receipt__c r : [SELECT Id FROM Receipt__c WHERE SalesOrder__c != null]) {
            receiptIds.add(r.Id);
        }

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new RestMock());
        OIC_ManageSalesforceDataController.createCreditReceipt(receiptIds);
        Test.stopTest();

        TriggerControl.BypassAccountTrigger   = false;
        TriggerControl.BypassCancelledTrigger = false;
    }

    @isTest
    public static void createAllocation2Test() {
        TriggerControl.BypassAccountTrigger   = true;
        TriggerControl.BypassCancelledTrigger = true;

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new RestMock());
        OIC_ManageSalesforceDataController.createAllocation(new Set<String>());
        OIC_ManageSalesforceDataController.createAllocation(null);
        Test.stopTest();

        TriggerControl.BypassAccountTrigger   = false;
        TriggerControl.BypassCancelledTrigger = false;
        
    }

    @isTest
    public static void createAllocationErrorTest() {
        TriggerControl.BypassAccountTrigger   = true;
        TriggerControl.BypassCancelledTrigger = true;

        createReceiptsAndAllocation();

        Set<String> allocationIds = new Set<String>();
        for (Allocation__c a : [SELECT Id FROM Allocation__c]) { allocationIds.add(a.Id); }

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new RestErrorMock());
        OIC_ManageSalesforceDataController.createAllocation(allocationIds);
        Test.stopTest();

        TriggerControl.BypassAccountTrigger   = false;
        TriggerControl.BypassCancelledTrigger = false;
        
    }

    @isTest
    public static void createInstallmentErrorTest() {
        TriggerControl.BypassAccountTrigger   = true;
        TriggerControl.BypassCancelledTrigger = true;

        Set<String> invoiceIdSet = new Set<String>();
        for (Invoice__c inv : [
            SELECT Id FROM Invoice__c WHERE Is_ADM_Fees_and_Dari_charges__c = false LIMIT 1
        ]) { invoiceIdSet.add(inv.Id); }

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new RestInvErroMock());
        OIC_ManageSalesforceDataController.createInstallment(invoiceIdSet);
        Test.stopTest();

        TriggerControl.BypassAccountTrigger   = false;
        TriggerControl.BypassCancelledTrigger = false;
    }

    @isTest
    public static void createInstallmentSTest() {
        TriggerControl.BypassAccountTrigger   = true;
        TriggerControl.BypassCancelledTrigger = true;

        Set<String> invoiceIdSet = new Set<String>();
        for (Invoice__c inv : [
            SELECT Id FROM Invoice__c WHERE Is_ADM_Fees_and_Dari_charges__c = false LIMIT 1
        ]) { invoiceIdSet.add(inv.Id); }

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new RestInvMock());
        OIC_ManageSalesforceDataController.createInstallment(invoiceIdSet);
        Test.stopTest();

        TriggerControl.BypassAccountTrigger   = false;
        TriggerControl.BypassCancelledTrigger = false;
    }

    @isTest
    public static void createPersonWrapper_DirectCoverageTest() {
        TriggerControl.BypassAccountTrigger   = true;
        TriggerControl.BypassCancelledTrigger = true;

        Account personAcc = [
            SELECT Id, Name, PersonTitle, FirstName, MiddleName, LastName, EIDNumber__pc,
                   EmiratesIDExpiryDate__pc,
                   (SELECT Id, Name, Email, EIDNumber__c, Birthdate, MobilePhone, Nationality__c
                    FROM Contacts LIMIT 1),
                   IsPersonAccount, TradeName__c, UnifiedNumber__c, PersonEmail, Phone,
                   BillingCountry, PassportNumber__pc, PersonGenderIdentity, MaritalStatus__pc,
                   PersonBirthdate, UAE_Resident_Status__pc, PassportExpiryDate__pc,
                   Nationality__pc, BillingCity, BillingState, BillingAddress, BillingStreet,
                   UAEVATRegisterNumber__c, PersonMobilePhone, PersonMailingCity,
                   PersonMailingStreet, PersonMailingState, PersonMailingCountry,
                   PersonMailingPostalCode
            FROM Account WHERE IsPersonAccount = true LIMIT 1
        ];

        Test.startTest();
        OIC_RequestWrapperController.CustomerWrapper wrapper =
            OIC_ManageSalesforceDataController.createPersonWrapper(personAcc);
        Test.stopTest();

        TriggerControl.BypassAccountTrigger   = false;
        TriggerControl.BypassCancelledTrigger = false;
        
    }

    @isTest
    public static void createOrganizationWrapper_DirectCoverageTest() {
        TriggerControl.BypassAccountTrigger   = true;
        TriggerControl.BypassCancelledTrigger = true;

        Account businessAcc = new Account(
            Name = 'Direct Org Wrapper Account', BillingCountry = 'United Arab Emirates',
            BillingCity = 'Abu Dhabi', BillingState = 'Abu Dhabi',
            BillingStreet = 'Test Street', Phone = '123456789'
        );
        insert businessAcc;

        Contact con = new Contact(
            LastName = 'Org Contact', AccountId = businessAcc.Id, Email = 'orgcontact@test.com'
        );
        insert con;

        Account queriedAcc = [
            SELECT Id, Name, FirstName, MiddleName, LastName, TradeName__c, UnifiedNumber__c,
                   Phone, BillingCountry, BillingCity, BillingState, BillingStreet,
                   UAEVATRegisterNumber__c,
                   (SELECT Id, Name, Email FROM Contacts LIMIT 1)
            FROM Account WHERE Id = :businessAcc.Id LIMIT 1
        ];

        Test.startTest();
        OIC_RequestWrapperController.CustomerWrapper wrapper =
            OIC_ManageSalesforceDataController.createOrganizationWrapper(queriedAcc);
        Test.stopTest();

        TriggerControl.BypassAccountTrigger   = false;
        TriggerControl.BypassCancelledTrigger = false;
        
    }

    @isTest
    public static void errorResponseBranch_AccountTest() {
        TriggerControl.BypassAccountTrigger   = true;
        TriggerControl.BypassCancelledTrigger = true;

        Set<String> accountIds = new Set<String>();
        for (Account a : [SELECT Id FROM Account LIMIT 5]) { accountIds.add(a.Id); }

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new RestErrorMock());
        OIC_ManageSalesforceDataController.createAccount(accountIds);
        Test.stopTest();

        TriggerControl.BypassAccountTrigger   = false;
        TriggerControl.BypassCancelledTrigger = false;
    }

    @isTest
    public static void errorResponseBranch_ReceiptTest() {
        TriggerControl.BypassAccountTrigger   = true;
        TriggerControl.BypassCancelledTrigger = true;

        createReceiptsAndAllocation();

        Set<String> receiptIds = new Set<String>();
        for (Receipt__c r : [SELECT Id FROM Receipt__c WHERE SalesOrder__c != null]) {
            receiptIds.add(r.Id);
        }

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new RestErrorMock());
        OIC_ManageSalesforceDataController.createReceipt(receiptIds);
        Test.stopTest();

        TriggerControl.BypassAccountTrigger   = false;
        TriggerControl.BypassCancelledTrigger = false;
    }

    @isTest
    public static void errorResponseBranch_SalesOrderTest() {
        TriggerControl.BypassAccountTrigger   = true;
        TriggerControl.BypassCancelledTrigger = true;

        Set<String> salesOrderIds = new Set<String>();
        for (SalesOrder__c so : [SELECT Id FROM SalesOrder__c LIMIT 5]) {
            salesOrderIds.add(so.Id);
        }

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new RestErrorMock());
        OIC_ManageSalesforceDataController.createSalesOrderAndSOInstallments(salesOrderIds);
        Test.stopTest();

        TriggerControl.BypassAccountTrigger   = false;
        TriggerControl.BypassCancelledTrigger = false;
    }

    @isTest
    public static void errorResponseBranch_InstallmentTest() {
        TriggerControl.BypassAccountTrigger   = true;
        TriggerControl.BypassCancelledTrigger = true;

        Set<String> invoiceIds = new Set<String>();
        for (Invoice__c inv : [
            SELECT Id FROM Invoice__c WHERE Is_ADM_Fees_and_Dari_charges__c = false
        ]) { invoiceIds.add(inv.Id); }

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new RestErrorMock());
        OIC_ManageSalesforceDataController.createInstallment(invoiceIds);
        Test.stopTest();

        TriggerControl.BypassAccountTrigger   = false;
        TriggerControl.BypassCancelledTrigger = false;
    }

    @isTest
    public static void errorResponseBranch_CreditReceiptTest() {
        TriggerControl.BypassAccountTrigger   = true;
        TriggerControl.BypassCancelledTrigger = true;

        createReceiptsAndAllocation();

        Set<String> receiptIds = new Set<String>();
        for (Receipt__c r : [SELECT Id FROM Receipt__c WHERE SalesOrder__c != null]) {
            receiptIds.add(r.Id);
        }

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new RestErrorMock());
        OIC_ManageSalesforceDataController.createCreditReceipt(receiptIds);
        Test.stopTest();

        TriggerControl.BypassAccountTrigger   = false;
        TriggerControl.BypassCancelledTrigger = false;
    }

    // ── NEW TESTS — COVERAGE UPLIFT ───────────────────────────────────────────

    @isTest
    public static void createProjectSuccessTest() {
        TriggerControl.BypassAccountTrigger   = true;
        TriggerControl.BypassCancelledTrigger = true;

        Project__c proj = [SELECT Id FROM Project__c LIMIT 1];

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new RestProjectMock(proj.Id));
        OIC_ManageSalesforceDataController.createProject(new Set<Id>{ proj.Id });
        Test.stopTest();

        TriggerControl.BypassAccountTrigger   = false;
        TriggerControl.BypassCancelledTrigger = false;

    }

    @isTest
    public static void createProjectErrorTest() {
        TriggerControl.BypassAccountTrigger   = true;
        TriggerControl.BypassCancelledTrigger = true;

        Project__c proj = [SELECT Id FROM Project__c LIMIT 1];

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new RestErrorMock());
        OIC_ManageSalesforceDataController.createProject(new Set<Id>{ proj.Id });
        Test.stopTest();

        TriggerControl.BypassAccountTrigger   = false;
        TriggerControl.BypassCancelledTrigger = false;

    }

    @isTest
    public static void createProjectNullErrorMsgTest() {
        TriggerControl.BypassAccountTrigger   = true;
        TriggerControl.BypassCancelledTrigger = true;

        Project__c proj = [SELECT Id FROM Project__c LIMIT 1];

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new RestProjectNullErrorMock(proj.Id));
        OIC_ManageSalesforceDataController.createProject(new Set<Id>{ proj.Id });
        Test.stopTest();

        TriggerControl.BypassAccountTrigger   = false;
        TriggerControl.BypassCancelledTrigger = false;

    }

    @isTest
    public static void createProjectEmptySetTest() {
        TriggerControl.BypassAccountTrigger   = true;
        TriggerControl.BypassCancelledTrigger = true;

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new RestMock());
        OIC_ManageSalesforceDataController.createProject(new Set<Id>());
        Test.stopTest();

        TriggerControl.BypassAccountTrigger   = false;
        TriggerControl.BypassCancelledTrigger = false;
    }

    @isTest
    public static void createUnAppliedAllocationSuccessTest() {
        TriggerControl.BypassAccountTrigger   = true;
        TriggerControl.BypassCancelledTrigger = true;

        createReceiptsAndAllocation();

        Set<String> allocationIds = new Set<String>();
        for (Allocation__c a : [SELECT Id FROM Allocation__c]) { allocationIds.add(a.Id); }

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new RestMock());
        OIC_ManageSalesforceDataController.createUnAppliedAllocation(allocationIds);
        Test.stopTest();

        TriggerControl.BypassAccountTrigger   = false;
        TriggerControl.BypassCancelledTrigger = false;
    }

    @isTest
    public static void createUnAppliedAllocationErrorTest() {
        TriggerControl.BypassAccountTrigger   = true;
        TriggerControl.BypassCancelledTrigger = true;

        createReceiptsAndAllocation();

        Set<String> allocationIds = new Set<String>();
        for (Allocation__c a : [SELECT Id FROM Allocation__c]) { allocationIds.add(a.Id); }

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new RestErrorMock());
        OIC_ManageSalesforceDataController.createUnAppliedAllocation(allocationIds);
        Test.stopTest();

        TriggerControl.BypassAccountTrigger   = false;
        TriggerControl.BypassCancelledTrigger = false;
    }

    @isTest
    public static void createUnAppliedAllocationEmptyTest() {
        TriggerControl.BypassAccountTrigger   = true;
        TriggerControl.BypassCancelledTrigger = true;

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new RestMock());
        OIC_ManageSalesforceDataController.createUnAppliedAllocation(new Set<String>());
        Test.stopTest();

        TriggerControl.BypassAccountTrigger   = false;
        TriggerControl.BypassCancelledTrigger = false;
    }

    @isTest
    public static void loadErrorMsgMap_DirectTest() {
        TriggerControl.BypassAccountTrigger   = true;
        TriggerControl.BypassCancelledTrigger = true;

        Test.startTest();
        Map<String,String> result = OIC_ManageSalesforceDataController.loadErrorMsgMap();
        Test.stopTest();

        TriggerControl.BypassAccountTrigger   = false;
        TriggerControl.BypassCancelledTrigger = false;
    }

    @isTest
    public static void resolveErrMsg_UnknownTest() {
        TriggerControl.BypassAccountTrigger   = true;
        TriggerControl.BypassCancelledTrigger = true;

        Test.startTest();
        String result = OIC_ManageSalesforceDataController.resolveErrMsg(
            'Unknown integration error', new Map<String,String>()
        );
        Test.stopTest();

        TriggerControl.BypassAccountTrigger   = false;
        TriggerControl.BypassCancelledTrigger = false;
        
    }

    @isTest
    public static void resolveErrMsg_NullUserMsgTest() {
        TriggerControl.BypassAccountTrigger   = true;
        TriggerControl.BypassCancelledTrigger = true;

        Test.startTest();
        String result = OIC_ManageSalesforceDataController.resolveErrMsg(
            'Some unmapped system error', new Map<String,String>()
        );
        Test.stopTest();

        TriggerControl.BypassAccountTrigger   = false;
        TriggerControl.BypassCancelledTrigger = false;
    }

    @isTest
    public static void resolveErrMsg_KnownMappedMsgTest() {
        TriggerControl.BypassAccountTrigger   = true;
        TriggerControl.BypassCancelledTrigger = true;

        Map<String,String> errMap = new Map<String,String>{ 'Mapped system error' => 'Friendly user message' };

        Test.startTest();
        String result = OIC_ManageSalesforceDataController.resolveErrMsg('Mapped system error', errMap);
        Test.stopTest();

        TriggerControl.BypassAccountTrigger   = false;
        TriggerControl.BypassCancelledTrigger = false;
        
    }

    @isTest
    public static void loadRetryMap_WithIdsTest() {
        TriggerControl.BypassAccountTrigger   = true;
        TriggerControl.BypassCancelledTrigger = true;

        SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];
        so.OICNoOfRetries__c = 2;
        update so;

        Test.startTest();
        Map<String,Integer> result = OIC_ManageSalesforceDataController.loadRetryMap(
            'SalesOrder__c', new Set<String>{ so.Id }
        );
        Test.stopTest();

        TriggerControl.BypassAccountTrigger   = false;
        TriggerControl.BypassCancelledTrigger = false;
    }

    @isTest
    public static void loadRetryMap_EmptyIdsTest() {
        TriggerControl.BypassAccountTrigger   = true;
        TriggerControl.BypassCancelledTrigger = true;

        Test.startTest();
        Map<String,Integer> result = OIC_ManageSalesforceDataController.loadRetryMap(
            'SalesOrder__c', new Set<String>()
        );
        Test.stopTest();

        TriggerControl.BypassAccountTrigger   = false;
        TriggerControl.BypassCancelledTrigger = false;
     
    }

    @isTest
    public static void loadRetryMap_NullIdsTest() {
        TriggerControl.BypassAccountTrigger   = true;
        TriggerControl.BypassCancelledTrigger = true;

        Test.startTest();
        Map<String,Integer> result = OIC_ManageSalesforceDataController.loadRetryMap(
            'SalesOrder__c', null
        );
        Test.stopTest();

        TriggerControl.BypassAccountTrigger   = false;
        TriggerControl.BypassCancelledTrigger = false;
    }

    @isTest
    public static void nextRetry_WithExistingCountTest() {
        TriggerControl.BypassAccountTrigger   = true;
        TriggerControl.BypassCancelledTrigger = true;

        Test.startTest();
        Integer result = OIC_ManageSalesforceDataController.nextRetry(
            new Map<String,Integer>{ 'abc123' => 3 }, 'abc123'
        );
        Test.stopTest();

        TriggerControl.BypassAccountTrigger   = false;
        TriggerControl.BypassCancelledTrigger = false;
    }

    @isTest
    public static void nextRetry_WithMissingKeyTest() {
        TriggerControl.BypassAccountTrigger   = true;
        TriggerControl.BypassCancelledTrigger = true;

        Test.startTest();
        Integer result = OIC_ManageSalesforceDataController.nextRetry(
            new Map<String,Integer>(), 'notfound'
        );
        Test.stopTest();

        TriggerControl.BypassAccountTrigger   = false;
        TriggerControl.BypassCancelledTrigger = false;
    }

    @isTest
    public static void nextRetry_WithNullMapTest() {
        TriggerControl.BypassAccountTrigger   = true;
        TriggerControl.BypassCancelledTrigger = true;

        Test.startTest();
        Integer result = OIC_ManageSalesforceDataController.nextRetry(null, 'anysfid');
        Test.stopTest();

        TriggerControl.BypassAccountTrigger   = false;
        TriggerControl.BypassCancelledTrigger = false;
    }

    @isTest
    public static void logOICError_DirectTest() {
        TriggerControl.BypassAccountTrigger   = true;
        TriggerControl.BypassCancelledTrigger = true;

        Test.startTest();
        OIC_ManageSalesforceDataController.logOICError(
            'Test Process', 'TestClass', 'testMethod',
            '{"request":"data"}', '{"response":"data"}',
            'SFID-001', 'Test OIC error', 500, 'Internal Server Error'
        );
        Test.stopTest();

        TriggerControl.BypassAccountTrigger   = false;
        TriggerControl.BypassCancelledTrigger = false;
    }

    @isTest
    public static void createReceipt_KnownErrorMsgTest() {
        TriggerControl.BypassAccountTrigger   = true;
        TriggerControl.BypassCancelledTrigger = true;

        createReceiptsAndAllocation();
        Receipt__c rec = [SELECT Id FROM Receipt__c WHERE SalesOrder__c != null LIMIT 1];

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new RestKnownErrorMock(rec.Id));
        OIC_ManageSalesforceDataController.createReceipt(new Set<String>{ rec.Id });
        Test.stopTest();

        TriggerControl.BypassAccountTrigger   = false;
        TriggerControl.BypassCancelledTrigger = false;
    }

    @isTest
    public static void createInstallment_AdmInvoiceTest() {
        TriggerControl.BypassAccountTrigger   = true;
        TriggerControl.BypassCancelledTrigger = true;

        Set<String> invoiceIdSet = new Set<String>();
        for (Invoice__c inv : [
            SELECT Id FROM Invoice__c WHERE Is_ADM_Fees_and_Dari_charges__c = true LIMIT 1
        ]) { invoiceIdSet.add(inv.Id); }

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new RestMock());
        OIC_ManageSalesforceDataController.createInstallment(invoiceIdSet);
        Test.stopTest();

        TriggerControl.BypassAccountTrigger   = false;
        TriggerControl.BypassCancelledTrigger = false;
    }

    @isTest
    public static void createSalesOrderAndSOInstallments_EmptyTest() {
        TriggerControl.BypassAccountTrigger   = true;
        TriggerControl.BypassCancelledTrigger = true;

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new RestMock());
        OIC_ManageSalesforceDataController.createSalesOrderAndSOInstallments(new Set<String>());
        Test.stopTest();

        TriggerControl.BypassAccountTrigger   = false;
        TriggerControl.BypassCancelledTrigger = false;
    }

    @isTest
    public static void createCreditReceipt_ErrorTest() {
        TriggerControl.BypassAccountTrigger   = true;
        TriggerControl.BypassCancelledTrigger = true;

        createReceiptsAndAllocation();

        Set<String> receiptIds = new Set<String>();
        for (Receipt__c r : [SELECT Id FROM Receipt__c WHERE SalesOrder__c != null]) {
            receiptIds.add(r.Id);
        }

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new RestErrorMock());
        OIC_ManageSalesforceDataController.createCreditReceipt(receiptIds);
        Test.stopTest();

        TriggerControl.BypassAccountTrigger   = false;
        TriggerControl.BypassCancelledTrigger = false;
    }

    @isTest
    public static void updateUnitStatus_EmptySetTest() {
        TriggerControl.BypassAccountTrigger   = true;
        TriggerControl.BypassCancelledTrigger = true;

        Test.setMock(HttpCalloutMock.class, new RestMock());
        Test.startTest();
        OIC_ManageSalesforceDataController.updateUnitStatus(new Set<String>());
        Test.stopTest();

        TriggerControl.BypassAccountTrigger   = false;
        TriggerControl.BypassCancelledTrigger = false;
    }
     private class RestAccMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            OIC_RequestWrapperController.OICResponseWrapperList responseWrapperList = new OIC_RequestWrapperController.OICResponseWrapperList();
            OIC_RequestWrapperController.OICResponseWrapper responseWrapper = new OIC_RequestWrapperController.OICResponseWrapper();
            Account rec = [Select Id From Account LIMIT 1];
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
    private class RestreceiptMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            OIC_RequestWrapperController.OICResponseWrapperList responseWrapperList = new OIC_RequestWrapperController.OICResponseWrapperList();
            OIC_RequestWrapperController.OICResponseWrapper responseWrapper = new OIC_RequestWrapperController.OICResponseWrapper();
            Receipt__c rec = [Select Id From Receipt__c LIMIT 1];
            responseWrapper.Sfid = rec.Id;
            responseWrapper.Status = 'S';
            responseWrapper.ErrorMsg = 'Success';
            responseWrapper.OracleId = 'R21234';
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
    public static void createInstallment_NonSOI_CustomerRefundDebitMemoTest() {
        TriggerControl.BypassAccountTrigger   = true;
        TriggerControl.BypassCancelledTrigger = true;

        Account acc = [SELECT Id FROM Account LIMIT 1];
        acc.Bank_Account_Number__c = 'ACC-REFUND-002';
        acc.IBAN_Number__c         = 'AE070331234567890188888';
        acc.Swift_Code__c          = 'SWFTREF2';
        acc.Bank_Name__c           = 'Refund Test Bank 2';
        acc.Beneficiary_Name__c    = 'Refund Beneficiary 2';
        update acc;

        SalesOrder__c so = [SELECT Id FROM SalesOrder__c WHERE Status__c = 'In Progress' LIMIT 1];
        Id debitMemoRtId = [SELECT Id FROM RecordType WHERE SObjectType = 'Invoice__c' AND DeveloperName = 'Debit_Memo' LIMIT 1].Id;

        Invoice__c nonSoiRefundInv               = new Invoice__c();
        nonSoiRefundInv.RecordTypeId             = debitMemoRtId;
        nonSoiRefundInv.Sales_Order__c           = so.Id; // no SalesOrderInstallment__c -> usesSOI = false
        nonSoiRefundInv.Account__c               = acc.Id;
        nonSoiRefundInv.InvoiceAmount__c         = 500;
        nonSoiRefundInv.Ebs_Invoice_Date__c      = System.today();
        nonSoiRefundInv.InvoiceDate__c           = System.today();
        nonSoiRefundInv.Transaction_Type__c      = 'Customer Refund';
        nonSoiRefundInv.RefundOracleid__c        = 'REF-ORACLE-002';
        insert nonSoiRefundInv;

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new RestInvMock());
        OIC_ManageSalesforceDataController.createInstallment(new Set<String>{ nonSoiRefundInv.Id });
        Test.stopTest();

        TriggerControl.BypassAccountTrigger   = false;
        TriggerControl.BypassCancelledTrigger = false;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // ADVANCE TAX CANCELLATION COVERAGE
    //   createInstallment() -> OIC_AdvanceTaxCancellationService.cancelAdvanceTaxInvoices()
    //   The service makes a plain-JSON callout (no Base64 envelope); createInstallment
    //   then makes the Base64 installment callout. AdvTaxAndInstallmentMock serves both:
    //   requests carrying "Base64RequestPayload" are the installment callout, everything
    //   else is the Advance Tax cancellation callout.
    // ─────────────────────────────────────────────────────────────────────────

    /** Creates an Advance Tax Invoice raised against the given installment Invoice. */
    private static Invoice__c createAdvanceTaxInvoice(Id installmentInvoiceId, Id accountId) {
        Invoice__c advTax               = new Invoice__c();
        advTax.Transaction_Type__c      = 'Advance Tax';
        advTax.Invoice_Advance__c       = installmentInvoiceId;
        advTax.Account__c               = accountId;
        advTax.InvoiceAmount__c         = 100;
        advTax.InvoiceDate__c           = System.today();
        advTax.Ebs_Invoice_Date__c      = System.today();
        advTax.OraclePartyId__c         = 'ADV-ORA-1';
        advTax.IsCancelled__c           = false;
        insert advTax;
        return advTax;
    }

    /** Pulls every "Sfid" value out of an arbitrary JSON string (case-insensitive key). */
    private static Set<String> extractSfids(String jsonBody) {
        Set<String> sfids = new Set<String>();
        if (String.isBlank(jsonBody)) return sfids;
        try {
            walkForSfid(JSON.deserializeUntyped(jsonBody), sfids);
        } catch (Exception ex) {}
        return sfids;
    }

    private static void walkForSfid(Object obj, Set<String> sfids) {
        if (obj == null) return;
        if (obj instanceof Map<String, Object>) {
            Map<String, Object> m = (Map<String, Object>) obj;
            for (String key : m.keySet()) {
                if (key != null && key.equalsIgnoreCase('sfid') && m.get(key) != null) {
                    sfids.add(String.valueOf(m.get(key)));
                } else {
                    walkForSfid(m.get(key), sfids);
                }
            }
        } else if (obj instanceof List<Object>) {
            for (Object item : (List<Object>) obj) walkForSfid(item, sfids);
        }
    }

    /**
     * Dual mock: Advance Tax cancellation (plain JSON) + installment (Base64) callouts.
     *  mode = 'NORMAL' -> echo every requested Sfid with `status`
     *  mode = 'EMPTY'  -> ResponseArray = [] for the cancellation callout
     *  mode = 'THROW'  -> the cancellation callout throws
     *  mode = 'BOGUS'  -> cancellation ResponseArray answers for an unrelated Sfid only
     */
    private class AdvTaxAndInstallmentMock implements HttpCalloutMock {
        private String status;
        private String errorMsg;
        private String mode;
        private Id     bogusSfid;

        AdvTaxAndInstallmentMock(String status, String errorMsg, String mode, Id bogusSfid) {
            this.status    = status;
            this.errorMsg  = errorMsg;
            this.mode      = mode;
            this.bogusSfid = bogusSfid;
        }

        public HTTPResponse respond(HTTPRequest req) {
            String body = req.getBody();
            Boolean isInstallmentCallout = body != null && body.contains('Base64RequestPayload');

            if (isInstallmentCallout) return installmentResponse(body);

            if (mode == 'THROW') {
                CalloutException e = new CalloutException();
                e.setMessage('Simulated Advance Tax cancellation callout failure');
                throw e;
            }

            OIC_RequestWrapperController.OICResponseWrapperList wl =
                new OIC_RequestWrapperController.OICResponseWrapperList();
            wl.ResponseArray = new List<OIC_RequestWrapperController.OICResponseWrapper>();

            if (mode == 'NORMAL') {
                for (String sfid : extractSfids(body)) {
                    wl.ResponseArray.add(buildRow(sfid, status, errorMsg));
                }
            } else if (mode == 'BOGUS' && bogusSfid != null) {
                wl.ResponseArray.add(buildRow(bogusSfid, 'S', null));
            }
            // mode == 'EMPTY' -> ResponseArray stays empty

            HTTPResponse res = new HTTPResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody(JSON.serialize(wl));   // plain JSON — service deserializes the body directly
            res.setStatusCode(200);
            res.setStatus('OK');
            return res;
        }

        private OIC_RequestWrapperController.OICResponseWrapper buildRow(Id sfid, String st, String err) {
            OIC_RequestWrapperController.OICResponseWrapper rw =
                new OIC_RequestWrapperController.OICResponseWrapper();
            rw.Sfid     = sfid;
            rw.Status   = st;
            rw.ErrorMsg = err;
            rw.OracleId = (st == 'S') ? 'CM-' + String.valueOf(sfid).right(6) : null;
            return rw;
        }

        private HTTPResponse installmentResponse(String requestBody) {
            OIC_RequestWrapperController.OICResponseWrapperList wl =
                new OIC_RequestWrapperController.OICResponseWrapperList();
            wl.ResponseArray = new List<OIC_RequestWrapperController.OICResponseWrapper>();

            Set<String> sfids = new Set<String>();
            try {
                Map<String, Object> bodyMap =
                    (Map<String, Object>) JSON.deserializeUntyped(requestBody);
                String b64 = (String) bodyMap.get('Base64RequestPayload');
                if (String.isNotBlank(b64)) {
                    sfids = extractSfids(EncodingUtil.base64Decode(b64).toString());
                }
            } catch (Exception ex) {}

            if (sfids.isEmpty()) sfids.add([SELECT Id FROM Invoice__c LIMIT 1].Id);

            for (String sfid : sfids) {
                OIC_RequestWrapperController.OICResponseWrapper rw =
                    new OIC_RequestWrapperController.OICResponseWrapper();
                rw.Sfid = sfid; rw.Status = 'S'; rw.ErrorMsg = null; rw.OracleId = '99887766';
                wl.ResponseArray.add(rw);
            }

            OIC_RequestWrapperController.Base64ResponseWrapper b64Resp =
                new OIC_RequestWrapperController.Base64ResponseWrapper();
            b64Resp.Base64Response = EncodingUtil.base64Encode(Blob.valueOf(JSON.serialize(wl)));

            HTTPResponse res = new HTTPResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody(JSON.serialize(b64Resp));
            res.setStatusCode(200);
            res.setStatus('OK');
            return res;
        }
    }

    // ── createInstallment() with a successful Advance Tax cancellation ───────────
    @isTest
    public static void createInstallment_AdvTaxCancellationSuccessTest() {
        TriggerControl.BypassAccountTrigger   = true;
        TriggerControl.BypassCancelledTrigger = true;

        Account acc = [SELECT Id FROM Account LIMIT 1];
        Invoice__c installmentInv = [
            SELECT Id FROM Invoice__c WHERE Is_ADM_Fees_and_Dari_charges__c = false LIMIT 1
        ];
        Invoice__c advTax = createAdvanceTaxInvoice(installmentInv.Id, acc.Id);

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new AdvTaxAndInstallmentMock('S', null, 'NORMAL', null));
        OIC_ManageSalesforceDataController.createInstallment(new Set<String>{ installmentInv.Id });
        Test.stopTest();

        Invoice__c reloaded = [SELECT Id, IsCancelled__c, OICIntegrationStatus__c FROM Invoice__c WHERE Id = :advTax.Id];
        System.assertEquals(true, reloaded.IsCancelled__c, 'Advance Tax Invoice should be marked cancelled on a successful cancellation');

        TriggerControl.BypassAccountTrigger   = false;
        TriggerControl.BypassCancelledTrigger = false;
    }

    // ── createInstallment() with a failed Advance Tax cancellation -> installment held back ──
    @isTest
    public static void createInstallment_AdvTaxCancellationErrorTest() {
        TriggerControl.BypassAccountTrigger   = true;
        TriggerControl.BypassCancelledTrigger = true;

        Account acc = [SELECT Id FROM Account LIMIT 1];
        Invoice__c installmentInv = [
            SELECT Id FROM Invoice__c WHERE Is_ADM_Fees_and_Dari_charges__c = false LIMIT 1
        ];
        Invoice__c advTax = createAdvanceTaxInvoice(installmentInv.Id, acc.Id);

        Test.startTest();
        Test.setMock(HttpCalloutMock.class,
            new AdvTaxAndInstallmentMock('E', 'Unknown integration error', 'NORMAL', null));
        OIC_ManageSalesforceDataController.createInstallment(new Set<String>{ installmentInv.Id });
        Test.stopTest();

        Invoice__c reloaded = [SELECT Id, IsCancelled__c, OICIntegrationStatus__c FROM Invoice__c WHERE Id = :advTax.Id];
        System.assertEquals(false, reloaded.IsCancelled__c, 'Advance Tax Invoice must not be cancelled when Oracle returned an error');
        System.assertEquals('E', reloaded.OICIntegrationStatus__c, 'Advance Tax Invoice should carry the error status');

        TriggerControl.BypassAccountTrigger   = false;
        TriggerControl.BypassCancelledTrigger = false;
    }

    // ── createInstallment() when the cancellation callout returns nothing ───────
    @isTest
    public static void createInstallment_AdvTaxCancellationEmptyResponseTest() {
        TriggerControl.BypassAccountTrigger   = true;
        TriggerControl.BypassCancelledTrigger = true;

        Account acc = [SELECT Id FROM Account LIMIT 1];
        Invoice__c installmentInv = [
            SELECT Id FROM Invoice__c WHERE Is_ADM_Fees_and_Dari_charges__c = false LIMIT 1
        ];
        createAdvanceTaxInvoice(installmentInv.Id, acc.Id);

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new AdvTaxAndInstallmentMock(null, null, 'EMPTY', null));
        OIC_ManageSalesforceDataController.createInstallment(new Set<String>{ installmentInv.Id });
        Test.stopTest();

        System.assert(true, 'Empty cancellation response should be handled without an unhandled exception');

        TriggerControl.BypassAccountTrigger   = false;
        TriggerControl.BypassCancelledTrigger = false;
    }

    // ── cancelAdvanceTaxInvoices(): no installment Ids -> empty result, no callout ──
    @isTest
    public static void cancelAdvanceTaxInvoices_NullAndEmptyTest() {
        TriggerControl.BypassAccountTrigger   = true;
        TriggerControl.BypassCancelledTrigger = true;

        Test.startTest();
        OIC_AdvanceTaxCancellationService.CancellationResult r1 =
            OIC_AdvanceTaxCancellationService.cancelAdvanceTaxInvoices(null);
        OIC_AdvanceTaxCancellationService.CancellationResult r2 =
            OIC_AdvanceTaxCancellationService.cancelAdvanceTaxInvoices(new Set<String>());
        r1.commitStagedWork();
        Test.stopTest();

        System.assertEquals(true, r1.isEmpty(), 'Null installment Ids must produce an empty result');
        System.assertEquals(true, r2.isEmpty(), 'Empty installment Ids must produce an empty result');

        TriggerControl.BypassAccountTrigger   = false;
        TriggerControl.BypassCancelledTrigger = false;
    }

    // ── cancelAdvanceTaxInvoices(): success path, staged work commits ──────────
    @isTest
    public static void cancelAdvanceTaxInvoices_SuccessDirectTest() {
        TriggerControl.BypassAccountTrigger   = true;
        TriggerControl.BypassCancelledTrigger = true;

        Account acc = [SELECT Id FROM Account LIMIT 1];
        Invoice__c installmentInv = [
            SELECT Id FROM Invoice__c WHERE Is_ADM_Fees_and_Dari_charges__c = false LIMIT 1
        ];
        Invoice__c advTax = createAdvanceTaxInvoice(installmentInv.Id, acc.Id);

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new AdvTaxAndInstallmentMock('S', null, 'NORMAL', null));
        OIC_AdvanceTaxCancellationService.CancellationResult result =
            OIC_AdvanceTaxCancellationService.cancelAdvanceTaxInvoices(new Set<String>{ installmentInv.Id });
        result.commitStagedWork();
        Test.stopTest();

        System.assertEquals(true, result.blockedInstallmentIds.isEmpty(), 'A successful cancellation blocks nothing');
        System.assertEquals(false, result.isEmpty(), 'A cancellation was performed, so the result is not empty');

        Invoice__c reloaded = [SELECT Id, IsCancelled__c FROM Invoice__c WHERE Id = :advTax.Id];
        System.assertEquals(true, reloaded.IsCancelled__c, 'Staged Invoice update should commit IsCancelled__c = true');

        TriggerControl.BypassAccountTrigger   = false;
        TriggerControl.BypassCancelledTrigger = false;
    }

    // ── cancelAdvanceTaxInvoices(): mapped (non-"Unknown") error message branch ──
    @isTest
    public static void cancelAdvanceTaxInvoices_KnownErrorDirectTest() {
        TriggerControl.BypassAccountTrigger   = true;
        TriggerControl.BypassCancelledTrigger = true;

        Account acc = [SELECT Id FROM Account LIMIT 1];
        Invoice__c installmentInv = [
            SELECT Id FROM Invoice__c WHERE Is_ADM_Fees_and_Dari_charges__c = false LIMIT 1
        ];
        createAdvanceTaxInvoice(installmentInv.Id, acc.Id);

        Test.startTest();
        Test.setMock(HttpCalloutMock.class,
            new AdvTaxAndInstallmentMock('E', 'Some specific mapped error', 'NORMAL', null));
        OIC_AdvanceTaxCancellationService.CancellationResult result =
            OIC_AdvanceTaxCancellationService.cancelAdvanceTaxInvoices(new Set<String>{ installmentInv.Id });
        result.commitStagedWork();
        Test.stopTest();

        System.assertEquals(true, result.blockedInstallmentIds.contains(installmentInv.Id),
            'A failed cancellation must hold back its source installment');
        System.assert(!result.invoicesToUpdate.isEmpty(), 'The errored Advance Tax Invoice should still be staged for update');

        TriggerControl.BypassAccountTrigger   = false;
        TriggerControl.BypassCancelledTrigger = false;
    }

    // ── cancelAdvanceTaxInvoices(): callout throws -> every installment blocked ──
    @isTest
    public static void cancelAdvanceTaxInvoices_CalloutExceptionDirectTest() {
        TriggerControl.BypassAccountTrigger   = true;
        TriggerControl.BypassCancelledTrigger = true;

        Account acc = [SELECT Id FROM Account LIMIT 1];
        Invoice__c installmentInv = [
            SELECT Id FROM Invoice__c WHERE Is_ADM_Fees_and_Dari_charges__c = false LIMIT 1
        ];
        createAdvanceTaxInvoice(installmentInv.Id, acc.Id);

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new AdvTaxAndInstallmentMock(null, null, 'THROW', null));
        OIC_AdvanceTaxCancellationService.CancellationResult result =
            OIC_AdvanceTaxCancellationService.cancelAdvanceTaxInvoices(new Set<String>{ installmentInv.Id });
        result.commitStagedWork();
        Test.stopTest();

        System.assertEquals(true, result.blockedInstallmentIds.contains(installmentInv.Id),
            'A callout exception must block the installment');
        System.assertEquals(true, result.invoicesToUpdate.isEmpty(),
            'The exception path clears staged Invoice updates');

        TriggerControl.BypassAccountTrigger   = false;
        TriggerControl.BypassCancelledTrigger = false;
    }

    // ── cancelAdvanceTaxInvoices(): Oracle never answers for the Advance Tax Invoice ──
    @isTest
    public static void cancelAdvanceTaxInvoices_UnansweredInvoiceDirectTest() {
        TriggerControl.BypassAccountTrigger   = true;
        TriggerControl.BypassCancelledTrigger = true;

        Account acc = [SELECT Id FROM Account LIMIT 1];
        Invoice__c installmentInv = [
            SELECT Id FROM Invoice__c WHERE Is_ADM_Fees_and_Dari_charges__c = false LIMIT 1
        ];
        createAdvanceTaxInvoice(installmentInv.Id, acc.Id);

        Test.startTest();
        // Respond only for an unrelated Sfid so the real Advance Tax Invoice goes unanswered
        Test.setMock(HttpCalloutMock.class,
            new AdvTaxAndInstallmentMock('S', null, 'BOGUS', installmentInv.Id));
        OIC_AdvanceTaxCancellationService.CancellationResult result =
            OIC_AdvanceTaxCancellationService.cancelAdvanceTaxInvoices(new Set<String>{ installmentInv.Id });
        result.commitStagedWork();
        Test.stopTest();

        System.assertEquals(true, result.blockedInstallmentIds.contains(installmentInv.Id),
            'An Advance Tax Invoice Oracle never answered for must block its installment');

        TriggerControl.BypassAccountTrigger   = false;
        TriggerControl.BypassCancelledTrigger = false;
    }

    // ── CancellationResult.isEmpty() true + commitStagedWork() no-op ───────────
    @isTest
    public static void cancellationResult_EmptyStateTest() {
        Test.startTest();
        OIC_AdvanceTaxCancellationService.CancellationResult result =
            new OIC_AdvanceTaxCancellationService.CancellationResult();
        System.assertEquals(true, result.isEmpty(), 'A fresh CancellationResult is empty');
        result.commitStagedWork();
        Test.stopTest();
    }
}