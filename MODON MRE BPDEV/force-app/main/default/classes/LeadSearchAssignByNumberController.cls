/**********************************************************************************************************************
* Name               : LeadSearchAssignByNumberController
* Description        : Controller class for Home Page LWC used to search Leads by LeadNumber__c and show Lead ownership status.
* Usage              : leadSearchAssignByNumberHome LWC
* Created By         : PWC Digital Middle East
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment
* 1.0           prateek.b.bansal@pwc.com           06 Jan 2026      Initial Draft
* 1.1           prateek.bansal@modon.com           07 Jan 2026      Updated search response to show converted/owner info (no reassignment)
**********************************************************************************************************************/
public without sharing class LeadSearchAssignByNumberController {

    private static final String SUB_SOURCE_FIELD = 'SubSource__c';
    private static final String CUSTOM_PERMISSION = 'Lead_Search_Assign';

    private static Boolean isAuthorized() {
        return FeatureManagement.checkPermission(CUSTOM_PERMISSION);
    }

    public class LeadRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String leadNumber;
        @AuraEnabled public Boolean isConverted;
        @AuraEnabled public Id ownerId;
        @AuraEnabled public String ownerName;
    }

    private class AllowedConfig {
        Set<String> sources = new Set<String>(); // LeadSource only
        Set<String> pairs   = new Set<String>(); // LeadSource||SubSource
    }

    private static AllowedConfig getAllowedConfig() {
        AllowedConfig cfg = new AllowedConfig();

        for (Lead_Assign_Filter__mdt m : [
            SELECT LeadSource__c, SubSource__c
            FROM Lead_Assign_Filter__mdt
            WHERE IsActive__c = true
        ]) {
            if (String.isBlank(m.LeadSource__c)) continue;

            String src = m.LeadSource__c.trim();
            String sub = (m.SubSource__c == null) ? '' : m.SubSource__c.trim();

            if (String.isBlank(sub)) cfg.sources.add(src);
            else cfg.pairs.add(src + '||' + sub);
        }
        return cfg;
    }

    private static Boolean isAllowed(AllowedConfig cfg, String src, String sub) {
        if (cfg == null || String.isBlank(src)) return false;

        String s = src.trim();
        String ss = (sub == null) ? '' : sub.trim();

        if (!String.isBlank(ss) && cfg.pairs.contains(s + '||' + ss)) return true;
        if (cfg.sources.contains(s)) return true;

        return false;
    }

    @AuraEnabled(cacheable=true)
    public static List<LeadRow> searchByLeadNumber(String leadNumberTerm, Integer maxRows) {
        if (!isAuthorized()) return new List<LeadRow>();

        String t = (leadNumberTerm == null) ? '' : leadNumberTerm.trim();
        if (String.isBlank(t)) return new List<LeadRow>();

        AllowedConfig cfg = getAllowedConfig();
        if (cfg.sources.isEmpty() && cfg.pairs.isEmpty()) return new List<LeadRow>();

        // SOQL injection fix: static SOQL with bind for lead number (exact match only).
        List<Lead> leads = [
            SELECT Id, LeadNumber__c, LeadSource, SubSource__c, IsConverted, OwnerId, Owner.Name
            FROM Lead
            WHERE LeadNumber__c = :t
            LIMIT 1
        ];

        if (leads.isEmpty()) return new List<LeadRow>();

        Lead l = leads[0];

        String src = (String) l.get('LeadSource');
        String sub = (String) l.get(SUB_SOURCE_FIELD);

        // Allow-list check applies irrespective of converted status
        if (!isAllowed(cfg, src, sub)) return new List<LeadRow>();

        LeadRow r = new LeadRow();
        r.id = l.Id;
        r.leadNumber = (String) l.get('LeadNumber__c');
        r.isConverted = l.IsConverted;
        r.ownerId = l.OwnerId;
        r.ownerName = (l.Owner != null) ? l.Owner.Name : null;

        return new List<LeadRow>{ r };
    }

    // Keep assignToMe if already deployed/used elsewhere; the LWC will no longer call it.
    // public static String assignToMe(Id leadId) { ... }
}