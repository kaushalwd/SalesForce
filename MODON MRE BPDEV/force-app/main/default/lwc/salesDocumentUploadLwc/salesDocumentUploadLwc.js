import { LightningElement,track,api, wire} from 'lwc';
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getRelatedDocumentsWrapper from '@salesforce/apex/RelatedDocumentsController.getRelatedDocumentDetailWrapper';
import deleteDocumentFile from '@salesforce/apex/RelatedDocumentsController.deleteDocumentFile';
import { refreshApex } from '@salesforce/apex';

export default class SalesDocumentUploadLwc extends LightningElement {
    @track documentColumns=['Name','Status','Actions'];
    @track acceptedFormats=['.png','.gif','.jpg','.pdf'];
    @track lstOfDocuments=[];
    uploadFileRow={};
    showUploadModal=false;
    uploadFileName='';
    @api recordId;
    @api objectApiName;
    @track BaseURL;
    @api documentIdsString=[];

    connectedCallback(){
        this.BaseURL=window.location.origin;
        // this.getdocuments();
    }
    wiredResults;
    @wire(getRelatedDocumentsWrapper, { sobjectId: '$recordId', objectName : '$objectApiName' })
    wiredDocuments(result) {
        this.wiredResults = result;
        const {data, error} = result;
        
        if (result.data) {
            this.recordsData = result.data;
            this.lstOfDocuments = result.data;
            this.error = undefined;
        } else if (result.error) {
            this.error = result.error;
            this.recordsData = undefined;
            this.showToastMessage('error', 'Error', JSON.stringify(this.error));
        }
    }

    // @api getdocuments(){
    //     this.isSpinner=true;
    //     var companyOptionalDocs = PassfortCompanyOptionalDocNamesLabel.split(',');
    //     var individualOptionalDocs = PassfortIndividualOptionalDocNamesLabel.split(',');
    //     getDocumentRecords({
    //         recordId: this.recordid
    //     }).then((data)=>{
    //         this.isSpinner=false;
    //     if(data.length>0){
    //     this.lstOfDocuments=[];
    //     this.documentIdsString=[];
    //     data.forEach(document => {
    //         this.lstOfDocuments.push(document);
    //     });
    //     this.lstOfDocuments.forEach(doc=>{
    //         if(doc.Status=='Uploaded' && !companyOptionalDocs.includes(doc.Name.split(' - ')[1])  && !individualOptionalDocs.includes(doc.Name.split(' - ')[1])){
    //         const detail = { key: doc.Name, value: doc.Id};
    //         this.documentIdsString.push(detail);
    //         }
    //     });
    //   }
    //  });
    // }

    handleCloseUploadSection(event){
        this.showUploadModal=false;
        this.uploadFileName='';
    }
    
    handleUpload(event){
        this.showUploadModal=true;
        this.uploadFileRow = this.lstOfDocuments[event.target.getAttribute("data-row-index")];
        this.uploadFileName = this.uploadFileRow.Name; 
    }
    handleUploadFinished(event){
        try{
        this.showUploadModal=false;
        const uploadedFiles= event.detail.files;
        if(uploadedFiles.length>1){
            this.showToastMessage('File Upload','Please upload only one file at a time.','error');
        }else{
            // this.getdocuments();
            refreshApex(this.wiredResults);
            if(this.uploadFileRow.ContentDocumentId!=null){
                deleteDocumentFile({
                    ContentDocumentId : this.uploadFileRow.ContentDocumentId
                }).then(result => {
                    this.showToastMessage('File Upload',this.uploadFileRow.Name+' is replaced Successfully','success');
                });
            }else{
              this.showToastMessage('File Upload',this.uploadFileRow.Name+' is added Successfully','success');
            }
        }
        }catch(e){
            console.error(e.getMessage);
        }   
    }

    showToastMessage(title,message,variant){
        const evt = new ShowToastEvent({
            title:title,
            message:message,
            variant:variant,
            mode:'dismissal'
        });
        this.dispatchEvent(evt);
    }

    handlePreview(event){
        this.uploadFileRow = this.lstOfDocuments[event.target.getAttribute("data-row-index")];
        this.PreviewUrl=this.BaseURL+'/lightning/r/ContentDocument/'+this.uploadFileRow.ContentDocumentId+'/view';
        window.open(this.PreviewUrl);
    }
}