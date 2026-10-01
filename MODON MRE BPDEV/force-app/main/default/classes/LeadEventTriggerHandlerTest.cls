@isTest
public class LeadEventTriggerHandlerTest {
    
    @isTest
    static void testAfterInsert() {
        Lead obj_Lead = new Lead(FirstName = 'John', LastName = 'Doe', Company = 'ABC Inc.',TradeName__c ='Test', UnifiedNumber__c='Test');
        Id profId = [SELECT Id FROM PRofile WHERE Name = 'Sales Management' LIMIT 1].Id;
        
        User user = new User();
        user.Username = 'abdallahtest_test@test.com';
        user.LastName = 'Test';
        user.FirstName = 'Sales';
        user.Email = 'test@test.com';
        user.Alias = 'test';
        user.TimeZoneSidKey = 'Pacific/Apia';
        user.LocaleSidKey = 'af_ZA';
        user.EmailEncodingKey = 'x-SJIS_0213';
        user.ProfileId = profId;
        user.LanguageLocaleKey = 'en_US';
        user.IsActive = true;
        
        Test.startTest(); 
        insert obj_Lead;
        insert user;
        List<Lead_Event__c> leadevents = new List<Lead_Event__c>{
            new Lead_Event__c(ADDED_BY__c = 'Test', Broker_Email__c = 'Test@admin.com', 
                              Broker_Name__c = 'Test',Broker_Phone__c ='+97156602342', Broker_UnifiedNumber__c='CN-5026332', 
                              CampaignId__c='Test', Checkin_Status__c = 'NO', Checkin_Time__c = '2025-02-22T10:09:58Z', 
                              Email__c='test@admin.com', EventID__c='67b6c6ab3153a5a856f3b417', 
                              EventName__c='Final Demo Event', FirstName__c='Test', LastName__c='Test2', LeadID__c=obj_Lead.Id, 
                              Lead_Source__c='Walk-In', SalesAgentName__c = 'Sales Test')
            // Add more test lead records as needed
        };
       insert leadevents;    
       Test.stopTest();     
    }

    @isTest
    static void testAfterUpdate() {
        Lead obj_Lead = new Lead(FirstName = 'John', LastName = 'Doe', Company = 'ABC Inc.',TradeName__c ='Test', UnifiedNumber__c='Test');
        Id profId = [SELECT Id FROM PRofile WHERE Name = 'Sales Management' LIMIT 1].Id;
        
        User user = new User();
        user.Username = 'abdallahtest_test@test.com';
        user.LastName = 'Test';
        user.FirstName = 'Sales';
        user.Email = 'test@test.com';
        user.Alias = 'test';
        user.TimeZoneSidKey = 'Pacific/Apia';
        user.LocaleSidKey = 'af_ZA';
        user.EmailEncodingKey = 'x-SJIS_0213';
        user.ProfileId = profId;
        user.LanguageLocaleKey = 'en_US';
        user.IsActive = true;
        
        User user2 = new User();
        user2.Username = 'abdallahtest_test22@test.com';
        user2.LastName = 'Test22';
        user2.FirstName = 'Sales';
        user2.Email = 'test@test.com';
        user2.Alias = 'test';
        user2.TimeZoneSidKey = 'Pacific/Apia';
        user2.LocaleSidKey = 'af_ZA';
        user2.EmailEncodingKey = 'x-SJIS_0213';
        user2.ProfileId = profId;
        user2.LanguageLocaleKey = 'en_US';
        user2.IsActive = true;
        
        Test.startTest(); 
        insert obj_Lead;
        insert user;
        insert user2;
        
        Lead_Event__c obj_LeadEvent = new Lead_Event__c(ADDED_BY__c = 'Test', Broker_Email__c = 'Test@admin.com', 
                              							Broker_Name__c = 'Test',Broker_Phone__c ='+97156602342', Broker_UnifiedNumber__c='CN-5026332', 
                              							CampaignId__c='Test', Checkin_Status__c = 'NO', Checkin_Time__c = '2025-02-22T10:09:58Z', 
                              							Email__c='test@admin.com', EventID__c='67b6c6ab3153a5a856f3b417', 
                              							EventName__c='Final Demo Event', FirstName__c='Test', LastName__c='Test2', LeadID__c=obj_Lead.Id, 
                              							Lead_Source__c='BrokerPortal', SalesAgentName__c = 'Sales Test');
         
       insert obj_LeadEvent; 
       //obj_LeadEvent.SalesAgentName__c = 'Sales Test22'; 
       //update obj_LeadEvent; 
       Test.stopTest();
    }    

}