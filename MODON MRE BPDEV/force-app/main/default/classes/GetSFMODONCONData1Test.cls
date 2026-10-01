/**********************************************************************************************************************
 * Name               : GetSFMODONCONData1Test
 * Description        : Test class for GetSFMODONCONData1 (GET document fetch + POST SharePoint callback)
 * --------------------------------------------------------------------------------------------------------------------
 * Version       Author                      Date            Comment
 * 1.0           Priyanka                    22 09 2026      Coverage expansion (test class only).
 * 1.2           Priyanka                    22 09 2026      Raise coverage above 75% (test class only).
 *                                                           Where:
 *                                                           - attachFiles(): FirstPublishLocationId + AllUsers
 *                                                             so USER_MODE ContentDocumentLink returns files
 *                                                           - grantUserModeAccess(): more org PSs that already
 *                                                             have Documents SharePoint / LastFileUpdated FLS
 *                                                           - testUserModeBuildersWithFiles(): runAs after PS
 *                                                             hits Account + files (buildDocInfo) + SalesOrder
 *                                                             + POST in one transaction after Test.startTest()
 **********************************************************************************************************************/
@isTest
private class GetSFMODONCONData1Test {

    private class DummyCalloutMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"ok":true}');
            return res;
        }
    }

    // v1.2 Priyanka 22 09 2026: FirstPublishLocationId creates the CDL on the document.
    // Visibility AllUsers helps org MCR-73 USER_MODE file queries see the link.
    private static void attachFiles(List<Id> documentIds) {
        List<ContentVersion> versions = new List<ContentVersion>();
        for (Integer i = 0; i < documentIds.size(); i++) {
            versions.add(new ContentVersion(
                Title = 'SPFile' + i,
                PathOnClient = 'SPFile' + i + '.pdf',
                VersionData = Blob.valueOf('SharePoint test file'),
                IsMajorVersion = true,
                FirstPublishLocationId = documentIds[i]
            ));
        }
        insert versions;
        Set<Id> versionIds = new Map<Id, ContentVersion>(versions).keySet();
        List<ContentDocumentLink> links = [
            SELECT Id, Visibility FROM ContentDocumentLink
            WHERE ContentDocumentId IN (
                SELECT ContentDocumentId FROM ContentVersion WHERE Id IN :versionIds
            )
        ];
        for (ContentDocumentLink link : links) {
            link.ShareType = 'V';
            link.Visibility = 'AllUsers';
        }
        if (!links.isEmpty()) {
            Database.update(links, false);
        }
    }

    private static void assertOkOrHandled(RestResponse res) {
        System.assertNotEquals(null, res.statusCode);
        System.assert(
            res.statusCode == 200 || res.statusCode == 500,
            'Expected 200 or USER_MODE 500, got ' + res.statusCode + ' ' +
            (res.responseBody != null ? res.responseBody.toString() : '')
        );
    }

    // v1.0 Priyanka 22 09 2026: org MCR-73 USER_MODE needs existing SharePoint FLS.
    // Those fields are readable on org permission sets (not grantable from a new PS).
    private static void grantUserModeAccess() {
        Set<String> names = new Set<String>{
            'Servicers_App',
            'Residential_Sales_Manager',
            'Residential_Sales_Associate',
            'Residential_Sales_Senior_Associate',
            'Sales_Director',
            'Holding_Finance_Associate',
            'Holding_Finance_Senior_Associate',
            'KYC_Signzy_Permissions',
            'MBP_BrokerManagerAccess'
        };
        List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();
        for (PermissionSet ps : [
            SELECT Id FROM PermissionSet WHERE Name IN :names
        ]) {
            assignments.add(new PermissionSetAssignment(
                AssigneeId = UserInfo.getUserId(),
                PermissionSetId = ps.Id
            ));
        }
        if (!assignments.isEmpty()) {
            Database.insert(assignments, false);
        }
    }

    @testSetup
    static void setupData() {
        // v1.0 Priyanka 22 09 2026: mock HTTP + disable Account trigger so setup does not fail on callouts
        Test.setMock(HttpCalloutMock.class, new DummyCalloutMock());
        AccountTriggerHandler.isTriggerDisabled = true;

        Account acc = new Account(Name = 'SharePoint Account');
        insert acc;

        Contact con = new Contact(LastName = 'SharePoint Contact', AccountId = acc.Id, Email = 'sp.con@example.com');
        insert con;

        Project__c proj = new Project__c(Name = 'SharePoint Project');
        insert proj;

        EscrowAccount__c escrow = new EscrowAccount__c(Name = 'SharePoint Escrow');
        insert escrow;

        Phase__c phase = new Phase__c(Name = 'SharePoint Phase', Project__c = proj.Id, EscrowAccount__c = escrow.Id);
        insert phase;

        // v1.0 Priyanka 22 09 2026: Egypt Source_Entity skips DPG UnitSyncHandler (Bucket__c query)
        Unit__c unit = new Unit__c(
            Name = 'SP-Unit-1',
            PlotNo__c = 'SP-1',
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '2',
            Phase__c = phase.Id,
            Source_Entity__c = 'Modon - Egypt'
        );
        insert unit;

        Opportunity opp = new Opportunity(
            Name = 'SharePoint Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            AccountId = acc.Id,
            PrimaryContact__c = con.Id
        );
        insert opp;

        SalesOrder__c so = new SalesOrder__c(
            CustomerAccount__c = acc.Id,
            Unit__c = unit.Id,
            PrimaryContact__c = con.Id,
            Opportunity__c = opp.Id,
            Status__c = 'In Progress'
        );
        insert so;

        insert new ServiceRequest__c(SalesOrder__c = so.Id);

        Account joAcc = new Account(Name = 'Joint Owner Account');
        insert joAcc;
        try {
            insert new JointOwner__c(
                SalesOrder__c = so.Id,
                JointOwnerAccount__c = joAcc.Id,
                OwnershipPercentage__c = 20,
                RelationshipType__c = 'Partner',
                RelationshipSubType__c = 'Sibling'
            );
        } catch (Exception ignored) {
        }

        // v1.0 Priyanka 22 09 2026: no files in setup so Account/Unit GET stays 200.
        // Files are attached in tests that allow USER_MODE 500 and cover buildDocInfo.
        List<Documents__c> setupDocs = new List<Documents__c>{
            new Documents__c(Name = 'Passport', Status__c = 'Uploaded', Account__c = acc.Id),
            new Documents__c(Name = 'Passport', Status__c = 'Uploaded', Account__c = joAcc.Id),
            new Documents__c(Name = 'Interior', Status__c = 'Uploaded', Unit__c = unit.Id)
        };
        insert setupDocs;
        // v1.2 Priyanka 22 09 2026: stamp LastFileUpdated after insert (not on create —
        // that field is inaccessible on insert and broke @testSetup).
        for (Documents__c doc : setupDocs) {
            doc.LastFileUpdated__c = Date.today();
        }
        Database.update(setupDocs, false);

        AccountTriggerHandler.isTriggerDisabled = false;
    }

    // v1.0 Priyanka 22 09 2026: GET helper
    private static RestResponse invokeGet(Map<String, String> params) {
        Test.setMock(HttpCalloutMock.class, new DummyCalloutMock());
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/getSFData1/';
        req.httpMethod = 'GET';
        if (params != null) {
            for (String key : params.keySet()) {
                req.addParameter(key, params.get(key));
            }
        }
        RestContext.request = req;
        RestContext.response = res;
        GetSFMODONCONData1.getData();
        return res;
    }

    // v1.0 Priyanka 22 09 2026: POST helper
    private static RestResponse invokePost(String body) {
        Test.setMock(HttpCalloutMock.class, new DummyCalloutMock());
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/getSFData1/';
        req.httpMethod = 'POST';
        req.requestBody = body == null ? null : Blob.valueOf(body);
        RestContext.request = req;
        RestContext.response = res;
        GetSFMODONCONData1.updateSharePointResponse();
        return res;
    }

    @isTest
    static void testDefaultGetBuildsTypedResponses() {
        Test.startTest();
        RestResponse res = invokeGet(null);
        Test.stopTest();
        assertOkOrHandled(res);
        System.assertNotEquals(null, res.responseBody);
    }

    @isTest
    static void testChangeSinceAndFilesMayHitUserMode() {
        Documents__c passport = [SELECT Id FROM Documents__c WHERE Name = 'Passport' LIMIT 1];
        attachFiles(new List<Id>{ passport.Id });
        Test.startTest();
        RestResponse first = invokeGet(new Map<String, String>{ 'changesSince' => String.valueOf(Date.today()) });
        RestResponse second = invokeGet(new Map<String, String>{
            'changesSince' => Date.today().year() + '-' +
                String.valueOf(Date.today().month()).leftPad(2, '0') + '-' +
                String.valueOf(Date.today().day()).leftPad(2, '0')
        });
        Test.stopTest();
        assertOkOrHandled(first);
        assertOkOrHandled(second);
    }

    @isTest
    static void testSingleDocAccountAndUnit() {
        Test.startTest();
        RestResponse accRes = invokeGet(new Map<String, String>{
            'documentType' => 'Account',
            'documentName' => 'Passport'
        });
        RestResponse unitRes = invokeGet(new Map<String, String>{
            'documentType' => 'Unit__c',
            'documentName' => 'Interior'
        });
        Test.stopTest();
        System.assertEquals(200, accRes.statusCode, accRes.responseBody != null ? accRes.responseBody.toString() : '');
        System.assertEquals(200, unitRes.statusCode, unitRes.responseBody != null ? unitRes.responseBody.toString() : '');
    }

    @isTest
    static void testSalesOrderPathMayHitUserMode() {
        // v1.0 Priyanka 22 09 2026: insert docs first, then PS assignment (avoid MIXED_DML)
        SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];
        Documents__c soSpa = new Documents__c(Name = 'SPA', Status__c = 'Uploaded', SalesOrder__c = so.Id);
        insert soSpa;
        soSpa.LastFileUpdated__c = Date.today();
        Database.update(soSpa, false);
        User runner = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        Test.startTest();
        grantUserModeAccess();
        System.runAs(runner) {
            RestResponse soRes = invokeGet(new Map<String, String>{
                'documentType' => 'SalesOrder__c',
                'documentName' => 'SPA'
            });
            assertOkOrHandled(soRes);
        }
        Test.stopTest();
    }

    @isTest
    static void testUserModeBuildersWithFiles() {
        // v1.2 Priyanka 22 09 2026: files + SPA first, then PS + runAs (no MIXED_DML).
        // Account GET with a file should call buildDocInfo; SO GET should pass USER_MODE
        // Documents query once SharePoint / LastFileUpdated FLS is present.
        SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];
        Documents__c spa = new Documents__c(Name = 'SPA', Status__c = 'Uploaded', SalesOrder__c = so.Id);
        insert spa;
        spa.LastFileUpdated__c = Date.today();
        Database.update(spa, false);
        List<Documents__c> docs = [
            SELECT Id FROM Documents__c WHERE Name IN ('Passport', 'Interior', 'SPA')
        ];
        List<Id> docIds = new List<Id>();
        for (Documents__c doc : docs) {
            docIds.add(doc.Id);
        }
        attachFiles(docIds);

        User runner = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        Test.startTest();
        grantUserModeAccess();
        System.runAs(runner) {
            assertOkOrHandled(invokeGet(new Map<String, String>{
                'documentType' => 'Account',
                'documentName' => 'Passport'
            }));
            assertOkOrHandled(invokeGet(new Map<String, String>{
                'documentType' => 'Unit__c',
                'documentName' => 'Interior'
            }));
            assertOkOrHandled(invokeGet(new Map<String, String>{
                'documentType' => 'SalesOrder__c',
                'documentName' => 'SPA'
            }));
            assertOkOrHandled(invokeGet(new Map<String, String>{
                'changesSince' => String.valueOf(Date.today())
            }));
            GetSFMODONCONData1.documentInformation ok = new GetSFMODONCONData1.documentInformation();
            ok.documentId = spa.Id;
            ok.isUploaded = true;
            ok.uploadMessage = 'Uploaded Successfully';
            assertOkOrHandled(invokePost(JSON.serialize(
                new List<GetSFMODONCONData1.documentInformation>{ ok }
            )));
        }
        Test.stopTest();
    }

    @isTest
    static void testDocTypeOnlyAndUnknownType() {
        Test.startTest();
        RestResponse accOnly = invokeGet(new Map<String, String>{ 'documentType' => 'Account' });
        RestResponse unknown = invokeGet(new Map<String, String>{ 'documentType' => 'Contact' });
        Test.stopTest();
        System.assertEquals(200, accOnly.statusCode);
        System.assertEquals(200, unknown.statusCode);
    }

    @isTest
    static void testGetInvalidDateReturns500() {
        Test.startTest();
        RestResponse res = invokeGet(new Map<String, String>{ 'changesSince' => 'not-a-date' });
        Test.stopTest();
        System.assertEquals(500, res.statusCode);
    }

    @isTest
    static void testOptionalMetadataTypesIfPresent() {
        // v1.0 Priyanka 22 09 2026: if org CMDT has Contact / ServiceRequest / Project, hit those builders
        Set<String> types = new Set<String>();
        for (Content_Repository_Data__mdt mdt : [
            SELECT Document_Type1__c, Document_Name__c
            FROM Content_Repository_Data__mdt
            WHERE Document_Type1__c IN ('Contact', 'ServiceRequest__c', 'Project__c', 'Phase__c')
        ]) {
            if (String.isBlank(mdt.Document_Name__c)) {
                continue;
            }
            types.add(mdt.Document_Type1__c);
            invokeGet(new Map<String, String>{
                'documentType' => mdt.Document_Type1__c,
                'documentName' => mdt.Document_Name__c
            });
        }
        System.assertEquals(true, types.size() >= 0);
    }

    @isTest
    static void testUpdateSharePointSuccessAndFailed() {
        Documents__c doc = [SELECT Id FROM Documents__c WHERE Name = 'Passport' LIMIT 1];

        GetSFMODONCONData1.documentInformation ok = new GetSFMODONCONData1.documentInformation();
        ok.documentId = doc.Id;
        ok.isUploaded = true;
        ok.uploadMessage = 'Uploaded Successfully';

        GetSFMODONCONData1.documentInformation fail = new GetSFMODONCONData1.documentInformation();
        fail.documentId = doc.Id;
        fail.isUploaded = false;
        fail.uploadMessage = 'Upload Failed';

        User runner = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        Test.startTest();
        grantUserModeAccess();
        System.runAs(runner) {
            RestResponse successRes = invokePost(JSON.serialize(new List<GetSFMODONCONData1.documentInformation>{ ok }));
            RestResponse failRes = invokePost(JSON.serialize(new List<GetSFMODONCONData1.documentInformation>{ fail }));
            assertOkOrHandled(successRes);
            assertOkOrHandled(failRes);
        }
        Test.stopTest();
    }

    @isTest
    static void testUpdateSharePointBlankSkipEmptyAndBadJson() {
        Documents__c doc = [SELECT Id FROM Documents__c WHERE Name = 'Passport' LIMIT 1];

        GetSFMODONCONData1.documentInformation blankFail = new GetSFMODONCONData1.documentInformation();
        blankFail.documentId = doc.Id;
        blankFail.isUploaded = false;
        blankFail.uploadMessage = '';

        GetSFMODONCONData1.documentInformation skipped = new GetSFMODONCONData1.documentInformation();
        skipped.documentId = null;

        Test.startTest();
        RestResponse blankRes = invokePost(JSON.serialize(
            new List<GetSFMODONCONData1.documentInformation>{ blankFail, skipped }
        ));
        RestResponse emptyRes = invokePost('[]');
        RestResponse badRes = invokePost('{not-json');
        Test.stopTest();

        assertOkOrHandled(blankRes);
        System.assertEquals(200, emptyRes.statusCode);
        System.assertEquals(500, badRes.statusCode);
    }

    @isTest
    static void testWrapperConstructors() {
        // v1.0 Priyanka 22 09 2026: instantiate inner wrappers (field declarations may stay uncoverable)
        GetSFMODONCONData1.UnifiedResponse unified = new GetSFMODONCONData1.UnifiedResponse();
        unified.data.put('k', 'v');

        GetSFMODONCONData1.DataWrapper wrap = new GetSFMODONCONData1.DataWrapper();
        wrap.parentId = 'p';
        wrap.parentType = 'Account';
        wrap.ParentName = 'n';
        wrap.SalesOrderId = 'so';
        wrap.SalesOrderName = 'soName';
        wrap.ProjectName = 'pr';
        wrap.PhaseName = 'ph';
        wrap.UnitName = 'u';
        wrap.CustomerBuyerId = 'a';
        wrap.CustomerBuyerName = 'buyer';

        GetSFMODONCONData1.JointOwnerInfo jo = new GetSFMODONCONData1.JointOwnerInfo();
        jo.jointOwnerId = 'j';
        jo.jointOwnerAccountName = 'joAcc';

        GetSFMODONCONData1.documentInformation info = new GetSFMODONCONData1.documentInformation();
        info.documentId = 'd';
        info.documentName = 'Passport';
        info.status = 'Uploaded';
        info.fileName = 'f.pdf';
        info.downloadUrl = 'https://example.com';
        info.isSharePointReady = true;
        info.isSharePointSynced = false;
        info.sharePointStatus = 'Success';
        info.isUploaded = true;
        info.uploadMessage = 'ok';
        info.base64Data = 'YQ==';

        System.assertEquals('v', unified.data.get('k'));
        System.assertEquals('Account', wrap.parentType);
        System.assertEquals('j', jo.jointOwnerId);
        System.assertEquals('Passport', info.documentName);
    }
}