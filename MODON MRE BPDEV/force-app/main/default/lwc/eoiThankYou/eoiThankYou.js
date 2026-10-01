/**
 * eoiThankYou — "payment successful" page shown after the customer's last
 * pending EOI payment, when EOI_Site_Thank_You_Enabled is true. With the label
 * false the journey lands on the payment step's receipt view as before.
 * @author Aurelix
 */
import { LightningElement, api } from 'lwc';

export default class EoiThankYou extends LightningElement {
    @api rows = [];      // eoiIdentityChooser.doneRows: desc, eoiLabel, awaitingEoi
    @api backUrl = '';
    @api isBusy = false;

    get hasRows() {
        return (this.rows || []).length > 0;
    }

    viewRegistrations() {
        this.dispatchEvent(new CustomEvent('viewregistrations'));
    }
}