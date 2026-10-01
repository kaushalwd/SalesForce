import { LightningElement, api } from 'lwc';

export default class GuestLoader extends LightningElement {
    /** Controls visibility. Parent can bind or call show()/hide() */
    @api isLoading = false;

    /** main line message */
    @api message = 'Please review your details and sign the KYC form in the next step.';

    /** optional smaller line under the message */
    @api subMessage = '';

    /** optional logo url (fallback if slot not provided) */
    @api logoUrl;

    /** control text direction for Arabic support: 'ltr' or 'rtl' */
    @api dir = 'ltr';

    get ariaLabel() {
        return this.message;
    }

    /** programmatic helpers */
    @api show() {
        this.isLoading = true;
    }

    @api hide() {
        this.isLoading = false;
    }
}