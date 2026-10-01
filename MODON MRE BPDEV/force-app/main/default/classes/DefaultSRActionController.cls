/**********************************************************************************************************************
* Name               :                                                         
* Description        : Class for BP framework
* Usage              : BP Framework                                                        
* Created By         : Sivannarayana Peddireddi                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                          Date            Comment                                                                       
* 1.0           sivannaryana.p@modon.com     10-05-2026      Initial Draft     
**********************************************************************************************************************/
public class DefaultSRActionController {

    public static void createCallTask(List<SObject> newList, String appendSubject) {

        System.debug('>>>>>>>>> createCallTask : Initiated');
        String owerQueue;
        if(appendSubject!=null && (appendSubject=='Default Notice1' || appendSubject=='Default Notice2')){
          owerQueue=system.label.DefaultNoticeOneQueue;  
        }

        String TaskRecordTypeId = Schema.SObjectType.Task
            .getRecordTypeInfosByDeveloperName()
            .get('General_Task')
            .getRecordTypeId();

        List<Task> tasksToInsert = new List<Task>();

        List<BusinessHours> bh = [
            SELECT Id
            FROM BusinessHours
            WHERE IsActive = true
            AND IsDefault = true
            LIMIT 1
        ];

        // Example SLA → 1 hour
        Integer taskInterval = 60 * 60 * 1000;
        
        for (SObject sob : newList) {
            String objectName = (sob.Id).getSObjectType().getDescribe().getName();
            Id recordId;
            if(objectName=='Business_Process_Step__c')
            recordId = (Id)sob.get('Business_Process__c');
            else
            recordId=(Id)sob.get('Id');    
            //Id ownerId  = (Id)sob.get('OwnerId');
            Id ownerId  = objectName=='Business_Process_Step__c' && owerQueue!=null ? owerQueue :(Id)sob.get('OwnerId');
            String name = !Test.isRunningTest() ? (String)sob.get('Name') : 'Test Name';

            DateTime dueDateTime = BusinessHours.add(
                bh[0].Id,
                System.now(),
                taskInterval
            );

            dueDateTime = DateTime.parse(dueDateTime.format());

            Date dueDate = Date.newInstance(
                dueDateTime.year(),
                dueDateTime.month(),
                dueDateTime.day()
            );

            Task t = new Task();
            t.RecordTypeId = TaskRecordTypeId;
            t.WhatId = recordId;
            t.OwnerId = ownerId;
            t.Subject = Constants.TASK_CALL_SUBJECT + ' - ' + name + ' - ' + appendSubject;
            t.ActivityDate = dueDate;
            t.CurrentTaskSLA__c = dueDateTime;
            t.Status = Constants.TASK_STATUS_OPEN;
            t.System_Created__c = true;
            t.Created_DateTime__c = System.now();
            t.NextTaskMilestone__c = 1; // Always 1

            tasksToInsert.add(t);
        }

        if (!tasksToInsert.isEmpty()) {
            Database.insert(tasksToInsert, false);
        }

        if (!tasksToInsert.isEmpty()) {
            sendTaskNotifications(tasksToInsert, owerQueue);
        }
    }
    
     public static void sendTaskNotifications(List<Task> taskList, string ownerQueue) {

    // Get Notification Type
  /*  CustomNotificationType notifType = [
        SELECT Id 
        FROM CustomNotificationType 
        WHERE DeveloperName = 'Default_SR_SLA' 
        LIMIT 1
    ];
*/
    List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
         List<String> emailsString=new List<String>();
         if(taskList.size()>0 && ownerQueue!=null){
             for(GroupMember gm: [Select Id, UserOrGroup.Email from GroupMember where groupId=:ownerQueue]){
               emailsString.add(gm.UserOrGroup.Email);  
             }             
         }

    for (Task t : taskList) {

     /*   // 🔔 Bell Notification
        Messaging.CustomNotification notification = new Messaging.CustomNotification();
        notification.setTitle('New Call Task Assigned');
        notification.setBody('Call task created: ' + t.Subject);
        notification.setNotificationTypeId(notifType.Id);
        notification.setTargetId(t.Id);

        notification.send(new Set<String>{ t.OwnerId });*/

        //  Email
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        if(emailsString.size()>0)
        mail.setToaddresses(emailsString);
        else
        mail.setTargetObjectId(t.OwnerId);
        mail.setSaveAsActivity(false);
        mail.setSubject('New Call Task Assigned');
        mail.setPlainTextBody(
            'Hello,\n\n' +
            'A new call task has been assigned to you.\n\n' +
            'Subject: ' + t.Subject + '\n' +
            'Due Date: ' + t.ActivityDate + '\n\n' +
            'Please review and complete the task on or before the due date.\n\n' +
    'Thank you.\n' +
    'Modon Service Team'
        );

        emails.add(mail);
    }

    if (!emails.isEmpty() && !Test.isRunningTest()) {
       // Messaging.sendEmail(emails);
    }
}
    
    
}