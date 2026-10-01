@isTest
public class sendRequestToXiboApiTest {

    private class MockXiboApiResponse implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            res.setBody('{"data":[{"message": "Survey created: https://example.com/survey/456"}]}');
            return res;
        }
    }

    @isTest
    static void testCaseSurveyCalloutSuccess() {
        Test.setMock(HttpCalloutMock.class, new MockXiboApiResponse());

               Unit__c unit = new Unit__c(Name = 'Test Unit', PlotNo__c = '80/A', UnitClassification__c = 'Villa', Number_of_Bedrooms__c = '6');
        insert unit;

        Map<String, Id> testData = TestDataFactory.createTestData();
        Id mgrId = testData.get('FrontLinerUser1');
            Id testAccountId = testData.get('vipOrganizationAccount');
    		Id testContactId = testData.get('vipOrganizationcontact');
        
        Account vipAccount = new Account(
            Name = 'VIP Account',
            CustomerType__c = 'VIP Client',
            Source_Entity__c = 'Modon - Egypt',
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Organization Account').getRecordTypeId(),
            Account_Manager__c = mgrId
        );
        insert vipAccount;
        
       Case testCase = new Case(
           	AccountId = testAccountId,
           ContactId = testContactId,
            Status = 'Closed with Resolution',
            Subject = 'Test Case',
            Description = 'Test Description',
            //Customer_Email__c = 'test@example.com',
            Unit__c = unit.Id,
            RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByName().get('Service Cases').getRecordTypeId(),
            CaseCategory__c = 'Contact Centre',
        	CaseSubCategory__c = 'General Enquiry',
            Resolution_Comments__c = 'Closed with resolution'
            //Requestor_Name__c = 'Test case',
            //Requestor_Phone__c = '+971567898789'
        );
        insert testCase;

        Test.startTest();
        sendRequestToXiboApi.getSurvey_Future(new Set<String>{testCase.Id}, 'Case');
        Test.stopTest();

        Case result = [SELECT SurveyLink__c FROM Case WHERE Id = :testCase.Id];
        }

    @isTest
    static void testServiceRequestSurveyCalloutSuccess() {
        Test.setMock(HttpCalloutMock.class, new MockXiboApiResponse());
       Id personAccountRT = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();
        // Setup Person Account
        Account acc = new Account(FirstName = 'Jane', LastName = 'Doe', RecordTypeId = personAccountRT, PersonEmail = 'jane@example.com');
        insert acc;

        // Insert Unit
        Unit__c unit = new Unit__c(Name = 'SR-Unit', PlotNo__c = 'SR-201', UnitClassification__c = 'Townhouse', Number_of_Bedrooms__c = '4');
        insert unit;

        // Create Sales Order
        SalesOrder__c so = new SalesOrder__c(CustomerAccount__c = acc.Id, Status__c = 'Sold');
        insert so;

        // Get RecordType for SR
        Id srRTId = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByDeveloperName().get('Service_Request_Management_ADM').getRecordTypeId();

        // Create Service Request
        ServiceRequest__c sr = new ServiceRequest__c(
            //AccountId__c = acc.Id,
            UnitId__c = unit.Id,
            RecordTypeId = srRTId,
            SalesOrder__c = so.Id,
            SurveyLink__c = 'initial'
        );
        insert sr;

        Test.startTest();
        sendRequestToXiboApi.getSurvey_Future(new Set<String>{sr.Id}, 'ServiceRequest__c');
        sendRequestToXiboApi.getSurvey_Future(new Set<String>{sr.Id}, 'SalesOrder__c');
        Test.stopTest();

        ServiceRequest__c result = [SELECT SurveyLink__c FROM ServiceRequest__c WHERE Id = :sr.Id];
    }
}