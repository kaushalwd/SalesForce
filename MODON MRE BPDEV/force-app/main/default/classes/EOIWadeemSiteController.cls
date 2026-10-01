/**
 * Guest-facing entry points for the Wadeem EOI microsite pages.
 * Thin by design: validation and DML live in EOIService, OAuth in
 * UAEPassService. Errors surface as AuraHandledException with safe text.
 * @author Aurelix
 */
public without sharing class EOIWadeemSiteController {

    /** Per-site source tag. Requests arriving through the ADIB network stamp their own
     *  source so each microsite keeps a separate registration universe (the UAE Pass
     *  dedupe and My Registrations queries scope by Source__c). Tests and every other
     *  context resolve to the original Wadeem value, so existing behavior is unchanged. */
    private static String SOURCE {
        get {
            if (SOURCE == null) {
                SOURCE = 'Wadeem Microsite';
                try {
                    Id netId = Network.getNetworkId();
                    if (netId != null) {
                        List<Network> nets = [SELECT Name FROM Network WHERE Id = :netId];
                        if (!nets.isEmpty() && nets[0].Name != null && nets[0].Name.containsIgnoreCase('ADIB')) {
                            SOURCE = 'ADIB Microsite';
                        }
                    }
                } catch (Exception e) {
                    // keep the Wadeem default
                }
            }
            return SOURCE;
        }
        set;
    }

    /** Verified identity summary returned to the page after UAE Pass. */
    public class UaePassResult {
        @AuraEnabled public Id registrationId  { get; set; }
        @AuraEnabled public String fullNameEn  { get; set; }
        @AuraEnabled public String emiratesIdMasked { get; set; }
        @AuraEnabled public String email       { get; set; }
        @AuraEnabled public String mobile      { get; set; }
    }

    @AuraEnabled
    public static String getUaePassAuthorizeUrl() {
        try {
            return UAEPassService.getAuthorizeUrl(UAEPassService.generateState());
        } catch (Exception e) {
            throw fail('UAE Pass is unavailable right now. Please try again.');
        }
    }

    @AuraEnabled
    public static UaePassResult completeUaePass(String code, String state, String userAgent, String locale) {
        try {
            UAEPassUserInfo u = UAEPassService.completeLogin(code, state);
            Id regId = EOIService.saveUaePassIdentity(u, SOURCE, userAgent, locale);
            UaePassResult r = new UaePassResult();
            r.registrationId = regId;
            r.fullNameEn = u.fullNameEn;
            r.emiratesIdMasked = maskEid(u.emiratesId);
            r.email = u.email;
            r.mobile = u.mobile;
            return r;
        } catch (UAEPassException e) {
            throw fail('UAE Pass verification did not complete. Please try again.');
        } catch (Exception e) {
            throw fail('Something went wrong. Please try again.');
        }
    }

    @AuraEnabled
    public static Id submitIdentity(EOIService.IdentityRequest req) {
        try {
            return EOIService.submitIdentity(req, SOURCE);
        } catch (EOIService.EOIServiceException e) {
            throw fail(e.getMessage());  // validation text is user-safe
        } catch (Exception e) {
            throw fail('Something went wrong. Please try again.');
        }
    }

    /** Sign-in first (MSC-247): the code goes out before the form. */
    @AuraEnabled
    public static EOIService.SignInStart beginSignIn(String channel, String target, String honeypot, String userAgent, String locale, String recaptchaToken) {
        try {
            return EOIService.beginSignIn(channel, target, honeypot, SOURCE, userAgent, locale, recaptchaToken);
        } catch (EOIService.EOIServiceException e) {
            throw fail(e.getMessage());
        } catch (Exception e) {
            throw fail('Could not send the code. Please try again.');
        }
    }

    @AuraEnabled
    public static Id completeDetails(Id registrationId, String sessionId, EOIService.IdentityRequest req) {
        try {
            return EOIService.completeDetails(registrationId, sessionId, req);
        } catch (EOIService.EOIServiceException e) {
            throw fail(e.getMessage());
        } catch (Exception e) {
            throw fail('Something went wrong. Please try again.');
        }
    }

    @AuraEnabled
    public static EOIService.SignInState getSignInState(Id registrationId, String sessionId) {
        try {
            return EOIService.getSignInState(registrationId, sessionId);
        } catch (Exception e) {
            throw fail('Something went wrong. Please try again.');
        }
    }

    @AuraEnabled
    public static VerificationService.VerificationResult startOtp(Id registrationId, String channel) {
        try {
            return EOIService.startOtp(registrationId, channel);
        } catch (EOIService.EOIServiceException e) {
            throw fail(e.getMessage());
        } catch (Exception e) {
            throw fail('Could not send the code. Please try again.');
        }
    }

    @AuraEnabled
    public static VerificationService.VerificationResult resendOtp(Id registrationId, Id verificationRequestId) {
        try {
            return EOIService.resendOtp(registrationId, verificationRequestId);
        } catch (EOIService.EOIServiceException e) {
            throw fail(e.getMessage());
        } catch (Exception e) {
            throw fail('Could not resend the code. Please try again.');
        }
    }

    @AuraEnabled
    public static VerificationService.VerificationResult verifyOtp(Id registrationId, Id verificationRequestId, String code) {
        try {
            return EOIService.verifyOtp(registrationId, verificationRequestId, code);
        } catch (EOIService.EOIServiceException e) {
            throw fail(e.getMessage());
        } catch (Exception e) {
            throw fail('Verification failed. Please try again.');
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<EOIService.TypologyTile> getTypologies(Id projectId) {
        try {
            return EOIService.getTypologies(projectId);
        } catch (Exception e) {
            throw fail('Could not load the collection. Please try again.');
        }
    }

    // Card pay-first (MSC-237/238): each residence type is a separate payment; the
    // registration rows for a type are written only after its payment captures, so
    // there is no unpaid submit path on this site.
    private static final String RETURN_PATH = '/wadeem-register';

    /** VAPT EXT-03 follow-up (13 Sep 2026): every entry point that acts on a registration must be
     *  called by the tab that signed it in - the session id `beginSignIn` issued. Record ids are
     *  guessable identifiers, never credentials. Reads answer with "nothing" on a mismatch; actions
     *  refuse with one generic line. */
    private static final String SESSION_MESSAGE = 'Your session has expired. Please sign in again.';
    private static void requireSession(Id registrationId, String sessionId) {
        if (registrationId == null) {
            return; // nothing to protect: the service treats a null id as "nothing to do", as before
        }
        if (!EOIService.ownsRegistration(registrationId, sessionId)) {
            throw fail(SESSION_MESSAGE);
        }
    }

    @AuraEnabled
    public static EOIService.PaymentStart startCardPayment(Id registrationId, Id projectId,
            Id rangeId, Integer quantity, Long elapsedMs, String honeypot, Integer unitIndex, String recaptchaToken, String sessionId) {
        requireSession(registrationId, sessionId);
        try {
            return EOIService.startCardPayment(registrationId, projectId, rangeId, quantity,
                elapsedMs, honeypot, RETURN_PATH, unitIndex, recaptchaToken);
        } catch (EOIService.EOIServiceException e) {
            throw fail(e.getMessage());
        } catch (Exception e) {
            throw fail('The payment could not be started. Please try again.');
        }
    }

    /** MSC-243: same call, embedded. Returns a Checkout payment session so the card form
     *  mounts on the microsite instead of redirecting the customer to the hosted page.
     *  Every guard and the server-side price are shared with startCardPayment above. */
    @AuraEnabled
    public static EOIService.PaymentStart startCardPaymentSession(Id registrationId, Id projectId,
            Id rangeId, Integer quantity, Long elapsedMs, String honeypot, Integer unitIndex, String recaptchaToken, String sessionId) {
        requireSession(registrationId, sessionId);
        try {
            return EOIService.startCardPaymentSession(registrationId, projectId, rangeId, quantity,
                elapsedMs, honeypot, RETURN_PATH, unitIndex, recaptchaToken);
        } catch (EOIService.EOIServiceException e) {
            throw fail(e.getMessage());
        } catch (Exception e) {
            throw fail('The payment could not be started. Please try again.');
        }
    }

    @AuraEnabled
    public static List<EOIService.PaymentLineState> getPaymentState(Id registrationId, String sessionId) {
        try {
            return EOIService.getPaymentState(registrationId, sessionId); // VAPT EXT-03: the tab's session id is required
        } catch (Exception e) {
            throw fail('The payment status could not be checked. Please try again.');
        }
    }

    @AuraEnabled
    public static EOIService.PaymentStatus confirmCardPayment(String reference) {
        try {
            return EOIService.confirmCardPayment(reference);
        } catch (Exception e) {
            throw fail('The payment status could not be checked. Please try again.');
        }
    }

    @AuraEnabled
    public static EOIService.SubmitResult finalizeCardPayment(String reference) {
        try {
            return EOIService.finalizeCardPayment(reference);
        } catch (EOIService.EOIServiceException e) {
            throw fail(e.getMessage());
        } catch (Exception e) {
            throw fail('Something went wrong. Please try again.');
        }
    }

    @AuraEnabled
    public static List<EOIService.RegistrationCard> getMyRegistrations(Id registrationId, String sessionId) {
        if (!EOIService.ownsRegistration(registrationId, sessionId)) {
            return new List<EOIService.RegistrationCard>(); // VAPT: not this tab's registration - nothing to show
        }
        try {
            return EOIService.getMyRegistrations(registrationId);
        } catch (Exception e) {
            throw fail('Your registrations could not be loaded. Please try again.');
        }
    }

    @AuraEnabled
    public static EOIService.RegistrationCard requestRefund(Id registrationId, String reference, String sessionId) {
        requireSession(registrationId, sessionId);
        try {
            return EOIService.requestRefund(registrationId, reference);
        } catch (EOIService.EOIServiceException e) {
            throw fail(e.getMessage());
        } catch (Exception e) {
            throw fail('The refund request could not be submitted. Please try again.');
        }
    }

    /** MEOI-CANCEL: void a held payment and close its registration (see EOIService). */
    @AuraEnabled
    public static EOIService.RegistrationCard cancelRegistration(Id registrationId, String reference, String sessionId) {
        requireSession(registrationId, sessionId);
        try {
            return EOIService.cancelRegistration(registrationId, reference);
        } catch (EOIService.EOIServiceException e) {
            throw fail(e.getMessage());
        } catch (Exception e) {
            throw fail('The registration could not be cancelled. Please try again.');
        }
    }

    /** Best effort: a missed activity must never block the journey. */
    @AuraEnabled
    public static void recordSelection(Id registrationId, List<EOIService.UnitSelection> lines, String sessionId) {
        requireSession(registrationId, sessionId);
        try {
            EOIService.recordSelection(registrationId, lines);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'recordSelection failed: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static EOIService.JourneyState getJourneyState(Id registrationId, String sessionId) {
        if (!EOIService.ownsRegistration(registrationId, sessionId)) {
            return EOIService.getJourneyState(null); // VAPT: reads as "no such journey"
        }
        try {
            return EOIService.getJourneyState(registrationId);
        } catch (Exception e) {
            throw fail('Something went wrong. Please try again.');
        }
    }

    /** MEOI-ACT. Activity diary batch from the page. Void and silent by design: nothing
     *  about logging may ever surface to the customer or fail the journey. */
    @AuraEnabled
    public static void recordActivity(Id registrationId, String sessionId, String batchKey, String eventsJson) {
        try {
            EoiSiteActivityService.record(registrationId, sessionId, batchKey, eventsJson, SOURCE);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'recordActivity failed: ' + e.getMessage());
        }
    }

    /* MEOI-CFG. Runtime switches, read fresh on every page load so a Setup edit takes
       effect without republishing the sites. cacheable=false on purpose: a cached read
       would reintroduce exactly the staleness this method exists to remove. */
    @AuraEnabled(cacheable=false)
    public static EOIService.SiteConfig getSiteConfig() {
        return EOIService.getSiteConfig();
    }

    private static String maskEid(String eid) {
        if (String.isBlank(eid) || eid.length() < 7) {
            return eid;
        }
        return eid.substring(0, 3) + '*********' + eid.substring(eid.length() - 3);
    }

    private static AuraHandledException fail(String message) {
        AuraHandledException e = new AuraHandledException(message);
        e.setMessage(message);
        return e;
    }
}