@IsTest
private class OIC_DPGDocuSignDocumentAPIHelperTest {

    // Mock HTTP response class
    private class MockHttpResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            
            if (req.getEndpoint().contains('/oauth/token')) {
                // Mock access token response
                res.setStatusCode(200);
                res.setBody('{"access_token":"mockAccessToken"}');
            } else if (req.getEndpoint().contains('/envelopes/') && req.getMethod() == 'GET') {
                // Mock envelope status
                res.setStatusCode(200);
                res.setBody('{"status":"sent"}');
            } else if (req.getEndpoint().contains('/envelopes/') && req.getMethod() == 'POST') {
                // Mock envelope creation or recipient view
                res.setStatusCode(200);
                res.setBody('{"envelopeId":"mockEnvelopeId","url":"https://mockSigningURL"}');
            } else if (req.getEndpoint().contains('/documents/combined')) {
                res.setStatusCode(200);
                res.setBodyAsBlob(Blob.valueOf('Mock PDF content'));
            } else {
                res.setStatusCode(200);
                res.setBody('{}');
            }
            return res;
        }
    }

    @IsTest
    static void testDownloadSPA() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        Test.startTest();
        Blob pdfBlob = OIC_DPGDocuSignDocumentAPIHelper.downloadSPA('mockEnvelopeId');
        Test.stopTest();
    }

    @IsTest
    static void testGetEnvelopeStatus() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        Test.startTest();
        String status = OIC_DPGDocuSignDocumentAPIHelper.getEnvelopeStatus(
            'https://mock.docusign.net',
            '123456',
            'mockEnvelopeId',
            'mockAccessToken'
        );
        Test.stopTest();
    }

    @IsTest
    static void testGenerateDocusignURL() {
        // Create a test User (owner of SalesOrder)
        User u = [SELECT Id FROM User WHERE Profile.Name = 'System Administrator' LIMIT 1];
        
        Id rtId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Person Account').getRecordTypeId();
        Account acc = new Account(FirstName = 'John54454', LastName = 'Doe54454', RecordTypeId = rtId);
        insert acc;

        List<Account> lst_Account = [SELECT Id, Name, PersonEmail, PersonContactId from Account where Id = :acc.Id];
        // Create SalesOrder
        SalesOrder__c so = new SalesOrder__c(CustomerAccount__c = acc.Id, OwnerId = u.Id);
        insert so;
        system.debug('soId'+so.Id);
        so.JO1__c = lst_Account.get(0).PersonContactId;
        so.JO2__c = lst_Account.get(0).PersonContactId;
        so.JO3__c = lst_Account.get(0).PersonContactId;
        so.JO4__c = lst_Account.get(0).PersonContactId;
        so.JO5__c = lst_Account.get(0).PersonContactId;
        so.JO6__c = lst_Account.get(0).PersonContactId;
        // Insert a ContentVersion (document)
        ContentVersion cv = new ContentVersion(
            Title = 'SPA',
            PathOnClient = 'SPA.jpg',
            VersionData = Blob.valueOf('Unit Test ContentVersion Body'),
            FirstPublishLocationId = so.Id
        );
        insert cv;
        
        // Now the link should exist
        Id cdId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        
        List<ContentDocumentLink> links =
            [SELECT Id, ContentDocumentId, ContentDocument.Title
             FROM ContentDocumentLink
             WHERE LinkedEntityId = :so.Id AND ContentDocumentId = :cdId
             WITH SYSTEM_MODE];
		
        List<ContentDocumentLink> lst_ContentDoc = [SELECT ContentDocumentId, ContentDocument.Title, SystemModstamp 
                                                        FROM ContentDocumentLink 
                                                        WHERE Id =: so.Id];
		System.debug('>>>>>>>>>> lst_ContentDoc  >>>> '+lst_ContentDoc);        
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        Test.startTest();
        String signingURL = OIC_DPGDocuSignDocumentAPIHelper.generateDocusignURL(so.Id);
        OIC_DPGDocuSignDocumentAPIHelper.generateDocusignURLJO(so.Id,'JO1');
        OIC_DPGDocuSignDocumentAPIHelper.generateDocusignURLJO(so.Id,'JO2');
        OIC_DPGDocuSignDocumentAPIHelper.generateDocusignURLJO(so.Id,'JO3');
        OIC_DPGDocuSignDocumentAPIHelper.generateDocusignURLJO(so.Id,'JO4');
        OIC_DPGDocuSignDocumentAPIHelper.generateDocusignURLJO(so.Id,'JO5');
        OIC_DPGDocuSignDocumentAPIHelper.generateDocusignURLJO(so.Id,'JO6');
        Test.stopTest();
    }

    @IsTest
    static void testGetSigningURL() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        Test.startTest();
        String url = OIC_DPGDocuSignDocumentAPIHelper.getSigningURL(
            'mockAccessToken', 'mockEnvelopeId', 'cust123', 'Test User', 'test@example.com'
        );
        String url2 = OIC_DPGDocuSignDocumentAPIHelper.getSigningURL(
            '', 'mockEnvelopeId', 'cust123', 'Test User', 'test@example.com'
        );
        Test.stopTest();
    }

    @IsTest
    static void testGetAccessToken() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        DocusignConfiguration__mdt obj_DocusignConfig = new DocusignConfiguration__mdt();
        DocuSignUtil.JWTModel jwtModel = new DocuSignUtil.JWTModel();
        
        List<DocusignConfiguration__mdt> lst_DocusignConfig = [SELECT Id, DeveloperName,  AccountId__c, IntegrationKey__c, 
                                  							 	   PrivateKey__c, UserId__c, AccountBaseURI__c, DocuSignHostName__c
                                                                   from DocusignConfiguration__mdt 
                                                             	   where DeveloperName = 'production'];
        if(lst_DocusignConfig.size() > 0){
             obj_DocusignConfig = lst_DocusignConfig.get(0);
        }
        jwtModel.iss = obj_DocusignConfig.IntegrationKey__c;//'YOUR_INTEGRATION_KEY';
        jwtModel.sub = obj_DocusignConfig.UserId__c;//'YOUR_API_USER_ID';
        jwtModel.aud = obj_DocusignConfig.DocuSignHostName__c;
        jwtModel.scope = 'signature impersonation';
        Test.startTest();
        String token = OIC_DPGDocuSignDocumentAPIHelper.getAccessToken(jwtModel, obj_DocusignConfig.PrivateKey__c, obj_DocusignConfig.DocuSignHostName__c);
        OIC_DPGDocuSignDocumentAPIHelper.getEnvelopeStatusPage('test');
        //public static String getDocuSignSingingURL(String accessToken, String envelopeId, String customerAccId, String customerName, String customerEmail) {
        OIC_DPGDocuSignDocumentAPIHelper.getDocuSignSingingURL(token,'test', 'test', 'test', 'test');
        Test.stopTest();
    }
}