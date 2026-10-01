/**
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 * Class Name      : ModonEgyptAddJointOwnerController
 * Author          : Mirza Baig
 * Created Date    : 02/05/2026
 * Last Modified By: Mirza Baig
 * Last Modified On: 02/05/2026
 *
 * Description     :
 * This controller supports LWC functionality for managing Joint Owners on a Sales Order.
 *
 * Key Responsibilities:
 *  - Fetch available Joint Owners from Opportunity
 *  - Fetch existing Joint Owners already linked to Sales Order
 *  - Clone and create Joint Owner records for Sales Order
 *
 * Notes:
 *  - Ownership validation is handled at LWC level
 *  - This class focuses on data retrieval and DML operations
 *
 * Change History  :
 *  Date          │   Author     │   Change
 * ――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――
 *  02/05/2026  │ Mirza Baig   │ Initial version
 */

public with sharing class ModonEgyptAddJointOwnerController {

    /**
     * Fetches:
     *  1. Joint Owners from Opportunity (not yet linked to Sales Order)
     *  2. Existing Joint Owners already linked to Sales Order
     *
     * @param salesOrderId  Id of Sales Order
     * @return JointOwnerWrapper containing both lists
     */
    @AuraEnabled
    public static JointOwnerWrapper getJointOwners(Id salesOrderId) {

        // Fetch Sales Order with Opportunity reference
        SalesOrder__c so = [
            SELECT Id, Opportunity__c
            FROM SalesOrder__c
            WHERE Id = :salesOrderId
            LIMIT 1
        ];

        // If no Opportunity is linked, return empty wrapper
        if (so.Opportunity__c == null) {
            return new JointOwnerWrapper();
        }

        // Fetch Opportunity-level Joint Owners not yet assigned to Sales Order
        List<JointOwner__c> oppOwners = [
            SELECT Id, OwnershipPercentage__c, JointOwnerAccount__r.Name
            FROM JointOwner__c
            WHERE Opportunity__c = :so.Opportunity__c
            AND SalesOrder__c = NULL
        ];

        // Fetch existing Sales Order Joint Owners
        List<JointOwner__c> soOwners = [
            SELECT Id, OwnershipPercentage__c
            FROM JointOwner__c
            WHERE SalesOrder__c = :salesOrderId
        ];

        return new JointOwnerWrapper(oppOwners, soOwners);
    }

    /**
     * Creates Sales Order Joint Owners by cloning Opportunity Joint Owners
     *
     * Steps:
     *  - Fetch selected Joint Owners
     *  - Clone each record
     *  - Assign SalesOrder__c
     *  - Override OwnershipPercentage__c from input map
     *  - Insert cloned records
     *
     * @param selectedJointOwnerMap  Map<JointOwnerId, OwnershipPercentage>
     * @param salesOrderId           Sales Order Id
     */
    @AuraEnabled
    public static void createSalesOrderJointOwners(
        Map<Id, Decimal> selectedJointOwnerMap,
        Id salesOrderId
    ) {
        try {
            // Fetch selected Joint Owners
            List<JointOwner__c> owners = [
                SELECT Id, JointOwnerAccount__c, Opportunity__c,
                       OwnershipPercentage__c, RelationshipSubType__c,
                       RelationshipType__c, SalesOrder__c
                FROM JointOwner__c
                WHERE Id IN :selectedJointOwnerMap.keySet()
            ];

            // Exit if no records found
            if (owners.isEmpty()) {
                return;
            }

            List<JointOwner__c> clonedJointOwners = new List<JointOwner__c>();

            // Clone and prepare new records
            for (JointOwner__c owner : owners) {
                JointOwner__c clonedOwner = owner.clone(false, true, false, false);

                clonedOwner.SalesOrder__c = salesOrderId;
                clonedOwner.OwnershipPercentage__c = selectedJointOwnerMap.get(owner.Id);

                clonedJointOwners.add(clonedOwner);
            }

            // Insert cloned records
            insert clonedJointOwners;

        } catch (Exception e) {
            // Handle exception for LWC
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Wrapper class to return multiple datasets to LWC
     */
    public class JointOwnerWrapper {

        /** Joint Owners from Opportunity */
        @AuraEnabled public List<JointOwner__c> oppJointOwners;

        /** Existing Joint Owners linked to Sales Order */
        @AuraEnabled public List<JointOwner__c> existingJointOwners;

        /** Default constructor */
        public JointOwnerWrapper() {}

        /**
         * Parameterized constructor
         *
         * @param oppJointOwners       Opportunity Joint Owners
         * @param existingJointOwners  Sales Order Joint Owners
         */
        public JointOwnerWrapper(
            List<JointOwner__c> oppJointOwners,
            List<JointOwner__c> existingJointOwners
        ) {
            this.oppJointOwners = oppJointOwners;
            this.existingJointOwners = existingJointOwners;
        }
    }
}