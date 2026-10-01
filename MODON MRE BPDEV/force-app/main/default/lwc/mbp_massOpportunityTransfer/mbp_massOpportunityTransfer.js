import { LightningElement, wire, track } from 'lwc';

import getEOIRecords
from '@salesforce/apex/MBP_OpportunityMassTransferController.getEOIRecords';

import changeOpportunityOwners
from '@salesforce/apex/MBP_OpportunityMassTransferController.changeOpportunityOwners';

import { ShowToastEvent }
from 'lightning/platformShowToastEvent';

import { refreshApex }
from '@salesforce/apex';

const COLUMNS = [

    {
        label: 'EOI Name',
        fieldName: 'eoiUrl',
        type: 'url',
        sortable: true,
        typeAttributes: {
            label: { fieldName: 'Name' },
            target: '_blank'
        }
    },

    {
        label: 'EOI ID',
        fieldName: 'EOIId__c',
        sortable: true
    },

    {
        label: 'Created Date',
        fieldName: 'CreatedDate',
        type: 'date',
        sortable: true,
        typeAttributes: {
            year: 'numeric',
            month: 'short',
            day: '2-digit'
        }
    },

    {
        label: 'Broker Agency',
        fieldName: 'brokerUrl',
        type: 'url',
        sortable: true,
        typeAttributes: {
            label: { fieldName: 'BrokerAgencyName' },
            target: '_blank'
        }
    },

    {
        label: 'Broker Agent',
        fieldName: 'brokerAgentUrl',
        type: 'url',
        sortable: true,
        typeAttributes: {
            label: { fieldName: 'BrokerAgentName' },
            target: '_blank'
        }
    },

    {
        label: 'EOI Amount (AED)',
        fieldName: 'EOI_Amount_AED__c',
        type: 'currency',
        sortable: true,
        typeAttributes: {
            currencyCode: 'AED'
        }
    },

    {
        label: 'Bedrooms',
        fieldName: 'NumberofBedrooms__c',
        sortable: true
    },

    {
        label: 'Units',
        fieldName: 'Number_of_Units__c',
        sortable: true
    },

    {
        label: 'Opportunity Owner',
        fieldName: 'ownerUrl',
        type: 'url',
        sortable: true,
        typeAttributes: {
            label: { fieldName: 'OpportunityOwner' },
            target: '_blank'
        }
    }
];

export default class EoiMassTransfer extends LightningElement {

    columns = COLUMNS;

    @track records = [];
    @track paginatedRecords = [];

    selectedRows = [];

    selectedUserId;

    showModal = false;

    wiredResult;

    sortedBy;
    sortedDirection = 'asc';

    // Pagination

    pageSize = 20;
    pageNumber = 1;

    totalPages = 0;
    totalRecords = 0;
    @track isLoading = false;
    selectedRowIds = [];

    @track records = [];
@track paginatedRecords = [];

allRecords = [];
searchKey = '';

    @wire(getEOIRecords)
    wiredEOIs(result) {

        this.wiredResult = result;

        if(result.data) {

          this.allRecords = result.data.map(row => {

    return {

        ...row,

        eoiUrl:
            '/' + row.Id,

        brokerUrl:
            row.BrokerAgency__c
            ? '/' + row.BrokerAgency__c
            : '',

        brokerAgentUrl:
            row.BrokerAgent__c
            ? '/' + row.BrokerAgent__c
            : '',

        ownerUrl:
            row.Opportunity__r?.OwnerId
            ? '/' + row.Opportunity__r.OwnerId
            : '',

        BrokerAgencyName:
            row.BrokerAgency__r?.Name || '',

        BrokerAgentName:
            row.BrokerAgent__r?.Name || '',

        OpportunityOwner:
            row.Opportunity__r?.Owner?.Name || ''
    };
});

            this.records = [...this.allRecords];

this.totalRecords = this.records.length;

            this.totalPages = Math.ceil(
                this.totalRecords / this.pageSize
            );

            this.updatePaginatedRecords();
        }
    }

    updatePaginatedRecords() {

        const start =
            (this.pageNumber - 1) * this.pageSize;

        const end =
            start + this.pageSize;

        this.paginatedRecords =
            [...this.records].slice(start, end);
    }

    handleRowSelection(event) {

    this.selectedRows =
        event.detail.selectedRows;

    this.selectedRowIds =
        this.selectedRows.map(
            row => row.Id
        );
}

    get disableButton() {
        return this.selectedRows.length === 0;
    }

    openModal() {
        this.showModal = true;
    }

    closeModal() {
        this.showModal = false;
    }

    handleUserChange(event) {
        this.selectedUserId =
            event.detail.recordId;
    }

   handleSubmit() {

    if(!this.selectedUserId) {

        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                message: 'Please select a user',
                variant: 'error'
            })
        );

        return;
    }

    this.isLoading = true;

    const selectedIds =
        this.selectedRows.map(
            row => row.Id
        );

    changeOpportunityOwners({

        eoiIds: selectedIds,
        newOwnerId: this.selectedUserId

    })
    .then(() => {

        this.dispatchEvent(

            new ShowToastEvent({
                title: 'Success',
                message:
                    'Opportunity owners updated successfully',
                variant: 'success'
            })
        );

        this.showModal = false;

        // Clear selections

        this.selectedRows = [];
        this.selectedRowIds = [];

        // Refresh latest data

        return refreshApex(
            this.wiredResult
        );
    })
    .then(() => {

        // Reset pagination

        this.pageNumber = 1;

        this.updatePaginatedRecords();
    })
    .catch(error => {

        this.dispatchEvent(

            new ShowToastEvent({
                title: 'Error',
                message:
                    error.body?.message ||
                    'Unknown error',
                variant: 'error'
            })
        );
    })
    .finally(() => {

        this.isLoading = false;
    });
}

    // Sorting

    doSorting(event) {

        this.sortedBy =
            event.detail.fieldName;

        this.sortedDirection =
            event.detail.sortDirection;

        let records =
            [...this.records];

        records.sort((a, b) => {

            let valA =
                a[this.sortedBy] || '';

            let valB =
                b[this.sortedBy] || '';

            return this.sortedDirection === 'asc'
                ? (valA > valB ? 1 : -1)
                : (valA < valB ? 1 : -1);
        });

        this.records = records;

        this.updatePaginatedRecords();
    }

    handlePrevious() {

        if(this.pageNumber > 1) {

            this.pageNumber--;

            this.updatePaginatedRecords();
        }
    }

    handleNext() {

        if(this.pageNumber < this.totalPages) {

            this.pageNumber++;

            this.updatePaginatedRecords();
        }
    }

    get disablePrevious() {
        return this.pageNumber <= 1;
    }

    get disableNext() {
        return this.pageNumber >= this.totalPages;
    }

    handleSearch(event) {

    this.searchKey =
        event.target.value?.toLowerCase() || '';

    if (!this.searchKey) {

        this.records = [...this.allRecords];

    } else {

        this.records = this.allRecords.filter(record => {

            const eoiName =
                (record.Name || '').toLowerCase();

            const eoiId =
                (record.EOIId__c || '').toLowerCase();

            return eoiName.includes(this.searchKey) ||
                   eoiId.includes(this.searchKey);
        });
    }

    this.pageNumber = 1;

    this.totalRecords = this.records.length;

    this.totalPages = Math.ceil(
        this.totalRecords / this.pageSize
    ) || 1;

    this.updatePaginatedRecords();
}
}