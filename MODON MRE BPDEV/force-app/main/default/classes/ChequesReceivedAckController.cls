public without sharing class ChequesReceivedAckController {

     @AuraEnabled
    public static String generatePDF(Id salesOrderId) {
        System.debug('generatePDF >>>>>>>>>>> salesOrderId  >> '+salesOrderId);
        String vfPageUrl = '/apex/ChequeAcknowledgementPDF?Id=';
        vfPageUrl += salesOrderId;
        return vfPageUrl;
    }
    
    public static Blob readyPDF(Id salesOrderId){
        PageReference pdfPage = Page.ChequeAcknowledgementPDF;
        pdfPage.getParameters().put('Id', salesOrderId);
        if (Test.isRunningTest()){
            return Blob.valueOf('Mock Content');
        }
        Blob pdfBlob = pdfPage.getContentAsPDF();
        
        if (pdfBlob == null || pdfBlob.size() == 0) {
            System.debug('Error: PDF Blob is empty or null. Page might not be rendering correctly.');
            throw new AurahandledException('Error generating PDF. Please check the page.');
        }
        return pdfBlob;
    }
    
    @AuraEnabled
	public static void sendEmailToCustomer(Id salesOrderId){
    // Generate the PDF blob from Visualforce
    Blob pdfBlob = readyPDF(salesOrderId);

    // Query Sales Order and related Person Account
    SalesOrder__c so = [
        SELECT Id, Name, CustomerAccount__r.PersonEmail, CustomerAccount__r.Id, CustomerAccount__r.IsPersonAccount
        FROM SalesOrder__c
        WHERE Id = :salesOrderId
        LIMIT 1
    ];

    // Proceed only if we have a valid Person Account with email
    if (
        so.CustomerAccount__r != null &&
        so.CustomerAccount__r.IsPersonAccount &&
        String.isNotBlank(so.CustomerAccount__r.PersonEmail)
    ) {

        // Send templated email using NotificationUtility
        NotificationUtility.sendNotification(
            'Receipt_Acknowledgment_Template',      // Email Template developer name
            new List<Id>{ so.CustomerAccount__c },  // Recipient (Person Account acts as Contact)
            false,                                  // sendBellNotification = false
            so.Id,                                  // whatId (SalesOrder__c context)
            null,                                   // whoId (optional, not used)
            null, null, null, null,                 // bell-related params not needed
            pdfBlob,                                // PDF attachment
           	'Receipt'                               // File name (without .pdf)
        );
    } else {
        throw new AuraHandledException('Customer email not found or account is not a Person Account. Cannot send receipt.');
    }
}

    /*public static void sendEmail(Blob pdfBlob, String customerEmail) {
   	   
        EmailTemplate emailTemplate = [SELECT Id, Subject, Markup FROM EmailTemplate WHERE DeveloperName = 'Thank_you_for_Interest' LIMIT 1];
        if (String.isNotBlank(customerEmail) && emailTemplate != null) {
            String emailBody = emailTemplate.Markup;
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(new String[] { customerEmail });
            email.setSubject('');
            email.setHtmlBody(emailBody);
            String fileName = 'Receipt';

            if (pdfBlob != null) {
                Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
                attachment.setFileName(fileName+'.pdf');
                attachment.setBody(pdfBlob);
                attachment.setContentType('application/pdf');
                email.setFileAttachments(new Messaging.EmailFileAttachment[] { attachment });
            }

            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
        }
    }*/
    
    @AuraEnabled
    public static SalesOrderDetails getSalesOrderDetails(Id recordId){
        System.debug('getSalesOrderDetails >>>>  recordId  '+recordId);
        SalesOrderDetails obj_SalesOrderDetails = new SalesOrderDetails();
        if(recordId != null){
            List<Receipt__c> lst_Receipts = [select Id, Name, Milestone__c, Bank__c, TransactionNumber__c, 
                                             ChequeDate__c, TotalAmount__c, AppliedAmount__c, SalesOrder__r.CustomerAccount__r.Name, 
                                             SalesOrder__r.Unit__r.Name, SalesOrder__r.Name, SalesOrder__r.ProjectName__c 
                                             from Receipt__c where  Status__c NOT IN ('Cancelled', 'Rejected') and SalesOrder__r.Id = :recordId];
            if(lst_Receipts.size() > 0){
                Receipt__c obj_Receipt = lst_Receipts.get(0);
                obj_SalesOrderDetails.customerName = obj_Receipt.SalesOrder__r.CustomerAccount__r.Name;
                obj_SalesOrderDetails.unitNo = obj_Receipt.SalesOrder__r.Unit__r.Name;
                obj_SalesOrderDetails.saleOrderNo = obj_Receipt.SalesOrder__r.Name;
                obj_SalesOrderDetails.projectName = obj_Receipt.SalesOrder__r.ProjectName__c;
                obj_SalesOrderDetails.currentDateVal = System.today();
                obj_SalesOrderDetails.soPaymentDetails = new List<PaymentDetails>();
            }
            for(Receipt__c obj_Receipt : lst_Receipts){
                PaymentDetails obj_PaymentDetails = new PaymentDetails();
                obj_PaymentDetails.milestone = obj_Receipt.Milestone__c!=null?obj_Receipt.Milestone__c.intValue():null;
                obj_PaymentDetails.bank = obj_Receipt.Bank__c;
                obj_PaymentDetails.transactionNumber = obj_Receipt.TransactionNumber__c;
                obj_PaymentDetails.chequeDate = obj_Receipt.ChequeDate__c;
                obj_PaymentDetails.amount = obj_Receipt.AppliedAmount__c;
                obj_SalesOrderDetails.soPaymentDetails.add(obj_PaymentDetails);
            }
        }
        System.debug('getSalesOrderDetails >>>>  obj_SalesOrderDetails  '+System.JSON.serialize(obj_SalesOrderDetails));
        return obj_SalesOrderDetails;    
    } 
    
    public class SalesOrderDetails{
        @AuraEnabled public String customerName{get;set;}
        @AuraEnabled public String unitNo{get;set;}
        @AuraEnabled public String saleOrderNo{get;set;}
        @AuraEnabled public String projectName{get;set;}
        @AuraEnabled public Date currentDateVal{get;set;}
        @AuraEnabled public List<PaymentDetails> soPaymentDetails {get;set;}
    }
    public class PaymentDetails{
        @AuraEnabled public Integer milestone{get;set;}
        @AuraEnabled public String bank{get;set;}
        @AuraEnabled public String transactionNumber{get;set;}
        @AuraEnabled public Date chequeDate{get;set;}
        @AuraEnabled public Decimal amount{get;set;}
    }
}