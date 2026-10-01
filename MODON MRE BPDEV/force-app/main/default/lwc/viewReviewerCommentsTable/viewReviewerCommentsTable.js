import { LightningElement, api, wire, track } from 'lwc';
import getCommentsByStep from '@salesforce/apex/ReviewerCommentViewerController.getCommentsByStep';
import deleteCommentWithFiles from '@salesforce/apex/ReviewerCommentViewerController.deleteCommentWithFiles';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const COLUMNS = [
    {label: 'Remarks', fieldName: 'remarks'},
    { label: 'Notes/Comments', fieldName: 'notes' },
    { label: 'Actioned To', fieldName: 'actionedTo' },
    {label: 'Review Status', fieldName: 'reviewStatus'},
    {
        label: 'Files',
        type: 'button',
        typeAttributes: {
            label: 'View File',
            name: 'view_file',
            variant: 'brand',
            disabled: { fieldName: 'fileDisabled' }
        }
    },
    {
        type: 'action',
        typeAttributes: {
            rowActions: [
                { label: 'Delete', name: 'delete' }
            ],
            menuAlignment: 'right'
        }
    }
];

export default class ViewReviewerCommentsTable extends NavigationMixin(LightningElement) {
    @api stepId;
    @track rows = [];
    columns = COLUMNS;
    wiredCommentsResult;

    get hasComments() {
        return this.rows && this.rows.length > 0;
    }   

    @wire(getCommentsByStep, { stepId: '$stepId' })
    wiredComments(result) {
        this.wiredCommentsResult = result;
        const { data, error } = result;
        if (data) {
            this.rows = data.map(row => ({
                ...row,
                fileDisabled: !(row.fileIds && row.fileIds.length > 0),
                firstFileId: row.fileIds?.[0] || null
            }));
        } else if (error) {
            console.error('Error fetching comments:', error);
            this.showToast('Error', 'Failed to load comments', 'error');
        }
    }

    connectedCallback() {
    }

    @api
    async refreshComments() {
        try {
            if (this.wiredCommentsResult) {
                await refreshApex(this.wiredCommentsResult);
            }
        } catch (error) {
            console.error('Error refreshing comments:', error);
        }
    }

    handleRowAction(event) {
        const { action, row } = event.detail;

        if (action.name === 'view_file' && row.firstFileId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__namedPage',
                attributes: { pageName: 'filePreview' },
                state: { selectedRecordId: row.firstFileId }
            });
        } else if (action.name === 'delete') {
            this.handleDeleteComment(row);
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    async handleDeleteComment(row) {
        
        if (!confirm('Are you sure you want to delete this comment.')) {
            return;
        }

        try {
            this.isLoading = true;
            await deleteCommentWithFiles({ commentId: row.commentId });
            this.showToast('Success', 'Comment and associated files deleted successfully', 'success');
            await this.refreshComments();
        } catch (error) {
            console.error('Error deleting comment:', error);
            this.showToast('Error', 'Failed to delete comment: ' + error.body?.message || error.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }
}