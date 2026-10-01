global with sharing class MBP_MasterplanSyncBatch
    implements Database.Batchable<SObject>, Database.Stateful, Database.AllowsCallouts {

    String unitStatusFilter;
    String unitPhaseFilter;

    global MBP_MasterplanSyncBatch() { }


        global MBP_MasterplanSyncBatch(String statusFilter, String phaseFilter) {
        this.unitStatusFilter = statusFilter;
        this.unitPhaseFilter = phaseFilter;
    }
        

    global Database.QueryLocator start(Database.BatchableContext bc) {
        // SOQL hardening: static SOQL with optional phase bind (no dynamic string assembly).
        if (String.isNotBlank(unitPhaseFilter)) {
            return Database.getQueryLocator([
                SELECT Id, Name, Masterplan_URL__c, Masterplan_Status__c,
                       Masterplan_Last_Sync__c, Masterplan_Error__c, Status__c
                FROM Unit__c
                WHERE Source_Entity__c != 'Modon - Egypt'
                AND Phase__c = :unitPhaseFilter
            ]);
        }
        return Database.getQueryLocator([
            SELECT Id, Name, Masterplan_URL__c, Masterplan_Status__c,
                   Masterplan_Last_Sync__c, Masterplan_Error__c, Status__c
            FROM Unit__c
            WHERE Source_Entity__c != 'Modon - Egypt'
        ]);
    }

    global void execute(Database.BatchableContext bc, List<Unit__c> scope) {
        List<Unit__c> unitsToUpdate = new List<Unit__c>();

        for (Unit__c u : scope) {
            try {
                MBP_ManagePropertiesController.MasterplanResult res =
                    MBP_ManagePropertiesController.fetchMasterplanLink(u.Name);

                u.Masterplan_Last_Sync__c = System.now();

                if (res != null && res.success && !String.isBlank(res.url)) {
                    u.Masterplan_URL__c    = res.url;
                    u.Masterplan_Status__c = 'Success';
                    u.Masterplan_Error__c  = null;
                } else {
                    u.Masterplan_URL__c    = null;
                    u.Masterplan_Status__c = 'Failed';

                    String msg =
                        (res != null && !String.isBlank(res.errorMessage))
                        ? res.errorMessage
                        : 'No URL returned from masterplan service';

                    u.Masterplan_Error__c = msg.left(3000); // avoid long text overflow
                }

                unitsToUpdate.add(u);
            } catch (Exception e) {
                u.Masterplan_URL__c      = null;
                u.Masterplan_Status__c   = 'Failed';
                u.Masterplan_Error__c    = e.getMessage().left(3000);
                u.Masterplan_Last_Sync__c = System.now();
                unitsToUpdate.add(u);

                System.debug(
                    LoggingLevel.ERROR,
                    'Error while fetching masterplan for Unit ' + u.Id + ' : ' + e.getMessage());
            }
        }

        if (!unitsToUpdate.isEmpty()) {
            update unitsToUpdate;
        }
    }

    global void finish(Database.BatchableContext bc) {
        System.debug('MBP_MasterplanSyncBatch finished.');
    }
}