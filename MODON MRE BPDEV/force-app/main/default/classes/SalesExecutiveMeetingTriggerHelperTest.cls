/**********************************************************************************************************************
* Name               : SalesExecutiveMeetingTriggerHelperTest                                                        
* Description        : Test class for SalesExecutiveMeetingTriggerHelper covering all Follow-Up and Broker logic
* Created By         : Rushi Patel
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Rushi Patel                 02 Sep 2026     Initial Draft           
******************************************************************************************************************/
@isTest
private class SalesExecutiveMeetingTriggerHelperTest {
    
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
    }
    
    @isTest
    static void testClearIrrelevantBrokerFields_ToExisting() {
        Id brokerRtId = Schema.SObjectType.Sales_Executive_Meeting__c.getRecordTypeInfosByDeveloperName().get('Broker').getRecordTypeId();
        
        // Insert a 'New' Broker meeting
        Sales_Executive_Meeting__c meeting = new Sales_Executive_Meeting__c(
            RecordTypeId = brokerRtId,
            Broker_Category__c = 'New',
            Broker_Name__c = 'Test Name',
            Broker_Location__c = 'Test Location'
        );
        insert meeting;
        
        Account acc = [SELECT Id FROM Account LIMIT 1];
        
        Test.startTest();
        // Clear processedIds so the framework doesn't skip the update event in the same transaction
        TriggerHandler.processedIds.clear();
        
        // Update to 'Existing' - providing the lookup to pass validation rules
        meeting.Broker_Category__c = 'Existing';
        meeting.Broker__c = acc.Id; 
        update meeting;
        Test.stopTest();
        
        // Assertions
        Sales_Executive_Meeting__c updatedMeeting = [SELECT Broker_Name__c, Broker_Location__c, Broker__c FROM Sales_Executive_Meeting__c WHERE Id = :meeting.Id];
        System.assertEquals(null, updatedMeeting.Broker_Name__c, 'Broker Name should be automatically cleared by the helper.');
        System.assertEquals(null, updatedMeeting.Broker_Location__c, 'Broker Location should be automatically cleared by the helper.');
        System.assertEquals(acc.Id, updatedMeeting.Broker__c, 'Broker lookup should safely remain.');
    }
    
    @isTest
    static void testClearIrrelevantBrokerFields_ToNew() {
        Id brokerRtId = Schema.SObjectType.Sales_Executive_Meeting__c.getRecordTypeInfosByDeveloperName().get('Broker').getRecordTypeId();
        Account acc = [SELECT Id FROM Account LIMIT 1];
        
        // Insert an 'Existing' Broker meeting
        Sales_Executive_Meeting__c meeting = new Sales_Executive_Meeting__c(
            RecordTypeId = brokerRtId,
            Broker_Category__c = 'Existing',
            Broker__c = acc.Id
        );
        insert meeting;
        
        Test.startTest();
        // Clear processedIds so the framework doesn't skip the update event in the same transaction
        TriggerHandler.processedIds.clear();
        
        // Update to 'New' - providing Name/Location to pass validation rules
        meeting.Broker_Category__c = 'New';
        meeting.Broker_Name__c = 'New Test Name';
        meeting.Broker_Location__c = 'New Test Location';
        update meeting;
        Test.stopTest();
        
        // Assertions
        Sales_Executive_Meeting__c updatedMeeting = [SELECT Broker_Name__c, Broker_Location__c, Broker__c FROM Sales_Executive_Meeting__c WHERE Id = :meeting.Id];
        System.assertEquals(null, updatedMeeting.Broker__c, 'Broker lookup should be automatically cleared by the helper.');
        System.assertEquals('New Test Name', updatedMeeting.Broker_Name__c, 'Broker Name should safely remain.');
    }

    @isTest
    static void testFollowUpTask_Insert_Customer() {
        Id customerRtId = Schema.SObjectType.Sales_Executive_Meeting__c.getRecordTypeInfosByDeveloperName().get('Customer').getRecordTypeId();
        
        Date followUpDate = System.today().addDays(5);
        
        Test.startTest();
        Sales_Executive_Meeting__c meeting = new Sales_Executive_Meeting__c(
            RecordTypeId = customerRtId,
            Follow_up_Date__c = followUpDate
        );
        insert meeting;
        Test.stopTest();
        
        // Assertions
        List<Task> tasks = [SELECT Id, Subject, ActivityDate, ReminderDateTime, IsReminderSet, Status, RecordType.DeveloperName FROM Task WHERE WhatId = :meeting.Id];
        System.assertEquals(1, tasks.size(), 'Exactly one follow-up task should be created on insert.');
        System.assertEquals('Follow up with Customer', tasks[0].Subject, 'Dynamic Subject should match Customer record type.');
        System.assertEquals(followUpDate, tasks[0].ActivityDate, 'Task Activity Date should perfectly match the follow up date.');
        System.assertEquals(true, tasks[0].IsReminderSet, 'Task Reminder should be active.');
        System.assertEquals('Open', tasks[0].Status, 'Task should be completely Open.');
    }
    
    @isTest
    static void testFollowUpTask_Update_DateChanged() {
        Id brokerRtId = Schema.SObjectType.Sales_Executive_Meeting__c.getRecordTypeInfosByDeveloperName().get('Broker').getRecordTypeId();
        Account acc = [SELECT Id FROM Account LIMIT 1];
        
        Date initialDate = System.today().addDays(2);
        Sales_Executive_Meeting__c meeting = new Sales_Executive_Meeting__c(
            RecordTypeId = brokerRtId,
            Broker_Category__c = 'Existing',
            Broker__c = acc.Id,
            Follow_up_Date__c = initialDate
        );
        insert meeting;
        
        // Assert initial task exists
        List<Task> initialTasks = [SELECT Id FROM Task WHERE WhatId = :meeting.Id];
        System.assertEquals(1, initialTasks.size(), 'Initial task should be created successfully.');
        
        Test.startTest();
        // Clear processedIds so the framework doesn't skip the update event in the same transaction
        TriggerHandler.processedIds.clear();
        
        Date newDate = System.today().addDays(10);
        meeting.Follow_up_Date__c = newDate;
        update meeting;
        Test.stopTest();
        
        // Assertions
        List<Task> finalTasks = [SELECT Id, Subject, ActivityDate FROM Task WHERE WhatId = :meeting.Id];
        System.assertEquals(1, finalTasks.size(), 'Should still only have 1 task (dynamically updated, not duplicated!).');
        System.assertEquals('Follow up with Broker', finalTasks[0].Subject, 'Dynamic Subject should recognize Broker record type.');
        System.assertEquals(newDate, finalTasks[0].ActivityDate, 'Task Activity Date should dynamically slide to the new date.');
    }
    
    @isTest
    static void testFollowUpTask_Update_DateCleared() {
        Id customerRtId = Schema.SObjectType.Sales_Executive_Meeting__c.getRecordTypeInfosByDeveloperName().get('Customer').getRecordTypeId();
        
        Sales_Executive_Meeting__c meeting = new Sales_Executive_Meeting__c(
            RecordTypeId = customerRtId,
            Follow_up_Date__c = System.today().addDays(3)
        );
        insert meeting;
        
        Test.startTest();
        // Clear processedIds so the framework doesn't skip the update event in the same transaction
        TriggerHandler.processedIds.clear();
        
        meeting.Follow_up_Date__c = null;
        update meeting;
        Test.stopTest();
        
        // Assertions
        List<Task> tasks = [SELECT Id, Status, Description, IsReminderSet FROM Task WHERE WhatId = :meeting.Id];
        System.assertEquals(1, tasks.size(), 'Task record should remain in the database for auditing.');
        System.assertEquals('Completed', tasks[0].Status, 'Task should be automatically marked as Completed/Closed.');
        System.assertEquals(false, tasks[0].IsReminderSet, 'Task Reminder popup should be safely turned off.');
        System.assert(tasks[0].Description.contains('cancelled'), 'Description should contain the automated system cancellation note.');
    }
}