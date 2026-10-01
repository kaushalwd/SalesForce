import { LightningElement, api } from 'lwc';
import basePath from '@salesforce/community/basePath';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import Toast from 'lightning/toast';

import getUserProfileDetails from '@salesforce/apex/MBP_BrokerUserProfilecontroller.getUserProfileDetails';
import uploadUserPicture from '@salesforce/apex/MBP_BrokerUserProfilecontroller.uploadUserPicture';
import resetPassword from '@salesforce/apex/MBP_BrokerUserProfilecontroller.resetPassword';
import updateContactDetails from '@salesforce/apex/MBP_BrokerUserProfilecontroller.updateContactDetails';
import getNationalityPicklistValues from '@salesforce/apex/MBP_BrokerUserProfilecontroller.getNationalityPicklistValues';
import validatePhone from '@salesforce/apex/MBP_LoqateIntegration.validatePhone';

import { COUNTRY_CODE_OPTIONS } from './countryCodes';

const UAE_STATUS_OPTIONS = [
    { label: 'Resident', value: 'Resident' },
    { label: 'Non-Resident', value: 'Non-Resident' }
];

export default class MbprProfilePanel extends LightningElement {
    @api signOutUrl = '';

    isInitializing = true;
    isActionPending = false;
    loadError = '';

    contactId = '';
    firstName = '';
    lastName = '';
    username = '';
    emailAddress = '';
    mobilePhone = '';
    brokerType = '';
    country = 'N/A';
    nationality = 'N/A';
    residentStatus = 'N/A';
    profilePhoto = '/sfsites/c/resource/defaultProfile';

    // Upload image modal
    showImageModal = false;
    previewPhoto = '';
    stagedImageBase64 = '';

    // Update profile modal
    showEditModal = false;
    editableMobileCountryCode = '';
    editableMobileNumber = '';
    originalPhone = '';
    editableUaeStatus = '';
    editableNationality = '';
    nationalityOptions = [];
    mobileValidated = false;
    mobileValidating = false;
    mobileButtonLabel = 'Validate Mobile';

    // Reset password modal
    showPasswordModal = false;
    oldPassword = '';
    newPassword = '';
    confirmPassword = '';

    _modalOpener = null;

    connectedCallback() {
        this.fetchProfileDetails();
    }

    async fetchProfileDetails() {
        this.isInitializing = true;
        this.loadError = '';
        try {
            const result = await getUserProfileDetails();
            const contact = (result && result.Contact) || {};
            this.contactId = contact.Id || '';
            this.firstName = contact.FirstName || '';
            this.lastName = contact.LastName || '';
            this.emailAddress = contact.Email || '';
            this.brokerType = contact.Broker_Type__c || '';
            this.username = (result && result.Username) || '';
            this.country = (result && result.Country) || 'N/A';
            this.nationality = contact.Nationality__c || 'N/A';
            this.residentStatus = contact.UAE_Resident_Status__c || 'N/A';

            if (contact.Phone) {
                const phoneParts = contact.Phone.split(/[-\s]/);
                if (phoneParts.length > 1) {
                    this.editableMobileCountryCode = phoneParts[0].replace('+', '');
                    this.editableMobileNumber = phoneParts.slice(1).join('');
                    this.mobilePhone = `+${this.editableMobileCountryCode} ${this.editableMobileNumber}`;
                } else {
                    // Legacy rendered "+undefined <number>"; show the raw value
                    // and let the user pick the code.
                    this.editableMobileCountryCode = '';
                    this.editableMobileNumber = contact.Phone;
                    this.mobilePhone = contact.Phone;
                }
                this.mobileValidated = true;
                this.mobileButtonLabel = 'Validated';
                this.originalPhone = this.editableMobileNumber;
            } else {
                this.editableMobileCountryCode = '';
                this.editableMobileNumber = '';
                this.mobilePhone = '';
                this.mobileValidated = false;
                this.mobileButtonLabel = 'Validate Mobile';
            }

            const photoUrl = result && result.FullPhotoUrl;
            this.profilePhoto = photoUrl
                ? `${photoUrl}${photoUrl.includes('?') ? '&' : '?'}t=${Date.now()}`
                : '/sfsites/c/resource/defaultProfile';
        } catch (error) {
            this.loadError = this.reduceError(error) || 'Unable to load your profile right now. Please try again.';
        } finally {
            this.isInitializing = false;
        }
    }

    handleRetryLoad() {
        this.fetchProfileDetails();
    }

    get effectiveSignOutUrl() {
        if (this.signOutUrl) return this.signOutUrl;
        // Site-scoped logout servlet; basePath resolves per environment.
        const sitePrefix = basePath || '';
        return `${sitePrefix}/secur/logout.jsp?retUrl=${encodeURIComponent(`${sitePrefix}/login`)}`;
    }

    get acceptedPhotoFormats() {
        return ['.jpg', '.jpeg', '.png'];
    }

    get countryCodeOptions() {
        return COUNTRY_CODE_OPTIONS;
    }

    get uaeStatusOptions() {
        return UAE_STATUS_OPTIONS;
    }

    get mobileValidateDisabled() {
        return this.mobileValidating;
    }

    // ------------------------------------------------------------------
    // Upload Profile Image
    // ------------------------------------------------------------------

    showProfileImagePopup(event) {
        this._modalOpener = event ? event.currentTarget : null;
        this.previewPhoto = this.profilePhoto;
        this.stagedImageBase64 = '';
        this.showImageModal = true;
    }

    hideProfileImagePopup() {
        this.showImageModal = false;
        // Legacy kept a cancelled selection staged; clear it so Cancel means cancel.
        this.stagedImageBase64 = '';
        this.previewPhoto = '';
        this.restoreFocus();
    }

    handleImagePreview(event) {
        const file = event.target.files && event.target.files[0];
        if (!file) return;
        const reader = new FileReader();
        reader.onload = () => {
            this.stagedImageBase64 = reader.result.split(',')[1];
            this.previewPhoto = reader.result;
        };
        reader.readAsDataURL(file);
    }

    async submitProfileImage() {
        if (!this.stagedImageBase64) {
            this.showToast('No image selected', 'error');
            return;
        }
        this.isActionPending = true;
        try {
            const result = await uploadUserPicture({ baseData: this.stagedImageBase64 });
            if (result && result.success === 'true') {
                this.showToast(result.msg, 'success');
                this.showImageModal = false;
                this.stagedImageBase64 = '';
                this.previewPhoto = '';
                await this.fetchProfileDetails();
            } else {
                this.showToast((result && result.msg) || 'Upload failed.', 'error');
            }
        } catch (error) {
            this.showToast(this.reduceError(error) || 'Upload failed.', 'error');
        } finally {
            this.isActionPending = false;
        }
    }

    handleImageModalKeydown(event) {
        if (event.key === 'Escape') {
            event.stopPropagation();
            this.hideProfileImagePopup();
        }
    }

    // ------------------------------------------------------------------
    // Update Profile
    // ------------------------------------------------------------------

    openEditProfileModal(event) {
        this._modalOpener = event ? event.currentTarget : null;
        // Seed with '' rather than the display fallback 'N/A', which is not a
        // real picklist entry.
        this.editableNationality = this.nationality === 'N/A' ? '' : this.nationality;
        this.editableUaeStatus = this.residentStatus === 'N/A' ? '' : this.residentStatus;
        this.showEditModal = true;
        getNationalityPicklistValues()
            .then((result) => {
                if (result && result.success) {
                    this.nationalityOptions = (result.values || []).map((value) => ({ label: value, value }));
                } else {
                    this.nationalityOptions = [];
                }
            })
            .catch(() => {
                this.nationalityOptions = [];
            });
    }

    closeEditProfileModal() {
        this.showEditModal = false;
        this.restoreFocus();
    }

    handleEditModalKeydown(event) {
        if (event.key === 'Escape') {
            event.stopPropagation();
            this.closeEditProfileModal();
        }
    }

    handleMobileCountryCodeChange(event) {
        this.editableMobileCountryCode = event.detail.value;
        if (this.mobileValidated) {
            this.mobileValidated = false;
            this.mobileButtonLabel = 'Validate Mobile';
        }
    }

    handleMobileNumberChange(event) {
        this.editableMobileNumber = event.target.value;
        if (this.mobileValidated && this.editableMobileNumber !== this.originalPhone) {
            this.mobileValidated = false;
            this.mobileButtonLabel = 'Validate Mobile';
        }
    }

    handleUaeStatusChange(event) {
        this.editableUaeStatus = event.detail.value;
    }

    handleNationalityChange(event) {
        this.editableNationality = event.detail.value;
    }

    handleMobileValidation() {
        if (this.mobileValidated && this.editableMobileNumber === this.originalPhone) {
            this.showToast('Mobile number already validated.', 'success');
            return;
        }
        if (!this.editableMobileCountryCode || !this.editableMobileNumber) {
            this.showToast('Please enter country code and mobile number.', 'error');
            return;
        }
        const countryCode = this.editableMobileCountryCode.startsWith('+')
            ? this.editableMobileCountryCode
            : '+' + this.editableMobileCountryCode;
        this.mobileValidating = true;
        this.mobileButtonLabel = 'Validating...';
        validatePhone({ phone: countryCode + this.editableMobileNumber })
            .then((result) => {
                if (result === true) {
                    this.mobileValidated = true;
                    this.originalPhone = this.editableMobileNumber;
                    this.mobileButtonLabel = 'Validated';
                    this.showToast('Mobile number is valid.', 'success');
                } else {
                    this.mobileValidated = false;
                    this.mobileButtonLabel = 'Validate Mobile';
                    this.showToast('Entered number is not valid.', 'error');
                }
            })
            .catch((error) => {
                this.mobileValidated = false;
                this.mobileButtonLabel = 'Validate Mobile';
                this.showToast(this.reduceError(error) || 'An unexpected error occurred', 'error');
            })
            .finally(() => {
                this.mobileValidating = false;
            });
    }

    async submitProfileUpdate() {
        if (!this.contactId) return;
        if (!this.mobileValidated) {
            this.showToast('Please validate your mobile number before updating your profile.', 'error');
            return;
        }
        this.isActionPending = true;
        try {
            // Persisted format matches legacy exactly: "+<code> <number>".
            await updateContactDetails({
                contactId: this.contactId,
                phone: `+${this.editableMobileCountryCode} ${this.editableMobileNumber}`,
                uaeStatus: this.editableUaeStatus,
                nationality: this.editableNationality
            });
            this.showToast('Profile updated successfully', 'success');
            this.showEditModal = false;
            await this.fetchProfileDetails();
        } catch (error) {
            this.showToast(this.reduceError(error) || 'An unexpected error occurred', 'error');
        } finally {
            this.isActionPending = false;
        }
    }

    // ------------------------------------------------------------------
    // Reset Password
    // ------------------------------------------------------------------

    openPasswordModal(event) {
        this._modalOpener = event ? event.currentTarget : null;
        this.oldPassword = '';
        this.newPassword = '';
        this.confirmPassword = '';
        this.showPasswordModal = true;
    }

    closePasswordModal() {
        this.showPasswordModal = false;
        this.oldPassword = '';
        this.newPassword = '';
        this.confirmPassword = '';
        this.restoreFocus();
    }

    handlePasswordModalKeydown(event) {
        if (event.key === 'Escape') {
            event.stopPropagation();
            this.closePasswordModal();
        }
    }

    handleOldPasswordChange(event) {
        this.oldPassword = event.target.value;
    }

    handleNewPasswordChange(event) {
        this.newPassword = event.target.value;
    }

    handleConfirmPasswordChange(event) {
        this.confirmPassword = event.target.value;
    }

    async submitPasswordReset() {
        if (!this.oldPassword || !this.newPassword || !this.confirmPassword) {
            this.showToast('Complete Mandatory Fields.', 'error');
            return;
        }
        if (this.newPassword !== this.confirmPassword) {
            const target = this.template.querySelector('[data-id="confirmPassword"]');
            if (target) {
                target.setCustomValidity('New Password and Confirm Password must match.');
                target.reportValidity();
            }
            return;
        }
        const target = this.template.querySelector('[data-id="confirmPassword"]');
        if (target) {
            target.setCustomValidity('');
            target.reportValidity();
        }
        this.isActionPending = true;
        try {
            await resetPassword({
                newPassword: this.newPassword,
                verifyNewPassword: this.confirmPassword,
                oldPassword: this.oldPassword
            });
            this.showToast('Password updated successfully', 'success');
            this.closePasswordModal();
        } catch (error) {
            this.showToast(this.reduceError(error) || 'An unexpected error occurred', 'error');
        } finally {
            this.isActionPending = false;
        }
    }

    // ------------------------------------------------------------------
    // Utilities
    // ------------------------------------------------------------------

    restoreFocus() {
        if (this._modalOpener && this._modalOpener.isConnected) {
            this._modalOpener.focus();
        }
        this._modalOpener = null;
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