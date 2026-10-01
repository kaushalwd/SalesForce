import { LightningElement, wire , api , track } from 'lwc';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import getisActive from '@salesforce/apex/ObjectFieldMetadataController.getisActive';
import getStatusToRecordTypeMap from '@salesforce/apex/ObjectFieldMetadataController.getStatusToRecordTypeMap';
import { CloseActionScreenEvent } from "lightning/actions";

import { NavigationMixin } from 'lightning/navigation';
import { encodeDefaultFieldValues } from 'lightning/pageReferenceUtils';
import { getRecord } from 'lightning/uiRecordApi';
import STATUS_FIELD from '@salesforce/schema/SalesOrder__c.Status__c';

// Case Object
import CASE_OBJECT from '@salesforce/schema/Case';
import CASE_CATEGORY_FIELD from '@salesforce/schema/Case.CaseCategory__c';

export default class createNewServiceRequestLWC extends NavigationMixin(LightningElement) {

    sObjectColumns = [];
    sObjectFields =[];
    sObjectName ='ServiceRequest__c';
    caseInfo;
    isNext=false;
    isModel=false;
    srRecordTypes;
    isActive;
    selectedRtVal;
    srRecordtypeVal=[];
    selectedRecName;
    selectedRecTypMap=[];
    issrType=false;

    statusRTMap = {};
    salesOrderStatus;

    @api recordId;

    connectedCallback(){
        this.getisActiveField();


        //Load Metadata Mapping
        getStatusToRecordTypeMap({ objName: this.sObjectName })
            .then(result => {
                this.statusRTMap = result;
                this.autoNavigateIfApplicable();
            })
            .catch(error => {
                console.error('Metadata error:', error);
            });
    }

    closeAction() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    isExecuting = false;    

    @api async invoke() {
        if (this.isExecuting) {
            return;
        }  
        this.isExecuting = true;
        await this.sleep(2000);
        this.isExecuting = false;
    }  

    sleep(ms) {
        return new Promise((resolve) => setTimeout(resolve, ms));
    }

    // NAVIGATION METHOD
    autoNavigateIfApplicable() {

        if (!this.salesOrderStatus || !this.srRecordTypes || Object.keys(this.statusRTMap).length === 0) {
            return;
        }

        const expectedRT = this.statusRTMap[this.salesOrderStatus];


        if (expectedRT) {

            const rt = this.srRecordTypes.find(r => r.label === expectedRT);

            if (!rt) {
                console.error('RT not found for:', expectedRT);
                return;
            }

            const defaultValues = encodeDefaultFieldValues({
                SalesOrder__c: this.recordId
            });

            this[NavigationMixin.Navigate]({
                type: 'standard__objectPage',
                attributes: {
                    objectApiName: 'ServiceRequest__c',
                    actionName: 'new'
                },
                state: {
                    recordTypeId: rt.value,
                    defaultFieldValues: defaultValues,
                    backgroundContext: `/lightning/r/SalesOrder__c/${this.recordId}/view`
                }
            });

            this.dispatchEvent(new CloseActionScreenEvent());
        }
    }

    //GET SALESORDER STATUS
    @wire(getRecord, { recordId: '$recordId', fields: [STATUS_FIELD] })
    wiredSO({ data, error }) {
        if (data) {
            this.salesOrderStatus = data.fields.Status__c.value;
            this.autoNavigateIfApplicable();
        } else if (error) {
            console.error('Error fetching SalesOrder:', error);
        }
    }

    getisActiveField() {
        this.error = '';
        getisActive({ 'objName': this.sObjectName })
            .then(result => {
                this.isActive = result;
                
                if (this.isActive) {

                    // SHOW MODAL ONLY IF NOT AUTO CASE
                    if (!this.statusRTMap[this.salesOrderStatus]) {
                        this.isModel = true;
                        this.issrType = true;
                    }

                } else {
                    this.isModel = false;
                }
            })
            .catch(error => {
                this.error = error;
                console.error('Error fetching active field:', error);
            });
    }

    @wire(getObjectInfo, { objectApiName: 'ServiceRequest__c' })
    objectInfo({ error, data }) {
        if (data) {
            let serviceRequestRt = [];
            let SrRecordTypeValues =[];
            const recordTypes = data.recordTypeInfos;


            Object.keys(recordTypes).forEach(element => {
                if(!recordTypes[element].master){
                    if (recordTypes[element].name !== 'Service Request Management -ADM' && recordTypes[element].name !== 'Joint Owner Deletion') {

                        let formattedName = recordTypes[element].name.includes('-') 
                            ? recordTypes[element].name.split('-')[1].trim() 
                            : recordTypes[element].name;

                        serviceRequestRt.push({
                            "label" : formattedName, 
                            "value" : recordTypes[element].recordTypeId
                        });

                        SrRecordTypeValues.push({
                            "label" : recordTypes[element].name, 
                            "value" : recordTypes[element].name
                        });

                        this.srRecordTypes = serviceRequestRt;
                        this.srRecordtypeVal = SrRecordTypeValues;
                    }
                }
            });

            this.autoNavigateIfApplicable();

        } else if (error) {
            console.error('Error fetching object info:', error);
        }
    }

    getIdByName(rectypId) {
        const record = this.srRecordTypes.find(srRecordTypes => srRecordTypes.value === rectypId);
        return record ? record.label : null; 
    }

    handleNext(e) {


        const expectedRT = this.statusRTMap[this.salesOrderStatus];

        if (expectedRT && this.selectedRecName === expectedRT) {

            const defaultValues = encodeDefaultFieldValues({
                SalesOrder__c: this.recordId
            });

            this[NavigationMixin.Navigate]({
                type: 'standard__objectPage',
                attributes: {
                    objectApiName: 'ServiceRequest__c',
                    actionName: 'new'
                },
                state: {
                    recordTypeId: this.selectedRtVal,
                    defaultFieldValues: defaultValues,
                    backgroundContext: `/lightning/r/SalesOrder__c/${this.recordId}/view`
                }
            });

            this.dispatchEvent(new CloseActionScreenEvent());

        } else {
            this.isNext = true;
            this.isModel = true;
            this.isModelVal = false;
            this.issrType = false;

        }
    }

    handleChange(event){
        let srMap =[];
        this.selectedRtVal = event.detail.value;

        const srRecName = this.getIdByName(this.selectedRtVal);
        this.selectedRecName = srRecName;

        this.selectedRecTypMap.push({
            "label":srRecName,
            "value":this.selectedRtVal
        });

    }
    
    handleClose() {
        this.isModel = false;
        this.issrType = false;
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    handlePopUp(event){
        const isModelVal=event.detail;
        this.isModel=isModelVal;


        this.dispatchEvent(new CloseActionScreenEvent());
    }
}