/**********************************************************************************************************************
* Name               : SFGenesys_UpdateQualifyLeadAPI                                                        
* Description        : Used for Qualifying the lead from Genesys or Whatsapp
* Usage              : 
* Created By         :                                                      
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           HZTL                             15 Sep 2025        Added Unit field for Modon Egypt   
* 2.0			Suresh							 06 May 2026		UAEResidenceStatus and Nationality added 
* 3.0			Suresh							 03 Sep 2026		Added PreferredCallbackDay -> Lead.PreferredContactTime__c.
*																	OPTIONAL: absent/blank is always fine and never blocks the
*																	update. Not validated here - the picklist itself will reject
*																	an unknown value if it is restricted.
*																	NOTE: PreferredContactTime__c is ALSO the target of the v1.0
*																	CallbackTimeslot field. The service layer only applies
*																	PreferredCallbackDay when CallbackTimeslot was not sent, so
*																	existing Genesys behaviour is unchanged.
* 3.1           Jay Patel                   21 Sep 2026     MCR-73 — with sharing
******************************************************************************************************************/
@RestResource(urlMapping='/updateLead/*')
global with sharing class SFGenesys_UpdateQualifyLeadAPI {
    
    //Entry point for updating the preferred language.
    //Handles the HTTP POST request.
    @HttpPost
    global static void updateLeadRecord() {
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
            String leadId = (String) inputMap.get('LeadId');
            Boolean qualifyLead = (Boolean) inputMap.get('QualifyLead');//Boolean    IsConverted
            String projectName = (String) inputMap.get('ProjectName');//ProjectInterest__c or ProjectInterest
            String bedroomType = (String) inputMap.get('BedroomType');//NumberOfBedrooms__c
            String investment = (String) inputMap.get('Investment');
            String budgetOption = (String) inputMap.get('BudgetOption');//CustomerBudget__c
            String finance = (String) inputMap.get('Finance');
            String contactChannel = (String) inputMap.get('ContactChannel'); //LeadSource
            String callbackTime = (String) inputMap.get('CallbackTimeslot');
            String comments = (String) inputMap.get('Comments');
            String unitType = inputMap.containsKey('UnitType') ? (String) inputMap.get('UnitType') : null; //UnitType__c
            //2.0
            String uaeResidenceStatus = (String) inputMap.get('UAEResidenceStatus');
            String nationality = (String) inputMap.get('Nationality');
            //3.0 - OPTIONAL picklist. Accepts both PascalCase and camelCase spellings from Genesys.
            String preferredCallbackDay = readValue(inputMap, new List<String>{'PreferredCallbackDay', 'preferredCallbackDay'}); //PreferredContactTime__c
            if(leadId.length() <> 18 && leadId.length() <> 15){
                GenesysDTO.createErrorResponse('Lead Id is not valid.'); 
                return;
            }
            List<String> projectNames = System.Label.SFGenesysProjectNames.split(',');
            List<String> bedroomTypes = System.Label.SFGenesysBedroomTypes.split(',');
            System.debug('requestId: '+requestId);
            System.debug('preferredCallbackDay: '+preferredCallbackDay); //3.0
            if(String.isNotBlank(leadId)){ 
                    //2.0
                    //3.0 - pass preferredCallbackDay (optional) through to the service layer
                    SFGenesys_Services.updateQualifyLeadInSF(leadId, qualifyLead, projectName, bedroomType, 
                                                             investment, budgetOption, finance, contactChannel, 
                                                             callbackTime, comments, unitType, uaeResidenceStatus, nationality, 
                                                             preferredCallbackDay, req, res, requestId); 
            }else{
                GenesysDTO.updateResponse(responseMap, false, 'Lead Id should not be null.', 400, '');  
            }
        }        
        catch (Exception e) {
            LoggerService.save(LoggerService.createApexLogforGenesys(e, 'SF Genesys Update Lead API','SFGenesys_UpdateQualifyLeadAPI','updateLeadRecord', requestId));
            GenesysDTO.updateResponse(responseMap, false, e.getMessage(), 500, requestId);
        }
    }

    /**
     * 3.0 - reads the first non-blank value from a list of candidate keys, so the endpoint tolerates
     * both camelCase and PascalCase spellings from Genesys. Returns null if none are present.
     * Values are read via String.valueOf so a numeric/boolean JSON value does not throw a cast exception.
     */
    private static String readValue(Map<String, Object> inputMap, List<String> keys) {
        for (String key : keys) {
            Object value = inputMap.get(key);
            if (value != null && String.isNotBlank(String.valueOf(value))) {
                return String.valueOf(value);
            }
        }
        return null;
    }
}