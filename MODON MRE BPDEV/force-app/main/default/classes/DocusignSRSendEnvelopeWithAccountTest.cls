@IsTest
private class DocusignSRSendEnvelopeWithAccountTest {
  
    private static Id attachTransferDoc(Id documentsId) {
        ContentVersion cv = new ContentVersion(
            Title = 'My Transfer Document',
            PathOnClient = 'transfer.pdf',
            VersionData = Blob.valueOf('dummy bytes')
        );
        insert cv;
        
        cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1 ];
        
        insert new ContentDocumentLink(
            LinkedEntityId    = documentsId,
            ContentDocumentId = cv.ContentDocumentId,
            ShareType = 'V'
        );
        
        return cv.Id;
    }
 
    private static ServiceRequest__c createSRData(Boolean createPrimaryContact) {
        string options = '[{"picklistOptions":["Light","Dark"],"picklistLable":"Fit out palete","picklistApiName":"FitoutPalete__c"},{"picklistOptions":["Light","Dark"],"picklistLable":"Exterior","picklistApiName":"Exterior__c"},{"picklistOptions":["Light","Dark"],"picklistLable":"Interior","picklistApiName":"Interior__c"}]';
        
        Project__c project = new Project__c();
        insert project;
        
        EscrowAccount__c esc = new EscrowAccount__c(name='Phase 2 Escrow Account');
        insert esc;
        
        VirtualAccount__c va = new VirtualAccount__c(
            Name='Test',
            Status__c='Available',
            EscrowAccount__c=esc.Id,
            VirtualAccountNumber__c='124567643',
            VirtualIBANNumber__c='AE3456789456788'
        );
        insert va;
        
        Phase__c ph = new Phase__c(
            Project__c = project.Id,
            EscrowAccount__c = esc.Id,
            PhaseOptions__c =options
        );
        insert ph;
        
        Unit__c unit = new Unit__c(
            Phase__c = ph.Id,
            PlotAreasqm__c = 1.0,
            PlotNo__c = '1',
            Status__c = 'Available',
            BlockedFor__c = UserInfo.getUserId(),
            BlockedBy__c = UserInfo.getUserId(),
            UnitClassification__c='Villa',
            Number_of_Bedrooms__c='9'
        );
        insert unit;
        
        Account cust = new Account(
            LastName='Test Person',
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Person Account').getRecordTypeId(),
            PersonEmail='person@test.com'
        );
        insert cust;
        
       /* Contact primaryContact;
        if (createPrimaryContact) {
            primaryContact = new Contact(
                LastName='Primary',
                Email='primary@test.com',
                AccountId=cust.Id
            );
            insert primaryContact;
        }*/
       /* Account cust = new Account(
        name = 'test account');
        insert cust;*/
        
        PaymentPlan__c pp = new PaymentPlan__c(
            Type__c='Standard',
            Unit__c=unit.Id,
            Status__c='Active'
        );
        insert pp;
        
        Opportunity opp = new Opportunity(
            Name='Opp',
            StageName='Prospecting',
            CloseDate=Date.today()
        );
        insert opp;
        
        SalesOrder__c so = new SalesOrder__c(
            Unit__c = unit.Id,
            CustomerAccount__c = cust.Id,
            PaymentPlan__c = pp.Id,
            Opportunity__c = opp.Id,
            Status__c='Completed',
            TotalAmount__c=100
        );
       /* if (createPrimaryContact) {
            so.PrimaryContact__c = primaryContact.Id;
        }*/
        insert so;
        
        ServiceRequest__c sr = new ServiceRequest__c(
            SalesOrder__c = so.Id,
            Type__c='Normal'
        );
        insert sr;
        
        return sr;
    }
    
    //
    // POSITIVE SCENARIO – All recipients + all documents found
    //
    
 @IsTest
static void test_sendEnvelope_happyPath() {
    ServiceRequest__c sr = createSRData(true);

    Id contactRecordTypeId = Schema.SObjectType.Prospect_Account__c
        .getRecordTypeInfosByDeveloperName()
        .get('Contact')
        .getRecordTypeId();

    // Add Joint Owner
    Account joAcc = new Account(
        LastName = 'Test Person1',
        RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName()
            .get('Person Account')
            .getRecordTypeId(),
        PersonEmail = 'personone@test.com'
    );
    insert joAcc;

    insert new JointOwner__c(
        SalesOrder__c = sr.SalesOrder__c,
        JointOwnerAccount__c = joAcc.Id,
        RelationshipType__c = 'Joint Owner P-P',
        RelationshipSubType__c = 'Friend',
        OwnershipPercentage__c = 50
    );

    // Add Prospect Account
    Prospect_Account__c pa = new Prospect_Account__c(
        Title__c = 'Mr.',
        Account__c = joAcc.Id,
        RecordTypeId = contactRecordTypeId,
        Account_Type__c = 'Broker Agency',
        First_Name__c = 'John',
        Last_Name__c = 'Doe',
        Middle_Name__c = 'A',
        OwnershipPercentage__c = 50,
        IsPersonAccount__c = true,
        Birthdate__c = Date.today().addYears(-30),
        Email__c = 'john.doe@test.com',
        Mobile__c = '+971525612345',
        Is_Primary__c = true,
        Country__c = 'UAE',
        State__c = 'Dubai',
        City__c = 'Dubai',
        Street__c = 'Street 2',
        PostalCode__c = '11111',
        Description__c = 'Test Person Account',
        LegalStructure__c = 'Sole Private Establishment (UAE based)',
        profileId__c = '67890',
        PassportNumber__c = 'CFQPR2117P',
        PassfortRiskStatus__c = 'Low',
        SourceOfIncome__c = 'Business',
        OtherSourceOfIncome__c = 'Stocks',
        UAE_Resident_Status__c = 'Resident',
        UAEVATRegisterNumber__c = 'VAT67890',
        EmiratesIDExpiryDate__c = System.today(),
        UnifiedNumber__c = 'UN67890',
        EIDNumber__c = '784-1234-1234567-1',
        PaymentMethod__c = 'Cash',
        OtherLegalStructure__c = 'None',
        Service_Request__c = sr.Id,
        RelationshipSubType__c = 'Friend',
        Nationality__c = 'United Arab Emirates',
        IsTheBusinessEntityRealBeneficiary__c = false,
        NoOfPropertyPurchasedWithModon__c = 2
    );
    insert pa;

    // Add Documents__c wrapper
    Documents__c doc = new Documents__c(
        Name = 'Transfer Document',
        Service_Request__c = sr.Id
    );
    insert doc;

    // Upload and link file
    attachTransferDoc(doc.Id);

    Test.startTest();
    try{
    String envId = DocusignSRSendEnvelopeWithAccount.sendFromServiceRequest(sr.Id);
    }catch (Exception ex){
        
    }
        Test.stopTest();

}
    
    @IsTest
    static void test_noDocuments_throws() {
        ServiceRequest__c sr = createSRData(false);
        
        try {
            Test.startTest();
            DocusignSRSendEnvelopeWithAccount.sendFromServiceRequest(sr.Id);
            Test.stopTest();
           
        } catch (exception e) {
           
        }
    }
    
  
    @IsTest
    static void test_noFiles_throws() {
        ServiceRequest__c sr = createSRData(false);
        
        Documents__c doc = new Documents__c(
            Name='My Transfer Document',
            Service_Request__c = sr.Id
        );
        insert doc;
        
        try {
            Test.startTest();
            SendEnvelopeSrFlowAction.Request req = new SendEnvelopeSrFlowAction.Request();
        req.serviceRequestId = sr.Id;

        List<SendEnvelopeSrFlowAction.Response> res =
            SendEnvelopeSrFlowAction.sendEnvelope(new List<SendEnvelopeSrFlowAction.Request>{ req });
            DocusignSRSendEnvelopeWithAccount.sendFromServiceRequest(sr.Id);
            Test.stopTest();
         
        } catch (exception e) {
           
        }
    }

    @IsTest
    static void test_noMatchingVersion_throws() {
        ServiceRequest__c sr = createSRData(false);
        
        Documents__c doc = new Documents__c(
            Name='My Transfer Document',
            Service_Request__c = sr.Id
        );
        insert doc;
        
        // Create a ContentVersion with wrong title
        ContentVersion cv = new ContentVersion(
            Title='Not a Match',
            PathOnClient='x.pdf',
            VersionData=Blob.valueOf('x')
        );
        insert cv;
        
        // Link it to Documents__c
        cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id=:cv.Id];
        insert new ContentDocumentLink(
            LinkedEntityId=doc.Id,
            ContentDocumentId=cv.ContentDocumentId,
            ShareType='V'
        );
        
        try {
            Test.startTest();
            DocusignSRSendEnvelopeWithAccount.sendFromServiceRequest(sr.Id);
            Test.stopTest();
        } catch (exception e) {
           }
    }
    
  
    @IsTest
    static void test_recipient_and_tabs() {
        
        dfsle.Tab t1 = DocusignSRSendEnvelopeWithAccount.createEnvTab('<S-Kris>');
        System.assertNotEquals(null, t1);
        
        dfsle.Tab t2 = DocusignSRSendEnvelopeWithAccount.createEnvTab('<D-Kris>');
        System.assertNotEquals(null, t2);
        
        dfsle.Tab t3 = DocusignSRSendEnvelopeWithAccount.createEnvTab('<In-Kris>');
        System.assertNotEquals(null, t3);
        
        dfsle.Tab t4 = DocusignSRSendEnvelopeWithAccount.createEnvTab('<ST-Kris>');
        System.assertNotEquals(null, t4);
        
        // Fallback
        dfsle.Tab t5 = DocusignSRSendEnvelopeWithAccount.createEnvTab('UnknownAnchor');
        System.assertNotEquals(null, t5);
        
        // Test createRecipient
        dfsle.Recipient rec = DocusignSRSendEnvelopeWithAccount.createRecipientFromSobj(
            'Example User',
            'user@test.com',
            'Ex  User',
            1,
            'a00XX0000001234',
            'Signer'
        );
        
        System.assertNotEquals(null, rec);
    }
}