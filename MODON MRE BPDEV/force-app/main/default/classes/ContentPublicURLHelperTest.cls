@isTest
private class ContentPublicURLHelperTest {

    @TestSetup
    static void makeData(){
        Project__c proj = new Project__c(Name = 'Jupiter');
        insert proj;

        Phase__c phase = new Phase__c(Name = 'Phase 1', Project__c = proj.Id);
        insert phase;
        
        Milestone__c milestone = new Milestone__c(Type__c='Progress Based',Phase__c = phase.Id,Milestone_Due_Date__c = system.today().addDays(45),
            Project__c = proj.Id,Name ='QAJupMilestoneTest1'
        );
        insert milestone;

        Unit__c unit = new Unit__c(Name = 'Unit A', Phase__c = phase.Id, PlotNo__c = '101', UnitClassification__c = 'Villa', Type__c = 'G+1',Number_of_Bedrooms__c ='1');
        insert unit;

        unit = [SELECT Id, Phase__r.Project__r.Name FROM Unit__c WHERE Id = :unit.Id];
        System.debug('Unit Project Name: ' + unit.Phase__r.Project__r.Name);

       
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        ContentVersion cv1 = new ContentVersion(
            Title = 'Test Document 1',
            PathOnClient = 'TestDoc1.pdf',
            VersionData = Blob.valueOf('This is a test file.'),
            IsMajorVersion = true
        );
        insert cv1;

        ContentVersion cv2 = new ContentVersion(
            Title = 'Another Test File',
            PathOnClient = 'AnotherTest.txt',
            VersionData = Blob.valueOf('Some more test data.'),
            IsMajorVersion = true
        );
        insert cv2;

        List<ContentVersion> insertedVersions = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id IN (:cv1.Id, :cv2.Id)];
        Map<Id, Id> cvIdToCdIdMap = new Map<Id, Id>();
        for(ContentVersion v : insertedVersions) {
            cvIdToCdIdMap.put(v.Id, v.ContentDocumentId);
        }

        ContentDocumentLink cdl1 = new ContentDocumentLink(
            ContentDocumentId = cvIdToCdIdMap.get(cv1.Id),
            LinkedEntityId = acc.Id,
            ShareType = 'V'
        );
        ContentDocumentLink cdl2 = new ContentDocumentLink(
            ContentDocumentId = cvIdToCdIdMap.get(cv2.Id),
            LinkedEntityId = acc.Id,
            ShareType = 'V'
        );
        insert new List<ContentDocumentLink>{cdl1, cdl2};
        
        SalesOrder__c so = new SalesOrder__c(CustomerAccount__c = acc.Id, Status__c = 'Completed', TotalAmount__c = 50000, Unit__c = unit.Id,  FacadeStyle__c = 'South California');
        insert so;
        
        
        Documents__c docRecord = new Documents__c(
            Name = 'Exterior'
        );
        
        Account unitParent = new Account(Name='Test Unit');
        insert unitParent;
        
        so.Unit__c = unit.Id;
        docRecord.Unit__c = unit.Id;
        
       
        insert docRecord;
        
        ContentVersion cvForDoc1 = new ContentVersion(
            Title = 'South California.jpg',
            PathOnClient = 'South California.jpg',
            VersionData = Blob.valueOf('Classic Style'),
            IsMajorVersion = true,
            Public_Link__c = 'http://example.com/classic'
        );
        ContentVersion cvForDoc2 = new ContentVersion(
            Title = 'Not Selected.jpg',
            PathOnClient = 'Not Selected.jpg',
            VersionData = Blob.valueOf('Modern Style'),
            IsMajorVersion = true,
            Public_Link__c = 'http://example.com/modern'
        );
        insert new List<ContentVersion>{cvForDoc1, cvForDoc2};
        
        Id cdIdForDoc1 = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cvForDoc1.Id].ContentDocumentId;
        Id cdIdForDoc2 = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cvForDoc2.Id].ContentDocumentId;
        
        ContentDocumentLink cdlForDoc1 = new ContentDocumentLink(
            ContentDocumentId = cdIdForDoc1,
            LinkedEntityId = docRecord.Id,
            ShareType = 'V'
        );
        ContentDocumentLink cdlForDoc2 = new ContentDocumentLink(
            ContentDocumentId = cdIdForDoc2,
            LinkedEntityId = docRecord.Id,
            ShareType = 'V'
        );
        insert new List<ContentDocumentLink>{cdlForDoc1, cdlForDoc2};

    }

    @isTest
    static void testGetLatestContentVersionIdByRecord_Success() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
        ContentVersion cv = [SELECT Id FROM ContentVersion WHERE Title = 'Another Test File' ORDER BY CreatedDate DESC LIMIT 1];

        Test.startTest();
        Id latestVersionId = ContentPublicURLHelper.getLatestContentVersionIdByRecord(acc.Id);
        Test.stopTest();
        
       
    }

    @isTest
    static void testGetLatestContentVersionIdByRecord_NoFile() {
        Account accWithNoFiles = new Account(Name='Account with No Files');
        insert accWithNoFiles;

        Test.startTest();
        try {
            ContentPublicURLHelper.getLatestContentVersionIdByRecord(accWithNoFiles.Id);
        } catch (AuraHandledException e) {
        }
        Test.stopTest();
    }

    @isTest
    static void testGetLatestContentVersionIdByRecordList_Success() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];

        Test.startTest();
        Set<Id> versionIds = ContentPublicURLHelper.getLatestContentVersionIdByRecordList(acc.Id);
        Test.stopTest();

    }
    
    @isTest
    static void testGeneratePublicLink_Success() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
        Set<Id> recordIdSet = new Set<Id>{ acc.Id };

        Test.startTest();
        Map<Id, String> publicUrlMap = ContentPublicURLHelper.generatePublicLink(recordIdSet);
        Test.stopTest();
       
    }

    @isTest
    static void testGetPublicURLByContentVersionId_Success() {
        Account acc = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
        Set<Id> recordIdSet = new Set<Id>{ acc.Id };
        
        Set<Id> initialVersionIds = ContentPublicURLHelper.getLatestContentVersionIdByRecordList(acc.Id);

        Test.startTest();
        ContentPublicURLHelper.getPublicURLByContentVersionId(recordIdSet);
        Test.stopTest();

        List<ContentVersion> updatedVersions = [SELECT Id, Public_Link__c FROM ContentVersion WHERE Id IN :initialVersionIds];
       
    }

    @isTest
    static void testGetPublicLinkoftheContent_Success() {
        SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];

        Test.startTest();
        String publicUrl = ContentPublicURLHelper.getPublicLinkoftheContent(so.Id);
        Test.stopTest();
      
    }
    
    @isTest
    static void testGetPublicLinkoftheContent_NoMatch() {
        SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];
     
        so.FacadeStyle__c = 'South California';
        update so;
        
        Test.startTest();
        String publicUrl = ContentPublicURLHelper.getPublicLinkoftheContent(so.Id);
        Test.stopTest();
        
    }
    
    @isTest
    static void testGetAccountIbanDistributionUrls() {
        
        // Existing Account from TestSetup
        Account acc = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
        Contact con = new Contact(LastName = 'Test con', AccountId = acc.Id);
        insert con;
        
        // Create Invoice
        Invoice__c inv = new Invoice__c(
            Account__c = acc.Id
        );
        insert inv;
        
        // Create IBAN Document
        Documents__c ibanDoc = new Documents__c(
            Name = 'IBAN Letter',
            PrimaryContact__c = con.Id
        );
        insert ibanDoc;
        
        // Upload File
        ContentVersion cv = new ContentVersion(
            Title = 'IBAN Letter.pdf',
            PathOnClient = 'IBAN Letter.pdf',
            VersionData = Blob.valueOf('IBAN Test File'),
            IsMajorVersion = true
        );
        insert cv;
        
        // Get ContentDocumentId
        Id contentDocId = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
        ].ContentDocumentId;
        
        // Link file to Documents__c
        insert new ContentDocumentLink(
            ContentDocumentId = contentDocId,
            LinkedEntityId = ibanDoc.Id,
            ShareType = 'V'
        );
        
        Test.startTest();
        
        Map<Id,String> result =
            ContentPublicURLHelper.getAccountIbanDistributionUrls(
                new Set<String>{ String.valueOf(inv.Id) }
            );
        
        Test.stopTest();
        
        System.assertEquals(1, result.size());
    }
}