/**********************************************************************************************************************
* Name               : ChequesClearedBatch                                                        
* Description        : This class is used to send the cheques ack to customers
* Usage              : Batch class
* Created By         : Suresh                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh         			    04 01 2026     Initial Draft    
* 2.0           Suresh         			    24 04 2026     Initial Draft
******************************************************************************************************************/
global without sharing class ChequesClearedBatch implements Database.Batchable<sObject> {
	global List<Receipt__c> records;
    
    global ChequesClearedBatch(List<Receipt__c> listReceipt) {
        this.records = listReceipt;
    }
    
    global Iterable<SObject> start(Database.BatchableContext BC) {
 		return records;
    }    
 
    global static Blob readyPDF(Id receiptId){
        PageReference pdfPage = Page.ReceiptDocument;
        pdfPage.getParameters().put('Id', receiptId);
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
    
    global void execute(Database.BatchableContext BC, List<Receipt__c> scope) {
        List<Receipt__c> listReceipt = (List<Receipt__c>)scope;
        String emailTemplateName = ''; 
       	for(Receipt__c obj_Receipt : listReceipt){
            // Generate the PDF blob from Visualforce 
            Blob pdfBlob = readyPDF(obj_Receipt.Id);
            String SOId = '';
            System.debug('>>>>>>>>>>>>>>>>>>> obj_Receipt.Status__c >>>>>>> '+obj_Receipt.Status__c);
            System.debug('>>>>>>>>>>>>>>>>>>> obj_Receipt.Cheque_Bounce_Reason__c >>>>>>> '+obj_Receipt.Cheque_Bounce_Reason__c);
            //2.0 - change
            emailTemplateName = 'Receipt_'+obj_Receipt.Status__c+'_Communication';
              if(obj_Receipt.SalesOrder__c != null){
                       SOId = obj_Receipt.SalesOrder__c; 
                    } else if(obj_Receipt.SalesOrderInstallment__r.SalesOrder__c != null){
                       SOId = obj_Receipt.SalesOrderInstallment__r.SalesOrder__c;  
                    } else {} 
              // Query Sales Order and related Person Account
                SalesOrder__c so = [
                    SELECT Id, Name, CustomerAccount__r.PersonEmail, CustomerAccount__r.Id, CustomerAccount__r.IsPersonAccount, PrimaryContact__r.Email,  
                    JO1__r.Email, JO2__r.Email, JO3__r.Email, JO4__r.Email, JO5__r.Email, JO6__r.Email FROM SalesOrder__c
                    WHERE Id = :SOId
                    LIMIT 1
                ];
        
             String custEmail = '';
             if(so != null && (!String.isBlank(so.CustomerAccount__r.PersonEmail) || String.isNotBlank(so.PrimaryContact__r.Email))){
                 custEmail = String.isNotBlank(so.CustomerAccount__r.PersonEmail)?so.CustomerAccount__r.PersonEmail:so.PrimaryContact__r.Email;
                 System.debug('>>>>>>>>>>>>>>>>>>>>>> custEmail >> '+custEmail);
                 if(!String.isBlank(so.JO1__r.Email)){
                    custEmail = custEmail+','+so.JO1__r.Email; 
                 }
                 
                 if(!String.isBlank(so.JO2__r.Email)){
                    custEmail = custEmail+','+so.JO2__r.Email; 
                 }
                 if(!String.isBlank(so.JO3__r.Email)){
                    custEmail = custEmail+','+so.JO3__r.Email; 
                 }
                 if(!String.isBlank(so.JO4__r.Email)){
                    custEmail = custEmail+','+so.JO4__r.Email; 
                 }
                 if(!String.isBlank(so.JO5__r.Email)){
                    custEmail = custEmail+','+so.JO5__r.Email; 
                 }
                 if(!String.isBlank(so.JO6__r.Email)){
                    custEmail = custEmail+','+so.JO6__r.Email; 
                 }
               } 
		     //Added 2.0 change 		            
             System.enqueueJob(new SendGridNotificationUtilityBlobQueueable(null,null,emailTemplateName,custEmail,'noreply@modon.com',
                                                           				  'MODON Sales Team',null,null,'ReceiptsAck','Customer Management',
                                                                           null,pdfBlob,'Receipts','pdf',obj_Receipt.Id ));
        }
    }
    global void finish(Database.BatchableContext BC) {}
}