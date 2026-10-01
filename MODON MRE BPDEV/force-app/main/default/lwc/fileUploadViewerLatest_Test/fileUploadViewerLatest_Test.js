import { LightningElement, api, wire, track } from 'lwc';
import fileUploadCompController from '@salesforce/apex/fileUploadCompController.getDocumentsWithFiles';
import { refreshApex } from '@salesforce/apex';
import USER_ID from '@salesforce/user/Id';
import { NavigationMixin } from 'lightning/navigation';

export default class FileUploadViewerLatest_Test extends NavigationMixin(LightningElement) {

    @api recordId;
    @api stepId;

    @track documents = [];
    @track validationError;

    isUploadModalOpen = false;
    selectedDocId;

    userId = USER_ID;
    wiredResult;

    @wire(fileUploadCompController, { businessProcessId: '$recordId' })
    wiredDocs(result) {
        this.wiredResult = result;

        if (result.data) {
            this.processDocuments(result.data);
        }
    }

    processDocuments(data) {
        this.documents = data.map(doc => {

            const files = (doc.files || []).map(file => ({
                fileName: file.fileName,
                formattedDate: this.formatDate(file.createdDate),
                ContentDocumentId: file.contentDocumentId,
                uploadedBy: file.uploadedBy
            }));

            return {
                ...doc,
                files,

                requiredClass: doc.isRequired ? 'required' : 'optional',
                missingClass: doc.isRequired && files.length === 0 ? 'missing' : '',
                isShowAutoGen : doc.isShowUpload,
                isCompleted: files.length > 0,
                completedClass: files.length > 0 ? 'completed' : '',
                showUpload: true,
                isExpanded: false,
                iconChevron: 'utility:chevronright'
            };
        });
    }

    formatDate(dateString) {
        return new Date(dateString).toLocaleString();
    }

    handleExpandClick(event) {
        const id = event.currentTarget.dataset.id;

        this.documents = this.documents.map(doc => {
            if (doc.docId === id) {
                const expanded = !doc.isExpanded;
                return {
                    ...doc,
                    isExpanded: expanded,
                    iconChevron: expanded ? 'utility:chevrondown' : 'utility:chevronright'
                };
            }
            return doc;
        });
    }

    handleUploadClick(event) {
        this.selectedDocId = event.target.dataset.id;
        this.isUploadModalOpen = true;
    }

    closeUploadModal() {
        this.isUploadModalOpen = false;
    }

    handleUploadFinished() {
        this.isUploadModalOpen = false;

        if (this.wiredResult) {
            refreshApex(this.wiredResult);
        }
    }

    navigateToFile(event) {
        const fileId = event.target.dataset.fileId;

        this[NavigationMixin.Navigate]({
            type: 'standard__namedPage',
            attributes: { pageName: 'filePreview' },
            state: { selectedRecordId: fileId }
        });
    }

    @api
    validateStepDocuments() {
        const missingDocs = this.documents.filter(
            d => d.isRequired && d.files.length === 0
        );

        if (missingDocs.length) {
            const names = missingDocs.map(d => d.Name).join(', ');
            this.validationError = `Please upload: ${names}`;
            return { isValid: false };
        }

        this.validationError = null;
        return { isValid: true };
    }
}