import { LightningElement, api } from 'lwc';

const OWNER_DOCS = [
    'Affection Plan',
    'Title Deed',
    'Sale & Purchase Agreement (SPA)',
    'Authorization Letter'
];

export default class PortalRegister extends LightningElement {
    @api loginUrl = '#';

    mode = 'owner';
    submitted = false;

    ownerDocs = OWNER_DOCS;

    get isOwner() {
        return this.mode === 'owner';
    }

    get isSp() {
        return this.mode === 'sp';
    }

    get ownerBtnClass() {
        return this.mode === 'owner' ? 'active' : '';
    }

    get spBtnClass() {
        return this.mode === 'sp' ? 'active' : '';
    }

    handleMode(event) {
        this.mode = event.currentTarget.dataset.id;
        this.submitted = false;
    }

    handleSubmit(event) {
        event.preventDefault();
        this.submitted = true;
    }
}