import { LightningElement, api } from 'lwc';

export default class MbprLoadingState extends LightningElement {
    @api variant = 'list';
    @api rows = 3;
    @api label = 'Loading';

    get stateClass() {
        return `loading loading--${this.safeValue(this.variant)}`;
    }

    get rowsArray() {
        const count = Math.max(1, Math.min(8, Number(this.rows) || 3));
        return Array.from({ length: count }, (_, index) => `row-${index}`);
    }

    get isHero() {
        return this.variant === 'hero' || this.variant === 'card';
    }

    safeValue(value) {
        return String(value || 'list').replace(/[^a-z0-9-]/gi, '').toLowerCase() || 'list';
    }
}