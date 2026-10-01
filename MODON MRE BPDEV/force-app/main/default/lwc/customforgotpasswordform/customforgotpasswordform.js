import { LightningElement } from 'lwc';
import forgotPassword from '@salesforce/apex/CustomForgotPasswordController.forgotPassword';
import LOGO from '@salesforce/resourceUrl/modonLogoPlain';
import doLogin from '@salesforce/apex/CommunityLoginController.login';
import logowhite from '@salesforce/resourceUrl/logowhite';
import instagram from '@salesforce/resourceUrl/instagram'
import youtubeicon from '@salesforce/resourceUrl/youtubeicon';
import linkedinicon from '@salesforce/resourceUrl/linkedinicon';
import facebook from '@salesforce/resourceUrl/facebook';
import twitterx from '@salesforce/resourceUrl/Twitterx';
import HOMEPAGE from '@salesforce/label/c.Customer_Portal_URL';
import { NavigationMixin } from 'lightning/navigation';

export default class Customforgotpasswordform extends  NavigationMixin(LightningElement) {
    email = '';
    message = '';
    logoUrl = LOGO;
    errorCheck = false;
    errorMessage;
        logowhiteUrl = logowhite;
        instagramUrl = instagram;
        youtubeiconUrl = youtubeicon;
        linkediniconUrl = linkedinicon;
        facebookUrl = facebook;
        twitterxUrl = twitterx;
        isLoading = false;
    handleChange(event) {
        this.email = event.target.value;
    }
handlecancel() {
          const url = HOMEPAGE;//'https://modonproperties--cpdev.sandbox.my.site.com/MCustomerPortal/';
       // window.open(url,'_blank');
       window.location.href = url;
    }
 handleReset() {
    this.isLoading = true; // Start loading
        try {
            if(this.email === '' || this.email === undefined) {
                this.isLoading = false;
                this.errorMessage = 'Please enter your email address.';
                this.errorCheck = true;
                return;

            }
            forgotPassword({ email: this.email })
            .then(result => {
                this.isLoading = false;
                this.errorCheck = true;
                this.errorMessage = 'Password reset email sent to your email. Kindly check your email to reset the password!';
            })
            .catch((error) => {
                this.isLoading = false;
                this.errorMessage = 'Error: Please reach out to the support team.';
                this.errorCheck = true;
                console.error('Error:', JSON.stringify(error));
            });

        } catch (error) {
            this.isLoading = false;
            this.errorCheck = true;
            this.errorMessage = 'Error: ' + error.body.message;
        }
    }
}