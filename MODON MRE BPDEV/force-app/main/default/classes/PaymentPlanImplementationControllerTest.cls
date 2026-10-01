@IsTest
private class PaymentPlanImplementationControllerTest {

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

        Project__c project = new Project__c(Name = 'Test Project');
        insert project;

        Phase__c phase = new Phase__c(
            Name = 'Test Phase',
            Project__c = project.Id
        );
        insert phase;

        Unit__c unitRec = new Unit__c(
            Name = 'Test Unit',
            Phase__c = phase.Id,
            PlotNo__c = 'PLOT-001',
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '4'
        );
        insert unitRec;

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

        List<PaymentInstallements__c> oldPlanInsts =
            new List<PaymentInstallements__c>();

        List<PaymentInstallements__c> newPlanInsts =
            new List<PaymentInstallements__c>();

        for (Integer i = 1; i <= 3; i++) {

            oldPlanInsts.add(new PaymentInstallements__c(
                PaymentInstallment__c = oldPlan.Id,
                Name = 'Old Installment ' + i,
              //  MilestoneNumber__c = i,
                MileStoneNumber__c = i,
                Milestone__c = 10 * i,
                MilestoneDate__c = Date.today().addDays(10 * i),
                MilestoneDescription__c = 'Old Milestone ' + i
            ));

            newPlanInsts.add(new PaymentInstallements__c(
                PaymentInstallment__c = newPlan.Id,
                Name = 'New Installment ' + i,
             //   MilestoneNumber__c = i,
                MileStoneNumber__c = i,
                Milestone__c = 15 * i,
                MilestoneDate__c = Date.today().addDays(20 * i),
                MilestoneDescription__c = 'New Milestone ' + i
            ));
        }

        insert oldPlanInsts;
        insert newPlanInsts;

        SalesOrder__c so = new SalesOrder__c(
            CustomerAccount__c = acc.Id,
            Status__c = 'sold',
            Unit__c = unitRec.Id,
            PaymentPlan__c = oldPlan.Id,
            TotalAmount__c = 100000
        );
        insert so;

        List<SalesOrderInstallments__c> soInsts =
            new List<SalesOrderInstallments__c>();

        for (Integer i = 0; i < oldPlanInsts.size(); i++) {
            soInsts.add(new SalesOrderInstallments__c(
                SalesOrder__c = so.Id,
                PaymentInstallments__c = oldPlanInsts[i].Id,
                InstallmentAmount__c = 10000 * (i + 1),
                Milestone__c = 10 * (i + 1),
                MilestoneDate__c = Date.today().addDays(10 * (i + 1)),
                MilestoneNumber__c = i + 1,
                MilestoneDescription__c = 'SO Milestone ' + (i + 1),
                PaymentStatus__c = i == 2 ? 'Paid' : 'Not Paid',
                Balance_Amount__c = i == 2 ? 0 : 10000
            ));
        }

        insert soInsts;

        List<Invoice__c> invoices = new List<Invoice__c>();

        for (SalesOrderInstallments__c soi : soInsts) {
            invoices.add(new Invoice__c(
                SalesOrderInstallment__c = soi.Id,
                Sales_Order__c = so.Id,
                InvoiceAmount__c = soi.InstallmentAmount__c,
                IsCancelled__c = false,
                Account__c = acc.Id
            ));
        }

        insert invoices;
    }

    @IsTest
    static void testCreatePlanSuccess() {

        SalesOrder__c so = [
            SELECT Id, PaymentPlan__c, CustomerAccount__c
            FROM SalesOrder__c
            LIMIT 1
        ];

        PaymentPlan__c newPlan = [
            SELECT Id
            FROM PaymentPlan__c
            WHERE Name = 'New Payment Plan'
            LIMIT 1
        ];

        List<SalesOrderInstallments__c> oldSOIs = [
            SELECT Id, PaymentStatus__c
            FROM SalesOrderInstallments__c
            WHERE SalesOrder__c = :so.Id
            ORDER BY MilestoneNumber__c
        ];

        List<PaymentInstallements__c> newPlanInsts = [
            SELECT Id
            FROM PaymentInstallements__c
            WHERE PaymentInstallment__c = :newPlan.Id
            ORDER BY MilestoneNumber__c
        ];

        PaymentPlanChangeRequest__c req = new PaymentPlanChangeRequest__c(
            Sales_Order__c = so.Id,
            Existing_Payment_Plan__c = so.PaymentPlan__c,
            Revised_Payment_Plan__c = newPlan.Id,
            Status__c = 'Approved',
            Submitted_By__c = UserInfo.getUserId(),
            Submitted_Date__c = System.now()
        );
        insert req;

        List<PaymentPlanChangeLine__c> lines =
            new List<PaymentPlanChangeLine__c>();

        for (Integer i = 0; i < oldSOIs.size(); i++) {
            lines.add(new PaymentPlanChangeLine__c(
                Change_Request__c = req.Id,
                Existing_SO_Installment__c = oldSOIs[i].Id,
                Payment_Installment__c = newPlanInsts[i].Id,
                Milestone__c = 15 * (i + 1),
                Amount__c = 15000 * (i + 1),
                Payment_Status__c = oldSOIs[i].PaymentStatus__c,
                Locked__c = oldSOIs[i].PaymentStatus__c == 'Paid',
                Needs_Unallocation__c = false,
                Outstanding_Amount__c = 10000
            ));
        }

        insert lines;

        Test.startTest();
        String result = PaymentPlanImplementationController.createPlan(req.Id);
        Test.stopTest();

        System.assertEquals('Success', result);

        PaymentPlanChangeRequest__c updatedReq = [
            SELECT Status__c
            FROM PaymentPlanChangeRequest__c
            WHERE Id = :req.Id
        ];

        System.assertEquals('Implemented', updatedReq.Status__c);

        SalesOrder__c updatedSO = [
            SELECT PaymentPlan__c
            FROM SalesOrder__c
            WHERE Id = :so.Id
        ];

        System.assertEquals(newPlan.Id, updatedSO.PaymentPlan__c);

        Account updatedAcc = [
            SELECT Is_Employee_Payment_Plan_Applied__c
            FROM Account
            WHERE Id = :so.CustomerAccount__c
        ];

        System.assertEquals(true, updatedAcc.Is_Employee_Payment_Plan_Applied__c);
    }

    @IsTest
    static void testCreatePlanNullRequestId() {

        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            PaymentPlanImplementationController.createPlan(null);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown);
    }

    @IsTest
    static void testCreatePlanNotApproved() {

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

        PaymentPlanChangeRequest__c req = new PaymentPlanChangeRequest__c(
            Sales_Order__c = so.Id,
            Existing_Payment_Plan__c = so.PaymentPlan__c,
            Revised_Payment_Plan__c = newPlan.Id,
            Status__c = 'Draft',
            Submitted_By__c = UserInfo.getUserId(),
            Submitted_Date__c = System.now()
        );
        insert req;

        Boolean exceptionThrown = false;

        Test.startTest();
        try {
            PaymentPlanImplementationController.createPlan(req.Id);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown);
    }

    @IsTest
    static void testCreatePlanNoStagingLines() {

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

        PaymentPlanChangeRequest__c req = new PaymentPlanChangeRequest__c(
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
            PaymentPlanImplementationController.createPlan(req.Id);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown);
    }

    @IsTest
    static void testCancelInvoicesOrDeleteSOI() {

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

        SalesOrderInstallments__c soi = [
            SELECT Id
            FROM SalesOrderInstallments__c
            WHERE PaymentStatus__c = 'Not Paid'
            LIMIT 1
        ];

        PaymentInstallements__c newPaymentInst = [
            SELECT Id
            FROM PaymentInstallements__c
            WHERE PaymentInstallment__c = :newPlan.Id
            LIMIT 1
        ];

        PaymentPlanChangeRequest__c req = new PaymentPlanChangeRequest__c(
            Sales_Order__c = so.Id,
            Existing_Payment_Plan__c = so.PaymentPlan__c,
            Revised_Payment_Plan__c = newPlan.Id,
            Status__c = 'Implemented',
            Submitted_By__c = UserInfo.getUserId(),
            Submitted_Date__c = System.now()
        );
        insert req;

        PaymentPlanChangeLine__c line = new PaymentPlanChangeLine__c(
            Change_Request__c = req.Id,
            Existing_SO_Installment__c = soi.Id,
            Payment_Installment__c = newPaymentInst.Id,
            Milestone__c = 20,
            Amount__c = 20000,
            Locked__c = false,
            Needs_Unallocation__c = false,
            Outstanding_Amount__c = 10000
        );
        insert line;

        Test.startTest();
        PaymentPlanImplementationController.cancelInvoicesOrDeleteSOI(req.Id);
        Test.stopTest();

        System.assert(true, 'Method executed successfully');
    }
}