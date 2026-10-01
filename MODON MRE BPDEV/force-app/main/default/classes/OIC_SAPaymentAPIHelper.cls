/**********************************************************************************************************************
* Name               : OIC_SAPaymentAPIHelper                                                        
* Description        : This class is used to create a payment.
* Usage              : 
* Created By         : Activemindsit                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh   	                02 02 2026      Initial Draft 
* 1.1           Suresh   	                13 05 2026      Allocation updated 
* 1.2           Suresh   	                29 09 2026      Added payment notification and case creation logic once the payment is created through Modon Connect. 
***********************************************************************************************************************/
global class OIC_SAPaymentAPIHelper {

    public static OIC_SAPaymentAPI.PaymentResponse createPaymentHelper(OIC_SAPaymentAPI.PaymentRequest obj_PaymentRequest){
        OIC_SAPaymentAPI.PaymentResponse obj_PaymentResponse = new OIC_SAPaymentAPI.PaymentResponse();
        Savepoint sp = Database.setSavepoint();
        try{
            if(String.isBlank(obj_PaymentRequest.CustomerName) || String.isBlank(obj_PaymentRequest.CustomerEmail)
               || String.isBlank(obj_PaymentRequest.UnitId) || String.isBlank(obj_PaymentRequest.ProjectName)
               || String.isBlank(obj_PaymentRequest.InvoiceId)){
                obj_PaymentResponse.Status = 'Failure';
           		obj_PaymentResponse.ErrorMessage = 'Please verify the mandatory fields customer name email unitid projectname and transactiontype';
            }else {
                String customerEmail = obj_PaymentRequest.CustomerEmail;
                String unitId = obj_PaymentRequest.UnitId;
                String projectName = obj_PaymentRequest.ProjectName;
                String invoiceId = obj_PaymentRequest.InvoiceId;
                
                List<Invoice__c> lst_Invoices = [SELECT Id, Name, InvoiceAmount__c, InvoiceBalance__c, AppliedAmount__c , 
                                                 InvoiceDate__c, InvoiceStatus__c, 
                                                 Sales_Order__c, SalesOrderInstallment__c, Sales_Order__r.CustomerAccount__c, 
                                                 SalesOrderInstallment__r.SalesOrder__r.CustomerAccount__c,
                                                 SalesOrderInstallment__r.SalesOrder__c from Invoice__c 
                                                 where InvoiceStatus__c != 'Paid' and Name = :invoiceId];
                if(lst_Invoices.size() == 0){
                    obj_PaymentResponse.Status = 'Success';
            		obj_PaymentResponse.ErrorMessage = 'Invoice is already paid';
                } else {
                    Invoice__c obj_Invoice = lst_Invoices.size() > 0?lst_Invoices.get(0):new Invoice__c();
                    //Unallocation logic
                    List<Allocation__c> lst_UpdateAllocation = new List<Allocation__c>();
                    List<Allocation__c> lst_Allocation = [select Id, Name, Status__c, InProgressReceiptAmount__c from Allocation__c 
                                                          where Invoice__r.Name = :invoiceId and Status__c = 'Applied' 
                                                          and InProgressReceiptAmount__c > 0 and Invoice__r.InvoiceStatus__c != 'Paid'
                                                          and Receipt__c != null and Receipt__r.Modeofpayment__c = 'Cheque'];
                    Decimal remaingAllAmount = 0.0;
                    for(Allocation__c obj_All : lst_Allocation){
                        if(obj_Invoice.InvoiceBalance__c <= obj_PaymentRequest.Amount){
                            obj_All.Status__c = 'Unapplied';
                            lst_UpdateAllocation.add(obj_All);
                        } else if(obj_All.InProgressReceiptAmount__c > (obj_PaymentRequest.Amount - remaingAllAmount)){
                            obj_All.InProgressReceiptAmount__c = obj_All.InProgressReceiptAmount__c - (obj_PaymentRequest.Amount - remaingAllAmount);
                            lst_UpdateAllocation.add(obj_All);
                            break;
                        } else if(obj_All.InProgressReceiptAmount__c <= (obj_PaymentRequest.Amount - remaingAllAmount)){
                            remaingAllAmount = remaingAllAmount + obj_All.InProgressReceiptAmount__c;
                            obj_All.Status__c = 'Unapplied';
                            lst_UpdateAllocation.add(obj_All);
                        } else {}
                    }                    
                    
                    if(lst_UpdateAllocation.size() > 0){
                        update lst_UpdateAllocation;
                    }
                    
                    Receipt__c obj_Receipt = new Receipt__c();
                    String AccountId = '';
                    if(!String.isBlank(obj_Invoice.Sales_Order__r.CustomerAccount__c)){
                        AccountId = obj_Invoice.Sales_Order__r.CustomerAccount__c;
                    } else {
                        AccountId = obj_Invoice.SalesOrderInstallment__r.SalesOrder__r.CustomerAccount__c;
                    }
                    
                    System.debug('>>>>>>>>>>> obj_Invoice.Sales_Order__r.CustomerAccount__c >> '+AccountId);
                    obj_Receipt.Account__c = AccountId != ''? AccountId:null;
                    obj_Receipt.BankName__c = obj_PaymentRequest.Bank;
                    //obj_Receipt.ChequeDate__c = obj_PaymentRequest.ChequeDate;
                    obj_Receipt.Last4Digit__c = obj_PaymentRequest.IBANorSwiftCodeLast4Digits;
                    obj_Receipt.Modeofpayment__c = obj_PaymentRequest.ModeOfPayment;
                    obj_Receipt.ReceiptDate__c = obj_PaymentRequest.TransactionDate;
                    obj_Receipt.EBS_Clearing_Date__c = obj_PaymentRequest.TransactionDate;
                    obj_Receipt.ReceiptRemarks__c = obj_PaymentRequest.Remarks;
                    //obj_Receipt.RemainingAmount__c = obj_PaymentRequest.Amount;
                    System.debug('>>>>>>>>>>>> obj_Invoice.Sales_Order__c >>>> '+obj_Invoice.Sales_Order__c);
                    System.debug('>>>>>>>>>>>> obj_Invoice.SalesOrderInstallment__r.SalesOrder__c >>>> '+obj_Invoice.SalesOrderInstallment__r.SalesOrder__c);
                    obj_Receipt.SalesOrder__c = obj_Invoice.Sales_Order__c!=null?obj_Invoice.Sales_Order__c:obj_Invoice.SalesOrderInstallment__r.SalesOrder__c;
                    obj_Receipt.SalesOrderInstallment__c = obj_Invoice.SalesOrderInstallment__c!=null?obj_Invoice.SalesOrderInstallment__c:null;
                    obj_Receipt.Status__c = 'In Progress';
                    obj_Receipt.TotalAmount__c = obj_PaymentRequest.Amount;
                    obj_Receipt.Receipt_Amount__c = obj_PaymentRequest.Amount;
                    obj_Receipt.TransactionDate__c = obj_PaymentRequest.TransactionDate;
                    obj_Receipt.TransactionNumber__c = obj_PaymentRequest.TransactionNumber;
                    System.debug('>>>>>>>>>>    '+System.JSON.serialize(obj_Receipt));
                    insert obj_Receipt;
                    System.debug('>>>>>>>>>>  Payment created successfully  >>>>  '+obj_Receipt.Id);
                    Id contentversionId = uploadFileBase64(obj_Receipt.Id, obj_PaymentRequest.FileAttachments);
                    
                    Decimal allocationAmount = obj_Invoice.InvoiceBalance__c - obj_PaymentRequest.Amount > 0?obj_PaymentRequest.Amount:obj_Invoice.InvoiceBalance__c;
                    Allocation__c allObj = new Allocation__c();
                    allObj.AllocationDate__c = system.today();
                    allObj.Invoice__c = obj_Invoice.Id;
                    allObj.Receipt__c = obj_Receipt.Id;
                    allObj.AllocationAmount__c = allocationAmount;
                    allObj.IsOnlineAllocation__c = true;
                    //1.1 added
                    if(obj_Receipt.SalesOrderInstallment__c == null){
                         insert allObj; 
                    }                                      
                    
                    if(obj_Receipt.Id != null){
                        sendEmailNotification(obj_Receipt.Id, contentversionId);
                        createCollectionCase(obj_Receipt.Id);
                    }
                    
                    obj_PaymentResponse.Status = 'Success';
            		obj_PaymentResponse.ErrorMessage = '';
                    obj_PaymentResponse.PaymentId = obj_Receipt.Id;
                    obj_PaymentResponse.ErrorCode = '';
                }
            }
        }catch(Exception exe){
            Database.rollback(sp);
            obj_PaymentResponse.Status = 'Failure';
            obj_PaymentResponse.ErrorMessage = exe.getMessage();
            LoggerService.save(LoggerService.createApexLog(
                    exe,
                    'OIC_SAPaymentAPIHelper',
                    'OIC_SAPaymentAPIHelper',
                    'createPaymentHelper'
                ));
        }
        return obj_PaymentResponse;
    }
    public static void sendEmailNotification(Id receiptId, Id contentVersionId){
        String emailTemplateName = 'Payment_Notification_Online';
        String custEmail = System.Label.PaymentNotificationMC;
        System.enqueueJob(new SendGridNotificationUtilityQueueable(null, null, emailTemplateName, custEmail, 'noreply@modon.com',
                                                                   'Modon Connect', null, null, 'Payment Notification', 'Collection Update',
                                                                    null, new List<Id>{contentVersionId}, receiptId));
    }
    
    public static void createCollectionCase(Id receiptId) {
        if (receiptId == null) {
            return;
        }
        List<Receipt__c> lst_Receipt = [SELECT Id, UnitNumber__c, SalesOrder__r.Unit__c, SalesOrder__r.PrimaryContact__r.Name, 
                                        SalesOrder__r.PrimaryContact__r.Email, SalesOrder__r.PrimaryContact__r.MobilePhone, 
                                        SalesOrder__r.CustomerAccount__c, Milestone_Description__c from Receipt__c
                                        WHERE Id = :receiptId
                                        WITH USER_MODE
                                        LIMIT 1];
        if(lst_Receipt.isEmpty()){
            System.debug(LoggingLevel.ERROR, 'Issue with Receipt Id while creating the case');
            throw new DMLException('Case creation aborted: Issue with Receipt Id while creating the case');
        }
        Receipt__c obj_Receipt = lst_Receipt.get(0);
        String safeDescription = String.isNotBlank(obj_Receipt.Milestone_Description__c) ? obj_Receipt.Milestone_Description__c : 'Collection Action Required';
        String caseSubjectAndDesc = safeDescription + ' - Modon Connect, Collection Update';
    
        List<SA_Cases_Mapping__mdt> lst_SAMapping = [
            SELECT Category__c, Channel__c, Origin__c, Request_Category__c, Request_Type__c,
                   Source__c, SubCategory__c, Sub_Vertical__c 
            FROM SA_Cases_Mapping__mdt
            WHERE Request_Category__c = 'Collection'
              AND Request_Type__c = 'Proof of Payment'
            WITH USER_MODE
            LIMIT 1
        ];
    
        if (lst_SAMapping.isEmpty()) {
            System.debug(LoggingLevel.ERROR, 'Mapping missing in SA_Cases_Mapping__mdt for Request_Category: Collection / Request_Type: Proof of Payment.');
            throw new DMLException('Case creation aborted: Configuration metadata mapping template not found.');
        }
        
        SA_Cases_Mapping__mdt obj_SAMap = lst_SAMapping.get(0);
    
        Case obj_Case = new Case(
            AccountId              = obj_Receipt.SalesOrder__r.CustomerAccount__c,
            Unit__c                = obj_Receipt.SalesOrder__r.Unit__c,
            Requestor_Phone__c     = obj_Receipt.SalesOrder__r.PrimaryContact__r.MobilePhone,
            Requestor_Email__c     = obj_Receipt.SalesOrder__r.PrimaryContact__r.Email,
            Requestor_Name__c      = obj_Receipt.SalesOrder__r.PrimaryContact__r.Name,
            Language_Preference__c = 'English',
            Description            = caseSubjectAndDesc,
            Subject                = caseSubjectAndDesc,
            Customer_Type__c       = 'Owner',
            Case_Comments__c       = '',
            Origin                 = obj_SAMap.Origin__c,
            Channel__c             = obj_SAMap.Channel__c,
            Source__c              = obj_SAMap.Source__c,
            Sub_Vertical__c        = obj_SAMap.Sub_Vertical__c,
            CaseCategory__c        = obj_SAMap.Category__c,
            CaseSubCategory__c     = obj_SAMap.SubCategory__c
        );
    
        try {
            Database.SaveResult sr = Database.insert(obj_Case, true, AccessLevel.USER_MODE);
            if (!sr.isSuccess()) {
                System.debug(LoggingLevel.ERROR, 'Failed to insert collection Case: ' + sr.getErrors()[0].getMessage());
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Context execution crash while running createCollectionCase: ' + e.getMessage());
            throw e; 
        }
    }

    public static Id uploadFileBase64(Id parentId, List<OIC_SAPaymentAPI.FileDetails> FileAttachments) {
        List<ContentVersion> lst_CV = new List<ContentVersion>();
        List<OIC_SAPaymentAPI.FileDetails> lst_FileDetails = new List<OIC_SAPaymentAPI.FileDetails>();
        lst_FileDetails = FileAttachments;
        
        for(OIC_SAPaymentAPI.FileDetails obj_FileDetails : lst_FileDetails){
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
        if(lst_CV.isEmpty()){
            return null;
        }else {
            return lst_CV.get(0).Id;
        }
    }
}