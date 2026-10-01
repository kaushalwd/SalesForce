/**********************************************************************************************************************
* Name               : BookingFeeTimerBatch                                                        
* Description        : Batch process to automatically release Unit reservations and reset Opportunity states 
*                      once the active Booking SLA timer expires.
* Usage              : Database.executeBatch(new BookingFeeTimerBatch(), 20);
* Created By         : Suresh                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.1           Suresh/Modon                12 07 2026      Initial       
******************************************************************************************************************/
public without sharing class BookingFeeTimerBatch implements Database.Batchable<sObject>, Database.AllowsCallouts, Database.Stateful {
    
    public Database.QueryLocator start(Database.BatchableContext bc) {
        DateTime currentExecutionTime = DateTime.now();
        System.debug('>>>> BookingFeeTimerBatch.start | Current Execution Boundary: ' + currentExecutionTime);
        
        return Database.getQueryLocator([
            SELECT Id, Name, BookingSLA__c, BookingSLAEnd__c, BookingStatus__c, Unit__c, Unit__r.ApprovalStatus__c, 
                   Unit__r.Status__c, Unit__r.Sub_Status__c, OwnerId 
            FROM Opportunity 
            WHERE BookingStatus__c = 'Reserved'
              AND Source_Entity__c != 'Modon - Egypt' 
              AND BookingSLAEnd__c <= :currentExecutionTime
              AND Unit__c != null
              AND Total_Received_Amount__c = 0
            WITH SYSTEM_MODE
        ]);
    }    
   		
    public void execute(Database.BatchableContext bc, List<Opportunity> scope) {
        System.debug('>>>> BookingFeeTimerBatch.execute | Processing batch scope size: ' + scope.size());
        
        Set<Id> setUnitIds = new Set<Id>();
        Map<Id, Opportunity> unitToOppMap = new Map<Id, Opportunity>();
        List<Opportunity> finalOpp = new List<Opportunity>();        
        
        List<Unit__c> unitsToUpdate = new List<Unit__c>();
        List<Opportunity> oppsToUpdate = new List<Opportunity>();
        
        try {
            for (Opportunity objOpp : scope) {
                if (objOpp.Unit__c != null) {
                    setUnitIds.add(objOpp.Unit__c);
                    if (!unitToOppMap.containsKey(objOpp.Unit__c)) {
                        unitToOppMap.put(objOpp.Unit__c, objOpp);
                    }
                }                                            
            }
            
            if (setUnitIds.isEmpty()) {
                return; 
            }
            
            List<Unit__c> lstUnit = [
                SELECT Id, ApprovalStatus__c, Status__c, Sub_Status__c, BlockedFor__c, BlockedBy__c, 
                       Blocked_Time__c, BlockComment__c, Name 
                FROM Unit__c
                WHERE Id IN :setUnitIds
                WITH SYSTEM_MODE 
                FOR UPDATE
            ];
            
            for (Unit__c objUnit : lstUnit) {
                objUnit.Sub_Status__c   = 'Un-Assigned';
                objUnit.BlockedFor__c   = null; 
                objUnit.BlockedBy__c    = null;
                objUnit.Blocked_Time__c = null;
                objUnit.BlockComment__c = '';                
                unitsToUpdate.add(objUnit);
                
                if (unitToOppMap.containsKey(objUnit.Id)) {
                    Opportunity objUpdOpp = unitToOppMap.get(objUnit.Id);
                    objUpdOpp.BookingSLAEnd__c = null;
                    objUpdOpp.BookingStatus__c = 'Available';
                    objUpdOpp.BookingSLA__c    = null;
                    oppsToUpdate.add(objUpdOpp);
                }
            }
            
            if (!unitsToUpdate.isEmpty()) {
                Database.SaveResult[] unitSR = Database.update(unitsToUpdate, false, AccessLevel.SYSTEM_MODE);
                logDmlFailures(unitSR, 'Unit__c');
            }
            
            if (!oppsToUpdate.isEmpty()) {
                Database.SaveResult[] oppSR = Database.update(oppsToUpdate, false, AccessLevel.SYSTEM_MODE);
                logDmlFailures(oppSR, 'Opportunity');
            }
            
        } catch (Exception ex) {
            System.debug('>>>> BookingFeeTimerBatch Critical Error: ' + ex.getMessage());
            LoggerService.save(LoggerService.createApexLog(ex, 'BookingFeeTimerBatch', 'execute', 'Critical Batch Processing Context Exception'));
        }        
    }
    
    public void finish(Database.BatchableContext bc) {
        System.debug('>>>> BookingFeeTimerBatch.finish | Pipeline execution successfully finalized.');
    }

    private void logDmlFailures(Database.SaveResult[] results, String sObjectType) {
        for (Database.SaveResult sr : results) {
            if (!sr.isSuccess()) {
                for (Database.Error err : sr.getErrors()) {
                    System.debug('>>>> DML Failure on ' + sObjectType + ' | Record ID: ' + sr.getId() + ' | Error: ' + err.getMessage());
                }
            }
        }
    }
}