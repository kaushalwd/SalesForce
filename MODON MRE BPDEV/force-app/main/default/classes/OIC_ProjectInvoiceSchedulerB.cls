/**********************************************************************************************************************
* Name               : OIC_ProjectInvoiceSchedulerB
* Description        : Schedulable class to pick invoices for a specific Project (from Custom Label).
* Created By         : AMGS
* --------------------------------------------------------------------------------------------------------------------
* Version       Author              Date                Comment
* 1.0           Raghu Gajjela       03-02-2026          Scheduable class.
***********************************************************************************************************************/
global class OIC_ProjectInvoiceSchedulerB implements Schedulable {

    global void execute(SchedulableContext sc) {
        Database.executeBatch(
            new OIC_ProjectInvoiceSyncBatch('InvoicePushQueryB'),
            1
        );
    }

}