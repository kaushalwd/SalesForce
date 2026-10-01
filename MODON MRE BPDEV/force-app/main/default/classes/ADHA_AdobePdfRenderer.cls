/**********************************************************************************************************************
* Name               : ADHA_AdobePdfRenderer
* Description        : Renders the undertaking HTML to PDF through Adobe PDF Services (token, upload, operate, poll,
*                      download). Visualforce renderAs="pdf" stays ruled out: it draws Arabic isolated and reversed.
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           Aurelix                     23 Aug 2026     Initial.
**********************************************************************************************************************/
public without sharing class ADHA_AdobePdfRenderer implements ADHA_UndertakingDocument.Renderer {

    private static final String IMS_URL = 'https://ims-na1.adobelogin.com';
    private static final String PDF_URL = 'https://pdf-services.adobe.io';
    private static final String CLIENT_ID = System.Label.AdobePDFClientId;
    private static final String CLIENT_SECRET = System.Label.AdobePDFClientSecret;

    /** A4 in inches, which is the unit Adobe's pageLayout expects. */
    private static final Decimal A4_WIDTH = 8.27;
    private static final Decimal A4_HEIGHT = 11.69;

    /**
     * Bounded busy poll, since Apex has no sleep. 70 plus this class's five other callouts is 75 of the
     * 100 a transaction allows; 25 proved too few for cold conversions and failed live signings.
     */
    @TestVisible private static Integer maxPolls = 70;

    /** Which step gave up, for the caller's error message; a bare null made failures undiagnosable. */
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
        String token = accessToken();
        if (String.isBlank(token)) {
            lastFailure = 'Adobe refused the credentials, no access token';
            return null;
        }
        String assetId = uploadZip(token, zipOf(html));
        if (String.isBlank(assetId)) {
            lastFailure = 'Adobe rejected the upload, no asset id';
            return null;
        }
        String pollUrl = startConversion(token, assetId);
        if (String.isBlank(pollUrl)) {
            lastFailure = 'Adobe would not start the conversion, no poll url';
            return null;
        }
        String out = awaitResult(token, pollUrl);
        if (String.isBlank(out)) {
            lastFailure = 'Adobe did not return a PDF within ' + maxPolls + ' polls';
        }
        return out;
    }

    /**
     * Adobe takes HTML as a zip with index.html at the root, not as a bare file.
     * Blob.valueOf writes UTF-8, which is what the document declares.
     */
    @TestVisible
    private static Blob zipOf(String html) {
        Compression.ZipWriter writer = new Compression.ZipWriter();
        writer.addEntry('index.html', Blob.valueOf(html));
        return writer.getArchive();
    }

    private String accessToken() {
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(IMS_URL + '/ims/token/v3');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            req.setTimeout(30000);
            req.setBody(
                'grant_type=client_credentials'
                + '&client_id=' + EncodingUtil.urlEncode(CLIENT_ID, 'UTF-8')
                + '&client_secret=' + EncodingUtil.urlEncode(CLIENT_SECRET, 'UTF-8')
                + '&scope=openid,AdobeID,DCAPI'
            );
            HttpResponse res = new Http().send(req);
            if (res.getStatusCode() != 200) {
                System.debug('ADHA_AdobePdfRenderer token HTTP ' + res.getStatusCode()
                    + ': ' + res.getBody().left(300));
                return null;
            }
            Map<String, Object> body =
                (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            return (String) body.get('access_token');
        } catch (Exception e) {
            System.debug('ADHA_AdobePdfRenderer token exception: ' + e.getMessage());
            return null;
        }
    }

    /** Presign, then PUT the bytes to the URI Adobe hands back. */
    private String uploadZip(String token, Blob archive) {
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(PDF_URL + '/assets');
            req.setMethod('POST');
            req.setHeader('Authorization', 'Bearer ' + token);
            req.setHeader('X-API-Key', CLIENT_ID);
            req.setHeader('Content-Type', 'application/json');
            req.setTimeout(30000);
            req.setBody('{"mediaType":"application/zip"}');

            HttpResponse res = new Http().send(req);
            if (res.getStatusCode() != 200) {
                System.debug('ADHA_AdobePdfRenderer presign HTTP ' + res.getStatusCode());
                return null;
            }
            Map<String, Object> body =
                (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            String uploadUri = (String) body.get('uploadUri');
            String assetId = (String) body.get('assetID');
            if (String.isBlank(uploadUri) || String.isBlank(assetId)) {
                return null;
            }

            HttpRequest put = new HttpRequest();
            put.setEndpoint(uploadUri);
            put.setMethod('PUT');
            put.setHeader('Content-Type', 'application/zip');
            put.setBodyAsBlob(archive);
            put.setTimeout(120000);

            HttpResponse putRes = new Http().send(put);
            if (putRes.getStatusCode() != 200 && putRes.getStatusCode() != 201) {
                System.debug('ADHA_AdobePdfRenderer upload HTTP ' + putRes.getStatusCode());
                return null;
            }
            return assetId;
        } catch (Exception e) {
            System.debug('ADHA_AdobePdfRenderer upload exception: ' + e.getMessage());
            return null;
        }
    }

    /** Returns the URL to poll, taken from the Location header. */
    private String startConversion(String token, String assetId) {
        try {
            Map<String, Object> layout = new Map<String, Object>{
                'pageWidth' => A4_WIDTH,
                'pageHeight' => A4_HEIGHT
            };
            HttpRequest req = new HttpRequest();
            req.setEndpoint(PDF_URL + '/operation/htmltopdf');
            req.setMethod('POST');
            req.setHeader('Authorization', 'Bearer ' + token);
            req.setHeader('X-API-Key', CLIENT_ID);
            req.setHeader('Content-Type', 'application/json');
            req.setTimeout(60000);
            req.setBody(JSON.serialize(new Map<String, Object>{
                'assetID' => assetId,
                'includeHeaderFooter' => false,
                'pageLayout' => layout,
                'json' => '{}'
            }));

            HttpResponse res = new Http().send(req);
            if (res.getStatusCode() != 201 && res.getStatusCode() != 202) {
                System.debug('ADHA_AdobePdfRenderer htmltopdf HTTP ' + res.getStatusCode()
                    + ': ' + res.getBody().left(300));
                return null;
            }
            return headerValue(res, 'location');
        } catch (Exception e) {
            System.debug('ADHA_AdobePdfRenderer htmltopdf exception: ' + e.getMessage());
            return null;
        }
    }

    /**
     * Adobe returns the poll URL as a lowercase 'location' header and getHeader is case sensitive, so
     * asking for 'Location' quietly yields null and the whole conversion looks like a failure.
     */
    private String headerValue(HttpResponse res, String name) {
        for (String key : res.getHeaderKeys()) {
            if (key != null && key.equalsIgnoreCase(name)) {
                return res.getHeader(key);
            }
        }
        return null;
    }

    private String awaitResult(String token, String pollUrl) {
        try {
            for (Integer attempt = 0; attempt < maxPolls; attempt++) {
                HttpRequest req = new HttpRequest();
                req.setEndpoint(pollUrl);
                req.setMethod('GET');
                req.setHeader('Authorization', 'Bearer ' + token);
                req.setHeader('X-API-Key', CLIENT_ID);
                req.setTimeout(30000);

                HttpResponse res = new Http().send(req);
                if (res.getStatusCode() != 200) {
                    continue;
                }
                Map<String, Object> body =
                    (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                String status = (String) body.get('status');
                if (status == 'failed') {
                    System.debug('ADHA_AdobePdfRenderer conversion failed: '
                        + JSON.serialize(body).left(300));
                    return null;
                }
                if (status != 'done') {
                    continue;
                }
                Map<String, Object> asset = (Map<String, Object>) body.get('asset');
                if (asset == null) {
                    return null;
                }
                return fetch((String) asset.get('downloadUri'));
            }
            System.debug('ADHA_AdobePdfRenderer gave up after ' + maxPolls + ' polls');
        } catch (Exception e) {
            System.debug('ADHA_AdobePdfRenderer poll exception: ' + e.getMessage());
        }
        return null;
    }

    private String fetch(String downloadUri) {
        if (String.isBlank(downloadUri)) {
            return null;
        }
        HttpRequest req = new HttpRequest();
        req.setEndpoint(downloadUri);
        req.setMethod('GET');
        req.setTimeout(120000);

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 200) {
            System.debug('ADHA_AdobePdfRenderer download HTTP ' + res.getStatusCode());
            return null;
        }
        Blob pdf = res.getBodyAsBlob();
        if (pdf == null || pdf.size() == 0) {
            return null;
        }
        return EncodingUtil.base64Encode(pdf);
    }
}