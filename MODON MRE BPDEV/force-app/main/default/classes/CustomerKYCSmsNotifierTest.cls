/**********************************************************************************************
 * Name            : CustomerKYCSmsNotifierTest
 * Description     : Covers the KYC link SMS leg - that a Person Account and each Power of Attorney
 *                   Contact get an SMS-only Outbound_Message_Log__c, that records with no phone or
 *                   no KYC link are skipped, and that the text stays inside one SMS segment.
 * Created By      : Rushi Patel
 * --------------------------------------------------------------------------------------------
 * Version    Author            Date              Comment
 * 1.0        Rushi Patel       22 September 2026  Initial version.
 **********************************************************************************************/
@IsTest
private class CustomerKYCSmsNotifierTest {

    private static final String KYC_LINK = 'https://kyc.signzy.ae/0KHC1VQRRQ';

    private class SmsMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('[{"status":"success"}]');
            return res;
        }
    }

    private static void stubCredential() {
        CommunicationApiSmsClient.credentialOverride = new OIC_Credential__mdt(
            DeveloperName = 'CommunicationAPI',
            Endpoint__c = 'https://example.com/sms',
            Username__c = 'u',
            Password__c = 'p'
        );
    }

    @TestSetup
    static void setup() {
        Account person = new Account(
            FirstName = 'Aisha',
            LastName = 'Individual',
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId(),
            PersonEmail = 'aisha.individual@example.com',
            PersonMobilePhone = '+971500000000',
            Nationality__pc = 'United Arab Emirates',
            UAE_Resident_Status__pc = 'Resident'
        );
        insert person;
        // Person account link lives on the contact side of the record.
        update new Account(Id = person.Id, KYCSiteLink__pc = KYC_LINK);

        Account org = new Account(
            Name = 'Test Corporate Account',
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('OrganizationAccount').getRecordTypeId(),
            Legal_Type__c = 'LLC'
        );
        insert org;

        insert new Contact(
            FirstName = 'Omar',
            LastName = 'PoaContact',
            AccountId = org.Id,
            Email = 'omar.poa@example.com',
            MobilePhone = '+971500000001',
            KYCSiteLink__c = KYC_LINK
        );
    }

    @IsTest
    static void testPersonAccountGetsSmsOnly() {
        stubCredential();
        Test.setMock(HttpCalloutMock.class, new SmsMock());
        Account acc = [SELECT Id FROM Account WHERE LastName = 'Individual' LIMIT 1];

        Test.startTest();
        CustomerKYCSmsNotifier.sendForAccount(acc.Id);
        Test.stopTest();

        List<Outbound_Message_Log__c> logs = [
            SELECT Channel__c, Message_Type__c, Recipient__c, Payload__c, Status__c, Related_Object__c
            FROM Outbound_Message_Log__c
            WHERE Related_Record_Id__c = :acc.Id
        ];
        System.assertEquals(1, logs.size(), 'Only the SMS leg should be logged; email stays with the flow');
        System.assertEquals('SMS', logs[0].Channel__c, 'Channel should be SMS');
        System.assertEquals('KYC Link Sent', logs[0].Message_Type__c, 'Message type should identify the KYC link');
        System.assertEquals('Account', logs[0].Related_Object__c, 'Related object should be Account');
        System.assertEquals('+971500000000', logs[0].Recipient__c, 'Recipient should be the person mobile phone');
        System.assert(logs[0].Payload__c.contains(KYC_LINK), 'The SMS text should carry the KYC link');
        System.assert(logs[0].Payload__c.contains('Aisha'), 'The SMS text should greet the customer by first name');
    }

    @IsTest
    static void testPoaContactGetsSms() {
        stubCredential();
        Test.setMock(HttpCalloutMock.class, new SmsMock());
        Contact con = [SELECT Id FROM Contact WHERE LastName = 'PoaContact' LIMIT 1];

        Test.startTest();
        CustomerKYCSmsNotifier.sendForContacts(new Set<Id>{ con.Id });
        Test.stopTest();

        List<Outbound_Message_Log__c> logs = [
            SELECT Channel__c, Recipient__c, Related_Object__c, Payload__c
            FROM Outbound_Message_Log__c
            WHERE Related_Record_Id__c = :con.Id
        ];
        System.assertEquals(1, logs.size(), 'The POA contact should get one SMS log');
        System.assertEquals('SMS', logs[0].Channel__c, 'Channel should be SMS');
        System.assertEquals('Contact', logs[0].Related_Object__c, 'Related object should be Contact');
        System.assert(logs[0].Payload__c.contains(KYC_LINK), 'The SMS text should carry the KYC link');
    }

    @IsTest
    static void testNoPhoneAndNoLinkAreSkipped() {
        stubCredential();
        Test.setMock(HttpCalloutMock.class, new SmsMock());
        Account acc = [SELECT Id FROM Account WHERE LastName = 'Individual' LIMIT 1];
        Contact con = [SELECT Id FROM Contact WHERE LastName = 'PoaContact' LIMIT 1];
        update new Account(Id = acc.Id, PersonMobilePhone = null);
        update new Contact(Id = con.Id, KYCSiteLink__c = null);

        Test.startTest();
        CustomerKYCSmsNotifier.sendForAccount(acc.Id);
        CustomerKYCSmsNotifier.sendForContacts(new Set<Id>{ con.Id });
        CustomerKYCSmsNotifier.sendForAccount(null);
        CustomerKYCSmsNotifier.sendForContacts(new Set<Id>());
        Test.stopTest();

        System.assertEquals(
            0,
            [SELECT COUNT() FROM Outbound_Message_Log__c],
            'No SMS should be logged when the phone or the KYC link is missing');
    }

    @IsTest
    static void testNameAndLinkSurviveTheApprovedCopy() {
        String text = CustomerKYCSmsNotifier.buildSmsText('Aisha', KYC_LINK);

        System.assert(text.contains(KYC_LINK), 'The link must be in the SMS');
        System.assert(text.contains('Aisha'), 'The customer name must be kept at the approved copy length');
        System.assert(text.contains('800 66366'), 'The contact number must be in the SMS');
        System.assert(!text.contains('{!'), 'Every merge token must be substituted');
    }

    /**
     * description : The approved copy is longer than one segment, so the name-drop guard cannot get it
     *               to 160 and must leave the personalised text alone rather than silently degrade it.
     *               If the copy is ever shortened below 160 this guard starts working again.
     */
    @IsTest
    static void testOverLongNameDoesNotStripPersonalisationNeedlessly() {
        String text = CustomerKYCSmsNotifier.buildSmsText('Aisha', KYC_LINK);

        System.assert(
            text.length() > CustomerKYCSmsNotifier.SMS_MAX_CHARS,
            'The approved KYC copy is expected to span more than one SMS segment');
        System.assert(text.contains('Aisha'), 'The name should not be dropped when dropping it would not help');
    }
}