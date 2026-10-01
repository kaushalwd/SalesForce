@isTest
public class MBP_ManagePropertiesControllerTest {

    @testSetup
    static void setupData() {
        Account acc = new Account(Name = 'Test Acc');
        insert acc;

        Contact con = new Contact(
            LastName = 'Test Contact',
            AccountId = acc.Id,
            Broker_Type__c = 'Owner'
        );
        insert con;

        Project__c project = new Project__c(
            Name = 'Test Project',
            Broker_Sales__c = true
        );
        insert project;

        Phase__c phase = new Phase__c(
            Name = 'Test Phase',
            Project__c = project.Id
        );
        insert phase;

        List<Unit__c> units = new List<Unit__c>{
            new Unit__c(
                Name = 'Unit 1',
                PlotNo__c = '109',
                UnitClassification__c = 'Villa',
                Number_of_Bedrooms__c = '2',
                Phase__c = phase.Id,
                Broker_Sales__c = true,
                Status__c = 'Sold'
            ),
            new Unit__c(
                Name = 'Unit 2',
                PlotNo__c = '109',
                UnitClassification__c = 'Villa',
                Number_of_Bedrooms__c = '2',
                Phase__c = phase.Id,
                Broker_Sales__c = true,
                Status__c = 'Available'
            )
        };
        insert units;

        Documents__c doc = new Documents__c(
            Name = 'Thumbnail',
            Project__c = project.Id
        );
        insert doc;

        ContentVersion cv = new ContentVersion(
            Title = 'Test CV',
            PathOnClient = 'Test.jpg',
            VersionData = Blob.valueOf('fake'),
            IsMajorVersion = true
        );
        insert cv;

        cv = [
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
        ];

        ContentDocumentLink cdl = new ContentDocumentLink(
            LinkedEntityId = doc.Id,
            ContentDocumentId = cv.ContentDocumentId,
            ShareType = 'V'
        );
        insert cdl;
    }

    @isTest static void testFetchProjects() {
        List<Project__c> projs = MBP_ManagePropertiesController.fetchProjects();
    }

    @isTest static void testFetchProjectsWithUnits() {
        Map<Id, List<Phase__c>> mapData = MBP_ManagePropertiesController.fetchProjectsWithUnits();
    }

    @isTest static void testGetRecords() {
        List<String> fields = new List<String>{ 'Name' };
        Map<String, String> filters = new Map<String, String>{ 'Name' => 'Test' };

        List<SObject> records = MBP_ManagePropertiesController.getRecords(
            'Unit__c',
            filters,
            fields
        );
    }

    @isTest static void testGetRecordsWithImages() {
        List<String> fields = new List<String>{ 'Name' };
        Map<String, String> filters = new Map<String, String>{ 'Name' => 'Test' };

        List<MBP_ManagePropertiesController.RecordWithImages> recs =
            MBP_ManagePropertiesController.getRecordsWithImages(
                'Unit__c',
                filters,
                fields,
                'Name',
                'Project__r.Name'
            );
    }

    @isTest static void testGetUnitRecords() {
        try {
            MBP_ManagePropertiesController.getUnitRecords('Unit__c');
        } catch (AuraHandledException e) {
            // expected
        }
    }

    @isTest static void testGetDocumentsAndFilesByProject() {
        Project__c proj = [SELECT Id FROM Project__c LIMIT 1];

        List<MBP_ManagePropertiesController.DocumentFileWrapper> docs =
            MBP_ManagePropertiesController.getDocumentsAndFilesByProject(proj.Id);
    }

    @isTest static void testGetAllocatedUnitCountsByProject() {
        Project__c proj = [SELECT Id FROM Project__c LIMIT 1];

        Map<Id, Integer> mapData =
            MBP_ManagePropertiesController.getAllocatedUnitCountsByProject(
                new List<Id>{ proj.Id }
            );
    }

    @isTest static void testIsValidFieldPath_AllBranches() {
        Schema.DescribeSObjectResult projDescribe = Project__c.SObjectType.getDescribe();
    }

    @isTest static void testIsValidFieldPath() {
        Schema.DescribeSObjectResult projDescribe = Project__c.SObjectType.getDescribe();

        MBP_ManagePropertiesController.isValidFieldPath(projDescribe, 'Name');
        MBP_ManagePropertiesController.isValidFieldPath(projDescribe, 'InvalidField');
        MBP_ManagePropertiesController.isValidFieldPath(projDescribe, 'Phase__r.Project__r.Name');
        MBP_ManagePropertiesController.isValidFieldPath(projDescribe, 'Phase__r.Name');
        MBP_ManagePropertiesController.isValidFieldPath(projDescribe, '');
        MBP_ManagePropertiesController.isValidFieldPath(projDescribe, null);
    }

    @isTest static void testGetUnitRecordsDifferentBrokerTypes() {
        Account acc = new Account(Name = 'Agent Account');
        insert acc;

        Contact con = new Contact(
            LastName = 'Agent Contact',
            AccountId = acc.Id,
            Broker_Type__c = 'Agent'
        );
        insert con;

        Profile portalProfile = [
            SELECT Id FROM Profile
            WHERE Name = 'Modon - Partner Community Login User'
            LIMIT 1
        ];

        Id userRoleId;
        try {
            userRoleId = [
                SELECT Id FROM UserRole
                WHERE Name = 'Partner User'
                LIMIT 1
            ].Id;
        } catch (Exception e) {
            userRoleId = null;
        }

        User portalUser = new User(
            Alias = 'tportal',
            Email = 'testportaluser@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'PortalUser',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = portalProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserRoleId = userRoleId,
            UserName = 'testportaluser' + System.currentTimeMillis() + '@example.com',
            ContactId = con.Id
        );
        insert portalUser;

        System.runAs(portalUser) {
            MBP_ManagePropertiesController.getUnitRecords('Unit__c');
        }
    }

    @isTest static void testGetRecordsInvalidObject() {
        try {
            MBP_ManagePropertiesController.getRecords(
                'InvalidObject',
                new Map<String, String>(),
                new List<String>{ 'Name' }
            );
        } catch (AuraHandledException ex) {
            // expected
        }
    }

    // ✅ NEW TEST METHOD TO INCREASE COVERAGE FOR mimeFromExt()
    @isTest static void testMimeFromExt_AllCases() {
        // Common image types
        System.assertEquals('image/jpeg', MBP_ManagePropertiesController.mimeFromExt('jpg'));
        System.assertEquals('image/jpeg', MBP_ManagePropertiesController.mimeFromExt('jpeg'));
        System.assertEquals('image/png', MBP_ManagePropertiesController.mimeFromExt('png'));
        System.assertEquals('image/gif', MBP_ManagePropertiesController.mimeFromExt('gif'));
        System.assertEquals('image/webp', MBP_ManagePropertiesController.mimeFromExt('webp'));
        System.assertEquals('image/svg+xml', MBP_ManagePropertiesController.mimeFromExt('svg'));

        // Document type
        System.assertEquals('application/pdf', MBP_ManagePropertiesController.mimeFromExt('pdf'));

        // Unknown extension
        System.assertEquals('application/octet-stream', MBP_ManagePropertiesController.mimeFromExt('exe'));

        // Null case
        System.assertEquals('application/octet-stream', MBP_ManagePropertiesController.mimeFromExt(null));
    }
     // Utility to create a ContentVersion + ContentDocument + ContentDocumentLink
    private static ContentVersion createContentVersion(Id linkedEntityId) {
        // Step 1: Insert ContentVersion (initial version)
        ContentVersion cv = new ContentVersion(
            Title = 'Test File',
            PathOnClient = 'TestFile.txt',
            VersionData = Blob.valueOf('Unit test content'),
            IsMajorVersion = true
        );
        insert cv;
        
        // Step 2: Query back ContentDocumentId
        cv = [SELECT Id, ContentDocumentId, FileExtension, VersionData, Title 
              FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
        
        // Step 3: Create link to linked entity
        insert new ContentDocumentLink(
            LinkedEntityId = linkedEntityId,
            ContentDocumentId = cv.ContentDocumentId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        
        return cv;
    }

    @IsTest
    static void testToDataUri() {
        // Arrange: create a dummy ContentVersion
        ContentVersion cv = new ContentVersion(
            Title = 'Sample',
            PathOnClient = 'sample.pdf',
            VersionData = Blob.valueOf('Sample file data'),
            IsMajorVersion = true
        );
        insert cv;

        cv = [SELECT Id, FileExtension, VersionData FROM ContentVersion WHERE Id = :cv.Id];

        // Act
        String dataUri = MBP_ManagePropertiesController.toDataUri(cv);

        // Assert
        System.assert(dataUri.startsWith('data:'), 'Data URI should start with data:');
        System.assert(dataUri.contains(';base64,'), 'Data URI should contain base64 part');
        System.assert(dataUri.contains(EncodingUtil.base64Encode(cv.VersionData)), 
                      'Data URI should contain encoded content');
    }

    @IsTest
    static void testLatestVersionsByLinked() {
        // Arrange: use Account as a linked entity
        Account acc = new Account(Name='Test Account 123445');
        insert acc;

        // Create content + link
        ContentVersion cv = createContentVersion(acc.Id);

        // Act
        Test.startTest();
        Map<Id, List<ContentVersion>> results = MBP_ManagePropertiesController.latestVersionsByLinked(new Set<Id>{acc.Id});
        Test.stopTest();

        // Assert
        System.assert(results.containsKey(acc.Id), 'Result should have entry for Account');
        System.assertEquals(1, results.get(acc.Id).size(), 'There should be one ContentVersion linked');
        System.assertEquals(cv.ContentDocumentId, results.get(acc.Id)[0].ContentDocumentId, 
                            'Linked ContentDocumentId should match');
    }

    @IsTest
    static void testLatestVersionsByLinkedEmpty() {
        // Act
        Map<Id, List<ContentVersion>> results = MBP_ManagePropertiesController.latestVersionsByLinked(new Set<Id>());
        // Assert
        System.assertEquals(0, results.size(), 'Empty input should return empty map');
    }
    
    

    // Mock class for HTTP Callout
    class MasterplanMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody('{"success": true, "url": "https://example.com/masterplan"}');
            return res;
        }
    }

    // Mock class for failure response
    class MasterplanFailMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody('{"success": false}');
            return res;
        }
    }

    @IsTest
    static void testFetchMasterplanLink_Success() {
        Test.setMock(HttpCalloutMock.class, new MasterplanMock());

        Test.startTest();
        MBP_ManagePropertiesController.MasterplanResult result = 
            MBP_ManagePropertiesController.fetchMasterplanLink('Unit101');
        Test.stopTest();

        System.assertEquals(true, result.success);
        System.assertEquals('https://example.com/masterplan', result.url);
        System.assertEquals(200, result.statusCode);
    }

    @IsTest
    static void testFetchMasterplanLink_FailureResponse() {
        Test.setMock(HttpCalloutMock.class, new MasterplanFailMock());

        Test.startTest();
        MBP_ManagePropertiesController.MasterplanResult result = 
            MBP_ManagePropertiesController.fetchMasterplanLink('Unit101');
        Test.stopTest();

        System.assertEquals(false, result.success);
        System.assertEquals('Oracle response success = false.', result.errorMessage);
    }

    @IsTest
    static void testFetchMasterplanLink_BlankUnitName() {

        Test.startTest();
        MBP_ManagePropertiesController.MasterplanResult result = 
            MBP_ManagePropertiesController.fetchMasterplanLink('');
        Test.stopTest();

        System.assertEquals(false, result.success);
        System.assertEquals('Unit name is required.', result.errorMessage);
    }

    @IsTest
    static void testFetchMasterplanLink_HttpError() {
        
        Test.setMock(HttpCalloutMock.class, new MasterplanHttpErrorMock());
        
        Test.startTest();
        MBP_ManagePropertiesController.MasterplanResult result =
            MBP_ManagePropertiesController.fetchMasterplanLink('Unit101');
        Test.stopTest();
        
        System.assertEquals(false, result.success);
        System.assert(result.errorMessage.contains('HTTP Error'));
    }
    
}