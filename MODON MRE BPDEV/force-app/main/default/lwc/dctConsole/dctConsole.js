import { LightningElement } from 'lwc';

const STATS = [
    { id: 'ownerPending', icon: '⏳', cls: 'stat-icon orange', value: '1', label: 'Owner Regs Pending' },
    { id: 'spPending', icon: '⏳', cls: 'stat-icon orange', value: '1', label: 'SP Regs Pending' },
    { id: 'requests', icon: '📋', cls: 'stat-icon gold', value: '3', label: 'Service Requests' },
    { id: 'review', icon: '🔎', cls: 'stat-icon blue', value: '1', label: 'Under Review' },
    { id: 'assignPending', icon: '⏳', cls: 'stat-icon orange', value: '1', label: 'Assignments Pending' },
    { id: 'owners', icon: '👤', cls: 'stat-icon green', value: '1', label: 'Owners' },
    { id: 'providers', icon: '🏢', cls: 'stat-icon green', value: '1', label: 'Service Providers' },
    { id: 'plots', icon: '🏗️', cls: 'stat-icon green', value: '2', label: 'Plots' }
];

const RECENT_REQUESTS = [
    { id: 'r1', tracking: 'DCT-48231007', service: 'Concept Design Review', submitter: 'Ahmed Al Mansouri', plot: 'PLT-001-2024', status: 'Under Review', statusClass: 'badge badge-under_review', submitted: '15 Jun 2026' },
    { id: 'r2', tracking: 'DCT-48230994', service: 'GFA Verification Review', submitter: 'BuildCo Contracting LLC', plot: 'PLT-002-2024', status: 'Submitted', statusClass: 'badge badge-submitted', submitted: '14 Jun 2026' },
    { id: 'r3', tracking: 'DCT-48230871', service: 'Modon Building Permit NOC', submitter: 'Ahmed Al Mansouri', plot: 'PLT-001-2024', status: 'Approved', statusClass: 'badge badge-approved', submitted: '09 Jun 2026' }
];

const OWNER_REGS = [
    { id: 'o1', name: 'Sara Al Zaabi', email: 'newowner@test.ae', company: 'Al Zaabi Real Estate', plot: 'PLT-009-2024', submitted: '14 Jun 2026', status: 'Pending', statusClass: 'badge badge-pending', pending: true },
    { id: 'o2', name: 'Mohammed Al Hashimi', email: 'mh@example.ae', company: 'Hashimi Holdings', plot: 'PLT-014-2024', submitted: '02 Jun 2026', status: 'Approved', statusClass: 'badge badge-approved', pending: false }
];

const SP_REGS = [
    { id: 's1', company: 'AlTech Engineering', email: 'newsp@test.ae', trn: 'TRN-200-555888-01', plot: 'PLT-001-2024', submitted: '13 Jun 2026', status: 'Pending', statusClass: 'badge badge-pending', pending: true }
];

const SERVICE_REQUESTS = [
    { id: 'sr1', tracking: 'DCT-48231007', service: 'Concept Design Review', submitter: 'Ahmed Al Mansouri', plot: 'PLT-001-2024', status: 'Under Review', statusClass: 'badge badge-under_review', fee: 'AED 5,000' },
    { id: 'sr2', tracking: 'DCT-48230994', service: 'GFA Verification Review', submitter: 'BuildCo Contracting LLC', plot: 'PLT-002-2024', status: 'Submitted', statusClass: 'badge badge-submitted', fee: 'AED 3,500' },
    { id: 'sr3', tracking: 'DCT-48230871', service: 'Modon Building Permit NOC', submitter: 'Ahmed Al Mansouri', plot: 'PLT-001-2024', status: 'Approved', statusClass: 'badge badge-approved', fee: 'AED 12,000' },
    { id: 'sr4', tracking: 'DCT-48230755', service: 'Elevation and Perspectives NOC', submitter: 'AlTech Engineering', plot: 'PLT-009-2024', status: 'Incomplete', statusClass: 'badge badge-incomplete', fee: 'AED 2,750' }
];

const ASSIGNMENTS = [
    { id: 'a1', plot: 'PLT-001-2024', provider: 'BuildCo Contracting LLC', owner: 'Ahmed Al Mansouri', requested: '12 Jun 2026', status: 'Pending', statusClass: 'badge badge-pending' }
];

const PLOTS = [
    { id: 'p1', plot: 'PLT-001-2024', owner: 'Ahmed Al Mansouri', location: 'Yas Island', area: '5,000', usage: 'Residential', status: 'Active', statusClass: 'badge badge-active' },
    { id: 'p2', plot: 'PLT-002-2024', owner: 'Ahmed Al Mansouri', location: 'Al Reem Island', area: '3,200', usage: 'Commercial', status: 'Active', statusClass: 'badge badge-active' }
];

const USERS = [
    { id: 'u1', name: 'DCT Admin', email: 'admin@modon.ae', role: 'dct_admin', status: 'Active', statusClass: 'badge badge-active', created: '01 May 2026' },
    { id: 'u2', name: 'Ahmed Al Mansouri', email: 'owner@demo.ae', role: 'owner', status: 'Active', statusClass: 'badge badge-active', created: '08 May 2026' },
    { id: 'u3', name: 'BuildCo Contracting', email: 'sp@demo.ae', role: 'service_provider', status: 'Active', statusClass: 'badge badge-active', created: '09 May 2026' }
];

const TABS = [
    { id: 'dashboard', label: 'Dashboard' },
    { id: 'ownerregs', label: 'Owner Registrations' },
    { id: 'spregs', label: 'SP Registrations' },
    { id: 'requests', label: 'Service Requests' },
    { id: 'assignments', label: 'Assignments' },
    { id: 'plots', label: 'Plots' },
    { id: 'users', label: 'Users' }
];

export default class DctConsole extends LightningElement {
    view = 'dashboard';
    menuOpen = false;

    stats = STATS;
    recentRequests = RECENT_REQUESTS;
    ownerRegs = OWNER_REGS;
    spRegs = SP_REGS;
    serviceRequests = SERVICE_REQUESTS;
    assignments = ASSIGNMENTS;
    plots = PLOTS;
    users = USERS;

    get tabs() {
        return TABS.map((t) => ({
            id: t.id,
            label: t.label,
            cssClass: t.id === this.view ? 'tab active' : 'tab'
        }));
    }

    get isDashboard() { return this.view === 'dashboard'; }
    get isOwnerRegs() { return this.view === 'ownerregs'; }
    get isSpRegs() { return this.view === 'spregs'; }
    get isRequests() { return this.view === 'requests'; }
    get isAssignments() { return this.view === 'assignments'; }
    get isPlots() { return this.view === 'plots'; }
    get isUsers() { return this.view === 'users'; }

    get navClass() { return this.menuOpen ? 'tabbar open' : 'tabbar'; }
    toggleMenu() { this.menuOpen = !this.menuOpen; }

    handleTab(event) {
        this.view = event.currentTarget.dataset.id;
        this.menuOpen = false;
    }

    handleNoop(event) {
        event.preventDefault();
    }
}