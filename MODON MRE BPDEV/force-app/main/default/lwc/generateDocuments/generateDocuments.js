import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex'; 

import getDocuments from '@salesforce/apex/BusinessProcessNintexDocumentGeneration.getDocuments';
import startDocumentGeneration from '@salesforce/apex/BusinessProcessNintexDocumentGeneration.startDocumentGeneration';

const REFRESH_INTERVAL_MS = 8000; 

export default class GenerateDocuments extends LightningElement {
    @api recordId;

    documents = [];
    hasDocuments = false;
    isLoading = false;
    
    wiredDocumentsResult;

    showConfirmModal = false;
    showSuccessMessage = false;
    successMessage = '';

    selectedDocId = null;
    selectedDocName = '';

    @wire(getDocuments, { businessProcessId: '$recordId' })
    wiredDocuments(result) {
        this.wiredDocumentsResult = result; 
        
        const { error, data } = result;

        if (data) {
            this.documents = data;
            this.hasDocuments = data.length > 0;
        } else if (error) {
            console.error('Error fetching documents:', error);
            this.documents = [];
            this.hasDocuments = false;
        }
    }

    get showDocuments() {
        return this.hasDocuments && !this.isLoading && !this.showSuccessMessage;
    }

    get showNoDocuments() {
        return !this.hasDocuments && !this.isLoading && !this.showSuccessMessage;
    }

    handleGenerateClick(event) {
        this.selectedDocId = event.currentTarget.dataset.id;
        this.selectedDocName = event.currentTarget.dataset.name;
        this.showConfirmModal = true;
    }

    handleCancel() {
        this.showConfirmModal = false;
        this.selectedDocId = null;
        this.selectedDocName = '';
    }

    handleConfirmGenerate() {
        this.showConfirmModal = false;
        this.isLoading = true;
        this.startGenerationProcess(this.selectedDocId, this.selectedDocName);
    }

    startGenerationProcess(docId, docName) {
        startDocumentGeneration({ processFlowDocumentId: docId, businessProcessId: this.recordId })
            .then(() => {
                this.showSuccessMessage = true;
                this.successMessage = `The document "${docName}" is being generated and will be attached soon.`;
                
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Generation Started',
                        message: `Document "${docName}" generation has started.`,
                        variant: 'success'
                    })
                );
                
              
                window.setTimeout(() => {
                    this.handleAutoRefresh();
                }, REFRESH_INTERVAL_MS);

            })
            .catch(error => {
                const message = error?.body?.message || error.message || 'An unknown error occurred.';
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Generation Failed',
                        message,
                        variant: 'error'
                    })
                );
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleAutoRefresh() {
        this.showSuccessMessage = false;
        this.successMessage = '';
        
        if (this.wiredDocumentsResult) {
            this.isLoading = true;
            refreshApex(this.wiredDocumentsResult)
                .finally(() => {
                    this.isLoading = false;
                });
        }
    }

    handleBackToList() {
        this.handleAutoRefresh(); 
    }
}