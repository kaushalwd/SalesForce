public without sharing class MilestoneSRCreationBatch implements Database.Batchable<sObject>, Schedulable {
    
    public set<Id> mileStoneIds = new set<Id>();
    
    public MilestoneSRCreationBatch(){
        mileStoneIds =  new set<Id>();
    }
    
    public MilestoneSRCreationBatch(set<Id> mileStoneRecIds){
        mileStoneIds =  mileStoneRecIds;
    }
    
    public Database.QueryLocator start(Database.BatchableContext BC) {
        
        Integer lookAheadDaysNonHandover = null;
        Integer lookAheadDaysHandoverPlot = null;
        Integer lookAheadDaysHandoverUnit = null;
        
        try {
            lookAheadDaysNonHandover = Integer.valueOf(System.Label.Milestone_Lookahead_Days);//for both unit and plot
            lookAheadDaysHandoverUnit = Integer.valueOf(System.Label.Milestone_Lookahead_Days_Handover_Unit);
            lookAheadDaysHandoverPlot = Integer.valueOf(System.Label.Milestone_Lookahead_Days_Handover_Plot);        
        } catch (Exception e) {
            System.debug('Invalid value in Custom Label Milestone_Lookahead_Days');
        }
        
        Date targetDateNonHandover = System.today().addDays(lookAheadDaysNonHandover);
        Date targetDateHandoverPlot = System.today().addDays(lookAheadDaysHandoverPlot);
        Date targetDateHandoverUnit = System.today().addDays(lookAheadDaysHandoverUnit);
        
        List<SalesOrderInstallments__c> SOIQuery = [
            SELECT Id, Name, SalesOrder__r.Name, Milestone_Name__c, Milestone_Installment__r.Name,
                   SalesOrder__r.Unit__r.Asset_Type__c, IsHandoverPayment__c,
                   Milestone_Installment__c, Milestone_Installment__r.ConfirmedMilestoneDate__c 
            FROM SalesOrderInstallments__c 
            WHERE Milestone_Installment__r.ConfirmedMilestoneDate__c = NULL 
            AND (
                (Milestone_Installment__r.Milestone_Due_Date__c = :targetDateNonHandover AND IsHandoverPayment__c = false) OR
                (SalesOrder__r.Unit__r.Asset_Type__c = 'Unit' AND Milestone_Installment__r.Milestone_Due_Date__c = :targetDateHandoverUnit AND IsHandoverPayment__c = true) OR
                (SalesOrder__r.Unit__r.Asset_Type__c = 'Plot' AND Milestone_Installment__r.Milestone_Due_Date__c = :targetDateHandoverPlot AND IsHandoverPayment__c = true)
            )
        ];
        
        for (SalesOrderInstallments__c soi : SOIQuery ){
            if (!mileStoneIds.contains(soi.Milestone_Installment__c)) {
                mileStoneIds.add(soi.Milestone_Installment__c);
            }
        }       
        
        if (!mileStoneIds.isEmpty()) {            
            return Database.getQueryLocator([
                SELECT Id, Name, Phase__c, Milestone_Due_Date__c, ConfirmedMilestoneDate__c
                FROM Milestone__c
                WHERE ConfirmedMilestoneDate__c = NULL
                AND Id IN :mileStoneIds
            ]);
        } else {
            return Database.getQueryLocator([
                SELECT Id, Name, Phase__c, Milestone_Due_Date__c, ConfirmedMilestoneDate__c
                FROM Milestone__c
                WHERE ConfirmedMilestoneDate__c = NULL
                AND Id = NULL
            ]);
        }
    }
    
    public void execute(Database.BatchableContext BC, List<Milestone__c> milestoneList){
        try{
            Id milestoneUpdateRecordTypeId = Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType,'Service_Request_Milestone_Update');
            List<ServiceRequest__c> ServiceRequestToCreate = new List<ServiceRequest__c>();
            Set<string>phaseIds = new Set<string>();
            //  date todayDt = system.today().addDays(45);
            //Date 27-01 2026 changed and added custom label.
            Integer lookAheadDays;
            try {
                lookAheadDays = Integer.valueOf(System.Label.Milestone_Lookahead_Days);
                system.debug('lookAheadDays======'+ lookAheadDays);
            } catch (Exception e) {
                System.debug('Invalid value in Custom Label Milestone_Lookahead_Days');
            }
            
            Date todayDt = System.today().addDays(lookAheadDays);
            
            // adding new logic to fill category and subcategory
            Map<Id, SalesOrderInstallments__c> milestoneToSOIMap = new Map<Id, SalesOrderInstallments__c>();
            
            for (SalesOrderInstallments__c soi : [SELECT Id,Milestone_Installment__c,IsHandoverPayment__c,SalesOrder__r.Unit__r.Asset_Type__c
                                                  FROM SalesOrderInstallments__c WHERE Milestone_Installment__c IN :milestoneList]) {
                                                      milestoneToSOIMap.put(soi.Milestone_Installment__c, soi);
                                                  }
            
            for(Milestone__c md : milestoneList){
                phaseIds.add(md.Phase__c);
                ServiceRequest__c newSR= new ServiceRequest__c();
                newSR.Name__c ='Milestone Update - '+md.Name;
                newSR.Milestone__c= md.Id;
                newSR.Type__c = 'Normal';
                newSR.Status__c='New';
                newSR.RecordTypeId = milestoneUpdateRecordTypeId;
                newSR.Source_Of_SR__c='Milestone Update - System';
                
                //----- new logic for category--------
                if (milestoneToSOIMap.containsKey(md.Id)) {

                    SalesOrderInstallments__c soiRec = milestoneToSOIMap.get(md.Id);

                    if (soiRec.IsHandoverPayment__c == true) {

                        newSR.Category__c = 'Handover';

                        if (soiRec.SalesOrder__r.Unit__r.Asset_Type__c == 'Unit') {
                            newSR.Sub_Category__c = 'Unit';
                        }
                        else if (soiRec.SalesOrder__r.Unit__r.Asset_Type__c == 'Plot') {
                            newSR.Sub_Category__c = 'Plot';
                        }
                    }
                }
                ServiceRequestToCreate.add(newSR);
            }
            
            if(ServiceRequestToCreate.size()>0 && !ServiceRequestToCreate.isEmpty()){
                system.debug('---Milestone Update---------ServiceRequestToCreate--------------'+ServiceRequestToCreate);
                Database.saveResult[]  srList = Database.insert(ServiceRequestToCreate,false);

                Set<string>srIdSet = new Set<string>();
                
                for (Database.SaveResult saveResult : srList) {
                    if (saveResult.isSuccess()) {
                        System.debug('Record Succesffully created '+saveResult.getId());
                        string srId = saveResult.getId();
                        srIdSet.add(srId);
                    } else {
                        for (Database.Error error : saveResult.getErrors()) {
                            System.debug('Record Failed'+error);
                        }
                    }
                }
                
                List<Milestone_Update_Tracker__c>mileStoneTrackerList = new List<Milestone_Update_Tracker__c>();
                if(srIdSet.size()>0){
                    for(ServiceRequest__c sr : [select Id,Milestone__c,Milestone__r.Phase__c,Milestone__r.Milestone_Due_Date__c,Milestone__r.ConfirmedMilestoneDate__c 
                                                from ServiceRequest__c where Id IN:srIdSet])
                    {
                        Milestone_Update_Tracker__c mut = new Milestone_Update_Tracker__c();
                        mut.Actual_Milestone_Due_Date__c = (sr.Milestone__r.ConfirmedMilestoneDate__c != null) ?  sr.Milestone__r.ConfirmedMilestoneDate__c : sr.Milestone__r.Milestone_Due_Date__c;
                        mut.Milestone__c= sr.Milestone__c;
                        mut.Service_Request__c = sr.Id;
                        mileStoneTrackerList.add(mut);
                    }
                }
                if(mileStoneTrackerList.size()>0)insert mileStoneTrackerList;
            }        
    }catch (DmlException e){
        LoggerService.save(LoggerService.createApexLog(e,'Milestone SRCreation','MilestoneSRCreationBatch','execute'));
    }
    catch(Exception ex){
        LoggerService.save(LoggerService.createApexLog(ex,'Milestone SRCreation','MilestoneSRCreationBatch','execute'));
    }
}

public void finish(Database.BatchableContext BC) {
}

//Schedulable execute method
public void execute(SchedulableContext SC){
    Database.executeBatch(new MilestoneSRCreationBatch(),1);
}
}