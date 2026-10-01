/**
* @description       : Community/Portal user Reset 
* @author            : Krishna Chaitanya
* @last modified on  : 09-Nov-2025
* @last modified by  : Krishna Chaitanya
* --------------------------------------------------------------------------------------------------------------------
* Version       Author              Date                Comment
* 1.0           Krishna Chaitanya   13 May 2025   		Initial Draft 
* 2.0           Manoj   	        09 Dec 2025   		Supports password reset email and direct password update without requiring user login and error code
**/
@RestResource(urlMapping='/CustomerPortalResetAPI/*')
global class CustomerPortalResetAPI {
    
    /**
     * HTTP POST API
     * Handles:
     * 1. Sending password reset email
     * 2. Updating password directly without login (v2.0)
     *      *
     *
     */
    @httpPost
    global static void createresetPassword(){
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response; 
        String requestId = String.valueOf(UUID.randomUUID());
        try{
            PasswordReset userInfo = (PasswordReset) JSON.deserialize(req.requestBody.toString(), PasswordReset.class);
            boolean isResetValue = userInfo.isResetEmail;  // 2.0 Flag to identify reset email flow 
             // Validate mandatory userinfo parameter
            if(userInfo == null){
                returnError(res, requestId, 'Error! occured.', 200);
                return;
            } // Validate mandatory email parameter
            if (String.isBlank(userInfo.email)) {
                returnError(res, requestId, 'Missing email parameter', 200);
                return;
            } // 2.0 Validate password when not triggering reset email           
            if(isResetValue == false && String.isBlank(userInfo.Password)){          
                returnError(res, requestId, 'Missing Password parameter', 200);
                return;
                
            }/**
             * 2.0 Password reset without login
             * Case 1: resetPassword = true
             * - Directly updates password using email + password
             */
            if(userInfo.resetPassword == true){ 
                UserDTO userDto = CustomerPortalUserService.getUserAccessResetNew(userInfo.email,userInfo.Password);
                if (userDto == null) {
                    returnError(res, requestId, 'We couldn’t find an active account linked to this email address.', 200);
                    return;
                }
                
            }else if(isResetValue == true){ 
                /**
             * 2.0 Reset Email Flow
             * Case 2: isResetEmail = true
             * - Generates reset email with encoded username
             */
                UserDTO useaValues = CustomerPortalUserService.getUserByEmail(userInfo.email);
                if(useaValues.id != null){
                    system.debug('useaValues.id ---'+useaValues.id );
                    system.debug('useaValues.id ---'+useaValues);
                    user userRec = new user();
                    userRec.id =useaValues.id;
                    system.debug(' userRec.id---'+ userRec);
                    System.debug('Username: ' + useaValues.Username);
                    Blob stringBlob = Blob.valueOf(useaValues.Username);			
                    String base64Encoded = EncodingUtil.base64Encode(stringBlob);
                    
                    userRec.EmailBase64String__c = base64Encoded;
                    try{
                        update userRec;
                        if(!test.isRunningTest()){
                            SendGridEmailServiceUserAccessAPI.sendEmailUsingSendGrid(userRec.id,System.Label.Email_CustomerPortalEmail);
                        }
                    }catch(Exception ex){
                        LoggerService.save(LoggerService.createApexLog(
                            ex, 'CustomerPortalResetAPI', 'CustomerPortalResetAPI', 'reset'
                        ));
                        returnError(res, requestId, 'Server Error: ' + ex.getMessage(), 200);
                    }      
                }else {
                    returnError(res, requestId, 'We couldn’t find an active account linked to this email address.', 200);
                }
            }
        } catch (Exception ex) {
            LoggerService.save(LoggerService.createApexLog(
                ex, 'CustomerPortalResetAPI', 'CustomerPortalResetAPI', 'reset' ));
            returnError(res, requestId, 'Server Error: ' + ex.getMessage(), 200);
        }  
        
    }
     /**
     * Utility method to build standardized error response
     */
    private static void returnError(RestResponse res, String requestId, String msg, Integer status) {
        APIResponse error = new APIResponse('error', requestId, null, msg);
        res.responseBody = Blob.valueOf(JSON.serialize(error));
        res.statusCode = status;
    }    
   /**
     * Wrapper class for password reset request payload
     * 2.0 Supports reset email and password update without login
     */
    public class PasswordReset{
        public String email;
        public String password;
        public Boolean resetPassword;  // v2.0 Direct password update
        public Boolean isResetEmail;   // v2.0 Trigger reset email    
    }
    
}