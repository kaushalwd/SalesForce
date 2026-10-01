/**
 * MBP_aiClass
 * ---------------------------------------------------------------------------
 * Thin orchestrator for the AI Assistant.
 *  - getGroundedAIResponse: routes the question to an intent, fetches the
 *    broker's real records (PII tokenized) via MBP_aiContextService, asks
 *    Gemini to answer ONLY from that data, then restores the real values.
 *  - getAIResponses: retained for back-compat (general, ungrounded).
 *
 * SECURITY: grant the portal user profile/permission set Apex Class Access to
 * this class, MBP_aiContextService, and MBP_BrokerLeadcontroller.
 * TODO: move API_KEY to a Named Credential / Custom Metadata before production.
 */
public with sharing class MBP_aiClass {

    private static final Modon_Generic_Metadata__mdt CONFIG = Modon_Generic_Metadata__mdt.getInstance('MBP_aiClass');
    private static final String API_KEY = CONFIG?.Api_Key__c;
    private static final String ENDPOINT = CONFIG?.Endpoint__c + API_KEY;

    private static final String SYSTEM_GENERAL =
        'You are Modon Concierge, an AI assistant for Modon Brokers real-estate agents. ' +
        'Answer concisely and helpfully about inventory, leads, commissions and policy. ' +
        'Use markdown for any lists or tables.';

    private static final String SYSTEM_GROUNDED =
        'You are Modon Concierge, an AI assistant for Modon Brokers real-estate agents. ' +
        'Answer ONLY using the DATA block below. Never invent records or values. ' +
        'If the DATA block is empty, say you found no matching records. ' +
        'Begin with one short summary line using any TOTAL_*, COMMISSION_SUMMARY, or count ' +
        'figures present in the DATA (e.g. "You have 211 leads."). ' +
        'If the DATA contains SINGLE_RECORD=true, present it as a short bullet list, not a table. ' +
        'Otherwise, when listing records render a COMPACT markdown table; if a SUGGESTED_COLUMNS ' +
        'line is present, use exactly those columns in that order and no others unless the user ' +
        'explicitly asks. ' +
        'If a TOTAL_* value is greater than SHOWING, list only the SHOWING most recent rows, then ' +
        'add a closing note that you are showing SHOWING of the total and invite the user to ' +
        'filter (for example by status, project, or status) to narrow it down. ' +
        'Format monetary amounts with thousands separators and an AED prefix. ' +
        'Keep any tokens such as @@NM1@@, @@EM1@@ EXACTLY as written - do not translate, ' +
        'reword, or remove them.';

    // Back-compat: original entry point (general, ungrounded)
    @AuraEnabled
    public static String getAIResponses(String aiPrompt) {
        return callGemini(aiPrompt);
    }

    // New grounded entry point
    @AuraEnabled
    public static String getGroundedAIResponse(String question, String historyJson) {
        if (String.isBlank(question)) {
            return 'Please enter a question.';
        }

        String intent = MBP_aiContextService.classify(question);

        if (intent == 'GENERAL') {
            // Out of scope: do NOT call the model for arbitrary questions.
            return 'I can only help with your leads, opportunities, sales orders, commissions, '
                + 'agency profile, and agents. Please ask me about one of those.';
        }

        // Grounded path
        MBP_aiContextService.GroundedContext ctx = MBP_aiContextService.buildContext(intent);
        if (ctx == null || !ctx.hasData) {
            // TEMP (while rolling out new domains): surface QUERY_ERROR/reason.
            if (ctx != null && String.isNotBlank(ctx.dataText)) {
                return ctx.dataText;
            }
            return 'I could not find any matching records for your agency.';
        }

        String redactedQuestion = MBP_aiContextService.redact(question, ctx.tokenMap);
        String prompt = SYSTEM_GROUNDED
            + '\n\nDATA:\n' + ctx.dataText
            + '\n\nQUESTION: ' + redactedQuestion
            + '\nAnswer:';

        String raw = callGemini(prompt);
        return MBP_aiContextService.unredact(raw, ctx.tokenMap);
    }

    // Helpers
    private static String buildHistory(String historyJson) {
        if (String.isBlank(historyJson)) return '';
        try {
            List<Object> turns = (List<Object>) JSON.deserializeUntyped(historyJson);
            List<String> lines = new List<String>();
            for (Object o : turns) {
                Map<String, Object> m = (Map<String, Object>) o;
                String role = String.valueOf(m.get('role'));
                String text = String.valueOf(m.get('text'));
                lines.add((role == 'user' ? 'Agent: ' : 'Concierge: ') + text);
            }
            return String.join(lines, '\n');
        } catch (Exception e) {
            return '';
        }
    }

    // Shared Gemini callout (used by both entry points).
    private static String callGemini(String prompt) {
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        req.setEndpoint(ENDPOINT);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');

        Map<String, Object> bodyMap = new Map<String, Object>{
            'contents' => new List<Object>{
                new Map<String, Object>{
                    'parts' => new List<Object>{
                        new Map<String, Object>{ 'text' => prompt }
                    }
                }
            }
        };
        req.setTimeout(120000);
        req.setBody(JSON.serialize(bodyMap));

        HttpResponse res = http.send(req);
        if (res.getStatusCode() == 200) {
            return MBP_aiservicerequest.parseResponsePlain(res.getBody());
        }
        return 'ERROR: ' + res.getBody();
    }
}