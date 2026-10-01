/**********************************************************************************************************************
* Name               : OIC_DPGUnitsAPI
* Description        : Single-class DPG units integration. Fetches units (broker-aware), their options, and the
*                      applicable payment plan, and returns them with pricing in the unit's own currency.
* Usage              : POST /services/apexrest/dpg/getunits/
*                      Body: { "ProjectId": "...", "CustomerName": "...", "ProfileName": "...",
*                              "Limit": 50, "Offset": 0 }
* Created By         : Activemindsit
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           Suresh                      08 04 2025      Initial Draft
* 1.1           Suresh                      20 10 2025      Payment Plan Id Updated
* 1.2           Suresh                      20 01 2026      FacadeStyle__c, FacadeType__c added
* 1.3           Suresh                      12 05 2026      Total price updated
* 1.4           upendra                     02 07 2026      Broker-aware unit access (bucket group + agency allocation)
* 2.0           Arvind                      10 Jul 2026     Merged OIC_DPGUnitsAPIHelper into this class (delete that
*                                                             class after deploy). Response handling delegated to
*                                                             OIC_RestResponse; UNT-xxx codes registered dynamically.
*                                                             SOQL injection closed on ProjectId / CustomerName.
*                                                             Query failures now surface as errors instead of being
*                                                             swallowed into an empty, "successful" list.
*                                                             CurrencyIsoCode returned on every price-bearing record.
* 2.1           upendra                      10 Jul 2026     CurrencyIsoCode now sourced from the parent Project
*                                                             (Phase__r.Project__r.CurrencyIsoCode) for both the Unit
*                                                             and its Options, so they can never disagree.
* 3.0           -                           13 Jul 2026     Converted GET -> POST. Parameters now read from the JSON
*                                                             request body. Added server-side pagination: Limit +
*                                                             Offset with a TotalCount and HasMore so DPG can page
*                                                             deterministically. Stable ORDER BY (Name, Id) added for
*                                                             correct paging. getUnits(String,String,String) replaced
*                                                             by getUnitsPage(...) which returns units + total count.
* 3.1           -                           15 Jul 2026     Added a Customer-profile flow. Non-broker callers now split
*                                                             on ProfileName: a profile containing "Customer" reads the
*                                                             public Online-Sales bucket inventory using the same
*                                                             availability rules as the broker flow (Available,
*                                                             BlockedFor null, non-Modon Egypt, unallocated agency),
*                                                             with NO bucket-membership requirement on the customer. A
*                                                             profile containing "Sales Manager" (and any other profile)
*                                                             keeps the existing customer-name based access.
* 3.2           -                           23 Jul 2026     MerchantId now resolved per-Unit via
*                                                             Unit -> VirtualAccount__c (child, Unit__c lookup) ->
*                                                             EscrowAccount__c (parent, EscrowAccount__c lookup) ->
*                                                             MerchantID__c. Falls back to the TEST993292000 constant
*                                                             when a Unit has no Virtual Account, no Escrow Account,
*                                                             or a blank MerchantID__c. UnitOption.MerchantId now
*                                                             mirrors its parent Unit's resolved MerchantId (options
*                                                             have no Virtual Account of their own). ASSUMPTION: field
*                                                             API names VirtualAccount__c.Unit__c,
*                                                             VirtualAccount__c.EscrowAccount__c, and
*                                                             EscrowAccount__c.MerchantID__c -- verify against org and
*                                                             adjust getVirtualAccounts() if different.
* 3.3           pprajapati@horizontal.com   25 Aug 2026     Adopted OIC_RequestContext for Section 0 identity resolution and validation.
* 3.4           Jay Patel                   21 Sep 2026     MCR-73 — USER_MODE SOQL, createApexLog
***********************************************************************************************************************/
@RestResource(urlMapping='/dpg/getunits/*')
global with sharing class OIC_DPGUnitsAPI {

    private static final String MERCHANT_ID       = 'TEST993292000';
    private static final String DEFAULT_CURRENCY  = 'AED';
    private static final String EXCLUDED_PROJECT  = '%Ras El Hekma%';

    // ---- Pagination bounds -------------------------------------------------------------
    // OFFSET in SOQL is hard-capped at 2000 by the platform; we validate against it up-front
    // and return a clear message rather than letting the query throw.
    private static final Integer DEFAULT_PAGE_SIZE = 50;
    private static final Integer MAX_PAGE_SIZE     = 200;
    private static final Integer MAX_OFFSET        = 2000;

    /* ====================================================================================
     *  ERROR CODES
     * ==================================================================================== */
    static {
        OIC_RestResponse.define('UNT-001', 400, 'A supplied parameter is not valid.');
        OIC_RestResponse.define('UNT-002', 500, 'Failed to query units.');
        OIC_RestResponse.define('UNT-999', 500, 'An unexpected error occurred.');
    }

    private static final String ERR_BAD_PARAM  = 'UNT-001';
    private static final String ERR_QUERY      = 'UNT-002';
    private static final String ERR_UNEXPECTED = 'UNT-999';

    /* ====================================================================================
     *  REST ENTRY POINT
     * ==================================================================================== */
    @HttpPost
    global static void getUnitsDPG() {
        try {
            OIC_RequestContext ctx = OIC_RequestContext.current().resolveIdentity();
            if (!ctx.isValid()) {
                ctx.toRestResponse().send();
                return;
            }

            String customerName = ctx.getString('CustomerName');
            String profileName  = ctx.getString('ProfileName');
            String projectId    = ctx.getString('ProjectId');

            if (String.isBlank(profileName) && String.isNotBlank(ctx.getCustomerType())) {
                profileName = ctx.getCustomerType();
            }

            System.debug('getUnitsDPG >>>> CustomerName >> ' + customerName);
            System.debug('getUnitsDPG >>>> ProfileName  >> ' + profileName);
            System.debug('getUnitsDPG >>>> ProjectId    >> ' + projectId);

            // ---- ProjectId: fail fast on a malformed Id -----------------------------------
            if (String.isNotBlank(projectId) && !(projectId instanceof Id)) {
                try {
                    Id.valueOf(projectId.trim());
                } catch (System.StringException se) {
                    OIC_RestResponse.failure(ERR_BAD_PARAM,
                        'Invalid ProjectId: "' + projectId + '" is not a valid Salesforce Id.').send();
                    return;
                }
            }

            // ---- Pagination: read, default, and validate ----------------------------------
            Integer pageLimit  = ctx.getInteger('Limit', DEFAULT_PAGE_SIZE);
            Integer pageOffset = ctx.getInteger('Offset', 0);

            if (pageLimit == null)  pageLimit  = DEFAULT_PAGE_SIZE;
            if (pageOffset == null) pageOffset = 0;

            if (pageLimit < 1 || pageLimit > MAX_PAGE_SIZE) {
                OIC_RestResponse.failure(ERR_BAD_PARAM,
                    'Limit must be between 1 and ' + MAX_PAGE_SIZE + '.').send();
                return;
            }
            if (pageOffset < 0 || pageOffset > MAX_OFFSET) {
                OIC_RestResponse.failure(ERR_BAD_PARAM,
                    'Offset must be between 0 and ' + MAX_OFFSET + '.').send();
                return;
            }

            // ---- Query one page + total count ---------------------------------------------
            UnitPage page = getUnitsPage(customerName, profileName, projectId, pageLimit, pageOffset);
            Integer returnedCount = page.units.size();

            OIC_RestResponse.success()
                .put('UnitDetails', buildUnitPayload(page.units))
                .put('Pagination', buildPaginationMeta(pageLimit, pageOffset, returnedCount, page.totalCount))
                .flat()
                .send();

        } catch (QueryException qEx) {
            OIC_RestResponse.fromException(qEx, ERR_QUERY).send();

        } catch (Exception ex) {
            //3.4 MCR-73: Log unexpected failures via LoggerService.createApexLog
            LoggerService.save(LoggerService.createApexLog(
                ex,
                'DPG Units API',
                'OIC_DPGUnitsAPI',
                'getUnitsDPG'
            ));
            OIC_RestResponse.fromException(ex, ERR_UNEXPECTED).send();
        }
    }

    /** Pagination block returned to the caller so it can request the next page. */
    private static Map<String, Object> buildPaginationMeta(Integer pageLimit, Integer pageOffset,
                                                           Integer returnedCount, Integer totalCount) {
        Boolean hasMore = (pageOffset + returnedCount) < totalCount;
        Map<String, Object> meta = new Map<String, Object>{
            'Limit'         => pageLimit,
            'Offset'        => pageOffset,
            'ReturnedCount' => returnedCount,
            'TotalCount'    => totalCount,
            'HasMore'       => hasMore,
            'NextOffset'    => hasMore ? (pageOffset + returnedCount) : null
        };
        return meta;
    }

    /* ====================================================================================
     *  PAYLOAD ASSEMBLY
     * ==================================================================================== */
    private static List<Unit> buildUnitPayload(List<Unit__c> lst_Unit) {
        List<Unit> unitDetails = new List<Unit>();
        if (lst_Unit.isEmpty()) return unitDetails;

        Set<Id> set_UnitId = new Set<Id>();
        for (Unit__c u : lst_Unit) set_UnitId.add(u.Id);

        // ---- Payment plan resolution: phase first, then project ------------------------
        Map<Id, Id> map_PhasePaymentPlan   = new Map<Id, Id>();
        Map<Id, Id> map_ProjectPaymentPlan = new Map<Id, Id>();

        for (PaymentPlan__c pp : getAllPaymentPlans()) {
            if (pp.Phase__c != null) {
                if (!map_PhasePaymentPlan.containsKey(pp.Phase__c)) {
                    map_PhasePaymentPlan.put(pp.Phase__c, pp.Id);
                }
            } else if (pp.Project__c != null) {
                if (!map_ProjectPaymentPlan.containsKey(pp.Project__c)) {
                    map_ProjectPaymentPlan.put(pp.Project__c, pp.Id);
                }
            }
        }

        // ---- v1.3: an open Sales Order's TotalAmount__c overrides the Unit's list price --
        Map<Id, Decimal> map_UnitPrice = new Map<Id, Decimal>();

        for (SalesOrder__c so : getOverridingSalesOrders(set_UnitId)) {
            if (!map_UnitPrice.containsKey(so.Unit__c)) {
                map_UnitPrice.put(so.Unit__c, so.TotalAmount__c);
            }
        }

        // ---- v2.1: currency comes from the parent Project, for the Unit AND its Options --
        Map<Id, String> map_UnitCurrency = new Map<Id, String>();
        for (Unit__c u : lst_Unit) {
            map_UnitCurrency.put(u.Id, resolveProjectCurrency(u));
        }

        // ---- v3.2: MerchantId comes from Unit -> VirtualAccount__c -> EscrowAccount__c ----
        Map<Id, String> map_UnitMerchantId = new Map<Id, String>();
        for (VirtualAccount__c va : getVirtualAccounts(set_UnitId)) {
            if (map_UnitMerchantId.containsKey(va.Unit__c)) continue; // first non-blank wins
            String merchantId = (va.EscrowAccount__r != null) ? va.EscrowAccount__r.MerchantID__c : null;
            if (String.isNotBlank(merchantId)) {
                map_UnitMerchantId.put(va.Unit__c, merchantId);
            }
        }

        // ---- Unit options ---------------------------------------------------------------
        Map<Id, List<Unit_Option__c>> map_UnitOptions = new Map<Id, List<Unit_Option__c>>();
        for (Unit_Option__c uo : getUnitOptions(set_UnitId)) {
            if (!map_UnitOptions.containsKey(uo.Unit__c)) {
                map_UnitOptions.put(uo.Unit__c, new List<Unit_Option__c>());
            }
            map_UnitOptions.get(uo.Unit__c).add(uo);
        }

        for (Unit__c obj_Unit : lst_Unit) {
            Unit unit = new Unit();
            unit.Id                        = obj_Unit.Id;
            unit.Name                      = obj_Unit.Name;
            unit.ProjectName               = safeProjectName(obj_Unit);
            unit.ProjectId                 = safeProjectId(obj_Unit);
            unit.Status                    = obj_Unit.Status__c;
            unit.BlockedBy                 = (obj_Unit.BlockedBy__r  != null) ? obj_Unit.BlockedBy__r.Name  : null;
            unit.BlockedFor                = (obj_Unit.BlockedFor__r != null) ? obj_Unit.BlockedFor__r.Email : null;
            unit.BlockReason               = obj_Unit.BlockReason__c;
            unit.BlockUntil                = obj_Unit.BlockUntil__c;
            unit.Phase                     = (obj_Unit.Phase__r != null) ? obj_Unit.Phase__r.Name : null;
            unit.InventoryStatus           = obj_Unit.InventoryStatus__c;
            unit.Number_of_Bedrooms        = obj_Unit.Number_of_Bedrooms__c;
            unit.FloorNumber               = obj_Unit.FloorNumber__c;
            unit.TotalArea                 = obj_Unit.TotalArea__c;
            unit.TotalGFAsqm               = obj_Unit.TotalGFAsqm__c;
            unit.TotalGrossSellableAreaGSA = obj_Unit.TotalGrossSellableAreaGSA__c;
            unit.PlotAreasqm               = obj_Unit.PlotAreasqm__c;
            unit.PlotNo                    = obj_Unit.PlotNo__c;
            unit.MDPlotId                  = obj_Unit.MDPlotId__c;

            // v3.2: resolved via Unit -> VirtualAccount__c -> EscrowAccount__c.MerchantID__c,
            // falling back to the static constant when that chain has no value.
            unit.MerchantId                = map_UnitMerchantId.containsKey(obj_Unit.Id)
                                                ? map_UnitMerchantId.get(obj_Unit.Id)
                                                : MERCHANT_ID;
            unit.Typology                  = obj_Unit.Typology__c;
            unit.FacadeStyle               = obj_Unit.FacadeStyle__c;
            unit.FacadeType                = obj_Unit.FacadeType__c;

            // v1.3: an open Sales Order's amount wins over the Unit's own list price.
            // v2.1: the currency is the PROJECT's, regardless of which record the amount
            // came from -- the Project owns the currency for everything beneath it.
            unit.TotalPrice = map_UnitPrice.containsKey(obj_Unit.Id)
                ? map_UnitPrice.get(obj_Unit.Id)
                : ((obj_Unit.TotalPrice__c != null) ? obj_Unit.TotalPrice__c : 0.00);

            unit.CurrencyIsoCode = map_UnitCurrency.get(obj_Unit.Id);

            // ---- Payment plan: phase-level, else project-level ---------------------------
            if (obj_Unit.Phase__c != null) {
                if (map_PhasePaymentPlan.containsKey(obj_Unit.Phase__c)) {
                    unit.PaymentPlanId = map_PhasePaymentPlan.get(obj_Unit.Phase__c);
                } else if (obj_Unit.Phase__r != null
                           && map_ProjectPaymentPlan.containsKey(obj_Unit.Phase__r.Project__c)) {
                    unit.PaymentPlanId = map_ProjectPaymentPlan.get(obj_Unit.Phase__r.Project__c);
                }
            }

            unit.ShowUnitPrice = (obj_Unit.Bucket__c != null
                                  && obj_Unit.Bucket__r != null
                                  && obj_Unit.Bucket__r.Name == System.Label.OnlineSalesBucket);

            // ---- Unit options ------------------------------------------------------------
            List<UnitOption> unitOptions = new List<UnitOption>();
            if (map_UnitOptions.containsKey(obj_Unit.Id)) {
                for (Unit_Option__c obj_UnitOption : map_UnitOptions.get(obj_Unit.Id)) {
                    UnitOption obj_UO = new UnitOption();
                    obj_UO.Id                        = obj_UnitOption.Id;
                    obj_UO.Name                      = obj_UnitOption.Name;
                    obj_UO.Unit                      = obj_UnitOption.Unit__c;
                    obj_UO.AED_SQM                   = obj_UnitOption.AED_SQM__c;
                    obj_UO.BasePrice                 = (obj_UnitOption.BasePrice__c  != null) ? obj_UnitOption.BasePrice__c  : 0.00;
                    obj_UO.TotalPrice                = (obj_UnitOption.TotalPrice__c != null) ? obj_UnitOption.TotalPrice__c : 0.00;
                    // Inherited from the Unit's Project, not from Unit_Option__c itself.
                    obj_UO.CurrencyIsoCode           = map_UnitCurrency.get(obj_Unit.Id);
                    obj_UO.BasementArea              = obj_UnitOption.BasementArea__c;
                    obj_UO.BasementParkingArea       = obj_UnitOption.BasementParkingArea__c;
                    obj_UO.Category                  = obj_UnitOption.Category__c;
                    obj_UO.FacadeType                = obj_UnitOption.FacadeType__c;
                    obj_UO.FirstFloorArea            = obj_UnitOption.FirstFloorArea__c;
                    obj_UO.GroundFloorArea           = obj_UnitOption.GroundFloorArea__c;
                    obj_UO.Interior                  = obj_UnitOption.Interior__c;
                    obj_UO.Internal_Area             = obj_UnitOption.Internal_Area__c;
                    obj_UO.NumberofBedrooms          = obj_UnitOption.NumberofBedrooms__c;
                    obj_UO.NumberofCarParks          = obj_UnitOption.NumberofCarParks__c;
                    obj_UO.Phase                     = obj_UnitOption.Phase__c;
                    obj_UO.PlotAreasqm               = obj_UnitOption.PlotAreasqm__c;
                    obj_UO.PlotNo                    = obj_UnitOption.PlotNo__c;
                    obj_UO.SecondFloorArea           = obj_UnitOption.SecondFloorArea__c;
                    obj_UO.SubCategory               = obj_UnitOption.SubCategory__c;
                    obj_UO.TerraceArea               = obj_UnitOption.TerraceArea__c;
                    obj_UO.TotalGFAsqm               = obj_UnitOption.TotalGFAsqm__c;
                    obj_UO.TotalGrossSellableAreaGSA = obj_UnitOption.TotalGrossSellableAreaGSA__c;
                    obj_UO.Type                      = obj_UnitOption.Type__c;
                    obj_UO.Typology                  = obj_UnitOption.Typology__c;
                    // v3.2: options have no Virtual Account of their own -- inherit the
                    // parent Unit's resolved MerchantId (which already falls back to the
                    // constant when the Unit has no Virtual/Escrow Account).
                    obj_UO.MerchantId                = unit.MerchantId;
                    unitOptions.add(obj_UO);
                }
            }
            unit.UnitOptions = unitOptions;
            unitDetails.add(unit);
        }

        return unitDetails;
    }

    private static String safeProjectName(Unit__c u) {
        return (u.Phase__r != null && u.Phase__r.Project__r != null) ? u.Phase__r.Project__r.Name : null;
    }

    private static String safeProjectId(Unit__c u) {
        return (u.Phase__r != null && u.Phase__r.Project__r != null) ? u.Phase__r.Project__r.Id : null;
    }

    /**
     * Walks Unit -> Phase -> Project for the currency. Any lookup in the chain may be null,
     * and a null parent makes the whole chain null -- dereferencing it directly would throw.
     * Falls back to AED when the chain is broken or the Project has no code set.
     */
    private static String resolveProjectCurrency(Unit__c u) {
        if (u.Phase__c == null || u.Phase__r == null)                          return DEFAULT_CURRENCY;
        if (u.Phase__r.Project__c == null || u.Phase__r.Project__r == null)    return DEFAULT_CURRENCY;

        String isoCode = u.Phase__r.Project__r.CurrencyIsoCode;
        return String.isNotBlank(isoCode) ? isoCode : DEFAULT_CURRENCY;
    }

    /* ====================================================================================
     *  QUERIES  (merged in from OIC_DPGUnitsAPIHelper)
     *  Exceptions are NOT swallowed. v1.4 caught everything and returned an empty list,
     *  so a broken query produced Status:"Success" with zero units and no explanation.
     *
     *  v3.0: getUnitsPage runs TWO queries against the same WHERE clause and binds --
     *  a COUNT() for TotalCount and a windowed SELECT for the page. Both use method-scoped
     *  bind variables (Database.query / Database.countQuery), so the admin-controlled
     *  SOQLQuery__c clause keeps resolving exactly as it did before.
     *
     *  v3.1: non-broker access now splits on ProfileName. A "Customer" profile reads the
     *  Online-Sales bucket inventory with the same availability rules as the broker flow;
     *  a "Sales Manager" (or any other) profile keeps the customer-name based access.
     * ==================================================================================== */
    public static UnitPage getUnitsPage(String customerName, String profileName, String projectId,
                                        Integer pageLimit, Integer pageOffset) {

        Contact brokerContact = MBP_DPGCreateLeadAPI.getBrokerContactContext();
        Boolean isBroker = (brokerContact != null);
        System.debug('getUnitsPage >>>> isBroker >> ' + isBroker);

        //3.4 MCR-73: Enforce CRUD/FLS via USER_MODE on UnitAccessConfig__mdt query
        List<UnitAccessConfig__mdt> lst_UAMDT = [
            SELECT ProfileName__c, SOQLQuery__c
            FROM UnitAccessConfig__mdt
            WHERE ProfileName__c = :profileName
            WITH USER_MODE
            LIMIT 1
        ];
        String mdtClause = lst_UAMDT.isEmpty() ? null : lst_UAMDT[0].SOQLQuery__c;

        // Method-scoped Apex bind variables for safe Database.query() / Database.countQuery() execution
        Set<Id> userBucketIds        = new Set<Id>();
        Set<Id> onlineSalesBucketIds = new Set<Id>();   // v3.1: Customer-profile flow
        Id projectIdBind     = String.isNotBlank(projectId) ? (Id) projectId.trim() : null;
        Id brokerAgencyBind  = isBroker ? brokerContact.AccountId : null;
        String excludedProj  = EXCLUDED_PROJECT;

        // Everything from FROM onward is shared between the count and the page query.
        String fromWhere =
            'FROM Unit__c ' +
            'WHERE (NOT Phase__r.Project__r.Name LIKE :excludedProj)';

        // Bound with Apex bind variables to prevent SOQL injection
        if (projectIdBind != null) {
            fromWhere += ' AND Phase__r.Project__r.Id = :projectIdBind';
        }

        if (isBroker) {
            // ---- Broker flow: bucket-group + agency based access rules ----
            Set<String> userGroupIds = new Set<String>();
            //3.4 MCR-73: Enforce CRUD/FLS via USER_MODE on GroupMember query
            for (GroupMember gm : [
                SELECT GroupId FROM GroupMember WHERE UserOrGroupId = :UserInfo.getUserId() WITH USER_MODE
            ]) {
                userGroupIds.add((String) gm.GroupId);
                userGroupIds.add(((String) gm.GroupId).substring(0, 15));
            }
            //3.4 MCR-73: Enforce CRUD/FLS via USER_MODE on Bucket__c query
            for (Bucket__c b : [
                SELECT Id FROM Bucket__c WHERE Bucket_Group_Id__c IN :userGroupIds WITH USER_MODE
            ]) {
                userBucketIds.add(b.Id);
            }
            System.debug('getUnitsPage >>>> userBucketIds >> ' + userBucketIds);

            fromWhere += ' AND Bucket__c IN :userBucketIds';
            fromWhere += ' AND Status__c = \'Available\' AND BlockedFor__c = null';
            fromWhere += ' AND Source_Entity__c != \'Modon - Egypt\'';

            fromWhere += (brokerAgencyBind != null)
                ? ' AND (Allocate_to_Agency__c = null OR Allocate_to_Agency__c = :brokerAgencyBind)'
                : ' AND Allocate_to_Agency__c = null';

        } else {
            // ---- Non-broker: split by the caller's profile (v3.1) ----
            // "Customer"      -> public Online-Sales inventory, broker-style availability.
            // "Sales Manager" -> (and any other profile) existing customer-name access.
            Boolean isCustomerProfile = String.isNotBlank(profileName)
                                        && profileName.containsIgnoreCase('Customer');

            if (isCustomerProfile) {
                // ---- Customer flow: Online-Sales buckets, broker-style availability rules ----
                // Buckets whose Name matches the Online Sales label. The customer does NOT
                // need to be a member of these buckets -- membership is not checked here.
                //3.4 MCR-73: Enforce CRUD/FLS via USER_MODE on Bucket__c query
                for (Bucket__c b : [
                    SELECT Id FROM Bucket__c WHERE Name = :System.Label.OnlineSalesBucket WITH USER_MODE
                ]) {
                    onlineSalesBucketIds.add(b.Id);
                }
                System.debug('getUnitsPage >>>> onlineSalesBucketIds >> ' + onlineSalesBucketIds);

                // Same conditions the broker flow applies, minus the group-derived buckets
                // and the broker-agency match (a customer has no agency, so unallocated only).
                fromWhere += ' AND Bucket__c IN :onlineSalesBucketIds';
                fromWhere += ' AND Status__c = \'Available\' AND BlockedFor__c = null';
                fromWhere += ' AND Source_Entity__c != \'Modon - Egypt\'';


            } else {
                // ---- Sales Manager / default flow: existing customer-name based access ----
                if (String.isNotBlank(customerName)) {
                    fromWhere += ' AND (BlockedFor__c = null OR BlockedFor__r.Username = :customerName )';
                }
                // NOTE: SOQLQuery__c is admin-controlled metadata, appended verbatim. Anyone with
                // rights to edit UnitAccessConfig__mdt can alter this query. It cannot be bound.
                if (String.isNotBlank(mdtClause)) {
                    fromWhere += mdtClause;
                }
            }
        }

        // ---- 1) Total matching rows (no ORDER BY / LIMIT / OFFSET) ---------------------
        String countQuery = 'SELECT COUNT() ' + fromWhere;
        System.debug('getUnitsPage >>>> countQuery >> ' + countQuery);

        Map<String, Object> binds = new Map<String, Object>{
            'excludedProj' => excludedProj
        };
        if (projectIdBind != null) binds.put('projectIdBind', projectIdBind);
        if (isBroker) {
            binds.put('userBucketIds', userBucketIds);
            if (brokerAgencyBind != null) binds.put('brokerAgencyBind', brokerAgencyBind);
        } else {
            Boolean isCustomerProfile = String.isNotBlank(profileName)
                                        && profileName.containsIgnoreCase('Customer');
            if (isCustomerProfile) {
                binds.put('onlineSalesBucketIds', onlineSalesBucketIds);
            } else {
                if (String.isNotBlank(customerName)) binds.put('customerName', customerName);
            }
        }

        //3.4 MCR-73: Enforce CRUD/FLS via USER_MODE on dynamic count query
        Integer totalCount = Database.countQueryWithBinds(countQuery, binds, AccessLevel.USER_MODE);

        // ---- 2) One page. Stable ORDER BY (Name, Id) so paging can't drift ------------
        Integer boundLimit  = pageLimit;   // referenced as :boundLimit in the query
        Integer boundOffset = pageOffset;  // referenced as :boundOffset in the query

        String dataQuery =
            'SELECT Id, Name, Status__c, BlockedBy__r.Name, BlockedFor__r.Name, BlockedFor__r.Email, ' +
            '       BlockReason__c, BlockUntil__c, Phase__r.Name, InventoryStatus__c, Number_of_Bedrooms__c, ' +
            '       FloorNumber__c, TotalArea__c, FacadeStyle__c, FacadeType__c, TotalGFAsqm__c, ' +
            '       TotalGrossSellableAreaGSA__c, TotalPrice__c, PlotAreasqm__c, PlotNo__c, ' +
            '       MDPlotId__c, Phase__c, Phase__r.Project__c, Phase__r.Project__r.Id, Phase__r.Project__r.Name, ' +
            '       Phase__r.Project__r.CurrencyIsoCode, ' +
            '       Bucket__c, Bucket__r.Name, ApprovalStatus__c, Typology__c, Source_Entity__c, Allocate_to_Agency__c ' +
            fromWhere +
            ' ORDER BY Name ASC, Id ASC' +
            ' LIMIT :boundLimit OFFSET :boundOffset';

        System.debug('getUnitsPage >>>> dataQuery >> ' + dataQuery);
        binds.put('boundLimit', boundLimit);
        binds.put('boundOffset', boundOffset);
        //3.4 MCR-73: Enforce CRUD/FLS via USER_MODE on dynamic Unit__c query
        List<Unit__c> units = Database.queryWithBinds(dataQuery, binds, AccessLevel.USER_MODE);

        return new UnitPage(units, totalCount);
    }

    /** Open Sales Orders whose TotalAmount__c overrides the Unit's list price. */
    private static List<SalesOrder__c> getOverridingSalesOrders(Set<Id> set_UnitId) {
        List<String> statusFilter  = getfilters(System.Label.CP_SO_Statusfilters);
        List<String> projectFilter = new List<String>();

        for (String c2 : System.Label.MIRE_Exclude_List.split(',')) {
            projectFilter.add(
                (c2 != null && c2.contains('^')) ? c2.replace('^', ',').trim() : c2.trim()
            );
        }

        //3.4 MCR-73: Enforce CRUD/FLS via USER_MODE on SalesOrder__c query
        return [
            SELECT Id, Name, TotalAmount__c, Unit__c
            FROM SalesOrder__c
            WHERE Status__c NOT IN :statusFilter
              AND Unit__r.Project_Name__c NOT IN :projectFilter
              AND Unit__c IN :set_UnitId
            WITH USER_MODE
        ];
    }

    public static List<Unit_Option__c> getUnitOptions(Set<Id> set_UnitId) {
        if (set_UnitId == null || set_UnitId.isEmpty()) return new List<Unit_Option__c>();

        //3.4 MCR-73: Enforce CRUD/FLS via USER_MODE on Unit_Option__c query
        return [
            SELECT Id, Name, AdditionalPrice__c, AED_SQM__c, AreaUnitofMeasure__c, BalconyArea__c,
                   BasementArea__c, BasementParkingArea__c, BasePrice__c, Category__c, Description__c,
                   Exterior__c, FacadeType__c, FirstFloorArea__c, FloorAreaRatioFAR__c, GrossFloorAreaGFA__c,
                   GroundFloorArea__c, Interior__c, Internal_Area__c, NumberofBedrooms__c, NumberofCarParks__c,
                   Phase__c, PlotAreasqm__c, PlotNo__c, SecondFloorArea__c, SubCategory__c, TerraceArea__c,
                   TotalGFAsqm__c, TotalGrossSellableAreaGSA__c, TotalPrice__c,
                   Type__c, Typology__c, Unit__c, Model__c
            FROM Unit_Option__c
            WHERE Unit__c IN :set_UnitId
            WITH USER_MODE
        ];
    }

    /**
     * v3.2: Virtual Accounts for the page's Units, joined to their parent Escrow Account
     * so MerchantID__c can be resolved without a second round trip. ASSUMPTION: the lookup
     * to Unit__c is named "Unit__c" and the lookup to EscrowAccount__c is named
     * "EscrowAccount__c" -- adjust both here if the org uses different API names.
     */
    private static List<VirtualAccount__c> getVirtualAccounts(Set<Id> set_UnitId) {
        if (set_UnitId == null || set_UnitId.isEmpty()) return new List<VirtualAccount__c>();

        //3.4 MCR-73: Enforce CRUD/FLS via USER_MODE on VirtualAccount__c query
        return [
            SELECT Id, Unit__c, EscrowAccount__c, EscrowAccount__r.MerchantID__c
            FROM VirtualAccount__c
            WHERE Unit__c IN :set_UnitId
            WITH USER_MODE
        ];
    }

    public static List<PaymentPlan__c> getAllPaymentPlans() {
        //3.4 MCR-73: Enforce CRUD/FLS via USER_MODE on PaymentPlan__c query
        return [
            SELECT Id, Name, Status__c, PaymentInstallment__c, StartDate__c, ExpiryDate__c,
                   Project__c, Phase__c, Phase__r.Name, Phase__r.Id, Phase__r.Project__c, PaymentPlanStructure__c
            FROM PaymentPlan__c
            WHERE Status__c = 'Active'
              AND Online_Sales__c = true
              AND (Project__c != null OR Phase__c != null)
            WITH USER_MODE
        ];
    }

    /** Retained from the helper for external callers. Not used by this endpoint. */
    public static List<PaymentPlan__c> getPaymentPlans(String unitId) {
        if (String.isBlank(unitId)) return new List<PaymentPlan__c>();

        //3.4 MCR-73: Enforce CRUD/FLS via USER_MODE on Unit__c query
        List<Unit__c> lst_Units = [
            SELECT Id, Name, Phase__r.Project__r.Name FROM Unit__c WHERE Id = :unitId WITH USER_MODE LIMIT 1
        ];
        if (lst_Units.isEmpty()
            || lst_Units[0].Phase__r == null
            || lst_Units[0].Phase__r.Project__r == null) {
            return new List<PaymentPlan__c>();
        }

        String projectName = lst_Units[0].Phase__r.Project__r.Name;
        //3.4 MCR-73: Enforce CRUD/FLS via USER_MODE on PaymentPlan__c query
        return [
            SELECT Id, Name, Status__c, PaymentInstallment__c, StartDate__c, ExpiryDate__c,
                   Project__c, PaymentPlanStructure__c
            FROM PaymentPlan__c
            WHERE Status__c = 'Active'
              AND Online_Sales__c = true
              AND Project__r.Name = :projectName
            WITH USER_MODE
            LIMIT 1
        ];
    }

    global static List<String> getfilters(String labelValue) {
        List<String> filterString = new List<String>();
        if (String.isBlank(labelValue)) return filterString;

        for (String s : labelValue.split(',')) {
            filterString.add(s.trim());
        }
        return filterString;
    }

    /* ====================================================================================
     *  INTERNAL WRAPPERS
     * ==================================================================================== */
    /** One page of units plus the total number of matching rows (ignoring the window). */
    public class UnitPage {
        public List<Unit__c> units;
        public Integer       totalCount;
        public UnitPage(List<Unit__c> units, Integer totalCount) {
            this.units      = units;
            this.totalCount = totalCount;
        }
    }

    /* ====================================================================================
     *  RESPONSE DTOs  (Status / ErrorCode / ErrorMessage now live on OIC_RestResponse)
     * ==================================================================================== */
    global class Unit {
        public String  Id;
        public String  Name;
        public String  ProjectName;
        public String  ProjectId;
        public String  Status;
        public String  BlockedBy;
        public String  BlockedFor;
        public String  BlockReason;
        public DateTime BlockUntil;
        public String  Phase;
        public String  InventoryStatus;
        public String  Number_of_Bedrooms;
        public String  FloorNumber;
        public Decimal TotalArea;
        public Decimal TotalGFAsqm;
        public Decimal TotalGrossSellableAreaGSA;
        public Decimal TotalPrice;
        public String  CurrencyIsoCode;
        public Decimal PlotAreasqm;
        public String  PlotNo;
        public String  MDPlotId;
        public String  PaymentPlanId;
        public Boolean ShowUnitPrice;
        public String  ApprovalStatus;
        public String  MerchantId;
        public String  Typology;
        public String  FacadeStyle;
        public String  FacadeType;
        public List<UnitOption> UnitOptions;
    }

    global class UnitOption {
        public String  Id;
        public String  Name;
        public Decimal AED_SQM;
        public Decimal BalconyArea;
        public Decimal BasePrice;
        public Decimal BasementArea;
        public Decimal BasementParkingArea;
        public String  Category;
        public String  Exterior;
        public String  FacadeType;
        public Decimal FirstFloorArea;
        public Decimal GrossFloorAreaGFA;
        public Decimal GroundFloorArea;
        public String  Interior;
        public Decimal Internal_Area;
        public Decimal NumberofBedrooms;
        public Decimal NumberofCarParks;
        public String  Phase;
        public Decimal PlotAreasqm;
        public String  PlotNo;
        public Decimal SecondFloorArea;
        public String  SubCategory;
        public Decimal TerraceArea;
        public Decimal TotalGFAsqm;
        public Decimal TotalGrossSellableAreaGSA;
        public Decimal TotalPrice;
        public String  CurrencyIsoCode;
        public String  Type;
        public String  Typology;
        public String  Unit;
        public String  MerchantId;
    }
}