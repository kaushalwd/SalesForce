import { LightningElement, wire, track } from 'lwc';
import { getObjectInfo, getPicklistValuesByRecordType } from 'lightning/uiObjectInfoApi';
import CASE_OBJECT from '@salesforce/schema/Case';

import getCases from '@salesforce/apex/ManagerBoardCaseController.getCases';

export default class CaseDataTable extends LightningElement {
    @track allData = [];
    @track pageData = [];
    @track error;

    // pagination
    pageSize = 20;
    currentPage = 1;
    totalPages = 0;

    // sorting
    sortedBy;
    sortedDirection = 'asc';

    // recordTypeId + picklists (unchanged)
    recordTypeId;
    
    columns = [
        {
            label: 'Case Number',
            fieldName: 'caseUrl',
            type: 'url',
            typeAttributes: { label: { fieldName: 'caseNumber' } }
        },
        { label: 'Status',         fieldName: 'status',       sortable: true },
        { label: 'Created Date',   fieldName: 'createdDate',  type: 'date', sortable: true },
        { label: 'Owner',          fieldName: 'ownerName',    sortable: true },
        { label: 'Case Type',      fieldName: 'caseType' },
        { label: 'Category',       fieldName: 'caseCategory' },
        { label: 'Sub-Category',   fieldName: 'caseSubCategory' },
        { label: 'Primary Assignee', fieldName: 'primaryAssignee' },
        { label: 'Requestor Name', fieldName: 'requestorName' },
        { label: 'Breached',       fieldName: 'breached',     type: 'boolean' },
        { label: 'SR Number',      fieldName: 'srNumber' }
       
    ];

    // wire to pick up record type & dependent picklists (same as before)
    @wire(getObjectInfo, { objectApiName: CASE_OBJECT })
    objectInfo({ data }) {
        if (data) this.recordTypeId = data.defaultRecordTypeId;
    }

    
    // wire your cases and initialize pagination
    wiredResult;
    @wire(getCases)
    wiredCases(result) {
        this.wiredResult = result;
        const { data, error } = result;
        if (data) {
            this.allData = data;
            this.totalPages = Math.ceil(data.length / this.pageSize);
            this.setPageData();
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.allData = [];
            this.pageData = [];
        }
    }

    setPageData() {
        const start = (this.currentPage - 1) * this.pageSize;
        this.pageData = this.allData.slice(start, start + this.pageSize);
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

    // getters for disabling buttons
    get isPreviousDisabled() { return this.currentPage === 1; }
    get isNextDisabled()     { return this.currentPage === this.totalPages; }

    // sort handler
    handleSort(event) {
        const { fieldName, sortDirection } = event.detail;
        this.sortedBy = fieldName;
        this.sortedDirection = sortDirection;

        let cloneData = [...this.allData];
        cloneData.sort((a, b) => {
            let valA = a[fieldName] ? a[fieldName].toString().toLowerCase() : '';
            let valB = b[fieldName] ? b[fieldName].toString().toLowerCase() : '';
            return valA > valB ? 1 : valA < valB ? -1 : 0;
        });
        if (sortDirection === 'desc') cloneData.reverse();

        this.allData = cloneData;
        this.currentPage = 1;
        this.setPageData();
    }
}