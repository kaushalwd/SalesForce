/**
 * @description       : 
 * @author            : Krishna Chaitanya
 * @group             : 
 * @last modified on  : 05-27-2025
 * @last modified by  : Krishna Chaitanya
**/
public class ServiceRequestUnitController {
    private static final string SERVICE_REQUEST_RT_Unit_SWAP { get { return 'SRM_Unit_Swap'; } }  // for payment plan swap
    private static final string SERVICE_REQUEST_RT_Unit_Upgrade { get { return 'Service_Request_Management_Unit_Upgrade'; } }  // for payment plan swap
    public static String TaskRecordTypeId = Schema.SObjectType.Task.getRecordTypeInfosByDeveloperName().get('Service_Request').getRecordTypeId();
    
    public static void createNextStepsForTasks(List<Task> tskList,Map<Id,Sobject> oldMap)
    {system.debug('debug: in SericeRequestUnit.createNextStepsForTasks method'+tskList+'map'+oldMap);
     ServiceRequestTaskController.handleTaskUpdates(tskList,oldMap,true);
    }
    
    public static void SendRegistartionEmail(Task thisTask){ 
        //Map<Id, ServiceRequest__c> srRecordMap = ServiceRequestTaskController.getServiceRequestMap(srIds); 
        Id srId = thisTask.WhatId;
        System.debug('SrId.....,.....'+srId);
        //= srRecordMap.values()[0].Id;
        try {
            Database.SaveResult result = Database.update( new ServiceRequest__c(Id = thisTask.WhatId, Status__c = 'Closed',CloseDate__c =System.Today()), false);
        } catch(Exception ex) {
            System.debug(ex.getMessage());
        }
        String accountId = [SELECT Id, AccountId__c FROM ServiceRequest__c WHERE Id=:thisTask.WhatId] ?.AccountId__c;
        EmailTemplate tem = [SELECT Id, DeveloperName FROM EmailTemplate WHERE DeveloperName ='Service_Request_Unit_Upgrade_Swap']; 
        List<Messaging.SingleEmailMessage> emailsToSend = new List<Messaging.SingleEmailMessage>();
        if(accountId != null) {
            
            for (Account relatedAcc : [
                SELECT Id, OwnerId, IsPersonAccount, Owner.Profile.Name, Owner.Email, PersonEmail, Name
                FROM Account 
                WHERE Id = :accountId
            ]) {
                if (relatedAcc.PersonEmail != null && relatedAcc.IsPersonAccount) {
                    Messaging.SingleEmailMessage email = getSingleEmail(relatedAcc.PersonEmail, relatedAcc.OwnerId, tem.Id, srId);
                    emailsToSend.add(email);
                } else { 
                    for (Contact relatedCon : [
                        SELECT Id, OwnerId, Owner.Profile.Name, Owner.Email, Email
                        FROM Contact 
                        WHERE Is_Active__c = TRUE AND AccountId = :accountId
                    ]) {
                        if (relatedCon.Email != null) {
                            Messaging.SingleEmailMessage email = getSingleEmail(relatedCon.Email, relatedAcc.OwnerId, tem.Id, srId);
                            emailsToSend.add(email);
                        }
                    }
                }
            }
        }
        System.debug('SrId.....,.....'+srId);
        if (!emailsToSend.isEmpty() &&  system.Label.EmailCheck =='true') {  
            System.debug('Sending Emails: ' + emailsToSend);
            Messaging.sendEmail(emailsToSend);
        }
    }
    
    public static Messaging.SingleEmailMessage getSingleEmail( String emailAdds, String userId,   String templateId,  String srId ){
        Messaging.SingleEmailMessage mail =  new Messaging.SingleEmailMessage();
        mail.setToAddresses(new String[]{emailAdds});
        mail.setTargetObjectId(userId);
        mail.setSaveAsActivity(false);
        mail.setTemplateId(templateId);// This is template ID
        mail.setTreatTargetObjectAsRecipient(false);
        //mail.setWhatId(srid);
        mail.setSenderDisplayName('Modon Sales Team');
        return mail;
    }
    
    public static void updateTaskStatusAfterApproval(ServiceRequest__c newServiceRequest, String subjectCriteria, boolean statusCriteria,Integer order) {
        Id unitswapRecordTypeId=Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType, SERVICE_REQUEST_RT_Unit_SWAP);
        Id unitupgradeRecordTypeId=Utility.getRecordTypeIdByDevName(ServiceRequest__c.SObjectType, SERVICE_REQUEST_RT_Unit_Upgrade);
        System.debug('updateTaskStatusAfterApproval called');
        System.debug('newServiceRequest.Id: ' + newServiceRequest.Id);
        System.debug('subjectCriteria: ' + subjectCriteria);
        System.debug('statusCriteria: ' + statusCriteria);
        List<Task> taskList = [SELECT Id, Status, Subject, Order__c 
                               FROM Task 
                               WHERE WhatId = :newServiceRequest.Id 
                               AND Status != :Constants.TASK_STATUS_CLOSED];
        Map<Id, Task> oldtskMap = new Map<Id, Task>();
        for (Task t : taskList) {
            oldtskMap.put(t.Id, t);
        }
        System.debug('oldtskMap---------->'+oldtskMap);
        
        Map<Id, Task> oldMap = new Map<Id, Task>();
        for (Id taskId : oldtskMap.keySet()) {
            oldMap.put(taskId, oldtskMap.get(taskId));
        }
        System.debug('oldtskMap---------->'+oldMap);
        list<ServiceRequest__c> SrCreationList=new list<ServiceRequest__c>();
        List<Task> taskListToUpdate = new List<Task>();
        for (Task task : taskList) {
            oldtskMap.put(task.Id, task);
            if (task.Subject == subjectCriteria && !statusCriteria) {
                task.Status = Constants.TASK_STATUS_CLOSED;
                taskListToUpdate.add(task);
            }else if(task.Subject == subjectCriteria && statusCriteria) {
                task.Order__c = task.Order__c+order;
                task.Status = Constants.TASK_STATUS_CLOSED;
                taskListToUpdate.add(task);
            }
        }
        List<Database.SaveResult> taskResult = new List<Database.SaveResult>();
        if (!taskListToUpdate.isEmpty()) {
            taskResult = Database.update(taskListToUpdate, false);
        }
        if(newServiceRequest.RecordTypeId == unitswapRecordTypeId   || newServiceRequest.RecordTypeId == unitupgradeRecordTypeId){
            if (taskResult != null && taskResult[0].isSuccess()) {
                System.debug('Task updated successfully.'+oldtskMap);
                
                // Step 3: Retrieve the updated task record
                List<Task> updatedTaskList = [SELECT NOC_Doc_Status__c,Id,Extended_NOC_Approval_Status__c,RecordTypeId, Subject, Order__c,WhatId, ActivityDate, Status, Description, KYC_Status__c, Priority,Is_Sub_Task__c 
                                              FROM Task WHERE Id IN :taskListToUpdate];
                List<Task> newTasks = new List<Task>();
                for(task t:updatedTaskList){
                    newTasks.add(t);
                    
                }
                createNextStepsForTasks(newTasks, null);
            }
        }
    }   
    
    public static void validationSrForDownPayment(List<Task> tasks, Map<Id, Task> oldMap) {
        if(tasks.size() > 0) {
        Task thisTask = tasks[0];
        Task oldTask = oldMap != null && oldMap.containsKey(thisTask.Id) ?  oldMap.get(thisTask.Id) : null;
        if(thisTask != null && oldTask != null && thisTask.Status != oldTask.Status && thisTask.Subject == 'Finance Team to Review Escrow Account Details' && thisTask.Status == Constants.TASK_STATUS_CLOSED){
            ServiceRequest__c thisRequest = [SELECT Id, Transferred_Sales_Order__c, RecordType.Name FROM ServiceRequest__c WHERE Id=: thisTask.WhatId];
            if(thisRequest != null  && thisRequest.Transferred_Sales_Order__c != null && (thisRequest.RecordType.Name == Constants.SERVICE_REQUEST_RT_DEV_NAME_UNIT_UPGRADE || thisRequest.RecordType.Name == Constants.SERVICE_REQUEST_RT_DEV_NAME_UNIT_SWAP )) {
                SalesOrder__c thisOrder = [SELECT Id, (SELECT Id, PaymentInstallments__r.Name, MilestoneNumber__c, PaymentStatus__c FROM Sales_Order_Installments__r) FROM SalesOrder__c WHERE Id =: thisRequest.Transferred_Sales_Order__c];
                Boolean isDownPaymentPaid = false ;
                for(SalesOrderInstallments__c thisInstallment : thisOrder.Sales_Order_Installments__r) {
                    if((thisInstallment.PaymentInstallments__r.Name == 'Down Payment' || thisInstallment.MilestoneNumber__c == 1 || thisInstallment.MilestoneNumber__c == 1.0)  && thisInstallment.PaymentStatus__c == 'Paid') {
                        isDownPaymentPaid = true;
                    } 
                }
                if(!isDownPaymentPaid) {
                    thisTask.addError('Please clear Down Payment');
                }
            }
        }
         System.debug('task validation ');
        }
        
        
    }
    
}