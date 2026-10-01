/**
* @description       : Community / Portal API to retrieve SOA (Statement of Account) data
*                      for a Sales Order.
* @author            : Manoj
* @last modified on  : 12-16-2025
* @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
* --------------------------------------------------------------------------------------------------------------------
* Version       Author              Date                Comment
* 1.0           Manoj   	       29 May 2025    		Initial Draft 
* 2.0 			Manoj			   13 Oct 2025    		Update Responce
* 3.0           Manoj              11 Nov 2025         Token-based request validation implemented.
*                                                       The token is included in the request and validated during processing.
*                                                       If the token is valid, the request is authorized and a successful
*                                                       response is returned; otherwise, the request is rejected with
*                                                       an appropriate error response.Error code.
**/
@RestResource(urlMapping='/CustomerPortalSOAAPI/*')
global class CustomerPortalSOAAPI {
     /**
     * HTTP GET API
     * Retrieves SOA details for the given Sales Order.
     *
     * Request Parameters:
     * - SOId  : Sales Order Name
     * - token : Access token for request validation (v3.0)
     *
     * Response:
     * - Success: Returns SOAWrapper data
     * - Error  : Returns standardized error response
     */
    @HttpGet
    global static void findSOADetails() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        String requestId = String.valueOf(UUID.randomUUID());
        try {
            String salesorderId = req.params.get('SOId');
            String Access_token = req.params.get('token'); // 3.0 Token passed in request parameters
            if (String.isBlank(salesorderId)) {
                returnErrorAPI.returnError(res, requestId, 'Missing salesorder parameter', 200);
                return;
            }
            Boolean isValidtoken = false; // 3.0 Token validation
            if(String.isBlank(Access_token)){  //3.0 Return error response if token missed farequest parameters
                returnErrorAPI.returnError(res, requestId, 'Missing token parameter', 200);
                return;
            }else{ // 3.0 Validate token using centralized validator
                isValidtoken =TokenValidator.isTokenValid(Access_token,null);
            }
            SOAControllerV1.SOAWrapper soaDetails =new SOAControllerV1.SOAWrapper();  
            if(isValidtoken){  // 3.0 Proceed only if token is valid 
                if(salesorderId != null ){ 
                    SalesOrder__c soRec =[select id from SalesOrder__c where Name =:salesorderId limit 1];
                    if(soRec != null){
                        soaDetails = SOAControllerV1.getSOAData(soRec.id);
                    }else{
                        returnErrorAPI.returnError(res, requestId, 'There is no Unit found', 200);
                        return;
                    }
                }else { //3.0 Return error response
                    returnErrorAPI.returnError(res, requestId, 'There is no Unit found', 200);
                    return;
                }
            }else{ //3.0 Return error response if token validation fails
                returnErrorAPI.returnError(res, requestId, 'Token validation failed. Please log in again.', 200);
                return;
            }// Build success response
            APIResponse response = new APIResponse('success', requestId, soaDetails, null);
            res.responseBody = Blob.valueOf(JSON.serialize(response));
            res.addHeader('Content-Type', 'application/json');
            res.statusCode = 200;
        } catch (Exception ex) {  // Return generic server error response
            LoggerService.save(LoggerService.createApexLog(
                ex, 'Customer Portal API', 'CustomerPortalUserAPI', 'findUser'
            ));
            returnErrorAPI.returnError(res, requestId, 'Server Error: ' + ex.getMessage(), 200);
        }
    }
}