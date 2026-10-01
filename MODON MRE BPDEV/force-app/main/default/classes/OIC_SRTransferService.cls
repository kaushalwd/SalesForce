/**********************************************************************************************************************
* Name               : OIC_SRTransferService
* Description        : Integration callouts for Property Transfer — Oracle-Salesforce via OIC.
*                      Mirrors OIC_CancellationServices pattern: NoDml variants only,
*                      zero DML inside, CallouResult returned to batch for deferred commit.
* Usage              : Used by EBSTransferBatch only.
* Created By         : ActiveMinds
* --------------------------------------------------------------------------------------------------------------------
* Version       Author          Date              Comment
* 1.0           Manoj           13 Jun 2026       Initial Draft — split from OIC_CancellationServices
************************************************************************************************************************/
public class OIC_SRTransferService {

    // ══════════════════════════════════════════════════════════════════
    // PUBLIC ENTRY POINT
    // ══════════════════════════════════════════════════════════════════

    /**
     * Builds a single JSON payload for one Service Request, sends it to
     * Oracle Fusion via OIC, parses the response, and returns a
     * SRCalloutResult whose staged records the batch commits.
     *
     * CustomerArray        — built from the Account linked to the SR (transferee).
     * ReversalReceiptArray — built from Receipt__c records linked to the SR
     *                        that already have an OraclePartyId__c.
     * ChargesArray         — built from the invoiceIds supplied by the batch.
     *
     * @param srId        Service Request Id
     * @param soId        Related SalesOrder__c Id
     * @param invoiceIds  Invoice__c Ids — all go into ChargesArray
     * @param receiptsIds Receipt__c Ids — candidates for ReversalReceiptArray
     * @return            SRCalloutResult — staged SObjects + logs; caller does all DML
     */
    public static OIC_SRTransferWrappers.SRCalloutResult sendTransferNoDml(
        Id         srId,
        Id         soId,
        List<Id>   invoiceIds, List<Id> receiptsIds
    ) {
        OIC_SRTransferWrappers.SRCalloutResult result = new OIC_SRTransferWrappers.SRCalloutResult();

        try {
            // ── 1. Query Service Request (+ Account relationship) ─────
            ServiceRequest__c sr = querySR(srId);

            // ── 2. Query Sales Order ──────────────────────────────────
            SalesOrder__c so = querySO(soId);

            // ── 3. Query Invoices → ChargesArray ─────────────────────
            List<Invoice__c> invoices = queryInvoices(invoiceIds);

            // ── 4. Query Receipts → ReversalReceiptArray ──────────────
            List<Receipt__c> reversalReceipts = queryReversalReceipts(receiptsIds);

            // ── 5. Build and serialise the request envelope ───────────
            OIC_SRTransferWrappers.SRTransferRequest srReq =
                buildSRRequest(sr, so, invoices, reversalReceipts);

            OIC_SRTransferWrappers.SRTransferRequestList requestList =
                new OIC_SRTransferWrappers.SRTransferRequestList();
            requestList.RequestArray.add(srReq);

            String requestBody  = JSON.serialize(requestList);
            String base64String = EncodingUtil.base64Encode(Blob.valueOf(requestBody));

            OIC_RequestWrapperController.Base64Wrapper b64Wrapper =
                new OIC_RequestWrapperController.Base64Wrapper();
            b64Wrapper.Base64RequestPayload = base64String;

            // ── 6. HTTP callout ───────────────────────────────────────
            HttpRequest req = OIC_CredentialsController.getCredentials('ModonFusionSRTransferAPI');
            req.setTimeout(120000);
            req.setBody(JSON.serialize(b64Wrapper));
            req.setHeader('Accept', 'application/json');

            HTTPResponse res       = new Http().send(req);
            String decodedResponse = decodeBase64Response(res.getBody());

            // ── 7. Stage API log (no save) ────────────────────────────
            result.apiLog = LoggerService.createAPILog(
                'SR Transfer API', 'OIC_SRTransferService', 'sendTransferNoDml',
                requestBody, decodedResponse,
                'Status Code: ' + res.getStatusCode() + '; Status: ' + res.getStatus(),
                'Callout Log');

            // ── 8. Parse response → staged SObjects ───────────────────
            parseResponseNoDml(
                decodedResponse, soId,
                sr.Transferred_Sales_Order__r.CustomerAccount__c,
                invoiceIds, receiptsIds, result);

        } catch (Exception ex) {
            result.hasError       = true;
            result.srStatus       = 'E';
            result.srErrorMessage = ex.getMessage();
            result.errorLog       = LoggerService.createApexLog(
                ex, 'SR Transfer API', 'OIC_SRTransferService', 'sendTransferNoDml');
        }

        return result;
    }

    // ══════════════════════════════════════════════════════════════════
    // PRIVATE — Query Helpers
    // ══════════════════════════════════════════════════════════════════

    /**
     * Queries the Service Request together with all Account (transferee)
     * fields needed to populate CustomerArray.
     */
    @TestVisible
    private static ServiceRequest__c querySR(Id srId) {
        List<ServiceRequest__c> srList = [
            SELECT Id, Name, Status__c, RecordType.Name,SalesOrder__c,Transferred_Sales_Order__c, Transferred_Sales_Order__r.CustomerAccount__c
            FROM   ServiceRequest__c
            WHERE  Id = :srId
            LIMIT  1
        ];
        if (srList.isEmpty()) {
            throw new AuraHandledException('Service Request not found: ' + srId);
        }
        return srList[0];
    }
	@TestVisible
	private static SalesOrder__c querySO(Id soId) {
        List<SalesOrder__c> soList = [
            SELECT Id, Name,
                   CustomerAccount__c,
                   CustomerAccount__r.OraclePartyId__c,
                   OraclePartyId__c,
                   CustAcctId__c,
                   OraclePartySiteID__c,
                   OracleCustAcctSiteID__c,
                   OracleSiteUseID__c,
                   Status__c,
                   ProjectName__c,
                   Unit__r.Name,
                   Unit__r.Project_Name__c,
                   Unit__r.Phase__r.Name,
                   Unit__r.Phase__r.EntityName__c,
                   Unit__r.UnitClassification__c,
                   VirtualAccount__r.VirtualAccountNumber__c,
                   VirtualAccount__r.VirtualIBANNumber__c,
                   NotToBeShownOnRD__c,
                   Source_Entity__c
            FROM   SalesOrder__c
            WHERE  Id                  = :soId
              AND  NotToBeShownOnRD__c = false
              AND  Source_Entity__c    != 'Modon - Egypt'
            LIMIT  1
        ];
        if (soList.isEmpty()) {
            throw new AuraHandledException('Sales Order not found or ineligible: ' + soId);
        }
        return soList[0];
    }

    /**
     * Full field set for Invoice__c — supports both the SOI path and
     * the direct Sales_Order path used in buildChargeWrapper().
     */
    @TestVisible
    private static List<Invoice__c> queryInvoices(List<Id> invoiceIds) {
        if (invoiceIds == null || invoiceIds.isEmpty()) return new List<Invoice__c>();
        return [
            SELECT Id, Name,
                   InvoiceAmount__c, Ebs_Invoice_Date__c, InvoiceDate__c,
                   InvoiceStatus__c, Account__c,
                   Account__r.OraclePartyId__c,
                   Sales_Order__c,
                   Sales_Order__r.Name,
                   Sales_Order__r.NotToBeShownOnRD__c,
                   Sales_Order__r.Source_Entity__c,
                   Sales_Order__r.CustAcctId__c,
                   Sales_Order__r.OraclePartySiteID__c,
                   Sales_Order__r.OracleCustAcctSiteID__c,
                   Sales_Order__r.OracleSiteUseID__c,
                   Sales_Order__r.Unit__r.Name,
                   Sales_Order__r.Unit__c,
                   Sales_Order__r.Unit__r.Project_Name__c,
                   Sales_Order__r.Unit__r.Phase__r.Name,
                   Sales_Order__r.Unit__r.Phase__r.EntityName__c,
                   Sales_Order__r.Unit__r.UnitClassification__c,
                   Sales_Order__r.Unit__r.PlotNo__c,
                   Sales_Order__r.VirtualAccount__r.VirtualAccountNumber__c,
                   Sales_Order__r.VirtualAccount__r.VirtualIBANNumber__c,
                   Sales_Order__r.VirtualAccount__r.Name,
                   Sales_Order__r.VirtualAccount__r.EscrowAccount__r.AccountNumber__c,
                   Sales_Order__r.VirtualAccount__r.EscrowAccount__r.IBANNo__c,
                   Sales_Order__r.VirtualAccount__r.EscrowAccount__r.StoreId__c,
                   Sales_Order__r.VirtualAccount__r.EscrowAccount__r.SwiftCode__c,
                   Sales_Order__r.VirtualAccount__r.EscrowAccount__r.TradeID__c,
                   Sales_Order__r.VirtualAccount__r.EscrowAccount__r.BankName__c,
                   Sales_Order__r.VirtualAccount__r.EscrowAccount__r.BeneficiaryName__c,
                   SalesOrderInstallment__c,
                   SalesOrderInstallment__r.Name,
                   SalesOrderInstallment__r.Milestone_Name__c,
                   SalesOrderInstallment__r.SalesOrder__c,
                   SalesOrderInstallment__r.SalesOrder__r.Name,
                   SalesOrderInstallment__r.SalesOrder__r.NotToBeShownOnRD__c,
                   SalesOrderInstallment__r.SalesOrder__r.Source_Entity__c,
                   SalesOrderInstallment__r.SalesOrder__r.CustAcctId__c,
                   SalesOrderInstallment__r.SalesOrder__r.OraclePartySiteID__c,
                   SalesOrderInstallment__r.SalesOrder__r.OracleCustAcctSiteID__c,
                   SalesOrderInstallment__r.SalesOrder__r.OracleSiteUseID__c,
                   SalesOrderInstallment__r.SalesOrder__r.Unit__c,
                   SalesOrderInstallment__r.SalesOrder__r.Unit__r.Name,
                   SalesOrderInstallment__r.SalesOrder__r.Unit__r.Project_Name__c,
                   SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__r.Name,
                   SalesOrderInstallment__r.SalesOrder__r.Unit__r.Phase__r.EntityName__c,
                   SalesOrderInstallment__r.SalesOrder__r.Unit__r.UnitClassification__c,
                   SalesOrderInstallment__r.SalesOrder__r.Unit__r.PlotNo__c,
                   SalesOrderInstallment__r.SalesOrder__r.VirtualAccount__r.VirtualAccountNumber__c,
                   SalesOrderInstallment__r.SalesOrder__r.VirtualAccount__r.VirtualIBANNumber__c,
                   SalesOrderInstallment__r.SalesOrder__r.VirtualAccount__r.Name,
                   SalesOrderInstallment__r.SalesOrder__r.VirtualAccount__r.EscrowAccount__r.AccountNumber__c,
                   SalesOrderInstallment__r.SalesOrder__r.VirtualAccount__r.EscrowAccount__r.IBANNo__c,
                   SalesOrderInstallment__r.SalesOrder__r.VirtualAccount__r.EscrowAccount__r.StoreId__c,
                   SalesOrderInstallment__r.SalesOrder__r.VirtualAccount__r.EscrowAccount__r.SwiftCode__c,
                   SalesOrderInstallment__r.SalesOrder__r.VirtualAccount__r.EscrowAccount__r.TradeID__c,
                   SalesOrderInstallment__r.SalesOrder__r.VirtualAccount__r.EscrowAccount__r.BankName__c,
                   SalesOrderInstallment__r.SalesOrder__r.VirtualAccount__r.EscrowAccount__r.BeneficiaryName__c,
                   Charge__r.Type__c,
                   OraclePartyId__c,
                   Actual_Invoice_Amount__c,
                   RecordType.Name
            FROM   Invoice__c
            WHERE  Id IN :invoiceIds
        ];
    }

    /**
     * Receipts already in Oracle (OraclePartyId__c != null) that are
     * linked to this SR and need reversal.
     */
    @TestVisible
    private static List<Receipt__c> queryReversalReceipts(list<id> receiptIds) {
        
        return [
            SELECT Id, Name, OraclePartyId__c
            FROM   Receipt__c
            WHERE  id IN : receiptIds
              AND  OraclePartyId__c != null ];
    }

    // ══════════════════════════════════════════════════════════════════
    // PRIVATE — Request Builder
    // ══════════════════════════════════════════════════════════════════
	@TestVisible
    private static OIC_SRTransferWrappers.SRTransferRequest buildSRRequest(
        ServiceRequest__c sr,
        SalesOrder__c     so,
        List<Invoice__c>  invoices,
        List<Receipt__c>  reversalReceipts
    ) {
        Map<String, String> chargeToTrxnMap = new Map<String, String>();
        for (ChargeTypeToTrxnType__mdt cfg : ChargeTypeToTrxnType__mdt.getAll().values()) {
            chargeToTrxnMap.put(cfg.ChargeType__c, cfg.TrxnType__c);
        }

        OIC_SRTransferWrappers.SRTransferRequest req = new OIC_SRTransferWrappers.SRTransferRequest();

        // ── SR header ────────────────────────────────────────────────
        req.sfSrId     = sr.Id;
        req.srType     = 'Transfer';
        req.srNumber   = sr.Name;
        req.srStatus   = sr.Status__c;
        req.EntityName = so.Unit__r.Phase__r.EntityName__c;
        req.sfSoId     = so.Id;
        req.OracleSoId = so.OraclePartyId__c != null ? so.OraclePartyId__c : '';
        req.sfSoCustId = so.CustomerAccount__c;

        // ── CustomerArray — one element: the transferee Account ───────
        req.CustomerArray.add(buildCustomerWrapper(sr.Transferred_Sales_Order__r.CustomerAccount__c));

        // ── ReversalReceiptArray ──────────────────────────────────────
        for (Receipt__c rec : reversalReceipts) {
            OIC_SRTransferWrappers.ReversalReceiptWrapper rw =
                new OIC_SRTransferWrappers.ReversalReceiptWrapper();
            rw.receiptSFID      = rec.Id;
            rw.receiptID        = rec.OraclePartyId__c;
            rw.reversalComments = 'Property Transfer';
            rw.ExtraInfo1       = '';
            rw.ExtraInfo2       = '';
            rw.ExtraInfo3       = '';
            req.ReversalReceiptArray.add(rw);
        }

        // ── ChargesArray — all invoices ───────────────────────────────
        for (Invoice__c inv : invoices) {
            req.ChargesArray.add(buildChargeWrapper(inv, chargeToTrxnMap));
        }

        return req;
    }

    // ──────────────────────────────────────────────────────────────────
    // CustomerWrapper builder — Account / transferee identity
    // ──────────────────────────────────────────────────────────────────
	@TestVisible
  	private static OIC_SRTransferWrappers.CustomerWrapper buildCustomerWrapper(
        Id accountIds
    ) {
        List<String> excludeStatuses = new List<String>{'Modon - Egypt'};
        Account accRec = [
            SELECT Id, Name, PersonTitle, FirstName, MiddleName, LastName,
                   EIDNumber__pc, RecordType.Name, EmiratesIDExpiryDate__pc,
                   Emirates_ID_Issue_Date__pc,
                   (SELECT Id, Name, Email, EIDNumber__c, Birthdate,
                           MobilePhone, Nationality__c
                    FROM Contacts LIMIT 1),
                   IsPersonAccount, TradeName__c, UnifiedNumber__c,
                   PersonEmail, Phone, BillingCountry, PassportNumber__pc,
                   PassportIssuancePlace__pc, PersonGenderIdentity,
                   MaritalStatus__pc, PersonBirthdate, UAE_Resident_Status__pc,
                   PassportExpiryDate__pc, Nationality__pc,
                   BillingCity, BillingState, BillingAddress, BillingStreet,
                   UAEVATRegisterNumber__c, PersonMobilePhone,
                   PersonMailingCity, PersonMailingStreet, PersonMailingState,
                   PersonMailingCountry, PersonMailingPostalCode
            FROM   Account
            WHERE  Id = :accountIds           // single Id — keep LIMIT 1
              AND  Source_Entity__c NOT IN :excludeStatuses
            LIMIT  1
        ];

        OIC_SRTransferWrappers.CustomerWrapper w =
            new OIC_SRTransferWrappers.CustomerWrapper();

        // ── Common identity fields (both types) ───────────────────────
        w.Sfid  = accRec.Id;

        if (accRec.RecordType.Name == 'OrganizationAccount') {

            // ══ ORGANIZATION — core fields from Account ═══════════════
            w.CustomerType          = 'ORGANIZATION';
            w.OrganizationName      = accRec.Name;
            w.TradeName             = accRec.TradeName__c;
            w.UnifiedNumber         = accRec.UnifiedNumber__c;
            w.VatRegistrationNumber = accRec.UAEVATRegisterNumber__c;

            // Representative name carried on the Account itself
            w.FirstName             = accRec.FirstName;
            w.MiddleName            = accRec.MiddleName;
            w.LastName              = accRec.LastName;

            // ── Contact sub-record (email / phone) ────────────────────
            if (accRec.Contacts != null && !accRec.Contacts.isEmpty()) {
                Contact c      = accRec.Contacts[0];
                w.EmailAddress = c.Email;
                w.PhoneNumber  = c.MobilePhone;
            }

            // ── Billing address ───────────────────────────────────────
            w.Country  = accRec.BillingCountry;
            w.City     = accRec.BillingCity;
            w.State    = accRec.BillingState;
            w.Province = accRec.BillingState;
            w.Address1 = accRec.BillingStreet;
            w.Address2 = '';

        } else {

            // ══ PERSON ACCOUNT ════════════════════════════════════════
            w.CustomerType       = 'PERSON';

            // ── Identity ──────────────────────────────────────────────
            w.Title              = accRec.PersonTitle;
            w.FirstName          = accRec.FirstName;
            w.MiddleName         = accRec.MiddleName;
            w.LastName           = accRec.LastName;
            w.Gender             = accRec.PersonGenderIdentity;
            w.MartialStatus      = accRec.MaritalStatus__pc;
            w.DateOfBirth        = accRec.PersonBirthdate != null
                                   ? String.valueOf(accRec.PersonBirthdate) : null;

            // ── ID documents ──────────────────────────────────────────
            w.PassportNumber     = accRec.PassportNumber__pc;
            w.PassportExpiryDate = accRec.PassportExpiryDate__pc != null
                                   ? String.valueOf(accRec.PassportExpiryDate__pc) : null;
            w.PassportPlaceOfIssue = accRec.PassportIssuancePlace__pc;
            w.EmiratesId         = accRec.EIDNumber__pc;
            w.EmiratesIdExpDate  = accRec.EmiratesIDExpiryDate__pc != null
                                   ? String.valueOf(accRec.EmiratesIDExpiryDate__pc) : null;
            w.IssueDate          = accRec.Emirates_ID_Issue_Date__pc != null
                                   ? String.valueOf(accRec.Emirates_ID_Issue_Date__pc) : null;
            w.ExpiryDate         = accRec.EmiratesIDExpiryDate__pc != null
                                   ? String.valueOf(accRec.EmiratesIDExpiryDate__pc) : null;
            w.Nationality        = accRec.Nationality__pc;
            w.IsUaeCustomer      = accRec.UAE_Resident_Status__pc == 'Resident' ? 'Y' : 'N';

            // ── Contact ───────────────────────────────────────────────
            w.EmailAddress       = accRec.PersonEmail;
            w.PhoneNumber        = accRec.Phone;

            // ── Mailing address (Person Account uses PersonMailing*) ──
            w.Country            = accRec.PersonMailingCountry;
            w.City               = accRec.PersonMailingCity;
            w.State              = accRec.PersonMailingState;
            w.Province           = accRec.PersonMailingState;
            w.Address1           = accRec.PersonMailingStreet;
            w.Address2           = '';
            w.placeOfRegistration = accRec.PassportIssuancePlace__pc;
        }

        return w;
    }

    // ──────────────────────────────────────────────────────────────────
    // ChargeWrapper builder — Invoice__c → ChargesArray
    // Mirrors OIC_TransferServices field logic; SOI path takes priority.
    // ──────────────────────────────────────────────────────────────────
	@TestVisible
    private static OIC_SRTransferWrappers.ChargeWrapper buildChargeWrapper(
        Invoice__c          inv,
        Map<String, String> chargeToTrxnMap
    ) {
        OIC_SRTransferWrappers.ChargeWrapper w = new OIC_SRTransferWrappers.ChargeWrapper();

        // ── Identity / shared ─────────────────────────────────────────
        w.Sfid              = inv.Id;
        w.CustomerSfid      = inv.Account__c;
        w.CustomerPartyId   = inv.Account__r.OraclePartyId__c != null
                              ? inv.Account__r.OraclePartyId__c : '';
        w.CustomerAcct      = '';
        w.OrgIdentifier     = UserInfo.getOrganizationId();
        w.InstallmentNumber = inv.Name;
        w.Status            = 'OPEN';

        // ── TrxnType ─────────────────────────────────────────────────
        Boolean useSOI = (inv.SalesOrderInstallment__c != null
            && inv.SalesOrderInstallment__r.SalesOrder__r.OraclePartySiteID__c  != null
            && inv.SalesOrderInstallment__r.SalesOrder__r.OracleCustAcctSiteID__c != null
            && inv.SalesOrderInstallment__r.SalesOrder__r.NotToBeShownOnRD__c   == false
            && inv.SalesOrderInstallment__r.SalesOrder__r.Source_Entity__c      != 'Modon - Egypt');

        String trxnType = useSOI ? 'INSTALLMENT'
            : (chargeToTrxnMap.containsKey(inv.Charge__r.Type__c)
               ? chargeToTrxnMap.get(inv.Charge__r.Type__c) : 'ADM_CHARGES');
        w.TrxnType = trxnType;

        // ── Amount ────────────────────────────────────────────────────
        if (inv.InvoiceAmount__c != null) {
            w.Amount = (trxnType == 'MODON_FEE' || trxnType == 'NOC_FEE')
                        ? inv.Actual_Invoice_Amount__c : inv.InvoiceAmount__c;
        }

        // ── Dates ─────────────────────────────────────────────────────
        w.InvoiceDate = inv.InvoiceDate__c != null
                        ? String.valueOf(inv.InvoiceDate__c)
                        : (inv.Ebs_Invoice_Date__c != null
                           ? String.valueOf(inv.Ebs_Invoice_Date__c)
                           : String.valueOf(System.today()));
        w.GlDate      = inv.Ebs_Invoice_Date__c != null
                        ? String.valueOf(inv.Ebs_Invoice_Date__c)
                        : String.valueOf(System.today());

        // ── Path-specific fields ──────────────────────────────────────
        if (useSOI) {
            SalesOrderInstallments__c soi = inv.SalesOrderInstallment__r;
            w.SoSfid               = soi.SalesOrder__c;
            w.SoIsfid              = inv.SalesOrderInstallment__c;
            w.SoIsfReference       = soi.Name;
            w.SoReference          = soi.SalesOrder__r.Name;
            w.Description          = soi.Milestone_Name__c;
            w.EscrowAccountNumber  = soi.SalesOrder__r.VirtualAccount__r.EscrowAccount__r.AccountNumber__c;
            w.EscrowIbanNumber     = soi.SalesOrder__r.VirtualAccount__r.EscrowAccount__r.IBANNo__c;
            w.EscrowStoreId        = soi.SalesOrder__r.VirtualAccount__r.EscrowAccount__r.StoreId__c;
            w.EscrowSwiftCode      = soi.SalesOrder__r.VirtualAccount__r.EscrowAccount__r.SwiftCode__c;
            w.EscrowTradeId        = soi.SalesOrder__r.VirtualAccount__r.EscrowAccount__r.TradeID__c;
            w.EscrowBankName       = soi.SalesOrder__r.VirtualAccount__r.EscrowAccount__r.BankName__c;
            w.EscrowBenificaryName = soi.SalesOrder__r.VirtualAccount__r.EscrowAccount__r.BeneficiaryName__c;
            w.Unit                 = soi.SalesOrder__r.Unit__r.PlotNo__c;
            w.ExtraInfo1           = soi.SalesOrder__r.Unit__r.PlotNo__c;
            w.UnitName             = soi.SalesOrder__r.Unit__r.Name;
            w.UnitSfId             = soi.SalesOrder__r.Unit__c;
            w.VirtualAccountNumber = soi.SalesOrder__r.VirtualAccount__r.VirtualAccountNumber__c;
            w.VirtualIbanNumber    = soi.SalesOrder__r.VirtualAccount__r.VirtualIBANNumber__c;
            w.ProjectName          = soi.SalesOrder__r.Unit__r.Project_Name__c;
            w.ProjectPhase         = soi.SalesOrder__r.Unit__r.Phase__r.Name;
            w.CustAcctId           = soi.SalesOrder__r.CustAcctId__c != null
                                     ? soi.SalesOrder__r.CustAcctId__c : '';
            w.OraclePartySiteID    = soi.SalesOrder__r.OraclePartySiteID__c != null
                                     ? soi.SalesOrder__r.OraclePartySiteID__c : '';
            w.OracleCustAcctSiteID = soi.SalesOrder__r.OracleCustAcctSiteID__c != null
                                     ? soi.SalesOrder__r.OracleCustAcctSiteID__c : '';
            w.OracleSiteUseID      = soi.SalesOrder__r.OracleSiteUseID__c != null
                                     ? soi.SalesOrder__r.OracleSiteUseID__c : '';
            w.ExtraInfo2           = resolveExtraInfo2(
                soi.SalesOrder__r.Unit__r.Project_Name__c,
                soi.SalesOrder__r.Unit__r.UnitClassification__c,
                soi.SalesOrder__r.Unit__r.Name,
                soi.SalesOrder__r.Unit__r.Phase__r.Name);

        } else {
            // Direct Sales_Order path
            w.SoSfid               = inv.Sales_Order__c;
            w.SoIsfid              = '';
            w.SoReference          = inv.Sales_Order__r.Name;
            w.Description          = inv.Sales_Order__r.Unit__r.Project_Name__c + '|'
                                     + inv.Sales_Order__r.Unit__r.Phase__r.Name + '|' + trxnType;
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
            w.ProjectPhase         = inv.Sales_Order__r.Unit__r.Phase__r.Name;
            w.CustAcctId           = inv.Sales_Order__r.CustAcctId__c != null
                                     ? inv.Sales_Order__r.CustAcctId__c : '';
            w.OraclePartySiteID    = inv.Sales_Order__r.OraclePartySiteID__c != null
                                     ? inv.Sales_Order__r.OraclePartySiteID__c : '';
            w.OracleCustAcctSiteID = inv.Sales_Order__r.OracleCustAcctSiteID__c != null
                                     ? inv.Sales_Order__r.OracleCustAcctSiteID__c : '';
            w.OracleSiteUseID      = inv.Sales_Order__r.OracleSiteUseID__c != null
                                     ? inv.Sales_Order__r.OracleSiteUseID__c : '';
            w.ExtraInfo2           = resolveExtraInfo2(
                inv.Sales_Order__r.Unit__r.Project_Name__c,
                inv.Sales_Order__r.Unit__r.UnitClassification__c,
                inv.Sales_Order__r.Unit__r.Name,
                inv.Sales_Order__r.Unit__r.Phase__r.Name);
        }

        return w;
    }

    // ══════════════════════════════════════════════════════════════════
    // PRIVATE — Response Parser
    // ══════════════════════════════════════════════════════════════════

    /**
     * Parses the decoded OIC response and populates staged SObjects
     * inside SRCalloutResult.  Zero DML, zero LoggerService.save().
    
     * responseCustomerArray (status S):
     *   → SalesOrder__c : CustAcctId__c, Oracle site IDs, OICIntegrationStatus__c = 'Transfer Success'
     *   → Account__c    : OraclePartyId__c,              OICIntegrationStatus__c = 'Transfer Success'
     * ReversalReceiptArray response (status S/E):
     *   → Receipt__c    : OICIntegrationStatus__c = 'Transfer Success' / 'Transfer Failed'
     * ChargesArray response (status S):
     *   → Invoice__c    : OraclePartyId__c,              OICIntegrationStatus__c = 'Transfer Success'
     */
    @TestVisible
    private static void parseResponseNoDml(
        String                                 decodedResponse,
        Id                                     soId,
        Id                                     accountId,
        List<Id>                               invoiceIds,
        List<Id>                               receiptIds,
        OIC_SRTransferWrappers.SRCalloutResult result
    ) {
        if (String.isBlank(decodedResponse)) {
            result.srStatus       = 'E';
            result.srErrorMessage = 'Empty response from OIC';
            result.hasError       = true;
            return;
        }

        OIC_SRTransferWrappers.SRTransferResponseList respList =
            (OIC_SRTransferWrappers.SRTransferResponseList) JSON.deserialize(
                decodedResponse, OIC_SRTransferWrappers.SRTransferResponseList.class);

        if (respList == null || respList.ResponseArray == null
                             || respList.ResponseArray.isEmpty()) {
            result.srStatus       = 'E';
            result.srErrorMessage = 'Null or empty ResponseArray from OIC';
            result.hasError       = true;
            return;
        }

        Map<String, String>  errorMap    = buildErrorMsgMap();
        Map<String, Integer> invRetryMap = buildRetryMap('Invoice__c',    invoiceIds);
        Map<String, Integer> recRetryMap = buildRetryMap('Receipt__c',    receiptIds);
        Map<String, Integer> soRetryMap  = buildRetryMap('SalesOrder__c', new List<Id>{ soId });
        Map<String, Integer> accRetryMap = buildRetryMap('Account',       new List<Id>{ accountId });

        for (OIC_SRTransferWrappers.SRTransferResponse srResp : respList.ResponseArray) {

            // ── SR-level outcome ──────────────────────────────────────
            result.srStatus       = srResp.status;
            result.srErrorMessage = srResp.errMsg;

            // Header-level failure ("status":"E" at the ResponseArray item
            // level) → flag the whole callout as a hard error so the batch
            // marks the SR 'Partially Completed' and rebuilds SR_Sync_Ids__c.
            if (srResp.status == 'E') {
                result.hasError = true;
            }

            // ── responseCustomerArray → SalesOrder__c + Account__c ───
            if (srResp.responseCustomerArray != null) {
                for (OIC_SRTransferWrappers.CustomerResponseWrapper cResp
                        : srResp.responseCustomerArray) {

                    if (cResp.status == 'S') {

                        // Stage SalesOrder__c — Oracle site IDs from Fusion
                        SalesOrder__c soRec = new SalesOrder__c(Id = soId);
                        soRec.CustAcctId__c            = cResp.CustAcctId != null
                                                         ? String.valueOf(cResp.CustAcctId) : null;
                        soRec.OraclePartySiteID__c      = cResp.OraclePartySiteID != null
                                                         ? String.valueOf(cResp.OraclePartySiteID) : null;
                        soRec.OracleCustAcctSiteID__c   = cResp.OracleCustAcctSiteID != null
                                                         ? String.valueOf(cResp.OracleCustAcctSiteID) : null;
                        soRec.OracleSiteUseID__c        = cResp.OracleSiteUseID != null
                                                         ? String.valueOf(cResp.OracleSiteUseID) : null;
                        soRec.OICIntegrationStatus__c   = 'Transfer Success';
                        
                        soRec.OICIntegrationMessage__c  = null;
                        soRec.OICNoOfRetries__c         = null;
                        result.salesOrderRecord         = soRec;

                        // Stage Account__c — new Oracle party id for transferee.
                        // Guard against null: this sample response does not
                        // include OraclePartyId, so don't blank out an
                        // existing value if Oracle doesn't return one.
                        Account accRec = new Account(Id = accountId);
                        if (cResp.OraclePartyId != null) {
                            accRec.OraclePartyId__c = cResp.OraclePartyId;
                        }
                        accRec.OICIntegrationStatus__c  = 'S';
                        accRec.OICIntegrationMessage__c = null;
                        accRec.OICNoOfRetries__c        = null;
                        result.accountRecord            = accRec;

                    } else if (cResp.status == 'E') {

                        // Stage SalesOrder__c failure
                        SalesOrder__c soRec = new SalesOrder__c(Id = soId);
                        soRec.OICIntegrationStatus__c   = 'Transfer Failed';
                        soRec.OICIntegrationMessage__c  = resolveErrorMessage(cResp.errMsg, errorMap);
                        soRec.OICNoOfRetries__c         = soRetryMap.containsKey(String.valueOf(soId))
                                                          ? soRetryMap.get(String.valueOf(soId)) + 1 : 1;
                        result.salesOrderRecord         = soRec;

                        // Stage Account__c failure
                        Account accRec = new Account(Id = accountId);
                        accRec.OICIntegrationStatus__c  = 'E';
                        accRec.OICIntegrationMessage__c = resolveErrorMessage(cResp.errMsg, errorMap);
                        accRec.OICNoOfRetries__c        = accRetryMap.containsKey(String.valueOf(accountId))
                                                          ? accRetryMap.get(String.valueOf(accountId)) + 1 : 1;
                        result.accountRecord            = accRec;
                    }
                }
            }

            // ── ReversalReceiptArray response → Receipt__c ────────────
            // ── ReversalReceiptArray response → Receipt__c ────────────
            if (srResp.ReversalReceiptArray != null) {
                for (OIC_SRTransferWrappers.ReversalReceiptResponseWrapper rrResp
                        : srResp.ReversalReceiptArray) {
                    Receipt__c recUpd = new Receipt__c(Id = rrResp.Sfid);

                    if (rrResp.status == 'S') {
                        recUpd.OICIntegrationStatus__c  = 'Transfer Success';
                        recUpd.OICIntegrationMessage__c = null;
                        recUpd.OICNoOfRetries__c        = null;

                    } else if (rrResp.status == 'E') {
                        recUpd.OICIntegrationStatus__c  = 'Transfer Failed';
                        recUpd.OICIntegrationMessage__c = resolveErrorMessage(rrResp.errMsg, errorMap);
                        recUpd.OICNoOfRetries__c        = recRetryMap.containsKey(rrResp.Sfid)
                                                          ? recRetryMap.get(rrResp.Sfid) + 1 : 1;
                    }
                    result.receiptRecords.add(recUpd);
                }
            }

            // ── ChargesArray response → Invoice__c ───────────────────
            if (srResp.ChargesArray != null) {
                for (OIC_SRTransferWrappers.ChargeResponseWrapper chResp : srResp.ChargesArray) {
                    Invoice__c inv = new Invoice__c(Id = chResp.Sfid);
                    if (chResp.status == 'S') {
                        inv.OraclePartyId__c         = chResp.oracleID;
                        inv.OICIntegrationStatus__c  = 'Transfer Success';
                        inv.OICIntegrationMessage__c = null;
                        inv.OICNoOfRetries__c        = null;
                    } else if (chResp.status == 'E') {
                        inv.OICIntegrationStatus__c  = 'Transfer Failed';
                        inv.OICIntegrationMessage__c = resolveErrorMessage(chResp.errMsg, errorMap);
                        inv.OICNoOfRetries__c        = invRetryMap.containsKey(chResp.Sfid)
                                                       ? invRetryMap.get(chResp.Sfid) + 1 : 1;
                    }
                    result.invoiceRecords.add(inv);
                }
            }
        }
    }

    // ══════════════════════════════════════════════════════════════════
    // PRIVATE — Utilities
    // ══════════════════════════════════════════════════════════════════

    /**
     * Decodes the OIC HTTP response body.
     *
     * Two shapes are possible from this endpoint:
     *   1. {"Base64Response":"<base64-encoded JSON>"}  — legacy envelope
     *   2. {"ResponseArray":[...]}                       — raw JSON, the
     *      shape this SR Transfer API currently returns
     *
     * Deserializing shape (2) as Base64ResponseWrapper throws
     * "Unknown property ResponseArray", which previously bubbled up to
     * the outer try/catch in sendTransferNoDml, set result.hasError = true
     * with a generic exception message, and skipped parseResponseNoDml
     * entirely (so the caller never saw a usable result). We now catch
     * that case and treat the body as already-decoded JSON.
     */
    @TestVisible
    private static String decodeBase64Response(String responseBody) {
        if (String.isBlank(responseBody)) return null;

        try {
            OIC_RequestWrapperController.Base64ResponseWrapper b64 =
                (OIC_RequestWrapperController.Base64ResponseWrapper) JSON.deserialize(
                    responseBody, OIC_RequestWrapperController.Base64ResponseWrapper.class);

            if (b64 != null && String.isNotBlank(b64.Base64Response)) {
                return EncodingUtil.base64Decode(b64.Base64Response).toString();
            }
        } catch (Exception ex) {
            System.debug('OIC_SRTransferServiceV1.decodeBase64Response — '
                + 'response is not a Base64 envelope, using raw body. ' + ex.getMessage());
        }

        // Not a Base64 envelope (or Base64Response was blank) — treat as raw JSON.
        return responseBody;
    }
	@TestVisible
    private static Map<String, Integer> buildRetryMap(String objectApiName, List<Id> ids) {
        Map<String, Integer> retryMap = new Map<String, Integer>();
        if (ids == null || ids.isEmpty()) return retryMap;
        Set<Id> idSet = new Set<Id>(ids);
        String safeObject = String.escapeSingleQuotes(objectApiName);
        String soql = 'SELECT Id, OICNoOfRetries__c FROM ' + safeObject
                    + ' WHERE Id IN :idSet AND OICNoOfRetries__c != null';
        for (SObject rec : Database.queryWithBinds(soql, new Map<String, Object>{'idSet' => idSet}, AccessLevel.SYSTEM_MODE)) {
            retryMap.put(
                (String) rec.get('Id'),
                Integer.valueOf((Decimal) rec.get('OICNoOfRetries__c')));
        }
        return retryMap;
    }

    private static Map<String, String> buildErrorMsgMap() {
        Map<String, String> errorMap = new Map<String, String>();
        for (Integration_Error_Messages__mdt m : [
            SELECT System_Error_Msg__c, User_Error_Msg__c
            FROM   Integration_Error_Messages__mdt
            WHERE  IsActive__c = true AND Application_Type__c = 'EBS'
        ]) errorMap.put(m.System_Error_Msg__c, m.User_Error_Msg__c);
        return errorMap;
    }

    private static String resolveErrorMessage(String errorMsg, Map<String, String> errorMap) {
        if (String.isBlank(errorMsg)) return null;
        if (errorMsg.contains('Unknown integration error'))
            return 'Required information is not updated in Salesforce. Please contact support';
        String userMsg = UserErrorMessage.getUserErrorMessage(errorMsg, errorMap);
        return userMsg != null
               ? userMsg
               : 'Required information is not updated in Salesforce. Please contact support, ' + errorMsg;
    }

    /**
     * Resolves ExtraInfo2 — Oracle segment identifier.
     * Mirrors OIC_TransferServices v2.0 Hudayriyat Golf Estates logic.
     */
    @TestVisible
    private static String resolveExtraInfo2(
        String projectName, String unitClassification,
        String unitName,    String phaseName
    ) {
        if (projectName == 'Hudayriyat Golf Estates') return projectName + '-' + unitClassification;
        if (projectName == 'Commercial Plots')         return unitName;
        return projectName + '-' + phaseName;
    }
}