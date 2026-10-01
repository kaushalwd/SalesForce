/**********************************************************************************************************************
* Name               : SalesOrderInstallmentTriggerHelper                                                        
* Description        : This class is used to handle all the SalesOrderInstallmentTriggerHandler instances
* Usage              : Called from SalesOrderInstallmentTriggerHandler
* Created By         : PWC Digital Middle East                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           prateek.b.bansal@pwc.com         17 Jan 2024     Initial Draft       
* 2.0           mdixit@horizontal.com            11 Oct 2025     //Added maintenance fee logic for MIRE 
* 3.0           mdixit@horizontal.com            17 Oct 2025     //Added New Milestone fields for Egypt
* 4.0           Mirza Baig                       28 FEB 2026     Bypass condition of invoice dates should be greater or equal to the today's date for Modon Egypt sales orders.
* 5.0           Shahil Sinha (Horizontal)        03 Feb 2026     Added updateEgyptAmountInWords method to populate Sales Order Egypt amount in words fields after roll-up summaries are calculated
* 6.0           Milin Kapatel (Horizontal)       22 Apr 2026     Added updateMilestoneDescriptionArabic method to populate Milestone Description in Arabic for Modon Egypt SOIs
* 7.0			Gautam Mishra (Horizontal)		 23 Apr 2026	 Applied setScale(2) to InvoiceAmount__c in createInvoice method to ensure consistent 2-decimal precision for calculated invoice values
*8.0            Arvind Kesharwani                05 APR 2026     Mapping the Sales Order in Each Invoice for Installment
******************************************************************************************************************/
public without sharing class SalesOrderInstallmentTriggerHelper {
    public static void createInvoice(List<sObject> newList){
        List<Invoice__c> invLst = new List<Invoice__c>();
        set<String> salesOrderids = new set<String>(); 
        for(SalesOrderInstallments__c soiObj : (List<SalesOrderInstallments__c>)newList){
            salesOrderids.add(soiObj.SalesOrder__c);
        }
        
        Map<String, SalesOrder__c> soMap = new Map<String, SalesOrder__c>();
        for(SalesOrder__c soObj : [SELECT Id, Unit__r.TotalPrice__c, Unit__c, CustomerAccount__c, Source_Entity__c FROM SalesOrder__c WHERE Id IN : salesOrderids]){
            soMap.put(soObj.Id, soObj);
        }
        
        for(SalesOrderInstallments__c soiObj : (List<SalesOrderInstallments__c>)newList){
            Invoice__c invObj = new Invoice__c();
            invObj.SalesOrderInstallment__c = soiObj.Id;
            invObj.Sales_Order__c = soiObj.SalesOrder__c; // 8.0 Arvind Added the Maaping for Sales Order
            
            Boolean isModonEgyptSalesOrder = soMap.get(soiObj.SalesOrder__c).Source_Entity__c == ModonEgyptConstants.MODON_EGYPT_SOURCE_ENTITY; //v4.0
            if((soiObj.Milestone__c <> null || soiObj.Milestone_Egypt_Percent__c <> null) && soMap.containsKey(soiObj.SalesOrder__c)){
                //Added maintenance fee logic for MIRE 
                if(isModonEgyptSalesOrder){ //v4.0
                    invObj.CurrencyIsoCode = soiObj.CurrencyIsoCode;
                    invObj.InvoiceAmount__c = (soiObj.InstallmentAmount__c + soiObj.Maintenance_Fee__c).setScale(2);//(soMap.get(soiObj.SalesOrder__c).Unit__r.TotalPrice__c) * (soiObj.Milestone__c/100);	//v7.0
                } else{
                	invObj.InvoiceAmount__c = soiObj.InstallmentAmount__c;//(soMap.get(soiObj.SalesOrder__c).Unit__r.TotalPrice__c) * (soiObj.Milestone__c/100);
                }  //Added maintenance fee logic for MIRE -- till here
            }

            if (soiObj.MilestoneDate__c != null && soiObj.MilestoneDate__c < System.today() && !isModonEgyptSalesOrder) { //v4.0
                invObj.InvoiceDate__c = System.today();
            } else {
                invObj.InvoiceDate__c = soiObj.MilestoneDate__c;
            }//system.today();
            //invObj.Status__c = 'Generated';
            
            if(soMap.containsKey(soiObj.SalesOrder__c)) 
                invObj.Account__c = soMap.get(soiObj.SalesOrder__c).CustomerAccount__c;
            
            invLst.add(invObj);
        }
        try{
            INSERT invLst;
        }catch(Exception ex){
            system.debug('SalesOrderInstallmentTriggerHelper.createInvoice==>' + ex.getMessage());
        }       
        
    }
    
    public static void validateInvoicePaymentReminderChange(Map<Id, sObject> newMap, Map<Id, sObject> oldMap){
        Set<Id> soiIds = new Set<Id>();
        for(Id recId : newMap.keySet()){
            SalesOrderInstallments__c newRec = (SalesOrderInstallments__c) newMap.get(recId);
            SalesOrderInstallments__c oldRec = (SalesOrderInstallments__c) oldMap.get(recId);
            if(newRec.SendPaymentReminder__c != oldRec.SendPaymentReminder__c && newRec.SendPaymentReminder__c == true){
                soiIds.add(newRec.Id);
            }
        }
        if(!soiIds.isEmpty()){
            createInvoicePDFOnceChecked(soiIds);
        }
    }
    
    @future(callout = true)
    public static void createInvoicePDFOnceChecked(Set<Id> soiIds) {
        Map<Id, Documents__c> invoiceToDocumentMap = new Map<Id, Documents__c>();
        String emailTemplateId = [SELECT Id, DeveloperName FROM EmailTemplate WHERE DeveloperName = :Constants.INVOICE_REMINDER_EMAIL_TEMPLATE].Id;
        OrgWideEmailAddress owea = [SELECT Id, Address, DisplayName FROM OrgWideEmailAddress WHERE DisplayName=:Constants.ORGWIDE_DEFAULT_NORPLY_NAME AND IsVerified = true];
        // OrgWideEmailAddress owea = [SELECT Id, Address, DisplayName FROM OrgWideEmailAddress WHERE Address=:Constants.ORGWIDE_DEFAULT_SALES_ADDRESS_NAME];
        List<ContentVersion> contentVersionsToInsert = new List<ContentVersion>();
        List<Messaging.SingleEmailMessage> emailsToSend = new List<Messaging.SingleEmailMessage>();
        
        List<Invoice__c> invoices = [SELECT Id, SalesOrderInstallment__r.Name, ExpressionOfInterest__r.Name, ExpressionOfInterest__c, SalesOrderInstallment__c, Account__r.PersonEmail, Account__r.IsPersonAccount, Account__r.PersonContactId, Account__c FROM Invoice__c WHERE SalesOrderInstallment__c IN :soiIds];
        system.debug('invoices==>' + invoices);
        system.debug('document==>' + [SELECT Id, Name, Invoice__c FROM Documents__c WHERE Invoice__c = :invoices AND Name = 'Invoice PDF']);
        for (Documents__c relatedDocument : [SELECT Id, Name, Invoice__c FROM Documents__c WHERE Invoice__c = :invoices AND Name = 'Invoice PDF']) {
            invoiceToDocumentMap.put(relatedDocument.Invoice__c, relatedDocument);
        }
        
        for (Invoice__c invoice : invoices) {
            Documents__c relatedDocument = invoiceToDocumentMap.get(invoice.Id);
            
            if (relatedDocument != null) {
                
                PageReference pdf = Page.InvoicePDF;
                pdf.getParameters().put('invoiceId', invoice.Id);
                //Blob pdfBlob = pdf.getContentAsPDF();
                
                Blob pdfBlob;
                if(Test.isRunningTest()) {   
                    pdfBlob = blob.valueOf('Unit.Test');    
                } else {         
                    pdfBlob = pdf.getContentAsPDF();         
                }
                
                ContentVersion contentVersion = new ContentVersion();
                contentVersion.VersionData = pdfBlob;
                contentVersion.Title = invoice.ExpressionOfInterest__c != null ? invoice.ExpressionOfInterest__r.Name + ' - Invoice' : invoice.SalesOrderInstallment__r.Name + ' - Invoice';
                contentVersion.PathOnClient = contentVersion.Title;
                contentVersion.FirstPublishLocationId = invoiceToDocumentMap.get(invoice.Id).Id;
                contentVersionsToInsert.add(contentVersion);
                
                Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
                email.setToAddresses(new String[]{invoice.Account__r.PersonEmail});
                email.setWhatId(invoice.Id);
                email.setTargetObjectId(invoice.Account__r.PersonContactId);
                email.setTemplateId(emailTemplateId);
                email.setOrgWideEmailAddressId(owea.Id);
                email.setSaveAsActivity(false);
                
                Messaging.EmailFileAttachment fileAttachment = new Messaging.EmailFileAttachment();
                fileAttachment.setFileName(contentVersion.Title);
                fileAttachment.setBody(contentVersion.VersionData);
                fileAttachment.setContentType('application/pdf');
                email.setFileAttachments(new List<Messaging.EmailFileAttachment>{fileAttachment});
                
                emailsToSend.add(email);
            }
        }
        
        if (!contentVersionsToInsert.isEmpty()) {
            insert contentVersionsToInsert;
        }
        
        if (!emailsToSend.isEmpty()) {
            try {
                Messaging.sendEmail(emailsToSend);
            } catch (Exception e) {
                System.debug('EXCEPTION EE -> ' + e.getMessage());
            }
        }
    }
    
    public static void updateSalesOrders(Map<Id, sObject> newMap, Map<Id, sObject> oldMap) {
        Set<Id> salesOrderIds = new Set<Id>();
        
        for (Id recId : newMap.keySet()) {
            SalesOrderInstallments__c newRec = (SalesOrderInstallments__c) newMap.get(recId);
            
            if (oldMap != null && oldMap.containsKey(recId)) {
                SalesOrderInstallments__c oldRec = (SalesOrderInstallments__c) oldMap.get(recId);
                
                if (newRec.MilestoneNumber__c != oldRec.MilestoneNumber__c ||
                    newRec.PaymentStatus__c != oldRec.PaymentStatus__c ||
                    newRec.SalesOrder__c != oldRec.SalesOrder__c) {
                        
                        if (newRec.SalesOrder__c != null) {
                            salesOrderIds.add(newRec.SalesOrder__c);
                        }
                        if (oldRec.SalesOrder__c != null) {
                            salesOrderIds.add(oldRec.SalesOrder__c);
                        }
                    }
            } else {
                if (newRec.SalesOrder__c != null) {
                    salesOrderIds.add(newRec.SalesOrder__c);
                }
            }
        }
        
        if (salesOrderIds.isEmpty()) return;
        
        List<SalesOrderInstallments__c> allInstallments = [
            SELECT SalesOrder__c, MilestoneNumber__c, PaymentStatus__c
            FROM SalesOrderInstallments__c
            WHERE SalesOrder__c IN :salesOrderIds
            AND MilestoneNumber__c != null
        ];
        
        Map<Id, SalesOrder__c> salesOrderMap = new Map<Id, SalesOrder__c>();
        
        for (SalesOrderInstallments__c inst : allInstallments) {
            Integer milestone = Integer.valueOf(inst.MilestoneNumber__c);
            if (milestone < 1 || milestone > 10) continue;
            
            Id soId = inst.SalesOrder__c;
            
            if (!salesOrderMap.containsKey(soId)) {
                salesOrderMap.put(soId, new SalesOrder__c(Id = soId));
            }
            
            SalesOrder__c so = salesOrderMap.get(soId);
            String status = inst.PaymentStatus__c;
            
            if (milestone == 1) {
                so.Payment_Status_1__c = status;
            } else if (milestone == 2) {
                so.Payment_Status_2__c = status;
            } else if (milestone == 3) {
                so.Payment_Status_3__c = status;
            } else if (milestone == 4) {
                so.Payment_Status_4__c = status;
            } else if (milestone == 5) {
                so.Payment_Status_5__c = status;
            } else if (milestone == 6) {
                so.Payment_Status_6__c = status;
            } else if (milestone == 7) {
                so.Payment_Status_7__c = status;
            } else if (milestone == 8) {
                so.Payment_Status_8__c = status;
            } else if (milestone == 9) {
                so.Payment_Status_9__c = status;
            } else if (milestone == 10) {
                so.Payment_Status_10__c = status;
            }
        }
        
        if (!salesOrderMap.isEmpty()) {
            update salesOrderMap.values();
        }
        
    }
    
    public static void handleManualLPCCharges1(List<sObject> updatedList) {
        List<Charge__c> chargesToInsert = new List<Charge__c>();
        List<Invoice__c> invoicesToInsert = new List<Invoice__c>();
        
        Map<Id, Decimal> soiToLPCAmountMap = new Map<Id, Decimal>();
        Map<Id, Id> soiToAccountMap = new Map<Id, Id>();
        
        List<SalesOrderInstallments__c> soiToProcess = new List<SalesOrderInstallments__c>();
        
        for (sObject sobj : updatedList) {
            SalesOrderInstallments__c soi = (SalesOrderInstallments__c)sobj;
            if (soi.LPCActive__c == true && soi.LPC_Charge__c != null && soi.LPC_Charge__c > 0) {
                soiToProcess.add(soi);
            }
        }
        
        if (soiToProcess.isEmpty()) return;
        
        // Fetch penalty fee record type
        Id penaltyRecordTypeId = Schema.SObjectType.Charge__c.getRecordTypeInfosByName().get('Late Payment').getRecordTypeId();
        
        // Preload SalesOrders and Accounts
        Set<Id> salesOrderIds = new Set<Id>();
        for (SalesOrderInstallments__c soi : soiToProcess) {
            if (soi.SalesOrder__c != null) salesOrderIds.add(soi.SalesOrder__c);
        }
        
        Map<Id, SalesOrder__c> soMap = new Map<Id, SalesOrder__c>(
            [SELECT Id, CustomerAccount__c FROM SalesOrder__c WHERE Id IN :salesOrderIds]
        );
        
        for (SalesOrderInstallments__c soi : soiToProcess) {
            Decimal lpcAmount = soi.LPC_Charge__c.setScale(2);
            
            Charge__c charge = new Charge__c();
            charge.Name = 'Late Payment Charge';
            charge.Amount__c = lpcAmount;
            charge.VAT_Amount__c = 0;
            charge.PaymentStatus__c = 'Not Paid';
            charge.RecordTypeId = penaltyRecordTypeId;
            charge.Sales_Order__c = soi.SalesOrder__c;
            charge.SalesOrderInstallment__c = soi.Id;
            
            chargesToInsert.add(charge);
            soiToLPCAmountMap.put(soi.Id, lpcAmount);
            soiToAccountMap.put(soi.Id, soMap.get(soi.SalesOrder__c).CustomerAccount__c);
        }
        
        if (!chargesToInsert.isEmpty()) {
            insert chargesToInsert;
            
            for (Charge__c charge : chargesToInsert) {
                Id soiId = charge.SalesOrderInstallment__c;
                Decimal amount = soiToLPCAmountMap.get(soiId);
                Id accId = soiToAccountMap.get(soiId);
                
                Invoice__c invoice = new Invoice__c();
                invoice.Sales_Order__c = charge.Sales_Order__c;
                invoice.Charge__c = charge.Id;
                invoice.Account__c = accId;
                invoice.InvoiceAmount__c = amount;
                invoice.SalesOrderInstallment__c = charge.SalesOrderInstallment__c;
                // invoice.Status__c = 'Pending'; // Uncomment if needed
                invoicesToInsert.add(invoice);
            }
            
            if (!invoicesToInsert.isEmpty()) {
                insert invoicesToInsert;
                
                List<SalesOrderInstallments__c> soiToDeactivate = new List<SalesOrderInstallments__c>();
                for (Id soiId : soiToLPCAmountMap.keySet()) {
                    soiToDeactivate.add(new SalesOrderInstallments__c(
                        Id = soiId, 
                        LPCActive__c = false
                    ));
                }
                if (!soiToDeactivate.isEmpty()) {
                    update soiToDeactivate;
                }
            }
        }
    }
    

public static void handleManualLPCCharges(List<SObject> updatedList) {
    if (updatedList == null || updatedList.isEmpty()) return;

    Set<Id> soiIds = new Set<Id>();
    List<SalesOrderInstallments__c> soiToProcess = new List<SalesOrderInstallments__c>();

    for (SObject s : updatedList) {
        SalesOrderInstallments__c soi = (SalesOrderInstallments__c)s;
        if (soi.LPCActive__c && soi.LPC_Charge__c != null && soi.LPC_Charge__c > 0 && soi.PaymentStatus__c == 'Paid') {
            soiToProcess.add(soi);
            soiIds.add(soi.Id);
        }
    }

    if (soiIds.isEmpty()) return;

    // Step 1: Fetch existing Charge records per SOI
    Map<Id, Charge__c> soiToChargeMap = new Map<Id, Charge__c>();
    Id penaltyRecordTypeId = Schema.SObjectType.Charge__c.getRecordTypeInfosByName().get('Late Payment').getRecordTypeId();
    for (Charge__c ch : [
        SELECT Id, SalesOrderInstallment__c, Amount__c, Sales_Order__c
        FROM Charge__c
        WHERE SalesOrderInstallment__c IN :soiIds
        AND RecordTypeId = :penaltyRecordTypeId
    ]) {
        soiToChargeMap.put(ch.SalesOrderInstallment__c, ch);
    }

    // Step 2: Fetch clearing dates
    Map<Id, Date> soiToClearingDate = new Map<Id, Date>();
    for (Allocation__c alloc : [
        SELECT Invoice__r.SalesOrderInstallment__c, Receipt__r.EBS_Clearing_Date__c
        FROM Allocation__c
        WHERE Invoice__r.SalesOrderInstallment__c IN :soiIds
        AND Receipt__r.Status__c = 'Cleared'
        ORDER BY Receipt__r.EBS_Clearing_Date__c DESC
    ]) {
        Id soiId = alloc.Invoice__r.SalesOrderInstallment__c;
        Date clearingDate = alloc.Receipt__r.EBS_Clearing_Date__c;
        if (soiId != null && clearingDate != null && !soiToClearingDate.containsKey(soiId)) {
            soiToClearingDate.put(soiId, clearingDate);
        }
    }

    // Step 3: Fetch SOI & related SO
    Map<Id, SalesOrderInstallments__c> soiMap = new Map<Id, SalesOrderInstallments__c>(
        [SELECT Id, LPC_Charge__c, LPCActive__c, SalesOrder__c,LatestLPCChargedAmt__c,
                MilestoneDate__c, ExtensionDate__c, LastLPCChargedDate__c,
                Milestone_Installment__r.ConfirmedMilestoneDate__c
         FROM SalesOrderInstallments__c WHERE Id IN :soiIds]
    );

    Set<Id> soIds = new Set<Id>();
    for (SalesOrderInstallments__c soi : soiMap.values()) {
        if (soi.SalesOrder__c != null) {
            soIds.add(soi.SalesOrder__c);
        }
    }

    Map<Id, SalesOrder__c> soMap = new Map<Id, SalesOrder__c>(
        [SELECT Id, CustomerAccount__c FROM SalesOrder__c WHERE Id IN :soIds]
    );

    // Prepare updates
    List<Charge__c> chargesToUpdate = new List<Charge__c>();
    List<Invoice__c> invoicesToInsert = new List<Invoice__c>();
    List<SalesOrderInstallments__c> soiToUpdate = new List<SalesOrderInstallments__c>();

    for (SalesOrderInstallments__c inputSOI : soiToProcess) {
        SalesOrderInstallments__c soi = soiMap.get(inputSOI.Id);
        if (soi == null || soi.LPC_Charge__c == null || soi.LPC_Charge__c <= 0) continue;

        Date clearingDate = soiToClearingDate.get(soi.Id);
        if (clearingDate == null) continue;

        // Determine milestone date for comparison
        Date milestoneDate;
        Integer overdueDays;
         Decimal chargeAmount = 0;
if (soi.ExtensionDate__c != null) {
    milestoneDate = soi.ExtensionDate__c;
    overdueDays= milestoneDate.daysBetween(clearingDate);
    chargeAmount=overdueDays < 0
            ? soi.LPC_Charge__c - (soi.LatestLPCChargedAmt__c != null ? soi.LatestLPCChargedAmt__c : 0)
            : soi.LPC_Charge__c;

} else if (soi.Milestone_Installment__r != null && soi.Milestone_Installment__r.ConfirmedMilestoneDate__c != null) {
    milestoneDate = soi.Milestone_Installment__r.ConfirmedMilestoneDate__c;
    overdueDays= milestoneDate.daysBetween(clearingDate);
    chargeAmount=overdueDays < 30
            ? soi.LPC_Charge__c - (soi.LatestLPCChargedAmt__c != null ? soi.LatestLPCChargedAmt__c : 0)
            : soi.LPC_Charge__c;
} else {
    milestoneDate = soi.MilestoneDate__c;
    overdueDays= milestoneDate.daysBetween(clearingDate);
    chargeAmount=overdueDays < 30
            ? soi.LPC_Charge__c - (soi.LatestLPCChargedAmt__c != null ? soi.LatestLPCChargedAmt__c : 0)
            : soi.LPC_Charge__c;
}       

        // Get existing charge
        Charge__c charge = soiToChargeMap.get(soi.Id);
        charge.Amount__c = chargeAmount.setScale(2);
        if(chargeAmount == 0){
            charge.PaymentStatus__c ='Waived';
        }
        chargesToUpdate.add(charge);

        // Create Invoice
        Id accId = soMap.containsKey(soi.SalesOrder__c) ? soMap.get(soi.SalesOrder__c).CustomerAccount__c : null;
        if (accId != null && chargeAmount!=0) {
            invoicesToInsert.add(new Invoice__c(
                Sales_Order__c = soi.SalesOrder__c,
                Charge__c = charge.Id,
                Account__c = accId,
                InvoiceAmount__c = chargeAmount.setScale(2),
                SalesOrderInstallment__c = soi.Id
            ));
        }

        // Update SOI
        soiToUpdate.add(new SalesOrderInstallments__c(
            Id = soi.Id,
            LPCActive__c = false
            //LastLPCChargedDate__c = clearingDate,
            //LatestLPCChargedAmt__c = chargeAmount.setScale(2)
        ));
    }

    if (!chargesToUpdate.isEmpty()) update chargesToUpdate;
    if (!invoicesToInsert.isEmpty()) insert invoicesToInsert;
    if (!soiToUpdate.isEmpty()) update soiToUpdate;
}

    //v5.0 Entry point - collects Sales Order IDs and enqueues Queueable job once
    //Static variable to collect all Sales Order IDs across trigger executions
    private static Set<Id> pendingSalesOrderIds = new Set<Id>();
    private static Boolean isQueueableScheduled = false;

    // v5.0 Called from SalesOrderInstallmentTriggerHandler AFTER INSERT
    public static void updateEgyptAmountInWords(List<SalesOrderInstallments__c> newList) {
        System.debug('updateEgyptAmountInWords Called');
        
        // Collect Sales Order IDs
        for (SalesOrderInstallments__c soi : newList) {
            if (soi.SalesOrder__c != null) {
                pendingSalesOrderIds.add(soi.SalesOrder__c);
            }
        }
        
        // Enqueue Queueable job only once per transaction
        if (!pendingSalesOrderIds.isEmpty() && !isQueueableScheduled && !System.isQueueable() && !System.isBatch()) {
            isQueueableScheduled = true;
            System.enqueueJob(new UpdateEgyptAmountInWordsQueueable(pendingSalesOrderIds));
        }
    }
    //v5.0 end

    
    //v6.0
    /**
     * updateMilestoneDescriptionArabic
     * @description Update Milestone Description in Arabic for Modon Egypt SOIs.
     * @param List<SalesOrderInstallments__c> newList
     * @return void
     */
    public static void updateMilestoneDescriptionArabic(List<SalesOrderInstallments__c> newList) {
        for (SalesOrderInstallments__c soi : newList) {
            if (soi.MilestoneDescription__c != null) {
                soi.MilestoneDescriptionArabic__c = ModonEgyptUtilities.translateMilestoneDescriptionToArabic(soi.MilestoneDescription__c);
            } else {
                soi.MilestoneDescriptionArabic__c = null;
            }
        }
    }
    
}