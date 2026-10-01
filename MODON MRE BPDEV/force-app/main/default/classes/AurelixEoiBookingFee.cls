/**
 * AurelixEoiBookingFee - the switch for booking one unit against a paid EOI without a booking fee.
 *
 * Version  Author       Date         Detail
 * 1.0      Aurelix Dev  22 Sep 2026  In the Sales App a customer who has paid an EOI deposit books one unit
 *                                    straight away, with no booking fee, and the deposit goes to the ADM &
 *                                    Dari invoice. The console took the booking fee first, so the customer
 *                                    paid both. MODON suggested switching the fee off in that case (call of
 *                                    22 Sep); the business has not confirmed yet. It sits behind a switch:
 *                                    EOI_SKIPS_BOOKING_FEE in Sales_Console_Config__mdt, off by
 *                                    default, editable in Setup without a deployment.
 *
 * Only the switch lives here (only Aurelix Apex reads the console switches). Whether a booking's EOI
 * qualifies is decided in SalesConsoleController (eoiCoversFee), next to the EOI rules it reuses.
 */
public with sharing class AurelixEoiBookingFee {

    public static final String FLAG = 'EOI_SKIPS_BOOKING_FEE';

    /** Tests set this instead of the metadata record. */
    @TestVisible private static Boolean switchOverride;

    /** Sales_Console_Config__mdt.EOI_SKIPS_BOOKING_FEE.Is_Active__c. */
    public static Boolean isOn() {
        if (switchOverride != null) {
            return switchOverride;
        }
        Sales_Console_Config__mdt cfg = Sales_Console_Config__mdt.getInstance(FLAG);
        return cfg != null && cfg.Is_Active__c == true;
    }
}