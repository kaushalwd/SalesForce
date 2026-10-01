@IsTest
private class SPAWhatsappTriggerHelperTest {

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

    @IsTest
    static void testDownloadSPA_enqueueJob() {
        Id rtId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Person Account').getRecordTypeId();
        Account acc = new Account(FirstName = 'John54454223', LastName = 'Doe54454223', RecordTypeId = rtId);
        insert acc;
        
        // Create SalesOrder
        SalesOrder__c so = new SalesOrder__c(CustomerAccount__c = acc.Id);
        insert so;

        // Create SPAWhatsapp record
        SPAWhatsapp__c spa = new SPAWhatsapp__c(
            Sales_Order__c = so.Id,
            Status__c = 'pending'
        );
        insert spa;

        // Change Status to 'completed' to trigger downloadSPA
        spa.Status__c = 'completed';
		update spa;
        Map<Id, SObject> oldMap = new Map<Id, SObject>{ spa.Id => [SELECT Id, Status__c FROM SPAWhatsapp__c WHERE Id = :spa.Id] };
        List<SObject> newList = new List<SObject>{ spa };
            
        // Create SPAWhatsapp record
        SPAWhatsapp__c spa2 = new SPAWhatsapp__c(
            Sales_Order__c = so.Id,
            Status__c = 'pending'
        );
        insert spa2;

        // Change Status to 'completed' to trigger downloadSPA
        spa2.Status__c = 'completed';
        spa2.FileUploaded__c = true;
		update spa2;
        Map<Id, SObject> oldMap2 = new Map<Id, SObject>{ spa2.Id => [SELECT Id, Status__c, FileUploaded__c FROM SPAWhatsapp__c WHERE Id = :spa2.Id] };
        List<SObject> newList2 = new List<SObject>{ spa2 };    

        Test.startTest();
        SPAWhatsappTriggerHelper.sendEmailMessage(newList, oldMap);
        SPAWhatsappTriggerHelper.downloadSPA(newList, oldMap);
        SPAWhatsappTriggerHelper.sendJOSPA(newList2, oldMap2);
        SPAWhatsappTriggerHelper.sendWhatsappMsgToJOQueueable(new Set<Id>{spa2.Id});
        Test.stopTest();
        // Since it's async, we can't assert job ID directly, but we can check debug logs manually
    }

    @IsTest
    static void testSendWhatsappMessage() {
        // Setup test data
        Id rtId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Person Account').getRecordTypeId();
        Account acc = new Account(FirstName = 'John544541212', LastName = 'Doe544541212', RecordTypeId = rtId);
        insert acc;

        SalesOrder__c so = new SalesOrder__c(CustomerAccount__c=acc.Id);
        insert so;

        SPAWhatsapp__c spa = new SPAWhatsapp__c(
            Sales_Order__c = so.Id,
            Status__c = 'sent',
            DocuSignURL__c = 'https://mock.docusign.net/doc'
        );
        insert spa;

        List<SObject> newList = new List<SObject>{ spa };

        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        Test.startTest();
        SPAWhatsappTriggerHelper.sendWhatsappMessage(newList);
        Test.stopTest();
    }

    @IsTest
    static void testSendWhatsappMessageOICAPI_direct() {
        Id rtId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Person Account').getRecordTypeId();
        Account acc = new Account(FirstName = 'John5445498', LastName = 'Doe5445498', RecordTypeId = rtId);
        insert acc;

        SalesOrder__c so = new SalesOrder__c(CustomerAccount__c=acc.Id);
        insert so;

        SPAWhatsapp__c spa = new SPAWhatsapp__c(
            Sales_Order__c = so.Id,
            Status__c = 'sent',
            DocuSignURL__c = 'https://mock.docusign.net/doc'
        );
        insert spa;

        Set<Id> spaIds = new Set<Id>{ spa.Id };

        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        Test.startTest();
        SPAWhatsappTriggerHelper.sendWhatsappMessageOICAPI(spaIds);
        SPAWhatsappTriggerHelper.sendWhatsappMsgToQueueable(spaIds);
        SPAWhatsappTriggerHelper.sendEmailMessageFuture(spaIds);
        Test.stopTest();
    }
}