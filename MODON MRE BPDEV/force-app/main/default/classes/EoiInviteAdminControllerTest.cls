/**********************************************************************************************************************
* Name               : EoiInviteAdminControllerTest
* Description        : Test coverage for EoiInviteAdminController. Exercises generateInviteLink for a normal lead,
*                      a confirmed lead, custom expiry, missing-lead error.
* Created By         : Prateek Bansal
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment
* 1.0           Prateek Bansal                    04 June 2026    Initial version
**********************************************************************************************************************/
@IsTest
private class EoiInviteAdminControllerTest {

    private static final String TEST_SECRET = 'test-secret-base64-payload-abcdef1234567890';

    @IsTest
    static void generateInviteLinkHappyPath() {
        InviteTokenSigner.secretOverride = TEST_SECRET;
        Lead l = newLead('Admin', 'HappyPath', 'ahp@example.com', '+971501234567', false);

        Test.startTest();
        EoiInviteAdminController.InviteLinkResult result = EoiInviteAdminController.generateInviteLink(l.Id, null);
        Test.stopTest();

        System.assertEquals(l.Id, result.leadId);
        System.assert(String.isNotBlank(result.token), 'Token should be generated.');
        System.assert(String.isNotBlank(result.url), 'URL should be built.');
        System.assert(result.url.contains('/invite?token='), 'URL should contain invite path.');
        System.assertNotEquals(null, result.expiresAt);
        System.assertEquals(false, result.alreadyConfirmed);
    }

    @IsTest
    static void generateInviteLinkFlagsAlreadyConfirmed() {
        InviteTokenSigner.secretOverride = TEST_SECRET;
        Lead l = newLead('Locked', 'Lead', 'll@example.com', null, true);

        EoiInviteAdminController.InviteLinkResult result = EoiInviteAdminController.generateInviteLink(l.Id, null);
        System.assertEquals(true, result.alreadyConfirmed);
        System.assertNotEquals(null, result.confirmedAt);
    }

    @IsTest
    static void generateInviteLinkWithCustomExpiry() {
        InviteTokenSigner.secretOverride = TEST_SECRET;
        Lead l = newLead('Custom', 'Expiry', 'ce@example.com', null, false);

        EoiInviteAdminController.InviteLinkResult result = EoiInviteAdminController.generateInviteLink(l.Id, 3);
        System.assert(result.expiresAt < System.now().addDays(4));
        System.assert(result.expiresAt > System.now().addDays(2));
    }

    @IsTest
    static void generateInviteLinkThrowsForNullLeadId() {
        InviteTokenSigner.secretOverride = TEST_SECRET;
        try {
            EoiInviteAdminController.generateInviteLink((Id) null, null);
            System.assert(false, 'Expected AuraHandledException for null Lead Id.');
        } catch (AuraHandledException ex) {
            System.assert(String.isNotBlank(ex.getMessage()));
        }
    }

    private static Lead newLead(String firstName, String lastName, String email, String mobile, Boolean confirmed) {
        Lead l = new Lead(
            FirstName = firstName, LastName = lastName,
            Email = email, MobilePhone = mobile,
            Company = 'Test', Status = 'New'
        );
        if (confirmed) {
            l.Site_Confirmed__c = true;
            l.Site_Confirmed_At__c = System.now().addHours(-1);
        }
        Schema.SObjectField projectInterest = Schema.getGlobalDescribe().get('Lead').getDescribe().fields.getMap().get('ProjectInterest__c');
        if (projectInterest != null && projectInterest.getDescribe().getType() == Schema.DisplayType.Picklist) {
            for (Schema.PicklistEntry e : projectInterest.getDescribe().getPicklistValues()) {
                if (e.isActive()) { l.put('ProjectInterest__c', e.getValue()); break; }
            }
        }
        insert l;
        return l;
    }

    @IsTest
    static void generateInviteLinkThrowsForMissingLead() {
        InviteTokenSigner.secretOverride = TEST_SECRET;
        Id fakeId = '00Q000000000001AAA';
        try {
            EoiInviteAdminController.generateInviteLink(fakeId, null);
            System.assert(false, 'Expected AuraHandledException for missing Lead.');
        } catch (AuraHandledException ex) {
            System.assert(String.isNotBlank(ex.getMessage()));
        }
    }
}