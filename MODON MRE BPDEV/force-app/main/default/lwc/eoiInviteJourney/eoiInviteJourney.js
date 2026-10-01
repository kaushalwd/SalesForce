import { LightningElement, track } from 'lwc';
import resolveInvite from '@salesforce/apex/EoiPublicInviteController.resolveInvite';
import startVerification from '@salesforce/apex/EoiPublicInviteController.startVerification';
import resendVerification from '@salesforce/apex/EoiPublicInviteController.resendVerification';
import verifyCode from '@salesforce/apex/EoiPublicInviteController.verifyCode';
import confirmInvite from '@salesforce/apex/EoiPublicInviteController.confirmInvite';
import getInviteTiles from '@salesforce/apex/EoiPublicInviteController.getInviteTiles';

const STEP_LOADING = 'loading';
const STEP_INVALID = 'invalid';
const STEP_EXPIRED = 'expired';
const STEP_ALREADY = 'already';
const STEP_HERO = 'hero';
const STEP_IDENTITY = 'identity';
const STEP_VERIFICATION = 'verification';
const STEP_TYPOLOGY = 'typology';
const STEP_REVIEW = 'review';
const STEP_CONFIRMATION = 'confirmation';

export default class EoiInviteJourney extends LightningElement {
    @track step = STEP_LOADING;
    @track isLoading = false;
    @track errorMessage = '';

    @track token = '';
    @track context = null;
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

    connectedCallback() {
        this.bootstrap();
    }

    async bootstrap() {
        this.isLoading = true;
        try {
            const params = new URLSearchParams(window.location.search || '');
            this.token = params.get('token') || '';
            if (!this.token) {
                this.step = STEP_INVALID;
                return;
            }
            const ctx = await resolveInvite({ token: this.token });
            this.context = ctx;
            if (!ctx || ctx.valid !== true) {
                this.step = ctx && ctx.expired ? STEP_EXPIRED : STEP_INVALID;
                return;
            }
            if (ctx.alreadyConfirmed === true) {
                this.step = STEP_ALREADY;
                return;
            }
            this.form.firstName = ctx.firstName || '';
            this.form.lastName = ctx.lastName || '';
            this.form.email = ctx.email || '';
            this.form.mobile = ctx.mobile || '';
            this.form.residentStatus = ctx.residentStatus || 'Resident';
            this.form.emiratesId = ctx.emiratesId || '784-';
            this.form.passportNumber = ctx.passportNumber || '';

            if (ctx.projectId) {
                try {
                    this.tiles = await getInviteTiles({ projectId: ctx.projectId });
                } catch (e) {
                    this.tiles = [];
                }
            }
            this.step = STEP_HERO;
        } catch (e) {
            this.errorMessage = this.extractMessage(e);
            this.step = STEP_INVALID;
        } finally {
            this.isLoading = false;
        }
    }

    get showStepHeader() {
        return this.step === STEP_IDENTITY ||
               this.step === STEP_VERIFICATION ||
               this.step === STEP_TYPOLOGY ||
               this.step === STEP_REVIEW;
    }

    get currentYear() { return new Date().getFullYear(); }

    get isLoadingStep() { return this.step === STEP_LOADING; }
    get isInvalid() { return this.step === STEP_INVALID; }
    get isExpired() { return this.step === STEP_EXPIRED; }
    get isAlready() { return this.step === STEP_ALREADY; }
    get isHero() { return this.step === STEP_HERO; }
    get isIdentity() { return this.step === STEP_IDENTITY; }
    get isVerification() { return this.step === STEP_VERIFICATION; }
    get isTypology() { return this.step === STEP_TYPOLOGY; }
    get isReview() { return this.step === STEP_REVIEW; }
    get isConfirmation() { return this.step === STEP_CONFIRMATION; }

    get isResident() { return this.form.residentStatus === 'Resident'; }
    get isNonResident() { return this.form.residentStatus === 'Non-Resident' || this.form.residentStatus === 'Non Resident'; }
    get isEmailChannel() { return this.channel === 'Email'; }
    get isSmsChannel() { return this.channel === 'SMS'; }
    get residentClass() { return this.isResident ? 'segmented__option segmented__option--active' : 'segmented__option'; }
    get nonResidentClass() { return this.isNonResident ? 'segmented__option segmented__option--active' : 'segmented__option'; }
    get emailChannelClass() { return this.isEmailChannel ? 'segmented__option segmented__option--active' : 'segmented__option'; }
    get smsChannelClass() { return this.isSmsChannel ? 'segmented__option segmented__option--active' : 'segmented__option'; }

    get welcomeName() {
        return this.context && this.context.firstName ? this.context.firstName : 'there';
    }

    get projectName() {
        return (this.context && this.context.projectName) || 'Hudayriyat Golf Estates';
    }

    get formattedConfirmedAt() {
        if (!this.context || !this.context.confirmedAt) return '';
        const d = new Date(this.context.confirmedAt);
        return d.toLocaleString().replace(/\s?(AM|PM)$/i, '');
    }

    get tileViewModels() {
        return (this.tiles || []).map(t => ({
            ...t,
            isSelected: this.selectedRangeId === t.rangeId,
            tileClass: this.selectedRangeId === t.rangeId ? 'tile tile--selected' : 'tile',
            renderUrl: this.typologyRenderUrl(t.unitTypology),
            formattedAmount: t.amount ? Number(t.amount).toLocaleString('en-US', { maximumFractionDigits: 0 }) : ''
        }));
    }

    typologyRenderUrl(unitTypology) {
        const slug = (unitTypology || '')
            .toLowerCase()
            .replace(/[\s ]+/g, '-')
            .replace(/[^a-z0-9-]/g, '')
            .replace(/-+/g, '-')
            .replace(/^-|-$/g, '');
        return slug
            ? `/sfsites/c/resource/Microsite_Typology/${slug}.jpg`
            : `/sfsites/c/resource/Microsite_Typology/golf-homes.jpg`;
    }

    get selectedTileView() {
        if (!this.selectedRangeId) return null;
        const t = (this.tiles || []).find(x => x.rangeId === this.selectedRangeId);
        if (!t) return null;
        return {
            ...t,
            formattedAmount: t.amount ? Number(t.amount).toLocaleString('en-US', { maximumFractionDigits: 0 }) : ''
        };
    }

    handleStart() {
        this.step = STEP_IDENTITY;
    }

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
                this.errorMessage = 'Please complete all required fields before continuing.';
                return;
            }
        }
        if (this.isResident && !/^784-[0-9]{4}-[0-9]{7}-[0-9]{1}$/.test(this.form.emiratesId)) {
            this.errorMessage = 'Please enter a valid Emirates ID (must start with 784, format 784-XXXX-XXXXXXX-X).';
            return;
        }
        if (!this.isValidEmail(this.form.email)) {
            this.errorMessage = 'Please enter a valid email address.';
            return;
        }
        if (!this.isValidPhone(this.form.mobile)) {
            this.errorMessage = 'Please enter a valid phone number with country code (e.g., +9715XXXXXXXX). Country code must not start with 0.';
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
                ? 'Please provide an email address before sending the code.'
                : 'Please provide a mobile number before sending the code.';
            return;
        }
        this.isLoading = true;
        try {
            const result = await startVerification({
                token: this.token,
                channel: this.channel,
                sessionToken: 'invite-' + Math.random().toString(36).slice(2, 10),
                target: target.trim()
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
            this.errorMessage = 'Please enter the verification code.';
            return;
        }
        this.isLoading = true;
        try {
            const result = await verifyCode({ verificationRequestId: this.verificationRequestId, code: this.enteredCode });
            if (result && result.verified) {
                this.step = STEP_TYPOLOGY;
            } else {
                this.errorMessage = (result && result.message) || 'Verification failed.';
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
            this.errorMessage = 'Please choose a typology to continue.';
            return;
        }
        this.errorMessage = '';
        this.step = STEP_REVIEW;
    }

    async handleConfirm() {
        this.errorMessage = '';
        this.isLoading = true;
        try {
            const dto = {
                token: this.token,
                verificationRequestId: this.verificationRequestId,
                rangeId: this.selectedRangeId,
                firstName: this.form.firstName,
                lastName: this.form.lastName,
                email: this.form.email,
                mobile: this.form.mobile,
                residentStatus: this.form.residentStatus,
                emiratesId: this.isResident ? this.form.emiratesId : '',
                passportNumber: this.isNonResident ? this.form.passportNumber : ''
            };
            const result = await confirmInvite({ req: dto });
            if (result && result.success) {
                this.step = STEP_CONFIRMATION;
            } else if (result && result.alreadyConfirmed) {
                this.context = { ...this.context, alreadyConfirmed: true, confirmedAt: result.confirmedAt };
                this.step = STEP_ALREADY;
            } else {
                this.errorMessage = (result && result.message) || 'Confirmation could not be completed.';
            }
        } catch (e) {
            this.errorMessage = this.extractMessage(e);
        } finally {
            this.isLoading = false;
        }
    }

    extractMessage(error) {
        if (!error) return 'Something went wrong. Please try again.';
        if (error.body && error.body.message) return error.body.message;
        if (error.message) return error.message;
        return 'Something went wrong. Please try again.';
    }
}