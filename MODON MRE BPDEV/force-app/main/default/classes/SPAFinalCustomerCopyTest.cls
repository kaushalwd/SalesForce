@isTest
private class SPAFinalCustomerCopyTest {
    
    // Mock HTTP response for DocuSign API
    private class SPAHttpMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"status":"Success","message":"Envelope Created"}');
            res.setStatusCode(200);
            return res;
        }
    }
    
    @IsTest
    static void testGetSigningURL() {
        Test.setMock(HttpCalloutMock.class, new SPAHttpMock());
        Test.startTest();
        String url = SPAFinalCustomerCopy.getFinalSigningURL(
            'mockAccessToken', 'mockEnvelopeId', 'cust123', 'Test User', 'test@example.com'
        );
        
        Test.stopTest();
    }
    
    @isTest
    static void test_sendFinalCopySPAToCustomer() {
        // --- Step 1: Create mock Account (Person Account)
        Account acc = new Account(
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Person Account').getRecordTypeId(),
            LastName = 'Test Customer12312',
            PersonEmail = 'test.customer12312@example.com'
        );
        insert acc;
        
        List<Account> lst_Account = [SELECT Id, Name, PersonEmail, PersonContactId from Account where Id = :acc.Id];
        // Create SalesOrder
        SalesOrder__c so = new SalesOrder__c(CustomerAccount__c = acc.Id);
        insert so;
        so.JO1__c = lst_Account.get(0).PersonContactId;
        so.JO2__c = lst_Account.get(0).PersonContactId;
        so.JO3__c = lst_Account.get(0).PersonContactId;
        so.JO4__c = lst_Account.get(0).PersonContactId;
        so.JO5__c = lst_Account.get(0).PersonContactId;
        so.JO6__c = lst_Account.get(0).PersonContactId;
        update so;
        // --- Step 3: Create ContentDocument & Version
        ContentVersion cv = new ContentVersion(
            Title = 'Test SPA Document completed',
            PathOnClient = 'SPA_Test_completed.pdf',
            VersionData = Blob.valueOf('Test data'),
            IsMajorVersion = true
        );
        insert cv;
        
        // Query the ContentDocumentId created by the platform
        cv = [SELECT Id, ContentDocumentId, Title, FileType, ContentSize FROM ContentVersion WHERE Id = :cv.Id];
        
        // Link the document to the SalesOrder
        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = cv.ContentDocumentId,
            LinkedEntityId = so.Id,
            ShareType = 'V'
        );
        insert cdl;
        
        // --- Step 4: Register mock HTTP callout
        Test.setMock(HttpCalloutMock.class, new SPAHttpMock());
        
        // --- Step 5: Call the method inside a test context
        Test.startTest();
        SPAFinalCustomerCopy.sendFinalCopySPAToCustomer(so.Id);
        Database.executeBatch(new SPAFinalCustomerCopyBatch(new List<SalesOrder__c>{so}), 1);
        Test.stopTest();
    }
    
    @isTest
    static void test_noDocumentFound() {
        // --- Create account & sales order without linked document
        Account acc = new Account(
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Person Account').getRecordTypeId(),
            LastName = 'Test Customer2',
            PersonEmail = 'customer2@example.com'
        );
        insert acc;
        
        SalesOrder__c so = new SalesOrder__c(
            CustomerAccount__c = acc.Id
        );
        insert so;
        
        Test.startTest();
        // No content linked → Should safely exit
        SPAFinalCustomerCopy.sendFinalCopySPAToCustomer(so.Id);
        Test.stopTest();
    }
}