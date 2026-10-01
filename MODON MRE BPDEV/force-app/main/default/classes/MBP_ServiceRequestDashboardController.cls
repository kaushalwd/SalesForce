public with sharing class MBP_ServiceRequestDashboardController {

    public static Id TASK_RT_ID = Schema.SObjectType.Task
        .getRecordTypeInfosByDeveloperName()
        .get('Service_Request')
        .getRecordTypeId();

    public class SRWrapper {
        @AuraEnabled public Id srId;
        @AuraEnabled public String srNumber;
        @AuraEnabled public String recordTypeName;
        @AuraEnabled public String status;
        @AuraEnabled public String srUrl;

        // Current active task (whatever step the SR is sitting at right now)
        @AuraEnabled public String activeTaskSubject;
        @AuraEnabled public String activeTaskStatus;       // Task.Status
        @AuraEnabled public String activeBrStatus;          // Broker_Registration_Status__c
        @AuraEnabled public String activeTaskOwner;

        // Who closed the "Require more information" task, and when
        @AuraEnabled public String rmiClosedByName;
        @AuraEnabled public Datetime rmiClosedDate;

        // Comments from the ORIGINAL (first / oldest) closed "Assignment of Broker Manager" task
        @AuraEnabled public String brManagerComments;
        @AuraEnabled public Datetime brManagerClosedDate;
        @AuraEnabled public String brManagerClosedByName;
    }

    @AuraEnabled(cacheable=true)
    public static List<SRWrapper> getServiceRequests() {

        List<SRWrapper> result = new List<SRWrapper>();

        // Step 1: SRs whose "Require more information" task is Closed
        // Also capture who closed it + when (OwnerId = who "had" the task / worked & closed it)
        Set<Id> requireInfoClosedSRIds = new Set<Id>();
        Map<Id, Task> srToRmiTask = new Map<Id, Task>();

        for (Task t : [
            SELECT WhatId, Owner.Name, LastModifiedDate, CompletedDateTime, CreatedDate
            FROM Task
            WHERE Subject = 'Require more information'
            AND Status = 'Closed'
            AND WhatId != null
            AND RecordTypeId = :TASK_RT_ID
            ORDER BY CreatedDate DESC
        ]) {
            requireInfoClosedSRIds.add(t.WhatId);
            // Most recent RMI closure wins per SR
            if (!srToRmiTask.containsKey(t.WhatId)) {
                srToRmiTask.put(t.WhatId, t);
            }
        }

        if (requireInfoClosedSRIds.isEmpty()) {
            return result;
        }

        // Step 2: SRs whose current task is ACTIVE (not Closed) — whatever step they're on now
        Set<Id> activeSRIds = new Set<Id>();
        Map<Id, Task> srToActiveTask = new Map<Id, Task>();

        for (Task t : [
            SELECT WhatId, Subject, Status, Broker_Registration_Status__c, Owner.Name, CreatedDate
            FROM Task
            WHERE Status != 'Closed'
            AND WhatId != null
            AND RecordTypeId = :TASK_RT_ID
            AND WhatId IN :requireInfoClosedSRIds
            ORDER BY CreatedDate DESC
        ]) {
            if (!activeSRIds.contains(t.WhatId)) {
                activeSRIds.add(t.WhatId);
                srToActiveTask.put(t.WhatId, t);
            }
        }

        // Step 3: Intersect — SRs that both had a closed RMI cycle AND currently have an active task
        requireInfoClosedSRIds.retainAll(activeSRIds);

        if (requireInfoClosedSRIds.isEmpty()) {
            return result;
        }

        // Step 4: Fetch the ORIGINAL (oldest) closed "Assignment of Broker Manager" task —
        // this is where the reviewer's original comments live
        Map<Id, Task> srToOriginalBrTask = new Map<Id, Task>();

        for (Task t : [
            SELECT WhatId, Comments__c, Owner.Name, LastModifiedDate, CompletedDateTime, CreatedDate
            FROM Task
            WHERE Subject = 'Assignment of Broker Manager'
            AND Status = 'Closed'
            AND WhatId IN :requireInfoClosedSRIds
            AND RecordTypeId = :TASK_RT_ID
            ORDER BY CreatedDate ASC
        ]) {
            // First (oldest) one wins — the original task before the RMI cycle
            if (!srToOriginalBrTask.containsKey(t.WhatId)) {
                srToOriginalBrTask.put(t.WhatId, t);
            }
        }

        // Step 5: Pull the actual Service Request records
        List<ServiceRequest__c> matchingSRs = [
            SELECT Id, Name, RecordType.Name, Status__c
            FROM ServiceRequest__c
            WHERE Id IN :requireInfoClosedSRIds
            ORDER BY CreatedDate DESC
        ];

        String baseUrl = URL.getOrgDomainUrl().toExternalForm();

        // Step 6: Assemble
        for (ServiceRequest__c sr : matchingSRs) {
            SRWrapper w = new SRWrapper();
            w.srId = sr.Id;
            w.srNumber = sr.Name;
            w.recordTypeName = sr.RecordType != null ? sr.RecordType.Name : '';
            w.status = sr.Status__c;
            w.srUrl = baseUrl + '/' + sr.Id;

            Task activeTask = srToActiveTask.get(sr.Id);
            if (activeTask != null) {
                w.activeTaskSubject = activeTask.Subject;
                w.activeTaskStatus = activeTask.Status;
                w.activeBrStatus = activeTask.Broker_Registration_Status__c;
                w.activeTaskOwner = activeTask.Owner != null ? activeTask.Owner.Name : null;
            }

            Task rmiTask = srToRmiTask.get(sr.Id);
            if (rmiTask != null) {
                w.rmiClosedByName = rmiTask.Owner != null ? rmiTask.Owner.Name : null;
                w.rmiClosedDate = rmiTask.CompletedDateTime != null
                    ? rmiTask.CompletedDateTime
                    : rmiTask.LastModifiedDate;
            }

            Task origBrTask = srToOriginalBrTask.get(sr.Id);
            if (origBrTask != null) {
                w.brManagerComments = origBrTask.Comments__c;
                w.brManagerClosedByName = origBrTask.Owner != null ? origBrTask.Owner.Name : null;
                w.brManagerClosedDate = origBrTask.CompletedDateTime != null
                    ? origBrTask.CompletedDateTime
                    : origBrTask.LastModifiedDate;
            }

            result.add(w);
        }

        return result;
    }
}