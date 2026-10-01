import { LightningElement, track, wire, api } from 'lwc';
import getChequeWrappers from '@salesforce/apex/ManageChequesController.getChequeWrappers';
import getChequesCount from '@salesforce/apex/ManageChequesController.getChequesCount';
import saveChequeDetails from '@salesforce/apex/ManageChequesController.saveChequeDetails'; 
import getSalesOrderWrapper from '@salesforce/apex/ManageChequesController.getSalesOrderWrapper';
import getUnitData from '@salesforce/apex/ManageChequesController.getUnitData'; 
import getAllProjects from '@salesforce/apex/ManageChequesController.getAllProjects'; 
import unSelectCheque from '@salesforce/apex/ManageChequesController.unSelectCheque'; 
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';  

export default class ManageCheques extends LightningElement {
    @track records = [];
    @api recordId; // Record ID of the current record
    originalData = [];    
    PhasesRawData = [];
    isNextDisabled = true;
    totalNumberOfCheques = 0;
    disablebuttons = true;
    currentPage = 1;
    totalPages = 0;
    offset = 0;
    pageSize = 10;
    isLoading = false;
    isTableLoading = false;
    shownoCheques = false;
    @track error;
    showModal = false;  
    showNoproperSo = false;
    startDate;
    endDate;
    selectedProject;
    selectedPhase; 
    projectRawData = [];
    allProjects = [];
    phaseOptions = [];   
    showfilters = true;
    allrecords = [];
    isFilterApplied = false;
    disSave = true
    disConfirm = true;
    savebeforeNext = false;
    selectedCustomer;
    selectedChequeNo;
    selectedPayee;
    selectedUnit;
    selectedRecords = [];

    connectedCallback() {
        if(!this.recordId) {
            this.getProjects();
        } else {
            this.showfilters = false;
        }

        this.getChequesCount();
        this.isLoading = true;
        this.getChequeWrappers();
        this.isLoading = false;

    } 

    async getChequeWrappers () {
        try {
            this.offset = (this.currentPage - 1) * this.pageSize;
            this.records = await getChequeWrappers({ offsetValue: this.offset, pageSize : this.pageSize, recordId : this.recordId});
            this.allrecords = this.records;
            if(this.records && this.records.length > 0) {
                this.selectedRecords = [... this.selectedRecords, ... this.records.filter(record => record.isSelected)];
                this.shownoCheques = false;
                this.buttonDisable();
            }
        } catch(error) {
            if(this.records) {
               this.showNoproperSo = true;
            } else {
                this.shownoCheques = true;}
        }
    }

    async getChequesCount () {
        try {
            this.totalNumberOfCheques = await getChequesCount({ recordId : this.recordId});
            this.totalPages = Math.ceil(this.totalNumberOfCheques / this.pageSize);
            if(this.totalNumberOfCheques === 0 || this.totalNumberOfCheques === undefined) {
                this.shownoCheques = true;
                this.records = [];
            }
            this.isNextDisabled = this.currentPage == this.totalPages;
            this.disablebuttons = this.totalNumberOfCheques === 0
        } catch(error) {
        }
    }

    async getProjects() {
        try{            
            let projectRawData = await getAllProjects();
            let phaseRawData = []    
            if(projectRawData && projectRawData.length > 0) {
                let projects = [];
                projectRawData.forEach(ele => {
                    let project = {};
                    project.label = ele.Name;
                    project.value = ele.Id;
                    projects.push(project);                     
                    if(ele.BuildingsSections__r && ele.BuildingsSections__r.length > 0) {
                         phaseRawData = [...phaseRawData, ...ele.BuildingsSections__r];
                    }
                });
                this.projectRawData = projectRawData;
                this.selectedProject = 'All';
                this.allProjects = [{label: 'All', value: 'All'}, ...projects];
                this.setPhaseOptions(phaseRawData);
            } 
        } catch(error){
            
        } finally{
           
        }
    }

    async handleSearch(event) {
        const recordId = event.target.dataset.id;
        const field = event.target.name;
        const value = event.target.value;
        this.isFilterApplied = true;
        if(value === '' || value === undefined || value === null) {
            this.records = this.allrecords;
            this.isFilterApplied = false;
            return;
        } else {
            try{
                if(event.target.value) {
                    if(field === 'unit') {
                        this.selectedUnit = event.target.value;
                    } else if(field === 'customerName') {
                        this.selectedCustomer = event.target.value;                   
                    } else if(field === 'chequeNo') {
                        this.selectedChequeNo = event.target.value;
                    } else if(field === 'payee') {
                        this.selectedPayee = event.target.value;
                    }
                    this.records = await getUnitData({projectName : this.selectedProject, phaseId : this.selectedPhase, unitSearchKey: this.selectedUnit, 
                                                startDate : this.startDate, endDate : this.endDate, customerSearchKey: this.selectedCustomer, chequeNoSearchKey: this.selectedChequeNo, payeeSearchKey : this.selectedPayee});
                } else {
                    this.records = this.allrecords;
                }
            } catch(error) {
                this.showErrorToast({type: "error", message : "Cheque Search error, Please contact admin", "label": "Cheques Search issue"});
            } finally{
            }
        }
        
    }

    async loadPhaseOptions() {
       if(this.selectedProject === 'All' || this.selectedProject === '' || this.selectedProject === undefined) {
            this.setPhaseOptions(this.PhasesRawData);         
       } else {
            let phases = [];
            this.PhasesRawData.forEach(element => {
                if(element.Project__c === this.selectedProject) {
                    phases.push({label : element.Name, value: element.Id});
                } 
                this.phaseOptions = phases;
            }); 
       }
    }

    setPhaseOptions(phaseRawData) {
            if(phaseRawData && phaseRawData.length > 0) {
                let phases = [];
                phaseRawData.forEach(ele => {
                    let phase = {};
                    phase.label = ele.Name;
                    phase.value = ele.Id;   
                    phases.push(phase);
                });
                this.selectedPhase = 'All';
                this.phaseOptions = [{label: 'All', value: 'All'}  , ...phases];
            } else {
                this.phaseOptions = [];
            }
            this.PhasesRawData = phaseRawData;
    }

    async handleChange(event) {
        const recordId = event.target.dataset.id;
        const field = event.target.dataset.field;
        const value = event.target.value;
        const name = event.target.name;
         const title = event.target.title;
        event.preventDefault();
        if(name == 'unit' && value !== '' && value !== undefined && value !== null) {
            this.records = this.records.map(row => {
                if (row.Id === recordId) {
                    return { ...row, [field]: value };
                }
                return row;
            });
            this.getSalesOrderWrapper(value , recordId);
        }

        if(name == 'customer' && value !== '' && value !== undefined && value !== null) {
            this.records = this.records.map(row => {
                if (row.Id === recordId) {
                    return { ...row, customerId: value };
                }
                return row;
            });
        }

        if(name == 'mileStone' && value !== '' && value !== undefined && value !== null) {
            this.records = this.records.map(row => {
                if (row.Id === recordId) {
                    row.salesOrderInstallmentId = value;
                    if(row.soiOptions && row.soiOptions.length > 0) {
                        row.soiOptions.forEach(option => {
                            if(option.value === value) {
                                row.mileStone = option.label;
                            }
                        });
                    }
                    
                    if(value) {
                       if(!row.soiInvoice) {                       
                            this.getSalesOrderWrapper(row.unit , value);
                        };
                        let invoice = row.soiInvoice[value];
                        if(invoice) {   
                            row.balanceAmount = invoice.InvoiceBalance__c;
                            row.invoiceId = invoice.Id;
                            row.chargeId = invoice.Charge__c;
                            
                        }
                        
                        
                    }         
                }
                return row;
                
            }); 
            this.copyCurrentRecordtoSelected();           
            
        }

        if(name == 'checkbox') {
            let isChecked = event.target.checked;
             let records = this.records.map(row => {
                if (row.Id === recordId) {
                    let isPrevSelected = row.isSelected;
                    row.isSelected = isChecked;
                    if(isChecked) {
                        this.selectedRecords.push(row);
                        if(row.amount <= row.balanceAmount) {
                            this.showErrorToast({type: "warning", title:"Warning", message : 'Cheque Amount ('+row.amount+') is more than Invoice balance amount :' +row.balanceAmount});
                        }
                    }  else {
                        if(isPrevSelected && !isChecked) {
                            this.selectedRecords = this.selectedRecords.filter(selectedRow => selectedRow.Id !== row.Id);
                            unSelectCheque({thisWrapper : row});
                        }
                    }
                    row.isSelected = isChecked;
                    this.buttonDisable();
                }
                return row;
            });            
             this.records = records;
        }

        if(name == 'confirm') {
            this.disConfirm = true;
            this.handleSave(name);
        }
        if(name == 'startDate') {
            this.startDate = value;
            this.records = await getUnitData({projectName : this.selectedProject, phaseId : this.selectedPhase, unitSearchKey: this.selectedUnit, 
                                            startDate : this.startDate, endDate : this.endDate, customerSearchKey: this.selectedCustomer, chequeNoSearchKey: this.selectedChequeNo, payeeSearchKey : this.selectedPayee});
        }
        if(name == 'endDate') {
            this.endDate = value;
            this.records = await getUnitData({projectName : this.selectedProject, phaseId : this.selectedPhase, unitSearchKey: this.selectedUnit, 
                                            startDate : this.startDate, endDate : this.endDate, customerSearchKey: this.selectedCustomer, chequeNoSearchKey: this.selectedChequeNo, payeeSearchKey : this.selectedPayee});
        }
        if(name == 'save') {
            this.handleSave(name);
        }
        if(name == 'cancel') {
            this.closeModal();
        }
        if(name == 'cancel') {
            this.closeModal();
        }
        if(name == 'project') {
            this.selectedProject = value;
            this.selectedPhase = '';
            this.selectedUnit = '';
            this.loadPhaseOptions();
            this.records = await getUnitData({projectName : this.selectedProject, phaseId : this.selectedPhase, unitSearchKey: this.selectedUnit, 
                                            startDate : this.startDate, endDate : this.endDate, customerSearchKey: this.selectedCustomer, chequeNoSearchKey: this.selectedChequeNo, payeeSearchKey : this.selectedPayee});

        }
        if(name == 'phase') {
            this.selectedPhase = value;
            this.selectedUnit = '';
            this.records = await getUnitData({projectName : this.selectedProject, phaseId : this.selectedPhase, unitSearchKey: this.selectedUnit, 
                                            startDate : this.startDate, endDate : this.endDate, customerSearchKey: this.selectedCustomer, chequeNoSearchKey: this.selectedChequeNo, payeeSearchKey : this.selectedPayee});
        }

    }

    copyCurrentRecordtoSelected() {
        this.records.forEach(row => {
            if(row.isSelected) {
                let index = this.selectedRecords.findIndex(selectedRow => selectedRow.Id === row.Id);
                if(index >= 0) {
                    this.selectedRecords[index] = row; // Update existing record
                }
            }
        });
    }

    async getSalesOrderWrapper(unitId, recordId) {
        if(unitId) {
            try {
                const salesOrderWrapper = await getSalesOrderWrapper({ unitId: unitId });
                    let records = this.records;
                    records = records.map(rec => {
                        if (rec.Id === recordId) {
                            if(salesOrderWrapper) {
                                rec.soiOptions =  salesOrderWrapper.soiOptions;
                                rec.salesOrderId = salesOrderWrapper.soId;
                                rec.salesOrderName = salesOrderWrapper.soName;
                                rec.salesOrderLink = salesOrderWrapper.soLink;
                                rec.soiInvoice = salesOrderWrapper.soiInvoice;
                                rec.soiBalance = salesOrderWrapper.soiBalance;
                            } else {
                                rec.soiOptions =  undefined;
                                rec.salesOrderId = '';
                                rec.salesOrderName = '';
                                rec.salesOrderLink = '';
                                rec.soiInvoice = '';
                                rec.soiBalance = '';
                            }

                            rec.unit = unitId; 
                        }
                        return rec;
                    });
                    this.records = records;
                    this.copyCurrentRecordtoSelected();
            } catch(error) {
            }
        }
    }

    handlecustomerChange(name) {
        let selectedCustomer = this.template.querySelector('lightning-input[name="customerName"]').value;
        if(selectedCustomer) {
            this.records = this.allrecords.filter(record => record.customerName && record.customerName.toLowerCase().includes(selectedCustomer.toLowerCase()));
        } else {
            this.records = this.allrecords;
        }
    }

    buttonDisable() {
        if(this.selectedRecords && this.selectedRecords.length > 0) {
            this.disConfirm = false;
            this.disSave = false;
        } else {
            this.disConfirm = true;
            this.disSave = true;
            this.disablebuttons = true;
        }
    }

    showErrorToast(error) {
        const evt = new ShowToastEvent({
            title: error.Title,
            message: error.message,
            variant: error.type,
        });
        this.dispatchEvent(evt); 
    }

  async handleSave(action) {
        let selectedRecords = this.selectedRecords
        if(selectedRecords && selectedRecords.length > 0) {
            try{
                let result = await saveChequeDetails({wrappers : selectedRecords, action : action});
                if(result) {
                    this.showModal = true;
                    if(result.length > 0) {
                        result.forEach(ele => {
                            if(ele.type == "true") {
                                ele.type = true;
                            } else {
                                ele.type = false;
                            }
                        });
                        this.errors = result;  
                    } 
                }
            } catch(error) {
                console.error('Error saving cheques:', error);
                this.showErrorToast({type: "error", title:"Error", message : error.message});
            }
        } else {
            this.showErrorToast({type: "error", title:"Error", message : 'Please select at least one cheque to save.'});
        }
    }

    get isPreviousDisabled() {
        return this.currentPage === 1;
    }

    get isNextDisabled() {
        return this.currentPage === this.totalPages || this.totalNumberOfCheques == 0 || this.totalNumberOfCheques == undefined;
    }

    handlePrevious() {
        this.handlePrevNext('save');
        if (this.currentPage > 1) {
            this.currentPage--;
            this.getChequeWrappers();
        }
    }

    async handlePrevNext(action) {
        let selectedRecords = this.records.filter(record => record.isSelected);
        if(selectedRecords && selectedRecords.length > 0) {
            try{
                let result = await saveChequeDetails({wrappers : selectedRecords, action : action});
            } catch(error) {
                console.error('Error saving cheques:', error);
                this.showErrorToast({type: "error", title:"Error", message : error.message});
            }
        } 
    }

    handleNext() {
        this.handlePrevNext('save');
        if (this.currentPage < this.totalPages) {
            this.currentPage++;
            this.getChequeWrappers();
        }
    }
    closeModal() {
        this.showModal = false;
        this.getChequeWrappers();
        this.getChequesCount();
        this.isNextDisabled = this.totalNumberOfCheques === 0 || this.totalNumberOfCheques === undefined;
        this.disablebuttons = this.totalNumberOfCheques === 0   || this.totalNumberOfCheques == null;
    }
}