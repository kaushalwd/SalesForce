import { LightningElement,track,wire } from 'lwc';
import getAllProject from '@salesforce/apex/PaymentReminderController.getAllProject';
import getPhasesAndReminderForProject from '@salesforce/apex/PaymentReminderController.getPhasesAndReminderForProject';
import getInstallments from '@salesforce/apex/PaymentReminderController.getInstallments';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getInstallmentsWithType from '@salesforce/apex/PaymentReminderController.getRemindersRecords';  

export default class Paymentreminder extends LightningElement {
    progress = 0;
    isProgressing = false;
    finished = 0;
    reminderTotal = 0;
    pageSize = 200;

    @track completeTableData = []; 
    projectNamePickListValues = [];
    phaseFieldValues = [];
    remindersPickListValues = [];
    projectNameField = '';
    phaseNameVal = '';
    selectedReminderType = '';
    selectedDate;
    locationCodeField;

    allSelectedRows = new Set();
    pageNumber = 0;
    pageData = [];
    selectedRows = [];

    @track completeTableDataReminder = [];
    phaseFieldValuesReminder = [];
    remindersPickListValuesReminder = [];
    projectNameFieldLog = '';
    phaseNameValLog = '';
    selectedReminderTypeLog = '';
    selectedDateLog;
    locationCodeFieldLog;

    allSelectedRowsReminder = new Set();
    pageNumberReminder = 0;
    pageDataReminder = [];
    selectedRowsReminder = [];

    phaseFieldValuesQueu = [];
    remindersPickListValuesQueu = [];
    projectNameFieldQueu = '';
    phaseNameValQueu = '';
    selectedReminderTypeQueu = '';
    selectedDateQueu;
    locationCodeFieldQueu;

    @track isLoadingtable = false;
    isLoading = false;
    dataNotAvailable = false;
    @track withouttype = false;
    @track isUnitOptions = false;
    
    columns = [
        // {label: 'Phase', fieldName: 'Phase__c', type: 'text'},
        {label: 'Account Name', fieldName: 'AccountLink',type: 'url',typeAttributes: { label: {fieldName: 'AccountName'}, target: '_blank' }},
        {label: 'Name', fieldName: 'InstallmentLink', type: 'url',typeAttributes: { label: {fieldName: 'InstallmentName'}, target: '_blank' }},
        {label: 'Unit', fieldName: 'UnitLink',type: 'url',typeAttributes: { label: {fieldName: 'UnitName'}, target: '_blank' }},
        {label: 'Reminder Type', fieldName: 'ReminderType', type: 'text'},
        {label: 'Due date', fieldName: 'DueDate__c', type: 'date'}
    ];    

    columnsInstallment = [
        {label: 'Name', fieldName: 'InstallmentLink', type: 'url',typeAttributes: { label: {fieldName: 'InstallmentName'}, target: '_blank' }},
        {label: 'Account Name', fieldName: 'AccountLink',type: 'url',typeAttributes: { label: {fieldName: 'AccountName'}, target: '_blank' }},
        {label: 'Phase', fieldName: 'PhaseName', type: 'text'},
        {label: 'Unit', fieldName: 'UnitLink',type: 'url',typeAttributes: { label: {fieldName: 'UnitName'}, target: '_blank' }},
        {label: 'Pending Amount', fieldName: 'RemainingAmount', type: 'number'},
        {label: 'Due date', fieldName: 'ReminderDueDate__c', type: 'date'},
        {label: 'Total Amount', fieldName: 'InstallmentAmount__c', type: 'number'},
        {label: 'Reminder Type', fieldName: 'ReminderType', type: 'text'}
    ];
           
    @track installmentColumns = this.columnsInstallment;
    columnReminder = this.columns;
    columnReminderQueue = this.columns;  
   
    columnReminder = [...this.columnReminder,
        {label: 'Sent Date', fieldName: 'ReminderSentDate', type: 'date'}
    ];

    activeTab='1';  
    columnReminderLog = this.columnReminder;  
    columnReminderLog = [...this.columnReminderLog,
        {label: 'Email Log', fieldName: 'EmailLogLink', type: 'url',typeAttributes: { label: 'View Email Log', target: '_blank'}} //v1.0
    ];

    connectedCallback(){
        this.isLoading = true;
        getAllProject()
            .then(result => {
                this.isLoading = false;
                this.projectNamePickListValues = [...this.projectNamePickListValues ,{label: 'None', value: ''}];
                if (result) {
                    let projectList = JSON.parse(result);
                    for(let i = 0; i < projectList.length; i++){
                        this.projectNamePickListValues = [...this.projectNamePickListValues ,{label: projectList[i].Name, value: projectList[i].Id}];
                    }
                }
            })
            .catch(error => {
                this.isLoading = false;
                this.error = error;
                this.contacts = undefined;
            });
    }
    @track selectedProjectLabel;
    handleProjectChange(event) {

        this.phaseFieldValues = [];
        this.remindersPickListValues = [];
        this.handleReset();
        this[event.target.name] = event.detail.value;
        this.selectedProjectLabel = event.target.options.find(opt => opt.value === event.detail.value).label;
        this.showActualCompletionDate = false;

        getPhasesAndReminderForProject({projectId : this.projectNameField})
        .then(result => {
            if (result[0]) {
                this.phaseFieldValues = [...this.phaseFieldValues ,{label: 'None', value: ''}];
                let response = JSON.parse(result[0]);
                for(let i = 0; i < response.length; i++){
                    this.phaseFieldValues = [...this.phaseFieldValues ,{label: response[i].Name, value: response[i].Id}];
                }
            }
            if(result[1]){
                this.remindersPickListValues = [...this.remindersPickListValues ,{label: 'All', value: ''}];
                let metadataRecordList = JSON.parse(result[1]);
                if(metadataRecordList){
                    for(let i = 0; i < metadataRecordList.length; i++){
                        this.remindersPickListValues = [...this.remindersPickListValues ,{label: metadataRecordList[i], value: metadataRecordList[i]}];
                    }
                }
            }
        })
        .catch(error => {
            this.error = error;
            this.contacts = undefined;
        });
    }
    handleSearch(event) { 
        this.isLoading = true;
        this.completeTableData = [];
        if(this.projectNameField ){
            this.installmentColumns = this.columnsInstallment;
            getInstallments({
                    selectedProject : this.projectNameField,
                    selectedPhaseId : this.phaseNameVal,
                    selectedReminderType : this.selectedReminderType,
                    selectedUnitName : this.locationCodeField              
            }).then(result => {
                    if (result) {
                        this.isLoading = false;
                        let tableData = [];
                        let response = JSON.parse(result);
                       
                        response.forEach(record => {
                            let preparedRec = {};
                            preparedRec.Id = record.InstallmentId     
                            preparedRec.ReminderType = record.ReminderType;                           
                            preparedRec.InstallmentId = record.InstallmentId;
                            preparedRec.AccountName = record.AccountName;
                            if (record.AccountId != null && record.AccountId != '' && record.AccountId != undefined) {
                                preparedRec.AccountLink= '/lightning/r/Account/'+record.AccountId + '/view';
                            }
                            preparedRec.Phase__c = record.PhaseId;
                            preparedRec.PhaseName= record.PhaseName;
                            preparedRec.InstallmentLink= '/lightning/r/Installment__c/'+record.InstallmentId + '/view';
                            preparedRec.InstallmentAmount__c = record.FinalAmount;
                            preparedRec.RemainingAmount = record.RemainingAmount;
                            preparedRec.ReminderDueDate__c = record.ReminderDueDate;
                            preparedRec.InstallmentName = record.InstallmentName;
                            preparedRec.UnitName = record.UnitName;
                            if (record.UnitId != null && record.UnitId != '' && record.UnitId != undefined) {
                                preparedRec.UnitLink= '/lightning/r/Unit__c/'+record.UnitId + '/view';
                            }
                            preparedRec.ReminderType = record.ReminderType;
                            tableData.push(preparedRec);
                        });
                        this.completeTableData = tableData;
                        this.dataNotAvailable = false;
                        
                    } else{
                        this.dataNotAvailable = true;
                    }
                })
                .catch(error => {
                    this.error = error;
                    this.contacts = undefined;
                    this.showToast('Search','Error Please try again','error');
                });
        }else{
            this.isLoading = false;
            this.showToast('Search','Please select project and phase filter first','error');
        }
    }
   
    showToast(titleVar,messageVar,variantVar){
        const evt = new ShowToastEvent({
            title: titleVar,
            message: messageVar,
            variant: variantVar
        });
        this.dispatchEvent(evt);
    }

    handleReset(event){
        this.projectNameField = '';
        this.phaseNameVal = '';
        this.selectedReminderType = '';
        this.selectedDate = undefined;
        this.locationCodeField = '';
    }

    handlePhase(event) {
        this.phaseNameVal = event.detail.value;
    }

    handleUnitName(event) {
        this.locationCodeField = event.detail.value;
    }
    handleKeyUp(event) {
       // alert('2222'+this.locationCodeField);
    }

    handleActive(event){ 
        this.activeTab = event.target.value;
    } 

    handleResetReminder(event){
        this.projectNameFieldLog = '';
        this.phaseNameValLog = '';
        this.selectedReminderTypeLog = '';
        this.selectedDateLog = undefined;
        this.locationCodeFieldLog = undefined;
    }

    handlePhaseReminder(event) {
        this.phaseNameValLog = event.detail.value;
    }

    handleProjectChangeReminder(event) {
        this.handleResetReminder();
        this.phaseFieldValuesReminder = [];
        this.remindersPickListValuesReminder = [];
        this.projectNameFieldLog = event.detail.value;
        
        getPhasesAndReminderForProject({projectId : this.projectNameFieldLog})
        .then(result => {
            if (result[0]) {
                this.phaseFieldValuesReminder = [...this.phaseFieldValuesReminder ,{label: 'None', value: ''}];
                let response = JSON.parse(result[0]);
                for(let i = 0; i < response.length; i++){
                    this.phaseFieldValuesReminder = [...this.phaseFieldValuesReminder ,{label: response[i].Name, value: response[i].Id}];
                }
            }
            /*if(result[1]){
                this.remindersPickListValuesReminder = [...this.remindersPickListValuesReminder ,{label: 'All', value: ''}];
                let metadataRecord = JSON.parse(result[1]);
                if(metadataRecord){
                    let reminderTypes = (metadataRecord.ReminderTypes__c).split(",");
                    for(let i = 0; i < reminderTypes.length; i++){
                        this.remindersPickListValuesReminder = [...this.remindersPickListValuesReminder ,{label: reminderTypes[i], value: reminderTypes[i]}];
                    }
                }
            }*/
        })
        .catch(error => {
            this.error = error;
            this.contacts = undefined;
        });
    }

     handleSearchReminder(event) {
        this.isLoading=true; 
        if(this.projectNameFieldLog ){
            this.columnReminder = this.columnReminderLog;
            getInstallmentsWithType({
                selectedProject : this.projectNameFieldLog,
                selectedPhaseId : this.phaseNameValLog
            })
            .then(result => {
                if (result) {
                    this.isLoading=false; 
                    let tableData = [];
                    let response = JSON.parse(result);
                    response.forEach(record => {
                        let preparedRec = {};
                        preparedRec.Id = record.InstallmentId;
                        preparedRec.InstallmentId = record.InstallmentId;        
                        preparedRec.AccountName = record.AccountName;
                        if (record.AccountId != null && record.AccountId != '' && record.AccountId != undefined) {
                            preparedRec.AccountLink= '/lightning/r/Account/'+record.AccountId + '/view';
                        }
                        preparedRec.InstallmentLink= '/lightning/r/Installment__c/'+record.InstallmentId + '/view';
                        preparedRec.DueDate__c = record.DueDate; 
                        preparedRec.ReminderDueDate__c = record.ReminderDueDate;
                        preparedRec.InstallmentName = record.InstallmentName;
                        preparedRec.UnitName = record.UnitName;
                        if (record.UnitId != null && record.UnitId != '' && record.UnitId != undefined) {
                            preparedRec.UnitLink= '/lightning/r/Unit__c/'+record.UnitId + '/view';
                        }
                        preparedRec.ReminderType = record.ReminderType;
                        if(record.emailMessageId != null){
                            preparedRec.EmailLogLink='/lightning/r/EmailMessage/'+ record.emailMessageId +'/view';                        
                        }
                        preparedRec.ReminderSentDate = record.sentDate; 
                        tableData.push(preparedRec);
                    });

                    this.completeTableDataReminder = tableData;
                    this.dataNotAvailable = false;
                    
                } else{
                    this.dataNotAvailable = true;
                }
            })
            .catch(error => {
                this.error = error;
                this.contacts = undefined;
                this.showToast('Search','Error Please try again','error');
            });
        }
        else{
            this.isLoading = false;
            this.showToast('Search','Please select project filter first','error');
        }
    }
     handleReminderChange(event) {
        this.selectedReminderType = event.detail.value;
    }
}