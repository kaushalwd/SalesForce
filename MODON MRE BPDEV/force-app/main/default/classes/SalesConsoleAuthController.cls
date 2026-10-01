/**
 * SalesConsoleAuthController - sign-in for the Modon Sales Console login page.
 *
 * Version  Author      Date         Detail
 * 1.0      Aurelix IT  09 Aug 2026  Initial. Site.login behind the branded card, so
 *                                   the approved login screen is one card rather than
 *                                   our panel stacked above the stock platform form.
 */

/**
 * Hands a username and password to the PLATFORM's authentication service and returns
 * where to go next. It does not authenticate anything itself.
 *
 * Site.login is Salesforce's supported entry point for a custom Experience Cloud login
 * page. Every policy still applies, and none of it lives here - password expiry,
 * lockout after failed attempts, login hours, IP restrictions, MFA and identity
 * verification are all enforced by the platform on this one call. Nothing is stored,
 * logged or cached: the credential is a method argument that goes straight to
 * Site.login and is never written anywhere, including debug logs.
 *
 * What is deliberately NOT here, and must never be added: the PoC's
 * loginAs(username, password, startUrl, persona) persona switcher. That is an
 * authentication bypass wearing a convenience label, and this org holds real customer
 * data.
 *
 * This runs as the site's GUEST user - it has to, since the caller is not signed in
 * yet. That is why the guest profile grants this one class and nothing else, and why
 * this class does nothing but call Site.login.
 */
public with sharing class SalesConsoleAuthController {

    /**
     * @return the URL to send the browser to on success, null on any failure.
     *
     * Null rather than an exception, and one null for every kind of failure. "No such
     * user" and "wrong password" are different answers, and letting the browser tell
     * them apart is how an attacker enumerates who works at Modon.
     */
    @AuraEnabled
    public static String login(String username, String password, String startUrl) {
        if (String.isBlank(username) || String.isBlank(password)) {
            return null;
        }
        try {
            PageReference pr = Site.login(username, password, startUrl);
            return pr == null ? null : pr.getUrl();
        } catch (Exception e) {
            // Site.login throws on a rejected credential in some contexts and returns
            // null in others. Both mean the same thing to the caller. The reason is
            // deliberately swallowed rather than returned or logged - see above.
            return null;
        }
    }
}