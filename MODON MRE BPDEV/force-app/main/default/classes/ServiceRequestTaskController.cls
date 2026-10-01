/**********************************************************************************************************************
* Name               : ServiceRequestTaskController                                                       
* Description        : This is a helper class for ServiceRequestTaskController
* Usage              : Called from TaskTriggerHandler
* Created By         : AMGS                                                     
* -------------------------------createNextStepBRTasks-------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Sirisha Reddy               10 Jan 2025     Create new task for service request
* 1.1           Krishna Chaitanya Ramadugu  10 Jan 2025     Create new task for service request property transfer
* 1.1           Ravi Pasumarthi             10 Jan 2025     Create new task for service request property transfer Titledeed
* 1.1           Raghu Gajjela               10 Jan 2025     Create new task for service request property transfer Payment plan swap
* 1.2           Raghu sharma                24 dec 2025      Added createPassfortTransactionsForBrokerRegistration method and adjusted handleTaskUpdatesBR accordingly
* 1.3           Raghu Sharma                01 Apr 2026      Added Emirates & Passfort documents to Broker Flow and restricted document fetching to Owner agents only
*1.4			Raghu Gajjela				03 Apr 2026		Added a method to update step number and step name on Service request
*1.5			Chandu Battu				30 Apr 2026		Added validation steps on pre and post unit Service request
*1.6			Chandu Battu				20 May 2026		Added validation steps on pre and post unit Service request
*1.7     		Upendra Reddy				16 jun 2026		added a piece of code to capture Due dates
******************************************************************************************************************/
public without sharing class ServiceRequestTaskController { 
    
    public static String TaskRecordTypeId = Schema.SObjectType.Task.getRecordTypeInfosByDeveloperName().get('Service_Request').getRecordTypeId();
    /**
    * @description Sends custom push notifications to task assignees and their managers
    *              when a new task is created with 'Open' status or when a task's status
    *              changes to 'Agent SLA Expired'. Only processes tasks with the 
    *              'Service_Request' record type.
    * @param newList List of new/updated Task records from the trigger
    * @param oldMap  Map of old Task records (keyed by Id) for comparison; null on insert
    */
    public static void sendTaskNotification(List<SObject> newList, Map<Id, SObject> oldMap) {
        Map<Id, Id> taskUserIdMap = new Map<Id, Id>();
        List<Messaging.CustomNotification> notifications = new List<Messaging.CustomNotification>(); 
        
        for (Task newTask: (List<Task>)newList) {
            if (newTask.RecordTypeId == TaskRecordTypeId) {
                Task oldRecord;
                // Check if there is an old task record for comparison (only if oldMap is not empty)
                if (oldMap != null && oldMap.size() > 0 && oldMap.containsKey(newTask.Id)) {
                    oldRecord = (Task)oldMap.get(newTask.Id);
                } else {
                    oldRecord = null;  // If no old record exists, set it to null
                }
                if (oldRecord != null && newTask.Status == Constants.TASK_STATUS_AGENT_SLA_EXPIRED &&
                    newTask.Status != oldRecord.Status) {
                        taskUserIdMap.put(newTask.Id, newTask.ownerId);
                    }
                if (oldRecord == null && newTask.Status == Constants.TASK_STATUS_OPEN) {
                    taskUserIdMap.put(newTask.Id, newTask.ownerId);
                }
            }
        }
        
        if (!taskUserIdMap.keyset().isEmpty()) {
            Map<Id, User> userMap =
                new Map<Id, User>([SELECT Id, ManagerId FROM User WHERE Id IN : taskUserIdMap.values()]);
            
            CustomNotificationType notifType = [SELECT Id FROM CustomNotificationType WHERE DeveloperName = 'Lead_Merge_Notification' LIMIT 1];
            
            for (Task newTask: (List<Task>)newList) {
                if (taskUserIdMap.keySet().contains(newtask.Id)) {
                    Id assigneeId = newTask.OwnerId;
                    Id managerId = userMap.containsKey(assigneeId) ? userMap.get(assigneeId).ManagerId : null;
                    
                    Set<String> recipientIds = new Set<String>();
                    if (assigneeId != null)
                        recipientIds.add(assigneeId);
                    if (managerId != null)
                        recipientIds.add(managerId);
                    
                    if (!recipientIds.isEmpty()) {
                        Messaging.CustomNotification customNotificationObj = new Messaging.CustomNotification();
                        if (newTask.Status == Constants.TASK_STATUS_AGENT_SLA_EXPIRED) {
                            customNotificationObj.setBody('Agent SLA Expired for Task: ' + newTask.Subject);
                            customNotificationObj.setTitle('Agent SLA Expired');
                        } else {
                            customNotificationObj.setBody('A New Task has been assigned to you : ' +  newTask.Subject);
                            customNotificationObj.setTitle('New Task Created');
                        }
                        customNotificationObj.setNotificationTypeId(notifType.Id);
                        customNotificationObj.setTargetId(newTask.Id);
                        customNotificationObj.send(recipientIds);
                    }
                }
            }
        }
    }
    /**
    * @description Creates initial workflow tasks for newly created Service Request records.
    *              Determines which tasks to create based on the Service Request's record type
    *              and subtype (e.g., Next of Kin, New Sale, Normal, Court Order, Unit Upgrade,
    *              Unit Swap, Default SR). Also creates share records for ADM record types.
    * @param newRequests List of newly inserted ServiceRequest__c records
    */
    /*Create New Task for Service Request*/
    public static void createIntialTasks(List<ServiceRequest__c> newRequests) {
        set<Id> srId = new set<Id>();
        String Registartion = 'Completed Registration';
        String DeRegistrationCheck = 'Normal';
        String newSales = 'New Sale';
        string emptycheck ='';
        set<Id> SalesOrderIds = new set<Id>();
        set<String> srSubtype = new set<String>();
        set<Id> salesAgentId = new set<Id>();
        set<Id> srOwnerId = new set<Id>();
        for (ServiceRequest__c sr: newRequests) {
            srId.add(sr.id);
            srSubtype.add(sr.Type__c);
            SalesOrderIds.add(sr.SalesOrder__c);
            salesAgentId.add(sr.Sales_Agent__c);
            srOwnerId.add(sr.OwnerId);
        }
        Map<Id, String> srRecordTypeMap = getServiceRequestRtMap(srId);
        set<string> recordTypeName = new set<string>();
        for (string recName: srRecordTypeMap.Values()) {
            recordTypeName.add(recName);
        }
        
        if (recordTypeName.contains(Constants.SERVICE_REQUEST_RT_DEV_NAME_ADM)) 
        {
            createShareRecord(srId, SalesOrderIds);
            if (!srRecordTypeMap.isEmpty() && srSubtype.contains('Next of Kin')) {
                createIntialStepTasks(srRecordTypeMap, srId, Registartion,null,null);
            } else if (!srRecordTypeMap.isEmpty() && srSubtype.contains('New Sale')) {
                createIntialStepTasks(srRecordTypeMap, srId, newSales,null,srOwnerId);
                
            } else if (!srRecordTypeMap.isEmpty() && (srSubtype.contains('Normal') || srSubtype.contains('Court Order'))) 
            {
                createIntialStepTasks(srRecordTypeMap, srId, DeRegistrationCheck,null,null);
            }
        }else if(recordTypeName.contains(Constants.SERVICE_REQUEST_RT_DEV_NAME_UNIT_UPGRADE) || recordTypeName.contains(Constants.SERVICE_REQUEST_RT_DEV_NAME_UNIT_SWAP)){
            createIntialStepTasks(srRecordTypeMap, srId,'',salesAgentId,null);
        }
        else if(recordTypeName.contains(Constants.SERVICE_REQUEST_Default_SR)){
            createIntialStepTasks(srRecordTypeMap, srId,'',null,srOwnerId);
        } 
        else 
        {
            System.debug('srRecordTypeMap--->' + srRecordTypeMap);
            createIntialStepTasks(srRecordTypeMap, srId,'',null,null);
        }
    }
    /**
    * @description Handles task update logic for standard Service Request workflows.
    *              Updates the parent Service Request status to 'In-progress' when the
    *              first-order task is updated, then evaluates completed tasks to determine
    *              and create the next step tasks in the workflow sequence.
    * @param newTasks        List of updated Task records
    * @param oldtasks        Map of old Task records before the update
    * @param isLwcController Boolean flag indicating if the update was triggered from an LWC component
    */
    public static void handleTaskUpdates(List<Task> newTasks, Map<Id, Sobject> oldtasks,boolean isLwcController) 
    {
        System.debug('newTasks------>113'+newTasks+oldtasks);
        Set<Id> completedTaskServiceRequestIds = getCompletedTaskServiceRequestIds(newTasks, oldtasks,isLwcController);
        Map<Id, Task> taskOrdermap = getTaskOrders(newTasks);
        list<Id> srids = new List<Id>();
        set<Id> setCloseSR = new set<Id>();
        for (task tsk: newTasks) 
        {
            if (tsk.Order__c == 1) 
            {
                srids.add(tsk.WhatId);
            }
            
        }
        if (srids.size() > 0) 
        {
            List<ServiceRequest__c> updatesr = new List<ServiceRequest__c>();
            for (Id srid: srids) 
            {
                ServiceRequest__c sr = new ServiceRequest__c(id = srid, Status__c = 'In-progress');
                updatesr.add(sr);
            }
            update updatesr;
        }
        


        if (!completedTaskServiceRequestIds.isEmpty()) 
        {
            Map<Id, String> taskSubjectMap = getServiceRequestRtMap(completedTaskServiceRequestIds);
            Map<Id, ServiceRequest__c> serviceRequestsubtypeMap = getServiceRequestSubtypeMap(completedTaskServiceRequestIds);
            if (!taskSubjectMap.isEmpty()) 
            {
                createNextStepTasks(completedTaskServiceRequestIds, taskSubjectMap, taskOrdermap,serviceRequestsubtypeMap);
            }
        }        
    }
    
    /**
    * @description Handles task update logic specifically for Broker Registration (BR) workflows.
    *              Updates the parent Service Request status to 'In-progress' when the first-order
    *              task is updated, then evaluates all updated task records to determine and
    *              create the next step tasks in the BR workflow sequence.
    * @param newTasks        List of updated Task records
    * @param oldtasks        Map of old Task records before the update
    * @param isLwcController Boolean flag indicating if the update was triggered from an LWC component
    */
    
    public static void handleTaskUpdatesBR(List<Task> newTasks, Map<Id, Sobject> oldtasks,boolean isLwcController) {
        System.debug('newTasks------>177'+newTasks+oldtasks);
        list<Id> srids = new List<Id>();
        set<Id> recordids = new set<Id>();
        set<Id> setCloseSR = new set<Id>();
        Map<Id, Task> taskOrdermap = getBRTaskOrders(newTasks);
        System.debug('taskOrdermap:::'+taskOrdermap);
        for (task tsk: newTasks){
            if (tsk.Order__c == 1) {
                srids.add(tsk.WhatId);
            }
            recordids.add(tsk.Id);
        }
        if (srids.size() > 0) {
            List<ServiceRequest__c> updatesr = new List<ServiceRequest__c>();
            for (Id srid: srids)  {
                ServiceRequest__c sr = new ServiceRequest__c(id = srid, Status__c = 'In-progress');
                updatesr.add(sr);
            }
            update updatesr;
        }
        system.debug('recordids:::'+recordids);
        if (!recordids.isEmpty()) {
            Map<Id, ServiceRequest__c> serviceRequestsubtypeMap = getServiceRequestSubtypeMap(recordids);
            createNextStepBRTasks(recordids, taskOrdermap,serviceRequestsubtypeMap);
        }   
        
        /*update 1.2 Starts Here
        Description : When the Sr is Moved From step1(Assignment of Broker Manager) to Step3(validation By compliance) Where are Creating Passfort Tranasction
        Records For Such Sr's as a Child of Related Registration record.*/ 
        
        Set<Id> approvedStep1SRs = new Set<Id>();
        
        for (Task t : newTasks) {
            if (
                t.Subject == BRConstants.SERVICE_REQUEST_TASK1 &&
                t.Broker_Registration_Status__c == BRConstants.ACTION_STATUS_APPROVED &&
                oldtasks.containsKey(t.Id) &&
                ((Task) oldtasks.get(t.Id)).Broker_Registration_Status__c
                != BRConstants.ACTION_STATUS_APPROVED
            ) {
                approvedStep1SRs.add(t.WhatId);
            }
        }
        
        if (approvedStep1SRs.isEmpty()) return;
        
        // Get SRs that already have Passfort company transaction
        Set<Id> srWithPassfort = new Set<Id>();
        for (AggregateResult ar : [
            SELECT Service_Request__c srId
            FROM PassfortTransaction__c
            WHERE Service_Request__c IN :approvedStep1SRs
            AND EntityType__c = :Constants.PASSFORT_TR_TYPE_COMPANY
            GROUP BY Service_Request__c
        ]) {
            srWithPassfort.add((Id) ar.get('srId'));
        }
        
        approvedStep1SRs.removeAll(srWithPassfort);
        
        if (!approvedStep1SRs.isEmpty()) {
            createPassfortTransactionsForBrokerRegistration(approvedStep1SRs);
        }     
        //Update 1.2 Ends Here 
    }
    /**
    * @description Performs comprehensive data validation when Service Request tasks are closed.
    *              Enforces business rules across multiple SR workflows including:
    *              - Prospect Account validations (primary count, ownership %, company contacts)
    *              - Broker Registration manager assignment check
    *              - Appointment booking verification for SPA/Handover tasks
    *              - Milestone Update date population checks
    *              - Plot Handover outstanding payment checks
    *              - Default Unit Cancellation mandatory field and approval validations
    *              - Finance cheque handover/clearance status checks
    *              - Unit Upgrade selected unit verification
    *              - Unit Consolidation equity transfer amount and fund transfer checks
    *              Throws field-level errors on the Task record to prevent closure if 
    *              validations fail.
    * @param newTasks List of Task records being updated
    * @param newMap   Map of new Task records keyed by Id
    * @param oldMap   Map of old Task records keyed by Id for status comparison
    */
    public static void serviceRequestDataValidation(List<Task> newTasks, Map<Id, Task> newMap,Map<Id, Task> oldMap) 
    {
        Map<Id, Task> srIds = new Map<Id, Task>();
        Map<Id, Task> financesrIds = new Map<Id, Task>();
        Map<Id, Task> clearancesrIds = new Map<Id, Task>();        
        Map<Id, Task> brokerRegistrationTaskSRMap = new Map<Id, Task>();
        Map<Id, ServiceRequest__c> registrationSRMap = new Map<Id, ServiceRequest__c>();
        Map<Id, Task> upgradeUnitSrIds = new Map<Id, Task>();
        Map<Id, Task> unitConsolidationSrIds = new Map<Id, Task>();
        Map<Id, Task> appointmentIds = new Map<Id, Task>();
        Map<Id, ServiceRequest__c> ServiceRequestsMap;
        Integer primaryCount = 0;
        Integer nonPrimaryCount = 0;
        Map<Id, List<Prospect_Account__c>> accountContacts = new Map<Id, List<Prospect_Account__c>>();
        Set<Id> companyProspectAccounts = new Set<Id>();
        
        Map<Id, Task> plotHandoverUpdateCollectOutstandingSrIds = new Map<Id, Task>();
        Map<Id, Task> defaultCancellationMandatorySrIds = new Map<Id, Task>();
        Map<Id, Task> defaultCancellationFinalStpeSrIds = new Map<Id, Task>();
        Map<Id, Task> defaultCancellationCreationSrIds = new Map<Id, Task>();
        Map<Id, Task> defaultCancellationFinaliseSrIds = new Map<Id, Task>();
        
        Map<Id, Task> preunitCancellationManagementSrIds = new Map<Id, Task>(); //1.5
        Map<Id, Task> preunitCancellationRefundForfeSrIds = new Map<Id, Task>(); //1.5
        Map<Id, Task> postUnitMgmtMap = new Map<Id, Task>(); //1.5
        Map<Id, Task> admStepMap = new Map<Id, Task>(); //1.5
        Map<Id, Task> directDebitStepMap = new Map<Id, Task>(); //1.5
        
        Map<Id, Task> milestoneUpdateSrIds = new Map<Id, Task>();
        Map<Id, Task> plotHandoverUpdateSrIds = new Map<Id, Task>();
        List<String> brokerRegistrationStatusList = new List<String>{BRConstants.ACTION_STATUS_RMI,
            BRConstants.ACTION_STATUS_APPROVED};
                
                // Collect relevant tasks
                for (Task task: newTasks) 
            {
                if (task.recordtypeId == TaskRecordTypeId &&
                    task.WhatId.getSObjectType().getDescribe().getName() == 'ServiceRequest__c' &&
                    task.Status == Constants.TASK_STATUS_CLOSED && oldMap.containsKey(task.Id) &&
                    oldMap.get(task.Id).Status != Constants.TASK_STATUS_CLOSED &&
                    (task.Subject == 'Manage Joint Owner Details with Share Percentage' ||
                     task.Subject == 'Gather New Buyer Details with Share Percentage') || 
                    task.Subject == 'Collect New Buyer and Seller Details' || 
                    task.Subject =='Collect Joint Owner Details and Share Percentage' ||  (task.Subject =='Collect Buyer Details and Required Documents')) 
                {
                    srIds.put(task.WhatId, task);
                    System.debug('srIds------>'+srIds);
                }
                if (task.recordtypeId == TaskRecordTypeId &&
                    task.WhatId.getSObjectType().getDescribe().getName() == 'ServiceRequest__c' &&
                    task.Status == Constants.TASK_STATUS_CLOSED && oldMap.containsKey(task.Id) &&
                    oldMap.get(task.Id).Status != Constants.TASK_STATUS_CLOSED &&
                    task.Subject == Constants.FINANCE_APPROVAL_STEP1) 
                {
                    financesrIds.put(task.WhatId, task);
                }
                if (task.recordtypeId == TaskRecordTypeId &&
                    task.WhatId.getSObjectType().getDescribe().getName() == 'ServiceRequest__c' &&
                    task.Status == Constants.TASK_STATUS_CLOSED && oldMap.containsKey(task.Id) &&
                    oldMap.get(task.Id).Status != Constants.TASK_STATUS_CLOSED &&
                    task.Subject == Constants.FINANCE_APPROVAL_STEP2) 
                {
                    clearancesrIds.put(task.WhatId, task);
                }
                if(task.recordtypeId == TaskRecordTypeId  && 
                   task.WhatId.getSObjectType().getDescribe().getName() == 'ServiceRequest__c'  &&
                   task.Status == Constants.TASK_STATUS_CLOSED && oldMap.containsKey(task.Id) &&
                   oldMap.get(task.Id).Status != Constants.TASK_STATUS_CLOSED &&
                   task.Subject == BRConstants.SERVICE_REQUEST_TASK1 ){
                       brokerRegistrationTaskSRMap.put(task.WhatId, task);
                   }
                if (task.recordtypeId == TaskRecordTypeId &&
                    task.WhatId.getSObjectType().getDescribe().getName() == 'ServiceRequest__c' &&
                    task.Status == Constants.TASK_STATUS_CLOSED && oldMap.containsKey(task.Id) &&
                    oldMap.get(task.Id).Status != Constants.TASK_STATUS_CLOSED &&
                    (task.Subject == 'Book Appointment for SPA Signing'|| task.Subject == 'Book Customer Appointment' || task.Subject =='Book Final Handover Appointment')) 
                {
                    appointmentIds.put(task.WhatId, task);
                }
                System.debug('task------>'+task);
                
                if (task.recordtypeId == TaskRecordTypeId &&
                    task.WhatId.getSObjectType().getDescribe().getName() == 'ServiceRequest__c' &&
                    task.Status == Constants.TASK_STATUS_CLOSED && oldMap.containsKey(task.Id) &&
                    oldMap.get(task.Id).Status != Constants.TASK_STATUS_CLOSED &&
                    task.Subject == 'Milestone Update Service Request Initiated') 
                {
                    milestoneUpdateSrIds.put(task.WhatId, task);
                } 
                
                if ((task.recordtypeId == TaskRecordTypeId &&
                     task.WhatId.getSObjectType().getDescribe().getName() == 'ServiceRequest__c' &&
                     task.Status == Constants.TASK_STATUS_CLOSED && oldMap.containsKey(task.Id) &&
                     oldMap.get(task.Id).Status != Constants.TASK_STATUS_CLOSED &&
                     task.Subject == 'Collect outstanding payment' &&
                     (task.SRType__c =='Plot Handover' )
                    ) || test.isRunningTest()) 
                {
                    plotHandoverUpdateCollectOutstandingSrIds.put(task.WhatId, task);
                }
                
                if (task.recordtypeId == TaskRecordTypeId &&
                    task.WhatId.getSObjectType().getDescribe().getName() == 'ServiceRequest__c' &&
                    task.Status == Constants.TASK_STATUS_CLOSED && oldMap.containsKey(task.Id) &&
                    oldMap.get(task.Id).Status != Constants.TASK_STATUS_CLOSED &&
                    (task.Subject == 'Capture Profit and Loss' || task.Subject == 'Finalize Refund and Forfeiture amount') &&
                    (task.SRType__c =='Default Unit Cancellation' || test.isRunningTest())
                   ) 
                {
                    defaultCancellationMandatorySrIds.put(task.WhatId, task);
                }
                
                if (task.recordtypeId == TaskRecordTypeId &&
                    task.WhatId.getSObjectType().getDescribe().getName() == 'ServiceRequest__c' &&
                    task.Status == Constants.TASK_STATUS_CLOSED && oldMap.containsKey(task.Id) &&
                    oldMap.get(task.Id).Status != Constants.TASK_STATUS_CLOSED &&
                    (task.Subject == 'Management Approval and Execute Unit Cancellation Process') &&
                    (task.SRType__c =='Default Unit Cancellation' || test.isRunningTest())
                   ) 
                {
                    defaultCancellationFinalStpeSrIds.put(task.WhatId, task);
                }
                system.debug('-------task.Subject----------------'+task.Subject+'-----type----------------'+task.SRType__c);
                if (task.recordtypeId == TaskRecordTypeId &&
                    task.WhatId.getSObjectType().getDescribe().getName() == 'ServiceRequest__c' &&
                    task.Status == Constants.TASK_STATUS_CLOSED && oldMap.containsKey(task.Id) &&
                    oldMap.get(task.Id).Status != Constants.TASK_STATUS_CLOSED &&
                    (task.Subject == 'Close SR per Legal advice.' ||
                     task.Subject == 'Close SR  per Legal advice.'
                    ) &&
                    (task.SRType__c =='Default SR' || test.isRunningTest())
                   ) 
                {
                    system.debug('----defaultCancellationCreationSrIds inside---');
                    defaultCancellationCreationSrIds.put(task.WhatId, task);
                }
                
                
                if (task.recordtypeId == TaskRecordTypeId &&
                    task.WhatId.getSObjectType().getDescribe().getName() == 'ServiceRequest__c' &&
                    task.Status == Constants.TASK_STATUS_CLOSED && oldMap.containsKey(task.Id) &&
                    oldMap.get(task.Id).Status != Constants.TASK_STATUS_CLOSED &&
                    (task.Subject == 'Finalize Refund and Forfeiture amount') &&
                    (task.SRType__c =='Default Unit Cancellation'  || test.isRunningTest())
                   ) 
                {
                    defaultCancellationFinaliseSrIds.put(task.WhatId, task);
                }
                
                
                if (task.recordtypeId == TaskRecordTypeId &&
                    task.WhatId.getSObjectType().getDescribe().getName() == 'ServiceRequest__c' &&
                    task.Status == Constants.TASK_STATUS_CLOSED && oldMap.containsKey(task.Id) &&
                    oldMap.get(task.Id).Status != Constants.TASK_STATUS_CLOSED &&
                    (task.Subject == 'Management Approval and Execute Unit Cancellation Process') &&
                    (task.SRType__c =='Pre Unit Cancellation' || test.isRunningTest())) 
                {
                    preunitCancellationManagementSrIds.put(task.WhatId, task);
                }
                
                if (task.recordtypeId == TaskRecordTypeId &&
                    task.WhatId.getSObjectType().getDescribe().getName() == 'ServiceRequest__c' &&
                    task.Status == Constants.TASK_STATUS_CLOSED && oldMap.containsKey(task.Id) &&
                    oldMap.get(task.Id).Status != Constants.TASK_STATUS_CLOSED &&
                    (task.Subject == 'Pre Unit Cancellation Service Request Initiated') && //1.6
                    (task.SRType__c =='Pre Unit Cancellation' || test.isRunningTest())) 
                {
                    preunitCancellationRefundforfeSrIds.put(task.WhatId, task);
                }
                
                
                if (task.recordtypeId == TaskRecordTypeId &&
                    task.WhatId.getSObjectType().getDescribe().getName() == 'ServiceRequest__c' &&
                    task.Status == Constants.TASK_STATUS_CLOSED &&
                    oldMap.containsKey(task.Id) &&
                    oldMap.get(task.Id).Status != Constants.TASK_STATUS_CLOSED &&
                    (task.SRType__c =='Post Unit Cancellation' || test.isRunningTest())
                   ) {
                       
                       if(task.Subject == 'Management Approval and Execute Unit Cancellation Process'){
                           postUnitMgmtMap.put(task.WhatId, task);
                       }
                   }
                
                
                if (task.recordtypeId == TaskRecordTypeId &&
                    task.WhatId != null &&
                    task.WhatId.getSObjectType().getDescribe().getName() == 'ServiceRequest__c' &&
                    task.Status == Constants.TASK_STATUS_CLOSED &&
                    oldMap.containsKey(task.Id) &&
                    oldMap.get(task.Id).Status != Constants.TASK_STATUS_CLOSED) {
                        
                        if (task.Subject == 'ADM De-Registration') {
                            admStepMap.put(task.WhatId, task);
                        }
                        
                        if (task.Subject == 'Direct Debit Check') {
                            directDebitStepMap.put(task.WhatId, task);
                        }
                    }
                
                if (task.recordtypeId == TaskRecordTypeId &&
                    task.WhatId.getSObjectType().getDescribe().getName() == 'ServiceRequest__c' &&
                    task.Status == Constants.TASK_STATUS_CLOSED && oldMap.containsKey(task.Id) &&
                    oldMap.get(task.Id).Status != Constants.TASK_STATUS_CLOSED &&
                    task.Subject == 'Start Title Deed registration') 
                {
                    plotHandoverUpdateSrIds.put(task.WhatId, task);
                }
                
                if (task.recordtypeId == TaskRecordTypeId && //1.5 start
                    task.WhatId.getSObjectType().getDescribe().getName() == 'ServiceRequest__c' &&
                    task.Status == Constants.TASK_STATUS_CLOSED && oldMap.containsKey(task.Id) &&
                    oldMap.get(task.Id).Status != Constants.TASK_STATUS_CLOSED &&
                    task.Subject == 'Sales Agent to select the Unit') 
                {
                    upgradeUnitSrIds.put(task.WhatId, task);
                }
                if (task.recordtypeId == TaskRecordTypeId &&
                    task.WhatId.getSObjectType().getDescribe().getName() == 'ServiceRequest__c' &&
                    task.Status == Constants.TASK_STATUS_CLOSED && oldMap.containsKey(task.Id) &&
                    oldMap.get(task.Id).Status != Constants.TASK_STATUS_CLOSED &&
                    (task.Subject == 'Acknowledgement of Equity Transfer and Forfeiture Amount'||task.Subject == 'Updating Approved Equity Transfer Amount')) 
                {
                    unitConsolidationSrIds.put(task.WhatId, task);
                }
                
            } //1.5 end
        System.debug('milestoneUpdateSrIds------>'+milestoneUpdateSrIds);
        if(!brokerRegistrationTaskSRMap.keySet().isEmpty()){
            ServiceRequestsMap = new Map<Id, ServiceRequest__c>([SELECT
                                                                 Id,
                                                                 Registration__c,
                                                                 Registration__r.Broker_Manager__c
                                                                 FROM 
                                                                 ServiceRequest__c
                                                                 WHERE Id in:brokerRegistrationTaskSRMap.keySet()]);
            
            
        }
        for(Task task: newTasks){
            system.debug('ServiceRequestsMap:::'+ServiceRequestsMap);
            if(task.recordtypeId == TaskRecordTypeId){
                if(task.WhatId.getSObjectType().getDescribe().getName() == 'ServiceRequest__c' && 
                   task.Status == Constants.TASK_STATUS_CLOSED && oldMap.containsKey(task.Id) &&
                   oldMap.get(task.Id).Status != Constants.TASK_STATUS_CLOSED 
                   && (task.Subject == BRConstants.SERVICE_REQUEST_TASK1 )
                   && brokerRegistrationStatusList.contains(task.Broker_Registration_Status__c) 
                   && ServiceRequestsMap.get(task.WhatId).Registration__r.Broker_Manager__c == null){
                       task.addError('Please assign the Broker manager at Registration record, before completing this step');
                   }
            }
        }
        
        if (!srIds.isEmpty()) 
        {
            List<Prospect_Account__c> prospectAccounts = [SELECT Id, Is_Primary__c, IsPersonAccount__c, RecordTypeName__c, Account__c,
                                                          Prospect_Account__c, Service_Request__r.Total_Ownership__c,
                                                          Service_Request__r.RecordTypeName__c,OwnershipPercentage__c,Name,Service_Request__r.SubType__c,JO_Deleted__c 
                                                          FROM Prospect_Account__c 
                                                          WHERE Service_Request__c IN : srIds.keySet()];
            Map<Id, Decimal> OwnershipMap = new Map<Id, decimal>();
            
            string pAccNames = '';
            
            if (!prospectAccounts.isEmpty()) 
            {
                Map<Id, Boolean> accountsWithPrimary = new Map<Id, Boolean>();
                
                for (Prospect_Account__c pAcc: prospectAccounts) 
                {
                    if (pAcc.RecordTypeName__c == 'Contact' && pAcc.Is_Primary__c && !pAcc.JO_Deleted__c) 
                    {
                        primaryCount++;
                    }
                    if(!pAcc.Is_Primary__c && !pAcc.JO_Deleted__c)
                    {
                        nonPrimaryCount++;
                    }
                    /*if(pAcc.JO_Deleted__c && pAcc.Service_Request__r.SubType__c == 'Joint Owner Addition')
                    {
                    srIds.get(pAcc.Service_Request__c).addError('The ' + pAcc.Name + ' is marked for deletion. This is not allowed for JO Addition service request.');
                    }*/
                    
                    OwnershipMap.put(pAcc.Service_Request__c, pAcc.Service_Request__r.Total_Ownership__c);
                    if (pAcc.RecordTypeName__c == 'Account') 
                    {
                        companyProspectAccounts.add(pAcc.Id);
                        pAccNames = pAccNames + pAcc.Name + ',';
                    }
                    if (pAcc.RecordTypeName__c == 'Contact' && pAcc.Prospect_Account__c != null && !pAcc.IsPersonAccount__c) 
                    {
                        if (!accountContacts.containsKey(pAcc.Prospect_Account__c)) 
                        {
                            accountContacts.put(pAcc.Prospect_Account__c, new List<Prospect_Account__c>());
                        }
                        accountContacts.get(pAcc.Prospect_Account__c).add(pAcc);
                    } 
                    else if (pAcc.RecordTypeName__c == 'Contact' && pAcc.Prospect_Account__c == null && !pAcc.IsPersonAccount__c) 
                    {
                        srIds.get(pAcc.Service_Request__c).addError('Cannot create a Contact Prospect without a Parent.' + pAcc.Name);
                    }
                    
                    system.debug('debug: pAcc.Name ' + pAcc.Name);
                    system.debug('debug: pAcc.OwnershipPercentage__c ' + pAcc.OwnershipPercentage__c);
                    //Commented as per new requirement
                    // if(!(pAcc.OwnershipPercentage__c >= 1) && !(pAcc.JO_Deleted__c))
                    // {
                    //     srIds.get(pAcc.Service_Request__c).addError('Ownership should be atleast 1% on ' + pAcc.Name);
                    // }
                    
                }
                
                if (primaryCount != 1) 
                {
                    for (Task task: newTasks) 
                    {
                        task.addError('Exactly 1 Primary Account is required. Please verify your selection.');
                    }
                }
                
                for (Id srid: OwnershipMap.keySet()) 
                {
                    if (OwnershipMap.get(srid) != 100.00) 
                    {
                        Task tsk = srIds.get(srid);
                        tsk.addError('Ownership % needs to sum up to 100');
                    }
                }
                
                if (accountContacts.keySet().size() != companyProspectAccounts.size()) 
                {
                    for (Task task: newTasks) 
                    {
                        task.addError('Org Account Prospects are created without Contact Prospect.' + pAccNames);
                    }
                }
                
                
                for (Id accId: accountContacts.keySet()) 
                {
                    Boolean hasSinglePrimary = false;
                    Boolean hasMultiplePrimary = false;
                    
                    for (Prospect_Account__c contact: accountContacts.get(accId)) 
                    {
                        if (contact.Is_Primary__c) 
                        {
                            if (hasSinglePrimary) 
                            {
                                hasMultiplePrimary = true;
                            }
                            hasSinglePrimary = true;
                        }
                    }
                    
                    if (hasMultiplePrimary) 
                    {
                        for (Task task: newTasks) 
                        {
                            task.addError('Company Prospects are created with more than 1 Primary Contact Prospect.');
                        }
                    } 
                    else if (!hasSinglePrimary) 
                    {
                        for (Task task: newTasks) 
                        {
                            task.addError('Company Prospects are created without a Primary Contact Prospect.');
                        }
                    }
                }
                
                system.debug('debug: checking joint owner addition');
                for(Prospect_Account__c pAcc: prospectAccounts)
                {
                    system.debug('debug: pAcc.Service_Request__r.RecordTypeName__c ' + pAcc.Service_Request__r.RecordTypeName__c);
                    system.debug('debug: nonPrimaryCount ' + nonPrimaryCount);
                    system.debug('debug: pAcc.Service_Request__r.SubType__c ' + pAcc.Service_Request__r.SubType__c);
                    system.debug('debug: pAcc.JO_Deleted__c ' + pAcc.JO_Deleted__c);
                    
                    if(pAcc.Service_Request__r.RecordTypeName__c == Constants.SERVICE_REQUEST_RT_DEV_NAME_JOINT_OWNER_TITLE_DEED &&
                       pAcc.JO_Deleted__c && pAcc.Service_Request__r.SubType__c == 'Joint Owner Addition')
                    {
                        system.debug('debug: you are here '+ pAcc.Name);
                        srIds.get(pAcc.Service_Request__c).addError('The ' + pAcc.Name + ' is marked for deletion. This is not allowed for JO Addition service request.');
                    }
                    else if(pAcc.Service_Request__r.RecordTypeName__c == Constants.SERVICE_REQUEST_RT_DEV_NAME_JOINT_OWNER_TITLE_DEED && nonPrimaryCount == 0
                            && (pAcc.Service_Request__r.SubType__c == 'Joint Owner Addition' || pAcc.Service_Request__r.SubType__c == 'Manage JO'))
                    {
                        srIds.get(pAcc.Service_Request__c).addError('Please add a Prospect Account as a Joint Owner.');
                    }
                }
            } 
            else 
            {
                for (Task task: newTasks) 
                {
                    System.debug('Error---->'+task);
                    task.addError('Unable to find buyer details. Please add details in the Prospect Account Tab.');
                }
            }
        }
        
        if (!appointmentIds.isEmpty()) 
        {
            List<Event> events = [SELECT Id, Subject, StartDateTime,EndDateTime,WhatId FROM Event WHERE whatId IN : appointmentIds.keySet()];
            Map<string,List<Event>>eventMapApp = new Map<string,List<Event>>();
            for(Event ev : events){
                string keyRec= ev.Subject+ev.whatId;
                if(eventMapApp.get(keyRec)==null)eventMapApp.put(keyRec,new List<Event>());
                eventMapApp.get(keyRec).add(ev);
            }
            if (events.size() == 0) 
            {
                for (Task task: appointmentIds.values()) 
                {
                    task.addError('Please Book an appointment to close this Task.');
                }
            }
            system.debug('----------eventMapApp ----------'+eventMapApp);
            
            for (Task task: newTasks) 
            {
                if(appointmentIds.containskey(task.WhatId) && task.Subject =='Book Final Handover Appointment' && task.SRType__c =='Plot Handover'){
                    string eventName = 'Appointment with Customer'+task.WhatId;
                    List<Event> evetList = eventMapApp.containskey(eventName) ? eventMapApp.get(eventName) : new List<Event>();
                    system.debug('----------eventName ----------'+eventName );
                    system.debug('----------evetList ----------'+evetList  );
                    if(evetList.size() != 2){
                        task.addError('Please Book an appointment to close this Task.');
                    }
                }
            }            
        }
        
        system.debug('----------defaultCancellationCreationSrIds----------'+defaultCancellationCreationSrIds);
        
        if(!defaultCancellationCreationSrIds.isEmpty()){
            
            Map<string,ServiceRequest__c>defaultCancellationCreationSRsIds= new Map<string,ServiceRequest__c>([
                SELECT Id,Name,RecordTypeName__c,Legal_Decision__c,SalesOrder__c,SalesOrder__r.Name,RecordTypeId,Cancellation_Date__c,SalesOrder__r.Totalpaidamount__c
                from ServiceRequest__c 
                where Id IN:defaultCancellationCreationSrIds.keyset() and SalesOrder__c != null
                and SalesOrder__r.Total_Outstanding__c > 0 and
                //and Legal_Decision__c != null and 
                (Legal_Decision__c ='Cancel with Refund' or Legal_Decision__c ='Cancel without Refund')
            ]);
            system.debug('----------defaultCancellationCreationSRsIds----------'+defaultCancellationCreationSRsIds);
            
            List<ServiceRequest__c> ServiceRequestToCreate = new List<ServiceRequest__c>();
            Id ucUpdateRecordTypeId = Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType,'DefaultUnitCancellation');
            
            for (Task task: newTasks) 
            {
                if(defaultCancellationCreationSRsIds.containskey(task.WhatId))
                {
                    ServiceRequest__c  md =  defaultCancellationCreationSRsIds.get(task.WhatId);
                    ServiceRequest__c newSR= DefaultUnitCancellationSRCreationBatch.createUnitCancellation(md,ucUpdateRecordTypeId);
                    ServiceRequestToCreate.add(newSR);  
                }
            }
            if(ServiceRequestToCreate.size()>0){
                insert ServiceRequestToCreate;
                system.debug('----------ServiceRequestToCreate----------'+ServiceRequestToCreate);
            }
        }
        system.debug('----------defaultCancellationFinaliseSrIds----------'+defaultCancellationFinaliseSrIds);
        
        if(!defaultCancellationFinaliseSrIds.isEmpty()){
            
            Map<string,ServiceRequest__c>defaultCancellationFinaliseSrIdsMap = new Map<string,ServiceRequest__c>([
                SELECT Id,Name,Total_Paid_Amount__c,Refund_Amount__c,Forfeiture__c,Forfeiture_Amount__c
                from ServiceRequest__c 
                where Id IN:defaultCancellationFinaliseSrIds.keyset() and SalesOrder__c != null
            ]);
            system.debug('----------defaultCancellationFinaliseSrIdsMap----------'+defaultCancellationFinaliseSrIdsMap);
            
            for (Task task: newTasks) 
            {
                if(defaultCancellationFinaliseSrIds.containskey(task.WhatId))
                {
                    ServiceRequest__c srCancel = defaultCancellationFinaliseSrIdsMap.get(task.WhatId);
                    decimal totalPaidAmount = srCancel.Total_Paid_Amount__c != null ? srCancel.Total_Paid_Amount__c :0;
                    decimal Refund_Amount = srCancel.Refund_Amount__c != null ? srCancel.Refund_Amount__c :0;
                    decimal Forfeiture = srCancel.Forfeiture_Amount__c != null ? srCancel.Forfeiture_Amount__c :0;
                    system.debug('-------totalPaidAmount ---------'+totalPaidAmount );
                    system.debug('-------Refund_Amount ---------'+Refund_Amount );
                    system.debug('-------Forfeiture ---------'+Forfeiture );
                    decimal totalEntered = Refund_Amount + Forfeiture;
                    system.debug('-------totalEntered ---------'+totalEntered );
                    
                    if(totalPaidAmount != totalEntered ){
                        task.addError('Total Paid amount should be equal to entered sum of Forfeiture and refund amounts');
                    }
                }
            }
        }
        
        if(!defaultCancellationFinalStpeSrIds.isEmpty()){
            
            Map<string,ServiceRequest__c>defaultCancellationSRsIds= new Map<string,ServiceRequest__c>([
                select id,SalesOrder__c,CM_Approval_Status__c,Final_Execution_Complete__c
                from ServiceRequest__c 
                where Id IN:defaultCancellationFinalStpeSrIds.keyset() and SalesOrder__c != null
            ]);
            
            System.debug('-------------defaultCancellationSRsIds-----------------'+defaultCancellationSRsIds);
            for (Task task: newTasks) 
            {
                if(defaultCancellationSRsIds.containskey(task.WhatId))
                {
                    ServiceRequest__c srRec = defaultCancellationSRsIds.get(task.WhatId);
                    System.debug('--------Cancellation-----srRec -----------------'+srRec );  
                    if(srRec.CM_Approval_Status__c !='Approved by CM Manager'){
                        task.addError('Management approval is pending. You are not allowed to proceed the Unit Cancellation process');
                    }else{
                        if(!srRec.Final_Execution_Complete__c){
                            task.addError('Please execute the process to complete the unit termination');
                        }
                    }                  
                }
            }
        }
        
        if(!defaultCancellationMandatorySrIds.isEmpty()){
            
            Map<string,ServiceRequest__c>defaultCancellationSRs= new Map<string,ServiceRequest__c>([
                select id,SalesOrder__c,Secondary_Market_Value__c,Market_Loss__c,
                Broker_Commission__c,Sales_Commission__c,Discount__c,
                Rebate__c,ADM_Fee__c,Service_Charge_Waiver__c,LPC__c,Legal_Admin_Fees__c,
                Forfeiture_Amount__c,Refund_Amount__c
                from ServiceRequest__c 
                where Id IN:defaultCancellationMandatorySrIds.keyset() and SalesOrder__c != null
            ]);
            
            
            System.debug('-------------defaultCancellationSRs-----------------'+defaultCancellationSRs);
            for (Task task: newTasks) 
            {
                if(defaultCancellationSRs.containskey(task.WhatId))
                {
                    ServiceRequest__c srRec = defaultCancellationSRs.get(task.WhatId);
                    System.debug('-------------srRec -----------------'+srRec );
                    
                    if(srRec != null && srRec.Id != null){
                        string errorFields =  (srRec.Secondary_Market_Value__c == null) ? 'Secondary Market Value' :'';
                        System.debug('-------------srRec.Market_Loss__c -----------------'+srRec.Market_Loss__c );
                        
                        if(srRec.Secondary_Market_Value__c== null){
                            errorFields += (errorFields !='')  ? ',Secondary Market Value' :'Secondary Market Value';
                        }
                        if(srRec.Market_Loss__c== null){
                            errorFields += (errorFields !='')  ? ',Market Loss' :'Market Loss';
                        }
                        if(srRec.Broker_Commission__c == null){
                            errorFields += (errorFields !='')  ? ',Broker Commission ' :'Broker Commission ';
                        }
                        if(srRec.Sales_Commission__c == null){
                            errorFields += (errorFields !='')  ? ',Sales Commission ' :'Sales Commission ';
                        }
                        if(srRec.Discount__c == null){
                            errorFields += (errorFields !='')  ? ',Discount' :'Discount';
                        }
                        if(srRec.Rebate__c == null){
                            errorFields += (errorFields !='')  ? ',Rebate' :'Rebate';
                        }
                        if(srRec.ADM_Fee__c == null){
                            errorFields += (errorFields !='')  ? ',ADM Fee' :'ADM Fee';
                        }
                        if(srRec.Service_Charge_Waiver__c == null){
                            errorFields += (errorFields !='')  ? ',Service Charge Waiver' :'Service Charge Waiver';
                        }
                        if(srRec.LPC__c == null){
                            errorFields += (errorFields !='')  ? ',LPC' :'LPC';
                        }
                        if(srRec.Legal_Admin_Fees__c == null){
                            errorFields += (errorFields !='')  ? ',Legal Admin Fees' :'Legal Admin Fees';
                        }
                        if(task.Subject == 'Finalize Refund and Forfeiture amount'){
                            if(srRec.Forfeiture_Amount__c== null){
                                errorFields += (errorFields !='')  ? ',Forfeiture' :'Forfeiture';
                            }
                            if(srRec.Refund_Amount__c == null){
                                errorFields += (errorFields !='')  ? ',Refund Amount' :'Refund Amount';
                            }
                        }
                        if(errorFields != ''){
                            task.addError('Please enter the following Mandatory fields ( '+errorFields+ ') to capture the Profit and Loss ');
                        }
                    }
                }
            }
        }
        
        if(!preunitCancellationManagementSrIds.isEmpty()){ //1.5 start
            
            Map<string,ServiceRequest__c>preunitcancellationmgmtSRsIds= new Map<string,ServiceRequest__c>([
                select id,SalesOrder__c,CM_Approval_Status__c,Final_Execution_Complete__c,Approval_Status__c
                from ServiceRequest__c 
                where Id IN:preunitCancellationManagementSrIds.keyset() and SalesOrder__c != null
            ]);
            
            // System.debug('-------------defaultCancellationSRsIds-----------------'+defaultCancellationSRsIds);
            for (Task task: newTasks) 
            {
                if(preunitCancellationManagementSrIds.containskey(task.WhatId))
                {
                    ServiceRequest__c srRec = preunitcancellationmgmtSRsIds.get(task.WhatId);
                    System.debug('--------Cancellation-----srRec -----------------'+srRec );  
                    if(srRec.Approval_Status__c !='Approved'){
                        task.addError('Management approval is pending. You are not allowed to proceed the Unit Cancellation process');
                    }                 
                }
            }
        }
        
        
        if(!preunitCancellationRefundForfeSrIds.isEmpty()){
            //1.6
            Map<Id, ServiceRequest__c> srMap = new Map<Id, ServiceRequest__c>([
                SELECT Id,
                Cancellation_Type__c,
                Payable_to_Customer__c,
                AccountId__c,
                AccountId__r.Bank_Name__c,
                AccountId__r.Bank_Branch_Name__c,
                AccountId__r.Bank_Country__c,
                AccountId__r.Beneficiary_Name__c,
                AccountId__r.Bank_Account_Number__c,
                AccountId__r.IBAN_Number__c,
                AccountId__r.Swift_Code__c
                FROM ServiceRequest__c 
                WHERE Id IN :preunitCancellationRefundForfeSrIds.keySet()
            ]);
            
            // Fetch Documents
            Map<Id, List<Documents__c>> docMap = new Map<Id, List<Documents__c>>();
            
            for(Documents__c doc : [
                SELECT Id, Name, Service_Request__c
                FROM Documents__c
                WHERE Service_Request__c IN :preunitCancellationRefundForfeSrIds.keySet()
            ]){
                if(!docMap.containsKey(doc.Service_Request__c)){
                    docMap.put(doc.Service_Request__c, new List<Documents__c>());
                }
                docMap.get(doc.Service_Request__c).add(doc);
            }
            
            for (Task task: newTasks) 
            {
                if(preunitCancellationRefundForfeSrIds.containsKey(task.WhatId))
                {
                    ServiceRequest__c srRec = srMap.get(task.WhatId);
                    
                    if(srRec == null) continue;
                    
                    // start 1.6 Bank Details Validation
                    if(srRec.Cancellation_Type__c == 'Cancellation with Refund'){
                    if(
                        srRec.AccountId__c == null ||
                        String.isBlank(srRec.AccountId__r.Bank_Name__c) ||
                        String.isBlank(srRec.AccountId__r.Bank_Branch_Name__c) ||
                        String.isBlank(srRec.AccountId__r.Bank_Country__c) ||
                        String.isBlank(srRec.AccountId__r.Beneficiary_Name__c) ||
                        String.isBlank(srRec.AccountId__r.Bank_Account_Number__c) ||
                        String.isBlank(srRec.AccountId__r.IBAN_Number__c) ||
                        String.isBlank(srRec.AccountId__r.Swift_Code__c)
                    ){
                        task.addError(
                            'Please fill all mandatory bank details on the related Account before closing this step.'
                        );
                    } 
                    }//End 1.6
                    if(srRec.Cancellation_Type__c == 'Cancellation with Refund'){
                        
                        List<Documents__c> docs = docMap.get(srRec.Id);
                        Set<Id> bankDocIds = new Set<Id>();
                        
                        if(docs != null){
                            for(Documents__c d : docs){
                                if(d.Name != null && d.Name.contains('Bank')){
                                    bankDocIds.add(d.Id);
                                }
                            }
                        }
                        
                        List<ContentDocumentLink> links = [
                            SELECT Id
                            FROM ContentDocumentLink
                            WHERE LinkedEntityId IN :bankDocIds
                        ];
                        
                        if(bankDocIds.isEmpty() || links.isEmpty()){
                            task.addError('Please upload Bank Details document before closing this step.');
                        }
                    }
                    
                    else if(srRec.Cancellation_Type__c == 'Consolidation Cancellation'){
                        
                        List<Unit_Consolidation__c> ucList = [
                            SELECT Transfer_Amount__c
                            FROM Unit_Consolidation__c
                            WHERE Service_Request__c = :srRec.Id
                        ];
                        
                        if(ucList == null || ucList.isEmpty()){
                            task.addError('Please add Unit Consolidation records before proceeding.');
                        }
                        else{
                            Decimal totalTransfer = 0;
                            //1.6 
                            for(Unit_Consolidation__c uc : ucList){
                                totalTransfer += (
                                    uc.Transfer_Amount__c != null
                                    ? uc.Transfer_Amount__c
                                    : 0
                                );
                            }
                            // 1.6
                            Decimal payable = (
                                srRec.Payable_to_Customer__c != null
                                ? srRec.Payable_to_Customer__c
                                : 0
                            );
                            


                            if(totalTransfer.setScale(2) != payable.setScale(2)){
                                task.addError(
                                    'Total Transfer Amount (' + totalTransfer +
                                    ') must be equal to Payable to Customer (' + payable + ').'
                                );
                            }
                        }
                    }
                }
            }
        } 
        
        
        if(!postUnitMgmtMap.isEmpty()){
            
            Map<Id, ServiceRequest__c> srMap = new Map<Id, ServiceRequest__c>([
                SELECT Id, SalesOrder__c, CM_Approval_Status__c, Final_Execution_Complete__c, Approval_Status__c
                FROM ServiceRequest__c 
                WHERE Id IN :postUnitMgmtMap.keySet() 
                AND SalesOrder__c != null
            ]);
            
            for (Task task: newTasks) 
            {
                if(postUnitMgmtMap.containsKey(task.WhatId))
                {
                    ServiceRequest__c srRec = srMap.get(task.WhatId);
                    
                    if(srRec != null && srRec.Approval_Status__c != 'Approved'){
                        task.addError('Management approval is pending. You are not allowed to proceed the Unit Cancellation process');
                    }                 
                }
            }
        }
        
        Id admRtId = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByName().get('ADM Registration').getRecordTypeId();
        
        if (!admStepMap.isEmpty()) {
            
            Map<Id, ServiceRequest__c> srMap = new Map<Id, ServiceRequest__c>([
                SELECT Id, SalesOrder__c,ADM_De_Registration_Id__c
                FROM ServiceRequest__c
                WHERE Id IN :admStepMap.keySet()
            ]);
            
            Set<Id> soIds = new Set<Id>();
            for (ServiceRequest__c sr : srMap.values()) {
                if (sr.SalesOrder__c != null) {
                    soIds.add(sr.SalesOrder__c);
                }
            }
            
            Map<Id, List<ServiceRequest__c>> admSrMap = new Map<Id, List<ServiceRequest__c>>();
            
            for (ServiceRequest__c sr : [
                SELECT Id, SalesOrder__c, Status__c,ADM_De_Registration_Id__c
                FROM ServiceRequest__c
                WHERE SalesOrder__c IN :soIds
                AND RecordTypeId = :admRtId
            ]) {
                if (!admSrMap.containsKey(sr.SalesOrder__c)) {
                    admSrMap.put(sr.SalesOrder__c, new List<ServiceRequest__c>());
                }
                admSrMap.get(sr.SalesOrder__c).add(sr);
            }
            
            for (Task t : admStepMap.values()) {
                
                ServiceRequest__c currentSR = srMap.get(t.WhatId);
                if (currentSR == null) continue;
                
                if (admSrMap.containsKey(currentSR.SalesOrder__c)) {
                    
                    Boolean hasOpenADM = false;
                    
                    for (ServiceRequest__c admSR : admSrMap.get(currentSR.SalesOrder__c)) {
                        
                        if (admSR.Status__c != null && admSR.Status__c != 'Closed') {
                            hasOpenADM = true;
                            break;
                        }
                    }
                    
                    if (hasOpenADM) {
                        t.addError('ADM Registration is still active. Please close it before proceeding.');
                        continue;
                    }
                    
                    if (String.isBlank(currentSR.ADM_De_Registration_Id__c)) {
                        t.addError('Please enter value in ADM Request Status field.');
                    }
                }
            }
        }
        
        if (!directDebitStepMap.isEmpty()) {
            
            Map<Id, ServiceRequest__c> srMap = new Map<Id, ServiceRequest__c>([
                SELECT Id, SalesOrder__c,Direct_Debit_Request_Status__c
                FROM ServiceRequest__c
                WHERE Id IN :directDebitStepMap.keySet()
            ]);
            
            Set<Id> soIds = new Set<Id>();
            for (ServiceRequest__c sr : srMap.values()) {
                if (sr.SalesOrder__c != null) {
                    soIds.add(sr.SalesOrder__c);
                }
            }
            
            Map<Id, List<DirectDebitRequest__c>> ddMap = new Map<Id, List<DirectDebitRequest__c>>();
            
            for (DirectDebitRequest__c dd : [
                SELECT Id, SalesOrder__c, IsActive__c
                FROM DirectDebitRequest__c
                WHERE SalesOrder__c IN :soIds
            ]) {
                if (!ddMap.containsKey(dd.SalesOrder__c)) {
                    ddMap.put(dd.SalesOrder__c, new List<DirectDebitRequest__c>());
                }
                ddMap.get(dd.SalesOrder__c).add(dd);
            }
            
            for (Task t : directDebitStepMap.values()) {
                
                ServiceRequest__c sr = srMap.get(t.WhatId);
                if (sr == null) continue;
                
                if (!ddMap.containsKey(sr.SalesOrder__c)) {
                    continue;
                }
                
                Boolean hasActiveDD = false;
                
                for (DirectDebitRequest__c dd : ddMap.get(sr.SalesOrder__c)) {
                    
                    if (dd.IsActive__c) {  
                        hasActiveDD = true;
                        break;
                    }
                }
                
                if (hasActiveDD) {
                    t.addError('Active Direct Debit exists. Please deactivate it before proceeding.');
                    continue;
                }
                
                if (sr.Direct_Debit_Request_Status__c == null) {
                    t.addError('Please enter value in Direct Debit Request Status field.');
                }
            }
        } //1.5 end
        
        if(!plotHandoverUpdateCollectOutstandingSrIds.isEmpty()){
            
            Map<string,ServiceRequest__c>plothandoverSRs= new Map<string,ServiceRequest__c>([
                select id,SalesOrder__c from ServiceRequest__c where Id IN:plotHandoverUpdateCollectOutstandingSrIds.keyset() and SalesOrder__c != null
            ]);
            Set<Id>salesOrderIdsRec = new  Set<Id>();
            for(ServiceRequest__c sr : plothandoverSRs.values()){
                salesOrderIdsRec.add(sr.SalesOrder__c); 
            }
            
            Map<string,decimal>balanceSOMap = new Map<string,decimal>();
            /*AggregateResult[] groupedResults = [
            select Count(Id),SalesOrder__c sales from SalesOrderInstallments__c 
            where SalesOrder__c IN:salesOrderIdsRec and MilestoneDate__c < TODAY
            and PaymentStatus__c ='Not Paid' 
            group by SalesOrder__c 
            ];*/
            AggregateResult[] groupedResults = [
                SELECT SalesOrderInstallment__r.SalesOrder__c soId,SUM(InvoiceBalance__c) 
                FROM Invoice__c 
                where SalesOrderInstallment__c != null
                AND Sales_Order__c = null
                AND SalesOrderInstallment__r.SalesOrder__c IN:salesOrderIdsRec 
                and InvoiceStatus__c != 'Cancelled' and SalesOrderInstallment__r.MilestoneDate__c < today
                group by SalesOrderInstallment__r.SalesOrder__c
            ];
            AggregateResult[] groupedResultsOthers = [
                SELECT Sales_Order__c soId,SUM(InvoiceBalance__c) 
                FROM Invoice__c 
                where SalesOrderInstallment__c = null
                AND Sales_Order__c IN:salesOrderIdsRec 
                and InvoiceStatus__c != 'Cancelled' 
                and InvoiceDate__c  < today 
                group by Sales_Order__c 
            ];
            /*
            SELECT SalesOrderInstallment__r.SalesOrder__c soId,SUM(InvoiceBalance__c) FROM Invoice__c 
            where SalesOrderInstallment__r.SalesOrder__c IN:salesOrderIdsRec and InvoiceStatus__c != 'Cancelled' 
            and InvoiceDate__c  <  TODAY group by SalesOrderInstallment__r.SalesOrder__c
            */
            for (AggregateResult ar : groupedResults)  {
                balanceSOMap.put(string.ValueOf(ar.get('soId')),(decimal) ar.get('expr0')); 
            }
            
            for (AggregateResult ar : groupedResultsOthers)  {
                decimal existingbalance = balanceSOMap.containskey(string.ValueOf(ar.get('soId'))) ? balanceSOMap.get(string.ValueOf(ar.get('soId'))) : 0;
                existingbalance += (decimal) ar.get('expr0');
                balanceSOMap.put(string.ValueOf(ar.get('soId')),existingbalance); 
            }
            
            System.debug('-------------balanceSOMap-----------------'+balanceSOMap);
            for (Task task: newTasks) 
            {
                if(plothandoverSRs.containskey(task.WhatId))
                {
                    string soId = plothandoverSRs.get(task.WhatId).SalesOrder__c;
                    if(balanceSOMap.containskey(soId) && balanceSOMap.get(soId)>0){
                        task.addError('Action cannot be closed due to Outstanding payment of '+balanceSOMap.get(soId) +' installments');
                    }
                }
            }
            
        }
        if(!milestoneUpdateSrIds.isEmpty())
        {
            System.debug('-----inside--------milestoneUpdateSrIds------>'+milestoneUpdateSrIds);
            
            Map<string,ServiceRequest__c>srMapMilestone = new Map<string,ServiceRequest__c>([
                select id,Milestone__c from ServiceRequest__c where Id IN:milestoneUpdateSrIds.keyset()
            ]);
            
            List<Milestone_Update_Tracker__c> milestoneTrackerList = [  select Id,MilestoneRec__c,Reschedule_Milestone_Date__c,Milestone__c,Milestone__r.Name,Service_Request__c,Confirmed_Milestone_Date__c 
                                                                      from Milestone_Update_Tracker__c 
                                                                      where Service_Request__c IN: milestoneUpdateSrIds.keyset() 
                                                                      //and Confirmed_Milestone_Date__c = null 
                                                                      //and Reschedule_Milestone_Date__c = null
                                                                      order by Service_Request__c asc];
            
            System.debug('-----inside--------milestoneTrackerList ------>'+milestoneTrackerList );
            
            Map<string,string>milestoneSRMap = new Map<string,string>();
            string keyMesage ='Please Populate either Confirmed Milestone Date or Reschedule Milestone Date for these Milestones (';
            for(Milestone_Update_Tracker__c ms : milestoneTrackerList)
            {
                ServiceRequest__c  srRecord = srMapMilestone.containskey(ms.Service_Request__c) && srMapMilestone.get(ms.Service_Request__c) != null ?srMapMilestone.get(ms.Service_Request__c) : new ServiceRequest__c(); 
                string errormessage ='';
                if(srRecord != null && srRecord.Id != null){
                    
                    if(ms.Milestone__c == srRecord.Milestone__c){
                        if(ms.Confirmed_Milestone_Date__c == null){
                            errormessage += (errormessage != '') ? ' \n Please enter Confirmed Milestone Date for '+ms.Milestone__r.Name : ' \n Please enter Confirmed Milestone Date for '+ms.Milestone__r.Name;
                        }
                        if(ms.Reschedule_Milestone_Date__c != null){
                            errormessage += (errormessage != '') ? ' \n Please remove Reschedule Milestone Date Date for '+ms.Milestone__r.Name : ' \n Please remove Reschedule Milestone Date Date for '+ms.Milestone__r.Name;
                        }
                    }else{
                        if(ms.Confirmed_Milestone_Date__c != null){
                            errormessage += (errormessage != '') ? ' \n Please remove Confirmed Milestone Date for '+ms.Milestone__r.Name : ' \n Please remove Confirmed Milestone Date for '+ms.Milestone__r.Name;
                        }
                    }
                    System.debug('-----inside--------errormessage------>'+errormessage);
                    
                    if(errormessage != ''){
                        if(milestoneSRMap.get(ms.Service_Request__c) == null)
                            milestoneSRMap.put(ms.Service_Request__c,errormessage);
                        else
                        {
                            string existingMilestones = milestoneSRMap.get(ms.Service_Request__c);
                            if(existingMilestones != '') 
                                existingMilestones = existingMilestones +'\n'+errormessage;
                            milestoneSRMap.put(ms.Service_Request__c,existingMilestones);
                        }
                    }
                }
            }
            System.debug('-----inside--------milestoneSRMap------>'+milestoneSRMap);
            
            for (Task task: newTasks) 
            {
                if(milestoneSRMap.containskey(task.WhatId))
                {
                    string errMsg = milestoneSRMap.get(task.WhatId);
                    System.debug('-----inside--------errMsg ------>'+errMsg );
                    
                    task.addError(errMsg);
                }
            }
        }
        
        system.debug('from servicerequestTaskController');
        if(!upgradeUnitSrIds.isEmpty()) {
            for(ServiceRequest__c thisSr : getServiceRequestSubtypeMap(upgradeUnitSrIds.keySet()).values()) {
                system.debug('from servicerequestTaskController'+ thisSr);
                if(thisSr.Selected_Unit__c == null) {
                    Task thisTask = upgradeUnitSrIds.get(thisSr.Id);
                    thisTask.addError('Please Select Unit before Upgrade/Swap Request');
                }
            }
            
        }
        
        
        if(unitConsolidationSrIds.size() > 0) {
            for(ServiceRequest__c thisSr : getServiceRequestSubtypeMap(unitConsolidationSrIds.keySet()).values()) {
                system.debug('from servicerequestTaskController'+ thisSr);
                if(thisSr.Equity_Transfer_Amount__c == null && unitConsolidationSrIds.get(thisSr.Id).Subject == 'Acknowledgement of Equity Transfer and Forfeiture Amount') {
                    Task thisTask = unitConsolidationSrIds.get(thisSr.Id);
                    thisTask.addError('Please Enter Equity Transfer Amount before Closing the Task');
                }else if(getTotalFundTransferAmount(thisSr.Id) > thisSr.Equity_Transfer_Amount__c && unitConsolidationSrIds.get(thisSr.Id).Subject == 'Updating Approved Equity Transfer Amount') {
                    Task thisTask = unitConsolidationSrIds.get(thisSr.Id);
                    thisTask.addError('Fund Transfer Amount should be equal to Equity Transfer Amount. Please Update Unit Transfer Amount Correctly');
                }else if(unitConsolidationSrIds.get(thisSr.Id).Subject == 'Unit Consolidation Service Request Initiated') {
                    Task thisTask = unitConsolidationSrIds.get(thisSr.Id);
                    Boolean hasConsolidated = false;
                    Boolean hasFundTransfer = false;
                    
                    for (Unit_Consolidation__c uc : [
                        SELECT Id, IsConsolidated__c, Fund_Transfer__c
                        FROM Unit_Consolidation__c
                        WHERE Service_Request__c = :thisSr.Id
                    ]) {
                        if (uc.IsConsolidated__c) hasConsolidated = true;
                        if (uc.Fund_Transfer__c) hasFundTransfer = true;
                    }
                    if (!hasConsolidated || !hasFundTransfer) {
                        thisTask.addError('At least one Transfer Unit and one Fund Transfer must be recorded before proceeding.');
                    } 
                }
            }
            
        }
        if(financesrIds.size() > 0) {
            for(ServiceRequest__c thisSr : getServiceRequestSubtypeMap(financesrIds.keySet()).values()) {
                system.debug('from servicerequestTaskController'+ thisSr);
                if(thisSr.Cheque_Handover_Status__c == null || thisSr.Cheque_Handover_User__c == null || thisSr.Cheque_Handover_Status__c == 'Pending Finance') {
                    Task thisTask = financesrIds.get(thisSr.Id);
                    thisTask.addError('Please update Cheque Handover User & Cheque Handover Status before Closing the Task');
                }
            }
        }
        if(clearancesrIds.size() > 0) {
            for(ServiceRequest__c thisSr : getServiceRequestSubtypeMap(clearancesrIds.keySet()).values()) {
                system.debug('from servicerequestTaskController'+ thisSr);
                if(thisSr.Cheque_Clearance_Status__c == null || thisSr.Cheque_Clearance_User__c == null || thisSr.Cheque_Clearance_Status__c == 'Pending Finance') {
                    Task thisTask = clearancesrIds.get(thisSr.Id);
                    thisTask.addError('Please update Cheque Clearance User & Cheque Clearance Status before Closing the Task');
                }            
            }
        }
    }
    /*
    * @description Identifies Service Request IDs from tasks that have been completed (status changed).
    *              Handles both insert scenarios (via LWC controller) and update scenarios by comparing
    *              old vs new task statuses. Only processes tasks related to ServiceRequest__c objects.
    * @param newTasks  List of new/updated Task records
    * @param oldTasks  Map of old Task records for comparison; null or empty on insert
    * @param isctrler  Boolean flag indicating if triggered from an LWC controller (allows insert-based completion)
    * @return          Set of Service Request Ids whose associated tasks have been completed
    */
    @TestVisible
    private static Set<Id> getCompletedTaskServiceRequestIds(List<Task> newTasks,Map<Id, Sobject> oldTasks,Boolean isctrler) 
    {
        Set<Id> completedTaskServiceRequestIds = new Set<Id>();
        for (Task tsk: newTasks) 
        {
            if (tsk.WhatId != null) 
            {
                if (tsk.WhatId.getSObjectType().getDescribe().getName() == 'ServiceRequest__c') 
                {
                    Task oldRecord;
                    if ((oldTasks == null || oldTasks.isEmpty()) && tsk.Status == Constants.TASK_STATUS_CLOSED && isctrler) {
                        completedTaskServiceRequestIds.add(tsk.WhatId);
                    }
                    
                    else{
                        if (oldTasks.size() > 0 && !oldTasks.isEmpty()) 
                        {
                            oldRecord = (Task)oldTasks.get(tsk.Id);
                            if (oldRecord != null && oldRecord.Status<> tsk.Status) 
                            {
                                completedTaskServiceRequestIds.add(tsk.WhatId);
                            }
                        } 
                    }
                }
            }
        }
        return completedTaskServiceRequestIds;
    }
    /**
    * @description Evaluates updated tasks related to Service Requests and categorizes them into
    *              a map for next-step processing. Handles three scenarios:
    *              - Closed tasks (non-KYC Rejected): added to task order map for next step creation
    *              - Closed + KYC Rejected sub-tasks: cancels the parent Service Request with reason 'KYC Rejected'
    *              - Closed tasks containing 'Finalize': closes the parent Service Request
    *              Also updates Service Request records as needed.
    * @param newTasks  List of updated Task records
    * @return          Map of Task Id to Task for tasks eligible for next-step creation
    */
    @TestVisible
    private static Map<Id, Task> getTaskOrders(List<Task> newTasks) 
    {system.debug('debug: in ServiceRequestTaskController.getTaskOrders method');
     Map<Id, Task> taskOrdermap = new Map<Id, Task>();
     List<ServiceRequest__c> updatesr = new List<ServiceRequest__c>();
     for (Task tsk: newTasks) 
     {
         if (tsk.WhatId != null) 
         {
             if (tsk.WhatId.getSObjectType().getDescribe().getName() == 'ServiceRequest__c') 
             {
                 system.debug('debug: tsk.Status ' + tsk.Status);
                 system.debug('debug: tsk.KYC_Status__c ' + tsk.KYC_Status__c);
                 system.debug('debug: tsk.Subject ' + tsk.Subject);
                 system.debug('debug: tsk.Is_Sub_Task__c ' + tsk.Is_Sub_Task__c);
                 
                 if ((tsk.Status == 'Closed' && tsk.Subject != 'KYC Rejected') ||
                     tsk.Status == 'Return for more information - documents' && !tsk.Subject.contains('Finalize')) 
                 {
                     system.debug('debug: in Closed or Return for more information - documents ');
                     taskOrdermap.put(tsk.Id, tsk);
                 } 
                 else if (tsk.Status == 'Closed' && tsk.KYC_Status__c == 'Rejected' &&
                          tsk.Is_Sub_Task__c && !tsk.Subject.contains('Finalize')) 
                 {
                     system.debug('debug: in Closed and Rejected ');
                     ServiceRequest__c sr = new ServiceRequest__c
                         (
                             id = tsk.WhatId, 
                             Status__c = 'Cancelled',
                             Cancellation_Reason__c = 'KYC Rejected'
                         );
                     updatesr.add(sr);
                     
                     /*  ServiceRequest__c srUpdated = [Select Id,RecordTypeName__c from ServiceRequest__c where Id =: sr.Id]; Commenting for prod Depolyment
                        if(srUpdated.RecordTypeName__c == Constants.SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER)
                        {
                        SendGridServiceRequestCustomerEmail.sendEmailToCustomer(sr.Id,ServiceConstants.CEMAIL_SR_SR_REJECTED);
                        }
                        else if(srUpdated.RecordTypeName__c == Constants.SERVICE_REQUEST_RT_DEV_NAME_JO_ADDITION)
                        {
                        SendGridServiceRequestCustomerEmail.sendEmailToCustomer(sr.Id,ServiceConstants.CEMAIL_SR_JO_REJECTED);
                        }*/
                 } else if (tsk.Status == 'Closed' && tsk.Subject.contains('Finalize')) 
                 {
                     system.debug('debug: in Closed and Finalize ');
                     ServiceRequest__c sr = new ServiceRequest__c(id = tsk.WhatId, Status__c = 'Closed');
                     updatesr.add(sr);
                 }
             }
             
         }
     }
     if (updatesr.size() > 0) {
         update updatesr;
     }
     System.debug('taskOrdermap--->'+taskOrdermap);
     return taskOrdermap;
    }
    /*
    * @description Evaluates updated Broker Registration (BR) tasks and categorizes them based on
    *              their Broker_Registration_Status__c field. Tasks with actionable statuses
    *              (Approved, RMI, Completed, Signed) are added to the task order map for next-step
    *              processing. Tasks with 'Rejected' status trigger the parent Service Request
    *              to be marked as 'Rejected'.
    * @param newTasks  List of updated Task records
    * @return          Map of Task Id to Task for tasks eligible for BR next-step creation
    */
    @TestVisible
    private static Map<Id, Task> getBRTaskOrders(List<Task> newTasks) {
        Map<Id, Task> taskOrdermap = new Map<Id, Task>();
        List<ServiceRequest__c> updatesr = new List<ServiceRequest__c>();
        system.debug('newTasks::'+newTasks);
        List<String> actionStatusList = new List<String> {BRConstants.ACTION_STATUS_APPROVED, BRConstants.ACTION_STATUS_RMI, BRConstants.ACTION_STATUS_COMPLETED, BRConstants.ACTION_STATUS_SIGNED};
            for (Task tsk: newTasks)  {
                if (tsk.WhatId != null) {
                    if (tsk.WhatId.getSObjectType().getDescribe().getName() == 'ServiceRequest__c') {
                        System.debug('tsk.Broker_Registration_Status__c:::'+tsk.Broker_Registration_Status__c);
                        System.debug('actionStatusList:::'+actionStatusList);
                        system.debug('contains status::'+actionStatusList.contains(tsk.Broker_Registration_Status__c));
                        
                        if (actionStatusList.contains(tsk.Broker_Registration_Status__c)) {
                            taskOrdermap.put(tsk.Id, tsk);
                        } 
                        else if (tsk.Broker_Registration_Status__c == BRConstants.ACTION_STATUS_REJECTED) {
                            system.debug('debug: in Closed and Finalize ');
                            ServiceRequest__c sr = new ServiceRequest__c(id = tsk.WhatId, Status__c = 'Rejected');
                            updatesr.add(sr);
                        }
                    }
                    
                }
            }
        if (updatesr.size() > 0) {
            update updatesr;
        }
        System.debug('taskOrdermap--->'+taskOrdermap);
        return taskOrdermap;
    }
    /*
    * @description Retrieves a map of Service Request Ids to their Record Type names
    *              for the provided set of Service Request Ids. Used to determine which
    *              workflow actions and task templates apply to each Service Request.
    * @param completedTaskServiceRequestIds  Set of Service Request Ids to query
    * @return  Map of Service Request Id to Record Type Name
    */
    @TestVisible
    private static Map<Id, String> getServiceRequestRtMap(Set<Id> completedTaskServiceRequestIds) 
    {
        Map<Id, String> taskSubjectMap = new Map<Id, String>();
        //1.5 Add Field
        List<ServiceRequest__c> serviceRequestlst = [SELECT Id, RecordType.Name, Type__c,Cancellation_Type__c,Extended_NOC_Approval_Status__c FROM ServiceRequest__c WHERE Id IN : completedTaskServiceRequestIds];
        system.debug('debug: serviceRequestlst ' + serviceRequestlst);
        for (ServiceRequest__c sr: serviceRequestlst) 
        {
            taskSubjectMap.put(sr.Id, sr.RecordType.Name);
        }
        return taskSubjectMap;
    }
    /*
    * @description Replaces the former ServiceRequest__c.Total_Fund_Transfer__c roll-up summary field.
    *              That field was removed when Unit_Consolidation__c.Service_Request__c was converted
    *              from Master-Detail to Lookup — a roll-up summary requires an active master-detail
    *              relationship, so it could no longer exist once that conversion happened.
    * @param serviceRequestId  Service Request whose fund-transfer total should be summed
    * @return  Sum of Unit_Consolidation__c.Transfer_Amount__c where Fund_Transfer__c = true
    */
    @TestVisible
    private static Decimal getTotalFundTransferAmount(Id serviceRequestId) {
        Decimal total = 0;
        for (AggregateResult ar : [
            SELECT SUM(Transfer_Amount__c) total
            FROM Unit_Consolidation__c
            WHERE Service_Request__c = :serviceRequestId
            AND Fund_Transfer__c = true
        ]) {
            Object sum = ar.get('total');
            if (sum != null) {
                total = (Decimal) sum;
            }
        }
        return total;
    }
    /*
    * @description Retrieves a map of Service Request Ids to their full ServiceRequest__c records,
    *              including key fields needed for task workflow decisions such as subtype, finance
    *              status, selected unit, equity transfer amounts, and sales order details.
    * @param completedTaskServiceRequestIds  Set of Service Request Ids to query
    * @return  Map of Service Request Id to ServiceRequest__c record
    */
    @TestVisible
    private static Map<Id, ServiceRequest__c> getServiceRequestSubtypeMap(Set<Id> completedTaskServiceRequestIds)
    {
        Map<Id, ServiceRequest__c> serviceRequestsubtypeMap = new Map<Id, ServiceRequest__c>();
        //1.5 Add Field
        List<ServiceRequest__c> serviceRequestlst = [SELECT Id,Cheque_Clearance_Status__c,Cancellation_Type__c,Cheque_Clearance_User__c,Cheque_Handover_Status__c,Cheque_Handover_User__c,Legal_Decision__c,Decision_Type__c,OwnerId, Sales_Agent__c,SalesOrder__r.Total_Outstanding__c,Selected_Unit__c, Name,RecordType.Name,Extended_NOC_Approval_Status__c,Type__c,Is_NOC_Extended__c,Equity_Transfer_Amount__c FROM ServiceRequest__c WHERE Id IN : completedTaskServiceRequestIds];
        for(ServiceRequest__c sr: serviceRequestlst)
        {
            serviceRequestsubtypeMap.put(sr.id,sr);
        }
        return serviceRequestsubtypeMap;
    }
    /*
    * @description Core workflow engine that determines and creates the next step Task for each
    *              completed Service Request task. Handles routing logic for multiple SR record types
    *              including Property Transfer, Joint Owner Title Deed, ADM, Unit Upgrade/Swap,
    *              Default SR, Payment Extension, and more. Key behaviors include:
    *              - Calculates the next task order based on SR type, KYC status, NOC approval status,
    *                decision type, and payment clearance
    *              - Matches the next order to a ServiceAction__c record to determine task details
    *              - Assigns task ownership via AssignmentRule__c queues or SR/sales agent owners
    *              - Closes or cancels the parent SR when a final task is completed
    *              - Sends registration notifications upon ADM SR completion
    *              - Updates Finance Approval Status for Property Transfer and Payment Extension SRs
    * @param completedTaskServiceRequestIds  Set of completed Service Request Ids
    * @param taskSubjectMap                  Map of SR Id to SR Record Type Name
    * @param taskOrderMap                    Map of completed Task Id to Task record
    * @param serviceRequestsrMap             Map of SR Id to ServiceRequest__c record with subtype details
    */
    @TestVisible 
    public static void createNextStepTasks(Set<Id> completedTaskServiceRequestIds,Map<Id, String> taskSubjectMap, Map<Id, Task> taskOrderMap,Map<Id, ServiceRequest__c> serviceRequestsrMap) 
    {system.debug('debug: ServiceRequestTaskController.createNextStepTasks method');
     // Retrieve relevant ServiceAction records ordered by Order__c
     boolean docmentRequired = false;
     Map<Id,string> serviceRequestsubtypeMap= new Map<Id,String>();
     Map<Id,Id> serviceRequestSalesAgent = new Map<ID,ID>();
     Map<Id,Id> serviceRequestOwner = new Map<ID,ID>();
     Map<Id,string> serviceRequestExtendedNoc = new Map<Id,String>();
     List<ServiceRequest__c> listOfSrs = new List<ServiceRequest__c>();
     set<Id> serviceRequestId = new Set<Id>();
     set<string> assignmentRuleID = new Set<string>();
     Map<Decimal, String> tskobjMap = new Map<Decimal, String>();
     Map<String, ServiceAction__c> srActionMap = new Map<String, ServiceAction__c>();
     Map<String, Task> tskActionMap = new Map<String, Task>();
     Map<Id,boolean> checkIsPaymentClear= new Map<Id,Boolean>();
     Map<Id,string> decissionType = new Map<Id,string>();
     for(ServiceRequest__c sr:serviceRequestsrMap.values())
     {
         serviceRequestsubtypeMap.put(sr.id,sr.Type__c);
         serviceRequestSalesAgent.put(sr.id,sr.Sales_Agent__c);
         serviceRequestExtendedNoc.put(sr.id,sr.Extended_NOC_Approval_Status__c);
         serviceRequestOwner.put(sr.Id,sr.OwnerId);
         decissionType.put(sr.id,sr.Decision_Type__c);
         if (sr.SalesOrder__r != null && sr.SalesOrder__r.Total_Outstanding__c != null && sr.SalesOrder__r.Total_Outstanding__c == 0) {
             checkIsPaymentClear.put(sr.Id, true);
         } else {
             checkIsPaymentClear.put(sr.Id, false);
         }
         
         system.debug('debug: sr.Id ' + sr.Id);
         system.debug('checkIsPaymentClear ' + checkIsPaymentClear);
         system.debug('debug: sr.Extended_NOC_Approval_Status__c ' + sr.Extended_NOC_Approval_Status__c);
     }
     
     List<String> srTypes = serviceRequestsubtypeMap.values();
     List<ServiceAction__c> actions = [SELECT Id, IsPaymentClear__c,Name, AssignmentRule__c, FinalTask__c, TaskType__c, NOC_Status__c,No_Of_Due_Days__c,TaskSubject__c, SR_Type__c,
                                       Description__c, Is_Sub_Task__c, KYC_Status__c, Order__c,
                                       ServiceCatalog__r.Service_Request_Type__c 
                                       FROM ServiceAction__c 
                                       WHERE ServiceCatalog__r.Service_Request_Type__c = : taskSubjectMap.values() ORDER BY Order__c ASC];
     for (ServiceAction__c action: actions) 
     {
         assignmentRuleID.add(action.AssignmentRule__c);
     }
     
     Map<Id, AssignmentRule__c> assigneeQueue = getSrAssigneeQueue(assignmentRuleID);
     System.debug('taskSubjectMap.values()' + taskSubjectMap);
     List<Task> tasksToCreate = new List<Task>();
     System.debug('tskobjMap--->' + taskOrderMap);
     // Iterate through completed tasks to determine next steps
     for (Id completedTaskId: taskOrderMap.keySet()) 
     {
         Integer completedTaskOrder = Integer.valueOf(taskOrderMap.get(completedTaskId).Order__c);
         tskActionMap.put(String.valueOf(completedTaskOrder), taskOrderMap.get(completedTaskId));
         System.debug('tskActionMap--->' + tskActionMap);
         Decimal nextOrder = Decimal.valueOf(completedTaskOrder);
         serviceRequestId.add(taskOrderMap.get(completedTaskId).whatId);
         
         
         
         // PROPERTY TRANSFER – OFF PLAN : CM APPROVAL STATUS UPDATE
         // 
         Id currentSrId = taskOrderMap.get(completedTaskId).WhatId;
         
         if (
             serviceRequestsrMap.containsKey(currentSrId) && serviceRequestsrMap.get(currentSrId).RecordType != null &&
             serviceRequestsrMap.get(currentSrId).RecordType.Name == Constants.SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER &&
             taskOrderMap.get(completedTaskId).Status == Constants.TASK_STATUS_CLOSED
         ) {
             
             // Step 10 → Submitted for Approval
             if (completedTaskOrder == 10) {
                 listOfSrs.add(new ServiceRequest__c(Id = currentSrId,Finance_Approval_Status__c = 'Submitted for Approval'));
             }
             
             // Step 11 → Approved by CM Team
             if (completedTaskOrder == 11) {
                 listOfSrs.add(new ServiceRequest__c(Id = currentSrId, Finance_Approval_Status__c = 'Approved by Manager'));
             }
         }
         // Payment Extension.
         if (serviceRequestsrMap.containsKey(currentSrId) && serviceRequestsrMap.get(currentSrId).RecordType != null &&
             serviceRequestsrMap.get(currentSrId).RecordType.Name == Constants.SERVICE_REQUEST_RT_DEV_NAME_PE &&
             taskOrderMap.get(completedTaskId).Status == Constants.TASK_STATUS_CLOSED) {
                 
                 if (completedTaskOrder == 3 || completedTaskOrder == 3.0) {
                     listOfSrs.add(new ServiceRequest__c(
                         Id = currentSrId,
                         Finance_Approval_Status__c = 'Approved by Manager'
                     ));
                 }
             }
         
         
         System.debug('nextOrder--->' + nextOrder);
         System.debug('taskSubjectMap.get(completedTaskId)--->' + taskSubjectMap.get(completedTaskId));
         System.debug('Constants.SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER--->' + Constants.SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER);
         System.debug('taskOrderMap.get(completedTaskId).KYC_Status__c--->' + taskOrderMap.get(completedTaskId).KYC_Status__c);
         System.debug('taskOrderMap.get(completedTaskId).KYC_Status__c--->' + taskOrderMap.get(completedTaskId).KYC_Status__c);
         
         if ((taskSubjectMap.get(taskOrdermap.get(completedTaskId).WhatId) == Constants.SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER_TITLE_DEED &&
              taskOrderMap.get(completedTaskId).subject == Constants.TITLE_DEED_CM_APPROVAL_TASK_SUBJECT && 
              taskOrderMap.get(completedTaskId).Status == Constants.TASK_STATUS_CLOSED) && 
             (taskOrderMap.get(completedTaskId).Extended_NOC_Approval_Status__c == 'Approved' || taskOrderMap.get(completedTaskId).Extended_NOC_Approval_Status__c == 'Approve with new dates')
            ) 
         {
             System.debug('nextOrder--->PTTTTTifffff' + nextOrder+serviceRequestsrMap.get(taskOrdermap.get(completedTaskId).WhatId).Extended_NOC_Approval_Status__c);
             
             nextOrder = nextOrder -7;
             System.debug('nextOrder--->PTTTTT' + nextOrder+serviceRequestsrMap.get(taskOrdermap.get(completedTaskId).WhatId).Extended_NOC_Approval_Status__c);
         } 
         else if ((taskSubjectMap.get(taskOrdermap.get(completedTaskId).WhatId) == Constants.SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER_TITLE_DEED &&
                   taskOrderMap.get(completedTaskId).subject == Constants.TITLE_DEED_CM_APPROVAL_TASK_SUBJECT && 
                   taskOrderMap.get(completedTaskId).Status == Constants.TASK_STATUS_CLOSED) && 
                  taskOrderMap.get(completedTaskId).Extended_NOC_Approval_Status__c == 'Rejected' && taskOrderMap.get(completedTaskId).Extended_NOC_Approval_Status__c <> null)
             //serviceRequestsrMap.get(taskOrdermap.get(completedTaskId).WhatId).Is_NOC_Extended__c == true                               
         {
             System.debug('nextOrder--->PTTTTTifffff' + nextOrder+serviceRequestsrMap.get(taskOrdermap.get(completedTaskId).WhatId).Extended_NOC_Approval_Status__c);
             
             nextOrder = nextOrder;
             System.debug('nextOrder--->Rejected' + nextOrder);
             System.debug('debug: expected orderApprove with new dates' + nextOrder);
         }
         else if ((taskSubjectMap.get(taskOrdermap.get(completedTaskId).WhatId) == Constants.SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER_TITLE_DEED_COMMERCIAL &&
                   taskOrderMap.get(completedTaskId).Status == Constants.TASK_STATUS_CLOSED)) 
         {
             System.debug('nextOrder--->PTTTTTTT' + nextOrder);
             nextOrder = nextOrder + 1;
         }
         else if ((taskSubjectMap.get(taskOrdermap.get(completedTaskId).WhatId) == Constants.SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER_TITLE_DEED &&
                   taskOrderMap.get(completedTaskId).Status == Constants.TASK_STATUS_CLOSED)) 
         {
             System.debug('nextOrder--->PTTTTTTT' + nextOrder);
             nextOrder = nextOrder + 1;
         }
         else if ((taskSubjectMap.get(taskOrdermap.get(completedTaskId).WhatId) == Constants.SERVICE_REQUEST_RT_DEV_NAME_UNIT_UPGRADE &&
                   taskOrderMap.get(completedTaskId).Status == Constants.TASK_STATUS_CLOSED)) 
         {
             System.debug('nextOrder--->UnitUpgrade' + nextOrder);
             nextOrder = nextOrder + 1;
         }
         else if ((taskSubjectMap.get(taskOrdermap.get(completedTaskId).WhatId) == Constants.SERVICE_REQUEST_RT_DEV_NAME_UNIT_SWAP &&
                   taskOrderMap.get(completedTaskId).Status == Constants.TASK_STATUS_CLOSED)) 
         {
             System.debug('nextOrder--->UnitSwap' + nextOrder);
             nextOrder = nextOrder + 1;
         }
         
         if ( //1.5 start
             taskSubjectMap.get(taskOrderMap.get(completedTaskId).WhatId) == Constants.SERVICE_REQUEST_Default_SR &&
             taskOrderMap.get(completedTaskId).Status == Constants.TASK_STATUS_CLOSED
         ) {
             String decision = decissionType.get(taskOrderMap.get(completedTaskId).WhatId);
             Task completedTask = taskOrderMap.get(completedTaskId);
             if ((decision == 'Unit Cancellation' || completedTask.is_Decision_Type__c ==True)
                 && completedTask.Subject == Constants.LEGAL_DECISION) {
                     nextOrder = 5;
                 }
             // Case 2: Payment Clear
             else if (checkIsPaymentClear.get(completedTask.WhatId) == true) {
                 if ( (decision == 'Legal' || completedTask.Subject == Constants.LEGAL_DECISION) 
                     && completedTask.Subject != Constants.LEGAL_TEM_SR_CLOSURE ) {
                         nextOrder = 5;
                     } 
                 else if (String.isBlank(decision) 
                          && completedTask.Subject != Constants.COLLECTION_TEAM_SR_CLOSURE) {
                              System.debug('CollectionTeam------>' + completedTask.Subject);
                              nextOrder = 2;
                          } 
                 else {
                     nextOrder = 8;
                 }
             }
             // Case 3: Only if not Unit Cancellation & not Payment Clear → check Default SR closure
             else {
                 if (
                     taskSubjectMap.get(completedTask.WhatId) == Constants.SERVICE_REQUEST_Default_SR &&
                     completedTask.Status == Constants.TASK_STATUS_CLOSED &&
                     (String.isBlank(decision) || decision != 'Unit Cancellation' || completedTask.is_Decision_Type__c ==false)
                 ) {
                     System.debug('decision---->'+decision+completedTask.is_Decision_Type__c);
                     System.debug('nextOrder--->DefaultSR' + nextOrder);
                     nextOrder = nextOrder + 1;
                 }
                 
             } //1.5 end         
         }
         
         // else if ((taskSubjectMap.get(taskOrdermap.get(completedTaskId).WhatId) == Constants.SERVICE_REQUEST_RT_PAYMENT_PLAN_SWAP &&
         //  taskOrderMap.get(completedTaskId).Status == Constants.TASK_STATUS_CLOSED)) 
         // {
         //  System.debug('nextOrder--->PTTTTTTT' + nextOrder);
         //  nextOrder = nextOrder + 1;
         // }
         
         System.debug('taskSubjectMap.get(taskOrdermap.get(completedTaskId).WhatId--->' + taskSubjectMap.get(taskOrdermap.get(completedTaskId).WhatId));
         System.debug('taskOrderMap.get(completedTaskId).subject--->' + taskOrderMap.get(completedTaskId).subject);
         System.debug('taskOrderMap.get(completedTaskId).Status--->' + taskOrderMap.get(completedTaskId).Status);
         System.debug('serviceRequestsrMap.get(taskOrdermap.get(completedTaskId).WhatId).Extended_NOC_Approval_Status__c--->' + serviceRequestsrMap.get(taskOrdermap.get(completedTaskId).WhatId).Extended_NOC_Approval_Status__c);
         System.debug('serviceRequestsrMap.get(taskOrdermap.get(completedTaskId).WhatId).Is_NOC_Extended__c--->' + serviceRequestsrMap.get(taskOrdermap.get(completedTaskId).WhatId).Is_NOC_Extended__c);
         if ((taskSubjectMap.get(taskOrdermap.get(completedTaskId).WhatId) == Constants.SERVICE_REQUEST_RT_DEV_NAME_JOINT_OWNER_TITLE_DEED &&
              taskOrderMap.get(completedTaskId).subject== Constants.TITLE_DEED_CM_APPROVAL_TASK_SUBJECT && 
              taskOrderMap.get(completedTaskId).Status == Constants.TASK_STATUS_CLOSED) && 
             (taskOrderMap.get(completedTaskId).Extended_NOC_Approval_Status__c == 'Approved' || taskOrderMap.get(completedTaskId).Extended_NOC_Approval_Status__c == 'Approve with new dates')
             //serviceRequestsrMap.get(taskOrdermap.get(completedTaskId).WhatId).Is_NOC_Extended__c == true               
            ) 
         {
             nextOrder = nextOrder -7;
             System.debug('nextOrder--->PTTTTT' + nextOrder);
             System.debug('debug: expected order' + nextOrder);
         } 
         else if ((taskSubjectMap.get(taskOrdermap.get(completedTaskId).WhatId) == Constants.SERVICE_REQUEST_RT_DEV_NAME_JOINT_OWNER_TITLE_DEED &&
                   taskOrderMap.get(completedTaskId).subject == Constants.TITLE_DEED_CM_APPROVAL_TASK_SUBJECT && 
                   taskOrderMap.get(completedTaskId).Status == Constants.TASK_STATUS_CLOSED) && 
                  taskOrderMap.get(completedTaskId).Extended_NOC_Approval_Status__c == 'Rejected' && taskOrderMap.get(completedTaskId).Extended_NOC_Approval_Status__c <> null)
             //serviceRequestsrMap.get(taskOrdermap.get(completedTaskId).WhatId).Is_NOC_Extended__c == true                               
         {
             System.debug('nextOrder--->PTTTTTifffff' + nextOrder+serviceRequestsrMap.get(taskOrdermap.get(completedTaskId).WhatId).Extended_NOC_Approval_Status__c);
             
             nextOrder = nextOrder;
             System.debug('nextOrder--->Rejected' + nextOrder);
             System.debug('debug: expected orderApprove with new dates' + nextOrder);
         }
         else if ((taskSubjectMap.get(taskOrdermap.get(completedTaskId).WhatId) == Constants.SERVICE_REQUEST_RT_DEV_NAME_JOINT_OWNER_TITLE_DEED &&
                   taskOrderMap.get(completedTaskId).Status == Constants.TASK_STATUS_CLOSED)) 
         {
             nextOrder = nextOrder + 1;
         }
         // else if ((taskSubjectMap.get(taskOrdermap.get(completedTaskId).WhatId) ==  &&
         //      taskOrderMap.get(completedTaskId).Status == Constants.TASK_STATUS_CLOSED)) 
         // {
         //  nextOrder = nextOrder + 1;
         // }
         
         if ((taskSubjectMap.get(taskOrdermap.get(completedTaskId).WhatId) == Constants.SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER ||
              taskSubjectMap.get(taskOrdermap.get(completedTaskId).WhatId) == Constants.SERVICE_REQUEST_RT_DEV_NAME_JO_ADDITION ||
              taskSubjectMap.get(taskOrdermap.get(completedTaskId).WhatId) == Constants.SERVICE_REQUEST_RT_DEV_NAME_PE ||
              taskSubjectMap.get(taskOrdermap.get(completedTaskId).WhatId) == Constants.SERVICE_REQUEST_LPC ||
              taskSubjectMap.get(taskOrdermap.get(completedTaskId).WhatId) == Constants.SERVICE_REQUEST_UC ||
              taskSubjectMap.get(taskOrdermap.get(completedTaskId).WhatId) == Constants.SERVICE_REQUEST_RT_PAYMENT_PLAN_SWAP ||
              taskSubjectMap.get(taskOrdermap.get(completedTaskId).WhatId) == Constants.SERVICE_REQUEST_MILESTONE ||
              taskSubjectMap.get(taskOrdermap.get(completedTaskId).WhatId) == Constants.SERVICE_REQUEST_PLOT_HANDOVER ||
              taskSubjectMap.get(taskOrdermap.get(completedTaskId).WhatId) == Constants.SERVICE_REQUEST_CANCELLATION_DEFAULT ||
              taskSubjectMap.get(taskOrdermap.get(completedTaskId).WhatId) == Constants.SERVICE_REQUEST_RT_PRE_UNIT_CANCELLATION || //1.5
              taskSubjectMap.get(taskOrdermap.get(completedTaskId).WhatId) == Constants.SERVICE_REQUEST_RT_POST_UNIT_CANCELLATION//1.5
             ) &&
             (taskOrderMap.get(completedTaskId).KYC_Status__c != 'Rejected' ||
              ((taskOrderMap.get(completedTaskId).KYC_Status__c == 'Resubmit KYC' ||
                taskOrderMap.get(completedTaskId).KYC_Status__c == 'Approved') &&
               taskOrderMap.get(completedTaskId).Status == Constants.TASK_STATUS_CLOSED))) 
         {
             nextOrder = nextOrder + 1;
             Id srId = taskOrderMap.get(completedTaskId).WhatId; //1.5 start
             
             ServiceRequest__c sr = serviceRequestsrMap.get(srId);
             
             Decimal prevOrder;
             
             do {
                 prevOrder = nextOrder;
                 
                 nextOrder = handlePreunitCancellationStepSkip(
                     nextOrder,
                     completedTaskOrder,
                     sr
                 );
                 
             } while (prevOrder != nextOrder); //1.5 end
         }
         System.debug('nextOrder--->' + nextOrder);
         
         if (taskOrderMap.get(completedTaskId).Status == 'Return for more information - documents' &&
             taskSubjectMap.get(taskOrdermap.get(completedTaskId).WhatId) == Constants.SERVICE_REQUEST_RT_DEV_NAME_ADM) 
         {
             docmentRequired = true;
             Decimal orderNum = nextOrder - 1;
             nextOrder = nextOrder - 1;
             decimal ornum = orderNum.round(System.RoundingMode.DOWN);
             tskobjMap.put(ornum, taskOrderMap.get(completedTaskId).WhatId);
             boolean SubTask = true;
             // getPreviousTasks(tskobjMap,SubTask);
             System.debug('tskobjMap--->' + tskobjMap);
         } 
         else if (taskOrderMap.get(completedTaskId).Status <> 'Return for more information - documents' &&
                  taskSubjectMap.get(taskOrdermap.get(completedTaskId).WhatId) == Constants.SERVICE_REQUEST_RT_DEV_NAME_ADM &&
                  taskOrderMap.get(completedTaskId).Status == Constants.TASK_STATUS_CLOSED) 
         {
             nextOrder = nextOrder + 1;
             if (taskOrderMap.get(completedTaskId).Is_Sub_Task__c) 
             {
                 Decimal orderNum = nextOrder;
                 decimal ornum = orderNum.round(System.RoundingMode.DOWN);
                 tskobjMap.put(ornum, taskOrderMap.get(completedTaskId).WhatId);
                 boolean SubTask = false;
                 getPreviousTasks(tskobjMap, SubTask);
             }
         }
         
         System.debug('nextOrder--->' + nextOrder);
         // Determine next step Order__c
         
         // Find the relevant action for the next step
         for (ServiceAction__c action: actions) 
         {
             // Match next Order__c and apply additional conditions
             if (action.ServiceCatalog__r.Service_Request_Type__c == Constants.SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER ||
                 action.ServiceCatalog__r.Service_Request_Type__c == Constants.SERVICE_REQUEST_RT_DEV_NAME_JO_ADDITION ||
                 action.ServiceCatalog__r.Service_Request_Type__c == Constants.SERVICE_REQUEST_RT_DEV_NAME_PE ||
                 action.ServiceCatalog__r.Service_Request_Type__c == Constants.SERVICE_REQUEST_LPC ||
                 action.ServiceCatalog__r.Service_Request_Type__c == Constants.SERVICE_REQUEST_UC ||
                 action.ServiceCatalog__r.Service_Request_Type__c == Constants.SERVICE_REQUEST_RT_PAYMENT_PLAN_SWAP ||
                 action.ServiceCatalog__r.Service_Request_Type__c == Constants.SERVICE_REQUEST_MILESTONE ||
                 action.ServiceCatalog__r.Service_Request_Type__c == Constants.SERVICE_REQUEST_PLOT_HANDOVER ||
                 action.ServiceCatalog__r.Service_Request_Type__c == Constants.SERVICE_REQUEST_CANCELLATION_DEFAULT || 
                 action.ServiceCatalog__r.Service_Request_Type__c == Constants.SERVICE_REQUEST_RT_PRE_UNIT_CANCELLATION || //1.5
                 action.ServiceCatalog__r.Service_Request_Type__c == Constants.SERVICE_REQUEST_RT_POST_UNIT_CANCELLATION //1.5
                 
                ) 
             {
                 if (!taskOrderMap.get(completedTaskId).Subject.contains('KYC') ||
                     (taskOrderMap.get(completedTaskId).Subject.contains('KYC') &&
                      taskOrderMap.get(completedTaskId).KYC_Status__c != 'Resubmit KYC' &&
                      taskOrderMap.get(completedTaskId).KYC_Status__c == 'Approved' &&
                      taskOrderMap.get(completedTaskId).Status == Constants.TASK_STATUS_CLOSED)) 
                 {
                     if (action.Order__c == nextOrder) 
                     {
                         system.debug('NExtttt---->');
                         Task t = new Task();
                         t.WhatId = taskOrderMap.get(completedTaskId).WhatId;
                         t.RecordTypeId = TaskRecordTypeId;
                         t.Subject = action.TaskSubject__c;
                         
                         if (assigneeQueue.containsKey(action.AssignmentRule__c)) 
                         {
                             t.OwnerId = assigneeQueue.get(action.AssignmentRule__c).DefaultQueueID__c;
                         }
                         t.Description = action.Description__c;
                         t.Order__c = action.Order__c;
                         t.Priority = 'High';
                         t.Status = 'Not Started';
                         t.ServiceAction__c = action.Id;
                         tasksToCreate.add(t);
                         break;  // Only create one task per completed task
                     }
                 } else if (taskOrderMap.get(completedTaskId).Subject.contains('KYC') &&
                            !taskOrderMap.get(completedTaskId).Is_Sub_Task__c &&
                            (taskOrderMap.get(completedTaskId).KYC_Status__c == 'Resubmit KYC' ||
                             taskOrderMap.get(completedTaskId).KYC_Status__c == 'Rejected')) 
                 {
                     if (action.KYC_Status__c == taskOrderMap.get(completedTaskId).KYC_Status__c) 
                     {
                         Task t = new Task(RecordTypeId = TaskRecordTypeId, Subject = action.TaskSubject__c,
                                           Description = action.Description__c, Order__c = action.Order__c,
                                           Priority = 'High', Status = 'Not Started');
                         t.WhatId = taskOrderMap.get(completedTaskId).WhatId;
                         if (assigneeQueue.containsKey(action.AssignmentRule__c)) 
                         {
                             t.OwnerId = assigneeQueue.get(action.AssignmentRule__c).DefaultQueueID__c;
                         }
                         t.ServiceAction__c = action.Id;
                         tasksToCreate.add(t);
                         break;  // Only create one task per completed task
                     }
                 } 
                 else 
                 {
                     break;  // Only create one task per completed task
                 }
             }
             
             System.debug('action.ServiceCatalog__r.Service_Request_Type__c ' + action.ServiceCatalog__r.Service_Request_Type__c);
             if (action.ServiceCatalog__r.Service_Request_Type__c == Constants.SERVICE_REQUEST_RT_DEV_NAME_ADM) 
             {
                 if (serviceRequestsubtypeMap.containskey(taskOrderMap.get(completedTaskId).WhatId)) 
                 {
                     system.debug('taskOrderMap.get(completedTaskId).Is_Sub_Task__c' + taskOrderMap.get(completedTaskId).Is_Sub_Task__c);
                     if (!taskOrderMap.get(completedTaskId).Is_Sub_Task__c &&
                         taskOrderMap.get(completedTaskId).Status <>
                         'Return for more information - documents') 
                     {
                         srTypes = serviceRequestsubtypeMap.values();
                         if (!srTypes.contains('Next of Kin') && (action.Order__c == nextOrder)) 
                         {
                             Task t = new Task();
                             t.WhatId = taskOrderMap.get(completedTaskId).WhatId;
                             t.RecordTypeId = TaskRecordTypeId;
                             t.Subject = action.TaskSubject__c;
                             if (assigneeQueue.containsKey(action.AssignmentRule__c)) 
                             {
                                 t.OwnerId = assigneeQueue.get(action.AssignmentRule__c).DefaultQueueID__c;
                             }else{
                                 t.OwnerId = serviceRequestOwner.get(taskOrderMap.get(completedTaskId).WhatId);
                             }
                             t.Description = action.Description__c;
                             t.Order__c = action.Order__c;
                             t.Priority = 'High';
                             t.Status = 'Not Started';
                             t.ServiceAction__c = action.Id;
                             tasksToCreate.add(t);
                             
                             break;
                         }
                     } 
                     else if (taskOrderMap.get(completedTaskId).Status == 'Return for more information - documents') 
                     {
                         srTypes = serviceRequestsubtypeMap.values();
                         System.debug('nextOrder' + nextOrder + 'action.Order__c' + action.Order__c);
                         if (!srTypes.contains('Next of Kin') && (action.Order__c == nextOrder) && action.SR_Type__c == srTypes[0]) 
                         {
                             Task t = new Task();
                             t.WhatId = taskOrderMap.get(completedTaskId).WhatId;
                             t.RecordTypeId = TaskRecordTypeId;
                             t.Subject = action.TaskSubject__c;
                             if (assigneeQueue.containsKey(action.AssignmentRule__c)) 
                             {
                                 t.OwnerId = assigneeQueue.get(action.AssignmentRule__c).DefaultQueueID__c;
                             }else{
                                 
                                 t.OwnerId = serviceRequestOwner.get(taskOrderMap.get(completedTaskId).WhatId);
                                 
                             }
                             t.Description = action.Description__c;
                             t.Order__c = action.Order__c;
                             t.Is_Sub_Task__c = true;
                             t.Priority = 'High';
                             t.Status = 'Not Started';
                             t.ServiceAction__c = action.Id;
                             tasksToCreate.add(t);
                             break;
                         }
                     }
                 }
             }
             
             if (action.ServiceCatalog__r.Service_Request_Type__c == Constants.SERVICE_REQUEST_RT_DEV_NAME_UNIT_UPGRADE || action.ServiceCatalog__r.Service_Request_Type__c == Constants.SERVICE_REQUEST_RT_DEV_NAME_UNIT_SWAP) 
             {
                 if (serviceRequestsubtypeMap.containskey(taskOrderMap.get(completedTaskId).WhatId)) 
                 {
                     Integer actionIntOrder = Integer.valueOf(action.Order__c);
                     
                     Decimal ActionOrder = Decimal.valueOf(actionIntOrder);
                     if(action.Order__c == nextOrder || ActionOrder == nextOrder)
                     {
                         Task t = new Task();
                         t.WhatId = taskOrderMap.get(completedTaskId).WhatId;
                         t.RecordTypeId = TaskRecordTypeId;
                         t.Subject = action.TaskSubject__c;
                         //System.debug('serviceRequestSalesAgent.get(taskOrderMap.get(completedTaskId).WhatId)'+serviceRequestSalesAgent.get(taskOrderMap.get(completedTaskId).WhatId));
                         if (assigneeQueue.containsKey(action.AssignmentRule__c)) 
                         {
                             t.OwnerId = assigneeQueue.get(action.AssignmentRule__c).DefaultQueueID__c;
                         }if (action.Order__c != 4.0 && action.Order__c != 4) {
                             t.OwnerId = serviceRequestSalesAgent.get(taskOrderMap.get(completedTaskId).WhatId);
                         }
                         
                         t.Description = action.Description__c;
                         t.Order__c = action.Order__c;
                         t.Priority = 'High';
                         t.Status = 'Not Started';
                         t.ServiceAction__c = action.Id;
                         tasksToCreate.add(t);
                         
                         break;
                         
                     }                       
                 }}
             
             if (action.ServiceCatalog__r.Service_Request_Type__c == Constants.SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER_TITLE_DEED_COMMERCIAL) 
             {
                 if (serviceRequestsubtypeMap.containskey(taskOrderMap.get(completedTaskId).WhatId)) 
                 {
                     Integer actionIntOrder = Integer.valueOf(action.Order__c);
                     
                     Decimal ActionOrder = Decimal.valueOf(actionIntOrder);
                     if(action.Order__c == nextOrder || ActionOrder == nextOrder)
                     {
                         Task t = new Task();
                         t.WhatId = taskOrderMap.get(completedTaskId).WhatId;
                         t.RecordTypeId = TaskRecordTypeId;
                         t.Subject = action.TaskSubject__c;
                         if (assigneeQueue.containsKey(action.AssignmentRule__c)) 
                         {
                             t.OwnerId = assigneeQueue.get(action.AssignmentRule__c).DefaultQueueID__c;
                         }if (action.Order__c != 4.0 && action.Order__c != 4) {
                             t.OwnerId = serviceRequestOwner.get(taskOrderMap.get(completedTaskId).WhatId);
                         }
                         
                         t.Description = action.Description__c;
                         t.Order__c = action.Order__c;
                         t.Priority = 'High';
                         t.Status = 'Not Started';
                         t.ServiceAction__c = action.Id;
                         tasksToCreate.add(t);
                         
                         break;
                         
                     }                       
                 }}
             //code added for payment plan swap record type for task creation
             // if (action.ServiceCatalog__r.Service_Request_Type__c == ) 
             // {
             //     if (serviceRequestsubtypeMap.containskey(taskOrderMap.get(completedTaskId).WhatId)) 
             //     {
             //          Integer actionIntOrder = Integer.valueOf(action.Order__c);
             
             //         Decimal ActionOrder = Decimal.valueOf(actionIntOrder);
             //         if(action.Order__c == nextOrder || ActionOrder == nextOrder)
             //         {
             //                 Task t = new Task();
             //                 t.WhatId = taskOrderMap.get(completedTaskId).WhatId;
             //                 t.RecordTypeId = TaskRecordTypeId;
             //                 t.Subject = action.TaskSubject__c;
             //                 if (assigneeQueue.containsKey(action.AssignmentRule__c)) 
             //                 {
             //                     t.OwnerId = assigneeQueue.get(action.AssignmentRule__c).DefaultQueueID__c;
             //                 }
             //                 t.Description = action.Description__c;
             //                 t.Order__c = action.Order__c;
             //                 t.Priority = 'High';
             //                 t.Status = 'Not Started';
             //                 t.ServiceAction__c = action.Id;
             //                 tasksToCreate.add(t);
             
             //                 break;
             
             //         }                        
             //     }
             // }
             
             
             if (action.ServiceCatalog__r.Service_Request_Type__c == Constants.SERVICE_REQUEST_RT_DEV_NAME_JOINT_OWNER_TITLE_DEED || 
                 action.ServiceCatalog__r.Service_Request_Type__c == Constants.SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER_TITLE_DEED ) 
             {
                 System.debug('action.Order__c --->534'+action.Order__c+taskOrderMap.get(completedTaskId).NOC_Doc_Status__c+action.NOC_Status__c);
                 if((taskOrderMap.get(completedTaskId).NOC_Doc_Status__c <> '' ||taskOrderMap.get(completedTaskId).NOC_Doc_Status__c <> null ) && (action.NOC_Status__c <> '' || action.NOC_Status__c <> null ) && action.NOC_Status__c == taskOrderMap.get(completedTaskId).NOC_Doc_Status__c)
                 {        
                     Integer actionIntOrder = Integer.valueOf(action.Order__c);
                     
                     Decimal ActionOrder = Decimal.valueOf(actionIntOrder);
                     if(action.Order__c == nextOrder || ActionOrder == nextOrder)
                     {
                         System.debug('action.Order__c --->534'+action.Order__c );
                         System.debug('nextOrder------>770000'+nextOrder);
                         Task t = new Task();
                         t.WhatId = taskOrderMap.get(completedTaskId).WhatId;
                         t.RecordTypeId = TaskRecordTypeId;
                         t.Subject = action.TaskSubject__c;
                         if (assigneeQueue.containsKey(action.AssignmentRule__c)) 
                         {
                             t.OwnerId = assigneeQueue.get(action.AssignmentRule__c).DefaultQueueID__c;
                         }
                         if (action.No_Of_Due_Days__c != null) 
                         {
                             t.ActivityDate = Date.today() + Integer.valueOf(action.No_Of_Due_Days__c);
                         }
                         t.Description = action.Description__c;
                         t.Order__c = action.Order__c;
                         t.NOC_Doc_Status__c= action.NOC_Status__c;
                         t.Priority = 'High';
                         t.Status = 'Not Started';
                         t.ServiceAction__c = action.Id;
                         tasksToCreate.add(t);
                         break;  // Only create one task per completed task
                     }
                 } 
                 else if (((taskOrderMap.get(completedTaskId).NOC_Doc_Status__c == '' ||
                            taskOrderMap.get(completedTaskId).NOC_Doc_Status__c == null) || 
                           (taskOrderMap.get(completedTaskId).NOC_Doc_Status__c <> '' ||
                            taskOrderMap.get(completedTaskId).NOC_Doc_Status__c <> null ) && 
                           (action.NOC_Status__c == '' || action.NOC_Status__c == null)) || taskOrderMap.get(completedTaskId).Extended_NOC_Approval_Status__c == 'Rejected' ) 
                 {
                     System.debug('action.Order__c --->534'+action.Order__c+taskOrderMap.get(completedTaskId).NOC_Doc_Status__c+action.NOC_Status__c);
                     
                     if (
                         taskOrderMap.get(completedTaskId).Status == Constants.TASK_STATUS_CLOSED)
                     {     
                         System.debug('action.Order__c --->556'+action.Order__c );
                         Integer actionIntOrder = Integer.valueOf(action.Order__c);
                         
                         Decimal ActionOrder = Decimal.valueOf(actionIntOrder);
                         System.debug('ActionOrder --->812'+ActionOrder+'nextOrder'+nextOrder);
                         
                         if(action.Order__c == nextOrder || ActionOrder == nextOrder)
                         {
                             System.debug('ActionOrderNEXTTTTT------>'+nextOrder);
                             Task t = new Task();
                             t.WhatId = taskOrderMap.get(completedTaskId).WhatId;
                             t.RecordTypeId = TaskRecordTypeId;
                             t.Subject = action.TaskSubject__c;
                             if (assigneeQueue.containsKey(action.AssignmentRule__c)) 
                             {
                                 t.OwnerId = assigneeQueue.get(action.AssignmentRule__c).DefaultQueueID__c;
                             }
                             if (action.No_Of_Due_Days__c != null) 
                             {
                                 t.ActivityDate = Date.today() + Integer.valueOf(action.No_Of_Due_Days__c);
                             }
                             t.Description = action.Description__c;
                             t.Order__c = action.Order__c;
                             t.Priority = 'High';
                             t.Status = 'Not Started';
                             tasksToCreate.add(t);
                             break;  // Only create one task per completed task
                         }
                     }
                     else 
                     {
                         break;  // Only create one task per completed task
                     }
                 }  
                 
             }
             
             if (action.ServiceCatalog__r.Service_Request_Type__c == Constants.SERVICE_REQUEST_Default_SR) 
             {
                 
                 Integer actionIntOrder = Integer.valueOf(action.Order__c);
                 Id srId = taskOrderMap.get(completedTaskId).WhatId;
                 Boolean isPaymentClear ;
                 if (checkIsPaymentClear.containsKey(srId)) {
                     isPaymentClear = checkIsPaymentClear.get(srId);
                     System.debug('isPaymentClear------>' + isPaymentClear);
                     
                 } else {
                     System.debug('srId not found in checkIsPaymentClear map: ' + srId);
                 }                   
                 System.debug('isPaymentClear------>'+isPaymentClear);
                 Decimal ActionOrder = Decimal.valueOf(actionIntOrder);
                 if ((action.Order__c == nextOrder || ActionOrder == nextOrder)
                     && isPaymentClear != null
                     && isPaymentClear == action.IsPaymentClear__c
                     && isPaymentClear == true)                        {
                         System.debug('action.Order__c --->534'+action.Order__c );
                         System.debug('nextOrder------>770000'+nextOrder);
                         Task t = new Task();
                         t.WhatId = taskOrderMap.get(completedTaskId).WhatId;
                         t.RecordTypeId = TaskRecordTypeId;
                         t.Subject = action.TaskSubject__c;
                         System.debug('serviceRequestOwner------>'+serviceRequestOwner);
                         if (assigneeQueue.containsKey(action.AssignmentRule__c)) 
                         {
                             t.OwnerId = assigneeQueue.get(action.AssignmentRule__c).DefaultQueueID__c;
                         }else{
                             t.OwnerId = serviceRequestOwner.get(taskOrderMap.get(completedTaskId).WhatId);
                         }
                         if (action.No_Of_Due_Days__c != null) 
                         {
                             t.ActivityDate = Date.today() + Integer.valueOf(action.No_Of_Due_Days__c);
                         }
                         t.Description = action.Description__c;
                         t.Order__c = action.Order__c;
                         t.Priority = 'High';
                         t.Status = 'Not Started';
                         t.ServiceAction__c = action.Id;
                         tasksToCreate.add(t);
                         break;  // Only create one task per completed task
                     }
                 
                 else if ((action.Order__c == nextOrder || ActionOrder == nextOrder)
                          && isPaymentClear != null
                          && isPaymentClear == action.IsPaymentClear__c
                          && isPaymentClear == false)
                 {
                     System.debug('action.Order__c --->534'+action.Order__c );
                     System.debug('nextOrder------>770000'+nextOrder);
                     Task t = new Task();
                     t.WhatId = taskOrderMap.get(completedTaskId).WhatId;
                     t.RecordTypeId = TaskRecordTypeId;
                     t.Subject = action.TaskSubject__c;
                     System.debug('serviceRequestOwner------>'+serviceRequestOwner);
                     if (assigneeQueue.containsKey(action.AssignmentRule__c)) 
                     {
                         t.OwnerId = assigneeQueue.get(action.AssignmentRule__c).DefaultQueueID__c;
                     }else{
                         t.OwnerId = serviceRequestOwner.get(taskOrderMap.get(completedTaskId).WhatId);
                     }
                     if(Test.isRunningTest()){
                         t.OwnerId = userinfo.getuserid();
                     }
                     if (action.No_Of_Due_Days__c != null) 
                     {
                         t.ActivityDate = Date.today() + Integer.valueOf(action.No_Of_Due_Days__c);
                     }
                     t.Description = action.Description__c;
                     t.Order__c = action.Order__c;
                     t.Priority = 'High';
                     t.Status = 'Not Started';
                     t.ServiceAction__c = action.Id;
                     tasksToCreate.add(t);
                     break;  // Only create one task per completed task
                 }
                 
                 
                 
             }
             // Integer actionOrder = Integer.valueOf(action.Order__c);
             srActionMap.put(String.ValueOf(action.Order__c), action);
             system.debug('srActionMap' + srActionMap);
         }
     }
     
     System.debug('tasksToCreate---->' + tasksToCreate);
     // Insert new tasks if any
     if (!tasksToCreate.isEmpty()) 
     {
         insert tasksToCreate;
         updateCurrentStepOnSR(tasksToCreate); //v1.4
     } else 
     {
         system.debug('elseee---->782');
         Map<Id, ServiceRequest__c> srRecordMap = getServiceRequestMap(serviceRequestId);
         string accountId;
         String ServiceReqId;
         set<Id> SrId = new set<Id>();
         set<string> recName = new set<string>();
         set<Id> soorder = new set<Id>();
         Map<String, Documents__c> docMap = new Map<String, Documents__c>();
         
         for (Task tsk: tskActionMap.Values()) 
         {
             System.debug('srActionMap------>794'+srActionMap);
             System.debug('srActionMap---->794'+tsk.Order__c);
             Decimal taskOrder = tsk.Order__c; // already a Decimal
             System.debug('taskOrder ----> ' + String.valueOf(taskOrder.setScale(1)));
             String tskOrder = String.valueOf(taskOrder.setScale(1));
             System.debug('taskOrder---->tskkkkkk'+tskOrder);
             System.debug('for------>795'+srActionMap.containsKey(String.valueOf(tskOrder))+'final taskkkk---->');
             if (srActionMap.containsKey(tskOrder) && tsk.WhatId != null &&
                 (srActionMap.get(tskOrder).FinalTask__c ||
                  srTypes.contains('Next of Kin')) &&
                 tsk.Status == Constants.TASK_STATUS_CLOSED) 
             {
                 if ((srRecordMap.get(tsk.WhatId).RecordType.Name == Constants.SERVICE_REQUEST_RT_DEV_NAME_ADM || 
                      srRecordMap.get(tsk.WhatId).RecordType.Name == Constants.SERVICE_REQUEST_RT_DEV_NAME_JOINT_OWNER_TITLE_DEED ||
                      // srRecordMap.get(tsk.WhatId).RecordType.Name == Constants.SERVICE_REQUEST_RT_PAYMENT_PLAN_SWAP ||
                      srRecordMap.get(tsk.WhatId).RecordType.Name == Constants.SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER_TITLE_DEED || 
                      srRecordMap.get(tsk.WhatId).RecordType.Name == Constants.SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER_TITLE_DEED_COMMERCIAL ||
                      srRecordMap.get(tsk.WhatId).RecordType.Name == Constants.SERVICE_REQUEST_RT_DEV_NAME_UNIT_SWAP ||
                      srRecordMap.get(tsk.WhatId).RecordType.Name == Constants.SERVICE_REQUEST_RT_DEV_NAME_UNIT_UPGRADE)&&
                     srActionMap.get(tskOrder).FinalTask__c) 
                 {
                     accountId = srRecordMap.get(tsk.WhatId).AccountId__c;
                     ServiceReqId =tsk.WhatId;
                     SrId.add(tsk.WhatId);
                     recName.add(srRecordMap.get(tsk.WhatId).RecordType.Name);
                     soorder.add(srRecordMap.get(tsk.WhatId).SalesOrder__c);
                 }
                 ServiceRequest__c newSr = new ServiceRequest__c(id = tsk.WhatId, Status__c = 'Closed',CloseDate__c =System.Today());
                 System.debug('listOfSrs----->809'+listOfSrs);
                 listOfSrs.add(newSr);
             }
         }
         if (recName.contains(Constants.SERVICE_REQUEST_RT_DEV_NAME_ADM) ) 
         {
             docMap = getDocumentList(soorder, recName, SrId);
             sendRegistertNotifications(accountId, null, docMap,SrId);
             //SendGridServiceRequestADMCustomerEmail.sendEmailToCustomer(SrId,'ADM Registration completion email notification');  // This is initiated from sendRequestToXiboApi
         }
     }
     
     if (listOfSrs.size() > 0 && !listOfSrs.isEmpty()) 
     {
         update listOfSrs;
     }
    }
    
    /**
    * @description Broker Registration-specific workflow engine that determines and creates the
    *              next step Task based on the current task's subject and Broker_Registration_Status__c.
    *              Routing logic includes:
    *              - Task 1 Approved → skip to order +2 (bypass document collection)
    *              - Task 1 or Task 3 RMI → revert to order 2
    *              - Task 3 Approved or Task 4 Signed → advance to next order
    *              - Task 2 Completed → revert to order 1
    *              - Task 5 Approved → end of workflow, return without creating a task
    * @param completedTaskServiceRequestIds  Set of completed Task Ids
    * @param taskOrderMap                    Map of Task Id to Task record for completed BR tasks
    * @param serviceRequestsrMap             Map of SR Id to ServiceRequest__c record
    */    
    @TestVisible 
    private static void createNextStepBRTasks(Set<Id> completedTaskServiceRequestIds, Map<Id, Task> taskOrderMap, Map<Id, ServiceRequest__c> serviceRequestsrMap) 
    {
        // Retrieve relevant ServiceAction records ordered by Order__c
        boolean docmentRequired = false;
        
        List<ServiceRequest__c> listOfSrs = new List<ServiceRequest__c>();
        set<Id> serviceRequestId = new Set<Id>();
        set<string> assignmentRuleID = new Set<string>();
        Map<Decimal, String> tskobjMap = new Map<Decimal, String>();
        Map<String, ServiceAction__c> srActionMap = new Map<String, ServiceAction__c>();
        Map<String, Task> tskActionMap = new Map<String, Task>();
        Map<String, Decimal> actionsubjectMap = new Map<String, Decimal>();
        
        List<ServiceAction__c> actions = [SELECT Id, Name, AssignmentRule__c, FinalTask__c, TaskType__c, NOC_Status__c,No_Of_Due_Days__c,TaskSubject__c, SR_Type__c,
                                          Description__c, Is_Sub_Task__c, KYC_Status__c, Order__c,
                                          ServiceCatalog__r.Service_Request_Type__c 
                                          FROM ServiceAction__c 
                                          WHERE ServiceCatalog__r.Service_Request_Type__c = : Constants.SERVICE_REQUEST_BR ORDER BY Order__c ASC];
        for (ServiceAction__c action: actions) {
            system.debug(action+'actions');
            assignmentRuleID.add(action.AssignmentRule__c);
            actionsubjectMap.put(action.TaskSubject__c,action.Order__c);
        }
        
        Map<Id, AssignmentRule__c> assigneeQueue = getSrAssigneeQueue(assignmentRuleID);
        List<Task> tasksToCreate = new List<Task>();
        // Iterate through completed tasks to determine next steps
        for (Id completedTaskId: taskOrderMap.keySet()){
            Integer completedTaskOrder = Integer.valueOf(taskOrderMap.get(completedTaskId).Order__c);
            tskActionMap.put(String.valueOf(completedTaskOrder), taskOrderMap.get(completedTaskId));
            System.debug('tskActionMap--->' + tskActionMap);
            Decimal nextOrder = Decimal.valueOf(completedTaskOrder);
            System.debug('nextOrder:::'+nextOrder);
            
            system.debug('taskOrderMap.get(completedTaskId).Subject :'+taskOrderMap.get(completedTaskId).Subject );
            system.debug('taskOrderMap.get(completedTaskId).Broker_Registration_Status__c:'+ taskOrderMap.get(completedTaskId).Broker_Registration_Status__c );
            if ( taskOrderMap.get(completedTaskId).Subject == BRConstants.SERVICE_REQUEST_TASK1 &&
                taskOrderMap.get(completedTaskId).Broker_Registration_Status__c == BRConstants.ACTION_STATUS_APPROVED){
                    
                    nextOrder = nextOrder + 2;
                    system.debug('nextOrder::'+nextOrder);
                } else if ( (taskOrderMap.get(completedTaskId).Subject == BRConstants.SERVICE_REQUEST_TASK1 ||
                             taskOrderMap.get(completedTaskId).Subject == BRConstants.SERVICE_REQUEST_TASK3)  &&
                           taskOrderMap.get(completedTaskId).Broker_Registration_Status__c == BRConstants.ACTION_STATUS_RMI){
                               nextOrder = 2;
                           }
            else if ((taskOrderMap.get(completedTaskId).Subject == BRConstants.SERVICE_REQUEST_TASK3 &&
                      taskOrderMap.get(completedTaskId).Broker_Registration_Status__c == BRConstants.ACTION_STATUS_APPROVED) ||
                     (taskOrderMap.get(completedTaskId).Subject == BRConstants.SERVICE_REQUEST_TASK4 &&
                      taskOrderMap.get(completedTaskId).Broker_Registration_Status__c == BRConstants.ACTION_STATUS_SIGNED)){
                          nextOrder = nextOrder + 1;
                      }
            else if ( taskOrderMap.get(completedTaskId).Subject == BRConstants.SERVICE_REQUEST_TASK2 &&
                     taskOrderMap.get(completedTaskId).Broker_Registration_Status__c == BRConstants.ACTION_STATUS_COMPLETED){
                         nextOrder = 1;
                     }else if(taskOrderMap.get(completedTaskId).Subject == BRConstants.SERVICE_REQUEST_TASK5
                              // taskOrderMap.get(completedTaskId).Order__c == 5
                              && taskOrderMap.get(completedTaskId).Broker_Registration_Status__c == BRConstants.ACTION_STATUS_APPROVED){
                                  system.debug('returned');    
                                  return;
                              }
            
            
            for (ServiceAction__c action: actions) 
            {             
                
                if (action.Order__c == nextOrder) 
                {
                    system.debug('NExtttt---->');
                    Task t = new Task();
                    t.WhatId = taskOrderMap.get(completedTaskId).WhatId;
                    t.RecordTypeId = TaskRecordTypeId;
                    t.Subject = action.TaskSubject__c;
                    
                    if (assigneeQueue.containsKey(action.AssignmentRule__c)) 
                    {
                        t.OwnerId = assigneeQueue.get(action.AssignmentRule__c).DefaultQueueID__c;
                    }

    t.Description = action.Description__c;
                    t.Order__c = action.Order__c;
                    t.Priority = 'High';
                    t.Status = 'Not Started';
/*1.7 starts*/   
    if(action.No_Of_Due_Days__c != null)
    {
        t.ActivityDate = Date.today().addDays(
            Integer.valueOf(action.No_Of_Due_Days__c)
        );
    }
/*1.7 Ends*/ 
                    tasksToCreate.add(t);
                    break;  // Only create one task per completed task
                }
            }
        }
        
        System.debug('tasksToCreate---->' + tasksToCreate);
        // Insert new tasks if any
        if (!tasksToCreate.isEmpty()) 
        {
            insert tasksToCreate;
            updateCurrentStepOnSR(tasksToCreate); //v1.4
        } 
        
    }

    /**
    * @description Retrieves a map of AssignmentRule__c records keyed by their Id, used to determine
    *              the default queue or user for task assignment during workflow step creation.
    * @param assignmentRuleID  Set of AssignmentRule__c Ids to query
    * @return  Map of AssignmentRule__c Id to AssignmentRule__c record
    */
    @TestVisible
    private static map<Id, AssignmentRule__c> getSrAssigneeQueue(set<String> assignmentRuleID) 
    {
        Map<Id, AssignmentRule__c> assinementQueueMap = new Map<Id, AssignmentRule__c>();
        // Map<String,AssignmentUser__c> asrMap= new Map<String,AssignmentUser__c>();
        for (AssignmentRule__c assrle: [
            SELECT Id, DefaultQueueID__c,
            DefaultUserId__c FROM AssignmentRule__c WHERE ID IN : assignmentRuleID
        ]) {
            System.debug('assinementQueueMap' + assinementQueueMap);
            assinementQueueMap.put(assrle.Id, assrle);
        }
        
        /* for (AssignmentRule__c assrle : [SELECT Id,DefaultQueueID__c, (SELECT
            IsActive__c,AssignmentRule__c,User__c,BusinessHours__c,
            AssignmentDays__c,MondayStartTime__c,MondayEndTime__c,TuesdayStartTime__c,TuesdayEndTime__c,WednesdayStartTime__c,WednesdayEndTime__c,ThursdayStartTime__c,ThursdayEndTime__c,FridayStartTime__c,FridayEndTime__c,SaturdayEndTime__c,MaximumCapacity__c,
            Assigned_Tasks__c FROM AssignmentUsers__r ORDER BY Assigned_Tasks__c ASC) FROM AssignmentRule__c
            WHERE ID IN :assignmentRuleID])
            {
            for( AssignmentUser__c asusr: assrle.AssignmentUsers__r){
            
            decimal availblecount = asusr.MaximumCapacity__c - asusr.Assigned_Tasks__c;
            if(asusr.Assigned_Tasks__c == 0){
            asrMap.put(asusr.AssignmentRule__c,asusr);
            }
            else if(availblecount > 0 ){
            asrMap.put(asusr.AssignmentRule__c,asusr);
            }
            }
            }*/
        return assinementQueueMap;
    }
    /**
    * @description Reopens previously closed or sub-task-flagged Tasks based on a given order number
    *              and related Service Request Id. Used in ADM workflows when a task is returned for
    *              more information, reverting the previous step's task back to 'Open' status.
    * @param tskObjMap  Map of task Order__c (Decimal) to Service Request Id (String)
    * @param SubTask    Boolean indicating whether to mark the reopened task as a sub-task
    */
    @TestVisible 
    private static void getPreviousTasks(Map<Decimal, String> tskObjMap, boolean SubTask) 
    {
        List<Task> preTskLst =
            [SELECT Id from Task Where Order__c = : tskobjMap.KeySet() AND WhatId = : tskobjMap.values()];
        List<Task> taksToUpdate = new List<Task>();
        if (preTskLst.size() > 0 && !preTskLst.isEmpty()) {
            for (Task t: preTskLst) {
                Task tsk = new Task(id = t.id, status = Constants.TASK_STATUS_OPEN, Is_Sub_Task__c = SubTask);
                System.debug('preTskLst--->' + preTskLst);
                taksToUpdate.add(tsk);
            }
        }
        if (!taksToUpdate.isEmpty()) 
        {
            update taksToUpdate;
        }
    }
    /**
    * @description Creates the first (initial) workflow Task for newly created Service Request records.
    *              Queries ServiceAction__c records matching the SR record types and subtype, then
    *              creates only the first-order task for each SR. Task ownership is assigned in order
    *              of priority: AssignmentRule queue → Sales Agent → SR Owner.
    * @param srRecordTypes  Map of SR Id to SR Record Type Name
    * @param srIds          Set of Service Request Ids to create tasks for
    * @param srType         SR subtype string used to filter applicable ServiceAction records
    * @param salesAgentId   Set of Sales Agent User Ids for task ownership assignment
    * @param srOwnerId      Set of SR Owner Ids as fallback for task ownership assignment
    */
    @TestVisible 
    private static void createIntialStepTasks(Map<Id, String> srRecordTypes, set<id> srIds,string srType,set<id> salesAgentId,set<Id> srOwnerId) 
    {
        // Retrieve relevant ServiceAction records ordered by Order__c
        System.debug('srType' + srType + srRecordTypes);
        set<String> assignmentRuleID = new set<String>();
        List<ServiceAction__c> actions = [
            SELECT Id, Name, AssignmentRule__c, TaskType__c, TaskSubject__c, Description__c, Is_Sub_Task__c,
            KYC_Status__c, Order__c,
            ServiceCatalog__r.Service_Request_Type__c FROM ServiceAction__c WHERE
            ServiceCatalog__r.Service_Request_Type__c = : srRecordTypes.values() AND(
                SR_Type__c =: srType or SR_Type__c = '') ORDER BY Order__c ASC
        ];
        for (ServiceAction__c action: actions) {
            assignmentRuleID.add(action.AssignmentRule__c);
        }
        Map<Id, AssignmentRule__c> assigneeQueue = getSrAssigneeQueue(assignmentRuleID);
        List<Task> tasksToCreate = new List<Task>();
        
        // Iterate through completed tasks to determine next steps
        Integer completedTaskOrder = 1;
        Decimal nextOrder = Decimal.valueOf(completedTaskOrder);
        
        // Find the relevant action for the next step
        for (ServiceAction__c action: actions) {
            for (Id srId: srIds) {
                Task t =
                    new Task(WhatId = srID, RecordTypeId = TaskRecordTypeId,
                             Description = action.Description__c, Priority = 'High', Status = 'Not Started',
                             Order__c = action.Order__c, Subject = action.TaskSubject__c);
                if (assigneeQueue.containsKey(action.AssignmentRule__c)) {
                    t.OwnerId = assigneeQueue.get(action.AssignmentRule__c).DefaultQueueID__c;
                }else if (salesAgentId != null && !salesAgentId.isEmpty()) {
                    t.OwnerId = salesAgentId.iterator().next();
                }else if (srOwnerId != null && !srOwnerId.isEmpty()){
                    t.OwnerId =  srOwnerId.iterator().next();
                }
                t.ServiceAction__c = action.Id;
                tasksToCreate.add(t);
            }
            break;
        }
        
        // Insert new tasks if any
        if (!tasksToCreate.isEmpty()) {
            System.debug('tasksToCreate--->' + tasksToCreate);
            insert tasksToCreate;
        }
    } 
    
    /**
    * @description Validates that required documents have been uploaded before a task can be closed.
    *              Supports multiple SR record types (ADM, Property Transfer, JO Addition, PE, LPC,
    *              Unit Consolidation, Joint Owner Title Deed, Payment Plan Swap, Plot Handover,
    *              Default Unit Cancellation, etc.) with step-specific document checks:
    *              - ADM: validates registration docs, deregistration forms, payment proof/receipt
    *                     and penalty charges per task order step
    *              - Property Transfer: validates Community NOC (step 3), MCD doc & charges (step 4),
    *                                   payment proof (step 6), Title Deed (step 9)
    *              - Payment Plan Swap: validates Payment Plan Swap document at step 6
    *              - LPC: validates Payment Proof document at step 3
    *              Throws field-level errors on the task's Status field to prevent closure.
    * @param newList  List of Task SObjects being updated
    * @param oldMap   Map of old Task SObjects for status change comparison
    */
    // This Method validated the document for each step while closing the task
    public static void documentValidation (List<SObject> newList, Map<Id, SObject> oldMap)
    {
        set<Id> serviceRequestId = new Set<Id> ();
        set<Id> salesOrderId = new Set<Id> ();
        set<String> serviceRequestRtName = new set<String> ();
        List<ServiceRequest__c> listOfSrs = new List<ServiceRequest__c> ();
        //Map<Id, Prospect_Account__c> prosaccMap = new Map<Id, Prospect_Account__c> ();
        List<Prospect_Account__c> prosaccList = new List<Prospect_Account__c> ();
        map<String, Task> tskMap = new Map<String, Task> ();
        for (Task newTask: (List<Task>)newList)
        {
            if (newTask.WhatId<> null && newTask.WhatId.getSObjectType ().getDescribe ().getName() == 'ServiceRequest__c')
            {
                Task oldRecord;
                
                if (oldMap.size () > 0 && !oldMap.isEmpty ())
                {
                    oldRecord = (Task)oldMap.get (newTask.Id);
                    if (oldRecord != null && oldRecord.Status<> newTask.Status && newTask.Status == Constants.TASK_STATUS_CLOSED)
                    {
                        serviceRequestId.add (newTask.whatId);
                        tskMap.put (String.ValueOf (newTask.Order__c), newTask);
                    }
                }
            }
        }
        System.debug ('tskMap----->' + tskMap);
        Map<Id, ServiceRequest__c> srRecordMap = getServiceRequestMap (serviceRequestId);
        Map<Id, charge__c> chargeMap = getChargeData (serviceRequestId);
        
        system.debug ('chargeMap----->' + chargeMap);
        for (ServiceRequest__c sr: srRecordMap.values ())
        {
            salesOrderId.add (sr.SalesOrder__c);
            serviceRequestId.add (sr.Id);
            System.debug ('salesOrderId----->' + salesOrderId);
            serviceRequestRtName.add (sr.RecordType.Name);
        }
        string docName;
        Map<String, Documents__c> docMap = new Map<String, Documents__c> ();
        //Map<String, Documents__c> prosacDocMap = new Map<String, Documents__c> ();
        List<Documents__c> prosacDocList = new List<Documents__c> ();
        
        if (serviceRequestRtName.contains (Constants.SERVICE_REQUEST_RT_DEV_NAME_ADM))
        {
            docMap = getDocumentList (salesOrderId, serviceRequestRtName,serviceRequestId);
        }
        List<ServiceRequest__c> titleDeedCommercialSRs = new List<ServiceRequest__c>();
        
        for (ServiceRequest__c sr : srRecordMap.values()) {
            if (sr.RecordType.Name == Constants.SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER_TITLE_DEED_COMMERCIAL) {
                titleDeedCommercialSRs.add(sr);
            }
            
        }
        
        System.debug ('salesOrderDocs----->' + docMap);
        
        if (serviceRequestRtName.contains (Constants.SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER)
            || serviceRequestRtName.contains (Constants.SERVICE_REQUEST_RT_DEV_NAME_JO_ADDITION)
            || serviceRequestRtName.contains (Constants.SERVICE_REQUEST_RT_DEV_NAME_PE) 
            || serviceRequestRtName.contains (Constants.SERVICE_REQUEST_LPC) 
            || serviceRequestRtName.contains (Constants.SERVICE_REQUEST_UC)
            || serviceRequestRtName.contains(Constants.SERVICE_REQUEST_MILESTONE) 
            ||  serviceRequestRtName.contains (Constants.SERVICE_REQUEST_RT_DEV_NAME_JOINT_OWNER_TITLE_DEED) 
            || serviceRequestRtName.contains (Constants.SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER_TITLE_DEED)
            || serviceRequestRtName.contains (Constants.SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER_TITLE_DEED_COMMERCIAL)
            || serviceRequestRtName.contains (Constants.SERVICE_REQUEST_RT_PAYMENT_PLAN_SWAP)
            || serviceRequestRtName.contains (Constants.SERVICE_REQUEST_PLOT_HANDOVER)
            || serviceRequestRtName.contains (Constants.SERVICE_REQUEST_CANCELLATION_DEFAULT)
            ||  serviceRequestRtName.contains (Constants.SERVICE_REQUEST_RT_PRE_UNIT_CANCELLATION) //1.5
            ||  serviceRequestRtName.contains (Constants.SERVICE_REQUEST_RT_POST_UNIT_CANCELLATION)//1.5
            
           )
        {
            //prosaccMap = getProspectList (serviceRequestId);
            prosaccList = getProspectList (serviceRequestId);
            docMap = getDocumentList (salesOrderId, serviceRequestRtName,serviceRequestId);
            
            for(String sr: docMap.keyset())
            {///list the documents details collected
                system.debug('debug: sr: ' + sr);
                system.debug('debug: sr status: ' + docMap.get(sr).Status__c);
            }
            
            set<Id> praccIds = new set<Id> ();
            //for (Prospect_Account__c pacc: prosaccMap.values ())
            for (Prospect_Account__c pacc: prosaccList)
            {
                praccIds.add (pacc.id);
            }
            //prosacDocMap = getProspectDoumentList (praccIds);
            prosacDocList = getProspectDoumentList (praccIds);
            
        }
        if(serviceRequestRtName.contains(Constants.SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER_TITLE_DEED_COMMERCIAL)
          ){      
              PropertyTransferTitleDeedController.validatePropertyTransferSRDocuments(serviceRequestRtName, docMap, tskMap,srRecordMap,titleDeedCommercialSRs, chargeMap);
          }
        // String[] mandatoryDocs = Label.PropertyTransferMnadatoryDocs.split(',');
        
        if (serviceRequestRtName.contains (Constants.SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER)
            || serviceRequestRtName.contains (Constants.SERVICE_REQUEST_RT_DEV_NAME_JO_ADDITION)
            || serviceRequestRtName.contains (Constants.SERVICE_REQUEST_RT_DEV_NAME_PE)
            || serviceRequestRtName.contains (Constants.SERVICE_REQUEST_LPC)
            || serviceRequestRtName.contains (Constants.SERVICE_REQUEST_UC)
            || serviceRequestRtName.contains (Constants.SERVICE_REQUEST_MILESTONE) 
            || serviceRequestRtName.contains (Constants.SERVICE_REQUEST_RT_DEV_NAME_JOINT_OWNER_TITLE_DEED) 
            || serviceRequestRtName.contains (Constants.SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER_TITLE_DEED)
            || serviceRequestRtName.contains (Constants.SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER_TITLE_DEED_COMMERCIAL)
            || serviceRequestRtName.contains (Constants.SERVICE_REQUEST_RT_PAYMENT_PLAN_SWAP)
            || serviceRequestRtName.contains (Constants.SERVICE_REQUEST_PLOT_HANDOVER)
            || serviceRequestRtName.contains (Constants.SERVICE_REQUEST_CANCELLATION_DEFAULT)
            ||  serviceRequestRtName.contains (Constants.SERVICE_REQUEST_RT_PRE_UNIT_CANCELLATION)//1.5
            ||  serviceRequestRtName.contains (Constants.SERVICE_REQUEST_RT_POST_UNIT_CANCELLATION)//1.5
           )
        {
            
            for (String ordr: tskMap.keySet ())
            {
                System.debug ('ordr---->' + ordr);
                List<String> missingDocs = new List<String> ();
                if (tskMap.get (ordr).Status == Constants.TASK_STATUS_CLOSED)
                {
                    // new validation for paymentplan swap 14-05-2025
                    
                    for (Documents__c dc : docMap.values()) {
                        if ( serviceRequestRtName.contains(Constants.SERVICE_REQUEST_RT_PAYMENT_PLAN_SWAP) &&(ordr == '6' || ordr == '6.0')) {
                            if (dc.Name.contains('Payment Plan Swap') && dc.Status__c != 'Uploaded') {
                                tskMap.get (ordr).Status.addError ( 'Please upload the Payment Plan Swap Document before closing the task.');
                            }
                        }
                        if (serviceRequestRtName.contains(Constants.SERVICE_REQUEST_LPC) && dc.Name.contains ('Payment Proof') && dc.Status__c != 'Uploaded' && (ordr == '3' || ordr == '3.0')) {
                            tskMap.get (ordr).Status.addError ('Please Upload the Payment Proof Document');
                        }
                    }
                    
                    /*if (ordr == '2' || ordr == '2.0')
                    {
                    //for (Prospect_Account__c pacc: prosaccMap.values ())
                    for (Prospect_Account__c pacc: prosaccList)
                    {
                    System.debug('debug: pacc.Name ' + pacc.Name);
                    List<String> requiredDocs = new List<String> ();
                    
                    if (pacc.RecordTypeName__c == 'Account')
                    {
                    requiredDocs.addAll (System.Label.PropertyTransferMnadatoryDocsforAcc.split (','));
                    }
                    else if (pacc.RecordTypeName__c == 'Contact')
                    {
                    requiredDocs.addAll (System.Label.PropertyTransferMnadatoryDocs.split (','));
                    }
                    
                    missingDocs = new List<String> (requiredDocs);
                    
                    //for (Documents__c dc: prosacDocMap.values ())
                    for (Documents__c dc: prosacDocList)
                    {
                    if (dc.Prospect_Account__c == pacc.Id && missingDocs.contains (dc.Name.trim ()) && dc.Status__c == 'Uploaded')
                    {
                    for (Integer i = 0; i < missingDocs.size (); i++)
                    {
                    if (missingDocs[i].trim ().equalsIgnoreCase (
                    dc.Name.trim ()))
                    {
                    missingDocs.remove (i);
                    break;
                    }
                    }
                    }
                    }
                    
                    if (!missingDocs.isEmpty ())
                    {
                    String displayName = (pacc.RecordTypeName__c == 'Contact' && pacc.Full_Name__c != null) ? pacc.Full_Name__c : pacc.Account__r.Name;
                    tskMap.get(ordr).Status.addError ('Prospect Account: ' + displayName + ' - Please upload the following documents: ' + String.join (missingDocs, ', '));
                    }
                    }
                    }*/
                    if (ordr == '6' || ordr == '6.0' )
                    {
                        for (Documents__c dc: docMap.values ())
                        {
                            if (dc.Name.contains ('Payment Proof') && dc.Status__c != 'Uploaded')
                            {
                                tskMap.get (ordr).Status.addError ('Please Upload the Payment Proof Document');
                            }
                        }
                    }
                    
                    for (Documents__c dc: docMap.values ())
                    {
                        system.debug('debug: dc ' + dc.Name);
                        system.debug('debug: dc.Status__c ' + dc.Status__c);
                        system.debug('debug: dc.id ' + dc.id);
                        if (ordr == '3' || ordr == '3.0')
                        {
                            if (dc.Name.contains ('Community NOC') && dc.Status__c != 'Uploaded')
                            {
                                tskMap.get (ordr).Status.addError ('Please Upload the Community NOC Document on the SR');
                            }
                        }
                        
                        if (ordr == '4' || ordr == '4.0')
                        {
                            system.debug('debug: dc ' + dc.Name);
                            system.debug('debug: dc.Status__c ' + dc.Status__c);
                            system.debug('debug: dc.id ' + dc.id);
                            if (dc.Name.contains ('MCD') && dc.Status__c != 'Uploaded')
                            {
                                tskMap.get (ordr).Status.addError ('Please Upload the Signed MCD Document on the SR');
                            }
                            if (chargeMap.containsKey (tskMap.get (ordr).WhatId))
                            {
                                if (chargeMap.get (tskMap.get (ordr).WhatId).Name.Contains ('NOC') && !serviceRequestRtName.contains(Constants.SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER))
                                {
                                    tskMap.get (ordr).Status.addError ('Please update the ' + chargeMap.get (tskMap.get (ordr).WhatId).Name + ' charge status to paid: ');
                                }
                                if (chargeMap.get (tskMap.get (ordr).WhatId).Name.Contains ('Extension Fee'))
                                {
                                    tskMap.get (ordr).Status.addError ('Please update the ' + chargeMap.get (tskMap.get (ordr).WhatId).Name + ' charge status to paid: ');
                                }
                            }
                        }
                        if ((ordr == '9' || ordr == '9.0')  && (tskMap.get (ordr).NOC_Doc_Status__c=='Title Deed Issued') )
                        {
                            
                            system.debug('debug: dc ' + dc.Name);
                            system.debug('debug: dc.Status__c ' + dc.Status__c);
                            system.debug('debug: dc.id ' + dc.id);
                            if (dc.Name.contains ('Title Deed') && dc.Status__c != 'Uploaded')
                            {
                                tskMap.get (ordr).Status.addError ('Please Upload the Title Deed Document on the SR');
                            }
                        }
                    }
                }
            }
        }
        
        /*    if (serviceRequestRtName.contains (Constants.SERVICE_REQUEST_RT_DEV_NAME_UNIT_SWAP) || serviceRequestRtName.contains (Constants.SERVICE_REQUEST_RT_DEV_NAME_UNIT_UPGRADE))
                {
                System.debug ('salesOrderDocs----->' + docMap);
                for (string ordr: tskMap.keyset ())
                {
                System.debug ('ordr---->' + ordr);
                
                if (tskMap.get (ordr).Status == Constants.TASK_STATUS_CLOSED)
                {
                if (ordr == '9' || ordr == '9.0'){
                if (chargeMap.containsKey (tskMap.get (ordr).WhatId))
                {
                if (chargeMap.get (tskMap.get (ordr).WhatId).Name.Contains ('ADM Fee'))
                {
                tskMap.get (ordr).Status.addError ('Please update the ' + chargeMap.get (tskMap.get (ordr).WhatId).Name + ' charge status to paid: ');
                }
                }
                }
                }
                }
                } */
        
        if (serviceRequestRtName.contains (Constants.SERVICE_REQUEST_RT_DEV_NAME_ADM))
        {
            System.debug ('salesOrderDocs----->' + docMap);
            for (string ordr: tskMap.keyset ())
            {
                System.debug ('ordr---->' + ordr);
                
                if (tskMap.get (ordr).Status == Constants.TASK_STATUS_CLOSED)
                {
                    if (docMap.size () > 0 && !docMap.isEmpty ())
                    {
                        // for(Documents__c dc:docMap.values()){
                        // for(Documents__c docs:docMap.values()){
                        System.debug ('docs---->' + docMap);
                        System.debug ('docs---->' + !(docMap.containsKey ('Passport')));
                        if (ordr == '1' || ordr == '1.0')
                        {
                            if (srRecordMap.get (tskMap.get (ordr).WhatId).Type__c == 'Next of Kin')
                            {
                                if ((docMap.containsKey (Label.ADM_Registration_Document) && docMap.get (Label.ADM_Registration_Document).Status__c != 'Uploaded'))
                                {
                                    System.debug (Label.ADM_Registration_Document);
                                    tskMap.get (ordr).Status.addError ('Please Upload '+ Label.ADM_Registration_Document);
                                }
                            }
                            else if (srRecordMap.get (tskMap.get (ordr).WhatId).Type__c == 'Normal' || srRecordMap.get (tskMap.get (ordr).WhatId).Type__c == 'Court Order')
                            {
                                if ((docMap.containsKey (Label.Deregistration_Form) && docMap.get (Label.Deregistration_Form).Status__c != 'Uploaded'))
                                {
                                    System.debug (Label.Deregistration_Form);
                                    tskMap.get (ordr).Status.addError ('Please Upload '+ Label.Deregistration_Form);
                                }
                            }
                            else if (srRecordMap.get (tskMap.get (ordr).WhatId).Type__c == 'New Sale')
                            {
                                /* String[] requiredDocs =
                                    Label.ServiceRequestAdmDocs.split(',');
                                    
                                    for (String doc : requiredDocs) {
                                    doc = doc.trim(); // Remove extra spaces
                                    if (docMap.containsKey(doc) &&
                                    docMap.get(doc).Status__c != 'Uploaded') {
                                    System.debug(doc);
                                    tskMap.get(ordr).Status.addError('Please
                                    upload the ' + doc + ' Document');
                                    }
                                    }*/
                                String[] requiredDocs = Label.ServiceRequestAdmDocs.split (',');
                                List<String> missingDocs = new List<String> ();
                                
                                for (String doc: requiredDocs)
                                {
                                    doc = doc.trim (); // Remove extra spaces
                                    if (!docMap.containsKey (doc) || docMap.get (doc).Status__c != 'Uploaded')
                                    {
                                        missingDocs.add (doc);
                                    }
                                }
                                
                                if (!missingDocs.isEmpty ())
                                {
                                    String errorMessage = 'Please upload the ' + String.join (missingDocs, ', ');
                                    tskMap.get (ordr).Status.addError (errorMessage);
                                }
                            }
                        }
                        else if (ordr == '2.0' || ordr == '2')
                        {
                        }
                        else if ((ordr == '3.0' || ordr == '3'))
                        {
                            
                            if ((docMap.containsKey (Label.Payment_Proof)  && docMap.get (Label.Payment_Proof).Status__c!= 'Uploaded'))
                            {
                                System.debug (Label.Payment_Proof);
                                tskMap.get (ordr).Status.addError ('Please Upload ' + Label.Payment_Proof);
                            }
                            
                            if (srRecordMap.get (tskMap.get (ordr).WhatId).Penality_Charge__c == True
                                && (srRecordMap.get (tskMap.get (ordr).WhatId).SalesOrder_Completed_Date__c < srRecordMap.get (tskMap.get (ordr).WhatId).Dari_Application_Submitted_Date__c))
                            {
                                System.debug ('chargeMap--->' + chargeMap);
                                if (chargeMap.containsKey (tskMap.get (ordr).WhatId))
                                {
                                    if (chargeMap.get (tskMap.get (ordr).WhatId).Name.Contains ('Penality Fee'))
                                    {
                                        tskMap.get (ordr).Status.addError (Label.Penality_Charge_Error);
                                    }
                                }
                            }
                            else
                            {
                                break;
                            }
                        }
                        
                        else if ((ordr == '4.0' || ordr == '4'))
                        {
                            if ((docMap.containsKey (Label.Payment_Receipt) && docMap.get (Label.Payment_Receipt).Status__c != 'Uploaded'))
                            {
                                System.debug (Label.Payment_Receipt);
                                tskMap.get (ordr).Status.addError ('Please Upload ' + Label.Payment_Receipt);
                            }
                        }
                        else if ((ordr == '5.0' || ordr == '5') && (docMap.containsKey (Label.ADM_Registration_Document) && docMap.get (Label.ADM_Registration_Document).Status__c != 'Uploaded'))
                        {
                            System.debug (Label.Payment_Receipt);
                            tskMap.get (ordr).Status.addError ('Please Upload ' + Label.ADM_Registration_Document);
                        }
                        else
                        {
                            // System.debug('Error');
                        }
                        //}
                        //}
                    }
                }
            }
        }
    }
    /**
    * @description Retrieves unpaid Charge__c records associated with the given Service Request Ids
    *              where the paid amount does not equal the total charge amount. Used in document
    *              validation to check for outstanding fees (e.g., Modon Fee, Extension Fee, Penalty Fee).
    * @param completedTaskServiceRequestIds  Set of Service Request Ids to query charges for
    * @return  Map of Service Request Id to the first unpaid Charge__c record found
    */
    @TestVisible 
    private static Map<Id, Charge__c> getChargeData (Set<Id> completedTaskServiceRequestIds)
    {
        Map<Id, Charge__c> chargeMap = new Map<Id, Charge__c> ();
        List<Charge__c> chargelst = [
            SELECT Id, Service_Request__c, Name, Paid_Amount__c, PaymentStatus__c,
            Remaining_Amount__c, Sales_Order__c, Type__c, VAT_Amount__c,
            Amount__c FROM Charge__c Where Service_Request__c IN : completedTaskServiceRequestIds AND (PaymentStatus__c <> 'Paid')];
        for (Charge__c c: chargelst)
        {
            if (c.Paid_Amount__c<> c.Amount__c)
            {
                chargeMap.put (c.Service_Request__c, c);
            }
        }
        return chargeMap;
    }
    /**
    * @description Retrieves a comprehensive map of ServiceRequest__c records by Id, including
    *              fields required for document validation, email notifications, and workflow
    *              processing (e.g., account details, sales order, ADM fields, title deed data).
    * @param completedTaskServiceRequestIds  Set of Service Request Ids to query
    * @return  Map of Service Request Id to ServiceRequest__c record
    */
    @TestVisible 
    private static Map<Id, ServiceRequest__c> getServiceRequestMap(Set<Id> completedTaskServiceRequestIds) {
        Map<Id, ServiceRequest__c> serviceRequestMap = new Map<Id, ServiceRequest__c>();
        List<ServiceRequest__c> serviceRequestlst = [SELECT Id,Signature_Status__c,UnitId__c,Cancellation_Type__c,Outstanding_Charge__c,Is_Manual_Upload__c,AccountId__c,RecordTypeName__c,CloseDate__c, Penality_Charge__c,RecordType.Name, Type__c,SalesOrder__c,SalesOrder_Completed_Date__c,ADM_Fee__c,Dari_Application_Number__c,Dari_Application_Submitted_Date__c,
                                                     Buyer_Validator_Name__c,Seller_Validator_Email__c,Seller_Validation_Name__c,Buyer_Validator_Email__c,Master_Developer__c,Reference_Number__c,Initial_Purchase_Date__c,Master_Developer_License_Number__c,Agreement_Effective_Date__c,Seller_SPA_Effective_Date__c,SR_Selling_Price__c,Master_Community_Declaration_Date__c,Max_No_Of_Floors__c,Max_Allowable_Podium__c,Submission_Period_in_Months__c,Commencement_Date_in_Months__c,Completion_Date_in_Months__c 
                                                     FROM ServiceRequest__c WHERE Id IN :completedTaskServiceRequestIds];
        for (ServiceRequest__c sr : serviceRequestlst) {
            serviceRequestMap.put(sr.Id, sr);
        }
        System.debug('serviceRequestMap--->'+serviceRequestMap);
        return serviceRequestMap;
    }   
    /**
    * @description Retrieves a map of document records (Documents__c) keyed by document name for
    *              the given Sales Orders and/or Service Requests. Fetches documents linked to the
    *              sales order, the service request directly, and the primary customer contact,
    *              consolidating all into a single map for validation and notification purposes.
    * @param SalesOrderId          Set of Sales Order Ids to fetch linked documents
    * @param serviceRequestRtName  Set of SR Record Type Names to filter applicable document types
    * @param serviceRequestId      Set of Service Request Ids for direct document lookups
    * @return  Map of document Name to Documents__c record
    */
    public static Map<String,Documents__c> getDocumentList(set<Id> SalesOrderId,set<String> serviceRequestRtName,set<Id> serviceRequestId){
        System.debug('SalesOrderId'+SalesOrderId);
        list<string> ServiceRequestAdmDocs = System.label.ServiceRequestAdmDocs.split(',');
        list<string> serviceRequestSoAdmDocs = System.label.ServiceRequstADMSoDoc.split(',');
        
        Map<String,Documents__c> docMap = new Map<String,Documents__c>();
        System.debug('serviceRequestRtName'+serviceRequestRtName);
        Set<String> docTypeSet = new Set<String>();
        Map<String,DocumentType__c> docTypeMap = new Map<String,DocumentType__c>();
        List<DocumentType__c> docTypeList = [SELECT Id, Name,Type__c, ShareWithCustomer__c, IsSystemUpload__c FROM DocumentType__c WHERE ((ObjectType__c='Service Request' AND RecordTypeDevName__c =:serviceRequestRtName))];
        
        for(DocumentType__c doctyp: docTypeList){
            
            docTypeSet.add(doctyp.Type__c);
            docTypeMap.put(doctyp.Type__c,doctyp);
            System.debug('doctyp.Id------>'+doctyp.Id);
        }
        List<Documents__c> salesOrderDocs = [SELECT Id,Account__c, Name, SalesOrder__c,SalesOrder__r.CustomerAccount__c, Status__c,DocumentType__r.Type__c FROM Documents__c WHERE (SalesOrder__c = : salesOrderId  OR Service_Request__c =: serviceRequestId) AND  (Name Like :docTypeMap.keyset()  OR Name IN :serviceRequestSoAdmDocs)];
        for(Documents__c dc:salesOrderDocs){
            docMap.put(dc.Name,dc);
            System.debug('dc.Id------>'+dc.Id);
        }
        Contact relatedContact;
        List<Documents__c> customeraccDocs = new List<Documents__c>();
        ServiceRequest__c sReq = new ServiceRequest__c();
        
        sReq = [SELECT Id,Name__c, SalesOrder__c,SalesOrder__r.CustomerAccount__c,SalesOrder__r.CustomerAccount__r.PersonContactId,RecordTypeName__c,RecordType.Name FROM ServiceRequest__c WHERE Id = :serviceRequestId LIMIT 1];
        
        if (sReq.SalesOrder__r.CustomerAccount__r.PersonContactId == null) {
            // Business account — Get a related contact (e.g., primary contact if modeled)
            List<Contact> contacts = [
                SELECT Id, FirstName, LastName, Email
                FROM Contact
                WHERE AccountId = :sReq.SalesOrder__r.CustomerAccount__c
                LIMIT 1
            ];
            if (!contacts.isEmpty()) {
                relatedContact = contacts[0];
            }
        } else {
            // Person account — use PersonContactId directly
            relatedContact = [SELECT Id, FirstName, LastName, Email
                              FROM Contact
                              WHERE Id = :sReq.SalesOrder__r.CustomerAccount__r.PersonContactId
                              LIMIT 1];
        }
        if (relatedContact != null && docTypeMap != null && ServiceRequestAdmDocs != null) {
            customeraccDocs = [
                SELECT Id, Account__c, Name, SalesOrder__c, SalesOrder__r.CustomerAccount__c,
                Status__c, DocumentType__r.Type__c, Service_Request__c
                FROM Documents__c 
                WHERE PrimaryContact__c = :relatedContact.Id 
                AND (Name LIKE :docTypeMap.keySet() OR Name IN :ServiceRequestAdmDocs)
            ];
        }
        for(Documents__c dc:customeraccDocs){
            docMap.put(dc.Name,dc);
            System.debug('dc.Id------>'+dc.Id);
        }
        System.debug('salesOrderDocs------>'+salesOrderDocs);
        return docMap;
    }
    
    /*Private static Map<Id,Prospect_Account__c> getProspectList(set<Id> serviceRequestId)
    {
    Map<Id,Prospect_Account__c> prospectMap = new Map<Id,Prospect_Account__c>();
    
    List<Prospect_Account__c> prospectacc = [SELECT Id,Name,RecordTypeName__c,Account__r.Name,Full_Name__c,Service_Request__c FROM Prospect_Account__c Where Service_Request__c =:serviceRequestId];
    for(Prospect_Account__c pacc:prospectacc)
    {
    prospectMap.put(pacc.Service_Request__c,pacc);
    }
    return prospectMap;
    }*/
    /**
    * @description Retrieves a list of Prospect_Account__c records associated with the given
    *              Service Request Ids. Used in document validation to identify buyer/seller
    *              prospects and their associated document requirements.
    * @param serviceRequestId  Set of Service Request Ids to query prospects for
    * @return  List of Prospect_Account__c records linked to the provided Service Requests
    */
    @TestVisible 
    Private static List<Prospect_Account__c> getProspectList(set<Id> serviceRequestId)
    {
        List<Prospect_Account__c> prospectList = new List<Prospect_Account__c>();
        
        List<Prospect_Account__c> prospectacc = [SELECT Id,Name,RecordTypeName__c,Account__r.Name,Full_Name__c,Service_Request__c FROM Prospect_Account__c Where Service_Request__c =:serviceRequestId];
        for(Prospect_Account__c pacc:prospectacc)
        {
            prospectList.add(pacc);
        }
        return prospectList;
    }
    
    /*Private static Map<String,Documents__c> getProspectDoumentList(set<Id> prospectaccIds){
        Map<String,Documents__c> docMap = new Map<String,Documents__c>();
        
        List<Documents__c> ProspectDocs = [SELECT Id, Name,Prospect_Account__c, SalesOrder__c, Status__c,DocumentType__r.Type__c FROM Documents__c WHERE ( Prospect_Account__c = : prospectaccIds )];
        for(Documents__c dc:ProspectDocs){
        docMap.put(dc.Name,dc);
        }
        return docMap;
        }*/
    /**
    * @description Retrieves a list of Documents__c records linked to the given Prospect Account Ids.
    *              Used to validate that required documents have been uploaded for each prospect
    *              before allowing task closure.
    * @param prospectaccIds  Set of Prospect_Account__c Ids to query documents for
    * @return  List of Documents__c records associated with the provided prospect accounts
    */
    @TestVisible
    Private static List<Documents__c> getProspectDoumentList(set<Id> prospectaccIds){
        List<Documents__c> ProspectDocs = [SELECT Id, Name,Prospect_Account__c, SalesOrder__c, Status__c,DocumentType__r.Type__c FROM Documents__c WHERE ( Prospect_Account__c = : prospectaccIds )];
        return ProspectDocs;
    }
    /**
    * @description Sends a custom push notification to a specific user when a task is assigned.
    *              Builds a notification with the task subject, related SR name, and Sales Order name.
    *              Silently exits if the notification type ID, task ID, or user ID is null.
    * @param taskSubject         Subject of the task being assigned
    * @param taskId              Id of the Task record to use as the notification target
    * @param notificationTypeId  Id of the CustomNotificationType to use
    * @param userId              Id of the User to receive the notification
    * @param srName              Name of the related Service Request (shown in notification body)
    * @param soName              Name of the related Sales Order (shown in notification body); nullable
    */
    public static void sendTaskNotification(
        String taskSubject,
        Id taskId,
        Id notificationTypeId,
        Id userId,
        String srName,
        String soName
    ){
        if (notificationTypeId == null || taskId == null || userId == null) return;
        
        Messaging.CustomNotification n = new Messaging.CustomNotification();
        n.setNotificationTypeId(notificationTypeId);
        n.setTargetId(taskId);
        
        // Short title
        n.setTitle('Task Assigned: ' + taskSubject);
        
        // Simple, readable body
        String body = 'You have been assigned a task for SR: ' + (srName != null ? srName : 'N/A');
        if (soName != null) {
            body += ' | SO: ' + soName;
        }
        body += '. Please review and start working on it.'; //1.5
        n.setBody(body);//1.5
        
        n.send(new Set<String>{ String.valueOf(userId) });//1.5
    }
    //start 1.6
    //@description Sends push notifications to task owners when new
    public static void sendTaskAssignmentNotification(Set<Id> taskIds) {
        
        if (taskIds == null || taskIds.isEmpty()) return;
        
        // Get Tasks only for Order = 1
        List<Task> tasks = [SELECT Id, OwnerId, WhatId FROM Task WHERE Id IN :taskIds AND Order__c = 1 and What.RecordType.Name != 'Broker registration'];
        
        if (tasks.isEmpty()) return;
        
        // Get Email Template
        Id templateId;
        List<EmailTemplate> templates = [SELECT Id FROM EmailTemplate WHERE DeveloperName = 'SR_Created' LIMIT 1];
        
        if (!templates.isEmpty())
            templateId = templates[0].Id;
        
        if (templateId == null) {
            System.debug('Template not found');
            return;
        }
        Id orgWideEmailId;
        
        List<OrgWideEmailAddress> oweaList =
            [SELECT Id FROM OrgWideEmailAddress WHERE Address = 'noreply@modon.com' LIMIT 1];
        
        if (!oweaList.isEmpty()) {
            orgWideEmailId = oweaList[0].Id;
        }
        
        // Collect Owner Ids
        Set<Id> queueIds = new Set<Id>();
        Set<Id> userIds = new Set<Id>();
        
        for (Task t : tasks) {
            
            if (t.OwnerId.getSObjectType() == Group.SObjectType)
                queueIds.add(t.OwnerId);
            
            else if (t.OwnerId.getSObjectType() == User.SObjectType)
                userIds.add(t.OwnerId);
        }
        
        // Get Active Users
        Map<Id, User> userMap =
            new Map<Id, User>(
                [SELECT Id, Email FROM User WHERE Id IN :userIds AND IsActive = true]
            );
        
        // Get Queue Users
        Map<Id, List<User>> queueUsersMap = new Map<Id, List<User>>();
        
        if (!queueIds.isEmpty()) {
            
            for (GroupMember gm : [SELECT GroupId, UserOrGroupId FROM GroupMember WHERE GroupId IN :queueIds]) {
                
                if (gm.UserOrGroupId.getSObjectType() == User.SObjectType) {
                    
                    User usr =
                        [SELECT Id, Email FROM User WHERE Id = :gm.UserOrGroupId AND IsActive = true LIMIT 1];
                    
                    if (!queueUsersMap.containsKey(gm.GroupId))
                        queueUsersMap.put(gm.GroupId, new List<User>());
                    
                    queueUsersMap.get(gm.GroupId).add(usr);
                }
            }
        }
        
        // Build Emails
        List<Messaging.SingleEmailMessage> emailsToSend = new List<Messaging.SingleEmailMessage>();
        
        for (Task t : tasks) {
            
            if (t.WhatId == null) continue;
            
            // CASE 1 — Owner is User
            if (userMap.containsKey(t.OwnerId)) {
                
                User usr = userMap.get(t.OwnerId);
                
                if (usr.Email != null) {
                    
                    Messaging.SingleEmailMessage mail =
                        Messaging.renderStoredEmailTemplate(
                            templateId,
                            usr.Id,
                            t.WhatId
                        );
                    
                    mail.setTargetObjectId(usr.Id);
                    mail.setToAddresses(new String[] { usr.Email });
                    mail.setSaveAsActivity(false);
                    if (orgWideEmailId != null) {
                        mail.setOrgWideEmailAddressId(orgWideEmailId);
                    }
                    
                    emailsToSend.add(mail);
                }
            }
            
            // CASE 2 — Owner is Queue
            else if (queueUsersMap.containsKey(t.OwnerId)) {
                
                for (User usr : queueUsersMap.get(t.OwnerId)) {
                    
                    if (usr.Email != null) {
                        
                        Messaging.SingleEmailMessage mail =
                            Messaging.renderStoredEmailTemplate(
                                templateId,
                                usr.Id,
                                t.WhatId
                            );
                        
                        mail.setTargetObjectId(usr.Id);
                        mail.setToAddresses(new String[] { usr.Email });
                        mail.setSaveAsActivity(false);
                        if (orgWideEmailId != null) {
                            mail.setOrgWideEmailAddressId(orgWideEmailId);
                        }
                        
                        emailsToSend.add(mail);
                    }
                }
            }
        }
        
        // Send Emails
        if (!emailsToSend.isEmpty() &&
            System.Label.EmailCheck == 'true' &&
            !Test.isRunningTest()) {
                
                Messaging.sendEmail(emailsToSend);
            }
    }//End 1.6
    /**
    * @description Sends push notifications to task owners when new 'Not Started' tasks are created
    *              for Service Request records. Queries the related SR and Sales Order names for
    *              context, retrieves the 'Task_Creation' custom notification type, and calls
    *              sendTaskNotification for each qualifying task.
    * @param newTasks  List of newly inserted Task records
    */
    public static void sendNotification(List<Task> newTasks){
        if (newTasks == null || newTasks.isEmpty()) return;
        
        // Get SR Ids from tasks
        Set<Id> srIds = new Set<Id>();
        for (Task t : newTasks){
            if (t.Status == 'Not Started'
                && t.WhatId != null
                && t.WhatId.getSObjectType() == ServiceRequest__c.SObjectType) {
                    srIds.add(t.WhatId);
                }
        }
        if (srIds.isEmpty()) return; //1.5 start
        
        // Query SR + Sales Order
        Map<Id, ServiceRequest__c> srMap = new Map<Id, ServiceRequest__c>([
            SELECT Id, Name, SalesOrder__r.Name
            FROM ServiceRequest__c
            WHERE Id IN :srIds
        ]);
        
        // Notification Type
        Id notificationTypeId = [
            SELECT Id FROM CustomNotificationType
            WHERE DeveloperName = 'Task_Creation'
            LIMIT 1
        ].Id;
        
        // Send notification for each task
        for (Task t : newTasks){
            if (t.Status == 'Not Started'
                && t.WhatId != null
                && t.WhatId.getSObjectType() == ServiceRequest__c.SObjectType) {
                    
                    ServiceRequest__c sr = srMap.get(t.WhatId);
                    sendTaskNotification(
                        t.Subject,
                        t.Id,
                        notificationTypeId,
                        t.OwnerId,
                        sr != null ? sr.Name : null,
                        (sr != null && sr.SalesOrder__r != null) ? sr.SalesOrder__r.Name : null
                    );
                    String taskid = t.OwnerId;
                    // sendRegistertNotifications(null, t.Id, null, null);
                }
        }//1.5 end
    }
    
    
    // public static void sendNotification(List<Task> newTasks){
    //     map<String,Task> tskMap = new Map<String,Task>();
    //     Id notificationTypeId = [SELECT Id, DeveloperName FROM CustomNotificationType WHERE DeveloperName='Task_Creation']?.Id; 
    
    //     System.debug('sendCustomNotification'+newTasks);
    //     for(Task tsk : newTasks){
    //         if(tsk.Status == 'Not Started'){
    //             if(tsk.WhatId <> null && tsk.WhatId.getSObjectType().getDescribe().getName() == 'ServiceRequest__c'){
    //                 System.debug('calling');
    //                 sendTaskNotification(tsk.Subject, tsk.Id, notificationTypeId, tsk.OwnerId);
    //                 string taskId =tsk.OwnerId;
    //                 sendRegistertNotifications(null,taskId,null,null);
    //             }
    //         }
    //     }
    // }
    /**
    * @description Sends email notifications for ADM registration completion and new task assignments.
    *              Handles two notification scenarios:
    *              - ADM Registration Completion: sends email with ADM Registration Document attachment
    *                to the customer (person account or org account contacts) using the
    *                'ADM_Registration_completion_email' template
    *              - New Task Assignment: sends email to the task assignee using the
    *                'New_Task_Creation' template
    *              Also creates EmailMessage records for tracking. Respects the EmailCheck label
    *              to control actual email sending in non-test contexts.
    * @param srCustomer     Account Id of the SR customer to send registration completion email; nullable
    * @param tskId          User Id of the task assignee to send task assignment email; nullable
    * @param docMap         Map of document Name to Documents__c for attachment retrieval; nullable
    * @param ServiceReqId   Set of Service Request Ids for SR context lookup; nullable
    */
    public static void sendRegistertNotifications(String srCustomer, String tskId, Map<String, Documents__c> docMap, Set<Id> ServiceReqId) {
        String contentDocumentId;
        Id docID;
        List<ID> docids = new List<ID>();
        
        // Fetch Service Request details
        Map<Id, ServiceRequest__c> srRecordMap = getServiceRequestMap(ServiceReqId);
        
        Id serviceRequestId;
        Date completionDate;
        
        if (!srRecordMap.isEmpty()) {
            for (ServiceRequest__c sr : srRecordMap.values()) {
                serviceRequestId = sr.Id;
                completionDate = sr.CloseDate__c;
                break;  // Only taking the first ServiceRequest__c for this email
            }
        }
        
        if (srCustomer != null ) {
            if (docMap != null && docMap.containsKey('ADM Registration Document')) {
                docID = docMap.get('ADM Registration Document').Id;
            }
            
            if (docID != null) {
                List<ContentDocumentLink> docLinks = [
                    SELECT ContentDocumentId 
                    FROM ContentDocumentLink 
                    WHERE LinkedEntityId = :docID 
                    LIMIT 1
                ];
                if (!docLinks.isEmpty()) {
                    contentDocumentId = docLinks[0].ContentDocumentId;
                }
            }
            
            if (contentDocumentId != null) {
                ContentVersion cv = [
                    SELECT Id, Title, VersionData 
                    FROM ContentVersion 
                    WHERE ContentDocumentId = :contentDocumentId 
                    ORDER BY CreatedDate DESC 
                    LIMIT 1
                ];
                docids.add(cv.Id);
            }
        }
        
        Map<String, Id> templateNameToIdMap = new Map<String, Id>();
        for (EmailTemplate tem : [SELECT Id, DeveloperName FROM EmailTemplate WHERE DeveloperName IN ('ADM_Registration_completion_email','New_Task_Creation')]) {
            templateNameToIdMap.put(tem.DeveloperName, tem.Id);
        }
        
        List<Messaging.SingleEmailMessage> emailsToSend = new List<Messaging.SingleEmailMessage>();
        List<EmailMessage> emailMessages = new List<EmailMessage>();
        if (srCustomer != null && srCustomer != '') {
            for (Account relatedAcc : [
                SELECT Id, PersonContactId,OwnerId, IsPersonAccount, Owner.Profile.Name, Owner.Email, PersonEmail, Name
                FROM Account 
                WHERE Id = :srCustomer
            ]) {
                if (relatedAcc.PersonEmail != null && relatedAcc.IsPersonAccount) {
                    Messaging.SingleEmailMessage email = getSingleEmail(
                        relatedAcc.PersonEmail, 
                        null,
                        relatedAcc.PersonContactId,  // Set WhatId for merge fields
                        serviceRequestId,
                        templateNameToIdMap.get('ADM_Registration_completion_email'), 
                        docids
                    );
                    Map<String, String> keyByValue = getEmailContent(
                        templateNameToIdMap.get('ADM_Registration_completion_email'), 
                        relatedAcc.OwnerId, 
                        serviceRequestId);
                    emailsToSend.add(email);
                    system.debug(keyByValue.get('Subject'));
                    emailMessages.add(getEmailMessage(
                        relatedAcc.PersonEmail, 
                        keyByValue.ContainsKey('Subject') ? keyByValue.get('Subject') : '', 
                        keyByValue.ContainsKey('PlainBody') ? keyByValue.get('PlainBody') : '', 
                        keyByValue.ContainsKey('HtmlBody') ? keyByValue.get('HtmlBody') : '',
                        serviceRequestId,
                        docids != null ? String.join(docids, ',' ) : ''
                    )); 
                } else { 
                    for (Contact relatedCon : [
                        SELECT Id, OwnerId, Owner.Profile.Name, Owner.Email, Email
                        FROM Contact 
                        WHERE Is_Active__c = TRUE AND AccountId = :srCustomer
                    ]) {
                        if (relatedCon.Email != null) {
                            Messaging.SingleEmailMessage email = getSingleEmail(
                                relatedCon.Email, 
                                
                                null,
                                relatedCon.Id ,  // Set WhatId for merge fields
                                serviceRequestId, 
                                templateNameToIdMap.get('ADM_Registration_completion_email'), 
                                docids
                            );
                            Map<String, String> keyByValue = getEmailContent(
                                templateNameToIdMap.get('ADM_Registration_completion_email'), 
                                relatedCon.Id, 
                                serviceRequestId);
                            emailsToSend.add(email);
                            system.debug(keyByValue.get('Subject'));
                            emailMessages.add(getEmailMessage(
                                relatedCon.Email, 
                                keyByValue.ContainsKey('Subject') ? keyByValue.get('Subject') : '', 
                                keyByValue.ContainsKey('PlainBody') ? keyByValue.get('PlainBody') : '',
                                keyByValue.ContainsKey('HtmlBody') ? keyByValue.get('HtmlBody') : '',
                                serviceRequestId,
                                docids != null ? String.join(docids, ',' ) : ''
                            ));   
                        }
                    }
                }
            }
        }
        
        if (tskId != null && tskId != '') {
            for (User usr : [
                SELECT Id, Email 
                FROM User 
                WHERE Id  = :tskId
            ]) {
                Messaging.SingleEmailMessage singleEmail = getSingleEmail(
                    usr.Email, 
                    null,
                    serviceRequestId,  // Set WhatId for merge fields
                    usr.Id, 
                    templateNameToIdMap.get('New_Task_Creation'), 
                    docids
                );
                Map<String, String> keyByValue = getEmailContent(
                    templateNameToIdMap.get('New_Task_Creation'), 
                    usr.Id, 
                    serviceRequestId);
                emailsToSend.add(getSingleEmail(
                    usr.Email, 
                    null, 
                    usr.Id,  // Set WhatId for merge fields
                    serviceRequestId,
                    templateNameToIdMap.get('New_Task_Creation'), 
                    docids
                ));
                emailMessages.add(getEmailMessage(
                    usr.Id, 
                    keyByValue.ContainsKey('Subject') ? keyByValue.get('Subject') : '', 
                    keyByValue.ContainsKey('PlainBody') ? keyByValue.get('PlainBody') : '',
                    keyByValue.ContainsKey('HtmlBody') ? keyByValue.get('HtmlBody') : '',
                    serviceRequestId,
                    docids != null ? String.join(docids, ',' ) : ''
                )); 
                system.debug(keyByValue.get('Subject'));
            }
        }
        
        if (!emailsToSend.isEmpty() && system.Label.EmailCheck =='true' && !Test.isRunningTest()) {
            System.debug('Sending Emails: ' + emailsToSend);
            Messaging.sendEmail(emailsToSend);
            if(!emailMessages.isEmpty()) {
                insert emailMessages; // Insert EmailMessage records if needed
            }
        }
    }
    /**
    * @description Constructs an EmailMessage SObject record for storing sent email details
    *              against a Service Request. Used for email tracking and audit purposes.
    * @param toAddress    Recipient email address
    * @param subject      Email subject line
    * @param plainBody    Plain text email body
    * @param htmlBody     HTML email body
    * @param relatedToId  Id of the related Service Request to associate the email message with
    * @param attachments  Comma-separated list of ContentVersion Ids for attachments; nullable
    * @return  Constructed EmailMessage record (not yet inserted)
    */
    @TestVisible
    private static EmailMessage getEmailMessage(String toAddress, String subject, String plainBody, String htmlBody, String relatedToId, String attachments) {
        EmailMessage email = new EmailMessage(); 
        email.ToAddress = toAddress;
        email.Subject = subject != null ? subject : '-';
        email.TextBody= plainBody;
        email.HtmlBody= htmlBody;
        email.RelatedToId = relatedToId; // Associate with the Service Request
        email.Status = '3'; // Sent
        email.FromAddress = 'noreply@modon.com';
        email.Attachments__c = attachments != null ? attachments : ''; // Assuming attachments is a comma-separated list of ContentDocument IDs
        
        return email;
    }
    /**
    * @description Renders a stored email template for a given target object and related record,
    *              returning the subject, plain text body, and HTML body as a key-value map.
    *              Used to extract email content before sending or inserting EmailMessage records.
    * @param templateId  Id of the EmailTemplate to render
    * @param targetId    Id of the target object (Contact or User) for merge field resolution
    * @param whatId      Id of the related object (e.g., Service Request) for merge field resolution
    * @return  Map with keys 'Subject', 'PlainBody', and 'HtmlBody' containing rendered content
    */
    @TestVisible
    private static Map<String, String> getEmailContent(Id templateId, Id targetId, Id whatId) {
        Map<String, String> keyByValue = new Map<String, String>();
        Messaging.SingleEmailMessage email = Messaging.renderStoredEmailTemplate(templateId, targetId, whatId);
        keyByValue.put('PlainBody', email.getPlainTextBody());
        keyByValue.put('HtmlBody', email.getHtmlBody());
        keyByValue.put('Subject', email.getSubject());
        return keyByValue;
    }
    /**
    * @description Retrieves an EmailTemplate record by Id, including its body, subject, and HTML value.
    * @param templateId  Id of the EmailTemplate to retrieve
    * @return  EmailTemplate record with Id, Name, body, Subject, and HTMLvalue fields
    */
    @TestVisible
    private static EmailTemplate getTemplate(Id templateId){
        return [SELECT Id, Name, body, Subject, HTMLvalue FROM EmailTemplate WHERE Id =: templateId];
    }
    
    // public static void sendTaskNotification(String subject, String targetObjectId, Id notificationTypeId, String userId){
    
    //     if(notificationTypeId != null) {
    //         Messaging.CustomNotification notification = new Messaging.CustomNotification();
    //         notification.setTitle('New Task Assigned to You: ' + subject);
    //         notification.setBody('You have been assigned a new task in  ' + subject + '.  Please review the task and start working on it at your earliest convenience');
    //         notification.setNotificationTypeId(notificationTypeId);
    //         notification.setTargetId(targetObjectId);
    
    //         notification.send(new Set<String>{userId});
    //     }
    // }
    /**
    * @description Constructs a Messaging.SingleEmailMessage for sending via Apex email,
    *              configured with a stored template, target object, related record, and
    *              optional document attachments. Sets the sender display name to 'Modon Sales Team'.
    * @param userId          Recipient email address string
    * @param ccMail          CC email address; currently unused (commented out)
    * @param targetObjectId  Id of the target Contact or User for template merge field resolution
    * @param serviceReqIds   Id of the related Service Request (WhatId) for merge field resolution
    * @param templateId      Id of the EmailTemplate to use
    * @param docIds          List of ContentVersion Ids to attach to the email; nullable
    * @return  Configured Messaging.SingleEmailMessage ready to send
    */
    public static Messaging.SingleEmailMessage getSingleEmail(String userId, String ccMail, String targetObjectId, id serviceReqIds,String templateId ,list<ID> docIds){
        Messaging.SingleEmailMessage mail =  new Messaging.SingleEmailMessage();
        Id serviceRequestId;
        
        mail.setToAddresses(new String[]{userId});
        //if(String.isNotBlank(ccMail)) mail.setCcAddresses(new String[]{ccMail});
        if (targetObjectId != null) {
            
            mail.setTargetObjectId(targetObjectId);
        }
        if (serviceReqIds!=null) {
            mail.setWhatId(serviceReqIds);
        }
        mail.setSaveAsActivity(false);
        mail.setTemplateId(templateId);// This is template ID
        mail.setSenderDisplayName('Modon Sales Team');
        if(docIds != null && docIds.size()>0 && !docIds.isEmpty()){
            mail.setEntityAttachments(docIds);
        }
        
        return mail;
    }
    /**
    * @description Cancels Charge__c records and their associated Invoice__c records when specific
    *              task status changes occur on Service Request tasks. Uses the
    *              Charges_Cancellation_on_SR__mdt custom metadata to determine which charge names
    *              should be cancelled based on the combination of SR record type, task subject,
    *              and task status. Updates matching charges to 'Cancelled' and marks linked
    *              invoices as cancelled.
    * @param newList  List of updated Task SObjects
    * @param oldMap   Map of old Task SObjects for status change comparison
    */
    public static void cancelServiceRequestCharges(List<SObject> newList, Map<Id, SObject> oldMap){
        system.debug('-cancelServiceRequestCharges------------');
        
        set<Id> serviceRequestId= new Set<Id>();
        set<string> taskStatus= new Set<string>();
        set<string> recordTypeSet= new Set<string>();
        set<string> taskSubjectSet= new Set<string>();
        
        for(Task newTask : (List<Task>)newList){
            
            Task oldRecord = (Task)oldMap.get(newTask.Id);
            if(newTask.WhatId != null && newTask.WhatId.getSObjectType().getDescribe().getName() == 'ServiceRequest__c'
               && oldRecord.Status != newTask.Status && newTask.Status != null
              ){
                  serviceRequestId.add(newTask.whatId);
                  taskStatus.add(newTask.Status);
                  taskSubjectSet.add(newTask.Subject);
              }
        }
        system.debug('-111----taskSubjectSet-------------'+taskSubjectSet);
        
        if(serviceRequestId.size()>0){
            List<ServiceRequest__c>srList = [
                select Id,RecordType.DeveloperName,Type__c,UnitId__r.Phase__c,SalesOrder__c,
                SalesOrder__r.TotalAmount__c,SalesOrder__r.CustomerAccount__c,Penality_Charge__c
                from ServiceRequest__c
                where Id IN:serviceRequestId 
                and SalesOrder__c != null
            ];
            
            Map<string,ServiceRequest__c>srMap = new Map<string,ServiceRequest__c>();
            for(ServiceRequest__c sr : srList){
                if(sr.RecordType.DeveloperName != null){
                    recordTypeSet.add(sr.RecordType.DeveloperName);
                    srMap.put(sr.Id,sr);
                }
            }
            Map<string,Set<string>>chargesCancellationMap = new Map<string,Set<string>>();
            Map<string,Set<string>>srMapChargesCancellation = new Map<string,Set<string>>();
            Set<string> cancelledChargesNames = new Set<string>();
            
            if(taskStatus.size()>0 && recordTypeSet.size()>0 && taskSubjectSet.size()>0){
                system.debug('-taskSubjectSet ------------'+taskSubjectSet );
                system.debug('-recordTypeSet------------'+recordTypeSet);
                system.debug('-taskStatus ------------'+taskStatus);
                
                List<Charges_Cancellation_on_SR__mdt> chargeCancellationList =[
                    select Id,Charges_for_Cancellation__c,SR_RecordType__c,Task_Status__c,Task_Subject__c 
                    from Charges_Cancellation_on_SR__mdt
                    where Task_Subject__c IN:taskSubjectSet and SR_RecordType__c IN:recordTypeSet
                    and SR_RecordType__c != null
                    and Task_Status__c != null 
                    and Task_Status__c IN:taskStatus 
                ];
                
                if(Test.isRunningTest()) {
                    chargeCancellationList.add(new Charges_Cancellation_on_SR__mdt(SR_RecordType__c='Service_Request_Management_ADM', Task_Status__c='Closed', Task_Subject__c='testSubject',
                                                                                   Charges_for_Cancellation__c='Modon Fee'));
                }
                
                for(Charges_Cancellation_on_SR__mdt csm : chargeCancellationList){
                    string chargeKey = csm.SR_RecordType__c +'-'+csm.Task_Subject__c+'-'+csm.Task_Status__c;
                    if(chargesCancellationMap.get(chargeKey)==null)chargesCancellationMap.put(chargeKey,new Set<string>());
                    if(csm.Charges_for_Cancellation__c != null){
                        for(string st : csm.Charges_for_Cancellation__c.split(';')){
                            chargesCancellationMap.get(chargeKey).add(st);
                        }
                    }
                }
                system.debug('-111----chargesCancellationMap-------------'+chargesCancellationMap);
                
                if(chargesCancellationMap.size()>0){
                    
                    for(Task newTask : (List<Task>)newList){
                        Task oldRecord = (Task)oldMap.get(newTask.Id);
                        if(newTask.WhatId != null && newTask.WhatId.getSObjectType().getDescribe().getName() == 'ServiceRequest__c'
                           && oldRecord.Status != newTask.Status && newTask.Status != null
                           && serviceRequestId.contains(newTask.WhatId) && 
                           taskStatus.contains(newTask.Status) &&
                           taskSubjectSet.contains(newTask.Subject)
                          ){
                              
                              string recordTypeName = srMap.containskey(newTask.WhatId) && srMap.get(newTask.WhatId) != null ? srMap.get(newTask.WhatId).RecordType.DeveloperName :'';
                              String salesOrder = srMap.containskey(newTask.WhatId) && srMap.get(newTask.WhatId) != null ? srMap.get(newTask.WhatId).SalesOrder__c :'';
                              
                              if(recordTypeName != '' && salesOrder != null && salesOrder !=''){
                                  string chargeKey = recordTypeName +'-'+newTask.Subject+'-'+newTask.Status;
                                  if(chargesCancellationMap.containskey(chargeKey) && chargesCancellationMap.get(chargeKey) != null){
                                      
                                      string chargeKeySalesOrder = salesOrder + recordTypeName +'-'+newTask.Subject+'-'+newTask.Status;
                                      if(srMapChargesCancellation.get(salesOrder)==null)srMapChargesCancellation.put(salesOrder,new Set<string>());
                                      Set<string> alreadyAdded = srMapChargesCancellation.get(salesOrder);
                                      for(string ss : chargesCancellationMap.get(chargeKey)){
                                          alreadyAdded.add(ss);
                                          cancelledChargesNames.add(ss);
                                      }
                                      srMapChargesCancellation.put(salesOrder,alreadyAdded);
                                  }
                              }
                          }
                    }
                    if(cancelledChargesNames.size()>0){
                        List<Charge__c>updateChargeList = new List<Charge__c>();
                        List<Invoice__c>invList = new List<Invoice__c>();
                        List<Charge__c>chargeList = [select Id,Name,Amount__c,Paid_Amount__c,PaymentStatus__c,Remaining_Amount__c,
                                                     Sales_Order__c,Type__c,VAT_Amount__c,
                                                     (select Id,isCancelled__c from Invoices__r where isCancelled__c = false)
                                                     from Charge__c where Sales_Order__c != null and Sales_Order__c IN: srMapChargesCancellation.keyset()
                                                     order by Sales_Order__c asc
                                                    ];
                        Set<string>chargesIds = new Set<string>();
                        
                        for(Charge__c charge  : chargeList){
                            Set<string> alreadyAdded = 
                                srMapChargesCancellation.containskey(charge.Sales_Order__c) && 
                                srMapChargesCancellation.get(charge.Sales_Order__c) != null ? srMapChargesCancellation.get(charge.Sales_Order__c) : new Set<string>();
                            
                            if(alreadyAdded.contains(charge.Name) && !chargesIds.contains(charge.Id)){
                                
                                chargesIds.add(charge.Id);  
                                updateChargeList.add(new Charge__c(Id = charge.Id, PaymentStatus__c='Cancelled'));
                                for(Invoice__c inv : charge.Invoices__r){
                                    invList.add(new Invoice__c(Id = inv.Id,isCancelled__c = true));
                                }
                            }                           
                        }
                        system.debug('-111----updateChargeList-------------'+updateChargeList);
                        if(updateChargeList.size()>0){
                            update updateChargeList;
                            system.debug('--2222---updateChargeList-------------'+updateChargeList);
                        }
                        system.debug('-111----invList-------------'+invList);
                        if(invList.size()>0){
                            update invList;
                            system.debug('--2222---invList-------------'+invList);
                        }
                    }
                }
            }
        }
    }
    /**
    * @description Creates manual sharing records (ServiceRequest__Share and SalesOrder__Share)
    *              for the given Service Request and Sales Order Ids, granting 'Edit' access to
    *              SR records and 'Read' access to Sales Order records for the public group
    *              defined in the publicgroupId custom label.
    * @param srIds   Set of Service Request Ids to share
    * @param soIds   Set of Sales Order Ids to share
    */
    @TestVisible 
    private static void createShareRecord(set<Id> srIds,set<Id>soIds){
        List<ServiceRequest__Share> srShareList = new List<ServiceRequest__Share>();
        List<SalesOrder__Share> soShareList = new List<SalesOrder__Share>();
        list<string> publicgroupId = System.label.publicgroupId.split(',');
        
        for(Id sr:srIds){
            ServiceRequest__Share srShare = new ServiceRequest__Share();
            srShare.ParentId = sr; // 
            srShare.UserOrGroupId = publicgroupId[0]; // Assign to Queue
            srShare.AccessLevel = 'Edit'; // Options: Read, Edit, All
            srShare.RowCause = Schema.ServiceRequest__Share.RowCause.Manual; 
            srShareList.add(srShare);
        }
        
        if(srShareList.size()>0 && !srShareList.isEmpty()){
            insert srShareList;
        }
        
        for(Id so:soIds){
            SalesOrder__Share soShare = new SalesOrder__Share();
            soShare.ParentId = so; // 
            soShare.UserOrGroupId = publicgroupId[0]; // Assign to Queue
            soShare.AccessLevel = 'Read'; // 
            soShare.RowCause = Schema.SalesOrder__Share.RowCause.Manual;
            soShareList.add(soShare);
        }
        
        System.debug('soShareList-->'+soShareList);
        if(soShareList.size()>0 && !soShareList.isEmpty()){
            insert soShareList;
        }
        System.debug('srShareList-->'+soShareList);
    }
    /**
    * @description Updates the Call_Task_Status__c field on Lead records when a task related to
    *              a Lead is created or updated. Identifies tasks linked to Leads (WhoId prefix '00Q')
    *              with subjects containing 'Call Task 1', 'Call Task 2', or 'Call Task 3', and
    *              bulk updates the corresponding Lead records with the matched status value.
    * @param newList  List of Task SObjects being inserted or updated
    */
    public static void updateLeadCallTaskStatus(List<SObject> newList) {
        Map<Id, String> leadIdToTaskStatusMap = new Map<Id, String>();
        
        for (Task task : (List<Task>) newList) {
            if (task.WhoId != null && String.valueOf(task.WhoId).startsWith('00Q')) { // Lead ID prefix
                if (task.Subject != null) {
                    if (task.Subject.containsIgnoreCase('Call Task 1')) {
                        leadIdToTaskStatusMap.put(task.WhoId, 'Call Task 1');
                    } else if (task.Subject.containsIgnoreCase('Call Task 2')) {
                        leadIdToTaskStatusMap.put(task.WhoId, 'Call Task 2');
                    } else if (task.Subject.containsIgnoreCase('Call Task 3')) {
                        leadIdToTaskStatusMap.put(task.WhoId, 'Call Task 3');
                    }
                }
            }
        }
        
        if (!leadIdToTaskStatusMap.isEmpty()) {
            List<Lead> leadsToUpdate = new List<Lead>();
            for (Id leadId : leadIdToTaskStatusMap.keySet()) {
                leadsToUpdate.add(new Lead(
                    Id = leadId,
                    Call_Task_Status__c = leadIdToTaskStatusMap.get(leadId)
                ));
            }
            update leadsToUpdate;
        }
    }
    /**
    * @description Validates that all documents specified in a ServiceAction's
    *              DocumentsValidationAtClosure__c field have been uploaded to the Service Request
    *              before the associated task can be closed. Fetches required document names from
    *              the ServiceAction configuration, compares them against uploaded Documents__c
    *              records on the SR, and adds a field-level error on the task listing all missing
    *              document names if any are not yet uploaded.
    * @param newList  List of Task SObjects being updated
    * @param oldMap   Map of old Task SObjects for status change comparison
    */
    public static void documentValidationOfSR(List<SObject> newList, Map<Id, SObject> oldMap) {
        
        Set<Id> srIds = new Set<Id>();
        Set<Id> actionIds = new Set<Id>();
        Map<Id, Id> taskToSrMap = new Map<Id, Id>();
        
        // Step 1: Collect relevant SR and Action Ids
        for (Task newTask : (List<Task>) newList) {
            if (
                newTask.WhatId != null &&
                newTask.WhatId.getSObjectType() == ServiceRequest__c.SObjectType &&
                newTask.ServiceAction__c != null &&
                oldMap.containsKey(newTask.Id) &&
                newTask.Status == Constants.TASK_STATUS_CLOSED &&
                ((Task) oldMap.get(newTask.Id)).Status != newTask.Status
            ) {
                srIds.add((Id)newTask.WhatId);
                actionIds.add(newTask.ServiceAction__c);
                taskToSrMap.put(newTask.Id, (Id)newTask.WhatId);
            }
        }
        system.debug('--documentValidationOfSR------srIds-----------'+srIds);
        system.debug('---documentValidationOfSR-----actionIds-----------'+actionIds);
        system.debug('---documentValidationOfSR-----taskToSrMap-----------'+srIds);
        
        if (actionIds.isEmpty()) return;
        
        // Step 2: Fetch required documents from ServiceActions
        Map<Id, List<String>> actionToRequiredDocsMap = new Map<Id, List<String>>();
        Set<String> allRequiredDocNames = new Set<String>();
        
        for (ServiceAction__c action : [
            SELECT Id, DocumentsValidationAtClosure__c
            FROM ServiceAction__c
            WHERE Id IN :actionIds
        ]) {
            if(action.DocumentsValidationAtClosure__c != null){
                List<String> docs = new List<String>();
                for (String docName : action.DocumentsValidationAtClosure__c.split(';')) {
                    if (!String.isBlank(docName)) {
                        String trimmed = docName.trim();
                        docs.add(trimmed);
                        allRequiredDocNames.add(trimmed);
                    }
                }
                if (!docs.isEmpty()) {
                    actionToRequiredDocsMap.put(action.Id, docs);
                }
            }
        }
        system.debug('--documentValidationOfSR------actionToRequiredDocsMap-----------'+actionToRequiredDocsMap);
        
        if (actionToRequiredDocsMap.isEmpty() || allRequiredDocNames.isEmpty()) return;
        
        // Step 3: Fetch already uploaded documents
        Map<Id, Set<String>> srToUploadedDocsMap = new Map<Id, Set<String>>();
        
        for (Documents__c doc : [
            SELECT Id, Name, Service_Request__c
            FROM Documents__c
            WHERE Service_Request__c IN :srIds
            AND Status__c = 'Uploaded'
            AND Name IN :allRequiredDocNames and 
            Service_Request__c != null
        ]) {
            if (!srToUploadedDocsMap.containsKey(doc.Service_Request__c)) {
                srToUploadedDocsMap.put(doc.Service_Request__c, new Set<String>());
            }
            srToUploadedDocsMap.get(doc.Service_Request__c).add(doc.Name.trim());
        }
        // Step 4: Validate and add errors if required documents are missing
        system.debug('--documentValidationOfSR------srToUploadedDocsMap-----------'+srToUploadedDocsMap);
        
        for (Task newTask: (List<Task>)newList)
        {
            if(
                newTask.WhatId != null && srIds.size()>0 && srIds.contains(newTask.WhatId) &&
                newTask.ServiceAction__c != null && 
                taskToSrMap.containskey(newTask.Id) &&
                actionToRequiredDocsMap.containskey(newTask.ServiceAction__c) &&
                actionToRequiredDocsMap.get(newTask.ServiceAction__c) != null
            ){
                Set<String> uploadedSRSet = srToUploadedDocsMap.containskey(newTask.WhatId) &&  srToUploadedDocsMap.get(newTask.WhatId) != null ? srToUploadedDocsMap.get(newTask.WhatId) : new Set<String>();
                system.debug('--documentValidationOfSR------configured docs-------uploadedSRSet ----'+uploadedSRSet );
                
                string missingDocs ='';
                for(String docsName : actionToRequiredDocsMap.get(newTask.ServiceAction__c)){
                    system.debug('--documentValidationOfSR------configured docs-----------'+docsName);
                    String trimmedDocName = docsName.trim();
                    if(!uploadedSRSet.contains(trimmedDocName)){
                        missingDocs += (missingDocs != '') ? ','+trimmedDocName : trimmedDocName;
                    }
                }
                system.debug('--documentValidationOfSR------missingDocs-----------'+missingDocs);
                
                if(missingDocs != ''){
                    newTask.addError('Please upload the following document(s): ' + missingDocs);
                }
            }
        }
    }
    /**
    * @description Updates the Status__c of related Registration__c records to 'Draft' when a task
    *              subject changes to 'Require more information' on update. Identifies Service
    *              Requests where this subject change occurred, finds their linked Registration
    *              records, and bulk updates them to reflect the pending information state.
    * @param newList  List of Task SObjects being updated
    * @param oldMap   Map of old Task SObjects for subject change comparison
    */
    public static void updateRegistrationStatusForRequireInfoTask(List<SObject> newList, Map<Id, SObject> oldMap) {
        List<Task> newTasks = (List<Task>) newList;
        Set<Id> relevantSRIds = new Set<Id>(); 
        for (Task newTask : newTasks) {
            system.debug('newTask:::'+newTask);
            if (newTask.WhatId != null && newTask.WhatId.getSObjectType().getDescribe().getName() == 'ServiceRequest__c') {
                
                
                Task oldTask = (Task) oldMap.get(newTask.Id);
                
                system.debug('oldTask:::'+oldTask);
                system.debug('oldTask.Subject:::'+oldTask.Subject);
                system.debug('newTask.Subject:::'+newTask.Subject);
                
                if (oldTask != null && oldTask.Subject != 'Require more information' && newTask.Subject == 'Require more information') {
                    relevantSRIds.add((Id)newTask.WhatId);  
                }
            }
        }
        system.debug('relevantSRIds::'+relevantSRIds);
        system.debug('newTasks::'+newTasks);
        if (!relevantSRIds.isEmpty()) {
            List<ServiceRequest__c> srList = [
                SELECT Id, Registration__c 
                FROM ServiceRequest__c 
                WHERE Id IN :relevantSRIds AND Registration__c != NULL
            ];
            Set<Id> registrationIds = new Set<Id>();
            for (ServiceRequest__c sr : srList) {
                registrationIds.add(sr.Registration__c);
            }
            List<Registration__c> registrationsToUpdate = new List<Registration__c>();
            for (Registration__c reg : [
                SELECT Id, Status__c 
                FROM Registration__c 
                WHERE Id IN :registrationIds
            ]) {
                reg.Status__c = 'Draft';
                registrationsToUpdate.add(reg);
            }
            
            system.debug('registrationsToUpdate::'+registrationsToUpdate);
            if (!registrationsToUpdate.isEmpty()) {
                update registrationsToUpdate;  
            }
        } 
    } 
    /**
    * @description Handles newly inserted tasks with the subject 'Require more information' by
    *              updating the associated Registration__c records to 'Draft' status. Only updates
    *              Registration records that are not currently 'In Progress'. Used as the insert
    *              counterpart to updateRegistrationStatusForRequireInfoTask.
    * @param newTasks  List of newly inserted Task records
    */
    public static void handleRequireMoreInfoTasks_Insert(List<Task> newTasks) {
        Set<Id> relevantSRIds = new Set<Id>();
        for (Task task : newTasks) {
            if (task.Subject == 'Require more information' &&
                task.WhatId != null &&
                task.WhatId.getSObjectType().getDescribe().getName() == 'ServiceRequest__c') {
                    relevantSRIds.add((Id) task.WhatId);
                }
        }
        if (!relevantSRIds.isEmpty()) {
            List<ServiceRequest__c> srList = [
                SELECT Id, Registration__c 
                FROM ServiceRequest__c 
                WHERE Id IN :relevantSRIds AND Registration__c != NULL
            ];
            Set<Id> registrationIds = new Set<Id>();
            for (ServiceRequest__c sr : srList) {
                registrationIds.add(sr.Registration__c);
                System.debug(' Found Registration Id: ' + sr.Registration__c + ' for SR: ' + sr.Id);
            }
            List<Registration__c> registrationsToUpdate = new List<Registration__c>();
            for (Registration__c reg : [
                SELECT Id, Status__c 
                FROM Registration__c 
                WHERE Id IN :registrationIds
            ]) {
                if (reg.Status__c != 'In Progress') {
                    reg.Status__c = 'Draft';
                    registrationsToUpdate.add(reg);
                } 
            }
            if (!registrationsToUpdate.isEmpty()) {
                update registrationsToUpdate;  
            }
        } 
    }
    
    /**
    * @description Sends an email notification to broker company contacts and registered agents
    *              when a Broker Registration task is set to 'Require more Information' status.
    *              Applies to specific task subjects (Assignment of Broker Manager, Validation by
    *              Compliance Team, Validation by Broker Sales Admin). The email includes the task
    *              description as the required-information comment and a link to the Broker portal.
    *              Uses SendGrid for email delivery via BP_SendGridUtilityClass.
    * @param newTasks  List of Task records being inserted or updated
    */
    
    public static void handleRequireMoreInfoTaskEmail(List<Task> newTasks) {
        Map<Id, Task> srToTaskMap = new Map<Id, Task>();
        
        List<String> validSubjects = new List<String>{
            'Assignment of Broker Manager',
                'Validation by Compliance Team',
                'Validation by Broker Sales Admin'
                };
                    
                    for (Task t : newTasks) {
                        if (t.WhatId != null &&
                            validSubjects.contains(t.Subject) &&
                            t.Broker_Registration_Status__c == 'Require more Information' &&
                            t.Description != null) {
                                srToTaskMap.put(t.WhatId, t);
                            }
                    }
        
        if (srToTaskMap.isEmpty()) return;
        
        List<ServiceRequest__c> eligibleSRs = [
            SELECT Id, Registration__c,
            Registration__r.Company_Email_Address__c,
            Registration__r.Company_Name_as_per_Trade_License__c,
            Registration__r.Trade_License_Number__c
            FROM ServiceRequest__c
            WHERE Id IN :srToTaskMap.keySet()
            AND Registration__c != null
            AND RecordType.Name = 'Broker Registration'
        ];
        
        if (eligibleSRs.isEmpty()) return;
        
        Set<Id> registrationIds = new Set<Id>();
        for (ServiceRequest__c sr : eligibleSRs) {
            registrationIds.add(sr.Registration__c);
        }
        
        Map<Id, List<Registration_Agent__c>> registrationAgentsMap = new Map<Id, List<Registration_Agent__c>>();
        if (!registrationIds.isEmpty()) {
            List<Registration_Agent__c> allAgents = [
                SELECT Id, Agent_Email__c, Registration_Name__c
                FROM Registration_Agent__c
                WHERE Registration_Name__c IN :registrationIds
                AND Agent_Email__c != null
            ];
            
            for (Registration_Agent__c agent : allAgents) {
                if (!registrationAgentsMap.containsKey(agent.Registration_Name__c)) {
                    registrationAgentsMap.put(agent.Registration_Name__c, new List<Registration_Agent__c>());
                }
                registrationAgentsMap.get(agent.Registration_Name__c).add(agent);
            }
        }
        
        Set<String> allEmailAddresses = new Set<String>();
        String emailBody = '';
        
        for (ServiceRequest__c sr : eligibleSRs) {
            Task relatedTask = srToTaskMap.get(sr.Id);
            if (relatedTask == null) continue;
            
            if (String.isNotBlank(sr.Registration__r.Company_Email_Address__c)) {
                allEmailAddresses.add(sr.Registration__r.Company_Email_Address__c);
            }
            
            if (registrationAgentsMap.containsKey(sr.Registration__c)) {
                for (Registration_Agent__c agent : registrationAgentsMap.get(sr.Registration__c)) {
                    allEmailAddresses.add(agent.Agent_Email__c);
                }
            }
            
            emailBody = 'Dear Partner,<br><br>' +
                'Thank you for your registration.<br>' +
                'To complete the verification process, we require additional information related to your broker registration.<br><br>' +
                '<strong>Comments:</strong> ' + relatedTask.Description + '<br><br>' +
                'Kindly review the above comments and provide the requested details at your earliest convenience.<br>' +
                'Please log in using the link below to update the necessary information:<br>' +
                '<a href="https://modonproperties.my.site.com/Brokers/">https://modonproperties.my.site.com/Brokers/</a><br><br>' +
                'This is an automated notification. Please do not reply to this email.<br><br>' +
                'Best regards,<br>' +
                'Broker Management Team';
            
            break;
        }
        
        if (allEmailAddresses.isEmpty()) return;
        
        List<Map<String, Object>> toList = new List<Map<String, Object>>();
        for (String email : allEmailAddresses) {
            toList.add(new Map<String, Object>{'email' => email});
        }
        
        String personalizationsEntry = JSON.serialize(new List<Object>{
            new Map<String, Object>{'to' => toList}
        });
        
        String subject = 'Additional Information Required for Your Registration';
        String emailHtml = MBP_ModonEmailUtilityClass.getFullEmailHtml(emailBody);
        
        BP_SendGridUtilityClass.sendEmail(personalizationsEntry, 'Al Naseem', subject, emailHtml, true);
    }
    
    /**
    * @description Updates the OwnerId of newly created Task records to match the OwnerId of the
    *              related Service Request, but only when the associated ServiceAction__c has the
    *              IsOwnerUpdatedFromSR__c flag set to true. Processes tasks in bulk by first
    *              identifying qualifying ServiceActions and SR owners, then applying the owner
    *              reassignment directly on the task records in-memory (before insert/update DML).
    * @param newList  List of Task SObjects being inserted
    * @param newMap   Map of Task Id to Task SObject (unused directly, available for reference)
    */
    public static void updateTaskOwnerFromSR(List<SObject> newList, Map<Id, SObject> newMap) {
        
        System.debug('TaskTriggerHelper >>>> updateTaskOwnerFromSR >>');
        
        Set<Id> srIds = new Set<Id>(); // ServiceRequest Ids
        Set<Id> actionIds = new Set<Id>();
        
        for (Task task : (List<Task>) newList) {
            if (
                String.isNotBlank(task.WhatId) &&
                task.WhatId.getSObjectType ().getDescribe ().getName() == 'ServiceRequest__c' &&
                task.ServiceAction__c != null
            ) {
                srIds.add(task.WhatId);
                actionIds.add(task.ServiceAction__c);
            }
        }
        
        if (actionIds.isEmpty()) {
            return; // No valid actions, exit early
        }
        
        // Get ServiceActions where owner should be updated from SR
        Set<Id> actionIdsToUpdate = new Set<Id>();
        for (ServiceAction__c action : [
            SELECT Id
            FROM ServiceAction__c
            WHERE Id IN :actionIds AND IsOwnerUpdatedFromSR__c = true
        ]) {
            actionIdsToUpdate.add(action.Id);
        }
        
        if (actionIdsToUpdate.isEmpty()) {
            return; // No matching ServiceActions, exit early
        }
        
        // Get ServiceRequest OwnerId map
        Map<Id, Id> srOwnerMap = new Map<Id, Id>();
        for (ServiceRequest__c sr : [
            SELECT Id, OwnerId
            FROM ServiceRequest__c
            WHERE Id IN :srIds
        ]) {
            if (sr.OwnerId != null) {
                srOwnerMap.put(sr.Id, sr.OwnerId);
            }
        }
        
        // Update Task owner based on SR
        for (Task task : (List<Task>) newList) {
            if (
                task.ServiceAction__c != null &&
                actionIdsToUpdate.contains(task.ServiceAction__c) &&
                srOwnerMap.containsKey(task.WhatId)
            ) {
                task.OwnerId = srOwnerMap.get(task.WhatId);
                System.debug('TaskTriggerHelper >>Task owner based on SR>> updateTaskOwnerFromSR >>'+task.OwnerId);
                
            }
        }
    }
    
    /** Update  1.2 Version Starts Here 
    *Description : on Broker service request record if step1 is Approved we are creating a passfort transcation record for 
    that service request's registration record and following the proedure of passfort transaction.
    * Notes      : Added on 24-12-2025. Fetches related broker SR,broker registration record,broker registration record Documents ,
    *               creates Passfort transaction parent record, and creates each document of registration record as a child
    of the parent passfort transaction.
    */
    
    
    public static void createPassfortTransactionsForBrokerRegistration(Set<Id> serviceRequestIds) {
        try {
            
            List<ServiceRequest__c> brokerRegistrationSRs = [
                SELECT Id, Registration__c
                FROM ServiceRequest__c 
                WHERE Id IN :serviceRequestIds 
                AND RecordType.DeveloperName =: constants.BROKER_REGISTRATION_RECORDTYPE
                AND Registration__c != null
            ];
            if (brokerRegistrationSRs.isEmpty()) return;
            
            
            Set<Id> registrationIds = new Set<Id>();
            for (ServiceRequest__c sr : brokerRegistrationSRs) {
                if (sr.Registration__c != null) registrationIds.add(sr.Registration__c);
            }
            if (registrationIds.isEmpty()) return;
            
            Map<Id, List<Documents__c>> registrationToDocumentsMap = new Map<Id, List<Documents__c>>();
            for (Documents__c doc : [
                SELECT Id, Name, Status__c, Registration__c
                FROM Documents__c
                WHERE Registration__c IN :registrationIds
                AND Status__c = 'Uploaded'
            ]) {
                if (!registrationToDocumentsMap.containsKey(doc.Registration__c)) {
                    registrationToDocumentsMap.put(doc.Registration__c, new List<Documents__c>());
                }
                registrationToDocumentsMap.get(doc.Registration__c).add(doc);
            }
            
            /* Update Version 1.3 Starts Here 
            @description: 
            *Added The Logic Of emirtes and passfort Of registration Agents of the Related registration 
            * to the Existing Passfort Flow These will also be Created as Child Passfort Transactions 
            */
            Map<Id, Id> agentToRegMap = new Map<Id, Id>();
            Set<Id> agentIds = new Set<Id>();
            
            for (Registration_Agent__c agent : [
                SELECT Id, Registration_Name__c
                FROM Registration_Agent__c
                WHERE Registration_Name__c IN :registrationIds and  Type__c = 'Owner'
            ]) {
                agentIds.add(agent.Id);
                agentToRegMap.put(agent.Id, agent.Registration_Name__c);
            }
            
            if (!agentIds.isEmpty()) {
                for (Documents__c doc : [
                    SELECT Id, Name, Status__c, Registration_Agent__c
                    FROM Documents__c
                    WHERE Registration_Agent__c IN :agentIds
                    AND Status__c = 'Uploaded'
                    AND Name IN ('Passport Document','Emirates Document')
                ]) {
                    Id regId = agentToRegMap.get(doc.Registration_Agent__c);
                    if (regId != null) {
                        if (!registrationToDocumentsMap.containsKey(regId)) {
                            registrationToDocumentsMap.put(regId, new List<Documents__c>());
                        }
                        registrationToDocumentsMap.get(regId).add(doc);
                    }
                }
            }
            // Update version 1.3 ends Here 
            
            List<PassfortTransaction__c> parentTransactions = new List<PassfortTransaction__c>();
            for (ServiceRequest__c sr : brokerRegistrationSRs) {
                
                if (sr.Registration__c == null) continue;
                
                PassfortTransaction__c parentTransaction = new PassfortTransaction__c(
                    Registration__c = sr.Registration__c,
                    EntityType__c = Constants.PASSFORT_TR_TYPE_COMPANY,
                    TransactionId__c = 'BR_' + String.valueOf(sr.Registration__c) + '_' + String.valueOf(DateTime.now().getTime())
                );
                
                if (registrationToDocumentsMap.containsKey(sr.Registration__c)) {
                    List<String> docIds = new List<String>();
                    for (Documents__c d : registrationToDocumentsMap.get(sr.Registration__c)) {
                        docIds.add(String.valueOf(d.Id));
                    }
                    if (!docIds.isEmpty()) {
                        parentTransaction.ParentDocumentIds__c = String.join(docIds, ',');
                    }
                }
                parentTransactions.add(parentTransaction);
            }
            
            if (!parentTransactions.isEmpty()) {
                insert parentTransactions;
                
            }
        } catch (Exception e) {
            System.debug('Error creating Passfort Transactions For Broker Registration: ' + e.getMessage());
        }
    }
    
    //Update 1.2 Version Ends Here
    
    /*
    This Is the new chnage to update step order and step name on service request level
    */
    private static void updateCurrentStepOnSR(List<Task> taskList) {
        system.debug('updateCurrentStepOnSR');
        
        Set<Id> srIds = new Set<Id>();
        
        for (Task t : taskList) {
            
            if (t.WhatId != null && t.WhatId.getSObjectType() == ServiceRequest__c.SObjectType) {
                srIds.add(t.WhatId);
            }
        }
        
        if (srIds.isEmpty()) //1.5 start
            return;
        Map<Id, ServiceRequest__c> srMap = new Map<Id, ServiceRequest__c>([SELECT Id,RecordType.DeveloperName,RecordType.Name FROM ServiceRequest__c WHERE Id IN :srIds]);
        
        List<ServiceRequest__c> srUpdates = new List<ServiceRequest__c>();
        for (Task t : taskList) {
            if (!srMap.containsKey(t.WhatId))
                continue;
            
            ServiceRequest__c sr = srMap.get(t.WhatId);
            
            // IMPORTANT CONDITION
            if (sr.RecordType.Name != Constants.SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER)
                continue;
            
            
            ServiceRequest__c updateSR = new ServiceRequest__c();
            updateSR.Id = sr.Id;
            updateSR.Step_Order__c = t.Order__c;
            updateSR.Step_Name__c = t.Subject;
            srUpdates.add(updateSR);
        }
        
        if (!srUpdates.isEmpty()) {
            update srUpdates;
            System.debug('Updated Step Tracking for SRs: ' + srUpdates);
        } //1.5 end
    }
     //1.5 Add logic
    private static Map<Id, Integer> ddCountcheck = new Map<Id, Integer>();
    private static Map<Id, Integer> admCountcheck = new Map<Id, Integer>();
    
    @TestVisible
    private static Decimal handlePreunitCancellationStepSkip(Decimal nextOrder,Integer completedTaskOrder,ServiceRequest__c sr) {
        if (sr == null || sr.SalesOrder__c == null) {
            return nextOrder;
        }
//v1.4 end
        
        Boolean isPreUnit =
            sr.RecordType != null &&
            sr.RecordType.Name == Constants.SERVICE_REQUEST_RT_PRE_UNIT_CANCELLATION;
        
        Boolean isPostUnit =
            sr.RecordType != null &&
            sr.RecordType.Name == Constants.SERVICE_REQUEST_RT_POST_UNIT_CANCELLATION;
        
        Id soId = sr.SalesOrder__c;
        
        Integer ddCount = 0;
        Integer admCount = 0;
        
        if (ddCountcheck.containsKey(soId)) {
            ddCount = ddCountcheck.get(soId);
        } else {
            ddCount = [
                SELECT COUNT()
                FROM DirectDebitRequest__c
                WHERE SalesOrder__c = :soId
            ];
            ddCountcheck.put(soId, ddCount);
        }
        
        if (isPostUnit) {
            
            if (admCountcheck.containsKey(soId)) {
                admCount = admCountcheck.get(soId);
            } else {
                
                Id admRtId = Schema.SObjectType.ServiceRequest__c
                    .getRecordTypeInfosByDeveloperName()
                    .get('Service_Request_Management_ADM')
                    .getRecordTypeId();
                
                admCount = [
                    SELECT COUNT()
                    FROM ServiceRequest__c
                    WHERE SalesOrder__c = :soId
                    AND RecordTypeId = :admRtId
                ];
                
                admCountcheck.put(soId, admCount);
            }
        }
        
        if (ddCount == 0 && nextOrder == 4) {
            nextOrder++;
        }
        
        if (isPostUnit && admCount == 0 && nextOrder == 3) {
            nextOrder++;
        }
        
        return nextOrder;
    } //End 
    
    
    
}