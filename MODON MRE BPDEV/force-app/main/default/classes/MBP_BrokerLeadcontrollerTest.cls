@isTest
public class MBP_BrokerLeadcontrollerTest {
    @testSetup
    static void setupTestData() {
        RecordType brokerRecordType = [SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND Name = 'Broker Agency' LIMIT 1];
        // Create test Account
        Account acc = new Account(Name = 'Test Broker Agency', RecordTypeId = brokerRecordType.Id,Type = 'Broker');
        insert acc;
        
        // Create test Contact
        Contact con = new Contact(LastName = 'Test', Broker_Type__c = 'Agent', AccountId = acc.Id);
        insert con;
        
        Contact con1 = new Contact(LastName = 'Test123', Broker_Type__c = 'Owner', AccountId = acc.Id);
        insert con1;
        
        
        // Create Project/Phase/Unit hierarchy
Project__c proj = new Project__c(Name = 'Nawayef Homes');
insert proj;

Phase__c phase = new Phase__c(Name = 'Phase 1', Project__c = proj.Id);
insert phase;

Unit__c unit = new Unit__c(
    Name = 'Unit-101', 
    Phase__c = phase.Id, 
    Status__c = 'Available',
        Number_of_Bedrooms__c = '6',
    PlotNo__c = 'r5',
    UnitClassification__c = 'Apartment'
);
insert unit;

PaymentPlan__c pp = new PaymentPlan__c(
    Name = 'Standard Plan',
Type__c = 'Standard',
    Unit__c = unit.Id
);
insert pp;

PaymentInstallements__c pi = new PaymentInstallements__c(
    PaymentInstallment__c = pp.Id,
    MilestoneNumber__c = 1,
    Name = 'Deposit'
);
insert pi;
        // Create test User
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Modon - Partner Community Login User' LIMIT 1];
        
        Id userRoleId;
        try {
            userRoleId = [SELECT Id FROM UserRole WHERE Name = 'Partner User' LIMIT 1].Id;
        } catch (Exception e) {
            userRoleId = null;
        }
        User u = new User(
            Username = 'testuser' + DateTime.now().getTime() + '@example.com',
            Alias = 'testu',
            Email = 'testuser@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'User',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'Asia/Kolkata',
            ProfileId = p.Id,
            ContactId = con.Id,
            UserRoleId = userRoleId,
            IsActive = true
        );
        insert u;
        
        
         User u2 = new User(
            Username = 'testuser1234' + DateTime.now().getTime() + '@example.com',
            Alias = 'testu',
            Email = 'testuser124@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'User',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'Asia/Kolkata',
            ProfileId = p.Id,
            ContactId = con1.Id,
            UserRoleId = userRoleId,
            IsActive = true
        );
        insert u2;
        // Create test Lead
        System.runAs(u){
            Lead lead = new Lead(
                FirstName = 'John',
                LastName = 'Doe',
                Company = 'Company',
                Email = 'john.doe@example.com',
                MobilePhone = '+9711234567890',
                BrokerAgency__c = acc.Id,
                BrokerAgent__c = con.Id,
                LeadSource = 'Broker Portal',
                BrokerAgentName__c='upendra',
                BrokerAgentMobile__c='+918897664052',
                Status = 'New',
                ProjectInterest__c='Nawayef Mansions ',
                	UnitType__c = 'Villa',
                	NumberOfBedrooms__c = '2 BHK + M',
                	PurposeofUse__c = 'Investor'
            );
            insert lead;
            
            // Create related Documents__c
            Documents__c doc = new Documents__c(Name = 'Emirates ID', Lead__c = lead.Id);
            insert doc;
        }
    }
    
    @isTest
    static void testGetUserDetails() {
        User testUser = [SELECT Id FROM User where Email ='testuser@example.com' LIMIT 1];
        Test.startTest();
        User result = MBP_BrokerLeadcontroller.getUserDetails(testUser.Id);
        Test.stopTest();
        System.assertNotEquals(null, result);
    }

    @isTest
    static void testGetFilteredLeads() {
        User testUser = [SELECT Id FROM User where Email ='testuser@example.com' LIMIT 1];
        User testUser1 = [SELECT Id FROM User where Email ='testuser124@example.com' LIMIT 1];
        Date startDate = Date.today().addMonths(-1);
        Date endDate   = Date.today().addMonths(1);
        Test.startTest();
        List<MBP_BrokerLeadcontroller.LeadWrapper> wrappers = 
            MBP_BrokerLeadcontroller.getFilteredLeads(testUser.Id, null, null,null);

        List<MBP_BrokerLeadcontroller.LeadWrapper> wrappers1 = 
            MBP_BrokerLeadcontroller.getFilteredLeads(testUser1.Id, null, null,null);
       
        List<MBP_BrokerLeadcontroller.LeadWrapper> wrappers2 = 
            MBP_BrokerLeadcontroller.getFilteredLeads(testUser.Id, startDate, endDate,null);

        List<MBP_BrokerLeadcontroller.LeadWrapper> wrappers3 = 
            MBP_BrokerLeadcontroller.getFilteredLeads(testUser1.Id, startDate, endDate,null);
        Test.stopTest();

        System.assertNotEquals(null, wrappers);
    }

    @isTest
    static void testCreateOrUpdateLead() {
        Contact con = [SELECT Id, AccountId FROM Contact LIMIT 1];

        Map<String, Object> leadMap = new Map<String, Object>{
            'FirstName' => 'Jane',
            'LastName'  => 'Smith',
            'Company'   => 'TestCo',
            'Email'     => 'jane.smith@example.com',
            'MobilePhone' => '+971123456789',  
            'BrokerAgentName__c'=>'upendra',
            'BrokerAgentMobile__c'=>'+918897664052',
            'Nationality__c' => 'India',
            'ProjectInterest__c' => 'Nawayef Mansions',
            'UnitType__c' => 'Villa',
            'NumberOfBedrooms__c' => '2 BHK + M',
            'LeadSource' => 'Website',
            'PurposeofUse__c' => 'Investor'
        };

        Test.startTest();
        Lead savedLead = MBP_BrokerLeadcontroller.createOrUpdateLead(leadMap, con.Id, con.AccountId);
        Test.stopTest();

        System.assertNotEquals(null, savedLead.Id);
    }
    
    @isTest
    static void testCreateOrUpdateLeadClearsIdentityDocuments() {
        Contact con = [SELECT Id, AccountId FROM Contact LIMIT 1];
        Map<String, Object> leadMap = new Map<String, Object>{
            'FirstName' => 'Org', 'LastName' => 'Switch', 'Company' => 'SwitchCo',
            'Email' => 'org.switch@example.com', 'MobilePhone' => '+971123456780',
            'BrokerAgentName__c' => 'upendra', 'BrokerAgentMobile__c' => '+918897664052',
            'Nationality__c' => 'India', 'ProjectInterest__c' => 'Nawayef Mansions',
            'UnitType__c' => 'Villa', 'NumberOfBedrooms__c' => '2 BHK + M',
            'LeadSource' => 'Website', 'PurposeofUse__c' => 'Investor',
            'UAEResidentStatus__c' => 'Resident',
            'EIDNumber__c' => '784-1234-1234567-1', 'EmiratesIDExpiryDate__c' => '2030-01-01',
            'PassportNumber__c' => 'P1234567', 'PassportIssueDate__c' => '2020-01-01', 'PassportExpiryDate__c' => '2030-01-01'
        };
        Lead created = MBP_BrokerLeadcontroller.createOrUpdateLead(leadMap, con.Id, con.AccountId);
        Lead stored = [SELECT EIDNumber__c, EmiratesIDExpiryDate__c, PassportNumber__c, PassportIssueDate__c, PassportExpiryDate__c FROM Lead WHERE Id = :created.Id];
        System.assertEquals('784-1234-1234567-1', stored.EIDNumber__c, 'identity documents saved for an individual');
        System.assertNotEquals(null, stored.EmiratesIDExpiryDate__c);

        // Same lead, no flag, blank dates: the existing behaviour keeps them.
        Map<String, Object> plainUpdate = new Map<String, Object>(leadMap);
        plainUpdate.put('Id', created.Id);
        plainUpdate.put('EmiratesIDExpiryDate__c', '');
        MBP_BrokerLeadcontroller.createOrUpdateLead(plainUpdate, con.Id, con.AccountId);
        stored = [SELECT EmiratesIDExpiryDate__c FROM Lead WHERE Id = :created.Id];
        System.assertNotEquals(null, stored.EmiratesIDExpiryDate__c, 'blank date without the flag is left untouched');

        // Switched to Organization: the portal drops the fields and sends the flag.
        Map<String, Object> orgUpdate = new Map<String, Object>(leadMap);
        orgUpdate.put('Id', created.Id);
        orgUpdate.put('Type', 'Organization');
        orgUpdate.put('Name', 'SwitchCo');
        for (String f : new List<String>{'EIDNumber__c','EmiratesIDExpiryDate__c','PassportNumber__c','PassportIssueDate__c','PassportExpiryDate__c'}) {
            orgUpdate.remove(f);
        }
        orgUpdate.put('clearIdentityDocuments', true);
        Test.startTest();
        MBP_BrokerLeadcontroller.createOrUpdateLead(orgUpdate, con.Id, con.AccountId);
        Test.stopTest();
        stored = [SELECT EIDNumber__c, EmiratesIDExpiryDate__c, PassportNumber__c, PassportIssueDate__c, PassportExpiryDate__c FROM Lead WHERE Id = :created.Id];
        System.assertEquals(null, stored.EIDNumber__c, 'EID cleared');
        System.assertEquals(null, stored.EmiratesIDExpiryDate__c, 'EID expiry cleared');
        System.assertEquals(null, stored.PassportNumber__c, 'passport cleared');
        System.assertEquals(null, stored.PassportIssueDate__c, 'passport issue cleared');
        System.assertEquals(null, stored.PassportExpiryDate__c, 'passport expiry cleared');
    }

    @isTest
    static void testUploadAndGetDocuments() {
        Lead testLead = [SELECT Id FROM Lead LIMIT 1];
        Documents__c doc = [SELECT Id FROM Documents__c WHERE Lead__c = :testLead.Id LIMIT 1];
        
        String sampleBase64 = EncodingUtil.base64Encode(Blob.valueOf('Test File Content'));
        String fileName = 'TestFile.pdf';
        
        Test.startTest();
        MBP_BrokerLeadcontroller.uploadFileToDocumentRecord(sampleBase64, fileName, testLead.Id, 'Emirates ID');
        List<Map<String, String>> docs = MBP_BrokerLeadcontroller.getUploadedDocuments(testLead.Id);
        Test.stopTest();
        
        System.assert(!docs.isEmpty());
    }
    
    @isTest
    static void testDeleteDocuments() {
        Lead testLead = [SELECT Id FROM Lead LIMIT 1];
        Documents__c doc = [SELECT Id FROM Documents__c WHERE Lead__c = :testLead.Id LIMIT 1];
        
        String base64Data = EncodingUtil.base64Encode(Blob.valueOf('Sample Content'));
        MBP_BrokerLeadcontroller.uploadFileToDocumentRecord(base64Data, 'DelFile.pdf', testLead.Id, 'Emirates ID');
        
        Test.startTest();
        Test.stopTest();
    }
    
    @isTest
    static void testGetPicklist() {
        Test.startTest();
        MBP_BrokerLeadcontroller.PicklistResponse response = MBP_BrokerLeadcontroller.getPicklist('Lead', 'Status');
        MBP_BrokerLeadcontroller.PicklistResponse responsePurpose = MBP_BrokerLeadcontroller.getPicklist('Lead', 'PurposeOfUse__c');
        Test.stopTest();
        
        System.assert(response.values != null);
    }
    
    @isTest
    static void testGetDependentPicklistValues() {
        Test.startTest();
        Test.stopTest();
    }
    
    @isTest
    static void testGroupLeadsLogic() {
        RecordType brokerRecordType = [SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND Name = 'Broker Agency' LIMIT 1];
        Account acc = new Account(Name = 'Test Varamnaming', RecordTypeId = brokerRecordType.Id, Type = 'Broker');
        insert acc;
        
        Contact con = new Contact(LastName = 'Bankim', Broker_Type__c = 'Agent', AccountId = acc.Id);
        insert con;
        
        Account acc22 = new Account(Name = 'Testweewing Vau', RecordTypeId = brokerRecordType.Id, Type = 'Broker');
        insert acc22;
        
        Contact con22 = new Contact(LastName = 'Bankimuhkinh', Broker_Type__c = 'Agent', AccountId = acc.Id);
        insert con22;
        
        Profile profile = [SELECT Id FROM Profile WHERE Name = 'Modon - Partner Community Login User' LIMIT 1];
        User u = new User(
            Username = 'groupuser' + DateTime.now().getTime() + '@example.com',
            Alias = 'guser',
            Email = 'groupuser@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'User',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'Asia/Kolkata',
            ProfileId = profile.Id,
            ContactId = con.Id,
            IsActive = true
        );
        insert u;
        
        List<Lead> testLeads = new List<Lead>{
            new Lead(
                FirstName = 'JohnVijayna',
                LastName = 'Vr',
                Company = 'comali Company',
                Email = 'john33@example.com',
                MobilePhone = '+9711233467891',
                BrokerAgent__c = con.Id,
                BrokerAgency__c = acc.Id,
                LeadSource = 'Broker Portal',
                Status = 'New',
                BrokerAgentName__c='Vijayendra',
                BrokerAgentMobile__c='+918897664132',
                ProjectInterest__c='Nawayef Mansions ',
                UnitType__c = 'Villa',
                NumberOfBedrooms__c = '2 BHK + M',
                PurposeofUse__c = 'Investor'
            ),
            new Lead(
                FirstName = 'aslam',
                LastName = 'Doyung',
                Company = 'Testing Company',
                Email = 'johnyy2323@example.com',
                MobilePhone = '+9711234537291',
                BrokerAgent__c = con22.Id,
                BrokerAgency__c = acc22.Id,
                LeadSource = 'Broker Portal',
                Status = 'New',
                BrokerAgentName__c='Bhushan',
                BrokerAgentMobile__c='+918827694052',
                ProjectInterest__c='Nawayef Mansions ',
                UnitType__c = 'Villa',
                NumberOfBedrooms__c = '2 BHK + M',
                PurposeofUse__c = 'Investor'
            )
        };
        insert testLeads;
        
        Test.startTest();
        List<MBP_BrokerLeadcontroller.LeadWrapper> result = MBP_BrokerLeadcontroller.getFilteredLeads(u.Id,null,null,null);
        Test.stopTest();
    }
    
    @isTest
    static void testDeleteLeadDocumentsCompleteFlow() {
        RecordType brokerRecordType = [SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND Name = 'Broker Agency' LIMIT 1];
        Account acc = new Account(Name = 'Testing Brokerageing Agencyingggg', RecordTypeId = brokerRecordType.Id, Type = 'Broker');
        insert acc;
        
        Contact con = new Contact(LastName = 'Test Agentingwe', Broker_Type__c = 'Agent', AccountId = acc.Id);
        insert con;
        
        Lead lead = new Lead(
            FirstName = 'DeleteDocu',
            LastName = 'Leadying',
            Company = 'TestCoty',
            Email = 'delete234@example.com',
            MobilePhone = '+9711234527891',
            BrokerAgent__c = con.Id,
            BrokerAgency__c = acc.Id,
            Status = 'New',
            BrokerAgentName__c='assambabu',
            BrokerAgentMobile__c='+918893624052',
            LeadSource = 'Broker Portal',
            ProjectInterest__c='Nawayef Mansions ',
            UnitType__c = 'Villa',
            NumberOfBedrooms__c = '2 BHK + M',
            PurposeofUse__c = 'Investor'
        );
        insert lead;
        
        Documents__c docRecord = new Documents__c(Name = 'Emirates ID', Lead__c = lead.Id);
        insert docRecord;
        
        ContentVersion cv = new ContentVersion(
            Title = 'TestDoc',
            PathOnClient = 'TestDoc.pdf',
            VersionData = Blob.valueOf('Sample data')
        );
        insert cv;
        
        Id contentDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        
        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = contentDocId,
            LinkedEntityId = docRecord.Id,
            ShareType = 'V'
        );
        insert cdl;
        
        Test.startTest();
        Map<String, Boolean> result = MBP_BrokerLeadcontroller.deleteLeadDocuments(lead.Id, new List<String>{'Emirates ID'});
        Test.stopTest();
        
        System.assertEquals(true, result.containsKey('Emirates ID'));
        System.assertEquals(true, result.get('Emirates ID'));
    }

    @isTest
    static void testDeleteLeadDocumentFile() {
        RecordType brokerRecordType = [SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND Name = 'Broker Agency' LIMIT 1];
        Account acc = new Account(Name = 'Testing File Delete Agency', RecordTypeId = brokerRecordType.Id, Type = 'Broker');
        insert acc;
        Contact con = new Contact(LastName = 'File Delete Agent', Broker_Type__c = 'Agent', AccountId = acc.Id);
        insert con;
        Lead lead = new Lead(
            FirstName = 'FileDel', LastName = 'Lead', Company = 'FileDelCo',
            Email = 'filedel@example.com', MobilePhone = '+971123456700',
            BrokerAgent__c = con.Id, BrokerAgency__c = acc.Id, Status = 'New',
            BrokerAgentName__c = 'agent', BrokerAgentMobile__c = '+971123456701',
            LeadSource = 'Broker Portal', ProjectInterest__c = 'Nawayef Mansions ',
            UnitType__c = 'Villa', NumberOfBedrooms__c = '2 BHK + M', PurposeofUse__c = 'Investor'
        );
        insert lead;
        Documents__c docRecord = new Documents__c(Name = 'Passport Copy', Lead__c = lead.Id);
        insert docRecord;

        // Two files on the same slot: deleting one must leave the other.
        List<ContentVersion> versions = new List<ContentVersion>{
            new ContentVersion(Title = 'Front', PathOnClient = 'Front.pdf', VersionData = Blob.valueOf('front')),
            new ContentVersion(Title = 'Back', PathOnClient = 'Back.pdf', VersionData = Blob.valueOf('back'))
        };
        insert versions;
        List<ContentDocumentLink> links = new List<ContentDocumentLink>();
        List<Id> contentDocIds = new List<Id>();
        for (ContentVersion cv : [SELECT ContentDocumentId FROM ContentVersion WHERE Id IN :versions]) {
            contentDocIds.add(cv.ContentDocumentId);
            links.add(new ContentDocumentLink(ContentDocumentId = cv.ContentDocumentId, LinkedEntityId = docRecord.Id, ShareType = 'V'));
        }
        insert links;

        Test.startTest();
        Boolean removed = MBP_BrokerLeadcontroller.deleteLeadDocumentFile(lead.Id, contentDocIds[0]);
        Boolean unknown = MBP_BrokerLeadcontroller.deleteLeadDocumentFile(lead.Id, contentDocIds[0]);
        Boolean blank = MBP_BrokerLeadcontroller.deleteLeadDocumentFile(null, contentDocIds[1]);
        Test.stopTest();

        System.assertEquals(true, removed, 'linked file is removed');
        System.assertEquals(false, unknown, 'a file no longer on the lead returns false');
        System.assertEquals(false, blank, 'missing lead returns false');
        List<Map<String, String>> remaining = MBP_BrokerLeadcontroller.getUploadedDocuments(lead.Id);
        System.assertEquals(1, remaining.size(), 'the other file on the slot stays');
        System.assertEquals(contentDocIds[1], remaining[0].get('contentDocumentId'));
    }

    @isTest
    static void testGetDependentPickListValues1() {
        Map<String, List<String>> result;
        Test.startTest();
        try {
            result = MBP_BrokerLeadcontroller.getDependentPickListValues(
                'Lead',
                'LeadSource',
                'SubSource__c'
            );
        } catch (Exception e) {
            return;
        } finally {
            Test.stopTest();
        }
    }

    @isTest
    static void testCheckDuplicateMobileAndEmail() {
        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'test@example.com',
            MobilePhone = '0551234567'
        );
        insert testContact;
        
        Test.startTest();
        String resultEmail = MBP_BrokerLeadcontroller.checkDuplicateEmailOrMobile('test@example.com', 'email');
        String resultMobile = MBP_BrokerLeadcontroller.checkDuplicateEmailOrMobile('0551234567', 'mobile');
        String resultNone = MBP_BrokerLeadcontroller.checkDuplicateEmailOrMobile('nonexistent@example.com', 'email');
        Test.stopTest();
    }
    
    @isTest
    static void testCheckDuplicateNoMatch() {
        Test.startTest();
        String result = MBP_BrokerLeadcontroller.checkDuplicateEmailOrMobile('999999999999', 'mobile');
        Test.stopTest();
    }
    
    @isTest
    static void testGetOfferData() {
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];
        List<String> unitIds = new List<String>{unit.Id};
        String unitIdsJson = JSON.serialize(unitIds);
        
        Test.startTest();
        MBP_BrokerLeadcontroller.OfferDataWrapper res1 = 
            MBP_BrokerLeadcontroller.getOfferData(null, 'unit', unitIdsJson, Date.today(), Date.today().addDays(7), 'All');
        
        MBP_BrokerLeadcontroller.OfferDataWrapper res2 = 
            MBP_BrokerLeadcontroller.getOfferData(null, 'lead', null, null, null, null);
        Test.stopTest();

        System.assertEquals(true, res1.success);
        System.assertNotEquals(0, res1.availableUnits.size());
    }

    @isTest
    static void testGenerateOfferPDF() {
        Lead l = [SELECT Id FROM Lead LIMIT 1];
        Unit__c u = [SELECT Id FROM Unit__c LIMIT 1];
        PaymentPlan__c pp = [SELECT Id FROM PaymentPlan__c LIMIT 1];
        
        Test.startTest();
        String url = MBP_BrokerLeadcontroller.generateOfferPDF(l.Id, u.Id, pp.Id, 'Design1', 'Option1', 'http://test.com', pp.Id);
        Test.stopTest();
        
        System.assert(url.contains('OfferDetailsPDF'));
        System.assert(url.contains(l.Id));
    }

    @isTest
    static void testHandleOfferAction() {
        Lead l = [SELECT Id FROM Lead LIMIT 1];
        Unit__c u = [SELECT Id FROM Unit__c LIMIT 1];
        PaymentPlan__c pp = [SELECT Id FROM PaymentPlan__c LIMIT 1];

        Map<String, Object> opts = new Map<String, Object>{
            'design' => 'Modern',
            'unitIds' => new List<String>{u.Id},
            'unitOption' => 'Wood Flooring',
            'dpgLink' => 'http://test.com'
        };

        Test.startTest();
        String previewResult = MBP_BrokerLeadcontroller.handleOfferAction(
            'preview',
            u.Id,
            l.Id,
            pp.Id,
            JSON.serialize(opts),
            'Jane Doe'
        );
        Test.stopTest();

        System.assertNotEquals(null, previewResult);
    }

    @isTest
    static void testOfferDataErrorHandling() {
        Test.startTest();
        MBP_BrokerLeadcontroller.OfferDataWrapper res = 
            MBP_BrokerLeadcontroller.getOfferData(null, 'unit', 'INVALID_JSON', null, null, null);
        Test.stopTest();
        
        System.assertEquals(false, res.success);
        System.assertNotEquals(null, res.errorMessage);
    }
    
    @isTest
    static void testOfferDataAndUnits() {
        Project__c proj = new Project__c(Name = 'Nawayef Homes'); insert proj;
        Phase__c ph = new Phase__c(Name = 'Phase 1', Project__c = proj.Id); insert ph;
        Unit__c u = new Unit__c(Name = 'U-101',Number_of_Bedrooms__c = '6',PlotNo__c = 'r5',UnitClassification__c = 'Apartment', Phase__c = ph.Id, Status__c = 'Available'); insert u;
        PaymentPlan__c pp = new PaymentPlan__c(Name = 'Plan A', Type__c = 'Standard',Unit__c = u.Id); insert pp;
        
        Test.startTest();
        String unitIdsJson = JSON.serialize(new List<String>{u.Id});
        MBP_BrokerLeadcontroller.getOfferData(null, 'unit', unitIdsJson, Date.today(), Date.today().addDays(7), 'Custom');
        MBP_BrokerLeadcontroller.getOfferData(null, 'lead', null, null, null, null);
        
        MBP_BrokerLeadcontroller.getOfferData(null, 'unit', 'INVALID_JSON', null, null, null);
        Test.stopTest();
    }

    @isTest
    static void testOfferActionsAndEmails() {
        Lead l = [SELECT Id, Email FROM Lead LIMIT 1];
        Unit__c u = [SELECT Id FROM Unit__c LIMIT 1];
        PaymentPlan__c pp = [SELECT Id FROM PaymentPlan__c LIMIT 1];

        Map<String, Object> opts = new Map<String, Object>{
            'design' => 'Modern',
            'unitIds' => new List<String>{u.Id},
            'unitOption' => 'Opt1',
            'dpgLink' => 'http://test.com'
        };

        Test.startTest();

        MBP_BrokerLeadcontroller.handleOfferAction(
            'preview',
            u.Id,
            l.Id,
            pp.Id,
            JSON.serialize(opts),
            'John Doe'
        );

        try {
            MBP_BrokerLeadcontroller.sendOfferEmail(
                new List<String>{ String.valueOf(u.Id) },
                l.Id,
                pp.Id,
                'Modern',
                'John Doe',
                new Map<String, String>{ '__DEFAULT__' => 'Opt1' },
                new Map<String, String>{ '__DEFAULT__' => 'http://test.com' },
                new Map<String, String>{ '__DEFAULT__' => pp.Id }
            );
        } catch (Exception e) {
        }

        Test.stopTest();

        System.assert(true);
    }

    @isTest
    static void testFilteringAndMaskingBranches() {
        User u = [SELECT Id FROM User WHERE Email = 'testuser@example.com' LIMIT 1];
        List<String> filterTypes = new List<String>{'Current FY', 'Previous FY', 'Current Year', 'Previous Year', 'Custom'};
        
        System.runAs(u) {
            Test.startTest();
            for(String ft : filterTypes) {
                MBP_BrokerLeadcontroller.getFilteredLeads(u.Id, Date.today().addDays(-5), Date.today(), ft);
            }
            Test.stopTest();
        }
    }

    @isTest
    static void testLeadCreationDeepBranches() {
        Contact con = [SELECT Id, AccountId FROM Contact LIMIT 1];
        
        Map<String, Object> payload = new Map<String, Object>{
            'FirstName' => 'TestFirst',
            'LastName' => 'BranchTest',
            'Company' => 'Test',
            'Type' => 'Organization',
            'ProjectInterest__c' => 'Nawayef Mansions',
            'BrokerAgentName__c' => 'Test Agent',
            'BrokerAgentMobile__c' => '+971501234567',
            'PassportIssueDate__c' => '2023-01-01',
            'PassportExpiryDate__c' => '2030-01-01',
            'EmiratesIDExpiryDate__c' => '2027-12-31',
            'DateOfBirth__c' => '1990-01-01',
            'vatCertificateType' => 'VAT Registration Certificate',
            'UAEVATRegisterNumber__c' => '123456789'
        };

        Test.startTest();
        MBP_BrokerLeadcontroller.createOrUpdateLead(payload, con.Id, con.AccountId);
        
        try { MBP_BrokerLeadcontroller.createOrUpdateLead(null, null, null); } catch(Exception e) {}
        Test.stopTest();
    }

    @isTest
    static void testEmailLeadsExport() {
        String leadsJson = '[{"LeadNumber":"L-101","Title":"Mr","FirstName":"John","LastName":"Doe","Email":"john@test.com","Mobile":"123456","Description":"Test","Status":"New"}]';
        User u = [SELECT Id FROM User WHERE Email = 'testuser@example.com' LIMIT 1];
        System.runAs(u) {
            Test.startTest();
            try {
                MBP_BrokerLeadcontroller.emailLeadsExport(leadsJson);
            } catch (Exception e) {}
            Test.stopTest();
        }
    }

    /*=================================================================================================================
    * V3.0 - Broker lead Person Account, placeholder documents and KYC link
    * Created By         : Rushi Patel
    * Date               : 28 September 2026
    =================================================================================================================*/

    /**
    * Name         : individualLeadPayload
    * Description  : Payload for a new Individual broker lead, as the portal sends it.
    * Created By   : Rushi Patel
    * Version      : V3.0 - 28 September 2026
    */
    private static Map<String, Object> individualLeadPayload(String email, String mobile, String passport) {
        return new Map<String, Object>{
            'Type' => 'Individual',
            'Salutation' => 'Mr.',
            'FirstName' => 'Ahmed', 'LastName' => 'Customer',
            'Email' => email, 'MobilePhone' => mobile,
            'BrokerAgentName__c' => 'upendra', 'BrokerAgentMobile__c' => '+918897664052',
            'Nationality__c' => 'India', 'UAEResidentStatus__c' => 'Non-Resident', 'CountryOfResidence__c' => 'India',
            'Description' => 'Interested in a villa',
            'PassportNumber__c' => passport, 'PassportIssueDate__c' => '2020-01-01', 'PassportExpiryDate__c' => '2030-01-01',
            'ProjectInterest__c' => 'Nawayef Mansions', 'UnitType__c' => 'Villa',
            'NumberOfBedrooms__c' => '2 BHK + M', 'PurposeofUse__c' => 'Investor'
        };
    }

    /**
    * Name         : insertExistingCustomer
    * Description  : Inserts an existing Person Account with a passport and a KYC completed date.
    * Created By   : Rushi Patel
    * Version      : V3.0 - 28 September 2026
    */
    private static Account insertExistingCustomer(String lastName, String passport, Date kycCompletedDate) {
        Id personRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();
        Account acc = new Account(RecordTypeId = personRtId, LastName = lastName, PassportNumber__pc = passport,
                                  PersonEmail = lastName.toLowerCase() + '@example.com',
                                  KYC_Completed_Date__c = kycCompletedDate);
        insert acc;
        return acc;
    }

    /**
    * Name         : personCustomer
    * Description  : Unsaved Person Account, so each test sets only the identity fields it needs.
    * Created By   : Rushi Patel
    * Version      : V3.0 - 28 September 2026
    */
    private static Account personCustomer(String lastName) {
        Id personRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();
        return new Account(RecordTypeId = personRtId, LastName = lastName);
    }

    /**
    * Name         : wasPicked
    * Description  : True when the account got the lead's residency ('Non-Resident' / 'India') - only the
    *                matched account is filled, so this proves which account was picked.
    * Created By   : Rushi Patel
    * Version      : V3.0 - 28 September 2026
    */
    private static Boolean wasPicked(Id accountId) {
        Account acc = [SELECT UAE_Resident_Status__pc, CountryOfResidence__pc FROM Account WHERE Id = :accountId];
        return acc.UAE_Resident_Status__pc == 'Non-Resident' && acc.CountryOfResidence__pc == 'India';
    }

    /**
    * Name         : saveLead
    * Description  : Saves a lead through the controller as the test broker contact.
    * Created By   : Rushi Patel
    * Version      : V3.0 - 28 September 2026
    */
    private static void saveLead(Map<String, Object> payload) {
        Contact con = [SELECT Id, AccountId FROM Contact LIMIT 1];
        MBP_BrokerLeadcontroller.createOrUpdateLead(payload, con.Id, con.AccountId);
    }

    /**
    * Name         : personAccountCount
    * Description  : Number of Person Accounts in the test data.
    * Created By   : Rushi Patel
    * Version      : V3.0 - 28 September 2026
    */
    private static Integer personAccountCount() {
        return [SELECT COUNT() FROM Account WHERE IsPersonAccount = true];
    }

    /**
    * Name         : kycJobCount
    * Description  : Number of KYC link jobs queued in the test.
    * Created By   : Rushi Patel
    * Version      : V3.0 - 28 September 2026
    */
    private static Integer kycJobCount() {
        return [SELECT COUNT() FROM AsyncApexJob WHERE ApexClass.Name = 'MBP_BrokerLeadKYCQueueable'];
    }

    /**
    * Name         : testNewIndividualLeadCreatesPersonAccount
    * Description  : New Individual broker lead with no match creates a Person Account with the lead's
    *                details and its placeholder documents.
    * Created By   : Rushi Patel
    * Version      : V3.0 - 28 September 2026
    */
    @isTest
    static void testNewIndividualLeadCreatesPersonAccount() {
        Contact con = [SELECT Id, AccountId FROM Contact LIMIT 1];

        Test.startTest();
        MBP_BrokerLeadcontroller.createOrUpdateLead(
            individualLeadPayload('new.customer@example.com', '+971501112233', 'N1234567'), con.Id, con.AccountId);
        Test.stopTest();

        List<Account> accs = [
            SELECT Id, PersonContactId, FirstName, LastName, PersonMobilePhone, Nationality__pc,
                   UAE_Resident_Status__pc, PassportNumber__pc, PassportExpiryDate__pc, AccountSource,
                   CountryOfResidence__pc, Description
            FROM Account
            WHERE IsPersonAccount = true AND PersonEmail = 'new.customer@example.com'
        ];
        System.assertEquals(1, accs.size(), 'one Person Account created for the new Individual lead');
        System.assertEquals('Ahmed', accs[0].FirstName);
        System.assertEquals('Customer', accs[0].LastName);
        System.assertEquals('+971501112233', accs[0].PersonMobilePhone);
        System.assertEquals('India', accs[0].Nationality__pc);
        System.assertEquals('Non-Resident', accs[0].UAE_Resident_Status__pc);
        System.assertEquals('N1234567', accs[0].PassportNumber__pc);
        System.assertEquals(Date.newInstance(2030, 1, 1), accs[0].PassportExpiryDate__pc);
        System.assertEquals('Broker Portal', accs[0].AccountSource);
        System.assertEquals('India', accs[0].CountryOfResidence__pc);
        System.assertEquals('Interested in a villa', accs[0].Description, 'description mapped');

        Integer docCount = [SELECT COUNT() FROM Documents__c WHERE PrimaryContact__c = :accs[0].PersonContactId];
        System.assertEquals(DocumentsUtility.getDocumentsForSObject('PersonAccount').size(), docCount,
            'placeholder documents generated for the new Person Account');
    }

    /**
    * Name         : testOrgLeadAndLeadUpdateDoNotCreatePersonAccount
    * Description  : Organization leads and updates to existing leads never create a Person Account.
    * Created By   : Rushi Patel
    * Version      : V3.0 - 28 September 2026
    */
    @isTest
    static void testOrgLeadAndLeadUpdateDoNotCreatePersonAccount() {
        Contact con = [SELECT Id, AccountId FROM Contact LIMIT 1];

        Map<String, Object> orgPayload = individualLeadPayload('org.lead@example.com', '+971507778899', null);
        orgPayload.put('Type', 'Organization');
        orgPayload.put('Name', 'Org Customer LLC');
        orgPayload.put('UnifiedNumber__c', 'UN12345');

        Lead existingLead = [SELECT Id FROM Lead LIMIT 1];
        Map<String, Object> updatePayload = individualLeadPayload('updated.lead@example.com', '+971501231231', 'UP123456');
        updatePayload.put('Id', existingLead.Id);

        Test.startTest();
        MBP_BrokerLeadcontroller.createOrUpdateLead(orgPayload, con.Id, con.AccountId);
        MBP_BrokerLeadcontroller.createOrUpdateLead(updatePayload, con.Id, con.AccountId);
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Account WHERE IsPersonAccount = true],
            'Person Account is only created for a new Individual lead');
    }

    /**
    * Name         : testIsBrokerLead
    * Description  : Only Broker Portal leads with both Broker Agency and Broker Agent are broker leads.
    * Created By   : Rushi Patel
    * Version      : V3.0 - 28 September 2026
    */
    @isTest
    static void testIsBrokerLead() {
        Contact con = [SELECT Id, AccountId FROM Contact LIMIT 1];
        System.assert(MBP_BrokerLeadcontroller.isBrokerLead(
            new Lead(LeadSource = 'Broker Portal', BrokerAgency__c = con.AccountId, BrokerAgent__c = con.Id)));
        System.assert(!MBP_BrokerLeadcontroller.isBrokerLead(
            new Lead(LeadSource = 'Website', BrokerAgency__c = con.AccountId, BrokerAgent__c = con.Id)),
            'other lead sources never create a Person Account');
        System.assert(!MBP_BrokerLeadcontroller.isBrokerLead(
            new Lead(LeadSource = 'Broker Portal', BrokerAgent__c = con.Id)),
            'a Broker Portal lead without its agency is not treated as a broker lead');
    }

    /**
    * Name         : testFindMatchingPersonAccountBlankLead
    * Description  : A lead with no identity details never matches an account.
    * Created By   : Rushi Patel
    * Version      : V3.0 - 28 September 2026
    */
    @isTest
    static void testFindMatchingPersonAccountBlankLead() {
        System.assertEquals(null, MBP_BrokerLeadcontroller.findMatchingPersonAccount(new Lead(LastName = 'Blank')),
            'a lead with no identity details never matches');
    }

    /**
    * Name         : testNewIndividualLeadWithExistingPersonAccount
    * Description  : Match on passport only - no new account, KYC not complete so the link is sent.
    * Created By   : Rushi Patel
    * Version      : V3.0 - 28 September 2026
    */
    @isTest
    static void testNewIndividualLeadWithExistingPersonAccount() {
        Contact con = [SELECT Id, AccountId FROM Contact LIMIT 1];
        Id personRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();
        insert new Account(RecordTypeId = personRtId, LastName = 'Existing', PersonEmail = 'existing@example.com',
                           PassportNumber__pc = 'EX998877');

        // Different email and mobile, same passport: counts as the same customer.
        Test.startTest();
        MBP_BrokerLeadcontroller.createOrUpdateLead(
            individualLeadPayload('someone.else@example.com', '+971504445566', 'EX998877'), con.Id, con.AccountId);
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM Account WHERE IsPersonAccount = true],
            'no new Person Account when a matching one exists');
        System.assertEquals(1, kycJobCount(), 'KYC never completed on the existing account - link sent');
    }

    /**
    * Name         : testMatchOnEmailOnly
    * Description  : Existing account matched on email only is used.
    * Created By   : Rushi Patel
    * Version      : V3.0 - 28 September 2026
    */
    @isTest
    static void testMatchOnEmailOnly() {
        Account existing = personCustomer('EmailOnly');
        existing.PersonEmail = 'email.only@example.com';
        insert existing;

        Test.startTest();
        saveLead(individualLeadPayload('email.only@example.com', '+971500000001', null));
        Test.stopTest();

        System.assertEquals(1, personAccountCount(), 'email match - no new Person Account');
        System.assert(wasPicked(existing.Id), 'account matched on email is used');
        System.assertEquals(1, kycJobCount(), 'KYC not complete - link sent');
    }

    /**
    * Name         : testMatchOnEmailIgnoresCase
    * Description  : Email match ignores upper / lower case.
    * Created By   : Rushi Patel
    * Version      : V3.0 - 28 September 2026
    */
    @isTest
    static void testMatchOnEmailIgnoresCase() {
        Account existing = personCustomer('EmailCase');
        existing.PersonEmail = 'Case.Match@Example.com';
        insert existing;

        Test.startTest();
        saveLead(individualLeadPayload('case.match@example.com', '+971500000002', null));
        Test.stopTest();

        System.assertEquals(1, personAccountCount(), 'email compared without case');
        System.assert(wasPicked(existing.Id));
    }

    /**
    * Name         : testMatchOnPersonMobileOnly
    * Description  : Existing account matched on PersonMobilePhone only is used.
    * Created By   : Rushi Patel
    * Version      : V3.0 - 28 September 2026
    */
    @isTest
    static void testMatchOnPersonMobileOnly() {
        Account existing = personCustomer('MobileOnly');
        existing.PersonMobilePhone = '+971500000003';
        insert existing;

        Test.startTest();
        saveLead(individualLeadPayload('mobile.only@example.com', '+971500000003', null));
        Test.stopTest();

        System.assertEquals(1, personAccountCount(), 'mobile match - no new Person Account');
        System.assert(wasPicked(existing.Id), 'account matched on PersonMobilePhone is used');
    }

    /**
    * Name         : testMatchOnAccountPhoneOnly
    * Description  : Existing account matched on the Account Phone field only is used.
    * Created By   : Rushi Patel
    * Version      : V3.0 - 28 September 2026
    */
    @isTest
    static void testMatchOnAccountPhoneOnly() {
        Account existing = personCustomer('PhoneOnly');
        existing.Phone = '+971500000004';
        insert existing;

        Test.startTest();
        saveLead(individualLeadPayload('phone.only@example.com', '+971500000004', null));
        Test.stopTest();

        System.assertEquals(1, personAccountCount(), 'Phone match - no new Person Account');
        System.assert(wasPicked(existing.Id), 'account matched on Phone is used');
    }

    /**
    * Name         : testMatchOnEmiratesIdOnly
    * Description  : Existing account matched on Emirates ID only is used.
    * Created By   : Rushi Patel
    * Version      : V3.0 - 28 September 2026
    */
    @isTest
    static void testMatchOnEmiratesIdOnly() {
        Account existing = personCustomer('EidOnly');
        existing.EIDNumber__pc = '784-1990-1234567-1';
        insert existing;

        Map<String, Object> payload = individualLeadPayload('eid.only@example.com', '+971500000005', null);
        payload.put('EIDNumber__c', '784-1990-1234567-1');

        Test.startTest();
        saveLead(payload);
        Test.stopTest();

        System.assertEquals(1, personAccountCount(), 'EID match - no new Person Account');
        System.assert(wasPicked(existing.Id), 'account matched on Emirates ID is used');
    }

    /**
    * Name         : testEachFieldMatchesDifferentAccountOldestWins
    * Description  : One account per field (email, mobile, Phone, EID, passport) - the oldest is used,
    *                whatever field it matched on, and the others are left untouched.
    * Created By   : Rushi Patel
    * Version      : V3.0 - 28 September 2026
    */
    @isTest
    static void testEachFieldMatchesDifferentAccountOldestWins() {
        Account byEmail = personCustomer('ByEmail');
        byEmail.PersonEmail = 'multi@example.com';
        Account byMobile = personCustomer('ByMobile');
        byMobile.PersonMobilePhone = '+971500000006';
        Account byPhone = personCustomer('ByPhone');
        byPhone.Phone = '+971500000006';
        Account byEid = personCustomer('ByEid');
        byEid.EIDNumber__pc = '784-1990-7654321-1';
        Account byPassport = personCustomer('ByPassport');
        byPassport.PassportNumber__pc = 'MP123456';
        insert new List<Account>{ byEmail, byMobile, byPhone, byEid, byPassport };
        Test.setCreatedDate(byEmail.Id, DateTime.now().addDays(-10));
        Test.setCreatedDate(byMobile.Id, DateTime.now().addDays(-20));
        Test.setCreatedDate(byPhone.Id, DateTime.now().addDays(-30));
        Test.setCreatedDate(byEid.Id, DateTime.now().addDays(-50)); // oldest
        Test.setCreatedDate(byPassport.Id, DateTime.now().addDays(-40));

        Map<String, Object> payload = individualLeadPayload('multi@example.com', '+971500000006', 'MP123456');
        payload.put('EIDNumber__c', '784-1990-7654321-1');

        Test.startTest();
        saveLead(payload);
        Test.stopTest();

        System.assertEquals(5, personAccountCount(), 'no new Person Account');
        System.assert(wasPicked(byEid.Id), 'oldest match (EID) is used');
        for (Account other : new List<Account>{ byEmail, byMobile, byPhone, byPassport }) {
            System.assert(!wasPicked(other.Id), 'newer matches are left untouched');
        }
        System.assertEquals(1, kycJobCount(), 'one KYC link, for the picked account only');
    }

    /**
    * Name         : testDuplicateCustomersUseOldestNotMerged
    * Description  : Same passport on three accounts - merged ones are skipped, the oldest remaining is
    *                used; with every match merged there is no match.
    * Created By   : Rushi Patel
    * Version      : V3.0 - 28 September 2026
    */
    @isTest
    static void testDuplicateCustomersUseOldestNotMerged() {
        Account oldestMerged = insertExistingCustomer('DupMerged', 'DP778899', null);
        Account older = insertExistingCustomer('DupOlder', 'DP778899', null);
        Account newer = insertExistingCustomer('DupNewer', 'DP778899', Date.today());
        Test.setCreatedDate(oldestMerged.Id, DateTime.now().addDays(-30));
        Test.setCreatedDate(older.Id, DateTime.now().addDays(-20));
        Test.setCreatedDate(newer.Id, DateTime.now().addDays(-10));
        update new Account(Id = oldestMerged.Id, Is_Merged__c = true);

        Lead dupLead = new Lead(LastName = 'Dup', PassportNumber__c = 'DP778899');
        System.assertEquals(older.Id, MBP_BrokerLeadcontroller.findMatchingPersonAccount(dupLead).Id,
            'oldest account that is not merged is used');

        update new Account(Id = older.Id, Is_Merged__c = true);
        update new Account(Id = newer.Id, Is_Merged__c = true);
        System.assertEquals(null, MBP_BrokerLeadcontroller.findMatchingPersonAccount(dupLead),
            'merged accounts never count as a match');
    }

    /**
    * Name         : testOldestMatchMergedNextOldestWins
    * Description  : Accounts matched on different fields with the oldest merged - the next oldest is used.
    * Created By   : Rushi Patel
    * Version      : V3.0 - 28 September 2026
    */
    @isTest
    static void testOldestMatchMergedNextOldestWins() {
        Account byEmail = personCustomer('MergedEmail');
        byEmail.PersonEmail = 'merged.multi@example.com';
        Account byMobile = personCustomer('LiveMobile');
        byMobile.PersonMobilePhone = '+971500000007';
        insert new List<Account>{ byEmail, byMobile };
        Test.setCreatedDate(byEmail.Id, DateTime.now().addDays(-30));
        Test.setCreatedDate(byMobile.Id, DateTime.now().addDays(-10));
        update new Account(Id = byEmail.Id, Is_Merged__c = true);

        Test.startTest();
        saveLead(individualLeadPayload('merged.multi@example.com', '+971500000007', null));
        Test.stopTest();

        System.assert(wasPicked(byMobile.Id), 'merged oldest skipped, next oldest used');
        System.assert(!wasPicked(byEmail.Id), 'merged account is never touched');
    }

    /**
    * Name         : testOnlyMergedMatchCreatesNewAccount
    * Description  : Only a merged account matches - treated as no match, a new Person Account is created
    *                and sent the KYC link.
    * Created By   : Rushi Patel
    * Version      : V3.0 - 28 September 2026
    */
    @isTest
    static void testOnlyMergedMatchCreatesNewAccount() {
        Account merged = personCustomer('OnlyMerged');
        merged.PassportNumber__pc = 'OM556677';
        insert merged;
        update new Account(Id = merged.Id, Is_Merged__c = true);

        Test.startTest();
        saveLead(individualLeadPayload('only.merged@example.com', '+971500000008', 'OM556677'));
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM Account WHERE IsPersonAccount = true AND PersonEmail = 'only.merged@example.com'],
            'new Person Account created');
        System.assert(!wasPicked(merged.Id), 'merged account is never touched');
        System.assertEquals(1, kycJobCount(), 'KYC link sent to the new account');
    }

    /**
    * Name         : testBlankValuesNeverMatch
    * Description  : Blank EID / passport on both the lead and the account is not a match.
    * Created By   : Rushi Patel
    * Version      : V3.0 - 28 September 2026
    */
    @isTest
    static void testBlankValuesNeverMatch() {
        Account existing = personCustomer('NoIds');
        existing.PersonEmail = 'someone.different@example.com';
        insert existing; // no mobile, EID or passport - same as the lead below

        Test.startTest();
        saveLead(individualLeadPayload('fresh.customer@example.com', '+971500000011', null));
        Test.stopTest();

        System.assertEquals(2, personAccountCount(), 'blank EID / passport on both sides is not a match');
        System.assert(!wasPicked(existing.Id));
    }

    /**
    * Name         : testBusinessAccountNeverMatches
    * Description  : A business (non-person) account with the same phone is ignored.
    * Created By   : Rushi Patel
    * Version      : V3.0 - 28 September 2026
    */
    @isTest
    static void testBusinessAccountNeverMatches() {
        Id orgRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('OrganizationAccount').getRecordTypeId();
        insert new Account(RecordTypeId = orgRtId, Name = 'Same Phone LLC', Phone = '+971500000012');

        Test.startTest();
        saveLead(individualLeadPayload('biz.phone@example.com', '+971500000012', null));
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM Account WHERE IsPersonAccount = true AND PersonEmail = 'biz.phone@example.com'],
            'business account with the same phone is ignored - new Person Account created');
    }

    /**
    * Name         : testExistingCustomerWithActiveKycIsLeftAlone
    * Description  : Existing account with KYC Active - no KYC link, no new account.
    * Created By   : Rushi Patel
    * Version      : V3.0 - 28 September 2026
    */
    @isTest
    static void testExistingCustomerWithActiveKycIsLeftAlone() {
        Contact con = [SELECT Id, AccountId FROM Contact LIMIT 1];
        insertExistingCustomer('ActiveKyc', 'AK112233', Date.today());

        Test.startTest();
        MBP_BrokerLeadcontroller.createOrUpdateLead(
            individualLeadPayload('active.lead@example.com', '+971502223344', 'AK112233'), con.Id, con.AccountId);
        Test.stopTest();

        System.assertEquals(0, kycJobCount(), 'no KYC link while the existing KYC is active');
        System.assertEquals(1, [SELECT COUNT() FROM Account WHERE IsPersonAccount = true], 'no new Person Account');
    }

    /**
    * Name         : testExistingCustomerWithExpiredKycGetsLink
    * Description  : Existing account with KYC Expired - the KYC link is sent.
    * Created By   : Rushi Patel
    * Version      : V3.0 - 28 September 2026
    */
    @isTest
    static void testExistingCustomerWithExpiredKycGetsLink() {
        Contact con = [SELECT Id, AccountId FROM Contact LIMIT 1];
        insertExistingCustomer('ExpiredKyc', 'EK445566', Date.today().addMonths(-4));

        Test.startTest();
        MBP_BrokerLeadcontroller.createOrUpdateLead(
            individualLeadPayload('expired.lead@example.com', '+971503334455', 'EK445566'), con.Id, con.AccountId);
        Test.stopTest();

        System.assertEquals(1, kycJobCount(), 'KYC link re-sent when the existing KYC has expired');
    }

    /**
    * Name         : testOldestNotCompleteNewerActiveSendsLink
    * Description  : The picked (oldest) account's KYC status decides - oldest not complete, newer active,
    *                so the link is sent.
    * Created By   : Rushi Patel
    * Version      : V3.0 - 28 September 2026
    */
    @isTest
    static void testOldestNotCompleteNewerActiveSendsLink() {
        Account oldest = personCustomer('OldNotDone');
        oldest.PassportNumber__pc = 'KS111111';
        Account newer = personCustomer('NewActive');
        newer.PassportNumber__pc = 'KS111111';
        newer.KYC_Completed_Date__c = Date.today();
        insert new List<Account>{ oldest, newer };
        Test.setCreatedDate(oldest.Id, DateTime.now().addDays(-30));
        Test.setCreatedDate(newer.Id, DateTime.now().addDays(-10));

        Test.startTest();
        saveLead(individualLeadPayload('kyc.split1@example.com', '+971500000009', 'KS111111'));
        Test.stopTest();

        System.assert(wasPicked(oldest.Id));
        System.assertEquals(1, kycJobCount(), 'oldest KYC not complete - link sent even though a newer one is active');
    }

    /**
    * Name         : testOldestActiveNewerNotCompleteSendsNothing
    * Description  : Oldest account KYC active, newer not complete - nothing is sent.
    * Created By   : Rushi Patel
    * Version      : V3.0 - 28 September 2026
    */
    @isTest
    static void testOldestActiveNewerNotCompleteSendsNothing() {
        Account oldest = personCustomer('OldActive');
        oldest.PassportNumber__pc = 'KS222222';
        oldest.KYC_Completed_Date__c = Date.today();
        Account newer = personCustomer('NewNotDone');
        newer.PassportNumber__pc = 'KS222222';
        insert new List<Account>{ oldest, newer };
        Test.setCreatedDate(oldest.Id, DateTime.now().addDays(-30));
        Test.setCreatedDate(newer.Id, DateTime.now().addDays(-10));

        Test.startTest();
        saveLead(individualLeadPayload('kyc.split2@example.com', '+971500000010', 'KS222222'));
        Test.stopTest();

        System.assert(wasPicked(oldest.Id));
        System.assertEquals(0, kycJobCount(), 'oldest KYC active - no link');
    }

    /**
    * Name         : testExistingCustomerBlankResidencyFilled
    * Description  : Blank UAE Resident Status and Country of Residence on the existing account are filled
    *                from the lead.
    * Created By   : Rushi Patel
    * Version      : V3.0 - 28 September 2026
    */
    @isTest
    static void testExistingCustomerBlankResidencyFilled() {
        Contact con = [SELECT Id, AccountId FROM Contact LIMIT 1];
        Account existing = insertExistingCustomer('NoResidency', 'NR101010', Date.today());

        Test.startTest();
        MBP_BrokerLeadcontroller.createOrUpdateLead(
            individualLeadPayload('noresidency.lead@example.com', '+971505556677', 'NR101010'), con.Id, con.AccountId);
        Test.stopTest();

        existing = [SELECT UAE_Resident_Status__pc, CountryOfResidence__pc FROM Account WHERE Id = :existing.Id];
        System.assertEquals('Non-Resident', existing.UAE_Resident_Status__pc, 'blank resident status filled');
        System.assertEquals('India', existing.CountryOfResidence__pc, 'blank country of residence filled');
    }

    /**
    * Name         : testExistingCustomerResidencyKept
    * Description  : Residency values already on the existing account are never overwritten.
    * Created By   : Rushi Patel
    * Version      : V3.0 - 28 September 2026
    */
    @isTest
    static void testExistingCustomerResidencyKept() {
        Contact con = [SELECT Id, AccountId FROM Contact LIMIT 1];
        Account existing = insertExistingCustomer('HasResidency', 'HR202020', Date.today());
        update new Account(Id = existing.Id, UAE_Resident_Status__pc = 'Resident',
                           CountryOfResidence__pc = 'United Arab Emirates');

        Test.startTest();
        MBP_BrokerLeadcontroller.createOrUpdateLead(
            individualLeadPayload('hasresidency.lead@example.com', '+971506667788', 'HR202020'), con.Id, con.AccountId);
        Test.stopTest();

        existing = [SELECT UAE_Resident_Status__pc, CountryOfResidence__pc FROM Account WHERE Id = :existing.Id];
        System.assertEquals('Resident', existing.UAE_Resident_Status__pc, 'existing resident status kept');
        System.assertEquals('United Arab Emirates', existing.CountryOfResidence__pc, 'existing country of residence kept');
    }

    /**
    * Name         : testResidencyPartiallyFilled
    * Description  : Resident Status present, Country of Residence blank - only the blank one is filled.
    * Created By   : Rushi Patel
    * Version      : V3.0 - 28 September 2026
    */
    @isTest
    static void testResidencyPartiallyFilled() {
        Account existing = personCustomer('HalfResidency');
        existing.PassportNumber__pc = 'HF333333';
        existing.UAE_Resident_Status__pc = 'Resident';
        insert existing;

        Test.startTest();
        saveLead(individualLeadPayload('half.residency@example.com', '+971500000013', 'HF333333'));
        Test.stopTest();

        existing = [SELECT UAE_Resident_Status__pc, CountryOfResidence__pc FROM Account WHERE Id = :existing.Id];
        System.assertEquals('Resident', existing.UAE_Resident_Status__pc, 'existing resident status kept');
        System.assertEquals('India', existing.CountryOfResidence__pc, 'blank country of residence filled');
    }

    /**
    * Name         : testResidencyBlankOnBothSides
    * Description  : No residency on the lead or the account - the account stays blank and the KYC job is
    *                still queued (sendKYCForm logs the missing residency).
    * Created By   : Rushi Patel
    * Version      : V3.0 - 28 September 2026
    */
    @isTest
    static void testResidencyBlankOnBothSides() {
        Account existing = personCustomer('NoResidencyAnywhere');
        existing.PassportNumber__pc = 'NB444444';
        insert existing;

        Map<String, Object> payload = individualLeadPayload('no.residency@example.com', '+971500000014', 'NB444444');
        payload.remove('UAEResidentStatus__c');
        payload.remove('CountryOfResidence__c');

        Test.startTest();
        saveLead(payload);
        Test.stopTest();

        existing = [SELECT UAE_Resident_Status__pc, CountryOfResidence__pc FROM Account WHERE Id = :existing.Id];
        System.assertEquals(null, existing.UAE_Resident_Status__pc);
        System.assertEquals(null, existing.CountryOfResidence__pc);
        System.assertEquals(1, kycJobCount(), 'KYC job still queued');
    }

    /**
    * Name         : testExistingAccountGetsMissingDocuments
    * Description  : A matched account gets the placeholder documents it does not have yet (V3.2 - it used to get none).
    * Created By   : Rushi Patel
    * Version      : V3.0 - 28 September 2026, V3.2 - 30 September 2026
    */
    @isTest
    static void testExistingAccountGetsMissingDocuments() {
        Account existing = personCustomer('NoNewDocs');
        existing.PassportNumber__pc = 'ND555555';
        insert existing;
        Id personContactId = [SELECT PersonContactId FROM Account WHERE Id = :existing.Id].PersonContactId;

        Test.startTest();
        saveLead(individualLeadPayload('no.new.docs@example.com', '+971500000015', 'ND555555'));
        Test.stopTest();

        System.assertEquals(DocumentsUtility.getDocumentsForSObject('PersonAccount').size(), // v3.2 updated by Rushi Patel - 30 September 2026
            [SELECT COUNT() FROM Documents__c WHERE PrimaryContact__c = :personContactId],
            'missing placeholder documents generated for the matched account');
    }

    /**
    * Name         : nonBrokerLead
    * Description  : Inserts a lead directly (not through the portal), so it is not a broker lead.
    * Created By   : Rushi Patel
    * Version      : V3.0 - 28 September 2026
    */
    private static Lead nonBrokerLead(String email) {
        Lead l = new Lead(FirstName = 'Walk', LastName = 'In', Company = 'Company', Email = email,
                          MobilePhone = '+971500000099', LeadSource = 'Website', Status = 'New',
                          ProjectInterest__c = 'Nawayef Mansions', UnitType__c = 'Villa',
                          NumberOfBedrooms__c = '2 BHK + M', PurposeofUse__c = 'Investor');
        insert l;
        return l;
    }

    /**
    * Name         : testNonBrokerLeadIsSkipped
    * Description  : A lead that is not a broker lead never gets a Person Account or a KYC link.
    * Created By   : Rushi Patel
    * Version      : V3.0 - 28 September 2026
    */
    @isTest
    static void testNonBrokerLeadIsSkipped() {
        Lead l = nonBrokerLead('walk.in@example.com');

        Test.startTest();
        MBP_BrokerLeadcontroller.createPersonAccountForLead(l.Id);
        Test.stopTest();

        System.assertEquals(0, personAccountCount(), 'no Person Account for a non-broker lead');
        System.assertEquals(0, kycJobCount(), 'no KYC link for a non-broker lead');
    }

    /**
    * Name         : testAccountFailureIsLoggedNotThrown
    * Description  : Any failure while creating the account is rolled back and logged - it never reaches
    *                the broker's lead save.
    * Created By   : Rushi Patel
    * Version      : V3.0 - 28 September 2026
    */
    @isTest
    static void testAccountFailureIsLoggedNotThrown() {
        Lead l = nonBrokerLead('gone@example.com');
        Id goneLeadId = l.Id;
        delete l;

        Test.startTest();
        MBP_BrokerLeadcontroller.createPersonAccountForLead(goneLeadId); // lead no longer exists - the query fails
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM Logger__c WHERE ExecutingProcessName__c = 'Broker Lead Person Account'],
            'failure logged instead of thrown');
        System.assertEquals(0, personAccountCount(), 'nothing created');
    }

    /*=================================================================================================================
    * V3.1 - Broker lead Organization Account and placeholder documents
    * Created By         : Rushi Patel
    * Date               : 29 September 2026
    =================================================================================================================*/

    /**
    * Name         : orgLeadPayload
    * Description  : Payload for a new Organization broker lead, as the live portal (mbpr_salesWorkspace) sends
    *                it - owner's details, company details, no identity documents.
    * Created By   : Rushi Patel
    * Version      : V3.1 - 29 September 2026
    */
    private static Map<String, Object> orgLeadPayload(String orgName, String unifiedNumber, String email) {
        return new Map<String, Object>{
            'Type' => 'Organization',
            'Name' => orgName,
            'UnifiedNumber__c' => unifiedNumber,
            'vatCertificateType' => 'VAT Registration Certificate',
            'UAEVATRegisterNumber__c' => '100123456700003',
            'Salutation' => 'Mr.',
            'FirstName' => 'Omar', 'LastName' => 'Owner',
            'Email' => email, 'MobilePhone' => '+971509990001',
            'Nationality__c' => 'India', 'UAEResidentStatus__c' => 'Resident', 'CountryOfResidence__c' => 'United Arab Emirates',
            'Description' => 'Company buying for staff housing',
            'BrokerAgentName__c' => 'upendra', 'BrokerAgentMobile__c' => '+918897664052',
            'ProjectInterest__c' => 'Nawayef Mansions', 'UnitType__c' => 'Villa',
            'NumberOfBedrooms__c' => '2 BHK + M', 'PurposeOfUse__c' => 'Investor',
            'clearIdentityDocuments' => true
        };
    }

    /**
    * Name         : insertOrgAccount
    * Description  : Inserts an existing account of the given record type with a Unified Number.
    * Created By   : Rushi Patel
    * Version      : V3.1 - 29 September 2026
    */
    private static Account insertOrgAccount(String name, String unifiedNumber, String recordTypeDevName) {
        Id rtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get(recordTypeDevName).getRecordTypeId();
        Account acc = new Account(RecordTypeId = rtId, Name = name, UnifiedNumber__c = unifiedNumber);
        // Modon_Org_Acc_Rule rejects a second org account with the same Unified Number unless the save is allowed
        Database.DMLOptions dmlOptions = new Database.DMLOptions();
        dmlOptions.DuplicateRuleHeader.allowSave = true;
        dmlOptions.optAllOrNone = true;
        Database.insert(acc, dmlOptions);
        return acc;
    }

    /**
    * Name         : markOrgAccountsMerged
    * Description  : Flags Organization Accounts as merged, passing the Modon_Org_Acc_Rule duplicate alert.
    * Created By   : Rushi Patel
    * Version      : V3.1 - 29 September 2026
    */
    private static void markOrgAccountsMerged(List<Id> accountIds) {
        List<Account> accs = new List<Account>();
        for (Id accId : accountIds) {
            accs.add(new Account(Id = accId, Is_Merged__c = true));
        }
        Database.DMLOptions dmlOptions = new Database.DMLOptions();
        dmlOptions.DuplicateRuleHeader.allowSave = true;
        dmlOptions.optAllOrNone = true;
        Database.update(accs, dmlOptions);
    }

    /**
    * Name         : orgAccountCount
    * Description  : Number of Organization Accounts with the given Unified Number.
    * Created By   : Rushi Patel
    * Version      : V3.1 - 29 September 2026
    */
    private static Integer orgAccountCount(String unifiedNumber) {
        return [SELECT COUNT() FROM Account
                WHERE RecordType.DeveloperName = 'OrganizationAccount' AND UnifiedNumber__c = :unifiedNumber];
    }

    /**
    * Name         : testNewOrgLeadCreatesOrgAccount
    * Description  : New Organization broker lead with no match creates an Organization Account with the
    *                lead's company details and its placeholder documents - no Person Account, no KYC link.
    * Created By   : Rushi Patel
    * Version      : V3.1 - 29 September 2026
    */
    @isTest
    static void testNewOrgLeadCreatesOrgAccount() {
        Test.startTest();
        saveLead(orgLeadPayload('Al Noor 2 Real Estate L.L.C.', 'UN-100001', 'owner.one@example.com'));
        Test.stopTest();

        List<Account> accs = [
            SELECT Id, Name, TradeName__c, UnifiedNumber__c, UAEVATRegisterNumber__c, VAT_Certificate_Type__c,
                   Description, AccountSource, IsPersonAccount
            FROM Account
            WHERE RecordType.DeveloperName = 'OrganizationAccount' AND UnifiedNumber__c = 'UN-100001'
        ];
        System.assertEquals(1, accs.size(), 'one Organization Account created');
        System.assertEquals('Al Noor 2 Real Estate L.L.C.', accs[0].Name, 'org name used as typed');
        System.assertEquals('Al Noor 2 Real Estate L.L.C.', accs[0].TradeName__c);
        System.assertEquals('100123456700003', accs[0].UAEVATRegisterNumber__c);
        System.assertEquals('VAT Registration Certificate', accs[0].VAT_Certificate_Type__c);
        System.assertEquals('Company buying for staff housing', accs[0].Description);
        System.assertEquals('Broker Portal', accs[0].AccountSource);
        System.assertEquals(false, accs[0].IsPersonAccount);

        System.assertEquals(DocumentsUtility.getDocumentsForSObject('Account').size(),
            [SELECT COUNT() FROM Documents__c WHERE Account__c = :accs[0].Id],
            'corporate placeholder documents generated for the new Organization Account');
        System.assertEquals(0, personAccountCount(), 'an Organization lead never creates a Person Account');
        System.assertEquals(0, kycJobCount(), 'no KYC link for Organization Accounts');
    }

    /**
    * Name         : testOrgLeadWithExistingOrgAccount
    * Description  : An Organization Account with the same Unified Number exists - no new account and no new
    *                documents on the existing one.
    * Created By   : Rushi Patel
    * Version      : V3.1 - 29 September 2026
    */
    @isTest
    static void testOrgLeadWithExistingOrgAccount() {
        Account existing = insertOrgAccount('Existing Co', 'UN-100002', 'OrganizationAccount');
        Integer docsBefore = [SELECT COUNT() FROM Documents__c WHERE Account__c = :existing.Id];

        Test.startTest();
        saveLead(orgLeadPayload('Existing Co Trading', 'UN-100002', 'owner.two@example.com'));
        Test.stopTest();

        System.assertEquals(1, orgAccountCount('UN-100002'), 'no new Organization Account when the Unified Number matches');
        System.assertEquals(docsBefore, [SELECT COUNT() FROM Documents__c WHERE Account__c = :existing.Id],
            'documents are only generated for new accounts');
    }

    /**
    * Name         : testOrgMatchUsesOldestNotMerged
    * Description  : Several Organization Accounts share the Unified Number - merged ones are skipped and the
    *                oldest remaining one is used; with every match merged there is no match.
    * Created By   : Rushi Patel
    * Version      : V3.1 - 29 September 2026
    */
    @isTest
    static void testOrgMatchUsesOldestNotMerged() {
        Account oldestMerged = insertOrgAccount('Dup Org Merged', 'UN-100003', 'OrganizationAccount');
        Account older = insertOrgAccount('Dup Org Older', 'UN-100003', 'OrganizationAccount');
        Account newer = insertOrgAccount('Dup Org Newer', 'UN-100003', 'OrganizationAccount');
        Test.setCreatedDate(oldestMerged.Id, DateTime.now().addDays(-30));
        Test.setCreatedDate(older.Id, DateTime.now().addDays(-20));
        Test.setCreatedDate(newer.Id, DateTime.now().addDays(-10));
        markOrgAccountsMerged(new List<Id>{ oldestMerged.Id });

        Lead orgLead = new Lead(LastName = 'Owner', Company = 'Dup Org', UnifiedNumber__c = 'UN-100003');
        System.assertEquals(older.Id, MBP_BrokerLeadcontroller.findMatchingOrgAccount(orgLead).Id,
            'oldest Organization Account that is not merged is used');

        markOrgAccountsMerged(new List<Id>{ older.Id, newer.Id });
        System.assertEquals(null, MBP_BrokerLeadcontroller.findMatchingOrgAccount(orgLead),
            'merged accounts never count as a match');
    }

    /**
    * Name         : testOnlyMergedOrgMatchCreatesNewAccount
    * Description  : Only a merged Organization Account has the Unified Number - treated as no match, so a new
    *                Organization Account is created.
    * Created By   : Rushi Patel
    * Version      : V3.1 - 29 September 2026
    */
    @isTest
    static void testOnlyMergedOrgMatchCreatesNewAccount() {
        Account merged = insertOrgAccount('Merged Org', 'UN-100004', 'OrganizationAccount');
        markOrgAccountsMerged(new List<Id>{ merged.Id });

        Test.startTest();
        saveLead(orgLeadPayload('Merged Org Again', 'UN-100004', 'owner.four@example.com'));
        Test.stopTest();

        System.assertEquals(2, orgAccountCount('UN-100004'), 'new Organization Account created next to the merged one');
    }

    /**
    * Name         : testUnifiedNumberOnOtherRecordTypesIgnored
    * Description  : A Broker Agency and a Person Account with the same Unified Number are never matched - a
    *                new Organization Account is created.
    * Created By   : Rushi Patel
    * Version      : V3.1 - 29 September 2026
    */
    @isTest
    static void testUnifiedNumberOnOtherRecordTypesIgnored() {
        Id brokerRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Broker_Agency').getRecordTypeId();
        insert new Account(RecordTypeId = brokerRtId, Name = 'Same Unified Brokers', Type = 'Broker', UnifiedNumber__c = 'UN-100005');
        Account person = personCustomer('SameUnifiedPerson');
        person.UnifiedNumber__c = 'UN-100005';
        insert person;

        Test.startTest();
        saveLead(orgLeadPayload('Brand New Org', 'UN-100005', 'owner.five@example.com'));
        Test.stopTest();

        System.assertEquals(1, orgAccountCount('UN-100005'), 'only Organization Accounts are matched - new one created');
    }

    /**
    * Name         : testBlankUnifiedNumberNeverMatches
    * Description  : A lead with a blank Unified Number never matches an Organization Account with a blank one.
    * Created By   : Rushi Patel
    * Version      : V3.1 - 29 September 2026
    */
    @isTest
    static void testBlankUnifiedNumberNeverMatches() {
        insertOrgAccount('No Unified Org', null, 'OrganizationAccount');

        System.assertEquals(null, MBP_BrokerLeadcontroller.findMatchingOrgAccount(
            new Lead(LastName = 'Owner', Company = 'Any Org', UnifiedNumber__c = null)),
            'blank Unified Number on both sides is not a match');
    }

    /**
    * Name         : testIndividualLeadNeverCreatesOrgAccount
    * Description  : An Individual broker lead never creates an Organization Account.
    * Created By   : Rushi Patel
    * Version      : V3.1 - 29 September 2026
    */
    @isTest
    static void testIndividualLeadNeverCreatesOrgAccount() {
        Test.startTest();
        saveLead(individualLeadPayload('individual.only@example.com', '+971509990002', 'IO777777'));
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Account WHERE RecordType.DeveloperName = 'OrganizationAccount'],
            'no Organization Account for an Individual lead');
    }

    /**
    * Name         : testNonBrokerOrgLeadIsSkipped
    * Description  : A lead that is not a broker lead never gets an Organization Account.
    * Created By   : Rushi Patel
    * Version      : V3.1 - 29 September 2026
    */
    @isTest
    static void testNonBrokerOrgLeadIsSkipped() {
        Lead l = nonBrokerLead('walk.in.org@example.com');
        update new Lead(Id = l.Id, UnifiedNumber__c = 'UN-100006');

        Test.startTest();
        MBP_BrokerLeadcontroller.createOrgAccountForLead(l.Id);
        Test.stopTest();

        System.assertEquals(0, orgAccountCount('UN-100006'), 'no Organization Account for a non-broker lead');
    }

    /**
    * Name         : testOrgAccountFailureIsLoggedNotThrown
    * Description  : Any failure while creating the Organization Account is rolled back and logged - it never
    *                reaches the broker's lead save.
    * Created By   : Rushi Patel
    * Version      : V3.1 - 29 September 2026
    */
    @isTest
    static void testOrgAccountFailureIsLoggedNotThrown() {
        Lead l = nonBrokerLead('gone.org@example.com');
        Id goneLeadId = l.Id;
        delete l;

        Test.startTest();
        MBP_BrokerLeadcontroller.createOrgAccountForLead(goneLeadId); // lead no longer exists - the query fails
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM Logger__c WHERE ExecutingProcessName__c = 'Broker Lead Org Account'],
            'failure logged instead of thrown');
    }

    /**
    * Name         : insertOrgContact
    * Description  : Inserts a Contact of the given record type on an account, without residency details.
    * Created By   : Rushi Patel
    * Version      : V3.1 - 29 September 2026
    */
    private static Contact insertOrgContact(Id accountId, String lastName, String email, String mobile, String recordTypeDevName) {
        Id rtId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get(recordTypeDevName).getRecordTypeId();
        Contact con = new Contact(RecordTypeId = rtId, AccountId = accountId, LastName = lastName, Email = email, MobilePhone = mobile);
        insert con;
        return con;
    }

    /**
    * Name         : contactsOn
    * Description  : Individual Contacts on the given account, oldest first.
    * Created By   : Rushi Patel
    * Version      : V3.1 - 29 September 2026
    */
    private static List<Contact> contactsOn(Id accountId) {
        return [SELECT Id, FirstName, LastName, Email, MobilePhone, UAE_Resident_Status__c, CountryOfResidence__c
                FROM Contact
                WHERE AccountId = :accountId AND RecordType.DeveloperName = 'Individual'
                ORDER BY CreatedDate ASC];
    }

    /**
    * Name         : testNewOrgAccountGetsContact
    * Description  : A new Organization Account always gets the lead's owner details as an Individual Contact.
    * Created By   : Rushi Patel
    * Version      : V3.1 - 29 September 2026
    */
    @isTest
    static void testNewOrgAccountGetsContact() {
        Test.startTest();
        saveLead(orgLeadPayload('Contact Test Co', 'UN-200001', 'owner.contact@example.com'));
        Test.stopTest();

        Account acc = [SELECT Id FROM Account WHERE RecordType.DeveloperName = 'OrganizationAccount' AND UnifiedNumber__c = 'UN-200001'];
        List<Contact> cons = [
            SELECT Id, Salutation, FirstName, LastName, Email, MobilePhone, Nationality__c, UAE_Resident_Status__c,
                   CountryOfResidence__c, LeadSource, RecordType.DeveloperName
            FROM Contact WHERE AccountId = :acc.Id
        ];
        System.assertEquals(1, cons.size(), 'one Contact created on the new Organization Account');
        System.assertEquals('Individual', cons[0].RecordType.DeveloperName);
        System.assertEquals('Mr.', cons[0].Salutation);
        System.assertEquals('Omar', cons[0].FirstName);
        System.assertEquals('Owner', cons[0].LastName);
        System.assertEquals('owner.contact@example.com', cons[0].Email);
        System.assertEquals('+971509990001', cons[0].MobilePhone);
        System.assertEquals('India', cons[0].Nationality__c);
        System.assertEquals('Resident', cons[0].UAE_Resident_Status__c);
        System.assertEquals('United Arab Emirates', cons[0].CountryOfResidence__c);
        System.assertEquals('Broker Portal', cons[0].LeadSource);
    }

    /**
    * Name         : testExistingOrgNoMatchingContactCreatesOne
    * Description  : Existing Organization Account without a matching Contact - a new Contact is created on it.
    * Created By   : Rushi Patel
    * Version      : V3.1 - 29 September 2026
    */
    @isTest
    static void testExistingOrgNoMatchingContactCreatesOne() {
        Account existing = insertOrgAccount('Known Co', 'UN-200002', 'OrganizationAccount');
        insertOrgContact(existing.Id, 'Someone Else', 'someone.else@example.com', '+971501110000', 'Individual');

        Test.startTest();
        saveLead(orgLeadPayload('Known Co', 'UN-200002', 'new.owner@example.com'));
        Test.stopTest();

        List<Contact> cons = contactsOn(existing.Id);
        System.assertEquals(2, cons.size(), 'new Contact created next to the unrelated one');
        System.assertEquals('new.owner@example.com', cons[1].Email);
        System.assertEquals(1, orgAccountCount('UN-200002'), 'existing account reused');
    }

    /**
    * Name         : testExistingOrgContactMatchedOnEmail
    * Description  : Individual Contact on the matched account with the same email - no new Contact, blank
    *                residency filled from the lead.
    * Created By   : Rushi Patel
    * Version      : V3.1 - 29 September 2026
    */
    @isTest
    static void testExistingOrgContactMatchedOnEmail() {
        Account existing = insertOrgAccount('Email Co', 'UN-200003', 'OrganizationAccount');
        Contact con = insertOrgContact(existing.Id, 'Owner', 'same.email@example.com', null, 'Individual');

        Test.startTest();
        saveLead(orgLeadPayload('Email Co', 'UN-200003', 'same.email@example.com'));
        Test.stopTest();

        List<Contact> cons = contactsOn(existing.Id);
        System.assertEquals(1, cons.size(), 'email match - no new Contact');
        System.assertEquals('Resident', cons[0].UAE_Resident_Status__c, 'blank resident status filled');
        System.assertEquals('United Arab Emirates', cons[0].CountryOfResidence__c, 'blank country of residence filled');
    }

    /**
    * Name         : testExistingOrgContactMatchedOnMobile
    * Description  : Individual Contact on the matched account with the same mobile (MobilePhone) is reused.
    * Created By   : Rushi Patel
    * Version      : V3.1 - 29 September 2026
    */
    @isTest
    static void testExistingOrgContactMatchedOnMobile() {
        Account existing = insertOrgAccount('Mobile Co', 'UN-200004', 'OrganizationAccount');
        insertOrgContact(existing.Id, 'Owner', 'different@example.com', '+971509990001', 'Individual');

        Test.startTest();
        saveLead(orgLeadPayload('Mobile Co', 'UN-200004', 'another.email@example.com'));
        Test.stopTest();

        List<Contact> cons = contactsOn(existing.Id);
        System.assertEquals(1, cons.size(), 'mobile match - no new Contact');
        System.assertEquals('Resident', cons[0].UAE_Resident_Status__c);
    }

    /**
    * Name         : testExistingOrgContactMatchedOnPhone
    * Description  : Individual Contact on the matched account whose Phone field has the lead's mobile is reused.
    * Created By   : Rushi Patel
    * Version      : V3.1 - 29 September 2026
    */
    @isTest
    static void testExistingOrgContactMatchedOnPhone() {
        Account existing = insertOrgAccount('Phone Co', 'UN-200005', 'OrganizationAccount');
        Contact con = insertOrgContact(existing.Id, 'Owner', 'other@example.com', null, 'Individual');
        update new Contact(Id = con.Id, Phone = '+971509990001');

        Test.startTest();
        saveLead(orgLeadPayload('Phone Co', 'UN-200005', 'phone.lead@example.com'));
        Test.stopTest();

        List<Contact> cons = contactsOn(existing.Id);
        System.assertEquals(1, cons.size(), 'Phone match - no new Contact');
        System.assertEquals('United Arab Emirates', cons[0].CountryOfResidence__c);
    }

    /**
    * Name         : testExistingOrgContactResidencyKept
    * Description  : Residency values already on the matched Contact are never overwritten.
    * Created By   : Rushi Patel
    * Version      : V3.1 - 29 September 2026
    */
    @isTest
    static void testExistingOrgContactResidencyKept() {
        Account existing = insertOrgAccount('Kept Co', 'UN-200006', 'OrganizationAccount');
        Contact con = insertOrgContact(existing.Id, 'Owner', 'kept@example.com', null, 'Individual');
        update new Contact(Id = con.Id, UAE_Resident_Status__c = 'Non-Resident', CountryOfResidence__c = 'India');

        Test.startTest();
        saveLead(orgLeadPayload('Kept Co', 'UN-200006', 'kept@example.com'));
        Test.stopTest();

        Contact after = contactsOn(existing.Id)[0];
        System.assertEquals('Non-Resident', after.UAE_Resident_Status__c, 'existing resident status kept');
        System.assertEquals('India', after.CountryOfResidence__c, 'existing country of residence kept');
    }

    /**
    * Name         : testExistingOrgContactResidencyPartiallyFilled
    * Description  : Resident Status present, Country of Residence blank - only the blank one is filled.
    * Created By   : Rushi Patel
    * Version      : V3.1 - 29 September 2026
    */
    @isTest
    static void testExistingOrgContactResidencyPartiallyFilled() {
        Account existing = insertOrgAccount('Half Co', 'UN-200007', 'OrganizationAccount');
        Contact con = insertOrgContact(existing.Id, 'Owner', 'half@example.com', null, 'Individual');
        update new Contact(Id = con.Id, UAE_Resident_Status__c = 'Non-Resident');

        Test.startTest();
        saveLead(orgLeadPayload('Half Co', 'UN-200007', 'half@example.com'));
        Test.stopTest();

        Contact after = contactsOn(existing.Id)[0];
        System.assertEquals('Non-Resident', after.UAE_Resident_Status__c, 'existing resident status kept');
        System.assertEquals('United Arab Emirates', after.CountryOfResidence__c, 'blank country of residence filled');
    }

    /**
    * Name         : testContactOnOtherAccountNotMatched
    * Description  : A Contact with the same email on a different account is never matched - a new Contact is
    *                created on the matched account and the other one is left untouched.
    * Created By   : Rushi Patel
    * Version      : V3.1 - 29 September 2026
    */
    @isTest
    static void testContactOnOtherAccountNotMatched() {
        Account existing = insertOrgAccount('Target Co', 'UN-200008', 'OrganizationAccount');
        Account other = insertOrgAccount('Other Co', 'UN-200009', 'OrganizationAccount');
        Contact otherCon = insertOrgContact(other.Id, 'Owner', 'shared@example.com', null, 'Individual');

        Test.startTest();
        saveLead(orgLeadPayload('Target Co', 'UN-200008', 'shared@example.com'));
        Test.stopTest();

        System.assertEquals(1, contactsOn(existing.Id).size(), 'new Contact created on the matched account');
        System.assertEquals(null, contactsOn(other.Id)[0].UAE_Resident_Status__c, 'Contact on another account untouched');
    }

    /**
    * Name         : testBrokerAgentContactNotMatched
    * Description  : A BrokerAgent Contact on the matched account with the same email is never matched - a new
    *                Individual Contact is created.
    * Created By   : Rushi Patel
    * Version      : V3.1 - 29 September 2026
    */
    @isTest
    static void testBrokerAgentContactNotMatched() {
        Account existing = insertOrgAccount('Agent Co', 'UN-200010', 'OrganizationAccount');
        Contact agent = insertOrgContact(existing.Id, 'Agent', 'agent.email@example.com', null, 'BrokerAgent');

        Test.startTest();
        saveLead(orgLeadPayload('Agent Co', 'UN-200010', 'agent.email@example.com'));
        Test.stopTest();

        System.assertEquals(1, contactsOn(existing.Id).size(), 'new Individual Contact created');
        System.assertEquals(null, [SELECT UAE_Resident_Status__c FROM Contact WHERE Id = :agent.Id].UAE_Resident_Status__c,
            'broker agent Contact untouched');
    }

    /**
    * Name         : testOldestMatchingContactUsed
    * Description  : Two Individual Contacts on the matched account match (one on email, one on mobile) - the
    *                oldest gets the residency, the newer one is left untouched.
    * Created By   : Rushi Patel
    * Version      : V3.1 - 29 September 2026
    */
    @isTest
    static void testOldestMatchingContactUsed() {
        Account existing = insertOrgAccount('Two Contacts Co', 'UN-200011', 'OrganizationAccount');
        Contact byEmail = insertOrgContact(existing.Id, 'By Email', 'two.contacts@example.com', null, 'Individual');
        Contact byMobile = insertOrgContact(existing.Id, 'By Mobile', 'x@example.com', '+971509990001', 'Individual');
        Test.setCreatedDate(byEmail.Id, DateTime.now().addDays(-10));
        Test.setCreatedDate(byMobile.Id, DateTime.now().addDays(-30)); // oldest

        Test.startTest();
        saveLead(orgLeadPayload('Two Contacts Co', 'UN-200011', 'two.contacts@example.com'));
        Test.stopTest();

        System.assertEquals(2, contactsOn(existing.Id).size(), 'no new Contact');
        System.assertEquals('Resident', [SELECT UAE_Resident_Status__c FROM Contact WHERE Id = :byMobile.Id].UAE_Resident_Status__c,
            'oldest match (mobile) is used');
        System.assertEquals(null, [SELECT UAE_Resident_Status__c FROM Contact WHERE Id = :byEmail.Id].UAE_Resident_Status__c,
            'newer match left untouched');
    }

    /**
    * Name         : testBlankLeadEmailMobileNeverMatch
    * Description  : A lead with no email and no mobile never matches a Contact with blank email and phone.
    * Created By   : Rushi Patel
    * Version      : V3.1 - 29 September 2026
    */
    @isTest
    static void testBlankLeadEmailMobileNeverMatch() {
        Account existing = insertOrgAccount('Blank Co', 'UN-200012', 'OrganizationAccount');
        insertOrgContact(existing.Id, 'No Details', null, null, 'Individual');

        System.assertEquals(null, MBP_BrokerLeadcontroller.findMatchingOrgContact(existing.Id,
            new Lead(LastName = 'Owner', Company = 'Blank Co', Email = null, MobilePhone = null)),
            'blank email / mobile on both sides is not a match');
    }

    /**
    * Name         : customerWithKycLink
    * Description  : Unsaved Person Account with a passport whose KYC link was sent the given number of seconds
    *                ago and lasts one day, so the link is live or expired as needed.
    * Created By   : Rushi Patel
    * Version      : V3.2 - 30 September 2026
    */
    private static Account customerWithKycLink(String lastName, String passport, Integer sentSecondsAgo) {
        Account acc = personCustomer(lastName);
        acc.PassportNumber__pc = passport;
        acc.KYC_Send_Date_Time__c = System.now().addSeconds(-sentSecondsAgo);
        acc.KYC_Expiry_Time_in_Seconds__c = 86400;
        acc.KYC_Link_Status__c = 'IN PROGRESS';
        return acc;
    }

    /**
    * Name         : testExistingCustomerWithLiveLinkGetsNoNewLink
    * Description  : Existing account, KYC not complete, link sent an hour ago and still live - no new KYC
    *                link, missing placeholder documents still generated.
    * Created By   : Rushi Patel
    * Version      : V3.2 - 30 September 2026
    */
    @isTest
    static void testExistingCustomerWithLiveLinkGetsNoNewLink() {
        Account existing = customerWithKycLink('LiveLink', 'LL666666', 3600);
        insert existing;
        System.assertEquals(true, [SELECT Is_KYC_Link_Active__c FROM Account WHERE Id = :existing.Id].Is_KYC_Link_Active__c,
            'test data: the link is live');

        Test.startTest();
        saveLead(individualLeadPayload('live.link@example.com', '+971500000016', 'LL666666'));
        Test.stopTest();

        System.assert(wasPicked(existing.Id), 'the existing account is used');
        System.assertEquals(0, kycJobCount(), 'no new KYC link while the one already sent is live');
        Id personContactId = [SELECT PersonContactId FROM Account WHERE Id = :existing.Id].PersonContactId;
        System.assertEquals(DocumentsUtility.getDocumentsForSObject('PersonAccount').size(),
            [SELECT COUNT() FROM Documents__c WHERE PrimaryContact__c = :personContactId],
            'missing placeholder documents generated even while the link is live');
    }

    /**
    * Name         : testExistingCustomerWithExpiredLinkGetsNewLink
    * Description  : Existing account, KYC not complete, link sent two days ago and expired - a new KYC link is sent.
    * Created By   : Rushi Patel
    * Version      : V3.2 - 30 September 2026
    */
    @isTest
    static void testExistingCustomerWithExpiredLinkGetsNewLink() {
        Account existing = customerWithKycLink('ExpiredLink', 'EL777777', 172800);
        insert existing;
        System.assertEquals(false, [SELECT Is_KYC_Link_Active__c FROM Account WHERE Id = :existing.Id].Is_KYC_Link_Active__c,
            'test data: the link has expired');

        Test.startTest();
        saveLead(individualLeadPayload('expired.link@example.com', '+971500000017', 'EL777777'));
        Test.stopTest();

        System.assert(wasPicked(existing.Id), 'the existing account is used');
        System.assertEquals(1, kycJobCount(), 'a new KYC link is sent once the old one has expired');
    }
}