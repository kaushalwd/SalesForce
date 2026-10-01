@IsTest
private class PassfortTransactionProcessBatchTest {
    
    private class RestMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HTTPResponse res = new HTTPResponse();
            res.setHeader('Content-Type', 'application/json');
            if (req.getBody() != null && req.getBody().contains('"data"')) {
                res.setBody('{"status":"Success","file_id":"FILE-001"}');
            } else {
                res.setBody('{"integration_id":"YxvkMSGkEe-RpoFwob_Iiw","status":"Success","id":"08aadff4-1edd-4aa8-8998-8688ef2da175","error_msg":"","root_id":"110873ff-3747-4482-846c-7bfe8867b5d4"}');
            }
            res.setStatusCode(200);
            res.setStatus('OK');
            return res;
        }
    }

    private static Id getAccountRtId(String developerName) {
        Map<String, Schema.RecordTypeInfo> rtMap = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName();
        return rtMap.containsKey(developerName) ? rtMap.get(developerName).getRecordTypeId() : null;
    }

    private static Id getContactRtId(String nameValue) {
        Map<String, Schema.RecordTypeInfo> rtMap = Schema.SObjectType.Contact.getRecordTypeInfosByName();
        return rtMap.containsKey(nameValue) ? rtMap.get(nameValue).getRecordTypeId() : null;
    }

    private static Id getProspectRtId(String developerName) {
        Map<String, Schema.RecordTypeInfo> rtMap = Schema.SObjectType.Prospect_Account__c.getRecordTypeInfosByDeveloperName();
        return rtMap.containsKey(developerName) ? rtMap.get(developerName).getRecordTypeId() : null;
    }
    
    @testSetup
    static void setup() {
        Account act = new Account(
            Name = 'Test Account',
            LegalStructure__c = 'Sole Private Establishment (UAE based)',
            DateOfEstablishment__c = Date.newInstance(2000, 2, 17),
            UnifiedNumber__c = '12357',
            TradeLicenseExpiryDate__c = Date.newInstance(2040, 2, 17),
            UAEVATRegisterNumber__c = '123456',
            PaymentMethod__c = 'Cash',
            PurposeOfTransaction__c = 'House rent',
            Phone = '+97154799866',
            SourceOfIncome__c = 'Salary',
            IsTheBusinessEntityRealBeneficiary__c = true,
            DeliveryChannel__c = 'Direct Sales Partner',
            NoOfPropertyPurchasedWithModon__c = 2,
            Description = 'test Description'
        );
        
        Account personAccount = new Account(
            RecordTypeId = getAccountRtId('PersonAccount'),
            FirstName = 'Test',
            LastName = 'PersonAccount',
            PersonBirthdate = Date.newInstance(2000, 2, 17),
            Nationality__pc = 'India',
            UAE_Resident_Status__pc = 'Resident',
            IdentityProof__pc = 'Emirates Id',
            EIDNumber__pc = '123456',
            PersonMobilePhone = '+97154799866',
            Occupation__pc = 'Teacher',
            EmployerBusinessName__pc = 'PwC',
            PaymentMethod__pc = 'Cash',
            PurposeOfTransaction__pc = 'House rent',
            PersonEmail = 'abc@pwc.com',
            AreYouPoliticallyExposedPersonPEP__pc = true,
            SourceOfIncome__pc = 'Salary',
            DeliveryChannel__pc = 'Face to face interaction',
            NoOfPropertyPurchasedWithModon__pc = 2
        );
        
        Account act1 = new Account(
            Name = 'Test Account1',
            LegalStructure__c = 'Sole Private Establishment (UAE based)',
            DateOfEstablishment__c = Date.newInstance(2000, 2, 17),
            UnifiedNumber__c = '22357',
            TradeLicenseExpiryDate__c = Date.newInstance(2040, 2, 17),
            UAEVATRegisterNumber__c = '223456',
            PaymentMethod__c = 'Cash',
            PurposeOfTransaction__c = 'House rent',
            Phone = '+97154799867',
            SourceOfIncome__c = 'Salary',
            IsTheBusinessEntityRealBeneficiary__c = true,
            DeliveryChannel__c = 'Direct Sales Partner',
            NoOfPropertyPurchasedWithModon__c = 2,
            Description = 'test Description'
        );
        
        insert new List<Account>{ act, personAccount, act1 };
        
        Contact con = new Contact(
            FirstName = 'Test',
            LastName = 'Test Contact',
            AccountId = act.Id,
            Birthdate = Date.newInstance(2000, 2, 17),
            Nationality__c = 'India',
            UAE_Resident_Status__c = 'Resident',
            IdentityProof__c = 'Emirates Id',
            EIDNumber__c = '123456',
            MobilePhone = '+97154799866',
            Occupation__c = 'Teacher',
            EmployerBusinessName__c = 'PwC',
            PaymentMethod__c = 'Cash',
            PurposeOfTransaction__c = 'House rent',
            Email = 'abc@pwc.com',
            AreYouPoliticallyExposedPersonPEP__c = true,
            SourceOfIncome__c = 'Salary',
            DeliveryChannel__c = 'Direct Sales Partner',
            NoOfPropertyPurchasedWithModon__c = 2,
            ProfileId__c = '25f6da34-7c55-4717-8202-b886bb0b2edc',
            RecordTypeId = getContactRtId('Shareholder')
        );
        insert con;
        
        Contact contRec = new Contact(
            FirstName = 'Test',
            LastName = 'Test Contact 2',
            AccountId = act.Id,
            Birthdate = Date.newInstance(2000, 2, 17),
            Nationality__c = 'India',
            UAE_Resident_Status__c = 'Resident',
            IdentityProof__c = 'Emirates Id',
            EIDNumber__c = '1234567',
            MobilePhone = '+97154799869',
            Occupation__c = 'Teacher',
            EmployerBusinessName__c = 'PwC',
            PaymentMethod__c = 'Cash',
            PurposeOfTransaction__c = 'House rent',
            Email = 'abc2@pwc.com',
            AreYouPoliticallyExposedPersonPEP__c = true,
            SourceOfIncome__c = 'Salary',
            DeliveryChannel__c = 'Direct Sales Partner',
            NoOfPropertyPurchasedWithModon__c = 2,
            ProfileId__c = '25f6da34-7c55-4717-8202-b886bb0b2edc',
            RecordTypeId = getContactRtId('Shareholder')
        );
        insert contRec;
        
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            CloseDate = Date.today(),
            StageName = 'Closed Won',
            AccountId = act.Id,
            PrimaryContact__c = con.Id
        );
        
        Opportunity opp2 = new Opportunity(
            Name = 'Test Opportunity2',
            CloseDate = Date.today(),
            StageName = 'Closed Won',
            AccountId = personAccount.Id,
            PrimaryContact__c = personAccount.PersonContactId
        );
        
        insert new List<Opportunity>{ opp, opp2 };
        
        SalesOrder__c salesOrder1 = new SalesOrder__c(
            CustomerAccount__c = act.Id,
            PrimaryContact__c = con.Id
        );
        
        SalesOrder__c salesOrder2 = new SalesOrder__c(
            CustomerAccount__c = personAccount.Id,
            PrimaryContact__c = personAccount.PersonContactId
        );
        
        insert new List<SalesOrder__c>{ salesOrder1, salesOrder2 };
        
        JointOwner__c jointOwner = new JointOwner__c(
            OwnershipPercentage__c = 50,
            RelationshipType__c = 'Joint Owner P-P',
            RelationshipSubType__c = 'Broker',
            JointOwnerAccount__c = act.Id,
            Opportunity__c = opp.Id
        );
        
        JointOwner__c jointOwner1 = new JointOwner__c(
            OwnershipPercentage__c = 20,
            RelationshipType__c = 'Joint Owner P-P',
            RelationshipSubType__c = 'Broker',
            JointOwnerAccount__c = act.Id,
            SalesOrder__c = salesOrder1.Id
        );
        
        insert new List<JointOwner__c>{ jointOwner, jointOwner1 };
        
        Contact shareholder1 = new Contact(
            FirstName = 'Test',
            LastName = 'Shareholder 1',
            AccountId = act.Id,
            OwnershipPercentage__c = 50,
            Email = 'test1@test.com',
            Birthdate = Date.newInstance(2000, 2, 17),
            Nationality__c = 'Iran',
            ProfileId__c = '25f6da34-7c55-4717-8202-b886bb0b2edc',
            RecordTypeId = getContactRtId('Shareholder')
        );
        
        Contact shareholder2 = new Contact(
            FirstName = 'Test',
            LastName = 'Shareholder 2',
            Email = 'test2@test.com',
            OwnershipPercentage__c = 20,
            Birthdate = Date.newInstance(2000, 2, 14),
            AccountId = act.Id,
            Nationality__c = 'India',
            ProfileId__c = '25f6da34-7c55-4717-8202-b886bb0b2edc',
            RecordTypeId = getContactRtId('Shareholder')
        );
        
        insert new List<Contact>{ shareholder1, shareholder2 };
        
        ContentVersion cv = new ContentVersion(
            Title = 'TestPassportDocument',
            PathOnClient = 'TestPassportDocument.pdf',
            VersionData = Blob.valueOf('test Passport component'),
            IsMajorVersion = true
        );
        insert cv;
        
        ContentVersion insertedCv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
        
        Documents__c doc = new Documents__c(
            Name = 'Passport',
            PrimaryContact__c = shareholder1.Id
        );
        insert doc;
        
        insert new ContentDocumentLink(
            ContentDocumentId = insertedCv.ContentDocumentId,
            LinkedEntityId = doc.Id
        );
        
ServiceRequest__c sr = new ServiceRequest__c(
    AccountId__c = personAccount.Id,
    SalesOrder__c = salesOrder2.Id
);
        insert sr;
        
Prospect_Account__c parentPa = new Prospect_Account__c(
    IsPersonAccount__c = true,
    Account_Type__c = 'Broker Agency',
    Service_Request__c = sr.Id,
    Is_Primary__c = true,
    RelationshipType__c = 'Individual',
    RelationshipSubType__c = 'Child',
    OwnershipPercentage__c = 53.3,
    Birthdate__c = System.today(),
    EIDNumber__c = '784-1234-1234567-1',
    PassportNumber__c = '10AL5003',
    City__c = 'City',
    Country__c = 'United Arab Emirates',
    SourceOfIncome__c = 'Others (please specify)',
    State__c = 'state',
    Street__c = 'Street',
    PostalCode__c = '506223',
    Mobile__c = '+9712222677',
    Nationality__c = 'United Arab Emirates',
    PaymentMethod__c = 'Cash',
    DeliveryChannel__c = 'Direct Sales Partner',
    EmployerBusinessName__c = 'Business',
    UAE_Resident_Status__c = 'Resident',
    Occupation__c = 'Occu',
    Title__c = 'Mr.',
    First_Name__c = 'Parent',
    Last_Name__c = 'test',
    ProfileId__c = 'BYV07HY',
    Email__c = 'parent@gmail.com',
    EmiratesIDExpiryDate__c = System.today() + 10,
    RecordTypeId = getProspectRtId('Account')
);
insert parentPa;

Prospect_Account__c pa = new Prospect_Account__c(
    IsPersonAccount__c = true,
    Account_Type__c = 'Broker Agency',
    Service_Request__c = sr.Id,
    Is_Primary__c = true,
    RelationshipType__c = 'Individual',
    RelationshipSubType__c = 'Child',
    OwnershipPercentage__c = 53.3,
    Birthdate__c = System.today(),
    EIDNumber__c = '784-1234-1234567-1',
    PassportNumber__c = '10AL5003',
    City__c = 'City',
    Country__c = 'United Arab Emirates',
    SourceOfIncome__c = 'Others (please specify)',
    State__c = 'state',
    Street__c = 'Street',
    PostalCode__c = '506223',
    Mobile__c = '+9712222677',
    Nationality__c = 'United Arab Emirates',
    PaymentMethod__c = 'Cash',
    DeliveryChannel__c = 'Direct Sales Partner',
    EmployerBusinessName__c = 'Business',
    UAE_Resident_Status__c = 'Resident',
    Occupation__c = 'Occu',
    Title__c = 'Mr.',
    First_Name__c = 'Test',
    Last_Name__c = 'test',
    ProfileId__c = 'BYV07HU',
    Email__c = 'child@gmail.com',
    EmiratesIDExpiryDate__c = System.today() + 10,
    Prospect_Account__c = parentPa.Id,
    RecordTypeId = getProspectRtId('Account')
);
insert pa;
        PassfortTransaction__c pst = new PassfortTransaction__c(
            EntityType__c = 'Primary Contact',
            Document__c = doc.Id,
            Sales_Order__c = salesOrder1.Id,
            Contact__c = shareholder1.Id,
            Opportunity__c = opp2.Id,
            ProfileId__c = '25f6da34-7c55-4717-8202-b886bb0b2edc',
            TransactionId__c = 'ea7861d1-ddc6-4f7c-9767-663f3b9bd5e7'
        );
        
        PassfortTransaction__c pst1 = new PassfortTransaction__c(
            EntityType__c = Constants.PASSFORT_TR_TYPE_COMPANY,
            Document__c = doc.Id,
            Sales_Order__c = salesOrder1.Id,
            Account__c = act1.Id,
            Opportunity__c = opp2.Id,
            Contact__c = shareholder1.Id,
            ProfileId__c = '125f6da34-7c55-4717-8202-b886bb0b2edc',
            TransactionId__c = '1ea7861d1-ddc6-4f7c-9767-663f3b9bd5e7'
        );
        
        PassfortTransaction__c pst2 = new PassfortTransaction__c(
            EntityType__c = 'Individual',
            Document__c = doc.Id,
            Sales_Order__c = salesOrder1.Id,
            Prospect_Account__c = pa.Id,
            Opportunity__c = opp2.Id,
            TransactionId__c = '1ea7861d1-ddc6-4f7c-9767-663f3b9bd5e8'
        );
        
        insert new List<PassfortTransaction__c>{ pst, pst1, pst2 };
    }
    
    @IsTest
    static void testMethod1() {
        Test.setMock(HttpCalloutMock.class, new RestMock());
        Set<Id> psetOfTransactionIds = new Set<Id>();
        for (PassfortTransaction__c pst : [SELECT Id FROM PassfortTransaction__c WHERE EntityType__c = 'Primary Contact' LIMIT 1]) {
            psetOfTransactionIds.add(pst.Id);
        }
        Test.startTest();
        Database.executeBatch(new PassfortTransactionProcessBatch(psetOfTransactionIds), 1);
        Test.stopTest();
    }
    
    @IsTest
    static void testMethod2() {
        Test.setMock(HttpCalloutMock.class, new RestMock());
        Set<Id> psetOfTransactionIds = new Set<Id>();
        for (PassfortTransaction__c pst : [SELECT Id FROM PassfortTransaction__c WHERE EntityType__c = :Constants.PASSFORT_TR_TYPE_COMPANY LIMIT 1]) {
            psetOfTransactionIds.add(pst.Id);
        }
        Test.startTest();
        Database.executeBatch(new PassfortTransactionProcessBatch(psetOfTransactionIds), 1);
        Test.stopTest();
    }
    
    @IsTest
    static void testMethod22() {
        Test.setMock(HttpCalloutMock.class, new RestMock());
        Set<Id> psetOfTransactionIds = new Set<Id>();
        for (PassfortTransaction__c pst : [SELECT Id FROM PassfortTransaction__c WHERE Prospect_Account__c != null LIMIT 1]) {
            psetOfTransactionIds.add(pst.Id);
        }
        Test.startTest();
        Database.executeBatch(new PassfortTransactionProcessBatch(psetOfTransactionIds), 1);
        Test.stopTest();
    }
    
    @IsTest
    static void testMethod3() {
        Test.setMock(HttpCalloutMock.class, new RestMock());
        Set<Id> prospectIds = new Set<Id>();
        for (Prospect_Account__c pa : [SELECT Id FROM Prospect_Account__c WHERE Prospect_Account__c != null LIMIT 1]) {
            prospectIds.add(pa.Id);
        }
        Test.startTest();
        PassfortTransactionProcessBatch.checkProfileIdsAndCreateTransactionPA(prospectIds);
        Test.stopTest();
    }
    
    @IsTest
    static void testMethod4() {
        Test.setMock(HttpCalloutMock.class, new RestMock());
        Set<Id> accountIds = new Set<Id>();
        for (Account acc : [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1]) {
            accountIds.add(acc.Id);
        }
        Test.startTest();
        PassfortTransactionProcessBatch.checkProfileIdsAndCreateTransaction(accountIds);
        Test.stopTest();
    }
    
    @IsTest
static void testMethod5() {
    Test.setMock(HttpCalloutMock.class, new RestMock());

    Contact shareholder = [SELECT Id FROM Contact WHERE LastName = 'Shareholder 1' LIMIT 1];
    ServiceRequest__c sr = [SELECT Id FROM ServiceRequest__c LIMIT 1];

    Documents__c docA = new Documents__c(
        Name = 'Reg Doc A',
        PrimaryContact__c = shareholder.Id
    );
    Documents__c docB = new Documents__c(
        Name = 'Reg Doc B',
        PrimaryContact__c = shareholder.Id
    );
    insert new List<Documents__c>{ docA, docB };

    Registration__c reg = new Registration__c(
        Company_Name_as_per_Trade_License__c = 'Broker Test Company A',
        Company_Email_Address__c = 'brokera@test.com',
        Trade_License_Number__c = 'TL-54321',
        Street_Name__c = 'Test Street',
        City__c = 'Abu Dhabi',
        State__c = 'Abu Dhabi',
        Postal_Code__c = '51133',
        Country__c = 'United Arab Emirates',
        Mobile_Number__c = '+971500000001',
        Website__c = 'www.testa.com',
        Type_of_Registration__c = 'New',
        Expiry_Date__c = Date.today().addYears(1),
        Issuance_Date__c = Date.today().addYears(-1),
        Licensing_Authority__c = 'Authority',
        UAE_VAT_Registration_Number__c = 'VAT-54321',
        VAT_Certificate_Type__c = 'VAT Registration Certificate',
        Bank_Name__c = 'Test Bank',
        Bank_Country__c = 'United Arab Emirates',
        IBAN_Country_Bank_Code__c = 'AE12',
        Account_Number__c = '123456780',
        SWIFT_Sort_Code__c = 'TESTAEXX',
        LegalStructure__c = 'Freezone Company/ Representative Office (UAE based)',
        Description__c = 'Broker registration test',
        PurposeOfTransaction__c = 'Property Brokerage Services',
        PaymentMethod__c = 'Domestic bank transfer',
        DeliveryChannel__c = 'Face to face interaction',
        NoOfPropertyPurchasedWithModon__c = 2,
        SourceOfIncome__c = 'Business',
        OtherSourceOfIncome__c = 'NA'
    );
    insert reg;

    PassfortTransaction__c parentTxn = new PassfortTransaction__c(
        Registration__c = reg.Id,
        EntityType__c = Constants.PASSFORT_TR_TYPE_COMPANY,
        TransactionId__c = 'REGTXN001',
        ParentDocumentIds__c = docA.Id + ',' + docB.Id
    );
    insert parentTxn;

    Set<Id> txnIds = new Set<Id>{ parentTxn.Id };

    Test.startTest();
    PassfortTransactionProcessBatch.checkProfileIdsAndCreateTransactionForRegistration(txnIds);
    Test.stopTest();
}
    
    @IsTest
static void testMethod6() {
    Test.setMock(HttpCalloutMock.class, new RestMock());

    Contact shareholder = [SELECT Id FROM Contact WHERE LastName = 'Shareholder 1' LIMIT 1];

    Documents__c docA = new Documents__c(
        Name = 'Reg Doc Existing A',
        PrimaryContact__c = shareholder.Id
    );
    Documents__c docB = new Documents__c(
        Name = 'Reg Doc Existing B',
        PrimaryContact__c = shareholder.Id
    );
    insert new List<Documents__c>{ docA, docB };

    Registration__c reg = new Registration__c(
        Company_Name_as_per_Trade_License__c = 'Broker Test Company B',
        Company_Email_Address__c = 'brokerb@test.com',
        Trade_License_Number__c = 'TL-98765',
        Street_Name__c = 'Test Street',
        City__c = 'Abu Dhabi',
        State__c = 'Abu Dhabi',
        Postal_Code__c = '51133',
        Country__c = 'United Arab Emirates',
        Mobile_Number__c = '+971500000002',
        Website__c = 'www.testb.com',
        Type_of_Registration__c = 'New',
        Expiry_Date__c = Date.today().addYears(1),
        Issuance_Date__c = Date.today().addYears(-1),
        Licensing_Authority__c = 'Authority',
        UAE_VAT_Registration_Number__c = 'VAT-98765',
        VAT_Certificate_Type__c = 'VAT Registration Certificate',
        Bank_Name__c = 'Test Bank',
        Bank_Country__c = 'United Arab Emirates',
        IBAN_Country_Bank_Code__c = 'AE12',
        Account_Number__c = '123456781',
        SWIFT_Sort_Code__c = 'TESTAEXX',
        LegalStructure__c = 'Freezone Company/ Representative Office (UAE based)',
        Description__c = 'Broker registration test',
        PurposeOfTransaction__c = 'Property Brokerage Services',
        PaymentMethod__c = 'Domestic bank transfer',
        DeliveryChannel__c = 'Face to face interaction',
        NoOfPropertyPurchasedWithModon__c = 2,
        SourceOfIncome__c = 'Business',
        OtherSourceOfIncome__c = 'NA'
    );
    insert reg;

    PassfortTransaction__c parentTxn = new PassfortTransaction__c(
        Registration__c = reg.Id,
        EntityType__c = Constants.PASSFORT_TR_TYPE_COMPANY,
        TransactionId__c = 'REGTXN002',
        ParentDocumentIds__c = docA.Id + ',' + docB.Id
    );
    insert parentTxn;

    PassfortTransaction__c existingChild = new PassfortTransaction__c(
        PassfortTransaction__c = parentTxn.Id,
        Registration__c = reg.Id,
        Document__c = docA.Id,
        EntityType__c = Constants.PASSFORT_TR_TYPE_DOCUMENT,
        TransactionId__c = 'REGTXN002_DOC_EXISTING'
    );
    insert existingChild;

    Set<Id> txnIds = new Set<Id>{ parentTxn.Id };

    Test.startTest();
    PassfortTransactionProcessBatch.checkProfileIdsAndCreateTransactionForRegistration(txnIds);
    Test.stopTest();
}
    
    
    
    @IsTest
static void testHelperUtilsDirect() {
    Test.startTest();
    PassfortTransactionProcessHelper.nullCheck(null);
    PassfortTransactionProcessHelper.nullCheck('');
    PassfortTransactionProcessHelper.nullCheck('ABC');
    PassfortTransactionProcessHelper.dateFormation(null);
    PassfortTransactionProcessHelper.dateFormation(Date.newInstance(2026, 4, 3));
    Test.stopTest();
}
    
    @IsTest
static void testUpdateAccountContactDirect() {
    Account acc = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
    Contact con = [SELECT Id FROM Contact WHERE LastName = 'Test Contact' LIMIT 1];

    Test.startTest();
    PassfortTransactionProcessHelper.updateAccountOrContactRecord(
        new Map<String, String>{ acc.Id => 'ACC_PROFILE_001' },
        new Map<String, String>{ con.Id => 'CON_PROFILE_001' },
        'profileId'
    );
    PassfortTransactionProcessHelper.updateAccountOrContactRecord(
        new Map<String, String>{ acc.Id => 'Account comment' },
        new Map<String, String>{ con.Id => 'Contact comment' },
        'comment'
    );
    Test.stopTest();
}
    
    
    @IsTest
static void testResponseAndCreateDocTxnDirect() {
    PassfortTransaction__c parentTxn = [
        SELECT Id
        FROM PassfortTransaction__c
        WHERE EntityType__c = 'Primary Contact'
        LIMIT 1
    ];

    Documents__c doc = [SELECT Id FROM Documents__c WHERE Name = 'Passport' LIMIT 1];

    Test.startTest();
    PassfortTransactionProcessHelper.updateResponseOnTransactionRecord(
        new Map<String, String>{ parentTxn.Id => '{"status":"Success"}' },
        new Map<String, String>{ parentTxn.Id => 'TXN001:PROFILE001' }
    );
    PassfortTransactionProcessHelper.createDocumentTransactionRecords(
        new Map<String, String>{ parentTxn.Id => doc.Id }
    );
    Test.stopTest();
}
    

    
}