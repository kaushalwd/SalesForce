import { LightningElement, wire, track  } from 'lwc';
import getProjectDetails from "@salesforce/apex/DirectDebitLWCController.getProjectDetails";
import getUnitDetails from "@salesforce/apex/DirectDebitLWCController.getUnitDetails";
import getPhaseDetails from "@salesforce/apex/DirectDebitLWCController.getPhaseDetails";
import getSaleOrderDetails from "@salesforce/apex/DirectDebitLWCController.getSaleOrderDetails";
import getSalesOrderInstallments from "@salesforce/apex/DirectDebitLWCController.getSalesOrderInstallments";
import createDirectDebitTransaction from "@salesforce/apex/DirectDebitLWCController.createDirectDebitTransaction";
import CollectionLimit from '@salesforce/label/c.CollectionLimit';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';


export default class DirectDebitCollectionScreen extends LightningElement {

    mainColumns = [    
        { label: 'SOI Name', fieldName: 'Name', sortable: "true" },
        { label: 'Sales Order Name', fieldName: 'SalesOrderName', sortable: "true" },
        { label: 'Unit Name', fieldName: 'UnitName',   sortable: "true"  },
        { label: 'Installment Amount', fieldName: 'InstallmentAmount__c',   sortable: "true"  },    
        { label: 'Account Name', fieldName: 'AccountName',   sortable: "true"  },
        { label: 'DD Owner Name', fieldName: 'DDOwnerName',   sortable: "true"  },
        { label: 'Milestone Number', fieldName: 'MilestoneNumber__c',   sortable: "true"  },
        { label: 'Payment Status', fieldName: 'PaymentStatus__c',   sortable: "true"  },	
        { label: 'Milestone Date', fieldName: 'MilestoneDate__c',   sortable: "true"  }    
    ];
    projectNamePickListValues;
    phaseNamePickListValues = [];
    saleOrderNamePickListValues = [];

    totalPages;
    rowsTableData = [];
    recordsToDisplay = []; 
    allSelectedRows = [];
    selectedDatatableRows = [];
    isLoading=false;
    isLoadingModal = false;
    maturitydate;
    maturityStartDate;
    maturityEndDate;
    pageSize = 50;
    dataMap={};
    draftValueMap={};
    draftValueMapIds = [];
    finalInstallmentCollectionAmtMap ={};
    errorIds = [];
    hasRowError = false;
    finalInstallmentCollectionIds = [];
    finalInstallmentCollectionCount = 0;
    isfinalInstallmentwarning = false;
    popupMessage = '';
    isInitiateCollections = false;
    hasSRforSelectedInstallmentLine = false;
    errors;
    _selected = [];
    selectedValues = [];
    holdingSelectedRowsObj={};

    projectNameField;
    phaseNameField;
    saleOrderNameField;

    @track pageNumbershavingErrors = '';
    @track columns = this.mainColumns;
    @track data = [];
    @track soInstallmentDisplay = [];
    @track totalInstallments = 0;
    @track sortBy;
    @track sortDirection = 'asc';
    @track pageNumber = 1;
    @track totalPages = 1;
    @track disablesendForDD = true;
    @track isPagination = false;
    @track selectedSoInstallmentMap = new Map();
    @track collectionSent = false;
    @track exportData = [];
    @track enableExcel = false;
    onOpen = false;

    label = {
        CollectionLimit
    };
   
    handleValidation() {
        let projectNameField = this.template.querySelector(".projectNameField");
        if (!projectNameField.value) {
            projectNameField.setCustomValidity("Project must se selected to do successful search");
        } else {
            projectNameField.setCustomValidity("");
        }
        projectNameField.reportValidity();
    }

    async handleSearchAll(event) {
        console.log('this.columns >>>> 22  >> ' + JSON.stringify(this.mainColumns));
        this.isLoading = true;
        this.data = [];
        this.dataMap = {};        
        let newData = [];

        if (!this.projectNameField) {
            this.isLoading = false;
            const evt = new ShowToastEvent({
                title: 'Project',
                message: 'Project must be selected to do successful search',
                variant: 'error',
            });
            this.dispatchEvent(evt);
        } else {
            console.log('this.projectNameField::' + this.projectNameField);
            console.log('this.projectNameField:: maturityEndDate ' + this.maturityEndDate);
            console.log('this.projectNameField:: maturityEndDate ' + this.maturityEndDate);
            console.log('this.projectNameField::  maturityStartDate  ' + this.maturityStartDate);
            console.log('this.projectNameField:: maturityEndDate ' + this.maturityEndDate);
            if ((this.maturityStartDate != undefined && (this.maturityEndDate == null || this.maturityEndDate == undefined)) 
                || ((this.maturityStartDate == null || this.maturityStartDate == undefined) && this.maturityEndDate != undefined)) {
                const evt = new ShowToastEvent({
                    title: 'Installment Lines',
                    message: 'Start and End Dates are Mandatory to do successful search',
                    variant: 'error',
                });
                this.dispatchEvent(evt);
                this.isLoading = false;
                return false;
            }
            if (this.maturityStartDate > this.maturityEndDate) {
                this.template.querySelector('.maturityStartDate').setCustomValidity("Installment Start date cannot be greater than Installment End Date");
                this.isLoading = false;
            } else {
                this.template.querySelector('.maturityStartDate').setCustomValidity("");
            }

            let newTableData = [];
            let soInstallments = [];

            var condition = (this.projectNameField !== '' && this.projectNameField !== null && this.projectNameField !== undefined ?
                ' SalesOrder__r.Unit__r.Phase__r.Project__r.Name =\'' + this.projectNameField + '\'' : '');

            condition += (this.phaseNameField !== '' && this.phaseNameField !== null && this.phaseNameField !== undefined ?
                (condition !== '' && condition !== null ? ' AND ' : '') +
                ' SalesOrder__r.Unit__r.Phase__r.Name =\'' + this.phaseNameField + '\'' : '');
            
            condition += (this.saleOrderNameField !== '' && this.saleOrderNameField !== null && this.saleOrderNameField !== undefined ?
                (condition !== '' && condition !== null ? ' AND ' : '') +
                ' SalesOrder__r.Name =\'' + this.saleOrderNameField + '\'' : '');
            
            if (this.maturityStartDate && this.maturityEndDate) {
                condition += (condition ? ' AND ' : '') +
                    ' MilestoneDate__c >= ' + this.maturityStartDate +
                    ' AND MilestoneDate__c <= ' + this.maturityEndDate;
            }

            var query;
            if (condition !== '' || condition !== null || condition !== undefined) {
                
                query = 'select Id, Name, SalesOrder__r.Unit__r.Phase__r.Project__r.Name, SalesOrder__r.Unit__r.Phase__r.Name, '+
                        'InstallmentAmount__c, SalesOrder__r.Unit__c, SalesOrder__r.Unit__r.Name, SalesOrder__r.CustomerAccount__r.Name,'+
                        'InstalmentPaymentDueDate__c, InstalmentPaymentDueDateArabic__c, MilestoneDate__c, MilestoneNumber__c, Milestone__c,'+
                        ' SalesOrder__r.Name, PaymentStatus__c  from SalesOrderInstallments__c  where' +
                        condition;

                console.log('query >>>> 22 ' + query);
                newData = await getSalesOrderInstallments({
                                                            query: query
                                                          });
                this.isLoading = false;                                          
                //console.log('Sales Order Installments >>>>   ' + JSON.stringify(newData));
                for (let i = 0; i < newData.length; i++) {
                        newTableData.push(newData[i]);
                        newData[i].soInstallment.DDOwnerName = newData[i].ddOwnerName;
                        soInstallments.push(newData[i].soInstallment);
                        this.dataMap[newData[i].Id] = newData[i];
                }
                if (newTableData.length > 0) {
                    this.enableExcel = true;
                }
                if (newTableData.length < 1 && !this.collectionSent) {
                    const evt = new ShowToastEvent({
                        title: 'Installment Lines',
                        message: 'No Installment Lines found',
                        variant: 'error',
                    });
                    this.dispatchEvent(evt);
                }
                if (this.collectionSent) {
                    this.collectionSent = false;
                }
                                
                this.data = newTableData;
                soInstallments.forEach(installment => {
                    installment.Name = installment.Name;
                    installment.SalesOrderName = installment.SalesOrder__r.Name;
                    installment.ProjectName = installment.SalesOrder__r.Unit__r.Phase__r.Project__r.Name;
                    installment.PhaseName = installment.SalesOrder__r.Unit__r.Phase__r.Name;
                    installment.UnitName = installment.SalesOrder__r.Unit__r.Name;
                    installment.InstallmentAmount__c = installment.InstallmentAmount__c;
                    installment.AccountName = installment.SalesOrder__r.CustomerAccount__r.Name;
                    installment.MilestoneNumber__c = installment.MilestoneNumber__c;
                    installment.PaymentStatus__c = installment.PaymentStatus__c;
                    installment.MilestoneDate__c = installment.MilestoneDate__c;
                });
                
                /*this.recordsToDisplay = soInstallments;                
                console.log('this.recordsToDisplay >>>>>>>  '+JSON.stringify(this.recordsToDisplay));
                this.totalInstallments = newTableData.length;
                this.pageSize = 50;*/
                //this.paginationHelper();
                this.data = soInstallments;
                this.totalInstallments = this.data.length;
                this.pageSize = 50;
                this.pageNumber = 1;
                this.paginationHelper();
                console.log('this.recordsToDisplay (page 1) >>>>>>>  ' + JSON.stringify(this.recordsToDisplay));
            }
            this.isLoading = false;
        }
        //projectNameField.reportValidity();
    }
    exportAsExcel() {
        console.log('>>>> exportAsExcel >>>> '+JSON.stringify(this.recordsToDisplay));
        let columnHeader = ["Sales Order Name","Project Name","Building Name","Unit Name","Installment Amount","Account Name","DD Owner Name","Milestone Number","Payment Status","Installement Payment Due Date"];
        let jsonKeys = ["SalesOrderName","ProjectName","BuildingName","UnitName","InstallmentAmount__c","AccountName","DDOwnerName","MilestoneNumber__c","PaymentStatus__c","InstalmentPaymentDueDate__c"];
        var jsonRecordsData = this.recordsToDisplay;
        let csvIterativeData;
        let csvSeperator;
        let newLineCharacter;
        csvSeperator = ",";
        newLineCharacter = "\n";
        csvIterativeData = "";
        csvIterativeData += columnHeader.join(csvSeperator);
        csvIterativeData += newLineCharacter;
        for (let i = 0; i < jsonRecordsData.length; i++) {
            let counter = 0;
            for (let iteratorObj in jsonKeys) {
                let dataKey = jsonKeys[iteratorObj];
                if (counter > 0) {
                    csvIterativeData += csvSeperator;
                }
                if (jsonRecordsData[i][dataKey] !== null && jsonRecordsData[i][dataKey] !== undefined) {
                    console.log(jsonRecordsData[i][dataKey]);
                    csvIterativeData += '"' + jsonRecordsData[i][dataKey] + '"';
                } else {
                    csvIterativeData += '""';
                }
                counter++;
            }
            csvIterativeData += newLineCharacter;
        }
        this.hrefdata = "data:text/csv;charset=utf-8," + encodeURI(csvIterativeData);
        csvIterativeData = csvIterativeData.replace(' ', '_SPACE_');
        if (csvIterativeData.includes('#')) {
            csvIterativeData = csvIterativeData.replaceAll('#', '');
        }
        csvIterativeData = csvIterativeData.replace(/"/g, '');
        csvIterativeData = csvIterativeData.replace('_SPACE_', ' ');
        var downloadLink = document.createElement("a");
        document.body.appendChild(downloadLink);
        downloadLink.href = 'data:application/vnd.ms-excel,' + csvIterativeData;
        downloadLink.download = 'Direct Debit Collection_' + this.projectNameField + '.xls.csv';
        downloadLink.click();
    }
    get bDisableFirst() {
        return this.pageNumber == 1;
    }
    get bDisableLast() {
        return this.pageNumber == this.totalPages;
    }

    handleComboBoxChange(event) {
        this.pageSize = event.target.value;
        this.paginationHelper();
    }
    handleChange(event) {
        console.log(event.target.name);
        console.log(event.target.value);
        this.phaseNameField = event.target.value;
        console.log('>>>>>> this.phaseNameField >>  '+this.phaseNameField);
    }
    handleMaturityDateChange(event) {
        console.log('event.target.name::' + event.target.value);
        this.maturitydate = event.target.value;
        if (event.target.name == 'maturityStartDate') {
            this.maturityStartDate = event.target.value;
        }
        if (event.target.name == 'maturityEndDate') {
            this.maturityEndDate = event.target.value;
            console.log('maturityEndDate ::  maturitydate '  + this.maturitydate);
        }        
    }
    handleDDBankChange(event) {
        this[event.target.name] = event.target.value;
    }
    async connectedCallback() {
        console.log('>>>> connectedCallback >>>>');
        this.getProjectDropDownData();
    }

    paginationHelper(event) {
        this.recordsToDisplay = [];
        this.totalPages = Math.ceil(this.totalInstallments / this.pageSize);
        if (this.pageNumber <= 1) {
            this.pageNumber = 1;
        } else if (this.pageNumber >= this.totalPages) {
            this.pageNumber = this.totalPages;
        }
        for (let i = (this.pageNumber - 1) * this.pageSize; i < this.pageNumber * this.pageSize; i++) {
            if (i === this.totalInstallments) {
                break;
            }
            this.recordsToDisplay.push(this.data[i]);
        }
        for (var i = 0; i <= this.totalPages; i++) {
            if (this.holdingSelectedRowsObj[i] != null) {
                for (let j = 0; j < this.holdingSelectedRowsObj[i].length; j++) {
                    if (this.errors == undefined || JSON.stringify(this.errors) == '{}') {
                        this.hasRowError = false;
                    } else if ((this.errors != undefined || JSON.stringify(this.errors) != '{}') && (this.errors.rows[this.holdingSelectedRowsObj[i][j]] == undefined || JSON.stringify(this.errors.rows[this.holdingSelectedRowsObj[i][j]]) == '{}')) {
                        this.hasRowError = false;
                    } else {
                        this.hasRowError = true;
                        break;
                    }
                }
                if (this.hasRowError) {
                    break;
                }
            }
        }

        if (this.finalInstallmentCollectionCount > 0 && !this.hasRowError) {
            this.disablesendForDD = false;
        } else {
            this.disablesendForDD = true;
        }

    }


    previousPage() {
        if (this.selectedDatatableRows.length > 0 && (this.holdingSelectedRowsObj[this.pageNumber] == null ||
                this.holdingSelectedRowsObj[this.pageNumber].length <= 0)) {
            this.holdingSelectedRowsObj[this.pageNumber] = this.selectedDatatableRows;
            console.log(this.holdingSelectedRowsObj[this.pageNumber]);
        } else if (this.holdingSelectedRowsObj[this.pageNumber] != null) {
            this.holdingSelectedRowsObj[this.pageNumber] = this.selectedDatatableRows;
            console.log(this.holdingSelectedRowsObj[this.pageNumber]);
        }
        this.pageNumber = this.pageNumber - 1;
        this.paginationHelper();
        if (this.holdingSelectedRowsObj[this.pageNumber] != null) {
            this.selectedDatatableRows = this.holdingSelectedRowsObj[this.pageNumber];
        }
        for (var i = 0; i <= this.totalPages; i++) {
            if (this.holdingSelectedRowsObj[i] != null) {
                for (let j = 0; j < this.holdingSelectedRowsObj[i].length; j++) {
                    if (this.errors == undefined || JSON.stringify(this.errors) == '{}') {
                        this.hasRowError = false;
                    } else if ((this.errors != undefined || JSON.stringify(this.errors) != '{}') && (this.errors.rows[this.holdingSelectedRowsObj[i][j]] == undefined || JSON.stringify(this.errors.rows[this.holdingSelectedRowsObj[i][j]]) == '{}')) {
                        this.hasRowError = false;
                    } else {
                        this.hasRowError = true;
                        break;
                    }

                }
                if (this.hasRowError) {
                    break;
                }

            }
        }

        if (this.finalInstallmentCollectionCount > 0 && !this.hasRowError) {
            this.disablesendForDD = false;
        } else {
            this.disablesendForDD = true;
        }

    }
    nextPage() {
        this.finalInstallmentCollectionAmtMap = {};
        this.hasRowError = false;
        if (this.selectedDatatableRows.length > 0 && (this.holdingSelectedRowsObj[this.pageNumber] == null ||
                this.holdingSelectedRowsObj[this.pageNumber].length <= 0)) {
            this.holdingSelectedRowsObj[this.pageNumber] = this.selectedDatatableRows;
            console.log(this.holdingSelectedRowsObj[this.pageNumber]);
        } else if (this.holdingSelectedRowsObj[this.pageNumber] != null) {
            this.holdingSelectedRowsObj[this.pageNumber] = this.selectedDatatableRows;
        }
        this.pageNumber = this.pageNumber + 1;
        this.paginationHelper();
        if (this.holdingSelectedRowsObj[this.pageNumber] != null) {
            this.selectedDatatableRows = this.holdingSelectedRowsObj[this.pageNumber];
        }

        for (var i = 0; i <= this.totalPages; i++) {
            if (this.holdingSelectedRowsObj[i] != null) {
                for (let j = 0; j < this.holdingSelectedRowsObj[i].length; j++) {
                    if (this.errors == undefined || JSON.stringify(this.errors) == '{}') {
                        this.hasRowError = false;
                    } else if ((this.errors != undefined || JSON.stringify(this.errors) != '{}') && (this.errors.rows[this.holdingSelectedRowsObj[i][j]] == undefined || JSON.stringify(this.errors.rows[this.holdingSelectedRowsObj[i][j]]) == '{}')) {
                        this.hasRowError = false;
                    } else {
                        this.hasRowError = true;
                        break;
                    }

                }
                if (this.hasRowError) {
                    break;
                }

            }
        }

        if (this.finalInstallmentCollectionCount > 0 && !this.hasRowError) {
            this.disablesendForDD = false;
        } else {
            this.disablesendForDD = true;
        }
    }
    firstPage() {
        if (this.selectedDatatableRows.length > 0 && (this.holdingSelectedRowsObj[this.pageNumber] == null ||
                this.holdingSelectedRowsObj[this.pageNumber].length <= 0)) {
            this.holdingSelectedRowsObj[this.pageNumber] = this.selectedDatatableRows;
            console.log(this.holdingSelectedRowsObj[this.pageNumber]);
        } else if (this.holdingSelectedRowsObj[this.pageNumber] != null) {
            this.holdingSelectedRowsObj[this.pageNumber] = this.selectedDatatableRows;
            console.log(this.holdingSelectedRowsObj[this.pageNumber]);
        }
        this.pageNumber = 1;
        this.paginationHelper();
        if (this.holdingSelectedRowsObj[this.pageNumber] != null) {
            this.selectedDatatableRows = this.holdingSelectedRowsObj[this.pageNumber];
        }
        for (var i = 0; i <= this.totalPages; i++) {
            if (this.holdingSelectedRowsObj[i] != null) {
                for (let j = 0; j < this.holdingSelectedRowsObj[i].length; j++) {
                    if (this.errors == undefined || JSON.stringify(this.errors) == '{}') {
                        this.hasRowError = false;
                    } else if ((this.errors != undefined || JSON.stringify(this.errors) != '{}') && (this.errors.rows[this.holdingSelectedRowsObj[i][j]] == undefined || JSON.stringify(this.errors.rows[this.holdingSelectedRowsObj[i][j]]) == '{}')) {
                        this.hasRowError = false;
                    } else {
                        this.hasRowError = true;
                        break;
                    }

                }
                if (this.hasRowError) {
                    break;
                }
            }
        }

        if (this.finalInstallmentCollectionCount > 0 && !this.hasRowError) {
            this.disablesendForDD = false;
        } else {
            this.disablesendForDD = true;
        }

    }
    lastPage() {
        if (this.selectedDatatableRows.length > 0 && (this.holdingSelectedRowsObj[this.pageNumber] == null ||
                this.holdingSelectedRowsObj[this.pageNumber].length <= 0)) {
            this.holdingSelectedRowsObj[this.pageNumber] = this.selectedDatatableRows;
            console.log(this.holdingSelectedRowsObj[this.pageNumber]);
        } else if (this.holdingSelectedRowsObj[this.pageNumber] != null) {
            this.holdingSelectedRowsObj[this.pageNumber] = this.selectedDatatableRows;
            console.log(this.holdingSelectedRowsObj[this.pageNumber]);
        }
        this.pageNumber = this.totalPages;
        this.paginationHelper();
        if (this.holdingSelectedRowsObj[this.pageNumber] != null) {
            this.selectedDatatableRows = this.holdingSelectedRowsObj[this.pageNumber];
        }
        for (var i = 0; i <= this.totalPages; i++) {
            if (this.holdingSelectedRowsObj[i] != null) {
                for (let j = 0; j < this.holdingSelectedRowsObj[i].length; j++) {
                    if (this.errors == undefined || JSON.stringify(this.errors) == '{}') {
                        this.hasRowError = false;
                    } else if ((this.errors != undefined || JSON.stringify(this.errors) != '{}') && (this.errors.rows[this.holdingSelectedRowsObj[i][j]] == undefined || JSON.stringify(this.errors.rows[this.holdingSelectedRowsObj[i][j]]) == '{}')) {
                        this.hasRowError = false;
                    } else {
                        this.hasRowError = true;
                        break;
                    }
                }
                if (this.hasRowError) {
                    break;
                }
            }
        }

        if (this.finalInstallmentCollectionCount > 0 && !this.hasRowError) {
            this.disablesendForDD = false;
        } else {
            this.disablesendForDD = true;
        }
    }

    async handlePhaseChange(event){
        let phaseName = event.target.value;
        this.phaseNameField = phaseName;
        this.getSaleOrderDetails(phaseName);
    }

    async handleProjectChange(event) {
        let projectName = event.target.value;
        this.projectNameField = projectName;
        this.getPhaseDetails(projectName);
    }

    async handleSaleOrderChange(event) {
        let saleOrderName = event.target.value;
        this.saleOrderNameField = saleOrderName;        
    }

    async getPhaseDetails(projectName) {
        console.log('>>>>  handlePhaseChange  >>>>  '+projectName);
        let dropdownData = [];
        let phaseNamePickListValuesMap = [];
        
        try{
                dropdownData = await getPhaseDetails({projectName : projectName});
                for (let i = 0; i < dropdownData.length; i++) {
                    if (dropdownData[i].Name ) {
                        phaseNamePickListValuesMap.push({
                            label: dropdownData[i].Name,
                            value: dropdownData[i].Name
                        });
                    }
                }
                console.log('>>>>> DirectDebitCollection >>>>  ' + JSON.stringify(phaseNamePickListValuesMap));
                this.phaseNamePickListValues = phaseNamePickListValuesMap;
        }catch(error){
            console.error('Error fetching project names:', error);
        }        
    }

    async getSaleOrderDetails(phaseName) {
        console.log('>>>>  getSaleOrderDetails  >>>>  '+phaseName);
        let dropdownData = [];
        let saleOrderNamePickListValuesMap = [];
        
        try{
                dropdownData = await getSaleOrderDetails({phaseName : phaseName});
                for (let i = 0; i < dropdownData.length; i++) {
                    if (dropdownData[i].Name ) {
                        saleOrderNamePickListValuesMap.push({
                            label: dropdownData[i].Name,
                            value: dropdownData[i].Name
                        });
                    }
                }
                console.log('>>>>> saleOrderNamePickListValuesMap >>>>  ' + JSON.stringify(saleOrderNamePickListValuesMap));
                this.saleOrderNamePickListValues = saleOrderNamePickListValuesMap;
        }catch(error){
            console.error('Error fetching project names:', error);
        }        
    }

    async getProjectDropDownData() {

        console.log('>>>>  getProjectDropDownData  >>>>');
        let projectNameData = [];
        let dropdownData = [];
        let newLocationNamesDataTableData = [];
        let newLocationNamesData = [];

        try{
                console.log('>>>>  getProjectDropDownData22222  >>>>');
                dropdownData = await getProjectDetails();
                for (let i = 0; i < dropdownData.length; i++) {
                    if (dropdownData[i].Name ) {
                        projectNameData.push({
                            label: dropdownData[i].Name,
                            value: dropdownData[i].Name
                        });
                    }
                }
                console.log('>>>>> DirectDebitCollection >>>>  ' + JSON.stringify(projectNameData));
                this.projectNamePickListValues = projectNameData;
        }catch(error){
            console.error('Error fetching project names:', error);
        }        
    }

    async resetAll() {
        this.data = [];
        this.projectNameField = '';
        this.phaseNameField = '';
        this.saleOrderNameField = '';
        this.ddBank = '';
        this.dataMap = {};
        this.maturitydate = '';
        this.maturityStartDate = '';
        this.maturityEndDate = '';
        this.totalInstallments = 0;
        this.recordsToDisplay = [];
        this.finalInstallmentCollectionAmtMap = {};
        this.finalInstallmentCollectionIds = [];
        this.holdingSelectedRowsObj = {};
        this.errors = {};
        this.draftValueMapIds = [];
        this.draftValueMap = {};
        this.errorIds = [];
        this.draftSelectedIds = [];
        this.finalInstallmentCollectionCount = 0;
        window.location.reload();
    }
    handleRowAction(event) {
        let updatedItemsSet = new Set();
        let selectedItemsSet = new Set();
        let loadedItemsSet = new Set();
        
        this.data.map((event) => {
            console.log('handleRowAction >>>> event.rowId '+event.Id);
            loadedItemsSet.add(event.Id);
        });
        console.log('handleRowAction >>>> loadedItemsSet '+JSON.stringify(loadedItemsSet));
        if (event.detail.selectedRows) {
            event.detail.selectedRows.map((event) => {
                updatedItemsSet.add(event.Id);
            });
            updatedItemsSet.forEach((id) => {
                if (!selectedItemsSet.has(id)) {
                    selectedItemsSet.add(id);
                }
            });
        }
        console.log('handleRowAction >>>> updatedItemsSet '+JSON.stringify(updatedItemsSet));
        
        loadedItemsSet.forEach((id) => {
            if (selectedItemsSet.has(id) && !updatedItemsSet.has(id)) {
                selectedItemsSet.delete(id);
            }
        });

        this.holdingSelectedRowsObj[this.pageNumber] = [...selectedItemsSet];
        console.log('handleRowAction >>>> holdingSelectedRowsObj '+JSON.stringify(this.holdingSelectedRowsObj));
        this.rowsTableData = [];
        let selectedRowsArray = [];

        var selectedRows = event.detail.selectedRows;
        this.allSelectedRows = selectedRows;

        console.log('handleRowAction >>>> selectedRows 22 : '+JSON.stringify(selectedRows));
        for (let index = 0; index < selectedRows.length; index++) {
            this.rowsTableData.push(selectedRows[index].Id);
            selectedRowsArray = [...selectedRowsArray, selectedRows[index].Id];
        }
        console.log('handleRowAction >>>> selectedRowsArray '+JSON.stringify(selectedRowsArray));
        this.selectedDatatableRows = selectedRowsArray;
        this.finalInstallmentCollectionIds = [];
        this.finalInstallmentCollectionAmtMap = {};
        this.hasRowError = false;
        console.log('handleRowAction >>>> totalPages '+JSON.stringify(this.totalPages));
        for (var i = 0; i <= this.totalPages; i++) {
            if (this.holdingSelectedRowsObj[i] != null) {
                
                for (let j = 0; j < this.holdingSelectedRowsObj[i].length; j++) {
                    this.finalInstallmentCollectionIds.push(this.holdingSelectedRowsObj[i][j]);
                }
            }
        }
        console.log('handleRowAction >>>> holdingSelectedRowsObj '+JSON.stringify(this.holdingSelectedRowsObj));
        this.finalInstallmentCollectionCount = this.finalInstallmentCollectionIds.length;
        for (var i = 0; i <= this.totalPages; i++) {
            if (this.holdingSelectedRowsObj[i] != null) {
                for (let j = 0; j < this.holdingSelectedRowsObj[i].length; j++) {
                    if (this.errors == undefined || JSON.stringify(this.errors) == '{}') {
                        this.hasRowError = false;
                    } else if ((this.errors != undefined || JSON.stringify(this.errors) != '{}') 
                        && (this.errors.rows[this.holdingSelectedRowsObj[i][j]] == undefined 
                            || JSON.stringify(this.errors.rows[this.holdingSelectedRowsObj[i][j]]) == '{}')) {
                        this.hasRowError = false;
                    } else {
                        this.hasRowError = true;
                        break;
                    }
                }
                if (this.hasRowError) {
                    break;
                }
            }
        }

        if (this.finalInstallmentCollectionCount > 0 && !this.hasRowError) {
            this.disablesendForDD = false;
        } else {
            this.disablesendForDD = true;
        }
    }
    hideModalBox(event) {
        this.isInitiateCollections = false;
    }
    sendForCollection(event) {
        this.isLoadingModal = true;
        console.log('>>>> sendForCollection >> this.finalInstallmentCollectionAmtMap >>  '+this.finalInstallmentCollectionIds);
        this.isfinalInstallmentwarning = true;

        createDirectDebitTransaction({
            soInstallmentsId: JSON.stringify(this.finalInstallmentCollectionIds)
            })
            .then(result => {
                if (result == 'Success') {
                    this.isLoadingModal = false;
                    this.isInitiateCollections = false;
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Success',
                            message: 'Sent for Collection!',
                            variant: 'success'
                        })
                    );

                    this.collectionSent = true;
                    this.handleSearchAll();
                } else {
                    this.isInitiateCollections = false;
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Error',
                            message: result,
                            variant: 'error'
                        })
                    );
                    this.handleSearchAll();
                }
            }).catch(error => {
                this.isInitiateCollections = false;
                this.isLoadingModal = false;
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: error.message,
                        variant: 'error'
                    })
                );
                this.handleSearchAll();
            });
    }
    sendForDDCollections(event) {
        this.finalInstallmentCollectionIds = [];
        this.finalInstallmentCollectionAmtMap = {};
        var allSelectedValues = [];
        this.selectedSoInstallmentMap = new Map();
        this.hasSRforSelectedInstallmentLine = false;
        var hasMultipleInstallmentLinesForSO = false;

        console.log('>>>> sendForDDCollections >> holdingSelectedRowsObj >> '+JSON.stringify(this.holdingSelectedRowsObj));
        console.log('>>>> sendForDDCollections >> totalPages >> '+JSON.stringify(this.totalPages));
        for (var i = 0; i <= this.totalPages; i++) {
            if (this.holdingSelectedRowsObj[i] != null) {
                for (let j = 0; j < this.holdingSelectedRowsObj[i].length; j++) {
                        this.finalInstallmentCollectionIds.push(this.holdingSelectedRowsObj[i][j]);
                }
            }
        }

        console.log('>>>> sendForDDCollections >> finalInstallmentCollectionIds >> '+JSON.stringify(this.finalInstallmentCollectionIds));
        console.log('>>>> sendForDDCollections >> this.dataMap >> '+JSON.stringify(this.dataMap));
        for (let i = 0; i < this.finalInstallmentCollectionIds.length; i++) {
            let selectedInstallmentLines = [];
            selectedInstallmentLines = this.selectedSoInstallmentMap[this.dataMap[this.finalInstallmentCollectionIds[i]].SalesOrder__c] != null 
                                       ?this.selectedSoInstallmentMap[this.dataMap[this.finalInstallmentCollectionIds[i]].SalesOrder__c] 
                                       : [];
            selectedInstallmentLines.push(this.dataMap[this.finalInstallmentCollectionIds[i]])
            this.selectedSoInstallmentMap[this.dataMap[this.finalInstallmentCollectionIds[i]].soInstallment.SalesOrder__c] = selectedInstallmentLines;

            if (this.selectedSoInstallmentMap[this.dataMap[this.finalInstallmentCollectionIds[i]].soInstallment.SalesOrder__c].length > 1) {
                hasMultipleInstallmentLinesForSO = true;
            }
        }
        console.log('>>>> sendForDDCollections >> hasMultipleInstallmentLinesForSO >> '+hasMultipleInstallmentLinesForSO);
        console.log('>>>> sendForDDCollections >> selectedSoInstallmentMap >> '+JSON.stringify(this.selectedSoInstallmentMap));
        console.log('>>>> sendForDDCollections >> finalInstallmentCollectionIds >> '+JSON.stringify(this.finalInstallmentCollectionIds));
        this.finalInstallmentCollectionCount = this.finalInstallmentCollectionIds.length;
        if (hasMultipleInstallmentLinesForSO) {
            const evt = new ShowToastEvent({
                title: 'Installment Lines',
                message: 'You have Selected multiple Installments for same Sales Order, Kindly make sure only one intsallment is selected for one Sales Order',
                variant: 'error',
            });
            this.dispatchEvent(evt);
        } else if (this.hasSRforSelectedInstallmentLine) {
            const evt = new ShowToastEvent({
                title: 'Installment Lines',
                message: 'The Selected Installment Lines are having active SR' + '\'s. Kindly Deleselect such Installment Lines',
                variant: 'error',
            });
            this.dispatchEvent(evt);
        } else {
            if (this.finalInstallmentCollectionCount >= CollectionLimit) {
                const evt = new ShowToastEvent({
                    title: 'Installment Lines',
                    message: 'Maximum ' + CollectionLimit + ' Instalment Lines can be sent for collections. Kindly revist your selection',
                    variant: 'error',
                });
                this.dispatchEvent(evt);
            } else if (this.finalInstallmentCollectionCount < CollectionLimit && this.finalInstallmentCollectionCount > 0) {
                this.isInitiateCollections = true;
                this.isfinalInstallmentwarning = false;
                this.popupMessage = 'You have selected ' + this.finalInstallmentCollectionCount + ' installments for collection. Are you sure you want to proceed?';
            } else if (this.finalInstallmentCollectionCount == 0) {
                this.popupMessage = 'You have selected ' + this.finalInstallmentCollectionCount + ' installments for collection.'
                this.isfinalInstallmentwarning = true;
            }
        }

        console.log('this.finalInstallmentCollectionIds:::' + this.finalInstallmentCollectionIds);
        console.log('final Map:::' + this.finalInstallmentCollectionAmtMap);
        console.log('holdingSelectedRowsObj Map:::' + this.holdingSelectedRowsObj);
        console.log('draftValueMap Map:::' + this.draftValueMap);
        console.log('allSelectedValues::' + allSelectedValues);

    }

    handleSortdata(event) {
        console.log('handleSortdata >>>> event.detail.fieldName >> '+event.detail.fieldName);
        console.log('handleSortdata >>>> event.detail.sortDirection >> '+event.detail.sortDirection);
        this.sortBy = event.detail.fieldName;
        this.sortDirection = event.detail.sortDirection;
        this.sortData(event.detail.fieldName, event.detail.sortDirection);
    }
    sortData(fieldname, direction) {
        let parseData = JSON.parse(JSON.stringify(this.recordsToDisplay));
        let keyValue = (a) => {
            return a[fieldname];
        };

        let isReverse = direction === 'asc' ? 1 : -1;

        parseData.sort((x, y) => {
            x = keyValue(x) ? keyValue(x) : ''; 
            y = keyValue(y) ? keyValue(y) : '';
            return isReverse * ((x > y) - (y > x));
        });

        this.recordsToDisplay = parseData;

    }
    
    handlecellchange(event) {
        console.log('handle Cell Change');
        var draftValues = event.detail.draftValues;
        var rowErrorMessages = [];
        var rowErrorFieldName = [];
        var rowError = {};
        let draftSelectedIds = this.selectedDatatableRows;

        rowErrorMessages.push('Enter a valid number, Entered value cannot be greater than Installment Amount and Collection Amount must be greate than 0.')
        rowErrorFieldName.push('CollectionAmount');
        rowError[draftValues[0].Id] = {
            messages: rowErrorMessages,
            fieldNames: rowErrorFieldName,
            title: 'We found error'

        };
        console.log('draftValues::' + draftValues);

        if (draftValues.length > 0) {
            for (let i = 0; i < draftValues.length; i++) {
                this.draftValueMap[draftValues[i].Id] = draftValues[i];
                this.draftValueMapIds.push(draftValues[i].Id);
                if (draftValues[i].CollectionAmount != 0 && draftValues[i].CollectionAmount != null) {
                    if (!draftSelectedIds.includes(draftValues[i].Id)) {
                        draftSelectedIds.push(draftValues[0].Id);
                    }
                }
            }
            this.selectedDatatableRows = [...draftSelectedIds];
            this.holdingSelectedRowsObj[this.pageNumber] = this.selectedDatatableRows;
        }

        if (this.draftValueMapIds != null) {
            for (let i = 0; i < this.draftValueMapIds.length; i++) {
                console.log(this.draftValueMap[this.draftValueMapIds[i]]);
                let installmentAmount = this.dataMap[this.draftValueMapIds[i]].AmountReceived__c != null || this.dataMap[this.draftValueMapIds[i]].AmountReceived__c != undefined ? (this.dataMap[this.draftValueMapIds[i]].InstallmentAmount__c - this.dataMap[this.draftValueMapIds[i]].AmountReceived__c) : this.dataMap[this.draftValueMapIds[i]].InstallmentAmount__c;
                if (this.draftValueMap[this.draftValueMapIds[i]].CollectionAmount > installmentAmount) {
                    this.errorIds.push(this.draftValueMapIds[i]);
                    rowError[this.draftValueMapIds[i]] = {
                        messages: rowErrorMessages,
                        fieldNames: rowErrorFieldName,
                        title: 'We found error'
                    };
                } else {
                    rowError[this.draftValueMapIds[i]] = {};
                }
            }
        }
        if (rowError != null) {
            this.errors = {
                rows: rowError
            }
        }
        this.finalInstallmentCollectionIds = [];
        this.finalInstallmentCollectionAmtMap = {};
        this.hasRowError = false;
        for (var i = 0; i <= this.totalPages; i++) {
            if (this.holdingSelectedRowsObj[i] != null) {
                for (let j = 0; j < this.holdingSelectedRowsObj[i].length; j++) {
                    if (this.errors == undefined || JSON.stringify(this.errors) == '{}') {
                        this.hasRowError = false;
                    } else if ((this.errors != undefined || JSON.stringify(this.errors) != '{}') && (this.errors.rows[this.holdingSelectedRowsObj[i][j]] == undefined || JSON.stringify(this.errors.rows[this.holdingSelectedRowsObj[i][j]]) == '{}')) {
                        this.hasRowError = false;
                    } else {
                        this.hasRowError = true;
                        break;
                    }

                }
                if (this.hasRowError) {
                    break;
                }

            }
        }

        for (var i = 0; i <= this.totalPages; i++) {
            if (this.holdingSelectedRowsObj[i] != null) {
                console.log('coming inside');
                for (let j = 0; j < this.holdingSelectedRowsObj[i].length; j++) {
                    console.log('j::' + j);
                    if (this.draftValueMap[this.holdingSelectedRowsObj[i][j]] != null) {
                        this.finalInstallmentCollectionAmtMap[this.holdingSelectedRowsObj[i][j]] = parseFloat(this.draftValueMap[this.holdingSelectedRowsObj[i][j]].CollectionAmount);
                        this.finalInstallmentCollectionIds.push(this.holdingSelectedRowsObj[i][j]);
                    } else {
                        this.finalInstallmentCollectionAmtMap[this.holdingSelectedRowsObj[i][j]] = (this.dataMap[this.holdingSelectedRowsObj[i][j]].AmountReceived__c != null || this.dataMap[this.holdingSelectedRowsObj[i][j]].AmountReceived__c != undefined) ? (this.dataMap[this.holdingSelectedRowsObj[i][j]].InstallmentAmount__c - this.dataMap[this.holdingSelectedRowsObj[i][j]].AmountReceived__c) : this.dataMap[this.holdingSelectedRowsObj[i][j]].InstallmentAmount__c;
                        this.finalInstallmentCollectionIds.push(this.holdingSelectedRowsObj[i][j]);
                    }
                }
            }
        }
        this.finalInstallmentCollectionCount = this.finalInstallmentCollectionIds.length;

        if (this.finalInstallmentCollectionCount > 0 && !this.hasRowError) {
            this.disablesendForDD = false;
        } else {
            this.disablesendForDD = true;
        }
        console.log('length::' + this.holdingSelectedRowsObj[this.pageNumber].length);

        console.log('this.recordsToDisplay::' + this.recordsToDisplay);
        console.log('this.selectedDatatableRows:::' + this.selectedDatatableRows);
    }
    async refresh() {
        await refreshApex(this.recordsToDisplay);
    }

}