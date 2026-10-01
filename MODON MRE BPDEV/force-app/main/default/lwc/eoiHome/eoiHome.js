/**
 * eoiHome — landing page shell for EOI microsites.
 * Composes eoiHero + eoiFooter; every brand value (images, copy, target
 * URL) is configured on the site page in Experience Builder, never here.
 * @author Aurelix
 */
import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class EoiHome extends NavigationMixin(LightningElement) {
    @api modonLogoImage = ''; // MEOI-MODON: header logo (project layout)
    @api heroImage = '';
    @api heroImageMobile = ''; // MEOI-HERO: portrait render for portrait viewports
    @api heroAlt = '';
    @api title = ''; // MEOI-HERO: heading under the logo (project layout only)
    @api heroLayout = ''; // MEOI-HERO: '' = logo top-centre / button bottom-centre; 'project' = modon.com project-page hero
    @api logoImage = '';
    @api logoAlt = '';
    @api tagline = '';
    @api ctaLine = '';
    @api buttonLabel = 'Begin';
    @api beginUrl = '/register-interest';
    @api copyrightText = '© 2026 Modon. All rights reserved.';

    handleBegin() {
        const url = this.beginUrl;
        if (!url) {
            return;
        }
        try {
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: { url }
            });
        } catch (e) {
            window.location.assign(url);
        }
    }
}