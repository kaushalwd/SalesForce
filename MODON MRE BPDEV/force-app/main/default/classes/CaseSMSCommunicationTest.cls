@isTest
public class CaseSMSCommunicationTest {

    private class MockCallout implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('[{"MessageId":"TEST-SMS-001","Status":"sent"}]');
            res.setStatusCode(200);
            return res;
        }
    }

    static Map<String, Id> getTestIds() {
        Map<String, Id> ids = new Map<String, Id>();
        ids.put('modonTestUser', [SELECT Id FROM User WHERE LastName = 'CallCenterUser' AND IsActive = true LIMIT 1].Id);
        ids.put('vipOrganizationAccount', [SELECT Id FROM Account WHERE Name = 'AccountVIP' LIMIT 1].Id);
        ids.put('vipOrganizationcontact', [SELECT Id FROM Contact WHERE LastName = 'Contact' AND Account.Name = 'AccountVIP' LIMIT 1].Id);
        ids.put('Unit', [SELECT Id FROM Unit__c WHERE PlotNo__c = '105' LIMIT 1].Id);
        return ids;
    }

    @TestSetup
    static void setupData() {
        TestDataFactory.createTestData();
        Map<String, Id> ids = getTestIds();

        CaseTriggerHandler.isTriggerDisabled = true;

        List<Case> casesToInsert = new List<Case>();

        casesToInsert.add(new Case(
            RunningTestClass__c = true,
            AccountId = ids.get('vipOrganizationAccount'),
            ContactId = ids.get('vipOrganizationcontact'),
            Status = 'In Progress',
            Customer_Type__c = ServiceConstants.CASE_CUSTOMER_TYPE_OWNER,
            Customer_Phone__c = '+971888999654',
            Customer_Name__c = 'SMS Test Owner',
            CaseCategory__c = 'General Enquiry',
            CaseSubCategory__c = 'Office Location/Working Hours',
            Unit__c = ids.get('Unit'),
            New_Owner__c = ids.get('modonTestUser')
        ));

        casesToInsert.add(new Case(
            RunningTestClass__c = true,
            Status = 'In Progress',
            Customer_Type__c = ServiceConstants.CASE_CUSTOMER_TYPE_VISITOR,
            Visitor_Phone__c = '+971507654321',
            Visitor_First_Name__c = 'SMS Test Visitor',
            CaseCategory__c = 'General Enquiry',
            CaseSubCategory__c = 'Office Location/Working Hours',
            Unit__c = ids.get('Unit'),
            Visitor_Last_Name__c = 'Jambal',
            New_Owner__c = ids.get('modonTestUser')
        ));

        casesToInsert.add(new Case(
            RunningTestClass__c = true,
            AccountId = ids.get('vipOrganizationAccount'),
            Status = 'In Progress',
            Customer_Type__c = ServiceConstants.CASE_CUSTOMER_TYPE_OWNER,
            Customer_Name__c = 'SMS No Phone Owner',
            CaseCategory__c = 'General Enquiry',
            CaseSubCategory__c = 'Office Location/Working Hours',
            Visitor_Last_Name__c = 'Bak',
            Visitor_Phone__c = '+919885370070',
            Unit__c = ids.get('Unit'),
            New_Owner__c = ids.get('modonTestUser')
        ));

        insert casesToInsert;

        CaseTriggerHandler.isTriggerDisabled = false;
    }

    @isTest
    static void testOwnerCase() {
        List<Case> cases = [
            SELECT Id, CaseNumber, Customer_Type__c,
                   Customer_Phone__c, Customer_Name__c,
                   Visitor_Phone__c, Visitor_First_Name__c
            FROM Case
            WHERE Customer_Name__c = 'SMS Test Owner'
            LIMIT 1
        ];
        Test.setMock(HttpCalloutMock.class, new MockCallout());
        Test.startTest();
        System.enqueueJob(new CaseSmsCommunication(cases));
        Test.stopTest();
    }

    @isTest
    static void testVisitorCase() {
        List<Case> cases = [
            SELECT Id, CaseNumber, Customer_Type__c,
                   Customer_Phone__c, Customer_Name__c,
                   Visitor_Phone__c, Visitor_First_Name__c
            FROM Case
            WHERE Visitor_First_Name__c = 'SMS Test Visitor'
            LIMIT 1
        ];
        Test.setMock(HttpCalloutMock.class, new MockCallout());
        Test.startTest();
        System.enqueueJob(new CaseSmsCommunication(cases));
        Test.stopTest();
    }

    @isTest
    static void testNoPhoneCase() {
        List<Case> cases = [
            SELECT Id, CaseNumber, Customer_Type__c,
                   Customer_Phone__c, Customer_Name__c,
                   Visitor_Phone__c, Visitor_First_Name__c
            FROM Case
            WHERE Customer_Name__c = 'SMS No Phone Owner'
            LIMIT 1
        ];
        Test.setMock(HttpCalloutMock.class, new MockCallout());
        Test.startTest();
        System.enqueueJob(new CaseSmsCommunication(cases));
        Test.stopTest();
    }

    @isTest
    static void testMixedCases() {
        List<Case> cases = [
            SELECT Id, CaseNumber, Customer_Type__c,
                   Customer_Phone__c, Customer_Name__c,
                   Visitor_Phone__c, Visitor_First_Name__c
            FROM Case
            WHERE Customer_Name__c IN ('SMS Test Owner', 'SMS No Phone Owner')
            OR Visitor_First_Name__c = 'SMS Test Visitor'
        ];
        Test.setMock(HttpCalloutMock.class, new MockCallout());
        Test.startTest();
        System.enqueueJob(new CaseSmsCommunication(cases));
        Test.stopTest();
    }

    @isTest
    static void testEmptyList() {
        Test.setMock(HttpCalloutMock.class, new MockCallout());
        Test.startTest();
        System.enqueueJob(new CaseSmsCommunication(new List<Case>()));
        Test.stopTest();
    }

    @isTest
    static void testNullList() {
        Test.setMock(HttpCalloutMock.class, new MockCallout());
        Test.startTest();
        System.enqueueJob(new CaseSmsCommunication(null));
        Test.stopTest();
    }
}