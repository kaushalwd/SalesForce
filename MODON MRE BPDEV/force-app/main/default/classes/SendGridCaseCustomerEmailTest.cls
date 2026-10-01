/**
 * @description       : 
 * @author            : Krishna Chaitanya
 * @group             : 
 * @last modified on  : 05-30-2025
 * @last modified by  : Krishna Chaitanya
**/
@IsTest
private class SendGridCaseCustomerEmailTest {

    @IsTest
    static void testAllScenariosInSingleMethod() {
        // Create active admin user
        User admin = createAdminUser();
        
        // Run setup operations as admin
        System.runAs(admin) {
            createEmailTemplates();
            createBannerDocument();
        }

        // Create test data outside runAs to avoid mixed context
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;
        
        Contact testContact = new Contact(
            FirstName = 'Test', LastName = 'Contact',
            Email = 'test@example.com', AccountId = testAccount.Id
        );
        insert testContact;
        
        List<Case> testCases = createTestCases(testAccount.Id);
        updateClosedCase(testCases[0]);

        // Executing test scenarios
        executeAllTestScenarios1(testCases);
        //executeAllTestScenarios2(testCases);
    }

    private static User createAdminUser() {
        Profile adminProfile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        return new User(
            Alias = 'admin',
            Email = 'admin.user@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Admin',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = adminProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'admin.user@test.com',
            IsActive = true
        );
    }

    private static void createEmailTemplates() {
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
        insert templates;
    }

    private static void createBannerDocument() {
        Document doc = new Document(
            Name = 'TestBanner',
            DeveloperName = 'TestBanner',
            FolderId = UserInfo.getUserId(),
            Body = Blob.valueOf('Test Content'),
            ContentType = 'image/png'
        );
        insert doc;
    }

    private static List<Case> createTestCases(Id accountId) {
        List<Case> cases = new List<Case>{
            new Case(
                Subject = 'Test Case 1 - Closed',
                Status = 'New',
                AccountId = accountId,
                Customer_Email__c = 'test1@example.com',
                Description = 'This is The Case description'
            )
            //  other cases similarly
        };
        insert cases;
        return cases;
    }

    private static void updateClosedCase(Case caseToClose) {
        caseToClose.Status = 'Closed';
        caseToClose.Resolution_Comments__c = 'Test comments';
        caseToClose.SurveyLink__c = 'https://test.survey/1';
        update caseToClose;
    }

    private static void executeAllTestScenarios1(List<Case> testCases) {        
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new SendGridMock());
        //  other scenario calls
        SendGridCaseCustomerEmail.executeEmailSending(
            new List<Id>{testCases[0].Id}, 
            ServiceConstants.CEMAIL_DEPARTMENT_TRANSFERED, 
            'https://test.survey/1'
        );
        Test.stopTest();
    }
    
    /*private static void executeAllTestScenarios2(List<Case> testCases) {
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new SendGridMock());
        
        // Execute all email scenarios
        SendGridCaseCustomerEmail.executeEmailSending(
            new List<Id>{testCases[0].Id}, 
            ServiceConstants.CEMAIL_CASE_CLOSED, 
            'https://test.survey/1' 
        );
        Test.stopTest();
    }*/

    private class SendGridMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(202);
            res.setBody('{"message":"success"}');
            return res;
        }
    }

}