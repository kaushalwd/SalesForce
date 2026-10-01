import { LightningElement,track,api, wire } from 'lwc';
import LightningModal from 'lightning/modal';
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import createPassfortTransactionRecords from '@salesforce/apex/PassfortRelatedEntitiesController.createPassfortTransactionRecords';
import upsertShareholderRecords from '@salesforce/apex/PassfortRelatedEntitiesController.upsertShareholderRecords';
import getShareholderRecords from '@salesforce/apex/PassfortRelatedEntitiesController.getShareholderRecords';
import getNationalityOptions from '@salesforce/apex/PassfortRelatedEntitiesController.getNationalityOptions';
import deleteDocumentPlaceholders from '@salesforce/apex/PassfortRelatedEntitiesController.deleteDocumentPlaceholders';
import deleteShareholderRecord from '@salesforce/apex/PassfortRelatedEntitiesController.deleteShareholderRecord';
import PassfortCompanyDocNamesLabel from '@salesforce/label/c.PassfortCompanyDocNames';
import PassfortIndividualDocNamesLabel from '@salesforce/label/c.PassfortIndividualDocNames';
import isAccessSubmitForCompliance from '@salesforce/apex/PassfortRelatedEntitiesController.isAccessSubmitForCompliance';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
//Added by Rushi-28/09/2026 - Submit for Compliance is blocked when the Passfort approval is no longer valid
import PASSFORT_APPROVED_VALID_FIELD from '@salesforce/schema/Account.Is_Passfort_Approved_Valid__c';
const FIELDS = ['Contact.SourceOfIncome__c'];
const COMPLIANCE_EXPIRED_MESSAGE = 'Compliance is already expired. Please complete the compliance check before proceeding.';

export default class PassfortCompanyFormLwc extends LightningModal {
    @api content;
    @api objectApiName='Account';
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
    @track
    isCommercialProject = false;
    @track
    isSecondaryMarket = false;

    /** ADDED to Show "Other Source Of Income" Dynamic field By Dselvam @ 28/12/2025 **/
    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredAccount({ error, data }) {
        if (data) {
            const sourceOfIncome = data.fields.SourceOfIncome__c?.value;

            if (sourceOfIncome === 'Others (please specify)') {
                this.isOtherIncome = true;
            }
        } else if (error) {
            console.error('Error fetching SourceOfIncome__pc', error);
        }
    }
    //Added by Rushi-28/09/2026 - separate wire on purpose: FIELDS above is a Contact field, and mixing an Account
    //field into the same getRecord call would fail the whole wire. The value captured when the form opens is the
    //source of truth; anything other than an explicit true (false, not loaded, no field access) is treated as not valid.
    isPassfortApprovedValid = false;
    @wire(getRecord, { recordId: '$recordId', fields: [PASSFORT_APPROVED_VALID_FIELD] })
    wiredPassfortApprovedValid({ error, data }) {
        if (data) {
            this.isPassfortApprovedValid = getFieldValue(data, PASSFORT_APPROVED_VALID_FIELD) === true;
        } else if (error) {
            this.isPassfortApprovedValid = false;
            console.error('Error fetching Is_Passfort_Approved_Valid__c', error);
        }
    }
    connectedCallback(){
        this.recordId=this.content.EntityRecordId;
        this.objectApiName=this.content.EntityAPIName;

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
        this.getshareholders();
    }
    
    getshareholders(){
        this.isSpinner=true;
        getShareholderRecords({
            AccountId:this.content.EntityRecordId
        }).then(result=>{
            this.isSpinner=false;
            this.showShareholderDatatable=true;
            this.shareHolderRecords=[];
            for(var i=0;i< result.length;i++){
                var index=i+1;
                var shareholderObject={};
                shareholderObject['key']=index;
                shareholderObject['Nationality__c']=result[i].Nationality__c;
                shareholderObject['Birthdate']=result[i].Birthdate;
                shareholderObject['OwnershipPercentage__c']=result[i].OwnershipPercentage__c;
                shareholderObject['FirstName']=result[i].FirstName;
                shareholderObject['LastName']=result[i].LastName;
                shareholderObject['Id']=result[i].Id;
                shareholderObject['AccountId']=result[i].AccountId;
                shareholderObject['RecordTypeId']=result[i].RecordTypeId;
                this.shareHolderRecords.push(shareholderObject);
            }
        }).catch(error=>{
            this.showToastMessage('Error ','Error in getting ShareHolder records','error');
        });
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

    handleChangeLegalStructure(event){
        this.LegalStructure=event.target.value;
        if(this.LegalStructure=="Others"){
            this.isOtherLegalStructure=true;
        }
        this.isOnChange=true;
    }

    handleChangeSourceOfIncome(event){
        this.SourceOfIncome=event.target.value;
        if(this.SourceOfIncome=="Others (please specify)"){
            this.isOtherSourceOfIncome=true;
        }else{
            this.isOtherSourceOfIncome=false;
        }
        this.isOnChange=true;
    }

    upsertShareholders(shareholderRow){
        var isMissingFields= false;
            if(this.isBlankString(shareholderRow.FirstName)|| this.isBlankString(shareholderRow.LastName)||
               this.isBlankString(shareholderRow.OwnershipPercentage__c)|| this.isBlankString(shareholderRow.Nationality__c)||
               this.isBlankString(shareholderRow.Birthdate)){
                    isMissingFields=true;
            }
        if(isMissingFields){
            this.showToastMessage('Error ','Please fill up all required fields of Shareholder','error');
        }else{
            upsertShareholderRecords({
                conShareholder : shareholderRow
            }).then(result=>{
                if(result.includes('success')){
                    this.getshareholders();
                     this.template.querySelector('c-passfort-document-upload-lwc').getdocuments(); //to get documents for new shareholder
                     this.showToastMessage('Success ','Shareholder record is successfully saved.','success');
                }else if(result.includes('error')){
                    this.showToastMessage('Error ','Shareholder record is not saved.','error');
                }
            }).catch(error => {
                this.showToastMessage('Error ','Shareholder record is not saved.','error');
            })
        }
    }
    
    //to add new blank row for share holder details
    handleAddRow(event){
        var index= this.shareHolderRecords.length+1;
        var shareholderObject={};
        shareholderObject['key']=index;
        shareholderObject['Nationality__c']='';
        shareholderObject['Birthdate']='';
        shareholderObject['OwnershipPercentage__c']=0;
        shareholderObject['FirstName']='';
        shareholderObject['LastName']='';
        shareholderObject['AccountId']=this.content.EntityRecordId;
        shareholderObject['RecordTypeId']='';
        this.shareHolderRecords.push(shareholderObject);
    }

    //to save shareholder record
    handleSaveRow(event){
        var rows = JSON.parse(JSON.stringify(this.shareHolderRecords));
        var rowIndex=event.target.getAttribute("data-row-index");
        var row=this.shareHolderRecords[rowIndex];
        this.upsertShareholders(row);
    }

    //to delete shareholder record
    handleDeleteRow(event){
        var rows = JSON.parse(JSON.stringify(this.shareHolderRecords));
        var rowIndex=event.target.getAttribute("data-row-index");
        var row=this.shareHolderRecords[rowIndex];
        if(row!=null && row.LastName==''){
            rows.splice(rowIndex, 1);
            this.shareHolderRecords = JSON.parse(JSON.stringify(rows));
        }
        else{
        deleteShareholderRecord({
            conShareholder : row
        }).then(result=>{      
          if(result.includes('success')){     
            rows.splice(rowIndex, 1);
            this.shareHolderRecords = JSON.parse(JSON.stringify(rows));
            for(var i=0; i<this.shareHolderRecords.length; i++){
                var index=i+1;
                this.shareHolderRecords[i].key=index;
            }
            this.getshareholders();
            this.template.querySelector('c-passfort-document-upload-lwc').getdocuments(); 
            this.showToastMessage('Success ','Shareholder record is deleted.','success');
          } else {
            this.showToastMessage('Error ','Shareholder record is not deleted.','error');
          }        
        }).catch(error => {
            this.showToastMessage('Error ','Shareholder record is not deleted.','error');
        }) 
    }       
    }

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
            if(sourceOfIncomeValue.value=="Others (please specify)"){
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
        if(this.clickedButton!="handleSubmitForCompliance" && this.clickedButton=="handleSubmit"){ //to save as draft
            this.template.querySelector('lightning-record-edit-form').submit(fields);
            this.showToastMessage('Success ','Details are successfully saved','success');
            this.isSpinner=false;
            this.returnFromModal["isRecordSaved"]=true;
            this.close(this.returnFromModal);
        }else if(this.clickedButton=="handleSubmitForCompliance" && this.clickedButton!="handleSubmit"){ //to save and create transaction records
            if(
                this.isBlankString(fields.LegalStructure__c) ||
                this.isBlankString(fields.DateOfEstablishment__c) ||
                this.isBlankString(fields.UnifiedNumber__c) ||
                this.isBlankString(fields.TradeLicenseExpiryDate__c) ||
                this.isBlankString(fields.UAEVATRegisterNumber__c) || 
                this.isBlankString(fields.PurposeOfTransaction__c) || 
                this.isBlankString(fields.ShippingCity) ||
                this.isBlankString(fields.ShippingCountry) ||
                this.isBlankString(fields.ShippingPostalCode) ||
                this.isBlankString(fields.ShippingState) ||
                this.isBlankString(fields.Phone) || 
                this.isBlankString(fields.Description)|| 
                this.isBlankString(fields.SourceOfIncome__c) ||
                this.isBlankString(fields.DeliveryChannel__c)|| 
                this.isBlankString(fields.NoOfPropertyPurchasedWithModon__c)
                || (fields.LegalStructure__c=="Other" && this.isBlankString(fields.OtherLegalStructure__c)) ||
                (fields.SourceOfIncome__c=="Others (please specify)" && this.isBlankString(fields.OtherSourceOfIncome__c))
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
                //Added for commertial plots by Siva
                transactionRecord['IsCommercialProject'] = this.isCommercialProject;
                //Added flag for commertial plots by Siva-15/08/2026
                transactionRecord['IsSecondaryMarket'] = this.isSecondaryMarket;
 
                lstTransactions.push(transactionRecord);                
                
                this.shareHolderRecords.forEach(shareHolderContact=>{
                    docIds ='';
                    lstOfdocMap.forEach(doc=>{
                        if(doc.key.includes(shareHolderContact.FirstName+' '+shareHolderContact.LastName))
                            docIds = docIds==''?doc.value:docIds+','+doc.value;
                    })
                    var transactionRecord={};
                    transactionRecord['ApprovalStatus']=shareHolderContact.PassfortApprovalStatus__c;
                    transactionRecord['EntityAPIName']='Contact';
                    transactionRecord['EntityRecordId']=shareHolderContact.Id;
                    transactionRecord['EntityType']='Shareholder';
                    transactionRecord['Name']=shareHolderContact.FirstName+' '+shareHolderContact.LastName;
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

        //Added by Rushi-28/09/2026 - must run before every other Submit for Compliance check (required fields, documents)
        if (!this.isPassfortApprovedValid) {
            this.showToastMessage('Error', COMPLIANCE_EXPIRED_MESSAGE, 'error');
            return;
        }

        this.isButtonDisabled = true;
        setTimeout(() => {
            this.clickedButton='handleSubmitForCompliance';
            this.template.querySelector('.submitButton').click();
        }, 1000)
    }

    handleChangeFirstName(event){
        this.shareHolderRecords[event.target.getAttribute("data-row-index")].FirstName = event.target.value;
    }
    handleChangeLastName(event){
        this.shareHolderRecords[event.target.getAttribute("data-row-index")].LastName = event.target.value;
    }
    handleChangeOwnershipPercentage(event){
        this.shareHolderRecords[event.target.getAttribute("data-row-index")].OwnershipPercentage__c = event.target.value;
    }
    handleChangeNationality(event){
        this.shareHolderRecords[event.target.getAttribute("data-row-index")].Nationality__c = event.target.value;
    }
    handleChangeBirthdate(event){
        this.shareHolderRecords[event.target.getAttribute("data-row-index")].Birthdate = event.target.value;
    }

    handleCommercialChange(event) {
        this.isCommercialProject = event.target.checked;
    }
    handleSecondaryMarketChange(event) {
        this.isSecondaryMarket = event.target.checked;
    }
}