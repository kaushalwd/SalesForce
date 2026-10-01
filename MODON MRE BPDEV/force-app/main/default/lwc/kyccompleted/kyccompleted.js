/**********************************************************************************************************************
* Name               : Kyccompleted (LWC)
* Description        : "Thank You / You're All Set" confirmation screen shown after KYC verification is completed.
* Created By         : ActiveMinds
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment
* 1.0          ActiveMinds                         -               Initial version - static resource image banner
* 2.0          Arvind                              31 July 2026    Replaced static resource banner image with live
*                                                                    HTML/CSS "Thank You" design (logo, heading,
*                                                                    subtext, Done button). Done button links to
*                                                                    https://www.modon.com/
* 2.1          Arvind                              31 July 2026    Fixed Done button styling not applying due to
*                                                                    theme/site anchor style overrides (raised CSS
*                                                                    specificity + !important guards). Added
*                                                                    JS-measured window.innerHeight fallback
*                                                                    (--thank-you-vh) for reliable full-height
*                                                                    background in in-app browser webviews
*                                                                    (Outlook, Instagram, LinkedIn, etc.) where
*                                                                    vh/svh/dvh CSS units are unreliable.
* 3.0          Arvind                              31 July 2026    Modern white-background redesign per feedback:
*                                                                    removed the dark wave background image entirely,
*                                                                    added a small dark header strip so the existing
*                                                                    dark-background MODON logo PNG (no transparency)
*                                                                    displays cleanly, added a success checkmark icon
*                                                                    and a "verified securely" trust badge.
*                                                                    Static resource: KYCModonLogoDark1 (updated with
*                                                                    new logo from design team).
**********************************************************************************************************************/
import { LightningElement } from 'lwc';
import modonLogoDark from '@salesforce/resourceUrl/KYCModonLogoDark1';

export default class Kyccompleted extends LightningElement {
    logoUrl = modonLogoDark;
    doneUrl = 'https://www.modon.com/';

    _resizeHandler = null;

    connectedCallback() {
        // 3.1 Arvind - JS-based viewport height fix, still relevant even without the
        // background image, since the white card itself should still fill the real
        // visible viewport reliably across in-app browser webviews.
        this._resizeHandler = () => this.setViewportHeight();
        window.addEventListener('resize', this._resizeHandler);
        window.addEventListener('orientationchange', this._resizeHandler);
        this.setViewportHeight();
        setTimeout(() => this.setViewportHeight(), 300);
    }

    disconnectedCallback() {
        if (this._resizeHandler) {
            window.removeEventListener('resize', this._resizeHandler);
            window.removeEventListener('orientationchange', this._resizeHandler);
        }
    }

    setViewportHeight() {
        if (window.innerHeight) {
            this.template.host.style.setProperty('--thank-you-vh', `${window.innerHeight}px`);
        }
    }
}