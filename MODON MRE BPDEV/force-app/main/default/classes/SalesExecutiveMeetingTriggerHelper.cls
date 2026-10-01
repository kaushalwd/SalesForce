/**********************************************************************************************************************
* Name               : SalesExecutiveMeetingTriggerHelper                                                        
* Description        : Helper class for SalesExecutiveMeetingTrigger
* Created By         : Rushi Patel
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Rushi Patel                 02 Sep 2026     Initial Draft           
******************************************************************************************************************/
public without sharing class SalesExecutiveMeetingTriggerHelper {

    /**
     * Clears out irrelevant broker fields when the Broker Category changes.
     */
    public static void clearIrrelevantBrokerFields(List<Sales_Executive_Meeting__c> newList, Map<Id, SObject> oldMap) {
        for (Sales_Executive_Meeting__c meeting : newList) {
            
            Boolean isCategoryChanged = false;
            if (oldMap == null) {
                isCategoryChanged = true;
            } else {
                Sales_Executive_Meeting__c oldMeeting = (Sales_Executive_Meeting__c)oldMap.get(meeting.Id);
                if (meeting.Broker_Category__c != oldMeeting.Broker_Category__c) {
                    isCategoryChanged = true;
                }
            }

            if (isCategoryChanged) {
                if (meeting.Broker_Category__c == 'New') {
                    // Clear the Existing Broker lookup field
                    meeting.Broker__c = null;
                } else if (meeting.Broker_Category__c == 'Existing') {
                    // Clear the New Broker manual fields
                    meeting.Broker_Name__c = null;
                    meeting.Broker_Location__c = null;
                }
            }
        }
    }

    /**
     * Creates, updates, or closes Follow-Up tasks when the Follow-up Date is set, changed, or cleared.
     */
    public static void createFollowUpTasks(List<Sales_Executive_Meeting__c> newList, Map<Id, SObject> oldMap) {
        List<Task> tasksToInsert = new List<Task>();
        List<Task> tasksToUpdate = new List<Task>();
        
        // 1. Identify which meetings had their follow-up date changed, set, or cleared
        Set<Id> meetingIdsWithNewDate = new Set<Id>();
        Set<Id> meetingIdsWithClearedDate = new Set<Id>();
        
        for (Sales_Executive_Meeting__c meeting : newList) {
            if (oldMap != null) {
                Sales_Executive_Meeting__c oldMeeting = (Sales_Executive_Meeting__c)oldMap.get(meeting.Id);
                
                // If the date was completely cleared out by the user
                if (meeting.Follow_up_Date__c == null && oldMeeting.Follow_up_Date__c != null) {
                    meetingIdsWithClearedDate.add(meeting.Id);
                } 
                // If the date was changed to a new valid date
                else if (meeting.Follow_up_Date__c != null && meeting.Follow_up_Date__c != oldMeeting.Follow_up_Date__c) {
                    meetingIdsWithNewDate.add(meeting.Id);
                }
            } else {
                // Insert context
                if (meeting.Follow_up_Date__c != null) {
                    meetingIdsWithNewDate.add(meeting.Id);
                }
            }
        }
        
        // 2. Handle cleared dates by closing any pending open tasks
        if (!meetingIdsWithClearedDate.isEmpty()) {
            for (Task t : [SELECT Id, Description FROM Task 
                           WHERE WhatId IN :meetingIdsWithClearedDate 
                           AND Subject LIKE 'Follow up with%' 
                           AND IsClosed = false]) {
                t.Status = 'Completed';
                t.IsReminderSet = false;
                t.Description = (t.Description == null ? '' : t.Description + '\n\n') + 
                                'System Note: This follow-up was automatically cancelled because the Follow-up Date was removed from the Meeting.';
                tasksToUpdate.add(t);
            }
        }
        
        // 3. Handle changed/new dates
        if (!meetingIdsWithNewDate.isEmpty()) {
            Map<Id, List<Task>> meetingToOpenTasks = new Map<Id, List<Task>>();
            for (Task t : [SELECT Id, WhatId, ActivityDate, ReminderDateTime, Subject FROM Task 
                           WHERE WhatId IN :meetingIdsWithNewDate 
                           AND Subject LIKE 'Follow up with%' 
                           AND IsClosed = false]) {
                if (!meetingToOpenTasks.containsKey(t.WhatId)) {
                    meetingToOpenTasks.put(t.WhatId, new List<Task>());
                }
                meetingToOpenTasks.get(t.WhatId).add(t);
            }
            
            // Fetch the General_Task record type ID safely
            Id generalTaskRtId;
            Schema.RecordTypeInfo rtInfo = Schema.SObjectType.Task.getRecordTypeInfosByDeveloperName().get('General_Task');
            if (rtInfo != null) {
                generalTaskRtId = rtInfo.getRecordTypeId();
            }
            
            // Fetch Meeting Record Types to dynamically set subject
            Map<Id, Schema.RecordTypeInfo> meetingRtInfos = Schema.SObjectType.Sales_Executive_Meeting__c.getRecordTypeInfosById();
            
            // Process the updates or inserts
            for (Sales_Executive_Meeting__c meeting : newList) {
                if (meetingIdsWithNewDate.contains(meeting.Id)) {
                    
                    Time reminderTime = Time.newInstance(8, 0, 0, 0);
                    Datetime newReminder = Datetime.newInstance(meeting.Follow_up_Date__c, reminderTime);
                    
                    String targetType = 'Customer'; // Default
                    if (meeting.RecordTypeId != null && meetingRtInfos.containsKey(meeting.RecordTypeId)) {
                        if (meetingRtInfos.get(meeting.RecordTypeId).getDeveloperName() == 'Broker') {
                            targetType = 'Broker';
                        }
                    }
                    String dynamicSubject = 'Follow up with ' + targetType;
                    
                    if (meetingToOpenTasks.containsKey(meeting.Id)) {
                        // Update the existing open tasks to the new date
                        for (Task existingTask : meetingToOpenTasks.get(meeting.Id)) {
                            existingTask.ActivityDate = meeting.Follow_up_Date__c;
                            existingTask.ReminderDateTime = newReminder;
                            existingTask.IsReminderSet = true;
                            existingTask.Subject = dynamicSubject;
                            tasksToUpdate.add(existingTask);
                        }
                    } else {
                        // Create a brand new one
                        Task followUpTask = new Task();
                        followUpTask.WhatId = meeting.Id;
                        followUpTask.OwnerId = meeting.OwnerId;
                        followUpTask.Subject = dynamicSubject;
                        followUpTask.ActivityDate = meeting.Follow_up_Date__c;
                        followUpTask.Status = 'Open';
                        followUpTask.Priority = 'Normal';
                        followUpTask.IsReminderSet = true;
                        followUpTask.ReminderDateTime = newReminder;
                        
                        if (generalTaskRtId != null) {
                            followUpTask.RecordTypeId = generalTaskRtId;
                        }
                        
                        tasksToInsert.add(followUpTask);
                    }
                }
            }
        }
        
        // 4. Perform DML (Bulkified and safe)
        if (!tasksToInsert.isEmpty()) {
            insert tasksToInsert;
        }
        if (!tasksToUpdate.isEmpty()) {
            update tasksToUpdate;
        }
    }
}