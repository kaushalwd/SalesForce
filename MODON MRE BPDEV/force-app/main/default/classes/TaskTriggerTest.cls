@isTest
public class TaskTriggerTest {
    @isTest
    static void testExceptionHandling() {
        // Create test data
        Account testAccount = new Account(Name = 'Test Account');
        insert testAccount;

        Task testTask = new Task(
            Subject = 'Test Task',
            WhatId = testAccount.Id
        );


        testTask.addError('Simulate an issue');

        Test.startTest();
        try {
            insert testTask;
        } catch (Exception e) {
        }
        Test.stopTest();
        List<ApexLog> logs = [SELECT Id FROM ApexLog WHERE Application = 'TaskTriggerHandler' LIMIT 1];

    }
}