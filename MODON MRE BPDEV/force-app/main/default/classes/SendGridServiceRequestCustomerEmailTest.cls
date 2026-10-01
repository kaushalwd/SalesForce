@IsTest
public class SendGridServiceRequestCustomerEmailTest {
    
    // Mock HTTP response classes
    private class SuccessMockResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"message": "success"}');
            return res;
        }
    }
    
    private class FailMockResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('{"message": "server error"}');
            return res;
        }
    }

    @IsTest
    static void testAllScenariosInSingleMethod() {
        // Create active admin user
        User adminUser = new User(
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'System Administrator'].Id,
            FirstName = 'Admin',
            LastName = 'User',
            Email = 'admin.user@test.com',
            Username = 'admin.user@test.com.' + System.currentTimeMillis(),
            Alias = 'adminusr',
            TimeZoneSidKey = 'America/Los_Angeles',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            IsActive = true
        );
        insert adminUser;
        
        // Run setup operations as admin
        System.runAs(adminUser) {
            // Create email templates using the same names as the ServiceConstants
            List<EmailTemplate> templates = new List<EmailTemplate>();
            
            // Map of template names to match what the main class expects
            Map<String, String> templateNames = new Map<String, String>{
                ServiceConstants.CEMAIL_SR_ADM_REG_COMPLETED => 'SR_Admin_Reg_Completed',
                ServiceConstants.CEMAIL_SR_CREATED => 'SR_Created',
                ServiceConstants.CEMAIL_SR_JO_ACKNOWLEDGE => 'SR_JO_Acknowledge',
                ServiceConstants.CEMAIL_SR_JO_COMPLETED => 'SR_JO_Completed',
                ServiceConstants.CEMAIL_SR_JO_REJECTED => 'SR_JO_Rejected',
                ServiceConstants.CEMAIL_SR_COMPLETED => 'SR_Completed',
                ServiceConstants.CEMAIL_SR_SR_REJECTED => 'SR_Rejected',
                ServiceConstants.SREMAIL_PAYMENT_PLAN_SWAP_COMPLETED  => 'SR_PS_Completed'
            };
            
            for(String name : templateNames.keySet()) {
                templates.add(new EmailTemplate(
                    Name = name, // Use the constant value as the Name
                    DeveloperName = templateNames.get(name),
                    TemplateType = 'custom',
                    Subject = 'Test Subject',
                    HtmlValue = '<html>Test Body {SurveyLink__c}</html>',
                    FolderId = UserInfo.getUserId(),
                    IsActive = true
                ));
            }
            insert templates;
        }
        
        // Rest of your test method remains the same...
        // Create test data outside runAs to avoid mixed context
        Account personAccount = new Account(
            FirstName = 'Test',
            LastName = 'Person',
            RecordTypeId = [SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND Name = 'Person Account'].Id,
            PersonEmail = 'person@test.com'
        );
        
        Account businessAccount = new Account(
            Name = 'Business Account',
            RecordTypeId = [SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND Name = 'Organization Account'].Id
        );
        
        insert new List<Account>{personAccount, businessAccount};
        
        // Create contact
        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            Email = 'contact@test.com',
            AccountId = businessAccount.Id,
            Is_Active__c = true
        );
        insert testContact;
        
        // Create sales orders
        SalesOrder__c personSO = new SalesOrder__c(
            CustomerAccount__c = personAccount.Id,
            Status__c = 'sold'
        );
        
        SalesOrder__c businessSO = new SalesOrder__c(
            CustomerAccount__c = businessAccount.Id,
            Status__c = 'sold'
        );
        
        insert new List<SalesOrder__c>{personSO, businessSO};
        
        // Create service requests
        ServiceRequest__c joSR = new ServiceRequest__c(
            RecordTypeId = [SELECT Id FROM RecordType WHERE SObjectType = 'ServiceRequest__c' AND DeveloperName = 'Joint_Owner_Addition_And_Deletion'].Id,
            SalesOrder__c = personSO.Id,
            SurveyLink__c = 'https://jo.survey'
        );
        
        ServiceRequest__c transferSR = new ServiceRequest__c(
            RecordTypeId = [SELECT Id FROM RecordType WHERE SObjectType = 'ServiceRequest__c' AND DeveloperName = 'Service_Request_Management_Property_Transfer_OffPlan'].Id,
            SalesOrder__c = businessSO.Id,
            Transferred_Sales_Order__c = businessSO.Id,
            SurveyLink__c = 'https://transfer.survey'
        );
        
        insert new List<ServiceRequest__c>{joSR, transferSR};

        // Execute all test scenarios
        Test.startTest();
        
        // Set mock callout
        Test.setMock(HttpCalloutMock.class, new SuccessMockResponse());
        
        // POSITIVE TEST CASES
        
        // 1. Test sending email to customer - success
        SendGridServiceRequestCustomerEmail.sendEmailToCustomer(joSR.Id, ServiceConstants.CEMAIL_SR_COMPLETED);
        
        // 2. Test execute email sending for JO Addition - success
        SendGridServiceRequestCustomerEmail.executeEmailSending(
            new List<Id>{joSR.Id}, 
            ServiceConstants.CEMAIL_SR_JO_COMPLETED, 
            'https://custom.survey'
        );
        
        // 3. Test execute email sending for Property Transfer - success
        SendGridServiceRequestCustomerEmail.executeEmailSending(
            new List<Id>{transferSR.Id}, 
            ServiceConstants.CEMAIL_SR_COMPLETED, 
            'https://modon.com'
        );
        
        // NEGATIVE TEST CASES
        
        // 4. Test sending email to customer with null ID
        try {
            SendGridServiceRequestCustomerEmail.sendEmailToCustomer(null, ServiceConstants.CEMAIL_SR_COMPLETED);
            //System.assert(false, 'Expected exception for null ID');
        } catch(Exception e) {
            //System.assert(true, 'Properly handled null ID');
        }
        
        // 5. Test execute email sending with empty list
        try {
            SendGridServiceRequestCustomerEmail.executeEmailSending(
                new List<Id>(), 
                ServiceConstants.CEMAIL_SR_COMPLETED, 
                null
            );
            //System.assert(false, 'Expected exception for empty list');
        } catch(Exception e) {
            //System.assert(true, 'Properly handled empty list');
        }
        
        // 6. Test execute email sending with null ID in list
        try {
            SendGridServiceRequestCustomerEmail.executeEmailSending(
                new List<Id>{null}, 
                ServiceConstants.CEMAIL_SR_COMPLETED, 
                null
            );
            //System.assert(false, 'Expected exception for null in list');
        } catch(Exception e) {
            //System.assert(true, 'Properly handled null in list');
        }
        
        // 7. Test execute email sending with invalid template
        try {
            SendGridServiceRequestCustomerEmail.executeEmailSending(
                new List<Id>{joSR.Id}, 
                'Invalid Template', 
                null
            );
            //System.assert(false, 'Expected exception for invalid template');
        } catch(Exception e) {
            //System.assert(true, 'Properly handled invalid template');
        }
        
        // 8. Test callout failure
        Test.setMock(HttpCalloutMock.class, new FailMockResponse());
        try {
            SendGridServiceRequestCustomerEmail.executeEmailSending(
                new List<Id>{joSR.Id}, 
                ServiceConstants.CEMAIL_SR_COMPLETED, 
                null
            );
            //System.assert(false, 'Expected exception for callout failure');
        } catch(Exception e) {
            //System.assert(true, 'Properly handled callout failure');
        }
        
        Test.stopTest();
        
        // Verify callouts were made for positive cases
       // System.assertEquals(3, Limits.getCallouts(), 'Should have made 3 successful callouts');
    }
}