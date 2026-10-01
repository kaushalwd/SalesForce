import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import findRegistrationWithReviewComment from '@salesforce/apex/Draftstagecontroller.findRegistrationWithReviewComment';

import ModonImages from "@salesforce/resourceUrl/modonImages";
import Bootstrap from "@salesforce/resourceUrl/Bootstrap";
import BootstrapCSS from "@salesforce/resourceUrl/BootstrapCSS";
import BootstrapJS from "@salesforce/resourceUrl/BootstrapJS";
import brokerPortalCssFile from "@salesforce/resourceUrl/brokerPortalCssFile";
import modondashboard from '@salesforce/resourceUrl/modondashboard';

import notificationIcon from '@salesforce/resourceUrl/Brokermodonnotificationicons';
import profileIcon from '@salesforce/resourceUrl/BrokerProfileicon';

export default class PortalTheme extends NavigationMixin(LightningElement) {
    logo = ModonImages + "/modonImages/brand-logo-black.png";
    logowhite = ModonImages + "/modonImages/brand-logo-white.png";
    backgroundImage = ModonImages + "/modonImages/bg-theme-pic.png";

    @track tabs = [];
    @track activeTab;
    @track registration;
    @track hasAccess = false;
    @track showSales = false;
    @track showMyAgency = false;
    @track isLimitedOnly = false;
    @track showProfileMenu = false;
    @track showMyInfoContent = false;
    @track isMenuOpen = false;
    @track tabsInitialized = false;

    notificationIcon = notificationIcon;
    profileIcon = profileIcon;
    modondashboard = modondashboard;

    connectedCallback() {
        this.loadData();
        this.syncTabWithUrl();
    }

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

           
        } catch (error) {
            console.error('Error fetching data:', error);
        }
    }

    getTabLabelFromPath(path) {
        switch (path) {
            case '/': return 'Dashboard';
            case '/properties': return 'Properties';
            case '/sales': return 'Sales';
            case '/commissions': return 'Commissions';
            case '/updates': return 'Updates';
            case '/myagency': return 'My Agency';
            case '/help': return 'Help';
            default: return null;
        }
    }

    syncTabWithUrl() {
        const path = window.location.pathname.toLowerCase();
        const activeTabFromUrl = this.getTabLabelFromPath(path);

        if (activeTabFromUrl) {
            this.activeTab = activeTabFromUrl;
        }
    }

    evaluateAndSetTabs() {
        if (this.tabsInitialized) {
            return;
        }

        const allTabs = [
            { label: 'Dashboard' },
            { label: 'Properties' },
            { label: 'Sales' },
            { label: 'Commissions' },
            { label: 'Updates' },
            { label: 'My Agency' },
            { label: 'Help' }
        ];

        this.tabs = [];

        if (!this.hasAccess) {
            return;
        }

        if (this.isLimitedOnly) {
            if (this.showMyAgency) this.tabs.push({ label: 'My Agency' });
            if (this.showSales) this.tabs.push({ label: 'Sales' });
        } else {
            this.tabs = allTabs;
        }

        // Ensure activeTab is valid, else reset to first available tab
        if (!this.tabs.find(tab => tab.label === this.activeTab)) {
            this.activeTab = this.tabs.length ? this.tabs[0].label : null;
        }

        this.tabsInitialized = true;
    }

    handleTabClick(event) {
        const selectedTab = event.target.innerText;
        this.activeTab = selectedTab;
        this.showMyInfoContent = false;

        let targetUrl = '';

        switch (selectedTab) {
            case 'Dashboard': targetUrl = '/'; break;
            case 'Properties': targetUrl = '/properties'; break;
            case 'Sales': targetUrl = '/sales'; break;
            case 'Commissions': targetUrl = '/commissions'; break;
            case 'Updates': targetUrl = '/updates'; break;
            case 'My Agency': targetUrl = '/myagency'; break;
            case 'Help': targetUrl = '/help'; break;
            default: return;
        }

        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: { url: targetUrl }
        });
     this.evaluateAndSetTabs();
      // alert( 'this.tabs:::'+JSON.stringify(this.tabs));
    }

    toggleProfileMenu() {
        this.showProfileMenu = !this.showProfileMenu;
    }

    handleMyInfo() {
        this.showMyInfoContent = true;
        this.showProfileMenu = false;
    }

    handleLogout() {
        window.location.href = '/secur/logout.jsp?retURL=/Brokers';
    }

    handleBackFromProfile() {
        this.showMyInfoContent = false;
    }

    get backgroundStyle() {
        return `background-image: url('${this.backgroundImage}');background-size: cover;background-repeat: no-repeat;background-position: center;`;
    }

    get computedTabs() {
        return this.tabs.map(tab => {
            const isActive = tab.label === this.activeTab;
            return {
                ...tab,
                className: `tab-button${isActive ? ' active' : ''}`
            };
        });
    }

    get isDashboard() { return this.activeTab === 'Dashboard'; }
    get isProperties() { return this.activeTab === 'Properties'; }
    get isSalesAgents() { return this.activeTab === 'Sales'; }
    get isReports() { return this.activeTab === 'Commissions'; }
    get isUpdates() { return this.activeTab === 'Updates'; }
    get isHelp() { return this.activeTab === 'Help'; }
    get isMyAgency() { return this.activeTab === 'My Agency'; }
}