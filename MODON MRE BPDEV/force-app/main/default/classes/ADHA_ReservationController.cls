/**********************************************************************************************************************
* Name               : ADHA_ReservationController
* Description        : The @AuraEnabled surface for the reservation step. Deliberately thin - every method resolves the
*                      customer through ADHA_JourneyController.resolveApplicant and hands off to ADHA_ReservationService.
* Usage              : adhaBaniyasJourney and masterplanUnitSelector LWCs on the ADHA Baniyas Experience Cloud site.
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           Aurelix                     16 Aug 2026     Initial.
**********************************************************************************************************************/
public without sharing class ADHA_ReservationController {
    /** The session token is the only identity accepted; a plot UID or record Id from the browser
     *  is a request, never a claim. */
    /** Read-only. Prices the villa and proves the customer may have it; writes nothing, so a
     *  customer browsing does not take stock off anyone else's map. */
    @AuraEnabled
    public static ADHA_ReservationService.ReservationView quote(String token, String plotUid) {
        return ADHA_ReservationService.quote(ADHA_JourneyController.resolveApplicant(token), plotUid);
    }

    /** The only call that creates a reservation. Sent when the customer accepts the undertaking,
     *  carrying everything the commitment consists of so it is one transaction. */
    @AuraEnabled
    public static ADHA_ReservationService.ReservationView confirm(
        String token,
        String plotUid,
        String paymentMethod,
        String language
    ) {
        return ADHA_ReservationService.confirm(
            ADHA_JourneyController.resolveApplicant(token), plotUid, paymentMethod, language);
    }

    /** Pressing Change villa gives the villa straight back, hold or confirmed, rather than making
     *  everyone else wait out the hold or the rest of the seven days. */
    @AuraEnabled
    public static void releaseCurrent(String token) {
        ADHA_Applicant__c applicant = ADHA_JourneyController.resolveApplicant(token);
        // First, and outside the service: the void is a callout and everything below it writes.
        ADHA_SigningService.releaseEnvelope(applicant, 'Customer changed villa');
        ADHA_ReservationService.releaseCurrent(applicant);
    }

    @AuraEnabled
    public static void cancel(String token) {
        ADHA_Applicant__c applicant = ADHA_JourneyController.resolveApplicant(token);
        ADHA_SigningService.releaseEnvelope(applicant, 'Customer cancelled the reservation');
        ADHA_ReservationService.cancel(applicant);
    }

    /** Not cacheable: this is what a refresh mid-flow reads to decide which screen to land on, and
     *  a cached copy would put the customer back on a screen they had already left. */
    @AuraEnabled
    public static ADHA_ReservationService.ReservationView currentReservation(String token) {
        return ADHA_ReservationService.current(ADHA_JourneyController.resolveApplicant(token));
    }

    /** Prepares the undertaking, raises an envelope if there is not one already, and hands back a
     *  captive signing URL. Safe to call again: a reload reuses the envelope, not a second deed. */
    @AuraEnabled
    public static ADHA_SigningService.SigningView beginSigning(String token) {
        ADHA_Applicant__c applicant = ADHA_JourneyController.resolveApplicant(token);
        try {
            return ADHA_SigningService.begin(applicant, liveFor(applicant));
        } catch (Exception e) {
            throw signingFailure(applicant, e, 'Starting signature');
        }
    }

    /** Asks DocuSign what actually happened and writes the outcome. The browser coming back is a
     *  hint, never evidence, so this is the only thing that may complete a reservation. */
    @AuraEnabled
    public static ADHA_SigningService.SigningView signingOutcome(String token) {
        // Inside the try, not before it: a session that lapsed at DocuSign used to throw here and
        // leave no trace of why a signed undertaking never registered.
        ADHA_Applicant__c applicant;
        try {
            applicant = ADHA_JourneyController.resolveApplicant(token);
            return ADHA_SigningService.outcome(applicant, liveFor(applicant));
        } catch (Exception e) {
            throw signingFailure(applicant, e, 'Reading the signature outcome');
        }
    }

    /** Which copies this applicant may download, and whether each one exists yet. */
    @AuraEnabled
    public static List<ADHA_SigningService.CopyRef> undertakingCopies(String token) {
        ADHA_Applicant__c applicant = ADHA_JourneyController.resolveApplicant(token);
        return ADHA_SigningService.copies(liveFor(applicant));
    }

    /** Serves a copy through Apex - a ContentDistribution URL works for anyone who has it, and these
     *  documents carry PII. kind is 'undertaking' or 'signed'; the token decides whose file is read. */
    @AuraEnabled
    public static ADHA_SigningService.CopyDownload downloadCopy(String token, String kind) {
        ADHA_Applicant__c applicant = ADHA_JourneyController.resolveApplicant(token);
        try {
            return ADHA_SigningService.download(liveFor(applicant), kind);
        } catch (Exception e) {
            throw signingFailure(applicant, e, 'Downloading the ' + kind + ' copy');
        }
    }

    /** Translates signing exceptions to the stable MSG_ code the client understands; the real
     *  reason stays in the log. */
    private static AuraHandledException signingFailure(
        ADHA_Applicant__c applicant, Exception e, String during
    ) {
        // A debug log nobody is watching is how a stuck customer stays invisible, so the failure
        // goes on the beneficiary's timeline where ADHA will actually meet it.
        if (applicant != null) {
            // logImmediate, not log: this method throws on the next line, and the rollback that
            // follows would take an ordinary Task insert with it.
            ADHA_JourneyLog.logImmediate(
                applicant.Id, null, ADHA_JourneyLog.SIGNING_FAILED,
                during + ' failed: ' + e.getTypeName() + ': ' + e.getMessage()
                    + ' | line ' + e.getLineNumber()
            );
        }
        // Logged before the early return below: with no applicant to hang a task on, this used to
        // exit having written nothing - the session lapse that hid a completed signature.
        System.debug(LoggingLevel.ERROR,
            during + ' failed: ' + e.getTypeName() + ': ' + e.getMessage()
            + ' | line ' + e.getLineNumber()
            + ' | applicant ' + (applicant == null ? 'unresolved, likely an expired session' : String.valueOf(applicant.Id)));
        if (e instanceof AuraHandledException) {
            return (AuraHandledException) e;
        }
        AuraHandledException wrapped = new AuraHandledException('MSG_SIGNING_FAILED');
        wrapped.setMessage('MSG_SIGNING_FAILED');
        return wrapped;
    }

    /** The reservation the signing step acts on, with the fields the service writes. */
    private static ADHA_Reservation__c liveFor(ADHA_Applicant__c applicant) {
        List<ADHA_Reservation__c> rows = [
            SELECT Id, Name, Applicant__c, Status__c, DocuSign_Envelope_Id__c, DocuSign_Status__c,
                   Completed_On__c, Journey_Log__c,
                   Undertaking_Document_Id__c, Signed_Document_Id__c
            FROM ADHA_Reservation__c
            WHERE Applicant__c = :applicant.Id AND Released_On__c = NULL
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];
        if (rows.isEmpty()) {
            throw new AuraHandledException('MSG_GENERIC');
        }
        return rows[0];
    }
}