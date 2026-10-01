/**********************************************************************************************************************
* Name               : SalesOrderReminderBatch
* Description        : SalesOrderReminderBatch to send the reminder
* Usage              : SalesOrderReminderBatch
* Created By         : Arvind Kesharani
* --------------------------------------------------------------------------------------------------------------------
* Version  Author                           Date            Description
* -------  -------------------------------- --------------- -------------------------------------------------------
* 1.0      Arvind Kesharani              19 AUG 2026         Initial Draft (Geoapify)
* 1.1      Arvind Kesharani              19 SEP 2026         Re-enabled Track 2; Resident exclusion for Track 1 & 2
* 1.2      Arvind Kesharani              19 SEP 2026         Added Track 3: Bank Transfer Receipt Approval reminder
* 1.3      Arvind Kesharani              19 SEP 2026         Fixed exclusion: Non-Resident (not Resident) excluded from Track 1 & 2
* 1.4      Arvind Kesharani              01 OCT 2026         Track 1 only: exclude DDA Initiated/Approved, exclude Pre-Approved
*                                                            Payment Plans, treat installment as paid if PaymentStatus__c is
*                                                            Paid / Partially Paid (in addition to existing Receipt check)
* 1.5      Arvind Kesharani              01 OCT 2026         Track 1: Pre-Approved Payment Plans are no longer excluded;
*                                                            instead only the 5th installment is skipped for them

****************************************************************************************************/
global class SalesOrderReminderBatch implements Database.Batchable<sObject>, Database.Stateful, Schedulable {

    private static final String TRACK_INSTALLMENT_2_PLUS = 'INSTALLMENT_2_PLUS';
    private static final String TRACK_INSTALLMENT_1_FEE = 'INSTALLMENT_1_FEE';
    private static final String TRACK_RECEIPT_APPROVAL_DP = 'RECEIPT_APPROVAL_DP';
    private static final String TRACK_RECEIPT_APPROVAL_ADM = 'RECEIPT_APPROVAL_ADM';

    // v1.4 — Track 1 only: SOs with these DDA statuses get NO Track 1 reminders
    private static final Set<String> TRACK1_EXCLUDED_DDA_STATUSES = new Set<String>{
        'Initiated', 'Approved'
    };

    // v1.5 — Track 1 only: for Pre-Approved Payment Plans, this installment is never reminded
    private static final Decimal PRE_APPROVAL_SKIPPED_MILESTONE = 5;

    // v1.4 — Track 1 only: installments with these statuses are treated as paid
    private static final Set<String> PAID_INSTALLMENT_STATUSES = new Set<String>{
        'Paid', 'Partially Paid'
    };

    // key = Track__c + '|' + Days_Since_SO__c
    private Map<String, Escalation_Tier__mdt> tierByTrackAndDays;

    // "Pretend today is this date" — defaults to the real Date.today() for the
    // nightly scheduled run, but can be overridden for manual testing.
    private Date effectiveToday;

    // Optional: when set, restricts the batch to ONLY these Sales Order Ids —
    // used for safe manual testing so a simulated "asOfDate" doesn't sweep in
    // unrelated real Sales Orders.
    private Set<Id> restrictToSoIds;

    public SalesOrderReminderBatch() {
        this.effectiveToday = Date.today();
    }

    public SalesOrderReminderBatch(Date asOfDateOverride) {
        this.effectiveToday = asOfDateOverride;
    }

    public SalesOrderReminderBatch(Date asOfDateOverride, Set<Id> restrictToSoIds) {
        this.effectiveToday = asOfDateOverride;
        this.restrictToSoIds = restrictToSoIds;
    }

    // ---------------------------------------------------------------
    // Schedulable entry point
    // ---------------------------------------------------------------
    global void execute(SchedulableContext sc) {
        Database.executeBatch(new SalesOrderReminderBatch(), 200);
    }

    // ---------------------------------------------------------------
    // Batchable
    // ---------------------------------------------------------------
    global Database.QueryLocator start(Database.BatchableContext bc) {

        tierByTrackAndDays = new Map<String, Escalation_Tier__mdt>();
        for (Escalation_Tier__mdt t : [
            SELECT Days_Since_SO__c, Tier_Code__c, Tier_Label__c, Track__c, Is_Repeating__c
            FROM Escalation_Tier__mdt
        ]) {
            if (t.Days_Since_SO__c != null && String.isNotBlank(t.Track__c)) {
                String key = t.Track__c + '|' + Integer.valueOf(t.Days_Since_SO__c);
                tierByTrackAndDays.put(key, t);
            }
        }

        // Cutover date: SOs created before this are excluded entirely.
        Date cutoverDate = Date.valueOf(Label.Sales_Order_Reminder_Cutover_Date);

        String whereClause = 'WHERE Status__c NOT IN (\'Voided\', \'Cancelled\') '
            + 'AND Source_Entity__c != \'Modon - Egypt\' '
            + 'AND CreatedDate >= :cutoverDate '
            + 'AND Unit__r.Phase__r.Project__r.Exclude_From_Reminders__c != true';

        if (restrictToSoIds != null && !restrictToSoIds.isEmpty()) {
            whereClause += ' AND Id IN :restrictToSoIds';
        }

        // NOTE: Primary_Contact_Residence_Status__c is selected but NOT
        // filtered out here — Track 3 needs both Residents and Non-Residents
        // (just on different timers). The Non-Resident exclusion for
        // Track 1 & 2 is applied in-memory below instead.
        // v1.4/1.5: DDA_Status__c and PaymentPlan__r.Pre_Approval__c are likewise
        // selected but NOT filtered here — they only affect Track 1, so the
        // checks are applied in-memory.
        String query = 'SELECT Id, Name, CreatedDate, Status__c, Source_Entity__c, Reminders_Sent__c, '
            + 'Down_Payment_Status__c, ADM_Fees_and_Dari__c, Pending_Down_Payment__c, Pending_ADM_Amount__c, '
            + 'Primary_Contact_Residence_Status__c, DDA_Status__c, PaymentPlan__c, PaymentPlan__r.Pre_Approval__c '
            + 'FROM SalesOrder__c ' + whereClause;

        return Database.getQueryLocator(query);
    }

    global void execute(Database.BatchableContext bc, List<SalesOrder__c> scope) {

        Set<Id> soIds = new Set<Id>();
        for (SalesOrder__c so : scope) {
            soIds.add(so.Id);
        }

        // Flat query (no nested subqueries in the batch's QueryLocator — see
        // note in earlier versions about the "Aggregate query has too many
        // rows" platform bug this avoids).
        Map<Id, List<SalesOrderInstallments__c>> installmentsBySoId = new Map<Id, List<SalesOrderInstallments__c>>();
        for (SalesOrderInstallments__c inst : [
            SELECT Id, SalesOrder__c, MilestoneNumber__c, MilestoneDescription__c, PaymentStatus__c,
                (SELECT Id FROM Receipts__r LIMIT 1)
            FROM SalesOrderInstallments__c
            WHERE SalesOrder__c IN :soIds
            AND MilestoneNumber__c != null
            ORDER BY MilestoneNumber__c ASC
        ]) {
            if (!installmentsBySoId.containsKey(inst.SalesOrder__c)) {
                installmentsBySoId.put(inst.SalesOrder__c, new List<SalesOrderInstallments__c>());
            }
            installmentsBySoId.get(inst.SalesOrder__c).add(inst);
        }

        // ---- Track 3 support: qualifying Down Payment / ADM receipts ----
        Map<Id, List<Receipt__c>> qualifyingReceiptsBySoId = new Map<Id, List<Receipt__c>>();
        for (Receipt__c r : [
            SELECT Id, SalesOrder__c, CreatedDate, Milestone__c, Is_ADM_Fees_and_Dari_charges__c,
                Modeofpayment__c, Receipt_Approved_By__c
            FROM Receipt__c
            WHERE SalesOrder__c IN :soIds
            AND Modeofpayment__c = 'Bank Transfer'
            AND Receipt_Approved_By__c = null
            AND (Milestone__c = 1 OR Is_ADM_Fees_and_Dari_charges__c = true)
        ]) {
            if (!qualifyingReceiptsBySoId.containsKey(r.SalesOrder__c)) {
                qualifyingReceiptsBySoId.put(r.SalesOrder__c, new List<Receipt__c>());
            }
            qualifyingReceiptsBySoId.get(r.SalesOrder__c).add(r);
        }

        List<SalesOrder__c> toUpdate = new List<SalesOrder__c>();

        for (SalesOrder__c so : scope) {
            List<SalesOrderInstallments__c> installments = installmentsBySoId.containsKey(so.Id)
                ? installmentsBySoId.get(so.Id)
                : new List<SalesOrderInstallments__c>();

            Integer daysSinceSO = so.CreatedDate.date().daysBetween(effectiveToday);
            Set<String> alreadySent = parseSentTiers(so.Reminders_Sent__c);
            Boolean changed = false;

            // ---- Requirement 1 (CORRECTED): Non-Residents get NO Track 1 / Track 2 reminders ----
            Boolean isResident = (so.Primary_Contact_Residence_Status__c == 'Resident');
            Boolean isNonResident = (so.Primary_Contact_Residence_Status__c == 'Non-Resident');

            if (!isNonResident) {
                // ---- Track 1: installment >= 2 unpaid, excluding handover ----
                // v1.4: skip Track 1 entirely if DDA is Initiated/Approved.
                // v1.5: Pre-Approved plans still get Track 1, minus the 5th installment.
                if (!isExcludedFromTrack1(so)) {
                    SalesOrderInstallments__c targetInstallment =
                        findNextQualifyingInstallment(installments, isPreApprovedPlan(so));
                    if (targetInstallment != null) {
                        Escalation_Tier__mdt tier1 = tierByTrackAndDays.get(TRACK_INSTALLMENT_2_PLUS + '|' + daysSinceSO);
                        if (tier1 != null && (!alreadySent.contains(tier1.Tier_Code__c) || tier1.Is_Repeating__c)) {
                            if (safeTriggerReminderFlow(so, tier1.Tier_Code__c)) {
                                alreadySent.add(tier1.Tier_Code__c);
                                changed = true;
                                logTierTriggered(so, tier1, 'Installment: ' + targetInstallment.Id
                                    + ', MilestoneNumber: ' + targetInstallment.MilestoneNumber__c);
                            }
                        }
                    }
                }

                // ---- Track 2: Down Payment and/or ADM & Dari, meaningfully outstanding ----
                if (isDownPaymentOrAdmOutstanding(so)) {
                    Escalation_Tier__mdt tier2 = tierByTrackAndDays.get(TRACK_INSTALLMENT_1_FEE + '|' + daysSinceSO);
                    if (tier2 != null && (!alreadySent.contains(tier2.Tier_Code__c) || tier2.Is_Repeating__c)) {
                        if (safeTriggerReminderFlow(so, tier2.Tier_Code__c)) {
                            alreadySent.add(tier2.Tier_Code__c);
                            changed = true;
                            logTierTriggered(so, tier2, 'Track: ' + TRACK_INSTALLMENT_1_FEE);
                        }
                    }
                }
            }

            // ---- Track 3: Bank Transfer Receipt Approval Pending ----
            // Runs for Residents AND Non-Residents (only the day threshold differs).
            if (qualifyingReceiptsBySoId.containsKey(so.Id)) {
                Integer expectedDays = isResident ? 3 : 7;

                for (Receipt__c r : qualifyingReceiptsBySoId.get(so.Id)) {
                    Boolean isDownPaymentReceipt = (r.Milestone__c == 1);

                    // DP receipt checks Down_Payment_Status__c; ADM receipt checks ADM_Fees_and_Dari__c
                    Boolean relevantStatusCollected = isDownPaymentReceipt
                        ? (so.Down_Payment_Status__c == 'Collected')
                        : (so.ADM_Fees_and_Dari__c == 'Collected');
                    if (!relevantStatusCollected) {
                        continue;
                    }

                    Integer daysSinceReceipt = r.CreatedDate.date().daysBetween(effectiveToday);
                    if (daysSinceReceipt != expectedDays) {
                        continue;
                    }

                    String trackKey = isDownPaymentReceipt ? TRACK_RECEIPT_APPROVAL_DP : TRACK_RECEIPT_APPROVAL_ADM;
                    Escalation_Tier__mdt tier3 = tierByTrackAndDays.get(trackKey + '|' + expectedDays);
                    if (tier3 == null || (alreadySent.contains(tier3.Tier_Code__c) && !tier3.Is_Repeating__c)) {
                        continue;
                    }

                    if (safeTriggerReminderFlow(so, tier3.Tier_Code__c)) {
                        alreadySent.add(tier3.Tier_Code__c);
                        changed = true;
                        logTierTriggered(so, tier3, 'Receipt: ' + r.Id
                            + (isDownPaymentReceipt ? ', Down Payment receipt' : ', ADM & Dari receipt'));
                    }
                }
            }

            if (changed) {
                so.Reminders_Sent__c = String.join(new List<String>(alreadySent), ';');
                toUpdate.add(so);
            }
        }

        if (!toUpdate.isEmpty()) {
            try {
                update toUpdate;
            } catch (Exception exc) {
                safeLog(LoggerService.createApexLog(
                    exc, 'SalesOrderReminderBatch', 'SalesOrderReminderBatch', 'execute-update'
                ));
            }
        }
    }

    global void finish(Database.BatchableContext bc) {
        // LoggerService.save() writes immediately per call, nothing to flush here.
    }

    // ---------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------

    /**
     * v1.4 — Track 1 only: the SO is excluded if its DDA is Initiated/Approved.
     * (v1.5: Pre-Approved Payment Plans are no longer excluded here — see
     * findNextQualifyingInstallment.)
     */
    @TestVisible
    private Boolean isExcludedFromTrack1(SalesOrder__c so) {
        return TRACK1_EXCLUDED_DDA_STATUSES.contains(so.DDA_Status__c);
    }

    /**
     * v1.5 — true when the SO's linked Payment Plan has Pre_Approval__c = true.
     * An SO with no Payment Plan returns false.
     */
    @TestVisible
    private Boolean isPreApprovedPlan(SalesOrder__c so) {
        return so.PaymentPlan__c != null
            && so.PaymentPlan__r != null
            && so.PaymentPlan__r.Pre_Approval__c == true;
    }

    /**
     * Track 1: lowest-numbered installment (Milestone Number >= 2, excluding
     * the final/handover installment) that is still unpaid — i.e. it has no
     * related Receipt__c AND (v1.4) its PaymentStatus__c is not Paid /
     * Partially Paid.
     * v1.5: for Pre-Approved Payment Plans, the 5th installment is skipped and
     * the search moves on to the next installment.
     */
    private SalesOrderInstallments__c findNextQualifyingInstallment(
        List<SalesOrderInstallments__c> installments, Boolean isPreApprovedPlan
    ) {
        if (installments.isEmpty()) {
            return null;
        }

        Decimal maxMilestoneNumber = installments[installments.size() - 1].MilestoneNumber__c;

        for (SalesOrderInstallments__c inst : installments) {
            if (inst.MilestoneNumber__c == null || inst.MilestoneNumber__c < 2) {
                continue;
            }
            if (inst.MilestoneNumber__c == maxMilestoneNumber) {
                continue; // handover milestone, skip
            }
            if (isPreApprovedPlan && inst.MilestoneNumber__c == PRE_APPROVAL_SKIPPED_MILESTONE) {
                continue; // v1.5: Pre-Approved plan, 5th installment never reminded
            }
            if (PAID_INSTALLMENT_STATUSES.contains(inst.PaymentStatus__c)) {
                continue; // v1.4: already Paid / Partially Paid, skip
            }
            if (inst.Receipts__r.isEmpty()) {
                return inst;
            }
        }
        return null;
    }

    /**
     * Track 2: fires if EITHER the Down Payment or the ADM & Dari fee is
     * meaningfully outstanding — read directly from SO-level fields.
     */
    private static final Set<String> TRIGGERING_STATUSES = new Set<String>{
        'Partially Collected', 'Generated'
    };
    private static final Decimal DOWN_PAYMENT_THRESHOLD = 2000;
    private static final Decimal ADM_THRESHOLD = 100;

    @TestVisible
    private Boolean isDownPaymentOrAdmOutstanding(SalesOrder__c so) {
        Boolean downPaymentOutstanding =
            TRIGGERING_STATUSES.contains(so.Down_Payment_Status__c)
            && so.Pending_Down_Payment__c != null
            && so.Pending_Down_Payment__c >= DOWN_PAYMENT_THRESHOLD;

        Boolean admOutstanding =
            TRIGGERING_STATUSES.contains(so.ADM_Fees_and_Dari__c)
            && so.Pending_ADM_Amount__c != null
            && so.Pending_ADM_Amount__c >= ADM_THRESHOLD;

        return downPaymentOutstanding || admOutstanding;
    }

    private Set<String> parseSentTiers(String reminderSentField) {
        Set<String> result = new Set<String>();
        if (String.isNotBlank(reminderSentField)) {
            for (String v : reminderSentField.split(';')) {
                if (String.isNotBlank(v)) {
                    result.add(v);
                }
            }
        }
        return result;
    }

    /**
     * Invokes the shared Autolaunched Flow, catching any failure so a single
     * bad tier doesn't roll back the entire chunk's transaction.
     */
    private static final String FLOW_API_NAME = 'Sales_Order_Reminder_Send';

    private Boolean safeTriggerReminderFlow(SalesOrder__c so, String tierCode) {
        try {
            Map<String, Object> inputs = new Map<String, Object>{
                'recordId' => so.Id,
                'tierCode' => tierCode
            };
            Flow.Interview flowInterview = Flow.Interview.createInterview(FLOW_API_NAME, inputs);
            flowInterview.start();
            return true;
        } catch (Exception exc) {
            safeLog(LoggerService.createApexLog(
                exc, 'SalesOrderReminderBatch', 'SalesOrderReminderBatch', 'safeTriggerReminderFlow'
            ));
            safeLog(new Logger__c(
                LogType__c = 'Apex Exception',
                ExecutingProcessName__c = 'SalesOrderReminderBatch',
                ClassName__c = 'SalesOrderReminderBatch',
                MethodName__c = 'safeTriggerReminderFlow',
                UUID__c = so.Id,
                Message__c = 'Flow invocation FAILED - SO: ' + so.Name + ', Tier: ' + tierCode
                    + '. Likely cause: Flow "' + FLOW_API_NAME + '" does not exist or is inactive.',
                ExceptionMessage__c = exc.getMessage()
            ));
            return false;
        }
    }

    private void logTierTriggered(SalesOrder__c so, Escalation_Tier__mdt tier, String extraDetail) {
        safeLog(new Logger__c(
            LogType__c = 'Sales Order Reminder',
            ExecutingProcessName__c = 'SalesOrderReminderBatch',
            ClassName__c = 'SalesOrderReminderBatch',
            MethodName__c = 'execute',
            UUID__c = so.Id,
            Message__c = 'Reminder tier triggered - SO: ' + so.Name
                + ', Tier: ' + tier.Tier_Code__c + ', ' + extraDetail
        ));
    }

    /**
     * Wraps LoggerService.save() defensively — LoggerService is shared and
     * can't be modified here, so this ensures a logging failure never
     * crashes the actual reminder detection/sending logic.
     */
    private void safeLog(Logger__c rec) {
        try {
            LoggerService.save(rec);
        } catch (Exception loggingExc) {
            System.debug(LoggingLevel.ERROR,
                'LoggerService.save() itself failed: ' + loggingExc.getMessage()
                + ' | Original log intent: ' + rec.Message__c);
        }
    }
}