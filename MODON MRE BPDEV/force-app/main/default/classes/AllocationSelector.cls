/**********************************************************************************************************************
* Name               : AllocationSelector
* Description        : Selector class for the Allocation__c object. Centralizes SOQL used by the
*                      Oracle-Salesforce (Fusion) integration classes.
* Usage              : Called from OIC_ManageAdvanceTaxInvoiceController and OIC_AdvanceTaxCancellationService to
*                      resolve the Allocation__c / Receipt__c records behind an Advance Tax Invoice.
* Created By         : MODON IT
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           Karunakar Pulkam            26 Aug 2026     Initial Draft
***********************************************************************************************************************/
public class AllocationSelector {

    private static final String ALLOCATION_STATUS_APPLIED = 'Applied';
    private static final String RECEIPT_STATUS_CLEARED = 'Cleared';

    // Base Allocation__c fields
    private static final String BASE_FIELDS =
        'Id, Name, Invoice__c, Receipt__c, AllocationAmount__c, Status__c';

    // Receipt fields
    private static final String RECEIPT_FIELDS =
        'Receipt__r.Name, Receipt__r.OraclePartyId__c, Receipt__r.Status__c';

    /**
     * Description : Returns the Allocation__c records (with their Receipt__c) raised against the supplied
     *               Invoice__c Ids. Used to source AllocAmount / ReceiptSFID / FusionReceiptID for the
     *               Advance Tax Invoice payload.
     * @param invoiceIds Set of Invoice__c Ids the allocations point to (Allocation__c.Invoice__c).
     * @return List<Allocation__c> allocations that carry a Receipt.
     */
    public static List<Allocation__c> getAllocationsByInvoiceIds(Set<Id> invoiceIds) {
        if (invoiceIds == null || invoiceIds.isEmpty()) {
            return new List<Allocation__c>();
        }

        String FIELD_LIST = String.join(new List<String>{ BASE_FIELDS, RECEIPT_FIELDS }, ', ');

        String query = 'SELECT ' + FIELD_LIST
                     + ' FROM Allocation__c'
                     + ' WHERE Invoice__c IN :invoiceIds'
                     + ' AND Status__c = :ALLOCATION_STATUS_APPLIED'
                     + ' AND Receipt__c != null'
                     + ' AND Receipt__r.Status__c = :RECEIPT_STATUS_CLEARED';
        System.debug('Print Query ' + query);

        return (List<Allocation__c>) Database.query(query);

        // return (List<Allocation__c>) Database.queryWithBinds(
        //     query,
        //     new Map<String, Object>{ 'invoiceIds' => invoiceIds },
        //     AccessLevel.SYSTEM_MODE
        // );
    }
}