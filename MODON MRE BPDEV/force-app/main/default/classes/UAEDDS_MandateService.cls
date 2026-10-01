/**********************************************************************************************
 * Name           : UAEDDS_MandateService
 * Description     : The mandate path - create, fetch the signed or unsigned form, refresh status
 *                   and discard. Also holds the pre-submit validation, which is where most of the
 *                   value sits: UAEDDS rejects on spelling, length and format, so it is far
 *                   cheaper to catch a bad mandate here than to explain the rejection later.
 *                   Never sets Approve__c and never creates a transaction row carrying a FAB
 *                   request type - those two things are what keep the existing FAB trigger chain
 *                   out of this path entirely.
 * Usage           : UAEDDS_MandateQueueable, UAEDDS_StatusPollBatch.
 * Created By      : Modon
 * --------------------------------------------------------------------------------------------
 * Version    Author            Date           Comment
 * 1.0        Prateek Bansal    23 Aug 2026    Initial version.
 * 1.1        Prateek Bansal    26 Aug 2026    Checks report per field rather than as one list;
 *                                             bank account type rule added; Sent To Bank date
 *                                             stamped on create.
 * 2.0        Karunakar         15 Sep 2026    reject, the Salesforce-side refusal of a mandate that
 *                                             was never sent. Rejected joins DEAD_STATUSES, so a
 *                                             refused mandate stops being offered for submission and
 *                                             stops blocking its own replacement.
 * 2.1        Karunakar         15 Sep 2026    reject takes a reason and refuses without one, and the
 *                                             reason is saved to Rejection_Reason__c.
 * 2.2        Karunakar         21 Sep 2026    customerAccountBankName reads UAEDDSBankName__c, the
 *                                             field the capture screen sets, and falls back to
 *                                             Customer_Bank_Name__c for mandates raised before it
 *                                             existed or by the Sales Console and FAB paths.
 **********************************************************************************************/
public with sharing class UAEDDS_MandateService {

    private static final String PROCESS = 'Mandate';

    /**
     * The org and the vendor spell two things differently. Mapped on the way out rather than
     * fixed at source, because both fields are shared with the FAB population (D9).
     *
     * Customer_Type__c is a formula, IF(Account__r.IsPersonAccount,'Individual','Non Individual'),
     * so 'Non Individual' arrives without the hyphen the vendor expects. Every mandate raised so
     * far has been a person account, which is why this has never surfaced.
     */
    private static final Map<String, String> CUSTOMER_TYPE = new Map<String, String>{
        'Individual' => 'Individual',
        'Non Individual' => 'Non-Individual'
    };

    private static final Map<String, String> ID_TYPE = new Map<String, String>{
        'Trade Licence Number' => 'Trade License Number'
    };

    /**
     * UAEDDS DDA statuses that have a Salesforce equivalent. Anything absent here is recorded on
     * Bank_Status_Code__c and leaves Status__c alone - an unrecognised code must never be guessed
     * into a branch. SUSP and EXPR are deliberately absent: they are real codes with no matching
     * Status__c value, so they are recorded rather than translated.
     */
    private static final Map<String, String> DDA_STATUS = new Map<String, String>{
        'PNDG' => 'Pending Customer Signature',
        'SUBP' => 'Send To Bank',
        'APRP' => 'Send To Bank',
        'ACCP' => 'Approved By Bank',
        'RJCT' => 'Rejected By Bank',
        'ERR'  => 'Rejected By Bank',
        'DENY' => 'Rejected By Bank',
        'RQXP' => 'Discarded',
        'CANC' => 'Cancelled'
    };

    /**
     * A mandate in one of these is finished. It must never block a replacement on its Sales Order,
     * must never be the mandate a collection is claimed against, and must never be submitted. The
     * first three are the Status__c values the terminal bank codes above map to.
     */
    public static final Set<String> DEAD_STATUSES = new Set<String>{
        'Discarded', 'Cancelled', 'Rejected By Bank', 'Rejected'
    };

    /**
     * The only bank statuses UAEDDS will discard. Its own refusal reads "Only 'PNDG' and 'DRFT' DDA
     * can be discarded"; DRFT is a vendor-side draft we never hold, because a mandate has no DDA Id
     * until it has been created. RQXP is already Discarded, so discarding it again is a no-op rather
     * than an error. Anything active is cancelled instead.
     */
    private static final Set<String> DISCARDABLE = new Set<String>{ 'PNDG', 'RQXP' };

    /** Whether the bank will accept a discard for this status. Used by the screen to offer it. */
    public static Boolean isDiscardable(String bankStatusCode) {
        return DISCARDABLE.contains(bankStatusCode);
    }

    /**
     * What counts as an address. Deliberately the shape of a mailbox rather than RFC 5322 in full:
     * the vendor rejects on the obvious faults - no @, no domain, a trailing comma - and a stricter
     * pattern here would refuse addresses the bank would have accepted. Mirrored by UAE_EMAIL in
     * uaeddsMandateRequest, so the screen refuses exactly what this refuses.
     */
    @TestVisible
    private static final String EMAIL = '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}';

    private static final String FIELDS =
        'Id, Name, Gateway__c, Status__c, DDA_Id__c, DDAR_Id__c, DDA_Reference_Number__c, ' +
        'Customer_ID_Number__c, Customer_Id_Type__c, Customer_Type__c, CustomerAccountName__c, ' +
        'Customer_Bank_Account_Name__c, Customer_City__c, Customer_Mobile__c, ' +
        'Customer_Email__c, ContactEmail__c, ' +
        'UAEDDSBankName__c, Customer_Bank_Name__c, Customer_Bank_Account_Type__c, ' +
        'Customer_IBAN_Number__c, ' +
        'Commences_On__c, Expires_On__c, Amount_Type__c, Payment_Frequency__c, ' +
        'Preferred_Payment_Method__c, Minimum_Amount__c, Maximum_Amount__c, Bank_Status_Code__c, ' +
        'OIC__c, Account__r.BillingCity';

    public class MandateException extends Exception {}

    /** Custom metadata cannot be inserted in a test, so the config is injectable. */
    @TestVisible
    private static UAEDDS_Config__mdt overrideConfig;

    @TestVisible
    private static UAEDDS_Config__mdt config() {
        return overrideConfig != null ? overrideConfig : UAEDDS_Config__mdt.getInstance('Default');
    }

    /**
     * Whether the org is switched on for mandate creation. Asked before enqueuing rather than only
     * inside createMandate, so a switched-off org queues nothing instead of queuing a job per
     * approved mandate that can only throw.
     */
    public static Boolean isCreationEnabled() {
        UAEDDS_Config__mdt cfg = config();
        return cfg != null && cfg.Mandate_Creation_Enabled__c == true;
    }

    // ---------------------------------------------------------------- flows

    public static UAEDDS_Service.Result createMandate(Id mandateId) {
        UAEDDS_Config__mdt cfg = config();
        if (!isCreationEnabled()) {
            // D4: there is no rollback to FAB creation, so this path ships switched off.
            throw new MandateException('UAEDDS mandate creation is switched off in UAEDDS_Config.');
        }

        DirectDebitRequest__c m = load(mandateId);
        List<String> problems = validate(m, cfg);
        if (!problems.isEmpty()) {
            throw new MandateException('Mandate cannot be submitted: ' + String.join(problems, ' '));
        }

        // OICCode is not in this map - UAEDDS_Service.call adds it from the fourth argument - so it
        // is printed beside the body rather than appearing inside it.
        Map<String, Object> body = buildPayload(m, cfg);
        System.debug('createDDAMandate request ' + JSON.serialize(body) + ' OICCode ' + m.OIC__c);

        UAEDDS_Service.Result r = UAEDDS_Service.call(
            UAEDDS_Service.CREATE_MANDATE, body, PROCESS, m.OIC__c
        );
        System.debug('createDDAMandate response ' + r.httpStatus + ' ' + r.rawBody);
        if (!r.ok || r.rows.isEmpty()) {
            return r;
        }

        String ddaId = UAEDDS_Service.str(r.rows[0], new List<String>{ 'ddaId' });
        if (String.isBlank(ddaId)) {
            // A body that parsed but carries no identifier is a failure, whatever it says.
            return r;
        }
        update new DirectDebitRequest__c(
            Id = m.Id,
            DDA_Id__c = ddaId,
            DDAR_Id__c = UAEDDS_Service.str(r.rows[0], new List<String>{ 'ddarId' }),
            Status__c = 'Pending Customer Signature',
            Sent_To_Bank_Date__c = Date.today(),
            Approve__c = TRUE,
            Approved_Date__c = Date.today(),
            Approve_Reject_By__c = UserInfo.getUserId()
        );

        // The mandate is at the bank and its identifiers are saved, so the unsigned form can be
        if (!System.isQueueable()) {
            queueUnsignedForm(m.Id);
        }
        return r;
    }

    /**
     * Queues the unsigned form for a mandate that has just been created.
     *
     * Not enqueued from a test, for the same reason UAEDDS_MandateQueueable does not chain in one:
     * the job would run at Test.stopTest() against whatever mock the create test set up and answer
     * a document response to it. Each link is asserted on its own instead.
     */
    private static void queueUnsignedForm(Id mandateId) {
        if (Test.isRunningTest()) {
            return;
        }
        System.enqueueJob(UAEDDS_MandateQueueable.forDocument(mandateId, false));
    }

    /**
     * Finance refusing a mandate before it is sent. The counterpart of Approve, and the only other
     * way out of Draft.
     */
    public static void reject(Id mandateId, String reason) {
        List<DirectDebitRequest__c> found = [
            SELECT Id, Name, Gateway__c, Status__c, DDA_Id__c, Reject__c
            FROM DirectDebitRequest__c WHERE Id = :mandateId LIMIT 1
        ];
        if (found.isEmpty()) {
            throw new MandateException('Mandate ' + mandateId + ' not found.');
        }
        DirectDebitRequest__c m = found[0];

        if (m.Gateway__c != 'UAEDDS') {
            throw new MandateException(
                m.Name + ' is on the FAB gateway. FAB mandates are rejected from the buttons on the '
                + 'record, which raise a transaction row this path deliberately does not.'
            );
        }
        if (String.isNotBlank(m.DDA_Id__c)) {
            throw new MandateException(
                m.Name + ' is already at the bank, so rejecting it here would leave it live at '
                + 'UAEDDS. Discard it while it is awaiting signature, or cancel it once it is live.'
            );
        }
        if (m.Reject__c == true || DEAD_STATUSES.contains(m.Status__c)) {
            throw new MandateException(m.Name + ' is already ' + m.Status__c + '.');
        }

        String why = reason == null ? null : reason.trim();
        if (String.isBlank(why)) {
            throw new MandateException(
                'A rejection reason is required. It is the only record of why ' + m.Name
                + ' was refused.'
            );
        }

        update new DirectDebitRequest__c(
            Id = m.Id,
            Reject__c = TRUE,
            Status__c = 'Rejected',
            Rejection_Reason__c = why,
            Approve_Reject_DateTime__c = System.now(),
            Approve_Reject_By__c = UserInfo.getUserId()
        );
    }

    public static UAEDDS_Service.Result fetchDocument(Id mandateId, Boolean signed) {
        DirectDebitRequest__c m = load(mandateId);
        if (String.isBlank(m.DDA_Id__c)) {
            throw new MandateException('Mandate ' + m.Name + ' has no DDA Id, so there is no form to fetch.');
        }

        // getDDADoc takes a requestArray, the same envelope discardDDA uses, and carries OICCode
        UAEDDS_Service.Result r = UAEDDS_Service.call(
            UAEDDS_Service.GET_DDA_DOC,
            new Map<String, Object>{
                'requestArray' => new List<Object>{
                    new Map<String, Object>{
                        'ddaId' => Integer.valueOf(m.DDA_Id__c),
                        'type' => signed ? 'signed-pdf' : 'unsigned-pdf',
                        'document' => signed ? 'SIGNED' : 'UNSIGNED',
                        'OICCode' => m.OIC__c
                    }
                }
            },
            PROCESS
        );
        if (!r.ok || r.rows.isEmpty()) {
            return r;
        }

        String base64 = UAEDDS_Service.str(r.rows[0], new List<String>{ 'base64' });
        if (String.isNotBlank(base64)) {
            UAEDDS_DocumentService.store(m.Id, base64, m.Name, signed);
        }
        return r;
    }

    public static UAEDDS_Service.Result refreshStatus(Id mandateId) {
        DirectDebitRequest__c m = load(mandateId);
        if (String.isBlank(m.DDA_Id__c)) {
            throw new MandateException('Mandate ' + m.Name + ' has no DDA Id, so there is no status to read.');
        }

        UAEDDS_Service.Result r = UAEDDS_Service.call(
            UAEDDS_Service.GET_DDA_STATUS, statusRequest(m.DDA_Id__c, m.OIC__c), PROCESS
        );
        System.debug('Print Status Res '+ r);
        if (r.ok && !r.rows.isEmpty()) {
            update statusUpdate(m, r.rows[0]);
        }
        return r;
    }

    /**
     * Discards a mandate the customer has not signed.
     */
    public static UAEDDS_Service.Result discard(Id mandateId) {
        DirectDebitRequest__c m = load(mandateId);
        if (String.isBlank(m.DDA_Id__c)) {
            throw new MandateException('Mandate ' + m.Name + ' has no DDA Id, so there is nothing to discard.');
        }
        if (!DISCARDABLE.contains(m.Bank_Status_Code__c)) {
            throw new MandateException(
                m.Name + ' is ' +
                (m.Bank_Status_Code__c == null ? 'not yet at the bank' : m.Bank_Status_Code__c) +
                '. UAEDDS only discards a mandate still awaiting signature - an active one is cancelled instead.'
            );
        }

        Map<String, Object> entry = new Map<String, Object>{
            'ddaId' => Integer.valueOf(m.DDA_Id__c)
        };

        if (String.isNotBlank(m.OIC__c)) {
            entry.put('OICCode', Long.valueOf(m.OIC__c.trim()));
        }

        Map<String, Object> body = new Map<String, Object>{
            'requestArray' => new List<Object>{ entry }
        };
        System.debug('discardDDA request ' + JSON.serialize(body));

        UAEDDS_Service.Result r = UAEDDS_Service.call(
            UAEDDS_Service.DISCARD_DDA, body, PROCESS
        );
        System.debug('discardDDA response ' + r);
        if (!r.ok || r.rows.isEmpty()) {
            return r;
        }

        update new DirectDebitRequest__c(
            Id = m.Id,
            Status__c = 'Discarded',
            Discarded_Date__c = Date.today(),
            // Stamped alongside so the bank code and the Salesforce status do not disagree until
            // the next poll. RQXP is what getDDAStatus reports for a discarded mandate.
            Bank_Status_Code__c = 'RQXP',
            Bank_Status_Description__c = describe('DDA Status', 'RQXP')
        );
        return r;
    }

    /**
     * Turns one getDDAStatus row into the record to update. Returns rather than saving so a
     * poller can collect a whole scope and write once.
     */
    public static DirectDebitRequest__c statusUpdate(DirectDebitRequest__c m, Map<String, Object> row) {
        String code = UAEDDS_Service.str(row, new List<String>{ 'status' });

        DirectDebitRequest__c upd = new DirectDebitRequest__c(
            Id = m.Id,
            Bank_Status_Code__c = code,
            Bank_Status_Description__c = describe('DDA Status', code),
            Last_Status_Sync__c = System.now(),
            CB_DDA_Reference__c = UAEDDS_Service.str(row, new List<String>{ 'cbDdaRefNo' })
        );
        if (code != null && DDA_STATUS.containsKey(code)) {
            upd.Status__c = DDA_STATUS.get(code);
        }
        return upd;
    }

    /**
     * The one getDDAStatus request body, shared by the single-record path and the poller.
     */
    public static Map<String, Object> statusRequest(String ddaId, String oicCode) {
        return new Map<String, Object>{
            'requestArray' => new List<Object>{
                new Map<String, Object>{
                    'ddaId' => Integer.valueOf(ddaId),
                    'OICCode' => oicCode
                }
            }
        };
    }

    /** Plain language for a raw code, or null when the vendor sends something we have not loaded. */
    public static String describe(String codeType, String code) {
        if (String.isBlank(code)) {
            return null;
        }
        for (UAEDDS_Code__mdt c : UAEDDS_Code__mdt.getAll().values()) {
            if (c.Code_Type__c == codeType && c.Code__c == code) {
                return c.Description__c;
            }
        }
        return null;
    }

    // ---------------------------------------------------------------- payload

    @TestVisible
    private static Map<String, Object> buildPayload(DirectDebitRequest__c m, UAEDDS_Config__mdt cfg) {
        String idNumber = digitsOnly(m.Customer_ID_Number__c);
        return new Map<String, Object>{
            'customerIdNumber' => idNumber,
            // custNid carries the same value as customerIdNumber. Both are mandatory (14.6).
            'custNid' => idNumber,
            'customerIdType' => mapped(ID_TYPE, m.Customer_Id_Type__c),
            'customerFullName' => tidy(m.CustomerAccountName__c),
            'customerType' => CUSTOMER_TYPE.get(m.Customer_Type__c),
            'customerCity' => city(m),
            'customerMobileNumber' => mobile(m.Customer_Mobile__c),
            'customerEmail' => email(m),
            'ddaReferenceNumber' => m.DDA_Reference_Number__c,
            'userPreferPaymentMethod' => fallback(m.Preferred_Payment_Method__c, cfg.Default_Preferred_Payment_Method__c),
            // UAEDDSBankName__c is the bank the UAEDDS capture screen sets and is authoritative
            // here. Customer_Bank_Name__c is kept as the fallback rather than dropped: mandates
            // raised before that field existed, and the ones the Sales Console and the FAB path
            // raise, carry the bank there and nowhere else, and sending the vendor a blank bank
            // name is a rejection rather than a warning.
            'customerAccountBankName' => fallback(m.UAEDDSBankName__c, m.Customer_Bank_Name__c),
            'customerBankAccountType' => m.Customer_Bank_Account_Type__c,
            'customerBankAccountTitle' => tidy(m.Customer_Bank_Account_Name__c),
            'customerBankAccountNumber' => compact(m.Customer_IBAN_Number__c),
            'commencesOn' => ddMMyyyy(m.Commences_On__c),
            'expiresOn' => ddMMyyyy(m.Expires_On__c),
            'amountType' => fallback(m.Amount_Type__c, cfg.Default_Amount_Type__c),
            'paymentFrequency' => fallback(m.Payment_Frequency__c, cfg.Default_Payment_Frequency__c),
            'minAmount' => round2(m.Minimum_Amount__c == null ? cfg.Default_Minimum_Amount__c : m.Minimum_Amount__c),
            'maxAmount' => round2(m.Maximum_Amount__c)
        };
    }

    // ---------------------------------------------------------------- validation

    /**
     * Every rule here is drawn from the vendor contract and was checked against the live BPDEV
     * records, several of which fail it. Returns the problems; an empty list means submittable.
     *
     * customerAccountBankName is deliberately not validated. The 91 local values have not been
     * reconciled against the vendor bank master and that reconciliation needs a business owner.
     * The value reaches Logger__c inside the request body either way, so a rejection is traceable.
     */
    public static List<String> validate(DirectDebitRequest__c m, UAEDDS_Config__mdt cfg) {
        List<String> problems = new List<String>();
        for (Rule r : check(m, cfg)) {
            problems.addAll(r.problems);
        }
        return problems;
    }

    /**
     * One rule, and whether this mandate satisfies it. The screen needs to show what passed as well
     * as what failed - a bare list of faults tells somebody what is wrong but never that the other
     * ten rules are already satisfied, which is most of the reassurance the capture screen owes.
     *
     * detail carries the normalised value on a pass, because "reads 0561234567" is the answer to
     * the question somebody actually has after typing +971561234567.
     */
    public class Rule {
        @AuraEnabled public String label;
        @AuraEnabled public Boolean passed = true;
        @AuraEnabled public String detail;
        @AuraEnabled public List<String> problems = new List<String>();
        /** The form field this rule is about, so a failure can be shown where it is fixed. */
        @AuraEnabled public String field;

        private Rule(String label) {
            this.label = label;
        }

        private Rule(String label, String field) {
            this.label = label;
            this.field = field;
        }

        private Rule fail(String problem) {
            this.passed = false;
            this.problems.add(problem);
            this.detail = this.problems.size() == 1 ? problem : String.join(this.problems, ' ');
            return this;
        }

        private Rule pass(String detail) {
            this.detail = detail;
            return this;
        }
    }

    /**
     * The single evaluation of every vendor rule. validate() is a thin flattening of this, so the
     * screen and the service can never disagree about what is wrong - there is one implementation
     * and the order of the problems is unchanged.
     */
    public static List<Rule> check(DirectDebitRequest__c m, UAEDDS_Config__mdt cfg) {
        List<Rule> rules = new List<Rule>();

        Rule gateway = new Rule('Gateway is UAEDDS');
        if (m.Gateway__c != 'UAEDDS') {
            gateway.fail('Gateway is ' + m.Gateway__c + ', not UAEDDS.');
        }
        rules.add(gateway);

        Rule custType = new Rule('Customer type is one UAEDDS accepts');
        if (!CUSTOMER_TYPE.containsKey(m.Customer_Type__c)) {
            custType.fail('Customer Type "' + m.Customer_Type__c + '" is not a value UAEDDS accepts.');
        } else {
            custType.pass('sends as ' + CUSTOMER_TYPE.get(m.Customer_Type__c));
        }
        rules.add(custType);

        Rule idType = new Rule('Customer ID type is set', 'Customer_Id_Type__c');
        if (String.isBlank(m.Customer_Id_Type__c)) {
            idType.fail('Customer Id Type is required.');
        } else {
            idType.pass(mapped(ID_TYPE, m.Customer_Id_Type__c));
        }
        rules.add(idType);

        Rule idNumber = new Rule('Customer ID number is present', 'Customer_ID_Number__c');
        String digits = digitsOnly(m.Customer_ID_Number__c);
        if (String.isBlank(digits)) {
            idNumber.fail('Customer Id Number is required.');
        } else {
            idNumber.pass('sends as ' + digits);
        }
        rules.add(idNumber);

        Rule reference = new Rule('DDA reference within 26 characters');
        if (String.isBlank(m.DDA_Reference_Number__c)) {
            reference.fail('DDA Reference Number is required.');
        } else if (m.DDA_Reference_Number__c.length() > 26) {
            reference.fail('DDA Reference Number exceeds the 26 character limit.');
        } else {
            reference.pass(m.DDA_Reference_Number__c);
        }
        rules.add(reference);

        Rule cityRule = new Rule('City is present', 'Customer_City__c');
        if (String.isBlank(city(m))) {
            cityRule.fail('Customer City is required, and the account has no billing city to fall back on.');
        } else {
            cityRule.pass(city(m));
        }
        rules.add(cityRule);

        // Customer_Email__c is what the capture screen saved, falling back to ContactEmail__c - the
        // formula that reads the person account email and then the sales order primary contact. A
        // company account with no primary contact resolves to blank, which is exactly why the field
        // is editable: the address can be typed rather than chased onto the account first.
        Rule emailRule = new Rule('Customer email is present and well formed', 'Customer_Email__c');
        String mail = email(m);
        if (String.isBlank(mail)) {
            emailRule.fail('Customer Email is required. Type one, or set a person email on the account.');
        } else if (!Pattern.matches(EMAIL, mail)) {
            emailRule.fail('Customer Email "' + mail + '" is not a valid email address.');
        } else {
            emailRule.pass(mail);
        }
        rules.add(emailRule);

        Rule mobileRule = new Rule('Mobile reads 05XXXXXXXX', 'Customer_Mobile__c');
        String mob = mobile(m.Customer_Mobile__c);
        if (mob == null || !Pattern.matches('05[0-9]{8}', mob)) {
            mobileRule.fail('Customer Mobile "' + m.Customer_Mobile__c + '" is not a UAE mobile in the form 05XXXXXXXX.');
        } else {
            mobileRule.pass('sends as ' + mob);
        }
        rules.add(mobileRule);

        Rule ibanRule = new Rule('IBAN is 23 characters', 'Customer_IBAN_Number__c');
        String iban = compact(m.Customer_IBAN_Number__c);
        if (iban == null || iban.length() != 23) {
            ibanRule.fail('IBAN must be exactly 23 characters, this one is ' + (iban == null ? 0 : iban.length()) + '.');
        } else {
            ibanRule.pass(iban);
        }
        rules.add(ibanRule);

        // customerBankAccountType is in the create payload and there was no rule for it, so a
        // mandate with the field blank passed validation and went to the bank incomplete. Found by
        // the capture screen, which was refusing to save something the service was happy with.
        Rule accountType = new Rule('Bank account type is set', 'Customer_Bank_Account_Type__c');
        if (String.isBlank(m.Customer_Bank_Account_Type__c)) {
            accountType.fail('Bank Account Type is required. UAEDDS accepts Savings or Current.');
        } else {
            accountType.pass(m.Customer_Bank_Account_Type__c);
        }
        rules.add(accountType);

        rules.add(nameRule('Customer full name', 'Customer Full Name', m.CustomerAccountName__c, 'CustomerAccountName__c'));
        rules.add(nameRule('Bank account title', 'Bank Account Title', m.Customer_Bank_Account_Name__c, 'Customer_Bank_Account_Name__c'));

        Rule window = new Rule('Mandate window is valid', 'Commences_On__c');
        if (m.Commences_On__c == null || m.Expires_On__c == null) {
            window.fail('Commences On and Expires On are both required.');
        } else if (m.Expires_On__c <= m.Commences_On__c) {
            window.fail('Expires On must be later than Commences On.');
        } else {
            window.pass(ddMMyyyy(m.Commences_On__c) + ' to ' + ddMMyyyy(m.Expires_On__c));
        }
        rules.add(window);

        // Fixed means every collection is the same amount, so the two bounds have to agree. Under
        // Variable they must not: UAEDDS refuses a range with no room in it.
        Rule amounts = new Rule('Amounts match the amount type', 'Maximum_Amount__c');
        Decimal minAmt = m.Minimum_Amount__c == null ? cfg.Default_Minimum_Amount__c : m.Minimum_Amount__c;
        if (m.Maximum_Amount__c == null) {
            amounts.fail('Maximum Amount is required.');
        } else if (m.Amount_Type__c == 'Fixed') {
            if (minAmt == null || minAmt != m.Maximum_Amount__c) {
                amounts.fail('Amount Type is Fixed, so Minimum Amount must equal Maximum Amount of '
                    + round2(m.Maximum_Amount__c) + '.');
            } else {
                amounts.pass(round2(m.Maximum_Amount__c) + ' every collection');
            }
        } else if (minAmt != null && m.Maximum_Amount__c <= minAmt) {
            amounts.fail('Maximum Amount must exceed Minimum Amount.');
        } else {
            amounts.pass(round2(minAmt) + ' to ' + round2(m.Maximum_Amount__c));
        }
        rules.add(amounts);

        return rules;
    }

    /** Vendor rule: 100 characters and 7 words, both caps, on the two name fields. */
    private static Rule nameRule(String label, String problemLabel, String value, String field) {
        Rule r = new Rule(label + ' within 100 characters and 7 words', field);
        List<String> problems = nameProblems(problemLabel, value);
        if (problems.isEmpty()) {
            return r.pass(tidy(value));
        }
        for (String p : problems) {
            r.fail(p);
        }
        return r;
    }

    /** Vendor rule: 100 characters and 7 words, both caps, on the two name fields. */
    private static List<String> nameProblems(String label, String value) {
        List<String> problems = new List<String>();
        String v = tidy(value);
        if (String.isBlank(v)) {
            problems.add(label + ' is required.');
            return problems;
        }
        if (v.length() > 100) {
            problems.add(label + ' exceeds 100 characters.');
        }
        if (v.split(' ').size() > 7) {
            problems.add(label + ' exceeds the 7 word limit.');
        }
        // UAEDDS answers "No special character is allowed in customer full name"
        if (!Pattern.matches('[A-Za-z\' -]+', v)) {
            problems.add(label + ' may hold only letters, spaces, hyphens and apostrophes. '
                + 'UAEDDS refuses digits and other characters.');
        }
        return problems;
    }

    // ---------------------------------------------------------------- normalising

    /** +971564142138 and 971564142138 both become 0564142138. */
    private static String mobile(String raw) {
        String v = compact(raw);
        if (v == null) {
            return null;
        }
        if (v.startsWith('+971')) {
            return '0' + v.substring(4);
        }
        if (v.startsWith('971')) {
            return '0' + v.substring(3);
        }
        return v;
    }

    /**
     * The address the mandate goes out with. Whatever the screen saved, and only where that is
     * blank the formula it started from, so a mandate raised before Customer_Email__c existed still
     * sends the account address rather than nothing.
     */
    private static String email(DirectDebitRequest__c m) {
        String typed = tidy(m.Customer_Email__c);
        return String.isNotBlank(typed) ? typed : tidy(m.ContactEmail__c);
    }

    /** Emirates IDs are stored as 784-1992-2875238-4 and must be sent as 784199228752384. */
    private static String digitsOnly(String raw) {
        return raw == null ? null : raw.replaceAll('[^0-9]', '');
    }

    private static String compact(String raw) {
        return raw == null ? null : raw.replaceAll('[\\s-]', '');
    }

    /** Trim, then collapse runs of whitespace, so the word count is honest. */
    private static String tidy(String raw) {
        return raw == null ? null : raw.trim().replaceAll('\\s+', ' ');
    }

    private static String city(DirectDebitRequest__c m) {
        if (String.isNotBlank(m.Customer_City__c)) {
            return m.Customer_City__c;
        }
        return m.Account__r == null ? null : m.Account__r.BillingCity;
    }

    private static String fallback(String value, String defaultValue) {
        return String.isNotBlank(value) ? value : defaultValue;
    }

    private static Decimal round2(Decimal value) {
        return value == null ? null : value.setScale(2, System.RoundingMode.HALF_UP);
    }

    /** UAEDDS wants dd/MM/yyyy here. getDDADailyReport wants ISO. Format per endpoint. */
    private static String ddMMyyyy(Date d) {
        if (d == null) {
            return null;
        }
        return String.valueOf(d.day()).leftPad(2, '0') + '/'
             + String.valueOf(d.month()).leftPad(2, '0') + '/'
             + String.valueOf(d.year());
    }

    private static String mapped(Map<String, String> translations, String value) {
        if (value == null) {
            return null;
        }
        return translations.containsKey(value) ? translations.get(value) : value;
    }

    @TestVisible
    private static DirectDebitRequest__c load(Id mandateId) {
        List<DirectDebitRequest__c> found = Database.query(
            'SELECT ' + FIELDS + ' FROM DirectDebitRequest__c WHERE Id = :mandateId LIMIT 1'
        );
        if (found.isEmpty()) {
            throw new MandateException('Mandate ' + mandateId + ' not found.');
        }
        return found[0];
    }
}