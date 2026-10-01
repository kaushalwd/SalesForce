import { LightningElement, api, track } from 'lwc';
import getServiceRequestMilestone from '@salesforce/apex/SRPaymentReadinessController.getServiceRequestMilestone';
import getUnpaidInstallments from '@salesforce/apex/SRPaymentReadinessController.getUnpaidInstallments';
import saveDefaultSR from '@salesforce/apex/SRPaymentReadinessController.saveDefaultSR';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class DefaultSRCreator extends LightningElement {

    _recordId;
   
    initialized = false;

    @track rows = [];

    milestoneId;
    milestoneName;

    selectedIds = new Set();

    isLoading = false;

    @api
    get recordId() {
        return this._recordId;
    }

    set recordId(value) {
        this._recordId = value;

        if (!this.initialized && value) {
            this.initialized = true;
            this.load();
        }
    }

    async load() {
        try {

            this.isLoading = true;

            this.milestoneId = await getServiceRequestMilestone({
                serviceRequestId: this.recordId
            });

            const data = await getUnpaidInstallments({
                milestoneId: this.milestoneId
            });

            this.rows = (data || []).map(r => {
                return {
                    ...r,
                    selected: false,
                    defaultSR: r.defaultSR ? true : false,
                    defaultComments: r.defaultComments || ''

                };
            });

            if (this.rows.length > 0) {
                this.milestoneName = this.rows[0].milestoneName;
            }

        } catch (e) {

            this.showToast('Error', e.body?.message, 'error');

        } finally {

            this.isLoading = false;
        }
    }

    get hasRows() {
        return this.rows.length > 0;
    }
get createDisabled() {
    return !this.rows.some(r => r.selected);
}

   handleSelect(event) {

    const id = event.target.dataset.id;
    const checked = event.target.checked;

    this.rows = this.rows.map(row => {
        if (row.soiId === id) {
            return { ...row, selected: checked };
        }
        return row;
    });
}

    handleSelectAll(event) {

        const checked = event.target.checked;

        this.selectedIds.clear();

        this.rows = this.rows.map(row => {

            if (checked) {
                this.selectedIds.add(row.soiId);
            }

            return {
                ...row,
                selected: checked
            };
        });
    }

    handleDefaultSR(event) {

        const id = event.target.dataset.id;
        const checked = event.target.checked;

        this.rows = this.rows.map(row => {

            if (row.soiId === id) {
                return {
                    ...row,
                    defaultSR: checked
                };
            }

            return row;
        });
    }
    handleCommentChange(event) {

    const id = event.target.dataset.id;
    const value = event.target.value;

    this.rows = this.rows.map(row => {

        if (row.soiId === id) {

            return {
                ...row,
                defaultComments: value
            };

        }

        return row;

    });

}

async handleSave() {

    try {

        const updates = this.rows
    .filter(r => r.selected)
    .map(r => ({
        soiId: r.soiId,
        defaultSR: r.defaultSR,
        defaultComments: r.defaultComments
    }));

        if (updates.length === 0) {
            this.showToast('Warning','Please select at least one SOI','warning');
            return;
        }

        this.isLoading = true;

        await saveDefaultSR({
            serviceRequestId: this.recordId,
    updates: updates
});
        this.showToast('Success','Default SR updated successfully','success');

        this.load();

    } catch(e){

        this.showToast('Error', e.body?.message, 'error');

    } finally {

        this.isLoading = false;
    }
}
handleCancel(){
    this.dispatchEvent(new CloseActionScreenEvent());
}

    showToast(title,message,variant){
        this.dispatchEvent(
            new ShowToastEvent({title,message,variant})
        );
    }
}