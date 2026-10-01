@IsTest
private class PaymentPlanChangeControllerTest {

    @TestSetup
    static void setupData() {

        Account acc = new Account(
            LastName = 'Test Customer',
            PersonEmail = 'testcustomer@test.com',
            PersonMobilePhone = '+971500000000',
            EIDNumber__pc = '784-1234-1234567-1',
            CustomerType__c = 'VIP Client',
            Source_Entity__c = 'Modon - Egypt',
            EmiratesIDExpiryDate__pc = System.today().addDays(30),
            UAE_Resident_Status__pc = 'Resident',
            Nationality__pc = 'United Arab Emirates',
            RecordTypeId = Schema.SObjectType.Account
                .getRecordTypeInfosByName()
                .get('Person Account')
                .getRecordTypeId()
        );
        insert acc;

        Project__c project = new Project__c(
            Name = 'Test Project'
        );
        insert project;

        Phase__c phase = new Phase__c(
            Name = 'Test Phase',
            Project__c = project.Id
        );
        insert phase;

        Unit__c unit = new Unit__c(
            Name = 'Test Unit',
            Phase__c = phase.Id,
            PlotNo__c = 'PLOT-001',
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '4'
        );
        insert unit;

        PaymentPlan__c oldPlan = new PaymentPlan__c(
            Name = 'Old Payment Plan',
            Type__c = 'Standard',
            Phase__c = phase.Id,
            Status__c = 'Active',
            StartDate__c = Date.today().addDays(-30),
            ExpiryDate__c = Date.today().addDays(60)
        );

        PaymentPlan__c newPlan = new PaymentPlan__c(
            Name = 'New Payment Plan',
            Type__c = 'Standard',
            Phase__c = phase.Id,
            Status__c = 'Active',
            StartDate__c = Date.today().addDays(-30),
            ExpiryDate__c = Date.today().addDays(60)
        );

        insert new List<PaymentPlan__c>{ oldPlan, newPlan };

        List<PaymentInstallements__c> paymentInstallments =
            new List<PaymentInstallements__c>();

        for (Integer i = 1; i <= 3; i++) {
            paymentInstallments.add(new PaymentInstallements__c(
                PaymentInstallment__c = newPlan.Id,
                Name = 'Installment ' + i,
                MilestoneNumber__c = i,
                Milestone__c = 10 * i,
                MilestoneDate__c = Date.today().addDays(30 * i),
                MilestoneDescription__c = 'Milestone ' + i
            ));
        }

        insert paymentInstallments;

        SalesOrder__c so = new SalesOrder__c(
            CustomerAccount__c = acc.Id,
            Status__c = 'sold',
            Unit__c = unit.Id,
            PaymentPlan__c = oldPlan.Id,
            TotalAmount__c = 100000
        );
        insert so;

        List<SalesOrderInstallments__c> soInstallments =
            new List<SalesOrderInstallments__c>();

        soInstallments.add(new SalesOrderInstallments__c(
            SalesOrder__c = so.Id,
            InstallmentAmount__c = 10000,
            Milestone__c = 10,
          //  Milestone_Name__c = 'Booking',
            MilestoneDate__c = Date.today().addDays(10),
            MilestoneNumber__c = 1,
            PaymentStatus__c = 'Not Paid',
            Balance_Amount__c = 10000
        ));

        soInstallments.add(new SalesOrderInstallments__c(
            SalesOrder__c = so.Id,
            InstallmentAmount__c = 20000,
            Milestone__c = 20,
           // Milestone_Name__c = 'Construction',
            MilestoneDate__c = Date.today().addDays(20),
            MilestoneNumber__c = 2,
            PaymentStatus__c = 'Partially Paid',
            Balance_Amount__c = 6000
        ));

        soInstallments.add(new SalesOrderInstallments__c(
            SalesOrder__c = so.Id,
            InstallmentAmount__c = 30000,
            Milestone__c = 30,
          //  Milestone_Name__c = 'Handover',
            MilestoneDate__c = Date.today().addDays(30),
            MilestoneNumber__c = 3,
            PaymentStatus__c = 'Paid',
            Balance_Amount__c = 0
        ));

        insert soInstallments;
    }

    @IsTest
    static void testLoadScreen() {

        SalesOrder__c so = [
            SELECT Id
            FROM SalesOrder__c
            LIMIT 1
        ];

        Test.startTest();
        PaymentPlanChangeController.PaymentPlanDataWrapper result =
            PaymentPlanChangeController.loadScreen(so.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertEquals(100000, result.salesAmount);
        System.assert(result.paymentPlans.size() > 0);
        System.assertEquals(3, result.existingPlan.size());
        System.assertEquals(3, result.revisedPlan.size());
    }

    @IsTest
    static void testGetPaymentPlanInstallments() {

        PaymentPlan__c newPlan = [
            SELECT Id
            FROM PaymentPlan__c
            WHERE Name = 'New Payment Plan'
            LIMIT 1
        ];

        Test.startTest();
        List<PaymentPlanChangeController.InstallmentWrapper> result =
            PaymentPlanChangeController.getPaymentPlanInstallments(newPlan.Id);
        Test.stopTest();

        System.assertEquals(3, result.size());
        System.assertEquals('Pending', result[0].paymentStatus);
        System.assertEquals(true, result[0].isEditable);
    }

    @IsTest
    static void testSaveRevisedPlan() {

        List<SalesOrderInstallments__c> installments = [
            SELECT Id, PaymentStatus__c
            FROM SalesOrderInstallments__c
            ORDER BY MilestoneNumber__c
        ];

        List<PaymentPlanChangeController.InstallmentWrapper> revisedPlan =
            new List<PaymentPlanChangeController.InstallmentWrapper>();

        PaymentPlanChangeController.InstallmentWrapper wrap =
            new PaymentPlanChangeController.InstallmentWrapper();

        wrap.installmentId = installments[0].Id;
        wrap.milestone = 15;
        wrap.amount = 15000;

        revisedPlan.add(wrap);

        Test.startTest();
        String result =
            PaymentPlanChangeController.saveRevisedPlan(revisedPlan);
        Test.stopTest();

        System.assertEquals('Success', result);

        SalesOrderInstallments__c updatedInst = [
            SELECT Milestone__c, InstallmentAmount__c
            FROM SalesOrderInstallments__c
            WHERE Id = :installments[0].Id
        ];

        System.assertEquals(15, updatedInst.Milestone__c);
        System.assertEquals(15000, updatedInst.InstallmentAmount__c);
    }

    @IsTest
    static void testSaveRevisedPlanNoRecords() {

        Test.startTest();
        String result =
            PaymentPlanChangeController.saveRevisedPlan(
                new List<PaymentPlanChangeController.InstallmentWrapper>()
            );
        Test.stopTest();

        System.assertEquals('No Records', result);
    }

    @IsTest
    static void testSaveToStaging() {

        SalesOrder__c so = [
            SELECT Id
            FROM SalesOrder__c
            LIMIT 1
        ];

        PaymentPlan__c newPlan = [
            SELECT Id
            FROM PaymentPlan__c
            WHERE Name = 'New Payment Plan'
            LIMIT 1
        ];

        PaymentInstallements__c paymentInst = [
            SELECT Id
            FROM PaymentInstallements__c
            LIMIT 1
        ];

        SalesOrderInstallments__c soInst = [
            SELECT Id, Balance_Amount__c
            FROM SalesOrderInstallments__c
            WHERE PaymentStatus__c = 'Partially Paid'
            LIMIT 1
        ];

        List<PaymentPlanChangeController.RevisedInstallmentWrapper> revisedList =
            new List<PaymentPlanChangeController.RevisedInstallmentWrapper>();

        PaymentPlanChangeController.RevisedInstallmentWrapper row =
            new PaymentPlanChangeController.RevisedInstallmentWrapper();

        row.installmentId = soInst.Id;
        row.paymentPlanInstallmentId = paymentInst.Id;
        row.installment = 'Revised Installment';
        row.milestone = 20;
        row.amount = 20000;
        row.paymentStatus = 'Partially Paid';
        row.milestoneNumber = 2;
        row.milestoneName = 'Revised Milestone';
        row.milestoneDate = Date.today().addDays(20);
        row.balanceAmount = 6000;
        row.requiresUnallocation = true;

        revisedList.add(row);

        String jsonBody = JSON.serialize(revisedList);

        Test.startTest();
        Id requestId =
            PaymentPlanChangeController.saveToStaging(
                so.Id,
                newPlan.Id,
                jsonBody
            );
        Test.stopTest();

        System.assertNotEquals(null, requestId);

        PaymentPlanChangeRequest__c req = [
            SELECT Id, Status__c, Sales_Order__c, Revised_Payment_Plan__c
            FROM PaymentPlanChangeRequest__c
            WHERE Id = :requestId
        ];

        System.assertEquals('Draft', req.Status__c);
        System.assertEquals(so.Id, req.Sales_Order__c);
        System.assertEquals(newPlan.Id, req.Revised_Payment_Plan__c);

        List<PaymentPlanChangeLine__c> lines = [
            SELECT Id, Change_Request__c, Needs_Unallocation__c, Outstanding_Amount__c
            FROM PaymentPlanChangeLine__c
            WHERE Change_Request__c = :requestId
        ];

        System.assertEquals(1, lines.size());
        System.assertEquals(true, lines[0].Needs_Unallocation__c);
        System.assertEquals(6000, lines[0].Outstanding_Amount__c);
    }

   // @IsTest
    static void testSaveToStagingNullSalesOrder() {

        PaymentPlan__c newPlan = [
            SELECT Id
            FROM PaymentPlan__c
            WHERE Name = 'New Payment Plan'
            LIMIT 1
        ];

        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            PaymentPlanChangeController.saveToStaging(
                null,
                newPlan.Id,
                '[]'
            );
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown);
    }

    @IsTest
    static void testSaveToStagingNullPaymentPlan() {

        SalesOrder__c so = [
            SELECT Id
            FROM SalesOrder__c
            LIMIT 1
        ];

        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            PaymentPlanChangeController.saveToStaging(
                so.Id,
                null,
                '[]'
            );
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown);
    }

    @IsTest
    static void testSaveToStagingEmptyPlan() {

        SalesOrder__c so = [
            SELECT Id
            FROM SalesOrder__c
            LIMIT 1
        ];

        PaymentPlan__c newPlan = [
            SELECT Id
            FROM PaymentPlan__c
            WHERE Name = 'New Payment Plan'
            LIMIT 1
        ];

        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            PaymentPlanChangeController.saveToStaging(
                so.Id,
                newPlan.Id,
                '[]'
            );
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown);
    }

    @IsTest
    static void testIsEmployeePaymentPlanApplied() {

        SalesOrder__c so = [
            SELECT Id, CustomerAccount__c
            FROM SalesOrder__c
            LIMIT 1
        ];

        Account acc = new Account(
            Id = so.CustomerAccount__c,
            Is_Employee_Payment_Plan_Applied__c = true
        );
        update acc;

        Test.startTest();
        Boolean result =
            PaymentPlanChangeController.IsEmployeePaymentPlanApplied(so.Id);
        Test.stopTest();

        System.assertEquals(true, result);
    }

    @IsTest
    static void testApproveRequest() {

        SalesOrder__c so = [
            SELECT Id, PaymentPlan__c
            FROM SalesOrder__c
            LIMIT 1
        ];

        PaymentPlan__c newPlan = [
            SELECT Id
            FROM PaymentPlan__c
            WHERE Name = 'New Payment Plan'
            LIMIT 1
        ];

        PaymentPlanChangeRequest__c req =
            new PaymentPlanChangeRequest__c(
                Sales_Order__c = so.Id,
                Existing_Payment_Plan__c = so.PaymentPlan__c,
                Revised_Payment_Plan__c = newPlan.Id,
                Status__c = 'Draft',
                Submitted_By__c = UserInfo.getUserId(),
                Submitted_Date__c = System.now()
            );

        insert req;

        Test.startTest();
        PaymentPlanChangeController.approveRequest(req.Id);
        Test.stopTest();

        PaymentPlanChangeRequest__c updatedReq = [
            SELECT Status__c
            FROM PaymentPlanChangeRequest__c
            WHERE Id = :req.Id
        ];

        System.assertEquals('Approved', updatedReq.Status__c);
    }

    @IsTest
    static void testApproveRequestInvalidStatus() {

        SalesOrder__c so = [
            SELECT Id, PaymentPlan__c
            FROM SalesOrder__c
            LIMIT 1
        ];

        PaymentPlan__c newPlan = [
            SELECT Id
            FROM PaymentPlan__c
            WHERE Name = 'New Payment Plan'
            LIMIT 1
        ];

        PaymentPlanChangeRequest__c req =
            new PaymentPlanChangeRequest__c(
                Sales_Order__c = so.Id,
                Existing_Payment_Plan__c = so.PaymentPlan__c,
                Revised_Payment_Plan__c = newPlan.Id,
                Status__c = 'Approved',
                Submitted_By__c = UserInfo.getUserId(),
                Submitted_Date__c = System.now()
            );

        insert req;

        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            PaymentPlanChangeController.approveRequest(req.Id);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown);
    }

    @IsTest
    static void testApproveRequestNullId() {

        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            PaymentPlanChangeController.approveRequest(null);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown);
    }
}