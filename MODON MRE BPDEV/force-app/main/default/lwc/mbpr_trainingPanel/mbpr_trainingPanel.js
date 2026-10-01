/**
 * mbpr_trainingPanel - the contents of the broker portal's Training drawer.
 *
 * One video, whose address is held in the custom label MBPR_Training_Video_URL
 * so the business can change it in Setup without a release. The panel reads no
 * records and calls no Apex.
 *
 * Nothing is fetched until the broker presses play, so opening the drawer costs
 * nothing. Every outcome is drawn: no address configured, an address we cannot
 * play here, and the video itself.
 *
 * Version  Author      Date         Detail
 * 1.0      Aurelix IT  10 Sep 2026  BP-nnn. New panel.
 */
import { LightningElement } from 'lwc';
import TRAINING_VIDEO_URL from '@salesforce/label/c.MBPR_Training_Video_URL';

/* Hosts we know how to turn into a player. Anything else that is a well-formed
   https address is still framed, so the business is not boxed in to two
   suppliers; a host the site does not trust lands on the "cannot play here"
   line rather than an empty black box. */
const YOUTUBE = /^(?:https?:\/\/)?(?:www\.|m\.)?(?:youtube(?:-nocookie)?\.com\/(?:watch\?(?:[^#]*&)?v=|embed\/|shorts\/|live\/)|youtu\.be\/)([A-Za-z0-9_-]{6,})/i;
const VIMEO = /^(?:https?:\/\/)?(?:www\.)?(?:vimeo\.com\/(?:video\/)?|player\.vimeo\.com\/video\/)(\d{6,})/i;
const VIDEO_FILE = /\.(?:mp4|m4v|webm|ogv|ogg|mov)$/i;
/* Same-origin Salesforce media: a file served by Shepherd, a static resource,
   or a site asset. These play in a native <video>, no trusted site needed. */
const SALESFORCE_PATH = /^\/(?:sfc\/|sfsites\/|servlet\/|resource\/|file-asset\/)/i;

/* A frame the site refuses never fires load. Long enough that a slow network is
   not mistaken for a refusal, short enough that the broker is not left staring. */
const FRAME_TIMEOUT_MS = 2500;

/**
 * Turns whatever the label holds into something playable, or null.
 * @param {string} raw the label's value
 * @returns {{kind: string, src: string, open: string}|null}
 */
function parseSource(raw) {
    const url = String(raw || '').trim();
    if (!url) return null;

    /* Same-origin path: only the Salesforce media routes, so a stray value like
       "/lightning/setup" is treated as unset rather than framed. */
    if (url.charAt(0) === '/') {
        return SALESFORCE_PATH.test(url) ? { kind: 'file', src: url, open: url } : null;
    }

    /* http would be blocked as mixed content on the portal's https origin, so it
       is refused here instead of failing silently in the browser. */
    if (!/^https:\/\//i.test(url)) return null;

    const youtube = url.match(YOUTUBE);
    if (youtube) {
        return {
            kind: 'frame',
            src: `https://www.youtube.com/embed/${youtube[1]}?autoplay=1&rel=0&modestbranding=1&playsinline=1`,
            open: `https://www.youtube.com/watch?v=${youtube[1]}`,
            /* The video's own still. maxres is the 16:9 one but is not minted for
               every upload, so handlePosterError steps down to hq, which always
               exists, and then gives up to a plain ground. */
            posters: [
                `https://i.ytimg.com/vi/${youtube[1]}/maxresdefault.jpg`,
                `https://i.ytimg.com/vi/${youtube[1]}/hqdefault.jpg`
            ]
        };
    }

    const vimeo = url.match(VIMEO);
    if (vimeo) {
        return {
            kind: 'frame',
            src: `https://player.vimeo.com/video/${vimeo[1]}?autoplay=1`,
            open: `https://vimeo.com/${vimeo[1]}`
        };
    }

    if (VIDEO_FILE.test(url.split('?')[0].split('#')[0])) {
        return { kind: 'file', src: url, open: url };
    }

    return { kind: 'frame', src: url, open: url };
}

/* The label is a compile-time constant, so this is resolved once per page. */
const SOURCE = parseSource(TRAINING_VIDEO_URL);

export default class MbprTrainingPanel extends LightningElement {
    playing = false;
    mediaFailed = false;
    maximised = false;
    posterIndex = 0;

    _frameTimer = null;

    disconnectedCallback() {
        this.clearFrameTimer();
    }

    get hasVideo() {
        return SOURCE !== null;
    }

    get isFrame() {
        return this.playing && !this.mediaFailed && Boolean(SOURCE) && SOURCE.kind === 'frame';
    }

    get isFile() {
        return this.playing && !this.mediaFailed && Boolean(SOURCE) && SOURCE.kind === 'file';
    }

    get showPoster() {
        return !this.isFrame && !this.isFile;
    }

    /* The still only exists for a host that publishes one. Everything else keeps
       the plain ground behind the play control - never an invented picture. */
    get posterSrc() {
        const posters = SOURCE && SOURCE.posters ? SOURCE.posters : null;
        return posters && this.posterIndex < posters.length ? posters[this.posterIndex] : '';
    }

    get hasPoster() {
        return Boolean(this.posterSrc);
    }

    get playerClass() {
        return this.maximised ? 'player player--max' : 'player';
    }

    get mediaSrc() {
        return SOURCE ? SOURCE.src : '';
    }

    get openUrl() {
        return SOURCE ? SOURCE.open : '';
    }

    /* Hidden on the client's word, 10 Sep 2026: "just hide the enlarged button
       for now". Nothing else is touched - the control, its layer and its tests
       are all intact, so bringing it back is this one line going back to
       `return this.hasVideo;` and nothing more. */
    get showEnlarge() {
        return false;
    }

    handlePlay() {
        if (!this.hasVideo) return;
        this.mediaFailed = false;
        this.playing = true;
        if (SOURCE.kind === 'frame') this.startFrameWatch();
    }

    /* A still that 404s or is refused steps down to the next one, then to the
       plain ground. It never leaves a broken image in the drawer. */
    handlePosterError() {
        this.posterIndex += 1;
    }

    /* Browser fullscreen first, because it escapes the drawer entirely. The
       portal reports it unavailable in some contexts, so the same click falls
       back to our own layer - the control is never drawn dead. The player
       element itself is what grows, so the video is never torn down and never
       restarts. */
    handleEnlarge() {
        if (!this.playing) this.handlePlay();
        const host = this.template.querySelector('.player');
        const request = host && (host.requestFullscreen || host.webkitRequestFullscreen);
        if (request) {
            try {
                const pending = request.call(host);
                if (pending && typeof pending.catch === 'function') {
                    pending.catch(() => {
                        this.maximised = true;
                    });
                }
                return;
            } catch (error) {
                /* fall through to our own layer */
            }
        }
        this.maximised = true;
    }

    handleMinimise() {
        this.maximised = false;
        const doc = document;
        const exit = doc.exitFullscreen || doc.webkitExitFullscreen;
        if (exit && (doc.fullscreenElement || doc.webkitFullscreenElement)) {
            try {
                const pending = exit.call(doc);
                if (pending && typeof pending.catch === 'function') pending.catch(() => {});
            } catch (error) {
                /* nothing to exit */
            }
        }
    }

    handleMaxKeydown(event) {
        if (event.key === 'Escape') {
            event.stopPropagation();
            this.handleMinimise();
        }
    }

    /* A plain button rather than a link: the site's global anchor styling wins
       over component CSS under synthetic shadow and painted the label dark on
       the dark drawer. */
    handleOpenInNewTab() {
        if (!this.openUrl) return;
        window.open(this.openUrl, '_blank', 'noopener,noreferrer');
    }

    handleFrameLoad() {
        this.clearFrameTimer();
        this.mediaFailed = false;
    }

    /* A file the browser cannot fetch or decode, and the frame timeout, land in
       the same place: back on the poster, with the line offering the new tab. */
    handleMediaError() {
        this.clearFrameTimer();
        this.playing = false;
        this.mediaFailed = true;
    }

    startFrameWatch() {
        this.clearFrameTimer();
        this._frameTimer = setTimeout(() => {
            this._frameTimer = null;
            this.playing = false;
            this.mediaFailed = true;
        }, FRAME_TIMEOUT_MS);
    }

    clearFrameTimer() {
        if (!this._frameTimer) return;
        clearTimeout(this._frameTimer);
        this._frameTimer = null;
    }
}