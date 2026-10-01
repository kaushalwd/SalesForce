import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
//import BACKGROUND from '@salesforce/resourceUrl/ModonBackground';
import LOGO from '@salesforce/resourceUrl/modonLogoPlain';
import createUserLead from '@salesforce/apex/CommunityLoginController.createUserLeadMethod';

import doLogin from '@salesforce/apex/CommunityLoginController.login';
import logowhite from '@salesforce/resourceUrl/logowhite';
import instagram from '@salesforce/resourceUrl/instagram'
import youtubeicon from '@salesforce/resourceUrl/youtubeicon';
import linkedinicon from '@salesforce/resourceUrl/linkedinicon';
import facebook from '@salesforce/resourceUrl/facebook';
import twitterx from '@salesforce/resourceUrl/Twitterx';

export default class CommunityLogin extends NavigationMixin(LightningElement) {
    //backgroundUrl = BACKGROUND;
    firstName;
    lastName;
    mobile;
    email;
    logoUrl = LOGO;
    @track errorCheck;
    @track errorMessage;
    logowhiteUrl = logowhite;
    instagramUrl = instagram;
    youtubeiconUrl = youtubeicon;
    linkediniconUrl = linkedinicon;
    facebookUrl = facebook;
    twitterxUrl = twitterx;
    handleChange(event) {
        const field = event.target.label.toLowerCase();
        if (field === 'email') {
            this.username = event.target.value;
        } else if (field === 'password') {
            this.password = event.target.value;
        }
    }
    handleSignUp(){
        this.isLoading = true;
        this.errorCheck = false;
        this.errorMessage = '';
        const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        if (!emailPattern.test(this.email)) {
            this.isLoading = false;
            this.errorCheck = true;
            this.errorMessage = 'Please enter a valid email address.';
            return;
        }
        createUserLead({firstName: this.firstName, lastName: this.lastName, mobile: this.mobile, email: this.email})
        .then(result => {
            try {
                if (!result.includes('Error')) {
                    this.handleToast('Portal User Creation request submitted!', 'success');
                  // Simulate async operation like Apex call
                    setTimeout(() => {
                        this.isLoading = false;
                        this.handleSignIn();
                    }, 3000);
                    window.location.href = 'https://interactive.modon.com/?state=earth&lang=en&tower=top&theme=light&floor=GF';
                   
                } else {
                    this.isLoading = false;
                    if(result.includes('INVALID_EMAIL_ADDRESS')){
                        this.errorMessage = 'Error! Please enter a valid email address.';
                    }if(result.includes('FIELD_CUSTOM_VALIDATION_EXCEPTION')){
                        this.errorMessage = result;
                    }else{
                        this.errorMessage = 'Error! Please reach your admin.';
                    }
                    this.errorCheck = true;
                  
                    this.handleToast(JSON.stringify(result), 'error');
                }
            } catch (innerError) {
                this.isLoading = false;
                console.error('Error inside then block:', innerError);
                this.handleToast('Please reach your admin!', 'error');
            }
        })
        .catch(error => {
            this.errorCheck = true;
            this.errorMessage = error.body.message;
            this.handleToast('Please reach your admin!', 'error');
            this.isLoading = false;
        });
    
    }
    handleChange(event){
        const field = event.target.label.toLowerCase();
        if (field === 'first name') {
            this.firstName = event.target.value;
        } else if (field === 'last name') {
            this.lastName = event.target.value;
        } else if (field === 'mobile') {
            this.mobile = event.target.value;
        } else if (field === 'email') {
            this.email = event.target.value;
        }
    }
    handleSignIn(){
        // Fire a custom event and pass data
        this.dispatchEvent(new CustomEvent('signup', {
            detail: false // you can pass any value in detail
        }));
    }
    handleToast(message,variant) {
        this.template.querySelector('c-custom-toast').show(message, variant);

    }
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
        const url = 'https://modonproperties--cpdev.sandbox.my.site.com/MCustomerPortal/';
        window.open(url,'_blank');
    }
    handlelinkedin(){
        const url = 'https://www.linkedin.com/company/modon/';
        window.open(url,'_blank');
    }
    handleMyProperties(){
        window.location.href='https://modonproperties--cpdev.sandbox.my.site.com/MCustomerPortal/my-properties';
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
   
}