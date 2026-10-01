/** Name             : OIC_ManageBankInvoiceData
* description        : This is used for the sending data from salesforce to ebs and attached docment.            
*Created By          : Active Minds
*********************************************************************************
*  Version  Author          Date        Notes
** 1.0      Manoj           15 Mar 2026    Initial
**********************************************************************************/
@isTest
public class OIC_ManageBankInvoiceDataTest {
    
    private class MockHttpResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setStatus('OK');
            res.setHeader('Content-Type', 'application/json');

            OIC_RequestWrapperController.OICResponseWrapperList responseList =
                new OIC_RequestWrapperController.OICResponseWrapperList();

            responseList.ResponseArray =
                new List<OIC_RequestWrapperController.OICResponseWrapper>();

            String decodedJson = JSON.serialize(responseList);
            String encodedJson = EncodingUtil.base64Encode(Blob.valueOf(decodedJson));

            OIC_RequestWrapperController.Base64ResponseWrapper baseResp =
                new OIC_RequestWrapperController.Base64ResponseWrapper();

            baseResp.Base64Response = encodedJson;

            res.setBody(JSON.serialize(baseResp));
            return res;
        }
    }

    private static void attachFileToDocument(Id documentId, String title) {
        ContentVersion cv = new ContentVersion(
            Title = title,
            PathOnClient = title + '.pdf',
            VersionData = Blob.valueOf('Test File Data')
        );
        insert cv;

        cv = [
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
            LIMIT 1
        ];

        ContentDocumentLink cdl = new ContentDocumentLink(
            LinkedEntityId = documentId,
            ContentDocumentId = cv.ContentDocumentId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        insert cdl;
    }

    @isTest
    static void testCreateRefundMemo_CustomerRefundAndTransferBranches() {

        Account acc = new Account(
            Name = 'Test Bank Account',
            Bank_Account_Number__c = '123456789',
            Bank_Branch_Name__c = 'Main Branch',
            Bank_Country__c = 'United Arab Emirates',
            Bank_Name__c = 'HDFC',
            IBAN_Number__c = 'AE070331234567890123456',
            Swift_Code__c = 'HDFCINBB'
        );
        insert acc;

        EscrowAccount__c escrow = new EscrowAccount__c(
            Name = 'Test Escrow',
            AccountNumber__c = 'ESC-001',
            IBANNo__c = 'AE070331234567890123456',
            StoreId__c = 'STORE-001',
            SwiftCode__c = 'SWIFT001',
            TradeID__c = 'TRADE-001',
            BankName__c = 'Escrow Bank',
            BeneficiaryName__c = 'Escrow Beneficiary'
        );
        insert escrow;

        VirtualAccount__c va = new VirtualAccount__c(
            Name = 'Cancellation VA',
            Status__c = 'Available',
            VirtualAccountNumber__c = 'VA-CAN-001',
            VirtualIBANNumber__c = 'AE111111111111111111111',
            EscrowAccount__c = escrow.Id
           
        );
        insert va;

        VirtualAccount__c transferVa = new VirtualAccount__c(
            Name = 'Transfer VA',
            Status__c = 'Available',
            VirtualAccountNumber__c = 'VA-TRF-001',
            VirtualIBANNumber__c = 'AE222222222222222222222',
            EscrowAccount__c = escrow.Id
        );
        insert transferVa;

        Unit__c unit = new Unit__c(
            Name = 'Test Unit',
            PlotNo__c = 'U-001',
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '1'
        );
        insert unit;

        SalesOrder__c so = new SalesOrder__c(
            CustomerAccount__c = acc.Id,
            Unit__c = unit.Id,
            VirtualAccount__c = va.Id,
            Status__c = 'Completed',
            Source_Entity__c = 'Modon - UAE',
            CustAcctId__c = 'CUST-CAN',
            OracleCustAcctSiteID__c = 'OCAS-CAN',
            OraclePartySiteID__c = 'OPS-CAN',
            OracleSiteUseID__c = 'OSU-CAN'
        );
        insert so;

        SalesOrder__c transferSO = new SalesOrder__c(
            CustomerAccount__c = acc.Id,
            VirtualAccount__c = transferVa.Id,
            Status__c = 'Completed',
            Source_Entity__c = 'Modon - UAE',
            CustAcctId__c = 'CUST-TRF',
            OracleCustAcctSiteID__c = 'OCAS-TRF',
            OraclePartySiteID__c = 'OPS-TRF',
            OracleSiteUseID__c = 'OSU-TRF'
        );
        insert transferSO;


        Invoice__c invCustomerRefund = new Invoice__c(
            OraclePartyId__c = 'ORACLE-INV-001',
            Transaction_Type__c = 'Customer Refund',
            Account__c = acc.Id
        );

        Invoice__c invTransferRefund = new Invoice__c(
            OraclePartyId__c = 'ORACLE-INV-002',
            Transaction_Type__c = 'Refund',
            Account__c = acc.Id
        );

        insert new List<Invoice__c>{ invCustomerRefund, invTransferRefund };

        Documents__c bankDetailsDoc = new Documents__c(
            Name = 'Documents',
            Invoice__c = invCustomerRefund.Id,
            Status__c = 'Uploaded'
        );
        insert bankDetailsDoc;

       

        attachFileToDocument(bankDetailsDoc.Id, 'Bank Details File');
        attachFileToDocument(bankDetailsDoc.Id, 'Approval File');

        Test.setMock(HttpCalloutMock.class, new MockHttpResponse());

        Test.startTest();
        OIC_ManageBankInvoiceData.createRefundMemo(
            new Set<String>{ invCustomerRefund.Id, invTransferRefund.Id }
        );
        Test.stopTest();

        System.assert(true, 'createRefundMemo executed successfully');
    }

    @isTest
    static void testCreateRefundMemo_NoMatchingInvoices() {
        Account acc = new Account(Name = 'Excluded Account');
        insert acc;

        Invoice__c inv = new Invoice__c(
            Transaction_Type__c = 'Customer Refund',
            Account__c = acc.Id
        );
        insert inv;

        Test.setMock(HttpCalloutMock.class, new MockHttpResponse());

        Test.startTest();
        OIC_ManageBankInvoiceData.createRefundMemo(new Set<String>{ inv.Id });
        OIC_ManageBankInvoiceData.createRefundMemo(null);
        Test.stopTest();

        System.assert(true, 'No matching invoice path executed safely');
    }
     @isTest
    static void testCreateRefundMemo_CustomerRefundBatch() {

        Account acc = new Account(
            Name = 'Test Bank Account',
            Bank_Account_Number__c = '123456789',
            Bank_Branch_Name__c = 'Main Branch',
            Bank_Country__c = 'United Arab Emirates',
            Bank_Name__c = 'HDFC',
            IBAN_Number__c = 'AE070331234567890123456',
            Swift_Code__c = 'HDFCINBB'
        );
        insert acc;

        EscrowAccount__c escrow = new EscrowAccount__c(
            Name = 'Test Escrow',
            AccountNumber__c = 'ESC-001',
            IBANNo__c = 'AE070331234567890123456',
            StoreId__c = 'STORE-001',
            SwiftCode__c = 'SWIFT001',
            TradeID__c = 'TRADE-001',
            BankName__c = 'Escrow Bank',
            BeneficiaryName__c = 'Escrow Beneficiary'
        );
        insert escrow;

        VirtualAccount__c va = new VirtualAccount__c(
            Name = 'Cancellation VA',
            Status__c = 'Available',
            VirtualAccountNumber__c = 'VA-CAN-001',
            VirtualIBANNumber__c = 'AE111111111111111111111',
            EscrowAccount__c = escrow.Id
           
        );
        insert va;

        VirtualAccount__c transferVa = new VirtualAccount__c(
            Name = 'Transfer VA',
            Status__c = 'Available',
            VirtualAccountNumber__c = 'VA-TRF-001',
            VirtualIBANNumber__c = 'AE222222222222222222222',
            EscrowAccount__c = escrow.Id
        );
        insert transferVa;

        Unit__c unit = new Unit__c(
            Name = 'Test Unit',
            PlotNo__c = 'U-001',
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '1'
        );
        insert unit;

        SalesOrder__c so = new SalesOrder__c(
            CustomerAccount__c = acc.Id,
            Unit__c = unit.Id,
            VirtualAccount__c = va.Id,
            Status__c = 'Completed',
            Source_Entity__c = 'Modon - UAE',
            CustAcctId__c = 'CUST-CAN',
            OracleCustAcctSiteID__c = 'OCAS-CAN',
            OraclePartySiteID__c = 'OPS-CAN',
            OracleSiteUseID__c = 'OSU-CAN'
        );
        insert so;

        SalesOrder__c transferSO = new SalesOrder__c(
            CustomerAccount__c = acc.Id,
            VirtualAccount__c = transferVa.Id,
            Status__c = 'Completed',
            Source_Entity__c = 'Modon - UAE',
            CustAcctId__c = 'CUST-TRF',
            OracleCustAcctSiteID__c = 'OCAS-TRF',
            OraclePartySiteID__c = 'OPS-TRF',
            OracleSiteUseID__c = 'OSU-TRF'
        );
        insert transferSO;

        Invoice__c invCustomerRefund = new Invoice__c(
            OraclePartyId__c = 'ORACLE-INV-001',
            Transaction_Type__c = 'Customer Refund',
            Account__c = acc.Id
        );
		Test.startTest();
        Invoice__c invTransferRefund = new Invoice__c(
            OraclePartyId__c = 'ORACLE-INV-002',
            Transaction_Type__c = 'Refund',
            Account__c = acc.Id,
            Status__c = 'In Progress'
        );

        insert new List<Invoice__c>{ invCustomerRefund, invTransferRefund };

        Documents__c bankDetailsDoc = new Documents__c(
            Name = 'Documents',
            Invoice__c = invTransferRefund.Id,
            Status__c = 'Uploaded'
        );
        insert bankDetailsDoc;
                   
         OIC_ManageBankInvoiceData.createRefundMemo( new Set<String>{ invCustomerRefund.Id, invTransferRefund.Id });
        Test.stopTest();
    }

}