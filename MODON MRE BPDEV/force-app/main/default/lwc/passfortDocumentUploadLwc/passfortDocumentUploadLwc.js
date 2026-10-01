import {LightningElement,track,api, wire} from 'lwc';
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { refreshApex } from '@salesforce/apex';
import getDocumentRecords from '@salesforce/apex/PassfortRelatedEntitiesController.getDocumentRecords';
import deleteDocumentFile from '@salesforce/apex/PassfortRelatedEntitiesController.deleteDocumentFile';
import PassfortCompanyOptionalDocNamesLabel from '@salesforce/label/c.PassfortCompanyOptionalDocNames';
import PassfortIndividualOptionalDocNamesLabel from '@salesforce/label/c.PassfortIndividualOptionalDocNames';

export default class PassfortDocumentUploadLwc extends LightningElement {
    @track documentColumns=['Name','Status','Actions'];
    @track acceptedFormats=['.png','.gif','.jpg','.pdf'];
    @track lstOfDocuments=[];
    uploadFileRow={};
    showUploadModal=false;
    uploadFileName='';
    @api recordId;
    @track BaseURL;
    @api documentIdsString=[];

    connectedCallback(){
        this.BaseURL=window.location.origin;
        this.getdocuments();
    }
   @api getdocuments(){
        this.isSpinner=true;
        var companyOptionalDocs = PassfortCompanyOptionalDocNamesLabel.split(',');
        var individualOptionalDocs = PassfortIndividualOptionalDocNamesLabel.split(',');
        getDocumentRecords({
            recordId: this.recordId
        }).then((data)=>{
            this.isSpinner=false;
        if(data.length>0){
        this.lstOfDocuments=[];
        this.documentIdsString=[];
        data.forEach(document => {
            this.lstOfDocuments.push(document);
        });
        this.lstOfDocuments.forEach(doc=>{
            if(doc.Status=='Uploaded' && !companyOptionalDocs.includes(doc.Name.split(' - ')[1])  && !individualOptionalDocs.includes(doc.Name.split(' - ')[1])){
            const detail = { key: doc.Name, value: doc.Id};
            this.documentIdsString.push(detail);
            }
        });
      }
     });
    }

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
        this.showUploadModal=false;
        const uploadedFiles= event.detail.files;
        if(uploadedFiles.length>1){
            this.showToastMessage('File Upload','Please upload only one file at a time.','error');
        }else{
            this.getdocuments();
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