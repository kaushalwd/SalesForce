import { LightningElement, api } from 'lwc';

/**
 * Aurelix IT - the portal's one loader. A blocking overlay carrying the Modon O.
 *
 * Owns no state and starts no timers, so mounting and unmounting it is the whole
 * API: render it on whatever busy flag the host already keeps.
 */
export default class Mbpr_loader extends LightningElement {
    /* Optional. A long wait should say what it is doing; a short one is better
       with nothing, since a label that flashes for 200ms is noise. */
    @api label;

    /* Fills its nearest positioned ancestor instead of the viewport. Use it for
       one box that is still filling in; the host must be position: relative. */
    @api contained = false;

    /* Like contained, but a translucent scrim instead of an opaque surface: the
       box already has content and is briefly busy (a file upload or delete
       inside a form step), so dim it rather than hide it. Host must be
       position: relative. */
    @api veil = false;

    get loaderClass() {
        if (this.veil) return 'loader loader--veil';
        return this.contained ? 'loader loader--contained' : 'loader';
    }
}