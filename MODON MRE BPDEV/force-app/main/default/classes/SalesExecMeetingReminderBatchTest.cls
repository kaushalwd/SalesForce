/**********************************************************************************************************************
* Name               : SalesExecMeetingReminderBatchTest                                                        
* Description        : Test class for SalesExecMeetingReminderBatch
* Created By         : Rushi Patel - Horizontal Digital                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Rushi Patel                 03 Sep 2026     Initial draft 
******************************************************************************************************************/
@isTest
private class SalesExecMeetingReminderBatchTest {

    @TestSetup
    static void setupData() {
        // Fetch the Broker_Agency record type ID for Account to bypass lookup filters
        Id brokerAgencyRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Broker_Agency').getRecordTypeId();
        
        // Create an Account to be used as a Broker
        Account brokerAcc = new Account(
            Name = 'Test Broker Account',
            RecordTypeId = brokerAgencyRtId
        );
        insert brokerAcc;
        
        // Get the Broker Record Type ID
        Id brokerRtId = Schema.SObjectType.Sales_Executive_Meeting__c.getRecordTypeInfosByDeveloperName().get('Broker').getRecordTypeId();

        Sales_Executive_Meeting__c meeting = new Sales_Executive_Meeting__c(
            RecordTypeId = brokerRtId,
            Broker_Category__c = 'Existing',
            Broker__c = brokerAcc.Id
        );
        insert meeting;
        
        // Create an open task attached to the meeting with ActivityDate = TODAY
        Task t = new Task(
            WhatId = meeting.Id,
            Subject = 'Follow up with Broker',
            ActivityDate = System.today(),
            Status = 'Open',
            Description = 'Test Description'
        );
        insert t;
    }

    @isTest
    static void testBatchExecution() {
        Test.startTest();
        SalesExecMeetingReminderBatch batch = new SalesExecMeetingReminderBatch();
        Database.executeBatch(batch);
        Test.stopTest();
        
        // Verify batch ran successfully
        AsyncApexJob job = [SELECT Id, Status, NumberOfErrors FROM AsyncApexJob WHERE JobType = 'BatchApex' LIMIT 1];
        System.assertEquals('Completed', job.Status, 'Batch should complete successfully');
        System.assertEquals(0, job.NumberOfErrors, 'Batch should have no errors');
    }
}