@isTest
private class TriggerHandlerTest {

    private static Contact buildContact(String suffix) {
        Contact testContact = new Contact(
            FirstName = 'Trigger',
            LastName = 'Handler ' + suffix,
            Email = 'trigger.handler.' + suffix + '@example.com',
            BrokerContactFromOracleFusion__c = false
        );

        Map<String, Schema.RecordTypeInfo> recordTypes =
            Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName();
        if (recordTypes.containsKey('Individual')) {
            testContact.RecordTypeId = recordTypes.get('Individual').getRecordTypeId();
        }

        return testContact;
    }

    @isTest
    static void testContactInsertCoversTriggerHandler() {
        TriggerHandler.processedIds = new Set<Id>();
        Contact testContact = buildContact('insert');

        Test.startTest();
        insert testContact;
        Test.stopTest();

        System.assertNotEquals(null, testContact.Id, 'Contact should be inserted.');
        System.assert(
            TriggerHandler.processedIds.contains(testContact.Id),
            'After-insert processing should add the record id to processedIds.'
        );
    }

    @isTest
    static void testContactUpdateCoversTriggerHandler() {
        Contact testContact = buildContact('update');
        insert testContact;

        TriggerHandler.processedIds = new Set<Id>();
        testContact.FirstName = 'Updated';

        Test.startTest();
        update testContact;
        Test.stopTest();

        System.assertEquals('Updated', [
            SELECT FirstName
            FROM Contact
            WHERE Id = :testContact.Id
        ].FirstName);
        System.assert(
            TriggerHandler.processedIds.contains(testContact.Id),
            'After-update processing should add the record id to processedIds.'
        );
    }

    @isTest
    static void testContactDeleteCoversTriggerHandler() {
        Contact testContact = buildContact('delete');
        insert testContact;

        TriggerHandler.processedIds = new Set<Id>();

        Test.startTest();
        delete testContact;
        Test.stopTest();

        Contact deletedContact = [
            SELECT Id, IsDeleted
            FROM Contact
            WHERE Id = :testContact.Id
            ALL ROWS
        ];
        System.assert(deletedContact.IsDeleted, 'Contact should be deleted.');
    }

    @isTest
    static void testBaseExtensionPointsAndHelperMethods() {
        TriggerHandler.processedIds = new Set<Id>();
        TriggerHandler handler = new TriggerHandler();

        handler.beforeInsertMethod(new List<SObject>(), new Map<Id, SObject>());
        handler.beforeUpdateMethod(
            new List<SObject>(),
            new Map<Id, SObject>(),
            new List<SObject>(),
            new Map<Id, SObject>()
        );
        handler.beforeDeleteMethod(new List<SObject>(), new Map<Id, SObject>());
        handler.afterInsertMethod(new List<SObject>(), new Map<Id, SObject>());
        handler.afterUpdateMethod(
            new List<SObject>(),
            new Map<Id, SObject>(),
            new List<SObject>(),
            new Map<Id, SObject>()
        );
        handler.afterDeleteMethod(new List<SObject>(), new Map<Id, SObject>());

        Contact includedContact = buildContact('included');
        Contact filteredContact = buildContact('filtered');
        insert new List<Contact>{ includedContact, filteredContact };

        TriggerHandler.processedIds = new Set<Id>();
        TriggerHandler.addProcessedIds(new List<SObject>{ filteredContact });

        List<SObject> filteredList = TriggerHandler.filterList(
            new List<SObject>{ includedContact, filteredContact }
        );
        Map<Id, SObject> filteredMap = TriggerHandler.filterMap(
            new Map<Id, SObject>{
                includedContact.Id => includedContact,
                filteredContact.Id => filteredContact
            }
        );

        System.assertEquals(1, filteredList.size(), 'One record should remain after filtering.');
        System.assertEquals(includedContact.Id, filteredList[0].Id);
        System.assertEquals(1, filteredMap.size(), 'One map entry should remain after filtering.');
        System.assert(filteredMap.containsKey(includedContact.Id));
        System.assertEquals(null, TriggerHandler.filterList(null));
        System.assertEquals(null, TriggerHandler.filterMap(null));
    }
}