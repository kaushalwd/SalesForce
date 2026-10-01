/* **
 * 1.0          Sivannarayana                               27 June 2026    Initial Draft
 * 2.0          pprajapati@horizontal.com                   02 Sept 2026    Added test coverage for selected receipts constructor
 * 2.1          pprajapati@horizontal.com                   03 Sept 2026    Added test coverage for 1 Case per EOI and multiple EOIs execution
 * 2.2          pprajapati@horizontal.com                   04 Sept 2026    Added test coverage for Management MEMO document linking
 ****/
@IsTest
private class CaseInsertEOIRefundTargetBatchTest {

    private class MockWhatsAppResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"success":true}');
            res.setStatusCode(200);
            return res;
        }
    }

    @TestSetup
    static void setupData() {

        Id personAccountRecordTypeId = Schema.SObjectType.Account
            .getRecordTypeInfosByDeveloperName()
            .get('PersonAccount')
            .getRecordTypeId();

        Account acc = new Account(
            RecordTypeId = personAccountRecordTypeId,
            LastName = 'Unidentified Account (MRE Finance)',
            PersonEmail = 'customer@test.com',
            PersonMobilePhone = '971501234567'
        );
        Database.insert(acc, AccessLevel.SYSTEM_MODE);

        Project__c proj = new Project__c(
            Name = 'Hudayriyat Golf Estates',
            EOI_Limit__c = 10
        );
        Database.insert(proj, AccessLevel.SYSTEM_MODE);

        Opportunity opp = new Opportunity(
            Name = 'EOI Refund Opportunity',
            StageName = 'Prospecting',
            CloseDate = System.today().addDays(10),
            AccountId = acc.Id
        );
        Database.insert(opp, AccessLevel.SYSTEM_MODE);

        Expressionofinterest__c eoi = new Expressionofinterest__c(
            Opportunity__c = opp.Id,
            Project__c = proj.Id,
            Account__c = acc.Id,
            EOI_Amount_AED__c = 10000,
            Status__c = 'In progress',
            Eligible_for_Refund__c = true
        );
        Database.insert(eoi, AccessLevel.SYSTEM_MODE);

        Receipt__c rec = new Receipt__c(
            Account__c = acc.Id,
            ExpressionOfInterest__c = eoi.Id,
            Status__c = 'Cleared',
            EBS_Clearing_Date__c = Date.today(),
            Receipt_Amount__c = 50000,
            TotalAmount__c = 50000
        );
        Database.insert(rec, AccessLevel.SYSTEM_MODE);

        SalesOrder__c so = new SalesOrder__c(
            Opportunity__c = opp.Id,
            Status__c = 'Voided'
        );
        Database.insert(so, AccessLevel.SYSTEM_MODE);

        Receipt__c rec2 = new Receipt__c(
            Account__c = acc.Id,
            ExpressionOfInterest__c = eoi.Id,
            SalesOrder__c = so.Id,
            Status__c = 'Cleared',
            EBS_Clearing_Date__c = Date.today(),
            Receipt_Amount__c = 25000,
            TotalAmount__c = 25000
        );
        Database.insert(rec2, AccessLevel.SYSTEM_MODE);

        // Second EOI for multi-EOI testing
        Expressionofinterest__c eoi2 = new Expressionofinterest__c(
            Opportunity__c = opp.Id,
            Project__c = proj.Id,
            Account__c = acc.Id,
            EOI_Amount_AED__c = 15000,
            Status__c = 'In progress',
            Eligible_for_Refund__c = true
        );
        Database.insert(eoi2, AccessLevel.SYSTEM_MODE);

        Receipt__c rec3 = new Receipt__c(
            Account__c = acc.Id,
            ExpressionOfInterest__c = eoi2.Id,
            Status__c = 'Cleared',
            EBS_Clearing_Date__c = Date.today(),
            Receipt_Amount__c = 15000,
            TotalAmount__c = 15000
        );
        Database.insert(rec3, AccessLevel.SYSTEM_MODE);
    }

    @IsTest
    static void testBatchDefaultConstructor() {

        Test.setMock(HttpCalloutMock.class, new MockWhatsAppResponse());

        Test.startTest();
        Database.executeBatch(new CaseInsertEOIRefundTargetBatch(), 1);
        Test.stopTest();

        validateBatchResult();
    }

    @IsTest
    static void testBatchWithEOIIdsConstructor() {

        Expressionofinterest__c eoi = [
            SELECT Id
            FROM Expressionofinterest__c
            LIMIT 1
        ];

        Test.setMock(HttpCalloutMock.class, new MockWhatsAppResponse());

        Test.startTest();
        Database.executeBatch(
            new CaseInsertEOIRefundTargetBatch(new List<Id>{ eoi.Id }),
            1
        );
        Test.stopTest();

        validateBatchResult();
    }

    @IsTest
    static void testBatchWithSelectedReceiptsConstructor() {

        Expressionofinterest__c eoi = [
            SELECT Id
            FROM Expressionofinterest__c
            LIMIT 1
        ];

        Receipt__c rec = [
            SELECT Id
            FROM Receipt__c
            WHERE ExpressionOfInterest__c = :eoi.Id
            LIMIT 1
        ];

        Test.setMock(HttpCalloutMock.class, new MockWhatsAppResponse());

        Test.startTest();
        Database.executeBatch(
            new CaseInsertEOIRefundTargetBatch(
                new List<Id>{ eoi.Id },
                new List<Id>{ rec.Id }
            ),
            1
        );
        Test.stopTest();

        Expressionofinterest__c updatedEOI = [
            SELECT Id, Case__c
            FROM Expressionofinterest__c
            WHERE Id = :eoi.Id
        ];
        System.assertNotEquals(null, updatedEOI.Case__c, 'EOI should be linked to Case');

        Receipt__c updatedReceipt = [
            SELECT Id, Case__c
            FROM Receipt__c
            WHERE Id = :rec.Id
        ];
        System.assertNotEquals(null, updatedReceipt.Case__c, 'Selected receipt should be linked to Case');
    }

    @IsTest
    static void testBatchWithMultipleEOIs() {
        List<Expressionofinterest__c> eois = [
            SELECT Id
            FROM Expressionofinterest__c
            LIMIT 2
        ];
        List<Id> eoiIds = new List<Id>{ eois[0].Id, eois[1].Id };

        Test.setMock(HttpCalloutMock.class, new MockWhatsAppResponse());

        Test.startTest();
        Database.executeBatch(
            new CaseInsertEOIRefundTargetBatch(eoiIds),
            2
        );
        Test.stopTest();

        // Verify 1 Case per EOI
        Expressionofinterest__c updatedEOI1 = [SELECT Id, Case__c FROM Expressionofinterest__c WHERE Id = :eois[0].Id];
        Expressionofinterest__c updatedEOI2 = [SELECT Id, Case__c FROM Expressionofinterest__c WHERE Id = :eois[1].Id];

        System.assertNotEquals(null, updatedEOI1.Case__c, 'EOI 1 should have a Case');
        System.assertNotEquals(null, updatedEOI2.Case__c, 'EOI 2 should have a Case');
        System.assertNotEquals(updatedEOI1.Case__c, updatedEOI2.Case__c, 'Each EOI should have its own separate Case');
    }

    private static void validateBatchResult() {

        Expressionofinterest__c updatedEOI = [
            SELECT Id, Case__c
            FROM Expressionofinterest__c
            WHERE Case__c != null
            LIMIT 1
        ];

        System.assertNotEquals(null, updatedEOI.Case__c);

        Case cs = [
            SELECT Id,
                   Subject,
                   Status,
                   CaseCategory__c,
                   Refund_Status__c,
                   Whats_App_Integration_Status__c,
                   Expression_of_Interest__c
            FROM Case
            WHERE Id = :updatedEOI.Case__c
            LIMIT 1
        ];

        System.assertNotEquals(null, cs.Id);
    }

    @IsTest
    static void testBatchWithContentDocument() {
        Test.setMock(HttpCalloutMock.class, new MockWhatsAppResponse());

        // Create test ContentVersion for Management MEMO
        ContentVersion cv = new ContentVersion(
            Title = 'Management MEMO',
            PathOnClient = 'Management_MEMO.pdf',
            VersionData = Blob.valueOf('Test Content'),
            IsMajorVersion = true
        );
        insert cv;
        Id contentDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;

        Expressionofinterest__c eoi = [SELECT Id FROM Expressionofinterest__c LIMIT 1];
        List<Receipt__c> recs = [SELECT Id FROM Receipt__c WHERE ExpressionOfInterest__c = :eoi.Id AND Status__c = 'Cleared'];
        List<Id> receiptIds = new List<Id>{ recs[0].Id };

        Test.startTest();
        CaseInsertEOIRefundTargetBatch batch = new CaseInsertEOIRefundTargetBatch(
            new List<Id>{ eoi.Id },
            receiptIds,
            contentDocId
        );
        Database.executeBatch(batch, 1);
        Test.stopTest();

        Expressionofinterest__c updatedEOI = [SELECT Id, Case__c FROM Expressionofinterest__c WHERE Id = :eoi.Id];
        System.assertNotEquals(null, updatedEOI.Case__c, 'Case should be created');

        List<ContentDocumentLink> cdls = [
            SELECT Id, ContentDocumentId, LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :updatedEOI.Case__c
            AND ContentDocumentId = :contentDocId
        ];
        System.assert(cdls.size() > 0, 'Management MEMO ContentDocumentLink should be attached to Case');
    }
}