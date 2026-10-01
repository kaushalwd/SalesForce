import { LightningElement, api, track } from 'lwc';
import getCurrentStep from '@salesforce/apex/ReceiptProgressIndicatorController.getCurrentStep';

export default class ReceiptProgressIndicator extends LightningElement {
    @api recordId;

    @track currentStatus = '';

    orderedStatuses = [
        'SF Approval Pending',  
        'Verified - Not Sent to Oracle',
        'Sent to EBS',
        'Oracle Approval Pending',
        'Awaiting Remittance',
        'Cleared'
    ];


    hoveredStatuses = null;

    connectedCallback() {
        this.loadCurrentStep();
    }

    async loadCurrentStep() {
        try {
            this.currentStatus = await getCurrentStep({ recordId: this.recordId });
        } catch (error) {
            console.error('Error fetching current step:', error);
        }
    }

    handleStatusClick(event) {
        // Your existing click handler if needed, or remove
    }

    handleStageMouseEnter(event) {
        const li = event.target.closest('li[data-label]');
        const label = li ? li.dataset.label : null;
        const fullStatuses = this.processedStatuses;
        const hovered = fullStatuses.find(s => s.label === label);
        this.hoveredStatuses = hovered ? [hovered] : null;
    }

    handleStageMouseLeave(event) {
        this.hoveredStatuses = null;
    }

    get processedStatuses() {
        let statusList = [...this.orderedStatuses];
        if (this.currentStatus === 'Verified' || this.currentStatus === 'Cleared') {
            statusList = statusList.filter(status => status !== 'Verified - Not Sent to Oracle' && status !== 'Oracle Approval Pending');
        }

        //return this.computeStatuses(this.orderedStatuses);
        return this.computeStatuses(statusList);
    }

    computeStatuses(statusList) {
        return statusList.map(label => {
            let className = 'slds-path__item ';
            let isComplete = false;
            let textClass = 'slds-path__title';

            if (label === this.currentStatus) {
                className += 'slds-is-current slds-is-active';
                if(this.currentStatus === 'Verified - Not Sent to Oracle'){
                    textClass += 'slds-text-color_error';
                }else{   
                    textClass += ' slds-text-color_inverse';
                }

            } else if (statusList.indexOf(label) < statusList.indexOf(this.currentStatus)) {
                className += 'slds-is-complete';
                isComplete = true;
            } else {
                className += 'slds-is-incomplete';
            }

            return { label, className, isComplete, textClass };
        });
    }

    get displayStatuses() {
        return this.hoveredStatuses || this.processedStatuses;
    }

    get statusStageWidthStyle() {
        const count = this.displayStatuses.length || 1;
        return `width:${(100 / count).toFixed(2)}%; min-width:80px; max-width:140px;`;
    }

    get statusLabelStyle() {
        return this.hoveredStatuses
            ? 'white-space:normal; overflow:visible; text-overflow:clip; margin:0;'
            : 'white-space:nowrap; overflow:hidden; text-overflow:ellipsis; margin:0;';
    }
}