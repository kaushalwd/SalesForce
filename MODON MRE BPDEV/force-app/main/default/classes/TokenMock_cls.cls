/**
* @description       : Community/Portal Profile
* @author            : Manoj
* @last modified on  : 12-16-2025
* @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
* --------------------------------------------------------------------------------------------------------------------
* Version       Author              Date                Comment
* 1.0           Manoj   	       11 Nov 2025   		Initial Draft 
**/
public class TokenMock_cls {
    
    // -------------------------------------------------------
    // HTTP Mock for BOTH token exchange + userDetails API
    // -------------------------------------------------------
    public class FullMock implements HttpCalloutMock {
        
        public HttpResponse respond(HttpRequest req) {
            
            HttpResponse res = new HttpResponse();
            
            // Mock TOKEN EXCHANGE call -----------------------------------
            if (req.getMethod() == 'POST' && req.getEndpoint().contains('/services/oauth2/token')) {
                res.setStatusCode(200);
                res.setBody('{"access_token":"TEST_ACCESS_TOKEN"}');
                return res;
            }
            
            // Mock USER DETAILS call ------------------------------------
            if (req.getMethod() == 'GET') {
                res.setStatusCode(200);
                res.setBody('{"user_id":"111","preferred_username":"testuser@modonexample.com","name":"Test Portal","email":"testuser@modonexample.com"}');
                return res;
            }
            
            // Default
            res.setStatusCode(200);
            return res;
        }
    }
    // -------------------------------------------------------
    // HTTP Mock for BOTH token Error exchange + userDetails API
    // -------------------------------------------------------
    public class TokenFailureMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse r = new HttpResponse();
            r.setStatusCode(200);
            r.setBody('{"error":"server_error"}');
            return r;
        }
    }
    // -------------------------------------------------------
    // HTTP Mock for BOTH token Error exchange + userDetails API
    // -------------------------------------------------------
    public class UserDetailsErrorMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(401);
            res.setBody('Unauthorized');
            return res;
        }        
    }
    
}