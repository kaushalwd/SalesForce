/**********************************************************************************************************************
* Name               : LeadsearchController
* Description        : This class is used to search all the leads for broker queue
* Created By         : Active Minds
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           Chandu                      04 Feb 2026     Search broker leads and convert the leads to opprtunity
* 2.0           Arvind                      07 Jun 2026     EOI Search tab - search by EOIId__c or Name.
*                                                           NOTE: ExpressionofInterest__c is Master-Detail child
*                                                           of Opportunity and has NO OwnerId field.
*                                                           All owner checks + updates are on Opportunity.OwnerId.
*                                                           Custom Label: EOI_Default_Owner_Id
*                                                           without-sharing inner class for Opportunity access.
******************************************************************************************************************/
public without sharing class leadSearchController {

    // ═══════════════════════════════════════════════════════════════════════
    // LEAD SEARCH  (v1.0 - unchanged, do not modify)
    // ═══════════════════════════════════════════════════════════════════════

    @AuraEnabled(cacheable=true)
    public static List<Lead> searchLeadsByNumber(String leadNumber) {

        Id brokerQueueId = [
            SELECT Id
            FROM Group
            WHERE Type = 'Queue'
            AND DeveloperName = 'Brokers_Queue'
            LIMIT 1
        ].Id;

        List<Lead> leads = [
            SELECT Id, FirstName, LastName,
            Email, MobilePhone, Status,
            CreatedBy.Name, CreatedDate,
            BrokerAgency_Name__c, BrokerAgentName__c,
            OwnerId, ProjectInterest__c,
            IsConverted,
            ConvertedAccountId,
            ConvertedContactId,
            ConvertedOpportunityId
            FROM Lead
            WHERE LeadNumber__c = :leadNumber
            //AND (OwnerId = :brokerQueueId OR IsConverted = true)
            AND OwnerId = :brokerQueueId
        ];

        return leads;
    }

    @AuraEnabled
    public static void assignLeadToCurrentUser(Id leadId) {

        Lead ld = [
            SELECT Id, OwnerId, Owner.Name, IsConverted, Status
            FROM Lead
            WHERE Id = :leadId
            LIMIT 1
        ];

        //  Retired lead
        if (ld.Status == 'Retired') {
            throw new AuraHandledException(
                'Lead is in Retired status and cannot be assigned or converted.'
            );
        }

        //  Block ONLY if owned by another USER (005)
        if (ld.OwnerId != null &&
            String.valueOf(ld.OwnerId).startsWith('005') &&
            ld.OwnerId != UserInfo.getUserId()) {

                throw new AuraHandledException(
                    'Lead is already assigned to ' + ld.Owner.Name + '.'
                );
            }

        // Already assigned to current user
        if (ld.OwnerId == UserInfo.getUserId()) {
            throw new AuraHandledException(
                'Lead is already assigned to you.'
            );
        }

        //  Assign to current user (from Queue or unowned)
        ld.OwnerId = UserInfo.getUserId();
        update ld;
    }

    // ═══════════════════════════════════════════════════════════════════════
    // EOI SEARCH  (v2.0 - new)
    //
    // IMPORTANT: ExpressionofInterest__c is a Master-Detail child of Opportunity.
    //            Master-Detail records DO NOT have their own OwnerId field.
    //            Ownership is inherited from the parent Opportunity.
    //            Therefore ALL owner checks and updates target Opportunity.OwnerId.
    //
    // Custom Label Required:
    //   Label Name : EOI_Default_Owner_Id
    //   Description: User or Queue Id that is the default owner of Opportunities.
    //                If Opportunity.OwnerId matches this label -> can assign to current user.
    //                If it does not match (and is not the current user) -> blocked.
    //   Example Value: 00Gxx000000xxxxx (Queue Id) or 005xx000000xxxxx (User Id)
    // ═══════════════════════════════════════════════════════════════════════

    /**
     * Search EOI by EOIId__c (custom field) or Name.
     * Runs in without-sharing context to access Opportunity regardless of user permissions.
     * Checks Opportunity.OwnerId for assignment state (EOI has no OwnerId - Master-Detail).
     */
    @AuraEnabled
    public static EOIResultWrapper searchEOI(String searchKey) {
        return new EOISearchContext().doSearch(searchKey);
    }

    /**
     * Assign the related Opportunity to the currently logged-in user.
     * Validates: Opportunity.OwnerId must equal Custom Label value.
     *            No active Sales Order on Opportunity.
     * @return Opportunity Id for LWC redirect.
     */
    @AuraEnabled
    public static Id assignEOIToCurrentUser(Id eoiId) {
        return new EOISearchContext().doAssign(eoiId);
    }

    // ─────────────────────────────────────────────────────────────────────
    // Without-sharing inner class
    // WHY: Sales/Broker users do not have access to Opportunity records.
    //      Running without sharing allows querying Opportunity and
    //      SalesOrder__c without INSUFFICIENT_ACCESS errors.
    // ─────────────────────────────────────────────────────────────────────
    private without sharing class EOISearchContext {

        public EOIResultWrapper doSearch(String searchKey) {
            if (String.isBlank(searchKey)) {
                throw new AuraHandledException('Please enter an EOI ID or Name.');
            }

            String trimmed = searchKey.trim();

            // Query EOI + parent Opportunity (including Opportunity.OwnerId)
            // EOI has NO OwnerId - it is a Master-Detail child
            List<ExpressionofInterest__c> eois = [
                SELECT Id, Name, EOIId__c, Status__c,
                       Opportunity__c,
                       Opportunity__r.Name,
                       Opportunity__r.OwnerId,
                       Opportunity__r.Owner.Name
                FROM ExpressionofInterest__c
                WHERE EOIId__c = :trimmed
                OR Name = :trimmed
                LIMIT 1
            ];

            if (eois.isEmpty()) {
                throw new AuraHandledException(
                    'No EOI found for "' + searchKey + '". Please check the EOI ID or Name and try again.'
                );
            }

            ExpressionofInterest__c eoi = eois[0];
            EOIResultWrapper result = new EOIResultWrapper();
            result.eoiId         = eoi.Id;
            result.eoiName       = eoi.Name;
            result.eoiCustomId   = eoi.EOIId__c;
            result.status        = eoi.Status__c;
            result.opportunityId = eoi.Opportunity__c;
            result.opportunityName = eoi.Opportunity__r != null ? eoi.Opportunity__r.Name : null;

            // Owner comes from Opportunity (EOI has no OwnerId - Master-Detail)
            result.ownerId   = eoi.Opportunity__r != null ? eoi.Opportunity__r.OwnerId   : null;
            result.ownerName = eoi.Opportunity__r != null ? eoi.Opportunity__r.Owner.Name : 'No Opportunity linked';

            // ── Sales Order check ──────────────────────────────────────────
            result.hasSalesOrder = false;
            if (eoi.Opportunity__c != null) {
                Integer soCount = [
                    SELECT COUNT()
                    FROM SalesOrder__c
                    WHERE Opportunity__c = :eoi.Opportunity__c
                    AND Status__c NOT IN ('Cancelled', 'System Cancelled', 'Voided')
                    LIMIT 1
                ];
                result.hasSalesOrder = (soCount > 0);
            }

            // ── Assignment state (based on Opportunity.OwnerId) ────────────
            // 'available'      : Opp owner = Custom Label value -> current user can take it
            // 'already_mine'   : Opp owner = current user -> already assigned
            // 'assigned_other' : Opp owner = someone else -> blocked
            // 'no_opportunity' : EOI has no related Opportunity -> cannot assign
            // IMPORTANT: Cast label to Id before comparing.
            // Custom Label stores a String that may be 15-char.
            // Opportunity.OwnerId is always 18-char.
            // String equality fails; Id equality normalises both sides.
            Id defaultOwnerId;
            try {
                defaultOwnerId = (Id) System.Label.EOI_Default_Owner_Id;
            } catch (Exception labelEx) {
                System.debug('EOI_Default_Owner_Id label missing/invalid: ' + labelEx.getMessage());
            }

            if (eoi.Opportunity__c == null) {
                result.assignmentState = 'no_opportunity';
            } else {
                Id oppOwnerId = eoi.Opportunity__r.OwnerId;
                if (oppOwnerId == UserInfo.getUserId()) {
                    result.assignmentState = 'already_mine';
                } else if (defaultOwnerId != null && oppOwnerId == defaultOwnerId) {
                    result.assignmentState = 'available';
                } else {
                    result.assignmentState = 'assigned_other';
                }
            }

            return result;
        }

        public Id doAssign(Id eoiId) {

            // Query Opportunity fields via parent relationship (EOI has no OwnerId)
            ExpressionofInterest__c eoi = [
                SELECT Id, Opportunity__c,
                       Opportunity__r.OwnerId,
                       Opportunity__r.Owner.Name
                FROM ExpressionofInterest__c
                WHERE Id = :eoiId
                LIMIT 1
            ];

            if (eoi.Opportunity__c == null) {
                throw new AuraHandledException('No Opportunity is linked to this EOI. Cannot assign.');
            }

            // Validate Opportunity.OwnerId (not EOI - it has no OwnerId)
            // Cast label to Id for 15/18-char safe comparison
            Id defaultOwnerId;
            try {
                defaultOwnerId = (Id) System.Label.EOI_Default_Owner_Id;
            } catch (Exception labelEx) {
                throw new AuraHandledException('EOI assignment configuration error. Contact your administrator.');
            }
            if (defaultOwnerId == null) {
                throw new AuraHandledException('EOI assignment configuration error. Contact your administrator.');
            }

            Id oppOwnerId = eoi.Opportunity__r.OwnerId;

            if (oppOwnerId == UserInfo.getUserId()) {
                throw new AuraHandledException('Opportunity is already assigned to you.');
            }
            if (oppOwnerId != defaultOwnerId) {
                throw new AuraHandledException(
                    'Opportunity is already assigned to '
                    + eoi.Opportunity__r.Owner.Name
                    + ' and cannot be reassigned.'
                );
            }

            // Sales Order re-check before assignment
            Integer soCount = [
                SELECT COUNT()
                FROM SalesOrder__c
                WHERE Opportunity__c = :eoi.Opportunity__c
                AND Status__c NOT IN ('Cancelled', 'System Cancelled', 'Voided')
                LIMIT 1
            ];
            if (soCount > 0) {
                throw new AuraHandledException(
                    'A Sales Order exists on this Opportunity. Owner cannot be changed.'
                );
            }

            // Update Opportunity.OwnerId (EOI has no OwnerId - Master-Detail child)
            Opportunity opp = new Opportunity(Id = eoi.Opportunity__c, OwnerId = UserInfo.getUserId());
            update opp;

            return eoi.Opportunity__c;
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // EOI Result Wrapper
    // ─────────────────────────────────────────────────────────────────────
    public class EOIResultWrapper {
        @AuraEnabled public Id      eoiId;
        @AuraEnabled public String  eoiName;
        @AuraEnabled public String  eoiCustomId;       // EOIId__c
        @AuraEnabled public String  status;
        @AuraEnabled public Id      ownerId;           // from Opportunity.OwnerId
        @AuraEnabled public String  ownerName;         // from Opportunity.Owner.Name
        @AuraEnabled public Id      opportunityId;
        @AuraEnabled public String  opportunityName;
        @AuraEnabled public Boolean hasSalesOrder;
        // 'available' | 'already_mine' | 'assigned_other' | 'no_opportunity'
        @AuraEnabled public String  assignmentState;
    }

}