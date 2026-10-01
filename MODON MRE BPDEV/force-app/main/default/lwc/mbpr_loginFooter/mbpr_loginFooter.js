import { LightningElement, api } from 'lwc';

export default class MbprLoginFooter extends LightningElement {
    @api year;
    @api termsUrl = '';
    @api privacyUrl = '';
}