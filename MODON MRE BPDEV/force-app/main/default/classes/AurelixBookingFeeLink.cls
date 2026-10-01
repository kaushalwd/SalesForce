/**
 * AurelixBookingFeeLink - the booking fee is collected by a payment link sent to the customer.
 *
 * Version  Author       Date         Detail
 * 1.1      Aurelix Dev  29 Sep 2026  Where Opportunity.ContactId is blank, the link is written to the primary
 *                                    contact (reachCustomer), so the customer still gets it.
 * 1.0      Aurelix Dev  29 Sep 2026  The booking fee is sent as a payment link instead of opening the MODON Pay
 *                                    card page (Modon_Pay_Terminal_URL?op=).
 *
 * Uses MODON's own SalesOrderCheckoutController.createBookingLink: one Checkout link per fee ('ADM Fee' or
 * 'Down Payment') for the Booking_Fee_Line__c balance. MODON's CheckoutPaymentTrigger sends it and
 * CheckoutPaymentPoller moves it to Expired or Captured. A captured link does not yet post a Receipt__c on
 * the fee line (MODON's materialiser handles EOI links only).
 * One link per call: a link is a callout followed by an insert.
 * Switch: BOOKING_FEE_BY_LINK in Sales_Console_Config__mdt (off: the MODON Pay card page).
 */
public with sharing class AurelixBookingFeeLink {

    public static final String FLAG = 'BOOKING_FEE_BY_LINK';

    /** Checkout_Payment__c.Payment_Purpose__c, by Booking_Fee_Line__c.Type__c. */
    public static final Map<String, String> PURPOSE_BY_FEE_TYPE = new Map<String, String>{
        'ADM & Dari' => 'ADM Fee',
        'Down Payment' => 'Down Payment'
    };

    /** What the rep reads for each purpose. */
    public static final Map<String, String> LABEL_BY_PURPOSE = new Map<String, String>{
        'ADM Fee' => 'ADM & Dari fee',
        'Down Payment' => 'Down payment'
    };

    /** A link the customer can still pay. */
    public static final Set<String> LIVE_STATUSES = new Set<String>{ 'Link Created', 'Authorized' };

    /** Tests set this instead of the metadata record. */
    @TestVisible private static Boolean switchOverride;

    /** Sales_Console_Config__mdt.BOOKING_FEE_BY_LINK.Is_Active__c. */
    public static Boolean isOn() {
        if (switchOverride != null) {
            return switchOverride;
        }
        /* off in tests unless a test turns it on, so the older booking tests keep the card page route */
        if (Test.isRunningTest()) {
            return false;
        }
        Sales_Console_Config__mdt cfg = Sales_Console_Config__mdt.getInstance(FLAG);
        return cfg != null && cfg.Is_Active__c == true;
    }

    /** One link, as stored. */
    public class LinkRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String purpose;
        @AuraEnabled public String label;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public String status;
        @AuraEnabled public Datetime expiresOn;
        @AuraEnabled public Datetime createdDate;
        @AuraEnabled public Boolean live = false;
        @AuraEnabled public Boolean paid = false;
    }

    /** Everything the booking page needs to draw the link state. */
    public class LinkState {
        /** The switch: links (true) or the MODON Pay card page (false). */
        @AuraEnabled public Boolean linkMode = false;
        /** The newest link per purpose, newest first. */
        @AuraEnabled public List<LinkRow> links = new List<LinkRow>();
        /** A link the customer can still pay. While true the unit cannot be released. */
        @AuraEnabled public Boolean anyLive = false;
        /** When the last live link expires. */
        @AuraEnabled public Datetime liveUntil;
        /** Fees with a balance and no live link: what "Send payment link" would send now. */
        @AuraEnabled public List<String> purposesToSend = new List<String>();
        /** The Reserved mark (AurelixUnitReservation). */
        @AuraEnabled public AurelixUnitReservation.ReservationState reservation;
    }

    /* ── Read ───────────────────────────────────────────────────────────────── */

    public static LinkState state(Id opportunityId, Id unitId) {
        LinkState s = new LinkState();
        s.linkMode = isOn();
        s.reservation = AurelixUnitReservation.state(opportunityId, unitId);
        if (opportunityId == null || unitId == null) {
            return s;
        }
        Datetime asOf = System.now();
        Set<String> seen = new Set<String>();
        Set<String> livePurposes = new Set<String>();
        for (Checkout_Payment__c cp : rowsFor(opportunityId, unitId)) {
            LinkRow r = toRow(cp, asOf);
            if (r.live) {
                s.anyLive = true;
                livePurposes.add(r.purpose);
                if (s.liveUntil == null || (r.expiresOn != null && r.expiresOn > s.liveUntil)) {
                    s.liveUntil = r.expiresOn;
                }
            }
            /* the newest row per purpose is the one that speaks for it */
            if (seen.add(r.purpose)) {
                s.links.add(r);
            }
        }
        for (Booking_Fee_Line__c l : feeLines(opportunityId, unitId)) {
            String purpose = PURPOSE_BY_FEE_TYPE.get(l.Type__c);
            if (purpose != null && l.Balance_Amount__c != null && l.Balance_Amount__c > 0
                    && !livePurposes.contains(purpose)) {
                s.purposesToSend.add(purpose);
            }
        }
        return s;
    }

    /** True while the customer can still pay a link for this unit on this booking. */
    public static Boolean anyLive(Id opportunityId, Id unitId) {
        Datetime asOf = System.now();
        for (Checkout_Payment__c cp : rowsFor(opportunityId, unitId)) {
            if (toRow(cp, asOf).live) {
                return true;
            }
        }
        return false;
    }

    /* ── Send ───────────────────────────────────────────────────────────────── */

    /**
     * Sends the link for one fee through MODON's createBookingLink and keeps the reservation for the
     * link's life. The amount is the fee line's balance. Refuses (AuraHandledException with the reason)
     * when nothing is owed on that fee or a link for it is still live. No DML before the callout.
     */
    public static LinkRow send(Id opportunityId, Id unitId, String purpose) {
        if (opportunityId == null || unitId == null) {
            throw refused('Select a unit before sending a payment link.');
        }
        if (!LABEL_BY_PURPOSE.containsKey(purpose)) {
            throw refused('Choose which fee the payment link is for.');
        }
        Decimal balance;
        for (Booking_Fee_Line__c l : feeLines(opportunityId, unitId)) {
            if (PURPOSE_BY_FEE_TYPE.get(l.Type__c) == purpose) {
                balance = l.Balance_Amount__c;
            }
        }
        String label = LABEL_BY_PURPOSE.get(purpose);
        if (balance == null || balance <= 0) {
            throw refused('Nothing is owed on the ' + label + '.');
        }
        Datetime asOf = System.now();
        for (Checkout_Payment__c cp : rowsFor(opportunityId, unitId)) {
            LinkRow r = toRow(cp, asOf);
            if (r.live && r.purpose == purpose) {
                throw refused('A payment link for the ' + label + ' is still live. Use Resend link.');
            }
        }
        /* the run this link belongs to: the rep's own running hold and its reference (beginRun) */
        String bookingRef;
        for (Unit__c u : [
            SELECT Checkout_Booking_Ref__c, Payment_In_Progress__c, Payment_Hold_Expiry__c, Payment_Hold_By__c
            FROM Unit__c WHERE Id = :unitId LIMIT 1
        ]) {
            Boolean myLiveHold = u.Payment_In_Progress__c == true && u.Payment_Hold_By__c == UserInfo.getUserId()
                && u.Payment_Hold_Expiry__c != null && u.Payment_Hold_Expiry__c > asOf;
            if (myLiveHold) {
                bookingRef = u.Checkout_Booking_Ref__c;
            }
        }
        if (String.isBlank(bookingRef)) {
            throw refused('The hold on this unit has expired. Send payment link again.');
        }

        /* the callout and MODON's own writes (row, booking context, hold expiry) */
        SalesOrderCheckoutController.LinkResult lr = SalesOrderCheckoutController.createBookingLink(
            bookingRef, purpose, balance, String.valueOf(unitId), String.valueOf(opportunityId), null);
        if (lr == null || lr.isSuccess != true) {
            throw refused(lr != null && String.isNotBlank(lr.message)
                ? lr.message : 'The payment link could not be created. Please try again.');
        }

        /* after the callout: the reservation lives as long as the link */
        AurelixUnitReservation.extendTo(opportunityId, lr.expiresOn);
        /* 1.1 - and the customer receives it even where Opportunity.ContactId is blank */
        reachCustomer(opportunityId, lr.reference);

        LinkRow row = new LinkRow();
        row.purpose = purpose;
        row.label = label;
        row.amount = lr.amount;
        row.status = 'Link Created';
        row.expiresOn = lr.expiresOn;
        row.live = true;
        for (Checkout_Payment__c cp : [
            SELECT Id, CreatedDate FROM Checkout_Payment__c WHERE Reference__c = :lr.reference LIMIT 1
        ]) {
            row.id = cp.Id;
            row.createdDate = cp.CreatedDate;
        }
        return row;
    }

    /**
     * 1.1 - createBookingLink takes the customer from Opportunity.ContactId, blank on some console bookings.
     * Then the row takes the primary contact's name, email and mobile, and MODON's message goes out once
     * (CheckoutNotificationService.resendLink).
     */
    private static void reachCustomer(Id opportunityId, String reference) {
        if (String.isBlank(reference)) {
            return;
        }
        List<Checkout_Payment__c> rows = [
            SELECT Id, Customer_Email__c, Customer_Phone__c FROM Checkout_Payment__c WHERE Reference__c = :reference LIMIT 1
        ];
        if (rows.isEmpty() || String.isNotBlank(rows[0].Customer_Email__c) || String.isNotBlank(rows[0].Customer_Phone__c)) {
            return;
        }
        for (Opportunity o : [
            SELECT PrimaryContact__r.Name, PrimaryContact__r.Email, PrimaryContact__r.MobilePhone, PrimaryContact__r.Phone
            FROM Opportunity WHERE Id = :opportunityId LIMIT 1
        ]) {
            Contact c = o.PrimaryContact__r;
            if (c == null) {
                return;
            }
            String phone = String.isNotBlank(c.MobilePhone) ? c.MobilePhone : c.Phone;
            if (String.isBlank(c.Email) && String.isBlank(phone)) {
                return;
            }
            update new Checkout_Payment__c(Id = rows[0].Id, Customer_Name__c = c.Name, Customer_Email__c = c.Email,
                Customer_Phone__c = phone);
            CheckoutNotificationService.resendLink(new Set<Id>{ rows[0].Id });
        }
    }

    /**
     * Sends the same stored message again for every live link (email and SMS, MODON's
     * CheckoutNotificationService.resendLink): nothing new is created and no expiry moves.
     */
    public static Integer resend(Id opportunityId, Id unitId) {
        Datetime asOf = System.now();
        Set<Id> live = new Set<Id>();
        for (Checkout_Payment__c cp : rowsFor(opportunityId, unitId)) {
            if (toRow(cp, asOf).live) {
                live.add(cp.Id);
            }
        }
        if (live.isEmpty()) {
            throw refused('No payment link is live. Use Send payment link.');
        }
        return CheckoutNotificationService.resendLink(live);
    }

    /**
     * Starts a run once the hold is taken: a new booking reference on Unit__c.Checkout_Booking_Ref__c, so
     * the links sent during this hold share one booking and MODON's Max_Booking_Links_Per_Fee__c counts within it.
     */
    public static String beginRun(Id unitId) {
        if (unitId == null) {
            return null;
        }
        String ref = newBookingRef();
        update new Unit__c(Id = unitId, Checkout_Booking_Ref__c = ref);
        return ref;
    }

    /* ── Helpers ────────────────────────────────────────────────────────────── */

    /** This booking's links for this unit, newest first; rows already tied to a Sales Order are done. */
    private static List<Checkout_Payment__c> rowsFor(Id opportunityId, Id unitId) {
        if (opportunityId == null || unitId == null) {
            return new List<Checkout_Payment__c>();
        }
        Set<String> unitKeys = new Set<String>{ String.valueOf(unitId), String.valueOf(unitId).substring(0, 15) };
        Set<String> oppKeys = new Set<String>{ String.valueOf(opportunityId), String.valueOf(opportunityId).substring(0, 15) };
        return [
            SELECT Id, Booking_Ref__c, Payment_Purpose__c, Amount__c, Status__c, Expires_On__c, CreatedDate
            FROM Checkout_Payment__c
            WHERE Held_Unit_Id__c IN :unitKeys AND Related_Record_Id__c IN :oppKeys
              AND Booking_Ref__c != null AND Sales_Order__c = null
            ORDER BY CreatedDate DESC
            LIMIT 50
        ];
    }

    private static LinkRow toRow(Checkout_Payment__c cp, Datetime asOf) {
        LinkRow r = new LinkRow();
        r.id = cp.Id;
        r.purpose = cp.Payment_Purpose__c;
        r.label = LABEL_BY_PURPOSE.containsKey(cp.Payment_Purpose__c)
            ? LABEL_BY_PURPOSE.get(cp.Payment_Purpose__c) : cp.Payment_Purpose__c;
        r.amount = cp.Amount__c;
        r.status = cp.Status__c;
        r.expiresOn = cp.Expires_On__c;
        r.createdDate = cp.CreatedDate;
        r.paid = cp.Status__c == 'Captured';
        r.live = LIVE_STATUSES.contains(cp.Status__c) && (cp.Expires_On__c == null || cp.Expires_On__c > asOf);
        return r;
    }

    private static List<Booking_Fee_Line__c> feeLines(Id opportunityId, Id unitId) {
        return [
            SELECT Id, Type__c, Balance_Amount__c
            FROM Booking_Fee_Line__c
            WHERE Opportunity__c = :opportunityId AND Unit__c = :unitId
            ORDER BY CreatedDate ASC
        ];
    }

    /** MODON's reference shape (SalesOrderCheckoutController.genRef). */
    @TestVisible
    private static String newBookingRef() {
        return 'CKO-' + EncodingUtil.convertToHex(Crypto.generateAesKey(128)).substring(0, 18);
    }

    private static AuraHandledException refused(String message) {
        AuraHandledException e = new AuraHandledException(message);
        e.setMessage(message);
        return e;
    }
}