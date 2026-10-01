/**
 * eoiFooter — public-site legal footer bar with Terms / Privacy modal.
 * Mirrors the Sales Console footer (mscFooter) visual language.
 * All copy is @api-overridable; defaults are placeholder legal text.
 * @author Aurelix
 */
import { LightningElement, api } from 'lwc';

const DEFAULT_TERMS = [
    'This registration site is provided by Modon for expressions of interest. Submitting a registration does not constitute a reservation, allocation or offer of sale.',
    'All property, pricing and availability information shown is indicative and subject to confirmation under the applicable sale and purchase agreement.',
    'Use of this site constitutes acceptance of Modon’s terms of use.'
].join('\n');

const DEFAULT_PRIVACY = [
    'Personal information captured on this site is processed by Modon for the purpose of managing sales enquiries and expressions of interest.',
    'Personal data is stored within Modon’s Salesforce environment and handled in accordance with applicable UAE data protection regulations.',
    'Data is accessible only to authorised Modon staff and retained only for as long as needed to service the enquiry.'
].join('\n');

export default class EoiFooter extends LightningElement {
    @api copyrightText = '© 2026 Modon. All rights reserved.';
    /* MEOI-FOOT: modon.com's legal pages (verified 10 Sep 2026: both return 200) */
    @api termsUrl = 'https://www.modon.com/terms-and-conditions';
    @api privacyUrl = 'https://www.modon.com/privacy-policy';
    @api termsLabel = 'Terms';
    @api privacyLabel = 'Privacy';
    @api termsTitle = 'Terms of Service';
    @api privacyTitle = 'Privacy Policy';
    @api termsText = DEFAULT_TERMS;
    @api privacyText = DEFAULT_PRIVACY;

    openDoc = null;
    focusPending = false;

    connectedCallback() {
        this.keyHandler = (event) => {
            if (event.key === 'Escape') {
                this.closeDoc();
            }
        };
        window.addEventListener('keydown', this.keyHandler);
    }

    disconnectedCallback() {
        window.removeEventListener('keydown', this.keyHandler);
    }

    renderedCallback() {
        if (this.focusPending) {
            this.focusPending = false;
            const closeBtn = this.template.querySelector('.doc-close');
            if (closeBtn) {
                closeBtn.focus();
            }
        }
    }

    get isDocOpen() {
        return this.openDoc !== null;
    }
    get docTitle() {
        return this.openDoc === 'privacy' ? this.privacyTitle : this.termsTitle;
    }
    get docParas() {
        const text = this.openDoc === 'privacy' ? this.privacyText : this.termsText;
        return (text || '')
            .split(/\n+/)
            .map((p) => p.trim())
            .filter((p) => p)
            .map((p, i) => ({ key: 'p' + i, text: p }));
    }

    openTerms() {
        this.openDoc = 'terms';
        this.focusPending = true;
    }
    openPrivacy() {
        this.openDoc = 'privacy';
        this.focusPending = true;
    }
    closeDoc() {
        this.openDoc = null;
    }
    handleOverlayClick(event) {
        if (event.target === event.currentTarget) {
            this.closeDoc();
        }
    }
}