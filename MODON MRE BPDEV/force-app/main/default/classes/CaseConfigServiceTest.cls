/**********************************************************************************************************************
* Name               : CaseConfigServiceTest                                                                : 
* Created By         : Active Minds Global Solutions Pvt Ltd                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                                      Date            Comment                                                                       
* 1.0           Raghu.Gajjela@activemindsit.com      		29 Jan 2025     Initial Draft  
* 2.0           ravikumar.pasumarthi@activemindsit.com      20 Jan 2026     Changes as per Case Mgmt 2.0
******************************************************************************************************************/
@IsTest
private class CaseConfigServiceTest {
    
    //private static string testCategory = 'Leasing Enquiry';
    
    private static Id getCaseRecordType() {
        return [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Case'
            AND DeveloperName = 'Standard'
            LIMIT 1
        ].Id;
    }
    
    @IsTest //(seeAllData=true)
    static void testApplyCategoryConfig() {
        // Make sure you have a Case_Config__mdt record in org:
        // Master Label = 'General Inquiry' (example)
        
        Id caseRtId = getCaseRecordType();
        
        Map<String, Id> testData = TestDataFactory.createTestData();
        Account personAccount = [
            SELECT Id, EIDNumber__pc, Phone, PersonEmail,Account_Manager__c, Name
            FROM Account 
            WHERE Id = :testData.get('vipPersonAccount') 
            LIMIT 1];
            
        Case c2 = new Case(
            RecordTypeId = caseRtId,
            Channel__c = '800 Modon',
            AccountId = personAccount.Id,
            Status = 'New',
            CaseCategory__c = 'General Enquiry',
            CaseSubCategory__c = 'Office Location/Working Hours',
            unit__c = testData.get('Unit')
        );
        insert c2;
        
        c2 = [SELECT Id, CaseCategory__c, Department__c, Organization__c,
              Vertical__c, Sub_Vertical__c
              FROM Case
              WHERE Id = :c2.Id];        
    }
}