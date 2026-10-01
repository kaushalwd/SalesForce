/**
 *Name               : LoqateService                                                        
* Description        : This class is used as controller for LWC (unitSearchLwc)
* Usage              : Loqate API Service                                                   
* Created By         :Arvind Kesharwani
 *Version       Author                          Date            Comment   
 1.0            Arvind Kesharwani             04/20/2026       Intial Dreaft



 * Reusable service class — call from LWC controller, Batch, Flow, Trigger, etc.
 *
 * Kill switch: Custom Label  Loqate_API_Enabled
 *   value = true  → API runs normally
 *   value = false → API is skipped, isValid = true so nothing is blocked
 *
 * If the API fails for any reason (expired key, timeout, network error)
 * the result always returns apiSkipped = true and isValid = true.
 * Nothing is ever blocked by an API failure.
 */
public with sharing class LoqateService {
    
 
  private static final String NAMED_CRED = 'callout:Loqate_Integration';
  private static final String PHONE_ENDPOINT = '/XXMODODN_LOQATE_PHONENUMBERV2/1.0/loqate/phonenumbervalidation';
   private static final String EMAIL_ENDPOINT = '/XXMODON_LOQATE_EMAIL/1.0/loqate/emailvalidation';
private static String API_KEY;
    static {
        List<OIC_Credential__mdt> creds = [
            SELECT DeveloperName, Endpoint__c, Password__c 
            FROM OIC_Credential__mdt 
            WHERE DeveloperName IN ('Loqate_EMAIL_ENDPOINT', 'Loqate_PHONE_ENDPOINT')
        ];
for (OIC_Credential__mdt mdt : creds) {
            if (mdt.DeveloperName == 'Loqate_PHONE_ENDPOINT') {
               // PHONE_ENDPOINT = mdt.Endpoint__c;
                API_KEY = mdt.Password__c; // Assigning the key
            } else if (mdt.DeveloperName == 'Loqate_EMAIL_ENDPOINT') {
              //  EMAIL_ENDPOINT = mdt.Endpoint__c;
              API_KEY = mdt.Password__c;
            }
        }
    }
    // ── Result wrappers ──────────────────────────────────────────────────────

    public class EmailResult {
        @AuraEnabled public Boolean isValid      = false;
        @AuraEnabled public Boolean apiSkipped   = false;
        @AuraEnabled public String  responseCode;
        @AuraEnabled public String  message;
        @AuraEnabled public Boolean isDisposable = false;
        @AuraEnabled public Boolean isFraudRisk  = false;
        @AuraEnabled public String  domain;
    }

    public class PhoneResult {
        @AuraEnabled public Boolean isValid      = false;
        @AuraEnabled public Boolean apiSkipped   = false;
        @AuraEnabled public String  message;
        @AuraEnabled public String  nationalFormat;
        @AuraEnabled public String  networkName;
        @AuraEnabled public String  networkCountry;
    }

    // ── Kill switch ──────────────────────────────────────────────────────────

    public static Boolean isApiEnabled() {
        try {
            String val = System.Label.Loqate_API_Enabled;
            return !'false'.equalsIgnoreCase(val);
        } catch (Exception e) {
            return true; // Label missing → default ON
        }
    }

    // ── Email Validation ─────────────────────────────────────────────────────

    public static EmailResult validateEmail(String email) {
        EmailResult result = new EmailResult();

        if (!isApiEnabled()) {
            result.isValid    = true;
            result.apiSkipped = true;
            result.message    = 'API disabled via Custom Label. Validation skipped.';
            return result;
        }

        try {
            HttpRequest req = new HttpRequest();
            req.setMethod('POST');
            req.setEndpoint(NAMED_CRED + EMAIL_ENDPOINT);
            req.setHeader('Content-Type', 'application/json');

           Map<String, String> payload = new Map<String, String>{
                'Key' => API_KEY,
                'Email' => email
            };
            req.setBody(JSON.serialize(payload));
            req.setTimeout(10000);
            HttpResponse res = new Http().send(req);
          System.debug('logLevel'+ res.getbody());
            if (res.getStatusCode() == 200) {
                Map<String,Object> body  = (Map<String,Object>) JSON.deserializeUntyped(res.getBody());
                List<Object>       items = (List<Object>) body.get('Items');
                if (items != null && !items.isEmpty()) {
                    Map<String,Object> item = (Map<String,Object>) items[0];
                    result.responseCode  = (String)  item.get('ResponseCode');
                    result.isValid       = 'Valid'.equalsIgnoreCase(result.responseCode);
                    result.message       = (String)  item.get('ResponseMessage');
                    result.domain        = (String)  item.get('Domain');
                    result.isDisposable  = item.get('IsDisposableOrTemporary') == true;
                    result.isFraudRisk   = item.get('IsComplainerOrFraudRisk')  == true;
                    result.apiSkipped    = false;
                }
            } else {
                result.isValid    = true;
                result.apiSkipped = true;
                result.message    = 'API error ' + res.getStatusCode() + ' — skipped, you can still proceed.';
            }
        } catch (Exception e) {
            result.isValid    = true;
            result.apiSkipped = true;
            result.message    = 'API unreachable — skipped, you can still proceed.';
        }
        return result;
    }
    // ── Phone Validation ─────────────────────────────────────────────────────

    public static PhoneResult validatePhone(String phone) {
        PhoneResult result = new PhoneResult();

        if (!isApiEnabled()) {
            result.isValid    = true;
            result.apiSkipped = true;
            result.message    = 'API disabled via Custom Label. Validation skipped.';
            return result;
        }
        try {
            HttpRequest req = new HttpRequest();
            req.setMethod('POST');
               req.setEndpoint(NAMED_CRED + PHONE_ENDPOINT);
            req.setHeader('Content-Type', 'application/json');
           Map<String, String> payload = new Map<String, String>{
                'Key' => API_KEY,
                'Phone' => phone
            };
            req.setBody(JSON.serialize(payload));
            req.setTimeout(10000);

            HttpResponse res = new Http().send(req);
  System.debug('logLevel'+ res.getbody());
            if (res.getStatusCode() == 200) {
                Map<String,Object> body  = (Map<String,Object>) JSON.deserializeUntyped(res.getBody());
                List<Object>       items = (List<Object>) body.get('Items');
                if (items != null && !items.isEmpty()) {
                Map<String,Object> item = (Map<String,Object>) items[0];
                    result.isValid        = 'Yes'.equalsIgnoreCase((String) item.get('IsValid'));
                    result.nationalFormat = (String) item.get('NationalFormat');
                    result.networkName    = (String) item.get('NetworkName');
                    result.networkCountry = (String) item.get('NetworkCountry');
                    result.message        = result.isValid ? 'Valid mobile number' : 'Invalid phone number';
                    result.apiSkipped     = false;
                }
            } else {
                result.isValid    = true;
                result.apiSkipped = true;
                result.message    = 'API error ' + res.getStatusCode() + ' — skipped, you can still proceed.';
            }
        } catch (Exception e) {
            result.isValid    = true;
            result.apiSkipped = true;
            result.message    = 'API unreachable — skipped, you can still proceed.';
        }
        return result;
    }
}