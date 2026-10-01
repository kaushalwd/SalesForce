@isTest
public class PDFControllerLayoutTest {
    
    // Helper method to create a SalesOrder record
    private static SalesOrder__c createSalesOrder(String unitOptionName, String projectName, String fitoutPalette) {
        Project__c proj = new Project__c(name = 'Nawayef Project');
        insert proj;
        Phase__c phase =  new Phase__c(Name = 'Phase 1', Project__c = proj.Id);
        insert phase;
        Unit__c unit = new Unit__c(Name = 'Unit1', Phase__c = phase.Id, plotNo__c = '1', PlotAreasqm__c=1234, UnitClassification__c = 'Villa', Number_of_Bedrooms__c = '3');
        insert unit;
        
        Unit_Option__c unitOption = new Unit_Option__c(Name = unitOptionName, category__c = 'HEIGHTS', plotNo__c = '1', PlotAreasqm__c=1234, Unit__c = unit.Id);
        insert unitOption;
        
        SalesOrder__c salesOrder = new SalesOrder__c(
            Unit__c = unit.Id,
            UnitOption__c = unitOption.Id,
            FitoutPalete__c = fitoutPalette
        );
        insert salesOrder;
        
        return salesOrder;
    }
    
    // Helper method to create ContentDocumentLink for the PDF content
    private static void createContentDocumentLink(Id salesOrderId) {
        // Create a ContentVersion, which will automatically create a ContentDocument
        ContentVersion contentVersion = new ContentVersion(
            Title = 'FloorPlan1',
            PathOnClient = 'floorplan1.pdf',
            VersionData = Blob.valueOf('Some base64 encoded content')
        );
        insert contentVersion;
        
        // Query the ContentDocumentId from the inserted ContentVersion record
        ContentVersion insertedContentVersion = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :contentVersion.Id LIMIT 1];
        
        // Create ContentDocumentLink to associate the ContentDocument with the SalesOrder
        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = insertedContentVersion.ContentDocumentId, // Get the ContentDocumentId
            LinkedEntityId = salesOrderId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        
        // Insert ContentDocumentLink
        insert cdl;
    }
    
    // Test case to verify the constructor logic and floorplan retrieval
    @isTest
    static void testConstructorLogic() {
        // Create test data
        SalesOrder__c salesOrder = createSalesOrder('Type 1', 'Al Naseem', 'Dark');
        createContentDocumentLink(salesOrder.Id);
        
        Test.startTest();
        
        // Simulate the VF page context
        ApexPages.StandardController controller = new ApexPages.StandardController(salesOrder);
        ApexPages.currentPage().getParameters().put('id', salesOrder.Id);
        PDFControllerLayout pdfController = new PDFControllerLayout(controller);
        
        Test.stopTest();
    }

    @isTest
    static void testConstructorLogic1() {
        
        Project__c proj = new Project__c(name = 'Nawayef Project');
        insert proj;
        Phase__c phase =  new Phase__c(Name = 'NAWAYEF WEST A', Project__c = proj.Id);
        insert phase;
        Unit__c unit = new Unit__c(Name = 'Unit1', Phase__c = phase.Id, plotNo__c = '1', PlotAreasqm__c=1234, UnitClassification__c = 'Villa', Number_of_Bedrooms__c = '3');
        insert unit;
        
        Unit_Option__c unitOption = new Unit_Option__c(Name = 'Type 2', category__c = 'HEIGHTS', plotNo__c = '1', PlotAreasqm__c=1234, Unit__c = unit.Id);
        insert unitOption;
        Unit_Option__c unitOption1 = new Unit_Option__c(Name = 'Type 3', category__c = 'HEIGHTS', plotNo__c = '1', PlotAreasqm__c=1234, Unit__c = unit.Id);
        insert unitOption1;
        Unit_Option__c unitOption2 = new Unit_Option__c(Name = 'Type 4', category__c = 'HEIGHTS', plotNo__c = '1', PlotAreasqm__c=1234, Unit__c = unit.Id);
        insert unitOption2;
        Unit_Option__c unitOption3 = new Unit_Option__c(Name = 'Type 5', category__c = 'HEIGHTS', plotNo__c = '1', PlotAreasqm__c=1234, Unit__c = unit.Id);
        insert unitOption3;
        Unit_Option__c unitOption4 = new Unit_Option__c(Name = 'Type 6', category__c = 'HEIGHTS', plotNo__c = '1', PlotAreasqm__c=1234, Unit__c = unit.Id);
        insert unitOption4;
        Unit_Option__c unitOption5 = new Unit_Option__c(Name = 'Type 7', category__c = 'HEIGHTS', plotNo__c = '1', PlotAreasqm__c=1234, Unit__c = unit.Id);
        insert unitOption5;
        Unit_Option__c unitOption6 = new Unit_Option__c(Name = 'Type 8', category__c = 'HEIGHTS', plotNo__c = '1', PlotAreasqm__c=1234, Unit__c = unit.Id);
        insert unitOption6;
        // Create test data
        SalesOrder__c salesOrder = new SalesOrder__c(
            Unit__c = unit.Id,
            UnitOption__c = unitOption.Id,
            FitoutPalete__c = 'Dark'
        );
        insert salesOrder;
         // Create a ContentVersion, which will automatically create a ContentDocument
        ContentVersion contentVersion = new ContentVersion(
            Title = 'FloorPlan1',
            PathOnClient = 'floorplan1.pdf',
            VersionData = Blob.valueOf('Some base64 encoded content')
        );
        insert contentVersion;
        
        // Query the ContentDocumentId from the inserted ContentVersion record
        ContentVersion insertedContentVersion = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :contentVersion.Id LIMIT 1];
        
        // Create ContentDocumentLink to associate the ContentDocument with the SalesOrder
        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = insertedContentVersion.ContentDocumentId, // Get the ContentDocumentId
            LinkedEntityId = unitOption.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        
        // Insert ContentDocumentLink
        insert cdl;
        
        Test.startTest();
        
        // Simulate the VF page context
        ApexPages.StandardController controller = new ApexPages.StandardController(salesOrder);
        ApexPages.currentPage().getParameters().put('id', salesOrder.Id);
        PDFControllerLayout pdfController = new PDFControllerLayout(controller);
        
        Test.stopTest();
    }
    
    // Test case to verify the savePDF method for successfully saving a PDF
    @isTest
    static void testSavePDFSuccess() {
        // Create test data
        SalesOrder__c salesOrder = createSalesOrder('Type 5', 'Al Naseem', 'Dark');
        createContentDocumentLink(salesOrder.Id);
        
        // Simulate the VF page context
        Test.startTest();
        
        ApexPages.StandardController controller = new ApexPages.StandardController(salesOrder);
        ApexPages.currentPage().getParameters().put('id', salesOrder.Id);
        PDFControllerLayout pdfController = new PDFControllerLayout(controller);
        
        // Set up parameters to simulate the savePDF action
        String pdfData = EncodingUtil.base64Encode(Blob.valueOf('Some PDF content'));
        ApexPages.currentPage().getParameters().put('pdfData', pdfData);
        ApexPages.currentPage().getParameters().put('recordId', salesOrder.Id);
        
        // Test the savePDF method
        PageReference resultPage = pdfController.savePDF();
        
        Test.stopTest();
    }
    
    // Test case for error handling in savePDF
    @isTest
    static void testSavePDFError() {
        // Create test data
        SalesOrder__c salesOrder = createSalesOrder('Type 4', 'Al Naseem', 'Dark');
        
        // Simulate the VF page context
        Test.startTest();
        
        ApexPages.StandardController controller = new ApexPages.StandardController(salesOrder);
        ApexPages.currentPage().getParameters().put('id', salesOrder.Id);
        PDFControllerLayout pdfController = new PDFControllerLayout(controller);
        
        // Set up invalid parameters to simulate an error scenario
        String invalidPdfData = null;  // Simulating a missing or invalid PDF data
        ApexPages.currentPage().getParameters().put('pdfData', invalidPdfData);
        ApexPages.currentPage().getParameters().put('recordId', salesOrder.Id);
        
        // Test the savePDF method
        PageReference resultPage = pdfController.savePDF();
        
        Test.stopTest();
        
        // Verify the result
        System.assert(resultPage == null, 'The result page should be null due to an error in saving PDF');
    }
    
    // Test case to validate handling of Nawayef project categories
    @isTest
    static void testNawayefProjectCategory() {
        // Create test data
        SalesOrder__c salesOrder = createSalesOrder('Type 3', 'Nawayef Heights', 'Light');
        createContentDocumentLink(salesOrder.Id);
        
        Test.startTest();
        
        // Simulate the VF page context
        ApexPages.StandardController controller = new ApexPages.StandardController(salesOrder);
        ApexPages.currentPage().getParameters().put('id', salesOrder.Id);
        PDFControllerLayout pdfController = new PDFControllerLayout(controller);
        
        Test.stopTest();
    }
    
    // Test case to verify multiple floor plans are handled properly
    @isTest
    static void testMultipleFloorPlans() {
        // Create test data
        SalesOrder__c salesOrder = createSalesOrder('Type 2', 'Al Naseem', 'Light');
        createContentDocumentLink(salesOrder.Id);
                
        // Simulate the VF page context
        Test.startTest();
        
        ApexPages.StandardController controller = new ApexPages.StandardController(salesOrder);
        ApexPages.currentPage().getParameters().put('id', salesOrder.Id);
        PDFControllerLayout pdfController = new PDFControllerLayout(controller);
        
        Test.stopTest();
    }
}