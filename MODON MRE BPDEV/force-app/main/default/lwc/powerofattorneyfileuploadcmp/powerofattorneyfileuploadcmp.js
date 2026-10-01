import { LightningElement,track,api } from 'lwc';
import uploadFile from '@salesforce/apex/CustomerKYCHandler.handlePOAFile';

export default class Powerofattorneyfileuploadcmp extends LightningElement {

        @track fileName = '';
        @track fileData;
        @track isLoading = false;
        @track message = '';
        @api accountId = null;
        get isUploadDisabled() {
            return !this.fileData;
        }
    
        handleFileChange(event) {
            this.message = '';
            const file = event.target.files[0];
            if (!file) {
                this.fileName = '';
                this.fileData = null;
                return;
            }
    
            const allowedTypes = ['image/jpeg', 'image/png', 'application/pdf', 'image/jpg'];
            if (!allowedTypes.includes(file.type)) {
                this.message = 'Invalid file type. Please upload a PDF, PNG, or JPG file.';
                this.fileName = '';
                this.fileData = null;
                return;
            }
    
            this.fileName = file.name;
            this.isLoading = true;
    
            const reader = new FileReader();
            reader.onload = () => {
                const base64 = reader.result.split(',')[1];
                this.fileData = base64;
                this.isLoading = false;
            };
            reader.readAsDataURL(file);
        }
        handleUploadConfirmation(){
            const userConfirmed = window.confirm('Are you sure you want to upload this file?');
            if (userConfirmed) {
                this.handleUpload();
            }
       }
        handleUpload() {
            this.isLoading = true;
            this.message = '';
    
            uploadFile({
                base64: this.fileData,
                contactEncryptId: this.accountId,
                fileName: this.fileName
            })
            .then(result => {
                if (result === 'Success') {
                    this.message = 'File uploaded successfully!';
                    this.fileName = '';
                    this.fileData = null;
                    this.fireCustomEvent('success', 'File uploaded successfully.');
    
                } else {
                    console.error('Error uploading file:', result);
                    this.message = 'Error! Contact Support Team!'; // Display the error message from Apex
                    this.fireCustomEvent('error', result);
                }
            })
            .catch(error => {
                console.error('Error uploading file:', error);
                this.message = 'An unexpected error occurred during the upload.';
                this.fireCustomEvent('error', 'An unexpected error occurred during the upload.');
            })
            .finally(() => {
                this.isLoading = false;
            });
        }
        fireCustomEvent(status, message) {
            const detail = {
                status: status,
                message: message
            };
            const customEvent = new CustomEvent('uploadpoaevent', {
                detail: detail,
                bubbles: true,
                composed: true
            });
            this.dispatchEvent(customEvent);
        }
}