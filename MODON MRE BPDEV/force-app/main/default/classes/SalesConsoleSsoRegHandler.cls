/*
 * MODON Sales Console - SSO registration handler
 * Author   Aurelix
 * Version  Date         Comment
 * 1.0      Aurelix IT   28 Aug 2026  Initial. The org signing its own reps into the
 *                                    console site: Auth Provider "Sales_Console_SSO"
 *                                    hands the OAuth identity here, and this class
 *                                    decides whether a console session is minted.
 */

/**
 * MATCH-ONLY. This handler links the OAuth identity coming back from this same org to
 * the very user it already belongs to, so an internal rep who is signed in to
 * Salesforce enters the Sales Console without typing credentials again.
 *
 * What it must never do, and structurally cannot: create a user, modify a user, or
 * sign in anyone other than the person the org itself just authenticated. Every path
 * that is not an exact self-match throws, and a throw means no session.
 *
 * Three gates, all of which must pass:
 *   1. The identity is from THIS org (organization_id attribute matches).
 *   2. The user id in the identity resolves to an active, standard (internal) user.
 *   3. That user holds the Redirect_To_Sales_Console custom permission - the same
 *      switch the login flow reads, granted through the Sales Console User
 *      permission set. One switch controls the whole journey.
 *
 * Runs as the Auth Provider's "Execute Registration As" user, NOT as the person
 * logging in - which is why gate 3 is a query on the target user rather than
 * FeatureManagement.checkPermission (that would test the wrong user).
 */
public without sharing class SalesConsoleSsoRegHandler implements Auth.RegistrationHandler {

    public class SsoException extends Exception {}

    private static final String CUSTOM_PERMISSION = 'Redirect_To_Sales_Console';
    private static final String DENIED =
        'Sales Console access could not be completed for this account. '
        + 'Please contact your administrator.';

    /**
     * First SSO login for this identity: find the matching user, never make one.
     * Returning a User WITH an Id tells the platform "link, do not insert".
     */
    public User createUser(Id portalId, Auth.UserData data) {
        return matchInternalUser(data);
    }

    /**
     * Later SSO logins re-run the gates and change nothing. A rep whose permission
     * set was removed after they linked once must not keep sliding in through the
     * remembered link.
     */
    public void updateUser(Id userId, Id portalId, Auth.UserData data) {
        User matched = matchInternalUser(data);
        if (matched.Id != userId) {
            throw new SsoException(DENIED);
        }
    }

    private User matchInternalUser(Auth.UserData data) {
        if (data == null || String.isBlank(data.identifier)) {
            throw new SsoException(DENIED);
        }

        // Gate 1 - the identity must come from this very org. The Salesforce-type
        // provider puts the issuing org id in the attribute map.
        String issuingOrg = data.attributeMap == null
            ? null : data.attributeMap.get('organization_id');
        String hereOrg = String.valueOf(UserInfo.getOrganizationId());
        if (String.isBlank(issuingOrg)
            || !hereOrg.startsWith(issuingOrg.left(15))) {
            throw new SsoException(DENIED);
        }

        // Gate 2 - the username in the identity payload must resolve to an active
        // internal user, and the identifier must carry that user's id. The provider
        // may prefix the identifier with the org id (the org's "include identity
        // organization's ID" option, not editable in this org's UI), so the check is
        // containment of the 15-character id rather than a parse of the whole string.
        if (String.isBlank(data.username)) {
            throw new SsoException(DENIED);
        }
        List<User> users = [
            SELECT Id, Username, IsActive, UserType
            FROM User
            WHERE Username = :data.username
            LIMIT 1
        ];
        if (users.isEmpty()
            || users[0].IsActive != true
            || users[0].UserType != 'Standard'
            || !data.identifier.contains(String.valueOf(users[0].Id).left(15))) {
            throw new SsoException(DENIED);
        }

        // Gate 3 - the same custom permission the login flow reads, checked against
        // the TARGET user through whichever permission set grants it.
        if (!holdsConsolePermission(users[0].Id)) {
            throw new SsoException(DENIED);
        }

        return users[0];
    }

    /** True when any permission set assigned to the user carries the permission. */
    private static Boolean holdsConsolePermission(Id userId) {
        Set<Id> grantingParents = new Set<Id>();
        for (SetupEntityAccess sea : [
            SELECT ParentId
            FROM SetupEntityAccess
            WHERE SetupEntityId IN (
                SELECT Id FROM CustomPermission WHERE DeveloperName = :CUSTOM_PERMISSION
            )
        ]) {
            grantingParents.add(sea.ParentId);
        }
        if (grantingParents.isEmpty()) {
            return false;
        }
        return [
            SELECT COUNT()
            FROM PermissionSetAssignment
            WHERE AssigneeId = :userId
              AND PermissionSetId IN :grantingParents
        ] > 0;
    }
}