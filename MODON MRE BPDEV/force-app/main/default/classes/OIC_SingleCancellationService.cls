public class OIC_SingleCancellationService {

    // =========================================================
    // MAIN METHOD
    // =========================================================
    public static HttpResponse sendCancellationRequest(
        Id salesOrderId,
        List<String> invoiceIds,
        List<String> receiptIds,
        List<String> allocationIds
    ) {

        CancellationRequestWrapper requestWrapper =
            buildCancellationRequest(salesOrderId, invoiceIds, receiptIds, allocationIds);

        String requestBody = JSON.serialize(requestWrapper);
        String base64Payload = EncodingUtil.base64Encode(Blob.valueOf(requestBody));

        OIC_RequestWrapperController.Base64Wrapper wrapper =
            new OIC_RequestWrapperController.Base64Wrapper();

        wrapper.Base64RequestPayload = base64Payload;

        HttpRequest req =
            OIC_CredentialsController.getCredentials('ModonFusionCancellationAPI');

        req.setTimeout(120000);
        req.setHeader('Accept', 'application/json');
        req.setBody(JSON.serialize(wrapper));

        return new Http().send(req);
    }

    // =========================================================
    // BUILD REQUEST (FULL BATCH-STYLE LOGIC)
    // =========================================================
    private static CancellationRequestWrapper buildCancellationRequest(
        Id salesOrderId,
        List<String> invoiceIds,
        List<String> receiptIds,
        List<String> allocationIds
    ) {

        CancellationRequestWrapper root = new CancellationRequestWrapper();
        root.RequestArray = new List<CancellationRequest>();

        // =====================================================
        // FETCH SALES ORDER (SINGLE QUERY)
        // =====================================================
        SalesOrder__c so = null;

        List<SalesOrder__c> soList = [
            SELECT Id, Name, Status__c, ProjectName__c,
                   CustAcctId__c,
                   OraclePartySiteID__c,
                   OracleCustAcctSiteID__c,
                   OracleSiteUseID__c,
                   Unit__r.Name,
                   Unit__r.PlotNo__c,
                   Unit__r.Phase__r.Name,
                   Unit__r.Phase__r.EntityName__c
            FROM SalesOrder__c
            WHERE Id = :salesOrderId
            LIMIT 1
        ];

        if (!soList.isEmpty()) {
            so = soList[0];
        }

        // =====================================================
        // HEADER (NULL SAFE IF SKIPPED OR NOT FOUND)
        // =====================================================
        CancellationRequest req = new CancellationRequest();

        req.sfSrID      = (so != null ? so.Id : null);
        req.sfSoId      = (so != null ? so.Id : null);
        req.EntityName  = (so != null ? so.Unit__r.Phase__r.EntityName__c : null);
        req.ProjectName = (so != null ? so.ProjectName__c : null);
        req.srType      = 'Cancellation';
        req.srStatus    = (so != null ? so.Status__c : null);

        // HEADER EXTRA INFO (NEVER REMOVE)
        req.ExtraInfo1 = (so != null ? so.Unit__r.Name : null);
        req.ExtraInfo2 = (so != null ? so.Unit__r.PlotNo__c : null);
        req.ExtraInfo3 = (so != null ? so.Unit__r.Phase__r.Name : null);
        req.ExtraInfo4 = (so != null ? so.CustAcctId__c : null);
        req.ExtraInfo5 = (so != null ? so.OraclePartySiteID__c : null);

        // =====================================================
        // ALWAYS INITIALIZE ARRAYS (OIC CONTRACT SAFETY)
        // =====================================================
        req.InstallmentArray = new List<InstallmentNode>();
        req.ReceiptArray     = new List<ReceiptNode>();
        req.ChargesArray     = new List<ChargeNode>();

        // =====================================================
        // PRELOAD STATUS MAPS (FOR SKIP LOGIC)
        // =====================================================
        Map<Id, Invoice__c> invMap = new Map<Id, Invoice__c>();
        Map<Id, Receipt__c> rcptMap = new Map<Id, Receipt__c>();
        Map<Id, Allocation__c> allocMap = new Map<Id, Allocation__c>();

        if (invoiceIds != null && !invoiceIds.isEmpty()) {
            invMap = new Map<Id, Invoice__c>([
                SELECT Id, OICIntegrationStatus__c
                FROM Invoice__c
                WHERE Id IN :invoiceIds
            ]);
        }

        if (receiptIds != null && !receiptIds.isEmpty()) {
            rcptMap = new Map<Id, Receipt__c>([
                SELECT Id, OICIntegrationStatus__c
                FROM Receipt__c
                WHERE Id IN :receiptIds
            ]);
        }

        if (allocationIds != null && !allocationIds.isEmpty()) {
            allocMap = new Map<Id, Allocation__c>([
                SELECT Id, OICIntegrationStatus__c
                FROM Allocation__c
                WHERE Id IN :allocationIds
            ]);
        }

        // =====================================================
        // 1. INVOICES (CHARGES)
        // =====================================================
        if (invoiceIds != null) {

            for (String sId : invoiceIds) {

                Id invId = (Id)sId;
                Invoice__c old = invMap.get(invId);

                if (old != null &&
                    old.OICIntegrationStatus__c == 'Cancellation Success') {
                    continue;
                }

                Invoice__c inv = [
                    SELECT Id, Name, InvoiceAmount__c, InvoiceDate__c,
                           SalesOrderInstallment__c,
                           SalesOrderInstallment__r.SalesOrder__c,
                           SalesOrderInstallment__r.SalesOrder__r.Unit__r.Name,
                           SalesOrderInstallment__r.SalesOrder__r.Unit__r.PlotNo__c
                    FROM Invoice__c
                    WHERE Id = :invId
                    LIMIT 1
                ];

                ChargeNode c = new ChargeNode();
                c.Sfid        = inv.Id;
                c.SoSfid      = inv.SalesOrderInstallment__r.SalesOrder__c;
                c.SoIsfid     = inv.SalesOrderInstallment__c;
                c.Amount      = inv.InvoiceAmount__c;
                c.InvoiceDate = inv.InvoiceDate__c;
                c.Description = 'Installment Invoice';
                c.TrxnType    = 'INSTALLMENT';
                c.CreditMemoFlag = 'N';

                c.ExtraInfo1 = inv.SalesOrderInstallment__r.SalesOrder__r.Unit__r.Name;
                c.ExtraInfo2 = inv.SalesOrderInstallment__r.SalesOrder__r.Unit__r.PlotNo__c;
                c.ExtraInfo3 = '';
                c.ExtraInfo4 = '';
                c.ExtraInfo5 = '';

                req.ChargesArray.add(c);
            }
        }

        // =====================================================
        // 2. RECEIPTS
        // =====================================================
        if (receiptIds != null) {

            for (String sId : receiptIds) {

                Id rId = (Id)sId;
                Receipt__c old = rcptMap.get(rId);

                if (old != null &&
                    old.OICIntegrationStatus__c == 'Cancellation Success') {
                    continue;
                }

                Receipt__c r = [
                    SELECT Id, OraclePartyId__c, EBS_Clearing_Date__c
                    FROM Receipt__c
                    WHERE Id = :rId
                    LIMIT 1
                ];

                ReceiptNode rn = new ReceiptNode();
                rn.receiptSFID = r.Id;
                rn.receiptID   = r.OraclePartyId__c;
                rn.GLDate      = r.EBS_Clearing_Date__c;

                rn.ExtraInfo1 = r.OraclePartyId__c;
                rn.ExtraInfo2 = String.valueOf(r.EBS_Clearing_Date__c);
                rn.ExtraInfo3 = 'CANCELLATION';

                req.ReceiptArray.add(rn);
            }
        }

        // =====================================================
        // 3. ALLOCATIONS (SKIP ONLY, NO PAYLOAD GIVEN)
        // =====================================================
        if (allocationIds != null) {
            for (String sId : allocationIds) {

                Id aId = (Id)sId;
                Allocation__c old = allocMap.get(aId);

                if (old != null &&
                    old.OICIntegrationStatus__c == 'Cancellation Success') {
                    continue;
                }

                // No payload mapping provided (intentional)
            }
        }

        root.RequestArray.add(req);
        return root;
    }

    // =========================================================
    // BANK DATA / REFUND MEMO REQUEST  -- OIC_ManageBankDataBatch REQUEST
    // ---------------------------------------------------------
    // Migrated from OIC_ManageBankDataBatch -> OIC_ManageBankData.createRefundMemo().
    // That SR-flow batch class queried Invoice__c via Service_Request__c, which does
    // not exist for this standalone Business_Process__c cancellation flow, so the
    // query below is re-sourced entirely off Invoice__c's own lookups
    // (Account__c / SalesOrderInstallment__r.SalesOrder__r / Transfer_Sales_Order__r).
    // The outbound payload shape, wrapper classes (OIC_RequestWrapperController.BankData /
    // BankDataWrapperLst) and target endpoint ('ModonFusionUpdateInvoiceAPI') are kept
    // IDENTICAL to the original OIC_ManageBankDataBatch request so the Oracle Integration
    // team can keep identifying/handling this as the same "Bank Data / Refund Memo"
    // request type as before -- only the Apex origin has moved.
    //
    // KNOWN GAP (flagged for review): OIC_ManageBankData additionally attached a PDF
    // looked up via Documents__c ('Pre Unit Cancellation Approval Attatchment' / 'Bank
    // Details'), keyed by Documents__c.Service_Request__c. Documents__c has no
    // Business_Process__c lookup, so for this BP flow Invoice_pdf is left blank -- same
    // fallback the original class already used when no document/ContentVersion was found.
    // =========================================================
    public static HttpResponse sendBankDataRequest(Set<String> invoiceIds) {

        List<OIC_RequestWrapperController.BankData> bankDataList = buildBankDataRequest(invoiceIds);

        if (bankDataList.isEmpty()) {
            return null; // nothing refund-eligible to sync -- skip the callout entirely
        }

        OIC_RequestWrapperController.BankDataWrapperLst bankWrapList =
            new OIC_RequestWrapperController.BankDataWrapperLst();
        bankWrapList.RequestArray = bankDataList;

        String bankWrapString = JSON.serialize(bankWrapList);
        String base64Payload = EncodingUtil.base64Encode(Blob.valueOf(bankWrapString));

        // NOTE: this endpoint's envelope field is "Base64Request" (NOT "Base64RequestPayload"
        // used by sendCancellationRequest above) -- kept as its own wrapper, matching what
        // OIC_ManageBankData originally sent, to preserve that exact contract for Oracle.
        BankDataBase64Wrapper wrapper = new BankDataBase64Wrapper();
        wrapper.Base64Request = base64Payload;

        HttpRequest req = OIC_CredentialsController.getCredentials('ModonFusionUpdateInvoiceAPI');
        req.setTimeout(120000);
        req.setBody(JSON.serialize(wrapper));

        return new Http().send(req);
    }

    // -- OIC_ManageBankDataBatch REQUEST: builds the same BankData payload OIC_ManageBankData
    //    used to build, re-sourced off Invoice__c directly (see gap note above).
    private static List<OIC_RequestWrapperController.BankData> buildBankDataRequest(Set<String> invoiceIds) {

        List<OIC_RequestWrapperController.BankData> bankDataList = new List<OIC_RequestWrapperController.BankData>();

        if (invoiceIds == null || invoiceIds.isEmpty()) {
            return bankDataList;
        }

        List<Invoice__c> lst_Invoice = [
            SELECT Id, Name, OraclePartyId__c, Transaction_Type__c, Account__c,
                   Account__r.Bank_Account_Number__c, Account__r.Bank_Branch_Name__c,
                   Account__r.Bank_Country__c, Account__r.Bank_Name__c, Account__r.Swift_Code__c,
                   Account__r.IBAN_Number__c,
                   SalesOrderInstallment__r.SalesOrder__r.Unit__r.Name,
                   SalesOrderInstallment__r.SalesOrder__r.Unit__c,
                   SalesOrderInstallment__r.SalesOrder__r.Name,
                   SalesOrderInstallment__r.SalesOrder__r.CustAcctId__c,
                   SalesOrderInstallment__r.SalesOrder__r.OracleCustAcctSiteID__c,
                   SalesOrderInstallment__r.SalesOrder__r.OraclePartySiteID__c,
                   SalesOrderInstallment__r.SalesOrder__r.OracleSiteUseID__c,
                   SalesOrderInstallment__r.SalesOrder__r.VirtualAccount__r.Name,
                   SalesOrderInstallment__r.SalesOrder__r.VirtualAccount__r.VirtualAccountNumber__c,
                   SalesOrderInstallment__r.SalesOrder__r.VirtualAccount__r.VirtualIBANNumber__c,
                   SalesOrderInstallment__r.SalesOrder__r.VirtualAccount__r.Swift_Code__c,
                   SalesOrderInstallment__r.SalesOrder__r.VirtualAccount__r.Escrow_Bank_Name__c,
                   Transfer_Sales_Order__c, Transfer_Sales_Order__r.Name,
                   Transfer_Sales_Order__r.CustAcctId__c, Transfer_Sales_Order__r.OracleCustAcctSiteID__c,
                   Transfer_Sales_Order__r.OraclePartySiteID__c, Transfer_Sales_Order__r.OracleSiteUseID__c,
                   Transfer_Sales_Order__r.VirtualAccount__r.Name,
                   Transfer_Sales_Order__r.VirtualAccount__r.VirtualAccountNumber__c,
                   Transfer_Sales_Order__r.VirtualAccount__r.VirtualIBANNumber__c,
                   Transfer_Sales_Order__r.VirtualAccount__r.Swift_Code__c,
                   Transfer_Sales_Order__r.VirtualAccount__r.Escrow_Bank_Name__c
            FROM Invoice__c
            WHERE Id IN :invoiceIds
              AND Account__c != null
              AND Transaction_Type__c IN ('Refund', 'Customer Refund')
        ];

        for (Invoice__c obj_Invoice : lst_Invoice) {
            OIC_RequestWrapperController.BankData bankDataObj = new OIC_RequestWrapperController.BankData();

            bankDataObj.SfReference = obj_Invoice.Name;
            bankDataObj.Invoice_pdf = ''; // see KNOWN GAP note above
            bankDataObj.Invoice_Id  = obj_Invoice.OraclePartyId__c;
            bankDataObj.UnitName    = obj_Invoice.SalesOrderInstallment__r.SalesOrder__r.Unit__r.Name;
            bankDataObj.Unit        = obj_Invoice.SalesOrderInstallment__r.SalesOrder__r.Unit__c;
            bankDataObj.Sfid        = obj_Invoice.Account__c;

            if (obj_Invoice.Transaction_Type__c == 'Customer Refund') {
                bankDataObj.BankAccountNumber = obj_Invoice.Account__r.Bank_Account_Number__c;
                bankDataObj.BankBranchName    = obj_Invoice.Account__r.Bank_Branch_Name__c;
                bankDataObj.BankName          = obj_Invoice.Account__r.Bank_Name__c;
                bankDataObj.IBANNumber        = obj_Invoice.Account__r.IBAN_Number__c;
                bankDataObj.SwiftCode         = obj_Invoice.Account__r.Swift_Code__c;

                bankDataObj.CancellationCustAcctId     = obj_Invoice.SalesOrderInstallment__r.SalesOrder__r.CustAcctId__c;
                bankDataObj.CancellationCustAcctSiteID = obj_Invoice.SalesOrderInstallment__r.SalesOrder__r.OracleCustAcctSiteID__c;
                bankDataObj.CancellationPartySiteID    = obj_Invoice.SalesOrderInstallment__r.SalesOrder__r.OraclePartySiteID__c;
                bankDataObj.CancellationSiteUseID      = obj_Invoice.SalesOrderInstallment__r.SalesOrder__r.OracleSiteUseID__c;
                bankDataObj.CancellationSalesOrder     = obj_Invoice.SalesOrderInstallment__r.SalesOrder__r.Name;
            } else {
                bankDataObj.CancellationVirtualAccountNumber = obj_Invoice.SalesOrderInstallment__r.SalesOrder__r.VirtualAccount__r.VirtualAccountNumber__c;
                bankDataObj.CancellationVirtualAccountName   = obj_Invoice.SalesOrderInstallment__r.SalesOrder__r.VirtualAccount__r.Name;
                bankDataObj.CancellationVirtualIBANNumber    = obj_Invoice.SalesOrderInstallment__r.SalesOrder__r.VirtualAccount__r.VirtualIBANNumber__c;
                bankDataObj.CancellationSwiftCode            = obj_Invoice.SalesOrderInstallment__r.SalesOrder__r.VirtualAccount__r.Swift_Code__c;
                bankDataObj.CancellationVirtualBankName      = obj_Invoice.SalesOrderInstallment__r.SalesOrder__r.VirtualAccount__r.Escrow_Bank_Name__c;

                bankDataObj.TransferVirtualAccountNumber = obj_Invoice.Transfer_Sales_Order__r.VirtualAccount__r.VirtualAccountNumber__c;
                bankDataObj.TransferVirtualAccountName   = obj_Invoice.Transfer_Sales_Order__r.VirtualAccount__r.Name;
                bankDataObj.TransferVirtualIBANNumber    = obj_Invoice.Transfer_Sales_Order__r.VirtualAccount__r.VirtualIBANNumber__c;
                bankDataObj.TransferSwiftCode            = obj_Invoice.Transfer_Sales_Order__r.VirtualAccount__r.Swift_Code__c;
                bankDataObj.TransferVirtualBankName      = obj_Invoice.Transfer_Sales_Order__r.VirtualAccount__r.Escrow_Bank_Name__c;
                bankDataObj.TransferCustAcctId           = obj_Invoice.Transfer_Sales_Order__r.CustAcctId__c;
                bankDataObj.TransferCustAcctSiteID       = obj_Invoice.Transfer_Sales_Order__r.OracleCustAcctSiteID__c;
                bankDataObj.TransferPartySiteID          = obj_Invoice.Transfer_Sales_Order__r.OraclePartySiteID__c;
                bankDataObj.TransferSiteUseID            = obj_Invoice.Transfer_Sales_Order__r.OracleSiteUseID__c;
                bankDataObj.TransferSalesOrder           = obj_Invoice.Transfer_Sales_Order__r.Name;

                bankDataObj.CancellationCustAcctId     = obj_Invoice.SalesOrderInstallment__r.SalesOrder__r.CustAcctId__c;
                bankDataObj.CancellationCustAcctSiteID = obj_Invoice.SalesOrderInstallment__r.SalesOrder__r.OracleCustAcctSiteID__c;
                bankDataObj.CancellationPartySiteID    = obj_Invoice.SalesOrderInstallment__r.SalesOrder__r.OraclePartySiteID__c;
                bankDataObj.CancellationSiteUseID      = obj_Invoice.SalesOrderInstallment__r.SalesOrder__r.OracleSiteUseID__c;
                bankDataObj.CancellationSalesOrder     = obj_Invoice.SalesOrderInstallment__r.SalesOrder__r.Name;
            }

            bankDataList.add(bankDataObj);
        }

        return bankDataList;
    }

    // -- OIC_ManageBankDataBatch REQUEST envelope only (kept separate from
    //    OIC_RequestWrapperController.Base64Wrapper -- see NOTE in sendBankDataRequest above).
    public class BankDataBase64Wrapper {
        public String Base64Request;
    }

    // =========================================================
    // WRAPPER CLASSES
    // =========================================================
    public class CancellationRequestWrapper {
        public List<CancellationRequest> RequestArray;
    }

    public class CancellationRequest {
        public String sfSrID;
        public String sfSoId;
        public String EntityName;
        public String ProjectName;
        public String srType;
        public String srStatus;

        public String ExtraInfo1;
        public String ExtraInfo2;
        public String ExtraInfo3;
        public String ExtraInfo4;
        public String ExtraInfo5;

        public List<InstallmentNode> InstallmentArray;
        public List<ReceiptNode> ReceiptArray;
        public List<ChargeNode> ChargesArray;
    }

    public class InstallmentNode {
        public String instSFID;
        public String installmentNo;
        public String oracleID;
        public Date   GlDate;
        public String TxnType;

        public String ExtraInfo1;
        public String ExtraInfo2;
        public String ExtraInfo3;
    }

    public class ReceiptNode {
        public String receiptSFID;
        public String receiptID;
        public Date   GLDate;

        public String ExtraInfo1;
        public String ExtraInfo2;
        public String ExtraInfo3;
    }

    public class ChargeNode {
        public String Sfid;
        public String SoSfid;
        public String SoIsfid;
        public Decimal Amount;
        public Date InvoiceDate;
        public String Description;
        public String TrxnType;
        public String CreditMemoFlag;

        public String ExtraInfo1;
        public String ExtraInfo2;
        public String ExtraInfo3;
        public String ExtraInfo4;
        public String ExtraInfo5;
    }
}