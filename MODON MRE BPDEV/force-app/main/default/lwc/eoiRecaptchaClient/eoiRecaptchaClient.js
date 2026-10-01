/**
 * eoiRecaptchaClient — promise bridge to the EOIRecaptchaFrame Visualforce page
 * (MEOI-CAPTCHA, 11 Sep 2026). A page embeds the frame (same origin, under the site's
 * <prefix>vforcesite path) and calls requestRecaptchaToken(frame, action); the frame runs
 * Google reCAPTCHA v3 and answers with a token, which the page sends to Apex for
 * verification. The script itself never loads inside the LWR page, so the site's CSP
 * stays untouched. @author Aurelix
 */
const pending = new Map();
let listening = false;

function listen() {
    if (listening) return;
    listening = true;
    window.addEventListener('message', (event) => {
        if (event.origin !== window.location.origin) return;
        const d = event.data || {};
        if (d.type !== 'eoi-recaptcha-token' || !d.nonce) return;
        const p = pending.get(d.nonce);
        if (!p) return;
        pending.delete(d.nonce);
        clearTimeout(p.timer);
        if (d.token) p.resolve(d.token);
        else p.reject(new Error(d.error || 'no-token'));
    });
}

/** /eoi -> /eoivforcesite/apex/EOIRecaptchaFrame ; badge=true shows Google's badge in the frame. */
export function recaptchaFramePath(basePath, badge) {
    const site = (basePath || '').replace(/\/$/, '');
    return `${site}vforcesite/apex/EOIRecaptchaFrame${badge ? '?badge=1' : ''}`;
}

export function requestRecaptchaToken(frame, action, timeoutMs = 8000) {
    return new Promise((resolve, reject) => {
        if (!frame || !frame.contentWindow) { reject(new Error('no-frame')); return; }
        listen();
        const nonce = `${Date.now()}-${Math.random().toString(36).slice(2)}`;
        const timer = setTimeout(() => { pending.delete(nonce); reject(new Error('timeout')); }, timeoutMs);
        pending.set(nonce, { resolve, reject, timer });
        frame.contentWindow.postMessage({ type: 'eoi-recaptcha-request', action, nonce }, window.location.origin);
    });
}

/** The line Google requires wherever the badge is hidden. */
export const RECAPTCHA_DISCLOSURE = 'This site is protected by reCAPTCHA and the Google Privacy Policy and Terms of Service apply.';