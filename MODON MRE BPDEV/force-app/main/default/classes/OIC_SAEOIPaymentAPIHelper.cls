global class OIC_SAEOIPaymentAPIHelper {

    public static OIC_SAEOIPaymentAPI.PaymentResponse createPaymentHelper(OIC_SAEOIPaymentAPI.PaymentRequest obj_PaymentRequest){
        OIC_SAEOIPaymentAPI.PaymentResponse obj_PaymentResponse = new OIC_SAEOIPaymentAPI.PaymentResponse();
        Savepoint sp = Database.setSavepoint();
        try{
            if(String.isBlank(obj_PaymentRequest.EOIId) || String.isBlank(obj_PaymentRequest.AccountId)){
                obj_PaymentResponse.Status = 'failure';
           		obj_PaymentResponse.ErrorMessage = 'Please verify the mandatory fields EOIId and AccountId';
            }else {
                String eoiId = obj_PaymentRequest.EOIId;
                String accountId = obj_PaymentRequest.AccountId; 
                List<Expressionofinterest__c> lst_EOI = [SELECT Id, Name, EOIId__c, Opportunity__c, Project__c, Phase__c, UnitType__c, 
                                                         NumberofBedrooms__c, UnitTypologyMRE__c, Number_of_Units__c, EOI_Range__c, 
                                                         EOI_Amount_AED__c, EOIComments__c, Account__c, Contact__c,
                                                         Phase__r.EscrowAccount__r.MerchantID__c, Contact__r.Name, Contact__r.Email, 
                                                         Contact__r.MobilePhone, Phase__r.Project__r.Name, Phase__r.Name, Status__c,
                                                         Phase__r.EscrowAccount__c, Phase__r.Project__c
                                                         from Expressionofinterest__c where Source_Entity__c != 'Modon - Egypt' 
                                                         and Id = :eoiId and Account__c = :accountId];
                if(lst_EOI.size() == 0){
                    obj_PaymentResponse.Status = 'success';
            		obj_PaymentResponse.ErrorMessage = 'EOI is not valid. Please verify Expression of Interest record';
                } else {
                    Expressionofinterest__c obj_EOI = lst_EOI.size() > 0?lst_EOI.get(0):new Expressionofinterest__c();
                    Receipt__c obj_Receipt = new Receipt__c();
                    
                    obj_Receipt.Account__c = obj_EOI.Account__c;
                    obj_Receipt.ExpressionOfInterest__c = obj_EOI.Id;
                    obj_Receipt.EOIEscrowAccount__c =  obj_EOI.Phase__r?.EscrowAccount__c;
                    obj_Receipt.Project__c = obj_EOI.Phase__r?.Project__c;
                    obj_Receipt.Phase__c = obj_EOI.Phase__c;
                    
                    obj_Receipt.BankName__c = obj_PaymentRequest.Bank;
                    obj_Receipt.Last4Digit__c = obj_PaymentRequest.IBANorSwiftCodeLast4Digits;
                    obj_Receipt.Modeofpayment__c = obj_PaymentRequest.ModeOfPayment;
                    obj_Receipt.ReceiptDate__c = obj_PaymentRequest.TransactionDate?.date();
                    obj_Receipt.EBS_Clearing_Date__c = obj_PaymentRequest.TransactionDate?.date();
                    obj_Receipt.ReceiptRemarks__c = obj_PaymentRequest.Remarks;
                    obj_Receipt.Status__c = 'Confirmed';
                    obj_Receipt.TotalAmount__c = obj_PaymentRequest.Amount;
                    obj_Receipt.Receipt_Amount__c = obj_PaymentRequest.Amount;
                    obj_Receipt.TransactionDate__c = obj_PaymentRequest.TransactionDate;
                    obj_Receipt.TransactionNumber__c = obj_PaymentRequest.TransactionNumber;
                    if(String.isNotBlank(obj_PaymentRequest.CreditCardTokenId)){
                        obj_Receipt.CreditCardToken__c = obj_PaymentRequest.CreditCardTokenId;
                    }                    
                    insert obj_Receipt;
                    
                    EOI_Allocation__c obj_EOIAll = new EOI_Allocation__c();
                    obj_EOIAll.Allocation_Amount__c = obj_PaymentRequest.Amount;
                    obj_EOIAll.Expression_of_Interest__c = obj_EOI.Id;
                    obj_EOIAll.Payment__c = obj_Receipt.Id;
                    obj_EOIAll.Status__c = 'Applied';
                    insert obj_EOIAll;
                    
                    uploadFileBase64(obj_Receipt.Id, obj_PaymentRequest.FileAttachments);
                    
                    if(String.isNotBlank(obj_PaymentRequest.CreditCardTokenId)){
                        List<CreditCardToken__c> lst_CCToken = [SELECT Id, Account__c, Amount__c, Approved__c, Authcode__c, Card_Category__c, Card_Type__c, 
                                  					CurrencyIsoCode, ExpiresOn__c, Expression_of_Interest__c, Issuer__c, Issuer_Country__c, 
                                 					Last4CardNumber__c, Opportunity__c, Processed_On__c, Reference__c, Response_Code__c, 
                                                    Response_Summary__c, SourceSystem__c, Status__c, TokenId__c,  Transaction_Id__c, UpdatedBy__c 
                                                    from CreditCardToken__c where Id = :obj_PaymentRequest.CreditCardTokenId];
                        CreditCardToken__c obj_CC = lst_CCToken.size() > 0?lst_CCToken.get(0):null;
                        if(obj_CC != null){
                            obj_CC.Status__c = 'Processed';
                            obj_CC.UpdatedBy__c = obj_PaymentRequest.SourceSystem;
                            Database.update(obj_CC, AccessLevel.SYSTEM_MODE);
                        }                        
                    }
                    
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
        }
        return obj_PaymentResponse;
    }
    public static void uploadFileBase64(Id parentId, List<OIC_SAEOIPaymentAPI.FileDetails> FileAttachments) {
        List<ContentVersion> lst_CV = new List<ContentVersion>();
        List<OIC_SAEOIPaymentAPI.FileDetails> lst_FileDetails = new List<OIC_SAEOIPaymentAPI.FileDetails>();
        lst_FileDetails = FileAttachments;
        
        for(OIC_SAEOIPaymentAPI.FileDetails obj_FileDetails : lst_FileDetails){
            ContentVersion cv = new ContentVersion();
            Blob fileBody = EncodingUtil.base64Decode(obj_FileDetails.Base64FileContent);
            cv.Title = obj_FileDetails.FileName;
            cv.PathOnClient = '/' + obj_FileDetails.FileName;
            cv.VersionData = fileBody;
            cv.Description = 'Recept Details';
            lst_CV.add(cv);
        }
        
        insert lst_CV;
        
        List<ContentDocumentLink> links = new List<ContentDocumentLink>();
        for (ContentVersion cv : [
            SELECT Id, ContentDocumentId 
            FROM ContentVersion 
            WHERE Id IN :lst_CV
        ]) {
            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.ContentDocumentId = cv.ContentDocumentId;
            cdl.LinkedEntityId = parentId;
            cdl.ShareType = 'V'; // Viewer
            cdl.Visibility = 'AllUsers';
            links.add(cdl);
        }
        
        insert links;
    }
}