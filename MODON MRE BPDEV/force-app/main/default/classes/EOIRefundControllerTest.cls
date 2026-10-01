/**********************************************************************************************************************
 * Name               : EOIRefundControllerTest
 * Description        : Test class for EOIRefundController.
 * Created By         : pprajapati@horizontal.com
 * --------------------------------------------------------------------------------------------------------------------
 * Version       Author                              Date            Comment
 * 1.0           pprajapati@horizontal.com           02 Sept 2026    Initial Draft for EOIRefundController unit tests
 * 2.0           pprajapati@horizontal.com           03 Sept 2026    Updated for partitioned receipts and multi-EOI submission
 * 3.0           pprajapati@horizontal.com           08 Sept 2026    Updated for Business Process creation flow and validation
 **********************************************************************************************************************/
@IsTest
private class EOIRefundControllerTest {

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
    static void setupTestData() {
        Id personRtId = Schema.SObjectType.Account
            .getRecordTypeInfosByDeveloperName()
            .get('PersonAccount')
            .getRecordTypeId();

        Account acc = new Account(
            RecordTypeId = personRtId,
            LastName = 'Unidentified Account (MRE Finance)',
            PersonEmail = 'refund.customer@test.com',
            PersonMobilePhone = '971509876543'
        );
        Database.insert(acc, AccessLevel.SYSTEM_MODE);

        Project__c proj = new Project__c(
            Name = 'Al Hadeel Community',
            EOI_Limit__c = 50
        );
        Database.insert(proj, AccessLevel.SYSTEM_MODE);

        Opportunity opp = new Opportunity(
            Name = 'Refund Test Opportunity',
            StageName = 'Prospecting',
            CloseDate = System.today().addDays(30),
            AccountId = acc.Id
        );
        Database.insert(opp, AccessLevel.SYSTEM_MODE);

        Expressionofinterest__c eoi = new Expressionofinterest__c(
            Opportunity__c = opp.Id,
            Project__c = proj.Id,
            Account__c = acc.Id,
            EOI_Amount_AED__c = 25000,
            Status__c = 'In progress',
            Eligible_for_Refund__c = true
        );
        Database.insert(eoi, AccessLevel.SYSTEM_MODE);

        // Eligible receipt 1
        Receipt__c rec1 = new Receipt__c(
            Account__c = acc.Id,
            ExpressionOfInterest__c = eoi.Id,
            Status__c = 'Cleared',
            EBS_Clearing_Date__c = Date.today(),
            TotalAmount__c = 15000,
            Receipt_Amount__c = 15000
        );
        Database.insert(rec1, AccessLevel.SYSTEM_MODE);

        SalesOrder__c so = new SalesOrder__c(
            Opportunity__c = opp.Id,
            Status__c = 'Voided'
        );
        Database.insert(so, AccessLevel.SYSTEM_MODE);

        // Eligible receipt 2
        Receipt__c rec2 = new Receipt__c(
            Account__c = acc.Id,
            ExpressionOfInterest__c = eoi.Id,
            SalesOrder__c = so.Id,
            Status__c = 'Cleared',
            EBS_Clearing_Date__c = Date.today(),
            TotalAmount__c = 10000,
            Receipt_Amount__c = 10000
        );
        Database.insert(rec2, AccessLevel.SYSTEM_MODE);

        // Ineligible receipt 3 (Status is In Progress, not Cleared)
        Receipt__c rec3 = new Receipt__c(
            Account__c = acc.Id,
            ExpressionOfInterest__c = eoi.Id,
            Status__c = 'In Progress',
            TotalAmount__c = 5000,
            Receipt_Amount__c = 5000
        );
        Database.insert(rec3, AccessLevel.SYSTEM_MODE);

        // Ensure Process_Flow__c 'EOI Refund Approval' exists
        List<Process_Flow__c> flows = [SELECT Id FROM Process_Flow__c WHERE Name = 'EOI Refund Approval'];
        if (flows.isEmpty()) {
            Process_Flow__c pf = new Process_Flow__c(
                Name = 'EOI Refund Approval',
                Process_Flow_Unique_Name__c = 'EOI Refund Approval',
                Active__c = true
            );
            Database.insert(pf, AccessLevel.SYSTEM_MODE);

            Process_Flow_Step__c pfs1 = new Process_Flow_Step__c(
                Section_Number__c = 1,
                section_Name__c = 'Sales Operations Director Approval',
                Description__c = 'Sales Operations Director Approval',
                Step_Name__c = 'Sales Operations Director Approval',
                Process_Flow__c = pf.Id,
                Setp_No__c = 1,
                Department_Queue__c = UserInfo.getUserId(),
                Active__c = true
            );
            Process_Flow_Step__c pfs2 = new Process_Flow_Step__c(
                Section_Number__c = 2,
                section_Name__c = 'CCO Approval',
                Description__c = 'CCO Approval',
                Step_Name__c = 'CCO Approval',
                Process_Flow__c = pf.Id,
                Setp_No__c = 2,
                Department_Queue__c = UserInfo.getUserId(),
                Active__c = true
            );
            Database.insert(new List<Process_Flow_Step__c>{ pfs1, pfs2 }, AccessLevel.SYSTEM_MODE);
        }
    }

    @IsTest
    static void testGetEligibleProjects() {
        Test.startTest();
        List<EOIRefundController.OptionWrapper> projects = EOIRefundController.getEligibleProjects();
        Test.stopTest();

        System.assertNotEquals(null, projects, 'Projects list should not be null');
        System.assert(projects.size() > 0, 'There should be at least one eligible project');
        System.assertEquals('Al Hadeel Community', projects[0].label);
    }

    @IsTest
    static void testGetEligibleEOIs() {
        Project__c proj = [SELECT Id FROM Project__c LIMIT 1];

        Test.startTest();
        List<EOIRefundController.EOIWrapper> eois = EOIRefundController.getEligibleEOIs(proj.Id);
        List<EOIRefundController.EOIWrapper> emptyEOIs = EOIRefundController.getEligibleEOIs(null);
        Test.stopTest();

        System.assertNotEquals(null, eois, 'EOIs list should not be null');
        System.assertEquals(1, eois.size(), 'Should return 1 matching EOI');
        System.assertEquals(0, emptyEOIs.size(), 'Null project should return empty list');
        System.assert(eois[0].opportunityName.contains('Refund Test Opportunity'), 'Opportunity name should match');
        System.assertEquals(2, eois[0].eligibleCount, 'Should have 2 eligible receipts');
        System.assertEquals(1, eois[0].uneligibleCount, 'Should have 1 ineligible receipt');
        System.assertEquals(25000, eois[0].totalEligibleAmount, 'Total eligible amount should be 25000');
    }

    @IsTest
    static void testGetEligibleReceipts() {
        Expressionofinterest__c eoi = [SELECT Id FROM Expressionofinterest__c LIMIT 1];

        Test.startTest();
        List<EOIRefundController.ReceiptWrapper> receipts = EOIRefundController.getEligibleReceipts(eoi.Id);
        List<EOIRefundController.ReceiptWrapper> emptyReceipts = EOIRefundController.getEligibleReceipts(null);
        Test.stopTest();

        System.assertNotEquals(null, receipts, 'Receipts list should not be null');
        System.assertEquals(2, receipts.size(), 'Should return 2 matching receipts');
        System.assertEquals(0, emptyReceipts.size(), 'Null eoi should return empty list');
    }

    @IsTest
    static void testSubmitRefundRequest_Success() {
        Test.setMock(HttpCalloutMock.class, new MockWhatsAppResponse());

        // Create test ContentVersion for Management MEMO
        ContentVersion cv = new ContentVersion(
            Title = 'Management MEMO',
            PathOnClient = 'Management_MEMO.pdf',
            VersionData = Blob.valueOf('Test Memo Data'),
            IsMajorVersion = true
        );
        insert cv;
        Id contentDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;

        Expressionofinterest__c eoi = [SELECT Id FROM Expressionofinterest__c LIMIT 1];
        List<Receipt__c> recs = [SELECT Id FROM Receipt__c WHERE ExpressionOfInterest__c = :eoi.Id AND Status__c = 'Cleared'];
        List<Id> receiptIds = new List<Id>{ recs[0].Id };

        Test.startTest();
        EOIRefundController.RefundResult result = EOIRefundController.submitRefundRequest(new List<Id>{ eoi.Id }, receiptIds, contentDocId);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(true, result.isSuccess, 'Request should succeed');
        System.assertNotEquals(null, result.businessProcessId, 'Business Process ID should be returned');
        System.assertNotEquals(null, result.businessProcessName, 'Business Process Name should be returned');

        // Verify EOI is tagged to the Business Process and has no Case yet
        Expressionofinterest__c updatedEoi = [SELECT Id, Business_Process__c, Case__c FROM Expressionofinterest__c WHERE Id = :eoi.Id];
        System.assertEquals(result.businessProcessId, updatedEoi.Business_Process__c, 'EOI should be tagged with Business Process Id');
        System.assertEquals(null, updatedEoi.Case__c, 'Case must NOT be created at submission time');

        // Verify Management MEMO file is linked to Business Process
        List<ContentDocumentLink> links = [
            SELECT Id, ContentDocumentId, LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :result.businessProcessId
            AND ContentDocumentId = :contentDocId
        ];
        System.assertEquals(1, links.size(), 'Management MEMO must be linked to Business Process');
    }

    @IsTest
    static void testSubmitRefundRequest_Validations() {
        Boolean caughtEoiException = false;
        try {
            EOIRefundController.submitRefundRequest(null, new List<Id>(), null);
        } catch (AuraHandledException e) {
            caughtEoiException = true;
        }
        System.assert(caughtEoiException, 'Should throw exception when EOI list is null');

        Boolean caughtDocException = false;
        Expressionofinterest__c eoi = [SELECT Id FROM Expressionofinterest__c LIMIT 1];
        try {
            // Passing a non-existent ContentDocument Id should fail validation
            EOIRefundController.submitRefundRequest(new List<Id>{ eoi.Id }, new List<Id>(), '069000000000000AAA');
        } catch (AuraHandledException e) {
            caughtDocException = true;
        }
        System.assert(caughtDocException, 'Should throw exception when Management MEMO document does not exist');
    }

    @IsTest
    static void testSubmitRefundRequest_OptionalDocument() {
        Test.setMock(HttpCalloutMock.class, new MockWhatsAppResponse());

        Expressionofinterest__c eoi = [SELECT Id FROM Expressionofinterest__c LIMIT 1];

        Test.startTest();
        // Submitting with contentDocumentId = null should succeed because document upload is optional
        EOIRefundController.RefundResult result = EOIRefundController.submitRefundRequest(
            new List<Id>{ eoi.Id },
            new List<Id>(),
            null
        );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(true, result.isSuccess, 'Request without document should succeed');
        System.assertNotEquals(null, result.businessProcessId, 'Business Process ID should be returned');

        // Verify no ContentDocumentLink was created
        List<ContentDocumentLink> links = [
            SELECT Id
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :result.businessProcessId
        ];
        System.assertEquals(0, links.size(), 'No ContentDocumentLink should be created when no document is uploaded');
    }

    @IsTest
    static void testSubmitRefundRequest_DuplicatePrevention() {
        ContentVersion cv = new ContentVersion(
            Title = 'Management MEMO',
            PathOnClient = 'Management_MEMO.pdf',
            VersionData = Blob.valueOf('Test Memo Data'),
            IsMajorVersion = true
        );
        insert cv;
        Id contentDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;

        Expressionofinterest__c eoi = [SELECT Id FROM Expressionofinterest__c LIMIT 1];

        // First submission creates Business Process
        EOIRefundController.RefundResult result1 = EOIRefundController.submitRefundRequest(
            new List<Id>{ eoi.Id },
            new List<Id>(),
            contentDocId
        );
        System.assertEquals(true, result1.isSuccess);

        // Second submission of the same EOI must fail
        Boolean caughtDuplicateException = false;
        try {
            EOIRefundController.submitRefundRequest(
                new List<Id>{ eoi.Id },
                new List<Id>(),
                contentDocId
            );
        } catch (AuraHandledException e) {
            caughtDuplicateException = true;
        }
        System.assert(caughtDuplicateException, 'Should prevent duplicate submission for EOI already in active BP');
    }
}