import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import Toast from 'lightning/toast';
import USER_ID from '@salesforce/user/Id';
import { getRecord } from 'lightning/uiRecordApi';
import { getObjectInfo, getPicklistValuesByRecordType } from 'lightning/uiObjectInfoApi';
import LEAD_OBJECT from '@salesforce/schema/Lead';

import getCurrentUserInfo from '@salesforce/apex/MBP_utilityclass.getCurrentUserInfo';
import getUnitRecords from '@salesforce/apex/MBP_ManagePropertiesController.getRecords';
import getLeadUserDetails from '@salesforce/apex/MBP_BrokerLeadcontroller.getUserDetails';
import getFilteredLeads from '@salesforce/apex/MBP_BrokerLeadcontroller.getFilteredLeads';
import createOrUpdateLead from '@salesforce/apex/MBP_BrokerLeadcontroller.createOrUpdateLead';
import getUploadedDocuments from '@salesforce/apex/MBP_BrokerLeadcontroller.getUploadedDocuments';
import deleteLeadDocuments from '@salesforce/apex/MBP_BrokerLeadcontroller.deleteLeadDocuments';
import deleteLeadDocumentFile from '@salesforce/apex/MBP_BrokerLeadcontroller.deleteLeadDocumentFile';
import VAT_UNDERTAKING_TEMPLATE from '@salesforce/resourceUrl/MBP_Leaduntertakingform';
import KYC_FORM_TEMPLATE from '@salesforce/resourceUrl/MBP_KYC_Form';
import uploadFileToDocumentRecord from '@salesforce/apex/MBP_BrokerLeadcontroller.uploadFileToDocumentRecord';
import validateEmail from '@salesforce/apex/MBP_LoqateIntegration.validateEmail';
import validatePhone from '@salesforce/apex/MBP_LoqateIntegration.validatePhone';
import getOpportunitiesForAgency from '@salesforce/apex/MBP_BrokerOpportunityController.getOpportunitiesForAgency';
import getSalesOrdersForOpportunity from '@salesforce/apex/MBP_BrokerOpportunityController.getSalesOrdersForOpportunity';
import getEOIRecords from '@salesforce/apex/MBP_ExpressionOfInterestsController.getEOIRecords';
import getEoiPicklistValues from '@salesforce/apex/MBP_ExpressionOfInterestsController.getPicklistValues';
import createEoiLead from '@salesforce/apex/MBP_ExpressionOfInterestsController.createLead';
// BP-054: the broker catalogue arrives in one read and drives all three fields, so the interest
// step makes no round trip per choice and never depends on Phase or Typology being empty.
import getBrokerRangeOptions from '@salesforce/apex/MBP_ExpressionOfInterestsController.getBrokerRangeOptions';
import prepareBrokerOpportunity from '@salesforce/apex/MBP_ExpressionOfInterestsController.prepareBrokerOpportunity';
import createInterestLink from '@salesforce/apex/MBP_EoiPaymentLinkController.createInterestLink';
import getEoiPaymentLinks from '@salesforce/apex/MBP_EoiPaymentLinkController.getEoiPaymentLinks';
import getBrokerPendingLinks from '@salesforce/apex/MBP_EoiPaymentLinkController.getBrokerPendingLinks';
import resendBrokerLink from '@salesforce/apex/MBP_EoiPaymentLinkController.resendBrokerLink';
import renewBrokerLink from '@salesforce/apex/MBP_EoiPaymentLinkController.renewBrokerLink';
import cancelBrokerPayment from '@salesforce/apex/MBP_EoiPaymentLinkController.cancelBrokerPayment';
import startVerification from '@salesforce/apex/VerificationService.startVerification';
import resendVerification from '@salesforce/apex/VerificationService.resendVerification';
import verifyCode from '@salesforce/apex/VerificationService.verifyCode';
import MBP_EnableEoi from '@salesforce/label/c.MBP_EnableEoi';
import MBP_EnableNewEoi from '@salesforce/label/c.MBP_EnableNewEoi';

const PAGE_SIZE = 8;
/* BP-039 (client, 10 Sep 2026): the full period list - All Time and Last 12
   Months (BP-033) plus the four presets this tab offered before - the same list
   as the dashboard and the Performance tab. All Time stays the default. */
const LEADS_PERIODS = [
    { value: 'All Time', label: 'All Time' },
    { value: 'Last 12 Months', label: 'Last 12 Months' },
    { value: 'Current Year', label: 'Current Year' },
    { value: 'Previous Year', label: 'Previous Year' },
    { value: 'Current FY', label: 'Current FY' },
    { value: 'Previous FY', label: 'Previous FY' }
];
const LEADS_DEFAULT_PERIOD = 'All Time';
/* getFilteredLeads resolves the FY / calendar-year names itself, so those four
   travel by name with no dates (the contract this tab always had). It does not
   know All Time or Last 12 Months, so those travel as explicit dates - the same
   definitions mbpr_dashboardWorkspace and mbpr_leadPerformance use. */
const LEADS_APEX_RESOLVED_PERIODS = new Set(['Current Year', 'Previous Year', 'Current FY', 'Previous FY']);
function resolveLeadsPeriodRange(period) {
    if (LEADS_APEX_RESOLVED_PERIODS.has(period)) {
        return { startDate: null, endDate: null };
    }
    const today = new Date();
    const iso = (d) =>
        `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
    if (period === 'Last 12 Months') {
        const lastMonthEnd = new Date(today.getFullYear(), today.getMonth(), 0);
        const start = new Date(lastMonthEnd.getFullYear(), lastMonthEnd.getMonth() - 11, 1);
        return { startDate: iso(start), endDate: iso(lastMonthEnd) };
    }
    const tomorrow = new Date(today.getFullYear(), today.getMonth(), today.getDate() + 1);
    return { startDate: '1900-01-01', endDate: iso(tomorrow) };
}

const UNIT_FIELDS = [
    'CreatedDate',
    'Status__c',
    'BasePrice__c',
    'TotalPrice__c',
    'Number_of_Bedrooms__c',
    'Phase__c',
    'Phase__r.Name',
    'Phase__r.Project__r.Name',
    'UnitClassification__c',
    'Typology__c',
    'View__c',
    'TotalArea__c',
    'Masterplan_URL__c'
];

const LEAD_PICKLIST_FIELDS = [
    ['Salutation', 'salutationOptions'],
    ['UAEResidentStatus__c', 'residentStatusOptions'],
    ['CountryOfResidence__c', 'countryOptions'],
    ['Nationality__c', 'nationalityOptions'],
    ['SalesOrigin__c', 'salesOriginOptions'],
    ['LeadOrigin__c', 'leadOriginOptions'],
    ['SalesType__c', 'salesTypeOptions'],
    ['ProjectInterest__c', 'projectInterestOptions'],
    ['UnitType__c', 'unitTypeOptions'],
    ['NumberOfBedrooms__c', 'bedroomOptions'],
    ['CustomerBudget__c', 'budgetOptions'],
    ['PurposeOfUse__c', 'purposeOptions'],
    ['VAT_Certificate_Type__c', 'vatCertificateTypeOptions']
];

const LEAD_PICKLIST_FIELD_ALIASES = {
    PurposeOfUse__c: 'PurposeofUse__c'
};

const LEAD_PICKLIST_FORM_FIELDS = {
    VAT_Certificate_Type__c: 'vatCertificateType'
};

const LEGACY_DISABLED_LEAD_FIELDS = [
    'PropertyUsage__c',
    'BuyRent__c',
    'PropertyReadiness__c',
    'Finance__c'
];

const LEAD_PICKLIST_OPTION_FALLBACKS = {
    CountryOfResidence__c: [
        ['Nationality__c', 'nationalityOptions'],
        ['LeadOrigin__c', 'leadOriginOptions']
    ]
};

const LEAD_FIELD_LABELS = {
    Salutation: 'Salutation',
    UAEResidentStatus__c: 'Resident status',
    CountryOfResidence__c: 'Country',
    Nationality__c: 'Nationality',
    SalesOrigin__c: 'Sales origin',
    LeadOrigin__c: 'Lead origin',
    SalesType__c: 'Sales type',
    ProjectInterest__c: 'Project name',
    UnitType__c: 'Unit type',
    NumberOfBedrooms__c: 'Number of bedrooms',
    CustomerBudget__c: 'Customer budget',
    PurposeOfUse__c: 'Purpose of use',
    VAT_Certificate_Type__c: 'VAT certificate type'
};

const LEAD_FORM_REQUIRED_RECORD_FIELDS = ['Lead.LastName'];

/* BP-024 - person-identity fields an Organization lead never carries. */
const LEAD_IDENTITY_DOCUMENT_FIELDS = [
    'EIDNumber__c',
    'EmiratesIDExpiryDate__c',
    'PassportNumber__c',
    'PassportIssueDate__c',
    'PassportExpiryDate__c'
];

const LEAD_FORM_OPTIONAL_RECORD_FIELDS = [
    'Lead.RecordTypeId',
    'Lead.Salutation',
    'Lead.FirstName',
    'Lead.Company',
    'Lead.Email',
    'Lead.MobilePhone',
    'Lead.UAEResidentStatus__c',
    'Lead.CountryOfResidence__c',
    'Lead.Nationality__c',
    'Lead.EIDNumber__c',
    'Lead.EmiratesIDExpiryDate__c',
    'Lead.PassportNumber__c',
    'Lead.PassportIssueDate__c',
    'Lead.PassportExpiryDate__c',
    'Lead.SalesOrigin__c',
    'Lead.LeadOrigin__c',
    'Lead.SalesType__c',
    'Lead.ProjectInterest__c',
    'Lead.UnitType__c',
    'Lead.NumberOfBedrooms__c',
    'Lead.CustomerBudget__c',
    'Lead.PurposeofUse__c',
    'Lead.PropertyReadiness__c',
    'Lead.Finance__c',
    'Lead.PropertyUsage__c',
    'Lead.BuyRent__c',
    'Lead.Description',
    'Lead.UnifiedNumber__c',
    'Lead.UAEVATRegisterNumber__c',
    'Lead.VAT_Certificate_Type__c',
    'Lead.Trade_License_Number__c'
];

const LEAD_PHONE_PATTERN = /^\+(?:[0-9] ?){6,14}[0-9]$/;
const EMIRATES_ID_PATTERN = /^784-\d{4}-\d{7}-\d{1}$/;
const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

const VERIFICATION_CODE_LENGTH = 6;
const VERIFICATION_CHANNELS = [
    { key: 'email', label: 'Email', icon: 'utility:email', channel: 'Email' },
    { key: 'sms', label: 'SMS', icon: 'utility:sms', channel: 'SMS' },
    { key: 'whatsapp', label: 'WhatsApp', icon: 'utility:chat', channel: 'WhatsApp', comingSoon: true }
];

function findVerificationChannel(key) {
    return VERIFICATION_CHANNELS.find((channel) => channel.key === key) || null;
}

// Same masks VerificationService writes to Masked_Target__c, so the row text
// before sending matches the "Code sent to" text after sending.
function maskVerificationEmail(value) {
    const parts = String(value || '').trim().split('@');
    if (parts.length !== 2 || !parts[0]) return '***';
    return `${parts[0].substring(0, Math.min(2, parts[0].length))}***@${parts[1]}`;
}

function maskVerificationPhone(value) {
    const digits = String(value || '').replace(/[^0-9]/g, '');
    return digits.length > 4 ? `****${digits.slice(-4)}` : '****';
}

function formatCountdown(totalSeconds) {
    const seconds = Math.max(0, Number(totalSeconds) || 0);
    const minutes = Math.floor(seconds / 60);
    return `${minutes}:${String(seconds % 60).padStart(2, '0')}`;
}

function scheduleFrame(callback) {
    if (typeof requestAnimationFrame === 'function') {
        requestAnimationFrame(callback);
    } else {
        callback();
    }
}

/* Emirates ID mask, 3-4-7-1 over at most 15 digits. Stored in the same
   hyphenated shape the org matches on (EIDNumber__pc equality in the EOI
   conversion, the same shape the console journey stores), so the value typed
   is the value saved. */
const EMIRATES_ID_GROUPS = [3, 4, 7, 1];

function formatEmiratesId(raw) {
    const digits = String(raw || '').replace(/\D/g, '').slice(0, 15);
    let formatted = '';
    let index = 0;
    for (const size of EMIRATES_ID_GROUPS) {
        if (index >= digits.length) break;
        if (formatted) formatted += '-';
        formatted += digits.slice(index, index + size);
        index += size;
    }
    return formatted;
}

/** Reformats the input in place and keeps the caret after the same digit. */
function applyEmiratesIdMask(input) {
    const value = input.value || '';
    const caret = typeof input.selectionStart === 'number' ? input.selectionStart : value.length;
    const digitsBeforeCaret = value.slice(0, caret).replace(/\D/g, '').length;
    const formatted = formatEmiratesId(value);
    if (input.value !== formatted) input.value = formatted;
    let position = 0;
    let seen = 0;
    while (position < formatted.length && seen < digitsBeforeCaret) {
        if (/\d/.test(formatted[position])) seen += 1;
        position += 1;
    }
    try {
        input.setSelectionRange(position, position);
    } catch (error) {
        // Not every input type supports selection; the value is already right.
    }
    return formatted;
}

/* `sides` splits one document type into several upload slots, but both still
   upload under the single type label: uploadFileToDocumentRecord looks the
   parent up by `Documents__c.Name = documentTypeLabel`, and a per-side label
   like "Emirates ID Front" has no matching record and would throw. Legacy does
   the same, sending front and back as 'Emirates ID' with their own filenames. */
const DOCUMENT_TYPES = [
    { key: 'emirates-id', label: 'Emirates ID', sides: ['Front', 'Back'] },
    { key: 'passport-copy', label: 'Passport Copy', sides: ['Front', 'Back'] },
    { key: 'kyc-form', label: 'Complete KYC Form' },
    { key: 'funds', label: '3 month Bank statement/source of funds' },
    { key: 'trade-license', label: 'Trade License' },
    { key: 'vat-register', label: 'VAT Register' },
    { key: 'vat-undertaking', label: 'VAT Undertaking' }
];

/* Slot keys are "<type><sep><side>" so leadFiles can hold one entry per side
   while every consumer can still recover the Apex-facing type label. */
const DOCUMENT_SIDE_SEPARATOR = '::';

function documentSlotKey(documentType, side) {
    return side ? `${documentType}${DOCUMENT_SIDE_SEPARATOR}${side}` : documentType;
}

function documentTypeFromSlotKey(slotKey) {
    return String(slotKey || '').split(DOCUMENT_SIDE_SEPARATOR)[0];
}

// Every broker EOI is paid online through a Checkout link (BP-030); the picklist is not asked.
const EOI_PAYMENT_TYPE_ONLINE = 'Online';
// BP-032: EOI number shows only once the customer's payment is captured; Void only while the link is untouched
// BP-041: the EOI number shows once the money is held or taken (mirrors MBP_EoiPaymentLinkController.EOI_NUMBER_VISIBLE_STATUSES)
const EOI_NUMBER_VISIBLE_STATUSES = new Set(['Authorized', 'Captured', 'Refunded', 'Partially Refunded']);
// BP-035: table cells never sit empty - a value that is not available yet shows this
const EOI_TABLE_PLACEHOLDER = '...';

/* BP-056 (11 Sep 2026): the broker EOI table shows FOUR words and never a stored value. MODON's
   list: Pending Payment, Expired, Paid, Cancelled. The payment record decides wherever one exists,
   because every status the broker cares about is a payment state; an older EOI raised before the
   payment rail falls back to its own status, which the lapse trigger keeps in step anyway. An
   unrecognised value resolves to Pending Payment rather than printing itself, so a picklist value
   added in the org later can never leak onto a broker's screen. */
const EOI_STATUS_PENDING = 'Pending Payment';
const EOI_STATUS_EXPIRED = 'Expired';
const EOI_STATUS_PAID = 'Paid';
const EOI_STATUS_CANCELLED = 'Cancelled';
/* BP-067 (12 Sep 2026): MODON approved Checkout_Payment__c.Dashboard_Status__c as the source of
   the word a broker reads, and it emits two the table never showed before. Refunded covers what
   this file used to call Cancelled (Voided and Refunded); Declined used to read Pending Payment.
   Both are the client's wording, not ours, so they are printed exactly as the formula returns. */
const EOI_STATUS_REFUNDED = 'Refunded';
const EOI_STATUS_DECLINED = 'Declined';

const EOI_PAYMENT_STATUS_LABELS = {
    'link created': EOI_STATUS_PENDING,
    declined: EOI_STATUS_PENDING,
    expired: EOI_STATUS_EXPIRED,
    authorized: EOI_STATUS_PAID,
    captured: EOI_STATUS_PAID,
    // part of the money is still with MODON, so the request stands
    'partially refunded': EOI_STATUS_PAID,
    voided: EOI_STATUS_CANCELLED,
    refunded: EOI_STATUS_CANCELLED
};

const EOI_RECORD_STATUS_LABELS = {
    new: EOI_STATUS_PENDING,
    'in progress': EOI_STATUS_PENDING,
    'pending with finance': EOI_STATUS_PENDING,
    expired: EOI_STATUS_EXPIRED,
    submitted: EOI_STATUS_PAID,
    approved: EOI_STATUS_PAID,
    completed: EOI_STATUS_PAID,
    'eoi confirmed': EOI_STATUS_PAID,
    'payment authorized': EOI_STATUS_PAID,
    voided: EOI_STATUS_CANCELLED,
    cancelled: EOI_STATUS_CANCELLED,
    canceled: EOI_STATUS_CANCELLED,
    rejected: EOI_STATUS_CANCELLED
};

/* Four labels, four distinct badges. Expired still needs the broker to act, so it keeps the error
   tone; a cancelled row is finished and goes quiet. getStatusTone stays exactly as it is - it is
   shared with Leads, Opportunities and Sales Orders and knows nothing about the word "Paid". */
const EOI_STATUS_TONES = {
    [EOI_STATUS_PENDING]: 'warning',
    [EOI_STATUS_EXPIRED]: 'error',
    [EOI_STATUS_PAID]: 'success',
    [EOI_STATUS_CANCELLED]: 'muted',
    // BP-067: the money is back with the customer and the row is finished, so it goes quiet
    [EOI_STATUS_REFUNDED]: 'muted',
    // the payment failed and the customer needs a fresh link - the same call to action as Expired
    [EOI_STATUS_DECLINED]: 'error'
};

/* BP-057: a request can still read 'Link Created' after its clock has run out, because
   CheckoutPaymentPoller only flips it on its next pass. Until then the stored status says payable
   while the URL is already dead, so the clock decides - the same rule the server enforces in
   MBP_EoiPaymentLinkController.resendBrokerLink and renewBrokerLink. */
function eoiLinkHasLapsed(paymentStatus, expiresOn) {
    if (String(paymentStatus || '').trim().toLowerCase() !== 'link created') return false;
    const at = expiresOn ? Date.parse(expiresOn) : NaN;
    return Number.isFinite(at) && at < Date.now();
}

// BP-057/058: at most one action per row, decided by the stored payment status and the clock.
/* BP-060: the name of each action says what the customer gets. RESEND puts the link they already
   have back in front of them, unchanged, with the same expiry. NEW mints a second payment request
   with its own number and its own expiry, and retires the spent one. */
const EOI_ACTION_RESEND = 'resend';
const EOI_ACTION_NEW = 'new';
const EOI_ACTION_CANCEL = 'cancel';
const EOI_ACTION_LABELS = {
    [EOI_ACTION_RESEND]: 'Resend link',
    [EOI_ACTION_NEW]: 'Send new link',
    [EOI_ACTION_CANCEL]: 'Cancel'
};

/* BP-059: an action acts on the Checkout_Payment__c record, so a row with no payment record id has
   nothing to act on and offers nothing. This is the guard, not a comment: an EOI row carries the
   EOI's own id, and before this the Cancel button sent that id to Apex, which looked for a payment
   with it and refused "That payment request could not be found." No payment id, no action - so the
   button can never again be handed something that is not a payment. */
function eoiRowAction(isPending, paymentStatus, expiresOn, paymentRecordId, superseded) {
    if (!paymentRecordId) return '';
    const status = String(paymentStatus || '').trim().toLowerCase();
    /* BP-058: a held payment can be released, whether or not its EOI has been raised yet. Once the
       money is CAPTURED nothing is offered: reversing a taken payment is a finance process, and the
       rail deliberately leaves a captured EOI to it. Held money stays releasable even on a request a
       newer one has replaced - money is never left stranded by a display rule. */
    if (status === 'authorized') return EOI_ACTION_CANCEL;
    if (!isPending) return '';                       // any other EOI row means the money is already taken
    /* BP-060: a request a newer one has replaced keeps its number and its history and offers nothing,
       so one interest can never carry two live asks. Apex decides this and re-proves it before acting. */
    if (superseded === true) return '';
    if (status === 'expired' || eoiLinkHasLapsed(status, expiresOn)) return EOI_ACTION_NEW;
    return status === 'link created' ? EOI_ACTION_RESEND : '';
}

/* Every row carries the same keys whether or not it has an action, so the nine grid tracks are
   always filled and the desktop columns can never slip out of line. */
function eoiRowActionFields(action, paymentRecordId) {
    return {
        // what the action acts on. NEVER the row id: a pending row's id is its payment, an EOI row's
        // id is the EOI, and the drawer needs that one.
        paymentRecordId: paymentRecordId || '',
        rowAction: action,
        hasRowAction: Boolean(action),
        rowActionLabel: EOI_ACTION_LABELS[action] || '',
        rowActionClass: action ? 'record-action' : 'record-action record-action--empty',
        // releasing money reads as a destructive action, so it carries the danger modifier
        rowActionButtonClass: action === EOI_ACTION_CANCEL
            ? 'record-action__button record-action__button--danger'
            : 'record-action__button'
    };
}

/* BP-067: wherever a payment record exists the approved formula field decides, printed verbatim.
   Two rules still sit above and below it, both deliberate.
   ABOVE - the expiry clock still wins, because the formula reads the stored status and the poller
   can be minutes behind it; without this a dead link would read Pending Payment next to its own
   'Send new link' button, which is the contradiction BP-057 removed.
   BELOW - EOI_PAYMENT_STATUS_LABELS is now only a safety net for a payment row whose formula value
   did not arrive, and EOI_RECORD_STATUS_LABELS still answers for a legacy EOI raised before the
   payment rail, which has no payment record and so no formula value at all. */
function eoiBrokerStatus(dashboardStatus, paymentStatus, recordStatus, expiresOn) {
    if (eoiLinkHasLapsed(paymentStatus, expiresOn)) return EOI_STATUS_EXPIRED;
    const approved = String(dashboardStatus || '').trim();
    if (approved) return approved;
    const payment = String(paymentStatus || '').trim().toLowerCase();
    if (payment && EOI_PAYMENT_STATUS_LABELS[payment]) return EOI_PAYMENT_STATUS_LABELS[payment];
    const record = String(recordStatus || '').trim().toLowerCase();
    if (record && EOI_RECORD_STATUS_LABELS[record]) return EOI_RECORD_STATUS_LABELS[record];
    return EOI_STATUS_PENDING;
}

function eoiBrokerStatusTone(label) {
    return EOI_STATUS_TONES[label] || 'muted';
}

const EOI_PATH_STEPS = [
    { key: 'customer', label: 'Customer', caption: 'Capture buyer profile' },
    { key: 'verification', label: 'Verify', caption: 'Confirm contact access' },
    { key: 'interests', label: 'Interest', caption: 'Select project and units' },
    { key: 'success', label: 'Submit', caption: 'Send payment requests' }
];

const LEAD_TYPE_OPTIONS = [
    { value: 'Individual', label: 'Individual' },
    { value: 'Organization', label: 'Organization' }
];

/* EOI customer step. The type is chosen first and shapes the grid; the same
   eleven createLead arguments are sent either way, with the fields the other
   type does not show sent blank (Apex routes on Company). */
const EOI_CUSTOMER_TYPES = [
    { value: 'Individual', label: 'Individual' },
    { value: 'Organization', label: 'Organization' }
];
/* Fields that survive a type switch; everything else is cleared. */
const EOI_CUSTOMER_SHARED_FIELDS = ['leadId', 'firstName', 'lastName', 'email', 'mobile'];
// BP-053: a Resident lives in the UAE, so Country of residence is filled in and locked for them.
// Matched against the live picklist rather than trusted blindly - see eoiResidentCountryValue.
const EOI_UAE_COUNTRY = 'United Arab Emirates';
const EOI_MOBILE_FORMAT_MESSAGE = 'Enter a valid international mobile number, for example +971581234567.';
const EOI_MOBILE_FAILED_MESSAGE = 'Mobile number failed validation. Enter a valid mobile number with country code.';

function emptyLeadForm() {
    return {
        Id: '',
        Type: 'Individual',
        Salutation: '',
        FirstName: '',
        LastName: '',
        Email: '',
        MobilePhone: '',
        UAEResidentStatus__c: '',
        CountryOfResidence__c: '',
        Nationality__c: '',
        EIDNumber__c: '',
        EmiratesIDExpiryDate__c: '',
        PassportNumber__c: '',
        PassportIssueDate__c: '',
        PassportExpiryDate__c: '',
        Name: '',
        UnifiedNumber__c: '',
        UAEVATRegisterNumber__c: '',
        vatCertificateType: '',
        SalesOrigin__c: 'International',
        LeadOrigin__c: '',
        SalesType__c: '',
        ProjectInterest__c: '',
        UnitType__c: '',
        NumberOfBedrooms__c: '',
        CustomerBudget__c: '',
        PurposeOfUse__c: '',
        PropertyReadiness__c: '',
        Finance__c: '',
        PropertyUsage__c: '',
        BuyRent__c: '',
        Description: ''
    };
}

function emptyEoiCustomer() {
    return {
        leadId: '',
        customerType: 'Individual',
        firstName: '',
        lastName: '',
        email: '',
        mobile: '',
        residentStatus: '',
        country: '',
        nationality: '',
        emiratesId: '',
        passportNumber: '',
        company: '',
        tradeLicenseNumber: ''
    };
}

/* BP-051: a native <select> only shows a stored value when the chosen <option> carries
   `selected` as the option is created. Assigning the select's own value is a no-op while
   the element still has no options, which is exactly the state a freshly rendered card is
   in, so a re-opened card came back blank. Both are applied now. */
function markSelectedOption(options, value) {
    const list = Array.isArray(options) ? options : [];
    return list.map((option) => ({ ...option, isSelected: option.value === value }));
}

// BP-051: strictly increasing, so an add and a remove inside the same millisecond can
// never mint two rows with the same key and break the for:each.
let eoiInterestSequence = 0;

/* BP-052: the EOI table is one list, newest first. The payment number is an AutoNumber
   (`CP-{00000}`) and it is the only key a pending request and a real EOI both carry, so it
   is the creation order for both. A row with no payment number sorts last; the sort is
   stable, so those keep the order Apex sent them in. */
function eoiPaymentSequence(row) {
    const digits = String(row?.paymentName || '').replace(/\D/g, '');
    return digits ? Number(digits) : -1;
}

function emptyEoiInterest(index = 0) {
    return {
        key: `interest-${Date.now()}-${index}-${(eoiInterestSequence += 1)}`,
        selectedProjectId: '',
        selectedProjectName: '',
        selectedPhaseId: '',
        selectedUnitType: '',
        selectedBedrooms: '',
        selectedUnitTypology: '',
        numberOfUnits: 1,
        remarks: '',
        matchedRangeId: '',
        matchedAmount: 0,
        eoiAmountLabel: 'AED 0'
        /* BP-054: the four option arrays that used to live here are gone. The lists now come
           from the catalogue getters, so a row carried four copies nothing ever read. The two
           phase/typology VALUES stay: the payload shape to the rail is unchanged, they are
           simply always blank now. */
    };
}


/* Lead status 'Qualified' is shown as 'Converted To Opportunity'. Exact
   match on the whole trimmed value, because 'Lead Qualified' is a separate
   status that keeps its own name. Presentation only: the raw value still
   drives counting, filtering and tones. */
function leadStatusLabel(status) {
    const raw = String(status || '').trim();
    return raw.toLowerCase() === 'qualified' ? 'Converted To Opportunity' : raw;
}

/* BP-023 - 'Qualified' is the org's only converted lead status and cannot be set
   by hand, so status alone says whether a lead has become an opportunity. The
   list wrapper carries no IsConverted, which is why status is the key. */
function isConvertedLead(lead) {
    return String(lead?.Status || '').trim().toLowerCase() === 'qualified';
}

export default class MbprSalesWorkspace extends LightningElement {
    @api launchIntent = '';
    @api eoiOnly = false;
    @api launchToken = '';
    @api directLeadForm = false;
    /* Standalone New EOI drawer: same chrome-less host as the
       direct lead form - only the EOI form drawer renders. */
    @api directEoiForm = false;
    /* BP-018 - Fast-Track (limited login + Fast Track service request) may work
       leads only. The shell decides who is Fast-Track; this flag hides the
       Opportunities tab everywhere it renders and stops the data fetch. */
    @api fastTrack = false;

    activeTab = 'performance';
    userInfo = {};
    accountId = '';
    contactId = '';
    brokerType = '';
    isBootLoading = true;
    bootError = false;

    leadRecords = [];
    isLeadsLoading = true;
    leadsError = false;
    leadPeriod = LEADS_DEFAULT_PERIOD;
    leadSearch = '';
    leadStatusFilter = 'all';
    leadProjectFilter = 'all';
    leadUnitTypeFilter = 'all';
    leadAgentFilter = 'all';
    leadStartDate = '';
    leadEndDate = '';
    pendingLeadStartDate = '';
    pendingLeadEndDate = '';
    pendingLeadPeriod = LEADS_DEFAULT_PERIOD;
    pendingLeadStatusFilter = 'all';
    pendingLeadProjectFilter = 'all';
    pendingLeadUnitTypeFilter = 'all';
    pendingLeadAgentFilter = 'all';
    isLeadFilterPanelOpen = false;
    leadPage = 1;
    leadPicklistsLoaded = false;
    leadObjectRecordTypeId = '';
    leadUiPicklistsError = false;
    leadPicklistFieldValues = {};
    leadPicklists = {};

    opportunities = [];
    isOpportunitiesLoading = true;
    opportunitiesError = false;
    opportunitySearch = '';
    opportunityStageFilter = 'all';
    opportunityProjectFilter = 'all';
    opportunityResidentStatusFilter = 'all';
    opportunityBrokerAgentFilter = 'all';
    opportunitySalesManagerFilter = 'all';
    opportunityStartDate = '';
    opportunityEndDate = '';
    pendingOpportunityStartDate = '';
    pendingOpportunityEndDate = '';
    pendingOpportunityStageFilter = 'all';
    pendingOpportunityProjectFilter = 'all';
    pendingOpportunityResidentStatusFilter = 'all';
    pendingOpportunityBrokerAgentFilter = 'all';
    pendingOpportunitySalesManagerFilter = 'all';
    isOpportunityFilterPanelOpen = false;
    opportunityPage = 1;
    salesOrders = [];
    isSalesOrdersLoading = false;
    salesOrdersError = false;

    eoiRecords = [];
    isEoiLoading = true;
    eoiError = false;
    eoiSearch = '';
    eoiStatusFilter = 'all';
    eoiProjectFilter = 'all';
    eoiPhaseFilter = 'all';
    eoiUnitTypeFilter = 'all';
    eoiBedroomsFilter = 'all';
    pendingEoiStatusFilter = 'all';
    pendingEoiProjectFilter = 'all';
    pendingEoiPhaseFilter = 'all';
    pendingEoiUnitTypeFilter = 'all';
    pendingEoiBedroomsFilter = 'all';
    isEoiFilterPanelOpen = false;
    eoiPage = 1;
    eoiPicklistsLoaded = false;
    eoiPicklists = {};
    eoiProjectOptions = [];
    eoiRangeCatalog = [];          // BP-054: active broker ranges, exactly as the org returns them

    unitRecords = [];
    isUnitsLoading = true;
    unitsError = false;

    drawerMode = '';
    selectedLeadId = '';
    selectedOpportunityId = '';
    selectedEoiId = '';
    selectedLeadDocuments = [];
    pendingDeleteDocumentKey = '';
    isDocumentsLoading = false;
    documentsError = false;
    // BP-015 - per-file delete confirm inside the edit form's upload cards
    pendingDeleteFileId = '';
    isDeletingLeadFile = false;
    leadForm = emptyLeadForm();
    leadFiles = {};
    isSavingLead = false;
    isLeadFormHydrating = false;
    leadHydrateRecordId;
    leadFormMessage = '';
    /* BP-005 - Loqate runs by itself when the broker leaves the Email or
       Mobile field: only for a value that passes the local format check,
       never twice for the same value, and never for a value loaded from a
       saved lead until the broker changes it. status: '' | 'known' (loaded,
       nothing shown) | 'checking' | 'valid' | 'invalid'. Save still re-runs
       both checks - this is feedback, not the guard. */
    leadEmailCheck = { value: '', status: '', message: '' };
    leadMobileCheck = { value: '', status: '', message: '' };
    leadFormMessageTone = 'info';


    eoiStep = 'customer';
    eoiCustomer = emptyEoiCustomer();
    /* Loqate results for the EOI customer step, same shape as the lead checks. */
    eoiEmailCheck = { value: '', status: '', message: '' };
    eoiMobileCheck = { value: '', status: '', message: '' };
    eoiSubmitPhase = '';
    eoiSubmittedLinks = [];
    eoiSubmittedOpportunityId = '';   // BP-041: the one Opportunity the payment requests hang off
    eoiDoneArmed = false;             // BP-041: Done with unsent requests asks once before closing
    isEoiRetryingLinks = false;
    eoiInterests = [emptyEoiInterest(0)];
    openEoiInterestKey = '';          // the one interest showing its fields; '' = all folded
    isEoiSaving = false;
    eoiFormMessage = '';
    eoiFormMessageTone = 'info';
    verificationMethod = '';
    verificationDigits = this.getBlankVerificationDigits();
    verificationRequestId = '';
    verificationMaskedTarget = '';
    verificationCodeError = '';
    verificationCompleted = false;
    verificationExpired = false;
    verificationFailed = false;
    verificationExpiresAt = null;
    verificationExpirySeconds = 0;
    verificationExpiryTimer = null;
    isSendingVerification = false;
    isResendingVerification = false;
    isVerifyingCode = false;
    resendAvailableAt = null;
    resendCooldownSeconds = 0;
    maxResendReached = false;
    resendCooldownTimer = null;

    eoiLinkMap = {};          // BP-032: eoiId -> { paymentName, status }
    eoiLinksError = false;
    eoiPendingRecords = [];   // BP-041: payment requests with no EOI yet (MBP_EoiPaymentLinkController.PendingRow)
    // BP-057: one row action at a time. Every action button is disabled while one is in flight, so a
    // double click - or a click on a second row - can never send two messages or mint two links.
    isEoiActionBusy = false;
    // BP-058: the row being cancelled, or null. Holds only what the dialog prints.
    eoiCancelRow = null;
    _shouldFocusEoiCancel = false;
    /* BP-061: the one request an action is running on. isEoiActionBusy shuts the whole tab; this says
       WHICH pill carries the loader, so the broker sees exactly what they pressed working. */
    eoiActionBusyId = '';
    // BP-060: the payment record of a request just created, lifted once so the broker can see it.
    flashPaymentId = '';
    _eoiFlashTimer = null;
    eoiPendingError = false;
    _handledLaunchToken = '';
    _shouldFocusDrawer = false;
    _consoleRefreshTimer = null;

    @wire(getObjectInfo, { objectApiName: LEAD_OBJECT })
    handleLeadObjectInfo({ data, error }) {
        if (data) {
            this.leadObjectInfo = data;
            const recordTypeInfos = data.recordTypeInfos || {};
            const masterRecordTypeInfo = Object.values(recordTypeInfos).find((info) => info.master);
            this.leadObjectRecordTypeId = data.defaultRecordTypeId || masterRecordTypeInfo?.recordTypeId || '';
            this.leadUiPicklistsError = false;
        } else if (error) {
            this.leadUiPicklistsError = true;
            this.leadPicklistsLoaded = false;
        }
    }

    @wire(getPicklistValuesByRecordType, { objectApiName: LEAD_OBJECT, recordTypeId: '$leadObjectRecordTypeId' })
    handleLeadRecordTypePicklists({ data, error }) {
        if (data) {
            this.leadPicklistFieldValues = data.picklistFieldValues || {};
            this.leadPicklists = LEAD_PICKLIST_FIELDS.reduce((acc, [fieldName, propName]) => {
                acc[propName] = this.toUiApiOptions(this.getLeadPicklistMetadata(fieldName)?.values || []);
                return acc;
            }, {});
            this.leadPicklistsLoaded = true;
            this.leadUiPicklistsError = false;
            this.normalizeLeadFormPicklistValues();
        } else if (error) {
            this.leadUiPicklistsError = true;
            this.leadPicklistsLoaded = false;
        }
    }

    @wire(getRecord, {
        recordId: '$leadHydrateRecordId',
        fields: LEAD_FORM_REQUIRED_RECORD_FIELDS,
        optionalFields: LEAD_FORM_OPTIONAL_RECORD_FIELDS
    })
    handleLeadFormRecord({ data, error }) {
        if (!this.leadHydrateRecordId) return;

        if (data) {
            const recordId = data.id || this.leadHydrateRecordId;
            if (!this.isLeadFormDrawer || this.leadForm.Id !== recordId) {
                this.isLeadFormHydrating = false;
                return;
            }

            this.leadForm = this.leadRecordToForm(data, this.leadForm);
            this.seedLeadChecksFromForm();
            this.normalizeLeadFormPicklistValues();
            this.resetLeadFieldValidity();
            this.isLeadFormHydrating = false;
            this.leadHydrateRecordId = undefined;
            this.clearLeadFormMessage();
        } else if (error && this.isLeadFormHydrating) {
            this.isLeadFormHydrating = false;
            this.leadHydrateRecordId = undefined;
            const message = `Saved lead details could not be fully loaded. ${this.reduceError(error)}`;
            this.setLeadFormMessage(message, 'warning');
        }
    }

    connectedCallback() {
        if (this.eoiOnly) {
            this.activeTab = 'eoi';
        }
        if (!this.showOpportunities && this.activeTab === 'opportunities') {
            this.activeTab = 'performance';
        }
        this.bootstrap();
    }

    disconnectedCallback() {
        this.clearResendCooldownTimer();
        this.clearExpiryTimer();
        this.clearDeferredConsoleRefresh();
        this.clearEoiFlashTimer();
    }

    get isDirectForm() {
        return this.directLeadForm || this.directEoiForm;
    }

    get showStandardWorkspace() {
        return !this.isDirectForm;
    }

    get showBootLoadingState() {
        return this.isBootLoading && !this.isDirectForm;
    }

    get showBootErrorState() {
        return this.bootError && !this.isDirectForm;
    }

    get salesConsoleClass() {
        return this.isDirectForm ? 'sales-console sales-console--direct' : 'sales-console';
    }

    get salesConsoleAriaLabel() {
        if (this.directEoiForm) return 'New EOI form';
        return this.directLeadForm ? 'New lead form' : 'Sales workspace';
    }

    renderedCallback() {
        this.notifySalesTabsState();

        if (this.launchToken && this.launchToken !== this._handledLaunchToken) {
            if (this.launchIntent === 'new-lead') {
                this._handledLaunchToken = this.launchToken;
                this.openLeadForm();
            } else if (this.launchIntent === 'new-eoi' && !this.isBootLoading) {
                // Home EOI card fast path: land straight in the New EOI form.
                // handleOpenEoiForm guards on canCreateEoi, which needs the
                // async-loaded brokerType - so the one-shot token is only
                // consumed once bootstrap has resolved the role. Until then
                // the boot-completion render re-enters here.
                this._handledLaunchToken = this.launchToken;
                this.handleOpenEoiForm();
            }
        }

        if (this._shouldFocusDrawer) {
            const closeButton = this.template.querySelector('.sales-drawer-focus');
            if (closeButton) closeButton.focus();
            this._shouldFocusDrawer = false;
        }

        // BP-058: the confirmation takes focus when it opens, so Escape and Tab work at once
        if (this._shouldFocusEoiCancel) {
            const dialog = this.template.querySelector('.eoi-confirm');
            if (dialog) {
                dialog.focus();
                this._shouldFocusEoiCancel = false;
            }
        }
    }

    async bootstrap() {
        this.isBootLoading = true;
        this.bootError = false;
        try {
            await this.loadUser();
            if (!this.isEoiEnabled) {
                this.eoiRecords = [];
            }
            const loaders = this.eoiOnly || this.directEoiForm ? [] : [this.loadLeads(), this.loadOpportunities(), this.loadUnits()];
            if (this.isEoiEnabled) {
                loaders.push(this.loadEoiRecords());
            }
            await Promise.all(loaders);
        } catch (error) {
            this.bootError = true;
        } finally {
            this.isBootLoading = false;
        }
    }

    async loadUser() {
        const data = await getCurrentUserInfo();
        this.userInfo = data || {};
        this.accountId = data?.accountId || '';
        this.contactId = data?.contactId || '';
        this.brokerType = data?.brokerType || '';

        if (!this.accountId || !this.contactId || !this.brokerType) {
            try {
                const user = await getLeadUserDetails({ userId: USER_ID });
                const fallbackContact = user?.Contact || {};
                this.contactId = this.contactId || user?.ContactId || fallbackContact.Id || '';
                this.accountId = this.accountId || fallbackContact.AccountId || '';
                this.brokerType = this.brokerType || fallbackContact.Broker_Type__c || '';
                this.userInfo = {
                    ...this.userInfo,
                    contactId: this.contactId,
                    accountId: this.accountId,
                    brokerType: this.brokerType,
                    contactPhone: this.userInfo.contactPhone || fallbackContact.Phone || ''
                };
            } catch (error) {
                this.userInfo = {
                    ...this.userInfo,
                    contextWarning: this.reduceError(error)
                };
            }
        }
    }

    async loadLeads(silent = false) {
        if (!silent) this.isLeadsLoading = true;
        this.leadsError = false;
        try {
            // A custom date range wins; otherwise the period travels as explicit dates.
            const periodRange = resolveLeadsPeriodRange(this.leadPeriod);
            const leadGroups = (await getFilteredLeads({
                userId: USER_ID,
                filterType: this.leadPeriod,
                startDate: this.leadDateRangeActive ? this.leadStartDate : periodRange.startDate,
                endDate: this.leadDateRangeActive ? this.leadEndDate : periodRange.endDate
            })) || [];
            // A row is one customer, and children holds each of their leads. Only the row was
            // kept, so a customer's other leads had no way of being opened. Converted ones are
            // still dropped further down by activeLeadRecords, same as before.
            this.leadRecords = leadGroups.reduce((all, row) => {
                const group = Array.isArray(row.children) && row.children.length ? row.children : [row];
                return all.concat(group);
            }, []);
            this.reconcileLeadFilters();
        } catch (error) {
            this.leadsError = true;
            this.leadRecords = [];
        } finally {
            if (!silent) this.isLeadsLoading = false;
        }
    }

    async loadOpportunities(silent = false) {
        // BP-018 - single choke point for every caller: no tab, no fetch.
        if (!this.showOpportunities) {
            this.opportunities = [];
            this.opportunitiesError = false;
            this.isOpportunitiesLoading = false;
            return;
        }
        if (!silent) this.isOpportunitiesLoading = true;
        this.opportunitiesError = false;
        try {
            if (!this.accountId) {
                this.opportunities = [];
                this.reconcileOpportunityFilters();
                return;
            }
            this.opportunities = (await getOpportunitiesForAgency({
                accountId: this.accountId,
                startDate: this.opportunityDateRangeActive ? this.opportunityStartDate : null,
                endDate: this.opportunityDateRangeActive ? this.opportunityEndDate : null
            })) || [];
            this.reconcileOpportunityFilters();
        } catch (error) {
            this.opportunitiesError = true;
            this.opportunities = [];
        } finally {
            if (!silent) this.isOpportunitiesLoading = false;
        }
    }

    async loadEoiRecords(silent = false) {
        if (!this.isEoiEnabled) {
            this.eoiRecords = [];
            this.eoiPendingRecords = [];
            return;
        }
        if (!silent) this.isEoiLoading = true;
        this.eoiError = false;
        this.eoiPendingError = false;
        try {
            // BP-041: EOI rows and the pending payment requests load together; a pending-list failure
            // never blanks the EOI rows (fail soft, flagged separately).
            const [records, pending] = await Promise.all([
                getEOIRecords(),
                getBrokerPendingLinks().catch(() => {
                    this.eoiPendingError = true;
                    return [];
                })
            ]);
            this.eoiRecords = records || [];
            this.eoiPendingRecords = pending || [];
            await this.loadEoiPaymentLinks();
            this.reconcileEoiFilters();
        } catch (error) {
            this.eoiError = true;
            this.eoiRecords = [];
            this.eoiPendingRecords = [];
            this.eoiLinkMap = {};
        } finally {
            if (!silent) this.isEoiLoading = false;
        }
    }

    // BP-032: CP number + link status per EOI. On failure the map is empty, so rows show no
    // payment number and Void stays disabled until Refresh succeeds (fail closed).
    async loadEoiPaymentLinks() {
        const eoiIds = (this.eoiRecords || []).map((item) => item.Id).filter(Boolean);
        this.eoiLinksError = false;
        if (!eoiIds.length) {
            this.eoiLinkMap = {};
            return;
        }
        try {
            const links = (await getEoiPaymentLinks({ eoiIds })) || [];
            const map = {};
            links.forEach((link) => {
                // BP-059: the payment RECORD id travels too - the row actions act on it
                if (link?.eoiId) map[link.eoiId] = { paymentId: link.paymentId || '', paymentName: link.paymentName || '', status: link.status || '', dashboardStatus: link.dashboardStatus || '' };
            });
            this.eoiLinkMap = map;
        } catch (error) {
            this.eoiLinkMap = {};
            this.eoiLinksError = true;
        }
    }

    async loadUnits(silent = false) {
        if (!silent) this.isUnitsLoading = true;
        this.unitsError = false;
        try {
            this.unitRecords = (await getUnitRecords({
                objectName: 'Unit__c',
                filters: {},
                fields: UNIT_FIELDS
            })) || [];
        } catch (error) {
            this.unitsError = true;
            this.unitRecords = [];
        } finally {
            if (!silent) this.isUnitsLoading = false;
        }
    }

    @api
    async refreshActiveTab() {
        // BP-061: a refresh mid-action would re-read the list under the broker's feet
        if (this.isEoiActionBusy) return;
        if (this.activeTab === 'performance') {
            const perf = this.template.querySelector('c-mbpr_lead-performance');
            if (perf) await perf.refresh();
            return;
        }
        if (this.activeTab === 'leads') await this.loadLeads();
        if (this.activeTab === 'opportunities') await this.loadOpportunities();
        if (this.activeTab === 'eoi' && this.isEoiEnabled) await this.loadEoiRecords();
    }

    async refreshConsoleData(options = {}) {
        const {
            leads = true,
            opportunities = true,
            eoi = this.isEoiEnabled,
            units = false,
            documents = false,
            salesOrders = false,
            // Aurelix IT 29 Aug 2026 - fetch without showing the skeletons
            silent = false
        } = options;

        const loaders = [];
        if (leads) loaders.push(this.loadLeads(silent));
        if (opportunities) loaders.push(this.loadOpportunities(silent));
        if (eoi && this.isEoiEnabled) loaders.push(this.loadEoiRecords(silent));
        if (units) loaders.push(this.loadUnits(silent));

        await Promise.all(loaders);
        this.normalizeConsolePagination();

        if (!this.syncDrawerAfterConsoleRefresh()) {
            return;
        }

        const detailLoaders = [];
        if (documents && this.selectedLeadId) detailLoaders.push(this.loadSelectedLeadDocuments());
        if (salesOrders && this.selectedOpportunityId) detailLoaders.push(this.loadSalesOrders(this.selectedOpportunityId));
        await Promise.all(detailLoaders);
    }

    @api
    async refreshWorkspaceData() {
        await this.refreshConsoleData({
            leads: true,
            opportunities: true,
            eoi: this.isEoiEnabled,
            units: true,
            documents: Boolean(this.selectedLeadId),
            salesOrders: Boolean(this.selectedOpportunityId)
        });
    }

    normalizeConsolePagination() {
        this.leadPage = Math.min(Math.max(1, this.leadPage), this.pageCount(this.filteredLeadRows.length));
        this.opportunityPage = Math.min(Math.max(1, this.opportunityPage), this.pageCount(this.filteredOpportunityRows.length));
        this.eoiPage = Math.min(Math.max(1, this.eoiPage), this.pageCount(this.filteredEoiRows.length));
    }

    syncDrawerAfterConsoleRefresh() {
        if (this.drawerMode === 'lead-detail' && !this.selectedLead) {
            this.closeDrawer();
            return false;
        }
        if (this.drawerMode === 'opportunity-detail' && !this.selectedOpportunity) {
            this.closeDrawer();
            return false;
        }
        if (this.drawerMode === 'eoi-detail' && !this.selectedEoi) {
            this.closeDrawer();
            return false;
        }
        return true;
    }

    notifyConsoleMutation(scope = 'sales') {
        this.dispatchEvent(
            new CustomEvent('salesdatachange', {
                detail: { scope },
                bubbles: true,
                composed: true
            })
        );
    }

    scheduleDeferredConsoleRefresh(options = {}, scope = 'sales') {
        this.clearDeferredConsoleRefresh();
        this._consoleRefreshTimer = window.setTimeout(async () => {
            this._consoleRefreshTimer = null;
            try {
                // Aurelix IT 29 Aug 2026 - silent, so one action is one load
                await this.refreshConsoleData({ ...options, silent: true });
                this.notifyConsoleMutation(scope);
            } catch {
                // Individual loaders already own visible error states.
            }
        }, 1500);
    }

    clearDeferredConsoleRefresh() {
        if (this._consoleRefreshTimer) {
            clearTimeout(this._consoleRefreshTimer);
            this._consoleRefreshTimer = null;
        }
    }

    get canCreateLead() {
        return this.brokerType === 'Agent' || this.brokerType === 'Owner';
    }

    get isEoiEnabled() {
        return String(MBP_EnableEoi || '').toLowerCase() === 'true';
    }

    /* MBP_EnableNewEoi shows or hides only the New EOI buttons; the EOI list
       stays under MBP_EnableEoi. */
    get isNewEoiEnabled() {
        return String(MBP_EnableNewEoi || '').toLowerCase() === 'true';
    }

    get canCreateEoi() {
        return this.canCreateLead && this.isEoiEnabled && this.isNewEoiEnabled;
    }

    get showOpportunities() {
        return !this.fastTrack;
    }

    get salesTabs() {
        const tabs = [
            { key: 'performance', label: 'Performance' },
            { key: 'leads', label: 'Manage Leads', count: this.leadRows.length }
        ];
        if (this.showOpportunities) {
            tabs.push({ key: 'opportunities', label: 'Manage Opportunities', count: this.opportunityRows.length });
        }

        return tabs.map((tab) => ({
            ...tab,
            hasCount: tab.count !== undefined,
            className: tab.key === this.activeTab ? 'sales-tab sales-tab--active' : 'sales-tab',
            ariaSelected: tab.key === this.activeTab
        }));
    }

    get showSalesTabs() {
        return !this.eoiOnly;
    }

    get showConsoleBar() {
        return !this.eoiOnly;
    }

    // BP-022 - Generate Offer belongs to leads; Manage Opportunities does not offer it
    get showGuidedOfferAction() {
        return !this.eoiOnly && !this.isOpportunitiesTab;
    }

    get isPerformanceTab() {
        return this.activeTab === 'performance';
    }

    get isLeadsTab() {
        return this.activeTab === 'leads';
    }

    get isOpportunitiesTab() {
        return this.showOpportunities && this.activeTab === 'opportunities';
    }

    get isEoiTab() {
        return this.isEoiEnabled && this.activeTab === 'eoi';
    }

    handleTab(event) {
        this.switchTab(event.currentTarget.dataset.tab);
    }

    switchTab(tab) {
        if (!tab || tab === this.activeTab) return;
        if (tab === 'opportunities' && !this.showOpportunities) return;
        this.activeTab = tab;
        this.closeSalesFilterPanels();
    }

    /* On touch the workspace modal hosts the tab pills in its header and drives
       them through this API; the state event keeps them in sync with the
       counts and active tab. Desktop keeps this component's console bar. */
    @api setActiveTab(key) {
        this.switchTab(key);
    }

    /* At 1200 and up the modal header hosts the tab pills, Generate Offer,
       Refresh and the dashboard's agent picker and Filters chip. These APIs
       let the host drive both without duplicating logic. */
    @api togglePerformanceFilters(anchor) {
        const perf = this.template.querySelector('c-mbpr_lead-performance');
        if (perf) perf.toggleFilters(anchor);
    }

    @api setPerformanceAgent(value) {
        const perf = this.template.querySelector('c-mbpr_lead-performance');
        if (perf) perf.setAgentScope(value);
    }

    @api openGuidedOffer() {
        this.handleOpenGuidedOffer();
    }

    handlePerfChromeState(event) {
        this.dispatchEvent(new CustomEvent('salesperfchrome', { detail: event.detail }));
    }

    _lastTabsSignature = '';

    notifySalesTabsState() {
        const tabs = this.showSalesTabs
            ? this.salesTabs.map((tab) => ({
                  key: tab.key,
                  label: tab.label,
                  count: tab.count,
                  hasCount: tab.hasCount,
                  active: tab.ariaSelected
              }))
            : [];
        const signature = JSON.stringify(tabs);
        if (signature === this._lastTabsSignature) return;
        this._lastTabsSignature = signature;
        this.dispatchEvent(new CustomEvent('salestabsstate', { detail: { tabs } }));
    }

    get showTouchNewLead() {
        return this.canCreateLead && this.isLeadsTab;
    }

    get showTouchNewEoi() {
        return this.canCreateEoi && this.isEoiTab;
    }

    get showTouchActionBar() {
        /* showTouchNewEoi is not part of this condition: the New EOI buttons
           are hidden, so the EOI tab alone must not raise an empty action bar
           on touch. The getter is kept so they can be restored. */
        return (
            !this.isPerformanceTab &&
            (this.showTouchNewLead || this.showGuidedOfferAction)
        );
    }

    /* BP-023 - converted leads live in Manage Opportunities now; the Leads tab,
       its count, filters, search and export all read this list. The raw
       leadRecords stay untouched for the other consumers of the same Apex. */
    get activeLeadRecords() {
        return this.leadRecords.filter((lead) => !isConvertedLead(lead));
    }

    get leadRows() {
        return this.activeLeadRecords.map((lead, index) => {
            const name = this.getLeadName(lead);
            const project = lead.Project || lead.ProjectInterest || '';
            const status = lead.Status || 'New';
            const isMasked = this.isMaskedValue(lead.Email) || this.isMaskedValue(lead.Mobile);
            return {
                ...lead,
                id: lead.Id,
                key: lead.Id || `lead-${index}`,
                name,
                initials: this.getInitials(name),
                projectLabel: project || 'Not specified',
                unitTypeLabel: lead.UnitType || 'Not specified',
                statusLabel: leadStatusLabel(status),
                statusTone: this.getStatusTone(status),
                contactLabel: [lead.Email, lead.Mobile].filter(Boolean).join(' / ') || 'Restricted',
                emailLabel: lead.Email || 'Restricted',
                mobileLabel: lead.Mobile || 'Restricted',
                agentLabel: lead.AgentName || 'Not assigned',
                createdLabel: this.formatShortDate(lead.CreatedDate),
                childCount: Array.isArray(lead.children) ? lead.children.length : 0,
                isMasked,
                canManage: this.canCreateLead && !isMasked,
                /* Retired leads are not offerable (business, 2026-08-13). */
                canGenerateOffer: !this.isRetiredStatus(status),
                rowStyle: `--reveal-index: ${index}`
            };
        });
    }

    get filteredLeadRows() {
        const query = this.leadSearch.trim().toLowerCase();
        return this.leadRows.filter((lead) => {
            const matchesStatus = this.leadStatusFilter === 'all' || lead.statusLabel === this.leadStatusFilter;
            const matchesProject = this.leadProjectFilter === 'all' || lead.projectLabel === this.leadProjectFilter;
            const matchesUnitType = this.leadUnitTypeFilter === 'all' || lead.unitTypeLabel === this.leadUnitTypeFilter;
            const matchesAgent = this.leadAgentFilter === 'all' || lead.agentLabel === this.leadAgentFilter;
            const haystack = [
                lead.name,
                lead.LeadNumber,
                lead.projectLabel,
                lead.unitTypeLabel,
                lead.statusLabel,
                lead.agentLabel,
                lead.contactLabel
            ].join(' ').toLowerCase();
            return matchesStatus && matchesProject && matchesUnitType && matchesAgent && (!query || haystack.includes(query));
        });
    }

    get paginatedLeadRows() {
        return this.paginate(this.filteredLeadRows, this.leadPage);
    }

    get leadStatusOptions() {
        return this.buildSelectOptions(this.leadRows, 'statusLabel', 'All statuses');
    }

    get leadPeriodOptions() {
        return LEADS_PERIODS;
    }

    get leadFilterButtonClass() {
        return this.hasLeadActiveFilters ? 'sales-filter-button sales-filter-button--active' : 'sales-filter-button';
    }

    get leadFilterPanelClass() {
        return this.isLeadFilterPanelOpen ? 'sales-filter sales-filter--open' : 'sales-filter';
    }

    get leadDateRangeActive() {
        return Boolean(this.leadStartDate && this.leadEndDate);
    }

    get isLeadDateRangeInvalid() {
        return Boolean(this.pendingLeadStartDate && this.pendingLeadEndDate && this.pendingLeadStartDate > this.pendingLeadEndDate);
    }

    get leadDateRangeHint() {
        if (this.isLeadDateRangeInvalid) {
            return 'The start date must be on or before the end date.';
        }
        if (Boolean(this.pendingLeadStartDate) !== Boolean(this.pendingLeadEndDate)) {
            return 'Select both dates to filter by a date range.';
        }
        return '';
    }

    get hasLeadActiveFilters() {
        return this.leadActiveFilterCount > 0;
    }

    get leadActiveFilterCount() {
        return [
            this.leadPeriod !== LEADS_DEFAULT_PERIOD,
            this.leadDateRangeActive,
            this.leadStatusFilter !== 'all',
            this.leadProjectFilter !== 'all',
            this.leadUnitTypeFilter !== 'all',
            this.leadAgentFilter !== 'all'
        ].filter(Boolean).length;
    }

    get leadAppliedFilterChips() {
        return [
            this.leadPeriod !== LEADS_DEFAULT_PERIOD ? { key: 'lead-period', label: `Period: ${this.labelForValue(this.leadPeriodOptions, this.leadPeriod)}` } : null,
            this.leadDateRangeActive ? { key: 'lead-dates', label: `Dates: ${this.leadStartDate} to ${this.leadEndDate}` } : null,
            this.leadStatusFilter !== 'all' ? { key: 'lead-status', label: `Status: ${this.leadStatusFilter}` } : null,
            this.leadProjectFilter !== 'all' ? { key: 'lead-project', label: `Project: ${this.leadProjectFilter}` } : null,
            this.leadUnitTypeFilter !== 'all' ? { key: 'lead-unit-type', label: `Unit type: ${this.leadUnitTypeFilter}` } : null,
            this.leadAgentFilter !== 'all' ? { key: 'lead-agent', label: `Owner: ${this.leadAgentFilter}` } : null
        ].filter(Boolean);
    }

    get leadPeriodSelectOptions() {
        return this.withSelectedOption(this.leadPeriodOptions, this.pendingLeadPeriod);
    }

    get leadStatusFilterOptions() {
        return this.buildSalesFilterOptions(this.getLeadRowsForFilter('status'), 'statusLabel', 'All statuses', this.pendingLeadStatusFilter);
    }

    get leadProjectFilterOptions() {
        return this.buildSalesFilterOptions(this.getLeadRowsForFilter('project'), 'projectLabel', 'All projects', this.pendingLeadProjectFilter);
    }

    get leadUnitTypeFilterOptions() {
        return this.buildSalesFilterOptions(this.getLeadRowsForFilter('unitType'), 'unitTypeLabel', 'All unit types', this.pendingLeadUnitTypeFilter);
    }

    get leadAgentFilterOptions() {
        return this.buildSalesFilterOptions(this.getLeadRowsForFilter('agent'), 'agentLabel', 'All owners', this.pendingLeadAgentFilter);
    }

    get leadPageLabel() {
        return this.pageLabel(this.filteredLeadRows.length, this.leadPage);
    }

    get isFirstLeadPage() {
        return this.leadPage <= 1;
    }

    get isLastLeadPage() {
        return this.leadPage >= this.pageCount(this.filteredLeadRows.length);
    }

    get hasFilteredLeads() {
        return this.filteredLeadRows.length > 0;
    }

    handleLeadSearch(event) {
        this.leadSearch = event.target.value || '';
        this.leadPage = 1;
    }

    handleLeadStatusFilter(event) {
        this.leadStatusFilter = event.target.value || 'all';
        this.leadPage = 1;
    }

    handleLeadPeriod(event) {
        this.leadPeriod = event.target.value || LEADS_DEFAULT_PERIOD;
        this.leadPage = 1;
        this.loadLeads();
    }

    toggleLeadFilterPanel() {
        if (this.isLeadFilterPanelOpen) {
            this.isLeadFilterPanelOpen = false;
            return;
        }
        this.closeSalesFilterPanels();
        this.syncPendingLeadFilters();
        this.isLeadFilterPanelOpen = true;
    }

    closeLeadFilterPanel() {
        this.isLeadFilterPanelOpen = false;
    }

    handlePendingLeadFilterChange(event) {
        const field = event.currentTarget.dataset.filter;
        if (field === 'startDate' || field === 'endDate') {
            const dateValue = event.target.value || '';
            if (field === 'startDate') this.pendingLeadStartDate = dateValue;
            if (field === 'endDate') this.pendingLeadEndDate = dateValue;
            return;
        }
        const value = event.target.value || 'all';
        if (field === 'period') {
            this.pendingLeadPeriod = value || LEADS_DEFAULT_PERIOD;
            if (this.pendingLeadPeriod !== this.leadPeriod) {
                this.pendingLeadStatusFilter = 'all';
                this.pendingLeadProjectFilter = 'all';
                this.pendingLeadUnitTypeFilter = 'all';
                this.pendingLeadAgentFilter = 'all';
            }
        }
        if (field === 'status') this.pendingLeadStatusFilter = value;
        if (field === 'project') this.pendingLeadProjectFilter = value;
        if (field === 'unitType') this.pendingLeadUnitTypeFilter = value;
        if (field === 'agent') this.pendingLeadAgentFilter = value;
        this.reconcilePendingLeadFilters();
    }

    async applyLeadFilters() {
        if (this.isLeadDateRangeInvalid) return;
        const nextPeriod = this.pendingLeadPeriod || LEADS_DEFAULT_PERIOD;
        const periodChanged = nextPeriod !== this.leadPeriod;
        const nextStartDate = this.pendingLeadStartDate || '';
        const nextEndDate = this.pendingLeadEndDate || '';
        const datesChanged = nextStartDate !== this.leadStartDate || nextEndDate !== this.leadEndDate;
        this.leadPeriod = nextPeriod;
        this.leadStartDate = nextStartDate;
        this.leadEndDate = nextEndDate;
        this.leadStatusFilter = this.pendingLeadStatusFilter || 'all';
        this.leadProjectFilter = this.pendingLeadProjectFilter || 'all';
        this.leadUnitTypeFilter = this.pendingLeadUnitTypeFilter || 'all';
        this.leadAgentFilter = this.pendingLeadAgentFilter || 'all';
        this.leadPage = 1;
        this.isLeadFilterPanelOpen = false;
        if (periodChanged || datesChanged) {
            await this.loadLeads();
        } else {
            this.reconcileLeadFilters();
        }
    }

    async clearLeadFilters() {
        const needsReload = this.leadPeriod !== LEADS_DEFAULT_PERIOD || this.leadDateRangeActive;
        this.leadPeriod = LEADS_DEFAULT_PERIOD;
        this.leadStartDate = '';
        this.leadEndDate = '';
        this.leadStatusFilter = 'all';
        this.leadProjectFilter = 'all';
        this.leadUnitTypeFilter = 'all';
        this.leadAgentFilter = 'all';
        this.syncPendingLeadFilters();
        this.leadPage = 1;
        if (needsReload) {
            await this.loadLeads();
        }
    }

    handlePreviousLeads() {
        this.leadPage = Math.max(1, this.leadPage - 1);
    }

    handleNextLeads() {
        this.leadPage = Math.min(this.pageCount(this.filteredLeadRows.length), this.leadPage + 1);
    }

    async handleOpenLead(event) {
        const id = event.currentTarget.dataset.id;
        if (!id) return;
        await this.openLeadDrawer(id);
    }

    async openLeadDrawer(id) {
        this.selectedLeadId = id;
        this.drawerMode = 'lead-detail';
        this._shouldFocusDrawer = true;
        await this.loadSelectedLeadDocuments();
    }

    openLeadForm(lead = null) {
        const leadId = lead?.id || lead?.Id || '';
        this.activeTab = 'leads';
        this.leadForm = lead ? this.leadToForm(lead) : emptyLeadForm();
        this.seedLeadChecksFromForm();
        this.leadFiles = {};
        this.isLeadFormHydrating = false;
        this.leadHydrateRecordId = undefined;
        this.clearLeadFormMessage();
        if (leadId) {
            this.selectedLeadId = leadId;
        } else {
            this.selectedLeadId = '';
            this.selectedLeadDocuments = [];
        }
        this.drawerMode = 'lead-form';
        this._shouldFocusDrawer = true;
        this.ensureLeadPicklists();
        if (leadId) {
            this.loadSelectedLeadDocuments();
            this.hydrateLeadFormRecord(leadId);
        }
    }

    handleOpenLeadForm() {
        if (!this.canCreateLead) return;
        this.openLeadForm();
    }

    handleEditSelectedLead() {
        if (this.selectedLead?.canManage) {
            this.openLeadForm(this.selectedLead);
        }
    }

    handleOpenGuidedOffer(event) {
        const leadId = event?.currentTarget?.dataset?.leadId || this.selectedLeadId || '';
        this.dispatchEvent(
            new CustomEvent('openofferworkspace', {
                detail: { leadId },
                bubbles: true,
                composed: true
            })
        );
    }

    ensureLeadPicklists() {
        if (this.leadPicklistsLoaded) {
            this.normalizeLeadFormPicklistValues();
            return;
        }

        if (this.leadUiPicklistsError) {
            const message = 'Lead picklist values could not be loaded for your active Lead record type. Refresh the page and try again.';
            this.setLeadFormMessage(message, 'error');
        }
    }

    hydrateLeadFormRecord(leadId) {
        this.isLeadFormHydrating = true;
        this.setLeadFormMessage('Loading saved lead details...', 'info');
        this.leadHydrateRecordId = undefined;
        Promise.resolve().then(() => {
            if (this.isLeadFormDrawer && this.leadForm.Id === leadId) {
                this.leadHydrateRecordId = leadId;
            }
        });
    }

    leadToForm(lead) {
        const email = this.firstLeadValue(lead.Email, lead.email);
        const mobile = this.firstLeadValue(lead.Mobile, lead.MobilePhone, lead.mobile);
        return {
            ...emptyLeadForm(),
            Id: this.firstLeadValue(lead.id, lead.Id),
            Type: this.inferLeadTypeFromValues(this.firstLeadValue(lead.LeadType, lead.Type), lead.UnifiedNumber, lead.UnifiedNumber__c, lead.uaevatregisternumber, lead.UAEVATRegisterNumber__c, lead.vatCertificateType, lead.TradeNumber, lead.Trade_License_Number__c),
            Salutation: this.firstLeadValue(lead.Title, lead.Salutation),
            FirstName: this.firstLeadValue(lead.FirstName),
            LastName: this.firstLeadValue(lead.LastName),
            Email: this.isMaskedValue(email) ? '' : email,
            MobilePhone: this.isMaskedValue(mobile) ? '' : mobile,
            UAEResidentStatus__c: this.firstLeadValue(lead.UAEResidentStatus, lead.UAEResidentStatus__c),
            CountryOfResidence__c: this.firstLeadValue(lead.CountryOfResidence, lead.CountryOfResidence__c),
            Nationality__c: this.firstLeadValue(lead.Nationality, lead.Nationality__c),
            EIDNumber__c: this.firstLeadValue(lead.EIDNumber, lead.EIDNumber__c),
            EmiratesIDExpiryDate__c: this.toDateInput(this.firstLeadValue(lead.EmiratesIDExpiryDate, lead.EmiratesIDExpiryDate__c)),
            PassportNumber__c: this.firstLeadValue(lead.PassportNumber, lead.PassportNumber__c),
            PassportIssueDate__c: this.toDateInput(this.firstLeadValue(lead.PassportIssueDate, lead.PassportIssueDate__c)),
            PassportExpiryDate__c: this.toDateInput(this.firstLeadValue(lead.PassportExpiryDate, lead.PassportExpiryDate__c)),
            Name: this.firstLeadValue(lead.Company, lead.Name),
            UnifiedNumber__c: this.firstLeadValue(lead.UnifiedNumber, lead.UnifiedNumber__c),
            UAEVATRegisterNumber__c: this.firstLeadValue(lead.uaevatregisternumber, lead.UAEVATRegisterNumber__c),
            vatCertificateType: this.firstLeadValue(lead.vatCertificateType, lead.VAT_Certificate_Type__c),
            SalesOrigin__c: this.firstLeadValue(lead.SalesOrigin, lead.SalesOrigin__c),
            LeadOrigin__c: this.firstLeadValue(lead.LeadOrigin, lead.LeadOrigin__c),
            SalesType__c: this.firstLeadValue(lead.SalesType, lead.SalesType__c),
            ProjectInterest__c: this.firstLeadValue(lead.ProjectInterest, lead.ProjectInterest__c, lead.Project, lead.Project__c),
            UnitType__c: this.firstLeadValue(lead.UnitType, lead.UnitType__c),
            NumberOfBedrooms__c: this.firstLeadValue(lead.NumberOfBedrooms, lead.NumberOfBedrooms__c),
            CustomerBudget__c: this.firstLeadValue(lead.CustomerBudget, lead.CustomerBudget__c),
            PurposeOfUse__c: this.firstLeadValue(lead.PurposeOfUse, lead.PurposeofUse__c, lead.PurposeOfUse__c),
            PropertyReadiness__c: this.firstLeadValue(lead.PropertyReadiness, lead.PropertyReadiness__c),
            Finance__c: this.firstLeadValue(lead.Finance, lead.Finance__c),
            PropertyUsage__c: this.firstLeadValue(lead.PropertyUsage, lead.PropertyUsage__c),
            BuyRent__c: this.firstLeadValue(lead.BuyRent, lead.BuyRent__c),
            Description: this.firstLeadValue(lead.Description)
        };
    }

    leadRecordToForm(record, fallbackForm = emptyLeadForm()) {
        const nextForm = {
            ...fallbackForm,
            Id: record.id || fallbackForm.Id || '',
            Salutation: this.getLeadRecordValue(record, 'Salutation', fallbackForm.Salutation),
            FirstName: this.getLeadRecordValue(record, 'FirstName', fallbackForm.FirstName),
            LastName: this.getLeadRecordValue(record, 'LastName', fallbackForm.LastName),
            Email: this.getLeadRecordValue(record, 'Email', fallbackForm.Email),
            MobilePhone: this.getLeadRecordValue(record, 'MobilePhone', fallbackForm.MobilePhone),
            UAEResidentStatus__c: this.getLeadRecordValue(record, 'UAEResidentStatus__c', fallbackForm.UAEResidentStatus__c),
            CountryOfResidence__c: this.getLeadRecordValue(record, 'CountryOfResidence__c', fallbackForm.CountryOfResidence__c),
            Nationality__c: this.getLeadRecordValue(record, 'Nationality__c', fallbackForm.Nationality__c),
            EIDNumber__c: this.getLeadRecordValue(record, 'EIDNumber__c', fallbackForm.EIDNumber__c),
            EmiratesIDExpiryDate__c: this.toDateInput(this.getLeadRecordValue(record, 'EmiratesIDExpiryDate__c', fallbackForm.EmiratesIDExpiryDate__c)),
            PassportNumber__c: this.getLeadRecordValue(record, 'PassportNumber__c', fallbackForm.PassportNumber__c),
            PassportIssueDate__c: this.toDateInput(this.getLeadRecordValue(record, 'PassportIssueDate__c', fallbackForm.PassportIssueDate__c)),
            PassportExpiryDate__c: this.toDateInput(this.getLeadRecordValue(record, 'PassportExpiryDate__c', fallbackForm.PassportExpiryDate__c)),
            Name: this.getLeadRecordValue(record, 'Company', fallbackForm.Name),
            UnifiedNumber__c: this.getLeadRecordValue(record, 'UnifiedNumber__c', fallbackForm.UnifiedNumber__c),
            UAEVATRegisterNumber__c: this.getLeadRecordValue(record, 'UAEVATRegisterNumber__c', fallbackForm.UAEVATRegisterNumber__c),
            vatCertificateType: this.getLeadRecordValue(record, 'VAT_Certificate_Type__c', fallbackForm.vatCertificateType),
            SalesOrigin__c: this.getLeadRecordValue(record, 'SalesOrigin__c', fallbackForm.SalesOrigin__c),
            LeadOrigin__c: this.getLeadRecordValue(record, 'LeadOrigin__c', fallbackForm.LeadOrigin__c),
            SalesType__c: this.getLeadRecordValue(record, 'SalesType__c', fallbackForm.SalesType__c),
            ProjectInterest__c: this.getLeadRecordValue(record, 'ProjectInterest__c', fallbackForm.ProjectInterest__c),
            UnitType__c: this.getLeadRecordValue(record, 'UnitType__c', fallbackForm.UnitType__c),
            NumberOfBedrooms__c: this.getLeadRecordValue(record, 'NumberOfBedrooms__c', fallbackForm.NumberOfBedrooms__c),
            CustomerBudget__c: this.getLeadRecordValue(record, 'CustomerBudget__c', fallbackForm.CustomerBudget__c),
            PurposeOfUse__c: this.getLeadRecordValue(record, 'PurposeofUse__c', fallbackForm.PurposeOfUse__c),
            PropertyReadiness__c: this.getLeadRecordValue(record, 'PropertyReadiness__c', fallbackForm.PropertyReadiness__c),
            Finance__c: this.getLeadRecordValue(record, 'Finance__c', fallbackForm.Finance__c),
            PropertyUsage__c: this.getLeadRecordValue(record, 'PropertyUsage__c', fallbackForm.PropertyUsage__c),
            BuyRent__c: this.getLeadRecordValue(record, 'BuyRent__c', fallbackForm.BuyRent__c),
            Description: this.getLeadRecordValue(record, 'Description', fallbackForm.Description)
        };
        nextForm.Type = this.inferLeadTypeFromValues(
            fallbackForm.Type,
            nextForm.UnifiedNumber__c,
            nextForm.UAEVATRegisterNumber__c,
            nextForm.vatCertificateType,
            this.getLeadRecordValue(record, 'Trade_License_Number__c', ''),
            this.isLeadOrganizationRecordType(record) ? 'Organization' : ''
        );
        return nextForm;
    }

    handleLeadFormChange(event) {
        if (this.isLeadFormHydrating) return;
        const field = event.target.dataset.field;
        if (!field) return;
        if (field === 'Email' && (event.target.value || '').trim() !== this.leadEmailCheck.value) {
            this.leadEmailCheck = { value: '', status: '', message: '' };
        }
        if (field === 'MobilePhone' && (event.target.value || '').trim() !== this.leadMobileCheck.value) {
            this.leadMobileCheck = { value: '', status: '', message: '' };
        }
        const nextForm = { ...this.leadForm, [field]: event.target.value || '' };
        if (field === 'ProjectInterest__c') {
            this.clearInvalidLeadDependentValue(nextForm, 'UnitType__c', 'unitTypeOptions');
            this.clearInvalidLeadDependentValue(nextForm, 'NumberOfBedrooms__c', 'bedroomOptions');
        }
        if (field === 'UAEResidentStatus__c') {
            if (this.isResidentStatus(nextForm.UAEResidentStatus__c)) {
                nextForm.PassportNumber__c = '';
                nextForm.PassportIssueDate__c = '';
                nextForm.PassportExpiryDate__c = '';
            } else if (this.isNonResidentStatus(nextForm.UAEResidentStatus__c)) {
                nextForm.EIDNumber__c = '';
                nextForm.EmiratesIDExpiryDate__c = '';
            }
        }
        this.leadForm = nextForm;
        this.pruneLeadFilesForForm(nextForm);
        event.target.setCustomValidity?.('');
        this.clearLeadFormMessage();
    }

    handleLeadType(event) {
        if (this.isLeadFormHydrating) return;
        const nextForm = { ...this.leadForm, Type: event.currentTarget.dataset.type || 'Individual' };
        if (nextForm.Type !== 'Organization') {
            nextForm.Name = '';
            nextForm.UnifiedNumber__c = '';
            nextForm.UAEVATRegisterNumber__c = '';
            nextForm.vatCertificateType = '';
        } else {
            // BP-024 - Individual-only identity documents are reset on the way to Organization
            LEAD_IDENTITY_DOCUMENT_FIELDS.forEach((field) => {
                nextForm[field] = '';
            });
        }
        this.leadForm = nextForm;
        this.pruneLeadFilesForForm(nextForm);
        this.resetLeadFieldValidity();
        this.clearLeadFormMessage();
    }

    handleLeadFile(event) {
        const slotKey = event.target.dataset.document;
        const files = Array.from(event.target.files || []);
        if (!slotKey || !files.length) return;
        // BP-015 - a slot that already holds a file is locked until that file is deleted
        if (this.isLeadSlotLocked(slotKey)) {
            event.target.value = '';
            return;
        }
        /* A side slot holds exactly one file - its input is not `multiple`,
           but clamp anyway so the name shown can never disagree with what
           actually uploads. */
        const isSideSlot = slotKey.includes(DOCUMENT_SIDE_SEPARATOR);
        const selected = isSideSlot ? files.slice(0, 1) : files;
        this.leadFiles = {
            ...this.leadFiles,
            [slotKey]: {
                documentType: documentTypeFromSlotKey(slotKey),
                files: selected,
                fileName: selected.length === 1 ? selected[0].name : `${selected.length} files selected`
            }
        };
        this.clearLeadFormMessage();
    }

    async handleSaveLead() {
        if (this.isLeadFormHydrating) {
            this.setLeadFormMessage('Saved lead details are still loading. Try again in a moment.', 'info');
            return;
        }

        this.clearLeadFormMessage();

        if (!this.contactId || !this.accountId) {
            await this.loadUser();
        }

        if (!this.contactId || !this.accountId) {
            const message = 'Your broker contact or agency account was not returned by the server. Refresh the portal or ask an admin to check the broker user Contact and Account mapping.';
            this.setLeadFormMessage(message, 'error');
            return;
        }

        if (!this.validateLeadFormFields()) {
            return;
        }

        const wasEditingLead = this.isLeadFormEditMode;
        this.isSavingLead = true;
        this.setLeadFormMessage('Validating contact details...', 'info');
        try {
            await this.validateLeadContact();
            this.setLeadFormMessage('Saving lead...', 'info');
            const savedLead = await createOrUpdateLead({
                payload: this.buildLeadPayload(),
                contactId: this.contactId,
                accountId: this.accountId
            });

            let uploadErrorMessage = '';
            try {
                await this.uploadLeadFiles(savedLead?.Id);
            } catch (uploadError) {
                uploadErrorMessage = this.reduceError(uploadError);
            }

            if (savedLead?.Id) {
                this.leadForm = { ...this.leadForm, Id: savedLead.Id };
                if (wasEditingLead) {
                    this.selectedLeadId = savedLead.Id;
                }
            }

            await this.refreshConsoleData({
                documents: wasEditingLead,
                salesOrders: Boolean(this.selectedOpportunityId)
            });
            this.notifyConsoleMutation('lead');
            this.scheduleDeferredConsoleRefresh({
                documents: wasEditingLead,
                salesOrders: Boolean(this.selectedOpportunityId)
            }, 'lead');

            if (uploadErrorMessage) {
                const message = `Lead saved, but one or more documents did not upload: ${uploadErrorMessage}`;
                this.setLeadFormMessage(message, 'warning');
                return;
            }

            if (wasEditingLead) {
                // BP-015 - an update closes the form the same way a new lead does
                this.showToast('Lead updated', 'Your changes have been saved.', 'success');
                this.closeDrawer();
            } else {
                // BP-011 - a new lead closes the form once saved; the toast carries
                // the confirmation because the footer message goes with the drawer.
                this.showToast('Lead created', 'The lead has been added to your list.', 'success');
                this.closeDrawer();
            }
        } catch (error) {
            const message = this.reduceError(error);
            this.setLeadFormMessage(message, 'error');
        } finally {
            this.isSavingLead = false;
        }
    }

    async validateLeadContact() {
        await validateEmail({ email: this.leadForm.Email.trim() });
        const isPhoneValid = await validatePhone({ phone: this.normalizeLeadMobileForSave(this.leadForm.MobilePhone) });
        if (!isPhoneValid) {
            throw new Error('Mobile number failed validation. Enter a valid mobile number with country code.');
        }
    }

    validateLeadFormFields() {
        this.resetLeadFieldValidity();

        const missingFields = this.getMissingLeadFields();
        missingFields.forEach(({ field, label }) => {
            this.setLeadFieldValidity(field, `${label} is required.`);
        });

        const formatMessages = [];
        const emailInput = this.template.querySelector('[data-field="Email"]');
        if (emailInput && !emailInput.checkValidity()) {
            formatMessages.push('Enter a valid email address.');
        }

        const normalizedMobile = this.normalizeLeadMobileForSave(this.leadForm.MobilePhone);
        if (this.leadForm.MobilePhone && !LEAD_PHONE_PATTERN.test(normalizedMobile)) {
            this.setLeadFieldValidity('MobilePhone', 'Enter a valid international mobile number, for example +971581234567.');
            formatMessages.push('Enter a valid international mobile number, for example +971581234567.');
        }

        if (this.isResidentLead && this.leadForm.EmiratesIDExpiryDate__c && !this.isFutureDate(this.leadForm.EmiratesIDExpiryDate__c)) {
            this.setLeadFieldValidity('EmiratesIDExpiryDate__c', 'Emirates ID expiry date must be in the future.');
            formatMessages.push('Emirates ID expiry date must be in the future.');
        }

        if (this.isResidentLead && this.leadForm.EIDNumber__c && !EMIRATES_ID_PATTERN.test(this.leadForm.EIDNumber__c)) {
            this.setLeadFieldValidity('EIDNumber__c', 'Invalid Emirates ID. Format should be: 784-1234-1234567-1.');
            formatMessages.push('Invalid Emirates ID. Format should be: 784-1234-1234567-1.');
        }

        if (this.isNonResidentLead && this.leadForm.PassportIssueDate__c && this.isFutureDate(this.leadForm.PassportIssueDate__c)) {
            this.setLeadFieldValidity('PassportIssueDate__c', 'Passport issue date cannot be in the future.');
            formatMessages.push('Passport issue date cannot be in the future.');
        }

        if (this.isNonResidentLead && this.leadForm.PassportExpiryDate__c && !this.isFutureDate(this.leadForm.PassportExpiryDate__c)) {
            this.setLeadFieldValidity('PassportExpiryDate__c', 'Passport expiry date must be in the future.');
            formatMessages.push('Passport expiry date must be in the future.');
        }

        const picklistMessages = this.getInvalidLeadPicklistMessages();
        const documentMessages = this.getLeadDocumentValidationMessages();
        const fieldsValid = this.reportLeadFieldValidity();

        if (!fieldsValid || missingFields.length || formatMessages.length || picklistMessages.length || documentMessages.length) {
            const missingMessage = missingFields.length
                ? `Complete required fields: ${missingFields.map((item) => item.label).join(', ')}.`
                : '';
            const message = [missingMessage, ...formatMessages, ...picklistMessages, ...documentMessages]
                .filter(Boolean)
                .join(' ');
            this.setLeadFormMessage(message || 'Fix the highlighted fields before saving.', 'error');
            this.focusFirstInvalidLeadField(missingFields);
            return false;
        }

        return true;
    }

    firstLeadValue(...values) {
        const value = values.find((item) => item !== undefined && item !== null && String(item).trim() !== '');
        return value === undefined || value === null ? '' : value;
    }

    getLeadRecordValue(record, fieldName, fallbackValue = '') {
        const field = record?.fields?.[fieldName];
        if (!field) return fallbackValue || '';
        const value = field.value;
        return value === undefined || value === null ? '' : value;
    }

    inferLeadTypeFromValues(preferredType, ...organizationSignals) {
        const normalizedType = String(preferredType || '').trim();
        const hasOrganizationSignal = organizationSignals.some((value) => value !== undefined && value !== null && String(value).trim() !== '');
        if (normalizedType === 'Organization' || hasOrganizationSignal) {
            return 'Organization';
        }
        return 'Individual';
    }

    isLeadOrganizationRecordType(record) {
        const recordTypeId = this.getLeadRecordValue(record, 'RecordTypeId', '');
        if (!recordTypeId || !this.leadObjectInfo?.recordTypeInfos) return false;
        const recordTypeInfo = Object.values(this.leadObjectInfo.recordTypeInfos).find((info) => info.recordTypeId === recordTypeId);
        const recordTypeText = `${recordTypeInfo?.developerName || ''} ${recordTypeInfo?.name || ''}`;
        return /organi[sz]ation|organisation/i.test(recordTypeText);
    }

    // ------------------------------------------------------------------
    // BP-005 - Loqate on blur for Email / Mobile on the lead form
    // ------------------------------------------------------------------

    /* Values already on the form (a saved lead) count as known: no callout,
       nothing shown, until the broker changes them. */
    seedLeadChecksFromForm() {
        const email = (this.leadForm.Email || '').trim();
        const mobile = (this.leadForm.MobilePhone || '').trim();
        this.leadEmailCheck = { value: email, status: email ? 'known' : '', message: '' };
        this.leadMobileCheck = { value: mobile, status: mobile ? 'known' : '', message: '' };
    }

    leadCheckText(check) {
        if (check.status === 'checking') return 'Checking...';
        if (check.status === 'valid') return 'Validated';
        return check.message;
    }

    leadCheckClass(check) {
        return `sales-field__status sales-field__status--${check.status}`;
    }

    get showLeadEmailStatus() {
        return ['checking', 'valid', 'invalid'].includes(this.leadEmailCheck.status);
    }

    get isLeadEmailChecking() {
        return this.leadEmailCheck.status === 'checking';
    }

    get leadEmailStatusText() {
        return this.leadCheckText(this.leadEmailCheck);
    }

    get leadEmailStatusClass() {
        return this.leadCheckClass(this.leadEmailCheck);
    }

    get showLeadMobileStatus() {
        return ['checking', 'valid', 'invalid'].includes(this.leadMobileCheck.status);
    }

    get isLeadMobileChecking() {
        return this.leadMobileCheck.status === 'checking';
    }

    get leadMobileStatusText() {
        return this.leadCheckText(this.leadMobileCheck);
    }

    get leadMobileStatusClass() {
        return this.leadCheckClass(this.leadMobileCheck);
    }

    async handleLeadEmailBlur(event) {
        if (this.isLeadFormHydrating) return;
        const input = event.target;
        const email = (input.value || '').trim();
        if (!email) {
            this.leadEmailCheck = { value: '', status: '', message: '' };
            return;
        }
        // Same value, already checked (or loaded): nothing to do.
        if (email === this.leadEmailCheck.value && this.leadEmailCheck.status) return;
        input.setCustomValidity?.('');
        if (!input.checkValidity()) {
            this.leadEmailCheck = { value: email, status: 'invalid', message: 'Enter a valid email address.' };
            return;
        }
        this.leadEmailCheck = { value: email, status: 'checking', message: '' };
        try {
            await validateEmail({ email });
            // The broker moved on to another value while this was in flight.
            if (this.leadEmailCheck.value !== email) return;
            this.leadEmailCheck = { value: email, status: 'valid', message: '' };
        } catch (error) {
            if (this.leadEmailCheck.value !== email) return;
            const message = this.reduceError(error) || 'Email failed validation.';
            this.leadEmailCheck = { value: email, status: 'invalid', message };
            this.setLeadFieldValidity('Email', message);
        }
    }

    async handleLeadMobileBlur(event) {
        if (this.isLeadFormHydrating) return;
        const input = event.target;
        const raw = (input.value || '').trim();
        if (!raw) {
            this.leadMobileCheck = { value: '', status: '', message: '' };
            return;
        }
        if (raw === this.leadMobileCheck.value && this.leadMobileCheck.status) return;
        input.setCustomValidity?.('');
        const mobile = this.normalizeLeadMobileForSave(raw);
        if (!LEAD_PHONE_PATTERN.test(mobile)) {
            this.leadMobileCheck = {
                value: raw,
                status: 'invalid',
                message: 'Enter a valid international mobile number, for example +971581234567.'
            };
            return;
        }
        this.leadMobileCheck = { value: raw, status: 'checking', message: '' };
        try {
            const isValid = await validatePhone({ phone: mobile });
            if (this.leadMobileCheck.value !== raw) return;
            if (isValid === true) {
                this.leadMobileCheck = { value: raw, status: 'valid', message: '' };
            } else {
                const message = 'Mobile number failed validation. Enter a valid mobile number with country code.';
                this.leadMobileCheck = { value: raw, status: 'invalid', message };
                this.setLeadFieldValidity('MobilePhone', message);
            }
        } catch (error) {
            if (this.leadMobileCheck.value !== raw) return;
            const message = this.reduceError(error) || 'Mobile number failed validation.';
            this.leadMobileCheck = { value: raw, status: 'invalid', message };
            this.setLeadFieldValidity('MobilePhone', message);
        }
    }

    getMissingLeadFields() {
        const requiredFields = [
            { field: 'FirstName', label: 'First name' },
            { field: 'LastName', label: 'Last name' },
            { field: 'Email', label: 'Email' },
            { field: 'MobilePhone', label: 'Mobile' },
            { field: 'UAEResidentStatus__c', label: 'Resident status' },
            { field: 'CountryOfResidence__c', label: 'Country of residence' },
            { field: 'Nationality__c', label: 'Nationality' },
            /* Sales origin, Lead origin, Sales type, Bedrooms, Purpose of use
               and Customer budget were removed from both lead forms. They stay
               on leadForm so edit mode still round-trips what the record holds;
               only the inputs and these required checks are gone. */
            { field: 'ProjectInterest__c', label: 'Project name' },
            { field: 'UnitType__c', label: 'Unit type' }
        ];

        if (this.isOrganizationLead) {
            requiredFields.push(
                { field: 'Name', label: 'Organization name' },
                { field: 'UnifiedNumber__c', label: 'Unified number' }
            );
            if (this.isVatRegistrationCertificate) {
                requiredFields.push({ field: 'UAEVATRegisterNumber__c', label: 'UAE VAT registration number' });
            }
        }

        if (this.isResidentLead) {
            requiredFields.push(
                { field: 'EIDNumber__c', label: 'Emirates ID' },
                { field: 'EmiratesIDExpiryDate__c', label: 'Emirates ID expiry date' }
            );
        }

        if (this.isNonResidentLead) {
            requiredFields.push(
                { field: 'PassportNumber__c', label: 'Passport number' },
                { field: 'PassportExpiryDate__c', label: 'Passport expiry date' }
            );
        }

        return requiredFields.filter(({ field }) => !this.hasLeadValue(field));
    }

    getLeadDocumentValidationMessages() {
        const messages = [];

        if (this.isLeadFormEditMode) {
            return messages;
        }

        if (this.isResidentLead) {
            messages.push(...this.getMissingDocumentSideMessages('Emirates ID'));
        }

        if (this.isNonResidentLead) {
            messages.push(...this.getMissingDocumentSideMessages('Passport Copy'));
        }

        if (this.isOrganizationLead && this.getLeadFileCount('Trade License') < 1) {
            messages.push('Upload the Trade License document for organization leads.');
        }

        return messages;
    }

    getInvalidLeadPicklistMessages() {
        if (!this.leadPicklistsLoaded) {
            return ['Lead field options are still loading. Try again in a moment.'];
        }

        return LEAD_PICKLIST_FIELDS.reduce((messages, [fieldName, propName]) => {
            const formFieldName = this.getLeadPicklistFormFieldName(fieldName);
            const value = this.leadForm[formFieldName];
            if (!value) return messages;

            const options = this.getLeadPicklistOptions(fieldName, propName);
            const isValidValue = options.some((option) => option.value === value);
            if (!isValidValue) {
                const label = this.getLeadFieldLabel(fieldName);
                const message = `${label} is not valid for the selected Lead record type. Select one of the available values.`;
                this.setLeadFieldValidity(formFieldName, message);
                messages.push(message);
            }
            return messages;
        }, []);
    }

    hasLeadValue(field) {
        const value = this.leadForm[field];
        return value !== undefined && value !== null && String(value).trim() !== '';
    }

    resetLeadFieldValidity() {
        this.template.querySelectorAll('[data-field]').forEach((field) => {
            field.setCustomValidity?.('');
        });
    }

    setLeadFieldValidity(fieldName, message) {
        const field = this.template.querySelector(`[data-field="${fieldName}"]`);
        field?.setCustomValidity?.(message);
    }

    reportLeadFieldValidity() {
        return Array.from(this.template.querySelectorAll('[data-field]')).reduce((isValid, field) => {
            const fieldIsValid = field.reportValidity ? field.reportValidity() : true;
            return isValid && fieldIsValid;
        }, true);
    }

    focusFirstInvalidLeadField(missingFields = []) {
        const firstMissingField = missingFields.find(({ field }) => this.template.querySelector(`[data-field="${field}"]`));
        const firstInvalidField = firstMissingField
            ? this.template.querySelector(`[data-field="${firstMissingField.field}"]`)
            : Array.from(this.template.querySelectorAll('[data-field]')).find((field) => field.checkValidity && !field.checkValidity());
        firstInvalidField?.focus?.();
    }

    /* Names the side that is actually missing. The old check counted "< 2 files"
       for the type, which two copies of the same side satisfied and which left
       a combined front+back PDF with no way forward. Only reached on create,
       so pending slots are the whole picture. */
    getMissingDocumentSideMessages(documentType) {
        const definition = DOCUMENT_TYPES.find((item) => item.label === documentType);
        const sides = (definition && definition.sides) || [];

        if (!sides.length) {
            return this.getLeadFileCount(documentType) < 1 ? [`Upload the ${documentType} document.`] : [];
        }

        const missing = sides.filter(
            (side) => !this.leadFiles[documentSlotKey(documentType, side)]?.files?.length
        );
        if (!missing.length) return [];

        const names = missing.map((side) => side.toLowerCase()).join(' and ');
        return [`Upload the ${documentType} ${names} ${missing.length > 1 ? 'documents' : 'document'}.`];
    }

    getLeadFileCount(documentType) {
        /* Sums every slot of this type, since a split type now spans one
           entry per side. */
        const pendingCount = Object.values(this.leadFiles).reduce(
            (total, item) => (item && item.documentType === documentType ? total + (item.files?.length || 0) : total),
            0
        );
        const existingCount = this.leadForm.Id
            ? this.selectedLeadDocuments.filter((document) => document.documentType === documentType).length
            : 0;
        return pendingCount + existingCount;
    }

    isResidentStatus(value) {
        const status = (value || '').toLowerCase();
        return status.includes('resident') && !status.includes('non');
    }

    isNonResidentStatus(value) {
        return (value || '').toLowerCase().includes('non');
    }

    getVisibleLeadDocumentTypes(form = this.leadForm) {
        const visibleTypes = new Set(['Complete KYC Form', '3 month Bank statement/source of funds']);
        const isOrganization = form.Type === 'Organization';
        if (!isOrganization && this.isResidentStatus(form.UAEResidentStatus__c)) {
            visibleTypes.add('Emirates ID');
        }
        if (!isOrganization && this.isNonResidentStatus(form.UAEResidentStatus__c)) {
            visibleTypes.add('Passport Copy');
        }
        if (form.Type === 'Organization') {
            visibleTypes.add('Trade License');
            if ((form.vatCertificateType || '').toLowerCase() === 'vat registration certificate') {
                visibleTypes.add('VAT Register');
            } else if (form.vatCertificateType) {
                visibleTypes.add('VAT Undertaking');
            }
        }
        return visibleTypes;
    }

    isLeadDocumentTypeVisible(documentType, form = this.leadForm) {
        return this.getVisibleLeadDocumentTypes(form).has(documentType);
    }

    isLeadDocumentUploadRequired(documentType) {
        if (this.isLeadFormEditMode) return false;
        if (documentType === 'Emirates ID') return this.isResidentLead;
        if (documentType === 'Passport Copy') return this.isNonResidentLead;
        if (documentType === 'Trade License') return this.isOrganizationLead;
        return false;
    }

    pruneLeadFilesForForm(form = this.leadForm) {
        const visibleTypes = this.getVisibleLeadDocumentTypes(form);
        const nextFiles = {};
        let changed = false;
        Object.keys(this.leadFiles).forEach((slotKey) => {
            const entry = this.leadFiles[slotKey];
            const documentType = (entry && entry.documentType) || documentTypeFromSlotKey(slotKey);
            if (visibleTypes.has(documentType)) {
                nextFiles[slotKey] = entry;
            } else {
                changed = true;
            }
        });
        if (changed) {
            this.leadFiles = nextFiles;
        }
    }

    normalizeLeadFormPicklistValues() {
        if (!this.leadPicklistsLoaded) return;
        if (this.isLeadFormEditMode) return;
        const nextForm = { ...this.leadForm };
        let hasChange = false;

        LEAD_PICKLIST_FIELDS.forEach(([fieldName, propName]) => {
            const formFieldName = this.getLeadPicklistFormFieldName(fieldName);
            if (!nextForm[formFieldName]) return;
            const options = this.getLeadPicklistOptions(fieldName, propName, nextForm.ProjectInterest__c);
            if (options.length && !options.some((option) => option.value === nextForm[formFieldName])) {
                nextForm[formFieldName] = '';
                hasChange = true;
            }
        });

        if (hasChange) {
            this.leadForm = nextForm;
        }
    }

    clearInvalidLeadDependentValue(form, fieldName, propName) {
        if (!form[fieldName]) return;
        const options = this.getLeadPicklistOptions(fieldName, propName, form.ProjectInterest__c, false);
        if (options.length && !options.some((option) => option.value === form[fieldName])) {
            form[fieldName] = '';
        }
    }

    getLeadPicklistOptions(fieldName, propName, controllingValue = this.leadForm.ProjectInterest__c, includeCurrentValue = true) {
        const options = this.getLeadDirectPicklistOptions(fieldName, propName, controllingValue);
        const baseOptions = options.length ? options : this.getLeadFallbackPicklistOptions(fieldName, controllingValue);
        return includeCurrentValue ? this.withCurrentLeadPicklistOption(fieldName, baseOptions) : baseOptions;
    }

    getLeadDirectPicklistOptions(fieldName, propName, controllingValue = this.leadForm.ProjectInterest__c) {
        const metadata = this.getLeadPicklistMetadata(fieldName);
        if (!metadata?.values?.length) {
            return this.filterLeadPicklistOptions(fieldName, this.leadPicklists[propName] || []);
        }

        const controllerValues = metadata.controllerValues || {};
        if (!Object.keys(controllerValues).length) {
            return this.filterLeadPicklistOptions(fieldName, this.toUiApiOptions(metadata.values));
        }

        if (!controllingValue) {
            return [];
        }

        const controllerIndex = controllerValues[controllingValue];
        if (controllerIndex === undefined || controllerIndex === null) {
            return [];
        }

        return this.filterLeadPicklistOptions(
            fieldName,
            this.toUiApiOptions(
                metadata.values.filter((value) => this.isPicklistValueValidForController(value, controllerIndex))
            )
        );
    }

    getLeadFallbackPicklistOptions(fieldName, controllingValue = this.leadForm.ProjectInterest__c) {
        const fallbackFields = LEAD_PICKLIST_OPTION_FALLBACKS[fieldName] || [];
        for (const [fallbackFieldName, fallbackPropName] of fallbackFields) {
            const options = this.getLeadDirectPicklistOptions(fallbackFieldName, fallbackPropName, controllingValue);
            if (options.length) return this.filterLeadPicklistOptions(fieldName, options);
        }
        return [];
    }

    withCurrentLeadPicklistOption(fieldName, options = []) {
        const formFieldName = this.getLeadPicklistFormFieldName(fieldName);
        const currentValue = this.leadForm?.[formFieldName];
        if (!currentValue || options.some((option) => option.value === currentValue)) {
            return options;
        }

        return [
            ...options,
            {
                value: currentValue,
                label: currentValue
            }
        ];
    }

    /* BP-012 - native <select> gets its value before its <option>s exist, so
       the value is lost on edit. Flag the current value on the option itself;
       the browser then selects it as the option mounts. */
    withLeadSelection(fieldName, options = []) {
        const currentValue = this.leadForm?.[this.getLeadPicklistFormFieldName(fieldName)] || '';
        return options.map((option) => ({ ...option, isSelected: option.value === currentValue }));
    }

    filterLeadPicklistOptions(fieldName, options) {
        if (fieldName === 'PurposeOfUse__c') {
            return options.filter((option) => ['End User', 'Investor'].includes(option.value));
        }
        return options;
    }

    getLeadPicklistMetadata(fieldName) {
        const apiName = this.resolveLeadPicklistFieldApiName(fieldName);
        return this.leadPicklistFieldValues[fieldName] || this.leadPicklistFieldValues[apiName] || null;
    }

    resolveLeadPicklistFieldApiName(fieldName) {
        return LEAD_PICKLIST_FIELD_ALIASES[fieldName] || fieldName;
    }

    getLeadPicklistFormFieldName(fieldName) {
        return LEAD_PICKLIST_FORM_FIELDS[fieldName] || fieldName;
    }

    getLeadFieldLabel(fieldName) {
        return LEAD_FIELD_LABELS[fieldName] || fieldName;
    }

    isPicklistValueValidForController(value, controllerIndex) {
        const validFor = value?.validFor;
        if (!Array.isArray(validFor) || !validFor.length) {
            return false;
        }
        return validFor.includes(controllerIndex);
    }

    isFutureDate(value) {
        if (!value) return false;
        const date = new Date(`${value}T00:00:00`);
        const today = new Date();
        today.setHours(0, 0, 0, 0);
        return date > today;
    }

    buildLeadPayload() {
        const payload = { ...this.leadForm };
        payload.MobilePhone = this.normalizeLeadMobileForSave(payload.MobilePhone);
        if (payload.Id) {
            LEGACY_DISABLED_LEAD_FIELDS.forEach((fieldName) => {
                delete payload[fieldName];
            });
        }
        if (payload.Type === 'Organization' && !payload.Name) {
            payload.Name = payload.LastName;
        }
        if (payload.Type !== 'Organization') {
            delete payload.Name;
            delete payload.UnifiedNumber__c;
            delete payload.UAEVATRegisterNumber__c;
            delete payload.vatCertificateType;
        }
        if (this.isResidentStatus(payload.UAEResidentStatus__c)) {
            delete payload.PassportNumber__c;
            delete payload.PassportIssueDate__c;
            delete payload.PassportExpiryDate__c;
        }
        if (this.isNonResidentStatus(payload.UAEResidentStatus__c)) {
            delete payload.EIDNumber__c;
            delete payload.EmiratesIDExpiryDate__c;
        }
        if (payload.Type === 'Organization') {
            /* BP-024 - nothing person-identity goes up for an organization, and the
               flag makes Apex blank what an earlier Individual save may hold
               (blank dates are otherwise left untouched on update). */
            LEAD_IDENTITY_DOCUMENT_FIELDS.forEach((field) => {
                delete payload[field];
            });
            payload.clearIdentityDocuments = true;
        }
        Object.keys(payload).forEach((key) => {
            if (payload[key] === '') payload[key] = null;
        });
        return payload;
    }

    normalizeLeadMobileForSave(value) {
        const input = String(value || '').trim();
        if (!input) return '';

        const digits = input.replace(/\D/g, '');
        if (!digits) return input;

        return `+${digits}`;
    }

    async uploadLeadFiles(leadId) {
        if (!leadId) return;
        const visibleTypes = this.getVisibleLeadDocumentTypes();
        const files = Object.values(this.leadFiles).flatMap((item) =>
            !visibleTypes.has(item.documentType) ? [] :
            (item.files || []).map((file) => ({
                documentType: item.documentType,
                file,
                fileName: file.name
            }))
        );
        if (!files.length) return;
        await Promise.all(files.map(async (item) => {
            const base64Data = await this.readFileAsBase64(item.file);
            await uploadFileToDocumentRecord({
                base64Data,
                fileName: item.fileName,
                leadId,
                documentTypeLabel: item.documentType
            });
        }));
    }

    async loadSelectedLeadDocuments() {
        this.selectedLeadDocuments = [];
        this.pendingDeleteDocumentKey = '';
        this.documentsError = false;
        if (!this.selectedLeadId) return;
        this.isDocumentsLoading = true;
        try {
            const docs = (await getUploadedDocuments({ leadId: this.selectedLeadId })) || [];
            this.selectedLeadDocuments = docs.map((doc, index) => ({
                key: `${doc.documentType}-${index}`,
                documentType: doc.documentType,
                title: doc.title,
                contentDocumentId: doc.contentDocumentId,
                downloadUrl: `/sfc/servlet.shepherd/document/download/${doc.contentDocumentId}`
            }));
        } catch (error) {
            this.documentsError = true;
        } finally {
            this.isDocumentsLoading = false;
        }
    }

    handleRequestDeleteLeadDocument(event) {
        this.pendingDeleteDocumentKey = event.currentTarget.dataset.key || '';
    }

    handleCancelDeleteLeadDocument() {
        this.pendingDeleteDocumentKey = '';
    }

    async handleConfirmDeleteLeadDocument(event) {
        const documentType = event.currentTarget.dataset.document;
        if (!documentType || !this.selectedLeadId) return;
        this.pendingDeleteDocumentKey = '';
        try {
            await deleteLeadDocuments({ leadId: this.selectedLeadId, documentTypes: [documentType] });
            await this.loadSelectedLeadDocuments();
            this.showToast('Document deleted', `${documentType} file was removed from this lead.`, 'success');
        } catch (error) {
            this.showToast('Document not deleted', this.reduceError(error), 'error');
        }
    }

    get leadDocumentRows() {
        return this.selectedLeadDocuments.map((doc) => ({
            ...doc,
            isConfirmingDelete: doc.key === this.pendingDeleteDocumentKey
        }));
    }

    get leadTypeOptions() {
        return LEAD_TYPE_OPTIONS.map((option) => ({
            ...option,
            className: option.value === this.leadForm.Type ? 'segmented-pill segmented-pill--active' : 'segmented-pill',
            ariaPressed: option.value === this.leadForm.Type
        }));
    }

    get isOrganizationLead() {
        return this.leadForm.Type === 'Organization';
    }

    get showVatTemplateDownload() {
        return (this.leadForm.vatCertificateType || '') === 'VAT Undertaking Certificate';
    }

    get vatTemplateUrl() {
        return VAT_UNDERTAKING_TEMPLATE;
    }

    /* The legacy lead screen offered the blank KYC form beside its upload slot;
       the revamp shipped the upload but never wired the template. Same static
       resource, gated on the KYC slot being rendered. */
    get showKycTemplateDownload() {
        return this.isLeadDocumentTypeVisible('Complete KYC Form');
    }

    get kycTemplateUrl() {
        return KYC_FORM_TEMPLATE;
    }

    /* BP-024 - identity documents (Emirates ID / passport) belong to a person, so
       an Organization lead never captures them. These two getters drive the
       inputs, the format checks, the required fields and the upload rules, so
       the type gate lives here once. Resident status, Country and Nationality
       stay on the form for both types (the console KYC needs them on the
       contact an organization lead converts into). */
    get isResidentLead() {
        return !this.isOrganizationLead && this.isResidentStatus(this.leadForm.UAEResidentStatus__c);
    }

    get isNonResidentLead() {
        return !this.isOrganizationLead && this.isNonResidentStatus(this.leadForm.UAEResidentStatus__c);
    }

    get isVatRegistrationCertificate() {
        return (this.leadForm.vatCertificateType || '').toLowerCase() === 'vat registration certificate';
    }

    get isLeadFormEditMode() {
        return Boolean(this.leadForm.Id);
    }

    get leadFormHasMessage() {
        return Boolean(this.leadFormMessage);
    }

    get leadFormMessageClass() {
        return this.getFormMessageClass(this.leadFormMessageTone);
    }

    get isLeadFormBusy() {
        return this.isSavingLead || this.isLeadFormHydrating;
    }

    get leadSaveButtonLabel() {
        if (this.isLeadFormHydrating) return 'Loading details...';
        return this.isSavingLead ? 'Saving lead...' : 'Save lead';
    }

    get eoiFormHasMessage() {
        return Boolean(this.eoiFormMessage);
    }

    get eoiFormMessageClass() {
        return this.getFormMessageClass(this.eoiFormMessageTone);
    }

    get eoiCustomerButtonLabel() {
        return this.isEoiSaving ? 'Saving customer...' : 'Next';
    }

    get eoiSubmitButtonLabel() {
        return this.isEoiSaving ? 'Submitting EOI...' : 'Submit EOI';
    }

    get isEoiSubmitDisabled() {
        return this.isEoiSaving || this.isEoiCatalogUnavailable || !this.allEoiInterestsComplete;
    }

    get verificationButtonLabel() {
        return this.isVerifyingCode ? 'Verifying...' : 'Verify';
    }

    get showEoiFormFooter() {
        return true;
    }

    get leadDocumentInputs() {
        const blocked = this.isLeadDocumentsBlocked;
        return DOCUMENT_TYPES.filter((item) => this.isLeadDocumentTypeVisible(item.label)).flatMap((item) => {
            const required = this.isLeadDocumentUploadRequired(item.label);
            const sides = item.sides || [];

            if (!sides.length) {
                const entry = this.leadFiles[item.label];
                return [this.withExistingLeadFiles({
                    key: item.key,
                    slotKey: item.label,
                    label: item.label,
                    fileName: entry?.fileName || 'No file selected',
                    hasFile: Boolean(entry),
                    required,
                    multiple: true
                }, blocked)];
            }

            return sides.map((side) => {
                const slotKey = documentSlotKey(item.label, side);
                const entry = this.leadFiles[slotKey];
                return this.withExistingLeadFiles({
                    key: `${item.key}-${side.toLowerCase()}`,
                    slotKey,
                    label: `${item.label} (${side})`,
                    fileName: entry?.fileName || 'No file selected',
                    hasFile: Boolean(entry),
                    required,
                    multiple: false
                }, blocked);
            });
        });
    }

    // ------------------------------------------------------------------
    // BP-015 - existing files live inside their upload card on edit
    // ------------------------------------------------------------------

    /* Edit mode only: while the saved files are loading (or failed to load)
       every card is locked, so a duplicate can never be picked blind. */
    get isLeadDocumentsBlocked() {
        return this.isLeadFormEditMode && (this.isDocumentsLoading || this.documentsError);
    }

    get isLeadFileActionDisabled() {
        return this.isLeadFormBusy || this.isDeletingLeadFile;
    }

    /* Apex returns the type only (no side), so a two-sided type hands its
       files out in order: first to Front, second to Back, and so on. Every
       file on the lead always lands in exactly one card. */
    getExistingLeadFilesForSlot(slotKey) {
        if (!this.isLeadFormEditMode) return [];
        const documentType = documentTypeFromSlotKey(slotKey);
        const item = DOCUMENT_TYPES.find((entry) => entry.label === documentType);
        const sides = item?.sides || [];
        const wanted = documentType.toLowerCase();
        const files = this.selectedLeadDocuments.filter(
            (doc) => String(doc.documentType || '').toLowerCase() === wanted
        );
        if (!sides.length) return files;
        const sideIndex = sides.indexOf(slotKey.split(DOCUMENT_SIDE_SEPARATOR)[1]);
        return files.filter((doc, index) => index % sides.length === sideIndex);
    }

    isLeadSlotLocked(slotKey) {
        return this.isLeadDocumentsBlocked || this.getExistingLeadFilesForSlot(slotKey).length > 0;
    }

    withExistingLeadFiles(slot, blocked) {
        const existingFiles = this.getExistingLeadFilesForSlot(slot.slotKey).map((doc) => ({
            key: doc.contentDocumentId,
            title: doc.title,
            downloadUrl: doc.downloadUrl,
            isConfirmingDelete: doc.contentDocumentId === this.pendingDeleteFileId
        }));
        const hasExisting = existingFiles.length > 0;
        let lockedHint = '';
        if (this.isDocumentsLoading) lockedHint = 'Loading uploaded files...';
        else if (this.documentsError) lockedHint = 'Uploaded files could not be loaded.';
        else if (hasExisting) lockedHint = 'Delete the file to upload a new one.';
        return {
            ...slot,
            existingFiles,
            hasExisting,
            isLocked: blocked || hasExisting,
            lockedHint
        };
    }

    handleRequestDeleteLeadFile(event) {
        this.pendingDeleteFileId = event.currentTarget.dataset.fileId || '';
    }

    handleCancelDeleteLeadFile() {
        this.pendingDeleteFileId = '';
    }

    async handleConfirmDeleteLeadFile(event) {
        const contentDocumentId = event.currentTarget.dataset.fileId || '';
        const leadId = this.leadForm.Id;
        if (!contentDocumentId || !leadId || this.isDeletingLeadFile) return;
        this.isDeletingLeadFile = true;
        try {
            const removed = await deleteLeadDocumentFile({ leadId, contentDocumentId });
            this.pendingDeleteFileId = '';
            await this.loadSelectedLeadDocuments();
            if (removed) {
                this.showToast('File deleted', 'You can now upload a new file in that slot.', 'success');
            } else {
                this.showToast('File not deleted', 'That file is no longer on this lead. The list has been refreshed.', 'warning');
            }
        } catch (error) {
            this.showToast('File not deleted', this.reduceError(error), 'error');
        } finally {
            this.isDeletingLeadFile = false;
        }
    }

    handleRetryLeadDocuments() {
        if (this.isDocumentsLoading) return;
        this.loadSelectedLeadDocuments();
    }

    get salutationOptions() {
        return this.withLeadSelection('Salutation', this.getLeadPicklistOptions('Salutation', 'salutationOptions'));
    }

    get residentStatusOptions() {
        return this.withLeadSelection('UAEResidentStatus__c', this.getLeadPicklistOptions('UAEResidentStatus__c', 'residentStatusOptions'));
    }

    get countryOptions() {
        return this.withLeadSelection('CountryOfResidence__c', this.getLeadPicklistOptions('CountryOfResidence__c', 'countryOptions'));
    }

    get nationalityOptions() {
        return this.withLeadSelection('Nationality__c', this.getLeadPicklistOptions('Nationality__c', 'nationalityOptions'));
    }

    get salesOriginOptions() {
        return this.getLeadPicklistOptions('SalesOrigin__c', 'salesOriginOptions');
    }

    get leadOriginOptions() {
        return this.getLeadPicklistOptions('LeadOrigin__c', 'leadOriginOptions');
    }

    get projectInterestOptions() {
        return this.withLeadSelection('ProjectInterest__c', this.getLeadPicklistOptions('ProjectInterest__c', 'projectInterestOptions'));
    }

    get unitTypeOptions() {
        return this.withLeadSelection('UnitType__c', this.getLeadPicklistOptions('UnitType__c', 'unitTypeOptions'));
    }

    get bedroomOptions() {
        return this.getLeadPicklistOptions('NumberOfBedrooms__c', 'bedroomOptions');
    }

    get budgetOptions() {
        return this.getLeadPicklistOptions('CustomerBudget__c', 'budgetOptions');
    }

    get purposeOptions() {
        return this.getLeadPicklistOptions('PurposeOfUse__c', 'purposeOptions');
    }

    get salesTypeOptions() {
        return this.getLeadPicklistOptions('SalesType__c', 'salesTypeOptions');
    }

    get vatCertificateTypeOptions() {
        return this.withLeadSelection('VAT_Certificate_Type__c', this.getLeadPicklistOptions('VAT_Certificate_Type__c', 'vatCertificateTypeOptions'));
    }

    get selectedLead() {
        return this.leadRows.find((lead) => lead.id === this.selectedLeadId) || null;
    }

    get selectedLeadRequirementLabel() {
        if (!this.selectedLead) return 'Not specified';
        const values = [this.selectedLead.projectLabel, this.selectedLead.unitTypeLabel].filter(
            (value) => value && value !== 'Not specified'
        );
        return values.join(' / ') || 'Not specified';
    }

    get hasSelectedLeadDocuments() {
        return this.selectedLeadDocuments.length > 0;
    }

    get opportunityRows() {
        return this.opportunities.map((opp, index) => ({
            ...opp,
            id: opp.Id,
            key: opp.Id || `opp-${index}`,
            name: opp.Name || 'Opportunity',
            stageLabel: opp.StageName || 'No stage',
            statusTone: this.getStatusTone(opp.StageName),
            projectName: opp.ProjectName || 'Not linked',
            salesManagerName: opp.SalesManagerName || 'Not assigned',
            brokerAgentName: opp.BrokerAgentName || 'Not assigned',
            customerContact: [opp.Email__c, opp.Mobile__c].filter(Boolean).join(' / ') || 'Restricted',
            emailLabel: opp.Email__c || 'Restricted',
            mobileLabel: opp.Mobile__c || 'Restricted',
            residentStatus: opp.UAE_Resident_Status__c || 'Not specified',
            createdLabel: opp.CreatedDate || '',
            rowStyle: `--reveal-index: ${index}`
        }));
    }

    get filteredOpportunityRows() {
        const query = this.opportunitySearch.trim().toLowerCase();
        return this.opportunityRows.filter((opp) => {
            const matchesStage = this.opportunityStageFilter === 'all' || opp.stageLabel === this.opportunityStageFilter;
            const matchesProject = this.opportunityProjectFilter === 'all' || opp.projectName === this.opportunityProjectFilter;
            const matchesResidentStatus =
                this.opportunityResidentStatusFilter === 'all' || opp.residentStatus === this.opportunityResidentStatusFilter;
            const matchesBrokerAgent = this.opportunityBrokerAgentFilter === 'all' || opp.brokerAgentName === this.opportunityBrokerAgentFilter;
            const matchesSalesManager = this.opportunitySalesManagerFilter === 'all' || opp.salesManagerName === this.opportunitySalesManagerFilter;
            const haystack = [
                opp.name,
                opp.stageLabel,
                opp.projectName,
                opp.residentStatus,
                opp.salesManagerName,
                opp.brokerAgentName,
                opp.customerContact
            ].join(' ').toLowerCase();
            return (
                matchesStage &&
                matchesProject &&
                matchesResidentStatus &&
                matchesBrokerAgent &&
                matchesSalesManager &&
                (!query || haystack.includes(query))
            );
        });
    }

    get paginatedOpportunityRows() {
        return this.paginate(this.filteredOpportunityRows, this.opportunityPage);
    }

    get opportunityStageOptions() {
        return this.buildSelectOptions(this.opportunityRows, 'stageLabel', 'All stages');
    }

    get opportunityFilterButtonClass() {
        return this.hasOpportunityActiveFilters ? 'sales-filter-button sales-filter-button--active' : 'sales-filter-button';
    }

    get opportunityFilterPanelClass() {
        return this.isOpportunityFilterPanelOpen ? 'sales-filter sales-filter--open' : 'sales-filter';
    }

    get hasOpportunityActiveFilters() {
        return this.opportunityActiveFilterCount > 0;
    }

    get opportunityDateRangeActive() {
        return Boolean(this.opportunityStartDate && this.opportunityEndDate);
    }

    get isOpportunityDateRangeInvalid() {
        return Boolean(
            this.pendingOpportunityStartDate &&
            this.pendingOpportunityEndDate &&
            this.pendingOpportunityStartDate > this.pendingOpportunityEndDate
        );
    }

    get opportunityDateRangeHint() {
        if (this.isOpportunityDateRangeInvalid) {
            return 'The start date must be on or before the end date.';
        }
        if (Boolean(this.pendingOpportunityStartDate) !== Boolean(this.pendingOpportunityEndDate)) {
            return 'Select both dates to filter by a date range.';
        }
        return '';
    }

    get opportunityActiveFilterCount() {
        return [
            this.opportunityDateRangeActive,
            this.opportunityStageFilter !== 'all',
            this.opportunityProjectFilter !== 'all',
            this.opportunityResidentStatusFilter !== 'all',
            this.opportunityBrokerAgentFilter !== 'all',
            this.opportunitySalesManagerFilter !== 'all'
        ].filter(Boolean).length;
    }

    get opportunityAppliedFilterChips() {
        return [
            this.opportunityDateRangeActive
                ? { key: 'opp-dates', label: `Dates: ${this.opportunityStartDate} to ${this.opportunityEndDate}` }
                : null,
            this.opportunityStageFilter !== 'all' ? { key: 'opp-stage', label: `Stage: ${this.opportunityStageFilter}` } : null,
            this.opportunityProjectFilter !== 'all' ? { key: 'opp-project', label: `Project: ${this.opportunityProjectFilter}` } : null,
            this.opportunityResidentStatusFilter !== 'all'
                ? { key: 'opp-resident-status', label: `Resident: ${this.opportunityResidentStatusFilter}` }
                : null,
            this.opportunityBrokerAgentFilter !== 'all' ? { key: 'opp-broker-agent', label: `Broker agent: ${this.opportunityBrokerAgentFilter}` } : null,
            this.opportunitySalesManagerFilter !== 'all' ? { key: 'opp-sales-manager', label: `Sales manager: ${this.opportunitySalesManagerFilter}` } : null
        ].filter(Boolean);
    }

    get opportunityStageFilterOptions() {
        return this.buildSalesFilterOptions(this.getOpportunityRowsForFilter('stage'), 'stageLabel', 'All stages', this.pendingOpportunityStageFilter);
    }

    get opportunityProjectFilterOptions() {
        return this.buildSalesFilterOptions(this.getOpportunityRowsForFilter('project'), 'projectName', 'All projects', this.pendingOpportunityProjectFilter);
    }

    get opportunityResidentStatusFilterOptions() {
        return this.buildSalesFilterOptions(
            this.getOpportunityRowsForFilter('residentStatus'),
            'residentStatus',
            'All residents',
            this.pendingOpportunityResidentStatusFilter
        );
    }

    get opportunityBrokerAgentFilterOptions() {
        return this.buildSalesFilterOptions(this.getOpportunityRowsForFilter('brokerAgent'), 'brokerAgentName', 'All broker agents', this.pendingOpportunityBrokerAgentFilter);
    }

    get opportunitySalesManagerFilterOptions() {
        return this.buildSalesFilterOptions(this.getOpportunityRowsForFilter('salesManager'), 'salesManagerName', 'All sales managers', this.pendingOpportunitySalesManagerFilter);
    }

    get opportunityPageLabel() {
        return this.pageLabel(this.filteredOpportunityRows.length, this.opportunityPage);
    }

    get isFirstOpportunityPage() {
        return this.opportunityPage <= 1;
    }

    get isLastOpportunityPage() {
        return this.opportunityPage >= this.pageCount(this.filteredOpportunityRows.length);
    }

    get hasFilteredOpportunities() {
        return this.filteredOpportunityRows.length > 0;
    }

    handleOpportunitySearch(event) {
        this.opportunitySearch = event.target.value || '';
        this.opportunityPage = 1;
    }

    handleOpportunityStageFilter(event) {
        this.opportunityStageFilter = event.target.value || 'all';
        this.opportunityPage = 1;
    }

    toggleOpportunityFilterPanel() {
        if (this.isOpportunityFilterPanelOpen) {
            this.isOpportunityFilterPanelOpen = false;
            return;
        }
        this.closeSalesFilterPanels();
        this.syncPendingOpportunityFilters();
        this.isOpportunityFilterPanelOpen = true;
    }

    closeOpportunityFilterPanel() {
        this.isOpportunityFilterPanelOpen = false;
    }

    handlePendingOpportunityFilterChange(event) {
        const field = event.currentTarget.dataset.filter;
        if (field === 'startDate' || field === 'endDate') {
            const dateValue = event.target.value || '';
            if (field === 'startDate') this.pendingOpportunityStartDate = dateValue;
            if (field === 'endDate') this.pendingOpportunityEndDate = dateValue;
            return;
        }
        const value = event.target.value || 'all';
        if (field === 'stage') this.pendingOpportunityStageFilter = value;
        if (field === 'project') this.pendingOpportunityProjectFilter = value;
        if (field === 'residentStatus') this.pendingOpportunityResidentStatusFilter = value;
        if (field === 'brokerAgent') this.pendingOpportunityBrokerAgentFilter = value;
        if (field === 'salesManager') this.pendingOpportunitySalesManagerFilter = value;
        this.reconcilePendingOpportunityFilters();
    }

    async applyOpportunityFilters() {
        if (this.isOpportunityDateRangeInvalid) return;
        const nextStartDate = this.pendingOpportunityStartDate || '';
        const nextEndDate = this.pendingOpportunityEndDate || '';
        const datesChanged = nextStartDate !== this.opportunityStartDate || nextEndDate !== this.opportunityEndDate;
        this.opportunityStartDate = nextStartDate;
        this.opportunityEndDate = nextEndDate;
        this.opportunityStageFilter = this.pendingOpportunityStageFilter || 'all';
        this.opportunityProjectFilter = this.pendingOpportunityProjectFilter || 'all';
        this.opportunityResidentStatusFilter = this.pendingOpportunityResidentStatusFilter || 'all';
        this.opportunityBrokerAgentFilter = this.pendingOpportunityBrokerAgentFilter || 'all';
        this.opportunitySalesManagerFilter = this.pendingOpportunitySalesManagerFilter || 'all';
        this.opportunityPage = 1;
        this.isOpportunityFilterPanelOpen = false;
        if (datesChanged) {
            await this.loadOpportunities();
        } else {
            this.reconcileOpportunityFilters();
        }
    }

    async clearOpportunityFilters() {
        const needsReload = this.opportunityDateRangeActive;
        this.opportunityStartDate = '';
        this.opportunityEndDate = '';
        this.opportunityStageFilter = 'all';
        this.opportunityProjectFilter = 'all';
        this.opportunityResidentStatusFilter = 'all';
        this.opportunityBrokerAgentFilter = 'all';
        this.opportunitySalesManagerFilter = 'all';
        this.syncPendingOpportunityFilters();
        this.opportunityPage = 1;
        if (needsReload) {
            await this.loadOpportunities();
        }
    }

    handlePreviousOpportunities() {
        this.opportunityPage = Math.max(1, this.opportunityPage - 1);
    }

    handleNextOpportunities() {
        this.opportunityPage = Math.min(this.pageCount(this.filteredOpportunityRows.length), this.opportunityPage + 1);
    }

    async handleOpenOpportunity(event) {
        const id = event.currentTarget.dataset.id;
        if (!id) return;
        await this.openOpportunityDrawer(id);
    }

    async openOpportunityDrawer(id) {
        this.selectedOpportunityId = id;
        this.drawerMode = 'opportunity-detail';
        this._shouldFocusDrawer = true;
        await this.loadSalesOrders(id);
    }

    async loadSalesOrders(opportunityId) {
        this.salesOrders = [];
        this.salesOrdersError = false;
        this.isSalesOrdersLoading = true;
        try {
            const records = (await getSalesOrdersForOpportunity({ opportunityId })) || [];
            this.salesOrders = records.map((order, index) => ({
                key: order.Id || `sales-order-${index}`,
                id: order.Id,
                name: order.Name || 'Sales Order',
                totalAmountLabel: this.formatCurrency(order.TotalAmount__c),
                projectName: order.ProjectName__c || order.Opportunity__r?.ProjectInterest__c || 'Not specified',
                statusLabel: order.Status__c || 'No status',
                statusTone: this.getStatusTone(order.Status__c),
                unitName: order.Unit_Name__c || 'Not assigned',
                bedrooms: order.Number_of_bedrooms__c || 'Not specified'
            }));
        } catch (error) {
            this.salesOrdersError = true;
        } finally {
            this.isSalesOrdersLoading = false;
        }
    }

    get selectedOpportunity() {
        return this.opportunityRows.find((opp) => opp.id === this.selectedOpportunityId) || null;
    }

    get hasSalesOrders() {
        return this.salesOrders.length > 0;
    }

    // BP-041: one list - the pending payment requests (no EOI yet) first, then the EOI rows.
    get eoiRows() {
        const pending = (this.eoiPendingRecords || []).map((item, index) => this.buildPendingEoiRow(item, index));
        const offset = pending.length;
        const eois = this.eoiRecords.map((item, index) => {
            const status = item.Status__c || 'New';
            // BP-032/041: the payment number is the broker's reference; the EOI number once the money is held or taken
            const link = this.eoiLinkMap[item.Id] || null;
            const paymentRecordId = link?.paymentId || '';
            const paymentName = link?.paymentName || '';
            const linkStatus = link?.status || '';
            const eoiNumber = EOI_NUMBER_VISIBLE_STATUSES.has(linkStatus) ? (item.EOIId__c || item.Name || '') : '';
            // BP-067: the approved field on the payment speaks first; a legacy EOI with no payment falls back to its own
            const brokerStatus = eoiBrokerStatus(link?.dashboardStatus || '', linkStatus, status);
            return {
                ...item,
                id: item.Id,
                key: item.Id || `eoi-${index}`,
                name: paymentName || 'EOI',
                paymentName,
                linkStatus,
                eoiNumber,
                // BP-035: display-only; search and export keep the real (possibly blank) values
                eoiNumberLabel: eoiNumber || EOI_TABLE_PLACEHOLDER,
                paymentNameLabel: paymentName || EOI_TABLE_PLACEHOLDER,
                customerName: item.Account__r?.Name || 'Customer',
                customerContact: [item.Account__r?.Email__c, item.Account__r?.PersonMobilePhone].filter(Boolean).join(' / ') || 'Restricted',
                customerEmail: item.Account__r?.Email__c || 'Restricted',
                customerMobile: item.Account__r?.PersonMobilePhone || 'Restricted',
                opportunityName: item.Opportunity__r?.Name || 'Not linked',
                projectName: item.Project__r?.Name || 'Not specified',
                phaseName: item.Phase__r?.Name || 'Not specified',
                unitType: item.UnitType__c || 'Not specified',
                bedrooms: item.NumberofBedrooms__c || 'Not specified',
                units: item.Number_of_Units__c || 0,
                amountLabel: this.formatCurrency(item.EOI_Amount_AED__c),
                statusLabel: brokerStatus,
                statusTone: eoiBrokerStatusTone(brokerStatus),
                comments: item.EOIComments__c || '',
                isPending: false,
                ...eoiRowActionFields(eoiRowAction(false, linkStatus, null, paymentRecordId, false), paymentRecordId),
                rowStyle: `--reveal-index: ${offset + index}`
            };
        });
        /* Both blocks arrive newest-first from Apex, but gluing them put every unpaid request
           above every paid EOI. Ranked together on the payment number instead, so the newest
           row is at the top of page 1 wherever it came from. The reveal index is stamped last,
           after the order is settled, or the rows fade in scrambled. */
        const flashId = this.flashPaymentId;
        const busyId = this.eoiActionBusyId;
        return [...pending, ...eois]
            .sort((a, b) => eoiPaymentSequence(b) - eoiPaymentSequence(a))
            .map((row, position) => ({
                ...row,
                rowStyle: `--reveal-index: ${position}`,
                // BP-060: only the request just created, and only until its timer clears
                rowClass: flashId && row.paymentRecordId === flashId ? 'record-row record-row--new' : 'record-row',
                // BP-061: the loader belongs to the pill that was pressed, never to every pill at once
                rowActionBusy: Boolean(busyId && row.paymentRecordId && row.paymentRecordId === busyId)
            }));
    }

    // BP-041: a payment request the customer has not paid yet, shaped like an EOI row so the table,
    // search, filters, export and the detail drawer need no second code path. Stored status only.
    buildPendingEoiRow(item, index) {
        const status = item.status || 'Link Created';
        const units = Math.max(1, Number(item.units) || 1);
        const paymentName = item.paymentName || '';
        // BP-056/057: no EOI exists on a pending request, so only the payment status can speak - and
        // the expiry overrides it while the poller has not caught up yet
        const brokerStatus = eoiBrokerStatus(item.dashboardStatus, status, '', item.expiresOn);
        const action = eoiRowAction(true, status, item.expiresOn, item.paymentId, item.superseded === true);
        return {
            id: item.paymentId,
            key: item.paymentId || `pending-${index}`,
            name: paymentName || 'Payment request',
            paymentName,
            linkStatus: status,
            eoiNumber: '',
            eoiNumberLabel: EOI_TABLE_PLACEHOLDER,
            paymentNameLabel: paymentName || EOI_TABLE_PLACEHOLDER,
            customerName: item.customerName || 'Customer',
            customerContact: [item.maskedEmail, item.maskedPhone].filter(Boolean).join(' / ') || 'Restricted',
            customerEmail: item.maskedEmail || 'Restricted',
            customerMobile: item.maskedPhone || 'Restricted',
            opportunityName: item.opportunityName || 'Not linked',
            projectName: item.projectName || 'Not specified',
            phaseName: item.phaseName || 'Not specified',
            unitType: item.unitType || 'Not specified',
            bedrooms: item.bedrooms || 'Not specified',
            units,
            amountLabel: this.formatCurrency(item.amount),
            statusLabel: brokerStatus,
            statusTone: eoiBrokerStatusTone(brokerStatus),
            comments: item.remarks || '',
            isPending: true,
            ...eoiRowActionFields(action, item.paymentId),
            rowStyle: `--reveal-index: ${index}`
        };
    }

    get filteredEoiRows() {
        const query = this.eoiSearch.trim().toLowerCase();
        return this.eoiRows.filter((eoi) => {
            const matchesStatus = this.eoiStatusFilter === 'all' || eoi.statusLabel === this.eoiStatusFilter;
            const matchesProject = this.eoiProjectFilter === 'all' || eoi.projectName === this.eoiProjectFilter;
            const matchesPhase = this.eoiPhaseFilter === 'all' || eoi.phaseName === this.eoiPhaseFilter;
            const matchesUnitType = this.eoiUnitTypeFilter === 'all' || eoi.unitType === this.eoiUnitTypeFilter;
            const matchesBedrooms = this.eoiBedroomsFilter === 'all' || eoi.bedrooms === this.eoiBedroomsFilter;
            const haystack = [
                eoi.paymentName,
                eoi.eoiNumber,
                eoi.customerName,
                eoi.opportunityName,
                eoi.projectName,
                eoi.phaseName,
                eoi.unitType,
                eoi.bedrooms,
                eoi.statusLabel
            ].join(' ').toLowerCase();
            return matchesStatus && matchesProject && matchesPhase && matchesUnitType && matchesBedrooms && (!query || haystack.includes(query));
        });
    }

    get paginatedEoiRows() {
        return this.paginate(this.filteredEoiRows, this.eoiPage);
    }

    get eoiStatusOptions() {
        return this.buildSelectOptions(this.eoiRows, 'statusLabel', 'All statuses');
    }

    get eoiFilterButtonClass() {
        return this.hasEoiActiveFilters ? 'sales-filter-button sales-filter-button--active' : 'sales-filter-button';
    }

    get eoiFilterPanelClass() {
        return this.isEoiFilterPanelOpen ? 'sales-filter sales-filter--open' : 'sales-filter';
    }

    get hasEoiActiveFilters() {
        return this.eoiActiveFilterCount > 0;
    }

    get eoiActiveFilterCount() {
        return [
            this.eoiStatusFilter !== 'all',
            this.eoiProjectFilter !== 'all',
            this.eoiPhaseFilter !== 'all',
            this.eoiUnitTypeFilter !== 'all',
            this.eoiBedroomsFilter !== 'all'
        ].filter(Boolean).length;
    }

    get eoiAppliedFilterChips() {
        return [
            this.eoiStatusFilter !== 'all' ? { key: 'eoi-status', label: `Status: ${this.eoiStatusFilter}` } : null,
            this.eoiProjectFilter !== 'all' ? { key: 'eoi-project', label: `Project: ${this.eoiProjectFilter}` } : null,
            this.eoiPhaseFilter !== 'all' ? { key: 'eoi-phase', label: `Phase: ${this.eoiPhaseFilter}` } : null,
            this.eoiUnitTypeFilter !== 'all' ? { key: 'eoi-unit-type', label: `Unit type: ${this.eoiUnitTypeFilter}` } : null,
            this.eoiBedroomsFilter !== 'all' ? { key: 'eoi-bedrooms', label: `Bedrooms: ${this.eoiBedroomsFilter}` } : null
        ].filter(Boolean);
    }

    get eoiStatusFilterOptions() {
        return this.buildSalesFilterOptions(this.getEoiRowsForFilter('status'), 'statusLabel', 'All statuses', this.pendingEoiStatusFilter);
    }

    get eoiProjectFilterOptions() {
        return this.buildSalesFilterOptions(this.getEoiRowsForFilter('project'), 'projectName', 'All projects', this.pendingEoiProjectFilter);
    }

    get eoiPhaseFilterOptions() {
        return this.buildSalesFilterOptions(this.getEoiRowsForFilter('phase'), 'phaseName', 'All phases', this.pendingEoiPhaseFilter);
    }

    get eoiUnitTypeFilterOptions() {
        return this.buildSalesFilterOptions(this.getEoiRowsForFilter('unitType'), 'unitType', 'All unit types', this.pendingEoiUnitTypeFilter);
    }

    get eoiBedroomsFilterOptions() {
        return this.buildSalesFilterOptions(this.getEoiRowsForFilter('bedrooms'), 'bedrooms', 'All bedrooms', this.pendingEoiBedroomsFilter);
    }

    get eoiPageLabel() {
        return this.pageLabel(this.filteredEoiRows.length, this.eoiPage);
    }

    /* BP-061: while a row action is running the whole EOI tab is shut - search, filters, refresh,
       export, New EOI, paging and the rows themselves - so nothing can re-read, re-order or navigate
       away from the request the broker is waiting on. */
    get isEoiBusyOrLoading() {
        return this.isEoiActionBusy || this.isEoiLoading;
    }

    get isEoiPreviousDisabled() {
        return this.isFirstEoiPage || this.isEoiActionBusy;
    }

    get isEoiNextDisabled() {
        return this.isLastEoiPage || this.isEoiActionBusy;
    }

    get isFirstEoiPage() {
        return this.eoiPage <= 1;
    }

    get isLastEoiPage() {
        return this.eoiPage >= this.pageCount(this.filteredEoiRows.length);
    }

    get hasFilteredEois() {
        return this.filteredEoiRows.length > 0;
    }

    handleEoiSearch(event) {
        if (this.isEoiActionBusy) return;
        this.eoiSearch = event.target.value || '';
        this.eoiPage = 1;
    }

    handleEoiStatusFilter(event) {
        this.eoiStatusFilter = event.target.value || 'all';
        this.eoiPage = 1;
    }

    toggleEoiFilterPanel() {
        if (this.isEoiActionBusy) return;
        if (this.isEoiFilterPanelOpen) {
            this.isEoiFilterPanelOpen = false;
            return;
        }
        this.closeSalesFilterPanels();
        this.syncPendingEoiFilters();
        this.isEoiFilterPanelOpen = true;
    }

    closeEoiFilterPanel() {
        this.isEoiFilterPanelOpen = false;
    }

    handlePendingEoiFilterChange(event) {
        if (this.isEoiActionBusy) return;
        const field = event.currentTarget.dataset.filter;
        const value = event.target.value || 'all';
        if (field === 'status') this.pendingEoiStatusFilter = value;
        if (field === 'project') this.pendingEoiProjectFilter = value;
        if (field === 'phase') this.pendingEoiPhaseFilter = value;
        if (field === 'unitType') this.pendingEoiUnitTypeFilter = value;
        if (field === 'bedrooms') this.pendingEoiBedroomsFilter = value;
        this.reconcilePendingEoiFilters();
    }

    applyEoiFilters() {
        if (this.isEoiActionBusy) return;
        this.eoiStatusFilter = this.pendingEoiStatusFilter || 'all';
        this.eoiProjectFilter = this.pendingEoiProjectFilter || 'all';
        this.eoiPhaseFilter = this.pendingEoiPhaseFilter || 'all';
        this.eoiUnitTypeFilter = this.pendingEoiUnitTypeFilter || 'all';
        this.eoiBedroomsFilter = this.pendingEoiBedroomsFilter || 'all';
        this.eoiPage = 1;
        this.isEoiFilterPanelOpen = false;
        this.reconcileEoiFilters();
    }

    clearEoiFilters() {
        if (this.isEoiActionBusy) return;
        this.eoiStatusFilter = 'all';
        this.eoiProjectFilter = 'all';
        this.eoiPhaseFilter = 'all';
        this.eoiUnitTypeFilter = 'all';
        this.eoiBedroomsFilter = 'all';
        this.syncPendingEoiFilters();
        this.eoiPage = 1;
    }

    handlePreviousEois() {
        if (this.isEoiActionBusy) return;
        this.eoiPage = Math.max(1, this.eoiPage - 1);
    }

    handleNextEois() {
        if (this.isEoiActionBusy) return;
        this.eoiPage = Math.min(this.pageCount(this.filteredEoiRows.length), this.eoiPage + 1);
    }

    handleOpenEoi(event) {
        if (this.isEoiActionBusy) return;
        const id = event.currentTarget.dataset.id;
        if (!id) return;
        this.openEoiDrawer(id);
    }

    openEoiDrawer(id) {
        this.selectedEoiId = id;
        this.drawerMode = 'eoi-detail';
        this._shouldFocusDrawer = true;
    }

    // Aurelix IT 29 Aug 2026 - row is a div, so Enter/Space handled here
    /**
     * BP-057. Send the existing link again, or mint a fresh one on the same payment record and send
     * that. Which of the two is decided here only to pick the call; the server re-reads the stored
     * row and enforces the rule again, so a stale screen cannot act on a row that has moved on.
     */
    async handleEoiRowAction(event) {
        // the row behind this button opens the drawer on click, and must not
        event.stopPropagation();
        if (this.isEoiActionBusy) return;
        const id = event.currentTarget?.dataset?.id;
        const action = event.currentTarget?.dataset?.action;
        // BP-058: releasing money asks first. Nothing runs until the broker presses Proceed.
        if (action === EOI_ACTION_CANCEL) {
            this.openEoiCancel(id);
            return;
        }
        if (!id || (action !== EOI_ACTION_RESEND && action !== EOI_ACTION_NEW)) return;

        this.isEoiActionBusy = true;
        this.eoiActionBusyId = id;
        try {
            if (action === EOI_ACTION_NEW) {
                // BP-060: a second payment request, with its own number. Apex sends nothing itself -
                // the new record's own creation message carries the link, so the customer gets one.
                const created = await renewBrokerLink({ paymentId: id });
                const newName = created && created.paymentName ? created.paymentName : '';
                this.showToast(
                    'New link sent',
                    newName
                        ? `New payment request ${newName} has been sent to the customer.`
                        : 'A new payment request has been sent to the customer.',
                    'success'
                );
                // the spent row loses its action and the new one arrives, so the list is re-read
                await this.loadEoiRecords(true);
                this.flashEoiRow(created && created.paymentId);
            } else {
                const name = await resendBrokerLink({ paymentId: id });
                this.showToast(
                    'Link sent',
                    name
                        ? `Payment request ${name} has been sent to the customer.`
                        : 'The payment request has been sent to the customer.',
                    'success'
                );
                await this.loadEoiRecords(true);
            }
        } catch (error) {
            this.showToast(
                action === EOI_ACTION_NEW ? 'Unable to send new link' : 'Unable to send link',
                this.reduceError(error) || 'Something went wrong. Please try again.',
                'error'
            );
        } finally {
            this.isEoiActionBusy = false;
            this.eoiActionBusyId = '';
        }
    }

    /* BP-060: the new request is already at the top of the table, because the list is ordered by
       payment number. It lifts once so the broker can see which row is the one they just created.
       The colours are the theme's own accent tokens and the stylesheet drops the movement under
       prefers-reduced-motion, so nothing new has to be maintained for light, dark or phone. */
    flashEoiRow(paymentRecordId) {
        this.clearEoiFlashTimer();
        if (!paymentRecordId) {
            this.flashPaymentId = '';
            return;
        }
        this.flashPaymentId = paymentRecordId;
        this._eoiFlashTimer = window.setTimeout(() => {
            this.flashPaymentId = '';
            this._eoiFlashTimer = null;
        }, 2600);
    }

    clearEoiFlashTimer() {
        if (this._eoiFlashTimer) {
            window.clearTimeout(this._eoiFlashTimer);
            this._eoiFlashTimer = null;
        }
    }

    // ── BP-058: the cancel confirmation ──────────────────────────────────────

    get isEoiCancelOpen() {
        return Boolean(this.eoiCancelRow);
    }

    openEoiCancel(paymentRecordId) {
        const row = (this.eoiRows || []).find((item) => item.paymentRecordId === paymentRecordId);
        // only a row that is actually offering Cancel can open the dialog
        if (!row || row.rowAction !== EOI_ACTION_CANCEL) return;
        this.eoiCancelRow = {
            id: row.paymentRecordId,          // the payment the server will act on

            paymentName: row.paymentNameLabel,
            /* BP-062: the EOI the broker is cancelling, read off the row that is already on screen.
               eoiNumberLabel is the gated one - it is blank (a placeholder) until the money is held
               or taken, so a number can never appear here before it exists. */
            eoiNumber: row.eoiNumberLabel,
            customerName: row.customerName,
            amountLabel: row.amountLabel
        };
        this._shouldFocusEoiCancel = true;
    }

    handleEoiCancelDismiss() {
        if (this.isEoiActionBusy) return;         // never disappear mid-call
        this.eoiCancelRow = null;
    }

    // the dialog sits on a scrim that closes on click; a click inside it must not
    stopEoiCancelBubble(event) {
        event.stopPropagation();
    }

    handleEoiCancelKeydown(event) {
        if (event.key === 'Escape' || event.key === 'Esc') {
            event.stopPropagation();
            this.handleEoiCancelDismiss();
        }
    }

    async handleEoiCancelConfirm() {
        const row = this.eoiCancelRow;
        if (!row || this.isEoiActionBusy) return;
        this.isEoiActionBusy = true;
        this.eoiActionBusyId = row.id;
        try {
            const name = await cancelBrokerPayment({ paymentId: row.id });
            this.eoiCancelRow = null;
            this.showToast('Cancelled', `Payment request ${name || row.paymentName} has been cancelled.`, 'success');
            await this.loadEoiRecords(true);
        } catch (error) {
            this.showToast(
                'Unable to cancel',
                this.reduceError(error) || 'The payment could not be cancelled. Please try again.',
                'error'
            );
        } finally {
            this.isEoiActionBusy = false;
            this.eoiActionBusyId = '';
        }
    }

    handleEoiRowKeydown(event) {
        if (this.isEoiActionBusy) return;
        if (event.key !== 'Enter' && event.key !== ' ' && event.key !== 'Spacebar') return;
        if (event.target !== event.currentTarget) return;
        event.preventDefault();
        const id = event.currentTarget.dataset.id;
        if (id) this.openEoiDrawer(id);
    }

    get selectedEoi() {
        return this.eoiRows.find((eoi) => eoi.id === this.selectedEoiId) || null;
    }

    async handleOpenEoiForm() {
        if (this.isEoiActionBusy) return;
        if (!this.canCreateEoi) return;
        this.activeTab = 'eoi';
        this.eoiStep = 'customer';
        this.eoiCustomer = emptyEoiCustomer();
        this.eoiEmailCheck = { value: '', status: '', message: '' };
        this.eoiMobileCheck = { value: '', status: '', message: '' };
        this.eoiSubmitPhase = '';
        this.eoiSubmittedLinks = [];
        this.eoiSubmittedOpportunityId = '';
        this.eoiDoneArmed = false;
        this.isEoiRetryingLinks = false;
        this.eoiInterests = [emptyEoiInterest(0)];
        this.openEoiInterestKey = this.eoiInterests[0].key;
        this.resetVerification();
        this.clearEoiFormMessage();
        this.drawerMode = 'eoi-form';
        this._shouldFocusDrawer = true;
        await this.ensureEoiSetup();
    }

    async ensureEoiSetup() {
        const promises = [];
        if (!this.eoiPicklistsLoaded) {
            promises.push(getEoiPicklistValues().then((result) => {
                this.eoiPicklists = {
                    residentOptions: this.toOptions(result?.residentStatus || []),
                    countryOptions: this.toOptions(result?.country || []),
                    nationalityOptions: this.toOptions(result?.nationality || [])
                };
                this.eoiPicklistsLoaded = true;
            }));
        }
        if (!this.eoiRangeCatalog.length) {
            promises.push(getBrokerRangeOptions().then((result) => {
                this.eoiRangeCatalog = (result || []).filter((row) => row && row.projectId && row.unitType && row.bedrooms);
                this.eoiProjectOptions = this.eoiCatalogProjects;
            }));
        }
        if (promises.length) {
            try {
                await Promise.all(promises);
            } catch (error) {
                this.setEoiFormMessage(this.reduceError(error), 'error');
            }
        }
        // whatever the catalogue settles on its own is filled in before the broker sees the step
        this.eoiInterests.forEach((_row, index) => this.resolveEoiInterest(index));
    }

    /* BP-054: the three lists the form offers, read straight off the catalogue. Distinct, in the
       order the org sent them, and never mutated. */
    get eoiCatalogProjects() {
        const seen = new Map();
        this.eoiRangeCatalog.forEach((row) => {
            if (row.projectId && !seen.has(row.projectId)) seen.set(row.projectId, row.projectName || '');
        });
        return [...seen.entries()].map(([value, label]) => ({ value, label: label || value }));
    }

    eoiCatalogUnitTypes(projectId) {
        const seen = [];
        this.eoiRangeCatalog.forEach((row) => {
            if (row.projectId === projectId && row.unitType && !seen.includes(row.unitType)) seen.push(row.unitType);
        });
        return seen.map((value) => ({ value, label: value }));
    }

    eoiCatalogBedrooms(projectId, unitType) {
        const seen = [];
        this.eoiRangeCatalog.forEach((row) => {
            if (row.projectId === projectId && row.unitType === unitType && row.bedrooms && !seen.includes(row.bedrooms)) {
                seen.push(row.bedrooms);
            }
        });
        return seen.map((value) => ({ value, label: value }));
    }

    /* BP-054: one pass settles a whole interest. A list with exactly one answer is chosen for the
       broker and its field locked; anything that no longer exists in the catalogue is cleared, so a
       stale pairing cannot survive a change above it. Phase and typology are not asked for at all -
       the server reads them off the range row it matches. No round trip, so nothing can race. */
    resolveEoiInterest(index) {
        const row = this.eoiInterests[index];
        if (!row) return;
        const next = { ...row };

        const projects = this.eoiCatalogProjects;
        const project = projects.find((option) => option.value === next.selectedProjectId);
        if (projects.length === 1) {
            next.selectedProjectId = projects[0].value;
            next.selectedProjectName = projects[0].label;
        } else if (!project) {
            next.selectedProjectId = '';
            next.selectedProjectName = '';
        } else {
            next.selectedProjectName = project.label;
        }

        const unitTypes = this.eoiCatalogUnitTypes(next.selectedProjectId);
        if (unitTypes.length === 1) next.selectedUnitType = unitTypes[0].value;
        else if (!unitTypes.some((option) => option.value === next.selectedUnitType)) next.selectedUnitType = '';

        const bedrooms = this.eoiCatalogBedrooms(next.selectedProjectId, next.selectedUnitType);
        if (!bedrooms.some((option) => option.value === next.selectedBedrooms)) next.selectedBedrooms = '';

        const match = this.eoiRangeCatalog.find((option) => option.projectId === next.selectedProjectId
            && option.unitType === next.selectedUnitType && option.bedrooms === next.selectedBedrooms);
        next.matchedRangeId = match ? match.rangeId : '';
        next.matchedAmount = match ? Number(match.amount) || 0 : 0;
        // BP-054: neither is on the form any more, and neither is required by the server.
        next.selectedPhaseId = '';
        next.selectedUnitTypology = '';

        this.eoiInterests = this.eoiInterests.map((current, position) => (position === index ? next : current));
        this.recalculateEoiAmount(index);
    }

    // ---- EOI customer step: type, residency, contact checks ----

    get eoiCustomerTypeOptions() {
        return EOI_CUSTOMER_TYPES.map((option) => ({
            ...option,
            className: option.value === this.eoiCustomer.customerType ? 'segmented-pill segmented-pill--active' : 'segmented-pill',
            ariaPressed: option.value === this.eoiCustomer.customerType
        }));
    }

    get isEoiOrganizationCustomer() {
        return this.eoiCustomer.customerType === 'Organization';
    }

    get isEoiIndividualCustomer() {
        return !this.isEoiOrganizationCustomer;
    }

    /** Identity fields follow residency and stay hidden until it is chosen. */
    get isEoiResidentCustomer() {
        return this.isEoiIndividualCustomer && this.isResidentStatus(this.eoiCustomer.residentStatus);
    }

    get isEoiNonResidentCustomer() {
        return this.isEoiIndividualCustomer && this.isNonResidentStatus(this.eoiCustomer.residentStatus);
    }

    /* BP-053: the country is only ever set to a value the picklist really carries. If the org
       renames or retires it, this returns '' and the field simply stays editable - never locked
       on a value the list cannot show. */
    get eoiResidentCountryValue() {
        const options = this.eoiPicklists.countryOptions || [];
        const exact = options.find((option) => option.value === EOI_UAE_COUNTRY);
        if (exact) return exact.value;
        const loose = options.find((option) => /^\s*(united\s+arab\s+emirates|u\.?a\.?e\.?)\s*$/i.test(option.value || ''));
        return loose ? loose.value : '';
    }

    /** Read-only only while the residency actually implies it, and only for an Individual. */
    /* BP-063: a Resident's country of residence is decided for them - United Arab Emirates, filled in
       and locked by BP-053 - so the row is hidden instead of shown greyed out. It comes BACK the moment
       that value cannot be resolved from the live picklist, because the field is still required and the
       broker must be able to answer it. Hiding changes nothing that is sent: the value lives in
       eoiCustomer, not in the DOM, and createEoiLead still receives it. */
    get showEoiCountryField() {
        return !this.isEoiCountryLocked;
    }

    get isEoiCountryLocked() {
        return this.isEoiResidentCustomer && Boolean(this.eoiResidentCountryValue);
    }

    get showEoiEmailStatus() {
        return ['checking', 'valid', 'invalid'].includes(this.eoiEmailCheck.status);
    }

    get isEoiEmailChecking() {
        return this.eoiEmailCheck.status === 'checking';
    }

    get eoiEmailStatusText() {
        return this.leadCheckText(this.eoiEmailCheck);
    }

    get eoiEmailStatusClass() {
        return this.leadCheckClass(this.eoiEmailCheck);
    }

    get showEoiMobileStatus() {
        return ['checking', 'valid', 'invalid'].includes(this.eoiMobileCheck.status);
    }

    get isEoiMobileChecking() {
        return this.eoiMobileCheck.status === 'checking';
    }

    get eoiMobileStatusText() {
        return this.leadCheckText(this.eoiMobileCheck);
    }

    get eoiMobileStatusClass() {
        return this.leadCheckClass(this.eoiMobileCheck);
    }

    handleEoiCustomerType(event) {
        const type = event.currentTarget.dataset.type;
        if (!type || type === this.eoiCustomer.customerType) return;
        // Only the shared contact fields survive a type switch, so a value typed
        // for the other type can never reach createLead.
        const next = emptyEoiCustomer();
        EOI_CUSTOMER_SHARED_FIELDS.forEach((field) => {
            next[field] = this.eoiCustomer[field];
        });
        next.customerType = type;
        this.eoiCustomer = next;
        this.clearEoiFormMessage();
    }

    /** Emirates ID types itself into 784-XXXX-XXXXXXX-X; the caret stays on the
     *  digit it was on. The hyphenated value is what is stored and matched. */
    handleEoiEmiratesIdInput(event) {
        const formatted = applyEmiratesIdMask(event.target);
        if (formatted === this.eoiCustomer.emiratesId) return;
        this.eoiCustomer = { ...this.eoiCustomer, emiratesId: formatted };
        this.clearEoiFormMessage();
    }

    handleEoiCustomerChange(event) {
        const field = event.target.dataset.field;
        if (!field) return;
        const value = event.target.value || '';
        const next = { ...this.eoiCustomer, [field]: value };
        // Residency decides which identity field is shown; clear both so a
        // hidden one never carries a stale value.
        if (field === 'residentStatus') {
            next.emiratesId = '';
            next.passportNumber = '';
            /* BP-053, client 11 Sep 2026: a Resident gets the UAE filled in and the field locked.
               Any other answer hands the field back empty, so a country chosen for the previous
               answer can never be submitted for this one. */
            next.country = this.isResidentStatus(value) ? this.eoiResidentCountryValue : '';
        }
        this.eoiCustomer = next;
        // A changed contact value drops its last result until blur checks it again.
        if (field === 'email' && value.trim() !== this.eoiEmailCheck.value) {
            this.eoiEmailCheck = { value: '', status: '', message: '' };
        }
        if (field === 'mobile' && value.trim() !== this.eoiMobileCheck.value) {
            this.eoiMobileCheck = { value: '', status: '', message: '' };
        }
        this.clearEoiFormMessage();
    }

    /* Same three guardrails as the lead form: local format first, never the
       same value twice, and a result that arrives for a superseded value is
       dropped. */
    async handleEoiEmailBlur(event) {
        const email = (event.target.value || '').trim();
        if (!email) {
            this.eoiEmailCheck = { value: '', status: '', message: '' };
            return;
        }
        if (email === this.eoiEmailCheck.value && this.eoiEmailCheck.status) return;
        if (!EMAIL_PATTERN.test(email)) {
            this.eoiEmailCheck = { value: email, status: 'invalid', message: 'Enter a valid email address.' };
            return;
        }
        this.eoiEmailCheck = { value: email, status: 'checking', message: '' };
        try {
            await validateEmail({ email });
            if (this.eoiEmailCheck.value !== email) return;
            this.eoiEmailCheck = { value: email, status: 'valid', message: '' };
        } catch (error) {
            if (this.eoiEmailCheck.value !== email) return;
            this.eoiEmailCheck = { value: email, status: 'invalid', message: this.reduceError(error) || 'Email failed validation.' };
        }
    }

    async handleEoiMobileBlur(event) {
        const raw = (event.target.value || '').trim();
        if (!raw) {
            this.eoiMobileCheck = { value: '', status: '', message: '' };
            return;
        }
        if (raw === this.eoiMobileCheck.value && this.eoiMobileCheck.status) return;
        const mobile = this.normalizeLeadMobileForSave(raw);
        if (!LEAD_PHONE_PATTERN.test(mobile)) {
            this.eoiMobileCheck = { value: raw, status: 'invalid', message: EOI_MOBILE_FORMAT_MESSAGE };
            return;
        }
        this.eoiMobileCheck = { value: raw, status: 'checking', message: '' };
        try {
            const isValid = await validatePhone({ phone: mobile });
            if (this.eoiMobileCheck.value !== raw) return;
            this.eoiMobileCheck = isValid === true
                ? { value: raw, status: 'valid', message: '' }
                : { value: raw, status: 'invalid', message: EOI_MOBILE_FAILED_MESSAGE };
        } catch (error) {
            if (this.eoiMobileCheck.value !== raw) return;
            this.eoiMobileCheck = { value: raw, status: 'invalid', message: this.reduceError(error) || 'Mobile number failed validation.' };
        }
    }

    /** Required and format rules for the selected customer type. */
    getEoiCustomerValidation() {
        const customer = this.eoiCustomer;
        const has = (field) => Boolean((customer[field] || '').trim());
        const missing = [];
        const need = (field, label) => {
            if (!has(field)) missing.push({ field, label });
        };
        if (this.isEoiOrganizationCustomer) {
            need('company', 'Organization name');
            need('tradeLicenseNumber', 'Trade licence number');
            need('firstName', 'Authorised contact first name');
            need('lastName', 'Authorised contact last name');
            need('email', 'Authorised contact email');
            need('mobile', 'Authorised contact mobile');
        } else {
            need('firstName', 'First name');
            need('lastName', 'Last name');
            need('email', 'Email');
            need('mobile', 'Mobile');
            need('residentStatus', 'Resident status');
            need('nationality', 'Nationality');
            need('country', 'Country of residence');
            if (this.isEoiResidentCustomer) need('emiratesId', 'Emirates ID');
            if (this.isEoiNonResidentCustomer) need('passportNumber', 'Passport number');
        }
        const format = [];
        if (has('email') && !EMAIL_PATTERN.test(customer.email.trim())) {
            format.push({ field: 'email', message: 'Enter a valid email address.' });
        }
        if (has('mobile') && !LEAD_PHONE_PATTERN.test(this.normalizeLeadMobileForSave(customer.mobile))) {
            format.push({ field: 'mobile', message: EOI_MOBILE_FORMAT_MESSAGE });
        }
        if (has('emiratesId') && !EMIRATES_ID_PATTERN.test(customer.emiratesId.trim())) {
            format.push({ field: 'emiratesId', message: 'Invalid Emirates ID. Format should be: 784-1234-1234567-1.' });
        }
        return { missing, format };
    }

    /** Next never trusts blur timing: a contact value that has not passed its
     *  check yet is checked here, and an invalid or failed check blocks the step. */
    async ensureEoiContactChecks() {
        const email = this.eoiCustomer.email.trim();
        if (this.eoiEmailCheck.value !== email || this.eoiEmailCheck.status !== 'valid') {
            this.eoiEmailCheck = { value: email, status: 'checking', message: '' };
            try {
                await validateEmail({ email });
                this.eoiEmailCheck = { value: email, status: 'valid', message: '' };
            } catch (error) {
                this.eoiEmailCheck = { value: email, status: 'invalid', message: this.reduceError(error) || 'Email failed validation.' };
            }
        }
        const rawMobile = this.eoiCustomer.mobile.trim();
        if (this.eoiMobileCheck.value !== rawMobile || this.eoiMobileCheck.status !== 'valid') {
            this.eoiMobileCheck = { value: rawMobile, status: 'checking', message: '' };
            try {
                const isValid = await validatePhone({ phone: this.normalizeLeadMobileForSave(rawMobile) });
                this.eoiMobileCheck = isValid === true
                    ? { value: rawMobile, status: 'valid', message: '' }
                    : { value: rawMobile, status: 'invalid', message: EOI_MOBILE_FAILED_MESSAGE };
            } catch (error) {
                this.eoiMobileCheck = { value: rawMobile, status: 'invalid', message: this.reduceError(error) || 'Mobile number failed validation.' };
            }
        }
        return this.eoiEmailCheck.status === 'valid' && this.eoiMobileCheck.status === 'valid';
    }

    async handleCreateEoiLead() {
        if (this.isEoiSaving) return;
        const { missing, format } = this.getEoiCustomerValidation();
        if (missing.length) {
            this.setEoiFormMessage(`Required: ${missing.map((item) => item.label).join(', ')}.`, 'error');
            this.focusFirstInvalidLeadField(missing);
            return;
        }
        if (format.length) {
            this.setEoiFormMessage(format.map((item) => item.message).join(' '), 'error');
            this.focusFirstInvalidLeadField(format);
            return;
        }
        this.isEoiSaving = true;
        this.setEoiFormMessage('Checking contact details...', 'info');
        try {
            const contactsValid = await this.ensureEoiContactChecks();
            if (!contactsValid) {
                const detail = [this.eoiEmailCheck.message, this.eoiMobileCheck.message].filter(Boolean).join(' ');
                this.setEoiFormMessage(detail || 'Contact details failed validation.', 'error');
                return;
            }
            this.setEoiFormMessage('Saving customer...', 'info');
            const customer = this.eoiCustomer;
            const isOrganization = this.isEoiOrganizationCustomer;
            // Same eleven arguments as before. The fields the other type does
            // not show are sent blank, so Apex routes on Company exactly as today.
            const result = await createEoiLead({
                firstName: customer.firstName.trim(),
                lastName: customer.lastName.trim(),
                email: customer.email.trim(),
                mobile: this.normalizeLeadMobileForSave(customer.mobile),
                residentStatus: isOrganization ? '' : customer.residentStatus,
                country: customer.country,
                nationality: isOrganization ? '' : customer.nationality,
                emiratesId: customer.emiratesId.trim(),
                passportNumber: customer.passportNumber.trim(),
                company: isOrganization ? customer.company.trim() : '',
                tradeLicenseNumber: isOrganization ? customer.tradeLicenseNumber.trim() : ''
            });
            if (!result?.success) {
                throw new Error((result?.pageErrors || []).join(', ') || 'Lead creation failed.');
            }
            this.eoiCustomer = { ...this.eoiCustomer, leadId: result.leadId };
            await this.refreshConsoleData({
                leads: true,
                opportunities: false,
                eoi: false,
                units: false
            });
            this.notifyConsoleMutation('lead');
            this.scheduleDeferredConsoleRefresh({
                leads: true,
                opportunities: false,
                eoi: false,
                units: false
            }, 'lead');
            this.eoiStep = 'verification';
            this.setEoiFormMessage('Customer saved. Send a verification code to continue.', 'success');
        } catch (error) {
            this.setEoiFormMessage(this.reduceError(error), 'error');
        } finally {
            this.isEoiSaving = false;
        }
    }

    handleSelectVerificationChannel(event) {
        if (this.isVerificationLocked) return;
        const channel = findVerificationChannel(event.currentTarget.dataset.method);
        if (!channel || channel.comingSoon) return;
        this.verificationMethod = channel.key;
        this.clearEoiFormMessage();
    }

    async handleSendVerificationCode() {
        if (this.isSendCodeDisabled) return;
        await this.sendVerificationCode(this.verificationMethod, false);
    }

    handleChangeVerificationChannel() {
        if (this.isChangeChannelDisabled) return;
        this.clearResendCooldownTimer();
        this.clearExpiryTimer();
        this.verificationRequestId = '';
        this.verificationMaskedTarget = '';
        this.verificationDigits = this.getBlankVerificationDigits();
        this.verificationCodeError = '';
        this.verificationExpired = false;
        this.verificationFailed = false;
        this.verificationExpiresAt = null;
        this.verificationExpirySeconds = 0;
        this.resendAvailableAt = null;
        this.resendCooldownSeconds = 0;
        this.maxResendReached = false;
        this.clearEoiFormMessage();
    }

    async sendVerificationCode(method, isFresh) {
        const channel = findVerificationChannel(method);
        if (!channel || channel.comingSoon) return;
        const target = channel.key === 'sms' ? this.eoiCustomer.mobile : this.eoiCustomer.email;
        if (!target) {
            this.setEoiFormMessage(channel.key === 'sms' ? 'Customer mobile is required.' : 'Customer email is required.', 'error');
            return;
        }
        this.verificationMethod = channel.key;
        this.verificationDigits = this.getBlankVerificationDigits();
        this.verificationCodeError = '';
        this.isSendingVerification = true;
        this.clearEoiFormMessage();
        try {
            const result = await startVerification({
                request: {
                    channel: channel.channel,
                    target,
                    context: 'EOI_HOME',
                    contextKey: this.eoiInterests[0]?.selectedProjectId || null
                }
            });
            if (!result || !result.verificationRequestId) {
                throw new Error('Verification could not be started.');
            }
            this.verificationRequestId = result.verificationRequestId;
            this.verificationMaskedTarget = result.maskedTarget || this.maskVerificationTarget(channel.key);
            this.verificationExpired = false;
            this.verificationFailed = false;
            this.maxResendReached = false;
            this.startResendCooldown(result.resendAvailableAt);
            this.startExpiryCountdown(result.expiresAt);
            this.setEoiFormMessage(`${channel.label}: ${result.message || (isFresh ? 'Verification code resent.' : 'Verification code sent.')}`, 'success');
            this.focusVerificationDigit(0);
        } catch (error) {
            this.setEoiFormMessage(this.reduceError(error), 'error');
        } finally {
            this.isSendingVerification = false;
        }
    }

    handleVerificationCodeInput(event) {
        const index = Number(event.currentTarget.dataset.otpIndex);
        const value = (event.target.value || '').replace(/\D/g, '').slice(-1);
        event.target.value = value;
        this.setVerificationDigit(index, value);
        if (value && index < VERIFICATION_CODE_LENGTH - 1) {
            this.focusVerificationDigit(index + 1);
        }
    }

    handleVerificationCodeKeydown(event) {
        const index = Number(event.currentTarget.dataset.otpIndex);
        if (event.key === 'Backspace' && !event.currentTarget.value && index > 0) {
            event.preventDefault();
            this.setVerificationDigit(index - 1, '');
            this.focusVerificationDigit(index - 1);
        } else if (event.key === 'ArrowLeft' && index > 0) {
            event.preventDefault();
            this.focusVerificationDigit(index - 1);
        } else if (event.key === 'ArrowRight' && index < VERIFICATION_CODE_LENGTH - 1) {
            event.preventDefault();
            this.focusVerificationDigit(index + 1);
        } else if (event.key === 'Enter') {
            event.preventDefault();
            if (!this.isVerifyDisabled) {
                this.handleVerifyCode();
            }
        }
    }

    handleVerificationCodePaste(event) {
        const text = String(event.clipboardData?.getData('text') || '').replace(/\D/g, '').slice(0, VERIFICATION_CODE_LENGTH);
        if (!text) return;
        event.preventDefault();
        const digits = this.getBlankVerificationDigits();
        text.split('').forEach((char, index) => {
            digits[index].value = char;
        });
        this.verificationDigits = digits;
        this.verificationCodeError = '';
        this.focusVerificationDigit(Math.min(text.length, VERIFICATION_CODE_LENGTH - 1));
    }

    setVerificationDigit(index, value) {
        this.verificationDigits = this.verificationDigits.map((digit) =>
            digit.index === index ? { ...digit, value } : digit
        );
        if (this.verificationCodeError) {
            this.verificationCodeError = '';
        }
    }

    focusVerificationDigit(index) {
        scheduleFrame(() => {
            const input = this.template.querySelector(`input[data-otp-index="${index}"]`);
            if (input) input.focus();
        });
    }

    async handleVerifyCode() {
        if (this.isVerifyDisabled) return;
        const code = this.verificationCode;
        this.isVerifyingCode = true;
        this.verificationCodeError = '';
        this.clearEoiFormMessage();
        try {
            const result = await verifyCode({ verificationRequestId: this.verificationRequestId, code });
            if (result && result.status === 'Verified') {
                this.verificationCompleted = true;
                this.clearResendCooldownTimer();
                this.clearExpiryTimer();
                this.eoiStep = 'interests';
                this.setEoiFormMessage('Verification complete. Add interest details to submit EOI.', 'success');
                return;
            }
            if (result && result.status === 'Failed') {
                this.verificationFailed = true;
            }
            this.verificationDigits = this.getBlankVerificationDigits();
            this.verificationCodeError = result?.message || 'Verification was not completed.';
            this.focusVerificationDigit(0);
        } catch (error) {
            const message = this.reduceError(error);
            if (this.isDeadVerificationMessage(message)) {
                this.verificationFailed = true;
            }
            this.verificationDigits = this.getBlankVerificationDigits();
            this.verificationCodeError = message;
        } finally {
            this.isVerifyingCode = false;
        }
    }

    async handleVerificationResend() {
        if (this.isResendDisabled) return;
        if (this.needsFreshVerification) {
            await this.sendVerificationCode(this.verificationMethod, true);
            return;
        }
        this.isResendingVerification = true;
        this.verificationCodeError = '';
        this.clearEoiFormMessage();
        try {
            const result = await resendVerification({ verificationRequestId: this.verificationRequestId });
            this.verificationDigits = this.getBlankVerificationDigits();
            this.verificationMaskedTarget = result?.maskedTarget || this.verificationMaskedTarget;
            this.verificationExpired = false;
            this.startResendCooldown(result?.resendAvailableAt);
            this.startExpiryCountdown(result?.expiresAt);
            this.setEoiFormMessage(`${this.verificationMethodLabel}: ${result?.message || 'Verification code resent.'}`, 'success');
            this.focusVerificationDigit(0);
        } catch (error) {
            const message = this.reduceError(error);
            if (message.toLowerCase().includes('maximum resend count reached')) {
                this.maxResendReached = true;
                this.verificationFailed = true;
            } else if (this.isDeadVerificationMessage(message)) {
                this.verificationFailed = true;
            }
            this.setEoiFormMessage(message, 'error');
        } finally {
            this.isResendingVerification = false;
        }
    }

    // VerificationService marks the request Expired / Failed / not pending;
    // after any of these only a fresh startVerification can continue.
    isDeadVerificationMessage(message) {
        const text = String(message || '').toLowerCase();
        return text.includes('expired') || text.includes('not pending') || text.includes('maximum verification attempts') || text.includes('not found');
    }

    maskVerificationTarget(key) {
        return key === 'sms'
            ? maskVerificationPhone(this.eoiCustomer.mobile)
            : maskVerificationEmail(this.eoiCustomer.email);
    }

    async handleEoiInterestChange(event) {
        const index = Number(event.target.dataset.index);
        const field = event.target.dataset.field;
        const value = event.target.value || '';
        if (Number.isNaN(index) || !field) return;

        const rows = this.eoiInterests.map((row, rowIndex) =>
            rowIndex === index ? { ...row, [field]: value } : row
        );
        this.eoiInterests = rows;
        this.clearEoiFormMessage();

        if (field === 'numberOfUnits') this.recalculateEoiAmount(index);
        else this.resolveEoiInterest(index);
    }

    recalculateEoiAmount(index) {
        const row = this.eoiInterests[index];
        if (!row) return;
        const units = Math.max(1, Number(row.numberOfUnits) || 1);
        const total = units * (Number(row.matchedAmount) || 0);
        this.updateEoiInterest(index, { eoiAmountLabel: this.formatCurrency(total) });
    }

    updateEoiInterest(index, patch) {
        this.eoiInterests = this.eoiInterests.map((row, rowIndex) =>
            rowIndex === index ? { ...row, ...patch } : row
        );
    }

    handleAddEoiInterest() {
        const added = emptyEoiInterest(this.eoiInterests.length);
        this.eoiInterests = [...this.eoiInterests, added];
        this.openEoiInterestKey = added.key;
        this.clearEoiFormMessage();
        // BP-054: the locked fields are filled in the moment the card appears
        this.resolveEoiInterest(this.eoiInterests.length - 1);
    }

    /* One interest shows its fields at a time, so several fit without scrolling.
       Tapping the open one folds it; tapping a folded one opens it and folds the
       rest. Nothing else about the interest changes. */
    handleToggleEoiInterest(event) {
        const key = event.currentTarget.dataset.key;
        if (!key) return;
        this.openEoiInterestKey = this.openEoiInterestKey === key ? '' : key;
    }

    handleRemoveEoiInterest(event) {
        const index = Number(event.currentTarget.dataset.index);
        if (Number.isNaN(index) || this.eoiInterests.length === 1) return;
        const removed = this.eoiInterests[index];
        this.eoiInterests = this.eoiInterests.filter((_row, rowIndex) => rowIndex !== index);
        /* BP-051: removing the open card used to leave every card folded and nothing to fill
           in. The row that takes its place opens instead. */
        if (removed && this.openEoiInterestKey === removed.key) {
            const next = this.eoiInterests[index] || this.eoiInterests[this.eoiInterests.length - 1];
            this.openEoiInterestKey = next ? next.key : '';
        }
        this.clearEoiFormMessage();
    }

    async handleSubmitEoi() {
        if (this.isEoiSaving) return;
        if (!this.eoiCustomer.leadId) {
            this.setEoiFormMessage('Create the customer lead before submitting EOI.', 'error');
            return;
        }
        if (!this.verificationCompleted) {
            this.setEoiFormMessage('Verify the customer before submitting EOI.', 'error');
            return;
        }
        const invalidIndex = this.eoiInterests.findIndex((row) => !this.isEoiInterestComplete(row));
        if (invalidIndex >= 0) {
            // BP-051: open the card the message is about, so the broker is not sent hunting.
            this.openEoiInterestKey = this.eoiInterests[invalidIndex].key;
            this.setEoiFormMessage(`Complete all fields for interest ${invalidIndex + 1}.`, 'error');
            return;
        }

        // BP-041: Submit prepares the customer (lead conversion, one Opportunity) and sends one payment request
        // per interest. No EOI is created here: the shared Checkout rail creates it once the payment is authorized.
        const interests = this.eoiInterests.map((row) => ({
            projectId: row.selectedProjectId,
            phaseId: row.selectedPhaseId,
            unitType: row.selectedUnitType,
            bedrooms: row.selectedBedrooms,
            unitTypology: row.selectedUnitTypology,
            numberOfUnits: Math.max(1, Number(row.numberOfUnits) || 1),
            remarks: row.remarks || ''
        }));

        this.isEoiSaving = true;
        this.eoiSubmitPhase = 'creating';
        this.clearEoiFormMessage();

        let opportunityId = '';
        try {
            const result = await prepareBrokerOpportunity({ leadId: this.eoiCustomer.leadId });
            if (!result?.success) {
                throw new Error((result?.pageErrors || []).join(', ') || 'The customer could not be prepared for payment.');
            }
            opportunityId = result.opportunityId || '';
            if (!opportunityId) {
                throw new Error('No opportunity was returned for the customer.');
            }
        } catch (error) {
            // Nothing was created: back to the form with the reason.
            this.eoiSubmitPhase = '';
            this.isEoiSaving = false;
            this.setEoiFormMessage(this.reduceError(error), 'error');
            return;
        }

        // From here the Opportunity exists; the drawer never returns to the form.
        this.eoiSubmittedOpportunityId = opportunityId;
        this.eoiDoneArmed = false;
        this.eoiSubmittedLinks = interests.map((interest, index) => this.buildSubmittedLink(index, this.eoiInterests[index], interest));
        await this.sendEoiPaymentLinks();

        this.eoiSubmitPhase = '';
        this.isEoiSaving = false;
        this.eoiStep = 'success';
        this.setEoiSubmitOutcomeMessage();

        try {
            await this.refreshConsoleData({
                leads: true,
                opportunities: true,
                eoi: true,
                salesOrders: Boolean(this.selectedOpportunityId)
            });
        } catch (error) {
            // The deferred refresh below retries; the submission itself has succeeded.
        }
        this.notifyConsoleMutation('eoi');
        this.scheduleDeferredConsoleRefresh({
            leads: true,
            opportunities: true,
            eoi: true,
            salesOrders: Boolean(this.selectedOpportunityId)
        }, 'eoi');
    }

    /* BP-054: the form asks for three things. Phase and typology left the form and are no longer
       required here or on the server; the matched range is still mandatory, so an interest is only
       complete once the org has actually priced it. */
    isEoiInterestComplete(row) {
        return Boolean(
            row &&
            row.selectedProjectId &&
            row.selectedUnitType &&
            row.selectedBedrooms &&
            row.matchedRangeId &&
            Number(row.numberOfUnits) >= 1
        );
    }

    buildSubmittedLink(index, row, interest) {
        const units = Math.max(1, Number(row?.numberOfUnits) || 1);
        const amountValue = units * (Number(row?.matchedAmount) || 0);
        const key = `interest-${index + 1}`;
        return {
            key,
            // the slot is part of the server's idempotency key: a Retry re-sends the same slot, two alike interests are two requests
            interestJson: JSON.stringify({ ...interest, slot: key }),
            // BP-054: the three fields the broker actually chose from.
            title: [row?.selectedProjectName, row?.selectedUnitType].filter(Boolean).join(' · ') || 'Interest',
            subtitle: row?.selectedBedrooms ? `${row.selectedBedrooms} BR` : '',
            amountValue,
            amountLabel: this.formatCurrency(amountValue),
            status: 'pending',
            paymentName: '',
            maskedEmail: '',
            maskedPhone: '',
            error: ''
        };
    }

    // One Checkout call at a time, in interest order. The Apex is idempotent per Opportunity + interest, so a
    // retry after a timeout returns the request that already exists instead of creating a second one.
    async sendEoiPaymentLinks() {
        for (const link of this.eoiSubmittedLinks) {
            if (link.status === 'sent') continue;
            try {
                const result = await createInterestLink({
                    opportunityId: this.eoiSubmittedOpportunityId,
                    interestJson: link.interestJson
                });
                if (!result?.success || !result.paymentName) {
                    throw new Error(result?.message || 'The payment request could not be created.');
                }
                const amountValue = result.amount != null ? Number(result.amount) : link.amountValue;
                this.patchSubmittedLink(link.key, {
                    status: 'sent',
                    paymentName: result.paymentName,
                    maskedEmail: result.maskedEmail || '',
                    maskedPhone: result.maskedPhone || '',
                    amountValue,
                    amountLabel: this.formatCurrency(amountValue),
                    error: ''
                });
            } catch (error) {
                this.patchSubmittedLink(link.key, { status: 'failed', error: this.reduceError(error) });
            }
        }
    }

    patchSubmittedLink(key, patch) {
        this.eoiSubmittedLinks = this.eoiSubmittedLinks.map((link) =>
            link.key === key ? { ...link, ...patch } : link
        );
    }

    async handleRetryEoiPaymentLinks() {
        if (this.isEoiRetryingLinks || !this.hasEoiLinkFailures) return;
        this.isEoiRetryingLinks = true;
        this.clearEoiFormMessage();
        this.eoiSubmittedLinks = this.eoiSubmittedLinks.map((link) =>
            link.status === 'failed' ? { ...link, status: 'pending', error: '' } : link
        );
        try {
            await this.sendEoiPaymentLinks();
        } finally {
            this.isEoiRetryingLinks = false;
        }
        this.setEoiSubmitOutcomeMessage();
    }

    setEoiSubmitOutcomeMessage() {
        const failed = this.eoiSubmittedLinks.filter((link) => link.status === 'failed').length;
        if (failed > 0) {
            this.setEoiFormMessage(`${failed} payment request${failed === 1 ? '' : 's'} could not be sent.`, 'error');
        } else {
            this.setEoiFormMessage('Payment requests have been sent to the customer.', 'success');
        }
    }

    // BP-041: with unsent requests, Done asks once - a closed drawer forgets them and the only way
    // back would be a brand-new submission for the same customer.
    handleEoiSubmitDone() {
        if (this.isEoiRetryingLinks) return;
        if (this.hasEoiLinkFailures && !this.eoiDoneArmed) {
            const failed = this.eoiSubmittedLinks.filter((link) => link.status === 'failed').length;
            this.eoiDoneArmed = true;
            this.setEoiFormMessage(`${failed} payment request${failed === 1 ? ' was' : 's were'} not sent. Retry, or click Close anyway to leave without ${failed === 1 ? 'it' : 'them'}.`, 'error');
            return;
        }
        this.closeDrawer();
    }

    get eoiDoneLabel() {
        return this.hasEoiLinkFailures && this.eoiDoneArmed ? 'Close anyway' : 'Done';
    }

    get isEoiCustomerStep() {
        return this.eoiStep === 'customer';
    }

    get isEoiVerificationStep() {
        return this.eoiStep === 'verification';
    }

    get isEoiInterestsStep() {
        return this.eoiStep === 'interests';
    }

    get isEoiSuccessStep() {
        return this.eoiStep === 'success';
    }

    get eoiPathStepIndex() {
        const key = this.isEoiCreating ? 'success' : this.eoiStep;
        return Math.max(0, EOI_PATH_STEPS.findIndex((step) => step.key === key));
    }

    get eoiPathSteps() {
        const currentIndex = this.eoiPathStepIndex;
        return EOI_PATH_STEPS.map((step, index) => {
            const isCompleted = index < currentIndex || this.isEoiSuccessStep;
            const isActive = index === currentIndex && !this.isEoiSuccessStep;
            const stateClass = isCompleted
                ? 'eoi-path__step eoi-path__step--completed'
                : isActive
                    ? 'eoi-path__step eoi-path__step--active'
                    : 'eoi-path__step';
            return {
                ...step,
                className: stateClass,
                marker: isCompleted ? '✓' : String(index + 1),
                ariaCurrent: isActive ? 'step' : null
            };
        });
    }

    get eoiPathFillStyle() {
        const maxIndex = EOI_PATH_STEPS.length - 1;
        const progress = maxIndex > 0 ? (this.eoiPathStepIndex / maxIndex) * 100 : 0;
        return `width: ${Math.min(100, Math.max(0, progress))}%`;
    }

    /* BP-051: these four boxes sit in a step the wizard tears down and rebuilds on every
       move, so they carry the selection on the option itself, the way the other 22 selects
       in this file already do. */
    get eoiResidentOptions() {
        return markSelectedOption(this.eoiPicklists.residentOptions, this.eoiCustomer.residentStatus);
    }

    get eoiCountryOptions() {
        return markSelectedOption(this.eoiPicklists.countryOptions, this.eoiCustomer.country);
    }

    get eoiNationalityOptions() {
        return markSelectedOption(this.eoiPicklists.nationalityOptions, this.eoiCustomer.nationality);
    }

    get isEoiCatalogUnavailable() {
        return this.isEoiInterestsStep && this.eoiPicklistsLoaded && !this.eoiRangeCatalog.length;
    }

    get eoiCatalogUnavailableMessage() {
        return 'No active broker EOI range setup is available in this org, so Project, Unit Type and Bedrooms cannot be selected yet.';
    }

    get isEoiCreating() {
        return this.eoiSubmitPhase === 'creating';
    }

    get isEoiCancelDisabled() {
        return this.isEoiCreating;
    }

    get showEoiCancelButton() {
        return !this.isEoiSuccessStep;
    }

    get allEoiInterestsComplete() {
        return this.eoiInterests.length > 0 && this.eoiInterests.every((row) => this.isEoiInterestComplete(row));
    }

    get firstIncompleteEoiInterestIndex() {
        return this.eoiInterests.findIndex((row) => !this.isEoiInterestComplete(row));
    }

    /* BP-051: a second card can only be started once the ones already on screen are complete,
       so a broker never ends up with two half-filled cards and a Submit that will not fire. */
    get isEoiAddInterestDisabled() {
        return this.isEoiCatalogUnavailable || this.isEoiCreating || !this.allEoiInterestsComplete;
    }

    get eoiAddInterestTitle() {
        if (this.isEoiCatalogUnavailable || this.isEoiCreating || this.allEoiInterestsComplete) {
            return 'Add another interest';
        }
        return `Complete interest ${this.firstIncompleteEoiInterestIndex + 1} first`;
    }

    get eoiInterestStackClass() {
        return this.isEoiCreating ? 'interest-stack interest-stack--locked' : 'interest-stack';
    }

    get eoiInterestTotal() {
        return this.eoiInterests.reduce((sum, row) => {
            if (!this.isEoiInterestComplete(row)) return sum;
            const units = Math.max(1, Number(row.numberOfUnits) || 1);
            return sum + units * (Number(row.matchedAmount) || 0);
        }, 0);
    }

    get eoiInterestSummary() {
        const count = this.eoiInterests.length;
        return {
            countLabel: `${count} interest${count === 1 ? '' : 's'}`,
            totalLabel: this.formatCurrency(this.eoiInterestTotal)
        };
    }

    get eoiCreatingCaption() {
        return `${this.eoiInterestSummary.countLabel} · ${this.eoiInterestSummary.totalLabel}`;
    }

    get eoiSubmittedLinkRows() {
        return this.eoiSubmittedLinks.map((link) => ({
            ...link,
            isSent: link.status === 'sent',
            isFailed: link.status === 'failed',
            isPending: link.status === 'pending',
            className: link.status === 'failed' ? 'eoi-link-row eoi-link-row--failed' : 'eoi-link-row'
        }));
    }

    get eoiSubmittedHeading() {
        const count = this.eoiSubmittedLinks.length;
        return count === 1 ? 'Payment request sent' : `${count} payment requests sent`;
    }

    // BP-041: the server prices every request from the EOI range; the total follows the rows, not the browser
    get eoiSubmittedTotalLabel() {
        const total = this.eoiSubmittedLinks.reduce((sum, link) => sum + (Number(link.amountValue) || 0), 0);
        return `Total ${this.formatCurrency(total)}`;
    }

    get hasEoiLinkFailures() {
        return this.eoiSubmittedLinks.some((link) => link.status === 'failed');
    }

    get hasEoiLinkSent() {
        return this.eoiSubmittedLinks.some((link) => link.status === 'sent');
    }

    get eoiSubmittedContactLine() {
        const sent = this.eoiSubmittedLinks.find((link) => link.status === 'sent');
        if (!sent) return '';
        const targets = [sent.maskedEmail, sent.maskedPhone].filter(Boolean);
        const count = this.eoiSubmittedLinks.filter((link) => link.status === 'sent').length;
        return `Payment request${count === 1 ? '' : 's'} sent to ${targets.join(' and ')}`;
    }

    get eoiRetryLinksLabel() {
        const failed = this.eoiSubmittedLinks.filter((link) => link.status === 'failed').length;
        return this.isEoiRetryingLinks ? 'Sending...' : `Retry ${failed === 1 ? 'request' : 'requests'}`;
    }

    get eoiInterestRows() {
        const projectOptions = this.eoiCatalogProjects;
        const isProjectDisabled = !projectOptions.length;
        const removeDisabled = this.eoiInterests.length === 1 || this.isEoiCreating;
        return this.eoiInterests.map((row, index) => {
            const unitTypeOptions = this.eoiCatalogUnitTypes(row.selectedProjectId);
            const bedroomOptions = this.eoiCatalogBedrooms(row.selectedProjectId, row.selectedUnitType);
            const isComplete = this.isEoiInterestComplete(row);
            const metaLine = isComplete
                ? [row.selectedProjectName, row.selectedUnitType,
                    row.selectedBedrooms ? `${row.selectedBedrooms} BR` : '']
                    .filter(Boolean).join(' · ')
                : 'Complete the selection to see the amount';
            const isOpen = row.key === this.openEoiInterestKey;
            return {
                ...row,
                displayIndex: index + 1,
                // BP-051: marked copies, so a card rebuilt by a collapse comes back filled in.
                projectOptions: markSelectedOption(projectOptions, row.selectedProjectId),
                unitTypeOptions: markSelectedOption(unitTypeOptions, row.selectedUnitType),
                bedroomOptions: markSelectedOption(bedroomOptions, row.selectedBedrooms),
                /* BP-054: a field with exactly one answer is filled in and read-only. It unlocks itself
                   the day the catalogue offers a second one, so nothing has to be changed in code. */
                isProjectDisabled: isProjectDisabled || projectOptions.length === 1,
                isUnitTypeDisabled: !row.selectedProjectId || !unitTypeOptions.length || unitTypeOptions.length === 1,
                isBedroomsDisabled: !row.selectedUnitType || !bedroomOptions.length,
                isComplete,
                isOpen,
                cardClass: isComplete ? 'interest-card interest-card--done' : 'interest-card',
                rowClass: isComplete ? 'interest-row interest-row--done' : 'interest-row',
                badgeClass: isComplete ? 'interest-card__badge interest-card__badge--done' : 'interest-card__badge',
                toggleTitle: isOpen ? 'Collapse' : 'Expand',
                badgeLabel: isComplete ? '✓' : String(index + 1),
                metaLine,
                amountClass: isComplete ? 'interest-card__amount' : 'interest-card__amount interest-card__amount--empty',
                amountLabel: isComplete ? row.eoiAmountLabel : 'AED -',
                isRemoveDisabled: removeDisabled
            };
        });
    }

    get verificationMethodLabel() {
        const channel = findVerificationChannel(this.verificationMethod);
        return channel ? channel.label : 'Email';
    }

    get eoiVerificationChannels() {
        const locked = this.isVerificationLocked;
        const sent = this.isVerificationSent;
        return VERIFICATION_CHANNELS.map((channel) => {
            const active = this.verificationMethod === channel.key;
            const showSent = active && sent;
            const showSpinner = active && this.isSendingVerification && !sent;
            const lockedOut = locked && !active;
            const soon = Boolean(channel.comingSoon);
            return {
                key: channel.key,
                label: channel.label,
                icon: channel.icon,
                destination: soon ? 'Not available yet' : this.maskVerificationTarget(channel.key),
                className: [
                    'verification-channel',
                    active ? 'verification-channel--active' : '',
                    showSent ? 'verification-channel--sent' : '',
                    lockedOut ? 'verification-channel--locked' : ''
                ].filter(Boolean).join(' '),
                ariaChecked: active ? 'true' : 'false',
                ariaDisabled: locked && active ? 'true' : 'false',
                disabled: soon || lockedOut,
                showSoon: soon,
                showSpinner,
                showSent,
                showRadio: !soon && !showSpinner && !showSent
            };
        });
    }

    get isVerificationSent() {
        return Boolean(this.verificationRequestId);
    }

    get isVerificationLocked() {
        return this.isSendingVerification || this.isVerificationSent || this.verificationCompleted;
    }

    get verificationHeading() {
        return this.isVerificationSent ? 'Enter the 6-digit code' : 'Send a verification code';
    }

    get showSendCodeButton() {
        return !this.isVerificationSent;
    }

    get isSendCodeDisabled() {
        return !this.verificationMethod || this.isSendingVerification || this.verificationCompleted;
    }

    get sendCodeButtonLabel() {
        const channel = findVerificationChannel(this.verificationMethod);
        return channel ? `Send code by ${channel.label}` : 'Send code';
    }

    get showVerificationCodePanel() {
        return this.isVerificationSent;
    }

    get verificationCodePanelClass() {
        return this.verificationCodeError ? 'verification-code verification-code--error' : 'verification-code';
    }

    get verificationCode() {
        return this.verificationDigits.map((digit) => digit.value).join('');
    }

    get needsFreshVerification() {
        return this.verificationExpired || this.verificationFailed;
    }

    get isCodeInputDisabled() {
        return this.isVerifyingCode || this.verificationCompleted || this.needsFreshVerification;
    }

    get isVerifyDisabled() {
        return !this.isVerificationSent
            || this.verificationCompleted
            || this.isVerifyingCode
            || this.isResendingVerification
            || this.isSendingVerification
            || this.needsFreshVerification
            || this.verificationCode.length !== VERIFICATION_CODE_LENGTH;
    }

    get isChangeChannelDisabled() {
        return this.verificationCompleted || this.isVerifyingCode || this.isResendingVerification || this.isSendingVerification;
    }

    get resendButtonLabel() {
        if (this.needsFreshVerification) return 'Send a new code';
        if (this.resendCooldownSeconds > 0) return `Resend in ${this.resendCooldownSeconds} s`;
        return 'Resend code';
    }

    get isResendDisabled() {
        if (!this.isVerificationSent || this.verificationCompleted) return true;
        if (this.isSendingVerification || this.isResendingVerification || this.isVerifyingCode) return true;
        if (this.needsFreshVerification) return false;
        return this.resendCooldownSeconds > 0;
    }

    get showResendSpinner() {
        return this.isResendingVerification || (this.isSendingVerification && this.isVerificationSent);
    }

    get showVerificationExpiry() {
        return this.isVerificationSent && Boolean(this.verificationExpiresAt) && !this.verificationFailed;
    }

    get verificationExpiryText() {
        return this.verificationExpired ? 'Code expired' : `Expires in ${formatCountdown(this.verificationExpirySeconds)}`;
    }

    get verificationExpiryClass() {
        return this.verificationExpired || this.verificationExpirySeconds < 60
            ? 'verification-expiry verification-expiry--low'
            : 'verification-expiry';
    }

    get unitRows() {
        return this.unitRecords.map((unit, index) => {
            const price = unit.TotalPrice__c != null ? unit.TotalPrice__c : unit.BasePrice__c;
            return {
                id: unit.Id,
                key: unit.Id || `unit-${index}`,
                name: unit.Name || 'Unit',
                phaseId: unit.Phase__c || '',
                phaseLabel: unit.Phase__r?.Name || 'Project',
                projectLabel: unit.Phase__r?.Project__r?.Name || unit.Phase__r?.Name || 'Project',
                statusLabel: unit.Status__c || 'Available',
                typeLabel: unit.UnitClassification__c || unit.Typology__c || 'Unit',
                bedroomsLabel: this.formatBedrooms(unit.Number_of_Bedrooms__c),
                priceLabel: this.formatCurrency(price),
                priceValue: Number(price) || 0,
                tourUrl: this.normalizeHttpUrl(unit.Masterplan_URL__c)
            };
        });
    }

    get isDrawerOpen() {
        return Boolean(this.drawerMode);
    }

    // The home New Lead fast path uses the same side-drawer presentation
    // as the workspace's own Add Lead (user direction, supersedes the
    // centred-modal treatment).
    get salesDrawerVariant() {
        return '';
    }

    get isLeadDetailDrawer() {
        return this.drawerMode === 'lead-detail' && this.selectedLead;
    }

    get isLeadFormDrawer() {
        return this.drawerMode === 'lead-form';
    }

    get isOpportunityDrawer() {
        return this.drawerMode === 'opportunity-detail' && this.selectedOpportunity;
    }

    get isEoiDetailDrawer() {
        return this.drawerMode === 'eoi-detail' && this.selectedEoi;
    }

    get isEoiFormDrawer() {
        return this.drawerMode === 'eoi-form';
    }

    get drawerTitle() {
        if (this.isLeadFormDrawer) return this.leadForm.Id ? 'Update Lead' : 'Add Lead';
        if (this.isLeadDetailDrawer) return this.selectedLead.name;
        if (this.isOpportunityDrawer) return this.selectedOpportunity.name;
        if (this.isEoiDetailDrawer) return this.selectedEoi.name;
        if (this.isEoiFormDrawer) return 'Add Expression of Interest';
        return 'Sales';
    }

    get drawerEyebrow() {
        return '';
    }

    // Record-context lines only (never instructional copy): the record's
    // requirement/stage/project beneath its name.
    get drawerSubtitle() {
        if (this.isLeadDetailDrawer) return this.selectedLeadRequirementLabel;
        if (this.isOpportunityDrawer) return this.selectedOpportunity.stageLabel;
        if (this.isEoiDetailDrawer) return this.selectedEoi.projectName;
        return '';
    }

    closeDrawer() {
        const notifyDirectClose = this.directLeadForm;
        const notifyDirectEoiClose = this.directEoiForm;
        this.drawerMode = '';
        this.selectedLeadId = '';
        this.selectedOpportunityId = '';
        this.selectedEoiId = '';
        this.selectedLeadDocuments = [];
        this.pendingDeleteFileId = '';
        this.salesOrders = [];
        this.clearResendCooldownTimer();
        this.clearExpiryTimer();
        if (notifyDirectClose) {
            this.dispatchEvent(
                new CustomEvent('closeleadform', {
                    bubbles: true,
                    composed: true
                })
            );
        }
        if (notifyDirectEoiClose) {
            this.dispatchEvent(
                new CustomEvent('closeeoiform', {
                    bubbles: true,
                    composed: true
                })
            );
        }
    }

    handleExportLeads() {
        const records = this.activeLeadRecords;
        if (!records.length) {
            this.showToast('No data to export', '', 'warning');
            return;
        }
        this.downloadCsv('LeadsExport.csv', ['LeadNumber', 'Title', 'FirstName', 'LastName', 'Email', 'Mobile', 'Description', 'Status'], records.map((lead) => [
            lead.LeadNumber || '',
            lead.Title || '',
            lead.FirstName || '',
            lead.LastName || '',
            lead.Email || '',
            lead.Mobile || '',
            lead.Description || '',
            lead.Status || ''
        ]));
    }

    handleExportOpportunities() {
        this.downloadCsv('modon-opportunities.csv', ['Opportunity', 'Stage', 'Project', 'Customer', 'Broker Agent', 'Sales Manager', 'Created'], this.filteredOpportunityRows.map((opp) => [
            opp.name,
            opp.stageLabel,
            opp.projectName,
            opp.customerContact,
            opp.brokerAgentName,
            opp.salesManagerName,
            opp.createdLabel
        ]));
    }

    handleExportEois() {
        if (this.isEoiActionBusy) return;
        this.downloadCsv('modon-eoi.csv', ['Payment', 'EOI', 'Customer', 'Status', 'Project', 'Phase', 'Unit Type', 'Bedrooms', 'Units', 'Amount'], this.filteredEoiRows.map((eoi) => [
            eoi.paymentName,
            eoi.eoiNumber,
            eoi.customerName,
            eoi.statusLabel,
            eoi.projectName,
            eoi.phaseName,
            eoi.unitType,
            eoi.bedrooms,
            eoi.units,
            eoi.amountLabel
        ]));
    }

    closeSalesFilterPanels() {
        this.isLeadFilterPanelOpen = false;
        this.isOpportunityFilterPanelOpen = false;
        this.isEoiFilterPanelOpen = false;
    }

    labelForValue(options, value) {
        const option = (options || []).find((item) => item.value === value || item.key === value);
        return option?.label || value || '';
    }

    withSelectedOption(options, selectedValue) {
        return (options || []).map((option) => {
            const value = option.value ?? option.key;
            return {
                ...option,
                key: option.key || value,
                value,
                isSelected: value === selectedValue
            };
        });
    }

    buildSalesFilterOptions(rows, field, allLabel, selectedValue = 'all') {
        const values = [...new Set((rows || []).map((row) => row[field]).filter(Boolean).map((value) => String(value)))].sort((a, b) =>
            a.localeCompare(b, undefined, { numeric: true, sensitivity: 'base' })
        );
        return this.withSelectedOption([{ value: 'all', label: allLabel }, ...values.map((value) => ({ value, label: value }))], selectedValue || 'all');
    }

    matchesSalesFilter(value, selectedValue) {
        return !selectedValue || selectedValue === 'all' || String(value ?? '') === String(selectedValue);
    }

    isSalesFilterValueAvailable(rows, field, value) {
        if (!value || value === 'all') return true;
        return (rows || []).some((row) => this.matchesSalesFilter(row[field], value));
    }

    syncPendingLeadFilters() {
        this.pendingLeadPeriod = this.leadPeriod || LEADS_DEFAULT_PERIOD;
        this.pendingLeadStartDate = this.leadStartDate || '';
        this.pendingLeadEndDate = this.leadEndDate || '';
        this.pendingLeadStatusFilter = this.leadStatusFilter || 'all';
        this.pendingLeadProjectFilter = this.leadProjectFilter || 'all';
        this.pendingLeadUnitTypeFilter = this.leadUnitTypeFilter || 'all';
        this.pendingLeadAgentFilter = this.leadAgentFilter || 'all';
    }

    getLeadRowsForFilter(field, useActive = false) {
        const status = useActive ? this.leadStatusFilter : this.pendingLeadStatusFilter;
        const project = useActive ? this.leadProjectFilter : this.pendingLeadProjectFilter;
        const unitType = useActive ? this.leadUnitTypeFilter : this.pendingLeadUnitTypeFilter;
        const agent = useActive ? this.leadAgentFilter : this.pendingLeadAgentFilter;

        return this.leadRows.filter((lead) => {
            const matchesStatus = field === 'status' || this.matchesSalesFilter(lead.statusLabel, status);
            const matchesProject = field === 'project' || this.matchesSalesFilter(lead.projectLabel, project);
            const matchesUnitType = field === 'unitType' || this.matchesSalesFilter(lead.unitTypeLabel, unitType);
            const matchesAgent = field === 'agent' || this.matchesSalesFilter(lead.agentLabel, agent);
            return matchesStatus && matchesProject && matchesUnitType && matchesAgent;
        });
    }

    reconcilePendingLeadFilters() {
        if (!this.isSalesFilterValueAvailable(this.getLeadRowsForFilter('status'), 'statusLabel', this.pendingLeadStatusFilter)) {
            this.pendingLeadStatusFilter = 'all';
        }
        if (!this.isSalesFilterValueAvailable(this.getLeadRowsForFilter('project'), 'projectLabel', this.pendingLeadProjectFilter)) {
            this.pendingLeadProjectFilter = 'all';
        }
        if (!this.isSalesFilterValueAvailable(this.getLeadRowsForFilter('unitType'), 'unitTypeLabel', this.pendingLeadUnitTypeFilter)) {
            this.pendingLeadUnitTypeFilter = 'all';
        }
        if (!this.isSalesFilterValueAvailable(this.getLeadRowsForFilter('agent'), 'agentLabel', this.pendingLeadAgentFilter)) {
            this.pendingLeadAgentFilter = 'all';
        }
    }

    reconcileLeadFilters() {
        if (!this.isSalesFilterValueAvailable(this.getLeadRowsForFilter('status', true), 'statusLabel', this.leadStatusFilter)) {
            this.leadStatusFilter = 'all';
        }
        if (!this.isSalesFilterValueAvailable(this.getLeadRowsForFilter('project', true), 'projectLabel', this.leadProjectFilter)) {
            this.leadProjectFilter = 'all';
        }
        if (!this.isSalesFilterValueAvailable(this.getLeadRowsForFilter('unitType', true), 'unitTypeLabel', this.leadUnitTypeFilter)) {
            this.leadUnitTypeFilter = 'all';
        }
        if (!this.isSalesFilterValueAvailable(this.getLeadRowsForFilter('agent', true), 'agentLabel', this.leadAgentFilter)) {
            this.leadAgentFilter = 'all';
        }
        this.leadPage = Math.min(Math.max(1, this.leadPage), this.pageCount(this.filteredLeadRows.length));
        if (this.isLeadFilterPanelOpen) {
            this.reconcilePendingLeadFilters();
        } else {
            this.syncPendingLeadFilters();
        }
    }

    syncPendingOpportunityFilters() {
        this.pendingOpportunityStartDate = this.opportunityStartDate || '';
        this.pendingOpportunityEndDate = this.opportunityEndDate || '';
        this.pendingOpportunityStageFilter = this.opportunityStageFilter || 'all';
        this.pendingOpportunityProjectFilter = this.opportunityProjectFilter || 'all';
        this.pendingOpportunityResidentStatusFilter = this.opportunityResidentStatusFilter || 'all';
        this.pendingOpportunityBrokerAgentFilter = this.opportunityBrokerAgentFilter || 'all';
        this.pendingOpportunitySalesManagerFilter = this.opportunitySalesManagerFilter || 'all';
    }

    getOpportunityRowsForFilter(field, useActive = false) {
        const stage = useActive ? this.opportunityStageFilter : this.pendingOpportunityStageFilter;
        const project = useActive ? this.opportunityProjectFilter : this.pendingOpportunityProjectFilter;
        const residentStatus = useActive ? this.opportunityResidentStatusFilter : this.pendingOpportunityResidentStatusFilter;
        const brokerAgent = useActive ? this.opportunityBrokerAgentFilter : this.pendingOpportunityBrokerAgentFilter;
        const salesManager = useActive ? this.opportunitySalesManagerFilter : this.pendingOpportunitySalesManagerFilter;

        return this.opportunityRows.filter((opp) => {
            const matchesStage = field === 'stage' || this.matchesSalesFilter(opp.stageLabel, stage);
            const matchesProject = field === 'project' || this.matchesSalesFilter(opp.projectName, project);
            const matchesResidentStatus = field === 'residentStatus' || this.matchesSalesFilter(opp.residentStatus, residentStatus);
            const matchesBrokerAgent = field === 'brokerAgent' || this.matchesSalesFilter(opp.brokerAgentName, brokerAgent);
            const matchesSalesManager = field === 'salesManager' || this.matchesSalesFilter(opp.salesManagerName, salesManager);
            return matchesStage && matchesProject && matchesResidentStatus && matchesBrokerAgent && matchesSalesManager;
        });
    }

    reconcilePendingOpportunityFilters() {
        if (!this.isSalesFilterValueAvailable(this.getOpportunityRowsForFilter('stage'), 'stageLabel', this.pendingOpportunityStageFilter)) {
            this.pendingOpportunityStageFilter = 'all';
        }
        if (!this.isSalesFilterValueAvailable(this.getOpportunityRowsForFilter('project'), 'projectName', this.pendingOpportunityProjectFilter)) {
            this.pendingOpportunityProjectFilter = 'all';
        }
        if (
            !this.isSalesFilterValueAvailable(
                this.getOpportunityRowsForFilter('residentStatus'),
                'residentStatus',
                this.pendingOpportunityResidentStatusFilter
            )
        ) {
            this.pendingOpportunityResidentStatusFilter = 'all';
        }
        if (
            !this.isSalesFilterValueAvailable(
                this.getOpportunityRowsForFilter('brokerAgent'),
                'brokerAgentName',
                this.pendingOpportunityBrokerAgentFilter
            )
        ) {
            this.pendingOpportunityBrokerAgentFilter = 'all';
        }
        if (
            !this.isSalesFilterValueAvailable(
                this.getOpportunityRowsForFilter('salesManager'),
                'salesManagerName',
                this.pendingOpportunitySalesManagerFilter
            )
        ) {
            this.pendingOpportunitySalesManagerFilter = 'all';
        }
    }

    reconcileOpportunityFilters() {
        if (!this.isSalesFilterValueAvailable(this.getOpportunityRowsForFilter('stage', true), 'stageLabel', this.opportunityStageFilter)) {
            this.opportunityStageFilter = 'all';
        }
        if (!this.isSalesFilterValueAvailable(this.getOpportunityRowsForFilter('project', true), 'projectName', this.opportunityProjectFilter)) {
            this.opportunityProjectFilter = 'all';
        }
        if (
            !this.isSalesFilterValueAvailable(
                this.getOpportunityRowsForFilter('residentStatus', true),
                'residentStatus',
                this.opportunityResidentStatusFilter
            )
        ) {
            this.opportunityResidentStatusFilter = 'all';
        }
        if (
            !this.isSalesFilterValueAvailable(
                this.getOpportunityRowsForFilter('brokerAgent', true),
                'brokerAgentName',
                this.opportunityBrokerAgentFilter
            )
        ) {
            this.opportunityBrokerAgentFilter = 'all';
        }
        if (
            !this.isSalesFilterValueAvailable(
                this.getOpportunityRowsForFilter('salesManager', true),
                'salesManagerName',
                this.opportunitySalesManagerFilter
            )
        ) {
            this.opportunitySalesManagerFilter = 'all';
        }
        this.opportunityPage = Math.min(Math.max(1, this.opportunityPage), this.pageCount(this.filteredOpportunityRows.length));
        if (this.isOpportunityFilterPanelOpen) {
            this.reconcilePendingOpportunityFilters();
        } else {
            this.syncPendingOpportunityFilters();
        }
    }

    syncPendingEoiFilters() {
        this.pendingEoiStatusFilter = this.eoiStatusFilter || 'all';
        this.pendingEoiProjectFilter = this.eoiProjectFilter || 'all';
        this.pendingEoiPhaseFilter = this.eoiPhaseFilter || 'all';
        this.pendingEoiUnitTypeFilter = this.eoiUnitTypeFilter || 'all';
        this.pendingEoiBedroomsFilter = this.eoiBedroomsFilter || 'all';
    }

    getEoiRowsForFilter(field, useActive = false) {
        const status = useActive ? this.eoiStatusFilter : this.pendingEoiStatusFilter;
        const project = useActive ? this.eoiProjectFilter : this.pendingEoiProjectFilter;
        const phase = useActive ? this.eoiPhaseFilter : this.pendingEoiPhaseFilter;
        const unitType = useActive ? this.eoiUnitTypeFilter : this.pendingEoiUnitTypeFilter;
        const bedrooms = useActive ? this.eoiBedroomsFilter : this.pendingEoiBedroomsFilter;

        return this.eoiRows.filter((eoi) => {
            const matchesStatus = field === 'status' || this.matchesSalesFilter(eoi.statusLabel, status);
            const matchesProject = field === 'project' || this.matchesSalesFilter(eoi.projectName, project);
            const matchesPhase = field === 'phase' || this.matchesSalesFilter(eoi.phaseName, phase);
            const matchesUnitType = field === 'unitType' || this.matchesSalesFilter(eoi.unitType, unitType);
            const matchesBedrooms = field === 'bedrooms' || this.matchesSalesFilter(eoi.bedrooms, bedrooms);
            return matchesStatus && matchesProject && matchesPhase && matchesUnitType && matchesBedrooms;
        });
    }

    reconcilePendingEoiFilters() {
        if (!this.isSalesFilterValueAvailable(this.getEoiRowsForFilter('status'), 'statusLabel', this.pendingEoiStatusFilter)) {
            this.pendingEoiStatusFilter = 'all';
        }
        if (!this.isSalesFilterValueAvailable(this.getEoiRowsForFilter('project'), 'projectName', this.pendingEoiProjectFilter)) {
            this.pendingEoiProjectFilter = 'all';
        }
        if (!this.isSalesFilterValueAvailable(this.getEoiRowsForFilter('phase'), 'phaseName', this.pendingEoiPhaseFilter)) {
            this.pendingEoiPhaseFilter = 'all';
        }
        if (!this.isSalesFilterValueAvailable(this.getEoiRowsForFilter('unitType'), 'unitType', this.pendingEoiUnitTypeFilter)) {
            this.pendingEoiUnitTypeFilter = 'all';
        }
        if (!this.isSalesFilterValueAvailable(this.getEoiRowsForFilter('bedrooms'), 'bedrooms', this.pendingEoiBedroomsFilter)) {
            this.pendingEoiBedroomsFilter = 'all';
        }
    }

    reconcileEoiFilters() {
        if (!this.isSalesFilterValueAvailable(this.getEoiRowsForFilter('status', true), 'statusLabel', this.eoiStatusFilter)) {
            this.eoiStatusFilter = 'all';
        }
        if (!this.isSalesFilterValueAvailable(this.getEoiRowsForFilter('project', true), 'projectName', this.eoiProjectFilter)) {
            this.eoiProjectFilter = 'all';
        }
        if (!this.isSalesFilterValueAvailable(this.getEoiRowsForFilter('phase', true), 'phaseName', this.eoiPhaseFilter)) {
            this.eoiPhaseFilter = 'all';
        }
        if (!this.isSalesFilterValueAvailable(this.getEoiRowsForFilter('unitType', true), 'unitType', this.eoiUnitTypeFilter)) {
            this.eoiUnitTypeFilter = 'all';
        }
        if (!this.isSalesFilterValueAvailable(this.getEoiRowsForFilter('bedrooms', true), 'bedrooms', this.eoiBedroomsFilter)) {
            this.eoiBedroomsFilter = 'all';
        }
        this.eoiPage = Math.min(Math.max(1, this.eoiPage), this.pageCount(this.filteredEoiRows.length));
        if (this.isEoiFilterPanelOpen) {
            this.reconcilePendingEoiFilters();
        } else {
            this.syncPendingEoiFilters();
        }
    }

    paginate(rows, page) {
        const start = (page - 1) * PAGE_SIZE;
        return rows.slice(start, start + PAGE_SIZE);
    }

    pageCount(count) {
        return Math.max(1, Math.ceil(count / PAGE_SIZE));
    }

    pageLabel(count, page) {
        if (!count) return '0 records';
        const start = (page - 1) * PAGE_SIZE + 1;
        const end = Math.min(page * PAGE_SIZE, count);
        return `${start}-${end} of ${count}`;
    }

    buildSelectOptions(rows, field, allLabel) {
        const values = [...new Set(rows.map((row) => row[field]).filter(Boolean))].sort();
        return [{ value: 'all', label: allLabel }, ...values.map((value) => ({ value, label: value }))];
    }

    toOptions(values) {
        const seen = new Set();
        const source = Array.isArray(values) ? values : Object.values(values || {});
        return source
            .map((item) => this.normalizeOption(item))
            .filter((option) => {
                if (!option?.value || seen.has(option.value)) return false;
                seen.add(option.value);
                return true;
            });
    }

    toUiApiOptions(values) {
        return (values || [])
            .filter((item) => item?.value)
            .map((item) => ({
                value: item.value,
                label: item.label || item.value
            }));
    }

    normalizeLookupOptions(values) {
        return this.toOptions(values);
    }

    normalizeOption(item) {
        if (item === undefined || item === null || item === '') return null;
        if (typeof item !== 'object') {
            const value = String(item);
            return { value, label: value };
        }

        const rawValue = item.value ?? item.Value ?? item.id ?? item.Id ?? item.name ?? item.Name ?? item.label ?? item.Label;
        if (rawValue === undefined || rawValue === null || rawValue === '') return null;
        const rawLabel = item.label ?? item.Label ?? item.name ?? item.Name ?? item.value ?? item.Value ?? rawValue;
        return {
            value: String(rawValue),
            label: String(rawLabel || rawValue)
        };
    }

    getInitials(name) {
        return String(name || 'M')
            .split(/\s+/)
            .filter(Boolean)
            .slice(0, 2)
            .map((part) => part[0])
            .join('')
            .toUpperCase();
    }

    getLeadName(lead) {
        return [lead.FirstName, lead.LastName].filter(Boolean).join(' ').trim() || lead.Name || 'Unnamed lead';
    }

    isRetiredStatus(status) {
        return String(status || '')
            .toLowerCase()
            .includes('retired');
    }

    getStatusTone(status) {
        const value = String(status || '').toLowerCase();
        if (value.includes('void') || value.includes('reject') || value.includes('cancel') || value.includes('expired') || value.includes('declined') || value.includes('lost') || value.includes('retired')) {
            return 'error';
        }
        if (value.includes('complete') || value.includes('confirm') || value.includes('approve') || value.includes('qualified') || value.includes('converted') || value.includes('won') || value.includes('captured')) {
            return 'success';
        }
        // BP-041: a payment request awaiting the customer; a held payment (Payment Authorized) is live
        if (value.includes('link created')) {
            return 'warning';
        }
        if (value.includes('authori')) {
            return 'active';
        }
        if (value.includes('pending') || value.includes('progress') || value.includes('finance') || value.includes('working')) {
            return 'warning';
        }
        if (value.includes('new') || value.includes('open') || value.includes('buyer')) {
            return 'active';
        }
        return 'muted';
    }

    formatShortDate(value) {
        if (!value) return '';
        const date = new Date(value);
        if (Number.isNaN(date.getTime())) return String(value);
        return new Intl.DateTimeFormat('en-AE', { day: '2-digit', month: 'short', year: 'numeric' }).format(date);
    }

    formatCurrency(amount) {
        const num = Number(amount);
        if (Number.isNaN(num)) return 'AED 0';
        return new Intl.NumberFormat('en-AE', {
            style: 'currency',
            currency: 'AED',
            maximumFractionDigits: 0
        }).format(num);
    }

    formatBedrooms(value) {
        if (value === null || value === undefined || value === '') return 'Not specified';
        const num = Number(value);
        if (Number.isNaN(num)) return String(value);
        if (num === 0) return 'Studio';
        if (num === 1) return '1 BR';
        return `${num} BR`;
    }

    toDateInput(value) {
        if (!value) return '';
        const date = new Date(value);
        if (Number.isNaN(date.getTime())) return String(value).slice(0, 10);
        return date.toISOString().slice(0, 10);
    }

    isMaskedValue(value) {
        return /[•*]/.test(String(value || ''));
    }

    normalizeHttpUrl(value) {
        const raw = String(value || '').trim();
        return /^https?:\/\//i.test(raw) ? raw: '';
    }

    readFileAsBase64(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = () => {
                const result = String(reader.result || '');
                resolve(result.includes(',') ? result.split(',')[1] : result);
            };
            reader.onerror = () => reject(reader.error);
            reader.readAsDataURL(file);
        });
    }

    downloadCsv(fileName, headers, rows) {
        const csv = [
            headers.map((value) => this.escapeCsv(value)).join(','),
            ...rows.map((row) => row.map((value) => this.escapeCsv(value)).join(','))
        ].join('\n');
        const blob = new Blob([`\uFEFF${csv}`], { type: 'text/plain' });
        let url;
        try {
            url = URL.createObjectURL(blob);
            const anchor = document.createElement('a');
            anchor.href = url;
            anchor.download = fileName;
            anchor.style.display = 'none';
            document.body.appendChild(anchor);
            anchor.click();
            document.body.removeChild(anchor);
        } finally {
            if (url) window.setTimeout(() => URL.revokeObjectURL(url), 0);
        }
    }

    escapeCsv(value) {
        return `"${String(value ?? '').replace(/"/g, '""')}"`;
    }

    getBlankVerificationDigits() {
        return Array.from({ length: 6 }, (_value, index) => ({
            key: `otp-${index}`,
            index,
            value: '',
            ariaLabel: `Digit ${index + 1} of ${VERIFICATION_CODE_LENGTH}`
        }));
    }

    resetVerification() {
        this.clearResendCooldownTimer();
        this.clearExpiryTimer();
        this.verificationMethod = '';
        this.verificationDigits = this.getBlankVerificationDigits();
        this.verificationRequestId = '';
        this.verificationMaskedTarget = '';
        this.verificationCodeError = '';
        this.verificationCompleted = false;
        this.verificationExpired = false;
        this.verificationFailed = false;
        this.verificationExpiresAt = null;
        this.verificationExpirySeconds = 0;
        this.isSendingVerification = false;
        this.isResendingVerification = false;
        this.isVerifyingCode = false;
        this.resendAvailableAt = null;
        this.resendCooldownSeconds = 0;
        this.maxResendReached = false;
    }

    startExpiryCountdown(expiresAt) {
        this.clearExpiryTimer();
        this.verificationExpiresAt = expiresAt || null;
        this.verificationExpired = false;
        if (!this.verificationExpiresAt) {
            this.verificationExpirySeconds = 0;
            return;
        }
        const update = () => {
            const expiresAtMs = new Date(this.verificationExpiresAt).getTime();
            const seconds = Number.isFinite(expiresAtMs) ? Math.max(0, Math.ceil((expiresAtMs - Date.now()) / 1000)) : 0;
            this.verificationExpirySeconds = seconds;
            if (seconds === 0) {
                this.clearExpiryTimer();
                if (this.verificationRequestId && !this.verificationCompleted) {
                    this.verificationExpired = true;
                }
            }
        };
        update();
        if (this.verificationExpirySeconds > 0) {
            this.verificationExpiryTimer = setInterval(update, 1000);
        }
    }

    clearExpiryTimer() {
        if (this.verificationExpiryTimer) {
            clearInterval(this.verificationExpiryTimer);
            this.verificationExpiryTimer = null;
        }
    }

    startResendCooldown(resendAvailableAt) {
        this.clearResendCooldownTimer();
        this.resendAvailableAt = resendAvailableAt;
        const update = () => {
            const availableAt = this.resendAvailableAt ? new Date(this.resendAvailableAt).getTime() : 0;
            const seconds = Math.max(0, Math.ceil((availableAt - Date.now()) / 1000));
            this.resendCooldownSeconds = seconds;
            if (seconds === 0) this.clearResendCooldownTimer();
        };
        update();
        if (this.resendCooldownSeconds > 0) {
            this.resendCooldownTimer = setInterval(update, 1000);
        }
    }

    clearResendCooldownTimer() {
        if (this.resendCooldownTimer) {
            clearInterval(this.resendCooldownTimer);
            this.resendCooldownTimer = null;
        }
        if (!this.resendAvailableAt || new Date(this.resendAvailableAt).getTime() <= Date.now()) {
            this.resendCooldownSeconds = 0;
        }
    }

    getFormMessageClass(tone = 'info') {
        const normalizedTone = tone || 'info';
        return [
            'sales-inline-message',
            'form-action-status',
            `form-action-status--${normalizedTone}`,
            `sales-inline-message--${normalizedTone}`
        ].filter(Boolean).join(' ');
    }

    setLeadFormMessage(message, tone = 'info') {
        this.leadFormMessage = message || '';
        this.leadFormMessageTone = tone || 'info';
    }

    clearLeadFormMessage() {
        this.leadFormMessage = '';
        this.leadFormMessageTone = 'info';
    }

    setEoiFormMessage(message, tone = 'info') {
        this.eoiFormMessage = message || '';
        this.eoiFormMessageTone = tone || 'info';
    }

    clearEoiFormMessage() {
        this.eoiFormMessage = '';
        this.eoiFormMessageTone = 'info';
    }

    showToast(title, message, variant = 'info') {
        try {
            Toast.show({ label: title, message, mode: 'dismissible', variant }, this);
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({ title, message, mode: 'dismissible', variant }));
        }
    }

    reduceError(error) {
        if (typeof error === 'string') {
            return error;
        }

        if (Array.isArray(error?.body)) {
            return error.body.map((item) => item.message).join(', ');
        }

        const fieldErrors = error?.body?.output?.fieldErrors || error?.body?.fieldErrors;
        if (fieldErrors) {
            const messages = Object.keys(fieldErrors).flatMap((fieldName) =>
                (fieldErrors[fieldName] || []).map((fieldError) => fieldError.message)
            );
            if (messages.length) return messages.join(', ');
        }

        const pageErrors = error?.body?.output?.errors || error?.body?.output?.pageErrors || error?.body?.pageErrors;
        if (pageErrors?.length) {
            return pageErrors.map((item) => item.message).join(', ');
        }

        if (error?.body?.message) return error.body.message;
        if (error?.detail?.message) return error.detail.message;
        if (error?.message) return error.message;

        try {
            const serializedError = JSON.stringify(error);
            return serializedError && serializedError !== '{}' ? serializedError : 'Unknown error';
        } catch (serializationError) {
            return 'Unknown error';
        }
    }
}