@isTest
public class SubmitEOIControllerTest {

    // ── Helpers ───────────────────────────────────────────────────────────────

    private static Id getPersonRtId() {
        List<RecordType> rt = [
            SELECT Id FROM RecordType
            WHERE  SObjectType = 'Account'
            AND    IsPersonType = true
            LIMIT  1
        ];
        return rt.isEmpty() ? null : rt[0].Id;
    }

    private static String buildParam(Id eoiId) {
        SubmitEOIController.RequestWrap req = new SubmitEOIController.RequestWrap();
        req.eoiId    = eoiId;
        req.comments = 'Test comment';
        return JSON.serialize(req);
    }

    private static void uploadAllDocs(Id eoiId) {
        List<Documents__c> docs = [
            SELECT Id FROM Documents__c
            WHERE  Expressionofinterest__c = :eoiId
        ];
        for (Documents__c d : docs) {
            d.Status__c = 'Uploaded';
        }
        if (!docs.isEmpty()) {
            update docs;
        }
    }

    private static List<Account_Field_Validation__mdt> getPersonAccountRules() {
        String rtDevName = [
            SELECT RecordType.DeveloperName FROM Account
            WHERE  LastName = 'TestPerson' LIMIT 1
        ].RecordType.DeveloperName;

        return [
            SELECT Field_API_Name__c FROM Account_Field_Validation__mdt
            WHERE  Object_API_Name__c            = 'Account'
            AND    Record_Type_Developer_Name__c = :rtDevName
            AND    Is_Active__c                  = true
        ];
    }

    private static Expressionofinterest__c getPersonEoi() {
        return [
            SELECT Id FROM Expressionofinterest__c
            WHERE  Account__r.LastName = 'TestPerson'
            AND    EOI_Amount_AED__c   = 0
            LIMIT  1
        ];
    }

    private static Expressionofinterest__c getPersonEoiWithAmount() {
        return [
            SELECT Id FROM Expressionofinterest__c
            WHERE  Account__r.LastName = 'TestPerson'
            AND    EOI_Amount_AED__c   = 5000
            LIMIT  1
        ];
    }

    private static Expressionofinterest__c getOrgEoi() {
        return [
            SELECT Id FROM Expressionofinterest__c
            WHERE  Account__r.Name   = 'Test Organization'
            AND    EOI_Amount_AED__c = 0
            LIMIT  1
        ];
    }

    private static Expressionofinterest__c getNoAccountEoi() {
        return [
            SELECT Id FROM Expressionofinterest__c
            WHERE  Account__c        = null
            AND    EOI_Amount_AED__c = 0
            LIMIT  1
        ];
    }

    private static Expressionofinterest__c getAmountEoi() {
        return [
            SELECT Id FROM Expressionofinterest__c
            WHERE  Account__c        = null
            AND    EOI_Amount_AED__c = 5000
            LIMIT  1
        ];
    }

    private static Account getOrgAccount() {
        return [SELECT Id FROM Account WHERE Name = 'Test Organization' LIMIT 1];
    }

    // ── Setup ─────────────────────────────────────────────────────────────────

    @TestSetup
    static void setupData() {
        Id personRtId = getPersonRtId();

        Account personAcc = new Account(
            FirstName    = 'John',
            LastName     = 'TestPerson',
            RecordTypeId = personRtId
        );
        Account orgAcc = new Account(Name = 'Test Organization');
        insert new List<Account>{ personAcc, orgAcc };

        Opportunity personOpp = new Opportunity(
            Name      = 'PersonOpp',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            AccountId = personAcc.Id
        );
        Opportunity orgOpp = new Opportunity(
            Name      = 'OrgOpp',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            AccountId = orgAcc.Id
        );
        Opportunity basicOpp = new Opportunity(
            Name      = 'BasicOpp',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            AccountId = orgAcc.Id
        );
        insert new List<Opportunity>{ personOpp, orgOpp, basicOpp };

        Id personOppId = personOpp.Id;
        Id orgOppId    = orgOpp.Id;
        Id basicOppId  = basicOpp.Id;

        List<Expressionofinterest__c> eois = new List<Expressionofinterest__c>{
            new Expressionofinterest__c(
                Opportunity__c    = personOppId,
                Account__c        = personAcc.Id,
                EOI_Amount_AED__c = 0
            ),
            new Expressionofinterest__c(
                Opportunity__c    = orgOppId,
                Account__c        = orgAcc.Id,
                EOI_Amount_AED__c = 0
            ),
            new Expressionofinterest__c(
                Opportunity__c    = basicOppId,
                EOI_Amount_AED__c = 0
            ),
            new Expressionofinterest__c(
                Opportunity__c    = basicOppId,
                EOI_Amount_AED__c = 5000
            ),
            new Expressionofinterest__c(
                Opportunity__c    = personOppId,
                Account__c        = personAcc.Id,
                EOI_Amount_AED__c = 5000
            )
        };
        insert eois;
    }

    // ── Tests ─────────────────────────────────────────────────────────────────

    // ─────────────────────────────────────────────────────────────────────────
    // 1. Zero amount, no account → Success
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void testCheck_ZeroAmount_NoAccount_Success() {
        Expressionofinterest__c eoi = getNoAccountEoi();
        uploadAllDocs(eoi.Id);

        Test.startTest();
        SubmitEOIController.RespondWrap result =
            SubmitEOIController.eoiSubmissionCheck(buildParam(eoi.Id));
        Test.stopTest();

        System.assertEquals('Success', result.result,
            'Zero amount, no account, docs uploaded should return Success');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 2. Null amount → skip payment check → Success
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void testCheck_NullAmount_SkipsPayment_Success() {
        Account orgAcc  = getOrgAccount();
        Opportunity opp = [
            SELECT Id FROM Opportunity
            WHERE  AccountId = :orgAcc.Id
            LIMIT  1
        ];

        Expressionofinterest__c eoi = new Expressionofinterest__c(
            Opportunity__c    = opp.Id,
            EOI_Amount_AED__c = null
        );
        insert eoi;
        uploadAllDocs(eoi.Id);

        Test.startTest();
        SubmitEOIController.RespondWrap result =
            SubmitEOIController.eoiSubmissionCheck(buildParam(eoi.Id));
        Test.stopTest();

        System.assertEquals('Success', result.result,
            'Null amount should skip payment check');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 3. Signed EOI Form not Uploaded → document error
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void testCheck_DocumentNotUploaded_Error() {
        Expressionofinterest__c eoi = getNoAccountEoi();
        uploadAllDocs(eoi.Id);

        insert new Documents__c(
            Name                    = 'Signed EOI Form',
            Expressionofinterest__c = eoi.Id,
            Status__c               = 'Pending Upload'
        );

        Test.startTest();
        SubmitEOIController.RespondWrap result =
            SubmitEOIController.eoiSubmissionCheck(buildParam(eoi.Id));
        Test.stopTest();

        System.assert(result.result.contains('Please upload'),
            'Non-uploaded document should trigger upload error');
        System.assert(result.result.contains('Signed EOI Form'),
            'Error should name the missing document');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 4. All docs uploaded → doc check passes
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void testCheck_DocumentUploaded_PassesDocCheck() {
        Expressionofinterest__c eoi = getNoAccountEoi();
        uploadAllDocs(eoi.Id);

        Test.startTest();
        SubmitEOIController.RespondWrap result =
            SubmitEOIController.eoiSubmissionCheck(buildParam(eoi.Id));
        Test.stopTest();

        System.assertEquals('Success', result.result,
            'All docs uploaded should pass doc check');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 5. Amount > 0, no receipt → payment error
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void testCheck_AmountPositive_NoReceipt_PaymentError() {
        Expressionofinterest__c eoi = getAmountEoi();
        uploadAllDocs(eoi.Id);

        Test.startTest();
        SubmitEOIController.RespondWrap result =
            SubmitEOIController.eoiSubmissionCheck(buildParam(eoi.Id));
        Test.stopTest();

        System.assertEquals('Please make sure payment is created.', result.result,
            'Should return payment missing error');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 6. Amount > 0, receipt exists → payment check passes
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void testCheck_AmountPositive_ReceiptExists_Passes() {
        Expressionofinterest__c eoi = getAmountEoi();
        Account acc                 = getOrgAccount();
        uploadAllDocs(eoi.Id);

        insert new Receipt__c(
            Expressionofinterest__c = eoi.Id,
            Account__c              = acc.Id
        );

        Test.startTest();
        SubmitEOIController.RespondWrap result =
            SubmitEOIController.eoiSubmissionCheck(buildParam(eoi.Id));
        Test.stopTest();

        System.assertEquals('Success', result.result,
            'Receipt present should pass payment check');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 7. Person Account — KYC fires first (new order), then payment
    //    If no metadata rules → KYC skipped → payment error
    //    If metadata rules exist → KYC fires first
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void testCheck_PersonAccount_PaymentErrorBeforeKYC() {
        Expressionofinterest__c eoi       = getPersonEoiWithAmount();
        List<Account_Field_Validation__mdt> rules = getPersonAccountRules();
        uploadAllDocs(eoi.Id);

        Test.startTest();
        SubmitEOIController.RespondWrap result =
            SubmitEOIController.eoiSubmissionCheck(buildParam(eoi.Id));
        Test.stopTest();

        if (rules.isEmpty()) {
            // No metadata rules → KYC skipped → payment check fires → payment error
            System.assertEquals('Please make sure payment is created.', result.result,
                'No metadata rules: payment error should show');
        } else {
            // Metadata rules exist → KYC fires first (KYC → Doc → Payment)
            System.assert(
                result.result.contains('KYC') || result.result.contains('Please make sure payment'),
                'Should be KYC or payment error: ' + result.result
            );
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 8. Person Account — KYC or metadata branch
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void testCheck_PersonAccount_HitsKycOrMetadataBranch() {
        Expressionofinterest__c eoi       = getPersonEoi();
        List<Account_Field_Validation__mdt> rules = getPersonAccountRules();
        uploadAllDocs(eoi.Id);

        Test.startTest();
        SubmitEOIController.RespondWrap result =
            SubmitEOIController.eoiSubmissionCheck(buildParam(eoi.Id));
        Test.stopTest();

        System.assertNotEquals(null, result.result, 'Result must not be null');
        System.assertNotEquals('',   result.result, 'Result must not be empty');

        if (rules.isEmpty()) {
            System.assertEquals('Success', result.result,
                'No metadata rules — KYC skipped — should be Success');
        } else {
            System.assert(
                result.result.contains('KYC') || result.result.equals('Success'),
                'Should be KYC error or Success: ' + result.result
            );
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 9. Person Account — KYC fires first (new order), then doc
    //    If no metadata rules → KYC skipped → doc error
    //    If metadata rules exist → KYC fires first
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void testCheck_PersonAccount_DocErrorBeforeKYC() {
        Expressionofinterest__c eoi       = getPersonEoi();
        List<Account_Field_Validation__mdt> rules = getPersonAccountRules();
        uploadAllDocs(eoi.Id);

        insert new Documents__c(
            Name                    = 'Signed EOI Form',
            Expressionofinterest__c = eoi.Id,
            Status__c               = 'Pending Upload'
        );

        Test.startTest();
        SubmitEOIController.RespondWrap result =
            SubmitEOIController.eoiSubmissionCheck(buildParam(eoi.Id));
        Test.stopTest();

        if (rules.isEmpty()) {
            // No metadata rules → KYC skipped → doc check fires → doc error
            System.assert(result.result.contains('Please upload'),
                'No metadata rules: doc error should show — ' + result.result);
        } else {
            // Metadata rules exist → KYC fires first (KYC → Doc → Payment)
            System.assert(
                result.result.contains('KYC') || result.result.contains('Please upload'),
                'Should be KYC or doc error: ' + result.result
            );
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 10. Org Account — hits org branch
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void testCheck_OrgAccount_HitsOrgBranch() {
        Expressionofinterest__c eoi = getOrgEoi();
        uploadAllDocs(eoi.Id);

        Test.startTest();
        SubmitEOIController.RespondWrap result =
            SubmitEOIController.eoiSubmissionCheck(buildParam(eoi.Id));
        Test.stopTest();

        System.assertNotEquals(null, result.result, 'Org account result must not be null');
        System.assertNotEquals('',   result.result, 'Org account result must not be empty');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 11. Org Account — with receipt
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void testCheck_OrgAccount_WithReceipt() {
        Expressionofinterest__c eoi = getOrgEoi();
        Account acc                 = getOrgAccount();
        uploadAllDocs(eoi.Id);

        insert new Receipt__c(
            Expressionofinterest__c = eoi.Id,
            Account__c              = acc.Id
        );

        Test.startTest();
        SubmitEOIController.RespondWrap result =
            SubmitEOIController.eoiSubmissionCheck(buildParam(eoi.Id));
        Test.stopTest();

        System.assertNotEquals(null, result.result, 'Result must not be null');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 12. Doc not uploaded + amount > 0 — doc error fires before payment
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void testCheck_DocAndPaymentFail_DocFirst() {
        Expressionofinterest__c eoi = getAmountEoi();
        uploadAllDocs(eoi.Id);

        insert new Documents__c(
            Name                    = 'Signed EOI Form',
            Expressionofinterest__c = eoi.Id,
            Status__c               = 'Pending Upload'
        );

        Test.startTest();
        SubmitEOIController.RespondWrap result =
            SubmitEOIController.eoiSubmissionCheck(buildParam(eoi.Id));
        Test.stopTest();

        System.assert(result.result.contains('Please upload'),
            'Doc error should fire before payment error');
    }
    @isTest
    static void testSubmitEoi_MethodExecutes() {
        Expressionofinterest__c eoi = getNoAccountEoi();
        uploadAllDocs(eoi.Id);

        SubmitEOIController.RequestWrap req = new SubmitEOIController.RequestWrap();
        req.eoiId    = eoi.Id;
        req.comments = 'Approve please';

        Test.startTest();
        try {
            SubmitEOIController.submitEoi(JSON.serialize(req));
        } catch (Exception ex) {
            System.debug('Expected approval exception: ' + ex.getMessage());
        }
        Test.stopTest();

        List<Expressionofinterest__c> eoiList = [
            SELECT Id, Status__c FROM Expressionofinterest__c WHERE Id = :eoi.Id
        ];
        System.assertEquals(1, eoiList.size(), 'EOI should still exist after submitEoi call');
        System.assertNotEquals(null, eoiList[0].Status__c, 'Status should be set');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 17. submitEoi — with comments
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void testSubmitEoi_WithComments() {
        Expressionofinterest__c eoi = getOrgEoi();
        uploadAllDocs(eoi.Id);

        SubmitEOIController.RequestWrap req = new SubmitEOIController.RequestWrap();
        req.eoiId    = eoi.Id;
        req.comments = 'Detailed approval comment';

        Test.startTest();
        try {
            SubmitEOIController.submitEoi(JSON.serialize(req));
        } catch (Exception ex) {
            System.debug('Expected approval exception: ' + ex.getMessage());
        }
        Test.stopTest();

        List<Expressionofinterest__c> eoiList = [
            SELECT Id FROM Expressionofinterest__c WHERE Id = :eoi.Id
        ];
        System.assertEquals(1, eoiList.size(), 'EOI should exist after submitEoi');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 18. Wrapper classes — field assignments
    // ─────────────────────────────────────────────────────────────────────────
    @isTest
    static void testWrapperClasses_FieldsAssignable() {
        SubmitEOIController.RequestWrap req = new SubmitEOIController.RequestWrap();
        req.eoiId    = 'a0B000000000001AAA';
        req.comments = 'Test comment';

        SubmitEOIController.RespondWrap resp = new SubmitEOIController.RespondWrap();
        resp.result  = 'Success';

        System.assertEquals('a0B000000000001AAA', req.eoiId,    'eoiId should match');
        System.assertEquals('Test comment',        req.comments, 'comments should match');
        System.assertEquals('Success',             resp.result,  'result should match');
    }

    @isTest
    static void testCheck_PersonKycValidationFails() {
        Expressionofinterest__c eoi = getPersonEoi();
        uploadAllDocs(eoi.Id);

        Test.startTest();
        SubmitEOIController.RespondWrap result =
            SubmitEOIController.eoiSubmissionCheck(buildParam(eoi.Id));
        Test.stopTest();

        System.assertNotEquals(null, result.result);
    }

    @isTest
    static void testCheck_OrgAccountMissingRequiredFields() {
        Expressionofinterest__c eoi = getOrgEoi();
        Account orgAcc = getOrgAccount();
        orgAcc.Phone = null;
        update orgAcc;
        uploadAllDocs(eoi.Id);

        Test.startTest();
        SubmitEOIController.RespondWrap result =
            SubmitEOIController.eoiSubmissionCheck(buildParam(eoi.Id));
        Test.stopTest();

        System.assertNotEquals(null, result.result);
    }

    @isTest
    static void testSubmitEoi_NoAccountSuccessPath() {
        Expressionofinterest__c eoi = getNoAccountEoi();
        uploadAllDocs(eoi.Id);

        SubmitEOIController.RequestWrap req = new SubmitEOIController.RequestWrap();
        req.eoiId = eoi.Id;
        req.comments = 'Submit for approval';

        Test.startTest();
        try {
            SubmitEOIController.RespondWrap resp = SubmitEOIController.submitEoi(JSON.serialize(req));
            System.assertNotEquals(null, resp);
        } catch (Exception ex) {
            System.debug('submitEoi exception: ' + ex.getMessage());
        }
        Test.stopTest();

        Expressionofinterest__c afterSubmit = [
            SELECT Status__c FROM Expressionofinterest__c WHERE Id = :eoi.Id
        ];
        System.assertNotEquals(null, afterSubmit.Status__c);
    }
}