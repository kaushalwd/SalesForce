/**
 * EOIController

 * Active / inactive is driven solely by EOI_Range__c.Is_Active__c.
 * All dropdown options are derived from active EOI Range records only.
 */
public with sharing class EOIController {

    // ─────────────────────────────────────────────────────────────────────────
    // 1. Projects — distinct from active EOI Range records only
    // ─────────────────────────────────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static List<LookupOption> getProjects() {
        // Pull distinct Project Ids + Names via the lookup relationship
        // Only projects that have at least one active EOI Range record appear
        Map<Id, String> seen = new Map<Id, String>();
        for (EOI_Range__c r : [
            SELECT Project__c, Project__r.Name
            FROM   EOI_Range__c
            WHERE  Is_Active__c = true
              AND  Project__c  != null
            ORDER BY Project__r.Name ASC
        ]) {
            if (!seen.containsKey(r.Project__c)) {
                seen.put(r.Project__c, r.Project__r.Name);
            }
        }
        List<LookupOption> options = new List<LookupOption>();
        for (Id pid : seen.keySet()) {
            options.add(new LookupOption(pid, seen.get(pid)));
        }
        // Sort alphabetically by label
        options.sort();
        return options;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 2. Phases — distinct from active EOI Range records for selected project
    // ─────────────────────────────────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static List<LookupOption> getPhases(Id projectId) {
        Map<Id, String> seen = new Map<Id, String>();
        for (EOI_Range__c r : [
            SELECT Phase__c, Phase__r.Name
            FROM   EOI_Range__c
            WHERE  Project__c   = :projectId
              AND  Is_Active__c = true
              AND  Phase__c    != null
            ORDER BY Phase__r.Name ASC
        ]) {
            if (!seen.containsKey(r.Phase__c)) {
                seen.put(r.Phase__c, r.Phase__r.Name);
            }
        }
        List<LookupOption> options = new List<LookupOption>();
        for (Id pid : seen.keySet()) {
            options.add(new LookupOption(pid, seen.get(pid)));
        }
        options.sort();
        return options;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 3. Unit types — distinct from active EOI Range for project + phase
    // ─────────────────────────────────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static List<String> getUnitTypes(Id projectId, Id phaseId) {
        List<AggregateResult> results = [
            SELECT Unit_Type__c ut
            FROM   EOI_Range__c
            WHERE  Project__c   = :projectId
              AND  Phase__c     = :phaseId
              AND  Is_Active__c = true
            GROUP BY Unit_Type__c
            ORDER BY Unit_Type__c ASC
        ];
        List<String> out = new List<String>();
        for (AggregateResult r : results) {
            out.add((String) r.get('ut'));
        }
        return out;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 4. Bedrooms — distinct from active EOI Range for project + phase + type
    // ─────────────────────────────────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static List<String> getBedrooms(Id projectId, Id phaseId, String unitType) {
        List<AggregateResult> results = [
            SELECT No_of_Bedrooms__c br
            FROM   EOI_Range__c
            WHERE  Project__c    = :projectId
              AND  Phase__c      = :phaseId
              AND  Unit_Type__c  = :unitType
              AND  Is_Active__c  = true
            GROUP BY No_of_Bedrooms__c
            ORDER BY No_of_Bedrooms__c ASC
        ];
        List<String> out = new List<String>();
        for (AggregateResult r : results) {
            out.add((String) r.get('br'));
        }
        return out;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 5. Matched EOI Range record — Id + Amount
    // ─────────────────────────────────────────────────────────────────────────
    @AuraEnabled(cacheable=true)
    public static EOIRangeResult getEOIRange(
        Id     projectId,
        Id     phaseId,
        String unitType,
        String bedrooms
    ) {
        List<EOI_Range__c> ranges = [
            SELECT Id, Amount__c
            FROM   EOI_Range__c
            WHERE  Project__c        = :projectId
              AND  Phase__c          = :phaseId
              AND  Unit_Type__c      = :unitType
              AND  No_of_Bedrooms__c = :bedrooms
              AND  Is_Active__c      = true
            LIMIT 1
        ];
        if (ranges.isEmpty()) return null;
        EOIRangeResult res = new EOIRangeResult();
        res.rangeId = ranges[0].Id;
        res.amount  = ranges[0].Amount__c;
        return res;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 6. Validate — duplicate EOI + project quota (Custom Label)
    // ─────────────────────────────────────────────────────────────────────────
    @AuraEnabled(cacheable=false)
    public static ValidationResult validateEOI(Id opportunityId, Id projectId) {
        ValidationResult res = new ValidationResult();

        // Duplicate check
        List<Expressionofinterest__c> existing = [
            SELECT Id, Name
            FROM   Expressionofinterest__c
            WHERE  Opportunity__c = :opportunityId
            LIMIT  1
        ];
        if (!existing.isEmpty()) {
            res.isDuplicate    = true;
            res.existingEOIRef = existing[0].Name;
            return res;
        }

        // Quota check — count existing EOIs for the project
        if (projectId != null) {
            Integer limitVal = Integer.valueOf(System.Label.EOI_Max_Limit_Per_Project);
            Integer used     = [
                SELECT COUNT() FROM Expressionofinterest__c
                WHERE Project__c = :projectId
            ];
            res.quotaLimit     = limitVal;
            res.quotaUsed      = used;
            res.quotaRemaining = limitVal - used;
            res.quotaExceeded  = (used >= limitVal);
        }

        res.isDuplicate = false;
        return res;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 7. Create EOI — customer auto-mapped from Opportunity
    // ─────────────────────────────────────────────────────────────────────────
    @AuraEnabled
    public static String createEOI(
        Id      opportunityId,
        Id      projectId,
        Id      phaseId,
        String  unitType,
        String  bedrooms,
        Integer numberOfUnits,
        Id      eoiRangeId,
        Decimal eoiAmount
    ) {
        // Server-side guard — always re-validate before insert
        ValidationResult check = validateEOI(opportunityId, projectId);
        if (check.isDuplicate) {
            throw new AuraHandledException(
                'An EOI already exists for this Opportunity: ' + check.existingEOIRef
            );
        }
        if (check.quotaExceeded) {
            throw new AuraHandledException(
                'EOI limit of ' + check.quotaLimit + ' has been reached for this project.'
            );
        }

        // Pull customer details from Opportunity — no manual form entry
        Opportunity opp = [
            SELECT ContactId, AccountId
            FROM   Opportunity
            WHERE  Id = :opportunityId
            LIMIT  1
        ];

        Expressionofinterest__c eoi = new Expressionofinterest__c(
            Opportunity__c      = opportunityId,
            Project__c          = projectId,
            Phase__c            = phaseId,
            UnitType__c         = unitType,
            NumberofBedrooms__c = bedrooms,
            Number_of_Units__c  = numberOfUnits,
            EOI_Range__c        = eoiRangeId,
            EOI_Amount_AED__c       = eoiAmount,
           // Amount__c            = eoiAmount,
            Contact__c          = opp.ContactId,
            Account__c          = opp.AccountId
        );
        insert eoi;
        return eoi.Id;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Wrapper classes
    // ─────────────────────────────────────────────────────────────────────────
    public class LookupOption implements Comparable {
        @AuraEnabled public Id     value;
        @AuraEnabled public String label;
        public LookupOption(Id v, String l) { value = v; label = l; }
        public Integer compareTo(Object other) {
            return label.compareTo(((LookupOption) other).label);
        }
    }

    public class EOIRangeResult {
        @AuraEnabled public Id      rangeId;
        @AuraEnabled public Decimal amount;
    }

    public class ValidationResult {
        @AuraEnabled public Boolean isDuplicate    = false;
        @AuraEnabled public String  existingEOIRef;
        @AuraEnabled public Integer quotaLimit     = 500;
        @AuraEnabled public Integer quotaUsed      = 0;
        @AuraEnabled public Integer quotaRemaining = 500;
        @AuraEnabled public Boolean quotaExceeded  = false;
    }
}