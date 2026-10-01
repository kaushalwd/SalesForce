import { LightningElement, api } from 'lwc';

export default class MbprEmptyState extends LightningElement {
    @api kicker = '';
    @api title = 'Nothing to show yet';
    @api message = '';
    @api tone = 'neutral';
    @api compact = false;
    @api showGraphic = false;
    @api primaryLabel = '';
    @api secondaryLabel = '';
    @api politeness = 'polite';

    get stateClass() {
        const classes = ['empty', `empty--${this.safeValue(this.tone)}`];
        if (this.compact) classes.push('empty--compact');
        if (this.showGraphic) classes.push('empty--graphic');
        return classes.join(' ');
    }

    get hasActions() {
        return Boolean(this.primaryLabel || this.secondaryLabel);
    }

    get ariaLiveValue() {
        return this.politeness === 'assertive' ? 'assertive' : 'polite';
    }

    handlePrimary() {
        this.dispatchEvent(new CustomEvent('primary'));
    }

    handleSecondary() {
        this.dispatchEvent(new CustomEvent('secondary'));
    }

    safeValue(value) {
        return String(value || 'neutral').replace(/[^a-z0-9-]/gi, '').toLowerCase() || 'neutral';
    }
}