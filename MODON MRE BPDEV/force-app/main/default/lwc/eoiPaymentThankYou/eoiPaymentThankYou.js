/**
 * eoiPaymentThankYou — the screen a customer lands on after paying a Modon
 * Checkout payment link (broker portal or sales console). It is NOT part of the
 * registration journey: that customer never used this site and has no session
 * here, so nothing is read, fetched or remembered. The page is deliberately
 * stateless — the same words for every visitor, whatever the URL carries.
 *
 * Every string and image arrives as a page property, so a second site (ADIB)
 * can reuse the component with its own brand and no code change.
 * @author Aurelix
 */
import { LightningElement, api } from 'lwc';

export default class EoiPaymentThankYou extends LightningElement {
    @api modonLogoImage = ''; // MEOI-MODON
    @api posterImage = '';
    @api posterAlt = '';
    @api logoImage = '';
    @api logoAlt = '';
    @api eyebrow = 'Expression of Interest';
    @api heading = 'Thank you';
    @api message = 'Your payment was successful and your interest is registered.';
    @api copyrightText = '© 2026 Modon. All rights reserved.';

    /* Each part renders only when its property is set, so an unconfigured page
       shows a clean screen instead of a broken image or an empty line. */
    get hasModonLogo() {
        return !!this.modonLogoImage;
    }
    /* MEOI-MODON: with MODON's logo the page uses the landing page's lighter scrim and no contour lines */
    get scrimClass() {
        return this.hasModonLogo ? 'page__scrim page__scrim--light' : 'page__scrim';
    }
    get hasPoster() {
        return Boolean(this.posterImage);
    }

    get hasLogo() {
        return Boolean(this.logoImage);
    }

    get hasEyebrow() {
        return Boolean(this.eyebrow);
    }

    get hasHeading() {
        return Boolean(this.heading);
    }

    get hasMessage() {
        return Boolean(this.message);
    }

    get hasCopyright() {
        return Boolean(this.copyrightText);
    }
}