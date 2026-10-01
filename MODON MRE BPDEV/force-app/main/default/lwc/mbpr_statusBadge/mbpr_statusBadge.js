import { LightningElement, api } from 'lwc';

export default class MbprStatusBadge extends LightningElement {
    @api label = 'Status';
    @api tone = 'neutral';
    @api size = 'standard';

    get badgeClass() {
        return ['badge', `badge--${this.safeValue(this.tone)}`, `badge--${this.safeValue(this.size)}`].join(' ');
    }

    safeValue(value) {
        return String(value || 'neutral').replace(/[^a-z0-9-]/gi, '').toLowerCase() || 'neutral';
    }
}