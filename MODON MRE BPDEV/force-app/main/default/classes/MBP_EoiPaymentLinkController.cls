/**
 * MBP_EoiPaymentLinkController
 * Aurelix IT - 9 Sep 2026 - BP-030 (Broker Portal, EOI drawer)
 * Prateek Bansal - 21 Sep 2026 - Reads EOI_Amount_AED__c, the field every org has, so one class body
 * serves all five. A hold still being recovered is no longer treated as spent, so a broker cannot raise
 * a second link over it.
 * Prateek Bansal - 12 Sep 2026 - hasLapsed also treats Authorization Expired as spent, so a hold
 * that ran out is not shown to the broker as a live request. retire() still stamps plain Expired:
 * a request replaced by a newer link is a retired link, not a lapsed hold.
 *
 * Creates the Checkout.com payment link for ONE broker EOI right after "Submit EOI".
 * Mirrors the Sales Console "Checkout Payments -> Create payment link" modal for an EOI
 * (CheckoutPaymentConsoleController.createLinkFromRecord('EOI', ...)) with the two options
 * the business fixed for brokers: Payment type = Authorize only (capture = false) and
 * Link expires in = 1 day (86400 s). The existing CheckoutPaymentTrigger then emails and
 * SMSes the link to the customer; nothing here sends a message itself.
 *
 * Guards (all surface as a plain AuraHandledException message):
 *   - caller must be a broker user (Contact + agency) and the EOI must belong to that agency
 *     (Agents: only their own EOIs), the same scoping getEOIRecords uses;
 *   - EOI_Amount_AED__c must be > 0 and the customer must have an email;
 *   - idempotent: an open link (Link Created / Authorized / Captured) already on the EOI is
 *     returned as-is, so a retry after a timeout never creates a second link.
 *
 * The broker only ever sees the Checkout_Payment__c Name (CP-nnnnn); never the EOI number.
 *
 * BP-041 (10 Sep 2026): the broker portal no longer creates the EOI at Submit. createInterestLink(opportunityId,
 * interestJson) creates ONE Checkout payment request per interest carrying the shared rail's creation payload
 * (EoiCheckoutPaymentController.EoiPayload) on the Opportunity; the rail creates the EOI once the payment is
 * Authorized (CheckoutEoiMaterializer), so the broker fields travel via the Opportunity. getBrokerPendingLinks()
 * lists those requests while no EOI exists yet. createPaymentLink(eoiId) stays for one release (cached bundles).
 *
 * BP-032 (9 Sep 2026): getEoiPaymentLinks (CP number + status per EOI for the broker EOI table) and
 * voidEoi (server-side rule: only while the latest link is still 'Link Created'; voids the link row too).
 *
 * BP-057/058 (11 Sep 2026): the EOI table's row actions - resendBrokerLink (send the live link again),
 * renewBrokerLink and cancelBrokerPayment (release a hold). Every one re-reads the stored record and
 * re-proves the agency before acting; the button is never trusted.
 *
 * BP-060 (11 Sep 2026): renewBrokerLink now CREATES a second payment request instead of renewing the
 * record in place (MODON reversed BP-057), and one interest carries one actionable request - the newest
 * for that opportunity and interest. Every message a broker can see is written here in plain words;
 * Checkout's own error text is never shown, only logged.
 */
public with sharing class MBP_EoiPaymentLinkController {

    /* BP-070: the browser never sends a range id, so this class re-resolves the range on submit.
       It must use the SAME Show On predicate as MBP_ExpressionOfInterestsController.getBrokerRangeOptions,
       or a broker could be shown one price and charged another. */
    @TestVisible private static final String SHOW_ON_BROKER = 'Broker Portal';
    @TestVisible private static final Integer LINK_EXPIRY_SECONDS = 86400;   // 1 day
    @TestVisible private static final Boolean CAPTURE_ON_PAYMENT  = false;   // Authorize only
    private static final Set<String> OPEN_LINK_STATUSES = new Set<String>{ 'Link Created', 'Authorized', 'Captured' };

    // ── BP-041: payment request per interest on the shared authorize rail ────
    /** The broker sees the EOI number once the money is held or taken (MODON, 10 Sep 2026); the LWC mirrors this set. */
    public static final Set<String> EOI_NUMBER_VISIBLE_STATUSES = new Set<String>{ 'Authorized', 'Captured', 'Refunded', 'Partially Refunded' };
    @TestVisible private static final String EOI_CURRENCY = 'AED';       // EOI ranges are priced in AED; the org is multi-currency
    @TestVisible private static final Integer PENDING_WINDOW_DAYS = 7;   // same window as the console's Awaiting payment view
    private static final Set<String> LIVE_LINK_STATUSES = new Set<String>{ 'Link Created', 'Authorized' };
    private static final String OPPORTUNITY_KEY_PREFIX = '006';
    private static final String PAYMENT_TYPE_ONLINE = 'Online';

    public class LinkResult {
        @AuraEnabled public Boolean success = false;
        @AuraEnabled public Boolean alreadyExisted = false;
        @AuraEnabled public Id eoiId;
        @AuraEnabled public Id paymentId;
        @AuraEnabled public String paymentName;      // CP-nnnnn - the only reference shown to the broker
        @AuraEnabled public String status;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public String currencyCode;
        @AuraEnabled public Datetime expiresOn;
        @AuraEnabled public String maskedEmail;
        @AuraEnabled public String maskedPhone;
        @AuraEnabled public String message;
    }

    @AuraEnabled
    public static LinkResult createPaymentLink(Id eoiId) {
        if (eoiId == null) {
            throw refuse('EOI id is required.');
        }
        Expressionofinterest__c eoi = loadBrokerEoi(eoiId);

        Checkout_Payment__c existing = LOOKUP.openLinkFor(eoi.Id, OPEN_LINK_STATUSES);
        if (existing != null) {
            return toResult(eoi, existing, true);
        }

        if (eoi.EOI_Amount_AED__c == null || eoi.EOI_Amount_AED__c <= 0) {
            throw refuse('This EOI has no outstanding balance.');
        }
        String customerEmail = firstNonBlank(eoi.Customer_Email__c, eoi.Contact__r != null ? eoi.Contact__r.Email : null);
        if (String.isBlank(customerEmail)) {
            throw refuse('The customer has no email address for the payment link.');
        }

        CheckoutPaymentLinkService.Request req = new CheckoutPaymentLinkService.Request();
        req.capture = CAPTURE_ON_PAYMENT;
        req.expirySeconds = LINK_EXPIRY_SECONDS;
        req.amount = eoi.EOI_Amount_AED__c;
        req.currencyCode = eoi.CurrencyIsoCode;
        req.customerEmail = customerEmail;
        req.customerName = eoi.Contact__r != null && String.isNotBlank(eoi.Contact__r.Name)
            ? eoi.Contact__r.Name
            : (eoi.Account__r != null ? eoi.Account__r.Name : null);
        req.customerPhoneNumber = customerPhone(eoi);
        req.description = 'EOI ' + eoi.Name + (String.isNotBlank(eoi.ProjectName__c) ? ' - ' + eoi.ProjectName__c : '');
        req.expressionOfInterestId = eoi.Id;
        req.relatedRecordId = eoi.Id;

        CheckoutPaymentLinkService.Product line = new CheckoutPaymentLinkService.Product();
        line.name = 'EOI ' + eoi.Name + (String.isNotBlank(eoi.ProjectName__c) ? ' – ' + eoi.ProjectName__c : '');
        line.quantity = 1;
        line.price = eoi.EOI_Amount_AED__c;
        req.products = new List<CheckoutPaymentLinkService.Product>{ line };

        CheckoutPaymentLinkService.Result r = CheckoutPaymentLinkService.createLink(req);
        if (r == null || r.isSuccess != true || r.paymentRecordId == null) {
            String reason = r == null ? 'No response from Checkout.' : r.message;
            throw refuse(String.isBlank(reason) ? 'The payment link could not be created.' : reason);
        }
        Checkout_Payment__c created = LOOKUP.byId(r.paymentRecordId);
        if (created == null) {
            throw refuse('The payment link was created but could not be read back.');
        }
        return toResult(eoi, created, false);
    }

    // ── BP-041: one payment request per interest, EOI created by the rail ───

    /** The interest as the drawer sends it. The range and the price are resolved on the server; ids in the JSON are hints only. */
    public class Interest {
        @AuraEnabled public String projectId;
        @AuraEnabled public String phaseId;
        @AuraEnabled public String unitType;
        @AuraEnabled public String bedrooms;
        @AuraEnabled public String unitTypology;
        @AuraEnabled public Integer numberOfUnits;
        @AuraEnabled public String remarks;
        @AuraEnabled public String slot;             // the drawer's interest slot ('interest-1' ...): two alike interests are two requests
    }

    /** One pending payment request (a Checkout_Payment__c row with no EOI yet), as the EOI tab shows it. Never the URL. */
    public class PendingRow {
        @AuraEnabled public Id paymentId;
        @AuraEnabled public String paymentName;      // CP-nnnnn
        @AuraEnabled public String status;           // Checkout_Payment__c.Status__c as stored
        /* BP-067: the client-approved wording, read from the formula field rather than mapped
           here, so reports, list views and this table can never drift apart. */
        @AuraEnabled public String dashboardStatus;
        @AuraEnabled public Datetime expiresOn;
        @AuraEnabled public Datetime createdDate;
        @AuraEnabled public String customerName;
        @AuraEnabled public String maskedEmail;
        @AuraEnabled public String maskedPhone;
        @AuraEnabled public Id opportunityId;
        @AuraEnabled public String opportunityName;
        @AuraEnabled public Id projectId;
        @AuraEnabled public String projectName;
        @AuraEnabled public String phaseName;
        @AuraEnabled public String unitType;
        @AuraEnabled public String bedrooms;
        @AuraEnabled public String unitTypology;
        @AuraEnabled public Integer units;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public String currencyCode;
        @AuraEnabled public String remarks;
        /* BP-060: a request a newer one has replaced. It keeps its number and its history and is
           still listed, but it offers no action, so one interest can never carry two live asks. */
        @AuraEnabled public Boolean superseded = false;
    }

    /** BP-060: the request the broker's table must land on, and the number their message names. */
    public class NewLinkResult {
        @AuraEnabled public Id paymentId;
        @AuraEnabled public String paymentName;   // CP-nnnnn - the new request
    }

    /**
     * Creates the Checkout payment request for ONE interest on a broker's Opportunity. No EOI is created here: the
     * request carries the creation payload and the shared rail raises the EOI when the payment is Authorized.
     * Idempotent per Opportunity + interest (project, phase, unit type, bedrooms, typology, units): a live request
     * (Link Created and not expired, or Authorized) is returned as alreadyExisted, so a Retry never doubles a link.
     */
    @AuraEnabled
    public static LinkResult createInterestLink(Id opportunityId, String interestJson) {
        if (opportunityId == null) {
            throw refuse('Opportunity id is required.');
        }
        BrokerScope me = brokerScope();
        Opportunity opp = LOOKUP.brokerOpportunity(opportunityId, me.agencyId);
        if (opp == null) {
            throw refuse('This opportunity does not belong to your agency.');
        }
        if (me.isAgent && opp.BrokerAgent__c != me.contactId) {
            throw refuse('This opportunity does not belong to you.');
        }

        Interest interest = parseInterest(interestJson);
        Integer units = interest.numberOfUnits == null || interest.numberOfUnits < 1 ? 1 : interest.numberOfUnits;

        // The org decides the range and the price (same predicate as getEOIRange); the browser's ids are hints only.
        EOI_Range__c range = LOOKUP.brokerRange(interest);
        if (range == null || range.Amount__c == null || range.Amount__c <= 0) {
            throw refuse('No active EOI range matches this interest. Reselect the interest and try again.');
        }
        Decimal amount = range.Amount__c * units;
        String slot = norm(interest.slot);
        String key = interestKey(range.Project__c, range.Phase__c, range.Unit_Type__c, range.No_of_Bedrooms__c, range.UnitTypologyMRE__c, units, slot);

        List<Checkout_Payment__c> live = LOOKUP.liveInterestLinks(opp.Id, key);
        if (!live.isEmpty()) {
            return toResult(live[0], true);
        }

        // The rail's EoiPayload shape (nulls left out) plus brokerSlot, which the rail ignores and the
        // idempotency key needs so that two alike interests stay two requests.
        Map<String, Object> payload = new Map<String, Object>{
            'opportunityId' => String.valueOf(opp.Id),
            'projectId'     => String.valueOf(range.Project__c),
            'unitType'      => range.Unit_Type__c,
            'bedrooms'      => range.No_of_Bedrooms__c,
            'unitTypology'  => range.UnitTypologyMRE__c,
            'numberOfUnits' => units,
            'eoiRangeId'    => String.valueOf(range.Id),
            'eoiAmount'     => amount,
            'paymentType'   => PAYMENT_TYPE_ONLINE,
            'currencyCode'  => EOI_CURRENCY
        };
        if (range.Phase__c != null) payload.put('phaseId', String.valueOf(range.Phase__c));
        if (String.isNotBlank(interest.remarks)) payload.put('remarks', interest.remarks);
        if (String.isNotBlank(slot)) payload.put('brokerSlot', slot);
        String payloadJson = JSON.serialize(payload);

        // Project quota counts EOIs plus live requests (MSC-230); the locked recheck runs again inside the service.
        try {
            EoiQuotaGuard.assertCapacity(payloadJson, false);
        } catch (EoiQuotaGuard.QuotaException qe) {
            throw refuse(qe.getMessage());
        }

        // The customer is the Opportunity contact (system mode: broker users cannot see customer Contacts).
        Contact customer = LOOKUP.customerContact(opp.ContactId);
        if (customer == null || String.isBlank(customer.Email)) {
            throw refuse('The customer has no email address for the payment request.');
        }

        CheckoutPaymentLinkService.Request req = new CheckoutPaymentLinkService.Request();
        req.capture = EoiPaymentPolicy.captureImmediately(EoiPaymentPolicy.CHANNEL_BROKER);
        req.expirySeconds = LINK_EXPIRY_SECONDS;
        req.amount = amount;
        req.currencyCode = EOI_CURRENCY;
        req.customerName = customer.Name;
        req.customerEmail = customer.Email.trim();
        req.customerPhoneNumber = String.isNotBlank(customer.MobilePhone) ? customer.MobilePhone : customer.Phone;
        req.description = 'EOI Payment' + (range.Project__r != null && String.isNotBlank(range.Project__r.Name) ? ' - ' + range.Project__r.Name : '');
        req.relatedRecordId = String.valueOf(opp.Id);
        req.eoiPayload = payloadJson;

        CheckoutPaymentLinkService.Result r = CheckoutPaymentLinkService.createLink(req);
        if (r == null || r.isSuccess != true || r.paymentRecordId == null) {
            String reason = r == null ? 'No response from Checkout.' : r.message;
            throw refuse(String.isBlank(reason) ? 'The payment request could not be created.' : reason);
        }

        // Nothing can lock before a callout, so two tabs can both pass the lookup above: keep the older request,
        // never delete the newer one (its message is already queued).
        live = LOOKUP.liveInterestLinks(opp.Id, key);
        if (live.size() > 1) {
            System.debug(LoggingLevel.WARN, '[MBP_EoiPaymentLinkController] duplicate live request on ' + opp.Id + ' for ' + key + '; returning ' + live[0].Name);
            return toResult(live[0], true);
        }
        Checkout_Payment__c created = LOOKUP.byId(r.paymentRecordId);
        if (created == null) {
            throw refuse('The payment request was created but could not be read back.');
        }
        return toResult(created, false);
    }

    /**
     * The agency's payment requests that have no EOI yet (last PENDING_WINDOW_DAYS days, every stored status), newest
     * first. Agents see their own Opportunities only. Payload rows are read first (small, indexed on CreatedDate) and
     * then filtered by the agency's Opportunities, never the other way round.
     */
    @AuraEnabled
    public static List<PendingRow> getBrokerPendingLinks() {
        BrokerScope me = brokerScope();
        List<PendingRow> out = new List<PendingRow>();
        Datetime cutoff = System.now().addDays(-PENDING_WINDOW_DAYS);
        List<Checkout_Payment__c> rows = LOOKUP.recentPayloadRows(cutoff);
        if (rows.isEmpty()) return out;

        Set<Id> oppIds = new Set<Id>();
        for (Checkout_Payment__c cp : rows) {
            Id oppId = asId(cp.Related_Record_Id__c);
            if (oppId != null) oppIds.add(oppId);
        }
        Map<Id, Opportunity> opps = LOOKUP.agencyOpportunities(oppIds, me.agencyId, me.isAgent ? me.contactId : null);
        if (opps.isEmpty()) return out;

        Map<Id, EoiCheckoutPaymentController.EoiPayload> payloadByRow = new Map<Id, EoiCheckoutPaymentController.EoiPayload>();
        Set<Id> projectIds = new Set<Id>();
        Set<Id> phaseIds = new Set<Id>();
        for (Checkout_Payment__c cp : rows) {
            Id oppId = asId(cp.Related_Record_Id__c);
            if (oppId == null || !opps.containsKey(oppId)) continue;
            EoiCheckoutPaymentController.EoiPayload p = parsePayload(cp.EOI_Creation_Payload__c);
            if (p == null) continue;
            payloadByRow.put(cp.Id, p);
            Id projectId = asId(p.projectId);
            Id phaseId = asId(p.phaseId);
            if (projectId != null) projectIds.add(projectId);
            if (phaseId != null) phaseIds.add(phaseId);
        }
        Map<Id, String> projectNames = LOOKUP.namesById(projectIds);
        Map<Id, String> phaseNames = LOOKUP.namesById(phaseIds);

        /* BP-060: a request is actionable only while it is the newest for its opportunity and its
           interest. Replacements that have already been paid have left this list for the EOI table,
           so they are read back as well - without them a paid interest would offer a new link again. */
        Set<String> relatedIds = new Set<String>();
        for (Id key : opps.keySet()) relatedIds.add(String.valueOf(key));
        List<Checkout_Payment__c> ranked = new List<Checkout_Payment__c>(rows);
        ranked.addAll(LOOKUP.settledPayloadRows(cutoff, relatedIds));
        Map<String, Datetime> newestByInterest = new Map<String, Datetime>();
        for (Checkout_Payment__c cp : ranked) {
            String groupKey = interestGroupKey(cp);
            if (groupKey == null || cp.CreatedDate == null) continue;
            Datetime seen = newestByInterest.get(groupKey);
            if (seen == null || cp.CreatedDate > seen) newestByInterest.put(groupKey, cp.CreatedDate);
        }

        for (Checkout_Payment__c cp : rows) {
            EoiCheckoutPaymentController.EoiPayload p = payloadByRow.get(cp.Id);
            if (p == null) continue;
            Id oppId = asId(cp.Related_Record_Id__c);
            PendingRow row = new PendingRow();
            row.paymentId = cp.Id;
            row.paymentName = cp.Name;
            row.status = cp.Status__c;
            row.dashboardStatus = cp.Dashboard_Status__c;
            row.expiresOn = cp.Expires_On__c;
            row.createdDate = cp.CreatedDate;
            row.customerName = cp.Customer_Name__c;
            row.maskedEmail = maskEmail(cp.Customer_Email__c);
            row.maskedPhone = maskPhone(cp.Customer_Phone__c);
            row.opportunityId = oppId;
            row.opportunityName = opps.get(oppId).Name;
            row.projectId = asId(p.projectId);
            row.projectName = row.projectId == null ? null : projectNames.get(row.projectId);
            Id phaseId = asId(p.phaseId);
            row.phaseName = phaseId == null ? null : phaseNames.get(phaseId);
            row.unitType = p.unitType;
            row.bedrooms = p.bedrooms;
            row.unitTypology = p.unitTypology;
            row.units = p.numberOfUnits == null || p.numberOfUnits < 1 ? 1 : p.numberOfUnits;
            row.amount = cp.Amount__c != null ? cp.Amount__c : p.eoiAmount;
            row.currencyCode = cp.Currency_Code__c;
            row.remarks = p.remarks;
            row.superseded = isSuperseded(cp, newestByInterest);
            out.add(row);
        }
        return out;
    }

    // ── BP-041 helpers ───────────────────────────────────────────────────────

    private static Interest parseInterest(String interestJson) {
        Interest it;
        try {
            it = (Interest) JSON.deserialize(interestJson, Interest.class);
        } catch (Exception e) {
            it = null;
        }
        /* BP-054: the broker form is Project + Unit Type + Bedrooms. Phase and typology are no longer
           asked for, so they are no longer required here - brokerRange() below resolves the row from the
           three fields and the payload takes phase and typology from whatever that row carries. The three
           fields the form does ask for are still mandatory, and the range lookup is still the real gate:
           an interest that matches no active broker range is refused a line later. */
        if (it == null || String.isBlank(it.projectId) || String.isBlank(it.unitType) || String.isBlank(it.bedrooms)) {
            throw refuse('Complete the interest details before sending the payment request.');
        }
        return it;
    }

    /**
     * One key per interest slot: 18-character ids, trimmed lower-cased text, units defaulted to 1, plus the drawer's
     * slot. Same key from a stored payload. A Retry re-sends the same slot (same key); two alike interests in one
     * submission carry different slots and therefore become two requests, as MODON's model requires.
     */
    @TestVisible
    private static String interestKey(String projectId, String phaseId, String unitType, String bedrooms, String unitTypology, Integer units, String slot) {
        return String.join(new List<String>{
            normalizeId(projectId), normalizeId(phaseId), norm(unitType), norm(bedrooms), norm(unitTypology),
            String.valueOf(units == null || units < 1 ? 1 : units), norm(slot)
        }, '|');
    }

    private static String payloadKey(String payloadJson) {
        if (String.isBlank(payloadJson)) return null;
        try {
            Map<String, Object> m = (Map<String, Object>) JSON.deserializeUntyped(payloadJson);
            Object unitsRaw = m.get('numberOfUnits');
            Integer units = unitsRaw == null ? null : Integer.valueOf(String.valueOf(unitsRaw));
            return interestKey((String) m.get('projectId'), (String) m.get('phaseId'), (String) m.get('unitType'), (String) m.get('bedrooms'),
                (String) m.get('unitTypology'), units, (String) m.get('brokerSlot'));
        } catch (Exception e) {
            return null;
        }
    }

    /* BP-060: one opportunity can carry several interests, so a request is identified by its
       opportunity AND its stored interest. A row with no opportunity or no readable payload belongs
       to no group and can never be superseded by another. */
    private static String interestGroupKey(Checkout_Payment__c cp) {
        if (cp == null || String.isBlank(cp.Related_Record_Id__c)) return null;
        String key = payloadKey(cp.EOI_Creation_Payload__c);
        return String.isBlank(key) ? null : cp.Related_Record_Id__c + '|' + key;
    }

    private static Boolean isSuperseded(Checkout_Payment__c cp, Map<String, Datetime> newestByInterest) {
        String groupKey = interestGroupKey(cp);
        if (groupKey == null || cp.CreatedDate == null) return false;
        Datetime newest = newestByInterest.get(groupKey);
        return newest != null && newest > cp.CreatedDate;
    }

    /** Never trust the button: the same rule the list is built with, re-read before anything is sent. */
    private static void assertNewest(Checkout_Payment__c cp) {
        if (LOOKUP.hasNewerRequest(cp.Related_Record_Id__c, payloadKey(cp.EOI_Creation_Payload__c), cp.CreatedDate)) {
            throw refuse('A newer payment request has already been sent for this interest.');
        }
    }

    /** A request whose link is spent: stored Expired, or still 'Link Created' with its clock run out -
        CheckoutPaymentPoller only flips a lapsed link on its next pass, so the clock decides, not the status. */
    private static Boolean hasLapsed(Checkout_Payment__c cp) {
        if (cp.Status__c == 'Expired') return true;
        // A hold that ran out is retried for a couple of days before anyone gives up on it. Until the
        // business has been told, it is not spent - and a new link raised now could double the deposit.
        if (cp.Status__c == 'Authorization Expired') return cp.Recovery_Alert_Sent__c == true;
        return cp.Status__c == LINK_CREATED && cp.Expires_On__c != null && cp.Expires_On__c < System.now();
    }

    /** The description a broker request carries: "EOI Payment - <project>". Read in system mode, and
        blank is fine - CheckoutPaymentLinkService simply omits it. */
    private static String requestDescription(String payloadJson) {
        EoiCheckoutPaymentController.EoiPayload p = parsePayload(payloadJson);
        Id projectId = p == null ? null : asId(p.projectId);
        if (projectId == null) return 'EOI Payment';
        String name = LOOKUP.namesById(new Set<Id>{ projectId }).get(projectId);
        return String.isBlank(name) ? 'EOI Payment' : 'EOI Payment - ' + name;
    }

    private static EoiCheckoutPaymentController.EoiPayload parsePayload(String payloadJson) {
        if (String.isBlank(payloadJson)) return null;
        try {
            return (EoiCheckoutPaymentController.EoiPayload) JSON.deserialize(payloadJson, EoiCheckoutPaymentController.EoiPayload.class);
        } catch (Exception e) {
            return null;
        }
    }

    /** Live = still payable or already held. Expires_On__c is the LINK expiry, so it is ignored once the money is held. */
    @TestVisible
    private static Boolean isLive(Checkout_Payment__c cp) {
        if (cp == null) return false;
        if (cp.Status__c == 'Authorized') return true;
        return cp.Status__c == 'Link Created' && (cp.Expires_On__c == null || cp.Expires_On__c > System.now());
    }

    private static String normalizeId(String raw) {
        if (String.isBlank(raw)) return '';
        try {
            return String.valueOf((Id) raw.trim());
        } catch (Exception e) {
            return norm(raw);
        }
    }

    private static String norm(String raw) {
        return raw == null ? '' : raw.trim().toLowerCase();
    }

    private static Id asId(String raw) {
        if (String.isBlank(raw)) return null;
        try {
            return (Id) raw.trim();
        } catch (Exception e) {
            return null;
        }
    }

    private static LinkResult toResult(Checkout_Payment__c cp, Boolean alreadyExisted) {
        LinkResult out = new LinkResult();
        out.success = true;
        out.alreadyExisted = alreadyExisted;
        out.eoiId = null;                       // no EOI exists until the payment is authorized
        out.paymentId = cp.Id;
        out.paymentName = cp.Name;
        out.status = cp.Status__c;
        out.amount = cp.Amount__c;
        out.currencyCode = cp.Currency_Code__c;
        out.expiresOn = cp.Expires_On__c;
        out.maskedEmail = maskEmail(cp.Customer_Email__c);
        out.maskedPhone = maskPhone(cp.Customer_Phone__c);
        out.message = alreadyExisted ? 'A payment request already exists for this interest.' : 'Payment request created.';
        return out;
    }

    // ── BP-032: EOI table support ────────────────────────────────────────────

    private static final String LINK_CREATED = 'Link Created';

    public class LinkInfo {
        @AuraEnabled public Id eoiId;
        /* BP-059: the Checkout_Payment__c record id. An EOI row's own id is the EOI's, so without
           this the table had nothing to hand a row action and Cancel was sent an EOI id. */
        @AuraEnabled public Id paymentId;
        @AuraEnabled public String paymentName;   // CP-nnnnn
        @AuraEnabled public String status;        // Checkout_Payment__c.Status__c
        @AuraEnabled public String dashboardStatus;  // BP-067: the word the broker reads
        @AuraEnabled public Datetime expiresOn;
    }

    /** Latest payment link per EOI, only for EOIs the caller may see (agency; agents: own). */
    @AuraEnabled
    public static List<LinkInfo> getEoiPaymentLinks(List<Id> eoiIds) {
        List<LinkInfo> out = new List<LinkInfo>();
        if (eoiIds == null || eoiIds.isEmpty()) return out;
        BrokerScope me = brokerScope();
        for (Checkout_Payment__c cp : LOOKUP.latestLinks(new Set<Id>(eoiIds), me.agencyId, me.isAgent ? me.contactId : null)) {
            LinkInfo li = new LinkInfo();
            li.eoiId = cp.Expression_of_Interest__c;
            li.paymentId = cp.Id;              // BP-059: the row actions act on THIS record
            li.paymentName = cp.Name;
            li.status = cp.Status__c;
            li.dashboardStatus = cp.Dashboard_Status__c;
            li.expiresOn = cp.Expires_On__c;
            out.add(li);
        }
        return out;
    }

    /** Void an EOI from the broker table. Allowed only while its latest link is still 'Link Created' (or it has no link). */
    @AuraEnabled
    public static void voidEoi(Id eoiId, String reason) {
        if (eoiId == null) throw refuse('EOI id is required.');
        if (String.isBlank(reason)) throw refuse('A void reason is required.');
        Expressionofinterest__c eoi = loadBrokerEoi(eoiId);              // agency / agent scoping
        if (eoi.Status__c == 'Voided') throw refuse('This EOI is already voided.');
        Checkout_Payment__c cp = LOOKUP.latestLink(eoi.Id);
        if (cp != null && cp.Status__c != LINK_CREATED) {
            throw refuse('This EOI can no longer be voided.');
        }
        LOOKUP.voidEoi(eoi.Id, reason.trim(), cp);
    }

    // ── BP-057: the broker EOI table's row actions ───────────────────────────

    /**
     * Send the link the customer already has, again. Same URL, same expiry - resending can never
     * extend any clock (CheckoutNotificationService.resendLink, MSC-229, the console's own Resend),
     * and no call reaches Checkout at all.
     *
     * Offered only while the link is genuinely payable. A row can still read 'Link Created' after
     * its clock has run out, because CheckoutPaymentPoller flips it on its next pass; sending then
     * would mail the customer a dead URL, so the expiry is checked as well as the status.
     */
    @AuraEnabled
    public static String resendBrokerLink(Id paymentId) {
        Checkout_Payment__c cp = brokerPayment(paymentId);
        assertNewest(cp);
        if (String.isBlank(cp.Payment_Link_Url__c)) {
            throw refuse('A payment link is not available for this request.');
        }
        if (!LIVE_LINK_STATUSES.contains(cp.Status__c)) {
            throw refuse('This payment request is no longer active.');
        }
        if (cp.Status__c == LINK_CREATED && cp.Expires_On__c != null && cp.Expires_On__c < System.now()) {
            throw refuse('This link has expired. Use Send new link to issue a new one.');
        }
        if (CheckoutNotificationService.resendLink(new Set<Id>{ cp.Id }) == 0) {
            throw refuse('The link could not be sent. Please try again.');
        }
        return cp.Name;
    }

    /**
     * BP-060 (11 Sep 2026). Send a NEW payment request for an interest whose link has run out.
     * MODON reversed BP-057's renew-in-place: the broker's table must show a new CP number, so a
     * second Checkout_Payment__c is created through the same rail a first request uses, and the
     * spent request is retired.
     *
     * The new record takes its OWN Reference__c - createLink generates one when the request leaves
     * it blank. Reusing the old reference would send the customer's payment to the dead record,
     * because CheckoutWebhookResource.findRow and applyStatusByReference both match a payment back
     * to its record by reference.
     *
     * Nothing is sent from here. A new row with Portal_Initiated__c false at 'Link Created' reaches
     * CheckoutNotificationService as a 'created' event through CheckoutPaymentTrigger, so the
     * customer gets exactly one message; calling resendLink as well would send a second.
     */
    @AuraEnabled
    public static NewLinkResult renewBrokerLink(Id paymentId) {
        Checkout_Payment__c cp = brokerPayment(paymentId);
        if (!hasLapsed(cp)) {
            throw refuse('This payment request still has a live link. Use Resend link to send it again.');
        }
        assertNewest(cp);

        Id oppId = asId(cp.Related_Record_Id__c);
        String key = payloadKey(cp.EOI_Creation_Payload__c);
        if (String.isBlank(key)) {
            throw refuse('This payment request cannot be managed here.');
        }
        // Anything still payable for this interest is the answer already; never a second live ask.
        if (!LOOKUP.liveInterestLinks(oppId, key).isEmpty()) {
            throw refuse('A newer payment request has already been sent for this interest.');
        }
        if (String.isBlank(cp.Customer_Email__c)) {
            throw refuse('The customer has no email address for the payment request.');
        }
        if (cp.Amount__c == null || cp.Amount__c <= 0) {
            throw refuse('This payment request cannot be managed here.');
        }
        /* Project quota counts EOIs plus live requests (MSC-230). The spent request does not count -
           EoiQuotaGuard skips a row whose expiry has passed - so this can never refuse on its own
           replacement. The locked recheck still runs inside the service, after the callout. */
        try {
            EoiQuotaGuard.assertCapacity(cp.EOI_Creation_Payload__c, false);
        } catch (EoiQuotaGuard.QuotaException qe) {
            throw refuse(qe.getMessage());
        }

        // Same customer, same amount, same stored interest: paying the new link raises the same EOI.
        CheckoutPaymentLinkService.Request req = new CheckoutPaymentLinkService.Request();
        req.capture = EoiPaymentPolicy.captureImmediately(EoiPaymentPolicy.CHANNEL_BROKER);
        req.expirySeconds = LINK_EXPIRY_SECONDS;
        req.amount = cp.Amount__c;
        req.currencyCode = String.isBlank(cp.Currency_Code__c) ? EOI_CURRENCY : cp.Currency_Code__c;
        req.customerName = cp.Customer_Name__c;
        req.customerEmail = cp.Customer_Email__c.trim();
        req.customerPhoneNumber = cp.Customer_Phone__c;
        req.description = requestDescription(cp.EOI_Creation_Payload__c);
        req.relatedRecordId = String.valueOf(oppId);
        req.eoiPayload = cp.EOI_Creation_Payload__c;

        CheckoutPaymentLinkService.Result r = CheckoutPaymentLinkService.createLink(req);
        if (r == null || r.isSuccess != true || r.paymentRecordId == null) {
            // Checkout's own wording never reaches a broker's screen; it is already in the API log.
            throw refuse('The payment link could not be created. Please try again.');
        }
        /* The spent request is closed in the same transaction, with its expiry message suppressed:
           the customer has just been sent a newer link, so "contact us for a new link" would be
           wrong. Doing it here also keeps the stored status true, instead of leaving the row reading
           'Link Created' until the poller's next pass. */
        LOOKUP.retire(cp.Id);

        Checkout_Payment__c created = LOOKUP.byId(r.paymentRecordId);
        NewLinkResult out = new NewLinkResult();
        out.paymentId = r.paymentRecordId;
        out.paymentName = created == null ? null : created.Name;
        return out;
    }

    /**
     * BP-058 (11 Sep 2026). Release a hold the customer's card is still carrying, from the broker
     * EOI table. Offered on an Authorized payment ONLY: once the money is captured a reversal is a
     * finance process, and CheckoutEoiMaterializer deliberately leaves a captured EOI to it
     * ("a captured EOI whose payment is voided or refunded later is left to the refund process").
     *
     * No new EOI logic is written here. Releasing the hold puts the payment into a lapsed status,
     * and the rail that already closes an expired or declined hold - CheckoutPaymentTrigger ->
     * CheckoutEoiMaterializer.closeLapsedEois - marks the expression of interest Cancelled and
     * writes the reason for finance. The customer's cancellation message goes out the same way.
     */
    @AuraEnabled
    public static String cancelBrokerPayment(Id paymentId) {
        Checkout_Payment__c cp = brokerPayment(paymentId);
        if (cp.Status__c == 'Captured') {
            throw refuse('This payment has already been completed and cannot be cancelled.');
        }
        if (cp.Status__c != 'Authorized') {
            throw refuse('This payment can no longer be cancelled.');
        }
        if (String.isBlank(cp.Payment_Id__c)) {
            throw refuse('This payment cannot be cancelled yet. Please try again shortly.');
        }
        CheckoutPaymentLinkService.Result r = CheckoutPaymentLinkService.voidPayment(cp.Payment_Id__c);
        if (r == null || r.isSuccess != true) {
            // Checkout's own wording never reaches a broker's screen; it is already in the API log.
            throw refuse('The payment could not be cancelled. Please try again.');
        }
        /* voidPayment asks CheckoutPaymentLinkService.updateTrackingStatus to write the new status,
           but that class is `with sharing` and Checkout_Payment__c is Private, so for a broker its
           SOQL finds nothing and the row is left reading Authorized while the money is already
           released. The row is therefore closed here, in system mode. */
        LOOKUP.markVoided(cp.Id);
        return cp.Name;
    }

    /**
     * One payment row, proved to belong to this broker before anything is done to it. The row itself
     * is Private externally, so it is read in system mode and the agency (and, for an Agent, the
     * agent) is enforced here through the Opportunity the request was raised against - the same
     * predicate getBrokerPendingLinks lists by, so a broker can only ever act on a row they can see.
     *
     * Never trust the button: the caller sends an id, and every rule is re-read from the stored row.
     */
    private static Checkout_Payment__c brokerPayment(Id paymentId) {
        if (paymentId == null) throw refuse('Something went wrong. Please try again.');
        BrokerScope me = brokerScope();
        Checkout_Payment__c cp = LOOKUP.actionRow(paymentId);
        if (cp == null) throw refuse('This payment request is no longer available.');
        if (String.isBlank(cp.EOI_Creation_Payload__c)) {
            throw refuse('This payment request cannot be managed here.');
        }
        Id oppId = asId(cp.Related_Record_Id__c);
        if (oppId == null) throw refuse('This payment request cannot be managed here.');
        if (LOOKUP.agencyOpportunities(new Set<Id>{ oppId }, me.agencyId, me.isAgent ? me.contactId : null).isEmpty()) {
            throw refuse('You do not have access to this payment request.');
        }
        return cp;
    }

    private class BrokerScope { Id contactId; Id agencyId; Boolean isAgent = false; }

    private static BrokerScope brokerScope() {
        User me = [
            SELECT Id, ContactId, Contact.AccountId, Contact.Broker_Type__c
            FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1
        ];
        if (me.ContactId == null || me.Contact.AccountId == null) {
            throw refuse('Your account is not linked to an agency.');
        }
        BrokerScope sc = new BrokerScope();
        sc.contactId = me.ContactId;
        sc.agencyId = me.Contact.AccountId;
        String brokerType = String.isBlank(me.Contact.Broker_Type__c) ? '' : me.Contact.Broker_Type__c.trim().toLowerCase();
        sc.isAgent = brokerType == 'agent';
        return sc;
    }

    // ── scoping ──────────────────────────────────────────────────────────────

    private static Expressionofinterest__c loadBrokerEoi(Id eoiId) {
        User me = [
            SELECT Id, ContactId, Contact.AccountId, Contact.Broker_Type__c
            FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1
        ];
        if (me.ContactId == null || me.Contact.AccountId == null) {
            throw refuse('Your account is not linked to an agency.');
        }
        // The agency filter is the guard. The read itself runs in system mode because the customer
        // Contact / Account behind the EOI is not shared to broker users, and a with-sharing read
        // would silently return the name and mobile as null (no SMS, no name on the link).
        Expressionofinterest__c eoi = LOOKUP.brokerEoi(eoiId, me.Contact.AccountId);
        if (eoi == null) {
            throw refuse('This EOI does not belong to your agency.');
        }
        String brokerType = String.isBlank(me.Contact.Broker_Type__c) ? '' : me.Contact.Broker_Type__c.trim().toLowerCase();
        if (brokerType == 'agent' && eoi.Opportunity__r.BrokerAgent__c != me.ContactId) {
            throw refuse('This EOI does not belong to you.');
        }
        return eoi;
    }

    // ── helpers ──────────────────────────────────────────────────────────────

    // AuraHandledException only carries its text to the client (and to tests) when setMessage is called
    private static AuraHandledException refuse(String message) {
        AuraHandledException e = new AuraHandledException(message);
        e.setMessage(message);
        return e;
    }

    private static LinkResult toResult(Expressionofinterest__c eoi, Checkout_Payment__c cp, Boolean alreadyExisted) {
        LinkResult out = new LinkResult();
        out.success = true;
        out.alreadyExisted = alreadyExisted;
        out.eoiId = eoi.Id;
        out.paymentId = cp.Id;
        out.paymentName = cp.Name;
        out.status = cp.Status__c;
        out.amount = cp.Amount__c;
        out.currencyCode = cp.Currency_Code__c;
        out.expiresOn = cp.Expires_On__c;
        out.maskedEmail = maskEmail(cp.Customer_Email__c);
        out.maskedPhone = maskPhone(cp.Customer_Phone__c);
        out.message = alreadyExisted ? 'A payment link already exists for this EOI.' : 'Payment link created.';
        return out;
    }

    private static String customerPhone(Expressionofinterest__c eoi) {
        if (eoi.Contact__r != null && String.isNotBlank(eoi.Contact__r.MobilePhone)) return eoi.Contact__r.MobilePhone;
        if (eoi.Contact__r != null && String.isNotBlank(eoi.Contact__r.Phone)) return eoi.Contact__r.Phone;
        if (eoi.Account__r != null && String.isNotBlank(eoi.Account__r.Phone)) return eoi.Account__r.Phone;
        return null;
    }

    private static String firstNonBlank(String a, String b) {
        return String.isNotBlank(a) ? a.trim() : (String.isNotBlank(b) ? b.trim() : null);
    }

    // Same shapes VerificationService writes to Masked_Target__c, so every broker screen agrees.
    @TestVisible
    private static String maskEmail(String email) {
        List<String> parts = (email == null ? '' : email.trim()).split('@');
        if (parts.size() != 2 || parts[0].length() == 0) return '';
        Integer visible = Math.min(2, parts[0].length());
        return parts[0].substring(0, visible) + '***@' + parts[1];
    }

    @TestVisible
    private static String maskPhone(String phone) {
        String digits = phone == null ? '' : phone.replaceAll('[^0-9]', '');
        return digits.length() > 4 ? '****' + digits.substring(digits.length() - 4) : '';
    }

    /**
     * System-mode reads, each restricted to one EOI id (plus the agency filter) or one payment id:
     * the customer Contact/Account behind the EOI and Checkout_Payment__c rows (Private externally,
     * so a console-made link on the same EOI would otherwise be invisible to the broker).
     */
    private static final PaymentLookup LOOKUP = new PaymentLookup();

    private without sharing class PaymentLookup {
        Expressionofinterest__c brokerEoi(Id eoiId, Id agencyId) {
            List<Expressionofinterest__c> rows = [
                SELECT Id, Name, Status__c, ProjectName__c, EOI_Amount_AED__c, CurrencyIsoCode, Customer_Email__c,
                       Contact__r.Name, Contact__r.Email, Contact__r.MobilePhone, Contact__r.Phone,
                       Account__r.Name, Account__r.Phone,
                       Opportunity__r.BrokerAgency__c, Opportunity__r.BrokerAgent__c
                FROM Expressionofinterest__c
                WHERE Id = :eoiId AND Opportunity__r.BrokerAgency__c = :agencyId
                LIMIT 1
            ];
            return rows.isEmpty() ? null : rows[0];
        }
        Checkout_Payment__c openLinkFor(Id eoiId, Set<String> statuses) {
            List<Checkout_Payment__c> rows = [
                SELECT Id, Name, Status__c, Amount__c, Currency_Code__c, Expires_On__c, Customer_Email__c, Customer_Phone__c
                FROM Checkout_Payment__c
                WHERE Expression_of_Interest__c = :eoiId AND Status__c IN :statuses
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            return rows.isEmpty() ? null : rows[0];
        }
        // BP-032: newest link per EOI, restricted to the caller's agency (and agent) through the parent Opportunity
        List<Checkout_Payment__c> latestLinks(Set<Id> eoiIds, Id agencyId, Id agentContactId) {
            Map<Id, Checkout_Payment__c> newest = new Map<Id, Checkout_Payment__c>();
            List<Checkout_Payment__c> rows = agentContactId == null
                ? [SELECT Id, Name, Status__c, Dashboard_Status__c, Expires_On__c, Expression_of_Interest__c
                   FROM Checkout_Payment__c
                   WHERE Expression_of_Interest__c IN :eoiIds
                     AND Expression_of_Interest__r.Opportunity__r.BrokerAgency__c = :agencyId
                   ORDER BY CreatedDate DESC, Id DESC]
                : [SELECT Id, Name, Status__c, Dashboard_Status__c, Expires_On__c, Expression_of_Interest__c
                   FROM Checkout_Payment__c
                   WHERE Expression_of_Interest__c IN :eoiIds
                     AND Expression_of_Interest__r.Opportunity__r.BrokerAgency__c = :agencyId
                     AND Expression_of_Interest__r.Opportunity__r.BrokerAgent__c = :agentContactId
                   ORDER BY CreatedDate DESC, Id DESC];
            for (Checkout_Payment__c cp : rows) {
                if (!newest.containsKey(cp.Expression_of_Interest__c)) newest.put(cp.Expression_of_Interest__c, cp);
            }
            return newest.values();
        }
        Checkout_Payment__c latestLink(Id eoiId) {
            List<Checkout_Payment__c> rows = [
                SELECT Id, Name, Status__c
                FROM Checkout_Payment__c
                WHERE Expression_of_Interest__c = :eoiId
                ORDER BY CreatedDate DESC, Id DESC
                LIMIT 1
            ];
            return rows.isEmpty() ? null : rows[0];
        }
        // BP-032: EOI + its open link go to Voided together (system mode; the guards above decide who may call this)
        void voidEoi(Id eoiId, String reason, Checkout_Payment__c openLink) {
            update new Expressionofinterest__c(Id = eoiId, Status__c = 'Voided', SLA_Voided_Reason__c = reason);
            if (openLink != null) {
                update new Checkout_Payment__c(Id = openLink.Id, Status__c = 'Voided');
            }
        }
        /* BP-058: close a released hold in system mode. The status change fires
           CheckoutPaymentTrigger, which hands the row to CheckoutEoiMaterializer.closeLapsedEois and
           marks the EOI Cancelled. The direct call afterwards is the belt for the case where the
           status was already Voided - an internal caller's updateTrackingStatus got there first - so
           the trigger never fired. closeLapsedEois only touches an EOI still at Payment Authorized,
           so calling it twice does nothing the first call did not already do. */
        void markVoided(Id paymentId) {
            List<Checkout_Payment__c> rows = [
                SELECT Id, Status__c, Reference__c, Expression_of_Interest__c, Receipt__c
                FROM Checkout_Payment__c WHERE Id = :paymentId LIMIT 1
            ];
            if (rows.isEmpty()) return;
            Checkout_Payment__c cp = rows[0];
            if (cp.Status__c != 'Voided') {
                update new Checkout_Payment__c(
                    Id = cp.Id, Status__c = 'Voided', Last_Checkout_Status__c = 'Voided', Last_Polled__c = System.now()
                );
                cp.Status__c = 'Voided';
            }
            if (cp.Expression_of_Interest__c != null && cp.Receipt__c == null) {
                CheckoutEoiMaterializer.closeLapsedEois(new List<Checkout_Payment__c>{ cp });
            }
        }
        // BP-057: everything the row actions re-read before acting. byId is left alone - it feeds
        // toResult and must keep its own field set.
        Checkout_Payment__c actionRow(Id paymentId) {
            List<Checkout_Payment__c> rows = [
                SELECT Id, Name, Status__c, Amount__c, Currency_Code__c, Expires_On__c, Reference__c,
                       CreatedDate, Customer_Name__c, Customer_Email__c, Customer_Phone__c, Payment_Link_Url__c,
                       Payment_Id__c, Related_Record_Id__c, EOI_Creation_Payload__c,
                       Expression_of_Interest__c, Receipt__c, Recovery_Alert_Sent__c
                FROM Checkout_Payment__c WHERE Id = :paymentId LIMIT 1
            ];
            return rows.isEmpty() ? null : rows[0];
        }
        /* BP-060: requests on these opportunities that have already become an EOI. They are not
           listed - the EOI itself is - but they still retire any older request for the same interest,
           so an interest that has been paid can never offer a new link again. */
        List<Checkout_Payment__c> settledPayloadRows(Datetime cutoff, Set<String> relatedIds) {
            if (relatedIds == null || relatedIds.isEmpty()) return new List<Checkout_Payment__c>();
            return [
                SELECT Id, CreatedDate, Related_Record_Id__c, EOI_Creation_Payload__c
                FROM Checkout_Payment__c
                WHERE CreatedDate >= :cutoff
                  AND Expression_of_Interest__c != null
                  AND Related_Record_Id__c IN :relatedIds
                LIMIT 2000
            ];
        }
        /* BP-060: the same rule for ONE request, re-read before an action runs. Any newer request
           for the same opportunity and interest retires this one, whatever status either carries. */
        Boolean hasNewerRequest(String relatedId, String key, Datetime createdDate) {
            if (String.isBlank(relatedId) || String.isBlank(key) || createdDate == null) return false;
            for (Checkout_Payment__c cp : [
                SELECT Id, EOI_Creation_Payload__c
                FROM Checkout_Payment__c
                WHERE Related_Record_Id__c = :relatedId
                  AND CreatedDate > :createdDate
                LIMIT 200
            ]) {
                if (key == payloadKey(cp.EOI_Creation_Payload__c)) return true;
            }
            return false;
        }
        /* BP-060: close the request a new one has just replaced. Its link is already dead, so the
           row is stamped Expired here rather than waiting for CheckoutPaymentPoller's next pass -
           and the expiry message is suppressed, because the customer has just been sent a newer
           link and telling them to ask for one would be wrong. Only requests with no EOI are ever
           offered this action, so no expression of interest is touched. */
        void retire(Id paymentId) {
            List<Checkout_Payment__c> rows = [
                SELECT Id, Status__c FROM Checkout_Payment__c WHERE Id = :paymentId LIMIT 1
            ];
            if (rows.isEmpty() || rows[0].Status__c == 'Expired') return;
            CheckoutNotificationService.replacedRowIds.add(paymentId);
            try {
                update new Checkout_Payment__c(
                    Id = paymentId, Status__c = 'Expired', Last_Checkout_Status__c = 'Expired'
                );
            } finally {
                CheckoutNotificationService.replacedRowIds.remove(paymentId);
            }
        }
        Checkout_Payment__c byId(Id paymentId) {
            List<Checkout_Payment__c> rows = [
                SELECT Id, Name, Status__c, Amount__c, Currency_Code__c, Expires_On__c, Customer_Email__c, Customer_Phone__c
                FROM Checkout_Payment__c WHERE Id = :paymentId LIMIT 1
            ];
            return rows.isEmpty() ? null : rows[0];
        }
        // ── BP-041 reads (system mode, each bounded by agency / opportunity / window) ──
        Opportunity brokerOpportunity(Id opportunityId, Id agencyId) {
            List<Opportunity> rows = [
                SELECT Id, Name, ContactId, BrokerAgency__c, BrokerAgent__c
                FROM Opportunity
                WHERE Id = :opportunityId AND BrokerAgency__c = :agencyId
                LIMIT 1
            ];
            return rows.isEmpty() ? null : rows[0];
        }
        // Same predicate as MBP_ExpressionOfInterestsController.getEOIRange, resolved on the server
        /* BP-054: matched on the three fields the broker form actually has. Phase and typology narrow
           the match only when the caller supplied them, so a caller that still sends them resolves
           exactly the row it always did, and the broker form resolves whether or not the range carries
           them. Ordered by CreatedDate so the answer is the same every time. */
        EOI_Range__c brokerRange(Interest it) {
            Id projectId = asId(it.projectId);
            if (projectId == null || String.isBlank(it.unitType) || String.isBlank(it.bedrooms)) return null;
            List<EOI_Range__c> rows = [
                SELECT Id, Amount__c, Project__c, Project__r.Name, Phase__c, Unit_Type__c, No_of_Bedrooms__c, UnitTypologyMRE__c
                FROM EOI_Range__c
                WHERE Project__c = :projectId
                  AND Unit_Type__c = :it.unitType
                  AND Show_On__c INCLUDES (:SHOW_ON_BROKER)
                  AND No_of_Bedrooms__c = :it.bedrooms
                  AND Is_Active__c = true
                ORDER BY CreatedDate ASC
            ];
            Id phaseId = asId(it.phaseId);
            String typology = it.unitTypology;
            for (EOI_Range__c r : rows) {
                if (phaseId != null && r.Phase__c != phaseId) continue;
                if (String.isNotBlank(typology) && !typology.equals(r.UnitTypologyMRE__c)) continue;
                return r;
            }
            return null;
        }
        Contact customerContact(Id contactId) {
            if (contactId == null) return null;
            List<Contact> rows = [SELECT Id, Name, Email, MobilePhone, Phone FROM Contact WHERE Id = :contactId LIMIT 1];
            return rows.isEmpty() ? null : rows[0];
        }
        // Live requests for the same interest on one Opportunity, oldest first
        List<Checkout_Payment__c> liveInterestLinks(Id opportunityId, String key) {
            String related = String.valueOf(opportunityId);
            Datetime cutoff = System.now().addDays(-PENDING_WINDOW_DAYS);
            List<Checkout_Payment__c> out = new List<Checkout_Payment__c>();
            for (Checkout_Payment__c cp : [
                SELECT Id, Name, Status__c, Amount__c, Currency_Code__c, Expires_On__c, Customer_Email__c, Customer_Phone__c, EOI_Creation_Payload__c
                FROM Checkout_Payment__c
                WHERE Related_Record_Id__c = :related
                  AND Expression_of_Interest__c = null
                  AND Status__c IN :LIVE_LINK_STATUSES
                  AND CreatedDate >= :cutoff
                ORDER BY CreatedDate ASC, Id ASC
            ]) {
                if (!isLive(cp)) continue;
                if (key == payloadKey(cp.EOI_Creation_Payload__c)) out.add(cp);
            }
            return out;
        }
        // Payload rows with no EOI in the window, newest first; the Opportunity filter is applied by the caller
        List<Checkout_Payment__c> recentPayloadRows(Datetime cutoff) {
            String pattern = OPPORTUNITY_KEY_PREFIX + '%';
            List<Checkout_Payment__c> out = new List<Checkout_Payment__c>();
            for (Checkout_Payment__c cp : [
                SELECT Id, Name, Status__c, Dashboard_Status__c, Amount__c, Currency_Code__c, Expires_On__c, CreatedDate,
                       Customer_Name__c, Customer_Email__c, Customer_Phone__c, Related_Record_Id__c, EOI_Creation_Payload__c
                FROM Checkout_Payment__c
                WHERE CreatedDate >= :cutoff
                  AND Expression_of_Interest__c = null
                  AND Related_Record_Id__c LIKE :pattern
                ORDER BY CreatedDate DESC, Id DESC
                LIMIT 2000
            ]) {
                if (String.isNotBlank(cp.EOI_Creation_Payload__c)) out.add(cp);
            }
            return out;
        }
        Map<Id, Opportunity> agencyOpportunities(Set<Id> oppIds, Id agencyId, Id agentContactId) {
            if (oppIds.isEmpty()) return new Map<Id, Opportunity>();
            return agentContactId == null
                ? new Map<Id, Opportunity>([SELECT Id, Name FROM Opportunity WHERE Id IN :oppIds AND BrokerAgency__c = :agencyId])
                : new Map<Id, Opportunity>([SELECT Id, Name FROM Opportunity WHERE Id IN :oppIds AND BrokerAgency__c = :agencyId AND BrokerAgent__c = :agentContactId]);
        }
        // The payload stores bare ids; resolve names against whatever object they belong to (Project__c, Phase__c)
        Map<Id, String> namesById(Set<Id> ids) {
            Map<Id, String> out = new Map<Id, String>();
            if (ids.isEmpty()) return out;
            String sobjName = new List<Id>(ids)[0].getSobjectType().getDescribe().getName();
            for (SObject rec : Database.query('SELECT Id, Name FROM ' + String.escapeSingleQuotes(sobjName) + ' WHERE Id IN :ids')) {
                out.put((Id) rec.get('Id'), (String) rec.get('Name'));
            }
            return out;
        }
    }
}