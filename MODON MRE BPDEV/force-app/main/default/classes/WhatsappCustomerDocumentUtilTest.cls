@isTest
private class WhatsappCustomerDocumentUtilTest {

    @testSetup
    static void setupData() {
        // 1. Setup Person Account for Primary Owner
        Id paRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
                            .get('PersonAccount').getRecordTypeId();

        Account pa = new Account(
            FirstName = 'Suresh12111',
            LastName = 'Modon1212',
            RecordTypeId = paRecordTypeId,
            PersonMobilePhone = '+971501112233',
            PersonEmail = 'suresh@modon.ae'
        );
        insert pa;

        // Get the auto-created Contact ID
        Id conId = [SELECT PersonContactId FROM Account WHERE Id = :pa.Id].PersonContactId;

        Opportunity oppObj = new Opportunity();
        oppObj.Name = 'Test opportunity';
        oppObj.StageName = 'Discussion In Progress';
        oppObj.CloseDate = System.Today();
        oppObj.AccountId = pa.Id;
        oppObj.PrimaryContact__c = [SELECT PersonContactId FROM Account WHERE Id=:pa.Id LIMIT 1].PersonContactId;
        oppObj.UAE_Resident_Status__c = 'Non-Resident';
        oppObj.Nationality__c = 'India';
        oppObj.PassportExpiryDate__c = Date.today();
        oppObj.PassportIssueDate__c = Date.today();
        oppObj.PassportNumber__c = 'NP232131';
        oppObj.En_PassportNumber__c = 'NP232131';
        oppObj.En_Nationality__c= 'India';
        oppObj.EIDNumber__c ='784-1989-4183036-1';
        insert oppObj;
        
        //Create a new Unit
        Unit__c unitObj = new Unit__c();
        unitObj.Name = 'MOD-101';
        unitObj.BasePrice__c = 1000;
        unitObj.AdditionalPrice__c = 0;
        unitObj.PlotAreasqm__c = 1.0;
        unitObj.PlotNo__c = '1';
        unitObj.UnitClassification__c = 'Villa';
        unitObj.Number_of_Bedrooms__c = '2'; 
        INSERT unitObj;

        SalesOrder__c so = new SalesOrder__c(
            CustomerAccount__c = pa.Id,
            Unit__c = unitObj.Id,
            PrimaryContact__c = conId,
            Status__c = 'Completed',
            Opportunity__c = oppObj.Id
        );
        insert so;

       
        // 3. Setup existing Document record for SPA testing
        Documents__c doc = new Documents__c(
            Name = 'Signed SPA (Modon)',
            SalesOrder__c = so.Id,
            Status__c = 'Uploaded'
        );
        insert doc;

        // 4. Attach a file to the Document for SPA testing
        ContentVersion cv = new ContentVersion(
            Title = 'Signed_SPA_File',
            PathOnClient = 'SPA.pdf',
            VersionData = Blob.valueOf('Test Content'),
            IsMajorVersion = true
        );
        insert cv;

        Id contentDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = contentDocId,
            LinkedEntityId = doc.Id,
            ShareType = 'V'
        );
        insert cdl;
    }

    @isTest
    static void testGenerateSOADocument() {
        // Test SOA generation (creates new ContentVersion and Distribution)
        Test.startTest();
        // Note: Page.SOA3 must exist in your org for this to compile
        String MobileNumber = '+971501112233';
        SalesOrder__c obj_SO = [SELECT Id, Opportunity__c from SalesOrder__c where Status__c = 'Completed' and Unit__r.Name = 'MOD-101'
                                    and (PrimaryContact__r.MobilePhone = :MobileNumber or JO1__r.MobilePhone = :MobileNumber 
                                    or JO2__r.MobilePhone = :MobileNumber or JO3__r.MobilePhone = :MobileNumber 
                                    or JO4__r.MobilePhone = :MobileNumber or JO5__r.MobilePhone = :MobileNumber 
                                    or JO6__r.MobilePhone = :MobileNumber) limit 1];
        System.debug('>>>>>>>>>>>>>>>>>> obj_SO '+obj_SO.Id);
        PageReference pageRef = Page.SOA3; 
        Test.setCurrentPage(pageRef);
        ApexPages.currentPage().getParameters().put('Id', obj_SO.Id);
        String url = WhatsappCustomerDocumentUtil.generateSOADocument('MOD-101', '+971501112233');
        Test.stopTest();
    }

    @isTest
    static void testGenerateSPADocument() {
        // Test SPA retrieval (finds existing ContentVersion and creates Distribution)
        Test.startTest();
        String url = WhatsappCustomerDocumentUtil.generateSPADocument('MOD-101', '+971501112233');
        Test.stopTest();
    }

    @isTest
    static void testGenerateDocumentNoData() {
        // Test with invalid phone number
        Test.startTest();
        String url = WhatsappCustomerDocumentUtil.generateSPADocument('MOD-101', '+971000000000');
        Test.stopTest();
    }
}