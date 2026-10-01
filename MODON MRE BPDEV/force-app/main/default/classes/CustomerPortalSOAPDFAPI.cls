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
*                                                       an appropriate error response.Error Code
* 4.0 			Manoj              17 Jan 2026         Add userName for the header
**/
@RestResource(urlMapping='/CustomerPortalSOAPDFAPI/*')
global class CustomerPortalSOAPDFAPI {
    /**
* HTTP GET API
* Retrieves SOA details for the given Sales Order.
*
* Request Parameters:
* - SOId  : Sales Order Name
* - token : Access token for request validation (3.0)
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
            String salesorderName = req.params.get('SOId');
            String Access_token = req.params.get('token'); // 3.0 Token passed in request parameters
            if (String.isBlank(salesorderName)) {
                returnErrorAPI.returnError(res, requestId, 'Missing salesorder parameter', 200);
                return;
            }//4.0 start Add userName 
            String userName = req.params.get('userName');
            if (String.isBlank(userName)) {
                returnErrorAPI.returnError(res, requestId, 'Missing salesorder parameter as userName', 200);
                return;
            } //4.0 end
            SOAPdfController.SOAWrapper soaDetails ;
            Boolean isValidtoken = false;// 3.0 Token validation
            if(String.isBlank(Access_token)){  //3.0 Return error response if token missed farequest parameters
                returnErrorAPI.returnError(res, requestId, 'Missing token parameter', 200);
                return;
            }else{ // 3.0 Validate token using centralized validator
                isValidtoken =TokenValidator.isTokenValid(Access_token,null);
            }
            if(isValidtoken){   // Process request only if token is valid
                soaDetails =new SOAPdfController.SOAWrapper();            
                if (salesorderName != null) {                    
                    String salesOrderId = null;                    
                    List<SalesOrder__c> soRec = [ SELECT Id FROM SalesOrder__c WHERE Name = :salesorderName AND CustomerAccount__r.PersonEmail = :userName LIMIT 1];
                     // If Sales Order not found, check Joint Owner
                    if (soRec.size() == 0) {                        
                        List<JointOwner__c> joinOwner = [SELECT Id, SalesOrder__c FROM JointOwner__c WHERE SalesOrder__r.Name = :salesorderName AND JointOwnerAccount__r.PersonEmail = :userName LIMIT 1];
                        
                        if (joinOwner.size() == 0) {
                            returnErrorAPI.returnError(res, requestId, 'No data found', 200);
                            return;
                        } else {
                            salesOrderId = joinOwner[0].SalesOrder__c;
                        }                        
                    } else {
                        salesOrderId = soRec[0].Id;
                    }                    
                    // Fetch SOA Data
                    if (salesOrderId != null) {
                        soaDetails = SOAPdfController.getSOAData(salesOrderId);
                    } else {
                        returnErrorAPI.returnError(res, requestId, 'No data found', 200);
                        return;
                    }
                    
                } else {
                    returnErrorAPI.returnError(res, requestId, 'No data found', 200);
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
            
        } catch (Exception ex) { // Return generic server error response
            LoggerService.save(LoggerService.createApexLog(ex, 'Customer Portal API', 'CustomerPortalUserAPI', 'findUser'));
            returnErrorAPI.returnError(res, requestId, 'Server Error: ' + ex.getMessage(), 200);
        }
    }
    
}