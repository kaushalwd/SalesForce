/**********************************************************************************************************************
* Name               : UnitAutoUnblockSchedulable                                                        
* Description        : Schedulable job executed when a Unit's blocked timer expires. If the unit's status
*                      has not transitioned to 'Reserved', it automatically resets the status to 'Available'
*                      and clears all blocking metadata.
* Usage              : System.schedule(jobName, cronStr, new UnitAutoUnblockSchedulable(unitIds));
* Created By         : MODON CRM Team
******************************************************************************************************************/
public without sharing class UnitAutoUnblockSchedulable implements Schedulable, Database.AllowsCallouts {

    @TestVisible private Set<Id> unitIds;

    public UnitAutoUnblockSchedulable() {
        this.unitIds = new Set<Id>();
    }

    public UnitAutoUnblockSchedulable(Set<Id> unitIds) {
        this.unitIds = (unitIds != null) ? unitIds : new Set<Id>();
    }

    public void execute(SchedulableContext sc) {
        // Automatically clean up this one-time scheduled trigger
        if (sc != null && sc.getTriggerId() != null) {
            try {
                System.abortJob(sc.getTriggerId());
            } catch (Exception e) {
                System.debug(LoggingLevel.WARN, 'UnitAutoUnblockSchedulable: Could not abort trigger: ' + e.getMessage());
            }
        }

        if (this.unitIds == null || this.unitIds.isEmpty()) {
            return;
        }

        List<Unit__c> unitsToRelease = new List<Unit__c>();
        for (Unit__c unit : [
            SELECT Id, Status__c, BlockedFor__c, BlockedBy__c, BlockUntil__c, BlockComment__c, Blocked_Time__c
            FROM Unit__c
            WHERE Id IN :this.unitIds
        ]) {
            // If the unit has NOT moved to Reserved, reset back to Available
            if (unit.Status__c != 'Reserved') {
                unit.Status__c        = 'Available';
                unit.BlockedFor__c    = null;
                unit.BlockedBy__c     = null;
                unit.BlockUntil__c    = null;
                unit.BlockComment__c  = null;
                unit.Blocked_Time__c  = null;
                unitsToRelease.add(unit);
            }
        }

        if (!unitsToRelease.isEmpty()) {
            Database.update(unitsToRelease, false);
            System.debug(LoggingLevel.INFO, 'UnitAutoUnblockSchedulable: Released ' + unitsToRelease.size() + ' unit(s) to Available.');
        }
    }
}