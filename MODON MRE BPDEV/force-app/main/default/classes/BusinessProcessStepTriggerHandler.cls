/**********************************************************************************************************************
* Name               :                                                         
* Description        : Class for BP framework
* Usage              : BP Framework                                                        
* Created By         : Sivannarayana Peddireddi                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                          Date            Comment                                                                       
* 1.0           sivannaryana.p@modon.com     10-05-2026      Initial Draft     
**********************************************************************************************************************/
public without sharing class BusinessProcessStepTriggerHandler extends TriggerHandler {
    
    public static final String IN_PROGRESS = 'In Progress';
    public static final String COMPLETED = 'Completed';
    public static final String ON_HOLD = 'On Hold';
    public static final String REJECTED = 'Rejected';
     public static final String CANCELLED = 'Cancelled';
    
    
    public static final String OPEN            = 'Open';
    public static final String NOT_ACTIONED    = 'Not Actioned';
    public static final String ACCEPTED        = 'Accepted';
    public static final String REQUIRED_INFO   = 'Required Info';
    public static final String PROVIDED_INFO   = 'Provided Info';
    public static final String RE_OPEN         = 'Re Open';
    public static final String ASSIGNED         = 'Assigned';
    public static final String RE_ASSIGNED         = 'Re Assigned';
    
     public class BusinessProcessTimeCalculation {
        public Integer TotalCompletionTime;
        Public Integer CompletedInHours;
        Public Integer completedInDays;
    }
    
    //*** Before Insert Action***//
    public override void beforeInsertMethod(List<SObject> newList, Map<Id, SObject> newMap){
        Set<ID> processFlowIds=new Set<ID>();
        for(Business_Process_Step__c newStep : (List<Business_Process_Step__c>) newList) {
            processFlowIds.add(newStep.Process_Flow_Step__c);
        }
        
        Map<ID,Process_Flow_Step__c> processFlowMap=new Map<ID,Process_Flow_Step__c>
            ([select ID,Process_Flow__r.Business_Hours_ID__c,Duration_To_Complete_In_Hourss__c from Process_Flow_Step__c where ID IN :processFlowIds]);
        
          for(Business_Process_Step__c newStep : (List<Business_Process_Step__c>) newList) {
              Process_Flow_Step__c processFlowStep = processFlowMap.get(newStep.Process_Flow_Step__c);
              Id bhId = processFlowMap.get(newStep.Process_Flow_Step__c).Process_Flow__r.Business_Hours_ID__c;
              if (newStep.Status__c!=null && newStep.Status__c==OPEN) {
                     newStep.Step_Open_Time__c = Datetime.now();
                     if(bhId!=null){
                      Decimal hrs = 0;
                      if(processFlowStep.Duration_To_Complete_In_Hourss__c != null){
                            hrs = Decimal.valueOf(processFlowStep.Duration_To_Complete_In_Hourss__c);
                            Long durationMs = (Long)(hrs * 60 * 60 * 1000);
                           newStep.Expected_Completion_Time__c = BusinessHours.add(bhId, newStep.Step_Open_Time__c, durationMs);
                      }
                    }
                }
              /*
               if (newStep.Assigned_To__c!=null) {
                   newStep.Status__c =ASSIGNED;
                   newStep.Assigned_Time__c=Datetime.now();
                   newstep.Assigned_by__c= UserInfo.getName();
               }
            */
              
          }
    }
    
    //*** Before Update Action***//
    public override void beforeUpdateMethod(list<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap){
        
        Set<ID> processFlowIds=new Set<ID>();
        for(Business_Process_Step__c newStep : (List<Business_Process_Step__c>) newList) {
            processFlowIds.add(newStep.Process_Flow_Step__c);
        }
        
        Map<ID,Process_Flow_Step__c> processFlowMap=new Map<ID,Process_Flow_Step__c>
            ([select ID,Process_Flow__r.Business_Hours_ID__c,Duration_To_Complete_In_Hourss__c from Process_Flow_Step__c where ID IN :processFlowIds]);
        
        for(Business_Process_Step__c newStep : (List<Business_Process_Step__c>) newList) {
             Business_Process_Step__c oldStep = (Business_Process_Step__c) oldMap.get(newStep.ID);
             Process_Flow_Step__c processFlowStep = processFlowMap.get(newStep.Process_Flow_Step__c);
             Id bhId = processFlowMap.get(newStep.Process_Flow_Step__c).Process_Flow__r.Business_Hours_ID__c;
            
            if (newStep.Assigned_To__c!=null && oldStep.Assigned_To__c != newStep.Assigned_To__c) {
                if(oldStep.Assigned_To__c==null) {
                   newStep.Status__c =ASSIGNED;
                   newStep.Assigned_Time__c=Datetime.now();
                   newstep.Assigned_by__c= UserInfo.getName();
                } else {
                   newStep.Status__c =RE_ASSIGNED;
                   newStep.Re_Assign_Time__c=Datetime.now();
                   newstep.Re_Assigned_by__c= UserInfo.getName(); 
                  // newstep.Last_Reassign_from__c=
                    if(newstep.Re_assign_Count__c!=null){
                       newstep.Re_assign_Count__c=newstep.Re_assign_Count__c+1; 
                    }else {
                        newstep.Re_assign_Count__c=1; 
                    }
                   
                }
            }
            If(oldStep.Status__c != newStep.Status__c){
                if (newStep.Status__c==OPEN) {
                    newStep.Step_Open_Time__c = Datetime.now();
                     if(bhId!=null){
                      Decimal hrs = 0;
                      if(processFlowStep.Duration_To_Complete_In_Hourss__c != null){
                            hrs = Decimal.valueOf(processFlowStep.Duration_To_Complete_In_Hourss__c);
                            Long durationMs = (Long)(hrs * 60 * 60 * 1000);
                           newStep.Expected_Completion_Time__c = BusinessHours.add(bhId, newStep.Step_Open_Time__c, durationMs);
                      }
                    }
                }
                if (newStep.Status__c==REQUIRED_INFO){
                    newStep.Re_Opened_For_More_Info_Tiime__c=Datetime.now();
                }
                if (newStep.Status__c==PROVIDED_INFO){
                    newStep.Assigned_With_Required_Info_Time__c=Datetime.now();
                }
                if(newStep.Status__c==COMPLETED){
                    newStep.Completed_Time__c =Datetime.now();
                    if(bhId!=null && newStep.Expected_Completion_Time__c!=null){
                        Long esc = BusinessHours.diff(bhId, newStep.Expected_Completion_Time__c, System.now());
                        //newStep.Escalated_Time__c = esc > 0 ? (esc / 1000 / 60) : 0;
                    }
                }
                
               if(newStep.Status__c==RE_OPEN){
                    if(newstep.Re_Open_Count__c==null){
                        newstep.Re_Open_Count__c=1;
                    } else {
                        newstep.Re_Open_Count__c=newstep.Re_Open_Count__c+1;
                    }
                   newstep.Last_reopen_time__c =Datetime.now();
                   newstep.Re_Opened_By__c=UserInfo.getName();
             }
                
            }
           
        }
        
        BusinessProcessManadatoryDocuments.validateMandatoryDocuments(newList, oldMap);
        BusinessProcessManadatoryFields.validateMandatoryFields(newList, oldMap);
    }
 
    //*** After Insert Action***//
    public override   void afterInsertMethod(List<SObject> newList, Map<Id, SObject> newMap) {
        handleStatusChange(newList);
    }
      
    
    
    //*** After Update Action***//
    public override  void afterUpdateMethod(List<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap) { 
        List<Business_Process__c> bpList=new List<Business_Process__c>();
        Set<ID> bpSetCompleted=new Set<ID>();
        Map<ID,Business_Process__c> bpMap=new  Map<ID,Business_Process__c>();
        system.debug('newList '+newList);
        Set<ID> stepIds=new Set<ID>();
        for(Business_Process_Step__c newStep : (List<Business_Process_Step__c>) newList) {
            Business_Process__c bp=null;
            stepIds.add(newStep.ID);
            if(!bpMap.isEmpty() && bpMap.get(newStep.Business_Process__c)!=null){
                bp=bpMap.get(newStep.Business_Process__c); 
            }else{
                 bp=new Business_Process__c(); 
            }
           
            System.debug('------------------newStep.Status__c = '+newStep.Status__c);
            if(newStep.Status__c==OPEN || newStep.Status__c==RE_OPEN || newStep.Status__c==PROVIDED_INFO || newStep.Status__c==ACCEPTED ){
                bp.ID=newStep.Business_Process__c;
                bp.Current_Business_Process_Step__c=newStep.Id;  
                // bpList.add(bp);
                bpMap.put(newStep.Business_Process__c, bp);
            }else if(newStep.Status__c==COMPLETED || newStep.Status__c==REQUIRED_INFO){
                bp.ID=newStep.Business_Process__c;
                bp.Previous_Business_Process_Step__c=newStep.Id; 
                
                 if(newStep.Status__c==COMPLETED  && !newStep.Is_Process_End__c){
                    bp.Status__c=IN_PROGRESS;
                }
                
                if(newStep.Status__c==COMPLETED && newStep.Is_Process_End__c){
                    bp.End_Date__c=System.now();
                    bp.Status__c=COMPLETED;
                    bpSetCompleted.add(bp.ID);
                } 
                bpMap.put(newStep.Business_Process__c, bp);
            }else if(newStep.Status__c==CANCELLED ){
                bp.ID=newStep.Business_Process__c;
                bp.End_Date__c=System.now();
                bp.Status__c=CANCELLED;
                bpMap.put(newStep.Business_Process__c, bp);
            }
        }  
        
        if(!bpMap.isEmpty()){
            
            if(!bpSetCompleted.isEmpty()){
                
                Map<Id, BusinessProcessTimeCalculation> bpStepTimeMap = new Map<Id, BusinessProcessTimeCalculation>();
                
                // Aggregate Completed__c times from related Business_Process_Step__c
                AggregateResult[] stepTimeAgg = [
                    SELECT Business_Process__c bpId, SUM(Completed__c) totalTime, SUM(Completed_in_Hours__c) totalHours, SUM(Completed_in_Days__c) totalDays
                    FROM Business_Process_Step__c
                    WHERE Business_Process__c IN :bpSetCompleted
                    GROUP BY Business_Process__c
                ];
                
                for (AggregateResult ar : stepTimeAgg) {
                    Id bpId = (Id) ar.get('bpId');
                    Integer totalTime = (Integer) ar.get('totalTime');
                    Integer CompletedInHours = (Integer) ar.get('totalHours');
                    Integer completedInDays = (Integer) ar.get('totalDays');
                    BusinessProcessTimeCalculation timeCalculation =new BusinessProcessTimeCalculation();
                    timeCalculation.TotalCompletionTime=totalTime;
                    timeCalculation.CompletedInHours=CompletedInHours;
                    timeCalculation.completedInDays=CompletedInHours;
                    bpStepTimeMap.put(bpId, timeCalculation);
                }
                
                // Set calculated Total_Time__c and Escalated_Time__c in bpMap
                for (Id bpId : bpStepTimeMap.keySet()) {
                    if (bpMap.containsKey(bpId)) {
                        Business_Process__c bp = bpMap.get(bpId);
                        bp.Total_Time__c = bpStepTimeMap.get(bpId).TotalCompletionTime; 
                        bp.Total_Time_In_Hours__c = bpStepTimeMap.get(bpId).CompletedInHours; 
                        bp.Total_Time_in_Days__c = bpStepTimeMap.get(bpId).completedInDays; 
                    }
                }
                
            }
            
            if(!bpMap.values().isEmpty())
            update bpMap.values();
        }
        
        handleStatusChange(newList,oldMap);
      //  StepTimeCalculator.checkstatusApprovedOrRejected(newList,oldMap);
        BusinessProcesssMandatoryFieldUpdate.populateMandatoryFields(Trigger.new,Trigger.oldMap); 
        Map<ID,Business_Process_Step__c> processFlowMap=new Map<ID,Business_Process_Step__c>
            ([select ID,Process_Flow_Step__r.Process_Flow__r.Business_Hours_ID__c,Process_Flow_Step__r.Duration_To_Complete_In_Hourss__c from Business_Process_Step__c where  ID IN :stepIds and Status__c ='Completed']);
        StepOwnershipSummary.updateOwnershipSummary(processFlowMap.keySet(),processFlowMap);
    }
    
    
    //shiv
    public static void handleStatusChange(List<Sobject> newList){
        List<Business_Process_Step_Time_Log__c> newLogs = new List<Business_Process_Step_Time_Log__c>();
        for (Business_Process_Step__c newStep : (List<Business_Process_Step__c>) newList) {
            if (newStep.Status__c==OPEN || newStep.Status__c==ACCEPTED){
                 Business_Process_Step_Time_Log__c log = new Business_Process_Step_Time_Log__c();
                log.Business_Process_Step__c = newStep.Id;
                log.Business_Process__c=newStep.Business_Process__c;
                log.New_Status__c = newStep.Status__c;
                log.Step_Assigned_User__c = newStep.Assigned_To__c;
                log.Start_time__c = System.now();
                newLogs.add(log);
            }
        }  
         if (!newLogs.isEmpty()) {
           insert newLogs;
        }
    }
    
    
    
    public static void handleStatusChange(List<Sobject> newList, Map<Id, Sobject> oldMap) {
        List<Business_Process_Step_Time_Log__c> newLogs = new List<Business_Process_Step_Time_Log__c>();
        List<Business_Process_Step_Time_Log__c> logsToUpdate = new List<Business_Process_Step_Time_Log__c>();
        Set<Id> stepIdsWithChange = new Set<Id>();
        for (Business_Process_Step__c newStep : (List<Business_Process_Step__c>) newList) {
            Business_Process_Step__c oldStep = (Business_Process_Step__c) oldMap.get(newStep.Id);
            if (oldStep.Status__c != newStep.Status__c || oldStep.Re_assign_Count__c!=newStep.Re_assign_Count__c) {
                stepIdsWithChange.add(newStep.Id);  
              if(newStep.Status__c!=COMPLETED && newStep.Status__c!=REJECTED){
                Business_Process_Step_Time_Log__c log = new Business_Process_Step_Time_Log__c();
                log.Business_Process_Step__c = newStep.Id;
                log.New_Status__c = newStep.Status__c;
                log.Step_Assigned_User__c = newStep.Assigned_To__c;
                log.Start_time__c = System.now();
                log.Business_Process__c=newStep.Business_Process__c;
                newLogs.add(log);
                }
            }
        }

        if (!stepIdsWithChange.isEmpty()) {
            // Get latest existing logs for those steps
            List<Business_Process_Step_Time_Log__c> existingLogs = [
                SELECT Id, Business_Process_Step__c, End_Time__c
                FROM Business_Process_Step_Time_Log__c
                WHERE Business_Process_Step__c IN :stepIdsWithChange
                ORDER BY Start_time__c DESC
            ];

             Set<Id> updatedSteps = new Set<Id>();
            for (Business_Process_Step_Time_Log__c log : existingLogs) {
                if (!updatedSteps.contains(log.Business_Process_Step__c) && log.End_Time__c == null) {
                    log.End_Time__c = System.now();
                    logsToUpdate.add(log);
                    updatedSteps.add(log.Business_Process_Step__c);
                }
            }
        }

        if (!logsToUpdate.isEmpty()) {
            update logsToUpdate;
        }

        if (!newLogs.isEmpty()) {
            insert newLogs;
        }
    }  

}