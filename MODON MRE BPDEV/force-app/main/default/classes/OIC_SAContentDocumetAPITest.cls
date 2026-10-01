@isTest
private class OIC_SAContentDocumetAPITest {

    @testSetup
    static void setupData() {
        //Create an account
         Schema.RecordTypeInfo recordTypeInfo = Schema.getGlobalDescribe().get('Account').getDescribe().getRecordTypeInfosByDeveloperName().get('PersonAccount');
         String recordTypeId = recordTypeInfo.getRecordTypeId();
         Account accountObj = new Account(RecordTypeId = recordTypeId);
         accountObj.PersonEmail = 'test1232.pdf@outlook.com';
         accountObj.FirstName = 'Firsttt';
         accountObj.LastName = 'Lasttt';
         accountObj.OraclePartyId__c ='22214';
         insert accountObj;
        
        // Create Unit/Property data
        Phase__c testPhase = new Phase__c(Name = 'Test Phase121');
        insert testPhase;
        
        Unit__c testUnit = new Unit__c(
            Name = 'Unit 101',
            UnitClassification__c = 'villa',
            PlotNo__c = 'P-101',
            Number_of_Bedrooms__c ='2',
            Phase__c = testPhase.Id,
            BuildingNo__c = 'B1'
        );
        insert testUnit;
        
        EscrowAccount__c testescrow = new EscrowAccount__c();
        insert testescrow;
        
        // Create Virtual Account
        VirtualAccount__c testVA = new VirtualAccount__c(
            EscrowAccount__c = testescrow.id,
            VirtualIBANNumber__c = 'IBAN123',
            VirtualAccountNumber__c = 'VA123'
            //Escrow_Bank_Name__c = 'Test Bank'
        );
        insert testVA;
        
        // Create Sales Order
        SalesOrder__c testSO = new SalesOrder__c(
           // SOCreationDate__c = System.today(),
            SPACustomerSignedDate__c = System.today().addDays(-30),
            //ProjectName__c = 'Test Project',
            TotalAmount__c = 1000000,
            CustomerAccount__c = accountObj.Id,
            Unit__c = testUnit.Id,
            VirtualAccount__c = testVA.Id
        );
        insert testSO;
        
        // Create Installments
        List<SalesOrderInstallments__c> installments = new List<SalesOrderInstallments__c>();
        for(Integer i=1; i<=3; i++) {
            installments.add(new SalesOrderInstallments__c(
                SalesOrder__c = testSO.Id,
                MilestoneNumber__c = 1.0,
                MilestoneDescription__c = 'Milestone ' + i,
                Milestone__c = 1.0,
                MilestoneDate__c = System.today().addMonths(i)
            ));
        }
        insert installments;

        // 2. Create Documents__c records
        // Doc 1: Will have a file attached
        // Doc 2: Will remain empty
        Documents__c docWithFile = new Documents__c(
            Name = 'Passport',
            Status__c = 'Uploaded',
            SalesOrder__c = testSO.Id
        );
        Documents__c docEmpty = new Documents__c(
            Name = 'Emirates ID',
            Status__c = 'Pending Upload',
            SalesOrder__c = testSO.Id
        );
        insert new List<Documents__c>{docWithFile, docEmpty};

        // 3. Create File (ContentVersion & ContentDocumentLink)
        ContentVersion cv = new ContentVersion(
            Title = 'Passport_File',
            PathOnClient = 'Passport.pdf',
            VersionData = Blob.valueOf('Test Content'),
            IsMajorVersion = true
        );
        insert cv;

        // Get the ContentDocumentId that was automatically created
        Id conDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;

        ContentDocumentLink cdl = new ContentDocumentLink(
            LinkedEntityId = docWithFile.Id,
            ContentDocumentId = conDocId,
            ShareType = 'V'
        );
        insert cdl;
    }

    @isTest
    static void testGetDocumentsSuccess() {
        SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];
        
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        
        request.requestUri = '/services/apexrest/salesorder/documents';
        request.httpMethod = 'GET';
        request.params.put('SalesOrderId', so.Id);
        request.params.put('UserName', 'test1232.pdf@outlook.com');
        
        RestContext.request = request;
        RestContext.response = response;

        Test.startTest();
        OIC_SAContentDocumetAPI.getCustomerDocuments();
        Test.stopTest();
    }

    @isTest
    static void testMissingParameters() {
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        
        request.httpMethod = 'GET';
        // Missing SalesOrderId
        request.params.put('UserName', 'test1232.pdf@outlook.com');
        
        RestContext.request = request;
        RestContext.response = response;

        Test.startTest();
        OIC_SAContentDocumetAPI.getCustomerDocuments();
        Test.stopTest();
    }

    @isTest
    static void testMissingUserName() {
        SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];
        RestRequest request = new RestRequest();
        RestResponse response = new RestResponse();
        
        request.httpMethod = 'GET';
        request.params.put('SalesOrderId', so.Id);
        // Missing UserName
        
        RestContext.request = request;
        RestContext.response = response;

        Test.startTest();
        OIC_SAContentDocumetAPI.getCustomerDocuments();
        Test.stopTest();
    }

}