@IsTest
public class MBP_ManageEventsandActivitiesTest {

    static Id agencyAccountId1;
    static Id agencyAccountId2;
    static Id eventId;

    static void setupTestData() {

        Account uaeAgency = new Account(
            Name = 'UAE Agency',
            Type_of_Registration__c = 'UAE Broker',
            BillingCountry = 'United Arab Emirates',
            BillingCity = 'Dubai',
            Bank_Country__c = 'United Arab Emirates',
            Phone = '123456'
        );

        // Bank_Country__c is record-type restricted; leave unset for International Broker
        Account intlAgency = new Account(
            Name = 'International Agency',
            Type_of_Registration__c = 'International Broker',
            BillingCountry = 'United States',
            BillingCity = 'New York',
            Phone = '999999'
        );

        insert new List<Account>{ uaeAgency, intlAgency };
        agencyAccountId1 = uaeAgency.Id;
        agencyAccountId2 = intlAgency.Id;

        Contact c1 = new Contact(
            LastName = 'Agent One',
            Email = 'agent1@test.com',
            AccountId = agencyAccountId1,
            Agent_Status__c = 'Active',
            Broker_Type__c = 'owner'
        );

        Contact c2 = new Contact(
            LastName = 'Agent Two',
            Email = 'agent2@test.com',
            AccountId = agencyAccountId2,
            Agent_Status__c = 'Active',
            Broker_Type__c = 'owner'
        );

        insert new List<Contact>{ c1, c2 };

        Event_and_Activity__c evt = new Event_and_Activity__c(
            Name = 'Test Event',
            Title__c = 'Property Expo',
            Status__c = 'Published',
            Type__c = 'Open house',
            Start_Date_and_Time__c = DateTime.now().addDays(-1),
            End_Date_and_Time__c = DateTime.now().addDays(1),
            Location__c = 'Dubai'
        );
        insert evt;
        eventId = evt.Id;
    }

    @IsTest
    static void test_getAgencies() {
        setupTestData();

        MBP_ManageEventsandActivities.getAgencies(
            'UAE', 'United Arab Emirates', 'Dubai', eventId
        );

        MBP_ManageEventsandActivities.getAgencies(
            'International', null, null, eventId
        );

        MBP_ManageEventsandActivities.getAgencies(
            null, null, null, eventId
        );
    }

    @IsTest
    static void test_getAssignedAgencies() {
        setupTestData();

        Agency_Mapping__c mapping = new Agency_Mapping__c(
            Event_and_Activity__c = eventId,
            Agency__c = agencyAccountId1,
            Status__c = 'Assigned'
        );
        insert mapping;

        MBP_ManageEventsandActivities.getAssignedAgencies(eventId);
        MBP_ManageEventsandActivities.getAssignedAgencies(null);
    }

    @IsTest
    static void test_getBankCountries() {
        MBP_ManageEventsandActivities.getBankCountries();
    }

    @IsTest
    static void test_getAgencyContactsForEvent() {
        setupTestData();

        MBP_ManageEventsandActivities.ContactRequest req =
            new MBP_ManageEventsandActivities.ContactRequest();
        req.agencyIds = new List<String>{ agencyAccountId1 };
        req.brokerTypes = new List<String>{ 'All' };

        MBP_ManageEventsandActivities.getAgencyContactsForEvent(req);

        req.brokerTypes = new List<String>{ 'Primary' };
        MBP_ManageEventsandActivities.getAgencyContactsForEvent(req);

        MBP_ManageEventsandActivities.getAgencyContactsForEvent(null);
    }

    @IsTest
    static void test_getOrgWideEmailAddresses() {
        MBP_ManageEventsandActivities.getOrgWideEmailAddresses();
    }

    @IsTest
    static void test_assignAgenciesToEvent() {
        setupTestData();

        Test.startTest();

        // Assign
        MBP_ManageEventsandActivities.assignAgenciesToEvent(
            eventId,
            new List<Id>{ agencyAccountId1, agencyAccountId2 }
        );

        // Unassign one
        MBP_ManageEventsandActivities.assignAgenciesToEvent(
            eventId,
            new List<Id>{ agencyAccountId1 }
        );

        // Null handling
        MBP_ManageEventsandActivities.assignAgenciesToEvent(
            null,
            new List<Id>{ agencyAccountId1 }
        );

        Test.stopTest();
    }

    @IsTest
    static void test_getEventsDynamic() {
        setupTestData();

        MBP_ManageEventsandActivities.getEventsDynamic(
            'Today', null, null
        );

        MBP_ManageEventsandActivities.getEventsDynamic(
            'Future', null, null
        );

        MBP_ManageEventsandActivities.getEventsDynamic(
            'Past', null, null
        );

        String startDate = DateTime.now().addDays(-2).formatGMT('yyyy-MM-dd\'T\'HH:mm:ss');
        String endDate   = DateTime.now().addDays(2).formatGMT('yyyy-MM-dd\'T\'HH:mm:ss');

        MBP_ManageEventsandActivities.getEventsDynamic(
            'Range', startDate, endDate
        );

        MBP_ManageEventsandActivities.getEventsDynamic(
            null, null, null
        );
    }
}