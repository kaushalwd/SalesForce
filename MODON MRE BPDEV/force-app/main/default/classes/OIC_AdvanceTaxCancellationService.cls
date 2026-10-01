/**********************************************************************************************************************
* Name               : OIC_AdvanceTaxCancellationService
* Description        : Cancels the Advance Tax Invoices raised against an installment Invoice before that
*                      installment is re-sent to Oracle Fusion.
*
*                      When createInstallment processes an installment that already has an Advance Tax Invoice
*                      synced to Oracle (Transaction_Type__c = 'Advance Tax', Invoice_Advance__c = the
*                      installment, OraclePartyId__c != null), that Advance Tax Invoice must be cancelled in
*                      Oracle first. Only installments whose cancellation came back Successful are allowed to
*                      continue; the rest are held back for the next run.
*
*                      IMPORTANT - no DML is performed here. Apex forbids a callout after uncommitted DML
*                      ("You have uncommitted work pending"), and createInstallment issues a second callout
*                      straight after this one. The Invoice__c updates and Logger__c records are therefore
*                      staged on CancellationResult and committed by the caller once every callout is done.
*
* Usage              : Called from OIC_ManageSalesforceDataController.createInstallment.
* Created By         : Karunakar
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           Karunakar                   26 Aug 2026     Initial Draft
* 1.1           Karunakar                   28 Aug 2026     No Base64 envelope - request/response are plain JSON,
*                                                            same credential as Advance Tax creation
* 1.2           Karunakar                   30 Aug 2026     Resolve Allocation__c / Receipt__c behind each Advance Tax
*                                                            Invoice so the cancellation payload carries the Receipt fields
***********************************************************************************************************************/
public without sharing class OIC_AdvanceTaxCancellationService {

    private static final String PROCESS_NAME = 'Advance Tax Cancellation API';
    private static final String CLASS_NAME   = 'OIC_AdvanceTaxCancellationService';
    private static final String METHOD_NAME  = 'cancelAdvanceTaxInvoices';

    /**
     * Description : Outcome of the Advance Tax cancellation phase. Carries the installments that must NOT be
     *               sent to Oracle, plus the DML the caller has to commit once all callouts are finished.
     */
    public class CancellationResult {
        /** Source installment Invoice Ids whose Advance Tax cancellation did not succeed. */
        public Set<Id> blockedInstallmentIds = new Set<Id>();
        /** Advance Tax Invoice__c records to update (IsCancelled__c and OIC status fields). */
        public List<Invoice__c> invoicesToUpdate = new List<Invoice__c>();
        /** Logger__c records staged for the caller to save. */
        public List<Logger__c> logsToSave = new List<Logger__c>();

        /** True when there was no Advance Tax Invoice to cancel, i.e. the normal flow applies untouched. */
        public Boolean isEmpty() {
            return blockedInstallmentIds.isEmpty() && invoicesToUpdate.isEmpty() && logsToSave.isEmpty();
        }

        /**
         * Description : Commits the staged Invoice updates and logs. Must be called only after every callout
         *               in the transaction has completed.
         *               Failures are swallowed deliberately: this runs from createInstallment's finally block,
         *               and letting it throw there would roll back the installment updates Oracle has already
         *               accepted.
         */
        public void commitStagedWork() {
            try {
                if (!invoicesToUpdate.isEmpty()) update invoicesToUpdate;
            } catch (Exception ex) {
                System.debug('>>>> Advance Tax cancellation update failed: ' + ex.getMessage());
                logsToSave.add(LoggerService.createApexLog(ex, PROCESS_NAME, CLASS_NAME, 'commitStagedWork'));
            }
            try {
                if (!logsToSave.isEmpty()) LoggerService.save(logsToSave);
            } catch (Exception ex) {
                System.debug('>>>> Advance Tax cancellation logging failed: ' + ex.getMessage());
            }
        }
    }

    /**
     * Description : Finds the Advance Tax Invoices raised against the supplied installments that are already
     *               synced to Oracle, sends them to Oracle as a cancellation, and reports which installments
     *               must be held back. Returns an empty result (and makes no callout at all) when there is
     *               nothing to cancel, so the normal installment flow runs untouched.
     * @param installmentIds Ids of the installment Invoices being processed by createInstallment.
     * @return CancellationResult carrying the blocked installments and the staged DML.
     */
    public static CancellationResult cancelAdvanceTaxInvoices(Set<String> installmentIds) {
        CancellationResult result = new CancellationResult();

        List<Invoice__c> advanceTaxInvoices;
        try {
            advanceTaxInvoices = InvoiceSelector.getAdvanceTaxInvoicesToCancel(installmentIds);
        } catch (Exception ex) {
            // Cannot tell which installments are affected - let the normal flow proceed and log it.
            result.logsToSave.add(LoggerService.createApexLog(ex, PROCESS_NAME, CLASS_NAME, METHOD_NAME));
            return result;
        }

        System.debug('advanceTaxInvoices for Cancellation'+ advanceTaxInvoices);

        // No Advance Tax Invoice to cancel -> normal flow, no callout
        if (advanceTaxInvoices == null || advanceTaxInvoices.isEmpty()) return result;

        // Map each Advance Tax Invoice back to the installment it was raised against
        Map<Id, Id> advTaxToInstallment = new Map<Id, Id>();
        for (Invoice__c inv : advanceTaxInvoices) {
            advTaxToInstallment.put(inv.Id, inv.Invoice_Advance__c);
        }

        // advanceTaxInvoices -> Invoice_Advance__c (source Invoice) -> Allocation__c -> Receipt__c.
        // Enrichment only (ReceiptSFID / FusionReceiptID / AllocAmount / UnAllocAmount) - a failure here
        // must not stop the cancellation, so it is logged and the payload goes out without those fields.
        Map<Id, Allocation__c> allocationByInvoiceId = new Map<Id, Allocation__c>();
        try {
            Map<Id, List<Allocation__c>> allocationsBySourceInvoice = loadAllocations(advanceTaxInvoices);
            for (Invoice__c inv : advanceTaxInvoices) {
                Allocation__c alloc = resolveAllocation(allocationsBySourceInvoice.get(inv.Invoice_Advance__c), inv.InvoiceAmount__c);
                if (alloc != null) {
                    allocationByInvoiceId.put(inv.Id, alloc);
                }
            }
        } catch (Exception ex) {
            result.logsToSave.add(LoggerService.createApexLog(ex, PROCESS_NAME, CLASS_NAME, METHOD_NAME));
        }

        String requestBodyString = null, responseStringActual = null;
        HTTPResponse res = null;
        try {
            AdvanceTaxInvoiceWrapper.RequestWrapperList requestWrapperList = new AdvanceTaxInvoiceWrapper.RequestWrapperList();
            requestWrapperList.RequestArray = OIC_SFDataWrapperGenerator.generateAdvanceTaxCancellationWrappers(advanceTaxInvoices, allocationByInvoiceId);
            requestBodyString = JSON.serialize(requestWrapperList);
            System.debug('advanceTaxCancelRequest==>' + requestBodyString);

            res = OIC_InvoiceExternalService.sendAdvanceTaxCancellation(requestBodyString);
            responseStringActual = (res != null) ? res.getBody() : null;
            System.debug('advanceTaxCancelResponse==>' + responseStringActual);

            OIC_RequestWrapperController.OICResponseWrapperList respObj = null;
            if (responseStringActual != null) {
                respObj = (OIC_RequestWrapperController.OICResponseWrapperList)
                    JSON.deserialize(responseStringActual, OIC_RequestWrapperController.OICResponseWrapperList.class);
            }

            if (respObj == null || respObj.ResponseArray == null || respObj.ResponseArray.isEmpty()) {
                // Nothing came back - treat every cancellation as failed so no installment slips through
                blockAll(result, advTaxToInstallment.values());
                result.logsToSave.add(LoggerService.createAPILog(PROCESS_NAME, CLASS_NAME, METHOD_NAME,
                    requestBodyString, responseStringActual,
                    'No response received; all Advance Tax cancellations treated as failed', 'Callout Error Log'));
                return result;
            }

            Map<String, String> errMap = loadErrorMsgMap();
            Set<Id> respondedIds = new Set<Id>();

            for (OIC_RequestWrapperController.OICResponseWrapper resp : respObj.ResponseArray) {
                if (resp.Sfid == null) continue;
                Id advTaxId = (Id) resp.Sfid;
                respondedIds.add(advTaxId);

                Invoice__c advTaxInv = new Invoice__c(Id = advTaxId);
                if (resp.Status == 'S') {
                    // Cancelled in Oracle - now mark it cancelled in Salesforce
                    advTaxInv.IsCancelled__c = true;
                    advTaxInv.Oracle_Credit_Memo_Id__c = resp.OracleId;
                    advTaxInv.OICIntegrationStatus__c = resp.Status;
                    advTaxInv.OICNoOfRetries__c = null;
                    advTaxInv.OICIntegrationMessage__c = null;
                } else {
                    advTaxInv.OICIntegrationStatus__c = 'E';
                    if (resp.ErrorMsg != null) {
                        advTaxInv.OICIntegrationMessage__c = resolveErrMsg(resp.ErrorMsg, errMap);
                    }
                    // Hold back the installment behind this Advance Tax Invoice
                    if (advTaxToInstallment.get(advTaxId) != null) {
                        result.blockedInstallmentIds.add(advTaxToInstallment.get(advTaxId));
                    }
                    result.logsToSave.add(LoggerService.createAPILog(PROCESS_NAME, CLASS_NAME, METHOD_NAME,
                        requestBodyString, responseStringActual,
                        'OIC Error | SFID: ' + resp.Sfid + ' | OIC Msg: ' + resp.ErrorMsg
                            + ' | HTTP: ' + res.getStatusCode() + ' ' + res.getStatus(), 'OIC Error Log'));
                }
                result.invoicesToUpdate.add(advTaxInv);
            }

            // An Advance Tax Invoice Oracle never answered for is not confirmed cancelled - block it too
            for (Id advTaxId : advTaxToInstallment.keySet()) {
                if (!respondedIds.contains(advTaxId) && advTaxToInstallment.get(advTaxId) != null) {
                    result.blockedInstallmentIds.add(advTaxToInstallment.get(advTaxId));
                }
            }

            result.logsToSave.add(LoggerService.createAPILog(PROCESS_NAME, CLASS_NAME, METHOD_NAME,
                requestBodyString, responseStringActual,
                'Status Code: ' + res.getStatusCode() + '; Status: ' + res.getStatus(), 'Callout Log'));

        } catch (Exception ex) {
            // Callout or parsing blew up - nothing is confirmed cancelled, so block every affected installment
            blockAll(result, advTaxToInstallment.values());
            result.invoicesToUpdate.clear();
            result.logsToSave.add(LoggerService.createAPILog(PROCESS_NAME, CLASS_NAME, METHOD_NAME,
                requestBodyString, (res != null ? res.getBody() : null),
                'Exception: ' + '500 Error', 'Callout Error Log'));
            result.logsToSave.add(LoggerService.createApexLog(ex, PROCESS_NAME, CLASS_NAME, METHOD_NAME));
        }
        return result;
    }

    /**
     * Description : Marks every supplied installment as blocked.
     */
    private static void blockAll(CancellationResult result, List<Id> installmentIds) {
        for (Id instId : installmentIds) {
            if (instId != null) result.blockedInstallmentIds.add(instId);
        }
    }

    /**
     * Description : Collects the source Invoices behind the Advance Tax Invoices (Invoice_Advance__c) and
     *               returns their Allocation__c records (with Receipt__c) grouped by source Invoice Id.
     *               Mirrors OIC_ManageAdvanceTaxInvoiceController.loadAllocations.
     */
    private static Map<Id, List<Allocation__c>> loadAllocations(List<Invoice__c> advanceTaxInvoices) {
        Set<Id> sourceInvoiceIds = new Set<Id>();
        for (Invoice__c inv : advanceTaxInvoices) {
            if (inv.Invoice_Advance__c != null) {
                sourceInvoiceIds.add(inv.Invoice_Advance__c);
            }
        }

        Map<Id, List<Allocation__c>> m = new Map<Id, List<Allocation__c>>();
        for (Allocation__c alloc : AllocationSelector.getAllocationsByInvoiceIds(sourceInvoiceIds)) {
            if (!m.containsKey(alloc.Invoice__c)) {
                m.put(alloc.Invoice__c, new List<Allocation__c>());
            }
            m.get(alloc.Invoice__c).add(alloc);
        }
        return m;
    }

    /**
     * Description : Picks the Allocation the Advance Tax Invoice was raised from. A source Invoice can carry
     *               several allocations, so the one whose Allocated Amount equals the Advance Tax Invoice
     *               amount wins; otherwise the first allocation is used.
     *               Mirrors OIC_ManageAdvanceTaxInvoiceController.resolveAllocation.
     */
    private static Allocation__c resolveAllocation(List<Allocation__c> allocs, Decimal invoiceAmount) {
        if (allocs == null || allocs.isEmpty()) return null;
        if (invoiceAmount != null) {
            for (Allocation__c alloc : allocs) {
                if (alloc.AllocationAmount__c != null && alloc.AllocationAmount__c == invoiceAmount) {
                    return alloc;
                }
            }
        }
        return allocs[0];
    }

    private static Map<String, String> loadErrorMsgMap() {
        Map<String, String> m = new Map<String, String>();
        for (Integration_Error_Messages__mdt r : [
            SELECT System_Error_Msg__c, User_Error_Msg__c
            FROM Integration_Error_Messages__mdt
            WHERE IsActive__c = true AND Application_Type__c = 'EBS'
        ]) {
            m.put(r.System_Error_Msg__c, r.User_Error_Msg__c);
        }
        return m;
    }

    private static String resolveErrMsg(String sysMsg, Map<String, String> errMap) {
        String u = UserErrorMessage.getUserErrorMessage(sysMsg, errMap);
        if (u == null) return 'Required information is not updated in Salesforce. Please contact support, ' + sysMsg;
        if (sysMsg != null && sysMsg.contains('Unknown integration error')) return 'Required information is not updated in Salesforce. Please contact support';
        return u;
    }
}