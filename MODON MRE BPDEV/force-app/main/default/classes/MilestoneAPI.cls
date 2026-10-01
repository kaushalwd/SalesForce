/**********************************************************************************************************************
* Name               : MilestoneAPI                                                        
* Description        : This class is used to get the project milestones.
* Usage              : 
* Created By         : Activemindsit                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Suresh   	                02 02 2026      Initial Draft       
* 1.1           Jay Patel                   23 Sep 2026     MCR-73 — with sharing, USER_MODE SOQL
***********************************************************************************************************************/
@RestResource(urlMapping='/Milestone/*')
global with sharing class MilestoneAPI {

    @HttpGet
    global static void findMilestoneDetails() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        String requestId = String.valueOf(UUID.randomUUID());
        try {
            String projectId = req.params.get('ProjectId');
            String phaseId = req.params.get('PhaseId');
           
            if (String.isBlank(phaseId)) {
                returnErrorAPI.returnError(res, requestId, 'Missing PhaseId parameter', 200);
                return;
            } 
            //System.debug('>>>>>>>>>>>>>>>>>>>>> projectId >>>> '+projectId);
            System.debug('>>>>>>>>>>>>>>>>>>>>> phaseId >>>> '+phaseId);
            List<Milestone> lst_MilestoneAPI = new List<Milestone>();
            
            //1.1 MCR-73: Enforce CRUD/FLS via USER_MODE on Milestone__c query
            List<Milestone__c> lst_Milestone = [
                SELECT Id, ConfirmedMilestoneDate__c, Construction_Progress__c,
                    Description__c, Milestones__c, Milestone_Due_Date__c, Name,
                    Milestone_Order__c, Phase__c, Progress_Percentage__c,
                    Project__c, Sub_Milestone__c, Type__c
                FROM Milestone__c
                WHERE Phase__c = :phaseId
                WITH USER_MODE
            ];
            
            if(lst_Milestone.size() > 0){
                for(Milestone__c obj_Milestone : lst_Milestone){
                    Milestone obj_MilestoneAPI = new Milestone();
                    obj_MilestoneAPI.ConfirmedMilestoneDate = obj_Milestone.ConfirmedMilestoneDate__c;
                    obj_MilestoneAPI.Construction_Progress = obj_Milestone.Construction_Progress__c;
                    obj_MilestoneAPI.Description = obj_Milestone.Description__c;
                    obj_MilestoneAPI.Milestones = obj_Milestone.Milestones__c;
                    obj_MilestoneAPI.MilestoneDate = obj_Milestone.Milestone_Due_Date__c;
                    obj_MilestoneAPI.MilestoneName = obj_Milestone.Name;
                    obj_MilestoneAPI.MilestoneOrder = obj_Milestone.Milestone_Order__c;
                    obj_MilestoneAPI.Phase = obj_Milestone.Phase__c;
                    //obj_MilestoneAPI.PhaseKey = obj_Milestone.Phase_Key__c;
                    obj_MilestoneAPI.Project = obj_Milestone.Project__c;
                    obj_MilestoneAPI.SubMilestone = obj_Milestone.Sub_Milestone__c;
                    obj_MilestoneAPI.Type = obj_Milestone.Type__c;
                    lst_MilestoneAPI.add(obj_MilestoneAPI); 
                }
                
            } else {
                returnErrorAPI.returnError(res, requestId, 'No data found', 200);
                return;
            }
            APIResponse response = new APIResponse('success', requestId, lst_MilestoneAPI, null);
            res.responseBody = Blob.valueOf(JSON.serialize(response));
            res.addHeader('Content-Type', 'application/json');
            res.statusCode = 200;
            
        } catch (Exception ex) { // Return generic server error response
            LoggerService.save(LoggerService.createApexLog(ex, 'MilestoneAPI', 'MilestoneAPI', 'findMilestoneDetails'));
            returnErrorAPI.returnError(res, requestId, 'Server Error: ' + ex.getMessage(), 200);
        }
    }
    
    public class Milestone{
        public Date ConfirmedMilestoneDate;
        public Decimal Construction_Progress;
        public String Description;
        public String Milestones;
        public Date MilestoneDate;
        public String MilestoneName;
        public String MilestoneOrder;
        public String Phase;
        public String PhaseKey;
        public String ProgressPercentage;
        public String Project;
        public String SubMilestone;  
        public String Type;
    }    
}