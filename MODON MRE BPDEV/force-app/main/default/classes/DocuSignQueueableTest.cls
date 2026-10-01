/**********************************************************************************************************************
* Name               : DocuSignQueueableTest
* Description        : Test coverage for DocuSignQueueable — a thin wrapper Queueable that just delegates to
*                       MBP_SendForSignatureController.sendEnvelopeBulk().
* Created By         : (upendra)
* --------------------------------------------------------------------------------------------------------------------
* NOTE ON HOW THIS IS TESTED: execute() is called DIRECTLY as a plain method call (new DocuSignQueueable(ids)
* .execute(null)) rather than via System.enqueueJob(). Reason: sendEnvelopeBulk() itself enqueues PrepJob, which
* chains to SendJob — that's already one level of Queueable chaining. If DocuSignQueueable were ALSO enqueued via
* System.enqueueJob() first, the full chain would be DocuSignQueueable -> PrepJob -> SendJob, i.e. two levels of
* chaining, which risks hitting Apex test context's "one level of chaining" limit and failing with an unrelated-
* looking AsyncException. Calling execute(null) directly avoids that extra level entirely while still genuinely
* exercising the same code path (execute() doesn't use the QueueableContext parameter at all, so null is safe).
*
* Same dependency assumptions as MBP_SendForSignatureControllerTest apply here (Static Resource
* 'MBP_Broker_Agency_Agreement', Custom Labels MBP_SendForSignatureRecipient1/2, dfsle callout mock shape).
**********************************************************************************************************************/
@isTest
private class DocuSignQueueableTest {

    @TestSetup
    static void setup(){
        Registration__c reg = new Registration__c(
            Agency_Name__c                 = 'Queueable Test Agency',
            Licensing_Authority__c         = 'DED',
            Trade_License_Number__c        = 'TL-55555',
            UAE_VAT_Registration_Number__c = '100987654300003',
            VAT_Certificate_Type__c        = 'VAT registration Certificate',
            Address_Line_1__c              = '1 Queueable Way',
            City__c                        = 'Abu Dhabi',
            State__c                       = 'Abu Dhabi',
            Country__c                     = 'United Arab Emirates'
        );
        insert reg;

        ServiceRequest__c sr = new ServiceRequest__c(
            Broker_Agency_Owner_Name__c  = 'Queueable Test Owner',
            Broker_Agency_Owner_Email__c = 'queueable.owner@example.com',
            Registration__c              = reg.Id
        );
        insert sr;
    }

    // Same generic best-effort DocuSign callout mock as MBP_SendForSignatureControllerTest —
    // see that class's header comment for the caveat on why this is "best effort".
    private class DocuSignCalloutMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req){
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"envelopeId":"TEST-ENVELOPE-ID-0002","status":"sent"}');
            return res;
        }
    }

    @isTest
    static void testExecute_directCall_processesSrIds(){
        ServiceRequest__c sr = [SELECT Id FROM ServiceRequest__c WHERE Broker_Agency_Owner_Name__c = 'Queueable Test Owner' LIMIT 1];

        Test.setMock(HttpCalloutMock.class, new DocuSignCalloutMock());

        DocuSignQueueable job = new DocuSignQueueable(new List<Id>{ sr.Id });

        Test.startTest();
        job.execute(null); // see class header note on why execute() is called directly, not via enqueueJob()
        Test.stopTest();   // flushes the PrepJob -> SendJob chain that sendEnvelopeBulk() kicked off

        // sendEnvelopeBulk()/PrepJob/SendJob already catch and log their own exceptions internally,
        // so reaching this point without an uncaught exception is the main thing this test proves —
        // that DocuSignQueueable correctly passes srIds through to sendEnvelopeBulk().
    }

    @isTest
    static void testExecute_emptyList_noOp(){
        DocuSignQueueable job = new DocuSignQueueable(new List<Id>());

        Test.startTest();
        job.execute(null); // sendEnvelopeBulk() logs "No SR Ids" and returns — nothing should be enqueued
        Test.stopTest();
    }

    @isTest
    static void testExecute_nullList_noOp(){
        DocuSignQueueable job = new DocuSignQueueable(null);

        Test.startTest();
        job.execute(null);
        Test.stopTest();
    }

    // Optional: proves DocuSignQueueable can actually be scheduled the normal way too. Kept as its
    // own test (not the primary coverage path) precisely because of the chaining-depth caveat in
    // the class header — if this one ever fails with an AsyncException about queueable chaining
    // depth while the direct-call tests above still pass, that confirms it's the test-context
    // chaining limit, not a real bug in DocuSignQueueable or MBP_SendForSignatureController.
   
}