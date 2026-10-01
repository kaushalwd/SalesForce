/**********************************************************************************************************************
* Name               : uaeddsCollectionScreen
* Description        : What is due over a milestone date window, what can legitimately be collected and what cannot
*                      with the reason attached, plus the countdown to the 20:00 Dubai cut-off for the date being sent.
* Usage              : Direct Debit app, Collections tab
* Created By         : Modon
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           Prateek Bansal              23 Aug 2026     Initial version
* 1.1           Prateek Bansal              24 Aug 2026     Console palette, cut-off countdown
* 1.2           Karunakar                   16 Sep 2026     Project filter, so a day can be collected
*                                                           one project at a time
* 1.3           Karunakar                   18 Sep 2026     Installment, sales order, unit, milestone
*                                                           and payment status columns
* 1.4           Karunakar                   18 Sep 2026     Start/end date window, mandatory project,
*                                                           phase and sales order filters, reason
*                                                           column restored, export to Excel
* 1.5           Karunakar                   18 Sep 2026     Sales order is a list of the project's own
*                                                           uncancelled sales orders, not a text box.
*                                                           Export downloads for real - a detached
*                                                           anchor never fired.
* 1.6           Karunakar                   18 Sep 2026     The export button is no longer bound to a
*                                                           disabled attribute. On a native button
*                                                           that reads as permanently disabled, so
*                                                           the click never reached the handler.
* 1.7           Karunakar                   18 Sep 2026     The export blob is application/octet-stream:
*                                                           LWS refuses text/csv outright. Falls back
*                                                           to a data URI if the blob is refused too.
* 1.8           Karunakar                   18 Sep 2026     Cut-off countdown, past-cut-off banner and
*                                                           the milestone-date-span check are off this
*                                                           screen. A row carrying a reason for not
*                                                           eligibility cannot be ticked.
* 1.9           Karunakar                   20 Sep 2026     Receipt excess amount and PDC columns:
*                                                           money already sitting against the
*                                                           installment, with the receipt it came
*                                                           from, so nobody debits a customer who
*                                                           has already paid.
* 1.10          Karunakar                   22 Sep 2026     Customer name column, from the mandate's
*                                                           CustomerAccountName__c - whose account
*                                                           the debit will actually hit.
* 1.11          Karunakar                   28 Sep 2026     DD Owner Name column from the mandate's
*                                                           CustomerAccountName__c; Customer name is
*                                                           now the sales order's customer account.
******************************************************************************************************************/
import { LightningElement, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';

import getDue from '@salesforce/apex/UAEDDS_LWCController.getDue';
import getProjects from '@salesforce/apex/UAEDDS_LWCController.getProjects';
import getPhases from '@salesforce/apex/UAEDDS_LWCController.getPhases';
import getSalesOrders from '@salesforce/apex/UAEDDS_LWCController.getSalesOrders';
import getRecentFiles from '@salesforce/apex/UAEDDS_LWCController.getRecentFiles';
import submitCollectionFile from '@salesforce/apex/UAEDDS_LWCController.submitCollectionFile';
import refreshFile from '@salesforce/apex/UAEDDS_LWCController.refreshFile';

// Every column carries its own width and wraps, rather than being left to the datatable to size.
// Auto sizing divides whatever width the table happens to have between the columns, so on a narrow
// screen a fourteen-column table gives each one a sliver and every value ends in an ellipsis - a
// half-shown unit name or DDA reference is the wrong record picked. Fixed widths plus wrapText make
// a long value taller instead of shorter, and the table scrolls sideways for the rest.
const COLUMNS = [
    // What the row is first, then what the bank arrangement behind it is. An operator picking rows
    // out of a window recognises the unit and the sales order long before the mandate number.
    { label: 'SOI name', fieldName: 'installmentName', type: 'text', wrapText: true, initialWidth: 190 },
    { label: 'Sales order', fieldName: 'salesOrderName', type: 'text', wrapText: true, initialWidth: 170 },
    // The sales order's customer, then the account holder named on the mandate. Whose account is
    // about to be debited is the one thing the other columns never say, and a mandate held in a
    // different name from the sales order is worth seeing before the file goes.
    { label: 'Customer name', fieldName: 'customerName', type: 'text', wrapText: true, initialWidth: 200 },
    { label: 'DD Owner Name', fieldName: 'ddOwnerName', type: 'text', wrapText: true, initialWidth: 200 },
    { label: 'Phase', fieldName: 'phaseName', type: 'text', wrapText: true, initialWidth: 150 },
    { label: 'Unit', fieldName: 'unitName', type: 'text', wrapText: true, initialWidth: 150 },
    { label: 'Mandate', fieldName: 'mandateName', type: 'text', wrapText: true, initialWidth: 160 },
    { label: 'DDA reference', fieldName: 'ddaRefNo', type: 'text', wrapText: true, initialWidth: 160 },
    { label: 'Milestone date', fieldName: 'dueDate', type: 'date-local', wrapText: true, initialWidth: 140 },
    {
        label: 'Milestone no.',
        fieldName: 'milestoneNumber',
        type: 'number',
        typeAttributes: { maximumFractionDigits: 0 },
        cellAttributes: { alignment: 'left' },
        wrapText: true,
        initialWidth: 130
    },
    // The installment's own value beside the amount that would actually be claimed. A part-paid row
    // claims its balance, so the two differing is the thing worth seeing rather than a duplication.
    {
        label: 'Installment amount',
        fieldName: 'installmentAmount',
        type: 'currency',
        typeAttributes: { currencyCode: 'AED' },
        cellAttributes: { alignment: 'right' },
        wrapText: true,
        initialWidth: 160
    },
    {
        label: 'Amount',
        fieldName: 'amount',
        type: 'currency',
        typeAttributes: { currencyCode: 'AED' },
        cellAttributes: { alignment: 'right' },
        wrapText: true,
        initialWidth: 150
    },
    // Money already recorded against the installment, which is the thing worth knowing before
    // debiting the customer again. Text rather than currency columns because each one carries the
    // receipt it came from as well as the amount, and a name beside the number is what lets an
    // operator go and look at it. Both are blank for the ordinary row that has no receipts.
    {
        label: 'Receipt excess amount',
        fieldName: 'excessReceipt',
        type: 'text',
        wrapText: true,
        initialWidth: 200
    },
    {
        label: 'PDC',
        fieldName: 'pdcReceipt',
        type: 'text',
        wrapText: true,
        initialWidth: 200
    },
    { label: 'Payment status', fieldName: 'paymentStatus', type: 'text', wrapText: true, initialWidth: 150 },
    // The reason a row cannot be collected sits in the table rather than behind a filter, so a
    // payment that should have gone and did not is visible on the same screen as the ones that did.
    {
        label: 'Reason for not eligibility',
        fieldName: 'problem',
        type: 'text',
        wrapText: true,
        initialWidth: 260
    }
];

// Same sizing as the collection table, for the same reason: a payment file name is long enough to
// be truncated to uselessness, and it is the one thing on this row anybody reads. The action column
// is left unsized - it holds a single menu button and the datatable sizes that itself.
const FILE_COLUMNS = [
    { label: 'File', fieldName: 'name', type: 'text', wrapText: true, initialWidth: 280 },
    { label: 'Status', fieldName: 'status', type: 'text', wrapText: true, initialWidth: 140 },
    { label: 'Rows', fieldName: 'recordCount', type: 'number', wrapText: true, initialWidth: 110 },
    {
        label: 'Total',
        fieldName: 'totalAmount',
        type: 'currency',
        typeAttributes: { currencyCode: 'AED' },
        wrapText: true,
        initialWidth: 160
    },
    { label: 'Uploaded', fieldName: 'uploadDate', type: 'date', wrapText: true, initialWidth: 180 },
    {
        type: 'action',
        typeAttributes: { rowActions: [{ label: 'Refresh from the bank', name: 'refresh' }] }
    }
];

// Blank rather than a sentinel string, so the value the screen holds is the value the Apex method
// treats as "no phase" and nothing has to be translated on the way out. There is no equivalent for
// the project: that one is mandatory and starts empty only so the screen can ask for it.
const ALL_PHASES = { label: 'All phases', value: '' };
const ALL_SALES_ORDERS = { label: 'All sales orders', value: '' };

export default class UaeddsCollectionScreen extends NavigationMixin(LightningElement) {
    startDate = this.today();
    endDate = this.tomorrow();
    projectName = '';
    phaseName = '';
    salesOrderName = '';

    columns = COLUMNS;
    fileColumns = FILE_COLUMNS;

    projectOptions = [];
    phaseOptions = [ALL_PHASES];
    salesOrderOptions = [ALL_SALES_ORDERS];
    loadedProject = '';
    rows = [];
    files = [];
    selectedIds = [];
    canSend = false;
    loaded = false;
    loading = false;

    connectedCallback() {
        // No load here any more. The project is mandatory, so there is nothing to ask the server
        // for until one is chosen - the recent files are still worth showing while that happens.
        this.loadFiles();
        // The minute timer that drove the cut-off countdown went with it. Nothing on this screen
        // changes with the clock now, so repainting on one would be work for no reader.
    }

    /**
     * The project list is reference data, so it is wired rather than loaded with the window - a
     * project added while the screen is open does not change what is due.
     */
    @wire(getProjects)
    wiredProjects({ data, error }) {
        if (data) {
            this.projectOptions = data;
        } else if (error) {
            this.projectOptions = [];
            this.toast('Projects not loaded', this.readError(error), 'warning');
        }
    }

    /**
     * The phases of whichever project is chosen. Re-wired when projectName changes, so the phase box
     * can never offer a phase belonging to a different project. A failure leaves the filter on All
     * phases rather than blocking: the window is still collectable unfiltered by phase.
     */
    @wire(getPhases, { projectName: '$projectName' })
    wiredPhases({ data, error }) {
        if (data) {
            this.phaseOptions = [ALL_PHASES, ...data];
        } else if (error) {
            this.phaseOptions = [ALL_PHASES];
            this.toast('Phases not loaded', this.readError(error), 'warning');
        }
    }

    /**
     * The sales orders under the chosen project, narrowed again by phase when one is picked so the
     * list offers only what the screen is already showing. Cancelled ones are left out server side -
     * choosing one could only ever produce an empty table.
     */
    @wire(getSalesOrders, { projectName: '$projectName', phaseName: '$phaseName' })
    wiredSalesOrders({ data, error }) {
        if (data) {
            this.salesOrderOptions = [ALL_SALES_ORDERS, ...data];
        } else if (error) {
            this.salesOrderOptions = [ALL_SALES_ORDERS];
            this.toast('Sales orders not loaded', this.readError(error), 'warning');
        }
    }

    // ------------------------------------------------------------------ cut-off

    /**
     * The rows currently ticked, as row objects rather than ids. The datatable hands back only ids
     * on reload, so the selection is resolved against this.rows rather than kept as a second copy
     * that could drift from it.
     */
    get selectedRows() {
        const chosen = new Set(this.selectedIds);
        return this.rows.filter((r) => chosen.has(r.installmentId));
    }

    // No cut-off countdown, past-cut-off banner or milestone-date-span check on this screen any
    // more. The 20:00 Dubai deadline is still enforced where it decides anything - prepare() refuses
    // a past-cut-off file server side before a payment file exists - and the home page still shows
    // the countdown for tomorrow's collection. What is gone is the screen refusing to let a
    // selection be made in the first place.

    // ------------------------------------------------------------------ dates

    // Built from local parts rather than toISOString. A Dubai user before 04:00 is still on
    // yesterday in UTC, so the ISO slice would hand them today when they asked for tomorrow.
    isoOf(d) {
        const pad = (n) => String(n).padStart(2, '0');
        return d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate());
    }

    today() {
        return this.isoOf(new Date());
    }

    tomorrow() {
        const d = new Date();
        d.setDate(d.getDate() + 1);
        return this.isoOf(d);
    }

    // ------------------------------------------------------------------ loading

    get canLoad() {
        return !!this.projectName && !!this.endDate;
    }

    get needsProject() {
        return !this.projectName;
    }

    load() {
        // Guarded rather than disabled-only: handleDateChange and the rest all end here, and the
        // server refuses a blank project anyway. This keeps that refusal from reaching the user as
        // an error toast for something they simply have not filled in yet.
        if (!this.canLoad) {
            this.rows = [];
            this.selectedIds = [];
            this.loaded = false;
            return;
        }
        this.loading = true;
        this.selectedIds = [];

        Promise.all([
            getDue({
                startDate: this.startDate,
                endDate: this.endDate,
                projectName: this.projectName,
                phaseName: this.phaseName,
                salesOrderName: this.salesOrderName
            }),
            getRecentFiles()
        ])
            .then(([due, files]) => {
                this.rows = (due.rows || []).map((r) => this.withReceipts(r));
                // The project the rows actually came back for, not the one now in the combobox.
                // They are the same once a load settles, and the empty message has to describe the
                // filter that produced the empty list rather than a newer selection.
                this.loadedProject = due.projectName;
                this.canSend = due.canSend;
                // Everything collectable is ticked to start with. Sending the whole window is the
                // normal case; leaving one out should be a deliberate act.
                this.selectedIds = this.rows.filter((r) => r.collectable).map((r) => r.installmentId);
                this.files = files || [];
                this.loaded = true;
            })
            .catch((error) => {
                this.toast('Not loaded', this.readError(error), 'error', 'sticky');
            })
            .finally(() => {
                this.loading = false;
            });
    }

    // The recent files panel does not depend on the filter, so it is loaded on its own before a
    // project is chosen - a file stuck on Submitting is worth seeing immediately.
    loadFiles() {
        getRecentFiles()
            .then((files) => {
                this.files = files || [];
            })
            .catch(() => {
                // Deliberately quiet. The files panel is context, and a toast about it on page load
                // would sit in front of the screen the user actually came for.
            });
    }

    /**
     * The two receipt columns, built from the name and amount the server sends separately.
     *
     * A copy rather than an edit in place: rows that come back from Apex are frozen, so assigning
     * to one silently fails in some browsers and throws in others. The copy also keeps the export
     * working, since it reads whatever is on the row object by fieldName.
     *
     * A row with no receipt against it gets an empty string rather than 'AED 0.00'. A zero in a
     * money column reads as a finding, and a blank cell is what "nothing here" should look like.
     */
    withReceipts(row) {
        return {
            ...row,
            excessReceipt: this.receiptText(row.excessReceiptName, row.excessAmount),
            pdcReceipt: this.receiptText(row.pdcReceiptName, row.pdcAmount)
        };
    }

    receiptText(name, amount) {
        if (!name) {
            return '';
        }
        return amount === null || amount === undefined
            ? name
            : `${name} - ${this.money(amount)}`;
    }

    money(amount) {
        try {
            return new Intl.NumberFormat('en-AE', {
                style: 'currency',
                currency: 'AED'
            }).format(amount);
        } catch (e) {
            // Formatting is presentation, so a locale the browser will not take should not cost
            // the number itself. AED in front of the plain value still reads correctly.
            return `AED ${amount}`;
        }
    }

    // ------------------------------------------------------------------ derived

    get hasRows() {
        return this.rows.length > 0;
    }

    get nothingDue() {
        return this.loaded && !this.loading && this.rows.length === 0;
    }

    // Nothing due in the whole window and nothing due on one project are different findings, and
    // the second one is worth naming - otherwise a filter left on from an earlier look reads as a
    // quiet week and nobody thinks to widen it.
    get emptyMessage() {
        return this.loadedProject
            ? `Nothing is due in this window for ${this.loadedProject}.`
            : 'Nothing is due in this window.';
    }

    get hasFiles() {
        return this.files.length > 0;
    }

    get hasStuckFile() {
        return this.files.some((f) => f.status === 'Submitting');
    }

    get collectableCount() {
        return this.rows.filter((r) => r.collectable).length;
    }

    get summary() {
        const refused = this.rows.length - this.collectableCount;
        if (refused === 0) {
            return `${this.collectableCount} due, all collectable.`;
        }
        return `${this.collectableCount} collectable, ${refused} refused - see Reason for not eligibility.`;
    }

    get noAccess() {
        return this.loaded && !this.canSend;
    }

    get sendLabel() {
        return `Send ${this.selectedIds.length} for collection`;
    }

    get cannotSend() {
        return this.loading || !this.canSend || this.selectedIds.length === 0;
    }

    // Says what would actually be taken. "Export to Excel" beside a half-ticked table leaves the
    // reader guessing whether they are about to get their selection or the lot.
    get exportLabel() {
        return this.selectedIds.length > 0
            ? `Export ${this.selectedIds.length} selected`
            : `Export all ${this.rows.length}`;
    }

    // ------------------------------------------------------------------ handlers

    handleStartDateChange(event) {
        this.startDate = event.target.value;
        this.load();
    }

    handleEndDateChange(event) {
        this.endDate = event.target.value;
        this.load();
    }

    handleProjectChange(event) {
        this.projectName = event.detail.value;
        // Both belong to the old project and cannot belong to the new one, so they are cleared
        // rather than carried across - the wires refill the lists a moment later. Leaving either in
        // place would filter the new project by a phase or sales order it has never heard of, and
        // the screen would read as an empty project rather than a stale filter.
        this.phaseName = '';
        this.salesOrderName = '';
        this.load();
    }

    handlePhaseChange(event) {
        this.phaseName = event.detail.value;
        // Same reasoning one level down: the sales order list is narrowed by phase, so a sales order
        // chosen under the previous phase is not in the new list.
        this.salesOrderName = '';
        this.load();
    }

    handleSalesOrderChange(event) {
        this.salesOrderName = event.detail.value;
        this.load();
    }

    handleReload() {
        this.load();
    }

    /**
     * A row carrying a Reason for not eligibility cannot be ticked.
     *
     * Enforced here rather than by a disabled attribute on the checkbox, because lightning-datatable
     * has no per-row way to disable one - the select-all box would tick them regardless. So the
     * selection is filtered on its way in and written back, which un-ticks anything ineligible the
     * moment it is ticked, select-all included.
     *
     * The rows stay on screen rather than being filtered out of the table. A payment that should
     * have gone and did not is exactly what nobody notices, and the reason beside it is the whole
     * point of showing it.
     */
    handleSelection(event) {
        const picked = event.detail.selectedRows.map((r) => r.installmentId);
        const allowed = picked.filter((id) => {
            const row = this.rows.find((r) => r.installmentId === id);
            return row && row.collectable;
        });

        this.selectedIds = allowed;
        if (allowed.length < picked.length) {
            const refused = picked.length - allowed.length;
            this.toast(
                'Not selectable',
                `${refused} ${refused === 1 ? 'row has' : 'rows have'} a reason for not eligibility ` +
                    `and cannot be sent. ${refused === 1 ? 'It has' : 'They have'} been left unticked.`,
                'warning'
            );
        }
    }

    handleSend() {
        this.loading = true;
        submitCollectionFile({
            installmentIds: this.selectedIds,
            startDate: this.startDate,
            endDate: this.endDate,
            projectName: this.projectName
        })
            .then((fileId) => {
                this.toast(
                    'Sent',
                    `${this.selectedIds.length} payments are on their way to UAEDDS.`,
                    'success'
                );
                this.load();
                this[NavigationMixin.Navigate]({
                    type: 'standard__recordPage',
                    attributes: {
                        recordId: fileId,
                        objectApiName: 'DDA_Payment_File__c',
                        actionName: 'view'
                    }
                });
            })
            .catch((error) => {
                this.toast('Not sent', this.readError(error), 'error', 'sticky');
                this.loading = false;
            });
    }

    handleFileAction(event) {
        const fileId = event.detail.row.id;
        this.loading = true;
        refreshFile({ fileId })
            .then((message) => {
                this.toast('Done', message, 'success');
                this.load();
            })
            .catch((error) => {
                this.toast('Not refreshed', this.readError(error), 'error', 'sticky');
                this.loading = false;
            });
    }

    // ------------------------------------------------------------------ export

    /**
     * The table as a spreadsheet. Exports what is ticked, falling back to everything on screen when
     * nothing is - somebody who has just loaded a window and wants it in Excel has not selected
     * anything yet, and an empty file would be the least useful possible answer.
     *
     * CSV rather than a real .xlsx: Excel opens it natively, and the alternative is a binary writer
     * library on a screen whose job is to send payments. The columns and their order are taken from
     * COLUMNS, so a column added to the table appears in the export without a second edit.
     */
    handleExport() {
        // Guarded here rather than by a disabled attribute on the button - see the template for why
        // binding disabled on a native button silently killed this handler.
        const exported = this.selectedRows.length > 0 ? this.selectedRows : this.rows;
        if (this.loading || exported.length === 0) {
            this.toast('Nothing to export', 'Tick the rows you want, or load a window first.', 'warning');
            return;
        }

        const header = COLUMNS.map((c) => this.csvCell(c.label)).join(',');
        const body = exported
            .map((row) => COLUMNS.map((c) => this.csvCell(row[c.fieldName])).join(','))
            .join('\r\n');

        try {
            // The BOM is what makes Excel read the file as UTF-8. Without it an Arabic unit name or
            // a non-breaking space arrives as mojibake, which looks like corrupted data rather than
            // an encoding default.
            this.download('﻿' + header + '\r\n' + body, this.exportFileName());
            this.toast('Exported', `${exported.length} rows downloaded.`, 'success');
        } catch (e) {
            // Surfaced rather than swallowed. A download that fails silently is indistinguishable
            // from one that never ran, which is what made this take three attempts to place.
            this.toast('Export failed', e && e.message ? e.message : String(e), 'error', 'sticky');
        }
    }

    csvCell(value) {
        if (value === null || value === undefined) {
            return '';
        }
        // Quoted unconditionally. A reason for not eligibility contains commas and full stops, and
        // deciding per value which ones need quoting is how one row silently shifts a column.
        return '"' + String(value).replace(/"/g, '""') + '"';
    }

    exportFileName() {
        const safe = (s) => String(s || '').replace(/[^A-Za-z0-9-]+/g, '-').replace(/^-|-$/g, '');
        const parts = ['collections', safe(this.projectName), this.startDate, 'to', this.endDate];
        return parts.filter((p) => p).join('-') + '.csv';
    }

    /**
     * A Blob and an object URL rather than a data: URI, and an anchor that is actually in the
     * document rather than a detached one.
     *
     * Both halves matter. A detached anchor's click() is ignored by the browser, so the earlier
     * version silently did nothing. And a data: URI carries the whole file in the URL, which a few
     * hundred rows is enough to push past the browser's URL ceiling - so it would have started
     * failing on exactly the large exports worth taking.
     */
    download(text, fileName) {
        const link = document.createElement('a');
        link.download = fileName;
        link.style.visibility = 'hidden';

        let objectUrl;
        try {
            // application/octet-stream, not text/csv. Lightning Web Security vets the MIME type on
            // Blob and createObjectURL and refuses a good many of them - text/csv among them, with
            // "Unsupported MIME type". octet-stream is the neutral "just bytes" type and is the one
            // it does allow. Excel still opens the file, because that is decided by the .csv on the
            // end of the name rather than by the type the bytes arrived under.
            objectUrl = URL.createObjectURL(
                new Blob([text], { type: 'application/octet-stream' })
            );
            link.href = objectUrl;
        } catch (e) {
            // If LWS refuses that too, carry the file in the href itself and skip Blob entirely.
            // No MIME check applies on this path. The download attribute makes this a download
            // rather than a navigation, so Chrome's block on navigating to data: does not bite -
            // the ceiling here is URL length, which only very large exports would reach.
            link.href = 'data:text/csv;charset=utf-8,' + encodeURIComponent(text);
        }

        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
        if (objectUrl) {
            // Released on the next tick rather than immediately: revoking it in the same frame as
            // the click can cancel the download before the browser has read the blob.
            setTimeout(() => URL.revokeObjectURL(objectUrl), 0);
        }
    }

    // ------------------------------------------------------------------ helpers

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