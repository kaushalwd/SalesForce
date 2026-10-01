/**
 * eoiIdentityPage — Builder-exposed page wrapper: eoiSplitPage shell with
 * eoiIdentityChooser inside. All branding arrives via page properties.
 * @author Aurelix
 */
import { LightningElement, api } from 'lwc';

export default class EoiIdentityPage extends LightningElement {
    @api modonLogoImage = ''; // MEOI-MODON
    @api posterImage = '';
    @api posterAlt = '';
    @api logoImage = '';
    @api logoAlt = '';
    @api tagline = '';
    @api caption = '';
    @api wordmark = '';
    @api wordmarkSub = '';
    @api eyebrow = 'Expression of Interest';
    @api projectId = '';
    @api typologyImageBase = '';
    @api heading = 'Register your interest';
    @api uaePassButtonImage = '';
    @api backUrl = '';
    @api helpLine = '';
    @api contactUrl = '';
    @api copyrightText = '© 2026 Modon. All rights reserved.';
}