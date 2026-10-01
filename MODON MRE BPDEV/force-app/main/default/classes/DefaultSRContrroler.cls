public class DefaultSRContrroler {

      public static String TaskRecordTypeId = Schema.SObjectType.Task.getRecordTypeInfosByDeveloperName().get('Service_Request').getRecordTypeId();
    private static final string SERVICE_REQUEST_RT_DEV_NAME_DEFAULT_SR { get { return 'Default_SR'; } }

  public static void createNextStepsForTasks(Set<Id> srIds, List<Task> tskList) {
   /* if (srIds == null || srIds.isEmpty()) return;

    Id defaultSRRecordTypeId = Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType, 'Default_SR');
	
    List<ServiceRequest__c> clearedSRs = [
        SELECT Id, AccountId__c, UnitId__c, SalesOrder__r.Total_Outstanding__c
        FROM ServiceRequest__c
        WHERE Id IN :srIds
        AND Status__c != 'Closed'
        AND RecordTypeId = :defaultSRRecordTypeId
    ];
*/
    if (tskList != null && !tskList.isEmpty()) {
        Map<Id, SObject> oldMap = new Map<Id, SObject>(); 
        ServiceRequestTaskController.handleTaskUpdates(tskList, oldMap, false);
    }
}

public static void createDefaultSRForSalesOrders(List<SalesOrder__c> salesOrders, String creationReason, Map<Id, Set<String>> soIdToOverdueInstIds) {
    // Defensive check and initializations
    if (salesOrders == null || salesOrders.isEmpty()) return;
    if (soIdToOverdueInstIds == null) {
        soIdToOverdueInstIds = new Map<Id, Set<String>>();
    }

    List<ServiceRequest__c> srToInsert = new List<ServiceRequest__c>();
    List<ServiceRequest__c> srToUpdate = new List<ServiceRequest__c>();
    Set<Id> soIds = new Set<Id>();
    Set<Id> unitIdsToUpdate = new Set<Id>();
    Set<Id> accountIdsToUpdate = new Set<Id>();

    Id defaultRecordTypeId = Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType, SERVICE_REQUEST_RT_DEV_NAME_DEFAULT_SR);

    for (SalesOrder__c so : salesOrders) {
        soIds.add(so.Id);
        if (so.Unit__c != null) {
            unitIdsToUpdate.add(so.Unit__c);
        }
        if (so.CustomerAccount__c != null) {
            accountIdsToUpdate.add(so.CustomerAccount__c);
        }
    }

    Map<Id, ServiceRequest__c> soIdToExistingSR = new Map<Id, ServiceRequest__c>();
    for (ServiceRequest__c sr : [SELECT Id, SalesOrder__c, Overdue_Installments__c, Status__c FROM ServiceRequest__c WHERE SalesOrder__c IN :soIds AND RecordTypeId = :defaultRecordTypeId AND Status__c NOT IN ('Closed', 'Closed (Paid)', 'Cancelled')]) {
        soIdToExistingSR.put(sr.SalesOrder__c, sr);
    }

    String finalReason = String.isNotBlank(creationReason) ? creationReason : 'Auto-created due to overdue payment or installment (30+ days) on the sales order.';

    for (SalesOrder__c so : salesOrders) {
        Set<String> overdueInstNames = soIdToOverdueInstIds.get(so.Id);
        if (overdueInstNames == null) {
            overdueInstNames = new Set<String>();
        }

        if (soIdToExistingSR.containsKey(so.Id)) {
            ServiceRequest__c existingSR = soIdToExistingSR.get(so.Id);
            existingSR.Overdue_Installments__c = appendUniqueNames(existingSR.Overdue_Installments__c, overdueInstNames);
            srToUpdate.add(existingSR);
        } else {
            ServiceRequest__c newSR = new ServiceRequest__c();
            newSR.Name__c = 'Default Collection SR - ' + so.Name;
            newSR.Status__c = 'New';
            newSR.Description__c = 'Default SR has been Created.';
            newSR.SalesOrder__c = so.Id;
            newSR.AccountId__c = so.CustomerAccount__c;
            newSR.UnitId__c = so.Unit__c;
            newSR.OpportunityId__c = so.Opportunity__c;
            newSR.RecordTypeId = defaultRecordTypeId;
            newSR.SR_Creation_Reason__c = finalReason;
            if (!overdueInstNames.isEmpty()) {
                newSR.Overdue_Installments__c = String.join(new List<String>(overdueInstNames), ',');
            }
            srToInsert.add(newSR);
        }
    }

    if (!srToInsert.isEmpty()) {
    Database.SaveResult[] results = Database.insert(srToInsert, false);

    for (Integer i = 0; i < results.size(); i++) {
        if (results[i].isSuccess()) {
            Id srId = srToInsert[i].Id;
            String result = sendDefaultNoticeEmail(srId,null);
            System.debug('Email send result for SR ' + srId + ': ' + result);
        } else {
            for (Database.Error err : results[i].getErrors()) {
                System.debug('Insert failed for SR: ' + err.getMessage());
            }
        }
    }
}
    if (!srToUpdate.isEmpty()) {
        update srToUpdate;
    }

    if (!unitIdsToUpdate.isEmpty()) {
    List<Unit__c> unitsToUpdate = new List<Unit__c>();
    for (Id unitId : unitIdsToUpdate) {
        unitsToUpdate.add(new Unit__c(
            Id = unitId,
            Unit_Defaulted__c = true
        ));
    }
    update unitsToUpdate;
}

   if (!accountIdsToUpdate.isEmpty()) {
    List<Account> accountsToUpdate = new List<Account>();
    for (Id accId : accountIdsToUpdate) {
        accountsToUpdate.add(new Account(
            Id = accId,
            Customer_Defaulted__c = true
        ));
    }
    update accountsToUpdate;
}
}

private static String appendUniqueNames(String existingnames, Set<String> newNames) {
    Set<String> combined = new Set<String>();

    // Add existing names
    if (!String.isBlank(existingnames)) {
        for (String val : existingnames.split(',')) {
            combined.add(val.trim());
        }
    }

    // Add new names
    for (String instName : newNames) {
        combined.add(instName);
    }

    return String.join(new List<String>(combined), ',');
}


    private static void handleClearedOutstandingSalesOrders(List<SalesOrder__c> clearedOrders) {
       if (clearedOrders == null || clearedOrders.isEmpty()) return;

    // Initialize variables
    Set<Id> clearedSOIds = new Set<Id>();
    Set<Id> accIds = new Set<Id>();
    Set<Id> unitIds = new Set<Id>();
    Set<Id> srIds = new Set<Id>();
    List<Account> accountsToUpdate = new List<Account>();
    List<Unit__c> unitsToUpdate = new List<Unit__c>();

    // Filter only fully paid orders
    for (SalesOrder__c so : clearedOrders) {
         System.debug('so.Total_Outstanding__c--->'+so.Total_Outstanding__c);
        if (so.Total_Outstanding__c == 0 || so.Total_Outstanding__c == 0.0) {
             System.debug('so.Total_Outstanding__c--->'+so.Total_Outstanding__c);
            clearedSOIds.add(so.Id);
        }
    }

       
    if (clearedSOIds.isEmpty()) return;

    // Get Record Type Id for Default_SR
    Id defaultSRRecordTypeId = Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType, 'Default_SR');

    // Fetch relevant Service Requests
    List<ServiceRequest__c> clearedSRs = [SELECT Id, AccountId__c, UnitId__c, SalesOrder__c FROM ServiceRequest__c WHERE SalesOrder__c IN :clearedSOIds AND Status__c != 'Closed' AND RecordTypeId = :defaultSRRecordTypeId];

    if (clearedSRs.isEmpty()) return;

    // Collect related Account and Unit Ids
    for (ServiceRequest__c sr : clearedSRs) {
        srIds.add(sr.Id);
        if (sr.AccountId__c != null) accIds.add(sr.AccountId__c);
        if (sr.UnitId__c != null) unitIds.add(sr.UnitId__c);
        System.debug('sr.AccountId__c--->'+sr.AccountId__c);
 System.debug('sr.UnitId__c--->'+sr.UnitId__c);
       
    }

    // Prepare Account updates
    for (Id accId : accIds) {
        accountsToUpdate.add(new Account(Id = accId, Customer_Defaulted__c = false));
    }

    // Prepare Unit updates
    for (Id unitId : unitIds) {
        unitsToUpdate.add(new Unit__c(Id = unitId, Unit_Defaulted__c = false));
    }

    // Perform updates
    if (!accountsToUpdate.isEmpty()) update accountsToUpdate;
    if (!unitsToUpdate.isEmpty()) update unitsToUpdate;
    }
    
    
    public static void updateOutstandingAmountForSalesOrders(Set<Id> salesOrderIds, List<SalesOrderInstallments__c> installments) {
   
        if ((installments == null || installments.isEmpty()) && salesOrderIds != null && !salesOrderIds.isEmpty()) {
        
        installments = fetchInstallmentsForSalesOrders(salesOrderIds);
    }
    if (installments == null || installments.isEmpty()) return;

    // Initialize variables
    Set<Id> installmentIds = new Set<Id>();
    Map<Id, Decimal> installmentIdToInvoicedAmount = new Map<Id, Decimal>();
    Map<Id, Decimal> soIdToOutstanding = new Map<Id, Decimal>();
    List<SalesOrder__c> salesOrdersToUpdate = new List<SalesOrder__c>();

    // Collect Installment Ids
    for (SalesOrderInstallments__c inst : installments) {
        if (inst.Id != null) {
            installmentIds.add(inst.Id);
        }
    }

 
        // Map to store total outstanding invoice balances per installment
            Map<Id, Decimal> installmentIdToBalance = new Map<Id, Decimal>();
            
            for (AggregateResult ar : [
                SELECT SalesOrderInstallment__c instId, SUM(InvoiceBalance__c) totalBal
                FROM Invoice__c
                WHERE SalesOrderInstallment__c IN :installmentIds
                AND IsCancelled__c = false
                GROUP BY SalesOrderInstallment__c
            ]) {
                 System.debug('installmentIdToBalance'+ar.get('instId')+ar.get('totalBal'));
                installmentIdToBalance.put((Id) ar.get('instId'), (Decimal) ar.get('totalBal'));
            }
            
       
            
            for (SalesOrderInstallments__c inst : installments) {
                
                if (inst.SalesOrder__c == null) continue;
            
                Decimal outstanding = installmentIdToBalance.get(inst.Id) != null
                    ? installmentIdToBalance.get(inst.Id)
                    : 0;
             System.debug('outstanding--->'+outstanding);
                if (!soIdToOutstanding.containsKey(inst.SalesOrder__c)) {
                    soIdToOutstanding.put(inst.SalesOrder__c, 0);
                }
                soIdToOutstanding.put(inst.SalesOrder__c, soIdToOutstanding.get(inst.SalesOrder__c) + outstanding);
                System.debug('soIdToOutstanding--->'+soIdToOutstanding);
            }
        
            for (Id soId : soIdToOutstanding.keySet()) {
        salesOrdersToUpdate.add(new SalesOrder__c(
            Id = soId,
            Total_Outstanding__c = soIdToOutstanding.get(soId)
        ));
            }

    if (!salesOrdersToUpdate.isEmpty()) {
        update salesOrdersToUpdate;
    }

    handleClearedOutstandingSalesOrders(salesOrdersToUpdate);
}

   @AuraEnabled
public static String sendDefaultNoticeEmail(Id serviceRequestId,String templateLabelOverride) {
    if (serviceRequestId == null) {
        return 'INVALID_SERVICE_REQUEST_ID';
    }
    
 // Step 1: Get SR using private method
    List<ServiceRequest__c> srList = getServiceRequestsById(serviceRequestId);
    if (srList.isEmpty()) {
        return 'SERVICE_REQUEST_NOT_FOUND';
    }

    ServiceRequest__c sr = srList[0];
    Account acc = sr.AccountId__r;
    if (acc == null) return 'ACCOUNT_NOT_FOUND';

    // Check if outstanding amount is 0 (already paid)
    if (sr.SalesOrder__r != null && sr.SalesOrder__r.Total_Outstanding__c == 0) {
        return 'AMOUNT_ALREADY_PAID';
    }


    String templateLabelName;

    if (String.isNotBlank(templateLabelOverride)) {
        templateLabelName = templateLabelOverride;
    } else {
            if (sr.SR_Creation_Reason__c == Label.SRCheckBounceReason) {
            system.debug('checkkk----->');
            templateLabelName = Label.Check_Bounce_Default_SR_Template;
        } else if (sr.SR_Creation_Reason__c == Label.SRSalesOrderInstOverdue) {
            templateLabelName = Label.Soli_Default_SR_Template;
        } else {
            return 'NO_MATCHING_TEMPLATE_REASON';
        }
    }
System.debug('templateLabelName--->'+templateLabelName);
    Id templateId = getEmailTemplateId(templateLabelName);
    if (templateId == null) {
        return 'TEMPLATE_NOT_FOUND';
    }
    system.debug('templateId--->'+templateId);

    // Get recipient emails
    List<Messaging.SingleEmailMessage> emailsToSend = getEmailsForAccount(acc, sr.Id, templateId);

    if (!emailsToSend.isEmpty()) {
        Messaging.sendEmail(emailsToSend, false);
        return 'EMAIL_SENT';
    }

    return 'NO_ELIGIBLE_CONTACT_FOUND';
}
    @TestVisible
    private static List<Messaging.SingleEmailMessage> getEmailsForAccount(Account acc, Id srId, Id templateId) {
    List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

    if (acc.IsPersonAccount && acc.PersonEmail != null && acc.PersonContactId != null) {
        // Person Account case
        emails.add(buildTemplateEmail(acc.PersonContactId, srId, acc.PersonEmail, templateId));
    } else {
        // Org Account case
        List<Contact> contacts = [
            SELECT Id, Email
            FROM Contact
            WHERE AccountId = :acc.Id
              AND Is_Active__c = TRUE
              AND Email != null
        ];
        for (Contact con : contacts) {
            emails.add(buildTemplateEmail(con.Id, srId, con.Email, templateId));
        }
    }
    return emails;
}

    
    private static Id getEmailTemplateId(String developerName) {
    if (String.isBlank(developerName)) {
        return null;
    }

    List<EmailTemplate> templates = [
        SELECT Id
        FROM EmailTemplate
        WHERE DeveloperName = :developerName
        LIMIT 1
    ];

    return templates.isEmpty() ? null : templates[0].Id;
}

    
    private static List<ServiceRequest__c> getServiceRequestsById(Id serviceRequestId) {
    List<ServiceRequest__c> srList = new List<ServiceRequest__c>();

    if (serviceRequestId == null) {
        return srList; 
    }

    srList = [
        SELECT Id,
               Name,
               AccountId__c,
               SalesOrder__r.Total_Outstanding__c,
               AccountId__r.IsPersonAccount,
               AccountId__r.PersonEmail,
               AccountId__r.PersonContactId,
               AccountId__r.Owner.Email,
               AccountId__r.OwnerId,SR_Creation_Reason__c
        FROM ServiceRequest__c
        WHERE Id = :serviceRequestId
    ];

    return srList;
}

@TestVisible
    // Helper to build templated email
    private static Messaging.SingleEmailMessage buildTemplateEmail(Id targetContactId, Id relatedRecordId, String replyTo, Id templateId) {
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setTargetObjectId(targetContactId);
        mail.setWhatId(relatedRecordId);
        mail.setTemplateId(templateId);
        mail.setReplyTo(replyTo);
        mail.setSaveAsActivity(true); // or false, if you prefer
        return mail;
    }
    
    private static List<SalesOrderInstallments__c> fetchInstallmentsForSalesOrders(Set<Id> salesOrderIds) {
         system.debug('fetchInstallmentsForSalesOrders--->'+salesOrderIds);
        Date today = Date.today();
    return [
			SELECT Id, Name, MilestoneDate__c, Milestone_Installment__c,
                   Milestone_Installment__r.Name, InstallmentAmount__c,
                   Milestone_Installment__r.ConfirmedMilestoneDate__c,
                   SalesOrder__c
                 
              FROM SalesOrderInstallments__c
        WHERE SalesOrder__c IN :salesOrderIds  AND SalesOrder__r.Status__c = 'Completed'
                   AND PaymentStatus__c NOT IN ('Cancelled')
               AND MilestoneNumber__c != 1
               AND (
                   (Milestone_Installment__c != null AND Milestone_Installment__r.ConfirmedMilestoneDate__c <= :today)
                   OR
                   (Milestone_Installment__c = null AND MilestoneDate__c <= :today)             
               ) AND (ExtensionDate__c = null OR ExtensionDate__c <= :today)
    ];
        
       
}
}