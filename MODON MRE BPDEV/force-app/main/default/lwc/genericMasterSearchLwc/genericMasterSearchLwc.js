import { LightningElement, api } from 'lwc';
export default class GenericMasterSearchLwc extends LightningElement {
    @api columns = []; // Array of column definitions with fieldName
    @api records = []; // Original data to filter
    @api placeholder = 'Search across all columns...';
    
    searchTerm = '';
    filteredRecords = [];
    
    // Handle search input change
    handleSearchChange(event) {
        this.searchTerm = event.target.value.toLowerCase().trim();
        this.filterData();
    }
    
    // Filter records based on search term
    filterData() {
        if (!this.searchTerm) {
            // If no search term, return all records
            this.dispatchFilteredRecords([...this.records]);
            return;
        }
        
        const filtered = this.records.filter(record => {
            // Check each column for the search term
            return this.columns.some(column => {
                const fieldValue = this.getFieldValue(record, column.fieldName);
                return fieldValue && fieldValue.toString().toLowerCase().includes(this.searchTerm);
            });
        });
        
        this.dispatchFilteredRecords(filtered);
    }
    
    // Helper to get nested field values (e.g., Owner.Name)
    getFieldValue(record, fieldPath) {
        const fields = fieldPath.split('.');
        let value = record;
        
        for (const field of fields) {
            if (value && typeof value === 'object') {
                value = value[field];
            } else {
                return null;
            }
        }
        
        return value;
    }
    
    // Dispatch filtered records to parent
    dispatchFilteredRecords(filteredRecords) {
        this.dispatchEvent(new CustomEvent('filtered', {
            detail: { filteredRecords }
        }));
    }
    
}