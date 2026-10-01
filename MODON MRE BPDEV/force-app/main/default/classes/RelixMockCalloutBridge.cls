/**
 * RelixMockCalloutBridge - SANDBOX-ONLY TEST TOOL. An HttpCalloutMock that turns a callout:Relix_API request into a call
 * of RelixMockApi.dispatch(), adding the x-api-key header the Named Credential would merge in, so the real Relix code
 * (RelixClient, RelixKycService, RelixDocumentBatch) talks to the real mock logic inside a test.
 *
 * NEVER DEPLOY TO PRODUCTION. Lives in sandbox-tools/relix-mock, outside force-app.
 *
 * Version  Author       Date         Detail
 * 1.0      MODON Dev  26 Sep 2026  Relix end-to-end mock test in sfdev (docs/relix/11-mock-test-plan.md section 1).
 *
 * HOW TO USE
 *   RelixMockCalloutBridge bridge = RelixMockCalloutBridge.open();   // mock gates open, test key registered
 *   bridge.advanceAfterCreate = 3600;                                 // optional: the mock clock jumps after a create
 *   Test.setMock(HttpCalloutMock.class, bridge);
 * Any other endpoint (MODON's Oracle and Arabic-translation callouts in the test) gets an empty 200.
 */
@IsTest
public class RelixMockCalloutBridge implements HttpCalloutMock {

    /** The dummy key of the tests. Its SHA-256 is registered by open(); it exists only inside a test. */
    public static final String TEST_KEY = 'relix-mock-test-key';
    public static final String NAMED_CREDENTIAL = 'callout:Relix_API';

    /** Every Relix request the bridge answered, in order. */
    public List<HttpRequest> requests = new List<HttpRequest>();
    /** Every answer, in the same order. */
    public List<RelixMockApi.Answer> answers = new List<RelixMockApi.Answer>();
    /** False to send no x-api-key (as a principal without the ApiKey parameter would). */
    public Boolean sendKey = true;
    /** The key sent; a different value proves the 401 path. */
    public String key = TEST_KEY;
    /** Seconds added to the mock clock after each successful create, so the next read sees a finished case. */
    public Long advanceAfterCreate = 0;

    /**
     * Opens the mock's gates for a test: sandbox, switched on, and the SHA-256 of TEST_KEY registered. Resets the clock.
     * @return a new bridge
     */
    public static RelixMockCalloutBridge open() {
        RelixMockApi.sandboxOverride = true;
        RelixMockApi.activeOverride = true;
        RelixMockApi.keyHashOverride = RelixMockBodies.sha256(Blob.valueOf(TEST_KEY));
        RelixMockApi.clockOffsetSeconds = 0;
        return new RelixMockCalloutBridge();
    }

    /**
     * Moves the mock clock.
     * @param seconds seconds to add (negative moves it back)
     */
    public static void advance(Long seconds) {
        RelixMockApi.clockOffsetSeconds = (RelixMockApi.clockOffsetSeconds == null ? 0 : RelixMockApi.clockOffsetSeconds) + seconds;
    }

    /**
     * Answers one callout: Relix requests through RelixMockApi.dispatch, anything else with an empty 200.
     * @param req the request
     * @return the answer
     */
    public HttpResponse respond(HttpRequest req) {
        String endpoint = req.getEndpoint();
        if (endpoint == null || !endpoint.startsWith(NAMED_CREDENTIAL)) {
            HttpResponse other = new HttpResponse();
            other.setStatusCode(200);
            other.setBody('{}');
            return other;
        }
        requests.add(req);
        Map<String, String> headers = new Map<String, String>();
        if (sendKey) {
            headers.put('x-api-key', key);
        }
        for (String name : new List<String>{ 'Accept', 'Content-Type' }) {
            if (req.getHeader(name) != null) {
                headers.put(name, req.getHeader(name));
            }
        }
        String body = req.getBody();
        RelixMockApi.Answer a = RelixMockApi.dispatch(req.getMethod(), endpoint.substringAfter(NAMED_CREDENTIAL), headers,
            String.isBlank(body) ? null : Blob.valueOf(body));
        answers.add(a);
        if (req.getMethod() == 'POST' && endpoint.endsWith('/buyer-journeys') && a.status == 200 && advanceAfterCreate != 0) {
            advance(advanceAfterCreate);
        }
        HttpResponse res = new HttpResponse();
        res.setStatusCode(a.status);
        res.setBody(a.body);
        for (String name : a.headers.keySet()) {
            res.setHeader(name, a.headers.get(name));
        }
        return res;
    }

    /**
     * How many Relix requests went to an endpoint containing the fragment.
     * @param fragment e.g. '/buyer'
     * @return the count
     */
    public Integer requestsTo(String fragment) {
        Integer n = 0;
        for (HttpRequest r : requests) {
            if (r.getEndpoint().contains(fragment)) {
                n++;
            }
        }
        return n;
    }

    /**
     * How many Relix requests went to an endpoint ending with the suffix (so '/buyer' does not count '/buyer-journeys').
     * @param suffix e.g. '/buyer'
     * @return the count
     */
    public Integer requestsEndingWith(String suffix) {
        Integer n = 0;
        for (HttpRequest r : requests) {
            if (r.getEndpoint().endsWith(suffix)) {
                n++;
            }
        }
        return n;
    }
}