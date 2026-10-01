/**********************************************************************************************************************
* Name               : LoggerRetentionBatch
* Description        : Purges Logger__c records older than the Compliance-approved retention period.
*                      Deletes only: Apex Exception, Service Exception, Mobile Exception,
*                      Flow Exception, and OIC Error Log.
*                      All other LogType__c values are retained.
*                      Retention days are read from hierarchy custom setting LoggerServiceSetting__c
*                      (Logger_Retention_Days__c). Set to 0 or leave blank to disable the job.
* Usage              : Database.executeBatch(new LoggerRetentionBatch(), 2000);
*                      LoggerRetentionScheduler.scheduleWeekly();
* Created By         : Harsh Mathur
* --------------------------------------------------------------------------------------------------------------------
* Version  Author                  Date            Comment
* 1.0      Harsh Mathur            24 Aug 2026     Initial Draft — R0-6 data retention
* 1.1      Harsh Mathur            24 Aug 2026     Scope delete to selected log types only
* 1.2      Harsh Mathur            24 Aug 2026     Include OIC Error Log; default retention 180 days
* 1.3      Harsh Mathur            27 Aug 2026     Read retention days from LoggerServiceSetting__c
**********************************************************************************************************************/
public class LoggerRetentionBatch implements Database.Batchable<SObject>, Database.Stateful {

    private static final Integer DEFAULT_BATCH_SIZE = 2000;

    @TestVisible
    private static final Set<String> PURGE_LOG_TYPES = new Set<String>{
        'Apex Exception',
        'Service Exception',
        'Mobile Exception',
        'Flow Exception',
        'OIC Error Log'
    };

    @TestVisible
    private Integer retentionDaysOverride;

    public LoggerRetentionBatch() {}

    @TestVisible
    private LoggerRetentionBatch(Integer retentionDaysOverride) {
        this.retentionDaysOverride = retentionDaysOverride;
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        Integer retentionDays = resolveRetentionDays();

        if (retentionDays == null || retentionDays <= 0) {
            return emptyQueryLocator();
        }

        Datetime cutoffDate = System.now().addDays(-retentionDays);
        Set<String> purgeLogTypes = PURGE_LOG_TYPES;

        // QueryLocator does not honor Test.setCreatedDate; list SOQL does.
        if (Test.isRunningTest()) {
            Map<Id, Logger__c> toPurge = new Map<Id, Logger__c>([
                SELECT Id
                FROM Logger__c
                WHERE CreatedDate < :cutoffDate
                AND LogType__c IN :purgeLogTypes
            ]);
            return Database.getQueryLocator([
                SELECT Id
                FROM Logger__c
                WHERE Id IN :toPurge.keySet()
            ]);
        }

        return Database.getQueryLocator([
            SELECT Id
            FROM Logger__c
            WHERE CreatedDate < :cutoffDate
            AND LogType__c IN :purgeLogTypes
        ], AccessLevel.SYSTEM_MODE);
    }

    public void execute(Database.BatchableContext bc, List<Logger__c> scope) {
        if (scope == null || scope.isEmpty()) {
            return;
        }
        Database.delete(scope, false, AccessLevel.SYSTEM_MODE);
    }

    public void finish(Database.BatchableContext bc) {
    }

    public static Boolean isEnabled() {
        Integer retentionDays = resolveRetentionDays(null);
        return retentionDays != null && retentionDays > 0;
    }

    private Integer resolveRetentionDays() {
        return resolveRetentionDays(retentionDaysOverride);
    }

    private static Integer resolveRetentionDays(Integer retentionDaysOverride) {
        if (retentionDaysOverride != null) {
            return retentionDaysOverride;
        }

        LoggerServiceSetting__c setting = LoggerServiceSetting__c.getInstance();
        if (setting == null || setting.Logger_Retention_Days__c == null) {
            return null;
        }

        return Integer.valueOf(setting.Logger_Retention_Days__c);
    }

    private static Database.QueryLocator emptyQueryLocator() {
        return Database.getQueryLocator(
            'SELECT Id FROM Logger__c WHERE Id = null',
            AccessLevel.SYSTEM_MODE
        );
    }
}