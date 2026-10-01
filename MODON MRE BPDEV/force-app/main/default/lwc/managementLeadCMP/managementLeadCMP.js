import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getAlltheUnits from '@salesforce/apex/ManagementLeadController.getAvailableUnits';
import searchUsers from '@salesforce/apex/ManagementLeadController.searchUsers';
import createLead from '@salesforce/apex/ManagementLeadController.createLead';
import { refreshApex } from '@salesforce/apex';
import FORM_FACTOR from '@salesforce/client/formFactor';
import { NavigationMixin } from 'lightning/navigation';

export default class LeadCreator extends NavigationMixin(LightningElement) {
    // Form
    firstName = '';
    lastName = '';
    email = '';
    mobile = '';
    isDesktop = FORM_FACTOR === 'Large';

    @track isLoading = true; 

    // Filters
    selectedProject = '';
    selectedPhase = '';
    selectedProjectName = '';
    selectedPhaseName = '';
    unitSearch = '';
    salesPersonName = '';
    projectOptions = [];
    projecPhaseOptions = [];
    phaseOptions = [];
    salesPersonId = null;
    blockedUntil;

    // Inventory data (units)
    @track data = [];
    _wiredUnitsResult;   // add this

    columns = [
        { label: 'Unit', fieldName: 'Name' },
        { label: 'Project Name', fieldName: 'Project_Name__c' },
        { label: 'Phase Name', fieldName: 'Phase_Name__c' },
        { label: 'Unit Status', fieldName: 'Status__c' },
        { label: 'Total Price', fieldName: 'TotalPrice__c' }
        //{ label: 'Approval Status', fieldName: 'ApprovalStatus__c' },
        //{ label: 'Sub Status', fieldName: 'Sub_Status__c' }
    ];

      mobilecolumns = [
        { label: 'Unit', fieldName: 'Name' },
        { label: 'Project Name', fieldName: 'Project_Name__c' },
        { label: 'Phase Name', fieldName: 'Phase_Name__c' }
       // { label: 'Unit Status', fieldName: 'Status__c' },
       // { label: 'Total Price', fieldName: 'TotalPrice__c' }
        //{ label: 'Approval Status', fieldName: 'ApprovalStatus__c' },
        //{ label: 'Sub Status', fieldName: 'Sub_Status__c' }
    ];

    // guard to suppress removal logic while programmatically changing page/filter
    suppressSelectionUpdate = false;

    @wire(getAlltheUnits)
    wiredUnits(result) {
        this._wiredUnitsResult = result;
        const { data, error } = result;
        if (data) {
            this.projectOptions = data.PicklistOptionMap.projectList;
            this.phaseOptions = data.PicklistOptionMap.phaseList;
            this.projecPhaseOptions = data.projectPhaseMap;

            // normalize unitList so each row has Id (string)
            const normalized = (data.unitList || []).map(u => {
                const id = u.Id || u.id || u.Unit_Id__c || (u.Unit__r && u.Unit__r.Id);
                return { ...u, Id: id ? String(id) : null };
            });
            this.data = normalized;
            this.isLoading = false;
        } else if (error) {
            const msg = (error && error.body && error.body.message) ? error.body.message : (error.message || 'Unknown error');
            this.showToast('Error loading units', msg, 'error');
            this.isLoading = false;
        }
    }

    // Pagination
    pageSize = 5;
    @track currentPage = 1;

    // global selection store (array of Id strings)
    @track selectedRowIds = [];

    // computed array of selected IDs that are present on the current page
    get selectedRowsForTable() {
        const pageIds = new Set((this.pagedData || []).map(r => String(r.Id)));
        return (this.selectedRowIds || []).filter(id => pageIds.has(String(id)));
    }

    // list of selected unit objects (for the modal)
    get selectedUnitsList() {
        return (this.selectedRowIds || []).map(id => {
            return this.data.find(d => String(d.Id) === String(id));
        }).filter(Boolean);
    }

    get filteredData() {
        if (!this.data) return [];
        let list = this.data;

        if (this.selectedProjectName && this.selectedProjectName !== '-- All Projects --') {
            list = list.filter(r => r.Project_Name__c === this.selectedProjectName);
        }

        if (this.selectedPhaseName && this.selectedPhaseName !== '-- All Phases --') {
            list = list.filter(r => r.Phase_Name__c === this.selectedPhaseName);
        }

        if (this.unitSearch) {
            const term = this.unitSearch.trim().toLowerCase();
            list = list.filter(r => (r.Name || '').toLowerCase().includes(term));
        }

        return list;
    }

    get totalPages() {
        return Math.max(1, Math.ceil(this.filteredData.length / this.pageSize));
    }

    get pagedData() {
        const start = (this.currentPage - 1) * this.pageSize;
        return this.filteredData.slice(start, start + this.pageSize);
    }

    get isFirstPage() {
        return this.currentPage <= 1;
    }

    get isLastPage() {
        return this.currentPage >= this.totalPages;
    }

    get assignDisabled() {
        return !(this.selectedRowIds && this.selectedRowIds.length > 0);
    }

    // Modal state
    @track isModalOpen = false;

    // Filters handlers
    handleProjectFilterChange(event) {
        // prevent accidental removals while changing filters
        this.suppressSelectionUpdate = true;
        this.selectedProject = event.detail.value;
        const selectedOption = this.projectOptions.find(opt => opt.value === this.selectedProject);
        this.selectedProjectName = selectedOption ? selectedOption.label : null;
        this.phaseOptions = this.projecPhaseOptions[this.selectedProjectName] || [];
        this.selectedPhase = '';
        this.selectedPhaseName = '';
        this.currentPage = 1;
        setTimeout(() => { this.suppressSelectionUpdate = false; }, 0);
    }

    handlePhaseChange(event) {
        this.suppressSelectionUpdate = true;
        this.selectedPhase = event.detail.value;
        const selectedOption = this.phaseOptions.find(opt => opt.value === this.selectedPhase);
        this.selectedPhaseName = selectedOption ? selectedOption.label : null;
        this.currentPage = 1;
        setTimeout(() => { this.suppressSelectionUpdate = false; }, 0);
    }

    handleUnitSearch(event) {
        this.unitSearch = event.target.value;
        this.currentPage = 1;
    }
    handleDateChange(event) {
        this.blockedUntil = event.target.value;
    }
    handleInputChange(event) {
        const field = event.target.dataset.id;
        const value = event.target.value;
        if (field === 'first') this.firstName = value;
        else if (field === 'last') this.lastName = value;
        else if (field === 'email') this.email = value;
        else if (field === 'mobile') this.mobile = value;
    }

    handleRowSelection(event) {
        // rows selected that datatable reports for the current render
        const selectedRows = event.detail.selectedRows || [];
        const selectedOnPageIds = new Set(selectedRows.map(r => String(r.Id)));

        // ids of rows currently shown
        const pageRowIds = new Set((this.pagedData || []).map(r => String(r.Id)));

        // current global selected set
        const globalSet = new Set((this.selectedRowIds || []).map(id => String(id)));

        // always add newly selected on this page
        selectedOnPageIds.forEach(id => globalSet.add(id));

        // only remove unselected on this page if not suppressing (i.e. user action)
        if (!this.suppressSelectionUpdate) {
            pageRowIds.forEach(id => {
                if (!selectedOnPageIds.has(id)) {
                    globalSet.delete(id);
                }
            });
        }

        this.selectedRowIds = Array.from(globalSet);
    }

    // When user clicks the main Create & Assign button — show modal
    handleCreateClick() {
        // minor validation: require first or last name to show modal (same as before)
        if (!this.firstName && !this.lastName) {
            this.showToast('Error', 'Please provide First Name or Last Name.', 'error');
            return;
        }
        if (!this.mobile) {
            this.showToast('Error', 'Please enter Mobile and Email to create lead.', 'error');
            return;
        }
        /*if (!this.email) {
            this.showToast('Error', 'Please enter Mobile and Email to create lead.', 'error');
            return;
        }*/
        if (!this.salesPersonName && this.salesPersonName.trim() === '' && this.selectedRowIds.length > 0) {
            this.showToast('Error', 'Please assign Sales Person to create a "Unit Allocated" lead.', 'error');
            return;
        }
        if ((this.blockedUntil === undefined || this.blockedUntil === null || this.blockedUntil === '') && this.selectedRowIds.length > 0 && this.salesPersonName) {
            this.showToast('Error', 'Please Select the "Blocked Duration".', 'error');
            return;
        }
        this.fullName = this.firstName + ' ' + this.lastName;
        // open modal so user can review selected units and remove if needed
        this.isModalOpen = true;
    }

    // Remove single selected unit from the global selection (called from modal delete icon)
    handleRemoveSelectedUnit(event) {
        const idToRemove = event.target.dataset.id;
        if (!idToRemove) return;
        const set = new Set((this.selectedRowIds || []).map(id => String(id)));
        set.delete(String(idToRemove));
        this.selectedRowIds = Array.from(set);
    }

    // Modal cancel
    handleCancelModal() {
        this.isModalOpen = false;
    }

    // Confirm create: create lead and assign selected units (then close modal)
    handleConfirmCreate() {
        this.isModalOpen = false;
        // create lead record
        this.isLoading = true; // show loading overlay

            createLead({ firstName: this.firstName, lastName: this.lastName, email: this.email, mobile: this.mobile, salesPersonName: this.salesPersonId, selectedRowIds:this.selectedRowIds,blockedUntil : this.blockedUntil })
            .then(lead => {
                this.showToast('Success', 'Lead created successfully', 'success');

                // if there are selected units, mark them as assigned locally
                if (this.selectedRowIds && this.selectedRowIds.length > 0) {
                    this.data = this.data.map(row => {
                        if (this.selectedRowIds.includes(String(row.Id))) {
                            return { ...row, Status: 'Assigned' };
                        }
                        return row;
                    });
                    // clear selection after assignment
                    this.selectedRowIds = [];
                   
                }

                // close modal and clear form inputs
                this.isModalOpen = false;
                this.firstName = '';
                this.lastName = '';
                this.email = '';    
                this.mobile = '';
                this.clearInputValues();
                this.currentPage = 1;
                this.isLoading = false; 

                 if (this._wiredUnitsResult) {
                        refreshApex(this._wiredUnitsResult);
                }
            })
            .catch(e => {   
                this.isLoading = false;     
                
                this.dispatchEvent(
                    new ShowToastEvent({
                    title: 'Error',
                    message: e?.body?.message || e?.message || 'Create Lead failed.',
                    variant: 'error'
                    })
                );
            });
    }

    assignSelectedToLead() {
        if (!this.selectedRowIds || this.selectedRowIds.length === 0) {
            this.showToast('Error', 'Select at least one Available unit to assign.', 'error');
            return;
        }
        if (!this.firstName && !this.lastName) {
            this.showToast('Error', 'Please enter First or Last name to create lead.', 'error');
            return;
        }
        
        const leadName = `${this.firstName} ${this.lastName}`.trim();
        this.data = this.data.map(row => {
            if (this.selectedRowIds.includes(String(row.Id))) {
                return { ...row, Status: 'Assigned', AssignedTo: 'local-assigned', AssignedToName: leadName };
            }
            return row;
        });
        const assignedCount = this.selectedRowIds.length;
        this.selectedRowIds = [];
        this.showToast('Success', `Assigned ${assignedCount} units to ${leadName}`, 'success');
    }

    clearInputValues() {
        const inputs = this.template.querySelectorAll('lightning-input');
        inputs.forEach(inp => inp.value = '');
    }

    handleCancel() {
        this.firstName = '';
        this.lastName = '';
        this.email = '';
        this.mobile = '';
        this.clearInputValues();
    }

    prevPage() {
        if (this.currentPage > 1) {
            this.suppressSelectionUpdate = true;
            this.currentPage -= 1;
            setTimeout(() => { this.suppressSelectionUpdate = false; }, 0);
        }
    }

    nextPage() {
        if (this.currentPage < this.totalPages) {
            this.suppressSelectionUpdate = true;
            this.currentPage += 1;
            setTimeout(() => { this.suppressSelectionUpdate = false; }, 0);
        }
    }

    showToast(title, message, variant = 'info') {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    navigateToTab() {
        // apiName must be the Tab developer name (case-sensitive)
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: {
                apiName: 'Management_Lead_History' // <-- replace with your tab API name if different
            }
        });
    }

    /*** Custom User Lookup**/
    @track searchTerm = '';
    @track users = [];
    @track hasSelection = false;
    @track selectedUser = {};
    @track isDropdownOpen = false;

    handleSearch(event) {
        // The value property is the correct way to get the input value from lightning-input
        this.searchTerm = event.target.value; 
        if (this.searchTerm && this.searchTerm.length > 2) {
            // A slight delay can improve performance by reducing API calls
            clearTimeout(this.delayTimeout);
            this.delayTimeout = setTimeout(() => {
                this.searchActiveUsers();
            }, 300);
        } else {
            this.users = [];
            this.isDropdownOpen = false;
        }
    }

    searchActiveUsers() {
        searchUsers({ searchTerm: this.searchTerm })
            .then(result => {
                this.users = result;
                this.isDropdownOpen = this.users.length > 0; // Only open if there are results
            })
            .catch(error => {
                console.error('Error searching users:', error);
                this.isDropdownOpen = false;
            });
    }

    handleSelect(event) {
    // prevent blur/other default behavior from interfering
        event.preventDefault();

        const userId = event.currentTarget.dataset.id;
        const userName = event.currentTarget.dataset.name;

        // update both selectedUser and the visible input value
        this.selectedUser = { Id: userId, Name: userName };
        this.searchTerm = userName;           // <-- essential: show selection in the input
        this.hasSelection = true;
        this.isDropdownOpen = false;
        this.salesPersonName = userName;
        this.salesPersonId = userId;
        // Dispatch event to parent components if needed
        const selectedEvent = new CustomEvent('userselected', {
            detail: this.selectedUser
        });
        this.dispatchEvent(selectedEvent);
    }
    
    handleClearSelection() {
        this.salesPersonName = '';
        this.salesPersonId = null;
        this.users = [];
        this.selectedUser = {};
        this.hasSelection = false;
        this.searchTerm = '';
        this.isDropdownOpen = false;
    }

    handleFocus() {
        if (!this.hasSelection && this.searchTerm && this.searchTerm.length > 2) {
            this.searchActiveUsers();
        }
    }
    
    handleBlur() {
        // Delay to allow handleSelect to run before dropdown closes
        setTimeout(() => {
            this.isDropdownOpen = false;
        }, 200);
    }
    //***** CSV File Uploaded */
    @track isModalOpenCSV = false;

  openCsvModal() {
    this.isModalOpenCSV = true;
  }

  closeModal() {
    this.isModalOpenCSV = false;
  }

  handleCreateLeads(event) {
    const rows = event.detail.rows;
    // Call Apex method here to insert Leads
    this.closeModal();
  }

  handleReassign(event) {
    // Implement reassign logic
  }

  handleDeletedAll(event) {
  }

  handleRowDeleted(event) {
  }
  async handleCreateFromParent() {
    await this.template.querySelector('c-csv-lead-uploader')?.handleCreate();
  }
}