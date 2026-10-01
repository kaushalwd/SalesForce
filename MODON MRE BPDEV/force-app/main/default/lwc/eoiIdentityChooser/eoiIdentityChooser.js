/**
 * eoiIdentityChooser — EOI identity step: UAE Resident (UAE Pass),
 * Non-Resident and Organization paths. Handles the UAE Pass redirect
 * callback (?code&state) and the Checkout payment return
 * (?paymentResult&ref) on the same page. Pay-first, one payment per
 * residence type: a type's registration rows are written only after its
 * card payment captures, and the checklist tracks each type separately.
 * @author Aurelix
 *
 * v1.1  MEOI-01/12  8 Sep 2026
 *   UAE Pass is now switchable at runtime. Custom Label EOI_Site_UAE_Pass_Enabled
 *   gates the UAE Resident pane: 'true' keeps the UAE PASS button, anything else
 *   reveals a manual Emirates-ID form in its place. The pane previously held the
 *   button and NOTHING ELSE, so turning UAE Pass off without this change left the
 *   tab empty. The form is the Non-Resident markup with passport swapped for
 *   Emirates ID, so the two panes stay visually identical; the mask and validator
 *   are lifted verbatim from eoiParTypologyJourney, which already solved this.
 *   A manual resident lands Status__c='New' and therefore routes through the
 *   existing OTP screen with no extra wiring, where UAE Pass lands 'Verified'.
 *
 *   Payment rail is switchable too. Custom Label EOI_Site_Payment_Mode selects
 *   'Embedded' (the same-origin Checkout iframe, unchanged) or 'Hosted' (redirect
 *   to the hosted payment page and back to ?paymentResult=success&ref=). The
 *   hosted rail needed NO new Apex - EOIWadeemSiteController.startCardPayment
 *   already existed and was simply never called from here.
 *   Labels are read with a string compare (=== 'true'), the house pattern; see
 *   eoiSlaTimer. They compile into the bundle, so they work for guest users.
 */
import { LightningElement, api, track } from 'lwc';
import basePath from '@salesforce/community/basePath';
import { recaptchaFramePath, requestRecaptchaToken } from 'c/eoiRecaptchaClient';
import getUaePassAuthorizeUrl from '@salesforce/apex/EOIWadeemSiteController.getUaePassAuthorizeUrl';
import completeUaePass from '@salesforce/apex/EOIWadeemSiteController.completeUaePass';
import beginSignIn from '@salesforce/apex/EOIWadeemSiteController.beginSignIn';
import completeDetails from '@salesforce/apex/EOIWadeemSiteController.completeDetails';
import getSignInState from '@salesforce/apex/EOIWadeemSiteController.getSignInState';
import startCardPaymentSession from '@salesforce/apex/EOIWadeemSiteController.startCardPaymentSession';
import confirmCardPayment from '@salesforce/apex/EOIWadeemSiteController.confirmCardPayment';
import finalizeCardPayment from '@salesforce/apex/EOIWadeemSiteController.finalizeCardPayment';
import getPaymentState from '@salesforce/apex/EOIWadeemSiteController.getPaymentState';
import getMyRegistrations from '@salesforce/apex/EOIWadeemSiteController.getMyRegistrations';
import requestRefund from '@salesforce/apex/EOIWadeemSiteController.requestRefund';
import cancelRegistration from '@salesforce/apex/EOIWadeemSiteController.cancelRegistration';
import getJourneyState from '@salesforce/apex/EOIWadeemSiteController.getJourneyState';
import startCardPayment from '@salesforce/apex/EOIWadeemSiteController.startCardPayment';
import getSiteConfig from '@salesforce/apex/EOIWadeemSiteController.getSiteConfig';
import recordSelection from '@salesforce/apex/EOIWadeemSiteController.recordSelection';
import recordActivity from '@salesforce/apex/EOIWadeemSiteController.recordActivity';

const UAE_PASS_AVAILABLE = false; // MEOI-UAELOCK - code-level kill switch, see showUaePass()
const JOURNEY_KEY = 'eoiWadeemJourney';
/* MEOI-ACT. The activity diary: what the customer did, buffered in the page and posted in
   batches (one Task per batch on the visitor). Switched by EOI_Site_Activity_Detail_Enabled,
   read from the server config - off means nothing is buffered or sent. */
const ACTIVITY_KEY = 'eoiWadeemActivity';
const ACTIVITY_MAX_BUFFER = 500;
const ACTIVITY_MAX_BATCH = 200;
const ACTIVITY_MAX_RETRIES = 2;
const PHASE_LABELS = {
    identity: 'Identity', otp: 'Verify', signin: 'Verify', welcome: 'My registrations',
    typology: 'EOI Selection', review: 'Payment', payCard: 'Payment', payPending: 'Payment',
    payFailed: 'Payment', done: 'Thank you', thanks: 'Thank you', expired: 'Session ended', closed: 'Closed'
};

// Wadeem draft renders (client PPTX extracts) used until the builder property
// points at a project's own cleared typology set (a non-empty value wins).
const DEFAULT_TYPOLOGY_IMAGE_BASE = '/sfsites/c/resource/Wadeem_Assets/villas'; // MEOI-TILES2 (13 Sep 2026): new folder = new paths; the image-optimisation CDN ignores ?v= and kept serving the old typologies/*.jpg

// Emirates ID: 784-XXXX-XXXXXXX-X. Lifted from eoiParTypologyJourney.
/* MEOI-PHONE. Same rule as the org's public EOI journey: +, country code not starting
   with 0, 8-15 digits. Spaces/dashes are stripped before the test and before sending. */
const PHONE_PATTERN = /^\+[1-9][0-9]{7,14}$/;
const PHONE_MESSAGE = 'Please enter a valid phone number with country code (e.g., +9715XXXXXXXX). Country code must not start with 0.';
const cleanPhone = (v) => String(v || '').replace(/[^0-9+]/g, '');
const EID_PATTERN = /^784-[0-9]{4}-[0-9]{7}-[0-9]{1}$/;

/* MEOI-ID2. Two registration types, not three. Residency is a property of an individual,
   not a separate kind of registrant, so it moved inside the Individual pane where the
   customer answers it after giving their details - and it decides one field, the identity
   document. Previously "UAE Resident" and "Non-Resident" were sibling tabs of
   "Organization", which put a person's nationality on the same footing as being a company. */
/* MEOI-A11. Fifteen minutes with no click, key, pointer or scroll ends the session on
   every screen. Checked every 30 seconds rather than on a single long timer so a laptop
   waking from sleep expires promptly instead of running the clock from before it slept. */
const IDLE_LIMIT_MS = 15 * 60 * 1000;
const IDLE_TICK_MS = 30 * 1000;
const ACTIVITY_EVENTS = ['click', 'keydown', 'pointerdown', 'touchstart', 'scroll'];

/* MEOI-A1. Per-unit payment key - MUST match EOIService: 15 chars of the Id, '#', index. */
function lineKeyFor(rangeId, unitIndex) {
    return String(rangeId).slice(0, 15) + '#' + unitIndex;
}

const TAB_IND = 'Ind';
const TAB_ORG = 'Org';
const RES_YES = 'Resident';
const RES_NO = 'Non-Resident';

/* MSC-247. Sign-in first: the code is proven before the form, so Verify leads the rail.
   The browser id is kept across visits; the sign-in session id comes from the server. */
const RAIL_LABELS = ['Verify', 'Identity', 'EOI Selection', 'Payment'];
const DEVICE_KEY = 'eoiDeviceId';
const CH_EMAIL = 'Email';
const CH_SMS = 'SMS';
const FORM_KEYS = ['firstName', 'lastName', 'email', 'mobile', 'emiratesId', 'passportNumber',
    'companyName', 'tradeLicenseNumber', 'tradeLicenseExpiryDate', 'registeredEmail', 'registeredPhone',
    'authorizedFirstName', 'authorizedLastName', 'authorizedEmail', 'authorizedPhone'];
const IDENTITY_SUB = 'Tell us who you are. Your details stay private and are used only for this expression of interest.';
function emptyForm() {
    const f = {};
    FORM_KEYS.forEach((k) => { f[k] = ''; });
    return f;
}
function newDeviceId() {
    try {
        if (window.crypto && window.crypto.randomUUID) {
            return window.crypto.randomUUID();
        }
    } catch (e) {
        /* fall through */
    }
    return 'd-' + Date.now().toString(36) + '-' + Math.random().toString(36).slice(2, 10);
}

export default class EoiIdentityChooser extends LightningElement {
    @api eyebrow = 'Expression of Interest';
    @api heading = 'Register your interest';
    @api uaePassButtonImage = '';
    @api uaePassNote = 'You’ll be redirected to UAE PASS and returned here to continue.';
    @api backUrl = '';
    @api helpLine = '';
    @api contactUrl = '';
    @api projectId = '';
    @api typologyImageBase = '';

    @track tab = TAB_IND;
    @track residency = RES_YES;

    /* MEOI-CFG. Read from Apex on mount, not imported as labels: @salesforce/label is
       baked in at bundle compile time, so a Setup edit would not reach the page until
       both sites were republished. Defaults below are today's behaviour, so a slow or
       failed config call degrades to exactly what shipped. */
    /* MEOI-UAEFLASH (10 Sep). Defaults are the OFF state: the button must never render on a
       guess. Before this, uaePassEnabled defaulted to true, so the UAE PASS button showed
       for the ~300 ms until getSiteConfig returned false and then vanished. */
    @track siteConfig = { uaePassEnabled: false, refundEnabled: false, paymentMode: 'Embedded' };
    @track configLoaded = false;
    @track isBusy = false;
    @track errorMessage = '';
    @track verified = null;   // UaePassResult after a successful callback
    @track submittedId = null;
    @track otpVerified = false;
    @track phase = 'signin'; // signin | otp | identity | welcome | typology | review | payCard | payPending | payFailed | done | closed
    @track signIn = { channel: CH_EMAIL, value: '' };
    @track signInRequest = null;  // the code request made on the sign-in screen
    @track signInTarget = '';     // the proven email or mobile, locked on the form
    signInSession = null;         // server-issued; proves this tab did the sign-in
    signInLocked = false;         // false only for a form-first row from before sign-in first
    @track prefill = null;        // returning person: last completed details, editable
    // Embedded Checkout Flow (MSC-243). The card form is mounted by the
    // CheckoutFlowContainer Visualforce page inside an iframe on this page; we hand it
    // the session over postMessage and it hands us back the outcome.
    @track checkoutInit = null;
    @track payingLine = null;   // what the mounted card form is charging, for the summary row
    @track cardFrameHeight = 0; // container-reported content height (checkout-size)
    readyTimer = null;          // the container must post checkout-ready within this window
    pendingPollTimer = null;    // payPending: quiet server re-check until capture lands
    pendingPollTicks = 0;
    boundFrameMessage;
    @track paymentReference = '';
    @track lines = [];
    @track paid = {};         // rangeId -> PaymentLineState from the server
    @track history = [];      // RegistrationCard list for the welcome-back view

    form = emptyForm();
    honeypot = '';
    loadedAt = Date.now();
    savedPhase = null;        // phase restored from the journey snapshot
    numbersPollTimer = null;  // fills system-generated EOI numbers in as they land
    numbersPollTicks = 0;
    @track numbersPollExhausted = false;
    @track busyLabel = '';    // what the blocking loader says during long waits

    disconnectedCallback() {
        this.stopActivityWatch();
        this.stopIdleWatch();
        this.stopNumbersPoll(false);
        this.stopPendingPoll();
        this.clearReadyTimer();
        if (this.boundFrameMessage) {
            window.removeEventListener('message', this.boundFrameMessage);
            this.boundFrameMessage = undefined;
        }
    }

    connectedCallback() {
        this.loadSiteConfig();
        this.startIdleWatch();
        this.boundFrameMessage = this.handleFrameMessage.bind(this);
        window.addEventListener('message', this.boundFrameMessage);
        if (this.handlePaymentReturn()) {
            return;
        }
        if (this.handleUaePassCallback()) {
            return;
        }
        this.resumeJourney();
    }

    // ---------- Checkout payment return ----------

    handlePaymentReturn() {
        let params;
        try {
            params = new URLSearchParams(window.location.search || '');
        } catch (e) {
            return false;
        }
        const result = params.get('paymentResult');
        if (!result) {
            return false;
        }
        const reference = params.get('ref') || '';
        /* MEOI-FRAME (11 Sep 2026). This page must never run the payment return while it is
           inside a frame: that is how the whole microsite once rendered inside its own card
           box and confirmed the same payment twice. Hand the outcome to the page that owns
           the frame and stop. Deliberately scoped to a payment return, so Experience
           Builder's own preview iframe is untouched - it never carries these parameters. */
        if (window.top !== window.self) {
            try {
                window.parent.postMessage({
                    type: 'checkout-result',
                    outcome: result === 'success' ? 'completed' : 'failed',
                    via: 'redirect',
                    reference
                }, window.location.origin);
            } catch (e) {
                /* nothing else this frame can usefully do */
            }
            this.cleanUrl();
            return true;
        }
        this.cleanUrl();
        this.restoreJourney();
        // the customer already completed the journey once - never let the
        // min-elapsed bot gate reject a quick retry after a payment return
        this.loadedAt = Date.now() - 60000;
        this.paymentReference = reference;
        if (result === 'success' && reference) {
            this.phase = 'payPending';
            this.startPendingPoll();
            this.confirmAndFinalize(reference);
        } else if (result === 'cancelled' || result === 'failed') {
            this.handleFailedReturn(result === 'cancelled'
                ? 'The payment was cancelled and no amount was collected.'
                : 'The payment was not completed and no amount was collected.');
        } else {
            this.handleFailedReturn('The payment was not completed.');
        }
        return true;
    }

    /** A failed leg still refreshes the checklist so earlier paid types stay marked. */
    handleFailedReturn(message) {
        if (this.submittedId && this.lines.length) {
            this.isBusy = true;
            this.refreshPaymentState()
                .then(() => {
                    if (this.phase === 'review') {
                        this.errorMessage = message + ' You can try again.';
                    }
                })
                .catch(() => {
                    this.showPaymentFailure(message);
                })
                .finally(() => {
                    this.isBusy = false;
                });
        } else {
            this.showPaymentFailure(message);
        }
    }

    confirmAndFinalize(reference) {
        this.isBusy = true;
        this.busyLabel = 'Confirming your payment';
        this.errorMessage = '';
        confirmCardPayment({ reference })
            .then((res) => {
                if (res.status === 'Captured' || res.finalized) {
                    return finalizeCardPayment({ reference })
                        .then(() => this.refreshPaymentState())
                        .then(() => {
                            if (this.phase === 'review' && !this.hasAnyPaid) {
                                // whole-selection payment from before the per-type
                                // rail: the registration is closed - land on done
                                this.savePostDoneJourney();
                                this.phase = 'done';
                            }
                        });
                }
                if (res.status === 'Pending') {
                    this.phase = 'payPending';
                    this.startPendingPoll();
                } else {
                    this.handleFailedReturn('The payment was not completed and no amount was collected.');
                }
                return undefined;
            })
            .catch((e) => {
                this.phase = 'payPending';
                this.errorMessage = this.messageOf(e);
                this.startPendingPoll();
            })
            .finally(() => {
                this.isBusy = false;
                this.busyLabel = '';
            });
    }

    checkPaymentAgain() {
        if (this.paymentReference) {
            this.confirmAndFinalize(this.paymentReference);
        }
    }

    /** Rebuilds the paid map from the server without changing the screen. */
    loadPaidMap() {
        // VAPT EXT-03: the server hands the paid lines only to the tab that signed in (session id)
        return getPaymentState({ registrationId: this.submittedId, sessionId: this.signInSession }).then((states) => {
            const paid = {};
            (states || []).forEach((s) => {
                paid[s.rangeId] = s;
            });
            this.paid = paid;
            // a paid type missing from the journey (e.g. storage lost) still renders
            (states || []).forEach((s) => {
                if (!this.lines.some((l) => l.lineKey === s.rangeId)) {
                    this.lines = [...this.lines, {
                        lineKey: s.rangeId,
                        rangeId: s.baseRangeId || s.rangeId,
                        unitIndex: s.unitIndex || null,
                        unitTypology: s.unitTypology || 'Villa',
                        bedrooms: s.bedrooms || '',
                        phaseName: '',
                        quantity: s.quantity || 1,
                        lineTotal: Number(s.amount) || 0
                    }];
                }
            });
        });
    }

    /** Rebuilds the paid map from the server and routes to checklist or done. */
    refreshPaymentState() {
        return this.loadPaidMap().then(() => {
            if (this.lines.length && this.allPaid) {
                // the visit is complete; the flow settles it server-side within
                // seconds (the sweeper remains the deep backstop)
                this.savePostDoneJourney();
                // MEOI-THANKS: the last payment lands on the thank-you page only when the
                // label says so; otherwise the payment step's receipt view, as before
                this.phase = this.thankYouEnabled ? 'thanks' : 'done';
            } else {
                this.phase = 'review';
                this.saveJourney();
            }
            this.startNumbersPoll();
        });
    }

    showPaymentFailure(message) {
        if (this.submittedId && this.lines.length) {
            this.phase = 'review';
            this.errorMessage = message + ' You can try again.';
        } else {
            this.phase = 'payFailed';
            this.errorMessage = message;
        }
    }

    retryPayment() {
        window.location.assign(window.location.pathname);
    }

    /** Saved on every phase transition; a reload restores it and re-routes from
     *  server truth (getJourneyState + getPaymentState), never from the snapshot
     *  alone. */
    /* MEOI-A7a. Masked destinations carried across a reload (the form fields are not). */
    restoredHints = null;
    /* MEOI-TC. Terms accepted for this session only - saved with the journey, cleared with it. */
    @track termsAccepted = false;

    handleTermsAccepted(event) {
        /* MEOI-TC2: the on-page checkbox reports both directions; only an acceptance is a
           diary line, an untick just disables Pay again. */
        const accepted = !(event && event.detail && event.detail.accepted === false);
        if (accepted && !this.termsAccepted) {
            this.logActivity('terms', {});
        }
        this.termsAccepted = accepted;
        this.saveJourney();
    }

    // ---------- MEOI-ACT: activity diary ----------
    activity = { seq: 0, buffer: [], retries: 0 };
    /* MEOI-ACT2. Per-tab nonce in every batch key. The buffer lives in sessionStorage,
       which is per tab, so two tabs on the same registration both count 1, 2, 3...
       and their batches "1-2" would upsert over each other. The nonce makes the
       keys "<tab>.1-2" and the diary keeps both tabs' lines. */
    activityTab = '';
    /* MEOI-ACT3. One request in flight at a time. A flush that starts while another is still
       waiting for its response used to re-send the unsent lines under an overlapping key
       ("3-3" then "3-4", seen on 10 Sep); now it waits and runs once the first one returns. */
    activityInFlight = null;
    activityPending = false;
    activityTimer = null;
    activityLastPhase = null;
    fieldSnapshot = {};
    boundVisibility = null;
    boundPageHide = null;

    get activityEnabled() {
        return this.configLoaded && this.siteConfig.activityEnabled === true;
    }
    get activityFlushMs() {
        const s = Number(this.siteConfig.activityFlushSeconds);
        return (s >= 15 && s <= 900 ? s : 60) * 1000;
    }
    phaseLabel(p) {
        return PHASE_LABELS[p] || p || '';
    }

    /** One diary line. No-op while the switch is off. */
    logActivity(type, data) {
        if (!this.activityEnabled) {
            return;
        }
        try {
            this.activity.seq += 1;
            const ev = { t: Date.now(), seq: this.activity.seq, step: this.phaseLabel(this.phase), type, ...(data || {}) };
            this.activity.buffer.push(ev);
            if (this.activity.buffer.length > ACTIVITY_MAX_BUFFER) {
                this.activity.buffer.splice(0, this.activity.buffer.length - ACTIVITY_MAX_BUFFER);
            }
            this.persistActivity();
        } catch (e) {
            /* the diary must never disturb the journey */
        }
    }

    /* Field edits: one line per field per blur, only when the value changed since the last
       commit. Attached to the form containers, so no input in the markup is touched. */
    /* The value as it was when the field got focus is the "old" value: this.form is already
       updated on every keystroke by handleField, so it cannot serve as the baseline. */
    handleFormFocusIn(event) {
        const el = event.target;
        const field = el && el.dataset ? el.dataset.field : null;
        if (field && typeof el.value === 'string') {
            this.fieldSnapshot[field] = el.value;
        }
    }
    handleFormFocusOut(event) {
        const el = event.target;
        const field = el && el.dataset ? el.dataset.field : null;
        if (!field || typeof el.value !== 'string') {
            return;
        }
        const prev = Object.prototype.hasOwnProperty.call(this.fieldSnapshot, field) ? this.fieldSnapshot[field] : '';
        const next = el.value;
        if (prev === next) {
            return;
        }
        this.fieldSnapshot[field] = next;
        this.logActivity('field', { field, oldValue: prev, newValue: next });
    }

    handleLineChange(event) {
        const d = event.detail || {};
        this.logActivity('line', { detail: `${d.bedrooms || d.rangeId} ${d.action} (qty ${d.qty})` });
    }

    /** Posts the unsent lines as one batch. Silent on failure; retried at the next flush. */
    flushActivity(reason) {
        if (!this.activityEnabled || !this.activity.buffer.length || !this.submittedId || !this.signInSession) {
            return Promise.resolve();
        }
        if (this.activityInFlight) {
            this.activityPending = true;
            return this.activityInFlight;
        }
        const events = this.activity.buffer.slice(0, ACTIVITY_MAX_BATCH);
        const batchKey = `${this.activityTab || this.newActivityTab()}.${events[0].seq}-${events[events.length - 1].seq}`;
        const lastSeq = events[events.length - 1].seq;
        this.activityInFlight = recordActivity({
            registrationId: this.submittedId,
            sessionId: this.signInSession,
            batchKey,
            eventsJson: JSON.stringify(events)
        })
            .then(() => {
                this.activity.buffer = this.activity.buffer.filter((ev) => ev.seq > lastSeq);
                this.activity.retries = 0;
                this.persistActivity();
            })
            .catch(() => {
                this.activity.retries += 1;
                if (this.activity.retries > ACTIVITY_MAX_RETRIES) {
                    // give up on this batch rather than grow forever
                    this.activity.buffer = this.activity.buffer.filter((ev) => ev.seq > lastSeq);
                    this.activity.retries = 0;
                    this.persistActivity();
                }
            })
            .then(() => {
                this.activityInFlight = null;
                if (this.activityPending) {
                    this.activityPending = false;
                    this.flushActivity('chained');
                }
            });
        return this.activityInFlight;
    }

    startActivityWatch() {
        if (this.activityTimer || !this.activityEnabled) {
            return;
        }
        const jitter = Math.floor(Math.random() * 10000); // spread flushes across customers
        this.activityTimer = window.setInterval(() => this.flushActivity('timer'), this.activityFlushMs + jitter);
        this.boundVisibility = () => {
            if (document.visibilityState === 'hidden') {
                this.flushActivity('hidden');
            }
        };
        this.boundPageHide = () => this.flushActivity('pagehide');
        document.addEventListener('visibilitychange', this.boundVisibility);
        window.addEventListener('pagehide', this.boundPageHide);
    }
    stopActivityWatch() {
        if (this.activityTimer) {
            window.clearInterval(this.activityTimer);
            this.activityTimer = null;
        }
        if (this.boundVisibility) {
            document.removeEventListener('visibilitychange', this.boundVisibility);
            this.boundVisibility = null;
        }
        if (this.boundPageHide) {
            window.removeEventListener('pagehide', this.boundPageHide);
            this.boundPageHide = null;
        }
    }
    newActivityTab() {
        this.activityTab = (Date.now().toString(36).slice(-4) + Math.random().toString(36).slice(2, 6)).toLowerCase();
        return this.activityTab;
    }
    persistActivity() {
        try {
            window.sessionStorage.setItem(ACTIVITY_KEY, JSON.stringify({ seq: this.activity.seq, buffer: this.activity.buffer, tab: this.activityTab }));
        } catch (e) {
            /* storage full or unavailable - keep in memory */
        }
    }
    restoreActivity() {
        try {
            const raw = window.sessionStorage.getItem(ACTIVITY_KEY);
            if (raw) {
                const a = JSON.parse(raw);
                this.activity = { seq: a.seq || 0, buffer: Array.isArray(a.buffer) ? a.buffer : [], retries: 0 };
                this.activityTab = typeof a.tab === 'string' ? a.tab : '';
            }
        } catch (e) {
            /* cosmetic */
        }
        if (!this.activityTab) {
            this.newActivityTab();
        }
    }
    clearActivity() {
        this.activity = { seq: 0, buffer: [], retries: 0 };
        this.activityTab = '';
        this.fieldSnapshot = {};
        try {
            window.sessionStorage.removeItem(ACTIVITY_KEY);
        } catch (e) {
            /* cosmetic */
        }
    }

    /* Step changes are read off the phase each render: one line per transition, and the
       batch is flushed at that moment - the natural checkpoint of the journey. */
    renderedCallback() {
        if (this.phase !== this.activityLastPhase) {
            const from = this.activityLastPhase;
            this.activityLastPhase = this.phase;
            if (from && this.activityEnabled) {
                // review -> payCard -> review all read "Payment": log only real rail moves
                if (this.phaseLabel(from) !== this.phaseLabel(this.phase)) {
                    this.logActivity('step', { oldValue: this.phaseLabel(from), newValue: this.phaseLabel(this.phase) });
                }
                this.flushActivity('step');
            }
        }
    }

    saveJourney() {
        try {
            window.sessionStorage.setItem(JOURNEY_KEY, JSON.stringify({
                submittedId: this.submittedId,
                lines: this.lines,
                phase: this.phase,
                verifiedName: this.verified ? this.verified.fullNameEn : null,
                // MEOI-A7a: masked only - never the raw email or number - so the verify
                // step can still say where the code goes after a reload
                emailHint: this.otpEmailHint,
                mobileHint: this.otpMobileHint,
                signInSession: this.signInSession,
                signInChannel: this.signIn.channel,
                termsAccepted: this.termsAccepted === true
            }));
        } catch (e) {
            /* payment still completes server-side without the cosmetic restore */
        }
    }

    restoreJourney() {
        try {
            const raw = window.sessionStorage.getItem(JOURNEY_KEY);
            if (!raw) {
                return;
            }
            const j = JSON.parse(raw);
            this.submittedId = j.submittedId || null;
            this.restoredHints = { email: j.emailHint || '', mobile: j.mobileHint || '' };
            this.termsAccepted = j.termsAccepted === true;
            // MEOI-A1: a journey saved before per-unit lines carries no lineKey - key it
            // by rangeId so it still matches a legacy per-type payment
            this.lines = (j.lines || []).map((l) => ({ ...l, lineKey: l.lineKey || l.rangeId }));
            this.savedPhase = j.phase || null;
            if (j.verifiedName && !this.verified) {
                this.verified = { fullNameEn: j.verifiedName };
            }
            this.signInSession = j.signInSession || null;
            if (j.signInChannel === CH_EMAIL || j.signInChannel === CH_SMS) {
                this.signIn = { channel: j.signInChannel, value: '' };
            }
        } catch (e) {
            /* cosmetic only */
        }
    }

    /** Reload without URL params: restore the snapshot and land on the right
     *  screen for the registration's CURRENT server state. */
    resumeJourney() {
        this.restoreJourney();
        if (!this.submittedId) {
            return; // nothing to restore - fresh identity page
        }
        this.isBusy = true;
        getJourneyState({ registrationId: this.submittedId, sessionId: this.signInSession })
            .then((js) => {
                if (!js || !js.exists) {
                    this.resetJourney();
                    return undefined;
                }
                if (js.status === 'New') {
                    return this.resumeSignIn();
                }
                if (this.savedPhase === 'welcome' || this.savedPhase === 'otp') {
                    // verified since (or verified elsewhere): same routing as a
                    // fresh verification - welcome back when history exists
                    return this.routeAfterVerification();
                }
                if (this.savedPhase === 'typology') {
                    return Promise.all([this.loadPaidMap(), this.loadHistory()]).then(() => {
                        this.phase = 'typology';
                        this.startNumbersPoll();
                    });
                }
                if (this.lines.length) {
                    // re-merges chips, routes review/done; history alongside so the
                    // "Your registrations" link survives the reload (MEOI-A12)
                    return Promise.all([this.refreshPaymentState(), this.loadHistory()]);
                }
                return this.routeAfterVerification();
            })
            .catch(() => {
                this.resetJourney();
            })
            .finally(() => {
                this.isBusy = false;
            });
    }

    /** A New row is either a sign-in row (code screen or the locked form) or a
     *  form-first row from before sign-in first (the code screen, as before). */
    resumeSignIn() {
        return getSignInState({ registrationId: this.submittedId, sessionId: this.signInSession })
            .then((s) => {
                if (!s || !s.exists || s.status !== 'New') {
                    this.resetJourney();
                    return;
                }
                if (!s.channel) {
                    this.signInLocked = false;
                    this.phase = 'otp';
                    return;
                }
                this.signInLocked = true;
                this.signIn = { channel: s.channel, value: '' };
                this.restoredHints = {
                    email: s.channel === CH_EMAIL ? s.maskedTarget || '' : '',
                    mobile: s.channel === CH_SMS ? s.maskedTarget || '' : ''
                };
                if (s.signedIn && s.target) {
                    this.signInTarget = s.target;
                    this.prefill = s.prefill || null;
                    this.openForm();
                } else if (s.signedIn) {
                    this.resetJourney(); // proven elsewhere or the session is gone: start clean
                } else {
                    this.signInRequest = null; // the code screen re-offers sending a code
                    this.phase = 'otp';
                }
            });
    }

    // ---------- MEOI-A11: idle session expiry ----------

    idleTimer = null;
    lastActivity = Date.now();
    boundActivity = null;

    startIdleWatch() {
        this.lastActivity = Date.now();
        this.boundActivity = () => { this.lastActivity = Date.now(); };
        ACTIVITY_EVENTS.forEach((ev) => window.addEventListener(ev, this.boundActivity, { passive: true }));
        this.idleTimer = window.setInterval(() => this.checkIdle(), IDLE_TICK_MS);
    }
    stopIdleWatch() {
        if (this.idleTimer) {
            window.clearInterval(this.idleTimer);
            this.idleTimer = null;
        }
        if (this.boundActivity) {
            ACTIVITY_EVENTS.forEach((ev) => window.removeEventListener(ev, this.boundActivity));
            this.boundActivity = null;
        }
    }
    checkIdle() {
        if (this.phase === 'signin' || this.phase === 'expired') {
            return; // nothing sensitive on the front door; already ended
        }
        if (this.phase === 'payCard' || this.phase === 'payPending') {
            return; // never pull the page out from under a card form or a 3-D Secure step
        }
        if (Date.now() - this.lastActivity < IDLE_LIMIT_MS) {
            return;
        }
        this.expireSession();
    }
    expireSession() {
        this.flushActivity('expire');
        this.stopNumbersPoll(false);
        this.stopPendingPoll();
        this.clearJourney();
        this.submittedId = null;
        this.lines = [];
        this.paid = {};
        this.history = [];
        this.savedPhase = null;
        this.termsAccepted = false;
        this.errorMessage = '';
        this.isBusy = false;
        this.clearSignIn();
        this.phase = 'expired';
    }
    beginAgain() {
        this.lastActivity = Date.now();
        this.resetJourney();
    }
    get isExpired() {
        return this.phase === 'expired';
    }

    resetJourney() {
        this.clearActivity();
        this.clearJourney();
        this.submittedId = null;
        this.lines = [];
        this.paid = {};
        this.termsAccepted = false;
        this.history = [];
        this.savedPhase = null;
        this.clearSignIn();
        this.phase = 'signin';
    }

    clearSignIn() {
        this.signInRequest = null;
        this.signInSession = null;
        this.signInTarget = '';
        this.signInLocked = false;
        this.prefill = null;
        this.form = emptyForm();
        this.tab = TAB_IND;
        this.residency = RES_YES;
    }

    /** After confirmation the session is kept, pointed at the ledger: a refresh
     *  (or the View-my-registrations button) lands on Welcome back with every
     *  EOI of this customer instead of the sign-in page. */
    savePostDoneJourney() {
        try {
            window.sessionStorage.setItem(JOURNEY_KEY, JSON.stringify({
                submittedId: this.submittedId,
                lines: [],
                phase: 'welcome',
                verifiedName: this.verified ? this.verified.fullNameEn : null
            }));
        } catch (e) {
            /* cosmetic only */
        }
    }

    handleViewRegistrations() {
        this.errorMessage = '';
        this.stopNumbersPoll(false);
        this.isBusy = true;
        this.routeAfterVerification().finally(() => {
            this.isBusy = false;
        });
    }

    clearJourney() {
        try {
            window.sessionStorage.removeItem(JOURNEY_KEY);
        } catch (e) {
            /* cosmetic only */
        }
    }

    // ---------- UAE Pass ----------

    handleUaePassCallback() {
        let params;
        try {
            params = new URLSearchParams(window.location.search || '');
        } catch (e) {
            return false;
        }
        const error = params.get('error');
        const code = params.get('code');
        const state = params.get('state');
        if (!error && !code) {
            return false;
        }
        this.cleanUrl();
        if (error) {
            // user cancelled in UAE Pass ('access_denied') or provider error
            this.errorMessage = error === 'access_denied'
                ? 'UAE PASS sign-in was cancelled.'
                : 'UAE PASS sign-in did not complete. Please try again.';
            return true;
        }
        this.isBusy = true;
        completeUaePass({
            code,
            state,
            userAgent: navigator.userAgent,
            locale: 'en'
        })
            .then((result) => {
                this.verified = result;
                this.submittedId = result.registrationId;
                this.errorMessage = '';
                return this.routeAfterVerification();
            })
            .catch((e) => {
                this.errorMessage = this.messageOf(e);
            })
            .finally(() => {
                this.isBusy = false;
            });
        return true;
    }

    /** After any successful verification: welcome back when this identity already
     *  paid for something, straight to the collection otherwise. */
    routeAfterVerification() {
        return getMyRegistrations({ registrationId: this.submittedId, sessionId: this.signInSession })
            .then((cards) => {
                this.history = cards || [];
                this.phase = this.history.length ? 'welcome' : 'typology';
                this.saveJourney();
            })
            .catch(() => {
                this.phase = 'typology';
                this.saveJourney();
            });
    }

    /* MEOI-A12. History is not part of the saved journey, so a reload used to leave it
       empty and the "Your registrations" link vanished from the EOI Selection step.
       Re-fetched on resume; a failure only keeps the link hidden. */
    loadHistory() {
        if (!this.submittedId) {
            return Promise.resolve();
        }
        return getMyRegistrations({ registrationId: this.submittedId, sessionId: this.signInSession })
            .then((cards) => {
                this.history = cards || [];
            })
            .catch(() => {
                /* link stays hidden */
            });
    }

    handleRegisterAnother() {
        this.errorMessage = '';
        this.phase = 'typology';
        this.saveJourney();
    }

    /** Code step: back to the sign-in screen with the typed value kept (the
     *  abandoned staging row simply stays New and is never verified). */
    handleOtpBack() {
        this.errorMessage = '';
        const keep = this.signIn;
        this.resetJourney();
        this.signIn = keep;
    }

    /** Typology: back to the welcome view - only offered when history exists. */
    handleTypologyBackToWelcome() {
        this.errorMessage = '';
        this.phase = 'welcome';
        this.saveJourney();
    }

    get hasHistory() {
        return (this.history || []).length > 0;
    }

    handleRequestRefund(event) {
        const reference = event.detail.reference;
        this.errorMessage = '';
        this.isBusy = true;
        requestRefund({ registrationId: this.submittedId, reference, sessionId: this.signInSession })
            .then((card) => {
                this.history = this.history.map((c) => (c.reference === reference ? card : c));
            })
            .catch((e) => {
                this.errorMessage = this.messageOf(e);
            })
            .finally(() => {
                this.isBusy = false;
            });
    }

    /* MEOI-CANCEL (11 Sep 2026). The customer voids a hold from "Your registrations": the
       server releases it at Checkout and closes the records, the card flips to Cancelled,
       the paid map is refreshed so the residence type is payable again, and the diary
       gets a line of its own. */
    handleCancelRegistration(event) {
        const reference = event.detail.reference;
        const card = (this.history || []).find((c) => c.reference === reference);
        this.errorMessage = '';
        this.isBusy = true;
        cancelRegistration({ registrationId: this.submittedId, reference, sessionId: this.signInSession })
            .then((updated) => {
                this.history = this.history.map((c) => (c.reference === reference ? updated : c));
                const eoi = updated && updated.eoiNumbers && updated.eoiNumbers.length
                    ? updated.eoiNumbers.join(' ') + ' · ' : '';
                const name = (card && card.unitTypology) || 'Villa';
                const amt = card && card.amount != null ? ' · AED ' + card.amount : '';
                this.logActivity('cancel', { detail: `${eoi}${name}${amt} (hold released)` });
                this.flushActivity('cancel');
                return this.loadPaidMap().catch(() => {});
            })
            .catch((e) => {
                this.errorMessage = this.messageOf(e);
            })
            .finally(() => {
                this.isBusy = false;
            });
    }

    startUaePass() {
        this.errorMessage = '';
        this.isBusy = true;
        this.busyLabel = 'Connecting to UAE PASS';
        getUaePassAuthorizeUrl()
            .then((url) => {
                window.location.assign(url);
            })
            .catch((e) => {
                this.errorMessage = this.messageOf(e);
                this.isBusy = false;
                this.busyLabel = '';
            });
    }

    cleanUrl() {
        try {
            window.history.replaceState({}, document.title, window.location.pathname);
        } catch (e) {
            /* cosmetic only */
        }
    }

    // ---------- forms ----------

    handleField(event) {
        this.form = { ...this.form, [event.target.dataset.field]: event.target.value };
    }

    /* MEOI-HP (10 Sep 2026). The hidden honeypot inputs are gone: Chromium autofill was
       filling the off-screen field together with the name and email, and real customers
       were refused with "Submission rejected." (tester report, 9 Sep). The forms are
       already gated by the OTP, so nothing is lost. `honeypot` is still sent, always
       blank, so the server signatures and their dormant checks stay untouched. */

    /* Manual resident path - only reachable while EOI_Site_UAE_Pass_Enabled is not
       'true'. Emirates ID is masked as the customer types and validated before the
       call, so a malformed id never reaches Apex. */
    handleEmiratesId(event) {
        const masked = this.formatEmiratesId(event.target.value);
        event.target.value = masked;
        this.form = { ...this.form, emiratesId: masked };
    }

    formatEmiratesId(value) {
        let digits = (value || '').replace(/\D/g, '');
        if (digits.length < 3) {
            digits = '784';
        } else if (!digits.startsWith('784')) {
            digits = '784' + digits;
        }
        digits = digits.substring(0, 15);
        const parts = ['784'];
        if (digits.length > 3) {
            parts.push(digits.substring(3, 7));
        }
        if (digits.length > 7) {
            parts.push(digits.substring(7, 14));
        }
        if (digits.length > 14) {
            parts.push(digits.substring(14, 15));
        }
        return parts.join('-') + (digits.length <= 3 ? '-' : '');
    }

    /* One submit for both residencies - only the identity document differs, and the Apex
       branches on residentStatus, so sending two shapes from here would just duplicate a
       decision the server already makes. */
    submitIndividual() {
        const resident = this.isResident;
        if (resident && !EID_PATTERN.test(this.form.emiratesId || '')) {
            this.errorMessage =
                'Please enter a valid Emirates ID in the format 784-XXXX-XXXXXXX-X.';
            return;
        }
        if (!resident && !(this.form.passportNumber || '').trim()) {
            this.errorMessage = 'Please enter your passport number.';
            return;
        }
        const mobile = cleanPhone(this.form.mobile);
        if (!PHONE_PATTERN.test(mobile)) {
            this.errorMessage = PHONE_MESSAGE;
            return;
        }
        this.submit({
            customerType: 'Individual',
            residentStatus: resident ? RES_YES : 'Non Resident',
            firstName: this.form.firstName,
            lastName: this.form.lastName,
            email: this.form.email,
            mobile,
            emiratesId: resident ? this.form.emiratesId : null,
            passportNumber: resident ? null : this.form.passportNumber
        });
    }

    selectResidency(event) {
        if (this.isBusy) {
            return;
        }
        if (this.residency !== event.currentTarget.dataset.res) {
            this.logActivity('choice', { field: 'residency', oldValue: this.residency, newValue: event.currentTarget.dataset.res });
        }
        this.residency = event.currentTarget.dataset.res;
        this.errorMessage = '';
    }

    submitOrganization() {
        const registeredPhone = cleanPhone(this.form.registeredPhone);
        const authorizedPhone = cleanPhone(this.form.authorizedPhone);
        if (!PHONE_PATTERN.test(registeredPhone) || !PHONE_PATTERN.test(authorizedPhone)) {
            this.errorMessage = PHONE_MESSAGE;
            return;
        }
        this.submit({
            customerType: 'Organization',
            companyName: this.form.companyName,
            tradeLicenseNumber: this.form.tradeLicenseNumber,
            tradeLicenseExpiryDate: this.form.tradeLicenseExpiryDate || null,
            registeredEmail: this.form.registeredEmail,
            registeredPhone,
            authorizedFirstName: this.form.authorizedFirstName,
            authorizedLastName: this.form.authorizedLastName,
            authorizedEmail: this.form.authorizedEmail,
            authorizedPhone
        });
    }

    /* MSC-247. The form completes the sign-in row; the proven email or mobile is
       taken from the row on the server, whatever the client sends. */
    submit(fields) {
        this.errorMessage = '';
        this.isBusy = true;
        completeDetails({
            registrationId: this.submittedId,
            sessionId: this.signInSession,
            req: {
                ...fields,
                honeypot: this.honeypot,
                userAgent: navigator.userAgent,
                locale: 'en',
                deviceId: this.deviceId(),
                sessionId: this.signInSession
            }
        })
            .then(() => {
                this.errorMessage = '';
                return this.routeAfterVerification();
            })
            .catch((e) => {
                this.errorMessage = this.messageOf(e);
            })
            .finally(() => {
                this.isBusy = false;
            });
    }

    // ---------- MSC-247: sign-in first ----------

    selectSignInChannel(event) {
        if (this.isBusy) {
            return;
        }
        const picked = event.currentTarget.dataset.value;
        if (picked === this.signIn.channel) {
            return;
        }
        this.signIn = { channel: picked, value: '' };
        this.errorMessage = '';
    }

    handleSignInValue(event) {
        this.signIn = { ...this.signIn, value: event.target.value };
    }

    handleSignInKeydown(event) {
        if (event.key === 'Enter') {
            event.preventDefault();
            this.sendSignInCode();
        }
    }

    sendSignInCode() {
        const byEmail = this.signIn.channel === CH_EMAIL;
        let target = (this.signIn.value || '').trim();
        if (!target) {
            this.errorMessage = byEmail ? 'Please enter your email address.' : 'Please enter your mobile number.';
            return;
        }
        if (!byEmail) {
            target = cleanPhone(target);
            if (!PHONE_PATTERN.test(target)) {
                this.errorMessage = PHONE_MESSAGE;
                return;
            }
        }
        this.errorMessage = '';
        this.isBusy = true;
        this.recaptchaToken('eoi_sign_in')
            .then((recaptchaToken) => beginSignIn({
                channel: this.signIn.channel,
                target,
                honeypot: this.honeypot,
                userAgent: navigator.userAgent,
                locale: 'en',
                recaptchaToken
            }))
            .then((res) => {
                this.submittedId = res.registrationId;
                this.signInSession = res.sessionId;
                this.signInRequest = res.otp;
                this.signInTarget = target;
                this.signInLocked = true;
                this.restoredHints = {
                    email: byEmail ? res.otp.maskedTarget || '' : '',
                    mobile: byEmail ? '' : res.otp.maskedTarget || ''
                };
                this.phase = 'otp';
                this.saveJourney();
            })
            .catch((e) => {
                this.errorMessage = this.messageOf(e);
            })
            .finally(() => {
                this.isBusy = false;
            });
    }

    /** The proven value is what the form shows in the locked field and what the
     *  client-side checks read; the server locks it again regardless. */
    seedLockedField() {
        const v = this.signInTarget;
        if (!v) {
            return;
        }
        if (this.signIn.channel === CH_EMAIL) {
            this.form = { ...this.form, email: v, registeredEmail: v };
        } else {
            this.form = { ...this.form, mobile: v, registeredPhone: v };
        }
    }

    deviceId() {
        try {
            let id = window.localStorage.getItem(DEVICE_KEY);
            if (!id) {
                id = newDeviceId();
                window.localStorage.setItem(DEVICE_KEY, id);
            }
            return id;
        } catch (e) {
            return null;
        }
    }

    get showSignIn() {
        return this.phase === 'signin';
    }
    get signInByEmail() {
        return this.signIn.channel === CH_EMAIL;
    }
    get signInEmailSelected() {
        return String(this.signInByEmail);
    }
    get signInSmsSelected() {
        return String(!this.signInByEmail);
    }
    get signInEmailClass() {
        return this.signInByEmail ? 'm-seg__opt is-on' : 'm-seg__opt';
    }
    get signInSmsClass() {
        return this.signInByEmail ? 'm-seg__opt' : 'm-seg__opt is-on';
    }
    get signInLabel() {
        return this.signInByEmail ? 'Email address' : 'Mobile number';
    }
    get signInType() {
        return this.signInByEmail ? 'email' : 'tel';
    }
    get signInAutocomplete() {
        return this.signInByEmail ? 'email' : 'tel';
    }
    get signInPlaceholder() {
        return this.signInByEmail ? 'name@example.com' : '+971 5x xxx xxxx';
    }
    get signInValue() {
        return this.signIn.value;
    }
    get otpLockedChannel() {
        return this.signInLocked ? this.signIn.channel : '';
    }
    get isEmailLocked() {
        return !!this.signInTarget && this.signIn.channel === CH_EMAIL;
    }
    get isMobileLocked() {
        return !!this.signInTarget && this.signIn.channel === CH_SMS;
    }

    messageOf(e) {
        const body = e && e.body;
        if (body && body.message) {
            return body.message;
        }
        return 'Something went wrong. Please try again.';
    }

    // ---------- tabs & view state ----------

    selectTab(event) {
        const picked = event.currentTarget.dataset.tab;
        if (this.lockedTab && picked !== this.lockedTab) {
            return; // already registered with us as the other type
        }
        if (this.tab !== picked) {
            this.logActivity('choice', { field: 'registrationType', oldValue: this.tab, newValue: picked });
        }
        this.tab = picked;
        this.errorMessage = '';
    }

    goBack() {
        if (this.backUrl) {
            window.location.assign(this.backUrl);
        } else {
            window.history.back();
        }
    }

    /** The code passed: the form comes next, with the proven field locked. A form-first
     *  row from before sign-in first is already complete and routes on as before. */
    handleOtpVerified() {
        this.logActivity('choice', { field: 'verificationChannel', newValue: (this.signIn && this.signIn.channel) || '' });
        this.otpVerified = true;
        this.errorMessage = '';
        if (!this.signInLocked) {
            this.isBusy = true;
            this.routeAfterVerification().finally(() => {
                this.isBusy = false;
            });
            return;
        }
        // the server hands this tab the proven value and, for a returning person, their last details
        this.isBusy = true;
        getSignInState({ registrationId: this.submittedId, sessionId: this.signInSession })
            .then((s) => {
                if (s && s.target) {
                    this.signInTarget = s.target;
                }
                this.prefill = (s && s.prefill) || null;
            })
            .catch(() => {
                /* the server locks the proven value on submit regardless */
            })
            .finally(() => {
                this.isBusy = false;
                this.openForm();
            });
    }

    openForm() {
        this.applyPrefill();
        this.seedLockedField();
        this.phase = 'identity';
        this.saveJourney();
    }

    /** Last completed details as the starting point; every field stays editable. */
    applyPrefill() {
        const p = this.prefill;
        if (!p) {
            return;
        }
        this.tab = p.customerType === 'Organization' ? TAB_ORG : TAB_IND;
        if (p.residentStatus) {
            this.residency = p.residentStatus === 'Resident' ? RES_YES : RES_NO;
        }
        const f = emptyForm();
        FORM_KEYS.forEach((k) => {
            if (p[k] !== undefined && p[k] !== null) {
                f[k] = String(p[k]);
            }
        });
        this.form = f;
    }

    /* A returning customer keeps the type their earlier registration used: that visit is
       already tied to a customer record in Salesforce, and a second type would split it. */
    get lockedTab() {
        const t = this.prefill && this.prefill.customerType;
        if (!t) {
            return null;
        }
        return t === 'Organization' ? TAB_ORG : TAB_IND;
    }
    get indTabDisabled() {
        return !!this.lockedTab && this.lockedTab !== TAB_IND;
    }
    get orgTabDisabled() {
        return !!this.lockedTab && this.lockedTab !== TAB_ORG;
    }
    get typeLockNote() {
        if (!this.lockedTab) {
            return '';
        }
        const asWhat = this.lockedTab === TAB_ORG ? 'an organisation' : 'an individual';
        return this.prefill && this.prefill.crmMatched
            ? `You are registered with us as ${asWhat}. Please contact us if this needs to change.`
            : `You are registered with us as ${asWhat}.`;
    }

    get identitySub() {
        if (!this.prefill) {
            return IDENTITY_SUB;
        }
        const name = (this.prefill.greetName || '').trim();
        return (name ? `Welcome back, ${name}. ` : 'Welcome back. ')
            + 'Your details from your previous registration are shown below. Please review and continue.';
    }

    /* MEOI-A1. The picker still speaks in typology + quantity; from here on every unit
       is its own line with its own key, so it gets its own payment. Indices continue
       after any unit of that typology already paid, so a returning customer's new units
       never collide with a settled one. Paid lines are pinned; the unpaid remainder is
       rebuilt from what the picker sends. */
    handleTypologyContinue(event) {
        const paidLines = this.lines.filter((l) => this.paid[l.lineKey]);
        const nextIndex = (rangeId) => {
            const prefix = String(rangeId).slice(0, 15) + '#';
            let max = 0;
            Object.keys(this.paid || {}).forEach((k) => {
                if (k.indexOf(prefix) === 0) {
                    const n = parseInt(k.slice(prefix.length), 10);
                    if (!isNaN(n) && n > max) { max = n; }
                }
            });
            return max + 1;
        };
        const fresh = [];
        (event.detail.lines || []).forEach((l) => {
            const qty = Math.max(1, parseInt(l.quantity, 10) || 1);
            const unit = l.quantity ? (l.lineTotal || 0) / l.quantity : (l.lineTotal || 0);
            let idx = nextIndex(l.rangeId);
            for (let i = 0; i < qty; i += 1, idx += 1) {
                fresh.push({ ...l, quantity: 1, lineTotal: unit, unitIndex: idx, lineKey: lineKeyFor(l.rangeId, idx) });
            }
        });
        this.lines = [...paidLines, ...fresh];
        this.phase = 'review';
        this.errorMessage = '';
        this.saveJourney();
        this.startNumbersPoll();
        this.recordSelectionActivity();
    }

    /** Milestone only: Salesforce writes a "Residences selected" activity. Never blocks. */
    recordSelectionActivity() {
        if (!this.submittedId || !this.lines.length) {
            return;
        }
        const byRange = {};
        this.lines.forEach((l) => { byRange[l.rangeId] = (byRange[l.rangeId] || 0) + 1; });
        const lines = Object.keys(byRange).map((rangeId) => ({ rangeId, quantity: byRange[rangeId] }));
        recordSelection({ registrationId: this.submittedId, lines, sessionId: this.signInSession }).catch(() => {});
    }

    handleChecklistBack() {
        this.errorMessage = '';
        this.phase = 'typology';
        this.saveJourney();
    }

    handleRemoveLine(event) {
        const key = event.detail.lineKey || event.detail.rangeId;
        if (this.paid[key]) {
            return; // paid lines are settled and cannot be removed
        }
        const gone = this.lines.find((l) => l.lineKey === key);
        this.logActivity('remove', { detail: gone ? `${gone.bedrooms || gone.unitTypology} (${key})` : key });
        this.lines = this.lines.filter((l) => l.lineKey !== key);
        this.saveJourney();
        if (!this.lines.length) {
            this.phase = 'typology';
        } else if (this.allPaid) {
            this.savePostDoneJourney();
            this.phase = 'done';
        }
    }

    handlePayLine(event) {
        const key = event.detail.lineKey || event.detail.rangeId;
        const line = this.lines.find((l) => l.lineKey === key);
        if (!line || this.paid[key]) {
            return;
        }
        this.logActivity('pay', { detail: `${line.bedrooms || line.unitTypology} (${key}) AED ${line.lineTotal || ''}` });
        const rangeId = line.rangeId;
        this.errorMessage = '';
        this.stopNumbersPoll(false); // nothing may re-render under the mounted card form
        this.isBusy = true;
        this.busyLabel = this.isHostedPayment
            ? 'Opening the secure payment page'
            : 'Opening the secure card form';
        const unit = line.quantity ? (line.lineTotal || 0) / line.quantity : 0;
        this.payingLine = {
            name: line.unitTypology || 'Villa',
            meta: `${line.quantity} \u00D7 AED ${this.fmt(unit)}`,
            amount: this.fmt(line.lineTotal || 0)
        };
        /* MEOI-12. One set of arguments, two rails. Every server-side guard - honeypot,
           minimum elapsed time, quantity clamp, verified-status gate, quota, the
           server-read range price, already-paid and the open-link cap - lives above the
           callout in EOIService and is shared by both, so a guard can never be fixed in
           one rail and missed in the other. */
        const startPayment = this.isHostedPayment ? startCardPayment : startCardPaymentSession;
        this.recaptchaToken('eoi_payment')
            .then((recaptchaToken) => startPayment({
                registrationId: this.submittedId,
                sessionId: this.signInSession, // VAPT: the tab's proof, checked server-side
                projectId: this.projectId,
                rangeId,
                quantity: 1,
                elapsedMs: Date.now() - this.loadedAt,
                honeypot: this.honeypot,
                unitIndex: line.unitIndex || null,
                recaptchaToken
            }))
            .then((res) => {
                /* Hosted rail: leave the page for the payment provider and come back to
                   ?paymentResult=success&ref=. Save the journey FIRST - once we navigate
                   away this component is torn down, and the reference is the only thing
                   that lets the return leg find the payment again. */
                if (res.status === 'Redirect' && res.redirectUrl) {
                    this.paymentReference = res.reference;
                    this.saveJourney();
                    window.location.assign(res.redirectUrl);
                    return;
                }
                if (res.status === 'Session' && res.sessionResponse) {
                    // The journey is saved before the form mounts: a 3-D Secure challenge can
                    // still take the whole page, and the ?paymentResult=&ref= return leg then
                    // resumes exactly as the hosted rail does.
                    this.paymentReference = res.reference;
                    this.saveJourney();
                    this.mountCardForm(res);
                    return;
                }
                this.isBusy = false;
                this.busyLabel = '';
                if (res.status === 'QuotaClosed') {
                    if (this.hasAnyPaid) {
                        this.errorMessage = res.message || 'EOI submissions are closed for the selected project.';
                    } else {
                        this.phase = 'closed';
                    }
                } else if (res.status === 'AlreadyPaid' && res.reference) {
                    // this type is already covered - settle it and refresh the checklist
                    this.paymentReference = res.reference;
                    this.confirmAndFinalize(res.reference);
                } else {
                    this.errorMessage = res.message || 'The payment could not be started. Please try again.';
                }
            })
            .catch((e) => {
                this.isBusy = false;
                this.busyLabel = '';
                this.errorMessage = this.messageOf(e);
            });
    }

    // ---------- Embedded Checkout Flow (MSC-243) ----------

    /** Holds the session until the container tells us it is listening. The iframe is
     *  same-origin (the Visualforce page is served under this site), so the container's
     *  own origin allowlist and ours both pass without a cross-origin CSP entry. */
    mountCardForm(res) {
        let session;
        try {
            session = JSON.parse(res.sessionResponse);
        } catch (e) {
            this.isBusy = false;
            this.busyLabel = '';
            this.errorMessage = 'The secure card form could not be prepared. Please try again.';
            return;
        }
        this.checkoutInit = {
            type: 'checkout-init',
            publicKey: res.publicKey,
            // The publishable key carries its own environment; sandbox keys are pk_sbox_*.
            environment: (res.publicKey || '').indexOf('pk_sbox_') === 0 ? 'sandbox' : 'production',
            paymentSession: session
        };
        this.cardFrameHeight = 0;
        // The LWR site does not serve Visualforce; its Force.com twin on the SAME
        // host does, so the frame stays same-origin under /eoivforcesite. The ?v=
        // cache-bust is frozen here for the life of the mount (site VF s-maxage=600).
        this.cardFrameUrl = '/eoivforcesite/apex/CheckoutFlowContainer?v=' + Date.now();
        this.phase = 'payCard';
        this.isBusy = false;
        this.busyLabel = '';
        // stay-on-page rule: if the container never reports ready, re-arm the
        // checklist with a clear error instead of leaving a dead form
        this.clearReadyTimer();
        this.readyTimer = window.setTimeout(() => {
            this.readyTimer = null;
            if (this.phase === 'payCard' && this.checkoutInit) {
                this.checkoutInit = null;
                this.phase = 'review';
                this.errorMessage = 'The secure card form could not be loaded. Please try again.';
            }
        }, 12000);
    }

    clearReadyTimer() {
        if (this.readyTimer) {
            window.clearTimeout(this.readyTimer);
            this.readyTimer = null;
        }
    }

    handleFrameMessage(event) {
        // Same-origin only. The container posts to '*' because it cannot know our host.
        if (!this.checkoutInit || event.origin !== window.location.origin) {
            return;
        }
        const data = event.data || {};
        if (data.type === 'checkout-ready') {
            this.clearReadyTimer();
            const frame = this.template.querySelector('iframe.cko-frame');
            if (frame && frame.contentWindow) {
                frame.contentWindow.postMessage(this.checkoutInit, window.location.origin);
            }
            return;
        }
        if (data.type === 'checkout-size') {
            const h = parseInt(data.height, 10);
            if (h > 0) {
                // clamp so a mis-report can never collapse or blow up the layout
                this.cardFrameHeight = Math.min(720, Math.max(360, h));
            }
            return;
        }
        if (data.type !== 'checkout-result') {
            return;
        }
        if (data.outcome === 'completed') {
            // Money has moved. Everything from here is the same path the hosted rail
            // takes on its return leg, so a interrupted session still settles via the sweeper.
            this.checkoutInit = null;
            this.confirmAndFinalize(this.paymentReference);
        } else if (data.via === 'redirect') {
            /* MEOI-FRAME. The card form navigated away to come back with this result, so
               there is no live session left to retry in place. Return to the checklist:
               the next Pay & register press mounts a fresh form and a fresh session. */
            this.clearReadyTimer();
            this.checkoutInit = null;
            this.startNumbersPoll();
            this.errorMessage = data.message
                || 'The payment was not completed and no amount was collected. Please try again.';
            this.phase = 'review';
        } else {
            // Card declined or the SDK failed: the session is still valid, so leave the
            // form mounted and let the customer try another card.
            this.errorMessage = data.message || 'The payment could not be completed. Please try again.';
        }
    }

    /** Leaves the card step without paying. The payment row stays open and is picked up
     *  by the poller or the sweeper if it did in fact capture. */
    handleCancelCard() {
        this.clearReadyTimer();
        this.startNumbersPoll();
        this.checkoutInit = null;
        this.errorMessage = '';
        this.phase = 'review';
    }

    get isPayCard() {
        return this.phase === 'payCard';
    }

    get cardFrameStyle() {
        return this.cardFrameHeight ? `height:${this.cardFrameHeight}px` : '';
    }
    // Set ONCE per mount (mountCardForm). Never a getter: a getter re-evaluates on
    // every re-render, and a fresh ?v= value would make the iframe reload the whole
    // card form each time any tracked state changes (e.g. a background poll tick).
    @track cardFrameUrl = '';

    get effectiveTypologyImageBase() {
        return this.typologyImageBase || DEFAULT_TYPOLOGY_IMAGE_BASE;
    }
    /* MEOI-A10 (corrected). The Confirm & pay screen shows only what is still to be paid.
       Settled lines stay in `lines` - the receipt and the EOI-number poll need them - but
       they are not handed to the review component, so a paid card never renders there
       again. Selecting the same typology later gives a fresh line with the next unit index. */
    get unpaidLines() {
        return (this.lines || []).filter((l) => !this.paid[l.lineKey]);
    }
    /* MEOI-A10b (10 Sep, Prateek/Mridul). The Confirm & pay screen shows THIS VISIT's units,
       paid and unpaid: a unit paid a moment ago stays on the list as a Paid card with its
       EOI number, next to the ones still to pay. `lines` is the visit's own selection (saved
       in sessionStorage, cleared on session end), and the paid map is loaded for this
       sign-in's registration only - so earlier, already-registered EOIs can never appear
       here; they live on "My registrations". */
    get visitLines() {
        return this.lines || [];
    }

    get hasAnyPaid() {
        return Object.keys(this.paid || {}).length > 0;
    }
    get allPaid() {
        return this.lines.length > 0 && this.lines.every((l) => this.paid[l.lineKey]);
    }
    /** Seeds the picker with the unpaid remainder when the customer goes back. */
    get unpaidCartSeed() {
        const seed = {};
        (this.lines || []).forEach((l) => {
            if (!this.paid[l.lineKey]) {
                seed[l.rangeId] = (seed[l.rangeId] || 0) + (l.quantity || 1);
            }
        });
        return seed;
    }

    // ---------- done view ----------

    get doneRows() {
        return this.lines
            .filter((l) => this.paid[l.lineKey])
            .map((l) => {
                const p = this.paid[l.lineKey];
                const qty = p.quantity || l.quantity || 1;
                return {
                    rangeId: l.rangeId,
                    desc: `${l.bedrooms || l.unitTypology || 'Villa'}${qty > 1 ? ` × ${qty}` : ''}`,
                    displayRef: this.shortRef(p.reference),
                    formattedAmount: this.fmt(p.amount || 0),
                    eoiLabel: (p.eoiNumbers && p.eoiNumbers.length) ? p.eoiNumbers.join(' · ') : '',
                    /* MEOI-10. The EOI number is issued asynchronously, so a payment can land
                       on this screen a moment before its number exists. Say so, rather than
                       leaving a blank where a number belongs. */
                    awaitingEoi: !(p.eoiNumbers && p.eoiNumbers.length)
                };
            });
    }
    get hasDoneRows() {
        return this.doneRows.length > 0;
    }
    get doneTotalFormatted() {
        const total = this.lines.reduce((sum, l) => {
            const p = this.paid[l.lineKey];
            return sum + (p && p.amount != null ? Number(p.amount) : 0);
        }, 0);
        return this.fmt(total);
    }

    fmt(amount) {
        try {
            return new Intl.NumberFormat('en-AE').format(amount || 0);
        } catch (e) {
            return String(amount || 0);
        }
    }

    shortRef(reference) {
        const r = reference || '';
        return r.length > 12 ? `${r.slice(0, 7)}…${r.slice(-3)}` : r;
    }

    // ---------- payPending auto-confirm (no Check-status click needed) ----------

    /** The waiting screen re-checks the payment every 5s without raising the
     *  blocking loader; the moment Checkout reports captured it advances through
     *  the normal confirm-and-finalize path. Bounded - the button stays as the
     *  manual backup and the poller/sweeper own the records regardless. */
    startPendingPoll() {
        if (this.pendingPollTimer || !this.paymentReference) {
            return;
        }
        this.pendingPollTicks = 0;
        this.pendingPollTimer = window.setInterval(() => {
            if (this.phase !== 'payPending' || this.isBusy) {
                this.stopPendingPoll();
                return;
            }
            this.pendingPollTicks += 1;
            confirmCardPayment({ reference: this.paymentReference })
                .then((res) => {
                    if (this.phase !== 'payPending') {
                        this.stopPendingPoll();
                        return;
                    }
                    if (res && (res.status === 'Captured' || res.finalized)) {
                        this.stopPendingPoll();
                        this.confirmAndFinalize(this.paymentReference);
                    } else if (res && res.status === 'Failed') {
                        this.stopPendingPoll();
                        this.handleFailedReturn('The payment was not completed and no amount was collected.');
                    } else if (this.pendingPollTicks >= 30) {
                        this.stopPendingPoll(); // ~2.5 min; manual button + sweeper take over
                    }
                })
                .catch(() => {
                    if (this.pendingPollTicks >= 30) {
                        this.stopPendingPoll();
                    }
                });
        }, 5000);
    }
    stopPendingPoll() {
        if (this.pendingPollTimer) {
            window.clearInterval(this.pendingPollTimer);
            this.pendingPollTimer = null;
        }
    }

    // ---------- EOI number polling (numbers appear seconds after each payment) ----------

    get paidLinesMissingNumbers() {
        return (this.lines || []).some((l) => {
            const p = this.paid[l.lineKey];
            return p && !(p.eoiNumbers && p.eoiNumbers.length);
        });
    }
    /* MEOI-SPIN. Blocks the page between capture and the number being issued - observed
       at roughly 50-65 seconds, because promotion runs asynchronously after commit.
       Deliberately gated on numbersPollExhausted as well: the poll gives up after ~88s,
       and when it does the customer must get their receipt rather than stare at a spinner
       that never stops. The per-line "EOI number to follow" text covers that case. */
    get showIssuingOverlay() {
        return (this.isDone || this.isThanks) && this.paidLinesMissingNumbers && !this.numbersPollExhausted;
    }
    get showBlockingLoader() {
        return this.isBusy || this.showIssuingOverlay;
    }
    get blockingLabel() {
        return this.isBusy ? this.busyLabel : 'Issuing your EOI number';
    }
    startNumbersPoll() {
        if (this.numbersPollTimer || !this.submittedId || !this.paidLinesMissingNumbers) {
            return;
        }
        this.numbersPollExhausted = false;
        this.numbersPollTicks = 0;
        this.numbersPollTimer = window.setInterval(() => {
            this.numbersPollTicks += 1;
            this.loadPaidMap()
                .then(() => {
                    if (!this.paidLinesMissingNumbers) {
                        this.stopNumbersPoll(false);
                    } else if (this.numbersPollTicks >= 22) {
                        this.stopNumbersPoll(true);
                    }
                })
                .catch(() => {
                    if (this.numbersPollTicks >= 22) {
                        this.stopNumbersPoll(true);
                    }
                });
        }, 4000);
    }
    stopNumbersPoll(exhausted) {
        if (this.numbersPollTimer) {
            window.clearInterval(this.numbersPollTimer);
            this.numbersPollTimer = null;
        }
        this.numbersPollExhausted = !!exhausted;
    }

    get stepEyebrow() {
        const steps = { signin: 1, otp: 1, identity: 2, typology: 3, review: 4 };
        const n = steps[this.phase];
        return n ? `${this.eyebrow} — Step ${n} of 4` : this.eyebrow;
    }
    get uaePassVerifiedLine() {
        return this.verified ? 'Verified with UAE PASS' : '';
    }
    /** First name for the greeting: UAE Pass profile or the submitted form. */
    get greetName() {
        const full = (this.verified && this.verified.fullNameEn) || '';
        const fromPass = full.trim().split(/\s+/)[0];
        return fromPass || (this.form && this.form.firstName) || '';
    }
    get welcomeHeading() {
        return this.greetName ? `Welcome back, ${this.greetName}` : 'Welcome back';
    }
    get doneThanks() {
        return this.greetName ? `Thank you, ${this.greetName}.` : 'Thank you.';
    }
    get failedSub() {
        const base = this.errorMessage || 'The payment was not completed and no amount was collected.';
        return `${base} You can try again whenever you\u2019re ready.`;
    }
    // ---------- step rail ----------
    get railIndex() {
        return { signin: 0, otp: 0, identity: 1, typology: 2, review: 3, payCard: 3 }[this.phase];
    }
    get railSteps() {
        const labels = RAIL_LABELS;
        const cur = this.railIndex;
        return labels.map((label, i) => ({
            label,
            num: i + 1,
            isDone: cur != null && i < cur,
            hasLine: i < labels.length - 1,
            cls: 'm-step'
                + (cur != null && i < cur ? ' is-done' : '')
                + (i === cur ? ' is-on' : '')
        }));
    }
    get stepMobBold() {
        const n = this.railIndex;
        return n != null ? `Step ${n + 1} of 4` : '';
    }
    get stepMobLabel() {
        const n = this.railIndex;
        return n != null ? RAIL_LABELS[n] : '';
    }
    // ---------- OTP channel hints (masked client-side, cosmetic only) ----------
    get otpEmailHint() {
        return this.maskEmail(this.form.email || this.form.registeredEmail || '')
            || (this.restoredHints && this.restoredHints.email) || '';
    }
    get otpMobileHint() {
        return this.maskMobile(this.form.mobile || this.form.registeredPhone || '')
            || (this.restoredHints && this.restoredHints.mobile) || '';
    }
    maskEmail(v) {
        const at = (v || '').indexOf('@');
        if (at < 1) {
            return '';
        }
        const local = v.slice(0, at);
        const tail = local.length > 2 ? local.slice(-1) : '';
        return `${local[0]}\u2022\u2022\u2022\u2022\u2022${tail}${v.slice(at)}`;
    }
    maskMobile(v) {
        const digits = (v || '').replace(/[^0-9+]/g, '');
        if (digits.length < 7) {
            return '';
        }
        return `${digits.slice(0, 4)} \u2022\u2022 \u2022\u2022\u2022 ${digits.slice(-4)}`;
    }
    get showChooser() {
        return this.phase === 'identity';
    }
    get showOtp() {
        return this.phase === 'otp';
    }
    get showWelcome() {
        return this.phase === 'welcome';
    }
    get showTypology() {
        return this.phase === 'typology';
    }
    get showReview() {
        return this.phase === 'review';
    }
    get isDone() {
        return this.phase === 'done';
    }
    get isThanks() {
        return this.phase === 'thanks';
    }
    get isPayPending() {
        return this.phase === 'payPending';
    }
    get isPayFailed() {
        return this.phase === 'payFailed';
    }
    get isClosed() {
        return this.phase === 'closed';
    }
    get indSelected() {
        return String(this.tab === TAB_IND);
    }
    get orgSelected() {
        return String(this.tab === TAB_ORG);
    }
    get indPaneClass() {
        return this.paneClass(TAB_IND);
    }
    get orgPaneClass() {
        return this.paneClass(TAB_ORG);
    }
    paneClass(t) {
        return this.tab === t ? 'pane' : 'pane is-hidden';
    }
    get indHidden() {
        return String(this.tab !== TAB_IND);
    }
    get orgHidden() {
        return String(this.tab !== TAB_ORG);
    }
    /* MEOI-CFG. Runtime switches, read from Apex on mount. (Restored 9 Sep: an identity
       rewrite replaced the getter block these lived in and took them with it.) */
    /* MEOI-CAPTCHA (11 Sep 2026). Google reCAPTCHA v3 runs inside the same-origin
       EOIRecaptchaFrame page (an iframe, like the card form) so the LWR page's CSP stays
       untouched; a token is requested right before the sign-in and payment-start calls and
       the server verifies it. Off by default (label EOI_Site_Recaptcha_Enabled). When the
       frame cannot answer - a content blocker, no network - the customer gets one clear line
       instead of a silent failure: the server refuses a missing token by design. Google's badge
       is shown in the frame (bottom-right, above the footer bar); the disclosure line under
       Send code stays as well. */
    get recaptchaEnabled() {
        return this.configLoaded && this.siteConfig.recaptchaEnabled === true;
    }
    get recaptchaFrameSrc() {
        // badge shown (MEOI-CAPTCHA follow-up, Mridul 11 Sep evening): the same visible
        // Google badge as on the landing site, bottom-right above the footer bar
        return recaptchaFramePath(basePath, true);
    }
    recaptchaToken(action) {
        if (!this.recaptchaEnabled) {
            return Promise.resolve(null);
        }
        const frame = this.template.querySelector('iframe.rc-frame');
        return requestRecaptchaToken(frame, action).catch(() => {
            const msg = 'The security check could not load. Please turn off content blockers for this page and try again.';
            const err = new Error(msg);
            err.body = { message: msg }; // messageOf() reads body.message
            throw err;
        });
    }

    loadSiteConfig() {
        getSiteConfig()
            .then((cfg) => {
                if (cfg) {
                    this.siteConfig = cfg;
                }
            })
            .catch(() => {
                // keep the shipped defaults; a config failure must not block registration
            })
            .finally(() => {
                this.configLoaded = true;
                this.restoreActivity();
                this.startActivityWatch();
            });
    }
    /* MEOI-CLOSED / MEOI-THANKS. Both default to false: an unreadable label must never
       close the site or strand the customer off the receipt. */
    get siteClosed() {
        return this.configLoaded && this.siteConfig.siteClosed === true;
    }
    get thankYouEnabled() {
        return this.siteConfig.thankYouEnabled === true;
    }
    /* MEOI-01. Anything other than true falls back to the manual form - the safe side. */
    get showUaePass() {
        // MEOI-UAELOCK (10 Sep, Mridul): UAE PASS is locked OUT in code for launch. The
        // EOI_Site_UAE_Pass_Enabled label alone can no longer show it - someone flipping the
        // label by mistake changes nothing. To bring UAE PASS back, set UAE_PASS_AVAILABLE to
        // true below AND set the label to true, then deploy and publish.
        return UAE_PASS_AVAILABLE && this.configLoaded && this.siteConfig.uaePassEnabled === true;
    }
    /* MEOI-12. 'Hosted' redirects out and back; anything else keeps the embedded iframe. */
    get isHostedPayment() {
        return this.siteConfig.paymentMode === 'Hosted';
    }
    get refundEnabled() {
        return this.siteConfig.refundEnabled === true;
    }
    get isResident() {
        return this.residency === RES_YES;
    }
    get residentSelected() {
        return String(this.isResident);
    }
    get nonResidentSelected() {
        return String(!this.isResident);
    }
    get residentClass() {
        return this.isResident ? 'm-seg__opt is-on' : 'm-seg__opt';
    }
    get nonResidentClass() {
        return this.isResident ? 'm-seg__opt' : 'm-seg__opt is-on';
    }
    /* UAE Pass only ever applied to residents; a non-resident has no UAE Pass identity. */
    get showUaePassForResident() {
        return this.showUaePass && this.isResident;
    }
}