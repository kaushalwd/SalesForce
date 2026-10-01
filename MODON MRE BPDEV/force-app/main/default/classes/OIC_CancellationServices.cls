/**********************************************************************************************************************
* Name               : OIC_CancellationServices                                                        
* Description        : This class contains main integration methods for Oracle-Salesforce integration callouts.
* Usage              : Used across Batch classes.
* Created By         : ActiveMinds                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Manoj		   	          15 March 2026     Initial Draft
* 2.0           Manoj                     19 April 2026     Added NoDml variants for batch usage
* 3.0           Manoj                     19 April 2026     Removed unused original DML methods (no trigger callers)
* 4.0			Manoj					  14 May   2026		Add Fusion process
* 5.0           Manoj					  05 May   2026		Add Hudayriyat Golf Estates project change
* 6.0			Manoj					  12 Jun   2026		Update SOQL
***********************************************************************************************************************/
public class OIC_CancellationServices {

    /**************************************
    // INNER WRAPPER — carries parsed record + staged logs (no DML)
     * CalloutResult is the return object for all NoDml methods.
     * Instead of saving inside the method, we stage everything here
     * and let the batch finish() method handle all DML in one shot.
     * hasError flag tells the caller whether the callout failed so it
     * can decide whether to commit or skip the record.
     */
    public class CalloutResult {
        public SObject  record;
        public SObject  apiLog;
        public SObject  errorLog;
        public Boolean  hasError = false;
    }

    // **************************************
    // PUBLIC — NoDml variants (used by EBSCancellationBatch only)
    // All callouts + parsing happen here. Zero DML. Zero LoggerService.save().
    // Caller collects the CalloutResult and defers all DML to finish().
    // **************************************

    /*
     * Sends a single Invoice/Installment record to Oracle Fusion via OIC.
     * We only pick up invoices where OraclePartyId is still null (not yet
     * synced) OR where the status is Cancelled (credit memo flow).
     * No DML happens here — the parsed Invoice__c and staged logs are
     * returned inside CalloutResult for the batch to commit later.
     */
    public static CalloutResult cancellationInstallmentNoDml(Id installmentId) {
        CalloutResult result       = new CalloutResult();
        Invoice__c invoiceToUpdate = new Invoice__c(Id = installmentId);
        result.record              = invoiceToUpdate;

        try {
            // Pull all the fields Oracle needs — both the SalesOrderInstallment
            // path and the direct SalesOrder path are fetched here because the
            // wrapper builder decides which path to use at runtime
            // 4.0 add new fields in SOQL
            // 5.0 add new fields in SOQL
            List<Invoice__c> installmentLst = [
                SELECT Id, Name, InvoiceAmount__c, Ebs_Invoice_Date__c, InvoiceDate__c,
                       InvoiceStatus__c, Account__c, Account__r.OraclePartyId__c,
                       Sales_Order__c, Sales_Order__r.name,
                       SalesOrderInstallment__c, SalesOrderInstallment__r.MilestoneDescription__c,
                       SalesOrderInstallment__r.SalesOrder__c,SalesOrderInstallment__r.Name,
                       SalesOrderInstallment__r.SalesOrder__r.VirtualAccount__r.EscrowAccount__r.AccountNumber__c,
                       SalesOrderInstallment__r.SalesOrder__r.VirtualAccount__r.EscrowAccount__r.IBANNo__c,
                       SalesOrderInstallment__r.SalesOrder__r.VirtualAccount__r.EscrowAccount__r.StoreId__c,
                       SalesOrderInstallment__r.SalesOrder__r.VirtualAccount__r.EscrowAccount__r.SwiftCode__c,
                       SalesOrderInstallment__r.SalesOrder__r.VirtualAccount__r.EscrowAccount__r.TradeID__c,
                       SalesOrderInstallment__r.SalesOrder__r.VirtualAccount__r.EscrowAccount__r.BankName__c,
                       SalesOrderInstallment__r.SalesOrder__r.VirtualAccount__r.EscrowAccount__r.BeneficiaryName__c,
                       SalesOrderInstallment__r.SalesOrder__r.Unit__c, SalesOrderInstallment__r.SalesOrder__r.Name,
                       SalesOrderInstallment__r.SalesOrder__r.Unit__r.Name,
                       SalesOrderInstallment__r.SalesOrder__r.VirtualAccount__r.VirtualAccountNumber__c,
                       SalesOrderInstallment__r.SalesOrder__r.VirtualAccount__r.VirtualIBANNumber__c,SalesOrderInstallment__r.SalesOrder__r.VirtualAccount__r.Name,
                       SalesOrderInstallment__r.SalesOrder__r.Unit__r.Project_Name__c,
                       SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__r.EntityName__c,
                       SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__r.Name,
                       SalesOrderInstallment__r.Milestone_Name__c,
                       SalesOrderInstallment__r.SalesOrder__r.Unit__r.PlotNo__c,
                       SalesOrderInstallment__r.SalesOrder__r.CustAcctId__c,
                       SalesOrderInstallment__r.SalesOrder__r.OraclePartySiteID__c,
                       SalesOrderInstallment__r.SalesOrder__r.OracleCustAcctSiteID__c,
                       SalesOrderInstallment__r.SalesOrder__r.OracleSiteUseID__c,
                       Sales_Order__r.VirtualAccount__r.EscrowAccount__r.AccountNumber__c,
                       Sales_Order__r.VirtualAccount__r.EscrowAccount__r.IBANNo__c,
                       Sales_Order__r.VirtualAccount__r.EscrowAccount__r.StoreId__c,
                       Sales_Order__r.VirtualAccount__r.EscrowAccount__r.SwiftCode__c,
                       Sales_Order__r.NotToBeShownOnRD__c, Sales_Order__r.Source_Entity__c,
                       Sales_Order__r.VirtualAccount__r.EscrowAccount__r.TradeID__c,
                       Sales_Order__r.VirtualAccount__r.EscrowAccount__r.BankName__c,
                       Sales_Order__r.VirtualAccount__r.EscrowAccount__r.BeneficiaryName__c,
                       Sales_Order__r.Unit__r.PlotNo__c,
                       SalesOrderInstallment__r.SalesOrder__r.NotToBeShownOnRD__c,
                       SalesOrderInstallment__r.SalesOrder__r.Source_Entity__c,
                       Sales_Order__r.Unit__r.Name, Sales_Order__r.Unit__c,
                       Sales_Order__r.VirtualAccount__r.VirtualAccountNumber__c,
                       Sales_Order__r.VirtualAccount__r.VirtualIBANNumber__c,
                       Sales_Order__r.Unit__r.Project_Name__c,
                       Sales_Order__r.Unit__r.Phase__r.Name,
                       Sales_Order__r.Unit__r.Phase__r.EntityName__c,Sales_Order__r.VirtualAccount__r.Name,
                       Charge__r.Type__c, Sales_Order__r.CustAcctId__c,
                       RefundOracleid__c, Sales_Order__r.OraclePartySiteID__c,
                       Sales_Order__r.OracleCustAcctSiteID__c, Sales_Order__r.OracleSiteUseID__c,Is_ADM_Fees_and_Dari_charges__c,
                       Actual_Invoice_Amount__c, OraclePartyId__c,
                       Parent_Invoice__c, RecordType.name, Parent_Invoice__r.OraclePartyId__c,SalesOrderInstallment__r.SalesOrder__r.Unit__r.UnitClassification__c,
                       Sales_Order__r.Unit__r.UnitClassification__c                        
                FROM Invoice__c
                WHERE Id = :installmentId
                  AND (OraclePartyId__c = null OR InvoiceStatus__c = 'Cancelled')
            ];

            // invCrdMap tracks credit memo invoices so the parser knows to stamp
            // Oracle_Credit_Memo_Id__c instead of OraclePartyId__c on success.
            // refundinvMap tracks Debit Memo refund invoices for the same reason.
            Map<Id, Boolean> invCrdMap    = new Map<Id, Boolean>();
            Map<Id, Boolean> refundinvMap = new Map<Id, Boolean>();
            List<OIC_RequestWrapperController.InstallmentWrapper> installmentWrapLst =
                buildInstallmentWrappers(installmentLst, invCrdMap, refundinvMap);

            // Credentials (endpoint URL + auth headers) come from a named
            // credential record — keeps secrets out of code
            HttpRequest req = OIC_CredentialsController.getCredentials('ModonFusionInstallmentAPI');
            req.setTimeout(120000);

            // Wrap the payload in Base64 as required by the OIC integration contract
            OIC_RequestWrapperController.InstallmentWrapperLst wrapperList =
                new OIC_RequestWrapperController.InstallmentWrapperLst();
            wrapperList.RequestArray = installmentWrapLst;

            String requestBody  = JSON.serialize(wrapperList);
            String base64String = EncodingUtil.base64Encode(Blob.valueOf(requestBody));
            OIC_RequestWrapperController.Base64Wrapper wrapper =
                new OIC_RequestWrapperController.Base64Wrapper();
            wrapper.Base64RequestPayload = base64String;
            req.setBody(JSON.serialize(wrapper));
            req.setHeader('Accept', 'application/json');

            HTTPResponse res       = new Http().send(req);
            String decodedResponse = decodeBase64Response(res.getBody());

            // ************************************** Parse only — no DML **************************************
            result.record  = parseInstallmentResponseNoDml(decodedResponse, invCrdMap, refundinvMap);

            // ************************************** Stage log — no save() **************************************
            result.apiLog  = LoggerService.createAPILog(
                'Invoice API', 'OIC_CancellationServices', 'cancellationInstallmentNoDml',
                requestBody, decodedResponse,
                'Status Code: ' + res.getStatusCode() + '; Status: ' + res.getStatus(),
                'Callout Log');

        } catch (Exception ex) {
            // Mark the result as an error so the batch can skip DML for this
            // record and still continue processing the rest of the batch scope
            Invoice__c errRec               = new Invoice__c(Id = installmentId);
            errRec.OICIntegrationStatus__c  = 'E';
            errRec.OICIntegrationMessage__c = ex.getMessage();
            result.record                   = errRec;
            result.hasError                 = true;
            result.errorLog                 = LoggerService.createApexLog(
                ex, 'Invoice API', 'OIC_CancellationServices', 'cancellationInstallmentNoDml');
        }
        return result;
    }

    // *********************************************************************

    /*
     * Sends a single Receipt record to Oracle Fusion via OIC.
     * Receipts tied to Egypt entity or flagged NotToBeShownOnRD are excluded
     * at the SOQL level — Oracle does not handle those records.
     * Note: this method re-throws the exception after logging it so the
     * batch caller knows a fatal error occurred for this receipt.
     **********************************************************************/
    public static CalloutResult cancellationReceiptNoDml(Id receiptId) {
        CalloutResult result      = new CalloutResult();
        Receipt__c recordToUpdate = new Receipt__c(Id = receiptId);
        result.record             = recordToUpdate;

        try {
            // Filter out Egypt entity and NotToBeShownOnRD at query time
            // to avoid sending records Oracle will reject
            // 4.0 Add fields to SOQL
            // 5.0 Add 
            List<Receipt__c> recLst = [SELECT Id, Name, Receipt_Amount__c,Receipt_Approved_Date__c,Account__c, SalesOrder__c, SalesOrderInstallment__c, AppliedAmount__c,
                                       SalesOrder__r.ProjectName__c,SalesOrderInstallment__r.SalesOrder__r.ProjectName__c,SalesOrder__r.Name,SalesOrderInstallment__r.SalesOrder__r.Name,
                                       PaymentEscrowAccount__c, PaymentEscrowAccount__r.AccountNumber__c, TransactionDate__c,
                                       PaymentEscrowAccount__r.IBANNo__c, PaymentEscrowAccount__r.Name, TransactionNumber__c, ExpressionOfInterest__c,
                                       Modeofpayment__c, ReceiptDate__c,ChequeDate__c, TotalAmount__c, Bank__c, Status__c, SalesOrder__r.Unit__r.Name, SalesOrder__r.Unit__c,Account__r.OraclePartyId__c,
                                       SalesOrder__r.VirtualAccount__r.VirtualAccountNumber__c, SalesOrder__r.VirtualAccount__r.VirtualIBANNumber__c,
                                       SalesOrderInstallment__r.Milestone_Name__c, Milestone_Description__c,SalesOrderInstallment__r.Name,
                                       SalesOrder__r.Unit__r.Project_Name__c, SalesOrderInstallment__r.SalesOrder__r.Unit__r.Project_Name__c,SalesOrderInstallment__r.SalesOrder__r.Unit__c,
                                       SalesOrder__r.Unit__r.Phase__r.Name, SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__r.Name,
                                       SalesOrder__r.Unit__r.Phase__r.EntityName__c, SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__r.EntityName__c,
                                       EBS_Clearing_Date__c, Charge__r.Type__c, Cheque_Number__c, SalesOrder__r.CustAcctId__c, SalesOrder__r.OraclePartySiteID__c,
                                       SalesOrder__r.OracleCustAcctSiteID__c, SalesOrder__r.OracleSiteUseID__c, SalesOrder__r.NotToBeShownOnRD__c,
                                       Cheque_Bounce_Reason__c, Reason_Code__c, OraclePartyId__c, isReverseEBS__c, RecordType.name, Transaction_Type__c,SalesOrderInstallment__r.SalesOrder__r.Unit__r.UnitClassification__c,SalesOrder__r.Unit__r.UnitClassification__c
                                        FROM Receipt__c
                                        WHERE Id = :receiptId
                                          AND SalesOrder__r.NotToBeShownOnRD__c = false
                                          AND SalesOrder__r.Source_Entity__c != 'Modon - Egypt'
                                    ];

            // receiptMap flags receipts that have an approval date — those get
            // written to Oracle_Id_Temporary__c instead of OraclePartyId__c
            // until the approval is confirmed on the Oracle side
            Map<Id, Boolean> receiptMap = new Map<Id, Boolean>();
            List<OIC_RequestWrapperController.ReceiptWrapper> receiptWrapLst =
                buildReceiptWrappers(recLst, receiptMap);

            HttpRequest req = OIC_CredentialsController.getCredentials('ModonFusionReceiptAPI');
            req.setTimeout(120000);

            OIC_RequestWrapperController.ReceiptWrapperLst wrapperList =
                new OIC_RequestWrapperController.ReceiptWrapperLst();
            wrapperList.RequestArray = receiptWrapLst;

            String requestBody  = JSON.serialize(wrapperList);
            String base64String = EncodingUtil.base64Encode(Blob.valueOf(requestBody));
            OIC_RequestWrapperController.Base64Wrapper wrapper =
                new OIC_RequestWrapperController.Base64Wrapper();
            wrapper.Base64RequestPayload = base64String;
            req.setBody(JSON.serialize(wrapper));
            req.setHeader('Accept', 'application/json');

            HTTPResponse res       = new Http().send(req);
            String decodedResponse = decodeBase64Response(res.getBody());

            // ************************************** Parse only — no DML ****************************************************************************
            result.record  = parseReceiptResponseNoDml(decodedResponse, receiptMap);

            // ************************************** Stage log — no save() **************************************
            result.apiLog  = LoggerService.createAPILog(
                'Receipt API', 'OIC_CancellationServices', 'cancellationReceiptNoDml',
                requestBody, decodedResponse,
                'Status Code: ' + res.getStatusCode() + '; Status: ' + res.getStatus(),
                'Callout Log');

        } catch (Exception ex) {
            Receipt__c errRec               = new Receipt__c(Id = receiptId);
            errRec.OICIntegrationStatus__c  = 'E';
            errRec.OICIntegrationMessage__c = ex.getMessage();
            result.record                   = errRec;
            result.hasError                 = true;
            result.errorLog                 = LoggerService.createApexLog(
                ex, 'Receipt API', 'OIC_CancellationServices', 'cancellationReceiptNoDml');
            // Re-throw so the batch execute() knows this receipt failed hard
            // and can handle it separately from a soft Oracle error response
            throw ex;
        }
        return result;
    }

    // ********************************************************************

    /*
     * Sends a single Allocation record to Oracle Fusion via OIC.
     * We only process allocations where the Allocation itself has no
     * OraclePartyId yet but both the parent Receipt and Invoice already
     * have one — Oracle needs those IDs to create the application.
     **********************************************************************/
    public static CalloutResult cancellationAllocationNoDml(Id allocationId) {
        CalloutResult result             = new CalloutResult();
        Allocation__c allocationToUpdate = new Allocation__c(Id = allocationId);
        result.record                    = allocationToUpdate;

        try {
            // Only fetch allocations where both Receipt and Invoice are already
            // in Oracle — no point sending if the parent records aren't there yet
            // 6.0
            List<Allocation__c> allocationLst = [
                SELECT Id, Name, Receipt__c, Invoice__c,
                       Receipt__r.TotalAmount__c, Receipt__r.OraclePartyId__c,
                       Invoice__r.Ebs_Invoice_Date__c, Invoice__r.OraclePartyId__c,
                       AllocationAmount__c, AllocationDate__c, Status__c,
                       Receipt__r.SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__r.Name,
                       Receipt__r.SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__r.EntityName__c,
                       Receipt__r.SalesOrderInstallment__r.SalesOrder__r.Unit__r.Project_Name__c,
                       Receipt__r.SalesOrder__r.Unit__r.Phase__r.Name,
                       Receipt__r.SalesOrder__r.Unit__r.Phase__r.EntityName__c
                FROM Allocation__c
                WHERE Id = :allocationId
                  AND OraclePartyId__c != null
                  AND Receipt__r.OraclePartyId__c != null
                  AND Invoice__r.OraclePartyId__c != null
                  AND Receipt__r.SalesOrderInstallment__r.SalesOrder__r.NotToBeShownOnRD__c = false
                  AND Receipt__r.SalesOrderInstallment__r.SalesOrder__r.Source_Entity__c != 'Modon - Egypt'
            ];

            List<OIC_RequestWrapperController.AllocationWrapper> allocationWrapLst =
                buildAllocationWrappers(allocationLst);

            HttpRequest req = OIC_CredentialsController.getCredentials('ModonFusionAllocationAPI');
            req.setTimeout(120000);

            OIC_RequestWrapperController.AllocationWrapperLst wrapperList =
                new OIC_RequestWrapperController.AllocationWrapperLst();
            wrapperList.RequestArray = allocationWrapLst;

            String requestBody  = JSON.serialize(wrapperList);
            String base64String = EncodingUtil.base64Encode(Blob.valueOf(requestBody));
            OIC_RequestWrapperController.Base64Wrapper wrapper =
                new OIC_RequestWrapperController.Base64Wrapper();
            wrapper.Base64RequestPayload = base64String;
            req.setBody(JSON.serialize(wrapper));
            req.setHeader('Accept', 'application/json');

            HTTPResponse res       = new Http().send(req);
            String decodedResponse = decodeBase64Response(res.getBody());

            // ************************************** Parse only — no DML ****************************************************************************
            result.record  = parseAllocationResponseNoDml(decodedResponse);

            // ************************************** Stage log — no save() **************************************
            result.apiLog  = LoggerService.createAPILog(
                'Allocation API', 'OIC_CancellationServices', 'cancellationAllocationNoDml',
                requestBody, decodedResponse,
                'Status Code: ' + res.getStatusCode() + '; Status: ' + res.getStatus(),
                'Callout Log');

        } catch (Exception ex) {
            Allocation__c errRec            = new Allocation__c(Id = allocationId);
            errRec.OICIntegrationStatus__c  = 'E';
            errRec.OICIntegrationMessage__c = ex.getMessage();
            result.record                   = errRec;
            result.hasError                 = true;
            result.errorLog                 = LoggerService.createApexLog(
                ex, 'Allocation API', 'OIC_CancellationServices', 'cancellationAllocationNoDml');
        }
        return result;
    }

    // **************************************
    // PRIVATE — Wrapper Builders
    // **************************************

    /*
     * Builds the Oracle request payload for Invoice/Installment records.
     *
     * Two routing paths exist inside this method:
     *   Path A — Invoice is linked to a SalesOrderInstallment (standard installment plan).
     *            Uses the installment's Sales Order for escrow, unit, and site IDs.
     *   Path B — Invoice is linked directly to a Sales Order (charge-based invoice).
     *            TrxnType is resolved from the ChargeTypeToTrxnType__mdt custom metadata.
     *
     * After the path is set, a second block determines the credit memo / debit memo
     * flags and populates invCrdMap / refundinvMap so the response parser knows
     * which Oracle ID field to stamp on the way back.
     ***************************************/
    private static List<OIC_RequestWrapperController.InstallmentWrapper> buildInstallmentWrappers(
        List<Invoice__c> installmentLst,
        Map<Id, Boolean> invCrdMap,
        Map<Id, Boolean> refundinvMap
    ) {
        List<OIC_RequestWrapperController.InstallmentWrapper> wrapLst =
            new List<OIC_RequestWrapperController.InstallmentWrapper>();

        // Load charge-type to transaction-type mapping from custom metadata
        // so we don't hardcode charge type strings here
        Map<String, String> chargeToTrxnMap = new Map<String, String>();
        for (ChargeTypeToTrxnType__mdt cfg : ChargeTypeToTrxnType__mdt.getAll().values()) {
            chargeToTrxnMap.put(cfg.ChargeType__c, cfg.TrxnType__c);
        }

        for (Invoice__c inv : installmentLst) {
            OIC_RequestWrapperController.InstallmentWrapper w =
                new OIC_RequestWrapperController.InstallmentWrapper();

            // Path A: installment-linked invoice — use the SalesOrderInstallment's
            // parent Sales Order for all Oracle identifiers
            if (inv.SalesOrderInstallment__c != null
                && inv.SalesOrderInstallment__r.SalesOrder__r.OraclePartySiteID__c != null
                && inv.SalesOrderInstallment__r.SalesOrder__r.OracleCustAcctSiteID__c != null
                && inv.SalesOrderInstallment__r.SalesOrder__r.NotToBeShownOnRD__c == false
                && inv.SalesOrderInstallment__r.SalesOrder__r.Source_Entity__c != 'Modon - Egypt') {

                w.Sfid                 = inv.Id;
                w.CustomerSfid         = inv.Account__c;
                w.CustomerPartyId      = inv.Account__r.OraclePartyId__c;
                w.SoIsfid              = inv.SalesOrderInstallment__c;
                w.SoIsfReference       = inv.SalesOrderInstallment__r.Name;
                w.SoSfid               = inv.SalesOrderInstallment__r.SalesOrder__c;
                w.EscrowAccountNumber  = inv.SalesOrderInstallment__r.SalesOrder__r.VirtualAccount__r.EscrowAccount__r.AccountNumber__c;
                w.EscrowIbanNumber     = inv.SalesOrderInstallment__r.SalesOrder__r.VirtualAccount__r.EscrowAccount__r.IBANNo__c;
                w.EscrowStoreId        = inv.SalesOrderInstallment__r.SalesOrder__r.VirtualAccount__r.EscrowAccount__r.StoreId__c;
                w.EscrowSwiftCode      = inv.SalesOrderInstallment__r.SalesOrder__r.VirtualAccount__r.EscrowAccount__r.SwiftCode__c;
                w.EscrowTradeId        = inv.SalesOrderInstallment__r.SalesOrder__r.VirtualAccount__r.EscrowAccount__r.TradeID__c;
                w.EscrowBankName       = inv.SalesOrderInstallment__r.SalesOrder__r.VirtualAccount__r.EscrowAccount__r.BankName__c;
                w.EscrowBenificaryName = inv.SalesOrderInstallment__r.SalesOrder__r.VirtualAccount__r.EscrowAccount__r.BeneficiaryName__c;
                w.Unit                 = inv.SalesOrderInstallment__r.SalesOrder__r.Unit__r.PlotNo__c;
                w.ExtraInfo1           = inv.SalesOrderInstallment__r.SalesOrder__r.Unit__r.PlotNo__c;
                w.UnitName             = inv.SalesOrderInstallment__r.SalesOrder__r.Unit__r.Name;
                w.UnitSfId             = inv.SalesOrderInstallment__r.SalesOrder__r.Unit__c;
                w.VirtualAccountNumber = inv.SalesOrderInstallment__r.SalesOrder__r.VirtualAccount__r.VirtualAccountNumber__c;
                w.VirtualIbanNumber    = inv.SalesOrderInstallment__r.SalesOrder__r.VirtualAccount__r.VirtualIBANNumber__c;
                w.ProjectName          = inv.SalesOrderInstallment__r.SalesOrder__r.Unit__r.Project_Name__c;
                //5.0
                if(inv.SalesOrderInstallment__r.SalesOrder__r.Unit__r.Project_Name__c == 'Hudayriyat Golf Estates'){
                    w.ExtraInfo2 = inv.SalesOrderInstallment__r.SalesOrder__r.Unit__r.Project_Name__c+'-'+inv.SalesOrderInstallment__r.SalesOrder__r.Unit__r.UnitClassification__c;
                 } else {
                    w.ExtraInfo2  = inv.SalesOrderInstallment__r.SalesOrder__r.Unit__r.Project_Name__c == 'Commercial Plots' ? inv.SalesOrderInstallment__r.SalesOrder__r.Unit__r.Name : inv.SalesOrderInstallment__r.SalesOrder__r.Unit__r.Project_Name__c
                            			+ '-' + inv.SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__r.Name;
                } 
                w.ProjectPhase         = inv.SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__r.Name;
                w.EntityName           = inv.SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__r.EntityName__c;
                w.CustAcctId           = inv.SalesOrderInstallment__r.SalesOrder__r.CustAcctId__c;
                w.OraclePartySiteID    = inv.SalesOrderInstallment__r.SalesOrder__r.OraclePartySiteID__c;
                w.OracleCustAcctSiteID = inv.SalesOrderInstallment__r.SalesOrder__r.OracleCustAcctSiteID__c;
                w.OracleSiteUseID      = inv.SalesOrderInstallment__r.SalesOrder__r.OracleSiteUseID__c;
                w.Description          = inv.SalesOrderInstallment__r.Milestone_Name__c;
                w.SoReference          = inv.SalesOrderInstallment__r.SalesOrder__r.Name;
                w.VirtualAccountName =inv.SalesOrderInstallment__r.SalesOrder__r.VirtualAccount__r.Name; // 4.0
                if (inv.InvoiceAmount__c != null)
                    w.Amount = String.valueOf(inv.InvoiceAmount__c);
                // Prefer InvoiceDate__c; fall back to Ebs_Invoice_Date__c; last resort today
                w.InvoiceDate = inv.InvoiceDate__c != null ? Date.valueOf(inv.InvoiceDate__c)
                    : inv.Ebs_Invoice_Date__c != null ? Date.valueOf(inv.Ebs_Invoice_Date__c)
                    : System.today();
                w.GlDate = inv.Ebs_Invoice_Date__c != null ? inv.Ebs_Invoice_Date__c : System.today();

            // Path B: direct Sales Order invoice — typically admin charges or fees
            } else if (inv.Sales_Order__r.OracleCustAcctSiteID__c != null
                    && inv.Sales_Order__r.OracleSiteUseID__c != null
                    && inv.Sales_Order__r.NotToBeShownOnRD__c == false
                    && inv.Sales_Order__r.Source_Entity__c != 'Modon - Egypt') {

                w.Sfid                 = inv.Id;
                w.CustomerSfid         = inv.Account__c;
                w.CustomerPartyId      = inv.Account__r.OraclePartyId__c;
                w.SoSfid               = inv.Sales_Order__c;
                w.SoReference          = inv.Sales_Order__r.Name;
                w.EscrowAccountNumber  = inv.Sales_Order__r.VirtualAccount__r.EscrowAccount__r.AccountNumber__c;
                w.EscrowIbanNumber     = inv.Sales_Order__r.VirtualAccount__r.EscrowAccount__r.IBANNo__c;
                w.EscrowStoreId        = inv.Sales_Order__r.VirtualAccount__r.EscrowAccount__r.StoreId__c;
                w.EscrowSwiftCode      = inv.Sales_Order__r.VirtualAccount__r.EscrowAccount__r.SwiftCode__c;
                w.EscrowTradeId        = inv.Sales_Order__r.VirtualAccount__r.EscrowAccount__r.TradeID__c;
                w.EscrowBankName       = inv.Sales_Order__r.VirtualAccount__r.EscrowAccount__r.BankName__c;
                w.EscrowBenificaryName = inv.Sales_Order__r.VirtualAccount__r.EscrowAccount__r.BeneficiaryName__c;
                w.Unit                 = inv.Sales_Order__r.Unit__r.PlotNo__c;
                w.ExtraInfo1           = inv.Sales_Order__r.Unit__r.PlotNo__c;
                w.UnitName             = inv.Sales_Order__r.Unit__r.Name;
                w.UnitSfId             = inv.Sales_Order__r.Unit__c;
                w.VirtualAccountNumber = inv.Sales_Order__r.VirtualAccount__r.VirtualAccountNumber__c;
                w.VirtualIbanNumber    = inv.Sales_Order__r.VirtualAccount__r.VirtualIBANNumber__c;
                w.ProjectName          = inv.Sales_Order__r.Unit__r.Project_Name__c;
                //5.0
                if(inv.Sales_Order__r.Unit__r.Project_Name__c == 'Hudayriyat Golf Estates'){ 
                        w.ExtraInfo2 = inv.Sales_Order__r.Unit__r.Project_Name__c+'-'+inv.Sales_Order__r.Unit__r.UnitClassification__c;
                 } else {
                    	w.ExtraInfo2  = inv.Sales_Order__r.Unit__r.Project_Name__c == 'Commercial Plots' ?inv.Sales_Order__r.Unit__r.Name  :inv.Sales_Order__r.Unit__r.Project_Name__c
                                         + '-' + inv.Sales_Order__r.Unit__r.Phase__r.Name;
                }
                w.ProjectPhase         = inv.Sales_Order__r.Unit__r.Phase__r.Name;
                w.EntityName           = inv.Sales_Order__r.Unit__r.Phase__r.EntityName__c;
                w.CustAcctId           = inv.Sales_Order__r.CustAcctId__c;
                w.OraclePartySiteID    = inv.Sales_Order__r.OraclePartySiteID__c;
                w.OracleCustAcctSiteID = inv.Sales_Order__r.OracleCustAcctSiteID__c;
                w.OracleSiteUseID      = inv.Sales_Order__r.OracleSiteUseID__c;
                // Fall back to ADM_CHARGES if the charge type isn't in the metadata map
                w.TrxnType             = chargeToTrxnMap.containsKey(inv.Charge__r.Type__c)
                    ? chargeToTrxnMap.get(inv.Charge__r.Type__c) : 'ADM_CHARGES';
                w.Description          = inv.Sales_Order__r.Unit__r.Project_Name__c + '|'
                    + inv.Sales_Order__r.Unit__r.Phase__r.Name + '|' + w.TrxnType;
                // MODON_FEE invoices use Actual_Invoice_Amount__c because the displayed
                // InvoiceAmount includes VAT; Oracle expects the net amount
                if (inv.InvoiceAmount__c != null)
                    w.Amount = w.TrxnType == 'MODON_FEE' 
                        ? String.valueOf(inv.Actual_Invoice_Amount__c)
                        : String.valueOf(inv.InvoiceAmount__c);
                w.InvoiceDate = inv.InvoiceDate__c != null ? Date.valueOf(inv.InvoiceDate__c) : System.today();
                w.GlDate      = inv.Ebs_Invoice_Date__c != null ? inv.Ebs_Invoice_Date__c : System.today();
                w.VirtualAccountName =inv.Sales_Order__r.VirtualAccount__r.Name; //4.0
                
            }

            // Determine the transaction type flag for Oracle based on record type
            // and cancellation status — order of these conditions matters
            if (inv.RecordType.name == 'Debit Memo' && inv.Parent_Invoice__c != null ) {
                // Debit Memo with a parent = refund invoice scenario
                w.CreditMemoFlag = 'N';
                w.Status         = 'Generated';
                w.RefundOracleId = inv.RefundOracleid__c;
                w.TrxnType       = 'REFOUND';
                refundinvMap.put(inv.Id, true);
            } else if (inv.RecordType.name == 'Debit Memo' && inv.Parent_Invoice__c == null) {
                // Standalone Debit Memo — no parent invoice linkage
                w.CreditMemoFlag = 'N';
                w.Status         = 'Generated';
                w.TrxnType       = 'DEBIT_MEMO';
            }else if (inv.RecordType.name != 'Debit Memo' && (inv.RecordType.name == 'Tax Invoice' ||  inv.OraclePartyId__c != null) && inv.InvoiceStatus__c == 'Cancelled') {
                // Cancelled invoice with an Oracle ID = credit memo against the original
                w.CreditMemoFlag           = 'Y';
                w.Status                   = 'Cancelled';
                w.CreditMemoApplyInvoiceId = inv.OraclePartyId__c;
                w.GlDate                   = System.today();
                if(inv.Is_ADM_Fees_and_Dari_charges__c == true){ //Start 4.0
                    w.TrxnType                 = 'ADM_CREDITMEMO';
                }else{
                    w.TrxnType                 = 'CREDIT_MEMO';
                } //End 4.0               
                invCrdMap.put(inv.Id, true);
            } else if (inv.RecordType.name != 'Debit Memo' && (inv.RecordType.name == 'Tax Invoice' ||  inv.OraclePartyId__c == null) && inv.InvoiceStatus__c != 'Cancelled') {
                // New invoice not yet in Oracle
                w.CreditMemoFlag = 'N';
                w.Status         = 'Generated';
                if (inv.SalesOrderInstallment__c != null
                    && inv.SalesOrderInstallment__r.SalesOrder__r.OraclePartySiteID__c != null
                    && inv.SalesOrderInstallment__r.SalesOrder__r.OracleCustAcctSiteID__c != null
                    && inv.SalesOrderInstallment__r.SalesOrder__r.NotToBeShownOnRD__c == false
                    && inv.SalesOrderInstallment__r.SalesOrder__r.Source_Entity__c != 'Modon - Egypt') {
                    w.TrxnType = 'INSTALLMENT';
                }
            }
            w.OrgIdentifier     = UserInfo.getOrganizationId();
            w.InstallmentNumber = inv.Name;
            wrapLst.add(w);
        }
        return wrapLst;
    }

    // ************************************************************************

    /*
     * Builds the Oracle request payload for Receipt records.
     *
     * TrxnType logic follows this priority order:
     *   1. RecordType overrides everything (Equity Transfer / Credit Note)
     *   2. Standard receipt defaults to INSTALLMENT
     *   3. If no SalesOrderInstallment, charge type metadata is checked first
     *
     * TransferType is set separately for equity transfer and refund scenarios
     * because Oracle uses both fields for routing on its end.
     *
     * Bypass flag controls whether Oracle validates the receipt date against
     * the approval workflow — set to Y when no approval date is present.
     */
    private static List<OIC_RequestWrapperController.ReceiptWrapper> buildReceiptWrappers(
        List<Receipt__c> recLst,
        Map<Id, Boolean> receiptMap
    ) {
        List<OIC_RequestWrapperController.ReceiptWrapper> wrapLst =
            new List<OIC_RequestWrapperController.ReceiptWrapper>();

        Map<String, String> chargeToTrxnMap = new Map<String, String>();
        for (ChargeTypeToTrxnType__mdt cfg : ChargeTypeToTrxnType__mdt.getAll().values()) {
            chargeToTrxnMap.put(cfg.ChargeType__c, cfg.TrxnType__c);
        }

        for (Receipt__c rec : recLst) {
            OIC_RequestWrapperController.ReceiptWrapper w =
                new OIC_RequestWrapperController.ReceiptWrapper();
            w.Sfid                 = rec.Id;
            w.SfReference          = rec.Name;
            w.CustomerSfid         = rec.Account__c;
            w.CustomerPartyId      = rec.Account__r.OraclePartyId__c;
            w.VirtualAccountNumber = rec.SalesOrder__r.VirtualAccount__r.VirtualAccountNumber__c;
            w.VirtualIbanNumber    = rec.SalesOrder__r.VirtualAccount__r.VirtualIBANNumber__c;
            w.OrgIdentifier        = UserInfo.getOrganizationId();

            // Project / phase / entity name depends on whether the receipt is
            // linked to an installment or directly to the Sales Order
            if (rec.SalesOrderInstallment__c != null) {
                w.ProjectName  = rec.SalesOrderInstallment__r.SalesOrder__r.ProjectName__c;
                // 5.0 - Hudayriyat Golf Estates project changes
                if(rec.SalesOrderInstallment__r.SalesOrder__r.ProjectName__c == 'Hudayriyat Golf Estates'){
                    w.ExtraInfo2 = rec.SalesOrderInstallment__r.SalesOrder__r.Unit__r.Project_Name__c+'-'+rec.SalesOrderInstallment__r.SalesOrder__r.Unit__r.UnitClassification__c;
                } else {
                    w.ExtraInfo2 = rec.SalesOrderInstallment__r.SalesOrder__r.ProjectName__c == 'Commercial Plots' ? rec.SalesOrderInstallment__r.SalesOrder__r.Unit__r.Name : rec.SalesOrderInstallment__r.SalesOrder__r.Unit__r.Project_Name__c
                                   + '-' + rec.SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__r.Name;
                }
                w.EntityName   = rec.SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__r.EntityName__c;
                w.ProjectPhase = rec.SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__r.Name;
                //Start 4.0 
                w.SoSfid = rec.SalesOrderInstallment__r.SalesOrder__c;
                w.SoReference = rec.SalesOrderInstallment__r.SalesOrder__r.Name;
                w.SoIsfid = rec.SalesOrderInstallment__c;
                w.SoIsfReference = rec.SalesOrderInstallment__r.Name;
                w.TrxnType = 'INSTALLMENT';
				//End 4.0
            } else {
                // Direct Sales Order receipt — resolve TrxnType from charge metadata
                w.ProjectName  = rec.SalesOrder__r.ProjectName__c;
                // 5.0 - Hudayriyat Golf Estates project changes
                if(rec.SalesOrder__r.ProjectName__c == 'Hudayriyat Golf Estates'){
                   w.ExtraInfo2 = rec.SalesOrder__r.Unit__r.Project_Name__c+'-'+rec.SalesOrder__r.Unit__r.UnitClassification__c;
                } else {
                   w.ExtraInfo2   = rec.SalesOrder__r.ProjectName__c =='Commercial Plots'  ?  rec.SalesOrder__r.Unit__r.Name : rec.SalesOrder__r.Unit__r.Project_Name__c
                                 + '-' + rec.SalesOrder__r.Unit__r.Phase__r.Name;
                }
                w.EntityName   = rec.SalesOrder__r.Unit__r.Phase__r.EntityName__c;
                w.ProjectPhase = rec.SalesOrder__r.Unit__r.Phase__r.Name;
                w.TrxnType     = chargeToTrxnMap.containsKey(rec.Charge__r.Type__c)
                    ? chargeToTrxnMap.get(rec.Charge__r.Type__c) : 'ADM_CHARGES';
                w.SoSfid =rec.SalesOrder__c; //4.0
                w.SoReference = rec.SalesOrder__r.Name; //4.0
            }			
            w.Description          = rec.Milestone_Description__c;
            w.EscrowAccountName    = rec.PaymentEscrowAccount__r.Name;
            w.EscrowAccountNo      = rec.PaymentEscrowAccount__r.AccountNumber__c;
            w.EscrowIBANNo         = rec.PaymentEscrowAccount__r.IBANNo__c;
            w.ReceiptNumber        = rec.Name;
            w.ReceiptType          = rec.Modeofpayment__c;
            w.CurrencyCode         = 'AED';
            // Use cheque date if present — Oracle uses this for post-dated cheque handling
            w.ReceiptDate          = rec.ChequeDate__c != null ? Date.valueOf(rec.ChequeDate__c) : Date.valueOf(rec.ReceiptDate__c);
            w.MaturityDate         = w.ReceiptDate;
            w.GlDate               = rec.EBS_Clearing_Date__c != null ? rec.EBS_Clearing_Date__c : System.today();
            // Prefer Receipt_Amount__c; fall back to AppliedAmount__c for partial payments
            w.Amount               = rec.Receipt_Amount__c != null ? rec.Receipt_Amount__c : rec.AppliedAmount__c;
            w.BankName             = rec.Bank__c;
            w.Status               = rec.Status__c;
            w.ChequeNumber         = rec.TransactionNumber__c;
            w.CustAcctId           = rec.SalesOrder__r.CustAcctId__c;
            w.OraclePartySiteID    = rec.SalesOrder__r.OraclePartySiteID__c;
            w.OracleCustAcctSiteID = rec.SalesOrder__r.OracleCustAcctSiteID__c;
            w.OracleSiteUseID      = rec.SalesOrder__r.OracleSiteUseID__c;
            w.Unit                 = rec.SalesOrder__r.Unit__r.Name;
            w.UnitName             = rec.SalesOrder__r.Unit__r.Name;
            w.EoiFlag              = rec.ExpressionOfInterest__c != null ? 'Y' : 'N';
            // Bypass = N means Oracle enforces the approval date check
            w.Bypass               = rec.Receipt_Approved_Date__c != null ? 'N' : 'Y';
            // Track approved receipts separately — they get a temporary Oracle ID            
            // until the confirmation comes back from Oracle
            if (rec.Receipt_Approved_Date__c != null) receiptMap.put(rec.Id, true);

            wrapLst.add(w);
        }
        return wrapLst;
    }

    // ************************************************************************************

    /*
     * Builds the Oracle request payload for Allocation records.
     * Allocation ties a Receipt to an Invoice in Oracle — so both Oracle IDs
     * must already exist before this can be called (enforced in the SOQL filter
     * upstream in cancellationAllocationNoDml).
     * AllocationAmount is capped at the Receipt's TotalAmount to prevent
     * over-application on the Oracle side.
     *****************************************************************************/
    private static List<OIC_RequestWrapperController.AllocationWrapper> buildAllocationWrappers(
        List<Allocation__c> allocationLst
    ) {
        List<OIC_RequestWrapperController.AllocationWrapper> wrapLst =
            new List<OIC_RequestWrapperController.AllocationWrapper>();

        for (Allocation__c alloc : allocationLst) {
            OIC_RequestWrapperController.AllocationWrapper w =
                new OIC_RequestWrapperController.AllocationWrapper();
            w.Sfid                   = alloc.Id;
            w.SfReference            = alloc.Id;
            w.ReceiptSfid            = alloc.Receipt__c;
            w.CashReceiptId          = alloc.Receipt__r.OraclePartyId__c;
            w.InstallmentInvoiceSfid = alloc.Invoice__c;
            w.CustomerTrxId          = alloc.Invoice__r.OraclePartyId__c;
            w.ResyncUnApply = 'Y';  // 4.0
            w.AllocationDate         = alloc.AllocationDate__c != null ? Date.valueOf(alloc.AllocationDate__c) : null;
            w.AllocationGlDate       = System.today();
            // Cap allocation amount to receipt total — prevents over-application in Oracle
            if (alloc.AllocationAmount__c != null) {
                Decimal amt = alloc.Receipt__r.TotalAmount__c < alloc.AllocationAmount__c
                    ? alloc.Receipt__r.TotalAmount__c : alloc.AllocationAmount__c;
                w.AllocationAmount = String.valueOf(amt);
            }
            w.Status      = alloc.Status__c;
            // Phase and entity come from the installment path if present;
            // otherwise fall back to the direct Sales Order relationship
            w.ProjectPhase = alloc.Receipt__r.SalesOrderInstallment__c != null
                ? alloc.Receipt__r.SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__r.Name
                : alloc.Receipt__r.SalesOrder__r.Unit__r.Phase__r.Name;
            w.EntityName  = alloc.Receipt__r.SalesOrderInstallment__c != null
                ? alloc.Receipt__r.SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__r.EntityName__c
                : alloc.Receipt__r.SalesOrder__r.Unit__r.Phase__r.EntityName__c;
            wrapLst.add(w);
        }
        return wrapLst;
    }

    // **************************************
    // PRIVATE — Response Parsers (NoDml — no Database.update inside)
    // **************************************

    /*
     * Parses Oracle's response for an Invoice/Installment callout.
     * On success:
     *   - Credit memo invoices  → stamp Oracle_Credit_Memo_Id__c
     *   - Refund debit memos    → stamp OraclePartyId__c + set Status to In Progress
     *   - Standard invoices     → stamp OraclePartyId__c
     * On error: stamp OracleSyncStatus__c = Failed and increment retry counter.
     * No Database.update() — the batch finish() method handles all DML.
     *****************************************************************************/
    private static Invoice__c parseInstallmentResponseNoDml(
        String decodedResponse,
        Map<Id, Boolean> invCrdMap,
        Map<Id, Boolean> refundinvMap
    ) {
        Invoice__c invoiceToupdate = new Invoice__c();
        if (String.isBlank(decodedResponse)) return invoiceToupdate;

        OIC_RequestWrapperController.OICResponseWrapperList respList =
            (OIC_RequestWrapperController.OICResponseWrapperList) JSON.deserialize(
                decodedResponse, OIC_RequestWrapperController.OICResponseWrapperList.class);
        if (respList == null) return invoiceToupdate;

        Map<String, Integer> retryMap = buildRetryMap('Invoice__c', respList.ResponseArray);
        Map<String, String>  errorMap = buildErrorMsgMap();

        for (OIC_RequestWrapperController.OICResponseWrapper r : respList.ResponseArray) {
            invoiceToupdate.Id = r.Sfid;
            if (r.Status == 'S') {
                // Which Oracle ID field gets stamped depends on the invoice type
                if (invCrdMap.containsKey(invoiceToupdate.Id))
                    invoiceToupdate.Oracle_Credit_Memo_Id__c = r.OracleId;
                else if (refundinvMap.containsKey(invoiceToupdate.Id)) {
                    invoiceToupdate.OraclePartyId__c = r.OracleId;
                    // Refund invoices go to In Progress — a separate process
                    // finalises them once Oracle confirms the refund
                    invoiceToupdate.Status__c        = 'In Progress';
                } else {
                    invoiceToupdate.OraclePartyId__c = r.OracleId;
                }
                invoiceToupdate.OICIntegrationStatus__c      = 'Cancellation Success'; //4.0
                invoiceToupdate.OICNoOfRetries__c        = null;
                invoiceToupdate.OICIntegrationMessage__c = null;
            } else if (r.Status == 'E') {
                invoiceToupdate.OICIntegrationStatus__c      = 'Cancellation Failed'; //4.0
                invoiceToupdate.OICIntegrationMessage__c = resolveErrorMessage(r.ErrorMsg, errorMap);
                // Increment retry count so the batch knows how many attempts
                // have been made — used to stop retrying after a threshold
                invoiceToupdate.OICNoOfRetries__c        = retryMap.containsKey(r.Sfid)
                    ? retryMap.get(r.Sfid) + 1 : 1;
            }
        }
        return invoiceToupdate;
    }

    // ****************************************************************************

    /*
     * Parses Oracle's response for a Receipt callout.
     * Approved receipts (in receiptMap) get a temporary Oracle ID field
     * stamped — Oracle_Id_Temporary__c — because the final confirmation
     * arrives in a separate downstream process.
     * Unapproved receipts get OraclePartyId__c directly.
     * On error: approval fields are cleared so the record can go through
     * the approval workflow again on the next retry.
     *****************************************************************************/
    private static Receipt__c parseReceiptResponseNoDml(
        String decodedResponse,
        Map<Id, Boolean> receiptMap
    ) {
        Receipt__c recordToupdate = new Receipt__c();
        if (String.isBlank(decodedResponse)) return recordToupdate;

        OIC_RequestWrapperController.OICResponseWrapperList respList =
            (OIC_RequestWrapperController.OICResponseWrapperList) JSON.deserialize(
                decodedResponse, OIC_RequestWrapperController.OICResponseWrapperList.class);
        if (respList == null) return recordToupdate;

        Map<String, Integer> retryMap = buildRetryMap('Receipt__c', respList.ResponseArray);
        Map<String, String>  errorMap = buildErrorMsgMap();

        for (OIC_RequestWrapperController.OICResponseWrapper r : respList.ResponseArray) {
            recordToupdate.Id = r.Sfid;
            if (r.Status == 'S') { // start 4.0
                recordToupdate.OICNoOfRetries__c        = null;
                recordToupdate.OICIntegrationMessage__c = null;
                // Approved receipts use a temp field until Oracle sends final confirmation
                if (receiptMap.containsKey(recordToupdate.Id))
                    recordToupdate.Oracle_Id_Temporary__c = r.OracleId;
                else
                    recordToupdate.OraclePartyId__c = r.OracleId;
                	recordToupdate.OICIntegrationStatus__c = 'Cancellation Success'; // End 4.0           
            } else if (r.Status == 'E') {
                recordToupdate.OICIntegrationMessage__c    = resolveErrorMessage(r.ErrorMsg, errorMap);
                recordToupdate.OICNoOfRetries__c           = retryMap.containsKey(r.Sfid) ? retryMap.get(r.Sfid) + 1 : 1;
                // Clear approval fields on error so the receipt re-enters the
                // approval workflow and doesn't stay in a half-approved state
                recordToupdate.Receipt_Approved_Checker__c = false;
                recordToupdate.Receipt_Approved_Date__c    = null;
                recordToupdate.Receipt_Approved_By__c      = null;
                recordToupdate.OICIntegrationStatus__c = 'Cancellation Failed'; // 4.0
            }
        }
        return recordToupdate;
    }

    // *****************************************************************************************

    /*
     * Parses Oracle's response for an Allocation callout.
     * OraclePartyId__c is only stamped on success — we don't want to write
     * a partial or incorrect Oracle ID if the response comes back as an error.
     * OracleSyncStatus__c reflects the result so ops teams can filter
     * failed allocations without reading the error message field.
     *****************************************************************************/
    private static Allocation__c parseAllocationResponseNoDml(String decodedResponse) {
        Allocation__c allocationToupdate = new Allocation__c();
        if (String.isBlank(decodedResponse)) return allocationToupdate;

        OIC_RequestWrapperController.OICResponseWrapperList respList =
            (OIC_RequestWrapperController.OICResponseWrapperList) JSON.deserialize(
                decodedResponse, OIC_RequestWrapperController.OICResponseWrapperList.class);
        if (respList == null) return allocationToupdate;

        Map<String, Integer> retryMap = buildRetryMap('Allocation__c', respList.ResponseArray);
        Map<String, String>  errorMap = buildErrorMsgMap();

        for (OIC_RequestWrapperController.OICResponseWrapper r : respList.ResponseArray) {
            allocationToupdate.Id = r.Sfid;
            // Only stamp OraclePartyId__c on success — never on error
            if (r.Status == 'S') {
                allocationToupdate.OraclePartyId__c        = r.OracleId; // 4.0
                allocationToupdate.OICIntegrationStatus__c     = 'Cancellation Success'; //4.0
                allocationToupdate.OICNoOfRetries__c        = null;
                allocationToupdate.OICIntegrationMessage__c = null;
            } else if (r.Status == 'E') {
                allocationToupdate.OICIntegrationStatus__c      = 'Cancellation Failed' ; //4.0
                allocationToupdate.OICIntegrationMessage__c = resolveErrorMessage(r.ErrorMsg, errorMap);
                allocationToupdate.OICNoOfRetries__c        = retryMap.containsKey(r.Sfid)
                    ? retryMap.get(r.Sfid) + 1 : 1;
            }
        }
        return allocationToupdate;
    }

    // **************************************
    // PRIVATE — Shared Utilities
    // **************************************

    /*
     * OIC wraps its response body in a Base64 envelope.
     * This helper strips that envelope and returns the raw JSON string
     * that the parsers expect. Returns null if the body is blank or the
     * Base64Response field is empty — callers treat null as a no-op.
     *****************************************************************************/
    private static String decodeBase64Response(String responseBody) {
        if (String.isBlank(responseBody)) return null;
        OIC_RequestWrapperController.Base64ResponseWrapper base64Wrap =
            (OIC_RequestWrapperController.Base64ResponseWrapper) JSON.deserialize(
                responseBody, OIC_RequestWrapperController.Base64ResponseWrapper.class);
        if (String.isBlank(base64Wrap.Base64Response)) return null;
        return EncodingUtil.base64Decode(base64Wrap.Base64Response).toString();
    }

    /*****************************************************************************
     * Builds a map of record Id to current OICNoOfRetries__c value.
     * Used by the parsers to increment the retry counter correctly.
     * Dynamic SOQL is used here so the same method works for Invoice,
     * Receipt, and Allocation without duplicating the query three times.
     *****************************************************************************/
    private static Map<String, Integer> buildRetryMap(
        String objectApiName,
        List<OIC_RequestWrapperController.OICResponseWrapper> responseArray
    ) {
        Set<String> ids = new Set<String>();
        for (OIC_RequestWrapperController.OICResponseWrapper r : responseArray) ids.add(r.Sfid);

        Map<String, Integer> retryMap = new Map<String, Integer>();
        if (ids.isEmpty()) return retryMap;

        String query = 'SELECT Id, OICNoOfRetries__c FROM ' + String.escapeSingleQuotes(objectApiName)
            + ' WHERE Id IN :ids AND OICNoOfRetries__c != null';
        for (SObject rec : Database.queryWithBinds(
            query,
            new Map<String, Object>{ 'ids' => ids },
            AccessLevel.SYSTEM_MODE
        )) {
            retryMap.put((String) rec.get('Id'),
                Integer.valueOf((Decimal) rec.get('OICNoOfRetries__c')));
        }
        return retryMap;
    }

    /*****************************************************************************
     * Loads active EBS error message mappings from custom metadata.
     * System_Error_Msg__c is the raw string Oracle returns;
     * User_Error_Msg__c is the friendly message shown on the record.
     * Keeping this in metadata means support can update messages
     * without a code deployment.
     *
    *****************************************************************************/
    private static Map<String, String> buildErrorMsgMap() {
        Map<String, String> errorMap = new Map<String, String>();
        for (Integration_Error_Messages__mdt m : [
            SELECT System_Error_Msg__c, User_Error_Msg__c
            FROM Integration_Error_Messages__mdt
            WHERE IsActive__c = true AND Application_Type__c = 'EBS'
        ]) {
            errorMap.put(m.System_Error_Msg__c, m.User_Error_Msg__c);
        }
        return errorMap;
    }

    /******************************************************************************
     * Resolves a raw Oracle error string into a user-friendly message.
     * Priority order:
     *   1. "Unknown integration error" — fixed generic message
     *   2. Matched entry in the error map — configured user message
     *   3. No match — generic fallback with the raw error appended
     *      so support can still see what Oracle actually said
     ******************************************************************************/
    private static String resolveErrorMessage(String errorMsg, Map<String, String> errorMap) {
        if (String.isBlank(errorMsg)) return null;
        if (errorMsg.contains('Unknown integration error'))
            return 'Required information is not updated in Salesforce. Please contact support';
        String userMsg = UserErrorMessage.getUserErrorMessage(errorMsg, errorMap);
        return userMsg != null ? userMsg
            : 'Required information is not updated in Salesforce. Please contact support, ' + errorMsg;
    }
    /* Start 4.0
 * Sends a single SalesOrder__c (with its child installments) to Oracle
 * Fusion via OIC. Mirrors createSalesOrderAndSOInstallments exactly but
 * with zero DML — parsed SalesOrder__c and staged logs are returned in
 * CalloutResult for EBSCancellationBatch to commit in Phase 2.
 *
 * Filters applied at SOQL time (same as the original):
 *   - NotToBeShownOnRD__c = false
 *   - Source_Entity__c != 'Modon - Egypt'
 *   - CustomerAccount__r.OraclePartyId__c != null
 *******************************************************************************/
public static CalloutResult cancellationSalesOrderNoDml(Id salesOrderId) {
    CalloutResult result           = new CalloutResult();
    SalesOrder__c soToUpdate       = new SalesOrder__c(Id = salesOrderId);
    result.record                  = soToUpdate;

    try {
        // Same SOQL as createSalesOrderAndSOInstallments — includes child
        // installments in a sub-select so the wrapper builder gets everything
        // it needs in a single query.
        // 4.0 add SOQL
        List<SalesOrder__c> soList = [SELECT Id, Name, CustomerAccount__c, CustomerAccount__r.OraclePartyId__c,
                                          Unit__r.Name, UnitOption__r.Name, PaymentPlan__r.Name, Unit__r.Phase__r.Name,
                                          Unit__r.Project_Name__c, Unit__r.Phase__r.EntityName__c, TotalAmount__c,
                                          VirtualAccount__r.VirtualAccountNumber__c, VirtualAccount__r.VirtualIBANNumber__c,
                                          SalesAssociate__r.Name, Status__c, ProjectName__c,ADM_Fees_Dari_charges__c,Discount_Amount__c,
                                          CustAcctId__c, OraclePartySiteID__c, OracleCustAcctSiteID__c, OracleSiteUseID__c,
                                          (SELECT Id, Name, MilestoneNumber__c, MilestoneDescription__c, InstallmentAmount__c,
                                                  MilestoneDate__c, Milestone__c, PaymentStatus__c, Balance_Amount__c
                                           FROM   Sales_Order_Installments__r)
                                          FROM SalesOrder__c  WHERE Id = :salesOrderId
                                          AND NotToBeShownOnRD__c = false
                                          AND Source_Entity__c != 'Modon - Egypt'
                                          AND CustomerAccount__r.OraclePartyId__c != null];

        // ── Build the request wrapper ────────────────────────────────
        // Identical field-by-field mapping from the original method.
        OIC_RequestWrapperController.SalesOrderWrapperLst soWrapListFinal =
            new OIC_RequestWrapperController.SalesOrderWrapperLst();

        List<OIC_RequestWrapperController.SalesOrderWrapper> soWrapList =
            new List<OIC_RequestWrapperController.SalesOrderWrapper>();

        for (SalesOrder__c so : soList) {
            OIC_RequestWrapperController.SalesOrderWrapper soWrap =
                new OIC_RequestWrapperController.SalesOrderWrapper();

            soWrap.Sfid                 = so.Id;
            soWrap.SfReference          = so.Name;
            soWrap.CustomerSfid         = so.CustomerAccount__c;
            soWrap.CustomerPartyId      = so.CustomerAccount__r.OraclePartyId__c;
            soWrap.CustomerAcct         = '';
            soWrap.UnitName             = so.Unit__r.Name;
            soWrap.UnitOption           = so.UnitOption__r.Name;
            soWrap.PaymentPlan          = so.PaymentPlan__r.Name;
            soWrap.Phase                = so.Unit__r.Phase__r.Name;
            soWrap.Project              = so.Unit__r.Project_Name__c;
            soWrap.TotalAmount          = so.TotalAmount__c != null
                                            ? String.valueOf(so.TotalAmount__c) : null;
            soWrap.AdmAmount            = so.ADM_Fees_Dari_charges__c != null ?string.valueOf(so.ADM_Fees_Dari_charges__c) : '0'; // 4.0
            soWrap.DiscountAmount       = so.Discount_Amount__c != null ? string.valueOf(so.Discount_Amount__c) : '0'; //4.0
            soWrap.VirtualAccountNumber = so.VirtualAccount__r.VirtualAccountNumber__c;
            soWrap.VirtualIbanNumber    = so.VirtualAccount__r.VirtualIBANNumber__c;
            soWrap.SalesAssociateName   = so.SalesAssociate__r.Name;
            soWrap.Status               = so.Status__c;
            soWrap.OrgIdentifier        = UserInfo.getOrganizationId();
            soWrap.ProjectName          = so.ProjectName__c;
            soWrap.Unit                 = so.Unit__r.Name;
            soWrap.ProjectPhase         = so.Unit__r.Phase__r.Name;
            soWrap.EntityName           = so.Unit__r.Phase__r.EntityName__c;
            soWrap.CustAcctId           = so.CustAcctId__c;
            soWrap.OraclePartySiteID    = so.OraclePartySiteID__c;
            soWrap.OracleCustAcctSiteID = so.OracleCustAcctSiteID__c;
            soWrap.OracleSiteUseID      = so.OracleSiteUseID__c;

            // ── Child installment wrappers ───────────────────────────
            List<OIC_RequestWrapperController.SalesOrderInstallmentWrapper> soiWrapList =
                new List<OIC_RequestWrapperController.SalesOrderInstallmentWrapper>();

            for (SalesOrderInstallments__c soi : so.Sales_Order_Installments__r) {
                OIC_RequestWrapperController.SalesOrderInstallmentWrapper soiWrap =
                    new OIC_RequestWrapperController.SalesOrderInstallmentWrapper();

                soiWrap.InstallmentSfid        = soi.Id;
                soiWrap.InstallmentfReference  = soi.Name;
                soiWrap.InstallmentNumber      = soi.MilestoneNumber__c != null
                                                    ? String.valueOf(soi.MilestoneNumber__c) : null;
                soiWrap.InstallementDescription = soi.MilestoneDescription__c;
                soiWrap.InstallmentDate         = soi.MilestoneDate__c;
                soiWrap.InstallementAmount      = soi.InstallmentAmount__c != null
                                                    ? String.valueOf(soi.InstallmentAmount__c) : null;
                soiWrap.InstallementStatus      = soi.PaymentStatus__c;
                soiWrap.ExtraInfo1 = string.valueOf(soi.MilestoneDate__c);
                soiWrap.ExtraInfo2 = string.valueOf(soi.Milestone__c);
                soiWrap.ExtraInfo3 = soi.PaymentStatus__c;
                soiWrap.ExtraInfo4 = string.valueOf(soi.Balance_Amount__c);

                soiWrapList.add(soiWrap);
            }

            soWrap.SalesOrderLines = soiWrapList;
            soWrapList.add(soWrap);
        }

        soWrapListFinal.RequestArray = soWrapList;

        // ── Encode + send ────────────────────────────────────────────
        String requestBody  = JSON.serialize(soWrapListFinal);
        String base64String = EncodingUtil.base64Encode(Blob.valueOf(requestBody));

        OIC_RequestWrapperController.Base64Wrapper wrapper =
            new OIC_RequestWrapperController.Base64Wrapper();
        wrapper.Base64RequestPayload = base64String;

        HttpRequest req = OIC_CredentialsController.getCredentials('ModonFusionSalesOrderAPI');
        req.setTimeout(120000);
        req.setBody(JSON.serialize(wrapper));
        req.setHeader('Accept', 'application/json');

        HTTPResponse res        = new Http().send(req);
        String decodedResponse  = decodeBase64Response(res.getBody());

        // ── Parse response — no DML ──────────────────────────────────
        result.record  = parseSalesOrderResponseNoDml(decodedResponse);

        // ── Stage log — no save() ────────────────────────────────────
        result.apiLog  = LoggerService.createAPILog(
            'Sales Order API', 'OIC_CancellationServices', 'cancellationSalesOrderNoDml',
            requestBody, decodedResponse,
            'Status Code: ' + res.getStatusCode() + '; Status: ' + res.getStatus(),
            'Callout Log');

    } catch (Exception ex) {
        SalesOrder__c errRec               = new SalesOrder__c(Id = salesOrderId);
        errRec.OICIntegrationStatus__c     = 'E';
        errRec.OICIntegrationMessage__c    = ex.getMessage();
        result.record                      = errRec;
        result.hasError                    = true;
        result.errorLog                    = LoggerService.createApexLog(
            ex, 'Sales Order API', 'OIC_CancellationServices', 'cancellationSalesOrderNoDml');
    }
    return result;
}

/*
 * Parses Oracle's response for a SalesOrder callout.
 * On success: stamps OraclePartyId__c + all four Oracle site ID fields,
 *             clears OICNoOfRetries__c and OICIntegrationMessage__c.
 * On error:   resolves the user-friendly message from metadata,
 *             increments OICNoOfRetries__c.
 * No Database.update() — batch Phase 2 handles all DML.
 *******************************************************************************/
private static SalesOrder__c parseSalesOrderResponseNoDml(String decodedResponse) {
    SalesOrder__c soToUpdate = new SalesOrder__c();
    if (String.isBlank(decodedResponse)) return soToUpdate;

    OIC_RequestWrapperController.OICSOResponseWrapperList respList =
        (OIC_RequestWrapperController.OICSOResponseWrapperList) JSON.deserialize(
            decodedResponse, OIC_RequestWrapperController.OICSOResponseWrapperList.class);
    if (respList == null) return soToUpdate;

    // Retry counter — same buildRetryMap utility used by the other parsers
    Set<String> ids = new Set<String>();
    for (OIC_RequestWrapperController.OICSOResponseWrapper r : respList.ResponseArray)
        ids.add(r.Sfid);

    Map<String, Integer> retryMap = new Map<String, Integer>();
    if (!ids.isEmpty()) {
        for (SalesOrder__c rec : [
            SELECT Id, OICNoOfRetries__c
            FROM SalesOrder__c
            WHERE Id IN :ids AND OICNoOfRetries__c != null
        ]) {
            retryMap.put(rec.Id, Integer.valueOf(rec.OICNoOfRetries__c));
        }
    }

    Map<String, String> errorMap = buildErrorMsgMap();

    for (OIC_RequestWrapperController.OICSOResponseWrapper soResp : respList.ResponseArray) {
            soToUpdate.Id                    = soResp.Sfid;
            if (soResp.Status == 'S') {
                soToUpdate.OICNoOfRetries__c        = null;
                soToUpdate.OICIntegrationMessage__c = null;
                soToUpdate.OraclePartyId__c      = soResp.OracleId;
                soToUpdate.OICIntegrationStatus__c = 'Cancellation Success';
                // Site IDs come back in the response and must be stamped
                // regardless of success/error so subsequent retries have them
                soToUpdate.CustAcctId__c           = soResp.CustAcctId;
                soToUpdate.OraclePartySiteID__c    = soResp.OraclePartySiteID;
                soToUpdate.OracleCustAcctSiteID__c = soResp.OracleCustAcctSiteID;
                soToUpdate.OracleSiteUseID__c      = soResp.OracleSiteUseID;
            } else if (soResp.Status == 'E') {
                soToUpdate.OICIntegrationStatus__c = 'Cancellation Failed';
                soToUpdate.OICIntegrationMessage__c = resolveErrorMessage(soResp.ErrorMsg, errorMap);
                soToUpdate.OICNoOfRetries__c        = retryMap.containsKey(soResp.Sfid)
                    ? retryMap.get(soResp.Sfid) + 1 : 1;
            }
        }
        return soToUpdate;
	}
    //End 4.0
}