/**********************************************************************************************************************
* Name               : LoggerRetentionBatchTest
* Description        : Unit tests for LoggerRetentionBatch. Verifies purge of expired target log types
*                      (Apex Exception, Service Exception, Mobile Exception, Flow Exception, OIC Error Log),
*                      retention of other log types, disable when retention days is 0, and
*                      LoggerServiceSetting__c (Logger_Retention_Days__c) configuration.
* Usage              : Run as Apex test class LoggerRetentionBatchTest
* Created By         : Harsh Mathur
* --------------------------------------------------------------------------------------------------------------------
* Version  Author                  Date            Comment
* 1.0      Harsh Mathur            27 Aug 2026     Initial test coverage for logger retention batch
**********************************************************************************************************************/
@isTest
private class LoggerRetentionBatchTest {

    @TestSetup
    static void setupTestData() {
        insert new List<Logger__c>{
            new Logger__c(LogType__c = 'Apex Exception', Message__c = 'Old exception'),
            new Logger__c(LogType__c = 'Apex Exception', Message__c = 'Recent exception'),
            new Logger__c(LogType__c = 'Callout Log', Message__c = 'Old audit'),
            new Logger__c(LogType__c = 'OIC Error Log', Message__c = 'Old OIC log')
        };
    }

    @isTest
    static void testDeletesOnlyExpiredTargetLogTypes() {
        Map<String, Logger__c> logsByMessage = new Map<String, Logger__c>();
        for (Logger__c log : [SELECT Id, Message__c, LogType__c FROM Logger__c]) {
            logsByMessage.put(log.Message__c, log);
        }

        Test.setCreatedDate(logsByMessage.get('Old exception').Id, DateTime.now().addDays(-200));
        Test.setCreatedDate(logsByMessage.get('Recent exception').Id, DateTime.now().addDays(-1));
        Test.setCreatedDate(logsByMessage.get('Old audit').Id, DateTime.now().addDays(-200));
        Test.setCreatedDate(logsByMessage.get('Old OIC log').Id, DateTime.now().addDays(-200));

        Test.startTest();
        Database.executeBatch(new LoggerRetentionBatch(180), 2000);
        Test.stopTest();

        Map<String, Logger__c> remainingByMessage = new Map<String, Logger__c>();
        for (Logger__c log : [SELECT Id, Message__c, LogType__c FROM Logger__c]) {
            remainingByMessage.put(log.Message__c, log);
        }

        System.assertEquals(2, remainingByMessage.size(), 'Expired target log types should be purged');
        System.assert(remainingByMessage.containsKey('Recent exception'), 'Recent exception log should remain');
        System.assert(remainingByMessage.containsKey('Old audit'), 'Callout Log audit records must be retained');
        System.assertEquals(false, remainingByMessage.containsKey('Old exception'), 'Expired Apex Exception should be deleted');
        System.assertEquals(false, remainingByMessage.containsKey('Old OIC log'), 'Expired OIC Error Log should be deleted');
    }

    @isTest
    static void testDisabledWhenRetentionIsZero() {
        List<Logger__c> logs = [
            SELECT Id
            FROM Logger__c
            WHERE LogType__c IN ('Apex Exception', 'OIC Error Log')
        ];
        for (Logger__c log : logs) {
            Test.setCreatedDate(log.Id, DateTime.now().addDays(-200));
        }

        Test.startTest();
        Database.executeBatch(new LoggerRetentionBatch(0), 2000);
        Test.stopTest();

        System.assertEquals(4, [SELECT COUNT() FROM Logger__c], 'No logs should be deleted when retention is 0');
    }

    @isTest
    static void testBatchUsesCustomSettingConfiguration() {
        LoggerServiceSetting__c setting = LoggerServiceSetting__c.getOrgDefaults();
        setting.Logger_Retention_Days__c = 180;
        upsert setting;

        List<Logger__c> logs = [
            SELECT Id
            FROM Logger__c
            WHERE LogType__c IN ('Apex Exception', 'OIC Error Log')
        ];
        for (Logger__c log : logs) {
            Test.setCreatedDate(log.Id, DateTime.now().addDays(-200));
        }

        Test.startTest();
        Database.executeBatch(new LoggerRetentionBatch(), 2000);
        Test.stopTest();

        System.assert(LoggerRetentionBatch.isEnabled(), 'Retention should be enabled from LoggerServiceSetting__c');
        System.assertEquals(1, [SELECT COUNT() FROM Logger__c], 'Only non-purge audit logs should remain');
        System.assertEquals(
            1,
            [SELECT COUNT() FROM Logger__c WHERE LogType__c = 'Callout Log'],
            'Callout Log audit records must be retained'
        );
    }

    @isTest
    static void testPurgesAllConfiguredLogTypes() {
        insert new List<Logger__c>{
            new Logger__c(LogType__c = 'Service Exception'),
            new Logger__c(LogType__c = 'Mobile Exception'),
            new Logger__c(LogType__c = 'Flow Exception')
        };

        for (Logger__c log : [
            SELECT Id
            FROM Logger__c
            WHERE LogType__c IN ('Service Exception', 'Mobile Exception', 'Flow Exception')
        ]) {
            Test.setCreatedDate(log.Id, DateTime.now().addDays(-200));
        }

        Test.startTest();
        Database.executeBatch(new LoggerRetentionBatch(180), 2000);
        Test.stopTest();

        System.assertEquals(
            0,
            [
                SELECT COUNT()
                FROM Logger__c
                WHERE LogType__c IN ('Service Exception', 'Mobile Exception', 'Flow Exception')
            ],
            'All configured purge log types should be deleted when expired'
        );
    }
}