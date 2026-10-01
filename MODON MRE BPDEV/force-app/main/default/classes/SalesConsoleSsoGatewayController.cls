/*
 * MODON Sales Console - SSO gateway controller
 * Author   Aurelix
 * Version  Date         Comment
 * 1.0      Aurelix IT   28 Aug 2026  Initial. The one hop a login flow cannot make
 *                                    itself: LoginFlow_FinishLocation only accepts
 *                                    URLs inside the org's own domain, and the
 *                                    console lives on the site domain. The flow
 *                                    finishes on this page; this page steps across.
 */

/**
 * Backs the SalesConsoleSsoGateway Visualforce page. The login flow sends a rep who
 * holds the redirect permission here; the action method forwards the browser to the
 * site's SSO endpoint, where the Sales_Console_SSO Auth Provider turns the org
 * session the rep already has into a console session - no second password.
 *
 * Anyone who lands here WITHOUT the permission - a bookmark, a guess, a shared link -
 * is sent to the ordinary Salesforce home page. No error, no information.
 */
public with sharing class SalesConsoleSsoGatewayController {

    /** Where the page's action attribute sends the browser. Never null. */
    public PageReference go() {
        if (!FeatureManagement.checkPermission('Redirect_To_Sales_Console')) {
            PageReference home = new PageReference('/');
            home.setRedirect(true);
            return home;
        }
        PageReference switchUrl = new PageReference(consoleSwitchUrl());
        switchUrl.setRedirect(true);
        return switchUrl;
    }

    /**
     * Salesforce's own network-switch servlet, which converts the rep's org session
     * into a site session with no second login. Proven in this org on 28 Aug 2026:
     * the servlet accepts ONLY the 15-character network id - the 18-character form
     * bounces to home, which is what sent an earlier version of this feature down
     * the (platform-blocked) same-org SSO road. The label keeps the canonical
     * 18-character id; left(15) is the shape the servlet wants.
     */
    @TestVisible
    private static String consoleSwitchUrl() {
        return '/servlet/networks/switch?networkId='
            + Label.Sales_Console_Network_Id.left(15);
    }
}