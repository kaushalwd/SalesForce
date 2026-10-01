/**********************************************************************************************************************
* Name               : ADHA_MasterplanController
* Description        : Serves the ADHA Baniyas masterplan to the microsite LWC. Geometry and inventory both come from
*                      ADHA_Unit__c; cluster boundary polygons stay in the WestBaniyasMasterplanData static resource.
* Usage              : masterplanUnitSelector LWC, hosted on the MasterplanUnitSelector Visualforce page via Lightning Out.
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           Aurelix                     13 Aug 2026     Initial draft. Eligibility = category intersection plus
*                                                             service-type match, per the ADHA eligibility feed.
* 1.1           Aurelix                     13 Aug 2026     Added community and plot position to the DTO so the LWC can
*                                                             build the journey stage 4 search and filter options.
* 1.2           Aurelix                     13 Aug 2026     Added balcony count - a real filter for customers eligible
*                                                             across more than one category.
* 1.3           Aurelix                     13 Aug 2026     Identity now comes from a server-issued session token, not
*                                                             an application number supplied by the browser.
* 1.4           Aurelix                     14 Aug 2026     Fail closed: a blank token no longer means "preview
*                                                             everything"; preview is an explicit sentinel.
* 1.5           Aurelix                     31 Aug 2026     The guest sharing rule now shares the whole Baniyas
*                                                             inventory, so who may see reserve stock is decided here.
***********************************************************************************************************************/
public with sharing class ADHA_MasterplanController {

    /** Deferred Loan customers book from House Purchase Loan stock. Inferred from the undertakings,
     *  which pair HPL and HPDL in one document; pending confirmation from ADHA. */
    private static final Map<String, String> SERVICE_ALIAS = new Map<String, String>{
        'House Purchase Deferred Loan' => 'House Purchase Loan'
    };

    /* The eligibility rule, defined once: used by getMasterplan for what the map paints and by
     * ADHA_ReservationService before it grants a hold, so the two can never disagree. */

    public static Set<String> categoriesFor(ADHA_Applicant__c applicant) {
        Set<String> categories = new Set<String>();
        if (applicant != null && String.isNotBlank(applicant.Eligible_Categories__c)) {
            categories.addAll(applicant.Eligible_Categories__c.split(';'));
        }
        return categories;
    }

    public static String serviceFor(ADHA_Applicant__c applicant) {
        String value = applicant == null ? null : applicant.Service_Type__c;
        return SERVICE_ALIAS.containsKey(value) ? SERVICE_ALIAS.get(value) : value;
    }

    public static Boolean isEligible(Set<String> categories, String service, ADHA_Unit__c unit) {
        // isNotBlank first: null == null is true in Apex, so an applicant with no service type
        // would otherwise match every unit whose Eligible_Service__c is blank and be refused on click.
        return String.isNotBlank(service)
            && categories.contains(unit.Category_Type__c)
            && service == unit.Eligible_Service__c;
    }

    public class UnitDTO {
        @AuraEnabled public String plotUid;
        @AuraEnabled public Integer num;          // masterplan number - what is printed on the plan
        // ADHA's plot number from the units export. Unique only within a community, so the label
        // it drives can repeat across the four communities; Plot_UID__c is the record key.
        @AuraEnabled public Integer plotNo;
        @AuraEnabled public String polygon;       // normalised JSON, parsed client-side
        @AuraEnabled public Decimal cx;
        @AuraEnabled public Decimal cy;
        @AuraEnabled public String cluster;
        // Zone number, or "P2" for the phase 2 pockets that carry no zone. The map's block hue.
        @AuraEnabled public String zone;
        @AuraEnabled public String status;
        @AuraEnabled public String category;
        @AuraEnabled public String villaType;
        @AuraEnabled public String community;
        @AuraEnabled public String position;      // Masterplan_Features__c - corner / middle / facing community
        @AuraEnabled public String service;
        @AuraEnabled public Decimal price;
        @AuraEnabled public Integer bedrooms;
        @AuraEnabled public Integer balconies;
        @AuraEnabled public Decimal bua;
        @AuraEnabled public Decimal plotArea;
        @AuraEnabled public Boolean eligible;     // may this applicant book this unit at all
        @AuraEnabled public Boolean selectable;   // eligible AND currently free
        @AuraEnabled public Boolean provisional;  // masterplan mapping not yet confirmed by ADHA
        // True only in ops sessions, for the map's pin tint. Customers always get false.
        @AuraEnabled public Boolean pinned = false;
        // Ops only - this villa is assignable reserve stock. Customers always get false.
        @AuraEnabled public Boolean reserveStock = false;
    }

    public class ApplicantContext {
        @AuraEnabled public String applicationNumber;
        @AuraEnabled public String customerName;
        @AuraEnabled public String serviceType;
        @AuraEnabled public List<String> categories;
        @AuraEnabled public Decimal approvedLoanAmount;
        @AuraEnabled public String language;
        @AuraEnabled public Integer eligibleUnitCount;
        // This applicant's pinned villa, if any.
        @AuraEnabled public String pinnedPlotUid;
        // Ops session, so the client renders pin mode.
        @AuraEnabled public Boolean isOps = false;
    }

    public class MasterplanData {
        @AuraEnabled public List<UnitDTO> units;
        @AuraEnabled public ApplicantContext applicant;
        @AuraEnabled public Integer totalUnits;
        @AuraEnabled public Integer eligibleUnits;
    }

    /** The volatile slice of the map, small enough to fetch repeatedly. */
    public class Availability {
        /** Plot ids nobody can take right now, whether reserved, held by someone else or blocked. */
        @AuraEnabled public List<String> taken;
        @AuraEnabled public Datetime asOf;
        /** How long the client should wait before asking again. Zero means do not poll. */
        @AuraEnabled public Integer pollSeconds;
    }

    /** The client's way in. `build` is never read: it exists so a payload shape change gets a
     *  new Lightning Data Service cache key, which survives reloads and would otherwise serve
     *  a browser the fields it cached before the change. Bump it in the LWC when fields move. */
    @AuraEnabled(cacheable=true)
    public static MasterplanData getMasterplanFor(String sessionToken, String build) {
        return getMasterplan(sessionToken);
    }

    /** @param sessionToken Issued by ADHA_JourneyController.verifyCode; anything else is rejected.
     *  This method must never return inventory to a caller it cannot identify - no bypass exists. */
    @AuraEnabled(cacheable=true)
    public static MasterplanData getMasterplan(String sessionToken) {
        // The code, not the sentence: resolveApplicant throws the same code for the same condition,
        // and the client translates it. An English sentence here reaches an Arabic customer as-is.
        if (String.isBlank(sessionToken)) {
            throw new AuraHandledException('MSG_SESSION_EXPIRED');
        }
        ADHA_Applicant__c applicant = ADHA_JourneyController.resolveApplicant(sessionToken);

        Set<String> categories = categoriesFor(applicant);
        String service = serviceFor(applicant);
        // Ops sees everything, a pinned applicant sees only their villa.
        Boolean ops = ADHA_JourneyController.isOps(applicant);
        Boolean hasPin = false;
        if (applicant != null && !ops) {
            hasPin = [
                SELECT COUNT() FROM ADHA_Unit__c WHERE Pinned_Applicant__c = :applicant.Id LIMIT 1
            ] > 0;
        }
        String firstPinnedPlot = null;

        MasterplanData result = new MasterplanData();
        result.units = new List<UnitDTO>();
        result.eligibleUnits = 0;

        // One query for everyone. The guest sharing rule shares the whole Baniyas inventory, and
        // who may see reserve stock is decided in the loop below, not by the sharing rule.
        Set<Id> assignableIds = ops ? assignablePool() : new Set<Id>();
        List<ADHA_Unit__c> source = [
            SELECT Plot_UID__c, Masterplan_Number__c, Plot_Number__c, Map_Polygon__c, Centroid_X__c, Centroid_Y__c,
                   Cluster__c, Zone__c, Phase__c, Status__c, Category_Type__c, Villa_Type__c, Eligible_Service__c,
                   Community__c, Masterplan_Features__c,
                   Price__c, Rooms_Count__c, Balconies_Count__c, House_Size__c, Calculated_Area__c,
                   Is_Selectable__c, Mapping_Status__c, Pinned_Applicant__c,
                   Expose_To__c, Active_Reservation__c
            FROM ADHA_Unit__c
            ORDER BY Masterplan_Number__c
            LIMIT 5000
        ];

        for (ADHA_Unit__c u : source) {
            // A long text area cannot be filtered in SOQL, so unmapped units are skipped here.
            if (String.isBlank(u.Map_Polygon__c)) {
                continue;
            }

            Boolean pinnedToMe = applicant != null && u.Pinned_Applicant__c == applicant.Id;
            Boolean pinnedToOther = u.Pinned_Applicant__c != null && !pinnedToMe;
            // Reserve stock is shared with the guest so ops and pinned applicants can
            // read it. Customers must never see it, and this line is what stops them.
            if (!ops && u.Expose_To__c != 'Public' && !pinnedToMe) {
                continue;
            }
            if (pinnedToMe && firstPinnedPlot == null) {
                firstPinnedPlot = u.Plot_UID__c;
            }

            UnitDTO d = new UnitDTO();
            d.plotUid = u.Plot_UID__c;
            d.num = u.Masterplan_Number__c == null ? null : Integer.valueOf(u.Masterplan_Number__c);
            d.plotNo = u.Plot_Number__c == null ? null : Integer.valueOf(u.Plot_Number__c);
            d.polygon = u.Map_Polygon__c;
            d.cx = u.Centroid_X__c;
            d.cy = u.Centroid_Y__c;
            d.cluster = u.Cluster__c;
            // Zone is the only spatially contiguous grouping, so it drives the block colour.
            // Phase 2 carries no zone, so it becomes its own group rather than an unstyled hole.
            d.zone = String.isNotBlank(u.Zone__c) ? u.Zone__c : 'P' + u.Phase__c;
            d.status = u.Status__c;
            d.category = u.Category_Type__c;
            d.villaType = u.Villa_Type__c;
            d.community = u.Community__c;
            d.position = u.Masterplan_Features__c;
            d.service = u.Eligible_Service__c;
            d.price = u.Price__c;
            d.bedrooms = u.Rooms_Count__c == null ? null : Integer.valueOf(u.Rooms_Count__c);
            d.balconies = u.Balconies_Count__c == null ? null : Integer.valueOf(u.Balconies_Count__c);
            d.bua = u.House_Size__c;
            d.plotArea = u.Calculated_Area__c;
            d.provisional = u.Mapping_Status__c != 'Confirmed';

            if (ops) {
                // Ops allocates, so nothing is greyed by eligibility. What ops can
                // assign is the reserve pool, never public stock - customers book that themselves.
                d.eligible = true;
                d.selectable = assignableIds.contains(u.Id);
                d.reserveStock = assignableIds.contains(u.Id) || u.Expose_To__c == 'Reserved';
                // A bare flag for the ops map tint - never set for customers.
                d.pinned = u.Pinned_Applicant__c != null;
            } else if (pinnedToOther) {
                // Somebody else's pin reads as plain taken.
                d.eligible = applicant == null ? false : isEligible(categories, service, u);
                d.selectable = false;
                d.status = 'Reserved';
            } else if (hasPin) {
                // Their pin overrides category and service, never availability.
                d.eligible = pinnedToMe;
                d.selectable = pinnedToMe && u.Is_Selectable__c;
                // The pin is the exposure grant. Parked reserve stock reads Available
                // to the one applicant it is pinned to, and to nobody else ever.
                if (pinnedToMe && reserveAssignable(u)) {
                    d.status = 'Available';
                    d.selectable = true;
                }
            } else {
                // No applicant means preview mode: show everything as eligible.
                d.eligible = applicant == null || isEligible(categories, service, u);
                d.selectable = d.eligible && u.Is_Selectable__c;
            }

            if (d.eligible) {
                result.eligibleUnits++;
            }
            result.units.add(d);
        }

        result.totalUnits = result.units.size();
        if (applicant != null) {
            ApplicantContext ctx = new ApplicantContext();
            ctx.applicationNumber = applicant.Application_Number__c;
            ctx.customerName = applicant.Customer_Name__c;
            ctx.serviceType = applicant.Service_Type__c;
            ctx.categories = new List<String>(categories);
            ctx.approvedLoanAmount = applicant.Approved_Loan_Amount__c;
            ctx.language = applicant.Preferred_Language__c;
            ctx.eligibleUnitCount = result.eligibleUnits;
            ctx.pinnedPlotUid = firstPinnedPlot;
            ctx.isOps = ops;
            result.applicant = ctx;
        }
        return result;
    }

    /** The reserve pool ops may assign from, as ids. Ids rather than a re-read of
     *  Expose_To off each row, so the map and the availability poll cannot disagree. */
    private static Set<Id> assignablePool() {
        Set<Id> out = new Set<Id>();
        for (ADHA_Unit__c u : [
            SELECT Id FROM ADHA_Unit__c
            WHERE Expose_To__c = 'Reserved'
              AND Status__c IN ('Reserved', 'Available')
              AND Active_Reservation__c = null
            LIMIT 5000
        ]) {
            out.add(u.Id);
        }
        return out;
    }

    /** A reserve-pool villa ops may assign, or a pinned applicant may book - parked
     *  (Reserved) or released back (Available), with no live reservation on it. Public and
     *  MV-Reserved villas are never assignable; the validation rule enforces the same shape. */
    public static Boolean reserveAssignable(ADHA_Unit__c u) {
        return u.Expose_To__c == 'Reserved'
            && (u.Status__c == 'Reserved' || u.Status__c == 'Available')
            && u.Active_Reservation__c == null;
    }

    /** Live availability split out of cacheable getMasterplan so the heavy polygon payload stays
     *  cached. Full list, not a delta: a missed delta leaves the client quietly wrong; this self-heals. */
    @AuraEnabled(cacheable=false)
    public static Availability getAvailability(String sessionToken) {
        // Same gate as getMasterplan. This must never hand inventory to a caller it cannot identify.
        if (String.isBlank(sessionToken)) {
            throw new AuraHandledException('MSG_SESSION_EXPIRED');
        }
        ADHA_Applicant__c applicant = ADHA_JourneyController.resolveApplicant(sessionToken);

        Availability result = new Availability();
        result.taken = new List<String>();
        result.asOf = System.now();
        result.pollSeconds = pollSeconds();

        // Per-applicant now. A villa pinned to somebody else reads taken;
        // ops keeps the raw view.
        Boolean ops = ADHA_JourneyController.isOps(applicant);
        Set<Id> assignableIds = ops ? assignablePool() : new Set<Id>();
        for (ADHA_Unit__c u : [
            SELECT Id, Plot_UID__c, Is_Selectable__c, Pinned_Applicant__c,
                   Expose_To__c, Status__c, Active_Reservation__c
            FROM ADHA_Unit__c
            WHERE Is_Selectable__c = false
               OR (Pinned_Applicant__c != null AND Pinned_Applicant__c != :applicant.Id)
            LIMIT 5000
        ]) {
            if (String.isBlank(u.Plot_UID__c)) {
                continue;
            }
            if (ops && (u.Is_Selectable__c || assignableIds.contains(u.Id))) {
                // Pinned but actually free, or assignable reserve stock: not taken for ops.
                continue;
            }
            // The same visibility rule as the map. A customer never sees reserve stock,
            // so it never reads taken to them; their own pinned villa is theirs to book.
            if (!ops && u.Expose_To__c != 'Public') {
                continue;
            }
            result.taken.add(u.Plot_UID__c);
        }
        return result;
    }

    /** Carried in the response rather than pushed down as another attribute, so changing the
     *  setting takes effect on the next poll instead of on the next page load. */
    private static Integer pollSeconds() {
        Decimal configured = ADHA_JourneyController.settings().Availability_Poll_Seconds__c;
        if (configured == null) {
            return 60;
        }
        Integer seconds = Integer.valueOf(configured);
        // Below ten this stops being a refresh and starts being a load test.
        return seconds <= 0 ? 0 : Math.max(seconds, 10);
    }
}