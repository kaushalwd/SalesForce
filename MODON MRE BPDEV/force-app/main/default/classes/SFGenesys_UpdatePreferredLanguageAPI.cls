/**********************************************************************************************************************
* Name               : SFGenesys_UpdatePreferredLanguageAPI
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.1           Jay Patel                   21 Sep 2026     MCR-73 — with sharing
******************************************************************************************************************/
@RestResource(urlMapping='/setPreferredLanguage/*')
global with sharing class SFGenesys_UpdatePreferredLanguageAPI {
    //Entry point for updating the preferred language.
    //Handles the HTTP POST request.
    @HttpPost
    global static void setPreferredLanguage() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        Boolean isUpdated;
        // Initialize logging and response map
        String requestId = String.valueOf(UUID.randomUUID().toString());
        Map<String, Object> responseMap = GenesysDTO.initializeResponse();
        try {
            // Parse input request
            Map<String, Object> inputMap = (Map<String, Object>) JSON.deserializeUntyped(req.requestBody.toString());
            List<String> availableLanguages = System.Label.SFGenesysAvailableLanguages.split(',');
            String objectId = (String) inputMap.get('ObjectId');
            String language = (String) inputMap.get('Language');
            
            // Validate input
            if (String.isBlank(objectId) || String.isBlank(language)) {
                GenesysDTO.createErrorResponse('ObjectId and Language are required.');
                return;
            }
            if(objectId.length() <> 18 && objectId.length() <> 15){
                GenesysDTO.createErrorResponse('ObjectId is not valid.'); 
                return;
            }
            // Update preferred language
            if(availableLanguages.contains(language))
                isUpdated = SFGenesys_Services.updatePreferredLanguage(objectId, language);
            if(isUpdated){
                GenesysDTO.updateResponse(responseMap, true, 'Language Preference updated successfully.', 200, requestId);
            }else{
                GenesysDTO.updateResponse(responseMap, true, 'Language Preference already Updated.', 200, '');
            }
            
        }  catch (Exception e) {
            LoggerService.save(LoggerService.createApexLogforGenesys(e, 'SF Genesys Update Preferred Language API','SFGenesys_Services','setPreferredLanguage', requestId));
            GenesysDTO.updateResponse(responseMap, false, e.getMessage(), 500, requestId);
        }
        
        // Log response details
        LoggerService.save(LoggerService.createAPILogforGenesys('SF Genesys Update Preferred Language API', 'SFGenesys_Services', 'setPreferredLanguage', JSON.serialize(req),res.responseBody != null ? res.responseBody.toString() : '', 'Status Code: ' + res.statusCode, 'WebService Callout Log', requestId));
        // Send response
        res.addHeader('Content-Type', 'application/json');
        res.responseBody = Blob.valueOf(JSON.serialize(responseMap));
        res.statusCode = (Integer) responseMap.get('statusCode');
    }
}