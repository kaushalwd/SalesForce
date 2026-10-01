/**
 * AurelixNewCustomerSwitch - the switch for creating a new customer when existing customers match.
 *
 * Version  Author       Date         Detail
 * 1.0      Aurelix Dev  28 Sep 2026  SCW-205. In the Sales App a rep cannot create a new account while
 *                                    existing accounts match the buyer: the lead needs an approved New
 *                                    Account Exception first ("Matching accounts were found. Please select
 *                                    one before converting."). The console's customer chooser offered
 *                                    "Continue With New Details", which created the customer anyway.
 *                                    Decision (28 Sep 2026): remove it, behind a switch so it can come back
 *                                    without a code change. ALLOW_NEW_CUSTOMER_DESPITE_MATCH in
 *                                    Sales_Console_Config__mdt, off, editable in Setup.
 *
 * Only the switch lives here (only Aurelix Apex reads the console switches). The button and the refusal
 * are in mscConsole and SalesConsoleLeadController (createCustomer, convertLeadToCustomer).
 */
public with sharing class AurelixNewCustomerSwitch {

    public static final String FLAG = 'ALLOW_NEW_CUSTOMER_DESPITE_MATCH';

    /** Tests set this instead of the metadata record. */
    @TestVisible private static Boolean switchOverride;

    /** Sales_Console_Config__mdt.ALLOW_NEW_CUSTOMER_DESPITE_MATCH.Is_Active__c. No record means off. */
    public static Boolean isOn() {
        if (switchOverride != null) {
            return switchOverride;
        }
        Sales_Console_Config__mdt cfg = Sales_Console_Config__mdt.getInstance(FLAG);
        return cfg != null && cfg.Is_Active__c == true;
    }
}