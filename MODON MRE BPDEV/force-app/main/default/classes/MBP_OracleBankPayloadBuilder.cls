/**********************************************************************************************************************
* Name               : MBP_OracleBankPayloadBuilder
* Description        : This class is responsible for constructing and serializing
*                      Bank Account JSON payload for Oracle Integration (OIC)
*                      using Salesforce Account and related document data.
* Usage              : Invoked by integration service classes to prepare
*                      Bank details payload before sending callout to Oracle.
* Created By         : Upendra Reddy
* --------------------------------------------------------------------------------------------------------------------
* Version     Author                          Date             Comment
* 1.0         upendra.asam@activemindsit.com   11 Feb 2026      Initial Draft – Implemented Bank payload construction
*                                                              including vendor mapping, bank details,
*                                                              currency mapping, supplier reference IDs,
*                                                              and JSON serialization.

**********************************************************************************************************************/


public with sharing class MBP_OracleBankPayloadBuilder {
    
    public static String buildBankJson(Account acc) {
        
        Map<String, Object> bank = new Map<String, Object>();
        
        bank.put('VendorName', acc.Name);
        
        bank.put('BankName', acc.Bank_Name__c);
        bank.put('BankBranchName', acc.Bank_Branch_Name__c);
        bank.put('BankBranchType', acc.Bank_Branch_Type__c);
        bank.put('AccountNumber', acc.Bank_Account_Number__c);
        bank.put('AccountCurrencyCode', acc.CurrencyIsoCode);
         bank.put('BankPartyId', acc.OIC_BANK_PARTY_ID__c);
        bank.put('AccountCountryCode', 'AE');
        bank.put('AccountCountryName', acc.BillingCountry);
        bank.put('beneficiaryName', acc.Beneficiary_Name__c);
        bank.put('IBAN', acc.IBAN_Number__c);
        bank.put('SwiftCode', acc.Swift_Code__c);
              bank.put('supplierSite', acc.BillingCity);
        
        bank.put('AllowInternationalPayments', 'Y');
        bank.put(
            'AccountStartDate',
            acc.CreatedDate.format('dd-MM-yyyy')
        );
        
        
        bank.put('AccountEndDate', null);
        
        bank.put('SFDCSupplierID', acc.Id);
        bank.put('FusionVendorID', acc.OIC_Supplier_Vendor_ID__c);
        
        bank.put(
            'BankDocumentAttachment',
            fetchBankDocumentBase64(acc.Id)
        );
        
        return JSON.serialize(new List<Object>{ bank });
    }
    
    private static String fetchBankDocumentBase64(Id accountId) {
        
        List<Documents__c> docList = [
            SELECT Id
            FROM Documents__c
            WHERE Account__c = :accountId
            AND Name = 'IBANLetter'
            LIMIT 1
        ];
        
        if (docList.isEmpty()) {
            System.debug('⚠️ No IBANLetter document found for Account');
            return null;
        }
        
        Id documentRecordId = docList[0].Id;
        
        List<ContentDocumentLink> cdlList = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :documentRecordId
            ORDER BY ContentDocument.CreatedDate DESC
            LIMIT 1
        ];
        
        if (cdlList.isEmpty()) {
            System.debug('⚠️ No file attached to IBANLetter document');
            return null;
        }
        
        ContentVersion cv = [
            SELECT VersionData
            FROM ContentVersion
            WHERE ContentDocumentId = :cdlList[0].ContentDocumentId
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        
        return EncodingUtil.base64Encode(cv.VersionData);
    }
    
}