/**********************************************************************************************
 * Name           : UAEDDS_LWCController
 * Description     : Exposure layer for the UAEDDS Lightning components. Every method is a thin
 *                   delegate to a service that is already built and tested, so no rule lives here
 *                   twice - a refusal the screen shows is the wording the service itself used. The
 *                   one piece of real logic is the send guard: tab visibility is a navigation aid
 *                   rather than a control, so submitting a collection file is checked server side
 *                   before anything leaves Salesforce.
 * Usage           : Backs uaeddsMandateRequest, uaeddsMandateAction, uaeddsCollectionScreen and
 *                   ddaReconReport. Deliberately not DirectDebitLWCController, which serves FAB.
 * Created By      : Modon
 * --------------------------------------------------------------------------------------------
 * Version    Author            Date           Comment
 * 1.0        Prateek Bansal    23 Aug 2026    Initial version.
 * 2.0        Karunakar         20 Sep 2026    submitCollectionFile names the file for tomorrow, the
 *                                             day the money moves, instead of for the milestone date
 *                                             of the rows. A selection spanning several milestone
 *                                             dates is no longer refused - overdue rows are still
 *                                             collected tomorrow, which is what the scheduler does.
 * 2.1        Karunakar         20 Sep 2026    A collection Row carries the receipts behind the
 *                                             installment: the cleared excess and the unallocated
 *                                             receipt, each with its name and amount.
 * 2.2        Karunakar         21 Sep 2026    The capture screen's bank is UAEDDSBankName__c end to
 *                                             end: createMandateRecord writes it, knownBank matches
 *                                             the account against that picklist, and the validation
 *                                             read carries it. The Sales Console and FAB paths keep
 *                                             writing Customer_Bank_Name__c - nothing in them sets
 *                                             the new field.
 **********************************************************************************************/
public with sharing class UAEDDS_LWCController {

    @TestVisible
    private static final String SEND_PERMISSION = 'UAEDDS_Send_Collections';

    // ---------------------------------------------------------------- mandate, create

    /**
     * What the Sales Order already knows before anybody types anything. The four defaults come
     * from UAEDDS_Config__mdt because nothing in the org populates those fields yet.
     */
    @AuraEnabled(cacheable=true)
    public static NewMandate getSalesOrderDefaults(Id salesOrderId) {
        List<SalesOrder__c> found = [
            SELECT Id, Name, CustomerAccount__c, CustomerAccount__r.Name,
                   CustomerAccount__r.IsPersonAccount, CustomerAccount__r.BillingCity,
                   CustomerAccount__r.PersonMobilePhone, CustomerAccount__r.PersonEmail,
                   CustomerAccount__r.EIDNumber__pc,
                   CustomerAccount__r.IBAN_Number__c, CustomerAccount__r.Bank_Name__c,
                   PrimaryContact__r.Email,
                   VirtualAccount__r.EscrowAccount__r.OIC__c
            FROM SalesOrder__c WHERE Id = :salesOrderId LIMIT 1
        ];
        if (found.isEmpty()) {
            throw new AuraHandledException('Sales Order ' + salesOrderId + ' not found.');
        }
        SalesOrder__c so = found[0];

        NewMandate n = new NewMandate();
        n.salesOrderId = so.Id;
        n.salesOrderName = so.Name;
        n.accountId = so.CustomerAccount__c;
        n.accountName = so.CustomerAccount__r == null ? null : so.CustomerAccount__r.Name;
        n.isPersonAccount = so.CustomerAccount__r != null && so.CustomerAccount__r.IsPersonAccount;
        n.city = so.CustomerAccount__r == null ? null : so.CustomerAccount__r.BillingCity;
        n.mobile = so.CustomerAccount__r == null ? null : so.CustomerAccount__r.PersonMobilePhone;
        n.email = accountEmail(so);
        n.idNumber = so.CustomerAccount__r == null ? null : so.CustomerAccount__r.EIDNumber__pc;
        n.idType = n.isPersonAccount ? 'UAE Emirates Identity Card' : 'Trade Licence Number';
        n.iban = so.CustomerAccount__r == null ? null : so.CustomerAccount__r.IBAN_Number__c;
        n.bankAccountTitle = n.accountName;
        n.bankName = knownBank(
            so.CustomerAccount__r == null ? null : so.CustomerAccount__r.Bank_Name__c
        );
        n.oic = escrowOic(so);

        UAEDDS_Config__mdt cfg = UAEDDS_Config__mdt.getInstance('Default');
        if (cfg != null) {
            n.amountType = cfg.Default_Amount_Type__c;
            n.paymentFrequency = cfg.Default_Payment_Frequency__c;
            n.minimumAmount = cfg.Default_Minimum_Amount__c;
            n.preferredPaymentMethod = cfg.Default_Preferred_Payment_Method__c;
            n.creationEnabled = cfg.Mandate_Creation_Enabled__c == true;
        }
        n.existingMandateId = existingMandate(salesOrderId);

        Terms t = derivedTerms(salesOrderId);
        n.termsDerived = t.derived;
        n.commencesOn = t.commencesOn;
        n.expiresOn = t.expiresOn;
        n.maximumAmount = t.maximumAmount;
        return n;
    }

    /**
     * The window this screen quotes: commences on the first unpaid milestone after the down payment,
     * expires 548 days after the last, maximum = largest installment
     */
    private class Terms {
        Boolean derived = false;
        Date commencesOn;
        Date expiresOn;
        Decimal maximumAmount;
    }

    private static Terms derivedTerms(Id salesOrderId) {
        Terms t = new Terms();
        List<SalesOrderInstallments__c> due = [
            SELECT MilestoneDate__c, InstallmentAmount__c
            FROM SalesOrderInstallments__c
            WHERE SalesOrder__c = :salesOrderId
              AND MilestoneNumber__c != NULL AND MilestoneDate__c != NULL
              AND MilestoneNumber__c > 1 AND PaymentStatus__c != 'Paid'
            ORDER BY MilestoneNumber__c
        ];
        if (due.isEmpty()) {
            return t;
        }
        t.derived = true;
        t.commencesOn = due[0].MilestoneDate__c;
        t.expiresOn = due[due.size() - 1].MilestoneDate__c.addDays(548);
        Integer counted = due.size() > 1 ? due.size() - 1 : 1;
        for (Integer k = 0; k < counted; k++) {
            Decimal amount = due[k].InstallmentAmount__c;
            if (amount != null && (t.maximumAmount == null || amount > t.maximumAmount)) {
                t.maximumAmount = amount;
            }
        }
        return t;
    }

    // ---------------------------------------------------------------- home

    @AuraEnabled
    public static HomeView getHome() {
        HomeView v = new HomeView();

        // UAEDDS ages a mandate out at RQXP after 7 working days with no customer action.
        for (DirectDebitRequest__c m : [
            SELECT Id, Name, Sent_To_Bank_Date__c, CustomerAccountName__c
            FROM DirectDebitRequest__c
            WHERE Gateway__c = 'UAEDDS' AND Status__c = 'Pending Customer Signature'
              AND Sent_To_Bank_Date__c != NULL
            ORDER BY Sent_To_Bank_Date__c
            LIMIT 50
        ]) {
            Signing s = new Signing();
            s.mandateId = m.Id;
            s.name = m.Name;
            s.customer = m.CustomerAccountName__c;
            s.deadline = addWorkingDays(m.Sent_To_Bank_Date__c, 7);
            s.daysLeft = Date.today().daysBetween(s.deadline);
            v.signing.add(s);
        }

        // Tomorrow's collection, and how long is left to send it. selectDue already applies every
        // eligibility rule, so this counts what would actually go rather than what is dated.
        Date tomorrow = Date.today().addDays(1);
        for (UAEDDS_PaymentService.Candidate c : UAEDDS_PaymentService.selectDue(tomorrow)) {
            if (c.isCollectable()) {
                v.dueCount++;
                v.dueTotal += c.amount == null ? 0 : c.amount;
            } else {
                v.dueBlocked++;
            }
        }
        v.dueDate = tomorrow;
        v.cutOff = UAEDDS_PaymentService.cutOff(tomorrow);
        v.pastCutOff = UAEDDS_PaymentService.isPastCutOff(tomorrow);
        v.stuckFiles = [SELECT COUNT() FROM DDA_Payment_File__c WHERE Status__c = 'Submitting'];
        v.bounced = [
            SELECT COUNT() FROM DirectDebit_Transactions__c
            WHERE Gateway__c = 'UAEDDS' AND Transaction_Status__c = 'Failure'
        ];
        v.unmatched = [
            SELECT COUNT() FROM Logger__c
            WHERE ExecutingProcessName__c = 'UAEDDS_Reconciliation' AND CreatedDate = LAST_N_DAYS:7
        ];
        return v;
    }

    /** Weekends only. The UAE working week is Monday to Friday since 2022. */
    private static Date addWorkingDays(Date start, Integer days) {
        Date d = start;
        Integer added = 0;
        while (added < days) {
            d = d.addDays(1);
            Datetime probe = Datetime.newInstance(d, Time.newInstance(12, 0, 0, 0));
            String day = probe.format('EEE');
            if (day != 'Sat' && day != 'Sun') {
                added++;
            }
        }
        return d;
    }

    /**
     * The same rules the service enforces, run against what is on screen before anything is saved.
     */
    @AuraEnabled
    public static List<UAEDDS_MandateService.Rule> checkDraft(Id salesOrderId, String draftJson) {
        Map<String, Object> draft = String.isBlank(draftJson)
            ? new Map<String, Object>()
            : (Map<String, Object>) JSON.deserializeUntyped(draftJson);

        List<SalesOrder__c> found = [
            SELECT Id, CustomerAccount__r.IsPersonAccount, CustomerAccount__r.BillingCity,
                   CustomerAccount__r.PersonEmail, PrimaryContact__r.Email
            FROM SalesOrder__c WHERE Id = :salesOrderId LIMIT 1
        ];
        if (found.isEmpty()) {
            throw new AuraHandledException('Sales Order ' + salesOrderId + ' not found.');
        }
        Account a = found[0].CustomerAccount__r;

        draft.put('Gateway__c', 'UAEDDS');
        draft.put('Customer_Type__c', a != null && a.IsPersonAccount ? 'Individual' : 'Non Individual');
        draft.put('ContactEmail__c', accountEmail(found[0]));
        if (String.isBlank((String) draft.get('Customer_Email__c'))) {
            draft.put('Customer_Email__c', accountEmail(found[0]));
        }
        // city() falls back to the account, and this record carries no Account__r to fall back to.
        if (String.isBlank((String) draft.get('Customer_City__c')) && a != null) {
            draft.put('Customer_City__c', a.BillingCity);
        }
        Boolean referenceIsPending = String.isBlank((String) draft.get('DDA_Reference_Number__c'));
        if (referenceIsPending) {
            draft.put('DDA_Reference_Number__c', 'DD-00000000');
        }

        // The window and the maximum are set by the trigger on insert. Supplying them here rather
        Terms t = derivedTerms(salesOrderId);
        if (t.derived) {
            draft.put('Commences_On__c', String.valueOf(t.commencesOn));
            draft.put('Expires_On__c', String.valueOf(t.expiresOn));
            draft.put('Maximum_Amount__c', t.maximumAmount);
        }

        DirectDebitRequest__c m = (DirectDebitRequest__c) JSON.deserialize(
            JSON.serialize(draft), DirectDebitRequest__c.class
        );

        List<UAEDDS_MandateService.Rule> rules =
            UAEDDS_MandateService.check(m, UAEDDS_Config__mdt.getInstance('Default'));
        if (referenceIsPending) {
            for (UAEDDS_MandateService.Rule r : rules) {
                if (r.label.startsWith('DDA reference')) {
                    r.detail = 'assigned automatically when the mandate is saved';
                }
            }
        }
        return rules;
    }

    /**
     * Create the mandate from the Sales Order plus the handful of choices the screen collects.
     */
    @AuraEnabled
    public static Id createMandateRecord(Id salesOrderId, Map<String, Object> choices) {
        NewMandate n = getSalesOrderDefaults(salesOrderId);
        if (n.existingMandateId != null) {
            throw new AuraHandledException(
                n.salesOrderName + ' already has a live UAEDDS mandate. Open that one instead.'
            );
        }

        Map<String, Object> c = choices == null ? new Map<String, Object>() : choices;
        DirectDebitRequest__c m = new DirectDebitRequest__c(
            RecordTypeId = Schema.SObjectType.DirectDebitRequest__c
                .getRecordTypeInfosByDeveloperName().get('UAEDDS').getRecordTypeId(),
            Gateway__c = 'UAEDDS',
            Status__c = 'Draft',
            Account__c = n.accountId,
            SalesOrder__c = salesOrderId,
            OIC__c = n.oic,
            CustomerAccountName__c = text(c, 'CustomerAccountName__c', n.accountName),
            Customer_Id_Type__c = text(c, 'Customer_Id_Type__c', n.idType),
            Customer_ID_Number__c = text(c, 'Customer_ID_Number__c', n.idNumber),
            Customer_Mobile__c = text(c, 'Customer_Mobile__c', n.mobile),
            Customer_Email__c = text(c, 'Customer_Email__c', n.email),
            Customer_City__c = text(c, 'Customer_City__c', n.city),
            // The bank the capture screen chose. Customer_Bank_Name__c is no longer written from
            // here - UAEDDSBankName__c is the field that screen reads and the one the vendor payload
            // now prefers - so a bank corrected on screen reaches the record and the bank.
            UAEDDSBankName__c = text(c, 'UAEDDSBankName__c', n.bankName),
            Customer_Bank_Account_Name__c = text(c, 'Customer_Bank_Account_Name__c', n.bankAccountTitle),
            Customer_IBAN_Number__c = text(c, 'Customer_IBAN_Number__c', n.iban),
            Customer_Bank_Account_Type__c = text(c, 'Customer_Bank_Account_Type__c', null),
            Amount_Type__c = text(c, 'Amount_Type__c', n.amountType),
            Payment_Frequency__c = text(c, 'Payment_Frequency__c', n.paymentFrequency),
            Preferred_Payment_Method__c = text(c, 'Preferred_Payment_Method__c', n.preferredPaymentMethod),
            Minimum_Amount__c = n.minimumAmount
        );
        if (n.termsDerived) {
            m.Commences_On__c = n.commencesOn;
            m.Expires_On__c = n.expiresOn;
            m.Maximum_Amount__c = n.maximumAmount;
        } else {
            // No instalments to read, so the screen asked for these and they arrive as choices.
            m.Commences_On__c = asDate(c, 'Commences_On__c');
            m.Expires_On__c = asDate(c, 'Expires_On__c');
            m.Maximum_Amount__c = asDecimal(c, 'Maximum_Amount__c');
        }
        insert m;

        
        DirectDebitRequest__c correction = new DirectDebitRequest__c(Id = m.Id);
        Boolean correctionNeeded = false;

        // if (n.termsDerived && n.expiresOn != null) {
        //     correction.Expires_On__c = n.expiresOn;
        //     correctionNeeded = true;
        // }
        
        if (m.Amount_Type__c == 'Fixed') {
            DirectDebitRequest__c saved = [
                SELECT Maximum_Amount__c FROM DirectDebitRequest__c WHERE Id = :m.Id
            ];
            if (saved.Maximum_Amount__c != null) {
                correction.Minimum_Amount__c = saved.Maximum_Amount__c;
                correctionNeeded = true;
            }
        }
        if (correctionNeeded) {
            update correction;
        }
        return m.Id;
    }

    private static String text(Map<String, Object> c, String key, String fallback) {
        Object v = c.get(key);
        return v == null || String.isBlank(String.valueOf(v)) ? fallback : String.valueOf(v);
    }

    private static Date asDate(Map<String, Object> c, String key) {
        Object v = c.get(key);
        return v == null || String.isBlank(String.valueOf(v)) ? null : Date.valueOf(String.valueOf(v));
    }

    private static Decimal asDecimal(Map<String, Object> c, String key) {
        Object v = c.get(key);
        return v == null || String.isBlank(String.valueOf(v)) ? null : Decimal.valueOf(String.valueOf(v));
    }

    
    /**
     * The person account email, falling back to the sales order's primary contact. Deliberately the
     * same order as the ContactEmail__c formula, so the value the screen reads back is the one the
     * mandate would have been sent with before Customer_Email__c existed.
     */
    private static String accountEmail(SalesOrder__c so) {
        if (so == null) {
            return null;
        }
        if (so.CustomerAccount__r != null && String.isNotBlank(so.CustomerAccount__r.PersonEmail)) {
            return so.CustomerAccount__r.PersonEmail;
        }
        return so.PrimaryContact__r == null ? null : so.PrimaryContact__r.Email;
    }

    private static String escrowOic(SalesOrder__c so) {
        if (so == null || so.VirtualAccount__r == null || so.VirtualAccount__r.EscrowAccount__r == null) {
            return null;
        }
        return so.VirtualAccount__r.EscrowAccount__r.OIC__c;
    }

    /** Every problem at once, in the service's own words. An empty list means it can be sent. */
    @AuraEnabled
    public static List<String> validateMandate(Id mandateId) {
        DirectDebitRequest__c m = mandateForValidation(mandateId);
        return UAEDDS_MandateService.validate(m, UAEDDS_Config__mdt.getInstance('Default'));
    }

    // ---------------------------------------------------------------- mandate, manage

    /** The record as the action screen needs it, including which actions are legal right now. */
    @AuraEnabled(cacheable=true)
    public static MandateView getMandate(Id mandateId) {
        List<DirectDebitRequest__c> found = [
            SELECT Id, Name, Gateway__c, Status__c, DDA_Id__c, DDCA_Id__c, Bank_Status_Code__c,
                   Bank_Status_Description__c, Cancellation_Reason_Code__c
            FROM DirectDebitRequest__c WHERE Id = :mandateId LIMIT 1
        ];
        if (found.isEmpty()) {
            throw new AuraHandledException('Mandate ' + mandateId + ' not found.');
        }
        DirectDebitRequest__c m = found[0];

        MandateView v = new MandateView();
        v.mandateId = m.Id;
        v.name = m.Name;
        v.gateway = m.Gateway__c;
        v.status = m.Status__c;
        v.bankStatusCode = m.Bank_Status_Code__c;
        v.bankStatusDescription = m.Bank_Status_Description__c;
        v.isUaedds = m.Gateway__c == 'UAEDDS';

        Set<String> onFile = new Set<String>();
        List<Documents__c> docs = [
            SELECT Id FROM Documents__c WHERE Direct_Debit_Request__c = :mandateId LIMIT 1
        ];
        if (!docs.isEmpty()) {
            // A subquery on LinkedEntityId is refused, so the row id is resolved first.
            for (ContentDocumentLink link : [
                SELECT ContentDocument.Title FROM ContentDocumentLink
                WHERE LinkedEntityId = :docs[0].Id
            ]) {
                onFile.add(link.ContentDocument.Title);
            }
        }
        v.hasUnsignedForm = onFile.contains(m.Name + ' - Unsigned Mandate');
        v.hasSignedForm = onFile.contains(m.Name + ' - Signed Mandate');
        v.hasUnsignedCancellationForm = onFile.contains(m.Name + ' - Cancellation Form Unsigned');
        v.hasSignedCancellationForm = onFile.contains(m.Name + ' - Cancellation Form Signed');

        Boolean atBank = v.isUaedds && String.isNotBlank(m.DDA_Id__c);
        Boolean active = atBank && m.Bank_Status_Code__c == 'ACCP';
        Boolean cancellationRaised = String.isNotBlank(m.DDCA_Id__c);
        v.canSubmit = v.isUaedds && !atBank
            && !UAEDDS_MandateService.DEAD_STATUSES.contains(m.Status__c);
        v.canFetchDocument = atBank;
        v.canRefreshStatus = atBank;
        v.canDiscard = atBank && UAEDDS_MandateService.isDiscardable(m.Bank_Status_Code__c);
        v.canCancel = active && !cancellationRaised;
        v.canFetchCancellationForm = v.isUaedds && cancellationRaised;
        return v;
    }

    @AuraEnabled
    public static String createMandate(Id mandateId) {
        try {
            return outcome(UAEDDS_MandateService.createMandate(mandateId), 'Sent to the bank.');
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * No outcome() here: reject makes no callout, so there is no Result to read and nothing the bank
     * could have refused. The service throws on every refusal of its own and the message is shown.
     */
    @AuraEnabled
    public static String rejectMandate(Id mandateId, String reason) {
        try {
            UAEDDS_MandateService.reject(mandateId, reason);
            return 'Rejected. Nothing was sent to the bank.';
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static String fetchDocument(Id mandateId, Boolean signed) {
        try {
            return outcome(
                UAEDDS_MandateService.fetchDocument(mandateId, signed),
                (signed ? 'Signed' : 'Unsigned') + ' form filed with the mandate.'
            );
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static String refreshStatus(Id mandateId) {
        try {
            return outcome(
                UAEDDS_MandateService.refreshStatus(mandateId), 'Status refreshed from the bank.'
            );
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static String discard(Id mandateId) {
        try {
            return outcome(
                UAEDDS_MandateService.discard(mandateId),
                'Discarded. Nothing is left sitting at the bank.'
            );
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static String cancelMandate(Id mandateId) {
        try {
            return outcome(
                UAEDDS_CancellationService.cancel(mandateId),
                'Cancellation requested. The bank has not agreed to it yet.'
            );
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static String fetchCancellationForm(Id mandateId, Boolean signed) {
        try {
            return outcome(
                UAEDDS_CancellationService.fetchCancellationForm(mandateId, signed),
                'Cancellation form filed with the mandate.'
            );
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ---------------------------------------------------------------- collections

    /**
     * Everything due in a milestone date window, collectable or not. Refusals carry their reason and
     * stay in the list: an installment that should have been collected and quietly was not is
     * exactly what nobody notices until the customer rings.
     */
    @AuraEnabled
    public static CollectionView getDue(
        Date startDate, Date endDate, String projectName, String phaseName, String salesOrderName
    ) {        
        if (String.isBlank(projectName)) {
            throw new AuraHandledException('Choose a project before loading what is due.');
        }
        if (startDate != null && endDate != null && startDate > endDate) {
            throw new AuraHandledException('The start date is after the end date.');
        }

        CollectionView v = new CollectionView();
        v.startDate = startDate;
        v.endDate = endDate;
        v.projectName = projectName;
        v.phaseName = phaseName;
        v.salesOrderName = salesOrderName;
        v.canSend = FeatureManagement.checkPermission(SEND_PERMISSION);

        UAEDDS_PaymentService.Filter f = new UAEDDS_PaymentService.Filter();
        f.startDate = startDate;
        f.endDate = endDate;
        f.projectName = projectName;
        f.phaseName = phaseName;
        f.salesOrderName = salesOrderName;

        for (UAEDDS_PaymentService.Candidate c : UAEDDS_PaymentService.selectDue(f)) {
            v.rows.add(new Row(c));
        }
        return v;
    }

    /**
     * The projects, for the filter on the collection screen. Name carries both the label and the
     * value because the filter is applied against SalesOrder__c.ProjectName__c, which is the
     * project's Name reached through the unit - an Id here would have nothing to match on.
     *
     * Cacheable: the project list does not change while a collection is being built.
     */
    @AuraEnabled(cacheable=true)
    public static List<Option> getProjects() {
        List<Option> options = new List<Option>();
        for (Project__c p : [
            SELECT Name FROM Project__c WHERE Name != NULL ORDER BY Name LIMIT 1000
        ]) {
            options.add(new Option(p.Name, p.Name));
        }
        return options;
    }

    /**
     * The phases of one project, for the second filter. Narrowed by the project's Name rather than
     * its Id because that is what the screen holds - see getProjects - and the phase filter is
     * applied against SalesOrder__r.Phase_Name__c, so a Name is what has to come back either way.
     *
     * An empty list for a blank project rather than every phase in the org: the phase box is only
     * ever opened after a project is chosen, and returning the lot would offer phases that cannot
     * match the project already picked.
     */
    @AuraEnabled(cacheable=true)
    public static List<Option> getPhases(String projectName) {
        List<Option> options = new List<Option>();
        if (String.isBlank(projectName)) {
            return options;
        }
        String project = projectName.trim();
        for (Phase__c p : [
            SELECT Name FROM Phase__c
            WHERE Name != NULL AND Project__r.Name = :project
            ORDER BY Name LIMIT 1000
        ]) {
            options.add(new Option(p.Name, p.Name));
        }
        return options;
    }

    /**
     * The sales orders under one project, for the third filter, narrowed further by phase when one
     * is chosen so the list matches what the screen is already showing.
     */
    @AuraEnabled(cacheable=true)
    public static List<Option> getSalesOrders(String projectName, String phaseName) {
        List<Option> options = new List<Option>();
        if (String.isBlank(projectName)) {
            return options;
        }
        String project = projectName.trim();
        String phase = String.isBlank(phaseName) ? null : phaseName.trim();

        // Dynamic for the phase clause only, on the same rule the service follows: an absent phase
        // has to mean no clause rather than a comparison nothing satisfies. Both values are bound.
        String soql =
            'SELECT Name FROM SalesOrder__c '
            + 'WHERE Name != NULL AND ProjectName__c = :project '
            + '  AND Status__c != \'Cancelled\''
            + (phase == null ? '' : ' AND Phase_Name__c = :phase')
            + ' ORDER BY Name LIMIT 1000';
        for (SalesOrder__c so : Database.query(soql)) {
            options.add(new Option(so.Name, so.Name));
        }
        return options;
    }

    /**
     * The last few files, so a header stuck on Submitting is visible on the same screen that would
     * otherwise send another one. That status is the double-debit marker and it needs a human.
     */
    @AuraEnabled
    public static List<FileRow> getRecentFiles() {
        List<FileRow> rows = new List<FileRow>();
        for (DDA_Payment_File__c f : [
            SELECT Id, Name, Status__c, Payment_File_Id__c, Payment_File_Name__c,
                   Record_Count__c, Total_Amount__c, Upload_Date__c
            FROM DDA_Payment_File__c
            ORDER BY Upload_Date__c DESC NULLS LAST
            LIMIT 10
        ]) {
            rows.add(new FileRow(f));
        }
        return rows;
    }

    /**
     * Builds the file, then hands it to the queueable that actually calls out. The commit has to
     * happen first because Salesforce forbids a callout after DML in one transaction, and that
     * ordering is the double-debit guard rather than a convention.
     */
    @AuraEnabled
    public static Id submitCollectionFile(
        List<Id> installmentIds, Date startDate, Date endDate, String projectName
    ) {
        // Checked here rather than trusted from the UI. A hidden tab is navigation, not access.
        if (!FeatureManagement.checkPermission(SEND_PERMISSION)) {
            throw new AuraHandledException(
                'Sending a collection file needs the Direct Debit Operations permission set, '
                + 'because it debits customers.'
            );
        }
        
        UAEDDS_PaymentService.Filter f = new UAEDDS_PaymentService.Filter();
        f.startDate = startDate;
        f.endDate = endDate;
        f.projectName = projectName;

        Set<Id> chosen = new Set<Id>(installmentIds);
        List<UAEDDS_PaymentService.Candidate> send = new List<UAEDDS_PaymentService.Candidate>();
        for (UAEDDS_PaymentService.Candidate c : UAEDDS_PaymentService.selectDue(f)) {
            if (chosen.contains(c.installmentId) && c.isCollectable()) {
                send.add(c);
            }
        }
        if (send.isEmpty()) {
            throw new AuraHandledException('Nothing in that selection can be collected.');
        }

        Date fileDueDate = Date.today().addDays(1);

        try {
            DDA_Payment_File__c file = UAEDDS_PaymentService.prepare(send, fileDueDate);
            System.enqueueJob(new UAEDDS_PaymentUploadQueueable(file.Id));
            return file.Id;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static String refreshFile(Id fileId) {
        try {
            return outcome(UAEDDS_PaymentService.refreshFile(fileId), 'File refreshed from the bank.');
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static String represent(Id transactionId) {
        try {
            return outcome(
                UAEDDS_PaymentService.represent(transactionId),
                'Re-presented. It re-enters the payment lifecycle.'
            );
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static String fetchBounceMemo(Id transactionId) {
        try {
            return outcome(
                UAEDDS_PaymentService.fetchBounceMemo(transactionId),
                'Bounce memo filed against the payment.'
            );
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ---------------------------------------------------------------- reconciliation

    /**
     * The day-end report as the screen shows it. Unmatched rows lead, because a payment UAEDDS
     * processed against a Modon mandate that Salesforce never requested is the finding that
     * matters. Reading it advances nothing; the batch owns that.
     */
    @AuraEnabled
    public static ReconView runDailyReport(Date reportDate) {
        ReconView v = new ReconView();
        v.reportDate = reportDate;

        UAEDDS_Service.Result r = UAEDDS_Service.call(
            UAEDDS_Service.DAILY_REPORT,
            new Map<String, Object>{ 'date' => isoDate(reportDate) },
            'Reconciliation'
        );
        // A date with no activity is not an outage. Live, UAEDDS answers HTTP 200 with an empty
        if (r.httpStatus == 404) {
            v.emptyDay = true;
            return v;
        }
        if (!r.ok) {
            throw new AuraHandledException('The day-end report could not be read: ' + r.errorText);
        }
        if (r.rows.isEmpty()) {
            v.emptyDay = true;
            return v;
        }

        Set<String> reported = new Set<String>();
        for (Map<String, Object> row : r.rows) {
            String paymentId = UAEDDS_Service.str(row, new List<String>{ 'id', 'paymentId' });
            if (paymentId != null) {
                reported.add(paymentId);
            }
        }
        Map<String, DirectDebit_Transactions__c> known =
            new Map<String, DirectDebit_Transactions__c>();
        for (DirectDebit_Transactions__c t : [
            SELECT Id, Name, UAEDDS_Payment_Id__c, Direct_Debit_Request__r.Name
            FROM DirectDebit_Transactions__c WHERE UAEDDS_Payment_Id__c IN :reported
        ]) {
            known.put(t.UAEDDS_Payment_Id__c, t);
        }

        for (Map<String, Object> row : r.rows) {
            ReconRow rr = new ReconRow(row);
            DirectDebit_Transactions__c t = known.get(rr.paymentId);
            if (t == null) {
                v.unmatched.add(rr);
            } else {
                rr.transactionId = t.Id;
                rr.transactionName = t.Name;
                rr.mandateName = t.Direct_Debit_Request__r.Name;
                v.matched.add(rr);
            }
        }
        return v;
    }

    // ---------------------------------------------------------------- helpers

    /** ok means the call completed and the body parsed, never that the bank agreed to anything. */    
    private static String outcome(UAEDDS_Service.Result r, String success) {
        if (r.ok) {
            return success;
        }
        throw new AuraHandledException(
            String.isBlank(r.errorText)
                ? 'The bank did not accept that. The call is in the Direct Debit logs.'
                : r.errorText
        );
    }

    private static Id existingMandate(Id salesOrderId) {
        List<DirectDebitRequest__c> found = [
            SELECT Id FROM DirectDebitRequest__c
            WHERE SalesOrder__c = :salesOrderId AND Gateway__c = 'UAEDDS'
              AND Status__c NOT IN :UAEDDS_MandateService.DEAD_STATUSES
            LIMIT 1
        ];
        return found.isEmpty() ? null : found[0].Id;
    }

    /**
     * Account.Bank_Name__c is free text and UAEDDSBankName__c is a picklist, so the two only
     * sometimes agree - live accounts hold 'Fab', 'BNK612' and 'Test Bank Name'. Matched loosely
     * enough to survive case and spacing, and returns null rather than a near miss: an unmatched
     * value cannot be shown in the picklist anyway, and guessing which bank was meant is how the
     * wrong one gets debited.
     *
     * Described against UAEDDSBankName__c rather than Customer_Bank_Name__c because that is the
     * picklist the capture screen offers. Matching the other one would hand the screen a default it
     * could not display.
     */
    private static String knownBank(String raw) {
        if (String.isBlank(raw)) {
            return null;
        }
        String needle = raw.trim().toLowerCase();
        for (Schema.PicklistEntry e : DirectDebitRequest__c.UAEDDSBankName__c
                .getDescribe().getPicklistValues()) {
            if (e.isActive() && e.getValue().toLowerCase() == needle) {
                return e.getValue();
            }
        }
        return null;
    }

    private static DirectDebitRequest__c mandateForValidation(Id mandateId) {
        List<DirectDebitRequest__c> found = [
            SELECT Id, Name, Gateway__c, Status__c, DDA_Id__c, DDAR_Id__c, DDA_Reference_Number__c,
                   Customer_ID_Number__c, Customer_Id_Type__c, Customer_Type__c,
                   CustomerAccountName__c, Customer_Bank_Account_Name__c, Customer_City__c,
                   Customer_Mobile__c, Customer_Email__c, ContactEmail__c, UAEDDSBankName__c,
                   Customer_Bank_Name__c,
                   Customer_Bank_Account_Type__c, Customer_IBAN_Number__c, Commences_On__c,
                   Expires_On__c, Amount_Type__c, Payment_Frequency__c, Preferred_Payment_Method__c,
                   Minimum_Amount__c, Maximum_Amount__c, Account__r.BillingCity
            FROM DirectDebitRequest__c WHERE Id = :mandateId LIMIT 1
        ];
        if (found.isEmpty()) {
            throw new AuraHandledException('Mandate ' + mandateId + ' not found.');
        }
        return found[0];
    }

    private static String isoDate(Date d) {
        return String.valueOf(d.year()) + '-'
            + String.valueOf(d.month()).leftPad(2, '0') + '-'
            + String.valueOf(d.day()).leftPad(2, '0');
    }

    // ---------------------------------------------------------------- wrappers

    public class NewMandate {
        @AuraEnabled public Id salesOrderId;
        @AuraEnabled public String salesOrderName;
        @AuraEnabled public Id accountId;
        @AuraEnabled public String accountName;
        @AuraEnabled public Boolean isPersonAccount;
        @AuraEnabled public String city;
        @AuraEnabled public String mobile;
        @AuraEnabled public String email;
        @AuraEnabled public String idNumber;
        @AuraEnabled public String idType;
        @AuraEnabled public String iban;
        @AuraEnabled public String bankName;
        @AuraEnabled public String bankAccountTitle;
        @AuraEnabled public String oic;
        @AuraEnabled public Boolean termsDerived = false;
        @AuraEnabled public Date commencesOn;
        @AuraEnabled public Date expiresOn;
        @AuraEnabled public Decimal maximumAmount;
        @AuraEnabled public String amountType;
        @AuraEnabled public String paymentFrequency;
        @AuraEnabled public Decimal minimumAmount;
        @AuraEnabled public String preferredPaymentMethod;
        @AuraEnabled public Boolean creationEnabled = false;
        @AuraEnabled public Id existingMandateId;
    }

    public class HomeView {
        @AuraEnabled public List<Signing> signing = new List<Signing>();
        @AuraEnabled public Date dueDate;
        @AuraEnabled public Integer dueCount = 0;
        @AuraEnabled public Integer dueBlocked = 0;
        @AuraEnabled public Decimal dueTotal = 0;
        @AuraEnabled public Datetime cutOff;
        @AuraEnabled public Boolean pastCutOff = false;
        @AuraEnabled public Integer stuckFiles = 0;
        @AuraEnabled public Integer bounced = 0;
        @AuraEnabled public Integer unmatched = 0;
    }

    public class Signing {
        @AuraEnabled public Id mandateId;
        @AuraEnabled public String name;
        @AuraEnabled public String customer;
        @AuraEnabled public Date deadline;
        @AuraEnabled public Integer daysLeft;
    }

    public class MandateView {
        @AuraEnabled public Id mandateId;
        @AuraEnabled public String name;
        @AuraEnabled public String gateway;
        @AuraEnabled public String status;
        @AuraEnabled public String bankStatusCode;
        @AuraEnabled public String bankStatusDescription;
        @AuraEnabled public Boolean isUaedds;
        @AuraEnabled public Boolean hasUnsignedForm;
        @AuraEnabled public Boolean hasSignedForm;
        @AuraEnabled public Boolean hasUnsignedCancellationForm;
        @AuraEnabled public Boolean hasSignedCancellationForm;
        @AuraEnabled public Boolean canSubmit;
        @AuraEnabled public Boolean canFetchDocument;
        @AuraEnabled public Boolean canRefreshStatus;
        @AuraEnabled public Boolean canDiscard;
        @AuraEnabled public Boolean canCancel;
        @AuraEnabled public Boolean canFetchCancellationForm;
    }

    /** A combobox entry. Label and value are both the project Name - see getProjects. */
    public class Option {
        @AuraEnabled public String label;
        @AuraEnabled public String value;

        private Option(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }

    public class CollectionView {
        @AuraEnabled public Date startDate;
        @AuraEnabled public Date endDate;
        @AuraEnabled public String projectName;
        @AuraEnabled public String phaseName;
        @AuraEnabled public String salesOrderName;
        @AuraEnabled public Boolean canSend;
        @AuraEnabled public List<Row> rows = new List<Row>();
    }

    public class Row {
        @AuraEnabled public Id installmentId;
        @AuraEnabled public Id mandateId;
        @AuraEnabled public String mandateName;
        @AuraEnabled public String ddaRefNo;
        @AuraEnabled public Date dueDate;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public String problem;
        @AuraEnabled public Boolean collectable;
        @AuraEnabled public String installmentName;
        @AuraEnabled public String salesOrderName;
        @AuraEnabled public String customerName;
        @AuraEnabled public String ddOwnerName;
        @AuraEnabled public String unitName;
        @AuraEnabled public String phaseName;
        @AuraEnabled public String projectName;
        @AuraEnabled public Decimal installmentAmount;
        @AuraEnabled public Decimal milestoneNumber;
        @AuraEnabled public String paymentStatus;
        @AuraEnabled public String excessReceiptName;
        @AuraEnabled public Decimal excessAmount;
        @AuraEnabled public String pdcReceiptName;
        @AuraEnabled public Decimal pdcAmount;

        private Row(UAEDDS_PaymentService.Candidate c) {
            installmentId = c.installmentId;
            mandateId = c.mandateId;
            mandateName = c.mandateName;
            ddaRefNo = c.ddaRefNo;
            dueDate = c.dueDate;
            amount = c.amount;
            problem = c.problem;
            collectable = c.isCollectable();
            installmentName = c.installmentName;
            salesOrderName = c.salesOrderName;
            customerName = c.customerName;
            ddOwnerName = c.ddOwnerName;
            unitName = c.unitName;
            phaseName = c.phaseName;
            projectName = c.projectName;
            installmentAmount = c.installmentAmount;
            milestoneNumber = c.milestoneNumber;
            paymentStatus = c.paymentStatus;
            excessReceiptName = c.excessReceiptName;
            excessAmount = c.excessAmount;
            pdcReceiptName = c.pdcReceiptName;
            pdcAmount = c.pdcAmount;
        }
    }

    public class FileRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String status;
        @AuraEnabled public String paymentFileId;
        @AuraEnabled public Decimal recordCount;
        @AuraEnabled public Decimal totalAmount;
        @AuraEnabled public Datetime uploadDate;

        private FileRow(DDA_Payment_File__c f) {
            id = f.Id;
            name = f.Payment_File_Name__c;
            status = f.Status__c;
            paymentFileId = f.Payment_File_Id__c;
            recordCount = f.Record_Count__c;
            totalAmount = f.Total_Amount__c;
            uploadDate = f.Upload_Date__c;
        }
    }

    public class ReconView {
        @AuraEnabled public Date reportDate;
        @AuraEnabled public Boolean emptyDay = false;
        @AuraEnabled public List<ReconRow> unmatched = new List<ReconRow>();
        @AuraEnabled public List<ReconRow> matched = new List<ReconRow>();
    }

    public class ReconRow {
        @AuraEnabled public String paymentId;
        @AuraEnabled public String customerDdsRefNo;
        @AuraEnabled public String paymentRefNo;
        @AuraEnabled public String amount;
        @AuraEnabled public String status;
        @AuraEnabled public String statusDescription;
        @AuraEnabled public String ftRefNo;
        @AuraEnabled public Id transactionId;
        @AuraEnabled public String transactionName;
        @AuraEnabled public String mandateName;

        private ReconRow(Map<String, Object> row) {
            paymentId = UAEDDS_Service.str(row, new List<String>{ 'id', 'paymentId' });
            customerDdsRefNo = UAEDDS_Service.str(row, new List<String>{ 'customerDdsRefNo' });
            paymentRefNo = UAEDDS_Service.str(row, new List<String>{ 'paymentRefNo' });
            amount = UAEDDS_Service.str(row, new List<String>{ 'amount' });
            status = UAEDDS_Service.str(row, new List<String>{ 'status' });
            ftRefNo = UAEDDS_Service.str(row, new List<String>{ 'ftRefNo' });
            statusDescription = UAEDDS_MandateService.describe('Payment Status', status);
        }
    }
}