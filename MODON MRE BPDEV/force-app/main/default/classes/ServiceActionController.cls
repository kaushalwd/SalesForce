/**
* @description       : 
* @author            : Krishna Chaitanya
* @group             : 
* @last modified on  : 07-31-2025
* @last modified by  : Krishna Chaitanya
**/
public with sharing class ServiceActionController {
    /**
         * @description : Constructor for StepWrapper.
         * @param id          : ServiceAction__c record Id
         * @param label       : ServiceAction__c Name
         * @param value       : ServiceCatalog__r.Name
         * @param status      : 'current', 'complete', or 'incomplete'
         * @param description : ServiceAction__c Description__c
         * @param selected    : true if this step is the current active step
         */
    public class StepWrapper {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String value { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String description { get; set; }
        @AuraEnabled public Boolean selected { get; set; }
        
        public StepWrapper(String id, String label, String value, String status, String description, Boolean selected) {
            this.id = id;
            this.label = label;
            this.value = value;
            this.status = status;
            this.description = description;
            this.selected = selected;
        }
    }
     /**
     * @description   : (Legacy / cacheable) Returns a flat list of StepWrapper objects
     *                  representing all ServiceAction__c steps for the SR's record type.
     *                  Compares the most recent Task's Subject and Order__c to determine
     *                  each step's status:
     *                    'current'    — Task subject matches this action's TaskSubject__c
     *                    'complete'   — Task order is higher than this action's Order__c
     *                    'incomplete' — Task order is lower than this action's Order__c
     *
     *                  Business Rule: Uses the most recently created Task (DESC by
     *                  CreatedDate). Returns empty list if recordId is null, SR not
     *                  found, or no Tasks exist.
     *
     * @param recordId : Id of the ServiceRequest__c record
     * @return         : List<StepWrapper> — ordered list of steps with status set,
     *                   or an empty list if prerequisites are not met
     */
@AuraEnabled(cacheable=true)
    public static List<StepWrapper> getServiceActions(Id recordId) {
        if (recordId == null) return new List<StepWrapper>();
        List<ServiceRequest__c> serviceRequests = [SELECT Id, Name, RecordType.Name,SalesOrder__r.ProjectName__c FROM ServiceRequest__c WHERE Id = :recordId LIMIT 1];
        if (serviceRequests.isEmpty()) return new List<StepWrapper>();
        ServiceRequest__c serviceRequest = serviceRequests[0];
        Boolean isCommercial = false;
        
    if (
        serviceRequest.SalesOrder__r != null &&
        serviceRequest.SalesOrder__r.ProjectName__c != null &&
        serviceRequest.SalesOrder__r.ProjectName__c == 'Commercial Plots'
    ) {
        isCommercial = true;
    }
        
    System.debug('Project Name: ' + serviceRequest.SalesOrder__r.ProjectName__c);
    System.debug('Is Commercial: ' + isCommercial);
        List<Task> tasks = [SELECT Id, Subject, Status, Order__c, CreatedDate FROM Task WHERE WhatId = :recordId ORDER BY CreatedDate DESC LIMIT 1];
        if (tasks.isEmpty()) return new List<StepWrapper>();
        
        Task lastTask = tasks[0];
        /*List<ServiceAction__c> serviceActions = [
            SELECT Id, Name, TaskSubject__c, Order__c, Description__c, ServiceCatalog__r.Name 
            FROM ServiceAction__c
            WHERE ServiceCatalog__r.Service_Request_Type__c = :serviceRequest.RecordType.Name 
            ORDER BY Order__c ASC
        ];*/
            List<ServiceAction__c> serviceActions;
        
    if (isCommercial) { // added new line for COmmerical plots V1 start
        // ONLY Commercial actions
        serviceActions = [SELECT Id,Name,TaskSubject__c,Order__c,Description__c,PropertyType__c,ServiceCatalog__r.Name
            FROM ServiceAction__c WHERE ServiceCatalog__r.Service_Request_Type__c =:serviceRequest.RecordType.Name
            AND PropertyType__c = 'Commercial' ORDER BY Order__c ASC ];
    }
    else {
        // Non Commercial + NULL
        serviceActions = [SELECT Id,Name,TaskSubject__c,Order__c,Description__c,PropertyType__c,ServiceCatalog__r.Name
            FROM ServiceAction__c WHERE ServiceCatalog__r.Service_Request_Type__c = :serviceRequest.RecordType.Name
            AND (PropertyType__c != 'Commercial' OR PropertyType__c = NULL) ORDER BY Order__c ASC ];
    }   //ends here.  
        List<StepWrapper> stepWrappers = new List<StepWrapper>();
        for (ServiceAction__c action : serviceActions) {
            String status = (lastTask.Subject == action.TaskSubject__c) ? 'current' : (lastTask.Order__c > action.Order__c) ? 'complete' : 'incomplete';
            stepWrappers.add(new StepWrapper(action.Id, action.Name, action.ServiceCatalog__r.Name, status, action.Description__c, status == 'current'));
        }
        return stepWrappers;
    }
     /**
     * @description : Wrapper for a single child step within a step group.
     *                Holds UI state flags (IsOpen, IsClosed, nextstep),
     *                step metadata (SLA, ActionType, helpText), and
     *                references to linked SR, Task, and ServiceAction records.
     *
     *                Default constructor sets:
     *                  IsOpen = false, IsClosed = false, clientstep = false,
     *                  ActionType = '', nextstep = false, status = ''
     */
    // new UI    
    @AuraEnabled public static list <StepGroupWrap> lstGroupWrap {get;set;}
    @AuraEnabled public static string GroupWidth {get;set; }
    @AuraEnabled public static LtngStepGroupWrapper ltngStepGroupObj { get; set; }
    
    public class StepGroupChildData {
        @AuraEnabled public string StepSummary { get;set; }
        @AuraEnabled public string StepId { get;  set;   }
        @AuraEnabled public string TaskId { get;  set;   }
        @AuraEnabled public string StepLoop {get; set;  }
        @AuraEnabled public boolean nextstep { get; set; }
        @AuraEnabled public boolean hasStep {  get; set;}
        @AuraEnabled public boolean IsOpen {get; set; }
        @AuraEnabled public boolean IsClosed { get;set; }
        @AuraEnabled public string helpText { get; set; }
        @AuraEnabled public string SLA { get;set; }
        @AuraEnabled public string ActionType { get;set; }
        @AuraEnabled public string SRID { get; set;}
        @AuraEnabled public boolean QuickActionStep {get;set; }
        @AuraEnabled public string status {  get;set; }
        @AuraEnabled public string stpNotes { get;set; }
        @AuraEnabled public boolean clientstep {get; set; }
        @AuraEnabled public date closedDate {get; set; }
        @AuraEnabled public date reSubmissionDate {get; set; }
        public StepGroupChildData() {
            IsOpen = false;
            IsClosed = false;
            clientstep = false;
            ActionType = '';
            nextstep =false;
            status='';
        }
    }
    /**
     * @description : Top-level wrapper returned by getStepGroupWrapper().
     *                Holds SR-level metadata (status, dates, fees, record type)
     *                and the full list of StepGroupWrap objects for the UI.
     */
    public class LtngStepGroupWrapper {
        @AuraEnabled public string totalTime {get; set;}
        @AuraEnabled public list < StepGroupWrap > lstLtngGroupWrapper {get;set; }
        @AuraEnabled public string estimatedHours { get; set; }
        @AuraEnabled public string srStatus { get; set;}
        @AuraEnabled public string srJoType { get; set;}
        @AuraEnabled public Date daridate { get; set; }
        @AuraEnabled public Date extensionDate { get; set; }
        @AuraEnabled public Date approvedExtensionDate {get; set;}
        @AuraEnabled public String darinumber { get; set; }
        @AuraEnabled public decimal admamount { get; set; }
        @AuraEnabled public decimal penalityamount { get; set; }
        @AuraEnabled public boolean penalitycheck { get; set; }
        @AuraEnabled public String recordTypeName { get; set; }
       @AuraEnabled public decimal outstandingCharge { get; set; }

    }
    /**
     * @description : Wrapper for a single step group (stage/phase) in the UI.
     *                Contains a label, order, current/passed state flags, SLA,
     *                and a list of child step data objects.
     *
     *                Default constructor sets:
     *                  lstChilds = empty list, CurrentGroup = false,
     *                  Passed_Group = false, Order = 0
     */
    public class StepGroupWrap {
        @AuraEnabled public string GroupLabel { get;set; }
        @AuraEnabled public string GroupShortLabel { get; set;}
        @AuraEnabled public boolean CurrentGroup { get; set; } 
        @AuraEnabled public boolean Passed_Group { get; set; }
        @AuraEnabled public integer Order { get; set; }
        @AuraEnabled public list < StepGroupChildData > lstChilds { get;set; }
        @AuraEnabled public string SLA { get; set;}
        
        public StepGroupWrap() {
            lstChilds = new list < StepGroupChildData > ();
            CurrentGroup = false;
            Passed_Group = false;
            
            Order=0;
        }
    }
    /**
     * @description            : Main data loader for the step-group UI component.
     *                           Loads all SR-level metadata and delegates step-group
     *                           construction to PrepareGroups().
     *
     *                           Populates LtngStepGroupWrapper with:
     *                             - SR Status, JO subtype, record type name
     *                             - Dari date, NOC extension dates, Dari number
     *                             - ADM fee, penalty amount and flag
     *                             - Outstanding charge
     *                             - Total elapsed time since SR creation (formatted)
     *                             - Full step group list
     *
     *                           Business Rule: Elapsed time is computed as the
     *                           difference between now (GMT) and SR.CreatedDate,
     *                           formatted via getFormattedTimeTaken() as minutes,
     *                           hours, or days.
     *
     * @param serviceRequestId : Id (as String) of the ServiceRequest__c
     * @return                 : LtngStepGroupWrapper — fully populated top-level wrapper
     */
    @AuraEnabled
    public static LtngStepGroupWrapper getStepGroupWrapper(string serviceRequestId) {
        Datetime submittedDateTime;
        Date daridate;
        Date extensionDate;
        Date approvedExtensionDate;
        decimal admamount;
        decimal penalityamount;
        boolean penalitycheck;
        
        String darinumber;
        string strSRStatus;
        String srJoType;
        string subtype;
        string recordTypeName;
        string salesOrderId;
        decimal outstandingCharge;
        if (serviceRequestId != null) {
            for (ServiceRequest__c sr: [select Id, Name,Outstanding_Charge__c,NOC_Extension_Date__c,Approved_NOC_Extension_Date__c, RecordType.Name,SalesOrder__c,ADM_Fee__c,SubType__c,Penality_Charge__c,createdDate,Dari_Application_Submitted_Date__c,Dari_Application_Number__c,Type__c,Status__c FROM ServiceRequest__c WHERE Id = :serviceRequestId]) {
                submittedDateTime = sr.createdDate;
                strSRStatus = sr.Status__c;
                srJoType = sr.SubType__c;
                subtype = sr.Type__c;
                daridate= sr.Dari_Application_Submitted_Date__c;
                extensionDate=sr.NOC_Extension_Date__c;
                approvedExtensionDate = sr.Approved_NOC_Extension_Date__c;
                darinumber=sr.Dari_Application_Number__c;
                outstandingCharge=sr.Outstanding_Charge__c;
                admamount= sr.ADM_Fee__c;
                penalitycheck = sr.Penality_Charge__c;
                recordTypeName = sr.RecordType.Name;
                salesOrderId=sr.SalesOrder__c;       
            }
        }
        
        Datetime currentDateTime = DateTime.now();
        Datetime GMTDate = Datetime.newInstanceGmt(
            currentDateTime.year(),
            currentDateTime.month(),
            currentDateTime.day(),
            currentDateTime.hour(),
            currentDateTime.minute(),
            currentDateTime.second());
        ltngStepGroupObj = new LtngStepGroupWrapper();
        ltngStepGroupObj.srStatus = strSRStatus;
        ltngStepGroupObj.srJoType = srJoType;
        ltngStepGroupObj.daridate = daridate;
        ltngStepGroupObj.darinumber = darinumber;
        ltngStepGroupObj.outstandingCharge = outstandingCharge;
        ltngStepGroupObj.admamount = admamount;
        ltngStepGroupObj.penalitycheck=penalitycheck;
        ltngStepGroupObj.penalityamount = penalityamount;
        ltngStepGroupObj.extensionDate=extensionDate;
        ltngStepGroupObj.approvedExtensionDate=approvedExtensionDate;
        ltngStepGroupObj.recordTypeName = recordTypeName;
        
        
        if (submittedDateTime != null) {
            Long seconds = (GMTDate.getTime() - submittedDateTime.getTime()) / 1000;
            Long minutes = seconds / 60;
            ltngStepGroupObj.totalTime = getFormattedTimeTaken(integer.valueof(minutes));// hours > 24 ? String.valueOf(days) + ' day(s)' : string.valueOf(math.floor(hours)) + ' hour(s)';
            
        }
        
        ltngStepGroupObj.lstLtngGroupWrapper = PrepareGroups(serviceRequestId,recordTypeName,subtype,strSRStatus);
        
        system.debug('ltngStepGroupObj:::'+ltngStepGroupObj);
        return ltngStepGroupObj;
    }
    /**
     * @description   : LWC entry point for Property Transfer placeholder flow.
     *                  Delegates to PropertyTransferProcessController.executePropertyExecutionsFlow().
     *                  Wraps any exception in AuraHandledException for LWC error handling.
     *
     * @param recordId : Id of the ServiceRequest__c
     * @return         : String — 'success' on completion
     * @throws         : AuraHandledException — wraps any exception message
     */
    @AuraEnabled
    public static string doCallout(Id recordId){
        try {
            PropertyTransferProcessController.executePropertyExecutionsFlow(recordId);
            return 'success';
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    /**
     * @description   : LWC entry point for Property Transfer Step 1 execution.
     *                  Delegates to PropertyTransferProcessController.executePropertyExecutionsFlowstep1(),
     *                  which dispatches to processServiceRequest(), ptTitleDeedprocessServiceRequest(),
     *                  or UpgradeprocessServiceRequest() based on SR record type.
     *                  Wraps any exception in AuraHandledException for LWC error handling.
     *
     * @param recordId : Id of the ServiceRequest__c
     * @return         : String — 'success' on completion
     * @throws         : AuraHandledException — wraps any exception message
     */
    @AuraEnabled
    public static string doCalloutStep1(Id recordId){
        try {
            PropertyTransferProcessController.executePropertyExecutionsFlowstep1(recordId);
            return 'success';
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /**
     * @description   : LWC entry point for Property Transfer Step 2 placeholder.
     *                  Delegates to PropertyTransferProcessController.executePropertyExecutionsFlowstep2().
     *                  Wraps any exception in AuraHandledException for LWC error handling.
     *
     * @param recordId : Id of the ServiceRequest__c
     * @return         : String — 'success' on completion
     * @throws         : AuraHandledException — wraps any exception message
     */
    @AuraEnabled
    public static string doCalloutStep2(Id recordId){
        try {
            PropertyTransferProcessController.executePropertyExecutionsFlowstep2(recordId);
            return 'success';
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
     /**
     * @description   : Alternative LWC entry point for the new Property Transfer UI design.
     *                  Functionally identical to doCalloutStep1() — both delegate to
     *                  executePropertyExecutionsFlowstep1().
     *                  Provided as a separate method for new UI component wiring.
     *
     * @param recordId : Id of the ServiceRequest__c
     * @return         : String — 'success' on completion
     * @throws         : AuraHandledException — wraps any exception message
     */
    @AuraEnabled
    public static string propertyTransferNewDesignProcess1(Id recordId){
        try {
            PropertyTransferProcessController.executePropertyExecutionsFlowstep1(recordId);
            return 'success';
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
     /**
     * @description   : LWC entry point for Joint Owner update process on an SR.
     *                  Delegates to PropertyTransferProcessController.processServiceRequestJo()
     *                  which handles JO additions, removals, and ownership % updates.
     *                  Wraps any exception in AuraHandledException for LWC error handling.
     *
     * @param recordId : Id of the ServiceRequest__c
     * @return         : String — 'success' on completion
     * @throws         : AuraHandledException — wraps any exception message
     */
    @AuraEnabled
    public static string doCalloutJo(Id recordId){
        try {
            PropertyTransferProcessController.processServiceRequestJo(recordId);
            return 'success';
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    // @AuraEnabled
    // public static string executeFlow(Id recordId){
    //     try {
    //        // PropertyTransferProcessController.executeFlow(recordId);
    //         return 'success';
    //     } catch (Exception e) {
    //         throw new AuraHandledException(e.getMessage());
    //     }
    // }
    /**
     * @description   : Formats a duration in minutes into a human-readable string.
     *                  Conversion rules:
     *                    < 60 minutes  → '{n} minute(s)'
     *                    1–23 hours    → '{n} hour(s)'
     *                    24+ hours     → '{n} day(s)'
     *
     * @param minutes  : Total elapsed minutes as an Integer
     * @return         : String — formatted duration string (e.g. '2 hour(s)', '3 day(s)')
     */
    public static string getFormattedTimeTaken(integer minutes){
        if(minutes > 60){
            Long hours = minutes / 60;
            if(hours > 24){
                Long days = hours / 24;
                return String.valueOf(Integer.valueof(days)) + ' day(s)';
            }else{
                return String.valueOf(Integer.valueof(math.floor(hours))) + ' hour(s)';
            }
        }else{
            return String.valueOf(minutes) + ' minute(s)';
        }
    }
    /**
     * @description              : Builds the list of StepGroupWrap objects for the
     *                             step-group UI by joining ServiceCatalog__c /
     *                             ServiceAction__c configuration with Task execution data.
     *
     *                             Process:
     *                               1. Query all Tasks for the SR ordered by CreatedDate DESC
     *                               2. Determine current task order, status, and NOC doc status
     *                               3. Query ServiceCatalog__c and child Service_Actions__r
     *                                  for the SR record type
     *                               4. Apply shouldIncludeStep() filter to exclude steps
     *                                  not relevant to the SR subtype
     *                               5. For each StepGroupWrap, build child step data via
     *                                  createStepGroupChildData()
     *                               6. Compute GroupWidth as equal percentage per group
     *
     *                             Business Rule (ADM record type):
     *                               - If current task status = 'Return', use taskList[1]
     *                                 (skip the return task)
     *                               - If current task is a sub-task and is 'Closed', use
     *                                 taskList[1] as the effective current task
     *
     * @param serviceRequestId   : SR Id used for Task query
     * @param recordTypeName     : SR Record Type Name (drives ServiceCatalog lookup)
     * @param subType            : SR SubType__c (used by shouldIncludeStep filter)
     * @param strSRStatus        : SR Status__c (passed to createStepGroupChildData)
     * @return                   : List<StepGroupWrap> — ordered step group wrappers,
     *                             or empty list if serviceRequestId is blank
     */
    @AuraEnabled
    public static List<StepGroupWrap> PrepareGroups(String serviceRequestId, String recordTypeName, String subType, String strSRStatus) {
        lstGroupWrap = new List<StepGroupWrap>();
        if (String.isEmpty(serviceRequestId)) {
            return lstGroupWrap;
        }
          // V1starts here    
    Boolean isCommercial = false;

    ServiceRequest__c srRec = [SELECT SalesOrder__r.ProjectName__c FROM ServiceRequest__c
        WHERE Id = :serviceRequestId LIMIT 1];

    String projectName;
        
    if (srRec.SalesOrder__r != null) {
        projectName = srRec.SalesOrder__r.ProjectName__c;
    }
    if (projectName != null && projectName.trim().toLowerCase().contains('commercial')) {
        isCommercial = true;
    }

    System.debug('Project Name >>>' + projectName + '<<<');
    System.debug('Is Commercial >>>' + isCommercial + '<<<'); //  v1 ends here
        
        string typeValue;
        Integer taskOrderNum;
        Map<String, List<ServiceAction__c>> mapGroupSteps = new Map<String, List<ServiceAction__c>>();
        List<String> actionSubjects = new List<String>();
        List<String> taskSubjects = new List<String>();
        List<Task> taskList = [SELECT Id, Subject,NOC_Doc_Status__c, Status, Is_Sub_Task__c,Order__c, createdDate FROM Task WHERE WhatId = :serviceRequestId AND Order__c != NULL ORDER BY createdDate DESC];
        
        if (!taskList.isEmpty()) {
            for (Task t : taskList) {
                if (t.Subject != null && !taskSubjects.contains(t.Subject)) {
                    taskSubjects.add(t.Subject);
                }
            }
            Task currenttaskdata = taskList[0];
            typeValue=currenttaskdata.NOC_Doc_Status__c;
            taskOrderNum = Integer.valueOf(currenttaskdata.Order__c);
            
        }
        for (ServiceCatalog__c srStp : [SELECT Id, Name, Service_Request_Type__c, Steps__c, (
            SELECT Id, Name, Order__c, TaskSubject__c, Description__c,NOC_Status__c, ServiceCatalog__c, Notes__c, FinalTask__c,
            PropertyType__c FROM Service_Actions__r WHERE Is_Sub_Task__c = FALSE ORDER BY Order__c ASC
        ) FROM ServiceCatalog__c WHERE Service_Request_Type__c = :recordTypeName]) { // V1 starts here
            
            for (ServiceAction__c stp : srStp.Service_Actions__r) {
                
                      if (isCommercial) { //v1 starts
                // Commercial project → only not Commercial
                if (stp.PropertyType__c == null || stp.PropertyType__c != 'Commercial') {
                    continue;
                }

            }
            else {

                if (stp.PropertyType__c == 'Commercial') {
                    continue;
                }

            }// v1 ends here
                actionSubjects.add(stp.TaskSubject__c);
                if (!mapGroupSteps.containsKey(stp.Name)) {
                    if (shouldIncludeStep(srStp.Service_Request_Type__c, subType, stp.Name)) {
                        StepGroupWrap objGrpWrap = new StepGroupWrap();
                        objGrpWrap.GroupLabel = stp.Name;
                        objGrpWrap.Order = Integer.valueOf(srStp.Steps__c);
                        objGrpWrap.GroupShortLabel = String.valueOf(lstGroupWrap.size() + 1);
                        objGrpWrap.SLA = '2 hour(s)';
                        lstGroupWrap.add(objGrpWrap);
                    }
                }
                if (!mapGroupSteps.containsKey(stp.Name)) {
                    mapGroupSteps.put(stp.Name, new List<ServiceAction__c>());
                }
                mapGroupSteps.get(stp.Name).add(stp);
            }
        }
        
        if (!taskList.isEmpty()) {
            Task currenttask = taskList[0];
            
            if(recordTypeName == Constants.SERVICE_REQUEST_RT_DEV_NAME_ADM && currenttask.Status == Constants.TASK_STATUS_RETURN){
                currenttask = taskList[1];
            }
            if(recordTypeName == Constants.SERVICE_REQUEST_RT_DEV_NAME_ADM && currenttask.Is_Sub_Task__c == true &&  currenttask.Status ==Constants.TASK_STATUS_CLOSED){
                currenttask = taskList[1];
            }
            Integer taskOrder = Integer.valueOf(currenttask.Order__c);
            String taskStatus = currenttask.Status;
             String currenttaskStatus = currenttask.Subject;
            String taskId = currenttask.Id;
            
            for (StepGroupWrap sgw : lstGroupWrap) {
                List<StepGroupChildData> lstChilds = new List<StepGroupChildData>();
                List<ServiceAction__c> stepsList = mapGroupSteps.containsKey(sgw.GroupLabel) ? mapGroupSteps.get(sgw.GroupLabel) : new List<ServiceAction__c>();
                for (ServiceAction__c stp : stepsList) {
                    StepGroupChildData cd = createStepGroupChildData(stp, taskOrder, taskStatus, taskId,sgw,typevalue,strSRStatus,taskSubjects,recordTypeName,currenttaskStatus);
                    lstChilds.add(cd);
                }
                sgw.lstChilds = lstChilds;
            }
        }
        
        if (!lstGroupWrap.isEmpty()) {
            GroupWidth = (100 / lstGroupWrap.size()) + '%';
        }
        
        return lstGroupWrap;
    }
    
    private static Boolean shouldIncludeStep(String requestType, String subType, String stepName) {
        if (requestType == 'Service Request Management -ADM') {
            return (subType == 'New Sale' && stepName != 'Registration Doc Check' && stepName != 'Deregistration') ||
                (subType == 'Next of Kin' && stepName == 'Registration Doc Check') ||
                ((subType == 'Normal'  || subType =='Court Order')&& stepName != 'Registration Doc Check' && stepName != 'Review Details');
        }
        return true;
    }
    //     private static Boolean shouldIncludeStepPT(String requestType, String typeval, String stepName) {
    //     if (requestType == 'Service Request Management - Property Transfer Title Deed') {
    //         return (typeval == 'Cancel NOC' && stepName == 'SR Cancellation - CM Team Comments') ||
    //                (typeval == 'In Progress' && stepName == 'Follow-up on NOC Status After 30 Days') ||
    //                ((typeval == 'Title Deed Issued' ) && stepName == 'Capture Title Deed by CM Team');
    //     }
    //     return true;
    // }
    /**
     * @description              : Builds a single StepGroupChildData object for a
     *                             ServiceAction__c step, computing the open/closed/next
     *                             UI state based on task order, status, and SR status.
     *
     *                             State logic (when SR is NOT Cancelled/Rejected):
     *                               stp.Order__c < taskOrder:
     *                                 - Task subject already completed → IsClosed=true
     *                                 - Task subject not completed    → IsOpen=true, nextstep=true
     *
     *                               stp.Order__c == taskOrder (current step):
     *                                 - Subject matches + is current task:
     *                                     - NOC status match  → nextstep=false, Passed=true
     *                                     - NOC status no match → nextstep=true, Passed=true
     *                                     - FinalTask closed   → nextstep=false, Passed=true
     *                                     - Otherwise          → nextstep=false, Passed=false
     *                                 - Subject matches but NOT current task → IsClosed=true
     *                                 - Subject not in completed tasks       → nextstep=true
     *
     *                               stp.Order__c > taskOrder:
     *                                 - Future step → IsOpen=true, nextstep=true
     *
     *                               SR Cancelled or Rejected:
     *                                 - All steps → IsOpen=true, nextstep=true (unblocked UI)
     *
     * @param stp               : ServiceAction__c step record
     * @param taskOrder         : Order__c of the current/effective Task (Integer)
     * @param taskStatus        : Status of the current/effective Task
     * @param taskId            : Id of the current/effective Task
     * @param SGW               : StepGroupWrap parent — CurrentGroup/Passed_Group updated in-place
     * @param TypeValue         : NOC_Doc_Status__c of the current Task
     * @param strSRStatus       : SR Status__c (Cancelled/Rejected check)
     * @param taskSubjects      : De-duped list of Task subjects already created for the SR
     * @param recordTypeName    : SR Record Type Name (not currently used, reserved for future)
     * @param currenttaskStatus : Subject of the current/effective Task
     * @return                  : StepGroupChildData — fully populated child step wrapper
     */
    public static StepGroupChildData createStepGroupChildData(ServiceAction__c stp, Integer taskOrder, String taskStatus, String taskId, StepGroupWrap SGW, String TypeValue,String strSRStatus,List<String> taskSubjects,string recordTypeName,String currenttaskStatus) {
        StepGroupChildData cd = new StepGroupChildData();
        cd.hasStep = true;
        cd.StepSummary = stp.Description__c;
        cd.StepId = stp.Id;
        cd.TaskId = taskId;
        cd.status = stp.Name;
        cd.ActionType = stp.Name;
        cd.SRID = stp.ServiceCatalog__c;
        cd.StepLoop = String.valueOf(taskOrder);
        cd.stpNotes = stp.Notes__c;
        if(strSRStatus !='Cancelled' && strSRStatus !='Rejected'){
            if (stp.Order__c < taskOrder) {
                if(taskSubjects.contains(stp.TaskSubject__c)){
                cd.IsClosed = true;
                cd.IsOpen = false;
                SGW.CurrentGroup = true;
                cd.nextstep = false;
                SGW.Passed_Group = true;
                } else{
                cd.IsClosed = false;
                cd.IsOpen = true;
                cd.nextstep = true;
                SGW.CurrentGroup = true;
                SGW.Passed_Group = false;
                }
            } else if (stp.Order__c == taskOrder) {
                if(taskSubjects.contains(stp.TaskSubject__c) && currenttaskStatus == stp.TaskSubject__c){
                cd.IsOpen = !stp.FinalTask__c || taskStatus != Constants.TASK_STATUS_CLOSED;
                cd.IsClosed = !cd.IsOpen;
                if(TypeValue!= null && stp.NOC_Status__c!=null && TypeValue == stp.NOC_Status__c){
                    SGW.CurrentGroup = true;
                    SGW.Passed_Group = true;
                    cd.nextstep= false;
                }else if(TypeValue!= null && stp.NOC_Status__c!=null && TypeValue != stp.NOC_Status__c){
                    SGW.CurrentGroup = true;
                    SGW.Passed_Group = true;
                    cd.nextstep= true;
                }else if(stp.FinalTask__c && taskStatus== Constants.TASK_STATUS_CLOSED){
                    SGW.CurrentGroup = true;
                    SGW.Passed_Group = true;
                    cd.nextstep= false;
                }else{
                    SGW.CurrentGroup = true;
                    SGW.Passed_Group = false;
                    cd.nextstep= false;
                }
                }else if(taskSubjects.contains(stp.TaskSubject__c) && currenttaskStatus != stp.TaskSubject__c){
                cd.IsClosed = true;
                cd.IsOpen = false;
                cd.nextstep = false;
                SGW.CurrentGroup = true;
                SGW.Passed_Group = false;
                }else{
                    cd.IsClosed = false;
                cd.IsOpen = false;
                cd.nextstep = true;
                SGW.CurrentGroup = true;
                SGW.Passed_Group = false;
                }
                
            } else {
                cd.IsClosed = false;
                cd.IsOpen = true;
                cd.nextstep = true;
                SGW.CurrentGroup = true;
                SGW.Passed_Group = false;
            }
        }else{
            cd.IsClosed = false;
            cd.IsOpen = true;
            cd.nextstep = true;
            SGW.CurrentGroup = true;
            SGW.Passed_Group = false;
        }
        
        System.debug('cd--->'+strSRStatus);
        return cd;
    }
     /**
     * @description   : Returns a fully-populated Task record by Id for display or
     *                  pre-fill in the LWC task update form.
     *                  Fetches all fields required by the task edit UI including
     *                  NOC status, KYC status, broker registration status, and comments.
     *
     * @param taskId   : Id of the Task to retrieve
     * @return         : Task — single Task record with all required fields
     * @throws         : AuraHandledException — if no Task found or any exception occurs
     */
    @AuraEnabled
    public static Task getTask(String taskId) {
        try {
            return [SELECT Id, Requested_From__c,Subject,Extended_NOC_Approval_Status__c,NOC_Doc_Status__c, ActivityDate, Status,Description,KYC_Status__c,Priority, Broker_Registration_Status__c,Comments__c FROM Task WHERE Id = :taskId LIMIT 1];
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
     /**
     * @description   : Executes the plot handover completion process for an SR.
     *                  Updates the linked SalesOrder:
     *                    HandedOverDate__c = today
     *                    TitleDeedIssued__c = true
     *                  Updates the linked Unit:
     *                    PlotStatus__c = 'Handed Over'
     *
     *                  Business Rule: Both SalesOrder and Unit updates are performed
     *                  only if a matching SR with a linked SalesOrder is found.
     *
     * @param recordId : Id (as String) of the ServiceRequest__c
     * @return         : String — 'success' on completion
     * @throws         : AuraHandledException — wraps any exception message
     */
    @AuraEnabled
    public static string executePlotHandoverUpdate(String recordId) {
        try {
            
            List<ServiceRequest__c> serviceRequests = [
                SELECT Id, Name, RecordType.Name,SalesOrder__c,SalesOrder__r.Unit__c,SalesOrder__r.Unit__r.PlotStatus__c,SalesOrder__r.HandedOverDate__c
                FROM ServiceRequest__c WHERE Id = :recordId LIMIT 1
            ];
            if(serviceRequests.size()>0 && serviceRequests!= null){
                 SalesOrder__c salOrder = new SalesOrder__c(Id=serviceRequests[0].SalesOrder__c,HandedOverDate__c = system.today(),TitleDeedIssued__c = true);
                 update salOrder;
                 Unit__c unitRec= new Unit__c(Id=serviceRequests[0].SalesOrder__r.Unit__c,PlotStatus__c = 'Handed Over');
                 update unitRec;
            }
            return 'success';
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
        
    } 
    /**
     * @description   : Executes the full Unit Termination / Cancellation process for
     *                  an SR when CM Manager approval has been granted.
     *
     *                  Business Rule — CM_Approval_Status__c must be 'Approved by CM Manager':
     *                    If NOT approved   → returns approval required message
     *                    If Rejected        → returns not allowed message
     *                    If SR not found    → returns not allowed message
     *
     *                  On Approval, executes the following DML operations:
     *                    1. For each paid Allocation__c on SO invoices (AllocationAmount__c > 0):
     *                         - Create CreditNote__c (Approved, IntegrationStatus = 'Success')
     *                         - Unapply Allocation__c (AllocationAmount__c = 0, Status = 'Unapplied')
     *                    2. Cancel future SalesOrderInstallment invoices
     *                         (isCancelled__c = true, MilestoneDate__c > today, not already cancelled)
     *                    3. Create Refund Receipt__c if Refund_Amount__c > 0
     *                         (Modeofpayment__c = 'Refund', Status = 'Approved')
     *                    4. Create Forfeiture Invoice__c if Forfeiture_Amount__c > 0
     *                         (Tax_Invoice record type, OICIntegrationStatus__c = 'S')
     *                    5. Cancel SalesOrder (Status = 'Cancelled')
     *                    6. Reset Unit (Status = '', ApprovalStatus = 'Draft')
     *
     * @param recordId : Id (as String) of the ServiceRequest__c
     * @return         : String — 'success' on approved completion, or descriptive
     *                   error message if approval conditions not met
     * @throws         : AuraHandledException — wraps any DML or system exception
     */
    @AuraEnabled
    public static string executeCancellationProcess(String recordId) {
        
        string successMsg ='';
        try {
            
            List<ServiceRequest__c> serviceRequests = [
                SELECT Id, Name, RecordType.Name,SalesOrder__c,SalesOrder__r.Unit__c,SalesOrder__r.Unit__r.PlotStatus__c,SalesOrder__r.HandedOverDate__c,Forfeiture_Amount__c,
                CM_Approval_Status__c,Refund_Amount__c,SalesOrder__r.CustomerAccount__c
                FROM ServiceRequest__c WHERE Id = :recordId LIMIT 1
            ];
            if(serviceRequests.size()>0 && serviceRequests!= null){
                ServiceRequest__c srRec = serviceRequests[0];
                 if(srRec.CM_Approval_Status__c =='Approved by CM Manager'){
                    // SalesOrder__c salOrder = new SalesOrder__c(Id=serviceRequests[0].SalesOrder__c,HandedOverDate__c = system.today(),TitleDeedIssued__c = true);
                    //update salOrder;
                    //  Unit__c unitRec= new Unit__c(Id=serviceRequests[0].SalesOrder__r.Unit__c,PlotStatus__c = 'Handed Over');
                    // update unitRec;
                    List<CreditNote__c> creditNoteList = new List<CreditNote__c>();
                    List<Allocation__c> unapplyList= new List<Allocation__c>();
                    for(Allocation__c  ac : [
                            SELECT Id,AllocationAmount__c,Status__c,Receipt_Status__c,Invoice__c,Invoice__r.SalesOrderInstallment__r.SalesOrder__c 
                            FROM Allocation__c 
                            WHERE Invoice__r.SalesOrderInstallment__r.SalesOrder__c =:srRec.SalesOrder__c
                            and AllocationAmount__c >0
                    ]){
                        
                        CreditNote__c cn = new CreditNote__c();
                        cn.Invoice__c = ac.Invoice__c;
                        cn.Amount__c = ac.AllocationAmount__c;            
                        System.debug('cn.Amount__c '+cn.Amount__c);
                        cn.Source__c = 'Property Sales Invoice';
                        cn.Sales_Order__c = ac.Invoice__r.SalesOrderInstallment__r.SalesOrder__c;
                        cn.Approval_Status__c = 'Approved';
                        cn.ApprovalDate__c = Date.today();
                        cn.IntegrationStatus__c = 'Success'; 
                        creditNoteList.add(cn);    
                        unapplyList.add(new Allocation__c(Id=ac.Id,AllocationAmount__c =0,Status__c='Unapplied'));   
                    }
                    /*
                    for(Allocation__c  ac : [
                            SELECT Id,AllocationAmount__c,Status__c,Receipt_Status__c,Invoice__c,Invoice__r.Charge__r.Sales_Order__c
                            FROM Allocation__c 
                            WHERE Invoice__r.Charge__r.Sales_Order__c =:srRec.SalesOrder__c
                            and AllocationAmount__c >0
                    ]){
                        CreditNote__c cn = new CreditNote__c();
                        cn.Invoice__c = ac.Invoice__c;
                        cn.Amount__c = ac.AllocationAmount__c;            
                        System.debug('cn.Amount__c '+cn.Amount__c);
                        cn.Source__c = 'Property Sales Invoice';
                        cn.Sales_Order__c = ac.Invoice__r.Charge__r.Sales_Order__c;
                        cn.Approval_Status__c = 'Approved';
                        cn.ApprovalDate__c = Date.today();
                        cn.IntegrationStatus__c = 'Success'; 
                        creditNoteList.add(cn);    
                        unapplyList.add(new Allocation__c(Id=ac.Id,AllocationAmount__c =0,Status__c='Unapplied'));   
                    }*/
                    List<Invoice__c>invlistCancelled = new List<Invoice__c>();
                    for(Invoice__c inv : [SELECT SalesOrderInstallment__r.SalesOrder__c,InvoiceStatus__c 
                        FROM Invoice__c 
                        where SalesOrderInstallment__c != null
                        AND Sales_Order__c = null
                        AND SalesOrderInstallment__r.SalesOrder__c =:srRec.SalesOrder__c
                        and InvoiceStatus__c != 'Cancelled' and SalesOrderInstallment__r.MilestoneDate__c > today]){
                        invlistCancelled.add(new Invoice__c(Id=inv.Id,isCancelled__c= true));
                    }
                    /*
                    for(Invoice__c inv : [SELECT Sales_Order__c,InvoiceStatus__c 
                        FROM Invoice__c 
                        where SalesOrderInstallment__c = null
                        AND Sales_Order__c =:srRec.SalesOrder__c
                        and InvoiceStatus__c != 'Cancelled' 
                        and InvoiceDate__c  > today 
                    ]){
                        invlistCancelled.add(new Invoice__c(Id=inv.Id,isCancelled__c= true));
                    }
                    */
                    if(creditNoteList.size()>0)insert creditNoteList;
                    if(unapplyList.size()>0)update unapplyList;
                    if(invlistCancelled.size()>0)update invlistCancelled;
                    
                    if(srRec.Refund_Amount__c!=null && srRec.Refund_Amount__c >0){
                        Receipt__c obj_NewReceipt = new Receipt__c();
                        obj_NewReceipt.Account__c = srRec.SalesOrder__r.CustomerAccount__c;
                        obj_NewReceipt.Modeofpayment__c = 'Refund';
                        obj_NewReceipt.SalesOrder__c = srRec.SalesOrder__c;
                        //obj_NewReceipt.SalesOrderInstallment__c = obj_SOI.Id;
                        obj_NewReceipt.TotalAmount__c = srRec.Refund_Amount__c;
                        obj_NewReceipt.Status__c = 'Approved';
                        insert obj_NewReceipt;
                     }
                     if(srRec.Forfeiture_Amount__c!=null && srRec.Forfeiture_Amount__c>0){
                         //create Forfeiture
                        Invoice__c ForfeitureInv= new Invoice__c();
                        ForfeitureInv.RecordTypeId = InvoiceService.recordTypeIdByDevName(Invoice__c.SobjectType,'Tax_Invoice');
                        ForfeitureInv.Sales_Order__c= srRec.SalesOrder__c;
                        ForfeitureInv.InvoiceAmount__c = srRec.Forfeiture_Amount__c;
                        ForfeitureInv.Account__c = srRec.SalesOrder__r.CustomerAccount__c;
                        ForfeitureInv.InvoiceDate__c=  Date.today();
                        ForfeitureInv.OICIntegrationStatus__c= 'S';
                        ForfeitureInv.Description__c ='Forfeiture Invoice';
                        insert ForfeitureInv;
                     }
                     SalesOrder__c salOrder = new SalesOrder__c(Id=srRec.SalesOrder__c,Status__c= 'Cancelled',CancellationReason__c='Default Unit Cancellation');
                     update salOrder;
                     Unit__c unitRec= new Unit__c(Id=srRec.SalesOrder__r.Unit__c,Status__c= '',ApprovalStatus__c ='Draft');
                     update unitRec;
                    
                     successMsg = 'success'; 
                 }else{
                     if(srRec.CM_Approval_Status__c !='Rejected'){
                         return 'Management Approval is required to proceed the Unit Termination Process';
                     }else{
                         return 'You are not allowed to proceed the Unit Termination Process';
                     }
                 }
            }else{
                return 'You are not allowed to process the SR';
            }
            return successMsg;
        } catch (Exception e) {
            //successMsg = e.getMessage();
            throw new AuraHandledException(e.getMessage());
        }
        
    } 
     /**
     * @description   : Applies confirmed and rescheduled milestone dates from
     *                  Milestone_Update_Tracker__c records to their linked Milestone__c
     *                  records for a given SR.
     *
     *                  Business Rule:
     *                    Confirmed_Milestone_Date__c != null → update ConfirmedMilestoneDate__c
     *                    Reschedule_Milestone_Date__c != null → update Milestone_Due_Date__c
     *                  Only tracker records with a linked Milestone__c are processed.
     *
     * @param recordId : Id (as String) of the ServiceRequest__c
     * @return         : String — 'success' on completion
     * @throws         : AuraHandledException — wraps any exception message
     */
    @AuraEnabled
    public static string executeMilestoneUpdate(String recordId) {
        try {
            List<Milestone__c>updateListOfMilestone = new List<Milestone__c>();
            system.debug('-------recordId------------'+recordId);
            
            List<Milestone_Update_Tracker__c> milestoneTrackerList = [
                select Id,MilestoneRec__c,Service_Request__c,Confirmed_Milestone_Date__c,Reschedule_Milestone_Date__c,Milestone__c  from Milestone_Update_Tracker__c 
                where Service_Request__c =:recordId and Milestone__c != null
                //and Confirmed_Milestone_Date__c = null and Reschedule_Milestone_Date__c = null
                order by Service_Request__c asc 
            ];
            system.debug('-------milestoneTrackerList ------------'+milestoneTrackerList );
            for(Milestone_Update_Tracker__c ms : milestoneTrackerList ){
                Milestone__c milestoneUpdate = new Milestone__c(Id = ms.Milestone__c);
                if(ms.Confirmed_Milestone_Date__c != null){
                    milestoneUpdate.ConfirmedMilestoneDate__c = ms.Confirmed_Milestone_Date__c;
                    updateListOfMilestone.add(milestoneUpdate);
                }else if(ms.Reschedule_Milestone_Date__c!= null){
                    //milestoneUpdate.ConfirmedMilestoneDate__c = ms.Reschedule_Milestone_Date__c;
                    milestoneUpdate.Milestone_Due_Date__c = ms.Reschedule_Milestone_Date__c;
                    updateListOfMilestone.add(milestoneUpdate);
                }
            }
            system.debug('-------updateListOfMilestone------------'+updateListOfMilestone);
            if(updateListOfMilestone.size()>0)update updateListOfMilestone;
            return 'success';
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
        
    } 
     /**
     * @description  : Updates a Task record from LWC and orchestrates next-step
     *                 creation based on the SR record type when the task transitions
     *                 to 'Closed' status.
     *
     *                 Process:
     *                   1. Fetch old Task state before update
     *                   2. Perform Database.update (partial save, errors captured)
     *                   3. On success, fetch updated Task and determine SR record type
     *                   4. Route to record-type-specific next-step logic:
     *
     *                 Record Type Routing (on status change → 'Closed'):
     *                   Title Deed / Joint Owner Title Deed:
     *                     → ServiceRequestTitleDeedController.createNextStepsForTasks()
     *                     → Order 2: serviceRequestDataValidationforProspectAcc()
     *                     → Order 3: SRDocumentValidation()
     *
     *                   Unit Upgrade / Unit Swap:
     *                     → ServiceRequestUnitController.createNextStepsForTasks()
     *                     → Order 7: SendRegistartionEmail()
     *
     *                   Broker Registration:
     *                     → Task1/Task3 with RMI or Approved status:
     *                          MBP_RegistrationService.createBrokerAgency()
     *                     → Any task with Rejected status:
     *                          SR Status__c = 'Rejected'
     *
     *                 Business Rule: If Database.update fails, AuraHandledException is
     *                 thrown with the first DML error message. SR updates for Broker
     *                 Registration rejection are batched and updated after task update.
     *
     * @param task   : Task record with updated field values (must include Id)
     * @throws       : AuraHandledException — on DML failure or any caught exception
     */
    @AuraEnabled
    public static void updateTask(Task task) {
        List<ServiceRequest__c> serviceRequestListToUpdate = new List<ServiceRequest__c>();
        system.debug('task::'+task);   
        String errorMsg = '';
        
        system.debug('debug: in ServiceActionController.updateTask method ');
        // Step 1: Query the old task data
        Map<Id, Task> oldtskMap = new Map<Id, Task>();
        List<Task> oldTaskList = [SELECT Id, SRType__c,Requested_From__c,NOC_Doc_Status__c,Extended_NOC_Approval_Status__c, 
                                  RecordTypeId,Subject, WhatId, ActivityDate, Status, Description, 
                                  KYC_Status__c, Priority, Broker_Registration_Status__c 
                                  FROM Task WHERE Id = :task.Id];
        
        for (Task t : oldTaskList) {
            oldtskMap.put(t.Id, t);
        }
        
        Map<Id, Task> newMap = new Map<Id, Task>();
        newMap.put(task.Id,task);
        
        // Step 2: Perform the update
        Database.SaveResult taskResult;
        try {
            taskResult = Database.update(task, false);
            system.debug('taskResult::'+taskResult);
            Decimal OrderNum=0;
            
            System.debug('Update Result: ' + taskResult);
            set<Id> srId = new set<Id>();
            if (taskResult.isSuccess()) {
                System.debug('Task updated successfully.');
                
                // Step 3: Retrieve the updated task record
                List<Task> updatedTaskList = [SELECT SRType__c,Requested_From__c,NOC_Doc_Status__c,Id,Extended_NOC_Approval_Status__c,RecordTypeId, Subject, Order__c,
                                              WhatId, ActivityDate, Status, Description, KYC_Status__c, Priority,Is_Sub_Task__c,
                                              Broker_Registration_Status__c, comments__c
                                              FROM Task WHERE Id = :task.Id];
                
                system.debug('updatedTaskList:::'+updatedTaskList);
                // Step 4: Convert oldtskMap to Map<Id, SObject>
                Map<Id, Task> oldMap = new Map<Id, Task>();
                for (Id taskId : oldtskMap.keySet()) {
                    oldMap.put(taskId, oldtskMap.get(taskId));
                }
                
                List<Task> newTasks = new List<Task>();
                for(task t:updatedTaskList){
                    newTasks.add(t);
                    srId.add(t.WhatId);
                    OrderNum = t.Order__c;
                }
                
                //Map<String,List<Task>> mapSRRecordypeTaskLists= determineServiceRequestRecordTypes(newTasks);
                Map<Id, String> srRecordTypeMap = getServiceRequestRtMap(srId);
                set<string> recordTypeName =new set<string>();
                for(string recName:srRecordTypeMap.Values()){
                    recordTypeName.add(recName);
                }
                Set<Id> serviceRequestIds = srRecordTypeMap.keySet();
                System.debug('oldMap.get(task.id).status'+oldMap.get(task.id).status);
                System.debug('updatedTaskList[0].Status'+updatedTaskList[0].Status);  
                List<Task> listTask = new List<Task>();
                
                if(oldMap.get(task.id).status <> updatedTaskList[0].Status && updatedTaskList[0].Status =='Closed' && 
                   (recordTypeName.contains(Constants.SERVICE_REQUEST_Default_SR))){ 
                        // Step 5: Call the method with updated data and old data
                        //DefaultSRContrroler.createNextStepsForTasks(serviceRequestIds,newTasks);
                     
                        if(OrderNum == 1 || OrderNum ==1.0){
                          
                        }   
                    }
                if(oldMap.get(task.id).status <> updatedTaskList[0].Status && updatedTaskList[0].Status =='Closed' && 
                   (recordTypeName.contains(Constants.SERVICE_REQUEST_RT_DEV_NAME_JOINT_OWNER_TITLE_DEED) || 
                    recordTypeName.contains(Constants.SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER_TITLE_DEED))){ 
                        // Step 5: Call the method with updated data and old data
                        ServiceRequestTitleDeedController.createNextStepsForTasks(newTasks, oldMap);
                     
                           
                        if(OrderNum == 2 || OrderNum == 2.0){
                           
                            ServiceRequestTitleDeedController.serviceRequestDataValidationforProspectAcc(newTasks, newMap, oldMap); //(List<Task> newTasks, Map<Id, Task> newMap, Map<Id, Task> oldMap)
                            
                        }
                        else if(OrderNum == 3 || OrderNum == 3.0){
                            ServiceRequestTitleDeedController.SRDocumentValidation(newTasks, oldMap); //(List<Task> newTasks, Map<Id, Task> newMap, Map<Id, Task> oldMap)
                          
                        }
                    } 
                else if(oldMap.get(task.id).status <> updatedTaskList[0].Status && updatedTaskList[0].Status =='Closed' && 
                   (recordTypeName.contains(Constants.SERVICE_REQUEST_RT_DEV_NAME_UNIT_UPGRADE) || 
                    recordTypeName.contains(Constants.SERVICE_REQUEST_RT_DEV_NAME_UNIT_SWAP))){
                        ServiceRequestUnitController.createNextStepsForTasks(newTasks, oldMap);
                    
                        if(OrderNum == 7 || OrderNum == 7.0){
                          ServiceRequestUnitController.SendRegistartionEmail(updatedTaskList[0]);
                            //Task Subject: Obtain Modon Countersignature on NOC
                        }
                    } 
                
                else if(oldMap.get(task.id).status <> updatedTaskList[0].Status && updatedTaskList[0].Status =='Closed'
                        && recordTypeName.contains(Constants.SERVICE_REQUEST_BR) &&
                        (((updatedTaskList[0].Subject == BRConstants.SERVICE_REQUEST_TASK1 
                           || updatedTaskList[0].Subject == BRConstants.SERVICE_REQUEST_TASK3) 
                          && (updatedTaskList[0].Broker_Registration_Status__c == BRConstants.ACTION_STATUS_RMI ||
                              updatedTaskList[0].Broker_Registration_Status__c == BRConstants.ACTION_STATUS_APPROVED)) ||
                         (updatedTaskList[0].Subject == BRConstants.SERVICE_REQUEST_TASK5 &&
                          updatedTaskList[0].Broker_Registration_Status__c == BRConstants.ACTION_STATUS_APPROVED))){
                              
                              ServiceRequest__c serviceRequest = [SELECT Id, Registration__c,Status__c, Fast_Track__c from ServiceRequest__c WHERE Id in: srId AND Registration__c != null];
                              system.debug('serviceRequest::'+serviceRequest);
                              system.debug('updatedTaskList[0]::'+updatedTaskList[0]);
                              if(serviceRequest != null){
                                  MBP_RegistrationService.createBrokerAgency(serviceRequest,  updatedTaskList[0]);
                              }
                          }else if(recordTypeName.contains(Constants.SERVICE_REQUEST_BR) && 
                                   oldMap.get(task.id).status <> updatedTaskList[0].Status && updatedTaskList[0].Status =='Closed' &&
                                   updatedTaskList[0].Broker_Registration_Status__c == BRConstants.ACTION_STATUS_REJECTED){
                                       
                                       ServiceRequest__c serviceRequest = new ServiceRequest__c();
                                       ServiceRequest.Id = updatedTaskList[0].WhatId;
                                       ServiceRequest.Status__c = BRConstants.ACTION_STATUS_REJECTED;
                                       serviceRequestListToUpdate.add(ServiceRequest);
                                   }
                else {
                    /*for (Database.Error err : taskResult.getErrors()) {
                        System.debug('Error: ' + err.getMessage());
                        }*/
                }
            }
                
            
            if (!taskResult.isSuccess()) {
                if (taskResult.getErrors() != null && taskResult.getErrors().size() > 0) {
                    errorMsg = taskResult.getErrors()[0].getMessage();
                }
                system.debug('errorMsg---->492'+errorMsg);
                throw new NullPointerException(); // or even just "throw new NullPointerException();" etc.
            }
            if(!serviceRequestListToUpdate.isEmpty()){
                update serviceRequestListToUpdate;
            }
        } catch (Exception e) {
            system.debug('errorMsg---->492'+e);
            if (String.isNotBlank(errorMsg)) {
                throw new AuraHandledException('Error updating task: ' + errorMsg);
            } else {
                throw new AuraHandledException('Error updating task: ' + e.getMessage());
            }
        }
    }
    
    public class My1Exception extends Exception {}
     /**
     * @description                          : Builds a Map of ServiceRequest__c Id to
     *                                         Record Type Name for a set of SR Ids.
     *                                         Used by updateTask() to determine which
     *                                         next-step routing logic to invoke.
     *
     * @param completedTaskServiceRequestIds : Set of SR Ids to query
     * @return                               : Map<Id, String> — SR Id → RecordType.Name
     */
    private static Map<Id, String> getServiceRequestRtMap(Set<Id> completedTaskServiceRequestIds) {
        Map<Id, String> taskSubjectMap = new Map<Id, String>();
        List<ServiceRequest__c> serviceRequestlst = [SELECT Id, RecordType.Name, Type__c FROM ServiceRequest__c WHERE Id IN :completedTaskServiceRequestIds];
        for (ServiceRequest__c sr : serviceRequestlst) {
            taskSubjectMap.put(sr.Id, sr.RecordType.Name);
        }
        return taskSubjectMap;
    }
    /**
     * @description    : Blocks the selected unit for upgrade by setting its
     *                   Status__c = 'Blocked for Upgrade'.
     *                   Validates that Selected_Unit__c is populated on the SR
     *                   before attempting the update.
     *
     *                   Business Rule: Throws AuraHandledException if
     *                   Selected_Unit__c is null, preventing premature unit blocking.
     *
     * @param srequest  : ServiceRequest__c record containing at least the SR Id
     *                   (Selected_Unit__c is re-queried server-side for safety)
     * @throws          : AuraHandledException — if no Selected_Unit__c or any exception
     */
    @AuraEnabled
	public static void updateUnit(ServiceRequest__c srequest) {
    try {
        ServiceRequest__c sr = [
            SELECT Id, Selected_Unit__c 
            FROM ServiceRequest__c 
            WHERE Id = :srequest.Id
            LIMIT 1
        ];

       if (sr.Selected_Unit__c == null) {
    throw new AuraHandledException('Please select Unit for upgrade from unit search.');
        }
        
        if (sr.Selected_Unit__c != null) {
            Unit__c unitToUpdate = [  
                SELECT Id, Status__c 
                FROM Unit__c 
                WHERE Id = :sr.Selected_Unit__c
                LIMIT 1
            ];

            unitToUpdate.Status__c = 'Blocked for Upgrade';
            update unitToUpdate;
        } else {
            throw new AuraHandledException('No Selected Unit found on Service Request.');
        }
    } catch (Exception e) {
        throw new AuraHandledException(e.getMessage());
    }
}
 /**
     * @description    : Updates a ServiceRequest__c record from LWC with penalty
     *                   charge auto-calculation and NOC extension status handling.
     *
     *                   Business Rules:
     *                     - Penality_Charge__c is set to true if
     *                       SalesOrder_Completed_Date__c < Dari_Application_Submitted_Date__c,
     *                       otherwise set to false.
     *                     - For Title Deed and Joint Owner Title Deed record types:
     *                       Reads old Extended_NOC_Approval_Status__c for future
     *                       Is_NOC_Extended__c flag logic (currently commented out).
     *
     * @param srequest  : ServiceRequest__c record with all updated field values
     * @throws          : AuraHandledException — wraps any exception message
     */
    @AuraEnabled
    public static void updateSR(ServiceRequest__c srequest) 
    {
        try {
            system.debug('debug: in ServiceActionController.updateSR method');
            if(srequest.SalesOrder_Completed_Date__c < srequest.Dari_Application_Submitted_Date__c)
            {
                srequest.Penality_Charge__c=true;
            }
            else 
            {
                srequest.Penality_Charge__c=false;
            }
            

            
            // reset the flag everytime until really needed by the code in below block
            //srequest.Is_NOC_Extended__c = false;
            
            if(srequest.RecordTypeName__c == Constants.SERVICE_REQUEST_RT_DEV_NAME_JOINT_OWNER_TITLE_DEED || srequest.RecordTypeName__c == Constants.SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER_TITLE_DEED)
            {
                system.debug('debug: srequest.NOC_Extension_Date__c ' + srequest.NOC_Extension_Date__c);
                system.debug('debug: srequest.Approved_NOC_Extension_Date__c ' + srequest.Approved_NOC_Extension_Date__c);
                system.debug('debug: srequest.Is_NOC_Extended__c ' + srequest.Is_NOC_Extended__c);
                
                // Get the old values of the SR to check if the SR is approved in this execution
                ServiceRequest__c oldRec = [SELECT Id,Extended_NOC_Approval_Status__c FROM ServiceRequest__c WHERE Id = :srequest.Id];           
                
               /* if(oldRec.Extended_NOC_Approval_Status__c != srequest.Extended_NOC_Approval_Status__c && srequest.Extended_NOC_Approval_Status__c != null && 
                   (srequest.Extended_NOC_Approval_Status__c == 'Approved' || srequest.Extended_NOC_Approval_Status__c == 'Approved with new dates'))
                {
                    srequest.Is_NOC_Extended__c = true;
                }
                else
                {
                    srequest.Is_NOC_Extended__c = false;
                }*/
            }
            update srequest;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
      /**
     * @description        : Creates a new Event record linked to an SR from LWC-provided
     *                       event data. Accepts a generic Map to allow flexible field
     *                       mapping without requiring a dedicated wrapper class.
     *
     *                       Fields mapped from eventData:
     *                         Subject, StartDateTime, EndDateTime, WhatId, Description
     *
     * @param eventData    : Map<String, Object> with event field values:
     *                         'Subject'       → Event.Subject
     *                         'StartDateTime' → Event.StartDateTime (ISO datetime string)
     *                         'EndDateTime'   → Event.EndDateTime   (ISO datetime string)
     *                         'WhatId'        → Event.WhatId (SR or other related record Id)
     *                         'Description'   → Event.Description
     */
    
    @AuraEnabled
    public static void createEvent(Map<String, Object> eventData) {
        Event newEvent = new Event(
            Subject = (String) eventData.get('Subject'),
            StartDateTime = DateTime.valueOf((String) eventData.get('StartDateTime')),
            EndDateTime = DateTime.valueOf((String) eventData.get('EndDateTime')),
            WhatId = (String) eventData.get('WhatId'),
            Description = (String) eventData.get('Description')
        );
        insert newEvent;
    }
     /**
     * @description   : Executes the payment extension process for an SR by updating
     *                  the linked SalesOrderInstallment milestone date and all
     *                  associated Invoice due dates to the SR's Payment_Extension_Date__c.
     *
     *                  Process:
     *                    1. Load SR with Sales_Order_Installment__c and extension date
     *                    2. For each Invoice linked to the installment:
     *                         - Save original InvoiceDate__c to Original_Invoice_Date__c
     *                         - Update InvoiceDate__c = Payment_Extension_Date__c
     *                    3. Update SalesOrderInstallments__c:
     *                         - Save original MilestoneDate__c to Original_Milestone_Date__c
     *                         - Update ExtensionDate__c = Payment_Extension_Date__c
     *
     *                  Business Rule: Returns a descriptive message (not an exception)
     *                  if no SR or installment is found, to allow LWC to handle gracefully.
     *                  Invoice and installment update failures are thrown as
     *                  AuraHandledException individually.
     *
     * @param srId     : Id (as String) of the ServiceRequest__c
     * @return         : String — 'success' on completion,
     *                   'No Sales_Order_Installment__c Value Found' if no installment linked,
     *                   'No SR Found' if SR not found
     * @throws         : AuraHandledException — 'Error at Invoice Update:' or
     *                                          'Error at Execute:' with exception message
     */
    @AuraEnabled
    public static string executePaymentExtension(String srId) {
        List<ServiceRequest__c> srList = [SELECT Id, Name, Payment_Extension_Date__c,Sales_Order_Installment__c,Sales_Order_Installment__r.MilestoneDate__c FROM ServiceRequest__c WHERE Id = :srId];
        if (!srList.isEmpty()) {
            ServiceRequest__c sr = srList[0];
            if (sr.Sales_Order_Installment__c != null) {
                List<Invoice__c> invoiceList = [SELECT Id, Name, SalesOrderInstallment__c,InvoiceDate__c,Original_Invoice_Date__c FROM Invoice__c WHERE SalesOrderInstallment__c = :sr.Sales_Order_Installment__c];
                if( !invoiceList.isEmpty()){
                    for( Invoice__c inv : invoiceList){
                        inv.Original_Invoice_Date__c = inv.InvoiceDate__c;
                        inv.InvoiceDate__c = sr.Payment_Extension_Date__c;
                        try{
                            update inv;
                        }catch( Exception e){
                            throw new AuraHandledException('Error at Invoice Update:'+e.getMessage());
                        }
                    }
                }
                SalesOrderInstallments__c updatesoi = new SalesOrderInstallments__c();
                updatesoi.Id = sr.Sales_Order_Installment__c;
                updatesoi.Original_Milestone_Date__c = sr.Sales_Order_Installment__r.MilestoneDate__c;
                updatesoi.ExtensionDate__c = sr.Payment_Extension_Date__c;
                try{
                    update updatesoi;
                    return 'success';
                }catch( Exception e){
                    throw new AuraHandledException('Error at Execute:'+e.getMessage());
                }  
            }else{
                return 'No Sales_Order_Installment__c Value Found';
            }
        }else{
            return 'No SR Found';
        }
    }

    
}