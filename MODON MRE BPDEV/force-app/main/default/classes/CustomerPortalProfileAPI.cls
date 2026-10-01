/**
* @description       : Community/Portal Profile
* @author            : Manoj
* @last modified on  : 29-05-2025
* @last modified by  : Manoj
* --------------------------------------------------------------------------------------------------------------------
* Version       Author              Date                Comment
* 1.0           Manoj   	       29 May 2025    		Initial Draft 
* 2.0 			Manoj			   13 Oct 2025    		Update Responce
* 3.0           Manoj              11 Nov 2025    		The token is included in the request header and validated during processing.
														If the token is valid, the request is authorized and a successful response is returned, 
														otherwise, the request is rejected and an error response is generated.Error Code
**/
@RestResource(urlMapping='/CustomerPortalProfileAPI/*')
global class CustomerPortalProfileAPI {
    
    @HttpGet
    global static void findUser() {                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        req.addHeader('Content-Type', 'application/json'); // 3.0 request parameters  
        String requestId = String.valueOf(UUID.randomUUID());
        
        try {
            String userName = req.params.get('userName');
            String Password = req.params.get('password');
            String isResetPasswordReq = req.params.get('resetpassword');
            String Access_token = req.params.get('token'); // 3.0 Token passed in request parameters
            UserAccess_DTO userDto ;
            List<User> resetUsers;
            System.debug('userName: ' + userName);
            System.debug('Password: ' + Password);
            System.debug('resetpassword: ' + isResetPasswordReq);
            
            Boolean isValidtoken = false; // 3.0 Validate token presence
            if(String.isBlank(Access_token)){  
                returnErrorAPI.returnError(res, requestId, 'Missing token parameter', 200);
                return;
            }else{ // 3.0 Validate token using TokenValidator utility
                isValidtoken =TokenValidator.isTokenValid(Access_token,null);
            }if(isValidtoken){ // Process request only if token is valid
                if (String.isBlank(userName) ) {
                    returnError(res, requestId, 'Missing email parameter', 200);
                    return;
                }else if(isResetPasswordReq == 'false' || isResetPasswordReq == null){
                    System.debug('isResetPasswordReq: ' + isResetPasswordReq);
                    User userRecord = [ SELECT Id, Email, Username, FirstName, EmiratesIDNumber__c,LastName,Street, City, State, Country, PostalCode,Phone,Contact.AccountId FROM User
                                       WHERE Username = :userName LIMIT 1 ];
                    userDto =UserImageUrl.mapUserdto(userRecord);           
                    
                }else if(isResetPasswordReq == 'true' ){
                    System.debug('Decoded: ' + isResetPasswordReq);
                    Blob decodedBlob = EncodingUtil.base64Decode(Password);
                    String decodedPassword = decodedBlob.toString();
                    System.debug('Decoded: ' + decodedPassword);     //Start 3.0          
                    // Step 1: Fetch active user by email (username)
                    resetUsers = [ SELECT Id, Email, Username, FirstName, EmiratesIDNumber__c,LastName,Street, City, State, Country, PostalCode,Phone,Contact.AccountId FROM User where Username = :userName AND IsActive = TRUE limit 1];
                    
                    if (resetUsers.isEmpty()) {
                        returnError(res, requestId, 'Invalid Password Credentials', 200);     
                        return;
                    }        
                    User targetUser = resetUsers[0];
                    
                    // Step 2: Attempt password reset
                    try {
                        System.setPassword(targetUser.Id, decodedPassword); //  Only if this succeeds...
                    } catch (Exception ex) {
                        returnError(res, requestId, 'Password reset failed: ' + ex.getMessage(), 200); 
                        return;
                    }
                                   
                }
                User userRecord = [ SELECT Id, Email, Username, FirstName, EmiratesIDNumber__c,LastName,Street, City, State, Country, PostalCode,Phone,Contact.AccountId FROM User
                                   WHERE Username = :userName LIMIT 1 ];
                userDto =UserImageUrl.mapUserdto(userRecord);
                // Build success response
                APIResponse response = new APIResponse('success', requestId, userDto, null);
                res.responseBody = Blob.valueOf(JSON.serialize(response));
                res.addHeader('Content-Type', 'application/json');
                res.statusCode = 200;     
            }else{ // 3.0 Return error response if token validation fails
                returnError(res, requestId, 'Token validation failed. Please log in again.', 200);
                return;
            } //End 3.0 
        } catch (Exception ex) {
            LoggerService.save(LoggerService.createApexLog(
                ex, 'CustomerPortalProfileAPI', 'CustomerPortalProfileAPI', 'findUser'
            ));
            returnError(res, requestId, 'Server Error: ' + ex.getMessage(), 200);
        }
    }
    
    public static String updateProfile(supportCaseWrapper profileInfo,UserDTO userDto){
        return CommunityCustomerProfile.udpateUserData(userDto.FirstName,userDto.LastName,'','',profileInfo.phone,profileInfo.street,profileInfo.state,profileInfo.city,profileInfo.postalCode,profileInfo.country,profileInfo.email);
    }
    @httpPost
    global static void createSupportCase(){
        RestRequest req = RestContext.request;
        
        RestResponse res = RestContext.response; 
        String requestId = String.valueOf(UUID.randomUUID());
        UserAccess_DTO userReturnDto ;
        try{
            supportCaseWrapper caseInfo = (supportCaseWrapper) JSON.deserialize(req.requestBody.toString(), supportCaseWrapper.class);
            System.debug('>>>>>>>>>>>> '+System.JSON.serialize(caseInfo));
            string Access_token = caseInfo.token;  // 3.0 Token passed in request parameters  // Start 3.0
            string isCasewithoutlogin = caseInfo.islogin;
            Boolean isValid_token = false;
             // 3.0 Return error message
            if(String.isBlank(Access_token) && isCasewithoutlogin == 'Yes'){
                returnErrorAPI.returnError(res, requestId, 'You are not allowed to create a case', 200);
                return;
            }else if(String.isBlank(Access_token) && isCasewithoutlogin == 'No'){ // Validate token using TokenValidator utility
                isValid_token =true;                  
            }else if(!String.isBlank(Access_token) && isCasewithoutlogin == 'Yes'){ // Validate token using TokenValidator utility
                isValid_token =TokenValidator.isTokenValid(Access_token,null);
            }else if(!String.isBlank(Access_token) && isCasewithoutlogin == 'No'){  // 3.0 Return error message
                returnErrorAPI.returnError(res, requestId, 'You are not allowed to create a case', 200);
                return;
            } else {  // 3.0 Return error message
                returnErrorAPI.returnError(res, requestId, 'You are not allowed to create a case', 200);
                return;
            } // End 3.0
            
            if(caseInfo == null){
                returnError(res, requestId, 'Error! occured.', 200);
                return;
            }
            if (String.isBlank(caseInfo.email)) {
                returnError(res, requestId, 'Missing email parameter', 200);
                return;
            }
            if(isValid_token){ // Validate token using TokenValidator utility
                UserDTO userDto = CustomerPortalUserService.getUserByEmail(caseInfo.email);
                if (userDto == null) {
                    returnError(res, requestId, 'No account exists for this email address.', 200);
                    return;
                }
                if(caseInfo <> null && caseInfo.isGeneralCase && !caseInfo.isImageUpload){ //Start 3.0 
                    String returnMessage = CommunityLoginController.handleCaseCreation(caseInfo.subject, caseInfo.caseComments, userDto.email, caseInfo.mobile,true);
                    user resetUsers = [ SELECT Id, Email, Username,FirstName, EmiratesIDNumber__c,LastName,Street, City, State, Country, PostalCode,Phone,Contact.AccountId FROM User where Username = :caseInfo.email AND IsActive = TRUE limit 1];
                    if (resetUsers == null) {
                        returnError(res, requestId, 'No account exists for this email address.', 200);
                        return;
                    }else{
                        userReturnDto =UserImageUrl.mapUserdto(resetUsers);
                        APIResponse response = new APIResponse('success', requestId, userReturnDto, returnMessage);
                        res.responseBody = Blob.valueOf(JSON.serialize(response));
                        res.addHeader('Content-Type', 'application/json');
                        res.statusCode = 200; 
                    }
                }else if(caseInfo <> null && !caseInfo.isGeneralCase && !caseInfo.isImageUpload){
                    String returnMessage = updateProfile(caseInfo,userDto);
                    
                    User userRec = [SELECT Id,FirstName,LastName,Email,EmiratesIDNumber__c,UserName,Phone,Street,City,State,Country,PostalCode,Contact.AccountId,ContactId FROM User WHERE UserName =: caseInfo.email];
                    userReturnDto =UserImageUrl.mapUserdto(userRec);
                    
                    APIResponse response = new APIResponse('success', requestId, userReturnDto, returnMessage);
                    res.responseBody = Blob.valueOf(JSON.serialize(response));
                    res.addHeader('Content-Type', 'application/json');
                    res.statusCode = 200; 
                }else if(caseInfo <> null && !caseInfo.isGeneralCase && caseInfo.isImageUpload){
                    UserImageUrl.uploadUserAvatar(caseInfo.base64Image,caseInfo.userName,caseInfo.email);
                    User userRec = [SELECT Id,FirstName,LastName,Email,EmiratesIDNumber__c,UserName,Phone,Street,City,State,Country,PostalCode,Contact.AccountId,ContactId FROM User WHERE UserName =: caseInfo.email];
                    userReturnDto =UserImageUrl.mapUserdto(userRec);
                    APIResponse response = new APIResponse('success', requestId, userReturnDto, null);
                    res.responseBody = Blob.valueOf(JSON.serialize(response));
                    res.addHeader('Content-Type', 'application/json');
                    res.statusCode = 200;
                }
            }else{  // Return error response if token validation fails
                returnError(res, requestId, 'Token validation failed. Please log in again.', 200);
                return;
            } //end 3.0
        } catch (Exception ex) {
            LoggerService.save(LoggerService.createApexLog(
                ex, 'Customer Portal API', 'CustomerPortalUserAPI', 'findUser'
            ));
            returnError(res, requestId, 'Server Error: ' + ex.getMessage(), 200);
        }
    }
    private static void returnError(RestResponse res, String requestId, String msg, Integer status) {
        APIResponse error = new APIResponse('error', requestId, null, msg);
        res.responseBody = Blob.valueOf(JSON.serialize(error));
        res.addHeader('Content-Type', 'application/json');
        res.statusCode = status;
    }
    
    public class supportCaseWrapper{
        public String subject;
        public String caseComments;
        public String mobile;
        public boolean isGeneralCase;
        public String phone;
        public String email;
        public String street;
        public String city;
        public String state;
        public String postalCode;
        public String country;
        public boolean isImageUpload;
        public String base64Image;
        public String userName;
        public string token; //3.0 add parameters for Request Body 
        public string islogin; //3.0 add parameters for Request Body 
        
    }      
    
}