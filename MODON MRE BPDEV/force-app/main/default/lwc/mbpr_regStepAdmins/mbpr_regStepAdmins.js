/**
 * Component Name: mbpr_regStepAdmins
 * Description: Step 4, Agency Admin Information. Repeating form over
 *                  Registration_Agent__c rows with Brokertype 'Agency Admin'.
 * Author: Aurelix IT
 *
 * Parent is mbpr_registrationWorkspace. submitForm dispatches 'success' with
 * {ids:[...]}; also emits 'error' and 'toast'.
 */
import { LightningElement, api, track } from 'lwc';
import getAgents from '@salesforce/apex/MBP_RegistrationGatewayController.getAgents';
import saveAgents from '@salesforce/apex/MBP_RegistrationGatewayController.saveAgents';
import deleteAgent from '@salesforce/apex/MBP_RegistrationGatewayController.deleteAgent';
import getRegistration from '@salesforce/apex/MBP_RegistrationGatewayController.getRegistration';
import uploadFile from '@salesforce/apex/MBP_RegistrationGatewayController.uploadFile';
import validateCompanyEmail from '@salesforce/apex/MBP_LoqateIntegration.validateEmail';
import validatePhone from '@salesforce/apex/MBP_LoqateIntegration.validatePhone';
import getExistingFile from '@salesforce/apex/MBP_RegistrationGatewayController.getExistingFile';
import deleteFile from '@salesforce/apex/MBP_RegistrationGatewayController.deleteFile';
import saveAgentsWithFiles from '@salesforce/apex/MBP_RegistrationGatewayController.saveAgentsWithFiles';
import checkDuplicateEmailOrMobile from '@salesforce/apex/MBP_RegistrationGatewayController.checkDuplicateEmailOrMobile';
import regFormStyles from 'c/mbpr_regFormStyles';
import { countryOptions } from './countries';

// Ported verbatim from the legacy bundle's import list; these are not
// referenced by any live code path there either (kept for import parity):
// saveAgents, deleteAgent, uploadFile, getExistingFile, deleteFile.
const UNUSED_LEGACY_APEX = [
    saveAgents,
    deleteAgent,
    uploadFile,
    getExistingFile,
    deleteFile
];

const VALID_EXTENSIONS = ['pdf', 'jpg', 'jpeg'];
const MAX_FILE_SIZE = 2 * 1024 * 1024; // 2MB, as legacy
const EID_REGEX = /^784-\d{4}-\d{7}-\d{1}$/;
const MOBILE_REGEX = /^\+?[1-9][0-9]{7,14}$/; // legacy lightning-input pattern
const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const ISSUE_DATE_FIELDS = ['passportIssueDate', 'eidIssueDate'];
const EXPIRY_DATE_FIELDS = ['passportExpiryDate', 'eidExpiryDate'];

// data-label -> member state keys. Insertion order matches the legacy payload
// file-pair order (passportFront, passportFinal, eidFront, eidBack, visa, poa).
const FILE_MAP = {
    Passport_First_Page: {
        base64: 'passportFrontbase64File',
        name: 'passportFrontfileName',
        preview: 'passportPreviewUrl',
        flag: 'isPassportFirstPageUploaded'
    },
    Passport_Signature_Page: {
        base64: 'passportFinalbase64File',
        name: 'passportFinalfileName',
        preview: 'passportFinalPreviewUrl',
        flag: 'isPassportSignaturePageUploaded'
    },
    Emirates_ID_Front: {
        base64: 'eidFrontbase64File',
        name: 'eidFrontfileName',
        preview: 'eidFrontPreviewUrl',
        flag: 'isEmiratesIdFrontUploaded'
    },
    Emirates_ID_Back: {
        base64: 'eidBackbase64File',
        name: 'eidBackfileName',
        preview: 'eidBackPreviewUrl',
        flag: 'isEmiratesIdBackUploaded'
    },
    Visa_Page: {
        base64: 'visabase64File',
        name: 'visabasefileName',
        preview: 'visaPreviewUrl',
        flag: 'isVisaPageUploaded'
    },
    POA_Document: {
        base64: 'poabase64File',
        name: 'poafileName',
        preview: 'poaPreviewUrl',
        flag: 'isPoaDocumentUploaded'
    }
};

// Same country-code set/order as the legacy inline mobCountryOptions getter.
const MOB_COUNTRY_CODES = [
    '1', '20', '27', '30', '31', '32', '33', '34', '36', '39',
    '40', '41', '43', '44', '45', '46', '47', '48', '49', '51',
    '52', '53', '54', '55', '56', '57', '58', '60', '61', '62',
    '63', '64', '65', '66', '81', '82', '84', '86', '90', '91',
    '92', '93', '94', '95', '98', '211', '212', '213', '216', '218',
    '220', '221', '222', '223', '224', '225', '226', '227', '228', '229',
    '230', '231', '232', '233', '234', '235', '236', '237', '238', '239',
    '240', '241', '242', '243', '244', '245', '246', '248', '249', '250',
    '251', '252', '253', '254', '255', '256', '257', '258', '260', '261',
    '262', '263', '264', '265', '266', '267', '268', '269', '290', '291',
    '297', '298', '299', '350', '351', '352', '353', '354', '355', '356',
    '357', '358', '359', '370', '371', '372', '373', '374', '375', '376',
    '377', '378', '380', '381', '382', '385', '386', '387', '389', '420',
    '421', '423', '500', '501', '502', '503', '504', '505', '506', '507',
    '508', '509', '590', '591', '592', '593', '594', '595', '596', '597',
    '598', '599', '670', '672', '673', '674', '675', '676', '677', '678',
    '679', '680', '681', '682', '683', '685', '686', '687', '688', '689',
    '690', '691', '692', '850', '852', '853', '855', '856', '870', '880',
    '881', '882', '883', '886', '960', '961', '962', '963', '964', '965',
    '966', '967', '968', '970', '971', '972', '973', '974', '975', '976',
    '977', '992', '993', '994', '995', '996', '998'
];

const TEXT_FIELDS = [
    'firstname', 'lastname', 'nationality', 'residentStatus', 'mobileNum', 'mobile', 'email',
    'passportNumber', 'passportIssueDate', 'passportExpiryDate',
    'eidNumber', 'eidIssueDate', 'eidExpiryDate', 'POA', 'POAemail'
];

/* Errors that only apply to a UAE resident; cleared when the row switches to
   Non-Resident, the same keys the Owners step clears. */
const RESIDENT_ERROR_KEYS = ['eidNumber', 'eidIssueDate', 'eidExpiryDate', 'Emirates_ID_Front', 'Emirates_ID_Back', 'Visa_Page'];

// Exact legacy template `required` props. Country Code (mobileNum) carries no
// required marker in the legacy template (it is enforced at submit only).
// POA Name / Email / Document are no longer captured on this step -
// their values are still loaded and passed through so drafts keep them.
const REQUIRED_STAR_FIELDS = new Set([
    'firstname', 'lastname', 'nationality', 'residentStatus', 'mobile', 'email',
    'passportNumber', 'passportIssueDate', 'passportExpiryDate',
    'eidNumber', 'eidIssueDate', 'eidExpiryDate'
]);

const UPLOAD_LABELS = Object.keys(FILE_MAP);
const REQUIRED_UPLOADS = new Set([
    'Passport_First_Page', 'Passport_Signature_Page',
    'Emirates_ID_Front', 'Emirates_ID_Back', 'Visa_Page'
]); // POA_Document is optional, as legacy

export default class MbprRegStepAdmins extends LightningElement {
    static stylesheets = [regFormStyles];

    @api objectApiName;
    @api registrationId;
    @api sessionId;
    @api registrationStatus;
    @api mode;

    @track staffMembers = [];
    @track fieldErrors = {}; // { [memberId]: { [fieldOrUploadLabel]: message } }

    countryOptionsList = countryOptions;
    initialStaffMembers = [];
    isLoading = false;

    /* BP-038 - the workspace's lock (status not Draft) or this step's own
       status check; templates keep binding disabled={isDisabled}. */
    @api locked = false;
    statusLocked = false;

    get isDisabled() {
        return Boolean(this.locked) || this.statusLocked;
    }
    showEIDFields = false;
    // Legacy declared isInternational but never assigned it, so the EID Front
    // gate `showEIDFields && !isInternational` always resolves to showEIDFields.
    // Preserved as-is.
    isInternational = false;
    registrationTypeFromParent;
    _pendingFocus = false;

    /* Same two values as the Owners step and the UAE_Resident_Status__c picklist. */
    residentStatusOptions = [
        { label: 'Resident', value: 'Resident' },
        { label: 'Non-Resident', value: 'Non-Resident' }
    ];

    get mobCountryOptions() {
        return MOB_COUNTRY_CODES.map((code) => ({ label: code, value: code }));
    }

    get showDeleteIcon() {
        return this.mode?.toLowerCase() === 'draft' && this.registrationStatus !== 'Submitted' && !this.isDisabled;
    }

    get showEidFrontBlock() {
        return this.showEIDFields && !this.isInternational;
    }

    get memberViews() {
        return this.staffMembers.map((member) => {
            const err = this.fieldErrors[member.id] || {};
            const cls = {};
            TEXT_FIELDS.forEach((field) => {
                let value = 'regf-field';
                if (REQUIRED_STAR_FIELDS.has(field)) {
                    value += ' regf-field--required';
                }
                if (field === 'mobileNum') {
                    value += ' regf-field--code';
                }
                if (err[field]) {
                    value += ' regf-field--error';
                }
                cls[field] = value;
            });
            UPLOAD_LABELS.forEach((label) => {
                let value = 'regf-upload';
                if (REQUIRED_UPLOADS.has(label)) {
                    value += ' regf-upload--required';
                }
                if (this.isDisabled) {
                    value += ' regf-upload--disabled';
                }
                if (err[label]) {
                    value += ' regf-field--error';
                }
                cls[label] = value;
            });
            cls.isPrimaryagencyadmin = err.isPrimaryagencyadmin ? 'regf-check regf-check--error' : 'regf-check';
            // Emirates ID is per row now: UAE Broker registration AND this admin
            // is a UAE resident (same rule as the Owners step).
            const showEid = this.showEIDFields && !!member.isResident;
            return {
                ...member,
                err,
                cls,
                showEid,
                showEidFront: showEid && !this.isInternational,
                phoneBtnDisabled: this.isDisabled || !!member.isValidatingPhone,
                emailBtnDisabled: this.isDisabled || !!member.isValidatingEmail
            };
        });
    }

    async connectedCallback() {
        this.isLoading = true;
        try {
            if (this.registrationId) {
                const registrationObj = await getRegistration({
                    registrationId: this.registrationId,
                    sessionId: this.sessionId
                });
                this.registrationTypeFromParent = registrationObj.Type_of_Registration__c?.trim()?.toLowerCase();
                if (registrationObj.Status__c !== 'Draft') {
                    this.statusLocked = true;
                }
                await this.loadRegistrationAgents();
                this.initialStaffMembers = JSON.parse(JSON.stringify(this.staffMembers));
            }
        } catch (error) {
            this.dispatchError('Unable to load registration data: ' + (error.body?.message || 'Unknown error'));
        } finally {
            this.isLoading = false;
        }
    }

    renderedCallback() {
        // Hand-rolled <select> elements cannot take value via template binding;
        // sync them from state on every render.
        this.template.querySelectorAll('select[data-id]').forEach((select) => {
            const member = this.staffMembers.find((m) => String(m.id) === select.dataset.id);
            if (member) {
                const value = member[select.name] == null ? '' : String(member[select.name]);
                if (select.value !== value) {
                    select.value = value;
                }
            }
        });

        if (this._pendingFocus) {
            this._pendingFocus = false;
            const firstInvalid = this.template.querySelector(
                '.regf-field--error .regf-field__control, .regf-field--error .regf-upload__input, .regf-check--error input'
            );
            if (firstInvalid) {
                firstInvalid.focus();
                firstInvalid.scrollIntoView({ block: 'center', behavior: 'smooth' });
            }
        }
    }

    async loadRegistrationAgents() {
        this.isLoading = true;
        try {
            const agents = await getAgents({
                registrationId: this.registrationId,
                sessionId: this.sessionId
            });
            let regType = '';
            if (agents.length > 0 && agents[0].registrationType) {
                regType = agents[0].registrationType?.trim()?.toLowerCase() || '';
            } else if (this.registrationTypeFromParent) {
                regType = this.registrationTypeFromParent?.trim()?.toLowerCase() || '';
            }
            this.showEIDFields = regType === 'uae broker';

            const staffAgents = agents.filter((agent) => agent.Brokertype === 'Agency Admin');
            if (staffAgents.length > 0) {
                this.staffMembers = staffAgents.map((agent, index) => this.withMemberDisplayDefaults({
                    ...agent,
                    // Legacy fell back to Date.now alone, which collides when
                    // several rows lack a tempId; the index salt keeps ids unique.
                    id: agent.tempId || `${Date.now()}_${index}`,
                    label: `Agency Admin Details ${index + 1}`,
                    firstname: agent.firstname,
                    passportIssueDate: agent.passportIssueDate,
                    eidIssueDate: agent.eidIssueDate,
                    nationality: agent.nationality,
                    residentStatus: agent.residentStatus,
                    isResident: agent.residentStatus === 'Resident',
                    POA: agent.POA,
                    POAemail: agent.POAemail,
                    lastname: agent.lastname,
                    mobileNum: agent.mobileNum,
                    email: agent.email,
                    mobile: agent.mobile,
                    passportNumber: agent.passportNumber,
                    passportExpiryDate: agent.passportExpiryDate,
                    eidNumber: agent.eidNumber,
                    eidExpiryDate: agent.eidExpiryDate,
                    Brokertype: agent.Brokertype,
                    registrationId: this.registrationId,
                    sfId: agent.sfId,
                    isPrimaryagencyadmin: !!agent.isPrimaryagencyadmin,

                    passportFrontbase64File: agent.passportFrontbase64File,
                    passportPreviewUrl: agent.passportFrontbase64File ? `data:application/pdf;base64,${agent.passportFrontbase64File}` : null,
                    isPassportFirstPageUploaded: !!agent.passportFrontbase64File,
                    passportFrontfileName: agent.passportFrontfileName,
                    isPrimaryOwner: agent.isPrimaryOwner,

                    passportFinalbase64File: agent.passportFinalbase64File,
                    passportFinalPreviewUrl: agent.passportFinalbase64File ? `data:application/pdf;base64,${agent.passportFinalbase64File}` : null,
                    isPassportSignaturePageUploaded: !!agent.passportFinalbase64File,
                    passportFinalfileName: agent.passportFinalfileName,

                    poabase64File: agent.poabase64File,
                    poaPreviewUrl: agent.poabase64File ? `data:application/pdf;base64,${agent.poabase64File}` : null,
                    isPoaDocumentUploaded: !!agent.poabase64File,
                    poafileName: agent.poafileName,

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

                    tempId: agent.id,
                    // Legacy cross-wired these two button labels (phone label
                    // derived from email presence and vice versa); the validity
                    // flags below were correct, so only the captions are fixed.
                    isPhoneLoqateValid: agent.mobileNum != null && agent.mobile != null,
                    isEmailLoqateValid: agent.email != null,
                    validatePhone: (agent.mobileNum != null && agent.mobile != null) ? 'Validated' : 'Validate Phone',
                    validateEmail: agent.email != null ? 'Validated' : 'Validate Email',
                    isValidatingPhone: false,
                    isValidatingEmail: false
                }));
            } else {
                const newAgent = {
                    id: Date.now().toString(), // temp ID
                    firstname: '',
                    POA: '',
                    POAemail: '',
                    lastname: '',
                    passportIssueDate: '',
                    eidIssueDate: '',
                    nationality: '',
                    residentStatus: '',
                    isResident: false,
                    mobileNum: '',
                    email: '',
                    mobile: '',
                    passportNumber: '',
                    passportExpiryDate: '',
                    eidNumber: '',
                    eidExpiryDate: '',
                    isPrimaryOwner: false,
                    isPrimaryagencyadmin: false,
                    passportFrontbase64File: null,
                    poabase64File: null,
                    passportFinalbase64File: null,
                    eidFrontbase64File: null,
                    eidBackbase64File: null,
                    visabase64File: null,
                    label: 'Agency Admin',
                    validateEmail: 'Validate Email',
                    validatePhone: 'Validate Phone',
                    isEmailLoqateValid: false,
                    isPhoneLoqateValid: false,
                    isValidatingPhone: false,
                    isValidatingEmail: false
                };
                this.staffMembers = [...this.staffMembers, newAgent];
            }
        } catch (error) {
            this.dispatchError('Unable to load Registration Agents: ' + (error.body?.message || error.message));
        } finally {
            this.isLoading = false;
        }
    }

    /* ---------------- field changes ---------------- */

    handleFieldChange(event) {
        const id = event.target.dataset.id;
        const field = event.target.name;
        const value = event.target.value;

        this.clearFieldError(id, field);

        const today = new Date().toISOString().split('T')[0];
        if (ISSUE_DATE_FIELDS.includes(field) && value && value > today) {
            this.setFieldError(id, field, 'Issue Date cannot be in the future.');
        }
        if (EXPIRY_DATE_FIELDS.includes(field) && value && value < today) {
            this.setFieldError(id, field, 'Expiry Date cannot be in the past.');
        }

        this.updateMember(id, { [field]: value });

        if (field === 'email') {
            const duplicate = this.staffMembers.find(
                (member) => member.email === value && member.id !== id
            );
            if (duplicate) {
                this.setFieldError(id, 'email', 'You have already added an owner with this email.');
                return;
            }
            this.updateMember(id, { isEmailLoqateValid: false, validateEmail: 'Validate Email' });
            checkDuplicateEmailOrMobile({ value, type: 'email' })
                .then((result) => {
                    let message = '';
                    if (result === 'AGENT_AND_CONTACT' || result === 'AGENT' || result === 'CONTACT') {
                        message = 'This email has already been added for an owner on the previous page, and a matching record exists in the salesforce.';
                    }
                    if (message) {
                        this.setFieldError(id, 'email', message);
                    } else {
                        this.clearFieldError(id, 'email');
                    }
                })
                .catch(() => {
                    this.setFieldError(id, 'email', 'Error validating email. Try again.');
                });
        }

        if (field === 'mobile') {
            const duplicate = this.staffMembers.find(
                (member) => member.mobile === value && member.id !== id
            );
            if (duplicate) {
                this.setFieldError(id, 'mobile', 'You have already added an owner with this mobile number.');
                return;
            }
            this.updateMember(id, { isPhoneLoqateValid: false, validatePhone: 'Validate Phone' });
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
                    if (message) {
                        this.setFieldError(id, 'mobile', message);
                    } else {
                        this.clearFieldError(id, 'mobile');
                    }
                })
                .catch(() => {
                    this.setFieldError(id, 'mobile', 'Error validating mobile number. Try again.');
                });
        }
    }

    handleFieldChange1(event) {
        const id = event.target.dataset.id;
        const field = event.target.name;
        const value = event.target.type === 'checkbox' ? event.target.checked : event.target.value;

        if (field === 'eidNumber') {
            if (!EID_REGEX.test(value)) {
                this.setFieldError(id, field, 'Emirates ID must be in the format: 784-XXXX-XXXXXXX-X. Only digits and dashes allowed in correct positions.');
            } else {
                this.clearFieldError(id, field);
            }
        }
        if (field === 'isPrimaryagencyadmin') {
            // One primary admin per agency, same rule as Primary Owner and the
            // post-registration Agents page: ticking a row clears the others.
            // The requirement is on the group, so the error clears on every row.
            this.staffMembers = this.staffMembers.map((m) => ({
                ...m,
                isPrimaryagencyadmin: m.id === id ? value : (value ? false : m.isPrimaryagencyadmin)
            }));
            this.staffMembers.forEach((m) => this.clearFieldError(m.id, field));
            return;
        }

        this.updateMember(id, { [field]: value });
    }

    /* Mirrors the Owners step: a Non-Resident admin has no Emirates ID, so the
       EID fields and EID uploads are cleared and their errors dropped. Visa and
       passport data are left alone. */
    handleResidentStatusChange(event) {
        const id = event.target.dataset.id;
        const value = event.target.value;

        this.staffMembers = this.staffMembers.map((member) => {
            if (member.id !== id) return member;
            const updated = { ...member, residentStatus: value, isResident: value === 'Resident' };
            if (!updated.isResident) {
                updated.eidNumber = null;
                updated.eidIssueDate = null;
                updated.eidExpiryDate = null;
                updated.isEmiratesIdFrontUploaded = false;
                updated.isEmiratesIdBackUploaded = false;
                updated.eidFrontbase64File = null;
                updated.eidFrontfileName = null;
                updated.eidFrontPreviewUrl = null;
                updated.eidBackbase64File = null;
                updated.eidBackfileName = null;
                updated.eidBackPreviewUrl = null;
            }
            return updated;
        });

        if (value) {
            this.clearFieldError(id, 'residentStatus');
        } else {
            this.setFieldError(id, 'residentStatus', 'Complete this field.');
        }
        if (value !== 'Resident') {
            RESIDENT_ERROR_KEYS.forEach((key) => this.clearFieldError(id, key));
        }
    }

    handleNumericInput(event) {
        const id = event.target.dataset.id;
        const value = event.target.value;
        // Legacy blur guard: digits only, otherwise the field is cleared.
        if (value && !/^[0-9]*$/.test(value)) {
            this.updateMember(id, { mobile: '' });
            this.setFieldError(id, 'mobile', 'Please enter only numbers');
        } else {
            this.clearFieldError(id, 'mobile');
        }
    }

    /* ---------------- Loqate validation ---------------- */

    handleValidatePhoneClick(event) {
        this.validatePhoneFor(event.currentTarget.dataset.id);
    }

    async validatePhoneFor(memberId) {
        const member = this.staffMembers.find((m) => m.id === memberId);
        if (!member) {
            return;
        }
        const countryCode = member.mobileNum?.trim();
        const mobileNumber = member.mobile?.trim();
        this.updateMember(memberId, { validatePhone: 'Validating...', isValidatingPhone: true });

        if (!countryCode || !mobileNumber) {
            this.dispatchToast('Please select country code and enter mobile number.', 'error');
            this.updateMember(memberId, {
                validatePhone: 'Validate Phone',
                isPhoneLoqateValid: false,
                isValidatingPhone: false
            });
            return;
        }

        try {
            const isValid = await validatePhone({ phone: `+${countryCode}${mobileNumber}` });
            this.updateMember(memberId, {
                isPhoneLoqateValid: isValid,
                validatePhone: isValid ? 'Validated' : 'Validate Phone'
            });
            this.dispatchToast(
                isValid ? 'Phone number is valid.' : 'Phone number is invalid.',
                isValid ? 'success' : 'error'
            );
        } catch (error) {
            this.updateMember(memberId, { isPhoneLoqateValid: false, validatePhone: 'Validate Phone' });
            this.dispatchToast(error.body?.message || 'Unable to validate phone number.', 'error');
        } finally {
            this.updateMember(memberId, { isValidatingPhone: false });
        }
    }

    handleValidateEmailClick(event) {
        this.validateEmailFor(event.currentTarget.dataset.id);
    }

    async validateEmailFor(memberId) {
        const member = this.staffMembers.find((m) => m.id === memberId);
        if (!member) {
            return;
        }
        this.updateMember(memberId, { validateEmail: 'Validating...', isValidatingEmail: true });

        if (!member.email) {
            // Legacy marked the member email-valid in this guard branch; that
            // defeated the Loqate gate, so the flag stays false here.
            this.dispatchToast('Please enter an email address to validate.', 'error');
            this.updateMember(memberId, {
                validateEmail: 'Validate Email',
                isEmailLoqateValid: false,
                isValidatingEmail: false
            });
            return;
        }

        try {
            await validateCompanyEmail({ email: member.email });
            this.updateMember(memberId, { isEmailLoqateValid: true, validateEmail: 'Validated' });
            this.dispatchToast('The email address is valid.', 'success');
        } catch (error) {
            this.updateMember(memberId, { isEmailLoqateValid: false, validateEmail: 'Validate Email' });
            this.dispatchToast(error.body?.message || 'The email address is invalid.', 'error');
        } finally {
            this.updateMember(memberId, { isValidatingEmail: false });
        }
    }

    /* ---------------- files ---------------- */

    handleFileChange(event) {
        const id = event.target.dataset.id;
        const labelName = event.target.dataset.label;
        const file = event.target.files && event.target.files[0];
        if (!file) {
            return;
        }

        const fileExtension = (file.name || '').split('.').pop().toLowerCase();
        if (!VALID_EXTENSIONS.includes(fileExtension)) {
            this.dispatchToast('Only .pdf and .jpg files are allowed.', 'error');
            return;
        }
        if (file.size > MAX_FILE_SIZE) {
            this.dispatchToast('File size must be less than 2 MB.', 'error');
            return;
        }
        const keys = FILE_MAP[labelName];
        if (!keys) {
            return;
        }

        const reader = new FileReader();
        reader.onload = () => {
            try {
                const dataUrl = reader.result;
                const base64 = dataUrl.substring(dataUrl.indexOf(',') + 1);

                let mimeType;
                if (fileExtension === 'pdf') {
                    mimeType = 'application/pdf';
                } else if (fileExtension === 'jpg' || fileExtension === 'jpeg') {
                    mimeType = 'image/jpeg';
                } else {
                    mimeType = file.type || 'application/octet-stream';
                }

                const byteCharacters = atob(base64);
                const bytes = new Uint8Array(byteCharacters.length);
                for (let i = 0; i < byteCharacters.length; i++) {
                    bytes[i] = byteCharacters.charCodeAt(i);
                }
                const previewUrl = URL.createObjectURL(new Blob([bytes], { type: mimeType }));

                this.updateMember(id, {
                    [keys.base64]: base64,
                    [keys.name]: file.name,
                    [keys.preview]: previewUrl,
                    [keys.flag]: true
                });
                this.clearFieldError(id, labelName);
            } catch (e) {
                this.dispatchToast('Something went wrong while reading the file.', 'error');
            }
        };
        reader.readAsDataURL(file);
    }

    handlePreview(event) {
        const id = event.currentTarget.dataset.id;
        const labelName = event.currentTarget.dataset.label;
        const member = this.staffMembers.find((m) => m.id === id);
        const keys = FILE_MAP[labelName];
        if (!member || !keys) {
            return;
        }
        const previewUrl = member[keys.preview];
        if (previewUrl && previewUrl.startsWith('data:')) {
            // Prefilled files arrive as data: URLs stamped application/pdf;
            // detect the real MIME type from the payload before opening.
            const base64 = previewUrl.split(',')[1] || '';
            const header = base64.substring(0, 20);
            let mimeType = 'application/octet-stream';
            if (header.startsWith('/9j/')) {
                mimeType = 'image/jpeg';
            } else if (header.startsWith('iVBOR')) {
                mimeType = 'image/png';
            } else if (header.startsWith('JVBER')) {
                mimeType = 'application/pdf';
            }
            try {
                const byteCharacters = atob(base64);
                const bytes = new Uint8Array(byteCharacters.length);
                for (let i = 0; i < byteCharacters.length; i++) {
                    bytes[i] = byteCharacters.charCodeAt(i);
                }
                this.openInNewTab(URL.createObjectURL(new Blob([bytes], { type: mimeType })));
            } catch (error) {
                this.dispatchToast('Unable to preview the file.', 'error');
            }
        } else if (previewUrl) {
            // Fresh uploads hold a blob: URL; open it directly (the legacy
            // handler silently ignored these).
            this.openInNewTab(previewUrl);
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
    }

    handleRemoveFile(event) {
        const id = event.currentTarget.dataset.id;
        const labelName = event.currentTarget.dataset.label;
        const keys = FILE_MAP[labelName];
        if (!keys) {
            return;
        }
        // As legacy: the fileName key is intentionally left in place; the
        // upload flag alone controls whether the pair reaches the payload.
        this.updateMember(id, {
            [keys.base64]: null,
            [keys.preview]: null,
            [keys.flag]: false
        });
    }

    /* ---------------- submit ---------------- */

    @api
    async submitForm() {
        // No step veil here: the workspace shows the full-screen loader for the
        // whole of Next, and a second spinner underneath it read as a defect.
        try {
            // 1) Control-level sweep (legacy: reportValidity over all inputs).
            //    Disabled forms are exempt, matching constraint-validation rules.
            if (!this.isDisabled && !this.validateAllMembers()) {
                this._pendingFocus = true;
                this.dispatchToast('Please fix the errors before proceeding.', 'error');
                return;
            }

            // 2) Loqate validations
            const invalidStaff = this.staffMembers.filter(
                (member) => !member.isPhoneLoqateValid || !member.isEmailLoqateValid
            );
            if (invalidStaff.length > 0) {
                this.dispatchToast('Please validate both Email and Mobile Number.', 'error');
                return;
            }

            // 3) Legacy required-field list + uploads
            const requiredFields = [
                { field: 'firstname', label: 'First Name' },
                { field: 'lastname', label: 'Last Name' },
                { field: 'mobile', label: 'Mobile' },
                { field: 'mobileNum', label: 'Mobile country Code' },
                { field: 'email', label: 'Email' },
                { field: 'passportNumber', label: 'Passport Number' },
                { field: 'passportExpiryDate', label: 'Passport Expiry Date' },
                { field: 'residentStatus', label: 'Resident Status' }
            ];
            // Emirates ID is required per row: UAE Broker registration AND the
            // admin is a UAE resident (Owners step rule).
            const eidRequiredFields = [
                { field: 'eidNumber', label: 'Emirates ID Number' },
                { field: 'eidExpiryDate', label: 'EID Expiry Date' }
            ];

            const missingFields = [];
            this.staffMembers.forEach((member, idx) => {
                const ownerLabel = `Agency Admin Details ${idx + 1}`;
                const memberRequired = this.showEIDFields && member.isResident
                    ? [...requiredFields, ...eidRequiredFields]
                    : requiredFields;
                memberRequired.forEach(({ field, label }) => {
                    if (!member[field]) {
                        missingFields.push(label);
                        this.setFieldError(member.id, field, 'This field is required');
                    }
                    if (field === 'eidNumber') {
                        const eid = member.eidNumber;
                        if (eid && !EID_REGEX.test(eid)) {
                            this.setFieldError(member.id, 'eidNumber', 'EID must be in the format: 784-XXXX-XXXXXXX-X');
                        } else if (eid) {
                            this.clearFieldError(member.id, 'eidNumber');
                        }
                    }
                });

                if (!member.isPassportFirstPageUploaded) {
                    missingFields.push('Passport First Page ' + ownerLabel);
                }
                if (!member.isPassportSignaturePageUploaded) {
                    missingFields.push('Passport Signature Page ' + ownerLabel);
                }
                if (this.showEIDFields && member.isResident) {
                    if (!member.isEmiratesIdFrontUploaded) {
                        missingFields.push('Emirates ID Front ' + ownerLabel);
                    }
                    if (!member.isEmiratesIdBackUploaded) {
                        missingFields.push('Emirates ID Back ' + ownerLabel);
                    }
                }
            });

            if (missingFields.length > 0) {
                this._pendingFocus = true;
                this.dispatchToast(`Please fill in the following required fields: ${missingFields.join(', ')}`, 'error', 'Error');
                return;
            }

            // 4) Detect changes vs the load-time snapshot
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
                    if (hasChanges) {
                        break;
                    }
                }
            }

            if (!hasChanges) {
                const recordIds = this.staffMembers.map((staff) => staff.Id).filter((recordId) => recordId);
                this.dispatchEvent(new CustomEvent('success', {
                    detail: { ids: recordIds },
                    bubbles: true,
                    composed: true
                }));
                this.dispatchToast('No changes were made to the Agency Admin information.', 'info', 'Info');
                return recordIds;
            }

            // 5) Build payload - only valid, flagged files are attached
            const hasValidExt = (name) =>
                !!name && name.includes('.') &&
                VALID_EXTENSIONS.includes(name.split('.').pop().toLowerCase());

            const ensureTempId = (member) => {
                if (!member.tempId) {
                    member.tempId = (window.crypto && window.crypto.randomUUID)
                        ? window.crypto.randomUUID()
                        : `${Date.now()}_${Math.random()}`;
                }
                return member;
            };

            const normalizedMembers = this.staffMembers.map((member) => ensureTempId({ ...member }));
            const dataToSend = normalizedMembers.map((member) => {
                const payload = {
                    firstname: member.firstname ?? null,
                    /* The inputs moved to the Owner step, but anything already
                       saved here is passed back unchanged rather than nulled,
                       so removing the UI cannot wipe draft data. */
                    POA: member.POA ?? null,
                    POAemail: member.POAemail ?? null,
                    lastname: member.lastname ?? null,
                    email: member.email ?? null,
                    mobileNum: member.mobileNum ?? null,
                    passportIssueDate: this.safeDate(member.passportIssueDate),
                    eidIssueDate: this.safeDate(member.eidIssueDate),
                    nationality: member.nationality ?? null,
                    residentStatus: member.residentStatus ?? null,
                    mobile: member.mobile ?? null,
                    passportNumber: member.passportNumber ?? null,
                    passportExpiryDate: this.safeDate(member.passportExpiryDate),
                    eidNumber: member.eidNumber ?? null,
                    eidExpiryDate: this.safeDate(member.eidExpiryDate),
                    Brokertype: 'Agency Admin',
                    isPrimaryOwner: this.safeBool(member.isPrimaryOwner),
                    isPrimaryagencyadmin: this.safeBool(member.isPrimaryagencyadmin),
                    registrationId: this.registrationId,
                    tempId: member.tempId,
                    sfId: member.sfId ?? null
                };
                Object.values(FILE_MAP).forEach(({ base64, name, flag }) => {
                    if (member[flag] && member[base64] && hasValidExt(member[name])) {
                        payload[base64] = member[base64];
                        payload[name] = member[name];
                    }
                });
                return payload;
            });

            // 6) Call Apex
            const recordIds = await saveAgentsWithFiles({ agentDataList: dataToSend, registrationId: this.registrationId, sessionId: this.sessionId });

            // 7) Map back IDs (as legacy: a no-op while Apex returns List<Id>;
            //    becomes live if Apex ever returns a tempId->Id map)
            this.staffMembers = normalizedMembers.map((member) => {
                const realId = recordIds[member.tempId];
                return {
                    ...member,
                    sfId: realId || member.sfId,
                    Id: realId || member.Id
                };
            });

            // 8) Success
            this.dispatchEvent(new CustomEvent('success', {
                detail: { ids: recordIds },
                bubbles: true,
                composed: true
            }));
            this.dispatchToast('Agency Admin Details saved.', 'success', 'Success');
            return recordIds;
        } catch (error) {
            this.dispatchError(
                (error && error.body && error.body.message)
                    ? error.body.message
                    : 'Failed to save Agency Admin information.'
            );
            throw error;
        }
    }

    /* ---------------- validation ---------------- */

    validateAllMembers() {
        const today = new Date().toISOString().split('T')[0];
        let allValid = true;
        const nextErrors = {};
        // Primary Agency Admin is a group rule (exactly one row), not a per-row
        // required box as legacy had it. Legacy forced every admin to be ticked,
        // which the client read as the selection not sticking per row.
        const primaryCount = this.staffMembers.filter((m) => m.isPrimaryagencyadmin).length;

        this.staffMembers.forEach((member) => {
            // Start from any pending errors (duplicate/server checks), matching
            // how legacy custom validity persisted into the submit sweep.
            const errors = { ...(this.fieldErrors[member.id] || {}) };
            delete errors.isPrimaryagencyadmin;
            const requireValue = (field) => {
                if (!member[field]) {
                    errors[field] = errors[field] || 'Complete this field.';
                }
            };

            ['firstname', 'lastname', 'nationality', 'residentStatus', 'mobile', 'email',
                'passportNumber', 'passportIssueDate', 'passportExpiryDate'].forEach(requireValue);
            // Emirates ID only for a UAE resident on a UAE Broker registration.
            if (this.showEIDFields && member.isResident) {
                ['eidNumber', 'eidIssueDate', 'eidExpiryDate'].forEach(requireValue);
            }
            if (primaryCount === 0) {
                errors.isPrimaryagencyadmin = 'Select one Primary Agency Admin.';
            } else if (primaryCount > 1 && member.isPrimaryagencyadmin) {
                errors.isPrimaryagencyadmin = 'Only one Primary Agency Admin can be selected.';
            }

            if (member.mobile && !MOBILE_REGEX.test(member.mobile)) {
                errors.mobile = errors.mobile || 'Please enter only numbers';
            }
            if (member.email && !EMAIL_REGEX.test(member.email)) {
                errors.email = errors.email || 'You have entered an invalid format.';
            }
            if (this.showEIDFields && member.eidNumber && !EID_REGEX.test(member.eidNumber)) {
                errors.eidNumber = 'Emirates ID must be in the format: 784-XXXX-XXXXXXX-X. Only digits and dashes allowed in correct positions.';
            }
            ISSUE_DATE_FIELDS.forEach((field) => {
                if (member[field] && member[field] > today) {
                    errors[field] = 'Issue Date cannot be in the future.';
                }
            });
            EXPIRY_DATE_FIELDS.forEach((field) => {
                if (member[field] && member[field] < today) {
                    errors[field] = 'Expiry Date cannot be in the past.';
                }
            });

            if (!member.isPassportFirstPageUploaded) {
                errors.Passport_First_Page = 'Complete this field.';
            }
            if (!member.isPassportSignaturePageUploaded) {
                errors.Passport_Signature_Page = 'Complete this field.';
            }
            if (this.showEIDFields && member.isResident) {
                if (!this.isInternational && !member.isEmiratesIdFrontUploaded) {
                    errors.Emirates_ID_Front = 'Complete this field.';
                }
                if (!member.isEmiratesIdBackUploaded) {
                    errors.Emirates_ID_Back = 'Complete this field.';
                }
                if (!member.isVisaPageUploaded) {
                    errors.Visa_Page = 'Complete this field.';
                }
            }

            if (Object.keys(errors).length > 0) {
                nextErrors[member.id] = errors;
                allValid = false;
            }
        });

        this.fieldErrors = nextErrors;
        return allValid;
    }

    /* ---------------- helpers ---------------- */

    safeDate(value) {
        return (value === undefined || value === null || value === '') ? null : value;
    }

    safeBool(value) {
        return value === true;
    }

    updateMember(id, patch) {
        this.staffMembers = this.staffMembers.map((member) =>
            member.id === id ? { ...member, ...patch } : member
        );
    }

    setFieldError(id, field, message) {
        const current = this.fieldErrors[id] || {};
        this.fieldErrors = { ...this.fieldErrors, [id]: { ...current, [field]: message } };
    }

    clearFieldError(id, field) {
        const current = this.fieldErrors[id];
        if (!current || !current[field]) {
            return;
        }
        const next = { ...current };
        delete next[field];
        this.fieldErrors = { ...this.fieldErrors, [id]: next };
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
            'POA',
            'POAemail'
        ].forEach((key) => {
            if (out[key] == null) {
                out[key] = '';
            }
        });
        return out;
    }

    dispatchToast(message, variant, title) {
        const detail = { message, variant };
        if (title) {
            detail.title = title;
        }
        this.dispatchEvent(new CustomEvent('toast', {
            detail,
            bubbles: true,
            composed: true
        }));
    }

    dispatchError(message) {
        this.dispatchEvent(new CustomEvent('error', {
            detail: { message },
            bubbles: true,
            composed: true
        }));
    }
}