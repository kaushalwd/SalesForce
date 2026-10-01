/**********************************************************************************************************************
* Name               : uaeddsHome
* Description        : The direct debit watchlist: the two deadlines that move against a clock and cannot be
*                      expressed as a list view filter, plus the counts that need somebody to look.
* Usage              : Direct Debit app, Home tab
* Created By         : Modon
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           Prateek Bansal              24 Aug 2026     Initial version
******************************************************************************************************************/
import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

import getHome from '@salesforce/apex/UAEDDS_LWCController.getHome';

// A minute is fine. Both deadlines are hours away, and a per-second tick would repaint the page
// 60 times for a number that has not changed.
const TICK_MS = 60000;

export default class UaeddsHome extends NavigationMixin(LightningElement) {
    view;
    loading = false;
    now = Date.now();
    timer;

    connectedCallback() {
        this.load();
        this.timer = setInterval(() => {
            this.now = Date.now();
        }, TICK_MS);
    }

    disconnectedCallback() {
        clearInterval(this.timer);
    }

    load() {
        this.loading = true;
        getHome()
            .then((view) => {
                this.view = view;
            })
            .catch(() => {
                this.view = undefined;
            })
            .finally(() => {
                this.loading = false;
            });
    }

    handleRefresh() {
        this.load();
    }

    // ---------------------------------------------------------------- the cut-off

    get cutOffLabel() {
        if (!this.view || !this.view.cutOff) {
            return '';
        }
        const left = new Date(this.view.cutOff).getTime() - this.now;
        if (left <= 0) {
            return 'closed';
        }
        const hours = Math.floor(left / 3600000);
        const minutes = Math.floor((left % 3600000) / 60000);
        return hours > 0 ? `${hours}h ${minutes}m left` : `${minutes}m left`;
    }

    get cutOffUrgent() {
        if (!this.view || !this.view.cutOff) {
            return false;
        }
        const left = new Date(this.view.cutOff).getTime() - this.now;
        return left > 0 && left < 3 * 3600000;
    }

    get cutOffClass() {
        if (!this.view) {
            return 'dd-card';
        }
        if (this.view.pastCutOff) {
            return 'dd-card dd-card_bad';
        }
        return this.cutOffUrgent ? 'dd-card dd-card_warn' : 'dd-card';
    }

    get dueHeadline() {
        if (!this.view) {
            return '';
        }
        const n = this.view.dueCount;
        return `${n} installment${n === 1 ? '' : 's'} ready`;
    }

    get dueBlockedLabel() {
        if (!this.view || !this.view.dueBlocked) {
            return '';
        }
        const n = this.view.dueBlocked;
        return `${n} due tomorrow cannot be collected. The Collections tab names each reason.`;
    }

    // ---------------------------------------------------------------- signing

    /**
     * Sorted by the service, so the row nearest its deadline leads. Anything already past is shown
     * as overdue rather than hidden - UAEDDS may not have aged it out yet, and a mandate the
     * customer never signed is exactly what somebody needs to chase.
     */
    get signingRows() {
        if (!this.view || !this.view.signing) {
            return [];
        }
        return this.view.signing.map((s) => ({
            ...s,
            label:
                s.daysLeft < 0
                    ? 'overdue'
                    : s.daysLeft === 0
                      ? 'today'
                      : `${s.daysLeft} day${s.daysLeft === 1 ? '' : 's'}`,
            rowClass: s.daysLeft <= 2 ? 'dd-row dd-row_warn' : 'dd-row'
        }));
    }

    get signingCount() {
        return this.view && this.view.signing ? this.view.signing.length : 0;
    }

    get hasSigning() {
        return this.signingCount > 0;
    }

    get signingClass() {
        const rows = this.signingRows;
        return rows.some((r) => r.daysLeft <= 2) ? 'dd-card dd-card_warn' : 'dd-card';
    }

    // ---------------------------------------------------------------- the three counts

    get stuckClass() {
        return this.view && this.view.stuckFiles > 0 ? 'dd-card dd-card_bad' : 'dd-card';
    }

    get bouncedClass() {
        return this.view && this.view.bounced > 0 ? 'dd-card dd-card_warn' : 'dd-card';
    }

    get unmatchedClass() {
        return this.view && this.view.unmatched > 0 ? 'dd-card dd-card_bad' : 'dd-card';
    }

    get allQuiet() {
        return (
            this.view &&
            !this.hasSigning &&
            this.view.dueCount === 0 &&
            this.view.stuckFiles === 0 &&
            this.view.bounced === 0 &&
            this.view.unmatched === 0
        );
    }

    handleOpenMandate(event) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: event.currentTarget.dataset.id,
                objectApiName: 'DirectDebitRequest__c',
                actionName: 'view'
            }
        });
    }
}