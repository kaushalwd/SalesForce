import { LightningElement, api } from 'lwc';
import { ShowToastEvent }        from 'lightning/platformShowToastEvent';
import launchCancellationBatch   from '@salesforce/apex/CancellationBatchController.launchCancellationBatch';
import getBatchJobStatus         from '@salesforce/apex/CancellationBatchController.getBatchJobStatus';
import getSyncStatus             from '@salesforce/apex/CancellationBatchController.getSyncStatus';

const POLL_INTERVAL_MS  = 5000;   // 5 seconds
const MAX_POLL_ATTEMPTS = 120;    // 10 minutes max

export default class CancellationRetry extends LightningElement {

    @api recordId;

    // ── Reactive state ────────────────────────────────────────────────
    isLoading     = false;
    spinnerLabel  = '';
    statusMessage = '';
    statusVariant = '';
    showStatus    = false;

    // ── Internal polling state ────────────────────────────────────────
    _pollTimer    = null;
    _pollCount    = 0;
    _jobId        = null;   // ← stores the batch Job Id from launch

    disconnectedCallback() {
        this._stopPolling();
    }

    // ── Button handler ────────────────────────────────────────────────
    handleRetry() {
        this.showStatus    = false;
        this.statusMessage = '';
        this.isLoading     = true;
        this.spinnerLabel  = 'Launching batch…';
        this._jobId        = null;

        launchCancellationBatch({ serviceRequestId: this.recordId })
            .then(result => {
                if (result.success) {
                    // Store the job Id — then poll AsyncApexJob first
                    this._jobId       = result.jobId;
                    this.spinnerLabel = 'Batch queued — waiting for job to start…';
                    this._startPolling();
                } else {
                    this.isLoading = false;
                    this._showResult(false, result.message);
                }
            })
            .catch(error => {
                this.isLoading = false;
                this._showResult(false, error?.body?.message ?? error?.message ?? 'Unknown error');
            });
    }

    // ── Phase 1: Poll AsyncApexJob until batch is terminal ────────────
    _startPolling() {
        this._pollCount = 0;
        this._pollTimer = setInterval(() => this._pollBatchJob(), POLL_INTERVAL_MS);
    }

    _stopPolling() {
        if (this._pollTimer) {
            clearInterval(this._pollTimer);
            this._pollTimer = null;
        }
    }

    _pollBatchJob() {
        this._pollCount++;

        if (this._pollCount > MAX_POLL_ATTEMPTS) {
            this._stopPolling();
            this.isLoading = false;
            this._showResult(
                false,
                'Batch is taking longer than expected (10 min). '
                + 'Please refresh and check Sync_Status__c manually.'
            );
            return;
        }

        getBatchJobStatus({ jobId: this._jobId })
            .then(res => {
                const isTerminal = res.isTerminal === 'true';

                if (!isTerminal) {
                    // Still running — update label with current status and keep waiting
                    this.spinnerLabel = `Processing cancellation… Job status: ${res.status}`;
                    return;
                }

                // Batch job is done — stop the timer
                this._stopPolling();

                if (res.status === 'Failed' || res.status === 'Aborted') {
                    // Batch itself failed — no point calling getSyncStatus
                    this.isLoading = false;
                    this._showResult(
                        false,
                        `Batch job ${res.status.toLowerCase()}. ${res.extendedStatus ?? ''}`
                    );
                    return;
                }

                // Batch completed — now check SR Sync_Status__c (Phase 2)
                this.spinnerLabel = 'Batch finished — reading sync status…';
                this._checkSyncStatus();
            })
            .catch(error => {
                this._stopPolling();
                this.isLoading = false;
                this._showResult(
                    false,
                    'Error checking batch job: ' + (error?.body?.message ?? error?.message ?? 'Unknown')
                );
            });
    }

    // ── Phase 2: Read SR Sync_Status__c once batch is confirmed done ──
    _checkSyncStatus() {
        getSyncStatus({ serviceRequestId: this.recordId })
            .then(res => {
                this.isLoading = false;

                const isSuccess = res.syncStatus === 'Fully Completed';
                const message   = isSuccess
                    ? 'Cancellation completed successfully.'
                    : `Cancellation finished with status: ${res.syncStatus}`;

                this._showResult(isSuccess, message);
                this._fireToast(
                    isSuccess ? 'Cancellation Complete' : 'Cancellation Finished',
                    message,
                    isSuccess ? 'success' : res.syncStatus === 'Partially Completed' ? 'warning' : 'error'
                );
            })
            .catch(error => {
                this.isLoading = false;
                this._showResult(
                    false,
                    'Error reading sync status: ' + (error?.body?.message ?? error?.message ?? 'Unknown')
                );
            });
    }

    // ── Helpers ───────────────────────────────────────────────────────
    _showResult(isSuccess, message) {
        this.statusVariant = isSuccess ? 'success' : 'error';
        this.statusMessage = message;
        this.showStatus    = true;
    }

    _fireToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    // ── Computed getters ──────────────────────────────────────────────
    get statusBoxClass() {
        return 'slds-box slds-m-top_small status-box '
            + (this.statusVariant === 'success' ? 'status-success' : 'status-error');
    }

    get statusIcon() {
        return this.statusVariant === 'success' ? 'utility:success' : 'utility:error';
    }
}