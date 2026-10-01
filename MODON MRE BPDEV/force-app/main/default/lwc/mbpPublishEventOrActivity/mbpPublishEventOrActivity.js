import { LightningElement, api } from 'lwc';
import publishEvent from '@salesforce/apex/MBP_ManageEventsandActivities.publishEvent';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class PublishEventOrActivity extends LightningElement {
    @api recordId;
    isLoading = false;

    async handlePublish() {
        this.isLoading = true;
        try {
            const result = await publishEvent({ recordId: this.recordId });

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: result,
                    variant: 'success'
                })
            );

            this.dispatchEvent(new CloseActionScreenEvent());
        } catch (e) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: e?.body?.message || e?.message || 'Unknown error',
                    variant: 'error'
                })
            );
        } finally {
            this.isLoading = false;
        }
    }
}