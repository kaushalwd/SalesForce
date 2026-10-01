/**
* @description       : Apex controller used by Unit Search LWCs to retrieve and prepare
*                      Units, Projects, Phases, Zones, and pricing data.
*                      Supports multi-currency pricing, filtering, aggregation logic,
*                      and provides wrapper classes for optimized UI consumption.
*                      Handles large datasets (50k+) automatically with batching.
*
* @author            : Mostafa Abdelrehem
* @company           : CloudzLab
* @last modified on  : 08-12-2025
* @last modified by  : Mostafa Abdelrehem
*
* Modifications Log
* Ver   Date         Author             Modification
* 1.0   08-12-2025   Mostafa Abdelrehem   Initial Version
* 1.1   29-12-2025   Mostafa Abdelrehem   Added support for large datasets (50k+)
* 1.2   16-01-2026   Mostafa Abdelrehem   Added Visible_to_MRE_SalesTeam filter
* 1.3   22-01-2026   Mostafa Abdelrehem   Added ApprovalStatus__c and Sub_Status__c filter
**/
public without sharing class UnitSearchResultController {
    
    private static final Integer BATCH_SIZE = 10000;
    private static final Integer MAX_RECORDS = 50000; // Salesforce hard limit
    
    // method to get all unit data
    @AuraEnabled
    public static Map<String, Object> getAllDataForSearch(String sourceEntity) {
        Map<String, Object> result = new Map<String, Object>();
        
        try {
            // Count units first to determine strategy
            Integer unitCount = [
                SELECT COUNT() 
                FROM Unit__c 
                WHERE TotalPrice__c > 0 AND Source_Entity__c = :sourceEntity
            ];
            
            System.debug('Total units found: ' + unitCount);
            
            List<Unit__c> units;
            
            // Choose strategy based on count
            if (unitCount > BATCH_SIZE) {
                System.debug('Using batched query for large dataset');
                units = getUnitsInBatches(sourceEntity, unitCount);
            } else {
                System.debug('Using single query for small dataset');
                units = querySingleBatch(sourceEntity, BATCH_SIZE, 0);
            }
            
            // Get all phases for the source entity
            List<Phase__c> phases = [
                SELECT Id, Name, Project__r.Id, Project__r.Name
                FROM Phase__c
                WHERE Source_Entity__c = :sourceEntity
                ORDER BY Name ASC
            ];
            
            // Get all projects for the source entity
            List<Project__c> projects = [
                SELECT Id, Name
                FROM Project__c
                WHERE Source_Entity__c = :sourceEntity
                ORDER BY Name ASC
            ];
            
            // Build unique zones list from units
            Map<String, Map<String, Object>> zonesMap = new Map<String, Map<String, Object>>();
            
            for (Unit__c unit : units) {
                if (String.isNotBlank(unit.Zone__c) && unit.Phase__r != null) {
                    String zoneLogoUrl = '/resource/UnitImages/rasElhekma.jpg'; // default image
                    String zoneKey = unit.Zone__c + '_' + unit.Phase__r.Id + '_' + unit.Phase__r.Project__r.Id;
                    
                    if (!zonesMap.containsKey(zoneKey)) {
                        zonesMap.put(zoneKey, new Map<String, Object>{
                            'name' => unit.Zone__c,
                            'phaseId' => unit.Phase__r.Id,
                            'phaseName' => unit.Phase__r.Name,
                            'projectId' => unit.Phase__r.Project__r.Id,
                            'projectName' => unit.Phase__r.Project__r.Name,
                            'logoUrl' => zoneLogoUrl
                        });
                    }
                }
            }
            
            // Build unit list
            List<UnitWrapper> unitList = new List<UnitWrapper>();
            for (Unit__c unit : units) {
                UnitWrapper wrapper = new UnitWrapper(unit);
                
                // Set Project Logo URL  
                wrapper.ProjectLogoUrl = '/resource/UnitImages/rasElhekma.jpg';
                
                // Set Zone Name
                wrapper.ZoneName = unit.Zone__c;
                
                // Set prices for different currencies
                if (unit.UnitPaymentPlanMappings__r != null && !unit.UnitPaymentPlanMappings__r.isEmpty()) {
                    for (UnitPaymentPlanMapping__c mapping : unit.UnitPaymentPlanMappings__r) {
                        if (mapping.CurrencyIsoCode == 'EGP') {
                            wrapper.PriceEGP = mapping.Base_Price__c;
                        } else if (mapping.CurrencyIsoCode == 'USD') {
                            wrapper.PriceUSD = mapping.Base_Price__c;
                        } else if (mapping.CurrencyIsoCode == 'AED') {
                            wrapper.PriceAED = mapping.Base_Price__c;
                        }
                    }
                }
                
                unitList.add(wrapper);
            }
            
            // Build project list
            List<Map<String, String>> projectList = new List<Map<String, String>>();
            for (Project__c project : projects) {
                String ProjectlogoUrl = '/resource/UnitImages/rasElhekma.jpg';// default image
                    
                projectList.add(new Map<String, String>{
                    'id' => project.Id,
                    'name' => project.Name,
                    'logoUrl' => ProjectlogoUrl
                });
            }
            
            // Build phase list
            List<Map<String, String>> phaseList = new List<Map<String, String>>();
            for (Phase__c phase : phases) {
                String PhaselogoUrl = '/resource/UnitImages/rasElhekma.jpg';// default image
                phaseList.add(new Map<String, String>{
                    'id' => phase.Id,
                    'name' => phase.Name,
                    'projectId' => phase.Project__r.Id,
                    'projectName' => phase.Project__r.Name,
                    'logoUrl' => PhaselogoUrl
                });
            }
            
            // Build zones list
            List<Map<String, Object>> zonesList = new List<Map<String, Object>>(zonesMap.values());
            
            result.put('units', unitList);
            result.put('projects', projectList);
            result.put('phases', phaseList);
            result.put('zones', zonesList);
            result.put('defaultCurrency', sourceEntity == 'Modon - Egypt' ? 'EGP' : 'AED');
            result.put('totalUnits', unitCount);
            
            System.debug('Returning ' + unitList.size() + ' units to LWC');
            
            return result;
            
        } catch (Exception e) {
            System.debug('Error in getAllDataForSearch: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error fetching data: ' + e.getMessage());
        }
    }
    
    /**
     * Helper method to get units in batches for large datasets
     * Handles datasets larger than 10k records by using OFFSET
     */
    private static List<Unit__c> getUnitsInBatches(String sourceEntity, Integer totalCount) {
        List<Unit__c> allUnits = new List<Unit__c>();
        Integer offset = 0;
        Integer recordsToFetch = Math.min(totalCount, MAX_RECORDS);
        
        System.debug('Starting batched query. Total to fetch: ' + recordsToFetch);
        
        while (offset < recordsToFetch) {
            Integer currentBatchSize = Math.min(BATCH_SIZE, recordsToFetch - offset);
            
            System.debug('Fetching batch at offset ' + offset + ' with size ' + currentBatchSize);
            
            List<Unit__c> batchUnits = querySingleBatch(sourceEntity, currentBatchSize, offset);
            
            if (batchUnits.isEmpty()) {
                System.debug('No more records found, breaking loop');
                break;
            }
            
            allUnits.addAll(batchUnits);
            offset += currentBatchSize;
            
            System.debug('Total units loaded so far: ' + allUnits.size());
            
            // Safety check: if we got less than expected, we're at the end
            if (batchUnits.size() < currentBatchSize) {
                System.debug('Received fewer records than requested, ending batch load');
                break;
            }
        }
        
        System.debug('Batch loading complete. Total units: ' + allUnits.size());
        return allUnits;
    }
    
    /**
     * Query a single batch of units
     * Separated into its own method to avoid code duplication
     * v1.2: added field Visible_to_MRE_SalesTeam__c on line 216
     * v1.3: added field ApprovalStatus__c and Sub_Status__c on line 217
     */
    private static List<Unit__c> querySingleBatch(String sourceEntity, Integer limitSize, Integer offset) {
        return [
            SELECT Id, Name, Project_Name__c, Phase__r.Project__r.Id, Phase__r.Project__r.Name, 
                TotalPrice__c, Phase__r.Name, Phase__r.Id,
                InventoryStatus__c, CurrencyIsoCode, Status__c, UnitClassification__c, Type__c,
                GrossFloorAreaGFA__c, Internal_Area__c, BalconyArea__c, BasementArea__c,
                BasementParkingArea__c, DriversRoomArea__c, Number_of_Bedrooms__c,
                NumberofAllocatedParking__c, PlotAreasqm__c, PlotNo__c, FirstFloorArea__c,
                GroundFloorArea__c, GroundFloorParkingArea__c, TerraceArea__c, BuildingNo__c,
                FloorNumber__c, Numberofbalcony__c, Numberofbathroom__c, Numberofmaidroom__c,
                Estimated_Completion_Date__c, Zone__c, Visible_to_MRE_SalesTeam__c,
                ApprovalStatus__c , Sub_Status__c,
                (SELECT Id, Base_Price__c, CurrencyIsoCode 
                 FROM UnitPaymentPlanMappings__r 
                 WHERE CurrencyIsoCode IN ('EGP', 'USD', 'AED') AND Name LIKE '%8 Years%' )
            FROM Unit__c
            WHERE TotalPrice__c > 0 AND Source_Entity__c = :sourceEntity
            ORDER BY Id ASC
            LIMIT :limitSize
            OFFSET :offset
        ];
    }
    
    // Wrapper class to hold unit data with multiple currency prices
    // v1.2: Introduce VisibletoMRESalesTeam variable on line 266 and initialize on line 305
    // v1.3: Introduce ApprovalStatus and SubStatus variable on line 271,272 and initialize on line 312,313
    public class UnitWrapper {
        @AuraEnabled public String Id { get; set; }
        @AuraEnabled public String Name { get; set; }
        @AuraEnabled public String ProjectName { get; set; }
        @AuraEnabled public String ProjectId { get; set; }
        @AuraEnabled public String ProjectLogoUrl { get; set; }
        @AuraEnabled public String PhaseName { get; set; }
        @AuraEnabled public String PhaseId { get; set; }
        @AuraEnabled public String ZoneName { get; set; }
        @AuraEnabled public String InventoryStatus { get; set; }
        @AuraEnabled public String CurrencyIsoCode { get; set; }
        @AuraEnabled public String Status { get; set; }
        @AuraEnabled public String UnitClassification { get; set; }
        @AuraEnabled public String UnitType { get; set; }
        @AuraEnabled public Decimal TotalPrice { get; set; }
        @AuraEnabled public Decimal PriceEGP { get; set; }
        @AuraEnabled public Decimal PriceUSD { get; set; }
        @AuraEnabled public Decimal PriceAED { get; set; }
        @AuraEnabled public Decimal GrossFloorArea { get; set; }
        @AuraEnabled public Decimal InternalArea { get; set; }
        @AuraEnabled public Decimal BalconyArea { get; set; }
        @AuraEnabled public Decimal BasementArea { get; set; }
        @AuraEnabled public Decimal BasementParkingArea { get; set; }
        @AuraEnabled public Decimal DriversRoomArea { get; set; }
        @AuraEnabled public String NumberOfBedrooms { get; set; }
        @AuraEnabled public Decimal NumberOfAllocatedParking { get; set; }
        @AuraEnabled public Decimal PlotArea { get; set; }
        @AuraEnabled public String PlotNo { get; set; }
        @AuraEnabled public Decimal FirstFloorArea { get; set; }
        @AuraEnabled public Decimal GroundFloorArea { get; set; }
        @AuraEnabled public Decimal GroundFloorParkingArea { get; set; }
        @AuraEnabled public Decimal TerraceArea { get; set; }
        @AuraEnabled public String BuildingNo { get; set; }
        @AuraEnabled public String FloorNumber { get; set; }
        @AuraEnabled public Decimal NumberOfBalcony { get; set; }
        @AuraEnabled public Decimal NumberOfBathroom { get; set; }
        @AuraEnabled public Decimal NumberOfMaidroom { get; set; }
        @AuraEnabled public Date EstimatedCompletionDate { get; set; }
        @AuraEnabled public String VisibletoMRESalesTeam { get; set; }
        @AuraEnabled public String ApprovalStatus { get; set; }
        @AuraEnabled public String SubStatus { get; set; }
        
        public UnitWrapper(Unit__c unit) {
            this.Id = unit.Id;
            this.Name = unit.Name;
            this.ProjectName = unit.Project_Name__c;
            this.ProjectId = unit.Phase__r != null ? unit.Phase__r.Project__r.Id : null;
            this.PhaseName = unit.Phase__r != null ? unit.Phase__r.Name : null;
            this.PhaseId = unit.Phase__r != null ? unit.Phase__r.Id : null;
            this.ZoneName = unit.Zone__c;
            this.InventoryStatus = unit.InventoryStatus__c;
            this.CurrencyIsoCode = unit.CurrencyIsoCode;
            this.Status = unit.Status__c;
            this.UnitClassification = unit.UnitClassification__c;
            this.UnitType = unit.Type__c;
            this.TotalPrice = (unit.TotalPrice__c != null) ? unit.TotalPrice__c : 0;
            this.PriceEGP = 0;
            this.PriceUSD = 0;
            this.PriceAED = 0;
            this.GrossFloorArea = (unit.GrossFloorAreaGFA__c != null) ? unit.GrossFloorAreaGFA__c : 0;
            this.InternalArea = (unit.Internal_Area__c != null) ? unit.Internal_Area__c : 0;
            this.BalconyArea = (unit.BalconyArea__c != null) ? unit.BalconyArea__c : 0;
            this.BasementArea = (unit.BasementArea__c != null) ? unit.BasementArea__c : 0;
            this.BasementParkingArea = (unit.BasementParkingArea__c != null) ? unit.BasementParkingArea__c : 0;
            this.DriversRoomArea = (unit.DriversRoomArea__c != null) ? unit.DriversRoomArea__c : 0;
            this.NumberOfBedrooms = unit.Number_of_Bedrooms__c;
            this.NumberOfAllocatedParking = (unit.NumberofAllocatedParking__c != null) ? unit.NumberofAllocatedParking__c : 0;
            this.PlotArea = (unit.PlotAreasqm__c != null) ? unit.PlotAreasqm__c : 0;
            this.PlotNo = unit.PlotNo__c;
            this.FirstFloorArea = (unit.FirstFloorArea__c != null) ? unit.FirstFloorArea__c : 0;
            this.GroundFloorArea = (unit.GroundFloorArea__c != null) ? unit.GroundFloorArea__c : 0;
            this.GroundFloorParkingArea = (unit.GroundFloorParkingArea__c != null) ? unit.GroundFloorParkingArea__c : 0;
            this.TerraceArea = (unit.TerraceArea__c != null) ? unit.TerraceArea__c : 0;
            this.BuildingNo = unit.BuildingNo__c;
            this.FloorNumber = unit.FloorNumber__c;
            this.NumberOfBalcony = (unit.Numberofbalcony__c != null) ? unit.Numberofbalcony__c : 0;
            this.NumberOfBathroom = (unit.Numberofbathroom__c != null) ? unit.Numberofbathroom__c : 0;
            this.NumberOfMaidroom = (unit.Numberofmaidroom__c != null) ? unit.Numberofmaidroom__c : 0;
            this.EstimatedCompletionDate = unit.Estimated_Completion_Date__c;
            this.VisibletoMRESalesTeam = unit.Visible_to_MRE_SalesTeam__c.toString();
            this.ApprovalStatus = unit.ApprovalStatus__c;
            this.SubStatus = unit.Sub_Status__c;
        }
    }
    
    // method to get the unit Phases
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getAllUnitPhases(String sourceEntity) {
        try {
            // Query all Unit Phase records with Id and Name
            List<Phase__c> phases = [
                SELECT Id, Name 
                FROM Phase__c  
                WHERE Source_Entity__c = :sourceEntity
                ORDER BY Name ASC 
            ];
            
            // Map the results to a List of key-value pairs
            List<Map<String, String>> phaseList = new List<Map<String, String>>();
            for (Phase__c phase : phases) {
                phaseList.add(new Map<String, String>{
                    'label' => phase.Name,
                    'value' => phase.Id
                });
            }
            System.debug(phaseList);
            return phaseList;
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching Unit Phases: ' + e.getMessage());
        }
    }
    
    // method to get the unit Projects
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getAllUnitProjects(String sourceEntity) {
        try {
            // Query all Unit Phase records with Id and Name
            List<Project__c> projects = [
                SELECT Id, Name 
                FROM Project__c  
                WHERE Source_Entity__c = :sourceEntity
                ORDER BY Name ASC 
            ];
            
            // Map the results to a List of key-value pairs
            List<Map<String, String>> projectList = new List<Map<String, String>>();
            for (Project__c project : projects) {
                projectList.add(new Map<String, String>{
                    'label' => project.Name,
                    'value' => project.Id
                });
            }
            System.debug(projectList);
            return projectList;
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching Unit Projects: ' + e.getMessage());
        }
    }
    
    // Method to get maximum values
    @AuraEnabled(cacheable=true)
    public static Map<String, Decimal> getMaximumUnitValues(String sourceEntity, String currencyCode) {
        Map<String, Decimal> maxValues = new Map<String, Decimal>();
        
        if (String.isBlank(currencyCode) && sourceEntity == 'Modon - Egypt') {
            currencyCode = 'EGP';
        } else if (String.isBlank(currencyCode) && sourceEntity == 'Modon - UAE') {
            currencyCode = 'AED';
        }
       
        // Get the maximum price for the specified currency
        AggregateResult maxPriceResult = [
            SELECT MAX(Base_Price__c) maxPrice 
            FROM UnitPaymentPlanMapping__c 
            WHERE Unit__r.Source_Entity__c = :sourceEntity
            AND CurrencyIsoCode = :currencyCode
        ];
        maxValues.put('MaxPrice', (Decimal)maxPriceResult.get('maxPrice'));
        
        // Get the maximum Area
        AggregateResult maxAreaResult = [
            SELECT MAX(GrossFloorAreaGFA__c) maxArea 
            FROM Unit__c 
            WHERE Source_Entity__c = :sourceEntity
        ];
        maxValues.put('MaxArea', (Decimal)maxAreaResult.get('maxArea'));
        
        return maxValues;
    }
    
    // Method to get user profile and role
    @AuraEnabled(cacheable=true)
    public static Map<String, String> getUserRoleAndProfile() {
        User u = [SELECT Id, UserRole.Name, Profile.Name FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        Map<String, String> result = new Map<String, String>();
        result.put('userRole', u.UserRole != null ? u.UserRole.Name : '');
        result.put('profileName', u.Profile.Name);
        return result;
    }
    
    // method to update the Preferred Units in the selected lead
    @AuraEnabled
    public static void updatePreferredUnits(Id leadId, String units) {
        try {
            Lead leadToUpdate = [SELECT Id, Preferred_Units__c FROM Lead WHERE Id = :leadId LIMIT 1];
            leadToUpdate.Preferred_Units__c = units;
            update leadToUpdate;
        } catch (Exception e) {
            throw new AuraHandledException('Error updating Lead: ' + e.getMessage());
        }
    }
}