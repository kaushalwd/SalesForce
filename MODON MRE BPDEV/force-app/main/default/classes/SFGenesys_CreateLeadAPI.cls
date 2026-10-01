/**********************************************************************************************************************
* Name               : SFGenesys_CreateLeadAPI
* Description        : REST endpoint to create a Lead from Genesys
* --------------------------------------------------------------------------------------------------------------------
* Version       Author        Date            Comment
* 3.1           Arvind        18 Jul 2026     Added ConversationId: extracted from the request body and stored on
*                                             Lead.Conversation_Id__c. API response is UNCHANGED (leadId, leadNumber).
* 3.2           Arvind        20 Jul 2026     'ani' in the request is accepted but ignored (not stored, not returned).
* 3.3           Arvind        21 Jul 2026     Email is now OPTIONAL for lead creation. A lead can be created without
*                                             an email; but if an email IS provided it must be a valid format,
*                                             otherwise the request is still rejected as "Email is not valid".
******************************************************************************************************************/
@RestResource(urlMapping='/createLead/*')
global class SFGenesys_CreateLeadAPI {

    //Handles the HTTP POST request.
    @HttpPost
    global static void createLeadRecord() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');
        // Initialize logging and response map
        String requestId = String.valueOf(UUID.randomUUID().toString());
        Map<String, Object> responseMap = GenesysDTO.initializeResponse();
        try {
            // Parse input request
            Map<String, Object> inputMap = (Map<String, Object>) JSON.deserializeUntyped(req.requestBody.toString());
            // Extract fields
            String firstName = (String) inputMap.get('FirstName');
            String lastName = (String) inputMap.get('LastName');
            String email = (String) inputMap.get('Email');
            String phone = (String) inputMap.get('Phone');
            String leadSource = (String) inputMap.get('LeadSource');
            String leadSubSource = (String) inputMap.get('LeadSubSource');
            String preferLanguage = (String) inputMap.get('Language');
            String projectName = (String) inputMap.get('ProjectName');
            String sourceEntity = (String) inputMap.get('SourceEntity');
            // v3.1 Arvind: extract the Genesys conversation id (accept both key styles)
            String conversationId = (String) inputMap.get('ConversationId');
            if (String.isBlank(conversationId)) {
                conversationId = (String) inputMap.get('conversation_id');
            }
            // v3.2 Arvind: 'ani' in the request is intentionally ignored - not stored, not returned.
            System.debug('firstName: '+ firstName);
            System.debug('lastName: '+ lastName);
            System.debug('email: '+ email);
            System.debug('phone: '+ phone);
            System.debug('leadSource: '+ leadSource);
            System.debug('leadSubSource: '+ leadSubSource);
            System.debug('preferLanguage: '+ preferLanguage);
            System.debug('projectName: '+ projectName);
            System.debug('sourceEntity: '+ sourceEntity);
            System.debug('conversationId: '+ conversationId); // v3.1 Arvind
            String sanitizedEmail = SFGenesys_Services.sanitizeEmail(email);
            String sanitizedphone = SFGenesys_Services.matchPhoneNumberPattern(phone, sourceEntity);
            // v3.3 Arvind: email is optional. It's only a validation failure if an email was
            // actually provided but is malformed (sanitizeEmail returned null for a non-blank input).
            Boolean emailProvidedButInvalid = String.isNotBlank(email) && sanitizedEmail == null;
            List<String> leadSourceLabel = System.Label.SFGenesysLeadSources.split(',');
            List<String> leadSubSourceLabel = System.Label.SFGenesysLeadSubSources.split(',');
            List<String> preferLanguageLabel = System.Label.SFGenesysLeadLanguagePreference.split(',');
            List<String> validSourceEntities = System.Label.SFGenesysSourceEntities.split(',');
            System.debug('sanitizedEmail: '+ sanitizedEmail);
            System.debug('sanitizedphone: '+ sanitizedphone);
            if(lastName <> null && !emailProvidedButInvalid && sanitizedphone <> null 
               && leadSourceLabel.contains(leadSource) 
               && (leadSubSource == null || leadSubSourceLabel.contains(leadSubSource)) 
               && (preferLanguage == null || preferLanguageLabel.contains(preferLanguage))
               && (sourceEntity == null || validSourceEntities.contains(sourceEntity))){
                System.debug('email valid or not provided: '+ sanitizedEmail);
                System.debug('sanitizedphone: '+ sanitizedphone);
                // v3.1 Arvind: pass conversationId through to the service layer
                // v3.3 Arvind: sanitizedEmail may be null here (email optional) - service handles a null email
                SFGenesys_Services.createLeadInSF(firstName, lastName, sanitizedEmail, sanitizedphone, leadSource, 
                                                  leadSubSource, preferLanguage, projectName, sourceEntity, conversationId, req, res, requestId);
            }else if (lastName == null){
                System.debug('lastName should not null: '+ sanitizedEmail);
                GenesysDTO.updateResponse(responseMap, false, 'Last Name should not null', 400, '');  
            }
            else if (emailProvidedButInvalid){
                System.debug('email not valid: '+ email);
                GenesysDTO.updateResponse(responseMap, false, 'Email is not valid', 400, '');  
            }
            else if (sanitizedphone == null){
                System.debug('Phone not matching the pattern: '+ sanitizedphone);
                if (sourceEntity == 'Modon - Egypt'){
                    GenesysDTO.updateResponse(responseMap, false, 'Phone should match the pattern e.g, 00000', 400, ''); 
                } else {
                    GenesysDTO.updateResponse(responseMap, false, 'Phone should match the pattern e.g, +00000', 400, ''); 
                }
            }else if (!leadSourceLabel.contains(leadSource)){
                System.debug('Lead Source is not valid: '+ leadSource);
                GenesysDTO.updateResponse(responseMap, false, 'Lead Source is not valid', 400, '');  
            }else if (!leadSubSourceLabel.contains(leadSubSource)){
                System.debug('Lead Sub-Source is not valid: '+ leadSubSource);
                GenesysDTO.updateResponse(responseMap, false, 'Lead Sub-Source is not valid', 400, '');  
            }else if (!preferLanguageLabel.contains(preferLanguage)){
                System.debug('Preferred Language is not valid: '+ preferLanguage);
                GenesysDTO.updateResponse(responseMap, false, 'Language is not valid', 400, '');  
            }else if (sourceEntity != null && !validSourceEntities.contains(sourceEntity)){
                System.debug('Source Entity is not valid: ' + sourceEntity);
  		        GenesysDTO.updateResponse(responseMap, false, 'Source Entity is not valid', 400, '');
            }else{
                return;
            }
        }
        catch (Exception e) {
            LoggerService.save(LoggerService.createApexLogforGenesys(e, 'SF Genesys Create Lead API','SFGenesys_CreateLeadAPI','createLeadRecord', requestId));
            GenesysDTO.updateResponse(responseMap, false, e.getMessage(), 500, '');
        }  
    }
}