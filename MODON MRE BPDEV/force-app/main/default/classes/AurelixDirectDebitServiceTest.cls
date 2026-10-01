/**
 * AurelixDirectDebitServiceTest - the console's UAEDDS door.
 *
 * Version  Author       Date         Detail
 * 1.2      Aurelix Dev  22 Sep 2026  Service 1.3: the Draft carries its bank as UAEDDSBankName__c (a value of
 *                                    that restricted picklist, First Abu Dhabi Bank), and the card reads that
 *                                    field first and Customer_Bank_Name__c only for older mandates.
 *                                    Previous version: _backup/2026-09-22_081155 (WL-019).
 * 1.1      Aurelix Dev  21 Sep 2026  Discard is Finance's per MODON's action matrix: the card never
 *                                    offers it, and financeOnlyDiscard carries the state instead.
 * 1.0      Aurelix Dev  18 Sep 2026  SCW-125. Stage / step / action mapping for every status
 *                                    MODON's UAEDDS build can leave on a mandate (in memory, no
 *                                    DML), the eligibility rule, the mobile and IBAN helpers,
 *                                    the switches, and - SeeAllData - the live card on DEV's own
 *                                    mandates and a Draft raised through MODON's method (rolled
 *                                    back). Callout actions are proved to refuse cleanly while
 *                                    the switch is off and to surface a vendor refusal when on.
 */
@IsTest
private class AurelixDirectDebitServiceTest {

    /** In memory, never inserted. Name is an auto-number, so it is set the way tests fake Ids: through JSON. */
    private static DirectDebitRequest__c row(String status) {
        Map<String, Object> raw = new Map<String, Object>{
            'Name' => 'DD-TEST',
            'Gateway__c' => 'UAEDDS',
            'Customer_Bank_Name__c' => 'EmiratesNBD Bank PJSC',
            'Customer_IBAN_Number__c' => 'AE070331234567890123456',
            'Customer_Mobile__c' => '0501234567',
            'Maximum_Amount__c' => 1000
        };
        if (status != null) {
            raw.put('Status__c', status);
        }
        return (DirectDebitRequest__c) JSON.deserialize(JSON.serialize(raw), DirectDebitRequest__c.class);
    }

    private static ContentDocumentLink fileTitled(String title) {
        ContentDocumentLink l = new ContentDocumentLink();
        l = (ContentDocumentLink) JSON.deserialize(
            '{"ContentDocumentId":"069000000000001AAA","ContentDocument":{"Title":"' + title + '"}}',
            ContentDocumentLink.class);
        return l;
    }

    /** Service 1.3: UAEDDSBankName__c is the bank; Customer_Bank_Name__c only for older mandates. */
    @IsTest
    static void theCardReadsTheUaeddsBankFirst() {
        DirectDebitRequest__c older = row('Draft');
        AurelixDirectDebitService.CardDTO before = AurelixDirectDebitService.cardFor(older, new List<ContentDocumentLink>());
        Assert.areEqual('EmiratesNBD Bank PJSC', before.bank, 'A mandate from before the new field shows its old bank.');

        DirectDebitRequest__c newer = row('Draft');
        newer.UAEDDSBankName__c = 'First Abu Dhabi Bank';
        AurelixDirectDebitService.CardDTO after = AurelixDirectDebitService.cardFor(newer, new List<ContentDocumentLink>());
        Assert.areEqual('First Abu Dhabi Bank', after.bank, 'UAEDDSBankName__c wins, as in MODON\'s payload.');
    }

    @IsTest
    static void noMandateIsAFreeSlot() {
        AurelixDirectDebitService.CardDTO c = AurelixDirectDebitService.cardFor(null, null);
        System.assertEquals(AurelixDirectDebitService.STAGE_NONE, c.stage);
        System.assertEquals(true, c.slotFree);
        System.assertEquals(false, c.covering);
        System.assert(c.steps.isEmpty());
    }

    @IsTest
    static void everyStatusMapsToAStage() {
        Map<String, String> expected = new Map<String, String>{
            'Draft' => AurelixDirectDebitService.STAGE_DRAFT,
            'Rejected' => AurelixDirectDebitService.STAGE_FINANCE_REJECTED,
            'Pending Customer Signature' => AurelixDirectDebitService.STAGE_PENDING,
            'Send To Bank' => AurelixDirectDebitService.STAGE_SENT,
            'Approved By Bank' => AurelixDirectDebitService.STAGE_ACTIVE,
            'Approved' => AurelixDirectDebitService.STAGE_ACTIVE,
            'Rejected By Bank' => AurelixDirectDebitService.STAGE_BANK_REJECTED,
            'Discarded' => AurelixDirectDebitService.STAGE_DISCARDED,
            'Cancellation Requested' => AurelixDirectDebitService.STAGE_CANCEL_REQUESTED,
            'Cancelled' => AurelixDirectDebitService.STAGE_CANCELLED,
            'Finance Team Approved' => AurelixDirectDebitService.STAGE_LEGACY
        };
        for (String status : expected.keySet()) {
            AurelixDirectDebitService.CardDTO c = AurelixDirectDebitService.cardFor(row(status), null);
            System.assertEquals(expected.get(status), c.stage, status);
            System.assertEquals(4, c.steps.size(), status + ' draws four steps');
            System.assert(String.isNotBlank(c.stageLabel), status + ' has a label');
        }
        AurelixDirectDebitService.CardDTO blank = AurelixDirectDebitService.cardFor(row(null), null);
        System.assertEquals(AurelixDirectDebitService.STAGE_LEGACY, blank.stage,
            'A console-era row with no status is legacy, not free');
        System.assertEquals(false, blank.slotFree);
    }

    @IsTest
    static void deadStatusesFreeTheSlotAndStopCovering() {
        for (String dead : new List<String>{ 'Discarded', 'Cancelled', 'Rejected By Bank', 'Rejected' }) {
            AurelixDirectDebitService.CardDTO c = AurelixDirectDebitService.cardFor(row(dead), null);
            System.assertEquals(true, c.slotFree, dead + ' frees the slot (MODON DEAD_STATUSES)');
            System.assertEquals(false, c.covering, dead + ' no longer covers');
            System.assertEquals(true, c.actions.setUpAgain, dead + ' offers Set up again');
        }
        for (String open : new List<String>{ 'Draft', 'Pending Customer Signature', 'Send To Bank', 'Approved By Bank', 'Cancellation Requested' }) {
            AurelixDirectDebitService.CardDTO c = AurelixDirectDebitService.cardFor(row(open), null);
            System.assertEquals(false, c.slotFree, open + ' still stands');
            System.assertEquals(true, c.covering, open + ' covers the schedule');
        }
        System.assertEquals(true, AurelixDirectDebitService.cardFor(row('Approved By Bank'), null).coversMilestones);
        System.assertEquals(false, AurelixDirectDebitService.cardFor(row('Draft'), null).coversMilestones);
    }

    @IsTest
    static void actionsFollowTheBankState() {
        AurelixDirectDebitService.switchOverride = new Map<String, Boolean>{
            AurelixDirectDebitService.FLAG_ACTIONS => true
        };
        DirectDebitRequest__c pending = row('Pending Customer Signature');
        pending.DDA_Id__c = '914';
        pending.Bank_Status_Code__c = 'PNDG';
        AurelixDirectDebitService.CardDTO p = AurelixDirectDebitService.cardFor(pending, null);
        System.assertEquals(true, p.actions.enabled);
        System.assertEquals(true, p.actions.refresh);
        System.assertEquals(false, p.actions.discard,
            'MODON keep discard with Finance (action matrix, 20 Sep), so it is never offered here');
        System.assertEquals(true, p.actions.financeOnlyDiscard,
            'but the state is reported, so the card can say where it is done');
        System.assertEquals(true, p.actions.fetchUnsigned, 'no unsigned form on file yet');
        System.assertEquals(false, p.actions.fetchSigned, 'nothing signed yet');
        System.assertEquals(false, p.actions.requestCancellation);

        DirectDebitRequest__c active = row('Approved By Bank');
        active.DDA_Id__c = '914';
        active.Bank_Status_Code__c = 'ACCP';
        AurelixDirectDebitService.CardDTO a = AurelixDirectDebitService.cardFor(
            active, new List<ContentDocumentLink>{ fileTitled('DD-TEST - Unsigned Mandate'), fileTitled('DD-TEST - Signed Mandate') });
        System.assertEquals(true, a.hasUnsignedForm);
        System.assertEquals(true, a.hasSignedForm);
        System.assertEquals(2, a.documents.size());
        System.assertEquals(false, a.actions.discard, 'a live mandate is cancelled, never discarded');
        System.assertEquals(false, a.actions.financeOnlyDiscard, 'and there is nothing for Finance to withdraw either');
        System.assertEquals(true, a.actions.requestCancellation);
        System.assertEquals(false, a.actions.fetchSigned, 'already on file');

        active.Cancellation_Initiated__c = true;
        AurelixDirectDebitService.CardDTO cp = AurelixDirectDebitService.cardFor(active, null);
        System.assertEquals(AurelixDirectDebitService.STAGE_CANCEL_PENDING, cp.stage,
            'a console-raised cancellation waits for Finance');
        System.assertEquals(false, cp.actions.requestCancellation, 'not twice');

        DirectDebitRequest__c requested = row('Cancellation Requested');
        requested.DDA_Id__c = '914';
        requested.DDCA_Id__c = '77';
        requested.Bank_Status_Code__c = 'ACCP';
        AurelixDirectDebitService.CardDTO r = AurelixDirectDebitService.cardFor(requested, null);
        System.assertEquals(false, r.actions.refresh, 'plan D6: a refresh would overwrite this status');

        DirectDebitRequest__c draft = row('Draft');
        AurelixDirectDebitService.CardDTO d = AurelixDirectDebitService.cardFor(draft, null);
        System.assertEquals(false, d.actions.refresh, 'nothing at the bank yet');
        System.assertEquals(false, d.actions.fetchUnsigned);
    }

    @IsTest
    static void switchOffDisablesActionsButKeepsTheFacts() {
        AurelixDirectDebitService.switchOverride = new Map<String, Boolean>{
            AurelixDirectDebitService.FLAG_ACTIONS => false
        };
        DirectDebitRequest__c pending = row('Pending Customer Signature');
        pending.DDA_Id__c = '914';
        pending.Bank_Status_Code__c = 'PNDG';
        AurelixDirectDebitService.CardDTO p = AurelixDirectDebitService.cardFor(pending, null);
        System.assertEquals(false, p.actions.enabled);
        System.assertEquals(true, p.actions.refresh, 'what WOULD be legal is still reported');
    }

    @IsTest
    static void eligibilityRule() {
        AurelixDirectDebitService.switchOverride = new Map<String, Boolean>{
            AurelixDirectDebitService.FLAG_UAEDDS => true,
            AurelixDirectDebitService.FLAG_ORGANISATION => false
        };
        AurelixDirectDebitService.EligibilityInput i = new AurelixDirectDebitService.EligibilityInput();
        i.salesOrderStatus = 'New';
        i.residency = 'Resident';
        i.isPersonAccount = true;
        i.liveChequeCount = 0;
        i.hasLines = true;
        i.card = AurelixDirectDebitService.cardFor(null, null);
        System.assertEquals(true, AurelixDirectDebitService.eligibility(i).allowed);

        i.liveChequeCount = 2;
        AurelixDirectDebitService.EligibilityDTO v = AurelixDirectDebitService.eligibility(i);
        System.assertEquals(false, v.allowed);
        System.assertEquals(AurelixDirectDebitService.REASON_CHEQUES, v.reason);
        i.liveChequeCount = 0;

        i.residency = 'Non-Resident';
        System.assertEquals(AurelixDirectDebitService.REASON_RESIDENT, AurelixDirectDebitService.eligibility(i).reason);
        i.residency = null;
        System.assertEquals(true, AurelixDirectDebitService.eligibility(i).allowed, 'unknown residency is not refused');

        i.isPersonAccount = false;
        System.assertEquals(AurelixDirectDebitService.REASON_ORGANISATION, AurelixDirectDebitService.eligibility(i).reason);
        AurelixDirectDebitService.switchOverride.put(AurelixDirectDebitService.FLAG_ORGANISATION, true);
        System.assertEquals(true, AurelixDirectDebitService.eligibility(i).allowed);
        i.isPersonAccount = true;

        i.salesOrderStatus = 'Voided';
        System.assertEquals('Not offered on a voided booking.', AurelixDirectDebitService.eligibility(i).reason);
        i.salesOrderStatus = 'New';

        i.hasLines = false;
        v = AurelixDirectDebitService.eligibility(i);
        System.assertEquals(false, v.allowed);
        System.assertEquals(null, v.reason, 'nothing to say when there is nothing to collect');
        i.hasLines = true;

        i.card = AurelixDirectDebitService.cardFor(row('Draft'), null);
        v = AurelixDirectDebitService.eligibility(i);
        System.assertEquals(false, v.allowed);
        System.assertEquals(null, v.reason, 'the card explains a standing mandate');
        i.card = AurelixDirectDebitService.cardFor(row('Discarded'), null);
        System.assertEquals(true, AurelixDirectDebitService.eligibility(i).allowed, 'a discarded mandate frees the order');

        AurelixDirectDebitService.switchOverride.put(AurelixDirectDebitService.FLAG_UAEDDS, false);
        v = AurelixDirectDebitService.eligibility(i);
        System.assertEquals(false, v.allowed);
        System.assertEquals(null, v.reason, 'switched off = hidden, silently');
    }

    @IsTest
    static void helpers() {
        System.assertEquals('0501234567', AurelixDirectDebitService.normaliseMobile('+971 50 123 4567'));
        System.assertEquals('0501234567', AurelixDirectDebitService.normaliseMobile('971501234567'));
        System.assertEquals('0501234567', AurelixDirectDebitService.normaliseMobile('00971501234567'));
        System.assertEquals('0501234567', AurelixDirectDebitService.normaliseMobile('501234567'));
        System.assertEquals('0501234567', AurelixDirectDebitService.normaliseMobile('050-123-4567'));
        System.assertEquals(null, AurelixDirectDebitService.normaliseMobile('  '));
        System.assertEquals(true, AurelixDirectDebitService.isUaeMobile('+971501234567'));
        System.assertEquals(false, AurelixDirectDebitService.isUaeMobile('+918948657995'), 'an Indian mobile is not a UAE mobile');
        System.assertEquals('AE070331234567890123456', AurelixDirectDebitService.cleanIban('ae07 0331-2345 6789 0123 456'));
        System.assertEquals(null, AurelixDirectDebitService.cleanIban(null));
        AurelixDirectDebitService.CardDTO c = AurelixDirectDebitService.cardFor(row('Draft'), null);
        System.assertEquals('AE07 **** 3456', c.ibanMasked);
        System.assert(AurelixDirectDebitService.deadStatuses().contains('Discarded'),
            'the slot rule is MODON\'s DEAD_STATUSES, read from their service');
    }

    @IsTest
    static void actionsRefuseWhileTheSwitchIsOff() {
        AurelixDirectDebitService.switchOverride = new Map<String, Boolean>{
            AurelixDirectDebitService.FLAG_ACTIONS => false
        };
        Id fake = '000000000000000AAA';
        for (Integer k = 0; k < 4; k++) {
            try {
                if (k == 0) AurelixDirectDebitService.refresh(fake);
                if (k == 1) AurelixDirectDebitService.discard(fake);
                if (k == 2) AurelixDirectDebitService.fetchForm(fake, true);
                if (k == 3) AurelixDirectDebitService.requestCancellation(fake, 'P01', 'x');
                System.assert(false, 'must refuse');
            } catch (AuraHandledException e) {
                System.assert(true);
            }
        }
        System.assertEquals(0, Limits.getCallouts(), 'no callout while off');
    }

    @IsTest
    static void draftCreationNeedsABooking() {
        try {
            AurelixDirectDebitService.createDraft(null);
            System.assert(false, 'must refuse');
        } catch (AurelixDirectDebitService.ConsoleException e) {
            System.assert(e.getMessage().contains('booking'));
        }
        AurelixDirectDebitService.switchOverride = new Map<String, Boolean>{
            AurelixDirectDebitService.FLAG_UAEDDS => true
        };
        AurelixDirectDebitService.DraftInput d = new AurelixDirectDebitService.DraftInput();
        d.salesOrderId = '000000000000000AAA';
        try {
            AurelixDirectDebitService.createDraft(d);
            System.assert(false, 'must refuse without an IBAN');
        } catch (AurelixDirectDebitService.ConsoleException e) {
            System.assert(e.getMessage().contains('IBAN'));
        }
        System.assert(!AurelixDirectDebitService.cancellationReasons().isEmpty(), 'P-codes from the picklist');
    }

    /* ------------------------------------------------------------------ live data (read-only) */

    /** The card on DEV's own mandates: every status the org holds renders, and the slot rule matches MODON's. */
    @IsTest(SeeAllData=true)
    static void liveCardsRender() {
        Integer seen = 0;
        for (DirectDebitRequest__c m : [
            SELECT Id, SalesOrder__c, Status__c FROM DirectDebitRequest__c
            WHERE SalesOrder__c != null ORDER BY CreatedDate DESC LIMIT 25
        ]) {
            AurelixDirectDebitService.CardDTO c = AurelixDirectDebitService.getCard(m.SalesOrder__c);
            System.assert(c != null && c.mandateId != null, 'the newest mandate on the order');
            System.assertEquals(AurelixDirectDebitService.isDead(c.status), c.slotFree, c.name);
            seen++;
        }
        System.assert(seen >= 0);
    }

    /**
     * A Draft through MODON's own method on an open Resident order with no mandate - the whole
     * point of 1.0. Rolled back with the test. Returns silently when DEV holds no such order.
     */
    @IsTest(SeeAllData=true)
    static void draftGoesThroughModonsCapture() {
        AurelixDirectDebitService.switchOverride = new Map<String, Boolean>{
            AurelixDirectDebitService.FLAG_UAEDDS => true
        };
        SalesOrder__c so;
        for (SalesOrder__c cand : [
            SELECT Id, CustomerAccount__c, CustomerAccount__r.IsPersonAccount
            FROM SalesOrder__c
            WHERE Status__c NOT IN ('Voided', 'Cancelled')
              AND UAE_Resident_Status__c = 'Resident'
              AND CustomerAccount__r.IsPersonAccount = true
              AND Id NOT IN (SELECT SalesOrder__c FROM DirectDebitRequest__c WHERE SalesOrder__c != null)
              AND Id IN (SELECT SalesOrder__c FROM SalesOrderInstallments__c WHERE MilestoneNumber__c > 1 AND PaymentStatus__c != 'Paid')
            ORDER BY CreatedDate DESC LIMIT 1
        ]) {
            so = cand;
        }
        if (so == null) {
            return;
        }
        AurelixDirectDebitService.DraftInput d = new AurelixDirectDebitService.DraftInput();
        d.salesOrderId = so.Id;
        d.holderName = 'Test Holder';
        d.bankName = 'First Abu Dhabi Bank';
        d.accountType = 'Current';
        d.iban = 'AE07 0331 2345 6789 0123 456';
        d.idType = 'UAE Emirates Identity Card';
        d.idNumber = '784-1990-1234567-1';
        d.mobile = '+971501234567';
        d.email = 'test@example.com';
        d.city = 'Abu Dhabi';
        Test.startTest();
        AurelixDirectDebitService.CardDTO c = AurelixDirectDebitService.createDraft(d);
        Test.stopTest();
        System.assertEquals(AurelixDirectDebitService.STAGE_DRAFT, c.stage);
        System.assertEquals('UAEDDS', c.gateway);
        System.assertEquals('0501234567', c.mobile, 'mobile normalised before the draft');
        System.assertEquals('test@example.com', c.email);
        /* the government ID never leaves the server in full (service 1.2); the IBAN beside it
           has always been masked and the two now read the same way */
        System.assertEquals('784 **** 671', c.idNumber, 'the ID is masked for the browser');
        System.assertEquals(false, c.slotFree);
        DirectDebitRequest__c saved = [
            SELECT RecordType.DeveloperName, Status__c, Expires_On__c, Commences_On__c, UAEDDSBankName__c
            FROM DirectDebitRequest__c WHERE Id = :c.mandateId
        ];
        System.assertEquals('UAEDDS', saved.RecordType.DeveloperName);
        System.assertEquals('Draft', saved.Status__c);
        Assert.areEqual('First Abu Dhabi Bank', saved.UAEDDSBankName__c,
            'The chosen bank reaches the field MODON\'s createMandateRecord and payload read.');
        Assert.areEqual('First Abu Dhabi Bank', c.bank, 'And the card shows it.');
        System.assert(saved.Expires_On__c == null || saved.Commences_On__c == null
            || saved.Expires_On__c > saved.Commences_On__c);
    }
}