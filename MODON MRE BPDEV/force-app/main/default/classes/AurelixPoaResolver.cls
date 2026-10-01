/**
 * AurelixPoaResolver - which Contact is a company's CURRENT authorised signatory.
 *
 * Version  Author       Date         Detail
 * 1.1      Aurelix Dev  29 Sep 2026  New bookingSubject(ForOpportunity): a company's booking is checked on the
 *                                    primary contact (the POA, as MODON's checkKYCEligibility reads it), else
 *                                    the POA row. Used by manual KYC and the documents checklist.
 * 1.0      Aurelix Dev  18 Sep 2026  MSC-176 (B6). Extracted, unchanged, from
 *                                    AurelixKycEligibilityService.resolveAuthorisedPoaContact so
 *                                    that eligibility, manual KYC and the document checklist all
 *                                    answer "who signs for this company" with the same rule. The
 *                                    eligibility service now delegates here.
 *
 * THE RULE. Never "a contact who happens to have completed KYC". SalesConsoleOrgController's
 * assignSignatory (MSC-181) replaces the single Power_of_Attorney__c row and repoints
 * Opportunity.PrimaryContact__c in the same transaction, so the POA row is authoritative and the
 * Opportunity should agree with it. Where the Opportunity's primary contact is among the rows it is
 * preferred - that is the signatory chosen for THIS deal - otherwise the most recently maintained
 * row wins. Null when no POA row exists. That is resolve's rule. Since 1.1 a company's own booking
 * follows bookingSubject instead: the primary contact is the POA, as MODON's gate reads it.
 *
 * OWNERSHIP. Aurelix-owned. Power_of_Attorney__c is MODON's object and is READ only.
 */
public with sharing class AurelixPoaResolver {

    /** The current authorised POA Contact for a company; null when there is none. */
    public static Id resolve(Id companyId, Id opportunityPrimaryContactId) {
        if (companyId == null) { return null; }

        List<Power_of_Attorney__c> rows = [
            SELECT Id, Contact__c
            FROM Power_of_Attorney__c
            WHERE Organization_Account__c = :companyId AND Contact__c != NULL
            ORDER BY LastModifiedDate DESC
        ];
        if (rows.isEmpty()) { return null; }

        for (Power_of_Attorney__c p : rows) {
            if (p.Contact__c == opportunityPrimaryContactId) { return p.Contact__c; }
        }
        return rows[0].Contact__c;
    }

    /**
     * 1.1 - who a company's own booking is checked on: the primary contact (the POA, as MODON's gate
     * reads it), else the POA row from resolve, else null.
     */
    public static Id bookingSubject(Id companyId, Id opportunityPrimaryContactId) {
        if (opportunityPrimaryContactId != null) { return opportunityPrimaryContactId; }
        return resolve(companyId, null);
    }

    /** 1.1 - bookingSubject for an Opportunity, read once. Null for a person buyer or an unknown Id. */
    public static Id bookingSubjectForOpportunity(Id opportunityId) {
        if (opportunityId == null) { return null; }
        for (Opportunity o : [
            SELECT Id, AccountId, PrimaryContact__c, Account.IsPersonAccount
            FROM Opportunity WHERE Id = :opportunityId LIMIT 1
        ]) {
            if (o.Account == null || o.Account.IsPersonAccount == true) { return null; }
            return bookingSubject(o.AccountId, o.PrimaryContact__c);
        }
        return null;
    }

    /** The same answer for an Opportunity, read once. Null for a person buyer or an unknown Id. */
    public static Id resolveForOpportunity(Id opportunityId) {
        if (opportunityId == null) { return null; }
        for (Opportunity o : [
            SELECT Id, AccountId, PrimaryContact__c, Account.IsPersonAccount
            FROM Opportunity WHERE Id = :opportunityId LIMIT 1
        ]) {
            if (o.Account == null || o.Account.IsPersonAccount == true) { return null; }
            return resolve(o.AccountId, o.PrimaryContact__c);
        }
        return null;
    }
}