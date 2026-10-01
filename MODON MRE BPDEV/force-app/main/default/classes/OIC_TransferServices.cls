/**********************************************************************************************************************
* Name               : OIC_TransferServices
* Description        : Integration callouts for Property Transfer — Oracle-Salesforce via OIC.
*                      Mirrors OIC_CancellationServices pattern: NoDml variants only,
*                      zero DML inside, CallouResult returned to batch for deferred commit.
* Usage              : Used by EBSTransferBatch only.
* Created By         : ActiveMinds
* --------------------------------------------------------------------------------------------------------------------
* Version       Author          Date              Comment
* 1.0           Manoj           14 May 2026       Initial Draft — split from OIC_CancellationServices
* 2.0			Manoj			05 May 2026		  Hudayriyat Golf Estates project change
***********************************************************************************************************************/
public class OIC_TransferServices {

    // ══════════════════════════════════════════════════════════════════
    // INNER WRAPPER
    // Carries parsed record + staged logs back to the batch.
    // Zero DML, zero LoggerService.save() inside these methods.
    // ══════════════════════════════════════════════════════════════════
    public class CalloutResult {
        public SObject  record;
        public SObject  apiLog;
        public SObject  errorLog;
        public Boolean  hasError = false;
    }

    // ══════════════════════════════════════════════════════════════════
    // PUBLIC — NoDml variants
    // ══════════════════════════════════════════════════════════════════

    /*
     * Sends a single SalesOrder__c (with child installments) to Oracle
     * Fusion via OIC for a Property Transfer.
     * Filters: NotToBeShownOnRD__c = false, Source_Entity__c != 'Modon - Egypt',
     *          CustomerAccount__r.OraclePartyId__c != null.
     * Returns CalloutResult; batch Phase 2 handles all DML.
     *******************************************************************************/
    public static CalloutResult transferSalesOrderNoDml(Id salesOrderId) {
        CalloutResult result     = new CalloutResult();
        SalesOrder__c soToUpdate = new SalesOrder__c(Id = salesOrderId);
        result.record            = soToUpdate;

        try {
            List<SalesOrder__c> soList = [SELECT Id, Name, CustomerAccount__c, Old_Account__c,Resale_Transfer_Date__c,CustomerAccount__r.OraclePartyId__c,
                                          Unit__r.Name, UnitOption__r.Name, PaymentPlan__r.Name, Unit__r.Phase__r.Name,
                                          Unit__r.Project_Name__c, Unit__r.Phase__r.EntityName__c, TotalAmount__c,
                                          VirtualAccount__r.VirtualAccountNumber__c, VirtualAccount__r.VirtualIBANNumber__c,
                                          SalesAssociate__r.Name, Status__c, ProjectName__c,ADM_Fees_Dari_charges__c,Discount_Amount__c,
                                          CustAcctId__c, OraclePartySiteID__c, OracleCustAcctSiteID__c, OracleSiteUseID__c,
                                          (SELECT Id, Name, MilestoneNumber__c, MilestoneDescription__c, InstallmentAmount__c,
                                                  MilestoneDate__c, Milestone__c, PaymentStatus__c, Balance_Amount__c
                                           FROM   Sales_Order_Installments__r)
                                          FROM SalesOrder__c WHERE Id = :salesOrderId
                                            AND NotToBeShownOnRD__c    = false
                                            AND Source_Entity__c       != 'Modon - Egypt'
                                            AND CustomerAccount__r.OraclePartyId__c != null
                                        ];

            // ── Build request wrapper ────────────────────────────────
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
                soWrap.AdmAmount            = so.ADM_Fees_Dari_charges__c != null
                                                ? String.valueOf(so.ADM_Fees_Dari_charges__c) : '0';
                soWrap.DiscountAmount       = so.Discount_Amount__c != null
                                                ? String.valueOf(so.Discount_Amount__c) : '0';
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
                if(so.Old_Account__c != null && so.Resale_Transfer_Date__c != null){
                    soWrap.PropertyTransfer ='Y';
                    soWrap.OldCustomerId =so.CustAcctId__c;
                }else{
                	soWrap.PropertyTransfer ='N';
                }
                // ── Child installment wrappers ───────────────────────
                List<OIC_RequestWrapperController.SalesOrderInstallmentWrapper> soiWrapList =
                    new List<OIC_RequestWrapperController.SalesOrderInstallmentWrapper>();

                for (SalesOrderInstallments__c soi : so.Sales_Order_Installments__r) {
                    OIC_RequestWrapperController.SalesOrderInstallmentWrapper soiWrap =
                        new OIC_RequestWrapperController.SalesOrderInstallmentWrapper();

                    soiWrap.InstallmentSfid         = soi.Id;
                    soiWrap.InstallmentfReference   = soi.Name;
                    soiWrap.InstallmentNumber       = soi.MilestoneNumber__c != null
                                                        ? String.valueOf(soi.MilestoneNumber__c) : null;
                    soiWrap.InstallementDescription = soi.MilestoneDescription__c;
                    soiWrap.InstallmentDate         = soi.MilestoneDate__c;
                    soiWrap.InstallementAmount      = soi.InstallmentAmount__c != null
                                                        ? String.valueOf(soi.InstallmentAmount__c) : null;
                    soiWrap.InstallementStatus      = soi.PaymentStatus__c;
                    soiWrap.ExtraInfo1              = String.valueOf(soi.MilestoneDate__c);
                    soiWrap.ExtraInfo2              = String.valueOf(soi.Milestone__c);
                    soiWrap.ExtraInfo3              = soi.PaymentStatus__c;
                    soiWrap.ExtraInfo4              = String.valueOf(soi.Balance_Amount__c);

                    soiWrapList.add(soiWrap);
                }

                soWrap.SalesOrderLines = soiWrapList;
                soWrapList.add(soWrap);
            }

            soWrapListFinal.RequestArray = soWrapList;

            // ── Encode + send ────────────────────────────────────────
            String requestBody  = JSON.serialize(soWrapListFinal);
            String base64String = EncodingUtil.base64Encode(Blob.valueOf(requestBody));

            OIC_RequestWrapperController.Base64Wrapper wrapper =
                new OIC_RequestWrapperController.Base64Wrapper();
            wrapper.Base64RequestPayload = base64String;

            HttpRequest req = OIC_CredentialsController.getCredentials('ModonFusionSalesOrderAPI');
            req.setTimeout(120000);
            req.setBody(JSON.serialize(wrapper));
            req.setHeader('Accept', 'application/json');

            HTTPResponse res       = new Http().send(req);
            String decodedResponse = decodeBase64Response(res.getBody());

            // ── Parse — no DML ───────────────────────────────────────
            result.record  = parseSalesOrderResponseNoDml(decodedResponse);

            // ── Stage log — no save() ────────────────────────────────
            result.apiLog  = LoggerService.createAPILog(
                'Sales Order API', 'OIC_TransferServices', 'transferSalesOrderNoDml',
                requestBody, decodedResponse,
                'Status Code: ' + res.getStatusCode() + '; Status: ' + res.getStatus(),
                'Callout Log');

        } catch (Exception ex) {
            SalesOrder__c errRec            = new SalesOrder__c(Id = salesOrderId);
            errRec.OICIntegrationStatus__c  = 'E';
            errRec.OICIntegrationMessage__c = ex.getMessage();
            result.record                   = errRec;
            result.hasError                 = true;
            result.errorLog                 = LoggerService.createApexLog(
                ex, 'Sales Order API', 'OIC_TransferServices', 'transferSalesOrderNoDml');
        }
        return result;
    }

    // ══════════════════════════════════════════════════════════════════

    /*
     * Sends a single Invoice/Installment record to Oracle Fusion via OIC
     * for a Property Transfer. Same field set as OIC_CancellationServices
     * but logged under OIC_TransferServices.
     *******************************************************************************/
    public static CalloutResult transferInstallmentNoDml(Id installmentId) {
        CalloutResult result       = new CalloutResult();
        Invoice__c invoiceToUpdate = new Invoice__c(Id = installmentId);
        result.record              = invoiceToUpdate;

        try { //2.0
            List<Invoice__c> installmentLst = [SELECT Id, Name, InvoiceAmount__c, Ebs_Invoice_Date__c, InvoiceDate__c,
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
                       Sales_Order__r.OracleCustAcctSiteID__c, Sales_Order__r.OracleSiteUseID__c,
                       Actual_Invoice_Amount__c, OraclePartyId__c,
                       Parent_Invoice__c, RecordType.name, Parent_Invoice__r.OraclePartyId__c,SalesOrderInstallment__r.SalesOrder__r.Unit__r.UnitClassification__c,
                       Sales_Order__r.Unit__r.UnitClassification__c                        
                FROM Invoice__c
                WHERE Id = :installmentId
                  AND (OraclePartyId__c = null OR InvoiceStatus__c = 'Cancelled')
            ];

            Map<Id, Boolean> invCrdMap    = new Map<Id, Boolean>();
            Map<Id, Boolean> refundinvMap = new Map<Id, Boolean>();
            List<OIC_RequestWrapperController.InstallmentWrapper> installmentWrapLst =
                buildInstallmentWrappers(installmentLst, invCrdMap, refundinvMap);

            HttpRequest req = OIC_CredentialsController.getCredentials('ModonFusionInstallmentAPI');
            req.setTimeout(120000);

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

            result.record  = parseInstallmentResponseNoDml(decodedResponse, invCrdMap, refundinvMap);
            result.apiLog  = LoggerService.createAPILog(
                'Invoice API', 'OIC_TransferServices', 'transferInstallmentNoDml',
                requestBody, decodedResponse,
                'Status Code: ' + res.getStatusCode() + '; Status: ' + res.getStatus(),
                'Callout Log');

        } catch (Exception ex) {
            Invoice__c errRec               = new Invoice__c(Id = installmentId);
            errRec.OICIntegrationStatus__c  = 'E';
            errRec.OICIntegrationMessage__c = ex.getMessage();
            result.record                   = errRec;
            result.hasError                 = true;
            result.errorLog                 = LoggerService.createApexLog(
                ex, 'Invoice API', 'OIC_TransferServices', 'transferInstallmentNoDml');
        }
        return result;
    }

    // ══════════════════════════════════════════════════════════════════

    /*
     * Sends a single Receipt record to Oracle Fusion via OIC for a
     * Property Transfer. Re-throws on exception so the batch can gate
     * downstream steps correctly.
     *******************************************************************************/
    public static CalloutResult transferReceiptNoDml(Id receiptId) {
        CalloutResult result      = new CalloutResult();
        Receipt__c recordToUpdate = new Receipt__c(Id = receiptId);
        result.record             = recordToUpdate;

        try {//2.0
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
                                        AND SalesOrder__r.Source_Entity__c    != 'Modon - Egypt'
                                    ];

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

            result.record  = parseReceiptResponseNoDml(decodedResponse, receiptMap);
            result.apiLog  = LoggerService.createAPILog(
                'Receipt API', 'OIC_TransferServices', 'transferReceiptNoDml',
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
                ex, 'Receipt API', 'OIC_TransferServices', 'transferReceiptNoDml');
            throw ex;
        }
        return result;
    }

    // ══════════════════════════════════════════════════════════════════
    // PRIVATE — Wrapper Builders (identical logic, different log label)
    // ══════════════════════════════════════════════════════════════════

    private static List<OIC_RequestWrapperController.InstallmentWrapper> buildInstallmentWrappers(
        List<Invoice__c> installmentLst,
        Map<Id, Boolean> invCrdMap,
        Map<Id, Boolean> refundinvMap
    ) {
        List<OIC_RequestWrapperController.InstallmentWrapper> wrapLst =
            new List<OIC_RequestWrapperController.InstallmentWrapper>();

        Map<String, String> chargeToTrxnMap = new Map<String, String>();
        for (ChargeTypeToTrxnType__mdt cfg : ChargeTypeToTrxnType__mdt.getAll().values()) {
            chargeToTrxnMap.put(cfg.ChargeType__c, cfg.TrxnType__c);
        }

        for (Invoice__c inv : installmentLst) {
            OIC_RequestWrapperController.InstallmentWrapper w =
                new OIC_RequestWrapperController.InstallmentWrapper();

            if (inv.SalesOrderInstallment__c != null
                && inv.SalesOrderInstallment__r.SalesOrder__r.OraclePartySiteID__c  != null
                && inv.SalesOrderInstallment__r.SalesOrder__r.OracleCustAcctSiteID__c != null
                && inv.SalesOrderInstallment__r.SalesOrder__r.NotToBeShownOnRD__c   == false
                && inv.SalesOrderInstallment__r.SalesOrder__r.Source_Entity__c      != 'Modon - Egypt') {

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
                w.VirtualAccountName   = inv.SalesOrderInstallment__r.SalesOrder__r.VirtualAccount__r.Name;
                w.ProjectName          = inv.SalesOrderInstallment__r.SalesOrder__r.Unit__r.Project_Name__c;
                //2.0
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
                if (inv.InvoiceAmount__c != null) w.Amount = String.valueOf(inv.InvoiceAmount__c);
                w.InvoiceDate = inv.InvoiceDate__c != null      ? Date.valueOf(inv.InvoiceDate__c)
                              : inv.Ebs_Invoice_Date__c != null ? Date.valueOf(inv.Ebs_Invoice_Date__c)
                              : System.today();
                w.GlDate = inv.Ebs_Invoice_Date__c != null ? inv.Ebs_Invoice_Date__c : System.today();

            } else if (inv.Sales_Order__r.OracleCustAcctSiteID__c != null
                    && inv.Sales_Order__r.OracleSiteUseID__c       != null
                    && inv.Sales_Order__r.NotToBeShownOnRD__c      == false
                    && inv.Sales_Order__r.Source_Entity__c         != 'Modon - Egypt') {

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
                w.VirtualAccountName   = inv.Sales_Order__r.VirtualAccount__r.Name;
                w.ProjectName          = inv.Sales_Order__r.Unit__r.Project_Name__c;
                //2.0
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
                w.TrxnType             = chargeToTrxnMap.containsKey(inv.Charge__r.Type__c)
                                            ? chargeToTrxnMap.get(inv.Charge__r.Type__c) : 'ADM_CHARGES';
                w.Description          = inv.Sales_Order__r.Unit__r.Project_Name__c + '|'
                                         + inv.Sales_Order__r.Unit__r.Phase__r.Name + '|' + w.TrxnType;
                if (inv.InvoiceAmount__c != null)
                    w.Amount = w.TrxnType == 'MODON_FEE' || w.TrxnType == 'NOC_FEE'
                                ? String.valueOf(inv.Actual_Invoice_Amount__c)
                                : String.valueOf(inv.InvoiceAmount__c);
                w.InvoiceDate = inv.InvoiceDate__c != null ? Date.valueOf(inv.InvoiceDate__c) : System.today();
                w.GlDate      = inv.Ebs_Invoice_Date__c != null ? inv.Ebs_Invoice_Date__c : System.today();
            }

            if (inv.RecordType.Name == 'Debit Memo' && inv.Parent_Invoice__c != null) {
                w.CreditMemoFlag = 'N'; w.Status = 'Generated';
                w.RefundOracleId = inv.RefundOracleid__c;
                w.TrxnType = 'REFOUND';
                refundinvMap.put(inv.Id, true);
            } else if (inv.RecordType.Name == 'Debit Memo' && inv.Parent_Invoice__c == null) {
                w.CreditMemoFlag = 'N'; w.Status = 'Generated'; w.TrxnType = 'DEBIT_MEMO';
            } else if (inv.RecordType.Name != 'Debit Memo'
                    && (inv.RecordType.Name == 'Tax Invoice' || inv.OraclePartyId__c != null)
                    && inv.InvoiceStatus__c == 'Cancelled') {
                w.CreditMemoFlag           = 'Y'; w.Status = 'Cancelled';
                w.CreditMemoApplyInvoiceId = inv.OraclePartyId__c;
                w.GlDate                   = System.today();
                w.TrxnType                 = 'CREDIT_MEMO';
                invCrdMap.put(inv.Id, true);
            } else if (inv.RecordType.Name != 'Debit Memo'
                    && (inv.RecordType.Name == 'Tax Invoice' || inv.OraclePartyId__c == null)
                    && inv.InvoiceStatus__c != 'Cancelled') {
                w.CreditMemoFlag = 'N'; w.Status = 'Generated';
                if (inv.SalesOrderInstallment__c != null
                    && inv.SalesOrderInstallment__r.SalesOrder__r.OraclePartySiteID__c != null
                    && inv.SalesOrderInstallment__r.SalesOrder__r.OracleCustAcctSiteID__c != null
                    && inv.SalesOrderInstallment__r.SalesOrder__r.NotToBeShownOnRD__c == false
                    && inv.SalesOrderInstallment__r.SalesOrder__r.Source_Entity__c != 'Modon - Egypt')
                    w.TrxnType = 'INSTALLMENT';
            }
            w.OrgIdentifier     = UserInfo.getOrganizationId();
            w.InstallmentNumber = inv.Name;
            wrapLst.add(w);
        }
        return wrapLst;
    }

    // ──────────────────────────────────────────────────────────────────

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

            if (rec.SalesOrderInstallment__c != null) {
                w.ProjectName    = rec.SalesOrderInstallment__r.SalesOrder__r.ProjectName__c;
                // 2.0 - Hudayriyat Golf Estates project changes
                if(rec.SalesOrderInstallment__r.SalesOrder__r.ProjectName__c == 'Hudayriyat Golf Estates'){
                    w.ExtraInfo2 = rec.SalesOrderInstallment__r.SalesOrder__r.Unit__r.Project_Name__c+'-'+rec.SalesOrderInstallment__r.SalesOrder__r.Unit__r.UnitClassification__c;
                } else {
                    w.ExtraInfo2 = rec.SalesOrderInstallment__r.SalesOrder__r.ProjectName__c == 'Commercial Plots' ? rec.SalesOrderInstallment__r.SalesOrder__r.Unit__r.Name : rec.SalesOrderInstallment__r.SalesOrder__r.Unit__r.Project_Name__c
                                   + '-' + rec.SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__r.Name;
                }
                w.EntityName     = rec.SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__r.EntityName__c;
                w.ProjectPhase   = rec.SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__r.Name;
                w.SoSfid         = rec.SalesOrderInstallment__r.SalesOrder__c;
                w.SoReference    = rec.SalesOrderInstallment__r.SalesOrder__r.Name;
                w.SoIsfid        = rec.SalesOrderInstallment__c;
                w.SoIsfReference = rec.SalesOrderInstallment__r.Name;
                w.TrxnType       = 'INSTALLMENT';
            } else {
                w.ProjectName  = rec.SalesOrder__r.ProjectName__c;
                // 2.0 - Hudayriyat Golf Estates project changes
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
                w.SoSfid       = rec.SalesOrder__c;
                w.SoReference  = rec.SalesOrder__r.Name;
            }

            w.Description          = rec.Milestone_Description__c;
            w.EscrowAccountName    = rec.PaymentEscrowAccount__r.Name;
            w.EscrowAccountNo      = rec.PaymentEscrowAccount__r.AccountNumber__c;
            w.EscrowIBANNo         = rec.PaymentEscrowAccount__r.IBANNo__c;
            w.ReceiptNumber        = rec.Name;
            w.ReceiptType          = rec.Modeofpayment__c;
            w.CurrencyCode         = 'AED';
            w.ReceiptDate          = rec.ChequeDate__c != null
                                        ? Date.valueOf(rec.ChequeDate__c)
                                        : Date.valueOf(rec.ReceiptDate__c);
            w.MaturityDate         = w.ReceiptDate;
            w.GlDate               = rec.EBS_Clearing_Date__c != null
                                        ? rec.EBS_Clearing_Date__c : System.today();
            w.Amount               = rec.Receipt_Amount__c != null
                                        ? rec.Receipt_Amount__c : rec.AppliedAmount__c;
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
            w.Bypass               = rec.Receipt_Approved_Date__c != null ? 'N' : 'Y';
            if (rec.Receipt_Approved_Date__c != null) receiptMap.put(rec.Id, true);
            wrapLst.add(w);
        }
        return wrapLst;
    }

    // ══════════════════════════════════════════════════════════════════
    // PRIVATE — Response Parsers
    // ══════════════════════════════════════════════════════════════════

    private static Invoice__c parseInstallmentResponseNoDml(
        String decodedResponse,
        Map<Id, Boolean> invCrdMap,
        Map<Id, Boolean> refundinvMap
    ) {
        Invoice__c inv = new Invoice__c();
        if (String.isBlank(decodedResponse)) return inv;

        OIC_RequestWrapperController.OICResponseWrapperList respList =
            (OIC_RequestWrapperController.OICResponseWrapperList) JSON.deserialize(
                decodedResponse, OIC_RequestWrapperController.OICResponseWrapperList.class);
        if (respList == null) return inv;

        Map<String, Integer> retryMap = buildRetryMap('Invoice__c', respList.ResponseArray);
        Map<String, String>  errorMap = buildErrorMsgMap();

        for (OIC_RequestWrapperController.OICResponseWrapper r : respList.ResponseArray) {
            inv.Id = r.Sfid;
            if (r.Status == 'S') {
                if      (invCrdMap.containsKey(inv.Id))    inv.Oracle_Credit_Memo_Id__c = r.OracleId;
                else if (refundinvMap.containsKey(inv.Id)) { inv.OraclePartyId__c = r.OracleId; inv.Status__c = 'In Progress'; }
                else                                        inv.OraclePartyId__c = r.OracleId;
                inv.OICIntegrationStatus__c  = 'Transfer Success';
                inv.OICNoOfRetries__c        = null;
                inv.OICIntegrationMessage__c = null;
            } else if (r.Status == 'E') {
                inv.OICIntegrationStatus__c  = 'Transfer Failed';
                inv.OICIntegrationMessage__c = resolveErrorMessage(r.ErrorMsg, errorMap);
                inv.OICNoOfRetries__c        = retryMap.containsKey(r.Sfid)
                                                ? retryMap.get(r.Sfid) + 1 : 1;
            }
        }
        return inv;
    }

    private static Receipt__c parseReceiptResponseNoDml(
        String decodedResponse,
        Map<Id, Boolean> receiptMap
    ) {
        Receipt__c rec = new Receipt__c();
        if (String.isBlank(decodedResponse)) return rec;

        OIC_RequestWrapperController.OICResponseWrapperList respList =
            (OIC_RequestWrapperController.OICResponseWrapperList) JSON.deserialize(
                decodedResponse, OIC_RequestWrapperController.OICResponseWrapperList.class);
        if (respList == null) return rec;

        Map<String, Integer> retryMap = buildRetryMap('Receipt__c', respList.ResponseArray);
        Map<String, String>  errorMap = buildErrorMsgMap();

        for (OIC_RequestWrapperController.OICResponseWrapper r : respList.ResponseArray) {
            rec.Id = r.Sfid;
            if (r.Status == 'S') {
                rec.OICNoOfRetries__c        = null;
                rec.OICIntegrationMessage__c = null;
                if (receiptMap.containsKey(rec.Id)) rec.Oracle_Id_Temporary__c = r.OracleId;
                else                                rec.OraclePartyId__c       = r.OracleId;
                rec.OICIntegrationStatus__c  = 'Transfer Success';
            } else if (r.Status == 'E') {
                rec.OICIntegrationMessage__c    = resolveErrorMessage(r.ErrorMsg, errorMap);
                rec.OICNoOfRetries__c           = retryMap.containsKey(r.Sfid)
                                                    ? retryMap.get(r.Sfid) + 1 : 1;
                rec.Receipt_Approved_Checker__c = false;
                rec.Receipt_Approved_Date__c    = null;
                rec.Receipt_Approved_By__c      = null;
                rec.OICIntegrationStatus__c     = 'Transfer Failed';
            }
        }
        return rec;
    }

    private static SalesOrder__c parseSalesOrderResponseNoDml(String decodedResponse) {
        SalesOrder__c so = new SalesOrder__c();
        if (String.isBlank(decodedResponse)) return so;

        OIC_RequestWrapperController.OICSOResponseWrapperList respList =
            (OIC_RequestWrapperController.OICSOResponseWrapperList) JSON.deserialize(
                decodedResponse, OIC_RequestWrapperController.OICSOResponseWrapperList.class);
        if (respList == null) return so;

        Set<String> ids = new Set<String>();
        for (OIC_RequestWrapperController.OICSOResponseWrapper r : respList.ResponseArray)
            ids.add(r.Sfid);

        Map<String, Integer> retryMap = new Map<String, Integer>();
        if (!ids.isEmpty()) {
            for (SalesOrder__c rec : [
                SELECT Id, OICNoOfRetries__c FROM SalesOrder__c
                WHERE Id IN :ids AND OICNoOfRetries__c != null
            ]) retryMap.put(rec.Id, Integer.valueOf(rec.OICNoOfRetries__c));
        }

        Map<String, String> errorMap = buildErrorMsgMap();

        for (OIC_RequestWrapperController.OICSOResponseWrapper soResp : respList.ResponseArray) {
            so.Id = soResp.Sfid;
            if (soResp.Status == 'S') {
                so.OICNoOfRetries__c        = null;
                so.OICIntegrationMessage__c = null;
                so.OraclePartyId__c         = soResp.OracleId;
                so.OICIntegrationStatus__c  = 'Transfer Success';
                so.CustAcctId__c            = soResp.CustAcctId;
                so.OraclePartySiteID__c     = soResp.OraclePartySiteID;
                so.OracleCustAcctSiteID__c  = soResp.OracleCustAcctSiteID;
                so.OracleSiteUseID__c       = soResp.OracleSiteUseID;
            } else if (soResp.Status == 'E') {
                so.OICIntegrationStatus__c  = 'Transfer Failed';
                so.OICIntegrationMessage__c = resolveErrorMessage(soResp.ErrorMsg, errorMap);
                so.OICNoOfRetries__c        = retryMap.containsKey(soResp.Sfid)
                                                ? retryMap.get(soResp.Sfid) + 1 : 1;
            }
        }
        return so;
    }

    // ══════════════════════════════════════════════════════════════════
    // PRIVATE — Shared Utilities
    // ══════════════════════════════════════════════════════════════════

    private static String decodeBase64Response(String responseBody) {
        if (String.isBlank(responseBody)) return null;
        OIC_RequestWrapperController.Base64ResponseWrapper base64Wrap =
            (OIC_RequestWrapperController.Base64ResponseWrapper) JSON.deserialize(
                responseBody, OIC_RequestWrapperController.Base64ResponseWrapper.class);
        if (String.isBlank(base64Wrap.Base64Response)) return null;
        return EncodingUtil.base64Decode(base64Wrap.Base64Response).toString();
    }

    private static Map<String, Integer> buildRetryMap(
        String objectApiName,
        List<OIC_RequestWrapperController.OICResponseWrapper> responseArray
    ) {
        Set<String> ids = new Set<String>();
        for (OIC_RequestWrapperController.OICResponseWrapper r : responseArray) ids.add(r.Sfid);
        Map<String, Integer> retryMap = new Map<String, Integer>();
        if (ids.isEmpty()) return retryMap;
        String safeObject = String.escapeSingleQuotes(objectApiName);
        String query = 'SELECT Id, OICNoOfRetries__c FROM ' + safeObject
            + ' WHERE Id IN :ids AND OICNoOfRetries__c != null';
        for (SObject rec : Database.queryWithBinds(query, new Map<String, Object>{'ids' => ids}, AccessLevel.SYSTEM_MODE))
            retryMap.put((String) rec.get('Id'),
                Integer.valueOf((Decimal) rec.get('OICNoOfRetries__c')));
        return retryMap;
    }

    private static Map<String, String> buildErrorMsgMap() {
        Map<String, String> errorMap = new Map<String, String>();
        for (Integration_Error_Messages__mdt m : [
            SELECT System_Error_Msg__c, User_Error_Msg__c
            FROM Integration_Error_Messages__mdt
            WHERE IsActive__c = true AND Application_Type__c = 'EBS'
        ]) errorMap.put(m.System_Error_Msg__c, m.User_Error_Msg__c);
        return errorMap;
    }

    private static String resolveErrorMessage(String errorMsg, Map<String, String> errorMap) {
        if (String.isBlank(errorMsg)) return null;
        if (errorMsg.contains('Unknown integration error'))
            return 'Required information is not updated in Salesforce. Please contact support';
        String userMsg = UserErrorMessage.getUserErrorMessage(errorMsg, errorMap);
        return userMsg != null ? userMsg
            : 'Required information is not updated in Salesforce. Please contact support, ' + errorMsg;
    }
}