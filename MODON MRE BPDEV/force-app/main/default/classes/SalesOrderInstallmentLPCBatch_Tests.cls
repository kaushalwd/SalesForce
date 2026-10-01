@isTest(SeeAllData=true)
private class SalesOrderInstallmentLPCBatch_Tests {
    private static Id latePaymentRtId() {
        return [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Charge__c' AND Name = 'Late Payment'
            LIMIT 1
        ].Id;
    }

    @isTest
    static void runBatch_NoAsserts() {
        Id rtId = latePaymentRtId();

        // Use any existing Phase__c (you showed there are many)
        Id phaseId = [SELECT Id FROM Phase__c LIMIT 1].Id;

        // Account + Sales Order
        Account acc = new Account(Name = 'LPC Test Acc');
        insert acc;

        SalesOrder__c so = new SalesOrder__c(CustomerAccount__c = acc.Id);
        insert so;

        // Milestones — include REQUIRED fields: Phase__c and Milestone_Due_Date__c
        // Also set ConfirmedMilestoneDate__c so the batch uses those exact day deltas.
        Date today = Date.today();
        Milestone__c m30 = new Milestone__c(
            Name = 'M30',
            Phase__c = phaseId,
            Milestone_Due_Date__c = today.addDays(-30),
            ConfirmedMilestoneDate__c = today.addDays(-30)
        );
        Milestone__c m45 = new Milestone__c(
            Name = 'M45',
            Phase__c = phaseId,
            Milestone_Due_Date__c = today.addDays(-30),
            ConfirmedMilestoneDate__c = today.addDays(-30)
        );
        Milestone__c m360 = new Milestone__c(
            Name = 'M360',
            Phase__c = phaseId,
            Milestone_Due_Date__c = today.addDays(-360),
            ConfirmedMilestoneDate__c = today.addDays(-360)
        );
        insert new List<Milestone__c>{ m30, m45, m360 };

        // Sales Order Installments (don’t set read-only/auto fields)
        SalesOrderInstallments__c soi30 = new SalesOrderInstallments__c(
            InstallmentAmount__c = 1000,
            MilestoneDate__c     = today.addDays(-31), // must be < TODAY per batch filter
            PaymentStatus__c     = 'Not Paid',
            SalesOrder__c        = so.Id,
            Exclude_LPC__c       = false,
            Milestone_Installment__c = m30.Id
        );
        SalesOrderInstallments__c soi45 = new SalesOrderInstallments__c(
            InstallmentAmount__c = 1500,
            MilestoneDate__c     = today.addDays(-46),
            PaymentStatus__c     = 'Not Paid',
            SalesOrder__c        = so.Id,
            Exclude_LPC__c       = false,
            Milestone_Installment__c = m45.Id
        );
        SalesOrderInstallments__c soi360 = new SalesOrderInstallments__c(
            InstallmentAmount__c = 2000,
            MilestoneDate__c     = today.addDays(-361),
            PaymentStatus__c     = 'Not Paid',
            SalesOrder__c        = so.Id,
            Exclude_LPC__c       = false,
            Milestone_Installment__c = m360.Id
        );
        insert new List<SalesOrderInstallments__c>{ soi30, soi45, soi360 };

        // Seed invoice for 30‑day (don’t set InvoiceBalance__c if it’s a formula)
        insert new Invoice__c(
            SalesOrderInstallment__c = soi30.Id,
            Sales_Order__c           = so.Id,
            Account__c               = acc.Id,
            InvoiceAmount__c         = 1000
        );

        // Seed charges for 45‑day (update path) and 360‑day (invoice-creation path)
        insert new Charge__c(
            RecordTypeId             = rtId,
            SalesOrderInstallment__c = soi45.Id,
            Sales_Order__c           = so.Id,
            Account__c               = acc.Id,
            PaymentStatus__c         = 'Not Paid',
            Amount__c                = 50
        );
        insert new Charge__c(
            RecordTypeId             = rtId,
            SalesOrderInstallment__c = soi360.Id,
            Sales_Order__c           = so.Id,
            Account__c               = acc.Id,
            PaymentStatus__c         = 'Not Paid',
            Amount__c                = 150
        );

        // Run: with Id filter
        Test.startTest();
        Database.executeBatch(new SalesOrderInstallmentLPCBatch(new List<Id>{ soi30.Id, soi360.Id }), 50);
        Test.stopTest();

        // Run: without Id filter
        //Test.startTest();
        //Database.executeBatch(new SalesOrderInstallmentLPCBatch(), 50);
        //Test.stopTest();
        // No asserts (per your request)
    }
}