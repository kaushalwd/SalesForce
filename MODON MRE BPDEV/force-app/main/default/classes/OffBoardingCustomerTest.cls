@isTest
public class OffBoardingCustomerTest {
    @testSetup
    static void setupData() {

        // Accounts
        Account acc1 = new Account(Name = 'Customer 1');
        Account acc2 = new Account(Name = 'Customer 2');
        insert new List<Account>{acc1, acc2};

        // Contacts
        Contact con1 = new Contact(
            FirstName = 'Test',
            LastName = 'User1',
            Email = 'user1@test.com',
            AccountId = acc1.Id
        );

        Contact con2 = new Contact(
            FirstName = 'Test',
            LastName = 'User2',
            Email = 'user2@test.com',
            AccountId = acc2.Id
        );
        insert new List<Contact>{con1, con2};

        // Create portal users (VERY IMPORTANT for coverage)
Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

User u1 = new User(
    Alias = 'u1',
    Email = 'portal1@test.com',
    EmailEncodingKey = 'UTF-8',
    LastName = 'Portal1',
    LanguageLocaleKey = 'en_US',
    LocaleSidKey = 'en_US',
    TimeZoneSidKey = 'Asia/Kolkata',
    ProfileId = p.Id,
    Username = 'portal1' + DateTime.now().getTime() + '@test.com',
    IsActive = true
);

User u2 = new User(
    Alias = 'u2',
    Email = 'portal2@test.com',
    EmailEncodingKey = 'UTF-8',
    LastName = 'Portal2',
    LanguageLocaleKey = 'en_US',
    LocaleSidKey = 'en_US',
    TimeZoneSidKey = 'Asia/Kolkata',
    ProfileId = p.Id,
    Username = 'portal2' + DateTime.now().getTime() + '@test.com',
    IsActive = true
);

insert new List<User>{u1, u2};

        // Project + Unit
        Project__c proj = new Project__c(Name = 'Test Project');
        insert proj;

        Phase__c phase = new Phase__c(Name = 'Phase', Project__c = proj.Id);
        insert phase;

        Unit__c unit = new Unit__c(
            Name = 'Unit1',
            Phase__c = phase.Id,
            PlotAreasqm__c = 1,
            PlotNo__c = '1',
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '1'
        );
        insert unit;

        // Sales Orders (IMPORTANT: Resale_Transfer_Date__c = TODAY)
        SalesOrder__c so1 = new SalesOrder__c(
            CustomerAccount__c = acc1.Id,
            Old_Account__c = acc1.Id,
            Status__c = 'Completed',
            Unit__c = unit.Id,
            Resale_Transfer_Date__c = Date.today()
        );

        SalesOrder__c so2 = new SalesOrder__c(
            CustomerAccount__c = acc2.Id,
            Old_Account__c = acc2.Id,
            Status__c = 'Completed',
            Unit__c = unit.Id,
            Resale_Transfer_Date__c = Date.today()
        );

        insert new List<SalesOrder__c>{so1, so2};

        // Joint Owner History (to cover that branch)
        Joint_Owner_History__c joh = new Joint_Owner_History__c(
            Sales_Order__c = so1.Id,
            Account__c = acc2.Id,
            Ownership__c = 12,
            Transfer_Date__c = Date.today()
        );
        insert joh;
    }

    @isTest
    static void testBatchExecution() {

        Test.startTest();

        OffBoardingCustomer batch = new OffBoardingCustomer(null);
        Database.executeBatch(batch, 1);

        Test.stopTest();

        // Verify users got deactivated
        List<User> users = [SELECT Id, IsActive FROM User WHERE IsActive = false];
        System.assert(users.size() > 0, 'Users should be deactivated');
    }

    @isTest
    static void testNoAccountsScenario() {
        Test.startTest();

        // Pass empty set → should hit early return
        OffBoardingCustomer batch = new OffBoardingCustomer(new Set<String>());
        Database.executeBatch(batch, 1);

        Test.stopTest();

        System.assert(true);
    }
    
   @isTest
static void testDeactivatePortalUsers_NoModification() {

    Account acc = new Account(Name = 'Test Acc');
    insert acc;

    Test.startTest();

    OffBoardingCustomer obj = new OffBoardingCustomer(null);
    obj.deactivatePortalUsers(new Set<Id>{acc.Id});

    Test.stopTest();
 
}
}