@isTest
public class CustomerPortalAPITest {
    // Mocked version of the service
    public class MockCustomerPortalUserService {
        public UserDTO getUserByEmail(String email) {
            User u = new User();
            UserDTO dto = new UserDTO(u);
            return dto;
        }
    }
    
    @IsTest
    static void testFindUser_Success() {
        String email = [SELECT Id,Email,UserName FROM User WHERE Id=:UserInfo.getUserId() LIMIT 1].UserName;
        // Inject test context
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestUri = '/services/apexrest/CustomerPortalUserAPI';
        req.httpMethod = 'GET';
        req.addParameter('userName', email);
        
        RestContext.request = req;
        RestContext.response = res;
        Test.startTest();
        CustomerPortalUserAPI.findUser();
        CustomerPortalProfileAPI.findUser();
        CustomerPortalUnitsAPI.findUnits();
        CustomerPortalSOAAPI.findSOADetails();
        Test.stopTest();
        String responseBody = RestContext.response.responseBody.toString();  }
    
    @IsTest
    static void testFindUser_MissingEmail() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestUri = '/services/apexrest/CustomerPortalUserAPI';
        req.httpMethod = 'GET';
        // No userName param
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        CustomerPortalUserAPI.findUser();
        CustomerPortalProfileAPI.findUser();
        CustomerPortalProfileAPI.createSupportCase();
        CustomerPortalUnitsAPI.findUnits();
        Test.stopTest();
        
    }
    
    @IsTest
    static void testFindUser_UserNotFound() {
        // Simulate request for a user that doesn't exist
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestUri = '/services/apexrest/CustomerPortalUserAPI';
        req.httpMethod = 'GET';
        req.addParameter('userName', 'notfound@example.com');
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        CustomerPortalUserAPI.findUser();
        CustomerPortalUnitsAPI.findUnits();
        Test.stopTest();
    }
    @isTest static void testResetPassword(){
        String email = [SELECT Id,Email,UserName FROM User WHERE Id=:UserInfo.getUserId() LIMIT 1].UserName;
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.httpMethod = 'GET';
        req.requestUri = '/services/apexrest/CustomerPortalUserAPI';
        req.addParameter('userName',email);
        req.addParameter('resetpassword', 'true');
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        CustomerPortalProfileAPI.findUser();
        Test.stopTest();
        
    }
    @isTest static void createSupportCaseTest(){
        String email = [SELECT Id,Email,UserName FROM User WHERE Id=:UserInfo.getUserId() LIMIT 1].UserName;
        
        CustomerPortalProfileAPI.supportCaseWrapper wrapper = new CustomerPortalProfileAPI.supportCaseWrapper();
        wrapper.subject = 'Test Case Subject';
        wrapper.caseComments = 'This is a test comment for the case.';
        wrapper.mobile = '9876543210';
        wrapper.isGeneralCase = true;
        wrapper.phone = '0123456789';
        wrapper.email = email;
        wrapper.street = '123 Test Street';
        wrapper.city = 'Testville';
        wrapper.state = 'TestState';
        wrapper.postalCode = '123456';
        wrapper.country = 'Testland';
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.httpMethod = 'POST';
        req.requestUri = '/services/apexrest/CustomerPortalUserAPI';
        req.requestBody = Blob.valueOf(JSON.serialize(wrapper));
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        CustomerPortalProfileAPI.createSupportCase();
        Test.stopTest();
    }
    @isTest static void createContactSupportCaseTest(){
        String email = [SELECT Id,Email,UserName FROM User WHERE Id=:UserInfo.getUserId() LIMIT 1].UserName;
        
        CustomerPortalProfileAPI.supportCaseWrapper wrapper = new CustomerPortalProfileAPI.supportCaseWrapper();
        wrapper.subject = 'Test Case Subject';
        wrapper.caseComments = 'This is a test comment for the case.';
        wrapper.mobile = '9876543210';
        wrapper.isGeneralCase = false;
        wrapper.phone = '0123456789';
        wrapper.email = email;
        wrapper.street = '123 Test Street';
        wrapper.city = 'Testville';
        wrapper.state = 'TestState';
        wrapper.postalCode = '123456';
        wrapper.country = 'Testland';
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.httpMethod = 'POST';
        req.requestUri = '/services/apexrest/CustomerPortalUserAPI';
        req.requestBody = Blob.valueOf(JSON.serialize(wrapper));
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        CustomerPortalProfileAPI.createSupportCase();
        Test.stopTest();
    }
    @isTest static void getSalesOrdersByCustomerTest(){
        // Create a Person Account (automatically creates a Contact behind the scenes)
          RecordType paRT = [
            SELECT Id FROM RecordType 
            WHERE SObjectType = 'Account' AND IsPersonType = true 
            LIMIT 1
        ];

        // Create Person Account (auto creates related Contact)
        Account personAcc = new Account(
            RecordTypeId = paRT.Id,
            FirstName = 'Test',
            LastName = 'CommunityPA',
            Phone = '1234567890',
            PersonEmail = 'communityuser@example.com'
        );
        insert personAcc;

        // Get related contact
        Contact contact = [SELECT Id FROM Contact WHERE AccountId = :personAcc.Id LIMIT 1];

        // Get a Customer Community profile
        Profile portalProfile = [SELECT Id FROM Profile WHERE UserType LIKE '%Portal%' LIMIT 1];

        // Create the community user
        User communityUser = new User(
            Username = 'testcommunityuser' + DateTime.now().getTime() + '@example.com',
            Email = 'communityuser@example.com',
            Alias = 'cuser',
            FirstName = 'Test',
            LastName = 'User',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = portalProfile.Id,
            ContactId = contact.Id
        );
        insert communityUser;
        
         Project__c project = new Project__c();
        insert project;
         
        Phase__c phase = new Phase__c();
        phase.Project__c = project.Id;
        insert phase;
        
        Unit__c unit = new Unit__c();
        unit.Phase__c = phase.Id;
        unit.PlotAreasqm__c = 1.0;
        unit.PlotNo__c = '1';
         unit.UnitClassification__c = 'Villa';
        unit.Number_of_Bedrooms__c = '1';
        insert unit;
        
        
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
        oppObj.AccountId =personAcc.Id;
        oppObj.Nationality__c='United Arab Emirates';
        oppObj.UAE_Resident_Status__c='Resident';
        oppObj.EmiratesIDExpiryDate__c =System.today().addDays(200);
        INSERT oppObj;
        
        JointOwner__c joObj = new JointOwner__c();
        joObj.Opportunity__c = oppObj.Id;
        joObj.JointOwnerAccount__c = personAcc.Id;
        joObj.OwnershipPercentage__c = 20;
        joObj.RelationshipType__c = 'Partner';
        joObj.RelationshipSubType__c = 'Sibling';
        INSERT joObj;
        
        SalesOrder__c so = new SalesOrder__c();
        so.Unit__c = unit.Id;
        
        so.Opportunity__c = oppObj.Id;
        so.PaymentPlan__c = paymentPlan.Id;
        so.Status__c = 'In Progress';
        so.CustomerAccount__c=personAcc.Id;
        INSERT so;
        
        
        SalesOrderInstallments__c soi = new SalesOrderInstallments__c();
        soi.SalesOrder__c = so.Id;
        soi.Milestone__c = 1;
        soi.InstallmentAmount__c = 100;
        insert soi;
        CommunityHomeControllerAPI.getFloorPlan(so.Id);
        CommunityHomeControllerAPI.getSPA(so.Id);
        CommunityHomeControllerAPI.getImageUrls(so.Id);
        CommunityHomeControllerAPI.getThisMonthsNotifications();
        CommunityHomeControllerAPI.makeCallout('parm1','parm2');
       
        
        String email = [SELECT Id,Email,UserName FROM User WHERE Id=:communityUser.Id LIMIT 1].UserName;
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.httpMethod = 'GET';
        req.requestUri = '/services/apexrest/CustomerPortalUnitsAPI';
        req.addParameter('userName',email);
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        CustomerPortalUnitsAPI.findUnits();
        Test.stopTest();
        
    }
    @isTest static void CustomerPortalSOAAPITest(){
        Project__c project = new Project__c();
        insert project;
         
        Phase__c phase = new Phase__c();
        phase.Project__c = project.Id;
        insert phase;
        
        Unit__c unit = new Unit__c();
        unit.Phase__c = phase.Id;
        unit.PlotAreasqm__c = 1.0;
        unit.PlotNo__c = '1';
        unit.UnitClassification__c = 'Villa';
        unit.Number_of_Bedrooms__c = '1';
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
        oppObj.AccountId =acc.id;
        oppObj.Nationality__c='United Arab Emirates';
        oppObj.UAE_Resident_Status__c='Resident';
        oppObj.EmiratesIDExpiryDate__c =System.today().addDays(200);
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
        so.CustomerAccount__c=acc.id;
        INSERT so;
        String soName = [SELECT Name FROM SalesOrder__c WHERE Id=:so.Id LIMIT 1].Name;
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.httpMethod = 'GET';
        req.requestUri = '/services/apexrest/CustomerPortalSOAAPI';
        req.addParameter('SOId',soName);
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        CustomerPortalSOAAPI.findSOADetails();
        Test.stopTest();
    }
    @isTest static void CustomerPortalErrorSOAAPITest(){
        Project__c project = new Project__c();
        insert project;
         
        Phase__c phase = new Phase__c();
        phase.Project__c = project.Id;
        insert phase;
        
        Unit__c unit = new Unit__c();
        unit.Phase__c = phase.Id;
        unit.PlotAreasqm__c = 1.0;
        unit.PlotNo__c = '1';
        unit.UnitClassification__c = 'Villa';
        unit.Number_of_Bedrooms__c = '1';
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
        oppObj.AccountId =acc.id;
        oppObj.Nationality__c='United Arab Emirates';
        oppObj.UAE_Resident_Status__c='Resident';
        oppObj.EmiratesIDExpiryDate__c =System.today().addDays(200);

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
        so.CustomerAccount__c=acc.id;
        INSERT so;
        
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.httpMethod = 'GET';
        req.requestUri = '/services/apexrest/CustomerPortalSOAAPI';
        req.addParameter('SOId',so.Id);
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        CustomerPortalSOAAPI.findSOADetails();
        CommunityHomeControllerAPI.PortalNotificationWrapper pwrap = new CommunityHomeControllerAPI.PortalNotificationWrapper( 'name', DateTime.now(),  'eventDescription');
        Test.stopTest();
    }

}