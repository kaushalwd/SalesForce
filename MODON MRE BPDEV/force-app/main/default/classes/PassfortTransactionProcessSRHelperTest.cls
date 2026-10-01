@IsTest
public class PassfortTransactionProcessSRHelperTest {
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

    private static Id getContactRtId(String recordTypeName) {
        Map<String, Schema.RecordTypeInfo> rtMap = Schema.SObjectType.Contact.getRecordTypeInfosByName();
        return rtMap.containsKey(recordTypeName) ? rtMap.get(recordTypeName).getRecordTypeId() : null;
    }

    private static Id getProspectRtId(String developerName) {
        Map<String, Schema.RecordTypeInfo> rtMap = Schema.SObjectType.Prospect_Account__c.getRecordTypeInfosByDeveloperName();
        return rtMap.containsKey(developerName) ? rtMap.get(developerName).getRecordTypeId() : null;
    }

    @testSetup
    static void setup() {
        Test.setMock(HttpCalloutMock.class, new RestMock());

        Account businessAcc = new Account(
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

        Account personAcc = new Account(
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

        insert new List<Account>{ businessAcc, personAcc };

        Contact shareholder = new Contact(
            FirstName = 'Test',
            LastName = 'Shareholder',
            AccountId = businessAcc.Id,
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
        insert shareholder;

        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            CloseDate = Date.today(),
            StageName = 'Closed Won',
            AccountId = businessAcc.Id,
            PrimaryContact__c = shareholder.Id
        );

        Opportunity opp2 = new Opportunity(
            Name = 'Test Opportunity 2',
            CloseDate = Date.today(),
            StageName = 'Closed Won',
            AccountId = personAcc.Id,
            PrimaryContact__c = personAcc.PersonContactId
        );
        insert new List<Opportunity>{ opp, opp2 };

        SalesOrder__c salesOrder = new SalesOrder__c(
            CustomerAccount__c = businessAcc.Id,
            PrimaryContact__c = shareholder.Id
        );

        SalesOrder__c salesOrder2 = new SalesOrder__c(
            CustomerAccount__c = personAcc.Id,
            PrimaryContact__c = personAcc.PersonContactId
        );
        insert new List<SalesOrder__c>{ salesOrder, salesOrder2 };

        JointOwner__c jo1 = new JointOwner__c(
            OwnershipPercentage__c = 50,
            RelationshipType__c = 'Joint Owner P-P',
            RelationshipSubType__c = 'Broker',
            JointOwnerAccount__c = businessAcc.Id,
            Opportunity__c = opp.Id
        );

        JointOwner__c jo2 = new JointOwner__c(
            OwnershipPercentage__c = 20,
            RelationshipType__c = 'Joint Owner P-P',
            RelationshipSubType__c = 'Broker',
            JointOwnerAccount__c = businessAcc.Id,
            SalesOrder__c = salesOrder.Id
        );
        insert new List<JointOwner__c>{ jo1, jo2 };

        ContentVersion cv = new ContentVersion(
            Title = 'TestPassportDocument',
            PathOnClient = 'TestPassportDocument.pdf',
            VersionData = Blob.valueOf('test Passport component'),
            IsMajorVersion = true
        );
        insert cv;

        ContentVersion insertedCv = [
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
            LIMIT 1
        ];

        Documents__c doc1 = new Documents__c(
            Name = 'Passport1',
            PrimaryContact__c = shareholder.Id
        );
        Documents__c doc2 = new Documents__c(
            Name = 'Passport2',
            PrimaryContact__c = shareholder.Id
        );
        Documents__c doc3 = new Documents__c(
            Name = 'Passport3',
            PrimaryContact__c = shareholder.Id
        );
        insert new List<Documents__c>{ doc1, doc2, doc3 };

        insert new List<ContentDocumentLink>{
            new ContentDocumentLink(
                ContentDocumentId = insertedCv.ContentDocumentId,
                LinkedEntityId = doc1.Id
            ),
            new ContentDocumentLink(
                ContentDocumentId = insertedCv.ContentDocumentId,
                LinkedEntityId = doc2.Id
            ),
            new ContentDocumentLink(
                ContentDocumentId = insertedCv.ContentDocumentId,
                LinkedEntityId = doc3.Id
            )
        };

            ServiceRequest__c sr = new ServiceRequest__c(
                AccountId__c = personAcc.Id,
                SalesOrder__c = salesOrder2.Id
            );
        insert sr;

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
    OtherSourceOfIncome__c = 'Other Income',
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
    Email__c = 'test@gmail.com',
    EmiratesIDExpiryDate__c = System.today() + 10,
    RecordTypeId = getProspectRtId('Account')
);
insert pa;

Prospect_Account__c parentPa = new Prospect_Account__c(
    IsPersonAccount__c = true,
    Account_Type__c = 'Broker Agency',
    Service_Request__c = sr.Id,
    Is_Primary__c = true,
    RelationshipType__c = 'Individual',
    OwnershipPercentage__c = 100,
    First_Name__c = 'Parent',
    Last_Name__c = 'Prospect',
    Email__c = 'parent@gmail.com',
    Country__c = 'United Arab Emirates',
    Nationality__c = 'United Arab Emirates',
    PaymentMethod__c = 'Cash',
    DeliveryChannel__c = 'Direct Sales Partner',
    UAE_Resident_Status__c = 'Resident',
    RecordTypeId = getProspectRtId('Account')
);
insert parentPa;

        pa.Prospect_Account__c = parentPa.Id;
        update pa;

        PassfortTransaction__c profileTxn = new PassfortTransaction__c(
            EntityType__c = 'Individual',
            Document__c = doc1.Id,
            Sales_Order__c = salesOrder.Id,
            Prospect_Account__c = pa.Id,
            TransactionId__c = '1ea7861d1-ddc6-4f7c-9767-663f3b9bd5e7',
            ParentDocumentIds__c = doc1.Id + ',' + doc2.Id
        );
        insert profileTxn;

        PassfortTransaction__c childDocTxn = new PassfortTransaction__c(
            PassfortTransaction__c = profileTxn.Id,
            Document__c = doc1.Id,
            EntityType__c = Constants.PASSFORT_TR_TYPE_DOCUMENT,
            TransactionId__c = '3ea7861d1-ddc6-4f7c-9767-663f3b9bd5e72',
            ProfileId__c = 'PROFILE-DOC-001'
        );
        insert childDocTxn;

        Registration__c reg = new Registration__c(
            Company_Name_as_per_Trade_License__c = 'Broker Test Company',
            Company_Email_Address__c = 'broker@test.com',
            Trade_License_Number__c = 'TL-12345',
            Street_Name__c = 'Test Street',
            City__c = 'Abu Dhabi',
            State__c = 'Abu Dhabi',
            Postal_Code__c = '51133',
            Country__c = 'United Arab Emirates',
            Mobile_Number__c = '+971500000000',
            Website__c = 'www.test.com',
            Type_of_Registration__c = 'New',
            Expiry_Date__c = Date.today().addYears(1),
            Issuance_Date__c = Date.today().addYears(-1),
            Licensing_Authority__c = 'Authority',
            UAE_VAT_Registration_Number__c = 'VAT-123',
            VAT_Certificate_Type__c = 'VAT Registration Certificate',
            Bank_Name__c = 'Test Bank',
            Bank_Country__c = 'United Arab Emirates',
            IBAN_Country_Bank_Code__c = 'AE12',
            Account_Number__c = '123456789',
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

        PassfortTransaction__c brokerTxn = new PassfortTransaction__c(
            Registration__c = reg.Id,
            EntityType__c = Constants.PASSFORT_TR_TYPE_COMPANY,
            TransactionId__c = '4ea7861d1-ddc6-4f7c-9767-663f3b9bd5e73',
            ParentDocumentIds__c = doc3.Id
        );
        insert brokerTxn;
    }

    @IsTest
    static void testPrepareProfileJSON() {
        Test.setMock(HttpCalloutMock.class, new RestMock());

        Prospect_Account__c pa = [
            SELECT Id
            FROM Prospect_Account__c
            WHERE Email__c = 'test@gmail.com'
            LIMIT 1
        ];

        Set<Id> transactionIds = new Set<Id>();
        for (PassfortTransaction__c txn : [
            SELECT Id
            FROM PassfortTransaction__c
            WHERE Prospect_Account__c = :pa.Id
            AND PassfortTransaction__c = NULL
        ]) {
            transactionIds.add(txn.Id);
        }

        Test.startTest();
        PassfortTransactionProcessSRHelper.prepareProfileJSON(transactionIds);
        Test.stopTest();

        List<PassfortTransaction__c> updatedTxns = [
            SELECT Id, Response__c, ProfileId__c
            FROM PassfortTransaction__c
            WHERE Id IN :transactionIds
        ];
        System.assert(!updatedTxns.isEmpty());

        Prospect_Account__c updatedPa = [
            SELECT Id, ProfileId__c, PassfortApprovalStatus__c
            FROM Prospect_Account__c
            WHERE Id = :pa.Id
        ];
    }

    @IsTest
    static void testCreateDocumentTransactionRecords() {
        PassfortTransaction__c txn = [
            SELECT Id
            FROM PassfortTransaction__c
            WHERE PassfortTransaction__c = NULL
            LIMIT 1
        ];
        Documents__c doc = [SELECT Id FROM Documents__c LIMIT 1];

        Map<String, String> inputMap = new Map<String, String>{
            String.valueOf(txn.Id) => String.valueOf(doc.Id)
        };

        Test.startTest();
        PassfortTransactionProcessSRHelper.createDocumentTransactionRecords(inputMap);
        Test.stopTest();

        List<PassfortTransaction__c> createdDocs = [
            SELECT Id, PassfortTransaction__c, Document__c, EntityType__c
            FROM PassfortTransaction__c
            WHERE PassfortTransaction__c = :txn.Id
            AND Document__c = :doc.Id
        ];
    }

@IsTest
static void testPrepareDocumentJSON() {
    Test.setMock(HttpCalloutMock.class, new RestMock());

    Set<Id> docIds = new Set<Id>();
    for (Documents__c doc : [
        SELECT Id
        FROM Documents__c
    ]) {
        docIds.add(doc.Id);
    }

    Set<Id> linkedDocumentIds = new Set<Id>();
    if (!docIds.isEmpty()) {
        for (ContentDocumentLink cdl : [
            SELECT LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :docIds
        ]) {
            linkedDocumentIds.add(cdl.LinkedEntityId);
        }
    }

    Set<Id> transactionIds = new Set<Id>();
    for (PassfortTransaction__c txn : [
        SELECT Id, Document__c
        FROM PassfortTransaction__c
        WHERE PassfortTransaction__c != NULL
        AND EntityType__c = :Constants.PASSFORT_TR_TYPE_DOCUMENT
        AND Document__c IN :linkedDocumentIds
    ]) {
        transactionIds.add(txn.Id);
    }

    Test.startTest();
    PassfortTransactionProcessSRHelper.prepareDocumentJSON(transactionIds);
    Test.stopTest();

    List<PassfortTransaction__c> updatedDocs = [
        SELECT Id, Response__c, ProfileId__c
        FROM PassfortTransaction__c
        WHERE Id IN :transactionIds
    ];
}

    @IsTest
    static void testPrepareBrokerRegistrationJSON() {
        Test.setMock(HttpCalloutMock.class, new RestMock());

        Set<Id> transactionIds = new Set<Id>();
        for (PassfortTransaction__c txn : [
            SELECT Id
            FROM PassfortTransaction__c
            WHERE Registration__c != NULL
            AND EntityType__c = :Constants.PASSFORT_TR_TYPE_COMPANY
        ]) {
            transactionIds.add(txn.Id);
        }

        Test.startTest();
        PassfortTransactionProcessSRHelper.prepareBrokerRegistrationJSON(transactionIds);
        Test.stopTest();

        Registration__c reg = [
            SELECT Id, ProfileId__c, PassfortApprovalStatus__c
            FROM Registration__c
            LIMIT 1
        ];
        System.assertEquals('110873ff-3747-4482-846c-7bfe8867b5d4', reg.ProfileId__c);

        List<PassfortTransaction__c> regTxns = [
            SELECT Id, Response__c, ProfileId__c
            FROM PassfortTransaction__c
            WHERE Id IN :transactionIds
        ];
    }

    @IsTest
    static void testUtilityMethods() {

        Prospect_Account__c pa = [
            SELECT Id
            FROM Prospect_Account__c
            WHERE Email__c = 'test@gmail.com'
            LIMIT 1
        ];

        Map<String, String> profileMap = new Map<String, String>{
            String.valueOf(pa.Id) => 'PROFILE-123'
        };

        Test.startTest();
        PassfortTransactionProcessSRHelper.updateAccountOrContactRecord(profileMap, 'profileId');
        PassfortTransactionProcessSRHelper.updateAccountOrContactRecord(profileMap, 'comment');

        PassfortTransaction__c txn = [SELECT Id FROM PassfortTransaction__c LIMIT 1];
        Map<String, String> responseMap = new Map<String, String>{
            String.valueOf(txn.Id) => '{"status":"Success"}'
        };
        Map<String, String> trIdMap = new Map<String, String>{
            String.valueOf(txn.Id) => 'TRX-001:PROFILE-001'
        };
        PassfortTransactionProcessSRHelper.updateResponseOnTransactionRecord(responseMap, trIdMap);

        Registration__c reg = [SELECT Id FROM Registration__c LIMIT 1];
        Map<String, String> regMap = new Map<String, String>{
            String.valueOf(reg.Id) => 'REG-PROFILE-001'
        };
        PassfortTransactionProcessSRHelper.updateRegistrationRecords(regMap);
        Test.stopTest();

        Prospect_Account__c updatedPa = [
            SELECT Id, ProfileId__c, PassfortComment__c
            FROM Prospect_Account__c
            WHERE Id = :pa.Id
        ];
        System.assertEquals('PROFILE-123', updatedPa.ProfileId__c);

        PassfortTransaction__c updatedTxn = [
            SELECT Id, Response__c, ProfileId__c
            FROM PassfortTransaction__c
            WHERE Id = :txn.Id
        ];

        Registration__c updatedReg = [
            SELECT Id, ProfileId__c
            FROM Registration__c
            WHERE Id = :reg.Id
        ];
    }
}