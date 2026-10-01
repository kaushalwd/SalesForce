/**********************************************************************************************************************
* Name               : SalesExecMeetingReminderBatch                                                        
* Description        : Batch job to process open tasks related to Sales Executive Meetings with a reminder date of today and send emails to task owners.
* Usage              : Executed via scheduler or manually
* Created By         : Rushi Patel - Horizontal Digital                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Rushi Patel                 03 Sep 2026     Initial draft 
******************************************************************************************************************/
public class SalesExecMeetingReminderBatch implements Database.Batchable<sObject> {

    public Database.QueryLocator start(Database.BatchableContext BC) {
        String query = 'SELECT Id, Subject, Description, OwnerId, WhatId, ActivityDate ' +
                       'FROM Task ' +
                       'WHERE IsClosed = FALSE ' +
                       'AND ActivityDate = TODAY ' +
                       'AND WhatId != null';
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext BC, List<Task> scope) {
        if (scope == null || scope.isEmpty()) return;
        
        // 1. FILTER TASKS IN APEX (Avoids polymorphic SOQL limits)
        String meetingPrefix = Sales_Executive_Meeting__c.sObjectType.getDescribe().getKeyPrefix();
        List<Task> meetingTasks = new List<Task>();
        for (Task t : scope) {
            if (String.valueOf(t.WhatId).startsWith(meetingPrefix)) {
                meetingTasks.add(t);
            }
        }
        
        if (meetingTasks.isEmpty()) return;

        // QUERY ORG WIDE EMAIL ONCE PER BATCH CHUNK
        Id orgWideEmailId = null;
        OrgWideEmailAddress[] owea = [SELECT Id FROM OrgWideEmailAddress WHERE DisplayName = 'Modon Real Estate' LIMIT 1];
        if (!owea.isEmpty()) {
            orgWideEmailId = owea[0].Id;
        }

        // PRE-FETCH USERS TO AVOID POLYMORPHIC OWNER ERRORS AND GROUPS
        Set<Id> ownerIds = new Set<Id>();
        for (Task t : meetingTasks) {
            if (t.OwnerId != null && String.valueOf(t.OwnerId).startsWith('005')) {
                ownerIds.add(t.OwnerId);
            }
        }
        
        Map<Id, User> userMap = new Map<Id, User>();
        if (!ownerIds.isEmpty()) {
            userMap = new Map<Id, User>([SELECT Id, Email, Name FROM User WHERE Id IN :ownerIds AND IsActive = true]);
        }

        List<Messaging.SingleEmailMessage> emailsToSend = new List<Messaging.SingleEmailMessage>();

        for (Task t : meetingTasks) {
            // ONLY PROCESS IF OWNER IS AN ACTIVE USER
            if (userMap.containsKey(t.OwnerId)) {
                User taskOwner = userMap.get(t.OwnerId);
                String toAddress = taskOwner.Email;
                
                if (String.isNotBlank(toAddress)) {
                    Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
                    email.setToAddresses(new String[] { toAddress });
                    
                    if (orgWideEmailId != null) {
                        email.setOrgWideEmailAddressId(orgWideEmailId);
                    }
                    
                    String taskSubject = String.isNotBlank(t.Subject) ? t.Subject : 'Meeting Follow Up';
                    email.setSubject('Reminder: ' + taskSubject);
                    
                    // BUILD THE HTML BODY
                    String body = 'Hello ' + taskOwner.Name + ',<br/><br/>' +
                                  'This is an automated reminder for an open task related to a Sales Executive Meeting.<br/><br/>' +
                                  '<b>Subject:</b> ' + taskSubject + '<br/>' +
                                  '<b>Due Date:</b> ' + (t.ActivityDate != null ? t.ActivityDate.format() : 'Today') + '<br/>';
                                  
                    if (String.isNotBlank(t.Description)) {
                        body += '<b>Comments:</b> ' + t.Description + '<br/>';
                    }
                    
                    String recordLink = URL.getOrgDomainURL().toExternalForm() + '/' + t.Id;
                    body += '<br/>You can view the task here: <a href="' + recordLink + '">Click Here</a><br/><br/>' +
                            'Thanks,<br/>Salesforce System';
                            
                    email.setHtmlBody(body);
                    email.setSaveAsActivity(false); // Do not save as activity to avoid org setting constraints
                    
                    emailsToSend.add(email);
                }
            }
        }
        
        // SEND EMAILS SAFELY
        if (!emailsToSend.isEmpty()) {
            Messaging.SendEmailResult[] results = Messaging.sendEmail(emailsToSend, false);
            for (Integer i = 0; i < results.size(); i++) {
                if (!results[i].isSuccess()) {
                    System.debug('Email Failed for Task: ' + results[i].getErrors()[0].getMessage());
                }
            }
        }
    }

    public void finish(Database.BatchableContext BC) {
        // Optional completion logic
    }
}