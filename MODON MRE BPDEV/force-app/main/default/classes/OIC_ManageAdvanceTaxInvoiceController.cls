/**
* @description Builds the Advance Tax Invoice ("ADV_TAX") payload from Invoice__c (Transaction_Type__c
*               = 'Advance Tax') records via OIC_SFDataWrapperGenerator.generateAdvanceTaxCreationWrappers
*               and sends it to Oracle Fusion via OIC_InvoiceExternalService.sendAdvanceTaxInvoice, which
*               sends the JSON payload as-is (no Base64 request/response envelope). Resolves the
*               Allocation__c / Receipt__c fields that are specific to an Advance Tax Invoice by walking
*               Invoice__c.Invoice_Advance__c (the source Invoice) -> Allocation__c -> Receipt__c.
*
* @author      Karunakar Pulkam
* @created     08-25-2026
* ------------------------------------------------------------------------------------
* Version  Author      			Date          Comment
* 1.0      Karunakar Pulkam    08-25-2026    Initial Draft
************************************************************************************/
public class OIC_ManageAdvanceTaxInvoiceController {

    /**
     * Description : Builds the Advance Tax Invoice payload and sends it to Oracle via Fusion API.
     */
    public static void createAdvanceTaxInvoice(Set<String> invoiceIds) {
        String requestBodyString = null, responseStringActual = null;
        HTTPResponse res = null;
        try {
            List<Invoice__c> advanceTaxInvoiceLst = InvoiceSelector.getAdvanceTaxInvoicesByIds(invoiceIds);
            System.debug('Print advanceTaxInvoiceLst '+advanceTaxInvoiceLst);
            if (advanceTaxInvoiceLst.isEmpty()) {
                return;
            }

            // invoiceIds -> Invoice_Advance__c (source Invoice) -> Allocation__c -> Receipt__c
            Map<Id, List<Allocation__c>> allocationsBySourceInvoice = loadAllocations(advanceTaxInvoiceLst);
            System.debug('allocationsBySourceInvoice '+allocationsBySourceInvoice);

            Map<Id, Allocation__c> allocationByInvoiceId = new Map<Id, Allocation__c>();
            for (Invoice__c inv : advanceTaxInvoiceLst) {
                Allocation__c alloc = resolveAllocation(allocationsBySourceInvoice.get(inv.Invoice_Advance__c), inv.InvoiceAmount__c);
                if (alloc != null) {
                    allocationByInvoiceId.put(inv.Id, alloc);
                }
            }

            AdvanceTaxInvoiceWrapper.RequestWrapperList requestWrapperList = new AdvanceTaxInvoiceWrapper.RequestWrapperList();
            requestWrapperList.RequestArray = OIC_SFDataWrapperGenerator.generateAdvanceTaxCreationWrappers(advanceTaxInvoiceLst, allocationByInvoiceId);
            requestBodyString = JSON.serialize(requestWrapperList);
            System.debug('requestBodyString '+requestBodyString);

            res = OIC_InvoiceExternalService.sendAdvanceTaxInvoice(requestBodyString);
            String responseBody = res.getBody();
            responseStringActual = responseBody;

            System.debug('responseBody '+ responseBody);

            if (responseBody != null && responseBody != '') {
                OIC_RequestWrapperController.OICResponseWrapperList respObj =
                    (OIC_RequestWrapperController.OICResponseWrapperList) JSON.deserialize(responseBody, OIC_RequestWrapperController.OICResponseWrapperList.class);
                if (respObj != null) {
                    Set<String> ids = new Set<String>();
                    for (OIC_RequestWrapperController.OICResponseWrapper r : respObj.ResponseArray) {
                        ids.add(r.Sfid);
                    }
                    Map<String, Integer> retryMap = loadRetryMap(ids);
                    Map<String, String> errMap = loadErrorMsgMap();
                    List<Invoice__c> lstToUpdate = new List<Invoice__c>();

                    for (OIC_RequestWrapperController.OICResponseWrapper resp : respObj.ResponseArray) {
                        Invoice__c inv = new Invoice__c(Id = resp.Sfid);
                        if (resp.Status == 'S') {
                            inv.OraclePartyId__c = resp.OracleId;
                            inv.OICIntegrationStatus__c = resp.Status;
                            inv.OICNoOfRetries__c = null;
                            inv.OICIntegrationMessage__c = null;
                        } else if (resp.Status == 'E') {
                            inv.OICIntegrationStatus__c = resp.Status;
                            if (resp.ErrorMsg != null) {
                                inv.OICIntegrationMessage__c = resolveErrMsg(resp.ErrorMsg, errMap);
                            }
                            inv.OICNoOfRetries__c = nextRetry(retryMap, resp.Sfid);
                            logOICError('Advance Tax Invoice API', 'OIC_ManageAdvanceTaxInvoiceController', 'createAdvanceTaxInvoice',
                                requestBodyString, responseStringActual, resp.Sfid, resp.ErrorMsg, res.getStatusCode(), res.getStatus());
                        }
                        lstToUpdate.add(inv);
                    }

                    if (!lstToUpdate.isEmpty()) {
                        update lstToUpdate;
                    }
                }

                LoggerService.save(LoggerService.createAPILog('Advance Tax Invoice API', 'OIC_ManageAdvanceTaxInvoiceController', 'createAdvanceTaxInvoice',
                    requestBodyString, responseStringActual, 'Status Code: ' + res.getStatusCode() + '; Status: ' + res.getStatus(), 'Callout Log'));
            }
        } catch (Exception ex) {
            LoggerService.save(LoggerService.createAPILog('Advance Tax Invoice API', 'OIC_ManageAdvanceTaxInvoiceController', 'createAdvanceTaxInvoice',
                requestBodyString, (res != null ? res.getBody() : null), 'Exception: 500 Error', 'Callout Error Log'));
            LoggerService.save(LoggerService.createApexLog(ex, 'Advance Tax Invoice API', 'OIC_ManageAdvanceTaxInvoiceController', 'createAdvanceTaxInvoice'));
        }
    }

    /**
     * Description : Collects the source Invoices behind the Advance Tax Invoices (Invoice_Advance__c) and
     *               returns their Allocation__c records (with Receipt__c) grouped by source Invoice Id.
     */
    private static Map<Id, List<Allocation__c>> loadAllocations(List<Invoice__c> advanceTaxInvoiceLst) {
        Set<Id> sourceInvoiceIds = new Set<Id>();
        for (Invoice__c inv : advanceTaxInvoiceLst) {
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

    private static Map<String, Integer> loadRetryMap(Set<String> ids) {
        Map<String, Integer> m = new Map<String, Integer>();
        if (ids == null || ids.isEmpty()) return m;
        for (Invoice__c r : [SELECT Id, OICNoOfRetries__c FROM Invoice__c WHERE Id IN :ids AND OICNoOfRetries__c != null]) {
            m.put(r.Id, Integer.valueOf(r.OICNoOfRetries__c));
        }
        return m;
    }

    private static Integer nextRetry(Map<String, Integer> m, String sfid) {
        return (m != null && m.containsKey(sfid) && m.get(sfid) != null) ? m.get(sfid) + 1 : 1;
    }

    private static void logOICError(String process, String cls, String method,
                                     String reqBody, String respBody,
                                     String sfid, String oicMsg,
                                     Integer httpCode, String httpStatus) {
        String detail = 'OIC Error | SFID: ' + sfid
                      + ' | OIC Msg: ' + oicMsg
                      + ' | HTTP: ' + httpCode + ' ' + httpStatus;
        LoggerService.save(LoggerService.createAPILog(process, cls, method, reqBody, respBody, detail, 'OIC Error Log'));
    }
}