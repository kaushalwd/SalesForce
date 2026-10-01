@isTest
private class MilestoneInstallmentsSummaryFromBpTest {

    @TestSetup
    static void setup() {

        Project__c project = new Project__c(Name = 'Test Project');
        insert project;

        Phase__c phase = new Phase__c(
            Name = 'Test Phase',
            Project__c = project.Id
        );
        insert phase;

        Milestone__c milestone = new Milestone__c(
            Name = 'Test Milestone',
            Phase__c = phase.Id,
            Project__c = project.Id,
            Milestone_Due_Date__c = Date.today()
        );
        insert milestone;

        Milestone__c otherMilestone = new Milestone__c(
            Name = 'Other Milestone',
            Phase__c = phase.Id,
            Project__c = project.Id,
            Milestone_Due_Date__c = Date.today()
        );
        insert otherMilestone;

        Unit__c unit = new Unit__c(
            Name = 'Test Unit',
            Phase__c = phase.Id,
            Status__c = 'Available',
            PlotNo__c = 'PLOT-1',
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '3'
        );
        insert unit;

        SalesOrder__c activeSalesOrder = new SalesOrder__c(
            Unit__c = unit.Id,
            Status__c = 'In Progress'
        );
        insert activeSalesOrder;

        SalesOrder__c cancelledSalesOrder = new SalesOrder__c(
            Unit__c = unit.Id,
            Status__c = 'Cancelled'
        );
        insert cancelledSalesOrder;

        // The fetch logic resolves installments via Milestone__c.Payment_Installments__r ->
        // SalesOrderInstallments__c.PaymentInstallments__c, so each milestone needs its own
        // PaymentInstallements__c (which in turn requires a PaymentPlan__c parent).
        PaymentPlan__c paymentPlan = new PaymentPlan__c(Type__c = 'Standard');
        insert paymentPlan;

        PaymentInstallements__c paymentInstallmentForMilestone = new PaymentInstallements__c(
            PaymentInstallment__c = paymentPlan.Id,
            MilestoneInstallment__c = milestone.Id
        );
        PaymentInstallements__c paymentInstallmentForOtherMilestone = new PaymentInstallements__c(
            PaymentInstallment__c = paymentPlan.Id,
            MilestoneInstallment__c = otherMilestone.Id
        );
        insert new List<PaymentInstallements__c>{ paymentInstallmentForMilestone, paymentInstallmentForOtherMilestone };

        List<SalesOrderInstallments__c> installments = new List<SalesOrderInstallments__c>();

        installments.add(new SalesOrderInstallments__c(
            SalesOrder__c = activeSalesOrder.Id,
            Milestone_Installment__c = milestone.Id,
            PaymentInstallments__c = paymentInstallmentForMilestone.Id,
            MilestoneDate__c = Date.today(),
            PaymentStatus__c = 'Not Paid',
            InstallmentAmount__c = 1000
        ));

        installments.add(new SalesOrderInstallments__c(
            SalesOrder__c = activeSalesOrder.Id,
            Milestone_Installment__c = milestone.Id,
            PaymentInstallments__c = paymentInstallmentForMilestone.Id,
            MilestoneDate__c = Date.today().addDays(1),
            PaymentStatus__c = 'Paid',
            InstallmentAmount__c = 2000
        ));

        // Linked to this milestone, but the Sales Order is Cancelled - must be excluded.
        installments.add(new SalesOrderInstallments__c(
            SalesOrder__c = cancelledSalesOrder.Id,
            Milestone_Installment__c = milestone.Id,
            PaymentInstallments__c = paymentInstallmentForMilestone.Id,
            MilestoneDate__c = Date.today(),
            PaymentStatus__c = 'Not Paid',
            InstallmentAmount__c = 500
        ));

        // Active Sales Order, but linked to a different milestone - must be excluded.
        installments.add(new SalesOrderInstallments__c(
            SalesOrder__c = activeSalesOrder.Id,
            Milestone_Installment__c = otherMilestone.Id,
            PaymentInstallments__c = paymentInstallmentForOtherMilestone.Id,
            MilestoneDate__c = Date.today(),
            PaymentStatus__c = 'Not Paid',
            InstallmentAmount__c = 300
        ));

        insert installments;

        Business_Process__c matchingBp = new Business_Process__c(
            Type__c = 'Project Milestone Confirmation',
            Milestone__c = milestone.Id
        );
        Database.insert(matchingBp, AccessLevel.SYSTEM_MODE);

        Business_Process__c wrongTypeBp = new Business_Process__c(
            Type__c = 'Handover Units',
            Milestone__c = milestone.Id
        );
        Database.insert(wrongTypeBp, AccessLevel.SYSTEM_MODE);

        Business_Process__c noMilestoneBp = new Business_Process__c(
            Type__c = 'Project Milestone Confirmation'
        );
        Database.insert(noMilestoneBp, AccessLevel.SYSTEM_MODE);
    }

    @isTest
    static void testGetMilestoneInstallmentsReturnsActiveOnly() {

        Business_Process__c bp = [
            SELECT Id FROM Business_Process__c
            WHERE Type__c = 'Project Milestone Confirmation' AND Milestone__c != null
            LIMIT 1
        ];

        Test.startTest();
        MilestoneInstallmentsSummaryFromBp.MilestoneInstallmentsResult result =
            MilestoneInstallmentsSummaryFromBp.getMilestoneInstallments(bp.Id);
        Test.stopTest();

        System.assertEquals(
            2, result.rows.size(),
            'Only the two active-SalesOrder installments on this milestone should be returned'
        );
        System.assertEquals(2, result.totalCount);
        System.assertEquals(1, result.totals.size(), 'All test records share one currency');
        System.assertEquals(3000, result.totals[0].totalAmount);
        System.assertEquals(2, result.totals[0].count);
    }

    @isTest
    static void testGetMilestoneInstallmentsSamePhase() {

        Milestone__c milestone = [SELECT Id, Phase__c FROM Milestone__c WHERE Name = 'Test Milestone' LIMIT 1];

        Business_Process__c bp = new Business_Process__c(
            Type__c = 'Project Milestone Confirmation',
            Milestone__c = milestone.Id,
            Phase__c = milestone.Phase__c
        );
        Database.insert(bp, AccessLevel.SYSTEM_MODE);

        Test.startTest();
        MilestoneInstallmentsSummaryFromBp.MilestoneInstallmentsResult result =
            MilestoneInstallmentsSummaryFromBp.getMilestoneInstallments(bp.Id);
        Test.stopTest();

        System.assertEquals(2, result.rows.size(),
            'Units in the Business Process Phase should be returned');
    }

    @isTest
    static void testGetMilestoneInstallmentsOtherPhase() {

        Milestone__c milestone = [SELECT Id, Project__c FROM Milestone__c WHERE Name = 'Test Milestone' LIMIT 1];

        Phase__c otherPhase = new Phase__c(Name = 'Other Phase', Project__c = milestone.Project__c);
        insert otherPhase;

        Business_Process__c bp = new Business_Process__c(
            Type__c = 'Project Milestone Confirmation',
            Milestone__c = milestone.Id,
            Phase__c = otherPhase.Id
        );
        Database.insert(bp, AccessLevel.SYSTEM_MODE);

        Test.startTest();
        MilestoneInstallmentsSummaryFromBp.MilestoneInstallmentsResult result =
            MilestoneInstallmentsSummaryFromBp.getMilestoneInstallments(bp.Id);
        Test.stopTest();

        System.assertEquals(0, result.rows.size(),
            'Units outside the Business Process Phase must be excluded');
        System.assertEquals(0, result.totalCount);
    }

    @isTest
    static void testGetMilestoneInstallmentsThrowsForWrongType() {

        Business_Process__c bp = [
            SELECT Id FROM Business_Process__c WHERE Type__c = 'Handover Units' LIMIT 1
        ];

        Boolean threw = false;

        Test.startTest();
        try {
            MilestoneInstallmentsSummaryFromBp.getMilestoneInstallments(bp.Id);
        }
        catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assertEquals(true, threw, 'Should reject Business Processes of the wrong Type');
    }

    @isTest
    static void testGetMilestoneInstallmentsThrowsWhenNoMilestone() {

        Business_Process__c bp = [
            SELECT Id FROM Business_Process__c
            WHERE Type__c = 'Project Milestone Confirmation' AND Milestone__c = null
            LIMIT 1
        ];

        Boolean threw = false;

        Test.startTest();
        try {
            MilestoneInstallmentsSummaryFromBp.getMilestoneInstallments(bp.Id);
        }
        catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assertEquals(true, threw, 'Should reject Business Processes without a linked Milestone');
    }
}