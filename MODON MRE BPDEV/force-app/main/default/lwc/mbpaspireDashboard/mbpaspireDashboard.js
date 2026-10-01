import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getBrokerDashboardData from '@salesforce/apex/MBP_BrokerClassificationProgram.getBrokerDashboardData';
import getEventsDynamic from '@salesforce/apex/MBP_ManageEventsandActivities.getEventsDynamic';

import currencyIcon from '@salesforce/resourceUrl/Mbp_Dirhamicon';
import aspireLogo from '@salesforce/resourceUrl/Mbp_Aspirelogo';
import principalBadge from '@salesforce/resourceUrl/Mbp_PrincipalBadge';
import maestroBadge from '@salesforce/resourceUrl/Mbp_MaestroBadge';
import ambassadorBadge from '@salesforce/resourceUrl/Mbp_Ambassadorbadge';
import pp1 from '@salesforce/resourceUrl/Mbp_Handshake';
import pp2 from '@salesforce/resourceUrl/Mbp_QRcode';
import pp3 from '@salesforce/resourceUrl/Mbp_StarCalendar';
import pp4 from '@salesforce/resourceUrl/Mbp_Connects';
import pp5 from '@salesforce/resourceUrl/Mbp_Inhands';
import pp6 from '@salesforce/resourceUrl/Mbp_Brainy';
import event1 from '@salesforce/resourceUrl/Mbp_DineMeet';
import event2 from '@salesforce/resourceUrl/Mbp_officemeet';
import event3 from '@salesforce/resourceUrl/Mbp_Growthmeet';
import modonLogo from '@salesforce/resourceUrl/Modon_White_Logo';
import wayToMaestro from '@salesforce/resourceUrl/Mbp_WayToMaestro';
import NowInAmbassador from '@salesforce/resourceUrl/Mbp_NowInAmbassador';
import wayToAmbassador from '@salesforce/resourceUrl/Mbp_WayToAmbassador';
import maestrounlocked from '@salesforce/resourceUrl/Mbp_Maestrounlocked';
import principalunlocked from '@salesforce/resourceUrl/Mbp_PrincipalUnlocked';
import ambassdorunlocked from '@salesforce/resourceUrl/Mbp_Ambassadorunlocked';

function formatCurrency(n) {
    if (n === null || n === undefined || n === '') return '';
    if (n === 0) return '0';
    if (n >= 1000000000) return (n / 1000000000).toFixed(1).replace(/\.0$/, '') + 'B';
    if (n >= 1000000) return (n / 1000000).toFixed(1).replace(/\.0$/, '') + 'M';
    return new Intl.NumberFormat('en-US').format(Math.round(n));
}

export default class MbpaspireDashboard extends NavigationMixin(LightningElement) {
    currencyIcon = currencyIcon;
    aspireLogo = aspireLogo;
    principalBadge = principalBadge;
    maestroBadge = maestroBadge;
    ambassadorBadge = ambassadorBadge;
    pp1 = pp1;
    pp2 = pp2;
    pp3 = pp3;
    pp4 = pp4;
    pp5 = pp5;
    pp6 = pp6;
    event1 = event1;
    event2 = event2;
    event3 = event3;
    modonLogo = modonLogo;
    wayToMaestro = wayToMaestro;
    NowInAmbassador = NowInAmbassador;
    wayToAmbassador = wayToAmbassador;
    maestrounlocked = maestrounlocked;
    principalunlocked = principalunlocked;
    ambassdorunlocked = ambassdorunlocked;

    @track dashboardData = null;
    @track events = [];
    @track isLoading = true;

    connectedCallback() {
        this.loadDashboardData();
    }

async loadDashboardData() {
    this.isLoading = true;
    try {
        const data = await getBrokerDashboardData();
        this.dashboardData = data;

  const sales = Number(data?.currentSales);

if (isNaN(sales)) {
    this.nextMilestoneValue = '0';
} else if (sales < 60000000) {
    this.nextMilestoneValue = formatCurrency(60000000);
} else if (sales < 200000000) {
    this.nextMilestoneValue = formatCurrency(200000000);
} else if (sales < 500000000) {
    this.nextMilestoneValue = formatCurrency(500000000);
} else {
    this.nextMilestoneValue = formatCurrency(9999999999);
}

    } catch (error) {
        console.error(error);
        this.nextMilestoneValue = '0';
    } finally {
        this.isLoading = false;
    }
}

    get userName() {
        return this.dashboardData?.userName || '';
    }

    get userInitials() {
        if (!this.userName) return '';
        return this.userName.split(' ').map(w => w[0]).join('').substring(0, 2).toUpperCase();
    }

    get hasPhoto() {
        return false;
    }

    get agencyName() {
        return this.dashboardData?.agencyName || '';
    }

    get currentSales() {
        return formatCurrency(this.dashboardData?.currentSales);
    }

get nextMilestone() {
    const sales = Number(this.dashboardData?.currentSales);

    if (isNaN(sales)) return '0';

    if (sales < 60000000) {
        return '60M';
    } 
    else if (sales < 200000000) {
        return '200M';
    } 
    else if (sales < 500000000) {
        return '500M';
    } 
    else {
        return '9,999,999,999';
    }
}

    get showNextMilestone() {
        return this.dashboardData?.nextMilestone !== null && this.dashboardData?.nextMilestone !== undefined;
    }

    get currentTier() {
        return this.dashboardData?.currentTier || 'Standard';
    }

    get isStandard() {
        return this.currentTier === 'Standard';
    }

    get isPrincipal() {
        return this.currentTier === 'Principal';
    }

    get isMaestro() {
        return this.currentTier === 'Maestro';
    }

    get isAmbassador() {
        return this.currentTier === 'Ambassador';
    }

    get badgeLabel() {
        return this.currentTier;
    }

    get badgeClass() {
        if (this.isAmbassador) return 'mbp-badge mbp-badge-ambassador';
        if (this.isMaestro) return 'mbp-badge mbp-badge-maestro';
        if (this.isPrincipal) return 'mbp-badge mbp-badge-principal';
        return 'mbp-badge mbp-badge-principal';
    }

    get showHeroBadge() {
        return !this.isStandard;
    }

    get heroBadgeImg() {
        if (this.isPrincipal) return this.wayToMaestro;
        if (this.isMaestro) return this.wayToAmbassador;
        if (this.isAmbassador) return this.NowInAmbassador;
        return '';
    }

    get heroBadgeText() {
        if (this.isPrincipal) return 'Your way to Maestro';
        if (this.isMaestro) return 'Your way to Ambassador';
        if (this.isAmbassador) return 'Now in Ambassador';
        return '';
    }

    get principalBadgeImg() {
        if (this.isPrincipal || this.isMaestro || this.isAmbassador) return this.principalunlocked;
        return this.principalBadge;
    }

    get maestroBadgeImg() {
        if (this.isMaestro || this.isAmbassador) return this.maestrounlocked;
        return this.maestroBadge;
    }

    get ambassadorBadgeImg() {
        if (this.isAmbassador) return this.ambassdorunlocked;
        return this.ambassadorBadge;
    }

    get nextTier() {
        const tier = this.dashboardData?.nextTier || '';
        if (tier === 'Maximum') {
            return 'Maximum Target';
        }
        return tier;
    }

    get principalRange() {
        const min = formatCurrency(this.dashboardData?.principalMin);
        const max = formatCurrency(this.dashboardData?.principalMax);
        return min && max ? `${min} – ${max}` : '';
    }

    get maestroRange() {
        const min = formatCurrency(this.dashboardData?.maestroMin);
        const max = formatCurrency(this.dashboardData?.maestroMax);
        return min && max ? `${min} – ${max}` : '';
    }

    get ambassadorRange() {
        const min = formatCurrency(this.dashboardData?.ambassadorMin);
        return min ? `${min}+` : '';
    }

    get principalCardClass() {
        return 'mbp-tier-card' + (this.isPrincipal ? ' mbp-tier-card-active' : '');
    }

    get maestroCardClass() {
        return 'mbp-tier-card' + (this.isMaestro ? ' mbp-tier-card-active' : '');
    }

    get ambassadorCardClass() {
        return 'mbp-tier-card' + (this.isAmbassador ? ' mbp-tier-card-active' : '');
    }

    handleNavClick(event) {
        event.preventDefault();
        const menuItems = this.template.querySelectorAll('.mbp-menu-item');
        if (menuItems) {
            menuItems.forEach(el => el.classList.remove('mbp-menu-item-active'));
        }
        event.currentTarget.classList.add('mbp-menu-item-active');

        const href = event.currentTarget.getAttribute('href');
        const sectionId = href.replace('#', '');
        const section = this.template.querySelector(`[data-id="${sectionId}"]`);

        if (section) {
            section.scrollIntoView({ behavior: 'smooth', block: 'start' });
            setTimeout(() => {
                const headerHeight = 80;
                const sectionTop = section.getBoundingClientRect().top + window.pageYOffset;
                const expectedPosition = sectionTop - headerHeight;
                if (Math.abs(window.pageYOffset - expectedPosition) > 5) {
                    window.scrollTo({ top: expectedPosition, behavior: 'smooth' });
                }
            }, 150);
        }
    }

    handleHeaderNav(event) {
        const tab = event.currentTarget.dataset.tab;
        const map = {
            Dashboard: '/',
            Properties: '/properties?tab=units',
            Leads: '/Leads',
            Commissions: '/commissions',
            Updates: '/Updates',
            'My Agency': '/myagency',
            Help: '/help'
        };
        const url = map[tab];
        if (url) {
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: { url }
            });
        }
    }

    @wire(getEventsDynamic, { mode: 'Future', startDate: null, endDate: null })
    wiredEvents({ data, error }) {
        if (data) {
            this.events = data;
        }
        if (error) {
            console.error('Error fetching events', error);
        }
    }

    get formattedEvents() {
        if (!this.events || this.events.length === 0) {
            return [];
        }
        return this.events.map(evt => ({
            id: evt.Id,
            title: evt.Name,
            type: evt.Type__c,
            location: evt.Location__c,
            link: evt.External_Link__c,
            startDate: this.formatDate(evt.Start_Date_and_Time__c),
            endDate: this.formatDate(evt.End_Date_and_Time__c),
            startDateTime: evt.Start_Date_and_Time__c,
            endDateTime: evt.End_Date_and_Time__c,
            startTime: this.formatTime(evt.Start_Date_and_Time__c),
            endTime: this.formatTime(evt.End_Date_and_Time__c),
            description: evt.Description__c,
            socialLink: evt.Social_Media_Link__c,
            virtualTourLink: evt.Virtual_Tour_Link__c
        }));
    }

    handleEventClick(event) {
    if (event.target.tagName === 'A' || event.target.closest('a')) {
        return;
    }

    sessionStorage.setItem('activeTab', 'Updates');
this[NavigationMixin.Navigate]({
    type: 'comm__namedPage',
    attributes: {
        name: 'updates__c' // ⚠️ your actual page API name
    }
});


}

    stopPropagation(event) {
        event.stopPropagation();
    }

    formatDate(dt) {
        if (!dt) return '';
        const date = new Date(dt);
        return date.toLocaleDateString('en-US', {
            year: 'numeric',
            month: 'short',
            day: 'numeric'
        });
    }

    formatTime(dt) {
        if (!dt) return '';
        const date = new Date(dt);
        return date.toLocaleTimeString('en-US', {
            hour: '2-digit',
            minute: '2-digit',
            hour12: true
        });
    }

    formatDateTime(dt) {
        if (!dt) return '';
        return `${this.formatDate(dt)} at ${this.formatTime(dt)}`;
    }

    hasDifferentEndDate(evt) {
        if (!evt.startDate || !evt.endDate) return false;
        return evt.startDate !== evt.endDate;
    }

    isMultiDayEvent(evt) {
        if (!evt.startDateTime || !evt.endDateTime) return false;
        const start = new Date(evt.startDateTime);
        const end = new Date(evt.endDateTime);
        return end.getDate() !== start.getDate() || end.getMonth() !== start.getMonth();
    }

    getEventDuration(evt) {
        if (!evt.startDateTime || !evt.endDateTime) return '';
        const start = new Date(evt.startDateTime);
        const end = new Date(evt.endDateTime);
        const diffTime = Math.abs(end - start);
        const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));

        if (diffDays === 1) return '1 day';
        if (diffDays > 1) return `${diffDays} days`;
        return '';
    }

    @track nextMilestoneValue = '';

    renderedCallback() {
    if (!this.nextMilestoneValue && this.dashboardData) {
        const sales = Number(this.dashboardData.currentSales);

        if (sales < 60000000) this.nextMilestoneValue = '60M';
        else if (sales < 200000000) this.nextMilestoneValue = '200M';
        else if (sales < 500000000) this.nextMilestoneValue = '500M';
        else this.nextMilestoneValue = '9,999,999,999';
    }
}
}