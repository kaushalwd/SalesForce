/**
* @description       : Lightning Web Component for Modon Egypt Bulk Cheque Entry Datatable
* @author            : Milin Kapatel
* @company           : Horizontal
* @last modified on  : 05-02-2026
* @last modified by  : Milin Kapatel
* Modifications Log
* Ver   Date         Author             Modification
* 1.0   05-02-2026   Milin Kapatel      Initial Version
**/
import LightningDatatable from 'lightning/datatable';
import DatatablePicklistTemplate from './picklist-template.html';
import FileUploadTemplate from './file-upload-template.html';
import { loadStyle } from 'lightning/platformResourceLoader';
import CustomDataTableResource from '@salesforce/resourceUrl/CustomDataTable';

export default class ModonEgyptBulkChequeEntryDatatable extends LightningDatatable {
    
    static customTypes = {
        picklist: {
            template: DatatablePicklistTemplate,
            typeAttributes: ['placeholder', 'field', 'editable', 'options', 'value', 'context'],
        },
        fileupload: {
            template: FileUploadTemplate,
            typeAttributes: ['label', 'formats', 'recordId']
        }
    };

    constructor() {
        super();
        Promise.all([
            loadStyle(this, CustomDataTableResource),
        ]).then(() => {})
    }
}