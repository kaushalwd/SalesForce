import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';

// Apex
import createExternalCommissions from '@salesforce/apex/CommissionLineReviewController.createExternalCommissions';

// Schema (adjust object name if yours differs)
import BROKER_AGENCY from '@salesforce/schema/Commission_Line__c.BrokerAgencyFRM__c';
import COMM_PERCENT from '@salesforce/schema/Commission_Line__c.Commission_Percent__c';
import UNIT from '@salesforce/schema/Commission_Line__c.Unit__c';
import TOTAL_PRICE from '@salesforce/schema/Commission_Line__c.Total_Unit_Price__c';
import COMMENTS from '@salesforce/schema/Commission_Line__c.Comments__c';

const FIELDS = [BROKER_AGENCY, COMM_PERCENT, UNIT, TOTAL_PRICE, COMMENTS];
export default class RecalculateExternalCommissionAction extends LightningElement {
    @api recordId;

    isLoading = false;
    loadError;
    commissionPercent; // editable
    comments;

    wiredRecord;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredGetRecord(result) {
        this.wiredRecord = result;
        const { data, error } = result;

        if (data) {
            this.loadError = null;
            // default editable percent to current record value
            this.commissionPercent = getFieldValue(data, COMM_PERCENT);
        } else if (error) {
            this.loadError = this.normalizeError(error);
        }
    }

    get hasData() {
        return !!this.wiredRecord?.data;
    }

    get brokerAgency() {
        return getFieldValue(this.wiredRecord?.data, BROKER_AGENCY) || '';
    }

    get unitName() {
        // If Unit__c is a lookup, this will show the Id.
        // If you want the Unit Name instead, tell me Unit__c target object and I’ll adjust to query Unit__r.Name.
        return getFieldValue(this.wiredRecord?.data, UNIT) || '';
    }

    get totalUnitPrice() {
        return getFieldValue(this.wiredRecord?.data, TOTAL_PRICE) ?? '';
    }

    get disableRecalculate() {
        return this.isLoading || !this.recordId || this.loadError || !this.isPercentValid();
    }

    handlePercentChange(event) {
        this.commissionPercent = event.detail.value;
    }
    handleCommentsChange(event) {
        this.comments = event.detail.value;
    }

    isPercentValid() {
        const v = this.commissionPercent;
        if (v === null || v === undefined || v === '') return false;

        const n = Number(v);
        if (Number.isNaN(n)) return false;

        // 0..100 allowed
        return n >= 0 && n <= 100;
    }

    async handleRecalculate() {
        if (!this.isPercentValid()) {
            this.toast('Error', 'Please enter a valid Commission Percent (0 to 5).', 'error');
            return;
        }
        if (this.commissionPercent < 1 || this.commissionPercent > 5) {
            this.toast('Error', 'Please enter a valid Commission Percent (0 to 5).', 'error');
            return;
        }
        if(!this.comments || this.comments.trim() === '') {
            this.toast('Error', 'Comments field is required to proceed.', 'error');
            return;
        }

        this.isLoading = true;
        try {
            // ✅ IMPORTANT:
            // This assumes your Apex method signature is something like:
            // createExternalCommissions(Id recordId, Decimal commissionPercent)
            await createExternalCommissions({
                recordId: this.recordId,
                commissionPercent: Number(this.commissionPercent),
                comments: this.comments.trim()
            });

            this.toast('Success', 'External commission recalculated initiated, will be processed shortly.', 'success');
            this.dispatchEvent(new CloseActionScreenEvent());
        } catch (e) {
            this.toast('Error', this.normalizeError(e), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleCancel() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    normalizeError(e) {
        if (Array.isArray(e?.body)) return e.body.map(x => x.message).join(', ');
        return e?.body?.message || e?.message || 'Unknown error';
    }
}