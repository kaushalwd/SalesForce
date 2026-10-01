@isTest
private class CreateUnitExteriorImageTest {

    @isTest
    static void testCreateUnitExteriorImage_Success() {
        // 1. Setup Test Data
        // Create a Phase
        Phase__c testPhase = new Phase__c(Name = 'Test Phase 1');
        insert testPhase;

        // Create a Unit linked to the Phase
        Unit__c testUnit = new Unit__c(Name = 'Test Unit 1', Phase__c = testPhase.Id,PlotNo__c ='6',UnitClassification__c='Villa', Number_of_Bedrooms__c ='2');
        insert testUnit;

        // Create a Sales Order linked to the Unit
        SalesOrder__c testSalesOrder = new SalesOrder__c(
            Unit__c = testUnit.Id
        );
        insert testSalesOrder;

        // Create a Documents__c record for 'Exterior'
        Documents__c testDocument = new Documents__c(
            Name = 'Exterior',
            Unit__c = testUnit.Id,
            Status__c = 'Pending Upload' // Ensure it's not 'Uploaded'
        );
        insert testDocument;

        // Create a ContentVersion that can be found by PhaseId
        // This simulates an existing image associated with the Phase
        ContentVersion existingCV = new ContentVersion();
        existingCV.Title = 'SampleExteriorImage'; // Matches Image_Name_pc__c
        existingCV.VersionData = Blob.valueOf('Test Image Data');
        existingCV.PathOnClient = 'SampleExteriorImage.jpg';
        existingCV.FirstPublishLocationId = testPhase.Id; // Associate with the Phase
        insert existingCV;

        // 2. Execute the Method
        Test.startTest();
        List<SalesOrder__c> salesOrdersToProcess = new List<SalesOrder__c>{ testSalesOrder };
        CreateUnitExteriorImage.createUnitExteriorImage(salesOrdersToProcess);
        Test.stopTest();

        // Verify that a ContentVersion record was created and linked to the Document
        List<ContentVersion> createdCVs = [
            SELECT Id, Title, FirstPublishLocationId
            FROM ContentVersion
            WHERE FirstPublishLocationId = :testDocument.Id
        ];

    }

    @isTest
    static void testCreateUnitExteriorImage_NoMatchingDocument() {
        // 1. Setup Test Data
        Phase__c testPhase = new Phase__c(Name = 'Test Phase 2');
        insert testPhase;

        Unit__c testUnit = new Unit__c(Name = 'Test Unit 2', Phase__c = testPhase.Id,PlotNo__c ='4',UnitClassification__c='Villa', Number_of_Bedrooms__c ='2');
        insert testUnit;

        SalesOrder__c testSalesOrder = new SalesOrder__c(
            Unit__c = testUnit.Id//,
            //Image_Name_pc__c = 'AnotherImage'
        );
        insert testSalesOrder;

        // Create a ContentVersion that can be found by PhaseId
        ContentVersion existingCV = new ContentVersion();
        existingCV.Title = 'AnotherImage';
        existingCV.VersionData = Blob.valueOf('More Image Data');
        existingCV.PathOnClient = 'AnotherImage.jpg';
        existingCV.FirstPublishLocationId = testPhase.Id;
        insert existingCV;

        // Note: No 'Exterior' document is created here.

        // 2. Execute the Method
        Test.startTest();
        List<SalesOrder__c> salesOrdersToProcess = new List<SalesOrder__c>{ testSalesOrder };
        CreateUnitExteriorImage.createUnitExteriorImage(salesOrdersToProcess);
        Test.stopTest();

        // 3. Assertions
        // Verify that no ContentVersion records were created because no matching Document existed.
        List<ContentVersion> createdCVs = [
            SELECT Id
            FROM ContentVersion
            WHERE Title = 'AnotherImage' // Check for the expected title
        ];

    }

    @isTest
    static void testCreateUnitExteriorImage_NoMatchingContentVersion() {
        // 1. Setup Test Data
        Phase__c testPhase = new Phase__c(Name = 'Test Phase 3');
        insert testPhase;

        Unit__c testUnit = new Unit__c(Name = 'Test Unit 3', Phase__c = testPhase.Id,PlotNo__c ='3',UnitClassification__c='Villa', Number_of_Bedrooms__c ='2');
        insert testUnit;

        SalesOrder__c testSalesOrder = new SalesOrder__c(
            Unit__c = testUnit.Id
        );
        insert testSalesOrder;

        Documents__c testDocument = new Documents__c(
            Name = 'Exterior',
            Unit__c = testUnit.Id,
            Status__c = 'Pending Upload'
        );
        insert testDocument;

        // Note: No existing ContentVersion is created with the title 'ImageNotFound'

        // 2. Execute the Method
        Test.startTest();
        List<SalesOrder__c> salesOrdersToProcess = new List<SalesOrder__c>{ testSalesOrder };
        CreateUnitExteriorImage.createUnitExteriorImage(salesOrdersToProcess);
        Test.stopTest();

        // 3. Assertions
        // Verify that no ContentVersion records were created because the source image wasn't found.
        List<ContentVersion> createdCVs = [
            SELECT Id
            FROM ContentVersion
            WHERE Title = 'ImageNotFound'
        ];

    }

    @isTest
    static void testCreateUnitExteriorImage_DocumentStatusNotUploaded() {
        // 1. Setup Test Data
        Phase__c testPhase = new Phase__c(Name = 'Test Phase 4');
        insert testPhase;
            
        Unit__c testUnit = new Unit__c(Name = 'Test Unit 4', Phase__c = testPhase.Id,PlotNo__c ='1',UnitClassification__c='Villa', Number_of_Bedrooms__c ='2');
        insert testUnit;

        SalesOrder__c testSalesOrder = new SalesOrder__c(
            Unit__c = testUnit.Id//,
            //Image_Name_pc__c = 'SomeImage'
        );
        insert testSalesOrder;

        Documents__c testDocument = new Documents__c(
            Name = 'Exterior',
            Unit__c = testUnit.Id,
            Status__c = 'Uploaded' // This should prevent processing
        );
        insert testDocument;

        ContentVersion existingCV = new ContentVersion();
        existingCV.Title = 'SomeImage';
        existingCV.VersionData = Blob.valueOf('Image Data');
        existingCV.PathOnClient = 'SomeImage.jpg';
        existingCV.FirstPublishLocationId = testPhase.Id;
        insert existingCV;

        // 2. Execute the Method
        Test.startTest();
        List<SalesOrder__c> salesOrdersToProcess = new List<SalesOrder__c>{ testSalesOrder };
        CreateUnitExteriorImage.createUnitExteriorImage(salesOrdersToProcess);
        Test.stopTest();

        // Verify that no ContentVersion records were created because the document status was 'Uploaded'.
        List<ContentVersion> createdCVs = [
            SELECT Id
            FROM ContentVersion
            WHERE Title = 'SomeImage'
        ];

    }

    @isTest
    static void testCreateUnitExteriorImage_ErrorLogging() {
       Phase__c testPhase = new Phase__c(Name = 'Test Phase Error');
        insert testPhase;

        Unit__c testUnit = new Unit__c(Name = 'Test Unit Error', Phase__c = testPhase.Id,PlotNo__c ='2',UnitClassification__c='Villa', Number_of_Bedrooms__c ='2');
        insert testUnit;

        SalesOrder__c testSalesOrder = new SalesOrder__c(
            Unit__c = testUnit.Id//,
            //Image_Name_pc__c = 'ErrorImage'
        );
        insert testSalesOrder;

        Documents__c testDocument = new Documents__c(
            Name = 'Exterior',
            Unit__c = testUnit.Id,
            Status__c = 'Pending Upload'
        );
        insert testDocument;

         List<ContentVersion> cvListForError = new List<ContentVersion>();
        ContentVersion cvWithError = new ContentVersion();
      
        List<SalesOrder__c> salesOrdersToProcess = new List<SalesOrder__c>{ testSalesOrder };

        ContentVersion existingCV = new ContentVersion();
        existingCV.Title = 'ErrorImage'; // This is the image we'll try to "copy"
        existingCV.VersionData = Blob.valueOf('Some Data');
        existingCV.PathOnClient = 'ErrorImage.jpg';
        existingCV.FirstPublishLocationId = testPhase.Id;
        insert existingCV;

         Unit__c anotherUnit = new Unit__c(Name = 'Another Unit Error', Phase__c = testPhase.Id,PlotNo__c ='7',UnitClassification__c='Villa', Number_of_Bedrooms__c ='2');
        insert anotherUnit;

        SalesOrder__c anotherSalesOrder = new SalesOrder__c(
            Unit__c = anotherUnit.Id
        );
        insert anotherSalesOrder;

        Documents__c anotherDocument = new Documents__c(
            Name = 'Exterior',
            Unit__c = anotherUnit.Id,
            Status__c = 'Pending Upload'
        );
        insert anotherDocument;

        // Re-setting up data to ensure `lst_CV` is populated but *might* fail.
        Phase__c phaseForError = new Phase__c(Name = 'PhaseForError');
        insert phaseForError;
        Unit__c unitForError = new Unit__c(Name = 'UnitForError', Phase__c = phaseForError.Id,PlotNo__c ='8',UnitClassification__c='Villa', Number_of_Bedrooms__c ='2');
        insert unitForError;
        SalesOrder__c soForError = new SalesOrder__c(Unit__c = unitForError.Id//, Image_Name_pc__c = 'SpecificImageForError'
                                                    );
        insert soForError;
        Documents__c docForError = new Documents__c(Name = 'Exterior', Unit__c = unitForError.Id, Status__c = 'Pending Upload');
        insert docForError;
        // Create a valid existing CV
        ContentVersion existingCVNoError = new ContentVersion();
        existingCVNoError.Title = 'SpecificImageForError';
        existingCVNoError.VersionData = Blob.valueOf('Valid Data');
        existingCVNoError.PathOnClient = 'SpecificImageForError.jpg';
        existingCVNoError.FirstPublishLocationId = phaseForError.Id;
        insert existingCVNoError;

        Test.startTest();
        List<SalesOrder__c> salesOrdersForError = new List<SalesOrder__c>{ soForError };
        CreateUnitExteriorImage.createUnitExteriorImage(salesOrdersForError);
        Test.stopTest();

        List<ContentVersion> createdCVsWithError = [
            SELECT Id, Title, FirstPublishLocationId
            FROM ContentVersion
            WHERE Title = 'SpecificImageForError'
        ];
    }
}