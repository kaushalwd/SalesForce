import { LightningElement, wire, track } from 'lwc';
import getLeadsWithTasks from '@salesforce/apex/ManagerBoardLeadTaskController.getLeadsWithTasks';

const PAGE_SIZE = 20;

export default class LeadTaskPivot extends LightningElement {
    sortedBy;
    sortedDirection = 'asc';
    @track allData = [];
    @track pageData = [];
    @track columns = [
        { label: 'Lead Source', fieldName: 'leadSource' },
        { label: 'Owner', fieldName: 'ownerName' },
        { label: 'Created Date', fieldName: 'createdDate', type: 'date', sortable: true },
        { label: 'Status', fieldName: 'status', sortable: true },
       // { label: 'Lead Number', fieldName: 'leadNumber' },
        { 
        label: 'Lead Number',
        fieldName: 'leadUrl',
        type: 'url',
        typeAttributes: {
            label: { fieldName: 'leadNumber' }/*
            target: '_blank'*/
        },
        sortable: true
    },
    { 
        label: 'Call 1',
        fieldName: 'task1Url',
        type: 'url',
        typeAttributes: {
            label: { fieldName: 'task1' }/*
            target: '_blank'*/
        }
    },
    { 
        label: 'Call 2',
        fieldName: 'task2Url',
        type: 'url',
        typeAttributes: {
            label: { fieldName: 'task2' }
            /*
            target: '_blank'*/
        }
    },
    { 
        label: 'Call 3',
        fieldName: 'task3Url',
        type: 'url',
        typeAttributes: {
            label: { fieldName: 'task3' }
        }
    }
        /*{ label: 'Call 1', fieldName: 'task1' },
        { label: 'Call 2', fieldName: 'task2' },
        { label: 'Call 3', fieldName: 'task3' }*/
    ];

    currentPage = 1;
    totalPages = 1;

    @wire(getLeadsWithTasks)
    wiredLeads({ error, data }) {
        if (data) {
            this.allData = data;
            this.totalPages = Math.ceil(data.length / PAGE_SIZE);
            this.setPageData();
        } else if (error) {
            console.error('Error retrieving data:', error);
        }
    }

    setPageData() {
        const start = (this.currentPage - 1) * PAGE_SIZE;
        const end = start + PAGE_SIZE;
        this.pageData = this.allData.slice(start, end);
    }

    handlePrevious() {
        if (this.currentPage > 1) {
            this.currentPage--;
            this.setPageData();
        }
    }

    handleNext() {
        if (this.currentPage < this.totalPages) {
            this.currentPage++;
            this.setPageData();
        }
    }

    get isPreviousDisabled() {
    return this.currentPage === 1;
}

    get isNextDisabled() {
    return this.currentPage === this.totalPages;
}

handleSort(event) {
    const { fieldName, sortDirection } = event.detail;
    this.sortedBy = fieldName;
    this.sortedDirection = sortDirection;

    // Clone the data to avoid mutating original
    let cloneData = [...this.allData];

    cloneData.sort((a, b) => {
        let valA = a[fieldName] ? a[fieldName].toString().toLowerCase() : '';
        let valB = b[fieldName] ? b[fieldName].toString().toLowerCase() : '';
        return valA > valB ? 1 : valA < valB ? -1 : 0;
    });

    if (sortDirection === 'desc') {
        cloneData.reverse();
    }

    this.allData = cloneData;
    // Reset to page 1 after sort
    this.currentPage = 1;
    this.setPageData();
}

}