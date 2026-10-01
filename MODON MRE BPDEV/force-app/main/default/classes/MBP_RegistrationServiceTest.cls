@isTest
public class MBP_RegistrationServiceTest {

    private static final String ADMIN_EMAIL = 'john.doe@example.com';
    private static final String OWNER_EMAIL = 'olivia.owner@example.com';

    // ------------------------------------------------------------------------------------
    // TEST DATA
    // ------------------------------------------------------------------------------------
    @testSetup
    static void setupTestData() {
        Registration__c reg = new Registration__c(
            Agency_Name__c = 'Test Agency',
            Website__c = 'https://test.com',
            Type_of_Registration__c = 'UAE Broker',
            Company_Email_Address__c = 'testagency@example.com',
            Address_Line_1__c = 'Address Line 1',
            Address_Line_2__c = 'Address Line 2',
            Country__c = 'United Arab Emirates',
            State__c = 'Abu Dhabi',
            Company_City__c = 'Abu Dhabi',
            PO_Box_Emirate__c = '123456',
            Mobile_Number__c = '0501112233',
            Licensing_Authority__c = 'Authority XYZ',
            Issuance_Date__c = Date.today().addYears(-1),
            Company_Name_as_per_Trade_License__c = 'Test Co LLC',
            Expiry_Date__c = Date.today().addYears(1),
            Trade_License_Number__c = 'TL-12345',
            VAT_Certificate_Type__c = 'VAT Registration Certificate'
        );
        insert reg;

        ServiceRequest__c sr = new ServiceRequest__c(
            Registration__c = reg.Id,
            Fast_Track__c = true,
            Status__c = 'In-progress'
        );
        insert sr;

        // Agency Admin
        Registration_Agent__c admin = new Registration_Agent__c(
            Agent_First_Name__c = 'John',
            Agent_Last_Name__c = 'Doe',
            Agent_Email__c = ADMIN_EMAIL,
            Agent_Phone_Number__c = '0509998888',
            Emirates_ID_Number__c = 'EID123456',
            Passport_Number__c = 'P987654321',
            Passport_Expiry__c = Date.today().addYears(5),
            Type__c = 'Agency Admin',
            Primary_Owner__c = true,
            Primary_Agency_Admin__c = true,
            Registration_Name__c = reg.Id
        );

        // Owner (needed for the Fast Track owner-only path)
        Registration_Agent__c owner = new Registration_Agent__c(
            Agent_First_Name__c = 'Olivia',
            Agent_Last_Name__c = 'Owner',
            Agent_Email__c = OWNER_EMAIL,
            Agent_Phone_Number__c = '0507776666',
            Emirates_ID_Number__c = 'EID654321',
            Passport_Number__c = 'P123456789',
            Passport_Expiry__c = Date.today().addYears(5),
            Type__c = BRConstants.AGENT_TYPE_OWNER,
            Share_holding_percentage__c = '100',
            Registration_Name__c = reg.Id
        );
        insert new List<Registration_Agent__c>{ admin, owner };

        Task t = new Task(
            Subject = 'Require More Information',
            WhatId = sr.Id,
            OwnerId = UserInfo.getUserId(),
            Status = 'Not Started',
            Priority = 'Normal'
        );
        insert t;
    }

    // ------------------------------------------------------------------------------------
    // HELPERS
    // ------------------------------------------------------------------------------------
    private static ServiceRequest__c getServiceRequest() {
        return [SELECT Id, Name, Registration__c, Fast_Track__c, Status__c FROM ServiceRequest__c LIMIT 1];
    }

    // In-memory Task is enough - createBrokerAgency only reads Subject and Broker_Registration_Status__c
    private static Task buildTask(String subject, String brokerRegStatus) {
        return new Task(Subject = subject, Broker_Registration_Status__c = brokerRegStatus);
    }

    private static Account getAgencyAccount() {
        Registration__c reg = [SELECT Broker_Agency__c FROM Registration__c LIMIT 1];
        System.assertNotEquals(null, reg.Broker_Agency__c, 'Expected Registration to be linked to the agency Account');
        return [SELECT Id, Name, Agency_Status__c FROM Account WHERE Id = :reg.Broker_Agency__c];
    }

    private static List<Contact> getContacts(Id accountId) {
        return [SELECT Id, Email, Broker_Type__c, Agent_Status__c FROM Contact WHERE AccountId = :accountId];
    }

    private static List<User> getUsers(List<Contact> contacts) {
        return [SELECT Id, ContactId, Username FROM User WHERE ContactId IN :contacts];
    }

    private static Integer countPermissionSet(List<User> users, String permSetName) {
        return [SELECT COUNT() FROM PermissionSetAssignment
                WHERE AssigneeId IN :users AND PermissionSet.Name = :permSetName];
    }

    // Documents__c may have required fields/validations in your org - never let this break the test.
    private static void insertDocumentsSafely() {
        try {
            Registration__c reg = [SELECT Id FROM Registration__c LIMIT 1];
            List<Registration_Agent__c> agents = [SELECT Id FROM Registration_Agent__c];
            List<Documents__c> docs = new List<Documents__c>();
            docs.add(new Documents__c(Registration__c = reg.Id));
            for (Registration_Agent__c a : agents) {
                docs.add(new Documents__c(Registration_Agent__c = a.Id));
            }
            insert docs;
        } catch (Exception e) {
            System.debug('Documents__c setup skipped: ' + e.getMessage());
        }
    }

    // ------------------------------------------------------------------------------------
    // createBrokerAgency - standard (non Fast Track) flows
    // ------------------------------------------------------------------------------------
    @isTest
    static void testCreateBrokerAgency() {
        // Original scenario kept: Fast Track SR, real task
        ServiceRequest__c sr = getServiceRequest();
        Task t = [SELECT Id, Subject, WhatId, Broker_Registration_Status__c FROM Task WHERE WhatId = :sr.Id LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        Test.startTest();
        MBP_RegistrationService.createBrokerAgency(sr, t);
        Test.stopTest();

        List<Account> accList = [SELECT Id, Name FROM Account WHERE Name = 'Test Agency'];
        System.assert(!accList.isEmpty(), 'Expected Account to be created');

        List<Contact> contacts = getContacts(accList[0].Id);
        System.assert(contacts.size() > 0, 'Expected contact(s) to be created');

        List<User> users = getUsers(contacts);
        System.assert(users.size() > 0, 'Expected user(s) to be created');

        List<PermissionSetAssignment> psas = [SELECT Id FROM PermissionSetAssignment WHERE AssigneeId IN :users];
        System.assert(psas.size() > 0, 'Expected permission set assignments');
    }

    @isTest
    static void testLimitedAccess_RequireMoreInformation() {
        ServiceRequest__c sr = getServiceRequest();
        sr.Fast_Track__c = false;
        Task t = buildTask(BRConstants.SERVICE_REQUEST_TASK1, BRConstants.ACTION_STATUS_RMI);
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        insertDocumentsSafely();

        Test.startTest();
        MBP_RegistrationService.createBrokerAgency(sr, t);
        Test.stopTest();

        Account acc = getAgencyAccount();
        System.assertEquals(BRConstants.ACCOUNT_STATUS_PENDINGVERIFICATION, acc.Agency_Status__c);

        List<Contact> contacts = getContacts(acc.Id);
        System.assertEquals(2, contacts.size(), 'Admin + Owner contacts expected');

        List<User> users = getUsers(contacts);
        System.assertEquals(2, users.size(), 'A user per contact expected');
        System.assert(countPermissionSet(users, BRConstants.MODON_LIMITED_LOGIN_ACCESS) > 0,
                      'Limited login permission set expected');
    }

    @isTest
    static void testLimitedAccess_Task3() {
        ServiceRequest__c sr = getServiceRequest();
        sr.Fast_Track__c = false;
        Task t = buildTask(BRConstants.SERVICE_REQUEST_TASK3, BRConstants.ACTION_STATUS_APPROVED);
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        Test.startTest();
        MBP_RegistrationService.createBrokerAgency(sr, t);
        Test.stopTest();

        Account acc = getAgencyAccount();
        System.assertEquals(BRConstants.ACCOUNT_STATUS_PENDINGVERIFICATION, acc.Agency_Status__c);
        System.assertEquals(2, getUsers(getContacts(acc.Id)).size());
    }

    @isTest
    static void testFinalStep_Approved_FullAccess() {
        ServiceRequest__c sr = getServiceRequest();
        sr.Fast_Track__c = false;
        Task t = buildTask(BRConstants.SERVICE_REQUEST_TASK5, BRConstants.ACTION_STATUS_APPROVED);
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        Test.startTest();
        MBP_RegistrationService.createBrokerAgency(sr, t);
        Test.stopTest();

        Account acc = getAgencyAccount();
        System.assertEquals(BRConstants.ACCOUNT_STATUS_ACTIVE, acc.Agency_Status__c);

        List<User> users = getUsers(getContacts(acc.Id));
        System.assertEquals(2, users.size());
        System.assertEquals(0, countPermissionSet(users, BRConstants.MODON_LIMITED_LOGIN_ACCESS),
                            'Full access users must not have limited login');
    }

    @isTest
    static void testNoTaskSubjectMatch_NoEmailBranch() {
        // Task with an unrelated subject and no status -> agencyStatus null, "no email" branch
        ServiceRequest__c sr = getServiceRequest();
        sr.Fast_Track__c = false;
        Task t = buildTask('Some Other Step', null);
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        Test.startTest();
        MBP_RegistrationService.createBrokerAgency(sr, t);
        Test.stopTest();

        Account acc = getAgencyAccount();
        System.assertEquals(2, getContacts(acc.Id).size());
    }

    // ------------------------------------------------------------------------------------
    // Fast Track flows
    // ------------------------------------------------------------------------------------
    @isTest
    static void testFastTrack_ToggleEvent_OwnerOnly() {
        ServiceRequest__c sr = getServiceRequest();
        sr.Fast_Track__c = true;
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        Test.startTest();
        // task == null -> genuine one-time Fast Track activation
        MBP_RegistrationService.createBrokerAgency(sr, null);
        Test.stopTest();

        Account acc = getAgencyAccount();
        System.assertEquals(BRConstants.ACCOUNT_STATUS_PENDINGVERIFICATION, acc.Agency_Status__c);

        List<Contact> contacts = getContacts(acc.Id);
        System.assertEquals(2, contacts.size(), 'Both contacts are created');

        List<User> users = getUsers(contacts);
        System.assertEquals(1, users.size(), 'Fast Track creates a user for the Owner only');
        Contact ownerContact = [SELECT Broker_Type__c FROM Contact WHERE Id = :users[0].ContactId];
        System.assertEquals(BRConstants.AGENT_TYPE_OWNER, ownerContact.Broker_Type__c);
    }

    @isTest
    static void testFastTrack_OrdinaryStep_NotToggleEvent() {
        ServiceRequest__c sr = getServiceRequest();
        sr.Fast_Track__c = true;
        Task t = buildTask(BRConstants.SERVICE_REQUEST_TASK1, null);
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        Test.startTest();
        MBP_RegistrationService.createBrokerAgency(sr, t);
        Test.stopTest();

        Account acc = getAgencyAccount();
        System.assertEquals(1, getUsers(getContacts(acc.Id)).size(), 'Owner-only access while Fast Track is active');
    }

    @isTest
    static void testFastTrack_FinalStepApproved() {
        ServiceRequest__c sr = getServiceRequest();
        sr.Fast_Track__c = true;
        Task t = buildTask(BRConstants.SERVICE_REQUEST_TASK5, BRConstants.ACTION_STATUS_APPROVED);
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        Test.startTest();
        MBP_RegistrationService.createBrokerAgency(sr, t);
        Test.stopTest();

        Account acc = getAgencyAccount();
        System.assertEquals(BRConstants.ACCOUNT_STATUS_ACTIVE, acc.Agency_Status__c);
        System.assertEquals(2, getUsers(getContacts(acc.Id)).size(), 'Final step is not owner-filtered');
    }

    // ------------------------------------------------------------------------------------
    // Merge / existing contact + existing user paths
    // ------------------------------------------------------------------------------------
    @isTest
    static void testMergeExistingContact_AndExistingUsers() {
        Account preAcc = new Account(Name = 'Pre Existing Agency');
        insert preAcc;
        Contact existing = new Contact(
            FirstName = 'Old',
            LastName = 'Owner',
            Email = OWNER_EMAIL,
            AccountId = preAcc.Id,
            RecordTypeId = BRConstants.BROKER_AGENT_RT
        );
        insert existing;

        ServiceRequest__c sr = getServiceRequest();
        sr.Fast_Track__c = false;
        Task t = buildTask(BRConstants.SERVICE_REQUEST_TASK1, BRConstants.ACTION_STATUS_RMI);
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        Test.startTest();
        // Run 1: existing Contact gets merged, Users get created.
        // Run 2: Account/Contacts already exist, Users already exist -> "existing user" branches.
        MBP_RegistrationService.createBrokerAgency(sr, t);
        MBP_RegistrationService.createBrokerAgency(sr, t);
        Test.stopTest();

        Account acc = getAgencyAccount();
        List<Contact> ownerContacts = [SELECT Id, AccountId FROM Contact WHERE Email = :OWNER_EMAIL];
        System.assertEquals(1, ownerContacts.size(), 'Existing contact must be merged, not duplicated');
        System.assertEquals(existing.Id, ownerContacts[0].Id);
        System.assertEquals(acc.Id, ownerContacts[0].AccountId, 'Merged contact moves to the agency');

        System.assertEquals(2, getUsers(getContacts(acc.Id)).size(), 'No duplicate users on re-run');
    }

    // ------------------------------------------------------------------------------------
    // createAgencyAccount (public) - direct call
    // ------------------------------------------------------------------------------------
    @isTest
    static void testCreateAgencyAccount_Direct() {
        Registration__c reg = [SELECT Agency_Name__c, Website__c, Type_of_Registration__c, Company_Email_Address__c,
                               Bank_Branch_Name__c, Bank_Branch_Type__c, Address_Line_1__c, Address_Line_2__c,
                               Country__c, State__c, Company_City__c, PO_Box_Emirate__c, Mobile_Number__c,
                               Licensing_Authority__c, Issuance_Date__c, Company_Name_as_per_Trade_License__c,
                               Expiry_Date__c, Trade_License_Number__c, Beneficiary_Name__c, VAT_Certificate_Type__c,
                               Broker_Agency__c, UAE_VAT_Registration_Number__c, Bank_Name__c,
                               IBAN_Country_Bank_Code__c, Account_Number__c, SWIFT_Sort_Code__c, Bank_Country__c, City__c
                               FROM Registration__c LIMIT 1];
        insertDocumentsSafely();

        Test.startTest();
        Account acc = MBP_RegistrationService.createAgencyAccount(new Account(), reg, BRConstants.ACCOUNT_STATUS_PENDINGVERIFICATION);
        Test.stopTest();

        System.assertNotEquals(null, acc.Id);
        System.assertEquals('Test Agency', [SELECT Name FROM Account WHERE Id = :acc.Id].Name);
        System.assertEquals(acc.Id, [SELECT Broker_Agency__c FROM Registration__c WHERE Id = :reg.Id].Broker_Agency__c);
    }

    // ------------------------------------------------------------------------------------
    // sendWelcomeEmails - direct calls (no DML before the callout, so the mock is honoured)
    // ------------------------------------------------------------------------------------
    @isTest
    static void testSendWelcomeEmails_AllTypes() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        ServiceRequest__c sr = getServiceRequest();
        Set<Id> targets = new Set<Id>{ UserInfo.getUserId() };
        Boolean ok = true;

        Test.startTest();
        try {
            MBP_RegistrationService.sendWelcomeEmails(targets, 'RMI', sr.Id);
            MBP_RegistrationService.sendWelcomeEmails(targets, 'RMI', null);
            MBP_RegistrationService.sendWelcomeEmails(targets, 'FULL', sr.Id);
            MBP_RegistrationService.sendWelcomeEmails(targets, 'FASTTRACK', sr.Id);
        } catch (Exception e) {
            ok = false;
        }
        Test.stopTest();

        System.assert(ok, 'sendWelcomeEmails must swallow send failures');
    }

    @isTest
    static void testSendWelcomeEmails_EmptyAndUnmatchedTargets() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        ServiceRequest__c sr = getServiceRequest();
        Boolean ok = true;

        Test.startTest();
        try {
            MBP_RegistrationService.sendWelcomeEmails(null, 'FASTTRACK', sr.Id);
            MBP_RegistrationService.sendWelcomeEmails(new Set<Id>(), 'FASTTRACK', sr.Id);
            MBP_RegistrationService.sendWelcomeEmails(new Set<Id>(), 'FULL', sr.Id);
            // Id that is not a User -> targetUsers query returns nothing
            MBP_RegistrationService.sendWelcomeEmails(new Set<Id>{ sr.Id }, 'FASTTRACK', sr.Id);
            MBP_RegistrationService.sendWelcomeEmails(new Set<Id>{ sr.Id }, 'FULL', sr.Id);
        } catch (Exception e) {
            ok = false;
        }
        Test.stopTest();

        System.assert(ok);
    }

    // ------------------------------------------------------------------------------------
    // getPermissionSetName / getPermissionSetAssignment
    // ------------------------------------------------------------------------------------
    @isTest
    static void testGetPermissionSetName() {
        System.assertEquals(BRConstants.MODON_LIMITED_LOGIN_ACCESS,
                            MBP_RegistrationService.getPermissionSetName('Owner', true));
        System.assertEquals(BRConstants.MODON_AGENT_ACCESS,
                            MBP_RegistrationService.getPermissionSetName('Agent', false));
        System.assertEquals(BRConstants.MODON_AGENCY_OWNER_ACCESS,
                            MBP_RegistrationService.getPermissionSetName('Owner', false));
        System.assertEquals(BRConstants.MODON_AGENCY_ADMIN_ACCESS,
                            MBP_RegistrationService.getPermissionSetName('Agency Admin', false));
        System.assertEquals(BRConstants.MODON_LIMITED_LOGIN_ACCESS,
                            MBP_RegistrationService.getPermissionSetName('Something Else', false));
    }

    @isTest
    static void testGetPermissionSetAssignment() {
        List<User> users = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

        MBP_RegistrationService.permissionMapWrapper wrapper = MBP_RegistrationService.getPermissionSetAssignment(users);
        System.assertNotEquals(null, wrapper.userPermissionAndAssignmentMap);
        System.assertNotEquals(null, wrapper.userPermissionsetAssignmentMap);

        MBP_RegistrationService.permissionMapWrapper emptyWrapper =
            MBP_RegistrationService.getPermissionSetAssignment(new List<User>());
        System.assert(emptyWrapper.userPermissionsetAssignmentMap.isEmpty());
    }
}