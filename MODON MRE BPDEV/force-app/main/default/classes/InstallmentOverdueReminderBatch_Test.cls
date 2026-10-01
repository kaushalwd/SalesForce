@isTest
public class InstallmentOverdueReminderBatch_Test {

    @testSetup static void setup() {

        // ---- Accounts (Person Accounts + a Business Account) ----
        Account acc = new Account(FirstName = 'First', LastName = 'Last', PersonEmail = 'test@person.com');
        Account acc1 = new Account(FirstName = 'First2', LastName = 'Last2', PersonEmail = 'test2@person.com');

        Id businessRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
                            .get('OrganizationAccount').getRecordTypeId();
        Account businessAcc = new Account(Name = 'Test Business', RecordTypeId = businessRtId);

        insert new List<Account>{ acc, acc1, businessAcc };

        Contact con = new Contact(
            LastName = 'Test Contact',
            AccountId = businessAcc.Id,
            Email = 'test@example.com',
            Is_Active__c = true
        );
        insert con;

        // ---- Project / Phase / Milestone ----
        Project__c proj = new Project__c(Name = 'Jupiter');
        insert proj;

        Phase__c phase = new Phase__c(Name = 'Phase 1', Project__c = proj.Id);
        insert phase;

        Milestone__c milestone = new Milestone__c(
            Type__c = 'Progress Based',
            Phase__c = phase.Id,
            Milestone_Due_Date__c = System.today().addDays(-30),
            ConfirmedMilestoneDate__c = System.today().addDays(-30),
            Project__c = proj.Id,
            Name = 'QAJupMilestoneTest1'
        );
        insert milestone;

        // ---- Units (bulk insert instead of 3 separate DML statements) ----
        List<Unit__c> units = new List<Unit__c>();
        for (Integer i = 0; i < 3; i++) {
            units.add(new Unit__c(
                Name = 'Unit A',
                Phase__c = phase.Id,
                PlotNo__c = '101',
                UnitClassification__c = 'Villa',
                Type__c = 'G+1',
                Number_of_Bedrooms__c = '1'
            ));
        }
        insert units;
        Unit__c unit  = units[0];
        Unit__c unit1 = units[1];
        Unit__c unit2 = units[2];

        // Removed the unnecessary re-query of Unit__c (Phase__r.Project__r.Name) —
        // it was only used for a debug statement and cost a SOQL call for no test value.

        // ---- Sales Orders (bulk insert) ----
        SalesOrder__c so  = new SalesOrder__c(CustomerAccount__c = acc.Id, Status__c = 'Completed', TotalAmount__c = 50000, Unit__c = unit.Id);
        SalesOrder__c so1 = new SalesOrder__c(CustomerAccount__c = businessAcc.Id, Status__c = 'Completed', TotalAmount__c = 50000, Unit__c = unit1.Id);
        SalesOrder__c so2 = new SalesOrder__c(CustomerAccount__c = acc1.Id, Status__c = 'Completed', TotalAmount__c = 50000, Unit__c = unit2.Id);
        insert new List<SalesOrder__c>{ so, so1, so2 };

        // Removed the re-query of SalesOrder__c (ProjectName__c) — Id is already
        // available from the insert and ProjectName__c wasn't used afterward.
        // If a downstream assertion truly needs it, re-add a single bulk query
        // (SELECT Id, ProjectName__c FROM SalesOrder__c WHERE Id IN :ids) rather
        // than querying per record.

        // Status__c was already 'Completed' at insert time, so the follow-up
        // update so.Status__c = 'Completed'; update so; (and so1/so2 equivalents)
        // were no-op DML and have been removed.

        // ---- Sales Order Installments (bulk insert) ----
        List<SalesOrderInstallments__c> installments = new List<SalesOrderInstallments__c>{
            new SalesOrderInstallments__c(
                SalesOrder__c = so.Id, MilestoneNumber__c = 1,
                PaymentStatus__c = 'Paid', InstallmentAmount__c = 10000,
                Milestone_Installment__c = milestone.Id,
                MilestoneDate__c = System.today().addDays(-45)
            ),
            new SalesOrderInstallments__c(
                SalesOrder__c = so.Id, MilestoneNumber__c = 2,
                PaymentStatus__c = 'Not Paid', InstallmentAmount__c = 10000,
                ExtensionDate__c = System.today().addDays(-20),
                MilestoneDate__c = System.today().addDays(-30)
            ),
            new SalesOrderInstallments__c(
                SalesOrder__c = so.Id, MilestoneNumber__c = 3,
                PaymentStatus__c = 'Not Paid', InstallmentAmount__c = 10000,
                MilestoneDate__c = System.today().addDays(30)
            ),
            new SalesOrderInstallments__c(
                SalesOrder__c = so1.Id, MilestoneNumber__c = 1,
                PaymentStatus__c = 'Paid', InstallmentAmount__c = 10000,
                MilestoneDate__c = System.today().addDays(-65)
            ),
            new SalesOrderInstallments__c(
                SalesOrder__c = so1.Id, MilestoneNumber__c = 2,
                PaymentStatus__c = 'Not Paid', InstallmentAmount__c = 10000,
                MilestoneDate__c = System.today().addDays(-30)
            ),
            new SalesOrderInstallments__c(
                SalesOrder__c = so2.Id, MilestoneNumber__c = 1,
                PaymentStatus__c = 'Paid', InstallmentAmount__c = 10000,
                MilestoneDate__c = System.today().addDays(-63)
            ),
            new SalesOrderInstallments__c(
                SalesOrder__c = so2.Id, MilestoneNumber__c = 2,
                PaymentStatus__c = 'Not Paid', InstallmentAmount__c = 10000,
                MilestoneDate__c = System.today().addDays(-10)
            ),
            new SalesOrderInstallments__c(
                SalesOrder__c = so2.Id, MilestoneNumber__c = 2,
                PaymentStatus__c = 'Not Paid', InstallmentAmount__c = 10000,
                MilestoneDate__c = System.today().addDays(-20)
            )
        };
        insert installments;
    }

    @isTest
    static void testMilestoneSRCreationBatch() {
        Test.startTest();
        Database.executeBatch(new InstallmentOverdueReminderBatch(), 50);
        Test.stopTest();
    }
}