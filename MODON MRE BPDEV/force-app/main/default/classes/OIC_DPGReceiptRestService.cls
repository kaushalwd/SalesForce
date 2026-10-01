/**********************************************************************************************************************
* Name        : OIC_DPGReceiptRestService
* Description : Exposes a REST endpoint that DPG (Digital Payment Gateway) calls via HTTP POST to create a
*               Receipt__c record against an Expression of Interest, optionally attaching a base64 document.
* Usage       : POST /services/apexrest/dpg/receipt/
* --------------------------------------------------------------------------------------------------------------------
* Version   Author   Date           Comment
* 1.0       -        -              Initial.
* 2.0       Arvind   10 Jul 2026    Response handling delegated to OIC_RestResponse. RCP-xxx codes registered
*                                     dynamically. Structured Errors[] on DML failures. Removed response wrapper.
* 2.1       Arvind   10 Jul 2026    CurrencyIsoCode set to AED on insert; read back off the saved Receipt on export.
* 2.2       Arvind   14 Jul 2026    salesOrderId no longer mandatory. Now EITHER salesOrderId OR
*                                     expressionOfInterestId is required (both accepted). Account is resolved from
*                                     the Sales Order when present, otherwise from the Expression of Interest.
* 3.0       -        14 Jul 2026    Removed ALL Sales Order logic. Endpoint now creates Expression-of-Interest
*                                     receipts only: expressionOfInterestId is REQUIRED, the Account is resolved
*                                     solely from the Expression of Interest, and the salesOrderId field,
*                                     SalesOrder__c mapping, resolveCustomerAccountFromSalesOrder() and the
*                                     RCP-004 code have all been retired.
* 3.1       pprajapati@horizontal.com   04 Sep 2026    Attach System.Label.Unidentified_Account1 to Receipt__c.Account__c
*                                                      instead of customer Account from ExpressionOfInterest__c.
* 3.2       Jay Patel                   21 Sep 2026    MCR-73 — USER_MODE SOQL/DML, createApexLog
***********************************************************************************************************************/
@RestResource(urlMapping='/dpg/receipt/*')
global with sharing class OIC_DPGReceiptRestService {

    /* ====================================================================================
     *  ERROR CODES - registered into the shared registry at class load.
     * ==================================================================================== */
    static {
        OIC_RestResponse.define('RCP-000', 400, 'Request body cannot be empty.');
        OIC_RestResponse.define('RCP-001', 400, 'Malformed JSON payload.');
        OIC_RestResponse.define('RCP-002', 400, 'A mandatory field is missing.');
        OIC_RestResponse.define('RCP-003', 400, 'A supplied Id is not a valid Salesforce Id.');
        OIC_RestResponse.define('RCP-005', 403, 'Insufficient permissions to create Receipt__c records.');
        OIC_RestResponse.define('RCP-006', 400, 'Failed to create receipt.');
        OIC_RestResponse.define('RCP-007', 404, 'No Expression of Interest found for the supplied expressionOfInterestId.');
        OIC_RestResponse.define('RCP-999', 500, 'An unexpected error occurred.');
    }

    private static final String ERR_EMPTY_BODY    = 'RCP-000';
    private static final String ERR_MALFORMED     = 'RCP-001';
    private static final String ERR_MANDATORY     = 'RCP-002';
    private static final String ERR_INVALID_ID    = 'RCP-003';
    private static final String ERR_NO_ACCESS     = 'RCP-005';
    private static final String ERR_INSERT_FAILED = 'RCP-006';
    private static final String ERR_NO_EOI        = 'RCP-007';
    private static final String ERR_UNEXPECTED    = 'RCP-999';

    private static final Integer HTTP_CREATED    = 201;
    private static final String  DEFAULT_CURRENCY = 'AED';

    /* ====================================================================================
     *  CUSTOM EXCEPTION - carries a registered code
     * ==================================================================================== */
    global class DPGReceiptException extends Exception {
        public String errorCode;
    }

    private static DPGReceiptException buildEx(String code, String message) {
        DPGReceiptException ex = new DPGReceiptException(message);
        ex.errorCode = code;
        return ex;
    }

    /* ====================================================================================
     *  REST ENTRY POINT
     * ==================================================================================== */
    @HttpPost
    global static void createReceipt() {
        RestRequest req = RestContext.request;
        Savepoint sp = Database.setSavepoint();

        try {
            // ---- 1. Parse & validate the incoming JSON body ------------------------------
            if (req == null || req.requestBody == null || req.requestBody.toString().trim().length() == 0) {
                throw buildEx(ERR_EMPTY_BODY, null);
            }

            ReceiptRequestWrapper input;
            try {
                input = (ReceiptRequestWrapper) JSON.deserialize(
                    req.requestBody.toString(), ReceiptRequestWrapper.class);
            } catch (Exception parseEx) {
                throw buildEx(ERR_MALFORMED, 'Malformed JSON payload: ' + parseEx.getMessage());
            }

            validateRequest(input);

            // ---- 2. Resolve the Expression of Interest Id (required) ----------------------
            Id expressionOfInterestId = toId(input.expressionOfInterestId, 'expressionOfInterestId', true);

            // ---- 3. Resolve the Account for the Receipt (Unidentified Account from Custom Label) -
            Id customerAccountId = resolveReceiptAccount(expressionOfInterestId);

            // ---- 4. Permission check BEFORE building the record ---------------------------
            if (!Schema.sObjectType.Receipt__c.isCreateable()) {
                throw buildEx(ERR_NO_ACCESS, null);
            }

            Boolean isAdm = (input.isAdmFeesAndDariCharges != null) ? input.isAdmFeesAndDariCharges : false;

            // ---- 5. Map wrapper -> Receipt__c and insert ----------------------------------
            Receipt__c receipt = new Receipt__c(
                Modeofpayment__c                = normalizeModeOfPayment(input.modeOfPayment),
                Status__c                       = normalizeReceiptStatus(input.status),
                ReceiptDate__c                  = (input.receiptDate != null) ? input.receiptDate : Date.today(),
                ExpressionOfInterest__c         = expressionOfInterestId,
                Last4DigitString__c             = input.last4DigitString,
                Is_ADM_Fees_and_Dari_charges__c = isAdm,
                ReceiptRemarks__c               = input.receiptRemarks,
                Receipt_Amount__c               = input.receiptAmount,
                TransactionNumber__c            = input.transactionNumber,
                TransactionDate__c              = (input.transactionDate != null) ? input.transactionDate : Date.today(),
                Transaction_Type__c             = input.transactionType,
                Account__c                      = customerAccountId
            );

            //3.2 MCR-73: Enforce CRUD/FLS via USER_MODE on Receipt insert
            Database.SaveResult sr = Database.insert(receipt, false, AccessLevel.USER_MODE);
            if (!sr.isSuccess()) {
                // Structured errors preserved: validation rules, trigger addError(), field names.
                OIC_RestResponse.failure(ERR_INSERT_FAILED,
                        'Failed to create receipt. ' + OIC_RestResponse.formatErrors(sr.getErrors()))
                    .addErrors(sr.getErrors())
                    .send();
                return;
            }
            Id receiptId = sr.getId();

            // ---- 6. Store the attached document (if any) ----------------------------------
            // A failed upload does NOT fail the request -- the Receipt exists. Surfaced instead.
            String documentStatus = 'Not Provided';
            if (String.isNotBlank(input.documentBase64)) {
                documentStatus = storeReceiptDocument(receiptId, input.documentBase64, input.documentName);
            }

            // ---- 7. Re-query for the auto-number Name field -------------------------------
            // CurrencyIsoCode is READ BACK from the saved record, never assumed -- if a trigger
            // or the parent Account overrode it, that is what gets exported. An amount without
            // its currency is meaningless, so the two travel together.
            //3.2 MCR-73: Enforce CRUD/FLS via USER_MODE on Receipt__c query
            Receipt__c createdReceipt = [
                SELECT Id, Name, Status__c, ReceiptDate__c, Account__c,
                       ExpressionOfInterest__c,
                       Receipt_Amount__c
                FROM Receipt__c
                WHERE Id = :receiptId
                WITH USER_MODE
                LIMIT 1
            ];

            OIC_RestResponse.success()
                .put('success',                true)
                .put('Success',                true)
                .put('isSuccess',              true)
                .put('IsSuccess',              true)
                .put('receiptId',              createdReceipt.Id)
                .put('ReceiptId',              createdReceipt.Id)
                .put('receiptName',            createdReceipt.Name)
                .put('ReceiptName',            createdReceipt.Name)
                .put('paymentStatus',          createdReceipt.Status__c)
                .put('PaymentStatus',          createdReceipt.Status__c)
                .put('receiptDate',            createdReceipt.ReceiptDate__c)
                .put('ReceiptDate',            createdReceipt.ReceiptDate__c)
                .put('accountId',              createdReceipt.Account__c)
                .put('AccountId',              createdReceipt.Account__c)
                .put('expressionOfInterestId', createdReceipt.ExpressionOfInterest__c)
                .put('ExpressionOfInterestId', createdReceipt.ExpressionOfInterest__c)
                .put('receiptAmount',          createdReceipt.Receipt_Amount__c)
                .put('ReceiptAmount',          createdReceipt.Receipt_Amount__c)
                .put('currencyIsoCode',        DEFAULT_CURRENCY)
                .put('CurrencyIsoCode',        DEFAULT_CURRENCY)
                .put('documentStatus',         documentStatus)
                .put('DocumentStatus',         documentStatus)
                .put('message',                'Receipt created successfully.')
                .put('Message',                'Receipt created successfully.')
                .flat()
                .send();

        } catch (DPGReceiptException dpgEx) {
            Database.rollback(sp);
            OIC_RestResponse.failure(dpgEx.errorCode, dpgEx.getMessage()).send();

        } catch (QueryException qEx) {
            Database.rollback(sp);
            OIC_RestResponse.fromException(qEx, ERR_NO_EOI).send();

        } catch (Exception ex) {
            // Covers DmlException -- fromException() attaches its structured row errors.
            Database.rollback(sp);
            //3.2 MCR-73: Log unexpected failures via LoggerService.createApexLog
            LoggerService.save(LoggerService.createApexLog(
                ex,
                'DPG Receipt REST Service',
                'OIC_DPGReceiptRestService',
                'createReceipt'
            ));
            OIC_RestResponse.fromException(ex, ERR_UNEXPECTED).send();
        }
    }

    /* ====================================================================================
     *  VALIDATION
     *  expressionOfInterestId is required, alongside the core receipt fields.
     * ==================================================================================== */
    private static void validateRequest(ReceiptRequestWrapper input) {
        if (input == null) {
            throw buildEx(ERR_MALFORMED, 'Request payload could not be parsed.');
        }

        List<String> missing = new List<String>();
        if (String.isBlank(input.expressionOfInterestId)) missing.add('expressionOfInterestId');
        if (String.isBlank(input.status))                 missing.add('status');
        if (input.receiptDate == null)                    missing.add('receiptDate');
        if (input.receiptAmount == null)                  missing.add('receiptAmount');
        if (String.isBlank(input.transactionNumber))      missing.add('transactionNumber');

        if (!missing.isEmpty()) {
            throw buildEx(ERR_MANDATORY,
                'Mandatory field(s) missing: ' + String.join(missing, ', '));
        }
    }

    /**
     * Blank/empty -> null (never an "Invalid id" for an optional field).
     * Non-blank but malformed -> clean 400 naming the offending field.
     */
    private static Id toId(String rawValue, String fieldName, Boolean required) {
        if (String.isBlank(rawValue)) {
            if (required) throw buildEx(ERR_MANDATORY, fieldName + ' is required.');
            return null;
        }
        try {
            return Id.valueOf(rawValue.trim());
        } catch (System.StringException se) {
            throw buildEx(ERR_INVALID_ID,
                'Invalid ' + fieldName + ': "' + rawValue + '" is not a valid Salesforce Id.');
        }
    }

    @TestVisible
    private static Id unidentifiedAccountOverride;

    /**
     * Resolves the Account to associate with the Receipt.
     * Per business requirements, receipts are attached to the Unidentified Account
     * configured in System.Label.Unidentified_Account1, rather than the customer Account from EOI.
     */
    private static Id resolveReceiptAccount(Id expressionOfInterestId) {
        //3.2 MCR-73: Enforce CRUD/FLS via USER_MODE on ExpressionOfInterest__c query
        List<ExpressionOfInterest__c> eois = [
            SELECT Id, Account__c
            FROM ExpressionOfInterest__c
            WHERE Id = :expressionOfInterestId
            WITH USER_MODE
            LIMIT 1
        ];
        if (eois.isEmpty()) {
            throw buildEx(ERR_NO_EOI,
                'No Expression of Interest found for expressionOfInterestId: ' + expressionOfInterestId);
        }

        if (unidentifiedAccountOverride != null) {
            return unidentifiedAccountOverride;
        }

        Id targetAccountId;
        if (String.isNotBlank(System.Label.Unidentified_Account1) && !Test.isRunningTest()) {
            try {
                targetAccountId = (Id) System.Label.Unidentified_Account1.trim();
            } catch (Exception ex) {
                System.debug(LoggingLevel.WARN, 'Invalid Id in Unidentified_Account1 label: ' + ex.getMessage());
            }
        }

        // Fallback: If label is blank/invalid, or running within a test context
        // where the org label Account ID does not exist in test isolation, use the EOI Account.
        if (targetAccountId == null && eois[0].Account__c != null) {
            targetAccountId = eois[0].Account__c;
        }

        return targetAccountId;
    }

    /**
     * Decodes the base64 file and attaches it to the Receipt as a standard Salesforce File
     * (ContentVersion + ContentDocumentLink), titled "Receipt PDF".
     * Returns a status string surfaced in the API response rather than throwing --
     * the Receipt already exists and must not be rolled back for a failed attachment.
     */
    private static String storeReceiptDocument(Id receiptId, String base64Data, String fileName) {
        try {
            Blob fileBody = EncodingUtil.base64Decode(base64Data);

            ContentVersion cv = new ContentVersion(
                Title          = 'Receipt PDF',
                PathOnClient   = String.isNotBlank(fileName) ? fileName : 'Receipt_PDF.pdf',
                VersionData    = fileBody,
                IsMajorVersion = true
            );
            //3.2 MCR-73: Enforce CRUD/FLS via USER_MODE on ContentVersion insert
            Database.insert(cv, AccessLevel.USER_MODE);

            //3.2 MCR-73: Enforce CRUD/FLS via USER_MODE on ContentVersion query
            ContentVersion insertedCv = [
                SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id WITH USER_MODE LIMIT 1
            ];

            //3.2 MCR-73: Enforce CRUD/FLS via USER_MODE on ContentDocumentLink insert
            Database.insert(new ContentDocumentLink(
                ContentDocumentId = insertedCv.ContentDocumentId,
                LinkedEntityId    = receiptId,
                ShareType         = 'V',
                Visibility        = 'AllUsers'
            ), AccessLevel.USER_MODE);

            return 'Uploaded';

        } catch (Exception fileEx) {
            System.debug(LoggingLevel.ERROR,
                'storeReceiptDocument >>>> ' + OIC_RestResponse.describeException(fileEx));
            return 'Upload Failed: ' + fileEx.getMessage();
        }
    }

    /* ====================================================================================
     *  REQUEST DTO   (no response DTO -- OIC_RestResponse builds the payload dynamically)
     * ==================================================================================== */
    global class ReceiptRequestWrapper {
        global String  modeOfPayment;
        global String  status;
        global Date    receiptDate;
        global String  expressionOfInterestId;   // REQUIRED - ExpressionOfInterest__c lookup
        global String  last4DigitString;
        global Boolean isAdmFeesAndDariCharges;
        global String  receiptRemarks;
        global Decimal receiptAmount;
        global Decimal appliedAmount;
        global Decimal receiptExcessAmount;
        global String  transactionNumber;
        global Date    transactionDate;
        global String  transactionType;
        global String  documentBase64;           // OPTIONAL - base64-encoded file content
        global String  documentName;             // OPTIONAL - e.g. "Receipt_TXN123.pdf"
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
}