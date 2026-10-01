/**
* @description       :
* @author            : Kumaravel Mathivanan
* @group             :
* @Created modified on  : 10-20-2025
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           Kumaravel Mathivanan        02-10-2025     Initial Draft
* 2.0           Manoj                       20-01-2026     Update JSON and Logic for the Reversed
* 3.0           Manoj                       30-01-2026     Update JSON and Logic for the Remitted
* 4.0           Manoj                       20-01-2026     Update logic for OracleID and Cleared
* 5.0           Manoj                       25-04-2026     Update logic to add LoggerService
* 6.0           Manoj                       02-05-2026     Update Request/Response to support per-record ResponseArray
* 7.0           Manoj                       13-05-2026     Update cleared/confrom to support per-record ResponseArray
* 7.1           Jay Patel                   21 Sep 2026    MCR-73 — with sharing, USER_MODE SOQL/DML, createApexLog
* 7.2           Jay Patel                   28 Sep 2026    MCR-184 — Bulkify receipt processing to handle multiple records
********************************************************************************************************/
@RestResource(urlMapping='/ReceiptAPI')
global with sharing class RestReceiptService {

    @HttpPost
    global static Base64ResponseWrapper updateReceiptsfromOracle() {
        RestRequest req = RestContext.request;
        Base64ResponseWrapper base64Response = new Base64ResponseWrapper();
        OICResponseWrapperList resultWrapperList = new OICResponseWrapperList();
        resultWrapperList.ResponseArray = new List<OICResponseWrapper>();
        String jsonString = null;
    	//start 7.0
        // ── Single log accumulator ──────────────────────────────────────
        List<String> logMessages = new List<String>();
        String overallStatus     = 'S'; 
       // End 7.0
        
        try {
            String rawBody = req.requestBody.toString();
            system.debug('rawBody----' + rawBody);
            Base64RequestWrapper base64Request = (Base64RequestWrapper) JSON.deserialize(rawBody, Base64RequestWrapper.class);
            system.debug('base64Request----' + base64Request);
    
            if (String.isBlank(base64Request.Base64Request)) {
                OICResponseWrapper errWrapper = new OICResponseWrapper();
                errWrapper.Status  = 'E';
                errWrapper.Message = 'Missing Base64Request in payload';
                errWrapper.Sfid    = null;
                resultWrapperList.ResponseArray.add(errWrapper);
                overallStatus = 'E'; // 7.0
                logMessages.add('Missing Base64Request in payload'); // 7.0
    
            } else {
                Blob decodedBlob = EncodingUtil.base64Decode(base64Request.Base64Request);
                jsonString = decodedBlob.toString();
                system.debug('request List' + jsonString);
    
                OICRequestWrapperList requestList = (OICRequestWrapperList) JSON.deserialize(jsonString, OICRequestWrapperList.class);
                system.debug('request List' + requestList);
                system.debug('request List Array' + requestList.RequestArray);
    
                // 7.2 MCR-184: Collect all non-blank Sfids to query Receipt__c records in bulk outside the loop
                Set<Id> receiptIds = new Set<Id>();
                if (requestList != null && requestList.RequestArray != null) {
                    for (OIC_RequestWrapper record : requestList.RequestArray) {
                        if (record != null && String.isNotBlank(record.Sfid)) {
                            try {
                                receiptIds.add((Id) record.Sfid.trim());
                            } catch (Exception ex) {
                                // Skip invalid Id formats here; will be caught and reported in the per-record processing loop
                            }
                        }
                    }
                }

                // 7.2 MCR-184: Single bulk query for all receipts to prevent SOQL limit in loop (enforce USER_MODE)
                Map<Id, Receipt__c> receiptMap = new Map<Id, Receipt__c>();
                if (!receiptIds.isEmpty()) {
                    //7.1 MCR-73: Enforce CRUD/FLS via USER_MODE on Receipt__c query
                    receiptMap = new Map<Id, Receipt__c>([
                        SELECT Id, OraclePartyId__c, Status__c
                        FROM Receipt__c
                        WHERE Id IN :receiptIds
                        WITH USER_MODE
                    ]);
                }

                // 7.2 MCR-184: Map to stage receipts for update and prevent duplicate Id errors in Database.update
                Map<Id, Receipt__c> receiptsToUpdateMap = new Map<Id, Receipt__c>();
                // Track which Sfid maps to which response wrapper(s) so we can update after bulk DML
                Map<Id, List<OICResponseWrapper>> sfidToResponseMap = new Map<Id, List<OICResponseWrapper>>();

                for (OIC_RequestWrapper record : requestList.RequestArray) {
                    system.debug('request' + record);
                    OICResponseWrapper recWrapper = new OICResponseWrapper();
                    recWrapper.Sfid = record.Sfid;

                    try { 
                        if (String.isNotBlank(record.Sfid)) {
                            // 7.2 MCR-184: Retrieve Receipt from pre-queried bulk map without executing SOQL inside loop
                            Id receiptId = (Id) record.Sfid.trim();
                            Receipt__c receipt = receiptMap.get(receiptId);

                            if (receipt != null) {
                                Receipt__c receiptUpdate = new Receipt__c();
                                receiptUpdate.Id = receipt.Id;

                                if (String.isNotBlank(record.Status) && record.Status == 'S') {
                                    receiptUpdate.OraclePartyId__c = record.OracleID;

                                } else if (String.isNotBlank(record.Status) && record.Status == 'R') {
                                    receiptUpdate.Status__c         = 'Rejected';
                                    receiptUpdate.ReceiptRemarks__c = record.Remarks;

                                } else if (String.isNotBlank(record.Status) && record.Status == 'Reversed') {
                                    // 2.0 7.0 Start Update Remarks logic
                                    if (record.Remarks == 'Cheque Replace' || record.Remarks == 'Cheque returned') {
                                        receiptUpdate.Status__c               = 'Returned to customer';
                                        receiptUpdate.isReverseEBS__c         = true;
                                        receiptUpdate.Cheque_Bounce_Reason__c = record.Remarks;
                                    } else if (record.Remarks == 'Accounting Error' || record.Remarks == 'Cancelled') {
                                        receiptUpdate.Status__c               = 'Cancelled';
                                        receiptUpdate.isReverseEBS__c         = true;
                                        receiptUpdate.Cheque_Bounce_Reason__c = record.Remarks;
                                    } else {
                                        receiptUpdate.Status__c               = 'Bounced';
                                        receiptUpdate.isReverseEBS__c         = true;
                                        receiptUpdate.Cheque_Bounce_Reason__c = record.Remarks;
                                    }
                                    // 2.0 7.0 End

                                } else if (String.isNotBlank(record.Status) && record.Status == 'Remitted') {
                                    // 3.0 Update the status Remitted
                                    receiptUpdate.Status__c         = 'Remitted';
                                    receiptUpdate.ReceiptRemarks__c = record.Remarks;
                                    if (record.OracleID != null) { // 4.0 Update the OracleID
                                        receiptUpdate.OraclePartyId__c = record.OracleID;
                                    }

                                } else if (String.isNotBlank(record.Status) && record.Status == 'Cleared') {
                                    // 4.0 Update the status Cleared
                                    receiptUpdate.Status__c = 'Cleared';
                                    if (record.OracleID != null) {
                                        receiptUpdate.OraclePartyId__c = record.OracleID;
                                    }
                                    receiptUpdate.EBS_Clearing_Date__c = record.ClearedDate;
                                } else if (String.isNotBlank(record.Status) && record.Status == 'Confirmed') { // 7.0                                    
                                    receiptUpdate.Status__c = 'Confirmed';
                                    if (record.OracleID != null) {
                                        receiptUpdate.OraclePartyId__c = record.OracleID;
                                    }
                                }

                                receiptsToUpdateMap.put(receiptUpdate.Id, receiptUpdate);
                                if (!sfidToResponseMap.containsKey(receipt.Id)) {
                                    sfidToResponseMap.put(receipt.Id, new List<OICResponseWrapper>());
                                }
                                sfidToResponseMap.get(receipt.Id).add(recWrapper);

                                // Tentatively mark success; DML block below will override on error
                                recWrapper.Status  = 'S';
                                recWrapper.Message = 'Record staged for update successfully.';

                            } else {
                                recWrapper.Status  = 'E';
                                recWrapper.Message = 'No Receipt__c found for Sfid: ' + record.Sfid
                                                   + ' / OracleID: ' + record.OracleID; // 7.0
                                // ── accumulate, no save() here ──
                                overallStatus = 'P';
                                logMessages.add('Not found — Sfid: ' + record.Sfid + ' / OracleID: ' + record.OracleID);
                            }
                        } else { 
                            recWrapper.Status  = 'E';
                            recWrapper.Message = 'Both Sfid and OracleID are blank; record skipped.';
                            // ── 7.0 accumulate, no save() here ──
                            overallStatus = 'P';
                            logMessages.add('Skipped — both Sfid and OracleID blank');
                        }
                    } catch (Exception ex) {
                        recWrapper.Status  = 'E';
                        recWrapper.Message = 'Error processing record: ' + ex.getMessage();
                        // ── 7.0 accumulate, no save() here ──
                        overallStatus = 'P';
                        logMessages.add('Record exception — Sfid: ' + record.Sfid + ' | ' + ex.getMessage());
                    }

                    resultWrapperList.ResponseArray.add(recWrapper);
                }

                // 7.2 MCR-184: Bulk DML update with partial success using Database.update in USER_MODE
                if (!receiptsToUpdateMap.isEmpty()) {
                    List<Receipt__c> receiptsToUpdate = receiptsToUpdateMap.values();
                    // 7.1 MCR-73: Enforce CRUD/FLS via USER_MODE on Receipt update
                    Database.SaveResult[] saveResults = Database.update(receiptsToUpdate, false, AccessLevel.USER_MODE);
                    for (Integer i = 0; i < saveResults.size(); i++) {
                        Id updatedId = receiptsToUpdate[i].Id;
                        List<OICResponseWrapper> wrappers = sfidToResponseMap.get(updatedId);
                        if (wrappers != null) {
                            for (OICResponseWrapper recWrapper : wrappers) {
                                if (saveResults[i].isSuccess()) {
                                    recWrapper.Status  = 'S';
                                    recWrapper.Message = 'Record updated successfully.';
                                } else {
                                    recWrapper.Status  = 'E';
                                    recWrapper.Message = saveResults[i].getErrors()[0].getMessage();
                                    // ── 7.0 accumulate, no save() here ──
                                    overallStatus = 'P';
                                    logMessages.add('DML error — Sfid: ' + updatedId + ' | ' + recWrapper.Message);
                                }
                            }
                        }
                    }
                }
            }
    
            String responseJson = JSON.serialize(resultWrapperList);
            base64Response.Base64Response = EncodingUtil.base64Encode(Blob.valueOf(responseJson));
    
            // ── ONE save() for the entire request ──────────────────────
            String logDetail = logMessages.isEmpty()
                ? 'All records processed successfully.'
                : String.join(logMessages, ' | ');
            LoggerService.save(LoggerService.createAPILog(
                'ReceiptAPI', 'RestReceiptService', 'updateReceiptsfromOracle',
                jsonString, responseJson,
                'Status Code: ' + overallStatus + '; ' + logDetail, 'Callout Log'
            ));
            // ───────────────────────────────────────────────────────────
    
        } catch (Exception e) {
            //7.1 MCR-73: Log unexpected failures via LoggerService.createApexLog
            LoggerService.save(LoggerService.createApexLog(
                e,
                'Receipt API',
                'RestReceiptService',
                'updateReceiptsfromOracle'
            ));
            OICResponseWrapper errWrapper = new OICResponseWrapper();
            errWrapper.Status  = 'E';
            errWrapper.Message = 'Unhandled error: ' + e.getMessage();
            errWrapper.Sfid    = null;
            resultWrapperList.ResponseArray = new List<OICResponseWrapper>{ errWrapper };
    
            String responseJson = JSON.serialize(resultWrapperList);
            base64Response.Base64Response = EncodingUtil.base64Encode(Blob.valueOf(responseJson));
    
            // ── ONE save() in the catch path too ───────────────────────
            LoggerService.save(LoggerService.createAPILog(
                'ReceiptAPI', 'RestReceiptService', 'updateReceiptsfromOracle',
                jsonString, responseJson,
                'Status Code: E; Unhandled error: ' + e.getMessage(), 'Callout Log'
            ));
            // ───────────────────────────────────────────────────────────
        } //End 7.0
    
        return base64Response;
    }

    // ========== Wrapper Classes ==========

    global class Base64RequestWrapper {
        public String Base64Request;
    }

    global class OICRequestWrapperList {
        public List<OIC_RequestWrapper> RequestArray;
    }

    global class OIC_RequestWrapper {
        public String Sfid;
        public String Remarks;
        public String PaymentStatus;
        public String Status;
        public String Message;
        public String OracleID;
        public String OracleRef;
        public String ReverseReason; // 2.0 Update ReverseReason logic
        public Date ClearedDate; // 7.0
    }

    global class OICResponseWrapper {
        public String Status;
        public String Message;
        public String Sfid;         // 6.0 Per-record identifier
    }

    global class OICResponseWrapperList {
        public List<OICResponseWrapper> ResponseArray;
    }

    global class Base64ResponseWrapper {
        public String Base64Response;
    }
}