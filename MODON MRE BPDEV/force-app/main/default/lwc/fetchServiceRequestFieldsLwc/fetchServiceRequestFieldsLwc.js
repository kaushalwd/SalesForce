import { LightningElement, api, track } from 'lwc';
import getObjInfo from '@salesforce/apex/ObjectFieldMetadataController.getObjInfo';
import getCaseObjData from '@salesforce/apex/FetchServiceRequestContoller.getCaseObjData';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import updateCaseWithServiceRequest from '@salesforce/apex/FetchServiceRequestContoller.updateCaseWithServiceRequest';
import getSalesOrders from '@salesforce/apex/FetchServiceRequestContoller.getSalesOrders';

export default class fetchServiceRequestFieldsLwc extends LightningElement {
    @api sobjectname;
    @api selectedrt;
    @api selectedrecmap = [];
    @api currentrecid;

    @track srReadOnlyFieldMap = [];
    @track srOptionalFieldMap = [];
    @track srRequiredFieldMap = [];
    @track selectedType;
    isPopUp = false;
    isParentModel = false;
    srRecName;
    srFields = [];
    unitId;
    type;
    accountId;
    error;
    @track salesOrderOptions = [];

    connectedCallback() {
        this.isPopUp = true;
        this.srRecName = this.getIdByName(this.selectedrt);
        this.isParentModel = false;
        this.getCompleteObjInfo();
        this.getCaseObjInfo();
    }

    getIdByName(rectypId) {
        const record = this.selectedrecmap.find(rec => rec.value === rectypId);
        return record ? record.label : null;
    }

    get typeOptions() {
        const options = [
            { label: 'Normal', value: 'Normal' },
            { label: 'Next of Kin', value: 'Next of Kin' },
            { label: 'Court Order', value: 'Court Order' }
        ];
   
        
        return options;
    }
    handleTypeChange(event) {
        this.selectedType = event.detail.value;
    }

    getCaseObjInfo() {
        getCaseObjData({ recordId: this.currentrecid })
            .then(result => {
                if (result && result.length > 0) {
                    let caseData = JSON.parse(JSON.stringify(result));
                    caseData.forEach(res => {
                        if (res.Id) {
                            this.accountId = res.AccountId;
                            this.unitId = res.Unit__c;
                           /* if (this.unitId) {
                                this.fetchSalesOrders(); 
                            }*/
                        }
                    });
                }
            })
            .catch(error => {
                console.error('Error fetching Case data:', error);
                this.error = error;
            });
    }
    get soFilter() {
        return this.soIds ? 
            JSON.stringify({
                filter: {
                    field: 'Id',
                    operator: 'IN',
                    values: this.soIds
                }
            }) : null;
    }
    fetchSalesOrders() {
        getSalesOrders({ unitId: this.unitId })
            .then(data => {
                if (data) {
                    this.salesOrderOptions = data.map(order => ({
                        label: order.Name,
                        value: order.Id
                    }));
                    this.soIds = data.map(order => order.Id); // Store SO Ids for lookup filtering

                }
            })
            .catch(error => {
                console.error('Error fetching Sales Orders:', error);
            });
    }
    
    
    
handleSalesOrderChange(event) {
    this.selectedSalesOrder = event.detail.value;
}
    getCompleteObjInfo() {
        getObjInfo({
            sObjectName: this.sobjectname,
            sObjectRecordType: this.srRecName,
            sOjectRecId: this.currentrecid
        })
            .then(result => {
                if (result) {
                    let fieldsData = result.columns;
                    let srFieldMap = [];
                    let srOptionalFldsMap = [];
                    let srRequiredFldsMap = [];
                    let srReadOnlyFldsMap = [];

                    Object.keys(fieldsData).forEach(element => {
                        srFieldMap.push(fieldsData[element].fieldName);
                        if (fieldsData[element].fieldType === 'OptionalFields') {
                            srOptionalFldsMap.push({ value: fieldsData[element].label, key: fieldsData[element].fieldName });
                        } else if (fieldsData[element].fieldType === 'RequiredFields') {
                            srRequiredFldsMap.push({ value: fieldsData[element].label, key: fieldsData[element].fieldName });
                        } else if (fieldsData[element].fieldType === 'ReadOnlyFields') {
                            srReadOnlyFldsMap.push({ value: fieldsData[element].label, key: fieldsData[element].fieldName });
                        }
                    });

                    this.srFields = srFieldMap;
                    this.srReadOnlyFieldMap = srReadOnlyFldsMap;
                    this.srOptionalFieldMap = srOptionalFldsMap;
                    this.srRequiredFieldMap = srRequiredFldsMap;
                }
            })
            .catch(error => {
                console.error('Error fetching Object Info:', error);
                this.error = error;
            });

        this.isParentModel = false;
    }

    handleSubmit(event) {
        event.preventDefault(); // Prevent default form submission
        const fields = event.detail.fields;
        //fields.Type__c = this.selectedType; 
        //fields.SalesOrder__c = this.selectedSalesOrder;

        this.template.querySelector('lightning-record-edit-form').submit(fields);
    }

    handleSuccess(event) {
        const serviceRequestId = event.detail.id; // Get the newly created Service Request Id
    if(serviceRequestId){
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Success!',
                message: 'Service Request created and linked to Case successfully!',
                variant: 'success'
            })
        );
    }
        // Call Apex to update the Case object
        updateCaseWithServiceRequest({ 
            caseId: this.currentrecid, 
            serviceRequestId: serviceRequestId 
        })
        .then(() => {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success!',
                    message: 'Service Request created and linked to Case successfully!',
                    variant: 'success'
                })
            );
        })
        .catch(error => {
            console.error('Error updating Case:', error);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: error.body.message || 'Failed to update Case record',
                    variant: 'error'
                })
            );
        });

        


        // Close the modal
        this.isPopUp = false;
        this.isParentModel = false;
        this.sendisModelToParent();
    }
    

    handleError(event) {
        console.error('Error updating record:', event.detail);
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error',
                message: event.detail.message || 'Something went wrong',
                variant: 'error'
            })
        );
    }
    
    sendisModelToParent() {
       
        this.dispatchEvent(new CustomEvent('result', { detail: this.isParentModel }));
    }

    handleClose() {
        this.sendisModelToParent();
        this.isPopUp = false;
        this.isParentModel = false;
    }
}