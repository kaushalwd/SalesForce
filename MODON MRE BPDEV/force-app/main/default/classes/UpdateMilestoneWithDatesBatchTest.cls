@IsTest
public class UpdateMilestoneWithDatesBatchTest {

    @testSetup
    static void setupData() {

         Project__c project = new Project__c();
        insert project;

        Phase__c phase = new Phase__c(
            Project__c = project.Id
        );
        insert phase;

        // Unit in the milestone's phase, so the Business Process phase filter
        // can match the Sales Order installment.
        Unit__c unitRec = new Unit__c(
            Name                  = 'UMB Test Unit',
            Phase__c              = phase.Id,
            PlotAreasqm__c        = 100,
            PlotNo__c             = 'UMB-001',
            UnitClassification__c = 'Plot',
            Number_of_Bedrooms__c = '2'
        );
        insert unitRec;

        SalesOrder__c so = new SalesOrder__c(
            Unit__c = unitRec.Id,
            Status__c = 'Completed'
        );
        insert so;

        Milestone__c ms = new Milestone__c(
            Name = 'MS1',
            Phase__c=phase.Id,
            Milestone_Due_Date__c = Date.today().addDays(5),
            ConfirmedMilestoneDate__c = Date.today().addDays(3)
        );
        insert ms;

        PaymentPlan__c pp = new PaymentPlan__c(Name = 'PP', Project__c = project.Id, Phase__c = phase.Id, Type__c = 'Standard');
        insert pp;

        PaymentInstallements__c pi = new PaymentInstallements__c(
            PaymentInstallment__c = pp.Id,
            MilestoneInstallment__c = ms.Id,
            MilestoneNumber__c = 1,
            MilestoneDate__c = Date.today()
        );
        insert pi;

        SalesOrderInstallments__c inst = new SalesOrderInstallments__c(
             MilestoneNumber__c=1,
            SalesOrder__c = so.Id,
            Milestone_Installment__c = ms.Id,
            PaymentInstallments__c = pi.Id,
            MilestoneDate__c = Date.today(),
            Is_Milestone_Confirmed__c = false
        );
        insert inst;
         Schema.RecordTypeInfo recordTypeInfo = Schema.getGlobalDescribe().get('Account')
            .getDescribe()
            .getRecordTypeInfosByDeveloperName()
            .get('PersonAccount');
        String recordTypeId = recordTypeInfo.getRecordTypeId();
        Account acc = new Account(RecordTypeId = recordTypeId, PersonEmail = 'test@example.com', FirstName = 'Test', LastName = 'User',Swift_Code__c = '123456');
        insert acc;

        Invoice__c inv = new Invoice__c(
            Account__c = acc.Id,
            InvoiceAmount__c = 200,
            SalesOrderInstallment__c = inst.Id,
            InvoiceDate__c = Date.today()
        );
        insert inv;
    }

    @IsTest
    static void testBatchExecute() {

        SalesOrderInstallments__c inst = [
            SELECT Id, Milestone_Installment__c
            FROM SalesOrderInstallments__c
            LIMIT 1
        ];

        Set<Id> inputSet = new Set<Id>();
        inputSet.add(inst.Milestone_Installment__c);

        Test.startTest();

        UpdateMilestoneWithDatesBatch batch =
            new UpdateMilestoneWithDatesBatch(inputSet);

        Database.executeBatch(batch, 1);

        Test.stopTest();
    }

    @IsTest
    static void testBatchWithBusinessProcessSamePhase() {

        SalesOrderInstallments__c inst = [
            SELECT Id, Milestone_Installment__c, Milestone_Installment__r.Phase__c
            FROM SalesOrderInstallments__c
            LIMIT 1
        ];

        Business_Process__c bp = new Business_Process__c(
            Phase__c = inst.Milestone_Installment__r.Phase__c
        );
        insert bp;

        Test.startTest();
        Database.executeBatch(
            new UpdateMilestoneWithDatesBatch(
                new Set<Id>{ inst.Milestone_Installment__c },
                bp.Id
            ),
            1
        );
        Test.stopTest();

        SalesOrderInstallments__c updated = [
            SELECT Is_Milestone_Confirmed__c
            FROM SalesOrderInstallments__c
            WHERE Id = :inst.Id
        ];
        System.assertEquals(true, updated.Is_Milestone_Confirmed__c,
            'Installment in the Business Process phase should be updated');
    }

    @IsTest
    static void testBatchWithBusinessProcessOtherPhase() {

        SalesOrderInstallments__c inst = [
            SELECT Id, Milestone_Installment__c, Milestone_Installment__r.Phase__r.Project__c
            FROM SalesOrderInstallments__c
            LIMIT 1
        ];

        Phase__c otherPhase = new Phase__c(
            Project__c = inst.Milestone_Installment__r.Phase__r.Project__c
        );
        insert otherPhase;

        Business_Process__c bp = new Business_Process__c(
            Phase__c = otherPhase.Id
        );
        insert bp;

        Test.startTest();
        Database.executeBatch(
            new UpdateMilestoneWithDatesBatch(
                new Set<Id>{ inst.Milestone_Installment__c },
                bp.Id
            ),
            1
        );
        Test.stopTest();

        SalesOrderInstallments__c notUpdated = [
            SELECT Is_Milestone_Confirmed__c
            FROM SalesOrderInstallments__c
            WHERE Id = :inst.Id
        ];
        System.assertEquals(false, notUpdated.Is_Milestone_Confirmed__c,
            'Installment in a different phase must not be updated');
    }

    @IsTest
    static void testBatchEmptyRun() {

        Set<Id> emptySet = new Set<Id>();

        Test.startTest();

        UpdateMilestoneWithDatesBatch batch =
            new UpdateMilestoneWithDatesBatch(emptySet);

        Database.executeBatch(batch, 1);

        Test.stopTest();
    }

    // Installment linked to the milestone only through its Payment Installment
    // (Milestone_Installment__c blank), with its invoice.
    private static SalesOrderInstallments__c createInstallmentWithoutMilestoneLink(Date milestoneDate) {

        SalesOrderInstallments__c existing = [
            SELECT SalesOrder__c, PaymentInstallments__c
            FROM SalesOrderInstallments__c
            LIMIT 1
        ];
        Account acc = [SELECT Id FROM Account LIMIT 1];

        SalesOrderInstallments__c inst = new SalesOrderInstallments__c(
            MilestoneNumber__c = 1,
            SalesOrder__c = existing.SalesOrder__c,
            PaymentInstallments__c = existing.PaymentInstallments__c,
            MilestoneDate__c = milestoneDate,
            Is_Milestone_Confirmed__c = false
        );
        insert inst;

        insert new Invoice__c(
            Account__c = acc.Id,
            InvoiceAmount__c = 200,
            SalesOrderInstallment__c = inst.Id,
            InvoiceDate__c = milestoneDate
        );
        return inst;
    }

    @IsTest
    static void testDatesReadFromMilestoneWhenInstallmentLinkBlank() {

        Milestone__c ms = [SELECT Id, ConfirmedMilestoneDate__c FROM Milestone__c LIMIT 1];
        SalesOrderInstallments__c inst = createInstallmentWithoutMilestoneLink(Date.today());

        Test.startTest();
        Database.executeBatch(new UpdateMilestoneWithDatesBatch(new Set<Id>{ ms.Id }), 200);
        Test.stopTest();

        SalesOrderInstallments__c updated = [
            SELECT Is_Milestone_Confirmed__c, MilestoneDate__c, PreviousMilestoneDate__c, Milestone_Installment__c
            FROM SalesOrderInstallments__c WHERE Id = :inst.Id
        ];
        System.assertEquals(true, updated.Is_Milestone_Confirmed__c,
            'Confirmed date must be read from Milestone__c even when Milestone_Installment__c is blank');
        System.assertEquals(ms.ConfirmedMilestoneDate__c, updated.MilestoneDate__c);
        System.assertEquals(Date.today(), updated.PreviousMilestoneDate__c);
        System.assertEquals(ms.Id, updated.Milestone_Installment__c,
            'Installment must be linked to its Milestone__c parent');

        Invoice__c inv = [SELECT InvoiceDate__c, Is_Milestone_Confirmed__c FROM Invoice__c WHERE SalesOrderInstallment__c = :inst.Id];
        System.assertEquals(ms.ConfirmedMilestoneDate__c, inv.InvoiceDate__c);
        System.assertEquals(true, inv.Is_Milestone_Confirmed__c);
    }

    @IsTest
    static void testLaterInstallmentKeepsInvoiceDate() {

        Milestone__c ms = [SELECT Id, ConfirmedMilestoneDate__c FROM Milestone__c LIMIT 1];
        Date laterDate = ms.ConfirmedMilestoneDate__c.addDays(30);
        SalesOrderInstallments__c inst = createInstallmentWithoutMilestoneLink(laterDate);

        Test.startTest();
        Database.executeBatch(new UpdateMilestoneWithDatesBatch(new Set<Id>{ ms.Id }), 200);
        Test.stopTest();

        SalesOrderInstallments__c updated = [
            SELECT Is_Milestone_Confirmed__c, MilestoneDate__c, Milestone_Installment__c
            FROM SalesOrderInstallments__c WHERE Id = :inst.Id
        ];
        System.assertEquals(true, updated.Is_Milestone_Confirmed__c);
        System.assertEquals(laterDate, updated.MilestoneDate__c, 'A later installment date is kept');
        System.assertEquals(ms.Id, updated.Milestone_Installment__c, 'Installment must be linked to its Milestone__c parent');

        Invoice__c inv = [SELECT InvoiceDate__c, Is_Milestone_Confirmed__c FROM Invoice__c WHERE SalesOrderInstallment__c = :inst.Id];
        System.assertEquals(laterDate, inv.InvoiceDate__c, 'Invoice date must not be blanked');
        System.assertEquals(true, inv.Is_Milestone_Confirmed__c);
    }
}