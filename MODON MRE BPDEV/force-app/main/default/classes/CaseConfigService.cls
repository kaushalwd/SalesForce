/**********************************************************************************************************************
* Name               : CaseConfigService                                                        
* Description        : Used in Case trigger (before insert / before update) to auto-populate Organization, Department, Queue, Owner, Priority, and Target SLA.
* Usage              : Called from CaseTriggerHelper
* Created By         : Active Minds Global Solutions Pvt Ltd                                                     
* ---------------------------------------------------------------------------------------------------------------------
* Version       Author                                      Date            Comment                                                                       
* 1.0           ravikumar.pasumarthi@activemindsit.com      25 Nov 2025     Initial Draft 
* 2.0			ravikumar.pasumarthi@activemindsit.com      07 May 2026     Modify condition to populate TL Queue 
***********************************************************************************************************************/
public with sharing class CaseConfigService {
    
    // Cache: each Case_Config_Category__mdt row is placed in the map matching the tier of its own
    // populated fields (Record_Type__c is always present):
    //   configExactMap    - RecordType::SubVertical::Category::SubCategory (row has Sub_Category__c)
    //   configSVMap       - RecordType::SubVertical::Category              (row has Sub_Vertical__c, no Sub_Category__c)
    //   configCatMap      - RecordType::Category                          (row has neither)
    // Lookup tries these tiers most-specific first, then finally retries configCatMap assuming
    // Record_Type__c = 'Standard' when the Case's actual record type has no configured match.
    private static final String DEFAULT_RECORD_TYPE = 'Standard';
    private static Map<String, Case_Config_Category__mdt> configExactMap;
    private static Map<String, Case_Config_Category__mdt> configSVMap;
    private static Map<String, Case_Config_Category__mdt> configCatMap;
    private static Map<Id, String> caseRecordTypeDevNameById;
    private static Map<String, Case_Config_Origin__mdt> originConfigMap;
    private static Map<String, Case_Config_Origin__mdt> originConfigSubCatMap;

    /**-----------------------------------------------------------------------------
    * Method name: makeKey
    * Builds composite key in format: RecordType::SubVertical::Category::SubCategory.
    * Used to map Case_Config_Category__mdt records in cache. Overload without
    * subCategory builds the 3-part fallback key.
    * @param recordType    Case RecordType DeveloperName.
    * @param subVertical   Sub Vertical value.
    * @param category      Case Category value.
    * @param subCategory   Case SubCategory value (omit for fallback key).
    * @return              Composite key string.
    -----------------------------------------------------------------------------*/
    private static String normPart(String val) {
        return String.isBlank(val) ? '' : val.trim();
    }

    private static String makeKey(String recordType, String subVertical, String category, String subCategory) {
        return normPart(recordType) + '::' + normPart(subVertical) + '::' + normPart(category) + '::' + normPart(subCategory);
    }

    private static String makeKey(String recordType, String subVertical, String category) {
        return normPart(recordType) + '::' + normPart(subVertical) + '::' + normPart(category);
    }

    private static String makeKey(String recordType, String category) {
        return normPart(recordType) + '::' + normPart(category);
    }

    /*-----------------------------------------------------------------------------
    * METHOD NAME : getCaseRecordTypeDevName
    * Resolves a Case RecordTypeId to its DeveloperName using a cached describe
    * lookup (no SOQL). Returns null if rtId is null or unrecognized.
    -----------------------------------------------------------------------------*/
    private static String getCaseRecordTypeDevName(Id rtId) {
        if (rtId == null) return null;
        if (caseRecordTypeDevNameById == null) {
            caseRecordTypeDevNameById = new Map<Id, String>();
            for (Schema.RecordTypeInfo rti : Case.SObjectType.getDescribe().getRecordTypeInfosById().values()) {
                caseRecordTypeDevNameById.put(rti.getRecordTypeId(), rti.getDeveloperName());
            }
        }
        return caseRecordTypeDevNameById.get(rtId);
    }

    /* -----------------------------------------------------------------------------
    * METHOD NAME : loadConfigCategory
    * Loads Case_Config_Category__mdt records into static cache, one map per tier
    * based on which fields are populated on each row (see field declarations above).
    * A second pass then backfills the broader SV/Category tiers from any row that
    * qualifies for that combination - even one scoped to a specific SubCategory -
    * whenever no dedicated broader-tier row already claimed that key, so a lookup
    * that misses the exact tier still falls back to the closest configured match
    * instead of finding nothing. Executed once per transaction.
    * ----------------------------------------------------------------------------- */
    private static void loadConfigCategory() {
        system.debug('debug: in CaseConfigService.loadConfigCategory');
        if (configExactMap != null) return;

        List<Case_Config_Category__mdt> allConfigs = Case_Config_Category__mdt.getAll().values();

        configExactMap = new Map<String, Case_Config_Category__mdt>();
        configSVMap = new Map<String, Case_Config_Category__mdt>();
        configCatMap = new Map<String, Case_Config_Category__mdt>();

        for (Case_Config_Category__mdt cfg : allConfigs) {
            if (String.isBlank(cfg.Case_Category__c)) continue;

            if (!String.isBlank(cfg.Sub_Category__c)) {
                String key = makeKey(cfg.Record_Type__c, cfg.Sub_Vertical__c, cfg.Case_Category__c, cfg.Sub_Category__c);
                configExactMap.put(key, cfg);
                system.debug('exact key : ' + key + '  cfg :' + cfg);
            } else if (!String.isBlank(cfg.Sub_Vertical__c)) {
                String key = makeKey(cfg.Record_Type__c, cfg.Sub_Vertical__c, cfg.Case_Category__c);
                configSVMap.put(key, cfg);
                system.debug('subvertical key : ' + key + '  cfg :' + cfg);
            } else {
                String key = makeKey(cfg.Record_Type__c, cfg.Case_Category__c);
                configCatMap.put(key, cfg);
                system.debug('category key : ' + key + '  cfg :' + cfg);
            }
        }

        // Fallback pass: let any row for a SubVertical+Category (or just Category) combo
        // stand in as the broader-tier default when that combo has no dedicated row of
        // its own. First matching row wins.
        for (Case_Config_Category__mdt cfg : allConfigs) {
            if (String.isBlank(cfg.Case_Category__c)) continue;

            if (!String.isBlank(cfg.Sub_Vertical__c)) {
                String keySV = makeKey(cfg.Record_Type__c, cfg.Sub_Vertical__c, cfg.Case_Category__c);
                if (!configSVMap.containsKey(keySV)) {
                    configSVMap.put(keySV, cfg);
                    system.debug('subvertical fallback key : ' + keySV + '  cfg :' + cfg);
                }
            }

            String keyCat = makeKey(cfg.Record_Type__c, cfg.Case_Category__c);
            if (!configCatMap.containsKey(keyCat)) {
                configCatMap.put(keyCat, cfg);
                system.debug('category fallback key : ' + keyCat + '  cfg :' + cfg);
            }
        }
    }
    
    /* -----------------------------------------------------------------------------
    * METHOD NAME : loadConfig
    * Loads Case_Config_Origin__mdt records into static cache
    * Creates mapping:label:: Metadata Record
    * Executed once per transaction.
    * ----------------------------------------------------------------------------- */
    public static void loadConfigOrigin() {
        system.debug('debug: in CaseConfigService.loadConfigOrigin');
        if (originConfigMap != null) return;
        
        originConfigMap = new Map<String, Case_Config_Origin__mdt>();
        originConfigSubCatMap = new Map<String, Case_Config_Origin__mdt>();
        
        for (Case_Config_Origin__mdt cfg : Case_Config_Origin__mdt.getAll().values()) {
            if (String.isBlank(cfg.MasterLabel)) continue;
            //if(originConfigMap.get(cfg.MasterLabel) == null) {originConfigMap.put(cfg.DeveloperName, cfg);}
            if(originConfigMap.get(cfg.DeveloperName) == null) {originConfigMap.put(cfg.DeveloperName, cfg);}
            string key = (cfg.SourceSubCategory__c != null) ? cfg.MasterLabel + '_' + cfg.SourceSubCategory__c.replace('&','And').replace(' ','_').replace('(','').replace(')','').replace('/','_') : cfg.MasterLabel;
            if(cfg.SourceSubCategory__c != null && originConfigSubCatMap.get(key) == null) {originConfigSubCatMap.put(key, cfg);}
            system.debug('key23 : ' + cfg.MasterLabel + '  cfg :' + cfg);
            system.debug('key for originConfigMap: ' + key);
            system.debug('key23.DeveloperName : ' + cfg.DeveloperName );
        }
    }
    
    /*-----------------------------------------------------------------------------
    * METHOD NAME : applyCategoryConfig
    * Applies configuration to Cases based on Category/SubCategory.
    * - Detects category changes.
    * - Fetches matching metadata (exact or fallback).
    * - Sets Organization, Department, Queue, Owner, Priority.
    * - Calculates Queue Owner Target SLA using Business Hours.
    * @param newList   Trigger.new Cases to update.
    * @param oldMap    Trigger.oldMap for change detection (nullable on insert)
    * -----------------------------------------------------------------------------*/
    public static void applyCategoryConfig(List<Case> newList, Map<Id, Case> oldMap) 
    {
        system.debug('debug: in applyCategoryConfig');
        if (newList == null || newList.isEmpty()) return;
        
        loadConfigCategory();
        Map<String, Id> queueMap = ServiceUtility.getQueueDevNameIdMap();
        for (Case c : newList) {
            
            Case oldCase = (oldMap != null) ? oldMap.get(c.Id) : null;
            Boolean categoryChanged = (oldCase == null || oldCase.CaseCategory__c != c.CaseCategory__c || oldCase.CaseSubCategory__c != c.CaseSubCategory__c
                                        || oldCase.Sub_Vertical__c != c.Sub_Vertical__c || oldCase.RecordTypeId != c.RecordTypeId);
            system.debug('debug: categoryChanged ' + categoryChanged);
            // If category is 'Duplicate Case' do not change any existing catalogue values  *******
            //Duplicate Case category was agreed to be used only by Dhouha and no other user.
            categoryChanged = (c.CaseCategory__c == 'Duplicate Case') ? false:categoryChanged;
            system.debug('debug: categoryChanged ' + categoryChanged);//2.0
            system.debug('debug: c.CaseCategory__c ' + c.CaseCategory__c);//2.0
            // If nothing changed and all driven fields are already filled, skip
            if (!categoryChanged && c.Department__c != null && c.Organization__c != null && c.Vertical__c != null && c.Sub_Vertical__c != null && c.Queue__c != null && c.Priority != null) {
                system.debug('debug: in continue 1');
                continue;
            }

            Case_Config_Category__mdt cfg;
            String caseRecordType = getCaseRecordTypeDevName(c.RecordTypeId);

            // 1) Exact: RecordType + SubVertical + Category + SubCategory
            if (!String.isBlank(c.CaseSubCategory__c)) {
                String keyExact = makeKey(caseRecordType, c.Sub_Vertical__c, c.CaseCategory__c, c.CaseSubCategory__c);
                cfg = configExactMap.get(keyExact);
                system.debug('debug: cfg1 (exact): ' + cfg);
            }

            // 2) Drop SubCategory: RecordType + SubVertical + Category
            if (cfg == null && !String.isBlank(c.Sub_Vertical__c)) {
                String keySV = makeKey(caseRecordType, c.Sub_Vertical__c, c.CaseCategory__c);
                cfg = configSVMap.get(keySV);
                system.debug('debug: cfg2 (subvertical): ' + cfg);
            }

            // 3) Drop SubVertical too: RecordType + Category
            if (cfg == null) {
                String keyCat = makeKey(caseRecordType, c.CaseCategory__c);
                cfg = configCatMap.get(keyCat);
                system.debug('debug: cfg3 (category): ' + cfg);
            }

            // 4) Last resort: assume Standard record type + Category when the Case's actual
            // record type has no configured match (e.g. only Case Category was supplied).
            if (cfg == null && caseRecordType != DEFAULT_RECORD_TYPE) {
                String keyDefault = makeKey(DEFAULT_RECORD_TYPE, c.CaseCategory__c);
                cfg = configCatMap.get(keyDefault);
                system.debug('debug: cfg4 (default record type): ' + cfg);
            }

            if (cfg == null) {
                // Nothing configured for this RecordType/SubVertical/Category/SubCategory combo
                system.debug('debug: in continue 2');
                continue;
            }
            
            // Apply config (always override; wrap per-field with "if (c.X == null)" if you want)
            c.Organization__c = cfg.Organization__c;
            c.Department__c   = cfg.Department__c;
            c.Vertical__c     = cfg.Vertical__c;
            c.Sub_Vertical__c = cfg.Sub_Vertical__c;
            //c.Queue__c        = (c.Origin != label.CaseOriginEmail && c.Origin != label.CaseOriginWeb) ?  cfg.TL_Queue__c : c.Queue__c;//2.0
            c.Queue__c        = cfg.TL_Queue__c;//2.0
            c.OwnerId         = (queueMap != null && queueMap.get(c.Queue__c) != null) ? queueMap.get(c.Queue__c) : c.OwnerId;
            c.Priority        = cfg.Priority__c;
            c.Owner_Queue__c  = cfg.Owner_Queue__c;
            c.Send_Customer_Email__c = cfg.Send_Customer_Email__c;
            system.debug('debug: cfg.Owner_Queue__c ' + cfg.Owner_Queue__c);
            DateTime currTime = DateTime.now();
            Holiday[] holidays = SystemContextClass.getHolidays();
            Map<String,BusinessHours> mapBH = SystemContextClass.getActiveBusinessHours();
            string bhConfigName = (cfg.Owner_Queue__c == 'Contact_Centre' || cfg.Owner_Queue__c == 'Default_Collection' || cfg.Owner_Queue__c == 'Post_Sales' || cfg.Owner_Queue__c == 'Property_Transfer_Services' || cfg.Owner_Queue__c == 'Real_Estate_Services') ? cfg.Owner_Queue__c : 'Default';
            BusinessHours bh = mapBH.get(bhConfigName);
            DateTime targetsla = ServiceUtility.CalculateDueDate(currTime,(Integer)(cfg.Queue_Owner_Target_SLA__c * 60),bh,holidays);
            system.debug('debug: cfg.Queue_Owner_Target_SLA__c ' + cfg.Queue_Owner_Target_SLA__c);
            c.Queue_Owner_Target_SLA__c = targetsla;
            c.Business_Hour_Name__c = bhConfigName;
            system.debug('debug: c.Organization__c ' + c.Organization__c); system.debug('debug: c.Department__c ' + c.Department__c);
            system.debug('debug: c.Vertical__c ' + c.Vertical__c); system.debug('debug: c.Sub_Vertical__c ' + c.Sub_Vertical__c);
            system.debug('debug: c.Origin ' + c.Origin);
            
            system.debug('debug: c.Queue__c ' + c.Queue__c); system.debug('debug: label.CaseOriginEmail ' + label.CaseOriginEmail);
            system.debug('debug: label.CaseOriginWeb ' + label.CaseOriginWeb); system.debug('debug: c.OwnerId ' + c.OwnerId);
            system.debug('debug: c.Priority ' + c.Priority); system.debug('debug: bhConfigName ' + bhConfigName);   
            system.debug('debug: targetsla ' + targetsla); system.debug('debug: currTime ' + currTime);                  
        }
    }
    
    /*-----------------------------------------------------------------------------
    * METHOD NAME : applyOriginConfig
    * Applies configuration to Cases based on Origin.
    * - Fetches matching metadata (exact or fallback).
    * - Sets Channel and Source.
    * @param newList   Trigger.new Cases to update.
    * @param oldMap    Trigger.oldMap for change detection (nullable on insert)
    * -----------------------------------------------------------------------------*/
    public static void applyOriginConfig(List<Case> newList, Map<Id, Case> oldMap) 
    {
        system.debug('debug: in applyOriginConfig');
        if (newList == null || newList.isEmpty()) return;
        
        loadConfigOrigin();
        for (Case c : newList) {
            
            if(c.Origin ==  null || (c.Origin != null && c.Origin.toUpperCase() == 'CHATBOT')) {c.Origin = 'Social';}
            Case oldCase = (oldMap != null) ? oldMap.get(c.Id) : null;
            Boolean originChanged = (oldCase == null || oldCase.Origin != c.Origin);
            system.debug('debug: originChanged ' + originChanged); system.debug('debug: c.Origin ' + c.Origin);
            system.debug('debug: c.CaseCategory__c ' + c.CaseCategory__c); system.debug('debug: c.CaseSubCategory__c ' + c.CaseSubCategory__c);
            
            Case_Config_Origin__mdt cfg;
            Case_Config_Origin__mdt cfgSubCatCat;
            
            string origin = c.Origin.replace(' ','_');
            string subcat = (c.CaseSubCategory__c != null ) ? c.CaseSubCategory__c.replace('&','And').replace(' ','_').replace('(','').replace(')','').replace('/','_') : '';
            string key2 = origin + '_' + subcat;
            
            Key2 = (key2 =='Social_Showroom_Villa_Appointment_Request') ? 'Social_Showroom_Villa_Appointment_Reques':key2;
            Key2 = (key2 =='Chatbot_Showroom_Villa_Appointment_Request') ? 'Chatbot_Showroom_Villa_Appointment_Reque':key2;
            system.debug('debug: originConfigMap.get(key2) ' + originConfigMap.get(key2));
            system.debug('debug: c.Origin ' + c.Origin);
            system.debug('debug: key2 ' + key2);
            
            cfg = originConfigMap.get(key2);
            if(cfg != null)
            {
                c.Channel__c = (c.Channel__c != null) ? c.Channel__c : cfg.Channel__c;
                c.Source__c = (c.Source__c != null) ? c.Source__c : cfg.Source__c;
                system.debug('debug: c.Channel__c ' + c.Channel__c); system.debug('debug: c.Source__c ' + c.Source__c);
                system.debug('debug: cfg.SourceSubCategory__c ' + cfg.SourceSubCategory__c); system.debug('debug: cfg.TargetCategory__c ' + cfg.TargetCategory__c);
                system.debug('debug: cfg.TargetSubCategory__c ' + cfg.TargetSubCategory__c); system.debug('debug: cfg.MasterLabel ' + cfg.MasterLabel);
            }
            //system.debug('debug: c.Origin ' + c.Origin); system.debug('debug: cfg.SourceSubCategory__c ' + cfg.SourceSubCategory__c);
            
            if((c.Origin == label.CaseOriginCustomerPortal || c.Origin == 'Customer_Portal' || c.Origin ==  'Social'|| c.Origin ==  label.CaseOriginWebsite) && cfg != null && cfg.SourceSubCategory__c != null)
            {system.debug('debug: label.CaseOriginCustomerPortal ' + label.CaseOriginCustomerPortal);
                string origin2 = c.Origin.replace(' ','_');
                 string key = origin2 + '_' + c.CaseSubCategory__c.replace('&','And').replace(' ','_').replace('(','').replace(')','').replace('/','_');
                 system.debug('debug: key ' + (key));
                 cfgSubCatCat = originConfigSubCatMap.get(key);
                 system.debug('debug: cfgSubCatCat ' + cfgSubCatCat);
                 c.CaseCategory__c = (cfgSubCatCat != null && cfgSubCatCat.TargetCategory__c != null) ? cfgSubCatCat.TargetCategory__c : null;
                 system.debug('debug: c.CaseCategory__c ' + c.CaseCategory__c);
                 //system.debug('debug: cfgSubCatCat.TargetSubCategory__c ' + cfgSubCatCat.TargetSubCategory__c);
                 c.CaseSubCategory__c = (cfgSubCatCat != null && cfgSubCatCat.TargetSubCategory__c != null) ? cfgSubCatCat.TargetSubCategory__c : null;
                 system.debug('debug: cfg.Channel__c ' + cfg.Channel__c); system.debug('debug: cfg.Source__c ' + cfg.Source__c);  
            }                
        }
    }   
}