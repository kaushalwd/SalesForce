/**********************************************************************************************************************
* Name               : SalesOrderCollectionsServiceController                                                        
* Description        : This class is used to handle Salesorder Calc from SalesOrderInstallment trigger instances
* Usage              : Called from SalesOrderInstallmentTrigger
* Created By         : AMGS                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0 			Srikrishna.chaitanya.com		 27 Nov 2025	 	Calc changes on SO
******************************************************************************************************************/
public class SalesOrderCollectionsServiceController {
    
    public static void recalcForSalesOrders(Set<Id> salesOrderIds) {
        
        if (Label.SO_Collections_Recalculation != 'true') {
            System.debug('SO Collections recalculation skipped (Label = false)');
            return;
        }
        if (salesOrderIds == null || salesOrderIds.isEmpty()) {
            return;
        }
        Set<Id> validSoIds = new Set<Id>();
        for (SalesOrder__c so : [SELECT Id,Unit__r.Source_Entity__c FROM SalesOrder__c WHERE Id IN :salesOrderIds AND Unit__r.Source_Entity__c != 'Modon - Egypt']) {
            validSoIds.add(so.Id);
        }
        
        if (validSoIds.isEmpty()) {
            return;
        }
        
        //salesOrderIds = validSoIds;
        
        Map<Id, Id> soiToSo = new Map<Id, Id>(); // SOI Id -> SO Id
        for (SalesOrderInstallments__c soi : [SELECT Id, SalesOrder__c FROM SalesOrderInstallments__c WHERE SalesOrder__c IN :validSoIds]) {
            if (soi.SalesOrder__c != null) {
                soiToSo.put(soi.Id, soi.SalesOrder__c);
            }
        }
        if (soiToSo.isEmpty()) {
            return; 
        }
        Set<Id> soiIds = soiToSo.keySet();
        Map<Id, Decimal> soToPaid    = new Map<Id, Decimal>();
        Map<Id, Decimal> soToBalance = new Map<Id, Decimal>();
        for (Invoice__c inv : [SELECT Id,InvoiceAmount__c,InvoiceBalance__c,SalesOrderInstallment__c FROM Invoice__c
                               WHERE SalesOrderInstallment__c IN :soiIds]) {
                                   Id soiId = inv.SalesOrderInstallment__c;
                                   if (soiId == null || !soiToSo.containsKey(soiId)) continue;
                                   Id soId = soiToSo.get(soiId);
                                   if (soId == null) continue;
                                   Decimal amount  = inv.InvoiceAmount__c== null ? 0 : inv.InvoiceAmount__c;
                                   system.debug('amount=========' + amount);
                                   Decimal balance = inv.InvoiceBalance__c == null ? 0 : inv.InvoiceBalance__c;
                                   system.debug('balance=========' + balance);
                                   Decimal paid    = amount - balance; // what has been cleared
                                   system.debug('paid=========' + paid);  
                                   soToPaid.put(soId,    (soToPaid.get(soId)    == null ? 0 : soToPaid.get(soId))    + paid);
                                   soToBalance.put(soId, (soToBalance.get(soId) == null ? 0 : soToBalance.get(soId)) + balance);
                               }
        List<SalesOrder__c> toUpdate = new List<SalesOrder__c>();
        for (SalesOrder__c so : [ SELECT Id, TotalAmount__c FROM SalesOrder__c WHERE Id IN :validSoIds]) {
            Decimal totalAmount      = so.TotalAmount__c == null ? 0 : so.TotalAmount__c;
            Decimal totalPaid        = soToPaid.get(so.Id);
            Decimal totalOutstanding = soToBalance.get(so.Id);
            if (totalPaid == null)        totalPaid = 0;
            if (totalOutstanding == null) totalOutstanding = 0;
            SalesOrder__c upd = new SalesOrder__c(
                Id                            = so.Id,
                Total_Amount_Cleared__c       = totalPaid,
                Future_Collections_Amount__c  = totalOutstanding
            );
            if (totalAmount > 0) {
                upd.Total_Cleared_Percentage__c      = (totalPaid / totalAmount) * 100;
                upd.Future_Collections_Percentage__c = (totalOutstanding / totalAmount) * 100;
            } else {
                upd.Total_Cleared_Percentage__c      = 0;
                upd.Future_Collections_Percentage__c = 0;
            }
            toUpdate.add(upd);
        }
        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }
    
    /*  public class SalesOrderInput {
@InvocableVariable(required=true)
public Id salesOrderId;
}
@InvocableMethod(
label='Recalculate SO Collections'
description='Recalculate Total Amount Cleared and Future Collections for given Sales Orders'
)
public static void recalcFromFlow(List<SalesOrderInput> inputs) {
Set<Id> soIds = new Set<Id>();
for (SalesOrderInput inp : inputs) {
if (inp != null && inp.salesOrderId != null) {
soIds.add(inp.salesOrderId);
}
}
recalcForSalesOrders(soIds);
}*/
    public static void recalcFromInstallments(Set<Id> installmentIds) {
        if (installmentIds == null || installmentIds.isEmpty()) return;
        // Get SOI → SO mapping, but only for the changed installments
        Map<Id, Id> soiToSo = new Map<Id, Id>(); // SOI Id -> SO Id
        Set<Id> soIds = new Set<Id>();
        for (SalesOrderInstallments__c soi : [SELECT Id, SalesOrder__c FROM SalesOrderInstallments__c WHERE Id IN :installmentIds ]) {
            if (soi.SalesOrder__c != null) {
                soiToSo.put(soi.Id, soi.SalesOrder__c);
                soIds.add(soi.SalesOrder__c);
            }
        }
        if (soIds.isEmpty()) {
            return;
        }
        // **Re-use main method – will query all SOIs & Invoices for those SOs**
        recalcForSalesOrders(soIds);
    }
}