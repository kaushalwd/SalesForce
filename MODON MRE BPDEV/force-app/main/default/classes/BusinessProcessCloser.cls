/**
 * Closes Business Process records when their linked invoices are marked as Paid.
 * Triggered from Invoice__c where InvoiceStatus__c = 'Paid'.
 */
public class BusinessProcessCloser {

    public static void closeOnInvoicePaid(List<Invoice__c> paidInvoices) {

        // Extract installment Ids from paid invoices (skip nulls)
        Set<Id> installmentIds = new Set<Id>();
        for (Invoice__c inv : paidInvoices) {
            if (inv.SalesOrderInstallment__c != null) {
                installmentIds.add(inv.SalesOrderInstallment__c);
            }
        }

        if (installmentIds.isEmpty()) return;

        // Find open Business Processes linked to those installments
        List<Business_Process__c> bpToClose = [
            SELECT Id, Status__c, Current_Business_Process_Step__c
            FROM Business_Process__c
            WHERE Sales_Order_Installment__c IN :installmentIds
			and Process_Flow__r.Name='Default And Termination'
            AND Status__c != 'Completed'
        ];

        if (bpToClose.isEmpty()) return;


    List<Business_Process_Step__c> bpSteps=new List<Business_Process_Step__c>();
        // Mark all qualifying Business Processes as Closed
        for (Business_Process__c bp : bpToClose) {
           // bp.Status__c = 'Completed';
           Business_Process_Step__c step=new Business_Process_Step__c();
           step.Id=bp.Current_Business_Process_Step__c;
           step.Is_Process_End__c=true;
		   step.Status__c='Completed';
           if(step.Id !=null)
           bpSteps.add(step);
        }
        if(bpSteps.size()>0 && ! Test.isRunningTest())
        update bpSteps;
    }
}