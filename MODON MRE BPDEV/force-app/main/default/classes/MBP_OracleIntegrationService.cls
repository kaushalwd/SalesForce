/**********************************************************************************************************************
* Name               : MBP_OracleIntegrationService
* Description        : Core integration utility class responsible for handling
*                      HTTP callouts to Oracle via OIC.
*                      Manages request construction, authentication (Basic Auth),
*                      response handling, and standardized wrapper return object.
* Usage              : Invoked by Queueable integration classes such as
*                      MBP_OracleSupplierSyncQueueable and
*                      MBP_OracleBankSyncQueueable to perform outbound callouts.
* Created By         : Upendra Reddy
* --------------------------------------------------------------------------------------------------------------------
* Version     Author                          Date             Comment
* 1.0         upendra.asam@activemindsit.com   11 Feb 2026      Initial Draft – Implemented generic HTTP POST method
*                                                              with Basic Authentication and JSON payload support.
*                                                              Added OracleResponseWrapper for standardized
*                                                              response handling across integration flows.

**********************************************************************************************************************/


public with sharing  class MBP_OracleIntegrationService {


    public static OracleResponseWrapper sendRequest(String endpointUrl, String jsonBody, 
                                                    String username, String password) {

        OracleResponseWrapper wrapper = new OracleResponseWrapper();

        Http http = new Http();
        HttpRequest req = new HttpRequest();

        req.setEndpoint(endpointUrl);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(120000); 
        Blob headerValue = Blob.valueOf(username + ':' + password);
        String auth = 'Basic ' + EncodingUtil.base64Encode(headerValue);
        req.setHeader('Authorization', auth);

        req.setBody(jsonBody);

        try {
            HttpResponse res = http.send(req);
            wrapper.statusCode = res.getStatusCode();
            wrapper.status = res.getStatus();
            wrapper.body = res.getBody();
            wrapper.isSuccess = (res.getStatusCode() == 200 || res.getStatusCode() == 201);
        } catch (Exception e) {
            wrapper.isSuccess = false;
            wrapper.errorMessage = e.getMessage();
        }

        return wrapper;
    }

    public class OracleResponseWrapper {
        public Boolean isSuccess;
        public Integer statusCode;
        public String status;
        public String body;
        public String errorMessage;
    }


}