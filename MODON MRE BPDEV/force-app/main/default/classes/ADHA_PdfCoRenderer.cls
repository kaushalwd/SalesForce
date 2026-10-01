/**********************************************************************************************************************
* Name               : ADHA_PdfCoRenderer
* Description        : Renders HTML to PDF through pdf.co, which is Chrome-based and shapes Arabic properly, unlike
*                      Visualforce renderAs="pdf". Kept separate from PdfCoService, whose 14% coverage fails the gate.
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           Aurelix                     23 Aug 2026     Initial.
**********************************************************************************************************************/
public without sharing class ADHA_PdfCoRenderer implements ADHA_UndertakingDocument.Renderer {

    private static final String BASE_URL = 'callout:PdfCo';
    private static final Integer TIMEOUT = 120000;

    /** Why the last render returned null; without it a failure says only "could not be rendered". */
    @TestVisible private static String lastFailure;

    public String lastFailure() {
        return lastFailure;
    }

    public String toPdfBase64(String html) {
        lastFailure = null;
        if (String.isBlank(html)) {
            lastFailure = 'no HTML was built for the document';
            return null;
        }
        String fileUrl = convert(html);
        return String.isBlank(fileUrl) ? null : download(fileUrl);
    }

    /** Returns a temporary pdf.co URL for the rendered document, or null if it refuses. */
    private String convert(String html) {
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(BASE_URL + '/v1/pdf/convert/from/html');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('x-api-key', System.Label.PdfCoAPIKey);
            req.setTimeout(TIMEOUT);
            req.setBody(JSON.serialize(new Map<String, Object>{
                'html'      => html,
                'async'     => false,
                'printBackground' => true,
                'margins'   => '20mm 18mm 20mm 18mm',
                'paperSize' => 'A4'
            }));

            HttpResponse res = new Http().send(req);
            if (res.getStatusCode() != 200) {
                lastFailure = 'pdf.co refused the conversion, HTTP ' + res.getStatusCode();
                System.debug('ADHA_PdfCoRenderer convert HTTP ' + res.getStatusCode()
                    + ': ' + res.getBody().left(300));
                return null;
            }
            Map<String, Object> body =
                (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            if (body.get('error') == true) {
                lastFailure = 'pdf.co rejected the document: ' + body.get('message');
                System.debug('ADHA_PdfCoRenderer convert error: ' + body.get('message'));
                return null;
            }
            return (String) body.get('url');
        } catch (Exception e) {
            lastFailure = 'pdf.co conversion failed: ' + e.getMessage();
            System.debug('ADHA_PdfCoRenderer convert exception: ' + e.getMessage());
            return null;
        }
    }

    /** pdf.co hands back a URL, so the bytes still have to be fetched before they can be signed. */
    private String download(String fileUrl) {
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(fileUrl);
            req.setMethod('GET');
            req.setTimeout(TIMEOUT);

            HttpResponse res = new Http().send(req);
            if (res.getStatusCode() != 200) {
                lastFailure = 'pdf.co would not hand back the PDF, HTTP ' + res.getStatusCode();
                System.debug('ADHA_PdfCoRenderer download HTTP ' + res.getStatusCode());
                return null;
            }
            Blob pdf = res.getBodyAsBlob();
            if (pdf == null || pdf.size() == 0) {
                lastFailure = 'pdf.co returned an empty PDF';
                return null;
            }
            return EncodingUtil.base64Encode(pdf);
        } catch (Exception e) {
            lastFailure = 'pdf.co download failed: ' + e.getMessage();
            System.debug('ADHA_PdfCoRenderer download exception: ' + e.getMessage());
            return null;
        }
    }
}