@IsTest
private class PassfortIntegrationServiceTest {

    private class SendGridMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(202);
            res.setBody('{"message":"accepted"}');
            return res;
        }
    }

@testSetup
static void setupData() {

    Account acc = new Account(
        Name = 'Test Account',
        ProfileId__c = 'ACC_PROFILE_001'
    );
    insert acc;

    Contact con = new Contact(
        FirstName = 'Test',
        LastName = 'Contact',
        AccountId = acc.Id,
        ProfileId__c = 'CON_PROFILE_001'
    );
    insert con;

    Registration__c reg = new Registration__c();
    reg.put('ProfileId__c', 'REG_PROFILE_001');
    insert reg;

    Map<String, Schema.RecordTypeInfo> srRtMap =
        Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByDeveloperName();

    if (srRtMap.containsKey('Broker_Registration')) {

        ServiceRequest__c sr = new ServiceRequest__c(
            RecordTypeId = srRtMap.get('Broker_Registration').getRecordTypeId(),
            Registration__c = reg.Id
        );
        insert sr;

        Task t = new Task(
            Subject = 'Validation by Compliance Team',
            WhatId = sr.Id,
            Status = 'Not Started',
            Priority = 'Normal'
        );

        t.put('Broker_Registration_Status__c', 'Require More information');
        insert t;
    }
}

    private static PassfortWebhookModel.Webhook buildWebhook(
        String eventName,
        String profileId,
        String newCategory,
        String newStatus
    ){
        PassfortWebhookModel.Webhook webhook = new PassfortWebhookModel.Webhook();
        webhook.event = eventName;

        PassfortWebhookModel.Entity entity = new PassfortWebhookModel.Entity();
        entity.profile_id = profileId;
        entity.new_category = newCategory;
        entity.new_status = newStatus;

        webhook.data = entity;
        return webhook;
    }

    @IsTest
    static void testRiskLevelContact(){

        PassfortWebhookModel.Webhook webhook = buildWebhook(
            'RISK_LEVEL_CHANGED',
            'CON_PROFILE_001',
            'High',
            null
        );

        Test.startTest();
        PassfortIntegrationService.processWebhook(webhook,'REQ1');
        Test.stopTest();
    }

    @IsTest
    static void testRiskLevelAccount(){

        PassfortWebhookModel.Webhook webhook = buildWebhook(
            'RISK_LEVEL_CHANGED',
            'ACC_PROFILE_001',
            'Medium',
            null
        );

        Test.startTest();
        PassfortIntegrationService.processWebhook(webhook,'REQ2');
        Test.stopTest();
    }

    @IsTest
    static void testRiskLevelRegistration(){

        PassfortWebhookModel.Webhook webhook = buildWebhook(
            'RISK_LEVEL_CHANGED',
            'REG_PROFILE_001',
            'Low',
            null
        );

        Test.startTest();
        PassfortIntegrationService.processWebhook(webhook,'REQ3');
        Test.stopTest();
    }

    @IsTest
    static void testProductStatusContact(){

        PassfortWebhookModel.Webhook webhook = buildWebhook(
            'PRODUCT_STATUS_CHANGED',
            'CON_PROFILE_001',
            null,
            'APPROVED'
        );

        Test.startTest();
        PassfortIntegrationService.processWebhook(webhook,'REQ4');
        Test.stopTest();
    }

    @IsTest
    static void testProductStatusRegistrationApproved(){

        Test.setMock(HttpCalloutMock.class,new SendGridMock());

        PassfortWebhookModel.Webhook webhook = buildWebhook(
            'PRODUCT_STATUS_CHANGED',
            'REG_PROFILE_001',
            null,
            'APPROVED'
        );

        Test.startTest();
        PassfortIntegrationService.processWebhook(webhook,'REQ5');
        Test.stopTest();
    }

    @IsTest
    static void testSendBrokerComplianceEmail(){

        Test.setMock(HttpCalloutMock.class,new SendGridMock());

        Registration__c reg =
        [SELECT Id FROM Registration__c WHERE ProfileId__c='REG_PROFILE_001' LIMIT 1];

        Test.startTest();
        PassfortIntegrationService.sendBrokerComplianceEmail(reg.Id,'Approved');
        Test.stopTest();
    }
    /*--------*/
     @IsTest
    static void testRiskLevelAccountNull(){

        PassfortWebhookModel.Webhook webhook = null;

        Test.startTest();
        PassfortIntegrationService.processWebhook(webhook,'REQ2');
        Test.stopTest();
    }
    
    @IsTest
    static void updateBrokerTaskStatusRejected(){

        Id regId = null;
        Test.startTest();
        PassfortIntegrationService.updateBrokerTaskStatus(regId,'REJECTED');
       
        PassfortIntegrationService.updateBrokerTaskStatus(regId,'REJECTED123');
        Test.stopTest();
    }
    
    @IsTest
    static void testprocessWebhookElse(){

        Test.setMock(HttpCalloutMock.class,new SendGridMock());

        PassfortWebhookModel.Webhook webhook = buildWebhook(
            'PRODUCT_STATUS_CHANGED_Test',
            'REG_PROFILE_001',
            null,
            'APPROVED'
        );

        Test.startTest();
        PassfortIntegrationService.processWebhook(webhook,'REQ5');
        Test.stopTest();
    }   
    
  /*  @IsTest
    static void testprocessProductStatusChange2(){

        Account acc567 = new Account(
            Name = 'Bajiraomastani',
            ProfileId__c = 'ACC_PROFILE_00123',
            PassfortApprovalStatus__c = 'APPROVED'
        );
        insert acc567;
        
        Test.setMock(HttpCalloutMock.class,new SendGridMock());

        PassfortWebhookModel.Webhook webhook = buildWebhook(
            'PRODUCT_STATUS_CHANGED',
            'ACC_PROFILE_00123',
            null,
            'APPROVED'
        );

        Test.startTest();
        PassfortIntegrationService.processWebhook(webhook,'REQ6');
        Test.stopTest();
    }   */
    
     @IsTest
    static void testprocessProductStatusChange3(){

        Account acc678 = new Account(
            Name = 'mastaniilakhatyat',
            ProfileId__c = 'ACC_PROFILE_00156',
            PassfortApprovalStatus__c = 'APPROVED'
        );
        insert acc678;
        
        Account testingpinacc = new Account(
            Name = 'kulakarni',
            ProfileId__c = 'ACC_PROFILE_00278',
            PassfortApprovalStatus__c = 'In Review'
        );
        insert testingpinacc;
        
        Test.setMock(HttpCalloutMock.class,new SendGridMock());

        PassfortWebhookModel.Webhook webhook = buildWebhook(
            'PRODUCT_STATUS_CHANGED',
            'ACC_PROFILE_00156',
            null,
            'APPROVED'
        );
        
        PassfortWebhookModel.Webhook webhook2 = buildWebhook(
            'PRODUCT_STATUS_CHANGED',
            'ACC_PROFILE_00278',
            null,
            'Launched'
        );

        Test.startTest();
        PassfortIntegrationService.processWebhook(webhook,'REQ7');
        PassfortIntegrationService.processWebhook(webhook2,'REQ8');
        Test.stopTest();
    }   
    
}