@isTest
public with sharing class ServiceRequestUnitControllerTest {

    @TestSetup
    static void makeData(){
           // Create Person Account
        Id personRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();
        Account personAcc = new Account(LastName = 'Test Person', RecordTypeId = personRtId, PersonEmail='test@gmail.com');
        insert personAcc;

        // Create Business Account (OrganizationAccount) and Contact
        Id businessRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('OrganizationAccount').getRecordTypeId();
        Account businessAcc = new Account(Name = 'Test Business', RecordTypeId = businessRtId);
        insert businessAcc;

        Contact con = new Contact(
            LastName = 'Test Contact',
            AccountId = businessAcc.Id,
            Email = 'test@example.com',
            Is_Active__c = true
        );
        insert con;

        SalesOrder__c soPerson = new SalesOrder__c(CustomerAccount__c = personAcc.Id, Status__c = 'Sold');
        insert soPerson;
        // Create a test service request unit
        ServiceRequest__c serviceRequestUnit = new ServiceRequest__c();
        serviceRequestUnit.Status__c = 'In-progress                                                                                                                                                                                                                                                                                             ';
        serviceRequestUnit.SalesOrder__c = soPerson.Id;
        serviceRequestUnit.AccountId__c = personAcc.Id;
        serviceRequestUnit.Transferred_Sales_Order__c = soPerson.Id;
        serviceRequestUnit.RecordTypeId= schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByDeveloperName().get('SRM_Unit_Swap').getRecordTypeId();

        insert serviceRequestUnit;
        
    }


       @isTest
    public static void testServiceRequestUnitController() {
        ServiceRequest__c thisSr = [SELECT Id, Name, Status__c, RecordTypeId, SalesOrder__c, AccountId__c FROM ServiceRequest__c LIMIT 1];
            Task  tsk = new Task(
            Subject = 'Sales Agent to select the Unit',
            WhatId = thisSr.Id,
            Status = 'closed',
            Priority = 'Normal',
            RecordTypeId = ServiceRequestUnitController.TaskRecordTypeId
        );

        Task oldTask = new Task(
            Subject = 'Sales Agent to select the Unit',
            WhatId = thisSr.Id,
            Status = 'Not Started',
            Priority = 'Normal',
            RecordTypeId = ServiceRequestUnitController.TaskRecordTypeId
        );
        insert oldTask;
        Map<Id, SObject> oldMap = new Map<Id, SObject>();
        oldMap.put(oldTask.Id, oldTask);
        List<Task> tskList = new List<Task>{tsk};        
        ServiceRequestUnitController.createNextStepsForTasks(tskList, oldMap);
        serviceRequestUnitController.SendRegistartionEmail(tsk);        
    }
    
    @isTest
    public static void testServiceRequestTaskValidation() {
        ServiceRequest__c thisSr = [SELECT Id, Name, Status__c, RecordTypeId, SalesOrder__c, AccountId__c FROM ServiceRequest__c];
        Task    tsk = new Task(
            Subject = 'Finance Team to Review Escrow Account Details',
            WhatId = thisSr.Id,
            Status = 'closed',
            Priority = 'Normal',
            order__c = 2,
            RecordTypeId = ServiceRequestUnitController.TaskRecordTypeId
        );

        Task oldTask = new Task(
            Subject = 'Finance Team to Review Escrow Account Details',
            WhatId = thisSr.Id,
            Status = 'Not Started',
            Priority = 'Normal',
            order__c = 1,
            RecordTypeId = ServiceRequestUnitController.TaskRecordTypeId
        );
        
        insert oldTask;
        EmailTemplate tem = [SELECT Id, DeveloperName FROM EmailTemplate WHERE DeveloperName ='Service_Request_Unit_Upgrade_Swap'];
        Map<Id, Task> oldMap = new Map<Id, Task>();
        oldMap.put(oldTask.Id, oldTask);
        tsk.Id = oldTask.Id;
        List<Task> tskList = new List<Task>{tsk};
        ServiceRequestUnitController.validationSrForDownPayment(tskList, oldMap);
        Messaging.SingleEmailMessage mesg = ServiceRequestUnitController.getSingleEmail('Test@example.com', Userinfo.getUserId(), tem.Id, thisSr.Id);
        serviceRequestUnitController.updateTaskStatusAfterApproval(thisSr, 'Finance Team to Review Escrow Account Details', false, 1);   
       // serviceRequestUnitController.updateTaskStatusAfterApproval(thisSr, 'Finance Team to Review Escrow Account Details', true, 1); 
    }  

}