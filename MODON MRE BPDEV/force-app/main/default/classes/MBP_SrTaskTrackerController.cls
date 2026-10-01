/**********************************************************************************************************************
* Name               : MBP_SrTaskTrackerController
* Description        : Apex controller for the mbpSrTaskTracker LWC.
*                      Lists Tasks on Broker Registration Service Requests with:
*                        - Subject filters (Assignment of Broker Manager, Require more information,
*                          Validation by Compliance Team, Send for Signature, Validation by Broker Sales Admin)
*                        - A separate "Resubmitted" filter: an "Assignment of Broker Manager" task created AFTER a
*                          closed "Require more information" task on the same SR (customer resubmitted).
*                        - Search (SR number, Registration number, Broker Agency, Assigned To, Updated By)
*                        - Task status + SR status filters, server-side sorting and pagination
*                        - Per-filter counts for the filter pills
* Usage              : Called imperatively from LWC mbpSrTaskTracker (getTasks).
* Created By         : Upendra Reddy
* --------------------------------------------------------------------------------------------------------------------
* Version     Author                          Date             Comment
* 1.0         upendra.asam@modon.com           28 Sep 2026      Initial version.
**********************************************************************************************************************/
public with sharing class MBP_SrTaskTrackerController {

    // ---- Constants -------------------------------------------------------------------------------------------------
    public static final String SR_RT_NAME         = 'Broker Registration';

    public static final String SUBJ_ABM           = 'Assignment of Broker Manager';
    public static final String SUBJ_RMI           = 'Require more information';
    public static final String SUBJ_COMPLIANCE    = 'Validation by Compliance Team';
    public static final String SUBJ_SIGNATURE     = 'Send for Signature';
    public static final String SUBJ_SALES_ADMIN   = 'Validation by Broker Sales Admin';

    public static final String FILTER_ALL         = 'ALL';
    public static final String FILTER_RESUBMITTED = 'RESUBMITTED';

    public static final String TASK_STATUS_OPEN      = 'OPEN';
    public static final String TASK_STATUS_COMPLETED = 'COMPLETED';

    private static final Set<String> KNOWN_SUBJECTS = new Set<String>{
        SUBJ_ABM, SUBJ_RMI, SUBJ_COMPLIANCE, SUBJ_SIGNATURE, SUBJ_SALES_ADMIN
    };

    private static final Set<String> SORTABLE_FIELDS = new Set<String>{
        'Subject', 'Status', 'ActivityDate', 'CreatedDate', 'LastModifiedDate'
    };

    private static final Integer DEFAULT_PAGE_SIZE = 10;
    private static final Integer MAX_PAGE_SIZE     = 100;
    private static final Integer MAX_OFFSET        = 2000;   // SOQL OFFSET limit
    private static final Integer SR_QUERY_LIMIT    = 50000;

    // ---- DTOs ------------------------------------------------------------------------------------------------------

    public class TaskRequest {
        public String  subjectFilter;
        public String  searchTerm;
        public String  taskStatus;
        public String  srStatus;
        public Integer pageNumber;
        public Integer pageSize;
        public String  sortBy;
        public String  sortDir;
    }

    public class TaskRow {
        @AuraEnabled public Id       taskId;
        @AuraEnabled public String   subject;
        @AuraEnabled public String   taskStatus;
        @AuraEnabled public Boolean  isClosed;
        @AuraEnabled public String   priority;
        @AuraEnabled public Date     dueDate;
        @AuraEnabled public Datetime createdDate;
        @AuraEnabled public Datetime lastModifiedDate;
        @AuraEnabled public Datetime completedDate;
        @AuraEnabled public String   assignedTo;
        @AuraEnabled public String   updatedBy;
        @AuraEnabled public String   createdBy;
        @AuraEnabled public Id       srId;
        @AuraEnabled public String   srName;
        @AuraEnabled public String   srStatus;
        @AuraEnabled public Id       registrationId;
        @AuraEnabled public String   registrationName;
        @AuraEnabled public String   agencyName;
        @AuraEnabled public Boolean  isResubmission;   // this task is the post-resubmission ABM task
        @AuraEnabled public Boolean  srResubmitted;    // the SR has been resubmitted at least once
    }

    public class TaskResponse {
        @AuraEnabled public List<TaskRow>       rows            = new List<TaskRow>();
        @AuraEnabled public Integer             totalRecords    = 0;
        @AuraEnabled public Integer             pageNumber      = 1;
        @AuraEnabled public Integer             pageSize        = DEFAULT_PAGE_SIZE;
        @AuraEnabled public Integer             totalPages      = 1;
        @AuraEnabled public Boolean             offsetCapped    = false;
        @AuraEnabled public Map<String, Integer> counts         = new Map<String, Integer>();
        @AuraEnabled public List<String>        srStatusOptions = new List<String>();
    }

    private class ResubmissionInfo {
        Set<Id> taskIds = new Set<Id>();
        Set<Id> srIds   = new Set<Id>();
    }

    // ---- Public API ------------------------------------------------------------------------------------------------

    @AuraEnabled
    public static TaskResponse getTasks(String requestJson) {
        try {
            TaskRequest req = normalise(
                String.isBlank(requestJson)
                    ? new TaskRequest()
                    : (TaskRequest) JSON.deserialize(requestJson, TaskRequest.class)
            );

            TaskResponse res = new TaskResponse();
            res.pageSize        = req.pageSize;
            res.srStatusOptions = getSrStatusOptions();

            // 1. Broker Registration SRs in scope (SR status filter applied here)
            Map<Id, ServiceRequest__c> srMap = querySrs(req.srStatus);
            Set<Id> scopeSrIds = new Set<Id>(srMap.keySet());

            if (scopeSrIds.isEmpty()) {
                res.counts = emptyCounts();
                return res;
            }

            // 2. Resubmission detection (closed RMI followed by a new ABM task)
            ResubmissionInfo resub = detectResubmissions(scopeSrIds);

            // 3. Base conditions shared by counts + data (everything except the subject filter)
            Map<String, Object> binds = new Map<String, Object>{
                'scopeSrIds'   => scopeSrIds,
                'resubTaskIds' => resub.taskIds
            };
            List<String> baseConds = new List<String>{ 'WhatId IN :scopeSrIds' };

            if (String.isNotBlank(req.searchTerm)) {
                String term = req.searchTerm.trim();
                binds.put('searchSrIds', matchSrsBySearch(srMap.values(), term));
                binds.put('likeTerm', '%' + term + '%');
                baseConds.add(
                    '(WhatId IN :searchSrIds OR Owner.Name LIKE :likeTerm OR LastModifiedBy.Name LIKE :likeTerm)'
                );
            }

            if (req.taskStatus == TASK_STATUS_OPEN) {
                baseConds.add('IsClosed = false');
            } else if (req.taskStatus == TASK_STATUS_COMPLETED) {
                baseConds.add('IsClosed = true');
            }

            // 4. Pill counts
            res.counts = buildCounts(baseConds, binds);

            // 5. Subject / Resubmitted filter
            List<String> conds = new List<String>(baseConds);
            if (req.subjectFilter == FILTER_RESUBMITTED) {
                conds.add('Id IN :resubTaskIds');
            } else if (KNOWN_SUBJECTS.contains(req.subjectFilter)) {
                binds.put('subjectFilter', req.subjectFilter);
                conds.add('Subject = :subjectFilter');
            }

            res.totalRecords = res.counts.containsKey(req.subjectFilter)
                ? res.counts.get(req.subjectFilter)
                : 0;
            res.totalPages = Math.max(1, (Integer) Math.ceil((Decimal) res.totalRecords / req.pageSize));

            // 6. Pagination (SOQL OFFSET is capped at 2000)
            Integer pageNumber = Math.min(req.pageNumber, res.totalPages);
            Integer offsetVal  = (pageNumber - 1) * req.pageSize;
            if (offsetVal > MAX_OFFSET) {
                offsetVal        = (MAX_OFFSET / req.pageSize) * req.pageSize;
                pageNumber       = (offsetVal / req.pageSize) + 1;
                res.offsetCapped = true;
            }
            res.pageNumber = pageNumber;

            binds.put('pageSize', req.pageSize);
            binds.put('offsetVal', offsetVal);

            String soql =
                'SELECT Id, Subject, Status, IsClosed, Priority, ActivityDate, CreatedDate, LastModifiedDate, ' +
                '       CompletedDateTime, WhatId, Owner.Name, LastModifiedBy.Name, CreatedBy.Name ' +
                'FROM Task ' +
                'WHERE ' + String.join(conds, ' AND ') + ' ' +
                'ORDER BY ' + req.sortBy + ' ' + req.sortDir + ' NULLS LAST, Id ' + req.sortDir + ' ' +
                'LIMIT :pageSize OFFSET :offsetVal';

            List<Task> tasks = (List<Task>) Database.queryWithBinds(soql, binds, AccessLevel.USER_MODE);

            for (Task t : tasks) {
                res.rows.add(toRow(t, srMap.get(t.WhatId), resub));
            }
            return res;

        } catch (Exception ex) {
            AuraHandledException ahe = new AuraHandledException(ex.getMessage());
            ahe.setMessage(ex.getMessage());
            throw ahe;
        }
    }

    // ---- Helpers ---------------------------------------------------------------------------------------------------

    private static TaskRequest normalise(TaskRequest req) {
        req.subjectFilter = String.isBlank(req.subjectFilter) ? FILTER_ALL : req.subjectFilter;
        req.taskStatus    = String.isBlank(req.taskStatus) ? FILTER_ALL : req.taskStatus.toUpperCase();
        req.srStatus      = String.isBlank(req.srStatus) ? FILTER_ALL : req.srStatus;
        req.pageNumber    = (req.pageNumber == null || req.pageNumber < 1) ? 1 : req.pageNumber;
        req.pageSize      = (req.pageSize == null || req.pageSize < 1)
            ? DEFAULT_PAGE_SIZE
            : Math.min(req.pageSize, MAX_PAGE_SIZE);
        req.sortBy        = SORTABLE_FIELDS.contains(req.sortBy) ? req.sortBy : 'LastModifiedDate';
        req.sortDir       = (req.sortDir != null && req.sortDir.toUpperCase() == 'ASC') ? 'ASC' : 'DESC';
        return req;
    }

    private static Map<Id, ServiceRequest__c> querySrs(String srStatus) {
        Boolean filterStatus = srStatus != FILTER_ALL;
        if (filterStatus) {
            return new Map<Id, ServiceRequest__c>([
                SELECT Id, Name, Status__c, Registration__c, Registration__r.Name,
                       Registration__r.Broker_Agency__r.Name
                FROM ServiceRequest__c
                WHERE RecordType.Name = :SR_RT_NAME
                  AND Status__c = :srStatus
                WITH USER_MODE
                LIMIT :SR_QUERY_LIMIT
            ]);
        }
        return new Map<Id, ServiceRequest__c>([
            SELECT Id, Name, Status__c, Registration__c, Registration__r.Name,
                   Registration__r.Broker_Agency__r.Name
            FROM ServiceRequest__c
            WHERE RecordType.Name = :SR_RT_NAME
            WITH USER_MODE
            LIMIT :SR_QUERY_LIMIT
        ]);
    }

    private static Set<Id> matchSrsBySearch(List<ServiceRequest__c> srs, String term) {
        Set<Id> matched = new Set<Id>();
        String t = term.toLowerCase();
        for (ServiceRequest__c sr : srs) {
            if (containsIgnoreCase(sr.Name, t)
                || containsIgnoreCase(sr.Registration__r?.Name, t)
                || containsIgnoreCase(sr.Registration__r?.Broker_Agency__r?.Name, t)) {
                matched.add(sr.Id);
            }
        }
        return matched;
    }

    private static Boolean containsIgnoreCase(String value, String lowerTerm) {
        return value != null && value.toLowerCase().contains(lowerTerm);
    }

    /**
     * Resubmission = the customer answered "Require more information":
     * the RMI task is closed and a NEW "Assignment of Broker Manager" task is created after it.
     * The original ABM task (step 1) is created before any RMI task, so it is never flagged.
     */
    private static ResubmissionInfo detectResubmissions(Set<Id> srIds) {
        ResubmissionInfo info = new ResubmissionInfo();

        Map<Id, Datetime> firstClosedRmiBySr = new Map<Id, Datetime>();
        for (Task t : [
            SELECT WhatId, CreatedDate
            FROM Task
            WHERE WhatId IN :srIds
              AND Subject = :SUBJ_RMI
              AND IsClosed = true
            ORDER BY CreatedDate ASC
        ]) {
            if (!firstClosedRmiBySr.containsKey(t.WhatId)) {
                firstClosedRmiBySr.put(t.WhatId, t.CreatedDate);
            }
        }

        if (firstClosedRmiBySr.isEmpty()) {
            return info;
        }

        for (Task t : [
            SELECT Id, WhatId, CreatedDate
            FROM Task
            WHERE WhatId IN :firstClosedRmiBySr.keySet()
              AND Subject = :SUBJ_ABM
        ]) {
            if (t.CreatedDate > firstClosedRmiBySr.get(t.WhatId)) {
                info.taskIds.add(t.Id);
                info.srIds.add(t.WhatId);
            }
        }
        return info;
    }

    private static Map<String, Integer> buildCounts(List<String> baseConds, Map<String, Object> binds) {
        Map<String, Integer> counts = emptyCounts();
        String whereClause = String.join(baseConds, ' AND ');

        // Task.Subject is a combobox field and cannot be used in GROUP BY,
        // so each subject gets its own COUNT() query (5 subjects + All + Resubmitted = 7 queries).
        counts.put(FILTER_ALL, Database.countQueryWithBinds(
            'SELECT COUNT() FROM Task WHERE ' + whereClause,
            binds, AccessLevel.USER_MODE));

        for (String subj : KNOWN_SUBJECTS) {
            Map<String, Object> subjBinds = new Map<String, Object>(binds);
            subjBinds.put('countSubject', subj);
            counts.put(subj, Database.countQueryWithBinds(
                'SELECT COUNT() FROM Task WHERE ' + whereClause + ' AND Subject = :countSubject',
                subjBinds, AccessLevel.USER_MODE));
        }

        Set<Id> resubIds = (Set<Id>) binds.get('resubTaskIds');
        counts.put(FILTER_RESUBMITTED, resubIds.isEmpty() ? 0 : Database.countQueryWithBinds(
            'SELECT COUNT() FROM Task WHERE ' + whereClause + ' AND Id IN :resubTaskIds',
            binds, AccessLevel.USER_MODE));

        return counts;
    }

    private static Map<String, Integer> emptyCounts() {
        Map<String, Integer> counts = new Map<String, Integer>{ FILTER_ALL => 0, FILTER_RESUBMITTED => 0 };
        for (String s : KNOWN_SUBJECTS) {
            counts.put(s, 0);
        }
        return counts;
    }

    private static List<String> getSrStatusOptions() {
        List<String> options = new List<String>();
        for (AggregateResult ar : [
            SELECT Status__c status
            FROM ServiceRequest__c
            WHERE RecordType.Name = :SR_RT_NAME
              AND Status__c != null
            WITH USER_MODE
            GROUP BY Status__c
            ORDER BY Status__c
        ]) {
            options.add((String) ar.get('status'));
        }
        return options;
    }

    private static TaskRow toRow(Task t, ServiceRequest__c sr, ResubmissionInfo resub) {
        TaskRow r = new TaskRow();
        r.taskId           = t.Id;
        r.subject          = t.Subject;
        r.taskStatus       = t.Status;
        r.isClosed         = t.IsClosed;
        r.priority         = t.Priority;
        r.dueDate          = t.ActivityDate;
        r.createdDate      = t.CreatedDate;
        r.lastModifiedDate = t.LastModifiedDate;
        r.completedDate    = t.CompletedDateTime;
        r.assignedTo       = t.Owner?.Name;
        r.updatedBy        = t.LastModifiedBy?.Name;
        r.createdBy        = t.CreatedBy?.Name;
        r.isResubmission   = resub.taskIds.contains(t.Id);
        r.srResubmitted    = resub.srIds.contains(t.WhatId);

        if (sr != null) {
            r.srId             = sr.Id;
            r.srName           = sr.Name;
            r.srStatus         = sr.Status__c;
            r.registrationId   = sr.Registration__c;
            r.registrationName = sr.Registration__r?.Name;
            r.agencyName       = sr.Registration__r?.Broker_Agency__r?.Name;
        }
        return r;
    }
}