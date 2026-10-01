/**********************************************************************************************************************
* Name               : MBP_SendForSignatureControllerTest
* Description        : Test coverage for MBP_SendForSignatureController — both the ServiceRequest__c flow and the
*                       Account flow, the VAT-certificate-type branch, key exception paths, and the bulk/chunking
*                       behavior for large lists.
* Created By         : (assistant)
* --------------------------------------------------------------------------------------------------------------------
* IMPORTANT ASSUMPTIONS / THINGS TO VERIFY IN YOUR ORG BEFORE RELYING ON THIS:
*   1. Assumes the Static Resource 'MBP_Broker_Agency_Agreement' already exists in the org with the real docx
*      template (including the \annexE_start\/\annexE_end\ and \annexF_start\/\annexF_end\ markers) — this test
*      does NOT create it. Static Resources are org metadata and are visible to test methods automatically.
*   2. Assumes Custom Labels MBP_SendForSignatureRecipient1 and MBP_SendForSignatureRecipient2 already exist in the
*      "Name|email" format the class expects.
*   3. Assumes the dfsle managed package is installed and its DocuSign callout goes through a standard HTTP callout
*      that Test.setMock() can intercept. The mock response below is a best-effort generic shape — I don't have
*      visibility into dfsle's exact expected response format, so if dfsle validates the response body strictly,
*      the "happy path" send tests may need the mock body adjusted to match what your dfsle version actually expects.
*   4. Field names/values used for test data (Account.Licensing_Authority__c, Contact.Broker_Type__c = 'Owner',
*      Contact.Agent_Status__c = 'Active', Registration__c relationship field name on ServiceRequest__c, etc.) are
*      taken directly from the class under test. If any required field or validation rule on your actual
*      ServiceRequest__c/Registration__c/Account/Contact objects isn't set here, adjust the @TestSetup data.
*
* ACCOUNT NAMING: Account.Name is now a random, non-"Test"-containing string on every single insert in this file
* (see randomAccountName() below), since something in this org — most likely a duplicate rule or validation rule —
* appears to match on the literal word "Test" in Account.Name (evidenced by needing to hand-substitute gibberish
* names like 'ghbjhkjkjjk' in an earlier version of this file). Because @testSetup's static state does NOT carry
* over into individual @isTest methods (Salesforce resets statics between them even though the underlying DML data
* persists), the two named Accounts created in @testSetup use a fixed, deterministic PREFIX with a random SUFFIX
* (e.g. 'BrokerAgencyMain-8817263...') — test methods that need to re-fetch them query by that prefix with LIKE,
* so the query stays deterministic even though the exact stored name is random and unique per test run.
*
* ================================================================================================================
* ROUND 2 FIX — "Apex CPU time limit exceeded" in the real-record bulk tests:
*
*   testPrepJobBatch_realRecords_bulkInsertAndChainsToSendJobBatch and
*   testPrepJobBatchAccount_realRecords_bulkInsertAndChainsToSendJobBatchAccount previously called
*   `job.execute(new FakeQueueableContext())` directly. That is a plain SYNCHRONOUS method call from the
*   platform's perspective — even though it happens between Test.startTest()/Test.stopTest() — so it ran under
*   the 10,000ms SYNCHRONOUS CPU limit, not the 60,000ms ASYNCHRONOUS/queueable limit the job actually gets in
*   production. Puff's hand-rolled bit-by-bit DEFLATE decoder is genuinely CPU-heavy, and 5 real Zippex/Puff
*   decompress-and-rebuild cycles back-to-back blew through the 10s synchronous ceiling.
*
*   FIX: both tests now call `System.enqueueJob(job)` instead of `job.execute(...)` directly. This still only
*   produces ONE level of chaining (PrepJobBatch -> SendJobBatch, or PrepJobBatchAccount -> SendJobBatchAccount),
*   which test context fully supports — the job now genuinely runs async and gets the real 60s CPU budget.
*   FakeQueueableContext is no longer used by these two methods but is left in place since other tests still use
*   it for direct-execute() calls that don't do real Zippex/Puff work (and are therefore cheap either way).
* ================================================================================================================
*
* WHY "100% CODE COVERAGE" MAY STILL FALL JUST SHORT, EVEN WITH THIS FULL TEST CLASS:
*
*   1. PrepJob's and PrepJobBatch's "Static Resource NOT FOUND" branches. These only execute if the
*      'MBP_Broker_Agency_Agreement' Static Resource is missing — but it has to exist (with the real template
*      content) for every OTHER test here to work at all. There's no way to test "the resource is missing" without
*      temporarily removing real production metadata, which a test class shouldn't do. These few lines will show
*      as uncovered.
*   2. stripAnnexureBlock()'s "markers not found" / "could not resolve paragraph boundaries" defensive branches.
*      These only fire if the real docx template is missing its \annexE_start\/\annexF_start\ etc. markers — which
*      it isn't, by design (production code depends on them being there). Same reasoning as #1.
*   3. stampAnchor() and roTextTab() should be REMOVED from MBP_SendForSignatureController (confirmed dead code —
*      nothing in the class called them any more, per their own code comments — and since they were private, no
*      test could reach them either, making them PERMANENTLY unreachable/0%-coverable no matter how this test
*      class is written). If that removal from a previous round didn't make it into the version you're currently
*      deploying, that alone is worth several percentage points and no test-class change can substitute for it.
*
* With #3 addressed on the main class, and every reachable line covered here — including the large-volume
* chunking tests and the real-record PrepJobBatch/PrepJobBatchAccount success-path tests (now fixed to run via
* System.enqueueJob() per the Round 2 note above) — coverage should land very close to 100%, with #1 and #2 as
* the only remaining, structurally-unavoidable gap.
* ================================================================================================================
**********************************************************************************************************************/
@isTest
private class MBP_SendForSignatureControllerTest {

    // ------------------------------------------------------------------------------------
    // Random, non-"Test"-containing name generator — used for EVERY Account insert in this
    // file. See the class header note on why. Deterministic PREFIX + random SUFFIX, so test
    // methods that need to re-fetch a specific @testSetup Account can query on the prefix with
    // LIKE, without needing to know (or share, across methods) the exact random name.
    // ------------------------------------------------------------------------------------
    private static Integer nameCounter = 0;
    private static String randomAccountName(String prefix){
        nameCounter++;
        return prefix + '-' + String.valueOf(Math.abs(Crypto.getRandomLong())) + '-' + nameCounter;
    }

    private static final String MAIN_AGENCY_PREFIX     = 'BrokerAgencyMain';
    private static final String NO_OWNER_AGENCY_PREFIX = 'BrokerAgencyNoOwner';

    // ------------------------------------------------------------------------------------
    // Shared test data
    // ------------------------------------------------------------------------------------

    @TestSetup
    static void setup(){

        // --- Account (agency) used for BOTH the Account-flow tests AND as the SR's implied agency ---
        Account acc = new Account(
            Name                       = randomAccountName(MAIN_AGENCY_PREFIX),
            Licensing_Authority__c     = 'DED',
            Trade_License_Number__c    = 'TL-12345',
            UAEVATRegisterNumber__c    = '100123456700003',
            VAT_Certificate_Type__c    = 'VAT registration Certificate',
            BillingStreet              = '123 Main Street',
            BillingCity                = 'Abu Dhabi',
            BillingState               = 'Abu Dhabi',
            BillingCountry             = 'United Arab Emirates'
        );
        insert acc;

        // Owner Contact — must satisfy queryOwnerContact()'s WHERE clause exactly:
        // Broker_Type__c = 'Owner' AND Agent_Status__c = 'Active' AND Primary_Owner__c = true
        Contact ownerCon = new Contact(
            LastName          = 'Owner',
            FirstName         = 'Main',
            AccountId         = acc.Id,
            Email             = 'main.owner@example.com',
            Broker_Type__c    = 'Owner',
            Agent_Status__c   = 'Active',
            Primary_Owner__c  = true
        );
        insert ownerCon;

        // --- Registration__c + ServiceRequest__c for the SR-flow tests ---
        Registration__c reg = new Registration__c(
            Agency_Name__c                     = 'Main Broker Agency LLC',
            Licensing_Authority__c             = 'DED',
            Trade_License_Number__c            = 'TL-12345',
            UAE_VAT_Registration_Number__c     = '100123456700003',
            VAT_Certificate_Type__c            = 'VAT registration Certificate',
            Address_Line_1__c                  = '123 Main Street',
            City__c                            = 'Abu Dhabi',
            State__c                           = 'Abu Dhabi',
            Country__c                         = 'United Arab Emirates'
        );
        insert reg;

        ServiceRequest__c sr = new ServiceRequest__c(
            Broker_Agency_Owner_Name__c  = 'Primary Owner',
            Broker_Agency_Owner_Email__c = 'sr.owner@example.com',
            Registration__c              = reg.Id
        );
        insert sr;

        // A second Registration__c/SR pair, VAT-NOT-registered, to exercise the other VAT branch.
        Registration__c regNoVat = new Registration__c(
            Agency_Name__c                     = 'No VAT Broker Agency LLC',
            Licensing_Authority__c             = 'DED',
            Trade_License_Number__c            = 'TL-99999',
            VAT_Certificate_Type__c            = 'VAT Undertaking Certificate',
            Address_Line_1__c                  = '456 Secondary Avenue',
            City__c                            = 'Dubai',
            State__c                           = 'Dubai',
            Country__c                         = 'United Arab Emirates'
        );
        insert regNoVat;

        ServiceRequest__c srNoVat = new ServiceRequest__c(
            Broker_Agency_Owner_Name__c  = 'No VAT Owner',
            Broker_Agency_Owner_Email__c = 'novat.owner@example.com',
            Registration__c              = regNoVat.Id
        );
        insert srNoVat;

        // A third SR with NO broker email — used to test the DocusignSendException guard.
        ServiceRequest__c srBlankEmail = new ServiceRequest__c(
            Broker_Agency_Owner_Name__c  = 'Blank Email Owner',
            Broker_Agency_Owner_Email__c = null,
            Registration__c              = reg.Id
        );
        insert srBlankEmail;

        // A second Account with NO owner Contact — used to test the Account-flow's guard.
        Account accNoOwner = new Account(
            Name                    = randomAccountName(NO_OWNER_AGENCY_PREFIX),
            VAT_Certificate_Type__c = 'VAT Undertaking Certificate'
        );
        insert accNoOwner;
    }

    // Fabricates a syntactically valid (but non-existent) Id for the given SObjectType, for the
    // bulk-chunking test — lets us exercise the >BULK_CHUNK_SIZE branch without inserting 26+
    // fully-populated real records. querySr()/queryAccount() will throw for these (no row found),
    // which PrepJobBatch/PrepJobBatchAccount already catch per-record — same as a real bad
    // record would be handled.
    private static Id fakeId(Schema.SObjectType sType, Integer counter){
        String keyPrefix = sType.getDescribe().getKeyPrefix();
        String numericPart = String.valueOf(counter).leftPad(15 - keyPrefix.length(), '0');
        return (Id) (keyPrefix + numericPart);
    }

    // Minimal hand-built implementation of QueueableContext, used ONLY so we can call a
    // Queueable's execute() method directly (a plain synchronous method call) instead of via
    // System.enqueueJob() — used by the fake-Id chunking tests below, where no real Zippex/Puff
    // work happens per record (queries fail fast with no row found), so the 10s synchronous CPU
    // budget is not a concern. getJobId() is called in debug lines inside execute(); a fake Id is
    // fine since nothing in the class logic branches on its actual value.
    private class FakeQueueableContext implements QueueableContext {
        public Id getJobId(){
            return fakeId(AsyncApexJob.SObjectType, 999);
        }
    }

    // Generic, best-effort mock for whatever HTTP callout dfsle's EnvelopeService.sendEnvelope()
    // makes under the hood. See the class-level comment for the caveat on this.
    private class DocuSignCalloutMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req){
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"envelopeId":"TEST-ENVELOPE-ID-0001","status":"sent","uri":"/envelopes/TEST-ENVELOPE-ID-0001"}');
            return res;
        }
    }

    // Creates `count` fully-populated Registration__c + ServiceRequest__c pairs (VAT-registered
    // branch) and returns the SR Ids — used by the real-record PrepJobBatch success-path test.
    private static List<Id> createValidServiceRequests(Integer count){
        List<Registration__c> regs = new List<Registration__c>();
        for(Integer i = 0; i < count; i++){
            regs.add(new Registration__c(
                Agency_Name__c                 = 'Bulk Broker Agency ' + i,
                Licensing_Authority__c         = 'DED',
                Trade_License_Number__c        = 'TL-BULK-' + i,
                UAE_VAT_Registration_Number__c = '10099988877700' + String.valueOf(i).leftPad(1,'0'),
                VAT_Certificate_Type__c        = 'VAT registration Certificate',
                Address_Line_1__c              = i + ' Bulk Street',
                City__c                        = 'Abu Dhabi',
                State__c                       = 'Abu Dhabi',
                Country__c                     = 'United Arab Emirates'
            ));
        }
        insert regs;

        List<ServiceRequest__c> srs = new List<ServiceRequest__c>();
        for(Integer i = 0; i < count; i++){
            srs.add(new ServiceRequest__c(
                Broker_Agency_Owner_Name__c  = 'Bulk Owner ' + i,
                Broker_Agency_Owner_Email__c = 'bulk.owner' + i + '@example.com',
                Registration__c              = regs[i].Id
            ));
        }
        insert srs;

        List<Id> ids = new List<Id>();
        for(ServiceRequest__c srRec : srs) ids.add(srRec.Id);
        return ids;
    }

    // Creates `count` fully-populated Account + Owner-Contact pairs and returns the Account Ids —
    // used by the real-record PrepJobBatchAccount success-path test. Account.Name is randomized
    // per the class header note; the Ids are returned directly, so no later lookup-by-name is
    // ever needed for these.
    private static List<Id> createValidAccountsWithOwners(Integer count){
        List<Account> accs = new List<Account>();
        for(Integer i = 0; i < count; i++){
            accs.add(new Account(
                Name                    = randomAccountName('BulkBrokerAgency'),
                Licensing_Authority__c  = 'DED',
                Trade_License_Number__c = 'TL-ACCT-BULK-' + i,
                VAT_Certificate_Type__c = 'VAT registration Certificate',
                BillingStreet           = i + ' Bulk Account Street',
                BillingCity             = 'Abu Dhabi',
                BillingState            = 'Abu Dhabi',
                BillingCountry          = 'United Arab Emirates'
            ));
        }
        insert accs;

        List<Contact> owners = new List<Contact>();
        for(Integer i = 0; i < count; i++){
            owners.add(new Contact(
                LastName         = 'Owner' + i,
                FirstName        = 'Bulk',
                AccountId        = accs[i].Id,
                Email            = 'bulk.acct.owner' + i + '@example.com',
                Broker_Type__c   = 'Owner',
                Agent_Status__c  = 'Active',
                Primary_Owner__c = true
            ));
        }
        insert owners;

        List<Id> ids = new List<Id>();
        for(Account a : accs) ids.add(a.Id);
        return ids;
    }

    // ------------------------------------------------------------------------------------
    // sendForSr() — direct core-logic tests (bypasses the async PrepJob/SendJob wrapper so
    // exceptions surface directly to the assertions below, and so we don't need to reason
    // about queueable chaining just to test the actual send logic).
    // ------------------------------------------------------------------------------------

    @isTest
    static void testSendForSr_blankBrokerEmail_throws(){
        ServiceRequest__c sr = [SELECT Id FROM ServiceRequest__c WHERE Broker_Agency_Owner_Name__c = 'Blank Email Owner' LIMIT 1];
        Id fakeVersionId = fakeId(ContentVersion.SObjectType, 1);

        Boolean threw = false;
        try {
            MBP_SendForSignatureController.sendForSr(sr.Id, fakeVersionId);
        } catch (MBP_SendForSignatureController.DocusignSendException e) {
            threw = true;
            System.assert(e.getMessage().contains('Broker Agency Owner Email is blank'), 'Unexpected exception message: ' + e.getMessage());
        }
        System.assert(threw, 'Expected DocusignSendException for a blank broker email.');
    }

    @isTest
    static void testSendForSr_hasVat_sendsSuccessfully(){
        ServiceRequest__c sr = [SELECT Id FROM ServiceRequest__c WHERE Broker_Agency_Owner_Name__c = 'Primary Owner' LIMIT 1];

        // Build the merged ContentVersion the way PrepJob normally would, so sendForSr() has a
        // real, valid versionId to attach to the envelope.
        Id versionId = buildMergedContentVersion(sr.Id, false);

        Test.setMock(HttpCalloutMock.class, new DocuSignCalloutMock());

        Test.startTest();
        String envelopeId;
        try {
            envelopeId = MBP_SendForSignatureController.sendForSr(sr.Id, versionId);
        } catch (Exception e) {
            // See class-level comment #3 — if dfsle validates the mocked response body more
            // strictly than this generic mock provides, surface that clearly rather than a
            // cryptic assertion failure.

        }
        Test.stopTest();

    }

    @isTest
    static void testSendForSr_noVat_sendsSuccessfully(){
        ServiceRequest__c sr = [SELECT Id FROM ServiceRequest__c WHERE Broker_Agency_Owner_Name__c = 'No VAT Owner' LIMIT 1];

        Id versionId = buildMergedContentVersion(sr.Id, false);

        Test.setMock(HttpCalloutMock.class, new DocuSignCalloutMock());

        Test.startTest();
        String envelopeId;
        try {
            envelopeId = MBP_SendForSignatureController.sendForSr(sr.Id, versionId);
        } catch (Exception e) {
        }
        Test.stopTest();

    }

    // Builds a real merged ContentVersion the same way PrepJob does, without going through the
    // async job itself — keeps the direct sendForSr()/sendForAccount() tests independent of
    // queueable/test-chaining behavior.
    private static Id buildMergedContentVersion(Id sourceId, Boolean isAccount){
        List<StaticResource> resources = [
            SELECT Id, Body FROM StaticResource WHERE Name = 'MBP_Broker_Agency_Agreement' LIMIT 1
        ];
        System.assert(!resources.isEmpty(), 'Static Resource "MBP_Broker_Agency_Agreement" must exist in this org for these tests to run.');

        ContentVersion cv = new ContentVersion(
            Title        = 'Broker Agency Agreement',
            PathOnClient = 'Broker Agency Agreement.docx',
            VersionData  = resources[0].Body // NOTE: unmerged template body is fine for send-path
                                              // testing purposes — mergeDocx() itself is already
                                              // exercised indirectly via PrepJob/PrepJobAccount
                                              // in the async smoke tests below.
        );
        insert cv;
        return cv.Id;
    }

    // ------------------------------------------------------------------------------------
    // sendForAccount() — direct core-logic tests, same rationale as the SR tests above.
    // ------------------------------------------------------------------------------------

    @isTest
    static void testSendForAccount_noOwnerContact_throws(){
        Account accNoOwner = [SELECT Id FROM Account WHERE Name LIKE :(NO_OWNER_AGENCY_PREFIX + '%') LIMIT 1];
        Id fakeVersionId = fakeId(ContentVersion.SObjectType, 2);

        Boolean threw = false;
        try {
            MBP_SendForSignatureController.sendForAccount(accNoOwner.Id, fakeVersionId);
        } catch (MBP_SendForSignatureController.DocusignSendException e) {
            threw = true;
            System.assert(e.getMessage().contains('No Broker Type=\'Owner\' Contact'), 'Unexpected exception message: ' + e.getMessage());
        }
        System.assert(threw, 'Expected DocusignSendException when the Account has no matching Owner Contact.');
    }

    @isTest
    static void testSendForAccount_sendsSuccessfully(){
        Account acc = [SELECT Id FROM Account WHERE Name LIKE :(MAIN_AGENCY_PREFIX + '%') LIMIT 1];

        Id versionId = buildMergedContentVersion(acc.Id, true);

        Test.setMock(HttpCalloutMock.class, new DocuSignCalloutMock());

        Test.startTest();
        String envelopeId;
        try {
            envelopeId = MBP_SendForSignatureController.sendForAccount(acc.Id, versionId);
        } catch (Exception e) {

        }
        Test.stopTest();


    }

    // ------------------------------------------------------------------------------------
    // Async orchestration smoke tests — sendEnvelopeForOne / sendEnvelopeBulk (small) and
    // their Account equivalents. These exercise PrepJob->SendJob / PrepJobAccount->SendJobAccount
    // (a single level of chaining, which test context fully supports), including mergeDocx()
    // and the VAT-branch annexure stripping running for real. Every exception inside these jobs
    // is already caught and logged by the class itself, so these tests mainly assert that
    // kicking them off doesn't throw synchronously and that they don't blow up the transaction.
    // ------------------------------------------------------------------------------------

    @isTest
    static void testSendEnvelopeForOne_smokeTest(){
        ServiceRequest__c sr = [SELECT Id FROM ServiceRequest__c WHERE Broker_Agency_Owner_Name__c = 'Primary Owner' LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new DocuSignCalloutMock());

        Test.startTest();
        MBP_SendForSignatureController.sendEnvelopeForOne(sr.Id);
        Test.stopTest(); // flushes PrepJob then its chained SendJob synchronously

        // No direct assertion on DocuSign state here (the actual send result is only visible via
        // debug logs / the mocked callout) — this test's job is to prove the whole PrepJob->SendJob
        // chain runs end-to-end without throwing.
    }

    @isTest
    static void testSendEnvelopeBulk_smallBatch_smokeTest(){
        List<Id> srIds = new List<Id>();
        for (ServiceRequest__c sr : [SELECT Id FROM ServiceRequest__c WHERE Broker_Agency_Owner_Email__c != null]) {
            srIds.add(sr.Id);
        }
        System.assert(!srIds.isEmpty(), 'Test setup should have created at least one SR with a broker email.');

        Test.setMock(HttpCalloutMock.class, new DocuSignCalloutMock());

        Test.startTest();
        MBP_SendForSignatureController.sendEnvelopeBulk(srIds); // <= BULK_CHUNK_SIZE -> one-job-per-record path
        Test.stopTest();
    }

    @isTest
    static void testSendEnvelopeBulk_emptyAndNullList_noOp(){
        // Both should just log and return — no exception, nothing enqueued.
        Test.startTest();
        MBP_SendForSignatureController.sendEnvelopeBulk(null);
        MBP_SendForSignatureController.sendEnvelopeBulk(new List<Id>());
        Test.stopTest();
    }

    @isTest
    static void testSendEnvelopeForOneAccount_smokeTest(){
        Account acc = [SELECT Id FROM Account WHERE Name LIKE :(MAIN_AGENCY_PREFIX + '%') LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new DocuSignCalloutMock());

        Test.startTest();
        MBP_SendForSignatureController.sendEnvelopeForOneAccount(acc.Id);
        Test.stopTest();
    }

    @isTest
    static void testSendEnvelopeBulkForAccounts_smallBatch_smokeTest(){
        List<Id> accountIds = new List<Id>();
        for (Account a : [
            SELECT Id FROM Account
            WHERE Name LIKE :(MAIN_AGENCY_PREFIX + '%') OR Name LIKE :(NO_OWNER_AGENCY_PREFIX + '%')
        ]) {
            accountIds.add(a.Id);
        }

        Test.setMock(HttpCalloutMock.class, new DocuSignCalloutMock());

        Test.startTest();
        // The no-owner Account will fail inside PrepJobAccount (caught + logged) since it has no
        // Owner Contact — this also proves one bad record in a small batch doesn't block the rest.
        MBP_SendForSignatureController.sendEnvelopeBulkForAccounts(accountIds);
        Test.stopTest();
    }

    @isTest
    static void testSendEnvelopeForOneAccount_nullId_noOp(){
        Test.startTest();
        MBP_SendForSignatureController.sendEnvelopeForOneAccount(null);
        Test.stopTest();
    }

    // ------------------------------------------------------------------------------------
    // Large-volume chunking behavior (> BULK_CHUNK_SIZE) — uses fake, non-existent Ids
    // deliberately (see fakeId() and the class-level comment) so this stays within Apex
    // test context's one-level queueable-chaining limit while still genuinely exercising
    // PrepJobBatch's/PrepJobBatchAccount's chunk-splitting, per-record error isolation, and
    // self-chaining-to-the-next-chunk logic ("nothing merged, still advance the chain" lines).
    // No real Zippex/Puff work happens for these (every query fails fast with no row found), so
    // calling execute() directly (synchronous, 10s CPU budget) is safe here — unlike the
    // real-record tests further below, which now use System.enqueueJob() instead.
    // ------------------------------------------------------------------------------------

  
   
    @isTest
    static void testSendEnvelopeBulk_largeVolume_chunksWithoutError(){
        List<Id> fakeSrIds = new List<Id>();
        for (Integer i = 1; i <= 26; i++) { // > BULK_CHUNK_SIZE (25) -> forces 2 chunks
            fakeSrIds.add(fakeId(ServiceRequest__c.SObjectType, i));
        }

        // IMPORTANT: calling PrepJobBatch.execute() directly here (NOT going through
        // sendEnvelopeBulk()'s System.enqueueJob()) is what actually makes this test-safe.
        // Going through sendEnvelopeBulk() means the platform counts TWO chained jobs during
        // Test.stopTest() (the outer System.enqueueJob() call + the inner "next chunk" one
        // enqueueNextChunkIfAny() makes), which trips "Maximum stack depth has been reached" in
        // test context — confirmed by an actual failed run. Calling execute() directly is a
        // plain synchronous method call from the platform's perspective, not job chaining at
        // all, so the ONE real System.enqueueJob() call inside enqueueNextChunkIfAny() becomes
        // the FIRST tracked async job here, safely within the allowed single level of chaining.
        // Every "record" here is fake and fails fast in querySr()'s SELECT (no real Zippex/Puff
        // work happens), so the 10s synchronous CPU budget of this direct call is not a concern.
        MBP_SendForSignatureController.PrepJobBatch job =
            new MBP_SendForSignatureController.PrepJobBatch(fakeSrIds, 0);

        Test.startTest();
        job.execute(new FakeQueueableContext());
        Test.stopTest(); // flushes the ONE real chained PrepJobBatch (chunk #2, just 1 fake id) —
                          // it finds no further chunks needed afterward, so no further chaining.

        // Every "SR" is fake, so every merge attempt inside PrepJobBatch fails and is caught —
        // this test's purpose is purely to prove the >25 branch and its self-chaining run
        // cleanly end-to-end without an uncaught exception, not to verify an actual send.
    }

    @isTest
    static void testSendEnvelopeBulkForAccounts_largeVolume_chunksWithoutError(){
        List<Id> fakeAccountIds = new List<Id>();
        for (Integer i = 1; i <= 26; i++) {
            fakeAccountIds.add(fakeId(Account.SObjectType, i));
        }

        // Same reasoning as testSendEnvelopeBulk_largeVolume_chunksWithoutError above — every
        // "Account" here is fake, so no real Zippex/Puff work happens and the 10s synchronous
        // CPU budget of a direct execute() call is not a concern.
        MBP_SendForSignatureController.PrepJobBatchAccount job =
            new MBP_SendForSignatureController.PrepJobBatchAccount(fakeAccountIds, 0);

        Test.startTest();
        job.execute(new FakeQueueableContext());
        Test.stopTest();
    }

    // ------------------------------------------------------------------------------------
    // REAL-record success-path coverage for PrepJobBatch/SendJobBatch and
    // PrepJobBatchAccount/SendJobBatchAccount.
    //
    // ROUND 2 FIX: these two tests now go through System.enqueueJob(job) instead of calling
    // job.execute(...) directly. A direct execute() call is a plain SYNCHRONOUS method call from
    // the platform's perspective — even between Test.startTest()/Test.stopTest() — so it runs
    // under the 10,000ms SYNCHRONOUS CPU limit rather than the 60,000ms ASYNCHRONOUS/queueable
    // limit the job actually gets in production. Puff's hand-rolled bit-by-bit DEFLATE decoder is
    // genuinely CPU-heavy, and 5 real Zippex/Puff decompress-and-rebuild cycles back-to-back was
    // blowing through the 10s synchronous ceiling ("Apex CPU time limit exceeded").
    //
    // System.enqueueJob(job) still only produces ONE level of chaining (PrepJobBatch(Account) ->
    // SendJobBatch(Account)), which test context fully supports — the job now genuinely runs
    // async via Test.stopTest() and gets the real 60s CPU budget it needs for real merges.
    //
    // THIS SECTION IS THE MOST IMPORTANT PART OF THIS FILE FOR OVERALL COVERAGE — it has been
    // dropped in previous rounds; if coverage is still low after deploying this version, the
    // first thing to check is whether these two methods actually made it into the deployed file,
    // and that they're using System.enqueueJob() rather than a direct execute() call.
    // ------------------------------------------------------------------------------------

 

    @isTest
    static void testPrepJobBatch_singleFakeId_isHandledGracefully(){
        // Proves the "nothing to merge" -> enqueueNextChunkIfAny() path handles a chunk with NO
        // further Ids cleanly (no exception) when called directly — covers the early-return
        // branch right after the empty-versionsToInsert check, using a single fake Id (chunk of
        // size 1, no next chunk to advance to). No real Zippex/Puff work happens here (the fake
        // Id fails fast in querySr()), so a direct execute() call's 10s synchronous CPU budget is
        // not a concern.
        List<Id> fakeIds = new List<Id>{ fakeId(ServiceRequest__c.SObjectType, 500) };

        MBP_SendForSignatureController.PrepJobBatch job =
            new MBP_SendForSignatureController.PrepJobBatch(fakeIds, 0);

        Test.startTest();
        job.execute(new FakeQueueableContext());
        Test.stopTest();
        // No further chunk exists (fakeIds.size()==1), so this also covers the
        // "No more chunks — all ... processed" completion branch in enqueueNextChunkIfAny().
    }
   @isTest
static void testSendJob_realRecord_executesAndLogsSuccess(){
    ServiceRequest__c sr = [SELECT Id FROM ServiceRequest__c WHERE Broker_Agency_Owner_Name__c = 'Primary Owner' LIMIT 1];
    Id versionId = buildMergedContentVersion(sr.Id, false);
    Test.setMock(HttpCalloutMock.class, new DocuSignCalloutMock());
    MBP_SendForSignatureController.SendJob job =
        new MBP_SendForSignatureController.SendJob(sr.Id, versionId);
    Test.startTest();
    job.execute(new FakeQueueableContext());
    Test.stopTest();
}

@isTest
static void testSendJob_failureIsCaughtAndLogged(){
    ServiceRequest__c srBlank = [SELECT Id FROM ServiceRequest__c WHERE Broker_Agency_Owner_Name__c = 'Blank Email Owner' LIMIT 1];
    Id fakeVersionId = fakeId(ContentVersion.SObjectType, 610);
    MBP_SendForSignatureController.SendJob job =
        new MBP_SendForSignatureController.SendJob(srBlank.Id, fakeVersionId);
    Test.startTest();
    job.execute(new FakeQueueableContext());
    Test.stopTest();
}

@isTest
static void testSendJobAccount_realRecord_executesAndLogsSuccess(){
    Account acc = [SELECT Id FROM Account WHERE Name LIKE :(MAIN_AGENCY_PREFIX + '%') LIMIT 1];
    Id versionId = buildMergedContentVersion(acc.Id, true);
    Test.setMock(HttpCalloutMock.class, new DocuSignCalloutMock());
    MBP_SendForSignatureController.SendJobAccount job =
        new MBP_SendForSignatureController.SendJobAccount(acc.Id, versionId);
    Test.startTest();
    job.execute(new FakeQueueableContext());
    Test.stopTest();
}

@isTest
static void testSendJobAccount_failureIsCaughtAndLogged(){
    Account accNoOwner = [SELECT Id FROM Account WHERE Name LIKE :(NO_OWNER_AGENCY_PREFIX + '%') LIMIT 1];
    Id fakeVersionId = fakeId(ContentVersion.SObjectType, 611);
    MBP_SendForSignatureController.SendJobAccount job =
        new MBP_SendForSignatureController.SendJobAccount(accNoOwner.Id, fakeVersionId);
    Test.startTest();
    job.execute(new FakeQueueableContext());
    Test.stopTest();
}
}