/**
* @description Service class responsible for sending installment wrappers to the
*              Modon Fusion OIC integration and processing the response back onto
*              Invoice__c records.
*
* @author      Modon IT
* @created     30-07-2026
* ------------------------------------------------------------------------------------
* Version  Author      Date          Comment
* 1.0      Modon IT    30-07-2026    Initial Draft
************************************************************************************/
public class OIC_InstallmentExtService {
    
    private static final String  NAMED_CREDENTIAL   = 'ModonFusionInstallmentAPI2';
    private static final Integer CALLOUT_TIMEOUT_MS = 120000;
    private static final String  SOBJECT_NAME       = 'Invoice__c';
    private static final String  LOG_SOURCE         = 'Invoice API';
    private static final String  LOG_CLASS          = 'OIC_InstallmentExtService'; // FIX #5
    private static final String  LOG_METHOD         = 'processInstallments';
    
    public class InstallmentCalloutResult {
        public Boolean          isSuccess         = false;
        public Integer          statusCode;
        public String           statusText;
        public String           requestPayload;
        public String           responsePayload;
        
        public List<Invoice__c> processedInvoices = new List<Invoice__c>();
    }
    
    /**
* Sends the supplied installment wrappers to the OIC endpoint and updates
* the related Invoice__c records with the integration outcome.
*
* @param installmentWrapLst wrappers to send; each wrapper's Sfid must be an Invoice__c Id.
* @return InstallmentCalloutResult describing the outcome.
*/
    public static InstallmentCalloutResult processInstallments(
        List<OIC_RequestWrapperController.InstallmentWrapper> installmentWrapLst, Map<Id,Id> invoiceToReceiptMap) {
            
            InstallmentCalloutResult result = new InstallmentCalloutResult();
            
            if (installmentWrapLst == null || installmentWrapLst.isEmpty()) {
                return result;
            }
            
            Map<String, Boolean> invCrdMap = buildCreditMemoMap(installmentWrapLst);
            
            String requestPayload  = buildRequestPayload(installmentWrapLst);
            result.requestPayload  = requestPayload;
            
            HttpResponse res        = sendCallout(requestPayload);
            result.statusCode       = res.getStatusCode();
            result.statusText       = res.getStatus();
            
            String responsePayload  = res.getBody();
            result.responsePayload  = responsePayload;
            
            if (String.isBlank(responsePayload)) {
                return result;
            }
            
            String actualResponse = decodeResponse(responsePayload);
            if (String.isBlank(actualResponse)) {
                return result;
            }
            
            OIC_RequestWrapperController.OICResponseWrapperList respObj =
                (OIC_RequestWrapperController.OICResponseWrapperList) JSON.deserialize(
                    actualResponse, OIC_RequestWrapperController.OICResponseWrapperList.class);
            
            if (respObj == null || respObj.ResponseArray == null || respObj.ResponseArray.isEmpty()) {
                return result;
            }
            
            List<Invoice__c> invoicesToUpdate = buildInvoiceUpdates(respObj, invCrdMap, requestPayload, actualResponse, res, invoiceToReceiptMap);
            
            if (!invoicesToUpdate.isEmpty()) {
                update invoicesToUpdate;
            }
            
            result.processedInvoices = invoicesToUpdate;
            result.isSuccess         = true;
            return result;
        }
    
    // ─── Private helpers ──────────────────────────────────────────────────────
    
    private static Map<String, Boolean> buildCreditMemoMap(
        List<OIC_RequestWrapperController.InstallmentWrapper> installmentWrapLst) {
            
            Map<String, Boolean> invCrdMap = new Map<String, Boolean>();
            for (OIC_RequestWrapperController.InstallmentWrapper iw : installmentWrapLst) {
                if (iw != null && 'Y'.equalsIgnoreCase(iw.CreditMemoFlag) && iw.Sfid != null) {
                    invCrdMap.put(iw.Sfid, true);
                }
            }
            return invCrdMap;
        }
    
    private static String buildRequestPayload(
        List<OIC_RequestWrapperController.InstallmentWrapper> installmentWrapLst) {
            
            OIC_RequestWrapperController.InstallmentWrapperLst installmentWrapperList =
                new OIC_RequestWrapperController.InstallmentWrapperLst();
            installmentWrapperList.RequestArray = installmentWrapLst;
            
            String installmentWrapString = JSON.serialize(installmentWrapperList);
            System.debug('JSON.serialize(installmentWrapString)==>' + installmentWrapString);
            return installmentWrapString;
        }
    
    private static HttpResponse sendCallout(String installmentWrapString) {
        HttpRequest req = OIC_CredentialsController.getCredentials(NAMED_CREDENTIAL);
        req.setTimeout(CALLOUT_TIMEOUT_MS);
        
        String base64String = EncodingUtil.base64Encode(Blob.valueOf(installmentWrapString));
        
        OIC_RequestWrapperController.Base64Wrapper wrapper =
            new OIC_RequestWrapperController.Base64Wrapper();
        wrapper.Base64RequestPayload = base64String;
        
        req.setBody(JSON.serialize(wrapper));
        req.setHeader('Accept', 'application/json');
        return new Http().send(req);
    }
    
    private static String decodeResponse(String installmentResponseBody) {
        OIC_RequestWrapperController.Base64ResponseWrapper b64 =
            (OIC_RequestWrapperController.Base64ResponseWrapper) JSON.deserialize(
                installmentResponseBody,
                OIC_RequestWrapperController.Base64ResponseWrapper.class);
        
        if (b64 == null || String.isBlank(b64.Base64Response)) {
            return null;
        }
        Blob decoded = EncodingUtil.base64Decode(b64.Base64Response);
        return decoded == null ? null : decoded.toString();
    }
    
    private static List<Invoice__c> buildInvoiceUpdates(
        OIC_RequestWrapperController.OICResponseWrapperList respObj,
        Map<String, Boolean> invCrdMap,
        String requestPayload,
        String responsePayload,
        HttpResponse res, Map<Id,Id> invoiceToReceiptMap) {
            
            Set<String> ids = new Set<String>();
            for (OIC_RequestWrapperController.OICResponseWrapper r : respObj.ResponseArray) {
                if (r != null && r.Sfid != null) {
                    ids.add(r.Sfid);
                }
            }
            
            Map<String, Integer> retryMap = loadRetryMap(SOBJECT_NAME, ids);
            Map<String, String>  errMap   = loadErrorMsgMap();
            
            List<Invoice__c> invoicesToUpdate = new List<Invoice__c>();
            List<Receipt__c> receiptsToUpdate = new List<Receipt__c>();
            
            
            for (OIC_RequestWrapperController.OICResponseWrapper resp : respObj.ResponseArray) {
                if (resp == null || resp.Sfid == null) continue;
                
                Invoice__c inv = new Invoice__c(Id = resp.Sfid);
                Id receiptId = invoiceToReceiptMap.get(resp.Sfid);
                Receipt__c receipt = receiptId != null
                    ? new Receipt__c(Id = receiptId)
                    : null;
                
                Boolean isCreditMemo = invCrdMap.containsKey(String.valueOf(resp.Sfid));
                
                if (resp.Status == 'S') {
                    if (isCreditMemo) {
                        inv.Oracle_Credit_Memo_Id__c = resp.OracleId;
                    } else {
                        inv.OraclePartyId__c = resp.OracleId;
                    }                
                    inv.OICIntegrationStatus__c  = resp.Status;
                    inv.OICNoOfRetries__c        = null;
                    inv.OICIntegrationMessage__c = null;
                    
                    if (receipt != null) {
                        receipt.OraclePartyId__c = resp.OracleId;
                        receiptsToUpdate.add(receipt);
                    }
                    
                } else if (resp.Status == 'E') {
                    inv.OICIntegrationStatus__c  = resp.Status;
                    if (resp.ErrorMsg != null) {
                        inv.OICIntegrationMessage__c = resolveErrMsg(resp.ErrorMsg, errMap);
                    }
                    inv.OICNoOfRetries__c = nextRetry(retryMap, resp.Sfid);
                    
                    logOICError(LOG_SOURCE, LOG_CLASS, LOG_METHOD,
                                requestPayload, responsePayload,
                                resp.Sfid, resp.ErrorMsg,
                                res.getStatusCode(), res.getStatus());
                }
                
                if (!receiptsToUpdate.isEmpty() && !Test.isRunningTest()) {
                    TriggerControl.bypassReceiptTrigger = true;
                    try {
                        update receiptsToUpdate;
                    } finally {
                        TriggerControl.bypassReceiptTrigger = false;
                    }
                }
                invoicesToUpdate.add(inv);
                
            }
            if(!receiptsToUpdate.isEmpty() && !Test.isRunningTest()) {
                update receiptsToUpdate;
            }
            
            return invoicesToUpdate;
        }
    
    private static Map<String, Integer> loadRetryMap(String sObjectName, Set<String> ids) {
        Map<String, Integer> retryMap = new Map<String, Integer>();
        if (ids == null || ids.isEmpty() || String.isBlank(sObjectName)) return retryMap;
        String safeSObjectName = String.escapeSingleQuotes(sObjectName);
        String query = 'SELECT Id, OICNoOfRetries__c FROM ' + safeSObjectName
            + ' WHERE Id IN :ids AND OICNoOfRetries__c != null';
        for (SObject obj : Database.queryWithBinds(query, new Map<String, Object>{'ids' => ids}, AccessLevel.SYSTEM_MODE)) {
            retryMap.put((String) obj.get('Id'),
                         Integer.valueOf((Decimal) obj.get('OICNoOfRetries__c')));
        }
        return retryMap;
    }
    
    private static Map<String, String> loadErrorMsgMap() {
        Map<String, String> errorMap = new Map<String, String>();
        for (Integration_Error_Messages__mdt r : [
            SELECT System_Error_Msg__c, User_Error_Msg__c
            FROM   Integration_Error_Messages__mdt
            WHERE  IsActive__c = true
            AND    Application_Type__c = 'EBS']) {
                errorMap.put(r.System_Error_Msg__c, r.User_Error_Msg__c);
            }
        return errorMap;
    }
    
    private static String resolveErrMsg(String errorMsg, Map<String, String> errMap) {
        String userErrorMessage = UserErrorMessage.getUserErrorMessage(errorMsg, errMap);
        if (userErrorMessage == null) {
            return 'Required information is not updated in Salesforce. Please contact support, ' + errorMsg;
        }
        if (errorMsg != null && errorMsg.contains('Unknown integration error')) {
            return 'Required information is not updated in Salesforce. Please contact support';
        }
        return userErrorMessage;
    }
    
    private static Decimal nextRetry(Map<String, Integer> retryMap, String sfid) {
        return (retryMap != null && retryMap.containsKey(sfid) && retryMap.get(sfid) != null)
            ? retryMap.get(sfid) + 1
            : 1;
    }
    
    private static void logOICError(String process, String cls, String method,
                                    String reqBody, String respBody,
                                    String sfid, String oicMsg,
                                    Integer httpCode, String httpStatus) {
                                        String detail = 'OIC Error | SFID: ' + sfid
                                            + ' | OIC Msg: '       + oicMsg
                                            + ' | HTTP: '          + httpCode + ' ' + httpStatus;
                                        LoggerService.save(LoggerService.createAPILog(
                                            process, cls, method, reqBody, respBody, detail, 'OIC Error Log'));
                                    }
}