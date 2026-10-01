global class SendBCCLetterBatch implements Database.Batchable<SObject>, Database.AllowsCallouts {

    global List<Id> unitIds { get; set; }

    global SendBCCLetterBatch(List<Id> unitIds) {
        this.unitIds = unitIds;
    }

    global Database.QueryLocator start(Database.BatchableContext bc) {
        
        if (unitIds == null || unitIds.isEmpty()) return null;
        
        return Database.getQueryLocator([
            SELECT Id, Name, Status__c, PrimaryContact__r.Email, Unit__r.Name, Unit__r.Project_Name__c, CustomerAccount__r.Name, PrimaryContact__r.Name, Unit__r.Phase__c,
            (SELECT Id, JointOwnerAccount__r.PersonEmail FROM Joint_Owners__r)
            FROM SalesOrder__c
            WHERE Unit__c IN :unitIds
        ]);
        
    }

    global void execute(Database.BatchableContext bc, List<SalesOrder__c> scope) {
        
        if(scope == null || scope.isEmpty()) return;
                
        Set<Id> phaseIds = new Set<Id>();
        Map<Id, String> primaryEmailMap = new Map<Id, String>();
        Map<Id, List<String>> jointOwnerEmailMap = new Map<Id, List<String>>();
        
        // Collect Sales Order Details
        for (SalesOrder__c order : scope) {
            phaseIds.add(order.Unit__r.Phase__c);
            if (order.PrimaryContact__r != null) {
                primaryEmailMap.put(order.Id, order.PrimaryContact__r.Email);
            }
            List<String> joEmails = new List<String>();
            for (JointOwner__c jo : order.Joint_Owners__r) {
                if (jo.JointOwnerAccount__r != null &&
                    String.isNotBlank(jo.JointOwnerAccount__r.PersonEmail)) {
                        joEmails.add(jo.JointOwnerAccount__r.PersonEmail);
                    }
            }
            jointOwnerEmailMap.put(order.Id, joEmails);
        }
        
        // Fetch Default Documents
        Map<Id, ContentDocumentLink> phaseToCDLMap = new Map<Id, ContentDocumentLink>();
        for (ContentDocumentLink cdl : [
            SELECT ContentDocumentId, ContentDocument.Title, ContentDocument.LatestPublishedVersionId, LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :phaseIds
            AND ContentDocument.Title LIKE '%BCC Letter%'
            ORDER BY ContentDocument.CreatedDate DESC]) {
                if (!phaseToCDLMap.containsKey(cdl.LinkedEntityId)) {
                    phaseToCDLMap.put(cdl.LinkedEntityId, cdl);
                }
            }
        
        // Fetch Content Versions
        Set<Id> versionIds = new Set<Id>();
        for (ContentDocumentLink cdl : phaseToCDLMap.values()) {
            versionIds.add(cdl.ContentDocument.LatestPublishedVersionId);
        }
        
        Map<Id, ContentVersion> versionMap = new Map<Id, ContentVersion>();
        if (!versionIds.isEmpty()) {
            for (ContentVersion cv : [SELECT Id, Title, VersionData, FileExtension FROM ContentVersion WHERE Id IN :versionIds]) {
                versionMap.put(cv.Id, cv);
            }
        }
        
        OrgWideEmailAddress owEmail = [SELECT Id FROM OrgWideEmailAddress WHERE DisplayName = :Label.Default_Sending_Email LIMIT 1] ?? null;
        List<Messaging.SingleEmailMessage> allEmails = new List<Messaging.SingleEmailMessage>();
        
        // Process Emails
        for (SalesOrder__c salesOrderRec : scope) {
            
            ContentDocumentLink cdl = phaseToCDLMap.get(salesOrderRec.Unit__r.Phase__c);
            if (cdl == null) continue;
            
            ContentVersion cv = versionMap.get(cdl.ContentDocument.LatestPublishedVersionId);
            if (cv == null) continue;
            
            // Default Letter Attachment
            Messaging.EmailFileAttachment efa = new Messaging.EmailFileAttachment();
            efa.setFileName(cv.Title + '.' + cv.FileExtension);
            efa.setBody(cv.VersionData);
            efa.setContentType('application/pdf');
            
            List<Messaging.EmailFileAttachment> attachments = new List<Messaging.EmailFileAttachment>();
            attachments.add(efa);
            
            Boolean isTestFlag = Boolean.valueOf(Label.IsTest);
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            List<String> toAddresses = new List<String>();
            if (primaryEmailMap.containsKey(salesOrderRec.Id)) {
                if(!isTestFlag){
                    toAddresses.add(primaryEmailMap.get(salesOrderRec.Id));
                }else{
                    toAddresses.add(Label.TestEmail);
                }
            }
            
            toAddresses.addAll(jointOwnerEmailMap.get(salesOrderRec.Id));
            
            List<String> ccAddresses = new List<String>();
            if (String.isNotBlank(System.Label.CustomerCareEmailAddress)) {
                ccAddresses.add(System.Label.CustomerCareEmailAddress);
            }
            
            if (String.isNotBlank(Label.CollectioBroadcast)) {
                ccAddresses.add(Label.CollectioBroadcast);
            }
            
            email.setToAddresses(toAddresses);
            //email.setToAddresses(new List<String>{'ashok31.sfa@gmail.com'});
            email.setSubject('BCC Letter Notification');
            if (!ccAddresses.isEmpty()) {
                email.setCcAddresses(ccAddresses);
            }
            email.setHtmlBody(
                '<div style="font-size:10.5pt; font-family:Tahoma, sans-serif; line-height:1.6;">' +
                
                'Dear ' + salesOrderRec.PrimaryContact__r.Name + ',<br/><br/>' +
                
                'Please find attached the official notice regarding the updated anticipated completion date for your unit ' +
                salesOrderRec.Unit__r.Name +
                ' at Reem Hills.<br/><br/>' +
                
                'We sincerely appreciate your continued patience and understanding as we progress toward the successful completion and handover of the project.<br/><br/>' +
                
                'Should you have any questions, please do not hesitate to contact us through 800 MODON (800 66366) or ' +
                '<a href="mailto:customercare@modon.com">customercare@modon.com</a>.<br/><br/>' +
                
                'Best regards,<br/>' +
                'Modon' +
                
                '</div>'
            );
            
            if (owEmail != null) {
                email.setOrgWideEmailAddressId(owEmail.Id);
            }
            email.setWhatId(salesOrderRec.Id);
            email.setSaveAsActivity(true);
            email.setFileAttachments(attachments);
            allEmails.add(email);
        }

        // Send Emails ONCE
        if (!allEmails.isEmpty()) {
          //  Messaging.sendEmail(allEmails);
            Messaging.SendEmailResult[] results = Messaging.sendEmail(allEmails);
            for(Integer i=0; i<results.size(); i++) {
                if(results[i].isSuccess()) {
                    BCCController.createBusinessProcess(scope[0].Id);                    
                }
            }
        }
        
    }


    global void finish(Database.BatchableContext bc) {
        System.debug('Batch Completed');
    }
    
}