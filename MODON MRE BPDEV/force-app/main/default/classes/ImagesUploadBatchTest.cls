@isTest
public class ImagesUploadBatchTest {

    @testSetup
    static void setupData() {
        
         Project__c project = new Project__c(Name = 'TestProject');
        insert project;
         
        Phase__c phase = new Phase__c();
        phase.Name ='TestPhase1';
        phase.Project__c = project.Id;
        insert phase;
        
        
        Unit__c unit = new Unit__c();
        unit.Phase__c = phase.Id;
        unit.PlotAreasqm__c = 1.0;
        unit.PlotNo__c = '1';
        unit.UnitClassification__c = 'Villa';
        unit.Number_of_Bedrooms__c = '1';
        unit.Unit_Image_Name_pc__c='TestProject';
        insert unit;
        
        Unit__c unitother = new Unit__c();
        unitother.Name ='Other Data';
        unitother.Phase__c = phase.Id;
        unitother.PlotAreasqm__c = 1.0;
        unitother.PlotNo__c = '1';
        unitother.UnitClassification__c = 'Villa';
        unitother.Number_of_Bedrooms__c = '1';
        unitother.Unit_Image_Name_pc__c='TestProject';
        insert unitother;
        
        Account acc = new Account();
        acc.name = 'test account';
        insert acc;
        
        PaymentPlan__c paymentPlan = new PaymentPlan__c();
        paymentPlan.Type__c = 'Standard';
        //paymentplan.Unit__c = unit.Id;
        insert paymentPlan;
        
        PaymentInstallements__c installment = new PaymentInstallements__c();
        installment.PaymentInstallment__c = paymentPlan.Id;
        installment.BrokerPayout__c = 10;
        installment.Milestone__c = 10;
        installment.MilestoneNumber__c = 1;
        installment.MilestoneDescription__c = 'test';
        INSERT installment;
        
        Opportunity oppObj = new Opportunity();
        oppObj.Name = 'Test opportunity';
        oppObj.StageName = 'Discussion In Progress';
        oppObj.CloseDate = System.Today();
        oppObj.AccountId =acc.id;
        oppObj.UAE_Resident_Status__c = 'Resident';
        oppObj.Nationality__c = 'United Arab Emirates';
        oppObj.EmiratesIDExpiryDate__c = Date.TODAY();
        oppObj.EIDNumber__c = '784-1990-1234567-8';
        INSERT oppObj;
        
        SalesOrder__c so = new SalesOrder__c();
        so.Unit__c = unit.Id;
        
        so.Opportunity__c = oppObj.Id;
        so.PaymentPlan__c = paymentPlan.Id;
        so.Status__c = 'Downpayment Payments Cleared';
        so.CustomerAccount__c=acc.id;
        INSERT so;
        
        SalesOrder__c soother = new SalesOrder__c();
        soother.Unit__c = unitother.Id;        
        soother.Opportunity__c = oppObj.Id;
        soother.PaymentPlan__c = paymentPlan.Id;
        soother.Status__c = 'Downpayment Payments Cleared';
        soother.CustomerAccount__c=acc.id;
        INSERT soother;
        
        
        // Create a dummy ContentVersion record for imageContentVersionId
        ContentVersion cv = new ContentVersion(
            Title = 'TestProject',
            PathOnClient = 'TestProject.jpg',
            VersionData = Blob.valueOf('fake image content'),
            FirstPublishLocationId = phase.Id // temp location     
        );
        insert cv;

        // Re-query because ContentDocumentLink needs ContentDocumentId
        cv = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];

        // Create a Documents__c record linked to Unit
        Documents__c doc = new Documents__c(
                                            Name = 'Exterior',
                                            Unit__c = unit.Id,
                                            Status__c = 'Pending Upload'
                                        );
        insert doc;

		// Create a Documents__c record linked to Unit
        Documents__c doc1 = new Documents__c(
                                            Name = 'Exterior',
                                            Unit__c = unitother.Id,
                                            Status__c = 'Pending Upload'
                                        );
        insert doc1;        
        // Create a dummy ContentVersion record for imageContentVersionId
        ContentVersion cvold = new ContentVersion(
            Title = 'TestProject',
            PathOnClient = 'TestProject.jpg',
            VersionData = Blob.valueOf('fake image content'),
            FirstPublishLocationId = doc1.Id // temp location     
        );
        insert cvold;
    }

    @isTest
    static void testBatchExecutionOther() {
        // Fetch ContentVersion Id for constructor
        list<ContentVersion> cv = [SELECT Id FROM ContentVersion ];
        SalesOrder__c soOther = [SELECT ProjectName__c FROM SalesOrder__c where Unit__r.name = 'Other Data' limit 2];

        Test.startTest();
        ImagesUploadBatch batch = new ImagesUploadBatch();
        Database.executeBatch(batch, 2);
        Test.stopTest();
    }

    @isTest
    static void testParameterizedConstructorAndProjectQuery() {
        ContentVersion cv = [SELECT Id FROM ContentVersion LIMIT 1];
        SalesOrder__c so = [SELECT Id, ProjectName__c FROM SalesOrder__c LIMIT 1];

        Test.startTest();
        ImagesUploadBatch namedBatch = new ImagesUploadBatch(cv.Id, so.ProjectName__c);
        Database.QueryLocator locator = namedBatch.start(null);
        namedBatch.execute(null, new List<SalesOrder__c>());
        namedBatch.finish(null);
        Test.stopTest();

        System.assertNotEquals(null, locator);
        System.assertEquals(cv.Id, namedBatch.imageContentVersionId);
        System.assertEquals(so.ProjectName__c, namedBatch.projectName);
    }
}