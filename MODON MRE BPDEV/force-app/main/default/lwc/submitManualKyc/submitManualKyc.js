/**********************************************************************************************************************
* Name               : submitManualKyc.js                                                        
* Description        : JavaScript controller for the Manual KYC Quick Action LWC. Manages UI state, file uploads, and submission.
*                      Object-agnostic - drives Account and Contact from the same bundle.
* Usage              : LWC
* Created By         : Rushi Patel - Horizontal Digital                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Rushi Patel                 27 Aug 2026           Initial draft 
* 1.1           Rushi Patel                 21 September 2026     Generalised for Account + Contact
* 1.1           Arvind                      17 Sep 2026     Made supporting document upload optional: removed file check
*                                                           from submit validation, removed auto-selection of a single
*                                                           existing file, pass null documentId when no file selected
******************************************************************************************************************/
import { LightningElement, api, wire, track } from 'lwc';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import submitForApproval from '@salesforce/apex/ManualKYCController.submitForApproval';
import getAvailableKYCFiles from '@salesforce/apex/ManualKYCController.getAvailableKYCFiles';
import renameUploadedFile from '@salesforce/apex/ManualKYCController.renameUploadedFile';

export default class SubmitManualKyc extends LightningElement {
    @api recordId;
    // Injected automatically by the Quick Action framework (Account or Contact).
    @api objectApiName;
    
    // Field states
    kycReason = '';
    kycComment = '';
    @track existingFiles = [];
    selectedFileId = '';
    
    // New UX states for file upload
    isNewlyUploaded = false;
    newlyUploadedFileName = '';
    
    // UI Loading states
    isFormLoaded = false;
    isFileWireComplete = false;
    isActionLoading = false;
    wiredFilesResult;

    get isInitialLoading() {
        return !(this.isFormLoaded && this.isFileWireComplete);
    }

    get showSpinner() {
        return this.isInitialLoading || this.isActionLoading;
    }

    get containerClass() {
        return this.isInitialLoading ? 'slds-hide' : 'slds-show';
    }

    // v1.1 - Removed auto-selection of a single existing file, since the document is now optional
    @wire(getAvailableKYCFiles, { recordId: '$recordId' })
    wiredFiles(result) {
        this.wiredFilesResult = result;
        if (result.data) {
            this.existingFiles = result.data;
            this.isFileWireComplete = true;
        } else if (result.error) {
            this.isFileWireComplete = true;
            this.showToast('Error', 'Failed to load existing files.', 'error');
        }
    }

    handleFormLoad(event) {
        this.isFormLoaded = true;
        
        if (event.detail && event.detail.records && event.detail.records[this.recordId]) {
            const fields = event.detail.records[this.recordId].fields;
            
            if (fields.KYC_Manual_Reason__c && fields.KYC_Manual_Reason__c.value) {
                this.kycReason = fields.KYC_Manual_Reason__c.value;
            }
            if (fields.Manual_KYC_Comment__c && fields.Manual_KYC_Comment__c.value) {
                this.kycComment = fields.Manual_KYC_Comment__c.value;
            }
        }
    }

    get acceptedFormats() {
        return ['.pdf', '.png', '.jpg', '.jpeg', '.docx', '.doc', '.xlsx', '.xls', '.csv'];
    }

    // v1.1 - Label now indicates the upload is optional
    get fileUploadLabel() {
        return this.hasExistingFiles ? '' : 'Upload Supporting Document (Optional)';
    }

    // v1.1 - Supporting document is no longer required to submit
    get isSubmitDisabled() {
        return !(this.kycReason && this.kycComment) || this.isActionLoading;
    }

    get hasExistingFiles() {
        return this.existingFiles && this.existingFiles.length > 0;
    }

    get isExistingSelected() {
        return this.selectedFileId && !this.isNewlyUploaded;
    }

    handleReasonChange(event) {
        this.kycReason = event.detail.value;
    }

    handleCommentChange(event) {
        this.kycComment = event.detail.value;
    }

    handleFileSelection(event) {
        this.selectedFileId = event.detail.value;
    }

    clearSelection() {
        this.selectedFileId = '';
        this.isNewlyUploaded = false;
        this.newlyUploadedFileName = '';
    }

    handleUploadFinished(event) {
        const uploadedFiles = event.detail.files;
        if (uploadedFiles && uploadedFiles.length > 0) {
            this.isActionLoading = true;
            const newFileId = uploadedFiles[0].documentId;
            
            renameUploadedFile({ documentId: newFileId })
                .then((renamedFile) => {
                    this.selectedFileId = renamedFile.value;
                    this.newlyUploadedFileName = renamedFile.label;
                    this.isNewlyUploaded = true;
                    this.isActionLoading = false;
                    this.showToast('Success', 'File uploaded successfully.', 'success');
                    
                    // Refresh in background so it's populated if they clear selection
                    refreshApex(this.wiredFilesResult);
                })
                .catch(error => {
                    this.isActionLoading = false;
                    this.showToast('Error', 'Failed to rename the uploaded file.', 'error');
                });
        }
    }

    handleSubmit() {
        this.isActionLoading = true;
        
        // v1.1 - Send null when no document is selected to avoid an "Invalid id" error in Apex
        submitForApproval({ 
            recordId: this.recordId, 
            kycReason: this.kycReason, 
            kycComment: this.kycComment,
            documentId: this.selectedFileId || null
        })
        .then(() => {
            this.isActionLoading = false;
            this.showToast('Success', 'Record submitted for Manual KYC approval.', 'success');
            this.closeAction();
        })
        .catch(error => {
            this.isActionLoading = false;
            let errorMsg = 'An error occurred during submission.';
            if (error && error.body && error.body.message) {
                errorMsg = error.body.message;
            }
            this.showToast('Error', errorMsg, 'error');
        });
    }

    closeAction() {
        this.dispatchEvent(new CloseActionScreenEvent());
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