/**
 * Shared EOI processing for public microsites: identity capture into the
 * EOI_Public_Registration__c staging object. Runs without sharing because
 * site guests own no records; bot and input validation happen here so every
 * per-site controller stays thin.
 * PAL-P5 (10 Sep 2026): the in-session receipt path passes the EOI phase's
 * EntityName__c into the shared builder. Fusion resolves the remittance bank account
 * from the entity and rejects a receipt that arrives without one.
 * VAPT EXT-03 (13 Sep 2026): getPaymentState requires the tab's session id (ownsRegistration).
 * MEOI-CAPTCHA5 (13 Sep 2026): reCAPTCHA diagnostics are queued (deferredLogs) and written by
 * flushDeferredLogs() after the transaction's callouts - a log insert before the Checkout call had
 * broken every site payment (SCW-098).
 * MEOI-STATUS (13 Sep 2026): closed payments on the site read the Checkout Payment Console's
 * Dashboard_Status__c and carry no note under the status (toCard).
 * MEOI-AUTHEXP (12 Sep 2026): Authorization Expired, the new Checkout status for a hold that
 * ran out on its own, counts as a failed payment here exactly as Expired does, and the note the
 * customer reads still says the hold expired and was released.
 * MEOI-RECOVER (22 Sep 2026): that is now true only once recovery has given up. A lapsed hold is
 * retried for two days (CheckoutHoldRenewalQueueable, which has no channel filter and so reaches
 * site rows too), and while Recovery_Alert_Sent__c is false the payment still counts as settled.
 * @author Aurelix
 */
public without sharing class EOIService {

    /** Identity-step payload from the site UI. */
    public class IdentityRequest {
        @AuraEnabled public String customerType   { get; set; }  // Individual | Organization
        @AuraEnabled public String residentStatus { get; set; }  // Resident | Non-Resident
        @AuraEnabled public String firstName      { get; set; }
        @AuraEnabled public String lastName       { get; set; }
        @AuraEnabled public String email          { get; set; }
        @AuraEnabled public String mobile         { get; set; }
        @AuraEnabled public String passportNumber { get; set; }
        @AuraEnabled public String emiratesId     { get; set; }  // MEOI-01, manual resident path
        @AuraEnabled public String companyName    { get; set; }
        @AuraEnabled public String tradeLicenseNumber { get; set; }
        @AuraEnabled public Date tradeLicenseExpiryDate { get; set; }
        @AuraEnabled public String registeredEmail { get; set; }
        @AuraEnabled public String registeredPhone { get; set; }
        @AuraEnabled public String authorizedFirstName { get; set; }
        @AuraEnabled public String authorizedLastName  { get; set; }
        @AuraEnabled public String authorizedEmail     { get; set; }
        @AuraEnabled public String authorizedPhone     { get; set; }
        @AuraEnabled public String honeypot       { get; set; }
        @AuraEnabled public String userAgent      { get; set; }
        @AuraEnabled public String locale         { get; set; }
        @AuraEnabled public String deviceId       { get; set; }  // browser id, kept on the registration
        @AuraEnabled public String sessionId      { get; set; }
    }

    /* MEOI-CFG. Runtime site configuration.
       WHY THIS EXISTS AT ALL: the three EOI_Site_* switches were first read in the LWC
       via @salesforce/label imports. Those are resolved when the LWC bundle is COMPILED,
       and the bundle is rebuilt only when the Experience site is published - so editing a
       label in Setup did NOT change the running page until both sites were republished.
       Measured, not assumed, on 8 Sep 2026.
       Apex reads System.Label at RUNTIME, so reading the switches here and handing them to
       the client makes a Setup edit take effect on the next page load, with no publish.
       That matters most for EOI_Site_Payment_Mode, which is the switch someone would flip
       under pressure if the embedded form starts failing. */
    public class SiteConfig {
        @AuraEnabled public Boolean uaePassEnabled { get; set; }
        @AuraEnabled public Boolean refundEnabled  { get; set; }
        @AuraEnabled public String  paymentMode    { get; set; }
        @AuraEnabled public Boolean siteClosed     { get; set; } // MEOI-CLOSED: whole journey replaced
        @AuraEnabled public Boolean thankYouEnabled { get; set; } // MEOI-THANKS: last payment -> thank-you page
        @AuraEnabled public Boolean activityEnabled { get; set; }  // MEOI-ACT: field-level activity diary on/off
        @AuraEnabled public Integer activityFlushSeconds { get; set; } // MEOI-ACT: client flush interval
        @AuraEnabled public Boolean recaptchaEnabled { get; set; }     // MEOI-CAPTCHA: v3 token required on sign-in / payment start
    }

    /** Never throws: a mistyped or blank switch must not take the site down. Every
     *  fallback is today's behaviour - UAE Pass on, refund hidden, embedded payment. */
    public static SiteConfig getSiteConfig() {
        SiteConfig c = new SiteConfig();
        c.uaePassEnabled = true;
        c.refundEnabled = false;
        c.paymentMode = 'Embedded';
        c.siteClosed = false;
        c.thankYouEnabled = false;
        try {
            c.uaePassEnabled = System.Label.EOI_Site_UAE_Pass_Enabled.trim() == 'true';
            c.refundEnabled = System.Label.EOI_Site_Refund_Enabled.trim() == 'true';
            String mode = System.Label.EOI_Site_Payment_Mode.trim();
            c.paymentMode = mode.equalsIgnoreCase('Hosted') ? 'Hosted' : 'Embedded';
        } catch (Exception e) {
            // keep the defaults above
        }
        // each newer switch is read on its own so one missing label cannot take the others down
        try {
            c.siteClosed = System.Label.EOI_Site_Closed.trim() == 'true';
        } catch (Exception e) {
            // keep the default above
        }
        try {
            c.thankYouEnabled = System.Label.EOI_Site_Thank_You_Enabled.trim() == 'true';
        } catch (Exception e) {
            // keep the defaults above
        }
        c.activityEnabled = EoiSiteActivityService.enabled();
        c.activityFlushSeconds = EoiSiteActivityService.flushSeconds();
        c.recaptchaEnabled = recaptchaEnabled();
        return c;
    }

    // ---------- MEOI-CAPTCHA (11 Sep 2026): Google reCAPTCHA v3 on the guest entry points ----------
    /* The page obtains a token from the EOIRecaptchaFrame bridge and sends it with the sign-in
       and payment-start calls; this verifies it with Google through the "reCAPTCHA API" named
       credential, whose external credential holds the secret (never in code, never read by
       Apex). Switch: label EOI_Site_Recaptcha_Enabled - off is today's behaviour. On: a missing,
       failed or low-scoring token is refused; Google being unreachable, or the secret not yet
       entered on the credential, is logged and let through - our own outage or configuration
       gap must never lock customers out, while a bot cannot simply omit the token. */
    @TestVisible private static Boolean recaptchaEnabledOverride;
    @TestVisible private static Decimal recaptchaMinScoreOverride;

    /** MEOI-CAPTCHA5 (13 Sep 2026). Diagnostics raised while verifying a reCAPTCHA token are queued
     *  here and written by flushDeferredLogs() only after the transaction's callouts. Until 13 Sep the
     *  fail-open branch inserted its Logger__c row at once, and that DML made every later callout in
     *  the same transaction fail ("uncommitted work pending") - so a reCAPTCHA misconfiguration or a
     *  Google outage took the Checkout session, and with it every card payment, down (SCW-098). */
    @TestVisible private static List<Logger__c> deferredLogs = new List<Logger__c>();

    /** Writes the queued reCAPTCHA diagnostics. Call after the last callout of the transaction; never
     *  before one. Safe to call when nothing is queued; never throws. */
    public static void flushDeferredLogs() {
        if (deferredLogs.isEmpty()) {
            return;
        }
        List<Logger__c> toSave = new List<Logger__c>(deferredLogs);
        deferredLogs.clear();
        try {
            LoggerService.save(toSave);
        } catch (Exception e) {
            // diagnostics never take down the journey
        }
    }
    public static final String RECAPTCHA_MESSAGE = 'The security check did not pass. Please try again.';

    public static Boolean recaptchaEnabled() {
        if (recaptchaEnabledOverride != null) {
            return recaptchaEnabledOverride;
        }
        /* MEOI-CAPTCHA-TEST (12 Sep 2026): tests decide the switch through the override; without one
           they run as if reCAPTCHA were off, so the org's label value (true in BPDev since 11 Sep
           evening) cannot fail the sign-in and payment tests that pass no token. */
        if (Test.isRunningTest()) {
            return false;
        }
        try {
            return System.Label.EOI_Site_Recaptcha_Enabled.trim() == 'true';
        } catch (Exception e) {
            return false;
        }
    }

    private static Decimal recaptchaMinScore() {
        if (recaptchaMinScoreOverride != null) {
            return recaptchaMinScoreOverride;
        }
        try {
            return Decimal.valueOf(System.Label.EOI_Site_Recaptcha_Min_Score.trim());
        } catch (Exception e) {
            return 0.5;
        }
    }

    public static void verifyRecaptcha(String token, String expectedAction) {
        if (!recaptchaEnabled()) {
            return;
        }
        if (String.isBlank(token)) {
            throw new EOIServiceException(RECAPTCHA_MESSAGE);
        }
        Map<String, Object> body;
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:Recaptcha_API');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            req.setTimeout(10000);
            req.setBody('secret={!$Credential.Recaptcha_Cred.Secret}&response=' + EncodingUtil.urlEncode(token, 'UTF-8'));
            HttpResponse res = new Http().send(req);
            body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        } catch (Exception e) {
            // queued, not written: a Logger__c insert here would block the Checkout callout that follows (SCW-098)
            deferredLogs.add(LoggerService.createApexLog(e, 'EOI Site reCAPTCHA', 'EOIService', 'verifyRecaptcha'));
            return; // Google unreachable or the credential misconfigured: never our customers' problem
        }
        if (body == null) {
            return;
        }
        List<Object> codes = (List<Object>) body.get('error-codes');
        if (codes != null && (codes.contains('invalid-input-secret') || codes.contains('missing-input-secret'))) {
            deferredLogs.add(LoggerService.createApexLog(
                new EOIServiceException('reCAPTCHA secret missing or invalid on External Credential reCAPTCHA Cred'),
                'EOI Site reCAPTCHA', 'EOIService', 'verifyRecaptcha'));
            return;
        }
        Boolean success = body.get('success') == true;
        Decimal score = body.get('score') == null ? null : Decimal.valueOf(String.valueOf(body.get('score')));
        String action = (String) body.get('action');
        Boolean actionMismatch = String.isNotBlank(expectedAction) && String.isNotBlank(action) && action != expectedAction;
        if (!success || (score != null && score < recaptchaMinScore()) || actionMismatch) {
            throw new EOIServiceException(RECAPTCHA_MESSAGE);
        }
    }

    public class EOIServiceException extends Exception {}

    private static final Pattern EMAIL_RE = Pattern.compile('^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$');

    /** Non-resident and organization identity submit. Returns the staging record id. */
    public static Id submitIdentity(IdentityRequest req, String source) {
        if (req == null) {
            throw new EOIServiceException('Missing request.');
        }
        if (String.isNotBlank(req.honeypot)) {
            // bots fill the invisible field; fail closed but quietly
            throw new EOIServiceException('Submission rejected.');
        }
        EOI_Public_Registration__c row = new EOI_Public_Registration__c(
            Status__c = 'New',
            Source__c = source,
            SubmittedAt__c = Datetime.now(),
            UserAgent__c = truncate(req.userAgent, 255),
            Locale__c = normalizeLocale(req.locale)
        );
        applyIdentity(row, req);
        insert row;
        return row.Id;
    }

    /** Validates the form and maps it onto the row. Shared by the form-first and sign-in-first paths. */
    private static void applyIdentity(EOI_Public_Registration__c row, IdentityRequest req) {
        if (req.customerType == 'Organization') {
            requireBlankless(new Map<String, String>{
                'Company name' => req.companyName,
                'Trade licence number' => req.tradeLicenseNumber,
                'Registered email' => req.registeredEmail,
                'Registered phone' => req.registeredPhone,
                'Signatory first name' => req.authorizedFirstName,
                'Signatory last name' => req.authorizedLastName,
                'Signatory email' => req.authorizedEmail,
                'Signatory phone' => req.authorizedPhone
            });
            requireEmail(req.registeredEmail);
            requireEmail(req.authorizedEmail);
            row.CustomerType__c = 'Organization';
            row.CompanyName__c = req.companyName;
            row.TradeLicenseNumber__c = req.tradeLicenseNumber;
            row.TradeLicenseExpiryDate__c = req.tradeLicenseExpiryDate;
            row.RegisteredEmail__c = req.registeredEmail.trim();
            row.RegisteredPhone__c = phone(req.registeredPhone);
            row.AuthorizedFirstName__c = req.authorizedFirstName;
            row.AuthorizedLastName__c = req.authorizedLastName;
            row.AuthorizedEmail__c = req.authorizedEmail.trim();
            row.AuthorizedPhone__c = phone(req.authorizedPhone);
        } else if (req.customerType == 'Individual') {
            /* MEOI-01. Two individual routes now reach this method. Until UAE Pass could
               be switched off, every form individual was a non-resident by construction,
               so the status and the passport requirement were hardcoded. With
               EOI_Site_UAE_Pass_Enabled off, a UAE resident registers here too and
               carries an Emirates ID instead of a passport.
               The residentStatus field already existed on this DTO and was simply unused.
               Anything other than an explicit 'Resident' keeps the previous behaviour, so
               an older client that omits the field is unaffected. */
            Boolean isResident = req.residentStatus == 'Resident';
            requireBlankless(new Map<String, String>{
                'First name' => req.firstName,
                'Last name' => req.lastName,
                'Email' => req.email,
                'Mobile' => req.mobile,
                (isResident ? 'Emirates ID' : 'Passport number')
                    => (isResident ? req.emiratesId : req.passportNumber)
            });
            requireEmail(req.email);
            row.CustomerType__c = 'Individual';
            row.ResidentStatus__c = isResident ? 'Resident' : 'Non Resident';
            row.FirstName__c = req.firstName;
            row.LastName__c = req.lastName;
            row.Email__c = req.email.trim();
            row.Mobile__c = phone(req.mobile);
            if (isResident) {
                // same normaliser the UAE Pass callback uses, so both routes store one shape
                row.EmiratesId__c = formatEmiratesId(req.emiratesId);
            } else {
                row.PassportNumber__c = req.passportNumber;
            }
        } else {
            throw new EOIServiceException('Unknown customer type.');
        }
    }

    /** UAE Pass verified resident: identity comes from the sovereign profile, already verified.
     *  Repeat sign-ins update the existing open row for the same UUID instead of inserting again;
     *  promoted/closed rows are never mutated. */
    public static Id saveUaePassIdentity(UAEPassUserInfo u, String source, String userAgent, String locale) {
        if (u == null || String.isBlank(u.uuid)) {
            throw new EOIServiceException('Missing UAE Pass profile.');
        }
        EOI_Public_Registration__c row = new EOI_Public_Registration__c(
            Status__c = 'Verified',
            Source__c = source,
            CustomerType__c = 'Individual',
            ResidentStatus__c = 'Resident',
            FirstName__c = u.firstNameEn,
            LastName__c = u.lastNameEn,
            Email__c = u.email,
            Mobile__c = formatUaePassMobile(u.mobile),
            EmiratesId__c = formatEmiratesId(u.emiratesId),
            UAE_Pass_UUID__c = u.uuid,
            VerifiedChannel__c = 'UAEPass',
            VerifiedAt__c = Datetime.now(),
            SubmittedAt__c = Datetime.now(),
            UserAgent__c = truncate(userAgent, 255),
            Locale__c = normalizeLocale(locale)
        );
        List<EOI_Public_Registration__c> existing = [
            SELECT Id FROM EOI_Public_Registration__c
            WHERE UAE_Pass_UUID__c = :u.uuid AND Source__c = :source AND Status__c IN ('New', 'Verified')
              AND BatchId__c = null AND EOI_Range__c = null
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        if (!existing.isEmpty()) {
            row.Id = existing[0].Id;
            update row;
        } else {
            insert row;
        }
        recordVerified(row, 'UAE Pass', u.uuid, u, 'Emirates ID ' + maskEid(u.emiratesId));
        return row.Id;
    }

    private static String maskEid(String eid) {
        if (String.isBlank(eid) || eid.length() < 7) {
            return eid;
        }
        return eid.substring(0, 3) + '*********' + eid.substring(eid.length() - 3);
    }

    // ---------- sign-in first (MSC-247): the code is proven before the form ----------

    public class SignInStart {
        @AuraEnabled public Id registrationId { get; set; }
        @AuraEnabled public String sessionId  { get; set; }  // this tab's proof; needed to finish the form
        @AuraEnabled public VerificationService.VerificationResult otp { get; set; }
    }

    public class SignInState {
        @AuraEnabled public Boolean exists      { get; set; }
        @AuraEnabled public String status       { get; set; }
        @AuraEnabled public Boolean signedIn    { get; set; }
        @AuraEnabled public String channel      { get; set; }  // Email | SMS, sign-in rows only
        @AuraEnabled public String maskedTarget { get; set; }
        @AuraEnabled public String target       { get; set; }  // only for the tab holding the session id
        @AuraEnabled public Prefill prefill     { get; set; }  // returning person: their last completed details
    }

    /** The person's own previous registration, offered back as an editable starting point. */
    public class Prefill {
        @AuraEnabled public String greetName          { get; set; }
        @AuraEnabled public String customerType       { get; set; }
        @AuraEnabled public String residentStatus     { get; set; }
        @AuraEnabled public String firstName          { get; set; }
        @AuraEnabled public String lastName           { get; set; }
        @AuraEnabled public String email              { get; set; }
        @AuraEnabled public String mobile             { get; set; }
        @AuraEnabled public String emiratesId         { get; set; }
        @AuraEnabled public String passportNumber     { get; set; }
        @AuraEnabled public String companyName        { get; set; }
        @AuraEnabled public String tradeLicenseNumber { get; set; }
        @AuraEnabled public Date tradeLicenseExpiryDate { get; set; }
        @AuraEnabled public String registeredEmail    { get; set; }
        @AuraEnabled public String registeredPhone    { get; set; }
        @AuraEnabled public String authorizedFirstName { get; set; }
        @AuraEnabled public String authorizedLastName  { get; set; }
        @AuraEnabled public String authorizedEmail     { get; set; }
        @AuraEnabled public String authorizedPhone     { get; set; }
        @AuraEnabled public Boolean crmMatched         { get; set; }  // already a customer in Salesforce
    }

    private static final Integer SIGN_IN_SENDS_PER_10_MIN = 5;

    /** Creates the sign-in row holding only the identifier, then sends the code.
     *  A send failure throws, so the row is rolled back with it. One row per sign-in, never reused.
     *  The session id marks a sign-in row; form-first rows never carry one. */
    public static SignInStart beginSignIn(String channel, String target, String honeypot, String source,
            String userAgent, String locale) {
        return beginSignIn(channel, target, honeypot, source, userAgent, locale, null);
    }

    /** MEOI-CAPTCHA: the page's reCAPTCHA token rides along; verified only when the switch is on. */
    public static SignInStart beginSignIn(String channel, String target, String honeypot, String source,
            String userAgent, String locale, String recaptchaToken) {
        if (String.isNotBlank(honeypot)) {
            throw new EOIServiceException('Submission rejected.');
        }
        verifyRecaptcha(recaptchaToken, 'eoi_sign_in');
        if (channel != 'Email' && channel != 'SMS') {
            throw new EOIServiceException('Unknown verification channel.');
        }
        String value;
        if (channel == 'Email') {
            requireEmail(target);
            value = target.trim();
        } else {
            value = phone(target);
        }
        Datetime since = Datetime.now().addMinutes(-10);
        Integer sends = [
            SELECT COUNT() FROM Verification_Request__c
            WHERE Target__c = :value AND Context__c = :OTP_CONTEXT AND CreatedDate >= :since
        ];
        if (sends >= SIGN_IN_SENDS_PER_10_MIN) {
            throw new EOIServiceException('Too many codes were requested for this '
                + (channel == 'Email' ? 'email' : 'number') + '. Please try again in a few minutes.');
        }
        EOI_Public_Registration__c row = new EOI_Public_Registration__c(
            Status__c = 'New',
            Source__c = source,
            Session_Id__c = EncodingUtil.convertToHex(Crypto.generateAesKey(128)),
            UserAgent__c = truncate(userAgent, 255),
            Locale__c = normalizeLocale(locale)
        );
        if (channel == 'Email') {
            row.Email__c = value;
        } else {
            row.Mobile__c = value;
        }
        insert row;
        SignInStart out = new SignInStart();
        out.registrationId = row.Id;
        out.sessionId = row.Session_Id__c;
        out.otp = startOtp(row.Id, channel);
        flushDeferredLogs(); // MEOI-CAPTCHA5: after the OTP send, which may itself call out
        return out;
    }

    /** The form after a sign-in. The verified identifier comes from the row, never from the client. */
    public static Id completeDetails(Id registrationId, String sessionId, IdentityRequest req) {
        if (req == null) {
            throw new EOIServiceException('Missing request.');
        }
        if (String.isNotBlank(req.honeypot)) {
            throw new EOIServiceException('Submission rejected.');
        }
        if (registrationId == null || String.isBlank(sessionId)) {
            throw new EOIServiceException('Please verify your email or mobile first.');
        }
        List<EOI_Public_Registration__c> rows = [
            SELECT Id, Source__c, Visitor__c, Email__c, Mobile__c, VerifiedChannel__c
            FROM EOI_Public_Registration__c
            WHERE Id = :registrationId AND Session_Id__c = :sessionId AND Status__c = 'New'
              AND VerifiedAt__c != null AND VerifiedChannel__c IN ('Email', 'SMS')
            LIMIT 1
            FOR UPDATE
        ];
        if (rows.isEmpty()) {
            throw new EOIServiceException('Please verify your email or mobile first.');
        }
        EOI_Public_Registration__c row = rows[0];
        Boolean byEmail = row.VerifiedChannel__c == 'Email';
        String proven = byEmail ? row.Email__c : row.Mobile__c;
        /* A person already registered with us keeps the type they registered with: their
           earlier visit is tied to a customer record, and a second type would split it. */
        Prefill before = previousDetails(row.Visitor__c, row.Id, byEmail, proven);
        if (before != null && String.isNotBlank(before.customerType) && before.customerType != req.customerType) {
            throw new EOIServiceException('You are already registered with us as '
                + (before.customerType == 'Organization' ? 'an organisation' : 'an individual')
                + '. Please continue with that registration type.');
        }
        if (req.customerType == 'Organization') {
            if (byEmail) {
                req.registeredEmail = proven;
            } else {
                req.registeredPhone = proven;
            }
        } else {
            if (byEmail) {
                req.email = proven;
            } else {
                req.mobile = proven;
            }
        }
        applyIdentity(row, req);
        if (row.CustomerType__c == 'Organization') {
            // the proven value lives in the organisation columns, as it does today
            if (byEmail) {
                row.Email__c = null;
            } else {
                row.Mobile__c = null;
            }
        }
        row.Status__c = 'Verified';
        row.SubmittedAt__c = Datetime.now();
        row.Device_Id__c = truncate(req.deviceId, 36);
        row.UserAgent__c = truncate(req.userAgent, 255);
        row.Locale__c = normalizeLocale(req.locale);
        update row;
        recordDetails(row);
        return row.Id;
    }

    /** Reload support for the sign-in steps. The raw identifier goes only to the tab holding the session id. */
    /** VAPT EXT-03: true only when `sessionId` is the session `beginSignIn` issued for this registration
     *  and the registration has been verified. A blank stored session (a row not created by sign-in)
     *  never matches. */
    public static Boolean ownsRegistration(Id registrationId, String sessionId) {
        if (registrationId == null || String.isBlank(sessionId)) {
            return false;
        }
        for (EOI_Public_Registration__c r : [
            SELECT Session_Id__c, VerifiedAt__c FROM EOI_Public_Registration__c WHERE Id = :registrationId LIMIT 1
        ]) {
            return String.isNotBlank(r.Session_Id__c) && r.Session_Id__c == sessionId && r.VerifiedAt__c != null;
        }
        return false;
    }

    public static SignInState getSignInState(Id registrationId, String sessionId) {
        SignInState s = new SignInState();
        s.exists = false;
        s.signedIn = false;
        if (registrationId == null) {
            return s;
        }
        List<EOI_Public_Registration__c> rows = [
            SELECT Status__c, Email__c, Mobile__c, VerifiedAt__c, Session_Id__c, Visitor__c,
                   Visitor__r.Matched_Contact__c, Visitor__r.Matched_Account__c, Visitor__r.Matched_Lead__c
            FROM EOI_Public_Registration__c WHERE Id = :registrationId LIMIT 1
        ];
        if (rows.isEmpty()) {
            return s;
        }
        EOI_Public_Registration__c r = rows[0];
        s.exists = true;
        s.status = r.Status__c;
        s.signedIn = r.VerifiedAt__c != null;
        if (r.Status__c != 'New' || String.isBlank(r.Session_Id__c)) {
            return s; // form-first (no session id) or already complete: nothing more to say
        }
        Boolean byEmail = String.isNotBlank(r.Email__c);
        String value = byEmail ? r.Email__c : r.Mobile__c;
        s.channel = byEmail ? 'Email' : 'SMS';
        s.maskedTarget = byEmail ? maskEmail(value) : maskPhone(value);
        if (s.signedIn && String.isNotBlank(sessionId) && sessionId == r.Session_Id__c) {
            s.target = value;
            s.prefill = previousDetails(r.Visitor__c, registrationId, byEmail, value);
            if (s.prefill != null) {
                s.prefill.crmMatched = r.Visitor__r != null
                    && (r.Visitor__r.Matched_Contact__c != null || r.Visitor__r.Matched_Account__c != null);
            }
        }
        return s;
    }

    /** Latest completed registration of the same visitor that carries the identifier just
     *  proven. The channel that proved that earlier visit does not matter: someone who
     *  verified by mobile last time and by email today is the same person, which is the
     *  rule the visitor match itself uses. */
    private static Prefill previousDetails(Id visitorId, Id currentId, Boolean byEmail, String value) {
        if (String.isBlank(value)) {
            return null;
        }
        /* Candidates: this visitor's own earlier visits, and any verified registration
           carrying the identifier just proven - including one written before the visitor
           object existed, or on the other microsite. Every candidate is filtered again
           below, so only a registration that actually carries the identifier is used. */
        Set<String> statuses = new Set<String>{ 'Verified', 'Promoted', 'PromoteFailed' };
        List<String> clauses = new List<String>();
        if (visitorId != null) {
            clauses.add('Visitor__c = :visitorId');
        }
        clauses.add(byEmail ? 'Email__c = :value' : 'Mobile__c = :value');
        clauses.add(byEmail ? 'RegisteredEmail__c = :value' : 'RegisteredPhone__c = :value');
        String soql = 'SELECT CustomerType__c, ResidentStatus__c, FirstName__c, LastName__c, Email__c, Mobile__c, '
            + 'EmiratesId__c, PassportNumber__c, CompanyName__c, TradeLicenseNumber__c, '
            + 'TradeLicenseExpiryDate__c, RegisteredEmail__c, RegisteredPhone__c, '
            + 'AuthorizedFirstName__c, AuthorizedLastName__c, AuthorizedEmail__c, AuthorizedPhone__c '
            + 'FROM EOI_Public_Registration__c '
            + 'WHERE Id != :currentId AND VerifiedAt__c != null AND Status__c IN :statuses '
            + 'AND (' + String.join(clauses, ' OR ') + ') '
            + 'ORDER BY VerifiedAt__c DESC LIMIT 25';
        for (EOI_Public_Registration__c p : Database.query(soql)) {
            if (!carriesIdentifier(p, byEmail, value)) {
                continue;
            }
            Prefill f = new Prefill();
            f.customerType = p.CustomerType__c;
            f.residentStatus = p.ResidentStatus__c;
            f.firstName = p.FirstName__c;
            f.lastName = p.LastName__c;
            f.email = p.Email__c;
            f.mobile = p.Mobile__c;
            f.emiratesId = p.EmiratesId__c;
            f.passportNumber = p.PassportNumber__c;
            f.companyName = p.CompanyName__c;
            f.tradeLicenseNumber = p.TradeLicenseNumber__c;
            f.tradeLicenseExpiryDate = p.TradeLicenseExpiryDate__c;
            f.registeredEmail = p.RegisteredEmail__c;
            f.registeredPhone = p.RegisteredPhone__c;
            f.authorizedFirstName = p.AuthorizedFirstName__c;
            f.authorizedLastName = p.AuthorizedLastName__c;
            f.authorizedEmail = p.AuthorizedEmail__c;
            f.authorizedPhone = p.AuthorizedPhone__c;
            f.greetName = p.CustomerType__c == 'Organization' ? p.AuthorizedFirstName__c : p.FirstName__c;
            return f;
        }
        return null;
    }

    private static Boolean carriesIdentifier(EOI_Public_Registration__c p, Boolean byEmail, String value) {
        if (byEmail) {
            return sameText(p.Email__c, value) || sameText(p.RegisteredEmail__c, value);
        }
        return samePhone(p.Mobile__c, value) || samePhone(p.RegisteredPhone__c, value);
    }

    private static Boolean sameText(String a, String b) {
        return a != null && b != null && a.trim().equalsIgnoreCase(b.trim());
    }

    /** Numbers are compared on their digits: the same mobile is stored with and without spaces. */
    private static Boolean samePhone(String a, String b) {
        if (String.isBlank(a) || String.isBlank(b)) {
            return false;
        }
        return a.replaceAll('[^0-9]', '') == b.replaceAll('[^0-9]', '');
    }

    /** Details submitted milestone. Never throws. */
    private static void recordDetails(EOI_Public_Registration__c row) {
        if (row.Visitor__c == null) {
            return;
        }
        try {
            String summary = detailsSummary(row.Id);
            EoiJourneyLog.log(row.Visitor__c, row.Id, row.Source__c, EoiJourneyLog.DETAILS_SUBMITTED, summary);
            EoiSiteVisitorService.appendTrail(row.Visitor__c, 'Details submitted  ' + summary);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Details milestone failed: ' + e.getMessage());
        }
    }

    private static String maskEmail(String email) {
        List<String> parts = (email == null ? '' : email).split('@');
        if (parts.size() != 2 || parts[0].length() == 0) {
            return '***';
        }
        return parts[0].substring(0, Math.min(2, parts[0].length())) + '***@' + parts[1];
    }

    private static String maskPhone(String phone) {
        String d = phone == null ? '' : phone.replaceAll('[^0-9]', '');
        return d.length() > 4 ? '****' + d.substring(d.length() - 4) : '****';
    }

    // ---------- OTP (wraps the shared VerificationService; EOI_HOME config, our own contextKey) ----------

    private static final String OTP_CONTEXT = 'EOI_HOME';

    public static VerificationService.VerificationResult startOtp(Id registrationId, String channel) {
        if (channel != 'Email' && channel != 'SMS') {
            throw new EOIServiceException('Unknown verification channel.');
        }
        EOI_Public_Registration__c row = loadOpenRow(registrationId);
        String target;
        if (channel == 'Email') {
            target = row.CustomerType__c == 'Organization' ? row.RegisteredEmail__c : row.Email__c;
        } else {
            target = row.CustomerType__c == 'Organization' ? row.RegisteredPhone__c : row.Mobile__c;
        }
        if (String.isBlank(target)) {
            throw new EOIServiceException('No ' + channel + ' on record for this registration.');
        }
        VerificationService.VerificationStartRequest req = new VerificationService.VerificationStartRequest();
        req.channel = channel;
        req.target = target;
        req.context = OTP_CONTEXT;
        req.contextKey = String.valueOf(registrationId);
        VerificationService.VerificationResult res = VerificationService.startVerification(req);
        row.VerificationRequest__c = res.verificationRequestId;
        update row;
        return res;
    }

    public static VerificationService.VerificationResult resendOtp(Id registrationId, Id verificationRequestId) {
        assertRequestBelongs(loadOpenRow(registrationId), verificationRequestId);
        return VerificationService.resendVerification(verificationRequestId);
    }

    public static VerificationService.VerificationResult verifyOtp(Id registrationId, Id verificationRequestId, String code) {
        EOI_Public_Registration__c row = loadOpenRow(registrationId);
        assertRequestBelongs(row, verificationRequestId);
        VerificationService.VerificationResult res = VerificationService.verifyCode(verificationRequestId, code);
        if (res != null && res.verified == true) {
            row.VerifiedChannel__c = res.channel;
            row.VerifiedAt__c = Datetime.now();
            if (String.isBlank(row.Session_Id__c)) {
                row.Status__c = 'Verified'; // form-first rows are complete once proven; sign-in rows wait for the form
            }
            update row;
            recordVerified(row, res.channel == 'Email' ? 'Email' : 'Mobile', otpTarget(row, res.channel), null, res.maskedTarget);
        } else if (res != null && res.status == 'Failed') {
            EOI_Site_Visitor__c v = EoiSiteVisitorService.known(otpTarget(row, 'Email'), otpTarget(row, 'SMS'));
            if (v != null) {
                EoiJourneyLog.logImmediate(v.Id, row.Id, row.Source__c, EoiJourneyLog.VERIFICATION_FAILED,
                    res.channel + ' · ' + res.maskedTarget + ' · attempts exhausted');
            }
        }
        return res;
    }

    private static String otpTarget(EOI_Public_Registration__c row, String channel) {
        if (channel == 'Email') {
            return row.CustomerType__c == 'Organization' ? row.RegisteredEmail__c : row.Email__c;
        }
        return row.CustomerType__c == 'Organization' ? row.RegisteredPhone__c : row.Mobile__c;
    }

    /** Links the visitor and writes the two milestones a verification proves. Never throws. */
    private static void recordVerified(EOI_Public_Registration__c row, String identityType, String value,
            UAEPassUserInfo u, String shownAs) {
        try {
            EoiSiteVisitorService.Result vr = EoiSiteVisitorService.onVerified(row, identityType, value, u);
            String subject = identityType == 'UAE Pass' ? EoiJourneyLog.VERIFIED_UAE_PASS
                : (identityType == 'Email' ? EoiJourneyLog.VERIFIED_EMAIL : EoiJourneyLog.VERIFIED_MOBILE);
            String who = vr.returning ? ' · returning visitor · prior visits ' + vr.priorVisits : ' · new visitor';
            EoiJourneyLog.queue(vr.visitor.Id, row.Id, row.Source__c, subject, shownAs + who);
            if (String.isBlank(row.Session_Id__c)) {
                EoiJourneyLog.queue(vr.visitor.Id, row.Id, row.Source__c, EoiJourneyLog.DETAILS_SUBMITTED, detailsSummary(row.Id));
            }
            EoiJourneyLog.flush();
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Visitor link failed: ' + e.getMessage());
        }
    }

    private static String detailsSummary(Id registrationId) {
        EOI_Public_Registration__c r = [
            SELECT Name, CustomerType__c, ResidentStatus__c FROM EOI_Public_Registration__c WHERE Id = :registrationId
        ];
        return r.Name + ' · ' + r.CustomerType__c + (String.isBlank(r.ResidentStatus__c) ? '' : ' · ' + r.ResidentStatus__c);
    }

    /** The customer pressed Continue on the residences step. Task only, no other DML. */
    public static void recordSelection(Id registrationId, List<UnitSelection> lines) {
        if (registrationId == null || lines == null || lines.isEmpty()) {
            return;
        }
        List<EOI_Public_Registration__c> rows = [
            SELECT Id, Name, Source__c, Visitor__c FROM EOI_Public_Registration__c
            WHERE Id = :registrationId AND Status__c IN ('Verified', 'Promoted', 'PromoteFailed') LIMIT 1
        ];
        if (rows.isEmpty() || rows[0].Visitor__c == null) {
            return;
        }
        Map<Id, Integer> qty = new Map<Id, Integer>();
        for (UnitSelection l : lines) {
            if (l != null && l.rangeId != null) {
                qty.put(l.rangeId, (qty.containsKey(l.rangeId) ? qty.get(l.rangeId) : 0) + (l.quantity == null ? 1 : l.quantity));
            }
        }
        List<String> parts = new List<String>();
        Decimal total = 0;
        for (EOI_Range__c r : [SELECT Id, UnitTypologyMRE__c, Amount__c FROM EOI_Range__c WHERE Id IN :qty.keySet()]) {
            Integer n = qty.get(r.Id);
            parts.add(r.UnitTypologyMRE__c + ' ×' + n);
            total += (r.Amount__c == null ? 0 : r.Amount__c) * n;
        }
        if (parts.isEmpty()) {
            return;
        }
        String summary = String.join(parts, ', ') + ' · total AED ' + total.setScale(0).format() + ' · ' + rows[0].Name;
        EoiJourneyLog.log(rows[0].Visitor__c, rows[0].Id, rows[0].Source__c, EoiJourneyLog.RESIDENCES_SELECTED, summary);
        EoiSiteVisitorService.appendTrail(rows[0].Visitor__c, 'Residences selected  ' + String.join(parts, ', '));
    }

    private static EOI_Public_Registration__c loadOpenRow(Id registrationId) {
        if (registrationId == null) {
            throw new EOIServiceException('Missing registration.');
        }
        List<EOI_Public_Registration__c> rows = [
            SELECT Id, Name, Status__c, CustomerType__c, Email__c, Mobile__c, ResidentStatus__c,
                   RegisteredEmail__c, RegisteredPhone__c, VerificationRequest__c, Source__c, Session_Id__c
            FROM EOI_Public_Registration__c
            WHERE Id = :registrationId AND Status__c = 'New' AND VerifiedAt__c = null
            LIMIT 1
        ];
        if (rows.isEmpty()) {
            throw new EOIServiceException('Registration not found or already verified.');
        }
        return rows[0];
    }

    private static void assertRequestBelongs(EOI_Public_Registration__c row, Id verificationRequestId) {
        if (verificationRequestId == null || row.VerificationRequest__c != verificationRequestId) {
            throw new EOIServiceException('Verification request mismatch.');
        }
    }

    // ---------- typology & final submit (mirrors the HGE journey process) ----------

    /* MEOI-A6. The five-second "submitted too fast" guard is REMOVED at MODON's request
       (9 Sep). It was firing on legitimate returning customers who already knew where the
       button was, and on the payment step it added nothing the honeypot does not - a bot
       fills the invisible field; a person who clicks quickly is just a person. The honeypot
       stays. elapsedMs is still accepted from the client so no signature changes. */

    public class TypologyTile {
        @AuraEnabled public Id rangeId       { get; set; }
        @AuraEnabled public Id phaseId       { get; set; }
        @AuraEnabled public String phaseName { get; set; }
        @AuraEnabled public String unitType  { get; set; }
        @AuraEnabled public String bedrooms  { get; set; }
        @AuraEnabled public String unitTypology { get; set; }
        @AuraEnabled public Decimal amount   { get; set; }
    }

    public class UnitSelection {
        @AuraEnabled public Id rangeId       { get; set; }
        @AuraEnabled public Integer quantity { get; set; }
    }

    public class SubmitResult {
        @AuraEnabled public String status        { get; set; }
        @AuraEnabled public String message       { get; set; }
        @AuraEnabled public String referenceName { get; set; }
        @AuraEnabled public Integer unitCount    { get; set; }
    }

    /* MEOI-RANGE (12 Sep 2026, MODON/Rushi): a range shows on the site only when it is Active
       AND its "Show On" multipicklist includes "Public Microsite". The same rule guards the two
       server-side truth queries below (selection submit, payment start), so a range hidden from
       the site cannot be paid for either. "Applicable for Broker" is no longer consulted here. */
    public static List<TypologyTile> getTypologies(Id projectId) {
        List<TypologyTile> tiles = new List<TypologyTile>();
        if (projectId == null) {
            return tiles;
        }
        for (EOI_Range__c r : [
            SELECT Id, Project__c, Phase__c, Phase__r.Name, Unit_Type__c,
                   No_of_Bedrooms__c, UnitTypologyMRE__c, Amount__c
            FROM EOI_Range__c
            WHERE Project__c = :projectId AND Is_Active__c = true AND Show_On__c INCLUDES ('Public Microsite')
            ORDER BY Phase__r.Name ASC, Unit_Type__c ASC, No_of_Bedrooms__c ASC
        ]) {
            TypologyTile tile = new TypologyTile();
            tile.rangeId = r.Id;
            tile.phaseId = r.Phase__c;
            tile.phaseName = r.Phase__r != null ? r.Phase__r.Name : null;
            tile.unitType = r.Unit_Type__c;
            tile.bedrooms = r.No_of_Bedrooms__c;
            tile.unitTypology = r.UnitTypologyMRE__c;
            tile.amount = r.Amount__c;
            tiles.add(tile);
        }
        return tiles;
    }

    /** Final submit: writes the selection onto the verified staging row and clones one row
     *  per extra unit, all under one BatchId (which hands the batch to the same promotion
     *  path the HGE journey uses). Amounts and typology data are re-read server-side. */
    public static SubmitResult completeRegistration(Id registrationId, Id projectId,
            List<UnitSelection> selections, String paymentType, Long elapsedMs, String honeypot) {
        SubmitResult result = new SubmitResult();
        if (String.isNotBlank(honeypot)) {
            throw new EOIServiceException('Submission rejected.');
        }
        if (paymentType != 'Cheque' && paymentType != 'Bank Transfer') {
            throw new EOIServiceException('Select a payment type.');
        }
        if (projectId == null || selections == null || selections.isEmpty()) {
            throw new EOIServiceException('Select at least one residence.');
        }

        List<EOI_Public_Registration__c> rows = [
            SELECT Id, Status__c, EOI_Range__c, BatchId__c, CustomerType__c, ResidentStatus__c,
                   FirstName__c, LastName__c, Email__c, Mobile__c, Phone__c, EmiratesId__c,
                   PassportNumber__c, UAE_Pass_UUID__c, CompanyName__c, TradeLicenseNumber__c,
                   TradeLicenseExpiryDate__c, RegisteredEmail__c, RegisteredPhone__c,
                   AuthorizedFirstName__c, AuthorizedLastName__c, AuthorizedEmail__c, AuthorizedPhone__c,
                   VerificationRequest__c, VerifiedChannel__c, VerifiedAt__c, Source__c,
                   UserAgent__c, Locale__c
            FROM EOI_Public_Registration__c
            WHERE Id = :registrationId
            LIMIT 1
        ];
        if (rows.isEmpty() || rows[0].Status__c != 'Verified') {
            throw new EOIServiceException('Registration not found or not verified.');
        }
        EOI_Public_Registration__c base = rows[0];
        if (base.EOI_Range__c != null || String.isNotBlank(base.BatchId__c)) {
            throw new EOIServiceException('This registration is already submitted.');
        }

        EoiHomeJourneyController.ValidationResult quota = EoiHomeJourneyController.validateEOI(null, projectId);
        if (quota != null && quota.quotaExceeded == true) {
            result.status = 'QuotaClosed';
            result.message = 'EOI submissions are closed for the selected project.';
            return result;
        }

        // server-side truth for every selected range
        Set<Id> rangeIds = new Set<Id>();
        for (UnitSelection sel : selections) {
            if (sel.rangeId == null || sel.quantity == null || sel.quantity < 1 || sel.quantity > 10) {
                throw new EOIServiceException('Invalid selection.');
            }
            rangeIds.add(sel.rangeId);
        }
        Map<Id, EOI_Range__c> ranges = new Map<Id, EOI_Range__c>([
            SELECT Id, Project__c, Phase__c, Unit_Type__c, No_of_Bedrooms__c, UnitTypologyMRE__c, Amount__c
            FROM EOI_Range__c
            WHERE Id IN :rangeIds AND Project__c = :projectId
              AND Is_Active__c = true AND Show_On__c INCLUDES ('Public Microsite')
        ]);
        if (ranges.size() != rangeIds.size()) {
            throw new EOIServiceException('Selection is no longer available.');
        }

        String batchId = generateBatchId();
        List<EOI_Public_Registration__c> toInsert = new List<EOI_Public_Registration__c>();
        Boolean baseFilled = false;
        for (UnitSelection sel : selections) {
            EOI_Range__c r = ranges.get(sel.rangeId);
            for (Integer i = 0; i < sel.quantity; i++) {
                if (!baseFilled) {
                    applySelection(base, r, projectId, paymentType, batchId);
                    baseFilled = true;
                } else {
                    EOI_Public_Registration__c clone = cloneIdentity(base);
                    applySelection(clone, r, projectId, paymentType, batchId);
                    toInsert.add(clone);
                }
            }
        }
        update base;
        if (!toInsert.isEmpty()) {
            insert toInsert;
        }

        result.status = 'Submitted';
        result.referenceName = [SELECT Name FROM EOI_Public_Registration__c WHERE Id = :base.Id].Name;
        result.unitCount = 1 + toInsert.size();
        result.message = 'Registration captured.';
        return result;
    }

    private static void applySelection(EOI_Public_Registration__c row, EOI_Range__c r,
            Id projectId, String paymentType, String batchId) {
        row.Project__c = projectId;
        row.Phase__c = r.Phase__c;
        row.EOI_Range__c = r.Id;
        row.UnitType__c = r.Unit_Type__c;
        row.Bedrooms__c = r.No_of_Bedrooms__c;
        row.UnitTypologyMRE__c = r.UnitTypologyMRE__c;
        row.Amount__c = r.Amount__c;
        row.PaymentTypePreference__c = paymentType;
        row.BatchId__c = batchId;
        row.SubmittedAt__c = Datetime.now();
    }

    private static EOI_Public_Registration__c cloneIdentity(EOI_Public_Registration__c base) {
        return new EOI_Public_Registration__c(
            Status__c = base.Status__c,
            Source__c = base.Source__c,
            CustomerType__c = base.CustomerType__c,
            ResidentStatus__c = base.ResidentStatus__c,
            FirstName__c = base.FirstName__c,
            LastName__c = base.LastName__c,
            Email__c = base.Email__c,
            Mobile__c = base.Mobile__c,
            Phone__c = base.Phone__c,
            EmiratesId__c = base.EmiratesId__c,
            PassportNumber__c = base.PassportNumber__c,
            UAE_Pass_UUID__c = base.UAE_Pass_UUID__c,
            CompanyName__c = base.CompanyName__c,
            TradeLicenseNumber__c = base.TradeLicenseNumber__c,
            TradeLicenseExpiryDate__c = base.TradeLicenseExpiryDate__c,
            RegisteredEmail__c = base.RegisteredEmail__c,
            RegisteredPhone__c = base.RegisteredPhone__c,
            AuthorizedFirstName__c = base.AuthorizedFirstName__c,
            AuthorizedLastName__c = base.AuthorizedLastName__c,
            AuthorizedEmail__c = base.AuthorizedEmail__c,
            AuthorizedPhone__c = base.AuthorizedPhone__c,
            VerificationRequest__c = base.VerificationRequest__c,
            VerifiedChannel__c = base.VerifiedChannel__c,
            VerifiedAt__c = base.VerifiedAt__c,
            UserAgent__c = base.UserAgent__c,
            Locale__c = base.Locale__c
        );
    }

    private static String generateBatchId() {
        String hex = EncodingUtil.convertToHex(Crypto.generateAesKey(128));
        return hex.substring(0, 8) + '-' + hex.substring(8, 12) + '-' + hex.substring(12, 16)
            + '-' + hex.substring(16, 20) + '-' + hex.substring(20, 32);
    }

    // ---------- card payment (Checkout.com hosted page, pay-first, one payment per type) ----------
    // Each selected residence type is paid for separately: one hosted payment, one
    // staging batch and one EOI reference per type. The line is priced server-side at
    // link creation and stashed as a snapshot on the payment row (own fields - never
    // EOI_Creation_Payload__c, which belongs to the console flow). Registration rows
    // are written only AFTER a payment captures.

    private static final String CARD_PAYMENT_TYPE = 'Online';
    private static final String CARD_CURRENCY = 'AED';
    private static final Integer MAX_OPEN_PAYMENT_LINKS = 5;
    /* MEOI-HOLD. The site no longer charges the card: by default it takes an authorisation
       (a hold) and ops capture or void it later from the Checkout Payment Console - the
       same Request.capture flag the console's "Authorize only" option sets. Checkout then
       reports Authorized rather than Captured, so every check that asks "is there money
       against this line" accepts both. Receipts and the Completed stamp deliberately stay
       on Captured: a hold is not money received. The shared EOI_Checkout_Capture_Mode is read at runtime
       like the other switches - 'Immediate' restores charge-on-payment with no publish. */
    /* PAL-P4 (10 Sep): one definition for every channel - EoiPaymentPolicy owns it. */
    public static final Set<String> PAID_STATUSES = EoiPaymentPolicy.PAID_STATUSES;
    /* PAL-P5 (10 Sep): the shared switch. EOI_Checkout_Capture_Mode lists the channels that
       still charge outright; 'Microsite' absent (today: None) means we hold. */
    @TestVisible private static Boolean captureImmediately() {
        return EoiPaymentPolicy.captureImmediately(EoiPaymentPolicy.CHANNEL_MICROSITE);
    }
    public static final String PAY_STATE_FINALIZED = 'Finalized';
    public static final String PAY_STATE_COMPLETED = 'Completed';
    public static final String PAY_STATE_DUPLICATE = 'Duplicate';
    public static final String PAY_STATE_REFUNDED  = 'Refunded';

    public class PaymentStart {
        @AuraEnabled public String status      { get; set; } // Redirect | Session | QuotaClosed | AlreadyPaid
        @AuraEnabled public String message     { get; set; }
        @AuraEnabled public String redirectUrl { get; set; }
        @AuraEnabled public String reference   { get; set; }
        // Embedded Flow only (startCardPaymentSession): the publishable key and the whole
        // /payment-sessions response the Checkout Web Components SDK needs in order to mount.
        // Neither is a secret - the secret key never leaves the named credential.
        @AuraEnabled public String publicKey       { get; set; }
        @AuraEnabled public String sessionResponse { get; set; }
    }

    public class PaymentStatus {
        @AuraEnabled public String status     { get; set; } // Captured | Pending | Failed | NotFound
        @AuraEnabled public Boolean finalized { get; set; }
        @AuraEnabled public Decimal amount    { get; set; }
        @AuraEnabled public String reference  { get; set; }
    }

    /** Selection snapshot stashed on the payment row at link creation. */
    private class SelectionSnapshot {
        public String registrationId;
        public String projectId;
        public List<SnapshotLine> lines;
    }
    private class SnapshotLine {
        public String rangeId;
        public String phaseId;
        public String unitType;
        public String bedrooms;
        public String unitTypology;
        public Decimal amount;
        public Integer quantity;
    }

    /** Validates one residence-type line, prices it server-side and opens a Checkout
     *  hosted payment for that type alone. No staging data changes here - registration
     *  rows are written only on capture. */
    public static PaymentStart startCardPayment(Id registrationId, Id projectId,
            Id rangeId, Integer quantity, Long elapsedMs, String honeypot, String returnPath,
            Integer unitIndex) {
        return startCardPaymentInternal(registrationId, projectId, rangeId, quantity,
            elapsedMs, honeypot, returnPath, false, unitIndex, null);
    }

    /** MEOI-CAPTCHA: same rail, with the page's reCAPTCHA token. */
    public static PaymentStart startCardPayment(Id registrationId, Id projectId,
            Id rangeId, Integer quantity, Long elapsedMs, String honeypot, String returnPath,
            Integer unitIndex, String recaptchaToken) {
        return startCardPaymentInternal(registrationId, projectId, rangeId, quantity,
            elapsedMs, honeypot, returnPath, false, unitIndex, recaptchaToken);
    }

    /** MSC-243: the same journey, kept on our own page. Identical guards and identical
     *  server-side pricing; the only difference is that Checkout returns a payment
     *  session for the embedded Flow component instead of a hosted page to redirect to.
     *  The customer never leaves the microsite. */
    public static PaymentStart startCardPaymentSession(Id registrationId, Id projectId,
            Id rangeId, Integer quantity, Long elapsedMs, String honeypot, String returnPath,
            Integer unitIndex) {
        return startCardPaymentInternal(registrationId, projectId, rangeId, quantity,
            elapsedMs, honeypot, returnPath, true, unitIndex, null);
    }

    /** MEOI-CAPTCHA: same rail, with the page's reCAPTCHA token. */
    public static PaymentStart startCardPaymentSession(Id registrationId, Id projectId,
            Id rangeId, Integer quantity, Long elapsedMs, String honeypot, String returnPath,
            Integer unitIndex, String recaptchaToken) {
        return startCardPaymentInternal(registrationId, projectId, rangeId, quantity,
            elapsedMs, honeypot, returnPath, true, unitIndex, recaptchaToken);
    }

    /** One body for both rails, so a guard can never be fixed in one and missed in the
     *  other. Everything up to the creation callout is identical; `embedded` switches
     *  only the Checkout endpoint and the shape of the result. */
    /* MEOI-A1 (9 Sep). One payment per UNIT, not per residence type. unitIndex (1-based)
       makes each unit of a typology its own payment: the key stored on the payment row
       becomes rangeId(15)#unitIndex, so AlreadyPaid, the open-link cap and the finalize
       duplicate check all operate per unit with no further change. Null unitIndex keeps
       the original per-type behaviour, so every payment already in the org stays valid.
       Fifteen characters of the Id plus '#' plus the index fits the Text(18) field; the
       18-character Id is still carried in the snapshot line for the clone rows. */
    private static PaymentStart startCardPaymentInternal(Id registrationId, Id projectId,
            Id rangeId, Integer quantity, Long elapsedMs, String honeypot, String returnPath,
            Boolean embedded, Integer unitIndex, String recaptchaToken) {
        PaymentStart out = new PaymentStart();
        if (String.isNotBlank(honeypot)) {
            throw new EOIServiceException('Submission rejected.');
        }
        verifyRecaptcha(recaptchaToken, 'eoi_payment'); // MEOI-CAPTCHA
        if (projectId == null || rangeId == null || quantity == null || quantity < 1 || quantity > 10) {
            throw new EOIServiceException('Invalid selection.');
        }
        // the base row may already be consumed by an earlier type's payment; only
        // the verification state gates a further type
        EOI_Public_Registration__c base = loadForPayment(registrationId, false);
        if (base.Status__c != 'Verified' && base.Status__c != 'Promoted' && base.Status__c != 'PromoteFailed') {
            throw new EOIServiceException('Registration not found or not verified.');
        }

        EoiHomeJourneyController.ValidationResult quota = EoiHomeJourneyController.validateEOI(null, projectId);
        if (quota != null && quota.quotaExceeded == true) {
            out.status = 'QuotaClosed';
            out.message = 'EOI submissions are closed for the selected project.';
            return out;
        }

        // server-side truth for the selected range
        List<EOI_Range__c> ranges = [
            SELECT Id, Phase__c, Unit_Type__c, No_of_Bedrooms__c, UnitTypologyMRE__c, Amount__c
            FROM EOI_Range__c
            WHERE Id = :rangeId AND Project__c = :projectId
              AND Is_Active__c = true AND Show_On__c INCLUDES ('Public Microsite')
        ];
        if (ranges.isEmpty() || ranges[0].Amount__c == null || ranges[0].Amount__c <= 0) {
            throw new EOIServiceException('Selection is no longer available.');
        }
        EOI_Range__c r = ranges[0];
        if (unitIndex != null) {
            if (unitIndex < 1 || unitIndex > 99) {
                throw new EOIServiceException('Invalid selection.');
            }
            quantity = 1; // per-unit rail: the amount is always one unit
        }
        Decimal total = r.Amount__c * quantity;

        SelectionSnapshot snap = new SelectionSnapshot();
        snap.registrationId = String.valueOf(registrationId);
        snap.projectId = String.valueOf(projectId);
        snap.lines = new List<SnapshotLine>();
        SnapshotLine line = new SnapshotLine();
        line.rangeId = String.valueOf(r.Id);
        line.phaseId = r.Phase__c == null ? null : String.valueOf(r.Phase__c);
        line.unitType = r.Unit_Type__c;
        line.bedrooms = r.No_of_Bedrooms__c;
        line.unitTypology = r.UnitTypologyMRE__c;
        line.amount = r.Amount__c;
        line.quantity = quantity;
        snap.lines.add(line);

        // one capture per type; open links capped per type against abuse
        String rangeKey = unitIndex == null
            ? String.valueOf(rangeId)
            : String.valueOf(rangeId).left(15) + '#' + unitIndex;
        Integer openLinks = 0;
        for (Checkout_Payment__c existing : [
            SELECT Id, Status__c, Reference__c, EOI_Site_Range__c, EOI_Site_State__c
            FROM Checkout_Payment__c
            WHERE EOI_Site_Registration__c = :String.valueOf(registrationId)
        ]) {
            Boolean paid = PAID_STATUSES.contains(existing.Status__c)
                || existing.EOI_Site_State__c == PAY_STATE_FINALIZED
                || existing.EOI_Site_State__c == PAY_STATE_COMPLETED;
            // a payment with no range marker predates the per-type rail and covered
            // the whole selection; one with this range covers exactly this type; a
            // reconciled refund releases the type so the customer may pay again
            Boolean coversType = existing.EOI_Site_Range__c == null || existing.EOI_Site_Range__c == rangeKey;
            if (paid && coversType && existing.EOI_Site_State__c != PAY_STATE_DUPLICATE
                    && existing.EOI_Site_State__c != PAY_STATE_REFUNDED) {
                out.status = 'AlreadyPaid';
                out.reference = existing.Reference__c;
                out.message = 'This residence type has already been paid for.';
                return out;
            }
            if (existing.EOI_Site_Range__c == rangeKey
                    && existing.Status__c == 'Link Created') {
                openLinks++;
            }
        }
        if (openLinks >= MAX_OPEN_PAYMENT_LINKS) {
            throw new EOIServiceException('Too many payment attempts. Please try again in a few minutes.');
        }

        String reference = 'CKO-' + EncodingUtil.convertToHex(Crypto.generateAesKey(128)).substring(0, 18);
        String pageUrl = sitePageUrl(returnPath);
        String encRef = EncodingUtil.urlEncode(reference, 'UTF-8');

        CheckoutPaymentLinkService.Request req = new CheckoutPaymentLinkService.Request();
        req.amount = total;
        req.currencyCode = CARD_CURRENCY;
        req.capture = captureImmediately();
        req.reference = reference;
        req.description = truncate('EOI Payment - '
            + (String.isBlank(r.UnitTypologyMRE__c) ? r.Unit_Type__c : r.UnitTypologyMRE__c), 80);
        req.relatedRecordId = String.valueOf(registrationId);
        req.successUrl = pageUrl + '?paymentResult=success&ref=' + encRef;
        req.failureUrl = pageUrl + '?paymentResult=failed&ref=' + encRef;
        req.cancelUrl  = pageUrl + '?paymentResult=cancelled&ref=' + encRef;
        /* MEOI-FRAME (11 Sep 2026). The embedded card form lives in an IFRAME on the
           registration page, and Checkout navigates THAT frame when a 3-D Secure step
           returns. With a site-page return URL the whole microsite loaded inside the card
           box and ran the payment-return leg a second time against the same session.
           Both return URLs now point at the frame's own container page instead: framed,
           it reports the result to the page that owns it; if it ever lands as the top
           window it forwards to this same site URL, so the hosted return leg still runs.
           The hosted rail (createHostedPayment, shared with the portal and console) keeps
           the three URLs above untouched. */
        if (embedded) {
            String backPath = EncodingUtil.urlEncode(new URL(pageUrl).getPath(), 'UTF-8');
            String frameUrl = frameReturnUrl();
            req.successUrl = frameUrl + '?result=success&ref=' + encRef + '&path=' + backPath;
            req.failureUrl = frameUrl + '?result=failed&ref=' + encRef + '&path=' + backPath;
        }
        if (base.CustomerType__c == 'Organization') {
            req.customerName = base.CompanyName__c;
            req.customerEmail = base.RegisteredEmail__c;
            req.customerPhoneNumber = base.RegisteredPhone__c;
        } else {
            req.customerName = joinName(base.FirstName__c, base.LastName__c);
            req.customerEmail = base.Email__c;
            req.customerPhoneNumber = base.Mobile__c;
        }
        // createHostedPayment sets this itself; the session endpoint does not, and without
        // it CheckoutNotificationService would email a "created" message pointing at a
        // payment link that does not exist for a session. The customer is on our page.
        if (embedded) {
            req.portalInitiated = true;
        }

        CheckoutPaymentLinkService.Result res = embedded
            ? CheckoutPaymentLinkService.createPaymentSession(req)
            : CheckoutPaymentLinkService.createHostedPayment(req);
        flushDeferredLogs(); // MEOI-CAPTCHA5: the last callout of this transaction is done
        if (res == null || res.isSuccess != true || res.paymentRecordId == null) {
            /* MEOI-DIAG. The customer keeps the friendly line, but the REASON is no longer
               thrown away. Until now a failed payment start produced this generic message
               and nothing else - no log, no status, no response body - so an intermittent
               gateway failure was undiagnosable after the fact. The gateway's own message
               and status are recorded here instead. Logging must never itself break the
               payment path, hence the bare catch. */
            try {
                String detail = res == null ? 'null result' : res.message;
                String raw = res == null ? null : res.rawResponse;
                if (raw != null && raw.length() > 30000) {
                    raw = raw.substring(0, 30000);
                }
                LoggerService.save(new Logger__c(
                    ClassName__c = 'EOIService',
                    MethodName__c = embedded
                        ? 'startCardPaymentInternal[session]'
                        : 'startCardPaymentInternal[hosted]',
                    ExecutingProcessName__c = 'EOI Site Payment Start',
                    Message__c = detail,
                    Integration_Request_Body__c = 'registrationId=' + registrationId
                        + '; rangeId=' + rangeId + '; quantity=' + quantity,
                    Integration_Response_Body__c = raw
                ));
            } catch (Exception logEx) {
                // never let diagnostics take down the journey
            }
            throw new EOIServiceException('The secure payment page could not be started. Please try again.');
        }
        // stash our snapshot on the row the service just created (own fields only)
        update new Checkout_Payment__c(
            Id = res.paymentRecordId,
            EOI_Site_Registration__c = String.valueOf(registrationId),
            EOI_Site_Selection__c = JSON.serialize(snap),
            EOI_Site_Range__c = rangeKey
        );
        EoiJourneyLog.log(base.Visitor__c, base.Id, base.Source__c, EoiJourneyLog.PAYMENT_STARTED,
            res.reference + ' · ' + r.UnitTypologyMRE__c + ' · AED ' + total.setScale(0).format() + ' · ' + base.Name);

        if (embedded) {
            // The reference is what confirmCardPayment, the poller and the sweeper key on;
            // a ps_ row resolves through the reference search, not the hosted-session read.
            out.status = 'Session';
            out.publicKey = res.publicKey;
            out.sessionResponse = res.sessionResponse;
        } else {
            out.status = 'Redirect';
            out.redirectUrl = res.paymentLinkUrl;
        }
        out.reference = res.reference;
        return out;
    }

    /** Re-reads the payment status from Checkout (for our own microsite rows only).
     *  Declined and Expired are re-polled, not trusted: a hosted session lets the
     *  customer retry after a decline, and the poller's clock-based Expired flip can
     *  precede a boundary capture. Only the write-side outcomes are final here. */
    public static PaymentStatus confirmCardPayment(String reference) {
        PaymentStatus out = new PaymentStatus();
        Checkout_Payment__c cp = loadSitePayment(reference);
        if (cp == null) {
            out.status = 'NotFound';
            return out;
        }
        Set<String> terminal = new Set<String>{
            'Captured', 'Authorized', 'Voided', 'Refunded', 'Partially Refunded'
        };
        String statusBefore = cp.Status__c;
        if (!terminal.contains(cp.Status__c)) {
            CheckoutPaymentLinkService.applyLatestStatus(cp);
            // narrow write-back: only the fields the poll mutates, so a concurrent
            // finalize's EOI_Site_State__c write is never clobbered
            update new Checkout_Payment__c(
                Id = cp.Id,
                Status__c = cp.Status__c,
                Last_Checkout_Status__c = cp.Last_Checkout_Status__c,
                Payment_Id__c = cp.Payment_Id__c,
                Raw_Payload__c = cp.Raw_Payload__c,
                Last_Polled__c = cp.Last_Polled__c,
                Error_Message__c = cp.Error_Message__c,
                Card_Last4__c = cp.Card_Last4__c,
                Card_Scheme__c = cp.Card_Scheme__c,
                Card_Type__c = cp.Card_Type__c,
                Card_Category__c = cp.Card_Category__c,
                Card_BIN__c = cp.Card_BIN__c,
                Card_Expiry__c = cp.Card_Expiry__c,
                Issuer__c = cp.Issuer__c,
                Issuer_Country__c = cp.Issuer_Country__c,
                Bank_Name__c = cp.Bank_Name__c,
                Account_Last4__c = cp.Account_Last4__c
            );
        }
        out.reference = cp.Reference__c;
        out.amount = cp.Amount__c;
        out.finalized = cp.EOI_Site_State__c == PAY_STATE_FINALIZED || cp.EOI_Site_State__c == PAY_STATE_COMPLETED;
        // 'Captured' stays the wire value the page acts on: a hold and a charge both mean
        // this line is settled from the customer's side (MEOI-HOLD)
        if (PAID_STATUSES.contains(cp.Status__c)) {
            out.status = 'Captured';
        } else if (cp.Status__c == 'Authorization Expired' && !cp.Recovery_Alert_Sent__c) {
            // MEOI-RECOVER: the hold ran out and is being taken again for a couple of days. Calling
            // it Failed would end the registration while we are still collecting it, so it stays
            // settled from the customer's side - the same word the console and the broker see.
            out.status = 'Captured';
        } else if (cp.Status__c == 'Declined' || cp.Status__c == 'Voided'
                || cp.Status__c == 'Expired' || cp.Status__c == 'Authorization Expired'
                || cp.Status__c == 'Refunded'
                || cp.Status__c == 'Partially Refunded') {
            out.status = 'Failed';
        } else {
            out.status = 'Pending';
        }
        if (out.status == 'Failed' && statusBefore != cp.Status__c) {
            recordPaymentNotCompleted(cp);
        }
        return out;
    }

    private static void recordPaymentNotCompleted(Checkout_Payment__c cp) {
        for (EOI_Public_Registration__c r : [
            SELECT Id, Name, Source__c, Visitor__c FROM EOI_Public_Registration__c
            WHERE Id = :cp.EOI_Site_Registration__c AND Visitor__c != null LIMIT 1
        ]) {
            EoiJourneyLog.logImmediate(r.Visitor__c, r.Id, r.Source__c, EoiJourneyLog.PAYMENT_NOT_COMPLETED,
                cp.Reference__c + ' · ' + cp.Status__c + ' · ' + r.Name);
        }
    }

    /** Writes the registration for a captured payment. Idempotent; separate transaction from
     *  the status callout so promotion (fired by the staging inserts) never follows a callout. */
    public static SubmitResult finalizeCardPayment(String reference) {
        Checkout_Payment__c cp = loadSitePayment(reference);
        if (cp == null) {
            throw new EOIServiceException('Payment not found.');
        }
        return finalizeFromPayment(cp);
    }

    /** Shared by the return path (guest) and EOISitePaymentSweeper (scheduled fallback).
     *  Writes this payment's own staging batch: the first payment for a registration
     *  consumes the base row, every later type gets a batch of fresh clones. */
    public static SubmitResult finalizeFromPayment(Checkout_Payment__c cp) {
        SubmitResult result = new SubmitResult();
        // lock + re-read: the return path, a second tab and the sweeper serialize here,
        // so exactly one transaction sees the pre-finalize state
        List<Checkout_Payment__c> fresh = [
            SELECT Id, Reference__c, Status__c, EOI_Site_Registration__c, EOI_Site_Selection__c,
                   EOI_Site_State__c, EOI_Site_Range__c, EOI_Site_Batch__c
            FROM Checkout_Payment__c WHERE Id = :cp.Id LIMIT 1 FOR UPDATE
        ];
        if (fresh.isEmpty()) {
            throw new EOIServiceException('Payment not found.');
        }
        cp = fresh[0];
        // idempotency first: a payment that already registered stays registered
        // even if its status later moves on (e.g. an ops refund)
        if (cp.EOI_Site_State__c == PAY_STATE_FINALIZED || cp.EOI_Site_State__c == PAY_STATE_COMPLETED
                || cp.EOI_Site_State__c == PAY_STATE_DUPLICATE) {
            return alreadyRegisteredResult(cp);
        }
        if (!PAID_STATUSES.contains(cp.Status__c)) {
            throw new EOIServiceException('Payment has not been approved yet.');
        }
        SelectionSnapshot snap;
        try {
            snap = (SelectionSnapshot) JSON.deserialize(cp.EOI_Site_Selection__c, SelectionSnapshot.class);
        } catch (Exception e) {
            snap = null;
        }
        if (snap == null || snap.lines == null || snap.lines.isEmpty()
                || snap.registrationId != cp.EOI_Site_Registration__c) {
            throw new EOIServiceException('Payment snapshot is unreadable.');
        }

        // base row lock serializes every finalize for this registration, which also
        // makes the per-type duplicate check below race-free
        EOI_Public_Registration__c base = loadForPayment(snap.registrationId, true);
        Boolean baseConsumed = base.EOI_Range__c != null || String.isNotBlank(base.BatchId__c);

        // duplicate rules: a payment with no range marker predates the per-type rail
        // and covered the whole selection - once the base row is consumed it must never
        // register again; a per-type payment is a duplicate when another finalized
        // payment already covers its type (or a whole-selection one covered everything)
        Boolean duplicate = false;
        if (cp.EOI_Site_Range__c == null) {
            duplicate = baseConsumed;
        } else {
            for (Checkout_Payment__c sibling : [
                SELECT EOI_Site_Range__c FROM Checkout_Payment__c
                WHERE EOI_Site_Registration__c = :cp.EOI_Site_Registration__c
                  AND Id != :cp.Id
                  AND EOI_Site_State__c IN (:PAY_STATE_FINALIZED, :PAY_STATE_COMPLETED)
            ]) {
                if (sibling.EOI_Site_Range__c == null || sibling.EOI_Site_Range__c == cp.EOI_Site_Range__c) {
                    duplicate = true;
                    break;
                }
            }
        }
        if (duplicate) {
            // the type is already registered by another payment - park for ops review
            update new Checkout_Payment__c(Id = cp.Id, EOI_Site_State__c = PAY_STATE_DUPLICATE);
            return alreadyRegisteredResult(cp);
        }

        // rows are written with BatchId__c BLANK and this payment's reference as
        // their join marker: the Create-only auto-promote flow still fires on the
        // clone inserts but no-ops on a blank batch, so nothing promotes until the
        // VISIT closes (completeVisit) and everything paid in it becomes ONE batch
        // -> one Lead -> one conversion -> one Opportunity
        List<EOI_Public_Registration__c> toInsert = new List<EOI_Public_Registration__c>();
        Boolean baseFilled = baseConsumed; // a consumed base row is never rewritten
        for (SnapshotLine line : snap.lines) {
            Integer qty = (line.quantity == null || line.quantity < 1 || line.quantity > 10) ? 1 : line.quantity;
            for (Integer i = 0; i < qty; i++) {
                if (!baseFilled) {
                    applySnapshotLine(base, line, snap.projectId, cp.Reference__c);
                    baseFilled = true;
                } else {
                    EOI_Public_Registration__c clone = cloneIdentity(base);
                    // the base row may already be Promoted/PromoteFailed from an
                    // earlier consolidated visit; this payment's rows start Verified
                    // so consolidation and the promotion handler both pick them up
                    clone.Status__c = 'Verified';
                    applySnapshotLine(clone, line, snap.projectId, cp.Reference__c);
                    toInsert.add(clone);
                }
            }
        }
        // rows and state stamp commit together or not at all: a caller that catches
        // (the sweeper) must never keep a half-finalized registration
        Savepoint sp = Database.setSavepoint();
        try {
            if (!baseConsumed) {
                update base;
            }
            if (!toInsert.isEmpty()) {
                insert toInsert;
            }
            update new Checkout_Payment__c(Id = cp.Id, EOI_Site_State__c = PAY_STATE_FINALIZED);
        } catch (Exception e) {
            Database.rollback(sp);
            throw e;
        }
        recordPaymentCaptured(base, cp);

        result.status = 'Registered';
        result.referenceName = [
            SELECT Name FROM EOI_Public_Registration__c
            WHERE EOI_Site_Payment__c = :cp.Reference__c ORDER BY CreatedDate ASC LIMIT 1
        ].Name;
        result.unitCount = (baseConsumed ? 0 : 1) + toInsert.size();
        result.message = 'Registration captured.';
        return result;
    }

    private static void applySnapshotLine(EOI_Public_Registration__c row, SnapshotLine line,
            String projectId, String paymentRef) {
        row.Project__c = projectId;
        row.Phase__c = line.phaseId;
        row.EOI_Range__c = line.rangeId;
        row.UnitType__c = line.unitType;
        row.Bedrooms__c = line.bedrooms;
        row.UnitTypologyMRE__c = line.unitTypology;
        row.Amount__c = line.amount;
        row.PaymentTypePreference__c = CARD_PAYMENT_TYPE;
        row.EOI_Site_Payment__c = paymentRef;
        row.SubmittedAt__c = Datetime.now();
    }

    /** Describes the staging rows a finalized payment wrote. New-model rows carry the
     *  payment reference; a payment with a batch marker but no such rows wrote its own
     *  batch (per-type era); one with neither predates the per-type rail entirely and
     *  its batch lives on the base registration row. */
    private static SubmitResult alreadyRegisteredResult(Checkout_Payment__c cp) {
        SubmitResult result = new SubmitResult();
        result.status = 'Registered';
        result.message = 'Registration already captured.';
        if (String.isNotBlank(cp.Reference__c)) {
            List<EOI_Public_Registration__c> own = [
                SELECT Name FROM EOI_Public_Registration__c
                WHERE EOI_Site_Payment__c = :cp.Reference__c ORDER BY CreatedDate ASC
            ];
            if (!own.isEmpty()) {
                result.referenceName = own[0].Name;
                result.unitCount = own.size();
                return result;
            }
        }
        String batchId = cp.EOI_Site_Batch__c;
        List<EOI_Public_Registration__c> bases = [
            SELECT Name, BatchId__c FROM EOI_Public_Registration__c
            WHERE Id = :cp.EOI_Site_Registration__c LIMIT 1
        ];
        if (String.isBlank(batchId) && !bases.isEmpty()) {
            batchId = bases[0].BatchId__c;
        }
        if (String.isNotBlank(batchId)) {
            List<EOI_Public_Registration__c> rows = [
                SELECT Name FROM EOI_Public_Registration__c
                WHERE BatchId__c = :batchId ORDER BY CreatedDate ASC
            ];
            if (!rows.isEmpty()) {
                result.referenceName = rows[0].Name;
                result.unitCount = rows.size();
                return result;
            }
        }
        if (!bases.isEmpty()) {
            result.referenceName = bases[0].Name;
            result.unitCount = 1;
        }
        return result;
    }

    /** Per-type payment facts for a registration, for rendering the payment checklist
     *  after a return or reload. One entry per residence type with money against it
     *  (captured or finalized); duplicates parked for ops are excluded. */
    public class PaymentLineState {
        @AuraEnabled public String rangeId      { get; set; } // the stored key: rangeId, or rangeId(15)#n
        @AuraEnabled public String baseRangeId  { get; set; } // 18-char EOI_Range__c Id from the snapshot
        @AuraEnabled public Integer unitIndex   { get; set; } // null for a legacy per-type payment
        @AuraEnabled public String reference    { get; set; }
        @AuraEnabled public Decimal amount      { get; set; }
        @AuraEnabled public Integer quantity    { get; set; }
        @AuraEnabled public Decimal unitAmount  { get; set; }
        @AuraEnabled public String unitTypology { get; set; }
        @AuraEnabled public String bedrooms     { get; set; }
        @AuraEnabled public List<String> eoiNumbers { get; set; } // system-generated, once the EOI records exist
    }

    /** VAPT EXT-03 (CYBER50, 13 Sep 2026): a registration's payment lines are handed only to the tab that
     *  signed that registration in - the caller must present the session id `beginSignIn` issued
     *  (`Session_Id__c`, 128-bit random) and the registration must be verified. Anything else gets an
     *  empty list, indistinguishable from "no payments yet". Record ids are identifiers, not credentials. */
    public static List<PaymentLineState> getPaymentState(Id registrationId, String sessionId) {
        List<PaymentLineState> out = new List<PaymentLineState>();
        if (registrationId == null || !ownsRegistration(registrationId, sessionId)) {
            return out;
        }
        Map<String, PaymentLineState> byRange = new Map<String, PaymentLineState>();
        for (Checkout_Payment__c cp : [
            SELECT Reference__c, Amount__c, Status__c,
                   EOI_Site_Range__c, EOI_Site_Selection__c, EOI_Site_State__c
            FROM Checkout_Payment__c
            WHERE EOI_Site_Registration__c = :String.valueOf(registrationId)
              AND EOI_Site_Range__c != null
              AND (Status__c IN :PAID_STATUSES
                   OR EOI_Site_State__c IN (:PAY_STATE_FINALIZED, :PAY_STATE_COMPLETED))
              AND EOI_Site_State__c != :PAY_STATE_DUPLICATE
              AND EOI_Site_State__c != :PAY_STATE_REFUNDED
            ORDER BY CreatedDate ASC
        ]) {
            PaymentLineState s = new PaymentLineState();
            s.rangeId = cp.EOI_Site_Range__c;
            if (s.rangeId != null && s.rangeId.contains('#')) {
                try { s.unitIndex = Integer.valueOf(s.rangeId.substringAfter('#')); }
                catch (Exception e) { s.unitIndex = null; }
            }
            s.reference = cp.Reference__c;
            s.amount = cp.Amount__c;
            try {
                SelectionSnapshot snap = (SelectionSnapshot)
                    JSON.deserialize(cp.EOI_Site_Selection__c, SelectionSnapshot.class);
                if (snap != null && snap.lines != null && !snap.lines.isEmpty()) {
                    s.baseRangeId = snap.lines[0].rangeId;
                    s.quantity = snap.lines[0].quantity;
                    s.unitAmount = snap.lines[0].amount;
                    s.unitTypology = snap.lines[0].unitTypology;
                    s.bedrooms = snap.lines[0].bedrooms;
                }
            } catch (Exception e) {
                // display fields stay null; amount and reference still render
            }
            byRange.put(s.rangeId, s);
        }
        Set<String> refs = new Set<String>();
        for (PaymentLineState s : byRange.values()) {
            refs.add(s.reference);
        }
        Map<String, List<String>> numbers = eoiNumbersByRef(refs);
        for (PaymentLineState s : byRange.values()) {
            s.eoiNumbers = numbers.containsKey(s.reference)
                ? numbers.get(s.reference) : new List<String>();
        }
        out.addAll(byRange.values());
        return out;
    }

    /** The system-generated EOI numbers behind each payment reference, once the
     *  records exist: staging rows join the payment via EOI_Site_Payment__c and
     *  the EOI via PromotedEOI__c. EOIId__c is the customer-facing number in all
     *  notifications; Name is the fallback (the id generator leaves EOIId__c
     *  null on a random token collision). One aggregated query per call. */
    private static Map<String, List<String>> eoiNumbersByRef(Set<String> refs) {
        Map<String, List<String>> out = new Map<String, List<String>>();
        if (refs == null || refs.isEmpty()) {
            return out;
        }
        for (EOI_Public_Registration__c row : [
            SELECT EOI_Site_Payment__c, PromotedEOI__r.EOIId__c, PromotedEOI__r.Name
            FROM EOI_Public_Registration__c
            WHERE EOI_Site_Payment__c IN :refs AND PromotedEOI__c != null
            ORDER BY CreatedDate ASC
            LIMIT 500
        ]) {
            String num = String.isNotBlank(row.PromotedEOI__r.EOIId__c)
                ? row.PromotedEOI__r.EOIId__c : row.PromotedEOI__r.Name;
            if (!out.containsKey(row.EOI_Site_Payment__c)) {
                out.put(row.EOI_Site_Payment__c, new List<String>());
            }
            out.get(row.EOI_Site_Payment__c).add(num);
        }
        return out;
    }

    // ---------- visit closure (one Opportunity per visit) ----------
    // A visit = one open registration row: sign-in creates or reuses it, each paid
    // residence type writes its rows against it (batchless), and closing the visit
    // gives everything paid in it ONE batch so the shared promotion handler makes
    // one Lead -> one conversion -> one Opportunity -> N EOIs.

    /** Closes the visit: assigns one fresh batch to every finalized-but-unbatched
     *  staging row whose payment is still captured, stamps the batch onto those
     *  payments and promotes the batch - one Lead, one conversion, one Opportunity.
     *  SWEEPER-ONLY, by design: promotion must never run in a guest transaction,
     *  and the caller's grace window is what guarantees every clone-insert flow
     *  interview for these rows has long drained, so no second promoter can race
     *  this one. While ANY captured payment of the registration is still
     *  unfinalized the closure defers - the visit must never split into two
     *  batches (two Opportunities) because one payment's rows arrived late.
     *  Idempotent: nothing to consolidate is a no-op. */
    public static SubmitResult completeVisit(Id registrationId) {
        SubmitResult result = new SubmitResult();
        result.status = 'NoOp';
        if (registrationId == null) {
            return result;
        }
        // the base-row lock serializes visit closure against concurrent finalizes
        // and against the sweeper's own consolidation pass
        loadForPayment(String.valueOf(registrationId), true);

        // only money that is still captured consolidates: a refunded payment's
        // rows must never promote; a captured payment with no site state has not
        // written its rows yet, so the whole visit waits for it
        Map<String, Id> capturedByRef = new Map<String, Id>();
        for (Checkout_Payment__c cp : [
            SELECT Id, Reference__c, EOI_Site_State__c FROM Checkout_Payment__c
            WHERE EOI_Site_Registration__c = :String.valueOf(registrationId)
              AND Status__c IN :PAID_STATUSES AND EOI_Site_Batch__c = null
        ]) {
            if (cp.EOI_Site_State__c == null) {
                result.status = 'Deferred';
                result.message = 'A captured payment has not registered yet.';
                return result;
            }
            if (cp.EOI_Site_State__c == PAY_STATE_FINALIZED && String.isNotBlank(cp.Reference__c)) {
                capturedByRef.put(cp.Reference__c, cp.Id);
            }
        }
        if (capturedByRef.isEmpty()) {
            return result;
        }
        List<EOI_Public_Registration__c> rows = [
            SELECT Id, Name, EOI_Site_Payment__c FROM EOI_Public_Registration__c
            WHERE EOI_Site_Payment__c IN :capturedByRef.keySet()
              AND BatchId__c = null AND Status__c = 'Verified' AND EOI_Range__c != null
            ORDER BY CreatedDate ASC
        ];
        if (rows.isEmpty()) {
            return result;
        }
        promotePendingAsBatch(rows, capturedByRef, result);
        return result;
    }

    /** Assigns one fresh batch to the pending rows, stamps it on their payments
     *  and runs the shared promotion cascade ONCE - atomically. Shared by
     *  completeVisit (sweeper backstop) and settlePaymentEois (flow fast path). */
    private static void promotePendingAsBatch(List<EOI_Public_Registration__c> rows,
            Map<String, Id> capturedByRef, SubmitResult result) {
        String batchId = generateBatchId();
        List<Id> rowIds = new List<Id>();
        Set<Id> paymentIds = new Set<Id>();
        for (EOI_Public_Registration__c row : rows) {
            row.BatchId__c = batchId;
            rowIds.add(row.Id);
            paymentIds.add(capturedByRef.get(row.EOI_Site_Payment__c));
        }
        List<Checkout_Payment__c> stamps = new List<Checkout_Payment__c>();
        for (Id pid : paymentIds) {
            stamps.add(new Checkout_Payment__c(Id = pid, EOI_Site_Batch__c = batchId));
        }
        // batch assignment, payment stamps and the promotion commit together or
        // roll back together, so a failed close leaves the visit exactly as it
        // was for the next attempt
        Savepoint sp = Database.setSavepoint();
        try {
            update rows;
            update stamps;
            EoiRegistrationPromotionHandler.promoteFromFlow(rowIds);
        } catch (Exception e) {
            Database.rollback(sp);
            throw e;
        }
        result.status = 'Consolidated';
        result.referenceName = rows[0].Name;
        result.unitCount = rows.size();
        result.message = 'Visit consolidated.';
    }

    /** Settles every finalized-but-unpromoted payment of this visit into EOI
     *  records NOW. The first settle runs the full promotion cascade - one Lead,
     *  one conversion, the visit's ONE Opportunity, this payment's EOIs. Every
     *  later settle APPENDS its EOIs to that same Opportunity with the promotion
     *  handler's exact row write-back shape (Status, PromotedEOI__c, PromotedAt__c,
     *  Matched fields, BatchId__c), so receipts, refund reconciliation and the
     *  returning-customer view cannot tell settled rows from sweeper-promoted
     *  ones. FLOW/SYSTEM CONTEXT ONLY - never call from a guest transaction
     *  (same rule as completeVisit); at most ONE promotion cascade per call.
     *  Idempotent and serialized on the base-row lock: batched rows are never
     *  re-selected, and a promoted base row is never reused across sessions
     *  (identity dedupe only reopens New/Verified rows), so any promoted row of
     *  this registration anchors THIS visit's Opportunity. */
    public static SubmitResult settlePaymentEois(Id registrationId) {
        SubmitResult result = new SubmitResult();
        result.status = 'NoOp';
        if (registrationId == null) {
            return result;
        }
        // serializes against finalizes, the sweeper and concurrent settles
        loadForPayment(String.valueOf(registrationId), true);

        Map<String, Id> capturedByRef = new Map<String, Id>();
        Set<String> allRefs = new Set<String>();
        for (Checkout_Payment__c cp : [
            SELECT Id, Reference__c, Status__c, EOI_Site_State__c, EOI_Site_Batch__c
            FROM Checkout_Payment__c
            WHERE EOI_Site_Registration__c = :String.valueOf(registrationId)
        ]) {
            if (String.isNotBlank(cp.Reference__c)) {
                allRefs.add(cp.Reference__c);
            }
            if (PAID_STATUSES.contains(cp.Status__c) && cp.EOI_Site_Batch__c == null
                    && cp.EOI_Site_State__c == PAY_STATE_FINALIZED
                    && String.isNotBlank(cp.Reference__c)) {
                capturedByRef.put(cp.Reference__c, cp.Id);
            }
        }
        if (capturedByRef.isEmpty()) {
            return result;
        }
        List<EOI_Public_Registration__c> rows = [
            SELECT Id, Name, EOI_Site_Payment__c, Project__c, Phase__c, UnitType__c,
                   Bedrooms__c, UnitTypologyMRE__c, EOI_Range__c, Amount__c,
                   PaymentTypePreference__c
            FROM EOI_Public_Registration__c
            WHERE EOI_Site_Payment__c IN :capturedByRef.keySet()
              AND BatchId__c = null AND Status__c = 'Verified' AND EOI_Range__c != null
            ORDER BY CreatedDate ASC
        ];
        if (rows.isEmpty()) {
            return result;
        }

        List<EOI_Public_Registration__c> anchors = [
            SELECT Id, BatchId__c, MatchedAccount__c, MatchedContact__c, MatchedLead__c,
                   PromotedEOI__c, PromotedEOI__r.Opportunity__c
            FROM EOI_Public_Registration__c
            WHERE Status__c = 'Promoted' AND PromotedEOI__c != null
              AND (Id = :registrationId OR EOI_Site_Payment__c IN :allRefs)
            ORDER BY PromotedAt__c ASC
            LIMIT 1
        ];
        if (anchors.isEmpty() || anchors[0].PromotedEOI__r.Opportunity__c == null) {
            // first settled payment of the visit carries the full cascade
            promotePendingAsBatch(rows, capturedByRef, result);
            receiptSettledPayments(registrationId);
            return result;
        }

        // append under the visit's existing Opportunity
        EOI_Public_Registration__c anchor = anchors[0];
        String batchId = String.isBlank(anchor.BatchId__c) ? generateBatchId() : anchor.BatchId__c;
        List<Expressionofinterest__c> eois = new List<Expressionofinterest__c>();
        for (EOI_Public_Registration__c row : rows) {
            eois.add(new Expressionofinterest__c(
                Opportunity__c = anchor.PromotedEOI__r.Opportunity__c,
                Project__c = row.Project__c,
                Phase__c = row.Phase__c,
                UnitType__c = row.UnitType__c,
                NumberofBedrooms__c = row.Bedrooms__c,
                UnitTypologyMRE__c = row.UnitTypologyMRE__c,
                Number_of_Units__c = 1,
                EOI_Range__c = row.EOI_Range__c,
                EOI_Amount_AED__c = row.Amount__c,
                Account__c = anchor.MatchedAccount__c,
                Contact__c = anchor.MatchedContact__c,
                Payment_Type__c = row.PaymentTypePreference__c
            ));
        }
        Set<Id> paymentIds = new Set<Id>();
        for (EOI_Public_Registration__c row : rows) {
            paymentIds.add(capturedByRef.get(row.EOI_Site_Payment__c));
        }
        List<Checkout_Payment__c> stamps = new List<Checkout_Payment__c>();
        for (Id pid : paymentIds) {
            stamps.add(new Checkout_Payment__c(Id = pid, EOI_Site_Batch__c = batchId));
        }
        Savepoint sp = Database.setSavepoint();
        try {
            insert eois;
            for (Integer i = 0; i < rows.size(); i++) {
                EOI_Public_Registration__c row = rows[i];
                row.Status__c = 'Promoted';
                row.PromotedEOI__c = eois[i].Id;
                row.PromotedAt__c = System.now();
                row.MatchedAccount__c = anchor.MatchedAccount__c;
                row.MatchedContact__c = anchor.MatchedContact__c;
                row.MatchedLead__c = anchor.MatchedLead__c;
                row.BatchId__c = batchId;
            }
            update rows;
            update stamps;
        } catch (Exception e) {
            Database.rollback(sp);
            throw e;
        }
        result.status = 'Appended';
        result.referenceName = rows[0].Name;
        result.unitCount = rows.size();
        result.message = 'EOIs appended to the visit opportunity.';
        receiptSettledPayments(registrationId);
        return result;
    }

    /** Receipts every finalized payment of the registration whose rows are all
     *  Promoted - the sweeper completeOne record shape, run at settle time so the
     *  receipt lands seconds after payment instead of on the 10-minute cadence.
     *  Each payment is its own savepoint: a failure leaves that payment Finalized
     *  and the sweeper backstop receipts it exactly as before (MSC-244). */
    private static void receiptSettledPayments(Id registrationId) {
        /* MEOI-HOLD-2. A held (Authorized) payment gets its EOI stamped the moment its
           rows promote, so ops see the EOI on the payment record; the receipt and the
           Completed state still wait for Captured. "Needs work" is therefore Receipt__c
           = null, no longer Expression_of_Interest__c = null. */
        List<Checkout_Payment__c> pays = [
            SELECT Id, Reference__c, Payment_Id__c, Currency_Code__c, Status__c,
                   EOI_Site_Registration__c, Expression_of_Interest__c
            FROM Checkout_Payment__c
            WHERE EOI_Site_Registration__c = :String.valueOf(registrationId)
              AND Status__c IN :PAID_STATUSES AND EOI_Site_State__c = :PAY_STATE_FINALIZED
              AND Receipt__c = null
        ];
        if (pays.isEmpty()) {
            return;
        }
        Set<String> refs = new Set<String>();
        for (Checkout_Payment__c cp : pays) {
            if (String.isNotBlank(cp.Reference__c)) {
                refs.add(cp.Reference__c);
            }
        }
        Map<String, List<EOI_Public_Registration__c>> rowsByRef = new Map<String, List<EOI_Public_Registration__c>>();
        for (EOI_Public_Registration__c row : [
            SELECT Id, Status__c, Amount__c, MatchedAccount__c, PromotedEOI__c, EOI_Site_Payment__c
            FROM EOI_Public_Registration__c
            WHERE EOI_Site_Payment__c IN :refs
            ORDER BY CreatedDate ASC
        ]) {
            if (!rowsByRef.containsKey(row.EOI_Site_Payment__c)) {
                rowsByRef.put(row.EOI_Site_Payment__c, new List<EOI_Public_Registration__c>());
            }
            rowsByRef.get(row.EOI_Site_Payment__c).add(row);
        }
        for (Checkout_Payment__c cp : pays) {
            List<EOI_Public_Registration__c> rows = rowsByRef.get(cp.Reference__c);
            Boolean allPromoted = rows != null && !rows.isEmpty();
            if (allPromoted) {
                for (EOI_Public_Registration__c row : rows) {
                    if (row.Status__c != 'Promoted' || row.PromotedEOI__c == null) {
                        allPromoted = false;
                        break;
                    }
                }
            }
            if (!allPromoted) {
                continue; // PromoteFailed or foreign rows - the sweeper/ops path owns it
            }
            Integer leadIdx = 0;
            for (Integer i = 0; i < rows.size(); i++) {
                if (rows[i].Id == (Id) cp.EOI_Site_Registration__c) {
                    leadIdx = i;
                    break;
                }
            }
            if (cp.Status__c != 'Captured') {
                // a hold: EOI on the payment now, receipt when the money is captured
                if (cp.Expression_of_Interest__c == null) {
                    try {
                        update new Checkout_Payment__c(Id = cp.Id, Expression_of_Interest__c = rows[leadIdx].PromotedEOI__c);
                    } catch (Exception e) {
                        // the sweeper's completeOne stamps it on its next pass
                    }
                }
                markEoisHeld(rows); // PAL-P1
                continue;
            }
            // PAL-P2: same shared builder as the sweeper, so the in-session path (only reached
            // when a channel captures immediately) can never drift from the 10-minute backstop
            Id unidentified = EoiReceiptBuilder.resolveUnidentifiedAccountId();
            if (unidentified == null) {
                continue; // stays Finalized - completeOne logs and retries
            }
            Set<Id> promotedEoiIds = new Set<Id>();
            for (EOI_Public_Registration__c row : rows) promotedEoiIds.add(row.PromotedEOI__c);
            Map<Id, String> entityByEoi = EoiReceiptBuilder.entityNamesByEoi(promotedEoiIds);
            List<Receipt__c> receipts = new List<Receipt__c>();
            for (EOI_Public_Registration__c row : rows) {
                receipts.add(EoiReceiptBuilder.build(
                    row.PromotedEOI__c, row.Amount__c, cp, unidentified, entityByEoi.get(row.PromotedEOI__c)));
            }
            Savepoint sp = Database.setSavepoint();
            try {
                insert receipts;
                update new Checkout_Payment__c(
                    Id = cp.Id,
                    Expression_of_Interest__c = rows[leadIdx].PromotedEOI__c,
                    Receipt__c = receipts[leadIdx].Id,
                    EOI_Site_State__c = PAY_STATE_COMPLETED
                );
            } catch (Exception e) {
                Database.rollback(sp); // stays Finalized - completeOne receipts it next run
            }
        }
    }

    /* PAL-P1 (10 Sep, Prateek's memo change 1). An EOI raised on a card HOLD is marked
       Payment Authorized with Skip_SLA__c, exactly as CheckoutEoiMaterializer marks the
       Sales/Broker ones: reporting can tell it from an unpaid EOI, and EOIVoidBatch and the
       payment reminders leave it alone - the money is already secured. Only a New /
       In Progress EOI is touched, so a captured or closed one is never rewritten.
       Idempotent; a failure is swallowed because the sweeper's completeOne calls this again
       on every pass until the receipt exists. */
    public static void markEoisHeld(List<EOI_Public_Registration__c> rows) {
        Set<Id> ids = new Set<Id>();
        for (EOI_Public_Registration__c row : rows) {
            if (row.PromotedEOI__c != null) {
                ids.add(row.PromotedEOI__c);
            }
        }
        if (ids.isEmpty()) {
            return;
        }
        List<Expressionofinterest__c> held = new List<Expressionofinterest__c>();
        for (Expressionofinterest__c eoi : [
            SELECT Id, Status__c, Skip_SLA__c FROM Expressionofinterest__c WHERE Id IN :ids
        ]) {
            if (eoi.Status__c == 'New' || eoi.Status__c == 'In Progress') {
                held.add(new Expressionofinterest__c(
                    Id = eoi.Id,
                    Status__c = EoiPaymentPolicy.STATUS_PAYMENT_AUTHORIZED,
                    Skip_SLA__c = true
                ));
            }
        }
        if (held.isEmpty()) {
            return;
        }
        try {
            update held;
        } catch (Exception e) {
            LoggerService.save(LoggerService.createApexLog(e, 'EOI Site Hold Marking', 'EOIService', 'markEoisHeld'));
        }
    }

    // ---------- returning customer: paid history & refund requests ----------

    /** One payment of this customer's, as shown on the returning-customer view. */
    public class RegistrationCard {
        @AuraEnabled public String reference         { get; set; }
        @AuraEnabled public String displayStatus     { get; set; } // Registered | Processing | Refund requested | Refunded | Cancelled
        @AuraEnabled public Boolean canRequestRefund { get; set; }
        @AuraEnabled public Boolean canCancel        { get; set; } // MEOI-CANCEL: a hold not yet captured
        @AuraEnabled public String displayNote       { get; set; } // MEOI-CANCEL2: the small print under the EOI number
        @AuraEnabled public Decimal amount           { get; set; }
        @AuraEnabled public Integer quantity         { get; set; }
        @AuraEnabled public String unitTypology      { get; set; }
        @AuraEnabled public String bedrooms          { get; set; }
        @AuraEnabled public Datetime paidAt          { get; set; }
        @AuraEnabled public List<String> eoiNumbers  { get; set; }
    }

    /** Everything this verified customer has paid for on this site, newest first.
     *  Identity is server-derived from the CURRENT verified registration row (UAE
     *  Pass UUID for residents, the OTP-verified email otherwise) - the client never
     *  supplies the identity key. Empty when the current row is not verified. */
    public static List<RegistrationCard> getMyRegistrations(Id registrationId) {
        List<RegistrationCard> out = new List<RegistrationCard>();
        Set<String> siblingIds = siblingRegistrationIds(registrationId);
        if (siblingIds.isEmpty()) {
            return out;
        }
        for (Checkout_Payment__c cp : [
            SELECT Reference__c, Status__c, Amount__c, CreatedDate,
                   EOI_Site_Selection__c, EOI_Site_State__c, EOI_Site_Refund_Requested__c, Dashboard_Status__c
            FROM Checkout_Payment__c
            WHERE EOI_Site_Registration__c IN :siblingIds
              AND (Status__c IN :PAID_STATUSES
                   OR EOI_Site_State__c IN (:PAY_STATE_FINALIZED, :PAY_STATE_COMPLETED, :PAY_STATE_REFUNDED))
              AND EOI_Site_State__c != :PAY_STATE_DUPLICATE
            ORDER BY CreatedDate DESC
            LIMIT 100
        ]) {
            out.add(toCard(cp));
        }
        Set<String> refs = new Set<String>();
        for (RegistrationCard c : out) {
            refs.add(c.reference);
        }
        Map<String, List<String>> numbers = eoiNumbersByRef(refs);
        for (RegistrationCard c : out) {
            c.eoiNumbers = numbers.containsKey(c.reference)
                ? numbers.get(c.reference) : new List<String>();
        }
        return out;
    }

    /** Marks one of this customer's captured payments as refund-requested. The
     *  request only flags the payment (EOI_Site_Refund_Requested__c): ops execute
     *  the money movement with the console Refund action, and the sweeper's
     *  reconciliation stage then closes the records. Idempotent. */
    public static RegistrationCard requestRefund(Id registrationId, String reference) {
        if (String.isBlank(reference)) {
            throw new EOIServiceException('Missing payment reference.');
        }
        Set<String> siblingIds = siblingRegistrationIds(registrationId);
        if (siblingIds.isEmpty()) {
            throw new EOIServiceException('Registration not found or not verified.');
        }
        // ownership check: the payment must belong to this verified identity
        List<Checkout_Payment__c> payments = [
            SELECT Id, Reference__c, Status__c, Amount__c, CreatedDate,
                   EOI_Site_Selection__c, EOI_Site_State__c, EOI_Site_Refund_Requested__c, Dashboard_Status__c
            FROM Checkout_Payment__c
            WHERE Reference__c = :reference AND EOI_Site_Registration__c IN :siblingIds
            LIMIT 1 FOR UPDATE
        ];
        if (payments.isEmpty()) {
            throw new EOIServiceException('Payment not found.');
        }
        Checkout_Payment__c cp = payments[0];
        if (cp.EOI_Site_Refund_Requested__c == null) {
            if (!PAID_STATUSES.contains(cp.Status__c)) {
                throw new EOIServiceException('This payment can no longer be refunded online. Please contact our team.');
            }
            if (cp.EOI_Site_State__c == PAY_STATE_DUPLICATE) {
                throw new EOIServiceException('This payment is already under review. Please contact our team.');
            }
            cp.EOI_Site_Refund_Requested__c = Datetime.now();
            update new Checkout_Payment__c(Id = cp.Id,
                EOI_Site_Refund_Requested__c = cp.EOI_Site_Refund_Requested__c);
            recordRefundRequested(registrationId, cp);
        }
        RegistrationCard card = toCard(cp);
        Map<String, List<String>> numbers = eoiNumbersByRef(new Set<String>{ cp.Reference__c });
        card.eoiNumbers = numbers.containsKey(cp.Reference__c)
            ? numbers.get(cp.Reference__c) : new List<String>();
        return card;
    }

    private static void recordRefundRequested(Id registrationId, Checkout_Payment__c cp) {
        try {
            RegistrationCard c = toCard(cp);
            for (EOI_Public_Registration__c r : [
                SELECT Id, Name, Source__c, Visitor__c FROM EOI_Public_Registration__c
                WHERE Id = :registrationId AND Visitor__c != null LIMIT 1
            ]) {
                String amount = c.amount == null ? '' : ' · AED ' + c.amount.setScale(0).format();
                EoiJourneyLog.log(r.Visitor__c, r.Id, r.Source__c, EoiJourneyLog.REFUND_REQUESTED,
                    cp.Reference__c + ' · ' + c.unitTypology + amount + ' · ' + r.Name);
                EoiSiteVisitorService.appendTrail(r.Visitor__c, 'Refund requested  ' + cp.Reference__c);
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Refund log failed: ' + e.getMessage());
        }
    }

    /** MEOI-CANCEL (11 Sep 2026). The customer cancels a registration whose payment is still
     *  a HOLD. The hold is voided at Checkout with the same call the console's Void action
     *  uses (CheckoutPaymentLinkService.voidPayment, which also writes Voided onto the row),
     *  and the records behind the payment are closed at once with the sweeper's own closure
     *  (EOI Cancelled, unpromoted rows detached, payment stamped) so the page reads
     *  Cancelled immediately rather than after the next sweep. A captured payment cannot be
     *  voided - that is the refund path. Idempotent: a second call returns the closed card. */
    public static RegistrationCard cancelRegistration(Id registrationId, String reference) {
        if (String.isBlank(reference)) {
            throw new EOIServiceException('Missing payment reference.');
        }
        Set<String> siblingIds = siblingRegistrationIds(registrationId);
        if (siblingIds.isEmpty()) {
            throw new EOIServiceException('Registration not found or not verified.');
        }
        // ownership check: the payment must belong to this verified identity
        List<Checkout_Payment__c> payments = [
            SELECT Id, Reference__c, Status__c, Amount__c, CreatedDate, Payment_Id__c,
                   EOI_Site_Selection__c, EOI_Site_State__c, EOI_Site_Refund_Requested__c, Dashboard_Status__c,
                   EOI_Site_Registration__c, EOI_Site_Batch__c, Expression_of_Interest__c, Receipt__c
            FROM Checkout_Payment__c
            WHERE Reference__c = :reference AND EOI_Site_Registration__c IN :siblingIds
            LIMIT 1
        ];
        if (payments.isEmpty()) {
            throw new EOIServiceException('Payment not found.');
        }
        Checkout_Payment__c cp = payments[0];
        if (cp.Status__c != 'Voided') {
            if (cp.Status__c != 'Authorized') {
                throw new EOIServiceException('This registration can no longer be cancelled online. Please contact our team.');
            }
            if (cp.EOI_Site_State__c == PAY_STATE_DUPLICATE || cp.EOI_Site_Refund_Requested__c != null) {
                throw new EOIServiceException('This payment is already under review. Please contact our team.');
            }
            if (String.isBlank(cp.Payment_Id__c)) {
                throw new EOIServiceException('This payment cannot be cancelled yet. Please try again in a few minutes.');
            }
            // callout first: nothing may be written in this transaction before it
            CheckoutPaymentLinkService.Result r = CheckoutPaymentLinkService.voidPayment(cp.Payment_Id__c);
            if (r == null || r.isSuccess != true) {
                throw new EOIServiceException('The hold could not be released. Please try again or contact our team.');
            }
            // The shared service runs WITH sharing and writes Voided only onto a row it can see;
            // the site's guest user sees no Checkout_Payment__c rows (seen live 11 Sep: the EOI
            // closed, the row stayed Authorized). This class runs without sharing, so stamp it here.
            cp.Status__c = 'Voided';
            cp.Last_Checkout_Status__c = 'Voided';
            cp.Last_Polled__c = System.now();
            Checkout_Payment__c stamp = new Checkout_Payment__c(Id = cp.Id, Status__c = 'Voided',
                Last_Checkout_Status__c = 'Voided', Last_Polled__c = cp.Last_Polled__c);
            if (String.isNotBlank(r.rawResponse)) {
                stamp.Raw_Payload__c = r.rawResponse.left(131000);
            }
            update stamp;
            recordCancelled(registrationId, cp);
        }
        if (cp.EOI_Site_State__c != PAY_STATE_REFUNDED) {
            EOISitePaymentSweeper.closeVoidedSitePayment(cp);
            cp.EOI_Site_State__c = PAY_STATE_REFUNDED;
        }
        RegistrationCard card = toCard(cp);
        Map<String, List<String>> numbers = eoiNumbersByRef(new Set<String>{ cp.Reference__c });
        card.eoiNumbers = numbers.containsKey(cp.Reference__c)
            ? numbers.get(cp.Reference__c) : new List<String>();
        return card;
    }

    private static void recordCancelled(Id registrationId, Checkout_Payment__c cp) {
        try {
            RegistrationCard c = toCard(cp);
            for (EOI_Public_Registration__c r : [
                SELECT Id, Name, Source__c, Visitor__c FROM EOI_Public_Registration__c
                WHERE Id = :registrationId AND Visitor__c != null LIMIT 1
            ]) {
                String amount = c.amount == null ? '' : ' · AED ' + c.amount.setScale(0).format();
                EoiJourneyLog.log(r.Visitor__c, r.Id, r.Source__c, 'Registration cancelled',
                    cp.Reference__c + ' · ' + c.unitTypology + amount + ' · hold released · ' + r.Name);
                EoiSiteVisitorService.appendTrail(r.Visitor__c, 'Registration cancelled  ' + cp.Reference__c);
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Cancel log failed: ' + e.getMessage());
        }
    }

    /** MEOI-STATUS: the Checkout Payment Console's status word for a payment (Dashboard_Status__c, a
     *  formula on Status__c). A formula on an in-memory row is not recomputed after the row's Status__c
     *  is changed in the same transaction (cancelRegistration stamps Voided and then builds the card),
     *  so when a closed status still carries an open word the value is re-read from the database. */
    private static final Set<String> CLOSED_STATUSES = new Set<String>{
        'Voided', 'Expired', 'Authorization Expired', 'Declined', 'Refunded', 'Partially Refunded' };
    private static final Set<String> OPEN_WORDS = new Set<String>{ 'Paid', 'Pending Payment' };
    private static String consoleStatusOf(Checkout_Payment__c cp) {
        String word = String.isBlank(cp.Dashboard_Status__c) ? null : cp.Dashboard_Status__c.trim();
        if (cp.Id != null && CLOSED_STATUSES.contains(cp.Status__c) && (word == null || OPEN_WORDS.contains(word))) {
            for (Checkout_Payment__c fresh : [SELECT Dashboard_Status__c FROM Checkout_Payment__c WHERE Id = :cp.Id LIMIT 1]) {
                word = String.isBlank(fresh.Dashboard_Status__c) ? null : fresh.Dashboard_Status__c.trim();
            }
        }
        return word;
    }

    private static RegistrationCard toCard(Checkout_Payment__c cp) {
        RegistrationCard c = new RegistrationCard();
        c.reference = cp.Reference__c;
        c.amount = cp.Amount__c;
        c.paidAt = cp.CreatedDate;
        try {
            SelectionSnapshot snap = (SelectionSnapshot)
                JSON.deserialize(cp.EOI_Site_Selection__c, SelectionSnapshot.class);
            if (snap != null && snap.lines != null && !snap.lines.isEmpty()) {
                Integer qty = 0;
                List<String> names = new List<String>();
                for (SnapshotLine line : snap.lines) {
                    qty += (line.quantity == null || line.quantity < 1) ? 1 : line.quantity;
                    String label = String.isBlank(line.unitTypology) ? line.unitType : line.unitTypology;
                    if (String.isNotBlank(label) && !names.contains(label)) {
                        names.add(label);
                    }
                }
                c.quantity = qty;
                c.unitTypology = names.isEmpty() ? null : String.join(names, ' + ');
                c.bedrooms = snap.lines[0].bedrooms;
            }
        } catch (Exception e) {
            // display fields stay null; amount, reference and status still render
        }
        // MEOI-STATUS2 (13 Sep 2026): for the customer, Checkout's own status is the truth about the
        // money. The site's EOI_Site_State__c = Refunded on its own is not - the 10 Sep hold-renewal
        // fault (EOI-3326) left rows closed on our side while the hold stayed live at Checkout
        // (e.g. EOI-FYZOUO: Authorized, EOI "Payment Authorized", site state Refunded), and those read
        // "Refunded"/"Paid" next to a Cancel button. They now read Registered like every live hold.
        Boolean refunded = cp.Status__c == 'Refunded' || cp.Status__c == 'Voided'
            || cp.Status__c == 'Partially Refunded';
        Boolean moneyHeld = cp.Status__c == 'Authorized' || cp.Status__c == 'Captured';
        // MEOI-STATUS (13 Sep 2026, Mridul): a closed payment reads exactly what the Checkout Payment
        // Console shows in its status column (Dashboard_Status__c - "Refunded" for a voided hold), so
        // the customer and MODON's ops see the same word; and no explanatory line under it. The
        // MEOI-CANCEL / MEOI-CANCEL2 wording ("Cancelled", "The hold on your card was released.")
        // remains only as the fallback when the console column is blank.
        String consoleStatus = consoleStatusOf(cp);
        if (cp.Status__c == 'Voided') {
            c.displayStatus = consoleStatus != null ? consoleStatus : 'Cancelled';
            c.displayNote = null;
        } else if (cp.Status__c == 'Expired' || cp.Status__c == 'Authorization Expired'
                || cp.Status__c == 'Declined') {
            c.displayStatus = consoleStatus != null ? consoleStatus : 'Cancelled';
            c.displayNote = null;
        } else if (refunded) {
            c.displayStatus = consoleStatus != null ? consoleStatus : 'Refunded';
            c.displayNote = null;
        } else if (cp.EOI_Site_Refund_Requested__c != null) {
            c.displayStatus = 'Refund requested';
        } else if (cp.EOI_Site_State__c == PAY_STATE_COMPLETED
                || cp.EOI_Site_State__c == PAY_STATE_FINALIZED
                || (moneyHeld && cp.EOI_Site_State__c == PAY_STATE_REFUNDED)) {
            c.displayStatus = 'Registered';
        } else {
            c.displayStatus = 'Processing'; // captured, registration write pending
        }
        // MEOI-CANCEL: a hold is cancelled (voided), never refunded; refund is for captured money
        c.canRequestRefund = cp.Status__c == 'Captured' && cp.EOI_Site_Refund_Requested__c == null;
        c.canCancel = cp.Status__c == 'Authorized' && cp.EOI_Site_Refund_Requested__c == null
            && cp.EOI_Site_State__c != PAY_STATE_DUPLICATE;
        return c;
    }

    /** Ids (as the payment rows store them) of every registration row belonging to
     *  the same verified identity as the given row. Empty when the row is missing
     *  or was never verified - history is never exposed to an unverified session. */
    private static Set<String> siblingRegistrationIds(Id registrationId) {
        Set<String> ids = new Set<String>();
        if (registrationId == null) {
            return ids;
        }
        List<EOI_Public_Registration__c> rows = [
            SELECT Id, Status__c, Source__c, CustomerType__c, Email__c, Mobile__c,
                   RegisteredEmail__c, RegisteredPhone__c, UAE_Pass_UUID__c,
                   VerifiedAt__c, VerifiedChannel__c
            FROM EOI_Public_Registration__c WHERE Id = :registrationId LIMIT 1
        ];
        if (rows.isEmpty()) {
            return ids;
        }
        EOI_Public_Registration__c me = rows[0];
        if (me.VerifiedAt__c == null
                || (me.Status__c != 'Verified' && me.Status__c != 'Promoted' && me.Status__c != 'PromoteFailed')) {
            return ids;
        }
        // identity is ONLY the identifier this session actually proved: the UAE
        // Pass UUID, the OTP'd email, or the OTP'd mobile. Matching on any other
        // field would let a form-typed (never verified) value read someone
        // else's history.
        List<EOI_Public_Registration__c> siblings;
        if (String.isNotBlank(me.UAE_Pass_UUID__c)) {
            siblings = [SELECT Id FROM EOI_Public_Registration__c
                WHERE UAE_Pass_UUID__c = :me.UAE_Pass_UUID__c AND Source__c = :me.Source__c LIMIT 500];
        } else if (me.CustomerType__c == 'Organization' && me.VerifiedChannel__c == 'Email'
                && String.isNotBlank(me.RegisteredEmail__c)) {
            siblings = [SELECT Id FROM EOI_Public_Registration__c
                WHERE RegisteredEmail__c = :me.RegisteredEmail__c AND CustomerType__c = 'Organization'
                  AND Source__c = :me.Source__c AND VerifiedAt__c != null LIMIT 500];
        } else if (me.CustomerType__c == 'Organization' && me.VerifiedChannel__c == 'SMS'
                && String.isNotBlank(me.RegisteredPhone__c)) {
            siblings = [SELECT Id FROM EOI_Public_Registration__c
                WHERE RegisteredPhone__c = :me.RegisteredPhone__c AND CustomerType__c = 'Organization'
                  AND Source__c = :me.Source__c AND VerifiedAt__c != null LIMIT 500];
        } else if (me.CustomerType__c == 'Individual' && me.VerifiedChannel__c == 'Email'
                && String.isNotBlank(me.Email__c)) {
            siblings = [SELECT Id FROM EOI_Public_Registration__c
                WHERE Email__c = :me.Email__c AND CustomerType__c = 'Individual'
                  AND Source__c = :me.Source__c AND VerifiedAt__c != null LIMIT 500];
        } else if (me.CustomerType__c == 'Individual' && me.VerifiedChannel__c == 'SMS'
                && String.isNotBlank(me.Mobile__c)) {
            siblings = [SELECT Id FROM EOI_Public_Registration__c
                WHERE Mobile__c = :me.Mobile__c AND CustomerType__c = 'Individual'
                  AND Source__c = :me.Source__c AND VerifiedAt__c != null LIMIT 500];
        } else {
            siblings = new List<EOI_Public_Registration__c>{ me };
        }
        for (EOI_Public_Registration__c s : siblings) {
            ids.add(String.valueOf(s.Id));
        }
        return ids;
    }

    // ---------- reload rerouting ----------

    /** The registration row's current server state, for rerouting a reloaded page. */
    public class JourneyState {
        @AuraEnabled public Boolean exists         { get; set; }
        @AuraEnabled public String status          { get; set; }
        @AuraEnabled public String verifiedChannel { get; set; }
    }

    public static JourneyState getJourneyState(Id registrationId) {
        JourneyState js = new JourneyState();
        js.exists = false;
        if (registrationId == null) {
            return js;
        }
        List<EOI_Public_Registration__c> rows = [
            SELECT Status__c, VerifiedChannel__c FROM EOI_Public_Registration__c
            WHERE Id = :registrationId LIMIT 1
        ];
        if (!rows.isEmpty()) {
            js.exists = true;
            js.status = rows[0].Status__c;
            js.verifiedChannel = rows[0].VerifiedChannel__c;
        }
        return js;
    }

    private static Checkout_Payment__c loadSitePayment(String reference) {
        if (String.isBlank(reference)) {
            return null;
        }
        List<Checkout_Payment__c> rows = [
            SELECT Id, Reference__c, Status__c, Amount__c, Payment_Id__c, Payment_Link_Id__c,
                   Last_Checkout_Status__c, Raw_Payload__c, Last_Polled__c, Error_Message__c,
                   Card_Last4__c, Card_Scheme__c, Card_Type__c, Card_Category__c, Card_BIN__c,
                   Card_Expiry__c, Issuer__c, Issuer_Country__c, Bank_Name__c, Account_Last4__c,
                   EOI_Site_Registration__c, EOI_Site_Selection__c, EOI_Site_State__c,
                   EOI_Site_Range__c, EOI_Site_Batch__c, Recovery_Alert_Sent__c
            FROM Checkout_Payment__c
            WHERE Reference__c = :reference AND EOI_Site_Registration__c != null
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0];
    }

    private static void recordPaymentCaptured(EOI_Public_Registration__c base, Checkout_Payment__c cp) {
        try {
            List<Checkout_Payment__c> full = [
                SELECT Amount__c, Card_Last4__c, Card_Scheme__c FROM Checkout_Payment__c WHERE Id = :cp.Id LIMIT 1
            ];
            String amount = full.isEmpty() || full[0].Amount__c == null ? '' : ' · AED ' + full[0].Amount__c.setScale(0).format();
            String card = full.isEmpty() || String.isBlank(full[0].Card_Last4__c) ? ''
                : ' · ' + (String.isBlank(full[0].Card_Scheme__c) ? 'card' : full[0].Card_Scheme__c) + ' •••• ' + full[0].Card_Last4__c;
            EoiJourneyLog.log(base.Visitor__c, base.Id, base.Source__c, EoiJourneyLog.PAYMENT_CAPTURED,
                cp.Reference__c + amount + card + ' · ' + base.Name);
            EoiSiteVisitorService.appendTrail(base.Visitor__c, 'Payment captured  ' + cp.Reference__c + amount);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Payment captured log failed: ' + e.getMessage());
        }
    }

    private static EOI_Public_Registration__c loadForPayment(String registrationId, Boolean lock) {
        String q = 'SELECT Id, Name, Visitor__c, Status__c, EOI_Range__c, BatchId__c, CustomerType__c, ResidentStatus__c, '
            + 'FirstName__c, LastName__c, Email__c, Mobile__c, Phone__c, EmiratesId__c, '
            + 'PassportNumber__c, UAE_Pass_UUID__c, CompanyName__c, TradeLicenseNumber__c, '
            + 'TradeLicenseExpiryDate__c, RegisteredEmail__c, RegisteredPhone__c, '
            + 'AuthorizedFirstName__c, AuthorizedLastName__c, AuthorizedEmail__c, AuthorizedPhone__c, '
            + 'VerificationRequest__c, VerifiedChannel__c, VerifiedAt__c, Source__c, '
            + 'UserAgent__c, Locale__c '
            + 'FROM EOI_Public_Registration__c WHERE Id = :registrationId LIMIT 1'
            + (lock ? ' FOR UPDATE' : '');
        List<EOI_Public_Registration__c> rows = Database.query(q);
        if (rows.isEmpty()) {
            throw new EOIServiceException('Registration not found.');
        }
        return rows[0];
    }

    /* MEOI-FRAME. The LWR site does not serve Visualforce; its Force.com twin on the SAME
       host does, so the container stays same-origin with the page and no CSP entry or new
       page is needed. This is the identical path eoiIdentityChooser mounts the card frame
       from, kept in one constant so the two can never drift apart. */
    private static final String FRAME_CONTAINER_PATH = '/eoivforcesite/apex/CheckoutFlowContainer';

    @TestVisible
    private static String frameReturnUrl() {
        String base = Site.getBaseSecureUrl();
        if (String.isBlank(base)) {
            base = URL.getOrgDomainUrl().toExternalForm();
        }
        return 'https://' + new URL(base).getHost() + FRAME_CONTAINER_PATH;
    }

    private static String sitePageUrl(String returnPath) {
        String siteBase = Site.getBaseSecureUrl();
        if (String.isBlank(siteBase)) {
            siteBase = URL.getOrgDomainUrl().toExternalForm();
        }
        return siteBase + returnPath;
    }

    private static String joinName(String first, String last) {
        return (String.isBlank(first) ? '' : first + ' ') + (last == null ? '' : last);
    }

    /** UAE Pass returns the mobile as bare digits (9715xxxxxxxx); the org-side
     *  Lead rule Mobile_Phone_Mandatory_Check requires a leading +, so resident
     *  promotion fails without this. Form paths are untouched - customers type
     *  the + themselves and those values already pass the rule. */
    @TestVisible
    private static String formatUaePassMobile(String mobile) {
        String cleaned = digits(mobile);
        if (String.isBlank(cleaned) || cleaned.startsWith('+')) {
            return cleaned;
        }
        return '+' + cleaned;
    }

    /** UAE Pass returns the Emirates ID undashed; the org-side Lead validation rule
     *  requires 784-XXXX-XXXXXXX-X, so promotion fails without this. */
    @TestVisible
    private static String formatEmiratesId(String eid) {
        if (String.isBlank(eid)) {
            return eid;
        }
        String d = eid.replaceAll('[^0-9]', '');
        if (d.length() == 15 && d.startsWith('784')) {
            return d.substring(0, 3) + '-' + d.substring(3, 7) + '-' + d.substring(7, 14) + '-' + d.substring(14);
        }
        return eid;
    }

    // ---------- validation helpers ----------

    private static void requireBlankless(Map<String, String> fields) {
        for (String label : fields.keySet()) {
            if (String.isBlank(fields.get(label))) {
                throw new EOIServiceException(label + ' is required.');
            }
        }
    }

    private static void requireEmail(String email) {
        if (String.isBlank(email) || !EMAIL_RE.matcher(email.trim()).matches()) {
            throw new EOIServiceException('Enter a valid email address.');
        }
    }

    /* MEOI-PHONE. Form paths validate the number the way the rest of the org does:
       international format, leading +, country code not starting with 0, 8-15 digits -
       the same regex as the public EOI journey (eoiPublicJourney.isValidPhone) and a
       superset of the Lead rule Mobile_Phone_Mandatory_Check (^\+(?:[0-9] ?){6,14}[0-9]$),
       so a registration can never fail promotion on the number. Spaces and dashes the
       customer typed are dropped first. UAE Pass keeps digits() below: it returns bare
       digits and formatUaePassMobile adds the +. */
    private static final Pattern PHONE_RE = Pattern.compile('^\\+[1-9][0-9]{7,14}$');
    private static String phone(String raw) {
        String cleaned = raw == null ? '' : raw.replaceAll('[^0-9+]', '');
        if (!PHONE_RE.matcher(cleaned).matches()) {
            throw new EOIServiceException('Please enter a valid phone number with country code (e.g., +9715XXXXXXXX). Country code must not start with 0.');
        }
        return cleaned;
    }

    private static String digits(String phone) {
        if (String.isBlank(phone)) {
            return phone;
        }
        String cleaned = phone.replaceAll('[^0-9+]', '');
        if (cleaned.replaceAll('[^0-9]', '').length() < 7) {
            throw new EOIServiceException('Enter a valid phone number.');
        }
        return truncate(cleaned, 40);
    }

    private static String truncate(String s, Integer max) {
        return (s != null && s.length() > max) ? s.substring(0, max) : s;
    }

    private static String normalizeLocale(String locale) {
        return locale == 'ar' ? 'ar' : 'en_US';
    }
}