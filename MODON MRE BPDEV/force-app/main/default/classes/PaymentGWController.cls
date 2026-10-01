/**********************************************************************************************************************
* Name               : PaymentGWController                                                       
* Description        : This is a class to read the output of payment gateway URL params.
* Usage              : 
* Created By         : PwC Digital Middle East                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Anil Valluri                18 Jan 2024     Initial Draft   
******************************************************************************************************************/    

public without sharing class PaymentGWController {
    
    public string resp {get; set;}
    public string paymentStatus {get; set;}

    public void paymentGWURLResponseCtrl() {

        try{
            resp = JSON.Serialize(ApexPages.currentPage().getParameters());
            system.debug('Payment gateway URL params::::: ' + resp);

            // check response and process..
            string recId = ApexPages.currentPage().getParameters().get('oid');
            paymentStatus = ApexPages.currentPage().getParameters().get('status');
            string IPGTransactionID = ApexPages.currentPage().getParameters().get('ipgTransactionId');
            string transactionDateTimePW = ApexPages.currentPage().getParameters().get('txndatetime');

            if(recId <> null && recId <> ''){
                Receipt__c receiptToUpdate = new Receipt__c();

                if(recId.contains('_'))
                receiptToUpdate.Id = recId.substringBefore('_');
                else 
                receiptToUpdate.Id = recId;
            
                receiptToUpdate.PaymentStatus__c = paymentStatus;

                if(paymentStatus == 'APPROVED' || paymentStatus == 'SUCCESS') 
                receiptToUpdate.Status__c = 'Approved';
                else //if(paymentStatus == 'FAILED' || paymentStatus == 'REJECTED')
                receiptToUpdate.Status__c = 'Rejected';

                receiptToUpdate.PaymentGatewayRawResponse__c = resp;
                receiptToUpdate.IPGTransactionId__c = IPGTransactionID;
                receiptToUpdate.TransactionDateTimePGWinText__c = transactionDateTimePW;

                update receiptToUpdate;
            }
        }
        catch(Exception e) {        
            LoggerService.save(LoggerService.createApexLog(e,'PaymentGWController','PaymentGWController.paymentGWURLResponseCtrl',''));
            system.debug('Error:::: ' + e.getMessage() + ' Trace::: ' + e.getStackTraceString());
        }   
    } 
}