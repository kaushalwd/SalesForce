import { LightningElement, track } from 'lwc';
import getActiveProject from '@salesforce/apex/EoiParTypologyController.getActiveProject';
import getParTiles from '@salesforce/apex/EoiParTypologyController.getParTiles';
import startVerification from '@salesforce/apex/EoiParTypologyController.startVerification';
import resendVerification from '@salesforce/apex/EoiParTypologyController.resendVerification';
import verifyCode from '@salesforce/apex/EoiParTypologyController.verifyCode';
import submitRegistration from '@salesforce/apex/EoiParTypologyController.submitRegistration';

const STEP_LOADING = 'loading';
const STEP_UNAVAILABLE = 'unavailable';
const STEP_HERO = 'hero';
const STEP_IDENTITY = 'identity';
const STEP_VERIFICATION = 'verification';
const STEP_TYPOLOGY = 'typology';
const STEP_REVIEW = 'review';
const STEP_CONFIRMATION = 'confirmation';

const TYPOLOGY_IMAGE_MAP = {
    'Par 3': '/sfsites/c/resource/Microsite_Typology/par-3.jpg',
    'Par 4': '/sfsites/c/resource/Microsite_Typology/par-4.jpg'
};

export default class EoiParTypologyJourney extends LightningElement {
    @track step = STEP_LOADING;
    @track isLoading = false;
    @track errorMessage = '';
    @track projectConfig = null;
    @track tiles = [];
    @track selectedRangeId = null;

    @track form = {
        firstName: '', lastName: '', email: '', mobile: '',
        residentStatus: 'Resident', emiratesId: '784-', passportNumber: ''
    };

    @track channel = 'Email';
    @track verificationRequestId = null;
    @track maskedTarget = '';
    @track enteredCode = '';

    @track utm = {
        utmSource: '', utmCampaign: '', utmMedium: '',
        utmUrl: '', utmSubSource: '', adName: '', adSetName: ''
    };

    @track confirmationReference = '';

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
                utmSubSource:(params.get('sub_source')   || '').substring(0, 255),
                adName:      (params.get('ad_name')      || '').substring(0, 255),
                adSetName:   (params.get('adset_name')   || '').substring(0, 255)
            };
        } catch (e) {
            // ignore
        }
    }

    async bootstrap() {
        this.isLoading = true;
        try {
            const cfg = await getActiveProject();
            this.projectConfig = cfg;
            if (!cfg || !cfg.projectId) {
                this.step = STEP_UNAVAILABLE;
                return;
            }
            try {
                this.tiles = await getParTiles({ projectId: cfg.projectId });
            } catch (e) {
                this.tiles = [];
            }
            this.step = STEP_HERO;
        } catch (e) {
            this.errorMessage = this.extractMessage(e);
            this.step = STEP_UNAVAILABLE;
        } finally {
            this.isLoading = false;
        }
    }

    get isLoadingStep() { return this.step === STEP_LOADING; }
    get isUnavailable() { return this.step === STEP_UNAVAILABLE; }
    get isHero() { return this.step === STEP_HERO; }
    get isIdentity() { return this.step === STEP_IDENTITY; }
    get isVerification() { return this.step === STEP_VERIFICATION; }
    get isTypology() { return this.step === STEP_TYPOLOGY; }
    get isReview() { return this.step === STEP_REVIEW; }
    get isConfirmation() { return this.step === STEP_CONFIRMATION; }

    get showStepHeader() {
        return this.step === STEP_IDENTITY ||
               this.step === STEP_VERIFICATION ||
               this.step === STEP_TYPOLOGY ||
               this.step === STEP_REVIEW;
    }

    get currentYear() { return new Date().getFullYear(); }

    get projectName() {
        return (this.projectConfig && this.projectConfig.name) || 'Hudayriyat Golf Estates';
    }

    get isResident() { return this.form.residentStatus === 'Resident'; }
    get isNonResident() {
        return this.form.residentStatus === 'Non-Resident' || this.form.residentStatus === 'Non Resident';
    }
    get isEmailChannel() { return this.channel === 'Email'; }
    get isSmsChannel() { return this.channel === 'SMS'; }

    get residentClass() {
        return this.isResident ? 'segmented__option segmented__option--active' : 'segmented__option';
    }
    get nonResidentClass() {
        return this.isNonResident ? 'segmented__option segmented__option--active' : 'segmented__option';
    }
    get emailChannelClass() {
        return this.isEmailChannel ? 'segmented__option segmented__option--active' : 'segmented__option';
    }
    get smsChannelClass() {
        return this.isSmsChannel ? 'segmented__option segmented__option--active' : 'segmented__option';
    }

    get tileViewModels() {
        return (this.tiles || []).map(t => ({
            ...t,
            isSelected: this.selectedRangeId === t.rangeId,
            tileClass: this.selectedRangeId === t.rangeId ? 'tile tile--selected' : 'tile',
            renderUrl: TYPOLOGY_IMAGE_MAP[t.unitTypology] || '/sfsites/c/resource/Microsite_Typology/golf-townhomes.jpg',
            startingPrice: this.formatStartingPrice(t.amount)
        }));
    }

    get selectedTileView() {
        if (!this.selectedRangeId) return null;
        const t = (this.tiles || []).find(x => x.rangeId === this.selectedRangeId);
        if (!t) return null;
        return { ...t, startingPrice: this.formatStartingPrice(t.amount) };
    }

    formatStartingPrice(amount) {
        if (amount == null) return '';
        const millions = Number(amount) / 1000000;
        const rounded = millions >= 10 ? Math.round(millions) : Math.round(millions * 10) / 10;
        return `Starts from AED ${rounded}M`;
    }

    handleStart() { this.step = STEP_IDENTITY; }

    handleSelectResidentStatus(event) {
        const value = event.currentTarget.dataset.value;
        if (value) this.form.residentStatus = value;
    }

    handleSelectChannel(event) {
        const value = event.currentTarget.dataset.value;
        if (value) this.channel = value;
    }

    handleFieldChange(event) {
        const field = event.target.dataset.field;
        if (!field) return;
        let value = event.target.value;
        if (field === 'emiratesId') {
            value = this.formatEmiratesId(value);
            event.target.value = value;
        } else if (field === 'mobile') {
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
        if (digits.length < 3) digits = '784';
        else if (!digits.startsWith('784')) digits = '784' + digits;
        digits = digits.substring(0, 15);
        const parts = ['784'];
        if (digits.length > 3) parts.push(digits.substring(3, 7));
        if (digits.length > 7) parts.push(digits.substring(7, 14));
        if (digits.length > 14) parts.push(digits.substring(14, 15));
        return parts.join('-') + (digits.length <= 3 ? '-' : '');
    }

    isValidEmail(value) {
        return /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test((value || '').trim());
    }

    isValidPhone(value) {
        return /^\+[1-9][0-9]{7,14}$/.test((value || '').trim());
    }

    handleIdentityContinue() {
        const required = ['firstName', 'lastName', 'email', 'mobile'];
        if (this.isResident) required.push('emiratesId');
        if (this.isNonResident) required.push('passportNumber');
        for (const f of required) {
            if (!this.form[f] || !this.form[f].toString().trim()) {
                this.errorMessage = 'Please complete all required fields before continuing';
                return;
            }
        }
        if (this.isResident && !/^784-[0-9]{4}-[0-9]{7}-[0-9]{1}$/.test(this.form.emiratesId)) {
            this.errorMessage = 'Please enter a valid Emirates ID (must start with 784, format 784-XXXX-XXXXXXX-X)';
            return;
        }
        if (!this.isValidEmail(this.form.email)) {
            this.errorMessage = 'Please enter a valid email address';
            return;
        }
        if (!this.isValidPhone(this.form.mobile)) {
            this.errorMessage = 'Please enter a valid phone number with country code (e.g., +9715XXXXXXXX)';
            return;
        }
        this.errorMessage = '';
        this.step = STEP_VERIFICATION;
    }

    handleBack() {
        const order = [STEP_HERO, STEP_IDENTITY, STEP_VERIFICATION, STEP_TYPOLOGY, STEP_REVIEW];
        const idx = order.indexOf(this.step);
        if (idx > 0) this.step = order[idx - 1];
    }

    async handleSendCode() {
        this.errorMessage = '';
        const target = this.channel === 'Email' ? this.form.email : this.form.mobile;
        if (!target || !target.trim()) {
            this.errorMessage = this.channel === 'Email'
                ? 'Please provide an email address before sending the code'
                : 'Please provide a mobile number before sending the code';
            return;
        }
        this.isLoading = true;
        try {
            const result = await startVerification({
                channel: this.channel,
                target: target.trim(),
                sessionToken: 'par-' + Math.random().toString(36).slice(2, 10)
            });
            this.verificationRequestId = result.verificationRequestId;
            this.maskedTarget = result.maskedTarget;
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
        } catch (e) {
            this.errorMessage = this.extractMessage(e);
        } finally {
            this.isLoading = false;
        }
    }

    async handleVerify() {
        this.errorMessage = '';
        if (!this.enteredCode || this.enteredCode.length < 4) {
            this.errorMessage = 'Please enter the verification code';
            return;
        }
        this.isLoading = true;
        try {
            const result = await verifyCode({
                verificationRequestId: this.verificationRequestId,
                code: this.enteredCode
            });
            if (result && result.verified) {
                this.step = STEP_TYPOLOGY;
            } else {
                this.errorMessage = (result && result.message) || 'Verification failed';
            }
        } catch (e) {
            this.errorMessage = this.extractMessage(e);
        } finally {
            this.isLoading = false;
        }
    }

    handleSelectTile(event) {
        const rangeId = event.currentTarget.dataset.rangeId;
        if (!rangeId) return;
        this.selectedRangeId = rangeId;
        this.errorMessage = '';
    }

    handleTypologyContinue() {
        if (!this.selectedRangeId) {
            this.errorMessage = 'Please choose a typology to continue';
            return;
        }
        this.errorMessage = '';
        this.step = STEP_REVIEW;
    }

    async handleSubmit() {
        this.errorMessage = '';
        this.isLoading = true;
        try {
            const tile = this.selectedTileView;
            if (!tile) {
                this.errorMessage = 'Please choose a typology to continue';
                return;
            }
            const dto = {
                firstName: this.form.firstName,
                lastName: this.form.lastName,
                email: this.form.email,
                mobile: this.form.mobile,
                phone: this.form.mobile,
                residentStatus: this.form.residentStatus,
                emiratesId: this.isResident ? this.form.emiratesId : '',
                passportNumber: this.isNonResident ? this.form.passportNumber : '',
                typology: tile.unitTypology,
                rangeId: this.selectedRangeId,
                projectId: this.projectConfig ? this.projectConfig.projectId : null,
                verificationRequestId: this.verificationRequestId,
                userAgent: navigator.userAgent || '',
                locale: 'en_US',
                utmSource: this.utm.utmSource,
                utmCampaign: this.utm.utmCampaign,
                utmMedium: this.utm.utmMedium,
                utmUrl: this.utm.utmUrl,
                utmSubSource: this.utm.utmSubSource,
                adName: this.utm.adName,
                adSetName: this.utm.adSetName
            };
            const result = await submitRegistration({ dto });
            if (result && result.recordId) {
                this.confirmationReference = result.referenceName || '';
                this.step = STEP_CONFIRMATION;
            } else {
                this.errorMessage = 'Submission could not be completed';
            }
        } catch (e) {
            this.errorMessage = this.extractMessage(e);
        } finally {
            this.isLoading = false;
        }
    }

    extractMessage(error) {
        if (!error) return 'Something went wrong. Please try again';
        if (error.body && error.body.message) return error.body.message;
        if (error.message) return error.message;
        return 'Something went wrong. Please try again';
    }
}