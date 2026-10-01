import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import generateInviteLink from '@salesforce/apex/EoiInviteAdminController.generateInviteLink';

export default class EoiInviteLinkManager extends LightningElement {
    @api recordId;
    @track isLoading = false;
    @track result = null;
    @track errorMessage = '';

    get hasResult() { return this.result != null; }
    get isLocked() { return this.result && this.result.alreadyConfirmed === true; }
    get formattedExpiresAt() {
        if (!this.result || !this.result.expiresAt) return '';
        return new Date(this.result.expiresAt).toLocaleString();
    }
    get formattedConfirmedAt() {
        if (!this.result || !this.result.confirmedAt) return '';
        return new Date(this.result.confirmedAt).toLocaleString();
    }

    async handleGenerate() {
        if (!this.recordId) {
            this.errorMessage = 'No Lead Id available on this page.';
            return;
        }
        this.errorMessage = '';
        this.isLoading = true;
        try {
            const r = await generateInviteLink({ leadId: this.recordId, expiryDays: null });
            this.result = r;
            this.dispatchEvent(new ShowToastEvent({
                title: 'Invite link generated', variant: 'success'
            }));
        } catch (e) {
            this.errorMessage = (e && e.body && e.body.message) || (e && e.message) || 'Failed to generate link.';
        } finally {
            this.isLoading = false;
        }
    }

    async handleCopy() {
        if (!this.result || !this.result.url) return;
        try {
            await navigator.clipboard.writeText(this.result.url);
            this.dispatchEvent(new ShowToastEvent({
                title: 'Copied to clipboard', variant: 'success'
            }));
        } catch (e) {
            this.errorMessage = 'Could not copy. Use the field below to copy manually.';
        }
    }

    handleWhatsApp() {
        if (!this.result || !this.result.url) return;
        const name = this.result.leadName || '';
        const greeting = name
            ? `Hi ${name}, please confirm your selection: ${this.result.url}`
            : `Please confirm your selection: ${this.result.url}`;
        const url = 'https://wa.me/?text=' + encodeURIComponent(greeting);
        window.open(url, '_blank', 'noopener');
    }
}