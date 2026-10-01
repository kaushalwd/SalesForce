/**********************************************************************************************************************
* Name               :                                                         
* Description        : Class for BP framework
* Usage              : BP Framework                                                        
* Created By         : Sivannarayana Peddireddi                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                          Date            Comment                                                                       
* 1.0           sivannaryana.p@modon.com     10-05-2026      Initial Draft     
**********************************************************************************************************************/
public with sharing class BusinessProcessStepController {
    
    public class StepWithTimelineWrapper {
        @AuraEnabled public Business_Process_Step__c step;
        @AuraEnabled public StepTimeCalculatorRealTime.StepTimeCalculationOutput timeline;
    }

     public class OptionWrapper {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        public OptionWrapper(String value, String label) {
            this.value = value;
            this.label = label;
        }
    }

    public class FilterOptionsWrapper {
        @AuraEnabled public List<OptionWrapper> departments;
        @AuraEnabled public List<OptionWrapper> processes;
        @AuraEnabled public List<OptionWrapper> users;
    }
  
    @AuraEnabled
    public static void assignStepsToUser(List<Id> stepIds, Id assignToUserId) {
        List<Business_Process_Step__c> steps = [
            SELECT Id, Status__c 
            FROM Business_Process_Step__c 
            WHERE Id IN :stepIds
        ];

        for (Business_Process_Step__c step : steps) {
            step.Assigned_To__c = assignToUserId;
            if (step.Status__c == 'Open') {
                step.Status__c = 'Accepted';
            }
        }
        update steps;
    }
    @AuraEnabled(cacheable=true)
    public static List<String> getBPNNumbers() {
        Set<String> bpnNumbers = new Set<String>();
        /*
        for (Business_Process__c bp : [
            SELECT BPN_Number__c 
            FROM Business_Process__c 
            WHERE BPN_Number__c != null AND Status__c = 'In Progress'
            ORDER BY BPN_Number__c
            LIMIT 1000
        ]) {
            bpnNumbers.add(bp.BPN_Number__c);
        }
        */
    
        return new List<String>(bpnNumbers);
    }

    @AuraEnabled //(cacheable=true)
    public static List<StepWithTimelineWrapper> fetchInitialSteps(
        String selectedFlowName, 
        String selectedStepName, 
        String selectedProjectId,  
        String selectedTowerId,
        String selectedStatus,
        String selectedAssignmentStatus,
        String bpnNumber,
        List<Id> unitIds,
        List<Id> bookingIds
    ) {
        system.debug('selectedFlowName = '+selectedFlowName + '---------selectedStepName = '+selectedStepName);
        //stem.debug('selectedProjectId = '+selectedProjectId + '-------selectedTowerId = '+selectedTowerId);
        system.debug('bookingIds --> '+bookingIds);
        system.debug('selectedStatus --> '+selectedStatus);
        system.debug('selectedAssignmentStatus --> '+selectedAssignmentStatus);
        
       Id userId = UserInfo.getUserId();
       //Will remove hardcoded one -- doing for quick testing
        //Id userId = '005ba000002rAcnAAE';
        List<String> validStatuses = new List<String>{'Accepted', 'Open', 'Re Open', 'Provided Info', 'Assigned'};

            // Determine which statuses to use
        List<String> statusFilter;
        if (String.isNotBlank(selectedStatus)) {
            statusFilter = new List<String>{selectedStatus};
         } else {
            statusFilter = validStatuses;
         }

        List<Id> queueIds = new List<Id>(getQueueIdsForUser(userId));
        
        // Build dynamic filters
        String baseQuery = 'SELECT Id, Name, Business_Process__c,Business_Process__r.Name, Business_Process__r.Process_Flow__r.Name, Status__c, CreatedDate, OwnerId, Assigned_To__c,Assigned_To__r.Name, canMassUpdate__c, ';
        baseQuery += 'Business_Process__r.Unit__c, Business_Process__r.Unit__r.Name, Business_Process__r.Project__c, Business_Process__r.Project__r.Name, ';
        baseQuery += 'Business_Process__r.Sales_Order__c, Business_Process__r.Sales_Order__r.Name, Owner.Name ';/* Business_Process__r.DLD_Balance__c, Business_Process__r.DLD_fee_allocated__c*/
        baseQuery += 'FROM Business_Process_Step__c WHERE Business_Process__c != Null AND Status__c IN :statusFilter ';
        if(selectedAssignmentStatus == 'Not Assigned'){
            baseQuery += 'AND Assigned_To__c = Null AND Business_Process__r.Process_Flow__c != null AND OwnerId IN :queueIds ';
        } else {
            baseQuery += 'AND Assigned_To__c = :userId ';
        }/*else if(selectedAssignmentStatus == 'Assigned'){
            baseQuery += 'AND Assigned_To__c = :userId ';
        } else {
            baseQuery += 'AND (Assigned_To__c = :userId OR (Assigned_To__c = Null AND OwnerId IN :queueIds )) ';
        }*/

        /*if (startDate != null) {
            baseQuery += ' AND CreatedDate >= :startDate';
        }
        if (endDate != null) {
        baseQuery += ' AND CreatedDate <= :endDate';
        }*/
       /* if (!String.isBlank(selectedFlowName)) {
        baseQuery += ' AND Business_Process_Name__c = :selectedFlowName';
        }*/
        
        if (!String.isBlank(selectedFlowName)) {
            baseQuery += ' AND Business_Process__r.Process_Flow__r.Name =:selectedFlowName';
        }
        if (!String.isBlank(selectedStepName)) {
        baseQuery += ' AND Name = :selectedStepName';
        }
        
        if (!String.isBlank(selectedProjectId)) {
        baseQuery += ' AND Business_Process__r.Project__c = :selectedProjectId';
        }
        if (!String.isBlank(selectedTowerId)) {
        baseQuery += ' AND Business_Process__r.Tower__c = :selectedTowerId';
        }
        if(!unitIds.isEmpty()) {
            baseQuery += ' AND Business_Process__r.Unit__c IN :unitIds';
        }
        if(!bookingIds.isEmpty()) {
            baseQuery += ' AND Business_Process__r.Booking__c IN :bookingIds';
        }
        if (String.isNotBlank(bpnNumber)) {
            //baseQuery += ' AND Business_Process__r.BPN_Number__c LIKE \'%' + String.escapeSingleQuotes(bpnNumber) + '%\'';
            baseQuery += ' AND Business_Process__r.BPN_Number__c =: bpnNumber';
        }

        baseQuery += ' ORDER BY CreatedDate ASC, Business_Process_Name__c ASC ';
        System.debug('baseQuery --> '+baseQuery);

        // SOQL injection fix: LWC filters bound via queryWithBinds.
        List<Business_Process_Step__c> steps = Database.queryWithBinds(
            baseQuery,
            new Map<String, Object>{
                'statusFilter' => statusFilter,
                'queueIds' => queueIds,
                'userId' => userId,
                'selectedFlowName' => selectedFlowName,
                'selectedStepName' => selectedStepName,
                'selectedProjectId' => selectedProjectId,
                'selectedTowerId' => selectedTowerId,
                'unitIds' => unitIds,
                'bookingIds' => bookingIds,
                'bpnNumber' => bpnNumber
            },
            AccessLevel.SYSTEM_MODE
        );

        /*List<Business_Process_Step__c> steps = [
            SELECT Id, Name, Business_Process__c, Business_Process_Name__c, Booking_Name__c, Status__c, CreatedDate, OwnerId, Assigned_To__c
            FROM Business_Process_Step__c
            WHERE Assigned_To__c = :userId
            AND Status__c IN :validStatuses
            ORDER BY CreatedDate ASC, Business_Process_Name__c ASC, Booking_Name__c ASC
        ];*/
		System.debug('steps=> ' + steps);
        
        List<StepWithTimelineWrapper> result = new List<StepWithTimelineWrapper>();
        for (Business_Process_Step__c step : steps) {
            StepWithTimelineWrapper wrapper = new StepWithTimelineWrapper();
            wrapper.step = step;
           // wrapper.timeline = StepTimeCalculatorRealTime.getTimelineMetadata(step.Id);
            result.add(wrapper);
        }
        System.debug('result=> ' + result);
        return result;
    }

    private static Set<Id> getQueueIdsForUser(Id userId) {
        Set<Id> queueIds = new Set<Id>();
        
        for (GroupMember gm : [
            SELECT GroupId
            FROM GroupMember
            WHERE UserOrGroupId = :userId
            AND Group.Type = 'Queue'
        ]) {
            queueIds.add(gm.GroupId);
        }
        
        return queueIds;
    }

   

    @AuraEnabled(cacheable=true)
    public static List<OptionWrapper> getProcessFlows() {
        List<OptionWrapper> opts = new List<OptionWrapper>();
        for (Process_Flow__c pf : [
            SELECT Id, Process_Flow_Unique_Name__c
            FROM Process_Flow__c
            ORDER BY Process_Flow_Unique_Name__c
        ]) {
            opts.add(new OptionWrapper(pf.Id, pf.Process_Flow_Unique_Name__c));
        }
        return opts;
    }

    @AuraEnabled(cacheable=true)
    public static List<OptionWrapper> getFlowSteps(Id processFlowId) {
        if (processFlowId == null) return new List<OptionWrapper>();
        List<OptionWrapper> opts = new List<OptionWrapper>();
        for (Process_Flow_Step__c step : [
            SELECT Id, Step_Name__c 
            FROM Process_Flow_Step__c 
            WHERE Process_Flow__c = :processFlowId 
            ORDER BY Step_Name__c
        ]) {
            opts.add(new OptionWrapper(step.Id, step.Step_Name__c));
        }
        return opts;
    }
    

    @AuraEnabled(cacheable=true)
    public static List<OptionWrapper> getQueueUsers(Id queueGroupId) {
        system.debug('queueGroupId --> '+queueGroupId);
        if (queueGroupId == null) return new List<OptionWrapper>();

        Set<Id> userIds = new Set<Id>();
        Set<Id> groupIds = new Set<Id>();

        for (GroupMember gm : [
            SELECT UserOrGroupId 
            FROM GroupMember 
            WHERE GroupId = :queueGroupId
        ]) {
            if (gm.UserOrGroupId.getSObjectType() == User.SObjectType) {
                userIds.add(gm.UserOrGroupId);
            } else {
                groupIds.add(gm.UserOrGroupId);
            }
        }

         system.debug('groupIds --> '+groupIds);
         system.debug('userIds --> '+userIds);
        if (!groupIds.isEmpty()) {
            for (GroupMember gm2 : [
                SELECT UserOrGroupId 
                FROM GroupMember 
                WHERE GroupId IN :groupIds
            ]) {
                if (gm2.UserOrGroupId.getSObjectType() == User.SObjectType) {
                    userIds.add(gm2.UserOrGroupId);
                }
            }
             system.debug('userIds --------> '+userIds);
        }

        List<OptionWrapper> opts = new List<OptionWrapper>();
        for (User u : [
            SELECT Id, Name 
            FROM User 
            WHERE Id IN :userIds 
            ORDER BY Name
        ]) {
            opts.add(new OptionWrapper(u.Id, u.Name));
        }
        system.debug('opts --------> '+opts);
        return opts;
    }

    @AuraEnabled
    public static List<StepWithTimelineWrapper> getFilteredSteps(
        String flowProcess,
        String flowStep,
        String department,
        List<String> status,
        String project,
        String tower,
        String user,
        String bpnNumber,
        List<Id> unitIds,
        List<Id> bookingIds
    ) {
        system.debug('flowProcess --> '+flowProcess);
        system.debug('flowStep --> '+flowStep);
        system.debug('department --> '+department);
        system.debug('status --> '+status);
        system.debug('project --> '+project);
        system.debug('tower --> '+tower);
        system.debug('unitIds --> '+unitIds);
        system.debug('bookingIds --> '+bookingIds);
        system.debug('bpnNumber --> '+bpnNumber);

        List<String> andClauses = new List<String>();
        List<String> orClauses = new List<String>();
        
        /*List<String> clauses = new List<String>();
        if (department != null) clauses.add('Department__c = :department');
        if (status != null) clauses.add('Status__c = :status');
        if (flowProcess != null) clauses.add('Business_Process_Name__c = :flowProcess');
        if (flowStep != null) clauses.add('Name = :flowStep');*/

        if (department != null) andClauses.add('Department__c = :department');
        if (status != null && !status.isEmpty()) andClauses.add('Status__c IN :status');
        if (flowProcess != null) andClauses.add('Business_Process__r.Process_Flow__r.Name = :flowProcess');
        if (flowStep != null) andClauses.add('Name = :flowStep');
        if(unitIds!=null && !unitIds.isEmpty()) andClauses.add('Business_Process__r.Unit__c IN :unitIds');
        if(bookingIds!=null && !bookingIds.isEmpty()) andClauses.add('Business_Process__r.Booking__c IN :bookingIds');
        if(String.isNotBlank(bpnNumber)) andClauses.add('Business_Process__r.BPN_Number__c =: bpnNumber');


        if (project != null) orClauses.add('Business_Process__r.Project__c = :project');
        if (tower != null) orClauses.add('Business_Process__r.Tower__c = :tower');
        if (user != null) orClauses.add('Assigned_To__c = :user');
        
        String baseQuery = 'SELECT Id, Name, Business_Process__r.Name, Department__c, Status__c, OwnerId, Assigned_To__c, Assigned_To__r.Name, CreatedDate, Owner.Name, ';
        baseQuery += 'Business_Process__r.Unit__c, Business_Process__r.Unit__r.Name, Business_Process__r.Project__c, Business_Process__r.Project__r.Name,  ';
        baseQuery += ' Business_Process__r.Sales_Order__c, Business_Process__r.Sales_Order__r.Name ';
        baseQuery += 'FROM Business_Process_Step__c WHERE ';

        System.debug('andClauses = '+andClauses);
        // Handle combinations of AND and OR
        if (!andClauses.isEmpty()) {
            baseQuery += String.join(andClauses, ' AND ');
        }

        System.debug('orClauses = '+orClauses);
        if (!orClauses.isEmpty()) {
            if (!andClauses.isEmpty()) {
                baseQuery += ' AND ';
            }
            baseQuery += '(' + String.join(orClauses, ' OR ') + ')';
        }

        baseQuery += ' ORDER BY Name ';
    
        
        System.debug('baseQuery --> '+baseQuery);
        // SOQL injection fix: LWC filters bound via queryWithBinds.
        List<Business_Process_Step__c> steps = Database.queryWithBinds(
            baseQuery,
            new Map<String, Object>{
                'department' => department,
                'status' => status,
                'flowProcess' => flowProcess,
                'flowStep' => flowStep,
                'unitIds' => unitIds,
                'bookingIds' => bookingIds,
                'bpnNumber' => bpnNumber,
                'project' => project,
                'tower' => tower,
                'user' => user
            },
            AccessLevel.SYSTEM_MODE
        );

        List<StepWithTimelineWrapper> result = new List<StepWithTimelineWrapper>();
        for (Business_Process_Step__c step : steps) {
            StepWithTimelineWrapper wrapper = new StepWithTimelineWrapper();
            wrapper.step = step;
            //wrapper.timeline = StepTimeCalculatorRealTime.getTimelineMetadata(step.Id);
            result.add(wrapper);
        }
        return result;
    }

    @AuraEnabled
    public static void assignSteps(List<Id> stepIds, Id assignToUserId) {
        
        List<Business_Process_Step__c> recs = [
            SELECT Id, Status__c , Name,Business_Process__c
            FROM Business_Process_Step__c 
            WHERE Id IN :stepIds
        ];
        Set<Id> bpIds=new Set<Id>();
        for (Business_Process_Step__c rec : recs) {
            rec.Assigned_To__c = assignToUserId != null ? assignToUserId : UserInfo.getUserId();
            if (rec.Status__c == 'Open') rec.Status__c = 'Accepted';
            if(rec.Name=='Collections Customer Engagement')
            bpIds.add(rec.Business_Process__c);
        }
        update recs;
        if(bpIds.size()>0)
        assignTasks(bpIds,assignToUserId );

    }
    


    @AuraEnabled(cacheable=true)
    public static Map<String, List<String>> getPicklistValuesFromField() {
        Map<String, List<String>> picklistMap = new Map<String, List<String>>();

        // Describe Business_Process_Step__c for Status__c picklist
        Schema.DescribeSObjectResult stepDescribe = Business_Process_Step__c.SObjectType.getDescribe();
        Map<String, Schema.SObjectField> stepFieldMap = stepDescribe.fields.getMap();

        // Describe Process_Flow_Step__c for Department__c picklist
        Schema.DescribeSObjectResult flowStepDescribe = Process_Flow_Step__c.SObjectType.getDescribe();
        Map<String, Schema.SObjectField> flowFieldMap = flowStepDescribe.fields.getMap();

        // Get Status__c picklist values from Business_Process_Step__c
        if (stepFieldMap.containsKey('Status__c')) {
            List<Schema.PicklistEntry> statusValues = stepFieldMap.get('Status__c').getDescribe().getPicklistValues();
            List<String> statusList = new List<String>();
            for (Schema.PicklistEntry val : statusValues) {
                if (val.isActive() && val.getLabel() != 'Not Actioned') {
                    statusList.add(val.getLabel());
                }
            }
            picklistMap.put('Status__c', statusList);
        }

        // Get Department__c picklist values from Process_Flow_Step__c
        if (flowFieldMap.containsKey('Department__c')) {
            List<Schema.PicklistEntry> deptValues = flowFieldMap.get('Department__c').getDescribe().getPicklistValues();
            List<String> deptList = new List<String>();
            for (Schema.PicklistEntry val : deptValues) {
                if (val.isActive()) {
                    deptList.add(val.getLabel());
                }
            }
            picklistMap.put('Department__c', deptList);
        }

        return picklistMap;
    }
    
    @AuraEnabled
    public static List<Id> getUnitsByName(List<String> unitNames) {
        system.debug('unitNames --> '+unitNames);
        if (!unitNames.isEmpty()) {
            /*
            return new List<Id>(
                new Map<Id, Unit__c>([
                    SELECT Id 
                    FROM Unit__c 
                    WHERE Name IN :unitNames 
                    LIMIT 10000
                ]).keySet()
                );
                */
        }
        return null;
    }


    @AuraEnabled
    public static List<Id> getBookingsByName(List<String> bookingNames) {
        system.debug('bookingNames --> '+bookingNames);
       
        if (!bookingNames.isEmpty()) {
          /*   return new List<Id>(
                new Map<Id, Booking__c>([
                    SELECT Id 
                    FROM Booking__c 
                    WHERE Name IN :bookingNames 
                    LIMIT 1000
                ]).keySet()
            );
        */
        }
        return null;
    }


    @AuraEnabled
    public static void saveBPNDocument(List<Id> stepIds, Id fileId, String documentType) {
    try {
        
        Set<Id> businessProcessIds=new Set<Id>();
        for (Business_Process_Step__c st:[Select Id,Business_Process__c from Business_Process_Step__c  where Id IN: stepIds]){
            businessProcessIds.add(st.Business_Process__c);
        }
        List<Business_Process_Documents__c> docList=[Select Id, Name from Business_Process_Documents__c where Business_Process__c IN:businessProcessIds and Name=: documentType];
       
        if (fileId != null && !docList.isEmpty()) {
            List<ContentDocumentLink> links = new List<ContentDocumentLink>();
            for (Business_Process_Documents__c doc : docList) {
               
                links.add(new ContentDocumentLink(
                    ContentDocumentId = fileId,
                    LinkedEntityId = doc.Id,
                    ShareType = 'V',
                    Visibility = 'AllUsers'
                ));
               
            }
            insert links;
        }
    } catch (Exception e) {
        throw new AuraHandledException('Error saving BPN document: ' + e.getMessage());
    }
}

Public static void assignTasks(Set<Id> bpIds, String UserId){

    List<Task> taskList=[Select Id, Subject from Task where WhatId IN : bpIds and Subject like 'Call Task - Finance Verification - Default Notice%' and Status ='Open'];
    List<Task> tskUpdate=new List<Task>();
    for(Task tk:taskList){
           Task t=new Task();
           t.Id=tk.Id;
           t.OwnerId=UserId;
           tskUpdate.add(t);
    }
    if(tskUpdate.size()>0)
    update tskUpdate;

}

    
}