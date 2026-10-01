/**********************************************************************************************************************
* Name               : OIC_SFDataWrapperGenerator
* Description        : Builds OIC request wrapper objects from Salesforce records for the Oracle-Salesforce
*                      (Fusion) integration. Separates payload-building logic from the callout logic in
*                      OIC_ManageSalesforceDataController.
* Usage              : Called from OIC_ManageSalesforceDataController and related integration classes.
* Created By         : MODON IT
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           Modon IT     26 Jul 2026     Initial Draft - extracted createReceipt wrapper builder
* 1.1			Karunakar Pulkam			20 Aug 2026		Bypass flag deafaulting 'N'
* 1.2			MODON IT					26 Aug 2026		Added createInstallment wrapper builders (SOI / Sales Order)
* 1.3			Karunakar					26 Aug 2026		Added Advance Tax cancellation wrapper builder
* 1.4			Karunakar					28 Aug 2026		Added Advance Tax creation wrapper builder
* 1.5			Karunakar					28 Aug 2026		Advance Tax creation now gated by usesSalesOrderInstallment/usesSalesOrder
* 1.6			Karunakar					30 Aug 2026		Advance Tax cancellation now carries Receipt fields (ReceiptSFID/
*															FusionReceiptID/AllocAmount/UnAllocAmount); added UnAllocAmount
***********************************************************************************************************************/
public without sharing class OIC_SFDataWrapperGenerator {

    private static final String TRXN_TYPE_ADV_TAX = 'ADV_TAX';

    /**
     * Description : Builds the list of ReceiptWrapper payloads from the supplied Receipt__c records.
     *               Populates the supplied receiptMap with receipt Ids that are already approved
     *               (Bypass = 'N') so the caller can drive its post-callout update logic.
     * @param receipts   List of Receipt__c records to convert into wrappers.
     * @param receiptMap Map to be populated with approved receipt Ids (passed by reference).
     * @return List<OIC_RequestWrapperController.ReceiptWrapper> built from the receipts.
     */
    public static List<OIC_RequestWrapperController.ReceiptWrapper> generateReceiptWrappers(
            List<Receipt__c> receipts, Map<Id,Boolean> receiptMap) {

        // Build charge-type -> transaction-type map from custom metadata
        Map<String,String> chargeToTrxnMap = new Map<String,String>();
        for (ChargeTypeToTrxnType__mdt cfg : ChargeTypeToTrxnType__mdt.getAll().values()) {
            chargeToTrxnMap.put(cfg.ChargeType__c, cfg.TrxnType__c);
        }

        List<OIC_RequestWrapperController.ReceiptWrapper> receiptWrapLst = new List<OIC_RequestWrapperController.ReceiptWrapper>();

        for (Receipt__c receipt : receipts) {
            OIC_RequestWrapperController.ReceiptWrapper rw = new OIC_RequestWrapperController.ReceiptWrapper();
            rw.Sfid = receipt.Id;
            rw.SfReference = receipt.Name;
            rw.CustomerSfid = receipt.Account__c;
            rw.CustomerPartyId = receipt.Account__r.OraclePartyId__c;
            rw.VirtualAccountNumber = receipt.SalesOrder__r.VirtualAccount__r.VirtualAccountNumber__c;
            rw.VirtualIbanNumber = receipt.SalesOrder__r.VirtualAccount__r.VirtualIBANNumber__c;
            rw.OrgIdentifier = UserInfo.getOrganizationId();
            if (receipt.SalesOrderInstallment__c != null) {
                rw.ProjectName = receipt.SalesOrderInstallment__r.SalesOrder__r.ProjectName__c;
                // 16.0 - Hudayriyat Golf Estates project changes
                if(receipt.SalesOrderInstallment__r.SalesOrder__r.ProjectName__c == 'Hudayriyat Golf Estates'){
                    rw.ExtraInfo2 = receipt.SalesOrderInstallment__r.SalesOrder__r.Unit__r.Project_Name__c+'-'+
                        receipt.SalesOrderInstallment__r.SalesOrder__r.Unit__r.UnitClassification__c;
                } else {
                    rw.ExtraInfo2 = receipt.SalesOrderInstallment__r.SalesOrder__r.Unit__r.Project_Name__c == 'Commercial Plots' ?
                        receipt.SalesOrderInstallment__r.SalesOrder__r.Unit__r.Name :
                        receipt.SalesOrderInstallment__r.SalesOrder__r.Unit__r.Project_Name__c+'-'+
                        receipt.SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__r.Name;
                }
                rw.EntityName = receipt.SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__r.EntityName__c;
                rw.ProjectPhase = receipt.SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__r.Name;
                rw.SoSfid = receipt.SalesOrderInstallment__r.SalesOrder__c;
                rw.SoReference  =receipt.SalesOrderInstallment__r.SalesOrder__r.Name;
                rw.SoIsfid = receipt.SalesOrderInstallment__c;
                rw.SoIsfReference = receipt.SalesOrderInstallment__r.Name;
                rw.TrxnType = 'INSTALLMENT'; // 18.0
            } else {
                rw.ProjectName = receipt.SalesOrder__r.ProjectName__c;
                // 16.0 - Hudayriyat Golf Estates project changes
                if(receipt.SalesOrder__r.ProjectName__c == 'Hudayriyat Golf Estates'){
                    rw.ExtraInfo2 = receipt.SalesOrder__r.Unit__r.Project_Name__c+'-'+receipt.SalesOrder__r.Unit__r.UnitClassification__c;
                } else {
                    rw.ExtraInfo2 =  receipt.SalesOrder__r.Unit__r.Project_Name__c == 'Commercial Plots' ?
                        receipt.SalesOrder__r.Unit__r.Name: receipt.SalesOrder__r.Unit__r.Project_Name__c+
                        '-'+receipt.SalesOrder__r.Unit__r.Phase__r.Name; // 12.0
                }
                rw.EntityName = receipt.SalesOrder__r.Unit__r.Phase__r.EntityName__c;
                rw.ProjectPhase = receipt.SalesOrder__r.Unit__r.Phase__r.Name;
                String ct = receipt.Charge__r.Type__c;
                rw.TrxnType = chargeToTrxnMap.containsKey(ct) ? chargeToTrxnMap.get(ct) : 'ADM_CHARGES';
                rw.SoSfid = receipt.SalesOrder__c;
                rw.SoReference  =receipt.SalesOrder__r.Name;
            }
            // 17.0 - TrxnType override block
            // Priority 1: Equity Transfer record type → always EQU_TRANSFOR
            if(receipt.RecordType.name == 'Equity Transfer'){
                rw.TrxnType = 'EQU_TRANSFOR';
            }
            // Priority 2: Credit Note record type → always CREDIT_NOTE
            else if(receipt.RecordType.name == 'Credit Note'){
                rw.TrxnType = 'CREDIT_NOTE';
            }
            // Priority 3: 14.0 - ADM receipt: Transaction_Type__c explicitly ADM_CHARGES
            // Overrides INSTALLMENT that was incorrectly set by old else block
            else if(receipt.Transaction_Type__c == 'ADM_CHARGES'){
                rw.TrxnType = 'ADM_CHARGES';
            }
            // Priority 4: 14.0 - ADM receipt: Is ADM flag true → fallback to ADM_CHARGES
            // Covers ADM receipts where Transaction_Type__c is null
            else if(receipt.Is_ADM_Fees_And_Dari_charges__c == true){
                rw.TrxnType = 'ADM_CHARGES';
            }
            // Priority 5: Keep whatever TrxnType was already correctly set
            // e.g. ADM_CHARGES from charge map (else branch) or INSTALLMENT from SOI branch
            // No else — existing value is preserved
            if(receipt.Transaction_Type__c == 'EQU_TRANSFOR'){
                rw.TransferType ='EQU_TRANSFOR';
            }else if(receipt.Transaction_Type__c == 'REFOUND'){
                rw.TransferType ='REFOUND';
            }
            rw.Description = receipt.Milestone_Description__c;
            rw.EscrowAccountName = receipt.PaymentEscrowAccount__r.Name;
            rw.EscrowAccountNo = receipt.PaymentEscrowAccount__r.AccountNumber__c;
            rw.EscrowIBANNo = receipt.PaymentEscrowAccount__r.IBANNo__c;
            rw.ReceiptNumber = receipt.Name;
            rw.ReceiptType = receipt.Modeofpayment__c;
            rw.CurrencyCode = 'AED';
            rw.ReceiptDate = receipt.ChequeDate__c != null ? Date.valueOf(receipt.ChequeDate__c) : Date.valueOf(receipt.ReceiptDate__c);
            rw.MaturityDate = rw.ReceiptDate;
            rw.GlDate = receipt.EBS_Clearing_Date__c != null ? receipt.EBS_Clearing_Date__c : system.today();
            rw.Amount = receipt.Receipt_Amount__c != null ? receipt.Receipt_Amount__c : receipt.AppliedAmount__c;
            rw.BankName = receipt.Bank__c;
            rw.Status = receipt.Status__c;
            rw.ChequeNumber = receipt.TransactionNumber__c;
            rw.CustAcctId = receipt.SalesOrder__r.CustAcctId__c;
            rw.OraclePartySiteID = receipt.SalesOrder__r.OraclePartySiteID__c;
            rw.OracleCustAcctSiteID = receipt.SalesOrder__r.OracleCustAcctSiteID__c;
            rw.OracleSiteUseID = receipt.SalesOrder__r.OracleSiteUseID__c;
            rw.Unit = receipt.SalesOrder__r.Unit__r.Name;
            rw.UnitName = receipt.SalesOrder__r.Unit__r.Name;
            rw.EoiFlag = receipt.ExpressionOfInterest__c != null ? 'Y' : 'N';
            rw.Bypass = 'N';//1.1
            if (receipt.Receipt_Approved_Date__c != null) {
                //rw.Bypass = 'N';
                receiptMap.put(receipt.id,true);
            } //else {
                //rw.Bypass = 'Y';
            //}
            receiptWrapLst.add(rw);
        }

        return receiptWrapLst;
    }

    // ── Installment (Invoice__c) wrappers ─────────────────────────────────────

    /**
     * Description : Builds the list of InstallmentWrapper payloads from the supplied Invoice__c records.
     *               Each invoice is routed to one of two builders depending on whether it is driven by a
     *               Sales Order Installment (usesSOI = true) or directly by a Sales Order (usesSOI = false).
     *               Populates invCrdMap with the invoice Ids sent as CREDIT_MEMO so the caller can decide
     *               which Oracle Id field to stamp on the response.
     * @param invoices           List of Invoice__c records to convert into wrappers.
     * @param accountIbanUrlMap  Account Id to 'IBAN Letter' public URL map (only needed for Customer Refunds).
     * @param invCrdMap          Map to be populated with credit-memo invoice Ids (passed by reference).
     * @return List<OIC_RequestWrapperController.InstallmentWrapper> built from the invoices.
     */
    public static List<OIC_RequestWrapperController.InstallmentWrapper> generateInstallmentWrappers(
            List<Invoice__c> invoices, Map<Id,String> accountIbanUrlMap, Map<Id,Boolean> invCrdMap) {

        // Build charge-type -> transaction-type map from custom metadata
        Map<String,String> chargeToTrxnMap = new Map<String,String>();
        for (ChargeTypeToTrxnType__mdt cfg : ChargeTypeToTrxnType__mdt.getAll().values()) {
            chargeToTrxnMap.put(cfg.ChargeType__c, cfg.TrxnType__c);
        }

        List<OIC_RequestWrapperController.InstallmentWrapper> installmentWrapLst =
            new List<OIC_RequestWrapperController.InstallmentWrapper>();

        for (Invoice__c inv : invoices) {
            Boolean usesSOI = usesSalesOrderInstallment(inv);
            if (usesSOI) {
                installmentWrapLst.add(generateSOInstallmentWrapper(inv, accountIbanUrlMap, invCrdMap));
            } else if (usesSalesOrder(inv)) {
                installmentWrapLst.add(generateSalesOrderInvoiceWrapper(inv, chargeToTrxnMap, accountIbanUrlMap));
            }
        }
        return installmentWrapLst;
    }

    /**
     * Description : True when the invoice is driven by a Sales Order Installment whose Sales Order carries
     *               the Oracle site details and is not excluded from the Oracle feed.
     */
    @TestVisible
    private static Boolean usesSalesOrderInstallment(Invoice__c inv) {
        return inv.SalesOrderInstallment__c != null
            && inv.SalesOrderInstallment__r.SalesOrder__r.OraclePartySiteID__c != null
            && inv.SalesOrderInstallment__r.SalesOrder__r.OracleCustAcctSiteID__c != null
            && inv.SalesOrderInstallment__r.SalesOrder__r.NotToBeShownOnRD__c == false
            && inv.SalesOrderInstallment__r.SalesOrder__r.Source_Entity__c != 'Modon - Egypt';
    }

    /**
     * Description : True when the invoice is driven directly by a Sales Order that carries the Oracle site
     *               details and is not excluded from the Oracle feed.
     */
    @TestVisible
    private static Boolean usesSalesOrder(Invoice__c inv) {
        return inv.Sales_Order__c != null
            && inv.Sales_Order__r.OracleCustAcctSiteID__c != null
            && inv.Sales_Order__r.OracleSiteUseID__c != null
            && inv.Sales_Order__r.NotToBeShownOnRD__c == false
            && inv.Sales_Order__r.Source_Entity__c != 'Modon - Egypt';
    }

    /**
     * Description : Builds the wrapper for an invoice linked to a Sales Order Installment (usesSOI = true).
     *               Handles the Refund / Debit Memo / Credit Memo status variations.
     */
    private static OIC_RequestWrapperController.InstallmentWrapper generateSOInstallmentWrapper(
            Invoice__c inv, Map<Id,String> accountIbanUrlMap, Map<Id,Boolean> invCrdMap) {

        OIC_RequestWrapperController.InstallmentWrapper iw = new OIC_RequestWrapperController.InstallmentWrapper();
        applyInvoiceFields(iw, inv);
        applySalesOrderFields(iw, inv.SalesOrderInstallment__r.SalesOrder__r);

        iw.SoSfid = inv.SalesOrderInstallment__r.SalesOrder__c;
        iw.SoIsfid = inv.SalesOrderInstallment__c;
        iw.SoIsfReference = inv.SalesOrderInstallment__r.Name; //14.0
        iw.TrxnType = 'INSTALLMENT';
        iw.Description = inv.SalesOrderInstallment__r.Milestone_Name__c;

        if (inv.InvoiceAmount__c != null) iw.Amount = String.valueOf(inv.InvoiceAmount__c);
        iw.InvoiceDate = inv.InvoiceDate__c != null ? Date.valueOf(inv.InvoiceDate__c)
            : (inv.Ebs_Invoice_Date__c != null ? Date.valueOf(inv.Ebs_Invoice_Date__c) : System.today());
        iw.GlDate = inv.Ebs_Invoice_Date__c != null ? inv.Ebs_Invoice_Date__c : System.today();

        if (inv.RecordType.name == 'Debit Memo' && inv.Parent_Invoice__c != null) {
            iw.CreditMemoFlag = 'N';
            iw.Status = 'Generated';
            //20.0 - Customer refund bank details
            applyCustomerRefundFields(iw, inv, accountIbanUrlMap);
        } else if (inv.RecordType.name == 'Debit Memo' && inv.Parent_Invoice__c == null) {
            iw.CreditMemoFlag = 'N';
            iw.Status = 'Generated';
            iw.TrxnType = 'DEBIT_MEMO';
        } else if (inv.RecordType.name != 'Debit Memo'
                && (inv.RecordType.name == 'Tax Invoice' || inv.OraclePartyId__c != null)
                && inv.InvoiceStatus__c == 'Cancelled') {
            iw.CreditMemoFlag = 'Y';
            iw.Status = 'Cancelled';
            iw.CreditMemoApplyInvoiceId = inv.OraclePartyId__c;
            iw.GlDate = System.today();
            iw.TrxnType = 'CREDIT_MEMO';
            invCrdMap.put(inv.Id, true);
        } else {
            iw.CreditMemoFlag = 'N';
            iw.Status = 'Generated';
        }
        System.debug('installmentWrapObj-----' + iw);
        return iw;
    }

    /**
     * Description : Builds the wrapper for an invoice linked directly to a Sales Order (usesSOI = false).
     *               Transaction type is resolved from the Charge type metadata mapping and overridden for
     *               Customer Refund debit memos.
     */
    private static OIC_RequestWrapperController.InstallmentWrapper generateSalesOrderInvoiceWrapper(
            Invoice__c inv, Map<String,String> chargeToTrxnMap, Map<Id,String> accountIbanUrlMap) {

        OIC_RequestWrapperController.InstallmentWrapper iw = new OIC_RequestWrapperController.InstallmentWrapper();
        applyInvoiceFields(iw, inv);
        applySalesOrderFields(iw, inv.Sales_Order__r);

        iw.SoSfid = inv.Sales_Order__c;

        String ct = inv.Charge__r.Type__c;
        iw.TrxnType = chargeToTrxnMap.containsKey(ct) ? chargeToTrxnMap.get(ct) : 'ADM_CHARGES';
        iw.Description = inv.Sales_Order__r.Unit__r.Project_Name__c + '|'
            + inv.Sales_Order__r.Unit__r.Phase__r.Name + '|' + iw.TrxnType;

        if (inv.InvoiceAmount__c != null) {
            iw.Amount = iw.TrxnType == 'MODON_FEE' || iw.TrxnType == 'NOC_FEE'
                ? String.valueOf(inv.Actual_Invoice_Amount__c) : String.valueOf(inv.InvoiceAmount__c); // 19.0
        }
        iw.InvoiceDate = inv.InvoiceDate__c != null ? Date.valueOf(inv.InvoiceDate__c) : System.today();
        iw.GlDate = inv.Ebs_Invoice_Date__c != null ? inv.Ebs_Invoice_Date__c : System.today();

        if (inv.Transaction_Type__c == 'Customer Refund' && inv.RecordType.Name == 'Debit Memo') {
            //20.0 - Customer refund bank details
            applyCustomerRefundFields(iw, inv, accountIbanUrlMap);
        }
        return iw;
    }

    /**
     * Description : Applies the Invoice__c / Account fields that are identical for both installment branches.
     */
    private static void applyInvoiceFields(OIC_RequestWrapperController.InstallmentWrapper iw, Invoice__c inv) {
        iw.Sfid = inv.Id;
        iw.CustomerSfid = inv.Account__c;
        iw.CustomerPartyId = inv.Account__r.OraclePartyId__c;
        iw.InstallmentNumber = inv.Name;
        iw.OrgIdentifier = UserInfo.getOrganizationId();
    }

    /**
     * Description : Applies the Sales Order driven fields (escrow, unit, virtual account, project and Oracle
     *               site details) shared by both installment branches. The Sales Order is resolved by the
     *               caller either from the Sales Order Installment or from the invoice directly.
     */
    private static void applySalesOrderFields(OIC_RequestWrapperController.InstallmentWrapper iw, SalesOrder__c so) {
        iw.SoReference = so.Name;
        iw.EscrowAccountNumber  = so.VirtualAccount__r.EscrowAccount__r.AccountNumber__c;
        iw.EscrowIbanNumber     = so.VirtualAccount__r.EscrowAccount__r.IBANNo__c;
        iw.EscrowStoreId        = so.VirtualAccount__r.EscrowAccount__r.StoreId__c;
        iw.EscrowSwiftCode      = so.VirtualAccount__r.EscrowAccount__r.SwiftCode__c;
        iw.EscrowTradeId        = so.VirtualAccount__r.EscrowAccount__r.TradeID__c;
        iw.EscrowBankName       = so.VirtualAccount__r.EscrowAccount__r.BankName__c;
        iw.EscrowBenificaryName = so.VirtualAccount__r.EscrowAccount__r.BeneficiaryName__c;
        iw.VirtualAccountNumber = so.VirtualAccount__r.VirtualAccountNumber__c;
        iw.VirtualIbanNumber    = so.VirtualAccount__r.VirtualIBANNumber__c;
        iw.VirtualAccountName   = so.VirtualAccount__r.Name; //14.0
        iw.Unit = so.Unit__r.PlotNo__c;
        iw.ExtraInfo1 = so.Unit__r.PlotNo__c;
        iw.UnitName = so.Unit__r.Name;
        iw.UnitSfId = so.Unit__c;
        iw.ProjectName = so.Unit__r.Project_Name__c;
        // 16.0 - Hudayriyat Golf Estates project changes
        if (so.Unit__r.Project_Name__c == 'Hudayriyat Golf Estates') {
            iw.ExtraInfo2 = so.Unit__r.Project_Name__c + '-' + so.Unit__r.UnitClassification__c;
        } else {
            iw.ExtraInfo2 = so.Unit__r.Project_Name__c == 'Commercial Plots' ? so.Unit__r.Name
                : so.Unit__r.Project_Name__c + '-' + so.Unit__r.Phase__r.Name; //12.0
        }
        iw.ProjectPhase = so.Unit__r.Phase__r.Name;
        iw.EntityName   = so.Unit__r.Phase__r.EntityName__c;
        iw.CustAcctId           = so.CustAcctId__c;
        iw.OraclePartySiteID    = so.OraclePartySiteID__c;
        iw.OracleCustAcctSiteID = so.OracleCustAcctSiteID__c;
        iw.OracleSiteUseID      = so.OracleSiteUseID__c;
    }

    /**
     * Description : 20.0 - Applies the customer refund transaction type and the customer's bank details,
     *               including the 'IBAN Letter' public URL resolved by the caller.
     */
    private static void applyCustomerRefundFields(OIC_RequestWrapperController.InstallmentWrapper iw,
            Invoice__c inv, Map<Id,String> accountIbanUrlMap) {
        iw.RefundOracleId = inv.RefundOracleid__c;
        iw.TrxnType = 'REFOUND';
        iw.CustomerAccountNumber  = inv.Account__r.Bank_Account_Number__c;
        iw.CustomerIbanNumber     = inv.Account__r.IBAN_Number__c;
        iw.CustomerSwiftCode      = inv.Account__r.Swift_Code__c;
        iw.CustomerBankName       = inv.Account__r.Bank_Name__c;
        iw.CustomerBenificaryName = inv.Account__r.Beneficiary_Name__c;
        iw.CustomerBankAcctURL = accountIbanUrlMap != null && accountIbanUrlMap.containsKey(inv.Account__c)
            ? accountIbanUrlMap.get(inv.Account__c) : null;
    }

    // ── Advance Tax creation wrappers ─────────────────────────────────────────

    /**
     * Description : Builds the Advance Tax Invoice ('ADV_TAX') creation payloads for Invoice__c records
     *               (Transaction_Type__c = 'Advance Tax'). Sent as a normal creation: CreditMemoFlag = 'N'
     *               and Status carries the invoice's current InvoiceStatus__c (contrast with
     *               generateAdvanceTaxCancellationWrappers, which sends the same shape as a cancellation).
     *               The Sales Order to source escrow/unit/virtual-account/Oracle-site fields from is
     *               resolved with Sales_Order__c taking priority: when usesSalesOrder(inv), fields come
     *               directly from Sales_Order__r; otherwise, when usesSalesOrderInstallment(inv), fields
     *               come from SalesOrderInstallment__r.SalesOrder__r. An invoice matching neither is not
     *               eligible for the Oracle feed and is skipped.
     *               The Allocation__c a given invoice was raised from can be ambiguous (a source Invoice may
     *               carry several), so it must already be resolved by the caller and supplied via
     *               allocationByInvoiceId.
     * @param advanceTaxInvoices    Advance Tax Invoice__c records to create.
     * @param allocationByInvoiceId Map of Advance Tax Invoice Id to the Allocation__c it was raised from.
     * @return List<AdvanceTaxInvoiceWrapper.RequestWrapper> creation payloads.
     */
    public static List<AdvanceTaxInvoiceWrapper.RequestWrapper> generateAdvanceTaxCreationWrappers(
            List<Invoice__c> advanceTaxInvoices, Map<Id, Allocation__c> allocationByInvoiceId) {

        List<AdvanceTaxInvoiceWrapper.RequestWrapper> requestLst = new List<AdvanceTaxInvoiceWrapper.RequestWrapper>();

        for (Invoice__c inv : advanceTaxInvoices) {
            Id soSfid;
            SalesOrder__c so;
            if (usesSalesOrder(inv)) {
                soSfid = inv.Sales_Order__c;
                so = inv.Sales_Order__r;
            } else if (usesSalesOrderInstallment(inv)) {
                soSfid = inv.SalesOrderInstallment__r.SalesOrder__c;
                so = inv.SalesOrderInstallment__r.SalesOrder__r;
            } else {
                continue;
            }

            AdvanceTaxInvoiceWrapper.RequestWrapper w = new AdvanceTaxInvoiceWrapper.RequestWrapper();

            w.Sfid = inv.Id;
            w.CustomerSfid = inv.Account__c;
            w.CustomerPartyId = inv.Account__r.OraclePartyId__c;
            w.SoSfid = soSfid;
            w.SoReference = so.Name;
            w.EscrowAccountNumber  = so.VirtualAccount__r.EscrowAccount__r.AccountNumber__c;
            w.EscrowIbanNumber     = so.VirtualAccount__r.EscrowAccount__r.IBANNo__c;
            w.EscrowStoreId        = so.VirtualAccount__r.EscrowAccount__r.StoreId__c;
            w.EscrowSwiftCode      = so.VirtualAccount__r.EscrowAccount__r.SwiftCode__c;
            w.EscrowTradeId        = so.VirtualAccount__r.EscrowAccount__r.TradeID__c;
            w.EscrowBankName       = so.VirtualAccount__r.EscrowAccount__r.BankName__c;
            w.EscrowBenificaryName = so.VirtualAccount__r.EscrowAccount__r.BeneficiaryName__c;
            w.Unit = so.Unit__r.PlotNo__c;
            w.PlotNumber = so.Unit__r.PlotNo__c;
            w.UnitName = so.Unit__r.Name;
            w.UnitSfId = so.Unit__c;
            w.VirtualAccountNumber = so.VirtualAccount__r.VirtualAccountNumber__c;
            w.VirtualIbanNumber    = so.VirtualAccount__r.VirtualIBANNumber__c;
            w.VirtualAccountName   = so.VirtualAccount__r.Name;
            w.ProjectName  = so.Unit__r.Project_Name__c;
            w.ProjectPhase = so.Unit__r.Phase__r.Name;
            w.EntityName   = so.Unit__r.Phase__r.EntityName__c;
            w.CustAcctId            = so.CustAcctId__c;
            w.OraclePartySiteID     = so.OraclePartySiteID__c;
            w.OracleCustAcctSiteID  = so.OracleCustAcctSiteID__c;
            w.OracleSiteUseID       = so.OracleSiteUseID__c;

            w.TrxnType = TRXN_TYPE_ADV_TAX;
            w.Status = inv.InvoiceStatus__c;
            w.CreditMemoFlag = 'N';

            if (inv.InvoiceAmount__c != null) {
                w.Amount = String.valueOf(inv.InvoiceAmount__c);
            }
            w.InvoiceDate = inv.InvoiceDate__c;
            w.GlDate = inv.Ebs_Invoice_Date__c != null ? inv.Ebs_Invoice_Date__c : System.today();
            w.OrgIdentifier = UserInfo.getOrganizationId();

            w.ParentInvoicesfId = inv.Invoice_Advance__r.Parent_Invoice__c;
            if (inv.Invoice_Advance__r != null) {
                w.InstallmentNumber = inv.Invoice_Advance__r.Name;
                w.AdvInstallmentNumber = 'ADV-'+inv.Name;
            }

            w.Description = so.Unit__r.Project_Name__c+ '|' + so.Unit__r.Phase__r.Name + '|' + TRXN_TYPE_ADV_TAX;

            applyReceiptFields(w, allocationByInvoiceId != null ? allocationByInvoiceId.get(inv.Id) : null);

            requestLst.add(w);
        }
        return requestLst;
    }

    /**
     * Description : Applies the Allocation / Receipt sourced fields (ReceiptSFID, FusionReceiptID,
     *               AllocAmount) shared by the Advance Tax creation and cancellation payloads. The
     *               Allocation the Advance Tax Invoice was raised from is resolved by the caller by
     *               walking Invoice__c.Invoice_Advance__c (the source Invoice) -> Allocation__c -> Receipt__c.
     *               UnAllocAmount is not set here - it is cancellation-only and stamped by
     *               generateAdvanceTaxCancellationWrappers.
     */
    private static void applyReceiptFields(AdvanceTaxInvoiceWrapper.RequestWrapper w, Allocation__c alloc) {
        if (alloc == null) return;
        w.ReceiptSFID = alloc.Receipt__c;
        w.FusionReceiptID = alloc.Receipt__r != null ? alloc.Receipt__r.OraclePartyId__c : null;
        if (alloc.AllocationAmount__c != null) {
            w.AllocAmount = String.valueOf(alloc.AllocationAmount__c);
        }
    }

    // ── Advance Tax cancellation wrappers ─────────────────────────────────────

    /**
     * Description : Builds the Advance Tax cancellation payloads for Advance Tax Invoice__c records that are
     *               already synced to Oracle. The field mapping mirrors generateAdvanceTaxCreationWrappers,
     *               but the record is sent as a cancellation: TrxnType stays 'ADV_TAX' so Oracle routes it
     *               to the Advance Tax service,
     *               while CreditMemoFlag = 'Y' / Status = 'Cancelled' signal the cancellation and
     *               CreditMemoApplyInvoiceId carries the Oracle Id of the invoice being cancelled.
     *               ReceiptSFID / FusionReceiptID / AllocAmount / UnAllocAmount are sourced the same way
     *               as generateAdvanceTaxCreationWrappers: from the Allocation__c (with its Receipt__c) the
     *               Advance Tax Invoice was raised from, resolved by the caller and supplied via
     *               allocationByInvoiceId.
     * @param advanceTaxInvoices    Advance Tax Invoice__c records to cancel.
     * @param allocationByInvoiceId Map of Advance Tax Invoice Id to the Allocation__c it was raised from.
     * @return List<AdvanceTaxInvoiceWrapper.RequestWrapper> cancellation payloads.
     */
    public static List<AdvanceTaxInvoiceWrapper.RequestWrapper> generateAdvanceTaxCancellationWrappers(
            List<Invoice__c> advanceTaxInvoices, Map<Id, Allocation__c> allocationByInvoiceId) {

        List<AdvanceTaxInvoiceWrapper.RequestWrapper> requestLst = new List<AdvanceTaxInvoiceWrapper.RequestWrapper>();

        for (Invoice__c inv : advanceTaxInvoices) {
            AdvanceTaxInvoiceWrapper.RequestWrapper w = new AdvanceTaxInvoiceWrapper.RequestWrapper();

            w.Sfid = inv.Id;
            w.CustomerSfid = inv.Account__c;
            w.CustomerPartyId = inv.Account__r.OraclePartyId__c;
            w.SoSfid = inv.Sales_Order__c;
            w.SoReference = inv.Sales_Order__r.Name;
            w.EscrowAccountNumber  = inv.Sales_Order__r.VirtualAccount__r.EscrowAccount__r.AccountNumber__c;
            w.EscrowIbanNumber     = inv.Sales_Order__r.VirtualAccount__r.EscrowAccount__r.IBANNo__c;
            w.EscrowStoreId        = inv.Sales_Order__r.VirtualAccount__r.EscrowAccount__r.StoreId__c;
            w.EscrowSwiftCode      = inv.Sales_Order__r.VirtualAccount__r.EscrowAccount__r.SwiftCode__c;
            w.EscrowTradeId        = inv.Sales_Order__r.VirtualAccount__r.EscrowAccount__r.TradeID__c;
            w.EscrowBankName       = inv.Sales_Order__r.VirtualAccount__r.EscrowAccount__r.BankName__c;
            w.EscrowBenificaryName = inv.Sales_Order__r.VirtualAccount__r.EscrowAccount__r.BeneficiaryName__c;
            w.Unit = inv.Sales_Order__r.Unit__r.PlotNo__c;
            w.PlotNumber = inv.Sales_Order__r.Unit__r.PlotNo__c;
            w.UnitName = inv.Sales_Order__r.Unit__r.Name;
            w.UnitSfId = inv.Sales_Order__r.Unit__c;
            w.VirtualAccountNumber = inv.Sales_Order__r.VirtualAccount__r.VirtualAccountNumber__c;
            w.VirtualIbanNumber    = inv.Sales_Order__r.VirtualAccount__r.VirtualIBANNumber__c;
            w.VirtualAccountName   = inv.Sales_Order__r.VirtualAccount__r.Name;
            w.ProjectName  = inv.Sales_Order__r.Unit__r.Project_Name__c;
            w.ProjectPhase = inv.Sales_Order__r.Unit__r.Phase__r.Name;
            w.EntityName   = inv.Sales_Order__r.Unit__r.Phase__r.EntityName__c;
            w.CustAcctId            = inv.Sales_Order__r.CustAcctId__c;
            w.OraclePartySiteID     = inv.Sales_Order__r.OraclePartySiteID__c;
            w.OracleCustAcctSiteID  = inv.Sales_Order__r.OracleCustAcctSiteID__c;
            w.OracleSiteUseID       = inv.Sales_Order__r.OracleSiteUseID__c;

            // Cancellation flags - same contract the invoice credit memo flow uses
            w.TrxnType                 = 'CREDIT_MEMO';
            w.CreditMemoFlag           = 'Y';
            w.Status                   = 'Cancelled';
            w.CreditMemoApplyInvoiceId = inv.OraclePartyId__c;
            w.GlDate                   = System.today();

            if (inv.InvoiceAmount__c != null) {
                w.Amount = String.valueOf(inv.InvoiceAmount__c);
            }
            w.InvoiceDate = inv.InvoiceDate__c;
            w.OrgIdentifier = UserInfo.getOrganizationId();

            w.ParentInvoicesfId = inv.Invoice_Advance__r.Parent_Invoice__c;
            if (inv.Invoice_Advance__r != null) {
                w.InstallmentNumber = 'ADV-'+inv.Name;
                w.AdvInstallmentNumber = 'ADV-'+inv.Name;
            }
            w.Description = inv.Sales_Order__r.Unit__r.Project_Name__c+ '|' + inv.Sales_Order__r.Unit__r.Phase__r.Name + '|' + TRXN_TYPE_ADV_TAX;

            Allocation__c alloc = allocationByInvoiceId != null ? allocationByInvoiceId.get(inv.Id) : null;
            //applyReceiptFields(w, alloc);
            // Cancellation-only: UnAllocAmount carries the same allocated amount as AllocAmount
            if (alloc != null && alloc.AllocationAmount__c != null) {
                w.ReceiptSFID = alloc.Receipt__c;
                w.FusionReceiptID = alloc.Receipt__r != null ? alloc.Receipt__r.OraclePartyId__c : null;
                w.UnAllocAmount = String.valueOf(alloc.AllocationAmount__c);
            }

            requestLst.add(w);
        }
        return requestLst;
    }
}