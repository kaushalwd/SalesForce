/**
 * Console footer - Terms and Privacy.
 *
 * Version  Author      Date         Detail
 * 1.1      Aurelix Dev 30 Sep 2026  Terms and Privacy open as dialogs: Escape closes them, focus moves to the close
 *                                   button and back to the link. The panel text is unchanged (waiting for MODON).
 * 1.0      Aurelix IT  09 Aug 2026  Ported from modonFooter in the PoC org.
 */

import { LightningElement, api } from 'lwc';

// Short, honest placeholder legal copy for the PoC. Modon's real Terms/Privacy
// text would replace these before any production use.
const DOCS = {
  terms: {
    title: 'Terms of Service',
    paras: [
      'This Sales Console is provided to Modon personnel for internal sales operations only. Access is restricted to authorised users.',
      'All property, pricing, availability and booking information shown is indicative and subject to confirmation under the applicable sale and purchase agreement.',
      'Use of this application constitutes acceptance of Modon’s internal usage policies. Unauthorised use, distribution or reproduction of any content is prohibited.',
      'This is a proof-of-concept environment; figures and records shown are for demonstration purposes only.'
    ]
  },
  privacy: {
    title: 'Privacy Policy',
    paras: [
      'Customer and lead information captured in this console is processed by Modon for the purpose of managing sales enquiries, bookings and payments.',
      'Personal data is stored within Modon’s Salesforce environment and handled in accordance with applicable UAE data protection regulations.',
      'Data is accessible only to the assigned sales representative and authorised Modon staff, and is retained only for as long as needed to service the customer relationship.',
      'This is a proof-of-concept environment; no live customer data should be entered.'
    ]
  }
};

export default class MscFooter extends LightningElement {
  @api copyright = '© 2026 Modon. All rights reserved.';
  activeDoc = null;

  get showDoc() {
    return this.activeDoc !== null;
  }
  get docTitle() {
    return this.activeDoc ? DOCS[this.activeDoc].title : '';
  }
  get docParas() {
    if (!this.activeDoc) {
      return [];
    }
    return DOCS[this.activeDoc].paras.map((text, i) => ({ key: i, text }));
  }
  openTerms(e) {
    this.openDoc('terms', e);
  }
  openPrivacy(e) {
    this.openDoc('privacy', e);
  }

  /* 1.1: remember the link, listen for Escape anywhere, and put focus on the close button */
  openDoc(which, e) {
    this._opener = e && e.currentTarget ? e.currentTarget.dataset.doc : null;
    this.activeDoc = which;
    if (!this._onKey) {
      this._onKey = (ev) => this.handleDocKey(ev);
      window.addEventListener('keydown', this._onKey);
    }
    this._focusClose = true;
  }

  renderedCallback() {
    if (this._focusClose && this.showDoc) {
      this._focusClose = false;
      const close = this.template.querySelector('.doc-close');
      if (close) {
        close.focus();
      }
    }
  }

  handleDocKey(e) {
    if (this.showDoc && (e.key === 'Escape' || e.key === 'Esc')) {
      e.preventDefault();
      e.stopPropagation();
      this.closeDoc();
    }
  }

  closeDoc() {
    if (!this.showDoc) {
      return;
    }
    this.activeDoc = null;
    if (this._onKey) {
      window.removeEventListener('keydown', this._onKey);
      this._onKey = null;
    }
    /* focus back on the link that opened the panel */
    const which = this._opener;
    this._opener = null;
    if (which) {
      // eslint-disable-next-line @lwc/lwc/no-async-operation
      Promise.resolve().then(() => {
        const link = this.template.querySelector(`.link[data-doc="${which}"]`);
        if (link) {
          link.focus();
        }
      });
    }
  }

  disconnectedCallback() {
    if (this._onKey) {
      window.removeEventListener('keydown', this._onKey);
      this._onKey = null;
    }
  }

  stopProp(e) {
    e.stopPropagation();
  }
}