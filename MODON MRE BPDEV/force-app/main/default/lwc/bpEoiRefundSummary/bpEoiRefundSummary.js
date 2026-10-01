import { LightningElement, api, wire } from 'lwc';

import getEOIRefundSummary from '@salesforce/apex/BP_OmniApprovalLwcController.getEOIRefundSummary';

export default class BpEoiRefundSummary extends LightningElement {

    @api bpStepId;

    summary;


    @wire(
        getEOIRefundSummary,
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
                'Error loading EOI refund summary:',
                error
            );

            this.summary = undefined;
        }
    }


    get showEOIList() {

        return !!this.summary?.showEOIList;
    }

    get eois() {

        return this.summary?.eois || [];
    }

    get hasEOIs() {

        return this.eois.length > 0;
    }

    get eoiCount() {

        return this.eois.length;
    }

}