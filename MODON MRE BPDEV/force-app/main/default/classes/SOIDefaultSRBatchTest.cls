@IsTest
public class SOIDefaultSRBatchTest {

    @testSetup
    static void setupData() {

        // ============================================================
        // Process Flow
        // ============================================================
        Process_Flow__c pf = new Process_Flow__c(
            Name = 'Default And Termination',
            Active__c = true,
            Process_Flow_Unique_Name__c = 'DEFAULT_AND_TERMINATION'
        );
        insert pf;


        // ============================================================
        // Person Account
        // ============================================================
        String personRecTypeId = Schema.SObjectType.Account
            .getRecordTypeInfosByDeveloperName()
            .get('PersonAccount')
            .getRecordTypeId();

        Account acc = new Account(
            RecordTypeId = personRecTypeId,
            FirstName = 'Test',
            LastName = 'Customer',
            PersonEmail = 'testcustomer@test.com',
            PersonMobilePhone = '+971500000000',
            EIDNumber__pc = '784-1234-1234567-1',
            PassportNumber__pc = 'P123456'
        );
        insert acc;


        // ============================================================
        // Opportunity
        // ============================================================
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            UAE_Resident_Status__c = 'Resident',
            Nationality__c = 'United Arab Emirates',
            EmiratesIDExpiryDate__c = Date.today().addDays(365),
            EIDNumber__c = '784-1234-1234567-1'
        );
        insert opp;


        // ============================================================
        // Project
        // ============================================================
        Project__c project = new Project__c(
            Name = 'Test Project'
        );
        insert project;


        // ============================================================
        // Phase
        // ============================================================
        Phase__c phase = new Phase__c(
            Name = 'Test Phase',
            Project__c = project.Id
        );
        insert phase;


        // ============================================================
        // Unit
        // ============================================================
        Unit__c unit = new Unit__c(
            Name = 'Test Unit',
            PlotNo__c = 'U-101',
            Number_of_Bedrooms__c = '2',
            UnitClassification__c = 'Apartment',
            Opportunity__c = opp.Id,
            Status__c = 'Sold',
            Phase__c = phase.Id
        );
        insert unit;


        // ============================================================
        // Milestone
        // ============================================================
        Milestone__c milestone = new Milestone__c(
            Name = 'Milestone 1',
            Phase__c = phase.Id,
            Milestone_Due_Date__c = Date.today().addDays(-20)
        );
        insert milestone;


        // ============================================================
        // Sales Order
        // ============================================================
        SalesOrder__c so = new SalesOrder__c(
            Status__c = 'Completed',
            CustomerAccount__c = acc.Id,
            Unit__c = unit.Id,
            TotalAmount__c = 100000,
            Opportunity__c = opp.Id
        );
        insert so;


        // ============================================================
        // Eligible Installment
        // ============================================================
        SalesOrderInstallments__c eligibleSoi =
            new SalesOrderInstallments__c(
                MilestoneNumber__c = 1,
                SalesOrder__c = so.Id,
                Milestone_Installment__c = milestone.Id,
                InstallmentAmount__c = 10000,
                MilestoneDate__c = Date.today().addDays(-15),
                PaymentStatus__c = 'Not Paid'
            );

        insert eligibleSoi;


        // ============================================================
        // Invoice
        // InvoiceBalance__c is read-only.
        // Account__c is mandatory.
        // ============================================================
        Invoice__c invoice = new Invoice__c(
            Account__c = acc.Id,
            SalesOrderInstallment__c = eligibleSoi.Id
        );


        // ============================================================
        // Try to populate writable amount field dynamically
        // ============================================================
        Map<String, Schema.SObjectField> invoiceFields =
            Schema.SObjectType.Invoice__c.fields.getMap();


        List<String> amountFields = new List<String>{
            'InvoiceAmount__c',
            'Invoice_Amount__c',
            'Amount__c',
            'TotalAmount__c',
            'Total_Amount__c',
            'InvoiceTotal__c',
            'Invoice_Total__c',
            'Invoice_Value__c',
            'InvoiceValue__c'
        };


        for (String fieldName : amountFields) {

            if (invoiceFields.containsKey(fieldName)) {

                Schema.DescribeFieldResult fieldDescribe =
                    invoiceFields.get(fieldName).getDescribe();

                if (fieldDescribe.isCreateable()) {

                    Schema.DisplayType fieldType =
                        fieldDescribe.getType();

                    if (
                        fieldType == Schema.DisplayType.Currency ||
                        fieldType == Schema.DisplayType.Double ||
                        fieldType == Schema.DisplayType.Integer
                    ) {

                        invoice.put(
                            fieldName,
                            10000
                        );

                        System.debug(
                            '*** Invoice amount field populated: ' +
                            fieldName
                        );

                        break;
                    }
                }
            }
        }


        // ============================================================
        // Try to populate paid/allocation fields as zero
        // ============================================================
        List<String> paidAmountFields = new List<String>{
            'PaidAmount__c',
            'Paid_Amount__c',
            'AllocatedAmount__c',
            'Allocated_Amount__c',
            'PaymentAmount__c',
            'Payment_Amount__c',
            'AppliedAmount__c',
            'Applied_Amount__c',
            'ReceivedAmount__c',
            'Received_Amount__c'
        };


        for (String fieldName : paidAmountFields) {

            if (invoiceFields.containsKey(fieldName)) {

                Schema.DescribeFieldResult fieldDescribe =
                    invoiceFields.get(fieldName).getDescribe();

                if (fieldDescribe.isCreateable()) {

                    Schema.DisplayType fieldType =
                        fieldDescribe.getType();

                    if (
                        fieldType == Schema.DisplayType.Currency ||
                        fieldType == Schema.DisplayType.Double ||
                        fieldType == Schema.DisplayType.Integer
                    ) {

                        invoice.put(
                            fieldName,
                            0
                        );
                    }
                }
            }
        }


        insert invoice;


        // ============================================================
        // Paid Installment
        // ============================================================
        SalesOrderInstallments__c paidSoi =
            new SalesOrderInstallments__c(
                MilestoneNumber__c = 2,
                SalesOrder__c = so.Id,
                Milestone_Installment__c = milestone.Id,
                InstallmentAmount__c = 5000,
                MilestoneDate__c = Date.today().addDays(-15),
                PaymentStatus__c = 'Paid'
            );

        insert paidSoi;
    }


    // ================================================================
    // TEST 1
    // Default Constructor
    // ================================================================
    @IsTest
    static void testBatchDefaultConstructor() {

        SalesOrderInstallments__c soi = [
            SELECT
                Id,
                SalesOrder__c,
                PaymentStatus__c,
                Default_and_Termination_SR__c
            FROM SalesOrderInstallments__c
            WHERE PaymentStatus__c = 'Not Paid'
            LIMIT 1
        ];


        List<Invoice__c> invoices = [
            SELECT
                Id,
                Account__c,
                SalesOrderInstallment__c,
                InvoiceBalance__c
            FROM Invoice__c
            WHERE SalesOrderInstallment__c = :soi.Id
        ];


        System.debug(
            '*** Invoice Records = ' +
            invoices
        );


        if (!invoices.isEmpty()) {

            System.debug(
                '*** Invoice Balance = ' +
                invoices[0].InvoiceBalance__c
            );
        }


        List<AggregateResult> results = [
            SELECT
                SalesOrderInstallment__r.SalesOrder__c SalesOrderId,
                SUM(InvoiceBalance__c) TotalBalance
            FROM Invoice__c
            WHERE SalesOrderInstallment__r.SalesOrder__c =
                :soi.SalesOrder__c
            AND SalesOrderInstallment__r.MilestoneDate__c < TODAY
            AND InvoiceBalance__c > 0
            AND SalesOrderInstallment__r.PaymentStatus__c != 'Cancelled'
            GROUP BY SalesOrderInstallment__r.SalesOrder__c
        ];


        System.debug(
            '*** Aggregate Results = ' +
            results
        );


        if (!results.isEmpty()) {

            Decimal totalBalance =
                (Decimal) results[0].get('TotalBalance');

            System.debug(
                '*** Aggregate Total Balance = ' +
                totalBalance
            );
        }


        Test.startTest();

        Database.executeBatch(
            new SOIDefaultSRBatch(),
            1
        );

        Test.stopTest();


        SalesOrderInstallments__c updatedSoi = [
            SELECT
                Id,
                PaymentStatus__c,
                Default_and_Termination_SR__c
            FROM SalesOrderInstallments__c
            WHERE Id = :soi.Id
        ];


        System.debug(
            '*** Updated SOI = ' +
            updatedSoi
        );

        System.debug(
            '*** Default BP = ' +
            updatedSoi.Default_and_Termination_SR__c
        );
    }


    // ================================================================
    // TEST 2
    // Constructor With Specific Milestone Installment IDs
    // ================================================================
    @IsTest
    static void testBatchWithSpecificMilestoneInstallmentIds() {

        SalesOrderInstallments__c soi = [
            SELECT
                Id,
                Milestone_Installment__c,
                SalesOrder__c
            FROM SalesOrderInstallments__c
            WHERE PaymentStatus__c = 'Not Paid'
            LIMIT 1
        ];


        Set<Id> milestoneIds = new Set<Id>{
            soi.Milestone_Installment__c
        };


        Test.startTest();

        Database.executeBatch(
            new SOIDefaultSRBatch(milestoneIds),
            1
        );

        Test.stopTest();


        SalesOrderInstallments__c updatedSoi = [
            SELECT
                Id,
                Default_and_Termination_SR__c
            FROM SalesOrderInstallments__c
            WHERE Id = :soi.Id
        ];


        System.debug(
            '*** Specific ID Batch Result = ' +
            updatedSoi
        );
    }


    // ================================================================
    // TEST 3
    // Schedulable Execution
    // ================================================================
    @IsTest
    static void testSchedulableExecution() {

        Test.startTest();


        String jobId = System.schedule(
            'SOI Default SR Batch Test',
            '0 0 1 * * ?',
            new SOIDefaultSRBatch()
        );


        Test.stopTest();


        System.debug(
            '*** Scheduled Job Id = ' +
            jobId
        );
    }


    // ================================================================
    // TEST 4
    // Aggregate Query Coverage
    // ================================================================
    @IsTest
    static void testInvoiceAggregateQuery() {

        SalesOrderInstallments__c soi = [
            SELECT
                Id,
                SalesOrder__c,
                MilestoneDate__c
            FROM SalesOrderInstallments__c
            WHERE PaymentStatus__c = 'Not Paid'
            LIMIT 1
        ];


        List<Invoice__c> invoices = [
            SELECT
                Id,
                Account__c,
                SalesOrderInstallment__c,
                InvoiceBalance__c
            FROM Invoice__c
            WHERE SalesOrderInstallment__c = :soi.Id
        ];


        System.debug(
            '*** Invoice Records = ' +
            invoices
        );


        List<AggregateResult> results = [
            SELECT
                SalesOrderInstallment__r.SalesOrder__c SalesOrderId,
                SUM(InvoiceBalance__c) TotalBalance
            FROM Invoice__c
            WHERE SalesOrderInstallment__r.SalesOrder__c =
                :soi.SalesOrder__c
            AND SalesOrderInstallment__r.MilestoneDate__c < TODAY
            AND InvoiceBalance__c > 0
            AND SalesOrderInstallment__r.PaymentStatus__c != 'Cancelled'
            GROUP BY SalesOrderInstallment__r.SalesOrder__c
        ];


        System.debug(
            '*** Aggregate Results = ' +
            results
        );


        if (!results.isEmpty()) {

            Decimal totalBalance =
                (Decimal) results[0].get('TotalBalance');

            System.debug(
                '*** Total Balance = ' +
                totalBalance
            );
        }
    }
}