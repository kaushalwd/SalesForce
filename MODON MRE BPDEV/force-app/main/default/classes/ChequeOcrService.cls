/**********************************************************************************************************************
 * Name               : ChequeOcrService
 * Description        : Reads a cheque image into structured data, for a human to confirm.
 * Usage              : Queued from ChequeFileController; executed by ChequeOcrQueueable
 * Created By         : Modon
 * --------------------------------------------------------------------------------------------------------------------
 * Version       Author                              Date            Comment
 * 1.5           Aurelix Dev                         22 Sep 2026     Amounts come back as decimal numbers, e.g.
 *                                                                   771571.05. The prompt asked for "digits only,
 *                                                                   no separators", so the decimal point was dropped
 *                                                                   and AED 771,571.05 was read as 77,157,105.
 *                                                                   Approved by Mridul (Aurelix), 22 Sep.
 * 1.4           Aurelix Dev                         01 Sep 2026     MSC-205. The model also returns the number the
 *                                                                   words spell out (amountInWordsValue), so a
 *                                                                   words-vs-figures disagreement can be said.
 * 1.3           Aurelix Dev                         01 Sep 2026     MSC-197. applyRead is public: the console
 *                                                                   already holds a live read at record time and
 *                                                                   stamps it rather than paying for the same
 *                                                                   read twice. Same writes, same mismatch rule,
 *                                                                   no new pipeline.
 * 1.2           Aurelix IT                          19 Aug 2026     loadConfig() reads Named_Credential__c off the AI
 *                                                                   Service Config record, so Modon can rotate the key
 *                                                                   without a deploy. Same pipeline otherwise.
 * 1.1           Aurelix Developer                   18 Aug 2026     isConfigured() and readNow(): a synchronous,
 *                                                                   never-throwing read for the console's cheque sheet.
 *                                                                   Same pipeline as performRead minus every write.
 * 1.0           Aurelix IT                          06 Aug 2026     Initial.
 * --------------------------------------------------------------------------------------------------------------------
 * Modelled on MBP_aiservicerequest with five of its problems fixed: named credential instead of a literal key, mime
 * type derived, a JSON schema instead of a pipe-delimited string, an explicit status, and failures persisted.
 *
 * Never writes Amount__c, Cheque_No__c or any live field: everything lands in OCR_* staging for a person to accept.
 ******************************************************************************************************************/
public with sharing class ChequeOcrService {

    public class ChequeOcrException extends Exception {}

    private static final String CONFIG_NAME = 'Cheque_OCR';
    private static final String LOG_PROCESS = 'Cheque OCR';
    /** Holds both the host and the API key. See loadConfig(). */
    private static final String NAMED_CREDENTIAL = 'Cheque_OCR';

    public static final String STATUS_NOT_ATTEMPTED = 'Not Attempted';
    public static final String STATUS_PROCESSING    = 'Processing';
    public static final String STATUS_EXTRACTED     = 'Extracted';
    public static final String STATUS_FAILED        = 'Failed';
    public static final String STATUS_CONFIRMED     = 'Confirmed';

    /** Vendors commonly return this sentinel instead of an empty value. */
    private static final String NA = 'NA';

    private static final Map<String, String> EXT_TO_MIME = new Map<String, String>{
        'pdf'  => 'application/pdf',
        'png'  => 'image/png',
        'jpg'  => 'image/jpeg',
        'jpeg' => 'image/jpeg',
        'webp' => 'image/webp',
        'heic' => 'image/heic',
        'tif'  => 'image/tiff',
        'tiff' => 'image/tiff'
    };

    @TestVisible private static Boolean skipEnqueueForTest = false;

    // entry point

    /**
     * Marks the cheque Processing and queues the read. Never throws: a failure to start must not roll back
     * the upload that triggered it.
     */
    public static void requestRead(Id chequeId, Id contentDocumentId) {
        if (chequeId == null || contentDocumentId == null) {
            return;
        }
        try {
            update new Cheque_Details__c(
                Id            = chequeId,
                OCR_Status__c = STATUS_PROCESSING,
                OCR_Error__c  = null
            );

            // queueable, not @future: it chains, survives a longer window, and is what AdobePDFQueueable
            // already does here for the same 120s reason
            if (!skipEnqueueForTest && !Test.isRunningTest()) {
                System.enqueueJob(new ChequeOcrQueueable(chequeId, contentDocumentId));
            }
        } catch (Exception e) {
            logFailure(chequeId, 'Could not start the cheque read: ' + e.getMessage());
        }
    }

    // 1.1: the console's synchronous read

    /**
     * True when Modon has switched automatic reading on (the AI Service Config flag). A metadata read, so
     * cheap enough to ask before every staged image. Never throws.
     */
    public static Boolean isConfigured() {
        try {
            AI_Service_Config__mdt md = AI_Service_Config__mdt.getInstance(CONFIG_NAME);
            return md != null && md.Is_Active__c == true && String.isNotBlank(md.Model__c);
        } catch (Exception e) {
            return false;
        }
    }

    /**
     * One read, now, with nothing persisted: the rep is looking at empty number, date and amount boxes, and
     * a proposal is worth more then than a staged read written later. Same pipeline as performRead.
     *
     * Null on every failure and never an exception, so a read that cannot happen does not stop a cheque
     * being recorded by hand. Must be called before any DML (it is a callout).
     */
    public static ChequeRead readNow(Id contentDocumentId, Integer timeoutMs) {
        if (contentDocumentId == null || !isConfigured()) {
            return null;
        }
        try {
            ContentVersion cv = loadLatestVersion(contentDocumentId);
            if (cv == null) {
                return null;
            }
            String ext = String.isBlank(cv.FileExtension) ? 'jpg' : cv.FileExtension.toLowerCase();
            String mime = EXT_TO_MIME.get(ext);
            if (mime == null) {
                return null;
            }
            Blob body = cv.VersionData;
            if (body == null || body.size() == 0 || body.size() > 4 * 1024 * 1024) {
                return null;
            }
            OcrConfig cfg = loadConfig();
            if (timeoutMs != null && timeoutMs > 0 && timeoutMs < cfg.timeoutMs) {
                cfg.timeoutMs = timeoutMs;
            }
            String raw = callVisionModel(cfg, EncodingUtil.base64Encode(body), mime);
            return parseRead(raw);
        } catch (Exception e) {
            return null;
        }
    }

    // the read

    /** One extraction. Called from the queueable, so the callout is off a user's transaction. */
    public static void performRead(Id chequeId, Id contentDocumentId) {
        String rawResponse;
        try {
            ContentVersion cv = loadLatestVersion(contentDocumentId);
            if (cv == null) {
                logFailure(chequeId, 'The cheque image could not be found.');
                return;
            }

            String ext = String.isBlank(cv.FileExtension)
                ? 'jpg' : cv.FileExtension.toLowerCase();
            String mime = EXT_TO_MIME.get(ext);
            if (mime == null) {
                logFailure(chequeId,
                    'A ' + ext + ' file cannot be read automatically. Attach a JPG, PNG or PDF.');
                return;
            }

            Blob body = cv.VersionData;
            if (body == null || body.size() == 0) {
                logFailure(chequeId, 'The cheque image is empty.');
                return;
            }
            // heap guard: base64 inflates by ~33% and the async limit is 12 MB
            if (body.size() > 4 * 1024 * 1024) {
                logFailure(chequeId,
                    'This image is too large to read automatically. Retake it at a lower resolution.');
                return;
            }

            OcrConfig cfg = loadConfig();
            rawResponse = callVisionModel(cfg, EncodingUtil.base64Encode(body), mime);
            ChequeRead parsed = parseRead(rawResponse);
            applyRead(chequeId, parsed, rawResponse);

        } catch (Exception e) {
            logFailure(chequeId, e.getMessage());
            LoggerService.save(new List<Logger__c>{
                LoggerService.createApexLog(e, LOG_PROCESS, 'ChequeOcrService', 'performRead')
            });
        }
    }

    private static ContentVersion loadLatestVersion(Id contentDocumentId) {
        List<ContentVersion> cvs = [
            SELECT Id, Title, FileExtension, ContentSize, VersionData
            FROM ContentVersion
            WHERE ContentDocumentId = :contentDocumentId
            AND IsLatest = true
            LIMIT 1
        ];
        return cvs.isEmpty() ? null : cvs[0];
    }

    // configuration

    public class OcrConfig {
        public String path;
        public Integer timeoutMs = 120000;
        /** 1.2: which named credential carries the host and the key. */
        public String namedCredential = NAMED_CREDENTIAL;
    }

    /**
     * Endpoint and key live in the NAMED CREDENTIAL. Both nearby precedents are cautionary:
     * MBP_aiservicerequest has its key as a literal, and OIC_Credential__mdt stores passwords in plain text.
     * Custom Metadata holds only the non-secret parts: model, timeout, on/off.
     */
    private static OcrConfig loadConfig() {
        OcrConfig cfg = new OcrConfig();
        AI_Service_Config__mdt md = AI_Service_Config__mdt.getInstance(CONFIG_NAME);
        if (md == null || md.Is_Active__c != true) {
            throw new ChequeOcrException(
                'Automatic cheque reading is switched off. The image has been saved and the '
                + 'details can be entered by hand.');
        }
        if (String.isBlank(md.Model__c)) {
            throw new ChequeOcrException(
                'Automatic cheque reading is not configured yet. Ask an administrator to set the '
                + 'model on the "' + CONFIG_NAME + '" AI Service Config record.');
        }
        cfg.path = '/v1beta/models/' + md.Model__c.trim() + ':generateContent';
        /* 1.2: named on the record when Modon has given this service its own credential; blank keeps the default */
        if (String.isNotBlank(md.Named_Credential__c)) {
            cfg.namedCredential = md.Named_Credential__c.trim();
        }
        if (md.Timeout_Ms__c != null && md.Timeout_Ms__c > 0) {
            cfg.timeoutMs = Integer.valueOf(md.Timeout_Ms__c);
        }
        return cfg;
    }

    // callout

    /**
     * Asks for JSON only, with response_mime_type pinned. Two instructions carry the weight: null rather
     * than a guess, and both amounts read independently, since deriving one from the other would destroy
     * the strongest check a cheque offers.
     */
    private static String callVisionModel(OcrConfig cfg, String base64Data, String mimeType) {
        String prompt =
            'You are reading a single bank cheque, most likely issued in the United Arab Emirates. '
          + 'Cheques may be printed in English, Arabic, or both. '
          + 'Extract these fields exactly as printed or handwritten on the cheque:\n'
          // 1.5: amounts as plain decimal numbers; "digits only" made the model drop the decimal point
          + '  chequeNumber, amount (a plain decimal number such as 771571.05: keep the decimal point, '
          + 'remove only the currency symbol and thousands separators), '
          + 'amountInWords (verbatim), amountInWordsValue (the number that amountInWords spells '
          + 'out, as a plain decimal number in the same format; null if the words cannot be converted), '
          + 'chequeDate (yyyy-MM-dd), '
          + 'bankName, accountNumber, iban, payee.\n'
          + 'Rules:\n'
          + '1. If a field is not present or you cannot read it with confidence, return null for it. '
          + 'Never guess and never infer a value from another field.\n'
          + '2. Read "amount" and "amountInWords" INDEPENDENTLY. Do not derive one from the other, '
          + 'even if they appear to disagree - a disagreement is information we need.\n'
          + '3. Set "isCheque" to false if the image is not a cheque.\n'
          + '4. Set "legible" to false if the image is too blurred, cropped or dark to read reliably.\n'
          + '5. Keep fils: an amount written with a decimal part, such as 1,250.50, is 1250.50, never 125050.\n'
          + 'Respond with JSON only.';

        Map<String, Object> schema = new Map<String, Object>{
            'type' => 'OBJECT',
            'properties' => new Map<String, Object>{
                'isCheque'      => new Map<String, Object>{ 'type' => 'BOOLEAN' },
                'legible'       => new Map<String, Object>{ 'type' => 'BOOLEAN' },
                'chequeNumber'  => new Map<String, Object>{ 'type' => 'STRING', 'nullable' => true },
                'amount'        => new Map<String, Object>{ 'type' => 'STRING', 'nullable' => true },
                'amountInWords' => new Map<String, Object>{ 'type' => 'STRING', 'nullable' => true },
                'amountInWordsValue' => new Map<String, Object>{ 'type' => 'STRING', 'nullable' => true },
                'chequeDate'    => new Map<String, Object>{ 'type' => 'STRING', 'nullable' => true },
                'bankName'      => new Map<String, Object>{ 'type' => 'STRING', 'nullable' => true },
                'accountNumber' => new Map<String, Object>{ 'type' => 'STRING', 'nullable' => true },
                'iban'          => new Map<String, Object>{ 'type' => 'STRING', 'nullable' => true },
                'payee'         => new Map<String, Object>{ 'type' => 'STRING', 'nullable' => true }
            },
            'required' => new List<String>{ 'isCheque', 'legible' }
        };

        Map<String, Object> bodyMap = new Map<String, Object>{
            'contents' => new List<Object>{
                new Map<String, Object>{
                    'parts' => new List<Object>{
                        new Map<String, Object>{ 'text' => prompt },
                        new Map<String, Object>{
                            'inline_data' => new Map<String, Object>{
                                // derived from the actual file, not assumed
                                'mime_type' => mimeType,
                                'data'      => base64Data
                            }
                        }
                    }
                }
            },
            'generationConfig' => new Map<String, Object>{
                'response_mime_type' => 'application/json',
                'response_schema'    => schema,
                // extraction, not composition
                'temperature'        => 0
            }
        };

        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:' + cfg.namedCredential + cfg.path);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        // the platform merges the key in from the named credential, so it never appears here or in a log
        req.setHeader('x-goog-api-key', '{!$Credential.Password}');
        req.setTimeout(cfg.timeoutMs);
        req.setBody(JSON.serialize(bodyMap));

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 200) {
            throw new ChequeOcrException(
                'The cheque reading service returned ' + res.getStatusCode()
                + '. The image has been saved; the read can be retried.');
        }
        return res.getBody();
    }

    // parsing

    public class ChequeRead {
        public Boolean isCheque = true;
        public Boolean legible = true;
        public String chequeNumber;
        public Decimal amount;
        public String amountInWords;
        /** 1.4: what the words spell out, as a number; null when the model could not convert. */
        public Decimal amountInWordsValue;
        public Date chequeDate;
        public String bankName;
        public String accountNumber;
        public String iban;
        public String payee;
    }

    /** Digs the model's text part out of the envelope and deserialises it: structured output still arrives
     *  as a string inside candidates[0]. */
    @TestVisible
    private static ChequeRead parseRead(String responseBody) {
        Map<String, Object> root =
            (Map<String, Object>) JSON.deserializeUntyped(responseBody);

        List<Object> candidates = (List<Object>) root.get('candidates');
        if (candidates == null || candidates.isEmpty()) {
            throw new ChequeOcrException('The cheque reading service returned nothing to read.');
        }
        Map<String, Object> content =
            (Map<String, Object>) ((Map<String, Object>) candidates[0]).get('content');
        List<Object> parts = content == null ? null : (List<Object>) content.get('parts');
        if (parts == null || parts.isEmpty()) {
            throw new ChequeOcrException('The cheque reading service returned an empty result.');
        }
        String payload = String.valueOf(((Map<String, Object>) parts[0]).get('text'));
        if (String.isBlank(payload)) {
            throw new ChequeOcrException('The cheque reading service returned an empty result.');
        }

        Map<String, Object> data =
            (Map<String, Object>) JSON.deserializeUntyped(payload);

        ChequeRead r = new ChequeRead();
        r.isCheque      = boolOf(data.get('isCheque'), true);
        r.legible       = boolOf(data.get('legible'), true);
        r.chequeNumber  = clean(data.get('chequeNumber'));
        r.amountInWords = clean(data.get('amountInWords'));
        r.bankName      = clean(data.get('bankName'));
        r.accountNumber = clean(data.get('accountNumber'));
        r.iban          = clean(data.get('iban'));
        r.payee         = clean(data.get('payee'));
        r.amount        = decimalOf(clean(data.get('amount')));
        r.amountInWordsValue = decimalOf(clean(data.get('amountInWordsValue')));
        r.chequeDate    = dateOf(clean(data.get('chequeDate')));
        return r;
    }

    /** Trims, and treats the vendor 'NA' sentinel as absent. */
    private static String clean(Object raw) {
        if (raw == null) return null;
        String s = String.valueOf(raw).trim();
        if (s == '' || s.equalsIgnoreCase(NA) || s.equalsIgnoreCase('null')) return null;
        return s;
    }

    private static Boolean boolOf(Object raw, Boolean fallback) {
        if (raw == null) return fallback;
        if (raw instanceof Boolean) return (Boolean) raw;
        return String.valueOf(raw).equalsIgnoreCase('true');
    }

    private static Decimal decimalOf(String raw) {
        if (String.isBlank(raw)) return null;
        // strip anything that is not part of a number: separators and a currency prefix are both common
        String digits = raw.replaceAll('[^0-9.\\-]', '');
        if (String.isBlank(digits)) return null;
        try {
            return Decimal.valueOf(digits);
        } catch (Exception e) {
            return null;
        }
    }

    private static Date dateOf(String raw) {
        if (String.isBlank(raw)) return null;
        try {
            // the prompt asks for yyyy-MM-dd; anything else is unread rather than guessed, since dd/MM and
            // MM/dd are indistinguishable for the first twelve days of a month
            List<String> p = raw.split('-');
            if (p.size() != 3) return null;
            return Date.newInstance(
                Integer.valueOf(p[0]), Integer.valueOf(p[1]), Integer.valueOf(p[2]));
        } catch (Exception e) {
            return null;
        }
    }

    // persisting: staging fields only

    /**
     * 1.3: public so a caller holding a read of its own (the console reads the image while the rep
     * is still filling the form) can stamp it without a second callout. Writes exactly what
     * performRead writes, mismatch rule included; still never touches a live field.
     */
    @TestVisible
    public static void applyRead(Id chequeId, ChequeRead r, String rawResponse) {
        if (r.isCheque == false) {
            logFailure(chequeId, 'That image does not look like a cheque. Please capture the cheque itself.');
            return;
        }
        if (r.legible == false) {
            logFailure(chequeId,
                'The cheque could not be read clearly. Retake it in better light, filling the frame.');
            return;
        }

        List<Cheque_Details__c> existing = [
            SELECT Id, Amount__c, Amount_in_Words__c, Cheque_No__c
            FROM Cheque_Details__c
            WHERE Id = :chequeId
            LIMIT 1
        ];
        if (existing.isEmpty()) {
            return;
        }

        Cheque_Details__c upd = new Cheque_Details__c(Id = chequeId);
        upd.OCR_Cheque_No__c        = r.chequeNumber;
        upd.OCR_Amount__c           = r.amount;
        upd.OCR_Amount_In_Words__c  = r.amountInWords;
        upd.OCR_Cheque_Date__c      = r.chequeDate;
        upd.OCR_Bank__c             = r.bankName;
        upd.OCR_Account_Number__c   = r.accountNumber;
        upd.OCR_IBAN__c             = r.iban;
        upd.OCR_Payee__c            = r.payee;
        upd.OCR_Status__c           = STATUS_EXTRACTED;
        upd.OCR_Read_On__c          = System.now();
        upd.OCR_Error__c            = null;
        upd.OCR_Mismatch__c         = hasMismatch(existing[0], r);
        // archive what the service said, not only what was mapped: the only way to settle a dispute later
        upd.OCR_Extracted_JSON__c   = truncate(rawResponse, 32768);

        try {
            update upd;
        } catch (Exception e) {
            logFailure(chequeId, e.getMessage());
        }
    }

    /**
     * Flags anything worth a second pair of eyes. The written amount is the control on the numeric one,
     * which is why banks print both, so a disagreement must surface rather than resolve itself.
     */
    @TestVisible
    private static Boolean hasMismatch(Cheque_Details__c current, ChequeRead r) {
        if (r.amount == null) {
            // nothing to reconcile against: an incomplete read, not a mismatch
            return false;
        }
        if (current.Amount__c != null && current.Amount__c.setScale(2) != r.amount.setScale(2)) {
            return true;
        }
        if (String.isNotBlank(r.amountInWords) && !wordsAgreeWithFigure(r.amountInWords, r.amount)) {
            return true;
        }
        return false;
    }

    /**
     * Conservative by design: it judges only when the words contain digits. A false mismatch on every
     * cheque would train reviewers to dismiss the flag.
     */
    private static Boolean wordsAgreeWithFigure(String words, Decimal figure) {
        String digits = words.replaceAll('[^0-9]', '');
        if (String.isBlank(digits)) {
            return true;
        }
        try {
            Decimal fromWords = Decimal.valueOf(digits);
            return fromWords == figure.setScale(0, System.RoundingMode.DOWN)
                || fromWords == figure;
        } catch (Exception e) {
            return true;
        }
    }

    private static String truncate(String s, Integer max) {
        if (String.isBlank(s)) return s;
        return s.length() > max ? s.substring(0, max) : s;
    }

    /** Failures land on the record in words an operations user can act on; MBP_aiservicerequest writes
     *  them to System.debug, where nobody sees them. */
    @TestVisible
    private static void logFailure(Id chequeId, String message) {
        if (chequeId == null) return;
        try {
            update new Cheque_Details__c(
                Id            = chequeId,
                OCR_Status__c = STATUS_FAILED,
                OCR_Error__c  = truncate(message, 1000),
                OCR_Read_On__c = System.now()
            );
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR,
                'ChequeOcrService: could not record failure on ' + chequeId + ' - ' + e.getMessage());
        }
    }
}