import { LightningElement } from 'lwc';
import getStatus from '@salesforce/apex/MBP_LaunchCurtainController.getStatus';
import TERMS_URL from '@salesforce/label/c.MBP_TermsandConditions';
import PRIVACY_URL from '@salesforce/label/c.MBP_privacypol';

/*
 * Broker Portal launch curtain.
 *
 * Drop one on every page in Experience Builder. It renders nothing unless
 * MBP_LaunchCurtainController says the running user should see the curtain,
 * then paints a full-viewport countdown over the page.
 *
 * Rules, in the order they matter on go-live day:
 * - No flash of the portal. The last server answer is remembered on the device
 *   and acted on before the server is asked again: remembered "on" draws the
 *   curtain at once, remembered "off" draws nothing, and a device with no
 *   memory draws the plain dark ground until the server answers.
 * - Fails open. Until the server has answered once on this page, any error
 *   lifts whatever was drawn, and the plain ground lifts itself after
 *   COVER_MAX_MS, so a fault can never black out a live portal. Once the
 *   server has confirmed the curtain, a failed re-check keeps it up rather
 *   than lifting it on a network blip.
 * - The switch decides, not the clock. Re-checked every minute so unticking
 *   Curtain On reaches open tabs without a reload. The countdown reaching zero
 *   only changes the message to "Opening shortly".
 * - Counts on server time. The browser clock is corrected by the offset from
 *   serverNowMs, so a wrong device clock cannot show the wrong countdown.
 */

const POLL_MS = 60000;
const TICK_MS = 250;
const FLIP_SETTLE_MS = 640;
const COVER_MAX_MS = 3000;
const MEMORY_KEY = 'mbpr.launchCurtain.v1';
const MAX_REMEMBERED_OFFSET_MS = 86400000;
const GST_TIME_ZONE = 'Asia/Dubai';
const GST_OFFSET_MINUTES = 240;

const MODE_COUNTDOWN = 'countdown';
const MODE_NO_DATE = 'nodate';
const MODE_OPENING = 'opening';

function pad(n) {
    return n < 10 ? '0' + n : String(n);
}

// Last server answer on this device. Any problem reading it (storage blocked,
// private mode, malformed value) means "nothing remembered".
function readMemory() {
    try {
        const raw = window.localStorage.getItem(MEMORY_KEY);
        if (!raw) return null;
        const value = JSON.parse(raw);
        if (!value || typeof value.on !== 'boolean') return null;
        const goLiveMs = typeof value.goLiveMs === 'number' && isFinite(value.goLiveMs) ? value.goLiveMs : null;
        const offsetMs =
            typeof value.offsetMs === 'number' && isFinite(value.offsetMs) && Math.abs(value.offsetMs) <= MAX_REMEMBERED_OFFSET_MS
                ? value.offsetMs
                : 0;
        return { on: value.on, goLiveMs, offsetMs };
    } catch (e) {
        return null;
    }
}

function writeMemory(on, goLiveMs, offsetMs) {
    try {
        window.localStorage.setItem(MEMORY_KEY, JSON.stringify({ on, goLiveMs, offsetMs, savedAt: Date.now() }));
    } catch (e) {
        // Storage unavailable; the next load simply starts with nothing remembered.
    }
}

// The clock sheds units as launch gets closer: days under 24h, hours under 60m.
function buildUnits(totalSeconds) {
    const d = Math.floor(totalSeconds / 86400);
    const h = Math.floor((totalSeconds % 86400) / 3600);
    const m = Math.floor((totalSeconds % 3600) / 60);
    const s = totalSeconds % 60;
    const list = [];
    if (d > 0) list.push({ key: 'd', label: d === 1 ? 'Day' : 'Days', value: pad(d), count: d, noun: 'day' });
    if (d > 0 || h > 0) list.push({ key: 'h', label: h === 1 ? 'Hour' : 'Hours', value: pad(h), count: h, noun: 'hour' });
    list.push({ key: 'm', label: m === 1 ? 'Minute' : 'Minutes', value: pad(m), count: m, noun: 'minute' });
    list.push({ key: 's', label: 'Seconds', value: pad(s), count: s, noun: 'second' });
    return list;
}

export default class MbprLaunchCurtain extends LightningElement {
    termsUrl = TERMS_URL;
    privacyUrl = PRIVACY_URL;
    year = new Date().getFullYear();

    showCurtain = false;
    showCover = false;
    hasServerAnswer = false;
    coverTimer;
    mode = MODE_COUNTDOWN;
    units = [];
    opensGst = '';
    opensLocal = '';
    timerLabel = '';

    goLiveMs = null;
    clockOffsetMs = 0;
    remainingSeconds = null;
    signature = '';
    flipSeq = 0;
    flipTimers = {};

    pollTimer;
    tickTimer;
    inFlight = false;
    hasFocused = false;
    scrollLocked = false;
    previousBodyOverflow = '';
    reduceMotion = false;

    boundFocusIn = this.handleDocumentFocusIn.bind(this);

    get isCountdown() {
        return this.mode === MODE_COUNTDOWN;
    }

    get isNoDate() {
        return this.mode === MODE_NO_DATE;
    }

    get isOpening() {
        return this.mode === MODE_OPENING;
    }

    connectedCallback() {
        try {
            this.reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
        } catch (e) {
            this.reduceMotion = false;
        }

        // Decide from memory before the first render, so the page underneath is
        // never painted uncovered while the server is being asked.
        const memory = readMemory();
        if (memory && memory.on) {
            this.clockOffsetMs = memory.offsetMs;
            this.goLiveMs = memory.goLiveMs;
            this.formatOpens();
            this.show();
        } else if (!memory) {
            this.showCover = true;
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            this.coverTimer = setTimeout(() => {
                if (!this.hasServerAnswer) this.clearCover();
            }, COVER_MAX_MS);
        }

        this.refresh();
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this.pollTimer = setInterval(() => this.refresh(), POLL_MS);
    }

    disconnectedCallback() {
        clearInterval(this.pollTimer);
        this.clearCover();
        this.hide();
    }

    renderedCallback() {
        if (this.showCurtain && !this.hasFocused) {
            const screen = this.template.querySelector('section.screen');
            if (screen) {
                screen.focus();
                this.hasFocused = true;
            }
        }
    }

    async refresh() {
        if (this.inFlight) return;
        this.inFlight = true;
        try {
            const status = await getStatus();
            const receivedAt = Date.now();
            this.hasServerAnswer = true;
            this.clearCover();
            if (!status || status.showCurtain !== true) {
                writeMemory(false, null, 0);
                this.hide();
                return;
            }
            this.clockOffsetMs = typeof status.serverNowMs === 'number' ? status.serverNowMs - receivedAt : 0;
            const nextGoLive = typeof status.goLiveMs === 'number' ? status.goLiveMs : null;
            if (nextGoLive !== this.goLiveMs) {
                this.goLiveMs = nextGoLive;
                this.remainingSeconds = null;
                this.formatOpens();
            }
            writeMemory(true, this.goLiveMs, this.clockOffsetMs);
            this.show();
        } catch (error) {
            // Until the server has answered once on this page, fail open: lift the
            // plain ground and any curtain drawn from memory. After a confirmed
            // "curtain", a failed re-check keeps it up. Memory is never written here.
            if (!this.hasServerAnswer) {
                this.clearCover();
                this.hide();
            }
        } finally {
            this.inFlight = false;
        }
    }

    // The plain dark ground drawn while a device with no memory waits for the
    // server. It neither locks scrolling nor traps focus; it lasts at most COVER_MAX_MS.
    clearCover() {
        clearTimeout(this.coverTimer);
        this.coverTimer = null;
        this.showCover = false;
    }

    show() {
        this.clearCover();
        if (!this.showCurtain) {
            this.showCurtain = true;
            this.hasFocused = false;
            this.lockPage();
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            this.tickTimer = setInterval(() => this.tick(), TICK_MS);
        }
        this.tick();
    }

    hide() {
        clearInterval(this.tickTimer);
        this.tickTimer = null;
        this.clearFlipTimers();
        this.unlockPage();
        this.showCurtain = false;
        this.units = [];
        this.signature = '';
        this.remainingSeconds = null;
    }

    tick() {
        if (this.goLiveMs === null) {
            this.mode = MODE_NO_DATE;
            return;
        }
        const now = Date.now() + this.clockOffsetMs;
        const seconds = Math.max(0, Math.ceil((this.goLiveMs - now) / 1000));
        if (seconds === 0) {
            if (this.mode !== MODE_OPENING) {
                this.mode = MODE_OPENING;
                this.clearFlipTimers();
                this.units = [];
                this.signature = '';
                this.remainingSeconds = 0;
            }
            return;
        }
        this.mode = MODE_COUNTDOWN;
        if (seconds === this.remainingSeconds) return;
        this.remainingSeconds = seconds;
        this.applyUnits(buildUnits(seconds));
    }

    applyUnits(next) {
        this.timerLabel = next
            .filter((u) => u.key !== 's')
            .map((u) => `${u.count} ${u.noun}${u.count === 1 ? '' : 's'}`)
            .join(' ') + ' remaining';

        const signature = next.map((u) => u.key).join('');
        if (signature !== this.signature || this.units.length !== next.length) {
            this.clearFlipTimers();
            this.signature = signature;
            this.units = next.map((u, index) => this.decorate(u, index, u.value, []));
            return;
        }

        this.units = this.units.map((current, index) => {
            const incoming = next[index];
            if (current.value === incoming.value) {
                return current.label === incoming.label ? current : { ...current, label: incoming.label };
            }
            if (this.reduceMotion) {
                return this.decorate(incoming, index, incoming.value, []);
            }
            // Top half shows the new value at once; the old top flap folds down
            // over it, then the new bottom flap lands over the old bottom half.
            this.flipSeq += 1;
            const id = this.flipSeq;
            this.scheduleSettle(incoming.key, id);
            return this.decorate(incoming, index, current.value, [
                { topKey: `t${id}`, bottomKey: `b${id}`, from: current.value, to: incoming.value }
            ]);
        });
    }

    decorate(unit, index, bottomValue, flaps) {
        return {
            key: unit.key,
            label: unit.label,
            value: unit.value,
            bottomValue,
            flaps,
            showSep: index > 0,
            unitClass: unit.key === 's' ? 'unit unit--sec' : 'unit'
        };
    }

    scheduleSettle(key, id) {
        clearTimeout(this.flipTimers[key]);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this.flipTimers[key] = setTimeout(() => {
            delete this.flipTimers[key];
            this.units = this.units.map((u) =>
                u.key === key && u.flaps.length && u.flaps[0].topKey === `t${id}`
                    ? { ...u, bottomValue: u.value, flaps: [] }
                    : u
            );
        }, FLIP_SETTLE_MS);
    }

    clearFlipTimers() {
        Object.keys(this.flipTimers).forEach((key) => clearTimeout(this.flipTimers[key]));
        this.flipTimers = {};
    }

    // "Monday 14 September, 8:00 PM GST", plus the broker's own time only when
    // their device is not already on Gulf time.
    formatOpens() {
        this.opensGst = '';
        this.opensLocal = '';
        if (this.goLiveMs === null) return;
        try {
            const at = new Date(this.goLiveMs);
            const gstDay = new Intl.DateTimeFormat('en-GB', {
                timeZone: GST_TIME_ZONE, weekday: 'long', day: 'numeric', month: 'long'
            }).format(at);
            const gstTime = new Intl.DateTimeFormat('en-US', {
                timeZone: GST_TIME_ZONE, hour: 'numeric', minute: '2-digit', hour12: true
            }).format(at);
            this.opensGst = `${gstDay}, ${gstTime} GST`;

            if (-at.getTimezoneOffset() === GST_OFFSET_MINUTES) return;

            const localTime = new Intl.DateTimeFormat('en-US', {
                hour: 'numeric', minute: '2-digit', hour12: true
            }).format(at);
            const zonePart = new Intl.DateTimeFormat(undefined, { timeZoneName: 'short' })
                .formatToParts(at)
                .find((part) => part.type === 'timeZoneName');
            const dayKey = (zone) => new Intl.DateTimeFormat('en-CA', { timeZone: zone }).format(at);
            const localZone = Intl.DateTimeFormat().resolvedOptions().timeZone;
            const sameDay = dayKey(GST_TIME_ZONE) === dayKey(localZone);
            const dayPart = sameDay ? '' : new Intl.DateTimeFormat('en-GB', { weekday: 'long' }).format(at) + ', ';
            this.opensLocal = `Your time: ${dayPart}${localTime}${zonePart ? ' ' + zonePart.value : ''}`;
        } catch (e) {
            this.opensLocal = '';
        }
    }

    // While the curtain is up the page underneath must not scroll or take focus.
    lockPage() {
        try {
            if (!this.scrollLocked) {
                this.previousBodyOverflow = document.body.style.overflow;
                document.body.style.overflow = 'hidden';
                this.scrollLocked = true;
            }
            document.addEventListener('focusin', this.boundFocusIn, true);
        } catch (e) {
            // The overlay still covers the page; locking is a nicety.
        }
    }

    unlockPage() {
        try {
            if (this.scrollLocked) {
                document.body.style.overflow = this.previousBodyOverflow;
                this.scrollLocked = false;
            }
            document.removeEventListener('focusin', this.boundFocusIn, true);
        } catch (e) {
            // Nothing to restore.
        }
    }

    handleDocumentFocusIn(event) {
        if (!this.showCurtain) return;
        // Native shadow retargets to the host; synthetic shadow passes the inner node.
        const host = this.template.host;
        if (event.target === host || (host && host.contains(event.target))) return;
        const screen = this.template.querySelector('section.screen');
        if (screen) screen.focus();
    }
}