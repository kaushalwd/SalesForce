/**
* @description Queueable wrapper that sends newly created Advance Tax Invoice__c records
*               (Transaction_Type__c = 'Advance Tax') to Oracle Fusion via
*               OIC_ManageAdvanceTaxInvoiceController.createAdvanceTaxInvoice. Enqueued from
*               AdvanceTaxInvoiceBatch after the Advance Tax Invoices are inserted.
*
* @author      Karunakar Pulkam
* @created     08-25-2026
* ------------------------------------------------------------------------------------
* Version  Author      			Date          Comment
* 1.0      Karunakar Pulkam    08-25-2026    Initial Draft
************************************************************************************/
public class AdvanceTaxInvoiceQueueable implements Queueable, Database.AllowsCallouts {

    private Set<String> invoiceIds;

    public AdvanceTaxInvoiceQueueable(Set<Id> invoiceIds) {
        this.invoiceIds = new Set<String>();
        if (invoiceIds != null) {
            for (Id invId : invoiceIds) {
                this.invoiceIds.add(invId);
            }
        }
    }

    public void execute(QueueableContext context) {
        if (invoiceIds == null || invoiceIds.isEmpty()) {
            return;
        }
        OIC_ManageAdvanceTaxInvoiceController.createAdvanceTaxInvoice(invoiceIds);
    }
}