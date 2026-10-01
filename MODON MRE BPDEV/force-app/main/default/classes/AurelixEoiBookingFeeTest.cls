/**
 * AurelixEoiBookingFee and SalesConsoleController.decideFeeByEoi (1.74).
 *
 * Version  Author       Date         Detail
 * 1.0      Aurelix Dev  22 Sep 2026  The switch, and the rule on values alone: the fee is skipped only with
 *                                    the switch on, for the booked unit, and for an EOI with a cleared receipt.
 */
@isTest
private class AurelixEoiBookingFeeTest {

    private static final Id UNIT_A = Id.valueOf('a03VG00001QGkxkYAD');
    private static final Id UNIT_B = Id.valueOf('a03VG00001QGkxpYAD');
    private static final Id EOI_1  = Id.valueOf('a0eVG000005IiJ5YAK');

    private static String mapping(Id unitId, Id eoiId) {
        return JSON.serialize(new Map<String, String>{ String.valueOf(unitId) => String.valueOf(eoiId) });
    }

    @isTest
    static void switchFollowsTheOverride() {
        AurelixEoiBookingFee.switchOverride = true;
        System.assertEquals(true, AurelixEoiBookingFee.isOn());
        AurelixEoiBookingFee.switchOverride = false;
        System.assertEquals(false, AurelixEoiBookingFee.isOn());
    }

    @isTest
    static void switchIsOffByDefault() {
        Sales_Console_Config__mdt cfg = Sales_Console_Config__mdt.getInstance(AurelixEoiBookingFee.FLAG);
        System.assertEquals(cfg != null && cfg.Is_Active__c == true, AurelixEoiBookingFee.isOn(),
            'Without an override the switch is the metadata record.');
    }

    @isTest
    static void paidEoiOnTheUnitCoversTheFee() {
        Map<String, Boolean> receipts = new Map<String, Boolean>{ String.valueOf(EOI_1) => true };
        System.assertEquals(true,
            SalesConsoleController.decideFeeByEoi(true, UNIT_A, mapping(UNIT_A, EOI_1), receipts));
    }

    @isTest
    static void switchOffKeepsTheFee() {
        Map<String, Boolean> receipts = new Map<String, Boolean>{ String.valueOf(EOI_1) => true };
        System.assertEquals(false,
            SalesConsoleController.decideFeeByEoi(false, UNIT_A, mapping(UNIT_A, EOI_1), receipts));
    }

    @isTest
    static void eoiWithoutAClearedReceiptKeepsTheFee() {
        Map<String, Boolean> receipts = new Map<String, Boolean>{ String.valueOf(EOI_1) => false };
        System.assertEquals(false,
            SalesConsoleController.decideFeeByEoi(true, UNIT_A, mapping(UNIT_A, EOI_1), receipts));
    }

    @isTest
    static void eoiOnAnotherUnitKeepsTheFee() {
        Map<String, Boolean> receipts = new Map<String, Boolean>{ String.valueOf(EOI_1) => true };
        System.assertEquals(false,
            SalesConsoleController.decideFeeByEoi(true, UNIT_A, mapping(UNIT_B, EOI_1), receipts));
    }

    @isTest
    static void noEoiKeepsTheFee() {
        System.assertEquals(false,
            SalesConsoleController.decideFeeByEoi(true, UNIT_A, null, new Map<String, Boolean>()));
    }

    /** With the switch off the page is told exactly what MODON's isPaymentRequired says. */
    @isTest
    static void feeNeedWithNoUnitIsNotRequired() {
        AurelixEoiBookingFee.switchOverride = true;
        SalesConsoleController.FeeNeedDTO need = SalesConsoleController.getBookingFeeNeed(null, null, null);
        System.assertEquals(false, need.required);
        System.assertEquals(false, need.coveredByEoi);
    }
}