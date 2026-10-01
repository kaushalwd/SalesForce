/**********************************************************************************************************************
* Name               : OIC_SABookingFeePaymentAPI                                                        
* Description        : This class is used to create a Booking fee payment.
* Usage              : 
* Created By         : MODON                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh   	                11 07 2026      Initial Draft       
***********************************************************************************************************************/
global class OIC_SABookingFeePaymentAPIHelper {

    public static OIC_SABookingFeePaymentAPI.PaymentResponse createPaymentHelper(OIC_SABookingFeePaymentAPI.PaymentRequest obj_PaymentRequest){
        OIC_SABookingFeePaymentAPI.PaymentResponse obj_PaymentResponse = new OIC_SABookingFeePaymentAPI.PaymentResponse();
        Savepoint sp = Database.setSavepoint();
        try{
            if(String.isBlank(obj_PaymentRequest.BookingFeeId) || String.isBlank(obj_PaymentRequest.OpportunityId)){
                obj_PaymentResponse.Status = 'failure';
           		obj_PaymentResponse.ErrorMessage = 'Please verify the mandatory fields BookingFeeId and OpportunityId';
            }else {
                String bookingFeeId = obj_PaymentRequest.BookingFeeId;
                String oppId = obj_PaymentRequest.OpportunityId; 
                List<Booking_Fee_Line__c> lst_BFLine = [
                    SELECT Id, Name, Balance_Amount__c, Comments__c, Opportunity__c, Fee_Status__c, Total_Amount__c, 
                           Total_Paid_Amount__c, Type__c, Unit__c, Opportunity__r.Name, Unit__r.Name, 
                           Opportunity__r.PrimaryContact__r.Name, Opportunity__r.PrimaryContact__r.Email, 
                           Opportunity__r.PrimaryContact__r.MobilePhone, Unit__r.Phase__r.EscrowAccount__r.MerchantID__c, 
                           Unit__r.Phase__r.EscrowAccount__r.Current_Acc_Merchant_ID__c, Unit__r.Phase__r.Project__r.Name, 
                           Unit__r.Phase__r.Name, Unit__r.Type__c, Unit__r.Typology__c, Unit__r.Number_of_Bedrooms__c, 
                           Opportunity__r.AccountId, Unit__r.Phase__r.EscrowAccount__c, Unit__r.Phase__r.Project__c, Unit__r.Phase__c
                    FROM Booking_Fee_Line__c 
                    WHERE Opportunity__r.Source_Entity__c != 'Modon - Egypt' 
                      AND Opportunity__r.StageName != 'Closed Lost' 
                      AND Opportunity__r.Id = :oppId
                      AND Fee_Status__c IN ('Generated', 'Partially Paid')
                      AND Id = :bookingFeeId
                    WITH SYSTEM_MODE
                ];
                if(lst_BFLine.isEmpty()){
                    obj_PaymentResponse.Status = 'success';
            		obj_PaymentResponse.ErrorMessage = 'BookingFee Line is not valid. Please verify opportunity';
                } else {
                    Booking_Fee_Line__c obj_BFLine = lst_BFLine.size() > 0?lst_BFLine.get(0):new Booking_Fee_Line__c();
                    Receipt__c obj_Receipt = new Receipt__c();
                    
                    obj_Receipt.Account__c = obj_BFLine.Opportunity__r.AccountId;
                    obj_Receipt.Booking_Fee_Line__c = obj_BFLine.Id;
                    obj_Receipt.EOIEscrowAccount__c =  obj_BFLine.Unit__r?.Phase__r?.EscrowAccount__c;
                    obj_Receipt.Project__c = obj_BFLine.Unit__r?.Phase__r?.Project__c;
                    obj_Receipt.Phase__c = obj_BFLine.Unit__r?.Phase__c;
                    
                    obj_Receipt.BankName__c = obj_PaymentRequest.Bank;
                    obj_Receipt.Last4Digit__c = obj_PaymentRequest.CardLast4Digits;
                    obj_Receipt.Last4DigitString__c = obj_PaymentRequest.CardLast4Digits!=null?String.valueOf(obj_PaymentRequest.CardLast4Digits):'';
                    obj_Receipt.Modeofpayment__c = obj_PaymentRequest.ModeOfPayment;
                    obj_Receipt.ReceiptDate__c = obj_PaymentRequest.TransactionDate?.date();
                    obj_Receipt.EBS_Clearing_Date__c = obj_PaymentRequest.TransactionDate?.date();
                    obj_Receipt.ReceiptRemarks__c = obj_PaymentRequest.Remarks;
                    obj_Receipt.Status__c = 'Confirmed';
                    obj_Receipt.TotalAmount__c = obj_PaymentRequest.Amount;
                    obj_Receipt.Receipt_Amount__c = obj_PaymentRequest.Amount;
                    obj_Receipt.TransactionDate__c = obj_PaymentRequest.TransactionDate;
                    obj_Receipt.TransactionNumber__c = obj_PaymentRequest.TransactionNumber;
                    obj_Receipt.Opportunity__c = obj_PaymentRequest.OpportunityId;
                    
                    insert as system obj_Receipt;
                    
                    Booking_Fee_Allocation__c obj_BFAllocation = new Booking_Fee_Allocation__c();
                    obj_BFAllocation.Allocation_Amount__c = obj_PaymentRequest.Amount;
                    obj_BFAllocation.Booking_Fee_Line__c = obj_BFLine.Id;
                    obj_BFAllocation.Payment__c = obj_Receipt.Id;
                    obj_BFAllocation.Status__c = 'Applied';
                    insert as system obj_BFAllocation;
                    
                    uploadFileBase64(obj_Receipt.Id, obj_PaymentRequest.FileAttachments);
                    
                    obj_PaymentResponse.Status = 'success';
            		obj_PaymentResponse.ErrorMessage = '';
                    obj_PaymentResponse.PaymentId = obj_Receipt.Id;
                    obj_PaymentResponse.ErrorCode = '';
                }
            }
        }catch(Exception exe){
            Database.rollback(sp);
            obj_PaymentResponse.Status = 'failure';
            obj_PaymentResponse.ErrorMessage = exe.getMessage();
            LoggerService.save(LoggerService.createApexLog(exe, 'OIC_SABookingFeePaymentAPIHelper', 'OIC_SABookingFeePaymentAPIHelper', 'createPaymentHelper'));
        }
        return obj_PaymentResponse;
    }
    
    public static void uploadFileBase64(Id parentId, List<OIC_SABookingFeePaymentAPI.FileDetails> fileAttachments) {
        if (fileAttachments == null || fileAttachments.isEmpty()) {
            return;
        }

        List<ContentVersion> baseFiles = new List<ContentVersion>();
        for (OIC_SABookingFeePaymentAPI.FileDetails detail : fileAttachments) {
            if (String.isBlank(detail.Base64FileContent)) {
                continue;
            }
            ContentVersion cv = new ContentVersion();
            cv.Title = detail.FileName;
            cv.PathOnClient = '/' + detail.FileName;
            cv.VersionData = EncodingUtil.base64Decode(detail.Base64FileContent);
            cv.Description = 'Receipt Details';
            baseFiles.add(cv);
        }
        
        if (baseFiles.isEmpty()) {
            return;
        }
        insert as system baseFiles;
        
        List<ContentDocumentLink> shareLinks = new List<ContentDocumentLink>();
        for (ContentVersion cv : [
            SELECT ContentDocumentId 
            FROM ContentVersion 
            WHERE Id IN :baseFiles
            WITH SYSTEM_MODE
        ]) {
            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.ContentDocumentId = cv.ContentDocumentId;
            cdl.LinkedEntityId = parentId;
            cdl.ShareType = 'V'; 
            cdl.Visibility = 'AllUsers';
            shareLinks.add(cdl);
        }
        
        if (!shareLinks.isEmpty()) {
            insert as system shareLinks;
        }
    }
}