import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import Toast from 'lightning/toast';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';
import CONTACT_OBJECT from '@salesforce/schema/Contact';
import SALUTATION_FIELD from '@salesforce/schema/Contact.Salutation';
import BROKER_TYPE_FIELD from '@salesforce/schema/Contact.Broker_Type__c';

import getUserInformation from '@salesforce/apex/MBP_BrokerAgentsController.getUserInformation';
import getContactsUserInfo from '@salesforce/apex/MBP_BrokerAgentsController.getContactsUserInfo';
import getPicklistValuesGeneric from '@salesforce/apex/MBP_BrokerAgentsController.getPicklistValuesGeneric';
import createBrokerAgent from '@salesforce/apex/MBP_BrokerAgentsController.createBrokerAgent';
import createUserFromContact from '@salesforce/apex/MBP_BrokerAgentsController.createUserFromContact';
import uploadFile from '@salesforce/apex/MBP_BrokerAgentsController.uploadFile';
import resetPassword from '@salesforce/apex/MBP_BrokerAgentsController.resetPassword';
import updateContactAgentStatus from '@salesforce/apex/MBP_BrokerAgentsController.updateContactAgentStatus';
import updateUserAgentStatus from '@salesforce/apex/MBP_BrokerAgentsController.updateUserAgentStatus';
import checkExistingPrimary from '@salesforce/apex/MBP_BrokerAgentsController.checkExistingPrimary';
import validateEmail from '@salesforce/apex/MBP_LoqateIntegration.validateEmail';
import validatePhone from '@salesforce/apex/MBP_LoqateIntegration.validatePhone';

import { COUNTRY_CODE_OPTIONS } from './countryCodes';

/* Mobile country code recovery. Contact.Mobile_Country_COde__c is only
   populated on a minority of contacts, but the number itself carries the
   code, so legacy rendered a blank picker and left "971556648201" in the
   phone box. Longest match first, so '971' beats '97' and '9'. */
const DIAL_CODES_LONGEST_FIRST = COUNTRY_CODE_OPTIONS
    .map((option) => String(option.value || ''))
    .filter((code) => code.length > 0)
    .sort((a, b) => b.length - a.length);

/* Splits a raw mobile into { countryCode, nationalNumber }. storedCode wins
   when present; this only fills the gap. Also handles a stored code plus a
   number that already starts with it, which used to give "971971...". */
function splitMobile(rawMobile, storedCode) {
    const digits = String(rawMobile || '').replace(/[^0-9]/g, '');
    const stored = String(storedCode || '').replace(/[^0-9]/g, '');

    if (stored) {
        return digits.startsWith(stored)
            ? { countryCode: stored, nationalNumber: digits.slice(stored.length) }
            : { countryCode: stored, nationalNumber: digits };
    }
    if (digits) {
        const match = DIAL_CODES_LONGEST_FIRST.find(
            (code) => digits.startsWith(code) && digits.length > code.length
        );
        if (match) {
            return { countryCode: match, nationalNumber: digits.slice(match.length) };
        }
    }
    return { countryCode: '', nationalNumber: digits };
}

/* Required-document detection. Legacy matched the exact names this component
   writes on upload, so anything from migration ("Emirates_ID_Front.pdf") never
   matched and the form demanded a file that was already attached. Word
   boundaries matter: /\badm\b/ must not fire on "admin". */
const DOCUMENT_PATTERNS = {
    emiratesId: [/emirates\s*id/, /\beid\b/, /residence\s*visa/],
    passport: [/passport/],
    reraCard: [/rera/],
    admCard: [/\badm\b/],
    // BP-094 - any broker card counts, so an older RERA or ADM file is not asked for again.
    brokerCard: [/broker\s*card/, /rera/, /\badm\b/]
};

function matchesDocument(filename, key) {
    const normalised = String(filename || '')
        .replace(/\.[a-z0-9]+$/i, '')
        .replace(/[_\-.]+/g, ' ')
        .replace(/\s+/g, ' ')
        .toLowerCase();
    return (DOCUMENT_PATTERNS[key] || []).some((pattern) => pattern.test(normalised));
}

const PAGE_SIZE = 10;
// Same practical threshold the legacy roster used for its "2 MB" copy.
const MAX_FILE_BYTES = 2500000;

const SORT_OPTIONS = [
    { label: 'Name', value: 'fullName' },
    { label: 'Username', value: 'username' },
    { label: 'Email ID', value: 'emailId' },
    { label: 'Agent ID', value: 'agentId' },
    { label: 'Role', value: 'role' },
    { label: 'Region', value: 'region' },
    { label: 'Country', value: 'country' },
    { label: 'Phone Number', value: 'phoneNumber' },
    { label: 'Status', value: 'active' }
];

export default class MbprAgentsRoster extends LightningElement {
    @api brokerType = '';

    isInitializing = true;
    isLoading = false;
    isActionPending = false;
    loadError = '';

    currentUser = null;
    agencyId = null;
    showEmirates = false;
    isDubaiBroker = false;
    isAbuDhabiBroker = false;

    agents = [];
    expandedAgentIds = [];
    currentPage = 1;
    searchQuery = '';
    sortBy = '';
    sortDirection = 'asc';

    // ---- Add/Edit modal state ----
    showModal = false;
    modalHeader = 'Add Agent';
    action = 'Add';
    disableForm = false;
    selectedRow = null;

    title = '';
    firstName = '';
    lastName = '';
    email = '';
    originalEmail = '';
    countryCode = '';
    phone = '';
    originalPhone = '';
    birthdate = '';
    role = '';
    isBroker = false;
    isPrimaryOwner = false;
    isPrimaryAgencyAdmin = false;
    brokerCertificateNumber = '';
    brokerCertificateIssueDate = '';
    brokerCertificateExpiryDate = '';
    issuingAuthority = '';
    emiratesID = '';
    expiryDate = '';
    eidIssueDate = '';
    passportNumber = '';
    passportExpiryDate = '';
    passportIssueDate = '';
    nationality = '';
    files = [];
    contactId = '';
    userId = '';
    agencyName = '';
    region = '';

    showPrimaryOwner = false;
    showPrimaryAdmin = false;
    isRERA_ADM_toShow = false;

    emailValidated = false;
    emailValidating = false;
    emailButtonLabel = 'Validate email';
    mobileValidated = false;
    mobileValidating = false;
    mobileButtonLabel = 'Validate mobile';

    nationalityOptions = [];

    // ---- Confirmation overlay state ----
    confirmationOpen = false;
    pendingAction = '';
    pendingRow = null;

    _loadSequence = 0;
    _confirmationFocusPending = false;
    _confirmationOpener = null;
    _modalOpener = null;

    @wire(getObjectInfo, { objectApiName: CONTACT_OBJECT })
    contactMetadata;

    @wire(getPicklistValues, {
        recordTypeId: '$contactMetadata.data.defaultRecordTypeId',
        fieldApiName: SALUTATION_FIELD
    })
    titlePicklist;

    @wire(getPicklistValues, {
        recordTypeId: '$contactMetadata.data.defaultRecordTypeId',
        fieldApiName: BROKER_TYPE_FIELD
    })
    brokerTypePicklist;

    @wire(getPicklistValuesGeneric, { sObjectName: 'Contact', fieldName: 'Nationality__c' })
    wiredNationalityPicklist({ data }) {
        this.nationalityOptions = data || [];
    }

    connectedCallback() {
        this.initializeRoster();
    }

    renderedCallback() {
        if (this.showModal) {
            this.syncFormSelects();
        }
        if (this.confirmationOpen && this._confirmationFocusPending) {
            const primaryButton = this.template.querySelector('.confirmation__action--primary');
            if (primaryButton) {
                primaryButton.focus();
                this._confirmationFocusPending = false;
            }
        }
    }

    async initializeRoster() {
        this.isInitializing = true;
        this.loadError = '';
        try {
            const [currentUser] = await Promise.all([getUserInformation(), this.loadAgents()]);
            this.currentUser = currentUser || null;
            // Legacy read Contact.AccountId, which its own SOQL never selected, so the
            // duplicate-primary check silently never ran. User.AccountId is selected,
            // so the same account is passed the way the legacy guard intended.
            this.agencyId = currentUser ? currentUser.AccountId : null;

            const account = currentUser && currentUser.Contact ? currentUser.Contact.Account : null;
            if (account) {
                this.showEmirates = this.agencyCapturesEmiratesId(account);
                // Broker card rules stay on the billing state, exactly as before.
                if (account.Agency_Region__c === 'Domestic') {
                    if (account.BillingState === 'Dubai') {
                        this.isDubaiBroker = true;
                    } else if (account.BillingState === 'Abu Dhabi') {
                        this.isAbuDhabiBroker = true;
                    }
                }
            }
        } catch (error) {
            this.loadError = this.reduceError(error) || 'Unable to load agents right now. Please try again.';
        } finally {
            this.isInitializing = false;
        }
    }

    /* BP-019 - Emirates details follow the agency's registration type: a UAE
       Broker captures Emirates ID for every owner/agent, an International
       Broker is passport only. Legacy keyed this on the billing country
       (Agency Region), which hid the fields for UAE brokers with an overseas
       address; that rule now applies only when no registration type is on
       record. */
    agencyCapturesEmiratesId(account) {
        const type = String(account.Type_of_Registration__c || '').trim().toLowerCase();
        if (type === 'uae broker') return true;
        if (type === 'international broker') return false;
        return account.Agency_Region__c === 'Domestic';
    }

    async loadAgents() {
        const sequence = ++this._loadSequence;
        this.isLoading = true;
        try {
            const result = await getContactsUserInfo();
            if (sequence !== this._loadSequence) return;
            this.agents = (result || []).map((element, index) => this.toAgentRow(element, index));
            const pageCount = Math.max(1, Math.ceil(this.agents.length / PAGE_SIZE));
            if (this.currentPage > pageCount) this.currentPage = pageCount;
        } finally {
            if (sequence === this._loadSequence) {
                this.isLoading = false;
            }
        }
    }

    toAgentRow(element, index) {
        const contact = element.contact || {};
        const user = element.user || {};
        // Recover the dial code from the number when the Contact field is
        // empty, which is the common case (populated on ~111 contacts).
        const mobileParts = splitMobile(element.mobile, contact.Mobile_Country_COde__c);
        const account = contact.Account || {};
        const userAccount = (user.Contact && user.Contact.Account) || {};
        const status = contact.Agent_Status__c || '';
        // BP-097 - Broker Management comment, shown only while the agent is Rejected.
        const rejectionComments = status === 'Rejected' ? String(element.rejectionComments || '').trim() : '';
        const firstName = contact.FirstName || '';
        const lastName = contact.LastName || '';
        return {
            key: contact.Id || `row-${index}`,
            title: contact.Salutation || '',
            agencyName: account.Name || '',
            firstName,
            lastName,
            fullName: contact.Name || '',
            displayName: `${firstName} ${lastName}`.trim(),
            initials: `${firstName.charAt(0) || ''}${lastName.charAt(0) || ''}`.toUpperCase(),
            emailId: element.email || '',
            role: contact.Broker_Type__c || '',
            birthdate: contact.Birthdate || '',
            // Legacy declared a Region column but read it from a field its Contact
            // query never selected; the user-side query does select it.
            region: userAccount.Agency_Region__c || '',
            country: account.BillingCountry || '',
            brokerCertificateNumber: contact.Broker_Certificate_Number__c || '',
            brokerCertificateIssueDate: contact.Broker_Certificate_Issue_Date__c || '',
            brokerCertificateExpiryDate: contact.Broker_Certificate_Expiry_Date__c || '',
            issuingAuthority: contact.Issuing_Authority__c || '',
            agentId: contact.Broker_Certificate_Number__c || 'N/A',
            phoneNumber: `${mobileParts.countryCode}${mobileParts.nationalNumber}`,
            countryCode: mobileParts.countryCode,
            active: status,
            statusTone: status === 'Active' ? 'success' : 'warning',
            profilePicPreview: user.FullPhotoUrl || '',
            contactId: contact.Id || '',
            userId: user.Id || '',
            username: user.Username || '',
            isPrimaryOwner: contact.Primary_Owner__c === true,
            isPrimaryAgencyAdmin: contact.Primary_Agency_Admin__c === true,
            isBroker: contact.IsBroker__c === true,
            passportNumber: contact.PassportNumber__c || '',
            passportExpiryDate: contact.PassportExpiryDate__c || '',
            passportIssueDate: contact.PassportIssueDate__c || '',
            emiratesID: contact.EIDNumber__c || '',
            expiryDate: contact.EID_Expiry_Date__c || '',
            eidIssueDate: contact.Emirates_ID_Issue_Date__c || '',
            nationality: contact.Nationality__c || '',
            files: Array.isArray(element.files) ? element.files : [],
            rejectionComments,
            hasRejectionComments: rejectionComments.length > 0,
            toggleTooltip: status === 'Active' ? 'Disable Agent' : 'Enable Agent'
        };
    }

    // ------------------------------------------------------------------
    // List presentation
    // ------------------------------------------------------------------

    get sortOptions() {
        return SORT_OPTIONS;
    }

    get sortOptionsView() {
        return SORT_OPTIONS.map((opt) => ({ ...opt, selected: opt.value === this.sortBy }));
    }

    get sortDirectionLabel() {
        return this.sortDirection === 'asc' ? 'Ascending' : 'Descending';
    }

    get isSortAscending() {
        return this.sortDirection === 'asc';
    }

    get submitDisabled() {
        return this.disableForm || this.isActionPending;
    }

    stopEventPropagation(event) {
        event.stopPropagation();
    }

    get searchedAgents() {
        const query = this.searchQuery.trim().toLowerCase();
        if (!query) return this.agents;
        return this.agents.filter((agent) =>
            [agent.displayName, agent.fullName, agent.emailId, agent.phoneNumber, agent.agencyName]
                .some((value) => (value || '').toLowerCase().includes(query))
        );
    }

    handleSearchInput(event) {
        this.searchQuery = event.target.value || '';
        this.currentPage = 1;
    }

    handleSearchClear() {
        this.searchQuery = '';
        this.currentPage = 1;
    }

    get sortedAgents() {
        if (!this.sortBy) return this.searchedAgents;
        const key = this.sortBy;
        const factor = this.sortDirection === 'asc' ? 1 : -1;
        const isNumeric = (value) => /^\d+$/.test(value);
        return [...this.searchedAgents].sort((a, b) => {
            const left = a[key] == null ? '' : String(a[key]);
            const right = b[key] == null ? '' : String(b[key]);
            if (isNumeric(left) && isNumeric(right)) {
                return (Number(left) - Number(right)) * factor;
            }
            return left.toLowerCase().localeCompare(right.toLowerCase()) * factor;
        });
    }

    get pagedAgents() {
        const start = (this.currentPage - 1) * PAGE_SIZE;
        const expanded = new Set(this.expandedAgentIds);
        return this.sortedAgents.slice(start, start + PAGE_SIZE).map((agent, index) => ({
            ...agent,
            sno: start + index + 1,
            isExpanded: expanded.has(agent.key),
            cardClass: expanded.has(agent.key) ? 'agent-card agent-card--expanded' : 'agent-card',
            expandIcon: expanded.has(agent.key) ? 'utility:chevronup' : 'utility:chevrondown',
            expandLabel: expanded.has(agent.key) ? 'Collapse details' : 'Expand details'
        }));
    }

    get hasAgents() {
        return this.agents.length > 0;
    }

    get totalPages() {
        return Math.max(1, Math.ceil(this.searchedAgents.length / PAGE_SIZE));
    }

    get showRosterNoMatch() {
        return Boolean(this.searchQuery.trim()) && this.searchedAgents.length === 0 && this.agents.length > 0;
    }

    get pageLabel() {
        return `Page ${this.currentPage} of ${this.totalPages}`;
    }

    get disablePrev() {
        return this.currentPage <= 1;
    }

    get disableNext() {
        return this.currentPage >= this.totalPages;
    }

    get showPagination() {
        return this.agents.length > PAGE_SIZE;
    }

    handlePrevPage() {
        if (this.currentPage > 1) this.currentPage -= 1;
    }

    handleNextPage() {
        if (this.currentPage < this.totalPages) this.currentPage += 1;
    }

    handleSortByChange(event) {
        this.sortBy = (event.detail && event.detail.value) || event.target.value;
        this.currentPage = 1;
    }

    handleSortDirectionToggle() {
        this.sortDirection = this.sortDirection === 'asc' ? 'desc' : 'asc';
        this.currentPage = 1;
    }

    handleToggleExpand(event) {
        const key = event.currentTarget.dataset.key;
        if (!key) return;
        this.expandedAgentIds = this.expandedAgentIds.includes(key)
            ? this.expandedAgentIds.filter((id) => id !== key)
            : [...this.expandedAgentIds, key];
    }

    findRowByKey(key) {
        return this.agents.find((agent) => agent.key === key) || null;
    }

    // ------------------------------------------------------------------
    // Export (legacy contract: all rows, legacy headers, AgentsExport.csv)
    // ------------------------------------------------------------------

    handleExport() {
        if (!this.agents.length) {
            this.showToast('No data to export', 'warning');
            return;
        }
        const exportRows = this.agents.map((agent) => ({
            // Export must match the name on the agent card and the roster's own
            // sort/search, which both use 'fullName' (Contact.Name). 'lastName' is
            // only the surname and was left behind when the name fields were split.
            Name: agent.fullName,
            Username: agent.username,
            'Email ID': agent.emailId,
            'Agent ID': agent.agentId,
            Role: agent.role,
            Region: agent.region,
            Country: agent.country,
            'Phone Number': agent.phoneNumber,
            Status: agent.active
        }));
        const headers = Object.keys(exportRows[0]);
        const csv = [
            headers.join(','),
            ...exportRows.map((row) => headers.map((header) => `"${row[header] == null ? '' : row[header]}"`).join(','))
        ].join('\n');

        const link = document.createElement('a');
        link.href = 'data:text/csv;charset=utf-8,' + encodeURIComponent(csv);
        link.download = 'AgentsExport.csv';
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
    }

    // ------------------------------------------------------------------
    // Add / Edit modal
    // ------------------------------------------------------------------

    get countryCodeOptions() {
        return COUNTRY_CODE_OPTIONS;
    }

    get titleOptions() {
        return (this.titlePicklist && this.titlePicklist.data && this.titlePicklist.data.values) || [];
    }

    get roleOptions() {
        return (this.brokerTypePicklist && this.brokerTypePicklist.data && this.brokerTypePicklist.data.values) || [];
    }

    get emailValidateDisabled() {
        return this.emailValidating || this.disableForm;
    }

    get mobileValidateDisabled() {
        return this.mobileValidating || this.disableForm;
    }

    get showReraUpload() {
        return this.isDubaiBroker && this.isRERA_ADM_toShow;
    }

    get showAdmUpload() {
        return this.isAbuDhabiBroker && this.isRERA_ADM_toShow;
    }

    /* BP-094 - agencies outside Dubai and Abu Dhabi get a Broker Card slot. It saves
       to the same backend slot as the RERA and ADM cards. Agency Admin has none. */
    get showBrokerCardUpload() {
        return (
            !this.isDubaiBroker &&
            !this.isAbuDhabiBroker &&
            this.isRERA_ADM_toShow &&
            this.role !== 'Agency Admin'
        );
    }

    /* BP-036 - native selects mirror the state after every render, so a value
       that arrived before the options (edit prefill, picklist wire) and a reset
       to '' (Add after Edit) both land on the right option. */
    syncFormSelects() {
        const state = {
            title: this.title,
            countryCode: this.countryCode,
            role: this.role,
            nationality: this.nationality
        };
        this.template.querySelectorAll('.agent-form select[data-id]').forEach((select) => {
            const value = state[select.dataset.id];
            const next = value === undefined || value === null ? '' : String(value);
            if (select.value !== next) select.value = next;
        });
    }

    withSelection(options, current) {
        const value = current === undefined || current === null ? '' : String(current);
        return (options || []).map((option) => ({ ...option, isSelected: String(option.value) === value }));
    }

    get titleSelectOptions() {
        return this.withSelection(this.titleOptions, this.title);
    }

    get roleSelectOptions() {
        return this.withSelection(this.roleOptions, this.role);
    }

    get nationalitySelectOptions() {
        return this.withSelection(this.nationalityOptions, this.nationality);
    }

    get countryCodeSelectOptions() {
        return this.withSelection(this.countryCodeOptions, this.countryCode);
    }

    get modalHeaderDetail() {
        return this.action === 'Edit' ? `${this.firstName || ''} ${this.lastName || ''}`.trim() : '';
    }

    get submitLabel() {
        return this.action === 'Edit' ? 'Save changes' : 'Add agent';
    }

    get identityHint() {
        return this.showEmirates ? 'Emirates ID and passport' : 'Passport';
    }

    get emailButtonClass() {
        return `roster-button roster-button--validate${this.emailValidated ? ' roster-button--validated' : ''}`;
    }

    get mobileButtonClass() {
        return `roster-button roster-button--validate${this.mobileValidated ? ' roster-button--validated' : ''}`;
    }

    /* Document slots: each file lands in the slot whose pattern it matches (the
       same matchesDocument handleSubmit uses); files for a slot that is not
       shown for this role or agency stay visible under "Other documents". */
    slotFiles(key) {
        return this.displayFiles.filter((file) => matchesDocument(file.filename, key));
    }

    get emiratesSlotFiles() {
        return this.slotFiles('emiratesId');
    }

    get passportSlotFiles() {
        return this.slotFiles('passport');
    }

    get reraSlotFiles() {
        return this.slotFiles('reraCard');
    }

    get admSlotFiles() {
        return this.slotFiles('admCard');
    }

    get brokerCardSlotFiles() {
        return this.slotFiles('brokerCard');
    }

    get otherSlotFiles() {
        return this.displayFiles.filter((file) => {
            if (this.showEmirates && matchesDocument(file.filename, 'emiratesId')) return false;
            if (matchesDocument(file.filename, 'passport')) return false;
            if (this.showReraUpload && matchesDocument(file.filename, 'reraCard')) return false;
            if (this.showAdmUpload && matchesDocument(file.filename, 'admCard')) return false;
            if (this.showBrokerCardUpload && matchesDocument(file.filename, 'brokerCard')) return false;
            return true;
        });
    }

    get hasOtherSlotFiles() {
        return this.otherSlotFiles.length > 0;
    }

    /* handleFileUpload keeps at most two Emirates / passport files (front and
       back) and replaces the oldest beyond that; one card is enough for RERA / ADM. */
    get canAddEmirates() {
        return this.emiratesSlotFiles.length < 2;
    }

    get canAddPassport() {
        return this.passportSlotFiles.length < 2;
    }

    get canAddRera() {
        return this.reraSlotFiles.length === 0;
    }

    get canAddAdm() {
        return this.admSlotFiles.length === 0;
    }

    get canAddBrokerCard() {
        return this.brokerCardSlotFiles.length === 0;
    }

    get emiratesPickLabel() {
        return this.emiratesSlotFiles.length ? 'Add other side' : 'Choose file';
    }

    get passportPickLabel() {
        return this.passportSlotFiles.length ? 'Add page' : 'Choose file';
    }

    slotClass(files) {
        return `doc-slot__box${files.length ? ' doc-slot__box--has' : ''}`;
    }

    get emiratesSlotClass() {
        return this.slotClass(this.emiratesSlotFiles);
    }

    get passportSlotClass() {
        return this.slotClass(this.passportSlotFiles);
    }

    get reraSlotClass() {
        return this.slotClass(this.reraSlotFiles);
    }

    get admSlotClass() {
        return this.slotClass(this.admSlotFiles);
    }

    get brokerCardSlotClass() {
        return this.slotClass(this.brokerCardSlotFiles);
    }

    get hasStagedFiles() {
        return this.files.length > 0;
    }

    get displayFiles() {
        return this.files.map((file, index) => ({
            ...file,
            key: `${file.filename}-${index}`,
            hasDownload: Boolean(file.downloadUrl)
        }));
    }

    handleAddAgent(event) {
        this._modalOpener = event ? event.currentTarget : null;
        this.action = 'Add';
        this.modalHeader = 'Add Agent';
        this.disableForm = false;
        this.selectedRow = null;
        this.title = '';
        this.firstName = '';
        this.lastName = '';
        this.email = '';
        this.originalEmail = '';
        this.countryCode = '';
        this.phone = '';
        this.originalPhone = '';
        this.birthdate = '';
        this.role = '';
        this.isBroker = false;
        this.isPrimaryOwner = false;
        this.isPrimaryAgencyAdmin = false;
        this.brokerCertificateNumber = '';
        this.brokerCertificateIssueDate = '';
        this.brokerCertificateExpiryDate = '';
        this.issuingAuthority = '';
        this.emiratesID = '';
        this.expiryDate = '';
        this.eidIssueDate = '';
        this.passportNumber = '';
        this.passportExpiryDate = '';
        this.passportIssueDate = '';
        this.nationality = '';
        this.files = [];
        this.contactId = '';
        this.userId = '';
        this.showPrimaryOwner = false;
        this.showPrimaryAdmin = false;
        this.isRERA_ADM_toShow = false;
        this.emailValidated = false;
        this.emailButtonLabel = 'Validate email';
        this.mobileValidated = false;
        this.mobileButtonLabel = 'Validate mobile';
        this.showModal = true;
    }

    handleEditAgent(event) {
        const row = this.findRowByKey(event.currentTarget.dataset.key);
        if (!row) return;
        this._modalOpener = event.currentTarget;
        this.action = 'Edit';
        this.modalHeader = 'Edit Agent';
        this.selectedRow = row;
        this.disableForm = row.active === 'Pending Verification';

        this.email = row.emailId;
        this.originalEmail = row.emailId;
        this.emailValidated = true;
        this.emailButtonLabel = 'Validated';

        // toAgentRow guarantees phoneNumber === countryCode + nationalNumber,
        // so re-splitting is deterministic. `replace` was also wrong for its
        // own inputs: it strips the FIRST occurrence anywhere, so a code that
        // repeats inside the number (971 55 971 ...) lost the wrong digits.
        const editParts = splitMobile(row.phoneNumber, row.countryCode);
        this.phone = editParts.nationalNumber;
        this.originalPhone = row.phoneNumber;
        this.mobileValidated = true;
        this.mobileButtonLabel = 'Validated';

        this.contactId = row.contactId;
        this.userId = row.userId;
        this.agencyName = row.agencyName;
        this.title = row.title;
        this.firstName = row.firstName;
        this.lastName = row.lastName;
        this.role = row.role;
        this.countryCode = row.countryCode;
        this.birthdate = row.birthdate;
        this.emiratesID = row.emiratesID;
        this.expiryDate = row.expiryDate;
        this.eidIssueDate = row.eidIssueDate;
        this.isPrimaryOwner = row.isPrimaryOwner;
        this.isPrimaryAgencyAdmin = row.isPrimaryAgencyAdmin;
        this.nationality = row.nationality;
        this.passportNumber = row.passportNumber;
        this.passportExpiryDate = row.passportExpiryDate;
        this.passportIssueDate = row.passportIssueDate;
        this.isBroker = row.isBroker;
        this.brokerCertificateNumber = row.brokerCertificateNumber;
        this.brokerCertificateIssueDate = row.brokerCertificateIssueDate;
        this.brokerCertificateExpiryDate = row.brokerCertificateExpiryDate;
        this.issuingAuthority = row.issuingAuthority;
        this.region = row.region;
        // Copy so staged uploads in the modal never mutate the roster row.
        this.files = [...row.files];

        if (this.role === 'Owner') {
            this.showPrimaryOwner = true;
            this.showPrimaryAdmin = false;
            this.isRERA_ADM_toShow = this.isBroker;
        } else if (this.role === 'Agency Admin') {
            this.showPrimaryAdmin = true;
            this.showPrimaryOwner = false;
            this.isRERA_ADM_toShow = this.isBroker;
        } else {
            this.showPrimaryOwner = false;
            this.showPrimaryAdmin = false;
            this.isRERA_ADM_toShow = true;
        }
        this.showModal = true;
    }

    closeModal() {
        this.showModal = false;
        this.restoreFocus(this._modalOpener);
        this._modalOpener = null;
    }

    handleModalKeydown(event) {
        if (event.key === 'Escape') {
            event.stopPropagation();
            this.closeModal();
        }
    }

    // ---- Field handlers (legacy validation rules verbatim) ----

    handleInputChange(event) {
        const field = event.target.dataset.id;
        const value = event.detail ? event.detail.value : event.target.value;

        switch (field) {
            case 'title':
                this.title = value;
                break;
            case 'firstName':
                this.firstName = value;
                break;
            case 'lastName':
                this.lastName = value;
                break;
            case 'email': {
                this.email = (value || '').toLowerCase();
                if (this.emailValidated && this.email !== this.originalEmail) {
                    this.emailValidated = false;
                    this.emailButtonLabel = 'Validate email';
                }
                break;
            }
            case 'countryCode': {
                this.countryCode = value;
                if (this.mobileValidated) {
                    this.mobileValidated = false;
                    this.mobileButtonLabel = 'Validate mobile';
                }
                break;
            }
            case 'phone': {
                this.phone = value;
                const target = event.target;
                if (/^[0-9]*$/.test(value)) {
                    target.setCustomValidity('');
                } else {
                    target.setCustomValidity('Enter Numbers only.');
                }
                target.reportValidity();
                if (this.mobileValidated && value !== this.originalPhone) {
                    this.mobileValidated = false;
                    this.mobileButtonLabel = 'Validate mobile';
                }
                break;
            }
            case 'dateOfBirth': {
                this.birthdate = value;
                const target = event.target;
                if (this.getAge(value) < 18) {
                    target.setCustomValidity('Age should be at least 18 years');
                } else {
                    target.setCustomValidity('');
                }
                target.reportValidity();
                break;
            }
            case 'role': {
                this.role = value;
                this.showPrimaryOwner = value === 'Owner';
                this.showPrimaryAdmin = value === 'Agency Admin';
                if (!this.showPrimaryOwner) this.isPrimaryOwner = false;
                if (!this.showPrimaryAdmin) this.isPrimaryAgencyAdmin = false;
                // BP-094 - an Owner's card slot follows the Is Broker tick. Agency Admin has none.
                this.isRERA_ADM_toShow = value === 'Owner' ? this.isBroker : value !== 'Agency Admin';
                break;
            }
            case 'isBroker':
                this.isBroker = event.target.checked;
                if (this.role === 'Owner') this.isRERA_ADM_toShow = this.isBroker;
                break;
            case 'emiratesID': {
                this.emiratesID = value;
                const target = event.target;
                const emiratesPattern = /^784-\d{4}-\d{7}-\d{1}$/;
                if (!emiratesPattern.test(value)) {
                    target.setCustomValidity('Emirates ID must be in the format: 784-XXXX-XXXXXXX-X');
                } else {
                    target.setCustomValidity('');
                }
                target.reportValidity();
                break;
            }
            case 'expiryDate': {
                this.expiryDate = value;
                const target = event.target;
                if (new Date(value) <= new Date()) {
                    target.setCustomValidity('Expiry date must be in the future.');
                } else {
                    target.setCustomValidity('');
                }
                target.reportValidity();
                break;
            }
            case 'eidIssueDate':
                this.eidIssueDate = value;
                this.validateIssueDate(value, 'eidIssueDate', 'EID Issue Date');
                this.validateDateSequence(value, this.expiryDate, 'eidIssueDate', 'expiryDate', 'EID');
                break;
            case 'passportNumber':
                this.passportNumber = value;
                break;
            case 'passportExpiryDate': {
                this.passportExpiryDate = value;
                const target = event.target;
                if (new Date(value) <= new Date()) {
                    target.setCustomValidity('Passport expiry date must be in the future.');
                } else {
                    target.setCustomValidity('');
                }
                target.reportValidity();
                break;
            }
            case 'passportIssueDate':
                this.passportIssueDate = value;
                this.validateIssueDate(value, 'passportIssueDate', 'Passport Issue Date');
                this.validateDateSequence(value, this.passportExpiryDate, 'passportIssueDate', 'passportExpiryDate', 'Passport');
                break;
            case 'nationality':
                this.nationality = value;
                break;
            case 'brokerCertificateNumber':
                this.brokerCertificateNumber = value;
                break;
            case 'issuingAuthority':
                this.issuingAuthority = value;
                break;
            case 'brokerCertificateIssueDate':
                this.brokerCertificateIssueDate = value;
                break;
            case 'brokerCertificateExpiryDate':
                this.brokerCertificateExpiryDate = value;
                break;
            default:
                break;
        }
    }

    handlePrimaryOwnerChange(event) {
        const checkbox = event.target;
        if (checkbox.checked) {
            checkExistingPrimary({ accountId: this.agencyId, type: 'Owner' })
                .then((result) => {
                    const target = this.template.querySelector('[data-id="isPrimaryOwner"]');
                    if (result) {
                        if (target) {
                            target.checked = false;
                            target.setCustomValidity(
                                'A Primary Owner already exists. Please disable it on the existing agent before assigning to a new one.'
                            );
                            target.reportValidity();
                        }
                        this.isPrimaryOwner = false;
                        this.showToast(
                            'A Primary Owner already exists. Please disable it on the existing agent before assigning to a new one.',
                            'error'
                        );
                    } else {
                        this.isPrimaryOwner = true;
                        this.isPrimaryAgencyAdmin = false;
                        this.role = 'Owner';
                        this.showPrimaryOwner = true;
                        this.showPrimaryAdmin = false;
                        if (target) {
                            target.setCustomValidity('');
                            target.reportValidity();
                        }
                    }
                })
                .catch(() => {
                    const target = this.template.querySelector('[data-id="isPrimaryOwner"]');
                    if (target) {
                        target.setCustomValidity('Unexpected error occurred during Primary Owner check.');
                        target.reportValidity();
                    }
                });
        } else {
            this.isPrimaryOwner = false;
            checkbox.setCustomValidity('');
            checkbox.reportValidity();
        }
    }

    handlePrimaryAdminChange(event) {
        const checkbox = event.target;
        if (checkbox.checked) {
            checkExistingPrimary({ accountId: this.agencyId, type: 'Agency Admin' })
                .then((result) => {
                    const target = this.template.querySelector('[data-id="isPrimaryAgencyAdmin"]');
                    if (result) {
                        if (target) {
                            target.checked = false;
                            target.setCustomValidity(
                                'A Primary Agency Admin already exists. Please disable it on the existing agent before assigning to a new one.'
                            );
                            target.reportValidity();
                        }
                        this.isPrimaryAgencyAdmin = false;
                        this.showToast(
                            'A Primary Agency Admin already exists. Please disable it on the existing agent before assigning to a new one.',
                            'error'
                        );
                    } else {
                        this.isPrimaryAgencyAdmin = true;
                        this.isPrimaryOwner = false;
                        this.role = 'Agency Admin';
                        this.showPrimaryAdmin = true;
                        this.showPrimaryOwner = false;
                        if (target) {
                            target.setCustomValidity('');
                            target.reportValidity();
                        }
                    }
                })
                .catch(() => {
                    const target = this.template.querySelector('[data-id="isPrimaryAgencyAdmin"]');
                    if (target) {
                        target.setCustomValidity('Unexpected error occurred during Primary Agency Admin check.');
                        target.reportValidity();
                    }
                });
        } else {
            this.isPrimaryAgencyAdmin = false;
            checkbox.setCustomValidity('');
            checkbox.reportValidity();
        }
    }

    getAge(dateString) {
        const today = new Date();
        const birthDate = new Date(dateString);
        let age = today.getFullYear() - birthDate.getFullYear();
        const monthDiff = today.getMonth() - birthDate.getMonth();
        if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < birthDate.getDate())) {
            age -= 1;
        }
        return age;
    }

    validateIssueDate(dateValue, fieldName, fieldLabel) {
        if (!dateValue) return true;
        const issueDate = new Date(dateValue);
        const today = new Date();
        today.setHours(0, 0, 0, 0);
        const target = this.template.querySelector(`[data-id="${fieldName}"]`);
        if (!target) return true;
        if (issueDate > today) {
            target.setCustomValidity(`${fieldLabel} cannot be in the future.`);
            target.reportValidity();
            return false;
        }
        target.setCustomValidity('');
        target.reportValidity();
        return true;
    }

    validateDateSequence(issueDateValue, expiryDateValue, issueFieldName, expiryFieldName, entityLabel) {
        if (!issueDateValue || !expiryDateValue) return true;
        const target = this.template.querySelector(`[data-id="${expiryFieldName}"]`);
        if (!target) return true;
        if (new Date(expiryDateValue) <= new Date(issueDateValue)) {
            target.setCustomValidity(`${entityLabel} expiry date must be after the issue date.`);
            target.reportValidity();
            return false;
        }
        target.setCustomValidity('');
        target.reportValidity();
        return true;
    }

    validateBrokerCertificateDates() {
        let isValid = true;
        const issueTarget = this.template.querySelector('[data-id="brokerCertificateIssueDate"]');
        const expiryTarget = this.template.querySelector('[data-id="brokerCertificateExpiryDate"]');
        const today = new Date();
        today.setHours(0, 0, 0, 0);

        if (this.brokerCertificateIssueDate && issueTarget) {
            if (new Date(this.brokerCertificateIssueDate) > today) {
                issueTarget.setCustomValidity('Broker certificate issue date cannot be in the future.');
                isValid = false;
            } else {
                issueTarget.setCustomValidity('');
            }
            issueTarget.reportValidity();
        }
        if (this.brokerCertificateExpiryDate && expiryTarget) {
            if (new Date(this.brokerCertificateExpiryDate) < today) {
                expiryTarget.setCustomValidity('Broker certificate expiry date cannot be in the past.');
                isValid = false;
            } else {
                expiryTarget.setCustomValidity('');
            }
            expiryTarget.reportValidity();
        }
        if (this.brokerCertificateIssueDate && this.brokerCertificateExpiryDate && expiryTarget) {
            if (new Date(this.brokerCertificateExpiryDate) <= new Date(this.brokerCertificateIssueDate)) {
                expiryTarget.setCustomValidity('Broker certificate expiry date must be after the issue date.');
                expiryTarget.reportValidity();
                isValid = false;
            }
        }
        return isValid;
    }

    // ---- Loqate validation ----

    handleEmailValidation() {
        if (!this.email) {
            this.showToast('Please enter an email address.', 'error');
            return;
        }
        this.emailValidating = true;
        this.emailButtonLabel = 'Validating...';
        validateEmail({ email: this.email })
            .then(() => {
                this.emailValidated = true;
                this.originalEmail = this.email;
                this.emailButtonLabel = 'Validated';
                this.showToast('Email is valid.', 'success');
            })
            .catch((error) => {
                this.emailValidated = false;
                this.emailButtonLabel = 'Validate email';
                this.showToast(this.reduceError(error) || 'Unexpected error occurred.', 'error');
            })
            .finally(() => {
                this.emailValidating = false;
            });
    }

    handleMobileValidation() {
        const countryCode = this.countryCode
            ? this.countryCode.startsWith('+')
                ? this.countryCode
                : '+' + this.countryCode
            : '';
        const phone = this.phone || '';
        if (!countryCode || !phone) {
            this.showToast('Please enter country code and mobile number.', 'error');
            return;
        }
        this.mobileValidating = true;
        this.mobileButtonLabel = 'Validating...';
        validatePhone({ phone: countryCode + phone })
            .then((result) => {
                if (result === true) {
                    this.mobileValidated = true;
                    this.originalPhone = this.phone;
                    this.mobileButtonLabel = 'Validated';
                    this.showToast('Mobile number is valid.', 'success');
                } else {
                    this.mobileValidated = false;
                    this.mobileButtonLabel = 'Validate mobile';
                    this.showToast('Entered number is not valid.', 'error');
                }
            })
            .catch((error) => {
                this.mobileValidated = false;
                this.mobileButtonLabel = 'Validate mobile';
                this.showToast(this.reduceError(error) || 'Unexpected error occurred.', 'error');
            })
            .finally(() => {
                this.mobileValidating = false;
            });
    }

    // ---- File handling (legacy rules verbatim) ----

    async handleFileUpload(event) {
        const date = new Date().toLocaleString();
        const inputName = event.target.name;
        let type = '';
        if (inputName === 'emirate') type = 'Emirates ID Copy';
        else if (inputName === 'rera') type = 'RERA Broker Card';
        else if (inputName === 'passport') type = 'Passport Copy';
        else if (inputName === 'adm') type = 'ADM Card';
        else if (inputName === 'brokerCard') type = 'Broker Card';
        else return;

        const readAsBase64 = (file) =>
            new Promise((resolve, reject) => {
                const reader = new FileReader();
                reader.readAsDataURL(file);
                reader.onload = () => resolve(reader.result.split(',')[1]);
                reader.onerror = (error) => reject(error);
            });

        for (const file of Array.from(event.target.files)) {
            const fileSize = file.size;
            const extension = file.name.split('.').pop();

            if (fileSize > MAX_FILE_BYTES) {
                this.showToast('File size is More Than 2 MB.', 'error');
                return;
            }
            if (fileSize + new Blob([JSON.stringify(this.files)]).size > MAX_FILE_BYTES) {
                this.showToast('Total File size is More Than 2 MB.', 'error');
                return;
            }
            if (this.files.some((f) => f.filename === file.name)) {
                this.showToast('File already exists', 'error');
                return;
            }

            // eslint-disable-next-line no-await-in-loop
            const base64 = await readAsBase64(file);
            const formattedFile = {
                filename: `${type} - ${date}.${extension}`,
                base64,
                fileSize,
                type,
                isNew: true
            };

            if (inputName === 'emirate' || inputName === 'passport') {
                const ofType = this.files.filter((f) => f.type === type);
                if (ofType.length >= 2) {
                    const firstIndex = this.files.findIndex((f) => f.type === type);
                    this.files.splice(firstIndex, 1);
                }
            }
            this.files = [...this.files, formattedFile];
        }
        event.target.value = null;
    }

    handleRemoveFile(event) {
        const filename = event.currentTarget.dataset.id;
        this.files = this.files.filter((file) => file.filename !== filename);
    }

    // ---- Submit ----

    async handleSubmit() {
        if (this.disableForm) return;

        if (!this.firstName || !this.lastName) {
            this.showToast('Please enter both first name and last name.', 'error');
            return;
        }
        if (this.lastName.includes(this.firstName)) {
            this.showToast('Last name appears to contain first name. Please enter only the last name.', 'error');
            return;
        }
        /* BP-096 - licence fields hidden for now, so they are not asked for or checked.
        if (this.isBroker) {
            if (
                !this.brokerCertificateNumber ||
                !this.brokerCertificateIssueDate ||
                !this.brokerCertificateExpiryDate ||
                !this.issuingAuthority
            ) {
                this.showToast(
                    'Please fill all broker certificate fields: Certificate Number, Issue Date, Expiry Date, and Issuing Authority.',
                    'error'
                );
                return;
            }
            if (!this.validateBrokerCertificateDates()) return;
        }
        */
        if (
            !this.validateIssueDate(this.eidIssueDate, 'eidIssueDate', 'EID Issue Date') ||
            !this.validateIssueDate(this.passportIssueDate, 'passportIssueDate', 'Passport Issue Date')
        ) {
            return;
        }
        if (!this.emailValidated || !this.mobileValidated) {
            this.showToast('Please validate both Email and Mobile before submitting.', 'error');
            return;
        }

        const inputsValid = [
            // BP-021 - text fields are native; BP-036 - so are the four selects.
            // Dates keep their own checks below; checkboxes and file inputs carry
            // no required flag (documents are checked from the staged list).
            ...this.template.querySelectorAll('.agent-form .portal-text-field input'),
            ...this.template.querySelectorAll('.agent-form .portal-text-field select')
        ].reduce((validSoFar, inputField) => {
            inputField.reportValidity();
            return validSoFar && inputField.checkValidity();
        }, true);
        if (!inputsValid) {
            this.showToast('Complete Mandatory Fields.', 'error');
            return;
        }

        /* BP-019 - each upload is required exactly when its input is shown, so the
           Emirates and broker-card rules no longer depend on each other. */
        let hasEmiratesId = false;
        let hasPassport = false;
        let hasReraCard = false;
        let hasAdmCard = false;
        let hasBrokerCard = false;
        this.files.forEach((element) => {
            if (!hasEmiratesId && matchesDocument(element.filename, 'emiratesId')) hasEmiratesId = true;
            if (!hasPassport && matchesDocument(element.filename, 'passport')) hasPassport = true;
            if (!hasReraCard && matchesDocument(element.filename, 'reraCard')) hasReraCard = true;
            if (!hasAdmCard && matchesDocument(element.filename, 'admCard')) hasAdmCard = true;
            if (!hasBrokerCard && matchesDocument(element.filename, 'brokerCard')) hasBrokerCard = true;
        });
        if (this.showEmirates && !hasEmiratesId) {
            this.showToast('Upload the Emirates ID / Residence Visa.', 'error');
            return;
        }
        if (!hasPassport) {
            this.showToast('Upload the Passport Page.', 'error');
            return;
        }
        if (this.showReraUpload && !hasReraCard) {
            this.showToast('Upload the RERA Broker Card.', 'error');
            return;
        }
        if (this.showAdmUpload && !hasAdmCard) {
            this.showToast('Upload the ADM Card.', 'error');
            return;
        }
        if (this.showBrokerCardUpload && !hasBrokerCard) {
            this.showToast('Upload the Broker Card.', 'error');
            return;
        }

        const isEdit = this.action === 'Edit';
        const agentInfo = {
            agencyName: this.agencyName,
            title: this.title,
            firstName: this.firstName,
            lastName: this.lastName,
            emailId: this.email,
            role: this.role,
            country: '',
            phoneNumber: this.phone,
            countryCode: this.countryCode,
            contactId: isEdit ? this.contactId : '',
            userId: isEdit ? this.userId : '',
            realEmail: '',
            realMobile: '',
            birthdate: this.birthdate,
            emiratesID: this.emiratesID != null ? this.emiratesID : '',
            expiryDate: this.expiryDate != null ? this.expiryDate : '',
            eidIssueDate: this.eidIssueDate != null ? this.eidIssueDate : '',
            isPrimaryOwner: this.isPrimaryOwner,
            isPrimaryAgencyAdmin: this.isPrimaryAgencyAdmin,
            nationality: this.nationality,
            brokerCertificateNumber: this.brokerCertificateNumber,
            brokerCertificateIssueDate: this.brokerCertificateIssueDate,
            brokerCertificateExpiryDate: this.brokerCertificateExpiryDate,
            issuingAuthority: this.issuingAuthority,
            isBroker: this.isBroker,
            passportNumber: this.passportNumber,
            passportExpiryDate: this.passportExpiryDate,
            passportIssueDate: this.passportIssueDate != null ? this.passportIssueDate : ''
        };

        this.isActionPending = true;
        try {
            const result = await createBrokerAgent({ agentInfo });
            if (result === 'Duplicate') {
                this.showToast('There is already a User with this Email in the System.', 'error');
                return;
            }
            if (!result) {
                this.showToast('Some error occured. Please contact Admin.', 'error');
                return;
            }

            const contactIdResult = result;
            if (this.files.length) {
                // ContentDocument titles must be passed exactly as stored: existing
                // files come back from Apex as `Title.ext` while the stored Title
                // already carries the extension, and any mismatch makes the Apex
                // cleanup delete the previously saved document links.
                const existingFilenames = this.files.map((file) => {
                    if (file.isNew) return file.filename;
                    const suffix = `.${file.type}`;
                    return file.filename.endsWith(suffix)
                        ? file.filename.slice(0, -suffix.length)
                        : file.filename;
                });
                await this.uploadStagedFiles(contactIdResult, existingFilenames);
            }

            if (!isEdit) {
                let permissionSetName;
                if (this.role === 'Agency Admin') permissionSetName = 'Modon_Agency_Admin_Access';
                else if (this.role === 'Agent') permissionSetName = 'Modon_Agent_Access';
                else if (this.role === 'Owner') permissionSetName = 'Modon_Agency_Owner_Access';
                // Legacy intended to skip this on edit (its guard checked a
                // lowercase 'edit' and misfired, regenerating usernames).
                await createUserFromContact({ contactId: contactIdResult, isActive: false, permissionSetName });
            }

            // BP-099 - saving a rejected agent sends it for verification again.
            const resubmitted = isEdit && this.selectedRow && this.selectedRow.active === 'Rejected';
            let savedMessage = 'Agent created successfully.';
            if (resubmitted) savedMessage = 'Agent updated and sent for verification again.';
            else if (isEdit) savedMessage = 'Agent updated successfully.';
            this.showToast(savedMessage, 'success');
            this.closeModal();
            await this.loadAgents();
        } catch (error) {
            this.handleApexError(error);
        } finally {
            this.isActionPending = false;
        }
    }

    async uploadStagedFiles(recordId, existingFilenames) {
        for (const fileData of this.files) {
            if (!fileData.base64) continue;
            // eslint-disable-next-line no-await-in-loop
            await uploadFile({
                base64: fileData.base64,
                filename: fileData.filename,
                type: fileData.type,
                recordId,
                isNew: false,
                existingFilenames
            });
        }
    }

    handleApexError(error) {
        let message = 'Unknown error';
        if (error && error.body) {
            if (Array.isArray(error.body.pageErrors) && error.body.pageErrors.length) {
                message = error.body.pageErrors[0].message;
            } else if (error.body.message) {
                message = error.body.message;
            }
        }
        if (message && message.includes('FIELD_CUSTOM_VALIDATION_EXCEPTION')) {
            message = 'FIELD_CUSTOM_VALIDATION_EXCEPTION: Please check the User/Contact Record';
        }
        this.showToast(message, 'error');
    }

    // ------------------------------------------------------------------
    // Reset password + status toggle (confirmation-gated)
    // ------------------------------------------------------------------

    handleResetPasswordClick(event) {
        const row = this.findRowByKey(event.currentTarget.dataset.key);
        if (!row) return;
        this.openConfirmation('reset', row, event.currentTarget);
    }

    handleStatusToggleClick(event) {
        const row = this.findRowByKey(event.currentTarget.dataset.key);
        if (!row) return;
        if (row.active === 'Pending Verification') {
            this.showToast('Cannot change status while verification is pending.', 'error');
            return;
        }
        // BP-098 - these statuses are set by Broker Management, so the broker cannot switch them.
        if (row.active === 'Rejected') {
            this.showToast('This agent was rejected. Edit the agent and save to send it for verification again.', 'error');
            return;
        }
        if (row.active === 'Suspended' || row.active === 'Blocked') {
            this.showToast(`This agent is ${row.active}. Only Broker Management can change that status.`, 'error');
            return;
        }
        this.openConfirmation('toggle', row, event.currentTarget);
    }

    openConfirmation(action, row, opener) {
        this.pendingAction = action;
        this.pendingRow = row;
        this._confirmationOpener = opener || null;
        this.confirmationOpen = true;
        this._confirmationFocusPending = true;
    }

    closeConfirmation() {
        this.confirmationOpen = false;
        this.pendingAction = '';
        this.pendingRow = null;
        this.restoreFocus(this._confirmationOpener);
        this._confirmationOpener = null;
    }

    handleConfirmationKeydown(event) {
        if (event.key === 'Escape') {
            event.stopPropagation();
            this.closeConfirmation();
        }
    }

    get confirmationTitle() {
        return this.pendingAction === 'reset' ? 'Reset Password' : 'Enable/Disable Agent';
    }

    get confirmationMessage() {
        if (!this.pendingRow) return '';
        if (this.pendingAction === 'reset') {
            return `Send a password reset email to ${this.pendingRow.displayName}?`;
        }
        const nextState = this.pendingRow.active === 'Active' ? 'disable' : 'enable';
        return `Are you sure you want to ${nextState} ${this.pendingRow.displayName}?`;
    }

    get confirmationActionLabel() {
        if (this.pendingAction === 'reset') return 'Reset Password';
        return this.pendingRow && this.pendingRow.active === 'Active' ? 'Disable Agent' : 'Enable Agent';
    }

    async handleConfirmAction() {
        const row = this.pendingRow;
        const action = this.pendingAction;
        this.closeConfirmation();
        if (!row) return;

        this.isActionPending = true;
        try {
            if (action === 'reset') {
                await resetPassword({ userId: row.userId });
                this.showToast('Reset Password Email sent to the user.', 'success');
            } else {
                await updateUserAgentStatus({ userId: row.userId, checkboxVal: row.active });
                await updateContactAgentStatus({ userId: row.contactId, checkboxVal: row.active });
                /* Both Apex calls above are awaited and throw into the catch on
                   failure, so reaching this line means the change is committed -
                   the old "submitted... might take several minutes" wording
                   described an async path that does not exist. row.active still
                   holds the PRE-change status, and 'Pending Verification' is
                   already blocked in handleStatusToggleClick, so it is binary
                   here: Active means we just disabled, anything else means we
                   just enabled. */
                this.showToast(
                    row.active === 'Active'
                        ? 'The agent has been disabled successfully.'
                        : 'The agent has been enabled successfully.',
                    'success'
                );
                await this.loadAgents();
            }
        } catch (error) {
            let message = '';
            const body = error && error.body;
            if (action === 'reset') {
                message =
                    (body && Array.isArray(body.pageErrors) && body.pageErrors.length && body.pageErrors[0].message) ||
                    'Reset password failed.';
            } else {
                message =
                    (body && Array.isArray(body.pageErrors) && body.pageErrors.length && body.pageErrors[0].message) ||
                    (body &&
                        body.fieldErrors &&
                        Array.isArray(body.fieldErrors.IsActive) &&
                        body.fieldErrors.IsActive.length &&
                        body.fieldErrors.IsActive[0].message) ||
                    // BP-098 - the server refuses a status it does not allow and says why.
                    (body && typeof body.message === 'string' && body.message) ||
                    'Unknown error occurred.';
            }
            this.showToast(message, 'error');
            if (action !== 'reset') {
                // The card may be showing an old status, so read the list again.
                try {
                    await this.loadAgents();
                } catch (reloadError) {
                    // The message above already told the broker what happened.
                }
            }
        } finally {
            this.isActionPending = false;
        }
    }

    handleRetryLoad() {
        this.initializeRoster();
    }

    // ------------------------------------------------------------------
    // Utilities
    // ------------------------------------------------------------------

    restoreFocus(element) {
        if (element && element.isConnected) {
            element.focus();
        }
    }

    reduceError(error) {
        if (!error) return '';
        if (typeof error === 'string') return error;
        if (error.body) {
            if (typeof error.body.message === 'string') return error.body.message;
            if (Array.isArray(error.body) && error.body.length && error.body[0].message) {
                return error.body[0].message;
            }
        }
        return error.message || '';
    }

    showToast(message, variant) {
        try {
            Toast.show({ label: message, mode: 'dismissible', variant }, this);
        } catch (toastError) {
            this.dispatchEvent(new ShowToastEvent({ title: '', message, mode: 'dismissible', variant }));
        }
    }
}