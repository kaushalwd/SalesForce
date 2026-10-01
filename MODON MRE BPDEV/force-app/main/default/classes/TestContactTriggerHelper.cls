@isTest
private class TestContactTriggerHelper {
    
    // Method to create a test Contact with minimal required fields set
    private static Contact createTestContact(Boolean fromOracleFusion, String recordTypeName) {
        Contact testContact = new Contact();
        
        // Set fields based on parameters
        testContact.FirstName = 'Test';
        testContact.LastName = 'Contact';
        testContact.Email = 'testcontact@example.com';
        testContact.BrokerContactFromOracleFusion__c = fromOracleFusion;
        
        // Set RecordTypeId based on DeveloperName
        Id recordTypeId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get(recordTypeName).getRecordTypeId();
        testContact.RecordTypeId = recordTypeId;
                
        insert testContact;
        return testContact;
    }
    
        private static Contact createTestContact2(Boolean fromOracleFusion, String recordTypeName) {
        Contact testContact = new Contact();
        
        // Set fields based on parameters
        testContact.FirstName = 'Test2';
        testContact.LastName = 'Contact2';
        testContact.Email = 'testcontac2t@example.com';
        testContact.BrokerContactFromOracleFusion__c = fromOracleFusion;
        
        // Set RecordTypeId based on DeveloperName
        Id recordTypeId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get(recordTypeName).getRecordTypeId();
        testContact.RecordTypeId = recordTypeId;
                
        insert testContact;
        return testContact;
    }

    
    @isTest static void testCreatePortalUsersAfterInsert() {
        // Prepare test data
        Contact newContact = createTestContact(true, 'BrokerAgent');
        
        // Simulate trigger context variables
        List<SObject> newList = new List<SObject>{newContact};
        Map<Id, SObject> newMap = new Map<Id, SObject>{newContact.Id => newContact};
        
        Test.startTest();
        // Call method simulating after insert context
        ContactTriggerHelper.createPortalUsers(newList, newMap, null, null);
        Test.stopTest();
        
    }
    
    @isTest static void testCreatePortalUsersAfterUpdate() {
        // Prepare initial test data
        Contact existingContact = createTestContact2(true, 'BrokerAgent');
        
        // Simulate an update to the contact
        Contact updatedContact = new Contact(Id = existingContact.Id, FirstName = 'Updated');
        
        // Simulate trigger context variables for update
        List<SObject> newList = new List<SObject>{updatedContact};
        Map<Id, SObject> newMap = new Map<Id, SObject>{updatedContact.Id => updatedContact};
        List<SObject> oldList = new List<SObject>{existingContact};
        Map<Id, SObject> oldMap = new Map<Id, SObject>{existingContact.Id => existingContact};
        
        Test.startTest();
        // Call method simulating after update context
        ContactTriggerHelper.createPortalUsers(newList, newMap, oldList, oldMap);
        Test.stopTest();
        
    }
    
    // Include additional test methods as needed to cover different scenarios
}