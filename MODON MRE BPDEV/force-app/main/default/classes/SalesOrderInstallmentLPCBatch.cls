/**
* @description       : 
* @author            : Krishna Chaitanya
* @group             : 
* @last modified on  : 08-11-2025
* @last modified by  : Krishna Chaitanya
**/
global class SalesOrderInstallmentLPCBatch implements Database.Batchable<SObject>, Database.Stateful {
    
    private Id penaltyRecordTypeId;
    private Map<Integer, Decimal> lpcSlabs = new Map<Integer, Decimal>();
    private List<Id> providedInstallmentIds;
    
    private List<SalesOrderInstallments__c> installmentsToUpdate = new List<SalesOrderInstallments__c>();
    
    // Constructor with optional Id list
    global SalesOrderInstallmentLPCBatch(List<Id> installmentIds) {
        this.providedInstallmentIds = installmentIds;
    }
    
    global SalesOrderInstallmentLPCBatch() {
        this.providedInstallmentIds = new List<Id>(); // default empty
    }
    
    global Database.QueryLocator start(Database.BatchableContext bc) {
        // Load LPC slabs
        for (LPC_Calculation__mdt meta : [SELECT Days_Due__c, Late_Percentage__c FROM LPC_Calculation__mdt]) {
            if (meta.Days_Due__c != null && meta.Late_Percentage__c != null) {
                lpcSlabs.put((Integer)meta.Days_Due__c, meta.Late_Percentage__c);
            }
        }
        
        // Fetch record type
        penaltyRecordTypeId = Schema.SObjectType.Charge__c.getRecordTypeInfosByName().get('Late Payment').getRecordTypeId();
        
        // Use inline SOQL with bind variable for Id filter
        if (providedInstallmentIds != null && !providedInstallmentIds.isEmpty()) {
            return Database.getQueryLocator([
                SELECT Id, InstallmentAmount__c, Over_Due_Days__c, MilestoneDate__c, PaymentStatus__c,Name,
                LPC_Charge__c, LPCActive__c, SalesOrder__c, SalesOrder__r.CustomerAccount__c, 
                ExtensionDate__c, Milestone_Installment__c, Milestone_Installment__r.ConfirmedMilestoneDate__c
                FROM SalesOrderInstallments__c
                WHERE PaymentStatus__c NOT IN ('Paid', 'Cancelled')
                AND MilestoneDate__c < TODAY
                AND MilestoneDate__c != null
                AND InstallmentAmount__c != null
                AND Over_Due_Days__c != null
                AND Exclude_LPC__c = false
                AND Id IN :providedInstallmentIds
            ]);
        } else {
            return Database.getQueryLocator([
                SELECT Id, InstallmentAmount__c, Over_Due_Days__c, MilestoneDate__c, PaymentStatus__c,Name,
                LPC_Charge__c, LPCActive__c, SalesOrder__c, SalesOrder__r.CustomerAccount__c, 
                ExtensionDate__c, Milestone_Installment__c, Milestone_Installment__r.ConfirmedMilestoneDate__c
                FROM SalesOrderInstallments__c
                WHERE PaymentStatus__c NOT IN ('Paid', 'Cancelled')
                AND MilestoneDate__c < TODAY
                AND MilestoneDate__c != null
                AND InstallmentAmount__c != null
                AND Exclude_LPC__c = false
                AND Over_Due_Days__c != null
            ]);
        }
    }
    
    
global void execute(Database.BatchableContext bc, List<SObject> scope) {
    Set<Id> soiIds = new Set<Id>();
    for (SalesOrderInstallments__c soi : (List<SalesOrderInstallments__c>) scope) {
        soiIds.add(soi.Id);
    }

    // Load Invoices by Installment
    Map<Id, Invoice__c> soiToInvoiceMap = new Map<Id, Invoice__c>();
    for (Invoice__c inv : [
        SELECT Id, InvoiceBalance__c, SalesOrderInstallment__c
        FROM Invoice__c
        WHERE SalesOrderInstallment__c IN :soiIds
    ]) {
        if (inv.SalesOrderInstallment__c != null) {
            soiToInvoiceMap.put(inv.SalesOrderInstallment__c, inv);
        }
    }

    // Load Charges (Late Payment) by SOI
    Map<Id, Charge__c> soiToChargeMap = new Map<Id, Charge__c>();
    for (Charge__c charge : [
        SELECT Id, SalesOrderInstallment__c, Amount__c, RecordTypeId,Sales_Order__c
        FROM Charge__c
        WHERE SalesOrderInstallment__c IN :soiIds
        AND RecordTypeId = :penaltyRecordTypeId
    ]) {
        if (charge.SalesOrderInstallment__c != null && !soiToChargeMap.containsKey(charge.SalesOrderInstallment__c)) {
            soiToChargeMap.put(charge.SalesOrderInstallment__c, charge);
        }
    }

    // Load SalesOrder accounts
    Set<Id> soIds = new Set<Id>();
    for (SalesOrderInstallments__c soi : (List<SalesOrderInstallments__c>) scope) {
        if (soi.SalesOrder__c != null) {
            soIds.add(soi.SalesOrder__c);
        }
    }

    Map<Id, SalesOrder__c> soMap = new Map<Id, SalesOrder__c>([
        SELECT Id, CustomerAccount__c FROM SalesOrder__c WHERE Id IN :soIds
    ]);

    List<Charge__c> chargesToInsert = new List<Charge__c>();
    List<Charge__c> chargesToUpdate = new List<Charge__c>();
    List<Invoice__c> invoicesToInsert = new List<Invoice__c>();

    for (SalesOrderInstallments__c soi : (List<SalesOrderInstallments__c>) scope) {
     
        //if (soi.ExtensionDate__c == null || soi.ExtensionDate__c < Date.today()) {
            Integer daysOverdue;
            if (soi.Milestone_Installment__c != null && soi.Milestone_Installment__r.ConfirmedMilestoneDate__c != null) {
                daysOverdue = soi.Milestone_Installment__r.ConfirmedMilestoneDate__c.daysBetween(Date.today());
            } else {
                daysOverdue = (Integer)soi.Over_Due_Days__c;
            }
            if (!lpcSlabs.containsKey(daysOverdue)) continue;

            Decimal lpcPercent = lpcSlabs.get(daysOverdue);
            Decimal baseAmount = 0;

            if (soiToInvoiceMap.containsKey(soi.Id)) {
                Invoice__c inv = soiToInvoiceMap.get(soi.Id);
                if (inv.InvoiceBalance__c != null) {
                    baseAmount = inv.InvoiceBalance__c;
                }
            }

            Decimal prevLPC = soi.LPC_Charge__c != null ? soi.LPC_Charge__c : 0;
            Decimal addLPC = baseAmount * (lpcPercent / 100);
            Decimal totalLPC = prevLPC + addLPC;

            soi.LatestLPCChargedAmt__c = addLPC;
            soi.LastLPCChargedDate__c = Date.today();
            soi.LPC_Charge__c = totalLPC.setScale(2);
            soi.LPCActive__c = true;
            installmentsToUpdate.add(soi);

            // CASE 1: 30 days – create Charge if not already
            if (lpcSlabs.containsKey(daysOverdue) && !soiToChargeMap.containsKey(soi.Id)) {
                Charge__c newCharge = new Charge__c(
                    Name = soi.Name+' - '+'LPC',
                    Amount__c = totalLPC.setScale(2),
                    VAT_Amount__c = 0,
                    PaymentStatus__c = 'Not Paid',
                    Account__c= soMap.get(soi.SalesOrder__c).CustomerAccount__c,
                    RecordTypeId = penaltyRecordTypeId,
                    Sales_Order__c = soi.SalesOrder__c,
                    SalesOrderInstallment__c = soi.Id
                );
                chargesToInsert.add(newCharge);
            }

            // CASE 2: Any other day (not 30 or 360) – update existing charge
            else if (daysOverdue != 360 && soiToChargeMap.containsKey(soi.Id)) {
                Charge__c existingCharge = soiToChargeMap.get(soi.Id);
                existingCharge.Amount__c = totalLPC.setScale(2);
                chargesToUpdate.add(existingCharge);
            }

            // CASE 3: 360 days – create Invoice from existing charge
            else if (daysOverdue == 360 && soiToChargeMap.containsKey(soi.Id)) {
                soi.LPCActive__c = false; // deactivate LPC

                Charge__c charge = soiToChargeMap.get(soi.Id);
                Id accId = soMap.containsKey(charge.Sales_Order__c)
                    ? soMap.get(charge.Sales_Order__c).CustomerAccount__c
                    : null;

                Invoice__c invoice = new Invoice__c(
                    Sales_Order__c = charge.Sales_Order__c,
                    Charge__c = charge.Id,
                    Account__c = accId,
                    InvoiceAmount__c = charge.Amount__c,
                    SalesOrderInstallment__c = soi.Id
                );
                invoicesToInsert.add(invoice);
            }
        
    }

    if (!installmentsToUpdate.isEmpty()) update installmentsToUpdate;
    if (!chargesToInsert.isEmpty()) insert chargesToInsert;
    if (!chargesToUpdate.isEmpty()) update chargesToUpdate;
    if (!invoicesToInsert.isEmpty()) insert invoicesToInsert;
}

    
    global void finish(Database.BatchableContext bc) {
        // Optional logging
    }
}