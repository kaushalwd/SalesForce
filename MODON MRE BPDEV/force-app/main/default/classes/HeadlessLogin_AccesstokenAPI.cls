/**
* @description       : Community/Portal Profile
* @author            : Manoj
* @last modified on  : 11-Nov-2025
* @last modified by  : Manoj
* --------------------------------------------------------------------------------------------------------------------
* Version       Author              Date                Comment
* 1.0           Manoj   	       11 Nov 2025   		Initial Draft 
* 2.0 			Manoj			   10 Mar 2026			Update logic to check eamil
**/
@RestResource(urlMapping='/code/accessexchange')
global class HeadlessLogin_AccesstokenAPI {
     /**
     * HTTP GET API to exchange auth code for access token and fetch user profile.
     * Request Parameters:
     *  - code: Authorization code from OAuth redirect
     *  - sfdc_community_url: Community URL for token exchange
     *
     * Response:
     *  - Success: Returns access token and UserDTO
     *  - Error: Returns error message if token cannot be retrieved or user not found
     */
    @HttpGet
    global static void accessTokenGet() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        try {
            UserDTO userDto;
            res.statusCode = 200; 
            // Fetch user details using access token
            String accessToken = doCodeExchange(req.params.get('code'), req.params.get('sfdc_community_url'));
            if (accessToken != null) {
                
                APIResponse userResDetails = TokenValidator.getUserDetails(accessToken,null);
                
                System.debug('Decoded: ' + userResDetails);
                String preferredUsername ;
                if (userResDetails != null && userResDetails.status == 'success') {
                    Map<String, Object> dataMap =  (userResDetails.data != null) ? (Map<String, Object>) userResDetails.data : null;
                    
                    if (dataMap != null) {
                        preferredUsername = (String) dataMap.get('preferred_username');
                        System.debug('Preferred Username: ' + preferredUsername);
                    }
                    
                    System.debug('Preferred Username: ' + preferredUsername);
                    //2.0 email
                    List<User> resetusers = [ SELECT Id, Email, Phone, Username, FirstName, LastName,UUID__c, Contact.AccountId FROM User WHERE IsActive = true and (Username = :preferredUsername OR Email = :preferredUsername ) LIMIT 1 ];
                    // Step 2 — Check Accounts with SAME email
                    
                    // If more than one account → flag and stop
                    if(resetusers.size() > 0){ //2.0 email 
                        List<Contact> contacts = [ SELECT Id, Email, Phone, EIDNumber__c, PassportNumber__c, 
                                                  AccountId, Account.RecordType.Name FROM Contact WHERE Email = :resetUsers[0].Email 
                                                  AND Email != null AND Account.RecordType.Name != 'Broker Agency' 
                                                  AND Source_Entity__c != 'Modon - Egypt'];
                        
                        if (contacts.size() > 1) {
                            
                            Contact conRec = contacts[0];
                            
                            Boolean hasEID = conRec.EIDNumber__c != null;
                            Boolean hasPassport = conRec.PassportNumber__c != null;
                            
                            if (conRec.Account.RecordType.Name == 'Organization Account' ||
                                conRec.Account.RecordType.Name == 'Person Account') {
                                    
                                    userDto = new UserDTO(resetUsers[0], hasEID, hasPassport);
                                }
                        }else {
                            userDto = new UserDTO(resetUsers[0], false, false);
                        }
                        
                    }
                    
                    
                }
                ExchangeResponse response = new ExchangeResponse('success', accessToken, userDto, null);
                res.responseBody = Blob.valueOf(JSON.serialize(response));
                res.addHeader('Content-Type', 'application/json');
                res.statusCode = 200;
                return;
                
            } else {
                ExchangeResponse response = new ExchangeResponse('success', null, null, 'Could not parse auth code redirect URI');
                res.responseBody = Blob.valueOf(JSON.serialize(response));
                res.addHeader('Content-Type', 'application/json');
                res.statusCode = 200;
                return;
            }
        } catch (Exception e) {
            ExchangeResponse response = new ExchangeResponse('success', null, null, 'Could not parse auth code redirect URI');
            res.responseBody = Blob.valueOf(JSON.serialize(response));
            res.addHeader('Content-Type', 'application/json');
            res.statusCode = 200;
            return;           
        }
    }
       /**
     * Exchange OAuth authorization code for access token.
     * @param code Authorization code from OAuth redirect
     * @param communityURL Community URL for token endpoint
     * @return access token string if successful, null otherwise
     */
    global static String doCodeExchange(String code, String communityURL) {
        Organization this_org = [Select Id, Name, IsSandbox from Organization];        
        Payment_Gateway__mdt pg_metadata = new Payment_Gateway__mdt();        
        if(this_org.IsSandbox){
            system.debug('debug: in this_org.IsSandbox');
            pg_metadata = Payment_Gateway__mdt.getInstance('Customer_Portal_Sandbox');
        }
        else{
            system.debug('debug: in else part');
            pg_metadata = Payment_Gateway__mdt.getInstance('Customer_Portal_Prod');
        }
        System.debug('debug: pg_metadata ' + pg_metadata);
        if(pg_metadata <> null){ 
            System.debug('pg_metadata--'+pg_metadata);
            string redirectURL=pg_metadata.End_Point_URL__c;
            String clientId = pg_metadata.API_Key__c;
            String clientSecret =pg_metadata.Secret_Key__c;
            
            Http h = new Http();
            HttpRequest req = new HttpRequest();
            req.setMethod('POST');              
            //Create Code Exchange URL
            String url = communityURL + '/services/oauth2/token';
            req.setEndpoint(url);
            
            //Post Body
            String body = 'grant_type=authorization_code';
            body = body + '&client_id=' + clientId;
            body = body + '&code=' + code;
            if (clientSecret != null) {
                body = body + '&client_secret=' + clientSecret;
            }
            body = body + '&redirect_uri=' + redirectURL;              
            //URL encode Post Body
            String encodedBody = EncodingUtil.urlEncode(body, 'UTF-8');
            
            // Set request body
            req.setBody(body);
            
            //Add Headers
            req.setHeader('Content-Type','application/x-www-form-urlencoded');
            
            //Send Token Request
            HttpResponse res = h.send(req);
            
            if (res.getStatusCode() == 200 ) {
                //Extract Token from Response
                Map<String,Object> tokenResponseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                return (String)tokenResponseMap.get('access_token');
            } else {
                System.debug('Response Code '+res.getStatusCode());
                System.debug('Response Code '+res.getBody());
                
                return null;
                
                
            }
        }else {
            LoggerService.save(LoggerService.createAPILog('access_token','HeadlessLogin_AccesstokenAPI','accessTokenGet', 'There is no service API found', '',  'There is no service API found', 'Update Log'));            
            return null;
        }
    }
    
    // Response Wrapper
    global class ExchangeResponse {
        String access_token;
        String state;
        String errMsg;
        Boolean success;
        Object data;
        
        public ExchangeResponse(String state, String access_token,Object data,string errMsg) {
            this.access_token = access_token;
            this.state = state;
            this.success = true;
            this.data = data;
            this.errMsg =errMsg;
        }      
    }
}