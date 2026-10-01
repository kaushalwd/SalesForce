import { LightningElement, track } from 'lwc';
import getUserInfo from '@salesforce/apex/MBP_BrokerOpportunityController.getUserInfo';
import getOpportunitiesForAgency from '@salesforce/apex/MBP_BrokerOpportunityController.getOpportunitiesForAgency';

import getSalesOrdersForOpportunity from '@salesforce/apex/MBP_BrokerOpportunityController.getSalesOrdersForOpportunity';

export default class OpportunityTableMain extends LightningElement {
    @track opportunities = [];
    @track selectedOpportunity = {};
    @track showOverview = false;
    @track showFilters = false;
    @track isLoading = true;

    @track filters = {
        name: '',
        email: '',
        mobile: '',
        agentName: '',
        salesManager: '',
        status: '',
        residentStatus: '',
        project: ''
    };

    @track projectOptions = [];

    @track salesOrders = [];
    @track salesOrderColumns = [
        { label: 'Project', fieldName: 'ProjectInterest__c' },
        { label: 'Unit', fieldName: 'Unit_Name__c', type: 'text' },
        { label: 'No Of Rooms', fieldName: 'Number_of_bedrooms__c', type: 'text' },
        { label: 'Amount', fieldName: 'TotalAmount__c', type: 'currency' },
        { label: 'Status', fieldName: 'Status__c', type: 'text' }
    ];

    @track columns = [
        { label: 'Name', fieldName: 'Name' },
        { label: 'Email', fieldName: 'Email__c' },
        { label: 'Mobile', fieldName: 'Mobile__c' },
        { label: 'Resident Status', fieldName: 'UAE_Resident_Status__c' },
        { label: 'Project', fieldName: 'projectName' },
        { label: 'Sales Manager', fieldName: 'salesManagerName' },
        { label: 'Agent Name', fieldName: 'brokerAgentName' },
        {
            type: 'button-icon',
            typeAttributes: {
                iconName: 'utility:preview',
                alternativeText: 'View',
                variant: 'bare'
            },
            label: '',
            fieldName: 'Id',
            cellAttributes: { alignment: 'center' },
            fixedWidth: 40,
        }
    ];

    get brokerAgencyName() {
        return this.selectedOpportunity?.BrokerAgency__r?.Name || '';
    }

    get projectName() {
        return this.selectedOpportunity?.ProjectInterest__c || '';
    }

    get brokerAgentName() {
        return this.selectedOpportunity?.BrokerAgent__r?.Name || '';
    }

    get salesManagerName() {
        return this.selectedOpportunity?.SalesManager__r?.FirstName || '';
    }

    connectedCallback() {
        this.loadOpportunities();
    }

    async loadOpportunities() {
        this.isLoading = true;
        try {
            const user = await getUserInfo();
            const accountId = user?.Contact?.AccountId;

            if (accountId) {
                const results = await getOpportunitiesForAgency({ accountId });

                this.opportunities = results.map((opp) => {
                    return {
                        Id: opp.Id,
                        Name: opp.Name,
                        StageName: opp.StageName,
                        Email__c: opp.Email__c,
                        Mobile__c: opp.Mobile__c,
                        projectName: opp.ProjectInterest__c || '',
                        brokerAgentName: opp.BrokerAgentName || '',
                        salesManagerName: opp.SalesManagerName || '',
                        brokerAgencyName: opp.BrokerAgencyName || '',
                        UAE_Resident_Status__c: opp.UAE_Resident_Status__c || '',
                        ProjectInterest__c: opp.ProjectInterest__c || '',
                        Nationality__c: opp.Nationality__c || '',
                        BrokerAgent__c: opp.BrokerAgent__c
                    };
                });
            }
        } catch (error) {
            console.error('❌ Error loading Opportunities:', error);
        } finally {
            this.isLoading = false;
        }
    }

    toggleFilterPanel() {
        this.showFilters = !this.showFilters;
    }

    handleFilterChange(event) {
        const field = event.target.dataset.id;
        this.filters[field] = event.target.value;
    }

   async handleRowAction(event) {
    const flatRow = event.detail.row;

    this.selectedOpportunity = {
        ...flatRow,
        BrokerAgent__r: { Name: flatRow.brokerAgentName || '' },
        SalesManager__r: { FirstName: flatRow.salesManagerName || '' },
        BrokerAgency__r: { Name: flatRow.brokerAgencyName || '' }
    };


    this.showOverview = true;

    try {
        const result = await getSalesOrdersForOpportunity({ opportunityId: flatRow.Id });

        // ✅ Flatten nested ProjectInterest__c from Opportunity
        this.salesOrders = result.map(order => {
            return {
                ...order,
                ProjectInterest__c: order.Opportunity__r?.ProjectInterest__c || ''
            };
        });

    } catch (error) {
        console.error('❌ Error fetching sales orders:', error);
    }
}


    handleBack() {
        this.selectedOpportunity = null;
        this.salesOrders = [];
        this.showOverview = false;
    }
}