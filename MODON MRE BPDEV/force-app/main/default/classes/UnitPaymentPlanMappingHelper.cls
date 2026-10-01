/**********************************************************************************************************************
* Name               : UnitPaymentPlanMappingHelper                                                        
* Description        : Helper class for UnitPaymentPlanMapping trigger - updates parent Unit's BasePrice based on
*                      specific payment plan mappings for Modon Egypt Sakneen sync.
*                      - If Unit.Visible_to_MRE_SalesTeam__c = TRUE  → Uses AED + 8 Years mapping
*                      - If Unit.Visible_to_MRE_SalesTeam__c = FALSE → Uses EGP + 8 Years mapping
* Usage              : Called from UnitPaymentPlanMappingTriggerHandler
* Created By         : Horizontal                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           Shahil Sinha (Horizontal)         15 Jan 2026   Initial Draft - Updates Unit's BasePrice with EGP + 8 Years
* 1.1           Shahil Sinha (Horizontal)         23 Jan 2026   Updated logic - Currency based on Visible_to_MRE_SalesTeam__c
*                                                               TRUE = AED, FALSE = EGP
******************************************************************************************************************/
public without sharing class UnitPaymentPlanMappingHelper {

    private static final String CURRENCY_AED = 'AED';
    private static final String CURRENCY_EGP = 'EGP';
    private static final String PAYMENT_PLAN_NAME_FILTER = '8 Years';

    /** v1.1 (line 53 - 87)
     * Updates parent Unit's BasePrice__c with the payment plan mapping's Base_Price__c.
     * Currency selection based on Unit's Visible_to_MRE_SalesTeam__c field:
     * - TRUE  → AED currency + "8 Years" name filter
     * - FALSE → EGP currency + "8 Years" name filter
     */
    public static void updateModonEgyptUnits(List<SObject> newList) {

        if (newList == null || newList.isEmpty()) {
            return;
        }

        // Collect Unit IDs from mappings
        Set<Id> unitIds = new Set<Id>();
        for (UnitPaymentPlanMapping__c mapping : (List<UnitPaymentPlanMapping__c>) newList) {
            if (mapping.Unit__c != null) {
                unitIds.add(mapping.Unit__c);
            }
        }

        if (unitIds.isEmpty()) {
            return;
        }

        // Query parent Units to get Visible_to_MRE_SalesTeam__c field
        Map<Id, Unit__c> unitMap = new Map<Id, Unit__c>([
            SELECT Id, BasePrice__c, Visible_to_MRE_SalesTeam__c 
            FROM Unit__c 
            WHERE Id IN :unitIds
        ]);

        // Build maps: Unit Id → Mapping for each currency type (filtered by "8 Years")
        Map<Id, UnitPaymentPlanMapping__c> aedMappingsByUnitId = new Map<Id, UnitPaymentPlanMapping__c>();
        Map<Id, UnitPaymentPlanMapping__c> egpMappingsByUnitId = new Map<Id, UnitPaymentPlanMapping__c>();

        for (UnitPaymentPlanMapping__c mapping : (List<UnitPaymentPlanMapping__c>) newList) {
            // Only process mappings with "8 Years" in name
            if (mapping.Name != null && mapping.Name.contains(PAYMENT_PLAN_NAME_FILTER)) {
                if (mapping.CurrencyIsoCode == CURRENCY_AED) {
                    aedMappingsByUnitId.put(mapping.Unit__c, mapping);
                } else if (mapping.CurrencyIsoCode == CURRENCY_EGP) {
                    egpMappingsByUnitId.put(mapping.Unit__c, mapping);
                }
            }
        }

        // Determine which mapping to use based on Unit's Visible_to_MRE_SalesTeam__c
        List<Unit__c> unitsToUpdate = new List<Unit__c>();

        for (Unit__c unit : unitMap.values()) {
            UnitPaymentPlanMapping__c mappingToUse = null;

            // TRUE = AED, FALSE/NULL = EGP
            if (unit.Visible_to_MRE_SalesTeam__c == true) {
                mappingToUse = aedMappingsByUnitId.get(unit.Id);
            } else {
                mappingToUse = egpMappingsByUnitId.get(unit.Id);
            }

            // Update Unit's BasePrice if mapping exists and price is different
            if (mappingToUse != null 
                && mappingToUse.Base_Price__c != null 
                && unit.BasePrice__c != mappingToUse.Base_Price__c) {
                unit.BasePrice__c = mappingToUse.Base_Price__c;
                unitsToUpdate.add(unit);
            }
        }

        // Perform DML only if changes exist
        if (!unitsToUpdate.isEmpty()) {
            update unitsToUpdate;
        }
    }
}