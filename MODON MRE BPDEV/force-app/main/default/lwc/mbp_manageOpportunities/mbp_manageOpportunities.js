/**********************************************************************************************************************
* Name               : MBP_manageopportunities
* Description        : This class is used as the lwc for Broker Portal opps.
* Usage              : LWC components for showing broker opps.
* Created By         : Upendra Reddy
* --------------------------------------------------------------------------------------------------------------------
* Version     Author                          Date             Comment
* 1.0         upendra.asam@activemindsit.com      27 Oct 2025      Initial Draft – Base implementation for opps ,
*  
* 1.1          raghu.chilukuri@activemindsit.com                        15 dec 2025       Mobile View Enhancements                                    

* 1.2       raghu.chilukuri@activemindsit.com        06 jan 2026     Updates include:
*                                                              - Fixed Filter issue.
*                                                              
**********************************************************************************************************************/

import { LightningElement, track ,api} from 'lwc';
import getUserInfo from '@salesforce/apex/MBP_BrokerOpportunityController.getUserInfo';
import getOpportunitiesForAgency from '@salesforce/apex/MBP_BrokerOpportunityController.getOpportunitiesForAgency';
import FilterIcon from '@salesforce/resourceUrl/Filter';
import getSalesOrdersForOpportunity from '@salesforce/apex/MBP_BrokerOpportunityController.getSalesOrdersForOpportunity';

export default class OpportunityTableMain extends LightningElement {
    @track opportunities = [];
    allOpportunities = [];
    @track selectedOpportunity = {};
    @track showOverview = false;
    @track showFilters = false;
    @track isLoading = true;
	    @track showMobileFilterBox = false;
    @track isMobile = false;
   @api recordId;
    filterIcon = FilterIcon;

    @track filters = {
        searchKey: '',
        residentStatus: '',
        stage: '',
        startDate: '',
        endDate: ''
    };
	
	//mobile
	
	 @track formattedSalesOrders = [];
	 
	  // Method to format amount
    formatAmount(amount) {
        if (!amount) return '$0.00';
        return '$' + parseFloat(amount).toFixed(2).replace(/\d(?=(\d{3})+\.)/g, '$&,');
    }
	
	    // Pagination properties
    @track currentPage = 1;
    @track pageSize = 10;
    @track totalPages = 1;
    @track disablePrev = true;
    @track disableNext = true;
	
	//upto above mobile

    residentStatusOptions = [
        { label: 'All', value: '' },
        { label: 'Resident', value: 'Resident' },
        { label: 'Non-Resident', value: 'Non-Resident' }
    ];

    // Stage options
    stageOptions = [
        { label: 'All', value: '' },
        { label: 'New', value: 'New' },
        { label: 'Discussion In Progress', value: 'Discussion In Progress' },
        { label: 'Unit Selection', value: 'Unit Selection' },
        { label: 'Closed Won', value: 'Closed Won' },
        { label: 'Closed Lost', value: 'Closed Lost' }
    ];

    @track showFilterBox = false;
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
       
        { label: 'S.No', fieldName: 'sno', type: 'number', initialWidth: 60 },
          { label: 'Status', fieldName: 'StageName', sortable: true },
        { label: 'Name', fieldName: 'Name', sortable: true },
        { label: 'Email', fieldName: 'Email__c', sortable: true },
        { label: 'Mobile', fieldName: 'Mobile__c', sortable: true },
        { label: 'Resident Status', fieldName: 'UAE_Resident_Status__c', sortable: true },
        { label: 'Project', fieldName: 'projectName', sortable: true },
        { label: 'Modon Rep', fieldName: 'salesManagerName', sortable: true },
        { label: 'Broker Name', fieldName: 'brokerAgentName', sortable: true },
       
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
            fixedWidth: 40
        }
    ];

    @track sortBy;
    @track sortDirection = 'asc';
	//mobile
	    get showPagination() {
        return this.opportunities && this.opportunities.length > 0;
    }

    get mobileFilterBoxClass() {
        return this.showMobileFilterBox ? 'mobile-filter-box visible' : 'mobile-filter-box';
    }
	
	//upto above mobile

    get computedColumns() {
        return this.columns.map(col => {
            if (!col.type || col.type !== 'button-icon') {
                return { ...col, sortable: true };
            }
            return col;
        });
    }

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
    this.checkMobileView();

    const today = new Date();
    const startOfYear = new Date(today.getFullYear(), 0, 1);
    this.filters.startDate = this.formatDate(startOfYear);
    this.filters.endDate = this.formatDate(today);

    this.loadOpportunities();
    window.addEventListener('resize', this.handleResize.bind(this));
}

    // Keep isMobile in sync with the actual viewport on every render. This
    // self-corrects the case where the component first mounted at desktop width
    // (e.g. switched in via the desktop tab) and a resize event never fired, so
    // the right view always renders instead of a blank page. Assigning the same
    // value is a no-op in LWC, so this won't cause a render loop.
    renderedCallback() {
        const mobile = window.innerWidth <= 768;
        if (mobile !== this.isMobile) {
            this.isMobile = mobile;
        }
    }

    formatDate(date) {
        const year = date.getFullYear();
        const month = String(date.getMonth() + 1).padStart(2, '0');
        const day = String(date.getDate()).padStart(2, '0');
        return `${year}-${month}-${day}`;
    }


    async loadOpportunities() {
    this.isLoading = true;
    try {
        const user = await getUserInfo();
        const accountId = user?.Contact?.AccountId;

        if (accountId) {
            // Pass the current filter dates (or null for defaults)
            const results = await getOpportunitiesForAgency({ 
                accountId: accountId,
                startDate: this.filters.startDate,
                endDate: this.filters.endDate
            });

            this.opportunities = results.map((opp, index) => ({
                sno: index + 1,
                Id: opp.Id,
                Name: opp.Name,
                StageName: opp.StageName,
                Email__c: opp.Email__c,
                Mobile__c: opp.Mobile__c,
                projectName: opp.ProjectName || '', 
                brokerAgentName: opp.BrokerAgentName || '',
                salesManagerName: opp.SalesManagerName || '',
                brokerAgencyName: opp.BrokerAgencyName || '',
                UAE_Resident_Status__c: opp.UAE_Resident_Status__c || '',
                ProjectInterest__c: opp.ProjectInterest__c || '',
                Nationality__c: opp.Nationality__c || '',
                BrokerAgent__c: opp.BrokerAgent__c,
                CreatedDate: opp.CreatedDate
            }));

            //  keep backup for filtering
            this.allOpportunities = [...this.opportunities];
            this.updatePagination();
        }
    } catch (error) {
        console.error('❌ Error loading Opportunities:', error);
    } finally {
        this.isLoading = false;
    }
}
@api
async focusOpportunityById(oppId) {
    if (!oppId) return;

    this.isLoading = true;
    try {
        await this.loadOpportunities(); // refresh so the just-converted Opp is present
        const flatRow = this.opportunities.find(o => o.Id === oppId);
        if (flatRow) {
            await this.handleRowAction({ detail: { row: flatRow } });
        } else {
            console.warn('Booked opportunity not found yet:', oppId);
        }
    } finally {
        this.isLoading = false;
    }
}
    get filterBoxClass() {
        return this.showFilterBox ? 'filter-box visible' : 'filter-box';
    }

    toggleFilterBox() {
        this.showFilterBox = !this.showFilterBox;
    }

    toggleFilterPanel() {
        this.showFilters = !this.showFilters;
    }

    handleExport() {
        if (!this.opportunities || this.opportunities.length === 0) {
           this.template.querySelector('c-mbp_customshowtoast').show(
            'No data to export',
            'Warning'
        );
        return;
        }

        const exportData = this.opportunities.map(opp => ({
           Status: opp.StageName,
        Name: opp.Name,
        Email: opp.Email__c,
        Mobile: opp.Mobile__c,
        'Resident Status': opp.UAE_Resident_Status__c,
        Project: opp.projectName,
        'Modon Rep': opp.salesManagerName,
        'Broker Name': opp.brokerAgentName
        }));

        const csv = this.convertToCSV(exportData);
        const encodedUri = 'data:text/csv;charset=utf-8,' + encodeURIComponent(csv);
        const link = document.createElement('a');
        link.setAttribute('href', encodedUri);
        link.setAttribute('download', 'OpportunitiesExport.csv');
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
    }

    convertToCSV(data) {
        if (!data || !data.length) return '';
        const header = Object.keys(data[0]).join(',');
        const rows = data.map(row =>
            Object.values(row)
                .map(value => `${value !== undefined && value !== null ? value : ''}`)
                .join(',')
        );
        return [header, ...rows].join('\n');
    }

    handleFilterChange(event) {
        const field = event.target.dataset.id;
        this.filters[field] = event.target.value;
    }

    applyFilters() {
    const { searchKey, residentStatus, stage, startDate, endDate } = this.filters;
    
    // Date filter - RELOAD DATA FROM SERVER WITH NEW DATES
    if (startDate || endDate) {
        // Call Apex with the selected dates
        this.isLoading = true;
        
        // Get user info first, then load opportunities with dates
        getUserInfo()
            .then(user => {
                const accountId = user?.Contact?.AccountId;
                
                if (accountId) {
                    return getOpportunitiesForAgency({
                        accountId: accountId,
                        startDate: startDate,
                        endDate: endDate
                    });
                }
                return [];
            })
            .then(results => {
                // Process the results (same as in loadOpportunities)
                const processedOpportunities = results.map((opp, index) => ({
                    sno: index + 1,
                    Id: opp.Id,
                    Name: opp.Name,
                    StageName: opp.StageName,
                    Email__c: opp.Email__c,
                    Mobile__c: opp.Mobile__c,
                    projectName: opp.ProjectName || '',
                    brokerAgentName: opp.BrokerAgentName || '',
                    salesManagerName: opp.SalesManagerName || '',
                    brokerAgencyName: opp.BrokerAgencyName || '',
                    UAE_Resident_Status__c: opp.UAE_Resident_Status__c || '',
                    ProjectInterest__c: opp.ProjectInterest__c || '',
                    Nationality__c: opp.Nationality__c || '',
                    BrokerAgent__c: opp.BrokerAgent__c,
                    CreatedDate: opp.CreatedDate
                }));
                
                // Update both arrays
                this.opportunities = [...processedOpportunities];
                this.allOpportunities = [...processedOpportunities];
                
                // Now apply local filters if any
                let filtered = [...this.opportunities];
                
                //  Fuzzy search
                if (searchKey) {
                    const key = searchKey.toLowerCase();
                    filtered = filtered.filter(o =>
                        (o.Name && o.Name.toLowerCase().includes(key)) ||
                        (o.Email__c && o.Email__c.toLowerCase().includes(key)) ||
                        (o.Mobile__c && o.Mobile__c.toLowerCase().includes(key))
                    );
                }

                //  Resident Status
                if (residentStatus) {
                    filtered = filtered.filter(o =>
                        o.UAE_Resident_Status__c?.toLowerCase() === residentStatus.toLowerCase()
                    );
                }

                //  Stage
                if (stage) {
                    filtered = filtered.filter(o =>
                        o.StageName?.toLowerCase() === stage.toLowerCase()
                    );
                }

                // Update with filtered results
                this.opportunities = filtered.map((opp, index) => ({ ...opp, sno: index + 1 }));
                
                // Close filter boxes
                if (this.isMobile) {
                    this.showMobileFilterBox = false;
                } else {
                    this.showFilterBox = false;
                }
                
                // Update pagination
                this.currentPage = 1;
                this.updatePagination();
            })
            .catch(error => {
                console.error('Error fetching filtered opportunities:', error);
                // Handle error
            })
            .finally(() => {
                this.isLoading = false;
            });
        
        return; // Exit early since we're loading from server
    }
    
    //  If NO date filter, apply local filters only
    let filtered = [...this.allOpportunities];
    
    //  Fuzzy search
    if (searchKey) {
        const key = searchKey.toLowerCase();
        filtered = filtered.filter(o =>
            (o.Name && o.Name.toLowerCase().includes(key)) ||
            (o.Email__c && o.Email__c.toLowerCase().includes(key)) ||
            (o.Mobile__c && o.Mobile__c.toLowerCase().includes(key))
        );
    }

    //  Resident Status
    if (residentStatus) {
        filtered = filtered.filter(o =>
            o.UAE_Resident_Status__c?.toLowerCase() === residentStatus.toLowerCase()
        );
    }

    //  Stage
    if (stage) {
        filtered = filtered.filter(o =>
            o.StageName?.toLowerCase() === stage.toLowerCase()
        );
    }

    // Update with filtered results
    this.opportunities = filtered.map((opp, index) => ({ ...opp, sno: index + 1 }));
    
    // Close filter boxes
    if (this.isMobile) {
        this.showMobileFilterBox = false;
    } else {
        this.showFilterBox = false;
    }
    
    // Update pagination
    this.currentPage = 1;
    this.updatePagination();
}

    resetFilters() {
    const today = new Date();
    const startOfYear = new Date(today.getFullYear(), 0, 1);

    this.filters = {
        searchKey: '',
        residentStatus: '',
        stage: '',
        startDate: this.formatDate(startOfYear),
        endDate: this.formatDate(today)
    };

    //  Reload opportunities with reset dates
    this.loadOpportunities();
    
    // Close filter boxes
    if (this.isMobile) {
        this.showMobileFilterBox = false;
    } else {
        this.showFilterBox = false;
    }
      this.currentPage = 1;
        this.updatePagination();
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

            //  Flatten nested ProjectInterest__c from Opportunity
            this.salesOrders = result.map(order => {
                return {
                    ...order,
                    ProjectInterest__c: order.Opportunity__r?.ProjectInterest__c || ''
                };
            });
			
			
              // Create formatted sales orders for mobile view
            this.formattedSalesOrders = result.map((order, index) => ({
                ...order,
                ProjectInterest__c: order.Opportunity__r?.ProjectInterest__c || '',
                displayIndex: index + 1,
                formattedAmount: this.formatAmount(order.TotalAmount__c)
            }));

        } catch (error) {
            console.error('❌ Error fetching sales orders:', error);
        }
    }

    handleSort(event) {
        this.sortBy = event.detail.fieldName;
        this.sortDirection = event.detail.sortDirection;

        let cloneData = [...this.opportunities];

        cloneData.sort((a, b) => {
            let valA = a[this.sortBy] ? a[this.sortBy].toString().toLowerCase() : '';
            let valB = b[this.sortBy] ? b[this.sortBy].toString().toLowerCase() : '';

            if (valA < valB) return this.sortDirection === 'asc' ? -1 : 1;
            if (valA > valB) return this.sortDirection === 'asc' ? 1 : -1;
            return 0;
        });

        //  Reassign S.No after sorting
        this.opportunities = cloneData.map((opp, index) => ({ ...opp, sno: index + 1 }));
		 this.updatePagination();
    }

    handleBack() {
        this.selectedOpportunity = null;
        this.salesOrders = [];
        this.showOverview = false;
    }
	
	//Mobile

     // Add this getter method
    get hasNoSalesOrders() {
        return this.salesOrders.length === 0;
    }
	    checkMobileView() {
        this.isMobile = window.innerWidth <= 768;
    }

    disconnectedCallback() {
        window.removeEventListener('resize', this.handleResize.bind(this));
    }

    handleResize() {
        this.checkMobileView();
    }

    // Mobile-specific filter toggle
    toggleMobileFilterBox() {
        this.showMobileFilterBox = !this.showMobileFilterBox;
    }

    handleMobileCardClick(event) {
        const opportunityId = event.currentTarget.dataset.id;
        this.handleMobileViewDetails({ currentTarget: { dataset: { id: opportunityId } } });
    }

    async handleMobileViewDetails(event) {
        const opportunityId = event.currentTarget.dataset.id;
        const flatRow = this.opportunities.find(opp => opp.Id === opportunityId);
        
        if (flatRow) {
            this.selectedOpportunity = {
                ...flatRow,
                BrokerAgent__r: { Name: flatRow.brokerAgentName || '' },
                SalesManager__r: { FirstName: flatRow.salesManagerName || '' },
                BrokerAgency__r: { Name: flatRow.brokerAgencyName || '' }
            };

            this.showOverview = true;

            try {
                const result = await getSalesOrdersForOpportunity({ opportunityId: flatRow.Id });
                this.salesOrders = result.map(order => ({
                    ...order,
                    ProjectInterest__c: order.Opportunity__r?.ProjectInterest__c || ''
                    
                }));

                         // Create formatted sales orders for mobile view
                this.formattedSalesOrders = result.map((order, index) => ({
                    ...order,
                    ProjectInterest__c: order.Opportunity__r?.ProjectInterest__c || '',
                    displayIndex: index + 1,
                    formattedAmount: this.formatAmount(order.TotalAmount__c)
                }));
           
            } catch (error) {
                console.error('Error fetching sales orders:', error);
            }
        }
    }

    // Helper method to format currency for mobile view
    formattedAmount(amount) {
        if (!amount) return '$0.00';
        return '$' + parseFloat(amount).toFixed(2).replace(/\d(?=(\d{3})+\.)/g, '$&,');
    }
	
	    // Pagination methods
    updatePagination() {
        this.totalPages = Math.ceil(this.opportunities.length / this.pageSize);
        this.disablePrev = this.currentPage <= 1;
        this.disableNext = this.currentPage >= this.totalPages;
    }

    handlePrevPage() {
        if (this.currentPage > 1) {
            this.currentPage--;
            this.updatePagination();
        }
    }

    handleNextPage() {
        if (this.currentPage < this.totalPages) {
            this.currentPage++;
            this.updatePagination();
        }
    }

    get paginatedOpportunities() {
        const startIndex = (this.currentPage - 1) * this.pageSize;
        const endIndex = startIndex + this.pageSize;
        return this.opportunities.slice(startIndex, endIndex);
    }
	
	
    get filterBoxClass() {
        return this.showFilterBox ? 'filter-box visible' : 'filter-box';
    }

    toggleFilterBox() {
        if (this.isMobile) {
            this.toggleMobileFilterBox();
        } else {
            this.showFilterBox = !this.showFilterBox;
        }
    }

    closeFilterBox(event) {
        if (event) event.stopPropagation();
        this.showFilterBox = false;
    }
	//upto above mobile
}