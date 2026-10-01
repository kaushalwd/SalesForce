/**********************************************************************************************************************
* Name               : EOITriggerHandler                                                        
* Description        : This class is used to handle all the EOI trigger instances
* Usage              : Called from EOITrigger
* Created By         : PWC Digital Middle East                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           prateek.b.bansal@pwc.com         27 Dec 2023     Initial Draft       
* 2.0           Gautam Sah(Horizontal)           31 Mar 2025     Modon Egypt Built      
* 2.1           Prateek Bansal                    14 May 2026     Queue EOI notifications and reminders after EOI creation
* 2.2           Prateek Bansal                    14 May 2026     Queue EOI completed and voided notifications on status transition
* 2.3           Arvind                            10 May 2026     COmment the Invoice creation
* 2.3           Arvind Kesharwani                 14 May 2026     Arvind - set the SLA 
* 2.4           Prateek Bansal                    15 May 2026     Persist SLA expiry before queueing creation follow-ups
* 2.5           Arvind Kesharwani                 18 May 2026     Null check on otherNewMap / otherOldMap from filterBeforeUpdate
* 2.6           Prateek Bansal                    10 Sep 2026     EOI payment reminders switched off at the call site. EOI deposits
*                                                                 are online only and the money is held before the EOI exists, so
*                                                                 there is never anything to chase. Deactivating the config records
*                                                                 does NOT do this: an empty active-config list trips the hardcoded
*                                                                 fallback in ReminderTaskService.getFallbackInitialConfigs.
* 2.7           Prateek Bansal                    13 Sep 2026     Queue the finance offer and the broker's copy on EOI creation.
* 2.8           Prateek Bansal                    13 Sep 2026     Treat Cancelled as an ending; it is what the cascade writes.
* 2.9           Prateek Bansal                    13 Sep 2026     Creation follow-ups on one job, so async EOIs are not rolled back.
* 3.0           Prateek Bansal                    13 Sep 2026     Carry the UAT Egypt sync here, commented, so one copy fits every org.


******************************************************************************************************************/
public without sharing class EOITriggerHandler extends TriggerHandler {

    //*** Before Insert Action ***//
    public override void beforeInsertMethod(list<SObject> newList, map<ID,SObject> newMap) {
        EOITriggerHelper.updateEOIId(newList);
        //EOITriggerHelper.updateAvailableEscrowAccount(newList);
    }

    //*** Before Update Action ***//
    public override void beforeUpdateMethod(List<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap) {
        // Filter EOIs using Modon_Egypt_EOIFilterHelper
        Map<String, Object> filteredLeads = Modon_Egypt_EOIFilterHelper.filterBeforeUpdate(newList, newMap, oldList, oldMap);

        if (filteredLeads == null) return;  // 2.5 guard: helper returned null

        // Extract filtered maps
        Map<Id, SObject> otherNewMap = (Map<Id, SObject>) filteredLeads.get('OtherNewMap');
        Map<Id, SObject> otherOldMap = (Map<Id, SObject>) filteredLeads.get('OtherOldMap');

        // 2.5 — null check added; otherNewMap is null when filterBeforeUpdate
        //        does not populate the 'OtherNewMap' key (e.g. all records are
        //        Modon Egypt EOIs), causing the previous NPE at this line.
        if (otherNewMap != null && !otherNewMap.isEmpty()) {
            EOITriggerHelper.updateEOIStatus(otherNewMap, otherOldMap);
        }
    }

    //*** After Delete Action ***//
    public override void afterDeleteMethod(List<SObject> oldList, Map<Id, SObject> oldMap) {

    }

    //*** After Insert Action ***//
    public override void afterInsertMethod(List<SObject> newList, Map<ID, SObject> newMap) {
        // Filter EOIs using Modon_Egypt_EOIFilterHelper
        Map<String, Object> filteredLeads = Modon_Egypt_EOIFilterHelper.filterAfterInsert(newList, newMap);

        if (filteredLeads == null) return;  // 2.5 guard

        // Extract filtered lists
        List<SObject> modonEgyptEOI = (List<SObject>) filteredLeads.get('ModonEgyptEOI');
        List<SObject> otherNewEOI   = (List<SObject>) filteredLeads.get('OtherEOI');

        // Process Other EOIs only
        if (otherNewEOI != null && !otherNewEOI.isEmpty()) {
          // EOITriggerHelper.createInvoice(otherNewEOI); // 2.3 Arvind comment for MRE is not required 
           EOITriggerHelper.createDocumentRecords(otherNewEOI);
           EOITriggerHelper.setSLAStartTime(otherNewEOI);
           queueEoiCreationFollowUps(otherNewEOI);
        }
        // Process Modon Egypt EOIs only
        if (modonEgyptEOI != null && !modonEgyptEOI.isEmpty()) {
           EOITriggerHelper.createModonEgyptDocumentRecords(modonEgyptEOI);
        }
    }

    private static void queueEoiCreationFollowUps(List<SObject> eoiRecords) {
        List<Id> eoiIds = new List<Id>();
        for (SObject eoiRecord : eoiRecords) {
            if (eoiRecord.Id != null) {
                eoiIds.add(eoiRecord.Id);
            }
        }
        if (eoiIds.isEmpty()) return;

        try {
            EoiNotificationService.enqueueEoiCreationFollowUps(eoiIds);
            // 2.6 Payment reminders are off. EOI deposits are online only and the payment is held
            // or taken before the EOI is raised, so no EOI ever needs a payment chase. Deactivating
            // the 12 Reminder_Config records does not achieve this: with no active config the
            // service falls back to a hardcoded 10-minute WhatsApp + Email pair and chases anyway.
            // ReminderTaskService.createInitialEoiPaymentReminderTasks(eoiIds);
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, '[EOITriggerHandler] Failed to queue EOI creation follow-ups: ' + ex.getMessage());
        }
    }

    
    
    //*** After Update Action ***//
    public override void afterUpdateMethod(List<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap) {
        // Filter EOIs using Modon_Egypt_EOIFilterHelper
        Map<String, Object> filteredLeads = Modon_Egypt_EOIFilterHelper.filterAfterUpdate(newList, newMap, oldList, oldMap);

        if (filteredLeads == null) return;  // 2.5 guard

        // Extract filtered maps
        Map<Id, SObject> otherNewMap = (Map<Id, SObject>) filteredLeads.get('OtherNewMap');
        Map<Id, SObject> otherOldMap = (Map<Id, SObject>) filteredLeads.get('OtherOldMap');

        // 3.0 The Modon Egypt Oracle receipt sync, as it stands in UAT and PreProd. Held commented so
        // one copy of this class deploys everywhere: ModonEgypt_OracleIntegrationControlUtil exists
        // only in those two orgs, so live code here would not compile in MREQA or Production.
        // Uncomment once that class ships to every org.
        // Map<Id, SObject> ModonEgyptNewMap = (Map<Id, SObject>) filteredLeads.get('ModonEgyptNewMap');
        // Map<Id, SObject> ModonEgyptOldMap = (Map<Id, SObject>) filteredLeads.get('ModonEgyptOldMap');
        // if (!ModonEgyptNewMap.isEmpty()) {
        //     if (ModonEgypt_OracleIntegrationControlUtil.isReceiptSyncEnabled()) {
        //         EOITriggerHelper.modonEgyptSyncReceiptToOracle(ModonEgyptNewMap, ModonEgyptOldMap);
        //     }
        // }
































        // Process Other EOIs only
        if (otherNewMap != null && !otherNewMap.isEmpty()) {
            EOITriggerHelper.manageInvoiceAmount(otherNewMap, otherOldMap);
            queueEoiStatusNotifications(otherNewMap, otherOldMap);
        }
    }

    private static void queueEoiStatusNotifications(Map<Id, SObject> newMap, Map<Id, SObject> oldMap) {
        List<Id> completedEoiIds = new List<Id>();
        List<Id> voidedEoiIds   = new List<Id>();

        for (Id eoiId : newMap.keySet()) {
            Expressionofinterest__c newEoi = (Expressionofinterest__c) newMap.get(eoiId);
            Expressionofinterest__c oldEoi = oldMap == null ? null : (Expressionofinterest__c) oldMap.get(eoiId);
            String newStatus = newEoi == null ? null : newEoi.Status__c;
            String oldStatus = oldEoi == null ? null : oldEoi.Status__c;
            if (String.isBlank(newStatus) || newStatus == oldStatus) continue;

            if (isCompletedStatus(newStatus)) {
                completedEoiIds.add(eoiId);
            } else if (isVoidedStatus(newStatus)) {
                voidedEoiIds.add(eoiId);
            }
        }

        try {
            if (!completedEoiIds.isEmpty()) {
                EoiNotificationService.enqueueEoiCompletedNotification(completedEoiIds);
            }
            if (!voidedEoiIds.isEmpty()) {
                EoiNotificationService.enqueueEoiVoidedNotification(voidedEoiIds);
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, '[EOITriggerHandler] Failed to queue EOI status notifications: ' + ex.getMessage());
        }
    }

    private static Boolean isCompletedStatus(String statusValue) {
        return String.isNotBlank(statusValue) && statusValue.trim().equalsIgnoreCase('Completed');
    }

    private static Boolean isVoidedStatus(String statusValue) {
        if (String.isBlank(statusValue)) return false;
        String normalizedStatus = statusValue.trim().toLowerCase();
        // Cancelled is what actually gets written: closeLapsedEois and the site sweeper both use it.
        return normalizedStatus == 'void' || normalizedStatus == 'voided' || normalizedStatus == 'cancelled';
    }
}