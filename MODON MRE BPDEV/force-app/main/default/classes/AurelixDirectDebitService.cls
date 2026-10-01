/**
 * AurelixDirectDebitService - the Sales Console's one door into MODON's UAE Direct Debit System
 * (UAEDDS) build. It CALLS MODON's classes and never writes a DirectDebitRequest__c of its own.
 *
 * Version  Author       Date         Detail
 * 1.3      Aurelix Dev  22 Sep 2026  The bank travels as UAEDDSBankName__c. Since UAEDDS_LWCController 2.2
 *                                    (MODON, 21 Sep) createMandateRecord writes that field from the
 *                                    choice of the same name and no longer reads Customer_Bank_Name__c,
 *                                    and the vendor payload prefers it, so the bank chosen in the console
 *                                    was dropped. The card reads UAEDDSBankName__c and falls back to
 *                                    Customer_Bank_Name__c for mandates raised before the change, as
 *                                    UAEDDS_MandateService does. Previous version:
 *                                    _backup/2026-09-22_081155 (WL-019).
 * 1.2      Aurelix Dev  21 Sep 2026  The card printed the customer's government ID in full while
 *                                    masking the IBAN on the same row (seen on DD-00435). Masked
 *                                    to the same shape as the IBAN, and the unmasked value is no
 *                                    longer sent to the browser at all.
 * 1.1      Aurelix Dev  21 Sep 2026  MODON answered the action matrix (20 Sep): a sales
 *                                    representative gets mandate creation, the signed and unsigned
 *                                    forms, refresh status and initiating a cancellation. Discard
 *                                    was NOT granted and is never offered now; the state moves to
 *                                    financeOnlyDiscard so the card can name where it is done.
 * 1.0      Aurelix Dev  18 Sep 2026  SCW-125. Replaces the console's status-less mandate insert
 *                                    (SalesConsoleController 1.41) with MODON's own Draft
 *                                    (UAEDDS_LWCController.createMandateRecord: record type UAEDDS,
 *                                    Status Draft, e-mail, city, expiry = last instalment + 548 d)
 *                                    and reads the mandate's whole UAEDDS lifecycle for the card
 *                                    (c/mscMandateCard): stage, bank code and reference, dates,
 *                                    reasons, the four PDFs, and which action is legal now.
 *                                    Actions (refresh, discard, fetch a form, request a
 *                                    cancellation) sit behind DIRECT_DEBIT_ACTIONS, off until MODON
 *                                    grants reps the UAEDDS credential (plan D1) and confirms the
 *                                    matrix (D2). Reads run without sharing and in system mode on
 *                                    purpose: Sales Management holds no permission on
 *                                    DirectDebitRequest__c or on the UAEDDS-era fields, and MODON's
 *                                    own classes enforce no FLS either.
 *
 * Ownership: Aurelix. Nothing of MODON's is modified. Design:
 * docs/sales-console-direct-debit-deep-dive-and-plan-2026-09-18.md; evidence:
 * analysis/direct-debit/evidence-notes/.
 */
public with sharing class AurelixDirectDebitService {

    /* ------------------------------------------------------------------ switches */

    public static final String FLAG_UAEDDS = 'DIRECT_DEBIT_UAEDDS';
    public static final String FLAG_ACTIONS = 'DIRECT_DEBIT_ACTIONS';
    public static final String FLAG_ORGANISATION = 'DIRECT_DEBIT_ORGANISATION';
    @TestVisible private static Map<String, Boolean> switchOverride;

    /** Sales_Console_Config__mdt.<flag>.Is_Active__c, editable in Setup without a deployment. */
    public static Boolean isOn(String flag) {
        if (switchOverride != null && switchOverride.containsKey(flag)) {
            return switchOverride.get(flag) == true;
        }
        Sales_Console_Config__mdt cfg = Sales_Console_Config__mdt.getInstance(flag);
        return cfg != null && cfg.Is_Active__c == true;
    }

    /* ------------------------------------------------------------------ MODON's vocabulary */

    public static final String GATEWAY_UAEDDS = 'UAEDDS';
    public static final String ST_DRAFT = 'Draft';
    public static final String ST_REJECTED = 'Rejected';
    public static final String ST_PENDING = 'Pending Customer Signature';
    public static final String ST_SENT = 'Send To Bank';
    public static final String ST_ACTIVE = 'Approved By Bank';
    public static final String ST_ACTIVE_FAB = 'Approved';
    public static final String ST_REJECTED_BANK = 'Rejected By Bank';
    public static final String ST_DISCARDED = 'Discarded';
    public static final String ST_CANCEL_REQUESTED = 'Cancellation Requested';
    public static final String ST_CANCELLED = 'Cancelled';
    public static final String CODE_ACCP = 'ACCP';

    /** The one "slot is free" rule: MODON's own set, read from their service, never copied. */
    public static Set<String> deadStatuses() {
        return UAEDDS_MandateService.DEAD_STATUSES;
    }

    public static Boolean isDead(String status) {
        return String.isNotBlank(status) && deadStatuses().contains(status);
    }

    /* ------------------------------------------------------------------ the card's stages */

    public static final String STAGE_NONE = 'none';
    public static final String STAGE_LEGACY = 'legacy';
    public static final String STAGE_DRAFT = 'draft';
    public static final String STAGE_FINANCE_REJECTED = 'financeRejected';
    public static final String STAGE_PENDING = 'pending';
    public static final String STAGE_SENT = 'sent';
    public static final String STAGE_ACTIVE = 'active';
    public static final String STAGE_BANK_REJECTED = 'bankRejected';
    public static final String STAGE_DISCARDED = 'discarded';
    public static final String STAGE_CANCEL_PENDING = 'cancelPending';
    public static final String STAGE_CANCEL_REQUESTED = 'cancelRequested';
    public static final String STAGE_CANCELLED = 'cancelled';

    /** Short words for the milestone box; the card carries the longer wording in c/mscLabels. */
    private static final Map<String, String> STAGE_LABEL = new Map<String, String>{
        STAGE_LEGACY => 'Requested',
        STAGE_DRAFT => 'With Finance',
        STAGE_FINANCE_REJECTED => 'Rejected by Finance',
        STAGE_PENDING => 'Awaiting signature',
        STAGE_SENT => 'With the bank',
        STAGE_ACTIVE => 'Active',
        STAGE_BANK_REJECTED => 'Rejected by the bank',
        STAGE_DISCARDED => 'Discarded',
        STAGE_CANCEL_PENDING => 'Cancellation requested',
        STAGE_CANCEL_REQUESTED => 'Cancellation requested',
        STAGE_CANCELLED => 'Cancelled'
    };

    /** Stages in which the mandate still stands over the schedule (cheques are not offered). */
    private static final Set<String> COVERING_STAGES = new Set<String>{
        STAGE_LEGACY, STAGE_DRAFT, STAGE_PENDING, STAGE_SENT, STAGE_ACTIVE,
        STAGE_CANCEL_PENDING, STAGE_CANCEL_REQUESTED
    };

    /* ------------------------------------------------------------------ eligibility wording */

    public static final String NON_RESIDENT = 'Non-Resident';
    private static final Set<String> ORDER_CLOSED = new Set<String>{ 'Voided', 'Cancelled' };
    public static final String REASON_CHEQUES = 'Cheques are with Finance for these milestones.';
    public static final String REASON_RESIDENT =
        'Direct debit needs a UAE resident with an Emirates ID and a UAE mobile.';
    public static final String REASON_ORGANISATION =
        'Direct debit for a company is not offered from the console yet.';
    public static final String REASON_ORDER = 'Not offered on a {0} booking.';
    public static final String REASON_ACTIONS_OFF =
        'Actions on a mandate are taken in Modon\'s Direct Debit app for now.';

    public class ConsoleException extends Exception {}

    /* ------------------------------------------------------------------ DTOs */

    public class StepDTO {
        @AuraEnabled public String key;
        /** done | now | warn | off */
        @AuraEnabled public String state;
        /** yyyy-MM-dd, when the step has a date */
        @AuraEnabled public String factOn;
        public StepDTO(String key, String state, String factOn) {
            this.key = key; this.state = state; this.factOn = factOn;
        }
    }

    public class DocDTO {
        /** unsigned | signed | cancelUnsigned | cancelSigned */
        @AuraEnabled public String key;
        @AuraEnabled public String title;
        @AuraEnabled public Id contentDocumentId;
        @AuraEnabled public Datetime uploadedOn;
    }

    public class ActionsDTO {
        /** the switch DIRECT_DEBIT_ACTIONS; when false the flags below are what WOULD be legal */
        @AuraEnabled public Boolean enabled = false;
        @AuraEnabled public Boolean refresh = false;
        /**
         * 1.1 - ALWAYS FALSE for a console user. Discarding is legal on a pending mandate and the
         * service can still do it, but MODON's action matrix (20 Sep) grants a sales
         * representative mandate creation, the signed and unsigned forms, refresh status and
         * initiating a cancellation - and not discard, which stays with Finance in their own app.
         * financeOnlyDiscard carries the STATE, so the card can say where it is done rather than
         * drawing a button nobody may press.
         */
        @AuraEnabled public Boolean discard = false;
        @AuraEnabled public Boolean financeOnlyDiscard = false;
        @AuraEnabled public Boolean fetchUnsigned = false;
        @AuraEnabled public Boolean fetchSigned = false;
        @AuraEnabled public Boolean requestCancellation = false;
        @AuraEnabled public Boolean setUpAgain = false;
    }

    public class CardDTO {
        @AuraEnabled public Id mandateId;
        @AuraEnabled public Id salesOrderId;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public String gateway;
        @AuraEnabled public String stage = STAGE_NONE;
        @AuraEnabled public String stageLabel;
        @AuraEnabled public List<StepDTO> steps = new List<StepDTO>();
        @AuraEnabled public Boolean covering = false;
        @AuraEnabled public Boolean coversMilestones = false;
        @AuraEnabled public Boolean slotFree = true;
        @AuraEnabled public Boolean approved = false;
        @AuraEnabled public String bankStatusCode;
        @AuraEnabled public String bankStatusDescription;
        @AuraEnabled public String cbReference;
        @AuraEnabled public Datetime requestedOn;
        @AuraEnabled public Date approvedOn;
        @AuraEnabled public Date sentToBankOn;
        @AuraEnabled public Datetime signedOn;
        @AuraEnabled public Date bankApprovedOn;
        @AuraEnabled public Date rejectedOn;
        @AuraEnabled public Date discardedOn;
        @AuraEnabled public Date cancellationRequestedOn;
        @AuraEnabled public Datetime lastSyncOn;
        @AuraEnabled public String rejectionReason;
        @AuraEnabled public String cancellationReasonCode;
        @AuraEnabled public String cancellationReasonLabel;
        @AuraEnabled public String holderName;
        @AuraEnabled public String bank;
        @AuraEnabled public String accountType;
        @AuraEnabled public String ibanMasked;
        @AuraEnabled public String idType;
        @AuraEnabled public String idNumber;
        @AuraEnabled public String mobile;
        @AuraEnabled public String email;
        @AuraEnabled public String city;
        @AuraEnabled public Date commencesOn;
        @AuraEnabled public Date expiresOn;
        @AuraEnabled public Decimal maximumAmount;
        @AuraEnabled public List<DocDTO> documents = new List<DocDTO>();
        @AuraEnabled public Boolean hasUnsignedForm = false;
        @AuraEnabled public Boolean hasSignedForm = false;
        @AuraEnabled public ActionsDTO actions = new ActionsDTO();
        /** MODON's validation problems on a Draft - what Finance will have to fix before sending. */
        @AuraEnabled public List<String> problems = new List<String>();
        /** Set by an action: what just happened, in MODON's words. */
        @AuraEnabled public String message;
    }

    public class EligibilityInput {
        public String salesOrderStatus;
        public String residency;
        public Boolean isPersonAccount;
        public Integer liveChequeCount = 0;
        public Boolean hasLines = false;
        public CardDTO card;
    }

    public class EligibilityDTO {
        @AuraEnabled public Boolean allowed = false;
        /** Why not, in one sentence; null when nothing needs saying (switch off, no lines, a card). */
        @AuraEnabled public String reason;
    }

    public class DraftInput {
        public Id salesOrderId;
        public String holderName;
        public String bankName;
        public String accountType;
        public String iban;
        public String idType;
        public String idNumber;
        public String mobile;
        public String email;
        public String city;
    }

    public class OptionDTO {
        @AuraEnabled public String value;
        @AuraEnabled public String label;
        public OptionDTO(String value, String label) { this.value = value; this.label = label; }
    }

    /* ------------------------------------------------------------------ reads */

    /** The newest mandate on a booking, as the card shows it. */
    @AuraEnabled
    public static CardDTO getCard(Id salesOrderId) {
        try {
            return cardForOrder(salesOrderId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    public static CardDTO cardForOrder(Id salesOrderId) {
        Reader r = new Reader();
        DirectDebitRequest__c m = salesOrderId == null ? null : r.newest(salesOrderId);
        CardDTO card = cardFor(m, m == null ? new List<ContentDocumentLink>() : r.filesFor(m.Id));
        if (card.mandateId == null) {
            card.salesOrderId = salesOrderId;
        }
        if (card.stage == STAGE_DRAFT) {
            card.problems = draftProblems(m.Id);
        }
        return card;
    }

    public static CardDTO cardForMandate(Id mandateId) {
        Reader r = new Reader();
        DirectDebitRequest__c m = r.byId(mandateId);
        if (m == null) {
            throw new ConsoleException('This mandate could not be found.');
        }
        CardDTO card = cardFor(m, r.filesFor(m.Id));
        if (card.stage == STAGE_DRAFT) {
            card.problems = draftProblems(m.Id);
        }
        return card;
    }

    /** MODON's live rule check while the rep types (their 13 vendor rules, their wording). */
    @AuraEnabled
    public static List<UAEDDS_MandateService.Rule> checkDraft(Id salesOrderId, String draftJson) {
        try {
            return UAEDDS_LWCController.checkDraft(salesOrderId, draftJson);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /** Cancellation reason codes, as MODON's picklist labels them. */
    @AuraEnabled(cacheable=true)
    public static List<OptionDTO> cancellationReasons() {
        List<OptionDTO> out = new List<OptionDTO>();
        for (Schema.PicklistEntry e :
                DirectDebitRequest__c.Cancellation_Reason_Code__c.getDescribe().getPicklistValues()) {
            if (e.isActive()) {
                out.add(new OptionDTO(e.getValue(), e.getLabel()));
            }
        }
        return out;
    }

    /* ------------------------------------------------------------------ the rule */

    /**
     * Whether "Direct Debit" may be offered on this booking. The console keeps these gates
     * itself: MODON's service has no residency rule and no individual/organisation split.
     */
    public static EligibilityDTO eligibility(EligibilityInput input) {
        EligibilityDTO e = new EligibilityDTO();
        if (input == null || !isOn(FLAG_UAEDDS)) {
            return e;
        }
        if (input.card != null && input.card.slotFree != true) {
            return e; // the card explains the standing mandate
        }
        if (input.hasLines != true) {
            return e; // nothing after the down payment to collect
        }
        if (input.liveChequeCount != null && input.liveChequeCount > 0) {
            e.reason = REASON_CHEQUES;
            return e;
        }
        if (String.isNotBlank(input.salesOrderStatus) && ORDER_CLOSED.contains(input.salesOrderStatus)) {
            e.reason = REASON_ORDER.replace('{0}', input.salesOrderStatus.toLowerCase());
            return e;
        }
        if (input.residency == NON_RESIDENT) {
            e.reason = REASON_RESIDENT;
            return e;
        }
        if (input.isPersonAccount != true && !isOn(FLAG_ORGANISATION)) {
            e.reason = REASON_ORGANISATION;
            return e;
        }
        e.allowed = true;
        return e;
    }

    /* ------------------------------------------------------------------ writes */

    /**
     * The Draft, through MODON's own capture method: record type UAEDDS, Gateway UAEDDS, Status
     * Draft, e-mail, city, config defaults, expiry corrected to + 548 days; the trigger derives
     * commences / maximum / originator / OIC and creates the "Bilingual Direct Debit Authority
     * Registration" placeholder. The caller (SalesConsoleController) has already run the KYC,
     * cheque, order-status and residency gates.
     */
    public static CardDTO createDraft(DraftInput input) {
        if (input == null || input.salesOrderId == null) {
            throw new ConsoleException('No booking was supplied.');
        }
        if (!isOn(FLAG_UAEDDS)) {
            throw new ConsoleException('Direct Debit is switched off in the console.');
        }
        String iban = cleanIban(input.iban);
        if (String.isBlank(iban)) {
            throw new ConsoleException('The Customer IBAN Number is required.');
        }
        Map<String, Object> choices = new Map<String, Object>{
            'Customer_Bank_Account_Name__c' => trimOrNull(input.holderName),
            'UAEDDSBankName__c' => trimOrNull(input.bankName),
            'Customer_Bank_Account_Type__c' => trimOrNull(input.accountType),
            'Customer_IBAN_Number__c' => iban,
            'Customer_Id_Type__c' => trimOrNull(input.idType),
            'Customer_ID_Number__c' => trimOrNull(input.idNumber),
            'Customer_Mobile__c' => normaliseMobile(input.mobile),
            'Customer_Email__c' => trimOrNull(input.email),
            'Customer_City__c' => trimOrNull(input.city)
        };
        Id mandateId;
        try {
            mandateId = UAEDDS_LWCController.createMandateRecord(input.salesOrderId, choices);
        } catch (AuraHandledException e) {
            /* AuraHandledException hides its text from Apex callers ("Script-thrown exception");
               MODON's only refusal here is a standing mandate or the creation switch. */
            throw new ConsoleException(
                'Modon\'s Direct Debit screen refused the draft: a live mandate may already stand '
                + 'on this booking, or mandate creation is switched off.');
        }
        return cardForMandate(mandateId);
    }

    /** Refresh bank status - MODON's callout, then the card re-read. */
    @AuraEnabled
    public static CardDTO refresh(Id mandateId) {
        try {
            requireActions();
            CardDTO before = cardForMandate(mandateId);
            if (before.actions.refresh != true) {
                throw new ConsoleException('The bank status cannot be refreshed in this state.');
            }
            outcome(UAEDDS_MandateService.refreshStatus(mandateId));
            CardDTO after = cardForMandate(mandateId);
            after.message = 'Status refreshed from the bank.';
            return after;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /** Discard - only while the bank still shows it pending (PNDG / RQXP). */
    @AuraEnabled
    public static CardDTO discard(Id mandateId) {
        try {
            requireActions();
            CardDTO before = cardForMandate(mandateId);
            if (before.actions.discard != true) {
                /* 1.1 - reached whenever a console user calls this, by design: MODON reserve
                   discard for Finance. Kept rather than deleted so the capability is one flag
                   away if that decision changes. */
                throw new ConsoleException(
                    'Discarding a mandate is done by Finance in Modon\'s Direct Debit app.');
            }
            outcome(UAEDDS_MandateService.discard(mandateId));
            CardDTO after = cardForMandate(mandateId);
            after.message = 'Discarded. Nothing is left at the bank.';
            return after;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /** Fetch the unsigned or signed mandate PDF onto MODON's document row. */
    @AuraEnabled
    public static CardDTO fetchForm(Id mandateId, Boolean signed) {
        try {
            requireActions();
            CardDTO before = cardForMandate(mandateId);
            Boolean legal = signed == true ? before.actions.fetchSigned : before.actions.fetchUnsigned;
            if (legal != true) {
                throw new ConsoleException('That form cannot be fetched in this state.');
            }
            outcome(UAEDDS_MandateService.fetchDocument(mandateId, signed == true));
            CardDTO after = cardForMandate(mandateId);
            after.message = (signed == true ? 'Signed' : 'Unsigned') + ' form filed with the mandate.';
            return after;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Raise a cancellation for Finance: MODON's fields only (Cancellation_Initiated__c, the reason
     * code, a note), no callout. Finance's Cancel mandate sends it to the bank. MODON's validation
     * rule UAEDDS_Cancellation_Approved demands a live (ACCP) mandate and a reason code.
     */
    @AuraEnabled
    public static CardDTO requestCancellation(Id mandateId, String reasonCode, String comment) {
        try {
            requireActions();
            if (String.isBlank(reasonCode)) {
                throw new ConsoleException('A cancellation reason is required.');
            }
            CardDTO before = cardForMandate(mandateId);
            if (before.actions.requestCancellation != true) {
                throw new ConsoleException('Only a mandate the bank has approved can be cancelled.');
            }
            new Reader().raiseCancellation(mandateId, reasonCode, comment);
            CardDTO after = cardForMandate(mandateId);
            after.message = 'Cancellation requested. Finance sends it to the bank.';
            return after;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    private static void requireActions() {
        if (!isOn(FLAG_ACTIONS)) {
            throw new ConsoleException(REASON_ACTIONS_OFF);
        }
    }

    /** A vendor refusal arrives as ok=false with the vendor's words; surface those. */
    private static void outcome(UAEDDS_Service.Result r) {
        if (r == null) {
            throw new ConsoleException('The bank did not answer.');
        }
        if (r.ok != true) {
            throw new ConsoleException(
                String.isBlank(r.errorText)
                    ? 'The bank did not accept that. The call is in the Direct Debit logs.'
                    : r.errorText);
        }
    }

    /* ------------------------------------------------------------------ the card */

    @TestVisible
    private static CardDTO cardFor(DirectDebitRequest__c m, List<ContentDocumentLink> files) {
        CardDTO c = new CardDTO();
        if (m == null) {
            return c;
        }
        c.mandateId = m.Id;
        c.salesOrderId = m.SalesOrder__c;
        c.name = m.Name;
        c.status = m.Status__c;
        c.gateway = m.Gateway__c;
        c.stage = stageOf(m);
        c.stageLabel = STAGE_LABEL.get(c.stage);
        c.covering = COVERING_STAGES.contains(c.stage);
        c.coversMilestones = c.stage == STAGE_ACTIVE;
        c.slotFree = isDead(m.Status__c);
        c.approved = m.Approve__c == true;
        c.bankStatusCode = m.Bank_Status_Code__c;
        c.bankStatusDescription = m.Bank_Status_Description__c;
        c.cbReference = m.CB_DDA_Reference__c;
        c.requestedOn = m.CreatedDate;
        c.approvedOn = m.Approved_Date__c;
        c.sentToBankOn = m.Sent_To_Bank_Date__c;
        c.signedOn = m.Signed_Form_Received_Date__c;
        c.bankApprovedOn = m.Bank_Approved_Date__c;
        c.rejectedOn = m.Rejected_Date__c;
        c.discardedOn = m.Discarded_Date__c;
        c.cancellationRequestedOn = m.Cancellation_Date_By_Finance__c;
        c.lastSyncOn = m.Last_Status_Sync__c;
        c.rejectionReason = m.Rejection_Reason__c;
        c.cancellationReasonCode = m.Cancellation_Reason_Code__c;
        c.cancellationReasonLabel = reasonLabel(m.Cancellation_Reason_Code__c);
        c.holderName = m.Customer_Bank_Account_Name__c;
        c.bank = String.isNotBlank(m.UAEDDSBankName__c) ? m.UAEDDSBankName__c : m.Customer_Bank_Name__c;
        c.accountType = m.Customer_Bank_Account_Type__c;
        c.ibanMasked = maskIban(m.Customer_IBAN_Number__c);
        c.idType = m.Customer_Id_Type__c;
        /* 1.2 - an Emirates ID or passport number is identity, like the IBAN under it */
        c.idNumber = maskId(m.Customer_ID_Number__c);
        c.mobile = m.Customer_Mobile__c;
        c.email = m.Customer_Email__c;
        c.city = m.Customer_City__c;
        c.commencesOn = m.Commences_On__c;
        c.expiresOn = m.Expires_On__c;
        c.maximumAmount = m.Maximum_Amount__c;
        c.documents = documentsFor(m.Name, files);
        for (DocDTO d : c.documents) {
            if (d.key == 'unsigned') c.hasUnsignedForm = true;
            if (d.key == 'signed') c.hasSignedForm = true;
        }
        c.steps = stepsFor(c);
        c.actions = actionsFor(m, c);
        return c;
    }

    @TestVisible
    private static String stageOf(DirectDebitRequest__c m) {
        String s = m.Status__c;
        if (String.isBlank(s)) return STAGE_LEGACY;
        if (s == ST_DRAFT) return STAGE_DRAFT;
        if (s == ST_REJECTED) return STAGE_FINANCE_REJECTED;
        if (s == ST_PENDING) return STAGE_PENDING;
        if (s == ST_SENT) return STAGE_SENT;
        if (s == ST_ACTIVE || s == ST_ACTIVE_FAB) {
            /* a console-raised cancellation waits for Finance: initiated, nothing at the bank yet */
            return m.Cancellation_Initiated__c == true && String.isBlank(m.DDCA_Id__c)
                ? STAGE_CANCEL_PENDING : STAGE_ACTIVE;
        }
        if (s == ST_REJECTED_BANK) return STAGE_BANK_REJECTED;
        if (s == ST_DISCARDED) return STAGE_DISCARDED;
        if (s == ST_CANCEL_REQUESTED) return STAGE_CANCEL_REQUESTED;
        if (s == ST_CANCELLED) return STAGE_CANCELLED;
        /* FAB-era intermediate values (Finance Team Approved, Sales Team Verified) */
        return STAGE_LEGACY;
    }

    private static List<StepDTO> stepsFor(CardDTO c) {
        String raised = day(c.requestedOn);
        String finance = c.approvedOn != null ? dayOf(c.approvedOn) : dayOf(c.sentToBankOn);
        String signed = day(c.signedOn);
        String bank = dayOf(c.bankApprovedOn);
        String st = c.stage;
        List<StepDTO> out = new List<StepDTO>();
        if (st == STAGE_LEGACY || st == STAGE_DRAFT) {
            out.add(new StepDTO('raised', 'done', raised));
            out.add(new StepDTO('finance', 'now', null));
            out.add(new StepDTO('signature', 'off', null));
            out.add(new StepDTO('bank', 'off', null));
        } else if (st == STAGE_FINANCE_REJECTED) {
            out.add(new StepDTO('raised', 'done', raised));
            out.add(new StepDTO('finance', 'warn', dayOf(c.rejectedOn)));
            out.add(new StepDTO('signature', 'off', null));
            out.add(new StepDTO('bank', 'off', null));
        } else if (st == STAGE_PENDING) {
            out.add(new StepDTO('raised', 'done', raised));
            out.add(new StepDTO('finance', 'done', finance));
            out.add(new StepDTO('signature', 'now', null));
            out.add(new StepDTO('bank', 'off', null));
        } else if (st == STAGE_SENT) {
            out.add(new StepDTO('raised', 'done', raised));
            out.add(new StepDTO('finance', 'done', finance));
            out.add(new StepDTO('signature', 'done', signed));
            out.add(new StepDTO('bank', 'now', null));
        } else if (st == STAGE_ACTIVE || st == STAGE_CANCEL_PENDING || st == STAGE_CANCEL_REQUESTED) {
            out.add(new StepDTO('raised', 'done', raised));
            out.add(new StepDTO('finance', 'done', finance));
            out.add(new StepDTO('signature', 'done', signed));
            out.add(new StepDTO('bank', 'done', bank));
        } else if (st == STAGE_BANK_REJECTED) {
            out.add(new StepDTO('raised', 'done', raised));
            out.add(new StepDTO('finance', 'done', finance));
            out.add(new StepDTO('signature', signed == null ? 'off' : 'done', signed));
            out.add(new StepDTO('bank', 'warn', null));
        } else if (st == STAGE_DISCARDED) {
            out.add(new StepDTO('raised', 'done', raised));
            out.add(new StepDTO('finance', 'done', finance));
            out.add(new StepDTO('signature', 'warn', dayOf(c.discardedOn)));
            out.add(new StepDTO('bank', 'off', null));
        } else if (st == STAGE_CANCELLED) {
            out.add(new StepDTO('raised', 'done', raised));
            out.add(new StepDTO('finance', 'done', finance));
            out.add(new StepDTO('signature', 'done', signed));
            out.add(new StepDTO('bank', 'warn', null));
        }
        return out;
    }

    /**
     * Which actions are legal now - MODON's own conditions (UAEDDS_LWCController.getMandate)
     * restated for a rep's surface: never Approve / Reject / Cancel at the bank. A mandate
     * whose cancellation is with the customer is not refreshed from here: MODON's poller does
     * not watch that status and a refresh that still reads ACCP would overwrite it (plan D6).
     */
    private static ActionsDTO actionsFor(DirectDebitRequest__c m, CardDTO c) {
        ActionsDTO a = new ActionsDTO();
        a.enabled = isOn(FLAG_ACTIONS);
        Boolean atBank = m.Gateway__c == GATEWAY_UAEDDS && String.isNotBlank(m.DDA_Id__c);
        Boolean live = atBank && m.Bank_Status_Code__c == CODE_ACCP;
        String st = c.stage;
        a.refresh = atBank && (st == STAGE_PENDING || st == STAGE_SENT || st == STAGE_ACTIVE);
        /* 1.1 - the state, not an offer: see ActionsDTO.discard. */
        a.financeOnlyDiscard = atBank && st == STAGE_PENDING
            && UAEDDS_MandateService.isDiscardable(m.Bank_Status_Code__c);
        a.discard = false;
        a.fetchUnsigned = atBank && c.hasUnsignedForm != true;
        a.fetchSigned = atBank && c.hasSignedForm != true
            && (st == STAGE_SENT || st == STAGE_ACTIVE || st == STAGE_CANCEL_PENDING
                || st == STAGE_CANCEL_REQUESTED || st == STAGE_CANCELLED);
        a.requestCancellation = live && st == STAGE_ACTIVE
            && String.isBlank(m.DDCA_Id__c) && m.Cancellation_Initiated__c != true;
        a.setUpAgain = c.slotFree == true;
        return a;
    }

    /** The four PDFs, matched on the titles UAEDDS_DocumentService / CancellationService write. */
    private static List<DocDTO> documentsFor(String name, List<ContentDocumentLink> files) {
        Map<String, String> keyByTitle = new Map<String, String>{
            name + ' - Unsigned Mandate' => 'unsigned',
            name + ' - Signed Mandate' => 'signed',
            name + ' - Cancellation Form Unsigned' => 'cancelUnsigned',
            name + ' - Cancellation Form Signed' => 'cancelSigned'
        };
        Map<String, DocDTO> byKey = new Map<String, DocDTO>();
        for (ContentDocumentLink l : files == null ? new List<ContentDocumentLink>() : files) {
            String title = l.ContentDocument == null ? null : l.ContentDocument.Title;
            String key = title == null ? null : keyByTitle.get(title);
            if (key == null || byKey.containsKey(key)) {
                continue; // newest first: the first hit wins
            }
            DocDTO d = new DocDTO();
            d.key = key;
            d.title = title;
            d.contentDocumentId = l.ContentDocumentId;
            d.uploadedOn = l.ContentDocument.CreatedDate;
            byKey.put(key, d);
        }
        List<DocDTO> out = new List<DocDTO>();
        for (String k : new List<String>{ 'unsigned', 'signed', 'cancelUnsigned', 'cancelSigned' }) {
            if (byKey.containsKey(k)) out.add(byKey.get(k));
        }
        return out;
    }

    /** MODON's rule list for a saved Draft, read only; never fatal for the card. */
    private static List<String> draftProblems(Id mandateId) {
        try {
            List<String> problems = UAEDDS_LWCController.validateMandate(mandateId);
            return problems == null ? new List<String>() : problems;
        } catch (Exception e) {
            return new List<String>();
        }
    }

    /* ------------------------------------------------------------------ helpers */

    /** +971 50 123 4567, 971501234567 and 0501234567 all become 0501234567 (MODON's rule). */
    @TestVisible
    private static String normaliseMobile(String raw) {
        if (String.isBlank(raw)) {
            return null;
        }
        String v = raw.replaceAll('[\\s\\-\\(\\)\\.]', '');
        if (v.startsWith('+971')) {
            v = '0' + v.substring(4);
        } else if (v.startsWith('00971')) {
            v = '0' + v.substring(5);
        } else if (v.startsWith('971') && v.length() >= 12) {
            v = '0' + v.substring(3);
        } else if (v.length() == 9 && v.startsWith('5')) {
            v = '0' + v;
        }
        return v;
    }

    @TestVisible
    private static Boolean isUaeMobile(String raw) {
        String v = normaliseMobile(raw);
        return v != null && Pattern.matches('05[0-9]{8}', v);
    }

    @TestVisible
    private static String cleanIban(String raw) {
        return String.isBlank(raw) ? null : raw.replaceAll('[\\s\\-]', '').toUpperCase();
    }

    private static String maskIban(String iban) {
        if (String.isBlank(iban)) {
            return null;
        }
        String flat = iban.replaceAll('\\s', '');
        if (flat.length() <= 8) {
            return flat;
        }
        return flat.substring(0, 4) + ' **** ' + flat.substring(flat.length() - 4);
    }

    /**
     * 1.2 - the same shape as maskIban: enough of the ends for a representative to recognise the
     * document they typed, never enough to reuse it. Short values are hidden entirely rather than
     * half-revealed.
     */
    private static String maskId(String raw) {
        if (String.isBlank(raw)) {
            return null;
        }
        String flat = raw.replaceAll('[\\s\\-]', '');
        if (flat.length() <= 6) {
            return '*'.repeat(flat.length());
        }
        return flat.substring(0, 3) + ' **** ' + flat.substring(flat.length() - 3);
    }

    private static String trimOrNull(String v) {
        return String.isBlank(v) ? null : v.trim();
    }

    private static String day(Datetime dt) {
        return dt == null ? null : dt.format('yyyy-MM-dd');
    }

    private static String dayOf(Date d) {
        return d == null ? null : String.valueOf(d);
    }

    private static String reasonLabel(String code) {
        if (String.isBlank(code)) {
            return null;
        }
        for (Schema.PicklistEntry e :
                DirectDebitRequest__c.Cancellation_Reason_Code__c.getDescribe().getPicklistValues()) {
            if (e.getValue() == code) {
                return e.getLabel();
            }
        }
        return code;
    }

    /* ------------------------------------------------------------------ elevated reads */

    /**
     * Without sharing, on purpose: Sales Management has no access to DirectDebitRequest__c, and a
     * mandate raised by somebody else (Finance, MODON's own screen) must still show and still
     * block a second. System mode: the UAEDDS-era fields carry no FLS for console users.
     */
    private without sharing class Reader {

        private final String FIELDS =
            'Id, Name, SalesOrder__c, Status__c, Gateway__c, Approve__c, Reject__c, '
            + 'Rejection_Reason__c, Rejected_Date__c, Approved_Date__c, Bank_Status_Code__c, '
            + 'Bank_Status_Description__c, CB_DDA_Reference__c, DDA_Id__c, DDCA_Id__c, '
            + 'Sent_To_Bank_Date__c, Signed_Form_Received_Date__c, Last_Status_Sync__c, '
            + 'Discarded_Date__c, Bank_Approved_Date__c, Cancellation_Reason_Code__c, '
            + 'Cancellation_Initiated__c, Cancellation_Approved__c, Cancellation_Date_By_Finance__c, '
            + 'Commences_On__c, Expires_On__c, Maximum_Amount__c, Customer_Bank_Account_Name__c, '
            + 'Customer_Bank_Name__c, UAEDDSBankName__c, Customer_Bank_Account_Type__c, Customer_IBAN_Number__c, '
            + 'Customer_Id_Type__c, Customer_ID_Number__c, Customer_Mobile__c, Customer_Email__c, '
            + 'Customer_City__c, CreatedDate';

        public DirectDebitRequest__c newest(Id salesOrderId) {
            List<DirectDebitRequest__c> found = Database.query(
                'SELECT ' + FIELDS + ' FROM DirectDebitRequest__c WHERE SalesOrder__c = :salesOrderId '
                + 'ORDER BY CreatedDate DESC LIMIT 1');
            return found.isEmpty() ? null : found[0];
        }

        public DirectDebitRequest__c byId(Id mandateId) {
            List<DirectDebitRequest__c> found = Database.query(
                'SELECT ' + FIELDS + ' FROM DirectDebitRequest__c WHERE Id = :mandateId LIMIT 1');
            return found.isEmpty() ? null : found[0];
        }

        /** The files on MODON's Documents__c row(s) for the mandate, newest first. */
        public List<ContentDocumentLink> filesFor(Id mandateId) {
            Set<Id> rows = new Set<Id>();
            for (Documents__c d : [
                SELECT Id FROM Documents__c WHERE Direct_Debit_Request__c = :mandateId
            ]) {
                rows.add(d.Id);
            }
            if (rows.isEmpty()) {
                return new List<ContentDocumentLink>();
            }
            return [
                SELECT ContentDocumentId, ContentDocument.Title, ContentDocument.CreatedDate
                FROM ContentDocumentLink
                WHERE LinkedEntityId IN :rows
                ORDER BY ContentDocument.CreatedDate DESC
            ];
        }

        public void raiseCancellation(Id mandateId, String reasonCode, String comment) {
            DirectDebitRequest__c m = byId(mandateId);
            String note = 'Cancellation requested from the Sales Console by ' + UserInfo.getName()
                + ' on ' + Datetime.now().format('dd MMM yyyy HH:mm')
                + (String.isBlank(comment) ? '' : ': ' + comment.trim());
            List<DirectDebitRequest__c> current = [
                SELECT Comments__c FROM DirectDebitRequest__c WHERE Id = :mandateId LIMIT 1
            ];
            String existing = current.isEmpty() ? null : current[0].Comments__c;
            update new DirectDebitRequest__c(
                Id = mandateId,
                Cancellation_Initiated__c = true,
                Cancellation_Reason_Code__c = reasonCode,
                Comments__c = String.isBlank(existing) ? note : existing + '\n' + note
            );
        }
    }
}