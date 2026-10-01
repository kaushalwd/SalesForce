/**
* @description       : Lightning Web Component for Modon Egypt File Upload View
* @author            : Milin Kapatel
* @company           : Horizontal
* @last modified on  : 05-02-2026
* @last modified by  : Milin Kapatel
* Modifications Log
* Ver   Date         Author             Modification
* 1.0   05-02-2026   Milin Kapatel      Initial Version
**/
import { LightningElement, api, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getRelatedFiles from '@salesforce/apex/Modon_Egypt_FileUploadViewController.getRelatedFiles';

export default class ModonEgyptFileUploadView extends LightningElement{
    @api label;
    @api formats;
    @api recordId;

    get acceptedFormats() {
        return this.formats.split(',');
    }

    @wire(getRelatedFiles, { recordId: '$recordId' })
    files;

    handleActionFinished(event) {
        //refresh the list of files
        refreshApex(this.files);
    }
}