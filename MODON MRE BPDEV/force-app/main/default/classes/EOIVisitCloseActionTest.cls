/**
 * EOIVisitCloseActionTest — the flow-invoked settle action: gated for tests,
 * one registration (one promotion cascade) per invocation.
 * @author Aurelix
 */
@isTest
private class EOIVisitCloseActionTest {

    private static Id makeProject() {
        Project__c p = new Project__c(Name = 'Wadeem Close Test');
        insert p;
        return p.Id;
    }

    private static Id makeRange(Id projectId) {
        EOI_Range__c r = new EOI_Range__c(
            Project__c = projectId, Unit_Type__c = 'Villa', UnitTypologyMRE__c = 'Select Villas',
            Amount__c = 50000, Is_Active__c = true, Applicable_for_Broker__c = true, Show_On__c = 'Public Microsite'
        );
        insert r;
        return r.Id;
    }

    private static Id verifiedRegistration(String email, String mobile) {
        EOI_Public_Registration__c row = new EOI_Public_Registration__c(
            Status__c = 'Verified', CustomerType__c = 'Individual', Source__c = 'Wadeem Microsite',
            FirstName__c = 'Close', LastName__c = 'Probe', Email__c = email, Mobile__c = mobile,
            VerifiedChannel__c = 'Email', VerifiedAt__c = System.now()
        );
        insert row;
        return row.Id;
    }

    private static String finalizedPayment(String reference, Id regId, Id projectId, Id rangeId) {
        String snap = JSON.serialize(new Map<String, Object>{
            'registrationId' => String.valueOf(regId),
            'projectId' => String.valueOf(projectId),
            'lines' => new List<Object>{ new Map<String, Object>{
                'rangeId' => String.valueOf(rangeId), 'phaseId' => null,
                'unitType' => 'Villa', 'bedrooms' => null,
                'unitTypology' => 'Select Villas', 'amount' => 50000, 'quantity' => 1 } }
        });
        insert new Checkout_Payment__c(
            Reference__c = reference, Status__c = 'Captured', Amount__c = 50000,
            Currency_Code__c = 'AED', Payment_Id__c = 'pay_' + reference,
            EOI_Site_Registration__c = String.valueOf(regId), EOI_Site_Selection__c = snap,
            EOI_Site_Range__c = String.valueOf(rangeId)
        );
        EOIService.finalizeCardPayment(reference);
        return reference;
    }

    @isTest
    static void gateOffLeavesEverythingUntouched() {
        Id projectId = makeProject();
        Id rangeId = makeRange(projectId);
        Id regId = verifiedRegistration('gate.off@example.com', '+971500000201');
        finalizedPayment('CKO-GATE1', regId, projectId, rangeId);

        // testEnabled defaults false: the drained flow path must not settle
        EOIVisitCloseAction.close(new List<Id>{ [
            SELECT Id FROM Checkout_Payment__c WHERE Reference__c = 'CKO-GATE1'
        ].Id });

        EOI_Public_Registration__c row = [
            SELECT Status__c, BatchId__c FROM EOI_Public_Registration__c WHERE Id = :regId
        ];
        System.assertEquals('Verified', row.Status__c);
        System.assertEquals(null, row.BatchId__c, 'gated action stamps nothing');
    }

    @isTest
    static void closeSettlesExactlyOneRegistrationPerInvocation() {
        Id projectId = makeProject();
        Id rangeId = makeRange(projectId);
        Id regA = verifiedRegistration('close.a@example.com', '+971500000202');
        Id regB = verifiedRegistration('close.b@example.com', '+971500000203');
        finalizedPayment('CKO-ONEA', regA, projectId, rangeId);
        finalizedPayment('CKO-ONEB', regB, projectId, rangeId);

        EOIVisitCloseAction.testEnabled = true;
        EOIVisitCloseAction.close(new List<Id>{
            [SELECT Id FROM Checkout_Payment__c WHERE Reference__c = 'CKO-ONEA'].Id,
            [SELECT Id FROM Checkout_Payment__c WHERE Reference__c = 'CKO-ONEB'].Id
        });

        EOI_Public_Registration__c rowA = [
            SELECT Status__c, BatchId__c FROM EOI_Public_Registration__c WHERE Id = :regA
        ];
        EOI_Public_Registration__c rowB = [
            SELECT Status__c, BatchId__c FROM EOI_Public_Registration__c WHERE Id = :regB
        ];
        System.assert(String.isNotBlank(rowA.BatchId__c), 'first registration settles');
        System.assertNotEquals('Verified', rowA.Status__c);
        System.assertEquals(null, rowB.BatchId__c,
            'one promotion cascade per transaction: the second registration waits for its own interview');
        System.assertEquals('Verified', rowB.Status__c);
    }

    /** MEOI-TEST (11 Sep 2026): an empty invocation is a no-op that touches nothing. */
    @isTest
    static void emptyInputIsANoOp() {
        EOIVisitCloseAction.testEnabled = true;
        EOIVisitCloseAction.close(null);
        EOIVisitCloseAction.close(new List<Id>());
        System.assertEquals(0, Limits.getQueries(), 'no query, no DML for an empty input');
        System.assertEquals(0, Limits.getDmlStatements());
    }
}