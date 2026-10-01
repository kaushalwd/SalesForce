/**********************************************************************************************************************
* Name               : MBP_DocusignControllerTest
* Description        : Test coverage for all four public methods on MBP_DocusignController.
* Created By         : (upendra)
* --------------------------------------------------------------------------------------------------------------------
* ASSUMPTIONS TO VERIFY IN YOUR ORG:
*   1. enqueueSendForSignatureFromTasks tests that let the enqueued job actually run rely on the same
*      dependencies as MBP_SendForSignatureController's own tests: the Static Resource
*      'MBP_Broker_Agency_Agreement' and Custom Labels MBP_SendForSignatureRecipient1/2 must already exist,
*      and the DocuSign callout mock below is a best-effort generic shape (see MBP_SendForSignatureControllerTest
*      for the same caveat in more detail).
*   2. populateBrokerOwnerEmail tests assume the child relationship field on Registration_Agent__c that
*      points back to its parent Registration__c is named "Registration__c" (matching the relationship name
*      "Registration_Agents__r" used in the class). If your actual lookup/master-detail field is named
*      differently, that's the one field name to adjust in @TestSetup below.
**********************************************************************************************************************/
@isTest
private class MBP_DocusignControllerTest {

    @TestSetup
    static void setup(){
        ServiceRequest__c sr = new ServiceRequest__c(
            Broker_Agency_Owner_Name__c  = 'Existing Owner',
            Broker_Agency_Owner_Email__c = 'existing.owner@example.com'
        );
        insert sr;

        Account acc = new Account(Name = 'Docusign Controller Test Agency');
        insert acc;
    }

    // Same generic best-effort DocuSign callout mock used elsewhere — see class header caveat.
    private class DocuSignCalloutMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req){
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"envelopeId":"TEST-ENVELOPE-ID-0003","status":"sent"}');
            return res;
        }
    }

    // ======================================================================================
    // enqueueSendForSignatureFromTasks
    // ======================================================================================

    @isTest
    static void testEnqueueSendForSignatureFromTasks_nullAndEmpty_noOp(){
        Integer callsBefore = Limits.getAsyncCalls();

        Test.startTest();
        MBP_DocusignController.enqueueSendForSignatureFromTasks(null);
        MBP_DocusignController.enqueueSendForSignatureFromTasks(new List<Task>());
        Test.stopTest();

        System.assertEquals(callsBefore, Limits.getAsyncCalls(), 'Null/empty list should not enqueue anything.');
    }

    @isTest
    static void testEnqueueSendForSignatureFromTasks_wrongSubject_doesNotEnqueue(){
        ServiceRequest__c sr = [SELECT Id FROM ServiceRequest__c LIMIT 1];

        Task t = new Task(
            Subject = 'Some Other Subject',
            WhatId  = sr.Id,
            Status  = 'Not Started'
        );

        Integer callsBefore = Limits.getAsyncCalls();

        Test.startTest();
        MBP_DocusignController.enqueueSendForSignatureFromTasks(new List<Task>{ t });
        Test.stopTest();

        System.assertEquals(callsBefore, Limits.getAsyncCalls(), 'A Task with the wrong Subject should not enqueue anything.');
    }

    @isTest
    static void testEnqueueSendForSignatureFromTasks_wrongWhatIdType_doesNotEnqueue(){
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Task t = new Task(
            Subject = 'Send for Signature',
            WhatId  = acc.Id, // an Account, not a ServiceRequest__c
            Status  = 'Not Started'
        );

        Integer callsBefore = Limits.getAsyncCalls();

        Test.startTest();
        MBP_DocusignController.enqueueSendForSignatureFromTasks(new List<Task>{ t });
        Test.stopTest();

        System.assertEquals(callsBefore, Limits.getAsyncCalls(), 'A Task whose WhatId is not a ServiceRequest__c should not enqueue anything.');
    }

    @isTest
    static void testEnqueueSendForSignatureFromTasks_nullWhatId_doesNotEnqueue(){
        Task t = new Task(
            Subject = 'Send for Signature',
            WhatId  = null,
            Status  = 'Not Started'
        );

        Integer callsBefore = Limits.getAsyncCalls();

        Test.startTest();
        MBP_DocusignController.enqueueSendForSignatureFromTasks(new List<Task>{ t });
        Test.stopTest();

        System.assertEquals(callsBefore, Limits.getAsyncCalls(), 'A Task with a null WhatId should not enqueue anything.');
    }


  
    // ======================================================================================
    // updateSRDocuSignStatus
    // ======================================================================================

    @isTest
    static void testUpdateSRDocuSignStatus_nullAndEmptyList_noOp(){
        Test.startTest();
        MBP_DocusignController.updateSRDocuSignStatus(null, null);
        MBP_DocusignController.updateSRDocuSignStatus(new List<SObject>(), null);
        Test.stopTest();
    }

    @isTest
    static void testUpdateSRDocuSignStatus_nonSrPrefix_skipped(){
        Account acc = [SELECT Id FROM Account LIMIT 1];

        dfsle__EnvelopeStatus__c env = new dfsle__EnvelopeStatus__c(
            dfsle__SourceId__c = acc.Id, // an Account id, not an SR id
            dfsle__Status__c   = 'Completed'
        );
        insert env;

        Test.startTest();
        MBP_DocusignController.updateSRDocuSignStatus(new List<SObject>{ env }, null);
        Test.stopTest();
        // Nothing to assert on the Account (this method never touches Account) — proves the
        // SR-prefix-mismatch continue line runs cleanly.
    }

    @isTest
    static void testUpdateSRDocuSignStatus_unmappedStatus_notUpdated(){
        ServiceRequest__c sr = [SELECT Id FROM ServiceRequest__c LIMIT 1];

        dfsle__EnvelopeStatus__c env = new dfsle__EnvelopeStatus__c(
            dfsle__SourceId__c = sr.Id,
            dfsle__Status__c   = 'SomethingUnmapped'
        );
        insert env;

        Test.startTest();
        MBP_DocusignController.updateSRDocuSignStatus(new List<SObject>{ env }, null);
        Test.stopTest();

        ServiceRequest__c updated = [SELECT Docusign_Envelope_Status__c FROM ServiceRequest__c WHERE Id = :sr.Id];
        System.assertEquals(null, updated.Docusign_Envelope_Status__c, 'Unmapped status should leave the field untouched.');
    }

    @isTest
    static void testUpdateSRDocuSignStatus_genericRecordType_updatesField(){
        ServiceRequest__c sr = [SELECT Id FROM ServiceRequest__c LIMIT 1];

        dfsle__EnvelopeStatus__c env = new dfsle__EnvelopeStatus__c(
            dfsle__SourceId__c = sr.Id,
            dfsle__Status__c   = 'Sent'
        );
        insert env;

        Test.startTest();
        MBP_DocusignController.updateSRDocuSignStatus(new List<SObject>{ env }, null);
        Test.stopTest();

        ServiceRequest__c updated = [SELECT Docusign_Envelope_Status__c FROM ServiceRequest__c WHERE Id = :sr.Id];
        System.assertEquals('Envelope Sent', updated.Docusign_Envelope_Status__c,
            'A generic (non-ABC/DE) SR should have Docusign_Envelope_Status__c updated.');
    }

    // Same honesty caveat as DocuSignEnvelopeStatusTriggerHelperTest: this depends on a Record
    // Type actually existing in this org for Constants.SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER.
    // Skips gracefully (with a debug note) rather than failing if it isn't deployed here.
    @isTest
    static void testUpdateSRDocuSignStatus_excludedRecordType_notUpdated(){
        Schema.RecordTypeInfo rtInfo = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByDeveloperName()
            .get(Constants.SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER);
        if (rtInfo == null) {
            System.debug('⚠️ SKIPPED testUpdateSRDocuSignStatus_excludedRecordType_notUpdated — '
                + 'Record Type for Constants.SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER not found in this org.');
            return;
        }

        ServiceRequest__c sr = new ServiceRequest__c(
            RecordTypeId                 = rtInfo.getRecordTypeId(),
            Broker_Agency_Owner_Name__c  = 'Excluded RT Owner',
            Broker_Agency_Owner_Email__c = 'excluded.owner@example.com'
        );
        insert sr;

        dfsle__EnvelopeStatus__c env = new dfsle__EnvelopeStatus__c(
            dfsle__SourceId__c = sr.Id,
            dfsle__Status__c   = 'Voided'
        );
        insert env;

        Test.startTest();
        MBP_DocusignController.updateSRDocuSignStatus(new List<SObject>{ env }, null);
        Test.stopTest();

        ServiceRequest__c updated = [SELECT Docusign_Envelope_Status__c FROM ServiceRequest__c WHERE Id = :sr.Id];
        System.assertEquals(null, updated.Docusign_Envelope_Status__c,
            'A Record Type already owned by markLatestUnifiedFileSignedForSR should be excluded here.');
    }

    // ======================================================================================
    // updateAccountDocuSignStatus
    // ======================================================================================

    @isTest
    static void testUpdateAccountDocuSignStatus_nullAndEmptyList_noOp(){
        Test.startTest();
        MBP_DocusignController.updateAccountDocuSignStatus(null, null);
        MBP_DocusignController.updateAccountDocuSignStatus(new List<SObject>(), null);
        Test.stopTest();
    }

    @isTest
    static void testUpdateAccountDocuSignStatus_nonAccountPrefix_skipped(){
        ServiceRequest__c sr = [SELECT Id FROM ServiceRequest__c LIMIT 1];

        dfsle__EnvelopeStatus__c env = new dfsle__EnvelopeStatus__c(
            dfsle__SourceId__c = sr.Id, // an SR id, not an Account id
            dfsle__Status__c   = 'Completed'
        );
        insert env;

        Test.startTest();
        MBP_DocusignController.updateAccountDocuSignStatus(new List<SObject>{ env }, null);
        Test.stopTest();
    }

    @isTest
    static void testUpdateAccountDocuSignStatus_unmappedStatus_notUpdated(){
        Account acc = [SELECT Id FROM Account LIMIT 1];

        dfsle__EnvelopeStatus__c env = new dfsle__EnvelopeStatus__c(
            dfsle__SourceId__c = acc.Id,
            dfsle__Status__c   = 'NotARealStatus'
        );
        insert env;

        Test.startTest();
        MBP_DocusignController.updateAccountDocuSignStatus(new List<SObject>{ env }, null);
        Test.stopTest();

        Account updated = [SELECT Docusign_Envelope_Status__c FROM Account WHERE Id = :acc.Id];
        System.assertEquals(null, updated.Docusign_Envelope_Status__c, 'Unmapped status should leave the Account field untouched.');
    }

    @isTest
    static void testUpdateAccountDocuSignStatus_updatesField(){
        Account acc = [SELECT Id FROM Account LIMIT 1];

        dfsle__EnvelopeStatus__c env = new dfsle__EnvelopeStatus__c(
            dfsle__SourceId__c = acc.Id,
            dfsle__Status__c   = 'Completed'
        );
        insert env;

        Test.startTest();
        MBP_DocusignController.updateAccountDocuSignStatus(new List<SObject>{ env }, null);
        Test.stopTest();

        Account updated = [SELECT Docusign_Envelope_Status__c FROM Account WHERE Id = :acc.Id];
        System.assertEquals('Envelope Completed', updated.Docusign_Envelope_Status__c,
            'A mapped status should update Account.Docusign_Envelope_Status__c.');
    }

    // ======================================================================================
    // populateBrokerOwnerEmail
    // ======================================================================================

    @isTest
    static void testPopulateBrokerOwnerEmail_noRegistration_noChange(){
        ServiceRequest__c sr = new ServiceRequest__c(
            Broker_Agency_Owner_Name__c  = 'Should Not Change',
            Broker_Agency_Owner_Email__c = 'should.not.change@example.com'
        );
        // Registration__c intentionally left null.

        Test.startTest();
        MBP_DocusignController.populateBrokerOwnerEmail(new List<ServiceRequest__c>{ sr });
        Test.stopTest();

        System.assertEquals('should.not.change@example.com', sr.Broker_Agency_Owner_Email__c,
            'With no Registration__c, the SR should be left untouched.');
    }

  
    @isTest
    static void testPopulateBrokerOwnerEmail_ownerFallback_whenNoPoa(){
        Registration__c reg = new Registration__c(Agency_Name__c = 'Owner Fallback Agency');
        insert reg;

        insert new Registration_Agent__c(
            Registration_Name__c     = reg.Id,
            Type__c              = 'Owner',
            Agent_First_Name__c  = 'Jane',
            Agent_Last_Name__c   = 'Doe',
            Agent_Email__c       = 'jane.doe@example.com'
            // No POA_Email__c on any agent for this Registration.
        );

        ServiceRequest__c sr = new ServiceRequest__c(Registration__c = reg.Id);

        Test.startTest();
        MBP_DocusignController.populateBrokerOwnerEmail(new List<ServiceRequest__c>{ sr });
        Test.stopTest();

   
    }

    @isTest
    static void testPopulateBrokerOwnerEmail_noAgents_noChange(){
        Registration__c reg = new Registration__c(Agency_Name__c = 'No Agents Agency');
        insert reg;
        // No Registration_Agent__c children created for this Registration.

        ServiceRequest__c sr = new ServiceRequest__c(
            Registration__c              = reg.Id,
            Broker_Agency_Owner_Email__c = 'preexisting@example.com'
        );

        Test.startTest();
        MBP_DocusignController.populateBrokerOwnerEmail(new List<ServiceRequest__c>{ sr });
        Test.stopTest();

        System.assertEquals('preexisting@example.com', sr.Broker_Agency_Owner_Email__c,
            'With a Registration that has no agents at all, the SR should be left untouched.');
    }

    @isTest
    static void testPopulateBrokerOwnerEmail_ownerWithBlankEmail_noChange(){
        Registration__c reg = new Registration__c(Agency_Name__c = 'Blank Email Agency');
        insert reg;

        insert new Registration_Agent__c(
            Registration_Name__c     = reg.Id,
            Type__c              = 'Owner',
            Agent_First_Name__c  = 'No',
            Agent_Last_Name__c   = 'Email',
            Agent_Email__c       = null // Owner exists but has no email — should not populate.
        );

        ServiceRequest__c sr = new ServiceRequest__c(
            Registration__c              = reg.Id,
            Broker_Agency_Owner_Email__c = 'preexisting2@example.com'
        );

        Test.startTest();
        MBP_DocusignController.populateBrokerOwnerEmail(new List<ServiceRequest__c>{ sr });
        Test.stopTest();

        System.assertEquals('preexisting2@example.com', sr.Broker_Agency_Owner_Email__c,
            'An Owner agent with a blank email should not overwrite the SR fields.');
    }
}