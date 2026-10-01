/**********************************************************************************************************************
* Name               : ADHA_JourneyController
* Description        : Stages 2 and 3 of the ADHA Baniyas customer journey - Emirates ID + OTP login (OTP itself lives
*                      in VerificationService), the SLA trigger, the General Declaration, and the session for later stages.
* Usage              : adhaBaniyasJourney LWC on the ADHA Baniyas Experience Cloud site, running as the guest user.
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           Aurelix                     13 Aug 2026     Initial draft. Journey stages 2-3 and session issuance.
* 1.1           Aurelix                     13 Aug 2026     Sliding idle expiry, and sessionStatus so a window superseded
*                                                             by a login elsewhere locks itself instead of lingering.
* 1.2           Aurelix                     14 Aug 2026     resumeSession returns the token; a blank one fell through
*                                                             to preview mode and showed all inventory as eligible.
* 1.3           Aurelix                     17 Aug 2026     Dev-only OTP bypass gated on a named org id; session issue
*                                                             extracted to issueSession() so the two routes cannot drift.
* 1.4           Aurelix                     22 Aug 2026     Soft launch gate; SLA clock keys on SLA_Start__c so exploring
*                                                             before launch costs no days and stamps no consent.
* 1.5           Aurelix                     26 Aug 2026     Gate is now the Exploration_Mode__c checkbox; the UTC-read
*                                                             future date and advance scheduling went with it.
* 1.6           Aurelix                     31 Aug 2026     Named exception to the gate: listed Emirates IDs may reserve
*                                                             while the site stays closed. The banner never moves.
***********************************************************************************************************************/
public without sharing class ADHA_JourneyController {

    private static final String VERIFICATION_CONTEXT = 'ADHA_BANIYAS';
    private static final String CHANNEL_SMS = 'SMS';
    /** Hard ceiling on a session however active the customer is. */
    private static final Integer SESSION_HOURS = 8;
    /** Short because a verified session can commit a reservation and the device may be shared; safe
     *  only because the client warns 60 seconds ahead and counts scrolling and panning as activity. */
    private static final Integer IDLE_MINUTES = 5;

    /** Returned for unknown and known Emirates IDs alike, so the endpoint cannot confirm housing eligibility.
     *  Every message here is a CODE; c/adhaLabels resolves wording so Arabic customers never see English. */
    private static final String GENERIC_START_MESSAGE = 'MSG_START';

    /** Maps VerificationService prose to codes at this one boundary so the shared class stays untouched;
     *  anything unrecognised becomes MSG_GENERIC rather than leaking English into an Arabic page. */
    private static String verificationCode(String message) {
        String m = message == null ? '' : message.toLowerCase();
        if (m.contains('invalid verification code')) {
            return 'MSG_OTP_INVALID';
        }
        if (m.contains('maximum verification attempts')) {
            return 'MSG_OTP_MAX_ATTEMPTS';
        }
        if (m.contains('maximum resend')) {
            return 'MSG_OTP_MAX_RESEND';
        }
        if (m.contains('please wait before requesting')) {
            return 'MSG_OTP_TOO_SOON';
        }
        return 'MSG_GENERIC';
    }

    public class JourneyException extends Exception {}

    public class LoginStart {
        @AuraEnabled public Id verificationRequestId;
        @AuraEnabled public String maskedTarget;
        @AuraEnabled public Datetime expiresAt;
        @AuraEnabled public Datetime resendAvailableAt;
        @AuraEnabled public String message;
        /** False when no applicant matched. The message is identical either way; this is only read
         *  server-side by tests, never branched on by the UI. */
        @AuraEnabled public Boolean dispatched = false;
        /** Development only. True means no OTP was sent and session below is already valid. */
        @AuraEnabled public Boolean skipOtp = false;
        @AuraEnabled public Session session;
    }

    public class Session {
        @AuraEnabled public String token;
        @AuraEnabled public String customerName;
        @AuraEnabled public String applicationNumber;
        @AuraEnabled public String maskedEmiratesId;
        @AuraEnabled public String serviceType;
        @AuraEnabled public String language;
        @AuraEnabled public String journeyStage;
        @AuraEnabled public Boolean declarationAccepted = false;
        @AuraEnabled public Datetime slaEnd;
        @AuraEnabled public Integer daysRemaining;
        @AuraEnabled public Integer attempt;
        /** Loaded by resolveApplicant since day one and then silently dropped by toSession, which
         *  is why the additional-amount screen could not be rendered at all. */
        @AuraEnabled public Decimal approvedLoanAmount;
        @AuraEnabled public Datetime slaStart;
        /** So the client can say "your last opportunity" without hard-coding 2. */
        @AuraEnabled public Integer maxAttempts;
        /** False during soft launch: explore yes, book no. Drives the villa CTA and the
         *  additional-amount row, so the client never offers what the server would refuse. */
        @AuraEnabled public Boolean reservationsOpen = true;
        /** Swaps of an already-signed villa still available this attempt. Zero hides the change
         *  button; the server refuses anyway if a stale page tries. */
        @AuraEnabled public Integer unitChangesRemaining;
        /** The total, including any per-applicant grant. "Final opportunity of 2" needs the two,
         *  not the one left. */
        @AuraEnabled public Integer unitChangesAllowed;
        /** Null when reserving is possible, otherwise the MSG_ code the server would refuse with. The client
         *  reads this rather than re-deriving the rule; that duplication once let an expired customer discard a villa. */
        @AuraEnabled public String reservationRefusal;
        /** Whether the signing step exists at all. False is how this ships, and with it false the
         *  journey ends at the confirmation screen exactly as it did before signing was built. */
        @AuraEnabled public Boolean signingEnabled = false;
        // Both ops gates passed. The client renders pin mode off this.
        @AuraEnabled public Boolean isOps = false;
        // The villa set aside for this applicant, if any.
        @AuraEnabled public String pinnedPlotUid;
    }

    public class Declaration {
        @AuraEnabled public String body;
        @AuraEnabled public String version;
        @AuraEnabled public String language;
        @AuraEnabled public Boolean placeholder = false;
    }

    /* ---------- stage 2: login ---------- */

    /** Looks up the applicant by Emirates ID and asks VerificationService to send an OTP to the mobile
     *  held on the record - never one accepted from the browser. */
    @AuraEnabled
    public static LoginStart startLogin(String emiratesId) {
        LoginStart result = new LoginStart();
        result.message = GENERIC_START_MESSAGE;

        String normalised = normaliseEmiratesId(emiratesId);
        if (String.isBlank(normalised)) {
            throw new AuraHandledException('MSG_ENTER_EID');
        }

        List<ADHA_Applicant__c> found = [
            SELECT Id, Mobile_Number__c, Customer_Name__c, Login_Enabled__c, Is_Ops__c, Emirates_ID__c
            FROM ADHA_Applicant__c
            WHERE Emirates_ID__c = :normalised
            LIMIT 1
        ];
        // Same shape, same message, no verification row. An attacker cannot tell the difference.
        if (found.isEmpty()) {
            return result;
        }

        // Unreleased batch gets the identical result an unknown Emirates ID gets - a difference would
        // confirm the person is on ADHA's housing list. Before the dev bypass on purpose.
        // Ops is never wave-released, so the batch gate must not lock them out at go-live.
        if (batchGateActive() && found[0].Login_Enabled__c != true && !isOps(found[0])) {
            System.debug(LoggingLevel.WARN, 'ADHA login blocked: batch not released for applicant ' + found[0].Id);
            return result;
        }

        // Development only. No VerificationService call, so no SMS and no Verification_Request__c
        // row, and a test applicant does not need a mobile number to be usable.
        if (bypassActive()) {
            System.debug(LoggingLevel.WARN, 'ADHA OTP bypass used for applicant ' + found[0].Id);
            result.skipOtp = true;
            result.session = issueSession(loadApplicant(found[0].Id));
            return result;
        }

        // Logged rather than surfaced: a customer whose mobile ADHA has not supplied must not be
        // able to tell their case apart from an unknown Emirates ID.
        if (String.isBlank(found[0].Mobile_Number__c)) {
            System.debug(LoggingLevel.WARN, 'ADHA login blocked: no mobile number on applicant ' + found[0].Id);
            return result;
        }

        VerificationService.VerificationStartRequest request = new VerificationService.VerificationStartRequest();
        request.channel = CHANNEL_SMS;
        request.target = found[0].Mobile_Number__c;
        request.context = VERIFICATION_CONTEXT;
        request.contextKey = String.valueOf(found[0].Id);

        VerificationService.VerificationResult sent = VerificationService.startVerification(request);
        result.verificationRequestId = sent.verificationRequestId;
        result.maskedTarget = sent.maskedTarget;
        result.expiresAt = sent.expiresAt;
        result.resendAvailableAt = sent.resendAvailableAt;
        result.dispatched = true;
        return result;
    }

    @AuraEnabled
    public static VerificationService.VerificationResult resendCode(Id verificationRequestId) {
        // Without this a guest could pass any journey's request Id, force a real SMS to that customer
        // and overwrite their code. The framework still owns the cooldown and resend cap.
        assertOwnRequest(verificationRequestId);
        return VerificationService.resendVerification(verificationRequestId);
    }

    /** Refuses a verification row belonging to another journey. Reads, never writes. */
    private static Verification_Request__c assertOwnRequest(Id verificationRequestId) {
        List<Verification_Request__c> rows = [
            SELECT Id, Context__c, Context_Key__c
            FROM Verification_Request__c
            WHERE Id = :verificationRequestId
            LIMIT 1
        ];
        if (rows.isEmpty() || rows[0].Context__c != VERIFICATION_CONTEXT) {
            throw new AuraHandledException('MSG_EID_UNVERIFIED');
        }
        return rows[0];
    }

    /** Verifies the code and, on success, starts the SLA and issues a session. The applicant comes from
     *  the verification row's Context_Key__c, never from anything the browser supplied. */
    @AuraEnabled
    public static Session verifyCode(Id verificationRequestId, String code) {
        // Ownership BEFORE the call. Verifying first would let a caller burn another journey's
        // attempts, or flip its row to Verified on a lucky guess, and only then be refused here.
        Verification_Request__c request = assertOwnRequest(verificationRequestId);
        if (String.isBlank(request.Context_Key__c)) {
            throw new AuraHandledException('MSG_EID_UNVERIFIED');
        }

        VerificationService.VerificationResult outcome = VerificationService.verifyCode(verificationRequestId, code);
        if (outcome == null || outcome.verified != true) {
            throw new AuraHandledException(outcome == null ? 'MSG_GENERIC' : verificationCode(outcome.message));
        }

        return issueSession(loadApplicant((Id) request.Context_Key__c));
    }

    /** The SLA trigger and the session mint, in one place. Called by verifyCode after a real OTP and
     *  by the development bypass in startLogin, so the two routes cannot drift apart. */
    private static Session issueSession(ADHA_Applicant__c applicant) {
        Datetime now = System.now();

        // Captured before the stamp below overwrites the answer.
        Boolean firstLogin = applicant.First_Verified_Login__c == null;
        if (firstLogin) {
            applicant.First_Verified_Login__c = now;
        }

        // THE SLA TRIGGER. Keyed on SLA_Start__c so soft-launch exploring runs no clock, and written
        // once so a second login never extends it. Never for ops.
        if (!isOps(applicant) && reservationsOpen(applicant) && applicant.SLA_Start__c == null) {
            applicant.SLA_Start__c = now;
            applicant.SLA_End__c = now.addDays(slaDays());
        }
        if (!isOps(applicant)) {
            if (applicant.Current_Attempt__c == null) {
                applicant.Current_Attempt__c = 1;
            }
            if (isEarlierStage(applicant.Journey_Stage__c, 'Logged In')) {
                applicant.Journey_Stage__c = 'Logged In';
            }
        }

        String token = newToken();
        // Remember what this login replaces, so the window that was holding it can be told it was
        // superseded rather than shown a generic expiry message.
        applicant.Prior_Session_Token_Hash__c = applicant.Session_Token_Hash__c;
        applicant.Session_Token_Hash__c = hashToken(token);
        applicant.Session_Expires_At__c = now.addMinutes(IDLE_MINUTES);
        applicant.Session_Hard_Expiry__c = now.addHours(SESSION_HOURS);
        update applicant;

        // Every sign-in, not just the first, and after the update, never before: an audit row for a
        // sign-in that failed to persist would be a lie in the timeline.
        ADHA_JourneyLog.log(
            applicant.Id, null, ADHA_JourneyLog.SIGNED_IN,
            'Stage ' + applicant.Journey_Stage__c + ', attempt ' + applicant.Current_Attempt__c
                + (firstLogin ? ', first sign-in' : '')
        );

        Session session = toSession(applicant);
        session.token = token;
        return session;
    }

    /** Double gate: Is_Ops__c on the record AND the Emirates ID in the settings
     *  allowlist. Both or nothing; a blank list means nobody. */
    public static Boolean isOps(ADHA_Applicant__c applicant) {
        // isSet first: many callers hand partially-queried applicants.
        if (applicant == null
            || !applicant.isSet(ADHA_Applicant__c.Is_Ops__c)
            || applicant.Is_Ops__c != true
            || !applicant.isSet(ADHA_Applicant__c.Emirates_ID__c)
            || String.isBlank(applicant.Emirates_ID__c)) {
            return false;
        }
        return emiratesIdListed(applicant.Emirates_ID__c, settings().Ops_Emirates_Ids__c);
    }

    /** Digits only, both sides - a dash-less allowlist entry must still match (same rule the
     *  signing allowlist uses). Blank list means nobody, never everybody. Shared so the ops list
     *  and the exploration bypass cannot drift apart. */
    private static Boolean emiratesIdListed(String emiratesId, String configured) {
        if (String.isBlank(configured) || String.isBlank(emiratesId)) {
            return false;
        }
        String mine = emiratesId.replaceAll('\\D', '');
        if (String.isBlank(mine)) {
            return false;
        }
        for (String allowed : configured.split(';')) {
            String entry = allowed.replaceAll('\\D', '');
            if (String.isNotBlank(entry) && entry == mine) {
                return true;
            }
        }
        return false;
    }

    /** The applicant's pinned villa, or null. First wins if there are two. */
    public static String pinnedPlotUidFor(Id applicantId) {
        List<ADHA_Unit__c> pinned = [
            SELECT Plot_UID__c FROM ADHA_Unit__c
            WHERE Pinned_Applicant__c = :applicantId
            ORDER BY Plot_UID__c
            LIMIT 1
        ];
        return pinned.isEmpty() ? null : pinned[0].Plot_UID__c;
    }

    /** Two independent conditions, because a checkbox alone would travel with the metadata. The org
     *  id has to be restated in each org the bypass is wanted in, and production is never one. */
    private static Boolean bypassActive() {
        return settings().Dev_Skip_OTP__c == true
            && settings().Dev_Skip_OTP_Org_Id__c == UserInfo.getOrganizationId();
    }

    /** The exploration mode gate, asked in one place so booking, the SLA clock, declaration consent and
     *  the additional amount cannot drift apart. Compared against true so a null means open. */
    public static Boolean reservationsOpen() {
        return settings().Exploration_Mode__c != true;
    }

    /** The org gate, and the named exception to it. Exploration mode is a property of the site;
     *  this is a property of one person, for proving the live booking and signing path before
     *  the site opens. The banner is deliberately not asked this question, so a listed applicant
     *  still sees viewing-only while being able to book: the site IS closed, they are the
     *  exception. Blank list means nobody, and no wildcard is honoured. */
    public static Boolean reservationsOpen(ADHA_Applicant__c applicant) {
        if (reservationsOpen()) {
            return true;
        }
        if (applicant == null || !applicant.isSet(ADHA_Applicant__c.Emirates_ID__c)) {
            return false;
        }
        Boolean listed = emiratesIdListed(
            applicant.Emirates_ID__c, settings().Exploration_Bypass_Emirates_Ids__c
        );
        if (listed) {
            System.debug(LoggingLevel.WARN,
                'ADHA exploration bypass used for applicant ' + applicant.Id);
        }
        return listed;
    }

    /** Restricts login to released batches, but only once reservations are open - ADHA told everyone to
     *  browse now, so exploration stays open. Compared against true so a null reads as off. */
    private static Boolean batchGateActive() {
        return settings().Batch_Release_Mode__c == true && reservationsOpen();
    }

    /** The same gate for the welcome and OTP screens, before any session exists. Safe to expose to the
     *  guest user: a property of the site, not of a person. */
    @AuraEnabled(cacheable=true)
    public static Boolean explorationMode() {
        return !reservationsOpen();
    }

    /* ---------- stage 3: general declaration ---------- */

    /** House Grant takes the Grant undertaking, both loan products the Loan one, anything else the general
     *  text. Public so ADHA_ReservationService stamps Undertaking_Type__c from this same mapping. */
    public static String undertakingTypeFor(String serviceType) {
        if (serviceType == 'House Grant') {
            return 'Grant';
        }
        if (serviceType == 'House Purchase Loan' || serviceType == 'House Purchase Deferred Loan') {
            return 'Loan';
        }
        return 'General Declaration';
    }

    /** Stage 3: the General Declaration, the same text for everyone. Serving the service-specific deed
     *  here showed it twice and served the General Declaration to nobody; stage 4 uses getUndertaking. */
    @AuraEnabled(cacheable=true)
    public static Declaration getDeclaration(String language) {
        Declaration declaration = textFor('General Declaration', language);
        if (declaration == null) {
            throw new AuraHandledException('MSG_GENERIC');
        }
        return declaration;
    }

    /** Stage 4b: the service-specific deed the customer signs. Also the source of Undertaking_Version__c,
     *  which assertVersion checks against this same record, so drift means every render throws. */
    @AuraEnabled(cacheable=true)
    public static Declaration getUndertaking(String language, String serviceType) {
        String undertakingType = undertakingTypeFor(serviceType);
        Declaration undertaking = textFor(undertakingType, language);
        if (undertaking == null && undertakingType != 'General Declaration') {
            // A service type with no deed loaded must still show something enforceable rather than
            // an error the customer cannot act on.
            undertaking = textFor('General Declaration', language);
        }
        if (undertaking == null) {
            throw new AuraHandledException('MSG_GENERIC');
        }
        return undertaking;
    }

    /** Null rather than throwing, so getUndertaking can fall back before deciding to refuse. */
    private static Declaration textFor(String undertakingType, String language) {
        String lang = language == 'ar' ? 'ar' : 'en';
        List<ADHA_Undertaking__mdt> rows = [
            SELECT Body__c, Version__c, Language__c
            FROM ADHA_Undertaking__mdt
            WHERE Undertaking_Type__c = :undertakingType AND Language__c = :lang
            LIMIT 1
        ];
        if (rows.isEmpty()) {
            return null;
        }
        Declaration text = new Declaration();
        text.body = rows[0].Body__c;
        text.version = rows[0].Version__c;
        text.language = rows[0].Language__c;
        // Surfaced so the UI can badge unapproved content rather than presenting it as final.
        text.placeholder = rows[0].Version__c != null && rows[0].Version__c.startsWith('PLACEHOLDER');
        return text;
    }

    @AuraEnabled
    public static Session acceptDeclaration(String token, String language) {
        ADHA_Applicant__c applicant = resolveApplicant(token);
        // Ops is not on the journey: no consent evidence, no stage stamp, session echoed back.
        if (isOps(applicant)) {
            return toSession(applicant);
        }
        String lang = language == 'ar' ? 'ar' : 'en';

        // Resolved from the record, never from the client: this is the consent evidence, and
        // Declaration_Version__c below records exactly which text was accepted.
        Declaration declaration = getDeclaration(lang);

        // Recorded before the update below overwrites it, so the row can say whether this repeated
        // an acceptance ADHA already held or was genuinely new.
        Boolean newEvidence = applicant.Declaration_Accepted__c != true
            || applicant.Declaration_Version__c != declaration.version
            || applicant.Declaration_Language__c != lang;

        // Stamped on EVERY acceptance - field history preserves the old values, and a stamp-once guard
        // recorded repeated consent as nothing. Never during soft launch, when the text can still change.
        if (reservationsOpen(applicant)) {
            applicant.Declaration_Accepted__c = true;
            applicant.Declaration_Accepted_On__c = System.now();
            applicant.Declaration_Version__c = declaration.version;
        }
        // Not evidence: how toSession knows a refresh already read the declaration. Already the hash of
        // the token that authenticated this call, so no re-hashing needed.
        applicant.Declaration_Session_Hash__c = applicant.Session_Token_Hash__c;
        applicant.Declaration_Language__c = lang;
        // A preference, not evidence, so this follows the customer.
        applicant.Preferred_Language__c = lang;
        if (isEarlierStage(applicant.Journey_Stage__c, 'Declaration Accepted')) {
            applicant.Journey_Stage__c = 'Declaration Accepted';
        }
        update applicant;
        // Version and language, logged on every acceptance: a silent re-acceptance is consent with no
        // record of it.
        ADHA_JourneyLog.log(
            applicant.Id, null, ADHA_JourneyLog.DECLARATION_ACCEPTED,
            'Version ' + declaration.version + ' in ' + lang
                + (newEvidence ? '' : ' (re-accepted, unchanged)')
                + (reservationsOpen(applicant) ? '' : ' (soft launch, not recorded as consent)')
        );
        return toSession(applicant);
    }

    /* ---------- stage 4: exploring ---------- */

    /** Separate from getMasterplan because that method is cacheable and cannot do DML. Without this
     *  the daily report's "Exploring units" count cannot be produced at all. */
    @AuraEnabled
    public static void markExploring(String token) {
        ADHA_Applicant__c applicant = resolveApplicant(token);
        // Ops browses the same map but is not on the journey, so no stage stamp.
        if (isOps(applicant)) {
            return;
        }
        if (isEarlierStage(applicant.Journey_Stage__c, 'Exploring')) {
            applicant.Journey_Stage__c = 'Exploring';
            update applicant;
        }
    }

    /** Records which villas the customer actually opened, deliberately without deduplication. The villa
     *  goes on the lookup as well as the description because a report cannot group on a substring. */
    @AuraEnabled
    public static void markUnitExplored(String token, String plotUid) {
        ADHA_Applicant__c applicant = resolveApplicant(token);
        // Ops browsing must not skew ADHA's exploration report.
        if (isOps(applicant) || String.isBlank(plotUid)) {
            return;
        }
        List<ADHA_Unit__c> units = [
            SELECT Id, Plot_UID__c FROM ADHA_Unit__c WHERE Plot_UID__c = :plotUid LIMIT 1
        ];
        if (units.isEmpty()) {
            // An unknown plot is a stale map or a tampered call. Neither is worth failing a browse over.
            return;
        }
        ADHA_JourneyLog.log(
            applicant.Id, null, units[0].Id, ADHA_JourneyLog.VILLA_EXPLORED, 'Villa ' + plotUid
        );
    }

    /* ---------- session ---------- */

    /** Heartbeat; returns 'ok', 'superseded' or 'expired'. touch is true only on real interaction - the
     *  heartbeat itself must never extend the session, or an open tab would keep itself alive forever. */
    @AuraEnabled
    public static String sessionStatus(String token, Boolean touch) {
        if (String.isBlank(token)) {
            return 'expired';
        }
        String hash = hashToken(token);
        List<ADHA_Applicant__c> rows = [
            SELECT Id, Session_Expires_At__c, Session_Hard_Expiry__c
            FROM ADHA_Applicant__c
            WHERE Session_Token_Hash__c = :hash
            LIMIT 1
        ];
        if (rows.isEmpty()) {
            // Not the live token. If it is the one the last login replaced, say so.
            List<ADHA_Applicant__c> prior = [
                SELECT Id FROM ADHA_Applicant__c WHERE Prior_Session_Token_Hash__c = :hash LIMIT 1
            ];
            return prior.isEmpty() ? 'expired' : 'superseded';
        }

        ADHA_Applicant__c applicant = rows[0];
        Datetime now = System.now();
        if (applicant.Session_Expires_At__c == null || applicant.Session_Expires_At__c < now) {
            return 'expired';
        }
        if (applicant.Session_Hard_Expiry__c != null && applicant.Session_Hard_Expiry__c < now) {
            return 'expired';
        }

        if (touch == true) {
            Datetime slide = now.addMinutes(IDLE_MINUTES);
            // Never slide past the hard ceiling.
            if (applicant.Session_Hard_Expiry__c != null && slide > applicant.Session_Hard_Expiry__c) {
                slide = applicant.Session_Hard_Expiry__c;
            }
            update new ADHA_Applicant__c(Id = applicant.Id, Session_Expires_At__c = slide);
        }
        return 'ok';
    }

    /** Ends the session and records why, silently - the caller never waits for the answer. Superseded
     *  must clear NOTHING: the token it carries is the old one, and clearing would kill the live session. */
    @AuraEnabled
    public static void endSession(String token, String reason) {
        if (String.isBlank(token)) {
            return;
        }
        // Never trust the client's word for a picklist value.
        String why = reason == 'Idle timeout' || reason == 'Superseded' ? reason : 'Signed out';
        String hash = hashToken(token);

        List<ADHA_Applicant__c> live = [
            SELECT Id FROM ADHA_Applicant__c WHERE Session_Token_Hash__c = :hash LIMIT 1
        ];

        if (live.isEmpty()) {
            // Either already gone, or the prior token of a session that has since been replaced.
            // Nothing to clear either way - log it against the reservation if there is one.
            List<ADHA_Applicant__c> prior = [
                SELECT Id FROM ADHA_Applicant__c WHERE Prior_Session_Token_Hash__c = :hash LIMIT 1
            ];
            if (!prior.isEmpty()) {
                logSessionEnd(prior[0].Id, why);
            }
            return;
        }

        Id applicantId = live[0].Id;
        ADHA_Applicant__c patch = new ADHA_Applicant__c(Id = applicantId);

        if (why != 'Superseded') {
            // Both hashes: clearing only the live one leaves this token matching the prior hash, so a
            // plain sign-out reads back as 'superseded'.
            patch.Session_Token_Hash__c = null;
            patch.Prior_Session_Token_Hash__c = null;
            patch.Session_Expires_At__c = null;
            patch.Session_Ended_On__c = System.now();
            patch.Session_Ended_Reason__c = why;
            update patch;
        }
        logSessionEnd(applicantId, why);
        if (why == 'Superseded') {
            ADHA_JourneyLog.log(applicantId, null, ADHA_JourneyLog.SESSION_SUPERSEDED, null);
        }
    }

    /** Adds a line to the live reservation's trail so a lapsed hold shows whether the applicant walked
     *  away or their browser died. Best effort - a closed tab may never send the call. */
    private static void logSessionEnd(Id applicantId, String why) {
        List<ADHA_Reservation__c> live = [
            SELECT Id, Journey_Log__c
            FROM ADHA_Reservation__c
            WHERE Applicant__c = :applicantId AND Status__c IN ('Held', 'Submitted', 'Completed')
            LIMIT 1
        ];
        if (live.isEmpty()) {
            return;
        }
        String stamped = System.now().format('yyyy-MM-dd HH:mm:ss') + '  Session ended: ' + why;
        String existing = live[0].Journey_Log__c;
        String combined = String.isBlank(existing) ? stamped : existing + '\n' + stamped;
        if (combined.length() > 130000) {
            combined = combined.substring(combined.length() - 130000);
        }
        update new ADHA_Reservation__c(Id = live[0].Id, Journey_Log__c = combined);
    }

    /** Lets a refresh resume where the customer was instead of restarting the journey. */
    @AuraEnabled
    public static Session resumeSession(String token) {
        Session session = toSession(resolveApplicant(token));
        // Echo the caller's own token back; omitting it silently downgraded a refresh to an
        // unauthenticated view of the whole inventory.
        session.token = token;
        return session;
    }

    /** The single gate every authenticated call goes through. Package-visible so
     *  ADHA_MasterplanController uses exactly the same check rather than a parallel one. */
    public static ADHA_Applicant__c resolveApplicant(String token) {
        if (String.isBlank(token)) {
            throw new AuraHandledException('MSG_SESSION_EXPIRED');
        }
        String hash = hashToken(token);
        List<ADHA_Applicant__c> rows = [
            SELECT Id, Application_Number__c, Customer_Name__c, Masked_Emirates_ID__c, Service_Type__c,
                   Eligible_Categories__c, Approved_Loan_Amount__c, Preferred_Language__c, Journey_Stage__c,
                   First_Verified_Login__c, SLA_Start__c, SLA_End__c, Current_Attempt__c,
                   Declaration_Accepted__c, Declaration_Version__c, Declaration_Language__c,
                   Declaration_Session_Hash__c, Extra_Unit_Changes__c,
                   Emirates_ID__c, Is_Ops__c,
                   // Read by ADHA_ReservationSmsSender on confirm, signature and release. Left out,
                   // every message is skipped and the read itself throws SObjectException.
                   Mobile_Number__c,
                   Session_Token_Hash__c, Session_Expires_At__c, Session_Hard_Expiry__c
            FROM ADHA_Applicant__c
            WHERE Session_Token_Hash__c = :hash
            LIMIT 1
        ];
        Datetime now = System.now();
        if (rows.isEmpty() || rows[0].Session_Expires_At__c == null || rows[0].Session_Expires_At__c < now) {
            throw new AuraHandledException('MSG_SESSION_EXPIRED');
        }
        if (rows[0].Session_Hard_Expiry__c != null && rows[0].Session_Hard_Expiry__c < now) {
            throw new AuraHandledException('MSG_SESSION_EXPIRED');
        }
        return rows[0];
    }

    /* ---------- helpers ---------- */

    private static ADHA_Applicant__c loadApplicant(Id applicantId) {
        List<ADHA_Applicant__c> rows = [
            SELECT Id, Application_Number__c, Customer_Name__c, Masked_Emirates_ID__c, Service_Type__c,
                   Eligible_Categories__c, Approved_Loan_Amount__c, Preferred_Language__c, Journey_Stage__c,
                   First_Verified_Login__c, SLA_Start__c, SLA_End__c, Current_Attempt__c,
                   Declaration_Accepted__c, Declaration_Version__c, Declaration_Language__c,
                   Declaration_Session_Hash__c, Extra_Unit_Changes__c,
                   Emirates_ID__c, Is_Ops__c,
                   // Read by ADHA_ReservationSmsSender on confirm, signature and release. Left out,
                   // every message is skipped and the read itself throws SObjectException.
                   Mobile_Number__c,
                   Session_Token_Hash__c, Session_Expires_At__c, Session_Hard_Expiry__c
            FROM ADHA_Applicant__c
            WHERE Id = :applicantId
            LIMIT 1
        ];
        if (rows.isEmpty()) {
            throw new AuraHandledException('MSG_EID_UNVERIFIED');
        }
        return rows[0];
    }

    private static Session toSession(ADHA_Applicant__c applicant) {
        Session session = new Session();
        session.customerName = applicant.Customer_Name__c;
        session.applicationNumber = applicant.Application_Number__c;
        session.maskedEmiratesId = applicant.Masked_Emirates_ID__c;
        session.serviceType = applicant.Service_Type__c;
        session.language = String.isBlank(applicant.Preferred_Language__c) ? 'ar' : applicant.Preferred_Language__c;
        session.journeyStage = applicant.Journey_Stage__c;
        // Per session, not per applicant: true only for the session that accepted it. A refresh
        // matches; a fresh login has a new hash and does not.
        session.declarationAccepted =
            String.isNotBlank(applicant.Declaration_Session_Hash__c) &&
            applicant.Declaration_Session_Hash__c == applicant.Session_Token_Hash__c;
        session.slaEnd = applicant.SLA_End__c;
        session.attempt = applicant.Current_Attempt__c == null ? 1 : Integer.valueOf(applicant.Current_Attempt__c);
        session.approvedLoanAmount = applicant.Approved_Loan_Amount__c;
        session.slaStart = applicant.SLA_Start__c;
        Decimal configured = settings().Max_Attempts__c;
        session.maxAttempts = configured == null ? 2 : Integer.valueOf(configured);
        session.reservationsOpen = reservationsOpen(applicant);
        session.reservationRefusal = ADHA_ReservationService.windowRefusal(applicant);
        session.unitChangesRemaining = ADHA_ReservationService.unitChangesRemaining(applicant);
        session.unitChangesAllowed = ADHA_ReservationService.unitChangesAllowed(applicant);
        session.signingEnabled = settings().Signing_Enabled__c == true;
        session.isOps = isOps(applicant);
        if (!session.isOps) {
            session.pinnedPlotUid = pinnedPlotUidFor(applicant.Id);
        }
        if (applicant.SLA_End__c != null) {
            Long ms = applicant.SLA_End__c.getTime() - System.now().getTime();
            // Ceiling, so the final partial day still reads as "1 day left" rather than zero.
            session.daysRemaining = ms <= 0 ? 0 : Integer.valueOf(Math.ceil(ms / 86400000.0));
        }
        return session;
    }

    /** Stage order mirrors the journey document, so a later stage is never overwritten by an earlier one
     *  when a customer navigates backwards. */
    private static final List<String> STAGE_ORDER = new List<String>{
        'Invited', 'Logged In', 'Declaration Accepted', 'Exploring', 'Unit Selected',
        'Confirmed', 'DocuSign Pending', 'Completed', 'Expired'
    };

    public static Boolean isEarlierStage(String current, String candidate) {
        if (String.isBlank(current)) {
            return true;
        }
        Integer a = STAGE_ORDER.indexOf(current);
        Integer b = STAGE_ORDER.indexOf(candidate);
        return a < 0 || a < b;
    }

    /** One settings read per transaction; every caller carries its own default. TestVisible because
     *  custom metadata cannot be inserted in a test, so the bypass gate needs this set directly. */
    @TestVisible
    private static ADHA_Setting__mdt settingsCache;

    public static ADHA_Setting__mdt settings() {
        if (settingsCache == null) {
            // Every field is named here, so one left out reads as null forever.
            List<ADHA_Setting__mdt> rows = [
                SELECT SLA_Days__c, Max_Attempts__c, Additional_Payment_Months__c,
                       OTP_TTL_Minutes__c, OTP_Max_Attempts__c, Selectable_Statuses__c,
                       Hold_Minutes__c, Dev_Skip_OTP__c, Dev_Skip_OTP_Org_Id__c,
                       Exploration_Mode__c, Batch_Release_Mode__c, Max_Unit_Changes__c,
                       Signing_Enabled__c, Signing_Is_Production__c, Docusign_Config_Name__c,
                       Signer_Email_Domain__c, Signing_Allowed_Emirates_Ids__c,
                       Signing_Return_Base_Url__c, Signing_Provider__c,
                       Payment_Release_Enabled__c, Confirmation_SMS_Enabled__c,
                       Invitation_SMS_Enabled__c, Ops_Emirates_Ids__c,
                       Exploration_Bypass_Emirates_Ids__c,
                       Availability_Poll_Seconds__c, Signing_Session_Minutes__c
                FROM ADHA_Setting__mdt
                WHERE DeveloperName = 'Default'
                LIMIT 1
            ];
            settingsCache = rows.isEmpty() ? new ADHA_Setting__mdt() : rows[0];
        }
        return settingsCache;
    }

    public static Integer slaDays() {
        Decimal d = settings().SLA_Days__c;
        return d == null ? 7 : Integer.valueOf(d);
    }

    @TestVisible
    private static String normaliseEmiratesId(String value) {
        // Stored with separators; customers type them inconsistently, so compare on digits only.
        if (String.isBlank(value)) {
            return null;
        }
        String digits = value.replaceAll('[^0-9]', '');
        if (digits.length() != 15) {
            return value.trim();
        }
        return digits.substring(0, 3) + '-' + digits.substring(3, 7) + '-' + digits.substring(7, 14) + '-' + digits.substring(14);
    }

    private static String newToken() {
        return EncodingUtil.convertToHex(Crypto.generateAesKey(256));
    }

    private static String hashToken(String token) {
        return EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', Blob.valueOf(token)));
    }
}