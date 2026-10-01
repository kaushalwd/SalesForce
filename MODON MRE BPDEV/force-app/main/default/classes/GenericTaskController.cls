/**********************************************************************************************************************
* Name               :                                                         
* Description        : Class for BP framework
* Usage              : BP Framework                                                        
* Created By         : Sivannarayana Peddireddi                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                          Date            Comment                                                                       
* 1.0           sivannaryana.p@modon.com     10-05-2026      Initial Draft     
**********************************************************************************************************************/
public with sharing class GenericTaskController {

    private static final String GENERAL_TASK_RECORDTYPE = 'General_Task';
    private static final String CUSTOMER_SOLUTION_STATUS = 'Customer Solution';

    @AuraEnabled(cacheable=true)
    public static List<String> getPicklistValues(String objectName, String fieldName) {
        List<String> values = new List<String>();

        if (String.isBlank(objectName) || String.isBlank(fieldName)) {
            return values;
        }

        Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
        if (!globalDescribe.containsKey(objectName)) {
            return values;
        }

        Schema.SObjectType objType = globalDescribe.get(objectName);
        Schema.DescribeSObjectResult objDescribe = objType.getDescribe();
        Map<String, Schema.SObjectField> fieldMap = objDescribe.fields.getMap();

        if (!fieldMap.containsKey(fieldName)) {
            return values;
        }

        Schema.DescribeFieldResult fieldDescribe = fieldMap.get(fieldName).getDescribe();

        for (Schema.PicklistEntry pe : fieldDescribe.getPicklistValues()) {
            values.add(pe.getLabel());
        }

        return values;
    }

    @AuraEnabled
    public static void saveCallTask(Task t) {
        if (t == null || t.Id == null) {
            throw new AuraHandledException('Task Id is required.');
        }

        Task existingTask = [
            SELECT Id,
                   WhatId,
                   Status,
                   Priority,
                   Subject,
                   ActivityDate,
                   Description,
                   RecordTypeId,
                   
                   NextTaskMilestone__c,
                   D_T_Customer_Discussion_Outcome__c
            FROM Task
            WHERE Id = :t.Id
            LIMIT 1
        ];

        Id generalTaskRtId = Schema.SObjectType.Task
            .getRecordTypeInfosByDeveloperName()
            .get(GENERAL_TASK_RECORDTYPE)
            .getRecordTypeId();

        if (existingTask.RecordTypeId != generalTaskRtId) {
            throw new AuraHandledException('Only General Task record type can be updated.');
        }

        existingTask.Status = t.Status;
        existingTask.Description = t.Description;
        existingTask.D_T_Customer_Discussion_Outcome__c = t.D_T_Customer_Discussion_Outcome__c;

        update existingTask;

        if (existingTask.Status == CUSTOMER_SOLUTION_STATUS) {
            if (String.isBlank(existingTask.D_T_Customer_Discussion_Outcome__c)) {
                throw new AuraHandledException('Customer Discussion Outcome is required when status is Customer Solution.');
            }

            updateBusinessProcessFromTask(existingTask);
            return;
        }

        if (existingTask.Status == 'Contacted' ||
            existingTask.Status == 'Meeting Scheduled' ||
            existingTask.Status == 'Invalid Number') {
            return;
        }

        if (existingTask.Status == 'Customer Not Reachable' ||
            existingTask.Status == 'Mobile Switched Off') {

            if (existingTask.NextTaskMilestone__c != null &&
                Integer.valueOf(existingTask.NextTaskMilestone__c) <= 3) {

                Task nextTask = createNextTask(existingTask, generalTaskRtId);
                if (nextTask != null) {
                    insert nextTask;
                }
            }
        }
    }

    private static void updateBusinessProcessFromTask(Task t) {
        if (t.WhatId == null) {
            return;
        }

        String whatObjectName = String.valueOf(t.WhatId.getSObjectType());
        if (whatObjectName != 'Business_Process__c') {
            return;
        }

        Business_Process__c bp = new Business_Process__c(
            Id = t.WhatId,
            D_T_Customer_Discussion_Outcome__c = t.D_T_Customer_Discussion_Outcome__c
        );

        update bp;
    }

    public static Task createNextTask(Task currentTask, Id taskRtId) {
        if (currentTask.NextTaskMilestone__c == null) {
            return null;
        }

        Integer nextMilestone = Integer.valueOf(currentTask.NextTaskMilestone__c);

        if (nextMilestone > 3) {
            return null;
        }

        Task newT = new Task();
        newT.RecordTypeId = taskRtId;
        newT.WhatId = currentTask.WhatId;
        newT.OwnerId = UserInfo.getUserId();
        newT.Status = 'Open';
        //newT.Subject = 'Call Attempt - ' + String.valueOf(nextMilestone + 1);
        String str = currentTask.Subject;
        String result = str.replaceAll('\\d+$', '');
        newT.Subject = result + String.valueOf(nextMilestone + 1);
        newT.ActivityDate = System.today().addDays(1);
        newT.Priority = currentTask.Priority;
        newT.TaskSubtype = 'Call';
        newT.NextTaskMilestone__c = nextMilestone + 1;

        return newT;
    }

    public class TaskScreenWrapper {
        @AuraEnabled public List<Task> closedTasks;
        @AuraEnabled public Task currentOpenTask;
    }

    @AuraEnabled(cacheable=true)
    public static TaskScreenWrapper getTaskScreenData(Id recordId) {
        Id taskRtId = Schema.SObjectType.Task
            .getRecordTypeInfosByDeveloperName()
            .get(GENERAL_TASK_RECORDTYPE)
            .getRecordTypeId();

        TaskScreenWrapper wrap = new TaskScreenWrapper();
        wrap.closedTasks = new List<Task>();
        wrap.currentOpenTask = null;

        List<Task> allTasks = [
            SELECT Id,
                   Subject,
                   Status,
                   Priority,
                   ActivityDate,
                   Description,
                   WhatId,
                   
                   NextTaskMilestone__c,
                   D_T_Customer_Discussion_Outcome__c,
                   RecordTypeId,
                   CreatedDate
            FROM Task
            WHERE WhatId = :recordId
            AND RecordTypeId = :taskRtId
            ORDER BY CreatedDate DESC
        ];

        for (Task t : allTasks) {
            if (t.Status == 'Open' && wrap.currentOpenTask == null) {
                wrap.currentOpenTask = t;
            } else {
                wrap.closedTasks.add(t);
            }
        }

        return wrap;
    }
}