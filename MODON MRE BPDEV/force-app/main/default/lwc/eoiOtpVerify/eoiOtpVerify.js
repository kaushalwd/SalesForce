/**
 * eoiOtpVerify — OTP verification for a staged EOI registration.
 * Channel is chosen first (Email or SMS), then the code is sent and
 * entered — same process as the HGE public journey.
 * @author Aurelix
 */
import { LightningElement, api, track } from 'lwc';
import startOtp from '@salesforce/apex/EOIWadeemSiteController.startOtp';
import resendOtp from '@salesforce/apex/EOIWadeemSiteController.resendOtp';
import verifyOtp from '@salesforce/apex/EOIWadeemSiteController.verifyOtp';

export default class EoiOtpVerify extends LightningElement {
    @api registrationId;
    @api emailHint = '';   // masked destination shown on the tile before a code is sent
    @api mobileHint = '';
    /* MSC-247. Sign-in first: the channel was chosen and the code already sent on the
       previous screen, so this step adopts that request and hides the channel choice. */
    @api lockedChannel = '';
    @api initialRequest = null;

    @track channel = 'Email';
    @track requestId = null;
    /* MEOI-BUG1. Was a single maskedTarget shared by both tiles. The getters below then
       showed it against whichever channel happened to be SELECTED, not the channel the
       code was actually sent to - so sending by SMS and then clicking the Email tile
       showed the masked PHONE NUMBER under "Email". Keyed by channel, each tile can only
       ever display its own destination. */
    @track maskedTarget = '';
    @track maskedByChannel = {};
    @track code = '';
    @track isBusy = false;
    @track errorMessage = '';
    @track resendWait = 0;

    countdownTimer = null;

    connectedCallback() {
        if (this.lockedChannel) {
            this.channel = this.lockedChannel;
        }
        const r = this.initialRequest;
        if (r && r.verificationRequestId) {
            this.channel = r.channel || this.channel;
            this.requestId = r.verificationRequestId;
            this.maskedTarget = r.maskedTarget || '';
            this.rememberMask(this.channel, this.maskedTarget);
            this.startCountdown(r.resendAvailableAt);
            this.focusCode();
        }
    }

    disconnectedCallback() {
        this.stopCountdown();
    }

    /* MEOI-BUG2. Picking the other tile used to move the highlight and nothing else.
       Once a code had been sent the only action left was "Resend code", which resends on
       the ORIGINAL request - so a customer who sent by SMS, then chose Email, then hit
       resend, received a second SMS and no email. The screen implied a choice it did not
       honour. Choosing a different channel after a code has gone out now starts a fresh
       request on that channel, which is what the customer is asking for. */
    selectChannel(event) {
        /* MEOI-BUG2a. The channel switch sends a fresh code, so it has to respect the same
           cooldown as Resend - otherwise flipping Email/SMS/Email defeats the timer
           entirely and becomes an unlimited send button. Same guard, one source of truth
           in channelSwitchDisabled, and the tiles are disabled in the markup so the
           affordance matches the behaviour rather than silently doing nothing. */
        if (this.channelSwitchDisabled) {
            return;
        }
        const picked = event.currentTarget.dataset.value;
        if (picked === this.channel) {
            return;
        }
        this.channel = picked;
        this.errorMessage = '';
        if (this.requestId) {
            this.code = '';
            this.handleSend();
        }
    }

    handleSend() {
        this.errorMessage = '';
        this.isBusy = true;
        startOtp({ registrationId: this.registrationId, channel: this.channel })
            .then((res) => {
                this.channel = res.channel;
                this.requestId = res.verificationRequestId;
                this.maskedTarget = res.maskedTarget;
                this.rememberMask(res.channel, res.maskedTarget);
                this.code = '';
                this.startCountdown(res.resendAvailableAt);
                this.focusCode();
            })
            .catch((e) => {
                this.errorMessage = this.messageOf(e);
            })
            .finally(() => {
                this.isBusy = false;
            });
    }

    handleResend() {
        if (this.resendWait > 0 || !this.requestId) {
            return;
        }
        this.errorMessage = '';
        this.isBusy = true;
        resendOtp({ registrationId: this.registrationId, verificationRequestId: this.requestId })
            .then((res) => {
                this.maskedTarget = res.maskedTarget || this.maskedTarget;
                this.rememberMask(res.channel || this.channel, res.maskedTarget);
                this.startCountdown(res.resendAvailableAt);
            })
            .catch((e) => {
                this.errorMessage = this.messageOf(e);
            })
            .finally(() => {
                this.isBusy = false;
            });
    }

    handleVerify() {
        const code = (this.code || '').trim();
        if (!/^[0-9]{4,8}$/.test(code)) {
            this.errorMessage = 'Enter the code from your message.';
            return;
        }
        this.errorMessage = '';
        this.isBusy = true;
        verifyOtp({ registrationId: this.registrationId, verificationRequestId: this.requestId, code })
            .then((res) => {
                if (res && res.verified) {
                    this.stopCountdown();
                    this.dispatchEvent(new CustomEvent('verified', { detail: { channel: this.channel } }));
                } else {
                    this.errorMessage = (res && res.message) || 'Invalid verification code.';
                }
            })
            .catch((e) => {
                this.errorMessage = this.messageOf(e);
            })
            .finally(() => {
                this.isBusy = false;
            });
    }

    handleCode(event) {
        this.code = event.target.value.replace(/[^0-9]/g, '');
        event.target.value = this.code;
    }

    handleCodeKeydown(event) {
        if (event.key === 'Enter') {
            this.handleVerify();
        }
    }

    startCountdown(resendAvailableAt) {
        this.stopCountdown();
        if (!resendAvailableAt) {
            this.resendWait = 0;
            return;
        }
        const target = new Date(resendAvailableAt).getTime();
        const tick = () => {
            const left = Math.max(0, Math.ceil((target - Date.now()) / 1000));
            this.resendWait = left;
            if (left <= 0) {
                this.stopCountdown();
            }
        };
        tick();
        this.countdownTimer = window.setInterval(tick, 1000);
    }

    stopCountdown() {
        if (this.countdownTimer) {
            window.clearInterval(this.countdownTimer);
            this.countdownTimer = null;
        }
    }

    focusCode() {
        requestAnimationFrame(() => {
            const input = this.template.querySelector('.code-input');
            if (input) {
                input.focus();
            }
        });
    }

    messageOf(e) {
        const body = e && e.body;
        return (body && body.message) || 'Something went wrong. Please try again.';
    }

    get hasRequest() {
        return !!this.requestId;
    }
    get showChannelChoice() {
        return !this.lockedChannel;
    }
    get emailSelected() {
        return String(this.channel === 'Email');
    }
    get smsSelected() {
        return String(this.channel === 'SMS');
    }
    /* Before any code is sent the tiles must stay live - that is how the customer picks
       where it goes. They lock only once a code is out and the timer is running. */
    get channelSwitchDisabled() {
        return this.isBusy || (!!this.requestId && this.resendWait > 0);
    }

    get emailChannelClass() {
        return this.channel === 'Email' ? 'm-seg__opt is-on' : 'm-seg__opt';
    }
    get smsChannelClass() {
        return this.channel === 'SMS' ? 'm-seg__opt is-on' : 'm-seg__opt';
    }
    /* MEOI-A7. The destination of the SELECTED channel only, under the control. */
    get destinationValue() {
        return this.channel === 'SMS' ? this.smsValue : this.emailValue;
    }
    get destinationLead() {
        return this.hasRequest ? 'Code sent to' : 'We\u2019ll send it to';
    }
    rememberMask(channel, masked) {
        if (!channel || !masked) {
            return;
        }
        this.maskedByChannel = { ...this.maskedByChannel, [channel]: masked };
    }

    get emailValue() {
        return this.maskedByChannel.Email || this.emailHint;
    }
    get smsValue() {
        return this.maskedByChannel.SMS || this.mobileHint;
    }
    get subLine() {
        return this.hasRequest
            ? 'We\u2019ve sent a six-digit code. Enter it below and you\u2019re through.'
            : 'Choose where to receive your six-digit code.';
    }
    /** Six display cells mirroring the hidden input. */
    get otpCells() {
        const code = this.code || '';
        const cells = [];
        for (let i = 0; i < 6; i++) {
            const ch = code.charAt(i);
            let cls = '';
            if (!ch) {
                cls += ' is-empty';
            }
            if (i === code.length && code.length < 6) {
                cls += ' is-focus';
            }
            cells.push({ i, ch: ch || '0', cls: cls.trim() });
        }
        return cells;
    }
    get resendDisabled() {
        return this.isBusy || this.resendWait > 0;
    }
    get resendLabel() {
        if (this.resendWait > 0) {
            const m = Math.floor(this.resendWait / 60);
            const s = String(this.resendWait % 60).padStart(2, '0');
            return `Resend in ${String(m).padStart(2, '0')}:${s}`;
        }
        return 'Resend code';
    }
}