/**********************************************************************************************************************
* Name               : ADHA_MasterplanControllerTest
* Description        : Covers the masterplan payload - eligibility filtering, geometry pass-through, and the session
*                      token check that replaced the client-supplied application number.
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           Aurelix                     13 Aug 2026     Initial draft.
* 1.1           Aurelix                     31 Aug 2026     Fixtures are customer stock; executive stock is
*                                                             a separate pool a customer never receives.
***********************************************************************************************************************/
@isTest
private class ADHA_MasterplanControllerTest {

    private static final String CODE = '123456';

    @TestSetup
    static void setup() {
        insert new ADHA_Applicant__c(
            Application_Number__c = 'T0000002',
            Emirates_ID__c = '784-1980-2222222-2',
            Customer_Name__c = 'Grant Applicant',
            Mobile_Number__c = '+971500000002',
            Service_Type__c = 'House Grant',
            Eligible_Categories__c = 'A',
            Approved_Loan_Amount__c = 1750000,
            Journey_Stage__c = 'Invited'
        );

        List<ADHA_Unit__c> units = new List<ADHA_Unit__c>();
        // Eligible: category A on House Grant.
        units.add(unit('MP-1', 'A', 'House Grant', 1, 'Available'));
        units.add(unit('MP-2', 'A', 'House Grant', 2, 'Reserved'));
        // Wrong category.
        units.add(unit('MP-3', 'B', 'House Grant', 3, 'Available'));
        // Wrong service.
        units.add(unit('MP-4', 'A', 'House Purchase Loan', 4, 'Available'));
        insert units;

        // Mapped to nothing on the plan - must be skipped rather than drawn at the origin.
        insert new ADHA_Unit__c(
            Plot_UID__c = 'MP-5', Category_Type__c = 'A', Eligible_Service__c = 'House Grant',
            Villa_Type__c = 'Modern', Community__c = 'Wb2_01', Status__c = 'Available',
            Expose_To__c = 'Public', Rooms_Count__c = 5, Balconies_Count__c = 3
        );
    }

    private static ADHA_Unit__c unit(String uid, String category, String service, Integer planNumber, String status) {
        return new ADHA_Unit__c(
            Plot_UID__c = uid,
            Category_Type__c = category,
            Eligible_Service__c = service,
            Villa_Type__c = 'Modern',
            Community__c = 'Wb2_01',
            Masterplan_Features__c = 'Double row middle',
            Status__c = status,
            // These are customer stock. A taken villa is Public with a non-Available
            // status; Expose_To Reserved means executive stock, which a customer never receives.
            Expose_To__c = 'Public',
            Masterplan_Number__c = planNumber,
            Map_Polygon__c = '[[0.1,0.1],[0.2,0.1],[0.2,0.2]]',
            Centroid_X__c = 0.15,
            Centroid_Y__c = 0.15,
            Rooms_Count__c = 5,
            Balconies_Count__c = 3,
            House_Size__c = 450,
            Calculated_Area__c = 1000,
            Price__c = 1800000,
            Mapping_Status__c = 'Provisional'
        );
    }

    private static String tokenForApplicant() {
        ADHA_Applicant__c a = [SELECT Id FROM ADHA_Applicant__c LIMIT 1];
        Verification_Request__c v = new Verification_Request__c(
            Channel__c = 'SMS', Target__c = '+971500000002', Masked_Target__c = '+9715****0002',
            Code_Hash__c = EncodingUtil.convertToHex(
                Crypto.generateDigest('SHA-256', Blob.valueOf(CODE + '|' + UserInfo.getOrganizationId()))),
            Status__c = 'Pending', Context__c = 'ADHA_BANIYAS', Context_Key__c = String.valueOf(a.Id),
            Expires_At__c = System.now().addMinutes(10), Attempts__c = 0, Max_Attempts__c = 5,
            Resend_Count__c = 0, Max_Resends__c = 3
        );
        insert v;
        return ADHA_JourneyController.verifyCode(v.Id, CODE).token;
    }

    @isTest
    static void sessionScopesTheMapToTheCustomersEligibleUnits() {
        String token = tokenForApplicant();

        Test.startTest();
        ADHA_MasterplanController.MasterplanData data = ADHA_MasterplanController.getMasterplan(token);
        Test.stopTest();

        System.assertEquals(4, data.totalUnits, 'The unmapped unit is skipped, the other four are drawn');
        System.assertEquals(2, data.eligibleUnits, 'Category A on House Grant only');
        System.assertEquals('Grant Applicant', data.applicant.customerName);

        Map<String, ADHA_MasterplanController.UnitDTO> byUid =
            new Map<String, ADHA_MasterplanController.UnitDTO>();
        for (ADHA_MasterplanController.UnitDTO d : data.units) {
            byUid.put(d.plotUid, d);
        }
        System.assertEquals(true, byUid.get('MP-1').eligible, 'Right category and service');
        System.assertEquals(true, byUid.get('MP-1').selectable, 'Available and eligible');
        System.assertEquals(false, byUid.get('MP-2').selectable, 'Reserved is not selectable');
        System.assertEquals(false, byUid.get('MP-3').eligible, 'Wrong category');
        System.assertEquals(false, byUid.get('MP-4').eligible, 'Wrong service type');
        System.assertEquals(false, byUid.containsKey('MP-5'), 'No geometry means it cannot be drawn');
    }

    /** The guest sharing rule shares the whole plan now, so this filter is the only
     *  thing keeping executive stock off a customer's map. */
    @isTest
    static void executiveStockNeverReachesACustomer() {
        insert new ADHA_Unit__c(
            Plot_UID__c = 'MP-9', Category_Type__c = 'A', Eligible_Service__c = 'House Grant',
            Villa_Type__c = 'Modern', Community__c = 'Wb2_01', Status__c = 'Reserved',
            Expose_To__c = 'Reserved', Masterplan_Number__c = 9,
            Map_Polygon__c = '[[0.1,0.1],[0.2,0.1],[0.2,0.2]]',
            Centroid_X__c = 0.15, Centroid_Y__c = 0.15,
            Rooms_Count__c = 5, Balconies_Count__c = 3, House_Size__c = 450,
            Calculated_Area__c = 1000, Price__c = 1800000, Mapping_Status__c = 'Provisional'
        );
        String token = tokenForApplicant();

        Test.startTest();
        ADHA_MasterplanController.MasterplanData data = ADHA_MasterplanController.getMasterplan(token);
        ADHA_MasterplanController.Availability avail = ADHA_MasterplanController.getAvailability(token);
        Test.stopTest();

        for (ADHA_MasterplanController.UnitDTO d : data.units) {
            System.assertNotEquals('MP-9', d.plotUid, 'executive stock is not a customer villa');
        }
        System.assertEquals(4, data.totalUnits, 'the customer map is unchanged by executive stock');
        System.assertEquals(2, data.eligibleUnits, 'and so is the count they are shown');
        System.assert(!new Set<String>(avail.taken).contains('MP-9'),
            'the poll never names a villa the map did not draw');
    }

    @isTest
    static void deferredLoanCustomersBookFromHousePurchaseLoanStock() {
        update new ADHA_Applicant__c(
            Id = [SELECT Id FROM ADHA_Applicant__c LIMIT 1].Id,
            Service_Type__c = 'House Purchase Deferred Loan'
        );
        String token = tokenForApplicant();

        Test.startTest();
        ADHA_MasterplanController.MasterplanData data = ADHA_MasterplanController.getMasterplan(token);
        Test.stopTest();

        System.assertEquals(1, data.eligibleUnits, 'HPDL maps onto House Purchase Loan inventory');
    }

    @isTest
    static void facetFieldsReachTheClient() {
        String token = tokenForApplicant();

        Test.startTest();
        ADHA_MasterplanController.MasterplanData data = ADHA_MasterplanController.getMasterplan(token);
        Test.stopTest();

        for (ADHA_MasterplanController.UnitDTO d : data.units) {
            if (d.plotUid == 'MP-1') {
                System.assertEquals('Wb2_01', d.community, 'Location facet');
                System.assertEquals('Double row middle', d.position, 'Plot position facet');
                System.assertEquals(5, d.bedrooms, 'Bedrooms facet');
                System.assertEquals(3, d.balconies, 'Balconies facet');
                System.assertEquals(true, d.provisional, 'Provisional mapping must stay visible');
            }
        }
    }

    /** Rubbish must be rejected, not quietly downgraded to the everything-is-eligible preview. */
    @isTest
    static void invalidTokenIsRejectedRatherThanTreatedAsPreview() {
        Boolean rejected = false;
        Test.startTest();
        try {
            ADHA_MasterplanController.getMasterplan('not-a-real-token');
        } catch (Exception e) {
            rejected = true;
        }
        Test.stopTest();
        System.assert(rejected, 'An invalid token must not fall through to preview mode');
    }

    /** The regression that prompted this: a refresh dropped the token, and a blank token used to
     *  mean "show everything", so the customer saw the entire inventory as eligible. */
    @isTest
    static void blankTokenIsRejectedRatherThanShowingEverything() {
        Boolean rejectedNull = false, rejectedEmpty = false;
        Test.startTest();
        try {
            ADHA_MasterplanController.getMasterplan(null);
        } catch (Exception e) {
            rejectedNull = true;
        }
        try {
            ADHA_MasterplanController.getMasterplan('');
        } catch (Exception e) {
            rejectedEmpty = true;
        }
        Test.stopTest();
        System.assert(rejectedNull, 'A null token must not return inventory');
        System.assert(rejectedEmpty, 'A blank token must not return inventory');
    }

    /** The demo sentinel is gone. A guessable word must not read the inventory. */
    @isTest
    static void theWordPreviewIsNoLongerAToken() {
        Boolean rejected = false;
        Test.startTest();
        try {
            ADHA_MasterplanController.getMasterplan('PREVIEW');
        } catch (Exception e) {
            rejected = true;
        }
        Test.stopTest();
        System.assert(rejected, 'PREVIEW must be treated as a forged token, not a bypass');
    }

    /** An applicant with no service type must match nothing - null == null is true in Apex. */
    @isTest
    static void aBlankServiceTypeMatchesNoVilla() {
        ADHA_Unit__c unmapped = new ADHA_Unit__c(Category_Type__c = 'A', Eligible_Service__c = null);
        System.assertEquals(
            false,
            ADHA_MasterplanController.isEligible(new Set<String>{ 'A' }, null, unmapped),
            'A blank service type must not match a blank Eligible_Service__c'
        );
    }

    /** A refresh must keep the customer scoped to their own units. */
    @isTest
    static void resumedSessionStillScopesTheMap() {
        String token = tokenForApplicant();

        Test.startTest();
        ADHA_JourneyController.Session resumed = ADHA_JourneyController.resumeSession(token);
        ADHA_MasterplanController.MasterplanData data =
            ADHA_MasterplanController.getMasterplan(resumed.token);
        Test.stopTest();

        System.assertEquals(token, resumed.token, 'resumeSession must return a usable token');
        System.assertEquals(2, data.eligibleUnits, 'Still only this customer eligible units');
        System.assertNotEquals(data.totalUnits, data.eligibleUnits,
            'A resumed session must not see the whole inventory as eligible');
    }

    /* ---------- keeping the map current ---------- */

    /** Split out of getMasterplan so availability is fetchable without dragging 1,659 polygons. */
    @isTest
    static void availabilityNamesOnlyWhatNobodyCanTake() {
        String token = tokenForApplicant();

        Test.startTest();
        ADHA_MasterplanController.Availability result =
            ADHA_MasterplanController.getAvailability(token);
        Test.stopTest();

        Set<String> taken = new Set<String>(result.taken);
        System.assert(taken.contains('MP-2'), 'A reserved villa is not takeable');
        System.assert(!taken.contains('MP-1'), 'An available one is');
        // Ineligible for this customer, but still free, so it belongs to nobody. The client only
        // paints what it drew, so a plot it never drew costs nothing to name.
        System.assert(!taken.contains('MP-3'), 'Eligibility is not availability');
        System.assertNotEquals(null, result.asOf, 'The client shows how fresh this is');
    }

    /** A villa taken between two calls has to show up on the second, or the poll is pointless. */
    @isTest
    static void availabilityMovesWhenAVillaIsTaken() {
        String token = tokenForApplicant();

        Test.startTest();
        Integer before = ADHA_MasterplanController.getAvailability(token).taken.size();
        update new ADHA_Unit__c(
            Id = [SELECT Id FROM ADHA_Unit__c WHERE Plot_UID__c = 'MP-1' LIMIT 1].Id,
            Status__c = 'Reserved'
        );
        List<String> after = ADHA_MasterplanController.getAvailability(token).taken;
        Test.stopTest();

        System.assertEquals(before + 1, after.size(), 'The list has to move with the inventory');
        System.assert(new Set<String>(after).contains('MP-1'), 'And name the villa that went');
    }

    /** The cadence rides on the response so the setting can be changed without a page load. */
    @isTest
    static void theClientIsToldHowOftenToComeBack() {
        String token = tokenForApplicant();
        ADHA_JourneyController.settingsCache = new ADHA_Setting__mdt(Availability_Poll_Seconds__c = 90);

        Test.startTest();
        Integer seconds = ADHA_MasterplanController.getAvailability(token).pollSeconds;
        Test.stopTest();

        System.assertEquals(90, seconds, 'The server owns the cadence');
    }

    @isTest
    static void aPollFasterThanTenSecondsIsRefused() {
        String token = tokenForApplicant();
        ADHA_JourneyController.settingsCache = new ADHA_Setting__mdt(Availability_Poll_Seconds__c = 2);

        Test.startTest();
        Integer seconds = ADHA_MasterplanController.getAvailability(token).pollSeconds;
        Test.stopTest();

        System.assertEquals(10, seconds, 'Two seconds is a load test, not a refresh');
    }

    @isTest
    static void zeroSwitchesThePollOffRatherThanDefaulting() {
        String token = tokenForApplicant();
        ADHA_JourneyController.settingsCache = new ADHA_Setting__mdt(Availability_Poll_Seconds__c = 0);

        Test.startTest();
        Integer seconds = ADHA_MasterplanController.getAvailability(token).pollSeconds;
        Test.stopTest();

        System.assertEquals(0, seconds, 'Zero is the lever to pull on a bad day');
    }

    /** Same gate as getMasterplan. Inventory never goes to a caller we cannot identify. */
    @isTest
    static void availabilityRefusesACallerWithNoSession() {
        Test.startTest();
        String blank = refusalFromAvailability('');
        String forged = refusalFromAvailability('not-a-real-token');
        Test.stopTest();

        System.assertNotEquals(null, blank, 'A blank token must be refused');
        System.assertNotEquals(null, forged, 'So must a forged one');
    }

    private static String refusalFromAvailability(String token) {
        try {
            ADHA_MasterplanController.getAvailability(token);
        } catch (Exception e) {
            return e.getMessage();
        }
        return null;
    }
}