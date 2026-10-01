@isTest
private class MBP_PortalUserProvisioningQueueableTest {

    @testSetup
    static void createTestData() {

        Account agencyAcc = new Account(
            Name = 'Queueable Test Agency',
            RecordTypeId = BRConstants.BROKER_AGENCY_RT
        );
        insert agencyAcc;

        Contact con = new Contact(
            LastName = 'Queueable Owner',
            AccountId = agencyAcc.Id,
            RecordTypeId = BRConstants.BROKER_AGENT_RT,
            Broker_Type__c = 'Owner',
            Primary_Owner__c = true,
            Agent_Status__c = 'Active',
            Email = 'queueable.owner@test.com'
        );
        insert con;
    }

    @isTest
    static void testExecute_CreatesUserAndAssignsPermissionSet() {

        Contact con = [SELECT Id FROM Contact WHERE LastName = 'Queueable Owner' LIMIT 1];

        List<PermissionSet> ps = [
            SELECT Id FROM PermissionSet WHERE Name = :BRConstants.MODON_AGENCY_OWNER_ACCESS LIMIT 1
        ];
        System.assert(!ps.isEmpty(), 'Test org must have the ' + BRConstants.MODON_AGENCY_OWNER_ACCESS + ' PermissionSet configured');

        Test.startTest();

        System.enqueueJob(new MBP_PortalUserProvisioningQueueable(new Set<Id>{ con.Id }));

        Test.stopTest();

        List<User> createdUsers = [SELECT Id FROM User WHERE ContactId = :con.Id];
        System.assertEquals(1, createdUsers.size(), 'Expected a User to be created for the Contact');

        List<PermissionSetAssignment> psaList = [
            SELECT Id, AssigneeId, PermissionSetId
            FROM PermissionSetAssignment
            WHERE AssigneeId = :createdUsers[0].Id
            AND PermissionSetId = :ps[0].Id
        ];
        System.assertEquals(1, psaList.size(), 'Expected the owner permission set to be assigned to the newly created User');
    }

    @isTest
    static void testExecute_NoContactsFound_NoException() {

        Test.startTest();

        // Bogus Id that resolves to no Contact record — should hit the
        // early return in execute() without throwing.
        System.enqueueJob(new MBP_PortalUserProvisioningQueueable(new Set<Id>()));

        Test.stopTest();

        System.assert(true, 'Executing with an empty Id set should not throw');
    }

    @isTest
    static void testExecute_DuplicateEmail_LogsFailureWithoutThrowing() {

        Account agencyAcc = [SELECT Id FROM Account LIMIT 1];

        Contact conA = new Contact(
            LastName = 'Dup A',
            AccountId = agencyAcc.Id,
            RecordTypeId = BRConstants.BROKER_AGENT_RT,
            Broker_Type__c = 'Agent',
            Agent_Status__c = 'Active',
            Email = 'duplicate.email@test.com'
        );
        Contact conB = new Contact(
            LastName = 'Dup B',
            AccountId = agencyAcc.Id,
            RecordTypeId = BRConstants.BROKER_AGENT_RT,
            Broker_Type__c = 'Agent',
            Agent_Status__c = 'Active',
            Email = 'duplicate.email@test.com' // same email -> same Alias/UserName -> second insert fails
        );
        insert new List<Contact>{ conA, conB };

        Test.startTest();

        System.enqueueJob(new MBP_PortalUserProvisioningQueueable(
            new Set<Id>{ conA.Id, conB.Id }
        ));

        Test.stopTest();

        List<User> createdUsers = [
            SELECT Id, ContactId FROM User WHERE ContactId IN :new Set<Id>{ conA.Id, conB.Id }
        ];
        System.assertEquals(1, createdUsers.size(), 'Only the first of the two duplicate-email Users should have been created');

        Contact failedCon = [
            SELECT Id, PortalUserAutoCreationFailed__c
            FROM Contact
            WHERE Id NOT IN :new Set<Id>{ createdUsers[0].ContactId }
            AND Id IN :new Set<Id>{ conA.Id, conB.Id }
        ];
        System.assertEquals(true, failedCon.PortalUserAutoCreationFailed__c, 'The failed Contact should be flagged');
    }
}