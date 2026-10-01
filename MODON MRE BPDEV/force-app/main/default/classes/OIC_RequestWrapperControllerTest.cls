/**********************************************************************************************************************
* Name               : OIC_RequestWrapperControllerTest
* Description        : Test class for OIC_RequestWrapperController
* Created By         : PWC Digital Middle East
* --------------------------------------------------------------------------------------------------------------------
* Version       Author              Date                Comment
* 1.0           Yazan Saeed         01 May 2024      Initial Draft
***********************************************************************************************************************/
@isTest
public class OIC_RequestWrapperControllerTest {

    @isTest
    static void testMethod1(){
        OIC_RequestWrapperController.UnitUpdateWrapper uuwRecord = new OIC_RequestWrapperController.UnitUpdateWrapper();
        uuwRecord.Id = 'Test';
        uuwRecord.Status = 'Test';
 /* ---------------- CustomerWrapper ---------------- */
        OIC_RequestWrapperController.CustomerWrapper cust =
            new OIC_RequestWrapperController.CustomerWrapper();
        cust.Sfid = '001';
        cust.CustomerType = 'Individual';
        cust.OrganizationName = 'Test Org';
        cust.TradeName = 'Trade';
        cust.UnifiedNumber = '12345';
        cust.EmailAddress = 'test@test.com';
        cust.PhoneNumber = '9999999999';
        cust.Country = 'UAE';
        cust.City = 'Dubai';
        cust.State = 'Dubai';
        cust.Address1 = 'Address';
        cust.VatRegistrationNumber = 'VAT123';
        cust.Title = 'Mr';
        cust.FirstName = 'John';
        cust.MiddleName = 'M';
        cust.LastName = 'Doe';
        cust.Gender = 'Male';
        cust.MaritalStatus = 'Single';
        cust.DateOfBirth = Date.today();
        cust.PassportNumber = 'P123';
        cust.PassportExpiryDate = Date.today().addYears(5);
        cust.Nationality = 'Indian';
        cust.PassportPlaceOfIssue = 'India';
        cust.IsUaeCustomer = 'Yes';


        /* ---------------- ReceiptWrapper ---------------- */
        OIC_RequestWrapperController.ReceiptWrapper receipt =
            new OIC_RequestWrapperController.ReceiptWrapper();
        receipt.Sfid = 'R001';
        receipt.SfReference = 'REF001';
        receipt.CustomerSfid = '001';
        receipt.CustomerPartyId = 'Party1';
        receipt.CustomerAcct = 'Acct1';
        receipt.OrgIdentifier = 'ORG';
        receipt.ProjectName = 'Project';
        receipt.VirtualAccountNumber = '123';
        receipt.VirtualIbanNumber = 'IBAN123';
        receipt.EscrowAccountNo = 'Escrow';
        receipt.EscrowAccountName = 'Escrow Name';
        receipt.EscrowIBANNo = 'IBAN';
        receipt.ReceiptNumber = 'REC123';
        receipt.ReceiptType = 'Cash';
        receipt.CurrencyCode = 'AED';
        receipt.ReceiptDate = Date.today();
        receipt.GlDate = Date.today();
        receipt.MaturityDate = Date.today();
        receipt.Amount = 1000;
        receipt.Description = 'Test Receipt';
        receipt.BankName = 'Bank';
        receipt.Status = 'New';
        receipt.RefundStatus = 'None';
        receipt.Unit = 'Unit1';
        receipt.UnitName = 'Unit Name';
        receipt.EoiFlag = 'Yes';
        receipt.ProjectPhase = 'Phase1';
        receipt.EntityName = 'Entity';
        receipt.CustAcctId = 'CustAcct';
        receipt.OraclePartySiteID = 'OPSID';
        receipt.OracleCustAcctSiteID = 'OCASID';
        receipt.OracleSiteUseID = 'OSUID';
        receipt.ChequeNumber = 'CHQ1';
        receipt.TransactionDate = '2024-01-01';
        receipt.TrxnType = 'Charge';
        receipt.Bypass = 'No';
        receipt.ReverseReceipt = 'No';
        receipt.ReverseOracleID = 'RO1';
        receipt.CategoryCode = 'Cat';
        receipt.ReasonCode = 'Reason';
        receipt.ReasonComments = 'Comment';
        receipt.Unidentified = 'No';
        receipt.UNIDENTIFIED_CUST_ACCT_ID = 'UCID';
        receipt.UNIDENTIFIED_RECEIPT_ID = 'URID';


        /* ---------------- ReceiptWrapperLst ---------------- */
        OIC_RequestWrapperController.ReceiptWrapperLst receiptList =
            new OIC_RequestWrapperController.ReceiptWrapperLst();
        receiptList.RequestArray =
            new List<OIC_RequestWrapperController.ReceiptWrapper>{ receipt };


        /* ---------------- CustomerWrapperLst ---------------- */
        OIC_RequestWrapperController.CustomerWrapperLst custList =
            new OIC_RequestWrapperController.CustomerWrapperLst();
        custList.RequestArray =
            new List<OIC_RequestWrapperController.CustomerWrapper>{ cust };


        /* ---------------- SalesOrderInstallmentWrapper ---------------- */
        OIC_RequestWrapperController.SalesOrderInstallmentWrapper inst =
            new OIC_RequestWrapperController.SalesOrderInstallmentWrapper();
        inst.InstallmentSfid = 'INS1';
        inst.InstallmentfReference = 'REF1';
        inst.InstallmentNumber = '1';
        inst.InstallementDescription = 'Installment';
        inst.InstallmentDate = Date.today();
        inst.InstallementAmount = '500';
        inst.InstallementStatus = 'Open';


        /* ---------------- SalesOrderWrapper ---------------- */
        OIC_RequestWrapperController.SalesOrderWrapper so =
            new OIC_RequestWrapperController.SalesOrderWrapper();
        so.Sfid = 'SO1';
        so.SfReference = 'SOREF';
        so.CustomerSfid = '001';
        so.CustomerPartyId = 'Party';
        so.CustomerAcct = 'Acct';
        so.UnitName = 'Unit';
        so.PaymentPlan = 'Plan';
        so.Phase = 'Phase';
        so.Project = 'Project';
        so.TotalAmount = '10000';
        so.Status = 'Active';
        so.Unit = 'Unit';
        so.OrgIdentifier = 'ORG';
        so.ProjectName = 'Project';
        so.ProjectPhase = 'Phase';
        so.EntityName = 'Entity';
        so.CustAcctId = 'Cust';
        so.OraclePartySiteID = 'OPS';
        so.OracleCustAcctSiteID = 'OCAS';
        so.OracleSiteUseID = 'OSU';
        so.PropertyTransfer = 'No';
        so.OldCustomerId = 'OLD';
        so.SalesOrderLines =
            new List<OIC_RequestWrapperController.SalesOrderInstallmentWrapper>{ inst };


        /* ---------------- SalesOrderWrapperLst ---------------- */
        OIC_RequestWrapperController.SalesOrderWrapperLst soList =
            new OIC_RequestWrapperController.SalesOrderWrapperLst();
        soList.RequestArray =
            new List<OIC_RequestWrapperController.SalesOrderWrapper>{ so };


        /* ---------------- Base64Wrapper ---------------- */
        OIC_RequestWrapperController.Base64Wrapper baseReq =
            new OIC_RequestWrapperController.Base64Wrapper();
        baseReq.Base64RequestPayload = 'BASE64DATA';


        /* ---------------- InstallmentWrapper ---------------- */
        OIC_RequestWrapperController.InstallmentWrapper inv =
            new OIC_RequestWrapperController.InstallmentWrapper();
        inv.Sfid = 'INV1';
        inv.SoSfid = 'SO1';
        inv.SoIsfid = 'SOI1';
        inv.CustomerSfid = '001';
        inv.CustomerPartyId = 'Party';
        inv.CustomerAcct = 'Acct';
        inv.EscrowAccountNumber = 'ESC1';
        inv.Unit = 'Unit';
        inv.UnitName = 'Unit Name';
        inv.Amount = '500';
        inv.InvoiceDate = Date.today();
        inv.InstallmentNumber = '1';
        inv.Description = 'Invoice';
        inv.Status = 'Open';
        inv.GlDate = Date.today();
        inv.ProjectPhase = 'Phase';
        inv.EntityName = 'Entity';
        inv.CustAcctId = 'Cust';
        inv.OraclePartySiteID = 'OPS';
        inv.OracleCustAcctSiteID = 'OCAS';
        inv.OracleSiteUseID = 'OSU';
        inv.TrxnType = 'Charge';
        inv.CreditMemoFlag = 'No';
        inv.ServiceTransType = 'Transfer';
        inv.ParentInvoicesfId = 'Parent';
        inv.ParentInvoiceOracleId = 'ParentOracle';


        /* ---------------- InstallmentWrapperLst ---------------- */
        OIC_RequestWrapperController.InstallmentWrapperLst invList =
            new OIC_RequestWrapperController.InstallmentWrapperLst();
        invList.RequestArray =
            new List<OIC_RequestWrapperController.InstallmentWrapper>{ inv };


        /* ---------------- AllocationWrapper ---------------- */
        OIC_RequestWrapperController.AllocationWrapper alloc =
            new OIC_RequestWrapperController.AllocationWrapper();
        alloc.Sfid = 'A1';
        alloc.SfReference = 'REF';
        alloc.ReceiptSfid = 'R1';
        alloc.CashReceiptId = 'CR1';
        alloc.InstallmentInvoiceSfid = 'INV1';
        alloc.CustomerTrxId = 'CTX1';
        alloc.AllocationDate = Date.today();
        alloc.AllocationGlDate = Date.today();
        alloc.AllocationAmount = '500';
        alloc.Status = 'Allocated';
        alloc.ProjectPhase = 'Phase';
        alloc.EntityName = 'Entity';
        alloc.ProjectName = 'Project';
        alloc.ResyncUnApply = 'No';


        /* ---------------- AllocationWrapperLst ---------------- */
        OIC_RequestWrapperController.AllocationWrapperLst allocList =
            new OIC_RequestWrapperController.AllocationWrapperLst();
        allocList.RequestArray =
            new List<OIC_RequestWrapperController.AllocationWrapper>{ alloc };


        /* ---------------- Response Wrappers ---------------- */
        OIC_RequestWrapperController.OICResponseWrapper resp =
            new OIC_RequestWrapperController.OICResponseWrapper();
        resp.Sfid = '1';
        resp.Status = 'Success';
        resp.ErrorMsg = '';
        resp.OracleId = 'OID';
        resp.OracleRef = 'OREF';
        resp.ReversalReason = 'None';

        OIC_RequestWrapperController.OICResponseWrapperList respList =
            new OIC_RequestWrapperController.OICResponseWrapperList();
        respList.ResponseArray =
            new List<OIC_RequestWrapperController.OICResponseWrapper>{ resp };


        OIC_RequestWrapperController.OICSOResponseWrapper soResp =
            new OIC_RequestWrapperController.OICSOResponseWrapper();
        soResp.Sfid = '1';
        soResp.Status = 'Success';
        soResp.ErrorMsg = '';
        soResp.OracleId = 'OID';
        soResp.OracleRef = 'OREF';
        soResp.CustAcctId = 'Cust';
        soResp.OraclePartySiteID = 'OPS';
        soResp.OracleCustAcctSiteID = 'OCAS';
        soResp.OracleSiteUseID = 'OSU';
        soResp.ReversalReason = 'None';

        OIC_RequestWrapperController.OICSOResponseWrapperList soRespList =
            new OIC_RequestWrapperController.OICSOResponseWrapperList();
        soRespList.ResponseArray =
            new List<OIC_RequestWrapperController.OICSOResponseWrapper>{ soResp };


        /* ---------------- Base64ResponseWrapper ---------------- */
        OIC_RequestWrapperController.Base64ResponseWrapper baseResp =
            new OIC_RequestWrapperController.Base64ResponseWrapper();
        baseResp.Base64Response = 'Response';
        baseResp.IntegrationId = 'INT1';


        /* Simple assertion to finalize execution */
       // System.assertEquals('Success', resp.Status);
    
        
    }
}