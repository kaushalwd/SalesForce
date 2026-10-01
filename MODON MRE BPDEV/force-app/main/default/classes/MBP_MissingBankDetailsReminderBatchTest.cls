@IsTest
public class MBP_MissingBankDetailsReminderBatchTest {

    private class SendGridMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(202);
            res.setBody('{"message":"accepted"}');
            return res;
        }
    }

    @IsTest
    static void test_execute_allStages() {

        Test.setMock(HttpCalloutMock.class, new SendGridMock());

        Database.DMLOptions dml = new Database.DMLOptions();
        dml.DuplicateRuleHeader.allowSave = true;
        
        List<Account> accs = new List<Account>{
            new Account(
                Name = 'MBP Bank Missing - Stage1',
                RecordTypeId = BRConstants.BROKER_AGENCY_RT
            ),
                new Account(
                    Name = 'MBP Bank Missing - Stage2',
                    RecordTypeId = BRConstants.BROKER_AGENCY_RT,
                    Last_Bank_Reminder_Date__c = Date.today().addDays(-16)
                ),
                new Account(
                    Name = 'MBP Bank Missing - Stage3',
                    RecordTypeId = BRConstants.BROKER_AGENCY_RT,
                    Last_Bank_Reminder_Date__c = Date.today().addDays(-30)
                ),
                new Account(
                    Name = 'MBP Bank Missing - No Recipients',
                    RecordTypeId = BRConstants.BROKER_AGENCY_RT
                )
                };
                    
                    for(Account a : accs){
                        a.setOptions(dml);
                    }
        
        insert accs;
        
        Account a1 = [Select id,Trade_License_Status__c,Bank_Status__c from Account where Name = 'MBP Bank Missing - Stage1'];
        Account a2 = [Select id,Trade_License_Status__c,Bank_Status__c from Account where Name = 'MBP Bank Missing - Stage2'];
        Account a3 = [Select id,Trade_License_Status__c,Bank_Status__c from Account where Name = 'MBP Bank Missing - Stage3'];
        Account aNoRecipients =  [Select id,Trade_License_Status__c,Bank_Status__c from Account where Name = 'MBP Bank Missing - No Recipients'];
        
        insert new Contact(
            LastName = 'Admin One',
            AccountId = a1.id,
            Email = 'admin1@test.com',
            Broker_Type__c = BRConstants.AGENT_TYPE_AGENCYADMIN
        );

        insert new Contact(
            LastName = 'Owner Two',
            AccountId = a2.id,
            Email = 'owner2@test.com',
            Broker_Type__c = BRConstants.AGENT_TYPE_OWNER
        );

        insert new Contact(
            LastName = 'Admin Three',
            AccountId =  a3.id,
            Email = 'admin3@test.com',
            Broker_Type__c = BRConstants.AGENT_TYPE_AGENCYADMIN
        );

        insert new Contact(
            LastName = 'Skip Blank Email',
            AccountId =  a3.id,
            Email = null,
            Broker_Type__c = BRConstants.AGENT_TYPE_OWNER
        );

        Test.startTest();
        new MBP_MissingBankDetailsReminderBatch().execute(null, new List<Account>{ a1, a2, a3, aNoRecipients });
        Test.stopTest();
    }

    @IsTest
    static void test_schedulable_execute_coverage_only() {
        Test.startTest();
        String cron = '0 0 0 1 1 ? 2099';
        System.schedule('MBP_MissingBankDetailsReminderBatchTestJob', cron, new MBP_MissingBankDetailsReminderBatch());
        Test.stopTest();
    }
}