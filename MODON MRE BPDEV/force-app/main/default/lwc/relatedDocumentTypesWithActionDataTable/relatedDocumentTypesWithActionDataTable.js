import { LightningElement, wire, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import { deleteRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getDocumentRecords from '@salesforce/apex/DocumentTypesController.fetchDocandDocType';
import createContentDocumentAndLinkToCase from '@salesforce/apex/DocumentTypesController.createContentDocumentAndLinkToCase';
import createContentVersion from '@salesforce/apex/DocumentTypesController.createContentVersion';
import DOCUMENT_OBJECT from "@salesforce/schema/Documents__c";
import ID_FIELD from "@salesforce/schema/Documents__c.Id";
import STATUS_FIELD from "@salesforce/schema/Documents__c.Status__c";
import strUserId from '@salesforce/user/Id';
import PROFILE_NAME_FIELD from '@salesforce/schema/User.Profile.Name';
import {getRecord} from 'lightning/uiRecordApi';

//2. Import the named import updateRecord
import { updateRecord } from "lightning/uiRecordApi";

export default class RelatedDocumentTypesWithActionDataTable extends NavigationMixin(LightningElement) {
    @api recordId;
    @track prfName;
    userId = strUserId;
    data = [];
    acceptedFormats = ['.pdf', '.png', '.jpg'];
    @track isLoading = true;
    currentItem;
    tempData = [];
    lstOfDocuments=[];
    isAdminUser;
    @track fileName = 'CustomFileName.pdf'; // Set your custom file name here
    @track fileContent = '';
    @track isUploadDisabled = true;
    error='';
    /** Wired Apex result so it can be refreshed programmatically */
    wireddocumentsResult;

    connectedCallback(){
        this.BaseURL=window.location.origin;
        this.getdocuments();
    }

    
   @wire(getRecord, {
    recordId: strUserId,
    fields: [PROFILE_NAME_FIELD]
}) wireuser({
    error,
    data
}) {
    if (error) {
       this.error = error ; 
    } else if (data) {
        this.prfName =data.fields.Profile.value.fields.Name.value; 
        if(this.prfName == 'System Administrator') {
            this.isAdminUser=true;
        }
    }
}

    @api getdocuments(){
        getDocumentRecords({
            
            serviceReqId: this.recordId,
            ObjectName:'ServiceRequest__c'
        }).then((data)=>{
            //data =data.map(item => {

                

                if(data.length>0){
                    this.lstOfDocuments=[];
                    let docdata = [];
                    let docParsedData = JSON.parse(JSON.stringify(data));
                    docParsedData.forEach(res => {
               
                        this.lstOfDocuments =docParsedData.map(item => {
                            
                             if(!item.contentVersion) {
                                return {
                                    isSignedSPA: item.isSPA,
                                    isbuttonsDisable : true,
                                    docName:item.docName,
                                    docId: item.docId,
                                    docStatus: item.docStatus,
                                    isSystemUpload:item.isSystemUpload,
                                    recordName:item.recordName,
                                    contcontentVersion:{
                                        id: '',
                                        fileType: '',
                                        title: '',
                                        fileExtension: '',
                                        contentDocumentId: '',
                                        createdDate: '',
                                        contentBodyId:'' ,
                                        createdBy:'',
                                        versionData: ''
                                    }
                                };
                        }
                            if(item.contentVersion){
                                return {
                                    isSignedSPA:item.isSPA,
                                    isbuttonsDisable : false,
                                    docName:item.docName,
                                    docId: item.docId,
                                    docStatus: item.docStatus,
                                    isSystemUpload:item.isSystemUpload,
                                    recordName:item.recordName,
                                    contcontentVersion:{
                                        id: item.contentVersion.Id,
                                        fileType: item.contentVersion.FileType,
                                        title: item.contentVersion.Title,
                                        fileExtension: item.contentVersion.FileExtension,
                                        contentDocumentId: item.contentVersion.ContentDocumentId,
                                        createdDate: item.contentVersion.CreatedDate,
                                        contentBodyId: item.contentVersion.ContentBodyId,
                                        createdBy:item.contentVersion.ContentDocument.CreatedBy.Name,
                                        versionData: item.contentVersion.VersionData
                                    }
                                };
                            } 
                        });
                        this.isLoading = false; // Data is loaded, hide the spinner
                        refreshApex(this.lstOfDocuments);

                     })
           
                }
                  else if (error) {
                    console.error(error);
                    this.isLoading = false; // Data is loaded, hide the spinner
            }
                  this.isLoading = false;
                  //this.getdocuments();
                  //refreshApex(this.lstOfDocuments);

           // });
            this.isLoading = false; // Data is loaded, hide the spinner
        
     });
     
    }

    handlepreviewFile(event) {
        const docId = event.target.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__namedPage',
            attributes: {
                pageName: 'filePreview'
            },
            state : {
                selectedRecordId:docId
            }
          });
    }

    handleDownload(event) {
        const docId = event.target.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: '/sfc/servlet.shepherd/document/download/'+docId
            },
            state : {
                selectedRecordId:docId
            }
          });
    }

    handleDelete(event) {
        const docId = event.target.dataset.id;
        
        this.handleDeleteFiles(docId);
        const fields = {};
        const docmentId = event.target.dataset.itemid;
        fields[ID_FIELD.fieldApiName] = docmentId;
        fields[STATUS_FIELD.fieldApiName] = 'Pending Upload';
            
            //5. Create a config object that had info about fields. 
            //Quick heads up here we are not providing Object API Name
        const recordInput = {
          fields: fields
        };
    
            //6. Invoke the method updateRecord()
        updateRecord(recordInput);
    }

    async handleDeleteFiles(docId) {
        this.isLoading = true; // Show spinner
        try {
            await deleteRecord(docId);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Document deleted',
                    variant: 'success'
                })
            );
            // Refresh the Apex data
            this.getdocuments();
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error deleting record',
                    message: reduceErrors(error).join(', '),
                    variant: 'error'
                })
            );
        }finally {
            this.isLoading = false; // Hide spinner
        }
    }




     handleFileClick(event) {
        const docId = event.target.dataset.itemid;
        const docName = event.target.dataset.itemname;
        const contentDocId = event.target.dataset.itemcontid;
        const recordName = event.target.dataset.itemrecname;
        this.tempData = {
            tempdocId:docId,
            tempContentDocumentId:contentDocId,
            tempdocName:docName,
            tempDocRecordName:recordName
        }

        const fileInput = this.template.querySelector('input[type="file"]');
        if (fileInput) {
            fileInput.click();
        }
    }

    async handleFileChange(event) {
        const file = event.target.files[0];
        if (!file){
            return;
        } 

        //this.isLoading = true; // Show spinner

        try {
            if (!this.tempData.tempContentDocumentId) {
                this.isLoading = true; // Show spinner
                // Create ContentDocument
                const reader = new FileReader();
                reader.onload = async () => {
                const base64 = reader.result.split(',')[1];
                const contentDocumentId = await createContentDocumentAndLinkToCase({
                                                    linkedEntityId: this.tempData.tempdocId,
                                                    fileName:this.tempData.tempdocName+' / ' + this.tempData.tempDocRecordName,
                                                    base64Data:base64,
                                                    pathOnClient: file.name
                                                    });
                        // Refresh the Apex data
                        this.getdocuments()

                        this.isLoading = false; // Hide spinner
                        this.dispatchEvent(
                            new ShowToastEvent({
                                title: 'Success',
                                message: 'File uploaded successfully',
                                variant: 'success'
                            })
                        );
                        
                };
                reader.readAsDataURL(file);
            }else{
                this.isLoading = true; // Show spinner
                // Create ContentVersion
                const reader = new FileReader();
                reader.onload = async () => {
                    const base64 = reader.result.split(',')[1];
                    await createContentVersion({
                        contentDocumentId: this.tempData.tempContentDocumentId,
                        title: this.tempData.tempdocName+' / ' + this.tempData.tempDocRecordName,
                        versionData: base64,
                        pathOnClient: file.name
                    });
                    // Refresh the Apex data
                    this.getdocuments();
                    this.isLoading = false; // Hide spinner
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Success',
                            message: 'File uploaded successfully',
                            variant: 'success'
                        })
                    );
                };
                reader.readAsDataURL(file);
                //this.getdocuments();
            }
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error uploading file',
                    message: error.body.message,
                    variant: 'error'
                })
            );
        } finally {
            //this.isLoading = false; // Hide spinner
        }
    }
}