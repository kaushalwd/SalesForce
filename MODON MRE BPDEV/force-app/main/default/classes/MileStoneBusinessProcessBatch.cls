/**********************************************************************************************************************
* Name               :  MileStoneBusinessProcessBatch                                                       
* Description        : Class for BP framework
* Usage              : BP Framework                                                        
* Created By         : Sivannarayana Peddireddi                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                          Date            Comment                                                                       
* 1.0           sivannaryana.p@modon.com     10-05-2026      Initial Draft     
**********************************************************************************************************************/
public without sharing class MileStoneBusinessProcessBatch implements Database.Batchable<sObject>, Schedulable {
    
    public set<Id> mileStoneIds = new set<Id>();
    
    public MileStoneBusinessProcessBatch(){
        mileStoneIds =  new set<Id>();
    }
    
    public MileStoneBusinessProcessBatch(set<Id> mileStoneRecIds){
        mileStoneIds =  mileStoneRecIds;
    }
    
    public Database.QueryLocator start(Database.BatchableContext BC) {
        
        Integer lookAheadDaysNonHandover = 45;
        Integer lookAheadDaysHandoverPlot = null;
        Integer lookAheadDaysHandoverUnit = null;
     
            //lookAheadDaysNonHandover = Integer.valueOf(System.Label.Milestone_Lookahead_Days);//for both unit and plot
            //lookAheadDaysHandoverUnit = Integer.valueOf(System.Label.Milestone_Lookahead_Days_Handover_Unit);
            //lookAheadDaysHandoverPlot = Integer.valueOf(System.Label.Milestone_Lookahead_Days_Handover_Plot);        
      
        Date targetDateNonHandover = System.today().addDays(lookAheadDaysNonHandover);
        return Database.getQueryLocator([
            SELECT Id, Name, Phase__c, Milestone_Due_Date__c, ConfirmedMilestoneDate__c
            FROM Milestone__c
            WHERE ConfirmedMilestoneDate__c = NULL
            AND Milestone_Due_Date__c != NULL
            AND Milestone_Due_Date__c = :targetDateNonHandover
        ]);
    }
    
    public void execute(Database.BatchableContext BC, List<Milestone__c> milestoneList){
        try{
            List<Process_Flow__c> pflow=[Select Id, Name from Process_Flow__c where Active__c =true and Name='Project Milestone Confirmation'];
             if(pflow.isEmpty()) return;
            for(Milestone__c mil:milestoneList){
			 CreateBusinessProcess.createPreRegistration(mil.Id, pflow[0].Id );
			
			
			}


                                                 
            
            
            }        
    catch (DmlException e){
        LoggerService.save(LoggerService.createApexLog(e,'Milestone BP Creation','MileStoneBusinessProcessBatch','execute'));
    }
    catch(Exception ex){
        LoggerService.save(LoggerService.createApexLog(ex,'Milestone BP Creation','MileStoneBusinessProcessBatch','execute'));
    }
}

public void finish(Database.BatchableContext BC) {
}


public void execute(SchedulableContext SC){
    Database.executeBatch(new MileStoneBusinessProcessBatch(),1);
}
}