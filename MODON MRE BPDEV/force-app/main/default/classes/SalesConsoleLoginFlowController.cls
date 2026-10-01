/*
 * MODON Sales Console - login flow (Visualforce)
 * Author   Aurelix
 * Version  Date         Comment
 * 1.0      Aurelix IT   28 Aug 2026  Initial. The Flow Builder login flow proved
 *                                    unable to hand over its finish location (three
 *                                    destinations assigned cleanly in the debug logs,
 *                                    all ignored - servlet, absolute, and relative
 *                                    /apex alike), so the flow is Visualforce, where
 *                                    finishing is this controller's own call.
 */

/**
 * Backs the SalesConsoleLoginFlow page - the login flow attached to the Sales
 * Management profile. Runs on EVERY login of that profile, so its one absolute rule
 * is: any doubt, any error, any unrecognised situation ends in a NORMAL login.
 * Nothing here may ever stand between a rep and Salesforce.
 *
 * The happy path: a rep holding Redirect_To_Sales_Console, signing in to the org in
 * a browser, is finished into the SalesConsoleSsoGateway page, which carries them
 * across to the console site via the Sales_Console_SSO Auth Provider.
 */
public with sharing class SalesConsoleLoginFlowController {

    @TestVisible
    private static final String GATEWAY = '/apex/SalesConsoleSsoGateway';

    /** Test seam: getCurrentSession is unavailable outside a real session. */
    @TestVisible
    private static Map<String, String> sessionOverride;

    /** The page's action method. Always finishes the login flow, never throws. */
    public PageReference proceed() {
        String target;
        try {
            target = decideTarget();
        } catch (Exception e) {
            target = null; // undecided means untouched: the login proceeds as normal
        }
        try {
            return target == null
                ? Auth.SessionManagement.finishLoginFlow()
                : Auth.SessionManagement.finishLoginFlow(target);
        } catch (Exception e) {
            // Outside a login-flow context (a direct visit, a test) there is nothing
            // to finish; go where the decision pointed all the same.
            PageReference fallback = new PageReference(target == null ? '/' : target);
            fallback.setRedirect(true);
            return fallback;
        }
    }

    /**
     * The gateway path for exactly the sign-ins the redirect is meant for; null for
     * every other login on the profile.
     *
     *  - permission: the one switch, granted by the Sales Console User perm set
     *  - network:    a login that is already on an Experience Cloud site stays there
     *  - login type: 'Application' is this org's browser UI sign-in (verified in
     *    LoginHistory); OAuth clients and the mobile app report other types and are
     *    deliberately left alone
     */
    @TestVisible
    private static String decideTarget() {
        if (!FeatureManagement.checkPermission('Redirect_To_Sales_Console')) {
            return null;
        }
        if (Network.getNetworkId() != null) {
            return null;
        }
        Map<String, String> session = sessionOverride;
        if (session == null) {
            try {
                session = Auth.SessionManagement.getCurrentSession();
            } catch (Exception e) {
                return null;
            }
        }
        String loginType = session == null ? null : session.get('LoginType');
        if (loginType != 'Application') {
            return null;
        }
        return GATEWAY;
    }
}