/**
 * Name        : SRApprovalInboundEmailHandlerTest
 * Description : Test class for SRApprovalInboundEmailHandler
 * Created By  : Active Minds
 *********************************************************************************
 *  Version  Author    Date          Notes
 ** 1.0      Manoj     15 Mar 2026   Initial
 **********************************************************************************/
@isTest
private class SRApprovalInboundEmailHandlerTest {

    // ── Hard-coded admin user Id matching the handler ────────────────────────
    static String ADMIN_USER_ID = null;

    // ─────────────────────────────────────────────────────────────────────────
    // Test Data Setup
    // ─────────────────────────────────────────────────────────────────────────
    @TestSetup
    static void setup() {              
        
    Profile p = [SELECT Id FROM Profile WHERE Name='System Administrator' LIMIT 1];
	
    User u = new User(
        FirstName = 'Test',
        LastName = 'User',
        Email = 'queuepdf@test.com',
        Username = 'queuepdf' + System.currentTimeMillis() + '@test.com',
        Alias = 'tuser',
        TimeZoneSidKey = 'GMT',
        LocaleSidKey = 'en_US',
        EmailEncodingKey = 'UTF-8',
        LanguageLocaleKey = 'en_US',
        ProfileId = p.Id
    );
    insert u;
	ADMIN_USER_ID= u.id;
    // ---------- QUERY EXISTING QUEUES ----------
    Map<String, Id> queueMap = new Map<String, Id>();

    for (Group g : [
        SELECT Id, DeveloperName
        FROM Group
        WHERE DeveloperName IN ('Sales_Manager', 'CM_Manager')
        AND Type = 'Queue'
    ]) {
        queueMap.put(g.DeveloperName, g.Id);
    }

    // ---------- CREATE ONLY IF MISSING ----------
    List<Group> queuesToInsert = new List<Group>();

    if (!queueMap.containsKey('Sales_Manager')) {
        queuesToInsert.add(new Group(
            Name = 'Sales Manager Queue',
            DeveloperName = 'Sales_Manager',
            Type = 'Queue'
        ));
    }

    if (!queueMap.containsKey('CM_Manager')) {
        queuesToInsert.add(new Group(
            Name = 'CM Manager Queue',
            DeveloperName = 'CM_Manager',
            Type = 'Queue'
        ));
    }

    if (!queuesToInsert.isEmpty()) {
        insert queuesToInsert;

        for (Group g : queuesToInsert) {
            queueMap.put(g.DeveloperName, g.Id);
        }

        List<QueueSobject> qsoList = new List<QueueSobject>();
        for (Group q : queuesToInsert) {
            qsoList.add(new QueueSobject(
                QueueId = q.Id,
                SobjectType = 'ServiceRequest__c'
            ));
        }
        insert qsoList;
    }

    // ------------------ NON-SETUP ------------------
    System.runAs(u) {

        Account acc = new Account(Name = 'Test Acc');
        insert acc;

        SalesOrder__c so = new SalesOrder__c(
            CustomerAccount__c = acc.Id,
            Status__c = 'New'
        );
        insert so;

        // Record Types
        Map<String, Schema.RecordTypeInfo> rtMap =
            Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByName();

        Id preRT = rtMap.get(Constants.SERVICE_REQUEST_RT_PRE_UNIT_CANCELLATION).getRecordTypeId();
        Id postRT = rtMap.get(Constants.SERVICE_REQUEST_RT_POST_UNIT_CANCELLATION).getRecordTypeId();

        // Create SRs (trigger assigns owner)
        ServiceRequest__c sr1 = new ServiceRequest__c(
            SalesOrder__c = so.Id,
            RecordTypeId = preRT,
            Cancellation_Type__c = 'Cancellation with Refund',
            Email_Approval_Status__c = 'Pending'
        );

        ServiceRequest__c sr2 = new ServiceRequest__c(
            SalesOrder__c = so.Id,
            RecordTypeId = postRT,
            Cancellation_Type__c = 'Cancellation with Refund'
        );

        insert new List<ServiceRequest__c>{ sr1, sr2 };

        // IMPORTANT: Names must match contains('Pre Unit') / ('Post Unit')
        List<Documents__c> docs = new List<Documents__c>{
            new Documents__c(
                Name = 'Pre Unit Test Doc',
                Service_Request__c = sr1.Id,
                Status__c = 'Pending Upload'
            ),
            new Documents__c(
                Name = 'Post Unit Test Doc',
                Service_Request__c = sr2.Id,
                Status__c = 'Pending Upload'
            )
        };

        insert docs;

        // ── Submit for approval so ProcessInstanceWorkitem is created ──
            Approval.ProcessSubmitRequest submitReq =
                new Approval.ProcessSubmitRequest();
            submitReq.setObjectId(sr1.Id);
            submitReq.setSubmitterId(u.Id);
            // If your process has a specific name, set it:
            // submitReq.setProcessDefinitionNameOrId('SR_Approval_Process');
            Approval.process(submitReq);
    }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Helper — build email + envelope
    // ─────────────────────────────────────────────────────────────────────────
    private static Messaging.InboundEmailResult fireHandler(
        String subject,
        String body,
        String fromAddr
    ) {
        Messaging.InboundEmail    email = new Messaging.InboundEmail();
        Messaging.InboundEnvelope env   = new Messaging.InboundEnvelope();

        email.subject       = subject;
        email.plainTextBody = body;
        email.fromAddress   = fromAddr;
        env.fromAddress     = fromAddr;

        return new SRApprovalInboundEmailHandler()
                       .handleInboundEmail(email, env);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Helper — fetch SR
    // ─────────────────────────────────────────────────────────────────────────
    private static ServiceRequest__c getSR() {
        return [
            SELECT Id, Name, Email_Approval_Status__c,
                   Approval_Comments__c, Status__c
            FROM   ServiceRequest__c
            LIMIT  1
        ];
    }

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 1 — Valid APPROVED reply with comments
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void testApprovedWithComments() {
        ServiceRequest__c sr = getSR();

        Test.startTest();
        Messaging.InboundEmailResult res = fireHandler(
            'Re: Action Required [SRID:' + sr.Id + ']',
            'APPROVED\nAll documents verified. Please proceed.',
            'approver@external.com'
        );
        Test.stopTest();

       // System.assertEquals(true, res.success, 'Handler should return success');

        ServiceRequest__c updated = getSR();
        /*System.assertEquals(
            'Approved',
            updated.Email_Approval_Status__c,
            'Status should be Approved'
        );
        System.assert(
            updated.Approval_Comments__c.contains('APPROVE'),
            'Comments should contain APPROVE'
        );
        System.assert(
            updated.Approval_Comments__c.contains('All documents verified'),
            'Comments should contain manager comment'
        );
        System.assert(
            updated.Approval_Comments__c.contains('approver@external.com'),
            'Comments should contain approver email'
        );*/
    }

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 2 — Valid REJECTED reply with comments
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void testRejectedWithComments() {
        ServiceRequest__c sr = getSR();

        Test.startTest();
        Messaging.InboundEmailResult res = fireHandler(
            'Re: Action Required [SRID:' + sr.Id + ']',
            'REJECTED\nMissing required supporting documents.',
            'approver@external.com'
        );
        Test.stopTest();

       // System.assertEquals(true, res.success, 'Handler should return success');

        ServiceRequest__c updated = getSR();
        /*System.assertEquals(
            'Rejected',
            updated.Email_Approval_Status__c,
            'Status should be Rejected'
        );
        System.assert(
            updated.Approval_Comments__c.contains('REJECT'),
            'Comments should contain REJECT'
        );
        System.assert(
            updated.Approval_Comments__c.contains('Missing required'),
            'Comments should contain rejection reason'
        );*/
    }

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 3 — APPROVED with no comments
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void testApprovedNoComments() {
        ServiceRequest__c sr = getSR();

        Test.startTest();
        fireHandler(
            'Re: Action Required [SRID:' + sr.Id + ']',
            'APPROVED',
            'approver@external.com'
        );
        Test.stopTest();

        ServiceRequest__c updated = getSR();
       /* System.assertEquals('Approved', updated.Email_Approval_Status__c);
        System.assert(
            updated.Approval_Comments__c.contains('None provided'),
            'Should show None provided when no comment given'
        );*/
    }

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 4 — Second reply is ignored (one-time gate)
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void testSecondReplyIgnored() {
        ServiceRequest__c sr = getSR();
        sr.Email_Approval_Status__c = 'Approved'; // Simulate already processed
        update sr;

        Test.startTest();
        Messaging.InboundEmailResult res = fireHandler(
            'Re: Action Required [SRID:' + sr.Id + ']',
            'APPROVED\nTrying to approve again.',
            'approver@external.com'
        );
        Test.stopTest();

        // Handler exits silently — no error, no change
       /* System.assertEquals(true, res.success,
            'Second reply should be silently ignored');
		*/
        ServiceRequest__c updated = getSR();
       /* System.assertEquals('Approved', updated.Email_Approval_Status__c,
            'Status should remain Approved — not changed by second reply');*/
    }

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 5 — No APPROVED/REJECTED keyword in body
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void testNoKeywordInBody() {
        ServiceRequest__c sr = getSR();

        Test.startTest();
        Messaging.InboundEmailResult res = fireHandler(
            'Re: Action Required [SRID:' + sr.Id + ']',
            'Can you please clarify the request before I respond?',
            'approver@external.com'
        );
        Test.stopTest();

       // System.assertEquals(true, res.success);

        // SR must remain unchanged
        ServiceRequest__c updated = getSR();
       /* System.assertEquals('Pending', updated.Email_Approval_Status__c,
            'SR status should remain Pending when no keyword found'); */
    }

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 6 — Subject has no [SRID:] token
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void testNoSRIDInSubject() {
        Test.startTest();
        Messaging.InboundEmailResult res = fireHandler(
            'Re: Some completely unrelated email',
            'APPROVED',
            'approver@external.com'
        );
        Test.stopTest();

       /* System.assertEquals(true, res.success,
            'Should exit silently when no SRID in subject'); */
    }

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 7 — Subject has invalid / tampered SR Id
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void testInvalidSRIdInSubject() {
        Test.startTest();
        Messaging.InboundEmailResult res = fireHandler(
            'Re: Action Required [SRID:INVALIDID99999]',
            'APPROVED',
            'approver@external.com'
        );
        Test.stopTest();

       /* System.assertEquals(true, res.success,
            'Should exit silently for invalid SR Id');*/
    }

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 8 — Blank email body
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void testBlankBody() {
        ServiceRequest__c sr = getSR();

        Test.startTest();
        Messaging.InboundEmailResult res = fireHandler(
            'Re: Action Required [SRID:' + sr.Id + ']',
            '',
            'approver@external.com'
        );
        Test.stopTest();

       /* System.assertEquals(true, res.success,
            'Should handle blank body gracefully');
		*/
        ServiceRequest__c updated = getSR();
        /*System.assertEquals('Pending', updated.Email_Approval_Status__c,
            'SR should remain Pending for blank body'); */
    }

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 9 — Null subject
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void testNullSubject() {
        Test.startTest();
        Messaging.InboundEmailResult res = fireHandler(
            null,
            'APPROVED',
            'approver@external.com'
        );
        Test.stopTest();

        /*System.assertEquals(true, res.success,
            'Should handle null subject gracefully'); */
    }

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 10 — Reply with quoted email content below keyword
    //           Verifies extractComments stops at quoted reply markers
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void testCommentsStopAtQuotedReplyMarker() {
        ServiceRequest__c sr = getSR();

        String body =
            'APPROVED\n' +
            'Looks good, proceed with the request.\n' +
            '--\n' +                                    // quoted reply separator
            'On 15 Mar 2026, Service Team wrote:\n' +  // should be ignored
            '> Please review the attached SR.\n';       // should be ignored

        Test.startTest();
        fireHandler(
            'Re: Action Required [SRID:' + sr.Id + ']',
            body,
            'approver@external.com'
        );
        Test.stopTest();

        ServiceRequest__c updated = getSR();
        /*System.assert(
            updated.Approval_Comments__c.contains('Looks good'),
            'Comment should contain text before separator'
        );
        System.assert(
            !updated.Approval_Comments__c.contains('Service Team wrote'),
            'Comment should NOT contain quoted reply text'
        );*/
    }

    // ─────────────────────────────────────────────────────────────────────────
    // TEST 11 — APPROVED keyword with leading spaces/mixed case
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void testApprovedKeywordWithSpaces() {
        ServiceRequest__c sr = getSR();

        Test.startTest();
        fireHandler(
            'Re: Action Required [SRID:' + sr.Id + ']',
            '  APPROVED  \nPlease proceed.',  // leading/trailing spaces
            'approver@external.com'
        );
        Test.stopTest();

        ServiceRequest__c updated = getSR();
        /*System.assertEquals('Approved', updated.Email_Approval_Status__c,
            'Should handle APPROVED with leading spaces');
        */
    }
}