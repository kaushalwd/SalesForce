/**
 * @description       : 
 * @author            : Krishna Chaitanya
 * @group             : 
 * @last modified on  : 08-12-2025
 * @last modified by  : Krishna Chaitanya
**/
public with sharing class LPCWaiverExecution {

    @AuraEnabled
    public static String updateLPCCharge(Id serviceRequestId) {
        if (serviceRequestId == null) return 'Invalid Service Request Id';

        try {
            ServiceRequest__c sr = [
                SELECT Id, Waiver_Percentage__c, LPC_Amount__c, LPC_Waived_Amount__c, Charge__c,
                       Charge__r.SalesOrderInstallment__c, Charge__r.Account__c
                FROM ServiceRequest__c
                WHERE Id = :serviceRequestId
                LIMIT 1
            ];
SalesOrderInstallments__c soiupdate = new SalesOrderInstallments__c(
                Id = sr.Charge__r.SalesOrderInstallment__c,
                //LPC_Charge__c = sr.LPC_Amount__c.setScale(2),
                LPCActive__c = false, // Deactivate LPC
                Exclude_LPC__c = true // Exclude from future LPC calculations
            );
            update soiupdate;
            // Update Charge amount
            if (sr.Charge__c != null) {
                update new Charge__c(Id = sr.Charge__c, Actual_Amount__c = sr.LPC_Amount__c,Amount__c = sr.LPC_Waived_Amount__c);
            }

            // Check existing invoices
            List<Invoice__c> invoices = [
                SELECT Id, InvoiceAmount__c
                FROM Invoice__c
                WHERE Charge__c = :sr.Charge__c
            ];
 
            if (!invoices.isEmpty()) {
                for (Invoice__c inv : invoices) {
                    inv.InvoiceAmount__c = sr.LPC_Waived_Amount__c;
                }
                update invoices;

            } else {
                // No invoices found, create one
                Charge__c charge = [
                    SELECT Id, Sales_Order__c, SalesOrderInstallment__c,SalesOrderInstallment__r.SalesOrder__c, Account__c
                    FROM Charge__c
                    WHERE Id = :sr.Charge__c
                    LIMIT 1
                ];

                Invoice__c newInvoice = new Invoice__c(
                    Sales_Order__c = charge.SalesOrderInstallment__r.SalesOrder__c,
                    Charge__c = charge.Id,
                    Account__c = charge.Account__c,
                    //SalesOrderInstallment__c = charge.SalesOrderInstallment__c,
                    InvoiceAmount__c = sr.LPC_Waived_Amount__c.setScale(2)
                );
                insert newInvoice;
            }
           

            return 'success';

        } catch (Exception ex) {
            System.debug('Error in LPCWaiverExecution.updateLPCCharge: ' + ex.getMessage());
            return 'Error: ' + ex.getMessage();
        }
    }
}