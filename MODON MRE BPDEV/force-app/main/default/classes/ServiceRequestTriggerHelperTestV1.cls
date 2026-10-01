@isTest
public class ServiceRequestTriggerHelperTestV1 {
    public class DummyHttpMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{}');
            res.setStatusCode(200);
            return res;
        }
    }

    private static SalesOrder__c createFreshSalesOrder() {
        List<Account> accList = [SELECT Id FROM Account WHERE IsPersonAccount = true LIMIT 1];
        Account acc;
        if (accList.isEmpty()) {
            Id rtPerson = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
                .get('PersonAccount').getRecordTypeId();
            acc = new Account(FirstName = 'Test', LastName = 'Helper',
                RecordTypeId = rtPerson,
                PersonEmail  = 'helper' + System.currentTimeMillis() + '@test.com');
            insert acc;
        } else {
            acc = accList[0];
        }
        SalesOrder__c so = new SalesOrder__c(Status__c = 'Sold', CustomerAccount__c = acc.Id);
        insert so;
        return so;
    }

    private static Id getTaskRecordTypeId() {
        return Schema.SObjectType.Task.getRecordTypeInfosByDeveloperName()
               .get('Service_Request').getRecordTypeId();
    }

    /**
     * Since Task.SRType__c is a formula field = ServiceAction__r.ServiceCatalog__r.Name,
     * the only way to make it resolve to the right value is to link the Task to a
     * ServiceAction whose parent ServiceCatalog has the required Name.
     */
    private static ServiceAction__c getOrCreateServiceAction(
            String catalogName, String srType, Decimal orderNum, String taskSubject) {

        List<ServiceCatalog__c> existing = [
            SELECT Id FROM ServiceCatalog__c WHERE Name = :catalogName LIMIT 1];
        ServiceCatalog__c sc;
        if (existing.isEmpty()) {
            sc = new ServiceCatalog__c(Name = catalogName, Service_Request_Type__c = srType);
            insert sc;
        } else {
            sc = existing[0];
        }
        List<ServiceAction__c> existingAct = [
            SELECT Id FROM ServiceAction__c
            WHERE ServiceCatalog__c = :sc.Id AND Order__c = :orderNum LIMIT 1];
        ServiceAction__c sa;
        if (existingAct.isEmpty()) {
            sa = new ServiceAction__c(
                Name              = catalogName + ' Step ' + orderNum,
                ServiceCatalog__c = sc.Id,
                Order__c          = orderNum,
                TaskSubject__c    = taskSubject);
            insert sa;
        } else {
            sa = existingAct[0];
        }
        return sa;
    }

    @isTest
    static void test_sendNotification_fullPath() {
        SalesOrder__c so = createFreshSalesOrder();
        ServiceRequest__c sr = new ServiceRequest__c(SalesOrder__c = so.Id);
        insert sr;
        Id taskRT = getTaskRecordTypeId();
        Task t = new Task(WhatId = sr.Id, RecordTypeId = taskRT, Subject = 'Notify Task',
            Status = 'Not Started', OwnerId = UserInfo.getUserId());
        insert t;
        Test.startTest();
        ServiceRequestTaskController.sendNotification(new List<Task>{ t });
        Test.stopTest();
    }

    @isTest
    static void test_sendNotification_emptyAndNullGuards() {
        Test.startTest();
        ServiceRequestTaskController.sendNotification(null);
        ServiceRequestTaskController.sendNotification(new List<Task>());
        Test.stopTest();
    }

    /*@isTest
    static void test_documentValidation_ADM_NewSale_order1() {
        SalesOrder__c so = createFreshSalesOrder();
        Id admRT = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByDeveloperName()
            .get('Service_Request_Management_ADM').getRecordTypeId();
        ServiceRequest__c sr = new ServiceRequest__c(RecordTypeId = admRT,
            SalesOrder__c = so.Id, Type__c = 'New Sale');
        insert sr;
        Id taskRT = getTaskRecordTypeId();
        Task t = new Task(WhatId = sr.Id, RecordTypeId = taskRT, Subject = 'ADM Step',
            Status = Constants.TASK_STATUS_CLOSED, Order__c = 1);
        insert t;
        Test.startTest();
        try {
            Map<Id, SObject> oldMap = new Map<Id, SObject>{
                t.Id => new Task(Id = t.Id, Status = 'Open')};
            ServiceRequestTaskController.documentValidation(new List<SObject>{ t }, oldMap);
        } catch (Exception e) { }
        Test.stopTest();
    }*/

    @isTest
    static void test_documentValidation_ADM_Normal_order1() {
        SalesOrder__c so = createFreshSalesOrder();
        Id admRT = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByDeveloperName()
            .get('Service_Request_Management_ADM').getRecordTypeId();
        ServiceRequest__c sr = new ServiceRequest__c(RecordTypeId = admRT,
            SalesOrder__c = so.Id, Type__c = 'Normal');
        insert sr;
        Id taskRT = getTaskRecordTypeId();
        Task t = new Task(WhatId = sr.Id, RecordTypeId = taskRT, Subject = 'ADM Normal',
            Status = Constants.TASK_STATUS_CLOSED, Order__c = 1);
        insert t;
        Test.startTest();
        try {
            Map<Id, SObject> oldMap = new Map<Id, SObject>{
                t.Id => new Task(Id = t.Id, Status = 'Open')};
            ServiceRequestTaskController.documentValidation(new List<SObject>{ t }, oldMap);
        } catch (Exception e) { }
        Test.stopTest();
    }

    @isTest
    static void test_documentValidation_ADM_NextOfKin_order1() {
        SalesOrder__c so = createFreshSalesOrder();
        Id admRT = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByDeveloperName()
            .get('Service_Request_Management_ADM').getRecordTypeId();
        ServiceRequest__c sr = new ServiceRequest__c(RecordTypeId = admRT,
            SalesOrder__c = so.Id, Type__c = 'Next of Kin');
        insert sr;
        Id taskRT = getTaskRecordTypeId();
        Task t = new Task(WhatId = sr.Id, RecordTypeId = taskRT, Subject = 'ADM NOK',
            Status = Constants.TASK_STATUS_CLOSED, Order__c = 1);
        insert t;
        Test.startTest();
        try {
            Map<Id, SObject> oldMap = new Map<Id, SObject>{
                t.Id => new Task(Id = t.Id, Status = 'Open')};
            ServiceRequestTaskController.documentValidation(new List<SObject>{ t }, oldMap);
        } catch (Exception e) { }
        Test.stopTest();
    }

    /*@isTest
    static void test_documentValidation_ADM_orders3_4_5() {
        SalesOrder__c so = createFreshSalesOrder();
        Id admRT = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByDeveloperName()
            .get('Service_Request_Management_ADM').getRecordTypeId();
        ServiceRequest__c sr = new ServiceRequest__c(RecordTypeId = admRT,
            SalesOrder__c = so.Id, Type__c = 'New Sale', Penality_Charge__c = false);
        insert sr;
        Id taskRT = getTaskRecordTypeId();
        for (Integer ord : new List<Integer>{ 3, 4, 5 }) {
            Task t = new Task(WhatId = sr.Id, RecordTypeId = taskRT,
                Subject = 'ADM Step ' + ord, Status = Constants.TASK_STATUS_CLOSED, Order__c = ord);
            insert t;
            Test.startTest();
            try {
                Map<Id, SObject> oldMap = new Map<Id, SObject>{
                    t.Id => new Task(Id = t.Id, Status = 'Open')};
                ServiceRequestTaskController.documentValidation(new List<SObject>{ t }, oldMap);
            } catch (Exception e) { }
            Test.stopTest();
        }
    }*/

    @isTest
    static void test_documentValidation_PT_step3_missingNOC() {
        SalesOrder__c so = createFreshSalesOrder();
        Id ptRT = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByDeveloperName()
            .get('Service_Request_Management_Property_Transfer_OffPlan').getRecordTypeId();
        ServiceRequest__c sr = new ServiceRequest__c(RecordTypeId = ptRT, SalesOrder__c = so.Id);
        insert sr;
        Id taskRT = getTaskRecordTypeId();
        Task t = new Task(WhatId = sr.Id, RecordTypeId = taskRT, Subject = 'Community NOC Step',
            Status = Constants.TASK_STATUS_CLOSED, Order__c = 3);
        insert t;
        Test.startTest();
        try {
            Map<Id, SObject> oldMap = new Map<Id, SObject>{
                t.Id => new Task(Id = t.Id, Status = 'Open')};
            ServiceRequestTaskController.documentValidation(new List<SObject>{ t }, oldMap);
        } catch (Exception e) { }
        Test.stopTest();
    }

    @isTest
    static void test_documentValidation_PT_step4_missingMCD() {
        SalesOrder__c so = createFreshSalesOrder();
        Id ptRT = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByDeveloperName()
            .get('Service_Request_Management_Property_Transfer_OffPlan').getRecordTypeId();
        ServiceRequest__c sr = new ServiceRequest__c(RecordTypeId = ptRT, SalesOrder__c = so.Id);
        insert sr;
        Charge__c charge = new Charge__c(Service_Request__c = sr.Id, Name = 'Modon Fee',
            Amount__c = 500, Paid_Amount__c = 0, PaymentStatus__c = 'Not Paid');
        insert charge;
        Id taskRT = getTaskRecordTypeId();
        Task t = new Task(WhatId = sr.Id, RecordTypeId = taskRT, Subject = 'MCD Step',
            Status = Constants.TASK_STATUS_CLOSED, Order__c = 4);
        insert t;
        Test.startTest();
        try {
            Map<Id, SObject> oldMap = new Map<Id, SObject>{
                t.Id => new Task(Id = t.Id, Status = 'Open')};
            ServiceRequestTaskController.documentValidation(new List<SObject>{ t }, oldMap);
        } catch (Exception e) { }
        Test.stopTest();
    }

    /*@isTest
    static void test_documentValidation_PT_step6_paymentProof() {
        SalesOrder__c so = createFreshSalesOrder();
        Id ptRT = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByDeveloperName()
            .get('Service_Request_Management_Property_Transfer_OffPlan').getRecordTypeId();
        ServiceRequest__c sr = new ServiceRequest__c(RecordTypeId = ptRT, SalesOrder__c = so.Id);
        insert sr;
        Documents__c doc = new Documents__c(Service_Request__c = sr.Id,
            Name = 'Payment Proof', Status__c = 'Pending');
        insert doc;
        Id taskRT = getTaskRecordTypeId();
        Task t = new Task(WhatId = sr.Id, RecordTypeId = taskRT, Subject = 'Payment Proof Step',
            Status = Constants.TASK_STATUS_CLOSED, Order__c = 6);
        insert t;
        Test.startTest();
        try {
            Map<Id, SObject> oldMap = new Map<Id, SObject>{
                t.Id => new Task(Id = t.Id, Status = 'Open')};
            ServiceRequestTaskController.documentValidation(new List<SObject>{ t }, oldMap);
        } catch (Exception e) { }
        Test.stopTest();
    }*/

    /*@isTest
    static void test_documentValidation_PaymentPlanSwap_step6() {
        SalesOrder__c so = createFreshSalesOrder();
        Id ppRT = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByDeveloperName()
            .get('Service_Request_Management_Payment_Plan_Swap').getRecordTypeId();
        ServiceRequest__c sr = new ServiceRequest__c(RecordTypeId = ppRT, SalesOrder__c = so.Id);
        insert sr;
        Documents__c doc = new Documents__c(Service_Request__c = sr.Id,
            Name = 'Payment Plan Swap', Status__c = 'Pending');
        insert doc;
        Id taskRT = getTaskRecordTypeId();
        Task t = new Task(WhatId = sr.Id, RecordTypeId = taskRT, Subject = 'PP Swap Step',
            Status = Constants.TASK_STATUS_CLOSED, Order__c = 6);
        insert t;
        Test.startTest();
        try {
            Map<Id, SObject> oldMap = new Map<Id, SObject>{
                t.Id => new Task(Id = t.Id, Status = 'Open')};
            ServiceRequestTaskController.documentValidation(new List<SObject>{ t }, oldMap);
        } catch (Exception e) { }
        Test.stopTest();
    }*/

    @isTest
    static void test_serviceRequestDataValidation_ADMDeRegistration() {
        SalesOrder__c so = createFreshSalesOrder();
        Id admRT = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByDeveloperName()
            .get('Service_Request_Management_ADM').getRecordTypeId();
        ServiceRequest__c sr = new ServiceRequest__c(RecordTypeId = admRT, SalesOrder__c = so.Id);
        insert sr;
        Id taskRT = getTaskRecordTypeId();
        Task t = new Task(WhatId = sr.Id, RecordTypeId = taskRT,
            Subject = 'ADM De-Registration', Status = Constants.TASK_STATUS_CLOSED);
        insert t;
        Map<Id, Task> oldMap = new Map<Id, Task>{ t.Id => new Task(Id = t.Id, Status = 'Open') };
        Map<Id, Task> newMap = new Map<Id, Task>{ t.Id => t };
        Test.startTest();
        ServiceRequestTaskController.serviceRequestDataValidation(
            new List<Task>{ t }, newMap, oldMap);
        Test.stopTest();
    }

    @isTest
    static void test_serviceRequestDataValidation_DirectDebitCheck_activeDD() {
        SalesOrder__c so = createFreshSalesOrder();
        Id admRT = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByDeveloperName()
            .get('Service_Request_Management_ADM').getRecordTypeId();
        ServiceRequest__c sr = new ServiceRequest__c(RecordTypeId = admRT, SalesOrder__c = so.Id);
        insert sr;
        DirectDebitRequest__c dd = new DirectDebitRequest__c(SalesOrder__c = so.Id, IsActive__c = true);
        insert dd;
        Id taskRT = getTaskRecordTypeId();
        Task t = new Task(WhatId = sr.Id, RecordTypeId = taskRT,
            Subject = 'Direct Debit Check', Status = Constants.TASK_STATUS_CLOSED);
        insert t;
        Map<Id, Task> oldMap = new Map<Id, Task>{ t.Id => new Task(Id = t.Id, Status = 'Open') };
        Map<Id, Task> newMap = new Map<Id, Task>{ t.Id => t };
        Test.startTest();
        ServiceRequestTaskController.serviceRequestDataValidation(
            new List<Task>{ t }, newMap, oldMap);
        Test.stopTest();
    }

    @isTest
    static void test_serviceRequestDataValidation_DirectDebitCheck_noStatusField() {
        SalesOrder__c so = createFreshSalesOrder();
        Id admRT = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByDeveloperName()
            .get('Service_Request_Management_ADM').getRecordTypeId();
        ServiceRequest__c sr = new ServiceRequest__c(RecordTypeId = admRT, SalesOrder__c = so.Id);
        insert sr;
        DirectDebitRequest__c dd = new DirectDebitRequest__c(SalesOrder__c = so.Id, IsActive__c = false);
        insert dd;
        Id taskRT = getTaskRecordTypeId();
        Task t = new Task(WhatId = sr.Id, RecordTypeId = taskRT,
            Subject = 'Direct Debit Check', Status = Constants.TASK_STATUS_CLOSED);
        insert t;
        Map<Id, Task> oldMap = new Map<Id, Task>{ t.Id => new Task(Id = t.Id, Status = 'Open') };
        Map<Id, Task> newMap = new Map<Id, Task>{ t.Id => t };
        Test.startTest();
        ServiceRequestTaskController.serviceRequestDataValidation(
            new List<Task>{ t }, newMap, oldMap);
        Test.stopTest();
    }

    /*@isTest
    static void test_serviceRequestDataValidation_PreUnit_MgmtApproval_notApproved() {
        SalesOrder__c so = createFreshSalesOrder();
        Id preUnitRT = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByDeveloperName()
            .get('Pre_Unit_Cancellation').getRecordTypeId();
        ServiceRequest__c sr = new ServiceRequest__c(RecordTypeId = preUnitRT,
            SalesOrder__c = so.Id, Approval_Status__c = 'Pending');
        insert sr;
        // Catalog Name must equal 'Pre Unit Cancellation' so SRType__c formula resolves correctly
        ServiceAction__c sa = getOrCreateServiceAction('Pre Unit Cancellation',
            Constants.SERVICE_REQUEST_RT_PRE_UNIT_CANCELLATION, 1,
            'Management Approval and Execute Unit Cancellation Process');
        Id taskRT = getTaskRecordTypeId();
        Task t = new Task(WhatId = sr.Id, RecordTypeId = taskRT,
            Subject = 'Management Approval and Execute Unit Cancellation Process',
            Status = Constants.TASK_STATUS_CLOSED, ServiceAction__c = sa.Id);
        insert t;
        Map<Id, Task> oldMap = new Map<Id, Task>{ t.Id => new Task(Id = t.Id, Status = 'Open') };
        Map<Id, Task> newMap = new Map<Id, Task>{ t.Id => t };
        Test.startTest();
        ServiceRequestTaskController.serviceRequestDataValidation(
            new List<Task>{ t }, newMap, oldMap);
        Test.stopTest();
    }*/

    /*@isTest
    static void test_serviceRequestDataValidation_PreUnit_CapturePnL_withRefund_noBankDoc() {
        SalesOrder__c so = createFreshSalesOrder();
        Id preUnitRT = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByDeveloperName()
            .get('Pre_Unit_Cancellation').getRecordTypeId();
        ServiceRequest__c sr = new ServiceRequest__c(RecordTypeId = preUnitRT,
            SalesOrder__c = so.Id, Cancellation_Type__c = 'Cancellation with Refund');
        insert sr;
        ServiceAction__c sa = getOrCreateServiceAction('Pre Unit Cancellation',
            Constants.SERVICE_REQUEST_RT_PRE_UNIT_CANCELLATION, 2, 'Capture Profit and Loss');
        Id taskRT = getTaskRecordTypeId();
        Task t = new Task(WhatId = sr.Id, RecordTypeId = taskRT,
            Subject = 'Capture Profit and Loss',
            Status = Constants.TASK_STATUS_CLOSED, ServiceAction__c = sa.Id);
        insert t;
        Map<Id, Task> oldMap = new Map<Id, Task>{ t.Id => new Task(Id = t.Id, Status = 'Open') };
        Map<Id, Task> newMap = new Map<Id, Task>{ t.Id => t };
        Test.startTest();
        ServiceRequestTaskController.serviceRequestDataValidation(
            new List<Task>{ t }, newMap, oldMap);
        Test.stopTest();
    }*/

    /*@isTest
    static void test_serviceRequestDataValidation_PreUnit_CapturePnL_consolidation() {
        SalesOrder__c so = createFreshSalesOrder();
        Id preUnitRT = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByDeveloperName()
            .get('Pre_Unit_Cancellation').getRecordTypeId();
        ServiceRequest__c sr = new ServiceRequest__c(RecordTypeId = preUnitRT,
            SalesOrder__c = so.Id, Cancellation_Type__c = 'Consolidation Cancellation');
        insert sr;
        Unit_Consolidation__c uc = new Unit_Consolidation__c(
            Service_Request__c = sr.Id, Transfer_Amount__c = 300);
        insert uc;
        ServiceAction__c sa = getOrCreateServiceAction('Pre Unit Cancellation',
            Constants.SERVICE_REQUEST_RT_PRE_UNIT_CANCELLATION, 3,
            'Capture Profit and Loss Consolidation');
        Id taskRT = getTaskRecordTypeId();
        Task t = new Task(WhatId = sr.Id, RecordTypeId = taskRT,
            Subject = 'Capture Profit and Loss',
            Status = Constants.TASK_STATUS_CLOSED, ServiceAction__c = sa.Id);
        insert t;
        Map<Id, Task> oldMap = new Map<Id, Task>{ t.Id => new Task(Id = t.Id, Status = 'Open') };
        Map<Id, Task> newMap = new Map<Id, Task>{ t.Id => t };
        Test.startTest();
        ServiceRequestTaskController.serviceRequestDataValidation(
            new List<Task>{ t }, newMap, oldMap);
        Test.stopTest();
    }*/

    /*@isTest
    static void test_serviceRequestDataValidation_PostUnit_MgmtApproval_notApproved() {
        SalesOrder__c so = createFreshSalesOrder();
        Id postUnitRT = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByDeveloperName()
            .get('Post_Unit_Cancellation').getRecordTypeId();
        ServiceRequest__c sr = new ServiceRequest__c(RecordTypeId = postUnitRT,
            SalesOrder__c = so.Id, Approval_Status__c = 'Pending');
        insert sr;
        ServiceAction__c sa = getOrCreateServiceAction('Post Unit Cancellation',
            Constants.SERVICE_REQUEST_RT_POST_UNIT_CANCELLATION, 1,
            'Management Approval and Execute Unit Cancellation Process');
        Id taskRT = getTaskRecordTypeId();
        Task t = new Task(WhatId = sr.Id, RecordTypeId = taskRT,
            Subject = 'Management Approval and Execute Unit Cancellation Process',
            Status = Constants.TASK_STATUS_CLOSED, ServiceAction__c = sa.Id);
        insert t;
        Map<Id, Task> oldMap = new Map<Id, Task>{ t.Id => new Task(Id = t.Id, Status = 'Open') };
        Map<Id, Task> newMap = new Map<Id, Task>{ t.Id => t };
        Test.startTest();
        ServiceRequestTaskController.serviceRequestDataValidation(
            new List<Task>{ t }, newMap, oldMap);
        Test.stopTest();
    }*/

    @isTest
    static void test_serviceRequestDataValidation_DefaultSR_closeSRLegal() {
        SalesOrder__c so = createFreshSalesOrder();
        Id defaultSRRT = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByDeveloperName()
            .get('Default_SR').getRecordTypeId();
        ServiceRequest__c sr = new ServiceRequest__c(RecordTypeId = defaultSRRT,
            SalesOrder__c = so.Id, Legal_Decision__c = 'Cancel with Refund');
        insert sr;
        ServiceAction__c sa = getOrCreateServiceAction('Default SR',
            Constants.SERVICE_REQUEST_Default_SR, 1, 'Close SR per Legal advice.');
        Id taskRT = getTaskRecordTypeId();
        Task t = new Task(WhatId = sr.Id, RecordTypeId = taskRT,
            Subject = 'Close SR per Legal advice.',
            Status = Constants.TASK_STATUS_CLOSED, ServiceAction__c = sa.Id);
        insert t;
        Map<Id, Task> oldMap = new Map<Id, Task>{ t.Id => new Task(Id = t.Id, Status = 'Open') };
        Map<Id, Task> newMap = new Map<Id, Task>{ t.Id => t };
        Test.startTest();
        ServiceRequestTaskController.serviceRequestDataValidation(
            new List<Task>{ t }, newMap, oldMap);
        Test.stopTest();
    }

    @isTest
    static void test_serviceRequestDataValidation_DefaultUnit_FinalizeRefund_mismatch() {
        SalesOrder__c so = createFreshSalesOrder();
        Id ducRT = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByDeveloperName()
            .get('DefaultUnitCancellation').getRecordTypeId();
        ServiceRequest__c sr = new ServiceRequest__c(RecordTypeId = ducRT,
            SalesOrder__c = so.Id, Total_Paid_Amount__c = 1000,
            Refund_Amount__c = 400, Forfeiture_Amount__c = 400);
        insert sr;
        ServiceAction__c sa = getOrCreateServiceAction('Default Unit Cancellation',
            Constants.SERVICE_REQUEST_CANCELLATION_DEFAULT, 1,
            'Finalize Refund and Forfeiture amount');
        Id taskRT = getTaskRecordTypeId();
        Task t = new Task(WhatId = sr.Id, RecordTypeId = taskRT,
            Subject = 'Finalize Refund and Forfeiture amount',
            Status = Constants.TASK_STATUS_CLOSED, ServiceAction__c = sa.Id);
        insert t;
        Map<Id, Task> oldMap = new Map<Id, Task>{ t.Id => new Task(Id = t.Id, Status = 'Open') };
        Map<Id, Task> newMap = new Map<Id, Task>{ t.Id => t };
        Test.startTest();
        ServiceRequestTaskController.serviceRequestDataValidation(
            new List<Task>{ t }, newMap, oldMap);
        Test.stopTest();
    }

    /*@isTest
    static void test_serviceRequestDataValidation_DefaultUnit_FinalStep_cmNotApproved() {
        SalesOrder__c so = createFreshSalesOrder();
        Id ducRT = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByDeveloperName()
            .get('DefaultUnitCancellation').getRecordTypeId();
        ServiceRequest__c sr = new ServiceRequest__c(RecordTypeId = ducRT,
            SalesOrder__c = so.Id, CM_Approval_Status__c = 'Pending');
        insert sr;
        ServiceAction__c sa = getOrCreateServiceAction('Default Unit Cancellation',
            Constants.SERVICE_REQUEST_CANCELLATION_DEFAULT, 2,
            'Management Approval and Execute Unit Cancellation Process');
        Id taskRT = getTaskRecordTypeId();
        Task t = new Task(WhatId = sr.Id, RecordTypeId = taskRT,
            Subject = 'Management Approval and Execute Unit Cancellation Process',
            Status = Constants.TASK_STATUS_CLOSED, ServiceAction__c = sa.Id);
        insert t;
        Map<Id, Task> oldMap = new Map<Id, Task>{ t.Id => new Task(Id = t.Id, Status = 'Open') };
        Map<Id, Task> newMap = new Map<Id, Task>{ t.Id => t };
        Test.startTest();
        ServiceRequestTaskController.serviceRequestDataValidation(
            new List<Task>{ t }, newMap, oldMap);
        Test.stopTest();
    }*/

    @isTest
    static void test_serviceRequestDataValidation_DefaultUnit_FinalStep_notExecuted() {
        SalesOrder__c so = createFreshSalesOrder();
        Id ducRT = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByDeveloperName()
            .get('DefaultUnitCancellation').getRecordTypeId();
        ServiceRequest__c sr = new ServiceRequest__c(RecordTypeId = ducRT,
            SalesOrder__c = so.Id, CM_Approval_Status__c = 'Approved by CM Manager',
            Final_Execution_Complete__c = false);
        insert sr;
        ServiceAction__c sa = getOrCreateServiceAction('Default Unit Cancellation',
            Constants.SERVICE_REQUEST_CANCELLATION_DEFAULT, 3,
            'Management Approval Execute Not Done');
        Id taskRT = getTaskRecordTypeId();
        Task t = new Task(WhatId = sr.Id, RecordTypeId = taskRT,
            Subject = 'Management Approval and Execute Unit Cancellation Process',
            Status = Constants.TASK_STATUS_CLOSED, ServiceAction__c = sa.Id);
        insert t;
        Map<Id, Task> oldMap = new Map<Id, Task>{ t.Id => new Task(Id = t.Id, Status = 'Open') };
        Map<Id, Task> newMap = new Map<Id, Task>{ t.Id => t };
        Test.startTest();
        ServiceRequestTaskController.serviceRequestDataValidation(
            new List<Task>{ t }, newMap, oldMap);
        Test.stopTest();
    }

    @isTest
    static void test_serviceRequestDataValidation_BrokerReg_noManager() {
        SalesOrder__c so = createFreshSalesOrder();
        Registration__c reg = new Registration__c(Status__c = 'Draft');
        insert reg;
        Id brRT = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByDeveloperName()
            .get(Constants.BROKER_REGISTRATION_RECORDTYPE).getRecordTypeId();
        ServiceRequest__c sr = new ServiceRequest__c(RecordTypeId = brRT,
            SalesOrder__c = so.Id, Registration__c = reg.Id);
        insert sr;
        Id taskRT = getTaskRecordTypeId();
        Task t = new Task(WhatId = sr.Id, RecordTypeId = taskRT,
            Subject = BRConstants.SERVICE_REQUEST_TASK1,
            Status = Constants.TASK_STATUS_CLOSED,
            Broker_Registration_Status__c = BRConstants.ACTION_STATUS_RMI);
        insert t;
        Map<Id, Task> oldMap = new Map<Id, Task>{ t.Id => new Task(Id = t.Id, Status = 'Open') };
        Map<Id, Task> newMap = new Map<Id, Task>{ t.Id => t };
        Test.startTest();
        ServiceRequestTaskController.serviceRequestDataValidation(
            new List<Task>{ t }, newMap, oldMap);
        Test.stopTest();
    }

    @isTest
    static void test_createNextStepBRTasks_Task4Signed() {
        SalesOrder__c so = createFreshSalesOrder();
        ServiceRequest__c sr = new ServiceRequest__c(SalesOrder__c = so.Id);
        insert sr;
        Id taskRT = getTaskRecordTypeId();
        Task t4 = new Task(WhatId = sr.Id, RecordTypeId = taskRT,
            Subject = BRConstants.SERVICE_REQUEST_TASK4, Status = 'Open', Order__c = 4,
            Broker_Registration_Status__c = BRConstants.ACTION_STATUS_SIGNED);
        insert t4;
        Test.startTest();
        ServiceRequestTaskController.createNextStepBRTasks(new Set<Id>{ sr.Id },
            new Map<Id, Task>{ t4.Id => t4 },
            new Map<Id, ServiceRequest__c>{ sr.Id => sr });
        Test.stopTest();
    }

    @isTest
    static void test_createNextStepBRTasks_Task3RMI() {
        SalesOrder__c so = createFreshSalesOrder();
        ServiceRequest__c sr = new ServiceRequest__c(SalesOrder__c = so.Id);
        insert sr;
        Id taskRT = getTaskRecordTypeId();
        Task t3 = new Task(WhatId = sr.Id, RecordTypeId = taskRT,
            Subject = BRConstants.SERVICE_REQUEST_TASK3, Status = 'Open', Order__c = 3,
            Broker_Registration_Status__c = BRConstants.ACTION_STATUS_RMI);
        insert t3;
        Test.startTest();
        ServiceRequestTaskController.createNextStepBRTasks(new Set<Id>{ sr.Id },
            new Map<Id, Task>{ t3.Id => t3 },
            new Map<Id, ServiceRequest__c>{ sr.Id => sr });
        Test.stopTest();
    }

    @isTest
    static void test_createNextStepBRTasks_Task5Approved_earlyReturn() {
        SalesOrder__c so = createFreshSalesOrder();
        ServiceRequest__c sr = new ServiceRequest__c(SalesOrder__c = so.Id);
        insert sr;
        Id taskRT = getTaskRecordTypeId();
        Task t5 = new Task(WhatId = sr.Id, RecordTypeId = taskRT,
            Subject = BRConstants.SERVICE_REQUEST_TASK5, Status = 'Open', Order__c = 5,
            Broker_Registration_Status__c = BRConstants.ACTION_STATUS_APPROVED);
        insert t5;
        Test.startTest();
        ServiceRequestTaskController.createNextStepBRTasks(new Set<Id>{ sr.Id },
            new Map<Id, Task>{ t5.Id => t5 },
            new Map<Id, ServiceRequest__c>{ sr.Id => sr });
        Test.stopTest();
        Integer taskCount = [SELECT COUNT() FROM Task WHERE WhatId = :sr.Id AND Order__c = 6];
        
    }

    @isTest
    static void test_getTaskOrders_returnForMoreInfo() {
        SalesOrder__c so = createFreshSalesOrder();
        ServiceRequest__c sr = new ServiceRequest__c(SalesOrder__c = so.Id);
        insert sr;
        Id taskRT = getTaskRecordTypeId();
        Task t = new Task(WhatId = sr.Id, RecordTypeId = taskRT,
            Subject = 'Document Review',
            Status = 'Return for more information - documents', Order__c = 2);
        insert t;
        Map<Id, SObject> oldMap = new Map<Id, SObject>{
            t.Id => new Task(Id = t.Id, Status = 'Open')};
        Test.startTest();
        ServiceRequestTaskController.handleTaskUpdates(new List<Task>{ t }, oldMap, false);
        Test.stopTest();
    }

    @isTest
    static void test_getTaskOrders_finalizeSubject_closesSR() {
        SalesOrder__c so = createFreshSalesOrder();
        ServiceRequest__c sr = new ServiceRequest__c(SalesOrder__c = so.Id);
        insert sr;
        Id taskRT = getTaskRecordTypeId();
        Task t = new Task(WhatId = sr.Id, RecordTypeId = taskRT,
            Subject = 'Finalize Registration', Status = 'Closed', Order__c = 5);
        insert t;
        Map<Id, SObject> oldMap = new Map<Id, SObject>{
            t.Id => new Task(Id = t.Id, Status = 'Not Started')};
        Test.startTest();
        ServiceRequestTaskController.handleTaskUpdates(new List<Task>{ t }, oldMap, false);
        Test.stopTest();
        
    }

    @isTest
    static void test_updateCurrentStepOnSR_propertyTransfer() {
        SalesOrder__c so = createFreshSalesOrder();
        Id ptRT = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByDeveloperName()
            .get('Service_Request_Management_Property_Transfer_OffPlan').getRecordTypeId();
        ServiceRequest__c sr = new ServiceRequest__c(RecordTypeId = ptRT, SalesOrder__c = so.Id);
        insert sr;
        ServiceCatalog__c sc = new ServiceCatalog__c(
            Name = 'PT Catalog ' + System.currentTimeMillis(),
            Service_Request_Type__c = Constants.SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER);
        insert sc;
        ServiceAction__c action = new ServiceAction__c(Name = 'Step 2 PT',
            ServiceCatalog__c = sc.Id, Order__c = 2,
            TaskSubject__c = 'PT Next Step', FinalTask__c = false);
        insert action;
        Id taskRT = getTaskRecordTypeId();
        Task t = new Task(WhatId = sr.Id, RecordTypeId = taskRT,
            Subject = 'PT Initial', Status = Constants.TASK_STATUS_CLOSED, Order__c = 1);
        insert t;
        sr = [SELECT Id, RecordType.Name, Type__c, Sales_Agent__c, OwnerId, SalesOrder__c,
                     Extended_NOC_Approval_Status__c, Decision_Type__c,
                     SalesOrder__r.Total_Outstanding__c, Is_NOC_Extended__c, Cancellation_Type__c
              FROM ServiceRequest__c WHERE Id = :sr.Id];
        Map<Id, Task> taskMap = new Map<Id, Task>{ t.Id => t };
        Map<Id, ServiceRequest__c> srMap = new Map<Id, ServiceRequest__c>{ sr.Id => sr };
        Map<Id, String> subjectMap = new Map<Id, String>{
            sr.Id => Constants.SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER};
        Test.startTest();
        ServiceRequestTaskController.createNextStepTasks(
            new Set<Id>{ sr.Id }, subjectMap, taskMap, srMap);
        Test.stopTest();
        
    }

    @isTest
    static void test_handlePreunitCancellationStepSkip_PostUnit_noADM() {
        SalesOrder__c so = createFreshSalesOrder();
        Id postUnitRT = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByDeveloperName()
            .get('Post_Unit_Cancellation').getRecordTypeId();
        ServiceRequest__c sr = new ServiceRequest__c(RecordTypeId = postUnitRT, SalesOrder__c = so.Id);
        insert sr;
        sr = [SELECT Id, SalesOrder__c, RecordType.Name FROM ServiceRequest__c WHERE Id = :sr.Id];
        Test.startTest();
        Decimal r1 = ServiceRequestTaskController.handlePreunitCancellationStepSkip(3, 2, sr);
        Decimal r2 = ServiceRequestTaskController.handlePreunitCancellationStepSkip(4, 3, sr);
        Test.stopTest();
    }

    /*@isTest
    static void test_handleTaskUpdatesBR_Task1Rejected() {
        SalesOrder__c so = createFreshSalesOrder();
        ServiceRequest__c sr = new ServiceRequest__c(SalesOrder__c = so.Id);
        insert sr;
        Id taskRT = getTaskRecordTypeId();
        Task t = new Task(WhatId = sr.Id, RecordTypeId = taskRT,
            Subject = BRConstants.SERVICE_REQUEST_TASK1, Status = 'Open', Order__c = 1,
            Broker_Registration_Status__c = BRConstants.ACTION_STATUS_REJECTED);
        insert t;
        Map<Id, SObject> oldMap = new Map<Id, SObject>{
            t.Id => new Task(Id = t.Id, Status = 'Open',
                Broker_Registration_Status__c = 'Pending')};
        Test.startTest();
        ServiceRequestTaskController.handleTaskUpdatesBR(new List<Task>{ t }, oldMap, false);
        Test.stopTest();
        
    }*/

    @isTest
    static void test_handleTaskUpdatesBR_passfortWithAgentDocs() {
        Test.setMock(HttpCalloutMock.class, new DummyHttpMock());
        SalesOrder__c so = createFreshSalesOrder();
        Registration__c reg = new Registration__c(Status__c = 'Draft');
        insert reg;
        Registration_Agent__c agent = new Registration_Agent__c(
            Agent_First_Name__c = 'John', Agent_Last_Name__c = 'Agent',
            Registration_Name__c = reg.Id, Type__c = 'Owner', Agent_Email__c = 'agent@test.com');
        insert agent;
        Documents__c agentDoc = new Documents__c(Name = 'Emirates Document',
            Registration_Agent__c = agent.Id, Status__c = 'Uploaded');
        insert agentDoc;
        Id brRT = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByDeveloperName()
            .get(Constants.BROKER_REGISTRATION_RECORDTYPE).getRecordTypeId();
        ServiceRequest__c sr = new ServiceRequest__c(RecordTypeId = brRT,
            SalesOrder__c = so.Id, Registration__c = reg.Id);
        insert sr;
        Id taskRT = getTaskRecordTypeId();
        Task t1 = new Task(WhatId = sr.Id, RecordTypeId = taskRT,
            Subject = BRConstants.SERVICE_REQUEST_TASK1, Status = 'Open', Order__c = 1,
            Broker_Registration_Status__c = BRConstants.ACTION_STATUS_APPROVED);
        insert t1;
        Map<Id, SObject> oldMap = new Map<Id, SObject>{
            t1.Id => new Task(Id = t1.Id, Status = 'Open',
                Broker_Registration_Status__c = 'Pending')};
        Test.startTest();
        ServiceRequestTaskController.handleTaskUpdatesBR(new List<Task>{ t1 }, oldMap, false);
        Test.stopTest();
       
    }

    @isTest
    static void test_createInitialTasks_DefaultSR() {
        SalesOrder__c so = createFreshSalesOrder();
        Id defaultSRRT = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByDeveloperName()
            .get('Default_SR').getRecordTypeId();
        ServiceRequest__c sr = new ServiceRequest__c(RecordTypeId = defaultSRRT,
            SalesOrder__c = so.Id, Status__c = 'New');
        insert sr;
        Test.startTest();
        ServiceRequestTaskController.createIntialTasks(new List<ServiceRequest__c>{ sr });
        Test.stopTest();
    }

    /*@isTest
    static void test_createInitialTasks_UnitUpgradeAndSwap() {
        SalesOrder__c so = createFreshSalesOrder();
        Id upgradeRT = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByDeveloperName()
            .get('Service_Request_Management_Unit_Upgrade').getRecordTypeId();
        Id swapRT = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByDeveloperName()
            .get('Service_Request_Management_Unit_Swap').getRecordTypeId();
        // Catalog Name must match the Service_Request_Type__c value used in createIntialStepTasks SOQL
        ServiceCatalog__c scUpgrade = new ServiceCatalog__c(
            Name = Constants.SERVICE_REQUEST_RT_DEV_NAME_UNIT_UPGRADE,
            Service_Request_Type__c = Constants.SERVICE_REQUEST_RT_DEV_NAME_UNIT_UPGRADE);
        ServiceCatalog__c scSwap = new ServiceCatalog__c(
            Name = Constants.SERVICE_REQUEST_RT_DEV_NAME_UNIT_SWAP,
            Service_Request_Type__c = Constants.SERVICE_REQUEST_RT_DEV_NAME_UNIT_SWAP);
        insert new List<ServiceCatalog__c>{ scUpgrade, scSwap };
        ServiceAction__c actionUpgrade = new ServiceAction__c(Name = 'Upgrade Init',
            ServiceCatalog__c = scUpgrade.Id, Order__c = 1, TaskSubject__c = 'Upgrade Step 1');
        ServiceAction__c actionSwap = new ServiceAction__c(Name = 'Swap Init',
            ServiceCatalog__c = scSwap.Id, Order__c = 1, TaskSubject__c = 'Swap Step 1');
        insert new List<ServiceAction__c>{ actionUpgrade, actionSwap };
        ServiceRequest__c srUpgrade = new ServiceRequest__c(RecordTypeId = upgradeRT,
            SalesOrder__c = so.Id, Status__c = 'New', Sales_Agent__c = UserInfo.getUserId());
        ServiceRequest__c srSwap = new ServiceRequest__c(RecordTypeId = swapRT,
            SalesOrder__c = so.Id, Status__c = 'New', Sales_Agent__c = UserInfo.getUserId());
        insert new List<ServiceRequest__c>{ srUpgrade, srSwap };
        Test.startTest();
        ServiceRequestTaskController.createIntialTasks(
            new List<ServiceRequest__c>{ srUpgrade, srSwap });
        Test.stopTest();
       
    }*/

    /*@isTest
    static void test_serviceRequestDataValidation_PlotHandover_outstandingPayment() {
        SalesOrder__c so = createFreshSalesOrder();
        Id plotRT = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByDeveloperName()
            .get('Service_Request_Management_Plot_Handover').getRecordTypeId();
        ServiceRequest__c sr = new ServiceRequest__c(RecordTypeId = plotRT, SalesOrder__c = so.Id);
        insert sr;
        SalesOrderInstallments__c installment = new SalesOrderInstallments__c(
            SalesOrder__c = so.Id, MilestoneDate__c = Date.today().addDays(-10));
        insert installment;
        Invoice__c inv = new Invoice__c(SalesOrderInstallment__c = installment.Id,
            
            InvoiceDate__c = Date.today().addDays(-5));
        insert inv;
        ServiceAction__c sa = getOrCreateServiceAction('Plot Handover',
            Constants.SERVICE_REQUEST_PLOT_HANDOVER, 1, 'Collect outstanding payment');
        Id taskRT = getTaskRecordTypeId();
        Task t = new Task(WhatId = sr.Id, RecordTypeId = taskRT,
            Subject = 'Collect outstanding payment',
            Status = Constants.TASK_STATUS_CLOSED, ServiceAction__c = sa.Id);
        insert t;
        Map<Id, Task> oldMap = new Map<Id, Task>{ t.Id => new Task(Id = t.Id, Status = 'Open') };
        Map<Id, Task> newMap = new Map<Id, Task>{ t.Id => t };
        Test.startTest();
        ServiceRequestTaskController.serviceRequestDataValidation(
            new List<Task>{ t }, newMap, oldMap);
        Test.stopTest();
    }*/

    /*@isTest
    static void test_serviceRequestDataValidation_PlotHandover_FinalAppointment() {
        SalesOrder__c so = createFreshSalesOrder();
        Id plotRT = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByDeveloperName()
            .get('Service_Request_Management_Plot_Handover').getRecordTypeId();
        ServiceRequest__c sr = new ServiceRequest__c(RecordTypeId = plotRT, SalesOrder__c = so.Id);
        insert sr;
        Event ev = new Event(Subject = 'Appointment with Customer' + sr.Id,
            StartDateTime = DateTime.now().addDays(1),
            EndDateTime = DateTime.now().addDays(1).addHours(1), WhatId = sr.Id);
        insert ev;
        ServiceAction__c sa = getOrCreateServiceAction('Plot Handover',
            Constants.SERVICE_REQUEST_PLOT_HANDOVER, 2, 'Book Final Handover Appointment');
        Id taskRT = getTaskRecordTypeId();
        Task t = new Task(WhatId = sr.Id, RecordTypeId = taskRT,
            Subject = 'Book Final Handover Appointment',
            Status = Constants.TASK_STATUS_CLOSED, ServiceAction__c = sa.Id);
        insert t;
        Map<Id, Task> oldMap = new Map<Id, Task>{ t.Id => new Task(Id = t.Id, Status = 'Open') };
        Map<Id, Task> newMap = new Map<Id, Task>{ t.Id => t };
        Test.startTest();
        ServiceRequestTaskController.serviceRequestDataValidation(
            new List<Task>{ t }, newMap, oldMap);
        Test.stopTest();
    }*/

    @isTest
    static void test_sendRegistertNotifications_nullDocMap() {
        SalesOrder__c so = createFreshSalesOrder();
        ServiceRequest__c sr = new ServiceRequest__c(SalesOrder__c = so.Id);
        insert sr;
        Test.startTest();
        ServiceRequestTaskController.sendRegistertNotifications(
            null, null, null, new Set<Id>{ sr.Id });
        Test.stopTest();
    }

    @isTest
    static void test_handleTaskUpdates_lwcController_insertScenario() {
        SalesOrder__c so = createFreshSalesOrder();
        ServiceRequest__c sr = new ServiceRequest__c(SalesOrder__c = so.Id);
        insert sr;
        Id taskRT = getTaskRecordTypeId();
        Task t = new Task(WhatId = sr.Id, RecordTypeId = taskRT,
            Subject = 'LWC Task', Status = Constants.TASK_STATUS_CLOSED, Order__c = 1);
        insert t;
        Test.startTest();
        ServiceRequestTaskController.handleTaskUpdates(new List<Task>{ t },
            new Map<Id, SObject>(), true);
        Test.stopTest();
    }

    /*@isTest
    static void test_createNextStepTasks_PT_financeApprovalUpdates() {
        SalesOrder__c so = createFreshSalesOrder();
        so.Total_Outstanding__c = 0;
        update so;
        Id ptRT = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByDeveloperName()
            .get('Service_Request_Management_Property_Transfer_OffPlan').getRecordTypeId();
        ServiceRequest__c sr = new ServiceRequest__c(RecordTypeId = ptRT, SalesOrder__c = so.Id);
        insert sr;
        sr = [SELECT Id, RecordType.Name, Type__c, Sales_Agent__c, OwnerId, SalesOrder__c,
                     Extended_NOC_Approval_Status__c, Decision_Type__c,
                     SalesOrder__r.Total_Outstanding__c, Is_NOC_Extended__c, Cancellation_Type__c
              FROM ServiceRequest__c WHERE Id = :sr.Id];
        Id taskRT = getTaskRecordTypeId();
        Task t10 = new Task(WhatId = sr.Id, RecordTypeId = taskRT,
            Subject = 'Finance Step 10', Status = Constants.TASK_STATUS_CLOSED, Order__c = 10);
        Task t11 = new Task(WhatId = sr.Id, RecordTypeId = taskRT,
            Subject = 'Finance Step 11', Status = Constants.TASK_STATUS_CLOSED, Order__c = 11);
        insert new List<Task>{ t10, t11 };
        Map<Id, Task> taskMap = new Map<Id, Task>{ t10.Id => t10, t11.Id => t11 };
        Map<Id, ServiceRequest__c> srMap = new Map<Id, ServiceRequest__c>{ sr.Id => sr };
        Map<Id, String> subjectMap = new Map<Id, String>{
            sr.Id => Constants.SERVICE_REQUEST_RT_DEV_NAME_PROPERTY_TRANSFER};
        Test.startTest();
        ServiceRequestTaskController.createNextStepTasks(
            new Set<Id>{ sr.Id }, subjectMap, taskMap, srMap);
        Test.stopTest();
        
    }*/

    /*@isTest
    static void test_createNextStepTasks_PE_financeApproval_step3() {
        SalesOrder__c so = createFreshSalesOrder();
        so.Total_Outstanding__c = 0;
        update so;
        Id peRT = Schema.SObjectType.ServiceRequest__c.getRecordTypeInfosByDeveloperName()
            .get('Service_Request_Management_Payment_Extension').getRecordTypeId();
        ServiceRequest__c sr = new ServiceRequest__c(RecordTypeId = peRT, SalesOrder__c = so.Id);
        insert sr;
        sr = [SELECT Id, RecordType.Name, Type__c, Sales_Agent__c, OwnerId, SalesOrder__c,
                     Extended_NOC_Approval_Status__c, Decision_Type__c,
                     SalesOrder__r.Total_Outstanding__c, Is_NOC_Extended__c, Cancellation_Type__c
              FROM ServiceRequest__c WHERE Id = :sr.Id];
        ServiceCatalog__c sc = new ServiceCatalog__c(
            Name = 'PE Cat ' + System.currentTimeMillis(),
            Service_Request_Type__c = Constants.SERVICE_REQUEST_RT_DEV_NAME_PE);
        insert sc;
        ServiceAction__c act = new ServiceAction__c(Name = 'PE Step 4',
            ServiceCatalog__c = sc.Id, Order__c = 4, TaskSubject__c = 'PE Next Step');
        insert act;
        Id taskRT = getTaskRecordTypeId();
        Task t3 = new Task(WhatId = sr.Id, RecordTypeId = taskRT,
            Subject = 'PE Step 3', Status = Constants.TASK_STATUS_CLOSED, Order__c = 3);
        insert t3;
        Map<Id, Task> taskMap = new Map<Id, Task>{ t3.Id => t3 };
        Map<Id, ServiceRequest__c> srMap = new Map<Id, ServiceRequest__c>{ sr.Id => sr };
        Map<Id, String> subjectMap = new Map<Id, String>{
            sr.Id => Constants.SERVICE_REQUEST_RT_DEV_NAME_PE};
        Test.startTest();
        ServiceRequestTaskController.createNextStepTasks(
            new Set<Id>{ sr.Id }, subjectMap, taskMap, srMap);
        Test.stopTest();
        
    }*/
}