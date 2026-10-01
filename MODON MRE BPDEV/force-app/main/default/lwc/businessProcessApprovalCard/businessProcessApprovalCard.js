import { LightningElement, api } from 'lwc';

const STATUS_VARIANT = {
    Open: 'pending',
    Accepted: 'pending',
    Assigned: 'pending',
    'Re Open': 'pending',
    'Re Assigned': 'pending',
    'Provided Info': 'pending',
    'Required Info': 'info',
    Completed: 'success',
    Rejected: 'error',
    Cancelled: 'error',
    Skipped: 'neutral',
    'Not Actioned': 'neutral'
};

export default class BusinessProcessApprovalCard extends LightningElement {
    @api step;
    @api isSelected = false;

    get cardClass() {
        return 'approval-card' + (this.isSelected ? ' approval-card_selected' : '');
    }

    get statusVariant() {
        return STATUS_VARIANT[this.step && this.step.status] || 'neutral';
    }

    get statusClass() {
        return 'status-pill status-pill_' + this.statusVariant;
    }

    get hasContext() {
        const s = this.step;
        return !!(s && (s.accountName || s.unitName || s.projectName || s.salesOrderName));
    }

    get displayDate() {
        return (this.step && (this.step.assignedDate || this.step.createdDate)) || null;
    }

    get displayDateLabel() {
        return this.step && this.step.assignedDate ? 'Assigned' : 'Created';
    }

    get ariaSelected() {
        return this.isSelected ? 'true' : 'false';
    }

    handleClick() {
        this.dispatchEvent(
            new CustomEvent('select', {
                detail: { stepId: this.step.stepId }
            })
        );
    }

    handleKeyDown(event) {
        if (event.key === 'Enter' || event.key === ' ') {
            event.preventDefault();
            this.handleClick();
        }
    }
}