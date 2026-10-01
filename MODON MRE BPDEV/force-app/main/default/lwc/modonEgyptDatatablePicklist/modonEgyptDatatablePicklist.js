/**
* @description       : Lightning Web Component for Modon Egypt Datatable Picklist
* @author            : Milin Kapatel
* @company           : Horizontal
* @last modified on  : 05-02-2026
* @last modified by  : Milin Kapatel
* Modifications Log
* Ver   Date         Author             Modification
* 1.0   05-02-2026   Milin Kapatel      Initial Version
**/
import { LightningElement, api } from 'lwc';

export default class ModonEgyptDatatablePicklist extends LightningElement {
    @api placeholder;
    @api field;
    @api options;
    @api value;
    @api context;
    @api editable;

    get isDisabled() {
        return !this.editable;
    }

    handleChange(event) {
        //show the selected value on UI
        this.value = event.detail.value;
        
        //fire event to send context and selected value to the data table
        this.dispatchEvent(new CustomEvent('picklistchanged', {
            composed: true,
            bubbles: true,
            cancelable: true,
            detail: {
                data: { context: this.context, value: this.value, fieldName: this.field  }
            }
        }));
    }

}