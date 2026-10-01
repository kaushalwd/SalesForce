@IsTest
public class MBP_TradeLicenseExpiryBatchTest {

    private class SendGridMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(202);
            res.setBody('{"message":"accepted"}');
            return res;
        }
    }

    private static Account createBrokerAgencyAccount(Date expiryDate, String name) {
        Account a = new Account(
            Name = name,
            RecordTypeId = BRConstants.BROKER_AGENCY_RT,
            TradeLicenseExpiryDate__c = expiryDate
        );
        insert a;
        return a;
    }

    private static Contact addContact(Id accountId, String lastName, String email, String brokerType) {
        Contact c = new Contact(
            LastName = lastName,
            AccountId = accountId,
            Email = email,
            Broker_Type__c = brokerType
        );
        insert c;
        return c;
    }

    @IsTest
    static void test_execute_reminders_and_expiryDay_and_finish() {

        Test.setMock(HttpCalloutMock.class, new SendGridMock());

        Date today = Date.today();

        Account a30 = createBrokerAgencyAccount(today.addDays(30), 'TL-30');
        addContact(a30.Id, 'Admin30', 'admin30@test.com', BRConstants.AGENT_TYPE_AGENCYADMIN);
        addContact(a30.Id, 'Owner30', 'owner30@test.com', BRConstants.AGENT_TYPE_OWNER);

        Account a15 = createBrokerAgencyAccount(today.addDays(15), 'TL-15');
        addContact(a15.Id, 'Admin15', 'admin15@test.com', BRConstants.AGENT_TYPE_AGENCYADMIN);
        addContact(a15.Id, 'Owner15', 'owner15@test.com', BRConstants.AGENT_TYPE_OWNER);

        Account a1 = createBrokerAgencyAccount(today.addDays(1), 'TL-1');
        addContact(a1.Id, 'Admin1', 'admin1@test.com', BRConstants.AGENT_TYPE_AGENCYADMIN);
        addContact(a1.Id, 'Owner1', 'owner1@test.com', BRConstants.AGENT_TYPE_OWNER);

        Account a0 = createBrokerAgencyAccount(today, 'TL-0');

        Contact admin0 = addContact(a0.Id, 'Admin0', 'admin0@test.com', BRConstants.AGENT_TYPE_AGENCYADMIN);
        Contact owner0 = addContact(a0.Id, 'Owner0', 'owner0@test.com', BRConstants.AGENT_TYPE_OWNER);
        Contact agent0 = addContact(a0.Id, 'Agent0', 'agent0@test.com', 'Agent');

        List<Account> scope = [
            SELECT Id, Name, TradeLicenseExpiryDate__c,Trade_License_Status__c,Agency_Status__c,
            Agency_Status_Reason__c,
            
            Bank_Status__c,
                   (SELECT Id, Name, Email, Broker_Type__c, Agent_Status__c,Primary_Owner__c  FROM Contacts)
            FROM Account
            WHERE Id IN :new Set<Id>{ a30.Id, a15.Id, a1.Id, a0.Id }
        ];

        MBP_TradeLicenseExpiryBatch b = new MBP_TradeLicenseExpiryBatch();

        // MCR-48: mixed reminder + expiry-day accounts in one execute must not DML-in-loop.
        Test.startTest();
        b.execute(null, scope);
        b.finish(null);
        Test.stopTest();
    }

    @IsTest
    static void test_schedulable_execute() {
        Test.startTest();
        System.schedule(
            'MBP_TradeLicenseExpiryBatchTestJob',
            '0 0 0 1 1 ? 2099',
            new MBP_TradeLicenseExpiryBatch()
        );
        Test.stopTest();
    }
}