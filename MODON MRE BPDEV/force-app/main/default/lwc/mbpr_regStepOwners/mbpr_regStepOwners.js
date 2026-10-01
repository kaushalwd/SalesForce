/**
 * Component Name: mbpr_regStepOwners
 * Description: Step 3, Owner Information. Repeating form for up to five
 *                  owners with Loqate phone and email validation, per-member
 *                  document uploads and a hand-rolled validation sweep.
 * Author: Aurelix IT
 *
 * Parent is mbpr_registrationWorkspace. submitForm resolves after save and
 * throws on Apex failure; emits 'success' ({ids:[...]}), 'error' and 'toast'.
 */

import { LightningElement, api, track } from 'lwc';
import regFormStyles from 'c/mbpr_regFormStyles';

/* Ported verbatim. Some are unused, as they were in the legacy bundle, but
   are kept so the step's Apex dependency set stays identical. */
import getAgents from '@salesforce/apex/MBP_RegistrationGatewayController.getAgents';
import saveAgents from '@salesforce/apex/MBP_RegistrationGatewayController.saveAgents'; // eslint-disable-line no-unused-vars
import deleteAgent from '@salesforce/apex/MBP_RegistrationGatewayController.deleteAgent';
import getRegistration from '@salesforce/apex/MBP_RegistrationGatewayController.getRegistration';
import validateCompanyEmail from '@salesforce/apex/MBP_LoqateIntegration.validateEmail';
import uploadFile from '@salesforce/apex/MBP_RegistrationGatewayController.uploadFile'; // eslint-disable-line no-unused-vars
import validatePhone from '@salesforce/apex/MBP_LoqateIntegration.validatePhone';
import checkDuplicateEmailOrMobile from '@salesforce/apex/MBP_RegistrationGatewayController.checkDuplicateEmailOrMobile';
import getExistingFile from '@salesforce/apex/MBP_RegistrationGatewayController.getExistingFile'; // eslint-disable-line no-unused-vars
import deleteFile from '@salesforce/apex/MBP_RegistrationGatewayController.deleteFile'; // eslint-disable-line no-unused-vars
import saveAgentsWithFiles from '@salesforce/apex/MBP_RegistrationGatewayController.saveAgentsWithFiles';

import { countryOptions } from './countries';

/* ---- Legacy country-code list (same 207 values, same order) ---- */
const MOB_COUNTRY_CODES = [
    '1', '20', '27', '30', '31', '32', '33', '34', '36', '39', '40', '41', '43', '44', '45', '46', '47', '48', '49',
    '51', '52', '53', '54', '55', '56', '57', '58', '60', '61', '62', '63', '64', '65', '66', '81', '82', '84', '86',
    '90', '91', '92', '93', '94', '95', '98', '211', '212', '213', '216', '218', '220', '221', '222', '223', '224',
    '225', '226', '227', '228', '229', '230', '231', '232', '233', '234', '235', '236', '237', '238', '239', '240',
    '241', '242', '243', '244', '245', '246', '248', '249', '250', '251', '252', '253', '254', '255', '256', '257',
    '258', '260', '261', '262', '263', '264', '265', '266', '267', '268', '269', '290', '291', '297', '298', '299',
    '350', '351', '352', '353', '354', '355', '356', '357', '358', '359', '370', '371', '372', '373', '374', '375',
    '376', '377', '378', '380', '381', '382', '385', '386', '387', '389', '420', '421', '423', '500', '501', '502',
    '503', '504', '505', '506', '507', '508', '509', '590', '591', '592', '593', '594', '595', '596', '597', '598',
    '599', '670', '672', '673', '674', '675', '676', '677', '678', '679', '680', '681', '682', '683', '685', '686',
    '687', '688', '689', '690', '691', '692', '850', '852', '853', '855', '856', '870', '880', '881', '882', '883',
    '886', '960', '961', '962', '963', '964', '965', '966', '967', '968', '970', '971', '972', '973', '974', '975',
    '976', '977', '992', '993', '994', '995', '996', '998'
];

/* ---- Validation rule constants (legacy strings preserved) ---- */
const ISSUE_DATE_FIELDS = ['passportIssueDate', 'eidIssueDate', 'brokerCertificateIssueDate'];
const EXPIRY_DATE_FIELDS = ['passportExpiryDate', 'eidExpiryDate', 'brokerCertificateExpiryDate'];
const EID_REGEX = /^784-\d{4}-\d{7}-\d{1}$/;
const MOBILE_PATTERN = /^\+?[1-9][0-9]{7,14}$/;
const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const MSG_REQUIRED_SWEEP = 'Complete this field.';
const MSG_REQUIRED_SUBMIT = 'This field is required';
const MSG_ISSUE_FUTURE = 'Issue Date cannot be in the future.';
const MSG_EXPIRY_PAST = 'Expiry Date cannot be in the past.';
const MSG_EID_CHANGE = 'Emirates ID must be in the format: 784-XXXX-XXXXXXX-X. Only digits and dashes allowed in correct positions.';
const MSG_EID_SUBMIT = 'EID must be in the format: 784-XXXX-XXXXXXX-X';
const MSG_MOBILE_PATTERN = 'Please enter only numbers';
const MSG_EMAIL_FORMAT = 'You have entered an invalid format.';
const MSG_SHARE_MAX = 'The number is too high.';

const VALID_FILE_EXTENSIONS = ['pdf', 'jpg', 'jpeg'];
const MAX_FILE_SIZE = 2 * 1024 * 1024; // 2 MB

/* Per-document state slots. Property names match the legacy staffMembers
   model so Apex payloads stay byte-compatible. POA Name, Email and Document
   moved here from the Agency Admin step, so POA_Document now has a real
   input rather than being payload-only plumbing. */
const FILE_SLOTS = {
    Passport_First_Page: {
        base64: 'passportFrontbase64File', name: 'passportFrontfileName',
        preview: 'passportPreviewUrl', flag: 'isPassportFirstPageUploaded', errorKey: 'passportFirstUpload'
    },
    Passport_Signature_Page: {
        base64: 'passportFinalbase64File', name: 'passportFinalfileName',
        preview: 'passportFinalPreviewUrl', flag: 'isPassportSignaturePageUploaded', errorKey: 'passportSignatureUpload'
    },
    Emirates_ID_Front: {
        base64: 'eidFrontbase64File', name: 'eidFrontfileName',
        preview: 'eidFrontPreviewUrl', flag: 'isEmiratesIdFrontUploaded', errorKey: 'eidFrontUpload'
    },
    Emirates_ID_Back: {
        base64: 'eidBackbase64File', name: 'eidBackfileName',
        preview: 'eidBackPreviewUrl', flag: 'isEmiratesIdBackUploaded', errorKey: 'eidBackUpload'
    },
    Visa_Page: {
        base64: 'visabase64File', name: 'visabasefileName',
        preview: 'visaPreviewUrl', flag: 'isVisaPageUploaded', errorKey: 'visaUpload'
    },
    POA_Document: {
        base64: 'poabase64File', name: 'poafileName',
        preview: 'poaPreviewUrl', flag: 'isPoaUploaded', errorKey: 'poaUpload'
    }
};

/* Field vocabulary for the view model (error text + card classes). */
const FIELD_NAMES = [
    'firstname', 'lastname', 'nationality', 'residentStatus', 'mobileNum', 'mobile', 'email',
    'passportNumber', 'passportIssueDate', 'passportExpiryDate',
    'eidNumber', 'eidIssueDate', 'eidExpiryDate',
    'brokerCertificateNumber', 'issuingAuthority', 'brokerCertificateIssueDate', 'brokerCertificateExpiryDate',
    'shareholdingPercentage',
    'POA', 'POAemail'
];

/* POA Name and Email are optional, as they were on the Agency Admin step.
   Kept out of the required styling so no asterisk appears. */
const OPTIONAL_FIELDS = new Set(['POA', 'POAemail']);

const UPLOAD_ERROR_KEYS = ['passportFirstUpload', 'passportSignatureUpload', 'eidFrontUpload', 'eidBackUpload', 'visaUpload'];

/* POA Document is optional too, so it renders without the required marker. */
const OPTIONAL_UPLOAD_ERROR_KEYS = ['poaUpload'];

/* Re-checked for emptiness on change. mobileNum is absent on purpose: it was
   never required in markup, only by the submit-time country-code check. */
const REQUIRED_LIVE_FIELDS = [
    'firstname', 'lastname', 'nationality', 'passportNumber',
    'brokerCertificateNumber', 'issuingAuthority', 'shareholdingPercentage'
];

const BROKER_ERROR_KEYS = ['brokerCertificateNumber', 'issuingAuthority', 'brokerCertificateIssueDate', 'brokerCertificateExpiryDate'];
const RESIDENT_ERROR_KEYS = ['eidNumber', 'eidIssueDate', 'eidExpiryDate', 'eidFrontUpload', 'eidBackUpload', 'visaUpload'];

export default class MbprRegStepOwners extends LightningElement {
    static stylesheets = [regFormStyles];

    @api objectApiName; // 'Registration_Agent__c' (from parent; informational)
    @api registrationId;
    @api sessionId;
    @api registrationStatus;
    @api mode; // 'draft'

    countryOptions = countryOptions;
    residentStatusOptions = [
        { label: 'Resident', value: 'Resident' },
        { label: 'Non-Resident', value: 'Non-Resident' }
    ];

    @track countryOptionsList = [];
    @track staffMembers = [];
    @track initialStaffMembers = [];
    @track isAddButtonDisabled = false;

    /* BP-038 - the workspace's lock (status not Draft) or this step's own
       status check; templates keep binding disabled={isDisabled}. */
    @api locked = false;
    statusLocked = false;

    get isDisabled() {
        return Boolean(this.locked) || this.statusLocked;
    }
    @track isLoading = false;
    /* Error store, { [memberId]: { [field]: message } }. Kept outside
       staffMembers so the member shape and Apex payloads stay identical. */
    @track fieldErrors = {};

    registrationTypeFromParent;

    get mobCountryOptions() {
        return MOB_COUNTRY_CODES.map((code) => ({ label: code, value: code }));
    }

    get showDeleteIcon() {
        return this.mode?.toLowerCase() === 'draft' && this.registrationStatus !== 'Submitted' && !this.isDisabled;
    }

    get showAddRow() {
        return !this.isAddButtonDisabled && !this.isDisabled;
    }

    /* ---- View model: legacy member state + per-field class/error props ---- */
    get ownerCards() {
        const allErrors = this.fieldErrors || {};
        return this.staffMembers.map((member) => {
            const errors = allErrors[member.id] || {};
            const card = {
                ...member,
                removable: !!member.showRemoveIcon && this.showDeleteIcon
            };
            FIELD_NAMES.forEach((field) => {
                const message = errors[field] || '';
                let cls = 'regf-field';
                if (field === 'mobileNum') {
                    cls += ' regf-field--code';
                } else if (!OPTIONAL_FIELDS.has(field)) {
                    cls += ' regf-field--required';
                }
                if (message) cls += ' regf-field--error';
                card['c_' + field] = cls;
                card['e_' + field] = message;
            });
            UPLOAD_ERROR_KEYS.forEach((key) => {
                const message = errors[key] || '';
                card['c_' + key] =
                    'regf-upload regf-upload--required' +
                    (this.isDisabled ? ' regf-upload--disabled' : '') +
                    (message ? ' regf-field--error' : '');
                card['e_' + key] = message;
            });
            OPTIONAL_UPLOAD_ERROR_KEYS.forEach((key) => {
                const message = errors[key] || '';
                card['c_' + key] =
                    'regf-upload' +
                    (this.isDisabled ? ' regf-upload--disabled' : '') +
                    (message ? ' regf-field--error' : '');
                card['e_' + key] = message;
            });
            card.e_isPrimaryOwner = errors.isPrimaryOwner || '';
            return card;
        });
    }

    /* ---- Lifecycle ---- */

    async connectedCallback() {
        this.isLoading = true;
        this.countryOptionsList = countryOptions;
        try {
            if (this.registrationId) {
                const registrationObj = await getRegistration({ registrationId: this.registrationId, sessionId: this.sessionId });
                this.registrationTypeFromParent = registrationObj.Type_of_Registration__c?.trim()?.toLowerCase();
                if (registrationObj.Status__c !== 'Draft') {
                    this.statusLocked = true;
                }
                await this.loadRegistrationAgents();
                this.initialStaffMembers = JSON.parse(JSON.stringify(this.staffMembers));
            }
        } catch (error) {
            this.dispatchEvent(new CustomEvent('error', {
                detail: { message: 'Unable to load registration data: ' + (error.body?.message || 'Unknown error') },
                bubbles: true,
                composed: true
            }));
        } finally {
            this.isLoading = false;
        }
    }

    /* Native selects do not reliably reflect a bound value before their options
       render, so state is synced onto them after every render. */
    renderedCallback() {
        this.template.querySelectorAll('select.regf-field__control').forEach((sel) => {
            const member = this.staffMembers.find((m) => m.id === sel.dataset.id);
            if (!member) return;
            const value = member[sel.name];
            sel.value = value === undefined || value === null ? '' : String(value);
        });
    }

    /* ---- Prefill ---- */

    async loadRegistrationAgents() {
        this.isLoading = true;
        try {
            const agents = await getAgents({ registrationId: this.registrationId, sessionId: this.sessionId });
            const staffAgents = agents.filter((agent) => agent.Brokertype === 'Owner');
            if (staffAgents.length > 0) {
                this.staffMembers = staffAgents.map((agent, index) => this.withMemberDisplayDefaults({
                    ...agent,
                    id: agent.sfId != null ? agent.sfId : Date.now().toString(),
                    label: `Owner Details ${index + 1}`,
                    showRemoveIcon: staffAgents.length > 1,
                    firstname: agent.firstname,
                    lastname: agent.lastname,
                    mobileNum: agent.mobileNum,
                    email: agent.email,
                    mobile: agent.mobile,
                    passportIssueDate: agent.passportIssueDate,
                    residentStatus: agent.residentStatus,
                    isResident: agent.residentStatus === 'Resident',
                    eidIssueDate: agent.eidIssueDate,
                    nationality: agent.nationality,
                    brokerCertificateNumber: agent.Broker_Certificate_Number,
                    brokerCertificateIssueDate: agent.Broker_Certificate_Issue_Date,
                    brokerCertificateExpiryDate: agent.Broker_Certificate_Expiry_Date,
                    issuingAuthority: agent.Issuing_Authority,
                    passportNumber: agent.passportNumber,
                    passportExpiryDate: agent.passportExpiryDate,
                    eidNumber: agent.eidNumber,
                    eidExpiryDate: agent.eidExpiryDate,
                    Brokertype: agent.Brokertype,
                    registrationId: this.registrationId,
                    sfId: agent.sfId,

                    passportFrontbase64File: agent.passportFrontbase64File,
                    passportPreviewUrl: agent.passportFrontbase64File ? `data:application/pdf;base64,${agent.passportFrontbase64File}` : null,
                    isPassportFirstPageUploaded: !!agent.passportFrontbase64File,
                    passportFrontfileName: agent.passportFrontfileName,

                    passportFinalbase64File: agent.passportFinalbase64File,
                    passportFinalPreviewUrl: agent.passportFinalbase64File ? `data:application/pdf;base64,${agent.passportFinalbase64File}` : null,
                    isPassportSignaturePageUploaded: !!agent.passportFinalbase64File,
                    passportFinalfileName: agent.passportFinalfileName,

                    eidFrontbase64File: agent.eidFrontbase64File,
                    eidFrontPreviewUrl: agent.eidFrontbase64File ? `data:application/pdf;base64,${agent.eidFrontbase64File}` : null,
                    isEmiratesIdFrontUploaded: !!agent.eidFrontbase64File,
                    eidFrontfileName: agent.eidFrontfileName,

                    eidBackbase64File: agent.eidBackbase64File,
                    eidBackPreviewUrl: agent.eidBackbase64File ? `data:application/pdf;base64,${agent.eidBackbase64File}` : null,
                    isEmiratesIdBackUploaded: !!agent.eidBackbase64File,
                    eidBackfileName: agent.eidBackfileName,

                    visabase64File: agent.visabase64File,
                    visaPreviewUrl: agent.visabase64File ? `data:application/pdf;base64,${agent.visabase64File}` : null,
                    isVisaPageUploaded: !!agent.visabase64File,
                    visabasefileName: agent.visabasefileName,

                    /* POA belongs to the Owner record now. Apex already returns
                       and stores POA / POAemail on Registration_Agent__c, so
                       the values just land on the owner's row. */
                    POA: agent.POA,
                    POAemail: agent.POAemail,
                    poabase64File: agent.poabase64File,
                    poaPreviewUrl: agent.poabase64File ? `data:application/pdf;base64,${agent.poabase64File}` : null,
                    isPoaUploaded: !!agent.poabase64File,
                    poafileName: agent.poafileName,

                    tempId: agent.id,
                    isPhoneLoqateValid: agent.mobileNum != null && agent.mobile != null,
                    isEmailLoqateValid: agent.email != null,
                    /* Legacy crossed these two label derivations: validateEmail
                       keyed off the phone fields and vice versa. */
                    validatePhone: agent.mobileNum != null && agent.mobile != null ? 'Validated' : 'Validate Phone',
                    validateEmail: agent.email != null ? 'Validated' : 'Validate Email'
                }));
            } else {
                const newAgent = this.withMemberDisplayDefaults({
                    id: Date.now().toString(), // temp ID
                    firstname: '',
                    lastname: '',
                    mobileNum: '',
                    email: '',
                    mobileCountryCode: '',
                    mobile: '',
                    passportNumber: '',
                    passportExpiryDate: '',
                    eidNumber: '',
                    residentStatus: '',
                    isResident: false,
                    eidExpiryDate: '',
                    shareholdingPercentage: '',
                    isPrimaryOwner: false,
                    isBroker: false,
                    passportFrontbase64File: null,
                    passportFinalbase64File: null,
                    eidFrontbase64File: null,
                    eidBackbase64File: null,
                    visabase64File: null,
                    label: 'Owner Details 1',
                    validateEmail: 'Validate Email',
                    validatePhone: 'Validate Phone'
                });
                this.staffMembers = [...this.staffMembers, newAgent];
            }
            this.updateAddButtonState();
        } catch (error) {
            this.dispatchEvent(new CustomEvent('error', {
                detail: { message: 'Unable to load Registration Agents: ' + (error.body?.message || error.message) },
                bubbles: true,
                composed: true
            }));
        } finally {
            this.isLoading = false;
        }
    }

    /* Native inputs render a null binding as the literal "undefined", so every
       template-bound member scalar must exist as ''. */
    withMemberDisplayDefaults(member) {
        const out = { ...member };
        [
            'firstname',
            'lastname',
            'mobileNum',
            'mobile',
            'email',
            'nationality',
            'residentStatus',
            'passportNumber',
            'passportIssueDate',
            'passportExpiryDate',
            'eidNumber',
            'eidIssueDate',
            'eidExpiryDate',
            'brokerCertificateNumber',
            'brokerCertificateIssueDate',
            'brokerCertificateExpiryDate',
            'issuingAuthority',
            'shareholdingPercentage',
            /* POA Name / Email were added after this list was written. Apex drops
               null wrapper fields from the response, so without a default the
               inputs received undefined and rendered the word "undefined". */
            'POA',
            'POAemail'
        ].forEach((key) => {
            if (out[key] == null) {
                out[key] = '';
            }
        });
        return out;
    }

    /* ---- Toast helper (relayed to the workspace shell) ---- */

    notify(message, variant) {
        this.dispatchEvent(new CustomEvent('toast', {
            detail: { message, variant },
            bubbles: true,
            composed: true
        }));
    }

    /* ---- Field error store ---- */

    setFieldError(memberId, field, message) {
        const all = { ...this.fieldErrors };
        const memberErrors = { ...(all[memberId] || {}) };
        if (message) {
            memberErrors[field] = message;
        } else {
            delete memberErrors[field];
        }
        if (Object.keys(memberErrors).length) {
            all[memberId] = memberErrors;
        } else {
            delete all[memberId];
        }
        this.fieldErrors = all;
    }

    clearMemberErrors(memberId, fields) {
        const all = { ...this.fieldErrors };
        const memberErrors = { ...(all[memberId] || {}) };
        fields.forEach((f) => delete memberErrors[f]);
        if (Object.keys(memberErrors).length) {
            all[memberId] = memberErrors;
        } else {
            delete all[memberId];
        }
        this.fieldErrors = all;
    }

    focusFirstError() {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            const errorCard = this.template.querySelector('.regf-field--error');
            if (!errorCard) return;
            errorCard.scrollIntoView({ block: 'center', behavior: 'smooth' });
            const control = errorCard.querySelector('.regf-field__control, .regf-upload__input');
            if (control) control.focus({ preventScroll: true });
        }, 0);
    }

    /* Field change handling. The legacy pair of handlers is merged: the
            broker-certificate branch only added the same date rules. */

    handleFieldChange(event) {
        const input = event.target;
        const id = input.dataset.id;
        const field = input.name;
        const value = input.type === 'checkbox' ? input.checked : input.value;
        const today = new Date().toISOString().split('T')[0];

        if (ISSUE_DATE_FIELDS.includes(field)) {
            this.setFieldError(id, field, value && value > today ? MSG_ISSUE_FUTURE : value ? '' : MSG_REQUIRED_SWEEP);
        }
        if (EXPIRY_DATE_FIELDS.includes(field)) {
            this.setFieldError(id, field, value && value < today ? MSG_EXPIRY_PAST : value ? '' : MSG_REQUIRED_SWEEP);
        }

        if (field === 'eidNumber') {
            // Legacy runs the dash-format regex on every change (including empty values).
            this.setFieldError(id, field, EID_REGEX.test(value) ? '' : MSG_EID_CHANGE);
        }

        if (field === 'email') {
            const duplicate = this.staffMembers.find((m) => m.email === value && m.id !== id);
            if (duplicate) {
                // Legacy: flag the duplicate and do NOT commit the value to state.
                this.setFieldError(id, field, 'You have already added an owner with this email.');
                return;
            }
            this.setFieldError(id, field, value ? '' : MSG_REQUIRED_SWEEP);
            this.staffMembers = this.staffMembers.map((m) =>
                m.id === id ? { ...m, email: value, isEmailLoqateValid: false, validateEmail: 'Validate Email' } : m
            );
            checkDuplicateEmailOrMobile({ value, type: 'email' })
                .then((result) => {
                    let message = '';
                    if (result === 'AGENT_AND_CONTACT') {
                        message = 'Email already exists in Registration Agent and Contact.';
                    } else if (result === 'AGENT') {
                        message = 'Email already exists in Registration Agent.';
                    } else if (result === 'CONTACT') {
                        message = 'Email already exists in Contact.';
                    }
                    if (message) this.setFieldError(id, field, message);
                })
                .catch(() => {
                    this.setFieldError(id, field, 'Error validating email. Try again.');
                });
            return;
        }

        if (field === 'mobile') {
            const duplicate = this.staffMembers.find((m) => m.mobile === value && m.id !== id);
            if (duplicate) {
                this.setFieldError(id, field, 'You have already added an owner with this mobile number.');
                return;
            }
            this.setFieldError(id, field, value ? '' : MSG_REQUIRED_SWEEP);
            this.staffMembers = this.staffMembers.map((m) =>
                m.id === id ? { ...m, mobile: value, isPhoneLoqateValid: false, validatePhone: 'Validate Phone' } : m
            );
            checkDuplicateEmailOrMobile({ value, type: 'mobile' })
                .then((result) => {
                    let message = '';
                    if (result === 'AGENT_AND_CONTACT') {
                        message = 'Mobile number already exists in Registration Agent and Contact.';
                    } else if (result === 'AGENT') {
                        message = 'Mobile number already exists in Registration Agent.';
                    } else if (result === 'CONTACT') {
                        message = 'Mobile number already exists in Contact.';
                    }
                    if (message) this.setFieldError(id, field, message);
                })
                .catch(() => {
                    this.setFieldError(id, field, 'Error validating mobile number. Try again.');
                });
            return;
        }

        if (field === 'isPrimaryOwner') {
            if (value === true) {
                const alreadyPrimary = this.staffMembers.find((m) => m.isPrimaryOwner && m.id !== id);
                if (alreadyPrimary) {
                    input.checked = false; // revert the DOM checkbox (state was never updated)
                    this.setFieldError(id, 'isPrimaryOwner', 'Only one Primary Owner can be selected.');
                    return;
                }
            }
            this.staffMembers = this.staffMembers.map((m) => ({
                ...m,
                isPrimaryOwner: m.id === id ? value : false
            }));
            this.setFieldError(id, 'isPrimaryOwner', '');
            return;
        }

        // Generic update (covers isBroker checkbox and all remaining fields).
        this.staffMembers = this.staffMembers.map((m) => (m.id === id ? { ...m, [field]: value } : m));

        if (field === 'isBroker' && value === false) {
            this.clearMemberErrors(id, BROKER_ERROR_KEYS);
        }
        if (field === 'shareholdingPercentage' && value) {
            const share = parseFloat(value);
            this.setFieldError(id, field, !Number.isNaN(share) && share > 100 ? MSG_SHARE_MAX : '');
        }
        if (REQUIRED_LIVE_FIELDS.includes(field)) {
            if (field === 'shareholdingPercentage' && value) return; // handled above
            this.setFieldError(id, field, value ? '' : MSG_REQUIRED_SWEEP);
        }
    }

    handleResidentStatusChange(event) {
        const id = event.target.dataset.id;
        const value = event.detail?.value ?? event.target.value;

        this.staffMembers = this.staffMembers.map((member) => {
            if (member.id !== id) return member;
            const updated = { ...member, residentStatus: value, isResident: value === 'Resident' };
            if (!updated.isResident) {
                // Non-resident: clear EID fields + EID uploads (legacy behavior).
                updated.eidNumber = null;
                updated.eidIssueDate = null;
                updated.eidExpiryDate = null;
                updated.isEmiratesIdFrontUploaded = false;
                updated.isEmiratesIdBackUploaded = false;
                updated.eidFrontbase64File = null;
                updated.eidFrontfileName = null;
                updated.eidBackbase64File = null;
                updated.eidBackfileName = null;
            }
            return updated;
        });

        this.setFieldError(id, 'residentStatus', value ? '' : MSG_REQUIRED_SWEEP);
        const member = this.staffMembers.find((m) => m.id === id);
        if (member && !member.isResident) {
            this.clearMemberErrors(id, RESIDENT_ERROR_KEYS);
        }
    }

    /* Digits-only guard on blur. The legacy handler wrote to an unused object
       and cleared the first mobile input in the DOM whatever the member. */
    handleNumericInput(event) {
        const id = event.target.dataset.id;
        const value = event.target.value;
        if (value && !/^[0-9]*$/.test(value)) {
            this.setFieldError(id, 'mobile', MSG_MOBILE_PATTERN);
        } else if (value) {
            this.setFieldError(id, 'mobile', '');
        }
    }

    /* ---- Loqate validation (per member; button label state on the member) ---- */

    handleValidatePhoneClick(event) {
        const button = event.currentTarget;
        const ownerId = button.dataset.id;
        button.innerText = 'Validating...';
        button.disabled = true;
        this.runValidatePhone(ownerId, button);
    }

    async runValidatePhone(ownerId, button) {
        const selectedOwner = this.staffMembers.find((member) => member.id === ownerId);
        const countryCode = selectedOwner?.mobileNum?.trim();
        const mobileNumber = selectedOwner?.mobile?.trim();

        if (!countryCode || !mobileNumber) {
            this.notify('Please select country code and enter mobile number.', 'error');
            button.innerText = 'Validate Phone';
            button.disabled = false;
            if (selectedOwner) {
                /* Legacy crashed here on an undefined variable; apply the
                   intended reset instead. */
                selectedOwner.isPhoneLoqateValid = false;
                selectedOwner.validatePhone = 'Validate Phone';
                this.staffMembers = [...this.staffMembers];
            }
            return;
        }

        const fullPhoneNumber = `+${countryCode}${mobileNumber}`;
        try {
            const isValid = await validatePhone({ phone: fullPhoneNumber });
            selectedOwner.isPhoneLoqateValid = isValid;
            selectedOwner.validatePhone = isValid ? 'Validated' : 'Validate Phone';
            button.innerText = selectedOwner.validatePhone;
            this.notify(isValid ? 'Phone number is valid.' : 'Phone number is invalid.', isValid ? 'success' : 'error');
        } catch (error) {
            selectedOwner.isPhoneLoqateValid = false;
            selectedOwner.validatePhone = 'Validate Phone';
            button.innerText = 'Validate Phone';
            this.notify(error.body?.message || 'Unable to validate phone number.', 'error');
        } finally {
            button.disabled = false;
            this.staffMembers = [...this.staffMembers]; // force re-render from state
        }
    }

    handleValidateEmailClick(event) {
        const button = event.currentTarget;
        const ownerId = button.dataset.id;
        button.innerText = 'Validating...';
        button.disabled = true;
        this.runValidateEmail(ownerId, button);
    }

    async runValidateEmail(ownerId, button) {
        const selectedOwner = this.staffMembers.find((member) => member.id === ownerId);

        if (!selectedOwner || !selectedOwner.email) {
            this.notify('Please enter an email address to validate.', 'error');
            button.innerText = 'Validate Email';
            button.disabled = false;
            if (selectedOwner) {
                /* Legacy marked an empty email as validated here. */
                selectedOwner.isEmailLoqateValid = false;
                selectedOwner.validateEmail = 'Validate Email';
                this.staffMembers = [...this.staffMembers];
            }
            return;
        }

        try {
            await validateCompanyEmail({ email: selectedOwner.email });
            selectedOwner.isEmailLoqateValid = true;
            selectedOwner.validateEmail = 'Validated';
            button.innerText = 'Validated';
            this.notify('The email address is valid.', 'success');
        } catch (error) {
            selectedOwner.isEmailLoqateValid = false;
            selectedOwner.validateEmail = 'Validate Email';
            button.innerText = 'Validate Email';
            this.notify(error.body?.message || 'The email address is invalid.', 'error');
        } finally {
            button.disabled = false;
            this.staffMembers = [...this.staffMembers];
        }
    }

    /* ---- Add / remove owners ---- */

    handleAddAgent() {
        if (this.staffMembers.length < 5) {
            const uniqueId = `temp_${Date.now()}_${Math.random().toString(36).substring(2, 5)}`;
            const newAgent = {
                id: uniqueId,
                tempId: Date.now().toString(),
                firstname: '',
                lastname: '',
                mobileNum: '',
                email: '',
                mobileCountryCode: '',
                passportIssueDate: '',
                eidIssueDate: '',
                nationality: '',
                mobile: '',
                passportNumber: '',
                passportExpiryDate: '',
                eidNumber: '',
                eidExpiryDate: '',
                shareholdingPercentage: '',
                POA: '',
                POAemail: '',
                isPrimaryOwner: false,
                isBroker: false,
                passportFrontbase64File: null,
                passportFinalbase64File: null,
                eidFrontbase64File: null,
                eidBackbase64File: null,
                visabase64File: null,
                poabase64File: null,
                label: `Owner Details ${this.staffMembers.length + 1}`,
                showRemoveIcon: true,
                validateEmail: 'Validate Email',
                validatePhone: 'Validate Phone'
            };
            this.staffMembers = [...this.staffMembers, newAgent];
            this.updateAddButtonState();
        } else {
            this.updateAddButtonState();
            // Legacy message string preserved (legacy cap is 5, message says 3).
            this.notify('Maximum of 3 Owners allowed.', 'warning');
        }
    }

    async handleRemoveAgent(event) {
        this.isLoading = true;
        const targetId = event.currentTarget.dataset.id;
        const index = this.staffMembers.findIndex((member) => member.id === targetId);
        if (index === -1) {
            this.isLoading = false;
            return;
        }
        const member = this.staffMembers[index];
        if (member.sfId || member.Id) {
            deleteAgent({ agentRecordId: member.sfId || member.Id, registrationId: this.registrationId, sessionId: this.sessionId })
                .then(() => {
                    this.staffMembers.splice(index, 1);
                    this.staffMembers = [...this.staffMembers];
                    this.clearMemberErrors(targetId, Object.keys(this.fieldErrors[targetId] || {}));
                    this.updateAddButtonState();
                    this.notify('Owner deleted successfully from database.', 'success');
                })
                .catch((error) => {
                    this.notify(error.body?.message || 'Failed to delete owner from database.', 'error');
                })
                .finally(() => {
                    this.isLoading = false;
                });
        } else {
            this.staffMembers.splice(index, 1);
            this.staffMembers = [...this.staffMembers];
            this.clearMemberErrors(targetId, Object.keys(this.fieldErrors[targetId] || {}));
            this.updateAddButtonState();
            this.isLoading = false;
        }
    }

    updateAddButtonState() {
        this.isAddButtonDisabled = this.staffMembers.length >= 5;
    }

    /* ---- Legacy value coercion helpers ---- */

    safeDate(v) {
        return v === undefined || v === null || v === '' ? null : v;
    }

    safeBool(v) {
        return v === true;
    }

    /* Submit-time validation sweep, replacing the legacy reportValidity pass. */

    validateAllMembers() {
        const today = new Date().toISOString().split('T')[0];
        const allErrors = {};
        let isValid = true;

        this.staffMembers.forEach((m) => {
            const e = { ...(this.fieldErrors[m.id] || {}) };
            const requireValue = (field) => {
                if (!m[field] && !e[field]) e[field] = MSG_REQUIRED_SWEEP;
            };

            // Required set = exactly the legacy `required` props.
            requireValue('firstname');
            requireValue('lastname');
            requireValue('nationality');
            requireValue('residentStatus');
            requireValue('mobile');
            requireValue('email');
            requireValue('passportNumber');
            requireValue('passportIssueDate');
            requireValue('passportExpiryDate');
            requireValue('shareholdingPercentage');

            if (m.mobile && !MOBILE_PATTERN.test(m.mobile)) e.mobile = MSG_MOBILE_PATTERN;
            if (m.email && !EMAIL_PATTERN.test(m.email)) e.email = MSG_EMAIL_FORMAT;
            /* POA Email is optional but must be well formed when supplied. */
            if (m.POAemail && !EMAIL_PATTERN.test(m.POAemail)) e.POAemail = MSG_EMAIL_FORMAT;

            if (m.passportIssueDate && m.passportIssueDate > today) e.passportIssueDate = MSG_ISSUE_FUTURE;
            if (m.passportExpiryDate && m.passportExpiryDate < today) e.passportExpiryDate = MSG_EXPIRY_PAST;

            const share = parseFloat(m.shareholdingPercentage);
            if (m.shareholdingPercentage && !Number.isNaN(share) && share > 100) {
                e.shareholdingPercentage = MSG_SHARE_MAX;
            }

            if (m.isResident) {
                requireValue('eidNumber');
                requireValue('eidIssueDate');
                requireValue('eidExpiryDate');
                if (m.eidNumber && !EID_REGEX.test(m.eidNumber)) e.eidNumber = MSG_EID_SUBMIT;
                if (m.eidIssueDate && m.eidIssueDate > today) e.eidIssueDate = MSG_ISSUE_FUTURE;
                if (m.eidExpiryDate && m.eidExpiryDate < today) e.eidExpiryDate = MSG_EXPIRY_PAST;
                if (!m.isEmiratesIdFrontUploaded) e.eidFrontUpload = MSG_REQUIRED_SWEEP;
                if (!m.isEmiratesIdBackUploaded) e.eidBackUpload = MSG_REQUIRED_SWEEP;
                if (!m.isVisaPageUploaded) e.visaUpload = MSG_REQUIRED_SWEEP;
            } else {
                RESIDENT_ERROR_KEYS.forEach((key) => delete e[key]);
            }

            if (m.isBroker) {
                requireValue('brokerCertificateNumber');
                requireValue('issuingAuthority');
                requireValue('brokerCertificateIssueDate');
                requireValue('brokerCertificateExpiryDate');
                if (m.brokerCertificateIssueDate && m.brokerCertificateIssueDate > today) {
                    e.brokerCertificateIssueDate = MSG_ISSUE_FUTURE;
                }
                if (m.brokerCertificateExpiryDate && m.brokerCertificateExpiryDate < today) {
                    e.brokerCertificateExpiryDate = MSG_EXPIRY_PAST;
                }
            } else {
                BROKER_ERROR_KEYS.forEach((key) => delete e[key]);
            }

            if (!m.isPassportFirstPageUploaded) e.passportFirstUpload = MSG_REQUIRED_SWEEP;
            if (!m.isPassportSignaturePageUploaded) e.passportSignatureUpload = MSG_REQUIRED_SWEEP;

            Object.keys(e).forEach((key) => {
                if (!e[key]) delete e[key];
            });
            if (Object.keys(e).length) {
                allErrors[m.id] = e;
                isValid = false;
            }
        });

        this.fieldErrors = allErrors;
        return isValid;
    }

    /* ---- Submit (same flow, gates, message strings and payload as legacy) ---- */

    @api
    async submitForm() {
        if (this.isDisabled) return; // BP-038 - view only: nothing is written
        // No step veil here: the workspace shows the full-screen loader for the
        // whole of Next, and a second spinner underneath it read as a defect.
        try {
            // 1) Field-level sweep across ALL members.
            if (!this.validateAllMembers()) {
                this.notify('Please fix the errors before proceeding.', 'error');
                this.focusFirstError();
                return;
            }

            // 2) Loqate email/phone gate.
            const invalidStaff = this.staffMembers.filter(
                (member) => !member.isPhoneLoqateValid || !member.isEmailLoqateValid
            );
            if (invalidStaff.length > 0) {
                this.notify('Please validate both Email and Mobile Number.', 'error');
                return;
            }

            // 3) Explicit required-field list (legacy step 3; catches the
            //    Country Code, which carries no required marker in markup).
            const requiredFields = [
                { field: 'firstname', label: 'First Name' },
                { field: 'lastname', label: 'Last Name' },
                { field: 'mobile', label: 'Mobile' },
                { field: 'mobileNum', label: 'Mobile country Code' },
                { field: 'email', label: 'Email' },
                { field: 'passportNumber', label: 'Passport Number' },
                { field: 'passportExpiryDate', label: 'Passport Expiry Date' },
                { field: 'shareholdingPercentage', label: 'Share holding percentage' }
            ];
            const missingFields = [];
            this.staffMembers.forEach((member, idx) => {
                const ownerLabel = `Owner ${idx + 1}`;
                requiredFields.forEach(({ field, label }) => {
                    if (!member[field]) {
                        missingFields.push(label);
                        this.setFieldError(member.id, field, MSG_REQUIRED_SUBMIT);
                    }
                });
                if (member.isResident) {
                    if (!member.eidNumber) missingFields.push('Emirates ID Number');
                    if (!member.eidExpiryDate) missingFields.push('EID Expiry Date');
                }
                if (!member.isPassportFirstPageUploaded) {
                    missingFields.push('Passport First Page ' + ownerLabel);
                }
                if (!member.isPassportSignaturePageUploaded) {
                    missingFields.push('Passport Signature Page ' + ownerLabel);
                }
                if (member.isResident) {
                    if (!member.isEmiratesIdFrontUploaded) missingFields.push('Emirates ID Front ' + ownerLabel);
                    if (!member.isEmiratesIdBackUploaded) missingFields.push('Emirates ID Back ' + ownerLabel);
                }
            });
            if (missingFields.length > 0) {
                this.notify(`Please fill in the following required fields: ${missingFields.join(', ')}`, 'error');
                this.focusFirstError();
                return;
            }

            // 4) Primary owner gate.
            const hasPrimaryOwner = this.staffMembers.some((member) => member.isPrimaryOwner === true);
            if (!hasPrimaryOwner) {
                this.notify('Please select at least one Primary Owner.', 'error');
                return;
            }

            // 5) Shareholding gates.
            const invalidShareholders = this.staffMembers.filter((member) => {
                const share = parseFloat(member.shareholdingPercentage);
                return isNaN(share) || share <= 0;
            });
            if (invalidShareholders.length > 0) {
                this.notify('Each owner’s Shareholding must be greater than 0.', 'error');
                return;
            }
            const totalShare = this.staffMembers.reduce(
                (sum, m) => sum + (parseFloat(m.shareholdingPercentage) || 0), 0
            );
            if (totalShare !== 100) {
                this.notify(`The total Shareholding percentage must equal 100%. Currently it's ${totalShare.toFixed(2)}%.`, 'error');
                return;
            }

            // 6) Change detection against the load-time snapshot.
            let hasChanges = false;
            if (this.staffMembers.length !== this.initialStaffMembers.length) {
                hasChanges = true;
            } else {
                for (let i = 0; i < this.staffMembers.length; i++) {
                    const current = this.staffMembers[i];
                    const initial = this.initialStaffMembers.find((init) => init.id === current.id);
                    if (!initial) {
                        hasChanges = true;
                        break;
                    }
                    for (const key in current) {
                        if (key !== 'id' && key !== 'label' && key !== 'showRemoveIcon') {
                            if (current[key] !== initial[key]) {
                                hasChanges = true;
                                break;
                            }
                        }
                    }
                    if (hasChanges) break;
                }
            }

            if (!hasChanges) {
                const recordIds = this.staffMembers.map((staff) => staff.Id).filter((id) => id);
                this.dispatchEvent(new CustomEvent('success', {
                    detail: { ids: recordIds },
                    bubbles: true,
                    composed: true
                }));
                this.notify('No changes were made to the Owner information.', 'info');
                return recordIds;
            }

            // 7) Build payload; only newly-flagged, valid-extension files are attached.
            const hasValidExt = (name) =>
                !!name && name.includes('.') &&
                VALID_FILE_EXTENSIONS.includes(name.split('.').pop().toLowerCase());

            const ensureTempId = (m) => {
                if (!m.tempId) {
                    m.tempId = window.crypto && window.crypto.randomUUID
                        ? window.crypto.randomUUID()
                        : `${Date.now()}_${Math.random()}`;
                }
                return m;
            };

            const addFileIfPresent = (src, dst, base64Key, nameKey) => {
                if (src[base64Key] && src[nameKey] && hasValidExt(src[nameKey])) {
                    dst[base64Key] = src[base64Key];
                    dst[nameKey] = src[nameKey];
                }
            };

            const normalizedMembers = this.staffMembers.map((m) => ensureTempId({ ...m }));

            const dataToSend = normalizedMembers.map((member) => {
                const payload = {
                    firstname: member.firstname ?? null,
                    lastname: member.lastname ?? null,
                    mobileNum: member.mobileNum ?? null,
                    email: member.email ?? null,
                    mobile: member.mobile ?? null,
                    passportNumber: member.passportNumber ?? null,

                    passportExpiryDate: this.safeDate(member.passportExpiryDate),
                    passportIssueDate: this.safeDate(member.passportIssueDate),
                    eidExpiryDate: this.safeDate(member.eidExpiryDate),
                    eidIssueDate: this.safeDate(member.eidIssueDate),

                    eidNumber: member.eidNumber ?? null,
                    nationality: member.nationality ?? null,

                    Brokertype: 'Owner',
                    registrationId: this.registrationId,
                    residentStatus: member.residentStatus ?? null,

                    Broker_Certificate_Number: this.safeBool(member.isBroker) ? member.brokerCertificateNumber ?? null : null,
                    Broker_Certificate_Issue_Date: this.safeBool(member.isBroker) ? this.safeDate(member.brokerCertificateIssueDate) : null,
                    Broker_Certificate_Expiry_Date: this.safeBool(member.isBroker) ? this.safeDate(member.brokerCertificateExpiryDate) : null,
                    Issuing_Authority: this.safeBool(member.isBroker) ? member.issuingAuthority ?? null : null,

                    sfId: member.sfId ?? null,
                    tempId: member.tempId,
                    shareholdingPercentage: member.shareholdingPercentage ?? null,

                    isPrimaryOwner: this.safeBool(member.isPrimaryOwner),
                    isBroker: this.safeBool(member.isBroker),
                    isPrimaryagencyadmin: false,

                    // written to the OWNER's Registration_Agent__c row.
                    POA: member.POA ?? null,
                    POAemail: member.POAemail ?? null
                };

                if (member.isPassportFirstPageUploaded) addFileIfPresent(member, payload, 'passportFrontbase64File', 'passportFrontfileName');
                if (member.isPassportSignaturePageUploaded) addFileIfPresent(member, payload, 'passportFinalbase64File', 'passportFinalfileName');
                if (member.isEmiratesIdFrontUploaded) addFileIfPresent(member, payload, 'eidFrontbase64File', 'eidFrontfileName');
                if (member.isEmiratesIdBackUploaded) addFileIfPresent(member, payload, 'eidBackbase64File', 'eidBackfileName');
                if (member.isVisaPageUploaded) addFileIfPresent(member, payload, 'visabase64File', 'visabasefileName');
                if (member.isPoaUploaded) addFileIfPresent(member, payload, 'poabase64File', 'poafileName');

                return payload;
            });

            // 8) Save.
            const recordIds = await saveAgentsWithFiles({ agentDataList: dataToSend, registrationId: this.registrationId, sessionId: this.sessionId });

            // 9) Map returned ids back onto members (as legacy: only effective
            //    when Apex returns a tempId-keyed map).
            this.staffMembers = normalizedMembers.map((m) => {
                const realId = recordIds[m.tempId];
                return {
                    ...m,
                    sfId: realId || m.sfId,
                    Id: realId || m.Id
                };
            });

            // 10) Success.
            this.dispatchEvent(new CustomEvent('success', {
                detail: { ids: recordIds },
                bubbles: true,
                composed: true
            }));
            this.notify('Owner details saved.', 'success');
            return recordIds;
        } catch (error) {
            this.dispatchEvent(new CustomEvent('error', {
                detail: { message: error.body?.message || 'Failed to save owner information.' },
                bubbles: true,
                composed: true
            }));
            throw error;
        }
    }

    /* ---- File upload / preview / delete ---- */

    base64ToBytes(base64) {
        const byteCharacters = atob(base64);
        const byteNumbers = new Array(byteCharacters.length);
        for (let i = 0; i < byteCharacters.length; i++) {
            byteNumbers[i] = byteCharacters.charCodeAt(i);
        }
        return new Uint8Array(byteNumbers);
    }

    getRealMimeType(base64Body) {
        const header = base64Body.substring(0, 20);
        if (header.startsWith('/9j/')) return 'image/jpeg';
        if (header.startsWith('iVBOR')) return 'image/png';
        if (header.startsWith('JVBER')) return 'application/pdf';
        return 'application/octet-stream';
    }

    handleFileChange(event) {
        const input = event.target;
        const id = input.dataset.id;
        const labelName = input.dataset.label;
        const file = input.files && input.files[0];

        if (!file) return;

        if (file.size > MAX_FILE_SIZE) {
            this.notify(`File "${file.name}" exceeds 2 MB limit. Please upload a smaller file.`, 'error');
            input.value = '';
            return;
        }

        const fileExtension = (file.name || '').split('.').pop().toLowerCase();
        if (!VALID_FILE_EXTENSIONS.includes(fileExtension)) {
            this.notify('Only .pdf and .jpg files are allowed.', 'error');
            input.value = '';
            return;
        }

        const reader = new FileReader();
        reader.onload = () => {
            try {
                const dataUrl = reader.result;
                const base64 = dataUrl.substring(dataUrl.indexOf(',') + 1);
                const mimeType = fileExtension === 'pdf'
                    ? 'application/pdf'
                    : fileExtension === 'jpg' || fileExtension === 'jpeg'
                        ? 'image/jpeg'
                        : file.type || 'application/octet-stream';

                const blob = new Blob([this.base64ToBytes(base64)], { type: mimeType });
                const previewUrl = URL.createObjectURL(blob);

                const slot = FILE_SLOTS[labelName];
                if (!slot) return;

                const patch = {
                    [slot.base64]: base64,
                    [slot.name]: file.name,
                    [slot.preview]: previewUrl,
                    [slot.flag]: true
                };
                this.staffMembers = this.staffMembers.map((member) =>
                    member.id === id ? { ...member, ...patch } : member
                );
                if (slot.errorKey) this.setFieldError(id, slot.errorKey, '');
            } catch (e) {
                this.notify('Something went wrong while reading the file.', 'error');
            }
        };
        reader.readAsDataURL(file);
    }

    /* Preview covers all five documents, both server-prefilled base64 and fresh
       in-session uploads. Legacy broke the EID-Back chip on an `ata-id` typo
       and only handled data: URLs. */
    handlePreview(event) {
        const id = event.currentTarget.dataset.id;
        const labelName = event.currentTarget.dataset.label;
        const member = this.staffMembers.find((m) => m.id === id);
        const slot = FILE_SLOTS[labelName];
        if (!member || !slot) return;

        let base64Body = member[slot.base64];
        if (!base64Body) {
            const previewUrl = member[slot.preview];
            if (previewUrl && String(previewUrl).startsWith('data:')) {
                base64Body = String(previewUrl).split(',')[1];
            }
        }
        if (!base64Body) {
            this.notify('No file available to preview.', 'error');
            return;
        }

        try {
            const realMimeType = this.getRealMimeType(base64Body);
            const blob = new Blob([this.base64ToBytes(base64Body)], { type: realMimeType });
            const blobUrl = URL.createObjectURL(blob);
            this.openInNewTab(blobUrl);
        } catch (error) {
            this.notify('Unable to preview the file.', 'error');
        }
    }

    /* window.open(blobUrl) opens the tab but then throws inside the site's
       Lightning Web Security wrapper, which cannot hand back a window proxy for
       a blob: page, so the user saw the preview AND an error toast. An anchor
       click with noopener returns no window object, so nothing is wrapped. */
    openInNewTab(url) {
        const link = document.createElement('a');
        link.href = url;
        link.target = '_blank';
        link.rel = 'noopener noreferrer';
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
        // Give the new tab time to load the blob before releasing it.
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => URL.revokeObjectURL(url), 60000);
    }

    handleRemoveFile(event) {
        const id = event.currentTarget.dataset.id;
        const labelName = event.currentTarget.dataset.label;
        const slot = FILE_SLOTS[labelName];
        if (!slot) return;

        // Legacy clears the base64/preview/flag but keeps the stored file name.
        const patch = {
            file: null,
            [slot.base64]: null,
            [slot.preview]: null,
            [slot.flag]: false
        };
        this.staffMembers = this.staffMembers.map((member) =>
            member.id === id ? { ...member, ...patch } : member
        );
    }
}