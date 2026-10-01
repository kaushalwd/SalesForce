/**********************************************************************************************************************
* Name               : TaskTriggerHandler                                                        
* Description        : This class is used to handle all the task trigger instances
* Usage              : Called from TaskTrigger
* Created By         : PwC Digital Middle East                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Anil Valluri                21 Dec 2023     Initial Draft    
* 1.1           Shubham Agrawal             03 Mar 2024     Call log email notifications   
* 1.2			Raghu Gajjela				17 sep 2025		For send email upon Sr creation and Updation classname:ServiceRequestEmailDispatcher
* 1.3           Suresh  					19 Nov 2025     SendSMSNotification added
* 1.4           Chandu  					30 Apr 2026     Escalation method
* 1.5           Raghu Sharma                20 May 2026     In after update Added a New Method calling for Case related SPA Task Handling
* 1.6           (upendra)                 07 Sep 2026     Moved the inline "Send for Signature" Task-scanning /
*                                                             DocuSignQueueable-enqueueing block (tagged "1.4
*                                                             start"/"1.4 end") out into
*                                                             MBP_DocusignController.enqueueSendForSignatureFromTasks()
*                                                             — DocuSign logic belongs in the DocuSign controller,
*                                                             not inline here. Behavior is identical; this is a pure
*                                                             code-organization change. Nothing else in this class
*                                                             was touched.
******************************************************************************************************************/
public without sharing class TaskTriggerHandler extends TriggerHandler {
    //*** Before Insert Action ***//
    public override void beforeInsertMethod(list<SObject> newList,map<ID,SObject> newMap)
    {
        TaskTriggerHelper.updateTaskOwnerFromLead(newList, newMap);
        ServiceRequestTaskController.updateTaskOwnerFromSR(newList, newMap);
        TaskTriggerHelper.updateEscalationTimes(newList); //1.4
    }
    
    //*** Before Update Action ***//
    public override void beforeUpdateMethod(list<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap)
    {
        ServiceRequestTaskController.documentValidation(newList,oldMap);
        ServiceRequestTaskController.documentValidationOfSR(newList,oldMap);

        // Cast newList to List<Task>
        List<Task> tasksNew = (List<Task>) newList;
        
        // Create new maps for Task records
        Map<Id, Task> tasksNewMap = new Map<Id, Task>();
        for (Id key : newMap.keySet()) {
            tasksNewMap.put(key, (Task)newMap.get(key));
        }
        
        Map<Id, Task> tasksOldMap = new Map<Id, Task>();
        for (Id key : oldMap.keySet()) {
            tasksOldMap.put(key, (Task)oldMap.get(key));
        }
         ServiceRequestUnitController.validationSrForDownPayment(tasksNew, tasksOldMap);
        ServiceRequestTaskController.serviceRequestDataValidation(tasksNew, tasksNewMap, tasksOldMap);
       
    }
    
    //*** After Insert Action ***//
    public override void afterInsertMethod(list<SObject> newList,map<ID,SObject> newMap)
    {
       
        //TaskTriggerHelper.updateSLADateTimeOnLead_BasedonTaskDueDate(newList, newMap);
        //TaskTriggerHelper.updateOpportunityStatus(newList, newMap);
        //TaskTriggerHelper.updateLeadCallTaskStatus(newList); // This is for sales app and can be uncommented after service cloud phase 2 deployment 
        TaskTriggerHelper.sendCallLogNotifications(newList, newMap);
        ServiceRequestTaskController.sendTaskNotification(newList,null);
        TaskTriggerHelper.sendTaskNotification(newList,null);
        ServiceRequestTaskController.sendNotification(newList);
        // TaskTriggerHelper.createDocumentRecord(newList);
        ServiceRequestTaskController.handleRequireMoreInfoTasks_Insert((List<Task>) newList);

        // 1.6: moved the "Send for Signature" Task -> DocuSignQueueable logic into
        // MBP_DocusignController — see that class for the DocuSign-specific implementation.
        MBP_DocusignController.enqueueSendForSignatureFromTasks((List<Task>) newList);

        //ServiceRequestEmailDispatcher.processTasks(newList,null,true);
    }
    
    //*** After Update Action ***//
    public override void afterUpdateMethod(list<SObject> newList, Map<Id, SObject> newMap, List<SObject> oldList, Map<Id, SObject> oldMap)
    {
         List<Task> tasksNew = (List<Task>) newList;
         Map<Id, Task> tasksOldMap = new Map<Id, Task>();
        for (Id key : oldMap.keySet()) {
            tasksOldMap.put(key, (Task)oldMap.get(key));
        }
        ServiceRequestTaskController.updateRegistrationStatusForRequireInfoTask(newList, oldMap);
        TaskTriggerHelper.updateLeadStatus_BasedOnTaskStatus(newList, newMap, oldList, oldMap);
        //ServiceRequestTaskController.handleTaskUpdates(newList,oldMap); //v.1.4 
        TaskTriggerHelper.isSLAExpired(newList,oldMap);
        TaskTriggerHelper.checkIfNoUpdate(newList,oldMap);
        //TaskTriggerHelper.autoCloseTask_and_Recreate(newList, newMap, oldList, oldMap);
        ServiceRequestTaskController.cancelServiceRequestCharges(newList,oldMap);
        ServiceRequestTaskController.sendTaskNotification(newList,oldMap);
        TaskTriggerHelper.sendTaskNotification(newList,oldMap);
        TaskTriggerHelper.updateOpportunityStage_BasedOnTaskStatus(newList, newMap, oldList, oldMap);
        TaskTriggerHelper.sendCustomerEmails(tasksNew, tasksOldMap);
        TaskTriggerHelper.sendSMSNotification(tasksNew, tasksOldMap);
       // ServiceRequestEmailDispatcher.processTasks(newList,oldMap,false);
       //ServiceRequestEmailDispatcher.processTasks(tasksNew, tasksOldMap, false);
         //ServiceRequestTaskController.handleRequireMoreInfoTaskEmail((List<Task>) newList);
		 //CaseTriggerHelper.handleCaseSPASignatureFlow(newList,oldMap);//update version 1.5
        
        List<Task> newTasks = (List<Task>) newList;
        
        Set<Id> srIds = new Set<Id>();
        for (Task t : newTasks) 
        {
            if (t.WhatId != null && t.WhatId.getSObjectType().getDescribe().getName() == 'ServiceRequest__c') {
                srIds.add(t.WhatId);
            }
        }
        
        if (srIds.isEmpty()) 
        {
            return; 
        }
        
        Map<Id, ServiceRequest__c> srMap = new Map<Id, ServiceRequest__c>([SELECT Id, RecordType.Name FROM ServiceRequest__c WHERE Id IN :srIds]);        
        
        Set<String> bypassRecordTypes = new Set<String>{Constants.SERVICE_REQUEST_RT_DEV_NAME_JOINT_OWNER_TITLE_DEED,Constants.SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER_TITLE_DEED,Constants.SERVICE_REQUEST_RT_DEV_NAME_UNIT_UPGRADE,Constants.SERVICE_REQUEST_RT_DEV_NAME_UNIT_SWAP};
                    
		Boolean shouldProceed = false;
        Boolean shouldProceedBR = false;

        for (Task t : newTasks) 
        {
            ServiceRequest__c sr = srMap.get(t.WhatId);
            if (sr != null && !bypassRecordTypes.contains(sr.RecordType.Name)) 
            {
                system.debug('enteredIF--->'+sr.RecordType.Name);
                if(sr.RecordType.Name==Constants.SERVICE_REQUEST_BR){
                    shouldProceedBR = true;
                    break;
                }else{
                    shouldProceed = true;
                    break;
                }
            }
        }
        
        if (shouldProceed) 
        {
            System.debug('calling');
            ServiceRequestTaskController.handleTaskUpdates(newTasks, oldMap,false);
        }
        if(shouldProceedBR){
            System.debug('callingBR');
            ServiceRequestTaskController.handleTaskUpdatesBR(newTasks, oldMap,false);
        }
    }
}