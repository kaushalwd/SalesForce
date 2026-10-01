@RestResource(urlMapping='/CustomerPortalSignUpAPI/*')
global class CustomerPortalSignUpAPI {
    @HttpPost
    global static void createLeadFromSignup() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        String requestId = String.valueOf(UUID.randomUUID());
        
        try {
            // Parse JSON body to wrapper
            SignupWrapper signupInfo = (SignupWrapper) JSON.deserialize(req.requestBody.toString(), SignupWrapper.class);
            
           if (String.isBlank(signupInfo.firstName) || String.isBlank(signupInfo.lastName) || String.isBlank(signupInfo.email) || String.isBlank(signupInfo.phone)) {
                returnError(res, requestId, 'First Name, Last Name, Phone, Email are required.', 400);
                return;
            }
            
            Lead newLead = new Lead(
                FirstName = signupInfo.firstName, 
                LastName =  signupInfo.lastName,
                Email = signupInfo.email,
                Phone = signupInfo.phone,
                LeadSource = 'Web',
                Status = 'New'
            );
            
            insert newLead;
            
            APIResponse response = new APIResponse('success', requestId, newLead.Id, null);
            res.responseBody = Blob.valueOf(JSON.serialize(response));
            res.addHeader('Content-Type', 'application/json');
            res.statusCode = 201; // Created
            
        } catch (Exception e) {
            LoggerService.save(LoggerService.createApexLog(
                e, 'Customer Portal API', 'CustomerPortalSignupAPI', 'createLeadFromSignup'
            ));
            returnError(res, requestId, 'Server Error: ' + e.getMessage(), 500);
        }
    }
    
    private static void returnError(RestResponse res, String requestId, String msg, Integer status) {
        APIResponse error = new APIResponse('error', requestId, null, msg);
        res.responseBody = Blob.valueOf(JSON.serialize(error));
        res.statusCode = status;
    }
    
    global class SignupWrapper {
        public String firstName;
        public String lastName;
        public String email;
        public String phone;
    }
    
}