/**********************************************************************************************************************
* Name               : EgyptArabicTranslationBatch                                                        
* Description        : Batch apex - this class is used to translate area values to Arabic words
* Usage              : UnitTriggerHelper
* Created By         : Milin Kapatel (Horizontal)                                                  
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                         
* 1.0           Milin Kapatel (Horizontal)          09 Mar 2026     Initial version
* 2.0           Milin Kapatel (Horizontal)          22 Apr 2026     Refactored to use ModonEgyptUtilities for area in words arabic conversion + updated methods to use convertAreaInWordsSqMtrSqCmtrTextArabic instead of Area_in_ArabicWordsSqMeterSqCentimeter
* 2.1           Milin Kapatel (Horizontal)          05 May 2026     Updated methods to pass Decimal values instead of String values
******************************************************************************************************************/
public without sharing class EgyptArabicTranslationBatch implements Database.Batchable<sObject>, Database.AllowsCallouts, Database.stateful{

    Set<Id> unitIds;
    public EgyptArabicTranslationBatch(Set<Id> unitIds) {
        this.unitIds = unitIds;
    }

    public Database.QueryLocator start(Database.BatchableContext bc){
        return Database.getQueryLocator([SELECT Id, GrossFloorAreaGFA__c, PlotAreasqm__c, TerraceArea__c FROM Unit__c WHERE Id IN :unitIds]);
    }

    public void execute(Database.BatchableContext bc, List<Unit__c> units){
        List<Unit__c> unitsToUpdate = new List<Unit__c>();
        for(Unit__c unit : units){
            //v2.0  
            unit.GFA_in_Words_Arabic__c = (unit.GrossFloorAreaGFA__c == null || unit.GrossFloorAreaGFA__c == 0) ? ModonEgyptConstants.AREA_AR_ZERO_SQ_MTR : ModonEgyptUtilities.convertAreaInWordsSqMtrSqCmtrTextArabic(unit.GrossFloorAreaGFA__c);
            //v2.0
            unit.Plot_Area_in_Words_Arabic__c = (unit.PlotAreasqm__c == null || unit.PlotAreasqm__c == 0) ? ModonEgyptConstants.AREA_AR_ZERO_SQ_MTR : ModonEgyptUtilities.convertAreaInWordsSqMtrSqCmtrTextArabic(unit.PlotAreasqm__c);
            //v2.0
            unit.Terrace_Area_in_Words_Arabic__c = (unit.TerraceArea__c == null || unit.TerraceArea__c == 0) ? ModonEgyptConstants.AREA_AR_ZERO_SQ_MTR : ModonEgyptUtilities.convertAreaInWordsSqMtrSqCmtrTextArabic(unit.TerraceArea__c);
            unitsToUpdate.add(unit);
        }
        update unitsToUpdate;
    }

   public void finish(Database.BatchableContext bc){
   }
}