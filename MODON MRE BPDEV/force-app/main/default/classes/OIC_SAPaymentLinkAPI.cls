/**********************************************************************************************************************
* Name               : OIC_SAPaymentLinkAPI                                                        
* Description        : This class is used to create/update a payment link.
* Usage              : 
* Created By         : Suresh                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh   	                26 07 2026      Initial Draft
* 1.1           Jay Patel                   21 Sep 2026     MCR-73 — USER_MODE DML, createApexLog
***********************************************************************************************************************/
@RestResource(urlMapping='/superapp/paymentlink/*')
global with sharing class OIC_SAPaymentLinkAPI {
    
    private class PaymentLinkException extends Exception {}

    @HttpPost
    global static void upsertPaymentLink() {
        RestRequest restRequest = RestContext.request;
        RestResponse restResponse = RestContext.response;
        
        restResponse.addHeader('Content-Type', 'application/json');
        String requestId = String.valueOf(UUID.randomUUID());
        PaymentLinkResponse obj_PaymentLinkResponse = new PaymentLinkResponse();
        
        Savepoint sp = Database.setSavepoint();
        
        try {
            if (restRequest.requestBody == null || String.isBlank(restRequest.requestBody.toString())) {
                returnErrorAPI.returnError(restResponse, requestId, 'Payload body context is missing or unreadable.', 200);
                return;
            }
            
            PaymentLinkRequest obj_PaymentLinkRequest;
            try {
                obj_PaymentLinkRequest = (PaymentLinkRequest)JSON.deserialize(
                    restRequest.requestBody.toString(), 
                    PaymentLinkRequest.class
                );
            } catch(Exception jsonEx) {
				returnErrorAPI.returnError(restResponse, requestId, 
                                           'INVALID_JSON_FORMAT: Ensure field data types match expectations. ' + jsonEx.getMessage(), 200);
                return;
            }

            validateFieldLevelSecurity();

            Payment_Link__c obj_PL = new Payment_Link__c();
            if (String.isNotBlank(obj_PaymentLinkRequest.PaymentLinkId)) {
                obj_PL.Id = (Id)Security.stripInaccessible(AccessType.CREATABLE, new List<Payment_Link__c>{ 
                    new Payment_Link__c(Id = obj_PaymentLinkRequest.PaymentLinkId) 
                }).getRecords()[0].Id;
            }
            
            obj_PL.CheckoutId__c = obj_PaymentLinkRequest.CheckoutId;
            obj_PL.Expiry_Timestamp__c = obj_PaymentLinkRequest.ExpiryTimestamp;
            obj_PL.Payment_URL__c = obj_PaymentLinkRequest.PaymentURL;
            obj_PL.Status__c = obj_PaymentLinkRequest.Status;
            if (String.isNotBlank(obj_PaymentLinkRequest.BookingFeeLineId)) {
                obj_PL.Booking_Fee_Line__c = obj_PaymentLinkRequest.BookingFeeLineId;
            } 
            if (String.isNotBlank(obj_PaymentLinkRequest.InvoiceId)) {
                obj_PL.Invoice__c = obj_PaymentLinkRequest.InvoiceId;
            }
            if (String.isNotBlank(obj_PaymentLinkRequest.EOIId)) {
                obj_PL.Expression_of_Interest__c = obj_PaymentLinkRequest.EOIId;
            }
            //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on Payment_Link upsert
            List<Database.UpsertResult> srList = Database.upsert(new List<Payment_Link__c>{ obj_PL }, false, AccessLevel.USER_MODE);
            Database.UpsertResult sr = srList[0];
            
            if (sr.isSuccess()) {
                obj_PaymentLinkResponse.PaymentLinkId = sr.getId();
                obj_PaymentLinkResponse.Status = obj_PL.Status__c;
                
                APIResponse response = new APIResponse('success', requestId, obj_PaymentLinkResponse, null);
                restResponse.responseBody = Blob.valueOf(JSON.serialize(response));
                restResponse.statusCode = 200;
            } else {
                List<String> errorMessages = new List<String>();
                for(Database.Error err : sr.getErrors()) {
                    errorMessages.add(err.getStatusCode() + ': ' + err.getMessage());
                }
                returnErrorAPI.returnError(restResponse, requestId, 'DML_ERROR: ' + String.join(errorMessages, ' | '), 200);
                return;
            }
            
        } catch (PaymentLinkException plex) {
            Database.rollback(sp);
            returnErrorAPI.returnError(restResponse, requestId, 'BAD_REQUEST: ' + plex.getMessage(), 200);
            return;
        } catch (Exception ex) {
            Database.rollback(sp);
            System.debug(LoggingLevel.ERROR, 'Fatal Integration Processing Fault: ' + ex.getStackTraceString());
            //1.1 MCR-73: Log unexpected failures via LoggerService.createApexLog
            LoggerService.save(LoggerService.createApexLog(
                ex,
                'Super App Payment Link API',
                'OIC_SAPaymentLinkAPI',
                'upsertPaymentLink'
            ));
            returnErrorAPI.returnError(restResponse, requestId, 'INTERNAL_SERVER_ERROR: ' + ex.getMessage(), 200);
            return;
        }
    }  

    private static void validateFieldLevelSecurity() {
        if (!Schema.sObjectType.Payment_Link__c.isAccessible() || 
            !Schema.sObjectType.Payment_Link__c.isCreateable() || 
            !Schema.sObjectType.Payment_Link__c.isUpdateable()) {
            throw new PaymentLinkException('SECURITY_ERROR: Insufficient object access execution permissions.');
        }
        
        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Payment_Link__c.fields.getMap();
        List<String> targetFields = new List<String>{'CheckoutId__c', 'Expiry_Timestamp__c', 'Payment_URL__c', 'Status__c', 'Booking_Fee_Line__c', 'Invoice__c'};
        
        for (String fieldName : targetFields) {
            Schema.DescribeFieldResult dfr = fieldMap.get(fieldName).getDescribe();
            if (!dfr.isCreateable() || !dfr.isUpdateable()) {
                throw new PaymentLinkException('SECURITY_ERROR: Insufficient field access permissions on ' + fieldName);
            }
        }
    }

    public class PaymentLinkRequest {
        public String BookingFeeLineId;
        public String InvoiceId;
        public String EOIId;
        public String PaymentLinkId;
        public String CheckoutId;
        public Datetime ExpiryTimestamp;
        public String PaymentURL;
        public String Status;        
    } 
    
    public class PaymentLinkResponse {
        public String PaymentLinkId;
        public String Status;    
        public String ErrorCode;    
        public String ErrorMessage;    
    }
}