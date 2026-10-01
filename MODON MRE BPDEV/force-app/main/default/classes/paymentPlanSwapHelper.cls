/**********************************************************************************************************************
* Name               : paymentPlanSwapHelper                                                       
* Description        : This is a helper class for paymentPlanSwapHelper
* Usage              : Called from ServiceRequestTrigger
* Created By         : AMGS                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Chandu Battu                10 May 2025     Validate and Execute the Payment Plan Swap
******************************************************************************************************************/
public  class paymentPlanSwapHelper {
    public static void emptyMethod(){system.debug('debug: in emptyMethod()');}
    public static void populateAccountAndUnit(List<ServiceRequest__c> serviceRequests) {
        Set<Id> salesOrderIds = new Set<Id>();
        for (ServiceRequest__c sr : serviceRequests) {
            if (sr.SalesOrder__c != null) {
                salesOrderIds.add(sr.SalesOrder__c);
            }
        }
        Map<Id, SalesOrder__c> salesOrderMap = new Map<Id, SalesOrder__c>();
        if (!salesOrderIds.isEmpty()) {
            for (SalesOrder__c so : [SELECT Id, CustomerAccount__c, Unit__c,Unit__r.Phase__r.Project__c FROM SalesOrder__c WHERE Id IN :salesOrderIds]) {
                salesOrderMap.put(so.Id, so);
            }
        }
        for (ServiceRequest__c sr : serviceRequests) {
            if (sr.SalesOrder__c != null && salesOrderMap.containsKey(sr.SalesOrder__c)) {
                SalesOrder__c relatedSO = salesOrderMap.get(sr.SalesOrder__c);
                sr.ProjectId__c = relatedSO.Unit__r.Phase__r.Project__c;
                sr.AccountId__c = relatedSO.CustomerAccount__c;
                sr.UnitId__c = relatedSO.Unit__c;
            }
        }
    }
    
    public static void validateNoPaymentsInProgress(List<ServiceRequest__c> newRequests) {
        //Get record type ID
        Id targetRecordTypeId = [SELECT Id FROM RecordType WHERE SObjectType = 'ServiceRequest__c' AND DeveloperName = 'Payment_Plan_Swap' LIMIT 1].Id;
        Set<Id> salesOrderIds = new Set<Id>();
        Map<Id, Id> srToNewPlanMap = new Map<Id, Id>();
        Map<Id, ServiceRequest__c> srMap = new Map<Id, ServiceRequest__c>();
        
        //Collect all sales order IDs
        for (ServiceRequest__c sr : newRequests) {
            if (sr.RecordTypeId == targetRecordTypeId && sr.SalesOrder__c != null) {
                salesOrderIds.add(sr.SalesOrder__c);
                srToNewPlanMap.put(sr.Id, sr.New_Payment_Plan__c);
                srMap.put(sr.Id, sr);
            }
        }
        if (salesOrderIds.isEmpty()) return;
        
        // Find Receipts with "In Progress" status for the sales orders
        Set<Id> blockedSalesOrderIds = new Set<Id>();
        for (Receipt__c payment : [
            SELECT Id, SalesOrder__c, Status__c
            FROM Receipt__c 
            WHERE SalesOrder__c IN :salesOrderIds
            AND Status__c = 'In Progress'
        ]) {
            blockedSalesOrderIds.add(payment.SalesOrder__c);
        }
        //Get Sales Orders with current Payment Plan
        Map<Id, SalesOrder__c> salesOrderMap = new Map<Id, SalesOrder__c>(
            [SELECT Id, PaymentPlan__c FROM SalesOrder__c WHERE Id IN :salesOrderIds]
        );
        
        //Apply validation on each Service Request
        for (ServiceRequest__c sr : newRequests) {
            if (sr.RecordTypeId != targetRecordTypeId || sr.SalesOrder__c == null) continue;
            Id soId = sr.SalesOrder__c;
            Id newPlanId = sr.New_Payment_Plan__c;
            Id oldPlanId = salesOrderMap.get(soId)?.PaymentPlan__c;
            //Block if "In Progress" payment found
            if (blockedSalesOrderIds.contains(soId)) {
                sr.addError('Cannot create Service Request: Payments are in progress for the linked Sales Order.');
                continue;
            }
            //Block if new plan is same as old OR either is null
            if (oldPlanId == null || oldPlanId == newPlanId) {
                sr.addError('Cannot create Service Request: New Payment Plan must be different from the current plan.');
            }
        }
    }
    
    public static void updatePreviousPaymentPlan(List<ServiceRequest__c> newList) {
        Id targetRecordTypeId = [SELECT Id FROM RecordType WHERE SObjectType = 'ServiceRequest__c' AND DeveloperName = 'Payment_Plan_Swap' LIMIT 1].Id;
        Set<Id> salesOrderIds = new Set<Id>();

        for (ServiceRequest__c sr : newList) {
            if (sr.RecordTypeId != targetRecordTypeId || sr.SalesOrder__c != null) {
                salesOrderIds.add(sr.SalesOrder__c);
            }
        }

        Map<Id, SalesOrder__c> salesOrderMap = new Map<Id, SalesOrder__c>(
            [SELECT Id, PaymentPlan__r.Name FROM SalesOrder__c WHERE Id IN :salesOrderIds]
        );

        for (ServiceRequest__c sr : newList) {
            SalesOrder__c so = salesOrderMap.get(sr.SalesOrder__c);
            if (so != null) {
                sr.Previous_Payment_Plan__c = so.PaymentPlan__r.Name;
            }
        }
    }
    
    
    public static void evaluateSwap(ServiceRequest__c sr) {
    system.debug('In evaluateSwap method');
 
    if (sr.SalesOrder__c == null || sr.New_Payment_Plan__c == null) return;
 
    // Step 1: Get Sales Order
    SalesOrder__c soRec = [
        SELECT Id, PaymentPlan__c, TotalAmount__c
        FROM SalesOrder__c
        WHERE Id = :sr.SalesOrder__c
        LIMIT 1
    ];
 
    Id oldPlanId = soRec.PaymentPlan__c;
    Decimal soTotalAmount = soRec.TotalAmount__c;
 
    // Exit if new and old plans are same or old is null
    if (oldPlanId == null || oldPlanId == sr.New_Payment_Plan__c) return;
 
    // Step 2: Get all SalesOrderInstallments (old ones)
    List<SalesOrderInstallments__c> oldInstallments = [
        SELECT Id
        FROM SalesOrderInstallments__c
        WHERE SalesOrder__c = :soRec.Id
    ];
 
    Set<Id> oldInstIds = new Set<Id>();
    for (SalesOrderInstallments__c inst : oldInstallments) {
        oldInstIds.add(inst.Id);
    }
 
    // Step 3: Get all receipts paid against old installments
    Decimal actualPaid = 0;
    if (!oldInstIds.isEmpty()) {
        List<Receipt__c> oldReceipts = [
            SELECT Id, TotalAmount__c,AppliedAmount__c, SalesOrderInstallment__c
            FROM Receipt__c
            WHERE SalesOrderInstallment__c IN :oldInstIds
        ];
        for (Receipt__c receipt : oldReceipts) {
            actualPaid += receipt.AppliedAmount__c;
        }
    }
    system.debug('Total Actual Paid = ' + actualPaid);
 
    // Step 4: Get milestones of new payment plan (till today)
    Decimal expectedPercent = 0;
    Set<Id> validMilestoneIds = new Set<Id>();
 
    List<PaymentInstallements__c> newMilestones = [
        SELECT Id, Milestone__c, MilestoneDate__c
        FROM PaymentInstallements__c
        WHERE PaymentInstallment__c = :sr.New_Payment_Plan__c
    ];
 
    for (PaymentInstallements__c milestone : newMilestones) {
        if (milestone.MilestoneDate__c != null && milestone.MilestoneDate__c <= Date.today()) {
            expectedPercent += milestone.Milestone__c;
            validMilestoneIds.add(milestone.Id);
        }
    }
    system.debug('Total Expected Percent Till Today = ' + expectedPercent);
 
    // Step 5: Get corresponding SalesOrderInstallments from those new milestones
    List<SalesOrderInstallments__c> newInstallments = [
        SELECT InstallmentAmount__c
        FROM SalesOrderInstallments__c
        WHERE PaymentInstallments__c IN :validMilestoneIds
    ];
 
    Decimal expectedPaid = (soTotalAmount * expectedPercent) / 100;
    Decimal totalExpectedPaid = 0;
    for (SalesOrderInstallments__c inst : newInstallments) {
        totalExpectedPaid += inst.InstallmentAmount__c;
    }
 
    system.debug('Expected Paid Based on Percent = ' + expectedPaid);
    system.debug('Actual Installment Sum Till Today = ' + totalExpectedPaid);
 
    // Step 6: Update SR fields
    sr.Actual_Paid__c = actualPaid;
    sr.Expected_Paid__c = expectedPaid;
 
    if (expectedPaid > actualPaid) {
        sr.Outstanding_Amount__c = expectedPaid - actualPaid;
       sr.Advance_Amount__c = 0;
    } else {
        sr.Advance_Amount__c = actualPaid - expectedPaid;
        sr.Outstanding_Amount__c = 0;
    }
}
    //SalesOrder__c so = [SELECT Id,TotalAmount__c, PaymentPlan__c FROM SalesOrder__c WHERE Id = :salesOrderId LIMIT 1];
    //ServiceRequest__c sr = [SELECT Id, New_Payment_Plan__c, SalesOrder__c FROM ServiceRequest__c WHERE Id = :serviceRequestId LIMIT 1 ]; 
    @AuraEnabled
    public static String executePaymentPlanSwap(Id srId) //refere above queries to include required fields in the parameter objects
    {
        ServiceRequest__c sr = [SELECT Id, SalesOrder__c, New_Payment_Plan__c FROM ServiceRequest__c WHERE Id = :srId];
        SalesOrder__c so = [SELECT ID,PaymentPlan__c,TotalAmount__c,CustomerAccount__c FROM SalesOrder__c WHERE ID =: sr.SalesOrder__c];
        system.debug('debug: in paymentPlanSwapHelper.executePaymentPlanSwap method');
        //savepoint and rollback on error to be implemented for all steps included
        Savepoint sp ;
        try {
            sp = Database.setSavepoint();
            // Step 1: Fetch all related SalesOrderInstallments__c
            List<SalesOrderInstallments__c> oldInstallments = [
                SELECT Id, Name, InstallmentAmount__c, MilestoneDate__c, PaymentStatus__c, SalesOrder__r.Name, MilestoneNumber__c,Instalment_Number__c,InstalmentPaymentDueDateArabicSPA__c,SPAINFRA__c,
                MilestoneDescriptionArabicSPA__c,MilestoneDescriptionArabic__c,MilestoneDescriptionSPA__c,InstalmentPaymentDueDate__c,InstalmentPaymentDueDateArabic__c,Original_Milestone_Date__c,
                PaymentInstallments__c,IsHandoverPayment__c,MilestoneDescription__c,
                Milestone__c,BrokerPayout__c,SalesAgentPayout__c FROM SalesOrderInstallments__c WHERE SalesOrder__c = :so.Id order by MilestoneNumber__c];
            
            system.debug('debug: oldInstallments.size() ' + oldInstallments.size());
            
            
            //CreditNote__c soNewCreditNote = createcreditnote(so.Id,oldInstallments);
            archiveInstallments(oldInstallments);
            InvoiceCancellation(oldInstallments);
            unapplyAllocations(new set<Id>{so.Id});
            updateSalesOrderPaymentPlan(sr);
            List<SalesOrderInstallments__c> newInstallments = createInstallmentsFromNewPaymentPlan(so.Id);// Query the SO details inside the method so the new payment plan will reflect on the record
            tagOldReceiptsToNewInstallments(oldInstallments, newInstallments,so.Id);
            deleteSalesOrderInstallments(oldInstallments);
            
            return 'paymentplanswap success';
         } catch (Exception e) {
            if (sp != null) Database.rollback(sp);
            throw new AuraHandledException('Error processing consolidation: ' + e.getMessage());
        }        
    }
    
    public static void archiveInstallments(List<SalesOrderInstallments__c> oldInstallments) 
    {
        system.debug('debug: in paymentPlanSwapHelper.archiveInstallments method');
        // Step 1: Prepare list of archive records
        List<SOInstallmentsArchive__c> archives = new List<SOInstallmentsArchive__c>();
        for (SalesOrderInstallments__c inst : oldInstallments) {
            SOInstallmentsArchive__c archive = new SOInstallmentsArchive__c();
            
            // Copying fields (adjust based on actual fields)
            archive.Old_SOInstallment_ID__c = inst.Id;
            archive.Installment_Amount__c = inst.InstallmentAmount__c;
            archive.MilestoneDate__c = inst.MilestoneDate__c;
            archive.PaymentStatus__c = inst.PaymentStatus__c;
            archive.Old_Sales_order__c = inst.SalesOrder__r.Name;
            archive.Milestone_Number__c = inst.MilestoneNumber__c;
            archive.Instalment_Number__c = inst.Instalment_Number__c;
            archive.Instalment_Payment_Due_Date_Arabic_SPA__c = inst.InstalmentPaymentDueDateArabicSPA__c;
            archive.SPA_Infra__c = inst.SPAINFRA__c;
            archive.MilestoneDescriptionArabicSPA__c = inst.MilestoneDescriptionArabicSPA__c;
            archive.MilestoneDescriptionArabic__c = inst.MilestoneDescriptionArabic__c;
            archive.MilestoneDescriptionSPA__c = inst.MilestoneDescriptionSPA__c;
            archive.Instalment_Payment_Due_Date__c = inst.InstalmentPaymentDueDate__c;
            archive.Instalment_Payment_Due_Date_Arabic__c = inst.InstalmentPaymentDueDateArabic__c;
            archive.Original_Milestone_Date__c = inst.Original_Milestone_Date__c;
            archive.Payment_Installments__c = inst.PaymentInstallments__c;
            archive.Is_Handover_Payment__c = inst.IsHandoverPayment__c;
            archive.MilestoneDescription__c = inst.MilestoneDescription__c;
            archive.Milestone__c = inst.Milestone__c;
            archive.Broker_Payout__c = inst.BrokerPayout__c;
            archive.Sales_Agent_Payout__c = inst.SalesAgentPayout__c;
            archives.add(archive);
        }
        
        // Step 2: Insert archive records
        insert archives;
        System.debug('Archived ' + archives.size() + ' installment records.');
    }
    
    // this method is using for updating the status to cancellation before related salesorder deleted.
    public static void InvoiceCancellation(List<SalesOrderInstallments__c> oldInstallments)
    {
        system.debug('debug: in paymentPlanSwapHelper.InvoiceCancellation method');
        if (oldInstallments.isEmpty()) return;
        // set to store all SalesOrderInstallments
        Set<Id> SoiIds = new Set<Id>();
        for(SalesOrderInstallments__c inst : oldInstallments ){
            SoiIds.add(inst.Id);
        }
        //Fetch Invoices linked to those installments
        List<Invoice__c> invoicesToCancel = [SELECT Id, IsCancelled__c FROM Invoice__c WHERE SalesOrderInstallment__c IN :SoiIds AND IsCancelled__c = false ];
        //Mark them as cancelled
        for (Invoice__c inv : invoicesToCancel) {
            inv.IsCancelled__c = true;
        }
        
        if (!invoicesToCancel.isEmpty()) {
            update invoicesToCancel;
        } 
    }
    
    private static void unapplyAllocations(Set<Id> salesOrderIds) {
        List<Allocation__c> allocations = [
            SELECT Id, AllocationAmount__c,Status__c
            FROM Allocation__c
            WHERE (Invoice__r.Sales_Order__c IN :salesOrderIds OR Invoice__r.SalesOrderInstallment__r.SalesOrder__c IN :salesOrderIds)
            AND AllocationAmount__c > 0
        ];
 
        for (Allocation__c alloc : allocations) {
            alloc.Status__c = 'Unapplied';
        }
 
        if (!allocations.isEmpty()) {
            update allocations;
        }
    }
    
    
    // Deletion of SalesOrderInstallments
    public static void deleteSalesOrderInstallments(List<SalesOrderInstallments__c> oldInstallments) 
    {
        if (!oldInstallments.isEmpty()) 
        {
            delete oldInstallments;
        }
    }
    
    Public static void updateSalesOrderPaymentPlan(ServiceRequest__c sr)
    {
        system.debug('debug: in paymentPlanSwapHelper.updateSalesOrderPaymentPlan method');
        //  Fetch the Service Request with new payment plan and its Sales Order
        system.debug('++++++++++++SR+++++++++'+ sr);
        if (sr.SalesOrder__c == null || sr.New_Payment_Plan__c == null) {
            throw new AuraHandledException('Missing Sales Order or new Payment Plan on Service Request.');
        }
        
        //  Update the Sales Order with new payment plan
        SalesOrder__c so = new SalesOrder__c(
            Id = sr.SalesOrder__c,
            PaymentPlan__c = sr.New_Payment_Plan__c
        );
        
        update so;
        system.debug('++++++++++++SO+++++++++'+ so);
    }
    
    // this will create New SOI
    public static List<SalesOrderInstallments__c> createInstallmentsFromNewPaymentPlan(Id salesOrderId) 
    {
        system.debug('debug: in paymentPlanSwapHelper.createInstallmentsFromNewPaymentPlan method');
        //  Fetch Sales Order with new Payment Plan
        SalesOrder__c so = [SELECT Id,TotalAmount__c, PaymentPlan__c FROM SalesOrder__c WHERE Id = :salesOrderId LIMIT 1];
        
        if (so.PaymentPlan__c == null) {
            throw new AuraHandledException('No Payment Plan found on the Sales Order.');
        }
        
        // Fetch related Payment Plan Installments
        List<PaymentInstallements__c> planInstallments = [SELECT Id, Name, PaymentInstallment__c, BrokerPayout__c, IsHandoverPayment__c, Milestone__c,  
                                                          MilestoneDate__c, MilestoneDescription__c, MilestoneNumber__c, SalesAgentPayout__c 
                                                          FROM PaymentInstallements__c WHERE PaymentInstallment__c = :so.PaymentPlan__c ORDER BY MilestoneNumber__c ASC ];
        
        if (planInstallments.isEmpty()) {
            throw new AuraHandledException('No installments found in the new Payment Plan.');
        }
        
        // Step 3: Create new SalesOrderInstallments__c from these
        List<SalesOrderInstallments__c> newSOIs = new List<SalesOrderInstallments__c>();
        
        for (PaymentInstallements__c planInst : planInstallments) {
            newSOIs.add(new SalesOrderInstallments__c(
                SalesOrder__c = so.Id,
                PaymentInstallments__c = planInst.Id,
                BrokerPayout__c = planInst.BrokerPayout__c,
                IsHandoverPayment__c = planInst.IsHandoverPayment__c,
                Milestone__c = planInst.Milestone__c,
                MilestoneDate__c = planInst.MilestoneDate__c,
                MilestoneDescription__c = planInst.MilestoneDescription__c,
                MilestoneNumber__c = planInst.MilestoneNumber__c,
                SalesAgentPayout__c = planInst.SalesAgentPayout__c,
                InstallmentAmount__c = (so.TotalAmount__c) * (planInst.Milestone__c/100),
                PaymentStatus__c = 'Not Paid'
                
            ));
        }
        
        insert newSOIs;
        return newSOIs;
    }
    
  
    public static void tagOldReceiptsToNewInstallments(
    List<SalesOrderInstallments__c> oldInstallments,
    List<SalesOrderInstallments__c> newInstallments,
    Id salesOrderId
) {
    Set<Id> oldInstIds = new Set<Id>();
    for (SalesOrderInstallments__c soi : oldInstallments) {
        oldInstIds.add(soi.Id);
    }

    Set<Id> newInstIds = new Set<Id>();
    Map<Id, SalesOrderInstallments__c> newInstMap = new Map<Id, SalesOrderInstallments__c>();
    for (SalesOrderInstallments__c soi : newInstallments) {
        newInstIds.add(soi.Id);
        newInstMap.put(soi.Id, soi);
    }

    List<Receipt__c> receipts = [SELECT Id, SalesOrderInstallment__c, TotalAmount__c,AppliedAmount__c,Receipt_Amount__c FROM Receipt__c WHERE SalesOrderInstallment__c IN :oldInstIds ORDER BY CreatedDate ASC ];

    List<Invoice__c> invoices = [SELECT Id, InvoiceBalance__c, SalesOrderInstallment__c, SalesOrderInstallment__r.MilestoneNumber__c FROM Invoice__c 
                                 WHERE SalesOrderInstallment__c IN :newInstIds AND InvoiceBalance__c > 0 AND isCancelled__c = false 
                                 ORDER BY SalesOrderInstallment__r.MilestoneNumber__c ASC ];

    if (receipts.isEmpty() || invoices.isEmpty()) return;

    Map<Id, Decimal> invoiceBalanceMap = new Map<Id, Decimal>();
    for (Invoice__c inv : invoices) {
        invoiceBalanceMap.put(inv.Id, inv.InvoiceBalance__c != null ? inv.InvoiceBalance__c : 0);
    }

    List<Allocation__c> allocationsToInsert = new List<Allocation__c>();
    List<Receipt__c> receiptsToUpdate = new List<Receipt__c>();
    Map<Id, Decimal> newInstPaidMap = new Map<Id, Decimal>();
    Integer invoiceIndex = 0;

    for (Receipt__c rec : receipts) {
      // Decimal remainingReceiptAmt = rec.TotalAmount__c != null ? rec.TotalAmount__c : 0;
        Decimal remainingReceiptAmt = rec.Receipt_Amount__c != null ? rec.Receipt_Amount__c : 0;
        system.debug ('remainingReceiptAmt======='+remainingReceiptAmt);
        if (remainingReceiptAmt <= 0) continue;

        for (Integer j = invoiceIndex; j < invoices.size(); j++) {
            Invoice__c inv = invoices[j];
            Decimal invBalance = invoiceBalanceMap.get(inv.Id);
            if (invBalance <= 0) {
                invoiceIndex++;
                continue;
            }

            Decimal allocAmt = Math.min(remainingReceiptAmt, invBalance);

            allocationsToInsert.add(new Allocation__c(
                Invoice__c = inv.Id,
                Receipt__c = rec.Id,
                AllocationAmount__c = allocAmt,
                AllocationDate__c = System.today(),
                Status__c = 'Applied'
            ));

            remainingReceiptAmt -= allocAmt;
            invoiceBalanceMap.put(inv.Id, invBalance - allocAmt);

            Id instId = inv.SalesOrderInstallment__c;
            Decimal currentPaid = newInstPaidMap.containsKey(instId) ? newInstPaidMap.get(instId) : 0;
			newInstPaidMap.put(instId, currentPaid + allocAmt);


            if (!receiptsToUpdate.contains(rec)) {
                rec.SalesOrderInstallment__c = instId;
                receiptsToUpdate.add(rec);
            }

            if (remainingReceiptAmt <= 0) break;
            if (invoiceBalanceMap.get(inv.Id) <= 0) invoiceIndex++;
        }
    }

    if (!allocationsToInsert.isEmpty()) insert allocationsToInsert;
    if (!receiptsToUpdate.isEmpty()) update receiptsToUpdate;

    List<SalesOrderInstallments__c> updatedInstallments = new List<SalesOrderInstallments__c>();
    for (Id instId : newInstPaidMap.keySet()) {
        SalesOrderInstallments__c inst = newInstMap.get(instId);
        Decimal paidAmt = newInstPaidMap.get(instId);

        if (inst.InstallmentAmount__c != null) {
            if (paidAmt >= inst.InstallmentAmount__c) {
                inst.PaymentStatus__c = 'Paid';
            } else if (paidAmt > 0) {
                inst.PaymentStatus__c = 'Partially Paid';
            } else {
                inst.PaymentStatus__c = 'Not Paid';
            }
            updatedInstallments.add(inst);
        }
    }

    if (!updatedInstallments.isEmpty()) {
        update updatedInstallments;
    }
}

}