/**********************************************************************************************
 * Name        : OIC_BookingFeeReceiptAPI
 * Description : REST entry point for creating / attaching payment receipts against Booking
 *               Fee Lines (bookingFeeLineId). Supports single or bulk receipts per call.
 *               Creates a Receipt__c row per fee line, creates child Booking_Fee_Allocation__c,
 *               marks the Booking_Fee_Line__c as Paid, and attaches any supplied Base64 documents.
 *               Returns only the receipts corresponding to the fee line items passed in payload.
 *
 *               Naming:
 *                 - ADM and Dari fee line -> "ADM and Dari fees receipt"
 *                 - Down Payment fee line -> "Down Payment receipt"
 *
 * Usage       : POST /services/apexrest/booking/feelinereceipts/
 *               POST /services/apexrest/booking/receipts/
 * --------------------------------------------------------------------------------------------
 * Version   Author                      Date            Comment
 * 1.0       Modon                       14 Jul 2026     Initial version.
 * 1.1       pprajapati@horizontal.com   25 Aug 2026     Adopted OIC_RequestContext.
 * 1.2       pprajapati@horizontal.com   30 Aug 2026     Strict 1:1 input-to-output receipt matching,
 *                                                       custom receipt naming (ADM & Dari vs Down Payment),
 *                                                       and support for single & bulk payloads.
 * 1.3       pprajapati@horizontal.com   02 Sep 2026     Attached System.Label.Unidentified_Account1 to Receipt__c.Account__c, updated Unit status handling.
* 1.4       Jay Patel                   21 Sep 2026     MCR-73 — USER_MODE SOQL/DML, createApexLog
 **********************************************************************************************/
@RestResource(urlMapping='/booking/feelinereceipts/*')
global with sharing class OIC_BookingFeeReceiptAPI {

    private static final String DEFAULT_CURRENCY = 'AED';

    /* ====================================================================================
     *  ERROR CODES
     * ==================================================================================== */
    static {
        OIC_RestResponse.define('BFR-000', 400, 'Request body cannot be empty.');
        OIC_RestResponse.define('BFR-001', 400, 'Malformed JSON payload.');
        OIC_RestResponse.define('BFR-002', 400, 'A mandatory field is missing or the request is invalid.');
        OIC_RestResponse.define('BFR-003', 400, 'A supplied Id is not a valid Salesforce Id.');
        OIC_RestResponse.define('BFR-004', 404, 'One or more Booking Fee Lines were not found.');
        OIC_RestResponse.define('BFR-005', 409, 'A receipt already exists for one or more Booking Fee Lines.');
        OIC_RestResponse.define('BFR-006', 403, 'Insufficient permissions to create Receipt__c records.');
        OIC_RestResponse.define('BFR-007', 400, 'Failed to create receipts.');
        OIC_RestResponse.define('BFR-999', 500, 'An unexpected error occurred.');
    }

    private static final String ERR_EMPTY_BODY    = 'BFR-000';
    private static final String ERR_MALFORMED     = 'BFR-001';
    private static final String ERR_MANDATORY     = 'BFR-002';
    private static final String ERR_INVALID_ID    = 'BFR-003';
    private static final String ERR_NO_FEELINE    = 'BFR-004';
    private static final String ERR_DUP_RECEIPT   = 'BFR-005';
    private static final String ERR_NO_ACCESS     = 'BFR-006';
    private static final String ERR_INSERT_FAILED = 'BFR-007';
    private static final String ERR_UNEXPECTED    = 'BFR-999';

    public class BFReceiptException extends Exception {
        public String errorCode;
    }

    private static BFReceiptException buildEx(String code, String message) {
        BFReceiptException ex = new BFReceiptException(message);
        ex.errorCode = code;
        return ex;
    }

    /* ====================================================================================
     *  REST ENTRY POINT
     * ==================================================================================== */
    @HttpPost
    global static void createFeeLineReceipts() {
        processReceipts();
    }

    global static void createReceipts() {
        processReceipts();
    }

    private static void processReceipts() {
        Savepoint sp = Database.setSavepoint();
        try {
            OIC_RequestContext ctx = OIC_RequestContext.current();
            String rawBody = (ctx.getRawBody() != null) ? ctx.getRawBody().trim() : '';
            if (String.isBlank(rawBody)) {
                sendError(400, ERR_EMPTY_BODY, 'Request body cannot be empty.');
                return;
            }

            if (rawBody.containsIgnoreCase('"RequestContext"') || rawBody.containsIgnoreCase('"requestContext"')) {
                ctx = ctx.resolveIdentity();
                if (!ctx.isValid()) {
                    sendError(400, ctx.getErrorCode(), ctx.getErrorMessage());
                    return;
                }
            }

            // ---- 1. Parse payload (supports both array and single-object shapes) ----------
            List<ReceiptEntry> inputList = parseInputPayload(rawBody);
            if (inputList == null || inputList.isEmpty()) {
                sendError(400, ERR_MANDATORY, 'The request must contain at least one Booking Fee Line receipt entry.');
                return;
            }

            // ---- 2. Validate mandatory fields on each entry -------------------------------
            List<Id> feeLineIds = new List<Id>();
            Set<Id> seen = new Set<Id>();
            List<String> missing = new List<String>();

            for (Integer i = 0; i < inputList.size(); i++) {
                ReceiptEntry e = inputList[i];
                String prefix = (inputList.size() > 1) ? ('receipts[' + i + '].') : '';

                if (String.isBlank(e.bookingFeeLineId)) missing.add(prefix + 'bookingFeeLineId');
                if (String.isBlank(e.status))           missing.add(prefix + 'status');
                if (String.isBlank(e.transactionNumber))missing.add(prefix + 'transactionNumber');

                if (String.isNotBlank(e.bookingFeeLineId)) {
                    Id flId;
                    try {
                        flId = Id.valueOf(e.bookingFeeLineId.trim());
                    } catch (Exception ex) {
                        throw buildEx(ERR_INVALID_ID,
                            'Invalid bookingFeeLineId: ' + e.bookingFeeLineId);
                    }
                    if (flId.getSObjectType() != Booking_Fee_Line__c.SObjectType) {
                        throw buildEx(ERR_INVALID_ID,
                            'bookingFeeLineId is not a Booking_Fee_Line__c Id: ' + flId);
                    }
                    if (seen.contains(flId)) {
                        throw buildEx(ERR_MANDATORY,
                            'Duplicate bookingFeeLineId in request: ' + flId + '. One receipt per line is allowed.');
                    }
                    seen.add(flId);
                    feeLineIds.add(flId);
                }
            }
            if (!missing.isEmpty()) {
                throw buildEx(ERR_MANDATORY, 'Mandatory field(s) missing: ' + String.join(missing, ', '));
            }

            // ---- 3. Load ONLY the fee lines passed in payload -----------------------------
            //1.4 MCR-73: Enforce CRUD/FLS via USER_MODE on Booking_Fee_Line__c query
            Map<Id, Booking_Fee_Line__c> feeLineById = new Map<Id, Booking_Fee_Line__c>([
                SELECT Id, Type__c, Total_Amount__c, Balance_Amount__c, Unit__c, Opportunity__c,
                       Opportunity__r.AccountId, Unit__r.Phase__r.EscrowAccount__c,
                       Unit__r.Phase__r.Project__c, Unit__r.Phase__c
                FROM Booking_Fee_Line__c
                WHERE Id IN :feeLineIds
                WITH USER_MODE
            ]);

            List<String> notFound = new List<String>();
            for (Id flId : feeLineIds) {
                if (!feeLineById.containsKey(flId)) notFound.add(String.valueOf(flId));
            }
            if (!notFound.isEmpty()) {
                throw buildEx(ERR_NO_FEELINE,
                    'No Booking Fee Line found for: ' + String.join(notFound, ', '));
            }

            // ---- 4. Enforce 1:1 -- reject lines that already have a receipt ---------------
            Set<Id> alreadyHasReceipt = new Set<Id>();
            //1.4 MCR-73: Enforce CRUD/FLS via USER_MODE on Receipt__c query
            for (Receipt__c r : [
                SELECT Booking_Fee_Line__c FROM Receipt__c WHERE Booking_Fee_Line__c IN :feeLineIds
                WITH USER_MODE
            ]) {
                alreadyHasReceipt.add(r.Booking_Fee_Line__c);
            }
            if (!alreadyHasReceipt.isEmpty()) {
                List<String> parts = new List<String>();
                for (Id flId : alreadyHasReceipt) parts.add(String.valueOf(flId));
                throw buildEx(ERR_DUP_RECEIPT,
                    'A receipt already exists for Booking Fee Line(s): ' + String.join(parts, ', '));
            }

            // ---- 5. Permission check ------------------------------------------------------
            if (!Schema.sObjectType.Receipt__c.isCreateable()) {
                throw buildEx(ERR_NO_ACCESS, null);
            }

            // ---- 6. Build the receipts for ONLY the passed items --------------------------
            List<Receipt__c> receipts = new List<Receipt__c>();
            for (ReceiptEntry e : inputList) {
                Id flId = Id.valueOf(e.bookingFeeLineId.trim());
                Booking_Fee_Line__c fl = feeLineById.get(flId);

                Decimal amount = e.receiptAmount;
                if (amount == null) {
                    amount = (fl.Balance_Amount__c != null && fl.Balance_Amount__c > 0)
                        ? fl.Balance_Amount__c
                        : fl.Total_Amount__c;
                }

                Boolean isAdm = (e.isAdmFeesAndDariCharges != null)
                    ? e.isAdmFeesAndDariCharges
                    : (fl.Type__c != null && fl.Type__c.containsIgnoreCase('ADM'));

                Date rDate = (e.receiptDate != null) ? e.receiptDate : Date.today();

                Id accId;
                if (String.isNotBlank(System.Label.Unidentified_Account1) && !Test.isRunningTest()) {
                    try { accId = Id.valueOf(System.Label.Unidentified_Account1.trim()); } catch (Exception ex) {}
                }
                if (accId == null && fl.Opportunity__r != null) {
                    accId = fl.Opportunity__r.AccountId;
                }
                if (accId == null) {
                    accId = ctx.getResolvedAccountId();
                }

                receipts.add(new Receipt__c(
                    Booking_Fee_Line__c             = flId,
                    Account__c                      = accId,
                    Modeofpayment__c                = normalizeModeOfPayment(e.modeOfPayment),
                    Status__c                       = normalizeReceiptStatus(e.status),
                    ReceiptDate__c                  = rDate,
                    EBS_Clearing_Date__c            = rDate,
                    Last4DigitString__c             = e.last4DigitString,
                    Is_ADM_Fees_and_Dari_charges__c = isAdm,
                    ReceiptRemarks__c               = e.receiptRemarks,
                    Receipt_Amount__c               = amount,
                    TotalAmount__c                  = amount,
                    TransactionNumber__c            = e.transactionNumber,
                    TransactionDate__c              = (e.transactionDate != null) ? e.transactionDate : rDate
                ));
            }

            // ---- 7. Insert receipts -------------------------------------------------------
            //1.4 MCR-73: Enforce CRUD/FLS via USER_MODE on Receipt__c insert
            Database.insert(receipts, AccessLevel.USER_MODE);

            // ---- 7b. Create Allocations & update Fee Line Status --------------------------
            List<Booking_Fee_Allocation__c> allocations = new List<Booking_Fee_Allocation__c>();
            List<Booking_Fee_Line__c> feeLinesToUpdate = new List<Booking_Fee_Line__c>();
            Set<Id> unitIdsToReserve = new Set<Id>();

            for (Integer i = 0; i < receipts.size(); i++) {
                Receipt__c r = receipts[i];
                Booking_Fee_Line__c fl = feeLineById.get(r.Booking_Fee_Line__c);
                allocations.add(new Booking_Fee_Allocation__c(
                    Booking_Fee_Line__c   = r.Booking_Fee_Line__c,
                    Payment__c            = r.Id,
                    Allocation_Amount__c  = r.Receipt_Amount__c,
                    Status__c             = 'Applied',
                    Type__c               = (fl != null ? fl.Type__c : 'ADM & Dari')
                ));
            }
            if (!allocations.isEmpty()) {
                //1.4 MCR-73: Enforce CRUD/FLS via USER_MODE on allocation insert
                Database.insert(allocations, AccessLevel.USER_MODE);
            }

            for (Id flId : feeLineIds) {
                Booking_Fee_Line__c fl = feeLineById.get(flId);
                feeLinesToUpdate.add(new Booking_Fee_Line__c(
                    Id = flId,
                    Status__c = 'Paid'
                ));
                if (fl.Unit__c != null) {
                    unitIdsToReserve.add(fl.Unit__c);
                }
            }
            if (!feeLinesToUpdate.isEmpty()) {
                //1.4 MCR-73: Enforce CRUD/FLS via USER_MODE on fee line update
                Database.update(feeLinesToUpdate, AccessLevel.USER_MODE);
            }

            if (!unitIdsToReserve.isEmpty()) {
                List<Unit__c> unitsToUpdate = new List<Unit__c>();
                for (Id uId : unitIdsToReserve) {
                    unitsToUpdate.add(new Unit__c(
                        Id = uId,
                        Status__c = 'Blocked'
                    ));
                }
                //1.4 MCR-73: Enforce CRUD/FLS via USER_MODE on Unit update
                Database.update(unitsToUpdate, AccessLevel.USER_MODE);
            }

            // ---- 8. Attach documents (best-effort, per receipt) ---------------------------
            List<String> docStatuses = new List<String>();
            for (Integer i = 0; i < inputList.size(); i++) {
                ReceiptEntry e = inputList[i];
                String docStatus = 'Not Provided';
                if (String.isNotBlank(e.documentBase64)) {
                    docStatus = storeReceiptDocument(receipts[i].Id, e.documentBase64, e.documentName);
                }
                docStatuses.add(docStatus);
            }

            // ---- 9. Re-query for AutoNumber Name & fields ---------------------------------
            Set<Id> receiptIds = new Set<Id>();
            for (Receipt__c r : receipts) receiptIds.add(r.Id);

            //1.4 MCR-73: Enforce CRUD/FLS via USER_MODE on Receipt__c query
            Map<Id, Receipt__c> savedById = new Map<Id, Receipt__c>([
                SELECT Id, Name, Status__c, ReceiptDate__c, Account__c, Booking_Fee_Line__c,
                       Receipt_Amount__c
                FROM Receipt__c
                WHERE Id IN :receiptIds
                WITH USER_MODE
            ]);

            // ---- 10. Build the per-line results with correct label naming -----------------
            List<Map<String, Object>> results = new List<Map<String, Object>>();
            for (Integer i = 0; i < receipts.size(); i++) {
                Receipt__c saved = savedById.get(receipts[i].Id);
                Booking_Fee_Line__c fl = feeLineById.get(saved.Booking_Fee_Line__c);

                // Specific requested name label:
                // ADM & Dari -> "ADM and Dari fees receipt"
                // Down Payment -> "Down Payment receipt"
                String receiptLabel;
                if (fl != null && fl.Type__c != null && fl.Type__c.containsIgnoreCase('ADM')) {
                    receiptLabel = 'ADM and Dari fees receipt';
                } else if (fl != null && fl.Type__c != null && fl.Type__c.containsIgnoreCase('Down')) {
                    receiptLabel = 'Down Payment receipt';
                } else {
                    receiptLabel = (fl != null && String.isNotBlank(fl.Type__c)) ? (fl.Type__c + ' receipt') : 'Booking Fee receipt';
                }

                Map<String, Object> itemMap = new Map<String, Object>{
                    'bookingFeeLineId' => saved.Booking_Fee_Line__c,
                    'feeType'          => receiptLabel,
                    'receiptId'        => saved.Id,
                    'receiptName'      => receiptLabel,
                    'receiptNumber'    => saved.Name,
                    'paymentStatus'    => saved.Status__c,
                    'receiptDate'      => saved.ReceiptDate__c,
                    'accountId'        => saved.Account__c,
                    'receiptAmount'    => saved.Receipt_Amount__c,
                    'currencyIsoCode'  => DEFAULT_CURRENCY,
                    'documentStatus'   => docStatuses[i]
                };
                results.add(itemMap);
            }

            Map<String, Object> responseMap = new Map<String, Object>{
                'Status'       => 'Success',
                'ReceiptCount' => results.size(),
                'message'      => results.size() + ' receipt(s) created.',
                'Results'      => results
            };

            RestResponse res = RestContext.response;
            if (res != null) {
                res.statusCode = 200;
                res.addHeader('Content-Type', 'application/json');
                res.responseBody = Blob.valueOf(JSON.serialize(responseMap, true));
            }

        } catch (BFReceiptException bfEx) {
            Database.rollback(sp);
            Integer httpStatus = 400;
            if (bfEx.errorCode == ERR_DUP_RECEIPT) {
                httpStatus = 409;
            } else if (bfEx.errorCode == ERR_NO_FEELINE) {
                httpStatus = 404;
            } else if (bfEx.errorCode == ERR_NO_ACCESS) {
                httpStatus = 403;
            }
            sendError(httpStatus, bfEx.errorCode, bfEx.getMessage());

        } catch (DmlException dmlEx) {
            Database.rollback(sp);
            sendError(400, ERR_INSERT_FAILED, OIC_RestResponse.describeException(dmlEx));

        } catch (Exception ex) {
            Database.rollback(sp);
            //1.4 MCR-73: Log unexpected failures via LoggerService.createApexLog
            LoggerService.save(LoggerService.createApexLog(
                ex,
                'Booking Fee Receipt API',
                'OIC_BookingFeeReceiptAPI',
                'processReceipts'
            ));
            sendError(500, ERR_UNEXPECTED, OIC_RestResponse.describeException(ex));
        }
    }

    private static void sendError(Integer statusCode, String errorCode, String message) {
        RestResponse res = RestContext.response;
        if (res != null) {
            res.statusCode = statusCode;
            res.addHeader('Content-Type', 'application/json');
            Map<String, Object> errMap = new Map<String, Object>{
                'Status'       => 'Failure',
                'ErrorCode'    => errorCode,
                'ErrorMessage' => message
            };
            res.responseBody = Blob.valueOf(JSON.serialize(errMap, true));
        }
    }

    /* ====================================================================================
     *  PAYLOAD PARSER
     * ==================================================================================== */
    private static List<ReceiptEntry> parseInputPayload(String rawBody) {
        List<ReceiptEntry> entries = new List<ReceiptEntry>();
        if (String.isBlank(rawBody)) return entries;

        Map<String, Object> rootMap;
        try {
            rootMap = (Map<String, Object>) JSON.deserializeUntyped(rawBody);
        } catch (Exception e) {
            try {
                // If raw array: [ { ... } ]
                List<Object> rawList = (List<Object>) JSON.deserializeUntyped(rawBody);
                String wrapped = '{"receipts":' + rawBody + '}';
                ReceiptsPayload p = (ReceiptsPayload) JSON.deserialize(wrapped, ReceiptsPayload.class);
                if (p != null && p.receipts != null) return p.receipts;
            } catch (Exception ex2) {
                throw buildEx(ERR_MALFORMED, 'Malformed JSON payload: ' + e.getMessage());
            }
        }

        if (rootMap != null) {
            Object receiptsObj = rootMap.get('receipts');
            if (receiptsObj == null) receiptsObj = rootMap.get('Receipts');
            if (receiptsObj == null) receiptsObj = rootMap.get('results');
            if (receiptsObj == null) receiptsObj = rootMap.get('Results');

            if (receiptsObj instanceof List<Object>) {
                ReceiptsPayload p = (ReceiptsPayload) JSON.deserialize(rawBody, ReceiptsPayload.class);
                if (p != null && p.receipts != null) {
                    entries.addAll(p.receipts);
                }
            } else if (receiptsObj instanceof Map<String, Object>) {
                ReceiptEntry singleEntry = (ReceiptEntry) JSON.deserialize(JSON.serialize(receiptsObj), ReceiptEntry.class);
                if (singleEntry != null) entries.add(singleEntry);
            } else {
                // Check single object at root level
                ReceiptEntry singleEntry = (ReceiptEntry) JSON.deserialize(rawBody, ReceiptEntry.class);
                if (String.isBlank(singleEntry.bookingFeeLineId)) {
                    if (rootMap.containsKey('BookingFeeId')) singleEntry.bookingFeeLineId = String.valueOf(rootMap.get('BookingFeeId'));
                    else if (rootMap.containsKey('bookingFeeId')) singleEntry.bookingFeeLineId = String.valueOf(rootMap.get('bookingFeeId'));
                    else if (rootMap.containsKey('BookingFeeLineId')) singleEntry.bookingFeeLineId = String.valueOf(rootMap.get('BookingFeeLineId'));
                    else if (rootMap.containsKey('FeeLineId')) singleEntry.bookingFeeLineId = String.valueOf(rootMap.get('FeeLineId'));
                    else if (rootMap.containsKey('feeLineId')) singleEntry.bookingFeeLineId = String.valueOf(rootMap.get('feeLineId'));
                    else if (rootMap.containsKey('Id')) singleEntry.bookingFeeLineId = String.valueOf(rootMap.get('Id'));
                    else if (rootMap.containsKey('id')) singleEntry.bookingFeeLineId = String.valueOf(rootMap.get('id'));
                }
                if (String.isNotBlank(singleEntry.bookingFeeLineId)) {
                    entries.add(singleEntry);
                }
            }
        }

        return entries;
    }

    /* ====================================================================================
     *  ATTACHMENT LOGIC
     * ==================================================================================== */
    private static String storeReceiptDocument(Id receiptId, String base64Content, String docName) {
        try {
            Blob fileBody = EncodingUtil.base64Decode(base64Content);
            String title = String.isNotBlank(docName) ? docName : ('Receipt_Doc_' + DateTime.now().getTime());

            ContentVersion cv = new ContentVersion(
                Title          = title,
                PathOnClient   = title.endsWithIgnoreCase('.pdf') ? title : (title + '.pdf'),
                VersionData    = fileBody,
                IsMajorVersion = true
            );
            //1.4 MCR-73: Enforce CRUD/FLS via USER_MODE on ContentVersion insert
            Database.insert(cv, AccessLevel.USER_MODE);

            //1.4 MCR-73: Enforce CRUD/FLS via USER_MODE on ContentVersion query
            Id docId = [
                SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id WITH USER_MODE LIMIT 1
            ].ContentDocumentId;
            //1.4 MCR-73: Enforce CRUD/FLS via USER_MODE on ContentDocumentLink insert
            Database.insert(new ContentDocumentLink(
                ContentDocumentId = docId,
                LinkedEntityId    = receiptId,
                ShareType         = 'V',
                Visibility        = 'AllUsers'
            ), AccessLevel.USER_MODE);
            return 'Attached';
        } catch (Exception e) {
            return 'Failed: ' + e.getMessage();
        }
    }

    private static String normalizeReceiptStatus(String rawStatus) {
        if (String.isBlank(rawStatus)) return 'Confirmed';
        String s = rawStatus.trim().toLowerCase();
        if (s == 'paid' || s == 'success' || s == 'successful' || s == 'confirmed') return 'Confirmed';
        if (s == 'cleared') return 'Cleared';
        if (s == 'received') return 'Received';
        if (s == 'approved') return 'Approved';
        if (s == 'in progress' || s == 'pending') return 'In Progress';
        return rawStatus;
    }

    private static String normalizeModeOfPayment(String raw) {
        if (String.isBlank(raw)) return 'Online';
        String s = raw.trim().toLowerCase();
        if (s.contains('card') || s.contains('online') || s.contains('ipg') || s.contains('gateway') || s.contains('web')) return 'Online';
        if (s.contains('bank') || s.contains('transfer') || s.contains('wire') || s.contains('eft')) return 'Bank Transfer';
        if (s.contains('cheque') || s.contains('check')) return 'Cheque';
        if (s.contains('pos')) return 'POS';
        if (s.contains('direct')) return 'Direct Debit';
        if (s.contains('equity')) return 'Equity Transfer';
        if (s.contains('note')) return 'Credit Note';
        if (s.contains('adjustment')) return 'Payment Adjustment';
        return raw;
    }

    /* ====================================================================================
     *  DTOs
     * ==================================================================================== */
    public class ReceiptsPayload {
        public List<ReceiptEntry> receipts;
    }

    public class ReceiptEntry {
        public String  bookingFeeLineId;
        public Decimal receiptAmount;
        public String  modeOfPayment;
        public String  status;
        public Date    receiptDate;
        public String  last4DigitString;
        public Boolean isAdmFeesAndDariCharges;
        public String  receiptRemarks;
        public String  transactionNumber;
        public Date    transactionDate;
        public String  transactionType;
        public String  documentBase64;
        public String  documentName;
    }
}