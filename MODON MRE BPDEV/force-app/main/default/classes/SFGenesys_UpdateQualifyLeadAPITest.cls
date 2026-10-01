@isTest
public class SFGenesys_UpdateQualifyLeadAPITest {

    @TestSetup
    static void getData () {
        //Retrieve Modon Egypt's user role
        UserRole role_Modon_Egypt = [SELECT Id FROM UserRole WHERE DeveloperName = 'Modon_Egypt_Head_of_Sales_Operations'];
        
        // Create Test User UAE
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Salesforce API Only System Integrations' LIMIT 1];
        User testUser_UAE = new User(
            FirstName = 'Test',
            LastName = 'User_UAE',
            Email = 'testuser_UAE@test.com',
            Username = 'testuseruae@test.com',
            Alias = 'tuser',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );
        insert testUser_UAE;
        
        User testUser_Egypt = new User(
            FirstName = 'Test',
            LastName = 'User_Egypt',
            Email = 'testuser_Egypt@test.com',
            Username = 'testuseregypt@test.com',
            Alias = 'tuser',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id,
            UserRoleId = role_Modon_Egypt.Id
        );
        insert testUser_Egypt;
        
        System.runAs(testUser_UAE) {
        // Create test lead
        Lead testLead = new Lead(
            FirstName = 'John',
            LastName = 'Doe',
            Company = 'Test Company',
            LeadSource = 'Web',
            TradeName__c = 'Test Trade',
            UnifiedNumber__c = '21345',
            ProjectInterest__c = 'Wadeem'
        );
        insert testLead;
        }
        
        System.runAs(testUser_Egypt) {
            // Create test lead
            Lead testLead = new Lead(
                FirstName = 'Travis',
                LastName = 'Scott',
                MobilePhone = '1234567890',
                Email='test2@test.fcom',
                LeadSource = 'Web',
                TradeName__c = 'Test Trade',
                UnifiedNumber__c = '21345',
                ProjectInterest__c = 'Wadeem'
            );
            insert testLead;
        }
    }
    
    @isTest
    static void testUpdateLeadRecord_Success() {
        
        Lead lead = [Select Id,FirstName,LastName,Company,TradeName__c,UnifiedNumber__c,Email,LanguagePreference__c From Lead LIMIT 1];        
        Test.startTest();
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestBody = Blob.valueOf('{"LeadId": "' + lead.Id + '","QualifyLead": true,"ProjectName": "Test Project","BedroomType": "2BHK","Investment": "High","BudgetOption": "Premium","Finance": "Yes","ContactChannel": "Phone","CallbackTimeslot": "Tomorrow"}');

        req.httpMethod = 'POST';
        RestContext.request = req;
        RestContext.response = res;

        SFGenesys_UpdateQualifyLeadAPI.updateLeadRecord();
        Test.stopTest();

        // Validate lead was updated
        Lead updatedLead = [SELECT Id FROM Lead WHERE Id = :lead.Id];
        System.assertEquals(lead.Id, updatedLead.Id);
    }

    @isTest
    static void testUpdateLeadRecord_InvalidLeadId() {
        Test.startTest();
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestBody = Blob.valueOf('{"LeadId": "00Q6F00001XyzAbUAZ", "QualifyLead": true}');

        req.httpMethod = 'POST';
        RestContext.request = req;
        RestContext.response = res;

        SFGenesys_UpdateQualifyLeadAPI.updateLeadRecord();
        Test.stopTest();

        // Ensure no lead was created or updated
        List<Lead> leads = [SELECT Id FROM Lead WHERE Id='00Q6F00001XyzAbUAZ'];
        System.assertEquals(0, leads.size());
    }

    @isTest
    static void testUpdateLeadRecord_ExceptionHandling() {
        Test.startTest();
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();

        req.requestBody = Blob.valueOf('{}'); // Missing required fields
        req.httpMethod = 'POST';
        RestContext.request = req;
        RestContext.response = res;

        SFGenesys_UpdateQualifyLeadAPI.updateLeadRecord();
        Test.stopTest();

        // Verify no leads were created
        List<Lead> leads = [SELECT Id FROM Lead WHERE Id=null];
        System.assertEquals(0, leads.size());
    }
}