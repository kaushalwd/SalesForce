/**********************************************************************************************
 * Name           : PaymentLinkNotificationServiceTest
 * Description     : Verifies Payment_Link__c fires Email + SMS on create (Sent) and Expired, that the
 *                   messages are logged to Outbound_Message_Log__c, and that a link with no Booking
 *                   Fee Line is a no-op.
 **********************************************************************************************/
@IsTest
private class PaymentLinkNotificationServiceTest {

    private class SmsMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('[{"status":"success"}]');
            return res;
        }
    }

    @TestSetup
    static void setup() {
        Account acc = new Account(Name = 'PL Acc');
        Schema.RecordTypeInfo rt = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('OrganizationAccount');
        if (rt != null) {
            acc.RecordTypeId = rt.getRecordTypeId();
        }
        insert acc;

        Contact c = new Contact(
            FirstName = 'Test', LastName = 'Payer', AccountId = acc.Id,
            Email = 'pl.payer@example.com', MobilePhone = '+971500000000'
        );
        insert c;

        Project__c proj = new Project__c(Name = 'PL Project');
        insert proj;
        Phase__c phase = new Phase__c(Name = 'PL Phase', Project__c = proj.Id);
        insert phase;
        Unit__c unit = new Unit__c(
            Name = 'ZZ_PL_Unit', PlotAreasqm__c = 1.0, PlotNo__c = '1', Phase__c = phase.Id,
            Number_of_Bedrooms__c = '2', UnitClassification__c = 'Villa',
            Status__c = 'Available', Sub_Status__c = 'Un-Assigned', ApprovalStatus__c = 'Draft'
        );
        insert unit;

        Opportunity opp = new Opportunity(
            Name = 'PL Opp', StageName = 'Discussion In Progress', CloseDate = System.today(),
            UAE_Resident_Status__c = 'Resident', Nationality__c = 'United Arab Emirates',
            EmiratesIDExpiryDate__c = Date.today().addDays(365), EIDNumber__c = '784-1232-1234567-4',
            PrimaryContact__c = c.Id
        );
        insert opp;

        insert new Booking_Fee_Line__c(
            Opportunity__c = opp.Id, Unit__c = unit.Id, Type__c = 'ADM & Dari',
            Total_Amount__c = 131036.32, Status__c = 'Pending'
        );
    }

    @IsTest
    static void testSentSendsEmailAndSms() {
        Booking_Fee_Line__c bfl = [SELECT Id FROM Booking_Fee_Line__c LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new SmsMock());

        Test.startTest();
        Payment_Link__c link = new Payment_Link__c(
            Status__c = 'Sent',
            Payment_URL__c = 'https://pay.sandbox.checkout.com/link/pl_test',
            CheckoutId__c = 'pl_test',
            Booking_Fee_Line__c = bfl.Id,
            Expiry_Timestamp__c = System.now().addHours(24)
        );
        insert link;
        Test.stopTest();

        List<Outbound_Message_Log__c> logs = [
            SELECT Channel__c, Message_Type__c FROM Outbound_Message_Log__c WHERE Related_Record_Id__c = :link.Id
        ];
        System.assertEquals(2, logs.size(), 'Email + SMS logs expected for a sent link');
        Set<String> channels = new Set<String>();
        for (Outbound_Message_Log__c l : logs) {
            System.assertEquals('Payment Link Sent', l.Message_Type__c, 'Message type should be Payment Link Sent');
            channels.add(l.Channel__c);
        }
        System.assert(channels.contains('Email') && channels.contains('SMS'), 'Both channels should be logged');
    }

    @IsTest
    static void testExpiredSendsNotice() {
        Booking_Fee_Line__c bfl = [SELECT Id FROM Booking_Fee_Line__c LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new SmsMock());

        Test.startTest();
        Payment_Link__c link = new Payment_Link__c(
            Status__c = 'Sent',
            Payment_URL__c = 'https://pay.sandbox.checkout.com/link/pl_exp',
            CheckoutId__c = 'pl_exp',
            Booking_Fee_Line__c = bfl.Id,
            Expiry_Timestamp__c = System.now().addHours(1)
        );
        insert link;
        link.Status__c = 'Expired';
        update link;
        Test.stopTest();

        List<Outbound_Message_Log__c> expired = [
            SELECT Id FROM Outbound_Message_Log__c
            WHERE Related_Record_Id__c = :link.Id AND Message_Type__c = 'Payment Link Expired'
        ];
        System.assertEquals(2, expired.size(), 'Email + SMS expiry notices expected');
    }

    @IsTest
    static void testNoBookingFeeLineIsNoOp() {
        Test.setMock(HttpCalloutMock.class, new SmsMock());

        Test.startTest();
        Payment_Link__c link = new Payment_Link__c(
            Status__c = 'Sent',
            Payment_URL__c = 'https://pay.sandbox.checkout.com/link/pl_nobfl',
            CheckoutId__c = 'pl_nobfl'
        );
        insert link;
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Outbound_Message_Log__c WHERE Related_Record_Id__c = :link.Id],
            'A link with no Booking Fee Line should send nothing');
    }
}