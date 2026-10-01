import { LightningElement, track, api } from 'lwc';
import {loadScript,loadStyle} from 'lightning/platformResourceLoader';
import ModonImages from "@salesforce/resourceUrl/modonImages";
import Bootstrap from "@salesforce/resourceUrl/Bootstrap";
import { ShowToastEvent } from 'lightning/platformShowToastEvent'
import ToastContainer from 'lightning/toastContainer';
import REGISTRATION_OBJECT from '@salesforce/schema/Registration__c';
import REGISTRATION_AGENT_OBJECT from '@salesforce/schema/Registration_Agent__c';
import EMAIL_FIELD from '@salesforce/schema/Registration__c.Company_Email_Address__c';
import findRegistrationByEmail from '@salesforce/apex/MBP_RegistrationFormController.findRegistrationByEmail';
import verifyOTP from '@salesforce/apex/MBP_RegistrationFormController.verifyOTP';
import findRegistrationAndSendOTP from '@salesforce/apex/MBP_RegistrationFormController.findRegistrationAndSendOTP';
import findRegistrationWithReviewComment from '@salesforce/apex/Draftstagecontroller.findRegistrationWithReviewComment';
import shouldShowBrokerContent from '@salesforce/apex/MBP_BrokerAgencyInformationController.shouldShowBrokerContent';

export default class RegistrationForm extends LightningElement {
@track registrationObj = { Status__c: 'Draft' };
@track mode = 'draft';
@track isLimitedDraftMode = false;


      @track showNextButton=true;

        @track enteredOTP = '';
    @track taskComment;
   @track showContent = false;

    logo = ModonImages+"/modonImages/brand-logo-black.png";
    logowhite = ModonImages+"/modonImages/brand-logo-white.png";
    backgroundImage = ModonImages+"/modonImages/bg-theme-pic.png";
    @api recordId;
    @track currentStep = 'initial';
    @track enteredOTP = ''; // Or just a regular property
registrationRecordId;
otpSent = false;
enteredOTP = '';
showOTPInput = false;

 @track showInProgressPopup = false;
    @track email = '';
    @track hasExistingRecord = false;
    @track nextButtonLabel = 'Next';
    @track steps = [
        { label: 'Company Information', stepNumber: '1' },
        { label: 'Trade License Information', stepNumber: '2' },
        { label: 'Owner Information', stepNumber: '3' },
        { label: 'Agency Admin Information', stepNumber: '4' },
        { label: 'Bank Information', stepNumber: '5' }
    ];
    @track objectApiName = '';
    @track regiAgentObjectApiName = '';
    @track registrationRecordId = null;
    @track registrationAgentrecordId;
    @track showStatusMessage = false;
    @track statusMessage = '';
    emailField = EMAIL_FIELD;
    currentToast = null;
    toastContainer;
    alwayshide=false;
    registrationObj = {};
    @track isLoading = false;

    get showInitial() { return this.currentStep === 'initial'; }
    get showStep1() { return this.currentStep === '1'; }
    get showStep2() { return this.currentStep === '2'; }
    get showStep3() { return this.currentStep === '3'; }
    get showStep4() { return this.currentStep === '4'; }
    get showStep5() { return this.currentStep === '5'; }
get backgroundStyle() {
        return `background-image: url('${this.backgroundImage}');background-size: cover;background-repeat: no-repeat;background-position: center; margin:0!important;`;
    }
    connectedCallback() {
    this.checkPermissionAndHide();

    if (this.mode === 'draft') {
        this.autoFetchForLimitedUser(); // 🔁 Directly load draft content
        this.showInitial = false; // 🚫 Skip initial screen
    }

    // Load styles as-is
    Promise.all([
        loadStyle(this, Bootstrap + '/css/bootstrap.min.css'),
        loadScript(this, Bootstrap + '/js/bootstrap.bundle.min.js')
    ])
    .catch(error => {
        console.error('Error loading styles', error);
    });

    this.isLoading = true;
    this.toastContainer = ToastContainer.instance();
    this.toastContainer.maxShown = 3;

    this.objectApiName = REGISTRATION_OBJECT.objectApiName;
    this.regiAgentObjectApiName = REGISTRATION_AGENT_OBJECT.objectApiName;
    this.registrationRecordId = this.recordId;
    this.updateSteps();

    if (this.recordId && this.mode !== 'draft') {
        this.hasExistingRecord = true;
        this.currentStep = '1';
        this.updateSteps();
    }

    setTimeout(() => {
        this.isLoading = false;
    }, 1000);
}

 get showDeleteIcon() {
        return this.mode?.toLowerCase() === 'draft' && this.registrationStatus !== 'Submitted';
    }
async checkPermissionAndHide() {
    try {
        const result = await shouldShowBrokerContent(); 
        // result is true if user does NOT have Modon Limited Login Access
        // So we HIDE if result is true
        this.showContent = !result; // ✅ Flip the logic here
    } catch (error) {
        console.error('❌ Error checking permission:', error);
        this.showContent = false;
    }
}
handleClosePopup() {
    this.showInProgressPopup = false;
}
get shouldShowLeftPanel() {
    return this.taskComment && this.taskComment.trim() !== '';
}
get shouldShowNextButton() {
    // ❗ Only hide button on step 5 and when status is Submitted
    return !(this.currentStep === '5' && this.registrationObj.Status__c === 'Submitted');
}
  async autoFetchForLimitedUser() {
    this.isLoading = true;

    try {
        const resultWrapper = await findRegistrationWithReviewComment();

        if (resultWrapper) {
            this.showCommentSection = resultWrapper.hasAccess;

            if (resultWrapper.registration) {
                this.registrationObj = resultWrapper.registration;
                this.recordId = resultWrapper.registration.Id; // ✅ Assign dynamic recordId
                 this.isLimitedDraftMode = true;

                this.hasExistingRecord = true;
                this.taskComment = resultWrapper.taskComment || '';
                this.taskCommentCount = this.taskComment ? 1 : 0;
                     if (resultWrapper.registration.Status__c === 'Submitted') {
                    this.showInProgressPopup = true;
                    this.showNextButton=false;
                }

                this.currentStep = '1';
                this.updateSteps();
            }
        }
    } catch (error) {
        console.error('❌ Error fetching limited access registration:', error);
        this.showToast({
            title: 'Error',
            message: error.body?.message || 'Unable to load your registration. Please try again later.',
            variant: 'error'
        });
    } finally {
        this.isLoading = false;
    }
}
get shouldShowPreviousButton() {
    const isFirstStep = this.currentStep === '1';

    // ✅ Only hide Previous for limited users in draft mode on step 1
    if (this.mode === 'draft' && isFirstStep && this.isLimitedDraftMode) {
        return false;
    }

    return true;
}






    handleEmailChange(event) {
        this.email = event.target.value;
    }

    handleKeyPress(event) {
        if (event.key === 'Enter') {
            this.handleSearch();
        }
    }
handleOtpChange(event) {
    this.enteredOTP = event.target.value;
}

  openModal(recordId) {
        this.registrationRecordId = recordId;
        this.showOTPInput = true;
    }

    closeModal() {
        this.showOTPInput = false;
        this.enteredOTP = '';
    }
async handleSendOtp() {
    this.isLoading = true;
    try {
        const result = await findRegistrationAndSendOTP({ inputValue: this.email });

        if (result === 'ERROR_NoInput') {
            this.showToast({
                title: 'Error',
                message: 'Please enter an email or trade license number.',
                variant: 'error'
            });
            return;
        }

        if (result === 'ERROR_NoRecord') {
            this.showToast({
                title: 'No Record Found',
                message: 'No existing registration record was found for the given input.',
                variant: 'warning'
            });
            return;
        }

        if (result.startsWith('STATUS_')) {
            this.showToast({
                title: 'Status Info',
                message: `Record is already in ${result.replace('STATUS_', '')} status.`,
                variant: 'info',
                mode: 'pester' 
            });
            return;
        }

        // Success
        this.registrationRecordId = result;
        this.showOTPInput = true;
        this.showToast({
            title: 'Existing Record Found!',
            message: 'An OTP has been sent to your Company email address.',
            variant: 'success'
        });

    } catch (error) {
        this.showToast({
            title: 'Error',
            message: error.body?.message || 'Error sending OTP',
            variant: 'error'
        });
        console.error('OTP Error:', JSON.stringify(error));
    } finally {
        this.isLoading = false;
    }
}

// STEP 2: Verify OTP
async handleVerifyOtp() {
    this.isLoading = true;
    try {
        const isValid = await verifyOTP({ recordId: this.registrationRecordId, userOTP: this.enteredOTP });
        if (isValid) {
            this.showToast({
                title: 'OTP verified successfully.',
    message: 'Please proceed to update the existing record.',
                variant: 'success'
            });
            // Step 3: Call handleSearch now
            await this.handleSearch(); 
        } else {
            this.showToast({
                title: 'Invalid OTP',
                message: 'The OTP you entered is incorrect. Please try again.',
                variant: 'error'
            });
        }
    } catch (error) {
        this.showToast({
            title: 'Error',
            message: error.body?.message || 'Error verifying OTP',
            variant: 'error'
        });
    } finally {
        this.isLoading = false;
    }
}




    async handleSearch() {
        this.isLoading = true;
        this.showOTPInput=false;
        if (!this.email) {
            this.showToast({
                title: 'Error',
                message: 'Please enter a company email address to search.',
                variant: 'error'
            });
            this.isLoading = false;
            return;
        }
        this.showStatusMessage = false;
       
        try {
            const result = await findRegistrationByEmail({ email: this.email });
            if (result) {
                this.registrationObj = result;
                if (result.Status__c !== 'Draft') {
                    this.showStatusMessage = true;
                    this.statusMessage = `Your application is currently at ${result.Status__c}. Please wait while we complete your request.`;
                    this.email = '';
                    this.recordId = null;
                    this.registrationRecordId = null;
                    this.hasExistingRecord = false;
                    this.isLoading = false;
                    return;
                }
                this.recordId = result.Id;
                this.registrationRecordId = result.Id;
                this.hasExistingRecord = true;
                this.currentStep = '1';
                this.updateSteps();
                
            } else {
                this.recordId = null;
                this.registrationRecordId = null;
                this.hasExistingRecord = false;
                this.currentStep = '1';
                this.updateSteps();
                this.showToast({
                    title: 'Info',
                    message: 'No existing record found. Proceed to create a new request.',
                    variant: 'info'
                });
            }
        } catch (error) {
            this.showToast({
                title: 'Error',
                message: error.body?.message || 'Unable to search for the record. Please try again later.',
                variant: 'error'
            });
            console.error('Error in handleSearch:', JSON.stringify(error));
        }finally {
            this.isLoading = false; 
        }
    }

    handleClear() {
        this.email = '';
        this.recordId = null;
        this.registrationRecordId = null;
        this.hasExistingRecord = false;
        this.currentStep = 'initial';
        this.updateSteps();        
    }

    handleCreateNew() {
        this.isLoading = true;
        this.recordId = null;
        this.registrationRecordId = null;
        this.hasExistingRecord = false;
        this.email = '';
        this.currentStep = '1';
        this.showStatusMessage = false;
        this.updateSteps();
        setTimeout(() => {
            this.isLoading = false;
        }, 1000);
    }

    handlePrevious() {
        this.isLoading = true;
        if (this.currentStep === '1') {
            this.currentStep = 'initial';
            this.showStatusMessage = false;
        } else {
            const current = parseInt(this.currentStep, 10);
            if (current > 1) {
                this.currentStep = (current - 1).toString();
            }
        }
        this.updateSteps();
        setTimeout(() => {
            this.isLoading = false;
        }, 500);
    }

    async handleNext() {
        this.isLoading = true;
        let childForm;
        if (this.currentStep === '1') {
            childForm = this.template.querySelector('c-company-information-form2');
        } else if (this.currentStep === '2') {
            childForm = this.template.querySelector('c-trade-license-form2');
        } else if (this.currentStep === '3') {
            childForm = this.template.querySelector('c-owner-information-form4');
        } else if (this.currentStep === '4') {
            childForm = this.template.querySelector('c-agency-admin-form3');
        }  else if (this.currentStep === '5') {
            childForm = this.template.querySelector('c-bank-information-form2');
        }

        if (childForm) {
            try {
                childForm.submitForm();
            } catch (error) {
                console.error('Error submitting form:', error);
                this.showToast({
                    title: 'Error',
                    message: error.message || 'Unable to submit the form. Please try again.',
                    variant: 'error'
                });
            }finally {
                this.isLoading = false;
            }
        } else {
            this.showToast({
                title: 'Error',
                message: 'Form not found. Please try again or contact support.',
                variant: 'error'
            });
        }
    }

    async handleFormSuccess(event) {
        const current = parseInt(this.currentStep, 10);

        if(this.currentStep === '3' || this.currentStep == '4'){
            this.registrationAgentrecordId = event.detail.id;
            await this.moveToNextStep(current, event.detail.id);
        }else{
            this.recordId = event.detail.id;
            await this.moveToNextStep(current, event.detail.id);
        }
        this.isLoading = false;        
    }

    async moveToNextStep(current, recordId) {
        if (current === 5) {
            this.currentStep = 'initial';
            this.recordId = null;
            this.registrationRecordId = null;
            this.hasExistingRecord = false;
            this.showStatusMessage = false;
            this.email = '';
            this.showToast({
                title: 'Success',
                message: 'Registration process completed!',
                variant: 'success'
            });
        } else if (current < 5) {
            this.currentStep = (current + 1).toString();
        }
        this.updateSteps();
    }

    handleFormError(event) {
        console.error('Form error details:', JSON.stringify(event.detail));
        this.showToast({
            title: 'Error',
            message: event.detail?.message || 'Unable to load or save the record. Please verify your input and try again.',
            variant: 'error'
        });
        this.isLoading = false;
    }

    showToast({ title, message, variant }) {
        if (this.currentToast) {
            this.currentToast = null;
        }
        const toastEvent = new ShowToastEvent({
            title,
            message,
            variant
        });
        this.dispatchEvent(toastEvent);
        this.currentToast = toastEvent;
    }

    handleToast(event) {
        const { title, message, variant } = event.detail;
        this.showToast({ title, message, variant });
    }

    updateSteps() {
        this.steps = this.steps.map(step => ({
            ...step,
            currentStep: step.stepNumber === this.currentStep
        }));
        this.nextButtonLabel = this.currentStep === '5' ? 'Submit' : 'Next';
    }
}