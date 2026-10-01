/**********************************************************************************************************************
* Name               : ServiceRequestEmailDispatcher                                                         
* Created By         : Active Minds Middle East                                                      
* @author            : Raghu Gajjela
* @group             : 
* Created			 : 05 AUG 2025
* @last modified on  : 
* @last modified by  : Raghu Gajjela
******************************************************************************************************************/

public class ServiceRequestEmailDispatcher {
    
    public static void processTasks(List<Task> tasks, Map<Id, Task> oldMap, Boolean isInsert) {
        Set<Id> srIds = new Set<Id>();
        for (Task t : tasks) {
            if (t.WhatId != null && t.WhatId.getSObjectType() == ServiceRequest__c.SObjectType) {
                srIds.add(t.WhatId);
            }
        }
        
        // Single SOQL Query 
        //  Map<Id, ServiceRequest__c> srInfoMap = new Map<Id, ServiceRequest__c>([SELECT Id, RecordTypeName__c, HandoverSelectionMode__c FROM ServiceRequest__c WHERE Id IN :srIds]);
        Map<Id, ServiceRequest__c> srInfoMap = new Map<Id, ServiceRequest__c>();
        
        if (!srIds.isEmpty()) {
            srInfoMap = new Map<Id, ServiceRequest__c>([ SELECT Id, RecordTypeName__c, HandoverSelectionMode__c FROM ServiceRequest__c WHERE Id IN :srIds ]);
        } else if (Test.isRunningTest()) {
            return; // Do nothing for tests where no SR exists
        }
        
        
        Set<Id> srIdsCreated = new Set<Id>();
        system.debug('srIdsCreated========'+ srIdsCreated);
        Set<Id> srIdsRejected = new Set<Id>();
        system.debug('srIdsRejected========'+ srIdsRejected);
        
        Set<Id> srIdsBooking1 = new Set<Id>();
        system.debug('srIdsBooking1========'+ srIdsBooking1);
        Set<Id> srIdsBooking2 = new Set<Id>();
        system.debug('srIdsBooking2========'+ srIdsBooking2);
        Set<Id> srIdsFinalDoc = new Set<Id>();
        system.debug('srIdsFinalDoc========'+ srIdsFinalDoc);
        
        List<Task> sendCreatedTasks = new List<Task>();
        system.debug('sendCreatedTasks========'+ sendCreatedTasks);
        List<Task> sendRejectedTasks = new List<Task>();
        
        List<Task> booking1Tasks = new List<Task>(); // Task Order = 2
        system.debug('booking1Tasks========'+ booking1Tasks);
        List<Task> booking2Tasks = new List<Task>(); // Task Order = 7
        system.debug('booking2Tasks========'+ booking2Tasks);
        List<Task> finalDocumentTasks = new List<Task>(); // Task Order = 6
        system.debug('finalDocumentTasks========'+ finalDocumentTasks);
        
        // ServiceRequest__c sr = [SELECT Id, RecordTypeName__c, HandoverSelectionMode__c FROM ServiceRequest__c WHERE Id = :t.WhatId LIMIT 1];
        for (Task t : tasks) {
            if (t.WhatId == null || t.WhatId.getSObjectType() != ServiceRequest__c.SObjectType) continue;
            
            ServiceRequest__c sr = srInfoMap.get(t.WhatId);
            if (sr == null) continue;
            
            if (isInsert && t.Order__c == 1) {
                sendCreatedTasks.add(t);
                srIdsCreated.add(t.WhatId);
            }
            else if (!isInsert && oldMap != null) {
                Task oldT = oldMap.get(t.Id);
                if (oldT == null) continue;
                if (t.Status == 'Closed' && t.KYC_Status__c == 'Rejected') {
                    sendRejectedTasks.add(t);
                    srIdsRejected.add(t.WhatId);
                }
            }
            
            
            if (!isInsert && t.Order__c == 2 && t.Status == 'Closed') {
                booking1Tasks.add(t);// first booking of unit handover
                srIdsBooking1.add(t.WhatId);
            }
            
            if (!isInsert && t.Order__c == 7 && t.Status == 'Closed' && sr.HandoverSelectionMode__c == 'Direct Vistit to office') {
                booking2Tasks.add(t);// Booking #2 — Task Order = 7 AND Direct Visit to Office
                srIdsBooking2.add(t.WhatId);
            }
            
            if (!isInsert && t.Order__c == 6 && t.Status == 'Closed') {
                finalDocumentTasks.add(t); // Final Document — Task Order = 6 and Closed
                srIdsFinalDoc.add(t.WhatId);
            }
            
        }
        if (!srIdsCreated.isEmpty()) {
            sendEmails(sendCreatedTasks, srIdsCreated, 'CEMAIL_SR_CREATED');
        }
        
        if (!srIdsRejected.isEmpty()) {sendEmails(sendRejectedTasks, srIdsRejected, 'CEMAIL_SR_REJECTED');}
        if (!srIdsBooking1.isEmpty()) {sendEmails(booking1Tasks, srIdsBooking1, 'CEMAIL_SR_BOOKING1');}
        if (!srIdsBooking2.isEmpty()) {sendEmails(booking2Tasks, srIdsBooking2, 'CEMAIL_SR_BOOKING2');}
        if (!srIdsFinalDoc.isEmpty()) {sendEmails(finalDocumentTasks, srIdsFinalDoc, 'CEMAIL_SR_FINALDOC');}
        
    }
    private static void sendEmails(List<Task> taskList, Set<Id> srIds, String templatePrefix) {
        if (taskList.isEmpty()) return;
        Id personRecTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();
        // checking salesorder Entity 
        Map<Id, ServiceRequest__c> srMap = new Map<Id, ServiceRequest__c>([SELECT Id, RecordTypeName__c,SalesOrder__c,SalesOrder__r.CustomerAccount__r.PersonEmail,SalesOrder__r.Source_Entity__c,
                                                                           SalesOrder__r.CustomerAccount__r.RecordTypeId,SalesOrder__r.PrimaryContact__r.Email FROM ServiceRequest__c WHERE Id IN :srIds
                                                                           and SalesOrder__r.Source_Entity__c != 'Modon - Egypt' and RecordType.Name <> :Constants.SERVICE_REQUEST_Default_SR]);
        List<String> templateKeys = new List<String>();
        system.debug('templateKeys======='+ templateKeys);
        for (ServiceRequest__c sr : srMap.values()) {
            templateKeys.add(templatePrefix + '_' + sr.RecordTypeName__c);
        }
        Map<String, Id> templateMap = new Map<String, Id>();
        system.debug('templateMap======='+ templateMap);
        for (EmailTemplate e : [SELECT Id, Name FROM EmailTemplate WHERE Name IN :templateKeys]) {
            templateMap.put(e.Name, e.Id);
        }
        
        for (Task t : taskList) {
            ServiceRequest__c sr = srMap.get(t.WhatId);
            if (sr == null) continue;
            String templateName = templatePrefix + '_' + sr.RecordTypeName__c;
            if (!templateMap.containsKey(templateName)) continue;
            system.debug('templateName======='+ templateName);
            String recipient = sr.SalesOrder__r.CustomerAccount__r.RecordTypeId == personRecTypeId ? sr.SalesOrder__r.CustomerAccount__r.PersonEmail : sr.SalesOrder__r.PrimaryContact__r.Email;
            system.debug('recipient======='+ recipient);
            if (String.isBlank(recipient)) continue;
            Messaging.SingleEmailMessage rendered = Messaging.renderStoredEmailTemplate(templateMap.get(templateName), sr.SalesOrder__c, sr.Id);
            String subject = rendered.getSubject();
            String body = rendered.getHtmlBody().replace('\n', '').replace('"', '\\"');
            String personalization = '[{"to": [{"email": "' + recipient + '"}]}]';
            List<Id> attachmentIds = new List<Id>();
            
            List<Documents__c> deedDocs = [SELECT Id FROM Documents__c WHERE Name = 'Title Deed' AND Service_Request__c = :sr.Id LIMIT 1];
            if (!deedDocs.isEmpty()) {
                List<ContentDocumentLink> cdl = [ SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId = :deedDocs[0].Id LIMIT 1];
                if (!cdl.isEmpty()) {
                    ContentVersion cv = [SELECT Id FROM ContentVersion WHERE ContentDocumentId = :cdl[0].ContentDocumentId ORDER BY VersionNumber DESC LIMIT 1 ];
                    attachmentIds.add(cv.Id);
                }
            }
            
            
            if (!Test.isRunningTest()) {
                system.debug('Method Entry Test=======');
                
                SendGridNotificationUtility.sendEmail(null,null,templateName,recipient,'noreply@modon.com','MODON Sales Team',null,null,'Service Request Created','Customer Management',
                                                      null,attachmentIds.isEmpty() ? null : attachmentIds,sr.Id);
            }
        }
    }
    
}