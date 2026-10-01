/**
* @File Name : MilestoneUpdateTracker.cls
* @Description :
* @Author :
* @Last Modified By :
* @Last Modified On : April 12, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | April 12, 2025 |   | Initial Version
**/

public with sharing class MilestoneUpdateTracker{
    @AuraEnabled(cacheable=true)
    public static List<Milestone_Update_Tracker__c> getChildRecords(Id parentId) {
        return [
            SELECT Id,Name, Actual_Milestone_Due_Date__c, Confirmed_Milestone_Date__c, Milestone__c,Milestone__r.Name,
            Reschedule_Milestone_Date__c,Service_Request__c,Is_Reschedule_Required__c,MilestoneRec__c
            FROM Milestone_Update_Tracker__c
            WHERE Service_Request__c = :parentId
        ]; 
    }

    @AuraEnabled
    public static string updateChildRecords(List<Milestone_Update_Tracker__c> updatedRecords,string srId) {
        try {
          system.debug('------updatedRecords--------------'+updatedRecords);
          system.debug('------srId--------------'+srId);
        set<string> milestoneUpdateIds = new set<string>();
          for(Milestone_Update_Tracker__c mut : updatedRecords){
              milestoneUpdateIds.add(mut.Id);
          }
         
          Map<string,Milestone_Update_Tracker__c>milestoneMap = new Map<string,Milestone_Update_Tracker__c>();
          for(Milestone_Update_Tracker__c  mst : [select id,Milestone__c,Milestone__r.Name from Milestone_Update_Tracker__c where Id IN:milestoneUpdateIds]){
              milestoneMap.put(mst.Id,mst);
          }
       //  system.debug('------srIds--------------'+srIds);
         List<ServiceRequest__c>srList=[select Id,Milestone__c from ServiceRequest__c where Id =:srId];
         system.debug('------srList--------------'+srList);
          
          if(srList.size()>0 && srList != null){
              ServiceRequest__c srRecord = srList.size()>0 && srList != null ? srList[0]:new ServiceRequest__c();
               system.debug('------srRecord --------------'+srRecord );

              string errormessage ='';
              boolean isError = false;
              for(Milestone_Update_Tracker__c mut : updatedRecords){
                 system.debug('------mut  --------------'+mut );
                    Milestone_Update_Tracker__c  msRecord = milestoneMap.get(mut.Id);
                 system.debug('------msRecord--------------'+msRecord);
                 system.debug('------srRecord.Milestone__c--------------'+srRecord.Milestone__c);
                 system.debug('------mut.Reschedule_Milestone_Date__c--------------'+mut.Reschedule_Milestone_Date__c);
                 system.debug('--111----mut.Confirmed_Milestone_Date__c--------------'+mut.Confirmed_Milestone_Date__c);

                  if(msRecord.Milestone__c == srRecord.Milestone__c){
                       system.debug('--matching----mut.Confirmed_Milestone_Date__c--------------'+mut.Confirmed_Milestone_Date__c);

                      if(mut.Confirmed_Milestone_Date__c == null){
                          system.debug('--matching----mut.Confirmed_Milestone_Date__c-------null-------'+mut.Confirmed_Milestone_Date__c);

                          errormessage += (errormessage != '') ? ' \n- Please enter Confirmed Milestone Date for '+msRecord.Milestone__r.Name : ' \n- Please enter Confirmed Milestone Date for '+msRecord.Milestone__r.Name;
                          isError = true;
                      }else{
                            system.debug('--matching----mut.Confirmed_Milestone_Date__c--not-----null-------'+mut.Confirmed_Milestone_Date__c);
                          if(mut.Confirmed_Milestone_Date__c < system.today()){
                              system.debug('--matching----mut.Confirmed_Milestone_Date__c--less than today------'+mut.Confirmed_Milestone_Date__c);
                              errormessage += (errormessage != '') ? ' \n- Confirmed Milestone Date should not be past date for '+msRecord.Milestone__r.Name : ' \n- Confirmed Milestone Date should not be past date for '+msRecord.Milestone__r.Name;
                              isError = true;
                          }
                      }
                      if(mut.Reschedule_Milestone_Date__c != null){
                          system.debug('--matching----mut.Reschedule_Milestone_Date__c -------null-------'+mut.Reschedule_Milestone_Date__c );
                          errormessage += (errormessage != '') ? ' \n- Please remove Reschedule Milestone Date Date for '+msRecord.Milestone__r.Name : ' \n- Please remove Reschedule Milestone Date Date for '+msRecord.Milestone__r.Name;
                          isError = true;
                      }
                  }else{
                      system.debug('-noooooooooooooooooo-matching----mut.Confirmed_Milestone_Date__c--------------'+mut.Confirmed_Milestone_Date__c);
                      system.debug('-noooooooooooooooooo-matching----mut.Reschedule_Milestone_Date__c --------------'+mut.Reschedule_Milestone_Date__c );

                      if(mut.Confirmed_Milestone_Date__c != null){
                          system.debug('-noooooooooooooooooo-matching----mut.Reschedule_Milestone_Date__c --not-----null-------'+mut.Reschedule_Milestone_Date__c );
                          errormessage += (errormessage != '') ? ' \n- Please remove Confirmed Milestone Date for '+msRecord.Milestone__r.Name : ' \n- Please remove Confirmed Milestone Date for '+msRecord.Milestone__r.Name;
                          isError = true;
                      }
                      
                      if(mut.Reschedule_Milestone_Date__c != null && mut.Reschedule_Milestone_Date__c < system.today()){
                          system.debug('-noooooooooooooooooo-matching----mut.Reschedule_Milestone_Date__c --not-----null-------'+mut.Reschedule_Milestone_Date__c );
                          errormessage += (errormessage != '') ? ' \n-  Reschedule Milestone Date should not be past date for '+msRecord.Milestone__r.Name : ' \n- Reschedule Milestone Date should not be past date for '+msRecord.Milestone__r.Name;
                          isError = true;
                      }
                      
                  }
              }
               system.debug('------isError--------------'+isError);
               system.debug('------errormessage--------------'+errormessage);

              if(!isError){
                  update updatedRecords;
                  return 'Success';
              }else{
                  return errormessage;
              }
          }else return 'Kindly contact system administrator';
          
        } catch (DmlException e) {
            throw new AuraHandledException('Failed to create contact: ' + e.getMessage());
        }catch(Exception e){
           throw new AuraHandledException('Failed to create contact: ' + e.getMessage());
        } 
    }
    
    //Not used
    @AuraEnabled
    public static void updateMilestoneRecords(List<Milestone_Update_Tracker__c> updatedRecords,string srId) {
        List<ServiceRequest__c> srList =[select Id from ServiceRequest__c where Id= :srId];
        List<Milestone_Update_Tracker__c> milestoneRecords = [select Id from Milestone_Update_Tracker__c where Service_Request__c =:srList[0].Id];
        srList  = new List<ServiceRequest__c>();
        srList  = new List<ServiceRequest__c>();
        srList  = new List<ServiceRequest__c>();
        srList  = new List<ServiceRequest__c>();
        milestoneRecords = new List<Milestone_Update_Tracker__c> ();
        milestoneRecords = new List<Milestone_Update_Tracker__c> ();
        milestoneRecords = new List<Milestone_Update_Tracker__c> ();
        milestoneRecords = new List<Milestone_Update_Tracker__c> ();
        milestoneRecords = new List<Milestone_Update_Tracker__c> ();
        milestoneRecords = new List<Milestone_Update_Tracker__c> ();
        milestoneRecords = new List<Milestone_Update_Tracker__c> ();
        milestoneRecords = new List<Milestone_Update_Tracker__c> ();
        milestoneRecords = new List<Milestone_Update_Tracker__c> ();
        milestoneRecords = new List<Milestone_Update_Tracker__c> ();
        milestoneRecords = new List<Milestone_Update_Tracker__c> ();
        milestoneRecords = new List<Milestone_Update_Tracker__c> ();
        milestoneRecords = new List<Milestone_Update_Tracker__c> ();
        milestoneRecords = new List<Milestone_Update_Tracker__c> ();
    }
}