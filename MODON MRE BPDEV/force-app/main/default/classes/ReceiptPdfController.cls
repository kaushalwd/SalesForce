/**-------------------------------------------------------------------
 * Description : Controller for Receipt PDF Vf page
 * -------------------------------------------------------------------
 * Version      Author           Date               Comment
 * -------------------------------------------------------------------
 * v1.0         Abdallah Hdaib   15-02-2024         Code Creation
 * -------------------------------------------------------------------
 * Notes: NaN
*/
public with sharing class ReceiptPdfController {

    public Receipt__c receipt {get;set;}

    public ReceiptPdfController() {
        String receiptId = ApexPages.currentPage().getParameters().get('receiptId');
        receipt = [SELECT Id, Name, Status__c, AppliedAmount__c, TotalAmount__c FROM Receipt__c WHERE Id = :receiptId];Apexpages.currentPage().getHeaders().put('content-disposition', 'inline; filename=test');
    }
}