/**********************************************************************************************************************
* Name               : KYCDocusignAbandonmentBatchJob                                                        
* Description        : Batch job to process abandoned KYC applications and send reminder emails
* Usage              : Executed via KYCDocusignAbandonmentBatchScheduler or manually
* Created By         : Rushi Patel - Horizontal Digital                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Rushi Patel                 14 Aug 2026     Initial draft 
******************************************************************************************************************/
public class KYCDocusignAbandonmentBatchJob implements Database.Batchable<sObject>, Database.AllowsCallouts {

    public Database.QueryLocator start(Database.BatchableContext BC) {
        // Fetch custom metadata for configurable batch settings
        KYC_Batch_Setting__mdt settings = KYC_Batch_Setting__mdt.getInstance('Default');
        
        Boolean isActive = (settings != null && settings.Is_Active__c != null) ? settings.Is_Active__c : true;
        if (!isActive && !Test.isRunningTest()) {
            return Database.getQueryLocator('SELECT Id FROM KYC_Response__c LIMIT 0');
        }
        
        Integer delayMinutes = (settings != null && settings.Delay_Minutes__c != null) ? Integer.valueOf(settings.Delay_Minutes__c) : 15;
        Datetime cutoffDate = (settings != null && settings.Cutoff_Date__c != null) ? settings.Cutoff_Date__c : Datetime.newInstanceGmt(2026, 8, 20, 0, 0, 0);
        String validSignzyStatus = (settings != null && String.isNotBlank(settings.Valid_Signzy_Status__c)) ? settings.Valid_Signzy_Status__c : 'COMPLETED';
        String excludedJourneyStatus = (settings != null && String.isNotBlank(settings.Excluded_Journey_Status__c)) ? settings.Excluded_Journey_Status__c : 'KYC Data Submitted - Signing Session Starting';
        
        Datetime delayTime = Datetime.now().addMinutes(-delayMinutes);
        String timeFilter = Test.isRunningTest() ? '' : 'AND LastModifiedDate < :delayTime ';
        
        String query = 'SELECT Id, Resume_Link__c, Contact__c, Contact__r.Email, Contact__r.KYC_Site_Link__c, Contact__r.ContactEncryptID__c, Customer__c, Customer__r.PersonEmail, Customer__r.PersonContactId, Customer__r.KYC_Site_Link__pc, Customer__r.AccountID_EncryptedId__c, ' +
                       'OwnerId, Owner.Email, ExpCloud_Reminder_Sent__c, Journey_Status__c, LastModifiedDate, CreatedDate ' +
                       'FROM KYC_Response__c ' +
                       'WHERE Signzy_Journey_Status__c = :validSignzyStatus ' +
                       'AND Journey_Status__c != null AND Journey_Status__c != :excludedJourneyStatus ' +
                       'AND CreatedDate >= :cutoffDate ' +
                       timeFilter +
                       'AND ExpCloud_Reminder_Sent__c = false ';
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext BC, List<KYC_Response__c> scope) {
        
        // QUERY ORG WIDE EMAIL ONCE PER BATCH CHUNK
        Id orgWideEmailId = null;
        OrgWideEmailAddress[] owea = [SELECT Id FROM OrgWideEmailAddress WHERE DisplayName = 'Modon Real Estate' LIMIT 1];
        if (!owea.isEmpty()) {
            orgWideEmailId = owea[0].Id;
        }

        // QUERY EMAIL TEMPLATE ONCE PER BATCH CHUNK
        Id emailTemplateId = null;
        EmailTemplate[] template = [SELECT Id FROM EmailTemplate WHERE DeveloperName = 'KYC_Abandonment_Template' LIMIT 1];
        if (!template.isEmpty()) {
            emailTemplateId = template[0].Id;
        }

        Set<Id> targetIds = new Set<Id>();
        for (KYC_Response__c kyc : scope) {
            Id matchId = kyc.Contact__c != null ? kyc.Contact__c : kyc.Customer__c;
            if (matchId != null) {
                targetIds.add(matchId);
            }
        }

        if (targetIds.isEmpty()) return;

        // SOQL 1: DEDUPLICATION
        Map<Id, Id> parentToLatestKycId = new Map<Id, Id>();
        for(KYC_Response__c kyc : [SELECT Id, Contact__c, Customer__c FROM KYC_Response__c WHERE (Contact__c IN :targetIds OR Customer__c IN :targetIds) AND CreatedDate = LAST_N_DAYS:30 ORDER BY CreatedDate DESC]) {
            Id parentId = kyc.Contact__c != null ? kyc.Contact__c : kyc.Customer__c;
            if (!parentToLatestKycId.containsKey(parentId)) {
                parentToLatestKycId.put(parentId, kyc.Id);
            }
        }

        List<KYC_Response__c> kycToUpdate = new List<KYC_Response__c>();
        List<KYC_Response__c> linksToUpdate = new List<KYC_Response__c>();
        
        // PRE-POPULATE Resume_Link__c FIRST SO THE EMAIL TEMPLATE ENGINE CAN MERGE IT
        for (KYC_Response__c kyc : scope) {
            Id matchId = kyc.Contact__c != null ? kyc.Contact__c : kyc.Customer__c;
            if (parentToLatestKycId.get(matchId) != kyc.Id) {
                continue; // Skip deduplicated ones, handled in the next loop
            }

            String siteLink = kyc.Contact__c != null ? kyc.Contact__r.KYC_Site_Link__c : kyc.Customer__r.KYC_Site_Link__pc;
            if (String.isBlank(kyc.Resume_Link__c) && String.isNotBlank(siteLink)) {
                String encryptedId = kyc.Contact__c != null ? kyc.Contact__r.ContactEncryptID__c : kyc.Customer__r.AccountID_EncryptedId__c;
                kyc.Resume_Link__c = siteLink + encryptedId;
                linksToUpdate.add(kyc);
            }
        }
        
        // Push links to database immediately so renderStoredEmailTemplate pulls the correct values
        if (!linksToUpdate.isEmpty()) {
            update linksToUpdate;
        }

        List<Messaging.SingleEmailMessage> emailsToSend = new List<Messaging.SingleEmailMessage>();
        Map<Integer, KYC_Response__c> emailIndexToKyc = new Map<Integer, KYC_Response__c>();

        for (KYC_Response__c kyc : scope) {
            Id matchId = kyc.Contact__c != null ? kyc.Contact__c : kyc.Customer__c;
            
            if (parentToLatestKycId.get(matchId) != kyc.Id) {
                kyc.ExpCloud_Reminder_Sent__c = true;
                kycToUpdate.add(kyc);
                continue;
            }

            // EXPERIENCE CLOUD REMINDER
            String toAddress = kyc.Contact__c != null ? kyc.Contact__r.Email : kyc.Customer__r.PersonEmail;
            String ccAddress = kyc.Owner.Email;
            Id targetContactId = kyc.Contact__c != null ? kyc.Contact__c : kyc.Customer__r.PersonContactId;
            
            if (String.isNotBlank(toAddress) && targetContactId != null && emailTemplateId != null && String.isNotBlank(kyc.Resume_Link__c)) {
                
                Messaging.SingleEmailMessage email = Messaging.renderStoredEmailTemplate(emailTemplateId, targetContactId, kyc.Id);
                
                // Override target recipient to ensure we explicitly send to the toAddress with CC support
                email.setTreatTargetObjectAsRecipient(false);
                email.setToAddresses(new String[] { toAddress });

                if (orgWideEmailId != null) {
                    email.setOrgWideEmailAddressId(orgWideEmailId);
                }
                
                if (String.isNotBlank(ccAddress)) {
                    email.setCcAddresses(new String[] { ccAddress });
                }
                
                email.setSaveAsActivity(false); // Do not save as activity to avoid org setting constraints
                
                emailsToSend.add(email);
                emailIndexToKyc.put(emailsToSend.size() - 1, kyc);
            } else {
                kyc.ExpCloud_Reminder_Sent__c = true;
                kycToUpdate.add(kyc);
            }
        }
        
        // Send emails and only update KYC records if the email was successfully sent
        if (!emailsToSend.isEmpty()) {
            Messaging.SendEmailResult[] results = Messaging.sendEmail(emailsToSend, false);
            for (Integer i = 0; i < results.size(); i++) {
                if (results[i].isSuccess()) {
                    KYC_Response__c successfulKyc = emailIndexToKyc.get(i);
                    successfulKyc.ExpCloud_Reminder_Sent__c = true;
                    kycToUpdate.add(successfulKyc);
                } else {
                    System.debug('Email Failed for KYC Id ' + emailIndexToKyc.get(i).Id + ': ' + results[i].getErrors()[0].getMessage());
                }
            }
        }
        
        if (!kycToUpdate.isEmpty()) {
            update kycToUpdate;
        }
    }

    public void finish(Database.BatchableContext BC) {
    }
}