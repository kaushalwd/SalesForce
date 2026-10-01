/**
* @description       : SR Payment Readiness (Milestone-based SOI update)
* @author            : Krishna Chaitanya
* @last modified on  : 02-19-2026
* @last modified by  : Krishna Chaitanya
**/
public with sharing class SRPaymentReadinessController {

    public class SoiRow {
        @AuraEnabled public Id soiId { get; set; }
        @AuraEnabled public String soiName { get; set; }

        @AuraEnabled public Id milestoneId { get; set; }
        @AuraEnabled public String milestoneName { get; set; }
        @AuraEnabled public String salesOrderName { get; set; }
        @AuraEnabled public String unitName {get; set;}
        @AuraEnabled public String customerName { get; set; }
        @AuraEnabled public Decimal amount { get; set; }
        @AuraEnabled public Date dueDate { get; set; }
        @AuraEnabled public String PaymentStatus { get; set; }

        @AuraEnabled public String readiness { get; set; } // picklist value (Yes/No) or null
        @AuraEnabled public String comment { get; set; }
        @AuraEnabled public Boolean hasBusinessProcess { get; set; } // true when Payment_Confirmation_Process__c is populated
        @AuraEnabled public Id businessProcessId { get; set; }
        @AuraEnabled public String businessProcessName { get; set; }
        @AuraEnabled public Boolean defaultSR {get;set;}
            @AuraEnabled public String defaultComments {get;set;}  
            @AuraEnabled public String modeOfPayment { get; set; }
@AuraEnabled public Decimal appliedAmount { get; set; }
    }

    public class SrContext {
        @AuraEnabled public Id milestoneId { get; set; }
        @AuraEnabled public String businessProcessType { get; set; }
    }

    @AuraEnabled(cacheable=true)
    public static SrContext getServiceRequestContext(Id serviceRequestId) {
        if (serviceRequestId == null) return null;

        Business_Process__c sr = [
            SELECT Id, Milestone__c, Type__c
            FROM Business_Process__c
            WHERE Id = :serviceRequestId
            LIMIT 1
        ];

        SrContext ctx = new SrContext();
        ctx.milestoneId = sr.Milestone__c;
        ctx.businessProcessType = sr.Type__c;
        return ctx;
    }

    // Phase__c of the Business Process, or null when there is no BP or it has no Phase.
    private static Id getBusinessProcessPhaseId(Id businessProcessId) {
        if (businessProcessId == null) {
            return null;
        }
        List<Business_Process__c> bps = [
            SELECT Phase__c
            FROM Business_Process__c
            WHERE Id = :businessProcessId
            LIMIT 1
        ];
        return bps.isEmpty() ? null : bps[0].Phase__c;
    }

    @AuraEnabled(cacheable=true)
    public static Id getServiceRequestMilestone(Id serviceRequestId) {
        SrContext ctx = getServiceRequestContext(serviceRequestId);
        return ctx != null ? ctx.milestoneId : null;
    }

    @AuraEnabled(cacheable=true)
    public static List<SoiRow> getInstallmentsByMilestone(Id milestoneId, Id businessProcessId) {
        if (milestoneId == null) return new List<SoiRow>();
    List<String> soStatuses = System.Label.Sales_Order_Status_Filter.split(',');
        for(Integer i=0;i<soStatuses.size();i++){
        soStatuses[i] = soStatuses[i].trim();
    }

        if (!Schema.sObjectType.SalesOrderInstallments__c.isAccessible()) {
           // throw new AuraHandledException('You do not have permission to access Sales Order Installments.');
        }

        Set<Id> paymentInstallmentIds = new Set<Id>();
        for (Milestone__c ms : [SELECT Id, (SELECT Id FROM Payment_Installments__r) FROM Milestone__c WHERE Id = :milestoneId]) {
            for (PaymentInstallements__c pi : ms.Payment_Installments__r) {
                paymentInstallmentIds.add(pi.Id);
            }
        }

        // Only units in the Business Process's Phase
        Id phaseId = getBusinessProcessPhaseId(businessProcessId);

        String soiQuery = System.Label.SR_Payment_Readiness_SOI_Query;
        List<SalesOrderInstallments__c> sois = Database.query(soiQuery);
        Set<Id> soiIds = new Set<Id>();

for (SalesOrderInstallments__c soi : sois) {
soiIds.add(soi.Id);
}
        
Map<Id, Receipt__c> receiptMap = new Map<Id, Receipt__c>();

for (Receipt__c rec : [SELECT Id,SalesOrderInstallment__c,Status__c,Modeofpayment__c,AppliedAmount__c
FROM Receipt__c WHERE SalesOrderInstallment__c IN :soiIds]) {
receiptMap.put(rec.SalesOrderInstallment__c, rec);
}

        List<SoiRow> rows = new List<SoiRow>();
        for (SalesOrderInstallments__c soi : sois) {
            SoiRow r = new SoiRow();
            r.soiId = soi.Id;
            r.soiName = soi.Name;
            r.milestoneId = soi.Milestone_Installment__c;
            r.milestoneName = (soi.Milestone_Installment__r != null) ? soi.Milestone_Installment__r.Name : null;
            r.salesOrderName = (soi.SalesOrder__r != null) ? soi.SalesOrder__r.Name : null;
            r.unitName = (soi.SalesOrder__r != null) ? soi.SalesOrder__r.Unit__r.name : null;
            r.customerName = (soi.SalesOrder__r != null && soi.SalesOrder__r.CustomerAccount__r.Name != null) ? 
            soi.SalesOrder__r.CustomerAccount__r.name : null;
            r.amount = soi.InstallmentAmount__c;
            r.dueDate = soi.MilestoneDate__c;
            r.readiness = soi.Payment_Readiness__c;
            r.comment = soi.Payment_Readiness_Comments__c;
            r.hasBusinessProcess = soi.Payment_Confirmation_Process__c != null;
            r.businessProcessId = soi.Payment_Confirmation_Process__c;
            r.businessProcessName = (soi.Payment_Confirmation_Process__r != null) ? soi.Payment_Confirmation_Process__r.Name : null;
            Receipt__c rec =
    receiptMap.get(soi.Id);

if (rec != null) {
    r.modeOfPayment = rec.Modeofpayment__c;
    r.appliedAmount =  rec.AppliedAmount__c;
}
else if (soi.SalesOrder__r != null && soi.SalesOrder__r.Direct_Debit_Request__c != null) {
    r.modeOfPayment ='Direct Debit';
}
else {
    r.modeOfPayment = '';
}
            rows.add(r);
        }
        return rows;
    }

// Plain save: writes Payment_Readiness__c / Payment_Readiness_Comments__c as given,
// no business validation. Does NOT create any Business Process.
@AuraEnabled
public static void saveReadiness(Id serviceRequestId, List<SoiRow> updates) {
    if (serviceRequestId == null) {
        throw new AuraHandledException('Service Request Id is required.');
    }
    if (updates == null || updates.isEmpty()) return;

    for (SoiRow row : updates) {
        if (row != null && row.readiness == 'No' && String.isBlank(row.comment)) {
            throw new AuraHandledException('Comment is mandatory for installment(s) marked "No".');
        }
    }

    if (!Schema.sObjectType.SalesOrderInstallments__c.isUpdateable()) {
        throw new AuraHandledException('You do not have permission to update Sales Order Installments.');
    }

    Boolean readinessUpdatable = Schema.sObjectType.SalesOrderInstallments__c.fields.Payment_Readiness__c.isUpdateable();
    Boolean commentsUpdatable  = Schema.sObjectType.SalesOrderInstallments__c.fields.Payment_Readiness_Comments__c.isUpdateable();

    if (!readinessUpdatable && !commentsUpdatable) {
        throw new AuraHandledException('You do not have permission to update Payment Readiness fields.');
    }

    Set<Id> soiIds = new Set<Id>();
    for (SoiRow row : updates) {
        if (row != null && row.soiId != null) soiIds.add(row.soiId);
    }

    // Once an installment has a Payment_Confirmation_Process__c, its readiness/comments are locked.
    Set<Id> lockedSoiIds = new Set<Id>();
    for (SalesOrderInstallments__c soi : [SELECT Id FROM SalesOrderInstallments__c WHERE Id IN :soiIds AND Payment_Confirmation_Process__c != null]) {
        lockedSoiIds.add(soi.Id);
    }

    Map<Id, SalesOrderInstallments__c> toUpdate = new Map<Id, SalesOrderInstallments__c>();

    for (SoiRow row : updates) {
        if (row == null || row.soiId == null) continue;
        if (lockedSoiIds.contains(row.soiId)) continue;

        SalesOrderInstallments__c soiUpd = new SalesOrderInstallments__c(Id = row.soiId);
        if (readinessUpdatable) {
            soiUpd.Payment_Readiness__c = row.readiness;
        }
        if (commentsUpdatable) {
            soiUpd.Payment_Readiness_Comments__c = row.comment;
        }
        toUpdate.put(soiUpd.Id, soiUpd);
    }

    if (toUpdate.isEmpty()) return;

    SObjectAccessDecision dec = Security.stripInaccessible(AccessType.UPDATABLE, toUpdate.values());
    List<SObject> safeToUpdate = dec.getRecords();

    if (safeToUpdate.isEmpty()) {
        throw new AuraHandledException('No editable fields found to update.');
    }

    try {
        update safeToUpdate;
    } catch (DmlException dmle) {
        throw new AuraHandledException('Failed to save Payment Readiness. ' + dmle.getDmlMessage(0));
    }
}

public class InitiateRow {
    @AuraEnabled public Id soiId { get; set; }
    @AuraEnabled public String comment { get; set; }
}

// Kicks off the "Installment Payment Verification" Business Process for the
// given Sales Order Installments (the rows marked "No" in the UI), independent of Save.
// Only callable from a "Project Milestone Confirmation" Business Process, which becomes
// the Parent_Business_Process__c on each Business Process created. Each installment's
// Payment Readiness comment is copied onto the created Business Process's Process_Comment__c.
// Returns the number of installments actually submitted (already-processed ones are skipped).
@AuraEnabled
public static Integer initiateInstallmentPaymentConfirmation(List<InitiateRow> installments, Id parentBusinessProcessId) {
    if (installments == null || installments.isEmpty()) {
        throw new AuraHandledException('Select at least one installment marked "No" before initiating the process.');
    }

    for (InitiateRow row : installments) {
        if (row != null && String.isBlank(row.comment)) {
            throw new AuraHandledException('Comment is mandatory for installment(s) marked "No".');
        }
    }

    if (parentBusinessProcessId == null) {
        throw new AuraHandledException('A Project Milestone Confirmation Business Process is required to initiate this process.');
    }

    Business_Process__c parentBp = [
        SELECT Id, Type__c
        FROM Business_Process__c
        WHERE Id = :parentBusinessProcessId
        LIMIT 1
    ];

    if (parentBp.Type__c != 'Project Milestone Confirmation') {
        throw new AuraHandledException('This action is only available from a Project Milestone Confirmation Business Process.');
    }

    Map<Id, String> commentBySoiId = new Map<Id, String>();
    for (InitiateRow row : installments) {
        if (row != null && row.soiId != null) {
            commentBySoiId.put(row.soiId, row.comment);
        }
    }

    Set<Id> alreadyProcessedIds = new Set<Id>();
    for (SalesOrderInstallments__c soi : [SELECT Id FROM SalesOrderInstallments__c WHERE Id IN :commentBySoiId.keySet() AND Payment_Confirmation_Process__c != null]) {
        alreadyProcessedIds.add(soi.Id);
    }
    for (Id processedId : alreadyProcessedIds) {
        commentBySoiId.remove(processedId);
    }

    if (commentBySoiId.isEmpty()) {
        throw new AuraHandledException('Business Process has already been created for the selected installment(s).');
    }

    Database.executeBatch(new InstallmentBusinessProcessBatch(commentBySoiId, parentBusinessProcessId), 1);
    return commentBySoiId.size();
}
    
@AuraEnabled
public static List<SoiRow> getUnpaidInstallments(Id milestoneId){

    List<String> paymentStatuses = System.Label.Payment_Status_Filter.split(',');
    List<String> soStatuses = System.Label.Sales_Order_Status_Filter.split(',');

for(Integer i=0;i<paymentStatuses.size();i++){
    paymentStatuses[i] = paymentStatuses[i].trim();
}
     for(Integer i=0;i<soStatuses.size();i++){
        soStatuses[i] = soStatuses[i].trim();
    }
    List<SoiRow> rows = new List<SoiRow>();

    for(SalesOrderInstallments__c soi : [SELECT Id, Name,InstallmentAmount__c,MilestoneDate__c,
               PaymentStatus__c,
               SalesOrder__r.Name,Exclude_from_Default__c,
               SalesOrder__r.CustomerAccount__r.Name,SalesOrder__r.Status__c,Exclude_Default_Comments__c,
               Milestone_Installment__r.Name FROM SalesOrderInstallments__c
        WHERE Milestone_Installment__c = :milestoneId
        AND PaymentStatus__c IN :paymentStatuses AND SalesOrder__r.Status__c IN :soStatuses

    ]){

        SoiRow r = new SoiRow();

        r.soiId = soi.Id;
        r.soiName = soi.Name;
        r.salesOrderName = soi.SalesOrder__r.Name;
        r.customerName = soi.SalesOrder__r.CustomerAccount__r.Name;
        r.amount = soi.InstallmentAmount__c;
        r.dueDate = soi.MilestoneDate__c;
        r.milestoneName = soi.Milestone_Installment__r.Name;
        r.PaymentStatus = soi.PaymentStatus__c;
        r.defaultSR = soi.Exclude_from_Default__c;
        r.defaultComments = soi.Exclude_Default_Comments__c;

        rows.add(r);
    }

    return rows;
}
    
public class DefaultSRUpdateWrapper{
    @AuraEnabled public Id soiId {get; set;}
    @AuraEnabled public Boolean defaultSR {get; set;}
    @AuraEnabled public String defaultComments {get; set;}
}

@AuraEnabled
public static void saveDefaultSR(Id serviceRequestId,List<DefaultSRUpdateWrapper> updates){
    if(updates == null || updates.isEmpty()){
        return;
    }

    List<SalesOrderInstallments__c> soiList = new List<SalesOrderInstallments__c>();

    for(DefaultSRUpdateWrapper w : updates){
        System.debug('SOI Id: ' + w.soiId + ' DefaultSR: ' + w.defaultSR);
         if(w.soiId == null){
            continue;
        }

        soiList.add(new SalesOrderInstallments__c( Id = w.soiId, Exclude_from_Default__c = w.defaultSR,Exclude_Default_Comments__c = w.defaultComments, Mile_Stone_Readiness_SR__c =serviceRequestId ));
    }
if(!soiList.isEmpty()){
    update soiList;
}
}
}