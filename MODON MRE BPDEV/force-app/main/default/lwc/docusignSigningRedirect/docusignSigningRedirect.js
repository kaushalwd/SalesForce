import { LightningElement, api, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CurrentPageReference } from 'lightning/navigation';
import getDocuSignSingingURL from '@salesforce/apex/OIC_DPGDocuSignDocumentAPIHelper.getDocuSignSingingURL';
import getEnvelopeStatusPage from '@salesforce/apex/OIC_DPGDocuSignDocumentAPIHelper.getEnvelopeStatusPage';
import getFinalSigningURL from '@salesforce/apex/SPAFinalCustomerCopy.getFinalSigningURL';

export default class DocusignSigningRedirect extends LightningElement {

    @track customerAccId;
    @track envelopeId;
    @track customerName;
    @track customerEmail;

    connectedCallback(){
        this.getDocuSignSingingURLAPI();
    }

    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference) {
            this.envelopeId = currentPageReference.state.envelopeId;
            this.customerAccId = currentPageReference.state.customerAccId;
            this.customerName = currentPageReference.state.customerName;
            this.customerEmail = currentPageReference.state.customerEmail;
            this.customerFinalCopy = currentPageReference.state.customerFinalCopy;
            if(currentPageReference.state.customerFinalCopy){
                this.customerFinalCopy = 'yes';
            } else {
                this.customerFinalCopy = 'no';
            }
        }
    }

    getDocuSignSingingURLAPI(){  
        getEnvelopeStatusPage({envelopeId:this.envelopeId
        }).then(result => {
            if(this.customerFinalCopy == 'yes'){
                getFinalSigningURL({accessToken:'', 
                                        envelopeId:this.envelopeId, 
                                        customerAccId:this.customerAccId,
                                        customerName:this.customerName,
                                        customerEmail:this.customerEmail
                    }).then(result => {
                        window.open(result, "_self");
                    }).catch(() => {});
            }else {
                if(result && (result == 'sent' || result == 'delivered' || result == 'timedout')){
                    getDocuSignSingingURL({accessToken:'', 
                                        envelopeId:this.envelopeId, 
                                        customerAccId:this.customerAccId,
                                        customerName:this.customerName,
                                        customerEmail:this.customerEmail
                    }).then(result => {
                        window.open(result, "_self");
                    }).catch(() => {});
                } else {
                        window.open("https://www.modon.com", "_self");
                }
            }
            
        }).catch(() => {});  
        
    }

   

    showSuccessToast() {
        const event = new ShowToastEvent({
            title: 'Success',
            message: 'Printed successfully.',
            variant: 'success',
            mode: 'dismissable'
        });
        this.dispatchEvent(event);
        this.navigateToRecordPage();
    }

    showErrorToast() {
        const event = new ShowToastEvent({
            title: 'Error',
            message: 'Error: Please check with Admin',
            variant: 'error',
            mode: 'dismissable'
        });
        this.dispatchEvent(event);
        this.navigateToRecordPage();
    }

    navigateToRecordPage(){
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.recordId,
                actionName: 'view'
            }
        });
    }
}