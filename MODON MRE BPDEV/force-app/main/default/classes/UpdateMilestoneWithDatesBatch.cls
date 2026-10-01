/**********************************************************************************************************************
* Name               :                                                         
* Description        : Class for BP framework
* Usage              : BP Framework                                                        
* Created By         : Sivannarayana Peddireddi                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                          Date            Comment                                                                       
* 1.0           sivannaryana.p@modon.com     10-05-2026      Initial Draft     
**********************************************************************************************************************/

global without sharing class UpdateMilestoneWithDatesBatch implements Database.Batchable<sObject>,Database.AllowsCallouts{
    
    Set<Id> setUnitMilestioneId = new Set<Id>();
    Set<Id> trigerredMilestone = new Set<Id>();
    string actionType ='';
    // Business Process that triggered the batch; its Phase__c restricts the
    // installments to units of that phase.
    Id businessProcessId;

    public UpdateMilestoneWithDatesBatch(Set<Id> setUnitMilestioneId){
        this(setUnitMilestioneId, null);
    }

    public UpdateMilestoneWithDatesBatch(Set<Id> setUnitMilestioneId, Id businessProcessId){
        this.setUnitMilestioneId = setUnitMilestioneId;
        this.businessProcessId = businessProcessId;
        system.debug('------setUnitMilestioneId -------------'+setUnitMilestioneId+' businessProcessId: '+businessProcessId );
    }

    global Database.QueryLocator start(Database.BatchableContext BC){
        system.debug('------start-------------'+setUnitMilestioneId );

        Set<Id> paymentInstallmentIds = new Set<Id>();
        for (Milestone__c ms : [SELECT Id, (SELECT Id FROM Payment_Installments__r) FROM Milestone__c WHERE Id IN :setUnitMilestioneId]) {
            for (PaymentInstallements__c pi : ms.Payment_Installments__r) {
                paymentInstallmentIds.add(pi.Id);
            }
        }

        // Sales Order statuses to include, e.g. "In Progress,Completed"
        List<String> soStatuses = new List<String>();
        for (String status : System.Label.Sales_Order_Status_Filter.split(',')) {
            if (String.isNotBlank(status)) {
                soStatuses.add(status.trim());
            }
        }

        // Phase of the Business Process (no phase filter when not available)
        Id phaseId;
        if (businessProcessId != null) {
            for (Business_Process__c bp : [SELECT Id, Phase__c FROM Business_Process__c WHERE Id = :businessProcessId LIMIT 1]) {
                phaseId = bp.Phase__c;
            }
        }
        system.debug('------soStatuses-------------'+soStatuses+' phaseId: '+phaseId );

        // PaymentInstallments__r.MilestoneInstallment__c = the Milestone__c this batch runs for;
        // its dates are read directly from Milestone__c in execute().
        String query = System.Label.Update_Milestone_Dates_SOI_Query;
        if (phaseId != null) {
            query += ' and SalesOrder__r.Unit__r.Phase__c = :phaseId ';
        }
        return Database.getQueryLocator(query);
    }
    
    global void execute(Database.BatchableContext BC, List<SalesOrderInstallments__c> scope){
        system.debug('----222222--scope-------------'+scope);
        try{
            Map<Id,SalesOrderInstallments__c> updateInstallments = new Map<Id,SalesOrderInstallments__c>();
            List<Invoice__c> invoiceListUpdate = new List<Invoice__c>();
            
            // Confirmed / due dates taken directly from Milestone__c (the milestones this batch
            // was started for), not from the installment's own Milestone_Installment__c lookup,
            // which can be blank or point to an older milestone.
            Map<Id, Milestone__c> milestonesById = new Map<Id, Milestone__c>([
                SELECT Id, ConfirmedMilestoneDate__c, Milestone_Due_Date__c
                FROM Milestone__c
                WHERE Id IN :setUnitMilestioneId
            ]);

            Set<Id> installmentIds = new Set<Id>();
            for(SalesOrderInstallments__c installment : scope)
            {
                installmentIds.add(installment.Id);

                Milestone__c milestone = milestonesById.get(installment.PaymentInstallments__r?.MilestoneInstallment__c);
                if (milestone == null) {
                    continue;
                }

                if(milestone.ConfirmedMilestoneDate__c !=null){
                    Date confirmedDate = milestone.ConfirmedMilestoneDate__c;
                    Date existingDate  = installment.MilestoneDate__c;
                    SalesOrderInstallments__c soiUpdate = new SalesOrderInstallments__c(Id = installment.Id,Is_Milestone_Confirmed__c = true,Milestone_Installment__c = milestone.Id);
                    //  Update date ONLY if existing date is not greater than confirmed date
                    if (confirmedDate != null && existingDate <= confirmedDate) {
                        soiUpdate.PreviousMilestoneDate__c = existingDate;
                        soiUpdate.MilestoneDate__c = confirmedDate;
                    }
                    updateInstallments.put(installment.Id,soiUpdate);
                } else if(milestone.ConfirmedMilestoneDate__c ==null && milestone.Milestone_Due_Date__c != installment.MilestoneDate__c){
                    system.debug('milestone Milestone');
                    Date dueDate = milestone.Milestone_Due_Date__c;
                    Date existingDate  = installment.MilestoneDate__c;
                    if ( dueDate != null && existingDate <= dueDate) {
                        SalesOrderInstallments__c install=new SalesOrderInstallments__c(Id = installment.Id,PreviousMilestoneDate__c = existingDate,MilestoneDate__c = dueDate);
                        updateInstallments.put(installment.Id, install);
                    }
                }

               
            }
            for (Invoice__c inv : [ SELECT Id, SalesOrderInstallment__c, InvoiceDate__c, Is_Milestone_Confirmed__c, OraclePartyId__c FROM Invoice__c  WHERE
                                   SalesOrderInstallment__c IN :installmentIds and InvoiceStatus__c  !='Cancelled']) {
                                       if(updateInstallments.size()>0 && updateInstallments.containsKey(inv.SalesOrderInstallment__c)){
                                           SalesOrderInstallments__c soiData=updateInstallments.get(inv.SalesOrderInstallment__c);
                                           Invoice__c invUpdate = new Invoice__c();
                                           invUpdate.Id = inv.Id;
                                           // == true: link-only / due-date updates leave this field unset (null)
                                           Boolean isConfirmed = soiData.Is_Milestone_Confirmed__c == true;
                                           if (!isConfirmed && soiData.MilestoneDate__c == null) {
                                               continue;   // only the milestone link changed - nothing to update on the invoice
                                           }
                                           if(isConfirmed){
                                               invUpdate.Is_Milestone_Confirmed__c = true ;

                                           }
                                           // Move the invoice date only when the installment date changed;
                                           // a confirmed installment dated after the confirmed date keeps
                                           // its date, so its invoice date must not be blanked.
                                           if (soiData.MilestoneDate__c != null) {
                                               invUpdate.PreviousInvoiceDate__c = inv.InvoiceDate__c;
                                               invUpdate.InvoiceDate__c =soiData.MilestoneDate__c;
                                               invUpdate.InvoiceDateUpdatedAfterBilling__c = String.isNotBlank(inv.OraclePartyId__c);
                                           }
                                           invoiceListUpdate.add(invUpdate);

                                       }
                                   }
            
            system.debug('----1111--updateInstallments-------------'+updateInstallments);
            if (!updateInstallments.isEmpty()) {
                update updateInstallments.values();
            }
            system.debug('----222222--updateInstallments-------------'+updateInstallments);
            if (!invoiceListUpdate.isEmpty()) {
                update invoiceListUpdate;
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