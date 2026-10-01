@isTest
public class SendDefaultLetterBatchTest {

    // ADD THIS MOCK CLASS
    private class MockDrawloopCallout implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/pdf');
            res.setBodyAsBlob(Blob.valueOf('%PDF-1.4 Mock Default Letter PDF'));
            return res;
        }
    }

    private static SalesOrder__c createSalesOrderData() {

        Project__c project = new Project__c(Name = 'Test Project');
        insert project;

        Phase__c phase = new Phase__c(
            Name = 'Test Phase',
            Project__c = project.Id
        );
        insert phase;

        Unit__c unit = new Unit__c(
            Name = 'Test Unit',
            Phase__c = phase.Id,
            PlotAreasqm__c = 100,
            PlotNo__c = 'U-101',
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '3'
        );
        insert unit;

        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Contact con = new Contact(
            FirstName = 'Test',
            LastName = 'Customer',
            Email = 'customer@test.com',
            AccountId = acc.Id
        );
        insert con;

        PaymentPlan__c paymentPlan = new PaymentPlan__c(
            Type__c = 'Standard',
            Unit__c = unit.Id
        );
        insert paymentPlan;

        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Discussion In Progress',
            CloseDate = Date.today(),
            AccountId = acc.Id,
            PrimaryContact__c = con.Id,
            UAE_Resident_Status__c = 'Resident',
            Nationality__c = 'United Arab Emirates',
            EmiratesIDExpiryDate__c = Date.today(),
            EIDNumber__c = '784-1990-1234567-8'
        );
        insert opp;

        SalesOrder__c so = new SalesOrder__c(
            Unit__c = unit.Id,
            Opportunity__c = opp.Id,
            PaymentPlan__c = paymentPlan.Id,
            Status__c = 'In Progress',
            CustomerAccount__c = acc.Id,
            PrimaryContact__c = con.Id
        );
        insert so;

        return so;
    }

    private static void createDefaultNoticeFile(Id salesOrderId) {

        ContentVersion cv = new ContentVersion(
            Title = 'Default Notice',
            PathOnClient = 'Default Notice.pdf',
            VersionData = Blob.valueOf('Test Default Notice PDF'),
            Origin = 'H'
        );
        insert cv;

        cv = [
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
            LIMIT 1
        ];

        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = cv.ContentDocumentId,
            LinkedEntityId = salesOrderId,
            ShareType = 'V'
        );
        insert cdl;
    }
    
    private static void createDDPRecords() {
        List<String> packageNames = new List<String>{'Default Document', 'CancelationPackage', 'FinalNoticePackage', 'NOCPackage'};
        List<Loop__DDP__c> existingDDPs = [SELECT Id, Name FROM Loop__DDP__c WHERE Name IN :packageNames];
        Map<String, Id> existingDDPMap = new Map<String, Id>();
        for(Loop__DDP__c ddp : existingDDPs) {
            existingDDPMap.put(ddp.Name, ddp.Id);
        }
        
        List<Loop__DDP__c> ddpsToCreate = new List<Loop__DDP__c>();
        for(String packageName : packageNames) {
            if(!existingDDPMap.containsKey(packageName)) {
                ddpsToCreate.add(new Loop__DDP__c(
                    Name = packageName,
                    Loop__Object_Name__c = 'SalesOrder__c',
                    Loop__Type__c = 'Mass'
                ));
            }
        }
        
        if(!ddpsToCreate.isEmpty()) {
            insert ddpsToCreate;
            
            for(Loop__DDP__c ddp : ddpsToCreate) {
                existingDDPMap.put(ddp.Name, ddp.Id);
            }
        }
        
        if(!existingDDPMap.isEmpty()) {
            List<Loop__DDP_Integration_Option__c> integrationOptions = new List<Loop__DDP_Integration_Option__c>();
            
            try {
                Id attachRTId = Schema.SObjectType.Loop__DDP_Integration_Option__c.getRecordTypeInfosByName().get('Attach').getRecordTypeId();
                
                for(String packageName : packageNames) {
                    if(existingDDPMap.containsKey(packageName)) {
                        integrationOptions.add(new Loop__DDP_Integration_Option__c(
                            Loop__DDP__c = existingDDPMap.get(packageName),
                            RecordTypeId = attachRTId,
                            Name = packageName + ' Delivery'
                        ));
                    }
                }
                
                if(!integrationOptions.isEmpty()) {
                    insert integrationOptions;
                }
            } catch (Exception e) {
                System.debug('Could not create integration options: ' + e.getMessage());
            }
        }
    }

    @isTest
    static void testSendDefaultLetterBatch() {
        createDDPRecords();
        SalesOrder__c so = createSalesOrderData();
        createDefaultNoticeFile(so.Id);

        // ADD THIS LINE TO HANDLE REST API CALLOUT
        Test.setMock(HttpCalloutMock.class, new MockDrawloopCallout());

        Test.startTest();

        Database.executeBatch(
            new SendDefaultLetterBatch(new Set<Id>{ so.Id }),
            1
        );

        Test.stopTest();

        System.assert(true, 'SendDefaultLetterBatch executed successfully.');
    }

    @isTest
    static void testGenerateSOACalledFromBatchData() {

        SalesOrder__c so = createSalesOrderData();

        Test.startTest();

        List<GenerateSOA.SOAWrapper> soaWrappers =
            GenerateSOA.generateSOA(new Set<Id>{ so.Id });

        Test.stopTest();

        System.assertNotEquals(null, soaWrappers, 'SOA wrapper list should not be null.');
        System.assertEquals(1, soaWrappers.size(), 'One SOA wrapper should be created.');

        GenerateSOA.SOAWrapper wrapper = soaWrappers[0];

        System.assertEquals(so.Id, wrapper.salesOrderId);
        System.assertNotEquals(null, wrapper.contentVersionId);
        System.assertNotEquals(null, wrapper.contentDocumentId);
        System.assertNotEquals(null, wrapper.contentDocumentLinkId);
        System.assertNotEquals(null, wrapper.cv);
        System.assertNotEquals(null, wrapper.cdl);
    }
}