/**********************************************************************************************************************
* Name               : AuthTokenService                                                        
* Description        : This class contains main integration methods for UAEPass.
* Usage              : Used to integrate with UAEPass.
* Created By         : Activemindsit                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh   	                17 02 2026      Initial Draft       

***********************************************************************************************************************/
public with sharing class AuthTokenService {
    private static final String TOKEN_ENDPOINT = System.Label.UAE_PASS_TOKEN;
    private static final String TOKENIDENTIFIER = System.Label.UAE_PASS_TOKENIDENTIFIER;
    private static final String TOKENIDENTIFIERVALUE = System.Label.UAE_PASS_TOKENIDENTIFIERVALUE;
 
    public class TokenResponse {
        public Boolean success;
        public String accessToken;
        public String tokenType;
        public Integer expiresIn;
        public String rawResponse;
        public String error;
    }
 
    public static String generateToken(String clientId, String clientSecret) {
        String tokenSF = '';
        HttpRequest req = new HttpRequest();
        req.setEndpoint(TOKEN_ENDPOINT);
        req.setMethod('POST');
        req.setTimeout(120000);
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
 
        String body =
            'grant_type=password' +
            '&client_id=' + EncodingUtil.urlEncode(clientId, 'UTF-8') +
            '&client_secret=' + EncodingUtil.urlEncode(clientSecret, 'UTF-8') +
            '&username=' + EncodingUtil.urlEncode(TOKENIDENTIFIER, 'UTF-8') +
            '&password=' + EncodingUtil.urlEncode(TOKENIDENTIFIERVALUE, 'UTF-8');
 
        req.setBody(body);
 
        try {
            Http http = new Http();
            HttpResponse res = http.send(req);
            if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
				System.debug('>>>>>>>>>>>  ' + res.getBody());
                Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(res.getBody()); 
                System.debug('>>>>>>>>>>>>>>>>>>>>accessToken >>>> '+(String) parsed.get('access_token'));
                tokenSF = (String) parsed.get('access_token');
                }  else {
                    System.debug('Token call failed: ' + res.getStatusCode() + ' ' + res.getStatus());
                    System.debug('Body: ' + res.getBody());
                }
                } catch (Exception e) {
                    System.debug('Token call exception: ' + e.getMessage());
                    throw e; // optional but recommended
                }
        return tokenSF;
    }
}