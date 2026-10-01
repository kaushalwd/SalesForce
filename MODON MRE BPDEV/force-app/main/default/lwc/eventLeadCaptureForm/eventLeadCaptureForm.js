import { LightningElement, api, track } from 'lwc';
import createLead from '@salesforce/apex/EventLeadCaptureController.createLead';
import validateCompanyEmail from '@salesforce/apex/MBP_LoqateIntegration.validateEmail';
import validatePhone from '@salesforce/apex/MBP_LoqateIntegration.validatePhone';

const DEFAULT_REDIRECT = 'https://www.modon.com';
const DEFAULT_BG =
    "linear-gradient(rgba(0,0,0,0.45), rgba(0,0,0,0.45)), url('https://v.fastcdn.co/u/250f902b/65494990-0-MODON-NawayefVillage.jpg')";
const DEFAULT_LOGO =
    'https://v.fastcdn.co/t/250f902b/33137049/1752777285-64980991-230x44-Modon-Logo-WHITEss.png';

export default class EventLeadCaptureForm extends LightningElement {
    @track isValidatingEmail = false;
    @track isEmailLoqateValid = false;

    @track isValidatingPhone = false;
    @track isPhoneLoqateValid = false;

    @track isSubmitting = false;

    @api defaultEventName = 'Event Lead';
    @api thankYouRedirectUrl = DEFAULT_REDIRECT;
    @api redirectDelayMs = 3000;
    @api backgroundImageUrl;
    @api logoUrl;
    @api propertyTypeOptionsCsv;
    @api representativeOptionsCsv;
    @api kioskName;
    @api customerBudgetOptionsCsv;
    @api isSalesPerson = false;

    showTermsError = false;

    form = {
        eventName: '',
        firstName: '',
        lastName: '',
        countryCode: '',
        phone: '',
        email: '',
        projectInterest: '',   // adding project interest
        propertyType: '',
        modonRepresentative: '',
        kioskName: '',
        customerBudget: '',
        isSalesPerson: false
    };

    showThankYou = false;
    agreeTerms = false;

    toastMessage = '';
    toastVariant = 'neutral';
    toastTimer;

    connectedCallback() {
        this.form.eventName = this.defaultEventName || 'Event Lead';
        if (this.kioskName) this.form.kioskName = this.kioskName;
        this.form.isSalesPerson = this.isSalesPerson;
    }

    get showLoader() {
        return this.isSubmitting || this.isValidatingEmail || this.isValidatingPhone;
    }

    get loaderText() {
        if (this.isSubmitting) return 'Submitting...';
        if (this.isValidatingEmail) return 'Validating email...';
        if (this.isValidatingPhone) return 'Validating phone...';
        return 'Loading...';
    }

    handleChange(event) {
        const name = event.target.name;
        const value = event.detail.value;

        if (name === 'email') {
            this.isEmailLoqateValid = false;
            const emailCmp = this.template.querySelector('[data-id="email"]');
            if (emailCmp) {
                emailCmp.setCustomValidity('');
                emailCmp.reportValidity();
            }
        }

        if (name === 'phone') {
            this.isPhoneLoqateValid = false;
            const phoneCmp = this.template.querySelector('[data-id="phone"]');
            if (phoneCmp) {
                phoneCmp.setCustomValidity('');
                phoneCmp.reportValidity();
            }
        }
        if (name === 'propertyType') {
            this.form = {
                ...this.form,
                propertyType: value,
                projectInterest: ''   // 👈 reset when type changes
            };
            return;
        }
        
        this.form = { ...this.form, [name]: value };
    }

    async validateEmail() {
        const emailCmp = this.template.querySelector('[data-id="email"]');
        const email = this.form.email;

        if (!emailCmp) return;

        if (!email || email.trim() === '') {
            emailCmp.setCustomValidity('');
            emailCmp.reportValidity();
            return;
        }

        if (this.isEmailLoqateValid || this.isValidatingEmail || this.isSubmitting) return;

        this.isValidatingEmail = true;

        try {
            await validateCompanyEmail({ email });
            this.isEmailLoqateValid = true;
            emailCmp.setCustomValidity('');
        } catch (e) {
            this.isEmailLoqateValid = false;
            emailCmp.setCustomValidity('Please enter a valid email address.');
        } finally {
            emailCmp.reportValidity();
            this.isValidatingEmail = false;
        }
    }

    validatePhone() {
        const phoneCmp = this.template.querySelector('[data-id="phone"]');
        const phone = this.form.phone;

        if (!phoneCmp) return;

        if (!phone || phone.trim() === '') {
            phoneCmp.setCustomValidity('Please enter a phone number');
            phoneCmp.reportValidity();
            this.isPhoneLoqateValid = false;
            return;
        }

        const phoneRegex = /^\+[0-9]{6,15}$/;

        if (!phoneRegex.test(phone)) {
            phoneCmp.setCustomValidity(
                'Phone number must start with + and contain digits only (e.g. +971501234567)'
            );
            phoneCmp.reportValidity();
            this.isPhoneLoqateValid = false;
            return;
        }

        phoneCmp.setCustomValidity('');
        phoneCmp.reportValidity();

        this.validatePhoneWithLoqate(phoneCmp, phone);
    }

    async validatePhoneWithLoqate(phoneCmp, phone) {
        if (this.isPhoneLoqateValid || this.isValidatingPhone || this.isSubmitting) return;

        this.isValidatingPhone = true;

        try {
            const isValid = await validatePhone({ phone });
            if (!isValid) {
                phoneCmp.setCustomValidity('Please enter a valid mobile number');
                this.isPhoneLoqateValid = false;
            } else {
                phoneCmp.setCustomValidity('');
                this.isPhoneLoqateValid = true;
            }
        } catch (e) {
            phoneCmp.setCustomValidity('Unable to validate phone number');
            this.isPhoneLoqateValid = false;
        } finally {
            phoneCmp.reportValidity();
            this.isValidatingPhone = false;
        }
    }

    get emailInputClass() {
        if (!this.form.email || this.form.email.trim() === '') return '';
        return !this.isEmailLoqateValid ? 'error-border' : 'normal-border';
    }

    get phoneInputClass() {
        if (!this.form.phone || this.form.phone.trim() === '') return '';
        return !this.isPhoneLoqateValid ? 'error-border' : 'normal-border';
    }

    async handleSubmit() {
        if (this.isSubmitting) return;
        
        this.showTermsError = false;
        if (this.isValidatingEmail || this.isValidatingPhone) {
            return;
        }

        if (!this.reportValidity()) return;

        
        this.validatePhone();
        const phoneCmp = this.template.querySelector('[data-id="phone"]');
        if (phoneCmp && (!phoneCmp.checkValidity() || !this.isPhoneLoqateValid)) {
            return;
        }

        if (!this.isPhoneLoqateValid) {
            if (phoneCmp) {
                phoneCmp.setCustomValidity('Please validate phone number before submitting.');
                phoneCmp.reportValidity();
            }
            return;
        }

        if (!this.isEmailLoqateValid) {
            const emailCmp = this.template.querySelector('[data-id="email"]');
            if (emailCmp) {
                emailCmp.setCustomValidity('Please validate email before submitting.');
                emailCmp.reportValidity();
            }
            return;
        }


        if (!this.agreeTerms) {
            this.showTermsError = true;
            return;
        }

        // if (!this.agreeTerms) {
        //     this.showLocalToast('You must agree to the terms and conditions.', 'error');
        //     return;
        // }

        this.isSubmitting = true;

        try {
            const payload = JSON.parse(JSON.stringify(this.form));
            await createLead({ inputJson: JSON.stringify(payload) });

            this.showLocalToast('Lead created successfully.', 'success');
            this.showThankYou = true;
            this.resetForm();
        } catch (error) {
            const message = error?.body?.message || 'An error occurred while creating the lead.';
            this.showLocalToast(message, 'error');
        } finally {
            this.isSubmitting = false;
        }
    }

    reportValidity() {
        const inputs = [...this.template.querySelectorAll('lightning-input, lightning-combobox')];
        return inputs.reduce((valid, input) => input.reportValidity() && valid, true);
    }

    resetForm() {
        this.form = {
            eventName: this.defaultEventName || 'Event Lead',
            firstName: '',
            lastName: '',
            countryCode: '',
            phone: '',
            email: '',
            projectInterest: '', // adding project interest
            propertyType: '',
            modonRepresentative: '',
            kioskName: this.kioskName || '',
            customerBudget: '',
            isSalesPerson: this.isSalesPerson
        };
        this.agreeTerms = false;
        this.isEmailLoqateValid = false;
        this.isPhoneLoqateValid = false;
    }

    showLocalToast(message, variant) {
        this.toastMessage = message;
        this.toastVariant = variant;
        clearTimeout(this.toastTimer);
        this.toastTimer = setTimeout(() => {
            this.toastMessage = '';
        }, 4000);
    }

    get backgroundStyle() {
        const image = this.backgroundImageUrl
            ? `linear-gradient(rgba(0,0,0,0.45), rgba(0,0,0,0.45)), url('${this.backgroundImageUrl}')`
            : DEFAULT_BG;
        return `background-image: ${image}; background-size: cover; background-position: center;`;
    }

    get logoSrc() {
        return this.logoUrl || DEFAULT_LOGO;
    }

    get toastClass() {
        return `toast ${this.toastVariant === 'error' ? 'toast-error' : 'toast-success'}`;
    }
// Project Interest Values 2026-12-02
    get projectInterestChoices() {
    const type = this.form.propertyType;

    if (!type) {
        return [];
    }

    if (type === 'Villa') {
        return [
            { label: 'Bashayer', value: 'Bashayer' },
            { label: 'Nawayef East', value: 'Nawayef East' },
            { label: 'Nawayef West', value: 'Nawayef Homes' },
            { label: 'Al Naseem', value: 'Al Naseem' },
             { label: 'Wadeem Gardens', value: 'Wadeem Gardens' }

        ];
    }

    if (type === 'Apartment') {
        return [
            { label: 'Reem Hills', value: 'Reem Hills' },
            { label: 'Bashayer', value: 'Bashayer' },
            { label: 'Tara', value: 'Tara' }
        ];
    }

    if (type === 'Townhouse') {
        return [
            { label: 'Reem Hills', value: 'Reem Hills' }
        ];
    }
    

    return [];
}


    get propertyTypeChoices() {
        const csv = this.propertyTypeOptionsCsv;
        if (!csv) {
            return [
                { label: 'Apartment', value: 'Apartment' },
                { label: 'Townhouse', value: 'Townhouse' },
                { label: 'Villa', value: 'Villa' }
                //{ label: 'Plot', value: 'Plot' }
            ];
        }
        return this.parseCsvOptions(csv);
    }

    get representativeChoices() {
        const csv = this.representativeOptionsCsv;
        if (!csv) {
            return [
                { label: 'Name Update here', value: 'Name Update here' },
                { label: 'Name Update here 2', value: 'Name Update here 2' },
                { label: 'Broker / Business Partner', value: 'Broker / Business Partner' }
            ];
        }
        return this.parseCsvOptions(csv);
    }

    parseCsvOptions(csv) {
        return csv
            .split(',')
            .map((item) => item.trim())
            .filter((item) => item.length > 0)
            .map((item) => ({ label: item, value: item }));
    }

    get customerBudgetChoices() {
        const csv = this.customerBudgetOptionsCsv;
        if (!csv) {
            return [
                { label: 'AED 0 - 5M', value: 'AED 0 - 5M' },
                { label: 'AED 5 - 10M', value: 'AED 5 - 10M' },
                { label: 'AED 10 - 15M', value: 'AED 10 - 15M' },
                { label: 'AED 15 - 20M', value: 'AED 15 - 20M' },
                { label: 'AED 20M+', value: 'AED 20M+' }
            ];
        }
        return this.parseCsvOptions(csv);
    }

    handleCheckboxChange(event) {
        this.agreeTerms = event.target.checked;
        if (this.agreeTerms) {
            this.showTermsError = false;
        }
    }

}