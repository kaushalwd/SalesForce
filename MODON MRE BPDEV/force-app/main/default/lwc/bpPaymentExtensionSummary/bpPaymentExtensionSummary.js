import { LightningElement, api, wire } from 'lwc';

import getPaymentExtensionSummary from '@salesforce/apex/BP_OmniApprovalLwcController.getPaymentExtensionSummary';

export default class BpPaymentExtensionSummary extends LightningElement {

    @api bpStepId;

    summary;


    @wire(
        getPaymentExtensionSummary,
        {
            bpStepRecordId: '$bpStepId'
        }
    )
    wiredSummary({
        error,
        data
    }) {

        if (data) {

            this.summary = data;

        } else if (error) {

            console.error(
                'Error loading payment extension summary:',
                error
            );

            this.summary = undefined;
        }
    }


    get showSummary() {

        return !!this.summary?.showMilestoneInfo;
    }

    get showMilestoneInfo() {

        return !!this.summary?.showMilestoneInfo;
    }

    get milestoneNumber() {

        return this.summary?.milestoneNumber ?? '-';
    }

    get spaDate() {

        return this.summary?.spaDate;
    }

    get extendedDate() {

        return this.summary?.extendedDate;
    }

    get installmentAmount() {

        return this.summary?.installmentAmount;
    }

}