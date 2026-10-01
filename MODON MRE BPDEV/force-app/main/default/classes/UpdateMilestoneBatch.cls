global without sharing class UpdateMilestoneBatch implements Database.Batchable<sObject>,Database.AllowsCallouts{
    
    Set<Id> setUnitMilestioneId = new Set<Id>();
    Set<Id> trigerredMilestone = new Set<Id>();
    string actionType ='';
    
    public UpdateMilestoneBatch(Set<Id> setUnitMilestioneId,string actionTypeFrom){
        this.setUnitMilestioneId = setUnitMilestioneId;
        system.debug('------setUnitMilestioneId -------------'+setUnitMilestioneId );
        this.actionType = actionTypeFrom;
    }
    
    global Database.QueryLocator start(Database.BatchableContext BC){
        system.debug('------start-------------'+setUnitMilestioneId );
        return Database.getQueryLocator([
            SELECT id, Milestone_Installment__r.Milestone_Due_Date__c, Milestone__c, MilestoneDate__c, Is_Milestone_Confirmed__c, Milestone_Installment__r.ConfirmedMilestoneDate__c 
            FROM SalesOrderInstallments__c 
            WHERE Milestone_Installment__c IN :setUnitMilestioneId 
              AND SalesOrder__r.Status__c = 'Completed' 
              AND Milestone_Installment__c != null
        ]);
    }
    
    global void execute(Database.BatchableContext BC, List<SalesOrderInstallments__c> scope){
        system.debug('----222222--scope-------------'+scope);
        try{
            List<SalesOrderInstallments__c> updateInstallments = new List<SalesOrderInstallments__c>();
            List<Invoice__c> updateInvoices = new List<Invoice__c>();
            
            Set<Id> installmentIds = new Set<Id>();
            for (SalesOrderInstallments__c soi : scope) {
                installmentIds.add(soi.Id);
            }
            
            // Fetch invoices related to these installments
            Map<Id, List<Invoice__c>> invoiceMap = new Map<Id, List<Invoice__c>>();
            for (Invoice__c inv : [ SELECT Id, SalesOrderInstallment__c, InvoiceDate__c, Is_Milestone_Confirmed__c FROM Invoice__c  WHERE
                                   SalesOrderInstallment__c IN :installmentIds]) {
                                       if (!invoiceMap.containsKey(inv.SalesOrderInstallment__c)) {
                                           invoiceMap.put(inv.SalesOrderInstallment__c, new List<Invoice__c>());
                                       }
                                       invoiceMap.get(inv.SalesOrderInstallment__c).add(inv);
                                   }
            
            for(SalesOrderInstallments__c installment : scope)
            {
                // if(actionType == 'cofirmed milestone' && installment.Milestone_Installment__r.ConfirmedMilestoneDate__c != installment.MilestoneDate__c){
                if(actionType == 'cofirmed milestone' ){
                    system.debug('confirmed Milestone');
                    Date confirmedDate = installment.Milestone_Installment__r.ConfirmedMilestoneDate__c;
                    Date existingDate  = installment.MilestoneDate__c;
                    // updateInstallments.add(new SalesOrderInstallments__c(Id = installment.Id, MilestoneDate__c = confirmedDate,Is_Milestone_Confirmed__c = true)); 
                    SalesOrderInstallments__c soiUpdate = new SalesOrderInstallments__c(Id = installment.Id,Is_Milestone_Confirmed__c = true);
                    
                    //  Update date ONLY if existing date is not greater than confirmed date
                    if (confirmedDate != null && existingDate <= confirmedDate) {
                        soiUpdate.MilestoneDate__c = confirmedDate;
                    }
                    
                    updateInstallments.add(soiUpdate);
                    
                    if (invoiceMap.containsKey(installment.Id)) {
                        for (Invoice__c inv : invoiceMap.get(installment.Id)) {
                            
                            Invoice__c invUpdate = new Invoice__c( Id = inv.Id,Is_Milestone_Confirmed__c = true );
                            
                            // Update invoice date only if milestone date was updated
                            if (confirmedDate != null && existingDate <= confirmedDate) {
                                invUpdate.InvoiceDate__c = confirmedDate;
                            }
                            
                            updateInvoices.add(invUpdate);
                        }
                    }
                    
                    /* if (invoiceMap.containsKey(installment.Id)) {
for (Invoice__c inv : invoiceMap.get(installment.Id)) {
updateInvoices.add(new Invoice__c(Id = inv.Id,InvoiceDate__c = confirmedDate,Is_Milestone_Confirmed__c = true));
}
}*/
                }
                
                if(actionType == 'milestone due date' && installment.Milestone_Installment__r.Milestone_Due_Date__c != installment.MilestoneDate__c){
                    system.debug('milestone Milestone');
                    Date dueDate = installment.Milestone_Installment__r.Milestone_Due_Date__c;
                    Date existingDate  = installment.MilestoneDate__c;
                    
                    if ( dueDate != null && existingDate <= dueDate) {
                        updateInstallments.add( new SalesOrderInstallments__c(Id = installment.Id,MilestoneDate__c = dueDate));
                        
                        //  Invoice update only when installment date is updated
                        if (invoiceMap.containsKey(installment.Id)) {
                            for (Invoice__c inv : invoiceMap.get(installment.Id)) {
                                updateInvoices.add(new Invoice__c(Id = inv.Id,InvoiceDate__c = dueDate));
                            }
                        }
                    }
                    /* updateInstallments.add(new SalesOrderInstallments__c(Id = installment.Id, MilestoneDate__c = dueDate )); 
if (invoiceMap.containsKey(installment.Id)) {
for (Invoice__c inv : invoiceMap.get(installment.Id)) {
updateInvoices.add(new Invoice__c(Id = inv.Id, InvoiceDate__c = dueDate));
}
}*/
                }
                
                
            }
            system.debug('----1111--updateInstallments-------------'+updateInstallments);
            if (!updateInstallments.isEmpty()) {
                update updateInstallments;
            }
            system.debug('----222222--updateInstallments-------------'+updateInstallments);
            if (!updateInvoices.isEmpty()) {
                update updateInvoices;
            }
            
        }catch (DmlException e){
            LoggerService.save(LoggerService.createApexLog(e,'Update Milestone Batch','UpdateMilestoneBatch','execute'));
        }
        catch(Exception ex){
            LoggerService.save(LoggerService.createApexLog(ex,'Update Milestone Batch','UpdateMilestoneBatch','execute'));
        }
    }  
    
    // Finish Method
    global void finish(Database.BatchableContext BC){
        
    }
    
    
}