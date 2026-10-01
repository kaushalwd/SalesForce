@IsTest
private class SPAWhatsappQueueableTest {

    // Mock HTTP response for DocuSign API
    private class MockHttpResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/pdf');
            res.setStatusCode(200);
            res.setBodyAsBlob(Blob.valueOf('Mock PDF Content'));
            return res;
        }
    }

    @IsTest
    static void testQueueableExecution() {
        Id rtId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Person Account').getRecordTypeId();
        Account acc = new Account(FirstName = 'John52223', LastName = 'Doe52223', RecordTypeId = rtId);
        insert acc;

        // Create SalesOrder
        SalesOrder__c so = new SalesOrder__c(CustomerAccount__c=acc.Id);
        insert so;

        // Create SPAWhatsapp record
        SPAWhatsapp__c spa = new SPAWhatsapp__c(
            Sales_Order__c = so.Id,
            Status__c = 'completed',
            EnvelopeId__c = 'mockEnvelopeId',
            DocuSignURL__c = 'https://mock.docusign.net/doc'
        );
        insert spa;

        // Create dfsle__EnvelopeStatus__c record
        dfsle__EnvelopeStatus__c envStatus = new dfsle__EnvelopeStatus__c(
            dfsle__DocuSignId__c = 'mockEnvelopeId',
            dfsle__SourceId__c = so.Id,
            dfsle__Status__c = 'Sent'
        );
        insert envStatus;

        // Insert a ContentVersion (document)
        ContentVersion cv = new ContentVersion(
            Title = 'SPA',
            PathOnClient = 'SPA.pdf',
            VersionData = Blob.valueOf('Test Data')
        );
        insert cv;
		ContentVersion obj_CVFull = [SELECT Id, ContentDocumentId, Title FROM ContentVersion WHERE Id = :cv.Id];
        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId=obj_CVFull.ContentDocumentId,
            LinkedEntityId=so.Id,
            ShareType='V'
        );
        insert cdl;

        // Set mock callout
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        // Enqueue Queueable
        Set<Id> spaIds = new Set<Id>{spa.Id};
        Test.startTest();
        SPAWhatsappQueueable queueableJob = new SPAWhatsappQueueable(spaIds);
        ID jobId = System.enqueueJob(queueableJob);
        Test.stopTest();
    }
}