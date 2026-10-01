/**
 * EoiSiteActivityPurge — deletes the microsite activity-diary Tasks older than
 * EOI_Site_Activity_Retention_Days (MEOI-ACT). Selects ONLY Tasks carrying
 * EOI_Site_Activity_Key__c, so milestone Tasks and every other Task in the org are untouched.
 * Schedule once (daily) with System.schedule; self-contained, no state.
 * @author Aurelix
 */
public without sharing class EoiSiteActivityPurge implements Schedulable, Database.Batchable<SObject> {

    public void execute(SchedulableContext sc) {
        Database.executeBatch(this, 200);
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        Datetime cutoff = System.now().addDays(-EoiSiteActivityService.retentionDays());
        return Database.getQueryLocator([
            SELECT Id FROM Task
            WHERE EOI_Site_Activity_Key__c != null AND CreatedDate < :cutoff
        ]);
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        Database.delete(scope, false);
    }

    public void finish(Database.BatchableContext bc) {}
}