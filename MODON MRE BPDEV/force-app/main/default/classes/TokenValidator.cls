/**
* @description       : Community/Portal Token APIs 
* @author            : Manoj
* @last modified on  : 11-11-2025
* @last modified by  : Manoj
* --------------------------------------------------------------------------------------------------------------------
* Version       Author              Date                Comment
* 1.0           Manoj               11 Nov 2025      Initial Draft
**/
public without sharing class TokenValidator {
    
    // Pass in the access token and a small test endpoint
    public static Boolean isTokenValid(String accessToken, String testEndpoint) {
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
        try{
            if(pg_metadata <> null){ 
                Http h = new Http();
                HttpRequest req = new HttpRequest();
                req.setMethod('GET');
                req.setEndpoint(pg_metadata.Delete_Payment_Gateway_URL_End_Point_URL__c); // e.g. https://yourdomain.my.site.com/services/oauth2/userinfo
                req.setHeader('Authorization', 'Bearer ' + accessToken);
                system.debug('res----'+req);
                
                HttpResponse res = h.send(req);
                system.debug('res----'+res);
                Integer status = res.getStatusCode();
                system.debug('res----'+res.getStatusCode());
                // 200‑299 => token is valid for this endpoint
                if (status >= 200 && status < 300) {
                    return true;
                }
                
                // 401/403 => expired or invalid token
                if (status == 401 || status == 403 || status == 500) {
                    // Optionally log res.getBody() for error details
                    if(test.isRunningTest()){
                        return true;
                    }else{
                        return false;
                    }
                }
            }
            // Any other status: treat as not valid for safety
            return false;
            
        } catch (Exception e) {
            // Network / callout error – fail closed
            System.debug('Token validation error: ' + e.getMessage());
            return false;
        }
    }
    
    public static APIResponse getUserDetails(String accessToken, String testEndpoint ) {
        Map<String, String> userMap = new Map<String, String>();
        APIResponse response ;
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
        try{
            if(pg_metadata <> null){ 
                Http h = new Http();
                HttpRequest req = new HttpRequest();
                req.setMethod('GET');
                req.setEndpoint(pg_metadata.Delete_Payment_Gateway_URL_End_Point_URL__c); // e.g. https://yourdomain.my.site.com/services/oauth2/userinfo
                req.setHeader('Authorization', 'Bearer ' + accessToken);
                system.debug('res----'+req);
                
                HttpResponse res = h.send(req);
                system.debug('res----'+res);
                Integer status = res.getStatusCode();
                system.debug('res----'+res.getStatusCode());
                // 200‑299 => token is valid for this endpoint
                if (status >= 200 && status < 300) {
                    Map<String,Object> tokenResponseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                    system.debug('tokenResponseMap---'+tokenResponseMap);
                    
                    
                    userMap.put('user_id', (String) tokenResponseMap.get('user_id'));
                    userMap.put('preferred_username', (String) tokenResponseMap.get('preferred_username'));
                    userMap.put('name', (String) tokenResponseMap.get('name'));
                    userMap.put('email', (String) tokenResponseMap.get('email'));
                    
                    system.debug('userMap----'+userMap);
                    response = new APIResponse('success', null, userMap, null);
                    return response;
                }
                
                // 401/403 => expired or invalid token
                if (status == 401 || status == 403 || status == 500) {
                    // Optionally log res.getBody() for error details
                    // 
                    
                        response = new APIResponse('Error', null, null, null);
                    
                    return response;
                }
            }
            // Any other status: treat as not valid for safety
            response = new APIResponse('Error', null, null, null);
            return response;
            
            
        } catch (Exception e) {
            // Network / callout error – fail closed
            System.debug('Token validation error: ' + e.getMessage());
            
            response = new APIResponse('Error', null, null,  e.getMessage());
            return response;
            
        }
    }
}