import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import runBatchForPeriod from '@salesforce/apex/MBP_BrokerClassificationRunner.runBatchForPeriod';
import getClassificationSummary from '@salesforce/apex/MBP_BrokerClassificationRunner.getClassificationSummary';

export default class Mbp_brokerClassificationRunner extends LightningElement {
    @track startMonth = '';
    @track endMonth = '';
    @track isLoading = false;
    @track showSummary = false;
    @track summaryData = [];
    @track jobId = '';
    @track totalAccounts = 0;

    get maxDate() {
        // Get current date in YYYY-MM format (last day of previous month)
        const today = new Date();
        const lastMonth = new Date(today.getFullYear(), today.getMonth() - 1, 1);
        return `${lastMonth.getFullYear()}-${String(lastMonth.getMonth() + 1).padStart(2, '0')}`;
    }

    handleStartMonthChange(event) {
        this.startMonth = event.target.value;
        this.validateDates();
    }

    handleEndMonthChange(event) {
        this.endMonth = event.target.value;
        this.validateDates();
    }

    validateDates() {
        if (this.startMonth && this.endMonth) {
            const start = new Date(this.startMonth + '-01');
            const end = new Date(this.endMonth + '-01');
            const today = new Date();
            const lastMonth = new Date(today.getFullYear(), today.getMonth(), 0);

            // Check if end date is in the future
            if (end > lastMonth) {
                this.showToast('Error', 'End date cannot be in the future', 'error');
                this.endMonth = '';
                return false;
            }

            // Check if start is after end
            if (start > end) {
                this.showToast('Error', 'Start date must be before end date', 'error');
                this.startMonth = '';
                return false;
            }

            // Check if exactly 12 months
            const monthsDiff = (end.getFullYear() - start.getFullYear()) * 12 +
                               (end.getMonth() - start.getMonth());

            if (monthsDiff !== 11) {
                this.showToast('Warning', 'Period must be exactly 12 months (e.g., Jan 2025 to Dec 2025)', 'warning');
                return false;
            }
        }
        return true;
    }

    handleRunBatch() {
        if (!this.startMonth || !this.endMonth) {
            this.showToast('Error', 'Please select both start and end months', 'error');
            return;
        }

        if (!this.validateDates()) {
            return;
        }

        this.isLoading = true;
        this.showSummary = false;

        // Convert YYYY-MM to first and last day
        const startDate = this.startMonth + '-01';
        const endDateObj = new Date(this.endMonth + '-01');
        const lastDay = new Date(endDateObj.getFullYear(), endDateObj.getMonth() + 1, 0).getDate();
        const endDate = this.endMonth + '-' + String(lastDay).padStart(2, '0');

        runBatchForPeriod({ startDateStr: startDate, endDateStr: endDate })
            .then(result => {
                this.jobId = result.jobId;
                this.totalAccounts = result.accountCount;

                this.showToast('Success',
                    `Batch job started! Job ID: ${result.jobId}. Processing ${result.accountCount} broker accounts. Please wait...`,
                    'success');

                // Poll for completion and get summary
                this.pollForCompletion();
            })
            .catch(error => {
                this.isLoading = false;
                console.error('Error running batch:', error);
                this.showToast('Error',
                    error.body?.message || 'Failed to start batch job',
                    'error');
            });
    }

    pollForCompletion() {
        // Poll every 5 seconds for up to 2 minutes
        let pollCount = 0;
        const maxPolls = 24; // 2 minutes / 5 seconds

        const pollInterval = setInterval(() => {
            pollCount++;

            getClassificationSummary()
                .then(summary => {
                    if (summary && summary.length > 0) {
                        this.summaryData = summary;
                        this.showSummary = true;
                        this.isLoading = false;
                        clearInterval(pollInterval);

                        this.showToast('Completed',
                            'Broker classification completed successfully!',
                            'success');
                    } else if (pollCount >= maxPolls) {
                        this.isLoading = false;
                        clearInterval(pollInterval);
                        this.showToast('Info',
                            'Batch is still processing. Refresh page to see results.',
                            'info');
                    }
                })
                .catch(error => {
                    console.error('Error polling:', error);
                    if (pollCount >= maxPolls) {
                        this.isLoading = false;
                        clearInterval(pollInterval);
                    }
                });
        }, 5000);
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            mode: 'dismissable'
        }));
    }

    handleRefreshSummary() {
        this.isLoading = true;
        getClassificationSummary()
            .then(summary => {
                this.summaryData = summary;
                this.showSummary = true;
                this.isLoading = false;
                this.showToast('Refreshed', 'Classification summary refreshed', 'success');
            })
            .catch(error => {
                this.isLoading = false;
                console.error('Error refreshing:', error);
                this.showToast('Error', 'Failed to refresh summary', 'error');
            });
    }
}