/**********************************************************************************************************************
* Name               : Modon_Egypt_ManageInventoryController                                                        
* Description        : This class is used as controller for LWC (modonEgyptManageInventory)
* Usage              : ModonEgyptManageInventory LWC                                                          
* Created By         : Horizontal Digital                                                   
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                          Date            Comment                                                                       
* 1.0          mkapatel@horizontal.com          20 Jan 2026     Initial Version
* 1.1          mkapatel@horizontal.com          03 Mar 2026     Used Constants common class for hardcoded values
* 2.0          mirza baig                       04 April 2026   Retrieved available zone values
******************************************************************************************************************/

public with sharing class Modon_Egypt_ManageInventoryController {

    /**
    * Retrieves a distinct list of Zone values from Unit__c records.
    * 
    * This method filters records by Source_Entity__c = 'Modon - Egypt'
    * and ensures duplicate Zone values are removed using a Set.
    *
    * @return List<String> - Unique list of Zone values for dropdown usage in LWC/UI
    */
    @AuraEnabled(cacheable=true)
    public static List<String> getZoneValues() {
        
        // Set to store unique Zone values (automatically removes duplicates)
        Set<String> zoneSet = new Set<String>();

        // Query Unit records filtered by Source Entity and non-null Zone
        for (Unit__c u : [
            SELECT Zone__c 
            FROM Unit__c 
            WHERE Zone__c != NULL 
            AND Source_Entity__c = :ModonEgyptConstants.MODON_EGYPT_SOURCE_ENTITY
        ]) {
            zoneSet.add(u.Zone__c);
        }

        // Convert Set to List before returning to LWC
        return new List<String>(zoneSet);
    }

    /**************************************************************************************************************************************************************************************
     * Method		 :	loadFilters
     * Description	 :	This method is used to load filter values
     * Parameters	 :  NONE
     * Returns		 :	Map<String, List<Map<String, String>>>
    ***************************************************************************************************************************************************************************************/
    @AuraEnabled(cacheable = true)
    public static Map<String, List<Map<String, String>>> loadFilters(){
        Map<String, List<Map<String, String>>> filtersToReturn = new Map<String, List<Map<String, String>>>();
        try {

            Map<String, Unit_Search_Filter__mdt> filterListMap = Unit_Search_Filter__mdt.getAll();
            List<Unit_Search_Filter__mdt> filterList = filterListMap.values();
            Set<Id> filterListIds = new Set<Id>();
            for (Unit_Search_Filter__mdt filter : filterList) {
                filterListIds.add(filter.Id);
            }
            
            if (!filterListIds.isEmpty()) {
                Map<String, Unit_Search_Filter_Value__mdt> filterValuesMap = Unit_Search_Filter_Value__mdt.getAll();
                List<Unit_Search_Filter_Value__mdt> filterValues = filterValuesMap.values();
                
                for (Unit_Search_Filter_Value__mdt val : filterValues) {
                    Map<String, String> filterKeyValuePair = new Map<String, String>();
                    filterKeyValuePair.put(ModonEgyptConstants.INVENTORY_KEY_LABEL, val.Label);
                    filterKeyValuePair.put(ModonEgyptConstants.INVENTORY_KEY_VALUE, val.DeveloperName);
                    if(filtersToReturn.containsKey(val.Unit_Search_Filter__r.DeveloperName)){
                        filtersToReturn.get(val.Unit_Search_Filter__r.DeveloperName).add(filterKeyValuePair);
                    }
                    else{
                        List<Map<String, String>> oneFilterList = new List<Map<String, String>>();
                        oneFilterList.add(filterKeyValuePair);

                        filtersToReturn.put(val.Unit_Search_Filter__r.DeveloperName, oneFilterList);
                    }
                }
            }

            //Currency
            List<CurrencyType> currencyIsoCodes = [SELECT IsoCode FROM CurrencyType WHERE IsActive = true];
            
            if (!currencyIsoCodes.isEmpty()) {
                List<Map<String, String>> oneFilterList = new List<Map<String, String>>();
                for (CurrencyType cic : currencyIsoCodes) {
                    Map<String, String> filterKeyValuePair = new Map<String, String>();
                    filterKeyValuePair.put(ModonEgyptConstants.INVENTORY_KEY_LABEL, cic.IsoCode);
                    filterKeyValuePair.put(ModonEgyptConstants.INVENTORY_KEY_VALUE, cic.IsoCode);
                    oneFilterList.add(filterKeyValuePair);
                }
                filtersToReturn.put(ModonEgyptConstants.INVENTORY_KEY_CURRENCY, oneFilterList);
            }
            return filtersToReturn;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**************************************************************************************************************************************************************************************
     * Method		 :	getFieldsFromLayout
     * Description	 :	This method is used to get fields API Names for a specific layout
     * Parameters	 :  String objectApiName, String layoutName
     * Returns		 :	List<String>
    ***************************************************************************************************************************************************************************************/
    @AuraEnabled(cacheable=true)
    public static List<String> getFieldsFromLayout(String objectApiName, String layoutName) {
        List<String> fieldList = new List<String>();
        try{
        
            List<Metadata.Metadata> layouts = 
                Metadata.Operations.retrieve(Metadata.MetadataType.Layout, 
                                            new List<String> {objectApiName + '-' + layoutName});
            Metadata.Layout layoutMd = (Metadata.Layout) layouts.get(0);

            for (Metadata.LayoutSection section : layoutMd.layoutSections) {
                for (Metadata.LayoutColumn column : section.layoutColumns) {
                    if (column.layoutItems != null) {
                        for (Metadata.LayoutItem item : column.layoutItems) {
                            fieldList.add(item.field);
                        }
                    }
                }
            }
        } catch(Exception e){
            throw new AuraHandledException(ModonEgyptConstants.INVENTORY_ERROR_FETCH_FIELDS + e.getMessage());
        }

        return fieldList;
    }

    /**************************************************************************************************************************************************************************************
     * Method		 :	updateInventory
     * Description	 :	This method is used to update Inventory(Units) data
     * Parameters	 :  string jsonString
     * Returns		 :	String
    ***************************************************************************************************************************************************************************************/
    @AuraEnabled
    public static String updateInventory(String jsonString){
        try {
            InventoryUpdateWrapper iuw = (InventoryUpdateWrapper) JSON.deserialize(jsonString, InventoryUpdateWrapper.class);
            List<Unit__c> unitsToUpdate = new List<Unit__c>();
            if(!iuw.unitIds.isEmpty()){
                unitsToUpdate = [SELECT Id, ApprovalStatus__c, Status__c, Sub_Status__c, BlockedFor__c, BlockedBy__c, BlockComment__c,  Blocked_Time__c, BlockReason__c, BlockUntil__c, Bucket__c FROM Unit__c WHERE Id IN :iuw.unitIds];
            }
            if(!unitsToUpdate.isEmpty()){
                if(iuw.action == ModonEgyptConstants.INVENTORY_ACTION_DRAFT){
                    for(Unit__c u : unitsToUpdate){
                        u.ApprovalStatus__c = ModonEgyptConstants.INVENTORY_STATUS_DRAFT;
                    }
                }
                if(iuw.action == ModonEgyptConstants.INVENTORY_ACTION_UNRELEASE){
                    for(Unit__c u : unitsToUpdate){
                        u.ApprovalStatus__c = ModonEgyptConstants.INVENTORY_STATUS_UNRELEASED;
                    }
                }
                if(iuw.action == ModonEgyptConstants.INVENTORY_ACTION_RELEASE){
                    if(iuw.userId != null && iuw.hoursToBlock != null && iuw.blockComments != null){
                        Integer minsToAdd = iuw.hoursToBlock == ModonEgyptConstants.INVENTORY_UNLIMITED ? null : iuw.hoursToBlock.contains(ModonEgyptConstants.INVENTORY_MIN_SUFFIX) ? Integer.valueOf(iuw.hoursToBlock.split(' ', 2)[0]) : (Integer.valueOf(iuw.hoursToBlock) * 60);
                        for(Unit__c u : unitsToUpdate){
                            u.ApprovalStatus__c = ModonEgyptConstants.INVENTORY_STATUS_RELEASED;
                            u.Status__c = ModonEgyptConstants.INVENTORY_UNIT_STATUS_AVAILABLE;
                            u.Sub_Status__c = ModonEgyptConstants.INVENTORY_SUBSTATUS_ASSIGNED;
                            u.BlockedFor__c = iuw.userId;
                            u.BlockedBy__c = UserInfo.getUserId();
                            u.BlockComment__c = iuw.blockComments;
                            u.Blocked_Time__c = null;
                            u.BlockReason__c = null;
                            u.BlockUntil__c = minsToAdd == null ? null : System.now().addMinutes(minsToAdd);
                            u.Bucket__c = iuw.bucketId != null ? iuw.bucketId : '';
                        }
                    }
                    else{
                        for(Unit__c u : unitsToUpdate){
                            u.ApprovalStatus__c = ModonEgyptConstants.INVENTORY_STATUS_RELEASED;
                            u.Status__c = ModonEgyptConstants.INVENTORY_UNIT_STATUS_AVAILABLE;
                            u.Sub_Status__c = ModonEgyptConstants.INVENTORY_SUBSTATUS_UNASSIGNED;
                            u.BlockedFor__c = null;
                            u.BlockedBy__c = null;
                            u.BlockComment__c = null;
                            u.Blocked_Time__c = null;
                            u.BlockReason__c = null;
                            u.BlockUntil__c = null;                            
                            u.Bucket__c = iuw.bucketId != null ? iuw.bucketId : '';
                        }
                    }
                }
                if(iuw.action == ModonEgyptConstants.INVENTORY_ACTION_ASSIGN){
                    Integer minsToAdd = iuw.hoursToBlock == ModonEgyptConstants.INVENTORY_UNLIMITED ? null : iuw.hoursToBlock.contains(ModonEgyptConstants.INVENTORY_MIN_SUFFIX) ? Integer.valueOf(iuw.hoursToBlock.split(' ', 2)[0]) : (Integer.valueOf(iuw.hoursToBlock) * 60);
                    for(Unit__c u : unitsToUpdate){
                        u.ApprovalStatus__c = ModonEgyptConstants.INVENTORY_STATUS_RELEASED;
                        u.Status__c = ModonEgyptConstants.INVENTORY_UNIT_STATUS_AVAILABLE;
                        u.Sub_Status__c = ModonEgyptConstants.INVENTORY_SUBSTATUS_ASSIGNED;
                        u.BlockedFor__c = iuw.userId;
                        u.BlockedBy__c = UserInfo.getUserId();
                        u.BlockComment__c = iuw.blockComments != null ? iuw.blockComments : null;
                        u.Blocked_Time__c = null;
                        u.BlockReason__c = null;
                        u.BlockUntil__c = minsToAdd == null ? null : System.now().addMinutes(minsToAdd);
                    }
                }
                if(iuw.action == ModonEgyptConstants.INVENTORY_ACTION_UNASSIGN){
                    for(Unit__c u : unitsToUpdate){
                        u.Opportunity__c = null;
                        u.Sub_Status__c = ModonEgyptConstants.INVENTORY_SUBSTATUS_UNASSIGNED;
                        u.BlockedFor__c = null;
                        u.BlockedBy__c = null;
                        u.BlockComment__c = null;
                        u.Blocked_Time__c = null;
                        u.BlockReason__c = null;
                        u.BlockUntil__c = null;
                    }
                }
                if(iuw.action == ModonEgyptConstants.INVENTORY_ACTION_BUCKET){
                    for(Unit__c u : unitsToUpdate){
                        u.Bucket__c = iuw.bucketId;
                    }
                }
            }

            if(!unitsToUpdate.isEmpty()){
                update unitsToUpdate;
            }
            return ModonEgyptConstants.INVENTORY_SUCCESS; 
        }
            
            
        catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ********** Wrapper class ********** //
    public class InventoryUpdateWrapper {
        @AuraEnabled
        public Set<Id> unitIds {get; set; }
        @AuraEnabled
        public String action {get; set; }
        @AuraEnabled
        public String userId {get; set; }
        @AuraEnabled
        public String bucketId {get; set; }
        @AuraEnabled
        public String hoursToBlock {get; set; }
        @AuraEnabled
        public String blockComments {get; set; }

        public InventoryUpdateWrapper() {
            this.unitIds = new Set<Id>();
        }
    }

}