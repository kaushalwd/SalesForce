// Utility Class: Handles JSON formatting for Genesys API responses.
global class GenesysDTO {
    
    // Formats a Lead record into a Map.
    public static Map<String, Object> formatLead(Lead lead) {
        return new Map<String, Object>{
            'ObjectId' => lead.Id,
            'ObjectType' => 'Lead',
            'FirstName' => lead.FirstName,
            'LastName' => lead.LastName,
            'Email' => lead.Email,
            'PreferredLanguage' => lead.LanguagePreference__c != null ? lead.LanguagePreference__c : ''
            };
         }
    
    // Formats an Account record into a Map.
    public static Map<String, Object> formatAccount(Account account) {
        return new Map<String, Object>{
            'ObjectId' => account.Id,
            'ObjectType' => 'Account',
            'FirstName' => account.FirstName,
            'LastName' => account.LastName,
            'Email' => account.PersonEmail,
            'PreferredLanguage' => ''
            };
         }
    
    // Formats a Contact record into a Map.
    public static Map<String, Object> formatContact(Contact contact) {
        return new Map<String, Object>{
            'ObjectId' => contact.Id,
            'ObjectType' => 'Contact',
            'FirstName' => contact.FirstName,
            'LastName' => contact.LastName,
            'Email' => contact.Email,
            'PreferredLanguage' => ''                    
            };
         }
    // Builds and sends an error response in JSON format.
    public static void createErrorResponse(String errorMessage) {
        Map<String, Object> errorResponse = new Map<String, Object>{
            'error' => true,
            'message' => errorMessage
                };
        RestContext.response.statusCode = 400;
        RestContext.response.responseBody = Blob.valueOf(JSON.serialize(errorResponse));
    }
    //Initializes the response map.
    public static Map<String, Object> initializeResponse() {
        return new Map<String, Object>{
            'successFlag' => false,
                'message' => ''
                };
        }
    
    /**
* Updates the response map with details.
*/
    public static void updateResponse(Map<String, Object> responseMap, Boolean success, String message, Integer statusCode, String UUID) {
        responseMap.put('successFlag', success);
        responseMap.put('message', message);
        responseMap.put('statusCode', statusCode);
        if(responseMap != null){
            if(String.isNotBlank(UUID)){responseMap.put('UUID', UUID);}
            System.debug('>>>> responseMap  >> '+JSON.serialize(responseMap));
            RestContext.response.responseBody = Blob.valueOf(JSON.serialize(responseMap));
            System.debug('>>>> responseMap  >> '+JSON.serialize(responseMap));
        }        
        RestContext.response.statusCode = 400;        
    }
    public static void createLeadResponse(Map<String, Object> responseMap, String leadId, String leadNumber, Boolean success, String message, String UUID) {
        responseMap.put('LeadNumber', leadNumber);
        responseMap.put('LeadId', leadId);
        responseMap.put('successFlag', success);
        responseMap.put('message', message);
        responseMap.put('UUID', UUID);
        RestContext.response.statusCode = 200;
        RestContext.response.responseBody = Blob.valueOf(JSON.serialize(responseMap));
    }
    public static void updateLeadResponse(Map<String, Object> responseMap, String salesAgent, Boolean success, String message, Integer statusCode, String UUID) {
        if(salesAgent!=''){responseMap.put('Sales Agent', salesAgent);}
        responseMap.put('successFlag', success);
        responseMap.put('message', message);
        responseMap.put('UUID', UUID);
        RestContext.response.statusCode = 200;
        RestContext.response.responseBody = Blob.valueOf(JSON.serialize(responseMap));
    }
}