/**********************************************************************************************************************
* Name               :                                                         
* Description        : Class for BP framework
* Usage              : BP Framework                                                        
* Created By         : Sivannarayana Peddireddi                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                          Date            Comment                                                                       
* 1.0           sivannaryana.p@modon.com     10-05-2026      Initial Draft     
**********************************************************************************************************************/
public without sharing class MilestoneTriggerHelper {

    public static void updateDueDateBasedMilestone(list<SObject> newList, Map<Id, SObject> oldMap){
    
        Set<Id> setUnitMilestioneId = new Set<Id>();
        Set<Id> setMilestoneDateUpdates = new Set<Id>();
        for(Milestone__c ms : (List<Milestone__c>)newList){
            Milestone__c oldMilestone = (Milestone__c)oldMap.get(ms.Id);
            if(ms.ConfirmedMilestoneDate__c != oldMilestone.ConfirmedMilestoneDate__c && ms.ConfirmedMilestoneDate__c!= null){
                setUnitMilestioneId.add(ms.Id);
            }
            
            if(ms.Milestone_Due_Date__c != oldMilestone.Milestone_Due_Date__c && ms.Milestone_Due_Date__c != null){
                setMilestoneDateUpdates .add(ms.Id);
            }
        }
        system.debug('------MilestoneTriggerHelper----------------setUnitMilestioneId----------------'+setUnitMilestioneId);
        if(setUnitMilestioneId.size()>0 && setUnitMilestioneId != null){
            system.debug('------MilestoneTriggerHelper----------------setUnitMilestioneId-----inside-----------'+setUnitMilestioneId);
           UpdateMilestoneBatch shn = new UpdateMilestoneBatch(setUnitMilestioneId,'cofirmed milestone'); 
            //database.executeBatch(shn,1);
        }
        
        if(setMilestoneDateUpdates.size()>0 && setMilestoneDateUpdates != null){
            system.debug('------MilestoneTriggerHelper----------------setMilestoneDateUpdates -----inside-----------'+setMilestoneDateUpdates );
            UpdateMilestoneBatch shn = new UpdateMilestoneBatch(setMilestoneDateUpdates,'milestone due date'); 
            //database.executeBatch(shn,1);
        }
        
    }
}