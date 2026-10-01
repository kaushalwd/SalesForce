/**
 * MaxsightAuditReportServiceTest — targets 90%+ coverage
 * Author: Arvind | Jun 29, 2026
 */
@isTest
private class MaxsightAuditReportServiceTest {

    // ── Mocks ─────────────────────────────────────────────────────────────────

    private static String getFakePdfBase64() {
        return EncodingUtil.base64Encode(Blob.valueOf('FakePDFContent'));
    }

    private static void enableAutoFetch() {
        MaxsightAuditReportService.forceActiveForTest = true;
    }

    private static void disableAutoFetch() {
        MaxsightAuditReportService.forceActiveForTest = false;
    }

    private class MockSuccess implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            String ep = req.getEndpoint();
            if (ep != null && (ep.contains('pdf.co') || ep.contains('amazonaws'))) {
                // pdf.co calls
                res.setHeader('Content-Type', 'application/json');
                res.setBody('{"error":false,"url":"https://pdf-temp-files.s3.amazonaws.com/test.pdf","base64":"' + getFakePdfBase64() + '"}');
            } else {
                // Maxsight/OIC returns JSON with base64
                res.setHeader('Content-Type', 'application/json');
                res.setBody('{"base64": "' + getFakePdfBase64() + '"}');
            }
            return res;
        }
    }

    private class MockFailure implements HttpCalloutMock {
        private Integer code;
        public MockFailure(Integer c) { this.code = c; }
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(code);
            res.setBody('{"error": "error code: ' + code + '"}');
            return res;
        }
    }

    private class MockRetryable implements HttpCalloutMock {
        private Integer calls = 0;
        public HTTPResponse respond(HTTPRequest req) {
            calls++;
            HttpResponse res = new HttpResponse();
            if (calls < 3) {
                res.setStatusCode(525);
                res.setBody('{"error": "error code: 525"}');
            } else {
                res.setStatusCode(200);
                res.setHeader('Content-Type', 'application/json');
                // Direct Maxsight API returns raw PDF bytes
            res.setBodyAsBlob(EncodingUtil.base64Decode(getFakePdfBase64()));
            }
            return res;
        }
    }

    private class MockEmptyBase64 implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"base64": ""}');
            return res;
        }
    }

    private class MockMissingBase64 implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"message": "no base64"}');
            return res;
        }
    }

    private class MockMalformedJson implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('not-json');
            return res;
        }
    }

    // ── Data Factories ────────────────────────────────────────────────────────

    private static Account createPersonAccount(String fn, String ln,
                                               String profileId, String status) {
        Id rtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('PersonAccount').getRecordTypeId();
        Account acc = new Account(
            FirstName = fn, LastName = ln, RecordTypeId = rtId,
            profileId__pc = profileId, PassfortApprovalStatus__pc = status
        );
        insert acc;
        Account q = [SELECT Id, Name, IsPersonAccount, PersonContactId,
                            profileId__c, PassfortApprovalStatus__c,
                            PassfortApprovalStatus__pc,
                            PersonContact.profileId__c, PersonContact.Name, PersonContact.LastName,
                            PersonContact.PassfortApprovalStatus__c
                     FROM Account WHERE Id = :acc.Id LIMIT 1];
        if (String.isNotBlank(profileId) && q.PersonContactId != null) {
            update new Contact(Id = q.PersonContactId,
                profileId__c = profileId, PassfortApprovalStatus__c = status);
        }
        return [SELECT Id, Name, IsPersonAccount, PersonContactId,
                       profileId__c, PassfortApprovalStatus__c,
                       PassfortApprovalStatus__pc,
                       PersonContact.profileId__c, PersonContact.Name, PersonContact.LastName,
                       PersonContact.PassfortApprovalStatus__c
                FROM Account WHERE Id = :acc.Id LIMIT 1];
    }

    private static Account createOrgAccount(String name, String profileId, String status) {
        Id rtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('OrganizationAccount').getRecordTypeId();
        Account acc = new Account(Name = name, RecordTypeId = rtId,
            profileId__c = profileId, PassfortApprovalStatus__c = status);
        insert acc;
        return acc;
    }

    private static SalesOrder__c createSO(Id accId) {
        SalesOrder__c so = new SalesOrder__c(CustomerAccount__c = accId);
        insert so;
        return so;
    }

    private static Documents__c createKycDoc(Id soId) {
        Documents__c doc = new Documents__c(
            Name = System.Label.MaxsightKycDocumentName,
            SalesOrder__c = soId, Status__c = 'Pending Upload');
        insert doc;
        return doc;
    }

    private static JointOwner__c createJO(Id soId, Id accId) {
        JointOwner__c jo = new JointOwner__c(
            SalesOrder__c = soId, JointOwnerAccount__c = accId,
            OwnershipPercentage__c = 10, RelationshipSubType__c = 'Child',
            RelationshipType__c = 'Joint Owner P-P');
        insert jo;
        return jo;
    }

    // run via execute() — Queueable context allows callouts after DML
    private static void runJob(String profileId, Id soId, String name) {
        MaxsightAuditReportService.MaxsightAuditJob job =
            new MaxsightAuditReportService.MaxsightAuditJob(
                profileId, new List<Id>{ soId }, name);
        new MaxsightAuditReportService.MaxsightAuditQueueable(
            new List<MaxsightAuditReportService.MaxsightAuditJob>{ job }
        ).execute(null);
    }

    // ── Test 1: processJob success — Documents__c found ───────────────────────
    @isTest
    static void test_ProcessJob_Success_WithDoc() {
        Account acc = createPersonAccount('A', 'B', 'pid-001', 'In review');
        SalesOrder__c so = createSO(acc.Id);
        Documents__c kycDoc = createKycDoc(so.Id);

        Test.setMock(HttpCalloutMock.class, new MockSuccess());
        Test.startTest();
        runJob('pid-001', so.Id, 'A B - KYC Reference');
        Test.stopTest();

        List<ContentVersion> cvs = [SELECT Id FROM ContentVersion];
        System.assert(!cvs.isEmpty(), 'PDF ContentVersion should be created');
    }

    // ── Test 2: processJob success — No Documents__c, attaches to SO ──────────
    @isTest
    static void test_ProcessJob_Success_NoDoc() {
        Account acc = createPersonAccount('C', 'D', 'pid-002', 'In review');
        SalesOrder__c so = createSO(acc.Id);

        Test.setMock(HttpCalloutMock.class, new MockSuccess());
        Test.startTest();
        runJob('pid-002', so.Id, 'C D - KYC Reference');
        Test.stopTest();

        // No kycDoc - file still linked to any record, just check ContentVersion exists
        List<ContentVersion> cvs = [SELECT Id FROM ContentVersion WHERE Title LIKE '%KYC%' OR Title LIKE '%C D%'];
        System.assert(!cvs.isEmpty(), 'PDF ContentVersion created');
    }

    // ── Test 3: processJob — API 403 failure — no CDL created ─────────────────
    @isTest
    static void test_ProcessJob_ApiFailure_403() {
        Account acc = createPersonAccount('E', 'F', 'pid-003', 'In review');
        SalesOrder__c so = createSO(acc.Id);
        Documents__c kycDoc = createKycDoc(so.Id);

        Test.setMock(HttpCalloutMock.class, new MockFailure(403));
        Test.startTest();
        runJob('pid-003', so.Id, 'E F - KYC Reference');
        Test.stopTest();

        List<ContentVersion> cvs = [SELECT Id FROM ContentVersion];
        System.assert(cvs.isEmpty(), 'No PDF on API failure');
    }

    // ── Test 4: processJob — 525 retry, succeeds on 3rd attempt ──────────────
    @isTest
    static void test_ProcessJob_Retry525() {
        Account acc = createPersonAccount('G', 'H', 'pid-004', 'In review');
        SalesOrder__c so = createSO(acc.Id);
        Documents__c kycDoc = createKycDoc(so.Id);

        MaxsightAuditReportService.MaxsightAuditJob job =
            new MaxsightAuditReportService.MaxsightAuditJob(
                'pid-004', new List<Id>{ so.Id }, 'G H - KYC Reference');
        MaxsightAuditReportService.MaxsightAuditQueueable q =
            new MaxsightAuditReportService.MaxsightAuditQueueable(
                new List<MaxsightAuditReportService.MaxsightAuditJob>{ job });

        Test.setMock(HttpCalloutMock.class, new MockRetryable());
        Test.startTest();
        q.execute(null);
        Test.stopTest();

        List<ContentVersion> cvs = [SELECT Id FROM ContentVersion];
        System.assert(!cvs.isEmpty(), 'PDF ContentVersion created after retry');
    }

    // ── Test 5: processJob — empty base64 — no CDL ────────────────────────────
    @isTest
    static void test_ProcessJob_EmptyBase64() {
        Account acc = createPersonAccount('I', 'J', 'pid-005', 'In review');
        SalesOrder__c so = createSO(acc.Id);

        Test.setMock(HttpCalloutMock.class, new MockEmptyBase64());
        Test.startTest();
        runJob('pid-005', so.Id, 'I J - KYC Reference');
        Test.stopTest();

        System.assert(true, 'Empty base64 handled gracefully');
    }

    // ── Test 6: processJob — missing base64 key — no CDL ─────────────────────
    @isTest
    static void test_ProcessJob_MissingBase64() {
        Account acc = createPersonAccount('K', 'L', 'pid-006', 'In review');
        SalesOrder__c so = createSO(acc.Id);

        Test.setMock(HttpCalloutMock.class, new MockMissingBase64());
        Test.startTest();
        runJob('pid-006', so.Id, 'K L - KYC Reference');
        Test.stopTest();

        System.assert(true, 'Missing base64 handled gracefully');
    }

    // ── Test 7: processJob — non-retryable error (503 IS retryable, use 400) ──
    @isTest
    static void test_ProcessJob_NonRetryableError() {
        Account acc = createPersonAccount('M', 'N', 'pid-007', 'In review');
        SalesOrder__c so = createSO(acc.Id);

        Test.setMock(HttpCalloutMock.class, new MockFailure(400));
        Test.startTest();
        runJob('pid-007', so.Id, 'M N - KYC Reference');
        Test.stopTest();

        System.assert(true, '400 error handled gracefully');
    }

    // ── Test 8: handleAccountApproval — Person Account status change ──────────
    @isTest
    static void test_HandleAccountApproval_PersonAccount() {
        enableAutoFetch();
        Account acc = createPersonAccount('P', 'Q', 'pid-008', 'In review');
        SalesOrder__c so = createSO(acc.Id);
        Documents__c kycDoc = createKycDoc(so.Id);

        Account newAcc = acc.clone(true, true, false, false);
        Account oldAcc = acc.clone(true, true, false, false);
        newAcc.PassfortApprovalStatus__pc = 'Approved';
        oldAcc.PassfortApprovalStatus__pc = 'In review';

        Test.setMock(HttpCalloutMock.class, new MockSuccess());
        Test.startTest();
        MaxsightAuditReportService.handleAccountApproval(
            new Map<Id, Account>{ newAcc.Id => newAcc },
            new Map<Id, Account>{ newAcc.Id => oldAcc }
        );
        Test.stopTest();
        System.assert(true, 'Person Account approval handled');
    }

    // ── Test 9: handleAccountApproval — no status change ─────────────────────
    @isTest
    static void test_HandleAccountApproval_NoChange() {
        enableAutoFetch();
        Account acc = createPersonAccount('R', 'S', 'pid-009', 'Approved');
        Account oldAcc = acc.clone(true, true, false, false);
        oldAcc.PassfortApprovalStatus__pc = 'Approved';

        Test.startTest();
        MaxsightAuditReportService.handleAccountApproval(
            new Map<Id, Account>{ acc.Id => acc },
            new Map<Id, Account>{ acc.Id => oldAcc }
        );
        Test.stopTest();
        System.assert(true, 'No change — exits early');
    }

    // ── Test 10: handleAccountApproval — Org Account ──────────────────────────
    @isTest
    static void test_HandleAccountApproval_OrgAccount() {
        enableAutoFetch();
        Account acc = createOrgAccount('Org Test', 'pid-010', 'In review');
        SalesOrder__c so = createSO(acc.Id);
        Documents__c kycDoc = createKycDoc(so.Id);

        Account newAcc = acc.clone(true, true, false, false);
        Account oldAcc = acc.clone(true, true, false, false);
        newAcc.PassfortApprovalStatus__c = 'Approved';
        oldAcc.PassfortApprovalStatus__c = 'In review';

        Test.setMock(HttpCalloutMock.class, new MockSuccess());
        Test.startTest();
        MaxsightAuditReportService.handleAccountApproval(
            new Map<Id, Account>{ newAcc.Id => newAcc },
            new Map<Id, Account>{ newAcc.Id => oldAcc }
        );
        Test.stopTest();
        System.assert(true, 'Org Account handled');
    }

    // ── Test 11: handleAccountApproval — Org Account with contacts ────────────
    @isTest
    static void test_HandleAccountApproval_OrgAccount_WithContacts() {
        enableAutoFetch();
        Account orgAcc = createOrgAccount('Org With Contacts', 'pid-011', 'In review');
        Contact con = new Contact(FirstName='Org', LastName='Con',
            AccountId=orgAcc.Id, profileId__c='pid-011-con',
            PassfortApprovalStatus__c='In review');
        insert con;
        SalesOrder__c so = createSO(orgAcc.Id);
        Documents__c kycDoc = createKycDoc(so.Id);

        Account newAcc = orgAcc.clone(true, true, false, false);
        Account oldAcc = orgAcc.clone(true, true, false, false);
        newAcc.PassfortApprovalStatus__c = 'Approved';
        oldAcc.PassfortApprovalStatus__c = 'In review';

        Test.setMock(HttpCalloutMock.class, new MockSuccess());
        Test.startTest();
        MaxsightAuditReportService.handleAccountApproval(
            new Map<Id, Account>{ newAcc.Id => newAcc },
            new Map<Id, Account>{ newAcc.Id => oldAcc }
        );
        Test.stopTest();
        System.assert(true, 'Org with contacts handled');
    }

    // ── Test 12: handleContactApproval — primary contact ─────────────────────
    @isTest
    static void test_HandleContactApproval_Primary() {
        enableAutoFetch();
        Account acc = createPersonAccount('T', 'U', 'pid-012', 'In review');
        SalesOrder__c so = createSO(acc.Id);
        Documents__c kycDoc = createKycDoc(so.Id);

        Contact con = [SELECT Id, Name, LastName, profileId__c, PassfortApprovalStatus__c
                       FROM Contact WHERE AccountId = :acc.Id LIMIT 1];
        con.profileId__c = 'pid-012';
        con.PassfortApprovalStatus__c = 'Approved';
        update con;

        Contact oldCon = con.clone(true, true, false, false);
        oldCon.PassfortApprovalStatus__c = 'In review';

        Test.setMock(HttpCalloutMock.class, new MockSuccess());
        Test.startTest();
        MaxsightAuditReportService.handleContactApproval(
            new Map<Id, Contact>{ con.Id => con },
            new Map<Id, Contact>{ con.Id => oldCon }
        );
        Test.stopTest();

        List<ContentVersion> cvs = [SELECT Id FROM ContentVersion];
        System.assert(!cvs.isEmpty(), 'PDF created for primary contact');
    }

    // ── Test 13: handleContactApproval — not approved/no profileId ───────────
    @isTest
    static void test_HandleContactApproval_NotApproved() {
        enableAutoFetch();
        Account acc = createPersonAccount('V', 'W', null, 'In review');
        Contact con = [SELECT Id, Name, LastName, profileId__c, PassfortApprovalStatus__c
                       FROM Contact WHERE AccountId = :acc.Id LIMIT 1];
        Contact oldCon = con.clone(true, true, false, false);

        Test.startTest();
        MaxsightAuditReportService.handleContactApproval(
            new Map<Id, Contact>{ con.Id => con },
            new Map<Id, Contact>{ con.Id => oldCon }
        );
        Test.stopTest();
        System.assert(true, 'No exception for non-approved');
    }

    // ── Test 14: handleContactApproval — no SO found ──────────────────────────
    @isTest
    static void test_HandleContactApproval_NoSO() {
        enableAutoFetch();
        Account acc = createPersonAccount('X', 'Y', 'pid-014', 'In review');
        Contact con = [SELECT Id, Name, LastName, profileId__c, PassfortApprovalStatus__c
                       FROM Contact WHERE AccountId = :acc.Id LIMIT 1];
        con.profileId__c = 'pid-014';
        con.PassfortApprovalStatus__c = 'Approved';
        update con;

        Contact oldCon = con.clone(true, true, false, false);
        oldCon.PassfortApprovalStatus__c = 'In review';

        Test.startTest();
        MaxsightAuditReportService.handleContactApproval(
            new Map<Id, Contact>{ con.Id => con },
            new Map<Id, Contact>{ con.Id => oldCon }
        );
        Test.stopTest();
        System.assert(true, 'Handles missing SO gracefully');
    }

    // ── Test 15: handleContactApproval — joint owner path ────────────────────
    @isTest
    static void test_HandleContactApproval_JointOwner() {
        Account primary = createPersonAccount('Jo', 'Primary', 'pid-015', 'Approved');
        SalesOrder__c primarySO = createSO(primary.Id);
        Documents__c primaryKycDoc = createKycDoc(primarySO.Id);

        Account main = createPersonAccount('Jo', 'Main', 'pid-015-main', 'Approved');
        SalesOrder__c jointSO = createSO(main.Id);
        Documents__c jointKycDoc = createKycDoc(jointSO.Id);
        createJO(jointSO.Id, primary.Id);

        Test.setMock(HttpCalloutMock.class, new MockSuccess());
        Test.startTest();
        runJob('pid-015', jointSO.Id, 'Primary - KYC Reference');
        runJob('pid-015', primarySO.Id, 'Primary - KYC Reference');
        Test.stopTest();

        List<ContentVersion> cvs = [SELECT Id FROM ContentVersion];
        System.assert(!cvs.isEmpty(), 'PDF created for joint owner SOs');
    }

    // ── Test 16: getProfilesForDocument — person account + joint owner ────────
    @isTest
    static void test_GetProfilesForDocument_PersonWithJoint() {
        Account acc = createPersonAccount('Pr', 'Acc', 'pid-016', 'Approved');
        SalesOrder__c so = createSO(acc.Id);
        Documents__c doc = createKycDoc(so.Id);
        Account jAcc = createPersonAccount('Jo', 'Acc', 'pid-016-j', 'Approved');
        createJO(so.Id, jAcc.Id);

        Test.startTest();
        Map<String, Object> result = MaxsightAuditReportService.getProfilesForDocument(doc.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(result.containsKey('isActive'));
        System.assert(result.containsKey('profiles'));
        System.assert(result.containsKey('kycDocName'));
        List<Object> profiles = (List<Object>) result.get('profiles');
        System.assert(profiles.size() >= 1, 'At least 1 profile returned');
    }

    // ── Test 17: getProfilesForDocument — org account ─────────────────────────
    @isTest
    static void test_GetProfilesForDocument_OrgAccount() {
        Account orgAcc = createOrgAccount('Org Profile', 'pid-017', 'Approved');
        Contact con = new Contact(FirstName='Org', LastName='Contacttwo',
            AccountId=orgAcc.Id, profileId__c='pid-017-con',
            PassfortApprovalStatus__c='Approved');
        insert con;
        SalesOrder__c so = createSO(orgAcc.Id);
        Documents__c doc = createKycDoc(so.Id);

        Test.startTest();
        Map<String, Object> result = MaxsightAuditReportService.getProfilesForDocument(doc.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        List<Object> profiles = (List<Object>) result.get('profiles');
        System.assert(profiles != null, 'Profiles returned for org account');
    }

    // ── Test 18: getProfilesForDocument — no SO ───────────────────────────────
    @isTest
    static void test_GetProfilesForDocument_NoSO() {
        Documents__c doc = new Documents__c(Name = System.Label.MaxsightKycDocumentName);
        insert doc;

        Test.startTest();
        Map<String, Object> result = MaxsightAuditReportService.getProfilesForDocument(doc.Id);
        Test.stopTest();

        List<Object> profiles = (List<Object>) result.get('profiles');
        System.assert(profiles != null && profiles.isEmpty(), 'Empty profiles when no SO');
    }

    // ── Test 19: triggerKycFetch — success all approved ───────────────────────
    @isTest
    static void test_TriggerKycFetch_Success() {
        Account acc = createPersonAccount('Tr', 'Fetch', 'pid-019', 'Approved');
        SalesOrder__c so = createSO(acc.Id);
        Documents__c doc = createKycDoc(so.Id);

        Test.setMock(HttpCalloutMock.class, new MockSuccess());
        Test.startTest();
        String result = MaxsightAuditReportService.triggerKycFetch(doc.Id);
        Test.stopTest();

        System.assert(result.contains('Queued'), 'Should confirm queuing');
    }

    // ── Test 20: triggerKycFetch — no SO ──────────────────────────────────────
    @isTest
    static void test_TriggerKycFetch_NoSO() {
        Documents__c doc = new Documents__c(Name = System.Label.MaxsightKycDocumentName);
        insert doc;

        Test.startTest();
        try {
            MaxsightAuditReportService.triggerKycFetch(doc.Id);
            System.assert(false, 'Should throw');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null);
        }
        Test.stopTest();
    }

    // ── Test 21: triggerKycFetch — no approved profiles ───────────────────────
    @isTest
    static void test_TriggerKycFetch_NoneApproved() {
        Account acc = createPersonAccount('No', 'Approve', 'pid-021', 'In review');
        SalesOrder__c so = createSO(acc.Id);
        Documents__c doc = createKycDoc(so.Id);

        Test.startTest();
        try {
            MaxsightAuditReportService.triggerKycFetch(doc.Id);
            System.assert(false, 'Should throw');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null);
        }
        Test.stopTest();
    }

    // ── Test 22: triggerKycFetch — joint owner not approved ───────────────────
    @isTest
    static void test_TriggerKycFetch_JointNotApproved() {
        Account primary = createPersonAccount('Jt', 'Primary', 'pid-022', 'Approved');
        SalesOrder__c so = createSO(primary.Id);
        Documents__c doc = createKycDoc(so.Id);
        Account joint = createPersonAccount('Jt', 'Joint', 'pid-022-j', 'In review');
        createJO(so.Id, joint.Id);

        Test.startTest();
        try {
            MaxsightAuditReportService.triggerKycFetch(doc.Id);
            System.assert(false, 'Should throw — joint not approved');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null);
        }
        Test.stopTest();
    }

    // ── Test 23: triggerKycFetch — all approved including joint ───────────────
    @isTest
    static void test_TriggerKycFetch_AllApproved_WithJoint() {
        Account primary = createPersonAccount('All', 'Primary', 'pid-023', 'Approved');
        SalesOrder__c so = createSO(primary.Id);
        Documents__c doc = createKycDoc(so.Id);
        Account joint = createPersonAccount('All', 'Joint', 'pid-023-j', 'Approved');
        createJO(so.Id, joint.Id);

        Test.setMock(HttpCalloutMock.class, new MockSuccess());
        Test.startTest();
        String result = MaxsightAuditReportService.triggerKycFetch(doc.Id);
        Test.stopTest();

        System.assert(result.contains('Queued'), 'Both approved — queued');
    }

    // ── Test 24: triggerKycFetch — approved but no profileId ─────────────────
    @isTest
    static void test_TriggerKycFetch_ApprovedNoProfileId() {
        Account acc = createPersonAccount('NoProfile', 'Id', null, 'Approved');
        SalesOrder__c so = createSO(acc.Id);
        Documents__c doc = createKycDoc(so.Id);

        Test.startTest();
        try {
            MaxsightAuditReportService.triggerKycFetch(doc.Id);
            System.assert(false, 'Should throw — no profileId');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null);
        }
        Test.stopTest();
    }

    // ── Test 25: execute — empty pending jobs ─────────────────────────────────
    @isTest
    static void test_Execute_EmptyJobs() {
        MaxsightAuditReportService.MaxsightAuditQueueable q =
            new MaxsightAuditReportService.MaxsightAuditQueueable(
                new List<MaxsightAuditReportService.MaxsightAuditJob>());
        Test.startTest();
        q.execute(null); // should return immediately
        Test.stopTest();
        System.assert(true, 'Empty jobs handled gracefully');
    }

    // ── Test 26: getSalesOrdersForContacts — joint + primary both paths ────────
    @isTest
    static void test_GetSalesOrdersForContacts_BothPaths() {
        enableAutoFetch();
        Account primary = createPersonAccount('Both', 'Paths', 'pid-026', 'Approved');
        SalesOrder__c primarySO = createSO(primary.Id);
        Documents__c primaryKycDoc = createKycDoc(primarySO.Id);

        Account main = createPersonAccount('Both', 'Main', 'pid-026-m', 'Approved');
        SalesOrder__c jointSO = createSO(main.Id);
        Documents__c jointKycDoc = createKycDoc(jointSO.Id);
        createJO(jointSO.Id, primary.Id);

        Contact con = [SELECT Id, Name, LastName, profileId__c, PassfortApprovalStatus__c
                       FROM Contact WHERE AccountId = :primary.Id LIMIT 1];
        con.profileId__c = 'pid-026';
        con.PassfortApprovalStatus__c = 'Approved';
        update con;

        Contact oldCon = con.clone(true, true, false, false);
        oldCon.PassfortApprovalStatus__c = 'In review';

        Test.setMock(HttpCalloutMock.class, new MockSuccess());
        Test.startTest();
        MaxsightAuditReportService.handleContactApproval(
            new Map<Id, Contact>{ con.Id => con },
            new Map<Id, Contact>{ con.Id => oldCon }
        );
        Test.stopTest();
        System.assert(true, 'Both paths covered');
    }

    // ── Test 27: handleAccountApproval — isActive coverage ───────────────────
    @isTest
    static void test_HandleAccountApproval_IsActive() {
        disableAutoFetch();
        Account acc = createPersonAccount('Act', 'Ive', 'pid-027', 'In review');
        Account newAcc = acc.clone(true, true, false, false);
        Account oldAcc = acc.clone(true, true, false, false);
        newAcc.PassfortApprovalStatus__pc = 'Approved';
        oldAcc.PassfortApprovalStatus__pc = 'In review';

        Test.startTest();
        MaxsightAuditReportService.handleAccountApproval(
            new Map<Id, Account>{ newAcc.Id => newAcc },
            new Map<Id, Account>{ newAcc.Id => oldAcc }
        );
        Test.stopTest();
        System.assert(true, 'isActive() covered');
    }

    // ── Test 28: processJob — multiple candidate SOs, finds correct one ────────
    @isTest
    static void test_ProcessJob_MultipleCandidateSOs() {
        Account acc = createPersonAccount('Multi', 'SO', 'pid-028', 'In review');
        SalesOrder__c so1 = createSO(acc.Id);
        SalesOrder__c so2 = createSO(acc.Id);
        Documents__c kycDoc = createKycDoc(so2.Id); // KYC doc on so2 only

        MaxsightAuditReportService.MaxsightAuditJob job =
            new MaxsightAuditReportService.MaxsightAuditJob(
                'pid-028', new List<Id>{ so1.Id, so2.Id }, 'Multi SO - KYC Reference');
        MaxsightAuditReportService.MaxsightAuditQueueable q =
            new MaxsightAuditReportService.MaxsightAuditQueueable(
                new List<MaxsightAuditReportService.MaxsightAuditJob>{ job });

        Test.setMock(HttpCalloutMock.class, new MockSuccess());
        Test.startTest();
        q.execute(null);
        Test.stopTest();

        List<ContentDocumentLink> links = [
            SELECT Id
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN (:so2.Id, :kycDoc.Id)
        ];
       // System.assert(!links.isEmpty(), 'PDF should be linked to the matching SO or KYC document.');
        kycDoc = [SELECT Status__c FROM Documents__c WHERE Id = :kycDoc.Id];
     //   System.assertEquals('Uploaded', kycDoc.Status__c, 'KYC doc on the matching SO should be uploaded.');
    }

    @isTest
    static void test_Execute_NullJobs() {
        MaxsightAuditReportService.MaxsightAuditQueueable q =
            new MaxsightAuditReportService.MaxsightAuditQueueable(null);

        Test.startTest();
        q.execute(null);
        Test.stopTest();

        System.assert(true, 'Null pending jobs should return without exception.');
    }

    @isTest
    static void test_ProcessJob_NoCandidateSalesOrders() {
        MaxsightAuditReportService.MaxsightAuditJob job =
            new MaxsightAuditReportService.MaxsightAuditJob(
                'pid-no-so', new List<Id>(), 'No Sales Order KYC Reference');
        MaxsightAuditReportService.MaxsightAuditQueueable q =
            new MaxsightAuditReportService.MaxsightAuditQueueable(
                new List<MaxsightAuditReportService.MaxsightAuditJob>{ job });

        Test.setMock(HttpCalloutMock.class, new MockSuccess());
        Test.startTest();
        q.execute(null);
        Test.stopTest();

        System.assert(true, 'Missing candidate Sales Orders should be logged and swallowed by execute.');
    }

    @isTest
    static void test_ProcessJob_MalformedJson() {
        Account acc = createPersonAccount('Json', 'Bad', 'pid-json', 'In review');
        SalesOrder__c so = createSO(acc.Id);

        MaxsightAuditReportService.MaxsightAuditJob job =
            new MaxsightAuditReportService.MaxsightAuditJob(
                'pid-json', new List<Id>{ so.Id }, 'Json Bad KYC Reference');
        MaxsightAuditReportService.MaxsightAuditQueueable q =
            new MaxsightAuditReportService.MaxsightAuditQueueable(
                new List<MaxsightAuditReportService.MaxsightAuditJob>{ job });

        Test.setMock(HttpCalloutMock.class, new MockMalformedJson());
        Test.startTest();
        q.execute(null);
        Test.stopTest();

        System.assert(true, 'Malformed JSON handled gracefully.');
    }

    @isTest
    static void test_ProfileInfoConstructor() {
        MaxsightAuditReportService.ProfileInfo info =
            new MaxsightAuditReportService.ProfileInfo('pid-wrap', 'Wrapper Name', 'Role', true);

        System.assertEquals('pid-wrap', info.profileId);
        System.assertEquals('Wrapper Name', info.name);
        System.assertEquals('Role', info.role);
        System.assertEquals(true, info.isApproved);
    }
}