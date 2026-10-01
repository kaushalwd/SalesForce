/**********************************************************************************************************************
* Name               : PassfortApprovalBatch
* Description        : Batch job to process Passfort approvals older than 90 days and set status to Expired
* Usage              : Executed via scheduled job to handle daily Passfort approval expirations.
*                      Runs for Account first, then chains itself for Contact, so a single scheduled
*                      job covers Business Accounts, Person Accounts and Contacts.
* Created By         : Rushi Patel - Horizontal Digital
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           Rushi Patel                 02 Sep 2026     Initial draft
* 2.0           Rushi Patel                 18 Sep 2026     Made the batch generic so the same expiry logic runs on
*                                                           Contact as well as Account. Account run chains Contact.
******************************************************************************************************************/
public class PassfortApprovalBatch implements Database.Batchable<sObject>, Schedulable {

    public static final String OBJECT_ACCOUNT = 'Account';
    public static final String OBJECT_CONTACT = 'Contact';

    private static final String STATUS_APPROVED = 'Approved';
    private static final String STATUS_EXPIRED  = 'Expired';

    // WHICH OBJECT THIS RUN PROCESSES - Account or Contact
    private final String objectApiName;

    // DEFAULT ENTRY POINT - STARTS WITH ACCOUNT AND CHAINS CONTACT AFTERWARDS
    public PassfortApprovalBatch() {
        this(OBJECT_ACCOUNT);
    }

    public PassfortApprovalBatch(String objectApiName) {
        this.objectApiName = objectApiName;
    }

    public Database.QueryLocator start(Database.BatchableContext BC) {

        // QUERY RECORDS WHERE APPROVAL DATE IS OLDER THAN 90 DAYS AND STATUS IS NOT YET EXPIRED.
        // Is_Passfort_Approved_Valid__c is the same 90 day formula on both objects.
        String query;

        if (OBJECT_CONTACT.equalsIgnoreCase(objectApiName)) {
            query = 'SELECT Id, PassfortApprovalStatus__c, PassfortRiskStatus__c, Passfort_Approval_Date__c ' +
                    'FROM Contact ' +
                    'WHERE Is_Passfort_Approved_Valid__c = false ' +
                    'AND Passfort_Approval_Date__c != null ' +
                    'AND PassfortApprovalStatus__c = \'' + STATUS_APPROVED + '\'';
        } else {
            query = 'SELECT Id, IsPersonAccount, PassfortApprovalStatus__c, PassfortApprovalStatus__pc, ' +
                    'PassfortRiskStatus__c, PassfortRiskStatus__pc, Passfort_Approval_Date__c ' +
                    'FROM Account ' +
                    'WHERE Is_Passfort_Approved_Valid__c = false ' +
                    'AND Passfort_Approval_Date__c != null ' +
                    'AND (PassfortApprovalStatus__c = \'' + STATUS_APPROVED + '\' ' +
                    'OR PassfortApprovalStatus__pc = \'' + STATUS_APPROVED + '\')';
        }

        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext BC, List<sObject> scope) {

        List<sObject> recordsToUpdate = new List<sObject>();

        for (sObject record : scope) {
            Boolean changed = false;

            // STANDARD FIELDS - PRESENT ON BUSINESS ACCOUNTS, PERSON ACCOUNTS AND CONTACTS
            if (STATUS_APPROVED.equals(record.get('PassfortApprovalStatus__c'))) {
                record.put('PassfortApprovalStatus__c', STATUS_EXPIRED);
                record.put('PassfortRiskStatus__c', null);
                changed = true;
            }

            // PERSON ACCOUNT ONLY - __pc FIELDS DO NOT EXIST ON CONTACT OR BUSINESS ACCOUNTS
            if (record instanceof Account) {
                Account acc = (Account) record;
                if (acc.IsPersonAccount && STATUS_APPROVED.equals(acc.PassfortApprovalStatus__pc)) {
                    acc.PassfortApprovalStatus__pc = STATUS_EXPIRED;
                    acc.PassfortRiskStatus__pc = null;
                    changed = true;
                }
            }

            // ADD TO UPDATE LIST IF ANY STATUS WAS EXPIRED
            if (changed) {
                recordsToUpdate.add(record);
            }
        }

        // UPDATE BATCH CHUNK - PARTIAL SUCCESS SO ONE BAD RECORD DOES NOT LOSE THE WHOLE CHUNK
        if (!recordsToUpdate.isEmpty()) {
            List<Database.SaveResult> saveResults = Database.update(recordsToUpdate, false);
            logFailures(saveResults, recordsToUpdate);
        }
    }

    public void finish(Database.BatchableContext BC) {
        // CHAIN THE CONTACT RUN ONCE THE ACCOUNT RUN IS COMPLETE.
        // Batch chaining is not permitted in a test context, so the test invokes the
        // Contact run directly through the constructor instead.
        if (OBJECT_ACCOUNT.equalsIgnoreCase(objectApiName) && !Test.isRunningTest()) {
            Database.executeBatch(new PassfortApprovalBatch(OBJECT_CONTACT), 200);
        }
    }

    // SCHEDULABLE EXECUTION - STARTS THE ACCOUNT RUN, WHICH THEN CHAINS CONTACT
    public void execute(SchedulableContext SC) {
        Database.executeBatch(new PassfortApprovalBatch(OBJECT_ACCOUNT), 200);
    }

    // RECORD ANY FAILED UPDATES SO AN EXPIRY THAT DID NOT APPLY IS TRACEABLE
    private void logFailures(List<Database.SaveResult> saveResults, List<sObject> recordsToUpdate) {

        List<Logger__c> logs = new List<Logger__c>();

        for (Integer i = 0; i < saveResults.size(); i++) {
            if (saveResults[i].isSuccess()) {
                continue;
            }
            List<String> messages = new List<String>();
            for (Database.Error err : saveResults[i].getErrors()) {
                messages.add(err.getStatusCode() + ': ' + err.getMessage());
            }
            Logger__c log = new Logger__c(
                ExecutingProcessName__c = 'Passfort Approval Expiry Batch',
                ClassName__c            = 'PassfortApprovalBatch',
                MethodName__c           = 'execute',
                LogType__c              = 'Apex Exception',
                Message__c              = objectApiName + ' ' + recordsToUpdate[i].Id
                                          + ' failed to expire - ' + String.join(messages, ' | ')
            );
            logs.add(log);
        }

        if (!logs.isEmpty()) {
            LoggerService.save(logs);
        }
    }
}