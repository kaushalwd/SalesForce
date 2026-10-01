/**
 * eoiWadeemGardens — Wadeem Gardens landing page (MEOI-LAND, 11 Sep 2026).
 * A faithful copy of modon.com's Hudayriyat Golf Estates project page, re-pointed at Wadeem:
 * hero image with the Wadeem logo instead of the video, "Register now" goes to the EOI site,
 * no virtual tour / brochure, no search or menu, one "Villas" block, a 4/5/6-bedroom
 * factsheet (values to be supplied by MODON), the template's amenities, map, FAQ and the
 * black terms footer. Everything below the FAQ that the template carried (register form,
 * map, footer menus) is left out on purpose. Read-only: no Apex, no data.
 * Every image and text is a page property so MODON can change it in Experience Builder.
 * MEOI-MAP (12 Sep 2026): the map is MODON's Wadeem Gardens SVG (web-optimised export, 1.2 MB;
 * the first 6 MB export would have pushed Wadeem_Landing past the 5 MB resource limit).
 * MEOI-HERO (12 Sep 2026, Mridul's reference screenshot): the hero is MODON's terrace render
 * (desktop 1920x1080, a portrait 1080x1920 render on portrait viewports via <picture>), the
 * stacked white lockup at 160px, the "Wadeem Gardens" heading back on, the tagline in sentence
 * case and the template's white uppercase "REGISTER NOW" button (18px, 15x30 padding).
 * @author Aurelix
 */
import { LightningElement, api } from 'lwc';
import basePath from '@salesforce/community/basePath';
import { recaptchaFramePath } from 'c/eoiRecaptchaClient';

// EOI-UI-19: hero carousel timing, and where the text sits in MODON's 1920x1080 offer banners (x 1150-1735), as on the agreed artifact
const HERO_SLIDE_MS = 6500;
const HERO_WIPE_MS = 1200;
const HERO_TEXT_L = 1150 / 1920;
const HERO_TEXT_R = 1735 / 1920;
const HERO_TEXT_C = (HERO_TEXT_L + HERO_TEXT_R) / 2;

const ASSET_VERSION = '7'; // 7: new amenity icons (MEOI-AMEN) // 6: gallery renders (MEOI-LAND10) // MEOI-LAND4: bump when a file in Wadeem_Landing / Wadeem_Assets changes

// MODON's villa table (Wadeem_Gardens_FAQs Final, 11 Sep 2026): Unit Area; handover Q3 2031;
// payment plan and price still to be announced. Editable in Builder via factsheetJson.
// MEOI-FACTS2 (14 Sep): MODON's go-live numbers (532/630/720 sqm, 25/75, Q3 2031, launch prices); row 4 label 'Price'.
const DEFAULT_FACTSHEET = [
    { title: '4-bedroom Villas', size: '532 sqm', plan: '25/75', handover: 'Q3 2031', price: 'Starts from AED 8.7M' },
    { title: '5-bedroom Villas', size: '630 sqm', plan: '25/75', handover: 'Q3 2031', price: 'Starts from AED 10.2M' },
    { title: '6-bedroom Villas', size: '720 sqm', plan: '25/75', handover: 'Q3 2031', price: 'Starts from AED 11.6M' }
];

// MODON's Wadeem Gardens amenities (FAQ document, 11 Sep 2026). `icon` names a file in
// Wadeem_Landing/amenities/. Editable in Builder via amenitiesJson.
const AMENITIES = [
    { icon: 'waterfront-promenade', label: 'Waterfront Promenade' },
    { icon: 'retail-and-dining', label: 'Retail and Dining' },
    { icon: 'premium-medical-clinics', label: 'Premium Medical Clinics' },
    { icon: 'metro', label: 'Metro' },
    { icon: 'marina', label: 'Marina' },
    { icon: 'ice-rink', label: 'Ice Rink' },
    { icon: 'culture-and-entertainment', label: 'Culture and Entertainment' },
    { icon: 'commercial-hubs', label: 'Commercial Hubs' },
    { icon: 'arena', label: 'Arena' },
    { icon: 'airconditioned-spine', label: 'Airconditioned Spine' },
    { icon: '6-clubhouses', label: '6 Clubhouses' },
    { icon: '2-international-schools', label: '2 International Schools' }
];

// MODON's FAQs for Wadeem Gardens (FAQ document, 11 Sep 2026). Editable in Builder via faqJson.
// MEOI-FAQ2 (12 Sep 2026, Mridul): the page shows only ten of the document's 56 — Q2, Q5, Q11, Q14, Q18,
// Q21 and Q29-Q32 — in the document's order. The full list is in Backup_2026-09-12/run-2255-faq.
const FAQS = [
    { q: "Are the villas available for purchase by all nationalities?",
      a: "Our villas are available to buyers of all nationalities and are offered on a freehold basis, so you can enjoy the benefits of owning your villa with full ownership rights." },
    { q: "Is the community gated and secure?",
      a: "Wadeem Gardens is a secure, gated community with 24-hour security, offering residents peace of mind." },
    { q: "What is the number of storeys?",
      a: "All villas are G+1. Refer to the table above for further information." },
    { q: "Are pets allowed?",
      a: "Yes, pets are permitted, subject to the applicable community guidelines, rules, and regulations." },
    { q: "What are the parking arrangements?",
      a: "Four-bedroom villas have three parking bays, and five and six-bedroom villas have four parking bays. All bays are fully covered. Visitor parking is available on street throughout the community." },
    { q: "What sustainability features are included?",
      a: "The villas are designed to achieve an Estidama Pearl 3 rating, reflecting compliance with Abu Dhabi's sustainability requirements. The rating considers factors such as energy and water efficiency, resource conservation, and the overall environmental performance of the development." },
    { q: "What is the Modon and ADIB arrangement?",
      a: "Modon has partnered with ADIB to offer buyers a dedicated, Sharia-compliant home finance solution, tailored specifically for Wadeem Gardens buyers during the off-plan period, so you can secure your home with confidence and financial flexibility from day one. Enjoy exclusive financing benefits through ADIB, including zero processing fees and zero valuation fees for eligible applicants, subject to ADIB's approval and financing requirements. ADIB provides the financing and evaluates all applications, while Modon has facilitated access to these preferential terms through its collaboration with ADIB. ADIB provides the finance and assesses your application." },
    { q: "Can I finance my purchase through ADIB?",
      a: "Yes. ADIB is ready to finance your purchase, subject to their standard eligibility checks and approved credit policies, the same straightforward checks any bank would run, giving you a clear, trusted path to owning your home at Wadeem Gardens." },
    { q: "Do I have to be an existing ADIB customer to apply?",
      a: "Not at all. Whether you're a long-standing ADIB customer or exploring ADIB financing for the first time, you're equally welcome to apply." },
    { q: "Does the financing apply to all units?",
      a: "Yes, every unit at Wadeem Gardens qualifies for ADIB financing, giving you complete freedom to choose the home that's right for you." }
];

/* MEOI-LAND2 (11 Sep). The brand fonts are also declared here, on the site's own path, because
   the page now lives on a site of its own (/wadeem-gardens): a site-less /sfsites/ URL is
   redirected to the domain's default site and may not resolve for a guest there (MEOI-IMG).
   @font-face rules are document-scoped, so one injection serves the shadow tree too. */
let fontsInjected = false;
function injectFonts(site) {
    if (fontsInjected || typeof document === 'undefined') return;
    fontsInjected = true;
    const base = `${site}/sfsites/c/resource/Microsite_Fonts`;
    const style = document.createElement('style');
    style.setAttribute('data-eoi-fonts', 'wadeem-gardens');
    style.textContent =
        `@font-face{font-family:'SuisseIntl';font-style:normal;font-weight:400;font-display:swap;` +
        `src:url('${base}/SuisseIntl-Regular.woff2') format('woff2'),url('${base}/SuisseIntl-Regular.woff') format('woff')}` +
        `@font-face{font-family:'SuisseIntl';font-style:normal;font-weight:500 700;font-display:swap;` +
        `src:url('${base}/SuisseIntl-Medium.woff2') format('woff2'),url('${base}/SuisseIntl-Medium.woff') format('woff')}`;
    document.head.appendChild(style);
}

export default class EoiWadeemGardens extends LightningElement {
    @api modonLogoImage = '/sfsites/c/resource/Wadeem_Landing/modon-logo-white.svg';
    @api heroImage = '/sfsites/c/resource/Wadeem_Landing/hero-terrace.jpg'; // MEOI-HERO: MODON's terrace render, 1920x1080 (was MEOI-LAND8 hero.jpg)
    @api heroImageMobile = '/sfsites/c/resource/Wadeem_Landing/hero-terrace-mobile.jpg'; // MEOI-HERO: portrait render, 1080x1920, served on portrait viewports; blank = desktop render everywhere
    @api heroAlt = 'Wadeem Gardens terrace overlooking the district, Hudayriyat Island';
    @api logoImage = '/sfsites/c/resource/Wadeem_Assets/wadeem-gardens-logo-stacked-white.svg'; // MEOI-HERO: MODON's stacked white lockup (was the wide MEOI-LOGO lockup)
    @api logoAlt = 'Wadeem Gardens';
    @api title = ''; // MEOI-HERO3 (13 Sep, Mridul): blank again - the stacked lockup already says Wadeem Gardens, the heading repeated it
    @api tagline = 'Where everything aligns'; // MEOI-HERO: sentence case, as in the reference
    @api registerUrl = '/eoi/wadeem-register';
    @api registerLabel = 'Register Your EOI'; // MEOI-HERO: renders uppercase; label per Mridul (12 Sep), same on the EOI site
    @api introText = 'A new district on Hudayriyat Island, built around the life you want to lead. Where education, hospitality, retail, sport and entertainment are not destinations you travel between, but part of the everyday. Wadeem is where everything aligns.'; // MEOI-COPY4 (13 Sep 2026, Mridul): MODON's district paragraph, revised
    @api villasHeading = 'Everything, within reach'; // MEOI-SIDE (12 Sep, Mridul): the Villas block became MODON's district block
    @api villasText = 'Wadeem Gardens is the heart, where a 2.3 km central spine connecting a community of 35,000 residents, linking the places that shape how we live, work, move and spend our time. Here, the community is designed around the moments that make life richer, with more of what matters brought closer together.'; // MEOI-COPY4 (13 Sep 2026): the 'Everything, within reach' paragraph, revised
    @api sideImage = '/sfsites/c/resource/Wadeem_Landing/everything-in-reach.jpg'; // MEOI-SIDE: MODON's civic-centre render, 1080x600 (was the template's side-text.jpg)
    @api sideImageAlt = 'Wadeem Gardens district centre, Hudayriyat Island';
    @api factsheetJson = '';
    @api amenitiesJson = ''; // MEOI-LAND5: [{"icon":"swimming-pool","label":"Swimming Pools"}, ...]
    @api faqJson = '';       // MEOI-LAND5: [{"q":"...","a":"..."}, ...]
    @api mapImage = '/sfsites/c/resource/Wadeem_Landing/map.svg'; // MEOI-MAP: MODON's Wadeem Gardens map (web-optimised SVG)
    @api mapAlt = 'Hudayriyat Island map';
    @api galleryImages = '/sfsites/c/resource/Wadeem_Landing/gallery/01-terrace-view.jpg,/sfsites/c/resource/Wadeem_Landing/gallery/02-boulevard-promenade.jpg,/sfsites/c/resource/Wadeem_Landing/gallery/03-jogging-track.jpg,/sfsites/c/resource/Wadeem_Landing/gallery/04-indoor-atrium.jpg'; // MEOI-LAND10: MODON's four renders (11 Sep pack)
    @api assetBase = '/sfsites/c/resource/Wadeem_Landing';
    @api copyrightText = '© Modon 2026 — All rights reserved';
    @api termsUrl = 'https://www.modon.com/terms-and-conditions';
    @api privacyUrl = 'https://www.modon.com/privacy-policy';
    @api recaptchaBadge = 'on'; // MEOI-CAPTCHA: Google's badge (bottom-right), 'off' to hide
    // MEOI-LAND11 (11 Sep, Mridul): the last fixed words become page properties too
    @api factsheetHeading = 'Factsheet';
    @api amenitiesHeading = 'Amenities';
    @api galleryHeading = 'Gallery';
    @api faqHeading = 'Frequently Asked Questions';
    @api sizeLabel = 'Size';
    @api planLabel = 'Payment plan';
    @api handoverLabel = 'Handover';
    @api priceLabel = 'Price';
    // MEOI-FACTS (12 Sep 2026): five factsheet rows were added and reverted the same evening; the Builder
    // properties cannot be removed from a placed component, so they stay declared here and are not rendered.
    @api plotLabel = 'Plot area';
    @api floorsLabel = 'Floors';
    @api parkingLabel = 'Parking';
    @api layoutsLabel = 'Layouts';
    @api quantityLabel = 'Quantity';
    @api termsLabel = 'Terms & Conditions';
    @api privacyLabel = 'Privacy Policy';
    @api modonLogoUrl = 'https://www.modon.com/';

    get showRecaptchaBadge() { return String(this.recaptchaBadge || '').toLowerCase() !== 'off'; }
    get recaptchaFrameSrc() { return recaptchaFramePath(basePath, true); }

    openFaq = -1;
    floatCta = false;   // MEOI-LAND3: the floating Register now shows once the hero button leaves the viewport

    // EOI-UI-19: hero carousel. Hero image holding several comma-separated URLs becomes slides; one URL keeps the single
    // image. EOI-UI-20: the portrait view follows Hero image (mobile) on its own: one URL there keeps that single image
    // (the original picture, unchanged), several make a portrait carousel, blank falls back to the landscape slides.
    // Hero image alt may separate slide texts with |.
    heroIndex = 0;
    heroLeaving = -1;
    heroDir = 1;
    heroAnimate = false;
    heroStarted = false;
    heroElapsed = 0;
    heroLast = 0;
    heroFrameId = null;
    heroLeaveTimer = null;
    heroStill = false;
    heroFocus = false;
    heroAway = false;
    heroSeen = null;
    heroSwipe = null;
    onHeroResize = null;
    heroPortrait = false;
    heroOrientationQuery = null;
    onHeroOrientation = null;

    splitHeroList(value) {
        return String(value || '').split(',').map((s) => s.trim()).filter(Boolean);
    }
    get heroDesktopList() { return this.splitHeroList(this.heroImage); }
    get heroMobileList() { return this.splitHeroList(this.heroImageMobile); }
    get isHeroCarousel() { return this.heroDesktopList.length > 1; }
    /* The slides to show now. Portrait screens: the mobile field decides (several URLs = its own carousel; one = no
       slides, the original picture shows that image; blank = the landscape slides). Otherwise the desktop field. */
    get heroActiveList() {
        const desktop = this.heroDesktopList;
        if (desktop.length < 2) return desktop;
        if (this.heroPortrait) {
            const mobile = this.heroMobileList;
            if (mobile.length > 1) return mobile;
            if (mobile.length === 1) return [];
        }
        return desktop;
    }
    get showHeroCarousel() { return this.isHeroCarousel && this.heroActiveList.length > 1; }
    get heroClass() { return this.showHeroCarousel ? 'hero hero--carousel' : 'hero'; }
    get heroCarouselLabel() { return this.logoAlt ? `${this.logoAlt} offers` : 'Offers'; }
    get heroSlides() {
        const list = this.heroActiveList;
        const alts = String(this.heroAlt || '').split('|').map((s) => s.trim());
        const current = this.heroIndex < list.length ? this.heroIndex : 0;
        return list.map((src, i) => {
            const active = i === current;
            let cls = 'hero__slide';
            if (active) {
                cls += ' hero__slide--active';
                if (this.heroAnimate) cls += this.heroDir < 0 ? ' hero__slide--from-prev' : ' hero__slide--from-next';
            } else if (i === this.heroLeaving) {
                cls += ' hero__slide--leaving';
            }
            return {
                key: `hero-slide-${i}`,
                cls,
                src: this.siteUrl(src),
                alt: alts.length > 1 ? (alts[i] || '') : (this.heroAlt || ''),
                label: `${i + 1} of ${list.length}`,
                hidden: active ? 'false' : 'true',
                loading: i === 0 ? 'eager' : 'lazy'
            };
        });
    }

    // EOI-UI-17: scroll cue at the foot of the hero
    scrollCueLabel = 'Scroll to explore';
    scrollCueGone = false;
    scrollCueNudge = false;
    onScrollCue = null;
    scrollCueTimer = null;

    get scrollCueClass() {
        return 'fold-cue' + (this.scrollCueGone ? ' fold-cue--gone' : '') + (this.scrollCueNudge ? ' fold-cue--nudge' : '');
    }

    get floatCtaClass() { return this.floatCta ? 'float-cta float-cta--on' : 'float-cta'; }
    get badgeClass() { return this.floatCta ? 'rc-badge rc-badge--raised' : 'rc-badge'; } // MEOI-CAPTCHA3: on phones the badge rises above the Register bar only while it shows
    get floatCtaHidden() { return this.floatCta ? 'false' : 'true'; }
    get floatCtaTabIndex() { return this.floatCta ? '0' : '-1'; }

    connectedCallback() {
        injectFonts((basePath || '').replace(/\/$/, ''));
        if (this.isHeroCarousel) this.watchHeroOrientation(); // EOI-UI-20: decided before the first render, so phones never flash the slides
    }

    /* MEOI-LAND2. The theme layout may leave a band above the page and a sliver below it; the
       amounts differ per site and per width. Measure once rendered (and on resize) and pull the
       host over both, so the hero starts at the very top and the black footer ends the page. */
    fitted = false;
    onResize = null;

    renderedCallback() {
        if (this.isHeroCarousel) { // EOI-UI-19
            if (!this.heroStarted) this.startHeroCarousel();
            this.frameHeroSlides();
        }
        if (this.fitted) return;
        this.fitted = true;
        this.onResize = () => this.fitToThemeLayout();
        window.addEventListener('resize', this.onResize);
        window.requestAnimationFrame(() => this.fitToThemeLayout());
        this.watchHeroButton();
        this.watchScrollCue();
    }

    disconnectedCallback() {
        if (this.onResize) window.removeEventListener('resize', this.onResize);
        if (this.heroObserver) { this.heroObserver.disconnect(); this.heroObserver = null; }
        if (this.onScroll) window.removeEventListener('scroll', this.onScroll);
        if (this.onScrollCue) { window.removeEventListener('scroll', this.onScrollCue); this.onScrollCue = null; }
        if (this.scrollCueTimer) { clearTimeout(this.scrollCueTimer); this.scrollCueTimer = null; }
        this.stopHeroCarousel();
    }

    /* MEOI-LAND3. Floating call to action: the hero's Register now stays as designed; once it
       scrolls out of view a fixed copy appears (bottom-right on desktop, a bar on phones) so the
       customer can register from anywhere on the page. IntersectionObserver where available,
       a scroll check otherwise. */
    heroObserver = null;
    onScroll = null;

    watchHeroButton() {
        const target = this.template.querySelector('.hero__btns');
        if (!target) return;
        if (typeof IntersectionObserver === 'function') {
            this.heroObserver = new IntersectionObserver((entries) => {
                entries.forEach((e) => { this.floatCta = !e.isIntersecting; });
            }, { threshold: 0 });
            this.heroObserver.observe(target);
        } else {
            this.onScroll = () => { const r = target.getBoundingClientRect(); this.floatCta = r.bottom < 0 || r.top > window.innerHeight; };
            window.addEventListener('scroll', this.onScroll, { passive: true });
            this.onScroll();
        }
    }

    /* EOI-UI-19. Hero carousel, ported from the agreed artifact: time only runs while the hero is on screen, the tab is
       visible, keyboard focus is outside the hero and the visitor has not asked for reduced motion; every 6.5s of it the
       next slide wipes in. Touch swipes change the slide. */
    startHeroCarousel() {
        const hero = this.template.querySelector('.hero');
        if (!hero) return;
        this.watchHeroOrientation();
        this.heroStarted = true;
        this.heroStill = this.prefersReducedMotion();
        this.heroElapsed = 0;
        this.heroLast = 0;
        const tick = (now) => {
            if (!this.heroStarted) return;
            if (!this.heroLast) this.heroLast = now;
            const dt = Math.min(100, now - this.heroLast);
            this.heroLast = now;
            const hidden = typeof document !== 'undefined' && document.hidden;
            if (!(this.heroStill || this.heroFocus || this.heroAway || hidden) && this.showHeroCarousel) {
                this.heroElapsed += dt;
                if (this.heroElapsed >= HERO_SLIDE_MS) this.heroGo(this.heroIndex + 1, 1);
            }
            this.heroFrameId = window.requestAnimationFrame(tick);
        };
        this.heroFrameId = window.requestAnimationFrame(tick);
        if (typeof IntersectionObserver === 'function') {
            this.heroSeen = new IntersectionObserver((entries) => { this.heroAway = !entries[0].isIntersecting; }, { threshold: 0.25 });
            this.heroSeen.observe(hero);
        }
        this.onHeroResize = () => this.frameHeroSlides();
        window.addEventListener('resize', this.onHeroResize);
    }

    stopHeroCarousel() {
        this.heroStarted = false;
        if (this.heroFrameId) { window.cancelAnimationFrame(this.heroFrameId); this.heroFrameId = null; }
        if (this.heroLeaveTimer) { clearTimeout(this.heroLeaveTimer); this.heroLeaveTimer = null; }
        if (this.heroSeen) { this.heroSeen.disconnect(); this.heroSeen = null; }
        if (this.onHeroResize) { window.removeEventListener('resize', this.onHeroResize); this.onHeroResize = null; }
        this.unwatchHeroOrientation();
    }

    /* EOI-UI-20. Portrait or landscape decides which hero field the slides come from; a change of orientation restarts
       the slideshow on the first image of the other list, without a wipe. */
    watchHeroOrientation() {
        if (this.heroOrientationQuery || typeof window === 'undefined' || typeof window.matchMedia !== 'function') return;
        const query = window.matchMedia('(orientation: portrait)');
        this.heroOrientationQuery = query;
        this.heroPortrait = query.matches;
        this.onHeroOrientation = (event) => {
            this.heroPortrait = event.matches;
            this.heroIndex = 0;
            this.heroLeaving = -1;
            this.heroAnimate = false;
            this.heroElapsed = 0;
            if (this.heroLeaveTimer) { clearTimeout(this.heroLeaveTimer); this.heroLeaveTimer = null; }
        };
        if (query.addEventListener) query.addEventListener('change', this.onHeroOrientation);
        else if (query.addListener) query.addListener(this.onHeroOrientation);
    }

    unwatchHeroOrientation() {
        const query = this.heroOrientationQuery;
        if (query && this.onHeroOrientation) {
            if (query.removeEventListener) query.removeEventListener('change', this.onHeroOrientation);
            else if (query.removeListener) query.removeListener(this.onHeroOrientation);
        }
        this.heroOrientationQuery = null;
        this.onHeroOrientation = null;
    }

    heroGo(to, dir) {
        const count = this.heroActiveList.length;
        if (count < 2) return;
        const current = this.heroIndex < count ? this.heroIndex : 0;
        const next = ((to % count) + count) % count;
        if (next === current) return;
        this.heroLeaving = current;
        this.heroDir = dir < 0 ? -1 : 1;
        this.heroAnimate = true;
        this.heroIndex = next;
        this.heroElapsed = 0;
        if (this.heroLeaveTimer) clearTimeout(this.heroLeaveTimer);
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this.heroLeaveTimer = setTimeout(() => {
            this.heroLeaveTimer = null;
            this.heroLeaving = -1;
        }, HERO_WIPE_MS + 80);
    }

    heroPointerDown(event) {
        if (!this.isHeroCarousel || event.pointerType === 'mouse') return;
        this.heroSwipe = { x: event.clientX, y: event.clientY };
    }

    heroPointerUp(event) {
        const start = this.heroSwipe;
        this.heroSwipe = null;
        if (!start || !this.isHeroCarousel) return;
        const dx = event.clientX - start.x;
        const dy = event.clientY - start.y;
        if (Math.abs(dx) > 45 && Math.abs(dx) > Math.abs(dy) * 1.3) this.heroGo(this.heroIndex + (dx < 0 ? 1 : -1), dx < 0 ? 1 : -1);
    }

    heroPointerCancel() {
        this.heroSwipe = null;
    }

    heroFocusIn(event) {
        let keyboard = false;
        try { keyboard = event.target.matches(':focus-visible'); } catch (e) { keyboard = false; }
        this.heroFocus = keyboard;
    }

    heroFocusOut(event) {
        if (!event.currentTarget.contains(event.relatedTarget)) this.heroFocus = false;
    }

    /* Keeps the offer text of each banner in frame at every screen shape (the artifact's rule); where the whole line
       cannot fit, the text is centred. Not applied when portrait images are supplied for portrait screens. */
    frameHeroSlides() {
        const hero = this.template.querySelector('.hero');
        if (!hero || !this.showHeroCarousel) return;
        const bw = hero.clientWidth;
        const bh = hero.clientHeight;
        if (!bw || !bh) return;
        const portraitSlides = this.heroPortrait && this.heroMobileList.length > 1; // MODON's portrait renders need no framing
        let position = '';
        if (!portraitSlides) {
            const W = Math.max(bw, bh * 16 / 9);
            const m = Math.max(20, bw * 0.04);
            let left = Math.max(bw - W, Math.min((bw - W) / 2, bw - m - HERO_TEXT_R * W));
            if (HERO_TEXT_L * W + left < m) left = Math.max(bw - W, Math.min(0, bw / 2 - HERO_TEXT_C * W));
            position = `${Math.round(left)}px 50%`;
        }
        this.template.querySelectorAll('.hero__slide-img').forEach((img) => {
            if (img.style.objectPosition !== position) img.style.objectPosition = position;
        });
    }

    /* EOI-UI-17. Scroll cue: hidden once the visitor scrolls past 40px and shown again at the top; a visitor still at
       the top after a few seconds gets one gentle nudge (not with reduced motion). */
    watchScrollCue() {
        this.onScrollCue = () => {
            const gone = (window.scrollY || document.documentElement.scrollTop || 0) > 40;
            if (gone !== this.scrollCueGone) this.scrollCueGone = gone;
        };
        window.addEventListener('scroll', this.onScrollCue, { passive: true });
        this.onScrollCue();
        if (!this.prefersReducedMotion()) {
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            this.scrollCueTimer = setTimeout(() => {
                this.scrollCueTimer = null;
                if (!this.scrollCueGone) this.scrollCueNudge = true;
            }, 4500);
        }
    }

    endScrollCueNudge(event) {
        if (event.target === event.currentTarget) this.scrollCueNudge = false;
    }

    scrollToContent() {
        const band = this.template.querySelector('.info');
        if (band) band.scrollIntoView({ behavior: this.prefersReducedMotion() ? 'auto' : 'smooth', block: 'start' });
    }

    prefersReducedMotion() {
        return typeof window.matchMedia === 'function' && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    }

    fitToThemeLayout() {
        const host = this.template.host;
        if (!host || !host.getBoundingClientRect) return;
        host.style.marginTop = '0px';
        host.style.marginBottom = '0px';
        const top = Math.round(host.getBoundingClientRect().top + window.scrollY);
        if (top > 0 && top <= 64) host.style.marginTop = `-${top}px`;
        const bottom = host.getBoundingClientRect().bottom + window.scrollY;
        const extra = Math.round(document.documentElement.scrollHeight - bottom);
        if (extra > 0 && extra <= 64) host.style.marginBottom = `-${extra}px`;
    }

    /* Static resources answer on the site's own path (/eoi/sfsites/...): the site-less
       /sfsites/ path 301s to the domain's default site (MEOI-IMG, 11 Sep). MEOI-LAND4: every
       resource URL also carries ?v=ASSET_VERSION - static resources are cached "Public" by the
       browser and the CDN, so a changed file at the same address kept showing its old content
       (the rail arrows, 11 Sep evening). Bump ASSET_VERSION whenever a file in Wadeem_Landing or
       Wadeem_Assets changes. */
    siteUrl(u) {
        if (!u) return '';
        const site = (basePath || '').replace(/\/$/, '');
        let out = site && u.startsWith('/sfsites/') && !u.startsWith(site + '/') ? site + u : u;
        if (out.includes('/sfsites/c/resource/') && !out.includes('?')) {
            out += '?v=' + ASSET_VERSION;
        }
        return out;
    }

    /** A file inside the asset folder, on the site path, version-stamped. */
    asset(path) {
        return this.siteUrl(`${(this.assetBase || '').replace(/\/$/, '')}/${path}`);
    }

    get modonLogoSrc() { return this.siteUrl(this.modonLogoImage); }
    get heroSrc() { return this.siteUrl(this.isHeroCarousel ? this.heroDesktopList[0] : this.heroImage); } // EOI-UI-20: the original picture (portrait, one mobile URL) falls back to the first slide
    get heroMobileSrc() { return this.siteUrl(this.heroImageMobile); }
    get hasHeroMobile() { return !!this.heroImageMobile; } // MEOI-HERO
    get logoSrc() { return this.siteUrl(this.logoImage); }
    get sideSrc() { return this.siteUrl(this.sideImage); }
    get mapSrc() { return this.siteUrl(this.mapImage); }
    get hasLogo() { return !!this.logoImage; }
    get hasModonLogo() { return !!this.modonLogoImage; }
    get hasTagline() { return !!this.tagline; }
    get hasTitle() { return !!this.title; }
    get hasSideImage() { return !!this.sideImage; }
    get hasMap() { return !!this.mapImage; }

    get icon() {
        return {
            bedroom: this.asset('icons/bedroom.png'), plan: this.asset('icons/payment-plan.png'),
            handover: this.asset('icons/handover.png'), price: this.asset('icons/price.png')
        };
    }

    get factsheet() {
        let rows = DEFAULT_FACTSHEET;
        if (this.factsheetJson) {
            try {
                const parsed = JSON.parse(this.factsheetJson);
                if (Array.isArray(parsed) && parsed.length) rows = parsed;
            } catch (e) { /* keep the defaults; a typo in the builder must never blank the page */ }
        }
        const line = (label, value) => `${label}: ${value || ''}`;
        return rows.map((r, i) => ({
            key: `fs-${i}`, title: r.title || '',
            sizeText: line(this.sizeLabel, r.size), planText: line(this.planLabel, r.plan),
            handoverText: line(this.handoverLabel, r.handover), priceText: line(this.priceLabel, r.price)
        }));
    }

    parsedList(json, fallback) {
        if (json) {
            try {
                const parsed = JSON.parse(json);
                if (Array.isArray(parsed) && parsed.length) return parsed;
            } catch (e) { /* keep the defaults; a typo in the builder must never blank the page */ }
        }
        return fallback;
    }

    get amenities() {
        return this.parsedList(this.amenitiesJson, AMENITIES).map((a, i) => ({
            key: `am-${i}`, label: a.label || '', src: this.asset(`amenities/${(a.icon || 'parks-and-green-spaces').replace(/[^a-z0-9-]/gi, '')}.svg`)
        }));
    }

    get gallery() {
        return (this.galleryImages || '').split(',').map((s) => s.trim()).filter(Boolean)
            .map((src, i) => {
                const name = (src.split('/').pop() || '').replace(/\.[a-z0-9]+$/i, '').replace(/^\d+-/, '').replace(/-/g, ' ');
                return { key: `g-${i}`, src: this.siteUrl(src), alt: `${this.title}${name ? ' — ' + name : ''}` };
            });
    }

    get faqs() {
        return this.parsedList(this.faqJson, FAQS).map((f, i) => ({
            ...f, key: `faq-${i}`, index: i, open: i === this.openFaq,
            cls: i === this.openFaq ? 'faq__item faq__item--open' : 'faq__item',
            expanded: i === this.openFaq ? 'true' : 'false',
            panelId: `faq-panel-${i}`
        }));
    }

    toggleFaq(event) {
        const i = Number(event.currentTarget.dataset.index);
        this.openFaq = this.openFaq === i ? -1 : i;
    }

    scrollRail(event) {
        const { rail, dir } = event.currentTarget.dataset;
        const el = this.template.querySelector(`[data-rail-id="${rail}"]`);
        if (!el) return;
        const first = el.querySelector('[data-slide]');
        const step = first ? first.getBoundingClientRect().width + 24 : el.clientWidth * 0.8;
        el.scrollBy({ left: dir === 'next' ? step : -step, behavior: 'smooth' });
    }
}