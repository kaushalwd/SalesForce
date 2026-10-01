/**
 * eoiSplitPage — journey shell for EOI microsite steps: brand panel
 * (client render under a pine tint + shoreline contour + lockup) beside the one content
 * measure, shared footer. Mobile: top bar; tablet: brand band; desktop:
 * 60/40 split. Brand-agnostic — all copy and imagery via properties.
 * @author Aurelix
 */
import { LightningElement, api } from 'lwc';

export default class EoiSplitPage extends LightningElement {
    @api modonLogoImage = ''; // MEOI-MODON: blank = no MODON logo (the ADIB site)
    @api posterImage = '';
    @api posterAlt = '';
    @api logoImage = '';
    @api logoAlt = '';
    @api tagline = '';
    @api caption = '';
    @api wordmark = '';
    @api wordmarkSub = '';
    @api copyrightText = '© 2026 Modon. All rights reserved.';

    get hasModonLogo() {
        return !!this.modonLogoImage;
    }
    /* MEOI-MODON: with MODON's logo the panel also drops its tint and contour lines (the "overlay"
       MODON asked to remove) - the ADIB site, which sets no MODON logo, keeps its look. */
    get brandClass() {
        return this.hasModonLogo ? 'brand brand--modon' : 'brand';
    }
    get hasPoster() {
        return !!this.posterImage;
    }
    get hasLogo() {
        return !!this.logoImage;
    }
    get hasWordmark() {
        return !!this.wordmark;
    }
    get hasTagline() {
        return !!this.tagline;
    }
    get hasCaption() {
        return !!this.caption;
    }
}