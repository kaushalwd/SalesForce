/**********************************************************************************************
 * Name           : SalesOrderCheckoutController
 * Description     : Pay-first unit booking. Collects the ADM/Dari fee and the down payment via
 *                   Checkout links (each on its own escrow processing channel) BEFORE any Sales
 *                   Order exists. The unit is hidden from other agents by Unit.Payment_In_Progress__c
 *                   (not a status change). When the captured total reaches the minimum, the agent
 *                   clicks Book -> the existing UnitSearchLwcController.saveSalesOrder creates the SO.
 * Usage           : LWC unitSearchLwc (Book Unit(s) step).
 * Created By      : Modon
 * --------------------------------------------------------------------------------------------
 * Version    Author            Date           Comment
 * 1.1        Aurelix Dev       03 Sep 2026    MSC-231. finalizeBooking honours an 'eoiMapping' key
 *                                             in the stashed payload (EOI deposits ride through
 *                                             the payment round-trip); absent = unchanged.
 * 1.0        Prateek Bansal    08 Jul 2026    Initial version.
 **********************************************************************************************/
public with sharing class SalesOrderCheckoutController {

    private static final Integer DEFAULT_LINK_EXPIRY = 300;   // 5 min
    private static final Integer DEFAULT_MAX_LINKS   = 3;
    private static final Decimal FEE_FLOOR           = 50000; // AED, "whichever is more"
    private static final Set<String> ACTIVE_LINK_STATUSES = new Set<String>{
        'Link Created','Authorized','Captured'
    };

    // ── DTOs ─────────────────────────────────────────────────────────────────
    public class Fees {
        @AuraEnabled public Decimal admFee = 0;
        @AuraEnabled public Decimal downPayment = 0;
        @AuraEnabled public Decimal minimum = 0;
    }

    public class BookingResult {
        @AuraEnabled public Boolean isSuccess = false;
        @AuraEnabled public String message;
        @AuraEnabled public String bookingRef;
        @AuraEnabled public String currencyCode;
        @AuraEnabled public Fees fees;
    }

    public class LinkResult {
        @AuraEnabled public Boolean isSuccess = false;
        @AuraEnabled public String message;
        @AuraEnabled public String reference;
        @AuraEnabled public String purpose;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public String paymentLinkUrl;
        @AuraEnabled public Datetime expiresOn;
    }

    public class LinkDTO {
        @AuraEnabled public String reference;
        @AuraEnabled public String purpose;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public String status;
        @AuraEnabled public String paymentLinkUrl;
        @AuraEnabled public Datetime expiresOn;
        @AuraEnabled public Boolean isPaid = false;
    }

    public class BookingStatus {
        @AuraEnabled public String bookingRef;
        @AuraEnabled public List<LinkDTO> links = new List<LinkDTO>();
        @AuraEnabled public Decimal capturedTotal = 0;
        @AuraEnabled public Decimal minimum = 0;
        @AuraEnabled public Fees fees;
        @AuraEnabled public Boolean canBook = false;
        @AuraEnabled public Boolean isBooked = false;
        @AuraEnabled public Id salesOrderId;
    }

    public class FinalizeResult {
        @AuraEnabled public Boolean isSuccess = false;
        @AuraEnabled public String message;
        @AuraEnabled public Id salesOrderId;
    }

    // ── Pay now: pre-flight, hold the unit, compute the minimum ────────────────
    // salesOrderList is the same wrapper the Book Unit(s) step builds for saveSalesOrder (V1 = 1 unit).
    @AuraEnabled
    public static BookingResult startBooking(List<SalesOrder__c> salesOrderList, String oppId, String offerLinesListStr) {
        BookingResult res = new BookingResult();
        if (salesOrderList == null || salesOrderList.isEmpty()) {
            res.message = 'No unit selected.'; return res;
        }
        if (salesOrderList.size() > 1) {
            res.message = 'Pay now supports a single unit. Use Generate sales order for multiple units.'; return res;
        }
        SalesOrder__c so = salesOrderList[0];
        if (String.isBlank(so.Unit__c) || so.TotalAmount__c == null) {
            res.message = 'Unit and price are required.'; return res;
        }

        // FOR UPDATE + availability / concurrent-hold re-check
        Unit__c unit = lockAndCheckUnit(so.Unit__c);

        Fees fees = computeFees(unit, so.PaymentPlan__c, so.TotalAmount__c);
        if (fees.minimum <= 0) {
            res.message = 'Could not compute the booking fees for this unit.'; return res;
        }

        String bookingRef = genRef();
        Datetime holdExpiry = System.now().addSeconds(linkExpirySeconds());

        unit.Payment_In_Progress__c = true;
        unit.Payment_Hold_Expiry__c = holdExpiry;
        unit.Checkout_Booking_Ref__c = bookingRef;
        unit.Payment_Hold_By__c = UserInfo.getUserId();
        update unit;

        res.isSuccess = true;
        res.bookingRef = bookingRef;
        res.currencyCode = resolveCurrency(so, oppId);
        res.fees = fees;
        return res;
    }

    // ── Generate a payment link for one fee, on that fee's escrow channel ──────
    @AuraEnabled
    public static LinkResult createBookingLink(String bookingRef, String purpose, Decimal amount,
                                               String unitId, String oppId, String soPayloadJson) {
        LinkResult lr = new LinkResult();
        if (String.isBlank(bookingRef) || String.isBlank(purpose) || amount == null || amount <= 0) {
            lr.message = 'Booking reference, purpose and a positive amount are required.'; return lr;
        }
        if (String.isBlank(unitId)) { lr.message = 'Unit is required.'; return lr; }

        // Cap: count ALL links generated for this purpose (incl. expired/paid) so the hold can't be extended forever.
        Integer existing = [
            SELECT COUNT() FROM Checkout_Payment__c
            WHERE Booking_Ref__c = :bookingRef AND Payment_Purpose__c = :purpose
        ];
        if (existing >= maxLinksPerFee()) {
            lr.message = 'Maximum number of links reached for ' + purpose + '.'; return lr;
        }

        Unit__c unit = [
            SELECT Id, Phase__c, Phase__r.EscrowAccount__c
            FROM Unit__c WHERE Id = :unitId LIMIT 1
        ];
        String channelId = resolveChannel(unit, purpose);

        String reference = genRef();
        CheckoutPaymentLinkService.Request req = new CheckoutPaymentLinkService.Request();
        req.amount = amount;
        req.currencyCode = resolveCurrency(null, oppId);
        req.capture = true;
        req.reference = reference;
        req.relatedRecordId = oppId;
        req.processingChannelId = channelId;
        req.expirySeconds = linkExpirySeconds();
        req.description = purpose + ' - Unit Booking';
        applyCustomer(req, oppId);

        CheckoutPaymentLinkService.Result r = CheckoutPaymentLinkService.createLink(req);
        if (r == null || !r.isSuccess || r.paymentRecordId == null) {
            lr.message = (r != null && r.message != null) ? r.message : 'Could not create the payment link.';
            return lr;
        }

        // Stamp the booking context onto the created row (createLink stays generic).
        Checkout_Payment__c cp = [
            SELECT Id, Expires_On__c, Payment_Link_Url__c FROM Checkout_Payment__c WHERE Id = :r.paymentRecordId LIMIT 1
        ];
        cp.Booking_Ref__c = bookingRef;
        cp.Payment_Purpose__c = purpose;
        cp.Held_Unit_Id__c = unitId;
        cp.SO_Creation_Payload__c = soPayloadJson;
        update cp;

        // Extend the unit hold to this link's expiry (release = last link's expiry).
        if (cp.Expires_On__c != null) {
            update new Unit__c(Id = unitId, Payment_Hold_Expiry__c = cp.Expires_On__c);
        }

        lr.isSuccess = true;
        lr.reference = reference;
        lr.purpose = purpose;
        lr.amount = amount;
        lr.paymentLinkUrl = r.paymentLinkUrl != null ? r.paymentLinkUrl : cp.Payment_Link_Url__c;
        lr.expiresOn = cp.Expires_On__c;
        return lr;
    }

    // ── Poll + resume: current link statuses, captured total, can-book flag ────
    @AuraEnabled
    public static BookingStatus getBookingStatus(String bookingRef) {
        BookingStatus st = new BookingStatus();
        st.bookingRef = bookingRef;
        if (String.isBlank(bookingRef)) return st;

        List<Checkout_Payment__c> rows = [
            SELECT Id, Reference__c, Payment_Purpose__c, Amount__c, Status__c, Payment_Link_Url__c,
                   Expires_On__c, Payment_Id__c, Payment_Link_Id__c, SO_Creation_Payload__c,
                   Sales_Order__c, Held_Unit_Id__c
            FROM Checkout_Payment__c
            WHERE Booking_Ref__c = :bookingRef
            ORDER BY CreatedDate ASC
        ];
        if (rows.isEmpty()) return st;

        // Refresh any still-open link from Checkout so the panel reflects real capture state.
        for (Checkout_Payment__c cp : rows) {
            if (ACTIVE_LINK_STATUSES.contains(cp.Status__c) && cp.Status__c != 'Captured') {
                CheckoutPaymentLinkService.applyLatestStatus(cp);
            }
        }
        update rows;

        String soPayload;
        Id soId;
        for (Checkout_Payment__c cp : rows) {
            if (String.isBlank(soPayload) && String.isNotBlank(cp.SO_Creation_Payload__c)) soPayload = cp.SO_Creation_Payload__c;
            if (soId == null && cp.Sales_Order__c != null) soId = cp.Sales_Order__c;
            LinkDTO d = new LinkDTO();
            d.reference = cp.Reference__c;
            d.purpose = cp.Payment_Purpose__c;
            d.amount = cp.Amount__c;
            d.status = cp.Status__c;
            d.paymentLinkUrl = cp.Payment_Link_Url__c;
            d.expiresOn = cp.Expires_On__c;
            d.isPaid = cp.Status__c == 'Captured';
            st.links.add(d);
            if (d.isPaid && cp.Amount__c != null) st.capturedTotal += cp.Amount__c;
        }
        st.salesOrderId = soId;
        st.isBooked = soId != null;
        st.fees = feesFromPayload(soPayload);
        st.minimum = st.fees.minimum;
        st.canBook = !st.isBooked && st.minimum > 0 && st.capturedTotal >= st.minimum;
        return st;
    }

    // ── Resume: find the in-progress (unbooked) booking for this unit on THIS opportunity ──
    // Match on the opportunity too (Related_Record_Id__c) so a stale booking started from another
    // opportunity is never resumed here - its links belong to a different customer.
    @AuraEnabled
    public static BookingStatus getActiveBooking(String unitId, String oppId) {
        if (String.isBlank(unitId) || String.isBlank(oppId)) return new BookingStatus();
        List<Checkout_Payment__c> rows = [
            SELECT Booking_Ref__c FROM Checkout_Payment__c
            WHERE Held_Unit_Id__c = :unitId AND Related_Record_Id__c = :oppId
              AND Booking_Ref__c != null AND Sales_Order__c = null
            ORDER BY CreatedDate DESC LIMIT 1
        ];
        if (rows.isEmpty()) return new BookingStatus();
        return getBookingStatus(rows[0].Booking_Ref__c);
    }

    // ── Book: create the SO from the stashed payload once the minimum is captured ──
    @AuraEnabled
    public static FinalizeResult finalizeBooking(String bookingRef) {
        FinalizeResult fr = new FinalizeResult();
        if (String.isBlank(bookingRef)) { fr.message = 'Booking reference is required.'; return fr; }

        List<Checkout_Payment__c> rows = [
            SELECT Id, Payment_Purpose__c, Amount__c, Status__c, Payment_Id__c, SO_Creation_Payload__c,
                   Held_Unit_Id__c, Sales_Order__c
            FROM Checkout_Payment__c WHERE Booking_Ref__c = :bookingRef
        ];
        if (rows.isEmpty()) { fr.message = 'No payments found for this booking.'; return fr; }
        for (Checkout_Payment__c cp : rows) {
            if (cp.Sales_Order__c != null) { fr.isSuccess = true; fr.salesOrderId = cp.Sales_Order__c; return fr; }
        }

        String soPayload;
        String unitId;
        Decimal captured = 0;
        for (Checkout_Payment__c cp : rows) {
            if (String.isBlank(soPayload) && String.isNotBlank(cp.SO_Creation_Payload__c)) soPayload = cp.SO_Creation_Payload__c;
            if (String.isBlank(unitId) && String.isNotBlank(cp.Held_Unit_Id__c)) unitId = cp.Held_Unit_Id__c;
            if (cp.Status__c == 'Captured' && cp.Amount__c != null) captured += cp.Amount__c;
        }
        Decimal minimum = feesFromPayload(soPayload).minimum;
        if (minimum <= 0 || captured < minimum) {
            fr.message = 'The minimum booking amount has not been captured yet.'; return fr;
        }

        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(soPayload);
        String oppId = (String) payload.get('oppId');
        String offerLines = (String) payload.get('offerLines');
        List<SalesOrder__c> sos = (List<SalesOrder__c>) JSON.deserialize(
            JSON.serialize(payload.get('salesOrders')), List<SalesOrder__c>.class
        );

        // MSC-231: a payload stashed with an 'eoiMapping' key ({unitId: eoiId} JSON) carries its
        // EOI deposits through the payment round-trip; absent or blank, EOI linking is skipped
        // exactly as before. The engine re-validates the receipts it spends either way.
        String eoiMapping = (String) payload.get('eoiMapping');
        String result = UnitSearchLwcController.saveSalesOrder(
            sos, oppId, offerLines, String.isBlank(eoiMapping) ? null : eoiMapping);
        if (result != 'Success') { fr.message = result; return fr; }

        // The SO was created against the held unit; find it and stamp the payments + release the flag.
        List<SalesOrder__c> created = [
            SELECT Id FROM SalesOrder__c
            WHERE Opportunity__c = :oppId AND Unit__c = :unitId
              AND Status__c NOT IN ('Cancelled','System Cancelled','Voided')
            ORDER BY CreatedDate DESC LIMIT 1
        ];
        Id salesOrderId = created.isEmpty() ? null : created[0].Id;

        for (Checkout_Payment__c cp : rows) { cp.Sales_Order__c = salesOrderId; }
        update rows;
        if (String.isNotBlank(unitId)) {
            update new Unit__c(Id = unitId, Payment_In_Progress__c = false,
                               Payment_Hold_Expiry__c = null, Checkout_Booking_Ref__c = null,
                               Payment_Hold_By__c = null);
        }

        fr.isSuccess = true;
        fr.salesOrderId = salesOrderId;
        return fr;
    }

    // ── Cancel: void active links + release the unit ───────────────────────────
    @AuraEnabled
    public static void cancelBooking(String bookingRef) {
        if (String.isBlank(bookingRef)) return;
        List<Checkout_Payment__c> rows = [
            SELECT Id, Status__c, Payment_Id__c, Held_Unit_Id__c
            FROM Checkout_Payment__c WHERE Booking_Ref__c = :bookingRef
        ];
        String unitId;
        for (Checkout_Payment__c cp : rows) {
            if (String.isBlank(unitId) && String.isNotBlank(cp.Held_Unit_Id__c)) unitId = cp.Held_Unit_Id__c;
            if (cp.Status__c == 'Link Created' && String.isNotBlank(cp.Payment_Id__c)) {
                CheckoutPaymentLinkService.voidPayment(cp.Payment_Id__c);
            }
        }
        if (String.isNotBlank(unitId)) {
            update new Unit__c(Id = unitId, Payment_In_Progress__c = false,
                               Payment_Hold_Expiry__c = null, Checkout_Booking_Ref__c = null,
                               Payment_Hold_By__c = null);
        }
    }

    // ── Helpers ────────────────────────────────────────────────────────────────
    private static Unit__c lockAndCheckUnit(String unitId) {
        List<Unit__c> units = [
            SELECT Id, Name, Status__c, Sub_Status__c, Payment_In_Progress__c, Payment_Hold_Expiry__c,
                   Phase__c, Phase__r.EscrowAccount__c
            FROM Unit__c WHERE Id = :unitId FOR UPDATE
        ];
        if (units.isEmpty()) throw new AuraHandledException('Unit not found.');
        Unit__c u = units[0];
        Boolean heldByOther = u.Payment_In_Progress__c == true
            && u.Payment_Hold_Expiry__c != null && u.Payment_Hold_Expiry__c >= System.now();
        if (heldByOther) throw new AuraHandledException('This unit is currently being booked by another agent.');
        Boolean hasActiveSo = ![
            SELECT Id FROM SalesOrder__c
            WHERE Unit__c = :unitId AND Status__c NOT IN ('Cancelled','System Cancelled','Voided') LIMIT 1
        ].isEmpty();
        if (hasActiveSo) throw new AuraHandledException('This unit already has an active sales order.');
        return u;
    }

    private static Fees computeFees(Unit__c unit, Id planId, Decimal totalAmount) {
        Fees f = new Fees();
        // ADM & Dari (mirrors ADMFeesChargeInvoiceService; base amount excl. VAT)
        if (unit.Phase__c != null) {
            List<Financial_Setup__c> cfg = [
                SELECT Value__c, Fee_Type__c, Default_Amount__c
                FROM Financial_Setup__c
                WHERE Phase__c = :unit.Phase__c AND Type__c = 'ADM & Dari Fee'
                  AND SR_RecordType__c = null AND Sub_Type__c INCLUDES ('New Sale')
                LIMIT 1
            ];
            if (!cfg.isEmpty()) {
                Financial_Setup__c fs = cfg[0];
                Decimal admDari = (fs.Fee_Type__c == '% Based Calculation')
                    ? (totalAmount * nz(fs.Value__c) / 100) + nz(fs.Default_Amount__c)
                    : nz(fs.Value__c);
                f.admFee = maxOf(admDari * 0.50, FEE_FLOOR);
            }
        }
        // Down payment = 25% of the first installment (first milestone % of price)
        if (planId != null) {
            List<PaymentInstallements__c> pi = [
                SELECT Milestone__c FROM PaymentInstallements__c
                WHERE PaymentInstallment__c = :planId ORDER BY MilestoneNumber__c ASC LIMIT 1
            ];
            if (!pi.isEmpty() && pi[0].Milestone__c != null) {
                Decimal firstInstallment = totalAmount * pi[0].Milestone__c / 100;
                f.downPayment = maxOf(firstInstallment * 0.25, FEE_FLOOR);
            }
        }
        f.minimum = nz(f.admFee) + nz(f.downPayment);
        return f;
    }

    private static String resolveChannel(Unit__c unit, String purpose) {
        String escrowId = unit.Phase__r != null ? unit.Phase__r.EscrowAccount__c : null;
        if (String.isNotBlank(escrowId)) {
            List<EscrowAccount__c> ea = [
                SELECT Processing_Channel_Id__c, ADM_Processing_Channel_Id__c
                FROM EscrowAccount__c WHERE Id = :escrowId LIMIT 1
            ];
            if (!ea.isEmpty()) {
                String ch = (purpose == 'ADM Fee') ? ea[0].ADM_Processing_Channel_Id__c : ea[0].Processing_Channel_Id__c;
                if (String.isNotBlank(ch)) return ch;
            }
        }
        return null; // falls back to the Checkout_Config default channel in the service
    }

    // Recompute the fees server-side from the stashed unit/plan (never trust a client-supplied value).
    private static Fees feesFromPayload(String soPayload) {
        if (String.isBlank(soPayload)) return new Fees();
        try {
            Map<String, Object> m = (Map<String, Object>) JSON.deserializeUntyped(soPayload);
            List<SalesOrder__c> sos = (List<SalesOrder__c>) JSON.deserialize(
                JSON.serialize(m.get('salesOrders')), List<SalesOrder__c>.class
            );
            if (sos.isEmpty() || String.isBlank(sos[0].Unit__c) || sos[0].TotalAmount__c == null) return new Fees();
            Unit__c unit = [SELECT Id, Phase__c, Phase__r.EscrowAccount__c FROM Unit__c WHERE Id = :sos[0].Unit__c LIMIT 1];
            return computeFees(unit, sos[0].PaymentPlan__c, sos[0].TotalAmount__c);
        } catch (Exception e) { return new Fees(); }
    }

    private static void applyCustomer(CheckoutPaymentLinkService.Request req, String opportunityId) {
        if (String.isBlank(opportunityId)) return;
        List<Opportunity> opps = [SELECT Id, ContactId, CurrencyIsoCode FROM Opportunity WHERE Id = :opportunityId LIMIT 1];
        if (opps.isEmpty()) return;
        if (String.isBlank(req.currencyCode)) req.currencyCode = opps[0].CurrencyIsoCode;
        if (opps[0].ContactId != null) {
            List<Contact> cons = [SELECT Name, Email, MobilePhone, Phone FROM Contact WHERE Id = :opps[0].ContactId LIMIT 1];
            if (!cons.isEmpty()) {
                req.customerName = cons[0].Name;
                req.customerEmail = cons[0].Email;
                req.customerPhoneNumber = String.isNotBlank(cons[0].MobilePhone) ? cons[0].MobilePhone : cons[0].Phone;
            }
        }
    }

    private static String resolveCurrency(SalesOrder__c so, String oppId) {
        if (so != null && String.isNotBlank(so.CurrencyIsoCode)) return so.CurrencyIsoCode;
        if (String.isNotBlank(oppId)) {
            List<Opportunity> o = [SELECT CurrencyIsoCode FROM Opportunity WHERE Id = :oppId LIMIT 1];
            if (!o.isEmpty()) return o[0].CurrencyIsoCode;
        }
        return 'AED';
    }

    private static Integer linkExpirySeconds() {
        Checkout_Config__mdt c = Checkout_Config__mdt.getInstance('Default');
        return (c != null && c.Booking_Link_Expiry_Seconds__c != null) ? c.Booking_Link_Expiry_Seconds__c.intValue() : DEFAULT_LINK_EXPIRY;
    }

    private static Integer maxLinksPerFee() {
        Checkout_Config__mdt c = Checkout_Config__mdt.getInstance('Default');
        return (c != null && c.Max_Booking_Links_Per_Fee__c != null) ? c.Max_Booking_Links_Per_Fee__c.intValue() : DEFAULT_MAX_LINKS;
    }

    private static String genRef() {
        return 'CKO-' + EncodingUtil.convertToHex(Crypto.generateAesKey(128)).substring(0, 18);
    }

    private static Decimal nz(Decimal v) { return v == null ? 0 : v; }
    private static Decimal maxOf(Decimal a, Decimal b) { return a >= b ? a : b; }
}