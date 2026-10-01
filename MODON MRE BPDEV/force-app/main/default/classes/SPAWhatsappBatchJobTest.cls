@IsTest
private class SPAWhatsappBatchJobTest {

    // Mock HTTP response for DocuSign envelope list
    private class MockDocuSignEnvelopeList implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);

            // Mock JSON response with two envelopes
            String mockJson = '{' +
                '"envelopes": [' +
                    '{"envelopeId":"env123","status":"completed","statusChangedDateTime":"2025-10-01T10:00:00Z"},' +
                    '{"envelopeId":"env456","status":"completed","statusChangedDateTime":"2025-10-01T12:00:00Z"}' +
                ']' +
            '}';
            res.setBody(mockJson);
            return res;
        }
    }

    @IsTest
    static void testBatchJobExecution() {
        // Create SPAWhatsapp records
        SPAWhatsapp__c spa1 = new SPAWhatsapp__c(EnvelopeId__c='env123', Status__c='sent');
        SPAWhatsapp__c spa2 = new SPAWhatsapp__c(EnvelopeId__c='env456', Status__c='sent');
        insert new List<SPAWhatsapp__c>{spa1, spa2};

        // Set mock callout
        Test.setMock(HttpCalloutMock.class, new MockDocuSignEnvelopeList());

        // Enqueue Queueable Batch Job
        Test.startTest();
        Id jobId = Database.executeBatch(new SPAWhatsappBatchJob(), 25);
	    System.debug('SPAWhatsappScheduler >>>>>>>> ' + jobId);        
        Test.stopTest();
    }
}