@isTest
public class DefaultServiceRequestController_Test {
    
    @testSetup
    static void setupData() {
        // Test Account
        Account acc = new Account(Name = 'Test Customer');
        insert acc;

        // Test Contact
        Contact con = new Contact(
            FirstName = 'Default',
            LastName = 'User',
            Email = 'default@test.com',
            AccountId = acc.Id,
            Is_Active__c = true
        );
        insert con;

        // Test Sales Order
        SalesOrder__c so = new SalesOrder__c(
            CustomerAccount__c = acc.Id,
            Status__c = 'Completed'
        );
        insert so;
    }
    
    @isTest
    static void testCreateDefaultServiceRequest() {
        // Fetch sales order
        SalesOrder__c so = [SELECT Id, Name FROM SalesOrder__c LIMIT 1];

        Test.startTest();
            // Call your controller method
            //DefaultServiceRequestController.createDefaultSR(so.Id);
        Test.stopTest();

      
    }
}