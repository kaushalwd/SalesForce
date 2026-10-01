import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import Toast from 'lightning/toast';

import getEditableAccount from '@salesforce/apex/MBP_BrokerAgencyInformationController.getEditableAccount';
import shouldShowBrokerContent from '@salesforce/apex/MBP_BrokerAgencyInformationController.shouldShowBrokerContent';
import getCommissionData from '@salesforce/apex/MBP_CommissionTreeCustomController.getCommissionData';
import getPicklistValues from '@salesforce/apex/MBP_CommissionTreeCustomController.getPicklistValues';
import rejectCommissionWithComments from '@salesforce/apex/MBP_CommissionInvoicePDFController.rejectCommissionWithComments';
import savePDFtoCommissionLine from '@salesforce/apex/MBP_CommissionInvoicePDFController.savePDFtoCommissionLine';
import hasBrokerVAT from '@salesforce/apex/MBP_CommissionInvoicePDFController.hasBrokerVAT';
import isTradeLicenseMandatory from '@salesforce/apex/MBP_CommissionInvoicePDFController.isTradeLicenseMandatory';
import isSupplierAndBankSynced from '@salesforce/apex/MBP_CommissionInvoicePDFController.isSupplierAndBankSynced';

const PAGE_SIZE = 10;
/* Column help tooltip. Width is fixed in px and MUST match
.head-tip in the CSS - the clamp maths below needs a known width to keep
   the tip inside.commission-content. */
const HEAD_TIP_WIDTH = 272;
/* Gap from the header cell's bottom edge to the tip box. The caret takes the
   top HEAD_TIP_CARET px of it, so the point lands 1px below the header row. */
const HEAD_TIP_GAP = 7;
const HEAD_TIP_CARET = 6;
/* Keeps the caret off the tip's rounded corners when the tip is clamped. */
const HEAD_TIP_CARET_INSET = 14;
/* Horizontal breathing room between the tip and the card edge. */
const HEAD_TIP_EDGE = 8;
const HEAD_TIP_MIN_WIDTH = 1024;
const AUTHORIZED_BROKER_TYPES = new Set(['Owner', 'Agency Admin']);
/* Own-invoice upload limits, matching the legacy component exactly. */
const OWN_INVOICE_MAX_BYTES = 2 * 1024 * 1024;
const OWN_INVOICE_ACCEPT = '.pdf,.jpg,.jpeg,.png';
/* Broker-facing copy for the Fusion/OIC sync gate. Matches MODON_UAT's
   mbp_BrokercommissionDetails, reworded there on 2026-08-30 to name banking
   details and a contact address instead of internal terms ("supplier
   details", "Fusion team", "Broker Management Team").

   NOT identical to MBP_CommissionInvoicePDFController.OIC_NOT_SYNCED_MESSAGE,
   which still carries the older wording in every org - UAT changed the LWC
   copy only. Apex hard-gates the same condition inside savePDFtoCommissionLine
   regardless, so this copy exists to say it before the round trip, and the
   difference is cosmetic. */
const OIC_NOT_SYNCED_MESSAGE =
    'Your banking details are currently not synced with the payment system. Please reach out to broker@modon.com for further assistance.';

/* Why a row that is not 'Ready To Process' cannot be acted on, so the
   view-only drawer explains itself instead of showing a bare PDF. Copy is
   verbatim from the legacy mbp_BrokercommissionDetails routing.

   'Rejected' is new: legacy had no branch for it, so its modal never opened
   for a rejected row. The copy names no status label of its own, so the
   backend value stays the source of truth. Tone mirrors getStatusTone so
   the notice and the badge always match. */
const NOTICE_VALIDATING = {
    tone: 'warning',
    heading: 'Under review',
    text:
        'Your commission information is currently being validated by our Broker Management Team. Please wait until the review is completed.'
};
const NOTICE_UNDER_APPROVAL = {
    tone: 'warning',
    heading: 'Submitted for approval',
    text:
        'Your invoice has been submitted successfully and is currently under approval. Our team will review and process it shortly.'
};
const NOTICE_DEPOSITED = {
    tone: 'success',
    heading: 'Payment released',
    text:
        'Your commission payment has been successfully deposited into your registered bank account.'
};
const NOTICE_REJECTED = {
    tone: 'error',
    heading: 'Sent back for review',
    text:
        'This commission was rejected with your comments and has returned to our Broker Management Team for review.'
};
const STATUS_NOTICES = {
    'Not Reviewed': NOTICE_VALIDATING,
    'Internal Review In-Progress': NOTICE_VALIDATING,
    'Re-Calculated': NOTICE_VALIDATING,
    'In Progress': NOTICE_VALIDATING,
    'Pending Invoice Verification': NOTICE_UNDER_APPROVAL,
    'Pending Finance Verification': NOTICE_UNDER_APPROVAL,
    Completed: NOTICE_DEPOSITED,
    'Completed - Partially': NOTICE_DEPOSITED,
    Rejected: NOTICE_REJECTED
};

/* Broker-facing status vocabulary. The SPA and Commission Status columns
   showed raw picklist values, which are internal language: a broker cannot
   read "SPA Signed (Modon)" and know whether to act.

   Presentation only. The raw value still drives filtering, routing, tones and
   everything Apex reads and writes. Same approach as the lead status alias in
   mbpr_homeGateway.

   SPA collapses eight stored values to four. Tone travels with the label
   rather than being derived from the raw value, so two rows both reading
   "Cancelled" cannot render in different colours. */
const SPA_DISPLAY = {
    'SPA Not Generated': { label: 'Not issued', tone: 'muted' },
    'SPA Generated': { label: 'In progress', tone: 'warning' },
    'Pending with Customer': { label: 'In progress', tone: 'warning' },
    'Pending for Validation': { label: 'In progress', tone: 'warning' },
    'Pending with Modon': { label: 'In progress', tone: 'warning' },
    'SPA Signed (Modon)': { label: 'Completed', tone: 'success' },
    Cancelled: { label: 'Cancelled', tone: 'error' },
    'SPA Voided': { label: 'Cancelled', tone: 'error' }
};

/* Filter dropdown order for the four SPA states - the natural progression of
   the document, not alphabetical. Anything unmapped sorts after them. */
const SPA_BUCKET_ORDER = ['Not issued', 'In progress', 'Completed', 'Cancelled'];

/* Only the two values the broker acts on are renamed. Business parked the
   wider rename, so nothing else in this column moves. */
const COMMISSION_STATUS_LABELS = {
    'Ready To Process': 'Not submitted',
    'Pending Invoice Verification': 'Submitted',
    /* Business 2026-08-31, option B of the clarification: the stage AFTER Modon
       has verified the invoice, where payment is being released. Option A
       (Pending Invoice Verification) was rejected because it already reads
       "Submitted" and one status cannot carry both words. */
    'Pending Finance Verification': 'Payment in Progress'
};

function commissionStatusLabel(rawStatus) {
    return COMMISSION_STATUS_LABELS[rawStatus] || rawStatus || 'Not Available';
}

/* A row the broker must act on reads "Not submitted", but the only way in
   was to click the row and find Accept at the bottom of the drawer. The
   button now names the action, so the path reads Not submitted, Submit
   invoice, Submitted.

   It runs the same openInvoice handler as before. Opening the row is what
   chooses between the three submission paths, so a button that submitted
   directly would bypass that routing and could self-bill an agency that must
   not be. This highlights the entrance; it is not a second way in. */
const INVOICE_ACTION_SUBMIT = 'Submit invoice';
const INVOICE_ACTION_VIEW = 'View Invoice';

function invoiceActionFor(isReadyToProcess) {
    return {
        label: isReadyToProcess ? INVOICE_ACTION_SUBMIT : INVOICE_ACTION_VIEW,
        className: isReadyToProcess
            ? 'view-invoice-button view-invoice-button--submit'
            : 'view-invoice-button'
    };
}

/* Resolves a stored SPA value to what the broker sees. tone is null for an
   unmapped value, so the caller keeps its keyword-derived tone; bucket is
   what the filter and sort compare on, so rows reading the same group. */
function spaDisplay(rawStatus) {
    const mapped = SPA_DISPLAY[rawStatus];
    if (mapped) return { label: mapped.label, tone: mapped.tone, bucket: mapped.label };
    if (rawStatus) return { label: rawStatus, tone: null, bucket: rawStatus };
    return { label: 'Not Available', tone: null, bucket: '' };
}
const CURRENCY_FORMATTER = new Intl.NumberFormat('en-US', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2
});
const WHOLE_NUMBER_FORMATTER = new Intl.NumberFormat('en-US', {
    minimumFractionDigits: 0,
    maximumFractionDigits: 0
});
const DATE_FORMATTER = new Intl.DateTimeFormat('en-GB', {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
    timeZone: 'UTC'
});

export default class MbprCommissionsWorkspace extends LightningElement {
    @api brokerType = '';

    isInitializing = true;
    isLoading = false;
    isActionPending = false;
    accessResolved = false;
    accessError = '';
    loadError = '';
    filterError = '';
    effectiveBrokerType = '';
    brokerContentAllowed = false;
    accountInfo = null;
    canAcceptCommission = false;

    /* Agency-level gates from MBP_CommissionInvoicePDFController. None vary per
       commission line, so they resolve once at init and again when an invoice
       is opened, which is when the routing decision is made.
         hasBrokerVat      - agency holds a VAT certificate and UAE VAT number,
                             so it gets the self-billing invoice.
         thresholdExceeded - completed sales at or above AED 375,000 (the Apex
                             method is named isTradeLicenseMandatory).
         fusionSynced      - OIC bank and supplier pushes both report Success. */
    hasBrokerVat = false;
    thresholdExceeded = false;
    fusionSynced = false;
    gatesResolved = false;

    commissions = [];
    filteredCommissions = [];
    statusOptions = [];
    downPaymentOptions = [];
    spaOptions = [];

    filterOpen = false;
    draftFilters = this.createDefaultFilters();
    appliedFilters = this.createDefaultFilters();

    currentPage = 1;
    sortBy = '';
    sortDirection = 'asc';
    expandedCommissionIds = [];

    headTipText = '';
    headTipOn = false;
    headTipX = 0;
    headTipY = 0;
    headTipCaretX = HEAD_TIP_WIDTH / 2;

    invoiceOpen = false;
    invoiceLoading = false;
    selectedCommissionId = '';
    taxInvoiceDraft = '';
    commentsDraft = '';
    taxInvoiceDraftError = false;
    commentsDraftError = false;
    _invoicePdfRequestSequence = 0;

    confirmationOpen = false;
    pendingAction = '';
    pendingActionPayload = null;

    /* block. Agency-level, so it carries no commission id - only the
       unit the broker clicked, for context. */
    thresholdBlockOpen = false;
    thresholdUnitName = '';
    _thresholdOpener = null;
    _thresholdFocusPending = false;

    /* own-invoice upload, for a non-VAT agency below the threshold.
       Error flags are separate booleans rather than one object because LWC
       tracks reassignment, not nested mutation. */
    ownInvoiceOpen = false;
    ownInvoiceCommissionId = '';
    ownInvoiceUnitName = '';
    ownInvoiceNumber = '';
    ownInvoiceDate = '';
    ownInvoiceFileName = '';
    ownInvoiceNumberError = false;
    ownInvoiceDateError = false;
    ownInvoiceFileError = false;
    ownInvoiceSubmitting = false;
    _ownInvoiceFile = null;
    _ownInvoiceOpener = null;
    _ownInvoiceFocusPending = false;

    _loadSequence = 0;
    _confirmationFocusPending = false;
    _confirmationOpener = null;

    connectedCallback() {
        this.initializeWorkspace();
    }

    renderedCallback() {
        if (this.ownInvoiceOpen && this._ownInvoiceFocusPending) {
            const firstField = this.template.querySelector('.invoice-upload .invoice-field input');
            if (firstField) {
                firstField.focus();
                this._ownInvoiceFocusPending = false;
            }
        }

        if (this.thresholdBlockOpen && this._thresholdFocusPending) {
            const thresholdPrimary = this.template.querySelector(
                '.threshold-block .confirmation__action--primary'
            );
            if (thresholdPrimary) {
                thresholdPrimary.focus();
                this._thresholdFocusPending = false;
            }
        }

        if (!this.confirmationOpen || !this._confirmationFocusPending) return;
        /* Scoped to the confirmation dialog: the threshold block reuses the
           same action classes, so an unscoped query could focus the wrong one. */
        const primaryButton = this.template.querySelector(
            '.confirmation:not(.threshold-block) .confirmation__action--primary'
        );
        if (primaryButton) {
            primaryButton.focus();
            this._confirmationFocusPending = false;
        }
    }

    async initializeWorkspace() {
        this.isInitializing = true;
        this.accessError = '';
        this.accessResolved = false;
        try {
            const [result, brokerContentAllowed] = await Promise.all([
                getEditableAccount(),
                shouldShowBrokerContent()
            ]);
            this.accountInfo = result && result.account ? result.account : null;
            this.effectiveBrokerType = (result && result.brokerType) || '';
            this.brokerContentAllowed = brokerContentAllowed === true;
            this.canAcceptCommission = Boolean(
                this.accountInfo && this.accountInfo.Bank_Account_Number__c
            );
            this.accessResolved = true;

            if (!this.isAuthorized) return;

            await Promise.all([
                this.loadPicklistOptions(),
                this.loadCommissionData(),
                this.resolveCommissionGates()
            ]);
        } catch (error) {
            this.accessError = this.reduceError(error) || 'Unable to verify commission access.';
        } finally {
            this.isInitializing = false;
        }
    }

    /* Resolves the three gates together. Each degrades to its safest value on
       failure: no VAT, so no unsubstantiated self-billing invoice; threshold
       not exceeded, so a transient failure never blocks a legitimate
       acceptance; not synced, which Apex refuses anyway. Never rethrown, so a
       failure here cannot break the listing. */
    async resolveCommissionGates() {
        const settled = await Promise.all([
            hasBrokerVAT().catch(() => null),
            isTradeLicenseMandatory().catch(() => null),
            isSupplierAndBankSynced().catch(() => null)
        ]);
        const [vat, threshold, synced] = settled;
        this.hasBrokerVat = vat === true;
        this.thresholdExceeded = threshold === true;
        this.fusionSynced = synced === true;
        this.gatesResolved = settled.every((value) => value !== null);
    }

    async loadPicklistOptions() {
        try {
            const result = await getPicklistValues();
            this.statusOptions = this.normalizeOptions(result && result.status);
            this.downPaymentOptions = this.normalizeOptions(result && result.downPaymentStatus);
            this.spaOptions = this.normalizeOptions(result && result.spaStatus);
        } catch (error) {
            // Commission data remains usable if optional filter metadata fails.
            this.statusOptions = [];
            this.downPaymentOptions = [];
            this.spaOptions = [];
        }
    }

    async loadCommissionData() {
        if (!this.isAuthorized) return;

        const requestSequence = ++this._loadSequence;
        this.isLoading = true;
        this.loadError = '';
        try {
            const data = await getCommissionData({
                startDateStr: this.appliedFilters.startDate,
                endDateStr: this.appliedFilters.endDate
            });
            if (requestSequence !== this._loadSequence) return;

            const records = Array.isArray(data) ? data : [];
            if (records.length && typeof records[0].canAcceptCommission === 'boolean') {
                this.canAcceptCommission = records[0].canAcceptCommission;
            }
            this.commissions = records.map((record, index) => this.mapCommission(record, index));
            this.applyClientFilters();
        } catch (error) {
            if (requestSequence !== this._loadSequence) return;
            this.loadError = this.reduceError(error) || 'Unable to load commissions.';
        } finally {
            if (requestSequence === this._loadSequence) this.isLoading = false;
        }
    }

    mapCommission(record, index) {
        const status = this.cleanValue(record && record.status);
        const downPaymentStatus = this.cleanValue(record && record.downPaymentStatus);
        const spaStatus = this.cleanValue(record && record.spaStatus);
        const spa = spaDisplay(spaStatus);
        /* ADM and Dari fees payment status, shown as stored. Business chose
           the fees field over registration status because it shares Down
           Payment's vocabulary, so "Paid" reads as a broker expects.

           Two orgs expose the same value under different property names:
           BRKRPRTL returns `admStatus` from Sales_Order__r.ADM_Fees_and_Dari__c,
           while BPDEV returns `admFeeStatus` from the Commission_Line formula
           ADM_Fee_Status__c = TEXT(Sales_Order__r.ADM_Fees_and_Dari__c) - the
           same field, reached a different way. Accept either, so the column
           populates wherever this component is deployed. */
        const admStatus = this.cleanValue(record && (record.admStatus ?? record.admFeeStatus));
        const invoiceDateRaw = this.cleanValue(record && record.invoiceDate);
        const clearanceDateRaw = (record && record.clearanceDate) || '';
        const unitPrice = this.toNumber(record && record.totalunitprice);
        const totalCommission = this.toNumber(record && record.totalCommission);
        const paidAmount = this.toNumber(record && record.paidAmount);
        const pendingAmount = this.toNumber(record && record.pendingAmount);
        const currentPayout = this.toNumber(record && record.currentPayout);
        const futureEligibleAmount = this.toNumber(record && record.futureEligibleAmount);
        const id = this.cleanValue(record && record.commissionId) || `commission-${index}`;

        return {
            Id: id,
            ProjectName: this.cleanValue(record && record.project),
            UnitName: this.cleanValue(record && record.unitNumber),
            Agent: this.cleanValue(record && record.brokerAgent),
            CustomerName: this.cleanValue(record && record.customerName),
            CommissionPercent: this.cleanValue(record && record.commissionPercent),
            CommissionAmount: this.formatNumber(totalCommission),
            CommissionAmountRaw: totalCommission,
            TotalCommissionPaid: this.formatNumber(paidAmount),
            TotalCommissionPaidRaw: paidAmount,
            CommissionPending: this.formatNumber(pendingAmount),
            CommissionPendingRaw: pendingAmount,
            CommissionPayoutNow: this.formatNumber(currentPayout),
            CommissionPayoutNowRaw: currentPayout,
            RemainingPayout: this.formatNumber(futureEligibleAmount),
            RemainingPayoutRaw: futureEligibleAmount,
            unitprice: this.formatWholeNumber(unitPrice),
            unitpriceRaw: unitPrice,
            StatusLabel: commissionStatusLabel(status),
            StatusTone: this.getStatusTone(status),
            StatusFilterValue: status,
            DownPaymentStatus: downPaymentStatus,
            DownPaymentStatusLabel: downPaymentStatus || 'Not Available',
            DownPaymentTone: this.getStatusTone(downPaymentStatus),
            AdmStatus: admStatus,
            AdmStatusLabel: admStatus || 'Not Available',
            AdmTone: this.getStatusTone(admStatus),
            SpaStatus: spaStatus,
            /* An unmapped value falls through to the previous behaviour, raw
               label and keyword-derived tone, so a new SPA status can never
               render blank. The filter and sort key off SpaBucket, so both
               group by what the broker sees. */
            SpaStatusLabel: spa.label,
            SpaTone: spa.tone || this.getStatusTone(spaStatus),
            SpaBucket: spa.bucket,
            InvoiceDate: this.formatDate(invoiceDateRaw),
            InvoiceDateRaw: invoiceDateRaw,
            /* When Modon actually cleared the payout. Blank until it happens,
               which is most rows. Apex already returned this; nothing rendered
               it until now. Sorting keys off the raw ISO string, which orders
               correctly as text, and empties sort together. */
            ClearanceDate: this.formatDateTime(clearanceDateRaw),
            ClearanceDateRaw: clearanceDateRaw || '',
            TaxInvoiceNumber: this.cleanValue(record && record.taxInvoiceNumber),
            isReadyToProcess: status === 'Ready To Process',
            invoiceActionLabel: invoiceActionFor(status === 'Ready To Process').label,
            invoiceActionClass: invoiceActionFor(status === 'Ready To Process').className
        };
    }

    /* Re-stamps a row's status locally after a successful action.

       getCommissionData is cacheable and the post-action reload passes the same
       dates, so the client serves the pre-action list from cache and the row
       keeps its old status even though the save succeeded. Applied after the
       reload so it wins either way.

       Derives every status-dependent field the way mapCommission does, so the
       tone, the filter value and the notice stay in step. */
    applyLocalStatus(commissionId, status, taxInvoiceNumber) {
        let changed = false;
        this.commissions = this.commissions.map((commission) => {
            if (commission.Id !== commissionId) return commission;
            changed = true;
            return {
                ...commission,
                StatusLabel: commissionStatusLabel(status),
                StatusTone: this.getStatusTone(status),
                StatusFilterValue: status,
                isReadyToProcess: status === 'Ready To Process',
                /* Re-derived here too: without this the row would read
                   "Submitted" while its button still offered "Submit
                   invoice". */
                invoiceActionLabel: invoiceActionFor(status === 'Ready To Process').label,
                invoiceActionClass: invoiceActionFor(status === 'Ready To Process').className,
                TaxInvoiceNumber: taxInvoiceNumber
                    ? this.cleanValue(taxInvoiceNumber)
                    : commission.TaxInvoiceNumber
            };
        });
        if (changed) this.applyClientFilters();
    }

    applyClientFilters() {
        const filters = this.appliedFilters;
        const unitSearch = (filters.unitSearchTerm || '').trim().toLowerCase();

        this.filteredCommissions = this.commissions.filter((commission) => {
            const unitMatches =
                !unitSearch || (commission.UnitName || '').toLowerCase().includes(unitSearch);
            const statusMatches =
                !filters.statusFilter || commission.StatusFilterValue === filters.statusFilter;
            const downPaymentMatches =
                !filters.downPaymentFilter || commission.DownPaymentStatus === filters.downPaymentFilter;
            /* Compares the bucket, not the stored value: picking "In progress"
               must return all four stored statuses that read that way. */
            const spaMatches = !filters.spaFilter || commission.SpaBucket === filters.spaFilter;
            const invoiceDateMatches =
                !commission.InvoiceDateRaw ||
                ((!filters.startDate || commission.InvoiceDateRaw >= filters.startDate) &&
                    (!filters.endDate || commission.InvoiceDateRaw <= filters.endDate));

            return unitMatches && statusMatches && downPaymentMatches && spaMatches && invoiceDateMatches;
        });

        this.currentPage = 1;
        this.expandedCommissionIds = [];
    }

    handleFilterInput(event) {
        const name = event.target.name;
        if (!name) return;
        this.draftFilters = {
            ...this.draftFilters,
            [name]: event.target.value || ''
        };
        this.filterError = '';
    }

    handleSearchKeydown(event) {
        if (event.key !== 'Enter') return;
        event.preventDefault();
        this.applyFilters();
    }

    async applyFilters() {
        if (
            this.draftFilters.startDate &&
            this.draftFilters.endDate &&
            this.draftFilters.startDate > this.draftFilters.endDate
        ) {
            this.filterError = 'End Date must be on or after Start Date.';
            return;
        }

        this.filterError = '';
        this.appliedFilters = { ...this.draftFilters };
        this.filterOpen = false;
        await this.loadCommissionData();
    }

    async resetFilters() {
        const defaults = this.createDefaultFilters();
        this.draftFilters = { ...defaults };
        this.appliedFilters = { ...defaults };
        this.filterError = '';
        this.filterOpen = false;
        await this.loadCommissionData();
    }

    handleRemoveFilter(event) {
        const name = event.currentTarget.dataset.name;
        if (!name) return;
        this.draftFilters = { ...this.draftFilters, [name]: '' };
        this.appliedFilters = { ...this.appliedFilters, [name]: '' };
        this.applyClientFilters();
    }

    toggleFilterPanel() {
        this.filterOpen = !this.filterOpen;
        this.filterError = '';
    }

    closeFilterPanel() {
        this.filterOpen = false;
        this.filterError = '';
        this.draftFilters = { ...this.appliedFilters };
    }

    handleSort(event) {
        const field = event.currentTarget.dataset.field;
        if (!field) return;
        if (this.sortBy === field) {
            this.sortDirection = this.sortDirection === 'asc' ? 'desc' : 'asc';
        } else {
            this.sortBy = field;
            this.sortDirection = 'asc';
        }
        this.currentPage = 1;
    }

    handleNextPage() {
        if (!this.isNextDisabled) {
            this.currentPage += 1;
            this.resetListScroll();
        }
    }

    handlePrevPage() {
        if (!this.isPrevDisabled) {
            this.currentPage -= 1;
            this.resetListScroll();
        }
    }

    /* Paging drops the reader back at the top of the list on every screen
       size (same rule as the units workspace pagination). */
    resetListScroll() {
        requestAnimationFrame(() => {
            const content = this.template.querySelector('.commission-content');
            if (content && typeof content.scrollIntoView === 'function') {
                content.scrollIntoView({ behavior: 'auto', block: 'start' });
            }
        });
    }

    toggleCommissionCard(event) {
        const id = event.currentTarget.dataset.id;
        if (!id) return;
        if (this.expandedCommissionIds.includes(id)) {
            this.expandedCommissionIds = this.expandedCommissionIds.filter((value) => value !== id);
        } else {
            this.expandedCommissionIds = [...this.expandedCommissionIds, id];
        }
    }

    openInvoice(event) {
        const id = event.currentTarget.dataset.id;
        if (!id) return;

        /* Non-VAT agencies are diverted away from the self-billing PDF; see
           resolveRowRoute. These are the two cases where routing replaces the
           view rather than gating the action. */
        const route = this.resolveRowRoute(id);
        if (route === 'threshold') {
            this.openThresholdBlock(id, event.currentTarget);
            return;
        }
        if (route === 'upload') {
            this.openOwnInvoice(id, event.currentTarget);
            return;
        }

        this.selectedCommissionId = id;
        this.taxInvoiceDraft = '';
        this.commentsDraft = '';
        this.taxInvoiceDraftError = false;
        this.commentsDraftError = false;
        this.invoiceLoading = true;
        this.invoiceOpen = true;

        /* Re-read the gates as the drawer opens: VAT details or a Fusion sync
           may have changed since page load. Not awaited, so the PDF frame
           starts loading immediately; the gates are only consulted on action. */
        this.resolveCommissionGates();
    }

    /* Which experience a row opens into.

       A non-VAT agency never sees the self-billing PDF: Apex only generates it
       when isVatUndertakingFlow is false, so showing it would present a
       document that does not exist. Above the threshold they are blocked;
       below it they upload their own invoice. Everything else keeps the
       invoice drawer.

       Requires gatesResolved, so a failed gate call falls back to the drawer
       rather than diverting the broker on unknown data. */
    resolveRowRoute(commissionId) {
        const commission = this.commissions.find((item) => item.Id === commissionId);
        if (!commission || !commission.isReadyToProcess) return 'invoice';
        if (!this.gatesResolved || this.hasBrokerVat) return 'invoice';
        return this.thresholdExceeded ? 'threshold' : 'upload';
    }

    isThresholdBlocked(commissionId) {
        return this.resolveRowRoute(commissionId) === 'threshold';
    }

    openThresholdBlock(commissionId, opener) {
        const commission = this.commissions.find((item) => item.Id === commissionId);
        this.thresholdUnitName = (commission && commission.UnitName) || '';
        this._thresholdOpener = opener || null;
        this.thresholdBlockOpen = true;
        this._thresholdFocusPending = true;
    }

    closeThresholdBlock() {
        this.thresholdBlockOpen = false;
        this.thresholdUnitName = '';
        this._thresholdFocusPending = false;
        const opener = this._thresholdOpener;
        this._thresholdOpener = null;
        if (opener && typeof opener.focus === 'function') {
            window.setTimeout(() => opener.focus(), 0);
        }
    }

    /* Hands the broker to My Agency, where the VAT certificate is maintained.
       Legacy hardcoded a UAT community URL here, which would send a BP_DEV
       user to the wrong org. */
    handleUpdateAgencyDetails() {
        this.thresholdBlockOpen = false;
        this.thresholdUnitName = '';
        this._thresholdOpener = null;
        this.dispatchEvent(
            new CustomEvent('openutilitypanel', {
                detail: { panel: 'myagency' },
                bubbles: true,
                composed: true
            })
        );
    }

    // ------------------------------------------------------------------
    // - own-invoice upload (non-VAT agency below AED 375,000)
    // ------------------------------------------------------------------

    get ownInvoiceEyebrow() {
        return this.ownInvoiceUnitName ? `Commissions · Unit ${this.ownInvoiceUnitName}` : 'Commissions';
    }

    get ownInvoiceAccept() {
        return OWN_INVOICE_ACCEPT;
    }

    get ownInvoiceNumberFieldClass() {
        return this.ownInvoiceNumberError
            ? 'invoice-field invoice-field--own-number invoice-field--error'
            : 'invoice-field invoice-field--own-number';
    }

    get ownInvoiceDateFieldClass() {
        return this.ownInvoiceDateError
            ? 'invoice-field invoice-field--own-date invoice-field--error'
            : 'invoice-field invoice-field--own-date';
    }

    get ownInvoiceDropClass() {
        return this.ownInvoiceFileError
            ? 'invoice-upload__drop invoice-upload__drop--error'
            : 'invoice-upload__drop';
    }

    /* The own-invoice equivalent of fusionBlocked. It cannot reuse that getter:
       fusionBlocked reads selectedCommission, which belongs to the invoice
       DRAWER and is not set on this path. The three gates are agency-level, not
       per row, and resolveRowRoute only routes here for a row that is already
       Ready To Process with gates resolved - so the agency-level answer is the
       whole test. */
    get ownInvoiceFusionBlocked() {
        return this.gatesResolved && !this.fusionSynced;
    }

    get isOwnInvoiceSubmitDisabled() {
        return this.ownInvoiceSubmitting || this.ownInvoiceFusionBlocked;
    }

    get ownInvoiceSubmitLabel() {
        return this.ownInvoiceSubmitting ? 'Submitting…' : 'Submit invoice';
    }

    openOwnInvoice(commissionId, opener) {
        const commission = this.commissions.find((item) => item.Id === commissionId);
        this.ownInvoiceCommissionId = commissionId;
        this.ownInvoiceUnitName = (commission && commission.UnitName) || '';
        this.ownInvoiceNumber = '';
        this.ownInvoiceDate = '';
        this.ownInvoiceFileName = '';
        this.ownInvoiceNumberError = false;
        this.ownInvoiceDateError = false;
        this.ownInvoiceFileError = false;
        this.ownInvoiceSubmitting = false;
        this._ownInvoiceFile = null;
        this._ownInvoiceOpener = opener || null;
        this.ownInvoiceOpen = true;
        this._ownInvoiceFocusPending = true;

        /* Same reason the invoice drawer re-reads on open (see openInvoice):
           a Fusion sync may have completed since page load, and this modal now
           renders the sync notice and gates its own submit button. Not awaited
           - the modal opens immediately and the notice appears as soon as the
           gates answer. */
        this.resolveCommissionGates();
    }

    closeOwnInvoice() {
        /* Never abandon a submission mid-flight: the record may already have
           moved to Pending Invoice Verification. */
        if (this.ownInvoiceSubmitting) return;
        this.ownInvoiceOpen = false;
        this.ownInvoiceCommissionId = '';
        this.ownInvoiceUnitName = '';
        this.ownInvoiceNumber = '';
        this.ownInvoiceDate = '';
        this.ownInvoiceFileName = '';
        this.ownInvoiceNumberError = false;
        this.ownInvoiceDateError = false;
        this.ownInvoiceFileError = false;
        this._ownInvoiceFile = null;
        this._ownInvoiceFocusPending = false;
        const opener = this._ownInvoiceOpener;
        this._ownInvoiceOpener = null;
        if (opener && typeof opener.focus === 'function') {
            window.setTimeout(() => opener.focus(), 0);
        }
    }

    handleOwnInvoiceNumber(event) {
        this.ownInvoiceNumber = event.target.value;
        if (this.ownInvoiceNumber.trim()) this.ownInvoiceNumberError = false;
    }

    handleOwnInvoiceDate(event) {
        this.ownInvoiceDate = event.target.value;
        if (this.ownInvoiceDate) this.ownInvoiceDateError = false;
    }

    handleOwnInvoiceFile(event) {
        const input = event.target;
        const file = input.files && input.files[0];
        /* The input is cleared on every path so re-picking the same file still
           fires a change event, exactly as the legacy component does. */
        if (!file) {
            input.value = null;
            return;
        }
        if (file.size > OWN_INVOICE_MAX_BYTES) {
            this.ownInvoiceFileError = true;
            this.showToast('File too large.', 'The invoice document must not exceed 2 MB.', 'error');
            input.value = null;
            return;
        }
        this._ownInvoiceFile = file;
        this.ownInvoiceFileName = file.name;
        this.ownInvoiceFileError = false;
        input.value = null;
    }

    clearOwnInvoiceFile() {
        this._ownInvoiceFile = null;
        this.ownInvoiceFileName = '';
    }

    readFileAsBase64(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = () => {
                const result = String(reader.result || '');
                const comma = result.indexOf(',');
                if (comma < 0) {
                    reject(new Error('The selected file could not be read.'));
                    return;
                }
                resolve(result.slice(comma + 1));
            };
            reader.onerror = () => reject(new Error('The selected file could not be read.'));
            reader.readAsDataURL(file);
        });
    }

    async submitOwnInvoice() {
        if (this.ownInvoiceSubmitting) return;

        const invoiceNumber = this.ownInvoiceNumber.trim();
        const invoiceDate = this.ownInvoiceDate;
        this.ownInvoiceNumberError = !invoiceNumber;
        this.ownInvoiceDateError = !invoiceDate;
        this.ownInvoiceFileError = !this._ownInvoiceFile;
        if (this.ownInvoiceNumberError || this.ownInvoiceDateError || this.ownInvoiceFileError) {
            /* Static selectors on purpose: invoice-field--error is only applied
               on the next render, so a selector keyed on it would match
               nothing at this point. */
            if (this.ownInvoiceNumberError) {
                this.focusInvoiceField('.invoice-field--own-number input');
            } else if (this.ownInvoiceDateError) {
                this.focusInvoiceField('.invoice-field--own-date input');
            } else {
                this.focusInvoiceField('.invoice-upload__input');
            }
            return;
        }

        const commissionLineId = this.ownInvoiceCommissionId;
        if (!commissionLineId) return;

        this.ownInvoiceSubmitting = true;
        try {
            /* Re-checked here as well as at open, matching the legacy
               component: the sync state can change while the form is filled
               in. Apex enforces it too, so a failed check defers to Apex. */
            const synced = await isSupplierAndBankSynced().catch(() => true);
            if (synced !== true) {
                this.ownInvoiceSubmitting = false;
                this.showToast('Invoice not submitted.', OIC_NOT_SYNCED_MESSAGE, 'error');
                return;
            }

            const invoiceFileData = await this.readFileAsBase64(this._ownInvoiceFile);

            await this.submitCommissionInvoice({
                commissionLineId,
                comments: '',
                invoiceNumber,
                invoiceDate,
                invoiceFileName: this._ownInvoiceFile.name,
                invoiceFileData,
                isVatUndertakingFlow: true
            });

            /* Cleared before the reload so the modal cannot be re-submitted
               against a record that has already moved on. */
            this.ownInvoiceSubmitting = false;
            this.ownInvoiceOpen = false;
            this.ownInvoiceCommissionId = '';
            this._ownInvoiceFile = null;
            this.ownInvoiceFileName = '';
            this.showToast('Invoice submitted successfully.', '', 'success');
            await this.loadCommissionData();
            this.applyLocalStatus(commissionLineId, 'Pending Invoice Verification', invoiceNumber);
        } catch (error) {
            this.ownInvoiceSubmitting = false;
            this.showToast('Invoice not submitted.', this.reduceError(error), 'error');
        }
    }

    handleOwnInvoiceKeydown(event) {
        event.stopPropagation();
        if (event.key === 'Escape') {
            event.preventDefault();
            this.closeOwnInvoice();
            return;
        }
        if (event.key !== 'Tab') return;

        const dialog = this.template.querySelector('.invoice-upload');
        if (!dialog) return;
        const focusable = Array.from(
            dialog.querySelectorAll('button:not([disabled]), input:not([disabled])')
        );
        if (!focusable.length) return;
        const first = focusable[0];
        const last = focusable[focusable.length - 1];
        const active = this.template.activeElement;
        if (event.shiftKey && active === first) {
            event.preventDefault();
            last.focus();
        } else if (!event.shiftKey && active === last) {
            event.preventDefault();
            first.focus();
        }
    }

    handleThresholdKeydown(event) {
        event.stopPropagation();
        if (event.key === 'Escape') {
            event.preventDefault();
            this.closeThresholdBlock();
            return;
        }
        if (event.key !== 'Tab') return;

        const dialog = this.template.querySelector('.threshold-block');
        if (!dialog) return;
        const focusable = Array.from(dialog.querySelectorAll('button:not([disabled])'));
        if (!focusable.length) return;
        const first = focusable[0];
        const last = focusable[focusable.length - 1];
        const active = this.template.activeElement;
        if (event.shiftKey && active === first) {
            event.preventDefault();
            last.focus();
        } else if (!event.shiftKey && active === last) {
            event.preventDefault();
            first.focus();
        }
    }

    closeInvoice() {
        if (this.isActionPending) return;
        this.closeConfirmation();
        this.invoiceOpen = false;
        this.invoiceLoading = false;
        this.selectedCommissionId = '';
    }

    handleInvoiceFrameLoad() {
        this.invoiceLoading = false;
    }

    handleTaxInvoiceInput(event) {
        this.taxInvoiceDraft = event.target.value;
        if (this.taxInvoiceDraft.trim()) this.taxInvoiceDraftError = false;
    }

    handleCommentsInput(event) {
        this.commentsDraft = event.target.value;
        if (this.commentsDraft.trim()) this.commentsDraftError = false;
    }

    focusInvoiceField(selector) {
        const field = this.template.querySelector(selector);
        if (field && typeof field.focus === 'function') field.focus();
    }

    handleAcceptRequest(event) {
        /* Defensive: the drawer is not reachable for a threshold-blocked row,
           but if the gates resolve to blocked while a drawer is already open,
           acceptance must still turn into the block rather than a submission. */
        if (this.isThresholdBlocked(this.selectedCommissionId)) {
            const opener = event && event.currentTarget;
            this.invoiceOpen = false;
            this.invoiceLoading = false;
            const blockedId = this.selectedCommissionId;
            this.selectedCommissionId = '';
            this.openThresholdBlock(blockedId, opener);
            return;
        }

        if (!this.selectedCommissionReady || this.isAcceptDisabled) {
            if (!this.canAcceptCommission) {
                this.showToast(
                    'Bank details are missing.',
                    'Please update your bank details to proceed with commission acceptance.',
                    'warning'
                );
            }
            return;
        }

        /* Same required rules the legacy VF page enforced, now inline:
           tax invoice number required only while the record has none;
           comments optional on accept. */
        const selected = this.selectedCommission;
        let taxInvoiceNumber = (selected && selected.TaxInvoiceNumber) || '';
        if (!taxInvoiceNumber) {
            taxInvoiceNumber = this.taxInvoiceDraft.trim();
            if (!taxInvoiceNumber) {
                this.taxInvoiceDraftError = true;
                this.focusInvoiceField('.invoice-field--tax input');
                return;
            }
        }
        this.openConfirmation(
            'accept',
            { taxInvoiceNumber, comments: this.commentsDraft.trim() },
            event.currentTarget
        );
    }

    handleRejectRequest(event) {
        if (!this.selectedCommissionReady || this.isRejectDisabled) return;

        const comments = this.commentsDraft.trim();
        if (!comments) {
            this.commentsDraftError = true;
            this.focusInvoiceField('.invoice-field--comments textarea');
            return;
        }
        this.openConfirmation('reject', { comments }, event.currentTarget);
    }

    openConfirmation(action, payload, opener) {
        this.pendingAction = action;
        this.pendingActionPayload = payload;
        this._confirmationOpener = opener || null;
        this.confirmationOpen = true;
        this._confirmationFocusPending = true;
    }

    closeConfirmation() {
        if (this.isActionPending) return;
        this.confirmationOpen = false;
        this.pendingAction = '';
        this.pendingActionPayload = null;
        this._confirmationFocusPending = false;
        const opener = this._confirmationOpener;
        this._confirmationOpener = null;
        if (opener && typeof opener.focus === 'function') {
            window.setTimeout(() => opener.focus(), 0);
        }
    }

    /* Single entry point for savePDFtoCommissionLine. All seven parameters are
       passed explicitly so the call never depends on LWC's omitted-parameter
       behaviour, and the two submission paths differ only in their values:

         isVatUndertakingFlow false - Modon generates and attaches the
             self-billing PDF and Apex stamps Invoice_Date__c with today.
         isVatUndertakingFlow true  - no PDF; the broker's own document is
             attached and the supplied invoice date kept.

       Apex writes invoiceNumber only when non-blank, sets Status__c to
       'Pending Invoice Verification' and submits for approval, so a resolved
       promise means the record has moved on and the listing must reload. */
    submitCommissionInvoice({
        commissionLineId,
        comments = '',
        invoiceNumber = '',
        invoiceDate = null,
        invoiceFileName = null,
        invoiceFileData = null,
        isVatUndertakingFlow = false
    }) {
        return savePDFtoCommissionLine({
            commissionLineId,
            comments,
            invoiceNumber,
            invoiceDate,
            invoiceFileName,
            invoiceFileData,
            isVatUndertakingFlow
        });
    }

    async confirmPendingAction() {
        if (!this.pendingAction || !this.selectedCommissionId || this.isActionPending) return;

        const action = this.pendingAction;
        const payload = this.pendingActionPayload || {};
        const commissionLineId = this.selectedCommissionId;
        this.confirmationOpen = false;
        this._confirmationFocusPending = false;
        this.isActionPending = true;

        try {
            if (action === 'accept') {
                /* Re-checked at the action boundary: the sync state can change
                   between opening the drawer and confirming. Apex enforces it
                   too, but checking here turns a raw exception into a message. */
                const synced = await isSupplierAndBankSynced().catch(() => true);
                if (synced !== true) {
                    this.showToast('Invoice not submitted.', OIC_NOT_SYNCED_MESSAGE, 'error');
                    return;
                }
                await this.submitCommissionInvoice({
                    commissionLineId,
                    comments: payload.comments || '',
                    invoiceNumber: payload.taxInvoiceNumber || ''
                });
                this.showToast('Invoice submitted for approval.', '', 'success');
            } else {
                const result = await rejectCommissionWithComments({
                    commissionLineId,
                    comments: payload.comments || ''
                });
                if (result !== 'SUCCESS') throw new Error(result || 'Unable to reject commission.');
                this.showToast('Commission rejected successfully.', '', 'success');
            }

            this.invoiceOpen = false;
            this.invoiceLoading = false;
            this.selectedCommissionId = '';
            await this.loadCommissionData();
            this.applyLocalStatus(
                commissionLineId,
                action === 'accept' ? 'Pending Invoice Verification' : 'Rejected',
                action === 'accept' ? payload.taxInvoiceNumber : ''
            );
        } catch (error) {
            const fallbackTitle = action === 'accept' ? 'Invoice not submitted.' : 'Commission not rejected.';
            this.showToast(fallbackTitle, this.reduceError(error), 'error');
        } finally {
            this.isActionPending = false;
            this.pendingAction = '';
            this.pendingActionPayload = null;
            this._confirmationOpener = null;
        }
    }

    handleConfirmationKeydown(event) {
        event.stopPropagation();
        if (event.key === 'Escape') {
            event.preventDefault();
            this.closeConfirmation();
            return;
        }
        if (event.key !== 'Tab') return;

        const dialog = this.template.querySelector('.confirmation');
        if (!dialog) return;
        const focusable = Array.from(dialog.querySelectorAll('button:not([disabled])'));
        if (!focusable.length) return;
        const first = focusable[0];
        const last = focusable[focusable.length - 1];
        const active = this.template.activeElement;
        if (event.shiftKey && active === first) {
            event.preventDefault();
            last.focus();
        } else if (!event.shiftKey && active === last) {
            event.preventDefault();
            first.focus();
        }
    }

    stopPropagation(event) {
        event.stopPropagation();
    }

    handleRetryAccess() {
        this.initializeWorkspace();
    }

    handleRetryData() {
        this.loadCommissionData();
    }

    get isAuthorized() {
        return (
            this.accessResolved &&
            this.brokerContentAllowed &&
            AUTHORIZED_BROKER_TYPES.has(this.effectiveBrokerType)
        );
    }

    get showNoAccess() {
        return this.accessResolved && !this.isAuthorized;
    }

    get hasAccessError() {
        return Boolean(this.accessError);
    }

    get showInitialLoading() {
        return this.isInitializing || (this.isLoading && !this.commissions.length);
    }

    get showNoCommissions() {
        return !this.isLoading && !this.loadError && !this.filteredCommissions.length;
    }

    get hasCommissionRows() {
        return this.filteredCommissions.length > 0;
    }

    /* Option text only; the value stays the stored picklist value, so filtering
       is unchanged. Without this the dropdown would read "Ready To Process"
       while the column it filters reads "Not submitted". */
    get statusOptionsWithAll() {
        return [
            { key: 'all-status', label: 'All', value: '' },
            ...this.statusOptions.map((option) => ({
                key: `status-${option.value}`,
                label: COMMISSION_STATUS_LABELS[option.value] || option.label,
                value: option.value
            }))
        ];
    }

    get downPaymentOptionsWithAll() {
        return [
            { key: 'all-down-payment', label: 'All', value: '' },
            ...this.downPaymentOptions.map((option) => ({ ...option, key: `down-payment-${option.value}` }))
        ];
    }

    /* Eight stored SPA values collapse to four, so the dropdown is deduped or it
       would list "In progress" four times. Options are still derived from the
       picklist Apex returns, so a value added later still appears under its
       raw name. The selected value is the bucket, matching SpaBucket. */
    get spaOptionsWithAll() {
        const seen = new Set();
        const buckets = [];
        this.spaOptions.forEach((option) => {
            const mapped = SPA_DISPLAY[option.value];
            const label = mapped ? mapped.label : option.label;
            const value = mapped ? mapped.label : option.value;
            if (!value || seen.has(value)) return;
            seen.add(value);
            buckets.push({ key: `spa-${value}`, label, value });
        });
        buckets.sort((left, right) => {
            const leftIndex = SPA_BUCKET_ORDER.indexOf(left.value);
            const rightIndex = SPA_BUCKET_ORDER.indexOf(right.value);
            return (leftIndex === -1 ? 99 : leftIndex) - (rightIndex === -1 ? 99 : rightIndex);
        });
        return [{ key: 'all-spa', label: 'All', value: '' }, ...buckets];
    }

    get activeFilterChips() {
        const chips = [];
        if (this.appliedFilters.unitSearchTerm) {
            chips.push({
                name: 'unitSearchTerm',
                label: `Unit Number: ${this.appliedFilters.unitSearchTerm}`
            });
        }
        if (this.appliedFilters.statusFilter) {
            /* The dropdown already relabels via COMMISSION_STATUS_LABELS, so a
               raw value here made the chip disagree with the option the broker
               just picked. */
            chips.push({
                name: 'statusFilter',
                label: `Status: ${commissionStatusLabel(this.appliedFilters.statusFilter)}`
            });
        }
        if (this.appliedFilters.downPaymentFilter) {
            chips.push({
                name: 'downPaymentFilter',
                label: `Down Payment Status: ${this.appliedFilters.downPaymentFilter}`
            });
        }
        if (this.appliedFilters.spaFilter) {
            chips.push({ name: 'spaFilter', label: `SPA Status: ${this.appliedFilters.spaFilter}` });
        }
        return chips;
    }

    get hasActiveFilterChips() {
        return this.activeFilterChips.length > 0;
    }

    get activeFilterCountLabel() {
        const count = this.activeFilterChips.length;
        return count ? `Filters (${count})` : 'Filters';
    }

    get filterPanelClass() {
        return this.filterOpen ? 'filter-panel filter-panel--open' : 'filter-panel';
    }

    get sortedCommissions() {
        const records = [...this.filteredCommissions];
        if (!this.sortBy) return records;

        records.sort((left, right) => {
            const leftValue = this.getSortValue(left, this.sortBy);
            const rightValue = this.getSortValue(right, this.sortBy);
            let comparison = 0;
            if (typeof leftValue === 'number' && typeof rightValue === 'number') {
                comparison = leftValue - rightValue;
            } else {
                comparison = String(leftValue || '').localeCompare(String(rightValue || ''), 'en', {
                    numeric: true,
                    sensitivity: 'base'
                });
            }
            return this.sortDirection === 'asc' ? comparison : comparison * -1;
        });
        return records;
    }

    get paginatedCommissions() {
        const start = (this.currentPage - 1) * PAGE_SIZE;
        return this.sortedCommissions.slice(start, start + PAGE_SIZE).map((commission, index) => {
            const isExpanded = this.expandedCommissionIds.includes(commission.Id);
            return {
                ...commission,
                serialNumber: start + index + 1,
                isExpanded,
                cardClass: isExpanded ? 'commission-card commission-card--open' : 'commission-card',
                expandedValue: isExpanded ? 'true' : 'false',
                expandLabel: isExpanded ? 'Collapse commission details' : 'Expand commission details'
            };
        });
    }

    get totalPages() {
        return Math.max(1, Math.ceil(this.filteredCommissions.length / PAGE_SIZE));
    }

    get isPrevDisabled() {
        return this.currentPage <= 1;
    }

    get isNextDisabled() {
        return this.currentPage >= this.totalPages;
    }

    get pageLabel() {
        return `Page ${this.currentPage} of ${this.totalPages}`;
    }

    get summaryCards() {
        const totals = this.filteredCommissions.reduce(
            (summary, commission) => ({
                total: summary.total + commission.CommissionAmountRaw,
                paid: summary.paid + commission.TotalCommissionPaidRaw,
                pending: summary.pending + commission.CommissionPendingRaw,
                current: summary.current + commission.CommissionPayoutNowRaw,
                future: summary.future + commission.RemainingPayoutRaw
            }),
            { total: 0, paid: 0, pending: 0, current: 0, future: 0 }
        );
        return [
            { key: 'total', label: 'Total Commission', value: this.formatCurrency(totals.total) },
            { key: 'paid', label: 'Paid Amount', value: this.formatCurrency(totals.paid) },
            { key: 'pending', label: 'Pending Amount', value: this.formatCurrency(totals.pending) }
            /* BP-068 (12 Sep 2026): MODON asked these tiles to read Total, Paid, Pending, the same
               three the dashboard card shows, and Eligible Amount to come off. Current Payout and
               Eligible Amount are HIDDEN, not removed - both are still totalled above and both keep
               their table columns, so pasting these two lines back restores the old row exactly.
            , { key: 'current', label: 'Current Payout', value: this.formatCurrency(totals.current) }
            , { key: 'future', label: 'Eligible Amount', value: this.formatCurrency(totals.future) } */
        ];
    }

    get selectedCommission() {
        return this.commissions.find((commission) => commission.Id === this.selectedCommissionId) || null;
    }

    get selectedCommissionReady() {
        return Boolean(this.selectedCommission && this.selectedCommission.isReadyToProcess);
    }

    get invoicePdfUrl() {
        /* Same-origin VF URL in renderAs=pdf mode, the exact document the
           download Apex prints. The community CSP blocks blob: and data:
           frames, so the native viewer must be fed same-origin. */
        return this.selectedCommissionId
            ? `/apex/CommissionInvoicePDF?commissionId=${encodeURIComponent(this.selectedCommissionId)}&renderAs=pdf`
            : '';
    }

    get showInvoiceFooter() {
        /* The footer only exists while it has content: a warning, a status
           notice, or the acceptance form and actions. With none of those the
           drawer is a pure PDF view. */
        return this.showBankWarning || this.selectedCommissionReady || this.hasStatusNotice;
    }

    /* Non-actionable rows keep the PDF view and gain an explanation. Rows that
       are Ready To Process are actionable, so they never carry a notice. */
    get statusNotice() {
        const selected = this.selectedCommission;
        if (!selected || selected.isReadyToProcess) return null;
        /* Keyed on the RAW status, not the broker-facing label. STATUS_NOTICES
           is declared with raw picklist keys, so every renamed status silently
           missed its notice: 'Pending Invoice Verification' reads "Submitted",
           and STATUS_NOTICES['Submitted'] is undefined. That row has been
           showing a bare PDF with no explanation since the vocabulary landed.
           Renaming a second status here would have extended the same fault. */
        return STATUS_NOTICES[selected.StatusFilterValue] || null;
    }

    get hasStatusNotice() {
        return Boolean(this.statusNotice);
    }

    get statusNoticeHeading() {
        const notice = this.statusNotice;
        return notice ? notice.heading : '';
    }

    get statusNoticeText() {
        const notice = this.statusNotice;
        return notice ? notice.text : '';
    }

    get statusNoticeClass() {
        const notice = this.statusNotice;
        return notice ? `invoice-notice invoice-notice--${notice.tone}` : 'invoice-notice';
    }

    /* An actionable row whose agency has not finished its Fusion sync. Apex
       refuses the submission anyway, so this just spares a doomed round trip.
       Gated on gatesResolved so a failed gate call never blocks acceptance. */
    get oicNotSyncedMessage() {
        return OIC_NOT_SYNCED_MESSAGE;
    }

    get fusionBlocked() {
        return this.selectedCommissionReady && this.gatesResolved && !this.fusionSynced;
    }

    get showTaxInvoiceInput() {
        const selected = this.selectedCommission;
        return this.selectedCommissionReady && Boolean(selected) && !selected.TaxInvoiceNumber;
    }

    get invoiceFormClass() {
        return this.showTaxInvoiceInput ? 'invoice-form invoice-form--split' : 'invoice-form';
    }

    get taxInvoiceFieldClass() {
        return this.taxInvoiceDraftError
            ? 'invoice-field invoice-field--tax invoice-field--error'
            : 'invoice-field invoice-field--tax';
    }

    get commentsFieldClass() {
        return this.commentsDraftError
            ? 'invoice-field invoice-field--comments invoice-field--error'
            : 'invoice-field invoice-field--comments';
    }

    get invoiceDrawerSubtitle() {
        const selected = this.selectedCommission;
        if (!selected) return '';
        return [selected.UnitName, selected.ProjectName].filter(Boolean).join(' · ');
    }

    get invoiceFrameTitle() {
        const selected = this.selectedCommission;
        return selected && selected.UnitName
            ? `Invoice for unit ${selected.UnitName}`
            : 'Commission invoice';
    }

    get bankDetailsMissing() {
        return !this.canAcceptCommission;
    }

    /* UAT never shows these two together: the bank warning lives in the
       self-billing modal and the status message in its own. The status notice
       matters more for a row that cannot be acted on, so it wins. */
    get showBankWarning() {
        return this.bankDetailsMissing && !this.hasStatusNotice;
    }

    get isAcceptDisabled() {
        return (
            this.isActionPending ||
            this.invoiceLoading ||
            !this.canAcceptCommission ||
            this.fusionBlocked
        );
    }

    get isRejectDisabled() {
        return this.isActionPending || this.invoiceLoading;
    }

    /* Names the row the broker clicked, so an agency-level block still reads
       as a reply to the specific action they took. */
    get thresholdEyebrow() {
        return this.thresholdUnitName ? `Commissions · Unit ${this.thresholdUnitName}` : 'Commissions';
    }

    get confirmationTitle() {
        return this.pendingAction === 'reject' ? 'Reject Invoice?' : 'Accept Invoice?';
    }

    get confirmationMessage() {
        return this.pendingAction === 'reject'
            ? 'The commission will be rejected with the comments entered in the invoice.'
            : 'The invoice will be submitted for approval using the details shown.';
    }

    get confirmationActionLabel() {
        return this.pendingAction === 'reject' ? 'Reject' : 'Accept';
    }

    get confirmationActionClass() {
        return this.pendingAction === 'reject'
            ? 'confirmation__action confirmation__action--primary confirmation__action--danger'
            : 'confirmation__action confirmation__action--primary';
    }

    get unitSortAria() {
        return this.getSortAria('UnitName');
    }

    get unitPriceSortAria() {
        return this.getSortAria('unitpriceRaw');
    }

    get invoiceDateSortAria() {
        return this.getSortAria('InvoiceDateRaw');
    }

    get clearanceDateSortAria() {
        return this.getSortAria('ClearanceDateRaw');
    }

    get projectSortAria() {
        return this.getSortAria('ProjectName');
    }

    get agentSortAria() {
        return this.getSortAria('Agent');
    }

    get customerSortAria() {
        return this.getSortAria('CustomerName');
    }

    get commissionAmountSortAria() {
        return this.getSortAria('CommissionAmountRaw');
    }

    get paidAmountSortAria() {
        return this.getSortAria('TotalCommissionPaidRaw');
    }

    get currentPayoutSortAria() {
        return this.getSortAria('CommissionPayoutNowRaw');
    }

    get futureEligibleSortAria() {
        return this.getSortAria('RemainingPayoutRaw');
    }

    get downPaymentSortAria() {
        return this.getSortAria('DownPaymentStatus');
    }

    get admSortAria() {
        return this.getSortAria('AdmStatus');
    }

    /* Sorts on the bucket, not the stored value - sorting by raw value would
       scatter the four rows that all read "In progress". */
    get spaSortAria() {
        return this.getSortAria('SpaBucket');
    }

    get commissionStatusSortAria() {
        return this.getSortAria('StatusLabel');
    }

    getSortValue(commission, field) {
        return commission && commission[field] != null ? commission[field] : '';
    }

    getSortAria(field) {
        if (this.sortBy !== field) return 'none';
        return this.sortDirection === 'asc' ? 'ascending' : 'descending';
    }

    createDefaultFilters() {
        const today = new Date();
        const year = today.getFullYear();
        return {
            unitSearchTerm: '',
            statusFilter: '',
            downPaymentFilter: '',
            spaFilter: '',
            startDate: `${year}-01-01`,
            endDate: this.toDateInputValue(today)
        };
    }

    normalizeOptions(options) {
        const seen = new Set();
        return (Array.isArray(options) ? options : [])
            .map((option) => ({
                label: this.cleanValue(option && option.label),
                value: this.cleanValue(option && option.value)
            }))
            .filter((option) => {
                if (!option.value || seen.has(option.value)) return false;
                seen.add(option.value);
                return true;
            });
    }

    /* Column help tooltip, hover and large screens only. Pointer events rather
       than mouseenter, so a touch device can be told apart via pointerType.
       The tip is clamped inside.commission-content, the nearest ancestor that
       does not clip;.commission-table-wrap scrolls and would cut it off. */

    get isLargeScreenForTips() {
        return (
            typeof window !== 'undefined' &&
            typeof window.matchMedia === 'function' &&
            window.matchMedia(`(min-width: ${HEAD_TIP_MIN_WIDTH}px)`).matches
        );
    }

    handleHeadTipEnter(event) {
        // Touch and pen taps also fire pointerenter; only a real mouse hover shows help.
        if (event.pointerType && event.pointerType !== 'mouse') return;
        if (!this.isLargeScreenForTips) return;

        const cell = event.currentTarget;
        const text = cell && cell.dataset ? cell.dataset.tip : '';
        if (!text) return;

        const anchor = this.template.querySelector('.commission-content');
        if (!anchor) return;

        const anchorRect = anchor.getBoundingClientRect();
        const cellRect = cell.getBoundingClientRect();
        const half = HEAD_TIP_WIDTH / 2;
        // Centre under the header, then hold the whole tip inside the anchor box.
        const minX = half + HEAD_TIP_EDGE;
        const maxX = Math.max(anchorRect.width - half - HEAD_TIP_EDGE, minX);
        const centre = cellRect.left - anchorRect.left + cellRect.width / 2;
        const tipX = Math.round(Math.min(Math.max(centre, minX), maxX));

        /* Placed against the header's real centre, not the tip's: the first and
           last columns clamp the tip inside the card, so a caret centred on the
           box would point at the wrong column. Measured from the tip's left
           edge and kept off its corners. */
        const caretX = centre - (tipX - half);

        this.headTipX = tipX;
        this.headTipCaretX = Math.round(
            Math.min(Math.max(caretX, HEAD_TIP_CARET_INSET), HEAD_TIP_WIDTH - HEAD_TIP_CARET_INSET)
        );
        this.headTipY = Math.round(cellRect.bottom - anchorRect.top + HEAD_TIP_GAP);
        this.headTipText = text;
        this.headTipOn = true;
    }

    handleHeadTipLeave() {
        this.headTipOn = false;
    }

    get headTipClass() {
        return this.headTipOn ? 'head-tip head-tip--on' : 'head-tip';
    }

    get headTipStyle() {
        return `left: ${this.headTipX}px; top: ${this.headTipY}px; --head-tip-caret: ${this.headTipCaretX}px;`;
    }

    get headTipHidden() {
        return this.headTipOn ? 'false' : 'true';
    }

    getStatusTone(status) {
        const value = this.cleanValue(status).toLowerCase();
        if (!value) return 'muted';
        if (
            value.includes('rejected') ||
            value.includes('cancelled') ||
            value.includes('failed') ||
            value.includes('expired')
        ) {
            return 'error';
        }
        if (
            value.includes('completed') ||
            value.includes('paid') ||
            value.includes('approved') ||
            value.includes('signed')
        ) {
            return 'success';
        }
        if (
            value.includes('ready') ||
            value.includes('pending') ||
            value.includes('progress') ||
            value.includes('generated') ||
            value.includes('submitted')
        ) {
            return 'warning';
        }
        return 'muted';
    }

    formatNumber(value) {
        return CURRENCY_FORMATTER.format(this.toNumber(value));
    }

    formatWholeNumber(value) {
        return WHOLE_NUMBER_FORMATTER.format(this.toNumber(value));
    }

    formatCurrency(value) {
        return `AED ${this.formatNumber(value)}`;
    }

    formatDate(value) {
        if (!value) return '-';
        const parsed = new Date(`${value}T00:00:00.000Z`);
        return Number.isNaN(parsed.getTime()) ? value : DATE_FORMATTER.format(parsed);
    }

    /* Broker_Commission_Clearence_Date__c is a Date/TIME, so the value arrives
       as a full ISO timestamp. formatDate above appends 'T00:00:00.000Z' for
       date-only fields and would produce an invalid date here, falling back to
       the raw ISO string. Parsed directly instead, then rendered with the same
       UTC-pinned DATE_FORMATTER every other date in this table uses, so the day
       shown never varies by the viewer's timezone. */
    formatDateTime(value) {
        if (!value) return '-';
        const parsed = new Date(value);
        return Number.isNaN(parsed.getTime()) ? value : DATE_FORMATTER.format(parsed);
    }

    toDateInputValue(date) {
        const year = date.getFullYear();
        const month = String(date.getMonth() + 1).padStart(2, '0');
        const day = String(date.getDate()).padStart(2, '0');
        return `${year}-${month}-${day}`;
    }

    toNumber(value) {
        const number = Number(value);
        return Number.isFinite(number) ? number : 0;
    }

    cleanValue(value) {
        return value == null ? '' : String(value).trim();
    }

    reduceError(error) {
        if (!error) return '';
        if (typeof error === 'string') return error;
        if (Array.isArray(error.body)) {
            return error.body.map((item) => item.message).filter(Boolean).join(', ');
        }
        if (error.body && error.body.message) return error.body.message;
        if (error.message) return error.message;
        return 'An unexpected error occurred.';
    }

    showToast(title, message, variant) {
        try {
            Toast.show({ label: title, message: message || '', mode: 'dismissible', variant }, this);
        } catch (error) {
            this.dispatchEvent(new ShowToastEvent({ title, message: message || '', mode: 'dismissible', variant }));
        }
    }
}