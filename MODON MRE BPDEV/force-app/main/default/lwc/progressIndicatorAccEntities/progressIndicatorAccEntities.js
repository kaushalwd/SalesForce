import { LightningElement,track,api, wire } from 'lwc';
import LightningModal from 'lightning/modal';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import createPassfortTransactionRecords from '@salesforce/apex/ProgressKYCController.createPassfortTransactionRecords';
// import upsertShareholderRecords from '@salesforce/apex/ProgressKYCController.upsertShareholderRecords';
// import getShareholderRecords from '@salesforce/apex/ProgressKYCController.getShareholderRecords';
// import getShareholderRecordscontact from '@salesforce/apex/ProgressKYCController.getShareholderRecordscontact';
import getNationalityOptions from '@salesforce/apex/ProgressKYCController.getNationalityOptions';
import deleteDocumentPlaceholders from '@salesforce/apex/ProgressKYCController.deleteDocumentPlaceholders';
//import deleteShareholderRecord from '@salesforce/apex/ProgressKYCController.deleteShareholderRecord';
import PassfortCompanyDocNamesLabel from '@salesforce/label/c.PassfortCompanyDocNames';//need to update
import PassfortIndividualDocNamesLabel from '@salesforce/label/c.PassfortIndividualDocNames';//need to update
import isAccessSubmitForCompliance from '@salesforce/apex/ProgressKYCController.isAccessSubmitForCompliance';

export default class ProgressIndicatorAccEntities extends LightningModal {
    @api content;
    @api objectApiName;
    @api recordId;
    isSpinner=false;
    isOnChange=false;
    isOtherLegalStructure=false;
    SourceOfIncome;
    isOtherSourceOfIncome=false;
    clickedButton;
    showShareholderDatatable=false;
    showSubmitForCompliance=false;
    @track activeSections=['Details','Shareholder','Documents'];
    @track shareHolderRecords=[];
    @track NationalityPicklistOptions=[];
    @track returnFromModal={
        isRecordSaved:false
    }
    accTable=false;

    connectedCallback(){
        this.recordId=this.content.EntityRecordId;
        this.objectApiName=this.content.EntityAPIName;
        if(this.objectApiName == 'Account'){
            this.accTable=true;
        }else{
            this.accTable=false;
        }
        isAccessSubmitForCompliance({
        }).then(booleanResult=>{
            this.showSubmitForCompliance=booleanResult;
        })

        getNationalityOptions({
        }).then((lstNationality)=>{
            lstNationality.forEach( nationality => {
                this.NationalityPicklistOptions = [
                    ...this.NationalityPicklistOptions,
                    {label: nationality, value: nationality}
                ];
            });
        });
        //this.getshareholders();
    }
    
    // getshareholders(){
    //     this.isSpinner=true;
    //     if(this.objectApiName=='Account'){
    //         getShareholderRecordscontact({
    //             AccountId:this.content.EntityRecordId
    //         }).then(result=>{
    //             this.isSpinner=false;
    //             this.showShareholderDatatable=true;
    //             this.shareHolderRecords=[];
    //             for(var i=0;i< result.length;i++){
    //                 var index=i+1;
    //                 var shareholderObject={};
    //                 shareholderObject['key']=index;
    //                 shareholderObject['Nationality__c']=result[i].Nationality__c;
    //                 shareholderObject['Birthdate']=result[i].Birthdate;
    //                 shareholderObject['OwnershipPercentage__c']=result[i].OwnershipPercentage__c;
    //                 shareholderObject['FirstName']=result[i].FirstName;
    //                 shareholderObject['LastName']=result[i].LastName;
    //                 shareholderObject['Id']=result[i].Id;
    //                 shareholderObject['AccountId']=result[i].AccountId;
    //                 this.shareHolderRecords.push(shareholderObject);
    //             }
    //         }).catch(error=>{
    //             this.showToastMessage('Error ','Error in getting ShareHolder records','error');
    //         });
    //     }else{
    //         getShareholderRecords({
    //             AccountId:this.content.EntityRecordId
    //         }).then(result=>{
    //             this.isSpinner=false;
    //             this.showShareholderDatatable=true;
    //             this.shareHolderRecords=[];
    //             for(var i=0;i< result.length;i++){
    //                 var index=i+1;
    //                 var shareholderObject={};
    //                 shareholderObject['key']=index;
    //                 shareholderObject['Nationality__c']=result[i].Nationality__c;
    //                 shareholderObject['Birthdate__c']=result[i].Birthdate__c;
    //                 shareholderObject['OwnershipPercentage__c']=result[i].OwnershipPercentage__c;
    //                 shareholderObject['First_Name__c']=result[i].First_Name__c;
    //                 shareholderObject['Last_Name__c']=result[i].Last_Name__c;
    //                 shareholderObject['Id']=result[i].Id;
    //                 shareholderObject['Account__c']=result[i].Account__c;
    //                 this.shareHolderRecords.push(shareholderObject);
    //             }
    //         }).catch(error=>{
    //             this.showToastMessage('Error ','Error in getting ShareHolder records','error');
    //         });
    //     }
        
    // }

    showToastMessage(title,message,variant){
        const evt = new ShowToastEvent({
            title:title,
            message:message,
            variant:variant,
            mode:'dismissal'
        });
        this.dispatchEvent(evt);
    }

    handleChangeLegalStructure(event){
        this.LegalStructure=event.target.value;
        if(this.LegalStructure=="Others"){
            this.isOtherLegalStructure=true;
        }
        this.isOnChange=true;
    }

    handleChangeSourceOfIncome(event){
        this.SourceOfIncome=event.target.value;
        if(this.SourceOfIncome=="Others"){
            this.isOtherSourceOfIncome=true;
        }else{
            this.isOtherSourceOfIncome=false;
        }
        this.isOnChange=true;
    }

    // upsertShareholders(shareholderRow){
    //     var isMissingFields= false;
    //         if(this.isBlankString(shareholderRow.First_Name__c)|| this.isBlankString(shareholderRow.Last_Name_cc)||
    //            this.isBlankString(shareholderRow.OwnershipPercentage__c)|| this.isBlankString(shareholderRow.Nationality__c)||
    //            this.isBlankString(shareholderRow.Birthdate__c)){
    //                 isMissingFields=true;
    //         }
    //     if(isMissingFields){
    //         this.showToastMessage('Error ','Please fill up all required fields of Shareholder','error');
    //     }else{
    //         upsertShareholderRecords({
    //             conShareholder : shareholderRow
    //         }).then(result=>{
    //             if(result.includes('success')){
    //                 this.getshareholders();
    //                  this.template.querySelector('c-passfort-document-upload-lwc').getdocuments(); //to get documents for new shareholder
    //                  this.showToastMessage('Success ','Shareholder record is successfully saved.','success');
    //             }else if(result.includes('error')){
    //                 this.showToastMessage('Error ','Shareholder record is not saved.','error');
    //             }
    //         }).catch(error => {
    //             this.showToastMessage('Error ','Shareholder record is not saved.','error');
    //         })
    //     }
    // }
    
    //to add new blank row for share holder details
    handleAddRow(event){
        var index= this.shareHolderRecords.length+1;
        var shareholderObject={};
        shareholderObject['key']=index;
        shareholderObject['Nationality__c']='';
        shareholderObject['Birthdate__c']='';
        shareholderObject['OwnershipPercentage__c']=0;
        shareholderObject['First_Name__c']='';
        shareholderObject['Last_Name__c']='';
        shareholderObject['Account__c']=this.content.EntityRecordId;
        this.shareHolderRecords.push(shareholderObject);
    }

    // //to save shareholder record
    // handleSaveRow(event){
    //     var rows = JSON.parse(JSON.stringify(this.shareHolderRecords));
    //     var rowIndex=event.target.getAttribute("data-row-index");
    //     var row=this.shareHolderRecords[rowIndex];
    //     this.upsertShareholders(row);
    // }

    //to delete shareholder record
    // handleDeleteRow(event){
    //     var rows = JSON.parse(JSON.stringify(this.shareHolderRecords));
    //     var rowIndex=event.target.getAttribute("data-row-index");
    //     var row=this.shareHolderRecords[rowIndex];
    //     if(row!=null && row.Last_Name__c==''){
    //         rows.splice(rowIndex, 1);
    //         this.shareHolderRecords = JSON.parse(JSON.stringify(rows));
    //     }
    //     else{
    //     deleteShareholderRecord({
    //         conShareholder : row
    //     }).then(result=>{      
    //       if(result.includes('success')){     
    //         rows.splice(rowIndex, 1);
    //         this.shareHolderRecords = JSON.parse(JSON.stringify(rows));
    //         for(var i=0; i<this.shareHolderRecords.length; i++){
    //             var index=i+1;
    //             this.shareHolderRecords[i].key=index;
    //         }
    //         this.getshareholders();
    //         this.template.querySelector('c-passfort-document-upload-lwc').getdocuments(); 
    //         this.showToastMessage('Success ','Shareholder record is deleted.','success');
    //       } else {
    //         this.showToastMessage('Error ','Shareholder record is not deleted.','error');
    //       }        
    //     }).catch(error => {
    //         this.showToastMessage('Error ','Shareholder record is not deleted.','error');
    //     }) 
    // }       
    // }

    handleClose() {
        this.close(this.returnFromModal);
        deleteDocumentPlaceholders({
            recordId : this.recordId
        }).then(result => {
        });        
    }

    handleOnLoad(event) {
        event.preventDefault();
        var record = event.detail.records;
        var fields = record[this.content.EntityRecordId].fields;
        if(!this.isOnChange){
            var legalStructureValue = fields.LegalStructure__c;
            var sourceOfIncomeValue = fields.SourceOfIncome__c;
            if(legalStructureValue.value=="Others"){
                this.isOtherLegalStructure=true;
            }else{
                this.isOtherLegalStructure=false;
            }
            if(sourceOfIncomeValue.value=="Others"){
                this.isOtherSourceOfIncome=true;
            }else{
                this.isOtherSourceOfIncome=false;
            }
        }
    }
   
   // to check blank field value before calling save
    isBlankString(str){
        var isBlank=false;
        switch(str){
            case '':
                isBlank=true;
                break;
            case "":
                isBlank=true;
                break;
            case null:
                isBlank=true;
                break;
            case undefined:
                isBlank=true;
                break;
            default:
                isBlank=false;
                break;
        }
        return isBlank;
    }

    onSubmit(event){
        event.preventDefault();
        const fields=event.detail.fields;
        if(this.clickedButton==="handleSubmit"){ //to save as draft
            // this.template.querySelector('lightning-record-edit-form').submit(fields);
            try {
                this.template.querySelector('lightning-record-edit-form').submit(fields);
                this.showToastMessage('Success','Details are successfully saved','success');
            } catch (error) {
                console.error('Submission Error:', error);
            }
            
           
            this.isSpinner=false;
            // this.returnFromModal["isRecordSaved"]=true;
            // this.close(this.returnFromModal);
        }else if(this.clickedButton=="handleSubmitForCompliance" && this.clickedButton!="handleSubmit"){ //to save and create transaction records
            if(
                this.isBlankString(fields.LegalStructure__c) ||
                this.isBlankString(fields.DateOfEstablishment__c) ||
                this.isBlankString(fields.UnifiedNumber__c) ||
                this.isBlankString(fields.TradeLicenseExpiryDate__c) ||
                this.isBlankString(fields.UAEVATRegisterNumber__c) || 
                this.isBlankString(fields.PurposeOfTransaction__c) || 
                this.isBlankString(fields.BillingCity) ||
                this.isBlankString(fields.BillingCountry) ||
                this.isBlankString(fields.BillingPostalCode) ||
                this.isBlankString(fields.BillingState) ||
                this.isBlankString(fields.Phone) || 
                this.isBlankString(fields.Description)|| 
                this.isBlankString(fields.SourceOfIncome__c) ||
                this.isBlankString(fields.DeliveryChannel__c)|| 
                this.isBlankString(fields.NoOfPropertyPurchasedWithModon__c)
                || (fields.LegalStructure__c=="Other" && this.isBlankString(fields.OtherLegalStructure__c)) ||
                (fields.SourceOfIncome__c=="Other" && this.isBlankString(fields.OtherSourceOfIncome__c))
           ){
            this.showToastMessage('Error ','All required fields needs to have data to submit for compliance','error');
               this.isSpinner=false;
           }else{
               var lstOfdocMap =this.template.querySelector('c-passfort-document-upload-lwc').documentIdsString;
               var companyDocs = PassfortCompanyDocNamesLabel.split(',');
               var individualDocs = PassfortIndividualDocNamesLabel.split(',');
               var docIds='';
               var allDocsUploaded =true;
               companyDocs.forEach(companyDocName=>{
                    lstOfdocMap.forEach(doc=>{
                        if(doc.key.includes(companyDocName))
                            docIds = docIds==''?doc.value:docIds+','+doc.value;
                    })
                })
                if(docIds.split(',').length != companyDocs.length){
                    allDocsUploaded = false;
                }
                
                var lstTransactions=[];
                var transactionRecord={};
                transactionRecord['ApprovalStatus']=this.content.ApprovalStatus;
                transactionRecord['EntityAPIName']=this.content.EntityAPIName;
                transactionRecord['EntityRecordId']=this.content.EntityRecordId;
                transactionRecord['EntityType']=this.content.EntityType;
                transactionRecord['Name']=this.content.Name;
                transactionRecord['parentObjectName']=this.content.parentObjectName;
                transactionRecord['parentRecordId']=this.content.parentRecordId;
                transactionRecord['RiskStatus']=this.content.RiskStatus;
                transactionRecord['ParentDocumentIds']=docIds;
                lstTransactions.push(transactionRecord);                
                
                this.shareHolderRecords.forEach(shareHolderContact=>{
                    docIds ='';
                    lstOfdocMap.forEach(doc=>{
                        if(doc.key.includes(shareHolderContact.First_Name__c+' '+shareHolderContact.Last_Name__c))
                            docIds = docIds==''?doc.value:docIds+','+doc.value;
                    })
                    var transactionRecord={};
                    transactionRecord['ApprovalStatus']=shareHolderContact.PassfortApprovalStatus__c;
                    transactionRecord['EntityAPIName']='Contact';
                    transactionRecord['EntityRecordId']=shareHolderContact.Id;
                    transactionRecord['EntityType']='Shareholder';
                    transactionRecord['Name']=shareHolderContact.First_Name__c+' '+shareHolderContact.Last_Name__c;
                    transactionRecord['parentObjectName']=this.content.parentObjectName;
                    transactionRecord['parentRecordId']=this.content.parentRecordId;
                    transactionRecord['RiskStatus']=shareHolderContact.PassfortRiskStatus__c;
                    transactionRecord['ParentDocumentIds']=docIds;
                    if(docIds.split(',').length != individualDocs.length){
                        allDocsUploaded = false;
                    }
                    lstTransactions.push(transactionRecord);
                })
                if(allDocsUploaded){
                    this.template.querySelector('lightning-record-edit-form').submit(fields);
                    createPassfortTransactionRecords({
                        transactionRecords : JSON.stringify(lstTransactions),
                        recordId : this.recordId
                    }).then(result=>{
                        if(result.includes('success')){
                            this.showToastMessage('Success ','This record has been successfully submitted for compliance.','success');
                            this.isSpinner=false;
                            this.returnFromModal["isRecordSaved"]=true;
                            this.close(this.returnFromModal);
                        }else if(result.includes('error')){
                            this.showToastMessage('Error ','This record failed to submit for compliance.','error');
                            this.isSpinner=false;
                        }
                    }).catch(error=>{
                        this.showToastMessage('Error ','Failed to submit for compliance','error');
                        this.isSpinner=false;
                    });
            }else{
                this.isSpinner=false;
                this.showToastMessage('Error ','Please provide required documents for all Shareholders','error');
            }
         }
        }
    }

    handleSubmit(event){
        event.preventDefault();
        this.isSpinner=true;
        this.clickedButton='handleSubmit';
        this.template.querySelector('.submitButton').click();
    }

    handleSubmitForCompliance(event){
        event.preventDefault();
        this.isSpinner=true;
        this.clickedButton='handleSubmitForCompliance';
        this.template.querySelector('.submitButton').click();
    }

    handleChangeFirstName(event){
        this.shareHolderRecords[event.target.getAttribute("data-row-index")].First_Name__c = event.target.value;
    }
    handleChangeLastName(event){
        this.shareHolderRecords[event.target.getAttribute("data-row-index")].Last_Name__c = event.target.value;
    }
    handleChangeOwnershipPercentage(event){
        this.shareHolderRecords[event.target.getAttribute("data-row-index")].OwnershipPercentage__c = event.target.value;
    }
    handleChangeNationality(event){
        this.shareHolderRecords[event.target.getAttribute("data-row-index")].Nationality__c = event.target.value;
    }
    handleChangeBirthdate(event){
        this.shareHolderRecords[event.target.getAttribute("data-row-index")].Birthdate__c = event.target.value;
    }
}