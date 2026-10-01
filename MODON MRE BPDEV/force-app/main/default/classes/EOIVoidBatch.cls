/**********************************************************************************************************************
* Name               : EOIVoidBatch
* Description        : Voids In-Progress EOIs that have breached their SLA window without payment
* --------------------------------------------------------------------------------------------------------------------
* Version  Author                  Date            Comment
* 1.0      Arvind Kesharwani                       Initial Draft
* 1.1      Prateek Bansal          17 May 2026     Convert start() SOQL to dynamic query with embedded datetime
*                                                  literal to fix tmpVar1 error
* 1.2      Prateek Bansal          17 May 2026     Run SOQL and DML in SYSTEM_MODE so the system batch is not
*                                                  blocked by per-user FLS
* 1.3      Arvind      22 May 2026     Stamp Timer_Display_Expiry__c using EOI_SLA_Timer_Display_Hours
*                                                  (flat 48 h shown to customer). Actual void window unchanged —
*                                                  still driven by EOI_SLA_HOURS_Expired /
*                                                  EOI_SLA_Hours_Non_Resident_expired per resident status.
**********************************************************************************************************************/
global class EOIVoidBatch implements Database.Batchable<SObject>, Database.Stateful {

    global Integer voidedCount = 0;

    global Database.QueryLocator start(Database.BatchableContext bc) {

        if (System.Label.EOI_SLA_Enabled != 'true') {
            // v1.2
            return Database.getQueryLocator(
                'SELECT Id FROM Expressionofinterest__c WHERE Id = null',
                AccessLevel.SYSTEM_MODE
            );
        }

        Integer  minHours    = Integer.valueOf(System.Label.EOI_SLA_Hours);
        Datetime minDeadline = Datetime.now().addHours(-minHours);

        // v1.3 — added Timer_Display_Expiry__c to SELECT so we can back-fill it
        // Keep dynamic locator + bind (static Datetime bind in start() hits tmpVar1).
        return Database.getQueryLocator(
            'SELECT Id, Status__c, SLA_Start_Time__c, ' +
            '       UAE_Resident_Status__c, Opportunity__c, ' +
            '       Timer_Display_Expiry__c ' +
            'FROM   Expressionofinterest__c ' +
            'WHERE  Status__c          IN (\'New\',\'In Progress\') ' +
            '  AND  Status__c          != \'Voided\' ' +
            '  AND  Skip_SLA__c        = false ' +
            '  AND  SLA_Start_Time__c  != null ' +
            '  AND  SLA_Start_Time__c  <= :minDeadline ' +
            '  AND  Source_Entity__c   != \'Modon - Egypt\'',
            AccessLevel.SYSTEM_MODE
        );
    }

    global void execute(Database.BatchableContext bc, List<Expressionofinterest__c> scope) {

        Integer  residentHours    = Integer.valueOf(System.Label.EOI_SLA_HOURS_Expired);
        Integer  nonResidentHours = Integer.valueOf(System.Label.EOI_SLA_Hours_Non_Resident_expired);
        String   residentValue    = System.Label.EOI_SLA_Resident_Value;
        Datetime now              = Datetime.now();

        // v1.3 — flat display-timer label, same for resident and non-resident
        Integer timerDisplayHours = Integer.valueOf(System.Label.EOI_SLA_Timer_Display_Hours); // e.g. 48

        // ── Step 1: find records that breached their ACTUAL expiry (72 h) ─────
        Set<Id> breachedIds = new Set<Id>();
        for (Expressionofinterest__c eoi : scope) {
            Integer hrs = (eoi.UAE_Resident_Status__c == residentValue)
                          ? residentHours : nonResidentHours;
            if (now >= eoi.SLA_Start_Time__c.addHours(hrs)) {
                breachedIds.add(eoi.Id);
            }
        }

        // ── Step 2: exclude EOIs that already have a payment receipt ──────────
        Set<Id> eoiWithPayment = new Set<Id>();
        if (!breachedIds.isEmpty()) {
            for (Receipt__c r : [
                SELECT Expressionofinterest__c FROM Receipt__c
                WHERE  Expressionofinterest__c IN :breachedIds
            ]) {
                eoiWithPayment.add(r.Expressionofinterest__c);
            }
        }

        // ── Step 3: build update list ─────────────────────────────────────────
        List<Expressionofinterest__c> toVoid = new List<Expressionofinterest__c>();

        for (Expressionofinterest__c eoi : scope) {

            Expressionofinterest__c record = new Expressionofinterest__c(Id = eoi.Id);
            Boolean needsUpdate = false;

            // v1.3 ── Stamp Timer_Display_Expiry__c once using FLAT 48-hr label ─
            // Resident and non-resident both see the same display timer.
            // This is intentionally shorter than the real void window (72 h)
            // so the customer feels urgency before the backend actually expires.
            if (eoi.Timer_Display_Expiry__c == null && eoi.SLA_Start_Time__c != null) {
                record.Timer_Display_Expiry__c = eoi.SLA_Start_Time__c.addHours(timerDisplayHours);
                needsUpdate = true;
            }

            // ── Actual expiry — unchanged from v1.2 ───────────────────────────
            if (breachedIds.contains(eoi.Id) && !eoiWithPayment.contains(eoi.Id)) {
                Integer hrs = (eoi.UAE_Resident_Status__c == residentValue)
                              ? residentHours : nonResidentHours;
                String resStatus = String.isBlank(eoi.UAE_Resident_Status__c)
                                   ? 'Not Set' : eoi.UAE_Resident_Status__c;

                record.Status__c            = 'Expired';
                record.SLA_Voided_Reason__c = 'SLA Expired — No payment within ' + hrs
                                              + ' hours. Resident Status: ' + resStatus + '.';
                needsUpdate = true;
                voidedCount++;
            }

            if (needsUpdate) toVoid.add(record);
        }

        if (!toVoid.isEmpty()) {
            Database.update(toVoid, AccessLevel.SYSTEM_MODE); // v1.2
        }
    }

    global void finish(Database.BatchableContext bc) {
        System.debug('EOIVoidBatch complete. Total expired: ' + voidedCount);
    }
}