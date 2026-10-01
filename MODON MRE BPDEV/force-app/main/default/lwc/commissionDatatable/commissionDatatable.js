import LightningDatatable from 'lightning/datatable';
import picklistTemplate from './picklistTemplate.html';
import picklistEditTemplate from './picklistEditTemplate.html';
import ownerLookupTemplate from './ownerLookupTemplate.html';
import ownerLookupEditTemplate from './ownerLookupEditTemplate.html';


export default class CommissionDatatable extends LightningDatatable {
    static customTypes = {
        picklist: {
            template: picklistTemplate,
            editTemplate: picklistEditTemplate,
            standardCellLayout: true,
            typeAttributes: ['placeholder', 'options', 'value', 'context', 'fieldName']
        },
        ownerlookup: {
            template: ownerLookupTemplate,
            editTemplate: ownerLookupEditTemplate,
            standardCellLayout: true,
            typeAttributes: ['value', 'displayValue', 'context']
        }
    };

    handlePicklistChange(event) {
        event.stopPropagation();

        const context = event.target.dataset.context;
        const fieldName = event.target.dataset.field;
        const value = event.detail.value;

        this.dispatchEvent(
            new CustomEvent('cellchange', {
                detail: {
                    draftValues: [
                        {
                            recordId: context,
                            [fieldName]: value
                        }
                    ]
                },
                bubbles: true,
                composed: true
            })
        );
    }
}