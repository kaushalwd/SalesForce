import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
//import BACKGROUND from '@salesforce/resourceUrl/ModonBackground';
import LOGO from '@salesforce/resourceUrl/modonLogoPlain';
import doLogin from '@salesforce/apex/CommunityLoginController.login';
import logowhite from '@salesforce/resourceUrl/logowhite';
import instagram from '@salesforce/resourceUrl/instagram'
import youtubeicon from '@salesforce/resourceUrl/youtubeicon';
import linkedinicon from '@salesforce/resourceUrl/linkedinicon';
import facebook from '@salesforce/resourceUrl/facebook';
import twitterx from '@salesforce/resourceUrl/Twitterx';
import FORGOTPASSWORD from '@salesforce/label/c.Cp_ForgotPassword';

import HOMEPAGE from '@salesforce/label/c.Customer_Portal_URL';
import PROPURL from '@salesforce/label/c.CP_MyPropertiesUrl';
import LOGOUTURL from '@salesforce/label/c.CP_LogoutUrl';


export default class CommunityLogin extends NavigationMixin(LightningElement) {
    //backgroundUrl = BACKGROUND;
    logoUrl = LOGO;
    email = '';
    password = '';
    username = '';
    @track errorCheck;
    @track errorMessage;
    @track signup = false;
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

    handleLogin(event) {
        if (!this.username && !this.password) {
            this.errorCheck = true;
            this.errorMessage = 'Please enter both Email and Password.';            
            return;
        }else if(!this.password) {
            this.errorCheck = true;
            this.errorMessage = 'Please Enter your Password.';
            return;
        }else if(!this.username){
            this.errorCheck = true;
            this.errorMessage = 'Please Enter your Email.';
            return;
        }
        
        const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        if (!emailPattern.test(this.username)) {
            this.errorCheck = true;
            this.errorMessage = 'Please enter a valid email address.';
            return;
        }
        if(this.username && this.password){

            event.preventDefault();
    
            doLogin({ username: this.username, password: this.password })
                .then((result) => {
                    window.location.href = result;
                })
                .catch((error) => {
                    this.error = error;      
                    this.errorCheck = true;
                    this.errorMessage = error.body.message;
                    let errorMessage = error.body.message;
                    if(errorMessage.includes('INVALID_EMAIL_ADDRESS')){
                        this.errorMessage = 'Please enter a valid email address.';
                    }else if(errorMessage.includes('INVALID_PASSWORD')){
                        this.errorMessage = 'Please enter a valid password.';
                    }else if(errorMessage.includes('Your login attempt has failed')){
                        this.errorMessage = 'Please choose a valid email and Password.';
                    }else if(errorMessage.includes('Your account has been locked')){
                        this.errorMessage = 'Your account has been locked. Please contact your administrator.';
                    }else if(errorMessage.includes('Too many failed login attempts')){  
                        this.errorMessage = 'Too many failed login attempts';
                    }else if(errorMessage.includes('Apex script unhandled')){       
                        this.errorMessage = 'Please contact your administrator.';
                    }else {
                        this.errorMessage = 'Please contact your administrator.';
                    }
                    
                });
    
            }
       /* if(this.username && this.password){

            event.preventDefault();
    
            doLogin({ username: this.username, password: this.password })
                .then((result) => {
                    window.location.href = result;
                })
                .catch((error) => {
                    this.error = error;      
                    this.errorCheck = true;
                    this.errorMessage = error.body.message;
                });
    
            }*/
    }
    handleFogotPassword(){
        let baseUrl = window.location.origin; 
        let forgotPasswordUrl = baseUrl + '/secur/forgotpassword.jsp'; 
        //window.location.assign('https://modonproperties--cpdev.sandbox.my.site.com/CustomerPortal/secur/forgotpassword.jsp'); 
        window.location.href = FORGOTPASSWORD;//'https://modonproperties--cpdev.sandbox.my.site.com/MCustomerPortal/ForgotPassword';
        
    }
    handlesignup(event) {
        this.signup = true;
    }
    handleSignUpFromChild(event) {
        this.signup = event.detail; // receiving "true" from child
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
}