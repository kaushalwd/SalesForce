/**
 * eoiSiteClosed — the "we are currently closed" state for the EOI microsites.
 * Rendered by eoiIdentityChooser in place of the whole journey while the
 * EOI_Site_Closed label is true (read at runtime, no republish).
 * @author Aurelix
 */
import { LightningElement, api } from 'lwc';

export default class EoiSiteClosed extends LightningElement {
    @api contactUrl = '';
}