public without sharing class MBP_aiservicerequest {

    private static final Modon_Generic_Metadata__mdt CONFIG = Modon_Generic_Metadata__mdt.getInstance('MBP_aiservicerequest');
    private static final String API_KEY = CONFIG?.Api_Key__c;

    private static final String ENDPOINT = CONFIG?.Endpoint__c + API_KEY;


    public static Map<String, String> validateDocuments(List<Id> contentDocumentIds, String srJson) {

        System.debug('=== START MULTI DOCUMENT VALIDATION ===');

        Map<String, String> results = new Map<String, String>();
        Boolean allValid = true;

        for (Id docId : contentDocumentIds) {

            System.debug('--- Processing Document Id: ' + docId);

            try {
                ContentVersion cv = [
                    SELECT VersionData, Title
                    FROM ContentVersion
                    WHERE ContentDocumentId = :docId
                    ORDER BY VersionNumber DESC
                    LIMIT 1
                ];

                System.debug('File Name: ' + cv.Title);

                String base64Data = EncodingUtil.base64Encode(cv.VersionData);
                System.debug('Base64 Length: ' + base64Data.length());

                String response = callGemini(base64Data, srJson);

                Boolean valid = isValid(response);

                String finalOutput = 'VALUE: ' + response + ' | STATUS: ' + (valid ? 'VALID' : 'INVALID');

                System.debug('Gemini Extracted Value: ' + response);
                System.debug('Validation Status: ' + finalOutput);

                results.put(cv.Title, finalOutput);

                if (!valid) {
                    allValid = false;
                }

            } catch (Exception e) {

                System.debug('Exception for DocId ' + docId + ': ' + e.getMessage());

                results.put(String.valueOf(docId), 'ERROR: ' + e.getMessage() + ' | STATUS: INVALID');
                allValid = false;
            }
        }

        results.put('FINAL_STATUS', allValid ? 'ALL_VALID' : 'SOME_INVALID');

        System.debug('=== FINAL STATUS: ' + results.get('FINAL_STATUS') + ' ===');

        return results;
    }


    public static String validateFromDocument(Id contentDocumentId, String srJson) {

        System.debug('--- START SINGLE DOCUMENT VALIDATION ---');

        try {
            ContentVersion cv = [
                SELECT VersionData, Title
                FROM ContentVersion
                WHERE ContentDocumentId = :contentDocumentId
                ORDER BY VersionNumber DESC
                LIMIT 1
            ];

            System.debug('File Name: ' + cv.Title);

            String base64Data = EncodingUtil.base64Encode(cv.VersionData);
            System.debug('Base64 Length: ' + base64Data.length());

            String response = callGemini(base64Data, srJson);

            Boolean valid = isValid(response);

            String finalOutput = 'VALUE: ' + response + ' | STATUS: ' + (valid ? 'VALID' : 'INVALID');

            System.debug('Final Output: ' + finalOutput);

            return finalOutput;

        } catch (Exception e) {
            System.debug('Exception: ' + e.getMessage());
            return 'ERROR: ' + e.getMessage() + ' | STATUS: INVALID';
        }
    }

    private static String callGemini(String base64Data, String srJson) {

        try {
            Http http = new Http();
            HttpRequest req = new HttpRequest();
            
            req.setEndpoint(ENDPOINT);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            String prompt = 'Read the entire attached document carefully. '
                + 'Extract the main important details such as company name and key identifiers present in the document. '
                + 'Summarize the main content briefly. '
                + 'Then verify whether the document looks valid, complete, and official. '
                + 'If valid, return in this format: VALID | <MAIN_IDENTIFIER> | <COMPANY_NAME>. '
                + 'If not valid or missing critical information, return: INVALID | <REASON>. '
                + 'Do not return any extra text apart from this format.';

            System.debug('Prompt Sent: ' + prompt);

            Map<String, Object> bodyMap = new Map<String, Object>{
                'contents' => new List<Object>{
                    new Map<String, Object>{
                        'parts' => new List<Object>{
                            new Map<String, Object>{ 'text' => prompt },
                            new Map<String, Object>{
                                'inline_data' => new Map<String, Object>{
                                    'mime_type' => 'application/pdf',
                                    'data' => base64Data
                                }
                            }
                        }
                    }
                }
            };
req.setTimeout(120000);
            String requestBody = JSON.serialize(bodyMap);
            System.debug('Request Body Length: ' + requestBody.length());

            req.setBody(requestBody);

            HttpResponse res = http.send(req);

            System.debug('Status Code: ' + res.getStatusCode());
            System.debug('Response Body: ' + res.getBody());

            if (res.getStatusCode() == 200) {
                return parseResponse(res.getBody());
            } else {
                return 'ERROR: ' + res.getBody();
            }

        } catch (Exception e) {
            System.debug('Callout Exception: ' + e.getMessage());
            return 'EXCEPTION: ' + e.getMessage();
        }
    }

    public static String parseResponse(String responseBody) {

        try {
            Map<String, Object> result =
                (Map<String, Object>) JSON.deserializeUntyped(responseBody);

            List<Object> candidates = (List<Object>) result.get('candidates');

            if (candidates != null && !candidates.isEmpty()) {

                Map<String, Object> first = (Map<String, Object>) candidates[0];
                Map<String, Object> content = (Map<String, Object>) first.get('content');
                List<Object> parts = (List<Object>) content.get('parts');

                if (parts != null && !parts.isEmpty()) {

                    String output =
                        (String)((Map<String, Object>)parts[0]).get('text');

                    output = output != null ? output.trim().toUpperCase() : '';

                    System.debug('Parsed Output: ' + output);

                    return output;
                }
            }

            return 'NO_RESPONSE';

        } catch (Exception e) {
            System.debug('Parsing Exception: ' + e.getMessage());
            return 'PARSING_ERROR: ' + e.getMessage();
        }
    }


    private static Boolean isValid(String result) {

        if (String.isBlank(result)) return false;

        if (result.contains('ERROR') ||
            result.contains('EXCEPTION') ||
            result.contains('PARSING_ERROR') ||
            result.contains('NO_RESPONSE')) {
            return false;
        }

        if (result.length() < 5) return false;

        return true;
    }
    
    public static String parseResponsePlain(String responseBody) {
    try {
        Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
        List<Object> candidates = (List<Object>) result.get('candidates');
        if (candidates != null && !candidates.isEmpty()) {
            Map<String, Object> first = (Map<String, Object>) candidates[0];
            Map<String, Object> content = (Map<String, Object>) first.get('content');
            List<Object> parts = (List<Object>) content.get('parts');
            if (parts != null && !parts.isEmpty()) {
                String output = (String)((Map<String, Object>) parts[0]).get('text');
                return output != null ? output.trim() : '';
            }
        }
        return 'NO_RESPONSE';
    } catch (Exception e) {
        return 'PARSING_ERROR: ' + e.getMessage();
    }
}
}