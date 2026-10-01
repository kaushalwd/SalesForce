import { LightningElement, api, track , wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import eoiSubmissionCheck from '@salesforce/apex/SubmitEOIEgyptController.eoiSubmissionCheck';
import submitEoi from '@salesforce/apex/SubmitEOIEgyptController.submitEoi';
import { CloseActionScreenEvent, refreshView } from 'lightning/actions';


export default class submitEoiEgyptLwc extends NavigationMixin(LightningElement) {

    @api recordId;
    @track respWrap={};
    showPopup = false;
    comments;


    @wire(eoiSubmissionCheck, { eoiId: '$recordId' })
    wiredEoiSubmissionCheck({ error, data }) {
        if (data) {
            this.respWrap = data;

            if (data.result === 'Success') {
                this.showPopup = true;
            } else {
                this.showErrorToast(data.result);
            }
        } else if (error) {
            this.showErrorToast('An error occurred while checking EOI submission.');
        }
    }

    /*connectedCallback(){
        if(this.recordId == undefined || this.recordId == null || this.recordId == ''){
            const urlParams = new URLSearchParams(window.location.search);
            const reccId = urlParams.get('recordId');
            this.recordId = reccId;
        }else{
            //do nothing
        }

        this.eoiSubmissionCheckCallout();
    }

    eoiSubmissionCheckCallout(){

        var requestWrap = {
            eoiId: this.recordId,
            comments: this.comments
        };

        eoiSubmissionCheck({requestWrapParam:JSON.stringify(requestWrap)}).then(result => {

            // this.respWrap = result

            if(result.result == 'Success'){
                // this.showSuccessToast();
                // setTimeout(function() {
                //     window.location.reload();
                // }, 1000);
                this.showPopup = true;
            } else {
                this.showErrorToast(result.result);
            }

            

        }).catch(error => {
        });
    }*/

    submitEoiCallout(){
    
        var requestWrap = {
            eoiId: this.recordId,
            comments: this.comments
        };
    
        submitEoi({requestWrapParam:JSON.stringify(requestWrap)}).then(result => {
    
            
            this.showSuccessToast();
    
        }).catch(error => {
            this.showErrorToast('This EOI is currently in an approval process.');
        });
    }

    showSuccessToast() {
        const event = new ShowToastEvent({
            title: 'Success',
            message: 'EOI submitted successfully.',
            variant: 'success',
            mode: 'dismissable'
        });
        this.dispatchEvent(event);
        this.dispatchEvent(new CloseActionScreenEvent());
        let url = '/'+ this.recordId;
        window.location.assign(url);
        // this.navigateToRecordPage();
    }

    showErrorToast(result) {
        const event = new ShowToastEvent({
            title: 'Error',
            message: result,
            variant: 'error',
            mode: 'dismissable'
        });
        this.dispatchEvent(event);
        this.dispatchEvent(new CloseActionScreenEvent());
        //this.navigateToRecordPage();
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

    handleComments(){
        this.comments = this.template.querySelector('lightning-textarea').value;
    }
}