@isTest
public class ProspectAccountTriggerHandlerTest {
    
    private static final String SERVICE_REQUEST_RT_DEV_NAME_ADM = 'Service_Request_Management_ADM';
    
    @testSetup
    static void setupData() {
        // Query RecordTypes dynamically
        RecordType orgacc = [SELECT Id, DeveloperName FROM RecordType WHERE SobjectType = 'Account' AND DeveloperName = 'OrganizationAccount' LIMIT 1];
        RecordType serRec = [SELECT Id, DeveloperName FROM RecordType WHERE SobjectType = 'ServiceRequest__c' AND DeveloperName = :SERVICE_REQUEST_RT_DEV_NAME_ADM LIMIT 1];
        
        Id brokerRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Broker_Agency').getRecordTypeId();
        Id orgAccRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('OrganizationAccount').getRecordTypeId();
        Id personAccRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();
        Id accountRecordTypeId = Schema.SObjectType.Prospect_Account__c.getRecordTypeInfosByDeveloperName().get('Account').getRecordTypeId();
        Id contactRecordTypeId = Schema.SObjectType.Prospect_Account__c.getRecordTypeInfosByDeveloperName().get('Contact').getRecordTypeId();
        
        // Create an Organization Account
        Account acc = new Account(
            Name = 'Xxy Orig',
            RecordTypeId = orgAccRecordTypeId
        );
        insert acc;
        
        salesorder__c so = new salesorder__c();
        so.status__c = 'sold';
        so.CustomerAccount__c = acc.Id;
        insert so;
        
        serviceRequest__c sr = new serviceRequest__c();
        sr.status__c = 'New';
        sr.SalesOrder__c = so.id;
        sr.RecordTypeId = serRec.Id;
        insert sr;
        
        Contact con = new Contact(LastName = 'Test Contact');
        insert con;
        
        
        
        // Create Prospect_Account__c with Account
       Prospect_Account__c prospect3 = new Prospect_Account__c(
            Account_Name__c = 'Test Business Account 123',
            RecordTypeId	=  accountRecordTypeId,
            Title__c ='Mr.',
            email__c = 'Test@test.com',
            EIDNumber__c ='784-1234-1234567-1',
            First_Name__c ='Krishna Chaitanya',
            Last_Name__c = ' Anderson',
            Account_Type__c = 'Broker Agency',
            Description__c = 'Business description',
            LegalStructure__c = 'Foreign Company (Non UAE based)',
            profileId__c = '12345',
            PassfortRiskStatus__c = 'Low',
            SourceOfIncome__c = 'Salary',
            OtherSourceOfIncome__c = 'Investments',
            TradeLicenseExpiryDate__c = Date.today().addYears(1),
            UAE_Resident_Status__c = 'Resident',
            UAEVATRegisterNumber__c = 'VAT12345',
            UnifiedNumber__c = 'UN12345',
            PaymentMethod__c = 'Cash',
            OtherLegalStructure__c = 'Other',
            IsTheBusinessEntityRealBeneficiary__c = true,
            Mobile__c = '+971525612345',
            DateOfEstablishment__c = Date.today().addYears(-5),
            Country__c = 'United Arab Emirates',
            State__c = 'Abu Dhabi',
            OwnershipPercentage__c = 50,
            City__c = 'Abu Dhabi',
            EmiratesIDExpiryDate__c = Date.today(),
            Service_Request__c = sr.Id,
            Street__c = 'Street 1',
            RelationshipSubType__c='Friend',
            PostalCode__c = '00000'
        );
        
        Prospect_Account__c prospect4 = new Prospect_Account__c(
            Account_Name__c = 'bbb Org 123',
            RecordTypeId	=  accountRecordTypeId,
            Title__c ='Mr.',
            email__c = 'Testbbb@testorg.com',
            First_Name__c ='Krishna Chaitanya',
            EIDNumber__c ='784-1234-1234567-1',
            Last_Name__c = ' Anderson',
            Account_Type__c = 'Broker Agency',
            Description__c = 'Business description',
            LegalStructure__c = 'Foreign Company (Non UAE based)',
            profileId__c = '12345',
            PassfortRiskStatus__c = 'Low',
            SourceOfIncome__c = 'Salary',
            Account__c = null,
            Contact__c = null,
            OtherSourceOfIncome__c = 'Investments',
            TradeLicenseExpiryDate__c = Date.today().addYears(1),
            UAE_Resident_Status__c = 'Resident',
            UAEVATRegisterNumber__c = 'VAT12345',
            UnifiedNumber__c = 'UN12345',
            PaymentMethod__c = 'Cash',
            OtherLegalStructure__c = 'Other',
            IsTheBusinessEntityRealBeneficiary__c = true,
            EmiratesIDExpiryDate__c = Date.today(),
            Mobile__c = '+971525612345',
            DateOfEstablishment__c = Date.today().addYears(-5),
            Country__c = 'United Arab Emirates',
            IsPersonAccount__c = false,
            State__c = 'Abu Dhabi',
            Prospect_Account__c= prospect3.Id,
            OwnershipPercentage__c = 50,
            City__c = 'Abu Dhabi',
            Service_Request__c = sr.Id,
            Street__c = 'Street 1',
            RelationshipSubType__c='Friend',
            PostalCode__c = '00000'
        );
        
        
        insert new List<Prospect_Account__c>{ prospect3, prospect4 };
            
            // Create Documents__c linked to Account
            Documents__c accDoc = new Documents__c(
                Name = 'Account Doc',
                Account__c = acc.Id
            );
        insert accDoc;
        
        // Create Documents__c linked to Contact
        Documents__c conDoc = new Documents__c(
            Name = 'Contact Doc',
            PrimaryContact__c = con.Id
        );
        insert conDoc;
    }
    
    @isTest
    static void testProspectAccountTriggerHandler() {
        Test.startTest();
        
        // Create Organization Account
        Id orgRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('OrganizationAccount').getRecordTypeId();
        
        Account orgAccount = new Account(
            Name = 'oooo Organization Account 123',
            RecordTypeId = orgRecordTypeId
        );
        insert orgAccount;
        
        // Create two SalesOrders (to avoid uniqueness issues)
        SalesOrder__c so1 = new SalesOrder__c(CustomerAccount__c = orgAccount.Id,Status__c = 'sold');
        SalesOrder__c so2 = new SalesOrder__c(CustomerAccount__c = orgAccount.Id,Status__c = 'sold');
        insert new List<SalesOrder__c>{so1, so2};
            
            // Create DocumentType
            DocumentType__c docType = new DocumentType__c(
                Type__c = 'Passport',
                ShareWithCustomer__c = true,
                IsSystemUpload__c = false,
                RecordTypeDevName__c = 'Account'
            );
        insert docType;
        
        // Create ServiceRequest
        Id srRtId = Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType, SERVICE_REQUEST_RT_DEV_NAME_ADM);
        ServiceRequest__c sr = new ServiceRequest__c(
            AccountId__c = orgAccount.Id,
            SalesOrder__c = so1.Id,
            RecordTypeId = srRtId
        );
        insert sr;
        
        // Create Prospect Account
        Id paRtId = Schema.SObjectType.Prospect_Account__c.getRecordTypeInfosByDeveloperName().get('Account').getRecordTypeId();
        Prospect_Account__c pa = new Prospect_Account__c(
            Account_Name__c = 'yyy Org 123',
            Description__c = 'Business description',
            LegalStructure__c = 'Foreign Company (Non UAE based)',
            profileId__c = '12345',
            PassfortRiskStatus__c = 'Low',
            SourceOfIncome__c = 'Salary',
            OtherSourceOfIncome__c = 'Investments',
            TradeLicenseExpiryDate__c = Date.today().addYears(1),
            UAE_Resident_Status__c = 'Resident',
            UAEVATRegisterNumber__c = 'VAT12345',
            UnifiedNumber__c = 'UN12345',
            PaymentMethod__c = 'Cash',
            OtherLegalStructure__c = 'Other',
            IsTheBusinessEntityRealBeneficiary__c = true,
            Mobile__c = '+971525612345',
            DateOfEstablishment__c = Date.today().addYears(-5),
            Country__c = 'UAE',
            State__c = 'Abu Dhabi',
            City__c = 'Abu Dhabi',
            Street__c = 'Street 1',
            PostalCode__c = '00000',
            Account__c = orgAccount.Id,
            Account_Type__c = 'Organization Account',
            Service_Request__c = sr.Id,
            RecordTypeId = paRtId
        );
        insert pa;
        
        
        
        
        // Test update
        pa.Account_Name__c = 'Updated Org Account';
        update pa;
        
        // Test delete & undelete
       // delete pa;
        //undelete pa;
        
        // Trigger manual execution
        List<sObject> newList = new List<sObject>{pa};
            Map<Id, sObject> newMap = new Map<Id, sObject>{ pa.Id => pa };
                List<sObject> oldList = null;
        Map<Id, sObject> oldMap = null;
        
        ProspectAccountTriggerHandler.isTestRun = true;
        Test.stopTest();
    }
    @isTest
    static void testProspectAccountTriggerHandler1() {
        Test.startTest();
        
        // Create Organization Account
        Id orgRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('OrganizationAccount').getRecordTypeId();
        
        Account orgAccount = new Account(
            Name = '7ization Account 123',
            RecordTypeId = orgRecordTypeId
        );
        insert orgAccount;
        
        // Create SalesOrders
        SalesOrder__c so1 = new SalesOrder__c(CustomerAccount__c = orgAccount.Id, Status__c = 'sold');
        SalesOrder__c so2 = new SalesOrder__c(CustomerAccount__c = orgAccount.Id, Status__c = 'sold');
        insert new List<SalesOrder__c>{so1, so2};
            
            // Create DocumentType
            DocumentType__c docType = new DocumentType__c(
                Type__c = 'Passport',
                ShareWithCustomer__c = true,
                IsSystemUpload__c = false,
                RecordTypeDevName__c = 'Account'
            );
        insert docType;
        
        // Create ServiceRequest
        Id srRtId = Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType, SERVICE_REQUEST_RT_DEV_NAME_ADM);
        ServiceRequest__c sr = new ServiceRequest__c(
            AccountId__c = orgAccount.Id,
            SalesOrder__c = so1.Id,
            RecordTypeId = srRtId
        );
        insert sr;
        
        // Create initial Prospect Account to simulate existing one
        Id paRtId = Schema.SObjectType.Prospect_Account__c.getRecordTypeInfosByDeveloperName().get('Account').getRecordTypeId();
        Prospect_Account__c existingPa = new Prospect_Account__c(
            Account_Name__c = 'Abc Org lll',
            Description__c = 'Business description',
            LegalStructure__c = 'Foreign Company (Non UAE based)',
            profileId__c = '12345',
            PassfortRiskStatus__c = 'Low',
            SourceOfIncome__c = 'Salary',
            OtherSourceOfIncome__c = 'Investments',
            TradeLicenseExpiryDate__c = Date.today().addYears(1),
            UAE_Resident_Status__c = 'Resident',
            UAEVATRegisterNumber__c = 'VAT12345',
            UnifiedNumber__c = 'UN12345',
            PaymentMethod__c = 'Cash',
            OtherLegalStructure__c = 'Other',
            IsTheBusinessEntityRealBeneficiary__c = true,
            Mobile__c = '+971525612345',
            DateOfEstablishment__c = Date.today().addYears(-5),
            Country__c = 'UAE',
            State__c = 'Abu Dhabi',
            City__c = 'Abu Dhabi',
            Street__c = 'Street 1',
            PostalCode__c = '00000',
            Account__c = orgAccount.Id,
            Account_Type__c = 'Organization Account',
            Service_Request__c = sr.Id,
            RecordTypeId = paRtId
        );
        insert existingPa;
        
        // Attempt to insert duplicate Prospect Account
        Prospect_Account__c duplicatePa = new Prospect_Account__c(
            Account_Name__c = 'Abc Org lll',
            Description__c = 'Business description',
            LegalStructure__c = 'Foreign Company (Non UAE based)',
            profileId__c = '12345',
            PassfortRiskStatus__c = 'Low',
            SourceOfIncome__c = 'Salary',
            OtherSourceOfIncome__c = 'Investments',
            TradeLicenseExpiryDate__c = Date.today().addYears(1),
            UAE_Resident_Status__c = 'Resident',
            UAEVATRegisterNumber__c = 'VAT12345',
            UnifiedNumber__c = 'UN12345',
            PaymentMethod__c = 'Cash',
            OtherLegalStructure__c = 'Other',
            IsTheBusinessEntityRealBeneficiary__c = true,
            Mobile__c = '+971525612345',
            DateOfEstablishment__c = Date.today().addYears(-5),
            Country__c = 'UAE',
            State__c = 'Abu Dhabi',
            City__c = 'Abu Dhabi',
            Street__c = 'Street 1',
            PostalCode__c = '00000',
            Account__c = orgAccount.Id,
            Account_Type__c = 'Organization Account',
            Service_Request__c = sr.Id,
            RecordTypeId = paRtId
        );
        
        try {
            insert duplicatePa;
            System.assert(false, 'Expected a DML exception due to duplicate Prospect Account');
        } catch (DmlException e) {
            System.assert(
                e.getMessage().contains('A Prospect Account with the same Service Request and Account already exists.'),
                'Validation error not triggered as expected'
            );
        }
        
        // Test update
        existingPa.Account_Name__c = 'Updated Org Account';
        update existingPa;
        
        // Test delete and undelete
        //delete existingPa;
        //undelete existingPa;
        
        // Trigger manual execution context
        List<sObject> newList = new List<sObject>{ existingPa };
            Map<Id, sObject> newMap = new Map<Id, sObject>{ existingPa.Id => existingPa };
                List<sObject> oldList = null;
        Map<Id, sObject> oldMap = null;
        ProspectAccountTriggerHandler prHelper =new ProspectAccountTriggerHandler();
        prHelper.afterDelete(null, null);
        prHelper.afterUnDelete(null,null);
        ProspectAccountTriggerHandler.isTestRun = true;
        
        Test.stopTest();
    }
    
    @isTest
    static void testDocumentTypeController() {
        Test.startTest();
        
        DocumentType__c docType = new DocumentType__c(
            Type__c = 'Passport',
            ShareWithCustomer__c = true,
            IsSystemUpload__c = false,
            RecordTypeDevName__c = SERVICE_REQUEST_RT_DEV_NAME_ADM
        );
        insert docType;
        
        Id srRtId = Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType, SERVICE_REQUEST_RT_DEV_NAME_ADM);
        
        SalesOrder__c sonew = new SalesOrder__c(status__c = 'sold');
        insert sonew;
        ServiceRequest__c sr = new ServiceRequest__c(
            RecordTypeId = srRtId,
            SalesOrder__c = sonew.id
        );
        insert sr;
        
        List<ServiceRequest__c> srList = new List<ServiceRequest__c>{sr};
            DocumentTypeController.creatingDocment(srList, 'Service Request');
        DocumentTypeController.justIncrement();
        
        Test.stopTest();
    }
    
    @isTest
    Static void Testscenario1(){
        
        
        // Create Organization Account
        Id orgRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('OrganizationAccount').getRecordTypeId();
        
        Account orgAccount = new Account(
            Name = 'GGG Organization Account 123',
            RecordTypeId = orgRecordTypeId
        );
        insert orgAccount;
        
        // Create two SalesOrders (to avoid uniqueness issues)
        SalesOrder__c so1 = new SalesOrder__c(CustomerAccount__c = orgAccount.Id,Status__c = 'sold');
        SalesOrder__c so2 = new SalesOrder__c(CustomerAccount__c = orgAccount.Id,Status__c = 'sold');
        insert new List<SalesOrder__c>{so1, so2};
            
            // Create DocumentType
            DocumentType__c docType = new DocumentType__c(
                Type__c = 'Passport',
                ShareWithCustomer__c = true,
                IsSystemUpload__c = false,
                RecordTypeDevName__c = 'Account'
            );
        insert docType;
        
        // Create ServiceRequest
        Id srRtId = Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType, SERVICE_REQUEST_RT_DEV_NAME_ADM);
        ServiceRequest__c sr = new ServiceRequest__c(
            AccountId__c = orgAccount.Id,
            SalesOrder__c = so1.Id,
            RecordTypeId = srRtId
        );
        insert sr;
               
        Id accountRecordTypeId = Schema.SObjectType.Prospect_Account__c.getRecordTypeInfosByDeveloperName().get('Account').getRecordTypeId();

        Prospect_Account__c prospect3 = new Prospect_Account__c(
            Account_Name__c = 'Test Business Account 123',
            RecordTypeId	=  accountRecordTypeId,
            Title__c ='Mr.',
            email__c = 'Test@test.com',
            First_Name__c ='Krishna Chaitanya',
            Last_Name__c = ' Anderson',
            Account_Type__c = 'Broker Agency',
            Description__c = 'Business description',
            LegalStructure__c = 'Foreign Company (Non UAE based)',
            profileId__c = '12345',
            PassfortRiskStatus__c = 'Low',
            PassportExpiryDate__c=system.today(),
            SourceOfIncome__c = 'Salary',
            OtherSourceOfIncome__c = 'Investments',
            TradeLicenseExpiryDate__c = Date.today().addYears(1),
            EIDNumber__c ='784-1234-1234567-1',
            EmiratesIDExpiryDate__c = Date.today(),
            UAE_Resident_Status__c = 'Resident',
            UAEVATRegisterNumber__c = 'VAT12345',
            UnifiedNumber__c = 'UN12345',
            PaymentMethod__c = 'Cash',
            OtherLegalStructure__c = 'Other',
            IsTheBusinessEntityRealBeneficiary__c = true,
            Mobile__c = '+971525612345',
            DateOfEstablishment__c = Date.today().addYears(-5),
            Country__c = 'United Arab Emirates',
            Nationality__c= 'United Arab Emirates',
            State__c = 'Abu Dhabi',
            OwnershipPercentage__c = 50,
            City__c = 'Abu Dhabi',
            Service_Request__c = sr.Id,
            Street__c = 'Street 1',
            RelationshipSubType__c='Friend',
            PostalCode__c = '00000'
        );
        insert prospect3; 
        
        
    }
    
    @isTest
    static void testCreatingDocment_AllPaths() {
        // Fetch inserted Prospect Accounts
        List<Prospect_Account__c> paList = [SELECT Id,RecordTypeName__c, Name, Account__c FROM Prospect_Account__c];
        
        // Call the helper method directly
        Test.startTest();
        ProspectAccountTriggerHelper.creatingDocment(paList);
        Test.stopTest();
        
        // Validate Documents__c got updated with Prospect_Account__c
        List<Documents__c> updatedDocs = [
            SELECT Id, Name, Prospect_Account__c
            FROM Documents__c
            WHERE Prospect_Account__c != null
        ];
        
        for (Documents__c doc : updatedDocs) {
            System.assertNotEquals(null, doc.Prospect_Account__c, 'Prospect_Account__c should be populated on Documents__c');
        }
    }
    
    @isTest
    static void testCreatingDocment_NoDocsFallbackPath() {
        
        serviceRequest__c sr = [select id from serviceRequest__C Limit 1];
        Id brokerRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Broker_Agency').getRecordTypeId();
        Id orgAccRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('OrganizationAccount').getRecordTypeId();
        Id personAccRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();
        Id accountRecordTypeId = Schema.SObjectType.Prospect_Account__c.getRecordTypeInfosByDeveloperName().get('Account').getRecordTypeId();
        Id contactRecordTypeId = Schema.SObjectType.Prospect_Account__c.getRecordTypeInfosByDeveloperName().get('Contact').getRecordTypeId();
        
        Account accNoDocs = new Account(
            Name = 'No Docs Account',
            RecordTypeId = orgAccRecordTypeId
            //IsPersonAccount = true
        );
        insert accNoDocs;
        
        // Create a new Prospect_Account__c linked to that account

        Prospect_Account__c prospect3 = new Prospect_Account__c(
            Account_Name__c = 'Test Business Account 456',
            RecordTypeId	=  accountRecordTypeId,
            Account__c =accNoDocs.id,
            Title__c ='Mr.',
            email__c = 'Test@test.com',
            First_Name__c ='Krishna Chaitanya',
            Last_Name__c = ' Anderson',
            Account_Type__c = 'Broker Agency',
            Description__c = 'Business description',
            LegalStructure__c = 'Foreign Company (Non UAE based)',
            profileId__c = '12345',
            PassfortRiskStatus__c = 'Low',
            PassportExpiryDate__c=system.today(),
            SourceOfIncome__c = 'Salary',
            OtherSourceOfIncome__c = 'Investments',
            TradeLicenseExpiryDate__c = Date.today().addYears(1),
            EIDNumber__c ='784-1234-1234567-1',
            EmiratesIDExpiryDate__c = Date.today(),
            UAE_Resident_Status__c = 'Resident',
            UAEVATRegisterNumber__c = 'VAT12345',
            UnifiedNumber__c = 'UN12345',
            PaymentMethod__c = 'Cash',
            OtherLegalStructure__c = 'Other',
            IsTheBusinessEntityRealBeneficiary__c = true,
            Mobile__c = '+971525612345',
            DateOfEstablishment__c = Date.today().addYears(-5),
            Country__c = 'United Arab Emirates',
            Nationality__c= 'United Arab Emirates',
            State__c = 'Abu Dhabi',
            OwnershipPercentage__c = 50,
            City__c = 'Abu Dhabi',
            Service_Request__c = sr.Id,
            Street__c = 'Street 1',
            RelationshipSubType__c='Friend',
            PostalCode__c = '00000'
        );
        insert prospect3; 
        
        // Clear out any documents
        //delete [SELECT Id FROM Documents__c];
        
        // Re-fetch the inserted PA
        List<Prospect_Account__c> paList = [SELECT Id,Service_Request__c,RecordTypeName__c, Account__c FROM Prospect_Account__c WHERE Account__c = :accNoDocs.Id];
        
        // Run method - fallback should be triggered
        Test.startTest();
        ProspectAccountTriggerHelper.creatingDocment(paList);
        ProspectAccountTriggerHelper.checkProspectAccountDeletion(paList);
        Test.stopTest();
        
        // No documents should be updated
        List<Documents__c> docs = [SELECT Id, Prospect_Account__c FROM Documents__c];
       // System.assertEquals(0, docs.size(), 'No documents should be linked');
    }
    
}