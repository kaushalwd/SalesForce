global class TaskEscalationReminderBatch implements Database.Batchable<SObject>, Schedulable{

    private Id testTaskId;
    private static final String STATUS_COMPLETED = 'Completed';
    private static final String REMINDER1 = 'Reminder 1 Sent';
    private static final String REMINDER2 = 'Reminder 2 Sent';
    private static final String REMINDER3 = 'Reminder 3 Sent';
    
      public TaskEscalationReminderBatch(){

    }

    // Constructor for testing single Task
    public TaskEscalationReminderBatch(Id taskId)
    {
        this.testTaskId = taskId;
    }

    global Database.QueryLocator start(Database.BatchableContext bc)
    {
        DateTime nowTime = System.now();
        
          if(testTaskId != null) {
            return Database.getQueryLocator([ SELECT Id,Status, OwnerId, WhatId,Email_Template_Name__c,Escalation_1_Time__c,Escalation_2_Time__c,
                                             Escalation_3_Time__c,Reminder__c,Escalation_1_Email__c,Escalation_2_Email__c,Escalation_3_Email__c 
                                             FROM Task WHERE Id = :testTaskId]);
        }

        return Database.getQueryLocator([SELECT Id,Status,OwnerId,WhatId,Email_Template_Name__c,Escalation_1_Time__c,Escalation_2_Time__c,
                                         Escalation_3_Time__c,Reminder__c,Escalation_1_Email__c,Escalation_2_Email__c,Escalation_3_Email__c
                                         FROM Task WHERE Status != :STATUS_COMPLETED AND Email_Template_Name__c != NULL
            AND ((Escalation_1_Time__c <= :nowTime AND Reminder__c = NULL) OR 
                 (Escalation_2_Time__c <= :nowTime AND Reminder__c = :REMINDER1)OR 
                 (Escalation_3_Time__c <= :nowTime AND Reminder__c = :REMINDER2)) ]);
    }
global void execute(Database.BatchableContext bc, List<Task> scope)
{
    if(scope.isEmpty()) return;

    DateTime nowTime = System.now();

    /* -----------------------------
       Collect Template Names
    ----------------------------- */

    Set<String> templateNames = new Set<String>();

    for(Task t : scope)
    {
        if(!String.isBlank(t.Email_Template_Name__c))
            templateNames.add(t.Email_Template_Name__c);
    }

    /* -----------------------------
       Get Email Templates
    ----------------------------- */

    Map<String, Id> templateMap = new Map<String, Id>();

    if(!templateNames.isEmpty())
    {
        for(EmailTemplate et : [
            SELECT Id, DeveloperName, Name
            FROM EmailTemplate
            WHERE DeveloperName IN :templateNames
            OR Name IN :templateNames
        ])
        {
            templateMap.put(et.DeveloperName, et.Id);
            templateMap.put(et.Name, et.Id);
        }
    }

    /* -----------------------------
       Collect All Escalation Emails
    ----------------------------- */

    Set<String> allEmails = new Set<String>();

    for(Task t : scope)
    {
        if(t.Escalation_1_Email__c != null)
            allEmails.add(t.Escalation_1_Email__c);

        if(t.Escalation_2_Email__c != null)
            allEmails.add(t.Escalation_2_Email__c);

        if(t.Escalation_3_Email__c != null)
            allEmails.add(t.Escalation_3_Email__c);
    }

    /* -----------------------------
       Get Users by Email
    ----------------------------- */

    Map<String, User> userByEmail = new Map<String, User>();

    if(!allEmails.isEmpty())
    {
        for(User u : [
            SELECT Id, Email, Name
            FROM User
            WHERE Email IN :allEmails
            AND IsActive = true
        ])
        {
            userByEmail.put(u.Email, u);
        }
    }

    /* -----------------------------
       Get Org Wide Email
    ----------------------------- */

    Id orgWideEmailId;

    List<OrgWideEmailAddress> oweaList =
    [
        SELECT Id
        FROM OrgWideEmailAddress
        WHERE Address = 'noreply@modon.com'
        LIMIT 1
    ];

    if(!oweaList.isEmpty())
        orgWideEmailId = oweaList[0].Id;

    /* -----------------------------
       Prepare Email + Updates
    ----------------------------- */

    List<Task> tasksToUpdate = new List<Task>();

    List<Messaging.SingleEmailMessage> emailsToSend =
        new List<Messaging.SingleEmailMessage>();

    for(Task tsk : scope)
    {
        Boolean emailNeeded = false;

        String sendToEmail;

        /* -----------------------------
           Reminder 1
        ----------------------------- */

        if(
            tsk.Escalation_1_Time__c != null &&
            tsk.Escalation_1_Time__c <= nowTime &&
            tsk.Reminder__c == null
        )
        {
            sendToEmail = tsk.Escalation_1_Email__c;

            tsk.Reminder__c = 'Reminder 1 Sent';

            emailNeeded = true;
        }

        /* -----------------------------
           Reminder 2
        ----------------------------- */

        else if(
            tsk.Escalation_2_Time__c != null &&
            tsk.Escalation_2_Time__c <= nowTime &&
            tsk.Reminder__c == 'Reminder 1 Sent'
        )
        {
            sendToEmail = tsk.Escalation_2_Email__c;

            tsk.Reminder__c = 'Reminder 2 Sent';

            emailNeeded = true;
        }

        /* -----------------------------
           Reminder 3
        ----------------------------- */

        else if(
            tsk.Escalation_3_Time__c != null &&
            tsk.Escalation_3_Time__c <= nowTime &&
            tsk.Reminder__c == 'Reminder 2 Sent'
        )
        {
            sendToEmail = tsk.Escalation_3_Email__c;

            tsk.Reminder__c = 'Reminder 3 Sent';

            emailNeeded = true;
        }

        if(!emailNeeded)
            continue;

        if(String.isBlank(sendToEmail))
            continue;

        /* -----------------------------
           Get Template
        ----------------------------- */

        Id templateId =
            templateMap.get(tsk.Email_Template_Name__c);

        if(templateId == null)
            continue;

        /* -----------------------------
           Get User from Email
        ----------------------------- */

        User recipientUser = userByEmail.get(sendToEmail);

        if(recipientUser == null)
        {
            System.debug('User not found for email: ' +sendToEmail);
            continue;
        }

        /* -----------------------------
           Render Email Template
        ----------------------------- */

        Messaging.SingleEmailMessage mail = Messaging.renderStoredEmailTemplate(templateId, recipientUser.Id,tsk.Id);

        mail.setTargetObjectId( recipientUser.Id);

        mail.setToAddresses( new String[] { sendToEmail });

        mail.setSaveAsActivity(false);

        if(orgWideEmailId != null)
            mail.setOrgWideEmailAddressId(orgWideEmailId);

        emailsToSend.add(mail);

        tasksToUpdate.add(tsk);
    }

    /* -----------------------------
       Send Emails
    ----------------------------- */

    if(
        !emailsToSend.isEmpty() &&
        System.Label.EmailCheck == 'true' &&
        !Test.isRunningTest()
    )
    {
        Messaging.sendEmail(emailsToSend);
    }

    /* -----------------------------
       Update Tasks
    ----------------------------- */

    if(!tasksToUpdate.isEmpty())
    {
        update tasksToUpdate;
    }
}
    global void finish(Database.BatchableContext bc)
    {
        System.debug('Reminder Batch Completed');
    }

    global void execute(SchedulableContext sc){
        //Database.executeBatch(new TaskEscalationReminderBatch(),200);
    }
}