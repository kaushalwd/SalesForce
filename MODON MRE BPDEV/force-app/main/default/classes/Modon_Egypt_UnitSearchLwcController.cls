/**********************************************************************************************************************
* Name               : Modon_Egypt_UnitSearchLwcController                                                        
* Description        : This class is used as controller for LWC (modonEgyptUnitSearchLwc)
* Usage              : unitSearchLwc LWC                                                          
* Created By         : Horizontal Digital                                                   
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                          Date            Comment                                                                       
* 1.0          mdixit@horizontal.com            21 May 2025     Initial Draft
* 2.0          mkapatel@horizontal.com          05 Dec 2025     Removed unwated code and added comments for clarity
* 3.0          mkapatel@horizontal.com          22 JAN 2026     Added Payment_Plan__r.Name in generateSalesOffers's UnitPaymentPlanMapping's query
* 4.0          mkapatel@horizontal.com          09 FEB 2026     Added logic to have maintenance fees always calculated based on 8 year payment plan price for MIRE team as per the requirement shared by client.
* 5.0          Mirza Baig                       28 FEB 2026     Added exact booking date logic in sales order isntallment "milestone dates". If sales order has a exact booking date then milestone dates will start from this otherwise from today's date.
* 6.0          Mirza Baig                       04 March 2026   Populated Sales Order Manager
* 7.0          mkapatel@horizontal.com          24 Mar 2026     Code clean up - removed unwanted comments
* 7.1		   mkapatel@horizontal.com			14 Apr 2026     Code Optimization
* 7.2		   mkapatel@horizontal.com			20 Apr 2026     Code Optimization
* 7.3		   mkapatel@horizontal.com			24 Apr 2026     Added Payment_Plan__r.isDefault__c = true in unit payment plan mapping query
* 7.4          nagrawal@horizontal.com          05 Apr 2026     updated logic to set primary contact and show relevant payment based on selected Unit, phase and project. 
* 7.5          mkapatel@horizontal.com          13 May 2026     Added Modon - Egypt Source_Entity__c in block request
* 7.6          mkapatel@horizontal.com          21 May 2026     Updated logic for base price for 8 year plan and furnished 8 year plan.
* 7.7          mkapatel@horizontal.com          25 May 2026     Added flexiblePaymentPlanName to SalesOrderPayload; populate Egypt_Flexible_Payment_Plan__c in saveSalesOrder and saveSalesOrderWithBlockRequest.
* 7.8          mkapatel@horizontal.com          26 May 2026     Adjusting last installment amount to make it equal to the price mentioned in Unit Payment Plan Mapping. + Bug fixes
* 7.9          mkapatel@horizontal.com          29 May 2026     Shifted buildSalesOrderInstance code to ModonEgypt_StandardPaymentPlanController
* 7.10         mkapatel@horizontal.com          04 June 2026    Shifted createSalesOrderInstallments to utilities class.
******************************************************************************************************************/
public with sharing class Modon_Egypt_UnitSearchLwcController {
    
    /**************************************************************************************************************************************************************************************
     * Method		 :	checkExistingSalesOrder
     * Description	 :	This method is used to check existing sales order for opportunity
     * Parameters	 :  String oppId
     * Returns		 :	Boolean
    ***************************************************************************************************************************************************************************************/
    @AuraEnabled
    public static Boolean checkExistingSalesOrder(String oppId){
        List<SalesOrder__c> soLst = [SELECT Id FROM SalesOrder__c WHERE Status__c NOT IN (:ModonEgyptConstants.STATUS_CANCELLED, :ModonEgyptConstants.STATUS_SYSTEM_CANCELLED, :ModonEgyptConstants.STATUS_VOIDED) AND Opportunity__c = :oppId];
        if(!soLst.isEmpty()){
            return true;
        }
        return false;
    }
    
    /**************************************************************************************************************************************************************************************
     * Method		 :	getAllProjects
     * Description	 :	This method is used to get all projects for Modon - Egypt source entity
     * Parameters	 :  String oppId
     * Returns		 :	List<Map<String, String>>
    ***************************************************************************************************************************************************************************************/
    @AuraEnabled
    public static List<Map<String, String>> getAllProjects(String oppId) {
        List<Map<String, String>> filtersToReturn = new List<Map<String, String>>();
        
        try {
            Opportunity opp = [SELECT Id, Name, Source_Entity__c FROM Opportunity WHERE Id = :oppId LIMIT 1];
            
            List<Project__c> projectsList = new List<Project__c>();
            if (opp.Source_Entity__c == ModonEgyptConstants.MODON_EGYPT_SOURCE_ENTITY) {
                projectsList = [SELECT Id, Name, Source_Entity__c 
                                FROM Project__c 
                                WHERE Source_Entity__c = :ModonEgyptConstants.MODON_EGYPT_SOURCE_ENTITY 
                                WITH SECURITY_ENFORCED 
                                ORDER BY Name];
            }
            for (Project__c tempProject : projectsList) {
                Map<String, String> tempMap = new Map<String, String>();
                tempMap.put(ModonEgyptConstants.KEY_LABEL, tempProject.Name);
                tempMap.put(ModonEgyptConstants.KEY_VALUE, tempProject.Id);
                filtersToReturn.add(tempMap);
            }
        } catch (Exception e) {
            throw new AuraHandledException(
                ModonEgyptConstants.MSG_ERR_GET_ALL_PROJECTS + e.getMessage()
            );
        }
        
        return filtersToReturn;
    }
    
    
    /**************************************************************************************************************************************************************************************
     * Method		 :	getAllPhase
     * Description	 :	This method is used to get all phase for selected project
     * Parameters	 :  string projectId
     * Returns		 :	list<map<String,string>>
    ***************************************************************************************************************************************************************************************/
    @AuraEnabled
    public static list<map<String,string>> getAllPhases(string projectId){
        list<map<String,string>> filtersToReturn = new list<map<String,string>>();
        
        for(Phase__c  tempPhase: [Select Id,Name from Phase__c where Project__c   =: projectId WITH SECURITY_ENFORCED order by Name] ){
            map<string,string> tempMap=new map<string,string>();
            tempMap.put(ModonEgyptConstants.KEY_LABEL,tempPhase.Name);
            tempMap.put(ModonEgyptConstants.KEY_VALUE,tempPhase.id);
            filtersToReturn.add(tempMap);
        }
        return filtersToReturn;
    }
    
    /**************************************************************************************************************************************************************************************
     * Method		 :	saveBlockedUnits
     * Description	 :	This method is used to save block request for selected units
     * Parameters	 :  List<String> selectedUnits, String opportunityId, String commentValue, String blockingHours
     * Returns		 :	string
    ***************************************************************************************************************************************************************************************/
    @AuraEnabled
    public static string saveBlockedUnits(List<String> selectedUnits, String opportunityId, String commentValue, String blockingHours){
        List<Block_Request__c> blockRequestLst = new List<Block_Request__c>();
        
        List<Block_Request__c> exstingblockRequestLst = [SELECT Id, Name FROM Block_Request__c WHERE Unit__c IN : selectedUnits AND Status__c = :ModonEgyptConstants.STATUS_IN_PROGRESS];
        
        if(!exstingblockRequestLst.isEmpty()){
            return ModonEgyptConstants.MSG_BLOCK_REQ_IN_PROGRESS_PREFIX + exstingblockRequestLst[0].Name + ModonEgyptConstants.MSG_BLOCK_REQ_IN_PROGRESS_SUFFIX;
        }
        
        
        List<Unit__c> unitLst = [SELECT Id, Name FROM Unit__c WHERE Id IN : selectedUnits AND Status__c = :ModonEgyptConstants.STATUS_RESERVED];
        if(!unitLst.isEmpty()){
            return ModonEgyptConstants.MSG_UNIT_ALREADY_BLOCKED_PREFIX + unitLst[0].Name + ModonEgyptConstants.MSG_UNIT_ALREADY_BLOCKED_SUFFIX;
        }
        
        for(String unitId : selectedUnits){
            Block_Request__c brObj = new Block_Request__c();
            brObj.Unit__c = unitId;
            brObj.Comment__c = commentValue;
            brObj.Opportunity__c = opportunityId;
            brObj.Hourstoblock__c = blockingHours;
            brObj.Source_Entity__c = ModonEgyptConstants.MODON_EGYPT_SOURCE_ENTITY;
            blockRequestLst.add(brObj);
        }
        try{
            INSERT blockRequestLst;
        }catch(Exception ex){
            return ex.getMessage();
        }
        return ModonEgyptConstants.MSG_SUCCESS;
    }
    

    /**************************************************************************************************************************************************************************************
     * Method		 :	getUnitTypes
     * Description	 :	This method is used to get all unit types values
     * Parameters	 :  none
     * Returns		 :	list<map<String,string>>
    ***************************************************************************************************************************************************************************************/
    @AuraEnabled
    public static list<map<String,string>> getUnitTypes(){
        list<map<String,string>> filtersToReturn = new list<map<String,string>>();
        List<Schema.PickListEntry> pickListValues = getPickListEntries(ModonEgyptConstants.API_OBJ_UNIT, ModonEgyptConstants.API_FIELD_UNIT_CLASSIFICATION);
        
        for(Schema.PickListEntry ple : pickListValues){
            map<string,string> tempMap=new map<string,string>();
            tempMap.put(ModonEgyptConstants.KEY_LABEL,ple.getLabel());
            tempMap.put(ModonEgyptConstants.KEY_VALUE,ple.getValue());
            filtersToReturn.add(tempMap);
        }
        return filtersToReturn;
    } 
    
    /**************************************************************************************************************************************************************************************
     * Method		 :	getNumberofBedrooms
     * Description	 :	This method is used to get all number of bedrooms values
     * Parameters	 :  none
     * Returns		 :	list<map<String,string>>
    ***************************************************************************************************************************************************************************************/
    @AuraEnabled
    public static list<map<String,string>> getNumberofBedrooms(){
        list<map<String,string>> filtersToReturn = new list<map<String,string>>();
        List<Schema.PickListEntry> pickListValues = getPickListEntries(ModonEgyptConstants.API_OBJ_UNIT, ModonEgyptConstants.API_FIELD_NUMBER_OF_BEDROOMS);
        
        for(Schema.PickListEntry ple : pickListValues){
            map<string,string> tempMap=new map<string,string>();
            tempMap.put(ModonEgyptConstants.KEY_LABEL,ple.getLabel());
            tempMap.put(ModonEgyptConstants.KEY_VALUE,ple.getValue());
            filtersToReturn.add(tempMap);
        }
        return filtersToReturn;
    } 
    
    /**************************************************************************************************************************************************************************************
     * Method		 :	getQualityType
     * Description	 :	This method is used to get all quality type values
     * Parameters	 :  none
     * Returns		 :	list<map<String,string>>
    ***************************************************************************************************************************************************************************************/
    @AuraEnabled
    public static list<map<String,string>> getQualityType(){
        list<map<String,string>> filtersToReturn = new list<map<String,string>>();
        Unit_Search_Filter__mdt qualityTypeFilter = [
            SELECT Id 
            FROM Unit_Search_Filter__mdt 
            WHERE DeveloperName = :ModonEgyptConstants.FILTER_QUALITY_TYPE 
            LIMIT 1
        ];
        
        if (qualityTypeFilter != null) {
            // Get the values mapped to the Floor filter
            List<Unit_Search_Filter_Value__mdt> values = [
                SELECT Label, DeveloperName 
                FROM Unit_Search_Filter_Value__mdt 
                WHERE Unit_Search_Filter__c = :qualityTypeFilter.Id
            ];
            
            for (Unit_Search_Filter_Value__mdt val : values) {
                Map<String, String> tempMap = new Map<String, String>();
                tempMap.put(ModonEgyptConstants.KEY_LABEL, val.Label);
                tempMap.put(ModonEgyptConstants.KEY_VALUE, val.DeveloperName);
                filtersToReturn.add(tempMap);
            }
        }
        return filtersToReturn;
    } 

    /**************************************************************************************************************************************************************************************
     * Method		 :	getCurrencyIsoCodes
     * Description	 :	This method is used to get all active currency ISO codes
     * Parameters	 :  none
     * Returns		 :	list<map<String,string>>
    ***************************************************************************************************************************************************************************************/
    @AuraEnabled
    public static List<Map<String,String>> getCurrencyIsoCodes(){
        List<CurrencyType> currencyIsoCodes = [SELECT IsoCode FROM CurrencyType WHERE IsActive = true];
        List<map<String,string>> filtersToReturn = new list<map<String,string>>();
        
        if (!currencyIsoCodes.isEmpty()) {
            for (CurrencyType cic : currencyIsoCodes) {
                Map<String, String> tempMap = new Map<String, String>();
                tempMap.put(ModonEgyptConstants.KEY_LABEL, cic.IsoCode);
                tempMap.put(ModonEgyptConstants.KEY_VALUE, cic.IsoCode);
                filtersToReturn.add(tempMap);
            }
        }
        return filtersToReturn;
    } 
    
    /**************************************************************************************************************************************************************************************
     * Method		 :	getGFARange
     * Description	 :	This method is used to get all GFA range values
     * Parameters	 :  none
     * Returns		 :	list<map<String,string>>
    ***************************************************************************************************************************************************************************************/
    @AuraEnabled
    public static list<map<String,string>> getGFARange(){
        list<map<String,string>> filtersToReturn = new list<map<String,string>>();
        // Get the 'Floor' filter metadata record
        Unit_Search_Filter__mdt gfaFilter = [
            SELECT Id 
            FROM Unit_Search_Filter__mdt 
            WHERE DeveloperName = :ModonEgyptConstants.FILTER_GFA 
            LIMIT 1
        ];
        
        if (gfaFilter != null) {
            // Get the values mapped to the Floor filter
            List<Unit_Search_Filter_Value__mdt> values = [
                SELECT Label, DeveloperName 
                FROM Unit_Search_Filter_Value__mdt 
                WHERE Unit_Search_Filter__c = :gfaFilter.Id
            ];
            
            for (Unit_Search_Filter_Value__mdt val : values) {
                Map<String, String> tempMap = new Map<String, String>();
                tempMap.put(ModonEgyptConstants.KEY_LABEL, val.Label);
                tempMap.put(ModonEgyptConstants.KEY_VALUE, val.DeveloperName);
                filtersToReturn.add(tempMap);
            }
        }
        return filtersToReturn;
    } 
    
    /**************************************************************************************************************************************************************************************
     * Method		 :	getFloorValues
     * Description	 :	This method is used to get all floor values
     * Parameters	 :  none
     * Returns		 :	list<map<String,string>>
    ***************************************************************************************************************************************************************************************/
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getFloorValues() {
        List<Map<String, String>> filtersToReturn = new List<Map<String, String>>();
        
        // Get the 'Floor' filter metadata record
        Unit_Search_Filter__mdt floorFilter = [
            SELECT Id 
            FROM Unit_Search_Filter__mdt 
            WHERE DeveloperName = :ModonEgyptConstants.FILTER_FLOOR 
            LIMIT 1
        ];
        
        if (floorFilter != null) {
            // Get the values mapped to the Floor filter
            List<Unit_Search_Filter_Value__mdt> values = [
                SELECT Label, DeveloperName 
                FROM Unit_Search_Filter_Value__mdt 
                WHERE Unit_Search_Filter__c = :floorFilter.Id
            ];
            
            for (Unit_Search_Filter_Value__mdt val : values) {
                Map<String, String> tempMap = new Map<String, String>();
                tempMap.put(ModonEgyptConstants.KEY_LABEL, val.Label);
                tempMap.put(ModonEgyptConstants.KEY_VALUE, val.DeveloperName);
                filtersToReturn.add(tempMap);
            }
        }
        
        return filtersToReturn;
    }
    
    /**************************************************************************************************************************************************************************************
     * Method		 :	getPickListEntries
     * Description	 :	This method is used to get picklist entries for given object and field
     * Parameters	 :  String objectName, String fieldName
     * Returns		 :	List<Schema.PickListEntry>
    ***************************************************************************************************************************************************************************************/
    static List<Schema.PickListEntry> getPickListEntries(String objectName, String fieldName){
        
        Schema.SObjectType objSobjectType = Schema.getGlobalDescribe().get(objectName) ;
        Schema.DescribeSObjectResult objDescribeSobject = objSobjectType.getDescribe() ;
        Map<String,Schema.SObjectField> fields = objDescribeSobject.fields.getMap() ;
        Schema.DescribeFieldResult fieldResult = fields.get(fieldName).getDescribe();
        List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
        return ple;
    }

    /**************************************************************************************************************************************************************************************
     * Method		 :	getUnitDetails
     * Description	 :	This method is used to get unit details based on filters
     * Parameters	 :  Id phaseId, String oppId, String unitType, String qualityType, String numberOfBedrooms, String gfaRange, String floor, String unitNumber, String currencyIsoCode
     * Returns		 :	List<GetUnitsWrapper>
    ***************************************************************************************************************************************************************************************/
    @AuraEnabled
    public static List<GetUnitsWrapper> getUnitDetails(Id phaseId, String oppId, String unitType, String qualityType, String numberOfBedrooms, String gfaRange, String floor, String unitNumber, String currencyIsoCode) {
        List<GetUnitsWrapper> unitDetailsWrappers = new List<GetUnitsWrapper>();
        List<Unit__c> unitLst = new List<Unit__c>();
        
        Integer minGFA;
        Integer maxGFA;
        String searchPattern;
        
        try {
            String currencyCode = currencyIsoCode != null ? currencyIsoCode : UserInfo.getDefaultCurrency();
            
            if (String.isNotBlank(gfaRange)) {
                String cleanedRange = gfaRange.replace('X', ModonEgyptConstants.EMPTY_STRING).replace('_', '-'); // → '100-200'               
                if (cleanedRange.contains('-')) {
                    // Case: "100-200"
                    String[] rangeParts = cleanedRange.split('-', 2);
                    if (rangeParts.size() == 2) {
                        minGFA = Integer.valueOf(rangeParts[0].trim());
                        maxGFA = Integer.valueOf(rangeParts[1].trim());
                    }
                } else {
                    minGFA = Integer.valueOf(cleanedRange);
                    maxGFA = null; // or maxGFA = minGFA if needed
                }                
            }
            
            String query;
            Map<String, Object> queryParams = new Map<String, Object>();
            
            String queryPrefix = 'SELECT Id, Name, Phase__c, PlotAreasqm__c, Phase__r.Name, Number_of_Bedrooms__c, ' +
                'Phase__r.Project__c, Phase__r.Project__r.Name, TotalPrice__c, UnitClassification__c, ' +
                'Unit_Quality__c, GrossFloorAreaGFA__c, FloorNumber__c, ' +
                '(SELECT Id FROM Sales_Orders__r WHERE Status__c NOT IN (\'Cancelled\', \'System Cancelled\', \'Voided\')) ' + 
                'FROM Unit__c WHERE ';
            
                // Define variables for binding
                String userId = UserInfo.getUserId();

                // Compose filter conditions
                List<String> coreFilters = new List<String>();
                coreFilters.add('Phase__c = :phaseId');
                coreFilters.add('((Status__c = \'Available\' AND Sub_Status__c = \'Un-Assigned\' AND ApprovalStatus__c = \'Released\') OR (Sub_Status__c = \'Assigned\' AND BlockedFor__c = :userId AND ApprovalStatus__c = \'Released\'))');
                coreFilters.add('(Opportunity__c = null OR Opportunity__c = :oppId)');
                
                List<String> optionalFilters = new List<String>();
                
                if (String.isNotBlank(unitType)) {
                    optionalFilters.add('UnitClassification__c = :unitType');
                }
                if (String.isNotBlank(qualityType)) {
                    optionalFilters.add('Unit_Quality__c = :qualityType');
                }
                if (String.isNotBlank(numberOfBedrooms)) {
                    optionalFilters.add('Number_of_Bedrooms__c = :numberOfBedrooms');
                }
                if (String.isNotBlank(floor)) {
                    optionalFilters.add('FloorNumber__c = :floor');
                }
                if (minGFA != null) {
                    optionalFilters.add('GrossFloorAreaGFA__c >= :minGFA');
                }
                if (maxGFA != null) {
                    optionalFilters.add('GrossFloorAreaGFA__c <= :maxGFA');
                }
            
            String finalWhereClause;
                
                if (String.isNotBlank(unitNumber)) {
                    // If unitNumber is provided, ignore optional filters completely
                    searchPattern = '%' + String.escapeSingleQuotes(unitNumber.trim()) + '%';
                    finalWhereClause = '(' + String.join(coreFilters, ' AND ') +
                        ' AND (Name LIKE :searchPattern))';
                } else {
                    // Normal flow with optional filters
                    finalWhereClause = String.join(coreFilters, ' AND ');
                    if (!optionalFilters.isEmpty()) {
                        finalWhereClause += ' AND ' + String.join(optionalFilters, ' AND ');
                    }
                }
            
            query = queryPrefix + finalWhereClause + ' ORDER BY Name';
            
            queryParams.put('phaseId', phaseId);
            queryParams.put('userId', userId);
            queryParams.put('oppId', oppId);
            if (String.isNotBlank(unitType)) queryParams.put('unitType', unitType);
            if (String.isNotBlank(qualityType)) queryParams.put('qualityType', qualityType);
            if (String.isNotBlank(numberOfBedrooms)) queryParams.put('numberOfBedrooms', numberOfBedrooms);
            if (String.isNotBlank(floor)) queryParams.put('floor', floor);
            if (minGFA != null) queryParams.put('minGFA', minGFA);
            if (maxGFA != null) queryParams.put('maxGFA', maxGFA);
            if (String.isNotBlank(unitNumber)) queryParams.put('searchPattern', searchPattern);

            unitLst = Database.queryWithBinds(query, queryParams, AccessLevel.SYSTEM_MODE);
            
            Set<Id> unitIds = new Set<Id>();
            for (Unit__c unitObj : unitLst) {
                unitIds.add(unitObj.Id);
            }
            //v7.3
            Map<Id, Decimal> basePriceByUnitId = new Map<Id, Decimal>();
            List<UnitPaymentPlanMapping__c> unitPaymentPlanMappingList = [SELECT Id, Unit__c, Base_Price__c, CurrencyIsoCode from UnitPaymentPlanMapping__c WHERE CurrencyIsoCode = :currencyCode AND Name like :ModonEgyptConstants.LIKE_8_YEARS AND Unit__c IN :unitIds AND Payment_Plan__r.isDefault__c = true];
            for(UnitPaymentPlanMapping__c upm : unitPaymentPlanMappingList) {
                basePriceByUnitId.put(upm.Unit__c, upm.Base_Price__c);
            }
            // Filter out units with existing sales orders
            List<Unit__c> validUnitLst = new List<Unit__c>();
            for (Unit__c unitObj : unitLst) {
                Decimal basePrice = basePriceByUnitId.get(unitObj.Id) != null ? basePriceByUnitId.get(unitObj.Id) : 0;
                if (unitObj.Sales_Orders__r.isEmpty()) {
                    GetUnitsWrapper udw = new GetUnitsWrapper();
                    udw.unitObj = unitObj;
                    udw.basePrice = basePrice;
                    udw.basePriceCurrencyIsoCode = currencyCode;
                    unitDetailsWrappers.add(udw);
                }
            }
            return unitDetailsWrappers;
        } catch(Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**************************************************************************************************************************************************************************************
     * Method		 :	isDocumentValidEgypt
     * Description	 :	This method is used to validate required documents for Egypt opportunities is uploaded
     * Parameters	 :  Id opportunityId
     * Returns		 :	DocumentValidationResult
    ***************************************************************************************************************************************************************************************/
    @AuraEnabled(cacheable=true)
    public static DocumentValidationResult isDocumentValidEgypt(Id opportunityId) {
        final String STATUS_UPLOADED = ModonEgyptConstants.DOC_STATUS_UPLOADED;
        final String RECORD_TYPE_ORG = ModonEgyptConstants.RECORD_TYPE_ORG;
        final String RECORD_TYPE_PERSON = ModonEgyptConstants.RECORD_TYPE_PERSON;
        final String COUNTRY_EGYPT = ModonEgyptConstants.COUNTRY_EGYPT;
        
        List<String> orgRequiredDocs = new List<String>{'tax id', 'commercial registration id'};
        List<List<String>> egyptPersonRequiredDocs = new List<List<String>>{
            new List<String>{'national id', 'passport copy'}
        };
        List<List<String>> otherPersonRequiredDocs = new List<List<String>>{
            new List<String>{'proof of residence id', 'passport copy'}
        };
                    
        try {
            Opportunity opp = [
                SELECT Id, AccountId, Account.Nationality__pc, Account.RecordType.Name
                FROM Opportunity
                WHERE Id = :opportunityId
                LIMIT 1
            ];
            
            String country = opp.Account.Nationality__pc;
            String recordTypeName = opp.Account.RecordType.Name;
            
            if (recordTypeName == RECORD_TYPE_PERSON && String.isBlank(country)) {
                return new DocumentValidationResult(false, ModonEgyptConstants.EMPTY_STRING, new List<String>{ModonEgyptConstants.DOC_ERR_NATIONALITY_REQUIRED});
            }
            
            List<Documents__c> docs = [
                SELECT Name, Status__c
                FROM Documents__c
                WHERE Opportunity__c = :opportunityId
            ];
            Map<String, String> documentStatusMap = new Map<String, String>();
            Map<String, String> originalNameMap = new Map<String, String>();
            for (Documents__c doc : docs) {
                String lowerName = doc.Name.toLowerCase();
                documentStatusMap.put(lowerName, doc.Status__c);
                originalNameMap.put(lowerName, doc.Name);
            }
            
            List<String> missingDocuments = new List<String>();
            
            if (recordTypeName == RECORD_TYPE_ORG) {
                Boolean isAnyDocumentUploaded = false;
                for (String requiredDoc : orgRequiredDocs) {
                    String lowerRequiredDoc = requiredDoc.toLowerCase();
                    if (documentStatusMap.containsKey(lowerRequiredDoc) && documentStatusMap.get(lowerRequiredDoc) == STATUS_UPLOADED) {
                        isAnyDocumentUploaded = true;
                        break;
                    }
                }
                if (!isAnyDocumentUploaded) {
                    return new DocumentValidationResult(false, country, new List<String>{ModonEgyptConstants.DOC_ERR_ORG_AT_LEAST_ONE_PREFIX + String.join(orgRequiredDocs,' or ')});
                }
            } else if (recordTypeName == RECORD_TYPE_PERSON) {
                List<List<String>> requiredDocGroups = (country == COUNTRY_EGYPT) ? egyptPersonRequiredDocs : otherPersonRequiredDocs;
                
                for (List<String> docGroup : requiredDocGroups) {
                    Boolean groupSatisfied = false;
                    for (String doc : docGroup) {
                        String lowerDoc = doc.toLowerCase();
                        if (documentStatusMap.containsKey(lowerDoc) && documentStatusMap.get(lowerDoc) == STATUS_UPLOADED) {
                            groupSatisfied = true;
                            break;
                        }
                    }
                    if (!groupSatisfied) {
                        // Add all options in the group as a single message
                        missingDocuments.add(ModonEgyptConstants.DOC_ERR_PERSON_AT_LEAST_ONE_PREFIX + String.join(docGroup, ' or '));
                    }
                }
            } else {
                return new DocumentValidationResult(false, country, new List<String>{ModonEgyptConstants.DOC_ERR_UNSUPPORTED_RECORD_TYPE_PREFIX + recordTypeName});
            }
            
            Boolean allDocumentsUploaded = missingDocuments.isEmpty();
            return new DocumentValidationResult(allDocumentsUploaded, country, missingDocuments);
        } catch (Exception e) {
            return new DocumentValidationResult(false, ModonEgyptConstants.EMPTY_STRING, new List<String>{ModonEgyptConstants.DOC_ERR_GENERIC_PREFIX + e.getMessage()});
        }
    }

    //v7.9
 
    /**************************************************************************************************************************************************************************************
     * Method		 :	checkUnitStatus
     * Description	 :	This method is used to check unit status before booking/blocking
     * Parameters	 :  List<String> selectedUnits
     * Returns		 :	string
    ***************************************************************************************************************************************************************************************/
    @AuraEnabled
    public static String checkUnitStatus(List<String> selectedUnits){
        Map<Id, Unit__c> unitMap = new Map<Id, Unit__c>([SELECT Id, Name, Status__c, BlockedFor__c, BlockedBy__c, 
                                                         Opportunity__c ,Sub_Status__c
                                                         FROM Unit__c 
                                                         WHERE Id IN : selectedUnits]);
        
        List<Unit__c> unitLst = new List<Unit__c>();
        for(String unitId : selectedUnits){ //Add Update the Change as par of new status
            if(unitMap.get(unitId).Status__c == ModonEgyptConstants.STATUS_AVAILABLE && unitMap.get(unitId).Sub_Status__c == ModonEgyptConstants.SUBSTATUS_ASSIGNED && unitMap.get(unitId).BlockedFor__c != UserInfo.getUserId()){
                return ModonEgyptConstants.MSG_UNIT_RESERVED_BY_OTHER_PREFIX + unitMap.get(unitId).Name + ModonEgyptConstants.MSG_UNIT_RESERVED_BY_OTHER_SUFFIX;
            }
        }
        return ModonEgyptConstants.MSG_SUCCESS;
    }

    /**************************************************************************************************************************************************************************************
     * Method		 :	saveSalesOrder
     * Description	 :	This method is used to save sales order with booking process
     * Parameters	 :  List<SalesOrderPayload> salesOrderPayloads, String oppId
     * Returns		 :	String
    ***************************************************************************************************************************************************************************************/
    @AuraEnabled
    public static String saveSalesOrder(List<SalesOrderPayload> salesOrderPayloads, String oppId){
        String successMessage = ModonEgyptConstants.MSG_SUCCESS;

        // 1. Map Payloads to actual sObjects
        List<SalesOrder__c> salesOrderList = new List<SalesOrder__c>();
        Map<Integer, List<ModonEgyptUtilities.CustomInstallment>> tempFlexMap = new Map<Integer, List<ModonEgyptUtilities.CustomInstallment>>();

        for(Integer i = 0; i < salesOrderPayloads.size(); i++) {
            SalesOrderPayload payload = salesOrderPayloads[i];
            
            SalesOrder__c so = new SalesOrder__c();
            so.PaymentPlan__c = String.isNotBlank(payload.paymentPlan) ? payload.paymentPlan : null;
            so.PrimaryContact__c = payload.primaryContact;
            so.Unit__c = payload.unit;
            so.TotalAmount__c = payload.totalAmount;
            so.CustomerAccount__c = payload.customerAccount;
            so.CurrencyIsoCode = payload.currencyIsoCode;
            so.Total_Amount_In_EGP__c = payload.totalAmountInEGP;
            so.Total_Amount_In_USD__c = payload.totalAmountInUSD;
            so.Total_Amount_In_AED__c = payload.totalAmountInAED;
            so.Unit_Selling_Price__c = payload.unitSellingPrice;
            so.BasePrice8Y_EGP__c = payload.basePrice8YEGP;
            so.ExactBookingDate_Egypt__c = payload.exactBookingDateEgypt;
            so.Egypt_Flexible_Payment_Plan__c = String.isNotBlank(payload.flexiblePaymentPlanName) ? payload.flexiblePaymentPlanName : null; // v7.7
            
            salesOrderList.add(so);
            
            // If flexible plan, store the array via index because the Sales Order doesn't have an ID yet
            if(payload.customInstallments != null && !payload.customInstallments.isEmpty()) {
                tempFlexMap.put(i, payload.customInstallments);
            }
        }
  
        set<String> unitIds = new set<String>();
        for(SalesOrder__c soObj : salesOrderList){
            unitIds.add(soObj.Unit__c);
        }
        List<Unit__c> unitList = [SELECT Id, Name, Source_Entity__c, BlockedBy__c, BlockedFor__c,Blocked_Time__c, Status_Change_Time__c, Opportunity__c, Status__c, Sub_Status__c,ApprovalStatus__c,Phase__c, Phase__r.Name FROM Unit__c WHERE Id IN : unitIds];

        Map<String, Unit__c> unitMap = new Map<String, Unit__c>();
        for(Unit__c unitObj : unitList){
            unitMap.put(unitObj.Id, unitObj);
        }

        List<Unit__c> updateUnitLst = new List<Unit__c>();

        if(!unitList.isEmpty()){
            for(Unit__c unitObj : unitList){
                if(unitObj.Sub_Status__c == ModonEgyptConstants.SUBSTATUS_ASSIGNED && unitObj.BlockedFor__c != null && (unitObj.BlockedFor__c != UserInfo.getUserId() || (unitObj.Opportunity__c != oppId && unitObj.Opportunity__c != null))){
                    return ModonEgyptConstants.MSG_UNIT_NOT_AVAILABLE_FOR_BOOKING;
                }

                if((unitObj.Status__c == ModonEgyptConstants.STATUS_AVAILABLE && (unitObj.Sub_Status__c == ModonEgyptConstants.SUBSTATUS_UNASSIGNED || unitObj.Sub_Status__c == ModonEgyptConstants.SUBSTATUS_ASSIGNED)) || (unitObj.Sub_Status__c == ModonEgyptConstants.SUBSTATUS_ASSIGNED  && unitObj.BlockedFor__c == UserInfo.getUserId())){
                    unitObj.Status__c = ModonEgyptConstants.STATUS_RESERVED;
                    unitObj.Sub_Status__c = ModonEgyptConstants.EMPTY_STRING;
                    unitObj.ApprovalStatus__c = ModonEgyptConstants.APPROVAL_STATUS_RELEASED;
                    unitObj.BlockedFor__c = UserInfo.getUserId();
                    unitObj.Opportunity__c = oppId;
                    if(unitObj.Source_Entity__c == ModonEgyptConstants.MODON_EGYPT_SOURCE_ENTITY){
                        unitObj.BlockUntil__c = System.now().addMinutes(60);
                    }else{
                        unitObj.BlockUntil__c = null;
                    }
                    unitObj.Status_Change_Time__c = DATETIME.NOW();
                    unitObj.Blocked_Time__c = DATETIME.NOW();
                    if(String.isBlank(unitObj.BlockedBy__c) && unitObj.Source_Entity__c != ModonEgyptConstants.MODON_EGYPT_SOURCE_ENTITY){
                        unitObj.BlockedBy__c = UserInfo.getUserId();
                    }
                    updateUnitLst.add(unitObj);
                }
            }   
        }else{
            return ModonEgyptConstants.MSG_UNIT_NOT_AVAILABLE_FOR_BOOKING;
        }
        
        //v6.0
        User currentUser = [SELECT Id, Name, Profile.Name, UserRole.Name, ManagerId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        String roleName = currentUser.UserRole.Name;
        String managerId = currentUser.ManagerId;
        //end
        
        
        List<Opportunity> oppLst = [SELECT Id, Name, PrimaryContact__c, CustomerType__c, UAE_Resident_Status__c,AccountId, Account.PersonContactId FROM Opportunity WHERE Id = :oppId];
        if(!salesOrderList.isEmpty()){
            for(SalesOrder__c salesOrderObj : salesOrderList){
                // Retrieve the unit for the current sales order
                Unit__c currentUnit = unitMap.get(salesOrderObj.Unit__c);
                
                if(String.isNotBlank(oppLst[0].PrimaryContact__c)){
                    salesOrderObj.PrimaryContact__c = oppLst[0].PrimaryContact__c;
                }

                salesOrderObj.OwnerManager_Egypt__c = managerId;//v6.0

                salesOrderObj.CustomerAccount__c = oppLst[0].AccountId;
                salesOrderObj.Opportunity__c = oppId;
                salesOrderObj.CustomerType__c = oppLst[0].CustomerType__c;
                salesOrderObj.UAE_Resident_Status__c =oppLst[0].UAE_Resident_Status__c;
                if (currentUnit.Source_Entity__c == ModonEgyptConstants.MODON_EGYPT_SOURCE_ENTITY) {
                    salesOrderObj.Source_Entity__c = ModonEgyptConstants.MODON_EGYPT_SOURCE_ENTITY;
                    salesOrderObj.AutoEndDate__c = System.now().addMinutes(60);
                }
                if(roleName != null && roleName.contains(ModonEgyptConstants.MODON_EGYPT_SALES_ASSOCIATE_ROLE_SUBSTR)){
                    salesOrderObj.SalesAssociate__c = UserInfo.getUserId();
                    salesOrderObj.CurrencyIsoCode = salesOrderObj.CurrencyIsoCode;
                }
            }
            Savepoint sp = Database.setSavepoint();
            try{
                
                if(!updateUnitLst.isEmpty()){
                    UPDATE updateUnitLst;
                }    
                //insert new sales order
                INSERT salesOrderList;
                // Map the newly created Sales Order IDs to their Flexible Installments
                Map<Id, List<ModonEgyptUtilities.CustomInstallment>> flexInstallmentMap = new Map<Id, List<ModonEgyptUtilities.CustomInstallment>>();
                for(Integer i = 0; i < salesOrderList.size(); i++) {
                    if(tempFlexMap.containsKey(i)) {
                        flexInstallmentMap.put(salesOrderList[i].Id, tempFlexMap.get(i));
                    }
                }

                // Pass both Standard and Flexible data to the generator
                String message = ModonEgyptUtilities.createSalesOrderInstallments(salesOrderList, flexInstallmentMap);

                if(!message.equals(ModonEgyptConstants.MSG_SUCCESS)){
                    Database.rollback(sp);
                    return message;
                }

            }catch(Exception ex){
                Database.rollback(sp);
                return ex.getMessage();
            }
        }
        return successMessage;
    }

    /**************************************************************************************************************************************************************************************
     * Method		 :	saveSalesOrderWithBlockRequest
     * Description	 :	This method is used to save sales order with block request process
     * Parameters	 :  List<SalesOrderPayload> salesOrderPayloads, String oppId
     * Returns		 :	String
    ***************************************************************************************************************************************************************************************/
    @AuraEnabled
    public static String saveSalesOrderWithBlockRequest(List<SalesOrderPayload> salesOrderPayloads, String oppId ){
        String blockRequestResponse;

        // 1. Map Payloads to actual sObjects
        List<SalesOrder__c> salesOrderList = new List<SalesOrder__c>();
        Map<Integer, List<ModonEgyptUtilities.CustomInstallment>> tempFlexMap = new Map<Integer, List<ModonEgyptUtilities.CustomInstallment>>();
        
        for(Integer i = 0; i < salesOrderPayloads.size(); i++) {
            SalesOrderPayload payload = salesOrderPayloads[i];
            
            SalesOrder__c so = new SalesOrder__c();
            so.PaymentPlan__c = String.isNotBlank(payload.paymentPlan) ? payload.paymentPlan : null;
            so.PrimaryContact__c = payload.primaryContact;
            so.Unit__c = payload.unit;
            so.TotalAmount__c = payload.totalAmount;
            so.CustomerAccount__c = payload.customerAccount;
            so.CurrencyIsoCode = payload.currencyIsoCode;
            so.Total_Amount_In_EGP__c = payload.totalAmountInEGP;
            so.Total_Amount_In_USD__c = payload.totalAmountInUSD;
            so.Total_Amount_In_AED__c = payload.totalAmountInAED;
            so.Unit_Selling_Price__c = payload.unitSellingPrice;
            so.BasePrice8Y_EGP__c = payload.basePrice8YEGP;
            so.ExactBookingDate_Egypt__c = payload.exactBookingDateEgypt;
            so.Egypt_Flexible_Payment_Plan__c = String.isNotBlank(payload.flexiblePaymentPlanName) ? payload.flexiblePaymentPlanName : null; // v7.7
            
            salesOrderList.add(so);
            
            // If flexible plan, store the array via index because the Sales Order doesn't have an ID yet
            if(payload.customInstallments != null && !payload.customInstallments.isEmpty()) {
                tempFlexMap.put(i, payload.customInstallments);
            }
        }

        List<Opportunity> oppLst = [SELECT Id, Name, PrimaryContact__c, CustomerType__c, UAE_Resident_Status__c,AccountId, Account.PersonContactId  , Account.Nationality__pc FROM Opportunity WHERE Id = :oppId];
        
        
        set<String> unitIds = new set<String>();
        for(SalesOrder__c soObj : salesOrderList){
            unitIds.add(soObj.Unit__c);
        }
        
        List<Unit__c> unitList = [SELECT Id, Name, BlockedBy__c, BlockedFor__c,Blocked_Time__c, Status_Change_Time__c, Opportunity__c, Status__c, Sub_Status__c,ApprovalStatus__c,Phase__c, Phase__r.Name, Phase__r.EscrowAccount__c FROM Unit__c WHERE Id IN : unitIds];
        
        
        List<Unit__c> updateUnitLst = new List<Unit__c>();
        
        if(!unitList.isEmpty()){
            for(Unit__c unitObj : unitList){
                if(unitObj.Sub_Status__c == ModonEgyptConstants.SUBSTATUS_ASSIGNED && unitObj.BlockedFor__c != null && (unitObj.BlockedFor__c != UserInfo.getUserId() || (unitObj.Opportunity__c != oppId && unitObj.Opportunity__c != null))){
                    return ModonEgyptConstants.MSG_UNIT_NOT_AVAILABLE_FOR_BOOKING;
                }
                
                if((unitObj.Status__c == ModonEgyptConstants.STATUS_AVAILABLE && (unitObj.Sub_Status__c == ModonEgyptConstants.SUBSTATUS_UNASSIGNED || unitObj.Sub_Status__c == ModonEgyptConstants.SUBSTATUS_ASSIGNED)) || (unitObj.Sub_Status__c == ModonEgyptConstants.SUBSTATUS_ASSIGNED  && unitObj.BlockedFor__c == UserInfo.getUserId())){
                    unitObj.Status__c = ModonEgyptConstants.STATUS_AVAILABLE;
                    unitObj.Sub_Status__c = ModonEgyptConstants.SUBSTATUS_ASSIGNED;
                    unitObj.BlockedFor__c = UserInfo.getUserId();
                    unitObj.Opportunity__c = oppId;
                    unitObj.BlockUntil__c = System.now().addMinutes(60);
                    unitObj.Status_Change_Time__c = DATETIME.NOW();
                    unitObj.Blocked_Time__c = DATETIME.NOW();
                    updateUnitLst.add(unitObj);
                }
            }
        } else {
            return ModonEgyptConstants.MSG_UNIT_NOT_AVAILABLE_FOR_BOOKING;
        }

        
        //v6.0
        User currentUser = [SELECT Id, Name, Profile.Name, UserRole.Name, ManagerId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        String roleName = currentUser.UserRole.Name;
        String managerId = currentUser.ManagerId;
        //end
        
        if(!salesOrderList.isEmpty()){
            for(SalesOrder__c salesOrderObj : salesOrderList){
                //Set Primary contact as Primary contact information is needed in Reservation and SPA 
                if(String.isNotBlank(oppLst[0].PrimaryContact__c)){
                    salesOrderObj.PrimaryContact__c = oppLst[0].PrimaryContact__c;
                }
                salesOrderObj.OwnerManager_Egypt__c = managerId;//v6.0
                salesOrderObj.Status__c = ModonEgyptConstants.STATUS_PENDING_BLOCKING_FEES;
                salesOrderObj.CustomerAccount__c = oppLst[0].AccountId;
                salesOrderObj.Opportunity__c = oppId;
                salesOrderObj.CustomerType__c = oppLst[0].CustomerType__c;
                salesOrderObj.UAE_Resident_Status__c = oppLst[0].UAE_Resident_Status__c;
                salesOrderObj.AutoEndDate__c = System.now().addMinutes(60);
                salesOrderObj.Source_Entity__c = ModonEgyptConstants.MODON_EGYPT_SOURCE_ENTITY;
                
                if(roleName != null && roleName.contains(ModonEgyptConstants.MODON_EGYPT_SALES_ASSOCIATE_ROLE_SUBSTR)){
                    salesOrderObj.SalesAssociate__c = UserInfo.getUserId();
                    salesOrderObj.CurrencyIsoCode = salesOrderObj.CurrencyIsoCode;
                }
            }
            
            // Determine block duration based on nationality
            String blockHours = '24';
            
            // Attempt to create block requests BEFORE DML to prevent partial processing
            blockRequestResponse = createBlockRequest(new List<String>(unitIds), oppId, ModonEgyptConstants.BLOCK_COMMENT_WITH_FEE, blockHours , 'Approved');
            
            // If block request failed, exit early
            if (blockRequestResponse != ModonEgyptConstants.MSG_SUCCESS) {
                return blockRequestResponse;
            }
            
            Savepoint sp = Database.setSavepoint();
            try {
                // Update units if any
                if (!updateUnitLst.isEmpty()) {
                    update updateUnitLst;
                }
                
                // Insert sales orders
                insert salesOrderList;
                
                // Map the newly created Sales Order IDs to their Flexible Installments
                Map<Id, List<ModonEgyptUtilities.CustomInstallment>> flexInstallmentMap = new Map<Id, List<ModonEgyptUtilities.CustomInstallment>>();
                for(Integer i = 0; i < salesOrderList.size(); i++) {
                    if(tempFlexMap.containsKey(i)) {
                        flexInstallmentMap.put(salesOrderList[i].Id, tempFlexMap.get(i));
                    }
                }
                
                // Pass both Standard and Flexible data to the generator
                String message = ModonEgyptUtilities.createSalesOrderInstallments(salesOrderList, flexInstallmentMap);

                if(!message.equals(ModonEgyptConstants.MSG_SUCCESS)){
                    Database.rollback(sp);
                    return message;
                }
                
            } catch (Exception ex) {
                Database.rollback(sp);
                return ex.getMessage();
            }
        }
        
        return ModonEgyptConstants.MSG_SUCCESS;
    }

    /**************************************************************************************************************************************************************************************
     * Method		 :	createBlockRequest
     * Description	 :	This method is used to create block request records for selected units
     * Parameters	 :  List<String> selectedUnits, String opportunityId, String commentValue, String blockingHours , String Status
     * Returns		 :	string
    ***************************************************************************************************************************************************************************************/
    public static string createBlockRequest(List<String> selectedUnits, String opportunityId, String commentValue, String blockingHours , String Status){
        List<Block_Request__c> blockRequestLst = new List<Block_Request__c>();
        
        List<Block_Request__c> exstingblockRequestLst = [SELECT Id, Name FROM Block_Request__c WHERE Unit__c IN : selectedUnits AND Status__c = 'In Progress'];
        
        if(!exstingblockRequestLst.isEmpty()){
            return ModonEgyptConstants.MSG_BLOCK_REQ_IN_PROGRESS_PREFIX + exstingblockRequestLst[0].Name + ModonEgyptConstants.MSG_BLOCK_REQ_IN_PROGRESS_SUFFIX;
        }
        
        
        List<Unit__c> unitLst = [SELECT Id, Name FROM Unit__c WHERE Id IN : selectedUnits AND Status__c = 'Reserved'];
        if(!unitLst.isEmpty()){
            return ModonEgyptConstants.MSG_UNIT_ALREADY_BLOCKED_PREFIX + unitLst[0].Name + ModonEgyptConstants.MSG_UNIT_ALREADY_BLOCKED_SUFFIX;
        }
        
        for(String unitId : selectedUnits){
            Block_Request__c brObj = new Block_Request__c();
            brObj.Unit__c = unitId;
            brObj.Comment__c = commentValue;
            brObj.Opportunity__c = opportunityId;
            brObj.Hourstoblock__c = blockingHours;
            brObj.Status__c = Status;
            brObj.Source_Entity__c = ModonEgyptConstants.MODON_EGYPT_SOURCE_ENTITY;
            blockRequestLst.add(brObj);
        }
        try{
            INSERT blockRequestLst;
        }catch(Exception ex){
            return ex.getMessage();
        }
        return ModonEgyptConstants.MSG_SUCCESS;
    }

    // ================== WRAPPER CLASSES ================== //


    public class SalesOrderPayload {
        @AuraEnabled public String paymentPlan {get;set;}
        @AuraEnabled public String primaryContact {get;set;}
        @AuraEnabled public String unit {get;set;}
        @AuraEnabled public Decimal totalAmount {get;set;}
        @AuraEnabled public String customerAccount {get;set;}
        @AuraEnabled public String currencyIsoCode {get;set;}
        @AuraEnabled public Decimal totalAmountInEGP {get;set;}
        @AuraEnabled public Decimal totalAmountInUSD {get;set;}
        @AuraEnabled public Decimal totalAmountInAED {get;set;}
        @AuraEnabled public Decimal unitSellingPrice {get;set;}
        @AuraEnabled public Decimal basePrice8YEGP {get;set;}
        @AuraEnabled public Date exactBookingDateEgypt {get;set;}
        @AuraEnabled public List<ModonEgyptUtilities.CustomInstallment> customInstallments {get;set;}
        @AuraEnabled public String flexiblePaymentPlanName {get;set;} // v7.7 — populated only for Flexible Payment Plan; maps to Egypt_Flexible_Payment_Plan__c
    }

    public class DocumentValidationResult {
        @AuraEnabled public Boolean isValid;
        @AuraEnabled public String nationality;
        @AuraEnabled public List<String> requiredDoc;
        
        public DocumentValidationResult(Boolean isValid, String nationality, List<String> requiredDoc) {
            this.isValid = isValid;
            this.nationality = nationality;
            this.requiredDoc = requiredDoc;
        }
    }

    public class GetUnitsWrapper {
        @AuraEnabled public Unit__c unitObj { get; set; }
        @AuraEnabled public Decimal basePrice { get; set; }
        @AuraEnabled public String basePriceCurrencyIsoCode { get; set; }
    }
}