/**
* @description       : Community/Portal Home APIs (bulkified)
* @author            : Manoj
* @last modified on  : 12-16-2025
* @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
* --------------------------------------------------------------------------------------------------------------------
* Version       Author              Date                Comment
* 1.0           Manoj			    27 Aug 2025       Initial Draft
* 2.0           Krishna Chaitanya   10 Oct 2025       Update the logic
* 3.0           Manoj               11 Nov 2025       Token-based request validation implemented.
*                                                       The token is included in the request and validated during processing.
*                                                       If the token is valid, the request is authorized and a successful
*                                                       response is returned; otherwise, the request is rejected with
*                                                       an appropriate error response.Error Code
* 4.0           Prateek             13 Apr 2026       Added logic for saving the API log records in Logger__c object for successful and error response.
**/
@RestResource(urlMapping='/CustomerPortalUnitsAPI/*')
global class CustomerPortalUnitsAPI {
     /**
     * HTTP GET API
     * Retrieves SOA details for the given Sales Order.
     *
     * Request Parameters:
     * - userName  : email id 
     *  - eidNumber  : eid for customer 
     *  - passportNumber  :Passport for customer
     * - token : Access token for request validation (3.0)
     *
     * Response:
     * - Success: Returns SOAWrapper data
     * - Error  : Returns standardized error response
     */
    @HttpGet
    global static void findUnits() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        String requestId = String.valueOf(UUID.randomUUID());
        try {
            String userName = req.params.get('userName');
            String eidNumber = req.params.get('eidNumber'); // 3.0 eidNumber passed in request parameters
            String passportNumber = req.params.get('passportNumber'); // 3.0 passportNumber passed in request parameters
            String Access_token = req.params.get('token'); // 3.0 Token passed in request parameters
            if (String.isBlank(userName)) {
                returnError(res, requestId, 'Missing userName parameter', 200);
                return;
            }
            Boolean isValidtoken = false; // 3.0 Token validation
            if(String.isBlank(Access_token)){ //3.0 Return error response if token missed farequest parameters
                returnError(res, requestId, 'Missing token parameter', 200);
                return;
            }else{ // 3.0 Validate token using centralized validator
                isValidtoken =TokenValidator.isTokenValid(Access_token,null);
            }
            
            List<CommunityHomeControllerAPI.SalesOrderWrapper> communithomeCon =new List<CommunityHomeControllerAPI.SalesOrderWrapper>();
            
            if(isValidtoken){// 3.0 Validate token using centralized validator
                UserDTO userDto = CustomerPortalUserService.getUserByEmail(userName);            
                if (userDto == null) {
                    returnError(res, requestId, 'User not found', 200);
                    return;
                }else{
                    string accountId =userDto.accountId;
                    communithomeCon = CommunityHomeControllerAPI.getSalesOrdersByCustomer(accountId,eidNumber,passportNumber);
                }
            }else{ //3.0 Return error response if token validation fails
                returnError(res, requestId, 'Token validation failed. Please log in again.', 200);
                return;
            } 
            // Build success response
            APIResponse response = new APIResponse('success', requestId, communithomeCon, null);
            LoggerService.save(LoggerService.createAPILogCP('get unit details','CustomerPortalUnitsAPI','findUnits',String.valueOf(req),String.valueOf(communithomeCon),'200','success',''));//4.0
            res.responseBody = Blob.valueOf(JSON.serialize(response));
            res.addHeader('Content-Type', 'application/json');
            res.statusCode = 200;
        } catch (Exception ex) { //3.0 Return error response
            LoggerService.save(LoggerService.createApexLog(
                ex, 'Customer Portal API', 'CustomerPortalUserAPI', 'findUser'
            ));
            returnError(res, requestId, 'Server Error: ' + ex.getMessage(), 200);
        }
    }
    // Return generic server error response
    private static void returnError(RestResponse res, String requestId, String msg, Integer status) {
        LoggerService.save(LoggerService.createAPILogCP('get unit details','CustomerPortalUnitsAPI','findUnits',requestId,String.valueOf(res),String.valueOf(status),'error',msg));//4.0
        APIResponse error = new APIResponse('error', requestId, null, msg);
        res.responseBody = Blob.valueOf(JSON.serialize(error));
        res.statusCode = status;
    }
    
}