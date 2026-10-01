/**
 * AdobePDFCalloutMock
 * Shared HttpCalloutMock for AdobePDFService / AdobePDFQueueable tests.
 *
 * Routes by endpoint so a single mock can serve the whole chain:
 *   Adobe IMS token  -> Adobe /assets (presign) -> S3 PUT
 *   -> combinepdf / addwatermark -> status poll -> /assets/{id} -> S3 GET
 *   pdf.co upload -> pdf.co edit/add -> pdf.co download
 *
 * Failure switches let a single test drive each early-return branch.
 */
@isTest
public class AdobePDFCalloutMock implements HttpCalloutMock {

    // ── Failure switches ──────────────────────────────────────────────────────
    public Boolean failAll    = false;  // every call 500
    public Boolean failToken  = false;  // IMS token 401
    public Boolean failUpload = false;  // Adobe /assets presign 500
    public Boolean failMerge  = false;  // combinepdf / addwatermark 400
    public Boolean jobFailed  = false;  // status poll returns "failed"

    // ── Observability ─────────────────────────────────────────────────────────
    public Integer      callCount    = 0;
    public List<String> endpointsHit = new List<String>();

    private static final String FAKE_PDF = '%PDF-1.4 mock pdf payload';

    public AdobePDFCalloutMock() {}

    public AdobePDFCalloutMock(Boolean failAll) {
        this.failAll = failAll;
    }

    public HttpResponse respond(HttpRequest req) {
        callCount++;
        String endpoint = req.getEndpoint();
        String method   = req.getMethod();
        endpointsHit.add(method + ' ' + endpoint);

        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');

        if (failAll) {
            res.setStatusCode(500);
            res.setBody('{"error":"mock failure"}');
            return res;
        }

        // ── Adobe IMS token ───────────────────────────────────────────────────
        if (endpoint.contains('/ims/token/v3')) {
            if (failToken) {
                res.setStatusCode(401);
                res.setBody('{"error":"invalid_client"}');
                return res;
            }
            res.setStatusCode(200);
            res.setBody('{"access_token":"MOCK_TOKEN","token_type":"bearer","expires_in":86399}');
            return res;
        }

        // ── S3 presigned PUT (upload) ─────────────────────────────────────────
        if (endpoint.contains('mock-upload')) {
            res.setStatusCode(200);
            res.setBody('');
            return res;
        }

        // ── S3 presigned GET (download) ───────────────────────────────────────
        if (endpoint.contains('mock-download')) {
            res.setStatusCode(200);
            res.setBodyAsBlob(Blob.valueOf(FAKE_PDF));
            return res;
        }

        // ── Async job status poll (must be checked before /operation/) ────────
        if (endpoint.endsWith('/status')) {
            res.setStatusCode(200);
            if (jobFailed) {
                res.setBody('{"status":"failed"}');
            } else {
                res.setBody('{"status":"done","asset":{"assetID":"MOCK_RESULT_ASSET"}}');
            }
            return res;
        }

        // ── combinepdf / addwatermark ─────────────────────────────────────────
        if (endpoint.contains('/operation/combinepdf')
            || endpoint.contains('/operation/addwatermark')) {
            if (failMerge) {
                res.setStatusCode(400);
                res.setBody('{"error":{"code":"INVALID_REQUEST_FORMAT"}}');
                return res;
            }
            res.setStatusCode(201);
            res.setHeader('Location',
                'https://pdf-services-ue1.adobe.io/operation/job/MOCKJOB/status');
            res.setHeader('x-request-id', 'MOCKJOB');
            res.setBody('{}');
            return res;
        }

        // ── Adobe GET /assets/{id} (resolve download URI) ─────────────────────
        if (endpoint.contains('/assets/') && method == 'GET') {
            res.setStatusCode(200);
            res.setBody('{"downloadUri":"https://mock-download.s3.amazonaws.com/final.pdf"}');
            return res;
        }

        // ── Adobe POST /assets (presign) ──────────────────────────────────────
        if (endpoint.endsWith('/assets')) {
            if (failUpload) {
                res.setStatusCode(500);
                res.setBody('{"error":"presign unavailable"}');
                return res;
            }
            res.setStatusCode(200);
            res.setBody('{"uploadUri":"https://mock-upload.s3.amazonaws.com/put",'
                + '"assetID":"MOCK_ASSET_' + callCount + '"}');
            return res;
        }

        // ── pdf.co upload ─────────────────────────────────────────────────────
        if (endpoint.contains('api.pdf.co/v1/file/upload/base64')) {
            res.setStatusCode(200);
            res.setBody('{"error":false,"status":200,'
                + '"url":"https://mock-pdfco-file.example.com/kyc.pdf"}');
            return res;
        }

        // ── pdf.co add images ─────────────────────────────────────────────────
        if (endpoint.contains('api.pdf.co/v1/pdf/edit/add')) {
            res.setStatusCode(200);
            res.setBody('{"error":false,"status":200,'
                + '"url":"https://mock-pdfco-branded.example.com/out.pdf"}');
            return res;
        }

        // ── pdf.co file download ──────────────────────────────────────────────
        if (endpoint.contains('mock-pdfco')) {
            res.setStatusCode(200);
            res.setBodyAsBlob(Blob.valueOf(FAKE_PDF));
            return res;
        }

        // ── Fallback ──────────────────────────────────────────────────────────
        res.setStatusCode(200);
        res.setBody('{}');
        return res;
    }
}