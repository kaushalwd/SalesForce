/**********************************************************************************************************************
* Name               : OIC_SABookingFeePaymentAPI                                                        
* Description        : This class is used to create a Booking fee payment.
* Usage              : 
* Created By         : MODON                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh   	                11 07 2026      Initial Draft
* 1.1           Jay Patel                   21 Sep 2026     MCR-73 — with sharing
***********************************************************************************************************************/
@RestResource(urlMapping='/superapp/bookingfee/createpayment/*')
global with sharing class OIC_SABookingFeePaymentAPI {

    @HttpPost
    global static void createBookingFeePayment() {
        RestRequest restRequest = RestContext.request;
        RestResponse restResponse = RestContext.response;
        PaymentRequest obj_PaymentRequest = new PaymentRequest();
        PaymentResponse obj_PaymentResponse = new PaymentResponse();
        String requestId = String.valueOf(UUID.randomUUID());
        restRequest.addHeader('Content-Type', 'application/json');
        restResponse.addHeader('Content-Type', 'application/json');
        System.debug('OIC_SABookingFeePaymentAPI >>>> PaymentRequest >> '+restRequest.requestBody.toString());
        try{
            try {
                obj_PaymentRequest = (PaymentRequest) JSON.deserialize(restRequest.requestBody.toString(), PaymentRequest.class);
            } catch (Exception parseEx) {
                returnErrorAPI.returnError(restResponse, requestId, 'Malformed JSON payload: ' + parseEx.getMessage(), 200);
                return;
            }

            obj_PaymentResponse = OIC_SABookingFeePaymentAPIHelper.createPaymentHelper(obj_PaymentRequest);
            
            APIResponse response = new APIResponse('success', requestId, obj_PaymentResponse, null);
            restResponse.responseBody = Blob.valueOf(JSON.serialize(response));
            restResponse.statusCode = 200;
            
        }catch (Exception ex) { 
            LoggerService.save(LoggerService.createApexLog(ex, 'OIC_SABookingFeePaymentAPI', 'OIC_SABookingFeePaymentAPI', 'createBookingFeePayment'));
            returnErrorAPI.returnError(restResponse, requestId, 'An unexpected server error occurred: ' + ex.getMessage(), 200);
            return;
        }
    }  
    
    global class PaymentRequest{
        public String BookingFeeId;
        public String CustomerName;
        public String CustomerEmail;
        public String SourceSystem;
        public String OpportunityId;
        public String ModeOfPayment;	
        public String TransactionNumber;
        public String Bank;	
        public String IBANorSwiftCodeLast4Digits;
        public Decimal CardLast4Digits;
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