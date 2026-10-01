import { LightningElement, api, track, wire } from 'lwc';
import { CurrentPageReference, NavigationMixin} from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import getUnits from '@salesforce/apex/BCCController.getUnits';
import sendBCCLetter from '@salesforce/apex/BCCController.sendBCCLetter';

const COLUMNS = [
    {
        label: 'Unit Name',
        fieldName: 'unitUrl',
        type: 'url',
        typeAttributes: {
            label: { fieldName: 'Name' },
            target: '_blank',
            tooltip: { fieldName: 'Name' }
        }
    },
    {
        label: 'Phase',
        fieldName: 'phaseUrl',
        type: 'url',
        typeAttributes: {
            label: { fieldName: 'phaseName' },
            target: '_blank',
            tooltip: { fieldName: 'phaseName' }
        }
    },
    {
        label: 'Type',
        fieldName: 'Type__c'
    },
    {
        label: 'Status',
        fieldName: 'Status__c'
    }
];

export default class BuildingCompletionCertificate extends NavigationMixin(LightningElement) {

    recordId;

    @track data = [];
    @track error;

    columns = COLUMNS;
    selectedRows = [];

    @wire(CurrentPageReference)
    setCurrentPageReference(currentPageReference) {
        if (currentPageReference) {
            this.recordId = currentPageReference.state.recordId;
            this.loadUnits();;
        }
    }

    async loadUnits() {
        try {
            const result = await getUnits({ phaseId: this.recordId });
            this.data = result.map(unit => {
                return {
                    ...unit,
                    unitUrl: '/' + unit.Id,
                    phaseUrl: unit.Phase__c ? '/' + unit.Phase__c : '',
                    phaseName: unit.Phase__r ? unit.Phase__r.Name : ''
                };
            });

            this.error = null;
        } catch (err) {
            this.error = err.body?.message || err.message;
            console.error(err);
        }
    }

    get selectedCount() {
        return this.selectedRows?.length || 0;
    }

    get disableSendButton() {
        return this.selectedCount === 0;
    }

    handleRowSelection(event) {
        this.selectedRows = event.detail.selectedRows;
    }

    async handleSend() {
        try {
            if (!this.selectedRows || this.selectedRows.length === 0) {
                this.showToast('Error', 'Please select at least one unit.', 'error');
                return;
            }

            const unitIds = this.selectedRows.map(row => row.Id);

            const result = await sendBCCLetter({ unitIds });
            if (result === 'Success') {
                this.showToast('Success', `BCC Letter initiated for ${unitIds.length} selected unit(s).`, 'success');
                this.handleCancel();
            } else {
                this.showToast('Error', result, 'error');
            }
        } catch (error) {
            this.showToast('Error', error?.body?.message || error?.message || 'An unexpected error occurred.', 'error');
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

}