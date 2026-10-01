public without sharing class CaseReminderToOwnerQueueable implements Queueable, Database.AllowsCallouts {
    
    public static void execute(QueueableContext context) {
        system.debug('Queueable execute started...');
        
        Set<String> excludedEmails = new Set<String>();
        if (String.isNotBlank(System.Label.Queue_ContactCentreMembers)) {
            // Split the label value by comma
            List<String> emailList = System.Label.Queue_ContactCentreMembers.split(',');
            for (String email : emailList) {
                if (String.isNotBlank(email)) {
                    excludedEmails.add(email.trim().toLowerCase());
                }
            }
        }
        
        System.debug('Excluded Emails: ' + excludedEmails);
        
        List<CaseSLA__c> lstOpenSLA = [SELECT Id,Name,OwnerId,Owner.Name,Owner.Email,CaseId__r.CaseNumber,CaseId__r.New_Owner__r.Name,CaseId__r.Current_Owner_Name__c
                                       ,CaseId__r.Origin,CaseId__r.CaseCategory__c,CaseId__r.CaseSubCategory__c FROM CaseSLA__c WHERE CaseId__r.Origin = '800 Modon' 
                                       and CaseId__r.IsClosed = false and Status__c != 'Resolved' ];
        
        system.debug('Found SLAs: ' + lstOpenSLA.size());
        
        if (!lstOpenSLA.isEmpty()) 
        {
            String dayofweekToday = ((DateTime)date.today()).format('EEEE').trim().toLowerCase();
			System.debug('DayOfWeek Today: ' + dayofweekToday);
            String excludeReminderEmailDay = System.Label.Queue_ContactCentreMembers_ExcludeReminderEmailDay;
			excludeReminderEmailDay = excludeReminderEmailDay.trim().toLowerCase();
            System.debug('excludeReminderEmailDay: ' + excludeReminderEmailDay);
            for (CaseSLA__c sla : lstOpenSLA) 
            {
                if (sla.Owner != null && String.isNotBlank(sla.Owner.Email))
                {
                    String recipientEmail = sla.Owner.Email.toLowerCase();
                    //Do not send email to contact centre team on the configured exclusion days
                    if (excludedEmails.contains(recipientEmail) && excludeReminderEmailDay.contains(dayofweekToday)) 
                    {
                        System.debug('Skipping email sending to : ' + recipientEmail);
                        continue;
                    }
                    else
                    {
                        System.debug('Sending email to : ' + recipientEmail);
                    	SendGridNotificationUtility.sendEmail(null,null,'Case_Reminder_Email',recipientEmail,'noreply@modon.com','MODON Service Team',(sla.CaseId__r != null ? sla.CaseId__r.CaseCategory__c : null),(sla.CaseId__r != null ? sla.CaseId__r.CaseSubCategory__c : null),'Open Case Reminder Email','Customer Management',null,null,sla.Id);
                    }
                } 
                else 
                {
                    System.debug('No recipient email found for SLA: ' + sla.Id);
                }
            }
        }
    }
}