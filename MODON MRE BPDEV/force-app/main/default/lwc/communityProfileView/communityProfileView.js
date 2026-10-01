import {
    LightningElement,
    wire,
    track,
    api
} from 'lwc';
import FORM_FACTOR from '@salesforce/client/formFactor';
import getCurrentUserInfo from '@salesforce/apex/CommunityCustomerProfile.getCurrentUserInfo';
import resetPassword from '@salesforce/apex/CommunityCustomerProfile.generateResetPassword';
import udpateUserData from '@salesforce/apex/CommunityCustomerProfile.udpateUserData';
import uploadUserAvatar from '@salesforce/apex/CommunityCustomerProfile.uploadUserAvatar';//
import getCurrentUserPhotoUrl from '@salesforce/apex/CommunityCustomerProfile.getCurrentUserPhotoUrl';
import PROFILEURL from '@salesforce/label/c.CP_ProfileUrl';
import caseCreateforUser from '@salesforce/apex/CommunityLoginController.handleCaseCreation';
import homeIcon from '@salesforce/resourceUrl/homeblack';
import priceIcon from '@salesforce/resourceUrl/priceblack';
import paymentIcon from '@salesforce/resourceUrl/planblack';
import buildingicon from '@salesforce/resourceUrl/buildingicon';
import bedIcon from '@salesforce/resourceUrl/bed';
import bathIcon from '@salesforce/resourceUrl/washroom';
import sizeIcon from '@salesforce/resourceUrl/building';
import areaIcon from '@salesforce/resourceUrl/area'
import carIcon from '@salesforce/resourceUrl/Car';
import balcony from '@salesforce/resourceUrl/balcony';
import outdoor from '@salesforce/resourceUrl/outdoor';
import school from '@salesforce/resourceUrl/school';
import basketball from '@salesforce/resourceUrl/basketball';
import bike from '@salesforce/resourceUrl/bike';
import walk from '@salesforce/resourceUrl/walk';
import swim from '@salesforce/resourceUrl/swim';
import gym from '@salesforce/resourceUrl/gym';
import community from '@salesforce/resourceUrl/community';
import getImageUrls from '@salesforce/apex/CommunityHomeController.getImageUrls';
import modonLogo from '@salesforce/resourceUrl/modonLogoPlain';
import note from '@salesforce/resourceUrl/note';
import question from '@salesforce/resourceUrl/question';
import logowhite from '@salesforce/resourceUrl/logowhite';
import building from '@salesforce/resourceUrl/building';
import { getRecord } from 'lightning/uiRecordApi';
import USER_ID from '@salesforce/user/Id';
import basePath from "@salesforce/community/basePath";
import instagram from '@salesforce/resourceUrl/instagram'
import youtubeicon from '@salesforce/resourceUrl/youtubeicon';
import linkedinicon from '@salesforce/resourceUrl/linkedinicon';
import facebook from '@salesforce/resourceUrl/facebook';
import twitterx from '@salesforce/resourceUrl/Twitterx';
import { NavigationMixin } from 'lightning/navigation';
import PROFILE_MESSAGE from '@salesforce/label/c.ProfileUpdateProgressMessage';


import downloadIcon from '@salesforce/resourceUrl/building';
import manageIcon from '@salesforce/resourceUrl/building';

import FORGOTPASSWORD from '@salesforce/label/c.Cp_ForgotPassword';

import HOMEPAGE from '@salesforce/label/c.Customer_Portal_URL';
import PROPURL from '@salesforce/label/c.CP_MyPropertiesUrl';
import LOGOUTURL from '@salesforce/label/c.CP_LogoutUrl';

import {
    ShowToastEvent
} from 'lightning/platformShowToastEvent';

export default class CommunityProfileView extends NavigationMixin(LightningElement) {
    profileMessage = PROFILE_MESSAGE;
    caseMessage = '';
    caseCreationDone = false;
    @track profileUpdateInprogress = false;
    @track isPasswordReset = false;
    @track menuOpen = false;
    @track userName;
    @track firstName;
    @track lastName;
    @track emiratesId;
    @track title;
    @track companyName;
    @track phone;
    @track address;
    @track email;
    @track mobile;
    @track ManagerName;
    @track street;
    @track city;
    @track state;
    @track country;
    @track zipCode;
    @track editProfile = false;
    @track addresshtmlContent;
    @track avatarUrl;
    @track isCaseCreationOpen = false;
    @track isLoading = false;
    @track newPassword;
    @track confirmPassword;
    file;
    fileInput;
    logoUrl = modonLogo;
    logowhiteUrl = logowhite;
    noteUrl = note;
    questionUrl = question;
    buildingUrl = building;
    userName ;
    properties;
 disableFields = true; // Add this

    @track property=[]; 
    @api recordId;
    balcony =balcony;
    bedIcon = bedIcon;
    bathIcon = bathIcon;
    sizeIcon = sizeIcon;
    carIcon = carIcon;
    homeIcon = homeIcon;
    priceIcon = priceIcon;
    paymentIcon = paymentIcon;
    downloadIcon = downloadIcon;
    areaIcon=areaIcon;
    manageIcon = manageIcon;
    //backgroundStyle = `background-image: url(${communityBg});`;
    logoUrl = modonLogo;
    logowhiteUrl = logowhite;
    noteUrl = note;
    questionUrl = question;
    buildingUrl = building;
    heroSectionStyle = "background-image: url('images/prop2.png');";
    homeIcon = homeIcon;
    priceIcon = priceIcon;
    paymentIcon = paymentIcon;    
    backgroundImageStyle = `background-image: url(${buildingicon}); background-size: cover; background-position: center; background-repeat: no-repeat;`;
    villaIconUrl = homeIcon;
    priceIconUrl =priceIcon;
    paymentPlanIconUrl = paymentIcon;
    bedImageUrl = bedIcon;
    areaImageUrl = areaIcon;
    bathImageUrl = bathIcon;
    sizeIconUrl = sizeIcon;
    carImageUrl = carIcon;
    balconyImageUrl = balcony;
    outdoor = outdoor;
    school = school;
    basketball = basketball;
    bike = bike;
    walk = walk;
    swim = swim;
    gym = gym;
    logowhiteUrl = logowhite;
    instagramUrl = instagram;
    youtubeiconUrl = youtubeicon;
    linkediniconUrl = linkedinicon;
    facebookUrl = facebook;
    twitterxUrl = twitterx;
    community = community;
    isDesktop = false;
    isTablet = false;
    isMobile = false;
   
connectedCallback() {
    if (FORM_FACTOR === 'Large' ) {
        this.isDesktop = true;
    } else if (FORM_FACTOR === 'Small'  || FORM_FACTOR === 'Medium') {
        this.isMobile = true;
    }
}
get editProfileDisabled(){
    return this.editProfile || this.profileUpdateInprogress;
}
get resetPasswordDisabled(){
    return this.editProfile || this.isCaseCreationOpen || this.isPasswordReset;
}
get detailPageVisibility(){
    return !this.isPasswordReset && !this.isCaseCreationOpen;
}

    @wire(getCurrentUserInfo)
    wiredUser({
        error,
        data
    }) {
        if (data) {
            this.loadImage();
            
            this.userName = data.userObj.Name;
            this.firstName = data.userObj.FirstName;
            this.lastName = data.userObj.LastName;
            this.emiratesId = data.userObj.EmiratesIDNumber__c;
            this.title = data.userObj.Title;
            this.companyName = data.userObj.CompanyName;
            this.phone = data.userObj.Phone;
            this.mobile = data.userObj.MobilePhone;
            // this.address = data.Address;
            this.email = data.userObj.Email;
            this.street = data.userObj.Street;
            this.state = data.userObj.State;
            this.country = data.userObj.Country;
            this.city = data.userObj.City;
            this.zipCode = data.userObj.PostalCode;
            this.profileUpdateInprogress = data.isUserUpdateInProgress;
            if(this.profileUpdateInprogress){
                this.disableFields = true;
            }
            //this.avatarUrl = data.PhotoImageURL__c;
            this.addresshtmlContent = '';
if (this.street) {
    this.addresshtmlContent += `${this.street},<br/>`;
}
if (this.city) {
    this.addresshtmlContent += `${this.city}, `;
}
if (this.state) {
    this.addresshtmlContent += `${this.state}<br/>`;
}
if (this.country) {
    this.addresshtmlContent += `${this.country} `;
}
if (this.zipCode) {
    this.addresshtmlContent += `${this.zipCode}`;
}

        } else if (error) {
            console.error('Error fetching user details:', error);
        }
    }
    handleEditProfile(event) {
        this.caseCreationDone = false;
        this.caseMessage = '';
        this.editProfile = true;
        this.isPasswordReset = false;
        this.disableFields = false; // Enable input fields
    }
    handleCancel(event) {
        this.editProfile = false;
        this.disableFields = true; // Disable input fields back
    }
    handleSaveChanges(event) {
        this.isLoading = true;
        const inputs = this.template.querySelectorAll('lightning-input');
        let isValid = true;
    
        inputs.forEach(input => {
            if (!input.checkValidity()) {
                input.reportValidity();
                isValid = false;
            }
        });
    
        if (isValid) {
            // Save your logic like udpateUserData() here
            this.handSaveProfile();

            this.disableFields = true;
            this.editProfile = false;
        } else {
            this.isLoading = false;
        }
    }
    handSaveProfile(event) {
      
        this.handleToast();
        const inputs = this.template.querySelectorAll('lightning-input');
        let isValid = true;

        inputs.forEach(input => {
            if (!input.checkValidity()) {
                input.reportValidity();
                isValid = false;
            }
        });

        if (isValid) {
            udpateUserData({
                    firstName: this.firstName,
                    lastName: this.lastName,
                    title: this.title,
                    companyName: this.companyName,
                    phone: this.phone,
                    street: this.street,
                    state: this.state,
                    city: this.city,
                    postalCode:this.zipCode,
                    country: this.country,
                    email:this.email
                })
                .then(result => {
                    if (!result.includes('Error')) {
                        this.profileUpdateInprogress = true;
                        this.profileMessage = result;
                        this.handleToast(result,'success');
                        window.location.reload();

                    } else {
                        this.handleToast(result,'error');
                    }
                    this.disableFields = true;
                    this.isLoading = false;
                })
                .catch(error => {
                    this.isLoading = false;
                })
        } else {
            this.isLoading = false;
        }
    }
    handleResetPassword(event) {
        this.caseCreationDone = false;
        this.caseMessage = '';
        this.isPasswordReset = true;
       /* resetPassword().then(result => {
            if (!result.includes('Error')) {
                this.handleToast(result,'success');
            } else {
                this.handleToast(result,'error');
            }
        }).catch(error => {
        })*/
    }
    handleFormInputChange(event) {
        if (event.target.name === 'firstName') {
            this.firstName = event.target.value;
        } else if (event.target.name === 'lastName') {
            this.lastName = event.target.value;
        } else if (event.target.name === 'title') {
            this.title = event.target.value;
        } else if (event.target.name === 'companyName') {
            this.companyName = event.target.value;
        } else if (event.target.name === 'mobile') {
            this.mobile = event.target.value;
        } else if (event.target.name === 'phone') {
            this.phone = event.target.value;
        }else if (event.target.name === 'street') {
            this.street = event.target.value;
        }
        else if (event.target.name === 'state') {
            this.state = event.target.value;
        }
        else if (event.target.name === 'city') {
            this.city = event.target.value;
        }
        else if (event.target.name === 'zipCode') {
            this.zipCode = event.target.value;
        }
        else if (event.target.name === 'country') {
            this.country = event.target.value;
        } else if (event.target.name === 'subject') {
            this.subject = event.target.value;
        } else if (event.target.name === 'caseDescription') {
            this.caseDescription = event.target.value;
        }else if (event.target.name === 'newPassword') {
            this.newPassword = event.target.value;
        }else if (event.target.name === 'confirmPassword') {
            this.confirmPassword = event.target.value;
        }
    }
    handleToast(message,variant) {
        this.template.querySelector('c-custom-toast').show(message, variant);

    }
    triggerFileUpload() {
        this.fileInput = this.template.querySelector('input[type="file"]');
        this.fileInput.click();
    }

    handleFileChange(event) {
        const file = event.target.files[0];
    
        if (file) {
            const reader = new FileReader();
    
            reader.onloadend = () => {
                const base64Result = reader.result.split(',')[1]; //
                this.avatarUrl = reader.result; // 
                this.uploadToServer(base64Result, file.name);
            };
    
            reader.readAsDataURL(file);
        }
    }
    loadImage(){
        getCurrentUserPhotoUrl()
            .then(result => {
                if(result){
                this.avatarUrl = `data:image/jpeg;base64,${result}`;
                }
            })
            .catch(error => {
            });
    }
    uploadToServer(base64Data, fileName) {
        uploadUserAvatar({ base64Data, fileName })
            .then(result => {
              this.avatarUrl = `data:image/jpeg;base64,${result}`;
              this.handleToast('New Avatar Updated!','success');
            })
            .catch(error => {
                console.error(JSON.stringify(error));
                this.handleToast('Avatar Upload failed!','error');
            });
    }
    handleLogout(event) {
        const sitePrefix = basePath.replace("/", "");
        window.location.href = LOGOUTURL;//'https://modonproperties--cpdev.sandbox.my.site.com/MCustomerPortal/secur/logout.jsp';

    }
    handleMenuSelect(event) {
        const selectedValue =  event.target.dataset.id;// Correct way to access the selected item value

        if (selectedValue === 'logout') {
            const sitePrefix = basePath.replace("/", "");
            window.location.href = LOGOUTURL;//'https://modonproperties--cpdev.sandbox.my.site.com/MCustomerPortal/secur/logout.jsp';
        } else if (selectedValue === 'home') {
            window.location.href = HOMEPAGE;//'https://modonproperties--cpdev.sandbox.my.site.com/MCustomerPortal/'; // Navigate to profile settings
        } else {
            console.warn('Unknown option selected:', selectedValue);
        }
    }
    logowhiteUrl = logowhite;
    userName ;
    contactid;
   
    handleModon(){
        const url = 'https://www.modon.com/';
        window.open(url,'_blank');
    }
    handleContactUs(){
        const url = 'https://www.modon.com/contact-us';
        window.open(url,'_blank');
    }
    logowhiteUrl = logowhite;
    instagramUrl = instagram;
    youtubeiconUrl = youtubeicon;
    linkediniconUrl = linkedinicon;
    facebookUrl = facebook;
    twitterxUrl = twitterx;


    handleContactUs(){
        const url = 'https://www.modon.com/contact-us';
        window.open(url,'_blank');
    }
    handleModon(){
        const url = 'https://www.modon.com/';
        window.open(url,'_blank');
    }
    handleinstagram(){
        const url = 'https://www.instagram.com/modonproperties/#';
        window.open(url,'_blank');
    }
    homepage(){
        const url = HOMEPAGE;//'https://modonproperties--cpdev.sandbox.my.site.com/MCustomerPortal/';
        window.open(url,'_blank');
    }
    handlelinkedin(){
        const url = 'https://www.linkedin.com/company/modon/';
        window.open(url,'_blank');
    }
    handleMyProperties(){
        window.location.href= PROPURL;//'https://modonproperties--cpdev.sandbox.my.site.com/MCustomerPortal/my-properties';
    }
    handleyoutube(){
        const url = 'https://www.youtube.com/channel/UCkF7MWvWZsty6udHa-ykATQ';
        window.open(url,'_blank');
    }
    handlefacebook(){
        const url = 'https://www.facebook.com/modonproperties';
        window.open(url,'_blank');
    }
    handletwitterx(){
        const url = 'https://x.com/ModonProperties';
        window.open(url,'_blank');
    }
    toggleMenu() {
        this.menuOpen = !this.menuOpen;
    } 
    handleCreateCase(){
        this.isPasswordReset = false;
        this.caseCreationDone = false;
        this.caseMessage = '';
        this.disableFields = true;
        this.isCaseCreationOpen = true;
    }
    caseCreationHandler(event){
        this.caseCreationDone = false;
        this.caseMessage = '';
        this.isLoading = true
        if(this.caseDescription == '' || this.caseDescription == undefined){
            this.handleToast('Please enter case description!','error');
            this.isLoading = false;
            return;

        }
        if(this.subject == '' || this.subject == undefined){
            this.handleToast('Please enter case subject!','error');
            this.isLoading = false;
            return;

        }
        caseCreateforUser({     
            Subject: this.subject,
            issueDesc: this.caseDescription,
            email: this.email,
            mobile: this.phone,
            isGeneralCase: true    })
    .then(result => {
        if (!result.includes('Error')) {
            this.handleToast(result,'success');
            this.isCaseCreationOpen = false;
            this.caseCreationDone = true;
            this.caseMessage = result;
        } else {
            this.handleToast('Error creating case!','error');
        }
        this.isLoading = false;
    }
    )
    .catch(error => {
        this.isLoading = false;
        console.error('Error creating case:', error);
        this.handleToast('Error creating case!','error');
    });   
}

handleCancelCaseCreation(){
    this.isCaseCreationOpen = false;
    this.disableFields = true;
}        
    callPasswordRestHandler(){
        this.isLoading = true;
        if(this.newPassword == '' || this.newPassword == undefined){
            this.handleToast('Please enter new password!','error');
            this.isLoading = false;
            return;
         }
         if(this.confirmPassword == '' || this.confirmPassword == undefined){
            this.handleToast('Please enter confirm password!','error');
            this.isLoading = false;
            return;
         }
         if(this.confirmPassword !== this.newPassword){
            this.handleToast('New Password and Confirm Password are not matching!','error');
            this.isLoading = false;
            return;
         }
         resetPassword({password:this.newPassword}).then(result => {
            if (!result.includes('Error')) {
                this.handleToast(result,'success');
                this.handleToast('Your password has been successfully reset.', 'success');
                // Simulate async operation like Apex call
                  setTimeout(() => {
                      this.isLoading = false;
                      this.isPasswordReset = false;
                      const sitePrefix = basePath.replace("/", "");
                      window.location.href = LOGOUTURL;//'https://modonproperties--cpdev.sandbox.my.site.com/MCustomerPortal/secur/logout.jsp';
                  }, 3000);
            } else {
                this.isLoading = false;
                if(result.includes('invalid repeated password')){
                    this.handleToast('Please choose a password different from your previous three.','error');
                }else {
                    this.handleToast(result,'error');
                }
                this.handleToast(result,'error');
                this.errorCheck = true;
                this.errorMessage = result;
            }
        }).catch(error => {
            this.isLoading = false;
            this.errorCheck = true;
            this.errorMessage = error.body.message;
        })
    } 
    handleCancelPasswordReset(){
        this.isPasswordReset = false;
    }     
}