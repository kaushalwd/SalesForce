/**************************************************************************************************
* Name           : ProgressIndicator.js
* Description    : LWC component to show progress indicator                                
* Created Date   : 14/01/2025
* Created By     : Krishna Chaitanya Ramadugu
* *********************************************************************************************************************
* Version       Author   Date         Comment   
* 1.0           KC       14/01/2025   Initial Draft
* 2.0           Chandu   15/04/2026   Added pre and post unit cancellation execution
**************************************************************************************************/

import { api, LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import SFResources from '@salesforce/resourceUrl/SFResources';
import getStepGroupWrapper from '@salesforce/apex/ServiceActionController.getStepGroupWrapper';
import getTask from '@salesforce/apex/ServiceActionController.getTask';
import updateTask from '@salesforce/apex/ServiceActionController.updateTask';
import updateSR from '@salesforce/apex/ServiceActionController.updateSR';
import updateUnit from '@salesforce/apex/ServiceActionController.updateUnit'
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import doCallout from '@salesforce/apex/ServiceActionController.doCallout';
import doCalloutJo from '@salesforce/apex/ServiceActionController.doCalloutJo';
import doCallout1 from '@salesforce/apex/ServiceActionController.doCalloutStep1';
import doCallout2 from '@salesforce/apex/ServiceActionController.doCalloutStep2';
import propertyTransferNewDesignProcess1 from '@salesforce/apex/ServiceActionController.propertyTransferNewDesignProcess1';
import updatePE from '@salesforce/apex/ServiceActionController.executePaymentExtension';
import ucexecute from '@salesforce/apex/UnitConsolidationController.processConsolidationFinancials';
import planSwap from '@salesforce/apex/paymentPlanSwapHelper.executePaymentPlanSwap';
import executemilestonemethod from '@salesforce/apex/ServiceActionController.executeMilestoneUpdate';
import sendPaymentReceiptToCustomer from '@salesforce/apex/PropertyTransferTitleDeedController.sendPaymentReceiptToCustomer';

import executePreUnitCancellation from '@salesforce/apex/SRCancellationExecutor.execute';
import executePostUnitCancellation from '@salesforce/apex/SRCancellationExecutor.execute';
import executeCancellationProcessMethod from '@salesforce/apex/ServiceActionController.executeCancellationProcess';
import executemethodforallamounts from '@salesforce/apex/ServiceRequestTriggerHelper.executemethodforamounts';

import updateLPC from '@salesforce/apex/LPCWaiverExecution.updateLPCCharge';
import autoProcessBrokerSR from '@salesforce/apex/autoAssignBroker.autoProcessBrokerSR';
import sendInvoiceToCustomer  from '@salesforce/apex/PropertyTransferTitleDeedController.sendInvoiceToCustomer';
import { updateRecord } from 'lightning/uiRecordApi';
import { getRecord } from 'lightning/uiRecordApi';

import property_Transfer_New_Design_Enabled_Flag from '@salesforce/label/c.Property_Transfer_New_Design_Enabled';
import ALLOWED_USERS from '@salesforce/label/c.Milestone_Allowed_Users';
import USER_ID from '@salesforce/user/Id';


const FIELDS = ['ServiceRequest__c.Final_Execution_Complete__c','ServiceRequest__c.RecordTypeName__c']; // field API names



export default class ProgressIndicator extends NavigationMixin(LightningElement) {
    @api recordId;
    @api opportunityId;
    @api taskId;
    srClose=false;
    finalexecutioncomplete=false;
    showExecute = false;
    showPtDeedExecute = false;
    statusValue;
    isSRCommentsChange=false;
    isDaridateChange=false;
isTitleDeeddateChange=false;
showLPCExecute=false;
    showmilestoneupdate=false;
   selectedUnitStatus = '';
selectedDecisiontype = '';
isDecissionType = false;
isUnitDecissionType = false;
selectedLegalStatus = '';

isCancelationDate=false;
RejectedReason=false;

    hpdatetimebool=false;
    hpRecordtype=false;
    SLA;
    stepId;
    srStatus;
    totalTime;
    hourglass;
    groupWidth;
    lstGroupWrap;
    recordTypeName;
    isLoading = true;
    hasRendered = false;
    showDariFields = false;
    showPaymentFields = false;
    showPenalityFields = false;
    showSendEmail=false;

    showSendEmail2=false;
    showSendEmailForMortgage=false;
    showuploaddoc = false;
    JoAddition = false;
    JoDeletion = false;
    ManageJo = false;
    showExecuteUC = false;
    hpdateval;// = new Date().toISOString().slice(0, 16);
    showextendNocFields =false;
showCancellationDate=false;
    showExecuteUtUpgde=false;
    showPSExecute=false;
    showExecuteUntSwp=false;
showPlotHandoverExecute = false;
showUnitHandoverExecute = false;
showUnitCancellationExecute = false;
showPlotHandoverTitleDeed = false;
showpreUnitCancellationExecute = false;
showpostUnitCancellationExecute = false;
recordtypenameofSR ='';
showExecuteMR=false;
showExecuteMD=false;
    showApprovedextendNocFields =false;
    isNOCExtensionRejected = false;
mrAppStatus=false;
    

    @track selectedStatus = '';
    @track accordionSection = "";
    @track timeoutCounter = 10;
    @track interval = 1000;
    @track dueDays;
    @track showEventForm = false;
    @track showSPAGeneration = false;
    @track disableExtendNoc = false;
    @track disableApprovedNoc = true;
    @track minDate;
    today = new Date().toISOString().split('T')[0];
    taskRecord = {};
    executioncomplete = false;
    isModalOpen = false;
    error;
    DariDate;
ApplicationDate;
ApplicationNo;
outStandingChargeAmount;
isOutStandingCharge =false;
    isextndNOCDateChange=false;
    isextensionAppstatus=false;
    isapprovedExtndNOCDateChange = false;
    extndNOCDate;
conditionalCancelDate;
    approvedExtndNOCDate;
    DariNumber;
TitledeedNumber;
TitledeedDate;
    srComments;
    AdmAmount;
    PenalityAmount;
    ShowJoExecute =false;
    closednotvalid=false;
    disableextndNOCDate = false;
    showPEExecute=false;
    isExtendNOCDateDisabled = false;
    isUnitStatus = false;
    isUnitChanged = false;
isLegalOptionChanged=false;
    srClosure;
srRejectionReason;
paymentDone = false;
showLPCExecute=false;
property_Transfer_New_Design_Enabled;
    @track eventRecord = {
        Subject: '',
        StartDateTime: '',
        EndDateTime: '',
        WhatId: '',
        Description: ''

    };
    /* Broker Registration SR Changes  */
    isBrokerRegistrationSR = false;
    brComments;
    isBrCommentsIsRequired = false;

    unitStatusOptions = [
        { label: 'Available', value: 'Available' },
        { label: 'Sold', value: 'Sold' },
        { label: 'CCMD', value: 'CCMD' },
        { label: 'Reserved', value: 'Reserved' },
        { label: 'UnReleased', value: 'UnReleased' },
        { label: 'Blocked for Upgrade', value: 'Blocked for Upgrade' }
    ];

    kycOptions = [
        { label: 'Approved', value: 'Approved' },
        { label: 'Rejected', value: 'Rejected' },
        { label: 'Resubmit KYC', value: 'Resubmit KYC' }
    ];
    extensionOptions = [
        { label: 'Approved', value: 'Approved' },
        { label: 'Approve with new dates', value: 'Approve with new dates' },
        { label: 'Rejected', value: 'Rejected' }
    ];
reqoptions = [
        { label: 'Req from Owner', value: 'Req from Owner' },
        { label: 'Third Party', value: 'Third Party' }
    ];
   cancelationReasonOptions =  [{ label: 'Out of Scope', value: 'Out of Scope' },
   { label: 'Others', value: 'Others' }];

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredRecord({ error, data }) {
        if (data) {
            this.finalexecutioncomplete = data.fields.Final_Execution_Complete__c.value; 
            if(this.finalexecutioncomplete){
                this.executioncomplete=true;
            }
            if(data.recordTypeInfo.name == 'Broker Registration'){
                this.isBrokerRegistrationSR = true;
            }
        } else if (error) {
            console.error('Error retrieving record:', error);
        }
    }

    
        handleAmountOustandingChange(event) {
        this.outStandingChargeAmount = event.target.value;
        this.isOutStandingCharge=true;
    }
    get getreqTitleDeedTask() {
    if(this.taskRecord.Subject === 'Upload Authorization Letter - Required for Third-Party'){
        return true;
    }else{
        return false;
    }
}
    showDueDays() {
        let counter = 0;
        const intId = setInterval(() => {
            this.dueDays = counter;
            counter++;
            if (counter === this.timeoutCounter) {
                this.dueDays = 'Time Out';
                clearInterval(intId);
            }
        }, this.interval);
    }

    get timelineWidth() {
        return `width: ${this.groupWidth}`;
    }

    get getKYCTask() {
        if(this.taskRecord.Subject === 'Collect KYC Documents' || this.taskRecord.Subject === 'Resubmit KYC Documents'){
            return true;
        }else{
            return false;
        }
    }

    get NocOptions() {
        const options = [
            { label: 'Cancel NOC', value: 'Cancel NOC' },
            { label: 'Title Deed Issued', value: 'Title Deed Issued' }
        ];
    
        // Add additional option if subject includes "30 Days Extended NOC"
        if (this.taskRecord?.Subject == 'Follow-up on NOC Status After 15 Days') {
            options.push({ label: 'In Progress', value: 'In Progress' });
        }
        if (this.taskRecord?.Subject == 'Follow-up on NOC Status After 30 Days') {
            options.push({ label: 'Extend NOC', value: 'Extend NOC'});
        }
    
        return options;
    }
    get getNOCTask() {
        if(this.taskRecord.Subject === 'Follow-up on NOC Status After 15 Days' || this.taskRecord.Subject === 'Follow-up on NOC Status After 30 Days'){
            return true;
        }else{
            return false;
        }
    }
    get getextendedNOCTask() {
        if(this.taskRecord.Subject === 'Approval needed from CM Manager'){
                        return true;
        }else{
            return false;
        }
    }

    get getUnitStatus() {
        if(this.taskRecord.Subject === 'Get Customer Confirmation for Unit Upgrade Payment' ||  this.taskRecord.Subject === 'Get Customer Confirmation for Unit Swap Payment'){
            this.unitStatusOptions = [ { label: 'Blocked for Upgrade', value: 'Blocked for Upgrade' } ];
            this.selectedUnitStatus = 'Blocked for Upgrade';
            this.isUnitChanged=true;
                        return true;
        }else{
            return false;
        }
    }

    get geCancellationComments() {
        if(this.taskRecord.Subject === 'CM Team Comments for SR Cancellation' || this.taskRecord.Subject === 'SR Cancellation - CM Team Comments'){
            return true;
        }else{
            return false;
        }
    }

    get showExtendNocDateField() {
        return this.showextendNocFields || this.getExtensionStatus;
    }
    get showSrCommentsField() {
        
        if(this.taskRecord.Subject === 'CM Team Comments for SR Closure'){
            return true;
        }else{
            return false;
        }
    }


    get showApprovedExtendNocDateField() {
        return this.showApprovedextendNocFields;
    }

    get getExtensionStatus() {
        if(this.taskRecord.Subject === 'Approval needed from CM Manager'){
            return true;
        }else{
            return false;
        }
    }
    get showApprovalSection(){
        if(this.taskRecord.Subject === 'Assignment of Broker Manager' || 
            this.taskRecord.Subject === 'Validation by Compliance Team' ||
            this.taskRecord.Subject === 'Validation by Broker Sales Admin' ||
            this.taskRecord.Subject === 'Require more information'
        ){
            return true;
        }else{
            return false;
        }
    }


    connectedCallback() {
        this.property_Transfer_New_Design_Enabled = property_Transfer_New_Design_Enabled_Flag.toLowerCase() === 'true';
        this.hourglass = SFResources;
    const tomorrow = new Date();
tomorrow.setDate(tomorrow.getDate() + 1);
this.minDate = tomorrow.toLocaleDateString('en-CA'); // YYYY-MM-DD
        this.showDueDays();
    }

    async renderedCallback() {
        if (!this.hasRendered) {
            await this.fetchStepGroupData();
            this.hasRendered = true;
        }
    }

    async fetchStepGroupData() {
        try {
            const result = await getStepGroupWrapper({ serviceRequestId: this.recordId });
            this.lstGroupWrap = result.lstLtngGroupWrapper;
        this.recordtypenameofSR = result.recordTypeName ;
            this.taskId = result.lstLtngGroupWrapper?.[0]?.lstChilds?.[0]?.TaskId;
            this.groupWidth = `${100 / result.lstLtngGroupWrapper.length}%`;
            this.totalTime = result.totalTime;
            this.srStatus = result.srStatus;
            this.Jotype= result.srJoType;
            this.DariDate = result.daridate;
            this.DariNumber = result.darinumber;
        this.TitledeedNumber = result.darinumber;
        this.TitledeedDate = result.darinumber;
            this.srComments= result.srcomments;
            this.AdmAmount = result.admamount;
            this.extndNOCDate=result.extensionDate;
            this.approvedExtndNOCDate = result.approvedExtensionDate;
            this.PenalityAmount=result.penalityamount;
            this.recordTypeName = result.recordTypeName;
            this.outStandingChargeAmount = result.outstandingCharge;
            if(result.penalitycheck){
                this.showPenalityFields=result.penalitycheck;
            }
            this.SLA = result.lstLtngGroupWrapper?.[0]?.SLA;

            if (this.taskId) {
                await this.fetchTaskData();
            }
        } catch (error) {
            console.error('Error fetching Step Group Data:', error);
        }
    }

    async fetchTaskData() {
        try {
            this.isLoading = true;
            this.taskRecord = await getTask({ taskId: this.taskId });
        } catch (error) {
            this.error = error;
            this.showToast('Error', error.body?.message || 'Failed to load Task data', 'error');
        } finally {
            this.isLoading = false;
        }
    }
    handleUnitChange(event) {
        this.selectedUnitStatus = event.detail.value;
        if(this.selectedUnitStatus === 'Blocked for Upgrade'){
                this.isUnitChanged=true;
        }
        // You can perform additional logic here
    }
getTodayDate() {
const d = new Date();
return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}
    handleInputChange(event) {
          if (this.isUnitDecissionType === true) {
        
    this.taskRecord = {
        ...this.taskRecord,[event.target.name]: event.target.value ,
        is_Decision_Type__c: true
    };

}else{
        this.taskRecord = { ...this.taskRecord, [event.target.name]: event.target.value };
        this.statusValue= this.taskRecord.Status
        const fieldName = event.target.name;
        const value = event.detail.value;
    
        if (fieldName === 'NOC_Doc_Status__c') {
            this.showextendNocFields = (value === 'Extend NOC');
            this.disableExtendNoc = false;
            this.disableApprovedNoc = true;
        }    
       if (fieldName === 'Extended_NOC_Approval_Status__c') {
        this.extensionStatus = value;

        const isApproved = (value === 'Approved' || value === 'Approve with new dates');
        this.isextensionAppstatus = isApproved;
        this.showApprovedextendNocFields = (value === 'Approve with new dates');
        //this.isNOCExtensionRejected = (value === 'Rejected');
 this.RejectedReason =(value === 'Rejected');
        // Optional: Reset related flags if status is neither approved nor rejected
        if (!isApproved && value !== 'Rejected') {
            this.showApprovedextendNocFields = false;
            this.isNOCExtensionRejected = false;
        }

    }
    if (this.taskRecord.Subject === 'CM Team Comments for SR Closure') {
        this.isNOCExtensionRejected = true;
        this.showextendNocFields  = false;
    }
    if((this.taskRecord.Subject ===  'Assignment of Broker Manager' 
        || this.taskRecord.Subject ===  'Validation by Compliance Team')
        && (this.taskRecord.Broker_Registration_Status__c == 'Require more Information'
            || this.taskRecord.Broker_Registration_Status__c == 'Rejected')){
        this.isBrCommentsIsRequired = true;
    }else {
        this.isBrCommentsIsRequired = false;
    }
if (this.taskRecord.Subject === 'Dues are completed. Collection team will close the SR' || this.taskRecord.Subject === 'All dues collected. Legal team will close the SR') {
    this.srClose = true;
    this.paymentDone=true;
}
if( this.taskRecord.Subject==='Close SR and open child SR per Legal advice'){
    this.srClose = true; 
}

if( this.taskRecord.Subject==='Completed Registration'){
    this.srClose = true; 
}
    }
}
    handleSrCommentsChange(event){
        this.srClosure = event.target.value;
    } 
     handleSrRejctionReason(event){
    this.srRejectionReason = event.target.value;
    } 
    handleBrCommentsChange(event){
        this.brComments = event.target.value;
    } 
    handleCancelDateInputChange(event){
    this.isCancelationDate=true;
    this.conditionalCancelDate=event.target.value;

    } 
    handleExtendNocInputChange(event){
        //alert('YOU ARE IN handleExtendNocInputChange METHOD');
        this.isextndNOCDateChange=true;
        this.extndNOCDate=event.target.value;
        //this.approvedExtndNOCDate = this.extndNOCDate;      
        //alert('YOU ARE IN handleExtendNocInputChange METHOD ' + this.extndNOCDate);
        //alert('YOU ARE IN handleExtendNocInputChange METHOD ' + this.approvedExtndNOCDate);  
    }
    handleApprovedExtendNocInputChange(event){
        //alert('YOU ARE HERE');
        //this.isapprovedExtndNOCDateChange=true;
        this.approvedExtndNOCDate = event.target.value;
       
    }
    handleDariInputChange(event){
        this.isDaridateChange=true;
            this.DariDate=event.target.value;
    }
    handleExtensionStatus(event){
        this.selectedStatus = event.detail.value;
    }
    handleDariAppNumberChange(event){
            this.DariNumber=event.target.value;
    }

handleTitledeedNumberChange(event){
    this.TitledeedNumber=event.target.value;
}

handleTitledeedDateChange(event){
    this.isTitleDeeddateChange = true;
    this.TitledeedDate=event.target.value;
}
    handleCommentsInputChange(event){
    this.srComments = event.target.value;
    this.isSRCommentsChange=true;
    }
    handleAdmFee(event){
        this.AdmAmount=event.target.value;
    }
    handlePenlaityAmount(event){
        this.PenalityAmount=event.target.value;
    }

    
async handleSendEmailForTitleDeed(event) {
    // disable button while processing

    const today = new Date().toLocaleDateString('en-CA');

    try {
        const result = await sendPaymentReceiptToCustomer({ 
            serviceRequestId: this.recordId
        });


        if (result === 'EMAIL_SENT') {
            this.closednotvalid = false;
            this.executioncomplete = true; 
            this.showToast(
                'Success',
                'Payment Receipt email sent successfully.',
                'success'
            );

        } else if (result === 'ERROR_NOC_PAYMENT_RECEIPT_NOT_UPLOADED') {
            this.closednotvalid = true;
            this.executioncomplete = false; 
            this.showToast(
                'Missing Document',
                'Please upload NOC Payment Receipt before sending the email.',
                'error'
            );

        } else if (result === 'ERROR_OUTSTANDING_PAYMENT_RECEIPT_NOT_UPLOADED') {
            this.closednotvalid = true;
            this.executioncomplete = false; 
            this.showToast(
                'Missing Document',
                'Outstanding Payment Receipt must be uploaded when Outstanding Charge is greater than zero.',
                'error'
            );

        } else if (result === 'NO_FILES_FOUND') {
            this.closednotvalid = true;
            this.executioncomplete = false; 
            this.showToast(
                'Missing File',
                'No file is attached to the Payment Receipt document.',
                'error'
            );

        } else if (result === 'NO_CONTENTVERSION_FOUND') {
            this.closednotvalid = true;
            this.executioncomplete = false; 
            this.showToast(
                'Missing File Version',
                'Latest file version not found for the Payment Receipt.',
                'error'
            );

        } else if (result === 'NO_ACTIVE_CONTACT_FOUND') {
            this.showToast(
                'Warning',
                'No active contact found to send the email.',
                'warning'
            );

        } else if (result === 'PERSON_ACCOUNT_HAS_NO_CONTACT') {
            this.showToast(
                'Warning',
                'Person Account does not have a contact.',
                'warning'
            );

        } else if (result === 'INVALID_SERVICE_REQUEST_ID') {
            this.showToast(
                'Error',
                'Invalid Service Request ID.',
                'error'
            );

        } else if (result === 'EMAIL_FAILED') {
            this.showToast(
                'Error',
                'Email sending failed. Please try again.',
                'error'
            );

        } else if (result === 'EMAIL_EXCEPTION') {
            this.showToast(
                'Error',
                'Unexpected error occurred while sending email.',
                'error'
            );

        } else {
            this.closednotvalid = false;
            this.executioncomplete = true; 
            this.showToast('Error', `Unexpected result: ${result}`, 'error');
        }

    } catch (error) {
        const errorMessage = error?.body?.message || 'Unexpected error occurred';
        this.showToast('Error', errorMessage, 'error');
        console.error('Send Email Error:', error);

    } finally {
        this.executioncomplete = true;   //re-enable button
    }

}



async handleSendEmailForNOCInv(event) {
     // disable button while processing


    const today = new Date().toLocaleDateString('en-CA');

    try {
        const result = await sendInvoiceToCustomer({ 
            serviceRequestId: this.recordId
        });     

        if (result === 'EMAIL_SENT') {
             this.closednotvalid = false;
    this.executioncomplete = true; 
            this.showToast('Success', 'Email sent successfully.', 'success');

        } else if (result === 'ERROR_NOC_INVOICE_NOT_UPLOADED') {
            this.closednotvalid = true;
    this.executioncomplete = false; 
            this.showToast(
                'Missing Document',
                'Please upload NOC Fee Invoice before sending the email.',
                'error'
            );

        } else if (result === 'ERROR_OUTSTANDING_INVOICE_NOT_UPLOADED') {
            this.closednotvalid = true;
    this.executioncomplete = false; 
            this.showToast(
                'Missing Document',
                'Outstanding Invoice must be uploaded when Outstanding Charge is greater than zero.',
                'error'
            );

        } else if (result === 'AMOUNT_ALREADY_PAID') {
            this.showToast('Info', 'Amount is already paid. Email was not sent.', 'info');

        } else if (result === 'NO_ELIGIBLE_CONTACT_FOUND') {
            this.showToast('Warning', 'No eligible contact found to send the email.', 'warning');

        } else if (result === 'ACCOUNT_NOT_FOUND') {
            this.showToast('Error', 'Associated account not found.', 'error');

        } else if (result === 'INVALID_SERVICE_REQUEST_ID') {
            this.showToast('Error', 'Invalid Service Request ID.', 'error');

        } else {
             this.closednotvalid = false;
    this.executioncomplete = true; 
            this.showToast('Error', `Unexpected result: ${result}`, 'error');
        }

    } catch (error) {
        const errorMessage = error?.body?.message || 'Unexpected error occurred';
        this.showToast('Error', errorMessage, 'error');
        console.error('Send Email Error:', error);

    } finally {
        this.executioncomplete = true;   //re-enable button
    }
}


    async handleSave(event) {
        let valid = false;
        this.template.querySelectorAll('lightning-input').forEach(input => {
            if (!input.reportValidity()) {
                valid = true;
            }
        });
       
        if( (this.taskRecord.Subject ==='Assignment of Broker Manager' 
            || this.taskRecord.Subject ==='Validation by Compliance Team'
            || this.taskRecord.Subject ==='Validation by Broker Sales Admin') && !valid){
            this.template.querySelectorAll('lightning-combobox').forEach(input => {
                if (!input.reportValidity()) {
                    valid = true;
                }
            });
        }

        if( (this.taskRecord.Subject ==='Collect KYC Documents' || this.taskRecord.Subject === 'Resubmit KYC Documents' 
            ) && !valid && this.taskRecord.Status === 'Closed'){
            this.template.querySelectorAll('lightning-combobox').forEach(input => {
                if (!input.reportValidity()) {
                    valid = true;
                }
            });
        }

        if((this.taskRecord.Subject === 'Assignment of Broker Manager' 
            || this.taskRecord.Subject ==='Validation by Compliance Team') && 
          !valid  && (this.taskRecord.Broker_Registration_Status__c === 'Require more Information' 
            || this.taskRecord.Broker_Registration_Status__c === 'Rejected')){
             this.template.querySelectorAll('lightning-textarea').forEach(input => {
                if (!input.reportValidity()) {
                    valid = true;
                }
            }); 
        }
        if(!valid){
            if((this.taskRecord.Subject === 'Assignment of Broker Manager' 
                || this.taskRecord.Subject ==='Require More Information' 
                || this.taskRecord.Subject ==='Validation by Compliance Team'
                || this.taskRecord.Subject ==='Send for Signature'
                || this.taskRecord.Subject ==='Validation by Broker Sales Admin') 
                
                && (this.taskRecord.Broker_Registration_Status__c != undefined 
                    && this.taskRecord.Broker_Registration_Status__c !=  null
                    && this.taskRecord.Broker_Registration_Status__c !=  '')){
                    this.taskRecord.Status = 'Closed'
                }

                this.isLoading = true;
                try {
                await updateTask({ task: this.taskRecord });
                if(this.DariDate){
                    await updateSR({ srequest: { Id: this.recordId, Dari_Application_Number__c:this.DariNumber,ADM_Fee__c:this.AdmAmount,Penality_Fee__c:this.PenalityAmount,Dari_Application_Submitted_Date__c: this.DariDate } });
                }
                if(this.extndNOCDate){
                    //alert('YOU ARE IN extndNOCDate METHOD this.extndNOCDate ' + this.extndNOCDate);
                    await updateSR({ srequest: { Id: this.recordId, NOC_Extension_Date__c:this.extndNOCDate,Is_NOC_Extended__c:false} });
                }
                if(this.approvedExtndNOCDate){
                    //alert('YOU ARE IN approvedExtndNOCDate METHOD' + this.approvedExtndNOCDate);               
                    await updateSR({ srequest: { Id: this.recordId, Approved_NOC_Extension_Date__c:this.approvedExtndNOCDate } });
                }
                if(this.isextensionAppstatus){
                    await updateSR({ srequest: { Id: this.recordId, Is_NOC_Extended__c:true }});
                }
                if (Number(this.outStandingChargeAmount) > 0) {
    await updateSR({
        srequest: {
            Id: this.recordId,
            Outstanding_Charge__c: this.outStandingChargeAmount
        }
    });
}


                if(this.taskRecord.Subject === 'Validation by Broker Sales Admin' 
                        && this.taskRecord.Status === 'Closed' 
                        && this.taskRecord.Broker_Registration_Status__c === 'Approved' 
                        && this.recordTypeName ==='Broker Registration'){
                 await updateSR({ srequest: { Id: this.recordId, Status__c:'Closed'} });
                }
                
            if(this.TitledeedDate){
                await updateSR({ srequest: { Id: this.recordId, ApplicationNo__c:this.TitledeedNumber,ApplicationDate__c: this.TitledeedDate } });
            }
                 if (this.isDecissionType) {
                let updateData = {
                    Id: this.recordId,
                    Decision_Type__c: this.selectedDecisiontype
                };

                if (this.isCancelationDate === true) {
                    updateData.Cancellation_Date__c = this.conditionalCancelDate;
                }
                
                    /*if (this.isUnitDecissionType === true) {
                        updateData.Status__c = 'Closed';
                    }*/

                await updateSR({ srequest: updateData });
            }

            if (this.isLegalOptionChanged) {
                let updateData = {
                    Id: this.recordId,
                    Legal_Decision__c: this.selectedLegalStatus
                };

                if (this.isCancelationDate === true) {
                    updateData.Cancellation_Date__c = this.conditionalCancelDate;
                }

                await updateSR({ srequest: updateData });
            }

                
                if(this.isUnitChanged){
                    await updateUnit({srequest: { Id: this.recordId}});
                }                
                if(this.srClose || this.isNOCExtensionRejected){
                    let srequest = {
                        Id: this.recordId,
                            Status__c: this.paymentDone ? 'Closed (Paid)' : 'Closed' // <-- Dynamic value
                    };
                    
                    if (this.srClosure && this.srClosure.trim() !== '') {
                        srequest.Comments__c = this.srClosure;
                    }
                    
                        try {
                    await updateSR({ srequest });
                        } catch (error) {
                            console.error('Error updating record:', error);
                        }
                    }
                
            
                   
                if (this.mrAppStatus) {
                    let srequest = {
                        Id: this.recordId,
                        Status__c: 'Rejected',
                        SR_Rejection_Reason__c: this.srRejectionReason ? this.srRejectionReason.trim() : null
                    };

                    try {
                        await updateSR({ srequest });
                    } catch (error) {
                        console.error('Error updating record:', error);
                    }
                }
            
                this.showToast('Success', 'Task updated successfully', 'success');
                this.handleCloseModal();
                this.hasRendered = false;
                await this.renderedCallback(); // Refresh data instead of reloading the page
                if(this.isOutStandingCharge ||  this.isDaridateChange || this.isSRCommentsChange || this.srClose || this.isNOCExtensionRejected){
                    window.location.reload();
                }

                if(this.isextndNOCDateChange || this.isextensionAppstatus){
                    window.location.reload();
                }

                if(this.isapprovedExtndNOCDateChange){
                    window.location.reload();
                }

                } catch (error) {

                    const errorMessage = this.extractErrorMessage(error.body.message);
                    this.showToast('Error', errorMessage , 'error' );
                this.handleCloseModal();
                this.hasRendered = false;
                await this.renderedCallback();
                }
            }else{
            this.showToast('Error', error.body?.message || 'Enter required Fields', 'error');
        }
    }
    get taskoptions() {
        const options = [
            { label: 'Not Started', value: 'Not Started' },
            { label: 'In Progress', value: 'In Progress' },
            { label: 'Closed', value: 'Closed' }
        ];
   
        if (this.showDariFields) {
            options.push({ label: 'Follow-up on NOC Status After 30 Days'});
        }
        return options;
        
    }
    get taskActionStatuses() {
        const options =[];
        if(this.taskRecord.Subject === 'Assignment of Broker Manager' 
            || this.taskRecord.Subject === 'Validation by Compliance Team' ){
            options.push({ label: 'Require more Information', value: 'Require more Information' },
            { label: 'Approved', value: 'Approved' },
            { label: 'Rejected', value: 'Rejected' });
        }
       else if(this.taskRecord.Subject === 'Validation by Broker Sales Admin' ){
            options.push({  label: 'Approved', value: 'Approved' },
                { label: 'Rejected', value: 'Rejected' });
        }
        else if(this.taskRecord.Subject === 'Require more information' ){
            options.push({  label: 'Completed', value: 'Completed' },
                { label: 'Voided', value: 'Voided' });
        }else if(this.taskRecord.Subject === 'Send for Signature' ){
            options.push({  label: 'Signed', value: 'Signed' },
                { label: 'Voided', value: 'Voided' });
        }else if(this.taskRecord.Subject === 'Send for Signature - Modon' ){
            options.push({  label: 'Signed', value: 'Signed' },
                { label: 'Voided', value: 'Voided' });
        }

        
        return options;
        
    }

    async handleJOAddition(event){
        if(this.taskRecord.Subject === 'Execute Joint Owner Title Deed Request'){
            this.srClose = true;
        }
        this.isLoading = true;
        try {
            const result = await doCalloutJo({ recordId: this.recordId });
            alert(result); // Display the string response
    
            if (result === 'success') {
                this.showToast('Success', 'Task updated successfully', 'success');
                this.finalexecutioncomplete=true;
                this.handleCloseModal();
                this.executioncomplete=true;
                this.hasRendered = false;
                await this.renderedCallback();
            } else {
                this.showToast('Error', result || 'Failed to load Task data', 'error');
            }
        } catch (error) {
            console.error('Error during callout:', error);
            this.showToast('Error', error.body?.message || 'Failed to load Task data', 'error');
        } finally {
            this.isLoading = false;
        }
        if(this.finalexecutioncomplete){
            this.handlefieldupdate();
        }
    }
    async handleJODeletion(event){
        
        this.isLoading = true;
        // try {
        //     const result = await executeFlow({ recordId: this.recordId });
        //     alert(result); // Display the string response
    
        //     if (result === 'success') {
        //         this.showToast('Success', 'Task updated successfully', 'success');
        //         this.handleCloseModal();
        //         this.executioncomplete=true;
        //         this.hasRendered = false;
        //         await this.renderedCallback();
        //     } else {
        //         this.showToast('Error', result || 'Failed to load Task data', 'error');
        //     }
        // } catch (error) {
        //     console.error('Error during callout:', error);
        //     this.showToast('Error', error.body?.message || 'Failed to load Task data', 'error');
        // } finally {
        //     this.isLoading = false;
        // }
        this.handleJOAddition();
    }

    async handleJOManage(event){
       
        // this.handleJODeletion();
        this.handleJOAddition();
    }
    async handletransferPtDeed(event){
        
        this.srClose=true;
        this.isLoading = true;
        try {
                const result1 = await doCallout1({ recordId: this.recordId });    
                //if (result1 === 'success') {
                   // const result2 = await doCallout2({ recordId: this.recordId });    
                    if (result1 === 'success') {
                        this.showToast('Success', 'Task updated successfully', 'success');
                        this.finalexecutioncomplete=true;
                        this.handleCloseModal();
                        this.executioncomplete=true;
                        this.hasRendered = false;
                        await this.renderedCallback();
                    } else {
                        this.showToast('Error', result2 || 'Failed to load Task data1', 'error');
                    }               
               // } else {
                 //   this.showToast('Error', result1 || 'Failed to load Task data2', 'error');
                //}            
            
        } catch (error) {
            console.error('Error during callout:', error);
            this.showToast('Error', error.body?.message || 'Failed to load Task data', 'error');
        } finally {
            this.isLoading = false;
        }

        if(this.finalexecutioncomplete){
            this.handlefieldupdate();
        }
    }

    async handleLPCManage(event) {
    this.executioncomplete=true;
    const result = await updateLPC({ serviceRequestId: this.recordId });    
    if (result === 'success') {
        this.showToast('Success', 'Task updated successfully', 'success');
        this.finalexecutioncomplete=true;
        this.handleCloseModal();
        this.executioncomplete=true;
        this.hasRendered = false;
        this.renderedCallback();
    } else {
        this.showToast('Error', result || 'Failed to Execute LPC Wavier', 'error');
    }               
    if(this.finalexecutioncomplete){
        this.handlefieldupdate();
    }

}

    async handlemilestone(event){
        const result = await executemilestonemethod({ recordId: this.recordId });    
        if (result === 'success') {
            this.showToast('Success', 'Executed Successfully', 'success');
            this.finalexecutioncomplete=true;
            this.handleCloseModal();
            this.executioncomplete=true;
            this.hasRendered = false;
            await this.renderedCallback();
        } else {
            this.showToast('Error', result || 'Failed to Execute', 'error');
        }    
        if(this.finalexecutioncomplete){
            this.handlefieldupdate();
        }           
    }
       get canExecuteMilestone() {

        if (!ALLOWED_USERS || !USER_ID) {
            return false;
        }

        const allowedUserIds = ALLOWED_USERS
            .split(',')
            .map(id => id.trim())
            .filter(id => id.length === 18);


        return allowedUserIds.includes(USER_ID);
    }
    async handletransfer(event) {
        this.isLoading = true;
        
        if(this.property_Transfer_New_Design_Enabled){
            try {
                const result2 = await propertyTransferNewDesignProcess1({ recordId: this.recordId });    
                if (result2 === 'success') {
                    this.showToast('Success', 'Task updated successfully', 'success');
                    this.finalexecutioncomplete=true;
                    this.handleCloseModal();
                    this.executioncomplete=true;
                    this.hasRendered = false;
                    await this.renderedCallback();
                } else {
                    this.showToast('Error', result2 || 'Failed to load Task data1', 'error');
                } 
            }catch (error) {
                console.error('Error during callout:', error);
                this.showToast('Error', error.body?.message || 'Failed to load Task data', 'error');
            } finally {
                this.isLoading = false;
            }
            if(this.finalexecutioncomplete){
                this.handlefieldupdate();
            }
        }else{
        try {
            const result = await doCallout({ recordId: this.recordId });
    
            if (result === 'success') {
                const result1 = await doCallout1({ recordId: this.recordId });    
                if (result1 === 'success') {
                    const result2 = await doCallout2({ recordId: this.recordId });    
                    if (result2 === 'success') {
                        this.showToast('Success', 'Task updated successfully', 'success');
                        this.finalexecutioncomplete=true;
                        this.handleCloseModal();
                        this.executioncomplete=true;
                        this.hasRendered = false;
                        await this.renderedCallback();
                    } else {
                        this.showToast('Error', result2 || 'Failed to load Task data1', 'error');
                    }               
                } else {
                    this.showToast('Error', result1 || 'Failed to load Task data2', 'error');
                }            
            } else {
                this.showToast('Error', result || 'Failed to load Task data3', 'error');
            }
        } catch (error) {
            console.error('Error during callout:', error);
            this.showToast('Error', error.body?.message || 'Failed to load Task data', 'error');
        } finally {
            this.isLoading = false;
        }
        if(this.finalexecutioncomplete){
            this.handlefieldupdate();
        }

        }

    }
    async handleUCtransfer(event) {
        this.executioncomplete=true;
         try {
        const result = await ucexecute({ serviceRequestId: this.recordId });

        if (result === 'Unit consolidation financials processed successfully') {
            this.showToast('Success', 'Executed Successfully', 'success');
            this.finalexecutioncomplete = true;
            this.handleCloseModal();
            this.executioncomplete = true;
            this.hasRendered = false;
            await this.renderedCallback();
        } else {
            this.showToast('Error', result || 'Failed to Execute', 'error');
        }

        if (this.finalexecutioncomplete) {
            this.handlefieldupdate();
        }
    } catch (error) {
        // Catch Apex exceptions thrown via AuraHandledException
        const errorMessage = error?.body?.message || 'Unexpected error occurred';
        this.showToast('Error', errorMessage, 'error');
        console.error('Unit Consolidation Error:', error);
    }
    }

    async executePreCancellationProcess(event) {
        this.isLoading = true;

        try {
            const result = await executePreUnitCancellation({
                srId: this.recordId
            });


            if (result === 'success') {
                this.showToast(
                    'Success',
                    'Pre Unit Cancellation executed successfully',
                    'success'
                );

                // Mark execution complete
                this.finalexecutioncomplete = true;
                this.executioncomplete = true;

                // Close modal
                this.handleCloseModal();

                // Refresh UI
                this.hasRendered = false;
                await this.renderedCallback();

            } else {
                this.showToast('Error', result, 'error');
            }

        } catch (error) {
            console.error('Error ---> ', error);
            const errorMessage = error?.body?.message || 'Error executing process';
            this.showToast('Error', errorMessage, 'error');
        } finally {
            this.isLoading = false;
        }

        // Update SR flag (same as other executions)
        if (this.finalexecutioncomplete) {
            this.handlefieldupdate();
        }
    }

    async executePostCancellationProcess(event) {
        this.isLoading = true;

        try {
            const result = await executePostUnitCancellation({
                srId: this.recordId
            });


            if (result === 'success') {
                this.showToast(
                    'Success',
                    'Post Unit Cancellation executed successfully',
                    'success'
                );

                // Mark execution complete
                this.finalexecutioncomplete = true;
                this.executioncomplete = true;

                // Close modal
                this.handleCloseModal();

                // Refresh UI
                this.hasRendered = false;
                await this.renderedCallback();

            } else {
                this.showToast('Error', result, 'error');
            }

        } catch (error) {
            console.error('Error ---> ', error);
            const errorMessage = error?.body?.message || 'Error executing process';
            this.showToast('Error', errorMessage, 'error');
        } finally {
            this.isLoading = false;
        }

        // Update SR flag (same as other executions)
        if (this.finalexecutioncomplete) {
            this.handlefieldupdate();
        }
    }


   async executePostCancellationProcess1() {

    // 🔥 Disable button immediately
    this.executioncomplete = true;

    try {
        await executemethodforallamounts({ srId: this.recordId });

        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Success',
                message: 'Amounts calculated successfully',
                variant: 'success'
            })
        );

    } catch (error) {
        console.error(error);

        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                message: error.body?.message || 'Something went wrong',
                variant: 'error'
            })
        );

        // ❗ Optional: Re-enable button on error
        this.executioncomplete = false;
    }
}
 get isMilestoneExecuteDisabled() {
        // Apply ONLY for Milestone Update
        if (this.showmilestoneupdate) {
            return this.executioncomplete || !this.canExecuteMilestone;
        }
        return this.executioncomplete;
    }

    handlefieldupdate(){
            const fields = {};
            fields['Id'] = this.recordId; // Mandatory
            fields['Final_Execution_Complete__c'] = true; // Replace with your field API name
    
            const recordInput = { fields };
    
            updateRecord(recordInput)
                .then(() => {
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Success',
                            message: 'Execution Completed',
                            variant: 'success'
                        })
                    );
                })
                .catch(error => {
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Error updating SR record',
                            message: error.body.message,
                            variant: 'error'
                        })
                    );
                });
    }
    get isRequired() {
        return this.statusValue === 'Closed';
    }
    get isExtendNocRequired() {
    return this.taskRecord.NOC_Doc_Status__c === 'Extend NOC';
    }
 
    get isapprovedExtndNOCRequired() {
        return this.taskRecord.NOC_Doc_Status__c === 'Approve with new dates';
    }
    
    navigateStep(event) {
        let isOpen = event.detail.isOpen;

        if (isOpen && this.taskId) {
            this.isModalOpen = true;
            this.showEventForm = this.taskRecord?.Subject === 'Book Appointment for SPA Signing';
            this.showExecute = this.taskRecord?.Subject === 'Execute Property Transfer Request';
            this.showmilestoneupdate = this.taskRecord?.Subject === 'Execute Milestone Update Request';
            this.showSendReceiptEmail = this.taskRecord?.Subject === 'Collect Payments (Outstanding / NOC)';
        this.showSendNOCInvoiceEmail = this.taskRecord?.Subject === 'Payment Status Confirmation - Finance Team';
        this.showPtDeedExecute = this.taskRecord?.Subject === 'Execute Property Transfer Title Deed Request' || this.taskRecord?.Subject === 'Upload Title Deed Copy and Execute SR';       
            this.showExecuteUC = this.taskRecord?.Subject === 'Execute Unit Consolidation Request';
            this.showuploaddoc = this.taskRecord?.Subject === 'Review Details';
            this.showDariFields = this.taskRecord?.Subject === 'Dari System Registration' || this.taskRecord?.Subject === 'CM Ops to register the Addendum in Dari system';
            this.ShowJoExecute = this.taskRecord?.Subject === 'Execute JO Request' || this.taskRecord?.Subject === 'Execute Joint Owner Title Deed Request';
            this.showOutstandingCharge = this.taskRecord?.Subject === 'Payment Status Confirmation - Finance Team';

            this.showPEExecute = this.taskRecord?.Subject === 'Execute Payment Extension Request';
            this.showPSExecute = this.taskRecord?.Subject === 'Execute SR and Review Transactions'; //Plan swap
            this.showExecuteUtUpgde = this.taskRecord?.Subject === 'CM Finance to Execute the SR and Review Transactions';
            this.showExecuteUntSwp = this.taskRecord?.Subject === 'CM Finance to Execute the Unit Swap SR and Review Transactions';
            this.showpreUnitCancellationExecute = this.taskRecord?.Subject === 'Repricing and Releases the unit before cancellation';
            this.showpostUnitCancellationExecute = this.taskRecord?.Subject === 'Repricing and Releases the unit before post cancellation';
             this.showLPCExecute = this.taskRecord?.Subject === 'Execute LPC Waiver Request';
            if(this.ShowJoExecute && this.Jotype === 'Joint Owner Addition'){
                this.JoAddition = true;
            }else if(this.ShowJoExecute && this.Jotype === 'Joint Owner Deletion'){
                this.JoDeletion = true;
            }else if(this.ShowJoExecute && this.Jotype === 'Manage JO'){
                this.ManageJo = true;
            }

            this.closednotvalid = this.taskRecord?.Subject === 'Approval needed from CM Team' || this.taskRecord?.Subject === 'Awaiting Business Approval' || (this.executioncomplete == false && this.taskRecord?.Subject === 'Execute Property Transfer Title Deed Request') || (this.executioncomplete == false && this.taskRecord?.Subject === 'Execute Joint Owner Title Deed Request')||(this.executioncomplete == false && this.taskRecord?.Subject === 'CM Finance to Execute the SR and Review Transactions') || (this.executioncomplete == false && this.taskRecord?.Subject ==='Payment Status Confirmation - Finance Team')||
	    (this.executioncomplete == false && this.taskRecord?.Subject ==='Collect Payments (Outstanding / NOC)');
            this.isExtendNOCDateDisabled = this.taskRecord?.Subject === 'Approval needed from CM Manager';
            //this.disableextndNOCDate = this.taskRecord?.Subject === 'CM Manager Approval' && this.record
  //this.showPaymentFields = this.taskRecord?.Subject === 'Payment';
        } else {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: this.taskId,
                    objectApiName: 'Task',
                    actionName: 'view'
                }
            });
        }
    }

    handleToggleSection() {
        this.accordionSection = this.accordionSection ? "Action Panel" :'';
    }

    handleCloseModal() {
        this.isModalOpen = false;
        this.showEventForm = false;
    }

    toggleEventForm() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Event',
                actionName: 'new'
            },
            state: {
                defaultFieldValues: `WhatId=${this.recordId},Subject=Appointment with Customer`
            }
        });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }

    extractErrorMessage(fullMessage) {
      /*  
        const match = fullMessage.match(/FIELD_CUSTOM_VALIDATION_EXCEPTION, (.*): \[/);
        return match ? match[1] : 'An error occurred';*/

    let match;

    if (match = fullMessage.match(/FIELD_CUSTOM_VALIDATION_EXCEPTION,\s*(.*?):\s*\[/)) {
        return match[1];
    } else if (match = fullMessage.match(/Error updating task:\s*(.*)/)) {
        return match[1];
    }

    // Fallback message
    return 'An error occurred';
    }

    async handlePEtransfer(event) {
        this.executioncomplete=true;
        const result = await updatePE({ srId: this.recordId });    
        if (result === 'success') {
            this.showToast('Success', 'Task updated successfully', 'success');
            this.finalexecutioncomplete=true;
            this.handleCloseModal();
            this.executioncomplete=true;
            this.hasRendered = false;
            this.renderedCallback();
        } else {
            this.showToast('Error', result || 'Failed to Execute Payment Extension', 'error');
        }               
        if(this.finalexecutioncomplete){
            this.handlefieldupdate();
        }

    }
async handlePStransfer(event) {
    
    const result = await planSwap({ srId: this.recordId });    
     
    if (result === 'paymentplanswap success') {
        this.showToast('Success', 'Task updated successfully', 'success');
        this.finalexecutioncomplete = true;
        this.handleCloseModal();
        this.executioncomplete = true;
        this.hasRendered = false;
        this.renderedCallback();
    }else {
            this.showToast('Error', result || 'Failed to Execute Payment Plan Swap', 'error');
        }            

    if (this.finalexecutioncomplete) {
        this.handlefieldupdate();
    }
}

async executePreCancellationProcess(event) {
        this.isLoading = true;

        try {
            const result = await executePreUnitCancellation({
                srId: this.recordId
            });


            if (result === 'success') {
                this.showToast(
                    'Success',
                    'Pre Unit Cancellation executed successfully',
                    'success'
                );

                // Mark execution complete
                this.finalexecutioncomplete = true;
                this.executioncomplete = true;

                // Close modal
                this.handleCloseModal();

                // Refresh UI
                this.hasRendered = false;
                await this.renderedCallback();

            } else {
                this.showToast('Error', result, 'error');
            }

        } catch (error) {
            console.error('Error ---> ', error);
            const errorMessage = error?.body?.message || 'Error executing process';
            this.showToast('Error', errorMessage, 'error');
        } finally {
            this.isLoading = false;
        }

        // Update SR flag (same as other executions)
        if (this.finalexecutioncomplete) {
            this.handlefieldupdate();
        }
    }

    async executePostCancellationProcess(event) {
        this.isLoading = true;

        try {
            const result = await executePostUnitCancellation({
                srId: this.recordId
            });


            if (result === 'success') {
                this.showToast(
                    'Success',
                    'Post Unit Cancellation executed successfully',
                    'success'
                );

                // Mark execution complete
                this.finalexecutioncomplete = true;
                this.executioncomplete = true;

                // Close modal
                this.handleCloseModal();

                // Refresh UI
                this.hasRendered = false;
                await this.renderedCallback();

            } else {
                this.showToast('Error', result, 'error');
            }

        } catch (error) {
            console.error('Error ---> ', error);
            const errorMessage = error?.body?.message || 'Error executing process';
            this.showToast('Error', errorMessage, 'error');
        } finally {
            this.isLoading = false;
        }

        // Update SR flag (same as other executions)
        if (this.finalexecutioncomplete) {
            this.handlefieldupdate();
        }
    }

     async executePostCancellationProcess1() {

    //  Disable button immediately
    this.executioncomplete = true;

    try {
        await executemethodforallamounts({ srId: this.recordId });

        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Success',
                message: 'Amounts calculated successfully',
                variant: 'success'
            })
        );

    } catch (error) {
        console.error(error);

        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                message: error.body?.message || 'Something went wrong',
                variant: 'error'
            })
        );

        //  Optional: Re-enable button on error
        this.executioncomplete = false;
    }
}
  
}