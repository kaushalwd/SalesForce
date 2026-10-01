/**
 * @***************************************           : ***************************************
 * @Name                                              : Enter description here
 * @Description                                       : Enter description here
 * @Usage                                             : Enter usage here
 * @Author                                            : AMGS
 * @------------------------------------------------  : ------------------------------------------------
 * @Version Comment                                   : 1.0
 * @Author                                            : Fatima Khan
 * @Date                                              : 09-17-2025
 * @***************************************           : ***************************************
**/
@isTest
private class MBP_ProjectDetailPageControllerTest {

@testSetup
static void setup() {
    Account acc = new Account(Name = 'Test Account');
    insert acc;

    Contact agent = new Contact(
        FirstName = 'Test',
        LastName  = 'Agent',
        Email     = 'agent@test.com',
        IsBroker__c = true,
        Agent_Status__c = 'Active',
        AccountId = acc.Id
    );
    insert agent;

    // Create Project
    Project__c project = new Project__c(
        Name = 'Test Project',
        //ProjectNumber__c = 'P001',
        //Project_Description__c = 'Test Description',
        Total_Units__c = 5
        //Location__Latitude__s = 25.276987,
        //Location__Longitude__s = 55.296249,
        //Starting_Price__c = 1000000
    );
    insert project;

    // Create Phase
    Phase__c phase = new Phase__c(
        Name = 'Phase 1',
        Project__c = project.Id
    );
    insert phase;

    // Create Unit
    Unit__c unit = new Unit__c(
        Name = 'Unit 101',
        Phase__c = phase.Id,
        Number_of_Bedrooms__c = '2',
        Status__c = 'Available',
        //Allocate_to_Agent__c = agent.Id,
        PlotNo__c='001', 
        UnitClassification__c='Villa',
        Type__c='q'
    );
    insert unit;

//     // Create Payment Plan
//         PaymentPlan__c plan = new PaymentPlan__c(
//             Name = 'Plan A',
//             Project__c = project.Id,
//             PaymentPlanStructure__c = '30-40',
//             Unit__c = unit.Id,
//             Type__c='Standard'
//         );
//         insert plan;

//         // Create Payment Installment
//         PaymentInstallements__c inst = new PaymentInstallements__c(
//             Name = 'Installment 1',
//             PaymentInstallment__c = plan.Id,
//             Milestone__c = 30.0,
//             MilestoneNumber__c = 1,
//             MilestoneDate__c = Date.today()
//         );
//         insert inst;
//     // Create Offer Promotion + OfferLine
//     OffersPromotions__c offerName = new OffersPromotions__c(
//         Name = 'Offer1',
//         Project__c = project.Id,
//         StartDate__c = Date.today().addDays(1),
//         EndDate__c = Date.today().addDays(10),
//         OfferName__c='Hi'
//     );
//     insert offerName;

//     OfferLines__c offer = new OfferLines__c(
//         OfferName__c = offerName.Id,
//         OfferValue__c = 5,
//         OfferValueType__c = 'Percentage',
//         DiscountType__c = 'Bulk Discount',
//         OfferType__c = 'Rebate',
//         Unit__c = unit.Id,
//         OfferOn__c ='Net Amount'
//     );
//     insert offer;

//     // Create Amenity
//     Amenities__c amenity = new Amenities__c(
//         Project__c = project.Id,
//         Amenity__c = 'Barbecue Area'
//     );
//     insert amenity;

//     // Create Documents
//     Documents__c doc1 = new Documents__c(
//         Name = 'Master Plan',
//         Project__c = project.Id
//     );
//     insert doc1;

//     Documents__c doc2 = new Documents__c(
//         Name = 'Floor Plan - 2BHK',
//         Project__c = project.Id,
//         Document_Unit_Type__c = 'Type A',
//         Number_of_Beds__c = 2,
//         Number_of_Bathrooms__c = 2,
//         Starting_Area__c = 1100
//     );
//     insert doc2;

//     Documents__c unitDoc = new Documents__c(
//         Name = 'Exterior',
//         Unit__c = unit.Id
//     );
//     insert unitDoc;
    
//     // Extra project documents for image/brochure coverage
// Documents__c thumbDoc = new Documents__c(
//     Name = 'Thumbnail',
//     Project__c = project.Id
// );
// insert thumbDoc;

// Documents__c galleryDoc = new Documents__c(
//     Name = 'Gallery',
//     Project__c = project.Id
// );
// insert galleryDoc;

// Documents__c brochureDoc = new Documents__c(
//     Name = 'English brochure',
//     Project__c = project.Id
// );
// insert brochureDoc;

// // Extra floor plan to trigger FloorPlanDTO population
// Documents__c floorDoc = new Documents__c(
//     Name = 'Floor Plan Type B',
//     Project__c = project.Id,
//     Document_Unit_Type__c = 'Type B',
//     Number_of_Beds__c = 3,
//     Number_of_Bathrooms__c = 2,
//     Starting_Area__c = 1300
// );
// insert floorDoc;

// // Unit images (Interior)
// Documents__c interiorDoc = new Documents__c(
//     Name = 'Interior',
//     Unit__c = unit.Id
// );
// insert interiorDoc;

// // Add multiple ContentVersions with different extensions
// List<ContentVersion> cvs = new List<ContentVersion>{
//     new ContentVersion(Title='Thumb Image', PathOnClient='thumb.png',
//         VersionData=Blob.valueOf('pngdata'), IsMajorVersion=true),
//     new ContentVersion(Title='Gallery Image', PathOnClient='gallery.gif',
//         VersionData=Blob.valueOf('gifdata'), IsMajorVersion=true),
//     new ContentVersion(Title='Brochure File', PathOnClient='brochure.pdf',
//         VersionData=Blob.valueOf('pdfdata'), IsMajorVersion=true),
//     new ContentVersion(Title='Floor Plan File', PathOnClient='floor.svg',
//         VersionData=Blob.valueOf('svgdata'), IsMajorVersion=true),
//     new ContentVersion(Title='Interior File', PathOnClient='interior.webp',
//         VersionData=Blob.valueOf('webpdata'), IsMajorVersion=true)
// };
// insert cvs;

// // Map ContentVersions to ContentDocuments
// Map<String, Id> docIdsByName = new Map<String, Id>{
//     'Thumbnail' => thumbDoc.Id,
//     'Gallery'   => galleryDoc.Id,
//     'English brochure' => brochureDoc.Id,
//     'Floor Plan Type B' => floorDoc.Id,
//     'Interior'  => interiorDoc.Id
// };

// Integer i = 0;
// for (ContentVersion cvRow : cvs) {
//     insert new ContentDocumentLink(
//         ContentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cvRow.Id].ContentDocumentId,
//         LinkedEntityId = docIdsByName.values()[i],
//         ShareType = 'V',
//         Visibility = 'AllUsers'
//     );
//     i++;
// }

//     // ContentVersion + ContentDocumentLink
//     ContentVersion cv = new ContentVersion(
//         Title = 'Test Image',
//         PathOnClient = 'test.jpg',
//         VersionData = Blob.valueOf('test data'),
//         IsMajorVersion = true
//     );
//     insert cv;

//     ContentDocumentLink link = new ContentDocumentLink(
//         ContentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId,
//         LinkedEntityId = doc1.Id,
//         ShareType = 'V',
//         Visibility = 'AllUsers'
//     );
//     insert link;
}
    
// }

    @isTest
    static void testFetchUnitsAndUpdateAllocations() {
        Id projectId = [SELECT Id FROM Project__c LIMIT 1].Id;
        List<MBP_ProjectDetailPageController.UnitWrapper> units = MBP_ProjectDetailPageController.fetchUnits(projectId);
    }





    // @isTest
    // static void testFetchProjectBundleById() {
    //     Id projectId = [SELECT Id FROM Project__c LIMIT 1].Id;
    //     MBP_ProjectDetailPageController.ProjectBundle bundle = MBP_ProjectDetailPageController.fetchProjectBundleById(projectId);
    // }

    // @isTest
    // static void testFetchProjectBundleByUnitId() {
    //     Id unitId = [SELECT Id FROM Unit__c LIMIT 1].Id;
    //     MBP_ProjectDetailPageController.ProjectBundle bundle = MBP_ProjectDetailPageController.fetchProjectBundleByUnitId(unitId);
    // }

    // @isTest
    // static void testFetchFloorPlans() {
    //     Id projectId = [SELECT Id FROM Project__c LIMIT 1].Id;
    //     MBP_ProjectDetailPageController.fetchFloorPlans(projectId);
    // }

    // @isTest
    // static void testFetchMasterPlanImage() {
    //     Id projectId = [SELECT Id FROM Project__c LIMIT 1].Id;
    //     MBP_ProjectDetailPageController.fetchMasterPlanImage(projectId);
    // }

    // @isTest
    // static void testFetchProjectImages() {
    //     Id projectId = [SELECT Id FROM Project__c LIMIT 1].Id;
    //     MBP_ProjectDetailPageController.fetchProjectImages(projectId);
    // }

    // @isTest
    // static void testFetchUnitImages() {
    //     Id unitId = [SELECT Id FROM Unit__c LIMIT 1].Id;
    //     MBP_ProjectDetailPageController.fetchUnitImages(unitId);
    // }

    // @isTest
    // static void testFetchDownloadableDocuments() {
    //     Id projectId = [SELECT Id FROM Project__c LIMIT 1].Id;
    //     MBP_ProjectDetailPageController.fetchDownloadableDocuments(projectId);
    // }

    // @isTest
    // static void testFetchPaymentPlansWithInstallments() {
    //     Id projectId = [SELECT Id FROM Project__c LIMIT 1].Id;
    //     MBP_ProjectDetailPageController.fetchPaymentPlansWithInstallments(projectId);
    // }

    // @isTest
    // static void testFetchOfferLines() {
    //     Id projectId = [SELECT Id FROM Project__c LIMIT 1].Id;
    //     MBP_ProjectDetailPageController.fetchOfferLines(projectId);
    // }

    // @isTest
    // static void testFetchAmenities() {
    //     Id projectId = [SELECT Id FROM Project__c LIMIT 1].Id;
    //     MBP_ProjectDetailPageController.fetchAmenities(projectId);
    // }

    // @isTest
    // static void testFetchUnitTypologies() {
    //     Id projectId = [SELECT Id FROM Project__c LIMIT 1].Id;
    // }

    // @isTest
    // static void testFetchProjects() {
    //     Id projectId = [SELECT Id FROM Project__c LIMIT 1].Id;
    //     MBP_ProjectDetailPageController.fetchProjects(projectId);
    // }
}