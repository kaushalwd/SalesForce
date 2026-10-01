import { LightningElement, api, track, wire } from 'lwc';
import approveStep from '@salesforce/apex/LwcApproveRejectBpstepController.approveMultipleSteps';
import approveFileIds from '@salesforce/apex/LwcApproveRejectBpstepController.approveFileIds';
import rejectStep from '@salesforce/apex/LwcApproveRejectBpstepController.rejectMultipleSteps';
import getSteps from '@salesforce/apex/LwcApproveRejectBpstepController.getSteps';
import requestForMoreInfoMultipleSteps from '@salesforce/apex/LwcApproveRejectBpstepController.requestForMoreInfoMultipleSteps';
import getDocumentsWithFiles from '@salesforce/apex/LwcApproveRejectBpstepController.getPaymentProofDocuments';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';

export default class LwcApprovalRejectMassSteps extends NavigationMixin(LightningElement) {
    @api stepIds = []; // Array of step IDs to process
    @api stepName = '';
    @api processName = '';
    @api totalDldAmount = 0;
    @track stepOptions = [];
    @track uploadedFileIds = [];
    @track uploadedSuportFileIds = [];
    @track paymentProofDocuments = [];
    acceptedFormats = ['.pdf', '.png', '.jpg', '.jpeg', '.docx'];
    
    radioValue;
    comment;
    selectedStepId;
    showStepSelection = false;
    isLoading = false;

    bpnNumber;
    transactionRefNumber;
    showBPNNumberField = false;
    showTransactionRefField = false;
    showFileUpload = false;

    // File preview properties
    showPreviewModal = false;
    previewFileUrl;
    previewFileName;
    previewFileId;

    hasUploadedFiles = false;
    hasUploadedSupportFiles = false;

     @track selectedDecision;

    decisionOptions = [
        {
            label: 'Proceed with notification',
            value: 'Proceed with notification'
        },
        {
            label: 'Proceed without notification',
            value: 'Proceed without notification'
        }
    ];

  handleCMDecisionChange(event) {
        this.selectedDecision = event.detail.value;
    }
    connectedCallback() {
        // Load payment proof documents if this is the Treasury step
        if ( (this.stepName === 'Treasury confirmation with Reference Number' || this.stepName === 'Accounts - Validation' || this.stepName === 'Audit -Naqoodi transfer') && this.stepIds.length > 0) {
            this.loadExistingDocuments();
        }
    }

    get firstStepId() {
        return this.stepIds && this.stepIds.length > 0 ? this.stepIds[0] : null;
    }

    get showProceedConfirmation(){
        return this.stepName==='CM Manager Approval';
    }
    
    get radioOptions() {
        return [
            { label: 'Approve', value: 'Approve' },
            { label: 'Reject', value: 'Reject' },
            { label: 'Request for more information', value: 'Request for more information' }
        ];
    }

    checkStepNameForAdditionalFields() {
        if (this.radioValue === 'Approve' && this.stepName === 'Accounts -Naqoodi transfer') {
            this.showBPNNumberField = true;
            this.showTransactionRefField = false;
        } else if (this.radioValue === 'Approve' && this.stepName === 'Treasury confirmation with Reference Number') {
            this.showBPNNumberField = false;
            this.showTransactionRefField = true;
        } else {
            this.showBPNNumberField = false;
            this.showTransactionRefField = false;
        }
    }

    handleRadioChange(event) {
        this.radioValue = event.detail.value;
        

        // Check if we should show the approve condition input
        this.checkStepNameForAdditionalFields();
        this.showFileUpload = (this.radioValue === 'Approve' && this.stepName!='CM Manager Approval');
        

        this.showStepSelection = false;
        this.selectedStepId = null;
        this.stepOptions = [];
        if (this.radioValue === 'Request for more information' && this.stepIds.length > 0) {
            //this.isLoading = true;
            getSteps({ bpsId: this.stepIds[0] })
                .then(result => {
                    if (result && result.length > 0) {
                        this.showStepSelection = true; // Show step selection
                        this.stepOptions = result.map(item => ({
                            label: item.Name,
                            value: item.Id
                        }));
                    } else {
                        this.showToast('Info', 'No previous steps available for sending request.', 'info');
                        /*this.showStepSelection = false; // Hide step selection if no steps are returned
                        this.selectedStepId = null; // Reset selected step
                        this.stepOptions = []; // Optional: reset if needed
                        this.isLoading = false;
                        */
                    }
                })
                .catch(error => {
                    this.showToast('Error', 'Fetching steps failed.', error)
                })
                .finally(() => {
                    this.isLoading = false; 
                });
        } 
    }

    handleCommentChange(event) {
        this.comment = event.detail.value;
    }

    handleBPNNumberChange(event) {
        this.bpnNumber = event.detail.value;
    }

    handleTransactionRefChange(event) {
        this.transactionRefNumber = event.detail.value;
    }

    handleStepChange(event) {
        this.selectedStepId = event.detail.value;
    }

    // File icon mapping based on file extension
    getFileIcon(fileName) {
        if (!fileName) return 'doctype:unknown';
        
        const extension = fileName.split('.').pop().toLowerCase();
        switch(extension) {
            case 'pdf': return 'doctype:pdf';
            case 'doc': case 'docx': return 'doctype:word';
            case 'xls': case 'xlsx': return 'doctype:excel';
            case 'ppt': case 'pptx': return 'doctype:ppt';
            case 'jpg': case 'jpeg': case 'png': case 'gif': return 'doctype:image';
            case 'txt': return 'doctype:txt';
            case 'zip': case 'rar': return 'doctype:zip';
            default: return 'doctype:unknown';
        }
    }

    // Load Existing documents from Apex
    loadExistingDocuments() {
        try {
            this.isLoading = true;
        
            getDocumentsWithFiles({ stepId: this.stepIds[0] })
                .then(result => {
                
                    if (Array.isArray(result)) {
                        this.paymentProofDocuments = result.map(doc => {
                                               
                            const links = Array.isArray(doc.ContentDocumentLinks) ? doc.ContentDocumentLinks.map(link => ({...link, })) : [];

                            return {
                                documentId: doc.Id,
                                name: doc.Title || doc.Name,
                                iconName: this.getFileIcon(doc.Title || doc.Name),
                                //showUpload: showIcons,
                                ContentDocumentLinks: links,
                                originalDoc: doc // Keep original document data if needed
                            };
                        return undefined;
                    }).filter(doc => doc !== undefined);

                    this.showPaymentProofDocuments = this.paymentProofDocuments.length > 0;
                    this.error = undefined;
                    
                } else {
                    // Handle unexpected response format
                    this.error = 'Unexpected response format from server';
                    this.paymentProofDocuments = [];
                    this.showPaymentProofDocuments = false;
                    console.error('Unexpected response format:', result);
                }
            })
            .catch(error => {
                // Handle promise rejection/error
                const errorMsg = error?.body?.message || error?.message || 'Unknown error occurred while loading documents';
                this.error = errorMsg;
                this.paymentProofDocuments = [];
                this.showPaymentProofDocuments = false;
                console.error('Error loading payment proof documents:', errorMsg, error);
            })
            .finally(() => {
                this.isLoading = false;
            });
            
        } catch (error) {
            // Handle synchronous errors
            console.error('Synchronous error in loadExistingDocuments:', error);
            this.error = error?.message || 'Unexpected error occurred';
            this.paymentProofDocuments = [];
            this.showPaymentProofDocuments = false;
            this.isLoading = false;
        }
    }

    handleUploadFinished(event) {
        const uploadedFiles = event.detail.files;
        this.uploadedFiles = uploadedFiles.map(file => ({
            documentId: file.documentId,
            name: file.name,
            iconName: this.getFileIcon(file.name)
        }));

        this.uploadedFileIds = uploadedFiles.map(file => file.documentId);
        this.hasUploadedFiles = true;
        this.showToast('Success', 'Files uploaded successfully.', 'success');
    }

    handleSupportUploadFinished(event) {
        const uploadedSupportFiles = event.detail.files;
        this.uploadedSupportFiles = uploadedSupportFiles.map(file => ({
            documentId: file.documentId,
            name: file.name,
            iconName: this.getFileIcon(file.name)
        }));

        this.uploadedSuportFileIds = uploadedSupportFiles.map(file => file.documentId);
        this.hasUploadedSupportFiles = true;
        this.showToast('Success', 'Support files uploaded successfully.', 'success');
    }

    //view File
    navigateToFile(event) {
        const contentDocumentId = event.target.dataset.url;
        if (contentDocumentId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__namedPage',
                attributes: {
                    pageName: 'filePreview'
                },
                state: {
                    selectedRecordId: contentDocumentId
                }
            })
        } else {
            console.error('No file URL found');
        }
    }

    // File download 
    handleDownloadPaymentProofFile(event) {
        const fileId = event.currentTarget.dataset.url;
        if (fileId) {
            window.open(`/sfc/servlet.shepherd/document/download/${fileId}`, '_blank');
        } else {
            console.error('No file ID found for download');
            this.showToast('Error', 'Unable to download file. File ID is missing.', 'error');
        }
    }

    handleSubmit() {
        
        let isValid = true;
        if (!this.radioValue || !this.comment) {
            isValid = false;
            return this.showToast('Error', 'Please select an action and enter a comment.', 'error');
        }

        // Validate Approval required fields if shown
        if (this.showBPNNumberField && !this.bpnNumber) {
            isValid = false;
            return this.showToast('Error', 'Please enter BPN Number.', 'error');
        }

        if (this.showTransactionRefField && !this.transactionRefNumber) {
            isValid = false;
            return this.showToast('Error', 'Please enter Transaction Reference Number.', 'error');
        }

        if (this.radioValue === 'Approve' && this.showTransactionRefField && !this.hasUploadedFiles) {
            isValid = false;
            return this.showToast('Error', 'Please upload at least one Treasury Reference Document.', 'error');
        }

        if(this.radioValue === 'Approve' && this.processName === 'Pre Registration' && this.stepName === 'Accounts -Naqoodi transfer'  ){//|| this.stepName === 'Treasury confirmation with Reference Number'
            isValid = false;
            return this.showToast('Error', 'This step cannot be approved from here. Please use the Excel file upload option on the home screen to approve it.', 'error');
        }

        if (this.radioValue === 'Request for more information' && !this.selectedStepId) {
            isValid = false;
            return this.showToast('Error', 'Please select a step to reject to.', 'error');
        }

        if(isValid){
            try {
                this.isLoading = true;

                let additionalFields = {};
                
                // Add additional fields if they exist
                if (this.showBPNNumberField) {
                    additionalFields.BPN_Number__c = this.bpnNumber;
                }
                if (this.showTransactionRefField) {
                    additionalFields.Transaction_Reference_Number__c = this.transactionRefNumber;
                }
                 if (this.stepName==='CM Manager Approval') {
                    additionalFields.CRM_Manager_decision__c = this.selectedDecision;
                }
                
                switch (this.radioValue) {
                   case 'Request for more information':
                     requestForMoreInfoMultipleSteps({
                        bpsIds: this.stepIds,
                        rejectingToBpsId: this.selectedStepId,
                        comment: this.comment
                    })
                    .then(result => {
                        this.isLoading = false;
                        this.dispatchEvent(new CustomEvent('submit'));
                        this.showToast('Success', 'Steps sent back successfully.', 'success');
                        })
                    .catch(error => this.showToast('Error', 'Steps sent back failed.', error));
                    break;

                    case 'Approve':
                    approveStep({
                        bpsIds: this.stepIds,
                        comment: this.comment,
                        additionalFieldsJson: JSON.stringify(additionalFields)
                    })
                    .then(result => {
                        if (this.uploadedFileIds.length > 0 || this.uploadedSuportFileIds.length > 0) {
                            approveFileIds({
                                bpsIds: this.stepIds,
                                fileIds:this.uploadedFileIds,
                                supportDocumentFileIds:this.uploadedSuportFileIds 
                            });
                        }
                        
                        this.dispatchEvent(new CustomEvent('submit'));
                        this.showToast('Success', 'Approved successfully.', 'success');
                        
                        })
                    .catch(error => this.showToast('Error', 'Fetching steps failed.', error));
                    break;

                    case 'Reject':
                        rejectStep({
                            bpsIds: this.stepIds,
                            comment: this.comment
                        })
                    .then(result => {
                            this.isLoading = false;
                            this.dispatchEvent(new CustomEvent('submit'));
                            this.showToast('Success', 'Rejected successfully.', 'success');
                        })
                    .catch(error => this.showToast('Error', 'Fetching steps failed.', error));
                    break;
                }
            } catch (error) {
                this.showToast('Error', error?.body?.message || 'Action failed.', 'error');
            } finally {
                this.isLoading = false;
            }
        }
    }

    showToast(title, message, variant = 'info') {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    handleCancel() {
        //this.closeModal();
        this.dispatchEvent(new CustomEvent('close'));
    }

    /*closeModal() {
        //this.isOpen = false;
        t
    }*/

    /*showToast(title, message, variant = 'info') {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }*/
}