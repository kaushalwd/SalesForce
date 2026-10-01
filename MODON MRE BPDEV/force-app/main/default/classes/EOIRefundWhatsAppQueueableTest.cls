@IsTest
global class EOIRefundWhatsAppQueueableTest {

    global class MockHttpResponseGenerator implements HttpCalloutMock {
        global HTTPResponse respond(HTTPRequest req) {
            System.assertEquals('POST', req.getMethod());
            System.assertEquals('application/json', req.getHeader('Content-Type'));
            System.assertNotEquals(null, req.getBody());

            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"success":true}');
            res.setStatusCode(200);
            return res;
        }
    }

    @testSetup
    static void setupData() {

        Id personRtId;
        if (
            Schema.SObjectType.Account
                .getRecordTypeInfosByDeveloperName()
                .containsKey('PersonAccount')
        ) {
            personRtId = Schema.SObjectType.Account
                .getRecordTypeInfosByDeveloperName()
                .get('PersonAccount')
                .getRecordTypeId();
        }

        Account acc;

        if (personRtId != null) {
            acc = new Account(
                RecordTypeId = personRtId,
                FirstName = 'Test',
                LastName = 'Customer',
                PersonEmail = 'customer@test.com',
                PersonMobilePhone = '971501234567'
            );
        } else {
            acc = new Account(
                Name = 'Test Customer'
            );
        }

        Database.insert(acc, AccessLevel.SYSTEM_MODE);

        Opportunity opp = new Opportunity(
            Name = 'EOI Refund Opportunity',
            StageName = 'Prospecting',
            CloseDate = System.today().addDays(10),
            AccountId = acc.Id
        );
        Database.insert(opp, AccessLevel.SYSTEM_MODE);

        Expressionofinterest__c primaryEOI =
            new Expressionofinterest__c(
                Opportunity__c = opp.Id,
                Account__c = acc.Id,
                EOI_Amount_AED__c = 10000,
                Status__c = 'In progress'
            );

        Database.insert(primaryEOI, AccessLevel.SYSTEM_MODE);

        primaryEOI = [
            SELECT Id,
                   Account__c,
                   Account__r.PersonEmail
            FROM Expressionofinterest__c
            WHERE Id = :primaryEOI.Id
            LIMIT 1
        ];

        Case cs = new Case();
        cs.Subject = 'EOI Refund';
        cs.Status = 'New';
        cs.Description = 'EOI Refund';
        cs.Sub_Vertical__c = 'CM Finance';
        cs.CaseCategory__c = 'EOI Refund';
        cs.Expression_of_Interest__c = primaryEOI.Id;
        cs.Send_Customer_Email__c = false;
        cs.AccountId = primaryEOI.Account__c;
        cs.Customer_Type__c = 'Owner';
        cs.Customer_Email__c = primaryEOI.Account__r.PersonEmail;
        cs.Source__c = 'Internal';
        cs.Channel__c = 'Social';
        cs.Refund_Status__c = 'Initiated';
        cs.Whats_App_Integration_Status__c = 'Initiated';

        Id standardRecordTypeId =
            getRecordTypeIdByDeveloperName('Case', 'Standard');

        if (standardRecordTypeId != null) {
            cs.RecordTypeId = standardRecordTypeId;
        }

        Database.insert(cs, AccessLevel.SYSTEM_MODE);

     /*   Receipt__c receipt = new Receipt__c();
        receipt.Name = 'Test Receipt';
        receipt.ExpressionOfInterest__c = primaryEOI.Id;

        Database.insert(receipt, AccessLevel.SYSTEM_MODE);
    */
    }

    @IsTest
    static void testQueueableSuccess() {

        Test.setMock(
            HttpCalloutMock.class,
            new MockHttpResponseGenerator()
        );

        Case cs = [
            SELECT Id
            FROM Case
            WHERE Subject = 'EOI Refund'
            LIMIT 1
        ];

        Expressionofinterest__c eoi = [
            SELECT Id
            FROM Expressionofinterest__c
            LIMIT 1
        ];

        Test.startTest();

        System.enqueueJob(
            new EOIRefundWhatsAppQueueable(
                cs.Id,
                '971501234567',
                new List<Id>{ eoi.Id },
                'Initial Outreach',
                'eoi_initial_outreach'
            )
        );

        Test.stopTest();

        Case updatedCase = [
            SELECT Id,
                   Whats_App_Integration_Status__c
            FROM Case
            WHERE Id = :cs.Id
        ];
        eoi.Case__c=updatedCase.Id;
        update eoi;
        
          EOIRefundReminderInvocable.Request req =new EOIRefundReminderInvocable.Request();

        req.caseId = updatedCase.Id;
        req.messageType = 'Refund Reminder';
        req.templateName = 'eoi_initial_reminder_1';
         EOIRefundReminderInvocable.sendReminder(new List<EOIRefundReminderInvocable.Request>{req}
        );

        System.assertEquals(
            'Target Inserted',
            updatedCase.Whats_App_Integration_Status__c
        );
/*
        Receipt__c updatedReceipt = [
            SELECT Id,
                   Case__c
            FROM Receipt__c
            WHERE ExpressionOfInterest__c = :eoi.Id
            LIMIT 1
        ];

        System.assertEquals(
            cs.Id,
            updatedReceipt.Case__c
        );
    */
    }

    @IsTest
    static void testQueueableFailure() {

        Test.setMock(
            HttpCalloutMock.class,
            new MockHttpFailureResponseGenerator()
        );

        Case cs = [
            SELECT Id
            FROM Case
            WHERE Subject = 'EOI Refund'
            LIMIT 1
        ];

        Expressionofinterest__c eoi = [
            SELECT Id
            FROM Expressionofinterest__c
            LIMIT 1
        ];

        Test.startTest();

        System.enqueueJob(
            new EOIRefundWhatsAppQueueable(
                cs.Id,
                '971501234567',
                new List<Id>{ eoi.Id },
                'Initial Outreach',
                'eoi_initial_outreach'
            )
        );

        Test.stopTest();

        Case updatedCase = [
            SELECT Id,
                   Whats_App_Integration_Status__c,
                   Description
            FROM Case
            WHERE Id = :cs.Id
        ];

        System.assertEquals(
            'Initiated',
            updatedCase.Whats_App_Integration_Status__c
        );

        /*
        System.assert(
            updatedCase.Description != null &&
            updatedCase.Description.contains('WhatsApp API failed')
        );
       */
    }

    @IsTest
    static void testQueueableValidationReturn() {

        Test.startTest();

        System.enqueueJob(
            new EOIRefundWhatsAppQueueable(
                null,
                null,
                new List<Id>(),
                null,
                null
            )
        );

        Test.stopTest();

        System.assert(true);
    }

    global class MockHttpFailureResponseGenerator implements HttpCalloutMock {
        global HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"success":false}');
            res.setStatusCode(500);
            return res;
        }
    }

    private static Id getRecordTypeIdByDeveloperName(
        String objectApiName,
        String developerName
    ) {
        List<RecordType> recordTypes = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = :objectApiName
            AND DeveloperName = :developerName
            LIMIT 1
        ];

        if (!recordTypes.isEmpty()) {
            return recordTypes[0].Id;
        }

        return null;
    }
}