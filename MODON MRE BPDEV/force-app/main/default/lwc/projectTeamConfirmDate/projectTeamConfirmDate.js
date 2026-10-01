import { LightningElement, api, track, wire } from 'lwc';
import getProcessData from '@salesforce/apex/ApprovalModalController.getProcessData';
import getDocuments from '@salesforce/apex/ApprovalModalController.getDocuments';
import getFiles from '@salesforce/apex/ApprovalModalController.getFiles';
import deleteFile from '@salesforce/apex/ApprovalModalController.deleteFile';
import getUnitCountForMilestone from '@salesforce/apex/MilestoneInstallmentsSummaryFromBp.getUnitCountForMilestone';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';

export default class ProjectTeamConfirmDate extends NavigationMixin(LightningElement) {

    @api recordId;

    // 🔹 Radio state
    selectedOption;

    // 🔹 Dates
    confirmationDueDate;
    confirmationDate;
    extensionDate;

    // 🔹 Documents
    @track documents = [];
    wiredDocsResult;

    // 🔹 Number of Units in the Milestone's Phase
    unitCount = 0;

    get hasSummary() {
        return this.unitCount > 0;
    }

    // 🔹 Radio Options
    radioOptions = [
        { label: 'Confirmation', value: 'CONFIRMATION' },
        { label: 'Extension', value: 'EXTENSION' }
    ];

    // 🔹 Derived UI states
    get isConfirmation() {
        return this.selectedOption === 'CONFIRMATION';
    }

    get isExtension() {
        return this.selectedOption === 'EXTENSION';
    }

    // 🔹 Extension Date must be strictly after the Milestone Date
    get minExtensionDate() {

        if (!this.confirmationDueDate) {
            return null;
        }

        const due = new Date(this.confirmationDueDate + 'T00:00:00Z');
        due.setUTCDate(due.getUTCDate() + 1);
        return due.toISOString().slice(0, 10);
    }

    // 🔹 No. of Days = Extension Date - Milestone Date
    get extensionDaysDiff() {

        if (!this.extensionDate || !this.confirmationDueDate) {
            return null;
        }

        const msPerDay = 24 * 60 * 60 * 1000;
        const ext = new Date(this.extensionDate + 'T00:00:00Z');
        const due = new Date(this.confirmationDueDate + 'T00:00:00Z');

        return Math.round((ext.getTime() - due.getTime()) / msPerDay);
    }

    get hasExtensionDaysDiff() {
        return this.extensionDaysDiff !== null;
    }

    // 🔹 Load Process Data
    @wire(getProcessData, { recordId: '$recordId' })
    wiredProcess({ data }) {
        if (data) {
            this.confirmationDueDate = data.Milestone__r?.Milestone_Due_Date__c;
            this.extensionDate = data.MileStone_Extension_Date__c;
            this.confirmationDate = data.Confirmation_Date__c == null ? this.confirmationDueDate : data.Confirmation_Date__c;

            // default selection based on data
            this.selectedOption = this.confirmationDate
                ? 'CONFIRMATION' : this.extensionDate ?
                    'EXTENSION' : 'CONFIRMATION';

            this.sendDataToParent();
            this.loadUnitCount();
        }
    }

    // 🔹 Load Number of Units in the Milestone's Phase
    async loadUnitCount() {

        if (!this.recordId) {
            return;
        }

        try {
            this.unitCount = await getUnitCountForMilestone({ businessProcessId: this.recordId }) || 0;
        } catch (error) {
            console.error('Error loading unit count:', error);
            this.unitCount = 0;
        }
    }

    // 🔹 Load Documents + Files
    @wire(getDocuments, { processId: '$recordId' })
    wiredDocs(result) {
        this.wiredDocsResult = result;

        if (result.data) {

            let docs = result.data.map(d => ({
                ...d,
                isExtension: d.Name === 'Extension Memo',
                isCertificate: d.Name === 'Milestone confirmation Certificate',
                files: [],
                hasFiles: false
            }));

            const ids = docs.map(d => d.Id);

            if (ids.length) {

                getFiles({ docIds: ids })
                    .then(files => {

                        files.forEach(f => {

                            const doc = docs.find(d => d.Id === f.LinkedEntityId);

                            if (doc) {
                                doc.files.push({
                                    Id: f.ContentDocumentId,
                                    Title: f.ContentDocument.Title
                                });
                            }
                        });

                        docs.forEach(d => {
                            d.hasFiles = d.files.length > 0;
                        });

                        this.documents = [...docs];
                    });
            } else {
                this.documents = [...docs];
            }
        }
    }

    // 🔹 Radio change
    handleRadioChange(event) {
        this.selectedOption = event.target.value;

        if (this.selectedOption === 'CONFIRMATION') {
            this.confirmationDate = this.confirmationDueDate;
        } else {
            this.confirmationDate = null;
        }

        this.sendDataToParent();
    }

    // 🔹 Extension date
    handleExtensionDate(event) {
        this.extensionDate = event.target.value;

        event.target.reportValidity();

        this.sendDataToParent();
    }

    // 🔹 Upload refresh
    handleUpload() {

    refreshApex(this.wiredDocsResult)
        .then(() => {

            if (this.wiredDocsResult.data) {

                let docs = this.wiredDocsResult.data.map(d => ({
                    ...d,
                    isExtension: d.Name === 'Extension Memo',
                    isCertificate: d.Name === 'Milestone confirmation Certificate',
                    files: [],
                    hasFiles: false
                }));

                const ids = docs.map(d => d.Id);

                return getFiles({ docIds: ids })
                    .then(files => {

                        files.forEach(f => {

                            const doc = docs.find(
                                d => d.Id === f.LinkedEntityId
                            );

                            if (doc) {

                                doc.files.push({
                                    Id: f.ContentDocumentId,
                                    Title: f.ContentDocument.Title
                                });
                            }
                        });

                        docs.forEach(d => {
                            d.hasFiles = d.files.length > 0;
                        });

                        this.documents = [...docs];
                    });
            }
        });
}
    // 🔹 Preview file
    handlePreview(event) {
        const fileId = event.currentTarget.dataset.id;

        this[NavigationMixin.Navigate]({
            type: 'standard__namedPage',
            attributes: {
                pageName: 'filePreview'
            },
            state: {
                selectedRecordId: fileId
            }
        });
    }

    // 🔹 Delete file
    // 🔹 Delete file
    handleDelete(event) {

        const fileId = event.currentTarget.dataset.id;

        deleteFile({ contentDocumentId: fileId })
            .then(() => {

                // Remove file locally from UI
                this.documents = this.documents.map(doc => {

                    const updatedFiles = doc.files.filter(
                        file => file.Id !== fileId
                    );

                    return {
                        ...doc,
                        files: updatedFiles,
                        hasFiles: updatedFiles.length > 0
                    };
                });

                // Refresh server data also
                return refreshApex(this.wiredDocsResult);
            })
            .catch(error => {
                console.error('Delete Error', error);
            });
    }

    // 🔹 Send data to parent
    sendDataToParent() {
        this.dispatchEvent(new CustomEvent('datapayload', {
            detail: {
                selectedOption: this.selectedOption,
                confirmationDate: this.confirmationDate,
                extensionDate: this.extensionDate
            }
        }));
    }
}