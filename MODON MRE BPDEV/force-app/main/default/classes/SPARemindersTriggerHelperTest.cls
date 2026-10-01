@isTest
private class SPARemindersTriggerHelperTest {

    // Mock class for HTTP callouts
    private class MockHttpResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');

            if(req.getEndpoint().contains('SPAWhatsappAPI')){
                res.setStatusCode(200);
                res.setBody('{"MessageId":"mockMsgId","BitlyURL":"https://bit.ly/mockUrl","Status":"sent"}');
            } else {
                res.setStatusCode(200);
                res.setBody('{}');
            }
            return res;
        }
    }
    
    @isTest
    static void testSendSPAReminder() {

        Id rtId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Person Account').getRecordTypeId();
        Account acc = new Account(FirstName = 'John54454223', LastName = 'Doe54454223', RecordTypeId = rtId);
        insert acc;
        
        // Create SalesOrder
        SalesOrder__c so = new SalesOrder__c(CustomerAccount__c = acc.Id);
        insert so;

        // Insert a DocuSign envelope record
        dfsle__EnvelopeStatus__c env = new dfsle__EnvelopeStatus__c(
            dfsle__DocuSignId__c = 'DOC123',
            dfsle__SourceId__c = so.Id,
            dfsle__Status__c = 'sent'
        );
        insert env;

        // Insert a WhatsApp record
        SPAWhatsapp__c wa = new SPAWhatsapp__c(
            Sales_Order__c = so.Id,
            EnvelopeId__c = 'DOC123',
            Status__c = 'sent',
            WhatsappURL__c = 'https://wa.me/12345'
        );
        insert wa;

        // Insert existing SPAReminder for retry count
        SPAReminders__c rem = new SPAReminders__c(
            CustomerName__c = acc.Name,
            Email__c = acc.PersonEmail,
            PhoneNumber__c = acc.PersonMobilePhone,
            NoOfReminders__c = 2,
            Sales_Order__c = so.Id
        );
        insert rem;

        // Call method under test
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        Test.startTest();
        String result = SPARemindersTriggerHelper.sendSPAReminder(so.Id);
        Test.stopTest();
    }

    @isTest
    static void testSendEmailMessage() {
        // Create test SPAReminder
        SPAReminders__c rem = new SPAReminders__c(
            CustomerName__c = 'Test Cust',
            Email__c = 'test@example.com',
            PhoneNumber__c = '0500000000'
        );
        insert rem;

        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        SPARemindersTriggerHelper.sendEmailMessage(new List<SObject>{rem});
        Test.stopTest();
    }

    @isTest
    static void testSendWhatsappMessageAndAPI() {
        // Create test SPAReminder
        SPAReminders__c rem = new SPAReminders__c(
            CustomerName__c = 'John Doe',
            Email__c = 'john@example.com',
            PhoneNumber__c = '0501112222',
            DocuSignURL__c = 'https://docusign.com/test',
            WhatsappURL__c = 'https://wa.me/98765'
        );
        insert rem;

        // Call WhatsApp send method
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        SPARemindersTriggerHelper.sendWhatsappMessage(new List<SObject>{rem});
        SPARemindersTriggerHelper.sendWhatsappMessageOICAPINoBatch(new List<SObject>{rem});
        Test.stopTest();
    }

    @isTest
    static void testSendWhatsappMessageOICAPI() {
        // Create test SPAReminder
        SPAReminders__c rem = new SPAReminders__c(
            CustomerName__c = 'John Doe',
            Email__c = 'john@example.com',
            PhoneNumber__c = '0501112222',
            DocuSignURL__c = 'https://docusign.com/test',
            WhatsappURL__c = 'https://wa.me/98765'
        );
        insert rem;

        // Call the future method directly
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        SPARemindersTriggerHelper.sendWhatsappMessageOICAPI(new Set<Id>{rem.Id});
        Test.stopTest();
    }
}