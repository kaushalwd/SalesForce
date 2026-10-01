import { LightningElement,track,api, wire} from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getSalesOrderDetails from '@salesforce/apex/ChequesReceivedAckController.getSalesOrderDetails';
import generatePDF from '@salesforce/apex/ChequesReceivedAckController.generatePDF';
import sendEmailToCustomer from '@salesforce/apex/ChequesReceivedAckController.sendEmailToCustomer';


export default class chequesReceivedAck extends LightningElement {
    
    @api recordId;

    @track isLoading = true;
    @track showUI = false;
    @track isDownloadDisabled = false;
    @track isSendEmailDisabled = false;
    
    @track soDetails = {};
    @track soPaymentDetails = [];

    @track isRendered = false;

    connectedCallback(){}

    renderedCallback() {
        if(!this.isRendered){
            const urlSearchParams = new URLSearchParams(window.location.search);
            this.recordId = urlSearchParams.get('recordId');
            if (this.recordId ) {
                this.isRendered = true;
                this.getSaleOrderDetails();
            }
        }
    }

    getSaleOrderDetails(){
        this.isLoading = true; 
        getSalesOrderDetails({ recordId: this.recordId})
        .then(result => {
            this.soDetails = result;
            this.isLoading = false;
            this.showUI = true;            
        })                  
        .catch(error => {
            this.isLoading = false;
            this.error = result.error;
            this.showToastMessage('error', JSON.stringify(this.error),'Error');
        }); 
    }

    handleSendEmail(){
        this.isLoading = true;
        sendEmailToCustomer({salesOrderId: this.recordId})
        .then(() => {
            this.showToast(
                'Success',
                'Cheque Received Acknowledgement has been sent successfully to the customer\'s Email.',
                'success'
            );
            this.resetData();
        })
        .catch((error) => {
                console.error('Error while sending an email:', error);
            })
            .finally(() => {
            this.isLoading = false;
        });
    }

    resetData(){
        this.soDetails = {};
        this.soPaymentDetails = [];
        this.showUI = false;
        this.isDownloadDisabled = true;
        this.isSendEmailDisabled = true;
    }
    handleDownload() {
        this.isLoading = true;
        generatePDF({salesOrderId: this.recordId})
        .then((vfPageUrl) => {
                if (vfPageUrl) {
                    window.open(vfPageUrl, '_blank'); // Open the VF page in a new tab
                    this.isDownloadDisabled = false;
                    this.showToast('Ready for Download!');
                    this.checkAndCleanUp();
                } else {
                    this.showToast('Error generating PDF', 'error');
                }                
            })
            .catch((error) => {
                console.error('Error generating PDF:', error);
            })
            .finally(() => {
            this.isLoading = false;
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
}