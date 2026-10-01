/**********************************************************************************************************************
* Name               : CaseSLAStatusBreachedTest                                                                : 
* Created By         : Active Minds Global Solutions Pvt Ltd                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                                      Date            Comment                                                                       
* 1.0           Raghu.Gajjela@activemindsit.com      	30 Jan 2025     Initial Draft          
******************************************************************************************************************/

@isTest
public class CaseSLAStatusBreachedTest {
    @isTest
    Public static void testexecute(){
        // Retrive Data from TestDataFactory
        Map<String, Id> testData = TestDataFactory.createTestData();
        Id caseId = testData.get('TestCase');
        
        // Create CaseSLA__c records
        List<CaseSLA__c> slaRecords = new List<CaseSLA__c>();
        
        
        CaseSLA__c sla1 = new CaseSLA__c(
            CaseId__c = caseId,
            Status__c = 'OnTrack', 
            DueTime__c = System.now().addDays(1) 
        );
        slaRecords.add(sla1);
        
        
        CaseSLA__c sla2 = new CaseSLA__c(
            CaseId__c = caseId,
            Status__c = 'OnTrack', 
            DueTime__c = System.now().addHours(-1) // Past time (breached)
        );
        slaRecords.add(sla2);
        
        insert slaRecords;
        
        System.assertEquals(2, slaRecords.size(), 'Two SLA records should be inserted.');
        
        // Test Execution
        Test.startTest();
        CaseSLAStatusBreached scheduler = new CaseSLAStatusBreached();
        scheduler.execute(null); // Simulating Scheduled Job Execution
        Test.stopTest();
        
        // Fetch updated SLA records
        List<CaseSLA__c> updatedSLAs = [SELECT Id, Status__c,DueTime__c, IsViolated__c FROM CaseSLA__c WHERE Id IN :slaRecords];
        
        for (CaseSLA__c sla : updatedSLAs) {
            if (sla.DueTime__c < System.now()) {
                System.assertEquals('Breached', sla.Status__c, 'SLA should be breached.');
                System.assertEquals(true, sla.IsViolated__c, 'SLA IsViolated should be true.');
            } else {
                System.assertEquals('OnTrack', sla.Status__c, 'SLA should still be in OnTrack.');
                System.assertEquals(false, sla.IsViolated__c, 'SLA IsViolated should be false.');
            }
        }
    }  
}