/**********************************************************************************************************************
* Name               : uaeddsMandateRequest
* Description        : Raises a UAEDDS mandate from a Sales Order. Reads the customer and bank details back
*                      rather than asking for them, and picks out the values that are genuinely a decision.
* Usage              : Quick action on SalesOrder__c
* Created By         : Modon
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           Prateek Bansal              23 Aug 2026     Initial version
* 1.1           Prateek Bansal              26 Aug 2026     Rebuilt as a read-back summary with the decisions picked out; Modon palette
* 1.2           Prateek Bansal              27 Aug 2026     Save disabled while any rule is failing
* 1.3           Prateek Bansal              01 Sep 2026     A field open for input stays open; it no longer closes mid-typing
* 1.4           Prateek Bansal              01 Sep 2026     Spacing restored around the bold values in the authorisation summary
* 1.5           Prateek Bansal              01 Sep 2026     Draft carries every defaulted field, so an unrendered rule no longer blocks Save silently
* 1.6           Karunakar                   12 Sep 2026     Name, ID number and IBAN always open; ID type and bank picked from their
*                                                           picklists; amount type held at Variable and read back
* 1.7           Karunakar                   12 Sep 2026     Single-letter identifiers renamed for what they hold
* 1.8           Karunakar                   12 Sep 2026     Bank Name sits directly above the IBAN it belongs with
* 1.9           Karunakar                   12 Sep 2026     In the name of follows the name as it is corrected, on screen and on save
* 2.0           Karunakar                   14 Sep 2026     Name read back behind a pencil; mobile always open, checked as it is typed
*                                                           and saved in the 05XXXXXXXX form; In the name of read back at the top
* 2.1           Karunakar                   15 Sep 2026     Email read off the account, open like the mobile, checked as it is typed
*                                                           and saved to Customer_Email__c so the bank is sent what is on screen
* 2.2           Karunakar                   15 Sep 2026     ID number held to 30 characters, on the box and on the value read off the
*                                                           account
* 2.3           Karunakar                   15 Sep 2026     Banner heading fixed to the account name the screen opened with, so it no
*                                                           longer rewrites itself as the Name field is corrected
* 2.4           Karunakar                   15 Sep 2026     Bank Name is required: marked on the line and blocking Save, because no
*                                                           server rule covers it
* 2.5           Karunakar                   21 Sep 2026     Open the mandate lands on the mandate: the navigation is asked for before
*                                                           the modal is closed, so it is no longer dropped onto the Sales Order
* 2.6           Karunakar                   21 Sep 2026     Bank Name reads UAEDDSBankName__c end to end. The line was keyed to it but
*                                                           the default and the guard were not, so nothing filled the field and Save
*                                                           stayed disabled whatever else was corrected. One constant now, an account
*                                                           default that only counts when the picklist holds it, and the chosen bank
*                                                           sent on save
******************************************************************************************************************/
import { LightningElement, api, wire } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { getObjectInfo, getPicklistValuesByRecordType } from 'lightning/uiObjectInfoApi';

import DDR_OBJECT from '@salesforce/schema/DirectDebitRequest__c';
import getSalesOrderDefaults from '@salesforce/apex/UAEDDS_LWCController.getSalesOrderDefaults';
import checkDraft from '@salesforce/apex/UAEDDS_LWCController.checkDraft';
import createMandateRecord from '@salesforce/apex/UAEDDS_LWCController.createMandateRecord';
import validateMandate from '@salesforce/apex/UAEDDS_LWCController.validateMandate';
import createMandate from '@salesforce/apex/UAEDDS_LWCController.createMandate';
import fetchDocument from '@salesforce/apex/UAEDDS_LWCController.fetchDocument';

/**
 * The longest ID number UAEDDS will carry. Applied twice, because the two cases are different: as
 * maxlength on the box, so the thirty-first character is never typed, and as a rule on the value,
 * because the number read off the account can already be longer than this and no maxlength on a box
 * refuses a value that was never typed into it.
 */
const ID_NUMBER_MAX = 30;
const ID_NUMBER_PROBLEM = `Use ${ID_NUMBER_MAX} characters or fewer. The bank will not take a longer number.`;

/**
 * One list, read by both the getters that render the lines and the code that decides which of them
 * are open for input, so the two can never drift apart.
 *
 * control says how the line is presented. 'text' is an input that never closes, for the values the
 * account is only ever a starting point for; 'reveal' is read back with a pencil beside it, so a
 * value that is usually right can still be corrected without reading as a field to fill in;
 * 'picklist' is a combobox off the field's own picklist; no control at all is read back, and only
 * turns into an input when it is blank or failing.
 */
const CUSTOMER_LINES = [
    // The account name is right far more often than it is wrong, so it is read back rather than
    // boxed. The pencil opens it, and what is typed is what the mandate is saved with.
    { field: 'CustomerAccountName__c', label: 'Name', control: 'reveal' },
    {
        field: 'Customer_Id_Type__c',
        label: 'ID type',
        control: 'picklist',
        required: true,
        placeholder: 'Choose the ID type'
    },
    // Capped rather than merely checked: the ceiling is a hard one, so the box refuses the
    // thirty-first character instead of accepting it and marking it wrong afterwards.
    { field: 'Customer_ID_Number__c', control: 'text', maxLength: ID_NUMBER_MAX },
    // Always open: the mobile on the account is a contact number rather than the one the bank will
    // text, and it is the value most often carrying a country code the vendor refuses.
    { field: 'Customer_Mobile__c', label: 'Mobile', control: 'text', type: 'tel' },
    // Open for the same reason as the mobile. UAEDDS sends the mandate here for signature, so a
    // stale address on the account is a mandate nobody ever signs, and a company account with no
    // primary contact reaches this screen with nothing at all to read back.
    { field: 'Customer_Email__c', label: 'Email', control: 'text', type: 'email' },
    { field: 'Customer_City__c', label: 'City' }
];

/**
 * The bank title is not here: it follows the customer name, so it is read back at the top of the
 * screen instead of sitting in this list as a line nobody can act on.
 *
 * Bank name sits directly above the IBAN, because the two are read off the same statement and a
 * mismatched pair is what the vendor rejects.
 */
const BANK_TITLE_FIELD = 'Customer_Bank_Account_Name__c';

/**
 * The bank the screen asks for, and the only one it reads. Named once because three places have to
 * agree on it - the line, the default, and the guard on Save - and the last time they did not, the
 * guard was reading a field nothing could ever fill.
 */
const BANK_NAME_FIELD = 'UAEDDSBankName__c';

const BANK_LINES = [
    // Required on the screen and nowhere else. UAEDDS_MandateService.validate deliberately leaves
    // customerAccountBankName alone - the local values have not been reconciled against the vendor
    // bank master - so a blank bank name passes every server rule and would reach the bank empty.
    // The block has to be here or it does not exist.
    {
        field: BANK_NAME_FIELD,
        label: 'Bank Name',
        control: 'picklist',
        required: true,
        placeholder: 'Choose the bank'
    },
    { field: 'Customer_IBAN_Number__c', label: 'IBAN', control: 'text' }
];

/**
 * The ID number is one field holding seven different documents, so the label follows the type that
 * is chosen rather than naming the Emirates ID a company cannot hold. Keyed on the picklist values
 * of Customer_Id_Type__c.
 */
const ID_NUMBER_LABEL = {
    'UAE Emirates Identity Card': 'Emirates ID number',
    'Trade Licence Number': 'Trade licence number',
    'Passport': 'Passport number',
    'UAE Driving License Number': 'Driving licence number',
    'Family Book Number': 'Family book number',
    'Emiree Decree Number': 'Emiree decree number',
    'Chamber Certification Number': 'Chamber certification number'
};

// Every mandate raised here authorises a ceiling rather than a set figure, so the type is not a
// decision. Read back rather than hidden, because it is what the bank is being told.
const AMOUNT_TYPE = 'Variable';

const REQUIRED = 'Required before this can go to the bank.';

// What UAEDDS accepts, and the only form the mandate is saved with. Mirrors the mobile() and
// compact() pair in UAEDDS_MandateService, so the screen refuses exactly what the server would.
const UAE_MOBILE = /^05[0-9]{8}$/;
const MOBILE_PROBLEM = 'Enter a UAE mobile as starts with 05. +971 and 971 are accepted and saved as 05.';

// Mirrors EMAIL in UAEDDS_MandateService, so the screen refuses exactly what the server would.
// The shape of a mailbox rather than RFC 5322 in full: anything stricter refuses addresses the
// bank would have accepted.
const EMAIL = /^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/;
const EMAIL_PROBLEM = 'Enter an email as name@example.com. The bank sends the mandate here to be signed.';


function normaliseMobile(raw) {
    if (!raw) {
        return '';
    }
    const compact = String(raw).replace(/[\s-]/g, '');
    if (compact.startsWith('+971')) {
        return `0${compact.substring(4)}`;
    }
    if (compact.startsWith('971')) {
        return `0${compact.substring(3)}`;
    }
    return compact;
}

/**
 * Every field the Sales Order and the config can supply, and where each one comes from.
 *
 * The draft posted to the check is built from these keys, not from the lines on screen. Some of
 * these are never rendered - the payment frequency and the preferred method are set by config -
 * and leaving them out of the draft failed their rules on every check, against a field the user
 * could not see.
 *
 * Customer_Id_Type__c still starts here: the account decides which document is the sensible one to
 * ask for, and the picklist on screen only overrides that starting point.
 */
const DEFAULT_SOURCE = {
    CustomerAccountName__c: 'accountName',
    Customer_Id_Type__c: 'idType',
    Customer_ID_Number__c: 'idNumber',
    Customer_Mobile__c: 'mobile',
    // The account email, or the Sales Order's primary contact where the account holds none. Apex
    // resolves that order, so the screen only has to read the one value back.
    Customer_Email__c: 'email',
    Customer_City__c: 'city',
    Customer_Bank_Name__c: 'bankName',
    // The bank the screen asks for. Same starting point as Customer_Bank_Name__c above - knownBank()
    // resolves one free text bank off the account and both fields read it - but value() only hands
    // it over when it is one of this picklist's own values. See bankFromAccount.
    UAEDDSBankName__c: 'bankName',
    Customer_Bank_Account_Name__c: 'bankAccountTitle',
    Customer_IBAN_Number__c: 'iban',
    Amount_Type__c: 'amountType',
    Payment_Frequency__c: 'paymentFrequency',
    Preferred_Payment_Method__c: 'preferredPaymentMethod'
};

/**
 * What the customer is telling the bank, read back before it is sent, with the two or three things
 * that are actually a decision picked out. Deliberately not lightning-record-edit-form: all but a
 * handful of these values are read from the account and the Sales Order, and a box around a value
 * nobody types reads as a field to fill in.
 */
export default class UaeddsMandateRequest extends NavigationMixin(LightningElement) {
    @api recordId;

    defaults;
    recordTypeId;
    picklists;
    choices = {};
    rules = [];
    checkTimer;
    /** Fields open for input. Added to as values turn out to be missing or wrong, never removed. */
    openFields = new Set();

    savedMandateId;
    mandateName;
    problems = [];
    sentMessage;
    loading = false;

    @wire(getObjectInfo, { objectApiName: DDR_OBJECT })
    objectInfo({ data }) {
        if (data) {
            this.recordTypeId = Object.keys(data.recordTypeInfos).find(
                (recordTypeId) => data.recordTypeInfos[recordTypeId].name === 'UAEDDS'
            );
        }
    }

    // Scoped by record type, so the UAEDDS lifecycle values are the only ones offered.
    @wire(getPicklistValuesByRecordType, {
        objectApiName: DDR_OBJECT,
        recordTypeId: '$recordTypeId'
    })
    picklistValues({ data }) {
        if (data) {
            this.picklists = data.picklistFieldValues;
        }
    }

    @wire(getSalesOrderDefaults, { salesOrderId: '$recordId' })
    wiredDefaults({ data, error }) {
        if (data) {
            this.defaults = data;
            // Opens whatever the account could not supply, before the first check comes back.
            this.refreshOpenFields();
            this.runCheck();
        } else if (error) {
            this.toast('Not loaded', this.readError(error), 'error', 'sticky');
        }
    }

    disconnectedCallback() {
        clearTimeout(this.checkTimer);
    }

    // ---------------------------------------------------------------- what the screen reads back

    get salesOrderName() {
        return this.defaults ? this.defaults.salesOrderName : '';
    }
    /**
     * The name the account held when the screen opened, and it does not move afterwards.
     *
     * The banner says which record is being worked on, not what is being typed into it. Following
     * the Name field made the heading rewrite itself letter by letter as the name was corrected -
     * and go blank for as long as the field was empty - which loses the one fixed point on the
     * screen at the moment it is most needed. The corrected name is read back where it is acted on:
     * in the Name field itself, and in 'In the name of', which is what the bank is actually sent.
     */
    get accountName() {
        // Apex leaves this null for a Sales Order with no customer account behind it.
        return (this.defaults && this.defaults.accountName) || '';
    }
    get switchedOff() {
        return this.defaults && !this.defaults.creationEnabled;
    }
    get showExisting() {
        return this.defaults && this.defaults.existingMandateId && !this.savedMandateId;
    }
    get showCapture() {
        return this.defaults && !this.defaults.existingMandateId && !this.savedMandateId;
    }
    get showProblems() {
        return this.savedMandateId && this.problems.length > 0;
    }
    get showSent() {
        return this.savedMandateId && this.problems.length === 0 && this.sentMessage;
    }

    value(field) {
        if (this.choices[field] !== undefined) {
            return this.choices[field];
        }
        // The bank title is the same person under a different heading, and Apex only ever offered
        // the account name as a starting point for it. So it follows whatever the name now reads,
        // rather than the name the account happened to hold when the screen opened. Correcting a
        // misspelt name once is the whole point; the branch above lets it be set apart if the rule
        // opens it and somebody types a different title.
        if (field === BANK_TITLE_FIELD) {
            return this.value('CustomerAccountName__c');
        }
        if (field === BANK_NAME_FIELD) {
            return this.bankFromAccount;
        }
        const sourceKey = DEFAULT_SOURCE[field];
        return this.defaults && sourceKey ? this.defaults[sourceKey] : undefined;
    }

    problemFor(field) {
        // The mobile is judged here rather than waiting on the check, so a bad number is marked on
        // the keystroke that makes it bad instead of 400ms later.
        if (field === 'Customer_Mobile__c') {
            return this.mobile.problem;
        }
        // Judged here for the same reason as the mobile: a missing @ is obvious on the keystroke
        // that makes it obvious, not 400ms later when the check comes back.
        if (field === 'Customer_Email__c') {
            return this.email.problem;
        }
        // Length is knowable on the keystroke, and the server rule has nothing to say about it, so
        // it is judged here. Only the length: a blank or otherwise wrong number is still the check's
        // to report, so this falls through rather than answering for the field outright.
        if (field === 'Customer_ID_Number__c' && this.idNumber.problem) {
            return this.idNumber.problem;
        }
        const failing = this.rules.find((rule) => !rule.passed && rule.field === field);
        return failing ? failing.problems.join(' ') : undefined;
    }

    /**
     * What is typed, what the bank will be sent, and whether the two amount to a UAE mobile. The
     * mandate is only ever saved with normalised, so a number entered as +971... is stored as 05...
     */
    get mobile() {
        const typed = this.value('Customer_Mobile__c');
        const normalised = normaliseMobile(typed);
        const ok = UAE_MOBILE.test(normalised);
        return {
            typed,
            normalised,
            ok,
            problem: ok ? undefined : (normalised ? MOBILE_PROBLEM : REQUIRED),
            hint: ok ? `sends as ${normalised}` : undefined
        };
    }

    /**
     * What is typed, what the bank will be sent, and whether the two amount to an address. Only the
     * trimmed value is ever saved: a copied address arrives with a trailing space often enough, and
     * UAEDDS refuses it rather than trimming it.
     */
    get email() {
        const typed = this.value('Customer_Email__c');
        const trimmed = typed ? String(typed).trim() : '';
        const ok = EMAIL.test(trimmed);
        return {
            typed,
            trimmed,
            ok,
            problem: ok ? undefined : (trimmed ? EMAIL_PROBLEM : REQUIRED),
            // Silent when there is nothing to report. Saying "sends as" against an address that is
            // character for character what was typed is noise on every screen.
            hint: ok && trimmed !== typed ? `sends as ${trimmed}` : undefined
        };
    }

    /**
     * The ID number, and whether it is within what the bank will carry. Blank is not judged here:
     * that is the check's to report, and saying "required" twice against one field is noise.
     */
    get idNumber() {
        const typed = this.value('Customer_ID_Number__c');
        const trimmed = typed ? String(typed).trim() : '';
        return {
            typed,
            trimmed,
            tooLong: trimmed.length > ID_NUMBER_MAX,
            problem: trimmed.length > ID_NUMBER_MAX ? ID_NUMBER_PROBLEM : undefined
        };
    }

    hintFor(field) {
        if (field === 'Customer_Mobile__c') {
            return this.mobile.hint;
        }
        if (field === 'Customer_Email__c') {
            return this.email.hint;
        }
        const passing = this.rules.find((rule) => rule.passed && rule.field === field);
        return passing && passing.detail && passing.detail.startsWith('sends as ')
            ? passing.detail
            : undefined;
    }

    /**
     * A value is read back rather than asked for when it exists, satisfies its rule, and the field
     * is not one the account can only guess at. A blank or failing one turns into a real input, so
     * a bad mobile on the account is fixable here instead of being a dead end.
     */
    buildLine(definition) {
        const { field, label, control, required, placeholder, type, maxLength } = definition;
        const isPicklist = control === 'picklist';
        const value = this.value(field);
        const editable = isPicklist || this.openFields.has(field);
        const problem = this.problemFor(field) || (required && !value ? REQUIRED : undefined);
        return {
            field,
            label: field === 'Customer_ID_Number__c' ? this.idNumberLabel : label,
            value,
            hint: problem ? undefined : this.hintFor(field),
            problem,
            isPicklist,
            options: isPicklist ? this.options(field) : undefined,
            required: required === true,
            placeholder,
            editable,
            type: type || 'text',
            // Undefined on every line but the ID number, which leaves the box uncapped.
            maxLength,
            // A value that is read back but still correctable, so the row carries a pencil.
            revealable: control === 'reveal' && !editable,
            // A control needs air around it; a read-back line is a row in a list and does not.
            rowClass: editable ? 'dd-row dd-row_field' : 'dd-row'
        };
    }

    /** The pencil. Opens the field for good: nothing closes it again while the screen is open. */
    handleReveal(event) {
        this.openFields = new Set(this.openFields).add(event.currentTarget.dataset.field);
    }

    /**
     * The bank title, read back above everything else. It is the customer name under another
     * heading, so it is shown rather than asked for, and it is corrected by correcting the name.
     */
    get bankTitle() {
        return {
            label: 'In the name of',
            value: this.value(BANK_TITLE_FIELD),
            problem: this.problemFor(BANK_TITLE_FIELD)
        };
    }

    /** Follows the chosen ID type, so the label never names a document the customer cannot hold. */
    get idNumberLabel() {
        return ID_NUMBER_LABEL[this.value('Customer_Id_Type__c')] || 'ID number';
    }

    /**
     * Opens any field whose value is missing or failing its rule. A field never closes again while
     * the screen is open.
     *
     * Deciding this per render from the value and the rule alone is what took the box away
     * mid-keystroke: the Emirates ID rule passes as soon as one digit is present, so typing 784 and
     * pausing turned the field back into read-back text holding a partial ID.
     */
    refreshOpenFields() {
        CUSTOMER_LINES.concat(BANK_LINES).forEach(({ field, control }) => {
            if (control === 'text' || !this.value(field) || this.problemFor(field)) {
                this.openFields.add(field);
            }
        });
        // Reassigned rather than mutated: a mutated Set does not re-render the template.
        this.openFields = new Set(this.openFields);
    }

    get sections() {
        return [
            {
                label: 'The customer',
                lines: CUSTOMER_LINES.map((definition) => this.buildLine(definition))
            },
            {
                label: 'The account to debit',
                lines: BANK_LINES.map((definition) => this.buildLine(definition))
            }
        ];
    }

    // ---------------------------------------------------------------- the decisions

    options(field) {
        if (!this.picklists || !this.picklists[field]) {
            return [];
        }
        return this.picklists[field].values.map((entry) => ({
            label: entry.label,
            value: entry.value
        }));
    }

    get accountTypeOptions() {
        return this.options('Customer_Bank_Account_Type__c');
    }
    get accountType() {
        return this.choices.Customer_Bank_Account_Type__c;
    }
    get amountType() {
        return AMOUNT_TYPE;
    }
    get accountTypeProblem() {
        return this.accountType ? undefined : REQUIRED;
    }
    get idType() {
        return this.value('Customer_Id_Type__c');
    }
    /**
     * The bank knownBank() matched off the account, offered as the starting point - but only when it
     * is one of this picklist's own values.
     *
     * knownBank() matches Account.Bank_Name__c against Customer_Bank_Name__c, which is a separate
     * value set from this one and maintained separately. An unmatched default read straight through
     * would leave the combobox showing nothing while bankName read as filled: Save would enable on a
     * bank nobody chose, and a restricted picklist would refuse the value on save.
     */
    get bankFromAccount() {
        const matched = this.defaults ? this.defaults.bankName : undefined;
        return this.options(BANK_NAME_FIELD).some((option) => option.value === matched)
            ? matched
            : undefined;
    }

    /** Read through value(), so the account default counts as chosen and only a blank one blocks. */
    get bankName() {
        return this.value(BANK_NAME_FIELD);
    }

    // Only shown when the Sales Order has no instalments to read the terms from.
    get askForTerms() {
        return this.defaults && !this.defaults.termsDerived;
    }

    get authorises() {
        if (!this.defaults || !this.defaults.termsDerived) {
            return undefined;
        }
        return {
            maximum: this.defaults.maximumAmount,
            from: this.defaults.commencesOn,
            to: this.defaults.expiresOn,
            meta: `Floor AED ${this.defaults.minimumAmount} Â· ${this.defaults.paymentFrequency} Â· ${this.defaults.preferredPaymentMethod}`
        };
    }

    handleChoice(event) {
        this.choices = { ...this.choices, [event.target.dataset.field]: event.detail.value };
        clearTimeout(this.checkTimer);
        this.checkTimer = setTimeout(() => this.runCheck(), 400);
    }

    runCheck() {
        // Everything the save will use, not only what is on screen. Built from DEFAULT_SOURCE so a
        // field that has a default but is never rendered still reaches the check.
        // The mobile goes to the check in the form it will be saved in, so the rule is run against
        // the value the bank will actually receive.
        const draft = {
            ...this.choices,
            Amount_Type__c: AMOUNT_TYPE,
            // null rather than left out, so a mobile the user has cleared is not quietly refilled
            // from the account by the fallback below.
            Customer_Mobile__c: this.mobile.normalised || null,
            // Same reason. Apex falls the blank back to the account address itself, which is what
            // the screen started from, so the check judges the same value either way.
            Customer_Email__c: this.email.trimmed || null
        };
        Object.keys(DEFAULT_SOURCE).forEach((field) => {
            const current = this.value(field);
            if (draft[field] === undefined && current) {
                draft[field] = current;
            }
        });
        checkDraft({ salesOrderId: this.recordId, draftJson: JSON.stringify(draft) })
            .then((rules) => {
                this.rules = rules || [];
                this.refreshOpenFields();
            })
            .catch(() => {
                // Never block the form on the check. The server re-runs the same rules on save.
                this.rules = [];
            });
    }

    /**
     * Disabled while anything is failing, so Save is only offered on a mandate that will actually
     * go. If checkDraft itself failed, rules is empty and nothing is blocking - the server runs the
     * same rules on save anyway, so a broken check must not trap the user on the form.
     */
    get cannotSave() {
        return (
            this.loading ||
            !this.accountType ||
            !this.idType ||
            !this.bankName ||
            !this.mobile.ok ||
            !this.email.ok ||
            this.idNumber.tooLong ||
            this.rules.some((rule) => !rule.passed)
        );
    }

    /**
     * Failing rules that belong to no field on screen, so the user can see why Save is greyed out.
     * Without this a rule the screen does not render - a missing email on the account, say - blocks
     * Save with nothing to point at.
     */
    get blockingNotes() {
        const shown = new Set(
            CUSTOMER_LINES.concat(BANK_LINES).map((definition) => definition.field)
        );
        shown.add('Customer_Bank_Account_Type__c');
        // Read back at the top of the screen rather than in a section, but still on screen.
        shown.add(BANK_TITLE_FIELD);
        return this.rules
            .filter((rule) => !rule.passed && !shown.has(rule.field))
            .map((rule) => rule.problems.join(' '));
    }

    get hasBlockingNotes() {
        return this.blockingNotes.length > 0;
    }

    // ---------------------------------------------------------------- save and send

    handleSave() {
        this.loading = true;
        // Both sent rather than left to the server default, so the mandate carries what the screen
        // said. Without the title here Apex falls back to the account name it read at the start,
        // and a name corrected on screen would be saved against the old title.
        const choices = {
            ...this.choices,
            Amount_Type__c: AMOUNT_TYPE,
            // Only the validated number is saved. Whatever was typed - +971..., spaces, hyphens -
            // the record carries 05XXXXXXXX, which is the one form UAEDDS accepts.
            Customer_Mobile__c: this.mobile.normalised,
            // Sent whether or not it was typed over, so the record carries the address the screen
            // read back rather than leaving Apex to read the account a second time.
            Customer_Email__c: this.email.trimmed,
            Customer_Bank_Account_Name__c: this.value(BANK_TITLE_FIELD),
            // Sent whether it was picked or came off the account, so Apex is handed the bank the
            // screen read back rather than resolving it a second time. createMandateRecord writes
            // it straight to UAEDDSBankName__c, and the vendor payload prefers that field, so a
            // bank corrected here is the one the bank is told about.
            [BANK_NAME_FIELD]: this.bankName
        };

        createMandateRecord({ salesOrderId: this.recordId, choices })
            .then((mandateId) => {
                this.savedMandateId = mandateId;
                this.mandateName = 'Success';
                return validateMandate({ mandateId });
            })
            .then((problems) => {
                this.problems = problems || [];
                if (this.problems.length > 0) {
                    return null;
                }
                if (this.switchedOff) {
                    this.sentMessage =
                        'Saved. It will go to the bank once mandate creation is switched on.';
                    return null;
                }
                this.sentMessage = ' Mandate Created.';
                //this.toast('Sent', this.sentMessage, 'success');
                //this.handleClose();
            })
            .catch((error) => {
                if (this.savedMandateId) {
                    this.problems = [this.readError(error)];
                } else {
                    this.toast('Not saved', this.readError(error), 'error', 'sticky');
                }
            })
            .finally(() => {
                this.loading = false;
            });
    }

    // Create at the bank, then fetch the unsigned form. Two callouts, never in one transaction
    // with the document decode.
    /*send() {
        return createMandate({ mandateId: this.savedMandateId })
            .then((message) => {
                this.sentMessage = message;
                return fetchDocument({ mandateId: this.savedMandateId, signed: false });
            })
            .then(() => {
                this.sentMessage += ' The unsigned form is filed with the mandate.';
                this.toast('Sent', this.sentMessage, 'success');
            });
    }*/

    handleOpenExisting() {
        this.open(this.defaults.existingMandateId);
    }
    handleOpenSaved() {
        this.open(this.savedMandateId);
    }

    /**
     * Opens the mandate itself, not the Sales Order the action was raised from.
     *
     * The navigation is asked for before the modal is closed, and the close is left to the next
     * tick. Closing first destroys this component synchronously, and a Navigate issued from a
     * component already being torn down is dropped - which left the user on the Sales Order they
     * started on, looking like the mandate had never been opened.
     */
    open(recordId) {
        if (!recordId) {
            return;
        }
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId, objectApiName: 'DirectDebitRequest__c', actionName: 'view' }
        });
        // The modal does not close on its own when the page behind it changes, so it still has to
        // be closed - just not before the navigation has been handed over.
        setTimeout(() => this.dispatchEvent(new CloseActionScreenEvent()), 0);
    }

    handleClose() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    readError(error) {
        if (error && error.body && error.body.message) {
            return error.body.message;
        }
        if (error && error.message) {
            return error.message;
        }
        return 'Something went wrong. The call is in the Direct Debit logs.';
    }

    toast(title, message, variant, mode) {
        this.dispatchEvent(
            new ShowToastEvent({ title, message, variant, mode: mode || 'dismissable' })
        );
    }
}