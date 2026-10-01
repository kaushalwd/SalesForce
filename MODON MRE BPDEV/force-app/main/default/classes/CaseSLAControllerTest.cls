/**********************************************************************************************************************
* Name               : CaseSLAControllerTest                                                                : 
* Created By         : Active Minds Global Solutions Pvt Ltd                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                                      Date            Comment                                                                       
* 1.0           Raghu.Gajjela@activemindsit.com             29 Jan 2025     Initial Draft     
* 2.0           ravikumar.pasumarthi@activemindsit.com      20 Jan 2026     Changes as per Case Mgmt 2.0
******************************************************************************************************************/
@IsTest
public class CaseSLAControllerTest {
    
    @isTest
    Public static void testGetCaseDetails() {
        // Retrieve the Case record from TestDataFactory
        Map<String, Id> testData = TestDataFactory.createTestData();
        Id caseId = testData.get('TestCase');
        Id ownerId = testData.get('modonTestUser'); // Ensure this user exists //2.0
        
        CaseSLA__c testSLA = new CaseSLA__c(
            CaseId__c = caseId,
            CaseOwner__c = ownerId, 
            Status__c = 'OnTrack'
        );
        insert testSLA;
        
        System.debug('Inserted SLA Record: ' + testSLA.Id);
        
        Test.startTest();
        CaseSLA__c result = CaseSLAController.getCaseDetails(caseId);
        Test.stopTest();
        
        System.debug('Retrieved SLA Record: ' + result);
        
        // Assert the returned CaseSLA__c record is not null
        System.assertNotEquals(null, result, 'CaseSLA__c record should not be null.');
        
        // Assert the values in the returned record
        System.assertEquals(caseId, result.CaseId__c, 'The Case ID should match.');
        System.assertEquals(ownerId, result.CaseOwner__c, 'The Case Owner should match.');
        System.assertEquals('OnTrack', result.Status__c, 'The status should match.');
    }
    
    // Test case for no CaseSLA__c records found
    @isTest
    Public static void testGetCaseDetails_NoSLARecord() {
        // Retrieve a Data from TestDataFactory
        Map<String, Id> testData = TestDataFactory.createTestData();
        Id ownerId = testData.get('modonTestUser'); // Ensure this user exists //2.0
         Id caseId = testData.get('TestCase');
        
        // Call the method under test
        Test.startTest();
        CaseSLA__c result = CaseSLAController.getCaseDetails(caseId);
        Test.stopTest();
        
        System.debug('Retrieved SLA Record: ' + result);
        
        // Assert that the result is null as there is no associated CaseSLA__c record
        System.assertEquals(null, result, 'The result should be null when no CaseSLA__c record is found.');
    }
    
}