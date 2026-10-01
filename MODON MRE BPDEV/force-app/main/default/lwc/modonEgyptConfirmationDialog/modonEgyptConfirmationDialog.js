/**
* @description       : Lightning Web Component for Modon Egypt Confirmation Dialog
* @author            : Milin Kapatel
* @company           : Horizontal
* @last modified on  : 05-02-2026
* @last modified by  : Milin Kapatel
* Modifications Log
* Ver   Date         Author             Modification
* 1.0   05-02-2026   Milin Kapatel      Initial Version
**/
import { LightningElement, api } from 'lwc';

export default class ModonEgyptConfirmationDialog extends LightningElement {
    @api visible; //used to hide/show dialog
    @api title; //modal title
    @api name; //reference name of the component
    @api message; //modal message
    @api confirmLabel; //confirm button label
    @api cancelLabel; //cancel button label
    @api originalMessage; //any event/message/detail to be published back to the parent component

    //handles button clicks
    handleClick(event) {
        //creates object which will be published to the parent component
        if (event.target) {
            let finalEvent = {
                originalMessage: this.originalMessage,
                status: event.target.name
            };

            //dispatch a 'click' event so the parent component can handle it
            this.dispatchEvent(new CustomEvent('click', { detail: finalEvent }));
        }
    }
}