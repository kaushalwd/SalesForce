/**
 * @description  Apex controller for the CancellationRetry LWC.
 *               Reads SR_Sync_Ids__c from the ServiceRequest__c, parses the
 *               JSON payload, and launches EBSCancellationBatch for any IDs
 *               that are present in the stored lists.
 *
 * @author       Manoj
 * @date         18-04-2026
 *
 *  *********************************************************************************
*  Version  Author          Date          Notes
** 1.0      Manoj           18-04-2026    Initial
*  2.0		Manoj			20-05-2026	  Add Other record types
*  3.0		Manoj			13-05-2026	  Add Error message and sync
**********************************************************************************/
public with sharing class CancellationBatchController {

    // ── Inner class mirrors the SR_Sync_Ids__c JSON structure ─────────
    private class SyncIdsPayload {
        public String       soId;
        public List<String> invoiceIds;
        public List<String> receiptIds;
        public List<String> allocationIds;
    }

    // ── Result wrapper returned to the LWC ────────────────────────────
    public class BatchLaunchResult {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String  message;
        @AuraEnabled public String  jobId;
        @AuraEnabled public Integer invoiceCount;
        @AuraEnabled public Integer receiptCount;
        @AuraEnabled public Integer allocationCount;
    }

    // ── Status wrapper used by the polling method ─────────────────────
    public class SyncStatusResult {
        @AuraEnabled public String  syncStatus;  // raw Sync_Status__c value
        @AuraEnabled public Boolean isTerminal;  // true when batch is done
    }

    /**
     * @description  Lightweight poll endpoint called by the LWC every few seconds.
     */
    @AuraEnabled
    public static SyncStatusResult getSyncStatus(Id serviceRequestId) {
        SyncStatusResult res = new SyncStatusResult();
        try {
            ServiceRequest__c sr = [
                SELECT Sync_Status__c
                FROM   ServiceRequest__c
                WHERE  Id = :serviceRequestId
                LIMIT  1
            ];
            res.syncStatus = sr.Sync_Status__c;
            res.isTerminal = (sr.Sync_Status__c == 'Fully Completed' || sr.Sync_Status__c == 'Partially Completed');
        } catch (Exception e) {
            res.syncStatus = 'Error: ' + e.getMessage();
            res.isTerminal = true;
        }
        return res;
    }

    /**
     * @description  Called by the LWC button. Reads SR_Sync_Ids__c,
     *               validates the payload, then enqueues the appropriate batch
     *               based on RecordType.
     */
    @AuraEnabled
    public static BatchLaunchResult launchCancellationBatch(Id serviceRequestId) {

        BatchLaunchResult result = new BatchLaunchResult();

        try {
            // ── 1. Query the ServiceRequest__c ────────────────────────
            // 3.0
            List<ServiceRequest__c> srList = [
                SELECT Id, SR_Sync_Ids__c, Sync_Status__c, RecordType.Name,Transferred_Sales_Order__c,Transferred_Sales_Order__r.CustomerOraclePartyId__c
                FROM   ServiceRequest__c
                WHERE  Id = :serviceRequestId
                LIMIT  1
            ];

            if (srList.isEmpty()) {
                result.success = false;
                result.message = 'ServiceRequest record not found for Id: ' + serviceRequestId;
                return result;
            }

            ServiceRequest__c sr = srList[0];

            // ── 2. Validate the payload field ─────────────────────────
            if (String.isBlank(sr.SR_Sync_Ids__c)) {
                result.success = false;
                result.message = 'SR_Sync_Ids__c is empty — nothing to process.';
                return result;
            }else if (sr.Transferred_Sales_Order__r.CustomerOraclePartyId__c == null) { //3.0
                result.success = false;
                result.message = 'This account hasnot been synced with Oracle yet. Please complete the sync first, then try again.';
                return result;
            }
            // ── 3. Parse JSON ─────────────────────────────────────────
            SyncIdsPayload payload;
            try {
                payload = (SyncIdsPayload) JSON.deserialize(
                    sr.SR_Sync_Ids__c, SyncIdsPayload.class
                );
            } catch (Exception parseEx) {
                result.success = false;
                result.message = 'Failed to parse SR_Sync_Ids__c JSON: ' + parseEx.getMessage();
                return result;
            }

            // ── 4. Normalise lists (null → empty) ─────────────────────
            List<String> invoiceIds    = payload.invoiceIds    != null ? payload.invoiceIds    : new List<String>();
            List<String> receiptIds    = payload.receiptIds    != null ? payload.receiptIds    : new List<String>();
            List<String> allocationIds = payload.allocationIds != null ? payload.allocationIds : new List<String>();
			//Start 2.0
            String  jobId          = null;
            Integer allocationCount = 0;
            String  recordTypeName  = sr.RecordType.Name;

            // ── 5. Route to the correct batch by RecordType ───────────
            if (recordTypeName == 'Pre Unit Cancellation') {

                if (invoiceIds.isEmpty() && receiptIds.isEmpty() && allocationIds.isEmpty()) {
                    result.success = false;
                    result.message = 'All ID lists in SR_Sync_Ids__c are empty — nothing to process.';
                    return result;
                }

                EBSCancellationBatch batch = new EBSCancellationBatch(
                    serviceRequestId,
                    invoiceIds,
                    receiptIds,
                    allocationIds
                );
                jobId           = Database.executeBatch(batch, 1);
                allocationCount = allocationIds.size();

            } else if (
                recordTypeName == 'Property Transfer OffPlan' ||
                recordTypeName == 'Property Transfer Title Deed (Commercial)' ||
                recordTypeName == 'Property Transfer Title Deed'
            ) {
                // Transfer batch does not use allocationIds — intentionally excluded
                if (invoiceIds.isEmpty() && receiptIds.isEmpty()) {
                    result.success = false;
                    result.message = 'Invoice and receipt ID lists in SR_Sync_Ids__c are both empty — nothing to process.';
                    return result;
                }

                EBSTransferBatchV1 batch = new EBSTransferBatchV1(
                    serviceRequestId,
                    invoiceIds,
                    receiptIds
                );
                jobId           = Database.executeBatch(batch, 1);
                allocationCount = 0; // Transfer has no allocations

            } else {
                // ── FIX: Unsupported record type — return explicit error instead of false success
                result.success = false;
                result.message = 'Unsupported RecordType for batch launch: ' + recordTypeName;
                return result;
            }
			//End 2.0
            // ── 6. Build success result ───────────────────────────────
            result.success         = true;
            result.jobId           = jobId;
            result.invoiceCount    = invoiceIds.size();
            result.receiptCount    = receiptIds.size();
            result.allocationCount = allocationCount;
            result.message         =
                'Batch launched successfully. '
                + 'Processing ' + invoiceIds.size() + ' invoice(s), '
                + receiptIds.size()    + ' receipt(s), '
                + allocationCount      + ' allocation(s).';

        } catch (Exception e) {
            result.success = false;
            result.message = 'Unexpected error: ' + e.getMessage();
        }

        return result;
    }
    //start 3.0
    /**
     * @description  Polls AsyncApexJob to check if the batch has finished.
     */
    @AuraEnabled
    public static Map<String, String> getBatchJobStatus(Id jobId) {
        Map<String, String> result = new Map<String, String>();
        try {
            AsyncApexJob job = [
                SELECT Status, ExtendedStatus
                FROM   AsyncApexJob
                WHERE  Id = :jobId
                LIMIT  1
            ];
            result.put('status',         job.Status);
            result.put('extendedStatus', job.ExtendedStatus ?? '');
            // Terminal states for a batch job
            Boolean isTerminal = (
                job.Status == 'Completed' ||
                job.Status == 'Failed'    ||
                job.Status == 'Aborted'
            );
            result.put('isTerminal', String.valueOf(isTerminal));
        } catch (Exception e) {
            result.put('status',     'Error');
            result.put('isTerminal', 'true');
            result.put('extendedStatus', e.getMessage());
        }
        return result;
    } //End 3.0
}