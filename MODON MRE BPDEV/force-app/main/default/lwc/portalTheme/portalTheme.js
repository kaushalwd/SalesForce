import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import findRegistrationWithReviewComment from '@salesforce/apex/Draftstagecontroller.findRegistrationWithReviewComment';
// Aspire logo — its own standalone static resource (single file).
import Mbp_Aspirelogo from "@salesforce/resourceUrl/Mbp_Aspirelogo";
// Modon branding — lives inside the modonImages zip static resource.
import ModonImages from "@salesforce/resourceUrl/modonImages";
import modondashboard from '@salesforce/resourceUrl/modondashboard';
import Termsandcondtions from '@salesforce/label/c.MBP_TermsandConditions';
import notificationIcon from '@salesforce/resourceUrl/Brokermodonnotificationicons';
import profileIcon from '@salesforce/resourceUrl/BrokerProfileicon';
// Lives on Draftstagecontroller — true when the logged-in user is an
// Owner/Agency Admin AND their agency's classification is Principal,
// Maestro, or Ambassador.
import shouldShowAspireLogo from '@salesforce/apex/Draftstagecontroller.shouldShowAspireLogo';

export default class PortalTheme extends NavigationMixin(LightningElement) {
    // ── Header logo — two different static resources, so the choice of
    // which one to render is made in the HTML with
    // template if:true={showAspireLogo} / if:false={showAspireLogo}.
    //
    // FIX: the header (.header) has background-color: #000000 (solid black).
    // The Modon logo was previously pointed at brand-logo-black.png — a
    // black logo on a black header is invisible, which is exactly what
    // looked like "the Modon logo isn't working" for Standard-tier users.
    // The Aspire logo happened to look fine against the same background,
    // so it seemed like only the Standard/Modon path was broken. Switching
    // to the white variant (brand-logo-white.png) — which was already
    // being loaded as `logowhite` but never actually used anywhere —
    // fixes it. No Apex change needed; shouldShowAspireLogo() was already
    // returning the correct value.
    aspireLogo = Mbp_Aspirelogo;
    modonLogo = ModonImages + "/modonImages/brand-logo-white.png";
    backgroundImage = ModonImages + "/modonImages/bg-theme-pic.png";

    termsandcondtions = Termsandcondtions;

    // Defaults to false (Modon logo) until the Apex call resolves, so
    // there's never a flash of the Aspire logo for someone who isn't
    // eligible. The HTML reads this directly.
    @track showAspireLogo = false;

    // tracked reactive properties
    @track tabs = [];
    @track activeTab;
    @track registration;
    @track hasAccess = false;
    @track showSales = false;
    @track showMyAgency = false;
    @track isLimitedOnly = false;
    @track showProfileMenu = false;
    @track showMyInfoContent = false;

    // menu state
    @track isMenuOpen = false;
    @track tabsInitialized = false;

    // notifications / profile icons
    notificationIcon = notificationIcon;
    profileIcon = profileIcon;
    modondashboard = modondashboard;

    // notifications state
    @track notifications = [];
    @track unreadCount = 0;
    @track showDropdown = false;
    @track error;

    // //mobile: mobile detection
    @track isMobile = false;

    // //mobile: mobile specific state
    @track showMobileProfileMenu = false;
    @track expandedTabs = new Set();
    @track brokerType;


    connectedCallback() {
        // //mobile: Add mobile detection
        this.detectMobile();
        window.addEventListener('resize', this.handleResize);
        window.addEventListener('click', this.handleClickOutside);

        this.loadData();
        this.loadHeaderLogoEligibility();
        this.syncTabWithUrl();
    }

    disconnectedCallback() {
        // //mobile: Clean up event listeners
        window.removeEventListener('resize', this.handleResize);
        window.removeEventListener('click', this.handleClickOutside);
    }

    // //mobile: Mobile detection methods
    handleResize = () => {
        this.detectMobile();
    }

    detectMobile() {
        this.isMobile = window.innerWidth <= 768;
        if (!this.isMobile) {
            this.isMenuOpen = false;
            this.showMobileProfileMenu = false;
        }
    }

    // //mobile: Click outside handler to close dropdowns
    handleClickOutside = (event) => {
        if (this.isMobile) {
            // Close mobile profile menu if clicked outside
            const mobileProfileMenu = this.template.querySelector('.mobile-profile-menu');
            if (mobileProfileMenu && !mobileProfileMenu.contains(event.target)) {
                this.showMobileProfileMenu = false;
            }
        } else {
            // Close desktop profile menu if clicked outside
            const profileMenu = this.template.querySelector('.profile-menu');
            if (profileMenu && !profileMenu.contains(event.target)) {
                this.showProfileMenu = false;
            }
        }
    }

    // //mobile: Mobile menu methods
    toggleMobileMenu() {
        this.isMenuOpen = !this.isMenuOpen;
        // Close profile menu when opening mobile menu
        if (this.isMenuOpen) {
            this.showMobileProfileMenu = false;
        }
    }

    closeMobileMenu = () => {
        this.isMenuOpen = false;
    }

    handleToggleMenu() {
        this.isMenuOpen = !this.isMenuOpen;
    }

    // //mobile: Mobile profile menu methods
    toggleMobileProfileMenu = (event) => {
        event.stopPropagation(); // Prevent the click from bubbling to window
        this.showMobileProfileMenu = !this.showMobileProfileMenu;
        // Close sidebar if open
        if (this.showMobileProfileMenu) {
            this.isMenuOpen = false;
        }
    }

    // Desktop profile menu method
    toggleProfileMenu = (event) => {
        if (event) event.stopPropagation();
        this.showProfileMenu = !this.showProfileMenu;
    }

    // ── Header logo eligibility ──────────────────────────────────────────────
    // Calls the Apex check and stores the result on the tracked property that
    // the HTML's if:true/if:false blocks read directly.
    loadHeaderLogoEligibility() {
        return shouldShowAspireLogo()
            .then((result) => {
                this.showAspireLogo = !!result;
            })
            .catch((err) => {
                console.error('❌ Error checking Aspire logo eligibility:', err);
                this.showAspireLogo = false; // fail safe -> Modon logo
            });
    }

    // Data loading and tab logic
    async loadData() {
        try {
            const result = await findRegistrationWithReviewComment();

            this.registration = result.registration;
            this.hasAccess = result.hasAccess;
            this.showSales = result.showSales;
            this.showMyAgency = result.showMyAgency;
            this.isLimitedOnly = result.isLimitedOnly;
            this.firstName = result.firstName;
            this.middleName = result.middleName;
            this.lastName = result.lastName;

            this.evaluateAndSetTabs();
            this.syncTabWithUrl();
        } catch (error) {
            console.error('Error fetching data:', error);
        }
    }

    getTabLabelFromPath(path) {
        if (path.includes('/myagency')) return 'My Agency';
        if (path.includes('/properties?tab=marketing') || path.includes('tab=marketing')) {
    return 'Marketing Collaterals';
}
    if (path.includes('/properties')) return 'My Sales';
        if (path.includes('/Leads')) return 'Leads';
        if (
    path.includes(
        '/manage-expression-of-interest'
    )
) {

    return 'Leads';
}
        if (path.includes('/commissions')) return 'Commissions';
        if (path.includes('/Updates')) return 'Updates';
        if (path.includes('/help')) return 'Help';
        if (path === '/' || path.includes('/dashboard') || path.includes('/brokers')) return 'Dashboard';
        return null;
    }

    syncTabWithUrl() {
        // First, check sessionStorage
        const storedTab = sessionStorage.getItem('activeTab');
        if (storedTab && this.tabs.find(tab => tab.label === storedTab)) {
            this.activeTab = storedTab;
            return;
        }

        // Fallback to URL
        const path = window.location.pathname.toLowerCase();
        const activeTabFromUrl = this.getTabLabelFromPath(path);
        if (activeTabFromUrl && this.tabs.find(tab => tab.label === activeTabFromUrl)) {
            this.activeTab = activeTabFromUrl;
        } else {
            this.activeTab = this.tabs.length ? this.tabs[0].label : null;
        }
    }

    evaluateAndSetTabs() {
        if (this.tabsInitialized) return;

      const allTabs = [
    { label: 'Dashboard' },
    { label: 'My Sales' },
    { label: 'Marketing Collaterals' },
    { label: 'Leads' },
    { label: 'Commissions' },
    { label: 'Updates' },
    { label: 'My Agency' },
    { label: 'Help' }
];
        this.tabs = [];

        if (!this.hasAccess) return;

        if (this.isLimitedOnly) {
            if (this.showMyAgency) this.tabs.push({ label: 'My Agency' });
            if (this.showSales) this.tabs.push({ label: 'Leads' });
        } else {
            this.tabs = allTabs;
        }

        // Ensure activeTab is valid after setting tabs
        const path = window.location.pathname.toLowerCase();
        const possibleTab = this.getTabLabelFromPath(path);
        if (possibleTab && this.tabs.find(tab => tab.label === possibleTab)) {
            this.activeTab = possibleTab;
        } else {
            this.activeTab = this.tabs.length ? this.tabs[0].label : null;
        }

        this.tabsInitialized = true;
    }

    // Tab navigation
    handleTabClick(event) {
        const selectedTab = event.currentTarget.dataset.label || event.target.innerText;
        if (!selectedTab) return;
        
        this.navigateToTab(selectedTab);
        this.isMenuOpen = false;
    }

    // //mobile: Mobile tab click handler
    handleTabClickMobile(event) {
        const selectedTab = event.currentTarget.dataset.label;
        if (!selectedTab) return;
        
        // Check if this tab has sub-tabs
        if (this.subTabsConfig[selectedTab] && this.subTabsConfig[selectedTab].length > 0) {
            // Toggle expand/collapse for this tab
            if (this.expandedTabs.has(selectedTab)) {
                this.expandedTabs.delete(selectedTab);
            } else {
                this.expandedTabs.add(selectedTab);
            }
            // Force re-render
            this.expandedTabs = new Set(this.expandedTabs);
        } else {
            // No sub-tabs, navigate directly
            this.navigateToTab(selectedTab);
            this.isMenuOpen = false;
            this.showMobileProfileMenu = false;
        }
    }

    navigateToTab(selectedTab) {
        this.activeTab = selectedTab;
        sessionStorage.setItem('activeTab', selectedTab);
        this.showMyInfoContent = false;

        let targetUrl = '';

        switch (selectedTab) {
            case 'Dashboard': targetUrl = '/'; break;
        case 'My Sales':
    targetUrl = '/properties?tab=units';
    break;
    case 'Marketing Collaterals':
    targetUrl = '/properties?tab=marketing';
    break;
            case 'Leads': targetUrl = '/Leads'; break;
            case 'Commissions': targetUrl = '/commissions'; break;
            case 'Updates': targetUrl = '/Updates'; break;
            case 'My Agency': targetUrl = '/myagency'; break;
            case 'Help': targetUrl = '/help'; break;
            default:
                console.warn('[Unknown Tab Selected]', selectedTab);
                return;
        }

        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: { url: targetUrl }
        });
    }

    // Profile & notification methods
    toggleDropdown() {
        this.showDropdown = !this.showDropdown;
        // Close other menus when opening notifications
        if (this.showDropdown) {
            this.showProfileMenu = false;
            this.showMobileProfileMenu = false;
        }
    }

    handleMyInfo() {
        this.showMyInfoContent = true;
        this.showProfileMenu = false;
        this.showMobileProfileMenu = false;
    }

    handleLogout() {
        window.location.href = '/secur/logout.jsp?retURL=/Brokers';
    }

    handleBackFromProfile() {
        this.showMyInfoContent = false;
    }

    // //mobile: Sub-tab click handler
    handleSubTabClick(event) {
        const subTabUrl = event.currentTarget.dataset.url;
        if (subTabUrl) {
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: { url: subTabUrl }
            });
            
            // Close all menus
            this.isMenuOpen = false;
            this.showMobileProfileMenu = false;
        }
        event.stopPropagation(); // Prevent triggering the main tab click
    }

    // Getters
    get backgroundStyle() {
        return `background-image: url('${this.backgroundImage}');background-size: cover;background-repeat: no-repeat;background-position: center;`;
    }

    // //mobile: Enhanced computed tabs for mobile
    get computedTabs() {
        return this.tabs.map(tab => {
            const isActive = tab.label === this.activeTab;
            const hasSubTabs = this.subTabsConfig[tab.label] && this.subTabsConfig[tab.label].length > 0;
            const isExpanded = this.expandedTabs.has(tab.label);
            
            
            return {
                ...tab,
                className: `tab-button ${isActive ? 'active' : ''}`,
                mobileMenuClass: `mobile-menu-item ${isActive ? 'active' : ''} ${hasSubTabs ? 'has-subtabs' : ''} ${isExpanded ? 'expanded' : ''}`,
                hasSubTabs: hasSubTabs,
                isExpanded: isExpanded,
                subTabs: hasSubTabs ? this.subTabsConfig[tab.label] : []
            };
        });
    }

    // //mobile: Sub-tabs configuration with real URLs
    @track subTabsConfig = {
       'My Sales': [
    { label: 'My Units', url: '/properties?tab=units' }
],
       'Leads': [

    {
        label: 'Manage Leads',
        url: '/Leads?view=leads'
    },

    {
        // Opportunities lives as a tab on the Leads page (there is no standalone
        // /manage-opportunities page). Deep-link to /Leads and let that page open
        // the Opportunities tab via the ?view= param.
        label: 'Manage Opportunities',
        url: '/Leads?view=opportunities'
    },

    {
        label: 'Manage Expression Of Interest',
        url: '/Leads?view=eoi'
    }
],
        'My Agency': [
            { label: 'Agency Info', url: '/myagency?tab=info' },
            { label: 'My Agents', url: '/agents?tab=agent' }
        ],
        'Help': [
            { label: 'Contact us', url: '/help?tab=contact' },
            { label: 'Cases', url: '/help?tab=cases' },
          /*  {label: 'Policies & Guidelines', url: '/help?tab=policy'},*/
            {label: 'Broker Requests', url: '/help?tab=Broker Requests'}
        ],
        'Dashboard': [
            { label: 'Dashboard', url: '/dashboard?tab=dashboard' },
            { label: 'Aspire', url: '/dashboard?tab=aspire' }
        ],
        'Updates': [
            { label: 'Events and Activities', url: '/Updates' },
            { label: 'Communications', url: '/communications' }
        ]
    };


    

    // //mobile: Mobile sidebar class getter
    get mobileSidebarClass() {
        return this.isMenuOpen ? 'mobile-sidebar open' : 'mobile-sidebar';
    }

    // //mobile: Mobile backdrop class getter
    get mobileBackdropClass() {
        return this.isMenuOpen ? 'mobile-backdrop show' : 'mobile-backdrop';
    }

    get hasUnread() {
        return this.unreadCount > 0;
    }

    get isDashboard() { return this.activeTab === 'Dashboard'; }
  get isProperties() {
    return this.activeTab === 'My Sales';
}
    get isSalesAgents() { return this.activeTab === 'Leads'; }
    get isReports() { return this.activeTab === 'Commissions'; }
    get isUpdates() { return this.activeTab === 'Updates'; }
    get isHelp() { return this.activeTab === 'Help'; }
    get isMyAgency() { return this.activeTab === 'My Agency'; }



}