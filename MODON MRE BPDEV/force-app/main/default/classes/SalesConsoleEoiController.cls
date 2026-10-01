/**
 * SalesConsoleEoiController - the EOI pane.
 *
 * Version  Author      Date         Detail
 * 1.2      Aurelix Dev  18 Sep 2026  MSC-181 (B9). eoiNumber = EOIId__c (e.g. EOI-VYN4B9), the
 *                                    reference the customer and the branch quote, beside Name
 *                                    (the auto-number). Read only; nothing else changes.
 * 1.0      Aurelix IT  09 Aug 2026  Initial. List only - creation delegates to the
 *                                   org's own EOIController.
 * 1.1      Aurelix IT  13 Aug 2026  projectName read the OPPORTUNITY's name, so every row
 *                                   was mislabelled; amount was declared and never set.
 */

/**
 * Deliberately just a reader.
 *
 * EOIController already owns the quota, the duplicate check, the range lookup and the
 * project/phase/type/bedroom cascade, and its createEOI re-validates server-side
 * before inserting. A second implementation of any of that would drift from it, and a
 * drifting EOI quota is a commercial problem, not a UI one. So the console reads its
 * own list here and calls EOIController for everything else.
 *
 * Expressionofinterest__c has no OwnerId - it is not an ownable object in this org -
 * so "mine" resolves through the Opportunity, which is owned. That is also the truer
 * reading: an EOI belongs to whoever is working the opportunity.
 */
public with sharing class SalesConsoleEoiController {

    public class EoiDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        /** 1.2 - EOIId__c, the customer-facing EOI number. */
        @AuraEnabled public String eoiNumber;
        @AuraEnabled public String status;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public String projectName;
        @AuraEnabled public String customerName;
        @AuraEnabled public Id opportunityId;
        @AuraEnabled public Datetime createdDate;
    }

    /** Statuses that no longer count as live. Matches the hub's EOI card exactly. */
    private static final Set<String> CLOSED_STATUSES = new Set<String>{
        'Cancelled', 'Voided', 'Expired', 'Rejected'
    };

    @AuraEnabled(cacheable=true)
    public static List<EoiDTO> getMyEois() {
        List<EoiDTO> out = new List<EoiDTO>();
        for (Expressionofinterest__c e : [
            SELECT Id, Name, EOIId__c, Status__c, Opportunity__c, CreatedDate,
                   Account__r.Name, Project__r.Name, EOI_Amount_AED__c
            FROM Expressionofinterest__c
            WHERE Opportunity__r.OwnerId = :UserInfo.getUserId()
            ORDER BY CreatedDate DESC
            LIMIT 200
        ]) {
            EoiDTO d = new EoiDTO();
            d.id = e.Id;
            d.name = e.Name;
            d.eoiNumber = e.EOIId__c;
            d.status = e.Status__c;
            d.customerName = e.Account__r != null ? e.Account__r.Name : null;
            /* 1.1 - Project__r.Name, not Opportunity__r.Name. Every row was labelled
               with the opportunity's name under a heading that said Project, so the
               pane read as though each EOI belonged to a project named after the customer. */
            d.projectName = e.Project__r != null ? e.Project__r.Name : null;
            // Declared since 1.0 and never populated, so every row showed a blank amount.
            d.amount = e.EOI_Amount_AED__c;
            d.opportunityId = e.Opportunity__c;
            d.createdDate = e.CreatedDate;
            out.add(d);
        }
        return out;
    }

    /** Live count, kept here so the pane and the hub card cannot disagree. */
    @AuraEnabled(cacheable=true)
    public static Integer getActiveEoiCount() {
        return [
            SELECT COUNT() FROM Expressionofinterest__c
            WHERE Opportunity__r.OwnerId = :UserInfo.getUserId()
              AND Status__c NOT IN :CLOSED_STATUSES
        ];
    }
}