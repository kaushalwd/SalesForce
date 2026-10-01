/**
* @description Request wrapper for the Advance Tax Invoice ("ADV_TAX") Oracle Fusion callout.
*               Field set mirrors OIC_RequestWrapperController.InstallmentWrapper (same
*               Sfid/Sales Order/Escrow/Virtual Account/Oracle-id fields sent for a regular
*               installment invoice) plus the Allocation/Receipt-sourced fields that are
*               specific to an Advance Tax Invoice (ReceiptSFID, AllocAmount, UnAllocAmount,
*               FusionReceiptID, AdvInstallmentNumber, ProjectNumber, PlotNumber).
*
* @author      Karunakar Pulkam
* @created     08-25-2026
* ------------------------------------------------------------------------------------
* Version  Author      			Date          Comment
* 1.0      Karunakar Pulkam    08-25-2026    Initial Draft
************************************************************************************/
public class AdvanceTaxInvoiceWrapper {

    public class RequestWrapper {
        public string Sfid;
        public string SoSfid;
        public string SoIsfid;
        public string SoIsfReference;
        public string SoReference;
        public string CustomerSfid;
        public string CustomerPartyId;
        public string CustomerAcct;
        public string EscrowAccountNumber;
        public string EscrowIbanNumber;
        public string EscrowStoreId;
        public string EscrowSwiftCode;
        public string EscrowTradeId;
        public string EscrowBankName;
        public string EscrowBenificaryName;
        public string Unit;
        public string UnitName;
        public string UnitSfId;
        public String OrgIdentifier;
        public string ProjectName;
        public string ProjectPhase;
        public string ProjectNumber;
        public string EntityName;
        public string VirtualAccountNumber;
        public string VirtualIbanNumber;
        public string VirtualAccountName;
        public string Amount;
        public Date InvoiceDate;
        public Date GlDate;
        public string InstallmentNumber;
        public string AdvInstallmentNumber;
        public string Description;
        public string Status;
        public string ExtraInfo1;
        public string ExtraInfo2;
        public string ExtraInfo3;
        public string ExtraInfo4;
        public string ExtraInfo5;
        public string CustAcctId;
        public string OraclePartySiteID;
        public string OracleCustAcctSiteID;
        public string OracleSiteUseID;
        public string TrxnType;
        public string CreditMemoFlag;
        public string ServiceTransType;
        public string ParentInvoicesfId;
        public string ParentInvoiceOracleId;
        public string CreditMemoApplyInvoiceId;
        public string RefundOracleId;
        public string ReceiptSFID;
        public string AllocAmount;
        public string UnAllocAmount;
        public string FusionReceiptID;
        public string PlotNumber;
    }

    public class RequestWrapperList {
        public List<RequestWrapper> RequestArray;
    }
}