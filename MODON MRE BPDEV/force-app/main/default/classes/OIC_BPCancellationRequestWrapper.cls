/**********************************************************************************************************************
* Name               : OIC_BPCancellationRequestWrapper
* Description        : Request payload wrapper for the Business_Process__c cancellation callout sent to Oracle
*                      Fusion via OIC (ModonFusionUpdateInvoiceAPI). Mirrors the agreed Cancellation JSON
*                      contract: one RequestArray entry per cancellation, carrying the SR/BP header, the customer
*                      bank/refund-memo details, the linked documents and the Installment / Receipt / Charges /
*                      Refund line arrays.
*                      Built and serialized by OIC_SingleCancellationCalloutService. Intentionally standalone —
*                      it does NOT reuse OIC_RequestWrapperController so this contract can evolve with the BP
*                      cancellation flow without touching the SR-flow wrappers.
*
* Created By         : Karunakar Pulkam
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           Karunakar Pulkam            22 Sep 2026         Initial draft — BP cancellation single-callout contract
***********************************************************************************************************************/
public class OIC_BPCancellationRequestWrapper {

    public List<CancellationRequest> RequestArray;

    public OIC_BPCancellationRequestWrapper() {
        this.RequestArray = new List<CancellationRequest>();
    }

    // =================================================================================================
    // HEADER — one entry per cancelled Business Process / Sales Order
    // =================================================================================================
    public class CancellationRequest {
        public String sfSrID;            // Business_Process__c.Id (SR replacement for the BP flow)
        public String sfSoId;            // SalesOrder__c.Id
        public String EntityName;        // Unit -> Phase -> EntityName__c
        public String ProjectName;
        public String sfSrRefundType;    // Business_Process__c.Cancellation_Type__c
        public String bicCode;           // Customer bank SWIFT/BIC
        public String payeeName;         // Beneficiary on the refund
        public String srType;            // Always 'Cancellation'
        public String srSubType;
        public String srNumber;          // Business_Process__c.Name
        public String srStatus;          // Business_Process__c.Status__c
        public String sfSoCustId;        // SalesOrder__c.CustomerAccount__c

        public String ExtraInfo1;
        public String ExtraInfo2;
        public String ExtraInfo3;

        // Refund-memo bank block (see NOTE in the class header on the duplicated casing)
        public String BankAccountNumber;
        public String BankBranchName;
        public String BankName;
        public String IBANNumber;
        public String SwiftCode;

        public List<DocumentLink>    DocumentsLink;
        public List<InstallmentNode> InstallmentArray;
        public List<ReceiptNode>     ReceiptArray;
        public List<ChargeNode>      ChargesArray;
        public List<RefundNode>      refundArray;

        // Arrays are always initialized — OIC rejects a payload where a node is absent rather than empty
        public CancellationRequest() {
            this.DocumentsLink    = new List<DocumentLink>();
            this.InstallmentArray = new List<InstallmentNode>();
            this.ReceiptArray     = new List<ReceiptNode>();
            this.ChargesArray     = new List<ChargeNode>();
            this.refundArray      = new List<RefundNode>();
        }
    }

    // =================================================================================================
    // DOCUMENTS
    // =================================================================================================
    public class DocumentLink {
        public String DocumentName;
        public String URLLink;
    }

    // =================================================================================================
    // INSTALLMENTS
    // =================================================================================================
    public class InstallmentNode {
        public String instSFID;          // SalesOrderInstallments__c.Id
        public String installmentNo;
        public String oracleID;          // Oracle transaction id of the invoice raised for this installment
        public String TxnType;

        public String ExtraInfo1;
        public String ExtraInfo2;
        public String ExtraInfo3;
    }

    // =================================================================================================
    // RECEIPTS
    // =================================================================================================
    public class ReceiptNode {
        public String receiptSFID;       // Receipt__c.Id
        public String receiptID;         // Receipt__c.OraclePartyId__c

        public String ExtraInfo1;
        public String ExtraInfo2;
        public String ExtraInfo3;
    }

    // =================================================================================================
    // CHARGES — cancelled invoices (credit memo / forfeiture / admin charge lines)
    // =================================================================================================
    public class ChargeNode {
        public String  Sfid;
        public String  SoSfid;
        public String  SoIsfid;
        public String  CustomerSfid;
        public String  CustomerPartyId;
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
        public Date    InvoiceDate;
        public String  InstallmentNumber;
        public String  Description;
        public String  SoReference;
        public String  VirtualAccountNumber;
        public String  VirtualIbanNumber;
        public String  Status;

        public String  ExtraInfo1;
        public String  ExtraInfo2;
        public String  ExtraInfo3;
        public String  ExtraInfo4;
        public String  ExtraInfo5;

        public String  OrgIdentifier;
        public String  ProjectName;
        public Date    GlDate;
        public String  ProjectPhase;
        public String  TrxnType;
        public String  CustAcctId;
        public String  OraclePartySiteID;
        public String  OracleCustAcctSiteID;
        public String  OracleSiteUseID;
        public String  CreditMemoFlag;
        public String  CreditMemoApplyInvoiceId;
    }

    // =================================================================================================
    // REFUNDS — same line shape as ChargeNode plus the receipt allocations funding the refund.
    // Declared as its own class rather than extending ChargeNode so the serialized field order and the
    // exact contract stay explicit and independent of Apex inheritance behaviour in JSON.serialize.
    // =================================================================================================
    public class RefundNode {
        public String  Sfid;
        public String  SoSfid;
        public String  SoIsfid;
        public String  CustomerSfid;
        public String  CustomerPartyId;
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
        public Date    InvoiceDate;
        public String  InstallmentNumber;
        public String  Description;
        public String  SoReference;
        public String  VirtualAccountNumber;
        public String  VirtualIbanNumber;
        public String  Status;

        public String  ExtraInfo1;
        public String  ExtraInfo2;
        public String  ExtraInfo3;
        public String  ExtraInfo4;
        public String  ExtraInfo5;

        public String  OrgIdentifier;
        public String  ProjectName;
        public Date    GlDate;
        public String  ProjectPhase;
        public String  TrxnType;
        public String  CustAcctId;
        public String  OraclePartySiteID;
        public String  OracleCustAcctSiteID;
        public String  OracleSiteUseID;
        public String  CreditMemoFlag;
        public String  CreditMemoApplyInvoiceId;

        public List<AllocationNode> Allocations;

        public RefundNode() {
            this.Allocations = new List<AllocationNode>();
        }
    }

    // =================================================================================================
    // ALLOCATIONS — receipts applied against the refunded invoice
    // =================================================================================================
    public class AllocationNode {
        public String  receiptSFID;      // Receipt__c.Id
        public String  receiptFusionID;  // Receipt__c.OraclePartyId__c
        public Decimal amountAlloc;      // Allocation__c.AllocationAmount__c
    }

    // =================================================================================================
    // ENVELOPE — ModonFusionUpdateInvoiceAPI expects the Base64 payload under "Base64Request"
    // (NOT "Base64RequestPayload", which the installment/receipt/allocation endpoints use).
    // =================================================================================================
    public class Base64RequestWrapper {
        public String Base64Request;
    }
}