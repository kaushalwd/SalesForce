@isTest
public class CloneOpportunityControllerTest {

    @testSetup
    static void setupData() {
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;

        Opportunity validOpportunity = new Opportunity(
            Name = 'Valid Opportunity',
            AccountId = testAccount.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(2)
        );
        insert validOpportunity;

        Opportunity invalidOpportunity = new Opportunity(
            Name = 'Invalid Opportunity',
            AccountId = testAccount.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(15)
        );
        insert invalidOpportunity;

        SalesOrder__c validSalesOrder = new SalesOrder__c(
            Opportunity__c = validOpportunity.Id,
            Status__c = 'SPA Delivered',
            CustomerAccount__c = testAccount.Id
        );
        insert validSalesOrder;

        SalesOrder__c invalidSalesOrder = new SalesOrder__c(
            Opportunity__c = invalidOpportunity.Id,
            Status__c = 'SPA Delivered',
            CustomerAccount__c = testAccount.Id
        );
        insert invalidSalesOrder;
        // Create a test user with access to the account
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Sales Management' LIMIT 1];
        User testUser = new User(
            Username = 'testuserrrer@example.com',
            Email = 'testuser@example.com',
            LastName = 'Modon',
            Alias = 'tuser',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            IsActive = true
        );
        insert testUser;
        
        // Reassign the Account owner to the test user
        testAccount.OwnerId = testUser.Id;
        update testAccount;
    }

    @isTest
    static void testGetRelatedOpportunities() {
        
        Account testAccount = [SELECT Id FROM Account LIMIT 1];
        List<Opportunity> opportunities = CloneOpportunityController.getRelatedOpportunities(testAccount.Id);
        CloneOpportunityController.CreateDocumentRecords(opportunities);
        System.assertNotEquals(0, opportunities.size(), 'There should be related opportunities.');
        System.assertEquals(2, opportunities.size(), 'There should be exactly 2 related opportunities.');
    }
    
    @isTest
    static void testCloneOpportunityWithValidSalesOrders() {

        User testUser = [Select Id FROM User Where Id =: UserInfo.getUserId() LIMIT 1];
        Account testAccount = [SELECT Id,Name FROM Account LIMIT 1];
        Opportunity testOpp = [SELECT Id FROM Opportunity LIMIT 1];
        SalesOrder__c salesOrder = [SELECT Id FROM SalesOrder__c LIMIT 1];
        //Id testUser = UserInfo.getUserId();
        AccountShare accountShare = new AccountShare();
        accountShare.AccountId = testAccount.Id;
        accountShare.UserOrGroupId = testUser.Id;
        accountShare.AccountAccessLevel = 'Edit';
        accountShare.OpportunityAccessLevel = 'Edit'; 
        accountShare.RowCause = Schema.AccountShare.RowCause.Manual;
        insert accountShare;
        DateTime dateTime1 = DateTime.newInstance(date.today().year(), date.today().month(), date.today().day());
        String formattedDate = dateTime1.format('ddMMyy');
        Test.startTest();
        
        // Run as the test user to validate the functionality
        System.runAs(testUser) {
            Id clonedOppId = CloneOpportunityController.cloneOpportunity(testAccount.Id);
            System.debug('clonedOppId: ' + clonedOppId);
            
            // Validate that the cloned Opportunity exists
            Opportunity clonedOpp = [SELECT Id, Name, StageName, Account.Name FROM Opportunity WHERE Id = :clonedOppId];
            System.assertNotEquals(null, clonedOpp, 'A new opportunity should have been created.');
            System.assertEquals(testAccount.Name+ '-'+ formattedDate, clonedOpp.Name, 'Cloned opportunity name should be account name.');
            System.assertEquals('Unit selection in progress', clonedOpp.StageName, 'StageName should be set to Unit Selection in Progress.');
        }
        
        Test.stopTest();
    }



    @isTest
    static void testCloneOpportunityWithNoValidSalesOrders() {
        
        Account accountNoValidSalesOrders = new Account(Name = 'Account with No Valid Sales Orders');
        insert accountNoValidSalesOrders;

        Opportunity oppWithoutValidSalesOrder = new Opportunity(
            Name = 'Opportunity with No Valid Sales Orders',
            AccountId = accountNoValidSalesOrders.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(10)
        );
        insert oppWithoutValidSalesOrder;

        SalesOrder__c invalidSalesOrder = new SalesOrder__c(
            Opportunity__c = oppWithoutValidSalesOrder.Id,
            Status__c = 'Cancelled',
            CustomerAccount__c = accountNoValidSalesOrders.Id
        );
        insert invalidSalesOrder;

        Id clonedOppId = CloneOpportunityController.cloneOpportunity(accountNoValidSalesOrders.Id);

        System.assertEquals(null, clonedOppId, 'No opportunity should be cloned when there are no valid sales orders.');
    }
}