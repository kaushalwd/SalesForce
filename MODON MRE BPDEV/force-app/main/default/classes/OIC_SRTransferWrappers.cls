/***********************************************************************************************************************
* Name               : OIC_SRTransferWrappers
* Description        : Request and Response wrapper classes for the unified SR-level Property Transfer
*                      callout to Oracle Fusion via OIC.
*                      A single JSON envelope carries the SR header, CustomerArray (account / transferee
*                      identity details), ReversalReceiptArray (receipt reversals for old owner),
*                      and ChargesArray (all Invoice__c records for the transfer).
* Usage              : Used exclusively by OIC_SRTransferServicev1 and EBSTransferBatch.
* Created By         : ActiveMinds
* --------------------------------------------------------------------------------------------------------------------
* Version       Author          Date              Comment
* 1.0           ActiveMinds     12 Jun 2026       Initial — unified SR JSON callout pattern
***********************************************************************************************************************/
public class OIC_SRTransferWrappers {

    // ══════════════════════════════════════════════════════════════════
    // ── REQUEST WRAPPERS ─────────────────────────────────────────────
    // ══════════════════════════════════════════════════════════════════

    /** Root request envelope — serialises to { "RequestArray": [...] } */
    public class SRTransferRequestList {
        public List<SRTransferRequest> RequestArray = new List<SRTransferRequest>();
    }

    /**
     * One SR per RequestArray element.
     * Header fields mirror the JSON root object;
     * three child arrays carry the detail.
     */
    public class SRTransferRequest {
        public String sfSrId;
        public String srType;           // always "Transfer"
        public String srNumber;
        public String srStatus;
        public String EntityName;       // e.g. "Hudayriyat Development - L.L.C- O.P.C"
        public String sfSoId;
        public String OracleSoId;       // existing Oracle SO id; blank on first sync
        public String sfSoCustId;
        public List<CustomerWrapper>        CustomerArray        = new List<CustomerWrapper>();
        public List<ReversalReceiptWrapper> ReversalReceiptArray = new List<ReversalReceiptWrapper>();
        public List<ChargeWrapper>          ChargesArray         = new List<ChargeWrapper>();
    }

    // ──────────────────────────────────────────────────────────────────
    /**
     * CustomerArray element — carries Account / transferee identity
     * details for the new owner.  Maps to Account__c fields queried
     * via the Service Request's Account__r relationship.
     */
    public class CustomerWrapper {
        // ── Identity ─────────────────────────────────────────────────
        public String  Sfid;                    // Account__c Id
        public String  CustomerType;            // "ORGANIZATION" | "INDIVIDUAL"
        public String  OrganizationName;
        public String  VatRegistrationNumber;
        public String  TradeName;
        public String  UnifiedNumber;
        // ── Person fields ─────────────────────────────────────────────
        public String  Title;
        public String  FirstName;
        public String  MiddleName;
        public String  LastName;
        public String  Gender;
        public String  DateOfBirth;             // "YYYY-MM-DD"
        public String  MartialStatus;
        // ── ID documents ─────────────────────────────────────────────
        public String  PassportNumber;
        public String  PassportExpiryDate;      // "YYYY-MM-DD"
        public String  PassportPlaceOfIssue;
        public String  EmiratesId;
        public String  EmiratesIdExpDate;       // "YYYY-MM-DD"
        public String  IssueDate;               // document issue date "YYYY-MM-DD"
        public String  ExpiryDate;              // document expiry date "YYYY-MM-DD"
        public String  Nationality;
        public String  IsUaeCustomer;           // "Y" | "N"
        // ── Contact ───────────────────────────────────────────────────
        public String  EmailAddress;
        public String  phoneType;               // "MOBILE" | "LANDLINE"
        public String  phoneCountryCode;
        public String  phoneAreaCode;
        public String  PhoneNumber;
        // ── Address ───────────────────────────────────────────────────
        public String  Unit;
        public String  UnitName;
        public String  placeOfRegistration;
        public String  Address1;
        public String  Address2;                // second address line
        public String  City;
        public String  State;
        public String  Province;
        public String  Country;
        // ── Extra ─────────────────────────────────────────────────────
        public String  ExtraInfo1;
        public String  ExtraInfo2;
        public String  ExtraInfo3;
        public String  ExtraInfo4;
        public String  ExtraInfo5;
    }

    // ──────────────────────────────────────────────────────────────────
    /**
     * ReversalReceiptArray element — receipt records whose Oracle
     * receipts are to be reversed as part of the property transfer.
     */
    public class ReversalReceiptWrapper {
        public String receiptSFID;
        public String receiptID;            // Oracle receipt id (OraclePartyId__c)
        public String reversalComments;
        public String ExtraInfo1;
        public String ExtraInfo2;
        public String ExtraInfo3;
    }

    // ──────────────────────────────────────────────────────────────────
    /**
     * ChargesArray element — one element per Invoice__c supplied via
     * invoiceIds.  CustomerPartyId and the Oracle site ID fields are
     * sent as String; they may be blank on a first-time sync.
     */
    public class ChargeWrapper {
        public String  Sfid;
        public String  SoSfid;
        public String  SoIsfid;
        public String  CustomerSfid;
        public String  CustomerPartyId;         // blank-safe String
        public String  CustomerAcct;
        public String  EscrowAccountNumber;
        public String  EscrowIbanNumber;
        public String  EscrowStoreId;
        public String  EscrowSwiftCode;
        public String  EscrowTradeId;
        public String  EscrowBankName;
        public String  EscrowBenificaryName;
        public String  Unit;
        public String  UnitName;
        public String  UnitSfId;
        public String  SoIsfReference;
        public Decimal Amount;
        public String  InvoiceDate;             // "YYYY-MM-DD"
        public String  InstallmentNumber;
        public String  Description;
        public String  SoReference;
        public String  VirtualAccountNumber;
        public String  VirtualIbanNumber;
        public String  Status;                  // "OPEN"
        public String  ExtraInfo1;
        public String  ExtraInfo2;
        public String  ExtraInfo3;
        public String  ExtraInfo4;
        public String  ExtraInfo5;
        public String  OrgIdentifier;
        public String  ProjectName;
        public String  GlDate;                 // "YYYY-MM-DD"
        public String  ProjectPhase;
        public String  TrxnType;
        public String  CustAcctId;             // blank-safe String
        public String  OraclePartySiteID;
        public String  OracleCustAcctSiteID;
        public String  OracleSiteUseID;
    }

    // ══════════════════════════════════════════════════════════════════
    // ── RESPONSE WRAPPERS ────────────────────────────────────────────
    // ══════════════════════════════════════════════════════════════════

    /** Root response envelope */
    public class SRTransferResponseList {
        public List<SRTransferResponse> ResponseArray;
    }

    /** One SR response element */
    public class SRTransferResponse {
        public String                               sfSrId;
        public String                               sfSoId;
        public String                               status;    // "S" | "E"
        public String                               errMsg;
        public List<CustomerResponseWrapper>        responseCustomerArray;
        public List<ReversalReceiptResponseWrapper> ReversalReceiptArray;
        public List<ChargeResponseWrapper>          ChargesArray;
    }

    /**
     * responseCustomerArray element.
     * Oracle site IDs are written back to SalesOrder__c.
     * OraclePartyId is written back to Account__c.
     */
    public class CustomerResponseWrapper {
        public String  Sfid;                    // Account__c Sfid sent in request
        public Decimal CustAcctId;
        public Decimal OraclePartySiteID;
        public Decimal OracleCustAcctSiteID;
        public Decimal OracleSiteUseID;
        public String  OraclePartyId;           // new Oracle party id for Account__c
        public String  status;
        public String  errMsg;
    }
	/**
     * ReversalReceiptArray response element.
     * Oracle site IDs are written back to receipt.
     * OraclePartyId is written back to receipt.
     */
    public class ReversalReceiptResponseWrapper {
        public String Sfid;
        public String oracleID;
        public String status;
        public String errMsg;
    }
    /**
     * ChargesArray response element — OracleID written back to Invoice__c.
     */
    public class ChargeResponseWrapper {
        public String Sfid;
        public String oracleID;
        public String status;
        public String errMsg;
    }

    // ══════════════════════════════════════════════════════════════════
    // ── CALLOUT RESULT  (zero DML inside the service) ────────────────
    // ══════════════════════════════════════════════════════════════════

    public class SRCalloutResult {
        /** SR-level outcome — "S" success, "E" error */
        public String           srStatus;
        public String           srErrorMessage;

        /**
         * Staged SalesOrder__c — Oracle site IDs populated from
         * responseCustomerArray on success.
         */
        public SalesOrder__c    salesOrderRecord;

        /**
         * Staged Account__c — OraclePartyId__c populated from
         * responseCustomerArray on success.
         */
        public Account          accountRecord;

        /**
         * Staged Invoice__c records — all invoices supplied via
         * invoiceIds, updated from ChargesArray response.
         */
        public List<Invoice__c> invoiceRecords = new List<Invoice__c>();
        public List<Receipt__c> receiptRecords = new List<Receipt__c>();

        /** Staged log records — no LoggerService.save() inside the service */
        public SObject          apiLog;
        public SObject          errorLog;

        /** True when the top-level catch fires */
        public Boolean          hasError = false;
    }
}