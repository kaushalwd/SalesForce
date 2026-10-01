@isTest
public class PDFControllerTest {

    @isTest
    static void testPDFController() {
        
        project__c testProject = new Project__c (
        name = 'Al Naseem');
        insert testProject;
        
        phase__c testPhase = new phase__c(
        Project__c = testProject.Id
        );
		insert testPhase;        
        
        Unit__c testUnit = new Unit__c(
            Name = 'Test Unit',
            PlotNo__c = '1',
            phase__c = testPhase.Id,
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '2'
        );
        insert testUnit;
            
        // Setup test data
        // Create a Sales Order
        TriggerControl.bypassTransferTrigger = true;
        SalesOrder__c testSalesOrder = new SalesOrder__c(
            Unit__c = testUnit.Id
        );
        insert testSalesOrder;
        TriggerControl.bypassTransferTrigger = false;

        ContentVersion contentVersion = new ContentVersion(
            Title          = 'a picture',
            PathOnClient   = 'Pic.jpg',
            VersionData    = Blob.valueOf('Test Content'),
            IsMajorVersion = true);
        insert contentVersion;

        List<ContentDocument> documents = [SELECT Id, Title, LatestPublishedVersionId FROM ContentDocument];

        ContentDocumentLink testContentDocumentLink = new ContentDocumentLink(
            ContentDocumentId = documents[0].Id,
            LinkedEntityId = testSalesOrder.Unit__c,
            ShareType = 'V'
        );
        insert testContentDocumentLink;

        // Test PDFController constructor
        ApexPages.StandardController sc = new ApexPages.StandardController(testSalesOrder);
        String base64PdfData = EncodingUtil.base64Encode(Blob.valueOf('PDF Content'));
        ApexPages.currentPage().getParameters().put('id', testSalesOrder.Id);
        ApexPages.currentPage().getParameters().put('recordId', testSalesOrder.Id);
        ApexPages.currentPage().getParameters().put('pdfData', base64PdfData);

        Test.startTest();
        PDFController pdfController = new PDFController(sc);
        PageReference pageRef = pdfController.savePDF();
        Test.stopTest();
        
        
        
        // Assertions for the constructor
        System.assertNotEquals(null, pdfController, 'PDFController should be instantiated');
        System.assertEquals(true, pdfController.FloorPlanAvailable, 'FloorPlanAvailable should be true');
        System.assertEquals(1, pdfController.plotlist.size(), 'Plot list should contain one unit');

        // Verify attachment creation
        List<Attachment> attachments = [SELECT Id, Name, ParentId FROM Attachment WHERE ParentId = :testSalesOrder.Id];
        //System.assertEquals(true, attachments.size() > 0, 'Attachment should be created');
        //System.assertEquals('SPA.pdf', attachments[0].Name, 'Attachment name should be SPA.pdf');
    }

   @isTest
    static void testPDFController_Constructor_NoFloorPlans() {
        // Create a Sales Order with no related units
        SalesOrder__c testSalesOrder = new SalesOrder__c(
            Unit__c = null
        );
        insert testSalesOrder;

        // Test PDFController constructor
        ApexPages.StandardController sc = new ApexPages.StandardController(testSalesOrder);
        ApexPages.currentPage().getParameters().put('id', testSalesOrder.Id);
        ApexPages.currentPage().getParameters().put('recordId', testSalesOrder.Id);
        ApexPages.currentPage().getParameters().put('pdfData', 'PDF Content');

        Test.startTest();
        PDFController pdfController = new PDFController(sc);
        Test.stopTest();
        
        // Assertions for the constructor
        System.assertNotEquals(null, pdfController, 'PDFController should be instantiated');
        System.assertEquals(false, pdfController.FloorPlanAvailable, 'FloorPlanAvailable should be false');
    }

    // Helper method to create test Unit
    private static Unit__c createTestUnit() {
        Unit__c testUnit = new Unit__c(
            Name = 'Test Unit',
            PlotNo__c = '1',
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '2'
        );
        insert testUnit;
        return testUnit;
    }
}