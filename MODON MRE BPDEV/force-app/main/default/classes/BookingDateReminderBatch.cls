global class BookingDateReminderBatch implements Database.Batchable<SObject>,Schedulable {
    global void execute(SchedulableContext sc) {
        Database.executeBatch(new BookingDateReminderBatch(), 1);
    }
    global Database.QueryLocator start(Database.BatchableContext bc) {
        List<String> cancellStatus = System.label.CommissionCancelStatus.contains(',')?System.label.CommissionCancelStatus.split(','):new List<String>{System.label.CommissionCancelStatus};

        return Database.getQueryLocator([
            SELECT Id, Name, OwnerId, Owner.Email,Owner.Name, Booking_Date__c,Unit_Launch_Date__c,Unit__r.Name
            FROM SalesOrder__c WHERE (Booking_Date__c = NULL OR Unit_Launch_Date__c = NULL) AND (Status__c NOT IN: cancellStatus)
        ]);
    }
    
    global void execute(Database.BatchableContext bc, List<SObject> scope) {
        List<SalesOrder__c> rows = (List<SalesOrder__c>) scope;
        Map<Id, List<SalesOrder__c>> ownerToSOs = new Map<Id, List<SalesOrder__c>>();
        Map<Id,String> userNameMap = new Map<Id,String>();
        for (SalesOrder__c so : rows) {
            userNameMap.put(so.OwnerId,so.Owner.Name);
            
            if (!ownerToSOs.containsKey(so.OwnerId)) ownerToSOs.put(so.OwnerId, new List<SalesOrder__c>());
            ownerToSOs.get(so.OwnerId).add(so);
        }
        
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        Datetime sendDt = Datetime.now();
        String FOLLOWUP_SUBJECT = 'Follow-up: Booking Date and Unit Launch Date missing!';
        if (ownerToSOs == null || ownerToSOs.isEmpty()) return;

        // Collect all SalesOrder Ids to check existing tasks
        Set<Id> allSoIds = new Set<Id>();
        Set<Id> ownerIds = new Set<Id>();
        for (Id ownerId : ownerToSOs.keySet()) {
            ownerIds.add(ownerId);
            for (SalesOrder__c so : ownerToSOs.get(ownerId)) {
                if (so.Id != null) allSoIds.add(so.Id);
            }
        }
        if (allSoIds.isEmpty()) return;

        // Query existing open follow-up tasks for these Sales Orders to prevent duplicates
        List<Task> existingTasks = [
            SELECT Id, WhatId, OwnerId, Status, Subject
            FROM Task
            WHERE WhatId IN :allSoIds
              AND Subject = :FOLLOWUP_SUBJECT
              AND (Status NOT IN ('Completed','Closed'))
        ];

        // Build a map WhatId -> set of existing task Ids (we just need to know existence)
        Map<Id, List<Task>> soIdToExistingTasks = new Map<Id, List<Task>>();
        for (Task t : existingTasks) {
            if (!soIdToExistingTasks.containsKey(t.WhatId)) soIdToExistingTasks.put(t.WhatId, new List<Task>());
            soIdToExistingTasks.get(t.WhatId).add(t);
        }

        // Prepare new tasks to insert (only for SOs with no existing open follow-up)
        List<Task> tasksToInsert = new List<Task>();
        // Also prepare a map OwnerId -> List<SalesOrder__c> (cleaned) for email sending
        Map<Id, List<SalesOrder__c>> emailOwnerMap = new Map<Id, List<SalesOrder__c>>();

        Date today = Date.today();

        for (Id ownerId : ownerToSOs.keySet()) {
            List<SalesOrder__c> listSo = ownerToSOs.get(ownerId);
            if (listSo == null || listSo.isEmpty()) continue;

            for (SalesOrder__c so : listSo) {
                // Skip if existing open follow-up task exists for this SO
                if (soIdToExistingTasks.containsKey(so.Id)) {
                    // existing open task found; skip creating a new one
                } else {
                    // create a follow-up task
                    Task t = new Task();
                    t.Subject = FOLLOWUP_SUBJECT;
                    t.WhatId = so.Id;
                    t.OwnerId = (ownerId == null) ? UserInfo.getUserId() : ownerId;
                    t.ActivityDate = today; // due today
                    t.Status = 'Open';
                    t.Priority = 'High';
                    t.SkipValidation__c = true;
                    t.Description = 'Automated follow-up: Booking Date and Unit Launch Date missing. Please update these fields to enable correct commission calculation.';
                    tasksToInsert.add(t);
                }

                if (!emailOwnerMap.containsKey(ownerId)) emailOwnerMap.put(ownerId, new List<SalesOrder__c>());
                emailOwnerMap.get(ownerId).add(so);
            }
        }

        if (!tasksToInsert.isEmpty()) {
            try {
                insert tasksToInsert;
            } catch (DmlException de) {
                System.debug('BookingReminderProcessor: Task insert failed: ' + de.getMessage());
            }
        }

        
        for (Id ownerId : ownerToSOs.keySet()) {
            List<SalesOrder__c> listSo = ownerToSOs.get(ownerId);
            String ownerEmail = listSo[0].Owner.Email;
            if (String.isBlank(ownerEmail)) continue; // skip if no email
            
            String fragment = BookingDateRemindEmailHelper.buildMinimalFragmentHtml(listSo);
            String plain  = BookingDateRemindEmailHelper.buildMinimalPlainText(listSo);
            
            String templateHtml = [SELECT Id,HtmlValue FROM EmailTemplate WHERE Name = 'CommissionMissingDateReminder' LIMIT 1].HtmlValue;
            String htmlBody = templateHtml.replace('<!--BODY_PLACEHOLDER-->', fragment);//
            htmlBody = htmlBody.replace('{OWNER_NAME}', userNameMap.get(ownerId));
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new String[]{ ownerEmail });
            mail.setSubject('Critical Reminder: MissingDates May Affect Commission Processing - Booking Date / Unit Launch Date (' + listSo.size() + ')');
            mail.setHtmlBody(htmlBody);
            mail.setPlainTextBody(plain);
            emails.add(mail);
        }
        
        // Send email(s) in one call
        if (!emails.isEmpty()) {
            try {
                Messaging.sendEmail(emails);
            } catch (Exception ex) {
                // optional: log to custom object or platform event
                System.debug('BookingDateReminder - email send failed: ' + ex);
            }
        }
    }
    
    global void finish(Database.BatchableContext bc) {
        // optional: send summary to admins or create log record
    }
}