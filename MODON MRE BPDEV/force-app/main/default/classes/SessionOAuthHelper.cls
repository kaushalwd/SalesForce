/**********************************************************************************************************************
* Name               :                                                         
* Description        : Document Generation Session ID
* Usage              : BP Framework                                                        
* Created By         : Sivannarayana Peddireddi                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                          Date            Comment                                                                       
* 1.0           sivannaryana.p@modon.com     24-07-2026      Initial Draft 
**********************************************************************************************************************/
public class SessionOAuthHelper {
    
    private static final String CLIENT_ID =System.Label.NocDocClientId;
    private static final String CLIENT_SECRET =System.Label.NocDocClientSecret;
    private static final String USERNAME =System.Label.NocDocUserName;
    private static final String PASSWORD =System.Label.NocDocPassword;
    private static final String TOKEN_ENDPOINT =System.Label.NocDocTokenEndPoint;
    private static String cachedAccessToken;
    private static DateTime tokenExpiryTime;
    
    public static String getOAuthAccessToken() {
        if (String.isNotBlank(cachedAccessToken) &&  tokenExpiryTime != null && System.now() < tokenExpiryTime) { 
            return cachedAccessToken;
        }   
        System.debug('Requesting new OAuth token');
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(TOKEN_ENDPOINT);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            req.setTimeout(120000);
            String body = 'grant_type=client_credentials' +'&client_id=' + CLIENT_ID +'&client_secret=' + CLIENT_SECRET +'&username=' + USERNAME +'&password=' + PASSWORD;
            req.setBody(body);
            Http http = new Http();
            HttpResponse res = http.send(req);
            System.debug('OAuth Response Status: ' + res.getStatusCode());
            System.debug('OAuth Response Body: ' + res.getBody());
            if (res.getStatusCode() == 200) {
                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());  
                if (responseMap != null && responseMap.containsKey('access_token')) {
                    cachedAccessToken = (String) responseMap.get('access_token');
                    // Set expiry time - default to 2 hours if not specified
                    Integer expiresIn = 7200;
                    if (responseMap.containsKey('expires_in')) {
                        Object expiresObj = responseMap.get('expires_in');
                        if (expiresObj instanceof Integer) {
                            expiresIn = (Integer) expiresObj;
                        }
                    }
                    tokenExpiryTime = System.now().addSeconds(expiresIn - 300); // 5 min buffer
                    return cachedAccessToken;
                } else {throw new CalloutException('No access_token in response: ' + res.getBody());
                }
            } else {throw new CalloutException('OAuth failed: ' + res.getStatusCode() + ' - ' + res.getBody());}
            } catch (Exception e) {System.debug('❌ OAuth Exception: ' + e.getMessage());throw new CalloutException('OAuth error: ' + e.getMessage());
        }
    }
    
  
}