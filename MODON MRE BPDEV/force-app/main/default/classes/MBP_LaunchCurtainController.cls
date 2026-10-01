/**********************************************************************************************************************
* Name               : MBP_LaunchCurtainController
* Description        : Single source of truth for the Broker Portal launch curtain. Returns whether the calling user
*                       should see the countdown instead of the portal, the instant being counted towards, and the
*                       server's own clock so the countdown never depends on the browser's clock being correct.
*
*                       The switch is Broker_Portal_Launch__mdt.Default.Curtain_On__c. Go_Live_At__c is DISPLAY ONLY:
*                       the clock running out does NOT open the portal, unticking the checkbox does. One control, one
*                       mental model, and an instant rollback at go-live without a deploy or a site publish.
*
*                       FAILS OPEN BY DESIGN. A missing record, a missing field, a revoked permission or any other
*                       error returns showCurtain = false, i.e. the portal. The curtain is a pre-launch courtesy; a
*                       fault in it must never be able to take a live portal away from working brokers.
*
* Usage              : Called imperatively by mbpr_launchCurtain. Deliberately NOT cacheable, so that unticking the
*                       checkbox reaches open browser tabs on their next poll rather than being served from cache.
* Created By         : Kiran Rehan
* --------------------------------------------------------------------------------------------------------------------
* Version     Author          Date            Comment
* 1.0         Kiran Rehan     13 Sep 2026     Initial version for the Broker Portal go-live curtain.
**********************************************************************************************************************/
public with sharing class MBP_LaunchCurtainController {

    @TestVisible private class LaunchCurtainException extends Exception {}

    @TestVisible private static final String BYPASS_PERMISSION = 'Broker_Portal_Launch_Bypass';
    @TestVisible private static final String SETTING_NAME      = 'Default';

    // Test seams. Reading the real custom metadata in a test would tie the assertions to whatever the org happens to
    // hold that day, so the tests inject their own values through these instead. overrideApplied is separate from
    // settingOverride so that a test can inject a deliberate null and prove the missing-record path.
    @TestVisible private static Boolean overrideApplied = false;
    @TestVisible private static Broker_Portal_Launch__mdt settingOverride;
    @TestVisible private static Boolean bypassOverride;
    @TestVisible private static Boolean simulateReadFailure = false;

    public class LaunchStatus {
        @AuraEnabled public Boolean showCurtain;   // true = paint the countdown over the page
        @AuraEnabled public Long    goLiveMs;      // epoch millis of Go Live At, or null when it is blank
        @AuraEnabled public Long    serverNowMs;   // epoch millis on the server at the moment of the call
    }

    /**
     * Returns the curtain state for the running user, guest users included.
     * Never throws: every failure path resolves to showCurtain = false.
     */
    @AuraEnabled
    public static LaunchStatus getStatus() {

        LaunchStatus status = new LaunchStatus();
        status.showCurtain  = false;
        status.goLiveMs     = null;
        status.serverNowMs  = Datetime.now().getTime();

        try {
            Broker_Portal_Launch__mdt setting = readSetting();

            // No record deployed yet, or it was deleted. Treat that as "no curtain".
            if (setting == null) {
                return status;
            }

            if (setting.Go_Live_At__c != null) {
                status.goLiveMs = setting.Go_Live_At__c.getTime();
            }

            status.showCurtain = (setting.Curtain_On__c == true) && !hasBypass();

        } catch (Exception e) {
            // Fail open. See the class header: a broken curtain must not be able to hide a live portal.
            System.debug(LoggingLevel.ERROR, 'MBP_LaunchCurtainController: falling open. ' + e.getMessage());
            status.showCurtain = false;
        }

        return status;
    }

    /**
     * getInstance costs no SOQL query, so the curtain adds nothing to the governor budget of the page it sits on.
     */
    private static Broker_Portal_Launch__mdt readSetting() {
        if (simulateReadFailure) {
            throw new LaunchCurtainException('Simulated read failure.');
        }
        if (overrideApplied) {
            return settingOverride;
        }
        return Broker_Portal_Launch__mdt.getInstance(SETTING_NAME);
    }

    /**
     * Returns false for a guest user and false when the custom permission does not exist in the org, both of which
     * are the answers we want.
     */
    private static Boolean hasBypass() {
        if (bypassOverride != null) {
            return bypassOverride;
        }
        return FeatureManagement.checkPermission(BYPASS_PERMISSION);
    }
}