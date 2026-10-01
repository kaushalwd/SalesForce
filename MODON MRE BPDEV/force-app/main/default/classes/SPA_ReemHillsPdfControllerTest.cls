@isTest
private class SPA_ReemHillsPdfControllerTest {
    @isTest
    static void testPDFController() {
        
        project__c testProject = new Project__c (
        name = 'Al Naseem');
        insert testProject;
        
        phase__c testPhase = new phase__c(
        Project__c = testProject.Id
        );
		insert testPhase;
        
        // TO DO: implement unit test
        Account act= new Account();
        act.Name='Test Account';
        act.LegalStructure__c='Sole Private Establishment (UAE based)';
        act.DateOfEstablishment__c=date.newinstance(2000, 2, 17);
        act.UnifiedNumber__c='12357';
        act.TradeLicenseExpiryDate__c=date.newinstance(2040, 2, 17);
        act.UAEVATRegisterNumber__c='123456';
        act.PurposeOfTransaction__c='Flat booking';
        act.PaymentMethod__c='Cash';
        act.PurposeOfTransaction__c='House rent';
        act.Phone='+97154799866';
        //act.AreYouPoliticallyExposedPersonPEP__pc=true;
        act.SourceOfIncome__c='Salary';
        act.IsTheBusinessEntityRealBeneficiary__c=true;
        act.DeliveryChannel__c='Direct Sales Partner';
        act.NoOfPropertyPurchasedWithModon__c=2;
        act.Description='test Description';
        
        Account personAccount = new Account();
        personAccount.RecordTypeId= Schema.getGlobalDescribe().get('Account').getDescribe().getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();
        personAccount.FirstName = 'Test';
        personAccount.LastName = 'PersonAccount';
        personAccount.PersonBirthdate=Date.newinstance(2000, 2, 17);
        personAccount.Nationality__pc='India';
        personAccount.UAE_Resident_Status__pc='Resident';
        personAccount.IdentityProof__pc='Emirates Id';
        personAccount.EIDNumber__pc='123456';
        personAccount.PersonMobilePhone='+97154799866';
        personAccount.Occupation__pc='Teacher';
        personAccount.EmployerBusinessName__pc='PwC';
        personAccount.PaymentMethod__pc='Cash';
        personAccount.PurposeOfTransaction__pc='House rent';
        personAccount.PersonEmail='abc@pwc.com';
        personAccount.AreYouPoliticallyExposedPersonPEP__pc=true;
        personAccount.SourceOfIncome__pc='Salary';
        personAccount.DeliveryChannel__pc='Face to face interaction';
        personAccount.NoOfPropertyPurchasedWithModon__pc=2;

        List<Account> lstAccount = new List<Account>();
		lstAccount.add(act);
		lstAccount.add(personAccount);        
        insert lstAccount;
        
        Receipt__c recObj = new Receipt__c();
        recObj.Account__c = lstAccount[0].Id;
        insert recObj;
        
        Contact con= new Contact();
        con.FirstName='Test';
        con.LastName='Test Contact';
        con.AccountId=lstAccount[0].id;
        con.Birthdate=Date.newinstance(2000, 2, 17);
        con.Nationality__c='India';
        con.UAE_Resident_Status__c='Resident';
        con.IdentityProof__c='Emirates Id';
        con.EIDNumber__c='123456';
        con.MobilePhone='+97154799866';
        con.Occupation__c='Teacher';
        con.EmployerBusinessName__c='PwC';
        con.PaymentMethod__c='Cash';
        con.PurposeOfTransaction__c='House rent';
        con.Email='abc@pwc.com';
        con.AreYouPoliticallyExposedPersonPEP__c=true;
        con.SourceOfIncome__c='Salary';
        con.DeliveryChannel__c='Direct Sales Partner';
        con.NoOfPropertyPurchasedWithModon__c=2;
        insert con;

        Opportunity opp= new Opportunity();
        opp.Name='Test Opportunity';
        opp.CloseDate=Date.today();
        opp.StageName='Closed Won';
        opp.AccountId=lstAccount[0].Id;
        opp.PrimaryContact__c=con.Id;
        
        Opportunity opp2= new Opportunity();
        opp2.Name='Test Opportunity2';
        opp2.CloseDate=Date.today();
        opp2.StageName='Closed Won';
        opp2.AccountId=lstAccount[1].Id;
        opp2.PrimaryContact__c=personAccount.PersonContactId;
        
        List<Opportunity> lstOpp= new List<Opportunity>();
        lstOpp.add(opp);
        lstOpp.add(opp2);        
        insert lstOpp;
        
        Unit__c testUnit = new Unit__c(
            Name = 'Test Unit',
            PlotNo__c = '1',
            phase__c = testPhase.Id,
            Internal_Area__c = 200,
            BalconyArea__c = 300,
            PlotAreasqm__c = 500,
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '3'
        );
        insert testUnit;
        
        PaymentPlan__c paymentPlan = new PaymentPlan__c();
        paymentPlan.Name = 'On Completion';
        paymentPlan.Type__c = 'Standard';
        paymentplan.Unit__c = testUnit.Id;
        insert paymentPlan;
        
        PaymentInstallements__c installment = new PaymentInstallements__c();
        
        installment.PaymentInstallment__c = paymentPlan.Id;
        installment.BrokerPayout__c = 10;
        installment.Milestone__c = 10;
        installment.MilestoneNumber__c = 1;
        installment.MilestoneDescription__c = 'test';
        
        INSERT installment;
                
        SalesOrder__c salesOrder1 = new SalesOrder__c();
        salesOrder1.CustomerAccount__c=lstAccount[0].Id;
        salesOrder1.PrimaryContact__c=con.Id;
        salesOrder1.Unit__c = testUnit.Id;
        salesOrder1.TotalAmount__c = 10000;
        salesOrder1.PaymentPlan__c = paymentPlan.id;
        
        SalesOrder__c salesOrder2 = new SalesOrder__c();
        salesOrder2.CustomerAccount__c=lstAccount[1].Id;
        salesOrder2.PrimaryContact__c=lstAccount[1].PersonContactId;
        
        List<SalesOrder__c> lstSalesOrder= new List<SalesOrder__c>();
        lstSalesOrder.add(salesOrder1);
        lstSalesOrder.add(salesOrder2);        
        insert lstSalesOrder;
        
        
		JointOwner__c jointOwner= new JointOwner__c();
		jointOwner.OwnershipPercentage__c=50;
        jointOwner.RelationshipType__c='Joint Owner P-P';
        jointOwner.RelationshipSubType__c='Broker';
        jointOwner.JointOwnerAccount__c=lstAccount[0].Id;
        jointOwner.Opportunity__c=lstOpp[0].Id;
        
        JointOwner__c jointOwner1= new JointOwner__c();
		jointOwner1.OwnershipPercentage__c=20;
        jointOwner1.RelationshipType__c='Joint Owner P-P';
        jointOwner1.RelationshipSubType__c='Broker';
        jointOwner1.JointOwnerAccount__c=lstAccount[0].Id;
        jointOwner1.SalesOrder__c=lstSalesOrder[0].Id;
        
        List<JointOwner__c> lstJointOwner= new List<JointOwner__c>();
        lstJointOwner.add(jointOwner);
        lstJointOwner.add(jointOwner1);
        insert lstJointOwner;
        
        Contact shareholder1 = new Contact();
        shareholder1.FirstName='Test';
        shareholder1.LastName='Shareholder 1';
        shareholder1.AccountId=act.Id;
        shareholder1.OwnershipPercentage__c=50;
        shareholder1.Birthdate=Date.newinstance(2000, 2, 17);
        shareholder1.Nationality__c='Iran';
        //shareholder1.PassfortApprovalStatus__c='In review';
        shareholder1.RecordTypeId=Schema.SObjectType.Contact.getRecordTypeInfosByName().get('Shareholder').getRecordTypeId();
        
        Contact shareholder2 = new Contact();
        shareholder2.FirstName='Test';
        shareholder2.LastName='Shareholder 2';
        shareholder2.OwnershipPercentage__c=20;
        shareholder2.Birthdate=Date.newinstance(2000, 2, 14);
        shareholder2.AccountId=act.Id;
        shareholder2.Nationality__c='India';
        shareholder2.RecordTypeId=Schema.SObjectType.Contact.getRecordTypeInfosByName().get('Shareholder').getRecordTypeId();
        
        List<Contact> lstShareholder = new List<Contact>();
        lstShareholder.add(shareholder1);
        lstShareholder.add(shareholder2);
        insert lstShareholder;
        
        ContentVersion cv = new ContentVersion();
        cv.Title='TestPassportDocument';
        cv.PathOnClient='TestPassportDocument.jpg';
        cv.VersionData= Blob.valueOf('test Passport component');
        cv.IsMajorVersion=true;
        
        ContentVersion cv1 = new ContentVersion();
        cv1.Title='TestCompanyDocument1';
        cv1.PathOnClient='TestCompanyDocument1.pdf';
        cv1.VersionData= Blob.valueOf('test TestCompanyDocument1 component');
        cv1.IsMajorVersion=true;

        List<ContentVersion> lstContentVersion = new List<ContentVersion>();
        lstContentVersion.add(cv);
        lstContentVersion.add(cv1);
        insert lstContentVersion;
        
        List<ContentDocument> documents = [SELECT Id, Title, LatestPublishedVersionId FROM ContentDocument WHERE LatestPublishedVersionId = :lstContentVersion[0].Id LIMIT 1];
        ContentDocumentLink testContentDocumentLink = new ContentDocumentLink(
            ContentDocumentId = documents[0].Id,
            LinkedEntityId = lstSalesOrder[0].Unit__c,
            ShareType = 'V'
        );
        insert testContentDocumentLink;
        
        
        
        // Test PDFController constructor
        ApexPages.StandardController sc = new ApexPages.StandardController(lstSalesOrder[0]);
        ApexPages.currentPage().getParameters().put('id', lstSalesOrder[0].Id);
        ApexPages.currentPage().getParameters().put('recordId', lstSalesOrder[0].Id);
        ApexPages.currentPage().getParameters().put('pdfData', 'PDF Content');
        
        Test.startTest();
        SPA_ReemHillsPdfController reemPdfController = new SPA_ReemHillsPdfController(sc);
        String base64PdfData = EncodingUtil.base64Encode(Blob.valueOf('PDF Content'));
        
        Test.stopTest();
        
        
        
        // Assertions for the constructor
        System.assertNotEquals(null, reemPdfController, 'reemPdfController should be instantiated');
        System.assertEquals(true, reemPdfController.FloorPlanAvailable, 'FloorPlanAvailable should be true');

        
        // Verify attachment creation
        List<Attachment> attachments = [SELECT Id, Name, ParentId FROM Attachment WHERE ParentId = :lstSalesOrder[0].Id];
        //System.assertEquals(true, attachments.size() > 0, 'Attachment should be created');
        //System.assertEquals('SPA.pdf', attachments[0].Name, 'Attachment name should be SPA.pdf');
    }
    
    @isTest
    static void testPDFController_Constructor_NoFloorPlans() {
        // Create a Sales Order with no related units
        SalesOrder__c testSalesOrder = new SalesOrder__c(
            Unit__c = null
        );
        insert testSalesOrder;
        
        // Test PDFController constructor
        ApexPages.StandardController sc = new ApexPages.StandardController(testSalesOrder);
        ApexPages.currentPage().getParameters().put('id', testSalesOrder.Id);
        ApexPages.currentPage().getParameters().put('recordId', testSalesOrder.Id);
        ApexPages.currentPage().getParameters().put('pdfData', 'PDF Content');
        
        Test.startTest();
        SPA_ReemHillsPdfController reemPdfController = new SPA_ReemHillsPdfController(sc);
        Test.stopTest();
        
        // Assertions for the constructor
        System.assertNotEquals(null, reemPdfController, 'reemPdfController should be instantiated');
        System.assertEquals(false, reemPdfController.FloorPlanAvailable, 'FloorPlanAvailable should be false');
    }
    
    // Helper method to create test Unit
    private static Unit__c createTestUnit() {
        Unit__c testUnit = new Unit__c(
            Name = 'Test Unit',
            PlotNo__c = '1',
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '3'
        );
        insert testUnit;
        return testUnit;
    }
}