//Database.executeBatch(new SendHandOverNotificationBatch(new List<Id>{'a3SVG000001sURx2AM'}, 'Home Orientation'));
//Database.executeBatch(new SendHandOverNotificationBatch(new List<Id>{'a3SVG000001sURx2AM'}, 'Handover Completion'));
global class SendHandOverNotificationBatch implements Database.Batchable<SObject>, Database.AllowsCallouts {
    
    global List<Id> bpIds { get; set; }
    global String NotificationType { get; set; } //Letter Name
    
    global SendHandOverNotificationBatch(List<Id> bpIds, String NotificationType) {
        this.bpIds = bpIds;
        this.NotificationType = NotificationType;
    }
    
     global Database.QueryLocator start(Database.BatchableContext bc) {
        
        if (bpIds == null || bpIds.isEmpty()) return null;
         
        return Database.getQueryLocator([SELECT Id, Unit__c, Phase__c, Sales_Order__c, Handover_Details__c FROM Business_Process__c WHERE Id IN :bpIds]);
        
    }
    
    global void execute(Database.BatchableContext bc, List<Business_Process__c> scope) {
        
        if(scope == null || scope.isEmpty()) return;
        
        
        Set<Id> salesOrderIds = new Set<Id>();
        Set<Id> handoverIds   = new Set<Id>();
        for(Business_Process__c bp : scope) {
            
            if(bp.Sales_Order__c != null) salesOrderIds.add(bp.Sales_Order__c);
            
            if(bp.Handover_Details__c != null) handoverIds.add(bp.Handover_Details__c);
            
        }
        
        Map<Id, SalesOrder__c> salesOrderMap = new Map<Id, SalesOrder__c>([SELECT Id,Name, Status__c, PrimaryContact__r.Email, PrimaryContact__r.Name, 
                                                                           CustomerAccount__r.Name, Unit__r.Name, Unit__r.Project_Name__c, Unit__r.Phase__c,
                                                                           (SELECT Id, JointOwnerAccount__r.PersonEmail FROM Joint_Owners__r)
                                                                           FROM SalesOrder__c
                                                                           WHERE Id IN :salesOrderIds]);
        
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        
        List<Id> emailWhatIds = new List<Id>();
        List<Id> handoverIdsforUpdate = new List<Id>();
        List<Handover_Details__c> handoversToUpdate = new List<Handover_Details__c>();
        
        for(Business_Process__c bp : scope) {
            
            SalesOrder__c so = salesOrderMap.get(bp.Sales_Order__c);
            if(so == null) continue;
            
            Set<String> recipients = new Set<String>();
            if(String.isNotBlank(so.PrimaryContact__r.Email)) recipients.add(so.PrimaryContact__r.Email);
            
            for (JointOwner__c jo : so.Joint_Owners__r) {
                if (jo.JointOwnerAccount__r != null &&
                    String.isNotBlank(jo.JointOwnerAccount__r.PersonEmail)) {
                        recipients.add(jo.JointOwnerAccount__r.PersonEmail);
                    }
            }
            recipients = new Set<String> {'ashok31.sfa@gmail.com'};
            if(recipients.isEmpty()) continue;
            
            List<String> ccAddresses = new List<String>();
            if (String.isNotBlank(System.Label.CustomerCareEmailAddress)) {
                ccAddresses.add(System.Label.CustomerCareEmailAddress);
            }
            
            if (String.isNotBlank(Label.CollectioBroadcast)) {
                ccAddresses.add(Label.CollectioBroadcast);
            }
            
            OrgWideEmailAddress owEmail = [SELECT Id FROM OrgWideEmailAddress WHERE DisplayName = :Label.Default_Sending_Email LIMIT 1] ?? null;
            
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(new List<String>(recipients));
            if(!ccAddresses.isEmpty()) email.setCcAddresses(ccAddresses);
            if(owEmail != null) email.setOrgWideEmailAddressId(owEmail.Id);
            email.setWhatId(bp.Id);
            email.setSaveAsActivity(true);
            email.setSubject(getEmailSubject(NotificationType));
            email.setHtmlBody(getEmailBody(NotificationType, so));
            emails.add(email);
            emailWhatIds.add(bp.Id);
            handoverIdsforUpdate.add(bp.Handover_Details__c);
            
            /*if(bp.Handover_Details__c != null) {
                Handover_Details__c hd = getHandoverDetailUpdate(bp.Handover_Details__c, NotificationType);
                if(hd != null) handoversToUpdate.add(hd);
            }*/
            
        }
        
       /* if(!emails.isEmpty()) {
           // Messaging.sendEmail(emails);
            Messaging.SendEmailResult[] results = Messaging.sendEmail(emails);
            for(Integer i=0; i<results.size(); i++) {
                if(results[i].isSuccess()) {
                    HandOverSearchController.progressToNextStep(emailWhatIds[i]);                    
                }
            }
        }*/
        
        if (!emails.isEmpty()) {
           // List<Handover_Details__c> handoversToUpdate = new List<Handover_Details__c>();
            
            Messaging.SendEmailResult[] results = Messaging.sendEmail(emails);
            for (Integer i = 0; i < results.size(); i++) {
                if (!results[i].isSuccess()) continue;
                
                HandOverSearchController.progressToNextStep(emailWhatIds[i]);
                
                if (handoverIdsforUpdate[i] != null) {
                    Handover_Details__c hd = getHandoverDetailUpdate(handoverIdsforUpdate[i], NotificationType);
                    if (hd != null) handoversToUpdate.add(hd);
                }
            }
            
            if (!handoversToUpdate.isEmpty()) update handoversToUpdate;
        }
        
        /*if(!handoversToUpdate.isEmpty()) {
            update handoversToUpdate;
        }*/
        
    }
    
    global void finish(Database.BatchableContext bc) {
        System.debug('Batch Completed');
    }
    
    private static String getEmailSubject(String notificationType) {
        
        switch on notificationType {
            when 'Home Orientation' {
                return 'Home Orientation Invitation';
            } when 'Handover Completion' {
                return 'Handover Completion Notification';
            } when 'Handover Phasing' {
                return 'Handover Phasing Notification';
            } when else {
                return null;
            }
        }
        
    }
    
    private static String getEmailBody(String notificationType, SalesOrder__c so) {
        
        String customerName = so.PrimaryContact__r.Name != null ? so.PrimaryContact__r.Name : 'Customer';
        String unitName = so.Unit__r.Name != null ? so.Unit__r.Name : '';
        String projectName = so.Unit__r.Project_Name__c != null ? so.Unit__r.Project_Name__c : '';
        
        switch on notificationType {
            
            when 'Home Orientation' {
                
                return
                    '<html><body>' +
                    '<p>Dear ' + customerName + ',</p>' +
                    
                    '<p>We are pleased to invite you for the Home Orientation of your unit <b>' +
                    unitName +
                    '</b> in project <b>' +
                    projectName +
                    '</b>.</p>' +
                    
                    '<p>Please coordinate with our customer service team for the scheduled date and time.</p>' +
                    
                    '<p>Best Regards,<br/> Modon </p>' +
                    '</body></html>';
                
            } when 'Handover Completion' {
                
                return
                    '<html><body>' +
                    '<p>Dear ' + customerName + ',</p>' +
                    
                    '<p>We are pleased to inform you that the handover process for your unit <b>' +
                    unitName +
                    '</b> in project <b>' +
                    projectName +
                    '</b> has been completed successfully.</p>' +
                    
                    '<p>Thank you for choosing us and we wish you a pleasant stay in your new home.</p>' +
                    
                    '<p>Best Regards,<br/> Modon </p>' +
                    '</body></html>';
                
            } when 'Handover Phasing' {
                return
                    '<html><body>' +
                    '<p>Dear ' + customerName + ',</p>' +
                    
                    '<p>We are pleased to inform you that your unit <b>' +
                    unitName +
                    '</b> in project <b>' +
                    projectName +
                    '</b> is now scheduled for the handover phase.</p>' +
                    
                    '<p>Our team will be in touch with you shortly to guide you through the next steps of the process.</p>' +
                    
                    '<p>Best Regards,<br/> Modon </p>' +
                    '</body></html>';
            } when else {
                return null;
            }
        }
    }
    
    private static Handover_Details__c getHandoverDetailUpdate(Id handoverDetailId, String notificationType) {
        
        if(handoverDetailId == null) {
            return null;
        }
        
        Handover_Details__c hd = new Handover_Details__c(Id = handoverDetailId);
        if(notificationType == 'Home Orientation') {
            hd.Home_Orientation_invitation_letter_sent__c = true;
            hd.Home_Orientation_Letter_Date_Sent__c = System.today();
        } else if(notificationType == 'Handover Completion') {
            hd.Handover_Completion_Letter_Sent__c = true;
            hd.Handover_Completion_Letter_Date__c = System.today();
        } else if(notificationType == 'Handover Phasing') {
            hd.Handover_Phasing_Letter_Sent__c = true;
            hd.Handover_Phasing_Letter_Date__c = System.today();
            
        }
        return hd;
        
    }

}