/**********************************************************************************************************************
* Name               : ADHA_PinningTest
* Description        : Pinning end to end: the double gate, the map flags, the booking gate, the
*                      validation rule, sweeper hygiene, and that the assignee never leaks into a DTO.
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           Aurelix                     29 Aug 2026     Initial.
* 1.1           Aurelix                     29 Aug 2026     markExploring must skip ops.
* 1.2           Aurelix                     30 Aug 2026     Guard refusals, pin aging, ops map flag.
* 1.3           Aurelix                     31 Aug 2026     The reserve boundary is Apex now, not the sharing rule.
**********************************************************************************************************************/
@isTest
private class ADHA_PinningTest {

    private static final String CODE = '123456';
    private static final String OPS_EID = '784-1970-0000001-1';

    @TestSetup
    static void setup() {
        insert new List<ADHA_Applicant__c>{
            applicant('P0000001', '784-1980-1111111-1', 'Customer One', '+971500000101', false),
            applicant('P0000002', '784-1980-2222222-2', 'Customer Two', '+971500000102', false),
            applicant('P0000009', OPS_EID, 'Ops Person', '+971500000109', true)
        };
        insert new List<ADHA_Unit__c>{
            // The reserve pool ops assigns from: parked, invisible to customers.
            unit('PIN-1', 'A', 'House Grant', 1, 'Reserved', 'Reserved'),
            // Never assignable: MV stock stays blocked whatever anyone asks.
            unit('PIN-2', 'A', 'House Grant', 2, 'Blocked', 'MV-Reserved'),
            // Wrong category for our applicants - the eligibility override case.
            unit('PIN-3', 'B', 'House Grant', 3, 'Reserved', 'Reserved'),
            unit('PIN-4', 'A', 'House Grant', 4, 'Reserved', 'Reserved'),
            // Public customer stock: bookable by anyone eligible, assignable by nobody.
            unit('PIN-5', 'A', 'House Grant', 5, 'Available', 'Public')
        };
    }

    private static ADHA_Applicant__c applicant(String appNo, String eid, String name, String mobile, Boolean ops) {
        return new ADHA_Applicant__c(
            Application_Number__c = appNo, Emirates_ID__c = eid, Customer_Name__c = name,
            Mobile_Number__c = mobile, Service_Type__c = 'House Grant',
            Eligible_Categories__c = 'A', Approved_Loan_Amount__c = 1750000,
            Journey_Stage__c = 'Invited', Is_Ops__c = ops
        );
    }

    /** Exposure is explicit now - Public is customer stock, Reserved is the pool ops
     *  assigns from, MV-Reserved is never touchable. */
    private static ADHA_Unit__c unit(String uid, String category, String service, Integer planNumber,
                                     String status, String exposeTo) {
        return new ADHA_Unit__c(
            Plot_UID__c = uid, Category_Type__c = category, Eligible_Service__c = service,
            Villa_Type__c = 'Modern', Community__c = 'Wb2_01', Status__c = status,
            Expose_To__c = exposeTo,
            Masterplan_Number__c = planNumber,
            Map_Polygon__c = '[[0.1,0.1],[0.2,0.1],[0.2,0.2]]',
            Centroid_X__c = 0.15, Centroid_Y__c = 0.15,
            Rooms_Count__c = 5, Balconies_Count__c = 3, House_Size__c = 450,
            Calculated_Area__c = 1000, Price__c = 1800000, Mapping_Status__c = 'Provisional'
        );
    }

    private static ADHA_Applicant__c byAppNo(String appNo) {
        return [SELECT Id, Application_Number__c, Emirates_ID__c, Is_Ops__c, Service_Type__c,
                       Eligible_Categories__c, Approved_Loan_Amount__c
                FROM ADHA_Applicant__c WHERE Application_Number__c = :appNo LIMIT 1];
    }

    /** Injected per test - statics reset between methods. */
    private static void settings(String opsList) {
        ADHA_JourneyController.settingsCache = new ADHA_Setting__mdt(
            Exploration_Mode__c = false, SLA_Days__c = 7, Max_Attempts__c = 2,
            Max_Unit_Changes__c = 2, Hold_Minutes__c = 10,
            Selectable_Statuses__c = 'Available',
            Ops_Emirates_Ids__c = opsList
        );
    }

    private static String tokenFor(String appNo) {
        ADHA_Applicant__c a = byAppNo(appNo);
        Verification_Request__c v = new Verification_Request__c(
            Channel__c = 'SMS', Target__c = '+971500000000', Masked_Target__c = '+9715****0000',
            Code_Hash__c = EncodingUtil.convertToHex(
                Crypto.generateDigest('SHA-256', Blob.valueOf(CODE + '|' + UserInfo.getOrganizationId()))),
            Status__c = 'Pending', Context__c = 'ADHA_BANIYAS', Context_Key__c = String.valueOf(a.Id),
            Expires_At__c = System.now().addMinutes(10), Attempts__c = 0, Max_Attempts__c = 5,
            Resend_Count__c = 0, Max_Resends__c = 3
        );
        insert v;
        return ADHA_JourneyController.verifyCode(v.Id, CODE).token;
    }

    private static void pinTo(String plotUid, String appNo) {
        ADHA_Unit__c u = [SELECT Id FROM ADHA_Unit__c WHERE Plot_UID__c = :plotUid LIMIT 1];
        u.Pinned_Applicant__c = byAppNo(appNo).Id;
        update u;
    }

    /* ---------- the double gate ---------- */

    @isTest
    static void opsNeedsBothTheFlagAndTheAllowlist() {
        settings(OPS_EID);
        System.assert(ADHA_JourneyController.isOps(byAppNo('P0000009')), 'flag AND listed: ops');
        System.assert(!ADHA_JourneyController.isOps(byAppNo('P0000001')), 'listed customers are not ops without the flag');

        settings('784-0000-0000000-0');
        System.assert(!ADHA_JourneyController.isOps(byAppNo('P0000009')), 'the flag alone is nothing when the list names somebody else');

        settings('');
        System.assert(!ADHA_JourneyController.isOps(byAppNo('P0000009')), 'a blank list means nobody, not everybody');
    }

    @isTest
    static void opsEndpointsRefuseANormalSession() {
        settings(OPS_EID);
        String customerToken = tokenFor('P0000001');
        Boolean threw = false;
        try {
            ADHA_PinController.searchApplicants(customerToken, 'Customer');
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assert(threw, 'to anyone who is not ops these endpoints do not exist');
    }

    @isTest
    static void anOpsSessionSkipsTheJourneyEntirely() {
        settings(OPS_EID);
        Test.startTest();
        String token = tokenFor('P0000009');
        Test.stopTest();
        System.assertNotEquals(null, token);
        ADHA_Applicant__c ops = byAppNo('P0000009');
        ADHA_Applicant__c full = [SELECT SLA_Start__c, Journey_Stage__c FROM ADHA_Applicant__c WHERE Id = :ops.Id];
        System.assertEquals(null, full.SLA_Start__c, 'ops is working, not on a journey: no clock');
        System.assertEquals('Invited', full.Journey_Stage__c, 'and no stage advance');
    }

    /* ---------- pin, unpin, conflict, audit surface ---------- */

    @isTest
    static void pinUnpinAndConflict() {
        settings(OPS_EID);
        String opsToken = tokenFor('P0000009');

        Test.startTest();
        ADHA_PinController.PinInfo p = ADHA_PinController.pin(opsToken, 'PIN-1', 'P0000001');
        Test.stopTest();
        System.assertEquals('waiting', p.pinStatus);
        System.assertEquals(byAppNo('P0000001').Id,
            [SELECT Pinned_Applicant__c FROM ADHA_Unit__c WHERE Plot_UID__c = 'PIN-1'].Pinned_Applicant__c);

        // Pinning it to somebody else is a conflict, not a silent steal.
        Boolean threw = false;
        try {
            ADHA_PinController.pin(opsToken, 'PIN-1', 'P0000002');
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assert(threw, 'a pinned villa cannot be quietly reassigned');

        ADHA_PinController.unpin(opsToken, 'PIN-1');
        System.assertEquals(null,
            [SELECT Pinned_Applicant__c FROM ADHA_Unit__c WHERE Plot_UID__c = 'PIN-1'].Pinned_Applicant__c);
        // Idempotent: unpinning again reveals nothing and throws nothing.
        ADHA_PinController.unpin(opsToken, 'PIN-1');
    }

    @isTest
    static void searchCarriesNoIdentityDocuments() {
        settings(OPS_EID);
        String opsToken = tokenFor('P0000009');
        List<ADHA_PinController.OpsApplicant> rows = ADHA_PinController.searchApplicants(opsToken, 'Customer');
        System.assertEquals(2, rows.size(), 'both customers, and never the ops record itself');
        String raw = JSON.serialize(rows);
        System.assert(!raw.contains('784-1980'), 'no Emirates IDs in an ops payload');
        System.assert(!raw.contains('+9715'), 'and no mobile numbers');
    }

    @isTest
    static void theValidationRuleRefusesAnythingOutsideTheReservePool() {
        // MV-Reserved: blocked stock nobody allocates.
        ADHA_Unit__c mv = [SELECT Id FROM ADHA_Unit__c WHERE Plot_UID__c = 'PIN-2' LIMIT 1];
        mv.Pinned_Applicant__c = byAppNo('P0000001').Id;
        Boolean mvThrew = false;
        try {
            update mv;
        } catch (DmlException e) {
            mvThrew = true;
            System.assert(e.getMessage().contains('reserve-stock'), 'the rule explains itself: ' + e.getMessage());
        }
        System.assert(mvThrew, 'MV stock is never assignable');

        // And public stock is the customer's to book, not ops's to hand out.
        ADHA_Unit__c pub = [SELECT Id FROM ADHA_Unit__c WHERE Plot_UID__c = 'PIN-5' LIMIT 1];
        pub.Pinned_Applicant__c = byAppNo('P0000001').Id;
        Boolean pubThrew = false;
        try {
            update pub;
        } catch (DmlException e) {
            pubThrew = true;
        }
        System.assert(pubThrew, 'a public villa cannot be assigned');
    }

    @isTest
    static void theBoardReportsEveryPinWithItsStatus() {
        settings(OPS_EID);
        String opsToken = tokenFor('P0000009');
        ADHA_PinController.pin(opsToken, 'PIN-1', 'P0000001');
        pinTo('PIN-3', 'P0000002');

        Test.startTest();
        List<ADHA_PinController.PinInfo> board = ADHA_PinController.board(opsToken);
        Test.stopTest();

        System.assertEquals(2, board.size(), 'every pin, nothing else');
        for (ADHA_PinController.PinInfo p : board) {
            System.assertEquals('waiting', p.pinStatus, p.plotUid + ' has no reservation yet');
            System.assertNotEquals(null, p.applicationNumber);
        }
    }

    @isTest
    static void searchAndPinRefuseJunkInput() {
        settings(OPS_EID);
        String opsToken = tokenFor('P0000009');

        System.assertEquals(0, ADHA_PinController.searchApplicants(opsToken, 'x').size(),
            'a one-character term searches nothing');
        System.assertEquals(0, ADHA_PinController.searchApplicants(opsToken, '  ').size());

        Boolean blankRefused = false;
        try {
            ADHA_PinController.pin(opsToken, '', 'P0000001');
        } catch (AuraHandledException e) {
            blankRefused = true;
        }
        System.assert(blankRefused, 'no villa named, nothing pinned');

        Boolean unknownRefused = false;
        try {
            ADHA_PinController.pin(opsToken, 'PIN-1', 'NO-SUCH');
        } catch (AuraHandledException e) {
            unknownRefused = true;
        }
        System.assert(unknownRefused, 'an unknown applicant pins nothing');

        Boolean unknownPlot = false;
        try {
            ADHA_PinController.pin(opsToken, 'NO-PLOT', 'P0000001');
        } catch (AuraHandledException e) {
            unknownPlot = true;
        }
        System.assert(unknownPlot, 'an unknown villa pins nothing');
    }

    /* ---------- The reserve pool is the whole working surface ---------- */

    @isTest
    static void opsAssignsReserveStockAndNothingElse() {
        settings(OPS_EID);
        String opsToken = tokenFor('P0000009');

        Test.startTest();
        // The pool: parked reserve stock takes a pin.
        ADHA_PinController.PinInfo p = ADHA_PinController.pin(opsToken, 'PIN-1', 'P0000001');
        // Public stock does not, however it is asked for.
        Boolean publicRefused = false;
        try {
            ADHA_PinController.pin(opsToken, 'PIN-5', 'P0000002');
        } catch (Exception e) {
            publicRefused = true;
        }
        Test.stopTest();

        System.assertEquals('PIN-1', p.plotUid, 'reserve stock is assignable');
        System.assert(publicRefused, 'public stock is the customer to book, never ops to hand out');
        System.assertEquals(null,
            [SELECT Pinned_Applicant__c FROM ADHA_Unit__c WHERE Plot_UID__c = 'PIN-5'].Pinned_Applicant__c);
    }

    @isTest
    static void theOpsMapOffersTheReservePoolAndTheCustomerMapHidesIt() {
        settings(OPS_EID);
        String opsToken = tokenFor('P0000009');
        String customerToken = tokenFor('P0000001');

        Test.startTest();
        ADHA_MasterplanController.MasterplanData ops = ADHA_MasterplanController.getMasterplan(opsToken);
        ADHA_MasterplanController.MasterplanData mine = ADHA_MasterplanController.getMasterplan(customerToken);
        Test.stopTest();

        for (ADHA_MasterplanController.UnitDTO d : ops.units) {
            if (d.plotUid == 'PIN-1') {
                System.assert(d.selectable, 'ops can assign parked reserve stock');
                System.assert(d.reserveStock, 'and the map paints it as the working pool');
            }
            if (d.plotUid == 'PIN-5') {
                System.assert(!d.selectable, 'public stock is not ops to assign');
            }
            if (d.plotUid == 'PIN-2') {
                System.assert(!d.selectable, 'MV stock is nobody\'s to assign');
            }
        }
        for (ADHA_MasterplanController.UnitDTO d : mine.units) {
            System.assert(d.reserveStock != true, 'the reserve flag never reaches a customer');
            System.assertNotEquals('PIN-1', d.plotUid,
                'reserve stock is absent from an unpinned customer\'s map, not merely unselectable');
        }
    }

    @isTest
    static void aPinnedApplicantBooksTheirReserveVilla() {
        settings(OPS_EID);
        pinTo('PIN-1', 'P0000001');
        ADHA_Applicant__c a = readyToBook('P0000001');

        Test.startTest();
        ADHA_MasterplanController.MasterplanData data =
            ADHA_MasterplanController.getMasterplan(tokenFor('P0000001'));
        ADHA_ReservationService.ReservationView view = ADHA_ReservationService.hold(a, 'PIN-1');
        Test.stopTest();

        for (ADHA_MasterplanController.UnitDTO d : data.units) {
            if (d.plotUid == 'PIN-1') {
                System.assertEquals('Available', d.status, 'the pin is the exposure grant');
                System.assert(d.selectable, 'so their reserve villa is bookable');
            }
        }
        System.assertEquals('PIN-1', view.plotUid, 'and the hold goes through');
    }

    @isTest
    static void anUnpinnedApplicantCannotBookReserveStock() {
        settings(OPS_EID);
        ADHA_Applicant__c a = readyToBook('P0000002');

        Test.startTest();
        Boolean threw = false;
        try {
            ADHA_ReservationService.hold(a, 'PIN-1');
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'reserve stock opens for its pinned applicant only');
    }

    @isTest
    static void theHolderOfATakenVillaIsVisibleToOpsOnly() {
        settings(OPS_EID);
        String opsToken = tokenFor('P0000009');
        ADHA_Applicant__c a = readyToBook('P0000001');
        ADHA_ReservationService.hold(a, 'PIN-5');

        Test.startTest();
        ADHA_PinController.HolderInfo held = ADHA_PinController.holder(opsToken, 'PIN-5');
        ADHA_PinController.HolderInfo free = ADHA_PinController.holder(opsToken, 'PIN-4');
        Test.stopTest();

        System.assertNotEquals(null, held, 'a taken villa names its holder for ops');
        System.assertEquals('P0000001', held.applicationNumber);
        System.assertEquals('booked', held.status);
        System.assertEquals(null, free, 'a free villa reveals nothing');

        // The same call from a customer token is refused outright.
        Boolean refused = false;
        try {
            ADHA_PinController.holder(tokenFor('P0000002'), 'PIN-5');
        } catch (Exception e) {
            refused = true;
        }
        System.assert(refused, 'holder details are an ops surface');
    }

    @isTest
    static void theCacheBustingEntryPointReturnsTheSamePayload() {
        settings(OPS_EID);
        String opsToken = tokenFor('P0000009');

        Test.startTest();
        ADHA_MasterplanController.MasterplanData direct =
            ADHA_MasterplanController.getMasterplan(opsToken);
        ADHA_MasterplanController.MasterplanData viaBuild =
            ADHA_MasterplanController.getMasterplanFor(opsToken, 'cr011');
        Test.stopTest();

        System.assertEquals(direct.units.size(), viaBuild.units.size(), 'same inventory either way');
        System.assert(viaBuild.applicant.isOps, 'and the same ops context');
        Boolean sawReserve = false;
        for (ADHA_MasterplanController.UnitDTO d : viaBuild.units) {
            if (d.plotUid == 'PIN-1') {
                sawReserve = true;
                System.assert(d.reserveStock, 'the flag the client keys its paint on');
                System.assert(d.selectable, 'and parked reserve stock is assignable');
            }
        }
        System.assert(sawReserve, 'the reserve villa is in the payload');
    }

    @isTest
    static void theStockListOffersFreeReserveVillasAndNothingElse() {
        settings(OPS_EID);
        String opsToken = tokenFor('P0000009');
        pinTo('PIN-3', 'P0000001'); // assigned, so it leaves the free list

        Test.startTest();
        List<ADHA_PinController.StockUnit> stock = ADHA_PinController.assignableStock(opsToken);
        Test.stopTest();

        Set<String> uids = new Set<String>();
        for (ADHA_PinController.StockUnit u : stock) {
            uids.add(u.plotUid);
        }
        System.assert(uids.contains('PIN-1'), 'free reserve stock is offered');
        System.assert(uids.contains('PIN-4'), 'and so is the other free one');
        System.assert(!uids.contains('PIN-3'), 'an assigned villa is no longer free');
        System.assert(!uids.contains('PIN-5'), 'public stock is never ops to assign');
        System.assert(!uids.contains('PIN-2'), 'MV stock is never assignable');

        // Specs ops picks by, and no customer token may ask.
        for (ADHA_PinController.StockUnit u : stock) {
            if (u.plotUid == 'PIN-1') {
                System.assertEquals('Modern', u.villaType);
                System.assertEquals(5, u.bedrooms);
            }
        }
        Boolean refused = false;
        try {
            ADHA_PinController.assignableStock(tokenFor('P0000001'));
        } catch (Exception e) {
            refused = true;
        }
        System.assert(refused, 'the stock list is an ops surface');
    }

    /* ---------- The reserve boundary moved from the sharing rule into the controller ---------- */

    @isTest
    static void aPinnedApplicantGetsTheirReserveVillaAndNoOtherReserveStock() {
        settings(OPS_EID);
        pinTo('PIN-1', 'P0000001');
        pinTo('PIN-4', 'P0000002');
        String token = tokenFor('P0000001');

        Test.startTest();
        ADHA_MasterplanController.MasterplanData data = ADHA_MasterplanController.getMasterplan(token);
        ADHA_MasterplanController.Availability avail = ADHA_MasterplanController.getAvailability(token);
        Test.stopTest();

        Map<String, ADHA_MasterplanController.UnitDTO> byUid =
            new Map<String, ADHA_MasterplanController.UnitDTO>();
        for (ADHA_MasterplanController.UnitDTO d : data.units) {
            byUid.put(d.plotUid, d);
        }

        System.assert(byUid.containsKey('PIN-1'), 'their assigned reserve villa reaches their map');
        System.assertEquals('Available', byUid.get('PIN-1').status, 'the pin is the exposure grant');
        System.assert(byUid.get('PIN-1').selectable, 'and it is theirs to book');
        System.assertEquals('PIN-1', data.applicant.pinnedPlotUid, 'so the banner can name it');
        System.assertEquals(1, data.eligibleUnits, 'the pin is the whole world');

        System.assert(!byUid.containsKey('PIN-4'), 'somebody else\'s reserve villa stays invisible');
        System.assert(!byUid.containsKey('PIN-2'), 'MV stock never reaches a customer');
        System.assert(byUid.containsKey('PIN-5'), 'public stock still travels, ineligible but drawn');

        Set<String> taken = new Set<String>(avail.taken);
        System.assert(!taken.contains('PIN-1'), 'their own villa is never taken from them');
        System.assert(!taken.contains('PIN-4'), 'and stock they cannot see is not in their poll');
    }

    @isTest
    static void anUnpinnedCustomerNeverReceivesReserveStock() {
        settings(OPS_EID);
        String token = tokenFor('P0000002');

        Test.startTest();
        ADHA_MasterplanController.MasterplanData data = ADHA_MasterplanController.getMasterplan(token);
        ADHA_MasterplanController.Availability avail = ADHA_MasterplanController.getAvailability(token);
        Test.stopTest();

        Set<String> uids = new Set<String>();
        for (ADHA_MasterplanController.UnitDTO d : data.units) {
            uids.add(d.plotUid);
        }
        System.assertEquals(new Set<String>{ 'PIN-5' }, uids,
            'a customer receives public stock and nothing else');
        System.assertEquals(1, data.eligibleUnits, 'and the count they are shown says the same');
        for (String uid : avail.taken) {
            System.assertEquals('PIN-5', uid, 'the poll never names a villa the map did not draw');
        }
    }

    @isTest
    static void opsStillReceivesTheWholePlan() {
        settings(OPS_EID);
        String opsToken = tokenFor('P0000009');

        Test.startTest();
        ADHA_MasterplanController.MasterplanData data = ADHA_MasterplanController.getMasterplan(opsToken);
        Test.stopTest();

        Set<String> uids = new Set<String>();
        Integer selectable = 0;
        for (ADHA_MasterplanController.UnitDTO d : data.units) {
            uids.add(d.plotUid);
            if (d.selectable) {
                selectable++;
            }
        }
        System.assertEquals(5, uids.size(), 'ops allocates against the whole plan');
        System.assertEquals(3, selectable,
            'and assigns from the free reserve pool only: PIN-1, PIN-3, PIN-4');
    }

    /* ---------- the masterplan, three viewpoints ---------- */

    @isTest
    static void aPinnedApplicantSeesOnlyTheirVilla() {
        settings(OPS_EID);
        pinTo('PIN-3', 'P0000001'); // category B: normally ineligible for this category-A applicant
        String token = tokenFor('P0000001');

        Test.startTest();
        ADHA_MasterplanController.MasterplanData data = ADHA_MasterplanController.getMasterplan(token);
        Test.stopTest();

        System.assertEquals('PIN-3', data.applicant.pinnedPlotUid);
        for (ADHA_MasterplanController.UnitDTO d : data.units) {
            if (d.plotUid == 'PIN-3') {
                System.assert(d.eligible, 'the pin overrides category eligibility');
                System.assert(d.selectable, 'and the villa is Available, so it is bookable');
            } else {
                System.assert(!d.eligible, d.plotUid + ' must be hidden from a pinned applicant');
            }
        }
        System.assertEquals(1, data.eligibleUnits, 'exactly one villa in the world');
        System.assert(!JSON.serialize(data).contains('Pinned_Applicant'),
            'the assignee never travels to a browser');
    }

    /** The reserve-stock model changed the shape of this. Pins live on reserve stock, which a
     *  customer never sees, so somebody else's assigned villa is absent rather than taken. */
    @isTest
    static void somebodyElsesReserveVillaIsAbsentFromACustomerMap() {
        settings(OPS_EID);
        pinTo('PIN-1', 'P0000002');
        String token = tokenFor('P0000001');

        Test.startTest();
        ADHA_MasterplanController.MasterplanData data = ADHA_MasterplanController.getMasterplan(token);
        ADHA_MasterplanController.Availability avail = ADHA_MasterplanController.getAvailability(token);
        Test.stopTest();

        for (ADHA_MasterplanController.UnitDTO d : data.units) {
            System.assertNotEquals('PIN-1', d.plotUid,
                'reserve stock assigned to somebody else never reaches another customer');
        }
        System.assert(!new Set<String>(avail.taken).contains('PIN-1'),
            'and the poll carries no villa the map never drew');
    }

    /** Public stock is the case a customer does see change under them. */
    @isTest
    static void publicStockHeldBySomebodyElseReadsTaken() {
        settings(OPS_EID);
        ADHA_Applicant__c holder = readyToBook('P0000002');
        ADHA_ReservationService.hold(holder, 'PIN-5');
        String token = tokenFor('P0000001');

        Test.startTest();
        ADHA_MasterplanController.MasterplanData data = ADHA_MasterplanController.getMasterplan(token);
        ADHA_MasterplanController.Availability avail = ADHA_MasterplanController.getAvailability(token);
        Test.stopTest();

        for (ADHA_MasterplanController.UnitDTO d : data.units) {
            if (d.plotUid == 'PIN-5') {
                System.assert(!d.selectable, 'a villa somebody else is holding is not bookable');
            }
        }
        System.assert(new Set<String>(avail.taken).contains('PIN-5'),
            'the poll carries it to other maps within a minute');
    }

    /* ---------- the booking gate ---------- */

    private static ADHA_Applicant__c readyToBook(String appNo) {
        ADHA_Applicant__c a = byAppNo(appNo);
        a.SLA_Start__c = System.now().addDays(-1);
        a.SLA_End__c = System.now().addDays(6);
        a.Journey_Stage__c = 'Exploring';
        a.Session_Token_Hash__c = 'h';
        a.Declaration_Session_Hash__c = 'h';
        a.First_Verified_Login__c = System.now().addDays(-1);
        a.Current_Attempt__c = 1;
        update a;
        return [SELECT Id, Application_Number__c, Customer_Name__c, Masked_Emirates_ID__c, Emirates_ID__c,
                       Service_Type__c, Eligible_Categories__c, Approved_Loan_Amount__c, Is_Ops__c,
                       Journey_Stage__c, SLA_Start__c, SLA_End__c, Current_Attempt__c, Mobile_Number__c,
                       Extra_Unit_Changes__c, Session_Token_Hash__c, Declaration_Session_Hash__c
                FROM ADHA_Applicant__c WHERE Id = :a.Id];
    }

    @isTest
    static void theGateRefusesBothDirectionsAndHonoursTheOverride() {
        settings(OPS_EID);
        pinTo('PIN-3', 'P0000001'); // their own pin, category B: override case
        pinTo('PIN-4', 'P0000002'); // somebody else's pin
        ADHA_Applicant__c a = readyToBook('P0000001');

        Test.startTest();
        // Somebody else's pinned villa is simply taken.
        Boolean tookRefused = false;
        try {
            ADHA_ReservationService.hold(a, 'PIN-4');
        } catch (AuraHandledException e) {
            tookRefused = true;
        }
        System.assert(tookRefused, 'PIN-4 belongs to somebody else');

        // A pinned applicant may not book an unpinned villa, even a normally eligible one.
        Boolean strayRefused = false;
        try {
            ADHA_ReservationService.hold(a, 'PIN-1');
        } catch (AuraHandledException e) {
            strayRefused = true;
        }
        System.assert(strayRefused, 'the pin is the whole world');

        // Their own pin books, though its category never matched: the override, working.
        ADHA_ReservationService.ReservationView view = ADHA_ReservationService.hold(a, 'PIN-3');
        Test.stopTest();
        System.assertEquals('PIN-3', view.plotUid, 'the pinned villa is bookable despite the category');
    }

    /* ---------- the sweeper's hygiene ---------- */

    @isTest
    static void expiryClearsThePin() {
        settings(OPS_EID);
        ADHA_Applicant__c gone = byAppNo('P0000002');
        gone.First_Verified_Login__c = System.now().addDays(-9);
        gone.SLA_Start__c = System.now().addDays(-9);
        gone.SLA_End__c = System.now().addDays(-1);
        gone.Journey_Stage__c = 'Unit Selected';
        gone.Current_Attempt__c = 2; // final attempt: expiry is terminal
        update gone;
        pinTo('PIN-4', 'P0000002');
        // Direct-DML pins carry no stamp, so set one to prove the sweeper clears it too.
        ADHA_Unit__c stamped = [SELECT Id FROM ADHA_Unit__c WHERE Plot_UID__c = 'PIN-4'];
        stamped.Pinned_On__c = System.now().addDays(-3);
        update stamped;

        Test.startTest();
        Database.executeBatch(new ADHA_ReservationSweeper(), 200);
        Test.stopTest();

        System.assertEquals('Expired',
            [SELECT Journey_Stage__c FROM ADHA_Applicant__c WHERE Id = :gone.Id].Journey_Stage__c);
        ADHA_Unit__c freed = [SELECT Pinned_Applicant__c, Pinned_On__c FROM ADHA_Unit__c WHERE Plot_UID__c = 'PIN-4'];
        System.assertEquals(null, freed.Pinned_Applicant__c,
            'an expired applicant\'s pin must not block the villa forever');
        System.assertEquals(null, freed.Pinned_On__c, 'the stamp goes with the pin');
    }

    /* ---------- Browsing leaves no journey footprint for ops ---------- */

    @isTest
    static void opsBrowsingNeverStampsTheJourneyStage() {
        settings(OPS_EID);
        String opsToken = tokenFor('P0000009');
        String customerToken = tokenFor('P0000001');

        Test.startTest();
        ADHA_JourneyController.markExploring(opsToken);
        ADHA_JourneyController.markExploring(customerToken);
        Test.stopTest();

        System.assertEquals('Invited',
            [SELECT Journey_Stage__c FROM ADHA_Applicant__c WHERE Application_Number__c = 'P0000009'].Journey_Stage__c,
            'ops browses the map without entering the journey');
        System.assertEquals('Exploring',
            [SELECT Journey_Stage__c FROM ADHA_Applicant__c WHERE Application_Number__c = 'P0000001'].Journey_Stage__c,
            'the guard must not stop real customers being counted');
    }

    /* ---------- Guards, aging, and the ops map flag ---------- */

    @isTest
    static void pinRefusesAnApplicantWithALiveReservation() {
        settings(OPS_EID);
        String opsToken = tokenFor('P0000009');
        ADHA_Applicant__c a = readyToBook('P0000001');
        ADHA_ReservationService.hold(a, 'PIN-5'); // public stock: what a customer books unaided

        Test.startTest();
        Boolean threw = false;
        try {
            ADHA_PinController.pin(opsToken, 'PIN-4', 'P0000001');
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'a live reservation means no pin - it could never be used');
        System.assertEquals(null,
            [SELECT Pinned_Applicant__c FROM ADHA_Unit__c WHERE Plot_UID__c = 'PIN-4'].Pinned_Applicant__c);

        // And the search result carries the flag ops sees the refusal by.
        for (ADHA_PinController.OpsApplicant row :
                ADHA_PinController.searchApplicants(opsToken, 'Customer One')) {
            System.assert(row.hasActiveReservation, 'the search must warn before the pin refuses');
        }
    }

    @isTest
    static void pinRefusesASecondUnitForAPinnedApplicant() {
        settings(OPS_EID);
        String opsToken = tokenFor('P0000009');
        ADHA_PinController.pin(opsToken, 'PIN-1', 'P0000001');

        Test.startTest();
        Boolean threw = false;
        try {
            ADHA_PinController.pin(opsToken, 'PIN-4', 'P0000001');
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'one pin per applicant');
        System.assertEquals(byAppNo('P0000001').Id,
            [SELECT Pinned_Applicant__c FROM ADHA_Unit__c WHERE Plot_UID__c = 'PIN-1'].Pinned_Applicant__c,
            'the first pin survives the refused second');
        System.assertEquals(null,
            [SELECT Pinned_Applicant__c FROM ADHA_Unit__c WHERE Plot_UID__c = 'PIN-4'].Pinned_Applicant__c);
    }

    @isTest
    static void rePinOfTheSameUnitStaysIdempotentAndKeepsTheAge() {
        settings(OPS_EID);
        String opsToken = tokenFor('P0000009');
        ADHA_PinController.pin(opsToken, 'PIN-1', 'P0000001');
        Datetime firstStamp = [SELECT Pinned_On__c FROM ADHA_Unit__c WHERE Plot_UID__c = 'PIN-1'].Pinned_On__c;

        Test.startTest();
        ADHA_PinController.PinInfo p = ADHA_PinController.pin(opsToken, 'PIN-1', 'P0000001');
        Test.stopTest();

        System.assertEquals('waiting', p.pinStatus, 're-pin of the same villa is a no-op, not an error');
        System.assertEquals(firstStamp,
            [SELECT Pinned_On__c FROM ADHA_Unit__c WHERE Plot_UID__c = 'PIN-1'].Pinned_On__c,
            'a re-pin must not reset the age');
    }

    @isTest
    static void pinStampsAndUnpinClearsPinnedOn() {
        settings(OPS_EID);
        String opsToken = tokenFor('P0000009');
        Datetime before = System.now().addSeconds(-1);

        ADHA_PinController.pin(opsToken, 'PIN-1', 'P0000001');
        ADHA_Unit__c u = [SELECT Pinned_On__c FROM ADHA_Unit__c WHERE Plot_UID__c = 'PIN-1'];
        System.assertNotEquals(null, u.Pinned_On__c, 'the board needs to know how long a pin has waited');
        System.assert(u.Pinned_On__c >= before, 'stamped now, not some inherited value');

        ADHA_PinController.unpin(opsToken, 'PIN-1');
        u = [SELECT Pinned_Applicant__c, Pinned_On__c FROM ADHA_Unit__c WHERE Plot_UID__c = 'PIN-1'];
        System.assertEquals(null, u.Pinned_Applicant__c);
        System.assertEquals(null, u.Pinned_On__c, 'no pin, no age');
    }

    @isTest
    static void theBoardCarriesPinnedOnAndToleratesItsAbsence() {
        settings(OPS_EID);
        String opsToken = tokenFor('P0000009');
        ADHA_PinController.pin(opsToken, 'PIN-1', 'P0000001');
        pinTo('PIN-4', 'P0000002'); // direct DML, no stamp - the legacy shape the client must survive

        List<ADHA_PinController.PinInfo> board = ADHA_PinController.board(opsToken);
        System.assertEquals(2, board.size());
        for (ADHA_PinController.PinInfo p : board) {
            if (p.plotUid == 'PIN-1') {
                System.assertNotEquals(null, p.pinnedOn, 'controller pins carry their age');
            } else {
                System.assertEquals(null, p.pinnedOn, 'a hand-written pin has none, and that is legal');
            }
        }
    }

    @isTest
    static void opsMapFlagsPinnedVillasAndCustomerMapNever() {
        settings(OPS_EID);
        pinTo('PIN-1', 'P0000002');

        String opsToken = tokenFor('P0000009');
        ADHA_MasterplanController.MasterplanData opsData = ADHA_MasterplanController.getMasterplan(opsToken);
        for (ADHA_MasterplanController.UnitDTO d : opsData.units) {
            System.assertEquals(d.plotUid == 'PIN-1', d.pinned == true,
                d.plotUid + ': the tint flag must match the pin exactly');
        }

        String customerToken = tokenFor('P0000001');
        ADHA_MasterplanController.MasterplanData custData = ADHA_MasterplanController.getMasterplan(customerToken);
        for (ADHA_MasterplanController.UnitDTO d : custData.units) {
            System.assert(d.pinned != true, 'a customer session never learns where pins sit');
        }
        String raw = JSON.serialize(custData);
        System.assert(!raw.contains('"pinned":true'), 'not even in the raw payload');
        System.assert(!raw.contains('Pinned_Applicant'), 'and never the assignee');
    }

    /* ---------- audit fixes: guards, search robustness, allowlist ---------- */

    @isTest
    static void anExpiredApplicantCannotBePinned() {
        settings(OPS_EID);
        String opsToken = tokenFor('P0000009');
        ADHA_Applicant__c gone = byAppNo('P0000001');
        gone.Journey_Stage__c = 'Expired';
        update gone;

        Test.startTest();
        Boolean threw = false;
        try {
            ADHA_PinController.pin(opsToken, 'PIN-1', 'P0000001');
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();
        System.assert(threw, 'an expired applicant can never book, so their pin would block the villa forever');
        for (ADHA_PinController.OpsApplicant row :
                ADHA_PinController.searchApplicants(opsToken, 'Customer One')) {
            System.assert(row.expired, 'and the search tags them before ops even tries');
        }
    }

    /** The ops journey skip must hold server-side, not only in routing. */
    @isTest
    static void anOpsTokenNeverStampsDeclarationOrExploration() {
        settings(OPS_EID);
        String opsToken = tokenFor('P0000009');

        Test.startTest();
        ADHA_JourneyController.acceptDeclaration(opsToken, 'en');
        ADHA_JourneyController.markUnitExplored(opsToken, 'PIN-1');
        Test.stopTest();

        ADHA_Applicant__c ops = [
            SELECT Journey_Stage__c, Declaration_Session_Hash__c, Declaration_Language__c
            FROM ADHA_Applicant__c WHERE Application_Number__c = 'P0000009'
        ];
        System.assertEquals('Invited', ops.Journey_Stage__c, 'no stage stamp for ops');
        System.assertEquals(null, ops.Declaration_Session_Hash__c, 'no consent evidence for ops');
        System.assertEquals(0, [
            SELECT COUNT() FROM Task WHERE WhatId = :ops.Id AND Subject LIKE '%explored%'
        ], 'ops browsing must not skew the exploration report');
    }

    @isTest
    static void searchSurvivesApostrophesAndRefusesWildcards() {
        settings(OPS_EID);
        String opsToken = tokenFor('P0000009');
        insert new ADHA_Applicant__c(
            Application_Number__c = 'P0000077', Emirates_ID__c = '784-1980-7777777-7',
            Customer_Name__c = 'Sean O\'Brien', Mobile_Number__c = '+971500000177',
            Service_Type__c = 'House Grant', Eligible_Categories__c = 'A',
            Approved_Loan_Amount__c = 1750000, Journey_Stage__c = 'Invited'
        );

        Test.startTest();
        List<ADHA_PinController.OpsApplicant> byName =
            ADHA_PinController.searchApplicants(opsToken, 'O\'Brien');
        List<ADHA_PinController.OpsApplicant> wildcard =
            ADHA_PinController.searchApplicants(opsToken, '%%');
        Test.stopTest();

        System.assertEquals(1, byName.size(), 'an apostrophe in a real name must still match');
        System.assertEquals(0, wildcard.size(), 'typed wildcards are literals, not match-everything');
    }

    @isTest
    static void theAllowlistMatchesWithOrWithoutDashes() {
        settings('784197000000011');
        System.assert(ADHA_JourneyController.isOps(byAppNo('P0000009')),
            'a dash-less allowlist entry names the same person');
    }
}