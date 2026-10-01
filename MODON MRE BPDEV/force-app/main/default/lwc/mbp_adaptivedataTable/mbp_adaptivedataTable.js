import { LightningElement, api, track } from 'lwc';

export default class Dynamiclwcdatatable extends LightningElement {
    @api title = 'Data Table';
    @api records = [];
    @api columns = [];
    
    @track sortBy;
    @track sortDirection = 'asc';
    @track defaultSortDirection = 'asc';

    @track currentPage = 1;
    pageSize = 10;

    connectedCallback() {
        // Ensure all columns have sortable = true
        this.columns = this.columns.map(col => {
            return { ...col, sortable: true };
        });

        // Default sort on first column
        if (this.columns.length > 0) {
            this.sortBy = this.columns[0].fieldName;
        }
    }

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

    // Clone for sorting
    let sortedRecords = [...this.records];

    // 🚀 Exclude sorting on S.No
    if (this.sortBy && this.sortBy !== 'sno') {
        sortedRecords = this.sortData(sortedRecords, this.sortBy, this.sortDirection);
    }

    // Pagination boundaries
    const start = (this.currentPage - 1) * this.pageSize;
    const end = start + this.pageSize;
    const pageSlice = sortedRecords.slice(start, end);

    // ✅ Correct serial number logic — continues across pages
    return pageSlice.map((row, index) => ({
        ...row,
        sno: start + index + 1 // Example: Page 2 → starts from 11
    }));
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

    handleSort(event) {
        const { fieldName, sortDirection } = event.detail;
        this.sortBy = fieldName;
        this.sortDirection = sortDirection;

        // Reset to first page on sort
        this.currentPage = 1;

        this.dispatchEvent(new CustomEvent('sort', {
            detail: { fieldName, sortDirection }
        }));
    }

  // ✅ Improved sorting (handles numeric + text + case-insensitive)
sortData(data, fieldName, sortDirection) {
    const sortedData = [...data];

    sortedData.sort((a, b) => {
        let valueA = a[fieldName];
        let valueB = b[fieldName];

        if (valueA === null || valueA === undefined) valueA = '';
        if (valueB === null || valueB === undefined) valueB = '';

        let strA = String(valueA).trim();
        let strB = String(valueB).trim();

        // ✅ If both are pure numbers → numeric sort (ignores leading zeros)
        const isNumeric = /^\d+$/.test(strA) && /^\d+$/.test(strB);
        if (isNumeric) {
            const numA = parseInt(strA, 10);
            const numB = parseInt(strB, 10);
            return sortDirection === 'asc' ? numA - numB : numB - numA;
        }

        // ✅ Case-insensitive alphabetical sort
        strA = strA.toLowerCase();
        strB = strB.toLowerCase();

        if (strA < strB) {
            return sortDirection === 'asc' ? -1 : 1;
        } else if (strA > strB) {
            return sortDirection === 'asc' ? 1 : -1;
        }
        return 0;
    });

    return sortedData;
}

}