global class InstallmentOverdueReminderBatch  implements Database.Batchable<SObject>{
    
    global Database.QueryLocator start(Database.BatchableContext bc) {
        Date today = Date.today();
        // SOQL hardening: static SOQL with binds (no dynamic string assembly).
        return Database.getQueryLocator([
            SELECT Id, Name, MilestoneDate__c, ExtensionDate__c, Milestone_Installment__c,
                   Milestone_Installment__r.Name, InstallmentAmount__c,
                   Milestone_Installment__r.ConfirmedMilestoneDate__c,
                   SalesOrder__c,
                   SalesOrder__r.CustomerAccount__c,
                   SalesOrder__r.CustomerAccount__r.Id,
                   SalesOrder__r.CustomerAccount__r.IsPersonAccount,
                   SalesOrder__r.CustomerAccount__r.PersonContactId,
                   SalesOrder__r.CustomerAccount__r.PersonEmail
            FROM SalesOrderInstallments__c
            WHERE SalesOrder__r.Status__c = 'Completed'
            AND PaymentStatus__c != 'Cancelled'
            AND PaymentStatus__c != 'Paid'
            AND MilestoneNumber__c != 1
            AND (
                (Milestone_Installment__c != null AND Milestone_Installment__r.ConfirmedMilestoneDate__c <= :today)
                OR
                (Milestone_Installment__c = null AND MilestoneDate__c <= :today)
            )
            AND (ExtensionDate__c = null OR ExtensionDate__c <= :today)
        ]);
    }
    
    
global void execute(Database.BatchableContext bc, List<SObject> scope) {
    System.debug('scope----->'+scope);
    List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
    Map<Integer, Id> overdueDaysToTemplateId = new Map<Integer, Id>();    
    Map<Id, Set<String>> soIdToInstIds = new Map<Id, Set<String>>();
    Set<Id> day30SalesOrderIds = new Set<Id>();
    Set<Id> orgAccountIdsNeedingContacts = new Set<Id>();
    Map<Id, Id> installmentToTargetContact = new Map<Id, Id>();
 Set<Id> salesOrderIds = new Set<Id>();
    
    for (EmailTemplate et : [SELECT Id, DeveloperName FROM EmailTemplate WHERE DeveloperName IN ('Payment_over_due_Reminder_10','Payment_over_due_Reminder_20','Payment_over_due_Reminder')]) 
       
        
        if (et.DeveloperName == 'Payment_over_due_Reminder_10') {
         	
            overdueDaysToTemplateId.put(10, et.Id);

        }else if (et.DeveloperName == 'Payment_over_due_Reminder_20') 
    	{
        	overdueDaysToTemplateId.put(20, et.Id);
        }
    	else if (et.DeveloperName == 'Payment_over_due_Reminder'){ 
            overdueDaysToTemplateId.put(30, et.Id);
        }
        
    System.debug('overdueDaysToTemplateId--->'+overdueDaysToTemplateId);
    for (SalesOrderInstallments__c inst : (List<SalesOrderInstallments__c>) scope) {
       
        Date milestoneDateToUse;
        if (inst.Milestone_Installment__c != null && inst.Milestone_Installment__r.ConfirmedMilestoneDate__c != null) {
            milestoneDateToUse = inst.Milestone_Installment__r.ConfirmedMilestoneDate__c;
        } else if (inst.MilestoneDate__c != null) {
            milestoneDateToUse = inst.MilestoneDate__c;
        } else {
            continue;
        }

       Integer daysOverdue;

            if (inst.ExtensionDate__c != null) {
                if (inst.ExtensionDate__c <= Date.today()) {
                    Integer diff = milestoneDateToUse.daysBetween(Date.today());
                    daysOverdue = (diff >= 30) ? 30 : diff;
                } else {
                    daysOverdue = 0; 
                }
            } else {
                daysOverdue = milestoneDateToUse.daysBetween(Date.today());
            }
        
        System.debug('daysOverdue->'+daysOverdue);

        if (overdueDaysToTemplateId.containsKey(daysOverdue)) {
            if (inst.SalesOrder__r != null && inst.SalesOrder__r.CustomerAccount__r != null) {
                Account acc = inst.SalesOrder__r.CustomerAccount__r;
                if (acc.IsPersonAccount && acc.PersonContactId != null) {
                    installmentToTargetContact.put(inst.Id, acc.PersonContactId);
                } else {
                    orgAccountIdsNeedingContacts.add(acc.Id);
                }
            }
        }

        if ((daysOverdue == 30 && inst.SalesOrder__c != null) || (inst.ExtensionDate__c != null && inst.ExtensionDate__c < Date.today() && daysOverdue >= 30)) {
            day30SalesOrderIds.add(inst.SalesOrder__c);
       
            if (!soIdToInstIds.containsKey(inst.SalesOrder__c)) {
                soIdToInstIds.put(inst.SalesOrder__c, new Set<String>());
            }
            soIdToInstIds.get(inst.SalesOrder__c).add(inst.Name);
        }
    }

    
    
    
    if (!orgAccountIdsNeedingContacts.isEmpty()) {
        Map<Id, Id> orgAccountToContact = new Map<Id, Id>();
        for (Contact c : [SELECT Id, AccountId FROM Contact WHERE AccountId IN :orgAccountIdsNeedingContacts AND Is_Active__c = TRUE AND Email != null]) {
            if (!orgAccountToContact.containsKey(c.AccountId)) {
                orgAccountToContact.put(c.AccountId, c.Id);
            }
        }

        for (SalesOrderInstallments__c inst : (List<SalesOrderInstallments__c>) scope) {
            if (inst.SalesOrder__r != null && inst.SalesOrder__r.CustomerAccount__r != null) {
                Id accId = inst.SalesOrder__r.CustomerAccount__r.Id;
                if (orgAccountToContact.containsKey(accId)) {
                    installmentToTargetContact.put(inst.Id, orgAccountToContact.get(accId));
                }
            }
        }
    }

    for (SalesOrderInstallments__c inst : (List<SalesOrderInstallments__c>) scope) {	
        Date milestoneDateToUse;
        if (inst.Milestone_Installment__c != null && inst.Milestone_Installment__r.ConfirmedMilestoneDate__c != null) {
            milestoneDateToUse = inst.Milestone_Installment__r.ConfirmedMilestoneDate__c;
        } else if (inst.MilestoneDate__c != null) {
            milestoneDateToUse = inst.MilestoneDate__c;
        } else {
            continue;
        }

        Integer daysOverdue = milestoneDateToUse.daysBetween(Date.today());
        System.debug('daysOverdue---->'+daysOverdue+inst.ExtensionDate__c);
        if (daysOverdue < 10) continue;

        Integer bucket;
        if(inst.ExtensionDate__c == null){
                if (daysOverdue == 10){
                   bucket = 10; 
                } 
                else if (daysOverdue == 20) {
                    bucket = 20;
                }
        }
        else if ((inst.ExtensionDate__c != null && inst.ExtensionDate__c < Date.today() && daysOverdue >= 30) || daysOverdue >= 30) {
            System.debug('bucket----'+bucket);
            bucket = 30;
        }
        else continue;
 System.debug('bucket----->'+bucket);
        Id templateId = overdueDaysToTemplateId.get(bucket);
        if (templateId == null) continue;

        System.debug('daysOverdue--->'+daysOverdue);
        if (overdueDaysToTemplateId.containsKey(bucket) && installmentToTargetContact.containsKey(inst.Id)) {
             System.debug('daysOverdue--->'+daysOverdue);
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setTargetObjectId(installmentToTargetContact.get(inst.Id));
            mail.setWhatId(inst.Id);
            mail.setTemplateId(templateId);
            mail.setSaveAsActivity(true);
            emails.add(mail);
        }
    }

    if (!emails.isEmpty()) {
        Messaging.sendEmail(emails);
    }

   
    if (!day30SalesOrderIds.isEmpty()) {
        List<SalesOrder__c> salesOrdersToCreateSR = [SELECT Id, Name, CustomerAccount__c, Unit__c, Opportunity__c FROM SalesOrder__c WHERE Id IN :day30SalesOrderIds];
        System.debug('salesOrdersToCreateSR--'+salesOrdersToCreateSR);
        for (SalesOrder__c so : salesOrdersToCreateSR) {
            if (so.Id != null) {
                salesOrderIds.add(so.Id);
            }
        }

        String creationReason = label.SRSalesOrderInstOverdue;
        if (!salesOrdersToCreateSR.isEmpty()) {
            DefaultSRContrroler.createDefaultSRForSalesOrders(salesOrdersToCreateSR, creationReason, soIdToInstIds);
            DefaultSRContrroler.updateOutstandingAmountForSalesOrders(salesOrderIds, scope);
        }
    }
}

    global void finish(Database.BatchableContext bc) {
        // Optional: Add logging or notification
    }
}