import { LightningElement, api } from 'lwc';

import checkEmployeePaymentPlanProcess
    from '@salesforce/apex/EmployeePaymentPlanChangeController.checkEmployeePaymentPlanProcess';

import createEmployeePaymentPlanProcess
    from '@salesforce/apex/EmployeePaymentPlanChangeController.createEmployeePaymentPlanProcess';

import { ShowToastEvent } from 'lightning/platformShowToastEvent';


export default class EmployeePaymentPlanChange extends LightningElement {

    _recordId;

    isLoading = false;
    isChecked = false;
    isProcessInProgress = false;


    @api
    get recordId() {
        return this._recordId;
    }

    set recordId(value) {

        this._recordId = value;

        if (value) {
            this.checkExistingProcess();
        }
    }


    async checkExistingProcess() {

        this.isLoading = true;
        this.isChecked = false;

        try {

            const result =
                await checkEmployeePaymentPlanProcess({
                    salesOrderId: this.recordId
                });

            this.isProcessInProgress = result;

            this.isChecked = true;

        }
        catch (error) {

            console.error(
                'Employee Payment Plan Check Error',
                error
            );

            this.showToast(
                'Error',
                this.getErrorMessage(error),
                'error'
            );

        }
        finally {

            this.isLoading = false;

        }
    }


    async handleSubmit() {

        if (!this.recordId) {

            this.showToast(
                'Error',
                'Sales Order Id is not available.',
                'error'
            );

            return;
        }

        this.isLoading = true;

        try {

            await createEmployeePaymentPlanProcess({
                salesOrderId: this.recordId
            });

            this.showToast(
                'Success',
                'Employee Payment Plan Change request initiated successfully.',
                'success'
            );

            this.dispatchEvent(
                new CustomEvent('processsuccess', {
                    detail: {
                        message:
                            'Employee Payment Plan Change request initiated successfully.'
                    }
                })
            );

        }
        catch (error) {

            console.error(
                'Employee Payment Plan Process Error',
                error
            );

            this.showToast(
                'Error',
                this.getErrorMessage(error),
                'error'
            );

            this.dispatchEvent(
                new CustomEvent('processerror', {
                    detail: {
                        title: 'Error',
                        message: this.getErrorMessage(error),
                        variant: 'error'
                    }
                })
            );

        }
        finally {

            this.isLoading = false;

        }
    }


    showToast(title, message, variant) {

        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant,
                mode:
                    variant === 'error'
                        ? 'sticky'
                        : 'dismissable'
            })
        );

    }


    getErrorMessage(error) {

        if (error?.body?.message) {
            return error.body.message;
        }

        if (Array.isArray(error?.body)) {

            return error.body
                .map(item => item.message)
                .join(', ');

        }

        if (error?.message) {
            return error.message;
        }

        return 'An unexpected error occurred.';

    }
}