/**********************************************************************************************************************
* Name               : ReceiptDocController                                                        
* Description        : This class is used to send the cheques ack to customers
* Usage              : visualsource page controller class
* Created By         : Suresh                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh         			    04 01 2025     Initial Draft       
******************************************************************************************************************/
public class ReceiptDocController {
    public Receipt__c rec {get; set;}
    
    public ReceiptDocController() {
        Id recId = ApexPages.currentPage().getParameters().get('id');
        rec = [SELECT Name, CreatedDate, ProjectName__c, UnitNumber__c, SalesOrder__r.PrimaryContact__r.Name, 
               SalesOrder__r.PrimaryContact__r.MobilePhone, SalesOrder__r.PrimaryContact__r.Email, 
               SalesOrder__r.VirtualAccount__r.VirtualAccountNumber__c, Modeofpayment__c, TransactionNumber__c, 
               TransactionDate__c, Bank__c, Receipt_Amount__c, TotalAmount__c, EBS_Clearing_Date__c, Totalamountinwords__c,
               ReceiptDate__c from Receipt__c WHERE Id = :recId LIMIT 1];
    }
}