import { LightningElement ,api} from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import sendForESign from '@salesforce/apex/SendEnvelope.sendEnvelopeMethod';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class SendForeSign extends LightningElement {
    @api recordId;
    connectedCallback(){
        const urlParams = new URLSearchParams(window.location.search);
        const reccId = urlParams.get('recordId');
        this.recordId = reccId;
        this.sendDoc();
    }

    sendDoc(){
    
        sendForESign({docID:this.recordId}).then(result => {
            if(result ==='success'){
                const event = new ShowToastEvent({
                    title: 'Success',
                    message: 'The document sent successfully',
                    variant: 'success',
                    mode: 'dismissable'
                });
                this.dispatchEvent(event);

                this.dispatchEvent(new CloseActionScreenEvent());
            }else{
                const event = new ShowToastEvent({
                    title: 'Error',
                    message: result,
                    variant: 'error',
                    mode: 'dismissable'
                });
                this.dispatchEvent(event);
                this.dispatchEvent(new CloseActionScreenEvent());
            }
    
        }).catch(() => {});
    }

}