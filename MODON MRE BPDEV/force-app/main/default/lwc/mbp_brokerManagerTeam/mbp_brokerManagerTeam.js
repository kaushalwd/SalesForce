import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import getTeamUsers from '@salesforce/apex/MBP_UserTeamController.getTeamUsers';
import twitterIcon from '@salesforce/resourceUrl/twitter';
import linkedInIcon from '@salesforce/resourceUrl/linkedin';
import PHONE_ICON from '@salesforce/resourceUrl/PhoneIcon';
import EMAIL_ICON from '@salesforce/resourceUrl/email';
import Whatsaplogo from "@salesforce/resourceUrl/Whatsaplogo";

export default class MbpBrokerManagerTeam extends NavigationMixin(LightningElement) {
    whatsaplogo = Whatsaplogo;
    twitterIconUrl = twitterIcon;
    linkedInIconUrl = linkedInIcon;
    phoneIcon = PHONE_ICON;
    email = EMAIL_ICON;

    @track isLoading = true;
    @track brokerManagementTeam = [];
    @track salesTeam = [];
    @track error;
    @track showContactUs = true;
    @track showCases = false;
    @track showPolicy = false;
        @track showRequests = false;
    @track showAspire = false;

    get contactUsTabClass() { 
        return this.showContactUs ? 'tab-button active-tab' : 'tab-button'; 
    }
    
    get casesTabClass() { 
        return this.showCases ? 'tab-button active-tab' : 'tab-button'; 
    }

    get policyTabClass() { 
        return this.showPolicy ? 'tab-button active-tab' : 'tab-button'; 
    }
    
     get requestTabClass() { 
        return this.showRequests ? 'tab-button active-tab' : 'tab-button'; 
    }

       //For aspire 

      get AspireDashboardTabclass() { 
        return this.showAspire ? 'tab-button active-tab' : 'tab-button'; 
    }

    @wire(getTeamUsers)
    wiredUsers({ error, data }) {
        if (data) {
            this.brokerManagementTeam = data.BrokerManagementTeam;
            this.salesTeam = data.SalesTeam;
            this.isLoading = false;
        } else if (error) {
            this.error = error?.body?.message || 'Unknown error';
            this.isLoading = false;
        }
    }

    connectedCallback() {
        // Initialize tab state from URL
        const urlParams = new URLSearchParams(window.location.search);
        const tabParam = urlParams.get('tab');
        if (tabParam) {
            this.setActiveTab(tabParam);
        }
    }

    @wire(CurrentPageReference)
    wiredPageReference(pageRef) {
        if (pageRef && pageRef.state?.tab) {
            this.setActiveTab(pageRef.state.tab);
        }
    }

    setActiveTab(tab) {
        // Only update if tab is valid and different from current
        if (['contact', 'cases', 'policy','Broker Requests','aspire'].includes(tab) && 
            !(tab === 'contact' && this.showContactUs) &&
            !(tab === 'cases' && this.showCases) &&
            !(tab === 'policy' && this.showPolicy)&&
            !(tab === 'Broker Requests' && this.showRequests)&&
            !(tab === 'aspire' && this.showAspire)) {
            
            this.showContactUs = tab === 'contact';
            this.showCases = tab === 'cases';
            this.showPolicy = tab === 'policy';
            this.showRequests = tab === 'Broker Requests';
             this.showAspire = tab === 'aspire';
            this.updateUrl(tab);
        }
    }

    showContactUsTab() {
        this.setActiveTab('contact');
    }

    showCasesTab() {
        this.setActiveTab('cases');
    }

    showPolicyTab() {
        this.setActiveTab('policy');
    }

    showrequesttab(){

        this.setActiveTab('Broker Requests');

    }

      showAspireTab() {
        this.setActiveTab('aspire');
    }


    updateUrl(tab) {
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: `/help?tab=${tab}`
            },
            state: {
                tab: tab
            }
        }, true);
    }
}