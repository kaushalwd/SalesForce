/**
 * REST API Class: Handles customer identification based on phone number
 * API Name: IdentificationCustomer
 * Description: Supports GET operation and joins for data conversion. Uses dedicated service and utility classes.
 */
@RestResource(urlMapping='/customerIdentification/*')
global class SFGenesys_CustomerIdentificationAPI {

    // HTTP GET Method: Processes the request to find customer records by phone number.
    @HttpGet
    global static void findCustomersByPhoneNumber() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        String phoneNumber;String email;
        String requestId = String.valueOf(UUID.randomUUID().toString());
        try {
            phoneNumber = req.params.get('phoneNumber');
            email = req.params.get('email'); 
            if (String.isBlank(phoneNumber) && String.isBlank(email)) {
                GenesysDTO.createErrorResponse('Phone number & Email parameter is missing');
                return;
            }
            // Sanitize phone number
            if (String.isNotBlank(phoneNumber)){
                phoneNumber = SFGenesys_Services.sanitizePhoneNumber(phoneNumber);
            }
            if (String.isNotBlank(email)){
                email = SFGenesys_Services.sanitizeEmail(email);
            }
        //} 
            // Handle lead identification logic in service class
            SFGenesys_Services.processRequest(phoneNumber, email, req, res);
        } catch (Exception e) { 
            //PARAMS: Exception ex, string processName, string className, string methodName
            LoggerService.save(LoggerService.createApexLog(e, 'SF Genesys Customer Identification API','SFGenesys_Services','processRequest'));
            GenesysDTO.createErrorResponse('Exception: ' + e.getMessage());
        }
    }
}