/**********************************************************************************************************************
* Name               : ModonEgypt_UnitsAPI
* Description        : REST API to expose Modon Egypt unit data to Sakneen. Returns all units where Source_Entity__c = 'Modon - Egypt'.
* Usage              : Called as REST API endpoint (/units/*) via HTTP GET method
* Created By         : Narendra Agrawal/ Shahil Sinha (Horizontal)
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment
* 1.0           Narendra Agrawal/ Shahil Sinha (Horizontal)        11 Dec 2025     Initial Version
* 1.1           Gautam Mishra (Horizontal)                         29 Dec 2025     Added UnitInput wrapper and filtering capability - 
*                                                                                  API now accepts optional JSON body with unit IDs to 
*                                                                                  return specific units. Returns all units if no filter provided.
* 1.2           Shahil Sinha (Horizontal)                          16 Jan 2026     Updated the query to get the UnitPaymentPlanMapping record whose CurrencyISoCode
                                                                                   is "EGP" and Name includes "8 Years" 
* 1.3           Shahil Sinha (Horizontal)                          23 Jan 2026     Refactored to use dynamic SOQL query and set limit to return 50k records max.
* 2.0           Gautam Mishra (Horizontal)                         21 Apr 2026     Updated and added field Bucket__c and Bucket__r.Name
* 2.1           Jay Patel                                            21 Sep 2026     MCR-73 — USER_MODE SOQL, createApexLog
**********************************************************************************************************************/

@RestResource(urlMapping='/units/*')
global with sharing class ModonEgypt_UnitsAPI {

    // ----------- CONSTANTS -----------
    private static final String SOURCE_ENTITY_EGYPT = 'Modon - Egypt';
    private static final Integer QUERY_LIMIT = 50000;

    // ----------- INPUT WRAPPER -----------
    global class UnitInput {
        public String unitRecordId;
    }

    // ----------- OUTPUT WRAPPER ---------- 
    global class UnitResponse {
        public Id Id;
        public String Name;
        public Decimal TotalPrice;
        public String PhaseName;
        public String InventoryStatus;
        public String Status;
        public String UnitClassification;
        public String Type;
        public String Typology;
        public Decimal InternalArea;
        public Decimal GFA;
        public Decimal BalconyArea;
        public Decimal BasementArea;
        public Decimal BasementParkingArea;
        public Decimal DriversRoomArea;
        public String Bedrooms;
        public Decimal AllocatedParking;
        public Decimal PlotArea;
        public String PlotNo;
        public Decimal FirstFloorArea;
        public Decimal GroundFloorArea;
        public Decimal GroundFloorParkingArea;
        public Decimal TerraceArea;
        public String BuildingNo;
        public String FloorNumber;
        public Decimal BalconyCount;
        public Decimal BathroomCount;
        public Decimal MaidRoomCount;
        public Date EstimatedCompletionDate;
        public Id BucketId;
        public String BucketName;
    }

    @HttpGet
    global static List<UnitResponse> getUnits() {
        try {
        RestRequest req = RestContext.request;
        String body = req.requestBody?.toString();

        Set<String> unitIds = new Set<String>();
        
        if (String.isNotBlank(body)) {
            try { 
                List<UnitInput> inputList = (List<UnitInput>) JSON.deserialize(body, List<UnitInput>.class);
                for (UnitInput item : inputList) {
                    if (String.isNotBlank(item.unitRecordId)) {
                        unitIds.add(item.unitRecordId);
                    }
                }
            } catch (Exception ex) {
                // Do nothing - all units will be returned
            }
        }

        List<Unit__c> units;
        String unitQuery =
            'SELECT Id, Name, TotalPrice__c, Phase__c, Phase__r.Name, ' +
            'InventoryStatus__c, Status__c, UnitClassification__c, Type__c, ' +
            'Typology__c, Internal_Area__c, GrossFloorAreaGFA__c, BalconyArea__c, ' +
            'BasementArea__c, BasementParkingArea__c, DriversRoomArea__c, ' +
            'NumberofAllocatedParking__c, PlotAreasqm__c, PlotNo__c, ' +
            'FirstFloorArea__c, GroundFloorArea__c, GroundFloorParkingArea__c, ' +
            'TerraceArea__c, BuildingNo__c, FloorNumber__c, Numberofbalcony__c, ' +
            'Numberofbathroom__c, Numberofmaidroom__c, Estimated_Completion_Date__c, ' +
            'Number_of_Bedrooms__c, Bucket__c, Bucket__r.Name, ' +
            '(SELECT Id, Base_Price__c, CurrencyIsoCode ' +
            ' FROM UnitPaymentPlanMappings__r ' +
            ' WHERE CurrencyIsoCode = \'EGP\' ' +
            ' AND Name LIKE \'%8 Years%\') ' +
            'FROM Unit__c ' +
            'WHERE Source_Entity__c = :SOURCE_ENTITY_EGYPT ';

        if (unitIds != null && !unitIds.isEmpty()) {
            unitQuery += 'AND Id IN :unitIds ';
        }

        //2.1 MCR-73: Enforce CRUD/FLS via USER_MODE on dynamic Unit__c query
        unitQuery += 'WITH USER_MODE ORDER BY Id ASC LIMIT :QUERY_LIMIT';

        units = Database.query(unitQuery);

        // Build response
        List<UnitResponse> responseList = new List<UnitResponse>();

        for (Unit__c u : units) {
            UnitResponse res = new UnitResponse();

            res.Id = u.Id;
            res.Name = u.Name;
            res.TotalPrice = (u.UnitPaymentPlanMappings__r != null && !u.UnitPaymentPlanMappings__r.isEmpty())
                             ? u.UnitPaymentPlanMappings__r[0].Base_Price__c : u.TotalPrice__c;
            res.PhaseName = u.Phase__r != null ? u.Phase__r.Name : null;
            res.InventoryStatus = u.InventoryStatus__c;
            res.Status = u.Status__c;
            res.UnitClassification = u.UnitClassification__c;
            res.Type = u.Type__c;
            res.Typology = u.Typology__c;
            res.InternalArea = u.Internal_Area__c;
            res.GFA = u.GrossFloorAreaGFA__c;
            res.BalconyArea = u.BalconyArea__c;
            res.BasementArea = u.BasementArea__c;
            res.BasementParkingArea = u.BasementParkingArea__c;
            res.DriversRoomArea = u.DriversRoomArea__c;
            res.Bedrooms = u.Number_of_Bedrooms__c;
            res.AllocatedParking = u.NumberofAllocatedParking__c;
            res.PlotArea = u.PlotAreasqm__c;
            res.PlotNo = u.PlotNo__c;
            res.FirstFloorArea = u.FirstFloorArea__c;
            res.GroundFloorArea = u.GroundFloorArea__c;
            res.GroundFloorParkingArea = u.GroundFloorParkingArea__c;
            res.TerraceArea = u.TerraceArea__c;
            res.BuildingNo = u.BuildingNo__c;
            res.FloorNumber = u.FloorNumber__c;
            res.BalconyCount = u.Numberofbalcony__c;
            res.BathroomCount = u.Numberofbathroom__c;
            res.MaidRoomCount = u.Numberofmaidroom__c;
            res.EstimatedCompletionDate = u.Estimated_Completion_Date__c;
            res.BucketId = u.Bucket__c;
            res.BucketName = u.Bucket__c != null ? u.Bucket__r.Name : null;

            responseList.add(res);
        }

        return responseList;
        } catch (Exception ex) {
            //2.1 MCR-73: Log unexpected failures via LoggerService.createApexLog
            LoggerService.save(LoggerService.createApexLog(
                ex,
                'Modon Egypt Units API',
                'ModonEgypt_UnitsAPI',
                'getUnits'
            ));
            throw ex;
        }
    }
}