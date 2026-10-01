/**
 * relixSendKyc - the "Send UAE KYC (Relix)" screen action on Account (Relix plan R1/R2, docs/relix).
 * MODON Dev, 25 Sep 2026.
 * MODON Dev, 26 Sep 2026 (K4): the server returns a fault as StatusView.error (getStatus, refresh) or as the send
 * result's problem instead of throwing, so its log is kept; the error is shown and the last good status stays.
 *
 * On open it reads the Account's Relix status. When nothing needs confirming (no live Relix case, KYC not
 * active, no live Signzy link) it sends at once, as agreed in the meeting. Otherwise it shows the current
 * Relix cases with Refresh and Send anyway / Resend. Signzy's own action is not touched.
 */
import { LightningElement, api, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { CloseActionScreenEvent } from 'lightning/actions';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getStatus from '@salesforce/apex/RelixKycController.getStatus';
import sendKyc from '@salesforce/apex/RelixKycController.send';
import refreshStatus from '@salesforce/apex/RelixKycController.refresh';
import LABELS from './labels';

const MODE_LOADING = 'loading';
const MODE_DISABLED = 'disabled';
const MODE_SENT = 'sent';
const MODE_PROBLEMS = 'problems';
const MODE_CASES = 'cases';
const MODE_ERROR = 'error';
const PLACEHOLDER = '{0}';
const TITLE_SEPARATOR = ' · ';
const VARIANT_SUCCESS = 'success';
const VARIANT_ERROR = 'error';

/** The safe message of an AuraHandledException, or a generic one for anything else. */
function reduceError(error) {
    const message = error && error.body ? error.body.message : null;
    return typeof message === 'string' && message.trim() ? message : LABELS.genericError;
}

export default class RelixSendKyc extends LightningElement {
    labels = LABELS;
    busy = false;
    mode = MODE_LOADING;
    status;
    problems = [];
    confirmReason;
    errorMessage;

    accountId;
    inDom = false;
    hasStarted = false;

    @api
    get recordId() {
        return this.accountId;
    }
    set recordId(value) {
        if (value) {
            this.accountId = value;
            this.begin();
        }
    }

    /** Quick actions do not always receive recordId in time; the page state carries it as well. */
    @wire(CurrentPageReference)
    wiredPageReference(pageReference) {
        const fromPage = pageReference && pageReference.state ? pageReference.state.recordId : null;
        if (fromPage && !this.accountId) {
            this.accountId = fromPage;
            this.begin();
        }
    }

    connectedCallback() {
        this.inDom = true;
        this.begin();
    }

    begin() {
        if (!this.inDom || this.hasStarted || !this.accountId) {
            return;
        }
        this.hasStarted = true;
        this.run(() => this.loadStatus());
    }

    // ---------------------------------------------------------------- server calls

    async loadStatus() {
        const status = await getStatus({ accountId: this.accountId });
        await this.showStatus(status, true);
    }

    async showStatus(status, sendWhenClear) {
        if (status && status.error) {
            // A server fault (K4): keep what is on screen and show the safe message.
            this.showError({ body: { message: status.error } });
            return;
        }
        this.status = status;
        this.confirmReason = null;
        if (!status || !status.enabled) {
            this.mode = MODE_DISABLED;
            return;
        }
        const clear = !status.hasLiveRelixCase && !status.kycActive && !status.signzyLinkLive;
        if (sendWhenClear && clear) {
            await this.requestSend(false);
            return;
        }
        this.mode = MODE_CASES;
    }

    async requestSend(confirmed) {
        const result = await sendKyc({ accountId: this.accountId, confirmed });
        if (result.status) {
            this.status = result.status;
        }
        if (result.ok) {
            this.mode = MODE_SENT;
            this.toast(LABELS.sentTitle, this.sentMessage, VARIANT_SUCCESS);
            return;
        }
        if (result.needsConfirmation) {
            this.confirmReason = result.confirmReason;
            this.mode = MODE_CASES;
            return;
        }
        const problems = result.problems && result.problems.length ? result.problems : [LABELS.genericError];
        this.problems = problems.map((text, index) => ({ key: `problem-${index}`, text }));
        this.mode = MODE_PROBLEMS;
    }

    async refreshCases() {
        const status = await refreshStatus({ accountId: this.accountId });
        await this.showStatus(status, false);
    }

    /** Runs one server step with the spinner on; any failure becomes a safe message and a toast. */
    async run(step) {
        if (this.busy) {
            return;
        }
        this.busy = true;
        this.errorMessage = null;
        try {
            await step();
        } catch (error) {
            this.showError(error);
        } finally {
            this.busy = false;
        }
    }

    showError(error) {
        this.errorMessage = reduceError(error);
        if (this.mode === MODE_LOADING) {
            this.mode = MODE_ERROR;
        }
        this.toast(LABELS.errorTitle, this.errorMessage, VARIANT_ERROR);
    }

    toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    // ---------------------------------------------------------------- handlers

    handleRefresh() {
        this.run(() => this.refreshCases());
    }

    handleSendConfirmed() {
        this.run(() => this.requestSend(true));
    }

    handleClose() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }

    // ---------------------------------------------------------------- view state

    get isLoading() {
        return this.mode === MODE_LOADING;
    }

    get isDisabled() {
        return this.mode === MODE_DISABLED;
    }

    get isSent() {
        return this.mode === MODE_SENT;
    }

    get hasProblems() {
        return this.mode === MODE_PROBLEMS;
    }

    get isCases() {
        return this.mode === MODE_CASES;
    }

    get ariaBusy() {
        return this.busy ? 'true' : 'false';
    }

    get sentMessage() {
        const recipient = this.status && this.status.recipientMasked ? this.status.recipientMasked : LABELS.theBuyer;
        return LABELS.sentMessage.replace(PLACEHOLDER, recipient);
    }

    get notices() {
        const texts = [];
        if (this.confirmReason) {
            texts.push(this.confirmReason);
        } else if (this.status) {
            if (this.status.kycActive) {
                texts.push(LABELS.kycActive);
            }
            if (this.status.signzyLinkLive) {
                texts.push(LABELS.signzyLive);
            }
        }
        return texts.map((text, index) => ({ key: `notice-${index}`, text }));
    }

    get hasNotices() {
        return this.notices.length > 0;
    }

    get caseRows() {
        const cases = this.status && this.status.cases ? this.status.cases : [];
        return cases.map((c) => {
            const repStatus = c.repStatus || c.relixStatus || '';
            return {
                id: c.id,
                title: c.role ? c.name + TITLE_SEPARATOR + c.role : c.name,
                repStatus,
                live: c.live === true,
                linkSentAt: c.linkSentAt,
                linkExpiresAt: c.linkExpiresAt,
                lastReadAt: c.lastReadAt,
                reviewReason: c.reviewReason && !repStatus.includes(c.reviewReason) ? c.reviewReason : null
            };
        });
    }

    get hasCases() {
        return this.caseRows.length > 0;
    }

    get showRefresh() {
        return this.isCases && this.hasCases;
    }

    get showSend() {
        return this.isCases;
    }

    get sendLabel() {
        return this.status && this.status.hasLiveRelixCase ? LABELS.resend : LABELS.sendAnyway;
    }
}