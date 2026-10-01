@isTest
private class ContactTriggerHelperTest {
    
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
    
    @isTest static void testCreatePortalUsersAfterInsert() {
        // Prepare test data 
        Contact newContact = createTestContact(true, 'BrokerAgent');
        Contact newContact2 = createTestContact(true, 'Individual');
        set<string> contactIds_CurrentContext = new set<string>();
        contactIds_CurrentContext.add(newContact2.Id);
        // Simulate trigger context variables
        List<SObject> newList = new List<SObject>{newContact,newContact2};
        Map<Id, SObject> newMap = new Map<Id, SObject>{newContact.Id => newContact};
        
        Test.startTest();
        // Call method simulating after insert context
        ContactTriggerHelper.createPortalUsers(newList, newMap, null, null);
        ContactTriggerHelper.createPortalUsers_Future(contactIds_CurrentContext,'Insert');
        Test.stopTest();
        
        // Normally, you would include assertions here to verify outcomes
    }
    
    @isTest static void testCreatePortalUsersAfterUpdate() {
        // Prepare initial test data
        Contact existingContact = createTestContact(true, 'BrokerAgent');
        
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
        ContactTriggerHelper.createPortalUsers_Future(new set<String>{updatedContact.Id},'Update');
        ContactTriggerHandler contList =new ContactTriggerHandler();
        List<Contact> conlist =contList.castToContactList(newList);
        
        Map<Id, Contact> newConMap = new Map<Id, Contact>();
        Map<Id, Contact> oldConMap = new Map<Id, Contact>();
        for(Contact con: (List<Contact>)newList)
        {
            newConMap.put(con.Id, con);
            oldConMap.put(con.Id, con);
        }
        
        ContactTriggerHelper.beforeUpdate( newConMap, oldConMap);
        Test.stopTest();
    }
    
    @isTest static void testUpdateReprocessingFlag() {
        Contact testContact = new Contact();
        // Set fields based on parameters
        testContact.FirstName = 'Test';
        testContact.LastName = 'Contact';
        testContact.Email = 'testcontact@example.com';
        testContact.En_Email__c = 'testcontact@123mail.com';
        testContact.En_Phone__c = '+919886578897';
        testContact.MobilePhone = '+919886578897';
        testContact.EIDNumber__c = '784-1987-1234567-8';
        testContact.En_EIDNumber__c = '784-1987-1234567-9';
        testContact.Nationality__c = 'India';
        testContact.En_Nationality__c = 'India';
        testContact.UAE_Resident_Status__c = 'Non-Resident';
        
        // Set RecordTypeId based on DeveloperName
        Id recordTypeId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('Individual').getRecordTypeId();
        testContact.RecordTypeId = recordTypeId;

        insert testContact;
        
        Test.startTest();
        TriggerHandler.processedIds = new Set<Id>();
        testContact.Source_Entity__c = 'Modon - UAE';
        testContact.UAE_Resident_Status__c = 'Resident';
        testContact.Email = 'testcontact@example.com';
        testContact.En_Email__c = 'testcontact@123mail.com';
        testContact.En_Phone__c = '+919886578897';
        testContact.MobilePhone = '+919886578897';
        testContact.EIDNumber__c = '784-1987-1234567-8';
        testContact.En_EIDNumber__c = '784-1987-1234567-9';
        testContact.Nationality__c = 'India';
        testContact.En_Nationality__c = 'India';
        update testContact;
        Test.stopTest();
    }
    
    /*@isTest static void testcastToContactList() {
        // Prepare initial test data
        // 
        // beforeUpdateMethod(list<SObject> newList,Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap)
        
        Contact existingContact = createTestContact(true, 'BrokerAgent');
        List<SObject> sObjectList = new List<SObject>();
        sObjectList.add(existingContact);
        
        Test.startTest();
        List<Contact> conList = ContactTriggerHandler.castToContactList(sObjectList);
        Test.stopTest();
    }*/
    
    // Include additional test methods as needed to cover different scenarios
    
    
    
    static TestMethod void testForNonEgypt(){
        Contact oldRec = new Contact();
        oldRec.LastName = 'Test contact';
        oldRec.Email = 'test@test.com';
        oldRec.Source_Entity__c = 'Modon - Egypt';
        INSERT oldRec;
        
        Contact newRec = new Contact(Id = oldRec.ID, LastName = 'Test contact 2');
        
        List<SObject> newList = new List<SObject>{ newRec };
        List<SObject> oldList = new List<SObject>{ oldRec };
        Map<Id, SObject> sObjNewMap = new Map<Id, SObject>{ newRec.Id => newRec };
        Map<Id, SObject> sObjOldMap = new Map<Id, SObject>{ oldRec.Id => oldRec };
        
        Map<String, Object> result = Modon_Egypt_ContactFilterHelper.filterBeforeUpdate(newList, sObjNewMap, oldList, sObjOldMap);
        Map<String, Object> result1 = Modon_Egypt_ContactFilterHelper.filterAfterUpdate(newList, sObjNewMap, oldList, sObjOldMap);
        System.assert(result1 != null && result1.containsKey('ModonEgyptContacts'), 'Expected filtered results');
        System.assert(result != null && result.containsKey('ModonEgyptContacts'), 'Expected filtered results');
    }
    
    @isTest
    static void testActivateInActivatePortalUsers() {
        
        Id contactRtId = [SELECT Id FROM RecordType WHERE SObjectType = 'Contact' AND DeveloperName = 'Broker_Agency' LIMIT 1].Id;

        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Contact con = new Contact(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'test@example.com',
            RecordTypeId = contactRtId,
            AccountId = acc.Id,
            Agent_Status__c = 'In Active',
            Broker_Type__c = 'Agent'
        );
        insert con;

        User portalUser = new User(
            Username = 'shawntest0076@example.com.testuat',
            Alias = 'tuser',
            LastName = 'User',
            Email = 'shawntest0076@example.com',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Modon - Partner Community Login User' LIMIT 1].Id,
            TimeZoneSidKey = 'America/New_York',
            UserRoleId = null,
            ContactId = con.Id
        );
        insert portalUser;

        con.Agent_Status__c = 'Active'; 
        update con;

       
        Contact updatedCon = [SELECT Id, RecordTypeId, Agent_Status__c, Broker_Type__c FROM Contact WHERE Id = :con.Id];
        Map<Id, SObject> oldContactMap = new Map<Id, SObject>{
            updatedCon.Id => new Contact(Id = updatedCon.Id, RecordTypeId = updatedCon.RecordTypeId, Agent_Status__c = 'In Active')
        };

        List<Contact> updatedContactList = new List<Contact>{updatedCon};

        Test.startTest();
        
        ContactTriggerHelper.activateInActivatePortalUsers(updatedContactList, oldContactMap);
        Test.stopTest();

        User updatedUser = [SELECT Id, IsActive FROM User WHERE ContactId = :con.Id];
        System.assertEquals(true, updatedUser.IsActive, 'User should be activated');
    } 
    
    
    @isTest
static void testMissingPaths() {

    Id rtId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName()
                    .get('BrokerAgent').getRecordTypeId();

    Contact con = new Contact(
        FirstName = 'Test',
        LastName = 'User',
        Email = 'testuser@test.com',
        RecordTypeId = rtId,
        BrokerContactFromOracleFusion__c = true
    );
    insert con;

    Contact oldCon = [SELECT Id, FirstName,En_Nationality__c,Masked_Emirates_Id__c,Masked_Phone__c,En_PassportNumber__c,PassportNumber__c,Masked_Email__c,Nationality__c,En_EIDNumber__c,EIDNumber__c,En_MobilePhone__c,Phone,MiddleName, LastName, Email FROM Contact WHERE Id = :con.Id];

    con.Email = 'updated@test.com';

    List<SObject> newList = new List<SObject>{con};
    Map<Id, SObject> newMap = new Map<Id, SObject>{con.Id => con};
    List<SObject> oldList = new List<SObject>{oldCon};
    Map<Id, SObject> oldMap = new Map<Id, SObject>{oldCon.Id => oldCon};

    Test.startTest();

    ContactTriggerHelper.createPortalUsers(newList, newMap, oldList, oldMap);

    ContactTriggerHelper.createPortalUsers_Future(
        new Set<String>{con.Id},
        'Update'
    );

    Map<Id, Contact> newConMap = new Map<Id, Contact>{con.Id => con};
    Map<Id, Contact> oldConMap = new Map<Id, Contact>{oldCon.Id => oldCon};

    ContactTriggerHelper.beforeUpdate(newConMap, oldConMap);

    Test.stopTest();
}
    
    @isTest
static void testActivateInactiveAndBlocked() {

    Id contactRtId = BRConstants.BROKER_AGENT_RT;

    Account acc = new Account(Name = 'Test Acc 2');
    insert acc;

    Contact con = new Contact(
        FirstName = 'Test',
        LastName = 'User',
        Email = 'inactive@test.com',
        RecordTypeId = contactRtId,
        AccountId = acc.Id,
        Agent_Status__c = 'Active',
        Broker_Type__c = 'Agent'
    );
    insert con;

    User portalUser = new User(
        Username = 'inactiveuser@test.com.test',
        Alias = 'tusr2',
        LastName = 'User',
        Email = 'inactiveuser@test.com',
        EmailEncodingKey = 'UTF-8',
        LanguageLocaleKey = 'en_US',
        LocaleSidKey = 'en_US',
        ProfileId = [SELECT Id FROM Profile WHERE Name = 'Modon - Partner Community Login User' LIMIT 1].Id,
        TimeZoneSidKey = 'America/New_York',
        ContactId = con.Id
    );
    insert portalUser;

    Contact updatedCon = [SELECT Id, RecordTypeId, Agent_Status__c FROM Contact WHERE Id = :con.Id];

    Map<Id, SObject> oldMap = new Map<Id, SObject>{
        updatedCon.Id => new Contact(
            Id = updatedCon.Id,
            RecordTypeId = updatedCon.RecordTypeId,
            Agent_Status__c = 'Active'
        )
    };

    updatedCon.Agent_Status__c = 'Suspended';

    Test.startTest();

    ContactTriggerHelper.activateInActivatePortalUsers(
        new List<Contact>{updatedCon},
        oldMap
    );

    Test.stopTest();
}
    
    
}