import { LightningElement, api } from 'lwc';
import getLpcAnalysis from '@salesforce/apex/LpcAnalysisViewerController.getLpcAnalysis';

export default class LpcAnalysisViewer extends LightningElement {
    analysis;
    error;
    isLoading = false;
    _recordId;

    @api
    get recordId() {
        return this._recordId;
    }

    set recordId(value) {
        this._recordId = value;

        if (value) {
            this.loadAnalysis();
        }
    }

    connectedCallback() {
        // handled through recordId setter
    }

    @api
    refreshAnalysis() {
        this.loadAnalysis();
    }

    loadAnalysis() {
        if (!this.recordId) {
            return;
        }

        this.isLoading = true;
        this.error = undefined;

        getLpcAnalysis({
            salesOrderId: this.recordId
        })
            .then((result) => {
                this.analysis = {
                    ...result,

                    hasWaiverProcesses:
                        result.waiverProcesses &&
                        result.waiverProcesses.length > 0,

                    waiverProcesses: (result.waiverProcesses || []).map((wp) => {
                        return {
                            ...wp,
                            name: wp.name || '',
                            lpcCollectedAmount: wp.lpcCollectedAmount || 0,
                            waiverPercentage: wp.waiverPercentage || 0,
                            lpcWaiverAmount: wp.lpcWaiverAmount || 0,
                            status: wp.status || ''
                        };
                    }),

                    installments: (result.installments || []).map((ins) => {
                        const hasBrackets =
                            ins.brackets &&
                            ins.brackets.length > 0;

                        const hasFreezeSections =
                            ins.freezeSections &&
                            ins.freezeSections.length > 0;

                        const lpcAmount = ins.lpcAmount || 0;

                        const isExcluded = ins.isLpcExcluded === true;

                        const isApplicable =
                            !isExcluded &&
                            lpcAmount > 0 &&
                            (hasBrackets || hasFreezeSections);

                        return {
                            ...ins,

                            allocations: ins.allocations || [],

                            brackets: (ins.brackets || []).map((bracket) => {
                                return {
                                    ...bracket,
                                    amountConsideredForLpc:
                                        bracket.amountConsideredForLpc || 0,
                                    lpcAmount:
                                        bracket.lpcAmount || 0,
                                    days:
                                        bracket.days || 0
                                };
                            }),

                            freezeSections:
                                (ins.freezeSections || []).map((freeze) => {
                                    return {
                                        ...freeze,
                                        amountNotCalculatedForLpc:
                                            freeze.amountNotCalculatedForLpc || 0,
                                        lpcAmountExcluded:
                                            freeze.lpcAmountExcluded || 0,
                                        freezeDays:
                                            freeze.freezeDays || 0
                                    };
                                }),

                            logs: ins.logs || [],

                            hasBrackets: hasBrackets,
                            hasFreezeSections: hasFreezeSections,

                            lpcApplicable:
                                isExcluded
                                    ? 'NO - Excluded (Exclude LPC enabled)'
                                    : isApplicable ? 'YES' : 'NO',

                            lpcApplicableClass:
                                isApplicable
                                    ? 'lpc-status lpc-yes'
                                    : 'lpc-status lpc-no',

                            milestoneDate:
                                ins.milestoneDate || '',

                            extensionDate:
                                ins.extensionDate || '',

                            rfoDate:
                                ins.rfoDate || '',

                            lpcStartBaseDate:
                                ins.lpcStartBaseDate || '',

                            lpcFreezeStartDate:
                                ins.lpcFreezeStartDate || '',

                            lpcFreezeEndDate:
                                ins.lpcFreezeEndDate || '',

                            invoiceAmount:
                                ins.invoiceAmount || 0,

                            balanceAmount:
                                ins.balanceAmount || 0,

                            appliedAmount:
                                ins.appliedAmount || 0,

                            totalPaidAmount:
                                ins.totalPaidAmount || 0,

                            paidWithinGrace:
                                ins.paidWithinGrace || 0,

                            outstandingAfterPayments:
                                ins.outstandingAfterPayments || 0,

                            lpcAmount:
                                ins.lpcAmount || 0
                        };
                    })
                };
            })
            .catch((error) => {
                this.analysis = undefined;
                this.error = this.reduceError(error);
                console.error(
                    'Error while loading LPC Analysis',
                    JSON.stringify(error)
                );
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    reduceError(error) {
        if (error?.body?.message) {
            return error.body.message;
        }

        if (error?.message) {
            return error.message;
        }

        return 'Unknown error occurred while loading LPC analysis.';
    }
}