/**********************************************************************************************************************
* Name               : SalesOrderInstallmentsControllerEquity                                                        
* Description        :  for the Sales Order instalments where payments needs to collected, sending the reminder.
* Usage              :  For sending the payment reminders                                                     
* Created By         :  Sami Azam                                                 
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                          Date            Comment                                                                       
* 1.0          Sami                             4 Dec 2025      Added the condtion for 5, 6, 7, 8 instalment
******************************************************************************************************************/

public class SalesOrderInstallmentsControllerEquity {
    private Id internalSalesOrderId;
    public string salesOrderId {get;set;}
    public string instalmentNumber{get;set;}
     public string emailReminderValue {get;set;}
     public string emailReminderValueStr {get;set;}
    
    
//helper method to get the percentage number
//added conditions for 5 to 8 instalments
    public SalesOrderInstallments__c getPercentage() {
        List<SalesOrderInstallments__c> SOI_List = new List<SalesOrderInstallments__c>();
        Integer instalNumner = (emailReminderValue =='Downpayment Reminder') ? 1 
            : (emailReminderValue == 'Second Instalment Reminder')? 2
            : (emailReminderValue == 'Third Instalment Reminder') ? 3 
            : (emailReminderValue == 'Fourth Instalment Reminder') ? 4
            : (emailReminderValue == 'Fifth Instalment Reminder') ? 5 //v1.0
            : (emailReminderValue == 'Sixth Instalment Reminder') ? 6 //v1.0
            : (emailReminderValue == 'Seventh Instalment Reminder') ? 7 //v1.0
            : (emailReminderValue == 'Eight Instalment Reminder') ? 8      //v1.0
            : (emailReminderValue == 'Reem Hills Sixth Payment Reminder') ? 6 
            : null;
        
        try{

                SOI_List = [SELECT MilestoneNumber__c,MilestoneDescription__c,Milestone__c,MilestoneDate__c,InstallmentAmount__c,salesOrder__r.Email_Reminder__c FROM SalesOrderInstallments__c  WHERE SalesOrder__c = :salesOrderId and MilestoneNumber__c = :instalNumner  LIMIT 1];
        }catch(QueryException e){    
        }
        if(SOI_List.size() >0){
            return SOI_List[0];
        }else {
            return null;
        }
    }
    
    /*
     public SalesOrderInstallments__c getPaymentPercentage() {
        List<SalesOrderInstallments__c> SOI_List = new List<SalesOrderInstallments__c>();
        
        
        system.debug('emailReminderValueStr-->>'+emailReminderValueStr);
        
        try{
            if(emailReminderValueStr != 'ADM Reminder'){
                SOI_List = [SELECT MilestoneNumber__c,MilestoneDescription__c,Milestone__c,MilestoneDate__c,InstallmentAmount__c,salesOrder__r.Email_Reminder__c FROM SalesOrderInstallments__c  WHERE SalesOrder__c = :salesOrderId and MilestoneNumber__c = 2  LIMIT 1];
            }
            else if(emailReminderValueStr == 'ADM Reminder'){
                SOI_List = [SELECT MilestoneNumber__c,MilestoneDescription__c,Milestone__c,MilestoneDate__c,InstallmentAmount__c,salesOrder__r.Email_Reminder__c FROM SalesOrderInstallments__c  WHERE SalesOrder__c = :salesOrderId and MilestoneNumber__c = 2  LIMIT 1];
            }
            
            
        }catch(QueryException e){
            
        }
        if(SOI_List.size() >0){
            return SOI_List[0];
        }else {
            return null;
        }
    }
*/
    
    
        
        // A helper method to get the Milestone__c directly
    public decimal getMilestoneValue() {
        SalesOrderInstallments__c installment = getPercentage();
        return installment != null ? installment.Milestone__c : 0;
    }
        // A helper method to get the Milestone amount directly
    public decimal getMilestoneAmountValue() {
        SalesOrderInstallments__c installment = getPercentage();
        return installment != null ? installment.InstallmentAmount__c : 0;
    }
    
            // A helper method to get the Milestone__c directly
    public Date getInstalmentDueDate() {
        SalesOrderInstallments__c installment = getPercentage();
        return installment != null ? installment.MilestoneDate__c : NULL;
    }
}