/**********************************************************************************************************************
* Name               : ADHA_UndertakingDocument
* Description        : Builds the reservation undertaking as one bilingual English and Arabic PDF with a DocuSign
*                      anchor. A version mismatch in either language throws rather than signing words nobody agreed to.
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           Aurelix                     23 Aug 2026     Initial.
* 2.0           Aurelix                     23 Aug 2026     One bilingual document instead of one per language.
**********************************************************************************************************************/
public without sharing class ADHA_UndertakingDocument {

    /** DocuSign anchor. White on white so the tag lands without the customer seeing it. */
    @TestVisible private static final String SIGN_ANCHOR = '\\s1\\';

    private static final String LOGO_RESOURCE = 'ADHABaniyasLogo';
    private static final String TZ = 'Asia/Dubai';

    public class DocumentException extends Exception {}

    /** Swappable so tests never call out, and so the renderer can change without touching content. */
    public interface Renderer {
        String toPdfBase64(String html);
        /** Why the last call returned null. On the interface so render() names whichever renderer actually failed. */
        String lastFailure();
    }

    /** Adobe is the only renderer proven live; the pdf.co key currently returns HTTP 401. Visualforce stays
     *  ruled out: renderAs="pdf" draws Arabic isolated and reversed, not the text ADHA approved. */
    @TestVisible private static Renderer renderer = new ADHA_AdobePdfRenderer();

    /** Dead until the pdf.co key is fixed, but left wired: it only costs one extra failed callout and
     *  becomes a real fallback again with no code change once the key is replaced. */
    @TestVisible private static Renderer fallbackRenderer = new ADHA_PdfCoRenderer();

    public class Rendered {
        @AuraEnabled public String base64;
        @AuraEnabled public String fileName;
        @AuraEnabled public Id contentVersionId;
        @AuraEnabled public Boolean reused;
        /** Adobe gave up and pdf.co produced this one. Reported by the caller, never logged here:
         *  render() runs BEFORE the DocuSign callouts and Apex forbids a callout after DML. */
        @AuraEnabled public Boolean viaFallback = false;
        @AuraEnabled public String fallbackReason;
    }

    /** The two language records for one undertaking type, checked against what was accepted. */
    @TestVisible
    private class Texts {
        ADHA_Undertaking__mdt english;
        ADHA_Undertaking__mdt arabic;
        List<String> englishLines;
        List<String> arabicLines;
        Boolean paired;
    }

    /* ---------- entry points ---------- */

    /**
     * Returns the stored document for the same undertaking version if one exists, otherwise renders anew.
     * Rendering is a metered callout, so a reload of the signing step must not spend another one.
     */
    public static Rendered generate(Id reservationId) {
        Rendered rendered = render(reservationId);
        if (!rendered.reused) {
            store(reservationId, rendered);
        }
        return rendered;
    }

    /**
     * Renders without writing anything. Apex forbids a callout after DML in the same transaction, so
     * the signing step must finish talking to Adobe and DocuSign before it files anything.
     */
    public static Rendered render(Id reservationId) {
        ADHA_Reservation__c res = load(reservationId);

        Rendered existing = findExisting(res);
        if (existing != null) {
            return existing;
        }

        String html = buildHtml(res);
        String base64 = renderer.toPdfBase64(html);
        Boolean usedFallback = false;
        String fallbackReason = null;

        if (String.isBlank(base64)) {
            // The primary gave up. Try the other one before failing a customer who is mid-signature:
            // the deed is the same HTML either way, and a slower document beats no document.
            String why = renderer.lastFailure();
            base64 = fallbackRenderer.toPdfBase64(html);
            usedFallback = String.isNotBlank(base64);
            fallbackReason = why;
        }

        if (String.isBlank(base64)) {
            // Carry both failure reasons; a bare "could not be rendered" made intermittent failures slow to place.
            List<String> why = new List<String>();
            if (String.isNotBlank(renderer.lastFailure())) {
                why.add('primary ' + renderer.lastFailure());
            }
            if (String.isNotBlank(fallbackRenderer.lastFailure())) {
                why.add('fallback ' + fallbackRenderer.lastFailure());
            }
            throw new DocumentException(
                'Undertaking PDF could not be rendered for ' + res.Name
                    + (why.isEmpty() ? '' : ': ' + String.join(why, '; '))
            );
        }

        Rendered out = new Rendered();
        out.base64 = base64;
        out.fileName = fileNameFor(res);
        out.reused = false;
        out.viaFallback = usedFallback;
        // Carried on the result rather than written here, so an Adobe outage is still visible on
        // the timeline without this method writing before the caller's callouts.
        out.fallbackReason = fallbackReason;
        return out;
    }

    /** Files a rendered document against the reservation. Call only once every callout is done. */
    public static Id store(Id reservationId, Rendered rendered) {
        if (rendered == null || rendered.reused || String.isBlank(rendered.base64)) {
            return rendered == null ? null : rendered.contentVersionId;
        }
        ADHA_Reservation__c res = load(reservationId);
        // Attachment, not Files: a guest user cannot read a ContentVersion even from a without-sharing
        // class, so a File could never be served back to the signer. Attachment access follows the parent.
        Attachment file = new Attachment(
            ParentId = res.Id,
            Name = rendered.fileName,
            ContentType = 'application/pdf',
            Description = titleFor(res),
            Body = EncodingUtil.base64Decode(rendered.base64)
        );
        insert file;
        rendered.contentVersionId = file.Id;
        update new ADHA_Reservation__c(Id = reservationId, Undertaking_Document_Id__c = file.Id);
        return file.Id;
    }

    /** Exposed so the document can be reviewed without rendering or storing anything. */
    public static String buildHtml(Id reservationId) {
        return buildHtml(load(reservationId));
    }

    /* ---------- content ---------- */

    @TestVisible
    private static String buildHtml(ADHA_Reservation__c res) {
        Texts texts = textsFor(res);

        return '<!DOCTYPE html><html lang="en" dir="ltr">'
            + '<head><meta charset="utf-8"/>' + styles() + '</head><body>'
            + masthead()
            + detailsTable(res)
            + clauses(texts)
            + acceptance(res)
            + signature()
            + footer(res, texts)
            + '</body></html>';
    }

    private static String masthead() {
        return '<div class="masthead">'
            + logoTag()
            + '<div class="masthead-text">'
            + '<div class="project"><span>West Baniyas</span><span class="ar">غرب بني ياس</span></div>'
            + '<div class="doc-title"><span>Housing Reservation Undertaking</span>'
            + '<span class="ar">تعهد حجز المسكن</span></div>'
            + '</div></div>';
    }

    /* ---------- details ---------- */

    private static String detailsTable(ADHA_Reservation__c res) {
        ADHA_Unit__c unit = res.Unit__r;
        ADHA_Applicant__c app = res.Applicant__r;

        List<String> rows = new List<String>();
        rows.add(row('Name', esc(app.Customer_Name__c), null, 'الاسم'));
        rows.add(row('Emirates ID', emiratesId(app), null, 'رقم الهوية'));
        rows.add(row('Application number', esc(app.Application_Number__c), null, 'رقم الطلب'));
        rows.add(row('Reservation reference', esc(res.Name), null, 'رقم الحجز'));
        rows.add(row('Villa', esc(unit == null ? null : unit.Name), null, 'المسكن'));
        if (unit != null && String.isNotBlank(unit.Villa_Type__c)) {
            rows.add(row('Villa type', esc(unit.Villa_Type__c), null, 'نوع المسكن'));
        }
        rows.add(row('Unit price', money(res.Unit_Price__c), null, 'سعر المسكن'));
        if (res.Additional_Amount__c != null && res.Additional_Amount__c > 0) {
            rows.add(row('Additional amount', money(res.Additional_Amount__c), null, 'المبلغ الإضافي'));
            rows.add(row(
                'Payment method',
                paymentMethodLabel(res.Payment_Method__c, false),
                paymentMethodLabel(res.Payment_Method__c, true),
                'طريقة السداد'
            ));
            rows.add(row('Payment due by', dateOnly(res.Additional_Payment_Due__c), null, 'تاريخ استحقاق السداد'));
        }
        rows.add(row('Confirmed on', stamp(res.Submitted_On__c), null, 'تاريخ التأكيد'));

        return '<table class="details">' + String.join(rows, '') + '</table>';
    }

    /**
     * English label, the value, Arabic label. <bdi> isolates the value so the Arabic column cannot
     * reorder an Emirates ID or a date; arValue only where the value is words rather than a number.
     */
    private static String row(String enLabel, String value, String arValue, String arLabel) {
        String cell;
        if (String.isBlank(value)) {
            cell = '&mdash;';
        } else if (String.isBlank(arValue)) {
            cell = '<bdi>' + value + '</bdi>';
        } else {
            cell = '<bdi>' + value + '</bdi><span class="ar-value">' + arValue + '</span>';
        }
        return '<tr><th class="en">' + enLabel + '</th>'
            + '<td>' + cell + '</td>'
            + '<th class="ar">' + arLabel + '</th></tr>';
    }

    /* ---------- the undertaking itself ---------- */

    /**
     * Side by side when both languages have the same paragraph count, otherwise stacked whole:
     * mispairing clauses in a legal document is worse than losing the side-by-side reading.
     */
    @TestVisible
    private static String clauses(Texts texts) {
        if (!texts.paired) {
            return '<div class="stacked">'
                + '<div class="block en">' + block(texts.englishLines, false) + '</div>'
                + '<div class="block ar" dir="rtl">' + block(texts.arabicLines, true) + '</div>'
                + '</div>';
        }
        List<String> rows = new List<String>();
        for (Integer i = 0; i < texts.englishLines.size(); i++) {
            String en = texts.englishLines[i];
            String ar = texts.arabicLines[i];
            String style = paragraphStyle(en, i) == 'clause' ? paragraphStyle(ar, i) : paragraphStyle(en, i);
            rows.add('<tr>'
                + '<td class="en"><p class="' + style + '">' + esc(en) + '</p></td>'
                + '<td class="ar" dir="rtl"><p class="' + style + '">' + esc(ar) + '</p></td>'
                + '</tr>');
        }
        return '<table class="clauses">' + String.join(rows, '') + '</table>';
    }

    private static String block(List<String> lines, Boolean rtl) {
        List<String> out = new List<String>();
        for (Integer i = 0; i < lines.size(); i++) {
            out.add('<p class="' + paragraphStyle(lines[i], i) + '">' + esc(lines[i]) + '</p>');
        }
        return String.join(out, '');
    }

    /**
     * ADHA numbers sections as a short word then a colon ("First:", "أولًا:"), so an early colon is a
     * heading and a late one is a lead-in sentence. The first line is the document title.
     */
    @TestVisible
    private static String paragraphStyle(String line, Integer index) {
        if (index == 0) {
            return 'doc-heading';
        }
        Integer colon = line == null ? -1 : line.indexOf(':');
        return colon > 0 && colon <= 20 ? 'lead' : 'clause';
    }

    private static String acceptance(ADHA_Reservation__c res) {
        String acceptedOn = '<bdi>' + stamp(res.Undertaking_Accepted_On__c) + '</bdi>';
        String read = res.Undertaking_Language__c == 'ar' ? 'Arabic' : 'English';
        String readAr = res.Undertaking_Language__c == 'ar' ? 'العربية' : 'الإنجليزية';
        return '<table class="acceptance"><tr>'
            + '<td class="en">This undertaking was accepted electronically on ' + acceptedOn
            + ' through the housing selection portal, in ' + read + '.</td>'
            + '<td class="ar" dir="rtl">تم قبول هذا التعهد إلكترونياً بتاريخ ' + acceptedOn
            + ' من خلال بوابة اختيار المساكن، باللغة ' + readAr + '.</td>'
            + '</tr></table>';
    }

    private static String signature() {
        return '<div class="sign">'
            + '<div class="sign-label"><span>Signature</span><span class="ar">التوقيع</span></div>'
            + '<div class="sign-line"><span class="anchor">' + SIGN_ANCHOR + '</span></div>'
            + '</div>';
    }

    private static String footer(ADHA_Reservation__c res, Texts texts) {
        return '<div class="foot">'
            + esc(res.Name) + ' &middot; '
            + esc(res.Undertaking_Type__c) + ' &middot; '
            + esc(texts.english.Version__c) + ' &middot; English and العربية'
            + '</div>';
    }

    /* ---------- lookups ---------- */

    private static ADHA_Reservation__c load(Id reservationId) {
        List<ADHA_Reservation__c> rows = [
            SELECT Id, Name, Status__c, Unit_Price__c, Additional_Amount__c, Payment_Method__c,
                   Additional_Payment_Due__c, Submitted_On__c, Confirmation_Date__c,
                   Undertaking_Type__c, Undertaking_Version__c, Undertaking_Language__c,
                   Undertaking_Accepted_On__c, Attempt_Number__c,
                   Undertaking_Document_Id__c, Signed_Document_Id__c,
                   Unit__r.Name, Unit__r.Plot_UID__c, Unit__r.Villa_Type__c,
                   Applicant__r.Customer_Name__c, Applicant__r.Masked_Emirates_ID__c,
                   Applicant__r.Emirates_ID__c,
                   Applicant__r.Application_Number__c, Applicant__r.Service_Type__c
            FROM ADHA_Reservation__c
            WHERE Id = :reservationId
            LIMIT 1
        ];
        if (rows.isEmpty()) {
            throw new DocumentException('Reservation not found: ' + reservationId);
        }
        return rows[0];
    }

    /**
     * Both languages are on the signed page, so both versions have to match what was accepted.
     * A mismatch means ADHA replaced the text afterwards, which is not something to paper over here.
     */
    @TestVisible
    private static Texts textsFor(ADHA_Reservation__c res) {
        Map<String, ADHA_Undertaking__mdt> byLanguage = new Map<String, ADHA_Undertaking__mdt>();
        for (ADHA_Undertaking__mdt row : [
            SELECT Body__c, Version__c, Language__c, Undertaking_Type__c
            FROM ADHA_Undertaking__mdt
            WHERE Undertaking_Type__c = :res.Undertaking_Type__c AND Language__c IN ('en', 'ar')
        ]) {
            byLanguage.put(row.Language__c, row);
        }

        Texts texts = new Texts();
        texts.english = byLanguage.get('en');
        texts.arabic = byLanguage.get('ar');
        if (texts.english == null || texts.arabic == null) {
            throw new DocumentException(
                'The ' + res.Undertaking_Type__c + ' undertaking is not loaded in both languages, '
                + 'and the document carries both'
            );
        }
        assertVersion(res, texts.english);
        assertVersion(res, texts.arabic);

        texts.englishLines = lines(texts.english.Body__c);
        texts.arabicLines = lines(texts.arabic.Body__c);
        texts.paired = texts.englishLines.size() == texts.arabicLines.size()
            && !texts.englishLines.isEmpty();
        return texts;
    }

    private static void assertVersion(ADHA_Reservation__c res, ADHA_Undertaking__mdt text) {
        if (res.Undertaking_Version__c != null && text.Version__c != res.Undertaking_Version__c) {
            throw new DocumentException(
                'Undertaking text has changed since acceptance: signed as ' + res.Undertaking_Version__c
                + ', current ' + text.Language__c + ' is ' + text.Version__c
            );
        }
    }

    @TestVisible
    private static List<String> lines(String body) {
        List<String> out = new List<String>();
        if (String.isBlank(body)) {
            return out;
        }
        for (String line : body.split('\n')) {
            if (String.isNotBlank(line.trim())) {
                out.add(line.trim());
            }
        }
        return out;
    }

    /**
     * Reuses the stored copy for the same version. Read via Undertaking_Document_Id__c, not
     * ContentDocumentLink: the site guest user cannot see those links, so that lookup always missed live.
     */
    private static Rendered findExisting(ADHA_Reservation__c res) {
        if (String.isBlank(res.Undertaking_Document_Id__c)) {
            return null;
        }
        List<Attachment> files = [
            SELECT Id, Name, Description, Body
            FROM Attachment
            WHERE Id = :res.Undertaking_Document_Id__c
            LIMIT 1
        ];
        // The description carries the undertaking version, so a stamped file for older text is not reused.
        if (files.isEmpty() || files[0].Description != titleFor(res)) {
            return null;
        }
        Rendered out = new Rendered();
        out.base64 = EncodingUtil.base64Encode(files[0].Body);
        out.fileName = files[0].Name;
        out.contentVersionId = files[0].Id;
        out.reused = true;
        return out;
    }

    private static String logoTag() {
        List<StaticResource> resources = [
            SELECT Body, ContentType FROM StaticResource WHERE Name = :LOGO_RESOURCE LIMIT 1
        ];
        if (resources.isEmpty()) {
            return '';
        }
        String type = String.isBlank(resources[0].ContentType) ? 'image/svg+xml' : resources[0].ContentType;
        return '<img class="logo" src="data:' + type + ';base64,'
            + EncodingUtil.base64Encode(resources[0].Body) + '" alt=""/>';
    }

    /* ---------- naming and formatting ---------- */

    /** Doubles as the reuse key, so the version has to be in it. No language: the document has both. */
    @TestVisible
    private static String titleFor(ADHA_Reservation__c res) {
        return 'West Baniyas Undertaking ' + res.Name
            + ' (' + res.Undertaking_Type__c + ' ' + res.Undertaking_Version__c + ')';
    }

    private static String fileNameFor(ADHA_Reservation__c res) {
        return 'West-Baniyas-Undertaking-' + res.Name + '.pdf';
    }

    /**
     * Mirrors PAYMENT_SCENARIOS in adhaBaniyasJourney.js. Duplicated because the document is rendered
     * server side and Apex cannot read the component's labels; keep the two in step.
     */
    @TestVisible
    private static String paymentMethodLabel(String method, Boolean arabic) {
        if (String.isBlank(method)) {
            return '';
        }
        if (!arabic) {
            return method.escapeHtml4();
        }
        Map<String, String> translated = new Map<String, String>{
            'Full Upfront Payment' => 'سداد كامل المبلغ دفعة واحدة',
            'Payment Plan' => 'السداد على أقساط شهرية',
            'Partial Payment with Plan' => 'سداد جزء الآن والباقي على أقساط',
            'Partial Payment with Plan and Bank Top Up' => 'سداد جزء الآن، وأقساط، وتمويل إضافي',
            'Bank Top Up Finance' => 'تمويل إضافي من بنك شريك',
            'Not Applicable' => 'لا ينطبق'
        };
        String label = translated.get(method);
        return label == null ? method.escapeHtml4() : label;
    }

    /**
     * Full ID on purpose: the deed must identify its signatory, while the site still shows only
     * Masked_Emirates_ID__c. The masked field is the fallback and is currently never written.
     */
    @TestVisible
    private static String emiratesId(ADHA_Applicant__c app) {
        if (String.isNotBlank(app.Emirates_ID__c)) {
            return esc(app.Emirates_ID__c);
        }
        return esc(app.Masked_Emirates_ID__c);
    }

    private static String esc(String value) {
        return value == null ? '' : value.escapeHtml4();
    }

    private static String money(Decimal amount) {
        return amount == null ? '' : 'AED ' + amount.setScale(0).format();
    }

    /** Numeric and day first, which reads the same in both halves of the page. */
    private static String stamp(Datetime value) {
        return value == null ? '' : value.format('dd/MM/yyyy', TZ);
    }

    private static String dateOnly(Date value) {
        if (value == null) {
            return '';
        }
        return Datetime.newInstance(value, Time.newInstance(12, 0, 0, 0)).format('dd/MM/yyyy', TZ);
    }

    /* ---------- presentation ---------- */

    private static String styles() {
        return '<style>'
            + '@import url("https://fonts.googleapis.com/css2?family=Noto+Naskh+Arabic:wght@400;600&family=Inter:wght@400;600;700&display=swap");'
            + '@page { size: A4; margin: 16mm 14mm; }'
            + 'body { font-family: \'Inter\',\'Helvetica Neue\',Arial,sans-serif; font-size: 9pt;'
            + ' line-height: 1.6; color: #16181d; }'
            + '.ar, td.ar, th.ar { font-family: \'Noto Naskh Arabic\',\'Amiri\',\'Traditional Arabic\',Arial,sans-serif; }'
            + '.masthead { display: flex; align-items: center; gap: 14px;'
            + ' border-bottom: 2px solid #16181d; padding-bottom: 10px; margin-bottom: 16px; }'
            + '.masthead-text { flex: 1 1 auto; }'
            + '.logo { height: 42px; }'
            + '.project { display: flex; justify-content: space-between; font-size: 8pt;'
            + ' letter-spacing: .1em; text-transform: uppercase; color: #6b6f68; }'
            + '.doc-title { display: flex; justify-content: space-between; font-size: 12pt; font-weight: 700; }'
            + '.details { width: 100%; border-collapse: collapse; margin-bottom: 16px; table-layout: fixed; }'
            + '.details th, .details td { border-bottom: 1px solid #e2e0d8; padding: 5px 8px;'
            + ' font-size: 8.5pt; vertical-align: top; }'
            + '.details th.en { width: 27%; text-align: left; font-weight: 600; color: #4a4e47; }'
            + '.details th.ar { width: 27%; text-align: right; font-weight: 600; color: #4a4e47; }'
            + '.details td { text-align: center; }'
            + '.ar-value { display: block; font-family: \'Noto Naskh Arabic\',Arial,sans-serif; color: #4a4e47; }'
            + '.clauses { width: 100%; border-collapse: collapse; table-layout: fixed; }'
            + '.clauses td { width: 50%; vertical-align: top; padding: 0 10px 8px; }'
            + '.clauses tr { page-break-inside: avoid; }'
            + '.clauses td.en { text-align: left; border-right: 1px solid #e2e0d8; }'
            + '.clauses td.ar { text-align: right; }'
            + '.clauses p { margin: 0; }'
            + 'p.doc-heading { font-weight: 700; font-size: 10pt; margin-bottom: 8px; }'
            + 'p.lead { font-weight: 700; margin-top: 10px; }'
            + '.stacked .block { margin-bottom: 18px; }'
            + '.stacked p { margin: 0 0 8px; }'
            + '.acceptance { width: 100%; border-collapse: collapse; margin-top: 16px;'
            + ' font-size: 8.5pt; color: #4a4e47; table-layout: fixed; }'
            + '.acceptance td { width: 50%; padding: 0 10px; vertical-align: top; }'
            + '.acceptance td.en { text-align: left; }'
            + '.acceptance td.ar { text-align: right; }'
            + '.sign { margin-top: 26px; page-break-inside: avoid; }'
            + '.sign-label { display: flex; justify-content: space-between; font-size: 8pt;'
            + ' letter-spacing: .08em; text-transform: uppercase; color: #6b6f68; margin-bottom: 6px; }'
            + '.sign-line { border-bottom: 1px solid #16181d; height: 50px; width: 60%; }'
            + '.anchor { color: #ffffff; font-size: 7pt; }'
            + '.foot { margin-top: 20px; padding-top: 8px; border-top: 1px solid #e2e0d8;'
            + ' font-size: 7.5pt; color: #8a8d84; }'
            + '</style>';
    }
}