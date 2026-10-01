public class ServiceRequestTitleDeedController  
{
    public static String TaskRecordTypeId = Schema.SObjectType.Task.getRecordTypeInfosByDeveloperName().get('Service_Request').getRecordTypeId();

    public static void createNextStepsForTasks(List<Task> tskList,Map<Id,Sobject> oldMap)
    {system.debug('debug: in ServiceRequestTitleDeedController.createNextStepsForTasks method');
        ServiceRequestTaskController.handleTaskUpdates(tskList,oldMap,false);
    }
    
    public static String serviceRequestDataValidationJOTitleDeed(List<Task> newTasks, Map<Id, Task> oldMap)
	{
        Set<Id> setSRId = new Set<Id>();
        String strError = '';
    
        // Collecting WhatId values (presumably ServiceRequest Ids) from tasks
        for (Task tsk : newTasks)
        {
            if (tsk.WhatId != null)
            {
                setSRId.add(tsk.WhatId);
            }
        }

        // Query to fetch ServiceRequests based on WhatId values and RecordType filter using Constants class
        List<ServiceRequest__c> listServiceRequest = [SELECT Id, Name, SalesOrder__c, SalesOrder__r.Status__c, SalesOrder__r.Name, Status__c FROM ServiceRequest__c
            WHERE Id IN :setSRId AND (RecordType.Name = :Constants.SERVICE_REQUEST_RT_DEV_NAME_JOINT_OWNER_TITLE_DEED OR RecordType.Name = :Constants.SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER_TITLE_DEED)];

        Set<Id> setSOId = new Set<Id>();
        Map<Id, String> mapChargeIdSOName = new Map<Id, String>();
        Map<Id, String> mapChargeIdReceiptId = new Map<Id, String>();
        Map<Id, Charge__c> mapChargeIdChargeDetails = new Map<Id, Charge__c>();

        // Collecting Sales Order Ids from ServiceRequests
        for (ServiceRequest__c sr : listServiceRequest)
        {
            setSOId.add(sr.SalesOrder__c);
        }

        // Query to fetch Charges associated with Sales Orders or Service Requests
        List<Charge__c> listCharge = [SELECT Id, Name, Sales_Order__r.Name FROM Charge__c WHERE Sales_Order__c IN :setSOId];

    	Set<Id> setChargeId = new Set<Id>();

        for (Charge__c cg : listCharge)
        {
            setChargeId.add(cg.Id);
            mapChargeIdSOName.put(cg.Id, cg.Sales_Order__r.Name);
            mapChargeIdChargeDetails.put(cg.Id, cg);
        }

        if (!setChargeId.isEmpty())
        {
            // Query to fetch Receipt details based on Charge Ids
            List<Receipt__c> listPayments = [
                SELECT Id, Name, Status__c, Charge__c, Charge__r.Name
                FROM Receipt__c
                WHERE Charge__c IN :setChargeId
            ];
    
            for (Receipt__c rec : listPayments)
            {
                mapChargeIdReceiptId.put(rec.Charge__c, rec.Id);
    
                // Validation for uncleared payments
                if (rec.Status__c != 'Cleared')
                {
                    strError += 'Payments not cleared on Sales Order: ' + mapChargeIdSOName.get(rec.Charge__c) + ' --> Charge: ' + rec.Charge__r.Name + ' --> Payment: ' + rec.Name + ' --> Status: ' + rec.Status__c + '\n';
                }
            }
    
            // Validation for missing payments
            for (Id chargeId : mapChargeIdSOName.keySet())
            {
                if (!mapChargeIdReceiptId.containsKey(chargeId))
                {
                    strError += 'Payments not available for charge on Sales Order: ' + mapChargeIdSOName.get(chargeId) + ' --> Charge: ' + mapChargeIdChargeDetails.get(chargeId).Name + '\n';
                }
            }
        }

     	if (String.isBlank(strError))
        {
            return 'Success';
        }

    	return strError;
	}
    
    public static void serviceRequestDataValidationforProspectAcc(List<Task> newTasks, Map<Id, Task> newMap, Map<Id, Task> oldMap) 
    {
        ServiceRequestTaskController.serviceRequestDataValidation(newTasks,newMap,oldMap);
    }
    
    public static void SRDocumentValidation(List<SObject> newList, Map<Id, SObject> oldMap)
    {
        ServiceRequestTaskController.documentValidation(newList,oldMap);
    }
    
    public static void updateTaskStatusAfterApproval(ServiceRequest__c newServiceRequest, String subjectCriteria, boolean statusCriteria) 
    {
        List<Task> taskList = [SELECT Id, Status, Subject, Order__c FROM Task WHERE WhatId = :newServiceRequest.Id AND Status != :Constants.TASK_STATUS_CLOSED];
        
        List<Task> taskListToUpdate = new List<Task>();
        for (Task task : taskList) 
        {
            if (task.Subject == subjectCriteria && !statusCriteria) 
            {
                task.Status = Constants.TASK_STATUS_CLOSED;
                taskListToUpdate.add(task);
            }
            else if(task.Subject == subjectCriteria && statusCriteria) 
            {
                task.Order__c = task.Order__c+1;
                task.Status = Constants.TASK_STATUS_CLOSED;
                taskListToUpdate.add(task);
            }
        }
        
        if (!taskListToUpdate.isEmpty()) {
            update taskListToUpdate;
        }
    }
}