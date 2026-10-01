/**********************************************************************************************************************
* Name               : ADHA_ReservationService
* Description        : Reservation rules for the ADHA Baniyas microsite: holds, changes, undertakings, releases.
*                      Owns inventory only; identity and the session gate belong to ADHA_JourneyController.
* Usage              : ADHA_ReservationController (the @AuraEnabled surface) and ADHA_ReservationSweeper (expiry).
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           Aurelix                     16 Aug 2026     Initial. Concurrency enforced by the two unique lock keys,
*                                                             not by an Apex availability check.
* 1.1           Aurelix                     17 Aug 2026     quote() takes a soft hold (Hold_Minutes__c, default 10);
*                                                             confirm() upgrades that hold in place.
* 1.2           Aurelix                     22 Aug 2026     Soft launch: windowRefusal refuses hold and confirm before
*                                                             the SLA check, so a null window reads as "not open yet".
**********************************************************************************************************************/
public without sharing class ADHA_ReservationService {
    /** A reservation is live while its lock keys are populated; the unique indexes enforce that,
     *  so statuses are labels, not a second source of truth. */
    private static final Set<String> RELEASED_STATUSES = new Set<String>{ 'Expired', 'Released', 'Cancelled' };

    public class ReservationView {
        @AuraEnabled public String reservationNumber;
        @AuraEnabled public String status;
        @AuraEnabled public String plotUid;
        @AuraEnabled public Integer masterplanNumber;
        @AuraEnabled public Decimal unitPrice;
        @AuraEnabled public Decimal approvedAmount;
        @AuraEnabled public Decimal additionalAmount;
        @AuraEnabled public String paymentMethod;
        @AuraEnabled public Date additionalPaymentDue;
        @AuraEnabled public Boolean undertakingAccepted = false;
        @AuraEnabled public String undertakingType;
        @AuraEnabled public String undertakingVersion;
        @AuraEnabled public Integer attempt;
        @AuraEnabled public Datetime slaEnd;
        @AuraEnabled public Integer daysRemaining;
        @AuraEnabled public String docuSignStatus;
        /** Null once signed. The client counts this down. */
        @AuraEnabled public Datetime holdExpiresAt;
    }

    /* ---------- read ---------- */

    public static ReservationView current(ADHA_Applicant__c applicant) {
        ADHA_Reservation__c live = liveReservation(applicant.Id);
        return live == null ? null : toView(live, applicant);
    }

    /* ---------- quote ---------- */

    /** Kept so ADHA_ReservationController.quoteUnit and the LWC need no rename. */
    public static ReservationView quote(ADHA_Applicant__c applicant, String plotUid) {
        return hold(applicant, plotUid);
    }

    /**
     * Takes a soft hold on a villa for Hold_Minutes__c while the customer reads the undertaking.
     * The lock is the unique Unit_Lock_Key__c index, so the insert wins or loses the race outright.
     */
    public static ReservationView hold(ADHA_Applicant__c applicant, String plotUid) {
        assertWindowOpen(applicant);
        assertDeclarationAccepted(applicant);

        // Applicant before unit, matching confirm(). Any other order lets the two deadlock.
        lockApplicant(applicant.Id);
        ADHA_Unit__c unit = lockUnit(plotUid);

        ADHA_Reservation__c live = liveReservation(applicant.Id);
        Boolean sameUnit = live != null && live.Unit__r != null && live.Unit__r.Plot_UID__c == plotUid;

        // Before assertBookable, which would refuse them the villa they are already holding: the
        // hold set Status__c to 'Held', so Is_Selectable__c is false for them too.
        if (sameUnit) {
            if (live.Undertaking_Accepted__c != true) {
                live.Hold_Expires_At__c = holdEnd();
                update live;
            }
            return toView(live, applicant);
        }

        // Inside the unit's row lock, so this cannot race a competing hold.
        releaseLapsedHoldOn(unit.Id);
        unit = lockUnit(plotUid);
        assertBookable(applicant, unit);

        if (live != null) {
            // A swap from the map consumes the change allowance too, or a signed reservation
            // could be swapped without limit.
            assertChangesRemaining(applicant, live);
            // Safe before the insert: if that fails, the transaction rolls this back with it.
            release(live, 'Changed Unit', applicant);
        }

        Datetime now = System.now();
        ADHA_Reservation__c res = new ADHA_Reservation__c(
            Applicant__c = applicant.Id,
            Unit__c = unit.Id,
            Attempt_Number__c = applicant.Current_Attempt__c == null
                ? 1
                : Integer.valueOf(applicant.Current_Attempt__c),
            SLA_Start__c = applicant.SLA_Start__c,
            SLA_End__c = applicant.SLA_End__c,
            Status__c = 'Held',
            Hold_Expires_At__c = holdEnd(),
            Unit_Price__c = unit.Price__c,
            Additional_Amount__c = additionalFor(unit.Price__c, applicant.Approved_Loan_Amount__c),
            // Recorded now so the undertaking screen can name the right document before signing.
            Undertaking_Type__c = ADHA_JourneyController.undertakingTypeFor(applicant.Service_Type__c),
            Undertaking_Accepted__c = false,
            DocuSign_Status__c = 'Not Sent',
            Reservation_Date__c = now,
            Unit_Lock_Key__c = String.valueOf(unit.Id),
            Applicant_Lock_Key__c = String.valueOf(applicant.Id),
            Journey_Log__c = logLine(null, 'Held ' + plotUid)
        );

        try {
            insert res;
        } catch (DmlException e) {
            throw collisionFor(e, unit.Id);
        }

        // Is_Selectable__c needs Status__c = 'Available', so this alone takes the villa off every
        // other customer's map. 'Held' rather than 'Reserved' so ADHA can tell the two apart.
        update new ADHA_Unit__c(Id = unit.Id, Status__c = 'Held', Active_Reservation__c = res.Id);

        advanceStage(applicant, 'Unit Selected', false);
        ADHA_JourneyLog.log(applicant.Id, res.Id, unit.Id, ADHA_JourneyLog.VILLA_HELD, 'Villa ' + plotUid);
        return toView(reload(res.Id), applicant);
    }

    /**
     * Releases the current hold or signed reservation the moment the customer asks to change.
     * Attempt and SLA_End__c are left alone, so the window does not restart.
     */
    public static void releaseCurrent(ADHA_Applicant__c applicant) {
        ADHA_Reservation__c live = liveReservation(applicant.Id);
        if (live == null) {
            return;
        }
        assertReleasable(applicant, live);
        assertChangesRemaining(applicant, live);
        release(live, 'Changed Unit', applicant);
        advanceStage(applicant, 'Exploring', true);
        // release() only queues its audit row; without this the villa change never reaches the log.
        ADHA_JourneyLog.flush();
    }

    /** Frees a lapsed, unsigned hold so the contender can take the villa. */
    private static void releaseLapsedHoldOn(Id unitId) {
        List<ADHA_Reservation__c> rows = [
            SELECT Id, Applicant__c, Status__c, Unit__c, Journey_Log__c, Hold_Expires_At__c,
                   Undertaking_Accepted__c
            FROM ADHA_Reservation__c
            WHERE Unit_Lock_Key__c = :String.valueOf(unitId)
              AND Undertaking_Accepted__c = false
              AND Hold_Expires_At__c != NULL
              AND Hold_Expires_At__c < :System.now()
            LIMIT 1
        ];
        if (!rows.isEmpty()) {
            release(rows[0], 'Hold Expired');
        }
    }

    private static Datetime holdEnd() {
        return System.now().addMinutes(holdMinutes());
    }

    private static Integer holdMinutes() {
        Decimal value = ADHA_JourneyController.settings().Hold_Minutes__c;
        return value == null ? 10 : Integer.valueOf(value);
    }

    /* ---------- confirm: the one write ---------- */

    /**
     * Signs the undertaking, upgrading the customer's own hold into a reservation. Idempotent on
     * the confirmed villa; a different villa is a change, keeping the same attempt and SLA_End__c.
     */
    public static ReservationView confirm(
        ADHA_Applicant__c applicant,
        String plotUid,
        String paymentMethod,
        String language
    ) {
        assertWindowOpen(applicant);
        assertDeclarationAccepted(applicant);

        // Applicant first, unit second, always. Updating a master-detail child locks its parent,
        // so any other order would let two paths through here deadlock each other.
        lockApplicant(applicant.Id);

        ADHA_Reservation__c live = liveReservation(applicant.Id);
        Integer attempt = applicant.Current_Attempt__c == null ? 1 : Integer.valueOf(applicant.Current_Attempt__c);
        Datetime slaStart = applicant.SLA_Start__c;
        Datetime slaEnd = applicant.SLA_End__c;

        Boolean sameUnit = live != null && live.Unit__r != null && live.Unit__r.Plot_UID__c == plotUid;

        if (sameUnit && live.Undertaking_Accepted__c == true) {
            // Already signed. A dropped connection and a retry is not an error.
            return toView(live, applicant);
        }

        if (live != null && !sameUnit) {
            assertChangesRemaining(applicant, live);
            // A change keeps the opportunity and the clock it was granted under.
            attempt = live.Attempt_Number__c == null ? attempt : Integer.valueOf(live.Attempt_Number__c);
            slaStart = live.SLA_Start__c;
            slaEnd = live.SLA_End__c;
            // Safe before the insert: an exception below rolls this back with the rest.
            release(live, 'Changed Unit', applicant);
        }

        ADHA_Unit__c unit = lockUnit(plotUid);
        // sameUnit means they already hold it, so the villa reads as Held rather than Available
        // and assertBookable would refuse the customer their own hold.
        if (!sameUnit) {
            assertBookable(applicant, unit);
        }

        String lang = language == 'ar' ? 'ar' : 'en';
        // Consent evidence for what was signed; ADHA_UndertakingDocument.assertVersion checks
        // against this record. Resolved from the applicant's service type, never from the client.
        ADHA_JourneyController.Declaration undertaking =
            ADHA_JourneyController.getUndertaking(lang, applicant.Service_Type__c);

        Decimal additional = additionalFor(unit.Price__c, applicant.Approved_Loan_Amount__c);
        String method = additional > 0 ? paymentMethod : 'Not Applicable';
        if (!methodValues().contains(method)) {
            throw new AuraHandledException('MSG_PAYMENT_METHOD');
        }

        Datetime now = System.now();
        // Upgrade the hold in place so its lock keys never leave the unique index. A lapsed hold
        // is fine: lockUnit plus assertBookable have just proved nobody else took the villa.
        ADHA_Reservation__c res = sameUnit ? live : new ADHA_Reservation__c();
        // Master-detail, and not writeable on update - setting it even to its own value throws.
        if (!sameUnit) {
            res.Applicant__c = applicant.Id;
        }
        res.Unit__c = unit.Id;
        res.Attempt_Number__c = attempt;
        res.SLA_Start__c = slaStart;
        res.SLA_End__c = slaEnd;
        res.Status__c = 'Submitted';
        res.Hold_Expires_At__c = null;
        res.Unit_Price__c = unit.Price__c;
        res.Additional_Amount__c = additional;
        res.Payment_Method__c = method;
        res.Undertaking_Type__c = ADHA_JourneyController.undertakingTypeFor(applicant.Service_Type__c);
        res.Undertaking_Accepted__c = true;
        res.Undertaking_Accepted_On__c = now;
        res.Undertaking_Version__c = undertaking.version;
        res.Undertaking_Language__c = lang;
        res.DocuSign_Status__c = 'Not Sent';
        res.Reservation_Date__c = res.Reservation_Date__c == null ? now : res.Reservation_Date__c;
        res.Submitted_On__c = now;
        res.Confirmation_Date__c = now;
        // Only when something is actually owed - a due date against a zero balance would show
        // the customer a deadline they cannot act on.
        res.Additional_Payment_Due__c = additional > 0 ? dueDate(now) : null;
        // String.valueOf always yields the 18-character Id form. 15- and 18-character forms are
        // different strings to the unique index, so mixing them silently defeats the lock.
        res.Unit_Lock_Key__c = String.valueOf(unit.Id);
        res.Applicant_Lock_Key__c = String.valueOf(applicant.Id);
        res.Journey_Log__c = logLine(
            res.Journey_Log__c,
            'Confirmed ' + plotUid + ' (' + undertaking.version + ', ' + lang + ')'
        );

        try {
            upsert res;
        } catch (DmlException e) {
            throw collisionFor(e, unit.Id);
        }

        // Is_Selectable__c reads Status__c, not Active_Reservation__c, so setting just the lookup
        // would leave the villa bookable on every other customer's map.
        update new ADHA_Unit__c(Id = unit.Id, Status__c = 'Reserved', Active_Reservation__c = res.Id);

        advanceStage(applicant, 'Confirmed', false);
        ADHA_JourneyLog.log(
            applicant.Id, res.Id, unit.Id, ADHA_JourneyLog.RESERVATION_CONFIRMED,
            'Villa ' + plotUid + ', undertaking ' + undertaking.version + ' in ' + lang
                + ', additional ' + additional + ' due ' + res.Additional_Payment_Due__c
        );
        // No message here: only the signature confirms, and ADHA_SigningService.complete sends the
        // single message once the envelope comes back.
        return toView(reload(res.Id), applicant);
    }

    /* ---------- release ---------- */

    /**
     * Gives the villa back inside the existing window. Deliberately does not consume an
     * opportunity: the second one is tied to ADHA sending a second invitation, not to us.
     */
    public static void cancel(ADHA_Applicant__c applicant) {
        ADHA_Reservation__c live = liveReservation(applicant.Id);
        if (live == null) {
            return;
        }
        assertReleasable(applicant, live);
        release(live, 'Cancelled');
        advanceStage(applicant, 'Exploring', true);
        ADHA_JourneyLog.flush();
    }

    /**
     * Nulls both lock keys so the unique indexes free up, and hands the villa back. Callable by the
     * sweeper with any Release_Reason__c value.
     */
    /**
     * Releases and, for a villa the customer had confirmed, texts them. A separate overload on
     * purpose: the batch and sweeper call the two-arg form, where a future cannot be chained.
     */
    public static void release(ADHA_Reservation__c res, String reason, ADHA_Applicant__c applicant) {
        Boolean wasCommitted = res != null && res.Undertaking_Accepted__c == true;
        release(res, reason);
        // An unsigned hold being swapped is browsing, not a loss. Only a confirmed villa is worth
        // telling somebody about.
        if (reason == 'Changed Unit' && wasCommitted) {
            ADHA_ReservationSmsSender.released(applicant, res);
        }
    }

    public static void release(ADHA_Reservation__c res, String reason) {
        Datetime now = System.now();
        res.Status__c = reason == 'Cancelled' ? 'Cancelled' : (reason == 'SLA Expiry' ? 'Expired' : 'Released');
        res.Release_Reason__c = reason;
        res.Released_On__c = now;
        res.Unit_Lock_Key__c = null;
        res.Applicant_Lock_Key__c = null;
        // Set here rather than by the void itself: the callout runs before this row is loaded, so
        // writing it there would be a lost update the moment this line saves.
        if (ADHA_SigningService.wasVoided(res.Id)) {
            res.DocuSign_Status__c = 'Voided';
        }
        res.Journey_Log__c = logLine(res.Journey_Log__c, 'Released: ' + reason);
        update res;

        // Queued, not written: the sweepers call this in a loop and already spend two statements a
        // row. Flushed by the caller at its own transaction boundary.
        ADHA_JourneyLog.queue(
            res.Applicant__c, res.Id, res.Unit__c, eventFor(reason), 'Reason: ' + reason
        );

        if (res.Unit__c != null) {
            update new ADHA_Unit__c(Id = res.Unit__c, Status__c = 'Available', Active_Reservation__c = null);
        }
    }

    /** Release_Reason__c is ADHA's vocabulary; the timeline needs the customer's. */
    @TestVisible
    private static String eventFor(String reason) {
        if (reason == 'Cancelled') { return ADHA_JourneyLog.CANCELLED; }
        if (reason == 'Changed Unit') { return ADHA_JourneyLog.VILLA_CHANGED; }
        if (reason == 'Hold Expired') { return ADHA_JourneyLog.HOLD_EXPIRED; }
        if (reason == 'SLA Expiry') { return ADHA_JourneyLog.SLA_EXPIRED; }
        if (reason == 'Additional Payment Not Received') { return ADHA_JourneyLog.PAYMENT_EXPIRED; }
        return 'Reservation released';
    }

    /* ---------- helpers ---------- */

    private static ADHA_Reservation__c liveReservation(Id applicantId) {
        List<ADHA_Reservation__c> rows = [
            SELECT Id, Name, Applicant__c, Status__c, Unit__c, Unit__r.Plot_UID__c,
                   Unit__r.Masterplan_Number__c,
                   // Read by ADHA_ReservationSmsSender; a field left out of the SELECT throws
                   // SObjectException on read.
                   Unit__r.Villa_Type__c, Unit__r.Rooms_Count__c,
                   Unit_Price__c, Additional_Amount__c, Payment_Method__c, Additional_Payment_Due__c,
                   Undertaking_Accepted__c, Undertaking_Type__c, Undertaking_Version__c,
                   Undertaking_Language__c, Attempt_Number__c, SLA_Start__c, SLA_End__c,
                   DocuSign_Status__c, Journey_Log__c, Hold_Expires_At__c, Reservation_Date__c
            FROM ADHA_Reservation__c
            WHERE Applicant__c = :applicantId AND Applicant_Lock_Key__c != NULL
            LIMIT 1
        ];
        return rows.isEmpty() ? null : rows[0];
    }

    private static ADHA_Reservation__c reload(Id reservationId) {
        return [
            SELECT Id, Name, Applicant__c, Status__c, Unit__c, Unit__r.Plot_UID__c,
                   Unit__r.Masterplan_Number__c,
                   // Read by ADHA_ReservationSmsSender; a field left out of the SELECT throws
                   // SObjectException on read.
                   Unit__r.Villa_Type__c, Unit__r.Rooms_Count__c,
                   Unit_Price__c, Additional_Amount__c, Payment_Method__c, Additional_Payment_Due__c,
                   Undertaking_Accepted__c, Undertaking_Type__c, Undertaking_Version__c,
                   Undertaking_Language__c, Attempt_Number__c, SLA_Start__c, SLA_End__c,
                   DocuSign_Status__c, Journey_Log__c, Hold_Expires_At__c, Reservation_Date__c
            FROM ADHA_Reservation__c
            WHERE Id = :reservationId
            LIMIT 1
        ];
    }

    private static void lockApplicant(Id applicantId) {
        // Assigned only because Apex will not take a bare SOQL expression as a statement; the
        // result is unused, the row lock is the whole point.
        List<ADHA_Applicant__c> ignored = [
            SELECT Id FROM ADHA_Applicant__c WHERE Id = :applicantId LIMIT 1 FOR UPDATE
        ];
        System.debug(LoggingLevel.FINEST, ignored.size());
    }

    /** Same row as lockUnit but without FOR UPDATE: a quote must not hold a lock while a
     *  customer reads. */
    private static ADHA_Unit__c readUnit(String plotUid) {
        if (String.isBlank(plotUid)) {
            throw new AuraHandledException('MSG_GENERIC');
        }
        List<ADHA_Unit__c> rows = [
            SELECT Id, Plot_UID__c, Masterplan_Number__c, Status__c, Price__c, Category_Type__c,
                   Eligible_Service__c, Is_Selectable__c, Pinned_Applicant__c, Active_Reservation__c,
                   Expose_To__c
            FROM ADHA_Unit__c
            WHERE Plot_UID__c = :plotUid
            LIMIT 1
        ];
        if (rows.isEmpty()) {
            throw new AuraHandledException('MSG_GENERIC');
        }
        return rows[0];
    }

    /** The three reasons a villa can be refused, in one place so the quote and the confirm can
     *  never disagree about who may have what. */
    private static void assertBookable(ADHA_Applicant__c applicant, ADHA_Unit__c unit) {
        // Ops allocates, never books.
        if (ADHA_JourneyController.isOps(applicant)) {
            throw new AuraHandledException('MSG_GENERIC');
        }
        // Somebody else's pin reads as plain taken, never as assigned.
        Boolean pinnedToMe = unit.Pinned_Applicant__c == applicant.Id;
        if (unit.Pinned_Applicant__c != null && !pinnedToMe) {
            throw new AuraHandledException('MSG_UNIT_TAKEN');
        }
        if (pinnedToMe) {
            // Their own pin: skip eligibility. Availability and deed mapping still apply below.
        } else {
            // A pinned applicant books their villa and nothing else.
            if ([SELECT COUNT() FROM ADHA_Unit__c WHERE Pinned_Applicant__c = :applicant.Id LIMIT 1] > 0) {
                throw new AuraHandledException('MSG_NOT_ELIGIBLE');
            }
            Set<String> categories = ADHA_MasterplanController.categoriesFor(applicant);
            String service = ADHA_MasterplanController.serviceFor(applicant);
            if (!ADHA_MasterplanController.isEligible(categories, service, unit)) {
                throw new AuraHandledException('MSG_NOT_ELIGIBLE');
            }
        }
        // Their pinned reserve villa books despite failing Is_Selectable - the pin is
        // the exposure grant. The active-reservation refusal above already ran.
        if (unit.Is_Selectable__c != true
            && !(pinnedToMe && ADHA_MasterplanController.reserveAssignable(unit))) {
            throw new AuraHandledException('MSG_UNIT_TAKEN');
        }
        // undertakingTypeFor falls back to 'General Declaration', which the restricted picklist
        // rejects; refuse up front so an unmapped service type never signs the wrong document.
        String undertaking = ADHA_JourneyController.undertakingTypeFor(applicant.Service_Type__c);
        if (undertaking != 'Grant' && undertaking != 'Loan') {
            throw new AuraHandledException('MSG_NOT_ELIGIBLE');
        }
    }

    private static ADHA_Unit__c lockUnit(String plotUid) {
        if (String.isBlank(plotUid)) {
            throw new AuraHandledException('MSG_GENERIC');
        }
        List<ADHA_Unit__c> rows = [
            SELECT Id, Plot_UID__c, Masterplan_Number__c, Status__c, Price__c, Category_Type__c,
                   Eligible_Service__c, Is_Selectable__c, Pinned_Applicant__c, Active_Reservation__c,
                   Expose_To__c
            FROM ADHA_Unit__c
            WHERE Plot_UID__c = :plotUid
            LIMIT 1
            FOR UPDATE
        ];
        if (rows.isEmpty()) {
            throw new AuraHandledException('MSG_GENERIC');
        }
        return rows[0];
    }

    /** Which of the two unique keys collided decides what the customer is told, and the two need
     *  very different messages - one means "someone was faster", the other "you already hold one". */
    private static AuraHandledException collisionFor(DmlException e, Id unitId) {
        Boolean duplicate = false;
        for (Integer i = 0; i < e.getNumDml(); i++) {
            if (e.getDmlType(i) == StatusCode.DUPLICATE_VALUE) {
                duplicate = true;
            }
        }
        if (!duplicate) {
            throw e;
        }
        Integer onUnit = [
            SELECT COUNT()
            FROM ADHA_Reservation__c
            WHERE Unit_Lock_Key__c = :String.valueOf(unitId)
        ];
        return new AuraHandledException(onUnit > 0 ? 'MSG_UNIT_TAKEN' : 'MSG_ALREADY_HELD');
    }

    /**
     * The reason this customer may not book, or null if they may. Stage before clock: an expired
     * final opportunity also leaves SLA_End__c in the past, and only one of those is the message.
     */
    @TestVisible
    public static String windowRefusal(ADHA_Applicant__c applicant) {
        // Must stay first: during soft launch SLA_End__c is null, which the branch below would
        // otherwise report as MSG_WINDOW_CLOSED on day one.
        if (!ADHA_JourneyController.reservationsOpen(applicant)) {
            return 'MSG_RESERVATIONS_CLOSED';
        }
        if (applicant.Journey_Stage__c == 'Expired') {
            return 'MSG_ATTEMPTS_SPENT';
        }
        if (applicant.SLA_End__c == null || applicant.SLA_End__c < System.now()) {
            return 'MSG_WINDOW_CLOSED';
        }
        return null;
    }

    /**
     * Committed-villa swaps count across the whole journey, derived from Submitted_On__c rather
     * than a counter that could drift. Unsigned holds are browsing and are never charged.
     */
    /**
     * A villa the customer has committed to, signed or not. Every guard on Submitted must cover
     * Completed too, or a signed reservation could be given away.
     */
    public static Boolean isCommitted(ADHA_Reservation__c reservation) {
        return reservation != null
            && (reservation.Status__c == 'Submitted' || reservation.Status__c == 'Completed');
    }

    public static Integer unitChangesUsed(ADHA_Applicant__c applicant) {
        return [
            SELECT COUNT()
            FROM ADHA_Reservation__c
            WHERE Applicant__c = :applicant.Id
              AND Release_Reason__c = 'Changed Unit'
              AND Submitted_On__c != NULL
        ];
    }

    /** Extra_Unit_Changes__c grants one applicant an extra change without raising the global cap.
     *  Null-safe: field defaults only reach records created after the field existed. */
    public static Integer unitChangesAllowed(ADHA_Applicant__c applicant) {
        Decimal configured = ADHA_JourneyController.settings().Max_Unit_Changes__c;
        Integer allowed = configured == null ? 2 : Integer.valueOf(configured);
        if (applicant.Extra_Unit_Changes__c != null) {
            allowed += Integer.valueOf(applicant.Extra_Unit_Changes__c);
        }
        return allowed;
    }

    public static Integer unitChangesRemaining(ADHA_Applicant__c applicant) {
        return Math.max(0, unitChangesAllowed(applicant) - unitChangesUsed(applicant));
    }

    /** Only a signed villa is charged for, matching assertReleasable. Ordered after the window
     *  check everywhere it is used, so a customer out of time hears about the clock, not the count. */
    private static void assertChangesRemaining(ADHA_Applicant__c applicant, ADHA_Reservation__c live) {
        if (live != null && isCommitted(live) && unitChangesRemaining(applicant) <= 0) {
            throw new AuraHandledException('MSG_CHANGES_SPENT');
        }
    }

    /**
     * An unsigned hold may always be released early; a signed reservation only inside the window,
     * because no replacement can be taken while it is shut and there is no undo.
     */
    private static void assertReleasable(ADHA_Applicant__c applicant, ADHA_Reservation__c live) {
        if (live != null && isCommitted(live)) {
            assertWindowOpen(applicant);
        }
    }

    /**
     * Server-side backstop for the declaration screen, keyed on the per-session hash rather than
     * the forever-true boolean. MSG_GENERIC because no legitimate client reaches this.
     */
    private static void assertDeclarationAccepted(ADHA_Applicant__c applicant) {
        if (String.isBlank(applicant.Declaration_Session_Hash__c)
            || applicant.Declaration_Session_Hash__c != applicant.Session_Token_Hash__c) {
            throw new AuraHandledException('MSG_GENERIC');
        }
    }

    private static void assertWindowOpen(ADHA_Applicant__c applicant) {
        String refusal = windowRefusal(applicant);
        if (refusal != null) {
            throw new AuraHandledException(refusal);
        }
    }

    /**
     * @param allowBackwards true when the move is genuinely a step back, so ADHA's daily
     *        breakdown reports the customer at the stage they are really at.
     */
    // Public so ADHA_SigningService can move an applicant to Completed without duplicating the
    // ordering rules that decide when a stage may move backwards.
    public static void advanceStage(ADHA_Applicant__c applicant, String stage, Boolean allowBackwards) {
        if (!allowBackwards && !ADHA_JourneyController.isEarlierStage(applicant.Journey_Stage__c, stage)) {
            return;
        }
        if (applicant.Journey_Stage__c == stage) {
            return;
        }
        applicant.Journey_Stage__c = stage;
        update applicant;
    }

    public static Decimal additionalFor(Decimal price, Decimal approved) {
        Decimal p = price == null ? 0 : price;
        Decimal a = approved == null ? 0 : approved;
        return p > a ? p - a : 0;
    }

    private static Integer maxAttempts() {
        Decimal value = ADHA_JourneyController.settings().Max_Attempts__c;
        return value == null ? 2 : Integer.valueOf(value);
    }

    public static Date dueDate(Datetime confirmedAt) {
        return Date.valueOf(confirmedAt.format('yyyy-MM-dd', 'Asia/Dubai')).addMonths(paymentMonths());
    }

    private static Integer paymentMonths() {
        Decimal value = ADHA_JourneyController.settings().Additional_Payment_Months__c;
        return value == null ? 3 : Integer.valueOf(value);
    }

    /** The five FAB NHL collection scenarios, plus the nothing-owed case. */
    private static Set<String> methodValues() {
        return new Set<String>{
            'Not Applicable',
            'Full Upfront Payment',
            'Payment Plan',
            'Partial Payment with Plan',
            'Partial Payment with Plan and Bank Top Up',
            'Bank Top Up Finance'
        };
    }

    /** Append-only, newest last, so the log reads as a trail. Trimmed from the front rather than
     *  the back if it ever approaches the field limit - the recent entries are the useful ones. */
    // Public for the same reason: one journey log format, written the same way from both classes.
    public static String logLine(String existing, String entry) {
        String stamped = System.now().format('yyyy-MM-dd HH:mm:ss') + '  ' + entry;
        String combined = String.isBlank(existing) ? stamped : existing + '\n' + stamped;
        return combined.length() > 130000 ? combined.substring(combined.length() - 130000) : combined;
    }

    private static ReservationView toView(ADHA_Reservation__c res, ADHA_Applicant__c applicant) {
        ReservationView v = new ReservationView();
        v.reservationNumber = res.Name;
        v.status = res.Status__c;
        v.plotUid = res.Unit__r == null ? null : res.Unit__r.Plot_UID__c;
        v.masterplanNumber = res.Unit__r == null || res.Unit__r.Masterplan_Number__c == null
            ? null
            : Integer.valueOf(res.Unit__r.Masterplan_Number__c);
        v.unitPrice = res.Unit_Price__c;
        v.approvedAmount = applicant.Approved_Loan_Amount__c;
        v.additionalAmount = res.Additional_Amount__c;
        v.paymentMethod = res.Payment_Method__c;
        v.additionalPaymentDue = res.Additional_Payment_Due__c;
        v.undertakingAccepted = res.Undertaking_Accepted__c == true;
        v.undertakingType = res.Undertaking_Type__c;
        v.undertakingVersion = res.Undertaking_Version__c;
        v.attempt = res.Attempt_Number__c == null ? 1 : Integer.valueOf(res.Attempt_Number__c);
        v.slaEnd = res.SLA_End__c;
        v.docuSignStatus = res.DocuSign_Status__c;
        v.holdExpiresAt = res.Hold_Expires_At__c;
        if (res.SLA_End__c != null) {
            Long ms = res.SLA_End__c.getTime() - System.now().getTime();
            v.daysRemaining = ms <= 0 ? 0 : Integer.valueOf(Math.ceil(ms / 86400000.0));
        }
        return v;
    }

    /**
     * Releases one lapsed, unaccepted hold. The re-read under FOR UPDATE is the point: the caller's
     * view can be minutes old, and an undertaking accepted in between must not be released.
     */
    public static Boolean releaseLapsedHold(Id reservationId) {
        if (reservationId == null) {
            return false;
        }
        List<ADHA_Reservation__c> fresh = [
            SELECT Id, Applicant__c, Status__c, Unit__c, Released_On__c, Journey_Log__c,
                   Hold_Expires_At__c, Undertaking_Accepted__c
            FROM ADHA_Reservation__c
            WHERE Id = :reservationId
            LIMIT 1
            FOR UPDATE
        ];
        if (fresh.isEmpty() || isReleased(fresh[0])) {
            return false;
        }
        if (fresh[0].Undertaking_Accepted__c == true) {
            return false;
        }
        if (fresh[0].Hold_Expires_At__c == null || fresh[0].Hold_Expires_At__c >= System.now()) {
            return false;
        }
        release(fresh[0], 'Hold Expired');
        return true;
    }

    /** Read by the sweeper so "already released" is decided in one place. */
    public static Boolean isReleased(ADHA_Reservation__c res) {
        return res.Released_On__c != null || RELEASED_STATUSES.contains(res.Status__c);
    }
}