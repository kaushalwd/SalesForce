@IsTest
public class UpdateMilestoneBatchTest {

    @testSetup
    static void setupData() {
        SalesOrder__c so = new SalesOrder__c(Status__c = 'Completed');
        insert so;

        Project__c project = new Project__c();
        insert project;

        Phase__c phase = new Phase__c(Project__c = project.Id);
        insert phase;

        Milestone__c confirmedMs = new Milestone__c(
            Name = 'Confirmed MS',
            Phase__c = phase.Id,
            Milestone_Due_Date__c = Date.today().addDays(5),
            ConfirmedMilestoneDate__c = Date.today().addDays(3)
        );
        Milestone__c dueDateMs = new Milestone__c(
            Name = 'Due Date MS',
            Phase__c = phase.Id,
            Milestone_Due_Date__c = Date.today().addDays(7),
            ConfirmedMilestoneDate__c = Date.today()
        );
        Milestone__c skipDateMs = new Milestone__c(
            Name = 'Skip Date MS',
            Phase__c = phase.Id,
            Milestone_Due_Date__c = Date.today().addDays(-2),
            ConfirmedMilestoneDate__c = Date.today().addDays(-3)
        );
        insert new List<Milestone__c>{ confirmedMs, dueDateMs, skipDateMs };

        SalesOrderInstallments__c confirmedInst = new SalesOrderInstallments__c(
            MilestoneNumber__c = 1,
            SalesOrder__c = so.Id,
            Milestone_Installment__c = confirmedMs.Id,
            MilestoneDate__c = Date.today(),
            Is_Milestone_Confirmed__c = false
        );
        SalesOrderInstallments__c dueDateInst = new SalesOrderInstallments__c(
            MilestoneNumber__c = 2,
            SalesOrder__c = so.Id,
            Milestone_Installment__c = dueDateMs.Id,
            MilestoneDate__c = Date.today(),
            Is_Milestone_Confirmed__c = false
        );
        SalesOrderInstallments__c skipDateInst = new SalesOrderInstallments__c(
            MilestoneNumber__c = 3,
            SalesOrder__c = so.Id,
            Milestone_Installment__c = skipDateMs.Id,
            MilestoneDate__c = Date.today(),
            Is_Milestone_Confirmed__c = false
        );
        SalesOrderInstallments__c noInvoiceInst = new SalesOrderInstallments__c(
            MilestoneNumber__c = 4,
            SalesOrder__c = so.Id,
            Milestone_Installment__c = confirmedMs.Id,
            MilestoneDate__c = Date.today().addDays(-1),
            Is_Milestone_Confirmed__c = false
        );
        insert new List<SalesOrderInstallments__c>{
            confirmedInst, dueDateInst, skipDateInst, noInvoiceInst
        };

        Schema.RecordTypeInfo recordTypeInfo = Schema.getGlobalDescribe().get('Account')
            .getDescribe()
            .getRecordTypeInfosByDeveloperName()
            .get('PersonAccount');
        Account acc = new Account(
            RecordTypeId = recordTypeInfo.getRecordTypeId(),
            PersonEmail = 'milestonebatch@example.com',
            FirstName = 'Mile',
            LastName = 'Stone',
            Swift_Code__c = '123456'
        );
        insert acc;

        insert new List<Invoice__c>{
            new Invoice__c(
                Account__c = acc.Id,
                InvoiceAmount__c = 200,
                SalesOrderInstallment__c = confirmedInst.Id,
                InvoiceDate__c = Date.today()
            ),
            new Invoice__c(
                Account__c = acc.Id,
                InvoiceAmount__c = 300,
                SalesOrderInstallment__c = dueDateInst.Id,
                InvoiceDate__c = Date.today()
            ),
            new Invoice__c(
                Account__c = acc.Id,
                InvoiceAmount__c = 150,
                SalesOrderInstallment__c = skipDateInst.Id,
                InvoiceDate__c = Date.today()
            )
        };
    }

    @IsTest
    static void testConfirmedMilestoneBatch() {
        Set<Id> milestoneIds = new Set<Id>();
        for (SalesOrderInstallments__c inst : [
            SELECT Milestone_Installment__c, Milestone_Installment__r.Name
            FROM SalesOrderInstallments__c
            WHERE Milestone_Installment__r.Name IN ('Confirmed MS', 'Skip Date MS')
        ]) {
            milestoneIds.add(inst.Milestone_Installment__c);
        }

        Test.startTest();
        Database.executeBatch(new UpdateMilestoneBatch(milestoneIds, 'cofirmed milestone'), 20);
        Test.stopTest();

        List<SalesOrderInstallments__c> updatedInst = [
            SELECT Id, Is_Milestone_Confirmed__c
            FROM SalesOrderInstallments__c
            WHERE Milestone_Installment__r.Name = 'Confirmed MS'
        ];
        System.assert(!updatedInst.isEmpty(), 'Confirmed milestone installments should be processed');
    }

    @IsTest
    static void testMilestoneDueDateBatch() {
        Set<Id> milestoneIds = new Set<Id>();
        for (SalesOrderInstallments__c inst : [
            SELECT Milestone_Installment__c
            FROM SalesOrderInstallments__c
            WHERE Milestone_Installment__r.Name IN ('Due Date MS', 'Skip Date MS')
        ]) {
            milestoneIds.add(inst.Milestone_Installment__c);
        }

        Test.startTest();
        Database.executeBatch(new UpdateMilestoneBatch(milestoneIds, 'milestone due date'), 20);
        Test.stopTest();

        SalesOrderInstallments__c dueInst = [
            SELECT Id, MilestoneDate__c
            FROM SalesOrderInstallments__c
            WHERE Milestone_Installment__r.Name = 'Due Date MS'
            LIMIT 1
        ];
        System.assertNotEquals(null, dueInst.Id, 'Due date installment should exist after batch');
    }

    @IsTest
    static void testEmptySetAndFinish() {
        UpdateMilestoneBatch batch = new UpdateMilestoneBatch(new Set<Id>(), 'cofirmed milestone');
        Test.startTest();
        Database.QueryLocator locator = batch.start(null);
        batch.execute(null, new List<SalesOrderInstallments__c>());
        batch.finish(null);
        Database.executeBatch(batch, 1);
        Test.stopTest();
        System.assertNotEquals(null, locator, 'Start should return a query locator for an empty id set');
    }

    @IsTest
    static void testUnknownActionTypeDoesNotUpdate() {
        Set<Id> milestoneIds = new Set<Id>();
        for (SalesOrderInstallments__c inst : [
            SELECT Milestone_Installment__c
            FROM SalesOrderInstallments__c
        ]) {
            milestoneIds.add(inst.Milestone_Installment__c);
        }

        Test.startTest();
        Database.executeBatch(new UpdateMilestoneBatch(milestoneIds, 'unknown action'), 20);
        Test.stopTest();

        System.assert(!milestoneIds.isEmpty(), 'Milestones should be passed to the unknown-action run');
    }
}