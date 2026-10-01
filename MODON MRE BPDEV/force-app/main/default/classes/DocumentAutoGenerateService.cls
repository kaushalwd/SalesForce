/**********************************************************************************************************************
* Name               : DocumentAutoGenerateService                                                        
* Description        : Auto generates Nintex document on Documents__c insert
*                      Uses DrawloopHelper — same as BusinessProcessNintexDocumentGeneration
* Usage              : Called from DocumentTriggerHelper.autoGenerateAndSendDocument
* --------------------------------------------------------------------------------------------------------------------
* Version       Author          Date            Comment                                                                       
* 2.0           Aurelix IT      10 Sep 2026     BP-047. Callouts first, one write afterwards. Writing the
*                                               status inside the loop made every document after the first
*                                               fail with "uncommitted work pending", because Apex forbids a
*                                               callout once DML has run in the same transaction. This is what
*                                               forced EOIs to be created one per transaction.
* 1.0           Arvind     20 May 2026     Initial Draft     
**********************************************************************************************************************/
public without sharing class DocumentAutoGenerateService {

    @future(callout=true)
    public static void generateAndSend(Set<Id> documentIds) {

        if (documentIds == null || documentIds.isEmpty()) return;

        List<Documents__c> documents = [
            SELECT Id,
                   Name,
                   Customer_Email__c
            FROM Documents__c
            WHERE Id IN :documentIds
        ];

        if (documents == null || documents.isEmpty()) return;

        Set<String> docNames = new Set<String>();
        for (Documents__c doc : documents) {
            if (String.isNotBlank(doc.Name)) docNames.add(doc.Name);
        }

        List<Document_Master_Configuration__mdt> configs = [
            SELECT Id,
                   DocumentDisplayName__c,
                   DocumentAPIName__c,
                   ObjectAPIName__c,
                   DocGen_Package_Name__c,
                   Delivery_Option_Name__c,
                   Auto_Generate_Document__c,
                   Auto_Send_DocuSign_Email__c
            FROM Document_Master_Configuration__mdt
            WHERE DocumentDisplayName__c IN :docNames
            AND   DocumentAPIName__c     != null
            AND   DocumentDisplayName__c != null
        ];

        if (configs == null || configs.isEmpty()) {
            System.debug('No metadata config found for: ' + docNames);
            return;
        }

        Map<String, Document_Master_Configuration__mdt> nameToConfig =
            new Map<String, Document_Master_Configuration__mdt>();
        for (Document_Master_Configuration__mdt config : configs) {
            nameToConfig.put(config.DocumentDisplayName__c, config);
        }

        // BP-047: results are collected here and written ONCE after every callout has finished.
        // Writing inside the loop is what made the second document fail: Apex forbids a callout
        // after DML in the same transaction, so document 2 died with "uncommitted work pending"
        // (seen live twice on 6 Sep 2026). Nothing else in this class performs DML.
        Map<Id, String> statusById = new Map<Id, String>();
        Map<Id, String> errorById  = new Map<Id, String>();
        Integer timeoutMs = calloutTimeoutMs(documents.size());

        for (Documents__c doc : documents) {

            Document_Master_Configuration__mdt config = nameToConfig.get(doc.Name);
            if (config == null) {
                System.debug('No metadata config for: ' + doc.Name);
                continue;
            }

            try {

                // ─────────────────────────────────────────────
                // GATE 1 — Auto_Generate_Document__c must be true
                // ─────────────────────────────────────────────
                if (config.Auto_Generate_Document__c != true) {
                    System.debug('Auto_Generate_Document__c = false. Skipping: '
                        + doc.Name); continue;
                }

                if (String.isBlank(config.DocGen_Package_Name__c)) {
                    recordError(statusById, errorById, doc.Id, 'DocGen_Package_Name__c is blank in metadata for: ' + doc.Name);
                    continue;
                }

                // ─────────────────────────────────────────────
                // STEP 1 — Generate PDF using DrawloopHelper
                // ─────────────────────────────────────────────
                String url = DrawloopHelper.GetDrawloopURL(
                    'Documents',
                    'Documents__c',
                    config.DocGen_Package_Name__c,
                    doc.Id
                );

                if (String.isBlank(url)) {
                    recordError(statusById, errorById, doc.Id, 'DrawloopHelper returned blank URL for: ' + doc.Name);
                    continue;
                }
                if (url.contains('?')) { url += '&format=PDF&download=1'; } else { url += '?format=PDF&download=1'; }

                Http http = new Http();
                HttpRequest req = new HttpRequest();
                req.setTimeout(timeoutMs);
                req.setEndpoint(url);
                req.setMethod('GET');
                HttpResponse res = http.send(req);

                System.debug('Drawloop status: ' + res.getStatusCode());
                System.debug('Drawloop body start: ' + res.getBody().left(200));

                if (res.getStatusCode() != 200) {
                    recordError(statusById, errorById, doc.Id,
                        'Drawloop HTTP failed. Status: ' + res.getStatusCode() + ' | ' + res.getBody().left(200));
                    continue;
                }
                // ─────────────────────────────────────────────
                // STEP 2 — Extract PDF blob
                // ─────────────────────────────────────────────
                Blob finalBlob = null; Boolean isPdf = false; String respBody = res.getBody();
                if (respBody != null && respBody.startsWith('<head')) {
                    finalBlob = extractPdfFromHtml(respBody, url, http, timeoutMs);
                    if (finalBlob != null && finalBlob.size() > 0) isPdf = true;
                } else {
                    finalBlob = res.getBodyAsBlob();
                    if (finalBlob != null && finalBlob.size() > 4 && respBody.substring(0, 4).equals('%PDF')) {
                        isPdf = true;
                    }
                }

                if (finalBlob == null || !isPdf) {
                    recordError(statusById, errorById, doc.Id, 'Failed to get valid PDF from Drawloop for: ' + doc.Name);
                    continue;
                }

                System.debug('PDF generated successfully for: ' + doc.Name
                    + ' | Size: ' + finalBlob.size());

                // ─────────────────────────────────────────────
                // STEP 3 — Remember the outcome; the write happens after the loop
                // DocuSign send removed — will be added later
                // ─────────────────────────────────────────────
                statusById.put(doc.Id, 'Generated');
                errorById.put(doc.Id, null);

            } catch (Exception e) {
                System.debug('ERROR | Document: ' + doc.Id
                    + ' | ' + e.getMessage()
                    + ' | Line: ' + e.getLineNumber()
                    + ' | Stack: ' + e.getStackTraceString());
                recordError(statusById, errorById, doc.Id, e.getMessage());
            }
        }

        // One write for every document, after the last callout. Same field values the per-document
        // helpers wrote before, so downstream automation on Documents__c sees exactly what it saw
        // before - just once with N rows instead of N times with one row.
        commitOutcomes(statusById, errorById);
    }


    // ─────────────────────────────────────────────────────────────
    // EXTRACT PDF FROM HTML
    // Changed from private to public for test coverage
    // ─────────────────────────────────────────────────────────────
    /** BP-047: the per-request timeout is passed in so the second callout shares the same
     *  transaction budget as the first. The three-argument form is kept for existing callers. */
    public static Blob extractPdfFromHtml(
        String htmlContent,
        String originalUrl,
        Http   http
    ) {
        return extractPdfFromHtml(htmlContent, originalUrl, http, DEFAULT_TIMEOUT_MS);
    }

    public static Blob extractPdfFromHtml(
        String htmlContent,
        String originalUrl,
        Http   http,
        Integer timeoutMs
    ) {
        try {
            Pattern downloadPattern = Pattern.compile('href="(/download/[^"]+)"');
            Matcher matcher = downloadPattern.matcher(htmlContent);

            if (matcher.find()) {
                String   relativePath = matcher.group(1);
                String[] urlParts     = originalUrl.split('/');
                String   baseUrl      = urlParts[0] + '//' + urlParts[2];
                String   downloadUrl  = baseUrl + relativePath;

                System.debug('Download link found: ' + downloadUrl);

                HttpRequest pdfReq = new HttpRequest();
                pdfReq.setTimeout(timeoutMs);
                pdfReq.setEndpoint(downloadUrl);
                pdfReq.setMethod('GET');

                HttpResponse pdfRes = http.send(pdfReq);
                System.debug('PDF download status: ' + pdfRes.getStatusCode());

                if (pdfRes.getStatusCode() == 200) {
                    Blob pdfBlob = pdfRes.getBodyAsBlob();
                    if (pdfBlob != null
                        && pdfBlob.size() > 0
                        && pdfRes.getBody().substring(0, 4).equals('%PDF')) {
                        return pdfBlob;
                    }
                }

            } else {
                System.debug('No /download/ link found. HTML length: '
                    + htmlContent.length());
                Integer chunkSize = 500;
                for (Integer i = 0;
                     i < Math.min(htmlContent.length(), 3000);
                     i += chunkSize) {
                    Integer endIndex = Math.min(i + chunkSize, htmlContent.length());
                    System.debug('HTML[' + i + ']: '
                        + htmlContent.substring(i, endIndex));
                }
            }

        } catch (Exception e) {
            System.debug('Error in extractPdfFromHtml: ' + e.getMessage());
        }
        return null;
    }


    // ─────────────────────────────────────────────────────────────
    // BP-047 HELPERS
    // ─────────────────────────────────────────────────────────────

    /** Apex allows 120 seconds of callout time per transaction in total, and each document can make
     *  two callouts (render, then download). A single document keeps the original 120s so today's
     *  behaviour is unchanged; a batch shares the budget, with a floor so a slow render still has a
     *  fair chance. Batches larger than three still risk the ceiling - the durable answer for high
     *  volume is one document per job, which is deliberately out of scope here. */
    @TestVisible private static final Integer DEFAULT_TIMEOUT_MS = 120000;
    @TestVisible private static final Integer MIN_TIMEOUT_MS     = 20000;
    @TestVisible private static final Integer CALLOUTS_PER_DOC   = 2;

    @TestVisible
    private static Integer calloutTimeoutMs(Integer documentCount) {
        if (documentCount == null || documentCount <= 1) {
            return DEFAULT_TIMEOUT_MS;
        }
        Integer share = DEFAULT_TIMEOUT_MS / (documentCount * CALLOUTS_PER_DOC);
        return share < MIN_TIMEOUT_MS ? MIN_TIMEOUT_MS : share;
    }

    /** Remembers a failure instead of writing it, so the next document may still call out. */
    @TestVisible
    private static void recordError(Map<Id, String> statusById, Map<Id, String> errorById, Id documentId, String message) {
        if (documentId == null) {
            return;
        }
        System.debug('Document generation failed for ' + documentId + ': ' + message);
        statusById.put(documentId, 'Error');
        errorById.put(documentId, String.isNotBlank(message) ? message.left(255) : 'Unknown error');
    }

    /** The single write. Never throws: a failure here must not lose the PDFs already produced,
     *  and the document rows can be re-driven. Mirrors updateStatus / logError field for field. */
    @TestVisible
    private static void commitOutcomes(Map<Id, String> statusById, Map<Id, String> errorById) {
        if (statusById == null || statusById.isEmpty()) {
            return;
        }
        Map<Id, String> errors = errorById == null ? new Map<Id, String>() : errorById;
        List<Documents__c> toUpdate = new List<Documents__c>();
        for (Id documentId : statusById.keySet()) {
            toUpdate.add(new Documents__c(
                Id                        = documentId,
                Document_Status__c        = statusById.get(documentId),
                Document_Error_Message__c = errors.get(documentId)
            ));
        }
        try {
            update toUpdate;
        } catch (DmlException e) {
            System.debug('Failed to write document outcomes: ' + e.getMessage());
        }
    }


    // ─────────────────────────────────────────────────────────────
    // UPDATE STATUS
    // ─────────────────────────────────────────────────────────────
    public static void updateStatus(Id documentId, String status) {
        if (documentId == null) return;
        try {
            update new Documents__c(
                Id                        = documentId,
                Document_Status__c        = status,
                Document_Error_Message__c = null
            );
        } catch (DmlException e) {
            System.debug('Failed to update status: ' + e.getMessage());
        }
    }


    // ─────────────────────────────────────────────────────────────
    // ERROR LOGGER
    // ─────────────────────────────────────────────────────────────
    public static void logError(Id documentId, String errorMessage) {
        if (documentId == null) return;
        try {
            update new Documents__c(
                Id                        = documentId,
                Document_Status__c        = 'Error',
                Document_Error_Message__c = String.isNotBlank(errorMessage)
                    ? errorMessage.left(255)
                    : 'Unknown error'
            );
        } catch (DmlException e) {
            System.debug('Failed to log error: ' + e.getMessage());
        }
    }

}