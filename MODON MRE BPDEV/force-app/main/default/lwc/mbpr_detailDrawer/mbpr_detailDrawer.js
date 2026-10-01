import { LightningElement, api } from 'lwc';

export default class MbprDetailDrawer extends LightningElement {
    @api open = false;
    @api title = 'Details';
    @api eyebrow = '';
    @api subtitle = '';
    @api closeLabel = 'Close panel';
    @api size = 'standard';
    @api tone = 'default';
    @api variant = '';

    _focusedOnOpen = false;
    _previousFocus = null;
    _scrollLocked = false;

    renderedCallback() {
        if (!this.open) {
            this._focusedOnOpen = false;
            this.unlockScroll();
            this.restoreFocus();
            return;
        }

        this.lockScroll();
        if (this._focusedOnOpen) return;
        this._previousFocus = document.activeElement;
        const closeButton = this.template.querySelector('.drawer__close');
        if (closeButton) {
            closeButton.focus();
            this._focusedOnOpen = true;
        }
    }

    disconnectedCallback() {
        this.unlockScroll();
    }

    get drawerClass() {
        const classes = ['drawer', `drawer--${this.safeValue(this.size)}`, `drawer--${this.safeValue(this.tone)}`];
        if (this.isModalVariant) {
            classes.push('drawer--modal');
        }
        return classes.join(' ');
    }

    get isModalVariant() {
        return this.variant === 'modal';
    }

    get layerClass() {
        return this.isModalVariant ? 'drawer-layer drawer-layer--modal' : 'drawer-layer';
    }

    handleOverlayClick() {
        this.handleClose();
    }

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    lockScroll() {
        if (this._scrollLocked || !document.body) return;
        const count = Number(document.body.dataset.mbprScrollLocks || 0);
        if (count === 0) {
            document.body.dataset.mbprPreviousOverflow = document.body.style.overflow || '';
            document.body.style.overflow = 'hidden';
        }
        document.body.dataset.mbprScrollLocks = String(count + 1);
        this._scrollLocked = true;
    }

    unlockScroll() {
        if (!this._scrollLocked || !document.body) return;
        const count = Math.max(Number(document.body.dataset.mbprScrollLocks || 1) - 1, 0);
        if (count === 0) {
            document.body.style.overflow = document.body.dataset.mbprPreviousOverflow || '';
            delete document.body.dataset.mbprPreviousOverflow;
            delete document.body.dataset.mbprScrollLocks;
        } else {
            document.body.dataset.mbprScrollLocks = String(count);
        }
        this._scrollLocked = false;
    }

    restoreFocus() {
        const previousFocus = this._previousFocus;
        this._previousFocus = null;
        if (!previousFocus || !previousFocus.focus) return;
        try {
            previousFocus.focus();
        } catch (error) {
            // Opener may have been removed while the drawer was open.
            if (error && error.name === 'InvalidStateError') {
                return;
            }
        }
    }

    handleKeydown(event) {
        if (event.key === 'Escape') {
            event.preventDefault();
            this.handleClose();
            return;
        }

        if (event.key !== 'Tab') return;

        const focusable = this.getFocusable();
        if (!focusable.length) return;

        const first = focusable[0];
        const last = focusable[focusable.length - 1];
        const active = this.template.activeElement;

        if (event.shiftKey && active === first) {
            event.preventDefault();
            last.focus();
        } else if (!event.shiftKey && active === last) {
            event.preventDefault();
            first.focus();
        }
    }

    getFocusable() {
        const root = this.template.querySelector('.drawer');
        if (!root) return [];
        const selector = 'button, [href], input, select, textarea, iframe, [tabindex]:not([tabindex="-1"])';
        const shadowFocusable = Array.from(root.querySelectorAll(selector));
        const slottedFocusable = Array.from(this.template.querySelectorAll('slot')).flatMap((slot) =>
            slot.assignedElements({ flatten: true }).flatMap((element) => {
                const nested = Array.from(element.querySelectorAll ? element.querySelectorAll(selector) : []);
                return element.matches && element.matches(selector) ? [element, ...nested] : nested;
            })
        );
        return [...shadowFocusable, ...slottedFocusable].filter(
            (element) => !element.disabled && element.getAttribute('aria-hidden') !== 'true'
        );
    }

    stopPropagation(event) {
        event.stopPropagation();
    }

    safeValue(value) {
        return String(value || 'default').replace(/[^a-z0-9-]/gi, '').toLowerCase() || 'default';
    }
}