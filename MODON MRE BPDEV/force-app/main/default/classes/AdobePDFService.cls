/**
 * AdobePDFService
 * Author  : Arvind
 * Created : Jul 30, 2026
 * Updated : Aug 18, 2026 - Pure Adobe, only using combinepdf (works)
 *
 * Note: htmltopdf and addwatermark return INVALID_REQUEST_FORMAT
 *       on this Adobe account - only combinepdf is available
 *
 * Flow:
 *  1. Get token
 *  2. Upload main PDF
 *  3. Upload signature page PDF (from Static Resource ModonSignaturePage)
 *  4. combinepdf - merge main + signature page
 *  5. Download final PDF
 *
 * Static Resources needed:
 *   ModonLogoMAX      - Modon logo PNG
 *   ModonSignature    - Signature image PNG
 *   ModonStamp        - Stamp image PNG
 *   ModonSignaturePage - Pre-built signature page PDF (upload once)
 */
public without sharing class AdobePDFService {

    private static final String IMS_URL          = 'https://ims-na1.adobelogin.com';
    private static final String PDF_SERVICES_URL = 'https://pdf-services.adobe.io';
    private static final String CLIENT_ID        = System.Label.AdobePDFClientId;
    private static final String CLIENT_SECRET    = System.Label.AdobePDFClientSecret;

    // Cache token - valid 24hrs, reused within same transaction
    private static String cachedToken;

    // ── Main entry point ──────────────────────────────────────────────────────
    public static String addModonBranding(
        String base64Pdf,
        String customerName,
        Id salesOrderId
    ) {
        System.debug('AdobePDFService: START | Customer: ' + customerName);
        try {
            // Step 1: Get token (cached)
            String accessToken = getAccessToken();
            if (String.isBlank(accessToken)) {
                System.debug('AdobePDFService: Token failed');
                return null;
            }
            System.debug('AdobePDFService: Token OK');

            // Step 2: Upload main PDF
            String pdfAssetId = uploadAsset(accessToken, base64Pdf, 'application/pdf');
            if (String.isBlank(pdfAssetId)) {
                System.debug('AdobePDFService: PDF upload failed');
                return null;
            }
            System.debug('AdobePDFService: PDF uploaded | ' + pdfAssetId);

            // Step 2b: Add logo to every page header via pdf.co (1 call only)
            // Adobe addwatermark not available on this plan - pdf.co used instead
            System.debug('AdobePDFService: Step 2b - Adding logo via pdf.co...');
            String logoAddedBase64 = addLogoViapdFco(base64Pdf);
            if (String.isNotBlank(logoAddedBase64)) {
                // Re-upload the logo-branded PDF to Adobe
                String logoBrandedAssetId = uploadAsset(
                    accessToken, logoAddedBase64, 'application/pdf');
                if (String.isNotBlank(logoBrandedAssetId)) {
                    pdfAssetId = logoBrandedAssetId;
                    System.debug('AdobePDFService: Logo added to all pages via pdf.co');
                }
            } else {
                System.debug('AdobePDFService: pdf.co logo failed - continuing without');
            }

            // Step 2b: Add watermark overlay to every page
            // ModonWatermarkOverlay.pdf = 1-page PDF with:
            //   - Modon logo top-right
            //   - "Verified by Modon Properties" bottom-left
            // Create once in Word/Canva and upload as Static Resource
            System.debug('AdobePDFService: Step 2b - Adding watermark overlay...');
            String overlayBase64 = getStaticResourceBase64('ModonWatermarkOverlay');
            if (String.isNotBlank(overlayBase64)) {
                String overlayAssetId = uploadAsset(
                    accessToken, overlayBase64, 'application/pdf');
                System.debug('AdobePDFService: Overlay uploaded | ' + overlayAssetId);
                if (String.isNotBlank(overlayAssetId)) {
                    String overlayAddedId = addLogoToPages(
                        accessToken, pdfAssetId, overlayAssetId);
                    if (String.isNotBlank(overlayAddedId)) {
                        pdfAssetId = overlayAddedId;
                        System.debug('AdobePDFService: Watermark overlay added SUCCESS');
                    } else {
                        System.debug('AdobePDFService: Overlay FAILED - continuing without');
                    }
                }
            } else {
                System.debug('AdobePDFService: ModonWatermarkOverlay not found in Static Resources');
            }

            // Step 3: Upload signature page from Static Resource
            // ModonSignaturePage.pdf - pre-built PDF with logo + signature + stamp
            // Upload once: Setup -> Static Resources -> ModonSignaturePage
            System.debug('AdobePDFService: Step 3 - Uploading signature page...');
            String signatureAssetId    = null;
            String signaturePageBase64 = getStaticResourceBase64('ModonSignaturePage');
            if (String.isNotBlank(signaturePageBase64)) {
                signatureAssetId = uploadAsset(
                    accessToken, signaturePageBase64, 'application/pdf');
                System.debug('AdobePDFService: Signature page uploaded | ' + signatureAssetId);
            } else {
                System.debug('AdobePDFService: ModonSignaturePage not found in Static Resources');
            }

            // Step 4: Merge main PDF + signature page using combinepdf
            String finalAssetId = pdfAssetId;
            if (String.isNotBlank(signatureAssetId)) {
                finalAssetId = mergePdfs(accessToken, pdfAssetId, signatureAssetId);
                if (String.isBlank(finalAssetId)) {
                    System.debug('AdobePDFService: Merge failed - using original PDF');
                    finalAssetId = pdfAssetId;
                } else {
                    System.debug('AdobePDFService: Merge SUCCESS | ' + finalAssetId);
                }
            }

            // Step 5: Download final PDF
            String finalBase64 = downloadAsset(accessToken, finalAssetId);
            System.debug('AdobePDFService: Done | size: '
                + (finalBase64 != null ? finalBase64.length() : 0));
            return finalBase64;

        } catch (Exception e) {
            System.debug('AdobePDFService EXCEPTION: ' + e.getMessage()
                + ' | Line: ' + e.getLineNumber());
            return null;
        }
    }

    // ── @future method - called from MaxsightAuditQueueable ──────────────────
    // Cannot enqueue Queueable from inside Queueable
    // @future runs in new transaction - can then enqueue AdobePDFQueueable
    @future(callout=false)
    public static void brandPdfAsync(
        String base64Pdf,
        String documentTitle,
        Id     salesOrderId,
        Id     contentDocumentId
    ) {
        System.debug('AdobePDFService.brandPdfAsync: Enqueueing AdobePDFQueueable...');
        try {
            System.enqueueJob(new AdobePDFQueueable(
                base64Pdf,
                documentTitle,
                salesOrderId,
                contentDocumentId
            ));
            System.debug('AdobePDFQueueable enqueued from @future');
        } catch (Exception e) {
            System.debug('AdobePDFQueueable enqueue failed: ' + e.getMessage());
        }
    }

    // ── Get OAuth token (cached) ───────────────────────────────────────────────
    private static String getAccessToken() {
        if (String.isNotBlank(cachedToken)) return cachedToken;
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
            System.debug('AdobePDFService token HTTP: ' + res.getStatusCode());
            if (res.getStatusCode() == 200) {
                Map<String, Object> r =
                    (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                cachedToken = (String) r.get('access_token');
                return cachedToken;
            }
        } catch (Exception e) {
            System.debug('AdobePDFService getAccessToken: ' + e.getMessage());
        }
        return null;
    }

    // ── Upload asset (presign + S3 PUT) ───────────────────────────────────────
    private static String uploadAsset(
        String accessToken, String base64Content, String mediaType
    ) {
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(PDF_SERVICES_URL + '/assets');
            req.setMethod('POST');
            req.setHeader('Authorization', 'Bearer ' + accessToken);
            req.setHeader('X-API-Key', CLIENT_ID);
            req.setHeader('Content-Type', 'application/json');
            req.setTimeout(30000);
            req.setBody('{"mediaType":"' + mediaType + '"}');

            HttpResponse res = new Http().send(req);
            if (res.getStatusCode() != 200) return null;

            Map<String, Object> r =
                (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            String uploadUri = (String) r.get('uploadUri');
            String assetID   = (String) r.get('assetID');

            HttpRequest putReq = new HttpRequest();
            putReq.setEndpoint(uploadUri);
            putReq.setMethod('PUT');
            putReq.setHeader('Content-Type', mediaType);
            putReq.setBodyAsBlob(EncodingUtil.base64Decode(base64Content));
            putReq.setTimeout(120000);

            HttpResponse putRes = new Http().send(putReq);
            if (putRes.getStatusCode() == 200 || putRes.getStatusCode() == 201) {
                return assetID;
            }
        } catch (Exception e) {
            System.debug('AdobePDFService uploadAsset: ' + e.getMessage());
        }
        return null;
    }

    // ── Merge two PDFs using Adobe combinepdf ─────────────────────────────────
    private static String mergePdfs(
        String accessToken, String pdfAssetId, String signatureAssetId
    ) {
        try {
            Map<String, Object> mergeParams = new Map<String, Object>{
                'assets' => new List<Object>{
                    new Map<String, Object>{ 'assetID' => pdfAssetId },
                    new Map<String, Object>{ 'assetID' => signatureAssetId }
                }
            };

            HttpRequest req = new HttpRequest();
            req.setEndpoint(PDF_SERVICES_URL + '/operation/combinepdf');
            req.setMethod('POST');
            req.setHeader('Authorization', 'Bearer ' + accessToken);
            req.setHeader('X-API-Key', CLIENT_ID);
            req.setHeader('Content-Type', 'application/json');
            req.setTimeout(60000);
            req.setBody(JSON.serialize(mergeParams));

            HttpResponse res = new Http().send(req);
            System.debug('AdobePDFService merge HTTP: ' + res.getStatusCode());

            if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
                String location  = res.getHeader('Location');
                String requestId = res.getHeader('x-request-id');
                String pollUrl   = String.isNotBlank(location) ? location
                    : 'https://pdf-services-ue1.adobe.io/operation/combinepdf/'
                      + requestId + '/status';
                return pollForResult(accessToken, pollUrl);
            }
            System.debug('AdobePDFService merge failed: ' + res.getBody().left(200));
        } catch (Exception e) {
            System.debug('AdobePDFService mergePdfs: ' + e.getMessage());
        }
        return null;
    }

    // ── Poll for job completion ────────────────────────────────────────────────
    private static String pollForResult(String accessToken, String locationUrl) {
        if (String.isBlank(locationUrl)) return null;
        try {
            for (Integer i = 0; i < 30; i++) {
                HttpRequest req = new HttpRequest();
                req.setEndpoint(locationUrl);
                req.setMethod('GET');
                req.setHeader('Authorization', 'Bearer ' + accessToken);
                req.setHeader('X-API-Key', CLIENT_ID);
                req.setTimeout(30000);

                HttpResponse res = new Http().send(req);
                if (res.getStatusCode() == 200) {
                    Map<String, Object> result =
                        (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                    String status = (String) result.get('status');
                    System.debug('AdobePDFService poll[' + i + '] status: ' + status);
                    if (status == 'done') {
                        Map<String, Object> asset =
                            (Map<String, Object>) result.get('asset');
                        return asset != null ? (String) asset.get('assetID') : null;
                    } else if (status == 'failed') {
                        System.debug('AdobePDFService job FAILED');
                        return null;
                    }
                }
            }
        } catch (Exception e) {
            System.debug('AdobePDFService pollForResult: ' + e.getMessage());
        }
        return null;
    }

    // ── Download asset as base64 ──────────────────────────────────────────────
    private static String downloadAsset(String accessToken, String assetId) {
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(PDF_SERVICES_URL + '/assets/' + assetId);
            req.setMethod('GET');
            req.setHeader('Authorization', 'Bearer ' + accessToken);
            req.setHeader('X-API-Key', CLIENT_ID);
            req.setTimeout(30000);

            HttpResponse res = new Http().send(req);
            if (res.getStatusCode() != 200) return null;

            Map<String, Object> result =
                (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            String downloadUrl = (String) result.get('downloadUri');
            if (String.isBlank(downloadUrl)) return null;

            HttpRequest dlReq = new HttpRequest();
            dlReq.setEndpoint(downloadUrl);
            dlReq.setMethod('GET');
            dlReq.setTimeout(120000);

            HttpResponse dlRes = new Http().send(dlReq);
            if (dlRes.getStatusCode() == 200) {
                Blob pdfBlob = dlRes.getBodyAsBlob();
                if (pdfBlob != null && pdfBlob.size() > 0) {
                    return EncodingUtil.base64Encode(pdfBlob);
                }
            }
        } catch (Exception e) {
            System.debug('AdobePDFService downloadAsset: ' + e.getMessage());
        }
        return null;
    }

    // ── Add logo to all pages via pdf.co (1 API call) ───────────────────────
    private static String addLogoViapdFco(String base64Pdf) {
        try {
            String logoBase64  = getStaticResourceBase64('ModonLogoMAX');
            String pdfCoApiKey = System.Label.PdfCoAPIKey;

            if (String.isBlank(logoBase64) || String.isBlank(pdfCoApiKey)) {
                System.debug('AdobePDFService: pdf.co logo - missing logo or key');
                return null;
            }

            // Step 1: Upload PDF to pdf.co
            HttpRequest upReq = new HttpRequest();
            upReq.setEndpoint('https://api.pdf.co/v1/file/upload/base64');
            upReq.setMethod('POST');
            upReq.setHeader('Content-Type', 'application/json');
            upReq.setHeader('x-api-key', pdfCoApiKey);
            upReq.setTimeout(60000);
            upReq.setBody(JSON.serialize(new Map<String, Object>{
                'file' => base64Pdf,
                'name' => 'kyc.pdf'
            }));
            HttpResponse upRes = new Http().send(upReq);
            if (upRes.getStatusCode() != 200) return null;
            Map<String, Object> upResult =
                (Map<String, Object>) JSON.deserializeUntyped(upRes.getBody());
            if (upResult.get('error') == true) return null;
            String pdfUrl = (String) upResult.get('url');

            // Step 2: Add logo image to all pages
            List<Map<String, Object>> images = new List<Map<String, Object>>();
            images.add(new Map<String, Object>{
                'url'    => 'data:image/png;base64,' + logoBase64,
                'x'      => 440,
                'y'      => 5,
                'width'  => 120,
                'height' => 40,
                'pages'  => '0-'
            });

            HttpRequest brandReq = new HttpRequest();
            brandReq.setEndpoint('https://api.pdf.co/v1/pdf/edit/add');
            brandReq.setMethod('POST');
            brandReq.setHeader('Content-Type', 'application/json');
            brandReq.setHeader('x-api-key', pdfCoApiKey);
            brandReq.setTimeout(60000);
            brandReq.setBody(JSON.serialize(new Map<String, Object>{
                'url'    => pdfUrl,
                'images' => images,
                'async'  => false
            }));
            HttpResponse brandRes = new Http().send(brandReq);
            System.debug('AdobePDFService pdfco logo HTTP: ' + brandRes.getStatusCode());
            if (brandRes.getStatusCode() != 200) return null;
            Map<String, Object> brandResult =
                (Map<String, Object>) JSON.deserializeUntyped(brandRes.getBody());
            if (brandResult.get('error') == true) return null;
            String brandedUrl = (String) brandResult.get('url');

            // Step 3: Download branded PDF
            HttpRequest dlReq = new HttpRequest();
            dlReq.setEndpoint(brandedUrl);
            dlReq.setMethod('GET');
            dlReq.setTimeout(60000);
            HttpResponse dlRes = new Http().send(dlReq);
            if (dlRes.getStatusCode() == 200 && dlRes.getBodyAsBlob().size() > 0) {
                System.debug('AdobePDFService: pdf.co logo success');
                return EncodingUtil.base64Encode(dlRes.getBodyAsBlob());
            }
        } catch (Exception e) {
            System.debug('AdobePDFService addLogoViaPdfCo: ' + e.getMessage());
        }
        return null;
    }

    // ── Add logo to all pages via Adobe addwatermark ────────────────────────
    // Correct format: watermarkDocumentAssetID must be a PDF (not image)
    // Upload logo PNG as PDF watermark document
    private static String addLogoToPages(
        String accessToken, String pdfAssetId, String logoAssetId
    ) {
        try {
            // The watermark must be a PDF - convert logo PNG to PDF first
            // We use ModonLogoOverlay static resource - a 1-page PDF with just the logo
            // If not available, use the logo asset directly (Adobe converts it)
            String watermarkAssetId = logoAssetId;

            // Try to get pre-built logo PDF overlay if exists
            String logoPdfBase64 = getStaticResourceBase64('ModonLogoOverlay');
            if (String.isNotBlank(logoPdfBase64)) {
                String logoPdfAssetId = uploadAsset(
                    accessToken, logoPdfBase64, 'application/pdf');
                if (String.isNotBlank(logoPdfAssetId)) {
                    watermarkAssetId = logoPdfAssetId;
                    System.debug('AdobePDFService: Using ModonLogoOverlay PDF');
                }
            }

            // Correct API format from Adobe docs
            Map<String, Object> body = new Map<String, Object>{
                'inputDocumentAssetID'   => pdfAssetId,
                'watermarkDocumentAssetID' => watermarkAssetId,
                'appearance' => new Map<String, Object>{
                    'appearOnForeground' => true,
                    'opacity'            => 100
                }
            };

            String bodyStr = JSON.serialize(body);
            System.debug('AdobePDFService addLogo request: ' + bodyStr);

            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://pdf-services-ue1.adobe.io/operation/addwatermark');
            req.setMethod('POST');
            req.setHeader('Authorization', 'Bearer ' + accessToken);
            req.setHeader('X-API-Key', CLIENT_ID);
            req.setHeader('Content-Type', 'application/json');
            req.setTimeout(60000);
            req.setBody(bodyStr);

            HttpResponse res = new Http().send(req);
            System.debug('AdobePDFService addLogo HTTP: ' + res.getStatusCode());
            System.debug('AdobePDFService addLogo response: ' + res.getBody().left(300));

            if (res.getStatusCode() == 200 || res.getStatusCode() == 201) {
                String location  = res.getHeader('Location');
                String requestId = res.getHeader('x-request-id');
                String pollUrl   = String.isNotBlank(location) ? location
                    : 'https://pdf-services-ue1.adobe.io/operation/addwatermark/'
                      + requestId + '/status';
                System.debug('AdobePDFService addLogo poll: ' + pollUrl);
                return pollForResult(accessToken, pollUrl);
            }
            System.debug('AdobePDFService addLogo FAILED: ' + res.getBody());
        } catch (Exception e) {
            System.debug('AdobePDFService addLogoToPages: ' + e.getMessage());
        }
        return null;
    }

    // ── Get Static Resource as base64 ─────────────────────────────────────────
    private static String getStaticResourceBase64(String resourceName) {
        try {
            List<StaticResource> resources = [
                SELECT Body FROM StaticResource
                WHERE Name = :resourceName LIMIT 1
            ];
            if (!resources.isEmpty() && resources[0].Body.size() > 0) {
                return EncodingUtil.base64Encode(resources[0].Body);
            }
            System.debug('AdobePDFService: ' + resourceName + ' not found');
        } catch (Exception e) {
            System.debug('AdobePDFService: ' + resourceName + ' - ' + e.getMessage());
        }
        return null;
    }
}