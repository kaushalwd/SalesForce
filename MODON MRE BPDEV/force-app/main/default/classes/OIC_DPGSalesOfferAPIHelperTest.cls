@isTest
public class OIC_DPGSalesOfferAPIHelperTest {

    @testSetup
    static void setupData() {
        // Create related project
        Project__c project = new Project__c(Name = 'Test Project44');
        insert project;

        Phase__c phase = new Phase__c(Name = 'Test Phase44', Project__c = project.Id);
        insert phase;
		
        Bucket__c obj_Bucket = new Bucket__c(Name = 'Online Sales');
        insert obj_Bucket;
        
        Unit__c unit = new Unit__c(
            Name = 'Unit 1',
            Phase__c = phase.Id,
            Status__c = 'Available',
            Number_of_Bedrooms__c = '2',
            FloorNumber__c = '5',
            TotalArea__c = 120.5,
            TotalGFAsqm__c = 100.0,
            TotalGrossSellableAreaGSA__c = 110.0,
            PlotAreasqm__c = 90.0,
            PlotNo__c = 'P-1234',
            MDPlotId__c = 'MD-0012',
            UnitClassification__c = 'Villa',
            Bucket__c = obj_Bucket.Id
        );
        insert unit;
    }

    @isTest
    static void testReadyPDF() {
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];
		PaymentPlan__c paymentPlan = new PaymentPlan__c();
        paymentPlan.Type__c = 'Standard';
        paymentplan.Unit__c = unit.Id;
        insert paymentPlan;
        
        PaymentInstallements__c installment = new PaymentInstallements__c();
        installment.PaymentInstallment__c = paymentPlan.Id;
        installment.BrokerPayout__c = 10;
        installment.Milestone__c = 10;
        installment.MilestoneNumber__c = 1;
        installment.MilestoneDescription__c = 'test';
        INSERT installment;
        
        Test.startTest();
        Blob pdfBlob = OIC_DPGSalesOfferAPIHelper.readyPDF(
            'proj1',
            unit.Id,
            'unitType1',
            paymentPlan.Id,
            'John Doe44',
            'test44@example.com',
            '',
            'http://testlink.com'
        );
        Test.stopTest();
    }

    @isTest
    static void testSavePDFToSalesforce() {
        Unit__c unit = [SELECT Id FROM Unit__c LIMIT 1];
        Blob fakeBlob = Blob.valueOf('Sample PDF content');
        String fileName = 'TestFile44.pdf';

        Test.startTest();
        Id contentVersionId = OIC_DPGSalesOfferAPIHelper.savePDFToSalesforce(fakeBlob, fileName, unit.Id);
        Test.stopTest();

        ContentVersion cv = [SELECT Id, Title, PathOnClient FROM ContentVersion WHERE Id = :contentVersionId LIMIT 1];
        ContentDocumentLink cdl = [SELECT Id, LinkedEntityId FROM ContentDocumentLink WHERE LinkedEntityId = :unit.Id LIMIT 1];
    }

    @isTest
    static void testGeneratePublicLink() {
        // Create a fake PDF file first
        Blob fakeBlob = Blob.valueOf('PDF data');
        ContentVersion cv = new ContentVersion(
            Title = 'Test Doc444',
            PathOnClient = 'TestDoc.pdf',
            VersionData = fakeBlob,
            IsMajorVersion = true
        );
        insert cv;

        ContentVersion insertedCv = [SELECT Id FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];

        Test.startTest();
        String publicUrl = OIC_DPGSalesOfferAPIHelper.generatePublicLink(insertedCv.Id, 'Test Doc');
        Test.stopTest();
    }
}