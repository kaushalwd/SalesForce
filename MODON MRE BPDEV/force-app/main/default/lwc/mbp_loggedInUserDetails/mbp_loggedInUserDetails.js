/**********************************************************************************************************************
* Name               : MBP_loggedinUserDetails
* Description        : This class is used as the Apex controller for Broker Portal Profile Management.
* Usage              : LWC components for Broker Agent profile updates
* Created By         : Upendra Reddy
* --------------------------------------------------------------------------------------------------------------------
* Version     Author                          Date             Comment
* 1.0         upendra.asam@activemindsit.com         20 Nov 2025      Initial Draft – Handles profile picture upload,
*                                                              profile data update (Mobile, UAE Resident, Nationality),
*                                                              password reset, and nationality picklist fetch.
*
* 1.1         upendra.asam@activemindsit.com         08 Dec 2025      Updated profile update logic:
*                                                              - Mobile, UAE Resident Status, Nationality correctly captured
*                                                              - Improved mobile validation handling (UI-level)
*                                                              - Enhanced field-level & page-level error display
*                                                              - KYC documents marked mandatory (handled in LWC)
**********************************************************************************************************************/



import { LightningElement, track } from 'lwc'; 
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getUserProfileDetails from '@salesforce/apex/MBP_BrokerUserProfilecontroller.getUserProfileDetails';
import uploadUserPicture from '@salesforce/apex/MBP_BrokerUserProfilecontroller.uploadUserPicture';
import resetPassword from '@salesforce/apex/MBP_BrokerUserProfilecontroller.resetPassword';
import validatePhone from '@salesforce/apex/MBP_LoqateIntegration.validatePhone';
import getNationalityPicklistValues from '@salesforce/apex/MBP_BrokerUserProfilecontroller.getNationalityPicklistValues';
import updateContactDetails from '@salesforce/apex/MBP_BrokerUserProfilecontroller.updateContactDetails';
export default class Modonbrokerprofile extends LightningElement {
    @track profilePhoto;
    @track firstName;
    @track lastName;
    @track mobilePhone;
    @track brokerType;
    @track editProfileModal = false;
mobileValidating = false;
mobileValidated = false;
mobileButtonLabel = 'Validate Mobile';
originalPhone = '';
    @track documents = [];
@track Email;
@track username;
@track isLoading=false;
@track country;
@track previewPhoto; 
    @track profileImagePopup = false;
    @track passwordModal = false;
    @track hideBackNav = false;
@track isImageLoading = true;
@track showCustomToast = false;
    profileData = { base64: '' };
  @track editableMobile;
    @track editableNationality;
    @track editableUaeStatus;
    @track nationalityOptions = [];
    @track uaeResidentOptions = [
        { label: 'Resident', value: 'Resident' },
        { label: 'Non-Resident', value: 'Non-Resident' }
    ];
    connectedCallback() {
        this.fetchProfileDetails();
        this.fetchDocuments();
    }


/* Version 1.1  starts*/
  fetchProfileDetails() {
        this.isLoading = true;
        getUserProfileDetails()
            .then(result => {
                const contact = result?.Contact || {};
                this.contactId = contact.Id;
                this.firstName = contact.FirstName;
                this.lastName = contact.LastName;
                this.brokerType = contact.Broker_Type__c;
                this.Email = contact.Email;
                this.username = result?.Username || '';
                this.country = result?.Country || 'N/A';
                this.natinalty = contact.Nationality__c || 'N/A';
                this.residentsatus = contact.UAE_Resident_Status__c || 'N/A';

             // Split phone into country code and number
if (contact.Phone) {
    const phoneParts = contact.Phone.split(/[-\s]/); 
    if (phoneParts.length > 1) {
        this.editableMobileCountryCode = phoneParts[0].replace('+','');
        this.editableMobileNumber = phoneParts.slice(1).join('');
    } else {
        this.editableMobileNumber = contact.Phone;
    }

    this.mobilePhone = `+${this.editableMobileCountryCode} ${this.editableMobileNumber}`;

    // 🔥 AUTO VALIDATE EXISTING NUMBER
    this.originalPhone = this.editableMobileNumber;
    this.mobileValidated = true;
    this.mobileButtonLabel = 'Validated ✅';
}


                this.profilePhoto = result?.FullPhotoUrl
                    ? result.FullPhotoUrl + '?t=' + Date.now()
                    : '/sfsites/c/resource/defaultProfile';

            })
            .catch(error => {
                console.error(error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }
    /* Version 1.1  ends*/
    openEditProfileModal() {
        this.editProfileModal = true;
        this.editableNationality = this.natinalty;
        this.editableUaeStatus = this.residentsatus;

        // Fetch Nationality picklist
        getNationalityPicklistValues()
            .then(result => {
                if (result.success) {
                    this.nationalityOptions = result.values.map(val => ({ label: val, value: val }));
                }
            })
            .catch(error => console.error(error));
    }

    closeEditProfileModal() {
        this.editProfileModal = false;
    }

    handleMobileNumberChange(event) {
        this.editableMobileNumber = event.target.value;
    }

    handleMobileCountryCodeChange(event) {
        this.editableMobileCountryCode = event.detail.value;
    }
/* Version 1.1  starts*/
    handleMobileNumberChange(event) {
    this.editableMobileNumber = event.target.value;

    // Reset validation because number changed
    if (this.mobileValidated && this.editableMobileNumber !== this.originalPhone) {
        this.mobileValidated = false;
        this.mobileButtonLabel = 'Validate Mobile';
    }
}

handleMobileCountryCodeChange(event) {
    this.editableMobileCountryCode = event.detail.value;

    // Reset validation because country code changed
    if (this.mobileValidated) {
        this.mobileValidated = false;
        this.mobileButtonLabel = 'Validate Mobile';
    }
}

    /* Version 1.1  ends*/
    handleUaeStatusChange(event) {
        this.editableUaeStatus = event.detail.value;
    }

    handleNationalityChange(event) {
        this.editableNationality = event.detail.value;
    }

 submitProfileUpdate() {
    if (!this.contactId) return;

    // ❗BLOCK PROFILE UPDATE IF MOBILE IS NOT VALIDATED
    if (!this.mobileValidated) {
        this.template.querySelector('c-mbp_customshowtoast')
            .show('Please validate your mobile number before updating your profile.', 'error');
        return;
    }

    const fullPhone = `+${this.editableMobileCountryCode} ${this.editableMobileNumber}`;

    this.isLoading = true;

    updateContactDetails({
        contactId: this.contactId,
        phone: fullPhone,
        uaeStatus: this.editableUaeStatus,
        nationality: this.editableNationality
    })
    .then(() => {
        this.closeEditProfileModal();
        this.fetchProfileDetails();
        this.template.querySelector('c-mbp_customshowtoast').show('Profile updated successfully', 'success');
    })
    .catch(error => {
        const msg = this.extractErrorMessage(error);
        this.template.querySelector('c-mbp_customshowtoast').show(msg, 'error');
        console.error(error);
    })
    .finally(() => {
        this.isLoading = false;
    });
}


    showProfileImagePopup() {
    this.previewPhoto = this.profilePhoto; // 🔁 Show current image as default preview
    this.profileImagePopup = true;
}

    hideProfileImagePopup() {
        this.profileImagePopup = false;
    }

    openPasswordModal() {
        this.passwordModal = true;
    }

    closePasswordModal() {
        this.passwordModal = false;
    }
handleImageLoad() {
    this.isImageLoading = false;
}
  handlePreview(event) {
    const file = event.target.files[0];
    if (!file) {
        console.warn('handlePreview: No file selected');
        return;
    }

    const reader = new FileReader();
    reader.onload = () => {
        const base64 = reader.result.split(',')[1];
        this.profileData.base64 = base64;
        this.previewPhoto = reader.result; // Update preview in modal only
    };
    reader.readAsDataURL(file);
}



   submitProfileImage() {
    if (!this.profileData.base64) {
        this.template.querySelector('c-mbp_customshowtoast').show('No image selected', 'error');
        return;
    }

    this.isLoading = true; // show custom spinner

    uploadUserPicture({ baseData: this.profileData.base64 })
        .then(data => {
            if (data?.success === 'true') {
                this.template.querySelector('c-mbp_customshowtoast').show(data.msg, 'success');
                this.hideProfileImagePopup();
                this.profileData.base64 = '';
                this.fetchProfileDetails();
            } else {
                this.template.querySelector('c-mbp_customshowtoast').show(data?.msg || 'Upload failed.', 'error');
            }
        })
        .catch(error => {
            const msg = this.extractErrorMessage(error);
            this.template.querySelector('c-mbp_customshowtoast').show(msg, 'error');
        })
        .finally(() => {
            this.isLoading = false; // hide spinner
        });
}

/* Version 1.1  starts*/
handleMobileValidation() {
    const countryCode = this.editableMobileCountryCode ? 
        (this.editableMobileCountryCode.startsWith('+') ? this.editableMobileCountryCode : '+' + this.editableMobileCountryCode) 
        : '';
    const phone = this.editableMobileNumber || '';
    const fullMobile = countryCode + phone;

    // If already validated and number didn't change, skip validation
    if (this.mobileValidated && phone === this.originalPhone) {
        this.template.querySelector('c-mbp_customshowtoast').show(
            'Mobile number already validated.',
            'success'
        );
        return;
    }

    if (!countryCode || !phone) {
        this.template.querySelector('c-mbp_customshowtoast').show(
            'Please enter country code and mobile number.',
            'error'
        );
        return;
    }

    this.mobileValidating = true;
    this.mobileButtonLabel = 'Validating...';

    validatePhone({ phone: fullMobile })
        .then(result => {
            if (result === true) {
                this.mobileValidated = true;
                this.originalPhone = phone; // store validated number
                this.mobileButtonLabel = 'Validated ✅';
                this.template.querySelector('c-mbp_customshowtoast').show(
                    'Mobile number is valid.',
                    'success'
                );
            } else {
                this.mobileValidated = false;
                this.mobileButtonLabel = 'Validate Mobile';
                this.template.querySelector('c-mbp_customshowtoast').show(
                    'Entered number is not valid.',
                    'error'
                );
            }
        })
        .catch(error => {
            console.error('Validation Error:', error);
            this.mobileValidated = false;
            this.mobileButtonLabel = 'Validate Mobile';
            this.template.querySelector('c-mbp_customshowtoast').show(
                this.getErrorMessage(error),
                'error'
            );
        })
        .finally(() => {
            this.mobileValidating = false;
        });
}
    /* Version 1.1  ends*/

submitPasswordReset() {
    const oldPassword = this.template.querySelector('[data-id="oldPassword"]').value;
    const newPassword = this.template.querySelector('[data-id="newPassword"]').value;
    const confirmPassword = this.template.querySelector('[data-id="confirmPassword"]').value;

    this.isLoading = true; // show custom spinner

    resetPassword({ newPassword, verifyNewPassword: confirmPassword, oldPassword })
        .then(() => {
            this.template.querySelector('c-mbp_customshowtoast').show('Password updated successfully', 'success');
            this.closePasswordModal();
        })
        .catch(error => {
            const msg = this.extractErrorMessage(error);
            this.template.querySelector('c-mbp_customshowtoast').show(msg, 'error');
        })
        .finally(() => {
            this.isLoading = false; // hide spinner
        });
}


    backToDashboard() {
        this.dispatchEvent(new CustomEvent('back'));
    }

    logout() {
        window.location.href = '../secur/logout.jsp';
    }
    /* Version 1.1  starts*/
mobCountryOptions=
         [{
                label: '1',
                value: '1'
            },
            {
                label: '20',
                value: '20'
            },
            {
                label: '27',
                value: '27'
            },
            {
                label: '30',
                value: '30'
            },
            {
                label: '31',
                value: '31'
            },
            {
                label: '32',
                value: '32'
            },
            {
                label: '33',
                value: '33'
            },
            {
                label: '34',
                value: '34'
            },
            {
                label: '36',
                value: '36'
            },
            {
                label: '39',
                value: '39'
            },
            {
                label: '40',
                value: '40'
            },
            {
                label: '41',
                value: '41'
            },
            {
                label: '43',
                value: '43'
            },
            {
                label: '44',
                value: '44'
            },
            {
                label: '45',
                value: '45'
            },
            {
                label: '46',
                value: '46'
            },
            {
                label: '47',
                value: '47'
            },
            {
                label: '48',
                value: '48'
            },
            {
                label: '49',
                value: '49'
            },
            {
                label: '51',
                value: '51'
            },
            {
                label: '52',
                value: '52'
            },
            {
                label: '53',
                value: '53'
            },
            {
                label: '54',
                value: '54'
            },
            {
                label: '55',
                value: '55'
            },
            {
                label: '56',
                value: '56'
            },
            {
                label: '57',
                value: '57'
            },
            {
                label: '58',
                value: '58'
            },
            {
                label: '60',
                value: '60'
            },
            {
                label: '61',
                value: '61'
            },
            {
                label: '62',
                value: '62'
            },
            {
                label: '63',
                value: '63'
            },
            {
                label: '64',
                value: '64'
            },
            {
                label: '65',
                value: '65'
            },
            {
                label: '66',
                value: '66'
            },
            {
                label: '81',
                value: '81'
            },
            {
                label: '82',
                value: '82'
            },
            {
                label: '84',
                value: '84'
            },
            {
                label: '86',
                value: '86'
            },
            {
                label: '90',
                value: '90'
            },
            {
                label: '91',
                value: '91'
            },
            {
                label: '92',
                value: '92'
            },
            {
                label: '93',
                value: '93'
            },
            {
                label: '94',
                value: '94'
            },
            {
                label: '95',
                value: '95'
            },
            {
                label: '98',
                value: '98'
            },
            {
                label: '211',
                value: '211'
            },
            {
                label: '212',
                value: '212'
            },
            {
                label: '213',
                value: '213'
            },
            {
                label: '216',
                value: '216'
            },
            {
                label: '218',
                value: '218'
            },
            {
                label: '220',
                value: '220'
            },
            {
                label: '221',
                value: '221'
            },
            {
                label: '222',
                value: '222'
            },
            {
                label: '223',
                value: '223'
            },
            {
                label: '224',
                value: '224'
            },
            {
                label: '225',
                value: '225'
            },
            {
                label: '226',
                value: '226'
            },
            {
                label: '227',
                value: '227'
            },
            {
                label: '228',
                value: '228'
            },
            {
                label: '229',
                value: '229'
            },
            {
                label: '230',
                value: '230'
            },
            {
                label: '231',
                value: '231'
            },
            {
                label: '232',
                value: '232'
            },
            {
                label: '233',
                value: '233'
            },
            {
                label: '234',
                value: '234'
            },
            {
                label: '235',
                value: '235'
            },
            {
                label: '236',
                value: '236'
            },
            {
                label: '237',
                value: '237'
            },
            {
                label: '238',
                value: '238'
            },
            {
                label: '239',
                value: '239'
            },
            {
                label: '240',
                value: '240'
            },
            {
                label: '241',
                value: '241'
            },
            {
                label: '242',
                value: '242'
            },
            {
                label: '243',
                value: '243'
            },
            {
                label: '244',
                value: '244'
            },
            {
                label: '245',
                value: '245'
            },
            {
                label: '246',
                value: '246'
            },
            {
                label: '248',
                value: '248'
            },
            {
                label: '249',
                value: '249'
            },
            {
                label: '250',
                value: '250'
            },
            {
                label: '251',
                value: '251'
            },
            {
                label: '252',
                value: '252'
            },
            {
                label: '253',
                value: '253'
            },
            {
                label: '254',
                value: '254'
            },
            {
                label: '255',
                value: '255'
            },
            {
                label: '256',
                value: '256'
            },
            {
                label: '257',
                value: '257'
            },
            {
                label: '258',
                value: '258'
            },
            {
                label: '260',
                value: '260'
            },
            {
                label: '261',
                value: '261'
            },
            {
                label: '262',
                value: '262'
            },
            {
                label: '263',
                value: '263'
            },
            {
                label: '264',
                value: '264'
            },
            {
                label: '265',
                value: '265'
            },
            {
                label: '266',
                value: '266'
            },
            {
                label: '267',
                value: '267'
            },
            {
                label: '268',
                value: '268'
            },
            {
                label: '269',
                value: '269'
            },
            {
                label: '290',
                value: '290'
            },
            {
                label: '291',
                value: '291'
            },
            {
                label: '297',
                value: '297'
            },
            {
                label: '298',
                value: '298'
            },
            {
                label: '299',
                value: '299'
            },
            {
                label: '350',
                value: '350'
            },
            {
                label: '351',
                value: '351'
            },
            {
                label: '352',
                value: '352'
            },
            {
                label: '353',
                value: '353'
            },
            {
                label: '354',
                value: '354'
            },
            {
                label: '355',
                value: '355'
            },
            {
                label: '356',
                value: '356'
            },
            {
                label: '357',
                value: '357'
            },
            {
                label: '358',
                value: '358'
            },
            {
                label: '359',
                value: '359'
            },
            {
                label: '370',
                value: '370'
            },
            {
                label: '371',
                value: '371'
            },
            {
                label: '372',
                value: '372'
            },
            {
                label: '373',
                value: '373'
            },
            {
                label: '374',
                value: '374'
            },
            {
                label: '375',
                value: '375'
            },
            {
                label: '376',
                value: '376'
            },
            {
                label: '377',
                value: '377'
            },
            {
                label: '378',
                value: '378'
            },
            {
                label: '380',
                value: '380'
            },
            {
                label: '381',
                value: '381'
            },
            {
                label: '382',
                value: '382'
            },
            {
                label: '385',
                value: '385'
            },
            {
                label: '386',
                value: '386'
            },
            {
                label: '387',
                value: '387'
            },
            {
                label: '389',
                value: '389'
            },
            {
                label: '420',
                value: '420'
            },
            {
                label: '421',
                value: '421'
            },
            {
                label: '423',
                value: '423'
            },
            {
                label: '500',
                value: '500'
            },
            {
                label: '501',
                value: '501'
            },
            {
                label: '502',
                value: '502'
            },
            {
                label: '503',
                value: '503'
            },
            {
                label: '504',
                value: '504'
            },
            {
                label: '505',
                value: '505'
            },
            {
                label: '506',
                value: '506'
            },
            {
                label: '507',
                value: '507'
            },
            {
                label: '508',
                value: '508'
            },
            {
                label: '509',
                value: '509'
            },
            {
                label: '590',
                value: '590'
            },
            {
                label: '591',
                value: '591'
            },
            {
                label: '592',
                value: '592'
            },
            {
                label: '593',
                value: '593'
            },
            {
                label: '594',
                value: '594'
            },
            {
                label: '595',
                value: '595'
            },
            {
                label: '596',
                value: '596'
            },
            {
                label: '597',
                value: '597'
            },
            {
                label: '598',
                value: '598'
            },
            {
                label: '599',
                value: '599'
            },
            {
                label: '670',
                value: '670'
            },
            {
                label: '672',
                value: '672'
            },
            {
                label: '673',
                value: '673'
            },
            {
                label: '674',
                value: '674'
            },
            {
                label: '675',
                value: '675'
            },
            {
                label: '676',
                value: '676'
            },
            {
                label: '677',
                value: '677'
            },
            {
                label: '678',
                value: '678'
            },
            {
                label: '679',
                value: '679'
            },
            {
                label: '680',
                value: '680'
            },
            {
                label: '681',
                value: '681'
            },
            {
                label: '682',
                value: '682'
            },
            {
                label: '683',
                value: '683'
            },
            {
                label: '685',
                value: '685'
            },
            {
                label: '686',
                value: '686'
            },
            {
                label: '687',
                value: '687'
            },
            {
                label: '688',
                value: '688'
            },
            {
                label: '689',
                value: '689'
            },
            {
                label: '690',
                value: '690'
            },
            {
                label: '691',
                value: '691'
            },
            {
                label: '692',
                value: '692'
            },
            {
                label: '850',
                value: '850'
            },
            {
                label: '852',
                value: '852'
            },
            {
                label: '853',
                value: '853'
            },
            {
                label: '855',
                value: '855'
            },
            {
                label: '856',
                value: '856'
            },
            {
                label: '870',
                value: '870'
            },
            {
                label: '880',
                value: '880'
            },
            {
                label: '881',
                value: '881'
            },
            {
                label: '882',
                value: '882'
            },
            {
                label: '883',
                value: '883'
            },
            {
                label: '886',
                value: '886'
            },
            {
                label: '960',
                value: '960'
            },
            {
                label: '961',
                value: '961'
            },
            {
                label: '962',
                value: '962'
            },
            {
                label: '963',
                value: '963'
            },
            {
                label: '964',
                value: '964'
            },
            {
                label: '965',
                value: '965'
            },
            {
                label: '966',
                value: '966'
            },
            {
                label: '967',
                value: '967'
            },
            {
                label: '968',
                value: '968'
            },
            {
                label: '970',
                value: '970'
            },
            {
                label: '971',
                value: '971'
            },
            {
                label: '972',
                value: '972'
            },
            {
                label: '973',
                value: '973'
            },
            {
                label: '974',
                value: '974'
            },
            {
                label: '975',
                value: '975'
            },
            {
                label: '976',
                value: '976'
            },
            {
                label: '977',
                value: '977'
            },
            {
                label: '992',
                value: '992'
            },
            {
                label: '993',
                value: '993'
            },
            {
                label: '994',
                value: '994'
            },
            {
                label: '995',
                value: '995'
            },
            {
                label: '996',
                value: '996'
            },
            {
                label: '998',
                value: '998'
            }
        ];

            /* Version 1.1  ends*/

    get acceptedPhotoFormats() {
        return ['.jpg', '.jpeg', '.png'];
    }

 showCenteredToast(title, message, variant) {
        this.customToastTitle = title;
        this.customToastMessage = message;
        this.customToastVariant = variant;
        this.showCustomToast = true;

        setTimeout(() => {
            this.showCustomToast = false;
        }, 5000);
    }

    extractErrorMessage(error) {
        if (error?.body?.message) return error.body.message;
        if (error?.message) return error.message;
        if (typeof error === 'string') return error;
        return 'An unexpected error occurred';
    }
}