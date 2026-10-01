/**
 * AurelixNewCustomerSwitch. The refusal itself is tested in SalesConsoleLeadControllerTest (1.27).
 *
 * Version  Author       Date         Detail
 * 1.0      Aurelix Dev  28 Sep 2026  SCW-205. The switch follows the override, and without one it is the
 *                                    metadata record (not a hardcoded value, so ticking it in Setup breaks
 *                                    no test).
 */
@isTest
private class AurelixNewCustomerSwitchTest {

    @isTest
    static void switchFollowsTheOverride() {
        AurelixNewCustomerSwitch.switchOverride = true;
        System.assertEquals(true, AurelixNewCustomerSwitch.isOn());
        AurelixNewCustomerSwitch.switchOverride = false;
        System.assertEquals(false, AurelixNewCustomerSwitch.isOn());
    }

    @isTest
    static void switchIsTheMetadataRecord() {
        Sales_Console_Config__mdt cfg =
            Sales_Console_Config__mdt.getInstance(AurelixNewCustomerSwitch.FLAG);
        System.assertEquals(cfg != null && cfg.Is_Active__c == true, AurelixNewCustomerSwitch.isOn(),
            'Without an override the switch is the metadata record.');
    }
}