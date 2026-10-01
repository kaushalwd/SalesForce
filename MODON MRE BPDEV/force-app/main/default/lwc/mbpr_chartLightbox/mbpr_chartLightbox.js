import { LightningElement, api } from 'lwc';

/**
 * Enlarge shell for the chart cards: a fixed scrim and a centred panel that
 * slots an enlarged copy of a chart. The host owns what renders inside.
 * Scroll lock, focus trap and Escape handling mirror mbpr_detailDrawer.
 */
export default class Mbpr_chartLightbox extends LightningElement {
    @api open = false;
    @api title;
    @api eyebrow;
    @api subtitle;
    @api closeLabel = 'Close enlarged chart';

    _previousFocus = null;
    _focusedOnOpen = false;
    _screenshotBusy = false;

    renderedCallback() {
        if (this.open && !this._focusedOnOpen) {
            this._focusedOnOpen = true;
            this.lockScroll();
            this._previousFocus = document.activeElement;
            const close = this.template.querySelector('.lightbox__close');
            if (close) {
                close.focus();
            }
        } else if (!this.open && this._focusedOnOpen) {
            this._focusedOnOpen = false;
            this.unlockScroll();
            this.restoreFocus();
        }
    }

    disconnectedCallback() {
        if (this._focusedOnOpen) {
            this._focusedOnOpen = false;
            this.unlockScroll();
        }
    }

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    /* Desktop only. One getDisplayMedia frame onto a canvas, saved as PNG.
       Chromium crops to the popup via Region Capture; elsewhere we crop
       manually when the surface is clearly this tab, otherwise save the
       full frame. Needs a user gesture and the browser picker. */
    get screenshotSupported() {
        return Boolean(
            typeof navigator !== 'undefined' &&
                navigator.mediaDevices &&
                navigator.mediaDevices.getDisplayMedia
        );
    }

    async handleScreenshot() {
        if (this._screenshotBusy || !this.screenshotSupported) return;
        this._screenshotBusy = true;
        let stream = null;
        const video = document.createElement('video');
        try {
            stream = await navigator.mediaDevices.getDisplayMedia({
                audio: false,
                video: { displaySurface: 'browser' },
                // Chromium extras; other browsers ignore unknown members.
                preferCurrentTab: true,
                selfBrowserSurface: 'include',
                surfaceSwitching: 'exclude'
            });
            const track = stream.getVideoTracks()[0];
            const panel = this.template.querySelector('.lightbox');

            let regionCropped = false;
            if (
                panel &&
                typeof window.CropTarget !== 'undefined' &&
                typeof window.CropTarget.fromElement === 'function' &&
                track &&
                typeof track.cropTo === 'function'
            ) {
                try {
                    const target = await window.CropTarget.fromElement(panel);
                    await track.cropTo(target);
                    regionCropped = true;
                } catch (cropError) {
                    regionCropped = false;
                }
            }

            video.srcObject = stream;
            video.muted = true;
            await video.play();
            // Let real frames arrive before sampling.
            await new Promise((resolve) => setTimeout(resolve, 350));

            const width = video.videoWidth;
            const height = video.videoHeight;
            if (!width || !height) throw new Error('No frame captured.');

            let sx = 0;
            let sy = 0;
            let sw = width;
            let sh = height;
            if (!regionCropped && panel) {
                const scaleX = width / window.innerWidth;
                const scaleY = height / window.innerHeight;
                if (Math.abs(scaleX - scaleY) < 0.02) {
                    const rect = panel.getBoundingClientRect();
                    sx = Math.max(0, Math.floor(rect.left * scaleX));
                    sy = Math.max(0, Math.floor(rect.top * scaleY));
                    sw = Math.max(1, Math.min(width - sx, Math.ceil(rect.width * scaleX)));
                    sh = Math.max(1, Math.min(height - sy, Math.ceil(rect.height * scaleY)));
                }
            }

            const canvas = document.createElement('canvas');
            canvas.width = sw;
            canvas.height = sh;
            canvas.getContext('2d').drawImage(video, sx, sy, sw, sh, 0, 0, sw, sh);

            const slug =
                String(this.title || 'chart')
                    .trim()
                    .replace(/[^\w-]+/g, '-')
                    .replace(/^-+|-+$/g, '') || 'chart';
            const link = document.createElement('a');
            link.href = canvas.toDataURL('image/png');
            link.download = `${slug}-${new Date().toISOString().slice(0, 10)}.png`;
            link.style.display = 'none';
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);
        } catch (error) {
            // Picker dismissed or capture blocked.
        } finally {
            try {
                video.pause();
                video.srcObject = null;
            } catch (cleanupError) {
                // ignore
            }
            if (stream) {
                stream.getTracks().forEach((track) => track.stop());
            }
            this._screenshotBusy = false;
        }
    }

    handleOverlayClick() {
        this.handleClose();
    }

    stopPropagation(event) {
        event.stopPropagation();
    }

    handleKeydown(event) {
        if (event.key === 'Escape') {
            event.preventDefault();
            // Never let the workspace modal behind see this Escape.
            event.stopPropagation();
            this.handleClose();
            return;
        }
        if (event.key !== 'Tab') {
            return;
        }
        const focusable = this.getFocusable();
        if (!focusable.length) {
            return;
        }
        const first = focusable[0];
        const last = focusable[focusable.length - 1];
        const active = this.template.activeElement || document.activeElement;
        if (event.shiftKey && active === first) {
            event.preventDefault();
            last.focus();
        } else if (!event.shiftKey && active === last) {
            event.preventDefault();
            first.focus();
        }
    }

    getFocusable() {
        const selector =
            'a[href], button:not([disabled]), textarea:not([disabled]), input:not([disabled]), select:not([disabled]), [tabindex]:not([tabindex="-1"])';
        const own = Array.from(this.template.querySelectorAll(selector));
        const slot = this.template.querySelector('slot');
        if (slot) {
            slot.assignedElements({ flatten: true }).forEach((el) => {
                if (el.matches && el.matches(selector)) {
                    own.push(el);
                }
                if (el.querySelectorAll) {
                    own.push(...el.querySelectorAll(selector));
                }
            });
        }
        return own;
    }

    restoreFocus() {
        const target = this._previousFocus;
        this._previousFocus = null;
        if (target && typeof target.focus === 'function') {
            try {
                target.focus();
            } catch (error) {
                // Opener was removed from the DOM.
            }
        }
    }

    /* Ref-counted so nested overlays cooperate. Shared with the modal and
       drawer shells. */
    lockScroll() {
        const body = document.body;
        const count = Number(body.dataset.mbprScrollLocks || 0);
        if (count === 0) {
            body.dataset.mbprPreviousOverflow = body.style.overflow || '';
            body.style.overflow = 'hidden';
        }
        body.dataset.mbprScrollLocks = String(count + 1);
    }

    unlockScroll() {
        const body = document.body;
        const count = Number(body.dataset.mbprScrollLocks || 0);
        if (count <= 1) {
            body.style.overflow = body.dataset.mbprPreviousOverflow || '';
            delete body.dataset.mbprScrollLocks;
            delete body.dataset.mbprPreviousOverflow;
        } else {
            body.dataset.mbprScrollLocks = String(count - 1);
        }
    }
}