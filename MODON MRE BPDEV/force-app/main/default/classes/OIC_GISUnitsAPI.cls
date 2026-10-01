/**********************************************************************************************************************
* Name               : OIC_GISUnitsAPI                                                        
* Description        : This class is used to fetch unit details based on project id.
* Usage              : 
* Created By         : Activemindsit                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh   	                08 04 2025      Initial Draft       
* 2.0           Suresh   	                19 01 2026      Building_No, UnitClassification and Type fields are added
* 2.1           Jay Patel                   21 Sep 2026     MCR-73 — with sharing, createApexLog
***********************************************************************************************************************/
@RestResource(urlMapping='/gis/getunits/*')
global with sharing class OIC_GISUnitsAPI {

    @HttpGet
    global static void getUnitsDPG() {
        RestRequest restRequest = RestContext.request;
        RestResponse restResponse = RestContext.response;
        GetUnitsResponse obj_GetUnitsResponse = new GetUnitsResponse();
        obj_GetUnitsResponse.UnitDetails = new List<Unit>();
        restRequest.addHeader('Content-Type', 'application/json');

        try {
            String projectId = restRequest.params.get('projectId');
            List<Unit__c> lst_Unit = OIC_GISUnitsAPIHelper.getUnits(projectId);
            for(Unit__c obj_Unit : lst_Unit){
                Unit unit = new Unit();
                unit.Id = obj_Unit.Id;
                unit.Name = obj_Unit.Name;
                unit.ProjectName = obj_Unit.Phase__r.Project__r.Name;
                unit.ProjectId = obj_Unit.Phase__r.Project__r.Id;
                unit.Status = obj_Unit.Status__c;
                unit.BlockedBy = obj_Unit.BlockedBy__r.Name;
                
                unit.BlockedFor = obj_Unit.BlockedFor__r.Name;
                unit.BlockReason = obj_Unit.BlockReason__c;
                unit.BlockUntil = obj_Unit.BlockUntil__c;
                unit.Phase = obj_Unit.Phase__r.Name;
                unit.InventoryStatus = obj_Unit.InventoryStatus__c;
                unit.Number_of_Bedrooms = obj_Unit.Number_of_Bedrooms__c;
                unit.FloorNumber = obj_Unit.FloorNumber__c;
                unit.TotalArea = obj_Unit.TotalArea__c;
                unit.TotalGFAsqm = obj_Unit.TotalGFAsqm__c;
                unit.TotalGrossSellableAreaGSA = obj_Unit.TotalGrossSellableAreaGSA__c;
                unit.TotalPrice = obj_Unit.TotalPrice__c;
                unit.PlotAreasqm = obj_Unit.PlotAreasqm__c;
                unit.PlotNo = obj_Unit.PlotNo__c;
                unit.MDPlotId = obj_Unit.MDPlotId__c;
                unit.ApprovalStatus = obj_Unit.ApprovalStatus__c;
                //2.0 - New fields are added
                unit.Building_No = obj_Unit.Building_No__c;
                unit.UnitClassification = obj_Unit.UnitClassification__c;
                unit.Type = obj_Unit.Type__c;
                obj_GetUnitsResponse.UnitDetails.add(unit);
            }    
            obj_GetUnitsResponse.Status = 'Success';
            obj_GetUnitsResponse.ErrorCode = '';
            obj_GetUnitsResponse.ErrorMessage = '';
            restResponse.statusCode = 200;
        } catch (Exception ex) {
            //2.1 MCR-73: Log unexpected failures via LoggerService.createApexLog
            LoggerService.save(LoggerService.createApexLog(
                ex,
                'GIS Units API',
                'OIC_GISUnitsAPI',
                'getUnitsDPG'
            ));
            obj_GetUnitsResponse.Status = 'Failure';
            obj_GetUnitsResponse.ErrorCode = 'GIS-999';
            obj_GetUnitsResponse.ErrorMessage = ex.getMessage();
            restResponse.statusCode = 200;
        }

        restResponse.addHeader('Content-Type', 'application/json');
        restResponse.responseBody = Blob.valueOf(JSON.serialize(obj_GetUnitsResponse));
    } 
    
    global class GetUnitsResponse{
        List<Unit> UnitDetails;  
        public String Status;	
        public String ErrorCode;	
        public String ErrorMessage;
    }
    global class Unit{
        public String Id;	
        public String Name;
        public String ProjectName;
        public String ProjectId;
        public String Status;	
        public String BlockedBy;
        public String BlockedFor;
        public String BlockReason;
        public DateTime BlockUntil;
        public String Phase;
        public String InventoryStatus;
        public String Number_of_Bedrooms;
        public String FloorNumber;
        public Decimal TotalArea;
        public Decimal TotalGFAsqm;
        public Decimal TotalGrossSellableAreaGSA;
        public Decimal TotalPrice;
        public Decimal PlotAreasqm;
        public String PlotNo;
        public String MDPlotId;
        public String ApprovalStatus;
        public String UnitClassification;
        public String Building_No;
        public String Type;
    } 
}