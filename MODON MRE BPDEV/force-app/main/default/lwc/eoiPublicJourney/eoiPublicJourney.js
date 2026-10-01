import { LightningElement, track } from 'lwc';
import getActiveProject from '@salesforce/apex/EoiPublicJourneyController.getActiveProject';
import getResidenceTiles from '@salesforce/apex/EoiPublicJourneyController.getResidenceTiles';
import startVerification from '@salesforce/apex/EoiPublicJourneyController.startVerification';
import resendVerification from '@salesforce/apex/EoiPublicJourneyController.resendVerification';
import verifyCode from '@salesforce/apex/EoiPublicJourneyController.verifyCode';
import submitRegistration from '@salesforce/apex/EoiPublicJourneyController.submitRegistration';

const STEP_HERO = 'hero';
const STEP_IDENTITY = 'identity';
const STEP_VERIFICATION = 'verification';
const STEP_RESIDENCE = 'residence';
const STEP_REVIEW = 'review';
const STEP_CONFIRMATION = 'confirmation';
const STEP_QUOTA_CLOSED = 'quotaClosed';
const STEP_UNAVAILABLE = 'unavailable';

export default class EoiPublicJourney extends LightningElement {
    @track step = STEP_HERO;
    @track isLoading = false;
    @track errorMessage = '';

    @track projectConfig = null;
    @track tiles = [];
    @track selectedTile = null;
    @track cart = {};

    @track customerType = 'Individual';
    @track form = this.emptyForm();

    @track channel = 'Email';
    @track verificationRequestId = null;
    @track maskedTarget = '';
    @track resendAvailableAt = null;
    @track enteredCode = '';
    @track verified = false;

    @track honeypot = '';
    @track identityEnteredAt = null;
    @track submission = null;
    @track utm = { utmSource: '', utmCampaign: '', utmMedium: '', utmUrl: '', adName: '', adSetName: '', subSource: '' };

    connectedCallback() {
        this.captureUtmFromUrl();
        this.bootstrap();
    }

    captureUtmFromUrl() {
        try {
            const params = new URLSearchParams(window.location.search || '');
            this.utm = {
                utmSource:   (params.get('utm_source')   || '').substring(0, 255),
                utmCampaign: (params.get('utm_campaign') || '').substring(0, 255),
                utmMedium:   (params.get('utm_medium')   || '').substring(0, 255),
                utmUrl:      (window.location.href || '').substring(0, 255),
                adName:      (params.get('ad_name')      || '').substring(0, 255),
                adSetName:   (params.get('adset_name')   || '').substring(0, 255),
                subSource:   (params.get('sub_source')   || '').substring(0, 255)
            };
        } catch (e) {
            this.utm = { utmSource: '', utmCampaign: '', utmMedium: '', utmUrl: '', adName: '', adSetName: '', subSource: '' };
        }
    }

    async bootstrap() {
        this.isLoading = true;
        try {
            const config = await getActiveProject();
            this.projectConfig = config;

            if (!config || !config.projectId) {
                this.step = STEP_UNAVAILABLE;
                return;
            }
            if (!config.quotaOpen) {
                this.step = STEP_QUOTA_CLOSED;
                return;
            }

            try {
                this.tiles = await getResidenceTiles({ projectId: config.projectId });
            } catch (e) {
                this.tiles = [];
            }
        } catch (e) {
            this.errorMessage = this.extractMessage(e);
            this.step = STEP_UNAVAILABLE;
        } finally {
            this.isLoading = false;
        }
    }

    emptyForm() {
        return {
            customerType: 'Individual',
            firstName: '', lastName: '', email: '', mobile: '', phone: '',
            residentStatus: 'Resident',
            emiratesId: '784-',
            passportNumber: '',
            companyName: '', tradeLicenseNumber: '', tradeLicenseExpiryDate: null,
            registeredEmail: '', registeredPhone: '',
            authorizedFirstName: '', authorizedLastName: '', authorizedEmail: '', authorizedPhone: '',
            projectId: null, phaseId: null, eoiRangeId: null,
            unitType: '', bedrooms: '', unitTypology: '', amount: 0,
            paymentTypePreference: 'Cheque',
            verificationRequestId: null,
            honeypot: '', elapsedMs: 0,
            userAgent: navigator.userAgent, locale: 'en_US'
        };
    }

    get isHero() { return this.step === STEP_HERO; }
    get isIdentity() { return this.step === STEP_IDENTITY; }
    get isVerification() { return this.step === STEP_VERIFICATION; }
    get isResidence() { return this.step === STEP_RESIDENCE; }
    get isReview() { return this.step === STEP_REVIEW; }
    get isConfirmation() { return this.step === STEP_CONFIRMATION; }
    get isQuotaClosed() { return this.step === STEP_QUOTA_CLOSED; }
    get isUnavailable() { return this.step === STEP_UNAVAILABLE; }
    get isIndividual() { return this.customerType === 'Individual'; }
    get isOrganization() { return this.customerType === 'Organization'; }
    get isResident() { return this.form.residentStatus === 'Resident'; }
    get isNonResident() { return this.form.residentStatus === 'Non Resident'; }
    get isEmailChannel() { return this.channel === 'Email'; }
    get isSmsChannel() { return this.channel === 'SMS'; }

    get individualTabClass() { return this.isIndividual ? 'tab tab--active' : 'tab'; }
    get organizationTabClass() { return this.isOrganization ? 'tab tab--active' : 'tab'; }
    get residentClass() { return this.isResident ? 'segmented__option segmented__option--active' : 'segmented__option'; }
    get nonResidentClass() { return this.isNonResident ? 'segmented__option segmented__option--active' : 'segmented__option'; }
    get emailChannelClass() { return this.isEmailChannel ? 'segmented__option segmented__option--active' : 'segmented__option'; }
    get smsChannelClass() { return this.isSmsChannel ? 'segmented__option segmented__option--active' : 'segmented__option'; }

    get currentYear() {
        return new Date().getFullYear();
    }

    get stepLabel() {
        switch (this.step) {
            case STEP_IDENTITY: return 'IDENTITY';
            case STEP_VERIFICATION: return 'VERIFY';
            case STEP_RESIDENCE: return 'RESIDENCE';
            case STEP_REVIEW: return 'CONFIRM';
            default: return '';
        }
    }

    get stepCounter() {
        switch (this.step) {
            case STEP_IDENTITY: return '02 — 05';
            case STEP_VERIFICATION: return '03 — 05';
            case STEP_RESIDENCE: return '04 — 05';
            case STEP_REVIEW: return '05 — 05';
            default: return '';
        }
    }

    get showStepHeader() {
        return this.isIdentity || this.isVerification || this.isResidence || this.isReview;
    }

    get selectionCount() {
        return Object.values(this.cart).reduce((s, n) => s + (Number(n) || 0), 0);
    }

    get selectedTilesView() {
        return (this.tiles || [])
            .filter(t => (this.cart[t.rangeId] || 0) > 0)
            .map(t => {
                const qty = this.cart[t.rangeId] || 0;
                const lineTotal = qty * (Number(t.amount) || 0);
                return {
                    ...t,
                    quantity: qty,
                    formattedAmount: this.formatAmount(t.amount),
                    formattedLineTotal: this.formatAmount(lineTotal)
                };
            });
    }

    get selectionTotal() {
        return this.selectedTilesView.reduce((sum, t) => sum + ((Number(t.amount) || 0) * t.quantity), 0);
    }

    get formattedSelectionTotal() {
        return this.formatAmount(this.selectionTotal);
    }

    get formattedAmount() {
        if (!this.selectedTile || !this.selectedTile.amount) return '';
        return 'AED ' + Number(this.selectedTile.amount).toLocaleString('en-US');
    }

    handleSelectResidentStatus(event) {
        const value = event.currentTarget.dataset.value;
        if (!value) return;
        this.form.residentStatus = value;
    }

    handleSelectChannel(event) {
        const value = event.currentTarget.dataset.value;
        if (value) this.channel = value;
    }

    handleSelectCustomerType(event) {
        const value = event.currentTarget.dataset.value;
        if (!value || value === this.customerType) return;
        this.customerType = value;
        this.form.customerType = value;
        if (value === 'Organization') {
            this.form.firstName = '';
            this.form.lastName = '';
            this.form.email = '';
            this.form.mobile = '';
            this.form.phone = '';
            this.form.emiratesId = '784-';
            this.form.passportNumber = '';
        } else {
            this.form.companyName = '';
            this.form.tradeLicenseNumber = '';
            this.form.tradeLicenseExpiryDate = null;
            this.form.registeredEmail = '';
            this.form.registeredPhone = '';
            this.form.authorizedFirstName = '';
            this.form.authorizedLastName = '';
            this.form.authorizedEmail = '';
            this.form.authorizedPhone = '';
        }
        this.errorMessage = '';
    }

    handleBack() {
        const order = [STEP_HERO, STEP_IDENTITY, STEP_VERIFICATION, STEP_RESIDENCE, STEP_REVIEW];
        const idx = order.indexOf(this.step);
        if (idx > 0) this.step = order[idx - 1];
    }

    get heroTagline() {
        return 'Expression of Interest Registration';
    }

    get projectName() {
        return this.projectConfig && this.projectConfig.name ? this.projectConfig.name : 'Modon';
    }

    get projectLocation() {
        if (this.projectConfig && this.projectConfig.location) return this.projectConfig.location;
        return 'Abu Dhabi · United Arab Emirates';
    }

    get tileViewModels() {
        return (this.tiles || []).map((t) => {
            const qty = this.cart[t.rangeId] || 0;
            const isSelected = qty > 0;
            return {
                ...t,
                quantity: qty,
                isSelected,
                tileClass: isSelected ? 'tile tile--selected' : 'tile',
                renderUrl: this.typologyRenderUrl(t.unitTypology),
                formattedAmount: this.formatAmount(t.amount),
                removeDisabled: qty <= 0
            };
        });
    }

    typologyRenderUrl(unitTypology) {
        const slug = (unitTypology || '')
            .toLowerCase()
            .replace(/[\s ]+/g, '-')
            .replace(/[^a-z0-9-]/g, '')
            .replace(/-+/g, '-')
            .replace(/^-|-$/g, '');
        return slug
            ? `/sfsites/c/resource/Microsite_Typology/${slug}.jpg`
            : `/sfsites/c/resource/Microsite_Typology/golf-homes.jpg`;
    }

    formatAmount(value) {
        if (value == null || value === '') return '';
        const num = Number(value);
        if (Number.isNaN(num)) return value;
        return num.toLocaleString('en-US', { maximumFractionDigits: 0 });
    }

    handleTileImageError(event) {
        event.target.src = '/sfsites/c/resource/Microsite_Typology/golf-homes.jpg';
    }

    get residentStatusOptions() {
        return [
            { label: 'Resident', value: 'Resident' },
            { label: 'Non-Resident', value: 'Non Resident' }
        ];
    }

    get channelOptions() {
        return [
            { label: 'Email', value: 'Email' },
            { label: 'SMS', value: 'SMS' }
        ];
    }

    handleStart() {
        this.identityEnteredAt = Date.now();
        this.step = STEP_IDENTITY;
    }

    handleCustomerTypeChange(event) {
        this.customerType = event.target.value;
        this.form.customerType = event.target.value;
    }

    handleFieldChange(event) {
        const field = event.target.dataset.field;
        if (!field) return;
        let value = event.target.value;
        if (field === 'emiratesId') {
            value = this.formatEmiratesId(value);
            event.target.value = value;
        } else if (field === 'passportNumber') {
            value = this.sanitizePassportNumber(value);
            event.target.value = value;
        } else if (field === 'mobile' || field === 'phone' || field === 'authorizedPhone' || field === 'registeredPhone') {
            value = this.formatPhone(value);
            event.target.value = value;
        }
        this.form[field] = value;
    }

    formatPhone(value) {
        const digits = (value || '').replace(/\D/g, '').substring(0, 15);
        return digits ? '+' + digits : '';
    }

    formatEmiratesId(value) {
        let digits = (value || '').replace(/\D/g, '');
        if (digits.length < 3) {
            digits = '784';
        } else if (!digits.startsWith('784')) {
            digits = '784' + digits;
        }
        digits = digits.substring(0, 15);
        const parts = ['784'];
        if (digits.length > 3) parts.push(digits.substring(3, 7));
        if (digits.length > 7) parts.push(digits.substring(7, 14));
        if (digits.length > 14) parts.push(digits.substring(14, 15));
        return parts.join('-') + (digits.length <= 3 ? '-' : '');
    }

    sanitizePassportNumber(value) {
        return (value || '').replace(/[^a-zA-Z0-9]/g, '');
    }

    isValidEmail(value) {
        return /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test((value || '').trim());
    }

    isValidPhone(value) {
        return /^\+[1-9][0-9]{7,14}$/.test((value || '').trim());
    }

    async handleIdentityContinue() {
        const required = this.isOrganization
            ? ['companyName', 'tradeLicenseNumber', 'authorizedFirstName', 'authorizedLastName', 'authorizedEmail', 'authorizedPhone']
            : ['firstName', 'lastName', 'email', 'mobile'];
        if (!this.isOrganization && this.isResident) required.push('emiratesId');
        if (!this.isOrganization && this.isNonResident) required.push('passportNumber');
        for (const f of required) {
            if (!this.form[f] || !this.form[f].toString().trim()) {
                this.errorMessage = 'Please complete all required fields before continuing.';
                return;
            }
        }
        if (!this.isOrganization && this.isResident && !/^784-[0-9]{4}-[0-9]{7}-[0-9]{1}$/.test(this.form.emiratesId)) {
            this.errorMessage = 'Please enter a valid Emirates ID (must start with 784, format 784-XXXX-XXXXXXX-X).';
            return;
        }
        const emailToCheck = this.isOrganization ? this.form.authorizedEmail : this.form.email;
        const phoneToCheck = this.isOrganization ? this.form.authorizedPhone : this.form.mobile;
        if (!this.isValidEmail(emailToCheck)) {
            this.errorMessage = 'Please enter a valid email address.';
            return;
        }
        if (!this.isValidPhone(phoneToCheck)) {
            this.errorMessage = 'Please enter a valid phone number with country code (e.g., +9715XXXXXXXX). Country code must not start with 0.';
            return;
        }
        this.errorMessage = '';
        this.step = STEP_VERIFICATION;
    }

    handleChannelChange(event) {
        this.channel = event.target.value;
    }

    async handleSendCode() {
        this.errorMessage = '';
        const target = this.channel === 'Email'
            ? (this.isOrganization ? this.form.authorizedEmail : this.form.email)
            : (this.isOrganization ? this.form.authorizedPhone : this.form.mobile);
        if (!target) {
            this.errorMessage = 'Missing contact details for verification.';
            return;
        }
        this.isLoading = true;
        try {
            const result = await startVerification({
                req: { channel: this.channel, target, sessionToken: this.makeSessionToken() }
            });
            this.verificationRequestId = result.verificationRequestId;
            this.maskedTarget = result.maskedTarget;
            this.resendAvailableAt = result.resendAvailableAt;
        } catch (e) {
            this.errorMessage = this.extractMessage(e);
        } finally {
            this.isLoading = false;
        }
    }

    handleCodeChange(event) {
        this.enteredCode = event.target.value;
    }

    async handleResend() {
        this.errorMessage = '';
        this.isLoading = true;
        try {
            const result = await resendVerification({ verificationRequestId: this.verificationRequestId });
            this.maskedTarget = result.maskedTarget;
            this.resendAvailableAt = result.resendAvailableAt;
        } catch (e) {
            this.errorMessage = this.extractMessage(e);
        } finally {
            this.isLoading = false;
        }
    }

    async handleVerify() {
        this.errorMessage = '';
        if (!this.enteredCode || this.enteredCode.length < 4) {
            this.errorMessage = 'Please enter the verification code.';
            return;
        }
        this.isLoading = true;
        try {
            const result = await verifyCode({
                verificationRequestId: this.verificationRequestId,
                code: this.enteredCode
            });
            if (result && result.verified) {
                this.verified = true;
                this.step = STEP_RESIDENCE;
            } else {
                this.errorMessage = result.message || 'Verification failed.';
            }
        } catch (e) {
            this.errorMessage = this.extractMessage(e);
        } finally {
            this.isLoading = false;
        }
    }

    handleTileAdd(event) {
        const rangeId = event.currentTarget.dataset.rangeId;
        if (!this.tiles.find(t => t.rangeId === rangeId)) return;
        const current = this.cart[rangeId] || 0;
        this.cart = { ...this.cart, [rangeId]: current + 1 };
    }

    handleTileRemove(event) {
        const rangeId = event.currentTarget.dataset.rangeId;
        const current = this.cart[rangeId] || 0;
        if (current <= 0) return;
        const next = { ...this.cart };
        if (current - 1 <= 0) {
            delete next[rangeId];
        } else {
            next[rangeId] = current - 1;
        }
        this.cart = next;
    }

    handleRemoveLine(event) {
        const rangeId = event.currentTarget.dataset.rangeId;
        if (!(rangeId in this.cart)) return;
        const next = { ...this.cart };
        delete next[rangeId];
        this.cart = next;
        if (this.selectionCount === 0) {
            this.step = STEP_RESIDENCE;
        }
    }

    handleResidenceContinue() {
        if (this.selectionCount === 0) {
            this.errorMessage = 'Please choose at least one residence to continue.';
            return;
        }
        this.errorMessage = '';
        this.step = STEP_REVIEW;
    }

    handleHoneypotChange(event) {
        this.honeypot = event.target.value;
    }

    get isPayByCheque() { return this.form.paymentTypePreference === 'Cheque'; }
    get isWireTransfer() { return this.form.paymentTypePreference === 'Bank Transfer'; }
    get chequeClass() { return this.isPayByCheque ? 'segmented__option segmented__option--active' : 'segmented__option'; }
    get wireTransferClass() { return this.isWireTransfer ? 'segmented__option segmented__option--active' : 'segmented__option'; }

    handleSelectPaymentType(event) {
        const value = event.currentTarget.dataset.value;
        if (!value) return;
        this.form.paymentTypePreference = value;
        this.errorMessage = '';
    }

    async handleSubmit() {
        this.errorMessage = '';
        if (!this.form.paymentTypePreference) {
            this.errorMessage = 'Please select a payment type before submitting.';
            return;
        }
        this.isLoading = true;
        try {
            const dto = { ...this.form };
            dto.customerType = this.customerType;
            if (this.customerType === 'Organization') dto.emiratesId = '';
            dto.projectId = this.projectConfig.projectId;
            dto.verificationRequestId = this.verificationRequestId;
            dto.honeypot = this.honeypot;
            dto.elapsedMs = this.identityEnteredAt ? Date.now() - this.identityEnteredAt : 0;
            dto.userAgent = navigator.userAgent;
            dto.utmSource   = this.utm.utmSource;
            dto.utmCampaign = this.utm.utmCampaign;
            dto.utmMedium   = this.utm.utmMedium;
            dto.utmUrl      = this.utm.utmUrl;
            dto.adName      = this.utm.adName;
            dto.adSetName   = this.utm.adSetName;
            dto.utmSubSource = this.utm.subSource;
            const expanded = [];
            for (const line of this.selectedTilesView) {
                for (let i = 0; i < line.quantity; i++) {
                    expanded.push({
                        phaseId: line.phaseId,
                        eoiRangeId: line.rangeId,
                        unitType: line.unitType,
                        bedrooms: line.bedrooms,
                        unitTypology: line.unitTypology,
                        amount: line.amount
                    });
                }
            }
            dto.selections = expanded;
            const result = await submitRegistration({ dto });
            this.submission = result;
            if (result.status === 'Verified') {
                this.step = STEP_CONFIRMATION;
            } else if (result.status === 'QuotaClosed') {
                this.step = STEP_QUOTA_CLOSED;
            } else if (result.status === 'Duplicate') {
                this.errorMessage = result.message || 'A registration with this email already exists for the selected project.';
            } else if (result.status === 'Rejected') {
                this.errorMessage = 'Submission could not be processed.';
            } else {
                this.errorMessage = result.message || 'Submission was not accepted.';
            }
        } catch (e) {
            this.errorMessage = this.extractMessage(e);
        } finally {
            this.isLoading = false;
        }
    }

    handleBackToHero() {
        this.step = STEP_HERO;
    }

    makeSessionToken() {
        return 'sess-' + Math.random().toString(36).slice(2, 10);
    }

    extractMessage(error) {
        if (!error) return 'Something went wrong. Please try again.';
        if (error.body && error.body.message) return error.body.message;
        if (error.message) return error.message;
        return 'Something went wrong. Please try again.';
    }
}