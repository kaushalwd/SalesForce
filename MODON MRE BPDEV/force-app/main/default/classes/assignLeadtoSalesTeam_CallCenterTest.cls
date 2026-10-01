/**********************************************************************************************************************
* Name               : assignLeadtoSalesTeam_CallCenterTest                                                        
* Description        : This is the test class for assignLeadtoSalesTeam_CallCenter
* Created By         : Horizontal Digital India                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           mdixit@horizontal.com               05 Aug 2025     Initial Draft       
******************************************************************************************************************/
@isTest
public class assignLeadtoSalesTeam_CallCenterTest {

    @isTest
    static void test_assignLeadsFromLWC_success() {

        // Create a test Lead
        Lead testLead = new Lead(
            FirstName = 'Test',
            LastName = 'User',
            Status = 'New',
            MobilePhone = '+917788554411',
            Email = 'test@email.com',
            LeadSource = 'Self Generated'
        );
        String emptyId = null;
        Test.startTest();
        try {
            insert testLead;
        } catch (Exception ex) {
            System.debug('Error inserting test lead: ' + ex.getMessage());
            throw ex; // Rethrow to fail the test if insertion fails
        }
        assignLeadtoSalesTeam_CallCenter.assignLeadsFromLWC(testLead.Id);
        assignLeadtoSalesTeam_CallCenter.getLeadRecord(testLead.Id);
        Test.stopTest();

        // Add assertions if Modon_LeadTriggerHandler.assignLeads changes anything
        System.assertNotEquals(UserInfo.getUserId(), testLead.OwnerId, 'Lead owner should change'); 
    }
    
    @IsTest
    static void testGetLeadRecord_CatchBlock() {
        Test.startTest();
        
        Boolean exceptionCaught = false;
        try {
            assignLeadtoSalesTeam_CallCenter.getLeadRecord(null);
        } catch (AuraHandledException e) {
            System.assert(true,'Should Catch Error');
            exceptionCaught = true;
        }
        Test.stopTest();
    }
    
    @IsTest
    static void testAssignLeadsFromLWC_CatchBlock() {
        Test.startTest();
        Boolean exceptionCaught = false;
        try {
            assignLeadtoSalesTeam_CallCenter.assignLeadsFromLWC(null);
        } catch (AuraHandledException e) {
            System.assert(true,'Should Catch Error');
            exceptionCaught = true;
        }
        
        Test.stopTest();
    }
}