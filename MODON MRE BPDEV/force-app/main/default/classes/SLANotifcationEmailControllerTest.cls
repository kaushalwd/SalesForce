@isTest
public class SLANotifcationEmailControllerTest {
  
    @TestSetup
    static void doSetupData(){
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
        oppObj.UAE_Resident_Status__c = 'Resident';
        oppObj.Nationality__c = 'United Arab Emirates';
        oppObj.EmiratesIDExpiryDate__c = Date.TODAY();
        oppObj.EIDNumber__c = '784-1990-1234567-8';
        oppObj.En_Nationality__c = 'India';
        oppObj.En_PassportNumber__c = 'P1234567';
        oppObj.En_EIDNumber__c = '784-1990-1234567-8';
        INSERT oppObj;
        
        JointOwner__c joObj = new JointOwner__c();
        joObj.Opportunity__c = oppObj.Id;
        joObj.JointOwnerAccount__c = acc.Id;
        joObj.OwnershipPercentage__c = 20;
        joObj.RelationshipType__c = 'Partner';
        joObj.RelationshipSubType__c = 'Sibling';
        INSERT joObj;
        
    // Profile for user creation
    Id profId = [SELECT Id FROM Profile WHERE Name = 'Sales Management' LIMIT 1].Id;

        // Create four active test users
        User user1 = new User(
            Username = 'testuser1_' + System.currentTimeMillis() + '@test.com',
            LastName = 'User1',
            Email = 'testuser1@test.com',
            Alias = 'tuser1',
            TimeZoneSidKey = 'Pacific/Apia',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = profId,
            LanguageLocaleKey = 'en_US',
            IsActive = true
        );
        insert user1;

        User user2 = new User(
            Username = 'testuser2_' + System.currentTimeMillis() + '@test.com',
            LastName = 'User2',
            Email = 'testuser2@test.com',
            Alias = 'tuser2',
            TimeZoneSidKey = 'Pacific/Apia',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = profId,
            LanguageLocaleKey = 'en_US',
            IsActive = true
        );
        insert user2;

        User user3 = new User(
            Username = 'testuser3_' + System.currentTimeMillis() + '@test.com',
            LastName = 'User3',
            Email = 'testuser3@test.com',
            Alias = 'tuser3',
            TimeZoneSidKey = 'Pacific/Apia',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = profId,
            LanguageLocaleKey = 'en_US',
            IsActive = true
        );
        insert user3;

        User user4 = new User(
            Username = 'testuser4_' + System.currentTimeMillis() + '@test.com',
            LastName = 'User2',
            Email = 'testuser4@test.com',
            Alias = 'tuser4',
            TimeZoneSidKey = 'Pacific/Apia',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = profId,
            LanguageLocaleKey = 'en_US',
            IsActive = true
        );
        insert user4;

        SalesOrder__c so = new SalesOrder__c();
        so.Unit__c = unit.Id;
        
        so.Opportunity__c = oppObj.Id;
        so.PaymentPlan__c = paymentPlan.Id;
        so.Status__c = 'In Progress';
        so.CustomerAccount__c=acc.id;
        so.Customer_Management_Associate__c = user1.id;
        so.SalesAssociate__c = user2.id;
        so.Sales_Operations_Associate__c = user3.id;
        so.Finance_Associate__c = user4.id;

        INSERT so;         
    }
    
    @istest
    static void testMethodCM() {
        SalesOrder__c so = [SELECT Id, Name FROM SalesOrder__c LIMIT 1];
        SLANotifcationEmailController.Request req = new SLANotifcationEmailController.Request();
        req.salesOrderId = so.Id;
        req.team = 'Customer Management';

        List<SLANotifcationEmailController.Request> reqList = new List<SLANotifcationEmailController.Request>();
        reqList.add(req);

        test.startTest();
        SLANotifcationEmailController.sendSlaEmails(reqList);
        test.stopTest();
    }
    
    @istest
    static void testMethodSA() {
        SalesOrder__c so = [SELECT Id, Name FROM SalesOrder__c LIMIT 1];

        SLANotifcationEmailController.Request req = new SLANotifcationEmailController.Request();
        req.salesOrderId = so.Id;
        req.team = 'Sales Associate';

        List<SLANotifcationEmailController.Request> reqList = new List<SLANotifcationEmailController.Request>();
        reqList.add(req);

        test.startTest();
        SLANotifcationEmailController.sendSlaEmails(reqList);
        test.stopTest();
    }
    
    @istest
    static void testMethodSOA() {
        SalesOrder__c so = [SELECT Id, Name FROM SalesOrder__c LIMIT 1];

        SLANotifcationEmailController.Request req = new SLANotifcationEmailController.Request();
        req.salesOrderId = so.Id;
        req.team = 'Sales Operation Associate';

        List<SLANotifcationEmailController.Request> reqList = new List<SLANotifcationEmailController.Request>();
        reqList.add(req);

        test.startTest();
        SLANotifcationEmailController.sendSlaEmails(reqList);
        test.stopTest();
    } 
    
    @istest
    static void testMethodFA() {
        SalesOrder__c so = [SELECT Id, Name FROM SalesOrder__c LIMIT 1];       

        SLANotifcationEmailController.Request req = new SLANotifcationEmailController.Request();
        req.salesOrderId = so.Id;
        req.team = 'Finance Associate';

        List<SLANotifcationEmailController.Request> reqList = new List<SLANotifcationEmailController.Request>();
        reqList.add(req);

        test.startTest();
        SLANotifcationEmailController.sendSlaEmails(reqList);
        test.stopTest();
    }
    
    
}