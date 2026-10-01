/**
 * Tests for SalesConsoleAuthController.
 *
 * Version  Author      Date         Detail
 * 1.0      Aurelix IT  09 Aug 2026  Initial.
 *
 * What these protect: the login page must never become an oracle. Every rejected
 * sign-in has to look identical from the browser - same null, no exception, no reason
 * - or the form tells an attacker which usernames exist at Modon. That property is
 * one careless `throw e` away from being lost, and nothing else in the codebase would
 * notice.
 */
@isTest
private class SalesConsoleAuthControllerTest {

    /** Nothing missing should ever reach the platform's authentication service. */
    @isTest
    static void testBlankCredentialsAreRefusedBeforeTheyLeaveApex() {
        Test.startTest();
        String noneAtAll   = SalesConsoleAuthController.login(null, null, '/sales/');
        String noPassword  = SalesConsoleAuthController.login('someone@modon.com', '', '/sales/');
        String noUsername  = SalesConsoleAuthController.login('', 'a-password', '/sales/');
        String justSpaces  = SalesConsoleAuthController.login('   ', '   ', '/sales/');
        Test.stopTest();

        System.assertEquals(null, noneAtAll,  'An empty form must not call Site.login.');
        System.assertEquals(null, noPassword, 'A missing password must not call Site.login.');
        System.assertEquals(null, noUsername, 'A missing username must not call Site.login.');
        System.assertEquals(null, justSpaces, 'Whitespace is not a credential.');
    }

    /**
     * The one that matters. A rejected credential must come back as a plain null -
     * never an exception, and never a message. AuraHandledException here would send
     * the platform's own wording to the browser, and that wording distinguishes an
     * unknown user from a wrong password.
     */
    @isTest
    static void testRejectedCredentialsComeBackAsNullNotAnException() {
        Boolean threw = false;
        String url;
        Test.startTest();
        try {
            url = SalesConsoleAuthController.login(
                'definitely.not.a.user@modon.com.invalid', 'not-the-password', '/sales/');
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();

        System.assertEquals(false, threw,
            'A failed sign-in must not throw. Site.login raises in some contexts and ' +
            'returns null in others; the caller has to see one behaviour.');
        System.assertEquals(null, url,
            'A rejected sign-in returns null so the UI can show one generic message.');
    }

    /**
     * Two different wrong answers must be indistinguishable. If these ever diverge,
     * the form has become a username oracle.
     */
    @isTest
    static void testUnknownUserAndWrongPasswordAreIndistinguishable() {
        Test.startTest();
        String unknownUser  = SalesConsoleAuthController.login(
            'no.such.person@modon.com.invalid', 'whatever', '/sales/');
        String wrongPassword = SalesConsoleAuthController.login(
            UserInfo.getUserName(), 'definitely-not-the-real-password', '/sales/');
        Test.stopTest();

        System.assertEquals(unknownUser, wrongPassword,
            'An unknown username and a real username with a wrong password must ' +
            'produce byte-identical results. Anything else enumerates Modon staff.');
    }
}