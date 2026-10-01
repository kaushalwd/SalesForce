import getFieldSetColumns from '@salesforce/apex/MBP_PropertiesFieldSetController.getFieldSetColumns';
import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';

export default class MBP_PropertiesFieldSetController extends NavigationMixin(LightningElement) {
    @track isProjectsActive = true;
    @track isUnitsActive = false;
    @track isMarketingActive = false;

    @track stayTrue = true;
    @track selectedTab = 'projects';
    @track activeObject = 'Project__c';
    @track activeFields = [];
    @track activeFilters = ['Name', 'District__r.Name'];
    @track activeColumns = [];
    @track activePage = 'Broker_Portal_Project_Detail_Page';
    @track imageMatchField = 'Name';
    @track documentMatchField = 'Project__r.Name';
    @track loading = false;
    @track loadError;

    get isProjectsTab() {
        return this.selectedTab === 'projects';
    }

    get isUnitsTab() {
        return this.selectedTab === 'units';
    }

    get isMarketingTab() {
        return this.selectedTab === 'marketing';
    }

    get projectsTabClass() {
        return this.isProjectsActive ? 'tab-button active' : 'tab-button';
    }

    get unitsTabClass() {
        return this.isUnitsActive ? 'tab-button active' : 'tab-button';
    }

    get marketingTabClass() {
        return this.isMarketingActive ? 'tab-button active' : 'tab-button';
    }

    connectedCallback() {
        const savedTab = localStorage.getItem('selectedTab') || 'units';

        if (savedTab === 'units') {
            this.showUnits();
        } else if (savedTab === 'marketing') {
            this.showMarketing();
        } else {
            this.showProjects();
        }
    }


    showProjects() {
        this.isProjectsActive = true;
        this.isUnitsActive = false;
        this.isMarketingActive = false;
        this.selectedTab = 'projects';
        try { localStorage.setItem('selectedTab', 'projects'); } catch (e) { }

        this.activeObject = 'Project__c';
        this.activeFilters = ['Name', 'District__r.Name'];
        this.activePage = 'Broker_Portal_Project_Detail_Page';
        this.imageMatchField = 'Name';
        this.documentMatchField = 'Project__r.Name';

        this.activeColumns = [];
        this.activeFields = [];
        this.loadColumns('Project__c');
    }

    showUnits() {
        this.isProjectsActive = false;
        this.isUnitsActive = true;
        this.isMarketingActive = false;
        this.selectedTab = 'units';
        try { localStorage.setItem('selectedTab', 'units'); } catch (e) { }

        this.activeObject = 'Unit__c';
        this.activeFilters = ['Project_Name__c', 'Type__c', 'Typology__c', 'Number_of_Bedrooms__c'];
        this.activePage = 'Broker_Portal_Unit_Detail_Page';
        this.imageMatchField = 'Project_Name__c';
        this.documentMatchField = 'Project__r.Name';

        this.activeColumns = [];
        this.activeFields = [];
        this.loadColumns('Unit__c');
    }

    showMarketing() {
        this.isProjectsActive = false;
        this.isUnitsActive = false;
        this.isMarketingActive = true;
        this.selectedTab = 'marketing';
        try { localStorage.setItem('selectedTab', 'marketing'); } catch (e) { }

        this.activeObject = 'Project__c';
        this.activeFilters = ['Name'];
        this.activePage = 'Broker_Portal_Project_Detail_Page';
        this.imageMatchField = 'Name';
        this.documentMatchField = 'Project__r.Name';

        this.activeColumns = [];
        this.activeFields = [];
        this.loadColumns('Project__c');
    }



    async loadColumns(objectApiName) {
        this.loading = true;
        this.loadError = undefined;
        try {
            const cols = await getFieldSetColumns({
                objectName: objectApiName,
                fieldSetName: 'Properties_Fields'
            });
            const normalized = (cols || []).map(c => {
                const api = c.fieldName || c.fieldPath;
                const key = api.replace(/\./g, '_');
                return { label: c.label || api, fieldName: key, apiName: api };
            });
            const hasDistrict = normalized.some(c => c.apiName === 'District__c');
            if (hasDistrict) {
                normalized.push({
                    label: 'District Name',
                    fieldName: 'District__r_Name',
                    apiName: 'District__r.Name'
                });
            }


            normalized.push({
                label: '',
                type: 'button-icon',
                typeAttributes: {
                    iconName: 'utility:preview',
                    alternativeText: 'View',
                    variant: 'bare'
                },
                fieldName: 'Id',
                cellAttributes: { alignment: 'center' },
                fixedWidth: 40
            });

            this.activeColumns = normalized;
            this.activeFields = normalized.filter(c => !!c.apiName).map(c => c.apiName);
        } catch (e) {
            this.loadError = e?.body?.message || e?.message || 'Failed to load field set columns';
            this.activeColumns = [
                { label: 'Name', fieldName: 'Name', apiName: 'Name' },
                { label: 'View', fieldName: '_view', apiName: '_view' }
            ];
            this.activeFields = ['Name'];
        } finally {
            this.loading = false;
        }
    }


    navigateToProjectsPage() {
        
        try { localStorage.setItem('selectedTab', 'projects'); } catch (e) { }
        
        if (this._currentPageName !== 'properties__c') {
            this[NavigationMixin.Navigate]({
                type: 'comm__namedPage',
                attributes: { name: 'properties__c' },
                state: { tab: 'projects' }
            });
            return;
        }
        
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: { name: 'properties__c' },
            state: { tab: 'projects' }
        });
        
        this.showProjects();
    }

    navigateTomarketingPage() {
        
        try { localStorage.setItem('selectedTab', 'marketing'); } catch (e) { }
        
        if (this._currentPageName !== 'properties__c') {
            this[NavigationMixin.Navigate]({
                type: 'comm__namedPage',
                attributes: { name: 'properties__c' },
                state: { tab: 'marketing' }
            });
            return;
        }
        
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: { name: 'properties__c' },
            state: { tab: 'marketing' }
        });
        
        this.showMarketing();
    }


    @wire(CurrentPageReference)
    setCurrentPageReference(pageRef) {
        this._currentPageName = pageRef?.attributes?.name;
        const urlTab = pageRef?.state?.tab;

        
        let target = urlTab;
        if (!target) {
            try {
                target = localStorage.getItem('selectedTab');
            } catch (e) { /* ignore */ }
        }
        if (target !== 'units' && target !== 'marketing' && target !== 'projects') {
            target = 'projects';
        }

        if (target === 'units') this.showUnits();
        else if (target === 'marketing') this.showMarketing();
        else this.showProjects(); 
    }

    navigateToUnitsPage() {
        
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: { name: 'Unit_List_Page__c' },
            state: { tab: 'units' }
        });

    }

}