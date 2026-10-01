import { LightningElement, track, wire } from 'lwc';

import fetchInitialSteps from '@salesforce/apex/BusinessProcessStepController.fetchInitialSteps';
import assignSteps from '@salesforce/apex/BusinessProcessStepController.assignSteps';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getPicklistValuesFromField from '@salesforce/apex/BusinessProcessStepController.getPicklistValuesFromField';
import saveBPNDocument from '@salesforce/apex/BusinessProcessStepController.saveBPNDocument';
import getBPNNumbers from '@salesforce/apex/BusinessProcessStepController.getBPNNumbers';

//import getQueueUsers from '@salesforce/apex/BusinessProcessStepController.getQueueUsers';
//import getUnitsByName from '@salesforce/apex/BusinessProcessStepController.getUnitsByName';
//import getBookingsByName from '@salesforce/apex/BusinessProcessStepController.getBookingsByName';
//import getProcessFlows from '@salesforce/apex/BusinessProcessStepController.getProcessFlows';
//import getFlowSteps from '@salesforce/apex/BusinessProcessStepController.getFlowSteps';
//import filterSteps from '@salesforce/apex/BusinessProcessStepController.filterSteps';

const columns = [
    { label: '#', fieldName: 'rowNumber', type: 'number', initialWidth: 70, sortable: false },

    //{ label: 'Business Process Name', fieldName: 'businessProcessName', sortable: true, wrapText: true },
    {
        label: 'Service Request Name',
        fieldName: 'businessProcessUrl',
        type: 'url',
        typeAttributes: {
            label: { fieldName: 'businessProcessName' },
            tooltip: 'Click to view process',
            target: '_blank'
        },
        sortable: true,
        wrapText: true
    },
    { label: 'Service Request ', fieldName: 'businessProcess', sortable: true, wrapText: true },
    { label: 'Name', fieldName: 'stepName', sortable: true, wrapText: true },
    
    /*{ label: 'Name', fieldName: 'stepName', sortable: true, wrapText: true },
    {
        label: 'Name',
        fieldName: 'stepUrl',
        type: 'url',
        typeAttributes: {
            label: { fieldName: 'stepName' },
            tooltip: 'Click to view record',
            target: '_blank'
        },
        sortable: true
    },*/
    
    { label: 'Project', fieldName: 'projectName', sortable: true, wrapText: true },
   // { label: 'Tower', fieldName: 'towerName', sortable: true, wrapText: true },
    { label: 'Unit', fieldName: 'unitName', sortable: true, wrapText: true },
    { label: 'Sales Order', fieldName: 'bookingName', sortable: true, wrapText: true },
    { label: 'Status', fieldName: 'status', sortable: true },
    //{ label: 'Pre registration information', fieldName: 'preRegistrationInfo', sortable: true, wrapText: true },
    { label: 'Assigned To', fieldName: 'assignedTo', sortable: true },
    { label: 'Created Date', fieldName: 'createdDate', type: 'date', sortable: true }
    /*,
    { label: 'Milestone Time', fieldName: 'milestoneTime', sortable: false },
    { label: 'Total Time', fieldName: 'totalTime', sortable: false },
    { label: 'Escalated Time', fieldName: 'escalatedTime', sortable: false },
   // { label: 'Is Escalated', fieldName: 'isEscalated', type: 'boolean', sortable: false },
    { label: 'Reopen Count', fieldName: 'reOpenCount', type: 'number', sortable: false }
    */
];

export default class BusinessStepTable extends LightningElement {
    @track records = [];
    @track error;
    @track columns = columns;

    startDate = '';
    endDate = '';
    searchKey = '';


    @track flowOptions = [];
    @track stepOptions = [];
    @track stepIds = [];
    @track assignToUserOptions = [];
    assignToUser;

    @track recordsToDisplay = [];  //Records to be displayed on the page
    @track filteredRecords = []; // Add filteredRecords property
    rowNumberOffset;  //Row number

    showTable = false;

    stepfilter;
    selectedFlowName;
    selectedFlow;
    selectedStepName;
    selectedStep;
    selectedStepAssignmentStatus

    selectedFlowId;
    selectedStepId;
    selectedProjectId;
    selectedTowerId;

    showApproveModal;

    showApproverRejectionButton;
    isLoading = false;
    showAssignSection = false;
    rowCountToSelect = 0; // New property to store the count

    @track statusOptions = [];
    status;
    @track sortedData = [];
    sortBy;
    sortDirection;
    noRecordsFound = false;

    @track unitIds = [];
    @track bookingIds = [];
    //unitFileName = '';
    //bookingFileName = '';

    selectedDocumentType = 'Approved BPN';
    stepAssignmentStatusOptions = [
        { label: 'Assigned', value: 'Assigned' },
        { label: 'Not Assigned', value: 'Not Assigned' }
    ];

    documentTypeOptions = [
        { label: 'Approved BPN', value: 'Approved BPN' },
        { label: 'Final Payment Proof', value: 'Final Payment Proof' }
    ];


    isSaveDisabled = true;
    showUploadBPNButton = false;
    showUploadBPNModal = false;
    uploadedFileId = null;
    uploadedFileName = '';
    acceptedFormats = ['.pdf', '.png', '.jpg', '.jpeg', '.doc', '.docx'];

    @track bpnOptions = [];
    bpnNumber = '';
    totalDldAmount = 0;


    /*get showApproverRejectionButton() {
        return (this.selectedFlowId && this.selectedStepId) || this.selectedProjectId || this.selectedTowerId;
    }*/
    connectedCallback() {
        this.showApproveModal = false;
        this.showApproverRejectionButton = false;
        this.showUploadBPNButton = false;
        this.loadData();
        this.loadPicklistValues();
    }

    // Wire service to fetch BPN numbers
    @wire(getBPNNumbers)
    wiredBPNNumbers({ error, data }) {
        if (data) {
            this.bpnOptions = data.map(bpn => ({
                label: bpn,
                value: bpn
            }));
            this.error = undefined;
        } else if (error) {
            console.error('Error fetching BPN numbers:', error);
            this.bpnOptions = [];
        }
    }

    handleMasterSearchFilter(event) {
        this.filteredRecords = event.detail.filteredRecords;
        
        // Update sortedData with filtered records
        if (this.sortBy && this.sortDirection) {
            this.sortedData = this.sortRecords([...this.filteredRecords], this.sortBy, this.sortDirection);
        } else {
            this.sortedData = [...this.filteredRecords];
        }
    }
    
    
    handleRowCountChange(event) {
        const count = parseInt(event.detail.value, 10) || 0;
        this.rowCountToSelect = count;

        const datatable = this.template.querySelector('lightning-datatable');
        if (datatable && this.sortedData.length > 0) {
            // Automatically select the first N rows
            const selectedRows = this.sortedData.slice(0, count);
            const selectedIds = selectedRows.map(row => row.id);
            datatable.selectedRows = selectedIds;

            this.stepIds = selectedIds;

            // Calculate total dldAmount for selected rows using the actual row objects
            this.totalDldAmount = selectedRows.reduce((sum, row) => {
                const amount = row.dldAmount || 0;
                return sum + amount;
            }, 0);



            // Show Approve/Reject or Assign sections if needed
            const allCanMassUpdate = selectedIds.length > 0 && selectedIds.every(id => {
                const row = this.sortedData.find(r => r.id === id);
                return row?.canMassUpdate;
            });

            if (allCanMassUpdate && this.selectedStepName && this.selectedStepAssignmentStatus !== 'Not Assigned') {
                this.showApproverRejectionButton = true;
            } else {
                this.showApproverRejectionButton = false;
            }

            if (this.stepIds.length > 0 && this.selectedStepAssignmentStatus == 'Not Assigned') {
                this.showAssignSection = true;
            } else {
                this.showAssignSection = false;
            }
        }
    }

    handleMasterSearchFilter(event) {
        this.filteredRecords = event.detail.filteredRecords;
        
        // Update sortedData with filtered records
        if (this.sortBy && this.sortDirection) {
            this.sortedData = this.sortRecords([...this.filteredRecords], this.sortBy, this.sortDirection);
        } else {
            this.sortedData = [...this.filteredRecords];
        }
    }


    handleSort(event) {
        const { fieldName: sortedBy, sortDirection } = event.detail;
        this.sortedData = this.sortRecords([...this.sortedData], sortedBy, sortDirection);
        this.sortBy = sortedBy;
        this.sortDirection = sortDirection;
    }
    
    sortRecords(data, sortedBy, sortDirection) {
        // First sort the data
        const sorted = [...data].sort((a, b) => {
            let valA = a[sortedBy] ?? '';
            let valB = b[sortedBy] ?? '';

            if (typeof valA === 'string') valA = valA.toLowerCase();
            if (typeof valB === 'string') valB = valB.toLowerCase();

            if (valA instanceof Date) valA = valA.getTime();
            if (valB instanceof Date) valB = valB.getTime();

            let result = valA > valB ? 1 : valA < valB ? -1 : 0;
            return sortDirection === 'asc' ? result : -result;
        });
    
        // Then renumber the rows sequentially
        return sorted.map((record, index) => {
            return {
                ...record,
                rowNumber: index + 1
            };
        });
    }

    loadPicklistValues() {
        getPicklistValuesFromField()
        .then(result => {
            if (result) {
                this.statusOptions = result['Status__c']?.map(label => ({ label, value: label })) || [];
                this.departmentOptions = result['Department__c']?.map(label => ({ label, value: label })) || [];
            }
        })
        .catch(error => {
            console.error('Error loading picklist values', error);
        });
    }
    
    handleStatusChange(e) {
        this.status = e.detail.value;
    }
    handleAssignmentStatusChange(e) {
        this.selectedStepAssignmentStatus = e.detail.value;
        this.showAssignSection = false;
    }

    formatData(data) {
    
        return data.map((item, index) => {
            const step = item.step;
        
            return {
                //rowNumber: index + 1,
                id: step.Id,
                businessProcess: step.Business_Process__r.Name,
                    
                businessProcessName: step.Business_Process__r.Process_Flow__r.Name,
                businessProcessUrl: '/' + step.Business_Process__c,  // link to related record
            
                stepName: step.Name,
                stepUrl: '/' + step.Id,

                bookingName: step.Business_Process__r.Sales_Order__r?.Name ,
                unitName: step.Business_Process__r.Unit__r?.Name,
                projectName: step.Business_Process__r.Project__r?.Name,
                //towerName: step.Business_Process__r.Tower__r?.Name,
                assignedTo: step.Assigned_To__r?.Name,

                status: step.Status__c,
                //preRegistrationInfo: step.Business_Process__r.Pre_registration_information__c,
                dldAmount: step.Business_Process__r.DLD_fee_allocated__c,
                createdDate: step.CreatedDate,
                ownerId: step.Owner?.Id || '',
                canMassUpdate: step.canMassUpdate__c
            /*,
            milestoneTime: item.timeline?.mileStoneTime || 'N/A',
            totalTime: item.timeline?.totalTime || 'N/A',
            escalatedTime: item.timeline?.escalatedTime || '0 min',
            isEscalated: item.timeline?.isEscalated || false,
            reOpenCount: item.timeline?.reOpenCount || 0
            */
            };
        });
    }


    loadData() {//startDate: this.startDate, endDate: this.endDate, 

        this.isLoading = true;
        this.error = undefined;
        this.showApproverRejectionButton = false;
        this.showAssignSection = false;
        this.stepIds = []; // clear selected rows 
        this.showUploadBPNButton = false;
        
        const datatable = this.template.querySelector('lightning-datatable');
        if (datatable) {
            datatable.selectedRows = [];
        }
        
        fetchInitialSteps({ 
            selectedFlowName: this.selectedFlowName, 
            selectedStepName: this.selectedStepName,  
            selectedProjectId: this.selectedProjectId, 
            selectedTowerId: this.selectedTowerId,
            selectedStatus: this.status,
            selectedAssignmentStatus: this.selectedStepAssignmentStatus,
            bpnNumber: this.bpnNumber,
            unitIds: this.unitIds,
            bookingIds: this.bookingIds
        })
            .then(data => {
                
                this.records = this.formatData(data);
                this.filteredRecords = [...this.records]; // Initialize filteredRecords with all records
                this.noRecordsFound = this.records.length === 0; // Set flag based on records
            
                // Default sort if none applied yet
                if (!this.sortBy) {
                    this.sortBy = 'createdDate';
                    this.sortDirection = 'desc';
                }

                this.sortedData = this.sortRecords([...this.filteredRecords], this.sortBy, this.sortDirection);
                this.showTable = true;
                this.showAssignSection = false;
                /* 
                // Reset paginator after data loads
                const paginator = this.template.querySelector('c-paginator');
                if (paginator) {
                    paginator.reset();
                }*/
                //this.forcePaginatorRefresh();
            })
            .catch(error => {
                this.error = error.body ? error.body.message : error.message;
                this.records = [];
                this.filteredRecords = []; // Clear filteredRecords on error
                this.sortedData = [];
                this.noRecordsFound = true;
            })
            .finally(() => {
                this.isLoading = false; // Hide loader when done
            });
    }


    handleRowSelection(e) {
        const rows = e.detail.selectedRows;
        
        this.stepIds = rows.map(r => r.id);


        this.totalDldAmount = rows.reduce((sum, row) => {
            const amount = row.dldAmount || 0;
            return sum + amount;
        }, 0);  

        const allCanMassUpdate = rows.length > 0 && rows.every(r => r.canMassUpdate);        
        if (allCanMassUpdate && this.selectedStepName && this.selectedStepAssignmentStatus !== 'Not Assigned') {
            this.showApproverRejectionButton = true;
        } else {
            this.showApproverRejectionButton = false;
        }

        const isAccountsOrFundsStep = this.selectedStepName && 
            (this.selectedStepName.includes('Accounts - Authorized Signatory') || 
             this.selectedStepName.includes('Funds Transfer'));
             
        if (this.stepIds.length > 0 && isAccountsOrFundsStep) {
            this.showUploadBPNButton = true;
        } else {
            this.showUploadBPNButton = false;
        }
        this.isSaveDisabled = true;


        if (this.stepIds.length > 0 && this.selectedStepAssignmentStatus == 'Not Assigned') {
                this.showAssignSection = true;

                /*  
                const queueId = rows[0].ownerId;
                getQueueUsers({ queueGroupId: queueId })
                .then(res => {
                    this.assignToUserOptions = res;
                    this.showAssignSection = true;
                })
                .catch(error => {
                this.error = error.body ? error.body.message : error.message;
                });*/

        } else {
            this.showAssignSection = false;
        }
        /*if(rows.length > 0 && rows[0].canMassUpdate && this.selectedStepName != null){
            this.showApproverRejectionButton = true;
        } else {
            this.showApproverRejectionButton = false;
        }*/

    }

    handleAssign() {
        if (this.stepIds.length === 0) {
            this.showToast('Warning', 'Please select rows before accept.', 'warning');
            return;
        }
        this.isLoading = true;
        assignSteps({
            stepIds: this.stepIds,
            assignToUserId: null
        })
        .then(() => {
            this.showToast('Success', 'Assigned successfully.', 'success');
            this.handleRefresh();
        })
        .catch(err => this.showToast('Error during assign', err.body.message, 'error'))
        .finally(() => {
            this.isLoading = false; // Hide loader when done
        });
    }


   

    handleProcessFlowSelection(event) {
        this.selectedFlowId = event.detail;
        this.stepfilter = 'Process_Flow__c = \''+this.selectedFlowId +'\'';
        this.showApproverRejectionButton = false; // Hide the approval/rejection button
        this.showAssignSection = false;
    }
    handleProcessFlowSelectionName(event) {
        this.selectedFlowName = event.detail;
        this.showApproverRejectionButton = false; // Hide the approval/rejection button
        this.showAssignSection = false;
    }
    handleProcessFlowClear() {
        this.selectedFlowId = null; // Reset selected PRocess ID
        this.selectedFlowName = null; // Reset Selected PRocess Name
        this.showApproverRejectionButton = false; // Hide the approval/rejection button
    }

    handleFlowStepSelection(event) {
        this.selectedStepId = event.detail;
        this.showApproverRejectionButton = false; // Hide the approval/rejection button
    }
    handleFlowStepSelectionName(event) {
        this.selectedStepName = event.detail;
        this.showApproverRejectionButton = false; // Hide the approval/rejection button
    }
    handleFlowStepClear() {
        this.selectedStepId = null; // Reset selected PRocess Step ID
        this.selectedStepName = null; // Reset Selected PRocess Step Name
        this.showApproverRejectionButton = false; // Hide the approval/rejection button
    }

    handleProjectSelection(event) {
        this.selectedProjectId = event.detail;
        this.showApproverRejectionButton = false; // Hide the approval/rejection button
    }
    handleProjectClear() {
        this.selectedProjectId = null; // Reset selected project ID
        this.showApproverRejectionButton = false; // Hide the approval/rejection button
    }
    
    handleTowerSelection(event) {
        this.selectedTowerId = event.detail;
        this.showApproverRejectionButton = false; // Hide the approval/rejection button
    }
    handleTowerClear() {
        this.selectedTowerId = null; // Reset selected Tower ID
    }
    handleBpnNumberChange(e) {
        this.bpnNumber = e.detail.value;
    }
    handleDocumentTypeChange(event) {
        this.selectedDocumentType = event.detail.value;
    }

    openUploadBPNModal() {
        this.showUploadBPNModal = true;
        this.uploadedFileId = null;
        this.selectedDocumentType = 'Approved BPN'; 
    }

    closeUploadBPNModal() {
        this.showUploadBPNModal = false;
    }

    handleBPNUploadFinished(event) {
        const uploadedFiles = event.detail.files;
        if (uploadedFiles.length > 0) {
            this.uploadedFileId = uploadedFiles[0].documentId;
            this.uploadedFileName = uploadedFiles[0].name;
            this.isSaveDisabled = false;
            this.showToast('Success', 'File uploaded successfully.', 'success');
        }
    }


    saveBPNDocument() {
        if (!this.uploadedFileId) {
            this.showToast('Error', 'Please upload a file ', 'error');
            return;
        }

        this.isLoading = true;
        saveBPNDocument({
            stepIds: this.stepIds,
            fileId: this.uploadedFileId,
            documentType: this.selectedDocumentType
        })
        .then(() => {
            this.showToast('Success', 'Document saved successfully.', 'success');
            this.closeUploadBPNModal();
            this.handleRefresh();
        })
        .catch(error => {
            this.showToast('Error', error.body?.message || 'Failed to save BPN document.', 'error');
            console.error('Error saving BPN document:', error);
        })
        .finally(() => {
            this.isLoading = false;
        });
    }

    showToast(title, msg, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message: msg, variant }));
    }

    handleModalSubmit() {
        this.showApproveModal = false;
        this.stepIds = [];

        // Re-fetch records logic can be added here
        this.handleRefresh();
    }

    openApprovalModal() {
        this.showApproveModal = true;
    }

    handleModalClose() {
        this.showApproveModal = false;
    }

    handleRefresh() {
        
        
        this.showApproverRejectionButton = false;

        /*const selectedIdSet = new Set(this.stepIds);
        this.recordsToDisplay = this.recordsToDisplay.filter(row => !selectedIdSet.has(row.id));

        const paginator = this.template.querySelector('c-paginator');
        if (paginator) {
            paginator.reset();
        }*/

        this.stepIds = []; // clear selected rows 
        const datatable = this.template.querySelector('lightning-datatable');
        if (datatable) {
            datatable.selectedRows = [];
        }

        this.rowCountToSelect = 0; 
        this.loadData();
    }

    handleClear() {

        this.selectedFlowName = null;
        this.selectedStepName = null;
        this.selectedStepId = null;
        this.selectedFlowId = null;
        this.selectedProjectId = null;
        this.selectedTowerId = null;
        this.stepIds = []; // Clear selected step IDs
        this.bpnNumber = '';
        //this.unitFileName = '';
        this.unitIds = [];
        //this.bookingFileName = '';
        this.bookingIds = [];
        this.selectedStatus = null;
        this.status = null;
        this.error = undefined; // Clear any error messages
        this.isLoading = false; // Reset loading state
        this.rowNumberOffset = 0; // Reset row number offset
        this.showApproverRejectionButton = false; // Hide the approval/rejection button
        this.showAssignSection = false;
        this.rowCountToSelect = 0;
        this.showUploadBPNButton = false; 
        this.rowCountToSelect = 0;

       /* const paginator = this.template.querySelector('c-paginator');
        if (paginator) {
            paginator.reset();
        }*/
        //this.template.querySelector('c-paginator').reset(); // Reset paginator
        
        this.template.querySelectorAll('c-generic-lookup-lwc').forEach(lookup => {
          lookup.clearLookup?.();
        });

        /*const comboboxes = this.template.querySelectorAll('lightning-combobox');
        if(comboboxes) {
            comboboxes.forEach(combobox => {
                combobox.value = '';
            });
        }*/

        // If you want to reset the table selection UI
        const datatable = this.template.querySelector('lightning-datatable');
        if (datatable) {
            datatable.selectedRows = [];
        }

        this.loadData();

    }


    /*handlePaginatorChange(event) {
        this.recordsToDisplay = event.detail;

        if (this.recordsToDisplay && this.recordsToDisplay.length > 0) {
            this.rowNumberOffset = this.recordsToDisplay[0].rowNumber - 1;
        } else {
            // Handle the case where recordsToDisplay is empty or undefined
            console.error('No records available or recordsToDisplay is undefined');
        }
    }*/


    /*forcePaginatorRefresh() {
        const tempRecords = this.records;
        this.records = [];
        setTimeout(() => {
        this.records = tempRecords;
        }, 0);
    }*/


    /*handleFlowChange(e) {
    this.selectedFlow = e.detail.value;

    this.showApproverRejectionButton = false;
    if(this.selectedFlow != undefined && this.selectedFlow != null){
      const selectedOption = this.flowOptions.find(option => option.value === this.selectedFlow);

      if (selectedOption) {
        this.selectedFlowName = selectedOption.label;
         // or selectedOption.name if you added that
      }
    }

    this.selectedStep = null;
    this.selectedStepName = null;
    this.stepOptions = [];
    getFlowSteps({ processFlowId: this.selectedFlow })
      .then(res => this.stepOptions = res)
      .catch(err => this.showToast('Error loading steps', err.body.message, 'error'));
}

handleStepChange(e) {
    this.selectedStep = e.detail.value;
    this.showApproverRejectionButton = false;

    if(this.selectedStep != undefined && this.selectedStep != null){
      const selectedOption = this.stepOptions.find(option => option.value === this.selectedStep);

      if (selectedOption) {
        this.selectedStepName = selectedOption.label;
         // or selectedOption.name if you added that
      } 
    } 
}*/
    
    /*handleSearch(event) {
        this.searchKey = event.target.value;
    }
     handleStartDate(event) {
        this.startDate = event.target.value;
    }

    handleEndDate(event) {
        this.endDate = event.target.value;
    }    */

    /*handleFilter() {
        if (!this.startDate || !this.endDate) {
            this.error = 'Please select both start and end dates.';
            return;
        }
        this.error = undefined;

        filterSteps({ startDate: this.startDate, endDate: this.endDate, selectedFlowName: this.selectedFlowName, selectedStepName: this.selectedStepName })
            .then(data => {
                this.error = undefined;
                this.records = this.formatData(data);
            })
            .catch(error => {
                this.error = error.body ? error.body.message : error.message;
                this.records = [];
            });
    }*/
    
    /*handleAssignChange(e) {
        this.assignToUser = e.detail.value;
    } */
    
    //Commented by Artee
    /*handleUnitFileChange(event) {
        const file = event.target.files[0];
        if (file) {
            this.unitFileName = file.name; // Show file name
            this.readCSVFile(file, 'unit');
        } else {
            this.unitFileName = '';
            this.unitIds = [];
        }
    }
    
    handleBookingFileChange(event) {
        const file = event.target.files[0];
        if (file) {
            this.bookingFileName = file.name; // Show file name
            this.readCSVFile(file, 'booking');
        } else {
            this.bookingFileName = '';
            this.bookingIds = [];
        }
    }

    readCSVFile(file, objName) {
        const reader = new FileReader();

        reader.onload = () => {
            const csv = reader.result;
            const lines = csv.split('\n');
            const names = lines.map(line => line.trim()).filter(name => name); // remove empty lines

            // remove header if needed (optional)
            if (names[0].toLowerCase().includes('name')) {
                names.shift();
            }

            if(objName === 'unit') {
                this.fetchUnitIds(names);
            } else if(objName === 'booking') {
                this.fetchBookingIds(names);
            }
        };

        reader.readAsText(file);
    }

    fetchUnitIds(unitNames) {
        getUnitsByName({ unitNames: unitNames })
            .then(result => {
                this.unitIds = result;
            })
            .catch(error => {
                console.error('Error fetching Unit Ids:', error);
            });
    }

    fetchBookingIds(bookingNames) {
        getBookingsByName({ bookingNames: bookingNames })
            .then(result => {
                this.bookingIds = result;
            })
            .catch(error => {
                console.error('Error fetching Booking Ids:', error);
            });
    }*/
}