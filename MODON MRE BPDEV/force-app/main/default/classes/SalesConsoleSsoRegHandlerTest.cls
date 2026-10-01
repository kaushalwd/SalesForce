/*
 * MODON Sales Console - tests for the SSO registration handler and gateway
 * Author   Aurelix
 * Version  Date         Comment
 * 1.0      Aurelix IT   28 Aug 2026  Initial. Every gate is exercised from both
 *                                    sides: the one identity that must pass, and
 *                                    each of the ways an identity must not.
 */
@IsTest
private class SalesConsoleSsoRegHandlerTest {

    private static final String PS_NAME = 'Sales_Console_User';

    private static User makeRep(String uname) {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            FirstName = 'Sso', LastName = 'Rep',
            Alias = 'srep', Email = 'sso.rep@example.com',
            Username = uname, ProfileId = p.Id,
            EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US', TimeZoneSidKey = 'Asia/Dubai'
        );
        insert u;
        return u;
    }

    private static void grantConsolePermission(Id userId) {
        PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = :PS_NAME LIMIT 1];
        insert new PermissionSetAssignment(AssigneeId = userId, PermissionSetId = ps.Id);
    }

    private static Auth.UserData identityFor(User u, String orgId) {
        return new Auth.UserData(
            u.Id, 'Sso', 'Rep', 'Sso Rep', u.Email, null,
            u.Username, 'en_US', 'Salesforce', null,
            new Map<String, String>{ 'organization_id' => orgId }
        );
    }

    @IsTest
    static void matchesTheAuthenticatedRep() {
        User rep = makeRep('sso.rep.pass@modon.example.test');
        grantConsolePermission(rep.Id);
        Auth.UserData d = identityFor(rep, UserInfo.getOrganizationId());

        Test.startTest();
        User matched = new SalesConsoleSsoRegHandler().createUser(null, d);
        Test.stopTest();

        System.assertEquals(rep.Id, matched.Id, 'must link the same user, never create');
    }

    @IsTest
    static void refusesForeignOrgIdentity() {
        User rep = makeRep('sso.rep.forg@modon.example.test');
        grantConsolePermission(rep.Id);
        Auth.UserData d = identityFor(rep, '00D000000000001EAA');

        try {
            new SalesConsoleSsoRegHandler().createUser(null, d);
            System.assert(false, 'foreign org identity must be refused');
        } catch (SalesConsoleSsoRegHandler.SsoException e) {
            System.assert(e.getMessage().contains('administrator'), 'professional message');
        }
    }

    @IsTest
    static void refusesWithoutConsolePermission() {
        User rep = makeRep('sso.rep.noperm@modon.example.test');
        Auth.UserData d = identityFor(rep, UserInfo.getOrganizationId());

        try {
            new SalesConsoleSsoRegHandler().createUser(null, d);
            System.assert(false, 'a rep without the permission set must be refused');
        } catch (SalesConsoleSsoRegHandler.SsoException e) {
            System.assert(true);
        }
    }

    @IsTest
    static void refusesUsernameMismatch() {
        User rep = makeRep('sso.rep.mism@modon.example.test');
        grantConsolePermission(rep.Id);
        Auth.UserData d = new Auth.UserData(
            rep.Id, 'Sso', 'Rep', 'Sso Rep', rep.Email, null,
            'somebody.else@modon.example.test', 'en_US', 'Salesforce', null,
            new Map<String, String>{ 'organization_id' => UserInfo.getOrganizationId() }
        );

        try {
            new SalesConsoleSsoRegHandler().createUser(null, d);
            System.assert(false, 'identity naming a different username must be refused');
        } catch (SalesConsoleSsoRegHandler.SsoException e) {
            System.assert(true);
        }
    }

    @IsTest
    static void matchesWhenIdentifierCarriesOrgPrefix() {
        User rep = makeRep('sso.rep.orgpfx@modon.example.test');
        grantConsolePermission(rep.Id);
        Auth.UserData d = new Auth.UserData(
            UserInfo.getOrganizationId() + rep.Id, 'Sso', 'Rep', 'Sso Rep',
            rep.Email, null, rep.Username, 'en_US', 'Salesforce', null,
            new Map<String, String>{ 'organization_id' => UserInfo.getOrganizationId() }
        );

        Test.startTest();
        User matched = new SalesConsoleSsoRegHandler().createUser(null, d);
        Test.stopTest();

        System.assertEquals(rep.Id, matched.Id,
            'an org-prefixed identifier must still link the same user');
    }

    @IsTest
    static void updateUserRefusesDriftedLink() {
        User rep = makeRep('sso.rep.drift@modon.example.test');
        User other = makeRep('sso.rep.other@modon.example.test');
        grantConsolePermission(rep.Id);
        Auth.UserData d = identityFor(rep, UserInfo.getOrganizationId());

        try {
            new SalesConsoleSsoRegHandler().updateUser(other.Id, null, d);
            System.assert(false, 'a link pointing at a different user must be refused');
        } catch (SalesConsoleSsoRegHandler.SsoException e) {
            System.assert(true);
        }
    }

    @IsTest
    static void updateUserAcceptsTheSameRep() {
        User rep = makeRep('sso.rep.same@modon.example.test');
        grantConsolePermission(rep.Id);
        Auth.UserData d = identityFor(rep, UserInfo.getOrganizationId());

        Test.startTest();
        new SalesConsoleSsoRegHandler().updateUser(rep.Id, null, d);
        Test.stopTest();
        System.assert(true, 'same-user relogin passes');
    }

    @IsTest
    static void loginFlowTargetsGatewayForBrowserHolder() {
        User rep = makeRep('sso.rep.lf1@modon.example.test');
        grantConsolePermission(rep.Id);

        System.runAs(rep) {
            SalesConsoleLoginFlowController.sessionOverride =
                new Map<String, String>{ 'LoginType' => 'Application' };
            System.assertEquals(
                SalesConsoleLoginFlowController.GATEWAY,
                SalesConsoleLoginFlowController.decideTarget(),
                'browser sign-in by a holder goes to the gateway'
            );
        }
    }

    @IsTest
    static void loginFlowLeavesOauthClientsAlone() {
        User rep = makeRep('sso.rep.lf2@modon.example.test');
        grantConsolePermission(rep.Id);

        System.runAs(rep) {
            SalesConsoleLoginFlowController.sessionOverride =
                new Map<String, String>{ 'LoginType' => 'Remote Access 2.0' };
            System.assertEquals(null,
                SalesConsoleLoginFlowController.decideTarget(),
                'the mobile app and OAuth clients must finish normally');
        }
    }

    @IsTest
    static void loginFlowLeavesNonHoldersAlone() {
        User rep = makeRep('sso.rep.lf3@modon.example.test');

        System.runAs(rep) {
            SalesConsoleLoginFlowController.sessionOverride =
                new Map<String, String>{ 'LoginType' => 'Application' };
            System.assertEquals(null,
                SalesConsoleLoginFlowController.decideTarget(),
                'without the permission the login is untouched');
        }
    }

    @IsTest
    static void loginFlowProceedNeverThrows() {
        User rep = makeRep('sso.rep.lf4@modon.example.test');
        grantConsolePermission(rep.Id);

        System.runAs(rep) {
            SalesConsoleLoginFlowController.sessionOverride =
                new Map<String, String>{ 'LoginType' => 'Application' };
            PageReference out = new SalesConsoleLoginFlowController().proceed();
            System.assertEquals(SalesConsoleLoginFlowController.GATEWAY,
                out.getUrl(), 'outside a real login flow, proceed falls back to the target');
        }
    }

    @IsTest
    static void gatewaySendsHolderToTheSiteSso() {
        User rep = makeRep('sso.rep.gate@modon.example.test');
        grantConsolePermission(rep.Id);

        System.runAs(rep) {
            PageReference target = new SalesConsoleSsoGatewayController().go();
            System.assertEquals(
                '/servlet/networks/switch?networkId=0DBVG0000003iZB',
                target.getUrl(),
                'holder must be sent to the network switch servlet, 15-char id'
            );
        }
    }

    @IsTest
    static void gatewaySendsEveryoneElseHome() {
        User rep = makeRep('sso.rep.home@modon.example.test');

        System.runAs(rep) {
            PageReference target = new SalesConsoleSsoGatewayController().go();
            System.assertEquals('/', target.getUrl(), 'non-holder goes to plain home');
        }
    }
}