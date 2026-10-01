/**********************************************************************************************************************
* Name               : UAEPassAutoLinkRuleTriggerTest                                                        
* Description        : Test class for UAEPassAutoLinkRuleTrigger, Handler, and Helper
* Created By         : Suresh                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh                  05 08 2026     Initial Draft       
******************************************************************************************************************/
@isTest
private class UAEPassAutoLinkRuleTriggerTest {

    @testSetup
    static void setupTestData() {
        Contact testContact = new Contact(
            FirstName = 'Suresh',
            LastName = 'Modon',
            Email = 'suresh.salesforce@modon.ae'
        );
        insert testContact;
    }

    @isTest
    static void testAfterInsertWithEmailMismatch() {
        Contact con = [SELECT Id, Email FROM Contact LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());

        Test.startTest();
        UAEPassAutoLinkRule__c newRule = new UAEPassAutoLinkRule__c(
            Contact__c = con.Id,
            Email__c = 'mismatch@modon.ae',
            EIDNumber__c = '784202612345678'
        );
        insert newRule;
        Test.stopTest();
    }

    @isTest
    static void testAfterUpdateWithEmailChange() {
        Contact con = [SELECT Id, Email FROM Contact LIMIT 1];
        UAEPassAutoLinkRule__c matchingRule = new UAEPassAutoLinkRule__c(
            Contact__c = con.Id,
            Email__c = con.Email,
            EIDNumber__c = '784202612345678'
        );
        insert matchingRule;
    
        UAEPassAutoLinkRule__c oldRecord = matchingRule.clone(true, true, false, false);
    
        matchingRule.Email__c = 'updated.mismatch@modon.ae';
    
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
    
        Test.startTest();
        Map<Id, UAEPassAutoLinkRule__c> oldMap = new Map<Id, UAEPassAutoLinkRule__c>();
        oldMap.put(oldRecord.Id, oldRecord);
    
        UAEPassAutoLinkRuleTriggerHelper.sendEmailMessage(
            new List<UAEPassAutoLinkRule__c>{ matchingRule }, 
            oldMap
        );
        Test.stopTest();
    }

    @isTest
    static void testAfterUpdateWithEmailChangeAnother() {
        Contact con = [SELECT Id, Email FROM Contact LIMIT 1];
        UAEPassAutoLinkRule__c matchingRule = new UAEPassAutoLinkRule__c(
            Contact__c = con.Id,
            Email__c = con.Email,
            EIDNumber__c = '784202612345678'
        );
        insert matchingRule;
    
        matchingRule.Email__c = 'updated.mismatch@modon.ae';
    
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
    
        Test.startTest();
        update matchingRule;
        Test.stopTest();
    }
    
    @isTest
    static void testNoEmailMismatchPath() {
        Contact con = [SELECT Id, Email FROM Contact LIMIT 1];
		Test.setMock(HttpCalloutMock.class, new MockHttpResponseGenerator());
        Test.startTest();
        UAEPassAutoLinkRule__c perfectMatchRule = new UAEPassAutoLinkRule__c(
            Contact__c = con.Id,
            Email__c = 'HelloooTest@modon.com',
            EIDNumber__c = '784202612345678'
        );
        insert perfectMatchRule;
        Test.stopTest();
    }

    private class MockHttpResponseGenerator implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"message":"success"}');
            res.setStatusCode(200);
            return res;
        }
    }
}