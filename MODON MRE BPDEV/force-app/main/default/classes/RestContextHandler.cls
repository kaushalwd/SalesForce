global with sharing virtual class RestContextHandler {
    
    public class RestException extends Exception {}

    public WebServiceResponse response {get;set;}
    private RestRequest restRequest {get;set;}
    private RestResponse restResponse {get;set;}
    private Boolean shouldLogRequest {get;set;}
    private Logger__c log {get;set;}
    public RestRequestHeaders requestHeaders {get; private set;}
    public Boolean notMobileRequest {get;set;}

    public RestContextHandler(Boolean shouldLogRequest) {

            if (RestContext.request == null || RestContext.response == null) {
                
                throw new RestException('RestContext request and RestContext response should not be null');
            }

            this.shouldLogRequest = shouldLogRequest;
            this.response = new WebServiceResponse();

            this.restRequest = RestContext.request;
            this.restResponse = RestContext.response;
            this.setResponseHeaders();
            this.populateRequestHeaders();
    }
    
    public void finalize() {
       this.finalize(null);
    }
    
    public void finalize(Exception exc) {
        
        if (this.shouldLogRequest) {
            this.updateLog(exc, response.statusCode, response.message);
            response.requestId = log.Id;
        }

        this.setResponseBody(Blob.valueOf(response.serialize()));
    }
    
    
    public string getRequestBody(){
        return this.restRequest.requestbody.toString();
    }
        
    public Map<String, String> getRequestBodyMap() {
        
        try {
            if (String.IsBlank(this.restRequest.requestbody.toString()))
                return null;

            Map<String,String> mapFieldApiFieldValues = new Map<String, String>();
            Map<String,object> mpUntypedObject = (Map<String,Object>)JSON.deserializeUntyped(this.restRequest.requestbody.tostring());
            System.debug('body >>> '+mpUntypedObject); 
            
            for( String key : mpUntypedObject.keyset()) {
                system.debug(key+'key >>> '+mpUntypedObject.get(key).tostring()); 
                mapFieldApiFieldValues.put(key,mpUntypedObject.get(key).tostring());
            }
            
            return mapFieldApiFieldValues;
        }
        catch(exception ex) {
            
            system.debug('Request Body Format not supported '+ex.getMessage());
            throw ex;
        }
    }
    
    public Map<String,object> getRequestBodyMapObject() {
        
        try {

            if (String.IsBlank(this.restRequest.requestbody.toString()))
                return null;

            Map<String,object> mpUntypedObject = (Map<String,Object>)JSON.deserializeUntyped(this.restRequest.requestbody.tostring());
            return mpUntypedObject;
        }
        catch(exception ex) {
            system.debug('Request Body Format not supported '+ex.getMessage());
            throw ex;
        }
    }
    
    public void setResponseBody(Blob body) {
        
        this.restResponse.responseBody = body;
    }
    
    public void addResponseHeader(String key, String value) {
        
        this.restResponse.addHeader(key, value);
    }
    
    public void setResponseStatusCode(Integer statusCode) {
    
        this.restResponse.statusCode = statusCode;
    }
    
    private void updateLog(Exception exc, Integer statusCode, String message) {
        
       if (this.log == null) {
        
          this.log = LoggerService.addMobileLog(this.restRequest, exc, message, statusCode);
       }
        else {
        this.log = LoggerService.updateMobileLog(this.log, this.restRequest, exc, message, statusCode);
        }
       LoggerService.save(this.log);
    }
    
    private void setResponseHeaders() {
        
        this.addResponseHeader('Content-Type', 'application/json;charset=UTF-8');
    }

    public void populateRequestHeaders() {

        this.requestHeaders = new RestRequestHeaders(this.restRequest);
        System.debug('--Request Headers--'+this.requestHeaders);
    }

   
}