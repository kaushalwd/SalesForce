/**
 * EOIRecaptchaFrameController — controller of the EOIRecaptchaFrame Visualforce page
 * (MEOI-CAPTCHA, 11 Sep 2026). Exposes the PUBLIC reCAPTCHA site key only; the secret
 * never leaves the External Credential and is never read by Apex. The label is part of the
 * package, so a missing label is a compile-time error rather than something to catch here.
 * @author Aurelix
 */
public with sharing class EOIRecaptchaFrameController {
    public String getSiteKey() {
        return System.Label.EOI_Site_Recaptcha_Site_Key.trim();
    }
}