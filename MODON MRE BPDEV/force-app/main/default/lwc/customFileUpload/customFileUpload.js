import { LightningElement, track } from 'lwc';
import fetchReceiptStatuses from '@salesforce/apex/fetchPaymentsStatus.fetchReceiptStatuses';
import uploadRecords from '@salesforce/apex/fetchPaymentsStatus.uploadRecords';
import sampleCSVFile from '@salesforce/resourceUrl/sampleCSVFile';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';


export default class CustomFileUpload extends LightningElement {
    @track dataPreview = [];
    @track isLoading = false;
    @track fileName = '';
    @track unmatchedCount = 0;


    columns = [
        { label: 'Project Name', fieldName: 'Project Name' },
        { label: 'Sales Order: Unit: Unit Name', fieldName: 'Sales Order: Unit: Unit Name' },
        { label: 'Sales Order: Sales Order Name', fieldName: 'Sales Order: Sales Order Name' },
        { label: 'Sales Order: Client Name', fieldName: 'Sales Order: Client Name' },
        { label: 'Receipt No', fieldName: 'Receipt No' },
        { label: 'Current Status', fieldName: 'OldStatus' },
        { label: 'New Status from Excel', fieldName: 'Status' },
        { label: 'Current EBS Clearing Date', fieldName: 'currentEBSClearingDate' },
        { label: 'New EBS Clearing Date from Excel', fieldName: 'EBS Clearing Date' },
        { label: 'Total Amount', fieldName: 'totalamount' },
    ];

    fileContents;

    get isEmpty() {
        return this.dataPreview.length === 0;
    }

    handleFileChange(event) {
        const file = event.target.files[0];
        if (!file) {
            console.error('No file selected.');
            return;
        }
        this.fileName = file.name;
        this.isLoading = true;

        const reader = new FileReader();
        reader.onload = () => {
            const text = reader.result;
            this.fileContents = text;
            this.dataPreview = this.parseCSV(text);
            this.mapReceiptStatuses(); // Fetch Salesforce data and merge
        };
        reader.onerror = () => {
            console.error('Error reading file', reader.error);
            this.isLoading = false;
        };
        reader.readAsText(file);
    }

    parseCSV(csv) {
        const lines = csv.split(/\r?\n/).map(line => line.trim()).filter(line => line.length > 0);
        if (lines.length === 0) {
            console.error('CSV is empty or invalid.');
            return [];
        }

        const allowedFields = this.columns.map(col => col.fieldName);
        let headerIndex = -1;
        let headers = [];

        // Step 1: Find the correct header line
        for (let i = 0; i < lines.length; i++) {
            const potentialHeader = lines[i].split(',').map(h => h.trim());
            const validMatchCount = potentialHeader.filter(header => allowedFields.includes(header)).length;

            // Assume this is a header if it contains at least two matching fields
            if (validMatchCount >= 2) {
                headerIndex = i;
                headers = potentialHeader;
                break;
            }
        }

        if (headerIndex === -1) {
            console.error('No valid header found in CSV.');
            return [];
        }

        // Step 2: Process rows after the header
        const records = [];
        for (let i = headerIndex + 1; i < lines.length; i++) {
            const values = lines[i].split(',').map(v => v.trim());
            if (values.length === 0 || values.every(v => v === '')) continue;

            let record = { id: (i - headerIndex - 1).toString() };
            headers.forEach((header, index) => {
                if (allowedFields.includes(header)) {
                    record[header] = values[index] || '';
                }
            });

            records.push(record);
        }

        return records;
    }


   mapReceiptStatuses() {
    const receiptNames = this.dataPreview.map(row => row['Receipt No']).filter(Boolean);

    if (!receiptNames.length) {
        console.warn('No receipt names found in uploaded file.');
        this.isLoading = false;
        return;
    }

    fetchReceiptStatuses({ receiptNames })
        .then(data => {
            const receiptMap = new Map();
            data.forEach(item => {
                receiptMap.set(item['Receipt No'], item);
            });

            let unmatchedCount = 0;

            this.dataPreview = this.dataPreview.map(row => {
                const match = receiptMap.get(row['Receipt No']);
                if (match) {
                    row['OldStatus'] = match['OldStatus'] || '';
                    row['currentEBSClearingDate'] = match['Old EBS Clearing Date'] || '';
                    row['Sales Order: Sales Order Name'] = match['Sales Order: Sales Order Name'] || '';
                    row['Sales Order: Unit: Unit Name'] = match['Sales Order: Unit: Unit Name'] || '';
                    row['Project Name'] = match['Sales Order: Project: Project Name'] || '';
                    row['Sales Order: Client Name'] = match['Sales Order: Client: Client Name'] || '';
                    row['totalamount'] = match['Totalamount'] || '';

                } else {
                    unmatchedCount++;
                }
                return row;
            });

            this.unmatchedCount = unmatchedCount;
            this.isLoading = false;
        })
        .catch(error => {
            console.error('Error fetching receipt statuses', error);
            this.isLoading = false;
        });
}


    downloadSampleFile() {
        const link = document.createElement('a');
        link.href = sampleCSVFile;
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
    }

    uploadData() {
        if (!this.dataPreview.length) {
            alert('No data to upload!');
            return;
        }

        // Check if there's at least one record where OldStatus !== Status
       	const hasChanges = this.dataPreview.some(row => {
			const oldStatus = row['OldStatus'] ? row['OldStatus'].trim() : '';
			const newStatus = row['Status'] ? row['Status'].trim() : '';
			const oldDate = row['currentEBSClearingDate'] ? row['currentEBSClearingDate'].trim() : '';
			const newDate = row['EBS Clearing Date'] ? row['EBS Clearing Date'].trim() : '';
			return row['Receipt No'] && (newStatus !== oldStatus || newDate !== oldDate);
		});

        if (!hasChanges) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'No Updates',
                    message: 'All statuses are already up to date. No changes to upload.',
                    variant: 'warning'
                })
            );
            return;
        }

        const uploadPayload = this.dataPreview.map(row => ({
            'Receipt No': row['Receipt No'] ? row['Receipt No'].trim() : '',
            'Status': row['Status'] ? row['Status'].trim() : '',
            'EBS Clearing Date' : row['EBS Clearing Date'] ? row['EBS Clearing Date'].trim() : '',
        }));

        if (!uploadPayload.some(rec => rec['Receipt No'] && (rec['Status'] || rec['EBS Clearing Date']))) {
            alert('Upload data must contain valid Receipt No and either Status or EBS Clearing Date.');
            return;
        }

        this.isLoading = true;
        uploadRecords({ jsonData: JSON.stringify(uploadPayload) })
            .then(() => {
                alert('Records updated successfully!');

                // Dynamically update dataPreview so OldStatus matches the new Status after upload
                 // Dynamically update dataPreview so OldStatus matches the new Status after upload
                 this.dataPreview = this.dataPreview.map(row => {
                const newStatus = row['Status'] ? row['Status'].trim() : '';
                const newDate = row['EBS Clearing Date'] ? row['EBS Clearing Date'].trim() : '';
                if (newStatus) {
                    row['OldStatus'] = newStatus;
                    row['Status'] = '';
                }
                if (newDate) {
                    row['currentEBSClearingDate'] = newDate;
                    row['EBS Clearing Date'] = '';
                }
                return row;
            });
        })
            .catch(error => {
                console.error('Upload error:', error);
                alert('Upload failed');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    /*refreshData() {
        this.isLoading = true;
        this.mapReceiptStatuses();
        this.showRefreshButton = false; // Hide refresh button after refresh
    }*/


}