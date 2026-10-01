/**********************************************************************************************************************
* Name               : sendRequestXiboCaseTest                                                                : 
* Created By         : Active Minds Global Solutions Pvt Ltd                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                                      Date            Comment                                                                       
* 1.0           Raghu.Gajjela@activemindsit.com      		29 Jan 2025     Initial Draft  
* 2.0           ravikumar.pasumarthi@activemindsit.com      20 Jan 2026     Changes as per Case Mgmt 2.0
******************************************************************************************************************/
@isTest
public class sendRequestXiboCaseTest {
    
    private static string testCategory = 'Customer Care';
    
    public class MockHttpResponseGenerator implements HttpCalloutMock {
        public HttpResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"data":[{"message":"Survey created: https://survey-link.com/form/123"}]}');
            res.setStatusCode(200);
            return res;
        }
    }
    
    public class MockHttpFailureResponseGenerator implements HttpCalloutMock {
        public HttpResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(401);
            res.setBody('{"error": "Unauthorized"}');
            return res;
        }
    }
    
    @isTest
    static void testCallCaseXIboService_success() {
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        
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

        Opportunity opp = new Opportunity(
            Name = 'VIP Opportunity',
            StageName = 'Discussion In Progress',
            CloseDate = System.Today(),
			AccountId =  vipAccount.Id           
        );
        insert opp;

        Unit__c unit = new Unit__c(Name = 'Error Unit', PlotNo__c = '90/B', UnitClassification__c = 'Apartment', Number_of_Bedrooms__c = '3', Opportunity__c = opp.Id, Status__c = 'Reserved');
        insert unit;
        
        Case testCase = new Case(
            AccountId = testAccountId,
            ContactId = testContactId,
            Status = 'New',
            Subject = 'Test Case',
            Description = 'Test Description',
            channel__c = '800 Modon',
            source__c = '800 Modon',
            Unit__c = unit.Id,
            RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByName().get('Standard').getRecordTypeId(),
            CaseCategory__c = testCategory,
            Resolution_Comments__c = 'Closed with resolution'
        );
        insert testCase;
        
        Test.startTest();
        sendRequestXiboCase.callCaseXIboService(new Set<String>{testCase.Id});
        Test.stopTest();
        
        //Case updatedCase = [SELECT SurveyLink__c FROM Case WHERE Id = :testCase.Id limit 1];
    }
    
    @isTest
    static void testCallCaseXIboService_errorResponse() {
        Test.setMock(HttpCalloutMock.class, new MockHttpFailureResponseGenerator());
        
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
        
        Opportunity opp = new Opportunity(
            Name = 'VIP Opportunity',
            StageName = 'Discussion In Progress',
            CloseDate = System.Today(),
			AccountId =  vipAccount.Id           
        );
        insert opp;
        
        Unit__c unit = new Unit__c(Name = 'Error Unit', PlotNo__c = '90/B', UnitClassification__c = 'Apartment', Number_of_Bedrooms__c = '3', Opportunity__c = opp.Id, Status__c = 'Reserved');
        insert unit;
                
        Case testCase = new Case(
            AccountId = testAccountId,
            ContactId = testContactId,
            channel__c = '800 Modon',
            source__c = '800 Modon',
            Status = 'New',
            Subject = 'Test Case',
            Description = 'Test Description',
            Unit__c = unit.Id,
            RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByName().get('Standard').getRecordTypeId(),
            CaseCategory__c = testCategory,
            Resolution_Comments__c = 'Closed with resolution'
        );
        insert testCase;
        
        Test.startTest();
        sendRequestXiboCase.callCaseXIboService(new Set<String>{testCase.Id});
        Test.stopTest();
    }
}