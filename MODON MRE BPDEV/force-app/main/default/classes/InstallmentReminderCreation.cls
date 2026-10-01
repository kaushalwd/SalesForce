/**********************************************************************************************************************
* Name               : InstallmentReminderCreation                                                        
* Description        : This batch class is used for sending EMail and update reminder set date on SOI
* Usage              : This batch class is used for sending EMail and update reminder set date on SOI
* Created By         : Active Minds Global Solutions Pvt Ltd                                                     
* ---------------------------------------------------------------------------------------------------------------------
* Version       Author                                      Date            Comment                                                                       
* 1.0			raghu.gajjela@activemindsit.com 			15 Dec 2025		This batch class is used for sending EMail and update reminder set date on SOI
* 2.0			Raghu Gajjela@activemindsit.com				07 May 2025		Modifiled to handle bulk uppdate.
***********************************************************************************************************************/
global without sharing class InstallmentReminderCreation 
implements Database.Batchable<sObject>, Database.AllowsCallouts {

    public Set<Id> InstallmentIds = new Set<Id>();
    public List<PaymentRemindersTemplates__mdt> prMetaList = new List<PaymentRemindersTemplates__mdt>();

    public InstallmentReminderCreation(){
        InstallmentIds = new Set<Id>();
    }

    public InstallmentReminderCreation(Set<Id> installmentRecIds){
        InstallmentIds = installmentRecIds;
    }

    global Database.QueryLocator start(Database.BatchableContext BC){

      String query = Label.InstallmentReminderBaseQuery; // Query

        if(InstallmentIds.size() > 0){

            String instIdsString = '';

            for(Id inId : InstallmentIds){

                instIdsString = instIdsString != ''? instIdsString + ',' + '\'' + inId + '\'' : '\'' + inId + '\'';
            }

            query += ' AND Id IN (' + instIdsString + ')';
        }

        Set<String> projectNames = new Set<String>();
        Set<String> reminderTypes = new Set<String>();

        prMetaList = [SELECT Id,EmailTemplateName__c,FromAddress__c,Is_Include_Joint_Owner__c,ProjectSetting__c,ReminderType__c,
                   ProjectSetting__r.MasterLabel FROM PaymentRemindersTemplates__mdt WHERE ProjectSetting__c != null AND ReminderType__c != null];

        for(PaymentRemindersTemplates__mdt pmt : prMetaList){

            projectNames.add(pmt.ProjectSetting__r.MasterLabel);

            reminderTypes.add(pmt.ReminderType__c);
        }

        query +=' AND ReminderType__c IN :reminderTypes ' +' AND SalesOrder__r.Unit__r.Project_Name__c IN :projectNames ' +' ORDER BY ReminderDueDate__c DESC';

        return Database.getQueryLocator(query);
    }

    global void execute(Database.BatchableContext BC,List<SalesOrderInstallments__c> scope) {

        try {

            if(scope.isEmpty()) return;

            Set<String> projectNames = new Set<String>();
            Set<String> reminderTypes = new Set<String>();
            Set<Id> soIds = new Set<Id>();

            for(SalesOrderInstallments__c so : scope){

                if(so.SalesOrder__r.Unit__r.Project_Name__c != null){
                    projectNames.add(so.SalesOrder__r.Unit__r.Project_Name__c);
                }

                if(so.ReminderType__c != null){
                    reminderTypes.add(so.ReminderType__c);
                }

                if(so.SalesOrder__c != null){
                    soIds.add(so.SalesOrder__c);
                }
            }

            // Active SRs
            Map<Id, ServiceRequest__c> openCancellationSRs = new Map<Id, ServiceRequest__c>();

            Id ucUpdateRecordTypeId =Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType,'DefaultUnitCancellation');

            Id defaultUpdateRecordTypeId = Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType,'Default_SR');

            for(ServiceRequest__c sr : [SELECT Id, SalesOrder__c FROM ServiceRequest__c
                WHERE ( RecordTypeId = :ucUpdateRecordTypeId OR RecordTypeId = :defaultUpdateRecordTypeId)
                AND SalesOrder__c IN :soIds AND Status__c != 'Cancelled'AND Status__c != 'Closed']){
                openCancellationSRs.put(sr.SalesOrder__c, sr);
            }

            // Metadata map
            Map<String, PaymentRemindersTemplates__mdt> metaMap = new Map<String, PaymentRemindersTemplates__mdt>();

            for(PaymentRemindersTemplates__mdt pmt : [SELECT Id,EmailTemplateName__c,FromAddress__c,ReminderType__c,
                       ProjectSetting__r.MasterLabel FROM PaymentRemindersTemplates__mdt
                WHERE ProjectSetting__r.MasterLabel IN :projectNames AND ReminderType__c IN :reminderTypes]){

                String key = pmt.ProjectSetting__r.MasterLabel +'-' + pmt.ReminderType__c;

                metaMap.put(key, pmt);
            }

            // Create reminders
            List<PaymentReminder__c> remindersToInsert = new List<PaymentReminder__c>();

            for(SalesOrderInstallments__c inst : scope){

                String key = inst.SalesOrder__r.Unit__r.Project_Name__c +'-' + inst.ReminderType__c;

                if(!metaMap.containsKey(key)) continue;

                if(openCancellationSRs.containsKey(inst.SalesOrder__c)){
                    continue;
                }

                remindersToInsert.add(getPaymentReminder(inst,inst.ReminderType__c,metaMap.get(key)));
            }

            if(remindersToInsert.isEmpty()){
                return;
            }

            insert remindersToInsert;

            List<PaymentReminder__c> reminders = [SELECT Id,ReminderType__c,From_Address__c,ToAddress__c,SalesOrderInstallment__c,
                       SalesOrderInstallment__r.SalesOrder__r.Unit__r.Project_Name__c,SalesOrderInstallment__r.SalesOrder__r.PrimaryContact__c
                FROM PaymentReminder__c WHERE Id IN :remindersToInsert ];

            // Preload Email Templates
            Set<String> templateNames = new Set<String>();

            for(PaymentRemindersTemplates__mdt meta : metaMap.values()){
                templateNames.add(meta.EmailTemplateName__c);
            }

            Map<String, Id> templateMap = new Map<String, Id>();

            for(EmailTemplate et : [SELECT Id, DeveloperName FROM EmailTemplate WHERE DeveloperName IN :templateNames]){
                templateMap.put( et.DeveloperName,et.Id);
            }

            // Bulk email logs
            List<EmailMessage> emailLogs = new List<EmailMessage>();

            List<SendGridQueueable.EmailRequest> emailRequests = new List<SendGridQueueable.EmailRequest>();

            Id targetId;

            for(PaymentReminder__c pr : reminders){

                String key = pr.SalesOrderInstallment__r.SalesOrder__r.Unit__r.Project_Name__c+ '-' +pr.ReminderType__c;

                PaymentRemindersTemplates__mdt meta = metaMap.get(key);

                String renderedHtml;

                try {

                    Id templateId = templateMap.get(meta.EmailTemplateName__c);

                    if(pr.SalesOrderInstallment__r.SalesOrder__r.PrimaryContact__c != null){

                        targetId = pr.SalesOrderInstallment__r.SalesOrder__r.PrimaryContact__c;

                    } else {

                        targetId = UserInfo.getUserId();
                    }

                    Messaging.SingleEmailMessage dummyEmail = Messaging.renderStoredEmailTemplate(templateId,targetId,pr.Id);

                    renderedHtml = dummyEmail.getHtmlBody();

                } catch(Exception e){

                    renderedHtml ='Error rendering template: ' + e.getMessage();
                }

                emailLogs.add(new EmailMessage(
                    Subject ='Payment Reminder - ' + pr.ReminderType__c,
                    HtmlBody = renderedHtml,
                    ToAddress = pr.ToAddress__c,
                    FromAddress = pr.From_Address__c,
                    RelatedToId = pr.Id,
                    Status = '3'
                ));
            }

            if(!emailLogs.isEmpty()){
                insert emailLogs;
            }
            
            MAP<ID,emailMessage>  emailMessageMap=new  MAP<ID,emailMessage>();
            for (EmailMessage emailMessage:emailLogs){
                emailMessageMap.put(emailMessage.RelatedToId,emailMessage);   
            }

            // Build queue requests
            for(PaymentReminder__c pr : reminders){

               // PaymentReminder__c pr = reminders[i];

                String key = pr.SalesOrderInstallment__r.SalesOrder__r.Unit__r.Project_Name__c + '-' + pr.ReminderType__c;

                PaymentRemindersTemplates__mdt meta = metaMap.get(key);

                emailRequests.add(new SendGridQueueable.EmailRequest(pr.Id,meta.EmailTemplateName__c,pr.ToAddress__c,pr.ReminderType__c,emailMessageMap.get(pr.ID).ID));
            }

            // ONE queueable only
            if(!emailRequests.isEmpty()){

                System.enqueueJob(new SendGridQueueable(emailRequests));
            }

            // Update reminder flags
            List<PaymentReminder__c> updateList = new List<PaymentReminder__c>();

            for(PaymentReminder__c pr : reminders){

                updateList.add(new PaymentReminder__c( Id = pr.Id, IsEmailDelivered__c = true));
            }

            if(!updateList.isEmpty()){
                update updateList;
            }

            updateInstallmentReminderSentDates(reminders);

        } catch(Exception ex){

            LoggerService.save(
                LoggerService.createApexLog(ex, 'InstallmentReminderCreation','InstallmentReminderCreation','execute')
            );
        }
    }

    public void execute(SchedulableContext SC){

        Database.executeBatch(
            new InstallmentReminderCreation(),
            50
        );
    }

    global void finish(Database.BatchableContext BC){}

       public static PaymentReminder__c getPaymentReminder(SalesOrderInstallments__c relatedInstallment, string reminderType,PaymentRemindersTemplates__mdt prRecordMeta){
        PaymentReminder__c reminder = new PaymentReminder__c();
        reminder.SalesOrderInstallment__c = relatedInstallment.Id;
        reminder.ReminderType__c = reminderType;
        reminder.Installment_Amount__c = relatedInstallment.InstallmentAmount__c;
        reminder.DueDate__c = relatedInstallment.ReminderDueDate__c;
        reminder.SentDate__c = system.now();
        reminder.ToAddress__c = relatedInstallment.SalesOrder__r.CustomerAccount__r.PersonEmail != null 
            ? relatedInstallment.SalesOrder__r.CustomerAccount__r.PersonEmail : relatedInstallment.SalesOrder__r.PrimaryContact__r.Email;
        
        reminder.From_Address__c = prRecordMeta.FromAddress__c;
        string reminderName = relatedInstallment.SalesOrder__r.Name+' - ';
        reminderName  += relatedInstallment.MilestoneDescription__c != null ? relatedInstallment.MilestoneDescription__c : relatedInstallment.SPAINFRA__c;
        reminderName  += ' - '+reminderType;
        reminder.Name = reminderName.length() >80 ? reminderName.substring(0, 79) : reminderName;
        //IsEmailDelivered__c , ErrorReason__c 
        return reminder;
    }

    public static void updateInstallmentReminderSentDates( List<PaymentReminder__c> paymentReminders){

        Map<Id, SalesOrderInstallments__c> updateMap =new Map<Id, SalesOrderInstallments__c>();

        DateTime sentDate = System.now();

        for(PaymentReminder__c pr : paymentReminders){

            if(pr.SalesOrderInstallment__c == null){
                continue;
            }

            Id instId = pr.SalesOrderInstallment__c;

            if(!updateMap.containsKey(instId)){

                updateMap.put(instId,new SalesOrderInstallments__c( Id = instId));
            }

            SalesOrderInstallments__c inst = updateMap.get(instId);

            String rt = pr.ReminderType__c;

            if(rt == '30 days Prior'){
                inst.Reminder_1_Sent__c = sentDate;
            }
            else if(rt == '15 Days Prior'){
                inst.Reminder_2_Sent__c = sentDate;
            }
            else if(rt == '7 Days Prior'){
                inst.Reminder_3_Sent__c = sentDate;
            }
            else if(rt == '1 Day Prior'){
                inst.Reminder_4_Sent__c = sentDate;
            }
        }

        if(!updateMap.isEmpty()){
            update updateMap.values();
        }
    }
}