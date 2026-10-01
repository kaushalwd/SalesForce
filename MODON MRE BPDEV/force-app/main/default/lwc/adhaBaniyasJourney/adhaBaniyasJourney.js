import { LightningElement, api, track } from 'lwc';
import startLogin from '@salesforce/apex/ADHA_JourneyController.startLogin';
import resendCode from '@salesforce/apex/ADHA_JourneyController.resendCode';
import verifyCode from '@salesforce/apex/ADHA_JourneyController.verifyCode';
import getDeclaration from '@salesforce/apex/ADHA_JourneyController.getDeclaration';
import getUndertaking from '@salesforce/apex/ADHA_JourneyController.getUndertaking';
import acceptDeclaration from '@salesforce/apex/ADHA_JourneyController.acceptDeclaration';
import resumeSession from '@salesforce/apex/ADHA_JourneyController.resumeSession';
import sessionStatus from '@salesforce/apex/ADHA_JourneyController.sessionStatus';
import explorationMode from '@salesforce/apex/ADHA_JourneyController.explorationMode';
// The same render resources the map's explore view uses (see masterplanUnitSelector.js), so
// there is one copy of each render in the org.
import VILLA_A from '@salesforce/resourceUrl/WestBaniyasVillaA';
import VILLA_B from '@salesforce/resourceUrl/WestBaniyasVillaB';
import VILLA_C from '@salesforce/resourceUrl/WestBaniyasVillaC';
// ADHA's logo, artwork untouched: the brand book forbids recolouring, so the white plate in
// .adha-logo is what makes it read on this ground.
import ADHA_LOGO from '@salesforce/resourceUrl/ADHABaniyasLogo';
import { t, dirOf, toLatinDigits, num, DEFAULT_LANG , allLabels } from 'c/adhaLabels';
import reserveCurrent from '@salesforce/apex/ADHA_ReservationController.currentReservation';
import confirmReservation from '@salesforce/apex/ADHA_ReservationController.confirm';
import releaseCurrent from '@salesforce/apex/ADHA_ReservationController.releaseCurrent';
import endSession from '@salesforce/apex/ADHA_JourneyController.endSession';
import beginSigning from '@salesforce/apex/ADHA_ReservationController.beginSigning';
import signingOutcome from '@salesforce/apex/ADHA_ReservationController.signingOutcome';
import undertakingCopies from '@salesforce/apex/ADHA_ReservationController.undertakingCopies';
import downloadCopy from '@salesforce/apex/ADHA_ReservationController.downloadCopy';

// Journey stages 2-4. Stage 1 is the invitation SMS, which happens outside the browser.
const STAGE_WELCOME = 'welcome';
const STAGE_LOGIN = 'login';
const STAGE_OTP = 'otp';
const STAGE_DECLARATION = 'declaration';
const STAGE_MAP = 'map';
const STAGE_LOCKED = 'locked';
// Step 4 is three screens: the money, the undertaking, the reference. Funding a six-figure
// shortfall is its own decision and keeps its own screen.
const STAGE_FINANCE = 'finance';
const STAGE_UNDERTAKING = 'undertaking';
const STAGE_DONE = 'done';

/* ---------- the arrival plane: six renders beside the form before the map, ordered as a
   walk through exteriors and interiors of both styles ---------- */
const VILLA_BASE = { A: VILLA_A, B: VILLA_B, C: VILLA_C };

/* title is the only label left. The visible caption came out on 22 Aug, but the dots still name
   the room they jump to, so these keys are load-bearing for screen readers, not decoration. */
const SLIDES = [
    { villa: 'C', path: 'exterior/heritage-a.webp', title: 'slideHeritage' },
    { villa: 'C', path: 'interior/05.webp', title: 'slideLiving' },
    { villa: 'A', path: 'exterior/modern-a.webp', title: 'slideModern' },
    { villa: 'A', path: 'interior/04.webp', title: 'slideDining' },
    { villa: 'C', path: 'interior/11.webp', title: 'slideBedroom' },
    { villa: 'B', path: 'exterior/heritage-a.webp', title: 'slideStreet' }
];

// Long enough to look at a house, short enough that the loop is not a slideshow you wait out.
const SLIDE_MS = 6500;

/* Fraction of a phone's height the renders take per stage: the landing render is the point,
   and by the declaration the band is down to a ribbon. */
const BANDS = {
    [STAGE_WELCOME]: 0.43,
    [STAGE_LOGIN]: 0.24,
    [STAGE_OTP]: 0.24,
    [STAGE_DECLARATION]: 0.14,
    [STAGE_LOCKED]: 0.24
};

/* Read per call rather than cached: a customer can turn Reduce Motion on mid-journey, and on
   iOS that takes effect without a reload. */
function prefersReducedMotion() {
    return typeof window !== 'undefined' &&
        typeof window.matchMedia === 'function' &&
        window.matchMedia('(prefers-reduced-motion: reduce)').matches;
}

// The five FAB NHL collection scenarios; the notes are the only place the customer is told
// what happens after the choice.
const PAYMENT_SCENARIOS = [
    { key: 'Full Upfront Payment', labelKey: 'pmUpfront', notes: ['noteRefund', 'noteCapped'] },
    { key: 'Payment Plan', labelKey: 'pmPlan', notes: ['noteRefund', 'noteCapped'] },
    { key: 'Partial Payment with Plan', labelKey: 'pmPartialPlan', notes: ['noteRefund', 'noteCapped'] },
    {
        key: 'Partial Payment with Plan and Bank Top Up',
        labelKey: 'pmPartialPlanTopUp',
        notes: ['noteRefund', 'noteCapped', 'noteTopUpDeclined']
    },
    { key: 'Bank Top Up Finance', labelKey: 'pmTopUp', notes: ['noteTopUpDeclined'] }
];

// sessionStorage, not localStorage: the session dies with the tab, which is the right lifetime
// for a shared or public device.
const TOKEN_KEY = 'adha_baniyas_token';

// localStorage, unlike the token above: the language must survive a sign-out and a new sign-in.
const LANG_KEY = 'adha_baniyas_lang';

// The villa being walked through, before it is committed. sessionStorage like the token: an
// uncommitted intent should not outlive the tab.
const QUOTE_KEY = 'adha_baniyas_quote';

// Matches ADHA_Setting__mdt.SLA_Days, which the server already applies; this copy only scales
// the bar. If the two ever diverge the label stays correct and only the bar is wrong.
const SLA_DAYS = 7;

// The server owns the real idle window. Must match IDLE_MINUTES in ADHA_JourneyController,
// or client and server disagree about when a session ended.
const IDLE_MS = 5 * 60 * 1000;
const WARN_MS = 60 * 1000;
const HEARTBEAT_MS = 60 * 1000;
// Tabs in the same browser tell each other about a new login instantly, rather than waiting
// up to a heartbeat. Cross-browser and cross-device still rely on the heartbeat.
const CHANNEL = 'adha_baniyas_session';

/* lockedReason is the client's word for it; these are the picklist values the record carries.
   Superseded deliberately does not clear anything server side - see endSession. */
const END_REASON = {
    signedout: 'Signed out',
    idle: 'Idle timeout',
    superseded: 'Superseded'
};

// An Emirates ID is 15 digits however it is typed - spaced, hyphenated, or in Arabic-Indic digits.
function digitsOf(value) {
    return toLatinDigits(String(value || '')).replace(/\D/g, '');
}

// 784-1990-3456789-3: groups of 3, 4, 7 and 1. Never a trailing separator - one that reappears the
// instant it is deleted leaves the caret stuck and backspace looking broken.
function formatEmiratesId(digits) {
    let out = '';
    for (let i = 0; i < digits.length; i++) {
        if (i === 3 || i === 7 || i === 14) {
            out += '-';
        }
        out += digits[i];
    }
    return out;
}

// Where the caret belongs after reformatting, counted in digits rather than characters so an
// inserted separator does not drag it out of position.
function caretAfterDigit(formatted, digitCount) {
    if (digitCount <= 0) {
        return 0;
    }
    let seen = 0;
    for (let i = 0; i < formatted.length; i++) {
        if (formatted[i] !== '-') {
            seen++;
            if (seen === digitCount) {
                return i + 1;
            }
        }
    }
    return formatted.length;
}

export default class AdhaBaniyasJourney extends LightningElement {
    @api masterplanUrl;
    @api mappingUrl;
    /* Set in Experience Builder; blank leaves the renders rotating. The host must be a CSP
       Trusted Site with mediaSrc - imgSrc alone does not cover it - and must move off UAT at go-live. */
    @api heroVideoUrl;
    /* Walkthrough film folder, passed through to the map. A setting like heroVideoUrl; blank
       leaves the walkthrough tab off. */
    @api walkthroughBaseUrl;

    stage = STAGE_WELCOME;
    /** Holds the first paint back while a stored session is resolved, so a returning customer
     *  never watches the landing screen before jumping to where they were. */
    resuming = false;
    // Signing. signBusy covers both legs, because the customer must not be able to press the
    // button again while we are already preparing a document or checking an outcome.
    signBusy = false;
    signNotice = '';
    checkingSignature = false;
    downloadBusy = false;
    downloadNotice = '';
    copies = [];
    /* The executed copy is handed over once per envelope. Reset in startSigning, not on download:
       an amend-after-signing raises a second envelope without leaving this component instance. */
    signedAutoDownloaded = false;
    // Switching is component-owned, never a platform language change: a reload would reset the
    // map camera, re-pay the SVG rebuild and double-count the "Exploring units" metric.
    lang = DEFAULT_LANG;
    /* From the server, not the session - it must stand before a session exists. False until
       the call answers, so an open site never flashes the banner. */
    exploring = false;
    /** Measured height of the notice, published through arrivalStyle. Zero, not -1: the first
     *  render has to publish a real 0px rather than a value nothing can use. */
    noticeHeight = 0;
    /* Open on a wide screen, closed on a phone. The map has room for two lines on a desktop and
       none to spare at 390px, where the full text runs to about 107px of an 800px viewport. */
    noticeOpen = typeof window !== 'undefined' && window.innerWidth > 820;
    @track session;
    declaration;
    // The stage 4b deed. Separate from `declaration` above: that is the General Declaration
    // everyone accepts at stage 3, this is the Grant or Loan text this customer signs.
    undertaking;
    emiratesId = '';
    otp = '';
    maskedTarget = '';
    verificationRequestId;
    errorMessage = '';
    infoMessage = '';
    busy = false;
    resendSeconds = 0;
    declarationRead = false;
    // Distinguishes "still loading" from "the fetch failed", so neither screen can claim to be
    // loading forever.
    declarationFailed = false;
    confirmingSignOut = false;
    // The plot a committed customer has asked to swap to, while the dialog is up; empty means
    // no question is being asked. The map keeps the unit itself.
    pendingSwapPlot = '';
    // Full card on every arrival, collapsing to the map's bar only on back - the reverse put a
    // Details press in front of the reservation they signed in to see.
    doneExpanded = false;
    // How far through the legal text they have scrolled, 0-100. One field, because only one
    // scroll-gated box is ever on screen.
    readProgress = 0;
    // Seconds left on the villa hold. Ticked only while a hold screen is showing.
    holdSeconds = 0;
    holdTimer;
    // Announced once at two minutes and once at zero. Never per second: aria-live on a ticking
    // counter reads the whole thing out sixty times.
    holdAnnouncement = '';
    holdWarned = false;
    focusedStage = '';
    warnedFocused = false;
    @track reservation;
    // The villa the customer is walking through, before anything is written. Distinct from
    // `reservation`, which only exists once they have accepted the undertaking.
    @track quote;
    // Deliberately unset. Pre-selecting one let a customer commit to how they would fund a
    // six-figure shortfall without ever making the choice.
    paymentMethod = '';
    undertakingRead = false;
    resendTimer;
    lockedReason = '';
    warnSeconds = 0;
    lastActivity = Date.now();
    activitySincePing = false;
    idleTimer;
    heartbeatTimer;
    channel;
    activityHandler;

    connectedCallback() {
        this.lockPageScroll();
        // Language before anything else, so the welcome screen never paints in Arabic for one
        // frame and then flips.
        const savedLang = this.storedLang();
        if (savedLang) {
            this.lang = savedLang;
        }

        // Ahead of the session branch below, which returns early on the welcome screen - the
        // banner is needed there most of all. Cacheable, so a resume does not pay for it twice.
        explorationMode()
            .then((on) => {
                this.exploring = on === true;
            })
            .catch(() => {
                // The site is open unless told otherwise. A failed call must not put a banner on a
                // live site claiming reservations have not started.
                this.exploring = false;
            });

        // A refresh mid-journey should land where the customer left off, not at the welcome screen.
        const stored = sessionStorage.getItem(TOKEN_KEY);
        if (!stored) {
            // No session to restore, so the welcome screen is the right answer straight away.
            return;
        }
        // Before the call, not in its callback. By the time a .then runs, the frame has painted.
        this.resuming = true;
        // DocuSign appends event= when it sends the signer back here. It is a hint that something
        // finished, never evidence of what, so the outcome is read from the envelope server side.
        const returnedFromSigning = this.signingEventFromUrl();
        this.busy = true;
        resumeSession({ token: stored })
            .then((session) => {
                this.resumeInto(session);
                this.startSessionWatch();
                if (returnedFromSigning) {
                    this.checkSigningOutcome();
                }
            })
            .catch(() => {
                // Expired or tampered with. Silently start again rather than showing an error the
                // customer cannot act on.
                sessionStorage.removeItem(TOKEN_KEY);
            })
            .finally(() => {
                this.busy = false;
            });
    }

    /** Puts a customer back where they were, from a validated session. One implementation for
     *  both refresh and re-login, so the two routes cannot disagree. */
    resumeInto(session) {
        this.session = session;
        this.adoptSessionLanguage(session);
        // Ops goes straight to the map in pin mode. No declaration, no journey.
        if (session.isOps) {
            this.stage = STAGE_MAP;
            this.resuming = false;
            return;
        }
        // reserveRefused, not reserveRefusal: this skip covers a lapsed window or spent
        // attempts, where accepting would record a legal artefact the customer cannot act on.
        this.stage = session.declarationAccepted || this.reserveRefused ? STAGE_MAP : STAGE_DECLARATION;

        if (this.stage === STAGE_DECLARATION) {
            this.loadDeclaration();
            // The declaration card shows its own loading state, so there is nothing left to wait for.
            this.resuming = false;
            return;
        }
        // Already past the declaration, so there may be a villa held. Landing on the map would
        // invite them to pick again - and picking again is what destroys the hold.
        const generation = this.sessionGeneration;
        reserveCurrent({ token: session.token })
            .then((reservation) => {
                if (!this.isCurrent(generation)) {
                    return;
                }
                if (reservation) {
                    this.reservation = reservation;
                    this.paymentMethod = reservation.paymentMethod || this.paymentMethod;
                    this.routeReservation();
                    // Never trust the event marker alone - a redirect can eat ?event=. If the
                    // envelope still looks open, ask DocuSign rather than wait to be told.
                    if (this.awaitingSignature) {
                        this.checkSigningOutcome();
                    }
                } else if (this.restoreQuote()) {
                    // Nothing committed yet, but this tab was part-way through choosing.
                    this.routeQuote();
                }
            })
            .catch(() => {
                // errorMessage cannot render on the map (showCard is false), so the message goes
                // to the map's own status line instead of nowhere.
                this.showMapNotice(t(this.lang, 'MSG_GENERIC'));
            })
            .finally(() => {
                // Held until the reservation has had its say, or the map would flash before the
                // confirmation card.
                this.resuming = false;
            });
    }

    /** Everything a new session needs however it was obtained: token, idle watch, cross-tab
     *  notice, then the same routing a refresh uses. */
    completeLogin(session, generation) {
        if (!this.isCurrent(generation)) {
            return;
        }
        sessionStorage.setItem(TOKEN_KEY, session.token);
        // Same resume path as a refresh: re-asking for the declaration would re-stamp
        // Declaration_Accepted_On__c and destroy the original consent record.
        this.resumeInto(session);
        this.startSessionWatch();
        if (this.channel) {
            this.channel.postMessage({ type: 'login', token: session.token });
        }
    }

    disconnectedCallback() {
        clearInterval(this.resendTimer);
        this.stopSlideshow();
        this.stopHoldCountdown();
        this.stopSessionWatch();
        this.unlockPageScroll();
        if (this.noticeObserver) {
            this.noticeObserver.disconnect();
            this.observedNotice = undefined;
        }
    }

    /** LWR's router appends a 1px span below our component that makes the page scroll ~24px;
     *  it is outside our shadow root, so scrolling is stopped here and restored on disconnect. */
    lockPageScroll() {
        const root = document.documentElement;
        if (!root) {
            return;
        }
        this.priorOverflow = root.style.overflow;
        this.priorTouchAction = root.style.touchAction;
        root.style.overflow = 'hidden';
        // The page margin outside our component is not a descendant of .journey, so the stylesheet
        // rule there cannot reach it and a double-tap on it would still scale the page.
        root.style.touchAction = 'manipulation';
    }

    unlockPageScroll() {
        const root = document.documentElement;
        if (root) {
            root.style.overflow = this.priorOverflow || '';
            root.style.touchAction = this.priorTouchAction || '';
        }
    }

    /* ---------- session watch: idle timeout + supersede lockdown ---------- */

    startSessionWatch() {
        if (this.idleTimer) {
            return;
        }
        this.lastActivity = Date.now();
        this.activitySincePing = true;

        // Pointer and key events cover the map too: panning and zooming are real interaction
        // that produces no server call, and would otherwise look like idleness.
        this.activityHandler = () => {
            this.lastActivity = Date.now();
            this.activitySincePing = true;
            if (this.warnSeconds > 0) {
                this.warnSeconds = 0;
            }
        };
        ['pointerdown', 'pointermove', 'keydown', 'wheel', 'touchstart'].forEach((e) =>
            window.addEventListener(e, this.activityHandler, { passive: true })
        );

        this.idleTimer = setInterval(() => this.checkIdle(), 1000);
        this.heartbeatTimer = setInterval(() => this.heartbeat(), HEARTBEAT_MS);

        if (typeof BroadcastChannel !== 'undefined') {
            this.channel = new BroadcastChannel(CHANNEL);
            this.channel.onmessage = (event) => {
                // Another tab in this browser just signed in as someone, so this one is stale.
                if (event.data && event.data.type === 'login' && event.data.token !== this.sessionToken) {
                    // The tab that signed in has not reported anything, so this one does.
                    this.lock('superseded');
                }
                // Or signed out - without this the sibling reads the dead token as an idle
                // timeout instead of the sign-out it was.
                if (event.data && event.data.type === 'logout') {
                    // The tab that pressed it has already told the server.
                    this.lock('signedout', false);
                }
            };
        }
    }

    stopSessionWatch() {
        clearInterval(this.idleTimer);
        clearInterval(this.heartbeatTimer);
        this.idleTimer = null;
        this.heartbeatTimer = null;
        if (this.activityHandler) {
            ['pointerdown', 'pointermove', 'keydown', 'wheel', 'touchstart'].forEach((e) =>
                window.removeEventListener(e, this.activityHandler)
            );
            this.activityHandler = null;
        }
        if (this.channel) {
            this.channel.close();
            this.channel = null;
        }
    }

    checkIdle() {
        const idle = Date.now() - this.lastActivity;
        if (idle >= IDLE_MS) {
            this.lock('idle');
        } else if (idle >= IDLE_MS - WARN_MS) {
            this.warnSeconds = Math.ceil((IDLE_MS - idle) / 1000);
        } else if (this.warnSeconds > 0) {
            this.warnSeconds = 0;
        }
    }

    heartbeat() {
        if (!this.sessionToken) {
            return;
        }
        // touch only when the customer has actually done something. A heartbeat that refreshed
        // the session would keep an abandoned tab alive forever.
        const touch = this.activitySincePing;
        this.activitySincePing = false;
        sessionStatus({ token: this.sessionToken, touch })
            .then((status) => {
                if (status === 'superseded') {
                    this.lock('superseded');
                } else if (status === 'expired') {
                    this.lock('idle');
                }
            })
            .catch(() => {
                // A transient failure must not sign anyone out; the next beat will settle it.
            });
    }

    /** @param report false when the lock came from another tab's broadcast - that tab already
     *      told the server, and a second call would duplicate the trail line. */
    lock(reason, report = true) {
        if (this.lockedReason) {
            return;
        }
        // Before the teardown drops it. Reported after, so a slow callout cannot delay the lock.
        const token = this.sessionToken;
        this.lockedReason = reason;
        this.warnSeconds = 0;
        this.stopSessionWatch();
        sessionStorage.removeItem(TOKEN_KEY);
        this.session = undefined;
        this.clearCustomerState();
        this.stage = STAGE_LOCKED;

        // Fire and forget, after the local teardown: the browser must end up signed out
        // whatever the network does. The server still expires sessions on its own.
        if (report && token) {
            endSession({ token, reason: END_REASON[reason] || END_REASON.signedout }).catch(() => {
                /* nothing useful left to do here */
            });
        }
    }

    /** Bumped whenever the person behind the session changes; every server call captures it at
     *  dispatch and discards its result if it no longer matches. */
    sessionGeneration = 0;

    /** True if the session this call belongs to is still the current one. */
    isCurrent(generation) {
        return generation === this.sessionGeneration;
    }

    clearCustomerState() {
        this.sessionGeneration += 1;
        this.declarationFailed = false;
        this.reservation = undefined;
        this.quote = undefined;
        this.persistQuote();
        this.declaration = undefined;
        this.undertaking = undefined;
        this.declarationRead = false;
        this.undertakingRead = false;
        this.readProgress = 0;
        this.doneExpanded = false;
        this.confirmingSignOut = false;
        this.pendingSwapPlot = '';
        this.stopHoldCountdown();
        this.holdSeconds = 0;
        this.holdAnnouncement = '';
        this.paymentMethod = '';
        this.maskedTarget = '';
        this.infoMessage = '';
    }

    handleStaySignedIn() {
        this.lastActivity = Date.now();
        this.activitySincePing = true;
        this.warnSeconds = 0;
        this.heartbeat();
    }

    handleSignInAgain() {
        this.lockedReason = '';
        this.stage = STAGE_WELCOME;
        this.emiratesId = '';
        this.otp = '';
        this.verificationRequestId = undefined;
        this.errorMessage = '';
        // Belt and braces: lock() already cleared this, but this handler is also the entry point
        // a customer reaches after a supersede they did not cause.
        this.clearCustomerState();
    }

    /* ---------- the arrival plane ---------- */

    /* Two planes before the map: renders and form. From the map onward the plan is the
       backdrop (see paneClass) and none of this applies. */

    slideIndex = 0;
    /* How far the rotation has actually got. Slides beyond this plus one carry no src, so six
       renders - about 1.2 MB - do not all land on first paint on a phone. */
    slideReached = 0;
    @track slideFailed = [];
    slideTimer = null;
    /* MODON's hero film sits in front of the rotation. Set when it will not play, which drops us
       back to the six renders rather than leaving a black plane beside the form. */
    heroVideoFailed = false;

    get slideCount() {
        return SLIDES.length;
    }

    get liveSlides() {
        return SLIDES.map((_, i) => i).filter((i) => this.slideFailed.indexOf(i) < 0);
    }

    /* A render that 404s is skipped; the plane only comes out when every one has failed. */
    get showMediaPlane() {
        return !this.resuming && this.showArrival && this.liveSlides.length > 0;
    }

    /* The film's host must be a CSP Trusted Site with mediaSrc or LWR blocks it, and it is UAT
       today - it must move before go-live. Suppressed under reduced motion. */
    get showHeroVideo() {
        return this.showMediaPlane
            && !!this.heroVideoUrl
            && !this.heroVideoFailed
            && !prefersReducedMotion();
    }

    /* Only where the dots steer something: over the renders, not over the film. Under reduced
       motion they are the only way past the first render. */
    get showSlideDots() {
        return this.showMediaPlane && !this.showHeroVideo && this.liveSlides.length > 1;
    }

    /* The first render doubles as the poster, so the plane is never empty while the film loads and
       nothing new has to be cut for it. */
    get heroPoster() {
        const first = SLIDES[0];
        return `${VILLA_BASE[first.villa]}/${first.path}`;
    }

    get showArrival() {
        return !this.showMap;
    }

    get logoSrc() {
        return ADHA_LOGO;
    }

    /* `at-<stage>` lets the plane respond to where the customer is without any rule having to
       infer it from a selector, and without a second source of truth for the stage. */
    get journeyClass() {
        // Not 'arrival' while holding: that layout sets the --band height for the media plane, and
        // keeping it would hold an empty band open behind the cover.
        if (this.resuming) {
            return 'journey booting';
        }
        // exploring carries the banner height down as a custom property, which crosses the
        // shadow boundary for the map's chrome to read.
        const banner = this.showShortNotice ? ' exploring' : '';
        return (this.showArrival ? `journey arrival at-${this.stage}` : 'journey') + banner;
    }

    /* Both custom properties in one bound string: an imperative setProperty write here was
       wiped by every re-render that changed --band. */
    get arrivalStyle() {
        return `--band: ${BANDS[this.stage] || 0.24}; --exploration-banner-h: ${this.noticeHeight}px;`;
    }

    /* On the plane in the arrival layout, inside the card over the map - never both. The card
       is transparent on the plane, so a rail on it would land beside the text. */
    get railInPlane() {
        return this.showRail && this.showArrival;
    }

    get railInCard() {
        return this.showRail && !this.showArrival;
    }

    get slides() {
        return SLIDES.map((slide, i) => ({
            key: i,
            index: String(i),
            // Undefined leaves the attribute off entirely, which is what keeps it unfetched.
            src: i <= this.slideReached + 1 && this.slideFailed.indexOf(i) < 0
                ? `${VILLA_BASE[slide.villa]}/${slide.path}`
                : undefined,
            cls: i === this.slideIndex ? 'shot on' : 'shot'
        }));
    }

    get slideDots() {
        return SLIDES.map((slide, i) => ({
            key: i,
            index: String(i),
            current: i === this.slideIndex ? 'true' : 'false',
            cls: i < this.slideIndex ? 'dot seen' : 'dot',
            // The room, not "slide 3 of 6" - a position in a carousel is not what somebody
            // choosing a house wants read out to them.
            label: this.labels[slide.title]
        }));
    }


    handleSlideDot = (event) => {
        const i = Number(event.currentTarget.dataset.index);
        if (Number.isNaN(i)) {
            return;
        }
        this.showSlide(i);
        // Restart the clock, so a slide chosen by hand gets its full turn rather than the
        // remainder of the one it interrupted.
        if (this.slideTimer) {
            this.startSlideshow();
        }
    };

    /* Anything from a missing resource to a codec the browser will not take. Either way the
       rotation takes over, and syncSlideshow starts it because showHeroVideo has gone false. */
    handleHeroVideoError = () => {
        if (this.heroVideoFailed) {
            return;
        }
        this.heroVideoFailed = true;
        this.syncSlideshow();
    };

    handleSlideError = (event) => {
        const i = Number(event.currentTarget.dataset.index);
        if (Number.isNaN(i) || this.slideFailed.indexOf(i) >= 0) {
            return;
        }
        this.slideFailed = [...this.slideFailed, i];
        if (i === this.slideIndex) {
            this.advanceSlide();
        }
    };

    showSlide(i) {
        this.slideIndex = i;
        this.slideReached = Math.max(this.slideReached, i);
    }

    advanceSlide() {
        const live = this.liveSlides;
        if (!live.length) {
            this.stopSlideshow();
            return;
        }
        const after = live.filter((i) => i > this.slideIndex);
        this.showSlide(after.length ? after[0] : live[0]);
    }

    startSlideshow() {
        this.stopSlideshow();
        this.slideTimer = setInterval(() => this.advanceSlide(), SLIDE_MS);
    }

    stopSlideshow() {
        if (this.slideTimer) {
            clearInterval(this.slideTimer);
            this.slideTimer = null;
        }
    }

    /* Rotating only while the arrival plane is on screen. Over the map the plane is not rendered
       at all, so a timer still running there would repaint nothing and hold a reference. */
    syncSlideshow() {
        // Not while the film is up: the renders are underneath it, so rotating them would burn a
        // timer and fetch images nobody can see.
        const wanted = this.showMediaPlane && !this.showHeroVideo
            && this.liveSlides.length > 1 && !prefersReducedMotion();
        if (wanted && !this.slideTimer) {
            this.startSlideshow();
        } else if (!wanted && this.slideTimer) {
            this.stopSlideshow();
        }
    }

    /* ---------- stage flags for the template ---------- */

    get isWelcome() {
        return this.stage === STAGE_WELCOME;
    }
    get isLogin() {
        return this.stage === STAGE_LOGIN;
    }
    /* Marks the Emirates ID input itself, so the field and its message fail together rather than
       the message being the only sign. */
    get emiratesIdFieldClass() {
        return this.errorMessage ? 'field has-error' : 'field';
    }

    /** 15 digits exactly, counted in digits because the field carries separators.
     *  handleSendCode keeps its own check: Enter bypasses the button. */
    get sendCodeDisabled() {
        return this.busy || digitsOf(this.emiratesId).length !== 15;
    }
    /* The identify stage renders the error against the Emirates ID field, so the card-level block
       must stand down there or the same sentence appears twice on one screen. */
    get showCardError() {
        return Boolean(this.errorMessage) && this.stage !== STAGE_LOGIN;
    }
    get isOtp() {
        return this.stage === STAGE_OTP;
    }
    get isDeclaration() {
        return this.stage === STAGE_DECLARATION;
    }
    get isMap() {
        // Never mount the map without a token: rendering it only to error is worse than
        // staying on the declaration stage.
        return this.stage === STAGE_MAP && !!this.sessionToken;
    }
    get isLocked() {
        return this.stage === STAGE_LOCKED;
    }

    get isFinance() {
        return this.stage === STAGE_FINANCE;
    }

    get isUndertaking() {
        return this.stage === STAGE_UNDERTAKING;
    }

    get isDone() {
        return this.stage === STAGE_DONE;
    }

    /* ---------- signing ---------- */

    /** Off unless the server says the step exists, so nothing here can appear by accident. */
    get signingEnabled() {
        return !!(this.session && this.session.signingEnabled);
    }

    get docuSignStatus() {
        return this.reservation ? this.reservation.docuSignStatus : null;
    }

    get isSigned() {
        return this.docuSignStatus === 'Signed';
    }

    /** An envelope we believe is still out. Anything else is either done or was never raised. */
    get awaitingSignature() {
        const status = this.reservation && this.reservation.docuSignStatus;
        return this.signingEnabled && (status === 'Sent' || status === 'Delivered');
    }

    get showSigned() {
        return this.isDone && this.signingEnabled && this.isSigned;
    }

    /** Deliberately not gated on the window: gating would leave an expired customer holding a
     *  reservation that can never complete. assertSignable agrees - Submitted is enough. */
    get showSignPrompt() {
        return (
            this.isDone &&
            this.signingEnabled &&
            !this.isSigned &&
            this.reservation &&
            this.reservation.status === 'Submitted'
        );
    }

    /** The outbound wait, distinct from checkingSignature (the return trip): collapsing the
     *  two would show "preparing" to a customer coming back from DocuSign. */
    get showSigningWait() {
        // Not when the prompt is up: that button carries its own ring, and both at once would
        // report one wait twice.
        return this.signBusy && !this.checkingSignature && !this.showSignPrompt;
    }

    get signCtaLabel() {
        if (!this.signBusy) {
            return t(this.lang, 'signCta');
        }
        return t(this.lang, this.checkingSignature ? 'signChecking' : 'signOpening');
    }

    /** Leaves for DocuSign in this tab, not an iframe: accounts can refuse framing, and
     *  sessionStorage survives the round trip in the same tab. */
    handleSign() {
        this.startSigning();
    }

    /** Raises the envelope and leaves; shared by the confirmation button and the accept-and-sign
     *  press. Resolves false if the hand off did not happen. */
    startSigning(silent) {
        if (this.signBusy) {
            return Promise.resolve(false);
        }
        this.signBusy = true;
        this.checkingSignature = false;
        this.signNotice = '';
        // A new envelope means a new executed copy: reset here, or an amend-after-signing
        // customer would be given the first deed and never the second.
        this.signedAutoDownloaded = false;
        return beginSigning({ token: this.sessionToken })
            .then((view) => {
                if (view && view.signingUrl) {
                    window.location.assign(view.signingUrl);
                    return true;
                }
                this.signBusy = false;
                this.signNotice = silent ? '' : t(this.lang, 'MSG_GENERIC');
                return false;
            })
            .catch((error) => {
                this.signBusy = false;
                // Silent on the merged path: an error banner under "your villa is reserved"
                // reads as though it had not. The sign button still shows the real reason.
                this.signNotice = silent ? '' : this.messageOf(error);
                return false;
            });
    }

    /** Reads event= off the URL and clears it, so a refresh does not re-run the check. */
    signingEventFromUrl() {
        try {
            const params = new URLSearchParams(window.location.search);
            const event = params.get('event');
            if (!event) {
                return null;
            }
            params.delete('event');
            const query = params.toString();
            window.history.replaceState(
                {},
                '',
                window.location.pathname + (query ? '?' + query : '')
            );
            return event;
        } catch (e) {
            return null;
        }
    }

    checkSigningOutcome() {
        // The marker path and the resume backstop both fire on a return; the server holds the
        // real guard, this just saves the duplicate callout.
        if (this.checkingSignature) {
            return;
        }
        this.signBusy = true;
        this.checkingSignature = true;
        signingOutcome({ token: this.sessionToken })
            .then((view) => {
                if (view && view.completed) {
                    this.signNotice = '';
                    // refreshReservation resolves only after loadCopies, so the signed copy is
                    // known to be listed by the time the download is asked for.
                    return this.refreshReservation().then(() => this.autoDownloadSigned());
                }
                this.signNotice = t(
                    this.lang,
                    view && view.status === 'Declined' ? 'signDeclined' : 'signNotFinished'
                );
                return this.refreshReservation();
            })
            .catch((error) => {
                this.signNotice = this.messageOf(error);
            })
            .finally(() => {
                this.signBusy = false;
                this.checkingSignature = false;
            });
    }

    /* ---------- downloading the copies ---------- */

    /** Only while there is still something to sign. Stale both after signing and with signing off. */
    get showSignNote() {
        return this.isDone && this.signingEnabled && !this.isSigned;
    }

    get showDownloads() {
        return this.isDone && this.signingEnabled && this.downloadOptions.length > 0;
    }

    /** Once signed, only the executed copy is offered - it supersedes the unsigned one. Both
     *  stay on the reservation for ADHA either way. */
    get downloadOptions() {
        const signed = this.isSigned;
        return (this.copies || [])
            .filter((copy) => copy.available)
            .filter((copy) => (signed ? copy.kind === 'signed' : copy.kind !== 'signed'))
            .map((copy) => ({
                kind: copy.kind,
                label: t(this.lang, copy.kind === 'signed' ? 'downloadSigned' : 'downloadUndertaking')
            }));
    }

    loadCopies() {
        if (!this.sessionToken) {
            return Promise.resolve();
        }
        return undertakingCopies({ token: this.sessionToken })
            .then((copies) => {
                this.copies = copies || [];
            })
            .catch(() => {
                // A missing list is not worth an error: the documents are still on the record.
                this.copies = [];
            });
    }

    /** The button sends a kind, never a record id; the server picks the file from this
     *  applicant's own reservation. */
    handleDownload(event) {
        this.downloadKind(event.currentTarget.dataset.kind);
    }

    /** Shared by the button and the automatic fetch. silent suppresses the failure notice - a
     *  customer who never asked must not see a download error on the completion screen. */
    downloadKind(kind, silent) {
        if (this.downloadBusy || !kind) {
            return Promise.resolve();
        }
        this.downloadBusy = true;
        this.downloadNotice = '';
        return downloadCopy({ token: this.sessionToken, kind })
            .then((copy) => this.saveFile(copy, silent))
            .catch(() => {
                if (!silent) {
                    this.downloadNotice = t(this.lang, 'downloadFailed');
                }
            })
            .finally(() => {
                this.downloadBusy = false;
            });
    }

    /** Hands over the executed copy on the return from DocuSign, silently: if the copy is not
     *  filed yet ADHA_SignedCopyBatch fetches it within ten minutes, and the button covers the gap. */
    autoDownloadSigned() {
        if (this.signedAutoDownloaded) {
            return Promise.resolve();
        }
        const ready = (this.copies || []).some(
            (copy) => copy.kind === 'signed' && copy.available
        );
        if (!ready) {
            return Promise.resolve();
        }
        this.signedAutoDownloaded = true;
        return this.downloadKind('signed', true).catch(() => undefined);
    }

    /** base64 to Blob to object URL. The revoke is DEFERRED: revoking right after click() can
     *  pull the blob before the browser takes it, which bites on the automatic download. */
    saveFile(copy, silent) {
        if (!copy || !copy.base64) {
            if (!silent) {
                this.downloadNotice = t(this.lang, 'downloadFailed');
            }
            return;
        }
        const binary = atob(copy.base64);
        const bytes = new Uint8Array(binary.length);
        for (let i = 0; i < binary.length; i++) {
            bytes[i] = binary.charCodeAt(i);
        }
        const url = URL.createObjectURL(new Blob([bytes], { type: 'application/pdf' }));
        const link = document.createElement('a');
        link.href = url;
        link.download = copy.fileName;
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
        setTimeout(() => URL.revokeObjectURL(url), 60000);
    }

    /** Re-reads the reservation so the screen reflects what the server just wrote. */
    refreshReservation() {
        return reserveCurrent({ token: this.sessionToken })
            .then((reservation) => {
                if (reservation) {
                    this.reservation = reservation;
                }
                return this.loadCopies();
            })
            .catch(() => {
                // The signature is recorded either way; a failed refresh is not worth an error.
            });
    }

    /* The map stays mounted for all of stage 3: unmounting resets the camera and re-pays a
       ~3,400-node SVG rebuild. */
    /** The map's own leading-edge chrome must stand down while the card is over it. */
    get mapMuted() {
        return this.showCard;
    }

    /* The reservation, handed to the map to render in its own search panel - the component
       that owns the corner owns the layout; only wording and formatting stay here. */
    get heldReference() {
        return this.reservation ? this.reservation.reservationNumber : null;
    }

    /** Empty once signed: the seven days are finished with them, and a spent countdown reports
     *  a failure that did not happen. Mirrors showSla. */
    get heldDaysLabel() {
        return this.reservationSubmitted ? '' : this.daysRemainingLabel;
    }

    get heldUrgent() {
        return !!this.session && this.session.daysRemaining <= 2;
    }

    get showMap() {
        return this.isMap || this.isFinance || this.isUndertaking || this.isDone;
    }

    /** Only on stages with content: on the map stage every inner template is false and the
     *  card rendered as an empty panel. A collapsed confirmation is the same case. */
    get showCard() {
        return !this.resuming && !this.isLocked && !this.isMap && !this.doneCollapsed;
    }

    /** Only after they press back. The map shows the line; Details brings the card back. */
    get doneCollapsed() {
        return this.isDone && !this.doneExpanded;
    }

    handleShowDetails() {
        this.doneExpanded = true;
    }

    handleHideDetails() {
        this.doneExpanded = false;
    }


    // Over the map the card is a panel on the leading edge, not a centred modal - the customer is
    // deciding about a place and should be able to see it.
    get paneClass() {
        if (this.showMap) {
            // Except the confirmation, which is centred. Finance and undertaking are decisions
            // about a villa and keep the community beside them; this one is that decision made.
            return this.isDone ? 'pane pane-over pane-centre' : 'pane pane-over';
        }
        /* Decided here, not with :has() in CSS: unsupported :has() would silently drop the
           Accept button below the fold. */
        return this.isDeclaration || this.isUndertaking ? 'pane pane-full' : 'pane';
    }

    // Only a confirmed reservation is "held". A quote has taken nothing off the map, so painting
    // it as the customer's villa would promise something the server has not granted.
    get heldPlotUid() {
        return this.reservation ? this.reservation.plotUid : null;
    }

    /* ---------- stage 3: reservation ---------- */

    // The map has already taken the hold by the time this fires - the villa is the customer's
    // while they read what follows, which is the whole point of holding before the undertaking.
    handleUnitSelected(event) {
        const picked = event.detail.quote;
        this.errorMessage = '';
        // The map asks through swaprequest BEFORE it writes, so a quote reaching this handler
        // has already been agreed to.
        this.quote = picked;
        this.persistQuote();
        this.routeQuote();
    }

    /** The map has asked to swap a committed villa and waits on the answer. Driven by the
     *  REQUEST, not a quote - a quote only exists once the server has written. */
    handleSwapRequest(event) {
        this.pendingSwapPlot = (event.detail && event.detail.plotUid) || '';
    }

    get confirmingSwap() {
        return Boolean(this.pendingSwapPlot);
    }

    handleConfirmSwap() {
        this.pendingSwapPlot = '';
        // The map owns the call. It kept the unit while we asked, and takes it now.
        const map = this.template.querySelector('c-masterplan-unit-selector');
        if (map) {
            map.confirmSwap();
        }
    }

    /** Nothing was written, so cancelling just drops the selection and leaves them on the map. */
    handleCancelSwap() {
        this.pendingSwapPlot = '';
        // Honest now. Nothing was written, so there is nothing to put back - which is the whole
        // difference from the version this replaces.
        const map = this.template.querySelector('c-masterplan-unit-selector');
        if (map) {
            map.cancelSwap();
        }
    }

    /** Where an uncommitted selection goes next. Nothing is written until acceptUndertaking. */
    routeQuote() {
        const q = this.quote;
        if (!q) {
            this.stage = STAGE_MAP;
            return;
        }
        this.syncHoldCountdown();
        // Nothing owed means nothing to choose, so the money screen would only say "AED 0".
        if (q.additionalAmount > 0) {
            this.stage = STAGE_FINANCE;
            return;
        }
        this.stage = STAGE_UNDERTAKING;
        this.loadUndertaking();
    }

    /** Keeps an uncommitted selection across a refresh. sessionStorage, matching the token: an
     *  uncommitted intent should die with the tab. */
    persistQuote() {
        try {
            if (this.quote) {
                sessionStorage.setItem(QUOTE_KEY, JSON.stringify({
                    quote: this.quote,
                    paymentMethod: this.paymentMethod
                }));
            } else {
                sessionStorage.removeItem(QUOTE_KEY);
            }
        } catch (e) {
            // Safari private mode throws on write. A lost draft selection is recoverable by
            // picking again; failing the journey over it is not.
        }
    }

    restoreQuote() {
        try {
            const raw = sessionStorage.getItem(QUOTE_KEY);
            if (!raw) {
                return false;
            }
            const saved = JSON.parse(raw);
            this.quote = saved.quote;
            this.paymentMethod = saved.paymentMethod || this.paymentMethod;
            return !!this.quote;
        } catch (e) {
            return false;
        }
    }

    /** Derived from the reservation's own fields, so a refresh lands where the customer left
     *  off. */
    routeReservation() {
        const r = this.reservation;
        if (!r) {
            this.stage = STAGE_MAP;
            return;
        }
        if (r.undertakingAccepted) {
            // Open, not collapsed: unsigned, the Sign button sat behind a Details press they
            // had no reason to expect.
            this.doneExpanded = true;
            this.stopHoldCountdown();
            this.stage = STAGE_DONE;
            this.loadCopies();
            return;
        }
        this.syncHoldCountdown();
        if (r.additionalAmount > 0 && !r.paymentMethod) {
            this.stage = STAGE_FINANCE;
            return;
        }
        this.stage = STAGE_UNDERTAKING;
        this.loadUndertaking();
    }

    handlePaymentMethod(event) {
        this.paymentMethod = event.currentTarget.dataset.method;
    }

    // The active language was conveyed by colour alone.
    get arActive() {
        return this.lang === 'ar';
    }

    get enActive() {
        return this.lang === 'en';
    }

    get paymentOptions() {
        return PAYMENT_SCENARIOS.map((o) => ({
            key: o.key,
            label: this.labels[o.labelKey],
            cls: o.key === this.paymentMethod ? 'opt selected' : 'opt',
            checked: o.key === this.paymentMethod
        }));
    }

    /** What the chosen scenario commits the customer to. Empty until they choose. */
    get selectedNotes() {
        const chosen = PAYMENT_SCENARIOS.find((o) => o.key === this.paymentMethod);
        return chosen ? chosen.notes.map((k) => ({ key: k, text: this.labels[k] })) : [];
    }

    get hasSelectedNotes() {
        return this.selectedNotes.length > 0;
    }

    /** Whether this villa costs anything on top of the approved amount. */
    get needsPayment() {
        return !!this.active && this.active.additionalAmount > 0;
    }

    /* ---------- the hold clock ---------- */

    /** Starts or stops the countdown to match the screen; called at routing points because a
     *  getter cannot tick. */
    syncHoldCountdown() {
        this.stopHoldCountdown();
        const ends = this.active && this.active.holdExpiresAt;
        if (!ends || this.isDone) {
            this.holdSeconds = 0;
            return;
        }
        this.holdWarned = false;
        this.tickHold(ends);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this.holdTimer = setInterval(() => this.tickHold(ends), 1000);
    }

    tickHold(ends) {
        const left = Math.floor((new Date(ends).getTime() - Date.now()) / 1000);
        this.holdSeconds = left > 0 ? left : 0;
        if (this.holdSeconds === 0) {
            this.stopHoldCountdown();
            this.holdAnnouncement = t(this.lang, 'holdLapsed');
        } else if (this.holdSeconds <= 120 && !this.holdWarned) {
            this.holdWarned = true;
            this.holdAnnouncement = t(this.lang, 'holdEndingSoon');
        }
    }

    stopHoldCountdown() {
        clearInterval(this.holdTimer);
        this.holdTimer = null;
    }

    /** Shown wherever there is a session to name. Not on welcome, sign-in or the code screen. */
    get showWho() {
        return !!this.session && !!this.session.customerName;
    }

    /** The name alone; the application number renders on its own line - see .who in the
     *  stylesheet. */
    get whoLabel() {
        return this.session ? this.session.customerName : '';
    }

    /** The hold clock takes the top strip on the two screens where a hold exists. */
    get showHoldBar() {
        return (this.isFinance || this.isUndertaking) && !!(this.active && this.active.holdExpiresAt);
    }

    /** The plain seven-day bar everywhere else, so the two clocks are never stacked. */
    get showSlaBar() {
        return this.showSla && !this.showHoldBar;
    }

    get holdClass() {
        if (this.holdSeconds === 0) {
            return 'holdbar lapsed';
        }
        // Same threshold convention as the SLA bar, which turns urgent under two days.
        return this.holdSeconds <= 120 ? 'holdbar urgent' : 'holdbar';
    }

    get holdLabel() {
        if (this.holdSeconds === 0) {
            return t(this.lang, 'holdLapsed');
        }
        const m = Math.floor(this.holdSeconds / 60);
        const s = this.holdSeconds % 60;
        return t(this.lang, 'heldForYou', `${m}:${s < 10 ? '0' : ''}${s}`);
    }

    // No server call: the payment method is part of the commitment and is sent with it.
    get financeDisabled() {
        // The refusal too: confirm() is guarded server side, so without this the customer presses
        // Continue and is refused after choosing a payment method rather than before.
        return this.busy || !this.paymentMethod || !!this.reserveRefusal;
    }

    handleFinanceContinue() {
        if (!this.paymentMethod) {
            this.errorMessage = t(this.lang, 'MSG_PAYMENT_METHOD');
            return;
        }
        this.errorMessage = '';
        this.persistQuote();
        this.stage = STAGE_UNDERTAKING;
        this.loadUndertaking();
    }

    /** The villa and figures restated where they are signed for: consent evidence about a
     *  specific villa at a specific price. */
    get undertakingRecap() {
        const parts = [this.plotLabel, this.priceLabel];
        if (this.needsPayment) {
            parts.push(t(this.lang, 'extraToPay') + ' ' + this.additionalLabel);
            const chosen = this.paymentOptions.find((o) => o.checked);
            if (chosen) {
                parts.push(chosen.label);
            }
        }
        return parts.filter(Boolean).join(' · ');
    }

    /** The service-specific deed, NOT the stage 3 declaration - the two are separate calls on
     *  purpose. */
    loadUndertaking() {
        this.undertakingRead = false;
        this.readProgress = 0;
        this.declarationFailed = false;
        // Cleared, not just re-fetched: the old body could be accepted while the new language
        // was in flight, stamping Undertaking_Language__c with one they did not read.
        this.undertaking = undefined;
        const generation = this.sessionGeneration;
        getUndertaking({
            language: this.lang,
            serviceType: this.session ? this.session.serviceType : null
        })
            .then((undertaking) => {
                if (!this.isCurrent(generation)) {
                    return;
                }
                this.undertaking = undertaking;
            })
            .catch((error) => {
                if (!this.isCurrent(generation)) {
                    return;
                }
                this.declarationFailed = true;
                this.errorMessage = this.messageOf(error);
            });
    }

    handleUndertakingScroll(event) {
        this.trackProgress(event.target);
        if (this.undertakingRead) {
            return;
        }
        const box = event.target;
        if (box.scrollTop + box.clientHeight >= box.scrollHeight - 24) {
            this.undertakingRead = true;
            this.revealAccept();
        }
    }

    /** Distance through the legal text. The gate is not negotiable; the bar just shows how
     *  far is left. */
    trackProgress(box) {
        const travel = box.scrollHeight - box.clientHeight;
        this.readProgress = travel <= 0 ? 100 : Math.min(100, Math.round((box.scrollTop / travel) * 100));
    }

    get readProgressStyle() {
        return `width: ${this.readProgress}%;`;
    }

    get undertakingLoading() {
        return !this.declaration && !this.declarationFailed;
    }

    get declarationLoading() {
        return !this.declaration && !this.declarationFailed;
    }

    /** The body's own language, so a screen reader voices Arabic legal text with an Arabic voice
     *  even when the chrome is English. */
    get declarationLang() {
        return this.declaration ? this.declaration.language : this.lang;
    }

    get declarationHintClass() {
        return this.declarationRead ? 'read-hint read' : 'read-hint';
    }

    get declarationHintLabel() {
        return t(this.lang, this.declarationRead ? 'declarationRead' : 'declarationScroll');
    }

    get undertakingHintClass() {
        return this.undertakingRead ? 'read-hint read' : 'read-hint';
    }

    get undertakingHintLabel() {
        return t(this.lang, this.undertakingRead ? 'declarationRead' : 'declarationScroll');
    }

    get undertakingDisabled() {
        return !this.undertakingRead || this.busy;
    }

    /** The villa being committed to. A resume in a new tab has no quote, so the live
     *  reservation - which names the same villa - is the fallback. */
    get confirmingPlotUid() {
        if (this.quote && this.quote.plotUid) {
            return this.quote.plotUid;
        }
        return this.reservation && this.reservation.plotUid ? this.reservation.plotUid : null;
    }

    handleAcceptUndertaking() {
        this.busy = true;
        this.errorMessage = '';
        const generation = this.sessionGeneration;
        // The body's own language, not the chrome's - this is consent evidence, and the two can
        // differ for as long as a reload is in flight. Matches what handleAccept already does.
        const signedIn = this.undertaking ? this.undertaking.language : this.lang;
        confirmReservation({
            token: this.sessionToken,
            plotUid: this.confirmingPlotUid,
            paymentMethod: this.paymentMethod,
            language: signedIn
        })
            .then((reservation) => {
                if (!this.isCurrent(generation)) {
                    return;
                }
                this.reservation = reservation;
                this.quote = undefined;
                this.persistQuote();
                // Expanded exactly once, here. Every later arrival at DONE is a resume and gets
                // the bar instead.
                this.doneExpanded = true;
                this.stopHoldCountdown();
                this.stage = STAGE_DONE;
                this.loadCopies();
                // Two Apex calls on purpose: Apex refuses a callout after DML, and merging
                // them server side is what produced the original 400.
                if (this.signingEnabled && !this.isSigned) {
                    this.startSigning(true);
                }
            })
            .catch((error) => {
                this.errorMessage = this.messageOf(error);
            })
            .finally(() => {
                this.busy = false;
            });
    }

    // Changing villa is a return to the map. The hold moves when they pick another one; it is not
    // released here, so backing out and changing their mind again costs them nothing.
    /** Two-step, so the one control that undoes a confirmed reservation cannot be pressed by
     *  accident - and so the customer is told which opportunity they are on. */
    /** Moves focus on screen change: swapping the card drops focus to <body>, and a
     *  screen-reader user would hear nothing. */
    manageFocus() {
        if (this.showWarning && !this.warnedFocused) {
            this.warnedFocused = true;
            const cta = this.template.querySelector('.idle-cta');
            if (cta) {
                cta.focus();
            }
            return;
        }
        if (!this.showWarning) {
            this.warnedFocused = false;
        }
        // Expanding the confirmation swaps a one-line bar for a full card, which is a screen
        // change as far as a screen-reader user is concerned, so it has to key the focus move too.
        const key = this.stage + (this.doneExpanded ? ':open' : '');
        if (key === this.focusedStage) {
            return;
        }
        const heading = this.template.querySelector('.card .title');
        if (!heading) {
            return;
        }
        this.focusedStage = key;
        // tabindex -1 so it can take programmatic focus without entering the tab order.
        heading.setAttribute('tabindex', '-1');
        heading.focus();
    }

    /* ---------- sign out ---------- */

    handleAskSignOut = () => {
        this.confirmingSignOut = true;
    };

    handleCancelSignOut = () => {
        this.confirmingSignOut = false;
    };

    /** What signing out costs depends on where they are: before the undertaking is accepted it
     *  gives up the soft hold, after it the villa is safe. No extra call needed. */
    get signOutBody() {
        const res = this.reservation;
        if (!res || !res.plotUid) {
            return t(this.lang, 'signOutBodyPlain');
        }
        const plot = this.plotLabel;
        if (res.undertakingAccepted === true) {
            return t(this.lang, 'signOutBodyReserved', plot);
        }
        const held = res.holdExpiresAt && new Date(res.holdExpiresAt).getTime() > Date.now();
        return held
            ? t(this.lang, 'signOutBodyHeld', plot)
            : t(this.lang, 'signOutBodyPlain');
    }

    /** Fire-and-forget on the server: a dropped network must never keep someone signed in on
     *  a shared device. */
    handleConfirmSignOut = () => {
        this.confirmingSignOut = false;
        if (this.channel) {
            this.channel.postMessage({ type: 'logout' });
        }
        // lock() does the teardown and the reporting; this only decides that it happens.
        this.lock('signedout');
    };

    /** Escape keeps the customer signed in - the least destructive reading of dismissal. */
    handleIdleKey(event) {
        if (event.key === 'Escape') {
            this.handleStaySignedIn();
        }
    }

    // The done card's own confirm-then-change handlers were deleted; changing villa now goes
    // through the map's confirmingSwap with the same warning.

    get changeVillaWarning() {
        const plot = this.reservation ? this.reservation.plotUid : '';
        let text = t(this.lang, 'changeVillaWarn', plot);
        // Fires on the LAST remaining change, and passes the TOTAL, not the remainder: the
        // string reads "final opportunity of {total}".
        const allowed = this.session && this.session.unitChangesAllowed;
        if (this.changesRemaining === 1 && allowed) {
            text += ' ' + t(this.lang, 'changeVillaFinal', num(allowed));
        }
        return text;
    }

    /** Gives the villa back and returns to the map. Awaited: a silent release failure would
     *  strand a confirmed villa for the rest of the seven days. */
    handleChangeVilla() {
        if (!this.sessionToken || !this.active) {
            this.toMapAfterChange();
            return;
        }
        this.busy = true;
        this.errorMessage = '';
        const generation = this.sessionGeneration;
        releaseCurrent({ token: this.sessionToken })
            .then(() => {
                if (!this.isCurrent(generation)) {
                    return;
                }
                const freed = this.plotLabel;
                // Both, not just the quote. `active` falls back to `reservation`, so leaving it
                // set showed the OLD villa's price and plot on the finance and undertaking screens.
                this.quote = undefined;
                this.reservation = undefined;
                this.doneExpanded = false;
                this.stopHoldCountdown();
                this.persistQuote();
                this.toMapAfterChange(freed);
            })
            .catch((error) => {
                // Stay put. Landing on the map would tell them it worked when it did not.
                this.errorMessage = this.messageOf(error);
            })
            .finally(() => {
                this.busy = false;
            });
    }

    toMapAfterChange(freedPlotUid) {
        this.stage = STAGE_MAP;
        // markHeld flew the camera to the held villa; without this the customer keeps staring
        // at the plot they just asked to leave.
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        requestAnimationFrame(() => {
            const map = this.template.querySelector('c-masterplan-unit-selector');
            if (!map) {
                return;
            }
            // The payload is a cacheable snapshot. If it was loaded while this villa was theirs it
            // still reads Held, so the map is told the plot is free rather than reloading 3.5 MB.
            if (freedPlotUid && map.markAvailable) {
                map.markAvailable(freedPlotUid);
            }
            if (map.showCommunity) {
                map.showCommunity();
            }
        });
    }

    /* ---------- reservation display ---------- */

    /** The quote while they are deciding, the reservation once it exists. Same shape either way,
     *  so every figure on screen comes from one place. */
    get active() {
        return this.reservation || this.quote;
    }

    get priceLabel() {
        return this.active ? t(this.lang, 'aed') + ' ' + num(this.active.unitPrice) : '';
    }

    get approvedLabel() {
        const value = this.active ? this.active.approvedAmount : null;
        return value == null ? '' : '\u2212 ' + t(this.lang, 'aed') + ' ' + num(value);
    }

    get additionalLabel() {
        return this.active ? t(this.lang, 'aed') + ' ' + num(this.active.additionalAmount) : '';
    }

    get referenceLabel() {
        return this.reservation ? this.reservation.reservationNumber : '';
    }

    get plotLabel() {
        return this.active ? this.active.plotUid : '';
    }

    get undertakingLede() {
        return t(this.lang, 'undertakingLede', this.plotLabel);
    }

    /** Accepting makes a reservation Submitted, not Completed, and the sweeper releases an
     *  unsigned one - the card must not claim completion. Same condition as the sign note. */
    get awaitingSignatureOnDone() {
        return this.signingEnabled && !this.isSigned;
    }

    get doneTitleLabel() {
        return t(this.lang, this.awaitingSignatureOnDone ? 'donePendingTitle' : 'doneTitle');
    }

    get doneMarkClass() {
        // A tick is a claim of completion on its own. Changing the words and leaving it would keep
        // making the point the words no longer make.
        return this.awaitingSignatureOnDone ? 'done-mark pending' : 'done-mark';
    }

    get doneLede() {
        return t(
            this.lang,
            this.awaitingSignatureOnDone ? 'donePendingLede' : 'doneLede',
            this.plotLabel
        );
    }

    get reservationDeadline() {
        return this.formatDate(this.reservation && this.reservation.slaEnd);
    }

    get paymentDeadline() {
        return this.formatDate(this.reservation && this.reservation.additionalPaymentDue);
    }

    get showPaymentDeadline() {
        return !!(this.reservation && this.reservation.additionalPaymentDue);
    }

    /** Short month for the fact strip. "21 November 2026" wraps in a third of the card and takes
     *  the strip from 70px to 88px; "21 Nov 2026" fits on one line in both languages. */
    get reservationDeadlineShort() {
        return this.formatDate(this.reservation && this.reservation.slaEnd, true);
    }

    get paymentDeadlineShort() {
        return this.formatDate(this.reservation && this.reservation.additionalPaymentDue, true);
    }

    // Gregorian and Latin-digit in both languages, matching the plot numbers and the money.
    formatDate(value, shortMonth) {
        if (!value) {
            return '';
        }
        // The month name is prose and follows the UI language; digits stay Latin in both, so
        // numeral systems never mix with the identifiers and money elsewhere.
        const locale = this.lang === 'ar' ? 'ar-AE-u-nu-latn' : 'en-GB';
        return new Date(value).toLocaleDateString(locale, {
            day: 'numeric',
            month: shortMonth ? 'short' : 'long',
            year: 'numeric'
        });
    }

    /* ---------- language ---------- */

    get dir() {
        return dirOf(this.lang);
    }

    // The declaration body carries its own language from the server. Reading it off the payload
    // rather than the chrome means the legal text always renders in its own direction.
    get declarationDir() {
        return dirOf(this.declaration ? this.declaration.language : this.lang);
    }

    get undertakingDir() {
        return dirOf(this.undertaking ? this.undertaking.language : this.lang);
    }

    get undertakingLang() {
        return this.undertaking ? this.undertaking.language : this.lang;
    }

    // One object rather than a getter per string: the template reads {labels.begin}, so adding a
    // string costs nothing here.
    get labels() {
        return allLabels(this.lang);
    }

    /** The card's one control, composed from two approved strings so it costs no Arabic
     *  review. It releases nothing itself; the swap dialog asks before a villa is given up. */
    get backOrChangeLabel() {
        const back = t(this.lang, 'backToCommunity');
        // Past the allowance the offer goes with the ability, but the button never hides - it
        // is the only way off this screen.
        return this.canChangeVilla ? `${back} / ${t(this.lang, 'changeVilla')}` : back;
    }

    get emiratesIdPlaceholder() {
        return '784-XXXX-XXXXXXX-X';
    }

    /* localStorage, unlike the tab-scoped token: the language must survive sign-out. Wrapped
       because Safari private mode throws on read and write. */
    storedLang() {
        try {
            const v = localStorage.getItem(LANG_KEY);
            return v === 'ar' || v === 'en' ? v : null;
        } catch (e) {
            return null;
        }
    }

    persistLang(value) {
        try {
            localStorage.setItem(LANG_KEY, value);
        } catch (e) {
            // Nothing to do - the choice still applies for this page view.
        }
    }

    /** Adopt the stored Preferred_Language__c only when no choice was made on this device -
     *  an explicit choice always wins. */
    adoptSessionLanguage(session) {
        if (this.storedLang() || !session || !session.language) {
            return;
        }
        this.lang = session.language;
        this.persistLang(session.language);
    }

    // Only the declaration stage becomes a flex column, so the phone layout below cannot affect
    // the welcome, sign-in or OTP screens.
    get cardClass() {
        const cls = this.isDeclaration || this.isUndertaking ? 'card card-declaration' : 'card';
        // On the arrival plane the panel chrome comes off - the plane is already the surface.
        return this.showArrival ? `${cls} card-plane` : cls;
    }

    /* ---------- stage rail and SLA instrument ---------- */

    /* Four steps: verify, agree, choose, confirm. Welcome lights nothing, and the map (step 3)
       renders no card, so 3 only ever shows as completed. */
    get railStage() {
        if (this.isLogin || this.isOtp) {
            return 1;
        }
        if (this.isDeclaration) {
            return 2;
        }
        // Step 4 covers the money, the undertaking and the confirmation. They are three screens
        // but one step: committing to the villa the customer chose at step 3.
        return this.isFinance || this.isUndertaking || this.isDone ? 4 : 0;
    }

    get showRail() {
        // Not on home: railStage is 0 there, so it rendered three empty segments on the one
        // screen where there is no progress to show.
        return !this.isLocked && !this.isWelcome;
    }

    get railSegments() {
        const at = this.railStage;
        return [1, 2, 3, 4].map((n) => ({
            key: n,
            cls: n === at ? 'on' : n < at ? 'done' : ''
        }));
    }

    /** Whether the held villa is committed to; the 7-day clock is finished with them then.
     *  Completed counts - it is the same commitment with the signature landed. */
    get reservationSubmitted() {
        const status = this.reservation && this.reservation.status;
        return status === 'Submitted' || status === 'Completed';
    }

    /** The pinned-villa strip. */
    get isOpsSession() {
        return !!(this.session && this.session.isOps);
    }

    get pinnedPlotUid() {
        return this.session ? this.session.pinnedPlotUid : undefined;
    }

    get pinnedBannerText() {
        if (!this.pinnedPlotUid || this.isOpsSession) {
            return '';
        }
        return t(this.lang, 'pinnedBanner').replace('{0}', this.pinnedPlotUid);
    }

    get canChangeVilla() {
        if (!this.session) {
            return false;
        }
        // A pin is final, so the change button goes. Ops unpins if needed.
        if (this.session.pinnedPlotUid) {
            return false;
        }
        // Allowance first: it only ever applies to a signed villa, which is the same thing the
        // refusal clause below is about, and running out of changes hides the button outright.
        if (this.reservationSubmitted && this.changesRemaining <= 0) {
            return false;
        }
        return !this.session.reservationRefusal || !this.reservationSubmitted;
    }

    /** Swaps of a signed villa still available. Read from the server, never counted here. */
    get changesRemaining() {
        const left = this.session && this.session.unitChangesRemaining;
        return typeof left === 'number' ? left : 1;
    }

    get refusalMessage() {
        if (!this.session || !this.session.reservationRefusal || this.reservationSubmitted) {
            return '';
        }
        return t(this.lang, this.session.reservationRefusal);
    }

    get showRefusal() {
        return !!this.refusalMessage;
    }

    // Suppressed once signed. A customer who confirmed in time must not be shown a spent countdown
    // as though something had gone wrong.
    get showSla() {
        return !!this.session && this.session.daysRemaining != null && !this.reservationSubmitted;
    }

    get slaClass() {
        return this.session && this.session.daysRemaining <= 2 ? 'sla urgent' : 'sla';
    }

    // Clamped both ends: a lapsed window must not render a negative bar, and a fresh one
    // must not overflow if the server ever reports more than the configured window.
    get slaStyle() {
        const left = this.session ? this.session.daysRemaining : 0;
        const pct = Math.max(0, Math.min(100, (left / SLA_DAYS) * 100));
        return `width: ${pct}%;`;
    }

    get arClass() {
        return this.lang === 'ar' ? 'lang-btn active' : 'lang-btn';
    }

    get enClass() {
        return this.lang === 'en' ? 'lang-btn active' : 'lang-btn';
    }

    handleLanguageSelect(event) {
        const next = event.currentTarget.dataset.lang;
        if (!next || next === this.lang) {
            return;
        }
        this.lang = next;
        this.persistLang(next);
        // Legal bodies are re-fetched on switch: the accepted language is recorded as legal
        // evidence, and without the reload it could stamp a language the customer never read.
        if (this.stage === STAGE_DECLARATION) {
            this.loadDeclaration();
        } else if (this.stage === STAGE_UNDERTAKING) {
            this.loadUndertaking();
        }
    }

    get lockTitle() {
        if (this.lockedReason === 'superseded') {
            return t(this.lang, 'lockSupersededTitle');
        }
        return this.lockedReason === 'signedout'
            ? t(this.lang, 'lockSignedOutTitle')
            : t(this.lang, 'lockIdleTitle');
    }

    /* Three reasons, three messages. Telling someone who pressed Sign out that they were idle for
       five minutes is the kind of small lie that makes a service feel broken. */
    get lockMessage() {
        if (this.lockedReason === 'superseded') {
            return t(this.lang, 'lockSuperseded');
        }
        return this.lockedReason === 'signedout'
            ? t(this.lang, 'lockSignedOut')
            : t(this.lang, 'lockIdle');
    }

    get showWarning() {
        return this.warnSeconds > 0 && !this.isLocked;
    }

    get sessionToken() {
        return this.session ? this.session.token : null;
    }

    get canResend() {
        return this.resendSeconds <= 0 && !this.busy;
    }

    /** The template binds `disabled`, so it needs the negative. Binding canResend there inverted
     *  the button: live during the countdown, dead once it finished. */
    get cannotResend() {
        return !this.canResend;
    }

    get resendLabel() {
        return this.resendSeconds > 0
            ? t(this.lang, 'resendIn', this.resendSeconds)
            : t(this.lang, 'resendCode');
    }

    get sentToLabel() {
        return t(this.lang, 'sentTo', this.maskedTarget);
    }

    get applicationLabel() {
        return this.session ? t(this.lang, 'applicationNo', this.session.applicationNumber) : '';
    }

    get idleWarningLabel() {
        return t(this.lang, 'idleWarning', this.warnSeconds);
    }

    get acceptDisabled() {
        return !this.declarationRead || this.busy;
    }

    /** Soft launch. Absent on an older cached session payload, so only an explicit false closes
     *  it - a missing field must not lock the site. */
    get reservationsOpen() {
        return !this.session || this.session.reservationsOpen !== false;
    }

    /** The map states the closed case, because a boolean @api cannot default to true. */
    get reservationsClosed() {
        return !this.reservationsOpen;
    }

    /** Both sources come from ADHA_JourneyController.reservationsOpen; the load-time call
     *  covers the screens before a session exists. */
    get showExplorationBanner() {
        return this.exploring || (!!this.session && this.reservationsClosed);
    }

    /* ADHA named the placements: the full notice where the project link opens, the short one
       with the masterplan. Chosen by placement, not viewport width. */
    get showFullNotice() {
        return this.showExplorationBanner && this.stage === STAGE_WELCOME;
    }

    /* Keyed on showMap, not the map stage: the masterplan stays mounted under finance,
       undertaking and done, so "with the masterplan" is four stages. */
    get showShortNotice() {
        // Not for ops: the notice is applicant guidance, and the pin strip needs the headroom.
        return this.showExplorationBanner && this.showMap && !this.isOpsSession;
    }

    get noticeTitle() {
        return t(this.lang, 'noticeTitle');
    }

    /** Three keys rather than one string with newlines: the template iterates them, and Arabic is
     *  reviewed and approved string by string. */
    get noticeParagraphs() {
        return ['noticeFullP1', 'noticeFullP2', 'noticeFullP3'].map((k) => ({
            key: k,
            text: t(this.lang, k)
        }));
    }

    get noticeShort() {
        return t(this.lang, 'noticeShort');
    }

    /* ADHA's first sentence must never be hidden. Split on the sentence rather than authored
       separately, so there is no second string to approve. */
    get noticeLead() {
        const full = this.noticeShort;
        const stop = full.indexOf('.');
        return stop === -1 ? full : full.slice(0, stop + 1);
    }

    get noticeRest() {
        const full = this.noticeShort;
        const stop = full.indexOf('.');
        return stop === -1 ? '' : full.slice(stop + 1).trim();
    }

    get noticeExpanded() {
        return this.noticeOpen;
    }

    get noticeToggleLabel() {
        return t(this.lang, this.noticeOpen ? 'noticeLess' : 'noticeMore');
    }

    handleNoticeToggle() {
        this.noticeOpen = !this.noticeOpen;
    }

    /** The sheet dismisses on its backdrop, so a tap on the card itself must not reach it. */
    handleNoticeCardClick(event) {
        event.stopPropagation();
    }

    /** The 7-day warning says the clock starts at sign-in. In exploration mode it does not, so the
     *  warning would contradict both the notice above it and what the server actually does. */
    get showWelcomeNotice() {
        return !this.showExplorationBanner;
    }

    /** Passed to the map so the villa card cannot offer Continue with this unit when the server
     *  would refuse the hold behind it. Empty string, not null: an @api string property. */
    get reserveRefusal() {
        const windowRefusal = (this.session && this.session.reservationRefusal) || '';
        // Clock first, mirroring the server's ordering: a customer out of time hears about the
        // clock, not the count.
        if (windowRefusal) {
            return windowRefusal;
        }
        // Without this the map offers a fourth villa and the server's refusal arrives too late
        // to be useful.
        if (this.reservationSubmitted && this.changesRemaining <= 0) {
            return 'MSG_CHANGES_SPENT';
        }
        return '';
    }

    /** Refused by the clock, not the soft-launch gate. Mirrors the same getter on
     *  masterplanUnitSelector. */
    get reserveRefused() {
        return !!this.reserveRefusal && this.reservationsOpen;
    }

    /** While reservations are closed the server records no acceptance, so the button must not
     *  claim one. The scroll gate stays: it is what makes the document get read. */
    get acceptLabel() {
        return t(this.lang, this.reservationsOpen ? 'acceptContinue' : 'continueLabel');
    }

    get daysRemainingLabel() {
        if (!this.session || this.session.daysRemaining == null) {
            return '';
        }
        const days = this.session.daysRemaining;
        return days === 1 ? t(this.lang, 'oneDayLeft') : t(this.lang, 'daysLeft', days);
    }

    /* ---------- stage 2: login ---------- */

    handleBegin() {
        this.stage = STAGE_LOGIN;
        this.errorMessage = '';
    }

    // Both fields normalise Arabic-Indic digits to ASCII: an Arabic keyboard produces ٠-٩,
    // which the server rejects with no explanation the customer can act on.
    handleEmiratesId(event) {
        const el = event.target;
        // Counted before reformatting, so the caret survives an inserted or removed separator.
        const typedDigits = digitsOf(el.value.slice(0, el.selectionStart)).length;
        const formatted = formatEmiratesId(digitsOf(el.value).slice(0, 15));
        this.emiratesId = formatted;
        // Written straight to the DOM as well, so the re-render is a no-op and the caret is not
        // thrown to the end of the field on every keystroke.
        el.value = formatted;
        const caret = caretAfterDigit(formatted, typedDigits);
        el.setSelectionRange(caret, caret);
    }

    handleOtpInput(event) {
        this.otp = toLatinDigits(event.target.value);
    }

    /** The journey's error box does not exist on the map stage, so the map shows it instead. */
    showMapNotice(message) {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        requestAnimationFrame(() => {
            const map = this.template.querySelector('c-masterplan-unit-selector');
            if (map && map.showNotice) {
                map.showNotice(message);
            }
        });
    }

    handleBackToWelcome() {
        this.stage = STAGE_WELCOME;
        this.errorMessage = '';
    }

    /** Back to the Emirates ID field, discarding the verification in flight. */
    handleChangeEmiratesId() {
        this.stage = STAGE_LOGIN;
        this.otp = '';
        this.verificationRequestId = null;
        this.maskedTarget = '';
        this.infoMessage = '';
        this.errorMessage = '';
        this.stopResendCountdown();
    }

    handleEmiratesIdKey(event) {
        if (event.key === 'Enter') {
            this.handleSendCode();
        }
    }

    handleOtpKey(event) {
        if (event.key === 'Enter') {
            this.handleVerify();
        }
    }

    handleSendCode() {
        // 15 digits, not characters: anything shorter failed the server's format check
        // silently, one screen later.
        if (digitsOf(this.emiratesId).length !== 15) {
            this.errorMessage = t(this.lang, 'MSG_ENTER_EID');
            return;
        }
        this.busy = true;
        this.errorMessage = '';
        const generation = this.sessionGeneration;
        startLogin({ emiratesId: this.emiratesId })
            .then((result) => {
                // Development bypass. The server decides this, never the browser, and it lands
                // through completeLogin like every other route to a session.
                if (result.skipOtp) {
                    this.completeLogin(result.session, generation);
                    return;
                }
                // The response is identical for an unknown Emirates ID, so the UI cannot leak
                // whether this person is eligible either.
                this.verificationRequestId = result.verificationRequestId;
                this.maskedTarget = result.maskedTarget;
                // Apex sends a code; the wording lives in the label module.
                this.infoMessage = t(this.lang, result.message || 'MSG_START');
                this.stage = STAGE_OTP;
                this.startResendCountdown(60);
            })
            .catch((error) => {
                this.errorMessage = this.messageOf(error);
            })
            .finally(() => {
                this.busy = false;
            });
    }

    handleVerify() {
        if (!this.verificationRequestId) {
            // No code was ever sent, which means the Emirates ID matched nothing. Say so only now,
            // at the point the customer has already committed to waiting for a code.
            this.errorMessage = t(this.lang, 'MSG_EID_UNVERIFIED');
            return;
        }
        if (!this.otp || this.otp.trim().length < 4) {
            this.errorMessage = t(this.lang, 'MSG_ENTER_OTP');
            return;
        }
        this.busy = true;
        this.errorMessage = '';
        const generation = this.sessionGeneration;
        verifyCode({ verificationRequestId: this.verificationRequestId, code: this.otp })
            .then((session) => {
                this.completeLogin(session, generation);
            })
            .catch((error) => {
                this.errorMessage = this.messageOf(error);
            })
            .finally(() => {
                this.busy = false;
            });
    }

    handleResend() {
        if (!this.canResend || !this.verificationRequestId) {
            return;
        }
        this.busy = true;
        resendCode({ verificationRequestId: this.verificationRequestId })
            .then((result) => {
                this.maskedTarget = result.maskedTarget;
                this.infoMessage = t(this.lang, 'MSG_CODE_RESENT');
                this.startResendCountdown(60);
            })
            .catch((error) => {
                this.errorMessage = this.messageOf(error);
            })
            .finally(() => {
                this.busy = false;
            });
    }

    stopResendCountdown() {
        clearInterval(this.resendTimer);
        this.resendSeconds = 0;
    }

    startResendCountdown(seconds) {
        clearInterval(this.resendTimer);
        this.resendSeconds = seconds;
        this.resendTimer = setInterval(() => {
            this.resendSeconds -= 1;
            if (this.resendSeconds <= 0) {
                clearInterval(this.resendTimer);
            }
        }, 1000);
    }

    /* ---------- stage 3: declaration ---------- */

    // The UI language wins over the applicant's stored preference: whichever version is on screen
    // is the one being read, and Declaration_Language__c has to record what was actually accepted.
    loadDeclaration() {
        this.declarationFailed = false;
        this.readProgress = 0;
        const generation = this.sessionGeneration;
        getDeclaration({ language: this.lang })
            .then((declaration) => {
                if (!this.isCurrent(generation)) {
                    return;
                }
                this.declaration = declaration;
            })
            .catch((error) => {
                if (!this.isCurrent(generation)) {
                    return;
                }
                // Without the flag the screen shows a heading, an error and no way off it.
                // getDeclaration is cacheable, so a transient failure can otherwise persist.
                this.declarationFailed = true;
                this.errorMessage = this.messageOf(error);
            });
    }

    /** One button, two screens: retrying on the signing screen has to re-fetch the deed, or that
     *  screen retries the declaration forever and never loads the text it is gating. */
    handleRetryDeclaration() {
        this.errorMessage = '';
        if (this.isUndertaking) {
            this.loadUndertaking();
        } else {
            this.loadDeclaration();
        }
    }

    // Acceptance unlocks only once the text has actually been scrolled to the end. A government
    // declaration that can be accepted without being seen is not evidence of anything.
    handleDeclarationScroll(event) {
        const el = event.target;
        this.trackProgress(el);
        if (this.declarationRead) {
            return;
        }
        if (el.scrollTop + el.clientHeight >= el.scrollHeight - 24) {
            this.declarationRead = true;
            this.revealAccept();
        }
    }

    /** Publishes --exploration-banner-h measured from the rendered strip - the wording wraps
     *  on a phone, so a constant would be wrong. */
    publishNoticeHeight() {
        const strip = this.template.querySelector('.exploration-banner');
        const h = strip ? Math.ceil(strip.getBoundingClientRect().height) : 0;
        // Only on change. Assigning re-renders, which calls this again, so the guard is what stops
        // it looping rather than what stops a redundant write.
        if (this.noticeHeight !== h) {
            this.noticeHeight = h;
        }
    }

    /** Re-measures when the strip resizes without a re-render - a late font swap re-wraps the
     *  wording and a stale height leaves a white gap between the notice and the map. */
    watchNoticeHeight() {
        const strip = this.template.querySelector('.exploration-banner');
        if (strip === this.observedNotice) {
            return;
        }
        if (!this.noticeObserver) {
            this.noticeObserver = new ResizeObserver(() => this.publishNoticeHeight());
        }
        this.noticeObserver.disconnect();
        this.observedNotice = strip;
        if (strip) {
            this.noticeObserver.observe(strip);
        }
    }

    /* The muted attribute only sets a default on parser-built elements; LWC scripts this one,
       so the live property stays false and phones refuse the unmuted autoplay. */
    nudgeHeroVideo() {
        const v = this.template.querySelector('.hero-video');
        if (!v || v === this.nudgedHeroVideo) {
            return;
        }
        this.nudgedHeroVideo = v;
        v.defaultMuted = true;
        v.muted = true;
        const attempt = () => v.play().catch(() => {});
        attempt();
        // Low Power Mode blocks even muted autoplay; the first touch anywhere starts the film.
        window.addEventListener('pointerdown', attempt, { once: true, passive: true });
    }

    renderedCallback() {
        this.manageFocus();
        this.syncSlideshow();
        this.publishNoticeHeight();
        this.watchNoticeHeight();
        this.nudgeHeroVideo();

        // A body too short to overflow fires no scroll event, so the gate must resolve here or
        // Accept stays disabled forever. Covers both scroll-gated bodies.
        const gated = this.isUndertaking ? !this.undertakingRead : !this.declarationRead;
        if (!gated) {
            return;
        }
        const box = this.template.querySelector('.declaration');
        if (box && box.scrollHeight <= box.clientHeight + 24) {
            this.readProgress = 100;
            if (this.isUndertaking) {
                this.undertakingRead = true;
            } else {
                this.declarationRead = true;
            }
        }
    }

    /** The unlocked button may be below the fold with nothing to say so; bring it into view. */
    revealAccept() {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        requestAnimationFrame(() => {
            const cta = this.template.querySelector('.cta');
            if (cta && cta.scrollIntoView) {
                cta.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
            }
        });
    }

    handleAccept() {
        this.busy = true;
        this.errorMessage = '';
        const generation = this.sessionGeneration;
        acceptDeclaration({ token: this.sessionToken, language: this.declaration.language })
            .then((session) => {
                // An idle lock can fire while this is in flight; landing afterwards would mount
                // the map with no token and render an empty card.
                if (!this.isCurrent(generation)) {
                    return;
                }
                this.session = { ...session, token: this.sessionToken };
                // Not straight to the map: a customer holding a villa belongs on their own
                // screen. Same routing resumeInto uses.
                this.routeAfterDeclaration();
            })
            .catch((error) => {
                this.errorMessage = this.messageOf(error);
            })
            .finally(() => {
                this.busy = false;
            });
    }

    /** Where a customer belongs once the declaration is behind them: their villa, or the map. */
    routeAfterDeclaration() {
        this.stage = STAGE_MAP;
        const generation = this.sessionGeneration;
        reserveCurrent({ token: this.sessionToken })
            .then((reservation) => {
                if (!this.isCurrent(generation) || !reservation) {
                    return;
                }
                this.reservation = reservation;
                this.paymentMethod = reservation.paymentMethod || this.paymentMethod;
                this.routeReservation();
            })
            .catch(() => {
                // The map is a safe landing. Their villa is still held server side and the next
                // resume will find it.
                this.showMapNotice(t(this.lang, 'MSG_GENERIC'));
            });
    }

    /** Maps MSG_* codes to labels, bridges the shared VerificationService's English sentences,
     *  and falls back to the generic message rather than leaking prose or a stack trace. */
    messageOf(error) {
        const raw =
            (error && error.body && error.body.message) || (error && error.message) || '';
        const code = String(raw).trim();
        if (code.indexOf('MSG_') === 0) {
            return t(this.lang, code);
        }
        const shared = {
            'Please wait before requesting another verification code.': 'MSG_OTP_TOO_SOON',
            'Maximum resend count reached.': 'MSG_OTP_MAX_RESEND',
            'Verification request expired.': 'MSG_SESSION_EXPIRED',
            'Verification request is not pending.': 'MSG_SESSION_EXPIRED'
        };
        // hasOwnProperty, not truthiness: an error message named "toString" or "constructor"
        // would return an inherited function.
        if (Object.prototype.hasOwnProperty.call(shared, code)) {
            return t(this.lang, shared[code]);
        }
        return t(this.lang, 'MSG_GENERIC');
    }
}