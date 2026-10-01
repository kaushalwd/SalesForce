/**********************************************************************************************************************
* Name               : OIC_SingleCancellationCalloutService
* Description        : Single Oracle Fusion / OIC callout for a Business_Process__c cancellation.
*
* Usage              : Called from BPCancellationSyncQueueable (BP cancellation strategies).
* Created By         : Modon IT
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           Karunakar Pulkam            22 Sep 2026         Initial draft — merged single-callout refactor
***********************************************************************************************************************/
public class OIC_SingleCancellationCalloutService {

    // Single endpoint for the merged request (the old bank-data endpoint — it already owns the refund-memo data)
    private static final String CREDENTIAL_NAME   = 'ModonFusionUpdateInvoiceAPI';
    private static final String SR_TYPE           = 'Cancellation';
    private static final String DEFAULT_TRXN_TYPE = 'ADM_CHARGES';
    private static final String TRXN_INSTALLMENT  = 'INSTALLMENT';
    private static final String TRXN_REFUND       = 'REFUND';
    private static final String ALREADY_SYNCED    = 'Cancellation Success';
    private static final Integer TIMEOUT_MS       = 120000;

    // Invoice__c.Transaction_Type__c values that make an invoice a refund line rather than a charge line
    private static final Set<String> REFUND_TRXN_TYPES = new Set<String>{ 'Refund', 'Customer Refund' };

    // Business_Process_Documents__c.Name -> DocumentName sent to Oracle in DocumentsLink
    private static final Map<String, String> OIC_DOCUMENT_NAMES = new Map<String, String>{
        'Bank Details'      => 'IBANLink',
        'Support Documents' => 'Support Document'
    };

    // =================================================================================================
    // MAIN METHOD — build + send the single merged cancellation request
    // =================================================================================================
    /**
     * @description Builds the full cancellation payload (header + bank/refund-memo details + documents +
     *              installment / receipt / charge / refund lines) and sends it in a single callout.
     * @param businessProcessId  Business_Process__c driving the cancellation (supplies the SR header + bank data).
     * @param salesOrderId       SalesOrder__c being cancelled.
     * @param invoiceIds         Cancelled invoices — split internally into ChargesArray and refundArray.
     * @param receiptIds         Cancelled receipts.
     * @param allocationIds      Allocations of the cancelled invoices — used to build refundArray.Allocations.
     * @return HttpResponse from OIC, or null when there is nothing to send.
     */
    public static HttpResponse sendCancellationRequest(
        Id           businessProcessId,
        Id           salesOrderId,
        List<String> invoiceIds,
        List<String> receiptIds,
        List<String> allocationIds
    ) {
        OIC_BPCancellationRequestWrapper payload =
            buildRequest(businessProcessId, salesOrderId, invoiceIds, receiptIds, allocationIds);

        if (payload == null || payload.RequestArray.isEmpty()) {
            return null; // nothing to sync — skip the callout entirely
        }

        String requestBody   = JSON.serialize(payload);
        System.debug('Cancellation Single Json '+ requestBody);
        String base64Payload = EncodingUtil.base64Encode(Blob.valueOf(requestBody));

        OIC_BPCancellationRequestWrapper.Base64RequestWrapper envelope =
            new OIC_BPCancellationRequestWrapper.Base64RequestWrapper();
        envelope.Base64Request = base64Payload;

        HttpRequest req = OIC_CredentialsController.getCredentials(CREDENTIAL_NAME);
        req.setTimeout(TIMEOUT_MS);
        req.setHeader('Accept', 'application/json');
        req.setBody(JSON.serialize(envelope));

        return new Http().send(req);
    }

    // =================================================================================================
    // BUILD REQUEST
    // =================================================================================================
    @TestVisible
    private static OIC_BPCancellationRequestWrapper buildRequest(
        Id           businessProcessId,
        Id           salesOrderId,
        List<String> invoiceIds,
        List<String> receiptIds,
        List<String> allocationIds
    ) {
        OIC_BPCancellationRequestWrapper root = new OIC_BPCancellationRequestWrapper();
        OIC_BPCancellationRequestWrapper.CancellationRequest header =
            new OIC_BPCancellationRequestWrapper.CancellationRequest();

        Business_Process__c bp = queryBusinessProcess(businessProcessId);
        SalesOrder__c       so = querySalesOrder(salesOrderId);

        // Bank / refund-memo details come from the BP's account first, then the Sales Order customer —
        // this replaces the separate OIC_ManageBankDataBatch request that used to carry them.
        Id accountId = (bp != null && bp.Account__c != null)
            ? bp.Account__c
            : (so != null ? so.CustomerAccount__c : null);
        Account acct = queryAccount(accountId);

        populateHeader(header, bp, so, acct);
        header.DocumentsLink = buildDocumentLinks(businessProcessId);

        // -------------------------------------------------------------------------------------------
        // Line data — all queried in bulk (the previous service queried invoice/receipt row by row
        // inside the loop, which could not survive more than 100 lines in a cancellation).
        // -------------------------------------------------------------------------------------------
        List<Invoice__c>    invoices    = queryInvoices(invoiceIds);
        List<Receipt__c>    receipts    = queryReceipts(receiptIds);
        List<Allocation__c> allocations = queryAllocations(allocationIds);

        // Allocations keyed by the invoice they were applied to — a refund line picks up the allocations
        // of its parent (cancelled) invoice, since that is the invoice the receipts were paid against.
        Map<Id, List<Allocation__c>> allocsByInvoice = new Map<Id, List<Allocation__c>>();
        for (Allocation__c alloc : allocations) {
            if (alloc.Invoice__c == null) continue;
            if (!allocsByInvoice.containsKey(alloc.Invoice__c)) {
                allocsByInvoice.put(alloc.Invoice__c, new List<Allocation__c>());
            }
            allocsByInvoice.get(alloc.Invoice__c).add(alloc);
        }

        Map<String, String> chargeToTrxnMap = loadChargeTypeMap();
        Map<Id, OIC_BPCancellationRequestWrapper.InstallmentNode> installmentNodes =
            new Map<Id, OIC_BPCancellationRequestWrapper.InstallmentNode>();

        for (Invoice__c inv : invoices) {
            // Already acknowledged by Oracle on an earlier attempt — do not resend
            if (inv.OICIntegrationStatus__c == ALREADY_SYNCED) continue;

            if (REFUND_TRXN_TYPES.contains(inv.Transaction_Type__c)) {
                header.refundArray.add(buildRefundNode(inv, so, allocsByInvoice));
            } else {
                header.ChargesArray.add(buildChargeNode(inv, so, chargeToTrxnMap));
            }

            addInstallmentNode(installmentNodes, inv);
        }
        header.InstallmentArray = installmentNodes.values();

        for (Receipt__c rec : receipts) {
            if (rec.OICIntegrationStatus__c == ALREADY_SYNCED) continue;
            header.ReceiptArray.add(buildReceiptNode(rec));
        }

        root.RequestArray.add(header);
        return root;
    }

    // =================================================================================================
    // HEADER
    // =================================================================================================
    private static void populateHeader(
        OIC_BPCancellationRequestWrapper.CancellationRequest header,
        Business_Process__c bp,
        SalesOrder__c       so,
        Account             acct
    ) {
        header.sfSrID         = (bp != null ? bp.Id : null);
        header.srNumber       = (bp != null ? bp.Name : null);
        header.srStatus       = (bp != null ? bp.Status__c : null);
        header.srType         = SR_TYPE;
        // Both of these describe the flavour of cancellation; Business_Process__c.Sub_Type__c carries
        // Addition/Deletion semantics that Oracle does not use here, so Cancellation_Type__c drives both.
        header.srSubType      = (bp != null ? bp.Cancellation_Type__c : null);
        header.sfSrRefundType = (bp != null ? bp.Cancellation_Type__c : null);

        header.sfSoId      = (so != null ? so.Id : null);
        header.sfSoCustId  = (so != null ? so.CustomerAccount__c : null);
        header.ProjectName = (so != null ? so.ProjectName__c : null);
        header.EntityName  = (so != null ? so.Unit__r.Phase__r.EntityName__c : null);

        header.ExtraInfo1 = (so != null ? so.Unit__r.Name : null);
        header.ExtraInfo2 = (so != null ? so.Unit__r.PlotNo__c : null);
        header.ExtraInfo3 = (so != null ? so.Unit__r.Phase__r.Name : null);

        // Refund-memo bank block — previously the body of the separate ModonFusionUpdateInvoiceAPI request
        header.BankAccountNumber = (acct != null ? acct.Bank_Account_Number__c : null);
        header.BankBranchName    = (acct != null ? acct.Bank_Branch_Name__c    : null);
        header.BankName          = (acct != null ? acct.Bank_Name__c           : null);
        header.IBANNumber        = (acct != null ? acct.IBAN_Number__c         : null);
        header.SwiftCode         = (acct != null ? acct.Swift_Code__c          : null);
        header.bicCode           = (acct != null ? acct.Swift_Code__c          : null);
        header.payeeName         = (acct == null)
            ? null
            : (String.isNotBlank(acct.Beneficiary_Name__c) ? acct.Beneficiary_Name__c : acct.Name);
    }

    /**
     * @description Public download links for the files on the BP's "Bank Details" and "Support Documents"
     *              Business_Process_Documents__c records. Read-only: the ContentDistribution records must
     *              already exist (see ensureDocumentDistributions), because DML here would block the callout.
     *              Files without a downloadable distribution are skipped.
     */
    private static List<OIC_BPCancellationRequestWrapper.DocumentLink> buildDocumentLinks(Id businessProcessId) {
        List<OIC_BPCancellationRequestWrapper.DocumentLink> links =
            new List<OIC_BPCancellationRequestWrapper.DocumentLink>();

        Map<Id, String> docNameByVersion = queryDocumentVersions(businessProcessId);
        if (docNameByVersion.isEmpty()) return links;

        Map<Id, ContentDistribution> distByVersion = queryDownloadableDistributions(docNameByVersion.keySet());

        for (Id versionId : docNameByVersion.keySet()) {
            ContentDistribution cd = distByVersion.get(versionId);
            if (cd == null || String.isBlank(cd.ContentDownloadUrl)) continue;

            OIC_BPCancellationRequestWrapper.DocumentLink link =
                new OIC_BPCancellationRequestWrapper.DocumentLink();
            link.DocumentName = docNameByVersion.get(versionId);
            link.URLLink      = cd.ContentDownloadUrl;
            links.add(link);
        }
        return links;
    }

    /**
     * @description Creates a downloadable ContentDistribution for every "Bank Details" / "Support Documents"
     *              file on the BP that does not have one yet. Must run in a transaction BEFORE the callout —
     *              Salesforce rejects a callout after uncommitted DML.
     * @return true when at least one ContentDistribution was inserted (the caller must then do the callout
     *         in a new transaction).
     */
    public static Boolean ensureDocumentDistributions(Id businessProcessId) {
        Map<Id, String> docNameByVersion = queryDocumentVersions(businessProcessId);
        if (docNameByVersion.isEmpty()) return false;

        Map<Id, ContentDistribution> distByVersion = queryDownloadableDistributions(docNameByVersion.keySet());

        List<ContentDistribution> toInsert = new List<ContentDistribution>();
        for (Id versionId : docNameByVersion.keySet()) {
            if (distByVersion.containsKey(versionId)) continue;
            toInsert.add(new ContentDistribution(
                Name                             = docNameByVersion.get(versionId),
                ContentVersionId                 = versionId,
                PreferencesAllowViewInBrowser    = true,
                PreferencesAllowOriginalDownload = true, // required for ContentDownloadUrl to download
                PreferencesNotifyOnVisit         = false
            ));
        }
        if (toInsert.isEmpty()) return false;

        insert toInsert;
        return true;
    }

    /**
     * @description Latest published version of each file on the BP's "Bank Details" / "Support Documents"
     *              document records, mapped to the DocumentName Oracle expects.
     */
    private static Map<Id, String> queryDocumentVersions(Id businessProcessId) {
        Map<Id, String> docNameByVersion = new Map<Id, String>();
        if (businessProcessId == null) return docNameByVersion;

        Map<Id, Business_Process_Documents__c> bpDocs = new Map<Id, Business_Process_Documents__c>([
            SELECT Id, Name
            FROM   Business_Process_Documents__c
            WHERE  Business_Process__c = :businessProcessId
              AND  Name IN :OIC_DOCUMENT_NAMES.keySet()
        ]);
        if (bpDocs.isEmpty()) return docNameByVersion;

        for (ContentDocumentLink cdl : [
            SELECT LinkedEntityId, ContentDocument.LatestPublishedVersionId
            FROM   ContentDocumentLink
            WHERE  LinkedEntityId IN :bpDocs.keySet()
        ]) {
            Id versionId = cdl.ContentDocument.LatestPublishedVersionId;
            if (versionId == null) continue;
            docNameByVersion.put(versionId, OIC_DOCUMENT_NAMES.get(bpDocs.get(cdl.LinkedEntityId).Name));
        }
        return docNameByVersion;
    }

    private static Map<Id, ContentDistribution> queryDownloadableDistributions(Set<Id> versionIds) {
        Map<Id, ContentDistribution> distByVersion = new Map<Id, ContentDistribution>();
        for (ContentDistribution cd : [
            SELECT Id, ContentVersionId, ContentDownloadUrl
            FROM   ContentDistribution
            WHERE  ContentVersionId IN :versionIds
              AND  PreferencesAllowOriginalDownload = true
            ORDER BY CreatedDate DESC
        ]) {
            // Keep the newest distribution per version
            if (!distByVersion.containsKey(cd.ContentVersionId)) {
                distByVersion.put(cd.ContentVersionId, cd);
            }
        }
        return distByVersion;
    }

    // =================================================================================================
    // LINE BUILDERS
    // =================================================================================================
    private static OIC_BPCancellationRequestWrapper.ChargeNode buildChargeNode(
        Invoice__c          inv,
        SalesOrder__c       so,
        Map<String, String> chargeToTrxnMap
    ) {
        OIC_BPCancellationRequestWrapper.ChargeNode c = new OIC_BPCancellationRequestWrapper.ChargeNode();
        populateCommonInvoiceFields(c, inv, so);

        // A cancelled invoice that already exists in Oracle is credited back rather than re-raised
        Boolean isCreditMemo = (inv.InvoiceStatus__c == 'Cancelled' || inv.isCancelled__c == true)
                                && String.isNotBlank(inv.OraclePartyId__c);
        c.CreditMemoFlag           = isCreditMemo ? 'Y' : 'N';
        c.CreditMemoApplyInvoiceId = isCreditMemo ? inv.OraclePartyId__c : null;

        // Charge-based invoices resolve their Oracle transaction type from custom metadata;
        // installment invoices are always INSTALLMENT.
        if (inv.Charge__c != null) {
            c.TrxnType = chargeToTrxnMap.containsKey(inv.Charge__r.Type__c)
                ? chargeToTrxnMap.get(inv.Charge__r.Type__c)
                : DEFAULT_TRXN_TYPE;
        } else {
            c.TrxnType = TRXN_INSTALLMENT;
        }
        return c;
    }

    private static OIC_BPCancellationRequestWrapper.RefundNode buildRefundNode(
        Invoice__c                   inv,
        SalesOrder__c                so,
        Map<Id, List<Allocation__c>> allocsByInvoice
    ) {
        OIC_BPCancellationRequestWrapper.RefundNode r = new OIC_BPCancellationRequestWrapper.RefundNode();

        r.Sfid                 = inv.Id;
        r.SoSfid               = resolveSoSfid(inv);
        r.SoIsfid              = inv.SalesOrderInstallment__c;
        r.SoIsfReference       = inv.SalesOrderInstallment__r.Name;
        r.CustomerSfid         = inv.Account__c;
        r.CustomerPartyId      = inv.Account__r.OraclePartyId__c;
        r.CustomerAcct         = '';
        r.Amount               = inv.InvoiceAmount__c;
        r.InvoiceDate          = inv.InvoiceDate__c;
        r.GlDate               = inv.Ebs_Invoice_Date__c != null ? inv.Ebs_Invoice_Date__c : System.today();
        r.InstallmentNumber    = inv.Name;
        r.Description          = inv.Description__c;
        r.Status               = inv.InvoiceStatus__c;
        r.OrgIdentifier        = UserInfo.getOrganizationId();
        r.TrxnType             = TRXN_REFUND;
        r.CreditMemoFlag       = 'N';
        r.CreditMemoApplyInvoiceId = null;

        copySalesOrderFields(r, so);

        r.ExtraInfo1 = (so != null ? so.Unit__r.Name : null);
        r.ExtraInfo2 = (so != null ? so.Unit__r.PlotNo__c : null);
        r.ExtraInfo3 = inv.Transaction_Type__c;
        r.ExtraInfo4 = '';
        r.ExtraInfo5 = '';

        // Receipts funding the refund: a refund invoice is raised against a cancelled parent invoice, so the
        // allocations to report are the parent's. Fall back to the refund invoice's own allocations.
        Id allocationSourceId = inv.Parent_Invoice__c != null ? inv.Parent_Invoice__c : inv.Id;
        if (allocsByInvoice.containsKey(allocationSourceId)) {
            for (Allocation__c alloc : allocsByInvoice.get(allocationSourceId)) {
                OIC_BPCancellationRequestWrapper.AllocationNode a =
                    new OIC_BPCancellationRequestWrapper.AllocationNode();
                a.receiptSFID     = alloc.Receipt__c;
                a.receiptFusionID = alloc.Receipt__r.OraclePartyId__c;
                a.amountAlloc     = alloc.AllocationAmount__c;
                r.Allocations.add(a);
            }
        }
        return r;
    }

    private static OIC_BPCancellationRequestWrapper.ReceiptNode buildReceiptNode(Receipt__c rec) {
        OIC_BPCancellationRequestWrapper.ReceiptNode rn = new OIC_BPCancellationRequestWrapper.ReceiptNode();
        rn.receiptSFID = rec.Id;
        rn.receiptID   = rec.OraclePartyId__c;
        rn.ExtraInfo1  = rec.OraclePartyId__c;
        rn.ExtraInfo2  = String.valueOf(rec.EBS_Clearing_Date__c);
        rn.ExtraInfo3  = 'CANCELLATION';
        return rn;
    }

    /**
     * @description Adds one InstallmentArray entry per distinct Sales Order Installment behind the
     *              cancelled invoices, carrying the Oracle id of the invoice raised for that installment.
     */
    private static void addInstallmentNode(
        Map<Id, OIC_BPCancellationRequestWrapper.InstallmentNode> nodes,
        Invoice__c inv
    ) {
        if (inv.SalesOrderInstallment__c == null || nodes.containsKey(inv.SalesOrderInstallment__c)) return;

        OIC_BPCancellationRequestWrapper.InstallmentNode n =
            new OIC_BPCancellationRequestWrapper.InstallmentNode();
        n.instSFID      = inv.SalesOrderInstallment__c;
        n.installmentNo = inv.SalesOrderInstallment__r.Instalment_Number__c;
        n.oracleID      = inv.OraclePartyId__c;
        n.TxnType       = TRXN_INSTALLMENT;
        n.ExtraInfo1    = inv.SalesOrderInstallment__r.Name;
        n.ExtraInfo2    = inv.SalesOrderInstallment__r.Milestone_Name__c;
        n.ExtraInfo3    = '';
        nodes.put(inv.SalesOrderInstallment__c, n);
    }

    // -------------------------------------------------------------------------------------------------
    // Shared line mapping — ChargeNode and RefundNode carry the same invoice/Sales Order attributes.
    // (ChargeNode is populated here; RefundNode reuses copySalesOrderFields for the Sales Order half.)
    // -------------------------------------------------------------------------------------------------
    private static void populateCommonInvoiceFields(
        OIC_BPCancellationRequestWrapper.ChargeNode c,
        Invoice__c                                  inv,
        SalesOrder__c                               so
    ) {
        c.Sfid              = inv.Id;
        c.SoSfid            = resolveSoSfid(inv);
        c.SoIsfid           = inv.SalesOrderInstallment__c;
        c.SoIsfReference    = inv.SalesOrderInstallment__r.Name;
        c.CustomerSfid      = inv.Account__c;
        c.CustomerPartyId   = inv.Account__r.OraclePartyId__c;
        c.CustomerAcct      = '';
        c.Amount            = inv.InvoiceAmount__c;
        c.InvoiceDate       = inv.InvoiceDate__c;
        c.GlDate            = inv.Ebs_Invoice_Date__c != null ? inv.Ebs_Invoice_Date__c : System.today();
        c.InstallmentNumber = inv.Name;
        c.Description       = inv.Description__c;
        c.Status            = inv.InvoiceStatus__c;
        c.OrgIdentifier     = UserInfo.getOrganizationId();

        copySalesOrderFields(c, so);

        c.ExtraInfo1 = (so != null ? so.Unit__r.Name : null);
        c.ExtraInfo2 = (so != null ? so.Unit__r.PlotNo__c : null);
        c.ExtraInfo3 = inv.Transaction_Type__c;
        c.ExtraInfo4 = '';
        c.ExtraInfo5 = '';
    }

    private static void copySalesOrderFields(OIC_BPCancellationRequestWrapper.ChargeNode c, SalesOrder__c so) {
        if (so == null) return;
        c.EscrowAccountNumber  = so.VirtualAccount__r.EscrowAccount__r.AccountNumber__c;
        c.EscrowIbanNumber     = so.VirtualAccount__r.EscrowAccount__r.IBANNo__c;
        c.EscrowStoreId        = so.VirtualAccount__r.EscrowAccount__r.StoreId__c;
        c.EscrowSwiftCode      = so.VirtualAccount__r.EscrowAccount__r.SwiftCode__c;
        c.EscrowTradeId        = so.VirtualAccount__r.EscrowAccount__r.TradeID__c;
        c.EscrowBankName       = so.VirtualAccount__r.EscrowAccount__r.BankName__c;
        c.EscrowBenificaryName = so.VirtualAccount__r.EscrowAccount__r.BeneficiaryName__c;
        c.VirtualAccountNumber = so.VirtualAccount__r.VirtualAccountNumber__c;
        c.VirtualIbanNumber    = so.VirtualAccount__r.VirtualIBANNumber__c;
        c.Unit                 = so.Unit__r.PlotNo__c;
        c.UnitName             = so.Unit__r.Name;
        c.UnitSfId             = so.Unit__c;
        c.SoReference          = so.Name;
        c.ProjectName          = so.ProjectName__c;
        c.ProjectPhase         = so.Unit__r.Phase__r.Name;
        c.CustAcctId           = so.CustAcctId__c;
        c.OraclePartySiteID    = so.OraclePartySiteID__c;
        c.OracleCustAcctSiteID = so.OracleCustAcctSiteID__c;
        c.OracleSiteUseID      = so.OracleSiteUseID__c;
    }

    private static void copySalesOrderFields(OIC_BPCancellationRequestWrapper.RefundNode r, SalesOrder__c so) {
        if (so == null) return;
        r.EscrowAccountNumber  = so.VirtualAccount__r.EscrowAccount__r.AccountNumber__c;
        r.EscrowIbanNumber     = so.VirtualAccount__r.EscrowAccount__r.IBANNo__c;
        r.EscrowStoreId        = so.VirtualAccount__r.EscrowAccount__r.StoreId__c;
        r.EscrowSwiftCode      = so.VirtualAccount__r.EscrowAccount__r.SwiftCode__c;
        r.EscrowTradeId        = so.VirtualAccount__r.EscrowAccount__r.TradeID__c;
        r.EscrowBankName       = so.VirtualAccount__r.EscrowAccount__r.BankName__c;
        r.EscrowBenificaryName = so.VirtualAccount__r.EscrowAccount__r.BeneficiaryName__c;
        r.VirtualAccountNumber = so.VirtualAccount__r.VirtualAccountNumber__c;
        r.VirtualIbanNumber    = so.VirtualAccount__r.VirtualIBANNumber__c;
        r.Unit                 = so.Unit__r.PlotNo__c;
        r.UnitName             = so.Unit__r.Name;
        r.UnitSfId             = so.Unit__c;
        r.SoReference          = so.Name;
        r.ProjectName          = so.ProjectName__c;
        r.ProjectPhase         = so.Unit__r.Phase__r.Name;
        r.CustAcctId           = so.CustAcctId__c;
        r.OraclePartySiteID    = so.OraclePartySiteID__c;
        r.OracleCustAcctSiteID = so.OracleCustAcctSiteID__c;
        r.OracleSiteUseID      = so.OracleSiteUseID__c;
    }

    private static String resolveSoSfid(Invoice__c inv) {
        if (inv.SalesOrderInstallment__c != null && inv.SalesOrderInstallment__r.SalesOrder__c != null) {
            return inv.SalesOrderInstallment__r.SalesOrder__c;
        }
        return inv.Sales_Order__c;
    }

    private static Map<String, String> loadChargeTypeMap() {
        Map<String, String> chargeToTrxnMap = new Map<String, String>();
        for (ChargeTypeToTrxnType__mdt cfg : ChargeTypeToTrxnType__mdt.getAll().values()) {
            chargeToTrxnMap.put(cfg.ChargeType__c, cfg.TrxnType__c);
        }
        return chargeToTrxnMap;
    }

    // =================================================================================================
    // QUERIES
    // =================================================================================================
    private static Business_Process__c queryBusinessProcess(Id businessProcessId) {
        if (businessProcessId == null) return null;
        List<Business_Process__c> bps = [
            SELECT Id, Name, Status__c, Cancellation_Type__c, Account__c
            FROM   Business_Process__c
            WHERE  Id = :businessProcessId
            LIMIT  1
        ];
        return bps.isEmpty() ? null : bps[0];
    }

    private static SalesOrder__c querySalesOrder(Id salesOrderId) {
        if (salesOrderId == null) return null;
        List<SalesOrder__c> sos = [
            SELECT Id, Name, Status__c, ProjectName__c, CustomerAccount__c,
                   CustAcctId__c, OraclePartySiteID__c, OracleCustAcctSiteID__c, OracleSiteUseID__c,
                   Unit__c, Unit__r.Name, Unit__r.PlotNo__c,
                   Unit__r.Phase__r.Name, Unit__r.Phase__r.EntityName__c,
                   VirtualAccount__r.VirtualAccountNumber__c, VirtualAccount__r.VirtualIBANNumber__c,
                   VirtualAccount__r.EscrowAccount__r.AccountNumber__c,
                   VirtualAccount__r.EscrowAccount__r.IBANNo__c,
                   VirtualAccount__r.EscrowAccount__r.StoreId__c,
                   VirtualAccount__r.EscrowAccount__r.SwiftCode__c,
                   VirtualAccount__r.EscrowAccount__r.TradeID__c,
                   VirtualAccount__r.EscrowAccount__r.BankName__c,
                   VirtualAccount__r.EscrowAccount__r.BeneficiaryName__c
            FROM   SalesOrder__c
            WHERE  Id = :salesOrderId
            LIMIT  1
        ];
        return sos.isEmpty() ? null : sos[0];
    }

    private static Account queryAccount(Id accountId) {
        if (accountId == null) return null;
        List<Account> accts = [
            SELECT Id, Name, OraclePartyId__c, Beneficiary_Name__c,
                   Bank_Account_Number__c, Bank_Branch_Name__c, Bank_Name__c,
                   IBAN_Number__c, Swift_Code__c
            FROM   Account
            WHERE  Id = :accountId
            LIMIT  1
        ];
        return accts.isEmpty() ? null : accts[0];
    }

    private static List<Invoice__c> queryInvoices(List<String> invoiceIds) {
        if (invoiceIds == null || invoiceIds.isEmpty()) return new List<Invoice__c>();
        return [
            SELECT Id, Name, InvoiceAmount__c, InvoiceDate__c, Ebs_Invoice_Date__c,
                   InvoiceStatus__c, isCancelled__c, Description__c, Transaction_Type__c,
                   OraclePartyId__c, OICIntegrationStatus__c, Parent_Invoice__c,
                   Account__c, Account__r.OraclePartyId__c,
                   Charge__c, Charge__r.Type__c,
                   Sales_Order__c,
                   SalesOrderInstallment__c, SalesOrderInstallment__r.Name,
                   SalesOrderInstallment__r.Instalment_Number__c,
                   SalesOrderInstallment__r.Milestone_Name__c,
                   SalesOrderInstallment__r.SalesOrder__c
            FROM   Invoice__c
            WHERE  Id IN :invoiceIds
        ];
    }

    private static List<Receipt__c> queryReceipts(List<String> receiptIds) {
        if (receiptIds == null || receiptIds.isEmpty()) return new List<Receipt__c>();
        return [
            SELECT Id, OraclePartyId__c, EBS_Clearing_Date__c, OICIntegrationStatus__c
            FROM   Receipt__c
            WHERE  Id IN :receiptIds
        ];
    }

    private static List<Allocation__c> queryAllocations(List<String> allocationIds) {
        if (allocationIds == null || allocationIds.isEmpty()) return new List<Allocation__c>();
        return [
            SELECT Id, Invoice__c, Receipt__c, Receipt__r.OraclePartyId__c,
                   AllocationAmount__c, OICIntegrationStatus__c
            FROM   Allocation__c
            WHERE  Id IN :allocationIds
              AND  OICIntegrationStatus__c != :ALREADY_SYNCED
        ];
    }
}