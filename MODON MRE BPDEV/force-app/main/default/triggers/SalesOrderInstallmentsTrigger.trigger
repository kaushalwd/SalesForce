trigger SalesOrderInstallmentsTrigger on SalesOrderInstallments__c (after insert, after update, after delete, after undelete) {
    
    Set<Id> changedInstallmentIds = new Set<Id>();
 
    if (Trigger.isInsert || Trigger.isUndelete) {
        for (SalesOrderInstallments__c rec : Trigger.new) {
            changedInstallmentIds.add(rec.Id);
        }
    }
 
    if (Trigger.isUpdate) {for (Integer i = 0; i < Trigger.new.size(); i++) {
        SalesOrderInstallments__c newRec = Trigger.new[i];SalesOrderInstallments__c oldRec = Trigger.old[i];
            if (newRec.PaymentStatus__c != oldRec.PaymentStatus__c) {changedInstallmentIds.add(newRec.Id);}
        }
    }
 
    if (Trigger.isDelete) { for (SalesOrderInstallments__c rec : Trigger.old) { changedInstallmentIds.add(rec.Id);}}
 
    if (!changedInstallmentIds.isEmpty()) {
        SalesOrderCollectionsServiceController.recalcFromInstallments(changedInstallmentIds);
    }
}