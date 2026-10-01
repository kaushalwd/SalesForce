/**********************************************************************************************************************
* Name               : MortgageRegistrationSRController                                                       
* Description        : This class is primarily used to handle operations related to Mortgage Registration Service Requests (Mortgage SRs)
* Usage              : Called from multiple classes
* Created By         : Sireesha                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Sireesha                18 Sep 2025     Initial Draft       
******************************************************************************************************************/


public class MortgageRegistrationSRController {
     public static void validateServiceRequestCreation(List<ServiceRequest__c> srList) {
     if (srList == null || srList.isEmpty()) {
            return;
        }

        // Collect all SalesOrder Ids
        Set<Id> salesOrderIds = new Set<Id>();
        for (ServiceRequest__c sr : srList) {
            if (sr.SalesOrder__c != null) {
                salesOrderIds.add(sr.SalesOrder__c);
            }
        }

        if (salesOrderIds.isEmpty()) {
            return;
        }

        // Query milestones through SalesOrderInstallments
        Map<Id, Boolean> soHasConfirmedMilestone = new Map<Id, Boolean>();
        List<SalesOrderInstallments__c> installments = [
            SELECT SalesOrder__c, Milestone_Installment__c, Milestone_Installment__r.ConfirmedMilestoneDate__c,IsHandoverPayment__c
            FROM SalesOrderInstallments__c 
            WHERE SalesOrder__c IN :salesOrderIds
            AND Milestone__c != null
        ];

        for (SalesOrderInstallments__c inst : installments) {
            if (inst.Milestone_Installment__r != null && inst.Milestone_Installment__r.ConfirmedMilestoneDate__c != null && inst.IsHandoverPayment__c==true) {
                soHasConfirmedMilestone.put(inst.SalesOrder__c, true);
            }
        }

        // Add error for SRs without confirmed milestone
        for (ServiceRequest__c sr : srList) {
            if (sr.SalesOrder__c != null && !soHasConfirmedMilestone.containsKey(sr.SalesOrder__c)) {
                sr.addError('Mortgage Service Request cannot be created as there is no Confirmed Milestone Date.');
            }
        }
    }

    public static void createNextStepsForTasks(Set<Id> srIds, List<Task> tskList) {
        if (tskList != null && !tskList.isEmpty()) {
            Map<Id, SObject> oldMap = new Map<Id, SObject>(); 
            ServiceRequestTaskController.handleTaskUpdates(tskList, oldMap, false);
        }
    }
    public static void createNextStepsForTasksForMortgageDiscrge(Set<Id> srIds, List<Task> tskList) {
        if (tskList != null && !tskList.isEmpty()) {
            Map<Id, SObject> oldMap = new Map<Id, SObject>(); 
            ServiceRequestTaskController.handleTaskUpdates(tskList, oldMap, false);
        }
    }
public static void linkMortgageDocuments(List<ServiceRequest__c> mortgageSRs) {

    if (mortgageSRs == null || mortgageSRs.isEmpty()) return;

    /************************************************************
     * STEP 1: Collect Sales Orders
     ************************************************************/
    Set<Id> salesOrderIds = new Set<Id>();
    Map<Id, Id> srToSO = new Map<Id, Id>();

    for (ServiceRequest__c sr : mortgageSRs) {
        if (sr.SalesOrder__c != null) {
            salesOrderIds.add(sr.SalesOrder__c);
            srToSO.put(sr.Id, sr.SalesOrder__c);
        }
    }
    if (salesOrderIds.isEmpty()) return;


    /************************************************************
     * STEP 2: Fetch Handover Milestone for each SO
     ************************************************************/
    Map<Id, Id> soToMilestone = new Map<Id, Id>();

    for (SalesOrderInstallments__c inst : [
        SELECT Id, SalesOrder__c, Milestone__c,Milestone_Installment__c
        FROM SalesOrderInstallments__c
        WHERE SalesOrder__c IN :salesOrderIds
          AND IsHandoverPayment__c = TRUE
    ]) {
        soToMilestone.put(inst.SalesOrder__c, inst.Milestone_Installment__c);
    }


    /************************************************************
     * STEP 3: Fetch Files under Milestones (ContentDocumentLink)
     ************************************************************/
    Map<Id, List<ContentDocumentLink>> milestoneFilesBySO = new Map<Id, List<ContentDocumentLink>>();

    if (!soToMilestone.isEmpty()) {

        List<ContentDocumentLink> fileLinks = [
            SELECT Id, ContentDocumentId, LinkedEntityId,
                   ContentDocument.Title,
                   ContentDocument.LatestPublishedVersionId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :soToMilestone.values()
        ];

        for (ContentDocumentLink cdl : fileLinks) {
            for (Id soId : soToMilestone.keySet()) {
                if (soToMilestone.get(soId) == cdl.LinkedEntityId) {

                    if (!milestoneFilesBySO.containsKey(soId)) {
                        milestoneFilesBySO.put(soId, new List<ContentDocumentLink>());
                    }

                    milestoneFilesBySO.get(soId).add(cdl);
                }
            }
        }
    }


    /************************************************************
     * STEP 4: Fetch Documents__c (BCC, SPA, Signed SPA)
     ************************************************************/
    Map<Id, Documents__c> mortgageBCCBySO = new Map<Id, Documents__c>();
    Map<Id, Documents__c> mortgageSPABySO = new Map<Id, Documents__c>();
    Map<Id, Documents__c> signedSPADocs = new Map<Id, Documents__c>();

    for (Documents__c doc : [
        SELECT Id, Name, SalesOrder__c,
               Service_Request__c,
               Service_Request__r.SalesOrder__c,
               Service_Request__r.RecordType.Name
        FROM Documents__c
        WHERE (
            (Name IN ('BCC','SPA')
             AND Service_Request__r.RecordType.Name = :Constants.SERVICE_REQUEST_Mortgage_Registration)
            OR Name = 'Signed SPA (Modon)'
        )
        AND (
            Service_Request__r.SalesOrder__c IN :salesOrderIds
         OR SalesOrder__c IN :salesOrderIds
        )
    ]) {

        if (doc.Name == 'BCC' &&
            doc.Service_Request__r != null &&
            doc.Service_Request__r.RecordType.Name == Constants.SERVICE_REQUEST_Mortgage_Registration &&
            doc.Service_Request__r.SalesOrder__c != null) {

            mortgageBCCBySO.put(doc.Service_Request__r.SalesOrder__c, doc);
        }

        else if (doc.Name == 'SPA' &&
                 doc.Service_Request__r != null &&
                 doc.Service_Request__r.RecordType.Name == Constants.SERVICE_REQUEST_Mortgage_Registration &&
                 doc.Service_Request__r.SalesOrder__c != null) {

            mortgageSPABySO.put(doc.Service_Request__r.SalesOrder__c, doc);
        }

        else if (doc.Name == 'Signed SPA (Modon)' && doc.SalesOrder__c != null) {
            signedSPADocs.put(doc.Id, doc);
        }
    }


    /************************************************************
     * STEP 5: Get Signed SPA file → map SO → FileId
     ************************************************************/
    Map<Id, Id> signedSPAFileBySO = new Map<Id, Id>();

    if (!signedSPADocs.isEmpty()) {

        List<ContentDocumentLink> cdlList = [
            SELECT ContentDocumentId, LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :signedSPADocs.keySet()
        ];

        for (ContentDocumentLink cdl : cdlList) {
            Documents__c d = signedSPADocs.get(cdl.LinkedEntityId);
            if (d != null && d.SalesOrder__c != null) {
                signedSPAFileBySO.put(d.SalesOrder__c, cdl.ContentDocumentId);
            }
        }
    }


    /************************************************************
     * STEP 6: Build New ContentDocumentLinks
     ************************************************************/
    List<ContentDocumentLink> newLinks = new List<ContentDocumentLink>();

    for (ServiceRequest__c sr : mortgageSRs) {

        Id soId = srToSO.get(sr.Id);
        if (soId == null) continue;

        /********* BCC FILE LINKING **********/
        Documents__c bccDoc = mortgageBCCBySO.get(soId);

        if (bccDoc != null && milestoneFilesBySO.containsKey(soId)) {

            for (ContentDocumentLink src : milestoneFilesBySO.get(soId)) {

                newLinks.add(new ContentDocumentLink(
                    ContentDocumentId = src.ContentDocumentId,
                    LinkedEntityId = bccDoc.Id,
                    ShareType = 'V',
                    Visibility = 'AllUsers'
                ));
            }
        }

        /********* SIGNED SPA FILE LINKING **********/
        Id spaFileId = signedSPAFileBySO.get(soId);
        Documents__c spaDoc = mortgageSPABySO.get(soId);

        if (spaFileId != null && spaDoc != null) {
            newLinks.add(new ContentDocumentLink(
                ContentDocumentId = spaFileId,
                LinkedEntityId = spaDoc.Id,
                ShareType = 'V',
                Visibility = 'AllUsers'
            ));
        }
    }


    /************************************************************
     * STEP 7: Insert all new file links
     ************************************************************/
    if (!newLinks.isEmpty()) {
        insert newLinks;
    }
}

    /**
* Method: validateMortgageSRDocuments
* Description: Validates required documents for Mortgage Registration and Mortgage Discharge SRs based on Task order.
*
* Parameters:
*   serviceRequestRtName - set of Service Request RecordType Name
*   docMap               - Map of document Name -> Documents__c
*   tskMap               - Map of Task order -> Task for adding errors
*/
    
    public static void validateMortgageRegistrationSRDocuments(
        set<String> serviceRequestRtName, 
        Map<String, Documents__c> docMap, 
        Map<String, Task> tskMap,Map<Id, ServiceRequest__c> srRecordMap
    ) {
        // Only run for Mortgage Registration SRs
        if (serviceRequestRtName.contains(Constants.SERVICE_REQUEST_Mortgage_Registration)) {
            System.debug('salesOrderDocs----->' + docMap);
            
            for (String ordr : tskMap.keySet()) {
                System.debug('ordr---->' + ordr);
                
                Task task = tskMap.get(ordr);
                if (task.Status == Constants.TASK_STATUS_CLOSED){
                    if(!docMap.isEmpty()) {
                    
                    // STEP 2: Mortgage Initial Mandatory Docs (Order 2)
                    if (ordr == '1' || ordr == '1.0') {
                        List<String> missingDocs = new List<String>();
                        for (String docName : Label.Mortgage_Mandatory_Docs_Initial.split(',')) {
                            docName = docName.trim();
                            if (!docMap.containsKey(docName) || docMap.get(docName).Status__c != 'Uploaded') {
                                missingDocs.add(docName);
                            }
                        }
                        if (!missingDocs.isEmpty()) {
                            task.addError('Please upload the ' + String.join(missingDocs, ', '));
                        }
                    }
                    
                    // STEP 3: Mortgage Approval Documents (Order 3)
                    else if (ordr == '4' || ordr == '4.0') {
                        List<String> missingDocs = new List<String>();
                        for (String docName : Label.Mortgage_Approval_Documents.split(',')) {
                            docName = docName.trim();
                            if (!docMap.containsKey(docName) || docMap.get(docName).Status__c != 'Uploaded') {
                                missingDocs.add(docName);
                            }
                        }
                        if (!missingDocs.isEmpty()) {
                            task.addError('Please upload the ' + String.join(missingDocs, ', '));
                        }
                    }
                    
                    // STEP 4: Payment Proof (Order 4)
                    else if (ordr == '5' || ordr == '5.0') {
                        if (docMap.containsKey(Label.Payment_Proof) && docMap.get(Label.Payment_Proof).Status__c != 'Uploaded') {
                            task.addError('Please Upload ' + Label.Payment_Proof);
                        }
                    }
                }
            
            if (ordr == '6' || ordr == '6.0') {

    System.debug('🔍 Inside Order 5 logic');

    // Step 1️⃣: Collect SR IDs
    Set<Id> srIds = new Set<Id>();
    for (Task t : tskMap.values()) {
        if (t.WhatId != null && srRecordMap.containsKey(t.WhatId)) {
            srIds.add(t.WhatId);
        }
    }

    if (!srIds.isEmpty()) {
        // Step 2️⃣: Get related Sales Orders
        Map<Id, ServiceRequest__c> srMap = new Map<Id, ServiceRequest__c>([
            SELECT Id, SalesOrder__c
            FROM ServiceRequest__c
            WHERE Id IN :srIds
            AND SalesOrder__c != null
        ]);

        Set<Id> salesOrderIds = new Set<Id>();
        for (ServiceRequest__c sr : srMap.values()) {
            salesOrderIds.add(sr.SalesOrder__c);
        }

        // Step 3️⃣: Aggregate unpaid invoice balances
        Map<Id, Decimal> balanceSOMap = new Map<Id, Decimal>();

        // 📘 Installment-based invoices
        AggregateResult[] groupedResults = [
            SELECT SalesOrderInstallment__r.SalesOrder__c soId,
                   SUM(InvoiceBalance__c) totalBal
            FROM Invoice__c
            WHERE SalesOrderInstallment__r.SalesOrder__c IN :salesOrderIds
            AND SalesOrderInstallment__c != null
            AND Sales_Order__c = null
            AND InvoiceStatus__c != 'Cancelled'
            AND SalesOrderInstallment__r.MilestoneDate__c < TODAY
            GROUP BY SalesOrderInstallment__r.SalesOrder__c
        ];

        // 📘 Other invoices (non-installment)
      /*  AggregateResult[] groupedResultsOthers = [
            SELECT Sales_Order__c soId,
                   SUM(InvoiceBalance__c) totalBal
            FROM Invoice__c
            WHERE Sales_Order__c IN :salesOrderIds
            AND SalesOrderInstallment__c = null
            AND InvoiceStatus__c != 'Cancelled'
            AND InvoiceDate__c < TODAY
            GROUP BY Sales_Order__c
        ];*/

        // Step 4️⃣: Merge both results
        for (AggregateResult ar : groupedResults) {
            Id soId = (Id) ar.get('soId');
            Decimal bal = (Decimal) ar.get('totalBal');
            balanceSOMap.put(soId, bal);
        }

     /*   for (AggregateResult ar : groupedResultsOthers) {
            Id soId = (Id) ar.get('soId');
            Decimal existing = balanceSOMap.containsKey(soId) ? balanceSOMap.get(soId) : 0;
            existing += (Decimal) ar.get('totalBal');
            balanceSOMap.put(soId, existing);
        }*/

        System.debug('🧾 balanceSOMap: ' + balanceSOMap);

        // Step 5️⃣: Validate tasks
        for (Task t : tskMap.values()) {
            if (t.WhatId != null && srMap.containsKey(t.WhatId)) {
                Id soId = srMap.get(t.WhatId).SalesOrder__c;
                if (balanceSOMap.containsKey(soId) && balanceSOMap.get(soId) > 0) {
                    t.addError(
                        'Action cannot be closed due to Outstanding payment of ' +
                        balanceSOMap.get(soId) + ' installments.'
                    );
                }
            }
        }
    }
}

            }
            }
        }
        // Mortgage Discharge Validation (Bank NOC mandatory for Order 1)
        else if (serviceRequestRtName.contains(Constants.SERVICE_REQUEST_Mortgage_Discharge)) {
            System.debug('Mortgage Discharge - docMap----->' + docMap);
            
            for (String ordr : tskMap.keySet()) {
                Task task = tskMap.get(ordr);
                if ((ordr == '1' || ordr == '1.0') && task.Status == Constants.TASK_STATUS_CLOSED) {
                    if (!docMap.isEmpty()) {
                        if (docMap.containsKey('Bank NOC') && docMap.get('Bank NOC').Status__c != 'Uploaded') {
                            task.addError('Please upload Bank NOC');
                        }
                    } 
                }
            }
        }
    }
    
  @AuraEnabled
public static String updateMortgageRegistrationSRStatus(String srId) {
    try {
        // Query Service Request
        ServiceRequest__c sr = [
            SELECT Id, UnitId__c, SalesOrder__c,Bank__c
            FROM ServiceRequest__c
            WHERE Id = :srId
            LIMIT 1
        ];
        
        // Validate required fields
        if (sr.UnitId__c == null) {
            throw new AuraHandledException('Please select a Unit for this Service Request.');
        }
        if (sr.SalesOrder__c == null) {
            throw new AuraHandledException('Please select a Sales Order for this Service Request.');
        }

 List<Unit__c> unitsToUpdate = new List<Unit__c>();
List<SalesOrder__c> salesOrdersToUpdate = new List<SalesOrder__c>();

if (sr.UnitId__c != null) {
    unitsToUpdate.add(new Unit__c(
        Id = sr.UnitId__c,
        Under_Mortgage__c = true
    ));
}

if (sr.SalesOrder__c != null) {
    salesOrdersToUpdate.add(new SalesOrder__c(
        Id = sr.SalesOrder__c,
        Under_Mortgage__c = true,
        Mortgage_Bank__c = sr.Bank__c
    ));
}

if (!unitsToUpdate.isEmpty()) {
    update unitsToUpdate;
}

if (!salesOrdersToUpdate.isEmpty()) {
    update salesOrdersToUpdate;
}


        return 'success';
    } catch (Exception e) {
        throw new AuraHandledException('Error updating related records: ' + e.getMessage());
    }
}
   @AuraEnabled
public static String updateMortgageDischargeSRStatus(String srId) {
    try {
        // Query Service Request
        ServiceRequest__c sr = [
            SELECT Id, UnitId__c, SalesOrder__c
            FROM ServiceRequest__c
            WHERE Id = :srId
            LIMIT 1
        ];
        
        // Validate required fields
        if (sr.UnitId__c == null) {
            throw new AuraHandledException('Please select a Unit for this Service Request.');
        }
        if (sr.SalesOrder__c == null) {
            throw new AuraHandledException('Please select a Sales Order for this Service Request.');
        }

List<Unit__c> unitsToUpdate = new List<Unit__c>();
List<SalesOrder__c> salesOrdersToUpdate = new List<SalesOrder__c>();

if (sr.UnitId__c != null) {
    unitsToUpdate.add(new Unit__c(
        Id = sr.UnitId__c,
        Under_Mortgage__c = false
    ));
}

if (sr.SalesOrder__c != null) {
    salesOrdersToUpdate.add(new SalesOrder__c(
        Id = sr.SalesOrder__c,
        Under_Mortgage__c = false
    ));
}

if (!unitsToUpdate.isEmpty()) {
    update unitsToUpdate;
}

if (!salesOrdersToUpdate.isEmpty()) {
    update salesOrdersToUpdate;
}



        return 'success';
    } catch (Exception e) {
        throw new AuraHandledException('Error updating related records: ' + e.getMessage());
    }
}
  
    
    public static void pauseLPCCalculationOnMortgageCreation(List<ServiceRequest__c> newList) {
        Set<Id> soIds = new Set<Id>();

        for (ServiceRequest__c sr : newList) {
            if (sr.RecordTypeId == Utility.getRecordTypeIdByDevName(
                ServiceRequest__c.SObjectType, 'Mortgage_Registration'
            ) && sr.SalesOrder__c != null) {
                soIds.add(sr.SalesOrder__c);
            }
        }

        if (!soIds.isEmpty()) {
            List<Charge__c> chargesToUpdate = [
                SELECT Id, Amount__c, Mortgage_Amount__c, Sales_Order__c, PaymentStatus__c
                FROM Charge__c
                WHERE Sales_Order__c IN :soIds
                AND PaymentStatus__c = 'Not Paid' and RecordType.Name =:Constants.CHARGE_LATE_PAYMENT
            ];

            for (Charge__c ch : chargesToUpdate) {
                ch.Mortgage_Amount__c = ch.Amount__c;
            }

            if (!chargesToUpdate.isEmpty()) {
                update chargesToUpdate;
            }
        }
    }
    
    public static void createLPCChargesOnMortgageClosure(List<SObject> newList, Map<Id, SObject> oldMap) {
        // Cast to proper type
        List<ServiceRequest__c> srNewList = (List<ServiceRequest__c>) newList;
        Map<Id, ServiceRequest__c> srOldMap = (Map<Id, ServiceRequest__c>) oldMap;

        Set<Id> soIds = new Set<Id>();

        for (ServiceRequest__c sr : srNewList) {
            ServiceRequest__c oldSr = srOldMap.get(sr.Id);
            if (sr.RecordTypeId == Utility.getRecordTypeIdByDevName(
                    ServiceRequest__c.SObjectType, 'Mortgage_Registration'
                )
                && sr.SalesOrder__c != null
                && sr.Status__c == 'Closed'
                && oldSr.Status__c != 'Closed') {
                soIds.add(sr.SalesOrder__c);
            }
        }

       if (!soIds.isEmpty()) {

    // 1️⃣ Step 1: Get all Charges that are not Paid or Cancelled
    List<Charge__c> chargeList = [
        SELECT Id, Amount__c, Mortgage_Amount__c, Sales_Order__c,
               SalesOrderInstallment__c, PaymentStatus__c, Account__c
        FROM Charge__c
        WHERE Sales_Order__c IN :soIds
        AND PaymentStatus__c NOT IN ('Paid', 'Cancelled') and  RecordType.Name =:Constants.CHARGE_LATE_PAYMENT
    ];

    // Collect installment Ids that have active (unpaid) charges
    Set<Id> soliIdsWithPendingCharges = new Set<Id>();
    for (Charge__c ch : chargeList) {
        if (ch.SalesOrderInstallment__c != null) {
            soliIdsWithPendingCharges.add(ch.SalesOrderInstallment__c);
        }
    }

    // 2️⃣ Step 2: Get Installments with Exclude_LPC__c = false and pending charges
    List<SalesOrderInstallments__c> soliList = new List<SalesOrderInstallments__c>();
    if (!soliIdsWithPendingCharges.isEmpty()) {
        soliList = [
            SELECT Id, SalesOrder__c, Exclude_LPC__c
            FROM SalesOrderInstallments__c
            WHERE Id IN :soliIdsWithPendingCharges
            AND Exclude_LPC__c = false
        ];
    }

    // 3️⃣ (Optional) Get existing Invoices for reference
    List<Invoice__c> existingInvoices = [
        SELECT Id, Charge__c, Sales_Order__c
        FROM Invoice__c
        WHERE Sales_Order__c IN :soIds
    ];
    Set<Id> invoicedChargeIds = new Set<Id>();
    for (Invoice__c inv : existingInvoices) {
        invoicedChargeIds.add(inv.Charge__c);
    }

    // 4️⃣ Prepare lists for update/insert
    List<Charge__c> chargesToUpdate = new List<Charge__c>();
    List<Invoice__c> invoicesToInsert = new List<Invoice__c>();

    for (Charge__c ch : chargeList) {
        if (ch.Mortgage_Amount__c != null && !invoicedChargeIds.contains(ch.Id)) {
            ch.Amount__c = ch.Mortgage_Amount__c;
            chargesToUpdate.add(ch);

            invoicesToInsert.add(new Invoice__c(
                Sales_Order__c = ch.Sales_Order__c,
                Charge__c = ch.Id,
                Account__c = ch.Account__c,
                InvoiceAmount__c = ch.Mortgage_Amount__c,
                SalesOrderInstallment__c = ch.SalesOrderInstallment__c
            ));
        }
    }

    // 5️⃣ Update & Insert
    if (!chargesToUpdate.isEmpty()) {
        update chargesToUpdate;
    }
    if (!invoicesToInsert.isEmpty()) {
        insert invoicesToInsert;
    }

     for (SalesOrderInstallments__c soli : soliList) {
         soli.Exclude_LPC__c = true;
     }
     update soliList;
}

    }
    
   public static void sendEmailOnMortgageDischargeClosure(List<SObject> newList, Map<Id, SObject> oldMap) {
        List<ServiceRequest__c> srNewList = (List<ServiceRequest__c>) newList;
        Map<Id, ServiceRequest__c> srOldMap = (Map<Id, ServiceRequest__c>) oldMap;
   List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        // Get CM_Team Queue Members
        List<GroupMember> cmTeamMembers = [
            SELECT UserOrGroupId 
            FROM GroupMember 
            WHERE Group.Name = 'CM_Team'
        ];

        if (cmTeamMembers.isEmpty()) return;

        // Get the Email Template Id
        Id templateId = [SELECT Id FROM EmailTemplate WHERE DeveloperName = 'Mortgage_Discharge_Closure' LIMIT 1].Id;

        for (ServiceRequest__c sr : srNewList) {
            ServiceRequest__c oldSr = srOldMap.get(sr.Id);

            if (sr.RecordTypeId == Utility.getRecordTypeIdByDevName(
                    ServiceRequest__c.SObjectType, 'Mortgage_Discharge'
                )
                && sr.Status__c == 'Closed'
                && oldSr.Status__c != 'Closed') {

                for (GroupMember member : cmTeamMembers) {
                    // Only include users (skip if member is another group)
                    if (String.valueOf(member.UserOrGroupId).startsWith('005')) {
                        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                        mail.setTargetObjectId(member.UserOrGroupId);
                        mail.setTemplateId(templateId);
                        mail.setWhatId(sr.Id); 
                        mail.setSaveAsActivity(false);
                        emails.add(mail);
                    }
                }
            }
        }

        if (!emails.isEmpty()) {
            Messaging.sendEmail(emails);
        }
    }

    
    public static void sendEmailOnMortgageOnRejetion(List<SObject> newList, Map<Id, SObject> oldMap) {
    List<ServiceRequest__c> srNewList = (List<ServiceRequest__c>) newList;
    Map<Id, ServiceRequest__c> srOldMap = (Map<Id, ServiceRequest__c>) oldMap;

    List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

    // Get the Email Template Id
    Id templateId = [
        SELECT Id 
        FROM EmailTemplate 
        WHERE DeveloperName = 'Mortgage_Reg_Rejection'
        LIMIT 1
    ].Id;

    for (ServiceRequest__c sr : srNewList) {

        ServiceRequest__c oldSr = srOldMap.get(sr.Id);

        // Fire only when SR is Mortgage_Registration and Status changed to Rejected
        if (sr.RecordTypeId == Utility.getRecordTypeIdByDevName(
                ServiceRequest__c.SObjectType, 'Mortgage_Registration'
            )
            && sr.Status__c == 'Rejected'
            && oldSr.Status__c != 'Rejected'
        ) {

            // Get Customer Account
            Account acc = [
                SELECT Id, IsPersonAccount, PersonContactId
                FROM Account
                WHERE Id = :sr.AccountId__c
                LIMIT 1
            ];

            Id targetId;

            // Person Account
            if (acc.IsPersonAccount && acc.PersonContactId != null) {
                targetId = acc.PersonContactId;
            } 
            // Business Account → Fetch Active Contact
            else {
                Contact c = [
                    SELECT Id 
                    FROM Contact
                    WHERE AccountId = :acc.Id
                    AND Is_Active__c = true
                    LIMIT 1
                ];
                if (c != null) {
                    targetId = c.Id;
                } else {
                    continue; // No valid customer contact → skip email
                }
            }

            // Prepare Email
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setTargetObjectId(targetId);      // Send to Customer
            mail.setTemplateId(templateId);        // Rejection Template
            mail.setWhatId(sr.Id);                // Attach SR
            mail.setSaveAsActivity(true);          // Log Email

            emails.add(mail);
        }
    }

    // Send
    if (!emails.isEmpty()) {
        Messaging.sendEmail(emails);
    }
}

    
    public static void blockSRCreationforMortgageDischarge(List<SObject> newList) {
    System.debug('debug: in blockSRCreationIfUnitOrSalesOrderInvalid method');

    List<ServiceRequest__c> srList = (List<ServiceRequest__c>) newList;
    Set<Id> unitIds = new Set<Id>();
    Set<Id> salesOrderIds = new Set<Id>();

    // Collect Unit and SalesOrder IDs
    for (ServiceRequest__c sr : srList) {
        if (sr.UnitId__c != null) {
            unitIds.add(sr.UnitId__c);
        }
        if (sr.SalesOrder__c != null) {
            salesOrderIds.add(sr.SalesOrder__c);
        }
    }

  
    Map<Id, SalesOrder__c> SoNotUnderMortgage = new Map<Id, SalesOrder__c>();
    if (!salesOrderIds.isEmpty()) {
        SoNotUnderMortgage = new Map<Id, SalesOrder__c>(
            [SELECT Id, Name, Status__c FROM SalesOrder__c WHERE Id IN :salesOrderIds AND Under_Mortgage__c =false]
        );
    }

    for (ServiceRequest__c sr : srList) {

        if (sr.SalesOrder__c != null && SoNotUnderMortgage.containsKey(sr.SalesOrder__c)) {
            sr.addError('Cannot create Service Request: SalesOrder is not under mortgage.');
        }

      
    }
}

    
    
 @AuraEnabled
    public static String sendMortgageEmailWithAttachments(Id serviceRequestId) {
        if (serviceRequestId == null) return 'INVALID_SERVICE_REQUEST_ID';

        // Step 1: Get Service Request and related records
        ServiceRequest__c sr = [
            SELECT Id, AccountId__c, SalesOrder__c, SalesOrder__r.Total_Outstanding__c
            FROM ServiceRequest__c
            WHERE Id = :serviceRequestId
            LIMIT 1
        ];
        if (sr == null) return 'SERVICE_REQUEST_NOT_FOUND';

        Account acc = [
            SELECT Id, IsPersonAccount, PersonEmail, PersonContactId, OwnerId
            FROM Account
            WHERE Id = :sr.AccountId__c
            LIMIT 1
        ];

        // Step 2: Determine TargetObjectId
        Id targetId;
        if (acc.IsPersonAccount) {
            if (acc.PersonContactId != null) {
                targetId = acc.PersonContactId;
            } else {
                return 'PERSON_ACCOUNT_HAS_NO_CONTACT';
            }
        } else {
            List<Contact> contacts = [
                SELECT Id, Email
                FROM Contact
                WHERE AccountId = :acc.Id
                AND Is_Active__c = true
                LIMIT 1
            ];
            if (contacts.isEmpty()) return 'NO_ACTIVE_CONTACT_FOUND';
            targetId = contacts[0].Id;
        }

        // Step 3: Get Documents (SOA, SPA, BCC)
        List<Documents__c> docList = [
            SELECT Id
            FROM Documents__c
            WHERE Service_Request__c = :sr.Id
            AND Name IN ('SOA','SPA','BCC')
        ];
        if (docList.isEmpty()) return 'NO_DOCUMENTS_FOUND';

        // Step 4: Get ContentVersion Ids for attachments
        Set<Id> docIds = new Set<Id>();
        for (Documents__c d : docList) docIds.add(d.Id);

        Set<Id> contentDocumentIds = new Set<Id>();
        List<ContentDocumentLink> docLinks = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :docIds
        ];
        for (ContentDocumentLink link : docLinks) contentDocumentIds.add(link.ContentDocumentId);

        if (contentDocumentIds.isEmpty()) return 'NO_CONTENTDOCUMENT_FOUND';

        List<ContentVersion> contentVersions = [
            SELECT Id, Title, VersionData, FileExtension
            FROM ContentVersion
            WHERE ContentDocumentId IN :contentDocumentIds
            AND IsLatest = true
        ];
        if (contentVersions.isEmpty()) return 'NO_CONTENTVERSION_FOUND';

        // Step 5: Get Email Template
        EmailTemplate template = [
            SELECT Id
            FROM EmailTemplate
            WHERE Name = 'Mortgage Registration Send Doc to Customer'
            LIMIT 1
        ];
        if (template == null) return 'EMAIL_TEMPLATE_NOT_FOUND';

        // Step 6: Prepare email
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setTargetObjectId(targetId); // recipient
        email.setWhatId(sr.Id);            // ServiceRequest__c (activity-enabled)
        email.setTemplateId(template.Id);
        email.setSaveAsActivity(true);     // logs email as activity

        // Attach files
        List<Messaging.EmailFileAttachment> attachments = new List<Messaging.EmailFileAttachment>();
        for (ContentVersion cv : contentVersions) {
            Messaging.EmailFileAttachment efa = new Messaging.EmailFileAttachment();
            efa.setFileName(cv.Title + '.' + cv.FileExtension);
            efa.setBody(cv.VersionData);
            attachments.add(efa);
        }
        if (!attachments.isEmpty()) email.setFileAttachments(attachments);

        // Step 7: Send email
        try {
            Messaging.SendEmailResult[] results = Messaging.sendEmail(
                new List<Messaging.SingleEmailMessage>{email}, false
            );
            for (Messaging.SendEmailResult res : results) {
                if (!res.isSuccess()) {
                    System.debug('Email failed: ' + res.getErrors()[0].getMessage());
                    return 'EMAIL_FAILED';
                }
            }
            return 'EMAIL_SENT';
        } catch (Exception e) {
            System.debug('Exception sending email: ' + e.getMessage());
            return 'EMAIL_EXCEPTION';
        }
    }
    
    
  public static void validateUnderMortgage(List<ServiceRequest__c> newList) {
    // Restricted RecordType Developer Names when Under_Mortgage__c = true
    Set<String> restrictedRTs = new Set<String>{
        Constants.SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER,
        Constants.SERVICE_REQUEST_RT_DEV_NAME_UNIT_UPGRADE,
        Constants.SERVICE_REQUEST_UC // Unit Consolidation
    };

    // Collect related Sales Orders and Record Type Ids
    Set<Id> salesOrderIds = new Set<Id>();
    Set<Id> recordTypeIds = new Set<Id>();

    for (ServiceRequest__c sr : newList) {
      System.debug('sr----------->'+sr);
            salesOrderIds.add(sr.SalesOrder__c);
        
        if (sr.RecordTypeId != null) {
            recordTypeIds.add(sr.RecordTypeId);
        }
    }

    if (salesOrderIds.isEmpty() || recordTypeIds.isEmpty()) {
        return;
    }

    // Fetch related Sales Orders
    Map<Id, SalesOrder__c> salesOrderMap = new Map<Id, SalesOrder__c>(
        [SELECT Id, Under_Mortgage__c FROM SalesOrder__c WHERE Id IN :salesOrderIds]
    );

    // Fetch Record Types (DeveloperName)
    Map<Id, RecordType> rtMap = new Map<Id, RecordType>(
        [SELECT Id, Name FROM RecordType WHERE Id IN :recordTypeIds]
    );
      system.debug('rtMap'+rtMap+restrictedRTs);

    // Validate each Service Request
    for (ServiceRequest__c sr : newList) {
        SalesOrder__c so = salesOrderMap.get(sr.SalesOrder__c);
        RecordType rt = rtMap.get(sr.RecordTypeId);
system.debug('rtMap---->711'+rt);
        if (so != null && so.Under_Mortgage__c == true && rt != null) {
            system.debug('rtMap---->711'+restrictedRTs);
            if (restrictedRTs.contains(rt.Name)) {
                sr.addError(
                    'Cannot create Service Request for "' + rt.Name +
                    '" because the property is currently Under Mortgage.'
                );
            }
        }
    }
}

    public static void updateSRProgressForMortgageRequests(List<ServiceRequest__c> newSRs){
        if (newSRs == null || newSRs.isEmpty()) {
            return;
        }


     Set<Id> unitIds = new Set<Id>();
        Set<Id> soIds = new Set<Id>();

        for (ServiceRequest__c sr : newSRs) {

if (sr.UnitId__c != null) {
                    unitIds.add(sr.UnitId__c);
                }
                if (sr.SalesOrder__c != null) {
                    soIds.add(sr.SalesOrder__c);
                }
        }
       List<Unit__c> unitsToUpdate = new List<Unit__c>();
        for (Id uId : unitIds) {
            unitsToUpdate.add(new Unit__c(
                Id = uId,
                SR_Progress__c = 'Mortgage'
            ));
        }

        List<SalesOrder__c> soToUpdate = new List<SalesOrder__c>();
        for (Id soId : soIds) {
            soToUpdate.add(new SalesOrder__c(
                Id = soId,
                SRProgressBar__c = 'Mortgage'
            ));
        }

       
        if (!unitsToUpdate.isEmpty()) {
            update unitsToUpdate;
        }
        if (!soToUpdate.isEmpty()) {
            update soToUpdate;
        }
    }
    
    

public static void sendEmailOnMortgageRegistrationClosure(List<SObject> newList, Map<Id, SObject> oldMap) {
    List<ServiceRequest__c> srNewList = (List<ServiceRequest__c>) newList;
    Map<Id, ServiceRequest__c> srOldMap = (Map<Id, ServiceRequest__c>) oldMap;
    List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

    // Get Email Template
    Id templateId = [SELECT Id FROM EmailTemplate WHERE DeveloperName = 'Mortgage_Reg_Closure' LIMIT 1].Id;

    // Record Type Ids
    Id mortgageRTId = Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType, 'Mortgage_Registration');
    Id handoverRTId = Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType, 'Unit_Handover');

    // Collect Mortgage SRs that are just closed
    Set<Id> closedMortgageSRIds = new Set<Id>();
    for (ServiceRequest__c sr : srNewList) {
        ServiceRequest__c oldSr = srOldMap.get(sr.Id);
        if (sr.RecordTypeId == mortgageRTId && sr.Status__c == 'Closed' && oldSr.Status__c != 'Closed') {
            closedMortgageSRIds.add(sr.Id);
        }
    }

    if (closedMortgageSRIds.isEmpty()) return;

    // Get related Unit Handover SRs (linked via LinkedSR__c)
    List<ServiceRequest__c> handoverSRs = [
        SELECT Id, OwnerId, LinkedSR__c
        FROM ServiceRequest__c
        WHERE RecordTypeId = :handoverRTId
        AND LinkedSR__c IN :closedMortgageSRIds
    ];

    // Create email for each Handover SR Owner
    for (ServiceRequest__c handoverSR : handoverSRs) {
        if (handoverSR.OwnerId != null) {
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setTargetObjectId(handoverSR.OwnerId);
            mail.setTemplateId(templateId);
            mail.setWhatId(handoverSR.LinkedSR__c); // The Mortgage SR
            mail.setSaveAsActivity(false);
            emails.add(mail);
        }
    }

    // Send all emails
    if (!emails.isEmpty()) {
        Messaging.sendEmail(emails);
    }
}

}