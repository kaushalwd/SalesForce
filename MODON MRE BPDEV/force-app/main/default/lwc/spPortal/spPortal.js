import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

const TABS = [
    { id: 'dashboard', label: 'Dashboard' },
    { id: 'plots', label: 'Assigned Plots' },
    { id: 'requests', label: 'My Requests' },
    { id: 'raise', label: 'Raise a Request' },
    { id: 'documents', label: 'Documents' }
];

const STATS = [
    { id: 's1', icon: '🏗️', iconClass: 'stat-icon green', value: '1', label: 'Assigned Plots' },
    { id: 's2', icon: '📋', iconClass: 'stat-icon gold', value: '2', label: 'My Requests' },
    { id: 's3', icon: '⏳', iconClass: 'stat-icon orange', value: '1', label: 'Pending' },
    { id: 's4', icon: '✓', iconClass: 'stat-icon green', value: '1', label: 'Approved' }
];

const RECENT_REQUESTS = [
    { id: 'r1', tracking: 'DCT-48230114', service: 'GFA Verification Review', plot: 'PLT-001-2024', status: 'Under Review', statusClass: 'badge badge-under_review', submitted: '02 Jun 2026' },
    { id: 'r2', tracking: 'DCT-48230260', service: 'Hoarding', plot: 'PLT-001-2024', status: 'Approved', statusClass: 'badge badge-approved', submitted: '28 May 2026' }
];

const ASSIGNED_PLOTS = [
    { id: 'p1', plot: 'PLT-001-2024', location: 'Yas Island, Abu Dhabi', owner: 'Ahmed Al Mansouri', usage: 'Residential', status: 'Active', statusClass: 'badge badge-active' }
];

const MY_REQUESTS = [
    { id: 'mr1', tracking: 'DCT-48230114', service: 'GFA Verification Review', category: 'NOCs', plot: 'PLT-001-2024', status: 'Under Review', statusClass: 'badge badge-under_review', fee: 'AED 2,000', submitted: '02 Jun 2026' },
    { id: 'mr2', tracking: 'DCT-48230260', service: 'Hoarding', category: 'Site Works', plot: 'PLT-001-2024', status: 'Approved', statusClass: 'badge badge-approved', fee: 'AED 800', submitted: '28 May 2026' }
];

const RAISE_STEPS = [
    { id: 'st1', num: '✓', label: 'Concept Design', cssClass: 'step done' },
    { id: 'st2', num: '2', label: 'Request Details', cssClass: 'step active' },
    { id: 'st3', num: '3', label: 'Documents', cssClass: 'step' },
    { id: 'st4', num: '4', label: 'Review & Confirm', cssClass: 'step' }
];

const SERVICE_CATEGORIES = [
    { id: 'sc1', label: 'NOCs' },
    { id: 'sc2', label: 'Site Works' },
    { id: 'sc3', label: 'Design Review' },
    { id: 'sc4', label: 'Land Transactions' }
];

const SERVICE_TYPES = [
    { id: 'sv1', label: 'Concept Design Review — AED 1,500' },
    { id: 'sv2', label: 'GFA Verification Review — AED 2,000' },
    { id: 'sv3', label: 'Elevation and Perspectives NOC — AED 1,200' },
    { id: 'sv4', label: 'Modon Building Permit NOC — AED 3,500' },
    { id: 'sv5', label: 'Hoarding — AED 800' },
    { id: 'sv6', label: 'Enabling Works — AED 2,500' },
    { id: 'sv7', label: 'Height Increase — AED 4,000' }
];

const URGENCY_OPTIONS = [
    { id: 'u1', label: 'Normal' },
    { id: 'u2', label: 'High' },
    { id: 'u3', label: 'Urgent' }
];

const DOCUMENTS = [
    { id: 'd1', name: 'Trade License.pdf', type: 'Trade License', plot: '—', uploaded: '09 May 2026' },
    { id: 'd2', name: 'Authorization Letter.pdf', type: 'Authorization Letter', plot: 'PLT-001-2024', uploaded: '09 May 2026' }
];

const NOTIFICATIONS = [
    { id: 'n1', title: 'Plot Access Granted', message: 'You have been granted access to PLT-001-2024. You can now raise service requests.', date: '10 May 2026' },
    { id: 'n2', title: 'Request Under Review', message: 'DCT-48230114 (GFA Verification) is under review.', date: '02 Jun 2026' }
];

export default class SpPortal extends NavigationMixin(LightningElement) {
    view = 'dashboard';
    submitted = false;
    menuOpen = false;
    notifOpen = false;
    profileOpen = false;
    @api logoutUrl;

    stats = STATS;
    recentRequests = RECENT_REQUESTS;
    assignedPlots = ASSIGNED_PLOTS;
    myRequests = MY_REQUESTS;
    raiseSteps = RAISE_STEPS;
    serviceCategories = SERVICE_CATEGORIES;
    serviceTypes = SERVICE_TYPES;
    urgencyOptions = URGENCY_OPTIONS;
    documents = DOCUMENTS;
    notifications = NOTIFICATIONS;

    get tabs() {
        return TABS.map((t) => ({
            id: t.id,
            label: t.label,
            cssClass: t.id === this.view ? 'tab active' : 'tab'
        }));
    }

    get isDashboard() { return this.view === 'dashboard'; }
    get isPlots() { return this.view === 'plots'; }
    get isRequests() { return this.view === 'requests'; }
    get isRaise() { return this.view === 'raise'; }
    get isDocuments() { return this.view === 'documents'; }
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
        this.menuOpen = false;
        this.notifOpen = false;
        this.profileOpen = false;
    }

    goRaise() {
        this.view = 'raise';
    }

    handleSubmit(event) {
        event.preventDefault();
        this.submitted = true;
    }
}