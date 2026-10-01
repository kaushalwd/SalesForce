public without sharing class BP_OmniApprovalLwcController {



    @AuraEnabled(cacheable=true)
    public static List<ApprovalDashboardWrapper> getApprovalDashboard() {

        Id currentUserId = UserInfo.getUserId();


        Set<Id> queueIds = new Set<Id>();

        for (GroupMember gm : [
            SELECT GroupId
            FROM GroupMember
            WHERE UserOrGroupId = :currentUserId
        ]) {
            queueIds.add(gm.GroupId);
        }



        List<GridConfig> configs = getGridConfigs();

        Set<String> stepFields = new Set<String>{
            'Id',
            'Name',
            'Business_Process__c',
            'Business_Process__r.Name',
            'Business_Process_Steps_Name_Custom__c',
            'Step__c',
            'Status__c',
            'Is_Management_Step__c',
            'Assigned_To__c',
            'Assigned_To__r.Name',
            'OwnerId',
            'Owner.Name',
            'CreatedDate',
            'LastModifiedDate'
        };

        Set<String> bpFields = new Set<String>{
            'Id',
            'Name',
            'Type__c',
            'Subcategory__c'
        };


        /*
         * Add configured fields to the appropriate object.
         */
        for (GridConfig config : configs) {

            if (!config.active) {
                continue;
            }

            if (config.objectName == 'Business_Process__c') {
                bpFields.add(getQueryField(config.fieldName));
            }

            if (config.objectName == 'Business_Process_Step__c') {
                stepFields.add(getQueryField(config.fieldName));
            }
        }


        /*
         * --------------------------------------------------------
         * 3. Get CURRENT steps assigned to logged-in user
         * --------------------------------------------------------
         */
        String stepQuery =
            'SELECT ' +
            String.join(new List<String>(stepFields), ',') +
            ' FROM Business_Process_Step__c' +
            ' WHERE  Is_Management_Step__c = true' +
            ' AND Status__c IN (\'Open\', \'Provided Info\', \'Not Valid\', \'Accepted\', \'Re Open\', \'Assigned\')' +
            ' AND (' +
                'Assigned_To__c = :currentUserId' +
                ' OR OwnerId = :currentUserId';

        if (!queueIds.isEmpty()) {
            stepQuery += ' OR OwnerId IN :queueIds';
        }

        stepQuery +=
            ')' +
            ' ORDER BY LastModifiedDate DESC';

        Map<String, Object> stepBinds = new Map<String, Object>{
            'currentUserId' => currentUserId
        };
        if (!queueIds.isEmpty()) {
            stepBinds.put('queueIds', queueIds);
        }

        List<Business_Process_Step__c> currentSteps =
            Database.queryWithBinds(stepQuery, stepBinds, AccessLevel.SYSTEM_MODE);


        if (currentSteps.isEmpty()) {
            return new List<ApprovalDashboardWrapper>();
        }


        /*
         * --------------------------------------------------------
         * 4. Collect BP IDs
         * --------------------------------------------------------
         */
        Set<Id> bpIds = new Set<Id>();

        for (Business_Process_Step__c step : currentSteps) {

            if (step.Business_Process__c != null) {
                bpIds.add(step.Business_Process__c);
            }
        }


        /*
         * --------------------------------------------------------
         * 5. Query Business Processes
         * --------------------------------------------------------
         */
        String bpQuery =
            'SELECT ' +
            String.join(new List<String>(bpFields), ',') +
            ' FROM Business_Process__c' +
            ' WHERE Id IN :bpIds';
        List<Business_Process__c> businessProcesses =
            Database.queryWithBinds(bpQuery, new Map<String, Object>{'bpIds' => bpIds}, AccessLevel.SYSTEM_MODE);


        Map<Id, Business_Process__c> bpMap =
            new Map<Id, Business_Process__c>(
                businessProcesses
            );


        /*
         * --------------------------------------------------------
         * 6. Query ALL steps belonging to those BPs
         *
         *    Used for Previous Approved Steps.
         * --------------------------------------------------------
         */
        String historyQuery =
            'SELECT ' +
            String.join(new List<String>(stepFields), ',') +
            ' FROM Business_Process_Step__c' +
            ' WHERE Business_Process__c IN :bpIds' +
            ' AND Is_Management_Step__c = true' +
            ' ORDER BY CreatedDate ASC';

        List<Business_Process_Step__c> allSteps =
            Database.queryWithBinds(historyQuery, new Map<String, Object>{'bpIds' => bpIds}, AccessLevel.SYSTEM_MODE);


        Map<Id, List<Business_Process_Step__c>> stepsByBp =
            new Map<Id, List<Business_Process_Step__c>>();

        for (Business_Process_Step__c step : allSteps) {

            if (!stepsByBp.containsKey(step.Business_Process__c)) {

                stepsByBp.put(
                    step.Business_Process__c,
                    new List<Business_Process_Step__c>()
                );
            }

            stepsByBp
                .get(step.Business_Process__c)
                .add(step);
        }


        /*
         * --------------------------------------------------------
         * 7. Build dashboard
         * --------------------------------------------------------
         */
        List<ApprovalDashboardWrapper> result =
            new List<ApprovalDashboardWrapper>();


        for (Business_Process_Step__c currentStep : currentSteps) {

            Business_Process__c bp =
                bpMap.get(currentStep.Business_Process__c);

            if (bp == null) {
                continue;
            }


            ApprovalDashboardWrapper wrapper =
                new ApprovalDashboardWrapper();

            wrapper.businessProcessId =
                bp.Id;

            wrapper.currentStepId =
                currentStep.Id;

            wrapper.businessProcessName =
                bp.Name;

            wrapper.businessProcessType =
                bp.Type__c;

            wrapper.businessProcessSubcategory =
                bp.Subcategory__c;

            wrapper.currentStepName =
                getStepName(currentStep);

            wrapper.status =
                currentStep.Status__c;

            wrapper.assignedTo =
                getAssignedUser(currentStep);


            /*
             * Current step fields
             */
            wrapper.currentStepFields =
                buildConfiguredFields(
                    bp,
                    currentStep,
                    configs
                );


            /*
             * Previous approved steps
             */
            List<Business_Process_Step__c> relatedSteps =
                stepsByBp.get(bp.Id);

            if (relatedSteps != null) {

                for (
                    Business_Process_Step__c previousStep :
                    relatedSteps
                ) {

                    /*
                     * Do not show the current step as history.
                     */
                    if (
                        previousStep.Id ==
                        currentStep.Id
                    ) {
                        continue;
                    }


                    /*
                     * Existing component considers Completed
                     * as approved.
                     */
                    if (
                        previousStep.Status__c !=
                        'Completed'
                    ) {
                        continue;
                    }


                    PreviousStepWrapper previous =
                        new PreviousStepWrapper();

                    previous.id =
                        previousStep.Id;

                    previous.stepName =
                        getStepName(previousStep);

                    previous.status =
                        previousStep.Status__c;

                    previous.assignedTo =
                        getAssignedUser(previousStep);

                    previous.fields =
                        buildConfiguredFields(
                            bp,
                            previousStep,
                            configs
                        );

                    wrapper.previousSteps.add(
                        previous
                    );
                }
            }


            result.add(wrapper);
        }


        return result;
    }


	private static String getQueryField(String fieldName) {

    if (String.isBlank(fieldName)) {
        return fieldName;
    }

    // Already a relationship field
    if (fieldName.contains('.')) {
        return fieldName;
    }

    return fieldName;
}


    // ============================================================
    // CONFIGURATION
    // ============================================================

    private static List<GridConfig> getGridConfigs() {

        List<GridConfig> result =
            new List<GridConfig>();

        for (
            BP_OmniApproval_Grid_Config__mdt config :
            [
                SELECT
                    Object__c,
                    Field_Name__c,
                    Sequence__c,
                    BP_Type__c,
                    Step_Name__c,
                    Active__c,
                    Label__c
                FROM BP_OmniApproval_Grid_Config__mdt
                WHERE Active__c = true
                ORDER BY Sequence__c ASC
            ]
        ) {

            GridConfig item =
                new GridConfig();

            item.objectName =
                config.Object__c;

            item.fieldName =
                config.Field_Name__c;

            item.sequence =
                config.Sequence__c;

            item.bpType =
                config.BP_Type__c;

            item.stepName =
                config.Step_Name__c;

            item.active =
                config.Active__c;

            item.mobile =true;
                //config.Mobile__c;

            item.desktop =true;
                //config.Desktop__c;

            item.label =
                config.Label__c;

            result.add(item);
        }

        return result;
    }


    // ============================================================
    // APPLICABLE GRID CONFIGURATION
    // ============================================================
    // Priority:
    // 1. BP-specific configuration for Business_Process__c.Type__c
    // 2. If no BP-specific configuration exists, use BP_Type__c = 'Default Config'
    // Blank BP_Type__c records continue to act as global configuration.
    // ============================================================
    @TestVisible
    private static List<GridConfig> getApplicableGridConfigs(
        List<GridConfig> allConfigs,
        String businessProcessType
    ) {

        List<GridConfig> specificConfigs = new List<GridConfig>();
        List<GridConfig> defaultConfigs = new List<GridConfig>();
        List<GridConfig> globalConfigs = new List<GridConfig>();

        if (allConfigs == null) {
            return globalConfigs;
        }

        for (GridConfig config : allConfigs) {

            if (config == null || !config.active) {
                continue;
            }

            if (String.isBlank(config.bpType)) {
                globalConfigs.add(config);
                continue;
            }

            if (config.bpType == 'Default Config') {
                defaultConfigs.add(config);
                continue;
            }

            if (config.bpType == businessProcessType) {
                specificConfigs.add(config);
            }
        }

        List<GridConfig> result = new List<GridConfig>();
        result.addAll(globalConfigs);

        if (!specificConfigs.isEmpty()) {
            result.addAll(specificConfigs);
        } else {
            result.addAll(defaultConfigs);
        }

        // getGridConfigs() already returns metadata ordered by Sequence__c,
        // and filtering above preserves that order.
        return result;
    }


    // ============================================================
    // BUILD CONFIGURED FIELDS
    // ============================================================

    private static List<FieldWrapper> buildConfiguredFields(
        Business_Process__c bp,
        Business_Process_Step__c step,
        List<GridConfig> configs
    ) {

        List<FieldWrapper> result =
            new List<FieldWrapper>();


        String bpType =
            String.isNotBlank(bp.Type__c)
            ? bp.Type__c
            : bp.Subcategory__c;

        String stepName =
            getStepName(step);


        List<GridConfig> applicableConfigs =
            getApplicableGridConfigs(
                configs,
                bpType
            );


        for (GridConfig config : applicableConfigs) {

            if (!config.active) {
                continue;
            }


            /*
             * Step filter.
             *
             * Blank step = applies to all steps.
             */
            if (
                String.isNotBlank(config.stepName) &&
                config.stepName != stepName
            ) {
                continue;
            }


            /*
             * Mobile / desktop filtering is done in LWC.
             */
            Object value;


            if (
                config.objectName ==
                'Business_Process__c'
            ) {

                value =
                    getFieldValue(
                        bp,
                        config.fieldName
                    );

            } else if (
                config.objectName ==
                'Business_Process_Step__c'
            ) {

                value =
                    getFieldValue(
                        step,
                        config.fieldName
                    );

            } else {

                continue;
            }


            /*
             * Do not display null fields.
             */
            if (value == null) {
                continue;
            }


            FieldWrapper field =
                new FieldWrapper();

            field.apiName =
                config.fieldName;

            field.label =
                String.isNotBlank(config.label)
                ? config.label
                : generateLabel(
                    config.fieldName
                );

            field.value =
                formatValue(value);

            field.sequence =
                config.sequence;

            field.mobile =
                config.mobile;

            field.desktop =
                config.desktop;


            result.add(field);
        }


        return result;
    }


    // ============================================================
    // GET FIELD VALUE
    // Supports:
    // Name
    // Type__c
    // Account__r.Name
    // Project__r.Name
    // ============================================================

    @TestVisible
    private static Object getFieldValue(
        SObject record,
        String fieldPath
    ) {

    if (
        record == null ||
        String.isBlank(fieldPath)
    ) {
        return null;
    }

    List<String> parts = fieldPath.split('\\.');

    SObject current = record;

    for (Integer i = 0; i < parts.size(); i++) {

        String part = parts[i];

        // Last field
        if (i == parts.size() - 1) {

            Object value = current.get(part);

            if (value == null) {
                return null;
            }

            // If this is a lookup/reference field,
            // return related record Name instead of Id.
            Schema.DescribeFieldResult fieldDescribe =
                current.getSObjectType()
                    .getDescribe()
                    .fields
                    .getMap()
                    .get(part)
                    .getDescribe();

            if (
                fieldDescribe.getType() ==
                Schema.DisplayType.REFERENCE
            ) {

                Id referenceId = (Id)value;

                List<Schema.SObjectType> referenceTypes =
                    fieldDescribe.getReferenceTo();

                if (!referenceTypes.isEmpty()) {
                    String refObjName = String.escapeSingleQuotes(referenceTypes[0].getDescribe().getName());
                    String refQuery = 'SELECT Name FROM ' + refObjName + ' WHERE Id = :referenceId LIMIT 1';
                    List<SObject> referenceRecords = Database.queryWithBinds(
                        refQuery,
                        new Map<String, Object>{'referenceId' => referenceId},
                        AccessLevel.SYSTEM_MODE
                    );

                    if (!referenceRecords.isEmpty()) {
                        return referenceRecords[0].get('Name');
                    }
                }
            }

            return value;
        }

        // Relationship field
        current = current.getSObject(part);

        if (current == null) {
            return null;
        }
    }

    return null;
}


    // ============================================================
    // FIELD LABEL
    // ============================================================

    @TestVisible
    private static String generateLabel(
        String fieldName
    ) {

        if (String.isBlank(fieldName)) {
            return '';
        }


        String value =
            fieldName.substringAfterLast('.');


        value =
            value
                .replace('__c', '')
                .replace('__r', '')
                .replace('_', ' ');


        return value;
    }


    // ============================================================
    // VALUE FORMAT
    // ============================================================

    @TestVisible
    private static String formatValue(
        Object value
    ) {

        if (value == null) {
            return '';
        }


        if (value instanceof Date) {

            return ((Date)value)
                .format();
        }


        if (value instanceof Datetime) {

            return ((Datetime)value)
                .format(
                    'dd/MM/yyyy hh:mm a'
                );
        }


        return String.valueOf(value);
    }


    // ============================================================
    // STEP NAME
    // ============================================================

    @TestVisible
    private static String getStepName(
        Business_Process_Step__c step
    ) {

        if (
            String.isNotBlank(
                step.Business_Process_Steps_Name_Custom__c
            )
        ) {

            return
                step.Business_Process_Steps_Name_Custom__c;
        }


        if (
            String.isNotBlank(
                step.Step__c
            )
        ) {

            return step.Step__c;
        }


        return step.Name;
    }


    // ============================================================
    // ASSIGNED USER
    // ============================================================

    private static String getAssignedUser(
        Business_Process_Step__c step
    ) {

        if (
            step.Assigned_To__r != null
        ) {

            return
                step.Assigned_To__r.Name;
        }


        if (
            step.Owner != null
        ) {

            return step.Owner.Name;
        }


        return '';
    }


    // ============================================================
    // EXISTING METHOD
    // ============================================================

    @AuraEnabled(cacheable=true)
    public static StepItemWrapper getActiveBpStepRecord(
        String bpRecordId,
        String bpStepRecordId
    ) {

        StepItemWrapper si =
            new StepItemWrapper();

        List<Reviewer_Comment__c> reComms = new List<Reviewer_Comment__c>();
        if (Schema.sObjectType.Reviewer_Comment__c.fields.getMap().containsKey('Business_Process__c')) {
            try {
                Map<String, Object> bindVars = new Map<String, Object>{ 'bpId' => bpRecordId };
                reComms = Database.queryWithBinds(
                    'SELECT Id FROM Reviewer_Comment__c WHERE Business_Process__c = :bpId',
                    bindVars,
                    AccessLevel.USER_MODE
                );
            } catch (Exception e) {
                // Ignore if field is not accessible for the user
            }
        }


        // Use dynamic SOQL to safely handle orgs where the Business_Process__r
        // relationship may not exist or have a different name
        List<Business_Process_Step__c> bpsSteps = new List<Business_Process_Step__c>();
        try {
            Map<String, Object> stepBinds = new Map<String, Object>{ 'bpStepRecordId' => bpStepRecordId };
            bpsSteps = Database.queryWithBinds(
                'SELECT Id, Process_Flow_Step__c, Is_Required_More_Button_Required__c,' +
                ' Process_Identifier_Options__c, Field_Rendering__c, Form_Rendering__c,' +
                ' Is_Sequence_Business_Process_Available__c,' +
                ' Business_Process__r.Latest_Process_Checklist__c,' +
                ' Assigned_To__r.Name, Business_Process__c,' +
                ' Business_Process__r.Name, Business_Process__r.Type__c,' +
                ' Business_Process__r.Sales_Order__c,' +
                ' Assigned_To__c, Step__c, Is_check_List__c, View_review_comments__c,' +
                ' Is_Review_Comments_Req__c, Is_Reject_Button_Required__c,' +
                ' Is_Submit_to_Next_Department_Required__c, Choose_Next_Owner__c,' +
                ' Is_Assigned_TO__c, Name, Status__c, Owner.Name' +
                ' FROM Business_Process_Step__c' +
                ' WHERE Id = :bpStepRecordId LIMIT 1',
                stepBinds,
                AccessLevel.SYSTEM_MODE
            );
        } catch (Exception e) {
            // Gracefully skip if relationship not available in this org
        }

        for (Business_Process_Step__c step : bpsSteps) {

            si.Id =
                step.Id;

            si.Name =
                step.Name;

            si.Status =
                step.Status__c;

            si.AssignedTo =
                step.Assigned_To__c;

            si.ownerName =
                step.Owner.Name;

            si.AssignedName =
                step.Assigned_To__r.Name;


            si.isCheckList =
                step.Is_check_List__c;

            si.parentId =
                step.Business_Process__c;

            si.currentCheckListItem =
                step.Business_Process__r.Latest_Process_Checklist__c;

            si.isNextSectionAvailable =
                step.Is_Sequence_Business_Process_Available__c;

            si.processIdenOptions =
                step.Process_Identifier_Options__c;

            si.formRendering =
                step.Form_Rendering__c;

            si.fieldRendering =
                step.Field_Rendering__c;

            si.ChooseNextOwner =
                step.Choose_Next_Owner__c;

            si.isRejectButtonRequired =
                step.Is_Reject_Button_Required__c;

            si.isRequiredInfoButtonRequired =
                step.Is_Required_More_Button_Required__c;

            si.isSubmittoNextDeptRequired =
                step.Is_Submit_to_Next_Department_Required__c;

            si.isReviewCommentsReq =
                step.Is_Review_Comments_Req__c;

            si.isAssinedTO =
                step.Is_Assigned_TO__c;

            si.viewReviewComments =
                step.View_review_comments__c &&
                reComms.size() > 0;

            si.canViewReviewComments =
                step.View_review_comments__c;

            si.processFlowStep =
                step.Process_Flow_Step__c;

            si.businessProcessName =
                step.Business_Process__r.Name;

            si.businessProcessType =
                step.Business_Process__r.Type__c;

            si.salesOrderId =
                step.Business_Process__r.Sales_Order__c;
        }


        return si;
    }


    // ============================================================
    // EXISTING COMPLETED STEPS
    // ============================================================

    @AuraEnabled(cacheable=true)
    public static List<Business_Process_Step__c>
        getCompletedBPStepRecords(
            String bpRecordId
        ) {

        String objectName =
            getObjectApiNameById(
                bpRecordId
            );


        if (
            objectName ==
            'Business_Process__c'
        ) {
            try {
                Map<String, Object> binds = new Map<String, Object>{ 'bpRecordId' => bpRecordId };
                return Database.queryWithBinds(
                    'SELECT Id, Step__c, Name, Status__c, Assigned_To__r.Name, Owner.Name, Remarks_Comments__c, ' +
                    'LastModifiedDate, Step_Open_Time__c, Assigned_Time__c, Completed_Time__c ' +
                    'FROM Business_Process_Step__c WHERE Business_Process__c = :bpRecordId ORDER BY CreatedDate ASC',
                    binds,
                    AccessLevel.SYSTEM_MODE
                );
            } catch (Exception e) {
                try {
                    Map<String, Object> binds = new Map<String, Object>{ 'bpRecordId' => bpRecordId };
                    return Database.queryWithBinds(
                        'SELECT Id, Name, Status__c, Assigned_To__r.Name, Owner.Name, Remarks_Comments__c, ' +
                        'LastModifiedDate, Step_Open_Time__c, Assigned_Time__c, Completed_Time__c ' +
                        'FROM Business_Process_Step__c WHERE Business_Process__c = :bpRecordId ORDER BY CreatedDate ASC',
                        binds,
                        AccessLevel.SYSTEM_MODE
                    );
                } catch (Exception ex) {
                    return new List<Business_Process_Step__c>();
                }
            }
        }


        return new List<Business_Process_Step__c>();
    }


    // ============================================================
    // OBJECT API NAME
    // ============================================================

    @AuraEnabled(cacheable=true)
    public static String getObjectApiNameById(
        String recordId
    ) {

        if (
            String.isBlank(recordId)
        ) {
            return null;
        }


        try {

            Id recordIdValue =
                (Id)recordId;

            return
                recordIdValue
                    .getSObjectType()
                    .getDescribe()
                    .getName();

        } catch (Exception e) {

            return null;
        }
    }


    // ============================================================
    // EXISTING APPROVAL ACTION
    // ============================================================

    @AuraEnabled
    public static String handleApprovalAction(
        String workItemId,
        String actionType,
        String comments
    ) {

        Approval.ProcessWorkitemRequest pwr =
            new Approval.ProcessWorkitemRequest();

        pwr.setComments(
            comments
        );

        pwr.setAction(
            actionType
        );

        pwr.setWorkitemId(
            workItemId
        );


        List<Approval.ProcessResult> results =
            Approval.process(
                new List<Approval.ProcessWorkitemRequest>{
                    pwr
                }
            );


        Approval.ProcessResult result =
            results[0];


        if (result.isSuccess()) {

            return
                result.getInstanceStatus();
        }


        List<String> errors =
            new List<String>();


        for (
            Database.Error err :
            result.getErrors()
        ) {

            errors.add(
                err.getMessage()
            );
        }


        throw new AuraHandledException(
            'Approval failed: ' +
            String.join(
                errors,
                '; '
            )
        );
    }


    // ============================================================
    // WRAPPERS
    // ============================================================

    public class ApprovalDashboardWrapper {

        @AuraEnabled
        public Id businessProcessId;

        @AuraEnabled
        public Id currentStepId;

        @AuraEnabled
        public String businessProcessName;

        @AuraEnabled
        public String businessProcessType;

        @AuraEnabled
        public String businessProcessSubcategory;

        @AuraEnabled
        public String currentStepName;

        @AuraEnabled
        public String status;

        @AuraEnabled
        public String assignedTo;

        @AuraEnabled
        public List<FieldWrapper>
            currentStepFields =
                new List<FieldWrapper>();

        @AuraEnabled
        public List<PreviousStepWrapper>
            previousSteps =
                new List<PreviousStepWrapper>();
    }


    public class PreviousStepWrapper {

        @AuraEnabled
        public Id id;

        @AuraEnabled
        public String stepName;

        @AuraEnabled
        public String status;

        @AuraEnabled
        public String assignedTo;

        @AuraEnabled
        public List<FieldWrapper>
            fields =
                new List<FieldWrapper>();
    }


    public class FieldWrapper {

        @AuraEnabled
        public String apiName;

        @AuraEnabled
        public String label;

        @AuraEnabled
        public String value;

        @AuraEnabled
        public Decimal sequence;

        @AuraEnabled
        public Boolean mobile;

        @AuraEnabled
        public Boolean desktop;
    }


    @TestVisible
    private class GridConfig {

        @TestVisible public String objectName;
        @TestVisible public String fieldName;
        @TestVisible public Decimal sequence;
        @TestVisible public String bpType;
        @TestVisible public String stepName;
        @TestVisible public Boolean active;
        @TestVisible public Boolean mobile;
        @TestVisible public Boolean desktop;
        @TestVisible public String label;
    }


    public class StepItemWrapper {

        @AuraEnabled public String Id;
        @AuraEnabled public String Name;
        @AuraEnabled public String Status;
        @AuraEnabled public String AssignedTo;
        @AuraEnabled public String ownerName;
        @AuraEnabled public String AssignedName;
        @AuraEnabled public Boolean isCheckList;
        @AuraEnabled public String parentId;
        @AuraEnabled public String currentCheckListItem;
        @AuraEnabled public Boolean isNextSectionAvailable;
        @AuraEnabled public String processIdenOptions;
        @AuraEnabled public Boolean formRendering;
        @AuraEnabled public Boolean fieldRendering;
        @AuraEnabled public Boolean ChooseNextOwner;
        @AuraEnabled public Boolean isRejectButtonRequired;
        @AuraEnabled public Boolean isRequiredInfoButtonRequired;
        @AuraEnabled public Boolean isSubmittoNextDeptRequired;
        @AuraEnabled public Boolean isReviewCommentsReq;
        @AuraEnabled public Boolean viewReviewComments;
        @AuraEnabled public Boolean canViewReviewComments;
        @AuraEnabled public Boolean isAssinedTO;
        @AuraEnabled public String processFlowStep;
        @AuraEnabled public String businessProcessName;
        @AuraEnabled public String businessProcessType;
        @AuraEnabled public String salesOrderId;
    }


@AuraEnabled(cacheable=true)
public static List<Map<String, Object>> getPendingStepFields(Id stepRecordId) {
    List<Map<String, Object>> result =new List<Map<String, Object>>();

    if (stepRecordId == null) {
        return result;
    }
    // ============================================================
    // 1. GET CURRENT BUSINESS PROCESS TYPE
    // ============================================================

        Business_Process_Step__c stepRecord;
        try {
            Map<String, Object> binds = new Map<String, Object>{ 'stepId' => stepRecordId };
            List<Business_Process_Step__c> stepList = Database.queryWithBinds(
                'SELECT Id, Business_Process__r.Type__c FROM Business_Process_Step__c WHERE Id = :stepId LIMIT 1',
                binds,
                AccessLevel.SYSTEM_MODE
            );
            if (!stepList.isEmpty()) {
                stepRecord = stepList[0];
            }
        } catch (Exception e) {
            // Relationship may not exist in this org
        }

        String businessProcessType;

        if (stepRecord != null && stepRecord.Business_Process__r != null) {
            businessProcessType =
                stepRecord.Business_Process__r.Type__c;
        }


    // ============================================================
    // 2. TRY BUSINESS PROCESS TYPE CONFIG FIRST
    // ============================================================

    List<BP_Pending_Step_Fields__mdt> configs =
        new List<BP_Pending_Step_Fields__mdt>();


    if (String.isNotBlank(businessProcessType)) {

        configs = [
            SELECT
                Type__c,
                Field_API_Name__c,
                Field_Label__c,
                Display_Order__c,
                Active__c
            FROM BP_Pending_Step_Fields__mdt
            WHERE Type__c = :businessProcessType
            AND Active__c = true
            ORDER BY Display_Order__c ASC
        ];
    }


    // ============================================================
    // 3. IF NO CONFIG FOUND, USE DEFAULT CONFIG
    // ============================================================

    if (configs.isEmpty()) {

        configs = [
            SELECT
                Type__c,
                Field_API_Name__c,
                Field_Label__c,
                Display_Order__c,
                Active__c
            FROM BP_Pending_Step_Fields__mdt
            WHERE Type__c = 'Default Config'
            AND Active__c = true
            ORDER BY Display_Order__c ASC
        ];
    }


    // ============================================================
    // 4. IF EVEN DEFAULT CONFIG DOES NOT EXIST
    // ============================================================

    if (configs.isEmpty()) {
        return result;
    }


    // ============================================================
    // 5. BUILD FIELD LIST FROM METADATA
    // ============================================================

    Set<String> fieldsToQuery =
        new Set<String>();

    fieldsToQuery.add('Id');


    for (
        BP_Pending_Step_Fields__mdt config :
        configs
    ) {

        if (
            String.isNotBlank(
                config.Field_API_Name__c
            )
        ) {

            fieldsToQuery.add(
                config.Field_API_Name__c
            );
        }
    }


    // ============================================================
    // 6. QUERY BUSINESS PROCESS STEP DYNAMICALLY
    // ============================================================

    String soql =
        'SELECT ' +
        String.join(
            new List<String>(fieldsToQuery),
            ','
        ) +
        ' FROM Business_Process_Step__c' +
        ' WHERE Id = :stepRecordId' +
        ' LIMIT 1';


    System.debug(
        'Pending Step Dynamic SOQL => ' +
        soql
    );


    SObject currentStep =
        Database.queryWithBinds(
            soql,
            new Map<String, Object>{
                'stepRecordId' => stepRecordId
            },
            AccessLevel.SYSTEM_MODE
        );


    // ============================================================
    // 7. GET FIELD DESCRIBE
    // ============================================================

    Schema.SObjectType stepObjectType =
        Schema.getGlobalDescribe().get(
            'Business_Process_Step__c'
        );


    if (stepObjectType == null) {
        return result;
    }


    Map<String, Schema.SObjectField> fieldMap =
        stepObjectType
            .getDescribe()
            .fields
            .getMap();


    // ============================================================
    // 8. BUILD RESPONSE FOR LWC
    // ============================================================

    for (
        BP_Pending_Step_Fields__mdt config :
        configs
    ) {

        String fieldApiName =
            config.Field_API_Name__c;


        if (String.isBlank(fieldApiName)) {
            continue;
        }


        Object fieldValue;


        // ========================================================
        // RELATIONSHIP FIELD
        //
        // Examples:
        // Assigned_To__r.Name
        // Owner.Name
        // Business_Process__r.Name
        // ========================================================

        if (fieldApiName.contains('.')) {

            fieldValue =
                getRelationshipValue(
                    currentStep,
                    fieldApiName
                );

        } else {

            // ====================================================
            // NORMAL FIELD
            // ====================================================

            if (!fieldMap.containsKey(fieldApiName)) {
                continue;
            }


            fieldValue =
                currentStep.get(
                    fieldApiName
                );
        }


        // ========================================================
        // FORMAT VALUE
        // ========================================================

        String displayValue =
            formatFieldValue(
                fieldValue
            );


        // ========================================================
        // RETURN FIELD TO LWC
        // ========================================================

        result.add(
            new Map<String, Object>{

                'fieldName' =>
                    fieldApiName,

                'label' =>
                    String.isNotBlank(
                        config.Field_Label__c
                    )
                    ? config.Field_Label__c
                    : fieldApiName,

                'value' =>
                    displayValue,

                'hasValue' =>
                    String.isNotBlank(
                        displayValue
                    ),

                'displayOrder' =>
                    config.Display_Order__c
            }
        );
    }


    return result;
}

@TestVisible
private static String formatFieldValue(
    Object value
) {
    if (value == null) {
        return '';
    }

    if (value instanceof Date) {
        return ((Date)value).format();
    }

    if (value instanceof Datetime) {
        return ((Datetime)value).format();
    }

    return String.valueOf(value);
}

@TestVisible
private static Object getRelationshipValue(
    SObject record,
    String fieldPath
) {
    List<String> parts =
        fieldPath.split('\\.');

    SObject currentRecord = record;

    for (Integer i = 0; i < parts.size(); i++) {

        if (currentRecord == null) {
            return null;
        }

        String part = parts[i];

        if (i == parts.size() - 1) {

            return currentRecord.get(part);

        } else {

            currentRecord =
                currentRecord.getSObject(part);
        }
    }

    return null;
}


    // ============================================================
    // PAYMENT EXTENSION SUMMARY
    // ============================================================

    @AuraEnabled(cacheable=true)
    public static PaymentExtensionSummaryWrapper getPaymentExtensionSummary(
        String bpStepRecordId
    ) {

        PaymentExtensionSummaryWrapper summary =
            new PaymentExtensionSummaryWrapper();

        if (String.isBlank(bpStepRecordId)) {
            return summary;
        }

        List<Business_Process_Step__c> steps = new List<Business_Process_Step__c>();
        try {
            Map<String, Object> binds = new Map<String, Object>{ 'bpStepId' => bpStepRecordId };
            steps = Database.queryWithBinds(
                'SELECT Business_Process__r.Type__c, Business_Process__r.Payment_Extension_Date__c,' +
                ' Business_Process__r.Sales_Order_Installment__r.MilestoneNumber__c,' +
                ' Business_Process__r.Sales_Order_Installment__r.MilestoneDate__c,' +
                ' Business_Process__r.Sales_Order_Installment__r.InstallmentAmount__c' +
                ' FROM Business_Process_Step__c WHERE Id = :bpStepId LIMIT 1',
                binds,
                AccessLevel.SYSTEM_MODE
            );
        } catch (Exception e) {
            return summary;
        }

        if (steps.isEmpty()) {
            return summary;
        }

        Business_Process__c bp = steps[0].Business_Process__r;
        if (bp == null) {
            return summary;
        }

        Boolean isPaymentExtension =
            (bp.Type__c == 'Payment Extension');

        summary.showMilestoneInfo = isPaymentExtension;

        if (!isPaymentExtension) {
            return summary;
        }

        summary.extendedDate =
            bp.Payment_Extension_Date__c;

        SalesOrderInstallments__c soi =
            bp.Sales_Order_Installment__r;

        if (soi != null) {

            summary.milestoneNumber =
                soi.MilestoneNumber__c;

            summary.spaDate =
                soi.MilestoneDate__c;

            summary.installmentAmount =
                soi.InstallmentAmount__c;
        }

        return summary;
    }


    public class PaymentExtensionSummaryWrapper {

        @AuraEnabled public Boolean showMilestoneInfo = false;
        @AuraEnabled public Decimal milestoneNumber;
        @AuraEnabled public Date spaDate;
        @AuraEnabled public Date extendedDate;
        @AuraEnabled public Decimal installmentAmount;
    }


    // ============================================================
    // EOI REFUND SUMMARY
    // ============================================================

    @AuraEnabled(cacheable=true)
    public static EOIRefundSummaryWrapper getEOIRefundSummary(
        String bpStepRecordId
    ) {

        EOIRefundSummaryWrapper summary = new EOIRefundSummaryWrapper();

        if (String.isBlank(bpStepRecordId)) {
            return summary;
        }

        List<Business_Process_Step__c> steps = new List<Business_Process_Step__c>();
        try {
            Map<String, Object> binds = new Map<String, Object>{ 'bpStepId' => bpStepRecordId };
            steps = Database.queryWithBinds(
                'SELECT Business_Process__c, Business_Process__r.Type__c' +
                ' FROM Business_Process_Step__c WHERE Id = :bpStepId LIMIT 1',
                binds,
                AccessLevel.SYSTEM_MODE
            );
        } catch (Exception e) {
            return summary;
        }

        if (steps.isEmpty()) {
            return summary;
        }

        Business_Process__c bp = steps[0].Business_Process__r;
        if (bp == null) {
            return summary;
        }

        Boolean isEOIRefundApproval =
            (bp.Type__c == 'EOI Refund Approval');

        summary.showEOIList = isEOIRefundApproval;

        if (!isEOIRefundApproval) {
            return summary;
        }

        Id bpId = steps[0].Business_Process__c;
        Map<String, Object> eoiBinds = new Map<String, Object>{ 'bpId' => bpId };
        List<Expressionofinterest__c> eois = Database.queryWithBinds(
            'SELECT Id, Name, EOIId__c, Account__r.Name, Project__r.Name, EOI_Amount_AED__c' +
            ' FROM Expressionofinterest__c' +
            ' WHERE Business_Process__c = :bpId' +
            ' ORDER BY CreatedDate ASC',
            eoiBinds,
            AccessLevel.SYSTEM_MODE
        );

        for (Expressionofinterest__c eoi : eois) {

            EOIWrapper item = new EOIWrapper();
            item.id = eoi.Id;
            item.name = eoi.Name;
            item.eoiId = eoi.EOIId__c;
            item.accountName = eoi.Account__r != null ? eoi.Account__r.Name : null;
            item.projectName = eoi.Project__r != null ? eoi.Project__r.Name : null;
            item.eoiAmountAED = eoi.EOI_Amount_AED__c;

            summary.eois.add(item);
        }

        return summary;
    }


    public class EOIRefundSummaryWrapper {

        @AuraEnabled public Boolean showEOIList = false;
        @AuraEnabled public List<EOIWrapper> eois = new List<EOIWrapper>();
    }


    public class EOIWrapper {

        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String eoiId;
        @AuraEnabled public String accountName;
        @AuraEnabled public String projectName;
        @AuraEnabled public Decimal eoiAmountAED;
    }
}