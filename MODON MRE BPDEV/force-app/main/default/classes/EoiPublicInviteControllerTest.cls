/**********************************************************************************************************************
* Name               : EoiPublicInviteControllerTest
* Description        : Test coverage for EoiPublicInviteController. Exercises resolveInvite (valid / expired / invalid /
*                      already-confirmed), startVerification, confirmInvite (happy path, lock semantics, missing OTP,
*                      missing range, inactive range).
* Created By         : Prateek Bansal
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment
* 1.0           Prateek Bansal                    04 June 2026    Initial version
**********************************************************************************************************************/
@IsTest
private class EoiPublicInviteControllerTest {

    private static final String TEST_SECRET = 'test-secret-base64-payload-abcdef1234567890';

    @IsTest
    static void resolveInviteHappyPath() {
        InviteTokenSigner.secretOverride = TEST_SECRET;
        Lead l = createLead('Happy', 'Path', 'hp@example.com', '+971501234567');
        String token = InviteTokenSigner.generate(l.Id);

        Test.startTest();
        EoiPublicInviteController.InviteContext ctx = EoiPublicInviteController.resolveInvite(token);
        Test.stopTest();

        System.assertEquals(true, ctx.valid);
        System.assertEquals(false, ctx.alreadyConfirmed);
        System.assertEquals(l.Id, ctx.leadId);
        System.assertEquals('Happy', ctx.firstName);
        System.assertEquals('hp@example.com', ctx.email);
    }

    @IsTest
    static void resolveInviteReturnsInvalidForBlankToken() {
        InviteTokenSigner.secretOverride = TEST_SECRET;
        EoiPublicInviteController.InviteContext ctx = EoiPublicInviteController.resolveInvite('');
        System.assertEquals(false, ctx.valid);
        System.assert(String.isNotBlank(ctx.message));
    }

    @IsTest
    static void resolveInviteReturnsInvalidForTamperedToken() {
        InviteTokenSigner.secretOverride = TEST_SECRET;
        Lead l = createLead('Tampered', 'Token', 'tt@example.com', '+971501234567');
        String token = InviteTokenSigner.generate(l.Id);
        String tampered = token.substring(0, token.length() - 4) + 'XXXX';

        EoiPublicInviteController.InviteContext ctx = EoiPublicInviteController.resolveInvite(tampered);
        System.assertEquals(false, ctx.valid);
    }

    @IsTest
    static void resolveInviteFlagsAlreadyConfirmed() {
        InviteTokenSigner.secretOverride = TEST_SECRET;
        Lead l = createLead('Already', 'Confirmed', 'ac@example.com', '+971501234567');
        l.Site_Confirmed__c = true;
        l.Site_Confirmed_At__c = System.now().addHours(-2);
        update l;
        String token = InviteTokenSigner.generate(l.Id);

        EoiPublicInviteController.InviteContext ctx = EoiPublicInviteController.resolveInvite(token);
        System.assertEquals(true, ctx.valid);
        System.assertEquals(true, ctx.alreadyConfirmed);
        System.assertNotEquals(null, ctx.confirmedAt);
    }

    @IsTest
    static void confirmInviteHappyPath() {
        InviteTokenSigner.secretOverride = TEST_SECRET;
        SObject project = createProject('HGE UAT Invite');
        SObject phase = createPhase('Phase 1', (Id) project.get('Id'));
        SObject range = createEoiRange((Id) project.get('Id'), (Id) phase.get('Id'));
        Lead l = createLead('Confirm', 'Happy', 'ch@example.com', '+971501234567');
        String token = InviteTokenSigner.generate(l.Id);
        Verification_Request__c v = createVerifiedRequest('ch@example.com', 'Email');

        EoiPublicInviteController.ConfirmRequest req = new EoiPublicInviteController.ConfirmRequest();
        req.token = token;
        req.verificationRequestId = v.Id;
        req.rangeId = (Id) range.get('Id');
        req.firstName = 'Confirm';
        req.lastName = 'Happy';
        req.email = 'ch@example.com';
        req.mobile = '+971501234567';
        req.residentStatus = 'Resident';
        req.emiratesId = '784-1990-1234567-1';

        Test.startTest();
        EoiPublicInviteController.ConfirmResult result = EoiPublicInviteController.confirmInvite(req);
        Test.stopTest();

        System.assertEquals(true, result.success);
        System.assertEquals(false, result.alreadyConfirmed);
        Lead reloaded = [SELECT Site_Confirmed__c, Selected_Typology__c, Site_Confirmed_At__c FROM Lead WHERE Id = :l.Id];
        System.assertEquals(true, reloaded.Site_Confirmed__c);
        System.assertEquals((Id) range.get('Id'), reloaded.Selected_Typology__c);
        System.assertNotEquals(null, reloaded.Site_Confirmed_At__c);
    }

    @IsTest
    static void confirmInviteReturnsLockedWhenAlreadyConfirmed() {
        InviteTokenSigner.secretOverride = TEST_SECRET;
        SObject project = createProject('HGE UAT Lock');
        SObject phase = createPhase('Phase 1', (Id) project.get('Id'));
        SObject range = createEoiRange((Id) project.get('Id'), (Id) phase.get('Id'));
        Lead l = createLead('Lock', 'Test', 'lt@example.com', '+971501234567');
        l.Site_Confirmed__c = true;
        l.Site_Confirmed_At__c = System.now().addHours(-1);
        update l;
        String token = InviteTokenSigner.generate(l.Id);
        Verification_Request__c v = createVerifiedRequest('lt@example.com', 'Email');

        EoiPublicInviteController.ConfirmRequest req = new EoiPublicInviteController.ConfirmRequest();
        req.token = token;
        req.verificationRequestId = v.Id;
        req.rangeId = (Id) range.get('Id');

        EoiPublicInviteController.ConfirmResult result = EoiPublicInviteController.confirmInvite(req);
        System.assertEquals(false, result.success);
        System.assertEquals(true, result.alreadyConfirmed);
    }

    @IsTest
    static void confirmInviteThrowsWithoutVerification() {
        InviteTokenSigner.secretOverride = TEST_SECRET;
        SObject project = createProject('HGE UAT NoOTP');
        SObject phase = createPhase('Phase 1', (Id) project.get('Id'));
        SObject range = createEoiRange((Id) project.get('Id'), (Id) phase.get('Id'));
        Lead l = createLead('NoOtp', 'Test', 'no@example.com', '+971501234567');
        String token = InviteTokenSigner.generate(l.Id);

        EoiPublicInviteController.ConfirmRequest req = new EoiPublicInviteController.ConfirmRequest();
        req.token = token;
        req.rangeId = (Id) range.get('Id');

        try {
            EoiPublicInviteController.confirmInvite(req);
            System.assert(false, 'Expected AuraHandledException for missing verification.');
        } catch (AuraHandledException ex) {
            System.assert(String.isNotBlank(ex.getMessage()));
        }
    }

    @IsTest
    static void confirmInviteThrowsWithoutRange() {
        InviteTokenSigner.secretOverride = TEST_SECRET;
        Lead l = createLead('NoRange', 'Test', 'nr@example.com', '+971501234567');
        String token = InviteTokenSigner.generate(l.Id);
        Verification_Request__c v = createVerifiedRequest('nr@example.com', 'Email');

        EoiPublicInviteController.ConfirmRequest req = new EoiPublicInviteController.ConfirmRequest();
        req.token = token;
        req.verificationRequestId = v.Id;
        req.rangeId = null;

        try {
            EoiPublicInviteController.confirmInvite(req);
            System.assert(false, 'Expected AuraHandledException for missing range.');
        } catch (AuraHandledException ex) {
            System.assert(String.isNotBlank(ex.getMessage()));
        }
    }

    @IsTest
    static void confirmInviteThrowsForInactiveRange() {
        InviteTokenSigner.secretOverride = TEST_SECRET;
        SObject project = createProject('HGE UAT Inactive');
        SObject phase = createPhase('Phase 1', (Id) project.get('Id'));
        SObject range = Schema.getGlobalDescribe().get('EOI_Range__c').newSObject();
        range.put('Project__c', (Id) project.get('Id'));
        range.put('Phase__c', (Id) phase.get('Id'));
        range.put('Unit_Type__c', 'Villa');
        range.put('No_of_Bedrooms__c', '3 Bedrooms');
        range.put('Amount__c', 650000);
        range.put('Is_Active__c', false);
        range.put('Applicable_for_Broker__c', true);
        insert range;

        Lead l = createLead('Inactive', 'Range', 'ir@example.com', '+971501234567');
        String token = InviteTokenSigner.generate(l.Id);
        Verification_Request__c v = createVerifiedRequest('ir@example.com', 'Email');

        EoiPublicInviteController.ConfirmRequest req = new EoiPublicInviteController.ConfirmRequest();
        req.token = token;
        req.verificationRequestId = v.Id;
        req.rangeId = (Id) range.get('Id');

        try {
            EoiPublicInviteController.confirmInvite(req);
            System.assert(false, 'Expected AuraHandledException for inactive range.');
        } catch (AuraHandledException ex) {
            System.assert(String.isNotBlank(ex.getMessage()));
        }
    }

    @IsTest
    static void startVerificationThrowsWithoutContact() {
        InviteTokenSigner.secretOverride = TEST_SECRET;
        Lead l = createLead('Empty', 'Contact', null, null);
        String token = InviteTokenSigner.generate(l.Id);

        try {
            EoiPublicInviteController.startVerification(token, 'Email', 'sess-1', null);
            System.assert(false, 'Should throw when Lead has no email and no target provided.');
        } catch (AuraHandledException ex) {
            System.assert(String.isNotBlank(ex.getMessage()));
        }
    }

    @IsTest
    static void resolveInviteReturnsInvalidWhenLeadMissing() {
        InviteTokenSigner.secretOverride = TEST_SECRET;
        // Generate a token for a Lead Id that exists, then delete the Lead
        Lead l = createLead('Will', 'Delete', 'wd@example.com', '+971501234567');
        String token = InviteTokenSigner.generate(l.Id);
        delete l;

        EoiPublicInviteController.InviteContext ctx = EoiPublicInviteController.resolveInvite(token);
        System.assertEquals(false, ctx.valid);
    }

    private static Lead createLead(String firstName, String lastName, String email, String mobile) {
        Lead l = new Lead(
            FirstName = firstName, LastName = lastName,
            Email = email, MobilePhone = mobile,
            Company = 'Test', Status = 'New'
        );
        Schema.SObjectField projectInterest = Schema.getGlobalDescribe().get('Lead').getDescribe().fields.getMap().get('ProjectInterest__c');
        if (projectInterest != null && projectInterest.getDescribe().getType() == Schema.DisplayType.Picklist) {
            for (Schema.PicklistEntry e : projectInterest.getDescribe().getPicklistValues()) {
                if (e.isActive()) { l.put('ProjectInterest__c', e.getValue()); break; }
            }
        }
        insert l;
        return l;
    }

    private static SObject createProject(String name) {
        SObject p = Schema.getGlobalDescribe().get('Project__c').newSObject();
        p.put('Name', name);
        if (Schema.getGlobalDescribe().get('Project__c').getDescribe().fields.getMap().containsKey('EOI_Limit__c')) {
            p.put('EOI_Limit__c', 5);
        }
        insert p;
        return p;
    }

    private static SObject createPhase(String name, Id projectId) {
        SObject ph = Schema.getGlobalDescribe().get('Phase__c').newSObject();
        ph.put('Name', name);
        if (Schema.getGlobalDescribe().get('Phase__c').getDescribe().fields.getMap().containsKey('Project__c')) {
            ph.put('Project__c', projectId);
        }
        insert ph;
        return ph;
    }

    private static SObject createEoiRange(Id projectId, Id phaseId) {
        SObject r = Schema.getGlobalDescribe().get('EOI_Range__c').newSObject();
        r.put('Project__c', projectId);
        r.put('Phase__c', phaseId);
        r.put('Unit_Type__c', 'Villa');
        r.put('No_of_Bedrooms__c', '3 Bedrooms');
        r.put('Amount__c', 650000);
        r.put('Is_Active__c', true);
        r.put('Applicable_for_Broker__c', true);
        r.put('Show_On__c', 'Invite Microsite');
        insert r;
        return r;
    }

    @IsTest
    static void getInviteTilesReturnsOnlyInviteVisibleRanges() {
        InviteTokenSigner.secretOverride = TEST_SECRET;
        SObject project = createProject('HGE Tiles');
        SObject phase = createPhase('Phase 1', (Id) project.get('Id'));
        SObject visibleRange = createEoiRange((Id) project.get('Id'), (Id) phase.get('Id'));

        SObject hiddenRange = Schema.getGlobalDescribe().get('EOI_Range__c').newSObject();
        hiddenRange.put('Project__c', (Id) project.get('Id'));
        hiddenRange.put('Phase__c', (Id) phase.get('Id'));
        hiddenRange.put('Unit_Type__c', 'Villa');
        hiddenRange.put('No_of_Bedrooms__c', '4 Bedrooms');
        hiddenRange.put('Amount__c', 850000);
        hiddenRange.put('Is_Active__c', true);
        hiddenRange.put('Applicable_for_Broker__c', true);
        hiddenRange.put('Show_On__c', 'Public Microsite');
        insert hiddenRange;

        List<EoiPublicInviteController.InviteTile> tiles =
            EoiPublicInviteController.getInviteTiles((Id) project.get('Id'));

        System.assertEquals(1, tiles.size(), 'Only Invite-Microsite-visible ranges should be returned.');
        System.assertEquals(visibleRange.get('Id'), tiles[0].rangeId);
    }

    private static Verification_Request__c createVerifiedRequest(String target, String channel) {
        Verification_Request__c v = new Verification_Request__c(
            Channel__c = channel,
            Target__c = target,
            Masked_Target__c = target.substringBefore('@').left(1) + '***@' + target.substringAfter('@'),
            Status__c = 'Verified',
            Context__c = 'EOI_INVITE',
            Expires_At__c = System.now().addMinutes(5),
            Verified_At__c = System.now()
        );
        insert v;
        return v;
    }
}