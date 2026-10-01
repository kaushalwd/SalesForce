/**********************************************************************************************************************
* Name               : ddaReconReport
* Description        : The UAEDDS day-end report for a date, read back against what Salesforce believes it submitted.
* Usage              : Direct Debit app, Reconciliation tab
* Created By         : Modon
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           Prateek Bansal              23 Aug 2026     Initial version
* 1.1           Prateek Bansal              24 Aug 2026     Console palette
******************************************************************************************************************/
import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import runDailyReport from '@salesforce/apex/UAEDDS_LWCController.runDailyReport';

const SHARED = [
    { label: 'Payment id', fieldName: 'paymentId', type: 'text' },
    { label: 'DDA reference', fieldName: 'customerDdsRefNo', type: 'text' },
    { label: 'Payment ref', fieldName: 'paymentRefNo', type: 'text' },
    { label: 'Amount', fieldName: 'amount', type: 'text', cellAttributes: { alignment: 'right' } },
    { label: 'Status', fieldName: 'statusDescription', type: 'text', wrapText: true },
    { label: 'FT reference', fieldName: 'ftRefNo', type: 'text' }
];

const MATCHED = [
    ...SHARED,
    {
        label: 'Transaction',
        fieldName: 'transactionUrl',
        type: 'url',
        typeAttributes: { label: { fieldName: 'transactionName' }, target: '_self' }
    },
    { label: 'Mandate', fieldName: 'mandateName', type: 'text' }
];

export default class DdaReconReport extends LightningElement {
    reportDate = this.yesterday();
    unmatchedColumns = SHARED;
    matchedColumns = MATCHED;

    unmatched = [];
    matched = [];
    emptyDay = false;
    ran = false;
    loading = false;

    connectedCallback() {
        this.run();
    }

    // Built from local parts rather than toISOString - same reason as the collection screen.
    yesterday() {
        const d = new Date();
        d.setDate(d.getDate() - 1);
        const pad = (n) => String(n).padStart(2, '0');
        return d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate());
    }

    run() {
        this.loading = true;
        this.ran = false;
        this.emptyDay = false;

        runDailyReport({ reportDate: this.reportDate })
            .then((view) => {
                this.unmatched = view.unmatched || [];
                this.matched = (view.matched || []).map((r) => ({
                    ...r,
                    transactionUrl: `/lightning/r/DirectDebit_Transactions__c/${r.transactionId}/view`
                }));
                this.emptyDay = view.emptyDay;
                this.ran = !view.emptyDay;
            })
            .catch((error) => {
                this.toast('Not read', this.readError(error), 'error', 'sticky');
            })
            .finally(() => {
                this.loading = false;
            });
    }

    get hasUnmatched() {
        return this.unmatched.length > 0;
    }

    get allMatched() {
        return this.unmatched.length === 0;
    }

    get hasMatched() {
        return this.matched.length > 0;
    }

    get matchedCount() {
        return this.matched.length;
    }

    get unmatchedHeading() {
        const n = this.unmatched.length;
        return `${n} payment${n === 1 ? '' : 's'} moved against a Modon mandate with no request behind ${
            n === 1 ? 'it' : 'them'
        }.`;
    }

    get nothingToExport() {
        return this.loading || (this.unmatched.length === 0 && this.matched.length === 0);
    }

    handleDateChange(event) {
        this.reportDate = event.target.value;
    }

    handleRun() {
        this.run();
    }

    handleExport() {
        const header = [
            'match', 'paymentId', 'customerDdsRefNo', 'paymentRefNo',
            'amount', 'status', 'statusDescription', 'ftRefNo', 'transaction', 'mandate'
        ];
        const lines = [header.join(',')];
        this.unmatched.forEach((r) => lines.push(this.line('unmatched', r)));
        this.matched.forEach((r) => lines.push(this.line('matched', r)));

        const link = document.createElement('a');
        link.href = 'data:text/csv;charset=utf-8,' + encodeURIComponent(lines.join('\n'));
        link.download = `uaedds-reconciliation-${this.reportDate}.csv`;
        link.click();
    }

    line(match, r) {
        return [
            match, r.paymentId, r.customerDdsRefNo, r.paymentRefNo, r.amount,
            r.status, r.statusDescription, r.ftRefNo, r.transactionName, r.mandateName
        ]
            .map((v) => `"${(v === null || v === undefined ? '' : v).toString().replace(/"/g, '""')}"`)
            .join(',');
    }

    readError(error) {
        if (error && error.body && error.body.message) {
            return error.body.message;
        }
        if (error && error.message) {
            return error.message;
        }
        return 'Something went wrong. The call is in the Direct Debit logs.';
    }

    toast(title, message, variant, mode) {
        this.dispatchEvent(
            new ShowToastEvent({ title, message, variant, mode: mode || 'dismissable' })
        );
    }
}