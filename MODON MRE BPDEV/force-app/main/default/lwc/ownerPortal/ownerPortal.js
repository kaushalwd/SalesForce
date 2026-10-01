import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import createHostedPaymentForLwc from '@salesforce/apex/CheckoutPaymentLinkService.createHostedPaymentForLwc';

// Static demo data — no objects/fields yet. Swapped for real records later.
const PLOTS = [
    { id: 'p1', name: 'PLT-001-2024', location: 'Yas Island, Abu Dhabi', area: '5,000', usage: 'Residential', status: 'Active', statusClass: 'badge badge-active' },
    { id: 'p2', name: 'PLT-002-2024', location: 'Al Reem Island, Abu Dhabi', area: '3,200', usage: 'Commercial', status: 'Active', statusClass: 'badge badge-active' }
];

const REQUESTS = [
    { id: 'r1', tracking: 'DCT-48230017', plot: 'PLT-001-2024', service: 'Concept Design Review', category: 'Building Design', status: 'Approved', statusClass: 'badge badge-approved', date: '12 May 2026', price: '—' },
    { id: 'r2', tracking: 'DCT-48230114', plot: 'PLT-001-2024', service: 'GFA Verification Review', category: 'NOCs', status: 'Under Review', statusClass: 'badge badge-under_review', date: '02 Jun 2026', price: 'AED 2,000' },
    { id: 'r3', tracking: 'DCT-48230225', plot: 'PLT-002-2024', service: 'Hoarding', category: 'Site Works', status: 'Submitted', statusClass: 'badge badge-submitted', date: '10 Jun 2026', price: 'AED 800' }
];

const DOCUMENTS = [
    { id: 'd1', name: 'Affection Plan.pdf', type: 'Affection Plan', plot: 'PLT-001-2024', date: '10 May 2026' },
    { id: 'd2', name: 'Sales & Purchase Agreement.pdf', type: 'SPA', plot: 'PLT-001-2024', date: '10 May 2026' },
    { id: 'd3', name: 'Title Deed.pdf', type: 'Ownership Title Deed', plot: 'PLT-002-2024', date: '11 May 2026' }
];

const PAYMENTS = [
    { id: 'pay1', ref: 'TXN-9F2A1C', type: 'Registration Fee', amount: 'AED 1,000', method: 'Card', status: 'Completed', statusClass: 'badge badge-completed', date: '08 May 2026' },
    { id: 'pay2', ref: 'TXN-3B7D2E', type: 'Service — GFA Verification', amount: 'AED 2,000', method: 'Card', status: 'Pending', statusClass: 'badge badge-pending', date: '02 Jun 2026' }
];

const SERVICE_PROVIDERS = [
    { id: 'sp1', company: 'BuildCo Contracting LLC', trn: 'TRN-100-234567-89', license: 'TL-2024-88899', plot: 'PLT-001-2024', status: 'Approved', statusClass: 'badge badge-approved' },
    { id: 'sp2', company: 'AlTech Engineering', trn: 'TRN-200-555888-01', license: 'TL-2024-44455', plot: 'PLT-001-2024', status: 'Pending', statusClass: 'badge badge-pending' }
];

const NOTIFICATIONS = [
    { id: 'n1', title: 'Request Approved', message: 'Your Concept Design Review (DCT-48230017) has been approved.', date: '12 May 2026' },
    { id: 'n2', title: 'Fee Set for Your Request', message: 'The fee for DCT-48230114 has been set to AED 2,000. Please proceed to payment.', date: '03 Jun 2026' },
    { id: 'n3', title: 'Document Checklist Updated', message: 'The document checklist for DCT-48230114 has been updated. Please review.', date: '05 Jun 2026' }
];

export default class OwnerPortal extends NavigationMixin(LightningElement) {
    view = 'dashboard';
    plots = PLOTS;
    requests = REQUESTS;
    documents = DOCUMENTS;
    payments = PAYMENTS;
    serviceProviders = SERVICE_PROVIDERS;
    notifications = NOTIFICATIONS;
    submitted = false;
    menuOpen = false;
    notifOpen = false;
    profileOpen = false;
    @api logoutUrl;

    // Top up (Checkout Hosted Payments Page)
    showTopUp = false;
    topUpAmount = '';
    topUpError = '';
    paying = false;
    topUpBanner;

    connectedCallback() {
        // On return from Checkout's hosted page, show the outcome banner and land on Payments.
        const params = new URLSearchParams(window.location.search);
        const result = params.get('paymentResult');
        if (result) {
            this.view = 'payments';
            this.topUpBanner = this.bannerFor(result);
            window.history.replaceState({}, '', window.location.href.split('?')[0]);
        }
    }

    get payLabel() {
        return this.paying ? 'Redirecting…' : 'Pay now';
    }

    get tabs() {
        return [
            { id: 'dashboard', label: 'Dashboard' },
            { id: 'plots', label: 'My Plots' },
            { id: 'requests', label: 'Service Requests' },
            { id: 'raise', label: 'Raise a Request' },
            { id: 'documents', label: 'Documents' },
            { id: 'payments', label: 'Payments' },
            { id: 'users', label: 'Manage Users' }
        ].map((t) => ({ ...t, cssClass: t.id === this.view ? 'tab active' : 'tab' }));
    }

    get isDashboard() { return this.view === 'dashboard'; }
    get isPlots() { return this.view === 'plots'; }
    get isRequests() { return this.view === 'requests'; }
    get isRaise() { return this.view === 'raise'; }
    get isDocuments() { return this.view === 'documents'; }
    get isPayments() { return this.view === 'payments'; }
    get isUsers() { return this.view === 'users'; }
    get isProfile() { return this.view === 'profile'; }

    get navClass() { return this.menuOpen ? 'tabbar open' : 'tabbar'; }
    get notifMenuClass() { return this.notifOpen ? 'dropdown notif-dd open' : 'dropdown notif-dd'; }
    get profileMenuClass() { return this.profileOpen ? 'dropdown open' : 'dropdown'; }

    toggleMenu() { this.menuOpen = !this.menuOpen; }
    toggleNotif() { this.notifOpen = !this.notifOpen; this.profileOpen = false; }
    toggleProfile() { this.profileOpen = !this.profileOpen; this.notifOpen = false; }
    goProfile() { this.view = 'profile'; this.profileOpen = false; this.menuOpen = false; }
    handleLogout() {
        this.profileOpen = false;
        if (this.logoutUrl) { window.location.href = this.logoutUrl; return; }
        this[NavigationMixin.Navigate]({ type: 'comm__loginPage', attributes: { actionName: 'logout' } });
    }

    handleTab(event) {
        this.view = event.currentTarget.dataset.id;
        this.submitted = false;
        this.menuOpen = false;
        this.notifOpen = false;
        this.profileOpen = false;
    }

    goRaise() {
        this.view = 'raise';
        this.submitted = false;
    }

    handleSubmit(event) {
        event.preventDefault();
        this.submitted = true;
    }

    // ── Top up ────────────────────────────────────────────────────────────
    handleTopUp() {
        this.topUpAmount = '';
        this.topUpError = '';
        this.showTopUp = true;
    }

    closeTopUp() {
        this.showTopUp = false;
    }

    handleAmountChange(event) {
        this.topUpAmount = event.target.value;
    }

    startPayment() {
        const amount = parseFloat(this.topUpAmount);
        if (!amount || amount <= 0) {
            this.topUpError = 'Enter a valid amount.';
            return;
        }
        this.topUpError = '';
        this.paying = true;
        const base = window.location.href.split('?')[0];
        createHostedPaymentForLwc({
            amount: amount,
            currencyCode: 'AED',
            successUrl: base + '?paymentResult=success',
            failureUrl: base + '?paymentResult=failed',
            cancelUrl: base + '?paymentResult=cancelled',
            description: 'Owner Portal top-up'
        })
            .then((result) => {
                if (result && result.isSuccess && result.paymentLinkUrl) {
                    window.location.href = result.paymentLinkUrl;
                } else {
                    this.paying = false;
                    this.topUpError = result && result.message ? result.message : 'Could not start payment.';
                }
            })
            .catch((error) => {
                this.paying = false;
                this.topUpError =
                    error && error.body && error.body.message ? error.body.message : 'Could not start payment.';
            });
    }

    bannerFor(result) {
        if (result === 'success') {
            return { cssClass: 'alert alert-success', icon: '✓', text: 'Payment received — we’re confirming it. Your top-up will reflect shortly.' };
        }
        if (result === 'failed') {
            return { cssClass: 'alert alert-warning', icon: '⚠', text: 'Payment was not completed. Please try again.' };
        }
        if (result === 'cancelled') {
            return { cssClass: 'alert alert-info', icon: 'ℹ️', text: 'Payment cancelled — no charge was made.' };
        }
        return undefined;
    }
}