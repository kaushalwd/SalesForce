@isTest
private class ServiceRequestCheckerTest {

    // ------------------ CREATE USER ------------------
    private static User createUser() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];

        User u = new User(
            FirstName = 'Test',
            LastName = 'User',
            Email = 'testuser@example.com',
            Username = 'testuser' + System.currentTimeMillis() + '@example.com',
            Alias = 'tuser',
            TimeZoneSidKey = 'GMT',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );
        insert u;
        return u;
    }

    // ------------------ TEST DATA ------------------
    @testSetup
    static void setupData() {

        // ONLY non-setup objects here
        Account acc = new Account(
            Name = 'Test Account',
            Bank_Name__c = 'HDFC',
            Bank_Account_Number__c = '123456',
            IBAN_Number__c = 'IBAN1231234567876765678'
        );
        insert acc;

        SalesOrder__c so = new SalesOrder__c(
            CustomerAccount__c = acc.Id,
            Status__c = 'Completed'
        );
        insert so;

        ServiceRequest__c sr = new ServiceRequest__c(
            SalesOrder__c = so.Id,
            Status__c = 'New'
        );
        insert sr;

        // ADM SR
        Id admRtId = Schema.SObjectType.ServiceRequest__c
            .getRecordTypeInfosByDeveloperName()
            .get('Service_Request_Management_ADM')
            .getRecordTypeId();

        insert new ServiceRequest__c(
            SalesOrder__c = so.Id,
            RecordTypeId = admRtId,
            Status__c = 'New'
        );

        insert new DirectDebitRequest__c(
            SalesOrder__c = so.Id,
            IsActive__c = true
        );

        insert new Task(
            WhatId = sr.Id,
            Subject = 'Test Task',
            Status = 'Not Started'
        );
    }

    // ------------------ QUEUE SETUP (SAFE) ------------------
    private static Id createQueue(User u) {

        System.runAs(u) {

            Group q = new Group(
                Name = 'SR Test Queue',
                DeveloperName = 'SR_Test_Queue',
                Type = 'Queue'
            );
            insert q;

            insert new QueueSobject(
                QueueId = q.Id,
                SobjectType = 'ServiceRequest__c'
            );

            return q.Id;
        }

        return null;
    }

    // ------------------ ADM ------------------
    @isTest
    static void test_hasADMRegistration() {

        ServiceRequest__c sr = [SELECT Id FROM ServiceRequest__c LIMIT 1];

        Test.startTest();
        ServiceRequestChecker.hasADMRegistration(sr.Id);
        ServiceRequestChecker.hasADMRegistration(null);
        Test.stopTest();
    }

    // ------------------ DIRECT DEBIT ------------------
    @isTest
    static void test_checkDirectDebitStatus() {

        ServiceRequest__c sr = [SELECT Id FROM ServiceRequest__c LIMIT 1];

        Test.startTest();
        ServiceRequestChecker.checkDirectDebitStatus(sr.Id);
        ServiceRequestChecker.checkDirectDebitStatus(null);
        Test.stopTest();
    }

    // ------------------ BANK DETAILS ------------------
    @isTest
    static void test_getBankDetails() {

        ServiceRequest__c sr = [SELECT Id FROM ServiceRequest__c LIMIT 1];

        Test.startTest();
        ServiceRequestChecker.getBankDetails(sr.Id);
        ServiceRequestChecker.getBankDetails(null);
        Test.stopTest();
    }

    // ------------------ ASSIGN TASKS ------------------
    @isTest
    static void test_assignTasks() {

        User u = createUser();
        Id queueId = createQueue(u);

        ServiceRequest__c sr = [SELECT Id FROM ServiceRequest__c LIMIT 1];

        // Assign SR to queue
        sr.OwnerId = queueId;
        update sr;

        Test.startTest();
        ServiceRequestChecker.assignTasks(sr.Id);
        Test.stopTest();
    }

    // ------------------ EXCEPTION ------------------
    @isTest
    static void test_assignTasks_exception() {

        Test.startTest();

        try {
            ServiceRequestChecker.assignTasks(null);
        } catch (Exception e) {
        }

        Test.stopTest();
    }
}