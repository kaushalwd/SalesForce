import { LightningElement,track,api, wire } from 'lwc';
import LightningModal from 'lightning/modal';
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import PassfortIndividualDocNamesLabel from '@salesforce/label/c.PassfortIndividualDocNames';
import createPassfortTransactionRecords from '@salesforce/apex/ProgressKYCController.createPassfortTransactionRecords';
import isAccessSubmitForCompliance from '@salesforce/apex/ProgressKYCController.isAccessSubmitForCompliance';

export default class ProgressIndicatorConEntities extends LightningModal {
    @api content;
    @api objectApiName='Contact';
    @api recordId;
    activeSections=['Details','Documents'];
    isSpinner=false;
    @track isNotPrimaryContact=false;
    @track UAEResidentStatus;
    @track IdentityProof;
    @track isResident=false;
    @track isOnChange=false;
    @track isOtherIncome=false;
    showSubmitForCompliance=false;
    clickedButton;
    isError=false;
    @track lstTransactions=[];
    BaseURL;
    StringDocIds='';
    @track returnFromModal={
        isRecordSaved:false
    }

    connectedCallback() {
        //this.isSpinner=true;
        this.recordId=this.content.EntityRecordId;
        this.BaseURL=window.location.origin;
        if(this.content.EntityType!='Primary Contact'){
            this.isNotPrimaryContact=true;
        }
        isAccessSubmitForCompliance({
        }).then(booleanResult=>{
            this.showSubmitForCompliance=booleanResult;
        })
    }
    //show toast message
    showToastMessage(title,message,variant){
        const evt = new ShowToastEvent({
            title:title,
            message:message,
            variant:variant,
            mode:'dismissal'
        });
        this.dispatchEvent(evt);
    }
    //close the modal pop up.
    handleClose() {
        this.close(this.returnFromModal);
    }
    //Change Identity Proof data on change resident status.
    handleChangeUAEResidentStatus(event){
        this.UAEResidentStatus=event.target.value;
        this.isOnChange=true;
        if(this.UAEResidentStatus=="Resident"){
            this.IdentityProof="Emirates ID";
            this.isResident=true;
        }else if(this.UAEResidentStatus=="Non-Resident"){
            this.IdentityProof="Passport";
            this.isResident=false;
        }
    }
    // On change Identity Proof show hide related fields.
    handleChangeIdentityProof(event){
        this.IdentityProof=event.target.value;
        this.isOnChange=true;
        if(this.IdentityProof=="Emirates ID"){
            this.isResident=true;
        }else if(this.IdentityProof=="Passport"){
            this.isResident=false;
        }
    }
    //If source of income is Other, show other income field.
    handleChangeSourceOfIncome(event){
        this.SourceOfIncome=event.target.value;
        if(this.SourceOfIncome=="Other"){
            this.isOtherIncome=true;
        }
    }
    //onload of the record edit form.
    handleOnLoad(event) {
        event.preventDefault();
        var record = event.detail.records;
        var fields = record[this.recordId].fields;
        if(!this.isOnChange){
            var UAEResident = fields.UAE_Resident_Status__c;
            if(UAEResident.value=="Resident"){
                this.IdentityProof="Emirates ID";
                this.isResident=true;
            }else if(UAEResident.value=="Non-Resident"){
                this.IdentityProof="Passport";
                this.isResident=false;
            }
        }
        this.isSpinner=false;
    }

    // This function checks if a string has valid data or not.
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
    //On click(also programmatically) of submit button this function called 1) Save salesforce record
    // 2) Create passfort Transaction records.
    onSubmit(event){
        this.isError=false;
        const fields=event.detail.fields;
        if(this.clickedButton!="handleSubmitForCompliance" && this.clickedButton=="handleSubmit"){
            this.template.querySelector('lightning-record-edit-form').submit(fields);
            this.showToastMessage('Success ','Details are successfully saved','success');
            this.isSpinner=false;
            //this.close(fields);
            this.returnFromModal["isRecordSaved"]=true;
            this.close(this.returnFromModal);
        }else if(this.clickedButton=="handleSubmitForCompliance" && this.clickedButton!="handleSubmit"){
            if(
                 this.isBlankString(fields.Birthdate) ||
                 this.isBlankString(fields.Nationality__c) ||
                 this.isBlankString(fields.UAE_Resident_Status__c) ||
                 this.isBlankString(fields.IdentityProof__c) ||
                 (this.isNotPrimaryContact && this.isBlankString(fields.EIDNumber__c) && this.isBlankString(fields.PassportNumber__c))|| 
                 this.isBlankString(fields.MobilePhone)|| 
                 (this.isNotPrimaryContact && this.isBlankString(fields.Occupation__c)) ||
                 this.isBlankString(fields.EmployerBusinessName__c)||
                 (this.isNotPrimaryContact && this.isBlankString(fields.PurposeOfTransaction__c))||
                 (this.isNotPrimaryContact && this.isBlankString(fields.PaymentMethod__c))|| 
                 this.isBlankString(fields.Email)||
                 (this.isNotPrimaryContact && this.isBlankString(fields.SourceOfIncome__c)) ||
                 (this.isNotPrimaryContact && fields.SourceOfIncome__c=="Other" && this.isBlankString(fields.OtherSourceOfIncome__c))|| 
                 (this.isNotPrimaryContact && this.isBlankString(fields.DeliveryChannel__c))||
                 this.isBlankString(fields.NoOfPropertyPurchasedWithModon__c)||
                 this.isBlankString(fields.MailingCity)||
                 this.isBlankString(fields.MailingCountry)||
                 this.isBlankString(fields.MailingState)||
                 this.isBlankString(fields.MailingPostalCode)||
                 this.isBlankString(fields.MailingStreet)
           ){
                this.isError=true;
                this.showToastMessage('Error : Required fields missing ','Please fill up all to submit for compliance','error');
                this.isSpinner=false;
           }else{
                var individualDocs = PassfortIndividualDocNamesLabel.split(',');
                var lstOfdocMap =this.template.querySelector('c-passfort-document-upload-lwc').documentIdsString;
                lstOfdocMap.forEach(element => {
                    if(this.isBlankString(this.StringDocIds)){
                        this.StringDocIds=element.value;
                    }else{
                        this.StringDocIds=this.StringDocIds+','+element.value;
                    }
                });
                if(lstOfdocMap.length!=individualDocs.length){
                    this.showToastMessage('Error : Required documents missing ','Please provide all required documents to submit for compliance','error');
                    this.isSpinner=false;
                }else{
                    this.template.querySelector('lightning-record-edit-form').submit(fields);
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
                    transactionRecord['ParentDocumentIds']=this.StringDocIds;

                    lstTransactions.push(transactionRecord);
                    createPassfortTransactionRecords({
                        transactionRecords : JSON.stringify(lstTransactions),
                        recordId : this.recordId
                    }).then(result=>{
                        if(result.includes('success')){
                            this.showToastMessage('Success ','This record has been successfully submitted for compliance.','success');
                            this.isSpinner=false;
                            this.returnFromModal['isRecordSaved']=true;
                            this.close(this.returnFromModal);
                        }else if(result.includes('error')){
                            this.showToastMessage('Error ','This record failed to submit for compliance.','error');
                            this.isSpinner=false;
                        }
                    }).catch(error=>{
                        this.showToastMessage('Error ','This record failed to submit for compliance.','error');
                        this.isSpinner=false;
                    });
                    this.isSpinner=false;
                }
            } 
        }
    }
    //on click Save as Draft
    handleSubmit(event){
        event.preventDefault();
        this.isSpinner=true;
        this.clickedButton='handleSubmit';
        this.template.querySelector('.submitButton').click();
    }
    // On click Submit for Compliance
    handleSubmitForCompliance(event){
        this.isSpinner=true;
        event.preventDefault();
        this.clickedButton='handleSubmitForCompliance';
        this.template.querySelector('.submitButton').click();
    }
}