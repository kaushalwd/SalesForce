/**********************************************************************************************************************
* Name               : WhatsAppOutboundClient
* Description        : Shared HTTP client for outbound WhatsApp campaign messages
* Created By         : Prateek Bansal
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment
* 1.0           Prateek Bansal                    12 May 2026     Initial shared WhatsApp outbound client
* 1.1           Narendra Agrawal                  06 Sep 2026     Removed hardcoded Endpoint URL and API Key. Values are taken
*                                                                 only from Outbound_Message_Config__mdt. If config is null,
*                                                                 inactive, or Endpoint URL / API Key is blank, the send fails
*                                                                 with an error on the Response (no callout).
**********************************************************************************************************************/
public without sharing class WhatsAppOutboundClient {
    public static Response send(String payload) {
        return send(payload, null);
    }

    public static Response send(String payload, MessagingConfigService.OutboundConfig config) {
        if (String.isBlank(payload)) {
            return fail('WhatsApp payload is required.'); // 1.2
        }

        // 1.2: refuse the callout unless CMDT is present, active, and has endpoint + API key
        String configError = validateConfig(config);
        if (configError != null) {
            return fail(configError); // 1.2
        }

        HttpRequest request = new HttpRequest();
        request.setEndpoint(config.endpointUrl); // 1.2: CMDT Endpoint_URL__c only
        request.setMethod('POST');
        request.setTimeout(120000);
        request.setHeader('Content-Type', 'application/json');
        request.setHeader('Accept', 'application/json');
        request.setHeader(getApiKeyHeader(config), config.apiKey); // 1.2: CMDT Api_Key__c only
        request.setBody(payload);

        HttpResponse httpResponse = new Http().send(request);
        Response response = new Response();
        response.statusCode = httpResponse == null ? 0 : httpResponse.getStatusCode();
        response.body = httpResponse == null ? null : httpResponse.getBody();
        response.externalMessageId = extractExternalMessageId(response.body);
        response.success = response.statusCode >= 200 && response.statusCode < 300;
        if (!response.success) {
            response.errorMessage = 'WhatsApp API failed with status ' + response.statusCode;
        }
        return response;
    }

    // 1.2: no hardcoded fallback — config null / inactive / blank endpoint or API key is an error
    private static String validateConfig(MessagingConfigService.OutboundConfig config) {
        if (config == null) { // 1.2
            return 'WhatsApp outbound config is missing.';
        }
        if (config.isActive != true) { // 1.2
            return 'WhatsApp outbound config is inactive.';
        }
        if (String.isBlank(config.endpointUrl)) { // 1.2
            return 'WhatsApp outbound Endpoint URL is not configured.';
        }
        if (String.isBlank(config.apiKey)) { // 1.2
            return 'WhatsApp outbound API key is not configured.';
        }
        return null;
    }

    // 1.2: put the error on Response instead of throwing
    private static Response fail(String errorMessage) {
        Response response = new Response();
        response.success = false;
        response.errorMessage = errorMessage;
        return response;
    }

    private static String getApiKeyHeader(MessagingConfigService.OutboundConfig config) {
        return String.isBlank(config.apiKeyHeader) ? 'x-api-key' : config.apiKeyHeader; // 1.2
    }

    private static String extractExternalMessageId(String responseBody) {
        if (String.isBlank(responseBody)) return null;
        try {
            Object parsed = JSON.deserializeUntyped(responseBody);
            if (parsed instanceof Map<String, Object>) {
                return getMessageIdFromMap((Map<String, Object>) parsed);
            }
            if (parsed instanceof List<Object>) {
                List<Object> rows = (List<Object>) parsed;
                if (!rows.isEmpty() && rows[0] instanceof Map<String, Object>) {
                    return getMessageIdFromMap((Map<String, Object>) rows[0]);
                }
            }
        } catch (Exception ex) {
            return null;
        }
        return null;
    }

    private static String getMessageIdFromMap(Map<String, Object> values) {
        if (values == null) return null;
        for (String key : new List<String>{ 'message_id', 'messageId', 'MessageId', 'id', 'Id' }) {
            if (values.containsKey(key) && values.get(key) != null) {
                return String.valueOf(values.get(key));
            }
        }
        return null;
    }

    public class Response {
        public Boolean success;
        public Integer statusCode;
        public String body;
        public String externalMessageId;
        public String errorMessage;
    }
}