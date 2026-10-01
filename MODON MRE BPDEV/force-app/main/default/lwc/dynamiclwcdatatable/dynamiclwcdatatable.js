import { LightningElement, api, track } from 'lwc';

export default class Dynamiclwcdatatable extends LightningElement {
    @api title = 'Data Table';
    @api records = [];
    @api columns = [];

    @track currentPage = 1;
    pageSize = 10;

    get totalPages() {
        return Math.ceil(this.records.length / this.pageSize);
    }

    get disablePrev() {
        return this.currentPage === 1;
    }

    get disableNext() {
        return this.currentPage === this.totalPages || this.totalPages === 0;
    }

    get pagedData() {
        if (!this.records || this.records.length === 0) return [];
        const start = (this.currentPage - 1) * this.pageSize;
        const end = start + this.pageSize;
        return this.records.slice(start, end);
    }

    get noData() {
        return !this.records || this.records.length === 0;
    }

    handlePrevious() {
        if (this.currentPage > 1) {
            this.currentPage--;
        }
    }

    handleNext() {
        if (this.currentPage < this.totalPages) {
            this.currentPage++;
        }
    }

    handleRowAction(event) {
        this.dispatchEvent(new CustomEvent('rowaction', {
            detail: event.detail
        }));
    }
}