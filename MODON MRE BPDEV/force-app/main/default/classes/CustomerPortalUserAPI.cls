@RestResource(urlMapping='/CustomerPortalUserAPI/*')
global class CustomerPortalUserAPI {
    
    @HttpGet
    global static void findUser() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        String requestId = String.valueOf(UUID.randomUUID());
        
        try {
            UserAccessDTO userDto;
            String userName = req.params.get('userName');
            String Password = req.params.get('Password');
            if (String.isBlank(userName) || String.isBlank(Password)) {
                returnError(res, requestId, 'Missing login creds parameter', 200);
                return;
            }else{          
            // Decode it back
          
               Blob decodedBlob = EncodingUtil.base64Decode(Password);
                String decodedPassword = decodedBlob.toString();
                System.debug('Decoded: ' + decodedPassword); 
                userDto= CustomerPortalUserService.getUserAccess(userName,decodedPassword);
            
                if (userDto == null) {
                    returnError(res, requestId, 'Invalid Credentials', 200);
                    return;
                }
            }             
            
            APIResponse response = new APIResponse('success', requestId, userDto, null);
            res.responseBody = Blob.valueOf(JSON.serialize(response));
            res.addHeader('Content-Type', 'application/json');
            res.statusCode = 200;
            
            
        } catch (Exception ex) {
            LoggerService.save(LoggerService.createApexLog(
                ex, 'Customer Portal API', 'CustomerPortalUserAPI', 'findUser'
            ));
            returnError(res, requestId, 'Server Error: ' + ex.getMessage(), 200);
        }
    }
   /* @httpPost
    global static void loginAuthHelper(){
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        String requestId = String.valueOf(UUID.randomUUID());

        loginCredsWrapper loginWrap = (loginCredsWrapper) JSON.deserialize(req.requestBody.toString(), loginCredsWrapper.class);

        if (String.isBlank(loginWrap.userName) || loginWrap == null) {
            returnError(res, requestId, 'Missing email parameter', 400);
            return;
        }
        UserDTO userDto = CustomerPortalUserService.getUserByEmail(loginWrap.userName);
        
        if (userDto == null) {
            returnError(res, requestId, 'User not found', 404);
            return;
        }
        
        CommunityLoginController.login(loginWrap.userName,loginWrap.password);
    }*/
    private static void returnError(RestResponse res, String requestId, String msg, Integer status) {
        APIResponse error = new APIResponse('error', requestId, null, msg);
        res.responseBody = Blob.valueOf(JSON.serialize(error));
        res.addHeader('Content-Type', 'application/json');
        res.statusCode = status;
    }
    public class loginCredsWrapper{
        public String userName;
        public String password;
    }
}