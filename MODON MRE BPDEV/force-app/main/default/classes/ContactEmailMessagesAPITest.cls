@IsTest
public class ContactEmailMessagesAPITest {

    // Find a Person Account Record Type safely
    private static Id getPersonAccountRtId() {
        for (Schema.RecordTypeInfo rti : Schema.SObjectType.Account.getRecordTypeInfos()) {
            if (rti.isAvailable() && rti.getName().toLowerCase().contains('person')) {
                return rti.getRecordTypeId();
            }
        }
        return null;
    }

    /**
     * Creates an EmailMessage "received" by contactId. EmailMessage.ToIds isn't
     * supported in Apex test context (FIELD_INTEGRITY_EXCEPTION), so the
     * EmailMessageRelation the API queries is inserted directly instead.
     */
    private static void createReceivedEmail(Id contactId, String subject, String body, Datetime messageDate) {
        EmailMessage em = new EmailMessage(
            Subject     = subject,
            HtmlBody    = '<p>' + body + '</p>',
            TextBody    = body,
            Incoming    = true,
            MessageDate = messageDate
        );
        insert em;

        insert new EmailMessageRelation(
            EmailMessageId = em.Id,
            RelationId     = contactId,
            RelationType   = 'ToAddress'
        );
    }

    @TestSetup
    static void testData() {
        Id paRtId = getPersonAccountRtId();
        System.assertNotEquals(null, paRtId,
            'Person Accounts must be enabled and a Person Account record type must exist.');

        Account orgAccount = new Account(Name = 'Test Org Account');
        insert orgAccount;

        Contact orgContact = new Contact(
            FirstName = 'Org',
            LastName  = 'Contact',
            AccountId = orgAccount.Id,
            Email     = 'org.contact@example.com'
        );
        insert orgContact;

        Account personAccount = new Account(
            RecordTypeId = paRtId,
            LastName     = 'Person Contact',
            PersonEmail  = 'person.contact@example.com'
        );
        insert personAccount;

        // 6 emails received so ORDER BY MessageDate DESC LIMIT 5 can be verified.
        for (Integer i = 0; i < 6; i++) {
            createReceivedEmail(orgContact.Id, 'Org Subject ' + i, 'Org Body ' + i,
                                 Datetime.now().addMinutes(-i));
        }
    }

    @IsTest
    static void test_organizationAccountContact_returnsLatestFiveEmails() {
        Contact con = [SELECT Id FROM Contact WHERE LastName = 'Contact' LIMIT 1];

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/contact-emails/v1/' + con.Id;
        req.httpMethod = 'GET';

        RestResponse res = new RestResponse();
        RestContext.request  = req;
        RestContext.response = res;

        Test.startTest();
        ContactEmailMessagesAPI.doGet();
        Test.stopTest();

        System.assertEquals(200, res.statusCode);
        ContactEmailMessagesAPI.ServiceResponse out = (ContactEmailMessagesAPI.ServiceResponse)
            JSON.deserialize(res.responseBody.toString(), ContactEmailMessagesAPI.ServiceResponse.class);

        System.assertEquals('SUCCESS', out.status);
        System.assertEquals(con.Id, out.contactId);
        System.assertEquals('Organization Account', out.accountType);
        System.assertEquals(5, out.recordCount);
        System.assertEquals(5, out.emailMessages.size());
        System.assertEquals('Org Subject 0', out.emailMessages[0].subject);
    }

    @IsTest
    static void test_contactId_viaQueryParam_works() {
        Contact con = [SELECT Id FROM Contact WHERE LastName = 'Contact' LIMIT 1];

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/contact-emails/v1';
        req.httpMethod = 'GET';
        req.addParameter('contactId', con.Id);

        RestResponse res = new RestResponse();
        RestContext.request  = req;
        RestContext.response = res;

        Test.startTest();
        ContactEmailMessagesAPI.doGet();
        Test.stopTest();

        System.assertEquals(200, res.statusCode);
    }

    @IsTest
    static void test_personAccountId_resolvesToPersonContactId() {
        Account personAccount = [
            SELECT Id, PersonContactId
            FROM Account
            WHERE LastName = 'Person Contact'
            LIMIT 1
        ];

        createReceivedEmail(personAccount.PersonContactId, 'Person Account Email', 'Hi', Datetime.now());

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/contact-emails/v1/' + personAccount.Id;
        req.httpMethod = 'GET';

        RestResponse res = new RestResponse();
        RestContext.request  = req;
        RestContext.response = res;

        Test.startTest();
        ContactEmailMessagesAPI.doGet();
        Test.stopTest();

        System.assertEquals(200, res.statusCode);
        ContactEmailMessagesAPI.ServiceResponse out = (ContactEmailMessagesAPI.ServiceResponse)
            JSON.deserialize(res.responseBody.toString(), ContactEmailMessagesAPI.ServiceResponse.class);

        System.assertEquals('SUCCESS', out.status);
        System.assertEquals('Person Account', out.accountType);
        System.assertEquals(personAccount.PersonContactId, out.contactId);
        System.assertEquals(1, out.recordCount);
    }

    @IsTest
    static void test_personContactId_direct_works() {
        Account personAccount = [
            SELECT Id, PersonContactId
            FROM Account
            WHERE LastName = 'Person Contact'
            LIMIT 1
        ];

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/contact-emails/v1/' + personAccount.PersonContactId;
        req.httpMethod = 'GET';

        RestResponse res = new RestResponse();
        RestContext.request  = req;
        RestContext.response = res;

        Test.startTest();
        ContactEmailMessagesAPI.doGet();
        Test.stopTest();

        System.assertEquals(200, res.statusCode);
        ContactEmailMessagesAPI.ServiceResponse out = (ContactEmailMessagesAPI.ServiceResponse)
            JSON.deserialize(res.responseBody.toString(), ContactEmailMessagesAPI.ServiceResponse.class);

        System.assertEquals('Person Account', out.accountType);
        System.assertEquals(personAccount.PersonContactId, out.contactId);
    }

    @IsTest
    static void test_organizationAccountId_isRejected() {
        Account orgAccount = [SELECT Id FROM Account WHERE Name = 'Test Org Account' LIMIT 1];

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/contact-emails/v1/' + orgAccount.Id;
        req.httpMethod = 'GET';

        RestResponse res = new RestResponse();
        RestContext.request  = req;
        RestContext.response = res;

        Test.startTest();
        ContactEmailMessagesAPI.doGet();
        Test.stopTest();

        System.assertEquals(400, res.statusCode);
        ContactEmailMessagesAPI.ServiceResponse out = (ContactEmailMessagesAPI.ServiceResponse)
            JSON.deserialize(res.responseBody.toString(), ContactEmailMessagesAPI.ServiceResponse.class);
        System.assertEquals('ERROR', out.status);
    }

    @IsTest
    static void test_missingId_returnsBadRequest() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/contact-emails/v1';
        req.httpMethod = 'GET';

        RestResponse res = new RestResponse();
        RestContext.request  = req;
        RestContext.response = res;

        Test.startTest();
        ContactEmailMessagesAPI.doGet();
        Test.stopTest();

        System.assertEquals(400, res.statusCode);
    }

    @IsTest
    static void test_invalidIdFormat_returnsBadRequest() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/contact-emails/v1/not-a-valid-id';
        req.httpMethod = 'GET';

        RestResponse res = new RestResponse();
        RestContext.request  = req;
        RestContext.response = res;

        Test.startTest();
        ContactEmailMessagesAPI.doGet();
        Test.stopTest();

        System.assertEquals(400, res.statusCode);
    }

    @IsTest
    static void test_unsupportedIdType_returnsBadRequest() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/contact-emails/v1/' + UserInfo.getUserId();
        req.httpMethod = 'GET';

        RestResponse res = new RestResponse();
        RestContext.request  = req;
        RestContext.response = res;

        Test.startTest();
        ContactEmailMessagesAPI.doGet();
        Test.stopTest();

        System.assertEquals(400, res.statusCode);
    }

    @IsTest
    static void test_contactNotFound_returnsNotFound() {
        Contact temp = new Contact(LastName = 'Temp Delete Me');
        insert temp;
        Id deletedContactId = temp.Id;
        delete temp;

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/contact-emails/v1/' + deletedContactId;
        req.httpMethod = 'GET';

        RestResponse res = new RestResponse();
        RestContext.request  = req;
        RestContext.response = res;

        Test.startTest();
        ContactEmailMessagesAPI.doGet();
        Test.stopTest();

        System.assertEquals(404, res.statusCode);
    }

    @IsTest
    static void test_accountNotFound_returnsNotFound() {
        Account temp = new Account(Name = 'Temp Delete Me');
        insert temp;
        Id deletedAccountId = temp.Id;
        delete temp;

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/contact-emails/v1/' + deletedAccountId;
        req.httpMethod = 'GET';

        RestResponse res = new RestResponse();
        RestContext.request  = req;
        RestContext.response = res;

        Test.startTest();
        ContactEmailMessagesAPI.doGet();
        Test.stopTest();

        System.assertEquals(404, res.statusCode);
    }

    @IsTest
    static void test_contactWithNoEmails_returnsSuccessWithZeroRecords() {
        Account noEmailAccount = new Account(Name = 'No Email Org Account');
        insert noEmailAccount;

        Contact noEmailContact = new Contact(
            FirstName = 'No',
            LastName  = 'Emails',
            AccountId = noEmailAccount.Id
        );
        insert noEmailContact;

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/contact-emails/v1/' + noEmailContact.Id;
        req.httpMethod = 'GET';

        RestResponse res = new RestResponse();
        RestContext.request  = req;
        RestContext.response = res;

        Test.startTest();
        ContactEmailMessagesAPI.doGet();
        Test.stopTest();

        System.assertEquals(200, res.statusCode);
        ContactEmailMessagesAPI.ServiceResponse out = (ContactEmailMessagesAPI.ServiceResponse)
            JSON.deserialize(res.responseBody.toString(), ContactEmailMessagesAPI.ServiceResponse.class);
        System.assertEquals('SUCCESS', out.status);
        System.assertEquals(0, out.recordCount);
    }
}