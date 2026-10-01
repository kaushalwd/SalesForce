/**********************************************************************************************************************
* Name               : TaskTriggerHelper                                                       
* Description        : This is a helper class for TaskTriggerHandler
* Usage              : Called from TaskTriggerHandler
* Created By         : PWC Digital Middle East                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Anil Valluri                21 Dec 2022     Initial Draft    
* 1.1           Prateek Bansal              26 Dec 2023     Update opportunity status on task creation 
* 1.2           Shubham Agrawal             03 Mar 2024     Call log email notifications
* 1.3           Sirisha Reddy               10 Jan 2025     Create new task for service request
* 1.4           Krishna Chaitanya Ramadugu  10 Jan 2025     Create new task for service request property transfer
* 1.5           Suresh  					19 Nov 2025     SendSMSNotification added
* 1.6           Raghu Sharma                11 May 2026     Sharing the pre unit cancellation sr's to Task Owners
******************************************************************************************************************/
public without sharing class TaskTriggerHelper {
    
    //v1.1
    /*public static void updateOpportunityStatus(list<SObject> newList,map<ID,SObject> newMap){
set<Id> opportunityIds = new set<Id>();

for(Task newTask : (List<Task>)newList){
if(String.isNotBlank(newTask.WhatId) && (String.valueOf(newTask.WhatId)).startsWith('006')){
opportunityIds.add(newTask.WhatId);
}
}

if(!opportunityIds.isEmpty()){
List<Opportunity> oppLst = [SELECT Id FROM Opportunity WHERE StageName = 'Discussion In Progress' AND Id IN : opportunityIds];
if(!oppLst.isEmpty()){
for(Opportunity oppObj : oppLst){
oppObj.StageName = 'Registration in progress';
}
UPDATE oppLst;
}
}
}*/
    
    public static void updateTaskOwnerFromLead(list<SObject> newList,map<ID,SObject> newMap){
        System.debug('TaskTriggerHelper >>>>  updateTaskOwnerFromLead >>  ');
        set<Id> leadIds = new set<Id>();
        List<Lead> lst_Lead = new List<Lead>();
        List<Task> lst_UpdateTask = new List<Task>();
        Map<Id, Task> map_Lead = new Map<Id, Task>();
        for(Task newTask : (List<Task>)newList){
            if(String.isNotBlank(newTask.WhoId) && (String.valueOf(newTask.WhoId)).startsWith('00Q')){
                leadIds.add(newTask.WhoId);                
                if(!map_Lead.containsKey(newTask.WhoId)){
                    map_Lead.put(newTask.WhoId, newTask);
                }
            }
        }
        if(leadIds.size() > 0){
            lst_Lead = [select Id, OwnerId from Lead where Id IN :leadIds]; 
        }
        for(Lead obj_Lead : lst_Lead){
            if(map_Lead.containsKey(obj_Lead.Id)){
                Task obj_Task = map_Lead.get(obj_Lead.Id);
                obj_Task.OwnerId = obj_Lead.OwnerId;
                //lst_UpdateTask.add(obj_Task);
            }
        }
        //newList = lst_UpdateTask;
        System.debug('TaskTriggerHelper >>>>  updateTaskOwnerFromLead >>  Completed >>  '+System.JSON.serialize(newList));
    }
    
  
    public static void updateLeadStatus_BasedOnTaskStatus(list<SObject> newList, Map<Id, SObject> newMap, 
                                                          List<SObject> oldList, Map<Id, SObject> oldMap){ 
                                                             
                                                              Schema.SObjectType leadObjType = Schema.Lead.getSObjectType();
                                                              List<Task> lst_createNewTask = new List<Task>();
                                                              set<Id> set_LeadId = new set<Id>();
                                                              List<Lead> lst_updateStatusLead = new List<Lead>();
                                                              List<Lead> lst_lead = new List<Lead>();
                                                              Map<Id, Lead> map_Lead = new Map<Id, Lead>();
                                                              List<Task> lst_ProspectTask = new List<Task>();                                                      
                                                              Id prospectTaskRecordTypeId = Schema.SObjectType.Task.getRecordTypeInfosByName().get('Prospect').getRecordTypeId();
                                                              List<Messaging.SingleEmailMessage> emailsToSend = new List<Messaging.SingleEmailMessage>();
                                                              Map<String, Id> templateNameToIdMap = new Map<String, Id>();
                                                              Map<String, Id> task_templateNameToIdMap = new Map<String, Id>();   
                                                              
                                                              
                                                              for(Task obj_Task : (List<Task>)newList){
                                                                  if(obj_Task.RecordTypeId == prospectTaskRecordTypeId){
                                                                      set_LeadId.add(obj_Task.WhoId);
                                                                      lst_ProspectTask.add(obj_Task);
                                                                  } 
                                                              }                                                      
                                                              
                                                              if(lst_ProspectTask.size() > 0){
                                                                  Map<Decimal, Task_Management__mdt> map_TaskMetadata = new Map<Decimal, Task_Management__mdt>();
                                                                  List<BusinessHours> orgBusinessHours = [select Id from BusinessHours where IsActive = true and IsDefault=true];
                                                                  List<Task_Management__mdt> lst_TaskMetadata = [select Label, ObjectName__c,Milestone__c,SLA__c, SLATimeType__c, Category__c, 
                                                                                                                 Subcategory__c from Task_Management__mdt where ObjectName__c = 'Lead'];
                                                                  
                                                                  for(EmailTemplate tem : [SELECT Id, DeveloperName FROM EmailTemplate 
                                                                                           WHERE DeveloperName IN ('Lead_Customer_No_Answer_All_Notification',
                                                                                                                   'Lead_Cus_Invalid_Number_Notification',
                                                                                                                   'Lead_Customer_No_Answer_Notification')]) {
                                                                                                                       templateNameToIdMap.put(tem.DeveloperName, tem.Id);
                                                                                                                   }
                                                                  
                                                                  for(EmailTemplate tem : [SELECT Id, DeveloperName FROM EmailTemplate 
                                                                                           WHERE DeveloperName IN ('Lead_Agent_Pending_Call_Tasks_SLA',
                                                                                                                   'Lead_Agent_Pending_Call_Tasks')]) {
                                                                                                                       task_templateNameToIdMap.put(tem.DeveloperName, tem.Id);
                                                                                                                   }
                                                                  System.debug('Tasktriggerhelper >>>>>>>  '+System.JSON.serialize(templateNameToIdMap));
                                                                  System.debug('Tasktriggerhelper >>>>>>>  '+System.JSON.serialize(task_templateNameToIdMap));
                                                                  for(Task_Management__mdt obj_TaskMetadata : lst_TaskMetadata){
                                                                      if(!map_TaskMetadata.containsKey(obj_TaskMetadata.Milestone__c)){
                                                                          map_TaskMetadata.put(obj_TaskMetadata.Milestone__c, obj_TaskMetadata);
                                                                      }
                                                                  }      
                                                                  
                                                                  
                                                                  
                                                                  lst_lead = [Select Id, Status, LeadSource, Project__r.Name, NumberOfBedrooms__c, CustomerBudget__c, Email,
                                                                              Finance__c, Investment__c from Lead where Id in: set_LeadId];
                                                                  for(Lead obj_Lead : lst_lead){
                                                                      if(!map_Lead.containsKey(obj_Lead.Id)){
                                                                          map_Lead.put(obj_Lead.Id, obj_Lead);
                                                                      }                                                    
                                                                  }                                                      
                                                                  for(Task obj_Task : (List<Task>)newList){
                                                                      Task oldRecord;
                                                                      if(oldMap <> null){
                                                                          oldRecord = (Task)oldMap.get(obj_Task.Id);
                                                                      }
                                                                      System.debug('TaskTrigger >>>> oldRecord.Status >>  obj_Task.Status >> '+oldRecord.Status+' >> '+obj_Task.Status);
                                                                      System.debug('TaskTrigger >>>> leadObjType >> '+leadObjType);
                                                                      // System.debug('TaskTrigger >>>> obj_Task.WhoId.getSObjectType() >> '+obj_Task.WhoId.getSObjectType()); - Commented as creating issue in flow execution 
                                                                      if( oldMap != null && oldRecord.Status != obj_Task.Status && obj_Task.whoId != null 
                                                                         && obj_Task.WhoId.getSObjectType() == leadObjType) {
                                                                             System.debug('TaskTrigger >>>>  Started >>>>'); 
                                                                             //Updated Task Status as Customer Not Interested 
                                                                             if(obj_Task.Status == Constants.TASK_STATUS_INVALID_NUMBER || 
                                                                                (obj_Task.Status == Constants.TASK_STATUS_CUSTOMER_REACHED 
                                                                                 && obj_Task.CustomerResponse__c == Constants.TASK_CUS_RESPONSE_INTEREST_LOST)){
                                                                                     /* System.debug('TaskTrigger >>>>  '+obj_Task.Status); 
Lead obj_Lead = map_Lead.get(obj_Task.WhoId); 
if(obj_Lead != null && (obj_Lead.Status == Constants.LEAD_STATUS_NEW || 
obj_Lead.Status == Constants.LEAD_STATUS_IN_PROGRESS)){
obj_Lead.Status = Constants.LEAD_STATUS_RETIRED;
obj_Lead.RetiredReason__c = obj_Task.CustomerResponse__c;
obj_Lead.RetirementComments__c = obj_Task.Description;
obj_Lead.Retired_DateTime__c = System.now();
lst_updateStatusLead.add(obj_Lead);

//Send Customer Notification - Invalid Number

// emailsToSend.add(getSingleEmail(obj_Lead.Id, null, obj_Lead.Id, templateNameToIdMap.get('Lead_Cus_Invalid_Number_Notification'))); 


//System.debug('Tasktriggerhelper >>>>>>>  '+System.JSON.serialize(emailsToSend)); 
}*/
                                                                                 }
                                                                             //Updated Task Status as Customer not able to reach before SLA
                                                                             if(obj_Task.NextTaskMilestone__c > 0 
                                                                                && ((obj_Task.Status == Constants.TASK_STATUS_CUS_NOT_REACHABLE)
                                                                                    ||(obj_Task.Status == Constants.TASK_STATUS_CUSTOMER_REACHED
                                                                                       && obj_Task.CustomerResponse__c == Constants.TASK_CUS_BUSY))){
                                                                                           System.debug('TaskTrigger >>>>  '+obj_Task.Status);
                                                                                           Lead obj_Lead = map_Lead.get(obj_Task.WhoId); 
                                                                                           if(obj_Lead != null && obj_Lead.Status == Constants.LEAD_STATUS_NEW){
                                                                                               obj_Lead.Status = Constants.LEAD_STATUS_IN_PROGRESS;
                                                                                               lst_updateStatusLead.add(obj_Lead);
                                                                                           }       
                                                                                           Task obj_NewTask = createNewTaskForLead(obj_Task, map_TaskMetadata, orgBusinessHours);
                                                                                           if(obj_NewTask != null){
                                                                                               lst_createNewTask.add(obj_NewTask);
                                                                                           }
                                                                                           // send customer notification - Lead_Customer_No_Answer_Notification
                                                                                           if(obj_Lead != null){
                                                                                               //emailsToSend.add(getSingleEmail(obj_Lead.Id, null, obj_Lead.Id, templateNameToIdMap.get('Lead_Customer_No_Answer_Notification'))); 
                                                                                               /*if (obj_Lead.Email != null) {
NotificationUtility.sendNotification(
'Lead_Customer_No_Answer_Notification',        // emailTemplateDeveloperName
new List<Id>{ obj_Lead.Id },                   // recipientIds (Lead ID)
false,                                         // sendBellNotification (optional)
obj_Lead.Id,                                   // whatId → relatedTo (Lead)
null,                                          // whoId (optional)
null, null, null,                              // bell title/body/target
null                                           // bellNotificationTypeDeveloperName
);
}*/
                                                                                               
                                                                                               System.debug('Tasktriggerhelper >>>>>>>  '+System.JSON.serialize(emailsToSend)); 
                                                                                           }
                                                                                           
                                                                                       }
                                                                             
                                                                             if(obj_Task.Status == Constants.TASK_STATUS_CUSTOMER_REACHED 
                                                                                && obj_Task.CustomerResponse__c == Constants.TASK_CUS_CUST_INTERESTED){
                                                                                    System.debug('TaskTrigger >>>>  '+obj_Task.Status);
                                                                                    Lead obj_Lead = map_Lead.get(obj_Task.WhoId); 
                                                                                    if(obj_Lead != null && 
                                                                                       (obj_Lead.Status == Constants.LEAD_STATUS_NEW || obj_Lead.Status == Constants.LEAD_STATUS_IN_PROGRESS)){
                                                                                           
                                                                                           Boolean missingFields = String.isBlank(obj_Lead.Project__r.Name)
                                                                                               || String.isBlank(obj_Lead.NumberOfBedrooms__c)
                                                                                               || String.isBlank(obj_Lead.CustomerBudget__c)
                                                                                               || String.isBlank(obj_Lead.Finance__c)
                                                                                               || String.isBlank(obj_Lead.Investment__c);
                                                                                           
                                                                                           if(missingFields){
                                                                                               obj_Task.addError('Please fill in Project, Bedroom, Budget, Finance, and Investment on the Lead before qualifying.');
                                                                                               return; 
                                                                                           }
                                                                                           
                                                                                           obj_Lead.Status = Constants.LEAD_STATUS_QUALIFY;
                                                                                           obj_Lead.ReAssignRRToSalesAssociate__c = true;                     
                                                                                           lst_updateStatusLead.add(obj_Lead);
                                                                                       }
                                                                                }
                                                                         }    
                                                                  } 
                                                                  if(lst_updateStatusLead.size() > 0){
                                                                      update lst_updateStatusLead;                                                     
                                                                  }                                                      
                                                                  if(lst_createNewTask.size() > 0){
                                                                      System.debug('TaskTrigger >>>> New Tasks >> '+System.JSON.serialize(lst_createNewTask));
                                                                      insert lst_createNewTask;                          
                                                                  }
                                                                  
                                                                  if(!emailsToSend.isEmpty()) {
                                                                      System.debug('Tasktriggerhelper 2222 >>>>>>>  '+System.JSON.serialize(emailsToSend)); 
                                                                      Messaging.sendEmail(emailsToSend);
                                                                  }
                                                              }                                                      
                                                          }
    
    
    
    public static Task createNewTaskForLead(Task currentTask, Map<Decimal, Task_Management__mdt> map_TaskMetadata, 
                                            List<BusinessHours> orgBusinessHours){
                                                System.debug('TaskTrigger >>>>   createNewTaskForLead >> started');                                        
                                                Task obj_Task;
                                                Long taskInterval = 0;
                                                DateTime addHoursToTaskDueDate;
                                                Id prospectTaskRecordTypeId = Schema.SObjectType.Task.getRecordTypeInfosByName().get('Prospect').getRecordTypeId();
                                                if(currentTask != null && map_TaskMetadata != null && map_TaskMetadata.size() > 0 
                                                   && orgBusinessHours != null){
                                                       
                                                       Task_Management__mdt obj_TaskMetadata = map_TaskMetadata.get(Integer.valueOf(currentTask.NextTaskMilestone__c));
                                                       Task_Management__mdt obj_NextTaskMetadata = map_TaskMetadata.get(Integer.valueOf(currentTask.NextTaskMilestone__c+1));
                                                       //Current Task details
                                                       if(obj_TaskMetadata.SLATimeType__c == 'seconds'){
                                                           taskInterval = Integer.valueOf(obj_TaskMetadata.SLA__c) * 1000;
                                                       } else if(obj_TaskMetadata.SLATimeType__c == 'minutes'){
                                                           taskInterval = Integer.valueOf(obj_TaskMetadata.SLA__c) * 60 * 1000;
                                                       } else if(obj_TaskMetadata.SLATimeType__c == 'hours'){
                                                           taskInterval = Integer.valueOf(obj_TaskMetadata.SLA__c) * 60 * 60 * 1000;
                                                       } else {} 
                                                       
                                                       //Create a call task for leads
                                                       if(taskInterval != 0){
                                                           addHoursToTaskDueDate = BusinessHours.add( orgBusinessHours[0].id , system.now() , taskInterval  );
                                                           addHoursToTaskDueDate = DateTime.parse(addHoursToTaskDueDate.format());
                                                           Date dueDate = Date.newInstance(addHoursToTaskDueDate.year(), addHoursToTaskDueDate.month(), 
                                                                                           addHoursToTaskDueDate.day());
                                                           obj_Task = new Task();
                                                           obj_Task.RecordTypeId = prospectTaskRecordTypeId;
                                                           obj_Task.whoId = currentTask.whoId;
                                                           obj_Task.OwnerId = currentTask.OwnerId;
                                                           obj_Task.Subject = Constants.TASK_CALL_SUBJECT+' '+Integer.valueOf(currentTask.NextTaskMilestone__c) +
                                                               ' - '+currentTask.Subject.substringAfter('-');
                                                           obj_Task.ActivityDate = dueDate;
                                                           obj_Task.CurrentTaskSLA__c = addHoursToTaskDueDate;
                                                           obj_Task.Status = Constants.TASK_STATUS_OPEN;
                                                           obj_Task.System_Created__c = true;
                                                           obj_Task.Created_DateTime__c = System.now();
                                                           if(obj_NextTaskMetadata != null){
                                                               obj_Task.NextTaskMilestone__c =  obj_NextTaskMetadata.Milestone__c;
                                                           } else {
                                                               obj_Task.NextTaskMilestone__c = 0; 
                                                           }
                                                       }
                                                       
                                                   }
                                                System.debug('TaskTrigger >>>>   createNewTaskForLead >> end >> '+System.JSON.serialize(obj_Task));                                        
                                                return obj_Task;       
                                            }
    // Commented by Naga - There is no reference of calling of this method in the Task Trigger Handler
    /* public static void autoCloseTask_and_Recreate(list<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap){ // Call this After Update


map<string, Date> mp_LeadID_TaskDueDate = new map<string, Date>();
map<string, string> mp_leadID_LeadOwnerID = new map<string, string>();

for(Task newTask : (List<Task>)newList){

Task oldRecord;
if(oldMap <> null){
oldRecord = (Task)oldMap.get(newTask.Id);
}

if( oldMap <> null && oldRecord.Status <> newTask.Status  && newTask.Status == Constants.TASK_STATUS_NOT_AVAILABLE && newTask.System_Created__c == true){ 

mp_LeadID_TaskDueDate.put(newTask.WhoId, newTask.ActivityDate); // The values in this map are not used currently. Only Key is used. If the Due Date of new task has to be calculated based on old Task's Due Date, then the values in this map can be used (no major changes to the code will be required if Map is used).
mp_leadID_LeadOwnerID.put(newTask.WhoId, newTask.OwnerId);
}   

}

if(!mp_LeadID_TaskDueDate.isEmpty()){
list<Task> lst_newTasks_toCreate = new list<Task>();
DateTime addHoursToTaskDueDate;
list<BusinessHours> orgBusinessHours = [select Id from BusinessHours where IsActive = true and IsDefault=true];
General_Parameters__mdt gp = General_Parameters__mdt.getInstance('Task_SLA_Time');
integer taskSLATime = integer.valueOf(gp.Value__c);
Long interval = taskSLATime * 60 * 60 * 1000;
addHoursToTaskDueDate = BusinessHours.add( orgBusinessHours[0].id , system.now() , interval  );
Date dueDate = Date.newInstance(addHoursToTaskDueDate.year(), addHoursToTaskDueDate.month(), addHoursToTaskDueDate.day());

for(string leadId: mp_LeadID_TaskDueDate.keySet()){
Task tsk = new Task();
tsk.whoId = leadId;
tsk.OwnerId = mp_leadID_LeadOwnerID.containsKey(leadId)? mp_leadID_LeadOwnerID.get(leadId) : null;
tsk.Subject = Constants.TASK_SUBJECT_FOR_LEAD_FOLLOWUP;
tsk.ActivityDate = dueDate;
tsk.Status = Constants.TASK_STATUS_OPEN;
tsk.System_Created__c = true;

lst_newTasks_toCreate.add(tsk);
}

if(!lst_newTasks_toCreate.isEmpty()){
insert lst_newTasks_toCreate;
}
}

} */
    
    //V1.2 - START
    public static void sendCallLogNotifications(List<SObject> newList, Map<Id, SObject> newMap) {
        
        Map<Id, Task> taskRelatedToLead = new Map<Id, Task>();
        Map<Id, Task> taskRelatedToAccount = new Map<Id, Task>();
        
        String callCenterProfileId = [SELECT Id FROM Profile WHERE Name = :Constants.PROFILE_CALL_CENTER_MANAGEMENT LIMIT 1]?.Id;
        
        Map<String, Id> templateNameToIdMap = new Map<String, Id>();
        for(EmailTemplate tem : [SELECT Id, DeveloperName FROM EmailTemplate WHERE DeveloperName IN ('CallLogNotificationToOpportunityOwner','CallLogNotificationToLeadOwner')]) {
            templateNameToIdMap.put(tem.DeveloperName, tem.Id);
        }
        
        Id notificationTypeId = [SELECT Id, DeveloperName FROM CustomNotificationType WHERE DeveloperName='CallLogNotification']?.Id; 
        
        for(Task newTask : (List<Task>)newList) {
            
            //if current user profile is Call center
            if(UserInfo.getProfileId() == callCenterProfileId && ( (newTask.Subject !=null && newTask.Subject.toLowerCase().contains('maqsam') ) || (newTask.CallObject!=null && newTask.CallObject.toLowerCase() == 'modon')) && newTask.WhoId!=null) {
                
                //check if newTask.WhoId is object type Lead
                if((newTask.WhoId).getSObjectType().getDescribe().getName() == 'Lead') {
                    taskRelatedToLead.put(newTask.WhoId, newTask);
                }
                
                //check if newTask.WhoId is not blank and starts with '006' -- related to Opportunity
                else if((newTask.WhoId).getSObjectType().getDescribe().getName() == 'Contact' && newTask.AccountId != null) {
                    taskRelatedToAccount.put(newTask.AccountId, newTask);
                }
                
            }                
            
        }
        
        List<Messaging.SingleEmailMessage> emailsToSend = new List<Messaging.SingleEmailMessage>();
        
        if(!taskRelatedToLead.isEmpty()) {
            for(Lead relatedLead : [SELECT Id, Name, OwnerId, Owner.Email, Owner.Profile.Name FROM Lead WHERE Id IN :taskRelatedToLead.keySet()]) {
                if(relatedLead?.Owner?.Profile.Name != null && String.valueOf(relatedLead.Owner.Profile.Name).containsIgnoreCase('Sales')) {
                    emailsToSend.add(getSingleEmail(relatedLead.OwnerId, null, relatedLead.Id, templateNameToIdMap.get('CallLogNotificationToLeadOwner')));
                    sendCustomNotification(relatedLead.Name, relatedLead.Id, notificationTypeId, relatedLead.OwnerId);
                }
            }
        }
        
        if(!taskRelatedToAccount.isEmpty()) {
            for(Opportunity relatedOpenOpp : [
                SELECT Id, OwnerId, Owner.Profile.Name, Owner.Email, Account.Name
                FROM Opportunity 
                WHERE AccountId IN :taskRelatedToAccount.keySet()
                AND IsClosed = false
            ]) {
                if(relatedOpenOpp?.Owner?.Profile.Name != null && String.valueOf(relatedOpenOpp.Owner.Profile.Name).containsIgnoreCase('Sales')) {
                    emailsToSend.add(getSingleEmail(relatedOpenOpp.OwnerId, null, relatedOpenOpp.Id, templateNameToIdMap.get('CallLogNotificationToOpportunityOwner')));
                    sendCustomNotification(relatedOpenOpp.Account.Name, relatedOpenOpp.Id, notificationTypeId, relatedOpenOpp.OwnerId);
                }
            }
        }
        
        if(!emailsToSend.isEmpty()) {
            Messaging.sendEmail(emailsToSend);
        }
        
    }
    
    public static Messaging.SingleEmailMessage getSingleEmail(String userId, String ccMail, String targetObjectId, String templateId){
        Messaging.SingleEmailMessage mail =  new Messaging.SingleEmailMessage();
        mail.setToAddresses(new String[]{userId});
        if(String.isNotBlank(ccMail)) mail.setCcAddresses(new String[]{ccMail});
        mail.setTargetObjectId(targetObjectId);
        mail.setSaveAsActivity(false);
        mail.setTemplateId(templateId);// This is template ID
        //mail.setSenderDisplayName('Modon Sales Team');
        
        return mail;
    }
    
    public static void sendCustomNotification(String customerName, String targetObjectId, Id notificationTypeId, String userId){
        
        if(notificationTypeId != null) {
            Messaging.CustomNotification notification = new Messaging.CustomNotification();
            notification.setTitle('You have a new Call log for customer ' + customerName);
            notification.setBody('You have a new call log for your customer ' + customerName + '. Please click here for more details.');
            notification.setNotificationTypeId(notificationTypeId);
            notification.setTargetId(targetObjectId);
            
            notification.send(new Set<String>{userId});
        }
    }
    
    //Changes added by Naga Chaitanya
    public static void isSLAExpired(List<SObject> newList, Map<Id, SObject> oldMap) {
        // Initialize required variables and collections
        String oppRecordTypeID = Schema.getGlobalDescribe().get('Task').getDescribe().getRecordTypeInfosByName().get('Opportunity').getRecordTypeId();
        Long taskInterval = 0;
        Set<Id> opportunityIds = new Set<Id>();
        Map<Id, Id> oppOwnerMap = new Map<Id, Id>();
        List<Task> newTasks = new List<Task>();
        Date dueDate;
        DateTime addHoursToTaskDueDate;
        
        // Query active and default business hours
        List<BusinessHours> orgBusinessHours = [SELECT Id FROM BusinessHours WHERE IsActive = TRUE AND IsDefault = TRUE];
        
        // Fetch Task metadata for Opportunities
        Map<Decimal, Task_Management__mdt> map_TaskMetadata = new Map<Decimal, Task_Management__mdt>();
        List<Task_Management__mdt> lst_TaskMetadata = [SELECT Label, ObjectName__c, Milestone__c, SLA__c, SLATimeType__c, Category__c, Subcategory__c FROM Task_Management__mdt WHERE ObjectName__c = 'Opportunity'];
        for (Task_Management__mdt obj_TaskMetadata : lst_TaskMetadata) {
            map_TaskMetadata.put(obj_TaskMetadata.Milestone__c, obj_TaskMetadata);
        }
        
        // Iterate through the new tasks to identify those with SLA expiration
        for (Task t : (List<Task>) newList) {
            Task oldRecord = (oldMap.containsKey(t.Id)) ? (Task) oldMap.get(t.Id) : null;
            
            // Check if task is related to an Opportunity and if SLA expired status is updated
            if (t.RecordTypeId == oppRecordTypeID && t.Status == Constants.TASK_STATUS_AGENT_SLA_EXPIRED && oldRecord != null && oldRecord.Status != Constants.TASK_STATUS_AGENT_SLA_EXPIRED && t.Subject.startsWith('Call Task 1')) {
                opportunityIds.add(t.WhatId);  // Add Opportunity Id
                oppOwnerMap.put(t.WhatId, t.OwnerId);  // Map Opportunity Id to OwnerId
            }
        }
        
        // If there are Opportunities to process, proceed with round-robin assignment of tasks
        if (!opportunityIds.isEmpty()) {
            Map<Id, Id> roundRobinMap = RoundRobinAssignmentUtility.getAvailableAgent(opportunityIds, 'Sales User', oppOwnerMap, true);
            
            // Iterate through new tasks to create follow-up tasks based on round-robin assignment
            if (!roundRobinMap.isEmpty()) {
                for (Task t : (List<Task>) newList) {
                    // Check if the task is SLA expired and the Opportunity has an assigned agent
                    if (t.RecordTypeId == oppRecordTypeID && t.Status == Constants.TASK_STATUS_AGENT_SLA_EXPIRED && roundRobinMap.containsKey(t.WhatId)) {
                        Task newTask = new Task();
                        
                        // Fetch old task data if available and calculate the new milestone and due date
                        if (oldMap.containsKey(t.Id)) {
                            Task oldTaskRecord = (Task) oldMap.get(t.Id);
                            String oppNameOlder = oldTaskRecord.Subject.substringAfter(' - ');
                            Integer previousMileStone = Integer.valueOf(oldTaskRecord.NextTaskMilestone__c);
                            previousMileStone++;
                            
                            newTask.NextTaskMilestone__c = previousMileStone;
                            newTask.Subject = Constants.TASK_CALL_SUBJECT + ' ' + String.valueOf(previousMileStone) + ' - ' + oppNameOlder;
                            
                            // Retrieve the task metadata for the updated milestone and calculate SLA interval
                            System.debug('previousMileStone'+previousMileStone);
                            Task_Management__mdt obj_TaskMetadata = map_TaskMetadata.get(Integer.valueOf(previousMileStone)) != null ? map_TaskMetadata.get(Integer.valueOf(previousMileStone)) : map_TaskMetadata.get(1);
                            system.debug('obj_TaskMetadata '+obj_TaskMetadata);
                            if (obj_TaskMetadata != null) {
                                if (obj_TaskMetadata.SLATimeType__c == 'seconds') {
                                    taskInterval = Integer.valueOf(obj_TaskMetadata.SLA__c) * 1000;
                                } else if (obj_TaskMetadata.SLATimeType__c == 'minutes') {
                                    taskInterval = Integer.valueOf(obj_TaskMetadata.SLA__c) * 60 * 1000;
                                } else if (obj_TaskMetadata.SLATimeType__c == 'hours') {
                                    taskInterval = Integer.valueOf(obj_TaskMetadata.SLA__c) * 60 * 60 * 1000;
                                }
                            }
                            
                            // Calculate the due date based on SLA interval
                            if (taskInterval != 0) {
                                System.debug('I am inside taskInterval!=0: '+taskInterval);
                                addHoursToTaskDueDate = BusinessHours.add(orgBusinessHours[0].Id, System.now(), taskInterval);
                                addHoursToTaskDueDate = DateTime.parse(addHoursToTaskDueDate.format());
                                dueDate = Date.newInstance(addHoursToTaskDueDate.year(), addHoursToTaskDueDate.month(), addHoursToTaskDueDate.day());
                            }
                        }
                        
                        // Set task fields and add to the list of new tasks
                        newTask.WhatId = t.WhatId;
                        newTask.OwnerId = roundRobinMap.get(t.WhatId);
                        newTask.ActivityDate = dueDate;
                        System.debug('newTask.ActivityDate '+ newTask.ActivityDate);
                        newTask.CurrentTaskSLA__c = addHoursToTaskDueDate;
                        newTask.Status = Constants.TASK_STATUS_OPEN;
                        newTask.RecordTypeId = oppRecordTypeID;
                        newTasks.add(newTask);
                    }
                }
            }
        }
        
        // Insert the newly created tasks if there are any
        if (!newTasks.isEmpty()) {
            database.insert(newTasks, false);  // Bulk insert tasks, suppressing DML exceptions
        }
    }
    
    //Changes added by Naga Chaitanya
    public static void updateOpportunityStage_BasedOnTaskStatus(List<SObject> newList, Map<Id, SObject> newMap,  List<SObject> oldList, Map<Id, SObject> oldMap) {
        
        // Set to store opportunity IDs that need stage update
        Set<Id> opportunityIds = new Set<Id>();
        Set<Id> unitSelectionIds = new Set<Id>();
        
        Id opportunityTaskRecordTypeId = Schema.SObjectType.Task.getRecordTypeInfosByName().get('Opportunity').getRecordTypeId();
        
        // Iterate over the new tasks to identify any that meet the condition for stage change
        for (Task newTask : (List<Task>) newList) {
            if(newTask.RecordTypeId == opportunityTaskRecordTypeId){
                Task oldRecord;
                // Check if there is an old task record for comparison (only if oldMap is not empty)
                if (oldMap.size() > 0 && oldMap.containsKey(newTask.Id)) {
                    oldRecord = (Task) oldMap.get(newTask.Id);
                } else {
                    oldRecord = null; // If no old record exists, set it to null
                }
                // Check if the task is related to an Opportunity (starts with '006') and has the status 'Requested for Appointment'
                if (String.isNotBlank(newTask.WhatId) && (String.valueOf(newTask.WhatId)).startsWith('006')) {
                    // Ensure the status has changed from the old record to the new record, if an old record exists
                    if (oldRecord != null &&  Constants.TASK_DISCUSSION_SET.contains(newTask.Status)  && newTask.Status != oldRecord.Status) {
                        // If the condition is met, add the Opportunity ID to the set
                        opportunityIds.add(newTask.WhatId);
                    } 
                    if (oldRecord != null &&  newTask.Status == Constants.TASK_STATUS_CUSTOMER_REACHED  && newTask.Status != oldRecord.Status &&
                        newTask.CustomerResponse__c == Constants.TASK_CUS_CUST_INTERESTED) {
                            // If the condition is met, add the Opportunity ID to the set
                            unitSelectionIds.add(newTask.WhatId);
                        } 
                }
            }
            
        }
        
        // If there are opportunity IDs that need their stage updated
        if (!opportunityIds.isEmpty()) {
            // Fetch the opportunities based on the collected Opportunity IDs
            List<Opportunity> oppToBeUpdatedList = [SELECT Id, StageName FROM Opportunity WHERE Id IN :opportunityIds];
            
            // Iterate over the opportunities and update their stage to 'Discussion in Progress'
            for (Opportunity opp : oppToBeUpdatedList) {
                if(unitSelectionIds.contains(opp.Id)){
                    opp.StageName = 'Unit Selection';
                }else{
                    opp.StageName = 'Discussion in Progress';
                }
            }
            System.debug('Inside the updateOpportunityStage_BasedonTaskStatus');
            System.debug(oppToBeUpdatedList);
            // Perform the update DML operation on the opportunities
            update oppToBeUpdatedList;
        }
    }
    
    //Changes added by Naga Chaitanya
    public static void checkIfNoUpdate(List<SObject> newList, Map<Id, SObject> oldMap) {
       
        // Initialize required variables and collections
        String oppRecordTypeID = Schema.getGlobalDescribe().get('Task').getDescribe().getRecordTypeInfosByName().get('Opportunity').getRecordTypeId();
        Set<Id> opportunityIds = new Set<Id>();
        Map<Id, Id> oppOwnerMap = new Map<Id, Id>();
        List<Task> newTasks = new List<Task>();
        Long taskInterval = 0;  // SLA time interval (default to 0, meaning no interval)
        Date dueDate;
        DateTime addHoursToTaskDueDate;
        
        // Query to get the active, default Business Hours
        List<BusinessHours> orgBusinessHours = [SELECT Id FROM BusinessHours WHERE IsActive = TRUE AND IsDefault = TRUE];
        
        // Fetch Task Management metadata for Opportunities
        Map<Decimal, Task_Management__mdt> map_TaskMetadata = new Map<Decimal, Task_Management__mdt>();
        List<Task_Management__mdt> lst_TaskMetadata = [SELECT Label, ObjectName__c, Milestone__c, SLA__c, SLATimeType__c, Category__c, Subcategory__c, MaxNoOfTasks__c FROM Task_Management__mdt WHERE ObjectName__c = 'Opportunity'];
        
        // Populate Task metadata map
        for (Task_Management__mdt obj_TaskMetadata : lst_TaskMetadata) {
            map_TaskMetadata.put(obj_TaskMetadata.Milestone__c, obj_TaskMetadata);
        }
        
        // Iterate over the new tasks to check specific conditions for creating follow-up tasks
        for (Task t : (List<Task>) newList) {
            if(t.RecordTypeId == oppRecordTypeID){
                // Fetch the old task record for comparison (if available)
                Task oldRecord = (oldMap.containsKey(t.Id)) ? (Task) oldMap.get(t.Id) : null;
                
                // Condition to check if task requires follow-up based on specific status changes or description
                if ((t.Status == Constants.TASK_STATUS_COMPLETED && oldRecord.Status != Constants.TASK_STATUS_COMPLETED && t.Description != null && t.Description.contains('No update'))
                    || (Constants.TASK_DISCUSSION_SET.contains(t.Status) && oldRecord.Status != t.Status && t.Status != Constants.TASK_STATUS_CUSTOMER_REACHED && t.Status != Constants.TASK_STATUS_INVALID_NUMBER)
                    || (t.Status == Constants.TASK_STATUS_AGENT_SLA_EXPIRED && oldRecord.Status != Constants.TASK_STATUS_AGENT_SLA_EXPIRED && !t.Subject.startsWith('Call Task 1'))) {
                        
                        Task newTask = new Task();
                        
                        if (oldRecord != null) {
                            // Parse old task's subject to get Opportunity name and increment milestone
                            String oppNameOlder = oldRecord.Subject.substringAfter(' - ');
                            Integer previousMileStone = Integer.valueOf(oldRecord.NextTaskMilestone__c);
                            previousMileStone++;  // Increment milestone for the follow-up task
                            newTask.NextTaskMilestone__c = previousMileStone;
                            newTask.Subject = Constants.TASK_CALL_SUBJECT + ' ' + String.valueOf(previousMileStone) + ' - ' + oppNameOlder;
                            System.debug('previousMileStone is: '+previousMileStone);
                            
                            // Fetch Task metadata for the updated milestone
                            //Task_Management__mdt obj_TaskMetadata = map_TaskMetadata.get(Integer.valueOf(previousMileStone));
                            //System.debug('obj_TaskMetadata is '+obj_TaskMetadata);
                            //System.debug('map_TaskMetadata.get(Integer.valueOf(previousMileStone)) '+ map_TaskMetadata.get(Integer.valueOf(1)));
                            Task_Management__mdt obj_TaskMetadata = map_TaskMetadata.get(Integer.valueOf(previousMileStone)) != null 
                                ? map_TaskMetadata.get(Integer.valueOf(previousMileStone)) 
                                : map_TaskMetadata.get(1);
                            
                            if (obj_TaskMetadata != null && previousMileStone <= obj_TaskMetadata.MaxNoOfTasks__c) {
                                // Calculate task interval based on SLA time type (seconds, minutes, hours)
                                if (obj_TaskMetadata.SLATimeType__c == 'seconds') {
                                    taskInterval = Integer.valueOf(obj_TaskMetadata.SLA__c) * 1000;
                                } else if (obj_TaskMetadata.SLATimeType__c == 'minutes') {
                                    taskInterval = Integer.valueOf(obj_TaskMetadata.SLA__c) * 60 * 1000;
                                } else if (obj_TaskMetadata.SLATimeType__c == 'hours') {
                                    taskInterval = Integer.valueOf(obj_TaskMetadata.SLA__c) * 60 * 60 * 1000;
                                }
                                
                            }
                            
                            // If task interval is set, calculate the due date based on business hours
                            if (taskInterval != 0) {
                                addHoursToTaskDueDate = BusinessHours.add(orgBusinessHours[0].Id, System.now(), taskInterval);
                                addHoursToTaskDueDate = DateTime.parse(addHoursToTaskDueDate.format());
                                dueDate = Date.newInstance(addHoursToTaskDueDate.year(), addHoursToTaskDueDate.month(), addHoursToTaskDueDate.day());
                            }
                        }
                        
                        // Set the fields for the new task and add to the list of tasks to be created
                        newTask.WhatId = t.WhatId;
                        newTask.ActivityDate = dueDate;
                        newTask.CurrentTaskSLA__c = addHoursToTaskDueDate;
                        newTask.Status = Constants.TASK_STATUS_OPEN;  // New task status is 'Open'
                        newTask.OwnerId = t.OwnerId;  // Assign the same owner as the original task
                        newTask.RecordTypeId = oppRecordTypeID;  // Set record type to 'Opportunity'
                        
                        // Add the new task to the list
                        if(dueDate != NULL){
                            newTasks.add(newTask);
                        }
                        
                    }
            }
        }
        
        // If there are new tasks to create, insert them into the database
        if (!newTasks.isEmpty()) {
            database.insert(newTasks, false);  // Bulk insert without DML exceptions
        }
    }
    
    
    public static void sendTaskNotification(List<SObject> newList, Map<Id, SObject> oldMap) {
        
        Map<Id,Id> taskUserIdMap = new Map<Id,Id>();
        List<Messaging.CustomNotification> notifications = new List<Messaging.CustomNotification>();
        
        for (Task newTask : (List<Task>) newList) {
            Task oldRecord;
            // Check if there is an old task record for comparison (only if oldMap is not empty)
            if (oldMap != null && oldMap.size() > 0 && oldMap.containsKey(newTask.Id)) {
                oldRecord = (Task) oldMap.get(newTask.Id);
            } else {
                oldRecord = null; // If no old record exists, set it to null
            } 
            if (oldRecord != null && (newTask.Status == Constants.TASK_STATUS_AGENT_SLA_EXPIRED ||  newTask.Status == Constants.TASK_STATUS_SLA_EXPIRED) && newTask.Status != oldRecord.Status) {
                taskUserIdMap.put(newTask.Id,newTask.ownerId);
            } 
            if (oldRecord == null && newTask.Status == Constants.TASK_STATUS_OPEN) {
                taskUserIdMap.put(newTask.Id,newTask.ownerId);
            } 
        }
        
        if(!taskUserIdMap.keyset().isEmpty()){
            Map<Id, User> userMap = new Map<Id, User>([
                SELECT Id, ManagerId FROM User WHERE Id IN :taskUserIdMap.values()
            ]);
            
            CustomNotificationType notifType = [SELECT Id FROM CustomNotificationType WHERE DeveloperName = 'Lead_Merge_Notification' LIMIT 1];
            
            
            for (Task  newTask: (List<Task>) newList) {
                
                if (taskUserIdMap.keySet().contains(newtask.Id) ) {
                    
                    Id assigneeId = newTask.OwnerId;
                    Id managerId = userMap.containsKey(assigneeId) ? userMap.get(assigneeId).ManagerId : null;
                    
                    Set<String> recipientIds = new Set<String>();
                    if (assigneeId != null) recipientIds.add(assigneeId);
                    if (managerId != null) recipientIds.add(managerId);
                    
                    if (!recipientIds.isEmpty()) {
                        Messaging.CustomNotification customNotificationObj = new Messaging.CustomNotification();
                        if(newTask.Status == Constants.TASK_STATUS_AGENT_SLA_EXPIRED || newTask.Status == Constants.TASK_STATUS_SLA_EXPIRED){
                            customNotificationObj.setBody('Agent SLA Expired for Task: ' + newTask.Subject);
                            customNotificationObj.setTitle('Agent SLA Expired');
                        }else{
                            customNotificationObj.setBody('A New Task has been assigned to you : ' + newTask.Subject);
                            customNotificationObj.setTitle('New Task Created');  
                        }
                        customNotificationObj.setNotificationTypeId(notifType.Id);
                        customNotificationObj.setTargetId(newTask.Id);
                        customNotificationObj.send(recipientIds);
                    }
                }
            } 
        }
    }
    /*public static void updateLeadCallTaskStatus(List<SObject> newList) {
        Map<Id, String> leadIdToTaskStatusMap = new Map<Id, String>();
        
        for (Task task : (List<Task>) newList) {
            if (task.WhoId != null && String.valueOf(task.WhoId).startsWith('00Q')) { 
                if (task.Subject != null) {
                    if (task.Subject.containsIgnoreCase('Call Task 1')) {
                        leadIdToTaskStatusMap.put(task.WhoId, 'Call Task 1');
                    } else if (task.Subject.containsIgnoreCase('Call Task 2')) {
                        leadIdToTaskStatusMap.put(task.WhoId, 'Call Task 2');
                    } else if (task.Subject.containsIgnoreCase('Call Task 3')) {
                        leadIdToTaskStatusMap.put(task.WhoId, 'Call Task 3');
                    }
                }
            }
        }
        
        if (!leadIdToTaskStatusMap.isEmpty()) {
            List<Lead> leadsToUpdate = new List<Lead>();
            for (Id leadId : leadIdToTaskStatusMap.keySet()) {
                leadsToUpdate.add(new Lead(
                    Id = leadId,
                    Call_Task_Status__c = leadIdToTaskStatusMap.get(leadId)
                ));
            }
            update leadsToUpdate;
        }
    }*/
    
    public static void sendSMSNotification(List<sObject> newList, Map<Id, sObject> oldMap){
        try{
            Set<Id> leadIds = new Set<Id>();
            for (Task obj_Task : (List<Task>) newList) {
                Task obj_OldTask = (Task)oldMap.get(obj_Task.Id);
                if (obj_Task.WhoId != null && String.valueOf(obj_Task.WhoId).startsWith('00Q')
                    && obj_OldTask.Status != obj_Task.Status && obj_Task.Status == 'Customer Not Reachable') {
                    leadIds.add(obj_Task.WhoId);
                }
            }
            if(leadIds.size() > 0){
          		TaskTriggerHelper.initiateSMSMessge(leadIds);
            }
            
        }catch(Exception exe){}        
    }   
   @future(callout = true)
   public static void initiateSMSMessge(Set<Id> leadIds) {
       try{
           if(leadIds.size() > 0){
                List<Lead> lst_Lead = new List<Lead>();
                lst_Lead = [select Id, Title, FirstName, LastName, Email, MobilePhone, ProjectInterest__c, LeadNumber__c, SMSBitlyURL__c 
                            from Lead where Id IN :leadIds and SMSBitlyURL__c != ''];
                List<SMSMessageRequest> lst_SMSMsgRequest = new List<SMSMessageRequest>();
                List<SMSMessageResponse> lst_SMSMsgResponse = new List<SMSMessageResponse>();
                if(lst_Lead.size() > 0){
                    for(Lead obj_Lead : lst_Lead){
                        SMSMessageRequest obj_SMSMsgRequest = new SMSMessageRequest();
                        obj_SMSMsgRequest.ProjectName = obj_Lead.ProjectInterest__c;
                        obj_SMSMsgRequest.CustomerName = obj_Lead.FirstName+' '+obj_Lead.LastName;
                        obj_SMSMsgRequest.MobileNumber = obj_Lead.MobilePhone;
                        obj_SMSMsgRequest.LeadNumber = obj_Lead.LeadNumber__c;
                        obj_SMSMsgRequest.LeadStatus = 'Customer Not Reached';
                        obj_SMSMsgRequest.BitlyMessageURL = obj_Lead.SMSBitlyURL__c;
                        lst_SMSMsgRequest.add(obj_SMSMsgRequest);
                    }
                    HttpRequest req = new HttpRequest();
                    req.setTimeout(120000);
                    req.setHeader('Accept', 'application/json');
                    req = OIC_CredentialsController.getCredentials('LeadCommunicationAPI');
                    req.setBody(JSON.serialize(lst_SMSMsgRequest));
                    system.debug('SMS >>>>> lst_SMSMsgRequest >> ' + JSON.serialize(lst_SMSMsgRequest));
                    Http http = new Http();
                    HTTPResponse res = http.send(req);
                    System.debug(res.getBody());
                }   
           }           	    
       }catch(Exception exe){}
   } 
    
 public static void sendCustomerEmails(List<sObject> newList, Map<Id, sObject> oldMap) {
    if (newList.isEmpty()) return;

    Map<Id, Task> oldTask = new Map<Id, Task>();
    for (Id tid : oldMap.keySet()) {
        oldTask.put(tid, (Task) oldMap.get(tid));
    }

    Set<Id> leadIds = new Set<Id>();

    for (Task t : (List<Task>) newList) {
        if (t.WhoId != null && String.valueOf(t.WhoId).startsWith('00Q')) {
            leadIds.add(t.WhoId);
        }
    }

    Map<Id, Lead> leadMap = leadIds.isEmpty() ? new Map<Id, Lead>() :
        new Map<Id, Lead>([SELECT Id, Email FROM Lead WHERE Id IN :leadIds]);

    Map<String, String> subjectTemplateMap = new Map<String, String>{
        'Call Task 1' => 'Lead_First_Notification',
        'Call Task 2' => 'Lead_Second_Notification',
        'Call Task 3' => 'Lead_Third_Notification'
    };

    for (Task newRec : (List<Task>) newList) {
        Task oldRec = oldTask.get(newRec.Id);

        if (oldRec == null || newRec.Subject == null || !newRec.Send_Customer_Notification__c) {
            continue;
        }

        for (String key : subjectTemplateMap.keySet()) {
            if (newRec.Subject.contains(key)) {
                String recipientEmail = (newRec.WhoId != null && leadMap.containsKey(newRec.WhoId)) 
                    ? leadMap.get(newRec.WhoId).Email 
                    : null;

                if (String.isNotBlank(recipientEmail)) {
                    SendGridNotificationUtility.sendEmail(
                        newRec.WhoId,
                        null,
                        subjectTemplateMap.get(key),
                        recipientEmail,
                        'noreply@modon.com',
                        'MODON Sales Team',
                        null,
                        null,
                        'Lead ' + key,
                        'Customer email',
                        null,
                        null,
                        newRec.WhoId 
                    );
                }
                break;
            }
        }
    }
}
    
    //V1.6
    public static void updateEscalationTimes (List<Task> taskList)
    {system.debug('debug: in ServiceRequestTraskController.updateEscalationTimes method');
        //List<Task> taskList = (List<Task>)newList;
        Set<Id> serviceActionIds = new Set<Id>();
        Set<Id> taskIds = new Set<Id>();
        Set<Id> srIds = new Set<Id>();
        
        //Update version 1.6 - SR sharing for assigned users
        List<ServiceRequest__Share> srShareList = new List<ServiceRequest__Share>();
        
        for(Task tsk : taskList)
        {
            if(tsk.ServiceAction__c != null)
            {
                serviceActionIds.add(tsk.ServiceAction__c);
                taskIds.add(tsk.Id);
                srIds.add(tsk.WhatId);
            }
        }
        if(serviceActionIds.isEmpty()) return;
        
        //Update version 1.6 Added RecordType.DeveloperName for service Request
        Map<Id,ServiceRequest__c> srMap = new Map<Id,ServiceRequest__c>([Select Id,Name,Name__c,RecordType.DeveloperName from ServiceRequest__c where Id in :srIds]); 
        Map<Id, ServiceAction__c> serviceActionMap = new Map<Id, ServiceAction__c>([SELECT Id,Escalation_1_SLA__c,Escalation_2_SLA__c,Escalation_3_SLA__c FROM ServiceAction__c WHERE Id IN :serviceActionIds]);

        Boolean escalationExists = false;

        for(ServiceAction__c sa : serviceActionMap.values())
        {
            if((sa.Escalation_1_SLA__c != null && sa.Escalation_1_SLA__c > 0) ||
            (sa.Escalation_2_SLA__c != null && sa.Escalation_2_SLA__c > 0) ||
            (sa.Escalation_3_SLA__c != null && sa.Escalation_3_SLA__c > 0))
            {
                escalationExists = true;
                break;
            }
        }

        if(!escalationExists)return;
        
        DateTime currTime = DateTime.now();
        Map<String,BusinessHours> mapBH = SystemContextClass.getActiveBusinessHours();
        BusinessHours bussHours = mapBH.get('Default');
        Holiday[] holidays = SystemContextClass.getHolidays();
        for (Task tsk: taskList)//(List<Task>)newList)
        {
            ServiceAction__c sa = serviceActionMap.get(tsk.ServiceAction__c);
            tsk.Related_To_Name__c = srMap.get(tsk.WhatId).Name;
            if(sa == null) continue;            
            if(sa != null && sa.Escalation_1_SLA__c != null && sa.Escalation_1_SLA__c > 0.0)
            {
                tsk.Escalation_1_Time__c = ServiceUtility.CalculateDueDate(currTime,(Integer)(sa.Escalation_1_SLA__c * 60),bussHours,holidays);
            }
            if(sa != null && sa.Escalation_2_SLA__c != null && sa.Escalation_2_SLA__c > 0.0)
            {
                tsk.Escalation_2_Time__c = ServiceUtility.CalculateDueDate(currTime,(Integer)(sa.Escalation_2_SLA__c * 60),bussHours,holidays);
            }
            if(sa != null && sa.Escalation_3_SLA__c != null && sa.Escalation_3_SLA__c > 0.0)
            {
                tsk.Escalation_3_Time__c = ServiceUtility.CalculateDueDate(currTime,(Integer)(sa.Escalation_3_SLA__c * 60),bussHours,holidays);
            }
            
            //Update version 1.6 - Sharing SR with Assigned To user for Pre_Unit_Cancellation sr
            
            if(srMap.containsKey(tsk.WhatId) && srMap.get(tsk.WhatId).RecordType.DeveloperName == 'Pre_Unit_Cancellation' && tsk.OwnerId != null){

                ServiceRequest__Share srShare = new ServiceRequest__Share();
                srShare.ParentId = tsk.WhatId;
                srShare.UserOrGroupId = tsk.OwnerId;
                srShare.AccessLevel = 'Edit';
                srShare.RowCause = Schema.ServiceRequest__Share.RowCause.Manual;
                srShareList.add(srShare);
            }
        }
        
        //Update version 1.6 - Insert SR share records for service Request
        
        if(!srShareList.isEmpty())
        {
            Database.insert(srShareList,false);
        }
    }
    
    

  public class SMSMessageRequest{
		public String LeadNumber{get;set;}
		public String MobileNumber{get;set;}
		public String LeadStatus{get;set;}
		public String CustomerName{get;set;}
		public String BitlyMessageURL{get;set;}
		public String ProjectName{get;set;}
   }
   public class SMSMessageResponse{
		public String LeadNumber{get;set;}
		public String BitlyURL{get;set;}
		public String Status{get;set;}
   } 
}