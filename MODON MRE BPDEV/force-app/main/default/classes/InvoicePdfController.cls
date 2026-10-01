public with sharing class InvoicePdfController {
    public Invoice__c invoice {get;set;}

    public InvoicePdfController() {
        String invoiceId = ApexPages.currentPage().getParameters().get('invoiceId');
        invoice = [SELECT Id, Name, InvoiceStatus__c FROM Invoice__c WHERE Id = :invoiceId];Apexpages.currentPage().getHeaders().put('content-disposition', 'inline; filename=test');
    }
}