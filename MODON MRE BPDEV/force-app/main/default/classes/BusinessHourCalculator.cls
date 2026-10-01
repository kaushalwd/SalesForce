/**********************************************************************************************************************
* Name               :                                                         
* Description        : Class for BP framework
* Usage              : BP Framework                                                        
* Created By         : Sivannarayana Peddireddi                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                          Date            Comment                                                                       
* 1.0           sivannaryana.p@modon.com     10-05-2026      Initial Draft     
**********************************************************************************************************************/

public with sharing class BusinessHourCalculator {

    public class Result {
        @InvocableVariable public Id recordId;
        @InvocableVariable public Datetime reminderDateTime;
         @InvocableVariable public Datetime reminderDateTime2;
         @InvocableVariable public Datetime reminderDateTime3;
    }

    @InvocableMethod(label='Calculate Reminder DateTime Based on Business Hours')
    public static List<Result> calculateReminder(List<Id> recordIds) {
        Id bhId = [SELECT Id FROM BusinessHours WHERE IsDefault = TRUE LIMIT 1].Id;
        /*List<Business_Process_Step_Time_Log__c> logs = [
            SELECT Id, CreatedDate,Business_Process_Step__c, Business_Process_Step__r.Process_Flow_Step__c
            FROM Business_Process_Step_Time_Log__c 
            WHERE Id IN :recordIds
        ];*/
     
        Map<Id,Id> stepIds=new Map<Id, Id>(); 
        Set<Id> procStepIds=new Set<Id>();
        Map<Id,List<Step_Escalation__c>> EscMap=new Map<Id,List<Step_Escalation__c>>();
        for(Business_Process_Step__c step:[Select Id, Process_Flow_Step__c from Business_Process_Step__c where Id IN:recordIds ]){
            if(step.Process_Flow_Step__c!=null){
             stepIds.put(step.Id, step.Process_Flow_Step__c);
                procStepIds.add(step.Process_Flow_Step__c);
            }
        }
       
        if(stepIds.size()>0){
            List<Step_Escalation__c> stepEscalations=[Select Id, Process_Flow_Step__c,BCC_Email__c,CC_Email__c,Department_Head__c,Trigger_To__c,Escalation_Trigger_Days__c,Business_Hours__c,Escalation_hours__c, Escalation_minutes__c FROM Step_Escalation__c WHERE Process_Flow_Step__c IN :procStepIds Order by Escalation_Trigger_Days__c ASC ];
            for(Step_Escalation__c Esc: stepEscalations){
               
                if(EscMap.size()>0 && EscMap.containsKey(Esc.Process_Flow_Step__c)){
                  List<Step_Escalation__c> stpEscMap=EscMap.get(Esc.Process_Flow_Step__c);
                  stpEscMap.add(Esc);
                  EscMap.put(Esc.Process_Flow_Step__c,stpEscMap);  
                }  
                else{
                   List<Step_Escalation__c> stpEscMap=new List<Step_Escalation__c>();
                   stpEscMap.add(Esc); 
                   EscMap.put(Esc.Process_Flow_Step__c,stpEscMap);    
                }
            
            }
        }

        List<Result> results = new List<Result>();
        for (Id  log :stepIds.keySet()) {
            // Add 1 business day (8 business hours) after CreatedDate
            if(EscMap.size()>0){
            List<Step_Escalation__c> EscList=EscMap.get(stepIds.get(log));
            Integer st1=0; Integer st2=0; Integer st3=0;
            st1=getMinites(EscList[0]);
            if(EscList.size() > 1)  st2=getMinites(EscList[1]);
            if(EscList.size() > 2)  st3=getMinites(EscList[2]);    
            /*Integer st1=Integer.ValueOf(EscList[0].Escalation_Trigger_Days__c)*24  ;
            Integer st2 = (EscList.size() > 1) 
                                ? ((EscList[1].Escalation_Trigger_Days__c != null) 
                                ? Integer.valueOf(EscList[1].Escalation_Trigger_Days__c) * 24 
                                : 0): 0;
            Integer st3=EscList.size()>2 ? Integer.ValueOf(EscList[2].Escalation_Trigger_Days__c) :0;*/
            Id bhId1=EscList[0].Business_Hours__c!=null ? EscList[0].Business_Hours__c: bhId;
            Id bhId2=EscList.size() > 1 && EscList[1].Business_Hours__c!=null ? EscList[1].Business_Hours__c: bhId;    
            Id bhId3=EscList.size() > 2 && EscList[2].Business_Hours__c!=null ? EscList[2].Business_Hours__c: bhId;
                Datetime reminder = BusinessHours.add(bhId1, system.now(), st1* 60 * 1000);
            Datetime reminder2 = BusinessHours.add(bhId2, system.now(), st2 * 60 * 1000);
            Datetime reminder3 = BusinessHours.add(bhId3, system.now(), st3* 60 * 1000);    
            Result r = new Result();
            r.recordId = log;
            r.reminderDateTime = reminder; 
            if(EscList.size()>1) r.reminderDateTime2=reminder2;
            if(EscList.size()>2) r.reminderDateTime3=reminder3;    
            results.add(r);
          
            }
        }
        system.debug(results);
        
        return results;
    }
    
    Public static Integer getMinites(Step_Escalation__c esc){
        Integer totalMinutes = 0;
                if (esc.Escalation_Trigger_Days__c != null)
                    totalMinutes += Integer.valueOf(esc.Escalation_Trigger_Days__c) * 24 * 60;
                if (esc.Escalation_Hours__c != null)
                    totalMinutes += Integer.valueOf(esc.Escalation_Hours__c) * 60;
                if (esc.Escalation_Minutes__c != null)
                    totalMinutes += Integer.valueOf(esc.Escalation_Minutes__c);
        
        return totalMinutes;
        
    }
    
    
}