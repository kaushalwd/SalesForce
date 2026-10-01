import { LightningElement, track, wire } from 'lwc';
//import getProcessFlows from '@salesforce/apex/BusinessProcessStepController.getProcessFlows';
//import getFlowSteps from '@salesforce/apex/BusinessProcessStepController.getFlowSteps';
import getQueueUsers from '@salesforce/apex/BusinessProcessStepController.getQueueUsers';
import getFilteredSteps from '@salesforce/apex/BusinessProcessStepController.getFilteredSteps';
import assignSteps from '@salesforce/apex/BusinessProcessStepController.assignSteps';
import getUnitsByName from '@salesforce/apex/BusinessProcessStepController.getUnitsByName';
import getBookingsByName from '@salesforce/apex/BusinessProcessStepController.getBookingsByName';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getPicklistValuesFromField from '@salesforce/apex/BusinessProcessStepController.getPicklistValuesFromField';
import getBPNNumbers from '@salesforce/apex/BusinessProcessStepController.getBPNNumbers';


export default class BusinessProcessStepAssignment extends LightningElement {

  isLoading = false;
  status = [];
  bpnNumber = '';
  stepfilter;
  selectedFlowName;
  selectedStepName;
  selectedFlowId;
  selectedStepId;

  selectedProjectId;
  selectedTowerId;
  selectedUserId;
  department;
  selectedDepartment;


  @track flowOptions = [];
  @track stepOptions = [];
  @track userOptions = [];
  @track assignToUserOptions = [];
  @track statusOptions = [];
  @track departmentOptions = [];


  showTable = false;
  rowNumberOffset;  //Row number
  @track recordsToDisplay = [];  //Records to be displayed on the page
  rowCountToSelect = 0; // store the count
  showAssignSection = false;
  
  
  @track bpnOptions = [];
  @track assignToUser;

  @track records = [];
  @track selectedRowIds = [];

  
  unitFileName = '';
  bookingFileName = '';
  @track unitIds = [];
  @track bookingIds = [];
  
  @track sortBy;
  @track sortedData = [];
  @track sortDirection;

  @track filteredRecords = []; // Records after master search filtering


  columns = [
    { label: '#', fieldName: 'rowNumber', type: 'number', initialWidth: 70, sortable: false },
    { label: 'Name', fieldName: 'Name', sortable: true },
    { label: 'SR Request', fieldName: 'Business_Process_Name__c', sortable: true },
    { label: 'Project', fieldName: 'projectName', sortable: true },
   // { label: 'Tower', fieldName: 'towerName', sortable: true },
    { label: 'Unit', fieldName: 'unitName', sortable: true },
    { label: 'Sales Order', fieldName: 'bookingName', sortable: true },
    { label: 'Status', fieldName: 'Status__c', sortable: true },
    //{ label: 'Pre registration information', fieldName: 'preRegistrationInfo', sortable: true, wrapText: true },
    { label: 'Assigned To', fieldName: 'Assigned_To__r.Name', sortable: true },
    { label: 'Owner', fieldName: 'Owner.Name', sortable: true },
    { label: 'Created Date', fieldName: 'CreatedDate', type: 'date', sortable: true }
  ];

  connectedCallback() {
    this.stepfilter = 'Process_Flow__c = \'' + this.selectedFlowId + '\'';
    this.loadPicklistValues();
  }

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

  loadPicklistValues() {
    getPicklistValuesFromField()
      .then(result => {
        if (result) {
          this.statusOptions = result['Status__c']
          ?.filter(label => label !== 'Completed')  // Filter out "Completed" value
          .map(label => ({ label, value: label })) || [];

          this.departmentOptions = result['Department__c']?.map(label => ({ label, value: label })) || [];
        }
      })
      .catch(error => {
        console.error('Error loading picklist values', error);
      });
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

  handleDepartmentChange(e) {
    this.selectedDepartment = e.detail.value;
  }

  handleStatusChange(e) {
    this.status = e.detail; // Now receives an array of selected values
  }

  handleSearch() {
    /*if ( !this.status || this.status.length === 0 || !this.selectedFlowName || !this.selectedStepName) {
      this.showToast('Missing Filters', 'Please select the filter criteria for status, business Process and Business process step.', 'warning');
      return;
    }*/



    // Check if status and business process are selected
    if (!this.status || this.status.length === 0 || !this.selectedFlowName) {
      this.showToast('Missing Filters', 'Please select the filter criteria for Status and Business Process.', 'warning');
      return;
    }
  
    // Check if either step OR department is selected (XOR condition)
    const hasStep = !!this.selectedStepName;
    const hasDepartment = !!this.selectedDepartment;
  
    if (!(hasStep || hasDepartment)) {
      this.showToast('Missing Filters', 'Please select either Business Process Step OR Department.', 'warning');
      return;
    }


    this.isLoading = true;

    getFilteredSteps({
      flowProcess: this.selectedFlowName,
      flowStep: this.selectedStepName,
      department: this.selectedDepartment,
      status: this.status,
      project: this.selectedProjectId,
      tower: this.selectedTowerId,
      user: this.selectedUserId,
      bpnNumber: this.bpnNumber,
      unitIds: this.unitIds,
      bookingIds: this.bookingIds
    })
      .then(res => {
        this.records = [];
        this.recordsToDisplay = [];
        this.records = this.formatData(res);//res;
        this.filteredRecords = [...this.records]; // Initialize filtered records

        this.recordsToDisplay = this.records;
        if (!this.sortBy) {
          this.sortBy = 'CreatedDate';
          this.sortDirection = 'desc';
        }

        this.sortedData = this.sortRecords([...this.records], this.sortBy, this.sortDirection);

        this.selectedRowIds = [];
        this.showAssignSection = false;
        this.showTable = true;

        // Reset paginator after data loads
        /*const paginator = this.template.querySelector('c-paginator');
        if (paginator) {
          paginator.reset();
        }*/
        this.isLoading = false;
      })
      .catch(error => {
        // alert('getFilteredSteps error'+error);
        this.error = error.body ? error.body.message : error.message;
        this.records = [];
        this.filteredRecords = [];
        this.isLoading = false;
      });
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

  formatData(data) {
    return data.map((item, index) => {
      const step = item.step;
      return {
        //rowNumber: index + 1,
        Id: step.Id,
        Name: step.Name,
        Business_Process_Name__c: step.Business_Process__r.Name,
        CreatedDate: step.CreatedDate,
        //Department__c: step.Department__c,
        'bookingName': step.Business_Process__r.Sales_Order__r?.Name,
        'unitName': step.Business_Process__r.Unit__r?.Name,
        'projectName': step.Business_Process__r.Project__r?.Name,
        //'towerName': step.Business_Process__r.Tower__r?.Name,
        Status__c: step.Status__c,
        //preRegistrationInfo: step.Business_Process__r.Pre_registration_information__c,
        'Assigned_To__r.Name': step.Assigned_To__r?.Name || '',
        'Owner.Name': step.Owner?.Name || '',
        'OwnerId': step.Owner?.Id || ''
        /*,
        milestoneTime: item.timeline?.milestoneTime || 'N/A',
        totalTime: item.timeline?.totalTime || 'N/A',
        escalatedTime: item.timeline?.escalatedTime || '0 min',
        reOpenCount: item.timeline?.reOpenCount || 0*/
      };
    });
  }

  handleRowSelection(e) {
    const rows = e.detail.selectedRows;
    this.selectedRowIds = rows.map(r => r.Id);
    if (rows.length > 0) {
      const queueId = rows[0].OwnerId;
      getQueueUsers({ queueGroupId: queueId })
        .then(res => {
          if(this.status!='Not Actioned'){
            this.assignToUserOptions = res;
            this.showAssignSection = true;
          }
        })
        .catch(err => this.showToast('Error loading queue users', err.body.message, 'error'));
    } else {
      this.showAssignSection = false;
    }
  }

  handleAssignChange(e) {
    this.assignToUser = e.detail.value;
  }

  handleAssign() {
    if (!this.assignToUser || this.selectedRowIds.length === 0) {
      this.showToast('Warning', 'Please select user and rows before assigning.', 'warning');
      return;
    }

    const selectedRecords = this.sortedData.filter(record => 
        this.selectedRowIds.includes(record.Id)
    );
    
    if (selectedRecords.length === 0) {
        this.showToast('Error', 'No records selected.', 'error');
        return;
    }
    
    const firstOwnerId = selectedRecords[0].OwnerId;
    const allSameOwner = selectedRecords.every(record => record.OwnerId === firstOwnerId);
    
    if (!allSameOwner) {
        this.showToast('Error', 'All selected steps must have the same owner (Queue).', 'error');
        return;
    }


    assignSteps({
      stepIds: this.selectedRowIds,
      assignToUserId: this.assignToUser
    })
      .then(() => {
        this.showToast('Success', 'Assigned successfully.', 'success');
        // this.records=null;
        this.handleSearch();
        this.handleRefresh();
      })
      .catch(err => this.showToast('Error during assign', err.body.message, 'error'));
  }

  showToast(title, msg, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message: msg, variant }));
  }

  handleProcessFlowSelection(event) {
    this.selectedFlowId = event.detail;
    this.stepfilter = 'Process_Flow__c = \'' + this.selectedFlowId + '\'';

  }

  handleProcessFlowSelectionName(event) {
    this.selectedFlowName = event.detail;
  }

  handleProcessFlowClear() {
    this.selectedFlowId = null; // Reset selected PRocess ID
    this.selectedFlowName = null; // Reset Selected PRocess Name
  }

  handleFlowStepSelection(event) {
    this.selectedStepId = event.detail;
  }

  handleFlowStepSelectionName(event) {
    this.selectedStepName = event.detail;
  }

  handleFlowStepClear() {
    this.selectedStepId = null; // Reset selected PRocess Step ID
    this.selectedStepName = null; // Reset Selected PRocess Step Name
  }

  handleProjectSelection(event) {
    this.selectedProjectId = event.detail;
  }
  handleProjectClear() {
    this.selectedProjectId = null; // Reset selected project ID
  }

  handleTowerSelection(event) {
    this.selectedTowerId = event.detail;
  }
  handleTowerClear() {
    this.selectedTowerId = null; // Reset selected Tower ID
  }

  handleUserSelection(event) {
    this.selectedUserId = event.detail;
  }
  handleUserClear() {
    this.selectedUserId = null; // Reset selected User ID
  }

  handlePaginatorChange(event) {
    this.recordsToDisplay = event.detail;

    if (this.recordsToDisplay && this.recordsToDisplay.length > 0) {
      this.rowNumberOffset = this.recordsToDisplay[0].rowNumber - 1;
    } else {
      // Handle the case where recordsToDisplay is empty or undefined
      console.error('No records available or recordsToDisplay is undefined');
    }
  }

  handleBpnNumberChange(e) {
      this.bpnNumber = e.detail.value;
  }

  handleRowCountChange(event) {
    const count = parseInt(event.detail.value, 10) || 0;
    this.rowCountToSelect = count;

    const datatable = this.template.querySelector('lightning-datatable');
    if (datatable && this.sortedData.length > 0) {
        // Automatically select the first N rows
        const selectedRows = this.sortedData.slice(0, count);
        
        const selectedIds = selectedRows.map(row => row.Id);//this.sortedData.slice(0, count).map(row => row.id);
        
        datatable.selectedRows = selectedIds;
        this.selectedRowIds = selectedIds;

        if (selectedRows.length > 0) {
          const queueId = selectedRows[0].OwnerId;
          getQueueUsers({ queueGroupId: queueId })
            .then(res => {
              if(this.status!='Not Actioned'){
                this.assignToUserOptions = res;
                this.showAssignSection = true;
              }
        
            })
          .catch(err => this.showToast('Error loading queue users', err.body.message, 'error'));
        } else {
          this.showAssignSection = false;
        }
    }
  }

  handleUnitFileChange(event) {
    const file = event.target.files[0];
    if (file) {
      this.unitFileName = file.name; // Show file name
      this.readCSVFile(file, 'unit');
    }
  }

  handleBookingFileChange(event) {
    const file = event.target.files[0];
    if (file) {
      this.bookingFileName = file.name; // Show file name
      this.readCSVFile(file, 'booking');
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

      if (objName === 'unit') {
        this.fetchUnitIds(names);
      } else if (objName === 'booking') {
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
  }

    handleRefresh() {
    // alert('handleRefresh');
    /*const paginator = this.template.querySelector('c-paginator');
    if (paginator) {
      paginator.reset();
    } */
    //this.records=[];
    this.handleSearch();
  }

  handleClear() {

    this.selectedTowerId = null;
    this.selectedProjectId = null;
    this.selectedFlowId = null;
    this.selectedFlowName = null;
    this.selectedStepId = null;
    this.selectedStepName = null;
    this.selectedUserId = null;
    this.selectedDepartment = null;
    //this.status = null;

    // Clear multi-select picklist
    const statusPicklist = this.template.querySelector('c-multi-select-picklist-lwc');
    if (statusPicklist) {
      statusPicklist.clear();
    }
    this.status = []; // Reset to empty array


    this.records = [];
    this.selectedRowIds = [];
    this.showAssignSection = false;
    this.showTable = false;
    this.rowNumberOffset = 0;
    this.unitIds = [];
    this.bookingIds = [];
    this.unitFileName = '';
    this.bookingFileName = '';
    this.rowCountToSelect = 0;
    this.bpnNumber = '';

    //this.template.querySelector('c-paginator').reset(); // Reset paginator
    /*const paginator = this.template.querySelector('c-paginator');
    if (paginator) {
      paginator.reset();
    } */

    this.template.querySelectorAll('c-generic-lookup-lwc').forEach(lookup => {
      lookup.clearLookup?.();
    });

    const comboboxes = this.template.querySelectorAll('lightning-combobox');
    comboboxes.forEach(combobox => {
      combobox.value = '';
    });
  }



    /*handleFlowChange(e) {
    this.selectedFlow = e.detail.value;

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

    if(this.selectedStep != undefined && this.selectedStep != null){
      const selectedOption = this.stepOptions.find(option => option.value === this.selectedStep);

      if (selectedOption) {
        this.selectedStepName = selectedOption.label;
         // or selectedOption.name if you added that
      }
    }
  }*/

  /*handleDepartmentChange(e) {
    this.department = e.detail.value;
  }*/


    /*async loadXLSX() {
      try {
          await loadScript(this, XLSX);
          this.xlsxLoaded = true;
      } catch (error) {
          this.error = 'Error loading XLSX library: ' + error.message;
      }
  }

  async handleUploadFinished(event) {
      this.isLoading = true;
      //this.error = undefined;
      this.unitIds = [];


      //try {
          if (!this.xlsxLoaded) {
              throw new Error('XLSX library not loaded yet');
          }

          const uploadedFile = event.detail.files[0];
          const fileReader = new FileReader();

          fileReader.onload = async () => {
              //try {
                  const arrayBuffer = fileReader.result;
                  const workbook = XLSX.read(arrayBuffer, { type: 'array' });
                  const firstSheetName = workbook.SheetNames[0];
                  
                  const worksheet = workbook.Sheets[firstSheetName];
                  
                  // Convert sheet to JSON
                  const jsonData = XLSX.utils.sheet_to_json(worksheet);
                  
                  // Extract Name column values
                  const unitNames = jsonData.map(row => row.Name).filter(name => name);
                  
                  if (unitNames.length === 0) {
                      throw new Error('No "Name" column found in the Excel file or all values are empty');
                  }
                  
                  // Query Units
                  const result = await getUnitsByName({ unitNames });
                  
                  if (result && result.length > 0) {
                     this.unitIds = result;
                  } else {
                      this.unitIds = [];
                  }
              } catch (error) {
                  this.error = 'Error processing file: ' + error.message;
              } finally {
                  this.isLoading = false;
              }
          };

          fileReader.readAsArrayBuffer(uploadedFile);
      } catch (error) {
          this.error = error.message;
          this.isLoading = false;
      }
  } */
}