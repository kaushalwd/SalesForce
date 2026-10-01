@IsTest
private class EOIRefundAutomaterTest {

    private class MockWhatsAppResponse implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"success":true}');
            res.setStatusCode(200);
            return res;
        }
    }

    @TestSetup
    static void setupData() {

        Id personAccountRecordTypeId = Schema.SObjectType.Account
            .getRecordTypeInfosByDeveloperName()
            .get('PersonAccount')
            .getRecordTypeId();

        Account acc = new Account(
            RecordTypeId = personAccountRecordTypeId,
            LastName = 'EOI Automater Test Customer',
            PersonEmail = 'automater@test.com',
            PersonMobilePhone = '971501234000'
        );
        Database.insert(acc, AccessLevel.SYSTEM_MODE);

        Opportunity opp = new Opportunity(
            Name = 'EOI Automater Test Opportunity',
            StageName = 'Prospecting',
            CloseDate = System.today().addDays(10),
            AccountId = acc.Id
        );
        Database.insert(opp, AccessLevel.SYSTEM_MODE);

        Business_Process__c bp = new Business_Process__c(Type__c = 'EOI Refund Approval');
        insert bp;

        // Create a test Management MEMO ContentVersion & link to bp
        ContentVersion cv = new ContentVersion(
            Title = 'Management MEMO',
            PathOnClient = 'Management_MEMO.pdf',
            VersionData = Blob.valueOf('Test Memo Content'),
            IsMajorVersion = true
        );
        insert cv;

        Id contentDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        insert new ContentDocumentLink(
            ContentDocumentId = contentDocId,
            LinkedEntityId = bp.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );

        Business_Process__c otherBp = new Business_Process__c(Type__c = 'EOI Refund Approval');
        insert otherBp;

        // Eligible EOI on bp - no Case yet, should get one when CCO Approval completes.
        Expressionofinterest__c eoi = new Expressionofinterest__c(
            Opportunity__c = opp.Id,
            Account__c = acc.Id,
            EOI_Amount_AED__c = 10000,
            Status__c = 'In progress',
            Business_Process__c = bp.Id
        );
        Database.insert(eoi, AccessLevel.SYSTEM_MODE);

        // Already-refunded EOI on the same bp - must be left untouched.
        CaseTriggerHandler.isTriggerDisabled = true;
        Case existingCase = new Case(Subject = 'Existing refund case');
        insert existingCase;
        CaseTriggerHandler.isTriggerDisabled = false;

        Expressionofinterest__c alreadyRefundedEoi = new Expressionofinterest__c(
            Opportunity__c = opp.Id,
            Account__c = acc.Id,
            EOI_Amount_AED__c = 5000,
            Status__c = 'In progress',
            Business_Process__c = bp.Id,
            Case__c = existingCase.Id
        );
        Database.insert(alreadyRefundedEoi, AccessLevel.SYSTEM_MODE);

        // EOI on a different Business Process - must not be swept up by bp's automation.
        Expressionofinterest__c otherEoi = new Expressionofinterest__c(
            Opportunity__c = opp.Id,
            Account__c = acc.Id,
            EOI_Amount_AED__c = 7000,
            Status__c = 'In progress',
            Business_Process__c = otherBp.Id
        );
        Database.insert(otherEoi, AccessLevel.SYSTEM_MODE);
    }

    private static BusinessProcessAutomationInput buildInput(Id businessProcessId, String stepName, String status) {

        BusinessProcessAutomationInput input = new BusinessProcessAutomationInput();
        input.steps = new List<Business_Process_Step__c>{
            new Business_Process_Step__c(
                Name = stepName,
                Status__c = status,
                Business_Process__c = businessProcessId
            )
        };
        return input;
    }

    @IsTest
    static void testCCOApprovalCompletedCreatesCaseForEligibleEOIOnly() {

        Business_Process__c bp = [
            SELECT Id FROM Business_Process__c
            WHERE Id NOT IN (SELECT Business_Process__c FROM Expressionofinterest__c WHERE EOI_Amount_AED__c = 7000)
            LIMIT 1
        ];

        Test.setMock(HttpCalloutMock.class, new MockWhatsAppResponse());

        Test.startTest();
        new EOIRefundAutomater().executeAutomation(buildInput(bp.Id, 'CCO Approval', 'Completed'));
        Test.stopTest();

        Expressionofinterest__c eligibleEoi = [
            SELECT Id, Case__c FROM Expressionofinterest__c WHERE EOI_Amount_AED__c = 10000
        ];
        System.assertNotEquals(null, eligibleEoi.Case__c, 'Eligible EOI should now have a refund Case.');

        Expressionofinterest__c alreadyRefundedEoi = [
            SELECT Id, Case__c FROM Expressionofinterest__c WHERE EOI_Amount_AED__c = 5000
        ];
        Case originalCase = [SELECT Id FROM Case WHERE Subject = 'Existing refund case'];
        System.assertEquals(
            originalCase.Id,
            alreadyRefundedEoi.Case__c,
            'Already-refunded EOI must keep its existing Case, not be reprocessed.'
        );

        Expressionofinterest__c otherBpEoi = [
            SELECT Id, Case__c FROM Expressionofinterest__c WHERE EOI_Amount_AED__c = 7000
        ];
        System.assertEquals(
            null,
            otherBpEoi.Case__c,
            'EOI on a different Business Process must not be touched.'
        );
    }

    @IsTest
    static void testStepNotCCOApprovalIsIgnored() {

        Business_Process__c bp = [
            SELECT Id FROM Business_Process__c
            WHERE Id NOT IN (SELECT Business_Process__c FROM Expressionofinterest__c WHERE EOI_Amount_AED__c = 7000)
            LIMIT 1
        ];

        Test.startTest();
        new EOIRefundAutomater().executeAutomation(
            buildInput(bp.Id, 'Sales Operations Director Approval', 'Completed')
        );
        Test.stopTest();

        Expressionofinterest__c eligibleEoi = [
            SELECT Id, Case__c FROM Expressionofinterest__c WHERE EOI_Amount_AED__c = 10000
        ];
        System.assertEquals(null, eligibleEoi.Case__c, 'A different step name must not trigger case creation.');
    }

    @IsTest
    static void testCCOApprovalNotCompletedIsIgnored() {

        Business_Process__c bp = [
            SELECT Id FROM Business_Process__c
            WHERE Id NOT IN (SELECT Business_Process__c FROM Expressionofinterest__c WHERE EOI_Amount_AED__c = 7000)
            LIMIT 1
        ];

        Test.startTest();
        new EOIRefundAutomater().executeAutomation(buildInput(bp.Id, 'CCO Approval', 'Open'));
        Test.stopTest();

        Expressionofinterest__c eligibleEoi = [
            SELECT Id, Case__c FROM Expressionofinterest__c WHERE EOI_Amount_AED__c = 10000
        ];
        System.assertEquals(null, eligibleEoi.Case__c, 'An incomplete CCO Approval step must not trigger case creation.');
    }
}