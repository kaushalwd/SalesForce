@isTest
public class UpdatTaskAssignmentBatch_Test {
         private static final string SERVICE_REQUEST_RT_DEV_NAME_DEFAULT_SR { get { return 'Default_SR'; } }
   
    @testSetup
    static void setupData() {
        // Create a user to assign as original owner
        User u = new User(
            Alias = 'testu',
            Email = 'testuser@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Test User',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id,
            TimeZoneSidKey = 'Asia/Kolkata',
            UserName = 'testuser' + DateTime.now().getTime() + '@example.com'
        );
        insert u;
        
          Id personAccountRT = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();
        Id businessAccountRT = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('OrganizationAccount').getRecordTypeId();
        
        // Create Person Account
        Account personAcc = new Account(
            FirstName = 'Test',
            LastName = 'Person',
            RecordTypeId = personAccountRT,
            PersonEmail = 'testperson@test.com'
        );
        insert personAcc;
        
        // Create Business Account
        Account businessAcc = new Account(
            Name = 'Test Business',
            RecordTypeId = businessAccountRT
        );
        insert businessAcc;
        
        // Create Contact for Business Account
        Contact businessContact = new Contact(
            FirstName = 'Business',
            LastName = 'Contact',
            AccountId = businessAcc.Id,
            Email = 'businesscontact@test.com',
            Is_Active__c = true
        );
        insert businessContact;
        
        // Create a Sales Order (if required by triggers)
        salesorder__c so = new salesorder__c(
            Status__c = 'Sold',
            CustomerAccount__c = personAcc.Id // Link to person account
        );
        insert so;
        
        // Create another Sales Order for business account
        salesorder__c businessSO = new salesorder__c(
            Status__c = 'Sold',
            CustomerAccount__c = businessAcc.Id // Link to business account
        );
        insert businessSO;
        
        // Get RecordTypeIds
        Id defautRecTypeId = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByDeveloperName().get(SERVICE_REQUEST_RT_DEV_NAME_DEFAULT_SR).getRecordTypeId();
         // Id taskRecordTypeId = Schema.SObjectType.Task.getRecordTypeInfosByDeveloperName().get('Service_Request').getRecordTypeId();
        
        // Insert AssignmentRule__c for ADM_SR_Assignment logic
        AssignmentRule__c asr = new AssignmentRule__c(
            IsActive__c = true,
            Recordtype__C = 'service Request',
            ProcessName__c = 'ADM',
            ProcessType__c = 'Sales'
        );
        insert asr;
        
         ServiceRequest__c srAdm = new ServiceRequest__c(
            RecordTypeId = defautRecTypeId,
            SalesOrder__c = so.Id,
            Status__c = 'New'
         );
        
        insert sradm;

        // Create a task that matches criteria
        Task t = new Task(
             Subject = 'CM Manager to send Default Notice 2',
            ActivityDate = Date.today(),
            OwnerId = u.Id,Order__c=2,
            Status = 'Not Started',WhatId =srAdm.Id 
        );
        insert t;
    }
    
    @isTest
    static void testBatchExecution() {
      
        // Run batch
        Test.startTest();
        Database.executeBatch(new UpdatTaskAssignmentBatch(), 1);
        Test.stopTest();
        
     
    }
    
    @isTest
    static void testSchedulableExecution() {
        Test.startTest();
        // Call schedulable execute
        System.schedule('Test Schedule', '0 0 1 * * ?', new UpdatTaskAssignmentBatch());
        Test.stopTest();
        
        // Assert something scheduled
        CronTrigger ct = [SELECT Id, CronExpression, TimesTriggered, NextFireTime
                          FROM CronTrigger WHERE CronJobDetail.Name = 'Test Schedule' LIMIT 1];
        System.assertNotEquals(null, ct, 'Schedule should exist');
    }
    
    @isTest
    static void testScheduleDailyRunMethod() {
        Test.startTest();
        UpdatTaskAssignmentBatch.scheduleDailyRun();
        Test.stopTest();
        
        // Assert scheduled job exists
        CronTrigger ct = [SELECT Id, CronExpression FROM CronTrigger 
                          WHERE CronJobDetail.Name = 'Daily Task Assignment Batch' LIMIT 1];
        System.assertEquals('0 0 2 * * ?', ct.CronExpression, 
            'Cron expression should match the scheduled daily run');
    }
}