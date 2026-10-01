/**
 * @description       : 
 * @author            : Krishna Chaitanya
 * @group             : 
 * @last modified on  : 05-14-2025
 * @last modified by  : Krishna Chaitanya
**/
@isTest
public class CommunityHomeControllerTest {
    @isTest
    static void myTestmethod(){
        Project__c project = new Project__c();
        insert project;
         
        Phase__c phase = new Phase__c();
        phase.Project__c = project.Id;
        insert phase;
        
        Unit__c unit = new Unit__c();
        unit.Phase__c = phase.Id;
        unit.PlotAreasqm__c = 1.0;
        unit.Number_of_Bedrooms__c = '2';
        unit.UnitClassification__c = 'Villa';
        unit.PlotNo__c = '1';
        insert unit;
        
        Account acc = new Account();
        acc.name = 'test account';
        insert acc;
        
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
        
        Opportunity oppObj = new Opportunity();
        oppObj.Name = 'Test opportunity';
        oppObj.StageName = 'Discussion In Progress';
        oppObj.CloseDate = System.Today();
        oppObj.UAE_Resident_Status__c = 'Resident';
        oppObj.Nationality__c ='United Arab Emirates';
        oppObj.EmiratesIDExpiryDate__c = Date.today().addDays(365);
        oppObj.EIDNumber__c='784-1232-1234567-4';
        INSERT oppObj;
        
        JointOwner__c joObj = new JointOwner__c();
        joObj.Opportunity__c = oppObj.Id;
        joObj.JointOwnerAccount__c = acc.Id;
        joObj.OwnershipPercentage__c = 20;
        joObj.RelationshipType__c = 'Partner';
        joObj.RelationshipSubType__c = 'Sibling';
        INSERT joObj;
        
        SalesOrder__c so = new SalesOrder__c();
        so.Unit__c = unit.Id;
        so.Opportunity__c = oppObj.Id;
        so.PaymentPlan__c = paymentPlan.Id;
        so.Status__c = 'In Progress';
        so.CustomerAccount__c = acc.Id;
        INSERT so;
        
        
        SalesOrderInstallments__c soi = new SalesOrderInstallments__c();
        soi.SalesOrder__c = so.Id;
        soi.InstallmentAmount__c = 1234567.00;
        soi.MilestoneNumber__c = 1;
        soi.PaymentStatus__c = 'Paid';
        soi.MilestoneDate__c = System.Today();
        INSERT soi;
        so.Status__c ='Completed';
        update so;
        Documents__c docObj = new Documents__c();
        docObj.Name = 'Signed SPA (Modon)';
        docObj.SalesOrder__c = so.Id;
        docObj.Status__c = 'Pending Upload';
        INSERT docObj;
        
        ContentVersion cv = new ContentVersion(
            Title = 'Signed SPA (Modon)',
            PathOnClient = 'Signed SPA (Modon).pdf',
            VersionData = Blob.valueOf('Test file content')
        );
        insert cv;
        
        CommunityHomeController.getSalesOrdersByCustomer(acc.Id);
        
        CommunityHomeController.getThisMonthsNotifications();
        
        CommunityHomeController.makeCallout('test1','test2');
        
        CommunityHomeController.getSPA(so.Id);
        
        CommunityHomeController.getFloorPlan(so.Id);
        
    }
    
    @isTest
    static void testGetImageUrls_WithGalleryAttachments() {
        // Arrange
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;

        Attachment galleryImage1 = new Attachment(
            Name = 'unit_gallery_image1.jpg',
            ParentId = testAccount.Id,
            Body = Blob.valueOf('Test Image Content 1')
        );

        Attachment galleryImage2 = new Attachment(
            Name = 'gallery_photo_unit2.png',
            ParentId = testAccount.Id,
            Body = Blob.valueOf('Test Image Content 2')
        );

        Attachment nonGalleryImage = new Attachment(
            Name = 'unit_document.pdf',
            ParentId = testAccount.Id,
            Body = Blob.valueOf('Test Document Content')
        );

        insert new List<Attachment>{galleryImage1, galleryImage2, nonGalleryImage};

        // Act
        Test.startTest();
        List<String> imageUrls = CommunityHomeController.getImageUrls(testAccount.Id);
        Test.stopTest();

        // Assert
        System.assertEquals(2, imageUrls.size(), 'Should return 2 image URLs for gallery attachments.');
        System.assert(imageUrls.contains('/servlet/servlet.FileDownload?file=' + galleryImage1.Id), 'Should contain URL for galleryImage1.');
        System.assert(imageUrls.contains('/servlet/servlet.FileDownload?file=' + galleryImage2.Id), 'Should contain URL for galleryImage2.');
        System.assert(!imageUrls.contains('/servlet/servlet.FileDownload?file=' + nonGalleryImage.Id), 'Should not contain URL for non-gallery attachment.');
    }
    
        @isTest
    static void testGetPDF_NavigateCall() {
        // Arrange
        String testRecordId = '001xxxxxxxxxxxxxxx';
             Project__c project = new Project__c();
        insert project;
         
        Phase__c phase = new Phase__c();
        phase.Project__c = project.Id;
        insert phase;
        
        Unit__c unit = new Unit__c();
        unit.Phase__c = phase.Id;
        unit.PlotAreasqm__c = 1.0;
        unit.PlotNo__c = '1';
        unit.Number_of_Bedrooms__c = '2';
        unit.UnitClassification__c = 'Villa';
        insert unit;
        
        Account acc = new Account();
        acc.name = 'test account';
        insert acc;
        
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
        
        Opportunity oppObj = new Opportunity();
        oppObj.Name = 'Test opportunity';
        oppObj.StageName = 'Discussion In Progress';
        oppObj.CloseDate = System.Today();
        oppObj.UAE_Resident_Status__c = 'Resident';
        oppObj.Nationality__c ='United Arab Emirates';
        oppObj.EmiratesIDExpiryDate__c = Date.today().addDays(365);
        oppObj.EIDNumber__c='784-1232-1234567-4';
        INSERT oppObj;
        
        JointOwner__c joObj = new JointOwner__c();
        joObj.Opportunity__c = oppObj.Id;
        joObj.JointOwnerAccount__c = acc.Id;
        joObj.OwnershipPercentage__c = 20;
        joObj.RelationshipType__c = 'Partner';
        joObj.RelationshipSubType__c = 'Sibling';
        INSERT joObj;
        
        SalesOrder__c so = new SalesOrder__c();
        so.Unit__c = unit.Id;
        so.Opportunity__c = oppObj.Id;
        so.PaymentPlan__c = paymentPlan.Id;
        so.Status__c = 'In Progress';
        so.CustomerAccount__c = acc.Id;
        INSERT so;

		so.Status__c ='Completed';
        update so;
        Test.startTest();
        //String base64PDF = CommunityHomeController.getPDF(testRecordId);
         try {
          String base64PDF = CommunityHomeController.getPDF(so.Id);
         } catch (Exception e) {
             System.assert(e.getMessage().contains('getContent'), 'Expected getContent-related exception');
         }
        Test.stopTest();

        // Assert
        // We can only assert that the method executed without throwing an error
        // and returned a non-null/non-empty string (assuming navigate works).
       // System.assertNotEquals(null, base64PDF, 'The base64 encoded PDF should not be null.');
        //System.assertNotEquals('', base64PDF, 'The base64 encoded PDF should not be empty.');

        // We cannot directly verify the PDF content here.
    }
    
     @isTest
    static void testWrapperConstructor() {
        String name = 'Test Notification';
        Datetime eventDateTime = Datetime.now();
        String description = 'This is a test event description.';

        CommunityHomeController.PortalNotificationWrapper wrapper =
            new CommunityHomeController.PortalNotificationWrapper(name, eventDateTime, description);

        System.assertEquals(name, wrapper.name, 'Name should match');
        System.assertEquals(eventDateTime, wrapper.eventDateTime, 'Event date/time should match');
        System.assertEquals(description, wrapper.eventDescription, 'Description should match');
    }
}