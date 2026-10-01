/**
 * eoiHero — full-bleed hero panel for EOI microsites.
 * Brand-agnostic: every image and line of copy arrives via @api.
 * MEOI-HERO (12 Sep 2026): layout="project" renders the modon.com project-page hero (stacked logo,
 * heading, tagline and a white uppercase button, bottom-left) that the Wadeem Gardens landing page
 * uses; the default layout (logo top-centre, button bottom-centre) is unchanged for the ADIB site.
 * heroImageMobile, when set, is served on portrait viewports through <picture>.
 * @author Aurelix
 */
import { LightningElement, api } from 'lwc';

export default class EoiHero extends LightningElement {
    @api modonLogoImage = ''; // MEOI-MODON: header logo in the project layout
    @api heroImage = '';
    @api heroImageMobile = ''; // MEOI-HERO
    @api heroAlt = '';
    @api title = ''; // MEOI-HERO: heading under the logo (project layout)
    @api layout = ''; // MEOI-HERO: '' (centred) | 'project'
    @api logoImage = '';
    @api logoAlt = '';
    @api tagline = '';
    @api ctaLine = '';
    @api buttonLabel = 'Begin';

    get hasHeroImage() {
        return !!this.heroImage;
    }
    get hasModonLogo() {
        return !!this.modonLogoImage;
    }
    /* MEOI-MODON: the project layout uses the landing page's lighter scrim, not the pine tint */
    get tintClass() {
        return this.isProject ? 'hero__tint hero__tint--project' : 'hero__tint';
    }
    get hasHeroMobile() {
        return !!this.heroImageMobile;
    }
    get hasTitle() {
        return !!this.title;
    }
    get isProject() {
        return this.layout === 'project';
    }
    get isCentred() {
        return this.layout !== 'project';
    }
    get hasLogo() {
        return !!this.logoImage;
    }
    get hasTagline() {
        return !!this.tagline;
    }
    get hasCtaLine() {
        return !!this.ctaLine;
    }

    handleBegin() {
        this.dispatchEvent(new CustomEvent('begin'));
    }
}