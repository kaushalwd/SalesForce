import { LightningElement, api, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// Apex Methods
import getCommentsByStep from '@salesforce/apex/ReviewerCommentController.getCommentsByStep';
import deleteCommentWithFiles from '@salesforce/apex/ReviewerCommentController.deleteCommentWithFiles';
import updateReviewerComment from '@salesforce/apex/ReviewerCommentController.updateReviewerComment';
import getActionedToOptions from '@salesforce/apex/ReviewerCommentController.getActionedToOptions';
import getRemarkOptions from '@salesforce/apex/ReviewerCommentController.getRemarkOptions';
import getDesignDocumentPlaceholder from '@salesforce/apex/ReviewerCommentController.getDesignDocumentPlaceholder';
import createReviewerComments from '@salesforce/apex/ReviewerCommentController.createReviewerComments';

let rowIdCounter = 0;

export default class ReviewerCommentsTable extends NavigationMixin(LightningElement) {
    @api stepId;
    @api bpId;
    
    // Existing Comments Properties
    @track existingComments = [];
    wiredCommentsResult;
    isAnyRowEditing = false;

    // New Comments Properties
    @track commentRows = [{ id: rowIdCounter++, notes: '', actionedTo: '', files: [], remarks: '', reviewStatus: '' }];
    @track actionedToOptions = [];
    @track reviewStatusOptions = [
        { label: 'Approve', value: 'Approve' },
        { label: 'Rejected', value: 'Rejected' },
        { label: 'Approved with noted', value: 'Approved with noted' },
        { label: 'Re submit', value: 'Re submit' }
    ];
    @track placeholderRecordId;
    @track remarkOptions;

    // Computed Properties
    get hasExistingComments() {
        return this.existingComments && this.existingComments.length > 0;
    }

    // Getter that processes file details for existing comments
    get existingCommentsWithFiles() {
        return this.existingComments.map(comment => {
            // Only show files that are not marked for removal and are not pending uploads
            let processedFileDetails = [];
            
            if (comment.fileDetails && comment.fileDetails.length > 0) {
                processedFileDetails = comment.fileDetails.filter(file => 
                    !comment.filesToRemove?.includes(file.documentId)
                );
            } else if (comment.fileIds && comment.fileIds.length > 0) {
                processedFileDetails = comment.fileIds
                    .filter(fileId => !comment.filesToRemove?.includes(fileId))
                    .map(fileId => ({
                        documentId: fileId,
                        name: 'File'
                    }));
            }
            
            return {
                ...comment,
                processedFileDetails: processedFileDetails
            };
        });
    }

    // Wire methods for existing comments
    @wire(getCommentsByStep, { stepId: '$stepId' })
    wiredComments(result) {
        this.wiredCommentsResult = result;
        const { data, error } = result;
        if (data) {
            this.existingComments = data.map(row => ({
                ...row,
                fileDisabled: !(row.fileIds && row.fileIds.length > 0),
                firstFileId: row.fileIds?.[0] || null,
                isEditing: false,
                editableNotes: row.notes,
                editableActionedTo: row.actionedTo,
                editableRemarks: row.remarks,
                editableReviewStatus: row.reviewStatus,
                fileDetails: this.processFileIdsToDetails(row.fileIds),
                originalFileDetails: this.processFileIdsToDetails(row.fileIds), // Store original files for cancellation
                newFiles: [], // For tracking newly uploaded files during edit
                filesToRemove: [], // For tracking files to remove during edit
                pendingUploads: [] // NEW: Track files uploaded during current edit session
            }));
        } else if (error) {
            console.error('Error fetching existing comments:', error);
            this.showToast('Error', 'Failed to load existing comments', 'error');
        }
    }

    // Helper method to convert fileIds to fileDetails
    processFileIdsToDetails(fileIds) {
        if (!fileIds || fileIds.length === 0) {
            return [];
        }
        return fileIds.map(fileId => ({
            documentId: fileId,
            name: 'File'
        }));
    }

    // Wire methods for dropdown options
    @wire(getActionedToOptions)
    wiredActionedToOptions({ error, data }) {
        if (data) {
            this.actionedToOptions = data.map(label => ({ label: label, value: label }));
        } else if (error) {
            console.error('Error fetching actioned to options:', error);
        }
    }

    @wire(getRemarkOptions, { stepId: "$stepId" })
    wiredRemarkOptions({ error, data }) {
        if (data) {
            this.remarkOptions = data.map(label => ({ label: label, value: label }));
        } else if (error) {
            console.error('Error fetching remark options:', error);
        }
    }

    connectedCallback() {
        if (this.stepId) {
            getDesignDocumentPlaceholder({ stepId: this.stepId })
                .then(result => {
                    this.placeholderRecordId = result;
                })
                .catch(error => {
                    console.error('Error fetching placeholder record:', error);
                });
        }
    }

    updateEditingState() {
        this.isAnyRowEditing = this.existingComments.some(comment => comment.isEditing);
    }

    // Existing Comments Edit Methods
    handleEditExistingComment(event) {
        // If any row is already being edited, prevent editing another one
        if (this.isAnyRowEditing) {
            this.showToast('Info', 'Please finish editing the current row before editing another one.', 'info');
            return;
        }

        const commentId = event.currentTarget.dataset.id;
        this.existingComments = this.existingComments.map(comment => 
            comment.commentId === commentId 
                ? { 
                    ...comment, 
                    isEditing: true,
                    // Initialize editable fields with current values if not set
                    editableNotes: comment.editableNotes || comment.notes,
                    editableActionedTo: comment.editableActionedTo || comment.actionedTo,
                    editableRemarks: comment.editableRemarks || comment.remarks,
                    editableReviewStatus: comment.editableReviewStatus || comment.reviewStatus,
                    // Store original state for cancellation
                    originalFileDetails: [...comment.fileDetails],
                    pendingUploads: [] // Reset pending uploads when starting edit
                }
                : comment
        );
        
        this.updateEditingState();
    }

    handleCancelEdit(event) {
        const commentId = event.currentTarget.dataset.id;
        this.existingComments = this.existingComments.map(comment => {
            if (comment.commentId === commentId) {
                // Reset to original state - this will remove any pending uploads
                return {
                    ...comment,
                    isEditing: false,
                    editableNotes: comment.notes,
                    editableActionedTo: comment.actionedTo,
                    editableRemarks: comment.remarks,
                    editableReviewStatus: comment.reviewStatus,
                    fileDetails: [...comment.originalFileDetails], // Restore original files
                    newFiles: [],
                    filesToRemove: [],
                    pendingUploads: [] // Clear pending uploads
                };
            }
            return comment;
        });
        
        this.updateEditingState();
        //this.showToast('Info', 'Edit cancelled. Any uploaded files during this session have been removed.', 'info');
    }

    handleExistingNotesChange(event) {
        const commentId = event.target.dataset.id;
        const value = event.target.value;
        this.existingComments = this.existingComments.map(comment =>
            comment.commentId === commentId 
                ? { ...comment, editableNotes: value }
                : comment
        );
    }

    handleExistingActionedToChange(event) {
        const commentId = event.target.dataset.id;
        const value = event.detail.value;
        this.existingComments = this.existingComments.map(comment =>
            comment.commentId === commentId 
                ? { ...comment, editableActionedTo: value }
                : comment
        );
    }

    handleExistingRemarkChange(event) {
        const commentId = event.target.dataset.id;
        const value = event.detail.value;
        this.existingComments = this.existingComments.map(comment =>
            comment.commentId === commentId 
                ? { ...comment, editableRemarks: value }
                : comment
        );
    }

    handleExistingReviewStatusChange(event) {
        const commentId = event.target.dataset.id;
        const value = event.detail.value;
        this.existingComments = this.existingComments.map(comment =>
            comment.commentId === commentId 
                ? { ...comment, editableReviewStatus: value }
                : comment
        );
    }

    handleExistingFileUpload(event) {
        const commentId = event.target.dataset.id;
        const uploadedFiles = event.detail.files;
        
        const fileDetails = uploadedFiles.map(file => ({
            documentId: file.documentId,
            name: file.name
        }));

        const fileIds = uploadedFiles.map(file => file.documentId);
        
        this.existingComments = this.existingComments.map(comment => {
            if (comment.commentId === commentId) {
                const currentFiles = comment.fileDetails || [];
                const currentFileIds = comment.fileIds || [];
                return {
                    ...comment,
                    fileDetails: [...currentFiles, ...fileDetails],
                    fileIds: [...currentFileIds, ...fileIds],
                    newFiles: [...(comment.newFiles || []), ...fileIds],
                    pendingUploads: [...(comment.pendingUploads || []), ...fileIds] // Track as pending
                };
            }
            return comment;
        });

        this.showToast('Success', 'Files uploaded successfully. Remember to save to keep changes.', 'success');
    }

    async handleSaveExistingComment(event) {
        const commentId = event.currentTarget.dataset.id;
        const comment = this.existingComments.find(c => c.commentId === commentId);
        
        if (!comment) return;

        // Validate required fields
        if (!comment.editableNotes || comment.editableNotes.trim() === '') {
            this.showToast('Validation Error', 'Notes/Comments is required', 'error');
            return;
        }

        try {
            // Ensure arrays are properly typed and not undefined
            const newFileIds = Array.isArray(comment.newFiles) ? comment.newFiles : [];
            const filesToRemove = Array.isArray(comment.filesToRemove) ? comment.filesToRemove : [];

            const payload = {
                commentId: comment.commentId,
                notes: comment.editableNotes,
                actionedTo: comment.editableActionedTo,
                remarks: comment.editableRemarks,
                reviewStatus: comment.editableReviewStatus,
                newFileIds: newFileIds,
                filesToRemove: filesToRemove
            };

            
            await updateReviewerComment({ commentData: JSON.stringify(payload) });
            
            // Update the comment with new values and exit edit mode
            this.existingComments = this.existingComments.map(c => 
                c.commentId === commentId 
                    ? {
                        ...c,
                        isEditing: false,
                        notes: c.editableNotes,
                        actionedTo: c.editableActionedTo,
                        remarks: c.editableRemarks,
                        reviewStatus: c.editableReviewStatus,
                        // Update original file details to include newly saved files
                        originalFileDetails: c.fileDetails,
                        newFiles: [],
                        filesToRemove: [],
                        pendingUploads: [] // Clear pending uploads after successful save
                    }
                    : c
            );

            this.showToast('Success', 'Comment updated successfully.', 'success');
            await this.refreshExistingComments();
            
        } catch (error) {
            console.error('Error updating comment:', error);
            this.showToast('Error', 'Failed to update comment: ' + error.body?.message || error.message, 'error');
        } finally {
            this.updateEditingState();
        }
    }

    async handleDeleteExistingComment(event) {
        // If any row is being edited, prevent deletion
        if (this.isAnyRowEditing) {
            this.showToast('Info', 'Please finish editing the current row before deleting another comment.', 'info');
            return;
        }

        const commentId = event.currentTarget.dataset.id;
        const comment = this.existingComments.find(c => c.commentId === commentId);
        
        if (!comment) return;

        if (!confirm('Are you sure you want to delete this comment?')) {
            return;
        }

        try {
            await deleteCommentWithFiles({ commentId: commentId });
            this.showToast('Success', 'Comment and associated files deleted successfully', 'success');
            await this.refreshExistingComments();
        } catch (error) {
            console.error('Error deleting existing comment:', error);
            this.showToast('Error', 'Failed to delete comment: ' + error.body?.message || error.message, 'error');
        }
    }

    async refreshExistingComments() {
        try {
            if (this.wiredCommentsResult) {
                await refreshApex(this.wiredCommentsResult);
            }
        } catch (error) {
            console.error('Error refreshing existing comments:', error);
        }
    }

    // New Comments Methods (unchanged)
    addRow() {
        this.commentRows = [...this.commentRows, { 
            id: rowIdCounter++, 
            notes: '', 
            actionedTo: '', 
            files: [], 
            remarks: '', 
            reviewStatus: '',
            fileDetails: []
        }];
    }

    handleNotesChange(event) {
        const id = parseInt(event.target.dataset.id);
        this.commentRows = this.commentRows.map(row =>
            row.id === id ? { ...row, notes: event.target.value } : row
        );
    }

    handleActionedToChange(event) {
        const id = parseInt(event.target.dataset.id);
        const selectedValue = event.detail.value;
        this.commentRows = this.commentRows.map(row =>
            row.id === id ? { ...row, actionedTo: selectedValue } : row
        );
    }

    handleRemarkChange(event) {
        const id = parseInt(event.target.dataset.id);
        const selectedValue = event.detail.value;
        this.commentRows = this.commentRows.map(row =>
            row.id === id ? { ...row, remarks: selectedValue } : row
        );
    }

    handlereviewStatusChange(event) {
        const id = parseInt(event.target.dataset.id);
        const selectedValue = event.detail.value;
        this.commentRows = this.commentRows.map(row =>
            row.id === id ? { ...row, reviewStatus: selectedValue } : row
        );
    }

    handleFileUpload(event) {
        const id = parseInt(event.target.dataset.id);
        const uploadedFiles = event.detail.files;
        
        const fileDetails = uploadedFiles.map(file => ({
            documentId: file.documentId,
            name: file.name
        }));

        const fileIds = uploadedFiles.map(file => file.documentId);
        
        this.commentRows = this.commentRows.map(row =>
            row.id === id ? { 
                ...row, 
                files: fileIds,
                fileDetails: fileDetails 
            } : row
        );

        this.showToast('Success', 'Files uploaded successfully.', 'success');
    }

    navigateToFile(event) {
        const contentDocumentId = event.currentTarget.dataset.id;
        if (contentDocumentId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__namedPage',
                attributes: {
                    pageName: 'filePreview'
                },
                state: {
                    selectedRecordId: contentDocumentId
                }
            });
        } else {
            console.error('No file ID found');
            this.showToast('Error', 'Unable to preview file. File ID is missing.', 'error');
        }
    }

    deleteRow(event) {
        const id = parseInt(event.target.dataset.id);
        if (this.commentRows.length === 1) {
            this.showToast('Warning', 'At least one comment row must remain.', 'warning');
            return;
        }
        this.commentRows = this.commentRows.filter(row => row.id !== id);
    }

    validateForm() {
        let isValid = true;
        const errors = [];

        this.commentRows.forEach((row, index) => {
            if (!row.notes || row.notes.trim() === '') {
                isValid = false;
                errors.push(`Notes/Comments is required for row ${index + 1}`);
            }
        });

        if (!isValid) {
            this.showToast('Validation Error', errors.join('\n'), 'error');
        }

        return isValid;
    }

    async handleSave() {
        try {
            if (!this.validateForm()) {
                return;
            }

            const payload = this.commentRows.map(row => ({
                notes: row.notes,
                actionedTo: row.actionedTo,
                fileIds: row.files,
                stepId: this.stepId,
                bpId: this.bpId,
                remarks: row.remarks,
                reviewStatus: row.reviewStatus
            }));

            const result = await createReviewerComments({ comments: payload });
        
            this.clearForm();
            await this.refreshExistingComments();
        
            this.dispatchEvent(
                new CustomEvent('commentsaved', { 
                    bubbles: true, 
                    composed: true,
                    detail: { 
                        stepId: this.stepId,
                        success: true,
                    }
                })
            );

            this.showToast('Success', 'Reviewer comments saved successfully.', 'success');

        } catch (error) {
            console.error(error);
            this.showToast('Error saving comments', error.body?.message || error.message, 'error');
        }
    }

    clearForm() {
        this.commentRows = [{ 
            id: rowIdCounter++, 
            notes: '', 
            actionedTo: '', 
            files: [], 
            remarks: '', 
            reviewStatus: '',
            fileDetails: []
        }];
    }

    // Utility Methods
    showToast(title, message, variant = 'info') {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}