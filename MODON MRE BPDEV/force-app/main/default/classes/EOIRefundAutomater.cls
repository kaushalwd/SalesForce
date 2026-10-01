/**********************************************************************************************************************
 * Name               : EOIRefundAutomater
 * Description        : Business Process Automation handler for EOI Refund Approval.
 *                      When the final step ('CCO Approval') is completed, it retrieves all EOIs tagged to the
 *                      approved Business Process, fetches the uploaded Management MEMO document, and launches
 *                      CaseInsertEOIRefundTargetBatch (batch size 1) to create 1 Case per EOI with all eligible
 *                      cleared receipts and the Management MEMO document linked.
 * Usage              : Invoked by BP Framework via Business_Process_Approval_Automations__mdt
 * Created By         : Sivannarayana Peddireddi
 * --------------------------------------------------------------------------------------------------------------------
 * Version       Author                          Date            Comment
 * 1.0           Sivannarayana Peddireddi        07-09-2026      Initial Draft
 * 2.0           pprajapati@horizontal.com       08-09-2026      Query Management MEMO ContentDocumentLink from Business
 *                                                               Process and pass to CaseInsertEOIRefundTargetBatch
 **********************************************************************************************************************/
public without sharing class EOIRefundAutomater implements BusinessProcessAutomation {

    public void executeAutomation(BusinessProcessAutomationInput input) {

        Set<Id> businessProcessIds = new Set<Id>();

        for (Business_Process_Step__c step : input.steps) {

            switch on step.Name {

                when 'CCO Approval' {
                    if (step.Status__c == 'Completed' && step.Business_Process__c != null) {
                        businessProcessIds.add(step.Business_Process__c);
                    }
                }
            }
        }

        if (!businessProcessIds.isEmpty()) {
            processCCOApproval(businessProcessIds);
        }
    }

    // Groups every not-yet-refunded EOI by the Business Process it belongs to, then
    // launches CaseInsertEOIRefundTargetBatch (batch size 1, one Case created per EOI)
    // once per Business Process whose CCO Approval step just completed.
    private void processCCOApproval(Set<Id> businessProcessIds) {

        Map<Id, List<Id>> eoiIdsByBusinessProcess = new Map<Id, List<Id>>();

        for (Expressionofinterest__c eoi : [
            SELECT Id, Business_Process__c
            FROM Expressionofinterest__c
            WHERE Business_Process__c IN :businessProcessIds
            AND Case__c = null
        ]) {
            if (!eoiIdsByBusinessProcess.containsKey(eoi.Business_Process__c)) {
                eoiIdsByBusinessProcess.put(eoi.Business_Process__c, new List<Id>());
            }
            eoiIdsByBusinessProcess.get(eoi.Business_Process__c).add(eoi.Id);
        }

        // Version 2.0 [pprajapati@horizontal.com - 08 Sept 2026]: Fetch ContentDocumentLink attached to Business_Process__c
        Map<Id, Id> bpToContentDocId = new Map<Id, Id>();
        for (ContentDocumentLink cdl : [
            SELECT ContentDocumentId, LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :businessProcessIds
        ]) {
            bpToContentDocId.put(cdl.LinkedEntityId, cdl.ContentDocumentId);
        }

        for (Id bpId : eoiIdsByBusinessProcess.keySet()) {
            List<Id> eoiIds = eoiIdsByBusinessProcess.get(bpId);
            if (!eoiIds.isEmpty()) {
                Id contentDocId = bpToContentDocId.get(bpId);
                Database.executeBatch(new CaseInsertEOIRefundTargetBatch(eoiIds, new List<Id>(), contentDocId), 1);
            }
        }
    }
}