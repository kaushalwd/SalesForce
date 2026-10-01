/**********************************************************************************************************************
* Name               : OIC_ManageSalesforceDataController                                                        
* Description        : This class contains main integration methods for Oracle-Salesforce integration callouts.
* Usage              : Used across Triggers and Batch classes.
* Created By         : PWC Digital Middle East                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Anil Valluri   	            29 Feb 2024     Initial Draft       
* 2.0           Manoj                       10 OCT 2025     Added new fields for Multi Entity / Org wrapper
* 2.1           Kumaravel                   12 OCT 2025     Added new fields for Charges wrapper
* 3.0           Kumar 						18 Oct 2025		Update The DL data and bulkBypass
* 4.0 			Manoj						20 Jan 2026		Update ReverseReasonmapping 
* 5.0			Suresh						25 Jan 2026		Update Unidentified
* 6.0			Manoj						30 Jan 2026		Update CreditNote
* 7.0           Manoj                       20 Feb`2026     Update for the Property Transfer Service
* 8.0           Manoj                       20 Mar 2026     Update for the Service Transfer ,InstallmentWrapper 
* 9.0			Manoj						10 Apri 2026	Add the Unit and back Waper
* 10.0			Manoj						03 Apri 2026	Add the fusion process Waper
* 11.0			Manoj						12 May  2026	Add Soid from unit mapping
* 12.0			Manoj						14 May  2026    Add Virtual Account Details 
* 13.0			Manoj						24 May  2026	Add New feilds in Fusion JSON
* 14.0 			Modon IT					27 Jul 2026		Added VO for Custom Bank details
**********************************************************************************************************************/
public class OIC_RequestWrapperController {
    public class UnitUpdateWrapper{
        public String Id;
        public String Status;
    }

    public class CustomerWrapper{
        public String Sfid;
        public String CustomerType;
        public String OrganizationName;
        public String TradeName;
        public String UnifiedNumber;
        public String EmailAddress;
        public String PhoneNumber;
        public String Country;
        public String City;
        public String State;
        public String Address1;
        public String VatRegistrationNumber;

        public String Title;
        public String FirstName;
        public String MiddleName;
        public String LastName;
        public String Gender;
        public String MaritalStatus;
        public Date DateOfBirth;
        public String PassportNumber;
        public Date PassportExpiryDate;
        public String Nationality;
        public String PassportPlaceOfIssue;
        public String IsUaeCustomer;
        public Date EmiratesIdExpDate; //9.0
        public String EmiratesId; //9.0       
    }

    public class ReceiptWrapper{
        public String Sfid;
        public String SfReference;
        public String CustomerSfid;
        public String CustomerPartyId;
        public String CustomerAcct;
        public String OrgIdentifier;
        public String ProjectName;
        public string VirtualAccountNumber;
        public string VirtualIbanNumber;
        public String EscrowAccountNo;
        public String EscrowAccountName;
        public String EscrowIBANNo;
        public String ReceiptNumber;
        public String ReceiptType;
        public String CurrencyCode;
        public Date ReceiptDate;
        public Date GlDate;
        public Date MaturityDate;
        public Decimal Amount;
        public String Description;
        public String BankName;
        public String Status;
        public String RefundStatus;
        public String Unit;
        public String UnitName;
        public String EoiFlag;
        public string ExtraInfo2;
        public string ProjectPhase;
        public string EntityName;
        public string CustAcctId;
        public string OraclePartySiteID;
        public string OracleCustAcctSiteID;
        public string OracleSiteUseID;  
        public string ChequeNumber;
        public string TransactionDate;    
        public string TrxnType; // Charges OIC Intergration project
        public string Bypass; 
        public string ReverseReceipt;  // issue type start
        public string ReverseOracleID; 
        public string CategoryCode; 
        public string ReasonCode; 
        public string ReasonComments;  // issue type end
        public String Unidentified; // 5.0
        public String UNIDENTIFIED_CUST_ACCT_ID; // 5.0
        public String UNIDENTIFIED_RECEIPT_ID; // 5.0
        public string TransferType; //8.0
        public string SoSfid; //10.0
        public string SoReference; //10.0
        public string SoIsfid; //10.0
        public string SoIsfReference; //10.0        
    }
    
    public class ReceiptWrapperLst{
        public List<ReceiptWrapper> RequestArray;
    }

    public class CustomerWrapperLst{
        public List<CustomerWrapper> RequestArray;
    }

    public class SalesOrderWrapper{
        public string Sfid;
        public string SfReference;
        public string CustomerSfid;
        public string CustomerPartyId;
        public string CustomerAcct;
        public string UnitName;
        public string UnitOption;
        public string PaymentPlan;
        public string Phase;
        public string Project;
        public string TotalAmount;
        public string AdmAmount;
        public string DiscountAmount;
        public string VirtualAccountNumber;
        public string VirtualIbanNumber;
        public string SalesAssociateName;
        public string Status;
        public String Unit;
        public String OrgIdentifier;
        public string ProjectName;
        public string ExtraInfo1;
        public string ExtraInfo2;
        public string ExtraInfo3;
        public string ExtraInfo4;
        public string ExtraInfo5;
        public string ProjectPhase;
        public string EntityName;
        public string CustAcctId;
        public string OraclePartySiteID;
        public string OracleCustAcctSiteID;
        public string OracleSiteUseID; 
        //7.0 start Property Transfer Service
        public string PropertyTransfer;  
        public string OldCustomerId;
        //7.0 End Property Transfer Service
        public list<SalesOrderInstallmentWrapper> SalesOrderLines;


    }

    public class SalesOrderInstallmentWrapper{
        public string InstallmentSfid;
        public string InstallmentfReference;
        public string InstallmentNumber;
        public string InstallementDescription;
        public Date InstallmentDate;
        public string InstallementAmount;
        public string InstallementStatus;
        public string ExtraInfo1;
        public string ExtraInfo2;
        public string ExtraInfo3;
        public string ExtraInfo4;
        public string ExtraInfo5;
        public String instInvoiceNum;

    }

    public class SalesOrderWrapperLst{
        public List<SalesOrderWrapper> RequestArray;
    }

    public class Base64Wrapper{
        public String Base64RequestPayload;
        //public String Base64Request; //11.0
    }


    public class InstallmentWrapper{
        public string Sfid;
        public string SoSfid;
        public string SoIsfid;
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
        //public string SoIsfid;
        public string SoIsfReference;
        public string Amount;
        public Date InvoiceDate;        
        public string InstallmentNumber;
        public string Description;
        public string SoReference;
        public string VirtualAccountNumber;
        public string VirtualIbanNumber;
        public string Status;
        public string ExtraInfo1;
        public string ExtraInfo2;
        public string ExtraInfo3;
        public string ExtraInfo4;
        public string ExtraInfo5;
        public Date GlDate;
		public string ProjectPhase;
        public string EntityName;
        public string CustAcctId;
        public string OraclePartySiteID;
        public string OracleCustAcctSiteID;
        public string OracleSiteUseID;        
        public string TrxnType; // Kumaravel-OIC Intergration project
        public string CreditMemoFlag; // 6.0        
        public string ServiceTransType; // 8.0 Add Service Transfer
        public string ParentInvoicesfId; //8.0
        public string ParentInvoiceOracleId; //8.0
        public string CreditMemoApplyInvoiceId; //8.0
        public string RefundOracleId; //8.0
        public string VirtualAccountName; //12.0
        public String CustomerAccountNumber;
        public String CustomerIbanNumber;
        public String CustomerSwiftCode;
        public String CustomerBankName;
        public String CustomerBenificaryName;
        public String CustomerBankAcctURL;        
    }

    public class InstallmentWrapperLst{
        public List<InstallmentWrapper> RequestArray;
    }


    public class AllocationWrapper{
        public string Sfid;
        public string SfReference;
        public string ReceiptSfid;
        public string CashReceiptId;
        public string InstallmentInvoiceSfid;
        public string CustomerTrxId;
        public Date AllocationDate;
        public Date AllocationGlDate;
        public string AllocationAmount;
        public string Status;
        public string ExtraInfo1;
        public string ExtraInfo2;
        public string ExtraInfo3;
        public string ExtraInfo4;
        public string ExtraInfo5;
        public string ProjectPhase;
        public string EntityName;
        public string ProjectName;
		public string ResyncUnApply;
    }

    public class AllocationWrapperLst{
        public List<AllocationWrapper> RequestArray;
    }


    ///// Response Wrappers //////


    public class Base64ResponseWrapper{
        public String Base64Response;
        public String IntegrationId;
    }


    public class OICResponseWrapperList{
        public list<OICResponseWrapper> ResponseArray;
    }

    public class OICResponseWrapper{
        public string Sfid;
        public string Status;
        public string ErrorMsg;
        public string OracleId;
        public string OracleRef;
        public string ReversalReason; //4.0 Update ReverseReasonmapping 
        public string So_id; // 10.0 Add 
    }
    
    public class OICSOResponseWrapperList{
        public list<OICSOResponseWrapper> ResponseArray;
    }

    public class OICSOResponseWrapper{
        public string Sfid;
        public string Status;
        public string ErrorMsg;
        public string OracleId;
        public string OracleRef;        
        public string CustAcctId;
        public string OraclePartySiteID;
        public string OracleCustAcctSiteID;
        public string OracleSiteUseID;
        public string ReversalReason; //4.0 Update ReverseReasonmapping 
    }
    //9.0 Start
     public class UnitRecordWrapperList{
        public List<UnitRecord> RequestArray;
    }
    
    public class UnitRecord {
        public Integer paas_id;
        public String  record_id;
        public String  bu_name;
        public Decimal pass_id;
        public String  project_number ;
        public String  project_name   ;        
        public String phase_name;
        public String project_gdv;
        public Decimal total_area;
        public String  building_id    ;
        public String  building_name  ;
        public String  building_number;
        public String  unit_id  ;
        public String  unit_type;
        public String  unit_number ;
        public String  unit_name;
        public String  unit_category  ;
        public String  unit_status    ;
        public Date unit_sold_Date;
        public Date  unit_launch_date;
        public Date  unit_end_date  ;
        public String  unit_description ;
        public Decimal sqmt;
        public Date  updated_date_of_unit ;
        public String  sold_status    ;
        public Decimal gross_sale_price ;
        public Decimal net_sale_price ;
        public Decimal minimum_selling_price;
        public Decimal realised_collections ;
        public Decimal spa_amount;
        public String  over_all_status;
        public String  dp_status;
        public String  spa_signed_status;
        public String  customer_code  ;
        public String  customer_name  ;
        public String  oqood_status   ;
        public String  spa_status     ;
        public Date spa_date;
        public String approval_or_inventory_status;
        public Decimal total_invocie_amount;
        public Decimal received;
        public Decimal external_sales_commission;
        public Decimal internal_sales_commission;
        public Decimal sales_commission;
        public Decimal discount_cash;
        public Decimal discount_adm_or_adgm;   
        public String  so_id; //13.0
        public String so_number; //13.0
        public String so_name; //13.0
        public Decimal plot_area; //13.0
        public String unit_classification; //13.0
        public Decimal gfa; //13.0
        public Decimal gsa; //13.0
        public String no_of_bedrooms;
        public Date project_launch_date;


    }
    
    public class BankDataWrapperLst{
        public List<BankData> RequestArray;
    }
        public class BankData {
            public String SfReference;
            public String Invoice_pdf;
            public String Invoice_Id;
            public String Oracle_receipt_id;
            public String UnitName;
            public String Unit;
            public String Sfid;
            public String BankAccountNumber;
            public String BankBranchName;
            public String BankName;
            public String IBANNumber;
            public String SwiftCode;
            public String CancellationVirtualAccountNumber;
            public String CancellationVirtualAccountName;
            public String CancellationVirtualIBANNumber;
            public String CancellationSwiftCode;
            public String CancellationVirtualBankName;
            public String TransferVirtualAccountNumber;
            public String TransferVirtualAccountName;
            public String TransferVirtualIBANNumber;
            public String TransferSwiftCode;
            public String TransferVirtualBankName;
            public String TransferCustAcctId;
            public String TransferCustAcctSiteID;
            public String TransferPartySiteID;
            public String TransferSiteUseID;
            public String TransferSalesOrder;
            public String CancellationCustAcctId;
            public String CancellationCustAcctSiteID;
            public String CancellationPartySiteID;
            public String CancellationSiteUseID;
            public String CancellationSalesOrder;
            
      }
    
    public class RevenueRecognitionMaster  {
            public Decimal paas_id;
            public String bu_name;
            public Date period;
            public String project_name;
            public String sf_project_number;
            public String building_id;
            public String unit_id;
            public Decimal total_spa_value;
            public Decimal total_invocie_amount;
            public Decimal received;
            public String so_id; // 10.0 Add 
            public String so_number; // 10.0 Add 
            public String so_name;   // 10.0 Add 
        }
    
    public class RevenueRecognitionMasterWrapperList{
        public List<RevenueRecognitionMaster> RequestArray;
    }
    // start 10.0 Add 
    public class ProjectMaster  {
           // public String value;
            public String Description;  
        	public string Sfid;
    }
    
    public class ProjectMasterList{
        public List<ProjectMaster> RequestArray;
    } //End 10.0
	 //9.0 End
}