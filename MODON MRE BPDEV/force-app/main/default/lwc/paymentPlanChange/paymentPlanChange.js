import { LightningElement, api, track } from 'lwc';

import loadScreen from '@salesforce/apex/PaymentPlanChangeController.loadScreen';
import getPaymentPlanInstallments from '@salesforce/apex/PaymentPlanChangeController.getPaymentPlanInstallments';
import saveToStaging from '@salesforce/apex/PaymentPlanChangeController.saveToStaging';
import createPlan from '@salesforce/apex/PaymentPlanImplementationController.createPlan';
import approveRequest from '@salesforce/apex/PaymentPlanChangeController.approveRequest';
import IsEmployeePaymentPlanApplied from '@salesforce/apex/PaymentPlanChangeController.IsEmployeePaymentPlanApplied';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';


export default class PaymentPlanChange extends LightningElement {

    //@api recordId;

    _recordId;
    isLoading = false;

    @api
    get recordId() {
        return this._recordId;
    }

    set recordId(value) {
        this._recordId = value;

        if (value) {
            this.loadData();
        }
    }

    showSaveButton = false;
    showCreatePlanButton = false;
    showApproveButton = false;
    currentStepName;

    @track paymentPlanOptions = [];
    @track existingPlan = [];
    @track revisedPlan = [];
    @track originalRevisedPlan = [];
    isReadOnly = false;
    selectedPaymentPlan;
    selectedPaymentPlanName;

    salesAmount = 0;

    basePlan;

    requestId;

    showSaveButton = false;
    showCreatePlanButton = false;

    get enableBtn() {
        return this.currentStepName && this.currentStepName != 'Initiate Request'
    }

    connectedCallback() {
        this.loadData();
    }

    loadData() {

        loadScreen({
            salesOrderId: this.recordId
        })
            .then(res => {

                this.paymentPlanOptions =
                    res.paymentPlans.map(p => ({
                        label: p.paymentPlanName,
                        value: p.paymentPlanId
                    }));

                this.salesAmount = res.salesAmount;

                this.currentStepName = res.currentStepName;

                const isInitiateRequest = this.currentStepName == 'Initiate Request';
                this.isReadOnly = !isInitiateRequest;

                this.existingPlan = res.existingPlan;

                this.basePlan =
                    JSON.parse(
                        JSON.stringify(
                            res.existingPlan
                        )
                    );
                if (res.requestId) {

                    this.requestId =
                        res.requestId;

                    this.selectedPaymentPlan =
                        res.revisedPaymentPlanId;

                    const selected =
                        this.paymentPlanOptions.find(
                            p => p.value === this.selectedPaymentPlan
                        );

                    this.selectedPaymentPlanName =
                        selected
                            ? selected.label
                            : '';

                    /*
                     * Rebuild revised plan automatically
                     * using existing logic
                     */
                    // this.rebuildRevisedPlan();

                    if (
                        res.revisedPlan &&
                        res.revisedPlan.length > 0
                    ) {

                        // Load the saved draft
                        this.revisedPlan =
                            JSON.parse(JSON.stringify(res.revisedPlan));

                        this.originalRevisedPlan = JSON.parse(JSON.stringify(res.revisedPlan));
                        if (this.revisedPlan.length > 0) {
                            this.revisedPlan[this.revisedPlan.length - 1].isEditable = false;
                            this.revisedPlan = [...this.revisedPlan];
                        }

                    } else {

                        // No staging lines found, rebuild from template
                        this.rebuildRevisedPlan();
                    }

                    if (res.requestStatus === 'Draft') {

                        //this.showSaveButton = false;
                        this.showApproveButton = true;
                        this.showCreatePlanButton = false;
                    }
                    else if (res.requestStatus === 'Approved') {

                        this.showSaveButton = false;
                        this.showApproveButton = false;
                        this.showCreatePlanButton = true;
                    }
                }
            })
            .catch(error => {

                console.error(
                    'Load Error',
                    error
                );

            });
    }

    handlePlanChange(event) {

        this.selectedPaymentPlan =
            event.detail.value;
        const selected =
            this.paymentPlanOptions.find(
                p => p.value === this.selectedPaymentPlan
            );
        this.selectedPaymentPlanName =
            selected
                ? selected.label
                : '';
        this.showSaveButton = true;
        this.showApproveButton = false;
        this.showCreatePlanButton = false;
        this.rebuildRevisedPlan();
    }
    rebuildRevisedPlan() {

        getPaymentPlanInstallments({

            paymentPlanId:
                this.selectedPaymentPlan

        })
            .then(template => {

                const locked =
                    this.basePlan.filter(row => {

                        if (row.paymentStatus === 'Paid') {
                            return true;
                        }

                        /*  if (
                              row.paymentStatus === 'Partially Paid'
                              &&
                              Number(row.balanceAmount || 0) <= 5000
                          ) {
                              return true;
                          }*/

                        return false;
                    });

                const pending =
                    this.basePlan.filter(row => {

                        if (
                            row.paymentStatus === 'Pending'
                            ||
                            row.paymentStatus === 'Unpaid'
                        ) {
                            return true;
                        }

                        if (
                            row.paymentStatus === 'Partially Paid'
                            &&
                            Number(row.balanceAmount || 0) > 5000
                        ) {
                            return true;
                        }

                        return false;
                    });

                let consumedPercent =
                    locked.reduce(
                        (sum, row) =>
                            sum +
                            Number(
                                row.milestone || 0
                            ),
                        0
                    );

                let remainingPlan =
                    template.map(t => ({

                        paymentPlanInstallmentId:
                            t.installmentId,

                        installment:
                            t.installment,

                        milestone:
                            Number(
                                t.milestone || 0
                            ),

                        milestoneNumber:
                            t.milestoneNumber,

                        milestoneName:
                            t.milestoneName,

                        milestoneDate:
                            t.milestoneDate

                    }));

                let index = 0;

                while (
                    consumedPercent > 0 &&
                    index < remainingPlan.length
                ) {

                    if (
                        remainingPlan[index].milestone
                        <= consumedPercent
                    ) {

                        consumedPercent -=
                            remainingPlan[index]
                                .milestone;

                        remainingPlan[index]
                            .milestone = 0;
                    }
                    else {

                        remainingPlan[index]
                            .milestone -=
                            consumedPercent;

                        consumedPercent = 0;
                    }

                    index++;
                }

                remainingPlan =
                    remainingPlan.filter(
                        row => row.milestone > 0
                    );

                let finalPlan = [];

                /*
                 * Paid / Partially Paid
                 */
                locked.forEach(row => {

                    finalPlan.push({

                        installmentId:
                            row.installmentId,

                        paymentPlanInstallmentId:
                            null,

                        installment:
                            row.installment,

                        milestoneNumber:
                            row.milestoneNumber,

                        milestoneName:
                            row.milestoneName,

                        milestoneDate:
                            row.milestoneDate,

                        milestone:
                            Number(row.milestone),

                        amount:
                            Number(row.amount),

                        balanceAmount:
                            Number(row.balanceAmount || 0),

                        needsUnallocation:
                            false,

                        paymentStatus:
                            row.paymentStatus,

                        isEditable:
                            false,

                        rowClass:
                            'paid-row'
                    });

                });

                /*
                 * Pending / Revised
                 */
                remainingPlan.forEach((planRow, idx) => {

                    let installmentId = null;
                    let installmentName = `Installment ${idx + 1}`;

                    let sourceSOI = null;

                    if (pending.length > 0) {

                        let soiIndex =
                            idx < pending.length
                                ? idx
                                : pending.length - 1;

                        sourceSOI =
                            pending[soiIndex];

                        installmentId =
                            sourceSOI.installmentId;

                        installmentName =
                            sourceSOI.installment;
                    }

                    const amount =
                        (this.salesAmount *
                            planRow.milestone) / 100;

                    const balanceAmount =
                        sourceSOI
                            ? Number(
                                sourceSOI.balanceAmount || 0
                            )
                            : 0;

                    const installmentAmount =
                        sourceSOI
                            ? Number(
                                sourceSOI.amount || 0
                            )
                            : 0;

                    /*
                     * Only true partial payments
                     * Balance > 5000
                     * Balance < Installment Amount
                     */
                    const needsUnallocation =
                        sourceSOI
                        &&
                        sourceSOI.paymentStatus === 'Partially Paid'
                        &&
                        balanceAmount > 5000
                        &&
                        balanceAmount < installmentAmount;

                    finalPlan.push({

                        installmentId:
                            installmentId,

                        paymentPlanInstallmentId:
                            planRow.paymentPlanInstallmentId,

                        installment:
                            installmentName,

                        milestoneNumber:
                            planRow.milestoneNumber,

                        milestoneName:
                            planRow.milestoneName,

                        milestoneDate:
                            planRow.milestoneDate,

                        milestone:
                            Number(
                                planRow.milestone.toFixed(2)
                            ),

                        amount:
                            Number(
                                amount.toFixed(2)
                            ),

                        balanceAmount:
                            balanceAmount,

                        needsUnallocation:
                            needsUnallocation,

                        paymentStatus:
                            'Pending',

                        isEditable:
                            true,

                        rowClass:
                            needsUnallocation
                                ? 'warning-row'
                                : ''
                    });

                });

                if (finalPlan.length > 0 && finalPlan[finalPlan.length - 1].paymentStatus === 'Pending') {
                    finalPlan[finalPlan.length - 1].isEditable = false;
                }


                this.revisedPlan = finalPlan;

                //this.showSaveButton =finalPlan.length > 0;

            })
            .catch(error => {

                console.error(
                    'Plan Change Error',
                    JSON.stringify(error)
                );

            });
    }

    async handleSave() {

        const result = await IsEmployeePaymentPlanApplied({
            salesOrderId: this.recordId
        });

        if (result) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Validation Error',
                    message: 'An Employee Payment Plan has already been applied to this customer.',
                    variant: 'error',
                    mode: 'sticky' // 'dismissable' or 'pester' are also options
                })
            );

            return; // Stop further processing
        }
        const payload =
            this.revisedPlan.map(
                row => ({

                    installmentId:
                        row.installmentId,

                    paymentPlanInstallmentId:
                        row.paymentPlanInstallmentId,

                    milestoneNumber:
                        row.milestoneNumber,

                    milestoneName:
                        row.milestoneName,

                    milestoneDate:
                        row.milestoneDate,

                    installment:
                        row.installment,

                    milestone:
                        row.milestone,

                    amount:
                        row.amount,

                    paymentStatus:
                        row.paymentStatus

                }));

        saveToStaging({

            salesOrderId:
                this.recordId,

            selectedPaymentPlanId:
                this.selectedPaymentPlan,

            revisedPlanJson:
                JSON.stringify(payload)

        })
            .then(result => {

                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Request Submitted for Approval Successfully.',
                        variant: 'success',
                        mode: 'dismissable'
                    })
                );

                this.requestId = result;

                this.showSaveButton = false;
                this.showApproveButton = true;
                this.showCreatePlanButton = false;
                window.location.reload();

            })
            .catch(error => {

                console.error(
                    error
                );

            });
    }

    handleCreatePlan() {
        this.isLoading = true;

        createPlan({
            requestId: this.requestId
        })
            .then(() => {
                this.isLoading = false;
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Payment Plan Created Successfully.',
                        variant: 'success'
                    })
                );

                this.showCreatePlanButton = false;
            })
            .catch(error => {
                this.isLoading = false;
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: error.body?.message || error.message || 'Something went wrong.',
                        variant: 'error',
                        mode: 'sticky'
                    })
                );
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleApprove() {

        approveRequest({
            requestId: this.requestId
        })
            .then(() => {



                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Request Approved Successfully.',
                        variant: 'success',
                        mode: 'dismissable'
                    })
                );


                this.showSaveButton = false;
                this.showApproveButton = false;
                this.showCreatePlanButton = true;

            })
            .catch(error => {

                console.error(error);

            });
    }


    handleDateChange(event) {

        const index = Number(event.target.dataset.index);

        const value = event.target.value;

        this.revisedPlan[index].milestoneDate = value;

        this.revisedPlan = [...this.revisedPlan];

        const changed = this.revisedPlan.some((row, i) =>
            row.milestoneDate !== this.originalRevisedPlan[i].milestoneDate
        );

        this.showSaveButton = changed;
    }

}