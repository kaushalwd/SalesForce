@IsTest
public class MBP_OracleBankPayloadBuilderTest {
    
    @TestSetup
    static void setupData() {
        
        Account acc = new Account(
            Name = 'Test Vendor',
            Bank_Name__c = 'Emirates NBD',
            Bank_Branch_Name__c = 'Dubai Main',
            Bank_Branch_Type__c = 'SWIFT',
            Bank_Account_Number__c = '1234567890',
      
            BillingCountry = 'UAE',
            BillingStreet = 'Sheikh Zayed Road',
            BillingCity = 'Dubai',
            IBAN_Number__c = 'AE070331234567890123456',
            Swift_Code__c = 'EBILAEAD',
            OIC_BANK_PARTY_ID__c = 'BP123',
            OIC_Supplier_Vendor_ID__c = 'FV456'
        );
        insert acc;
        
        Documents__c doc = new Documents__c(
            Name = 'IBANLetter',
            Account__c = acc.Id
        );
        insert doc;
        
        ContentVersion cv = new ContentVersion(
            Title = 'IBAN Letter File',
            PathOnClient = 'IBANLetter.pdf',
            VersionData = Blob.valueOf('Dummy IBAN Letter Content'),
            IsMajorVersion = true
        );
        insert cv;
        
        cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
        
        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = cv.ContentDocumentId,
            LinkedEntityId = doc.Id,
            ShareType = 'V'
        );
        insert cdl;
    }
    
    @IsTest
    static void testBuildBankJson_WithDocument() {
        
        Account acc = [SELECT Id, Name, Bank_Name__c, Bank_Branch_Name__c,
                       Bank_Branch_Type__c, Bank_Account_Number__c,
                       CurrencyIsoCode, BillingCountry, BillingStreet,
                       BillingCity, IBAN_Number__c, Swift_Code__c,
                       OIC_BANK_PARTY_ID__c, OIC_Supplier_Vendor_ID__c,
                       CreatedDate
                       FROM Account
                       LIMIT 1];
        
        Test.startTest();
        String result = MBP_OracleBankPayloadBuilder.buildBankJson(acc);
        Test.stopTest();
        
        System.assertNotEquals(null, result);
        System.assert(result.contains('Test Vendor'));
        System.assert(result.contains('Emirates NBD'));
        System.assert(result.contains('AE070331234567890123456'));
    }
    
    
}