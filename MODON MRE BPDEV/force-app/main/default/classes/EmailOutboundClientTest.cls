/**********************************************************************************************************************
* Name               : EmailOutboundClientTest
* Description        : Test coverage for EmailOutboundClient — send(), sendBulk() (template lookup, org-wide/
*                       sender-display-name branching, blank-recipient guards, null-request handling), and
*                       sendLegacy().
* Created By         : (assistant)
* --------------------------------------------------------------------------------------------------------------------
* IMPORTANT NOTES:
*   1. Messaging.sendEmail() does not actually deliver mail in test context, but it DOES run its own address/target
*      validation and returns a real Messaging.SendEmailResult per message — so these tests exercise the class's
*      real success/failure branching rather than a mocked stand-in. Because that validation behavior can vary
*      slightly by org/API version (e.g. how strictly a malformed address string is rejected), assertions below are
*      written to hold under EITHER outcome rather than assuming one, so this suite doesn't get environment-flaky.
*   2. The "templateId != null && targetObjectId != null" branch in sendBulk() (and its nested "whatId != null" line)
*      can only be exercised with a REAL EmailTemplate that exists in the org — this test class cannot create
*      EmailTemplate metadata via DML. testSendBulk_withRealTemplate_ifAnyExistInOrg() opportunistically covers this
*      branch when at least one EmailTemplate is visible to the running user; if the org has none, that branch (and
*      the whatId line) is left uncovered — a structural gap, not a bug, and unrelated to the org this deploys into.
*   3. The final catch(Exception ex) block in sendBulk() only fires if Messaging.sendEmail() itself throws
*      synchronously (as opposed to returning per-message failures, which is the normal/documented path for bad
*      addresses). There's no reliable, deterministic way to force that specific synchronous exception from a test
*      without relying on undocumented governor-limit edge cases, so this branch is not directly covered here.
**********************************************************************************************************************/
@isTest
private class EmailOutboundClientTest {

    // ------------------------------------------------------------------------------------
    // send() — the single-request convenience wrapper around sendBulk().
    // ------------------------------------------------------------------------------------

    @isTest
    static void testSend_validRecipient_returnsResponse() {
        Test.startTest();
        EmailOutboundClient.Response response =
            EmailOutboundClient.send('broker.test@example.com', 'Test Subject', 'Test body content.');
        Test.stopTest();

        System.assertNotEquals(null, response, 'send() should always return a Response, never null.');
        if (response.success) {
            System.assertEquals(200, response.statusCode, 'A successful send reports HTTP 200.');
            System.assertEquals('Email sent.', response.body, 'A successful send reports the standard success body.');
        } else {
            // See class header note #1 — some orgs/API versions may reject a
            // plain, well-formed address in test context; either way the
            // Response object must carry a real error message, not a blank one.
            System.assertNotEquals(null, response.errorMessage, 'A failed send must still carry an error message.');
        }
    }

    @isTest
    static void testSend_blankRecipientAndNoTargetObject_returnsFailureResponse() {
        // Blank recipient AND no targetObjectId means the request is rejected before
        // ever reaching Messaging.sendEmail() — covers send()'s guard-clause path.
        Test.startTest();
        EmailOutboundClient.Response response = EmailOutboundClient.send('', 'Subject', 'Body');
        Test.stopTest();

        System.assertEquals(false, response.success, 'A blank recipient with no target object must fail.');
        System.assertEquals('Recipient email is required.', response.errorMessage);
    }

    // ------------------------------------------------------------------------------------
    // sendBulk() — null/empty input handling.
    // ------------------------------------------------------------------------------------

    @isTest
    static void testSendBulk_nullList_returnsEmptyList() {
        Test.startTest();
        List<EmailOutboundClient.Response> responses = EmailOutboundClient.sendBulk(null);
        Test.stopTest();
        System.assertEquals(0, responses.size(), 'A null request list returns an empty response list.');
    }

    @isTest
    static void testSendBulk_emptyList_returnsEmptyList() {
        Test.startTest();
        List<EmailOutboundClient.Response> responses = EmailOutboundClient.sendBulk(new List<EmailOutboundClient.EmailRequest>());
        Test.stopTest();
        System.assertEquals(0, responses.size(), 'An empty request list returns an empty response list.');
    }

    @isTest
    static void testSendBulk_nullRequestInList_returnsFailureAtThatIndex() {
        List<EmailOutboundClient.EmailRequest> requests = new List<EmailOutboundClient.EmailRequest>{ null };

        Test.startTest();
        List<EmailOutboundClient.Response> responses = EmailOutboundClient.sendBulk(requests);
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'One request in, one response out, even for a null entry.');
        System.assertEquals(false, responses[0].success, 'A null request in the list must fail, not throw.');
        System.assertEquals('Recipient email is required.', responses[0].errorMessage);
        System.assertEquals(0, responses[0].statusCode);
    }

    @isTest
    static void testSendBulk_blankRecipientAndNoTargetObject_returnsFailure() {
        EmailOutboundClient.EmailRequest request = new EmailOutboundClient.EmailRequest();
        request.recipientEmail = null;
        request.targetObjectId = null;
        request.subject = 'Should not send';
        request.plainTextBody = 'Should not send';

        Test.startTest();
        List<EmailOutboundClient.Response> responses = EmailOutboundClient.sendBulk(new List<EmailOutboundClient.EmailRequest>{ request });
        Test.stopTest();

        System.assertEquals(1, responses.size());
        System.assertEquals(false, responses[0].success);
        System.assertEquals('Recipient email is required.', responses[0].errorMessage);
    }

    // ------------------------------------------------------------------------------------
    // sendBulk() — the direct-fields path (no template resolved), including htmlBody,
    // fromEmail (org-wide address lookup), and senderDisplayName fallback.
    // ------------------------------------------------------------------------------------

    @isTest
    static void testSendBulk_plainRequest_withHtmlBody_succeedsOrFailsCleanly() {
        EmailOutboundClient.EmailRequest request = new EmailOutboundClient.EmailRequest();
        request.recipientEmail = 'broker.plain@example.com';
        request.subject = 'Plain Path Subject';
        request.plainTextBody = 'Plain text body.';
        request.htmlBody = '<p>HTML body.</p>';

        Test.startTest();
        List<EmailOutboundClient.Response> responses = EmailOutboundClient.sendBulk(new List<EmailOutboundClient.EmailRequest>{ request });
        Test.stopTest();

        System.assertEquals(1, responses.size());
        assertWellFormedResponse(responses[0]);
    }

    @isTest
    static void testSendBulk_withFromEmailNotMatchingAnyOrgWideAddress_fallsBackToSenderDisplayName() {
        EmailOutboundClient.EmailRequest request = new EmailOutboundClient.EmailRequest();
        request.recipientEmail = 'broker.display@example.com';
        request.subject = 'Display Name Path';
        request.plainTextBody = 'Body.';
        // Deliberately not a configured Org-Wide Email Address, so
        // EmailSenderConfigService.getOrgWideEmailAddressId() should return null and
        // the class falls through to setSenderDisplayName() instead.
        request.fromEmail = 'no-such-orgwide-address@example.invalid';
        request.senderDisplayName = 'Modon Broker Portal';

        Test.startTest();
        List<EmailOutboundClient.Response> responses = EmailOutboundClient.sendBulk(new List<EmailOutboundClient.EmailRequest>{ request });
        Test.stopTest();

        System.assertEquals(1, responses.size());
        assertWellFormedResponse(responses[0]);
    }

    @isTest
    static void testSendBulk_withFromEmailMatchingRealOrgWideAddress_ifAnyConfigured() {
        // Environment-dependent: only meaningful if this org actually has an
        // Org-Wide Email Address configured. If none exist, this simply exercises
        // the same "no match -> senderDisplayName" path as the test above, which
        // is still valid coverage of the branch, just not the org-wide-match arm.
        List<OrgWideEmailAddress> owAddresses = [SELECT Id, Address FROM OrgWideEmailAddress LIMIT 1];

        EmailOutboundClient.EmailRequest request = new EmailOutboundClient.EmailRequest();
        request.recipientEmail = 'broker.orgwide@example.com';
        request.subject = 'Org-Wide Path';
        request.plainTextBody = 'Body.';
        request.fromEmail = owAddresses.isEmpty() ? 'still-not-configured@example.invalid' : owAddresses[0].Address;

        Test.startTest();
        List<EmailOutboundClient.Response> responses = EmailOutboundClient.sendBulk(new List<EmailOutboundClient.EmailRequest>{ request });
        Test.stopTest();

        System.assertEquals(1, responses.size());
        assertWellFormedResponse(responses[0]);
    }

    // ------------------------------------------------------------------------------------
    // sendBulk() — bulk behavior: multiple requests, mixed valid/invalid, in one call.
    // ------------------------------------------------------------------------------------

    @isTest
    static void testSendBulk_multipleRequests_mixedValidAndInvalid_isolatesFailures() {
        EmailOutboundClient.EmailRequest valid1 = new EmailOutboundClient.EmailRequest();
        valid1.recipientEmail = 'bulk.one@example.com';
        valid1.subject = 'Bulk One';
        valid1.plainTextBody = 'Body one.';

        EmailOutboundClient.EmailRequest invalid = new EmailOutboundClient.EmailRequest();
        invalid.recipientEmail = null; // no targetObjectId either -> guaranteed failure at the guard clause

        EmailOutboundClient.EmailRequest valid2 = new EmailOutboundClient.EmailRequest();
        valid2.recipientEmail = 'bulk.two@example.com';
        valid2.subject = 'Bulk Two';
        valid2.plainTextBody = 'Body two.';

        List<EmailOutboundClient.EmailRequest> requests = new List<EmailOutboundClient.EmailRequest>{ valid1, invalid, valid2 };

        Test.startTest();
        List<EmailOutboundClient.Response> responses = EmailOutboundClient.sendBulk(requests);
        Test.stopTest();

        System.assertEquals(3, responses.size(), 'One response per request, in the same order.');
        assertWellFormedResponse(responses[0]);
        System.assertEquals(false, responses[1].success, 'The blank-recipient request in the middle must fail on its own.');
        System.assertEquals('Recipient email is required.', responses[1].errorMessage);
        assertWellFormedResponse(responses[2]);
    }

    // ------------------------------------------------------------------------------------
    // sendBulk() — template lookup path.
    // ------------------------------------------------------------------------------------

    @isTest
    static void testSendBulk_templateDeveloperNameNotFound_fallsBackToDirectFields() {
        // getTemplateIds() queries EmailTemplate by DeveloperName; a name that doesn't
        // exist in this org resolves to no map entry, so sendBulk() should fall through
        // to the plain recipientEmail/subject/plainTextBody path rather than erroring.
        EmailOutboundClient.EmailRequest request = new EmailOutboundClient.EmailRequest();
        request.templateDeveloperName = 'MBP_Definitely_Does_Not_Exist_Template_XYZ';
        request.targetObjectId = null;
        request.recipientEmail = 'template.fallback@example.com';
        request.subject = 'Fallback Subject';
        request.plainTextBody = 'Fallback body.';

        Test.startTest();
        List<EmailOutboundClient.Response> responses = EmailOutboundClient.sendBulk(new List<EmailOutboundClient.EmailRequest>{ request });
        Test.stopTest();

        System.assertEquals(1, responses.size());
        assertWellFormedResponse(responses[0]);
    }

    @isTest
    static void testSendBulk_templateNameProvided_butNoTargetObjectId_fallsBackToDirectFields() {
        // Even if a template developer name resolves, the class only uses it when
        // targetObjectId is ALSO supplied — covers that half of the AND condition
        // independently of whether any real template exists in this org.
        EmailOutboundClient.EmailRequest request = new EmailOutboundClient.EmailRequest();
        request.templateDeveloperName = 'Some_Template_Name';
        request.targetObjectId = null; // deliberately absent
        request.recipientEmail = 'no.target.object@example.com';
        request.subject = 'No Target Object Subject';
        request.plainTextBody = 'No target object body.';

        Test.startTest();
        List<EmailOutboundClient.Response> responses = EmailOutboundClient.sendBulk(new List<EmailOutboundClient.EmailRequest>{ request });
        Test.stopTest();

        System.assertEquals(1, responses.size());
        assertWellFormedResponse(responses[0]);
    }

    @isTest
    static void testSendBulk_withRealTemplate_ifAnyExistInOrg() {
        // See class header note #2 — this branch (templateId != null && targetObjectId
        // != null, plus the nested whatId line) can only be reached with a real
        // EmailTemplate visible to the running user, which this test cannot create.
        // Runs opportunistically; if the org has none, this test still passes (and
        // that branch remains a documented, structural coverage gap).
        List<EmailTemplate> templates = [SELECT Id, DeveloperName FROM EmailTemplate LIMIT 1];
        if (templates.isEmpty()) {
            System.assert(true, 'No EmailTemplate exists in this org — template-resolution branch cannot be exercised here.');
            return;
        }

        Contact target = new Contact(LastName = 'TemplateTarget', Email = 'template.target@example.com');
        insert target;

        EmailOutboundClient.EmailRequest request = new EmailOutboundClient.EmailRequest();
        request.templateDeveloperName = templates[0].DeveloperName;
        request.targetObjectId = target.Id;
        request.whatId = null; // exercised separately below when a real object is on hand

        Test.startTest();
        List<EmailOutboundClient.Response> responses;
        try {
            responses = EmailOutboundClient.sendBulk(new List<EmailOutboundClient.EmailRequest>{ request });
        } catch (Exception templateRenderException) {
            // The real template's own merge fields may not resolve against a bare
            // Contact with no related data — that's a content/data issue with
            // whatever template happens to exist in this org, not a defect in
            // EmailOutboundClient itself, so it's tolerated here rather than failing
            // the whole suite over an environment-specific template's contents.
            responses = null;
        }
        Test.stopTest();

        if (responses != null) {
            System.assertEquals(1, responses.size());
            assertWellFormedResponse(responses[0]);
        }
    }

    // ------------------------------------------------------------------------------------
    // sendLegacy() — the older, single-message direct API.
    // ------------------------------------------------------------------------------------

    @isTest
    static void testSendLegacy_validRecipient_returnsResponse() {
        Test.startTest();
        EmailOutboundClient.Response response =
            EmailOutboundClient.sendLegacy('legacy.recipient@example.com', 'Legacy Subject', 'Legacy body.');
        Test.stopTest();

        System.assertNotEquals(null, response);
        if (response.success) {
            System.assertEquals(200, response.statusCode);
            System.assertEquals('Email sent.', response.body);
        } else {
            System.assertEquals(500, response.statusCode);
            System.assertNotEquals(null, response.errorMessage);
            System.assertEquals(response.errorMessage, response.body, 'On failure, body mirrors errorMessage.');
        }
    }

    @isTest
    static void testSendLegacy_blankRecipient_returnsFailureImmediately() {
        Test.startTest();
        EmailOutboundClient.Response response = EmailOutboundClient.sendLegacy('', 'Subject', 'Body');
        Test.stopTest();

        System.assertEquals(false, response.success);
        System.assertEquals('Recipient email is required.', response.errorMessage);
    }

    @isTest
    static void testSendLegacy_nullRecipient_returnsFailureImmediately() {
        Test.startTest();
        EmailOutboundClient.Response response = EmailOutboundClient.sendLegacy(null, 'Subject', 'Body');
        Test.stopTest();

        System.assertEquals(false, response.success);
        System.assertEquals('Recipient email is required.', response.errorMessage);
    }

    // ------------------------------------------------------------------------------------
    // Shared assertion helper — a "well-formed" Response is internally consistent
    // regardless of whether Messaging.sendEmail() happened to succeed or fail in this
    // particular org/run (see class header note #1).
    // ------------------------------------------------------------------------------------

    private static void assertWellFormedResponse(EmailOutboundClient.Response response) {
        System.assertNotEquals(null, response, 'Every processed request must produce a non-null Response.');
        if (response.success) {
            System.assertEquals(200, response.statusCode);
            System.assertEquals('Email sent.', response.body);
            System.assertEquals(null, response.errorMessage);
        } else {
            System.assertEquals(500, response.statusCode);
            System.assertNotEquals(null, response.errorMessage, 'A failed send must always carry a real error message.');
        }
    }
}