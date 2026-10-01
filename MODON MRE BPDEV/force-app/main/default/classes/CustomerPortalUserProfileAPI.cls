/**
* @description       : Community/Portal user ProfileAPI
* @author            : Krishna Chaitanya
* @last modified on  : 12-16-2025
* @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
* --------------------------------------------------------------------------------------------------------------------
* Version       Author              Date                Comment
* 1.0           Krishna Chaitanya   13 May 2025   		Initial Draft 
* 2.0           Manoj              11 Nov 2025         Token-based request validation implemented.
*                                                       The token is included in the request and validated during processing.
*                                                       If the token is valid, the request is authorized and a successful
*                                                       response is returned; otherwise, the request is rejected with
*                                                       an appropriate error response and Error code.
* 3.0		   Manoj			  10 Mar 2026			Add email to SOQL
**/
@RestResource(urlMapping='/CustomerPortalUserProfileAPI/*')
global class CustomerPortalUserProfileAPI {
      /**
     * HTTP GET API
     * Retrieves SOA details for the given Sales Order.
     *
     * Request Parameters:
     * - userId
     * -password
     * -resetpassword
     * - token : Access token for request validation (3.0)
     *
     * Response:
     * - Success: Returns SOAWrapper data
     * - Error  : Returns standardized error response
     */
    @HttpGet
    global static void getUserDetails() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        String requestId = String.valueOf(UUID.randomUUID());
        
        try {
            String userId = req.params.get('userId');
            String password = req.params.get('password');
            String isResetPasswordReq = req.params.get('resetpassword');
            String Access_token = req.params.get('token'); // 2.0 Token passed in request parameters
            
            Boolean isReset = isResetPasswordReq == 'true';
            if (String.isBlank(userId)) {
                returnError(res, requestId, 'Missing userId parameter', 200);
                return;
            }
            Boolean isValidtoken = false; // 2.0 Token validation
            if(String.isBlank(Access_token)){ //2.0 Return error response if token missed farequest parameters
                returnError(res, requestId, 'Missing token parameter', 200);
                return;
            }else{  // 2.0 Validate token using centralized validator
                isValidtoken =TokenValidator.isTokenValid(Access_token,null);
            }
            if(isValidtoken){  // 2.0 Process request only if token is valid                
                User userRecord = [ SELECT Id, Email, Username, FirstName, EmiratesIDNumber__c,LastName,Street, City, State, Country, PostalCode,Phone,Contact.AccountId FROM User
                                   WHERE Id = :userId LIMIT 1 ];
                
                
                // Handle reset password if requested
                if (isReset && !String.isBlank(password)) {
                    Blob decodedBlob = EncodingUtil.base64Decode(password);
                    String decodedPassword = decodedBlob.toString();
                    
                    try {
                        System.setPassword(userRecord.Id, decodedPassword);
                    } catch (Exception ex) {
                        returnError(res, requestId, 'Password reset failed: ' + ex.getMessage(), 200);
                        return;
                    }                
                }
                
                // Get user's profile image URL (from ContentDocumentLink)
                String imageUrl = getUserImageUrl(userRecord.Id);
                
                // Use existing UserAccess_DTO constructor
                UserAccess_DTO dto = new UserAccess_DTO(
                    userRecord.Id,
                    userRecord.Email,
                    userRecord.Username,
                    userRecord.FirstName,
                    userRecord.LastName,
                    userRecord.Contact.AccountId, 
                    userRecord.Street,
                    userRecord.State,
                    userRecord.City,
                    userRecord.Country,
                    userRecord.PostalCode,
                    userRecord.EmiratesIDNumber__c,
                    userRecord.Phone,
                    imageUrl
                );        
                // Build success response
                APIResponse response = new APIResponse('success', requestId, dto, null);
                res.responseBody = Blob.valueOf(JSON.serialize(response));
                res.addHeader('Content-Type', 'application/json');
                res.statusCode = 200;
            }
            
        } catch (Exception ex) { //2.0 Return error response
            LoggerService.save(LoggerService.createApexLog(
                ex, 'Customer Portal API', 'UserDetailsAPI', 'getUserDetails'
            ));
            returnError(res, requestId, 'Server Error: ' + ex.getMessage(), 200);
        }
    }
    // Helper method to fetch image URL from ContentDocumentLink
    private static String getUserImageUrl(Id userId) {
        List<ContentDocumentLink> docLinks = [SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :userId LIMIT 1 ];
        if (!docLinks.isEmpty()) {
            ContentVersion cv = [SELECT Id, ContentDocumentId, VersionData, Title FROM ContentVersion WHERE ContentDocumentId = :docLinks[0].ContentDocumentId 
                                 ORDER BY CreatedDate DESC LIMIT 1 ];
            return 'data:image/jpeg;base64,' + EncodingUtil.base64Encode(cv.VersionData);
        }
        return null;
    }
    
    // Error response helper
    private static void returnError(RestResponse res, String requestId, String message, Integer statusCode) {
        APIResponse errorResponse = new APIResponse('error', requestId, null, message);
        res.responseBody = Blob.valueOf(JSON.serialize(errorResponse));
        res.addHeader('Content-Type', 'application/json');
        res.statusCode = statusCode;
    }
    
    // API Response Wrapper
    global class APIResponse {
        public String status;
        public String requestId;
        public Object data;
        public String message;
        
        public APIResponse(String status, String requestId, Object data, String message) {
            this.status = status;
            this.requestId = requestId;
            this.data = data;
            this.message = message;
        }
    }
    @HttpPost
    global static void createSupportCase() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response; 
        String requestId = String.valueOf(UUID.randomUUID());       
        try {            
            supportCaseWrapper caseInfo = (supportCaseWrapper) JSON.deserialize(req.requestBody.toString(), supportCaseWrapper.class);
            
            if (caseInfo == null) {
                returnError(res, requestId, 'Invalid request payload.', 200);
                return;
            }
            Boolean isValidtoken = false; // Start 2.0 // 2.0 Token passed in request parameters
            String tokenString = caseInfo.token;
            String isloginString = caseInfo.islogin;
            system.debug('tokenString---'+tokenString);
            system.debug('isloginString---'+isloginString);
            if(tokenString == Null && isloginString == 'Yes'){ //3.0 Return error response if token missed farequest parameters
                returnError(res, requestId, 'Missing Toke parameter', 200);
                return; 
            }else if(tokenString == Null && isloginString == 'No'){ 
                isValidtoken = true; // 2.0 Validate token using centralized validator
            }else if(tokenString != Null && isloginString == 'Yes'){ // 2.0 Validate token using centralized validator
                isValidtoken =TokenValidator.isTokenValid(tokenString,null);
            }else if(tokenString != Null && isloginString == 'No'){ //2.0 Return error response if token missed farequest parameters
                returnError(res, requestId, 'Missing Toke parameter', 200);
                return;
            }
            if(isValidtoken){
                if (String.isBlank(caseInfo.email)) { //2.0 Return error response
                    returnError(res, requestId, 'Missing email parameter', 200);
                    return;
                } // End 2.0
                //3.0 Add email to SOQL
                User user = [SELECT Id, Email, Username, FirstName, EmiratesIDNumber__c, LastName,Street, City, State, Country, PostalCode, Phone, Contact.AccountId FROM User
                             WHERE (Username = :caseInfo.email OR Email =: caseInfo.email) LIMIT 1 ];
                
                
                if (caseInfo.isGeneralCase ) {
                    //  Always create a case
                    String returnMessage = CommunityLoginController.handleCaseCreation(
                        caseInfo.subject,
                        caseInfo.caseComments,
                        user.Email,
                        caseInfo.mobile,
                        true
                    );
                    // If general case, only return success message
                    APIResponse response = new APIResponse('success', requestId, returnMessage, null);
                    res.responseBody = Blob.valueOf(JSON.serialize(response));
                    res.addHeader('Content-Type', 'application/json');
                    res.statusCode = 200;
                    return;
                }
                // If NOT a general case, update user details
                /*if (caseInfo.firstName != null) user.FirstName = caseInfo.firstName;
if (caseInfo.lastName != null) user.LastName = caseInfo.lastName;
if (caseInfo.street != null) user.Street = caseInfo.street;
if (caseInfo.city != null) user.City = caseInfo.city;
if (caseInfo.state != null) user.State = caseInfo.state;
if (caseInfo.postalCode != null) user.PostalCode = caseInfo.postalCode;
if (caseInfo.country != null) user.Country = caseInfo.country;
if (caseInfo.phone != null) user.Phone = caseInfo.phone;

update user;*/
                
                else if (caseInfo.isGeneralCase) { //2.0 add this case create
                    //  Always create a case
                    String returnMessage = CommunityLoginController.handleCaseCreation(
                        caseInfo.subject,
                        caseInfo.caseComments,
                        user.Email,
                        caseInfo.mobile,
                        false
                    );
                    // If general case, only return success message
                    APIResponse response = new APIResponse('success', requestId, returnMessage, null);
                    res.responseBody = Blob.valueOf(JSON.serialize(response));
                    res.addHeader('Content-Type', 'application/json');
                    res.statusCode = 200;
                    return;
                }
                
                // Upload image if requested
                else if (caseInfo.isImageUpload && !String.isBlank(caseInfo.base64Image)) {
                    try {
                        Blob imageBlob = EncodingUtil.base64Decode(caseInfo.base64Image);
                        
                        ContentVersion cv = new ContentVersion(
                            Title = 'UserProfileImage_' + Datetime.now().getTime(),
                            PathOnClient = 'profile.jpg',
                            VersionData = imageBlob
                        );
                        insert cv;
                        
                        cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
                        
                        ContentDocumentLink link = new ContentDocumentLink(
                            ContentDocumentId = cv.ContentDocumentId,
                            LinkedEntityId = user.Id,
                            ShareType = 'V'
                        );
                        insert link;
                    } catch (Exception ex) {
                        LoggerService.save(LoggerService.createApexLog(
                            ex, 'Customer Portal API', 'ImageUpload', 'createSupportCase'
                        ));
                    }
                }
                
                
                // Fetch profile image if any
                String imageUserUrl = getUserImageUrl(user.Id);
                
                UserAccess_DTO userDto = new UserAccess_DTO(
                    user.Id,
                    user.Email,
                    user.Username,
                    user.FirstName,
                    user.LastName,
                    user.Contact.AccountId,
                    user.Street,
                    user.State,
                    user.City,
                    user.Country,
                    user.PostalCode,
                    user.EmiratesIDNumber__c,
                    user.Phone,
                    imageUserUrl
                );
                // Build success response
                APIResponse finalResponse = new APIResponse('success', requestId, userDto, 'User updated and case created successfully');
                res.responseBody = Blob.valueOf(JSON.serialize(finalResponse));
                res.addHeader('Content-Type', 'application/json');
                res.statusCode = 200;
            }
        } catch (Exception ex) { // Return generic server error response
            LoggerService.save(LoggerService.createApexLog(
                ex, 'Customer Portal API', 'CustomerPortalUserAPI', 'createSupportCase'
            ));
            returnError(res, requestId, 'Server Error: ' + ex.getMessage(), 200);
        }
    }
    
    /* global static void createSupportCase(){
RestRequest req = RestContext.request;
RestResponse res = RestContext.response; 
String requestId = String.valueOf(UUID.randomUUID());
try {
supportCaseWrapper caseInfo = (supportCaseWrapper) JSON.deserialize(req.requestBody.toString(), supportCaseWrapper.class);
if (caseInfo == null) {
returnError(res, requestId, 'Invalid request payload.', 400);
return;
}

if (String.isBlank(caseInfo.email)) {
returnError(res, requestId, 'Missing email parameter', 400);
return;
}
system.debug('debug: caseInfo.email' + caseInfo.email);
// Fetch User using email as username
User user = [ SELECT Id, Email, Username, FirstName, EmiratesIDNumber__c,LastName,Street, City, State, Country, PostalCode,Phone,Contact.AccountId FROM User  WHERE Username = :caseInfo.email LIMIT 1 ];

system.debug('debug: user.email' + user.email);
system.debug('debug: user.lastmodifieddate' + user.lastmodifieddate);

// Update user details from input
if (caseInfo.firstName != null) user.FirstName = caseInfo.firstName;
if (caseInfo.lastName != null) user.LastName = caseInfo.lastName;
if (caseInfo.street != null) user.Street = caseInfo.street;
if (caseInfo.city != null) user.City = caseInfo.city;
if (caseInfo.state != null) user.State = caseInfo.state;
if (caseInfo.postalCode != null) user.PostalCode = caseInfo.postalCode;
if (caseInfo.country != null) user.Country = caseInfo.country;
if (caseInfo.phone != null) user.Phone = caseInfo.phone;

update user;

// system.debug('debug: user.lastmodifieddate' + user.lastmodifieddate);
// Get user's profile image URL (from ContentDocumentLink)
String imageUserUrl = getUserImageUrl(user.Id);
// Create response DTO
UserAccess_DTO userDto = new UserAccess_DTO(
user.Id,
user.Email,
user.FirstName,
user.LastName,
user.Contact.AccountId,
user.Street,
user.State,
user.City,
user.Country,
user.PostalCode,
user.EmiratesIDNumber__c, // EIDNumber
user.Phone,
imageUserUrl 
);

// If General Case, create a case
if (caseInfo.isGeneralCase) {
String returnMessage = CommunityLoginController.handleCaseCreation(
caseInfo.subject,
caseInfo.caseComments,
user.Email,
caseInfo.mobile,
true
);

APIResponse response = new APIResponse('success', requestId, returnMessage, null);
res.responseBody = Blob.valueOf(JSON.serialize(response));
res.addHeader('Content-Type', 'application/json');
res.statusCode = 200;

} else {
// Just return updated user data
APIResponse response = new APIResponse('success', requestId, userDto, 'User updated successfully');
res.responseBody = Blob.valueOf(JSON.serialize(response));
res.addHeader('Content-Type', 'application/json');
res.statusCode = 200;
}

} catch (Exception ex) {
LoggerService.save(LoggerService.createApexLog(
ex, 'Customer Portal API', 'CustomerPortalUserAPI', 'createSupportCase'
));
returnError(res, requestId, 'Server Error: ' + ex.getMessage(), 500);
}
}*/
    /**
 * Wrapper class for portal case creation
 * 2.0: No change
 */
    public class supportCaseWrapper{
        public String firstName;
        public String lastName;
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
        public string token; // 2.0 Direct token update
        public string islogin; // 2.0 Direct login update 
        
    }     
    
}