/**********************************************************************************************************************
* Name               : ADHA_JourneyControllerTest
* Description        : Covers journey stages 2-4: OTP verification, the SLA trigger, the General Declaration and the
*                      session that guards every later call. The OTP send itself is covered by VerificationService.
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           Aurelix                     13 Aug 2026     Initial draft.
* 1.1           Aurelix                     17 Aug 2026     Gate tests for the development OTP bypass.
* 1.2           Aurelix                     22 Aug 2026     Soft launch: the frozen clock, and the declaration shown
*                                                             without consent being stamped.
***********************************************************************************************************************/
@isTest
private class ADHA_JourneyControllerTest {

    private static final String CODE = '123456';

    @TestSetup
    static void setup() {
        insert new ADHA_Applicant__c(
            Application_Number__c = 'T0000001',
            Emirates_ID__c = '784-1980-1111111-1',
            Customer_Name__c = 'Test Applicant',
            Mobile_Number__c = '+971500000001',
            Service_Type__c = 'House Grant',
            Eligible_Categories__c = 'A',
            Approved_Loan_Amount__c = 1750000,
            Journey_Stage__c = 'Invited'
        );

        // Two eligible, one not - enough to prove the eligibility filter still applies under a session.
        List<ADHA_Unit__c> units = new List<ADHA_Unit__c>();
        for (Integer i = 0; i < 3; i++) {
            units.add(new ADHA_Unit__c(
                Plot_UID__c = 'TEST-' + i,
                Category_Type__c = i < 2 ? 'A' : 'B',
                Eligible_Service__c = 'House Grant',
                Villa_Type__c = 'Modern',
                Community__c = 'Wb2_01',
                Status__c = 'Available',
                Expose_To__c = 'Public',
                Masterplan_Number__c = i + 1,
                Map_Polygon__c = '[[0.1,0.1],[0.2,0.1],[0.2,0.2]]',
                Centroid_X__c = 0.15,
                Centroid_Y__c = 0.15,
                Rooms_Count__c = 5,
                Balconies_Count__c = 3,
                Price__c = 1800000
            ));
        }
        insert units;
    }

    /** Mirrors VerificationService.hashCode so a pending request can be created without a callout. */
    private static String hashCode(String code) {
        return EncodingUtil.convertToHex(
            Crypto.generateDigest('SHA-256', Blob.valueOf(code + '|' + UserInfo.getOrganizationId())));
    }

    private static Verification_Request__c pendingRequest(Id applicantId) {
        Verification_Request__c v = new Verification_Request__c(
            Channel__c = 'SMS',
            Target__c = '+971500000001',
            Masked_Target__c = '+9715****0001',
            Code_Hash__c = hashCode(CODE),
            Status__c = 'Pending',
            Context__c = 'ADHA_BANIYAS',
            Context_Key__c = String.valueOf(applicantId),
            Expires_At__c = System.now().addMinutes(10),
            Attempts__c = 0,
            Max_Attempts__c = 5,
            Resend_Count__c = 0,
            Max_Resends__c = 3
        );
        insert v;
        return v;
    }

    private static ADHA_Applicant__c applicant() {
        return [SELECT Id, First_Verified_Login__c, SLA_Start__c, SLA_End__c, Current_Attempt__c,
                       Journey_Stage__c, Declaration_Accepted__c, Declaration_Version__c, Declaration_Language__c,
                       Declaration_Accepted_On__c, Preferred_Language__c, Service_Type__c
                FROM ADHA_Applicant__c LIMIT 1];
    }

    @isTest
    static void verifyStartsTheSlaAndIssuesASession() {
        // Says out loud what this test assumes. Without it the test reads the org's real
        // ADHA_Setting__mdt, and fails whenever exploration mode is switched on.
        exploring(false);
        ADHA_Applicant__c before = applicant();
        Verification_Request__c v = pendingRequest(before.Id);

        Test.startTest();
        ADHA_JourneyController.Session session = ADHA_JourneyController.verifyCode(v.Id, CODE);
        Test.stopTest();

        System.assertNotEquals(null, session.token, 'A session token should be issued');
        System.assertEquals('Test Applicant', session.customerName);
        System.assertEquals('Logged In', session.journeyStage);

        ADHA_Applicant__c after = applicant();
        System.assertNotEquals(null, after.First_Verified_Login__c, 'First verified login is the SLA trigger');
        System.assertEquals(7, after.SLA_Start__c.date().daysBetween(after.SLA_End__c.date()), 'SLA window is 7 days');
        System.assertEquals(1, after.Current_Attempt__c);
    }

    /** The single most important rule in the journey document: logging in again must not buy more time. */
    @isTest
    static void secondLoginDoesNotExtendTheSla() {
        ADHA_Applicant__c seed = applicant();
        ADHA_JourneyController.Session first = ADHA_JourneyController.verifyCode(pendingRequest(seed.Id).Id, CODE);
        ADHA_Applicant__c afterFirst = applicant();

        Test.startTest();
        ADHA_JourneyController.Session second = ADHA_JourneyController.verifyCode(pendingRequest(seed.Id).Id, CODE);
        Test.stopTest();

        ADHA_Applicant__c afterSecond = applicant();
        System.assertEquals(afterFirst.First_Verified_Login__c, afterSecond.First_Verified_Login__c,
            'First verified login must never be overwritten');
        System.assertEquals(afterFirst.SLA_End__c, afterSecond.SLA_End__c,
            'The 7-day window must not restart on a second login');
        System.assertNotEquals(first.token, second.token, 'Each login issues a fresh token');
    }

    /** Stage 3 and stage 4b read different records; as one call, the deed was served at both
     *  stages and the General Declaration at neither. */
    @isTest
    static void stageThreeServesTheGeneralDeclarationAndStageFourTheDeed() {
        exploring(false);
        ADHA_Applicant__c seed = applicant();

        Test.startTest();
        ADHA_JourneyController.Declaration declaration = ADHA_JourneyController.getDeclaration('en');
        ADHA_JourneyController.Declaration deed =
            ADHA_JourneyController.getUndertaking('en', seed.Service_Type__c);
        Test.stopTest();

        // Derived, not hardcoded: the fixture's service type is free to change, and what matters
        // is that it maps to a real deed, because that is what makes the two stages differ.
        String deedType = ADHA_JourneyController.undertakingTypeFor(seed.Service_Type__c);
        System.assertNotEquals('General Declaration', deedType,
            'a fixture that falls back to the declaration would prove nothing here');
        // On the body, not the version: Grant and the General Declaration both sit at 2026-08-v1,
        // so equal versions prove nothing while equal bodies prove the two stages collapsed again.
        System.assertNotEquals(declaration.body, deed.body,
            'stage 3 and stage 4b must not resolve to the same record');
        System.assert(declaration.body.contains('housing application'),
            'stage 3 is the General Declaration: ' + declaration.body.left(80));
        System.assert(deed.body.contains(deedType),
            'stage 4b is the ' + deedType + ' deed: ' + deed.body.left(80));
        System.assertEquals(false, declaration.placeholder,
            'ADHA supplied the real text on 26 August, so nothing should badge as placeholder');
    }

    @isTest
    static void declarationIsServedAndAcceptanceIsRecorded() {
        // Says out loud what this test assumes. Without it the test reads the org's real
        // ADHA_Setting__mdt, and fails whenever exploration mode is switched on.
        exploring(false);
        ADHA_Applicant__c seed = applicant();
        ADHA_JourneyController.Session session = ADHA_JourneyController.verifyCode(pendingRequest(seed.Id).Id, CODE);

        Test.startTest();
        ADHA_JourneyController.Declaration declaration =
            ADHA_JourneyController.getDeclaration('en');
        ADHA_JourneyController.Session accepted = ADHA_JourneyController.acceptDeclaration(session.token, 'en');
        Test.stopTest();

        System.assert(String.isNotBlank(declaration.body), 'Declaration text should be served');
        System.assertEquals(true, accepted.declarationAccepted);
        System.assertEquals('Declaration Accepted', accepted.journeyStage);

        ADHA_Applicant__c after = applicant();
        System.assertEquals(declaration.version, after.Declaration_Version__c, 'Records which text was accepted');
        System.assertEquals('en', after.Declaration_Language__c, 'AR and EN are not interchangeable evidence');
    }

    /** Every acceptance overwrites the stamp; the previous values survive in field history, which
     *  is what makes overwriting them safe. */
    @isTest
    static void everyAcceptanceIsStamped() {
        // Says out loud what this test assumes. Without it the test reads the org's real
        // ADHA_Setting__mdt, and fails whenever exploration mode is switched on.
        exploring(false);
        ADHA_Applicant__c seed = applicant();
        ADHA_JourneyController.Session session = ADHA_JourneyController.verifyCode(pendingRequest(seed.Id).Id, CODE);
        ADHA_JourneyController.acceptDeclaration(session.token, 'en');

        ADHA_Applicant__c first = applicant();
        Datetime originalOn = first.Declaration_Accepted_On__c;
        System.assertNotEquals(null, originalOn, 'the first acceptance is stamped');
        System.assertEquals('en', first.Declaration_Language__c);

        Test.startTest();
        // Same customer, later visit, this time in Arabic.
        ADHA_JourneyController.acceptDeclaration(session.token, 'ar');
        Test.stopTest();

        ADHA_Applicant__c after = applicant();
        System.assertEquals('ar', after.Declaration_Language__c,
            'the record holds the most recent consent; the earlier one is in field history');
        System.assert(after.Declaration_Accepted_On__c >= originalOn,
            'and the stamp moves, which is what makes a history row exist at all');
        System.assertEquals(true, after.Declaration_Accepted__c,
            'has ever accepted stays true');
        System.assertEquals('ar', after.Preferred_Language__c);
    }

    /** Per session, not per applicant: a refresh must not re-ask, and a fresh login must. */
    @isTest
    static void theDeclarationIsAskedOncePerSession() {
        // Says out loud what this test assumes. Without it the test reads the org's real
        // ADHA_Setting__mdt, and fails whenever exploration mode is switched on.
        exploring(false);
        ADHA_Applicant__c seed = applicant();
        ADHA_JourneyController.Session first =
            ADHA_JourneyController.verifyCode(pendingRequest(seed.Id).Id, CODE);
        System.assertEquals(false, first.declarationAccepted, 'never accepted yet');

        ADHA_JourneyController.acceptDeclaration(first.token, 'en');
        System.assertEquals(true, ADHA_JourneyController.resumeSession(first.token).declarationAccepted,
            'a refresh in the same session does not ask again');

        Test.startTest();
        // A new login reissues the token, so the stored hash no longer matches.
        ADHA_JourneyController.Session second =
            ADHA_JourneyController.verifyCode(pendingRequest(seed.Id).Id, CODE);
        Test.stopTest();

        System.assertEquals(false, second.declarationAccepted,
            'a fresh sign-in asks for it again');
        System.assertEquals(true, applicant().Declaration_Accepted__c,
            'even though they have accepted it before');
    }

    @isTest
    static void markExploringMovesTheStageForTheDailyReport() {
        ADHA_Applicant__c seed = applicant();
        ADHA_JourneyController.Session session = ADHA_JourneyController.verifyCode(pendingRequest(seed.Id).Id, CODE);
        ADHA_JourneyController.acceptDeclaration(session.token, 'en');

        Test.startTest();
        ADHA_JourneyController.markExploring(session.token);
        Test.stopTest();

        System.assertEquals('Exploring', applicant().Journey_Stage__c);
    }

    /** A later stage must survive a customer navigating backwards. */
    @isTest
    static void stageIsNeverMovedBackwards() {
        ADHA_Applicant__c seed = applicant();
        ADHA_JourneyController.Session session = ADHA_JourneyController.verifyCode(pendingRequest(seed.Id).Id, CODE);
        ADHA_JourneyController.acceptDeclaration(session.token, 'en');
        ADHA_JourneyController.markExploring(session.token);

        Test.startTest();
        ADHA_JourneyController.acceptDeclaration(session.token, 'en');
        Test.stopTest();

        System.assertEquals('Exploring', applicant().Journey_Stage__c,
            'Re-accepting the declaration must not drag the stage back');
    }

    /** Signing in elsewhere must not merely fail to share the session - it must kill the first one. */
    @isTest
    static void secondLoginInvalidatesTheFirstSession() {
        ADHA_Applicant__c seed = applicant();
        ADHA_JourneyController.Session first = ADHA_JourneyController.verifyCode(pendingRequest(seed.Id).Id, CODE);
        System.assertEquals('ok', ADHA_JourneyController.sessionStatus(first.token, false),
            'The first session is live before the second login');

        Test.startTest();
        ADHA_JourneyController.Session second = ADHA_JourneyController.verifyCode(pendingRequest(seed.Id).Id, CODE);
        Test.stopTest();

        System.assertEquals('superseded', ADHA_JourneyController.sessionStatus(first.token, false),
            'The first window must be told it was superseded, not merely expired');
        System.assertEquals('ok', ADHA_JourneyController.sessionStatus(second.token, false),
            'The newest session stays live');

        Boolean rejected = false;
        try {
            ADHA_JourneyController.resumeSession(first.token);
        } catch (Exception e) {
            rejected = true;
        }
        System.assert(rejected, 'The superseded token must no longer resolve');
    }

    /** Signing out must kill the session at once, not leave it to the idle lapse; shared devices
     *  are the whole point of the control. */
    @isTest
    static void endSessionClearsTheSessionImmediately() {
        ADHA_Applicant__c seed = applicant();
        ADHA_JourneyController.Session session = ADHA_JourneyController.verifyCode(pendingRequest(seed.Id).Id, CODE);
        System.assertEquals('ok', ADHA_JourneyController.sessionStatus(session.token, false),
            'The session is live before signing out');

        Test.startTest();
        ADHA_JourneyController.endSession(session.token, 'Signed out');
        Test.stopTest();

        ADHA_Applicant__c after = [
            SELECT Session_Token_Hash__c, Prior_Session_Token_Hash__c, Session_Expires_At__c,
                   Session_Ended_On__c, Session_Ended_Reason__c
            FROM ADHA_Applicant__c WHERE Id = :seed.Id
        ];
        System.assertEquals(null, after.Session_Token_Hash__c, 'The live token hash is cleared');
        System.assertEquals(null, after.Prior_Session_Token_Hash__c,
            'The prior hash goes too, or the token answers "superseded" and the applicant is told '
            + 'they signed in on another device when all they did was sign out');
        System.assertEquals(null, after.Session_Expires_At__c, 'The expiry is cleared with it');
        System.assertNotEquals(null, after.Session_Ended_On__c, 'The ending is timestamped');
        System.assertEquals('Signed out', after.Session_Ended_Reason__c, 'and carries its reason');

        System.assertEquals('expired', ADHA_JourneyController.sessionStatus(session.token, false),
            'The token is dead, and dead reads as expired rather than superseded');
    }

    /** An idle timeout ends the session the same way, and says so on the record. */
    @isTest
    static void endSessionRecordsAnIdleTimeout() {
        ADHA_Applicant__c seed = applicant();
        ADHA_JourneyController.Session session = ADHA_JourneyController.verifyCode(pendingRequest(seed.Id).Id, CODE);

        Test.startTest();
        ADHA_JourneyController.endSession(session.token, 'Idle timeout');
        Test.stopTest();

        ADHA_Applicant__c after = [
            SELECT Session_Token_Hash__c, Session_Ended_Reason__c
            FROM ADHA_Applicant__c WHERE Id = :seed.Id
        ];
        System.assertEquals(null, after.Session_Token_Hash__c, 'Still torn down');
        System.assertEquals('Idle timeout', after.Session_Ended_Reason__c, 'Recorded as idle, not as a sign out');
    }

    /** A superseded tab reports its ending with the PREVIOUS token; clearing anything here would
     *  kill the session the applicant is actually using. */
    @isTest
    static void endSessionFromASupersededTabLeavesTheLiveSessionAlone() {
        ADHA_Applicant__c seed = applicant();
        ADHA_JourneyController.Session first = ADHA_JourneyController.verifyCode(pendingRequest(seed.Id).Id, CODE);
        ADHA_JourneyController.Session second = ADHA_JourneyController.verifyCode(pendingRequest(seed.Id).Id, CODE);
        System.assertEquals('superseded', ADHA_JourneyController.sessionStatus(first.token, false),
            'The first tab is superseded before it reports anything');

        Test.startTest();
        ADHA_JourneyController.endSession(first.token, 'Superseded');
        Test.stopTest();

        System.assertEquals('ok', ADHA_JourneyController.sessionStatus(second.token, false),
            'The live session must survive the old tab reporting its own ending');
        ADHA_Applicant__c after = [
            SELECT Session_Token_Hash__c, Session_Ended_On__c FROM ADHA_Applicant__c WHERE Id = :seed.Id
        ];
        System.assertNotEquals(null, after.Session_Token_Hash__c, 'The live token hash is untouched');
        System.assertEquals(null, after.Session_Ended_On__c,
            'and nothing is stamped as ended, because the applicant is still signed in');
    }

    /** A reason the client made up must not reach the restricted picklist. */
    @isTest
    static void endSessionNormalisesAnUnknownReason() {
        ADHA_Applicant__c seed = applicant();
        ADHA_JourneyController.Session session = ADHA_JourneyController.verifyCode(pendingRequest(seed.Id).Id, CODE);

        Test.startTest();
        ADHA_JourneyController.endSession(session.token, 'whatever-the-client-felt-like');
        Test.stopTest();

        System.assertEquals('Signed out',
            [SELECT Session_Ended_Reason__c FROM ADHA_Applicant__c WHERE Id = :seed.Id].Session_Ended_Reason__c,
            'Anything unrecognised falls back to Signed out rather than failing the update');
    }

    /** Without this log line a lapsed hold reads the same whether the applicant walked away or
     *  their browser died. */
    @isTest
    static void endSessionWritesTheEndingIntoTheReservationTrail() {
        ADHA_Applicant__c seed = applicant();
        ADHA_JourneyController.Session session = ADHA_JourneyController.verifyCode(pendingRequest(seed.Id).Id, CODE);

        ADHA_Unit__c u = new ADHA_Unit__c(
            Plot_UID__c = 'SIGNOUT-1',
            Category_Type__c = 'A',
            Eligible_Service__c = 'House Grant',
            Villa_Type__c = 'Modern',
            Community__c = 'Wb4_03',
            Status__c = 'Reserved',
            Expose_To__c = 'Public',
            Masterplan_Number__c = 901,
            Price__c = 1800000
        );
        insert u;

        insert new ADHA_Reservation__c(
            Applicant__c = seed.Id,
            Unit__c = u.Id,
            Status__c = 'Held',
            Attempt_Number__c = 1,
            Hold_Expires_At__c = System.now().addMinutes(10),
            Undertaking_Accepted__c = false,
            Unit_Lock_Key__c = String.valueOf(u.Id),
            Applicant_Lock_Key__c = String.valueOf(seed.Id),
            Journey_Log__c = 'Held SIGNOUT-1'
        );

        Test.startTest();
        ADHA_JourneyController.endSession(session.token, 'Signed out');
        Test.stopTest();

        String log = [
            SELECT Journey_Log__c FROM ADHA_Reservation__c WHERE Applicant__c = :seed.Id LIMIT 1
        ].Journey_Log__c;
        System.assert(log.contains('Held SIGNOUT-1'), 'The existing trail is kept, not overwritten');
        System.assert(log.contains('Session ended: Signed out'),
            'and the ending is appended so a later lapse can be explained. Got: ' + log);
    }

    /** Sign-out is fire-and-forget, so a repeat call or a forgotten token must not throw back at
     *  a torn-down client. */
    @isTest
    static void endSessionIsSilentOnUnknownOrRepeatedTokens() {
        ADHA_Applicant__c seed = applicant();
        ADHA_JourneyController.Session session = ADHA_JourneyController.verifyCode(pendingRequest(seed.Id).Id, CODE);

        Test.startTest();
        ADHA_JourneyController.endSession(session.token, 'Signed out');
        ADHA_JourneyController.endSession(session.token, 'Signed out');
        ADHA_JourneyController.endSession('never-issued', 'Signed out');
        ADHA_JourneyController.endSession(null, null);
        ADHA_JourneyController.endSession('', 'Signed out');
        Test.stopTest();

        System.assertEquals('expired', ADHA_JourneyController.sessionStatus(session.token, false),
            'Still expired, and nothing threw along the way');
    }

    /** The heartbeat must not keep an abandoned tab alive - only real interaction slides the window. */
    @isTest
    static void heartbeatWithoutTouchDoesNotExtendTheSession() {
        ADHA_Applicant__c seed = applicant();
        ADHA_JourneyController.Session session = ADHA_JourneyController.verifyCode(pendingRequest(seed.Id).Id, CODE);
        Datetime before = [SELECT Session_Expires_At__c FROM ADHA_Applicant__c WHERE Id = :seed.Id].Session_Expires_At__c;

        Test.startTest();
        ADHA_JourneyController.sessionStatus(session.token, false);
        Datetime afterCheck = [SELECT Session_Expires_At__c FROM ADHA_Applicant__c WHERE Id = :seed.Id].Session_Expires_At__c;
        ADHA_JourneyController.sessionStatus(session.token, true);
        Datetime afterTouch = [SELECT Session_Expires_At__c FROM ADHA_Applicant__c WHERE Id = :seed.Id].Session_Expires_At__c;
        Test.stopTest();

        System.assertEquals(before, afterCheck, 'A plain heartbeat must never extend the idle window');
        System.assert(afterTouch >= before, 'Real interaction slides the window forward');
    }

    @isTest
    static void idleSessionReportsExpired() {
        ADHA_Applicant__c seed = applicant();
        ADHA_JourneyController.Session session = ADHA_JourneyController.verifyCode(pendingRequest(seed.Id).Id, CODE);
        update new ADHA_Applicant__c(Id = seed.Id, Session_Expires_At__c = System.now().addMinutes(-1));

        Test.startTest();
        String status = ADHA_JourneyController.sessionStatus(session.token, true);
        Test.stopTest();

        System.assertEquals('expired', status, 'An idle-expired session cannot be revived by a touch');
    }

    @isTest
    static void unknownTokenReportsExpiredNotSuperseded() {
        Test.startTest();
        String status = ADHA_JourneyController.sessionStatus('never-issued', false);
        Test.stopTest();
        System.assertEquals('expired', status);
    }

    @isTest
    static void forgedTokenIsRejected() {
        Boolean rejected = false;
        Test.startTest();
        try {
            ADHA_JourneyController.resumeSession('deadbeefdeadbeef');
        } catch (Exception e) {
            rejected = true;
        }
        Test.stopTest();
        System.assert(rejected, 'A token that matches no applicant must be rejected');
    }

    @isTest
    static void expiredSessionIsRejected() {
        ADHA_Applicant__c seed = applicant();
        ADHA_JourneyController.Session session = ADHA_JourneyController.verifyCode(pendingRequest(seed.Id).Id, CODE);
        update new ADHA_Applicant__c(Id = seed.Id, Session_Expires_At__c = System.now().addMinutes(-1));

        Boolean rejected = false;
        Test.startTest();
        try {
            ADHA_JourneyController.resumeSession(session.token);
        } catch (Exception e) {
            rejected = true;
        }
        Test.stopTest();
        System.assert(rejected, 'An expired session must be rejected');
    }

    @isTest
    static void blankTokenIsRejected() {
        Boolean rejected = false;
        Test.startTest();
        try {
            ADHA_JourneyController.resumeSession('');
        } catch (Exception e) {
            rejected = true;
        }
        Test.stopTest();
        System.assert(rejected, 'A blank token must not resolve to anyone');
    }

    /** An unknown Emirates ID and a known one must be indistinguishable to the caller. */
    @isTest
    static void unknownEmiratesIdLooksIdenticalToAKnownOne() {
        Test.startTest();
        ADHA_JourneyController.LoginStart unknown = ADHA_JourneyController.startLogin('784-1999-9999999-9');
        Test.stopTest();

        System.assertEquals(false, unknown.dispatched, 'No verification should be created for an unknown ID');
        System.assertNotEquals(null, unknown.message, 'The caller still gets the generic message');
        System.assertEquals(null, unknown.verificationRequestId, 'Nothing to resend against');
    }

    @isTest
    static void missingMobileNumberDoesNotLeakThatTheApplicantExists() {
        update new ADHA_Applicant__c(Id = applicant().Id, Mobile_Number__c = null);

        Test.startTest();
        ADHA_JourneyController.LoginStart result = ADHA_JourneyController.startLogin('784-1980-1111111-1');
        Test.stopTest();

        System.assertEquals(false, result.dispatched);
        System.assertEquals(null, result.verificationRequestId);
    }

    /** Asserted on the helper rather than through startLogin: reaching the lookup with a real mobile
     *  number attached would fire an SMS callout, which a test cannot make. */
    @isTest
    static void emiratesIdIsNormalisedRegardlessOfSeparators() {
        Test.startTest();
        String fromDigits = ADHA_JourneyController.normaliseEmiratesId('784198011111111');
        String fromDashes = ADHA_JourneyController.normaliseEmiratesId('784-1980-1111111-1');
        String fromSpaces = ADHA_JourneyController.normaliseEmiratesId(' 784 1980 1111111 1 ');
        Test.stopTest();

        System.assertEquals('784-1980-1111111-1', fromDigits, 'Digits only should reach the stored format');
        System.assertEquals('784-1980-1111111-1', fromDashes, 'Already formatted input is unchanged');
        System.assertEquals('784-1980-1111111-1', fromSpaces, 'Spaces are separators like any other');
        System.assertEquals('12345', ADHA_JourneyController.normaliseEmiratesId(' 12345 '),
            'Anything that is not 15 digits is passed through trimmed, to be matched or not on its own terms');
    }

    @isTest
    static void blankEmiratesIdIsRejected() {
        Boolean rejected = false;
        Test.startTest();
        try {
            ADHA_JourneyController.startLogin('   ');
        } catch (Exception e) {
            rejected = true;
        }
        Test.stopTest();
        System.assert(rejected, 'A blank Emirates ID is a client error, not a silent no-op');
    }

    /* ---------- the development OTP bypass ----------
     * All three null the mobile first, parking the applicant short of the SMS callout so only the gate is under test. */

    private static void stubSettings(Boolean flag, String orgId) {
        ADHA_JourneyController.settingsCache = new ADHA_Setting__mdt(
            Dev_Skip_OTP__c = flag,
            Dev_Skip_OTP_Org_Id__c = orgId
        );
    }

    @isTest
    static void bypassIsOffByDefault() {
        update new ADHA_Applicant__c(Id = applicant().Id, Mobile_Number__c = null);
        stubSettings(false, UserInfo.getOrganizationId());

        Test.startTest();
        ADHA_JourneyController.LoginStart result = ADHA_JourneyController.startLogin('784-1980-1111111-1');
        Test.stopTest();

        System.assertEquals(false, result.skipOtp, 'The checkbox is off, so the OTP stage stands');
        System.assertEquals(null, result.session, 'No session may be handed out without verification');
        System.assertEquals(null, applicant().First_Verified_Login__c, 'The SLA must not have been triggered');
    }

    /** The guard that actually matters. A checkbox travels with the metadata; a named org id does not. */
    @isTest
    static void bypassIsClosedWhenTheOrgIdDoesNotMatch() {
        update new ADHA_Applicant__c(Id = applicant().Id, Mobile_Number__c = null);

        Test.startTest();
        stubSettings(true, null);
        ADHA_JourneyController.LoginStart blank = ADHA_JourneyController.startLogin('784-1980-1111111-1');
        stubSettings(true, '00D000000000000AAA');
        ADHA_JourneyController.LoginStart other = ADHA_JourneyController.startLogin('784-1980-1111111-1');
        Test.stopTest();

        System.assertEquals(false, blank.skipOtp, 'A blank org id must never open the bypass');
        System.assertEquals(null, blank.session);
        System.assertEquals(false, other.skipOtp, 'Another org id must never open the bypass');
        System.assertEquals(null, other.session);
        System.assertEquals(null, applicant().First_Verified_Login__c, 'The SLA must not have been triggered');
    }

    @isTest
    static void bypassIssuesTheSameSessionAsARealOtp() {
        update new ADHA_Applicant__c(Id = applicant().Id, Mobile_Number__c = null);
        stubSettings(true, UserInfo.getOrganizationId());

        Test.startTest();
        ADHA_JourneyController.LoginStart result = ADHA_JourneyController.startLogin('784-1980-1111111-1');
        Test.stopTest();

        System.assertEquals(true, result.skipOtp);
        System.assertNotEquals(null, result.session, 'The bypass must hand back a usable session');
        System.assertNotEquals(null, result.session.token);
        System.assertEquals('Test Applicant', result.session.customerName);
        System.assertEquals('Logged In', result.session.journeyStage);
        System.assertEquals(null, result.verificationRequestId, 'No OTP was sent, so there is nothing to resend against');

        // issueSession is shared with verifyCode, so the SLA has to be stamped exactly as it is there.
        ADHA_Applicant__c after = applicant();
        System.assertNotEquals(null, after.First_Verified_Login__c, 'First verified login is the SLA trigger');
        System.assertEquals(7, after.SLA_Start__c.date().daysBetween(after.SLA_End__c.date()), 'SLA window is 7 days');
        System.assertEquals(1, after.Current_Attempt__c);
        System.assertEquals(0, [SELECT COUNT() FROM Verification_Request__c], 'The bypass must not create a verification row');
    }

    /* ---------- exploration mode ----------
     * These cover the clock and the consent; the booking refusal lives in ADHA_ReservationServiceTest. */

    /** Boolean rather than the datetime this replaced, so null stays reachable: it is the state of
     *  an org where nobody set the field, and it has its own test below. */
    private static void exploring(Boolean isOn) {
        ADHA_JourneyController.settingsCache = new ADHA_Setting__mdt(Exploration_Mode__c = isOn);
    }

    @isTest
    static void reservationsAreOpenWhenNobodySetTheField() {
        exploring(null);
        System.assertEquals(true, ADHA_JourneyController.reservationsOpen(),
            'Null must mean open, or an org where nobody set the field refuses every reservation');
    }

    /* The banner needs the gate before a session exists, so it is asked for separately. These two
     * prove the endpoint answers the same question reservationsOpen does, inverted. */

    @isTest
    static void explorationModeEndpointReportsTheGateForTheWelcomeScreen() {
        exploring(true);
        System.assertEquals(true, ADHA_JourneyController.explorationMode(),
            'The welcome screen has no session to read, so it asks here');

        exploring(false);
        System.assertEquals(false, ADHA_JourneyController.explorationMode());
    }

    @isTest
    static void explorationModeEndpointSaysNoWhenNobodySetTheField() {
        exploring(null);
        System.assertEquals(false, ADHA_JourneyController.explorationMode(),
            'A null must not put an exploration banner on a live site');
    }

    /** The named exception: their clock starts and their session says open, while the site's own
     *  gate and everyone else's stay exactly where they were. */
    @isTest
    static void aListedEmiratesIdGetsAClockWhileTheSiteStaysClosed() {
        ADHA_JourneyController.settingsCache = new ADHA_Setting__mdt(
            Exploration_Mode__c = true,
            Exploration_Bypass_Emirates_Ids__c = '784-1980-1111111-1',
            SLA_Days__c = 7, Max_Attempts__c = 2
        );
        Verification_Request__c v = pendingRequest(applicant().Id);

        Test.startTest();
        ADHA_JourneyController.Session session = ADHA_JourneyController.verifyCode(v.Id, CODE);
        Test.stopTest();

        System.assertEquals(true, session.reservationsOpen,
            'the client opens the booking CTA for the one applicant proving the path');
        ADHA_Applicant__c after = applicant();
        System.assertNotEquals(null, after.SLA_Start__c, 'and the clock runs, or booking is refused');
        System.assertNotEquals(null, after.SLA_End__c);
        System.assertEquals(true, ADHA_JourneyController.explorationMode(),
            'the banner is org-wide: it must not lift for one person');
        System.assertEquals(false, ADHA_JourneyController.reservationsOpen(),
            'and the site gate itself is untouched');
    }

    @isTest
    static void anUnlistedEmiratesIdIsUnaffectedByTheBypass() {
        ADHA_JourneyController.settingsCache = new ADHA_Setting__mdt(
            Exploration_Mode__c = true,
            Exploration_Bypass_Emirates_Ids__c = '784-1980-9999999-9',
            SLA_Days__c = 7, Max_Attempts__c = 2
        );
        Verification_Request__c v = pendingRequest(applicant().Id);

        Test.startTest();
        ADHA_JourneyController.Session session = ADHA_JourneyController.verifyCode(v.Id, CODE);
        Test.stopTest();

        System.assertEquals(false, session.reservationsOpen, 'somebody else on the list is not them');
        System.assertEquals(null, applicant().SLA_Start__c, 'and browsing still costs them no day');
    }

    @isTest
    static void explorationModeLetsSomeoneInWithoutStartingTheirClock() {
        exploring(true);
        ADHA_Applicant__c before = applicant();
        Verification_Request__c v = pendingRequest(before.Id);

        Test.startTest();
        ADHA_JourneyController.Session session = ADHA_JourneyController.verifyCode(v.Id, CODE);
        Test.stopTest();

        System.assertNotEquals(null, session.token, 'They still sign in and still explore');
        System.assertEquals(false, session.reservationsOpen, 'The client needs to know to close the CTA');

        ADHA_Applicant__c after = applicant();
        System.assertNotEquals(null, after.First_Verified_Login__c, 'The visit is still recorded');
        System.assertEquals(null, after.SLA_Start__c, 'Browsing before launch must not cost a day');
        System.assertEquals(null, after.SLA_End__c);
    }

    @isTest
    static void theClockStartsOnTheFirstSignInAfterLaunch() {
        // The decisive one. Someone who looked around in exploration mode must get a full window
        // when reservations open, not a window that started while they were browsing.
        exploring(true);
        ADHA_JourneyController.verifyCode(pendingRequest(applicant().Id).Id, CODE);
        System.assertEquals(null, applicant().SLA_Start__c, 'Precondition: no clock yet');

        exploring(false);

        Test.startTest();
        ADHA_JourneyController.verifyCode(pendingRequest(applicant().Id).Id, CODE);
        Test.stopTest();

        ADHA_Applicant__c after = applicant();
        System.assertNotEquals(null, after.SLA_Start__c, 'The window opens when reservations do');
        System.assertEquals(7, after.SLA_Start__c.date().daysBetween(after.SLA_End__c.date()),
            'And it is the full 7 days, not what was left of them');
    }

    @isTest
    static void anExistingClockIsNeverRestarted() {
        exploring(false);
        ADHA_JourneyController.verifyCode(pendingRequest(applicant().Id).Id, CODE);
        Datetime firstStart = applicant().SLA_Start__c;
        System.assertNotEquals(null, firstStart);

        Test.startTest();
        ADHA_JourneyController.verifyCode(pendingRequest(applicant().Id).Id, CODE);
        Test.stopTest();

        System.assertEquals(firstStart, applicant().SLA_Start__c,
            'A second login must not extend the window - the guard moved to SLA_Start__c but must still hold');
    }

    @isTest
    static void explorationModeShowsTheDeclarationWithoutStampingConsent() {
        exploring(true);
        ADHA_JourneyController.Session session =
            ADHA_JourneyController.verifyCode(pendingRequest(applicant().Id).Id, CODE);

        Test.startTest();
        ADHA_JourneyController.Session after =
            ADHA_JourneyController.acceptDeclaration(session.token, 'en');
        Test.stopTest();

        ADHA_Applicant__c a = applicant();
        System.assertEquals(false, a.Declaration_Accepted__c, 'No acceptance while the text can still change');
        System.assertEquals(null, a.Declaration_Accepted_On__c, 'and nothing dated to point at');
        System.assertEquals(null, a.Declaration_Version__c, 'and no version it could be an acceptance of');

        System.assertEquals('en', a.Declaration_Language__c, 'The preference is not evidence, so it saves');
        System.assertEquals('Declaration Accepted', a.Journey_Stage__c, 'They still reach the map');
        System.assertEquals(true, after.declarationAccepted,
            'The session marker still stands, or a refresh would send them back to the declaration');
    }

    @isTest
    static void consentIsStampedOnceReservationsOpen() {
        exploring(false);
        ADHA_JourneyController.Session session =
            ADHA_JourneyController.verifyCode(pendingRequest(applicant().Id).Id, CODE);

        Test.startTest();
        ADHA_JourneyController.acceptDeclaration(session.token, 'ar');
        Test.stopTest();

        ADHA_Applicant__c a = applicant();
        System.assertEquals(true, a.Declaration_Accepted__c);
        System.assertNotEquals(null, a.Declaration_Accepted_On__c);
        System.assertNotEquals(null, a.Declaration_Version__c, 'The version is what makes it an acceptance');
    }

    /* ---------- batch release gate ----------
     * Every test stubs BOTH switches: exploration ignores the gate, and org-read settings broke tests before. */

    /** The dev bypass stays ON throughout: the only way to a session without an SMS callout, and
     *  proof the gate is checked BEFORE the bypass. */
    private static void batchGate(Boolean gateOn, Boolean exploringOn) {
        ADHA_JourneyController.settingsCache = new ADHA_Setting__mdt(
            Batch_Release_Mode__c = gateOn,
            Exploration_Mode__c = exploringOn,
            Dev_Skip_OTP__c = true,
            Dev_Skip_OTP_Org_Id__c = UserInfo.getOrganizationId()
        );
    }

    private static void released(Boolean isOn) {
        update new ADHA_Applicant__c(Id = applicant().Id, Login_Enabled__c = isOn);
    }

    @isTest
    static void batchGateOffLetsAnUnreleasedApplicantSignIn() {
        batchGate(false, false);
        released(false);

        Test.startTest();
        ADHA_JourneyController.LoginStart result = ADHA_JourneyController.startLogin('784-1980-1111111-1');
        Test.stopTest();

        System.assertNotEquals(null, result.session,
            'With the gate off the flag must not matter, or deploying it locks out every beneficiary');
    }

    @isTest
    static void batchGateIsOffWhenNobodySetTheField() {
        batchGate(null, false);
        released(false);

        Test.startTest();
        ADHA_JourneyController.LoginStart result = ADHA_JourneyController.startLogin('784-1980-1111111-1');
        Test.stopTest();

        System.assertNotEquals(null, result.session,
            'A null must read as off. An org where nobody set the field must not refuse everyone');
    }

    @isTest
    static void batchGateRefusesAnApplicantWhoseBatchIsNotReleased() {
        batchGate(true, false);
        released(false);

        Test.startTest();
        ADHA_JourneyController.LoginStart result = ADHA_JourneyController.startLogin('784-1980-1111111-1');
        Test.stopTest();

        System.assertEquals(null, result.session, 'Not released, so no session even with the bypass on');
        System.assertEquals(false, result.skipOtp, 'The gate is checked before the bypass, not after');
        System.assertEquals(false, result.dispatched, 'No invitation, so no OTP either');
        System.assertEquals(null, result.verificationRequestId);
        System.assertEquals(0, [SELECT COUNT() FROM Verification_Request__c],
            'A refused login must not leave a verification row behind');
        System.assertEquals(null, applicant().First_Verified_Login__c, 'And must not count as a visit');
    }

    @isTest
    static void batchGateLetsAReleasedApplicantSignIn() {
        batchGate(true, false);
        released(true);

        Test.startTest();
        ADHA_JourneyController.LoginStart result = ADHA_JourneyController.startLogin('784-1980-1111111-1');
        Test.stopTest();

        System.assertNotEquals(null, result.session, 'Released, so the gate must stand aside');
        System.assertEquals('Test Applicant', result.session.customerName);
    }

    /** A refusal that looks different from an unknown Emirates ID would confirm the person is on
     *  ADHA's housing list, so the WHOLE response has to match. */
    @isTest
    static void batchGateRefusalIsIdenticalToAnUnknownEmiratesId() {
        batchGate(true, false);
        released(false);

        Test.startTest();
        ADHA_JourneyController.LoginStart refused = ADHA_JourneyController.startLogin('784-1980-1111111-1');
        ADHA_JourneyController.LoginStart unknown = ADHA_JourneyController.startLogin('784-1999-9999999-9');
        Test.stopTest();

        System.assertEquals(unknown.message, refused.message, 'Same words');
        System.assertEquals(unknown.dispatched, refused.dispatched);
        System.assertEquals(unknown.skipOtp, refused.skipOtp);
        System.assertEquals(unknown.verificationRequestId, refused.verificationRequestId);
        System.assertEquals(unknown.maskedTarget, refused.maskedTarget,
            'A masked number here would say the person exists');
        System.assertEquals(unknown.expiresAt, refused.expiresAt);
        System.assertEquals(unknown.resendAvailableAt, refused.resendAvailableAt);
        System.assertEquals(unknown.session, refused.session);
        System.assertEquals(JSON.serialize(unknown), JSON.serialize(refused),
            'Byte for byte, so a field added later cannot quietly reintroduce the leak');
    }

    @isTest
    static void explorationModeIgnoresTheBatchGate() {
        // ADHA told beneficiaries to browse now and reserve when they are texted. Holding a later
        // batch out of the map would take back something they have already been offered.
        batchGate(true, true);
        released(false);

        Test.startTest();
        ADHA_JourneyController.LoginStart result = ADHA_JourneyController.startLogin('784-1980-1111111-1');
        Test.stopTest();

        System.assertNotEquals(null, result.session,
            'Exploration stays open to everyone; the gate only bites once reservations open');
        System.assertEquals(null, applicant().SLA_Start__c, 'And still without starting their clock');
    }

    /** Ops is never wave-released, so the go-live gate must wave them through. */
    @isTest
    static void batchGateNeverLocksOutOps() {
        ADHA_JourneyController.settingsCache = new ADHA_Setting__mdt(
            Batch_Release_Mode__c = true,
            Exploration_Mode__c = false,
            Dev_Skip_OTP__c = true,
            Dev_Skip_OTP_Org_Id__c = UserInfo.getOrganizationId(),
            Ops_Emirates_Ids__c = '784-1980-1111111-1'
        );
        released(false);
        update new ADHA_Applicant__c(Id = applicant().Id, Is_Ops__c = true);

        Test.startTest();
        ADHA_JourneyController.LoginStart result = ADHA_JourneyController.startLogin('784-1980-1111111-1');
        Test.stopTest();

        System.assertNotEquals(null, result.session,
            'the gate must not lock out the people who run the site');
    }
}