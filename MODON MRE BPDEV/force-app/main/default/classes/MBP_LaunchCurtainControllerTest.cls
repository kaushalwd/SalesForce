/**********************************************************************************************************************
* Name               : MBP_LaunchCurtainControllerTest
* Description        : Covers every branch of the Broker Portal launch curtain, including the two that matter most on
*                       go-live day: a bypass holder always gets the portal, and any fault falls open to the portal
*                       rather than hiding it.
* Created By         : Kiran Rehan
* --------------------------------------------------------------------------------------------------------------------
* Version     Author          Date            Comment
* 1.0         Kiran Rehan     13 Sep 2026     Initial version.
**********************************************************************************************************************/
@IsTest
private class MBP_LaunchCurtainControllerTest {

    private static final Datetime GO_LIVE = Datetime.newInstanceGmt(2026, 9, 20, 6, 0, 0);

    /**
     * Builds an in-memory setting and arms the seams. Custom metadata cannot be inserted, so the controller is handed
     * a constructed record rather than the org's own.
     */
    private static void applySetting(Boolean curtainOn, Datetime goLiveAt, Boolean hasBypass) {
        MBP_LaunchCurtainController.settingOverride = new Broker_Portal_Launch__mdt(
            DeveloperName  = 'Default',
            Curtain_On__c  = curtainOn,
            Go_Live_At__c  = goLiveAt
        );
        MBP_LaunchCurtainController.overrideApplied = true;
        MBP_LaunchCurtainController.bypassOverride  = hasBypass;
    }

    @IsTest
    static void curtainOnWithoutBypassShowsCountdown() {
        applySetting(true, GO_LIVE, false);

        Test.startTest();
        MBP_LaunchCurtainController.LaunchStatus status = MBP_LaunchCurtainController.getStatus();
        Test.stopTest();

        Assert.isTrue(status.showCurtain, 'A broker without the bypass must see the curtain while it is on.');
        Assert.areEqual(GO_LIVE.getTime(), status.goLiveMs, 'The go-live instant must come back as epoch millis.');
        Assert.isNotNull(status.serverNowMs, 'The server clock must always be returned.');
    }

    @IsTest
    static void bypassHolderAlwaysSeesThePortal() {
        applySetting(true, GO_LIVE, true);

        Test.startTest();
        MBP_LaunchCurtainController.LaunchStatus status = MBP_LaunchCurtainController.getStatus();
        Test.stopTest();

        Assert.isFalse(status.showCurtain, 'The bypass permission must defeat the curtain.');
        Assert.areEqual(GO_LIVE.getTime(), status.goLiveMs, 'The countdown target is still reported to a tester.');
    }

    @IsTest
    static void curtainOffShowsThePortal() {
        applySetting(false, GO_LIVE, false);

        Test.startTest();
        MBP_LaunchCurtainController.LaunchStatus status = MBP_LaunchCurtainController.getStatus();
        Test.stopTest();

        Assert.isFalse(status.showCurtain, 'Unticking the checkbox is what opens the portal.');
    }

    /**
     * The clock running out must NOT open the portal on its own. Only the checkbox does.
     */
    @IsTest
    static void pastGoLiveTimeDoesNotOpenThePortal() {
        applySetting(true, Datetime.now().addDays(-5), false);

        Test.startTest();
        MBP_LaunchCurtainController.LaunchStatus status = MBP_LaunchCurtainController.getStatus();
        Test.stopTest();

        Assert.isTrue(status.showCurtain, 'An elapsed go-live time must leave the curtain exactly as it was.');
    }

    @IsTest
    static void blankGoLiveTimeIsReportedAsNull() {
        applySetting(true, null, false);

        Test.startTest();
        MBP_LaunchCurtainController.LaunchStatus status = MBP_LaunchCurtainController.getStatus();
        Test.stopTest();

        Assert.isTrue(status.showCurtain, 'A blank date must still curtain the portal.');
        Assert.isNull(status.goLiveMs, 'A blank date must come back as null so the component can hide the clock.');
    }

    @IsTest
    static void missingSettingRecordFallsOpen() {
        MBP_LaunchCurtainController.settingOverride  = null;
        MBP_LaunchCurtainController.overrideApplied  = true;
        MBP_LaunchCurtainController.bypassOverride   = false;

        Test.startTest();
        MBP_LaunchCurtainController.LaunchStatus status = MBP_LaunchCurtainController.getStatus();
        Test.stopTest();

        Assert.isFalse(status.showCurtain, 'A deleted or undeployed record must never curtain a live portal.');
        Assert.isNull(status.goLiveMs, 'There is no date to report when there is no record.');
    }

    @IsTest
    static void readFailureFallsOpen() {
        MBP_LaunchCurtainController.simulateReadFailure = true;

        Test.startTest();
        MBP_LaunchCurtainController.LaunchStatus status = MBP_LaunchCurtainController.getStatus();
        Test.stopTest();

        Assert.isFalse(status.showCurtain, 'Any fault in the curtain must resolve to the portal, never to a blackout.');
        Assert.isNotNull(status.serverNowMs, 'The server clock is set before the read, so it survives a failure.');
    }

    /**
     * Exercises the real custom metadata read and the real permission check, the path that actually runs in production.
     * The org's own record decides the answer, so this asserts the contract rather than a particular value.
     */
    @IsTest
    static void liveReadHonoursTheDeployedRecord() {
        Test.startTest();
        MBP_LaunchCurtainController.LaunchStatus status = MBP_LaunchCurtainController.getStatus();
        Test.stopTest();

        Assert.isNotNull(status, 'The controller must always answer.');
        Assert.isNotNull(status.showCurtain, 'showCurtain is never null.');
        Assert.isNotNull(status.serverNowMs, 'serverNowMs is never null.');

        Broker_Portal_Launch__mdt deployed = Broker_Portal_Launch__mdt.getInstance('Default');
        Boolean expected = deployed != null
            && deployed.Curtain_On__c == true
            && !FeatureManagement.checkPermission('Broker_Portal_Launch_Bypass');
        Assert.areEqual(expected, status.showCurtain, 'The live read must match the deployed record.');
    }
}