import { LightningElement, api, track } from 'lwc';
import getFields from '@salesforce/apex/ApprovalDynamicFieldController.getFields';
import getStepDocuments from '@salesforce/apex/ApprovalDynamicFieldController.getStepDocuments';
import assignStepToCurrentUser from '@salesforce/apex/BusinessProcessController.assignStepToCurrentUser';
import getSteps from '@salesforce/apex/LwcApproveRejectBpstepController.getSteps';
import getAssinedSteps from '@salesforce/apex/LwcApproveRejectBpstepController.getAssinedSteps';
import approveStepAssignedTo from '@salesforce/apex/LwcApproveRejectBpstepController.approveStepAssignedTo';
import requestForMoreInfo from '@salesforce/apex/LwcApproveRejectBpstepController.requestForMoreInfo';
import approveStep from '@salesforce/apex/LwcApproveRejectBpstepController.approveStep';
import rejectStep from '@salesforce/apex/LwcApproveRejectBpstepController.rejectStep';
import onHoldStep from '@salesforce/apex/LwcApproveRejectBpstepController.onHoldStep';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import isCheckListProvided from '@salesforce/apex/BusinessProcessController.isCheckListProvided';
import checkLoggedInUser from '@salesforce/apex/LwcApproveRejectBpstepController.checkLoggedInUser';
import getnextqueueMembers from '@salesforce/apex/LwcApproveRejectBpstepController.getnextqueueMembers';
import userId from '@salesforce/user/Id';
import updateBusinessProcess from '@salesforce/apex/ApprovalModalController.updateBusinessProcess';

export default class ApprovalModal extends LightningElement {
    @api isOpen = false;
    @api step = {};
    @api recordId;
    @api businessProcessName;

    @track accepted = false;
    @track hasVerificationSteps = false;
    @track verificationComplete = true;
    @track showBankReference = false;
    @track initialized = false;
    @track isLoading = true;
    @track assignToUserOptions = [];
    @track assignToUser;

    @track uploadedFiles = {};
    @track stpName = '';

    // Multi step Values 
    @track multiStepValues = [];
    @track showMultiStep = false;
    @track filteredStepOptions = [];

    //nsv
    @track fields = [];
    fieldValues = {};
    fieldMeta = {};
    @track documents = [];

    showDynamicForm = false;
    selectedOption; 
    confirmationDate; 
    extensionDate; 
    //nsv
    @track processFlowUniqueName;
    @track Case__c = null;
    @track stpName = '';
    radioValue;
    comment;
    stepValue;
    assinedTostepValue;
    brValue;
    stepOptions = [];
    stepData;
    selectedRows;
    assignedTostepOptions = [];
    showStep = false;
    showAssignSection = false;
    showAssignToStep = false;
    showApproval = false;
    allNotVerified = false;

    currentUserId = userId;
    //TD: Bank Details Document Variables
    @track docTypeValue;
    @track reasonValue;
    @track reasonOptions = [];
    @track showReason = false;
    @track showDocType = false;
    @track isBrAmendment = false;//END

    requiredBeneficiaryDocs = ['Beneficiary Document']; //---- SRS2 412 ---- Refund Process - By Ayaz //
    bpnDocs = ['BPN Document']; //---- SRS2 412 ---- Refund Process - By Ayaz //
    swiftCopyDocs = ['Swift Copy']; //---- SRS2 412 ---- Refund Process - By Ayaz //
    initiationCopyDocs = ['Initiation Copy']; //---- SRS2 412 ---- Refund Process - By Ayaz //

    requiredMortgageDocs = ['Mortgage Contract', 'DLD Letter', 'Manager Cheque Copy'];
    requiredDSRSnapDocs = ['DSR Snap'];
    requiredFOLDocs = ['Signed and Stamped SPA Particulars', 'Completion Notice for the Building', 'Handover Notice for the Building', 'Oqood Payment Receipt'];
    requiredGeratedDSRDocs = ['DSR Document'];
    requiredTitleDeedDocs = ['Title Deed Document'];
    requiredSignedDSRDocs = ['Signed DSR Document'];
    authorizeSignedDSRDocs = ['Authorize Signed DSR'];

    requiredDocListReAllocation = ['Customer Acknowledgement Email', 'Valid Proof of Payment (POP)', 'Collection Report Screenshot', 'Indemnity Letter (from the Remitter)']; //---- SRS2 410 ---- Fund Reallocation Process - By Furkan //

    verificationSteps = [];
    verificationStatusOptions = [
        { label: 'Verified', value: 'Verified' },
        { label: 'Not Verified', value: 'Not Verified' },
        { label: 'None', value: 'None' }
    ];

    @track isLoading = false;

    @track showCostApprovalFields = false;
    processIdentifierValue;

    handleMultiStepChange(event) {
        this.multiStepValues = event.detail.value;
    }

    get showAcceptButton() {
        return !this.accepted && !this.step.AssignedTo;
    }

    get hideApprovalFields() {
        return !this.showApproval || !(this.accepted || this.step?.AssignedTo);

    }

    checkAndSkipToApproval() {
        // Check if there's no checklist or reviewer comments to display
        const hasCheckList = this.step.isCheckList && this.step.currentCheckListItem != null;
        const hasReviewComments = this.step.viewReviewComments || this.step.isReviewCommentsReq;

        // If nothing to show and user has accepted or is assigned, skip directly to approval
        if (!hasCheckList && !hasReviewComments && (this.accepted || this.step.AssignedTo)) {
            this.showApproval = true;
        }
    }

    async getFieldsInfo() { //nsv
        try {
            const result = await getFields({ stepName: this.step.Name, recordId: this.recordId });
            if (result && result.fields && result.fields.length > 0) {
                const metaFields = result.fields;
                 const values = result.values || {};
                this.fields = metaFields.map(field => {
                    let options = [];
                    if (field.Picklist_Values__c) {
                        options = field.Picklist_Values__c.split(';').map(v => {
                            return { label: v, value: v };
                        });
                    }
                     const existingValue = values[field.Field_API_Name__c];
                     if (existingValue !== undefined && existingValue !== null) {
    this.fieldValues[field.Field_API_Name__c] = existingValue;
}
                    this.fieldMeta[field.Field_API_Name__c] = {
                        objectName: field.Object_API_Name__c,
                        fieldApi: field.Field_API_Name__c
                    };

                    return {
                        ...field,
                        value: existingValue,
                        isText: field.Field_Type__c === 'text',
                        isNumber: field.Field_Type__c === 'number',
                        isDate: field.Field_Type__c === 'date',
                        isPicklist: field.Field_Type__c === 'picklist',
                        isCheckbox: field.Field_Type__c === 'checkbox',
                        options: options
                    };

                });
                this.showDynamicForm = true;
            }
        } catch (error) {
            console.error('Error loading dynamic fields', error);
        }
    }

    handleFieldChange(event) {
        const field = event.target.dataset.field;
        if (event.target.type === 'checkbox') {
            this.fieldValues[field] = event.target.checked;
        } else {
            this.fieldValues[field] = event.target.value;
        }
    }

    get showPayReadiness(){
        return this.step.Name=='Payment Readiness Check';
    }

    get showPaymentPrcess(){
           return this.step.Name=='Payment Processing';
    }

     get isProjectTeamStep() {
        return this.step.Name === 'Project Team Confirm/Extend Milestone';
    }

    handleChildData(event) {
        const data = event.detail;

         this.selectedOption = data.selectedOption;
         this.confirmationDate = data.confirmationDate;
         this.extensionDate = data.extensionDate;
        
    }

    async documentsInfo() {
        try {
            const result = await getStepDocuments({ stepId: this.step.Id });
            this.documents = result.map(doc => ({
                Id: doc.docId,
                Name: doc.docName,
                fileName: doc.fileName,
                contentDocId: doc.contentDocumentId,
                uploaded: doc.fileName ? true : false,
                isUploading: false
            }));
        } catch (error) {
            console.error(error);
        }
    }

    handleUploadStart(event) {
        const docId = event.target.dataset.id;
        this.documents = this.documents.map(doc => {
            if (doc.Id === docId) {
                return { ...doc, isUploading: true };
            }
            return doc;

        });
    }

    handleUploadFinished(event) {
        const docId = event.target.dataset.id;
        const uploadedFiles = event.detail.files;

        this.documents = this.documents.map(doc => {

            if (doc.Id === docId) {
                return {
                    ...doc,
                    uploaded: true,
                    fileName: uploadedFiles[0].name,
                    contentDocId: uploadedFiles[0].documentId
                };
            }

            return doc;

        });

    }

    viewFile(event) {
        const docId = event.currentTarget.dataset.id;
       // alert('nsv' + docId);
        const doc = this.documents.find(d => d.Id === docId);
        if (doc.contentDocId) {
            window.open('/sfc/servlet.shepherd/document/download/' + doc.contentDocId);

        }
    }

    async connectedCallback() {
        //await this.initVerificationSteps();  // Make sure this.step is populated here
        this.initialized = true;
        if (this.step.AssignedTo === this.currentUserId) {
            this.accepted = true;
        }
        // Auto-skip to approval options if no checklist or reviewer comments to show
        this.checkAndSkipToApproval();

        try {
  // Assumes this.step is already populated
            this.getFieldsInfo();
            this.documentsInfo();
            this.isLoading = false;
        } catch (error) {
            console.error('Error in connectedCallback logic:', error);
        }
    }

    get showApprovalOptions() {
        if (!this.initialized || this.isLoading) return false;
        return this.showApproval === true;
    }

    get showVerificationSection() {
        return (this.accepted || this.step.AssignedTo) &&
            this.hasVerificationSteps &&
            !this.verificationComplete;
    }

    get showCheckList() {
        if (this.showApproval) {
            return !this.showApproval;
        }
        return this.step.isCheckList && this.step.currentCheckListItem != null && (this.accepted || this.step.AssignedTo);
    }

    get showChecklistItemDisplay() {
        return (
            this.step &&
            this.step.Name === 'Development - Providing Complete Project Details' &&
            (this.accepted || this.step.AssignedTo)
        );
    }
    get showCheckInitiaton() {
        if (this.showApproval) {
            return !this.showApproval;
        }
        return this.step.isCheckList && this.step.currentCheckListItem == null && (this.accepted || this.step.AssignedTo);
    }

    get radioOptions() {
        let options = [
            { label: 'Approve', value: 'Approve' }
        ];
        if (this.step?.isRequiredInfoButtonRequired) {
            options.splice(1, 0, { label: 'Returned for Additional Information', value: 'Request for more information' }); // Insert 'Request for more information' at position 1
        }
        if (this.step?.isRejectButtonRequired) {
            options.splice(2, 0, { label: 'Reject Request', value: 'Cancel Request' }); // Insert 'Reject' at position 1
        }
        return options;
    }

    // Comment is optional when approving; still required for every other action.
    get isCommentRequired() {
        return this.radioValue !== 'Approve';
    }

    get showReviewerComments() {
        return (this.step.viewReviewComments || this.step.isReviewCommentsReq) && !this.showApproval && (this.accepted && this.step.AssignedTo);
    }

    handleNextFromReviewComments() {
        this.showApproval = true;
    }

    async handleAccept() {
        let hasAcceptAccess = true;
        await checkLoggedInUser({ stepId: this.step.Id })
            .then(result => {
                if (result != 'Success') {
                    hasAcceptAccess = false;
                    return this.showToast('Error', 'You are not authorised to accept the step record', 'error');
                }
            })
        if (hasAcceptAccess) {
            this.isLoading = true;
            assignStepToCurrentUser({ stepId: this.step.Id })
                .then(result => {
                    this.accepted = true;
                    this.step = { ...this.step, AssignedTo: 'justAssigned' };
                    this.dispatchEvent(new CustomEvent('submit'));
                    this.showToast('Success', 'Step assigned to you.', 'success');
                    this.isLoading = false;
                    window.location.reload();
                })
                .catch(error => {
                    this.isLoading = false;
                    this.showToast('Error', error?.body?.message || 'Assignment failed.', 'error');
                    this.dispatchEvent(new CustomEvent('cancel'));
                });
        }
    }

    handleAssignChange(e) {
        this.assignToUser = e.detail.value;
    }

    handleRowSelection(event) { // nsv Multi select option
        this.selectedRows = event.detail.selectedRows.map(row => row.Id);
    }

    @track draftValues = [];
    columns = [
        {
            label: 'Step Name',
            fieldName: 'Name',
            type: 'text'
        },
        {
            label: 'Reason',
            fieldName: 'reason',
            type: 'text',
            editable: true
        }
    ];

    handleDraftSave(event) {
        const drafts = event.detail.draftValues;

        let updatedData = [...this.stepData];

        drafts.forEach(draft => {
            const index = updatedData.findIndex(row => row.Id === draft.Id);
            if (index !== -1) {
                updatedData[index] = {
                    ...updatedData[index],
                    ...draft
                };
            }
        });


        const invalidRows = updatedData.filter(row =>
            this.selectedRows.includes(row.Id) && (!row.reason || row.reason.trim() === '')
        );

        if (invalidRows.length > 0) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Please enter reason for all selected steps',
                    variant: 'error'
                })
            );

            return;
        }


        this.stepData = updatedData;
        this.draftValues = [];
    }

    handleRadioChange(event) {
        this.radioValue = event.detail.value;
        this.multiStepValues = [];
        if (this.radioValue === 'Request for more information') {
            if (this.step?.isMultiStepSelect) {
                this.showMultiStep = true;
                this.showStep = false;
            } else {
                this.showMultiStep = false;
                this.showStep = true;
            }

        } else {
            this.showStep = false;
            this.showMultiStep = false;
        }

        this.showDocType = (this.radioValue === 'Request for more information' || this.radioValue === 'Cancel Request') && this.isBrAmendment;
        this.showAssignSection = this.radioValue === 'Approve' && this.step.ChooseNextOwner ? true : false;
        this.showAssignToStep = this.radioValue === 'Approve' && this.step.isAssinedTO ? true : false;
        if (this.showAssignSection) {
            getnextqueueMembers({ bpsId: this.step.Id })
                .then(res => {
                    this.assignToUserOptions = res;
                })
                .catch(err => this.showToast('Error loading queue users', err.body.message, 'error'));
        }
        if (this.showAssignToStep) {
            getAssinedSteps({ bpsId: this.step.Id })
                .then(result => {
                    this.assignedTostepOptions = result.map(item => ({
                        label: item.Name,
                        value: item.Id
                    }));
                })
                .catch(error => this.showToast('Error', 'Fetching steps failed.', error));
        }

        if (this.showStep || this.showMultiStep) {
            getSteps({ bpsId: this.step.Id })
                .then(result => {
                    this.stepOptions = result.map(item => ({
                        label: item.Name,
                        value: item.Id
                    }));
                    this.stepData = this.stepOptions.map(opt => ({
                        Id: opt.value,
                        Name: opt.label,
                        reason: ''
                    }));
                    this.stepValue = null;
                    this.filteredStepOptions = [];
                    this.multiStepValues = [];
                })
                .catch(error => this.showToast('Error', 'Fetching steps failed.', error));
        }
    }

    handleCommentChange(event) {
        this.comment = event.detail.value;
    }

    handleStepChange(event) {
        this.stepValue = event.detail.value;
    }

    handleAssignedTOStepChange(event) {
        this.assinedTostepValue = event.detail.value;
    }

    async handleSubmit() {
        let wrapper = {
            recordId: this.recordId,
            stepId: this.step.Id,
            stepName: this.step.Name,
            action: this.radioValue,
            comment: this.comment,
            fieldValues: this.fieldValues,
            fieldMeta: this.fieldMeta

        };
        //alert('nsv' + JSON.stringify(wrapper));
        if (!this.radioValue) {
            return this.showToast('Error', 'Please select an action.', 'error');
        }
        if (this.isCommentRequired && !this.comment) {
            return this.showToast('Error', 'Please enter a comment.', 'error');
        }


        if (this.businessProcessName === 'Pre Registration' && (this.step.Name === 'Accounts -Naqoodi transfer' || this.step.Name === 'Treasury confirmation with Reference Number' || this.step.Name === 'Account DLD payment Entries')) {
            return this.showToast('Error', 'This step cannot be approved from here. Please use the Excel file upload option on the home screen to approve it.', 'error');
        }
        if (this.step.AssignedTo !== this.currentUserId) {
            return this.showToast('Error', 'You are not authorised to update the step record', 'error');
        }

        let hasApproveAccess = true;
        await checkLoggedInUser({ stepId: this.step.Id })
            .then(result => {
                if (result != 'Success') {
                    hasApproveAccess = false;
                    return this.showToast('Error', 'You are not authorised to update the step record', 'error');
                }
            })
        if (hasApproveAccess) {
            this.isLoading = true;
            try {

                if (this.isProjectTeamStep && this.radioValue ==='Approve') {

                    if (!this.confirmationDate && !this.extensionDate) {
                    alert('Please complete required fields');
                    this.isLoading=false;
                    return;
                    }
                       updateBusinessProcess({
        recordId: this.recordId,
        selectedOption: this.selectedOption,
        confirmationDate: this.confirmationDate,
        extensionDate: this.extensionDate
    })
    .catch(error => {
        console.error(error);
    });
                }

                if (this.radioValue === 'Request for more information' && !this.stepValue && this.showStep) {
                    this.isLoading = false;
                    return this.showToast('Error', 'Please select a step to reject to.', 'error');
                }

                if (this.radioValue === 'Request for more information' && this.showMultiStep) {
                    if (!this.selectedRows || this.selectedRows.length === 0) {
                        this.isLoading = false;
                        return this.showToast('Error', 'Please select at least one step.', 'error');
                    }

                    const selectedSteps = this.stepData.filter(step =>
                        this.selectedRows.includes(step.Id)
                    );

                    const invalidSteps = selectedSteps.filter(step =>
                        !step.reason || step.reason.trim() === ''
                    );

                    if (invalidSteps.length > 0) {
                        this.isLoading = false;
                        return this.showToast('Error', 'Please enter reason for all selected steps.', 'error');
                    }

                  }

                    //nsv
                    if (this.radioValue === 'Approve' && (this.isEligibilty || this.iscomHold || this.isbookingClash)) {
                        this.isLoading = false;
                        return this.showToast('Error', 'Please Reject the step as Broker Ledger is not Eligible now.', 'error');
                    }

                    if (this.radioValue === 'Approve' && this.step.isAssinedTO == true && !this.assinedTostepValue) {
                        this.isLoading = false;
                        return this.showToast('Error', 'Please select Assigned to step.', 'error');
                    }

                    switch (this.radioValue) {
                        case 'Request for more information':
                            await requestForMoreInfo({
                                //TD :Wrapper Change
                                rfmiWrap: JSON.stringify({
                                    bpsId: this.step.Id,
                                    rejectingToBpsId: this.stepValue,
                                    comment: this.comment,
                                    documentType: this.docTypeValue,
                                    reasonForMoreInfo: this.reasonValue,
                                    multiStepIds: this.multiStepValues,
                                    multiSteps: (this.stepData && this.selectedRows)
                                        ? this.stepData
                                            .filter(step => this.selectedRows.includes(step.Id))
                                            .map(step => ({ Id: step.Id, reason: step.reason || '' }))
                                        : []


                                    //added this on 5th jan for multiselect values
                                })
                                //brNumber: this.brValue
                            });
                            this.isLoading = false;
                            this.dispatchEvent(new CustomEvent('submit'));
                            this.showToast('Success', 'Step sent back successfully.', 'success');
                            if (this.processFlowUniqueName === 'Broker Ledger Approvals')
                                window.location.reload();
                            break;

                        case 'Approve':
                            if (this.step.isAssinedTO == true) {
                                await approveStepAssignedTo({
                                    bpsId: this.step.Id,
                                    assignedToBpsId: this.assinedTostepValue,
                                    comment: this.comment

                                });
                            } else {
                                const wrapperJSON = JSON.stringify(wrapper);
                                await approveStep({
                                    wrapperJSON: wrapperJSON,
                                    bpsId: this.step.Id,
                                    comment: this.comment,
                                    nextStepOwnerID: this.assignToUser
                                    //brNumber: this.brValue
                                });
                            }
                            this.isLoading = false;
                            this.dispatchEvent(new CustomEvent('submit'));
                            this.showToast('Success', 'Approved successfully.', 'success');
                            if (this.processFlowUniqueName === 'Broker Ledger Approvals')
                                window.location.reload(); //nsv
                            break;

                        case 'Cancel Request':
                            await rejectStep({
                                //TD :Wrapper Change
                                rejWrap: JSON.stringify({
                                    bpsId: this.step.Id,
                                    comment: this.comment,
                                    documentType: this.docTypeValue,
                                    reasonForRejection: this.reasonValue
                                })
                            });
                            this.isLoading = false;
                            this.dispatchEvent(new CustomEvent('submit'));
                            this.showToast('Success', 'Rejected successfully.', 'success');
                            break;

                        case 'On Hold':
                            await onHoldStep({
                                bpId: this.recordId,
                                bpsId: this.step.Id,
                                comment: this.comment
                            });
                            this.isLoading = false;
                            this.dispatchEvent(new CustomEvent('submit'));
                            this.showToast('Info', 'You have put the process on hold.', 'info');
                            break;

                        case 'Submit to Audit':
                            await submitToAudit({
                                bpsId: this.step.Id,
                                comment: this.comment,
                            });
                            this.isLoading = false;
                            this.dispatchEvent(new CustomEvent('submit'));
                            this.showToast('Sucess', 'Submitted to Aduit Successfully', 'Success');
                            break;

                    }
                    this.isLoading = false;
                } catch (error) {
                    this.isLoading = false;
                    this.showToast('Error', error?.body?.message || 'Action failed.', 'error');
                }
            }

    }

        handleCancel() {
            this.dispatchEvent(new CustomEvent('cancel'));
        }

        handleNext() {
            if (this.step.viewReviewComments || this.step.isReviewCommentsReq) {
                this.showApproval = true;
                return;
            }
            if (this.step.isCheckList) {
                if (!this.step?.parentId) {
                    this.showToast('Error', 'Checklist parent Id missing.', 'error');
                    return;
                }
                isCheckListProvided({ parentId: this.step.parentId })
                    .then(result => {
                        if (!result) {
                            this.showToast('Validation', 'Please fill all checklist data.', 'error');
                        } else {
                            this.showApproval = true;
                        }
                    })
                    .catch(error => {
                        console.error('Checklist validation error:', error);
                        this.showToast('Error', error?.body?.message || 'Checklist validation failed', 'error');
                    });
                return;
            }
            // DEFAULT FALLBACK
            this.showApproval = true;
        }

        showToast(title, message, variant = 'info') {
            this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
        }

    }