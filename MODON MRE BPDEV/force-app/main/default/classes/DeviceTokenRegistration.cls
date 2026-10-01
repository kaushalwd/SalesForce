/**********************************************************************************************************************
* Name               : DeviceTokenRegistration                                                        
* Description        : This class is used to register the mobile devices.
* Usage              : 
* Created By         : Activemindsit                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh   	                02 02 2026      Initial Draft
* 2.0           Suresh   	                01 06 2026      Added contact id in the request message
***********************************************************************************************************************/
@RestResource(urlMapping='/DeviceTokenRegistrationAPI/*')
global class DeviceTokenRegistration {

    @HttpPost
    global static void tokenRegistration() {
        RestRequest restRequest = RestContext.request;
        RestResponse restResponse = RestContext.response;
        DeviceTokenRegRequest obj_DeviceTokenRequest = new DeviceTokenRegRequest();
        DeviceTokenRegResponse obj_DeviceTokenResponse = new DeviceTokenRegResponse();
        restRequest.addHeader('Content-Type', 'application/json');
        String requestId = String.valueOf(UUID.randomUUID());
        obj_DeviceTokenRequest = (DeviceTokenRegRequest)System.JSON.deserialize(restRequest.requestBody.toString(), DeviceTokenRegRequest.class);
        System.debug('DeviceTokenRegRequest >>>> tokenRegistration >> '+System.JSON.serialize(obj_DeviceTokenRequest));
        //2.0 - updated
        if(obj_DeviceTokenRequest == null || String.isBlank(obj_DeviceTokenRequest.ContactId)
          || String.isBlank(obj_DeviceTokenRequest.DeviceToken)){
            returnError(restResponse, requestId, 'Missing Mandatory Parameters', 200);
            return;  
          } else {
              try{
                    //2.0 - updated
                    Contact obj_Contact = [select Id, SuperAppDeviceToken__c, SuperAppDeviceType__c from Contact
                                           where Id = :obj_DeviceTokenRequest.ContactId limit 1];
                    obj_Contact.SuperAppDeviceToken__c = obj_DeviceTokenRequest.DeviceToken;
                    obj_Contact.SuperAppDeviceType__c = obj_DeviceTokenRequest.DeviceType;
                    update obj_Contact;
                  	obj_DeviceTokenResponse.Status = 'Success';
                    obj_DeviceTokenResponse.ErrorCode = '';
                    obj_DeviceTokenResponse.ErrorMessage = '';
              }catch(Exception exe){
                  	obj_DeviceTokenResponse.Status = 'Failure';
                    obj_DeviceTokenResponse.ErrorCode = '400';
                    obj_DeviceTokenResponse.ErrorMessage = exe.getMessage();
              }  
              
          }
        APIResponse response = new APIResponse('success', requestId, obj_DeviceTokenResponse, null);
        restResponse.responseBody = Blob.valueOf(JSON.serialize(response));
        restResponse.addHeader('Content-Type', 'application/json');
        restResponse.statusCode = 200; 
    }  
    private static void returnError(RestResponse res, String requestId, String msg, Integer status) {
        APIResponse error = new APIResponse('error', requestId, null, msg);
        res.responseBody = Blob.valueOf(JSON.serialize(error));
        res.statusCode = status;
    }
    global class DeviceTokenRegRequest{
        public String AccountId;
        //2.0 - updated
        public String ContactId;
        public String DeviceType;
        public String DeviceToken;	
    } 
    global class DeviceTokenRegResponse {
        public String Status;	
        public String ErrorCode;	
        public String ErrorMessage;	
    }
}