/**********************************************************************************************************************
* Name               : OIC_SAEOIPaymentAPI                                                        
* Description        : This class is used to create a eoi payment.
* Usage              : 
* Created By         : Activemindsit                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh   	                02 02 2026      Initial Draft
* 1.1           Jay Patel                   21 Sep 2026     MCR-73 — with sharing, createApexLog
***********************************************************************************************************************/
@RestResource(urlMapping='/superapp/eoi/createpayment/*')
global with sharing class OIC_SAEOIPaymentAPI {

    @HttpPost
    global static void createEOIPayment() {
        RestRequest restRequest = RestContext.request;
        RestResponse restResponse = RestContext.response;
        PaymentRequest obj_PaymentRequest = new PaymentRequest();
        PaymentResponse obj_PaymentResponse = new PaymentResponse();
        String requestId = String.valueOf(UUID.randomUUID());
        restRequest.addHeader('Content-Type', 'application/json');
        try {
            System.debug('OIC_SAPaymentAPI >>>> PaymentRequest >> '+restRequest.requestBody.toString());
            obj_PaymentRequest = (PaymentRequest)System.JSON.deserialize(restRequest.requestBody.toString(), PaymentRequest.class);
            System.debug('OIC_SAPaymentAPI >>>> PaymentRequest >> '+System.JSON.serialize(obj_PaymentRequest));
            obj_PaymentResponse = OIC_SAEOIPaymentAPIHelper.createPaymentHelper(obj_PaymentRequest);
            APIResponse response = new APIResponse('success', requestId, obj_PaymentResponse, null);
            restResponse.responseBody = Blob.valueOf(JSON.serialize(response));
            restResponse.addHeader('Content-Type', 'application/json');
            restResponse.statusCode = 200;
        } catch (Exception ex) {
            //1.1 MCR-73: Log unexpected failures via LoggerService.createApexLog
            LoggerService.save(LoggerService.createApexLog(
                ex,
                'Super App EOI Payment API',
                'OIC_SAEOIPaymentAPI',
                'createEOIPayment'
            ));
            returnErrorAPI.returnError(restResponse, requestId, 'An unexpected server error occurred: ' + ex.getMessage(), 200);
        }
    }  
    
    global class PaymentRequest{
        public String CreditCardTokenId;
        public String CustomerName;
        public String CustomerEmail;
        public String SourceSystem;
        public String EOIId;
        public String AccountId;
        public String ModeOfPayment;	
        public String TransactionNumber;
        public String Bank;	
        public Double IBANorSwiftCodeLast4Digits;
        public String CardLast4Digits;
        public String Remarks;
        public Decimal Amount;
        public Datetime TransactionDate;
        public List<FileDetails> FileAttachments;
        public PaymentRequest(){}
    } 
    global class PaymentResponse {
        public String PaymentId;
        public String Status;	
        public String ErrorCode;	
        public String ErrorMessage;	
    }
   
    global class FileDetails {
        public String FileName;
        public String Base64FileContent;
    }    
}