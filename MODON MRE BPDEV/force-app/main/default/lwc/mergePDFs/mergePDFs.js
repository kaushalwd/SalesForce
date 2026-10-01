import { LightningElement, api, wire } from 'lwc';
import getPdfFilesWithIdsAsBase64 from '@salesforce/apex/Merge_PDF.getPdfFilesWithIdsAsBase64';
import uploadFile from '@salesforce/apex/Merge_PDF.saveMergedPDFs';
import pdfLib from '@salesforce/resourceUrl/pdfLib';
import { loadScript } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
export default class MergePDFs extends LightningElement {
    @api recordId;
    isLibLoaded = false;
    mergedPdf = null;
    pdfLibInstance;
    showFileUpload = false;
    

    renderedCallback() {
        if (this.isLibLoaded) {
            return;
        }
        loadScript(this, pdfLib + '/pdfLib/pdf-lib.min.js')
            .then(() => {
                if (window['pdfLib'] || window['PDFLib']) {
                    this.isLibLoaded = true;
                    this.pdfLibInstance = window['pdfLib'] || window['PDFLib'];
                    //this.loadPdfs();
                } else {
                    console.error('PDF-LIB not loaded correctly.');
                    this.toast('PDF-LIB not loaded correctly.', 'error', 'dismissible');
                }
            })
            .catch(error => {
                console.error('Error loading PDF-LIB:', error);
                this.toast('Error loading PDF-LIB:', 'error', 'dismissible');
            });
    }

    @wire(getPdfFilesWithIdsAsBase64, { recordId: '$recordId' })
    wiredPdfs({ error, data }) {
        if (this.isLibLoaded && data) {
            let isAlreadyMerged = false;
            for (let pdfFile of data) {
                if(pdfFile.Name.split('@')[0] == pdfFile.Title.split('@')[0]){
                    let msg = 'There is already an existing merged PDF available. Please delete the existing one with a name like "'+pdfFile.Name.split('@')[0]+'" before creating a new one.'
                    this.toast('Error!!!', 'error', 'dismissible', msg);
                    isAlreadyMerged = true;
                    this.dispatchEvent(new CloseActionScreenEvent());
                    return;
                }
            }
            if(!isAlreadyMerged){
                this.mergePDFs(data);
            }
            
        } else if (error) {
            console.error('Error fetching PDFs:', error);
            this.toast('Error fetching PDFs:' + error, 'error', 'dismissible');
        }
    }

    async mergePDFs(pdfFiles) {
        if (!this.pdfLibInstance) {
            this.toast('PDF-LIB instance is not defined.', 'error', 'dismissible');
            console.error('PDF-LIB instance is not defined.');
            return;
        }

        const { PDFDocument } = this.pdfLibInstance;

        var file_name = '';
        const mergedPdf = await PDFDocument.create();
        for (let pdfFile of pdfFiles) {
            file_name = pdfFile.Name;
            const pdfBytes = Uint8Array.from(atob(pdfFile.Base64Data), c => c.charCodeAt(0));
            const pdfDoc = await PDFDocument.load(pdfBytes);
            const copiedPages = await mergedPdf.copyPages(pdfDoc, pdfDoc.getPageIndices());
            copiedPages.forEach(page => mergedPdf.addPage(page));
        }
        
        //APPENDIX B, Draft Unit Plan الملحق ب, مسودة مخطط الوحدة
        /*const Draft_Unit_Plan = mergedPdf[-1];
        const { width, height } = Draft_Unit_Plan.getSize();
        firstPage.drawText('APPENDIX B, Draft Unit Plan الملحق ب, مسودة مخطط الوحدة', {
            x: 2,
            y: height / 2 + 300,
            size: 50,
            font: Arial,
            color: rgb(6, 6, 6),
        })*/

        const compressedPdfBytes = await mergedPdf.save({ useObjectStreams: true });
        const pdfBlob = new Blob([compressedPdfBytes], { type: 'application/pdf' });

        if (pdfBlob.size > 3 * 1024 * 1024) { // Check if the file size exceeds 4MB
            let msg = 'The merged PDF size exceeds 3MB. In a few seconds, the merged PDF will start downloading automatically or it will prompt you to save it. After saving it locally, please reupload it using the upload button below.';
            this.toast('Warning!!!', 'warning','sticky', msg);
            this.showFileUpload = true;
            this.downloadPdfLocally(pdfBlob, file_name)
            
        } else {
            this.uploadCompressedPdf(pdfBlob, file_name);
        }
    }

    downloadPdfLocally(pdfBlob, file_name) {
        const url = URL.createObjectURL(pdfBlob);
        const link = document.createElement('a');
        link.href = url;
        link.download = file_name + '.pdf';
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
        URL.revokeObjectURL(url);
    }

    handleUploadFinished(event) {
        // Get the number of uploaded files
        const uploadedFiles = event.detail.files.length;
        if (uploadedFiles > 0) {
            let title = 'uploaded successfully!!';
            this.toast(title, 'success', 'dismissible');
            this.dispatchEvent(new CloseActionScreenEvent());
        }
    }

    uploadCompressedPdf(blob_file, file_name) {
        const reader = new FileReader();
        reader.readAsDataURL(blob_file);
        reader.onloadend = () => {
            const base64data = reader.result.split(',')[1];
            this.saveMergedFiles(base64data, file_name);
        }
    }

    saveMergedFiles(file, file_name) {
        if (file) {
            uploadFile({ data: file, recordId: this.recordId, file_name:file_name }).then(result => {
                this.fileData = null
                let title = 'uploaded successfully!!';
                this.toast(title, 'success','dismissible');
                this.dispatchEvent(new CloseActionScreenEvent());
                return true;

            }).catch(error => {
                console.error('Error while Merging PDFs', error);
                this.toast('Error while Merging PDFs', 'error', 'dismissible');
                return false;
            });
        }
    }

    toast(title, type, mode, msg) {
        const toastEvent = new ShowToastEvent({
            title,
            message: msg,
            variant: type,
            mode: mode
        })
        this.dispatchEvent(toastEvent)
    }
}