import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LightningConfirm from 'lightning/confirm';
import { getObjectInfo, getPicklistValues } from 'lightning/uiObjectInfoApi';
import CHECKOUT_PAYMENT_OBJECT from '@salesforce/schema/Checkout_Payment__c';
import STATUS_FIELD from '@salesforce/schema/Checkout_Payment__c.Status__c';
import getPayments from '@salesforce/apex/CheckoutPaymentConsoleController.getPayments';
import refreshStatus from '@salesforce/apex/CheckoutPaymentConsoleController.refreshStatus';
import capturePayment from '@salesforce/apex/CheckoutPaymentConsoleController.capturePayment';
import refundPayment from '@salesforce/apex/CheckoutPaymentConsoleController.refundPayment';
import voidPayment from '@salesforce/apex/CheckoutPaymentConsoleController.voidPayment';
import resendPaymentLink from '@salesforce/apex/CheckoutPaymentConsoleController.resendPaymentLink';
import regeneratePaymentLink from '@salesforce/apex/CheckoutPaymentConsoleController.regeneratePaymentLink';
import getPayableRecords from '@salesforce/apex/CheckoutPaymentConsoleController.getPayableRecords';
import createLinkFromRecord from '@salesforce/apex/CheckoutPaymentConsoleController.createLinkFromRecord';
import hasCheckoutActionsPerm from '@salesforce/customPermission/Checkout_Allow_Actions';

const PAGE_SIZE = 10;
const ALL_OPTION = { label: 'All', value: 'All' };

export default class CheckoutPaymentConsole extends LightningElement {
    @api recordId;
    status = 'All';
    days = '30';
    searchKey = '';
    pageNumber = 1;
    rows = [];
    loading = false;
    now = 0;

    get hasFullAccess() {
        return hasCheckoutActionsPerm;
    }

    // Create-link modal state
    showModal = false;
    modalStep = 1;
    sourceType;
    modalSearch = '';
    options = [];
    modalLoading = false;
    selected;
    creating = false;
    resultUrl;
    expirySeconds = '604800';
    captureMode = 'immediate';

    expiryOptions = [
        { label: '1 hour', value: '3600' },
        { label: '6 hours', value: '21600' },
        { label: '12 hours', value: '43200' },
        { label: '1 day', value: '86400' },
        { label: '3 days', value: '259200' },
        { label: '7 days', value: '604800' },
        { label: '14 days', value: '1209600' },
        { label: '30 days', value: '2592000' },
        { label: '60 days', value: '5184000' }
    ];
    captureOptions = [
        { label: 'Charge immediately', value: 'immediate' },
        { label: 'Authorize only (hold, capture later)', value: 'authorize' }
    ];

    // Read from the Status__c picklist itself, so a value added in Setup shows up here with no
    // code change. Starts as All-only and fills in when the wire returns.
    statusOptions = [ALL_OPTION];

    @wire(getObjectInfo, { objectApiName: CHECKOUT_PAYMENT_OBJECT })
    checkoutPaymentInfo;

    @wire(getPicklistValues, {
        recordTypeId: '$checkoutPaymentInfo.data.defaultRecordTypeId',
        fieldApiName: STATUS_FIELD
    })
    wiredStatusValues({ data, error }) {
        if (data) {
            this.statusOptions = [
                ALL_OPTION,
                ...data.values.map((entry) => ({ label: entry.label, value: entry.value }))
            ];
            return;
        }
        if (error) {
            // Leave the All option in place so the filter still works, just unnarrowed.
            this.statusOptions = [ALL_OPTION];
            this.toast('Error', 'Could not load payment statuses: ' + this.errorMessage(error), 'error');
        }
    }
    eoiStatusFilter = 'All';
    eoiStatusOptions = [
        { label: 'All', value: 'All' },
        { label: 'Pending Payment', value: 'Pending Payment' },
        { label: 'Paid', value: 'Paid' },
        { label: 'Expired', value: 'Expired' },
        { label: 'Refunded', value: 'Refunded' },
        { label: 'Declined', value: 'Declined' }
    ];
    dayOptions = [
        { label: 'Last 7 days', value: '7' },
        { label: 'Last 30 days', value: '30' },
        { label: 'Last 90 days', value: '90' }
    ];

    connectedCallback() {
        this.now = Date.now();
        this._ticker = setInterval(() => {
            this.now = Date.now();
        }, 1000);
        this.load();
    }

    disconnectedCallback() {
        if (this._ticker) {
            clearInterval(this._ticker);
        }
    }

    get filteredRows() {
        let result = this.rows;
        
        if (this.eoiStatusFilter && this.eoiStatusFilter !== 'All') {
            result = result.filter(r => r.eoiStatusDisplay === this.eoiStatusFilter);
        }

        const key = this.searchKey.trim().toLowerCase();
        if (key) {
            result = result.filter(
                (r) =>
                    (r.Name && r.Name.toLowerCase().includes(key)) ||
                    (r.Customer_Email__c && r.Customer_Email__c.toLowerCase().includes(key)) ||
                    (r.eoiNameDisplay && r.eoiNameDisplay.toLowerCase().includes(key))
            );
        }
        return result;
    }

    get totalCount() {
        return this.filteredRows.length;
    }

    get totalPages() {
        return Math.max(1, Math.ceil(this.totalCount / PAGE_SIZE));
    }

    get pageRows() {
        const start = (this.pageNumber - 1) * PAGE_SIZE;
        return this.filteredRows.slice(start, start + PAGE_SIZE);
    }

    get timedRows() {
        return this.pageRows.map((r) => {
            const exp = this.expiry(r);
            const expired =
                r.Status__c === 'Expired' ||
                (r.Expires_On__c && new Date(r.Expires_On__c).getTime() <= this.now);
            return {
                ...r,
                expiryDisplay: exp.text,
                expiryClass: exp.cls,
                actions: this.buildActions(r, expired)
            };
        });
    }

    expiry(r) {
        if (r.Status__c !== 'Link Created' || !r.Expires_On__c) {
            return { text: '', cls: 'cko-muted' };
        }
        const ms = new Date(r.Expires_On__c).getTime() - this.now;
        if (ms <= 0) {
            return { text: 'Expired', cls: 'cko-expiry-over' };
        }
        const totalSec = Math.floor(ms / 1000);
        const days = Math.floor(totalSec / 86400);
        const hours = Math.floor((totalSec % 86400) / 3600);
        const mins = Math.floor((totalSec % 3600) / 60);
        const secs = totalSec % 60;
        let text;
        if (days > 0) {
            text = `${days}d ${hours}h`;
        } else if (hours > 0) {
            text = `${hours}h ${mins}m`;
        } else if (mins > 0) {
            text = `${mins}m ${secs}s`;
        } else {
            text = `${secs}s`;
        }
        const cls = ms < 3600000 ? 'cko-expiry-soon' : ms < 86400000 ? 'cko-expiry-warn' : 'cko-muted';
        return { text, cls };
    }

    get transactionWord() {
        return this.totalCount === 1 ? 'transaction' : 'transactions';
    }

    get pageLabel() {
        return `Page ${this.pageNumber} of ${this.totalPages}`;
    }

    get disablePrev() {
        return this.pageNumber <= 1;
    }

    get disableNext() {
        return this.pageNumber >= this.totalPages;
    }

    get isEmpty() {
        return !this.loading && this.totalCount === 0;
    }

    load() {
        this.loading = true;
        getPayments({ status: this.status, days: parseInt(this.days, 10), parentId: this.recordId })
            .then((data) => {
                this.rows = data.map((r) => ({
                    ...r,
                    recordUrl: `/lightning/r/Checkout_Payment__c/${r.Id}/view`,
                    amountDisplay: this.amount(r),
                    statusClass: this.statusClass(r.Status__c),
                    lastPolledDisplay: this.relativeTime(r.Last_Polled__c),
                    eoiNameDisplay: r.Expression_of_Interest__r ? r.Expression_of_Interest__r.EOIId__c : '',
                    eoiStatusDisplay: r.Dashboard_Status__c,
                    eoiUrl: r.Expression_of_Interest__c ? `/lightning/r/Expressionofinterest__c/${r.Expression_of_Interest__c}/view` : ''
                }));
                this.pageNumber = 1;
            })
            .catch((e) => this.toast('Error', this.errorMessage(e), 'error'))
            .finally(() => {
                this.loading = false;
            });
    }

    amount(r) {
        return this.formatAmount(r.Amount__c, r.Currency_Code__c);
    }

    formatAmount(value, currency) {
        if (value === null || value === undefined) {
            return '';
        }
        const amt = Number(value).toLocaleString('en-US', {
            minimumFractionDigits: 2,
            maximumFractionDigits: 2
        });
        return `${amt} ${currency || ''}`.trim();
    }

    statusClass(status) {
        const base = 'cko-pill ';
        switch (status) {
            case 'Link Created':
                return base + 'cko-pill_info';
            case 'Authorized':
                return base + 'cko-pill_warning';
            case 'Captured':
                return base + 'cko-pill_success';
            case 'Refunded':
            case 'Partially Refunded':
                return base + 'cko-pill_refund';
            case 'Declined':
                return base + 'cko-pill_error';
            default:
                return base + 'cko-pill_neutral';
        }
    }

    relativeTime(value) {
        if (!value) {
            return '';
        }
        const mins = Math.floor((Date.now() - new Date(value).getTime()) / 60000);
        if (mins < 1) {
            return 'just now';
        }
        if (mins < 60) {
            return `${mins} min${mins === 1 ? '' : 's'} ago`;
        }
        const hours = Math.floor(mins / 60);
        if (hours < 24) {
            return `${hours} hour${hours === 1 ? '' : 's'} ago`;
        }
        const days = Math.floor(hours / 24);
        if (days === 1) {
            return 'Yesterday';
        }
        if (days < 7) {
            return `${days} days ago`;
        }
        return new Date(value).toLocaleDateString();
    }

    buildActions(row, expired) {
        const actions = [];
        if (this.hasFullAccess) {
            if (row.Payment_Link_Url__c && !expired) {
                actions.push({ label: 'Open link', name: 'open' });
            }
        }
        actions.push({ label: 'Refresh status', name: 'refresh' });
        if (this.hasFullAccess) {
            if (row.Status__c === 'Authorized') {
                actions.push({ label: 'Capture (approve)', name: 'capture' });
                actions.push({ label: 'Cancel', name: 'void' });
            }
            if (row.Status__c === 'Captured' || row.Status__c === 'Partially Refunded') {
                actions.push({ label: 'Refund', name: 'refund' });
            }
        }
        // Re-sending needs a live link to send, so a blank URL hides the action.
        if (row.Status__c === 'Link Created' && row.Payment_Link_Url__c) {
            actions.push({ label: 'Send Link', name: 'sendLink' });
        }
        // An expired link can never be paid, so this mints a fresh one instead of re-sending.
        if (row.Status__c === 'Expired') {
            actions.push({ label: 'Send Link', name: 'regenerateLink' });
        }
        return actions;
    }

    handleSearch(e) {
        this.searchKey = e.detail.value;
        this.pageNumber = 1;
    }

    handleStatusChange(e) {
        this.status = e.detail.value;
        this.load();
    }

    handleEoiStatusChange(e) {
        this.eoiStatusFilter = e.detail.value;
        this.pageNumber = 1;
    }

    handleDaysChange(e) {
        this.days = e.detail.value;
        this.load();
    }

    handleReload() {
        this.load();
    }

    handlePrev() {
        if (this.pageNumber > 1) {
            this.pageNumber -= 1;
        }
    }

    handleNext() {
        if (this.pageNumber < this.totalPages) {
            this.pageNumber += 1;
        }
    }

    handleMenuSelect(event) {
        const action = event.detail.value;
        const recordId = event.currentTarget.dataset.id;
        const row = this.rows.find((r) => r.Id === recordId);
        if (row) {
            this.runRowAction(action, row);
        }
    }

    async runRowAction(action, row) {
        if (action === 'open') {
            window.open(row.Payment_Link_Url__c, '_blank');
            return;
        }

        if (action !== 'refresh') {
            const confirmed = await LightningConfirm.open({
                message: this.confirmMessage(action, row),
                label: 'Please confirm',
                theme: action === 'refund' || action === 'void' ? 'warning' : 'success'
            });
            if (!confirmed) {
                return;
            }
        }

        this.loading = true;
        this.runAction(action, row.Id)
            .then(() => {
                this.toast('Success', this.successMessage(action, row), 'success');
                this.load();
            })
            .catch((e) => {
                this.toast('Error', this.errorMessage(e), 'error');
                this.loading = false;
            });
    }

    runAction(action, recordId) {
        if (action === 'refresh') {
            return refreshStatus({ recordId });
        }
        if (action === 'capture') {
            return capturePayment({ recordId, amount: null });
        }
        if (action === 'refund') {
            return refundPayment({ recordId, amount: null });
        }
        if (action === 'sendLink') {
            return resendPaymentLink({ recordId });
        }
        if (action === 'regenerateLink') {
            return regeneratePaymentLink({ recordId });
        }
        return voidPayment({ recordId });
    }

    confirmMessage(action, row) {
        const recipient = row.Customer_Name__c || 'the customer';
        if (action === 'sendLink') {
            return `Send the payment link for ${row.Name} to ${recipient}?`;
        }
        if (action === 'regenerateLink') {
            // No amount here on purpose: the new link is priced from the active EOI Range on the
            // server, so quoting the expired row's amount could promise the wrong number.
            return `This link has expired. Create a new payment link and send it to ${recipient}?`;
        }
        return `${this.actionLabel(action)} payment ${row.Name} for ${row.amountDisplay}?`;
    }

    successMessage(action, row) {
        const recipient = row.Customer_Name__c || 'the customer';
        if (action === 'sendLink') {
            return `Payment link sent to ${recipient}.`;
        }
        if (action === 'regenerateLink') {
            return `A new payment link was created and sent to ${recipient}.`;
        }
        return `${this.actionLabel(action)} completed for ${row.Name}.`;
    }

    actionLabel(action) {
        switch (action) {
            case 'capture':
                return 'Capture';
            case 'refund':
                return 'Refund';
            case 'void':
                return 'Cancel';
            case 'sendLink':
            case 'regenerateLink':
                return 'Send Link';
            case 'refresh':
                return 'Refresh';
            default:
                return action;
        }
    }

    // ── Create-link modal ────────────────────────────────────────────────
    get isStep1() {
        return this.modalStep === 1;
    }
    get isStep2() {
        return this.modalStep === 2;
    }
    get isStep3() {
        return this.modalStep === 3;
    }
    get noOptions() {
        return this.modalStep === 2 && !this.modalLoading && this.options.length === 0;
    }
    get modalTitle() {
        if (this.modalStep === 1) {
            return 'Create payment link';
        }
        if (this.modalStep === 2) {
            return this.sourceType === 'EOI' ? 'Select an EOI' : 'Select an installment';
        }
        return this.resultUrl ? 'Payment link created' : 'Review & generate';
    }
    get searchLabel() {
        return this.sourceType === 'EOI' ? 'Search EOIs (number, project, email)' : 'Search installments (name, sales order)';
    }

    openCreate() {
        this.showModal = true;
        this.modalStep = 1;
        this.sourceType = undefined;
        this.modalSearch = '';
        this.options = [];
        this.selected = undefined;
        this.resultUrl = undefined;
        this.expirySeconds = '604800';
        this.captureMode = 'immediate';
    }

    closeModal() {
        this.showModal = false;
    }

    handleChooseType(event) {
        this.sourceType = event.currentTarget.dataset.type;
        this.modalSearch = '';
        this.modalStep = 2;
        this.loadOptions();
    }

    handleModalSearch(event) {
        this.modalSearch = event.detail.value;
        this.loadOptions();
    }

    loadOptions() {
        this.modalLoading = true;
        getPayableRecords({ sourceType: this.sourceType, searchKey: this.modalSearch })
            .then((data) => {
                this.options = data.map((o) => ({
                    ...o,
                    amountDisplay: this.formatAmount(o.amount, o.currencyCode)
                }));
            })
            .catch((e) => this.toast('Error', this.errorMessage(e), 'error'))
            .finally(() => {
                this.modalLoading = false;
            });
    }

    handleSelectOption(event) {
        const id = event.currentTarget.dataset.id;
        this.selected = this.options.find((o) => o.recordId === id);
        this.modalStep = 3;
    }

    handleBack() {
        if (this.modalStep === 3) {
            this.modalStep = 2;
        } else if (this.modalStep === 2) {
            this.modalStep = 1;
        }
    }

    handleExpiryChange(event) {
        this.expirySeconds = event.detail.value;
    }

    handleCaptureChange(event) {
        this.captureMode = event.detail.value;
    }

    handleGenerate() {
        this.creating = true;
        createLinkFromRecord({
            sourceType: this.sourceType,
            recordId: this.selected.recordId,
            expirySeconds: parseInt(this.expirySeconds, 10),
            capture: this.captureMode === 'immediate'
        })
            .then((r) => {
                this.resultUrl = r.paymentLinkUrl;
                this.toast('Success', 'Payment link created.', 'success');
            })
            .catch((e) => this.toast('Error', this.errorMessage(e), 'error'))
            .finally(() => {
                this.creating = false;
            });
    }

    handleOpenResult() {
        window.open(this.resultUrl, '_blank');
    }

    handleDone() {
        this.showModal = false;
        this.load();
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    errorMessage(e) {
        if (e && e.body && e.body.message) {
            return e.body.message;
        }
        return e && e.message ? e.message : 'Unexpected error';
    }
}