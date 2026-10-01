@isTest
private class LeadWalkInControllerTest {
    
    @testSetup
    static void setupTestData() {
        // Insert a test user with the required profile name "Sales Management"
        Profile salesManagementProfile = [SELECT Id FROM Profile WHERE Name = 'Sales Management' LIMIT 1];
    }
    
    @isTest
    static void testGetSalesExecutiveOptions() {
        Test.startTest();
        // Call the getSalesExecutiveOptions method
        List<User> salesExecutives = LeadWalkInController.getSalesExecutiveOptions();
        Test.stopTest();
        
    }

    @isTest
    static void testCreateLead() {
        // Call the getSalesExecutiveOptions method
        List<User> salesExecutives = LeadWalkInController.getSalesExecutiveOptions();
        // Call the getAdNameOptions method
        List<String> adNames = LeadWalkInController.getAdNameOptions();

        
        Lead testLead = new Lead(
            VisitorType__c= 'Direct',
            FirstName= 'Direct',
            LastName= 'Direct',
            MobilePhone='+971555555555',
            Email= 'test@test.com',
            AdName__c='SMS',
            SubSource__c= 'SMS',
            Sales_Executive__c= 'SMS',
            Description= 'SMS',
            LeadSource= 'Walk-in',
            AdSetName__c= 'Hudayriyat Island Sales Centre Visitors',
            UTMSource__c= 'Hudayriyat Island Sales Centre Visitors',
            UTMCampaign__c= 'Salesforce'
            
        );
        
        
        // Call the createLead method
        Lead createdLead = LeadWalkInController.createLead(testLead);
       
        
       
    }
}