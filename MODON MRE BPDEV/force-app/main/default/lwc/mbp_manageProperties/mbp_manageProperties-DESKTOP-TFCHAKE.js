import { LightningElement, track } from 'lwc';
import getFieldSetColumns from '@salesforce/apex/MBP_PropertiesFieldSetController.getFieldSetColumns';

export default class MBP_PropertiesFieldSetController extends LightningElement {
    @track isProjectsActive = true;
    @track isUnitsActive = false;
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
    
    get isProjectsTab() { return this.selectedTab === 'projects'; }
    get isUnitsTab() { return this.selectedTab === 'units'; }
    get projectsTabClass() { return this.isProjectsActive ? 'tab-button active' : 'tab-button'; }
    get unitsTabClass() { return this.isUnitsActive ? 'tab-button active' : 'tab-button'; }

    connectedCallback() {
        this.showProjects();
    }

    showProjects() {
        this.isProjectsActive = true;
        this.isUnitsActive = false;
        this.selectedTab = 'projects';
        this.activeObject = 'Project__c';
        this.activeFilters = ['Name', 'District__r.Name'];
        this.activePage = 'Broker_Portal_Project_Detail_Page';
        this.imageMatchField = 'Name';
        this.documentMatchField = 'Project__r.Name';
        this.loadColumns('Project__c');
    }

    showUnits() {
        this.isProjectsActive = false;
        this.isUnitsActive = true;
        this.selectedTab = 'units';
        this.activeObject = 'Unit__c';
        this.activeFilters = ['Project_Name__c', 'Type__c', 'Typology__c', 'Number_of_Bedrooms__c'];
        this.activePage = 'Broker_Portal_Unit_Detail_Page';
        this.imageMatchField = 'Project_Name__c';
        this.documentMatchField = 'Project__r.Name';
        this.loadColumns('Unit__c');
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
        return {
            label: c.label || api,
            fieldName: key,   
            apiName: api      
        };
        });

        this.activeColumns = normalized;
        this.activeFields  = normalized.map(c => c.apiName); 

                } catch (e) {
                    this.loadError = e?.body?.message || e?.message || 'Failed to load field set columns';
                    this.activeColumns = [{ label: 'Name', fieldName: 'Name', apiName: 'Name' }];
                    this.activeFields = ['Name'];
                    console.error('Field set load error:', e);
                } finally {
                    this.loading = false;
                }
            }
        }