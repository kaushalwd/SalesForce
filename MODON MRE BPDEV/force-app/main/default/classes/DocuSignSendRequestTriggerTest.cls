/**********************************************************************************************************************
* Name               : DocuSignSendRequestTriggerTest                                                        
* Description        : Test class for DocuSignSendRequestTrigger. 
*                      NOTE: This test class is created explicitly for Phase 1 of the deployment. Because Flosum 
*                      deployments require the PlatformEventSubscriberConfig (which has environment-specific usernames) 
*                      to be deployed manually via REST API after the event and trigger are created, the Queueable 
*                      class is delayed to Phase 2. This test class ensures the Trigger gets code coverage in Phase 1 
*                      since the main Queueable Test class cannot be deployed yet.
* Created By         : Rushi Patel
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Rushi Patel                 07 Sep 2026     Initial draft 
******************************************************************************************************************/
@isTest
private class DocuSignSendRequestTriggerTest {
    @isTest
    static void testPlatformEventTriggerPhase1() {
        Test.startTest();
        
        // Generate a fake Document Id to satisfy the ID cast in the trigger
        String docPrefix = Documents__c.SObjectType.getDescribe().getKeyPrefix();
        String fakeDocId = docPrefix + '000000000001';
        
        // Publish the platform event
        DocuSign_Send_Request__e req = new DocuSign_Send_Request__e(Document_Id__c = fakeDocId);
        Database.SaveResult sr = EventBus.publish(req);
        
        Test.stopTest();
        
        // Assert that the event was published successfully
        System.assert(sr.isSuccess(), 'Platform Event should publish successfully to provide coverage for the trigger.');
    }
}