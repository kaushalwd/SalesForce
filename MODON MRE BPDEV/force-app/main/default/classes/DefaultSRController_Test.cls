@isTest
public class DefaultSRController_Test {

    @testSetup
    static void setupData() {
        // Create Person Account
        Id personRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();
        Account acc = new Account(LastName = 'Test Person', RecordTypeId = personRtId, PersonEmail='test@gmail.com');
        insert acc;
        
         Id businessRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('OrganizationAccount').getRecordTypeId();
        Account businessAcc = new Account(Name = 'Test Business', RecordTypeId = businessRtId);
        insert businessAcc;
        // Project + Phase + Milestone
        Project__c proj = new Project__c(Name = 'Jupiter');
        insert proj;

        Phase__c phase = new Phase__c(Name = 'Phase 1', Project__c = proj.Id);
        insert phase;

        Milestone__c milestone = new Milestone__c(
            Type__c = 'Progress Based',
            Phase__c = phase.Id,
            Milestone_Due_Date__c = System.today().addDays(45),
            Project__c = proj.Id,
            Name = 'QAJupMilestoneTest1'
        );
        insert milestone;

        // Unit
        Unit__c unit = new Unit__c(
            Name = 'Unit A',
            Phase__c = phase.Id,
            PlotNo__c = '101',
            UnitClassification__c = 'Villa',
            Type__c = 'G+1',
            Number_of_Bedrooms__c = '1'
        );
        insert unit;

        // Sales Order
        SalesOrder__c so = new SalesOrder__c(
            CustomerAccount__c = acc.Id,
            Status__c = 'Completed',
            TotalAmount__c = 50000,
            Unit__c = unit.Id
            
        );
        insert so;

        // Installments
        SalesOrderInstallments__c soi1 = new SalesOrderInstallments__c(
            SalesOrder__c = so.Id,
            MilestoneNumber__c = 1,
            PaymentStatus__c = 'Paid',
            InstallmentAmount__c = 10000,
            Milestone_Installment__c  = milestone.Id,
            MilestoneDate__c = System.today()
        );
        insert soi1;

        SalesOrderInstallments__c soi2 = new SalesOrderInstallments__c(
            SalesOrder__c = so.Id,
            MilestoneNumber__c = 2,
            PaymentStatus__c = 'Not Paid',
            InstallmentAmount__c = 10000,
            MilestoneDate__c = System.today().addMonths(-1).addDays(-1),
            ExtensionDate__c = System.today().addDays(-10)
        );
        insert soi2;

        SalesOrderInstallments__c soi3 = new SalesOrderInstallments__c(
            SalesOrder__c = so.Id,
            MilestoneNumber__c = 3,
            PaymentStatus__c = 'Not Paid',
            InstallmentAmount__c = 10000,
            MilestoneDate__c = System.today().addMonths(2).addDays(-1)
        );
        insert soi3;
        
so.Status__c = 'Completed';
update so;  
        
   List<EmailTemplate> templates = new List<EmailTemplate>{
            new EmailTemplate(
                Name = ServiceConstants.CEMAIL_CASE_CLOSED,
                DeveloperName = 'CEMAIL_CASE_CLOSED',
                TemplateType = 'custom',
                FolderId = UserInfo.getUserId(),
                Subject = 'Case Closed',
                HtmlValue = '<html>Case Closed {SurveyLink__c}</html>'
            ),
            new EmailTemplate(
                Name = ServiceConstants.CEMAIL_DUPLICATE_CASE,
                DeveloperName = 'CEMAIL_DUPLICATE_CASE',
                TemplateType = 'custom',
                FolderId = UserInfo.getUserId(),
                Subject = 'Duplicate Closed',
                HtmlValue = '<html>Case Closed {SurveyLink__c}</html>'
            )
                
            //  other templates similarly
        };
       // insert templates;

        
    }

    @isTest
    static void testCreateDefaultSR() {
        // Get Sales Order
        SalesOrder__c so = [SELECT Id, Opportunity__c,Name,CustomerAccount__c, Unit__c FROM SalesOrder__c LIMIT 1];
        
        // Overdue installments mapping
        Map<Id, Set<String>> overdueMap = new Map<Id, Set<String>>();
        overdueMap.put(so.Id, new Set<String>{'SOI2'});

        Test.startTest();
        DefaultSRContrroler.createDefaultSRForSalesOrders(
            new List<SalesOrder__c>{so},
            'Overdue Test Reason',
            overdueMap
        );
        Test.stopTest();

        // Verify SR created
        List<ServiceRequest__c> srList = [
            SELECT Id, Name__c, Status__c, SR_Creation_Reason__c, Overdue_Installments__c
            FROM ServiceRequest__c
            WHERE SalesOrder__c = :so.Id
        ];
        System.assert(!srList.isEmpty(), 'Default SR should be created');
        System.assertEquals('New', srList[0].Status__c);
        System.assertEquals('Overdue Test Reason', srList[0].SR_Creation_Reason__c);
    }

    @isTest
    static void testSendDefaultNoticeEmail() {
        // Create SR linked to Sales Order
        SalesOrder__c so = [SELECT Id,Opportunity__c,Name, CustomerAccount__c, Unit__c FROM SalesOrder__c LIMIT 1];
        
        ServiceRequest__c sr = new ServiceRequest__c(
            Name__c = 'Test Default SR',
            Status__c = 'New',
            SalesOrder__c = so.Id,
            AccountId__c = so.CustomerAccount__c,
            UnitId__c = so.Unit__c,
            SR_Creation_Reason__c = Label.SRSalesOrderInstOverdue, // matches logic in controller
            RecordTypeId = Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType, 'Default_SR')
        );
        insert sr;

        Test.startTest();
        String result = DefaultSRContrroler.sendDefaultNoticeEmail(sr.Id, null);
        Test.stopTest();

        System.debug('Email send result: ' + result);
        System.assert(result == 'EMAIL_SENT' || result == 'NO_ELIGIBLE_CONTACT_FOUND' || result == 'TEMPLATE_NOT_FOUND');
    }

    @isTest
    static void testUpdateOutstandingAmount() {
        SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];
        List<SalesOrderInstallments__c> installments = [
            SELECT Id, SalesOrder__c, InstallmentAmount__c
            FROM SalesOrderInstallments__c
            WHERE SalesOrder__c = :so.Id
        ];

        Test.startTest();
        DefaultSRContrroler.updateOutstandingAmountForSalesOrders(new Set<Id>{so.Id}, installments);
        Test.stopTest();
    }
     @isTest
    static void testAppendUniqueNames() {
        // First create SR with one overdue installment
        SalesOrder__c so = [SELECT Id, Opportunity__c,Name,CustomerAccount__c, Unit__c FROM SalesOrder__c LIMIT 1];
        Map<Id, Set<String>> overdueMap = new Map<Id, Set<String>>();
        overdueMap.put(so.Id, new Set<String>{'SOI2'});

        DefaultSRContrroler.createDefaultSRForSalesOrders(
            new List<SalesOrder__c>{so},
            'Append Test',
            overdueMap
        );

        // Call again with new overdue installment → should append
        overdueMap.put(so.Id, new Set<String>{'SOI3'});
        DefaultSRContrroler.createDefaultSRForSalesOrders(
            new List<SalesOrder__c>{so},
            'Append Test Again',
            overdueMap
        );

        ServiceRequest__c sr = [
            SELECT Overdue_Installments__c 
            FROM ServiceRequest__c 
            WHERE SalesOrder__c = :so.Id LIMIT 1
        ];
        System.assert(sr.Overdue_Installments__c.contains('SOI2'));
        System.assert(sr.Overdue_Installments__c.contains('SOI3'));
    }

   
@isTest
static void testGetEmailsForAccount() {
    // Person Account → PersonEmail should be picked
    Account acc = [SELECT Id, PersonContactId, PersonEmail FROM Account WHERE PersonEmail != null LIMIT 1];
    ServiceRequest__c sr = new ServiceRequest__c(
        Name__c = 'Email Person SR',
        Status__c = 'New',
        AccountId__c = acc.Id,
        SR_Creation_Reason__c = 'Email Test',
        RecordTypeId = Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType, 'Default_SR')
    );
    insert sr;

    // Business Account → Contact email should be picked
    Account bizAcc = [SELECT Id FROM Account WHERE PersonEmail = null LIMIT 1];
    ServiceRequest__c srBiz = new ServiceRequest__c(
        Name__c = 'Email Biz SR',
        Status__c = 'New',
        AccountId__c = bizAcc.Id,
        SR_Creation_Reason__c = 'Email Test',
        RecordTypeId = Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType, 'Default_SR')
    );
    insert srBiz;

    // Create a dummy user for runAs
    Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
    User u = new User(
        Alias = 'templt',
        Email = 'templt@example.com',
        EmailEncodingKey = 'UTF-8',
        LastName = 'Temp',
        LanguageLocaleKey = 'en_US',
        LocaleSidKey = 'en_US',
        ProfileId = p.Id,
        TimeZoneSidKey = 'America/Los_Angeles',
        UserName = 'templt' + DateTime.now().getTime() + '@example.com'
    );
    insert u;

    Id templateId;
    System.runAs(u) {
        EmailTemplate tmp = new EmailTemplate(
            Name = ServiceConstants.CEMAIL_CASE_CLOSED,
            DeveloperName = 'CEMAIL_CASE_CLOSED',
            TemplateType = 'custom',
            FolderId = u.Id, // personal folder
            Subject = 'Case Closed',
            HtmlValue = '<html>Case Closed {SurveyLink__c}</html>'
        );
        insert tmp;
        templateId = tmp.Id;
    }

    Test.startTest();
    Messaging.SingleEmailMessage mail = DefaultSRContrroler.buildTemplateEmail(
        acc.PersonContactId,
        sr.Id,
        acc.PersonEmail,
        templateId
    );
    DefaultSRContrroler.sendDefaultNoticeEmail(srBiz.Id, null);
    Test.stopTest();

    System.assertEquals(templateId, mail.getTemplateId());
}

    @isTest
    static void testBuildTemplateEmail_noTemplate() {
        // Force path where no template found → returns null
        SalesOrder__c so = [SELECT Id, CustomerAccount__c, Unit__c FROM SalesOrder__c LIMIT 1];
        ServiceRequest__c sr = new ServiceRequest__c(
            Name__c = 'Test No Template',
            Status__c = 'New',
            SalesOrder__c = so.Id,
            AccountId__c = so.CustomerAccount__c,
            UnitId__c = so.Unit__c,
            SR_Creation_Reason__c = 'Email Test',
            RecordTypeId = Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType, 'Default_SR')
        );
        insert sr;

        Test.startTest();
        String result = DefaultSRContrroler.sendDefaultNoticeEmail(sr.Id, 'InvalidTemplateName');
        Test.stopTest();

        System.assertEquals('TEMPLATE_NOT_FOUND', result);
    }

    
   
  
}