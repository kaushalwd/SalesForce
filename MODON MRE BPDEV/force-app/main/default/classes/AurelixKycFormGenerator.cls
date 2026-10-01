/**
 * AurelixKycFormGenerator - produce the KYC form PDF for a buyer, on request, through MODON's own
 * Nintex plumbing.
 *
 * Version  Author       Date         Detail
 * 1.7      Aurelix Dev  29 Sep 2026  Regeneration (AurelixKycGenerationGate 2.3): only a file filed since this render
 *                                    began counts as Nintex's, else the download is stored. claimForMarking stands
 *                                    down if status, envelope id or requested flag moved since the gate read them.
 * 1.6      Aurelix Dev  29 Sep 2026  Sends on every generation, once: claimForMarking sets Pending under a lock, then
 *                                    MarkGenerated sets Generated (clearing the old EnvelopID__c when sending), so
 *                                    MODON's autoSendDocuSign fires once per request. Adds resetStatusToPending.
 * 1.5      Aurelix Dev  28 Sep 2026  generateForParty, for the joint owner's manual KYC route.
 *                                    The same gate, package and render on the joint owner's own "KYC Form" row,
 *                                    but NEVER the automated DocuSign send: MODON's queueable addresses
 *                                    Documents__c.Customer_Email__c, a formula over Opportunity__r.PrimaryContact__r,
 *                                    so linking a joint owner's row to the booking would send their form to the
 *                                    BUYER. The row is not linked and Auto_Send stays false. In the Sales App the
 *                                    form is sent with "KYC Manual Sign", whose envelope configuration addresses
 *                                    the row's own contact ({!Documents__c.PrimaryContact__r.Email}); the rep is
 *                                    told to use it. generate(opportunityId) is unchanged in behaviour.
 * 1.4      Aurelix Dev  27 Sep 2026  Companies too, as in MODON's Sales App (AurelixKycGenerationGate 2.0). The
 *                                    render is unchanged: the same package, "KYC Form Manual", run on the POA
 *                                    Contact's "KYC Form" row, where Nintex picks its corporate file ("KYC
 *                                    Corporate (2) - Copy (1)") because the row's contact is not a person
 *                                    account. The DocuSign request still resolves through
 *                                    Opportunity__r.PrimaryContact__r.Email, which for a company is the POA.
 * 1.3      Aurelix Dev  18 Sep 2026  Seen on the second live run: the PDF landed, the row was
 *                                    flagged, the status turned Generated - and no envelope went
 *                                    out. MODON's TriggerHandler base keeps processedIds per
 *                                    transaction and filters a record out of any later trigger
 *                                    pass, so the status write (a second update of the same row)
 *                                    was invisible to autoSendDocuSign. The marking is now ONE
 *                                    update - flags, booking link, Document_Status__c = Generated
 *                                    and a cleared error - run in a fresh transaction by a small
 *                                    queueable, so their afterUpdate sees the change once and
 *                                    publishes the DocuSign request. Their updateStatus is no
 *                                    longer called; the same two fields are written with the
 *                                    same values.
 * 1.2      Aurelix Dev  18 Sep 2026  DocuSign: MODON's DocumentAutoSendDocuSignQueueable addresses
 *                                    the envelope to Documents__c.Customer_Email__c, a FORMULA
 *                                    (Opportunity__r.PrimaryContact__r.Email), and names it from
 *                                    CustomerName__c, also a formula over the row's parents. The
 *                                    rows MODON's creators make carry no Opportunity, so both are
 *                                    blank and their queueable skips with "No Customer Email".
 *                                    When the auto-send switch is on, the generator now links the
 *                                    row to the booking (Opportunity__c) before the status turns
 *                                    Generated, so both formulas resolve, and refuses when the
 *                                    booking's primary contact has no email.
 * 1.1      Aurelix Dev  18 Sep 2026  Seen on the first live run (06:46Z): Nintex's own
 *                                    delivery option had already attached "KYC Form Manual
 *                                    <name>.pdf" to the row (as the integration user) by the time
 *                                    the download returned, so the copy this class stored was a
 *                                    duplicate. The PDF is now stored only when the row carries no
 *                                    file after the render - a fallback, not the rule.
 * 1.0      Aurelix Dev  18 Sep 2026  MSC-178 (B7, generation). Replaces the Phase 3B "one-flag
 *                                    route", which could never work: DocumentTriggerHandler runs
 *                                    autoGenerateAndSendDocument on AFTER INSERT only, so flipping
 *                                    Auto_Generate_Document__c by update generated nothing; and the
 *                                    route the EOI portal uses (the flag on the template row) would
 *                                    fire Nintex for every new customer the moment their rows are
 *                                    created, because DocumentsUtility copies that flag onto every
 *                                    new row. So the console generates ON REQUEST, and only what
 *                                    the gate allows:
 *                                      1 AurelixKycGenerationGate.check must say canGenerate
 *                                      2 DrawloopHelper.GetDrawloopURL('Documents','Documents__c',
 *                                        package, rowId) - MODON's helper, which resolves the
 *                                        Loop__DDP__c by name and object and signs the request
 *                                        (SessionOAuthHelper) - unchanged
 *                                      3 the same GET their DocumentAutoGenerateService makes
 *                                        (format=PDF&download=1), and their extractPdfFromHtml
 *                                        when Nintex answers with a page instead of a file
 *                                      4 the PDF is on the "KYC Form" row: Nintex's delivery
 *                                        option attaches it during the render; if it did not,
 *                                        the downloaded PDF is stored here as a fallback
 *                                      5 the row is marked requested (Auto_Generate_Document__c,
 *                                        which by update triggers nothing) and, only if the
 *                                        console switch KYC_FORM_AUTO_SEND_DOCUSIGN is on, flagged
 *                                        Auto_Send_DocuSign_Email__c BEFORE the status turns
 *                                        Generated, so MODON's afterUpdate raises the envelope
 *                                      6 Document_Status__c = Generated, their status vocabulary,
 *                                        written in a fresh transaction (1.3)
 *                                    The package name comes from MODON's template row
 *                                    (Document_Master_Configuration.KYC Form, DocGen_Package_Name__c)
 *                                    when they fill it, else from the console's own switch
 *                                    KYC_FORM_DOCGEN_PACKAGE (Sales_Console_Config__mdt.Value__c).
 *
 * OWNERSHIP. Aurelix-owned. DrawloopHelper, SessionOAuthHelper, DocumentAutoGenerateService and
 * Document_Master_Configuration__mdt are MODON's and are called or read, never changed.
 */
public with sharing class AurelixKycFormGenerator {

    public static final String CONFIG_PACKAGE   = 'KYC_FORM_DOCGEN_PACKAGE';
    public static final String CONFIG_AUTO_SEND = 'KYC_FORM_AUTO_SEND_DOCUSIGN';
    public static final String TEMPLATE_OBJECT  = 'PersonAccount';
    public static final String TEMPLATE_NAME    = 'KYC Form';
    public static final String STATUS_GENERATED = 'Generated';
    /* 1.6 - MODON's pre-generation value on the same restricted picklist */
    public static final String STATUS_PENDING   = 'Pending';
    /* 1.6 - the gate's own sentence for a request that already stands */
    public static final String ALREADY_REQUESTED = AurelixKycGenerationGate.ALREADY_REQUESTED;
    /* MODON's service uses 120 s per document; the render can take most of it. */
    public static final Integer TIMEOUT_MS = 120000;

    /** Tests: skip DrawloopHelper (needs a live Loop__DDP__c and a token) and hit the mock directly. */
    @TestVisible private static String urlOverride;
    @TestVisible private static String packageOverride;
    @TestVisible private static Boolean autoSendOverride;

    public class ResultDTO {
        @AuraEnabled public Boolean success = false;
        @AuraEnabled public String message;
        @AuraEnabled public Id documentId;
        @AuraEnabled public Id fileId;
        @AuraEnabled public Boolean sentForSignature = false;
    }

    /** MODON's template row first, the console switch second; null when neither names a package. */
    public static String packageName() {
        if (packageOverride != null) { return String.isBlank(packageOverride) ? null : packageOverride; }
        for (Document_Master_Configuration__mdt t : [
            SELECT DocGen_Package_Name__c
            FROM Document_Master_Configuration__mdt
            WHERE ObjectAPIName__c = :TEMPLATE_OBJECT AND DocumentDisplayName__c = :TEMPLATE_NAME
            LIMIT 1
        ]) {
            if (String.isNotBlank(t.DocGen_Package_Name__c)) { return t.DocGen_Package_Name__c.trim(); }
        }
        Sales_Console_Config__mdt cfg = Sales_Console_Config__mdt.getInstance(CONFIG_PACKAGE);
        if (cfg != null && cfg.Is_Active__c == true && String.isNotBlank(cfg.Value__c)) {
            return cfg.Value__c.trim();
        }
        return null;
    }

    /** Is a package named anywhere? The gate reads this. */
    public static Boolean configured() {
        return String.isNotBlank(packageName());
    }

    private static Boolean autoSend() {
        if (autoSendOverride != null) { return autoSendOverride; }
        Sales_Console_Config__mdt cfg = Sales_Console_Config__mdt.getInstance(CONFIG_AUTO_SEND);
        return cfg != null && cfg.Is_Active__c == true;
    }

    /**
     * Generate the KYC form for the buyer on this booking. Refused with the gate's own sentence
     * when it may not run. One Nintex render, one stored PDF, one status write.
     */
    @AuraEnabled
    public static ResultDTO generate(Id opportunityId) {
        AurelixKycGenerationGate.GateDTO gate = AurelixKycGenerationGate.check(opportunityId);
        if (gate.applicable != true) {
            throw new AuraHandledException('This booking has no customer contact to generate the KYC form for.');
        }
        Boolean send = autoSend();
        /* the missing-email refusal still comes after the render, as before 1.5 (see render) */
        return render(gate, customerNameFor(opportunityId), opportunityId, send,
            send ? customerEmailFor(opportunityId) : null);
    }

    /**
     * 1.5: the joint owner's form, on their own contact's "KYC Form" row. Rendered and filed only:
     * never linked to a booking and never sent by the automated route (see the header).
     */
    public static ResultDTO generateForParty(Id contactId, String customerName) {
        AurelixKycGenerationGate.GateDTO gate = AurelixKycGenerationGate.checkContact(contactId);
        if (gate.applicable != true) {
            throw new AuraHandledException('This person has no contact record to generate the KYC form for.');
        }
        ResultDTO out = render(gate, customerName, null, false, null);
        out.message = PARTY_GENERATED;
        return out;
    }

    /** 1.5: what the rep is told after a joint owner's form is produced. */
    public static final String PARTY_GENERATED =
        'KYC form generated. Send it for signature with KYC Manual Sign on the KYC Form document.';

    /**
     * 1.5: the render, the store and the marking, shared by both routes. linkOpportunityId and
     * sendEmail matter only when send is true (the buyer's route).
     */
    private static ResultDTO render(
        AurelixKycGenerationGate.GateDTO gate, String customerName,
        Id linkOpportunityId, Boolean send, String sendEmail
    ) {
        if (gate.canGenerate != true) {
            throw new AuraHandledException('The KYC form cannot be generated yet. '
                + (String.isBlank(gate.blockedReason) ? '' : gate.blockedReason));
        }
        String pkg = packageName();
        if (String.isBlank(pkg)) {
            throw new AuraHandledException('Form generation is not configured yet.');
        }
        Id documentId = gate.documentId;
        /* 1.7 - files from here on are this render's (less 1 s: stored dates have whole seconds) */
        Datetime renderStart = Datetime.now().addSeconds(-1);

        /* ── the render, exactly as MODON's service does it ─────────────────── */
        String url;
        try {
            url = urlOverride != null
                ? urlOverride
                : DrawloopHelper.GetDrawloopURL('Documents', 'Documents__c', pkg, documentId);
        } catch (Exception e) {
            fail(documentId, 'Nintex could not be reached: ' + e.getMessage());
        }
        if (String.isBlank(url)) {
            fail(documentId, 'Nintex returned no run address for package "' + pkg + '".');
        }
        url += url.contains('?') ? '&format=PDF&download=1' : '?format=PDF&download=1';

        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setTimeout(TIMEOUT_MS);
        req.setEndpoint(url);
        req.setMethod('GET');
        HttpResponse res;
        try {
            res = http.send(req);
        } catch (Exception e) {
            fail(documentId, 'The Nintex call failed: ' + e.getMessage());
        }
        if (res.getStatusCode() != 200) {
            fail(documentId, 'Nintex answered ' + res.getStatusCode() + '.');
        }
        Blob pdf = null;
        String body = res.getBody();
        if (body != null && body.startsWith('<head')) {
            pdf = DocumentAutoGenerateService.extractPdfFromHtml(body, url, http, TIMEOUT_MS);
        } else {
            Blob raw = res.getBodyAsBlob();
            if (raw != null && raw.size() > 4 && body.substring(0, 4) == '%PDF') { pdf = raw; }
        }
        if (pdf == null || pdf.size() == 0) {
            fail(documentId, 'Nintex did not return a PDF.');
        }

        /* ── store it, mark the row, then let MODON's status write run ───────── */
        ResultDTO out = new ResultDTO();
        out.documentId = documentId;
        Boolean claimed = true;
        try {
            /* 1.1 - Nintex's delivery option normally files the PDF itself during the render;
               store the download only when the row still carries nothing
               1.7 - nothing FROM THIS RENDER: last round's files do not count */
            List<ContentDocumentLink> landed = [
                SELECT ContentDocumentId FROM ContentDocumentLink
                WHERE LinkedEntityId = :documentId AND ContentDocument.CreatedDate >= :renderStart
                ORDER BY ContentDocument.CreatedDate DESC LIMIT 1
            ];
            if (landed.isEmpty()) {
                ContentVersion cv = new ContentVersion(
                    Title = 'KYC Form - ' + (String.isBlank(customerName) ? 'customer' : customerName),
                    PathOnClient = 'KYC-Form.pdf',
                    VersionData = pdf,
                    FirstPublishLocationId = documentId);
                insert cv;
                out.fileId = cv.Id;
            } else {
                out.fileId = landed[0].ContentDocumentId;
            }

            if (send == true && String.isBlank(sendEmail)) {
                throw new AuraHandledException('The form was generated, but the customer has no email address for the signature request.');
            }
            /* 1.3 - one update, in its own transaction (see the header): flags, the booking link
               the email/name formulas resolve through, and MODON's status vocabulary.
               1.5 - the link is made only on the buyer's route (send true)
               1.6 - claimed first, so that write is always a change into Generated */
            claimed = claimForMarking(documentId, gate);
            if (claimed) {
                System.enqueueJob(new MarkGenerated(documentId, linkOpportunityId, send == true));
                out.sentForSignature = send == true;
            }
        } catch (Exception e) {
            throw new AuraHandledException('The form was generated but could not be stored: ' + e.getMessage());
        }
        if (!claimed) {
            /* 1.6 - another request marked the row during the render; its marking sends, this one must not */
            throw new AuraHandledException(ALREADY_REQUESTED);
        }
        out.success = true;
        out.message = out.sentForSignature
            ? 'KYC form generated and sent for signature.'
            : 'KYC form generated and filed on the customer\'s documents.';
        return out;
    }

    /**
     * 1.6 - re-reads the row under a lock after the render. If another request marked it since the
     * gate ran, returns false with no write; otherwise marks it requested and Pending, so MarkGenerated
     * is always a change into Generated.
     * 1.7 - "since the gate ran" compares status, envelope id and requested flag with the gate's reading.
     */
    @TestVisible
    private static Boolean claimForMarking(Id documentId, AurelixKycGenerationGate.GateDTO seen) {
        Documents__c row = [
            SELECT Id, Document_Status__c, Auto_Generate_Document__c, EnvelopID__c
            FROM Documents__c WHERE Id = :documentId LIMIT 1 FOR UPDATE
        ];
        if (seen == null
                || blankToEmpty(row.Document_Status__c) != blankToEmpty(seen.documentStatus)
                || blankToEmpty(row.EnvelopID__c) != blankToEmpty(seen.envelopeId)
                || (row.Auto_Generate_Document__c == true) != (seen.generationRequested == true)) {
            return false;
        }
        update new Documents__c(
            Id = documentId,
            Auto_Generate_Document__c = true,
            Document_Status__c = STATUS_PENDING);
        return true;
    }

    /** 1.7 - trimmed, and blank for null, so a null and an empty value read the same. */
    private static String blankToEmpty(String v) {
        return v == null ? '' : v.trim();
    }

    /**
     * 1.6 - support only: sets a hand-reset "KYC Form" row back to Pending (System Administrator has
     * no field access to Document_Status__c). Returns the old value.
     */
    public static String resetStatusToPending(Id documentId) {
        Documents__c row = [SELECT Id, Name, Document_Status__c FROM Documents__c WHERE Id = :documentId LIMIT 1];
        if (row.Name != TEMPLATE_NAME) {
            throw new IllegalArgumentException('Only a "' + TEMPLATE_NAME + '" document can be reset here.');
        }
        String before = row.Document_Status__c;
        if (before != STATUS_PENDING) {
            update new Documents__c(Id = documentId, Document_Status__c = STATUS_PENDING);
        }
        return before;
    }

    /**
     * 1.3 - the single marking update, in a transaction of its own so MODON's trigger framework
     * (processedIds) sees the row change once: Auto_Send set and status turning Generated together
     * is exactly what DocumentTriggerHelper.autoSendDocuSign looks for.
     * 1.6 - the row is Pending here; on the buyer's route the old envelope id is cleared too, as MODON
     * sends only when EnvelopID__c is blank.
     */
    public class MarkGenerated implements Queueable {
        private Id documentId;
        private Id opportunityId;
        private Boolean send;
        public MarkGenerated(Id documentId, Id opportunityId, Boolean send) {
            this.documentId = documentId;
            this.opportunityId = opportunityId;
            this.send = send;
        }
        public void execute(QueueableContext qc) {
            Documents__c mark = new Documents__c(
                Id = documentId,
                Auto_Generate_Document__c = true,
                Auto_Send_DocuSign_Email__c = send == true,
                Document_Status__c = STATUS_GENERATED,
                Document_Error_Message__c = null);
            if (send == true) {
                mark.Opportunity__c = opportunityId;
                mark.EnvelopID__c = null;
            }
            update mark;
        }
    }

    /** Record the error on the row the way MODON's service does, then refuse with a sentence. */
    private static void fail(Id documentId, String message) {
        DocumentAutoGenerateService.logError(documentId, message);
        throw new AuraHandledException(message);
    }

    private static String customerNameFor(Id opportunityId) {
        for (Opportunity o : [SELECT Account.Name FROM Opportunity WHERE Id = :opportunityId LIMIT 1]) {
            return o.Account == null ? null : o.Account.Name;
        }
        return null;
    }

    /** 1.2 - what Customer_Email__c will resolve to once the row is linked to the booking. */
    private static String customerEmailFor(Id opportunityId) {
        for (Opportunity o : [SELECT PrimaryContact__r.Email FROM Opportunity WHERE Id = :opportunityId LIMIT 1]) {
            return o.PrimaryContact__r == null ? null : o.PrimaryContact__r.Email;
        }
        return null;
    }
}