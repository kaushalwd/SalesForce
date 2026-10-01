@IsTest
public class SOIDefaultTrackerInvocableTest {

    @TestSetup
    static void setupData() {

        // ---------------------------------------------------------
        // Trigger bypasses required by the org
        // ---------------------------------------------------------
        TriggerControl.bypassTransferTrigger = true;
        TriggerControl.BypassCancelledTrigger = true;
        TriggerControl.BypassAccountTrigger = true;

        // ---------------------------------------------------------
        // Project
        // ---------------------------------------------------------
        Project__c project = new Project__c(
            Name = 'Default Tracker Test Project'
        );
        insert project;

        // ---------------------------------------------------------
        // Phase
        // ---------------------------------------------------------
        Phase__c phase = new Phase__c(
            Name = 'Default Tracker Test Phase',
            Project__c = project.Id
        );
        insert phase;

        // ---------------------------------------------------------
        // Unit
        // ---------------------------------------------------------
        Unit__c unitRec = new Unit__c(
            Phase__c = phase.Id,
            PlotAreasqm__c = 1.0,
            PlotNo__c = '1',
            UnitClassification__c = 'Plot',
            Number_of_Bedrooms__c = '2',
            Name = 'Default Tracker Unit'
        );
        insert unitRec;

        // ---------------------------------------------------------
        // Account
        // ---------------------------------------------------------
        Account acc = new Account(
            Name = 'Default Tracker Test Account',
            Swift_Code__c = '999999'
        );
        insert acc;

        // ---------------------------------------------------------
        // IMPORTANT:
        // Create ONLY ONE Sales Order.
        //
        // The previous test class inserted additional SalesOrder__c
        // records inside individual test methods. That fired
        // SalesOrderTrigger -> SalesOrderSLAHelper.createOrderSLAs
        // repeatedly and caused Too many SOQL queries: 101.
        // ---------------------------------------------------------
        SalesOrder__c so = new SalesOrder__c(
            TotalAmount__c = 2000,
            Source_Entity__c = 'Modon - UAE',
            CustomerAccount__c = acc.Id,
            Unit__c = unitRec.Id
        );
        insert so;

        // ---------------------------------------------------------
        // Installment 1
        // Outstanding balance <= 500
        // Invoice = 200
        // Allocation = 150
        // Outstanding = 50
        // ---------------------------------------------------------
        SalesOrderInstallments__c normalSOI =
            new SalesOrderInstallments__c(
                SalesOrder__c = so.Id,
                MilestoneNumber__c = 1,
                InstallmentAmount__c = 200,
                MilestoneDate__c = Date.today().addDays(-20),
                PaymentStatus__c = 'Not Paid'
            );

        // ---------------------------------------------------------
        // Installment 2
        // Outstanding balance > 500
        // ---------------------------------------------------------
        SalesOrderInstallments__c highBalanceSOI =
            new SalesOrderInstallments__c(
                SalesOrder__c = so.Id,
                MilestoneNumber__c = 2,
                InstallmentAmount__c = 1000,
                MilestoneDate__c = Date.today().addDays(-30),
                PaymentStatus__c = 'Not Paid'
            );

        // ---------------------------------------------------------
        // Installment 3
        // Used for No Business Process test
        // ---------------------------------------------------------
        SalesOrderInstallments__c noBPSOI =
            new SalesOrderInstallments__c(
                SalesOrder__c = so.Id,
                MilestoneNumber__c = 3,
                InstallmentAmount__c = 300,
                MilestoneDate__c = Date.today().addDays(-15),
                PaymentStatus__c = 'Not Paid'
            );

        // ---------------------------------------------------------
        // Installment 4
        // Cancelled installment
        // ---------------------------------------------------------
        SalesOrderInstallments__c cancelledSOI =
            new SalesOrderInstallments__c(
                SalesOrder__c = so.Id,
                MilestoneNumber__c = 4,
                InstallmentAmount__c = 200,
                MilestoneDate__c = Date.today().addDays(-20),
                PaymentStatus__c = 'Cancelled'
            );

        insert new List<SalesOrderInstallments__c>{
            normalSOI,
            highBalanceSOI,
            noBPSOI,
            cancelledSOI
        };

        // ---------------------------------------------------------
        // Receipt for Installment 1 allocation
        // ---------------------------------------------------------
        Receipt__c receipt = new Receipt__c(
            Account__c = acc.Id,
            Status__c = 'Approved',
            TotalAmount__c = 1000
        );
        insert receipt;

        // ---------------------------------------------------------
        // Invoices
        // ---------------------------------------------------------
        Invoice__c normalInvoice = new Invoice__c(
            Account__c = acc.Id,
            InvoiceAmount__c = 200,
            Sales_Order__c = so.Id,
            SalesOrderInstallment__c = normalSOI.Id
        );

        Invoice__c highBalanceInvoice = new Invoice__c(
            Account__c = acc.Id,
            InvoiceAmount__c = 1000,
            Sales_Order__c = so.Id,
            SalesOrderInstallment__c = highBalanceSOI.Id
        );

        Invoice__c noBPInvoice = new Invoice__c(
            Account__c = acc.Id,
            InvoiceAmount__c = 300,
            Sales_Order__c = so.Id,
            SalesOrderInstallment__c = noBPSOI.Id
        );

        Invoice__c cancelledInvoice = new Invoice__c(
            Account__c = acc.Id,
            InvoiceAmount__c = 200,
            Sales_Order__c = so.Id,
            SalesOrderInstallment__c = cancelledSOI.Id
        );

        insert new List<Invoice__c>{
            normalInvoice,
            highBalanceInvoice,
            noBPInvoice,
            cancelledInvoice
        };

        // ---------------------------------------------------------
        // Allocation
        // 200 - 150 = 50 outstanding
        // ---------------------------------------------------------
        Allocation__c allocation = new Allocation__c(
            Invoice__c = normalInvoice.Id,
            Receipt__c = receipt.Id,
            AllocationAmount__c = 150,
            ApprovedReceiptAmount__c = 150,
            InProgressReceiptAmount__c = 0,
            Status__c = 'Applied'
        );
        insert allocation;

        // ---------------------------------------------------------
        // Business Process
        // All test methods get their own copy of @TestSetup data.
        //
        // For the No Business Process scenario, that test method
        // deletes this record before invoking the class.
        // ---------------------------------------------------------
        Business_Process__c bp = new Business_Process__c(
            Sales_Order__c = so.Id,
            Type__c = 'Default And Termination',
            Status__c = 'In Progress'
        );
        Database.insert(bp, AccessLevel.SYSTEM_MODE);
    }


    // =============================================================
    // TEST 1
    // Outstanding balance <= 500
    // =============================================================
    @IsTest
    static void testTrackerSOITracker() {

        TriggerControl.bypassTransferTrigger = true;
        TriggerControl.BypassCancelledTrigger = true;
        TriggerControl.BypassAccountTrigger = true;

        SalesOrderInstallments__c soi = [
            SELECT Id,
                   SalesOrder__c,
                   MilestoneDate__c,
                   PaymentStatus__c
            FROM SalesOrderInstallments__c
            WHERE MilestoneNumber__c = 1
            LIMIT 1
        ];

        Test.startTest();

        SOIDefaultTrackerInvocable.trackerSOITracker(
            new List<Id>{ soi.Id }
        );

        Test.stopTest();
    }


    // =============================================================
    // TEST 2
    // Empty List
    // =============================================================
    @IsTest
    static void testTrackerSOITrackerEmptyList() {

        Test.startTest();

        SOIDefaultTrackerInvocable.trackerSOITracker(
            new List<Id>()
        );

        Test.stopTest();
    }


    // =============================================================
    // TEST 3
    // Outstanding balance > 500
    // =============================================================
    @IsTest
    static void testTrackerSOITrackerBalanceGreaterThan500() {

        TriggerControl.bypassTransferTrigger = true;
        TriggerControl.BypassCancelledTrigger = true;
        TriggerControl.BypassAccountTrigger = true;

        // No Account/SalesOrder/Invoice creation here.
        // Reuse @TestSetup data so SalesOrderTrigger is not fired again.
        SalesOrderInstallments__c soi = [
            SELECT Id,
                   SalesOrder__c,
                   MilestoneDate__c,
                   PaymentStatus__c
            FROM SalesOrderInstallments__c
            WHERE MilestoneNumber__c = 2
            LIMIT 1
        ];

        Test.startTest();

        SOIDefaultTrackerInvocable.trackerSOITracker(
            new List<Id>{ soi.Id }
        );

        Test.stopTest();
    }


    // =============================================================
    // TEST 4
    // No Business Process
    // =============================================================
    @IsTest
    static void testTrackerSOITrackerNoBusinessProcess() {

        TriggerControl.bypassTransferTrigger = true;
        TriggerControl.BypassCancelledTrigger = true;
        TriggerControl.BypassAccountTrigger = true;

        SalesOrderInstallments__c soi = [
            SELECT Id,
                   SalesOrder__c,
                   MilestoneDate__c,
                   PaymentStatus__c
            FROM SalesOrderInstallments__c
            WHERE MilestoneNumber__c = 3
            LIMIT 1
        ];

        // Each test method gets an isolated copy of the @TestSetup data,
        // so deleting the BP here does not impact any other test.
        delete [SELECT Id FROM Business_Process__c];

        Test.startTest();

        SOIDefaultTrackerInvocable.trackerSOITracker(
            new List<Id>{ soi.Id }
        );

        Test.stopTest();
    }


    // =============================================================
    // TEST 5
    // Cancelled Installment
    // =============================================================
    @IsTest
    static void testTrackerSOITrackerCancelledInstallment() {

        TriggerControl.bypassTransferTrigger = true;
        TriggerControl.BypassCancelledTrigger = true;
        TriggerControl.BypassAccountTrigger = true;

        SalesOrderInstallments__c soi = [
            SELECT Id,
                   SalesOrder__c,
                   MilestoneDate__c,
                   PaymentStatus__c
            FROM SalesOrderInstallments__c
            WHERE MilestoneNumber__c = 4
            LIMIT 1
        ];

        Test.startTest();

        SOIDefaultTrackerInvocable.trackerSOITracker(
            new List<Id>{ soi.Id }
        );

        Test.stopTest();
    }
}