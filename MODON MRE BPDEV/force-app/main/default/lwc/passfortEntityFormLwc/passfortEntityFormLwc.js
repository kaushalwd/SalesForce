import { LightningElement,track,api, wire } from 'lwc';
import LightningModal from 'lightning/modal';
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import PassfortIndividualDocNamesLabel from '@salesforce/label/c.PassfortIndividualDocNames';
import createPassfortTransactionRecords from '@salesforce/apex/PassfortRelatedEntitiesController.createPassfortTransactionRecords';
import isAccessSubmitForCompliance from '@salesforce/apex/PassfortRelatedEntitiesController.isAccessSubmitForCompliance';
//Added for Individual entity type enhancements - KYC banner/warning & Payment Method/Delivery Channel defaults by Arvind-07/07/2026 - Version 5.0
import getKYCAndSalesOrderDetails from '@salesforce/apex/PassfortRelatedEntitiesController.getKYCAndSalesOrderDetails';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
//Added by Rushi-28/09/2026 - Submit for Compliance is blocked when the Passfort approval is no longer valid
import PASSFORT_APPROVED_VALID_FIELD from '@salesforce/schema/Contact.Is_Passfort_Approved_Valid__c';
//For Person Accounts the source of truth is the Account's own Is_Passfort_Approved_Valid__c, not the Contact copy (__pc)
import IS_PERSON_ACCOUNT_FIELD from '@salesforce/schema/Contact.Account.IsPersonAccount';
import ACCOUNT_PASSFORT_APPROVED_VALID_FIELD from '@salesforce/schema/Contact.Account.Is_Passfort_Approved_Valid__c';
const FIELDS = ['Contact.SourceOfIncome__c'];
const COMPLIANCE_EXPIRED_MESSAGE = 'Compliance is already expired. Please complete the compliance check before proceeding.';

export default class PassfortEntityFormLwc extends LightningModal {
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
    @track isButtonDisabled = false;
    BaseURL;
    StringDocIds='';
    //Added flag for commertial plots by Sireesha-18/04/2026
        @track isCommercialProject = false;
     //Added flag for commertial plots by Siva-15/08/2026
     @track isSecondaryMarket = false;
    //Added for Individual entity type enhancements by Arvind-07/07/2026 - Version 5.0
        @track PaymentMethodDefault;
        @track DeliveryChannelDefault;
        @track kycStatus;
    //Added by Arvind-07/07/2026 - Version 5.6 - defaults NoOfPropertyPurchasedWithModon__c to 0 when blank, for every entity type
        @track NoOfPropertyDefault;
    @track returnFromModal={
        isRecordSaved:false
    }
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
    //Added by Rushi-28/09/2026 - value captured when the form opens is the source of truth for Submit for Compliance.
    //Anything other than an explicit true (false, not loaded, no field access) is treated as not valid.
    //Person Account -> Account.Is_Passfort_Approved_Valid__c; business Contact -> Contact.Is_Passfort_Approved_Valid__c.
    //Account fields are optional so a business Contact still loads if the user can't read its parent Account.
    isPassfortApprovedValid = false;
    @wire(getRecord, {
        recordId: '$recordId',
        fields: [PASSFORT_APPROVED_VALID_FIELD],
        optionalFields: [IS_PERSON_ACCOUNT_FIELD, ACCOUNT_PASSFORT_APPROVED_VALID_FIELD]
    })
    wiredPassfortApprovedValid({ error, data }) {
        if (data) {
            const validityField = getFieldValue(data, IS_PERSON_ACCOUNT_FIELD) === true
                ? ACCOUNT_PASSFORT_APPROVED_VALID_FIELD
                : PASSFORT_APPROVED_VALID_FIELD;
            this.isPassfortApprovedValid = getFieldValue(data, validityField) === true;
        } else if (error) {
            this.isPassfortApprovedValid = false;
            console.error('Error fetching Is_Passfort_Approved_Valid__c', error);
        }
    }
    //Added for Individual entity type enhancements by Arvind-07/07/2026 - Version 5.0 - true only when EntityType is 'Individual'
    get isIndividualEntity(){
        return this.content.EntityType=='Individual';
    }
    //Added for Individual entity type enhancements by Arvind-07/07/2026 - Version 5.0 - shows KYC-not-completed banner only when opened from a Sales Order and KYC isn't Active yet
    get showKYCWarning(){
        return this.isIndividualEntity && this.content.parentObjectName=='SalesOrder__c' && this.kycStatus!='KYC Active';
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
        if(this.SourceOfIncome=="Others (please specify)"){
            this.isOtherIncome=true;
        }
        //Added by Arvind-07/07/2026 - Version 5.0
        //Payment Method (from Sales Order's Modeofpayment__c) and Delivery Channel defaults now run the same way
        //for every Entity Type (not just Individual), so there's a single default-value code path for both.
        //KYC status is still only used to drive the Individual+Sales-Order banner further below.
        //Form is held behind the spinner until this resolves, so these field value bindings are set once
        //before the record-edit-form mounts - never changed reactively afterwards.
        this.isSpinner=true;
        getKYCAndSalesOrderDetails({
            contactId : this.content.EntityRecordId,
            parentObjectName : this.content.parentObjectName,
            parentRecordId : this.content.parentRecordId
        }).then(result=>{
            this.kycStatus=result.KYCStatus;
            //Delivery Channel default only applied if it matched a real picklist value in Apex - otherwise stays blank and user selects manually
            if(result.DeliveryChannelDefault){
                this.DeliveryChannelDefault=result.DeliveryChannelDefault;
            }
            if(this.content.parentObjectName=='SalesOrder__c' && result.ModeOfPayment){
                this.PaymentMethodDefault=result.ModeOfPayment;
            }
            //Added by Arvind-07/07/2026 - Version 5.6 - NoOfPropertyPurchasedWithModon__c defaults to 0 when the Contact doesn't already have a value
            this.NoOfPropertyDefault=result.NoOfPropertyDefault;
            //if ModeOfPayment/DeliveryChannelDefault is null/blank, the fields stay undefined so user selects manually
            this.isSpinner=false;
        }).catch(error=>{
            console.error('getKYCAndSalesOrderDetails error => ', error);
            this.isSpinner=false;
        });
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
        if(this.SourceOfIncome=="Others (please specify)"){
            this.isOtherIncome=true;
        }else{
            this.isOtherIncome=false;
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

    //Added by Arvind-07/07/2026 - Version 5.2
    //Fires only once Salesforce actually confirms the record-edit-form's save succeeded.
    //For Save as Draft (handleSubmit), this now drives the success toast + modal close, replacing the old
    //hardcoded toast that used to fire immediately regardless of the real outcome.
    //For Submit for Compliance, the success toast/close is still driven by createPassfortTransactionRecords
    //further below (unchanged) - so we don't duplicate a toast/close here for that branch.
    handleSuccess(event){
        if(this.clickedButton=='handleSubmit'){
            this.showToastMessage('Success ','Details are successfully saved','success');
            this.isSpinner=false;
            this.returnFromModal["isRecordSaved"]=true;
            this.close(this.returnFromModal);
        }
    }

    //Added by Arvind-07/07/2026 - Version 5.2
    //Surfaces the real Salesforce error (e.g. required field, validation rule, invalid picklist value)
    //instead of it being silently hidden behind a fake success toast.
    handleError(event){
        this.isSpinner=false;
        this.isButtonDisabled=false;
        const errorMessage = (event.detail && (event.detail.detail || event.detail.message)) || 'Failed to save the record. Please check the required fields and try again.';
        this.showToastMessage('Error',errorMessage,'error');
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
            //Added by Arvind-07/07/2026 - Version 5.2
            //Success toast + modal close now happen in handleSuccess, only once Salesforce actually confirms the
            //save - previously this fired immediately regardless of whether the save actually succeeded, which
            //hid real validation errors behind a false "success" toast.
        }else if(this.clickedButton=="handleSubmitForCompliance" && this.clickedButton!="handleSubmit"){
            if(
                 this.isBlankString(fields.Birthdate) ||
                 this.isBlankString(fields.Nationality__c) ||
                 this.isBlankString(fields.GenderIdentity) ||
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
                 (this.isNotPrimaryContact && fields.SourceOfIncome__c=="Others (please specify)" && this.isBlankString(fields.OtherSourceOfIncome__c))|| 
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
                if((lstOfdocMap.length!=individualDocs.length && fields.UAE_Resident_Status__c =='Resident') || (fields.UAE_Resident_Status__c =='Non-Resident' && lstOfdocMap.length === 0)){
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
                    //Added for commertial plots by sireesha
                    transactionRecord['IsCommercialProject'] = this.isCommercialProject;
                    //Added flag for commertial plots by Siva-15/08/2026
                    transactionRecord['IsSecondaryMarket'] = this.isSecondaryMarket;
               
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
                            const errorMessage = result ? result.replace(/^error\s*:\s*/i, '') : 'This record failed to submit for compliance.';
                                this.showToastMessage(
                                    'Error',
                                    errorMessage,
                                    'error'
                                );
                                this.isSpinner = false;
                            //this.showToastMessage('Error ','This record failed to submit for compliance.','error');
                            this.isSpinner=false;
                        }
                    }).catch(error=>{
                        console.error('createPassfortTransactionRecords error => ', error);

                            this.showToastMessage(
                                'Error',
                                error?.body?.message || 'This record failed to submit for compliance.',
                                'error'
                            );
                            this.isSpinner = false;
                            //this.isButtonDisabled = false;
                       // this.showToastMessage('Error ','This record failed to submit for compliance.','error');
                       // this.isSpinner=false;
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
     //Added handle method  for commertial plots by Sireesha-18/04/2026
    handleCommercialChange(event) {
    this.isCommercialProject = event.target.checked;
}

 //Added flag for commertial plots by Siva-15/08/2026
   handleSecondaryMarketChange(event) {
    this.isSecondaryMarket = event.target.checked;
}

    // On click Submit for Compliance
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
}