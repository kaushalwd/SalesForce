/**********************************************************************************************************************
* Name               : salesExecutiveKPIManager.js
* Description        : JS controller for Sales Executive KPI Manager component
* Usage              : Handles UI interactions and data processing for KPIs
* Created By         : Rushi Patel
* --------------------------------------------------------------------------------------------------------------------
* Version       Author           Date            Comment
* 1.0           Rushi Patel      24 Aug 2026     Initial Draft
******************************************************************************************************************/
import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getSalesExecutiveKPIs from '@salesforce/apex/SalesExecutiveKPIController.getSalesExecutiveKPIs';
import saveKPIs from '@salesforce/apex/SalesExecutiveKPIController.saveKPIs';

export default class SalesExecutiveKPIManager extends NavigationMixin(LightningElement) {
    @track kpiData = [];
    @track isSaveDisabled = true;
    isLoading = true;
    error;

    originalData = [];

    monthOptions = [
        { label: 'January', value: 'January' },
        { label: 'February', value: 'February' },
        { label: 'March', value: 'March' },
        { label: 'April', value: 'April' },
        { label: 'May', value: 'May' },
        { label: 'June', value: 'June' },
        { label: 'July', value: 'July' },
        { label: 'August', value: 'August' },
        { label: 'September', value: 'September' },
        { label: 'October', value: 'October' },
        { label: 'November', value: 'November' },
        { label: 'December', value: 'December' }
    ];

    get yearOptions() {
        const options = [];
        const currentYear = new Date().getFullYear();
        for (let i = currentYear; i <= currentYear + 50; i++) {
            options.push({ label: i.toString(), value: i.toString() });
        }
        return options;
    }

    get cancelOrCloseLabel() {
        return this.isSaveDisabled ? 'Close' : 'Cancel';
    }


    // Trigger data fetch on page reference change (e.g. navigation)
    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference) {
            this.fetchData();
        }
    }

    // Trigger data fetch on component initialization
    connectedCallback() {
        this.fetchData();
    }

    fetchData() {
        this.isLoading = true;
        // Call Apex to get KPI records
        getSalesExecutiveKPIs()
            .then(result => {
                // Parse result to avoid readonly proxy issues and allow mutations
                let parsedResult = JSON.parse(JSON.stringify(result));
                // Add CSS class properties to track highlighting for edited fields
                parsedResult = parsedResult.map(row => ({
                    ...row,
                    presentableClass: '',
                    punctualityClass: '',
                    teamWorkClass: '',
                    targetClass: '',
                    monthClass: '',
                    yearClass: ''
                }));
                // Set working and original data arrays
                this.kpiData = parsedResult;
                this.originalData = JSON.parse(JSON.stringify(parsedResult));
                this.isSaveDisabled = true;
                this.error = undefined;
            })
            .catch(error => {
                this.error = error.body ? error.body.message : error.message;
                this.kpiData = undefined;
                this.showToast('Error', 'Error loading data: ' + this.error, 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleInputChange(event) {
        // Retrieve identifier and field name from dataset
        const userId = event.target.dataset.id;
        const fieldName = event.target.dataset.field;
        let value = event.target.value;

        // Find the specific row index for the changed input
        const rowIndex = this.kpiData.findIndex(row => row.userId === userId);
        if (rowIndex !== -1) {
            // Standardize empty inputs to null
            if (value === '' || value === null || value === undefined) {
                value = null;
            } else if (fieldName === 'target' || fieldName === 'presentable' || fieldName === 'punctuality' || fieldName === 'teamWork') {
                // Ensure numerical fields are parsed as floats
                value = parseFloat(value);
            }
            // Update the state array and evaluate overall changes
            this.kpiData[rowIndex][fieldName] = value;
            this.checkForChanges();
        }
    }

    checkForChanges() {
        let hasChanges = false;
        // Compare working data against the original data element by element
        for (let i = 0; i < this.kpiData.length; i++) {
            const current = this.kpiData[i];
            const original = this.originalData[i];
            
            // Helper function to normalize blank vs null
            const normalize = (val) => (val === '' || val === null || val === undefined) ? null : val;
            
            // Determine if fields have been edited and apply CSS highlighting class
            const isPresentableChanged = normalize(current.presentable) !== normalize(original.presentable);
            current.presentableClass = isPresentableChanged ? 'changed-field' : '';
            
            const isPunctualityChanged = normalize(current.punctuality) !== normalize(original.punctuality);
            current.punctualityClass = isPunctualityChanged ? 'changed-field' : '';
            
            const isTeamWorkChanged = normalize(current.teamWork) !== normalize(original.teamWork);
            current.teamWorkClass = isTeamWorkChanged ? 'changed-field' : '';
            
            const isTargetChanged = normalize(current.target) !== normalize(original.target);
            current.targetClass = isTargetChanged ? 'changed-field' : '';
            
            const isMonthChanged = normalize(current.month) !== normalize(original.month);
            current.monthClass = isMonthChanged ? 'changed-field' : '';
            
            const isYearChanged = normalize(current.year) !== normalize(original.year);
            current.yearClass = isYearChanged ? 'changed-field' : '';

            if (isPresentableChanged || isPunctualityChanged || isTeamWorkChanged || isTargetChanged || isMonthChanged || isYearChanged) {
                hasChanges = true;
            }
        }
        this.kpiData = [...this.kpiData]; // trigger reactivity
        this.isSaveDisabled = !hasChanges;
    }

    handleCancel() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Sales_Executive_Teams_KPI__c',
                actionName: 'list'
            },
            state: {
                filterName: 'All'
            }
        });
    }

    handleSave() {
        this.isLoading = true;
        
        // Find which rows actually changed to only send updates, or send all. 
        // For simplicity and per requirement "pass the whole json to backend... update all the records", we send all.
        const kpiJson = JSON.stringify(this.kpiData);
        
        saveKPIs({ kpiListJSON: kpiJson })
            .then(() => {
                this.showToast('Success', 'KPIs saved successfully', 'success');
                // Refresh data to get new Ids if new records were created
                this.fetchData();
            })
            .catch(error => {
                this.isLoading = false;
                this.showToast('Error', 'Error saving data: ' + (error.body ? error.body.message : error.message), 'error');
            });
    }

    
    
    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            })
        );
    }
}