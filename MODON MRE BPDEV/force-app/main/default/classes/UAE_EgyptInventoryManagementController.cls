/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : UAE_EgyptInventoryManagementController
 * Author          : <YourName>
 * Created Date    : Jun 27, 2026
 * Last Modified By: <YourName>
 * Last Modified On: Jun 27, 2026
 * Description     : Apex controller for the UAE & Egypt Inventory Management LWC.
 *                   Serves paginated Unit__c records scoped to UAE/Egypt buckets,
 *                   provides dynamic filter options, a total-count method, and a
 *                   bulk CCMD status update.
 *
 * Change History  :
 *  Date          │   Author     │   Change
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  Jun 27, 2026  │ <YourName>   │ Initial version
 *  Jun 27, 2026  │ <YourName>   │ GFA filter changed to min/max range params;
 *                │              │ added getTotalCount() for stats bar;
 *                │              │ getFilterOptions() returns GFA range labels
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 */
public with sharing class UAE_EgyptInventoryManagementController {

    // Only these bucket names are ever shown, regardless of what the user requests.
    private static final List<String> ALLOWED_BUCKET_NAMES =
        new List<String>{ 'UAE Team', 'Egypt UAE Team' };

    // Mandatory source entity restriction – always applied, not user-overridable.
    private static final String REQUIRED_SOURCE_ENTITY = 'Modon - Egypt';

    private static final String STATUS_CCMD      = 'CCMD';
    private static final String STATUS_AVAILABLE = 'Available';

    private static final String BLOCK_REASON_MANAGEMENT = 'Hold By Management';

    // GFA range breakpoints (sqm). Every range is [lowerBound, upperBound).
    // The last entry uses null as upperBound to mean "no ceiling" (1000+).
    private static final List<Integer> GFA_BREAKPOINTS =
        new List<Integer>{ 0, 200, 400, 600, 800, 1000 };

    /**
     * Simple, explicit DTO for incoming filter values.
     * One object instead of ~9 primitive arguments keeps the Apex signature
     * and the JS callsite clean. Not a "service layer" — just a flat input DTO.
     *
     * gfaMin / gfaMax are Decimal so the caller can pass null for "no bound".
     */
    public class InventoryFilters {
        @AuraEnabled public String  project { get; set; }
        @AuraEnabled public String  phase { get; set; }
        @AuraEnabled public String  zone { get; set; }
        @AuraEnabled public String  bucket { get; set; }
        @AuraEnabled public String  unitClassification { get; set; }
        @AuraEnabled public String  bedrooms { get; set; }
        @AuraEnabled public String  unitQuality { get; set; }
        @AuraEnabled public Decimal gfaMin { get; set; }   // lower bound (inclusive), null = no lower bound
        @AuraEnabled public Decimal gfaMax { get; set; }   // upper bound (exclusive),  null = no upper bound
        @AuraEnabled public String  floor { get; set; }
        @AuraEnabled public String  status { get; set; }
        @AuraEnabled public String  searchKey { get; set; }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // PUBLIC METHODS
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Returns one page of CCMD + Available units matching the given filters.
     *
     * GFA range: passed as gfaMin / gfaMax on the InventoryFilters object so
     * GrossFloorAreaGFA__c (a Decimal field that cannot be used in GROUP BY)
     * is filtered via WHERE instead of HAVING.
     *
     * @param filters    Filter criteria (nullable fields = "no filter applied").
     * @param offsetSize Records to skip (0-based pagination).
     * @param pageSize   Records to return per page (defaults to 50).
     */
    @AuraEnabled(cacheable=false)
    public static List<Unit__c> getInventoryUnits(
        InventoryFilters whereClauseFilters,
        Integer offsetSize,
        Integer pageSize
    ) {
        try {
            if (!Schema.sObjectType.Unit__c.isAccessible()) {
                throw new AuraHandledException('You do not have access to Units.');
            }

            if (pageSize  == null || pageSize  <= 0) { pageSize  = 50; }
            if (offsetSize == null || offsetSize < 0) { offsetSize = 0; }

            Map<String, Object> binds = new Map<String, Object>();
            String whereClause = buildWhereClause(whereClauseFilters, binds);

            String query =
                'SELECT Id, Name, Project_Name__c, Phase__r.Name, Zone__c, ' +
                '       Bucket__r.Name, UnitClassification__c, Number_of_Bedrooms__c, ' +
                '       Unit_Quality__c, GrossFloorAreaGFA__c, BlockComment__c, BlockReason__c, FloorNumber__c, ApprovalStatus__c, Status__c ' +
                'FROM   Unit__c ' +
                'WHERE  ' + whereClause +
                'ORDER BY Name ASC ' +
                'LIMIT :pageSize OFFSET :offsetSize';

            binds.put('pageSize',   pageSize);
            binds.put('offsetSize', offsetSize);

            return Database.queryWithBinds(query, binds, AccessLevel.USER_MODE);

        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException('Failed to load units: ' + e.getMessage());
        }
    }

    /**
     * Returns the total count of qualifying units for the current filter set.
     * Called separately from getInventoryUnits so the stats bar can show
     * "X total units" without waiting for pagination to finish.
     *
     * @param filters  Same filter object used by getInventoryUnits.
     */
    @AuraEnabled(cacheable=false)
    public static Integer getTotalCount(InventoryFilters filters) {
        try {
            if (!Schema.sObjectType.Unit__c.isAccessible()) {
                throw new AuraHandledException('You do not have access to Units.');
            }

            Map<String, Object> binds = new Map<String, Object>();
            String whereClause = buildWhereClause(filters, binds);

            String query =
                'SELECT COUNT() FROM Unit__c WHERE ' + whereClause;

            return Database.countQueryWithBinds(query, binds, AccessLevel.USER_MODE);

        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException('Failed to get total count: ' + e.getMessage());
        }
    }

    /**
     * Returns the grand total of UAE + Egypt UAE Team units (no user filters).
     * Used by the stats bar to show "X total units in UAE & Egypt buckets".
     * Cached because it never changes based on user input.
     */
    @AuraEnabled(cacheable=true)
    public static Integer getGrandTotalCount() {
        try {
            if (!Schema.sObjectType.Unit__c.isAccessible()) {
                throw new AuraHandledException('You do not have access to Units.');
            }
            return [
                SELECT COUNT()
                FROM   Unit__c
                WHERE  Bucket__r.Name IN :ALLOWED_BUCKET_NAMES
                AND    Source_Entity__c = :REQUIRED_SOURCE_ENTITY
                AND    ApprovalStatus__c = 'Released'
                AND    Status__c IN ('CCMD', 'Available')
                WITH   USER_MODE
            ];
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException('Failed to get grand total: ' + e.getMessage());
        }
    }

    /**
     * Returns distinct values for every filterable field, scoped to the
     * allowed buckets + required source entity.
     *
     * GFA options are returned as human-readable range labels (e.g. "0 – 200 sqm")
     * under the key "grossFloorAreaRanges". The matching min/max values are
     * resolved in JS (see GFA_RANGES constant in the LWC).
     *
     * Project_Name__c is a formula field referencing Phase__r.Project__r.Name
     * and cannot be used in GROUP BY, so it is collected in a separate query.
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, List<String>> getFilterOptions() {
        try {
            if (!Schema.sObjectType.Unit__c.isAccessible()) {
                throw new AuraHandledException('You do not have access to Units.');
            }

            // One GROUP BY query covers all non-formula, non-Decimal groupable fields.
            List<AggregateResult> rows = [
                SELECT Phase__r.Name     phaseName,
                       Zone__c,
                       Bucket__r.Name    bucketName,
                       UnitClassification__c,
                       Number_of_Bedrooms__c,
                       Unit_Quality__c,
                       FloorNumber__c
                FROM   Unit__c
                WHERE  Bucket__r.Name IN :ALLOWED_BUCKET_NAMES
                AND    Source_Entity__c = :REQUIRED_SOURCE_ENTITY
                AND    ApprovalStatus__c = 'Released'
                AND    Status__c IN ('CCMD', 'Available')
                WITH   USER_MODE
                GROUP BY Phase__r.Name, Zone__c, Bucket__r.Name, FloorNumber__c,
                         UnitClassification__c, Number_of_Bedrooms__c, Unit_Quality__c
            ];

            Set<String> projects       = new Set<String>();
            Set<String> phases         = new Set<String>();
            Set<String> zones          = new Set<String>();
            Set<String> buckets        = new Set<String>();
            Set<String> classifications= new Set<String>();
            Set<String> bedroomsSet    = new Set<String>();
            Set<String> qualities      = new Set<String>();
            Set<String> floors         = new Set<String>();

            for (AggregateResult row : rows) {
                addIfNotBlank(phases,          (String) row.get('phaseName'));
                addIfNotBlank(zones,           (String) row.get('Zone__c'));
                addIfNotBlank(buckets,         (String) row.get('bucketName'));
                addIfNotBlank(classifications, (String) row.get('UnitClassification__c'));
                addIfNotBlank(qualities,       (String) row.get('Unit_Quality__c'));
                addIfNotBlank(floors,          (String) row.get('FloorNumber__c'));

                Object bedroomsVal = row.get('Number_of_Bedrooms__c');
                if (bedroomsVal != null) {
                    bedroomsSet.add(String.valueOf(bedroomsVal));
                }
            }

            // Project_Name__c is a formula (Phase__r.Project__r.Name) and cannot
            // be used in GROUP BY → collect distinct values via a plain SELECT.
            for (Unit__c u : [
                SELECT Project_Name__c
                FROM   Unit__c
                WHERE  Bucket__r.Name IN :ALLOWED_BUCKET_NAMES
                AND    Source_Entity__c = :REQUIRED_SOURCE_ENTITY
                AND    ApprovalStatus__c = 'Released'
                AND    Status__c IN ('CCMD', 'Available')
                WITH   USER_MODE
                LIMIT  10000
            ]) {
                addIfNotBlank(projects, u.Project_Name__c);
            }

            // GFA ranges: static labels derived from GFA_BREAKPOINTS.
            // Resolved to min/max Decimal values in the LWC JS (GFA_RANGES constant).
            List<String> gfaRangeLabels = new List<String>();
            for (Integer i = 0; i < GFA_BREAKPOINTS.size(); i++) {
                Integer lower = GFA_BREAKPOINTS[i];
                if (i < GFA_BREAKPOINTS.size() - 1) {
                    Integer upper = GFA_BREAKPOINTS[i + 1];
                    gfaRangeLabels.add(lower + ' – ' + upper + ' sqm');
                } else {
                    gfaRangeLabels.add(lower + '+ sqm');
                }
            }

            Map<String, List<String>> options = new Map<String, List<String>>();
            options.put('project',            sortedList(projects));
            options.put('phase',              sortedList(phases));
            options.put('zone',               sortedList(zones));
            options.put('bucket',             sortedList(buckets));
            options.put('unitClassification', sortedList(classifications));
            options.put('bedrooms',           sortedList(bedroomsSet));
            options.put('unitQuality',        sortedList(qualities));
            options.put('grossFloorAreaRanges', gfaRangeLabels); // range labels, not raw values
            options.put('floor',              sortedList(floors));

            return options;

        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException('Failed to load filter options: ' + e.getMessage());
        }
    }

    /**
     * Bulk-updates Status__c to 'CCMD' for the given record IDs.
     * The caller (LWC) must pre-filter to only pass Available unit IDs;
     * this method performs an additional server-side guard and returns
     * how many records were actually updated.
     *
     * @param recordIds  IDs of Unit__c records to update.
     * @return           Number of records updated (for the success toast).
     */
    @AuraEnabled
    public static Integer updateUnitsStatus(List<Id> recordIds, String blockComments) {
        try {
            if (recordIds == null || recordIds.isEmpty()) {
                throw new AuraHandledException('No records were selected for update.');
            }

            if (!Schema.sObjectType.Unit__c.fields.Status__c.isUpdateable()) {
                throw new AuraHandledException(
                    'You do not have permission to update the Status field.'
                );
            }

            // Server-side guard: only update units that are still Available.
            // This protects against stale selections and concurrent edits.
            List<Unit__c> availableUnits = [
                SELECT Id, Status__c
                FROM   Unit__c
                WHERE  Id IN :recordIds
                AND    Status__c = :STATUS_AVAILABLE
                WITH   USER_MODE
            ];

            if (availableUnits.isEmpty()) {
                throw new AuraHandledException(
                    'All selected units already have CCMD status. No update was performed.'
                );
            }

            List<Unit__c> toUpdate = new List<Unit__c>();
            for (Unit__c u : availableUnits) {
                toUpdate.add(new Unit__c(Id = u.Id, Status__c = STATUS_CCMD, BlockReason__c = BLOCK_REASON_MANAGEMENT, BlockComment__c = blockComments));
            }

            // Strip any fields the running user cannot edit (defensive FLS enforcement).
            SObjectAccessDecision decision =
                Security.stripInaccessible(AccessType.UPDATABLE, toUpdate);
            update decision.getRecords();

            return decision.getRecords().size();

        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (DmlException dmlEx) {
            throw new AuraHandledException(
                'Failed to update status: ' + dmlEx.getDmlMessage(0)
            );
        } catch (Exception e) {
            throw new AuraHandledException('Failed to update status: ' + e.getMessage());
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // PRIVATE HELPERS
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Builds the WHERE clause string and populates the binds map.
     * Mandatory restrictions (bucket, source entity, status, approval) are
     * always added first. User-supplied filters narrow the result further.
     * No user input is ever concatenated directly into the string.
     */
    private static String buildWhereClause(
        InventoryFilters filters,
        Map<String, Object> binds
    ) {
        List<String> conditions = new List<String>();

        // ── Mandatory restrictions ────────────────────────────────────────
        conditions.add('Bucket__r.Name IN :allowedBucketNames');
        binds.put('allowedBucketNames', ALLOWED_BUCKET_NAMES);

        conditions.add('Source_Entity__c = :requiredSourceEntity');
        binds.put('requiredSourceEntity', REQUIRED_SOURCE_ENTITY);

        conditions.add('ApprovalStatus__c = \'Released\'');

        conditions.add('Status__c IN (\'CCMD\', \'Available\')');

        // ── User-supplied filters ─────────────────────────────────────────
        if (filters != null) {

            // When a searchKey is present we intentionally ignore all other
            // user filters (project, phase, zone, etc.) and only apply the
            // mandatory restrictions above plus the name LIKE below.
            // This lets users search freely without being blocked by whatever
            // filter dropdowns happen to be selected.
            Boolean isSearchMode = String.isNotBlank(filters.searchKey);

            if (isSearchMode) {
                // Search mode: only filter by name, ignore all other user filters.
                conditions.add('Name LIKE :searchPattern');
                binds.put(
                    'searchPattern',
                    '%' + String.escapeSingleQuotes(filters.searchKey.trim()) + '%'
                );
            } else {
                // Normal filter mode: apply every non-blank dropdown filter.
                if (String.isNotBlank(filters.project)) {
                    conditions.add('Project_Name__c = :projectVal');
                    binds.put('projectVal', filters.project);
                }
                if (String.isNotBlank(filters.phase)) {
                    conditions.add('Phase__r.Name = :phaseVal');
                    binds.put('phaseVal', filters.phase);
                }
                if (String.isNotBlank(filters.zone)) {
                    conditions.add('Zone__c = :zoneVal');
                    binds.put('zoneVal', filters.zone);
                }
                // Bucket is already hardcoded in the mandatory restrictions above.
                // This optional filter allows narrowing to one specific bucket.
                if (String.isNotBlank(filters.bucket)) {
                    conditions.add('Bucket__r.Name = :bucketVal');
                    binds.put('bucketVal', filters.bucket);
                }
                if (String.isNotBlank(filters.unitClassification)) {
                    conditions.add('UnitClassification__c = :classificationVal');
                    binds.put('classificationVal', filters.unitClassification);
                }
                if (String.isNotBlank(filters.bedrooms)) {
                    conditions.add('Number_of_Bedrooms__c = :bedroomsVal');
                    binds.put('bedroomsVal', filters.bedrooms);
                }
                if (String.isNotBlank(filters.unitQuality)) {
                    conditions.add('Unit_Quality__c = :qualityVal');
                    binds.put('qualityVal', filters.unitQuality);
                }

                // GFA range: GrossFloorAreaGFA__c is a Decimal and cannot be
                // used in GROUP BY, so it is filtered here in WHERE via min/max.
                if (filters.gfaMin != null) {
                    conditions.add('GrossFloorAreaGFA__c >= :gfaMin');
                    binds.put('gfaMin', filters.gfaMin);
                }
                if (filters.gfaMax != null) {
                    conditions.add('GrossFloorAreaGFA__c < :gfaMax');
                    binds.put('gfaMax', filters.gfaMax);
                }

                if (String.isNotBlank(filters.floor)) {
                    conditions.add('FloorNumber__c = :floorVal');
                    binds.put('floorVal', filters.floor);
                }

                if (String.isNotBlank(filters.status)) {
                    conditions.add('Status__c = :statusVal');
                    binds.put('statusVal', filters.status);
                }
            }
        }

        return String.join(conditions, ' AND ') + ' ';
    }

    private static void addIfNotBlank(Set<String> targetSet, String value) {
        if (String.isNotBlank(value)) {
            targetSet.add(value);
        }
    }

    private static List<String> sortedList(Set<String> values) {
        List<String> result = new List<String>(values);
        result.sort();
        return result;
    }
}