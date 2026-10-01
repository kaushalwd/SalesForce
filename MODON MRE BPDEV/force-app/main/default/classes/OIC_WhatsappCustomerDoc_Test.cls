@IsTest
private class OIC_WhatsappCustomerDoc_Test {

    /*
     * HTTP Mock class added as requested.
     * Note: OIC_WhatsappCustomerDoc currently does not perform direct HTTP callouts,
     * but this mock is available if any dependent logic/package triggers callouts in test context.
     */
    private class WhatsappCustomerDocHttpMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody('{"status":"success","message":"Mock response"}');
            return res;
        }
    }

    @TestSetup
    static void setupData() {
         Account personAccount = new Account();
        personAccount.RecordTypeId= Schema.getGlobalDescribe().get('Account').getDescribe().getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();
        personAccount.FirstName = 'Test';
        personAccount.LastName = 'PersonAccount';
        personAccount.PersonBirthdate=Date.newinstance(2000, 2, 17);
        personAccount.Nationality__pc='India';
        personAccount.UAE_Resident_Status__pc='Resident';
        personAccount.IdentityProof__pc='Emirates Id';
        personAccount.EIDNumber__pc='123456';
        personAccount.PersonMobilePhone='+971545412082';
        personAccount.Occupation__pc='Teacher';
        personAccount.EmployerBusinessName__pc='PwC';
        personAccount.PaymentMethod__pc='Cash';
        personAccount.PurposeOfTransaction__pc='House rent';
        personAccount.PersonEmail='abc@pwc.com';
        personAccount.AreYouPoliticallyExposedPersonPEP__pc=true;
        personAccount.SourceOfIncome__pc='Salary';
        personAccount.DeliveryChannel__pc='Face to face interaction';
        personAccount.NoOfPropertyPurchasedWithModon__pc=2;        
        insert personAccount;

        Opportunity opp = new Opportunity(
            Name = 'Test Opp',
            StageName = 'Discussion In Progress',
            CloseDate = System.today(),
            AccountId = personAccount.Id
        );
        insert opp;

        Unit__c unit = new Unit__c(
            Name = 'UNIT-101',
            PlotNo__c = 'U-1',
            UnitClassification__c = 'Apartment',
            Number_of_Bedrooms__c = '2'
        );
        insert unit;

        PaymentPlan__c plan = new PaymentPlan__c(
            Type__c = 'Standard',
            Unit__c = unit.Id
        );
        insert plan;

        SalesOrder__c so = new SalesOrder__c(
            Unit__c = unit.Id,
            Opportunity__c = opp.Id,
            PaymentPlan__c = plan.Id,
            CustomerAccount__c = personAccount.Id,
            TotalAmount__c = 2000000,
            Daricharges__c = 499,
            Status__c = 'In Progress'
        );
        insert so;

        Documents__c spaDoc = new Documents__c();
        spaDoc.Name = 'Signed SPA (Modon)';
        spaDoc.Status__c = 'Uploaded';
        spaDoc.SalesOrder__c = so.Id;
        insert spaDoc;

        ContentVersion cv = new ContentVersion();
        cv.Title = 'Signed SPA Modon';
        cv.PathOnClient = 'Signed SPA Modon.pdf';
        cv.VersionData = Blob.valueOf('Test SPA File Content');
        cv.FirstPublishLocationId = spaDoc.Id;
        insert cv;
    }

    @IsTest
    static void testFindDocDetails_MissingMobileNumber() {
        Test.setMock(HttpCalloutMock.class, new WhatsappCustomerDocHttpMock());

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestUri = '/services/apexrest/WhatsappCustomerDoc/';
        req.httpMethod = 'GET';
        req.params.put('unitName', 'UNIT-101');
        req.params.put('docName', 'SPA');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        OIC_WhatsappCustomerDoc.findDocDetails();
        Test.stopTest();
    }

    @IsTest
    static void testFindDocDetails_MissingUnitName() {
        Test.setMock(HttpCalloutMock.class, new WhatsappCustomerDocHttpMock());

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestUri = '/services/apexrest/WhatsappCustomerDoc/';
        req.httpMethod = 'GET';
        req.params.put('MobileNumber', '971545412082');
        req.params.put('docName', 'SPA');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        OIC_WhatsappCustomerDoc.findDocDetails();
        Test.stopTest();
    }

    @IsTest
    static void testFindDocDetails_MissingDocName() {
        Test.setMock(HttpCalloutMock.class, new WhatsappCustomerDocHttpMock());

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestUri = '/services/apexrest/WhatsappCustomerDoc/';
        req.httpMethod = 'GET';
        req.params.put('MobileNumber', '971545412082');
        req.params.put('unitName', 'UNIT-101');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        OIC_WhatsappCustomerDoc.findDocDetails();
        Test.stopTest();
    }

    @IsTest
    static void testFindDocDetails_SPA_DocumentFound() {
        Test.setMock(HttpCalloutMock.class, new WhatsappCustomerDocHttpMock());

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestUri = '/services/apexrest/WhatsappCustomerDoc/';
        req.httpMethod = 'GET';
        req.params.put('MobileNumber', '971545412082');
        req.params.put('unitName', 'UNIT-101');
        req.params.put('docName', 'SPA');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        OIC_WhatsappCustomerDoc.findDocDetails();
        Test.stopTest();
    }

    @IsTest
    static void testFindDocDetails_SOA_DocumentGeneration() {
        Test.setMock(HttpCalloutMock.class, new WhatsappCustomerDocHttpMock());

        SalesOrder__c so = [
            SELECT Id
            FROM SalesOrder__c
            LIMIT 1
        ];

        Documents__c soaDoc = new Documents__c();
        soaDoc.Name = 'Customer SOA';
        soaDoc.Status__c = 'Pending Upload';
        soaDoc.SalesOrder__c = so.Id;
        insert soaDoc;

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestUri = '/services/apexrest/WhatsappCustomerDoc/';
        req.httpMethod = 'GET';
        req.params.put('MobileNumber', '971545412082');
        req.params.put('unitName', 'UNIT-101');
        req.params.put('docName', 'SOA');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        OIC_WhatsappCustomerDoc.findDocDetails();
        Test.stopTest();
    }

    @IsTest
    static void testFindDocDetails_NoSalesOrderFound() {
        Test.setMock(HttpCalloutMock.class, new WhatsappCustomerDocHttpMock());

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestUri = '/services/apexrest/WhatsappCustomerDoc/';
        req.httpMethod = 'GET';
        req.params.put('MobileNumber', '9715412082');
        req.params.put('unitName', 'INVALID-UNIT');
        req.params.put('docName', 'SPA');

        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        OIC_WhatsappCustomerDoc.findDocDetails();
        Test.stopTest();
    }

    @IsTest
    static void testGetFilters_WithCommaValues() {
        Test.startTest();
        List<String> filters = OIC_WhatsappCustomerDoc.getfilters('Cancelled,Void,Rejected');
        Test.stopTest();
    }

    @IsTest
    static void testGetSignedSPAFilesDownloadUrl_EmptyList() {
        Test.startTest();
        List<OIC_WhatsappCustomerDoc.responseWrapper> result =
            OIC_WhatsappCustomerDoc.getSignedSPAFilesDownloadUrl(new List<Documents__c>());
        Test.stopTest();
    }

    @IsTest
    static void testGetCustomerSOADoc_EmptyList() {
        Test.startTest();
        List<Documents__c> result =
            OIC_WhatsappCustomerDoc.getcustomerSOADoc(new List<Documents__c>());
        Test.stopTest();
    }
}