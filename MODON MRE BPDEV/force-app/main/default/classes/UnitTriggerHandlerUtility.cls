/**********************************************************************************************************************
* Name               : UnitTriggerHandlerUtility
* Description        : This utility class publishes Platform Events (UnitEvent__e) to sync unit data from Salesforce 
*                      to external systems (Nawy and Sakneen) for Egypt sales process. Handles event publishing, 
*                      status updates, and integration logging.
* Usage              : Called from UnitTriggerHandler
* Created By         : Harshit
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment
* 1.0           Harshit                          20 Aug 2025     
* 2.0           Shahil Sinha (Horizontal)        11 Dec 2025     Added publishUnitsToSakneen method for Sakneen integration
* 3.0           Narendra Agrawal (Horizontal)    26 Dec 2025     Removed Nawy integration methods, enhanced publishUnitsToSakneen 
*                                                                with Delete handling and status tracking (Success/Failure), 
*                                                                added publishSalesOrdersToSakneen method.
* 4.0           Shahil Sinha (Horizontal)        15 Jan 2026     Changed Total Price to use Base Price from 8 Years Payment Plan(EGP) mapping
* 4.1           Shahil Sinha (Horizontal)        29 Jan 2026     Added Type__c field in the payload for Sakneen integration
* 4.2           Shahil Sinha (Horizontal)        29 Jan 2026     Fixed Phase__c null issue by querying Phase__r.Name and mapping by Unit Id
**********************************************************************************************************************/
public with sharing class UnitTriggerHandlerUtility {

    //V2.0 (line 21 - 166) This method sync unit data into Sakneen
    public static void publishUnitsToSakneen(List<Unit__c> units, String OperationType) {
        List<UnitEvent__e> events = new List<UnitEvent__e>();
        List<Logger__c> logsToInsert = new List<Logger__c>();
        
        //v3.0 (line 113 - 119) Handled delete event
        if(OperationType != 'DELETE') {
            List<Unit__c> unitsToUpdate = new List<Unit__c>();
            
            //v4.2 (line 30 - 34) Query Phase__r.Name and build map by Unit Id
            Map<Id, String> unitIdToPhaseNameMap = new Map<Id, String>();
            for (Unit__c u : [SELECT Id, Phase__r.Name FROM Unit__c WHERE Id IN :units]) {
                unitIdToPhaseNameMap.put(u.Id, u.Phase__r != null ? u.Phase__r.Name : null);
            }
            
            //v4.0 (line 36 - 52) Query UnitPaymentPlanMapping and build map by Name
            Map<String, Decimal> unitToPaymentPlanBasePrice = new Map<String, Decimal>();
            List<UnitPaymentPlanMapping__c> unitPaymentPlanMappingList = [
                SELECT Name, Base_Price__c, Unit__c
                FROM UnitPaymentPlanMapping__c WHERE Unit__c IN :units AND CurrencyISoCode = 'EGP' AND Name LIKE '%8 Years%'
            ];
            
            if (!unitPaymentPlanMappingList.isEmpty()) {
                for (UnitPaymentPlanMapping__c item : unitPaymentPlanMappingList) {
                    unitToPaymentPlanBasePrice.put(item.Unit__c, item.Base_Price__c);
                }
            }

            //v4.2 (line 49 - 52) Pass unitIdToPhaseNameMap to mapping method
            for (Unit__c unit : units) {
                events.add(mapUnitsToSakneenPayload(unit, OperationType, unitToPaymentPlanBasePrice, unitIdToPhaseNameMap));
            }

            //v3.0 (line 54 - 111) status tracking (Success/Failure)
            if (!events.isEmpty()) {
                List<Database.SaveResult> results = EventBus.publish(events);

                for (Integer i = 0; i < results.size(); i++) {
                    if (results[i].isSuccess()) {
                        // Mark the Sakneen_Status__c Success if the event was published successfully
                        Unit__c updatedUnit = new Unit__c(
                            Id = units[i].Id,
                            Sakneen_Status__c = 'Success'
                        );
                        unitsToUpdate.add(updatedUnit);
                    } else {
                        // Mark the Sakneen_Status__c Failure if the event was published failed
                        Unit__c updatedUnit = new Unit__c(
                            Id = units[i].Id,
                            Sakneen_Status__c = 'Failure'
                        );
                        unitsToUpdate.add(updatedUnit);

                        //Capture logs when failure
                        String processName = 'Sakneen - UnitSync';
                        String className   = 'UnitTriggerHandlerUtility';
                        String methodName  = 'publishUnitsToSakneen';
                        String requestBody = JSON.serialize(events);
                        String responseBody= JSON.serialize(results);
                        String statusCode  = getStatusCode(results);
                        String logType     = 'Integration';
                        
                        Logger__c logEntry = LoggerService.createAPILog(
                            processName,
                            className,
                            methodName,
                            requestBody,
                            responseBody,
                            statusCode,
                            logType
                        );
                        
                        logsToInsert.add(logEntry);
                    }
                }

                if (!unitsToUpdate.isEmpty()) {
                    try {
                        update unitsToUpdate;
                    } catch (DmlException ex) {
                        System.debug('Error updating Sakneen_Status__c: ' + ex.getMessage());
                    }
                }

                 if (!logsToInsert.isEmpty()) {
                    try {
                        insert logsToInsert;
                    } catch (DmlException ex) {
                        System.debug('Error inserting failure logs: ' + ex.getMessage());
                    }
                }
            }
        } else {
            for (Unit__c unit : units) {
                events.add(new UnitEvent__e(RecordId__c = unit.Id, Operation_Type__c = OperationType));
            }

            List<Database.SaveResult> results = EventBus.publish(events);
        }
    }

    //v4.2 (line 124) Added unitIdToPhaseNameMap parameter to get Phase Name
    // Same logic as ModonEgypt_UnitsAPI - get base price from 8 Years Payment Plan mapping
    private static UnitEvent__e mapUnitsToSakneenPayload(Unit__c unit, String OperationType, Map<String, Decimal> unitToPaymentPlanBasePrice, Map<Id, String> unitIdToPhaseNameMap) {
        //v4.0 (line 125 - 130)
        Decimal totalPrice = unitToPaymentPlanBasePrice.isEmpty() 
            ? unit.TotalPrice__c 
            : unitToPaymentPlanBasePrice.get(unit.Id) != null
                ? unitToPaymentPlanBasePrice.get(unit.Id) 
                : unit.TotalPrice__c;
        
        return new UnitEvent__e(
            RecordId__c = unit.Id,
            Name__c = unit.Name,
            Total_Price__c = totalPrice,
            //v4.2 (line 137) Get Phase Name from map using Unit Id
            Phase__c = unitIdToPhaseNameMap.get(unit.Id),
            //v4.1 (line 139)
            Type__c = unit.Type__c,
            Inventory_Status__c = unit.InventoryStatus__c,
            Status__c = unit.Status__c,
            Unit_Classification__c = unit.UnitClassification__c,
            Operation_Type__c = OperationType,
            Typology__c = unit.Typology__c,
            Internal_Area__c = unit.Internal_Area__c,
            Gross_Floor_Area_GFA__c = unit.GrossFloorAreaGFA__c,
            Balcony_Area__c = unit.BalconyArea__c,
            Basement_Area__c = unit.BasementArea__c,
            Basement_Parking_Area__c = unit.BasementParkingArea__c,
            Drivers_Room_Area__c = unit.DriversRoomArea__c,
            Number_of_Bedrooms__c = unit.Number_of_Bedrooms__c,
            Number_of_Allocated_Parking__c = unit.NumberofAllocatedParking__c,
            Plot_Area_sqm__c = unit.PlotAreasqm__c,
            Plot_No__c = unit.PlotNo__c,
            First_Floor_Area__c = unit.FirstFloorArea__c,
            Ground_Floor_Area__c = unit.GroundFloorArea__c,
            Ground_Floor_Parking_Area__c = unit.GroundFloorParkingArea__c,
            Terrace_Area__c = unit.TerraceArea__c,
            Building_No__c = unit.BuildingNo__c,
            Floor_Number__c = unit.FloorNumber__c,
            Number_of_Balcony__c = unit.Numberofbalcony__c,
            Number_of_bathroom__c = unit.Numberofbathroom__c,
            Maid_Room_Count__c = unit.Numberofmaidroom__c,
            Estimated_Completion_Date__c = unit.Estimated_Completion_Date__c
        );
    }

    private static String getStatusCode(List<Database.SaveResult> results) {
        for (Database.SaveResult r : results) {
            if (!r.isSuccess()) {
                return 'ERROR';
            }
        }
        return 'SUCCESS';
    }
    
    //V2.0 (line 177 - 222) Filter units applicable for Sakneen sync
    public static List<Unit__c> filterUnitsForSakneenSync(List<Unit__c> modonEgyptUnits, Map<ID, SObject> newMap, Map<ID, SObject> oldMap) {
        List<Unit__c> modonEgyptUnitsForSakneen = new List<Unit__c>();
        for (Unit__c record : modonEgyptUnits) {
            Unit__c newUnit = (Unit__c) newMap.get(record.Id);
            Unit__c oldUnit = (Unit__c) oldMap.get(record.Id);

            if (hasTrackedFieldChanged(newUnit, oldUnit)) {
                modonEgyptUnitsForSakneen.add(newUnit);
            } 
        }
        return modonEgyptUnitsForSakneen;
    }

    // Helper to check tracked field changes (aligned with Sakneen payload fields)    
    private static Boolean hasTrackedFieldChanged(Unit__c newUnit, Unit__c oldUnit) {
        return newUnit.Name != oldUnit.Name ||
            newUnit.TotalPrice__c != oldUnit.TotalPrice__c ||
            newUnit.Phase__c != oldUnit.Phase__c ||
            //v4.1 (line 197)
            newUnit.Type__c != oldUnit.Type__c ||
            newUnit.InventoryStatus__c != oldUnit.InventoryStatus__c ||
            newUnit.Status__c != oldUnit.Status__c ||
            newUnit.UnitClassification__c != oldUnit.UnitClassification__c ||
            newUnit.Typology__c != oldUnit.Typology__c ||
            newUnit.Internal_Area__c != oldUnit.Internal_Area__c ||
            newUnit.GrossFloorAreaGFA__c != oldUnit.GrossFloorAreaGFA__c ||
            newUnit.BalconyArea__c != oldUnit.BalconyArea__c ||
            newUnit.BasementArea__c != oldUnit.BasementArea__c ||
            newUnit.BasementParkingArea__c != oldUnit.BasementParkingArea__c ||
            newUnit.DriversRoomArea__c != oldUnit.DriversRoomArea__c ||
            newUnit.Number_of_Bedrooms__c != oldUnit.Number_of_Bedrooms__c ||
            newUnit.NumberofAllocatedParking__c != oldUnit.NumberofAllocatedParking__c ||
            newUnit.PlotAreasqm__c != oldUnit.PlotAreasqm__c ||
            newUnit.PlotNo__c != oldUnit.PlotNo__c ||
            newUnit.FirstFloorArea__c != oldUnit.FirstFloorArea__c ||
            newUnit.GroundFloorArea__c != oldUnit.GroundFloorArea__c ||
            newUnit.GroundFloorParkingArea__c != oldUnit.GroundFloorParkingArea__c ||
            newUnit.TerraceArea__c != oldUnit.TerraceArea__c ||
            newUnit.BuildingNo__c != oldUnit.BuildingNo__c ||
            newUnit.FloorNumber__c != oldUnit.FloorNumber__c ||
            newUnit.Numberofbalcony__c != oldUnit.Numberofbalcony__c ||
            newUnit.Numberofbathroom__c != oldUnit.Numberofbathroom__c ||
            newUnit.Numberofmaidroom__c != oldUnit.Numberofmaidroom__c ||
            newUnit.Estimated_Completion_Date__c != oldUnit.Estimated_Completion_Date__c;
    }

    //v3.0 (line 223 - 317) Removed Nawy Integration
    //     public static void publishEvents(List<Unit__c> units , String OperationType) {
    //     List<UnitEvent__e> events = new List<UnitEvent__e>();
    //     List<Unit__c> unitsToUpdate = new List<Unit__c>();

    //     for (Unit__c unit : units) {
    //         events.add(mapToEvent(unit, OperationType));
    //     }

    //     if (!events.isEmpty()) {
    //         List<Database.SaveResult> results = EventBus.publish(events);
    //         System.debug('Published Unit Events → ' + results);
    //         System.debug('Published Events → ' + events);

    //         for (Integer i = 0; i < results.size(); i++) {
    //             if (results[i].isSuccess()) {
    //                 // Mark the unit as "Pending Sync" only if the event was published successfully
    //                 Unit__c updatedUnit = new Unit__c(
    //                     Id = units[i].Id,
    //                     Nawy_Status__c = 'Pending Sync'
    //                 );
    //                 unitsToUpdate.add(updatedUnit);
    //             } else {
    //                 for (Database.Error err : results[i].getErrors()) {
    //                     System.debug('Failed to publish event for Unit: ' + units[i].Id + ' → ' + err.getMessage());
    //                 }
    //             }
    //         }

    //         if (!unitsToUpdate.isEmpty()) {
    //             try {
    //                 update unitsToUpdate;
    //             } catch (DmlException ex) {
    //                 System.debug('Error updating Nawy_Status__c: ' + ex.getMessage());
    //             }
    //         }

    //         try {
    //             String processName = 'Nawy - UnitSync';
    //             String className   = 'UnitTriggerHandlerUtility';
    //             String methodName  = 'publishEvents';
    //             String requestBody = JSON.serialize(events);
    //             String responseBody= JSON.serialize(results);
    //             String statusCode  = getStatusCode(results);
    //             String logType     = 'Integration';
                
    //             Logger__c logEntry = LoggerService.createAPILog(
    //                 processName,
    //                 className,
    //                 methodName,
    //                 requestBody,
    //                 responseBody,
    //                 statusCode,
    //                 logType
    //             );
                
    //             insert logEntry;
    //         } catch (Exception logEx) {
    //             System.debug('Failed to insert log entry: ' + logEx.getMessage());
    //         }
    //     }
    // }

    // private static UnitEvent__e mapToEvent(Unit__c unit , String OperationType) {
    //     return new UnitEvent__e(
    //         Approval_Status__c              = unit.ApprovalStatus__c,
    //         Area__c                         = unit.TotalArea__c,
    //         Balcony_Area__c                 = unit.BalconyArea__c,
    //         Base_Price__c                   = unit.BasePrice__c,
    //         Building_No__c                  = unit.BuildingNo__c,
    //         Currency_ISO_Code__c            = unit.CurrencyIsoCode,
    //         Floor_Number__c                 = unit.FloorNumber__c,
    //         Gross_Floor_Area_GFA__c         = unit.GrossFloorAreaGFA__c	,
    //         Internal_Area__c                = unit.Internal_Area__c,
    //         LastModifiedDate__c             = unit.LastModifiedDate,
    //         Name__c                         = unit.Name,
    //         Number_of_Allocated_Parking__c  = unit.NumberofAllocatedParking__c,
    //         Number_of_Balcony__c            = unit.Numberofbalcony__c,
    //         Number_of_bathroom__c           = unit.Numberofbathroom__c,
    //         Number_of_Bedrooms__c           = unit.Number_of_Bedrooms__c,
    //         Operation_Type__c               = OperationType,
    //         Phase__c                        = unit.Phase__c,
    //         Plot_Area_sqm__c                = unit.PlotAreasqm__c,
    //         Plot_No__c                      = unit.PlotNo__c,
    //         RecordId__c                     = unit.Id,
    //         Source_Entity__c                = unit.Source_Entity__c,
    //         Status__c                       = unit.Status__c,
    //         Sub_Status__c                   = unit.Sub_Status__c,
    //         Typology__c                     = unit.Typology__c,
    //         Unit_Classification__c          = unit.UnitClassification__c,
    //         Unit_Quality__c                 = unit.Unit_Quality__c,
    //         Zone__c                         = unit.Zone__c
    //     );
    // } 
}