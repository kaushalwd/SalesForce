/**
* @description       : Community/Portal Get SPA DATA
* @author            : Manoj
* @last modified on  : 29-05-2025
* @last modified by  : Manoj
* --------------------------------------------------------------------------------------------------------------------
* Version       Author              Date                Comment
* 1.0           Manoj   	       29 May 2025    		Initial Draft 
* 2.0 			Manoj			   13 Oct 2025    		Update Tesclass
**/
@IsTest
public class CommunityHomeControllerAPITestcls {
  private class YourMockCallout implements HttpCalloutMock {
    public HTTPResponse respond(HTTPRequest req) {
        // Create a fake response
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setBody('{"example":"response"}');
        res.setStatusCode(200);
        return res;
    }
}
 

    @TestSetup
    static void setupTestData() {
        // Create test account
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;
        
        // Create project
        Project__c testProject = new Project__c(Name = 'Test Project');
        insert testProject;
        
        // Create phase
        Phase__c testPhase = new Phase__c(
            Name = 'Test Phase',
            Project__c = testProject.Id,
            Description__c = 'Phase Description'
        );
        insert testPhase;
        
        // Create unit
        Unit__c testUnit = new Unit__c(
            Name = 'Test Unit',
            Phase__c = testPhase.Id,
            Number_of_Bedrooms__c = '3',
            Numberofbathroom__c = 2,
            NumberofCarParks__c = 1,
            Numberofbalcony__c = 2,
            TotalArea__c = 1500,
            PlotNo__c = '101',
            Type__c = 'Apartment',
            UnitClassification__c = 'Villa'
            //Project_Name__c = 'Test Project'
        );
        insert testUnit;
        
        // Create unit option
        Unit_Option__c testOption = new Unit_Option__c(
            Name = 'Test Option',
            Unit__c = testUnit.Id,
            NumberofBedrooms__c = 3,
            NumberofCarParks__c = 1,
            PlotAreasqm__c = 1500,
            Type__c = 'Apartment',
            Typology__c = 'Premium',
            PlotNo__c = 'TR67',
            TotalGrossSellableAreaGSA__c = 1500
        );
        insert testOption;
        
        // Create payment plan
        PaymentPlan__c testPlan = new PaymentPlan__c(
            Name = 'Test Plan',
            PaymentPlanStructure__c = 'Instalp',
            Type__c = 'standard'
        );
        insert testPlan;
        
        // Create sales order
        SalesOrder__c testOrder = new SalesOrder__c(
            //Name = 'SO-0001',
            CustomerAccount__c = testAccount.Id,
            Unit__c = testUnit.Id,
            UnitOption__c = testOption.Id,
           // ProjectName__c = 'Test Project',
            TotalAmount__c = 1000000,
            //TotalGrossSellableAreaGSA__c = 1500,
           // PaymentPlanStructure__c = 'Installment Plan',
            PaymentPlan__c = testPlan.Id,
            Status__c = 'Completed',
            SPAPublicUrl__c = 'https://example.com/spa',
            FloorPlanPublicURL__c = 'https://example.com/floorplan'
          //  PortalImageName__c = 'https://example.com/image'
        );
        insert testOrder;
        
        // Create sales order installments
        List<SalesOrderInstallments__c> installments = new List<SalesOrderInstallments__c>{
            new SalesOrderInstallments__c(
                SalesOrder__c = testOrder.Id,
                InstallmentAmount__c = 200000,
                MilestoneNumber__c = 1,
                PaymentStatus__c = 'Paid',
                MilestoneDate__c = Date.today().addDays(-30)
            ),
            new SalesOrderInstallments__c(
                SalesOrder__c = testOrder.Id,
                InstallmentAmount__c = 300000,
                MilestoneNumber__c = 2,
                PaymentStatus__c = 'Partially Paid',
                MilestoneDate__c = Date.today().addDays(30)
            )
        };
        insert installments;
        
        // Create document
        Documents__c testDoc = new Documents__c(
            Name = 'Signed SPA (Modon)',
            SalesOrder__c = testOrder.Id,
            Status__c = 'Uploaded'
        );
        insert testDoc;
        testOrder.Status__c='Completed';
        update testOrder;
        // Create portal notification
        Portal_Notification__c testNotification = new Portal_Notification__c(
            Name = 'Test Notification',
            Event_Description__c = 'Test Event',
            Event_Date_Time__c = Datetime.now()
        );
        insert testNotification;
        
        // Create OIC Credential metadata
        OIC_Credential__mdt testCredential = new OIC_Credential__mdt(
            DeveloperName = 'ModonCustomerDPGAPI',
            Endpoint__c = 'https://example.com/api?',
            Username__c = 'testuser',
            Password__c = 'testpass',
            Method__c = 'GET'
        );
        // This would typically be done via a metadata deployment, but for testing we'll mock it
    }
    
    @IsTest
    static void testGetSalesOrdersByCustomer() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        Test.startTest();
        List<CommunityHomeControllerAPI.SalesOrderWrapper> results = 
            CommunityHomeControllerAPI.getSalesOrdersByCustomer(testAccount.Id,null,null);
        Test.stopTest();
    }
    
    @IsTest
    static void testGetFloorPlan() {
        SalesOrder__c testOrder = [SELECT Id FROM SalesOrder__c LIMIT 1];
        
        Test.startTest();
        String result = CommunityHomeControllerAPI.getFloorPlan(testOrder.Id);
        Test.stopTest();
    }
    
    @IsTest
    static void testGetSPA() {
        SalesOrder__c testOrder = [SELECT Id FROM SalesOrder__c LIMIT 1];
        
        Test.startTest();
        String result = CommunityHomeControllerAPI.getSPA(testOrder.Id);
        Test.stopTest();
    }
    
   /* @IsTest
    static void testGetPDF() {

        Test.setMock(HttpCalloutMock.class, new YourMockCallout());  
        SalesOrder__c testOrder = [SELECT Id FROM SalesOrder__c LIMIT 1];
        
        Test.startTest();
        String result = CommunityHomeControllerAPI.getPDF(testOrder.Id);
        Test.stopTest();
    }*/
    
    @IsTest
    static void testGetImageUrls() {
        Unit__c testUnit = [SELECT Id FROM Unit__c LIMIT 1];
        
        // Create test attachment
        Attachment testAttachment = new Attachment(
            Name = 'gallery_image.jpg',
            ParentId = testUnit.Id,
            Body = Blob.valueOf('Test')
        );
        insert testAttachment;
        
        Test.startTest();
        List<String> results = CommunityHomeControllerAPI.getImageUrls(testUnit.Id);
        Test.stopTest();
    }
    
    @IsTest
    static void testGetThisMonthsNotifications() {
        Test.startTest();
        List<CommunityHomeControllerAPI.PortalNotificationWrapper> results = 
            CommunityHomeControllerAPI.getThisMonthsNotifications();
        Test.stopTest();
    }
    
    @IsTest
    static void testMakeCallout() {
        // Mock the HTTP callout
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        
        Test.startTest();
        Map<String, String> result = CommunityHomeControllerAPI.makeCallout('project1', 'unit1');
        Test.stopTest();
    }
    
    // Mock HTTP response class
    private class MockHttpResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"success":true,"url":"https://example.com/dpg"}');
            res.setStatusCode(200);
            return res;
        }
    }

@IsTest
    static void testSuccessCase() {
        Test.setMock(HttpCalloutMock.class, new TokenMock_cls.FullMock());

        Test.startTest();
        Map<String, String> result = CommunityHomeControllerAPI.makeCallout('x', 'UnitA');
        Test.stopTest();
    }

    // ----------------------------------------------------
    // TEST CASE 2: 200 but success=false
    // ----------------------------------------------------
    @IsTest
    static void testFailureCase() {
        
        Test.setMock(HttpCalloutMock.class, new TokenMock_cls.FullMock());

        Test.startTest();
        Map<String, String> result = CommunityHomeControllerAPI.makeCallout('x', 'UnitB');
        Test.stopTest();
    }

    // ----------------------------------------------------
    // TEST CASE 3: Non-200 status code
    // ----------------------------------------------------
    @IsTest
    static void testNon200Status() {
        Test.setMock(HttpCalloutMock.class, new TokenMock_cls.FullMock());

        Test.startTest();
        Map<String, String> result = CommunityHomeControllerAPI.makeCallout('x', 'UnitC');
        Test.stopTest();

        
    }

    // ----------------------------------------------------
    // TEST CASE 4: Exception handling
    // ----------------------------------------------------
    @IsTest
    static void testExceptionCase() {
        Test.setMock(HttpCalloutMock.class, new TokenMock_cls.FullMock());

        Test.startTest();
        Map<String, String> result = CommunityHomeControllerAPI.makeCallout('x', 'UnitD');
        Test.stopTest();

    }
     @IsTest
    static void testGetSalesOrdersByCustomer1() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        Test.startTest();
        List<CommunityHomeControllerAPI.SalesOrderWrapper> results = 
            CommunityHomeControllerAPI.getSalesOrdersByCustomer(testAccount.Id,'784-1980-4712369-6',null);
        Test.stopTest();
    }
     @IsTest
    static void testGetSalesOrdersByCustomer2() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        Test.startTest();
        List<CommunityHomeControllerAPI.SalesOrderWrapper> results = 
            CommunityHomeControllerAPI.getSalesOrdersByCustomer(testAccount.Id,null,'hgjg34343');
        Test.stopTest();
    }
     @IsTest
    static void testGetSalesOrdersByCustomer3() {
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        
        Test.startTest();
        List<CommunityHomeControllerAPI.SalesOrderWrapper> results = 
            CommunityHomeControllerAPI.getSalesOrdersByCustomer(testAccount.Id,'784-1980-4712369-6','hgjg34343');
        Test.stopTest();
    }
}