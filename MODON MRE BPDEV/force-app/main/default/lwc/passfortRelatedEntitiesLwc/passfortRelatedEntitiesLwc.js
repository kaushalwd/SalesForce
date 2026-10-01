import { LightningElement, track,api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getEntityRecords from '@salesforce/apex/PassfortRelatedEntitiesController.getEntityRecords';
import passfortEntityFormLwc from 'c/passfortEntityFormLwc';
import passfortCompanyFormLwc from 'c/passfortCompanyFormLwc';

export default class PassfortRelatedEntitiesLwc extends LightningElement {
    @api recordId;
    noOfRecords=0;
    @track records=[];
    variantColor;

    //get related Account/Contact records
    @wire(getEntityRecords,{recordId:'$recordId'})
    wiredContact({error,data}){
        if(data){
            this.noOfRecords=data.length;
            var noOfRejectedEntities=0;
            var noOfInReviewEntities=0;
            var noOfApprovedEntities=0;
            var noOfOtherEntities=0;
            var i=0;
            data.forEach(element => {
                var objectElement={};
                objectElement=Object.assign({},element);
                objectElement['Id']=i++;
                if(objectElement.ApprovalStatus=="Approved"){
                    objectElement['ApprovalVariantColor']="success";
                    objectElement['ApprovalIconName']="utility:target";
                    noOfApprovedEntities+=1;
                }else if(objectElement.ApprovalStatus=="Rejected" || objectElement.ApprovalStatus=="Canceled"){
                    objectElement['ApprovalVariantColor']="error";
                    objectElement['ApprovalIconName']="utility:target";
                    noOfRejectedEntities+=1;
                }else if(objectElement.ApprovalStatus=="Applied" || objectElement.ApprovalStatus=="In review"){
                    objectElement['ApprovalVariantColor']="warning";
                    objectElement['ApprovalIconName']="utility:target";
                    noOfInReviewEntities+=1;
                }else{
                    noOfOtherEntities+=1;
                }

                if(objectElement.RiskStatus=="Low"){
                    objectElement['RiskVariantColor']="success";
                    objectElement['RiskIconName']="utility:down";
                }else if(element.RiskStatus=="High"){
                    objectElement['RiskVariantColor']="error";
                    objectElement['RiskIconName']="utility:up";
                }else{
                }
                this.records.push(objectElement);    
            });
            if(noOfApprovedEntities>0 && noOfOtherEntities==0 && noOfRejectedEntities==0 && noOfInReviewEntities==0){
                this.variantColor="success";
            }else if(noOfRejectedEntities>0){
                this.variantColor="error";
            }else if(noOfInReviewEntities>0){
                this.variantColor="warning";
            }else if(noOfOtherEntities>0 && noOfApprovedEntities==0 && noOfRejectedEntities==0 && noOfInReviewEntities==0){
                
            }
            this.error=undefined;
        }else if(error){
            this.error=error;
            this.data=undefined;
        }
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

    //handle button actions
    handleButtonMenuAction(event){
        const actionName= event.target.label;
        const row = event.target.value;
        if(actionName=='Edit'){
            if(row.EntityAPIName=='Contact'){
                const result = passfortEntityFormLwc.open({
                    size: 'medium',
                    description: 'access',
                    content:row,
                }).then( result =>{
                    if(!this.isBlankString(result)){
                        if(result.isRecordSaved){
                            window.location.reload();
                        }
                    }  
                });
            }else if(row.EntityAPIName=='Account'){
                const result = passfortCompanyFormLwc.open({
                    size: 'medium',
                    description: 'access',
                    content:row,
                }).then( result =>{
                    if(!this.isBlankString(result)){
                        if(result.isRecordSaved){
                            window.location.reload();
                        }
                    }
                });
            }
        }
    }
}