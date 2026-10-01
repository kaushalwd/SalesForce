public class PaymentMilestoneExtentionAutomator implements BusinessProcessAutomation {
    
    public void executeAutomation(BusinessProcessAutomationInput input) {

        Set<Id> bpIds = new Set<Id>();      
        for (Business_Process_Step__c step : input.steps) {
            if (step.Status__c == 'Open' && (step.Name == 'Finance Verifcation' || step.Name == 'Finance Verification')) {
                 bpIds.add(step.Business_Process__c);
            }   
        }
        
        if(!bpIds.isEmpty()){
            List<Business_Process__c> bpList=[select ID,Payment_Extension_Date__c,Sales_Order_Installment__c from Business_Process__c where ID IN :bpIds];
            Map<Id, SalesOrderInstallments__c> installmentsToUpdate = new Map<Id, SalesOrderInstallments__c>();
            Set<Id> installmentIds = new Set<Id>();
            Map<Id, Date> extensionDateByInstallmentId = new Map<Id, Date>();
            for(Business_Process__c bp : bpList){
                if(bp.Sales_Order_Installment__c != null){
                    SalesOrderInstallments__c salesOrderInstallment=new SalesOrderInstallments__c();
                    salesOrderInstallment.ID=bp.Sales_Order_Installment__c;
                    salesOrderInstallment.ExtensionDate__c=bp.Payment_Extension_Date__c;
                    salesOrderInstallment.MilestoneDate__c=bp.Payment_Extension_Date__c;
                    installmentsToUpdate.put(salesOrderInstallment.ID, salesOrderInstallment);
                    installmentIds.add(bp.Sales_Order_Installment__c);
                    extensionDateByInstallmentId.put(bp.Sales_Order_Installment__c, bp.Payment_Extension_Date__c);
                }
            }
            if(!installmentsToUpdate.isEmpty()){
                update installmentsToUpdate.values();
            }
            if(!installmentIds.isEmpty()){
                List<Invoice__c> invoicesToUpdate = new List<Invoice__c>();
                for(Invoice__c inv : [select ID, InvoiceDate__c, SalesOrderInstallment__c from Invoice__c where SalesOrderInstallment__c IN :installmentIds and InvoiceStatus__c!='Cancelled']){
                    Invoice__c invoiceToUpdate = new Invoice__c();
                    invoiceToUpdate.ID = inv.ID;
                    invoiceToUpdate.InvoiceDate__c = extensionDateByInstallmentId.get(inv.SalesOrderInstallment__c);
                    invoicesToUpdate.add(invoiceToUpdate);
                }
                if(!invoicesToUpdate.isEmpty()){
                    update invoicesToUpdate;
                }
            }
        }
        }
        
          
}