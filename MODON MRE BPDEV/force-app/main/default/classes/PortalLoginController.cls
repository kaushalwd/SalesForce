/**
 * Custom login for the Modon DCT Experience Cloud site.
 * Authenticates the external user via Site.login and returns the start URL,
 * which the login component navigates to (the session is established by Site.login).
 */
public with sharing class PortalLoginController {
    @AuraEnabled
    public static String login(String username, String password, String startUrl) {
        try {
            String start = String.isBlank(startUrl) ? '/' : startUrl;
            System.PageReference pageRef = Site.login(username, password, start);
            return pageRef != null ? pageRef.getUrl() : null;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}