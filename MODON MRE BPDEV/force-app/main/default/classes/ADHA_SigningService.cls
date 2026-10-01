/**********************************************************************************************************************
* Name               : ADHA_SigningService
* Description        : The signing step and its guardrails, all failing closed. Envelopes land in Modon's LIVE
*                      DocuSign account: there is no demo config and the 'sandbox' record points at production too.
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           Aurelix                     23 Aug 2026     Initial.
**********************************************************************************************************************/
public without sharing class ADHA_SigningService {

    private static final String TEST_MARKER = '[TEST bpdev] ';
    /** Signing_Allowed_Emirates_Ids__c set to this clears everybody. See assertAllowed. */
    @TestVisible private static final String WILDCARD = '*';

    public class SigningException extends Exception {}

    /** Everything a provider needs to raise one envelope. Built here so guardrails cannot be skipped. */
    public class SignRequest {
        public Id reservationId;
        public String reservationName;
        public String signerName;
        public String signerEmail;
        public String clientUserId;
        public String documentBase64;
        public String documentName;
        public String emailSubject;
        public String returnUrl;
    }

    /** One downloadable copy of the undertaking, named by kind rather than by record id. */
    public class CopyRef {
        @AuraEnabled public String kind;
        @AuraEnabled public String fileName;
        @AuraEnabled public Boolean available;
    }

    public class CopyDownload {
        @AuraEnabled public String kind;
        @AuraEnabled public String fileName;
        @AuraEnabled public String base64;
    }

    public static final String COPY_UNDERTAKING = 'undertaking';
    public static final String COPY_SIGNED = 'signed';

    /** What the journey needs to render the signing step. */
    public class SigningView {
        @AuraEnabled public String signingUrl;
        @AuraEnabled public String envelopeId;
        @AuraEnabled public String status;
        @AuraEnabled public Boolean completed;
    }

    @TestVisible private static ADHA_SigningProvider provider;

    /**
     * Only the exact word DocuSign reaches Modon's live account; anything else gets the stub,
     * so reaching the real account is a deliberate act rather than an oversight.
     */
    @TestVisible
    private static ADHA_SigningProvider provider() {
        if (provider == null) {
            provider = settings().Signing_Provider__c == 'DocuSign'
                ? (ADHA_SigningProvider) new ADHA_DocuSignProvider()
                : (ADHA_SigningProvider) new ADHA_StubSigningProvider();
        }
        return provider;
    }

    /* ---------- entry points ---------- */

    /**
     * Renders the document, raises an envelope if none exists yet, and returns a captive URL.
     * Safe to call again: a reload reuses the existing envelope rather than raising a second deed.
     */
    public static SigningView begin(ADHA_Applicant__c applicant, ADHA_Reservation__c reservation) {
        assertEnabled();
        assertSignable(reservation);
        assertAllowed(applicant);

        // Every callout first, every write afterwards: Apex forbids a callout once the
        // transaction has written, so do not file the document before the DocuSign calls.
        ADHA_UndertakingDocument.Rendered document = ADHA_UndertakingDocument.render(reservation.Id);
        SignRequest request = requestFor(applicant, reservation, document);

        String envelopeId = reservation.DocuSign_Envelope_Id__c;
        Boolean raised = false;
        if (String.isBlank(envelopeId)) {
            envelopeId = provider().send(request);
            if (String.isBlank(envelopeId)) {
                throw new SigningException('No envelope id came back for ' + reservation.Name);
            }
            raised = true;
        }
        String url = provider().signingUrl(envelopeId, request);

        // ---- no more callouts past this line ----
        ADHA_UndertakingDocument.store(reservation.Id, document);
        // Here rather than in render(), which runs above the two callouts and cannot write. An
        // Adobe outage that nothing records is one nobody chases, and pdf.co is metered.
        if (document != null && document.viaFallback == true) {
            ADHA_JourneyLog.queue(
                applicant.Id, reservation.Id, ADHA_JourneyLog.RENDER_FAILED,
                'Adobe failed, rendered by pdf.co instead'
                    + (String.isBlank(document.fallbackReason) ? '' : ': ' + document.fallbackReason)
            );
            ADHA_JourneyLog.flush();
        }
        if (raised) {
            // Stamped only where an envelope is actually raised; record() also runs from
            // outcome(), and stamping there would date an old envelope to its last status check.
            reservation.Envelope_Raised_On__c = System.now();
            // Deliberately leaves Status__c on Submitted, which the sweeper, payment batch and
            // guards all expect; DocuSign_Status__c carries the envelope state instead.
            record(reservation, envelopeId, 'sent', null);
        }
        holdSessionOpen(applicant);

        SigningView view = new SigningView();
        view.envelopeId = envelopeId;
        view.signingUrl = url;
        view.status = reservation.DocuSign_Status__c;
        view.completed = false;
        return view;
    }

    /**
     * Asks the provider what actually happened and writes the outcome. The return URL is only
     * a hint that something finished; the envelope itself is the sole authority.
     */
    public static SigningView outcome(ADHA_Applicant__c applicant, ADHA_Reservation__c reservation) {
        assertEnabled();
        if (String.isBlank(reservation.DocuSign_Envelope_Id__c)) {
            throw new SigningException('Nothing to check: ' + reservation.Name + ' has no envelope');
        }

        // DocuSign's own word, lowercase, which is not what our picklist stores.
        String reported = provider().status(reservation.DocuSign_Envelope_Id__c);
        String stored = picklistStatus(reported);

        SigningView view = new SigningView();
        view.envelopeId = reservation.DocuSign_Envelope_Id__c;
        view.status = stored;
        view.completed = reported == 'completed';

        if (view.completed && reservation.Status__c != 'Completed') {
            // Callout before any write, and a failure here must not stop the reservation completing:
            // the signature is the legal act, the PDF is a copy DocuSign can still hand over later.
            String signedCopy = String.isBlank(reservation.Signed_Document_Id__c)
                ? provider().downloadSigned(reservation.DocuSign_Envelope_Id__c)
                : null;
            complete(applicant, reservation, reported, signedCopy);
        } else if (stored != null && stored != reservation.DocuSign_Status__c) {
            record(reservation, reservation.DocuSign_Envelope_Id__c, reported, null);
        }
        return view;
    }

    /**
     * Keeps the customer signed in across the trip to DocuSign: the tab navigates away, so no
     * heartbeat slides the five minute idle window. Widened only here, still capped by the hard expiry.
     */
    private static void holdSessionOpen(ADHA_Applicant__c applicant) {
        Decimal configured = settings().Signing_Session_Minutes__c;
        Integer minutes = configured == null ? 45 : Integer.valueOf(configured);
        if (minutes <= 0 || applicant == null) {
            return;
        }
        // Re-read: never assume a caller's query selected these fields.
        List<ADHA_Applicant__c> live = [
            SELECT Id, Session_Expires_At__c, Session_Hard_Expiry__c
            FROM ADHA_Applicant__c WHERE Id = :applicant.Id LIMIT 1
        ];
        if (live.isEmpty()) {
            return;
        }
        Datetime until = System.now().addMinutes(minutes);
        if (live[0].Session_Hard_Expiry__c != null && until > live[0].Session_Hard_Expiry__c) {
            until = live[0].Session_Hard_Expiry__c;
        }
        if (live[0].Session_Expires_At__c != null && live[0].Session_Expires_At__c >= until) {
            return;
        }
        try {
            update new ADHA_Applicant__c(Id = applicant.Id, Session_Expires_At__c = until);
        } catch (Exception e) {
            // Never blocks the hand off. Worst case is the return trip needing a fresh sign-in,
            // which the resume check now recovers from anyway.
            System.debug(LoggingLevel.ERROR, 'Could not extend the signing session: ' + e.getMessage());
        }
    }

    /**
     * Voids the envelope BEFORE anything in the release writes; Apex refuses a callout after DML.
     * A completed envelope cannot be voided, so that case is only logged on the timeline.
     */
    public static void releaseEnvelope(ADHA_Applicant__c applicant, String reason) {
        if (applicant == null || settings().Signing_Enabled__c != true) {
            return;
        }
        List<ADHA_Reservation__c> rows = [
            SELECT Id, Name, Applicant__c, DocuSign_Envelope_Id__c, DocuSign_Status__c
            FROM ADHA_Reservation__c
            WHERE Applicant__c = :applicant.Id AND Applicant_Lock_Key__c != NULL
            LIMIT 1
        ];
        if (rows.isEmpty() || String.isBlank(rows[0].DocuSign_Envelope_Id__c)) {
            return;
        }
        ADHA_Reservation__c res = rows[0];

        if (res.DocuSign_Status__c == 'Signed') {
            ADHA_JourneyLog.log(
                applicant.Id, res.Id, ADHA_JourneyLog.DEED_SUPERSEDED,
                'Envelope ' + res.DocuSign_Envelope_Id__c + ' is completed and cannot be voided. '
                    + 'The signed deed for this villa remains valid at DocuSign and needs handling '
                    + 'outside the journey. Reason: ' + reason
            );
            return;
        }

        try {
            Boolean done = provider().voidEnvelope(res.DocuSign_Envelope_Id__c, reason);
            if (done) {
                voided.add(res.Id);
            }
            ADHA_JourneyLog.log(
                applicant.Id, res.Id,
                done ? ADHA_JourneyLog.VOIDED : ADHA_JourneyLog.SIGNING_FAILED,
                done
                    ? 'Envelope ' + res.DocuSign_Envelope_Id__c + ' voided. Reason: ' + reason
                    : 'DocuSign refused to void ' + res.DocuSign_Envelope_Id__c
                        + '. Villa released anyway.'
            );
        } catch (Exception e) {
            // Never blocks the release. A DocuSign outage must not trap the customer's villa.
            ADHA_JourneyLog.log(
                applicant.Id, res.Id, ADHA_JourneyLog.SIGNING_FAILED,
                'Voiding ' + res.DocuSign_Envelope_Id__c + ' failed: ' + e.getMessage()
                    + '. Villa released anyway.'
            );
        }
    }

    /** Reservations voided in this transaction, so release() can stamp the picklist it cannot know. */
    @TestVisible private static Set<Id> voided = new Set<Id>();

    public static Boolean wasVoided(Id reservationId) {
        return reservationId != null && voided.contains(reservationId);
    }

    /** Withdraws an envelope. The way a test send is cleaned up out of Modon's live account. */
    public static Boolean withdraw(ADHA_Reservation__c reservation, String reason) {
        if (String.isBlank(reservation.DocuSign_Envelope_Id__c)) {
            return false;
        }
        Boolean done = provider().voidEnvelope(reservation.DocuSign_Envelope_Id__c, reason);
        if (done) {
            record(reservation, reservation.DocuSign_Envelope_Id__c, 'voided', null);
        }
        return done;
    }

    /**
     * Voids at DocuSign and writes nothing, so batch callers can keep every write behind
     * every callout instead of hitting "uncommitted work pending" on the second row.
     */
    public static Boolean voidOnly(String envelopeId, String reason) {
        if (String.isBlank(envelopeId) || settings().Signing_Enabled__c != true) {
            return false;
        }
        return provider().voidEnvelope(envelopeId, reason);
    }

    /* ---------- guardrails, all failing closed ---------- */

    private static void assertEnabled() {
        if (settings().Signing_Enabled__c != true) {
            throw new SigningException('Signing is switched off');
        }
    }

    private static void assertSignable(ADHA_Reservation__c reservation) {
        if (reservation == null) {
            throw new SigningException('No reservation to sign');
        }
        if (reservation.Status__c != 'Submitted') {
            throw new SigningException(
                'Only a submitted reservation can be signed, and ' + reservation.Name
                + ' is ' + reservation.Status__c
            );
        }
    }

    /**
     * Outside production only listed Emirates IDs may sign; blank means nobody, a lone `*` everybody.
     * Not Signing_Is_Production__c: that also strips the test marker off envelopes in Modon's LIVE account.
     */
    @TestVisible
    private static void assertAllowed(ADHA_Applicant__c applicant) {
        if (settings().Signing_Is_Production__c == true) {
            return;
        }
        String allowed = settings().Signing_Allowed_Emirates_Ids__c;
        if (String.isBlank(allowed)) {
            throw new SigningException(
                'No Emirates ID is cleared for test signing, so nobody is. '
                + 'Set Signing_Allowed_Emirates_Ids__c first'
            );
        }
        String theirs = normalise(applicant.Emirates_ID__c);
        for (String entry : allowed.split(';')) {
            // Before normalise, which strips everything that is not a digit and would turn this
            // into an empty string that can never match.
            if (entry.trim() == WILDCARD) {
                return;
            }
            if (normalise(entry) == theirs && String.isNotBlank(theirs)) {
                return;
            }
        }
        throw new SigningException(
            'This applicant is not on the test signing list, and these envelopes are real'
        );
    }

    /* ---------- building the request ---------- */

    @TestVisible
    private static SignRequest requestFor(
        ADHA_Applicant__c applicant, ADHA_Reservation__c reservation,
        ADHA_UndertakingDocument.Rendered document
    ) {
        SignRequest request = new SignRequest();
        request.reservationId = reservation.Id;
        request.reservationName = reservation.Name;
        request.signerName = applicant.Customer_Name__c;
        request.signerEmail = signerEmail(applicant);
        // Never blank. A blank clientUserId turns a captive signer into one DocuSign emails.
        request.clientUserId = String.valueOf(applicant.Id);
        request.documentBase64 = document.base64;
        request.documentName = marker() + document.fileName;
        request.emailSubject = marker() + 'West Baniyas undertaking ' + reservation.Name;
        request.returnUrl = returnUrl();

        if (String.isBlank(request.clientUserId)) {
            throw new SigningException('Refusing to send without a clientUserId');
        }
        if (String.isBlank(request.signerEmail)) {
            throw new SigningException('Refusing to send without a signer address');
        }
        if (String.isBlank(request.documentBase64)) {
            throw new SigningException('Refusing to send an empty document');
        }
        return request;
    }

    /**
     * DocuSign requires an address even for embedded signing and no applicant has one. Unique per
     * person so the audit trail means something, on a domain that cannot receive mail.
     */
    @TestVisible
    private static String signerEmail(ADHA_Applicant__c applicant) {
        String domain = settings().Signer_Email_Domain__c;
        if (String.isBlank(domain)) {
            throw new SigningException('Signer_Email_Domain__c is not set');
        }
        String reference = String.isBlank(applicant.Application_Number__c)
            ? String.valueOf(applicant.Id)
            : applicant.Application_Number__c;
        return 'wb-' + reference.toLowerCase() + '@' + domain;
    }

    /** Marks a test envelope so it is identifiable among the real ones in the live account. */
    @TestVisible
    private static String marker() {
        return settings().Signing_Is_Production__c == true ? '' : TEST_MARKER;
    }

    @TestVisible
    private static String returnUrl() {
        String base = settings().Signing_Return_Base_Url__c;
        if (String.isBlank(base)) {
            base = Site.getBaseUrl();
        }
        if (String.isBlank(base)) {
            throw new SigningException('Signing_Return_Base_Url__c is not set');
        }
        // The journey's own page: an LWR site 404s a made-up path like /signing-return.
        // No session token: DocuSign stores this URL and it reaches history and referrers.
        return base.removeEnd('/') + '/';
    }

    /* ---------- writing what happened ---------- */

    private static void record(
        ADHA_Reservation__c reservation, String envelopeId, String status, String reservationStatus
    ) {
        String stored = picklistStatus(status);
        reservation.DocuSign_Envelope_Id__c = envelopeId;
        // Unknown statuses leave the field alone rather than failing the write on a restricted picklist.
        if (stored != null) {
            reservation.DocuSign_Status__c = stored;
        }
        if (String.isNotBlank(reservationStatus)) {
            reservation.Status__c = reservationStatus;
        }
        reservation.Journey_Log__c = ADHA_ReservationService.logLine(
            reservation.Journey_Log__c, 'Envelope ' + envelopeId + ' ' + status
        );
        update reservation;

        String event = eventFor(status);
        if (event != null) {
            ADHA_JourneyLog.log(reservation.Applicant__c, reservation.Id, event, 'Envelope ' + envelopeId);
        }
    }

    /** Only the states worth a line on the beneficiary's timeline. The rest are noise. */
    @TestVisible
    private static String eventFor(String status) {
        if (status == 'sent') { return ADHA_JourneyLog.ENVELOPE_SENT; }
        if (status == 'declined') { return ADHA_JourneyLog.DECLINED; }
        if (status == 'voided') { return ADHA_JourneyLog.VOIDED; }
        return null;
    }

    private static void complete(
        ADHA_Applicant__c applicant, ADHA_Reservation__c reservation, String status, String signedCopy
    ) {
        // The return URL, the resume backstop and the batch race here for one signature. Lock
        // after every callout and right before the write, so the loser sees the winner's work.
        ADHA_Reservation__c locked = [
            SELECT Id, Status__c, Signed_Document_Id__c
            FROM ADHA_Reservation__c
            WHERE Id = :reservation.Id
            FOR UPDATE
        ];
        if (locked.Status__c == 'Completed') {
            // File the copy only if it is genuinely still missing, so a first pass whose download
            // failed is repaired rather than left short.
            if (String.isBlank(locked.Signed_Document_Id__c) && String.isNotBlank(signedCopy)) {
                locked.Signed_Document_Id__c = fileSignedCopy(reservation, signedCopy);
                update locked;
                reservation.Signed_Document_Id__c = locked.Signed_Document_Id__c;
                ADHA_JourneyLog.log(
                    applicant.Id, reservation.Id, ADHA_JourneyLog.COPY_STORED,
                    'Executed copy filed against the reservation'
                );
            }
            return;
        }

        reservation.DocuSign_Status__c = picklistStatus(status);
        reservation.Status__c = 'Completed';
        reservation.Completed_On__c = System.now();
        reservation.Journey_Log__c = ADHA_ReservationService.logLine(
            reservation.Journey_Log__c,
            'Signed, envelope ' + reservation.DocuSign_Envelope_Id__c
        );
        if (String.isNotBlank(signedCopy)) {
            reservation.Signed_Document_Id__c = fileSignedCopy(reservation, signedCopy);
        } else {
            reservation.Journey_Log__c = ADHA_ReservationService.logLine(
                reservation.Journey_Log__c,
                'Signed copy not retrieved; ADHA_SignedCopyBatch will retry'
            );
        }
        update reservation;
        ADHA_ReservationService.advanceStage(applicant, 'Completed', false);

        ADHA_JourneyLog.queue(
            applicant.Id, reservation.Id, ADHA_JourneyLog.SIGNED,
            'Envelope ' + reservation.DocuSign_Envelope_Id__c
        );
        ADHA_JourneyLog.queue(
            applicant.Id, reservation.Id,
            String.isNotBlank(signedCopy) ? ADHA_JourneyLog.COPY_STORED : ADHA_JourneyLog.SIGNING_FAILED,
            String.isNotBlank(signedCopy)
                ? 'Executed copy filed against the reservation'
                : 'Signed, but the executed copy did not come back. ADHA_SignedCopyBatch will retry.'
        );
        ADHA_JourneyLog.flush();
        // Re-read with every field the message needs; a field missing from a caller's SELECT
        // throws on read and has cost a rolled-back confirm before.
        ADHA_ReservationSmsSender.confirmedAndSigned(applicant, forMessage(reservation.Id));
    }

    /** Everything the confirmation message reads, in one place, so no caller has to know the list. */
    private static ADHA_Reservation__c forMessage(Id reservationId) {
        return [
            SELECT Id, Name, Additional_Amount__c, Additional_Payment_Due__c,
                   Unit__r.Plot_UID__c, Unit__r.Villa_Type__c, Unit__r.Rooms_Count__c
            FROM ADHA_Reservation__c WHERE Id = :reservationId LIMIT 1
        ];
    }

    /** The executed copy from DocuSign, or null if it is still not available. For the retry batch. */
    public static String signedCopyFor(String envelopeId) {
        return provider().downloadSigned(envelopeId);
    }

    /** Files the executed PDF alongside the generated one, so the reservation carries both. */
    public static Id fileSignedCopy(ADHA_Reservation__c reservation, String base64) {
        Attachment file = new Attachment(
            ParentId = reservation.Id,
            Name = fileNameFor(COPY_SIGNED, reservation.Name),
            ContentType = 'application/pdf',
            Description = 'West Baniyas Undertaking ' + reservation.Name + ' (signed)',
            Body = EncodingUtil.base64Decode(base64)
        );
        insert file;
        return file.Id;
    }

    /* ---------- copies the customer may download ---------- */

    /**
     * Downloads are named by kind, never record id: the server picks the file from the applicant's
     * own reservation, so the client can never fetch an arbitrary file in the org.
     */
    public static List<CopyRef> copies(ADHA_Reservation__c reservation) {
        List<CopyRef> out = new List<CopyRef>();
        out.add(copyRef(COPY_UNDERTAKING, reservation.Name, reservation.Undertaking_Document_Id__c));
        out.add(copyRef(COPY_SIGNED, reservation.Name, reservation.Signed_Document_Id__c));
        return out;
    }

    private static CopyRef copyRef(String kind, String reservationName, String documentId) {
        CopyRef ref = new CopyRef();
        ref.kind = kind;
        ref.fileName = fileNameFor(kind, reservationName);
        ref.available = String.isNotBlank(documentId);
        return ref;
    }

    public static CopyDownload download(ADHA_Reservation__c reservation, String kind) {
        String documentId = kind == COPY_SIGNED
            ? reservation.Signed_Document_Id__c
            : (kind == COPY_UNDERTAKING ? reservation.Undertaking_Document_Id__c : null);
        if (String.isBlank(documentId)) {
            throw new SigningException('No ' + kind + ' copy is available for ' + reservation.Name);
        }
        List<Attachment> files = [
            SELECT Id, Name, Body FROM Attachment WHERE Id = :documentId LIMIT 1
        ];
        if (files.isEmpty()) {
            throw new SigningException('The ' + kind + ' copy for ' + reservation.Name + ' is missing');
        }
        CopyDownload out = new CopyDownload();
        out.kind = kind;
        out.fileName = files[0].Name;
        out.base64 = EncodingUtil.base64Encode(files[0].Body);
        return out;
    }

    private static String fileNameFor(String kind, String reservationName) {
        return kind == COPY_SIGNED
            ? 'West-Baniyas-Undertaking-' + reservationName + '-signed.pdf'
            : 'West-Baniyas-Undertaking-' + reservationName + '.pdf';
    }

    /* ---------- helpers ---------- */

    /**
     * Maps DocuSign's lowercase words to the restricted picklist, where completed becomes Signed.
     * Anything unrecognised returns null so the caller leaves the field alone.
     */
    @TestVisible
    private static String picklistStatus(String reported) {
        if (String.isBlank(reported)) {
            return null;
        }
        Map<String, String> known = new Map<String, String>{
            'sent' => 'Sent',
            'delivered' => 'Delivered',
            'completed' => 'Signed',
            'signed' => 'Signed',
            'declined' => 'Declined',
            'voided' => 'Voided'
        };
        return known.get(reported.toLowerCase());
    }

    private static ADHA_Reservation__c reload(Id reservationId) {
        return [
            SELECT Id, Name, Applicant__c, Status__c, DocuSign_Envelope_Id__c, DocuSign_Status__c,
                   Completed_On__c, Journey_Log__c,
                   Undertaking_Document_Id__c, Signed_Document_Id__c
            FROM ADHA_Reservation__c WHERE Id = :reservationId LIMIT 1
        ];
    }

    private static String normalise(String emiratesId) {
        return emiratesId == null ? '' : emiratesId.replaceAll('[^0-9]', '');
    }

    private static ADHA_Setting__mdt settings() {
        return ADHA_JourneyController.settings();
    }
}