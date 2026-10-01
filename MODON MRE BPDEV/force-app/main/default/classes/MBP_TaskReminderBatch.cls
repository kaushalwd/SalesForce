/* Version       Author                          Date            Comment                                                                      
* 1.0           sanath.manohar@activemindsit.com    19 Dec 2023      Initial Draft(Communication Record Creation,Approvalprocess,emailsending)      
  1.1           raghu.chilukuri@activemindsit.com    08/03/26         Template Change
  1.2           sanath.manohar@activemindsit.com    11/03/36         template Verify and code refinement
  1.3           raghu.chilukuri@activemindsit.com   14/04/26         Updated and add cc from custom label
  1.4           raghu.chilukuri@activemindsit.com  21/04/26         Added Bcc and NO_DATA Logic for The cc and Bcc emails 
  1.5           Upendra.Aasam@activemindsit.com    30/04/26         Added Schedualble to the class
**********************************************************************************************
*/
 
global class MBP_TaskReminderBatch
    implements Database.Batchable<sObject>, Database.Stateful,Schedulable, Database.AllowsCallouts { //1.5

    global final String query;

    Map<Id, List<Task>> tasksByOwner = new Map<Id, List<Task>>();
    Map<Id, String> userEmails = new Map<Id, String>();
    Map<Id, Set<Id>> queueToUsersMap = new Map<Id, Set<Id>>();

/**
* @description Initializes the batch class and builds the dynamic SOQL query
*              to fetch open task reminders for broker registration service requests.
*/

    global MBP_TaskReminderBatch() {

        System.debug('=== MBP_TaskReminderBatch CONSTRUCTOR START ===');

        String completed = 'Closed';

        List<String> subjectList = new List<String>{
            BRConstants.SERVICE_REQUEST_TASK1,
            BRConstants.SERVICE_REQUEST_TASK2,
            BRConstants.SERVICE_REQUEST_TASK3,
            BRConstants.SERVICE_REQUEST_TASK4,
            BRConstants.SERVICE_REQUEST_TASK5
        };

        String subjectListString = '';
        for (Integer i = 0; i < subjectList.size(); i++) {
            subjectListString += '\'' + String.escapeSingleQuotes(subjectList[i]) + '\'';
            if (i < subjectList.size() - 1) subjectListString += ', ';
        }

        query =
            'SELECT Id, Subject, ActivityDate, Broker_Registration_Status__c, OwnerId, WhatId, Status ' +
            'FROM Task ' +
            'WHERE Status != \'' + completed + '\' ' +
            'AND ActivityDate != NULL ' +
            'AND Subject IN (' + subjectListString + ')';

        System.debug('Batch Query => ' + query);
    }
        
/**
* @description Starts the batch execution and returns the query locator
*              for the task records to be processed.
*/

    global Database.QueryLocator start(Database.BatchableContext bc) {
        System.debug('=== BATCH START CALLED ===');
        return Database.getQueryLocator(query);
    }

/**
 * @description Processes task reminder records, evaluates reminder conditions,
 *              closes expired tasks/service requests where applicable,
 *              resolves owner email addresses, and sends reminder emails.
*/

    global void execute(Database.BatchableContext bc, List<Task> scope) {

        System.debug('=== EXECUTE START ===');
        System.debug('Scope Size => ' + scope.size());

        tasksByOwner.clear();
        userEmails.clear();
        queueToUsersMap.clear();

        Set<Id> whatIds = new Set<Id>();

        for (Task t : scope) {
            System.debug('Processing Task => ' + t.Id + ' Subject=' + t.Subject +
                         ' DueDate=' + t.ActivityDate + ' Owner=' + t.OwnerId);

            if (t.WhatId != null &&
                t.WhatId.getSObjectType() == ServiceRequest__c.SObjectType) {
                whatIds.add(t.WhatId);
            }
        }

        System.debug('Collected SR Ids => ' + whatIds);

        Map<Id, ServiceRequest__c> srMap = new Map<Id, ServiceRequest__c>([
            SELECT Id, Name, Fast_Track__c, Status__c
            FROM ServiceRequest__c
            WHERE Id IN :whatIds
            AND RecordTypeName__c = 'Broker Registration'
        ]);

        System.debug('Fetched SR Map => ' + srMap);

        /* ---- TASK PROCESSING ---- */

        for (Task t : scope) {

            if (!tasksByOwner.containsKey(t.OwnerId)) {
                tasksByOwner.put(t.OwnerId, new List<Task>());
            }

            if (t.WhatId != null && srMap.containsKey(t.WhatId)) {
                ServiceRequest__c sr = srMap.get(t.WhatId);

                System.debug('SR Found for Task => ' + sr.Name +
                             ' FastTrack=' + sr.Fast_Track__c);

                if (sr.Fast_Track__c && t.ActivityDate.addDays(7) <= Date.today()) {
                    System.debug('Fast Track Expired. Closing Task + SR');
                    sr.Fast_Track__c = false;
                    t.Status = 'Closed';
                    update new List<SObject>{ sr, t };
                    continue;
                }
            }

            Integer daysDue = Date.today().daysBetween(t.ActivityDate);
            System.debug('Days Due Calculation => ' + daysDue);

            if (t.Subject == BRConstants.SERVICE_REQUEST_TASK2) {

                System.debug('TASK2 evaluation');

                if (daysDue == 1 || daysDue == 15 || daysDue == 29) {
                    System.debug('Reminder condition met for TASK2');
                    tasksByOwner.get(t.OwnerId).add(t);
                } else if (daysDue <= 0) {
                    System.debug('TASK2 exceeded 30 days. Closing.');
                    t.Status = 'Closed';
                    t.Broker_Registration_Status__c = 'Voided';
                    if (srMap.containsKey(t.WhatId)) {
                        srMap.get(t.WhatId).Status__c = 'Closed';
                        update srMap.get(t.WhatId);
                    }
                    update t;
                }

            } else if (t.Subject == BRConstants.SERVICE_REQUEST_TASK4) {

                System.debug('TASK4 evaluation');

                if (daysDue == 1 || daysDue == 7 || daysDue == 14) {
                    System.debug('Reminder condition met for TASK4');
                    tasksByOwner.get(t.OwnerId).add(t);
                } else if (daysDue <= 0) {
                    System.debug('TASK4 exceeded 15 days. Closing.');
                    t.Status = 'Closed';
                    t.Broker_Registration_Status__c = 'Voided';
                    if (srMap.containsKey(t.WhatId)) {
                        srMap.get(t.WhatId).Status__c = 'Closed';
                        update srMap.get(t.WhatId);
                    }
                    update t;
                }

            } else if (
                t.Subject == BRConstants.SERVICE_REQUEST_TASK1 ||
                t.Subject == BRConstants.SERVICE_REQUEST_TASK3 ||
                t.Subject == BRConstants.SERVICE_REQUEST_TASK5
            ) {
                if (t.ActivityDate < Date.today()) {
                    System.debug('Overdue task added for reminder');
                    tasksByOwner.get(t.OwnerId).add(t);
                }
            }
        }

        System.debug('Tasks grouped by Owner => ' + tasksByOwner);

        /* ---- OWNER EMAIL RESOLUTION ---- */

        List<Id> queueIds = new List<Id>();
        Map<Id,User> userMap = new Map<Id,User>();
		List<User> userList = [SELECT Id, Email FROM User WHERE Id IN: tasksByOwner.keySet()];
        for(User us: userList){
            userMap.put(us.Id, us);  
        }
        for (Id ownerId : tasksByOwner.keySet()) {
            System.debug('Resolving Owner => ' + ownerId);
            if (String.valueOf(ownerId).startsWith('005')) {
                User u = userMap.get(ownerId);
                System.debug('User Email Found => ' + u.Email);
                if (!String.isBlank(u.Email)) userEmails.put(ownerId, u.Email);

            } else if (String.valueOf(ownerId).startsWith('00G')) {
                System.debug('Queue Owner detected');
                queueIds.add(ownerId);
            }
        }

        if (!queueIds.isEmpty()) {

            System.debug('Fetching Queue Members => ' + queueIds);

            for (GroupMember gm : [
                SELECT GroupId, UserOrGroupId
                FROM GroupMember
                WHERE GroupId IN :queueIds
            ]) {

                System.debug('Queue Member => ' + gm);

                if (String.valueOf(gm.UserOrGroupId).startsWith('005')) {
                    if (!queueToUsersMap.containsKey(gm.GroupId)) {
                        queueToUsersMap.put(gm.GroupId, new Set<Id>());
                    }
                    queueToUsersMap.get(gm.GroupId).add(gm.UserOrGroupId);
                }
            }

            System.debug('Queue → Users Map => ' + queueToUsersMap);

            Set<Id> allQueueUsers = new Set<Id>();
            for (Set<Id> s : queueToUsersMap.values()) {
                allQueueUsers.addAll(s);
            }

            for (User u : [
                SELECT Id, Email FROM User WHERE Id IN :allQueueUsers
            ]) {
                System.debug('Queue User Email => ' + u.Email);
                if (!String.isBlank(u.Email)) userEmails.put(u.Id, u.Email);
            }
        }

        /* ---- EMAIL SENDING ---- */

        for (Id ownerId : tasksByOwner.keySet()) {

            List<Task> ownerTasks = tasksByOwner.get(ownerId);

            System.debug('Preparing email for Owner => ' + ownerId +
                         ' TaskCount=' + ownerTasks.size());

            if (ownerTasks.isEmpty()) continue;

            if (String.valueOf(ownerId).startsWith('00G')) {
                for (Id uid : queueToUsersMap.get(ownerId)) {
                    System.debug('Sending Queue Email to => ' + userEmails.get(uid));
                    sendEmail(userEmails.get(uid), ownerTasks, srMap);
                }
            } else {
                System.debug('Sending Email to User => ' + userEmails.get(ownerId));
                sendEmail(userEmails.get(ownerId), ownerTasks, srMap);
            }
        }

        System.debug('=== EXECUTE END ===');
    }

/**
 * @description Builds and sends reminder email content based on task type,
 *              due date, and related service request details.
 * @param toEmail Recipient email address.
 * @param tasks List of task records for which reminder email needs to be sent.
 * @param srMap Map of related ServiceRequest__c records keyed by Id.
*/

    private void sendEmail(String toEmail, List<Task> tasks, Map<Id, ServiceRequest__c> srMap) {

        System.debug('sendEmail() called for => ' + toEmail);

        if (String.isBlank(toEmail)) {
            System.debug('Email skipped — blank address');
            return;
        }

        Set<String> reminderMessages = new Set<String>();
        Map<String, List<Task>> tasksBySR = new Map<String, List<Task>>();
		String emailSubject = 'Reminder: Pending Tasks on Service Requests';
        String taskEmailBody;  
        String emailBody; 
        for (Task t : tasks){
            Integer daysDue = Date.today().daysBetween(t.ActivityDate);
            System.debug('Email Task Evaluation => ' + t.Id + ' DaysDue=' + daysDue);

            if (t.Subject == BRConstants.SERVICE_REQUEST_TASK2 && t.Broker_Registration_Status__c != 'Completed') {
                if (daysDue == 1){
                    reminderMessages.add('<p><b>Final Reminder: Pending Tasks due</b></p>');
                	emailSubject = 'Final Reminder: Pending Tasks due';
                    taskEmailBody = getEmailBody('Partner','today', BRConstants.SERVICE_REQUEST_TASK2);
                }else if (daysDue == 15){
                    reminderMessages.add('<p><b>Reminder: Pending Tasks due in 15 Days</b></p>');
                	emailSubject = 'Reminder: Pending Tasks due in 15 Days';
                    taskEmailBody = getEmailBody('Partner','in 15 days', BRConstants.SERVICE_REQUEST_TASK2);
                }else if (daysDue == 29){
                    reminderMessages.add('<p><b>Pending Tasks Reminder</b></p>');
                    emailSubject = 'Pending Tasks Reminder';
                    taskEmailBody = getEmailBody('Partner','in 29 days', BRConstants.SERVICE_REQUEST_TASK2);
                }
            }

            if (t.Subject == BRConstants.SERVICE_REQUEST_TASK4 && t.Broker_Registration_Status__c != 'Signed') {
                if (daysDue == 1){
                    reminderMessages.add('<p><b>Final Reminder: Signature Due Today</b></p>');
                    emailSubject = 'Final Reminder: Signature Due Today';
                    taskEmailBody = getEmailBody('Partner','today', BRConstants.SERVICE_REQUEST_TASK4);
                }
                else if (daysDue == 7){
                    reminderMessages.add('<p><b>Reminder: Signature pending in 7 Days</b></p>');
                    emailSubject = 'Reminder: Signature pending in 7 Days';
                    taskEmailBody = getEmailBody('Partner','7 days', BRConstants.SERVICE_REQUEST_TASK4);
                }
                else if (daysDue == 14){
                    reminderMessages.add('<p><b>Signature Pending</b></p>');
                    emailSubject = 'Signature Pending';
                    taskEmailBody = getEmailBody('Partner','14 days', BRConstants.SERVICE_REQUEST_TASK4);
                }
            }

          /*  if ((t.Subject == BRConstants.SERVICE_REQUEST_TASK1 ||
                 t.Subject == BRConstants.SERVICE_REQUEST_TASK3 ||
                 t.Subject == BRConstants.SERVICE_REQUEST_TASK5)
                && t.ActivityDate < Date.today()) {
                    taskEmailBody = '<p><b>Dear Broker Sales Admin:</b> Overdue tasks exist.</p>';
                reminderMessages.add(
                    '<p><b>Dear Broker Sales Admin:</b> Overdue tasks exist.</p>'
                );
                    emailBody +=
                        '<table border="1" cellpadding="5">' +
                        '<tr><th>Subject</th><th>Due Date</th><th>SR</th></tr>'; 
            } */

            String srName = 'N/A';
            if (t.WhatId != null && srMap.containsKey(t.WhatId)) {
                srName = srMap.get(t.WhatId).Name;
            }

            if (!tasksBySR.containsKey(srName)) {
                tasksBySR.put(srName, new List<Task>());
            }
            tasksBySR.get(srName).add(t);
        }

        System.debug('Reminder Messages => ' + reminderMessages);
        System.debug('Tasks grouped by SR => ' + tasksBySR.keySet());

         emailBody = taskEmailBody;
           // '<h3>Pending Tasks Reminder</h3>' +
           // String.join(new List<String>(reminderMessages), '');

                               
                               
                            /*   for (String srName : tasksBySR.keySet()) {
                                   for (Task t : tasksBySR.get(srName)) {
                                       if(t.Subject == BRConstants.SERVICE_REQUEST_TASK1 ||
                                          t.Subject == BRConstants.SERVICE_REQUEST_TASK3 ||
                                          t.Subject == BRConstants.SERVICE_REQUEST_TASK5){
                                              emailBody +=
                                                  '<tr><td>' + t.Subject + '</td>' +
                                                  '<td>' + t.ActivityDate + '</td>' +
                                                  '<td>' + srName + '</td></tr>';
                                          }
                                   }
                               } 
                               
                               emailBody += '</table>'; */
        system.debug('emailBody::'+emailBody);
        if(emailBody != ''&& emailBody != null){
            system.debug('emailBody::'+emailBody);
            String finalBody = MBP_ModonEmailUtilityClass.getFullEmailHtml(emailBody);
            System.debug('Final Email Body Prepared');

             /*Update version 1.4
            @description : Added cc and bcc NO_DATA logic
            */
            String ccJson = '';
            String ccLabel = Label.MBP_BatchEmailsCc;

            if (ccLabel != null && !ccLabel.contains('NO_DATA') && !String.isBlank(ccLabel)) {
                ccJson = '"cc":[{"email":"' + ccLabel.replace(',', '"},{"email":"') + '"}],';
            }

            String bccJson = '';
            String bccLabel = Label.MBP_BatchEmailsBCc;

            if (bccLabel != null && !bccLabel.contains('NO_DATA') && !String.isBlank(bccLabel)) {
                bccJson = '"bcc":[{"email":"' + bccLabel.replace(',', '"},{"email":"') + '"}],';
            }
            
            /*Update version 1.3
            @description : added cc emails using a Custom label To the Personalizations
            */
            String personalization =
                '[{' + '"to":[{"email":"' + toEmail + '"}],' + ccJson + bccJson + '"subject":"' + emailSubject + '"' + '}]';
            //Update version 1.4 Ends Here
            
            System.debug('Calling SendGrid Email');
            
            BP_SendGridUtilityClass.sendEmail(
                personalization,
                'Al Naseem',
                emailSubject,
                finalBody,
                false
            );
            
            System.debug('Email Sent Successfully');
        }
    }

    global void finish(Database.BatchableContext bc) {
        System.debug('=== BATCH FINISH ===');
    }
        
        /**
         * @description Generates the email body HTML for task reminder notifications
         *              based on agent name, remaining days, and task type.
         * @param agentName Name of the recipient or recipient role.
         * @param remainingDays Remaining due period text to display in the email.
         * @param taskName Name of the task used to determine message content.
         * @return HTML formatted email body string.
         */
  
        
        public static string getEmailBody(String agentName, String remainingDays, String taskName){
            
            /*Update 1.1*/
            String wrapperStart =
                '<tr>' +
                '  <td style="padding:20px 30px 10px 30px;' +
                '             font-family:Arial, sans-serif;' +
                '             font-size:16px;' +
                '             line-height:20px;' +
                '             color:#000000;">';
            
            String wrapperEnd =
                '  </td>' +
                '</tr>';
            
            String introLine;
            
            if (taskName == BRConstants.SERVICE_REQUEST_TASK4) {
                introLine =
                    '<p style="margin:0;">Dear ' + agentName + ',</p><br/>' +
                    '<p style="margin:0;">We would like to remind you that signature is pending for completion within ' + remainingDays + '.</p><br/>';
            } else {
                introLine =
                    '<p style="margin:0;">Dear ' + agentName + ',</p><br/>' +
                    '<p style="margin:0;">We would like to remind you that there are tasks pending and due for completion ' + remainingDays + '.</p><br/>';
            }
            
            String htmlBody =
                wrapperStart +
                introLine +
                '<p style="margin:0;">We strongly encourage you to complete the pending tasks, otherwise the request will be closed.</p><br/>' +
                '<p style="margin:0;">If you have already initiated the update process, please disregard this message.</p><br/>' +
                '<p style="margin:0;">Should you have any questions or require further assistance, please contact us on 800 MODON (800 66366) or email ' +
                '<a href="mailto:broker@modon.com">broker@modon.com</a>.</p>' +
                wrapperEnd;
            
            return htmlBody;
        }
        
        /*update 1.1 Ends*/
        
        // 🔹 Scheduler entry point //1.5
global void execute(SchedulableContext sc) {

    Database.executeBatch(new MBP_TaskReminderBatch(), 200);
}
}