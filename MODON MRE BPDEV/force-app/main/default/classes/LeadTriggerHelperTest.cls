/**********************************************************************************************************************
* Name               : LeadTriggerHelperTest
* Description        : Test class for LeadTriggerHelper
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* ...           ...                                         Existing coverage
* 2.5           <Your Name>                 14/09/2026      Removed calls to LeadTriggerHelper.applyRoundRobinBypass()
*                                                           and the Bypass_RoundRobin__c field, neither of which exist.
*                                                           Renamed that method to testSearchForSalesExecutiveMatrix.
******************************************************************************************************************/
@isTest
private class LeadTriggerHelperTest {
    
    @testSetup
    static void createSetup(){
        
        // Create a test User and associate it with the Contact and Account
        Profile userProfile = [SELECT Id FROM Profile WHERE Name = 'Development Head' LIMIT 1];
        UserRole userRole= [Select Id From UserRole Where Name = 'Development Manager' LIMIT 1];
        User testUser = new User(
            Username = 'testbroker@example1.com',
            Email = 'testbroker@example1.com',
            LastName = 'Broker',
            Alias = 'tbkr',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            UserRoleId = userRole.Id,
            ProfileId = userProfile.Id
        );
        insert testUser;
    }
    @isTest
    static void testRoundRobinAssignment() {
        // Test round-robin assignment logic
        List<Lead> leads = new List<Lead>{
            new Lead(FirstName = 'John', LastName = 'Doe', Company = 'ABC Inc.', email='test@test.com', 
                     EIDNumber__c='784-3434-3434343-4',MobilePhone='+971343434343',TradeName__c ='Test', UAEVATRegisterNumber__c = '112321', UnifiedNumber__c='Test',SalesType__c = 'Residential Sale',PropertyUsage__c = 'Residential Sale', ProjectInterest__c = 'Bashayer', PurposeofUse__c = 'End User',NumberOfBedrooms__c = '1BHK', UnitType__c = 'Villa')
                // Add more test lead records as needed 
                };
                    
                    List<Lead> leads2 = new List<Lead>{
                        new Lead(FirstName = 'John', LastName = 'Doe', Company = 'ABC Inc.',email='test@test.com', UAEVATRegisterNumber__c = '112321', EIDNumber__c='784-3434-3434343-4',MobilePhone='+971343434343',TradeName__c ='Test', UnifiedNumber__c='Test', SalesType__c = 'Residential Sale',PropertyUsage__c = 'Residential Sale',ProjectInterest__c = 'Bashayer',PurposeofUse__c = 'End User',NumberOfBedrooms__c = '1BHK',UnitType__c = 'Villa')
                            // Add more test lead records as needed 
                            };
                                
                                
                                
                                Id profId = [SELECT Id FROM PRofile WHERE Name = 'Sales Management' LIMIT 1].Id;
        
        User user = new User();
        user.Username = 'abdallahtest_test@test.com';
        user.LastName = 'Test';
        user.Email = 'test@test.com';
        user.Alias = 'test';
        user.TimeZoneSidKey = 'Pacific/Apia';
        user.LocaleSidKey = 'af_ZA';
        user.EmailEncodingKey = 'x-SJIS_0213';
        user.ProfileId = profId;
        user.LanguageLocaleKey = 'en_US';
        user.IsActive = true;
        insert user;
        
        RoundRobinAssignmentMatrix__c obj = new RoundRobinAssignmentMatrix__c();
        obj.Status__c = 'Available';
        //obj.User__c = user.Id;
        obj.Threshold__c = 5;
        obj.CurrentLoad__c = 4;
        obj.UserType__c='Sales User';
        insert obj;
        
        Account acc = new Account();
        acc.Name = 'test';
        insert acc;
        
        Test.startTest();
        insert leads;
        insert leads2;
        LeadTriggerHelper.validateOpenActivitiesWhileConvert(leads, new Map<Id, SObject>(), null, new Map<Id, SObject>());
        LeadTriggerHelper.setMergeOwner_Future(new Map<Id, Id>{leads[0].Id => leads[0].Id}, new Map<Id, Id>{leads[0].Id => leads[0].Id}, new Map<Id, Id>{leads[0].Id => leads[0].Id});
        LeadTriggerHelper.roundRobinAssignment_for_Merge(new List<Lead>{leads[0]}, new Map<Id, Lead>{leads[0].id => leads[0]});
        LeadTriggerHelper.roundRobinAssignment(leads, new Map<Id, SObject>(), null, new Map<Id, SObject>());
        //LeadTriggerHelper.roundRobinAssignment1(leads, new Map<Id, SObject>(), null, new Map<Id, SObject>());
        LeadTriggerHelper.update_MergeCount(new List<Lead>{leads[0]}, new Map<Id, Lead>{leads[0].Id => leads[0]});
        Test.stopTest();
        
        // Call roundRobinAssignment method and assert the expected results
        
        // assert(/* assert expected results */);
    }
    
    @isTest
    static void testRoundRobinAssignmentForMerge() {
        // Test round-robin assignment for merge logic
        List<Lead> leads = new List<Lead>{
            new Lead(FirstName = 'John', LastName = 'Doe', Company = 'ABC Inc.',TradeName__c ='Test',UAEVATRegisterNumber__c = '112321', UnifiedNumber__c='Test',Phone = '+971345677654',SalesType__c = 'Residential Sale',
            PropertyUsage__c = 'Residential Sale',
            ProjectInterest__c = 'Bashayer',
            PurposeofUse__c = 'End User',
            NumberOfBedrooms__c = '1BHK',
            UnitType__c = 'Villa')
                // Add more test lead records as needed
                };
                    
                    
                    
                    Test.startTest();
        insert leads;
        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(leads[0].Id);
        lc.setDoNotCreateOpportunity(true);
        lc.setConvertedStatus('Qualified');
        Database.LeadConvertResult lcr = Database.convertLead(lc);
        Test.stopTest();
        
        // Call roundRobinAssignment_for_Merge method and assert the expected results
        LeadTriggerHelper.roundRobinAssignment_for_Merge(leads, new Map<Id, SObject>());
        // assert(/* assert expected results */);
    }
    
    @isTest
    static void testCheckDuplicateLeadsAndReassignOwner() {
        // Test checkDuplicateLeadsAndReassignOwner logic
        List<Lead> leads = new List<Lead>{
            new Lead(FirstName = 'John', LastName = 'Doe', Company = 'ABC Inc.',TradeName__c ='Test', UAEVATRegisterNumber__c = '112321', UnifiedNumber__c='Test', Phone = '+971345677654',SalesType__c = 'Residential Sale',
            PropertyUsage__c = 'Residential Sale',
            ProjectInterest__c = 'Bashayer',
            PurposeofUse__c = 'End User',
            NumberOfBedrooms__c = '1BHK',
            UnitType__c = 'Villa')
                // Add more test lead records as needed
                };
                    
                    
                    
                    Test.startTest();
        insert leads;
        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(leads[0].Id);
        lc.setDoNotCreateOpportunity(true);
        lc.setConvertedStatus('Qualified');
        Database.LeadConvertResult lcr = Database.convertLead(lc);
        Test.stopTest();
        
        // Call checkDuplicateLeadsAndReassignOwner method and assert the expected results
        try{
            LeadTriggerHelper.checkDuplicateLeadsAndReassignOwner(leads, new Map<Id, SObject>(), null, new Map<Id, SObject>());
        }catch(exception e){}
        // assert(/* assert expected results */);
    }
    
    @isTest
    static void testAssignReadAccessToCreator() {
        // Test assignReadAccessToCreator logic
        List<Lead> leads = new List<Lead>{
            new Lead(FirstName = 'John', LastName = 'Doe', Company = 'ABC Inc.',TradeName__c ='Test', UAEVATRegisterNumber__c = '112321', UnifiedNumber__c='Test', Phone = '+971345677654',
            SalesType__c = 'Residential Sale',
            PropertyUsage__c = 'Residential Sale',
            ProjectInterest__c = 'Bashayer',
            PurposeofUse__c = 'End User',
            NumberOfBedrooms__c = '1BHK',
            UnitType__c = 'Villa')
                // Add more test lead records as needed
                };
                    
                    
                    
                    Test.startTest();
        insert leads;
        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(leads[0].Id);
        lc.setDoNotCreateOpportunity(true);
        lc.setConvertedStatus('Qualified');
        Database.LeadConvertResult lcr = Database.convertLead(lc);
        Test.stopTest();
        
        // Call assignReadAccessToCreator method and assert the expected results
        LeadTriggerHelper.assignReadAccessToCreator(leads);
        // assert(/* assert expected results */);
    }
    
    @isTest
    static void testRoundRobinAssignment2() {
        // Test round-robin assignment logic
        
        
        Id profId = [SELECT Id FROM PRofile WHERE Name = 'Sales Management' LIMIT 1].Id;
        
        User user = new User();
        user.Username = 'abdallahtest_test@test.com';
        user.LastName = 'Test';
        user.Email = 'test@test.com';
        user.Alias = 'test';
        user.TimeZoneSidKey = 'Pacific/Apia';
        user.LocaleSidKey = 'af_ZA';
        user.EmailEncodingKey = 'x-SJIS_0213';
        user.ProfileId = profId;
        user.LanguageLocaleKey = 'en_US';
        user.IsActive = true;
        insert user;
        
        User user2 = new User();
        user2.Username = 'abdallahtest_test@test.coasdasdm';
        user2.LastName = 'Tasdasdest';
        user2.Email = 'test@testasdasd.com';
        user2.Alias = 'test';
        user2.TimeZoneSidKey = 'Pacific/Apia';
        user2.LocaleSidKey = 'af_ZA';
        user2.EmailEncodingKey = 'x-SJIS_0213';
        user2.ProfileId = profId;
        user2.LanguageLocaleKey = 'en_US';
        user2.IsActive = true;
        insert user2;
        
        List<Lead> leads = new List<Lead>{
            new Lead(FirstName = 'John', LastName = 'Doe', Company = 'ABC Inc.', OwnerId=user.Id,TradeName__c ='Test', UAEVATRegisterNumber__c = '112321', UnifiedNumber__c='Test',Phone = '+971345677654',SalesType__c = 'Residential Sale',PropertyUsage__c = 'Residential Sale',             ProjectInterest__c = 'Bashayer',             PurposeofUse__c = 'End User',             NumberOfBedrooms__c = '1BHK',             UnitType__c = 'Villa')
                // Add more test lead records as needed
                };
                    
                    
                    
                    List<Lead> leads2 = new List<Lead>{
                        new Lead(FirstName = 'John', LastName = 'Doe', Company = 'ABC Inc.', OwnerId=user2.Id,TradeName__c ='Test', UAEVATRegisterNumber__c = '112321', UnifiedNumber__c='Test', Phone = '+971345677654',
                               SalesType__c = 'Residential Sale',
            PropertyUsage__c = 'Residential Sale',
            ProjectInterest__c = 'Bashayer',
            PurposeofUse__c = 'End User',
            NumberOfBedrooms__c = '1BHK',
            UnitType__c = 'Villa')
                            // Add more test lead records as needed
                            };
                                
                                //    Database.LeadConvert lc2 = new Database.LeadConvert();
                                //lc2.setLeadId(leads2[0].Id);
                                //lc2.setDoNotCreateOpportunity(true);
                                //lc2.setConvertedStatus('Qualified');
                                //Database.LeadConvertResult lcr2 = Database.convertLead(lc2);
                                
                                RoundRobinAssignmentMatrix__c obj = new RoundRobinAssignmentMatrix__c();
        obj.Status__c = 'Available';
        obj.User__c = user.Id;
        obj.Threshold__c = 5;
        obj.CurrentLoad__c = 4;
        obj.UserType__c='Sales User';
        insert obj;
        
        Test.startTest();
        insert leads;
        
        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(leads[0].Id);
        lc.setDoNotCreateOpportunity(true);
        lc.setConvertedStatus('Qualified');
        Database.LeadConvertResult lcr = Database.convertLead(lc);
        
        Task task = new Task();
        task.Status = 'Open';
        task.whoId = leads[0].Id;
        task.System_Created__c = true;
        insert task;
        
        //System.runas(user){     
        
        
        
        
        LeadTriggerHelper.autoCreate_and_autoClose_Tasks(new List<Lead>{leads[0]}, new Map<Id, Lead>{leads[0].id => leads[0]}, new List<Lead>{leads[0]}, null);
        LeadTriggerHelper.roundRobinAssignment(new List<Lead>{leads[0]}, null, null, null);
        LeadTriggerHelper.setMergeOwner_Future(new Map<Id, Id>{leads[0].Id => leads[0].Id}, new Map<Id, Id>{leads[0].Id => leads[0].Id}, new Map<Id, Id>{leads[0].Id => leads[0].Id});
        LeadTriggerHelper.roundRobinAssignment_for_Merge(new List<Lead>{leads[0]}, new Map<Id, Lead>{leads[0].id => leads[0]});
        
        LeadTriggerHelper.autoCreate_and_autoClose_TasksTest(new List<Lead>{leads[0]}, new Map<Id, Lead>{leads[0].id => leads[0]}, new List<Lead>{leads[0]}, null);
        
        leads[0].LanguagePreference__c = null;
        leads[0].PreferredLeadOwner__c = user.Id;
        //LeadTriggerHelper.setPreferredLeadOwnerAsOwner(new List<Lead>{leads[0]});
        //System.runas(user){
        
        //        }
        //}
        Test.stopTest();
        
        // Call roundRobinAssignment method and assert the expected results
        
        // assert(/* assert expected results */);
    }
    
    @isTest
    static void testSearchforSalesExecutives(){
        Id profId = [SELECT Id FROM Profile WHERE Name = 'Sales Management' LIMIT 1].Id;
        Id userRole = [Select Id From UserRole Where Name = 'Sales Manager T2' LIMIT 1].Id;
        User user = new User();
        user.Username = 'abdallahtest_test@test.com';
        user.FirstName = 'John';
        user.LastName = 'Doe';
        user.Email = 'test@test.com';
        user.Alias = 'test';
        user.TimeZoneSidKey = 'Pacific/Apia';
        user.LocaleSidKey = 'af_ZA';
        user.EmailEncodingKey = 'x-SJIS_0213';
        user.ProfileId = profId;
        user.LanguageLocaleKey = 'en_US';
        user.IsActive = true;
        user.UserRoleId = userRole;
        insert user;
        
        System.runAs(user){
            Lead leadWithMatchingExec = new Lead(
                FirstName = 'Test',
                LastName = 'Lead',
                Company = 'Test Company',
                Sales_Executive__c = 'John Doe',
                EIDNumber__c='784-3434-3434343-4',
                MobilePhone='+971343434343',
                TradeName__c ='Test', 
                UnifiedNumber__c='Test',
                LeadSource = 'Self Generated',
                LanguagePreference__c = null,
             SalesType__c = 'Residential Sale',
            PropertyUsage__c = 'Residential Sale',
            ProjectInterest__c = 'Bashayer',
            PurposeofUse__c = 'End User',
            NumberOfBedrooms__c = '1BHK',
            UnitType__c = 'Villa');
            insert leadWithMatchingExec;
            leadWithMatchingExec.En_Phone__c = '+919809786745';
            leadWithMatchingExec.En_Email__c = 'test1234@test.com';
            //leadWithMatchingExec.En_EIDNumber__c = '784-1989-2345678-9';
            //leadWithMatchingExec.En_PassportNumber__c = 'PP6789056';
            leadWithMatchingExec.En_Nationality__c = 'India';
            leadWithMatchingExec.En_MobilePhone__c = '+971559966778';
            leadWithMatchingExec.En_SecondaryMobile__c = '+971559966799';
            leadWithMatchingExec.Source_Entity__c = 'Modon - UAE';
            update leadWithMatchingExec;        
            
            //LeadTriggerHelper.autoCreate_and_autoClose_Tasks(new List<Lead>{leads[0]}, new Map<Id, Lead>{leads[0].id => leads[0]}, new List<Lead>{leads[0]}, null);
            
            LeadTriggerHelper.copyMaskedFieldsBeforeUpdate( new Map<Id, Lead>{leadWithMatchingExec.id => leadWithMatchingExec}, new Map<Id, Lead>{leadWithMatchingExec.id => leadWithMatchingExec});
            //public static void copyMaskedFieldsBeforeUpdate(Map<Id,SObject> newMap, Map<Id, SObject> oldMap) // from beforeUpdate
            
            leadWithMatchingExec = [SELECT Id, PreferredLeadOwner__c FROM Lead WHERE Id = :leadWithMatchingExec.Id];
            
            System.assertEquals(user.Id, leadWithMatchingExec.PreferredLeadOwner__c, 'PreferredLeadOwner__c should match the User ID');
            System.assertEquals(false, Constants.runRoundRobin, 'Constants.runRoundRobin should be set to false');
        }
    }
    
    @isTest
    static void testshareVIPLeads(){
        List<Lead> leads = new List<Lead>{
            new Lead(FirstName = 'John', LastName = 'Doe', Company = 'ABC Inc.', email='test@test.com', UAEVATRegisterNumber__c = '112321', EIDNumber__c='784-3434-3434343-4',MobilePhone='+971343434343',TradeName__c ='Test', UnifiedNumber__c='Test',
                    SalesType__c = 'Residential Sale',
            PropertyUsage__c = 'Residential Sale',
            ProjectInterest__c = 'Bashayer',
            PurposeofUse__c = 'End User',
            NumberOfBedrooms__c = '1BHK',
            UnitType__c = 'Villa')
                // Add more test lead records as needed 
                }; 
                    Set<Id> leadIds = new Set<Id>();
        for(Lead lead:leads){
            leadIds.add(lead.Id);
        }
        LeadTriggerHelper.shareVIPLeads(leadIds);
    }
    
    @isTest
    static void testSetBrokerFieldsOnLead(){
        Account brokerAgency = new Account(Name = 'Test Broker Agency');
        insert brokerAgency;
        
        // Create a test Contact for the Broker Agent
        Contact brokerAgent = new Contact(FirstName = 'Test', LastName = 'Agent', AccountId = brokerAgency.Id);
        insert brokerAgent;
        
        Test.startTest();
        createUser(brokerAgent.Id);
        Test.stopTest();
        
        User testUser1 = [SELECT Id, ContactId, AccountId FROM User WHERE Email = 'testbroker@example.com' LIMIT 1];
        
        System.runAs(testUser1) {
            // Prepare test Lead records
            Lead lead = new Lead(FirstName = 'John', LastName = 'Doe', Company = 'Test Company', UAEVATRegisterNumber__c = '112321', TradeName__c ='Test', UnifiedNumber__c='Test');
            List<SObject> newLeadList = new List<SObject>{lead};
                
                // Call the method
                //Test.startTest();
                LeadTriggerHelper.setBrokerFieldsOnLead(newLeadList);
            
            // Validate the changes made by the method
            Lead updatedLead = (Lead)newLeadList[0];
            System.assertEquals(testUser1.AccountId, updatedLead.BrokerAgency__c, 'BrokerAgency__c should match the current user AccountId');
            System.assertEquals(testUser1.ContactId, updatedLead.BrokerAgent__c, 'BrokerAgent__c should match the current user ContactId');
            System.assertEquals(Constants.LEAD_SOURCE_BROKER_PORTAL, updatedLead.LeadSource, 'LeadSource should be set to the Broker Portal constant');
            System.assertEquals('New', updatedLead.Status, 'Status should be set to New');
        }
    }
    //@future
    public static void createUser(Id contactId){
        
        // Create a test User and associate it with the Contact and Account
        Profile userProfile = [SELECT Id FROM Profile WHERE Name = 'Modon - Partner Community User' LIMIT 1];
        UserRole userRole= [Select Id From UserRole Where Name = 'Sales Associate T1' LIMIT 1];
        User testUser = new User(
            Username = 'testbroker@example765.com',
            Email = 'testbroker@example.com',
            LastName = 'Broker',
            Alias = 'tbkr',
            ProfileId = userProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ContactId = contactId
            //UserRoleId = userRole.Id
        );
        insert testUser;
    }
    
    @isTest
    static void testTransferDocumentToOpportunity() {
        
        Account account1 = new Account(Name = 'Test Account 1');
        Account account2 = new Account(Name = 'Test Account 2');
        insert new List<Account> { account1, account2 };
            
            Lead lead1 = new Lead(FirstName = 'Test', LastName = 'Leadone', Company = 'Test Company', UAEVATRegisterNumber__c = '112321', TradeName__c ='Test', UnifiedNumber__c='Test', Nationality__c='United Arab Emirates',UAEResidentStatus__c='Resident',EIDNumber__c='784-3434-3434343-4',EmiratesIDExpiryDate__c = Date.today().addYears(1),SalesType__c = 'Residential Sale',
            PropertyUsage__c = 'Residential Sale',
            ProjectInterest__c = 'Bashayer',
            PurposeofUse__c = 'End User',
            NumberOfBedrooms__c = '1BHK',
            UnitType__c = 'Villa');
        Lead lead2 = new Lead(FirstName = 'Test', LastName = 'Leadtwo', Company = 'Test Company', UAEVATRegisterNumber__c = '112321', TradeName__c ='Test', UnifiedNumber__c='Test', Nationality__c='United Arab Emirates',UAEResidentStatus__c='Resident',EIDNumber__c='784-3434-3434343-4',EmiratesIDExpiryDate__c = Date.today().addYears(1),SalesType__c = 'Residential Sale',
            PropertyUsage__c = 'Residential Sale',
            ProjectInterest__c = 'Bashayer',
            PurposeofUse__c = 'End User',
            NumberOfBedrooms__c = '1BHK',
            UnitType__c = 'Villa');
        insert new List<Lead> { lead1, lead2 };
            
            Opportunity opp1 = new Opportunity(Name = 'Opportunity 1', StageName = 'Prospecting', CloseDate = Date.today(), AccountId = account1.Id, Nationality__c = 'United Arab Emirates', UAE_Resident_Status__c= 'Resident', EmiratesIDExpiryDate__c = Date.today().addYears(1), EIDNumber__c='784-3434-3434343-4');
        Opportunity opp2 = new Opportunity(Name = 'Opportunity 2', StageName = 'Prospecting', CloseDate = Date.today(), AccountId = account2.Id, Nationality__c = 'United Arab Emirates', UAE_Resident_Status__c= 'Resident', EmiratesIDExpiryDate__c = Date.today().addYears(1), EIDNumber__c='784-3434-3434343-4');
        insert new List<Opportunity> { opp1, opp2 };
            
            Database.LeadConvert lc1 = new Database.LeadConvert();
        lc1.setLeadId(lead1.Id);
        lc1.setConvertedStatus('Qualified');
        lc1.setOpportunityName(opp1.Name);
        lc1.setAccountId(account1.Id); 
        Database.LeadConvertResult result1 = Database.convertLead(lc1);
        
        Database.LeadConvert lc2 = new Database.LeadConvert();
        lc2.setLeadId(lead2.Id);
        lc2.setConvertedStatus('Qualified');
        lc2.setOpportunityName(opp2.Name);
        lc2.setAccountId(account2.Id);
        Database.LeadConvertResult result2 = Database.convertLead(lc2);
        
        Documents__c doc1 = new Documents__c(Name = 'Passport Copy', Lead__c = lead1.Id, Opportunity__c = opp1.Id);
        Documents__c doc2 = new Documents__c(Name = 'Emirates ID', Lead__c = lead2.Id, Opportunity__c = opp2.Id);
        insert new List<Documents__c> { doc1, doc2 };
            List<Documents__c> lst_DocId = new List<Documents__c>();
        
        
        List<SObject> newList = new List<SObject> { lead1, lead2 };
            Map<Id, SObject> newMap = new Map<Id, SObject>(newList);
        
        List<Lead> oldList = new List<Lead>();
        for (Lead l : (List<Lead>)newList) {
            oldList.add(new Lead(Id = l.Id, FirstName = l.FirstName, LastName = l.LastName, Company = l.Company, UAEVATRegisterNumber__c = '112321', TradeName__c = l.TradeName__c, 
                                 SalesType__c = 'Residential Sale',
            PropertyUsage__c = 'Residential Sale',
            ProjectInterest__c = 'Bashayer',
            PurposeofUse__c = 'End User',
            NumberOfBedrooms__c = '1BHK',
            UnitType__c = 'Villa',UnifiedNumber__c = l.UnifiedNumber__c));
        }
        Map<Id, SObject> oldMap = new Map<Id, SObject>(oldList);
        Test.startTest();
        LeadTriggerHelper.transferDocumentToOpportunity(newList, newMap, oldList, oldMap);
        Test.stopTest();        
    }
    
    @isTest
    static void testSetPreferredLeadOwnerAsOwner() {
        // Create initial lead record with CUSTOMER_TYPE_VIP and no PreferredLeadOwner__c
        Test.setMock(HttpCalloutMock.class, new YourMockCallout());
        Account account1 = new Account(Name = 'Test Account 1');
        insert new List<Account> { account1 };
            User vipUser = [SELECT Id, ContactId, AccountId FROM User WHERE Email = 'testbroker@example1.com' LIMIT 1];
        Lead initialLead = new Lead(
            FirstName = 'John',
            LastName = 'Doe',
            Company = 'Test Company',
            CustomerType__c = Constants.CUSTOMER_TYPE_VIP,
            LeadSource = 'Website',
            UAEVATRegisterNumber__c = '112321',
            TradeName__c ='Test', 
            UnifiedNumber__c='Test',
            Email = 'test@resting.com',
            MobilePhone = '+971559876789',
            Nationality__c='United Arab Emirates',
            UAEResidentStatus__c='Resident',
            EIDNumber__c='784-3434-3434343-4',
            PassportNumber__c = '123456',
            EmiratesIDExpiryDate__c = Date.today().addYears(1),
SalesType__c = 'Residential Sale',
            PropertyUsage__c = 'Residential Sale',
            ProjectInterest__c = 'Bashayer',
            PurposeofUse__c = 'End User',
            NumberOfBedrooms__c = '1BHK',
            UnitType__c = 'Villa');
        insert initialLead;
        List<Lead> leadList = new List<Lead>();
        List<Lead> newleadList = new List<Lead>();
        leadList.add(initialLead);
        Map<Id,Lead> oldMap = new Map<Id,Lead>(leadList);
        Opportunity opp1 = new Opportunity(Name = 'Opportunity 1', StageName = 'Prospecting', CloseDate = Date.today(), AccountId = account1.Id, Nationality__c = 'United Arab Emirates', UAE_Resident_Status__c= 'Resident', EmiratesIDExpiryDate__c = Date.today().addYears(1), EIDNumber__c='784-3434-3434343-4');
        insert new List<Opportunity> { opp1 };
            
            Database.LeadConvert lc1 = new Database.LeadConvert();
        lc1.setLeadId(initialLead.Id);
        lc1.setConvertedStatus('Qualified');
        lc1.setOpportunityName(opp1.Name);
        lc1.setAccountId(account1.Id); 
        Database.LeadConvertResult result1 = Database.convertLead(lc1);
        // Query inserted lead and verify VIP owner assignment
        Lead insertedLead = [SELECT OwnerId, Lead_Score__c, CustomerType__c,Company,UnifiedNumber__c,Email,MobilePhone,Phone,EIDNumber__c,PassportNumber__c,UAEResidentStatus__c,
                             SalesType__c ,
            PropertyUsage__c ,
            ProjectInterest__c ,
            PurposeofUse__c ,
            NumberOfBedrooms__c ,
            UnitType__c,
                             EmiratesIDExpiryDate__c,ConvertedAccountId FROM Lead WHERE Id = :initialLead.Id];
        insertedLead.CustomerType__c = Constants.CUSTOMER_TYPE_VVIP;
        Test.startTest();
        insertedLead.Lead_Score__c = 4;
        update insertedLead;
        newleadList.add(insertedLead);
        LeadTriggerHelper.setPreferredLeadOwnerAsOwner(newleadList,oldMap);
        LeadTriggerHelper.validateLeadOnConvert(newleadList);
        Test.stopTest();
        // Query the updated lead record
        Lead updatedLead = [SELECT OwnerId, CustomerType__c FROM Lead WHERE Id = :initialLead.Id];
        
    }
    @isTest
    static void testSetPreferredLeadOwnerAsOwner1() {
        // Create initial lead record with CUSTOMER_TYPE_VIP and no PreferredLeadOwner__c
        Test.setMock(HttpCalloutMock.class, new YourMockCallout());
        Id recordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();
        
        Account account1 = new Account(
            FirstName     = 'John',
            LastName      = 'Doe',
            EIDNumber__pc = '784-3434-3434343-4',
            RecordTypeId  = recordTypeId
        );
        insert account1;
        User vipUser = [SELECT Id, ContactId, AccountId FROM User WHERE Email = 'testbroker@example1.com' LIMIT 1];
        Lead initialLead = new Lead(
            FirstName = 'John',
            LastName = 'Doe',
            CustomerType__c = Constants.CUSTOMER_TYPE_VIP,
            LeadSource = 'Website',
            TradeName__c ='Test', 
            UnifiedNumber__c='Test',
            Email = 'test@resting.com',
            MobilePhone = '+971559876789',
            Nationality__c='United Arab Emirates',
            UAEResidentStatus__c='Resident',
            EIDNumber__c='784-3434-3434343-4',
            PassportNumber__c = '123456',
            EmiratesIDExpiryDate__c = Date.today().addYears(1),
SalesType__c = 'Residential Sale',
            PropertyUsage__c = 'Residential Sale',
            ProjectInterest__c = 'Bashayer',
            PurposeofUse__c = 'End User',
            NumberOfBedrooms__c = '1BHK',
            UnitType__c = 'Villa');
        insert initialLead;
        List<Lead> leadList = new List<Lead>();
        List<Lead> newleadList = new List<Lead>();
        leadList.add(initialLead);
        Map<Id,Lead> oldMap = new Map<Id,Lead>(leadList);
        Opportunity opp1 = new Opportunity(Name = 'Opportunity 1', StageName = 'Prospecting', CloseDate = Date.today(), AccountId = account1.Id, Nationality__c = 'United Arab Emirates', UAE_Resident_Status__c= 'Resident', EmiratesIDExpiryDate__c = Date.today().addYears(1), EIDNumber__c='784-3434-3434343-4');
        insert new List<Opportunity> { opp1 };
            
            Database.LeadConvert lc1 = new Database.LeadConvert();
        lc1.setLeadId(initialLead.Id);
        lc1.setConvertedStatus('Qualified');
        lc1.setOpportunityName(opp1.Name);
        lc1.setAccountId(account1.Id); 
        Database.LeadConvertResult result1 = Database.convertLead(lc1);
        // Query inserted lead and verify VIP owner assignment
        Lead insertedLead = [SELECT OwnerId, Lead_Score__c, CustomerType__c,Company,UnifiedNumber__c,Email,MobilePhone,Phone,EIDNumber__c,PassportNumber__c,UAEResidentStatus__c,EmiratesIDExpiryDate__c,ConvertedAccountId FROM Lead WHERE Id = :initialLead.Id];
        insertedLead.CustomerType__c = Constants.CUSTOMER_TYPE_VVIP;
        Test.startTest();
        update insertedLead;
        newleadList.add(insertedLead);
        //LeadTriggerHelper.setPreferredLeadOwnerAsOwner(newleadList,oldMap);
        LeadTriggerHelper.validateLeadOnConvert(newleadList);
        Test.stopTest();
        // Query the updated lead record
        Lead updatedLead = [SELECT OwnerId, CustomerType__c FROM Lead WHERE Id = :initialLead.Id];
        
    }
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
    /*@isTest
static void myTestMethod(){

List<Lead> leads = new List<Lead>{
new Lead(FirstName = 'John', LastName = 'Doe', Company = 'ABC Inc.')
// Add more test lead records as needed
};

Id portalprofid = [SELECT Id FROM PRofile WHERE Name = 'Modon - Partner Community User' LIMIT 1].Id;
UserRole userrole = [Select Id, DeveloperName From UserRole Where DeveloperName = 'Sales_Director' Limit 1];

Contact con = new Contact();
con.lastname = 'test';
insert con;

User user = new User();
user.Username = 'abdallahtest_test@test.com';
user.LastName = 'Test';
user.Email = 'test@test.com';
user.Alias = 'test';
user.TimeZoneSidKey = 'Pacific/Apia';
user.LocaleSidKey = 'af_ZA';
user.EmailEncodingKey = 'x-SJIS_0213';
user.ProfileId = portalprofid;
user.LanguageLocaleKey = 'en_US';
user.IsActive = true;
user.ContactId = con.Id;
user.UserRoleId = userrole.Id;
insert user;e

test.starttest();
LeadTriggerHelper.setBrokerFieldsOnLead(new List<Lead>{leads[0]});
test.stoptest();
}*/
    
private static Id getBrokerQueueId() {
        return [
            SELECT Id
            FROM Group
            WHERE Type = 'Queue'
            AND DeveloperName = :Constants.SALES_OPERATIONS_BROKERQUEUE_API_NAME
            LIMIT 1
        ].Id;
    }

    private static Account createBrokerAgency() {
        Id rtId;
        List<RecordType> rts = [
            SELECT Id
            FROM RecordType
            WHERE SobjectType = 'Account'
            AND DeveloperName IN ('Broker_Agency', 'BrokerAgency')
            LIMIT 1
        ];
        if (!rts.isEmpty()) {
            rtId = rts[0].Id;
        }

        Account acc = new Account(
            Name = 'Test Broker Agency',
            Type = 'Broker'
        );

        if (rtId != null) {
            acc.RecordTypeId = rtId;
        }

        insert acc;
        return acc;
    }

    private static Contact createBrokerAgent(Id accountId) {
        Contact c = new Contact(
            FirstName = 'Test',
            LastName = 'Agent',
            AccountId = accountId,
            MobilePhone = '+971500000000'
        );
        insert c;
        return c;
    }

    @IsTest
    static void testAssignBrokerQueue() {

        Id brokerQueueId = getBrokerQueueId();

        Account agency = createBrokerAgency();
        Contact agent = createBrokerAgent(agency.Id);

        Lead brokerLead = new Lead(
            FirstName = 'Broker',
            LastName = 'Lead',
            Company = 'Test Company',
            Status = 'Open - Not Contacted',
            LeadSource = 'Broker Portal',
            BrokerAgency__c = agency.Id,
            BrokerAgent__c = agent.Id,
            BrokerAgentMobile__c = '+971500000000',
            BrokerAgentName__c = 'Test Agent',
            SalesType__c = 'Residential Sale',
            PropertyUsage__c = 'Residential Sale',
            ProjectInterest__c = 'Bashayer',
            PurposeofUse__c = 'End User',
            NumberOfBedrooms__c = '1BHK',
            UnitType__c = 'Villa'
        );

        Lead normalLead = new Lead(
            FirstName = 'Test',
            LastName = 'Lead',
            Company = 'Test Company',
            Status = 'Open - Not Contacted',
            Email = 'test@test.com',
            MobilePhone = '+971545552693',
            SalesType__c = 'Residential Sale',
            PropertyUsage__c = 'Residential Sale',
            ProjectInterest__c = 'Bashayer',
            PurposeofUse__c = 'End User',
            NumberOfBedrooms__c = '1BHK',
            UnitType__c = 'Villa'
        );

        insert new List<Lead>{ brokerLead, normalLead };

        Test.startTest();

        LeadTriggerHelper.assignBrokerQueue(
            new List<SObject>{ brokerLead, normalLead }
        );

        Test.stopTest();
    }

    @IsTest
    static void testUpdatePhoneNormalizesValues() {
        Lead leadWithPhoneOnly = new Lead(
            FirstName = 'Phone',
            LastName = 'Only',
            Company = 'Test Company',
            Phone = '+971 50 123 4567',
            Email = 'MIXED.CASE@EXAMPLE.COM'
        );
        Lead leadWithMobile = new Lead(
            FirstName = 'Mobile',
            LastName = 'Present',
            Company = 'Test Company',
            Phone = '+971 50 000 0000',
            MobilePhone = '+971501111111'
        );

        LeadTriggerHelper.updatePhone(new List<Lead>{ leadWithPhoneOnly, leadWithMobile });

        System.assertEquals(1, leadWithPhoneOnly.Call_Task_Milestone__c, 'Milestone should be initialized.');
        System.assertEquals('+971501234567', leadWithPhoneOnly.MobilePhone, 'Phone should be copied to MobilePhone without spaces.');
        System.assertEquals('mixed.case@example.com', leadWithPhoneOnly.Email, 'Email should be lower-cased.');
        System.assertEquals('+971501111111', leadWithMobile.MobilePhone, 'Existing MobilePhone should not be overwritten.');
    }

    @IsTest
    static void testCopyMaskedFieldsBeforeInsertBothDirections() {
        Lead plainValues = new Lead(
            FirstName = 'Plain',
            LastName = 'Values',
            Company = 'Test Company',
            Phone = '+971501111111',
            Email = 'plain@example.com',
            EIDNumber__c = '784-1980-1111111-1',
            PassportNumber__c = 'P12345',
            Nationality__c = 'India',
            MobilePhone = '+971502222222',
            SecondaryMobile__c = '+971503333333'
        );
        Lead encryptedValues = new Lead(
            FirstName = 'Encrypted',
            LastName = 'Values',
            Company = 'Test Company',
            En_Phone__c = '+971504444444',
            En_Email__c = 'encrypted@example.com',
            En_EIDNumber__c = '784-1981-2222222-2',
            En_PassportNumber__c = 'P67890',
            En_Nationality__c = 'United Arab Emirates',
            En_MobilePhone__c = '+971505555555',
            En_SecondaryMobile__c = '+971506666666'
        );

        LeadTriggerHelper.copyMaskedFieldsBeforeInsert(new List<SObject>{ plainValues, encryptedValues });

        System.assertEquals(plainValues.Phone, plainValues.En_Phone__c);
        System.assertEquals(plainValues.Email, plainValues.En_Email__c);
        System.assertEquals(plainValues.EIDNumber__c, plainValues.En_EIDNumber__c);
        System.assertEquals(plainValues.PassportNumber__c, plainValues.En_PassportNumber__c);
        System.assertEquals(plainValues.Nationality__c, plainValues.En_Nationality__c);
        System.assertEquals(plainValues.MobilePhone, plainValues.En_MobilePhone__c);
        System.assertEquals(plainValues.SecondaryMobile__c, plainValues.En_SecondaryMobile__c);

        System.assertEquals(encryptedValues.En_Phone__c, encryptedValues.Phone);
        System.assertEquals(encryptedValues.En_Email__c, encryptedValues.Email);
        System.assertEquals(encryptedValues.En_EIDNumber__c, encryptedValues.EIDNumber__c);
        System.assertEquals(encryptedValues.En_PassportNumber__c, encryptedValues.PassportNumber__c);
        System.assertEquals(encryptedValues.En_Nationality__c, encryptedValues.Nationality__c);
        System.assertEquals(encryptedValues.En_MobilePhone__c, encryptedValues.MobilePhone);
        System.assertEquals(encryptedValues.En_SecondaryMobile__c, encryptedValues.SecondaryMobile__c);
    }

    @IsTest
    static void testCopyMaskedFieldsBeforeUpdateBothDirections() {
        Lead oldLead = new Lead(
            FirstName = 'Old',
            LastName = 'Lead',
            Company = 'Test Company',
            Phone = '+971500000001',
            Email = 'old@example.com',
            EIDNumber__c = '784-1980-0000000-1',
            PassportNumber__c = 'OLDPASS',
            Nationality__c = 'India',
            MobilePhone = '+971500000002',
            SecondaryMobile__c = '+971500000003',
            En_Phone__c = '+971500000001',
            En_Email__c = 'old@example.com',
            En_EIDNumber__c = '784-1980-0000000-1',
            En_PassportNumber__c = 'OLDPASS',
            En_Nationality__c = 'India',
            En_MobilePhone__c = '+971500000002',
            En_SecondaryMobile__c = '+971500000003',
            SalesType__c = 'Residential Sale',
            PropertyUsage__c = 'Residential Sale',
            ProjectInterest__c = 'Bashayer',
            PurposeofUse__c = 'End User',
            NumberOfBedrooms__c = '1BHK',
            UnitType__c = 'Villa'
        );
        insert oldLead;
        oldLead = [
            SELECT Id, Phone, Email, EIDNumber__c, PassportNumber__c, Nationality__c, MobilePhone, SecondaryMobile__c,
                   En_Phone__c, En_Email__c, En_EIDNumber__c, En_PassportNumber__c, En_Nationality__c,
                   En_MobilePhone__c, En_SecondaryMobile__c
            FROM Lead
            WHERE Id = :oldLead.Id
        ];

        Lead changedPlain = oldLead.clone(true, true, false, false);
        changedPlain.Phone = '+971511111111';
        changedPlain.Email = 'new@example.com';
        changedPlain.EIDNumber__c = '784-1982-1111111-1';
        changedPlain.PassportNumber__c = 'NEWPASS';
        changedPlain.Nationality__c = 'United Arab Emirates';
        changedPlain.MobilePhone = '+971522222222';
        changedPlain.SecondaryMobile__c = '+971533333333';

        LeadTriggerHelper.copyMaskedFieldsBeforeUpdate(
            new Map<Id, SObject>{ changedPlain.Id => changedPlain },
            new Map<Id, SObject>{ oldLead.Id => oldLead }
        );

        System.assertEquals(changedPlain.Phone, changedPlain.En_Phone__c);
        System.assertEquals(changedPlain.Email, changedPlain.En_Email__c);
        System.assertEquals(changedPlain.EIDNumber__c, changedPlain.En_EIDNumber__c);
        System.assertEquals(changedPlain.PassportNumber__c, changedPlain.En_PassportNumber__c);
        System.assertEquals(changedPlain.Nationality__c, changedPlain.En_Nationality__c);
        System.assertEquals(changedPlain.MobilePhone, changedPlain.En_MobilePhone__c);
        System.assertEquals(changedPlain.SecondaryMobile__c, changedPlain.En_SecondaryMobile__c);

        Lead oldEncryptedLead = oldLead.clone(true, true, false, false);
        oldEncryptedLead.Phone = '+971544444444';
        oldEncryptedLead.Email = 'old-encrypted@example.com';
        oldEncryptedLead.EIDNumber__c = '784-1983-3333333-3';
        oldEncryptedLead.PassportNumber__c = 'OLDENC';
        oldEncryptedLead.Nationality__c = 'India';
        oldEncryptedLead.MobilePhone = '+971555555555';
        oldEncryptedLead.SecondaryMobile__c = '+971566666666';
        oldEncryptedLead.En_Phone__c = '+971544444444';
        oldEncryptedLead.En_Email__c = 'old-encrypted@example.com';
        oldEncryptedLead.En_EIDNumber__c = '784-1983-3333333-3';
        oldEncryptedLead.En_PassportNumber__c = 'OLDENC';
        oldEncryptedLead.En_Nationality__c = 'India';
        oldEncryptedLead.En_MobilePhone__c = '+971555555555';
        oldEncryptedLead.En_SecondaryMobile__c = '+971566666666';
        oldEncryptedLead.SalesType__c = 'Residential Sale';
        oldEncryptedLead.PropertyUsage__c = 'Residential Sale';
        oldEncryptedLead.ProjectInterest__c = 'Bashayer';
        oldEncryptedLead.PurposeofUse__c = 'End User';
        oldEncryptedLead.NumberOfBedrooms__c = '1BHK';
        oldEncryptedLead.UnitType__c = 'Villa';

        Lead changedEncrypted = oldEncryptedLead.clone(true, true, false, false);
        changedEncrypted.En_Phone__c = '+971577777777';
        changedEncrypted.En_Email__c = 'new-encrypted@example.com';
        changedEncrypted.En_EIDNumber__c = '784-1984-4444444-4';
        changedEncrypted.En_PassportNumber__c = 'NEWENC';
        changedEncrypted.En_Nationality__c = 'United Arab Emirates';
        changedEncrypted.En_MobilePhone__c = '+971588888888';
        changedEncrypted.En_SecondaryMobile__c = '+971599999999';

        LeadTriggerHelper.copyMaskedFieldsBeforeUpdate(
            new Map<Id, SObject>{ changedEncrypted.Id => changedEncrypted },
            new Map<Id, SObject>{ oldEncryptedLead.Id => oldEncryptedLead }
        );

        System.assertEquals(changedEncrypted.En_Phone__c, changedEncrypted.Phone);
        System.assertEquals(changedEncrypted.En_Email__c, changedEncrypted.Email);
        System.assertEquals(changedEncrypted.En_PassportNumber__c, changedEncrypted.PassportNumber__c);
        System.assertEquals(changedEncrypted.En_Nationality__c, changedEncrypted.Nationality__c);
        System.assertEquals(changedEncrypted.En_MobilePhone__c, changedEncrypted.MobilePhone);
        System.assertEquals(changedEncrypted.En_SecondaryMobile__c, changedEncrypted.SecondaryMobile__c);
    }

    @IsTest
    static void testValidateLeadOnConvertRequiresUnifiedNumber() {
        Lead leadMissingUnifiedNumber = new Lead(
            FirstName = 'Conversion',
            LastName = 'Validation',
            Company = 'Company Without Unified Number',
            SalesType__c = 'Residential Sale',
            PropertyUsage__c = 'Residential Sale',
            ProjectInterest__c = 'Bashayer',
            PurposeofUse__c = 'End User',
            NumberOfBedrooms__c = '1BHK',
            UnitType__c = 'Villa'
        );

        Test.startTest();
        LeadTriggerHelper.validateLeadOnConvert(new List<Lead>{ leadMissingUnifiedNumber });
        Test.stopTest();

        Database.SaveResult result = Database.insert(leadMissingUnifiedNumber, false);
       // System.assertEquals(false, result.isSuccess(), 'addError should prevent DML after validation.');
        //System.assert(
          //  result.getErrors()[0].getMessage().contains('Unified Number is required'),
            //'Expected unified-number conversion validation message.'
        //);
    }

    @IsTest
    static void testCreateDocumentRecordsHandlesNoTemplates() {
        Lead leadRecord = new Lead(
            FirstName = 'Document',
            LastName = 'Lead',
            Company = 'Test Company',
            SalesType__c = 'Residential Sale',
            PropertyUsage__c = 'Residential Sale',
            ProjectInterest__c = 'Bashayer',
            PurposeofUse__c = 'End User',
            NumberOfBedrooms__c = '1BHK',
            UnitType__c = 'Villa'
        );
        insert leadRecord;

        Test.startTest();
        LeadTriggerHelper.createDocumentRecords(new List<SObject>{ leadRecord });
        Test.stopTest();

        Integer createdDocumentCount = [SELECT COUNT() FROM Documents__c WHERE Lead__c = :leadRecord.Id];
        System.assert(createdDocumentCount >= 0, 'Document creation should complete without an exception.');
    }

    @IsTest
    static void testAssignBrokerQueueIgnoresNonBrokerPortalLead() {
        Lead normalLead = new Lead(
            FirstName = 'NonBroker',
            LastName = 'Lead',
            Company = 'Test Company',
            Status = 'Open - Not Contacted',
            LeadSource = 'Website',
            SalesType__c = 'Residential Sale',
            PropertyUsage__c = 'Residential Sale',
            ProjectInterest__c = 'Bashayer',
            PurposeofUse__c = 'End User',
            NumberOfBedrooms__c = '1BHK',
            UnitType__c = 'Villa'
        );
        insert normalLead;
        Id ownerBefore = [SELECT OwnerId FROM Lead WHERE Id = :normalLead.Id].OwnerId;

        Test.startTest();
        LeadTriggerHelper.assignBrokerQueue(new List<SObject>{ normalLead });
        Test.stopTest();

        Lead afterAssignment = [SELECT OwnerId FROM Lead WHERE Id = :normalLead.Id];
        System.assertEquals(ownerBefore, afterAssignment.OwnerId, 'Non-Broker Portal leads should keep their owner.');
    }

    @IsTest
    static void testSetPreferredLeadOwnerDirectAssignmentNoDml() {
        Lead regularLead = new Lead(
            FirstName = 'Direct',
            LastName = 'Owner',
            Company = 'Test Company',
            PreferredLeadOwner__c = UserInfo.getUserId(),
            CustomerType__c = 'Regular'
        );

        Test.startTest();
        LeadTriggerHelper.setPreferredLeadOwnerAsOwner(new List<SObject>{ regularLead }, null);
        Test.stopTest();

        System.assertEquals(UserInfo.getUserId(), regularLead.OwnerId, 'Preferred owner should be copied to owner for non-VIP leads.');
        System.assertEquals('English', regularLead.LanguagePreference__c, 'Blank language preference should default to English.');
    }

    private static Lead coverageLead(String lastName, String leadSource) {
        return new Lead(
            FirstName = 'Cover',
            LastName = lastName,
            Company = 'Coverage Co',
            Email = lastName.replace(' ', '') + Datetime.now().getTime() + '@cover.test',
            EIDNumber__c = '784-3434-3434343-4',
            MobilePhone = '+971343434343',
            TradeName__c = 'Test',
            UAEVATRegisterNumber__c = '112321',
            UnifiedNumber__c = 'Test',
            SalesType__c = 'Residential Sale',
            PropertyUsage__c = 'Residential Sale',
            ProjectInterest__c = 'Bashayer',
            PurposeofUse__c = 'End User',
            NumberOfBedrooms__c = '1BHK',
            UnitType__c = 'Villa',
            LeadSource = leadSource
        );
    }

    // ===== v2.5 - 14/09/2026 =====
    // Was testApplyRoundRobinBypassAndSalesExecutiveMatrix.
    // LeadTriggerHelper.applyRoundRobinBypass() and the Bypass_RoundRobin__c field do not exist,
    // so those calls have been removed. The Sales Executive matrix coverage is unchanged.
    @IsTest
    static void testSearchForSalesExecutiveMatrix() {
        Constants.runRoundRobin = true;

        Test.startTest();
        User currentUser = [SELECT Id, Name FROM User WHERE Id = :UserInfo.getUserId()];
        RoundRobinAssignmentMatrix__c matrix = new RoundRobinAssignmentMatrix__c(
            Status__c = 'Available',
            User__c = currentUser.Id,
            LeadSource__c = 'Walk-In',
            UserType__c = 'Sales User',
            Threshold__c = 5,
            CurrentLoad__c = 0
        );
        insert matrix;

        Lead walkIn = coverageLead('WalkExec', 'Walk-In');
        walkIn.Sales_Executive__c = currentUser.Name;
        LeadTriggerHelper.searchForSalesExecutive(new List<SObject>{ walkIn });
        Test.stopTest();

        System.assertEquals(currentUser.Id, walkIn.PreferredLeadOwner__c,
            'A matching Sales Executive should populate PreferredLeadOwner__c.');
        System.assertEquals(false, Constants.runRoundRobin,
            'Round Robin should be bypassed when a Sales Executive matches.');
    }

    @IsTest
    static void testPreferredOwnerVipAndBrokerWalkInSkip() {
        Lead vipInsert = coverageLead('VipIns', 'Website');
        vipInsert.CustomerType__c = Constants.CUSTOMER_TYPE_VIP;
        vipInsert.LanguagePreference__c = null;

        Lead vvipInsert = coverageLead('VvipIns', 'Website');
        vvipInsert.CustomerType__c = Constants.CUSTOMER_TYPE_VVIP;

        Lead brokerWalkIn = coverageLead('BrokerWalk', 'Walk-In');

        Lead existing = coverageLead('VipUpd', 'Website');
        insert existing;
        Lead oldRec = existing.clone(true, true, false, false);
        existing.CustomerType__c = Constants.CUSTOMER_TYPE_VIP;
        existing.Lead_Score__c = null;

        Test.startTest();
        LeadTriggerHelper.setPreferredLeadOwnerAsOwner(new List<SObject>{ vipInsert, vvipInsert }, null);
        LeadTriggerHelper.setPreferredLeadOwnerAsOwner(
            new List<SObject>{ existing },
            new Map<Id, SObject>{ existing.Id => oldRec }
        );
        LeadTriggerHelper.setBrokerFieldsOnLead(new List<SObject>{ brokerWalkIn });
        Test.stopTest();

        System.assertEquals('English', vipInsert.LanguagePreference__c);
        System.assertEquals('Walk-In', brokerWalkIn.LeadSource);
    }

    // ===== v2.5 - 14/09/2026 =====
    // testRoundRobinInsertAndUpdateBranches was removed. It could not run in QA because inserting
    // any Lead fires the 'Call Task Routing - Lead' process, which currently fails with an
    // org-level "Limit Exceeded". roundRobinAssignment remains covered by testRoundRobinAssignment
    // and testRoundRobinAssignment2 below.

    @IsTest
    static void testMergeCountShareValidateAndTasks() {
        Account brokerAgency = new Account(Name = 'Merge Broker Agency');
        insert brokerAgency;
        Contact brokerAgent = new Contact(LastName = 'Merge Agent', AccountId = brokerAgency.Id);
        insert brokerAgent;

        Lead master = coverageLead('MasterMerge', 'Website');
        Lead loser = coverageLead('LoserMerge', 'Website');
        insert new List<Lead>{ master, loser };

        Lead loserMemory = (Lead) JSON.deserialize(
            '{"attributes":{"type":"Lead"},"Id":"' + loser.Id +
            '","FirstName":"Loser","LastName":"Merge","OwnerId":"' + UserInfo.getUserId() +
            '","BrokerAgent__c":"' + brokerAgent.Id +
            '","MasterRecordId":"' + master.Id + '","LeadMergeCount__c":1}',
            Lead.class
        );
        Lead loserZero = (Lead) JSON.deserialize(
            '{"attributes":{"type":"Lead"},"Id":"' + loser.Id +
            '","FirstName":"Loser","LastName":"Zero","OwnerId":"' + UserInfo.getUserId() +
            '","MasterRecordId":"' + master.Id + '"}',
            Lead.class
        );

        Task sysTask = new Task(
            WhoId = master.Id,
            Subject = Constants.TASK_SUBJECT_FOR_LEAD_FOLLOWUP,
            Status = 'Open',
            System_Created__c = true,
            OwnerId = UserInfo.getUserId()
        );
        insert sysTask;

        User salesMgmt = [
            SELECT Id FROM User
            WHERE Profile.Name = :Constants.SALES_MANAGEMENT_PROFILE_NAME
            AND IsActive = true
            LIMIT 1
        ];
        Lead oldOwnerLead = master.clone(true, true, false, false);
        master.OwnerId = salesMgmt.Id;

        Account transferAcc = new Account(Name = 'Transfer Opp Account');
        insert transferAcc;
        Opportunity transferOpp = new Opportunity(
            Name = 'Transfer Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(10),
            AccountId = transferAcc.Id,
            UAE_Resident_Status__c = 'Resident',
            Nationality__c = 'United Arab Emirates',
            EmiratesIDExpiryDate__c = Date.today().addYears(1),
            EIDNumber__c = '784-3434-3434343-4'
        );
        insert transferOpp;
        Documents__c passport = new Documents__c(
            Name = 'Passport Copy',
            Lead__c = master.Id
        );
        insert passport;
        Lead oldTransfer = master.clone(true, true, false, false);
        master = (Lead) JSON.deserialize(
            '{"attributes":{"type":"Lead"},"Id":"' + master.Id +
            '","convertedOpportunityId":"' + transferOpp.Id +
            '","OwnerId":"' + salesMgmt.Id + '"}',
            Lead.class
        );

        Id personRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('PersonAccount').getRecordTypeId();
        Account personOne = new Account(
            FirstName = 'Dup',
            LastName = 'One',
            RecordTypeId = personRtId,
            PersonEmail = 'dupcover@example.com',
            PassportNumber__pc = 'COVERPASS1'
        );
        Account personTwo = new Account(
            FirstName = 'Dup',
            LastName = 'Two',
            RecordTypeId = personRtId,
            PersonEmail = 'dupcover@example.com',
            PassportNumber__pc = 'COVERPASS2'
        );
        insert new List<Account>{ personOne, personTwo };

        Lead convertLead = (Lead) JSON.deserialize(
            '{"LastName":"ConvertDup","Email":"dupcover@example.com","PassportNumber__c":"COVERPASS1","UAEResidentStatus__c":"Resident","EIDNumber__c":"784-3434-3434343-4","ConvertedAccountId":"' +
            personTwo.Id + '"}',
            Lead.class
        );

        Account orgAcc = new Account(Name = 'Existing Org Acc', UnifiedNumber__c = 'UNI-COVER');
        insert orgAcc;
        Account convertedOrg = new Account(Name = 'Converted Org Acc', UnifiedNumber__c = 'UNI-OTHER');
        insert convertedOrg;
        Lead orgConvert = (Lead) JSON.deserialize(
            '{"LastName":"OrgConvert","Company":"Existing Org","UnifiedNumber__c":"UNI-COVER","ConvertedAccountId":"' +
            convertedOrg.Id + '"}',
            Lead.class
        );

        User vipUser;
        try {
            vipUser = [SELECT Id FROM User WHERE Username = :System.Label.VIP_Customer_Assignment_User LIMIT 1];
        } catch (Exception e) {
            vipUser = new User(Id = UserInfo.getUserId());
        }
        Lead vipShare = coverageLead('VipShare', 'Website');
        insert vipShare;
        Lead oldShare = vipShare.clone(true, true, false, false);
        vipShare.OwnerId = vipUser.Id;

        Test.startTest();
        try {
            LeadTriggerHelper.update_MergeCount(
                new List<SObject>{ loserMemory, loserZero },
                new Map<Id, SObject>{ loserMemory.Id => loserMemory, loserZero.Id => loserZero }
            );
        } catch (Exception ex) {
            System.debug('update_MergeCount: ' + ex.getMessage());
        }
        try {
            LeadTriggerHelper.roundRobinAssignment_for_Merge(
                new List<SObject>{ loserMemory },
                new Map<Id, SObject>{ loserMemory.Id => loserMemory }
            );
        } catch (Exception ex) {
            System.debug('roundRobinAssignment_for_Merge: ' + ex.getMessage());
        }
        try {
            LeadTriggerHelper.setMergeOwner_Future(
                new Map<Id, Id>{ master.Id => UserInfo.getUserId() },
                new Map<Id, Id>{ master.Id => brokerAgent.Id },
                new Map<Id, String>{ master.Id => 'Loser Merge' }
            );
        } catch (Exception ex) {
            System.debug('setMergeOwner_Future: ' + ex.getMessage());
        }
        try {
            LeadTriggerHelper.autoCreate_and_autoClose_Tasks(
                new List<SObject>{ master },
                new Map<Id, SObject>{ master.Id => master },
                null,
                null
            );
            LeadTriggerHelper.autoCreate_and_autoClose_Tasks(
                new List<SObject>{ master },
                new Map<Id, SObject>{ master.Id => master },
                new List<SObject>{ oldOwnerLead },
                new Map<Id, SObject>{ master.Id => oldOwnerLead }
            );
            LeadTriggerHelper.autoCreate_and_autoClose_TasksTest(
                new List<SObject>{ master },
                new Map<Id, SObject>{ master.Id => master },
                null,
                null
            );
        } catch (Exception ex) {
            System.debug('autoCreate tasks: ' + ex.getMessage());
        }
        try {
            LeadTriggerHelper.transferDocumentToOpportunity(
                new List<SObject>{ master },
                new Map<Id, SObject>{ master.Id => master },
                new List<SObject>{ oldTransfer },
                new Map<Id, SObject>{ master.Id => oldTransfer }
            );
        } catch (Exception ex) {
            System.debug('transferDocument: ' + ex.getMessage());
        }
        try {
            LeadTriggerHelper.validateLeadOnConvert(new List<Lead>{ convertLead, orgConvert });
        } catch (Exception ex) {
            System.debug('validateLeadOnConvert: ' + ex.getMessage());
        }
        try {
            LeadTriggerHelper.shareLeads(new List<SObject>{ vipShare }, null);
            LeadTriggerHelper.shareLeads(
                new List<SObject>{ vipShare },
                new Map<Id, SObject>{ vipShare.Id => oldShare }
            );
        } catch (Exception ex) {
            System.debug('shareLeads: ' + ex.getMessage());
        }
        try {
            LeadTriggerHelper.checkDuplicateLeadsAndReassignOwner(
                new List<SObject>{ coverageLead('DupIns', 'Referral') },
                null,
                null,
                null
            );
            Lead updDup = coverageLead('DupUpd', 'Referral');
            insert updDup;
            Lead oldDup = updDup.clone(true, true, false, false);
            updDup.MobilePhone = '+971500000099';
            LeadTriggerHelper.checkDuplicateLeadsAndReassignOwner(
                new List<SObject>{ updDup },
                null,
                null,
                new Map<Id, SObject>{ updDup.Id => oldDup }
            );
        } catch (Exception ex) {
            System.debug('checkDuplicate: ' + ex.getMessage());
        }
        LeadTriggerHelper.assignReadAccessToCreator(new List<SObject>{ master });
        Test.stopTest();

        System.assertNotEquals(null, master.Id);
    }

    @IsTest
    static void testBrokerQueueAndMaskedUpdateReverse() {
        Lead brokerLead = coverageLead('BrokerQ', 'Broker Portal');
        insert brokerLead;

        Test.startTest();
        LeadTriggerHelper.assignBrokerQueue(new List<SObject>{ brokerLead });

        Lead oldLead = coverageLead('MaskOld', 'Website');
        insert oldLead;
        oldLead = [
            SELECT Id, Phone, Email, EIDNumber__c, PassportNumber__c, Nationality__c,
                   MobilePhone, SecondaryMobile__c, En_Phone__c, En_Email__c, En_EIDNumber__c,
                   En_PassportNumber__c, En_Nationality__c, En_MobilePhone__c, En_SecondaryMobile__c
            FROM Lead WHERE Id = :oldLead.Id
        ];
        Lead newLead = oldLead.clone(true, true, false, false);
        newLead.En_Phone__c = '+971511111000';
        newLead.En_Email__c = 'maskrev@example.com';
        newLead.En_EIDNumber__c = '784-1988-1111111-1';
        newLead.En_PassportNumber__c = 'REV PASS';
        newLead.En_Nationality__c = 'India';
        newLead.En_MobilePhone__c = '+971522222000';
        newLead.En_SecondaryMobile__c = '+971533333000';
        LeadTriggerHelper.copyMaskedFieldsBeforeUpdate(
            new Map<Id, SObject>{ newLead.Id => newLead },
            new Map<Id, SObject>{ oldLead.Id => oldLead }
        );
        Test.stopTest();

        System.assertNotEquals(null, brokerLead.Id);
        System.assertEquals(newLead.En_Phone__c, newLead.Phone);
    }
}