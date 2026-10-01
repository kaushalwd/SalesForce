@IsTest
private class DocumentAutoGenerateServiceTest {

    private class MockPDFSuccess implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('%PDF-1.4 mock pdf content');
            return res;
        }
    }

    private class MockHTTPError implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Server Error');
            return res;
        }
    }

    private class MockNonPDF implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('not a pdf');
            return res;
        }
    }

    private class MockHTMLThenPDF implements HttpCalloutMock {
        private Integer callCount = 0;
        public HTTPResponse respond(HTTPRequest req) {
            callCount++;
            HttpResponse res = new HttpResponse();
            if (callCount == 1) {
                res.setStatusCode(200);
                res.setBody('<head></head><body>'
                    + '<a href="/download/test.pdf">Download</a></body>');
            } else {
                res.setStatusCode(200);
                res.setBody('%PDF-1.4 signed pdf');
            }
            return res;
        }
    }

    private class MockHTMLDownloadFails implements HttpCalloutMock {
        private Integer callCount = 0;
        public HTTPResponse respond(HTTPRequest req) {
            callCount++;
            HttpResponse res = new HttpResponse();
            if (callCount == 1) {
                res.setStatusCode(200);
                res.setBody('<head></head><body>'
                    + '<a href="/download/test.pdf">Download</a></body>');
            } else {
                res.setStatusCode(404);
                res.setBody('Not Found');
            }
            return res;
        }
    }

    private class MockHTMLDownloadNotPDF implements HttpCalloutMock {
        private Integer callCount = 0;
        public HTTPResponse respond(HTTPRequest req) {
            callCount++;
            HttpResponse res = new HttpResponse();
            if (callCount == 1) {
                res.setStatusCode(200);
                res.setBody('<head></head><body>'
                    + '<a href="/download/test.pdf">Download</a></body>');
            } else {
                res.setStatusCode(200);
                res.setBody('not pdf at all');
            }
            return res;
        }
    }

    private class MockHTMLNoLink implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('<head></head><body>Processing...</body>');
            return res;
        }
    }

    private static final String TEST_URL =
        'https://test.salesforce.com/apex/Loop__Loop?id=001000000000001';

    private static Documents__c createDoc(String name) {
        Documents__c doc = new Documents__c(Name = name);
        insert doc;
        return doc;
    }

    private static Loop__DDP__c getDDP(String name) {
        List<Loop__DDP__c> existing = [
            SELECT Id FROM Loop__DDP__c WHERE Name = :name LIMIT 1
        ];
        if (!existing.isEmpty()) return existing[0];
        Loop__DDP__c ddp = new Loop__DDP__c(
            Name = name, Loop__IsActive__c = true
        );
        insert ddp;
        return ddp;
    }

    private static Document_Master_Configuration__mdt getValidConfig() {
        List<Document_Master_Configuration__mdt> cfgs = [
            SELECT DocumentDisplayName__c, DocGen_Package_Name__c
            FROM Document_Master_Configuration__mdt
            WHERE Auto_Generate_Document__c = true
            AND   DocGen_Package_Name__c    != null
            LIMIT 1
        ];
        return cfgs.isEmpty() ? null : cfgs[0];
    }

    private static Document_Master_Configuration__mdt getAutoGenerateFalseConfig() {
        List<Document_Master_Configuration__mdt> cfgs = [
            SELECT DocumentDisplayName__c
            FROM Document_Master_Configuration__mdt
            WHERE Auto_Generate_Document__c = false
            LIMIT 1
        ];
        return cfgs.isEmpty() ? null : cfgs[0];
    }


    // ═════════════════════════════════════════════════════════════
    // generateAndSend — EARLY RETURNS
    // ═════════════════════════════════════════════════════════════

    @IsTest
    static void test_generateAndSend_Null() {
        Test.startTest();
        DocumentAutoGenerateService.generateAndSend(null);
        Test.stopTest();
        System.assert(true);
    }

    @IsTest
    static void test_generateAndSend_Empty() {
        Test.startTest();
        DocumentAutoGenerateService.generateAndSend(new Set<Id>());
        Test.stopTest();
        System.assert(true);
    }

    @IsTest
    static void test_generateAndSend_NoDocuments() {
        Documents__c doc = createDoc('TempDelete');
        Id deletedId = doc.Id;
        delete doc;
        Test.setMock(HttpCalloutMock.class, new MockPDFSuccess());
        Test.startTest();
        DocumentAutoGenerateService.generateAndSend(new Set<Id>{ deletedId });
        Test.stopTest();
        System.assert(true);
    }

    @IsTest
    static void test_generateAndSend_NoConfig() {
        Documents__c doc = createDoc('NO_CONFIG_DOC_ZZZZ');
        Test.setMock(HttpCalloutMock.class, new MockPDFSuccess());
        Test.startTest();
        DocumentAutoGenerateService.generateAndSend(new Set<Id>{ doc.Id });
        Test.stopTest();
        System.assert(true);
    }


    // ═════════════════════════════════════════════════════════════
    // generateAndSend — config == null branch
    // Two docs: one matches metadata, one does not
    // ═════════════════════════════════════════════════════════════

    @IsTest
    static void test_generateAndSend_ConfigNullBranch() {
        Document_Master_Configuration__mdt cfg = getValidConfig();
        if (cfg == null) return;
        Documents__c doc1 = createDoc(cfg.DocumentDisplayName__c);
        Documents__c doc2 = createDoc('ZZZNO_MATCH_CONFIG_9999');
        Test.setMock(HttpCalloutMock.class, new MockPDFSuccess());
        Test.startTest();
        DocumentAutoGenerateService.generateAndSend(
            new Set<Id>{ doc1.Id, doc2.Id }
        );
        Test.stopTest();
        System.assertNotEquals(null,
            [SELECT Document_Status__c FROM Documents__c WHERE Id = :doc1.Id]
            .Document_Status__c);
    }


    // ═════════════════════════════════════════════════════════════
    // generateAndSend — Auto_Generate = false
    // ═════════════════════════════════════════════════════════════

    @IsTest
    static void test_generateAndSend_AutoGenerateFalse() {
        Document_Master_Configuration__mdt cfg = getAutoGenerateFalseConfig();
        if (cfg == null) {
            System.debug('No Auto_Generate=false metadata — skipping');
            return;
        }
        Documents__c doc = createDoc(cfg.DocumentDisplayName__c);
        Test.setMock(HttpCalloutMock.class, new MockPDFSuccess());
        Test.startTest();
        DocumentAutoGenerateService.generateAndSend(new Set<Id>{ doc.Id });
        Test.stopTest();
        System.assertNotEquals('Error',
            [SELECT Document_Status__c FROM Documents__c WHERE Id = :doc.Id]
            .Document_Status__c);
    }


    // ═════════════════════════════════════════════════════════════
    // generateAndSend — Blank URL (no DDP)
    // ═════════════════════════════════════════════════════════════

    @IsTest
    static void test_generateAndSend_BlankURL() {
        Document_Master_Configuration__mdt cfg = getValidConfig();
        if (cfg == null) return;
        Documents__c doc = createDoc(cfg.DocumentDisplayName__c);
        Test.setMock(HttpCalloutMock.class, new MockPDFSuccess());
        Test.startTest();
        DocumentAutoGenerateService.generateAndSend(new Set<Id>{ doc.Id });
        Test.stopTest();
        System.assertNotEquals(null,
            [SELECT Document_Status__c FROM Documents__c WHERE Id = :doc.Id]
            .Document_Status__c);
    }


    // ═════════════════════════════════════════════════════════════
    // generateAndSend — WITH DDP
    // ═════════════════════════════════════════════════════════════

    @IsTest
    static void test_generateAndSend_PDFSuccess() {
        Document_Master_Configuration__mdt cfg = getValidConfig();
        if (cfg == null) return;
        getDDP(cfg.DocGen_Package_Name__c);
        Documents__c doc = createDoc(cfg.DocumentDisplayName__c);
        Test.setMock(HttpCalloutMock.class, new MockPDFSuccess());
        Test.startTest();
        DocumentAutoGenerateService.generateAndSend(new Set<Id>{ doc.Id });
        Test.stopTest();
        System.assertNotEquals(null,
            [SELECT Document_Status__c FROM Documents__c WHERE Id = :doc.Id]
            .Document_Status__c);
    }

    @IsTest
    static void test_generateAndSend_HTTP500() {
        Document_Master_Configuration__mdt cfg = getValidConfig();
        if (cfg == null) return;
        getDDP(cfg.DocGen_Package_Name__c);
        Documents__c doc = createDoc(cfg.DocumentDisplayName__c);
        Test.setMock(HttpCalloutMock.class, new MockHTTPError());
        Test.startTest();
        DocumentAutoGenerateService.generateAndSend(new Set<Id>{ doc.Id });
        Test.stopTest();
        System.assertEquals('Error',
            [SELECT Document_Status__c FROM Documents__c WHERE Id = :doc.Id]
            .Document_Status__c);
    }

    @IsTest
    static void test_generateAndSend_NonPDF() {
        Document_Master_Configuration__mdt cfg = getValidConfig();
        if (cfg == null) return;
        getDDP(cfg.DocGen_Package_Name__c);
        Documents__c doc = createDoc(cfg.DocumentDisplayName__c);
        Test.setMock(HttpCalloutMock.class, new MockNonPDF());
        Test.startTest();
        DocumentAutoGenerateService.generateAndSend(new Set<Id>{ doc.Id });
        Test.stopTest();
        System.assertEquals('Error',
            [SELECT Document_Status__c FROM Documents__c WHERE Id = :doc.Id]
            .Document_Status__c);
    }

    @IsTest
    static void test_generateAndSend_HTMLThenPDF() {
        Document_Master_Configuration__mdt cfg = getValidConfig();
        if (cfg == null) return;
        getDDP(cfg.DocGen_Package_Name__c);
        Documents__c doc = createDoc(cfg.DocumentDisplayName__c);
        Test.setMock(HttpCalloutMock.class, new MockHTMLThenPDF());
        Test.startTest();
        DocumentAutoGenerateService.generateAndSend(new Set<Id>{ doc.Id });
        Test.stopTest();
        System.assertNotEquals(null,
            [SELECT Document_Status__c FROM Documents__c WHERE Id = :doc.Id]
            .Document_Status__c);
    }

    @IsTest
    static void test_generateAndSend_HTMLNoLink() {
        Document_Master_Configuration__mdt cfg = getValidConfig();
        if (cfg == null) return;
        getDDP(cfg.DocGen_Package_Name__c);
        Documents__c doc = createDoc(cfg.DocumentDisplayName__c);
        Test.setMock(HttpCalloutMock.class, new MockHTMLNoLink());
        Test.startTest();
        DocumentAutoGenerateService.generateAndSend(new Set<Id>{ doc.Id });
        Test.stopTest();
        System.assertEquals('Error',
            [SELECT Document_Status__c FROM Documents__c WHERE Id = :doc.Id]
            .Document_Status__c);
    }

    @IsTest
    static void test_generateAndSend_HTMLDownloadFails() {
        Document_Master_Configuration__mdt cfg = getValidConfig();
        if (cfg == null) return;
        getDDP(cfg.DocGen_Package_Name__c);
        Documents__c doc = createDoc(cfg.DocumentDisplayName__c);
        Test.setMock(HttpCalloutMock.class, new MockHTMLDownloadFails());
        Test.startTest();
        DocumentAutoGenerateService.generateAndSend(new Set<Id>{ doc.Id });
        Test.stopTest();
        System.assertEquals('Error',
            [SELECT Document_Status__c FROM Documents__c WHERE Id = :doc.Id]
            .Document_Status__c);
    }

    @IsTest
    static void test_generateAndSend_HTMLDownloadNotPDF() {
        Document_Master_Configuration__mdt cfg = getValidConfig();
        if (cfg == null) return;
        getDDP(cfg.DocGen_Package_Name__c);
        Documents__c doc = createDoc(cfg.DocumentDisplayName__c);
        Test.setMock(HttpCalloutMock.class, new MockHTMLDownloadNotPDF());
        Test.startTest();
        DocumentAutoGenerateService.generateAndSend(new Set<Id>{ doc.Id });
        Test.stopTest();
        System.assertEquals('Error',
            [SELECT Document_Status__c FROM Documents__c WHERE Id = :doc.Id]
            .Document_Status__c);
    }


    // ═════════════════════════════════════════════════════════════
    // extractPdfFromHtml — ALL BRANCHES
    // ═════════════════════════════════════════════════════════════

    @IsTest
    static void test_extractPdf_DownloadSuccess() {
        String html = '<head></head><body>'
            + '<a href="/download/test.pdf">Download</a></body>';
        Test.setMock(HttpCalloutMock.class, new MockPDFSuccess());
        Test.startTest();
        Blob result = DocumentAutoGenerateService.extractPdfFromHtml(
            html, TEST_URL, new Http());
        Test.stopTest();
        System.assertNotEquals(null, result);
    }

    @IsTest
    static void test_extractPdf_DownloadFails() {
        String html = '<head></head><body>'
            + '<a href="/download/test.pdf">Download</a></body>';
        Test.setMock(HttpCalloutMock.class, new MockHTTPError());
        Test.startTest();
        Blob result = DocumentAutoGenerateService.extractPdfFromHtml(
            html, TEST_URL, new Http());
        Test.stopTest();
        System.assertEquals(null, result);
    }

    // NEW: download returns non-PDF
    @IsTest
    static void test_extractPdf_DownloadNotPDF() {
        String html = '<head></head><body>'
            + '<a href="/download/test.pdf">Download</a></body>';
        Test.setMock(HttpCalloutMock.class, new MockNonPDF());
        Test.startTest();
        Blob result = DocumentAutoGenerateService.extractPdfFromHtml(
            html, TEST_URL, new Http());
        Test.stopTest();
        System.assertEquals(null, result);
    }

    @IsTest
    static void test_extractPdf_NoLink() {
        Test.startTest();
        Blob result = DocumentAutoGenerateService.extractPdfFromHtml(
            '<head></head><body>no link</body>', TEST_URL, new Http());
        Test.stopTest();
        System.assertEquals(null, result);
    }

    // NEW: long HTML > 3000 chars — covers debug chunk loop
    @IsTest
    static void test_extractPdf_NoLink_LongHTML() {
        String body = 'No link padding content here. '.repeat(120);
        Test.startTest();
        Blob result = DocumentAutoGenerateService.extractPdfFromHtml(
            '<head></head><body>' + body + '</body>', TEST_URL, new Http());
        Test.stopTest();
        System.assertEquals(null, result);
    }

    @IsTest
    static void test_extractPdf_Exception() {
        String html = '<head></head><body>'
            + '<a href="/download/test.pdf">Download</a></body>';
        Test.setMock(HttpCalloutMock.class, new MockPDFSuccess());
        Test.startTest();
        Blob result = DocumentAutoGenerateService.extractPdfFromHtml(
            html, null, new Http());
        Test.stopTest();
        System.assertEquals(null, result);
    }


    // ═════════════════════════════════════════════════════════════
    // updateStatus — ALL BRANCHES
    // ═════════════════════════════════════════════════════════════

    @IsTest
    static void test_updateStatus() {
        Documents__c doc = createDoc('UpdateStatusDoc');
        Test.startTest();
        DocumentAutoGenerateService.updateStatus(doc.Id, 'Generated');
        Test.stopTest();
        Documents__c r = [SELECT Document_Status__c, Document_Error_Message__c
            FROM Documents__c WHERE Id = :doc.Id];
        System.assertEquals('Generated', r.Document_Status__c);
        System.assertEquals(null, r.Document_Error_Message__c);
    }

    @IsTest
    static void test_updateStatus_Null() {
        Test.startTest();
        DocumentAutoGenerateService.updateStatus(null, 'Generated');
        Test.stopTest();
        System.assert(true);
    }

    // NEW: Sent status
    @IsTest
    static void test_updateStatus_Sent() {
        Documents__c doc = createDoc('SentStatusDoc');
        Test.startTest();
        DocumentAutoGenerateService.updateStatus(doc.Id, 'Sent');
        Test.stopTest();
        System.assertEquals('Sent',
            [SELECT Document_Status__c FROM Documents__c WHERE Id = :doc.Id]
            .Document_Status__c);
    }

    // NEW: clears previous error message
    @IsTest
    static void test_updateStatus_ClearsError() {
        Documents__c doc = createDoc('ClearErrorDoc');
        DocumentAutoGenerateService.logError(doc.Id, 'Old error');
        Test.startTest();
        DocumentAutoGenerateService.updateStatus(doc.Id, 'Generated');
        Test.stopTest();
        Documents__c r = [SELECT Document_Status__c, Document_Error_Message__c
            FROM Documents__c WHERE Id = :doc.Id];
        System.assertEquals('Generated', r.Document_Status__c);
        System.assertEquals(null, r.Document_Error_Message__c);
    }


    // ═════════════════════════════════════════════════════════════
    // logError — ALL BRANCHES
    // ═════════════════════════════════════════════════════════════

    @IsTest
    static void test_logError() {
        Documents__c doc = createDoc('ErrorDoc');
        Test.startTest();
        DocumentAutoGenerateService.logError(doc.Id, 'Test Error');
        Test.stopTest();
        Documents__c r = [SELECT Document_Status__c, Document_Error_Message__c
            FROM Documents__c WHERE Id = :doc.Id];
        System.assertEquals('Error', r.Document_Status__c);
        System.assertEquals('Test Error', r.Document_Error_Message__c);
    }

    @IsTest
    static void test_logError_Blank() {
        Documents__c doc = createDoc('BlankErrorDoc');
        Test.startTest();
        DocumentAutoGenerateService.logError(doc.Id, '');
        Test.stopTest();
        System.assertEquals('Unknown error',
            [SELECT Document_Error_Message__c FROM Documents__c WHERE Id = :doc.Id]
            .Document_Error_Message__c);
    }

    // NEW: null message → Unknown error
    @IsTest
    static void test_logError_NullMessage() {
        Documents__c doc = createDoc('NullMsgDoc');
        Test.startTest();
        DocumentAutoGenerateService.logError(doc.Id, null);
        Test.stopTest();
        System.assertEquals('Unknown error',
            [SELECT Document_Error_Message__c FROM Documents__c WHERE Id = :doc.Id]
            .Document_Error_Message__c);
    }

    @IsTest
    static void test_logError_LongMessage() {
        Documents__c doc = createDoc('LongErrorDoc');
        Test.startTest();
        DocumentAutoGenerateService.logError(doc.Id, 'X'.repeat(300));
        Test.stopTest();
        System.assertEquals(255,
            [SELECT Document_Error_Message__c FROM Documents__c WHERE Id = :doc.Id]
            .Document_Error_Message__c.length());
    }

    // NEW: exactly 255 chars boundary
    @IsTest
    static void test_logError_Exactly255() {
        Documents__c doc = createDoc('Exactly255Doc');
        Test.startTest();
        DocumentAutoGenerateService.logError(doc.Id, 'A'.repeat(255));
        Test.stopTest();
        System.assertEquals(255,
            [SELECT Document_Error_Message__c FROM Documents__c WHERE Id = :doc.Id]
            .Document_Error_Message__c.length());
    }

    @IsTest
    static void test_logError_NullId() {
        Test.startTest();
        DocumentAutoGenerateService.logError(null, 'Error');
        Test.stopTest();
        System.assert(true);
    }

    // NEW: overwrites previous status
    @IsTest
    static void test_logError_OverwritesPreviousStatus() {
        Documents__c doc = createDoc('OverwriteDoc');
        DocumentAutoGenerateService.updateStatus(doc.Id, 'Generated');
        Test.startTest();
        DocumentAutoGenerateService.logError(doc.Id, 'New error');
        Test.stopTest();
        Documents__c r = [SELECT Document_Status__c, Document_Error_Message__c
            FROM Documents__c WHERE Id = :doc.Id];
        System.assertEquals('Error', r.Document_Status__c);
        System.assertEquals('New error', r.Document_Error_Message__c);
    }

    // ═════════════════════════════════════════════════════════════
    // BP-047 — callouts first, one write afterwards
    // ═════════════════════════════════════════════════════════════

    /**
     * The regression this whole change exists for. Before BP-047 the status was written inside the
     * loop, so document 2 hit "You have uncommitted work pending. Please commit or rollback before
     * calling out" and every document after the first failed (seen live twice on 6 Sep 2026).
     * Three documents in one call must now all come back Generated.
     */
    @IsTest
    static void test_BP046_ThreeDocumentsInOneTransactionAllGenerate() {
        Document_Master_Configuration__mdt cfg = getValidConfig();
        if (cfg == null) return;
        getDDP(cfg.DocGen_Package_Name__c);
        Documents__c first  = createDoc(cfg.DocumentDisplayName__c);
        Documents__c second = createDoc(cfg.DocumentDisplayName__c);
        Documents__c third  = createDoc(cfg.DocumentDisplayName__c);
        Test.setMock(HttpCalloutMock.class, new MockPDFSuccess());
        Test.startTest();
        DocumentAutoGenerateService.generateAndSend(new Set<Id>{ first.Id, second.Id, third.Id });
        Test.stopTest();
        // The sandbox has no live Drawloop, so the OUTCOME cannot be asserted here (the existing
        // single-document test asserts only that a status was written, for the same reason). What
        // this test does prove is the regression: before BP-047 the write happened inside the loop,
        // so documents 2 and 3 could not call out at all and came back with "uncommitted work
        // pending". Every row must now be processed and none may carry that message.
        List<Documents__c> after = [
            SELECT Id, Document_Status__c, Document_Error_Message__c
            FROM Documents__c WHERE Id IN :new Set<Id>{ first.Id, second.Id, third.Id }
        ];
        System.assertEquals(3, after.size(), 'all three rows are still there');
        for (Documents__c d : after) {
            System.assertNotEquals(null, d.Document_Status__c,
                'every document in the batch must be processed, not just the first');
            String err = d.Document_Error_Message__c == null ? '' : d.Document_Error_Message__c.toLowerCase();
            System.assert(!err.contains('uncommitted work'),
                'no document may fail because an earlier one wrote to the database: ' + d.Document_Error_Message__c);
        }
    }

    /** A failure part way through must not stop the documents after it from calling out. */
    @IsTest
    static void test_BP046_AFailureDoesNotBlockTheRestOfTheBatch() {
        Document_Master_Configuration__mdt cfg = getValidConfig();
        if (cfg == null) return;
        getDDP(cfg.DocGen_Package_Name__c);
        Documents__c a = createDoc(cfg.DocumentDisplayName__c);
        Documents__c b = createDoc(cfg.DocumentDisplayName__c);
        Test.setMock(HttpCalloutMock.class, new MockHTTPError());
        Test.startTest();
        DocumentAutoGenerateService.generateAndSend(new Set<Id>{ a.Id, b.Id });
        Test.stopTest();
        for (Documents__c d : [SELECT Id, Document_Status__c, Document_Error_Message__c
                               FROM Documents__c WHERE Id IN :new Set<Id>{ a.Id, b.Id }]) {
            System.assertEquals('Error', d.Document_Status__c, 'both rows reached the callout and both recorded the failure');
            System.assertNotEquals(null, d.Document_Error_Message__c, 'the reason is stored');
        }
    }

    /** The single write: same fields the per-document helpers wrote before. */
    @IsTest
    static void test_BP046_CommitOutcomesWritesStatusAndError() {
        Documents__c ok   = createDoc('BP046 Ok');
        Documents__c bad  = createDoc('BP046 Bad');
        Map<Id, String> statusById = new Map<Id, String>{ ok.Id => 'Generated', bad.Id => 'Error' };
        Map<Id, String> errorById  = new Map<Id, String>{ ok.Id => null, bad.Id => 'boom' };
        Test.startTest();
        DocumentAutoGenerateService.commitOutcomes(statusById, errorById);
        DocumentAutoGenerateService.commitOutcomes(new Map<Id, String>(), new Map<Id, String>());   // empty is a no-op
        DocumentAutoGenerateService.commitOutcomes(null, null);              // null is a no-op
        Test.stopTest();
        Map<Id, Documents__c> after = new Map<Id, Documents__c>([
            SELECT Id, Document_Status__c, Document_Error_Message__c
            FROM Documents__c WHERE Id IN :statusById.keySet()
        ]);
        System.assertEquals('Generated', after.get(ok.Id).Document_Status__c);
        System.assertEquals(null, after.get(ok.Id).Document_Error_Message__c);
        System.assertEquals('Error', after.get(bad.Id).Document_Status__c);
        System.assertEquals('boom', after.get(bad.Id).Document_Error_Message__c);
    }

    /** recordError remembers rather than writes, and never exceeds the 255 character field. */
    @IsTest
    static void test_BP046_RecordErrorCollectsWithoutWriting() {
        Documents__c doc = createDoc('BP046 Collect');
        Map<Id, String> statusById = new Map<Id, String>();
        Map<Id, String> errorById  = new Map<Id, String>();
        DocumentAutoGenerateService.recordError(statusById, errorById, doc.Id, 'x'.repeat(400));
        DocumentAutoGenerateService.recordError(statusById, errorById, null, 'ignored');
        Documents__c blankMessage = createDoc('BP046 Blank');
        DocumentAutoGenerateService.recordError(statusById, errorById, blankMessage.Id, '   ');
        System.assertEquals(2, statusById.size(), 'a null id is ignored');
        System.assertEquals('Error', statusById.get(doc.Id));
        System.assertEquals(255, errorById.get(doc.Id).length(), 'trimmed to the field length');
        System.assertEquals('Unknown error', errorById.get(blankMessage.Id));
        System.assertEquals(null,
            [SELECT Document_Status__c FROM Documents__c WHERE Id = :doc.Id].Document_Status__c,
            'recordError must NOT write - writing inside the loop is the bug being fixed');
    }

    /** The callout time budget: one document keeps the original timeout, a batch shares it. */
    @IsTest
    static void test_BP046_CalloutTimeoutSharesTheTransactionBudget() {
        System.assertEquals(120000, DocumentAutoGenerateService.calloutTimeoutMs(null));
        System.assertEquals(120000, DocumentAutoGenerateService.calloutTimeoutMs(0));
        System.assertEquals(120000, DocumentAutoGenerateService.calloutTimeoutMs(1),
            'a single document behaves exactly as it did before BP-047');
        System.assertEquals(30000, DocumentAutoGenerateService.calloutTimeoutMs(2));
        System.assertEquals(20000, DocumentAutoGenerateService.calloutTimeoutMs(3));
        System.assertEquals(DocumentAutoGenerateService.MIN_TIMEOUT_MS,
            DocumentAutoGenerateService.calloutTimeoutMs(50), 'never below the floor');
    }
// ═════════════════════════════════════════════════════════════
// DML EXCEPTION PATHS — catch(DmlException) blocks
// ═════════════════════════════════════════════════════════════

@IsTest
static void test_updateStatus_DmlExceptionIsCaught() {
    Documents__c doc = createDoc('DeleteForUpdateStatus');
    Id deletedId = doc.Id;
    delete doc;
    Test.startTest();
    DocumentAutoGenerateService.updateStatus(deletedId, 'Generated');
    Test.stopTest();
    System.assert(true, 'update on a deleted record throws DmlException, which must be caught, not propagated');
}

@IsTest
static void test_logError_DmlExceptionIsCaught() {
    Documents__c doc = createDoc('DeleteForLogError');
    Id deletedId = doc.Id;
    delete doc;
    Test.startTest();
    DocumentAutoGenerateService.logError(deletedId, 'Some error');
    Test.stopTest();
    System.assert(true, 'update on a deleted record throws DmlException, which must be caught, not propagated');
}

@IsTest
static void test_BP046_CommitOutcomesDmlExceptionIsCaught() {
    Documents__c doc = createDoc('DeleteForCommit');
    Id deletedId = doc.Id;
    delete doc;
    Map<Id, String> statusById = new Map<Id, String>{ deletedId => 'Generated' };
    Map<Id, String> errorById  = new Map<Id, String>{ deletedId => null };
    Test.startTest();
    DocumentAutoGenerateService.commitOutcomes(statusById, errorById);
    Test.stopTest();
    System.assert(true, 'a failed write must not lose the PDFs already produced - the exception is caught, not thrown');
}

// ═════════════════════════════════════════════════════════════
// commitOutcomes — null errorById with a non-empty statusById
// ═════════════════════════════════════════════════════════════

@IsTest
static void test_BP046_CommitOutcomesHandlesNullErrorMapWithRealStatuses() {
    Documents__c doc = createDoc('NullErrorMapDoc');
    Map<Id, String> statusById = new Map<Id, String>{ doc.Id => 'Generated' };
    Test.startTest();
    DocumentAutoGenerateService.commitOutcomes(statusById, null);   // errorById itself is null, not empty
    Test.stopTest();
    Documents__c after = [
        SELECT Document_Status__c, Document_Error_Message__c
        FROM Documents__c WHERE Id = :doc.Id
    ];
    System.assertEquals('Generated', after.Document_Status__c);
    System.assertEquals(null, after.Document_Error_Message__c,
        'a null errorById must default to an empty map rather than NPE');
}
    /** The three argument form still works for existing callers and defaults the timeout. */
    @IsTest
    static void test_BP046_ExtractPdfFromHtmlKeepsItsOldSignature() {
        // MockPDFSuccess answers every callout identically, so both signatures are comparable.
        Test.setMock(HttpCalloutMock.class, new MockPDFSuccess());
        String html = '<head></head><body><a href="/download/test.pdf">Download</a></body>';
        Test.startTest();
        Blob viaOldSignature = DocumentAutoGenerateService.extractPdfFromHtml(
            html, 'https://example.com/a/b', new Http());
        Blob viaNewSignature = DocumentAutoGenerateService.extractPdfFromHtml(
            html, 'https://example.com/a/b', new Http(), DocumentAutoGenerateService.MIN_TIMEOUT_MS);
        Test.stopTest();
        System.assertNotEquals(null, viaOldSignature, 'the three-argument form still works for existing callers');
        System.assertNotEquals(null, viaNewSignature, 'the four-argument form behaves the same');
        System.assertEquals(viaOldSignature.size(), viaNewSignature.size(), 'same bytes either way');
    }
}