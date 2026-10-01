/**********************************************************************************************************************
* Name               : OIC_GISUnitsAPIHelper                                                        
* Description        : Helper class used from OIC_GISUnitsAPI.
* Usage              : 
* Created By         : Activemindsit                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh   	                08 04 2025      Initial Draft       
* 2.0           Suresh   	                19 01 2026      Building_No, UnitClassification and Type fields are added
***********************************************************************************************************************/
global class OIC_GISUnitsAPIHelper {

    public static List<Unit__c> getUnits(String projectId){
        List<Unit__c> lst_Unit = new List<Unit__c>();
        try{
              //2.0 - New fields are added
              lst_Unit = [select Id, Name, Status__c, BlockedBy__r.Name, BlockedFor__r.Name, BlockReason__c, BlockUntil__c, 
                           Phase__r.Name, InventoryStatus__c, Number_of_Bedrooms__c, FloorNumber__c, TotalArea__c, 
                           TotalGFAsqm__c, TotalGrossSellableAreaGSA__c, TotalPrice__c, PlotAreasqm__c, PlotNo__c, MDPlotId__c,
                           Phase__r.Project__r.Id, Phase__r.Project__r.Name, ApprovalStatus__c, UnitClassification__c, Building_No__c, Type__c
                           from Unit__c where Phase__r.Project__r.Id = :projectId];
           }catch(Exception exe){}
           return lst_Unit;
    }   
   
}