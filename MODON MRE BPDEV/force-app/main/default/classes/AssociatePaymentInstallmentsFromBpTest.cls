@isTest
private class AssociatePaymentInstallmentsFromBpTest {

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

        PaymentPlan__c paymentPlan = new PaymentPlan__c(
            Name = 'Test Payment Plan',
            Type__c = 'Standard',
            Project__c = project.Id,
            Phase__c = phase.Id
        );
        insert paymentPlan;

        List<PaymentInstallements__c> installments = new List<PaymentInstallements__c>();

        for (Integer i = 1; i <= 2; i++) {
            installments.add(new PaymentInstallements__c(
                PaymentInstallment__c = paymentPlan.Id,
                MilestoneNumber__c = i,
                MilestoneDescription__c = 'Installment ' + i,
                MilestoneDate__c = Date.today().addMonths(i)
            ));
        }

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
    static void testGetEligiblePaymentInstallmentsReturnsMatches() {

        Business_Process__c bp = [
            SELECT Id FROM Business_Process__c
            WHERE Type__c = 'Project Milestone Confirmation' AND Milestone__c != null
            LIMIT 1
        ];

        Test.startTest();
        List<AssociatePaymentInstallmentsFromBp.PaymentInstallmentOption> options =
            AssociatePaymentInstallmentsFromBp.getEligiblePaymentInstallments(bp.Id);
        Test.stopTest();

        System.assertEquals(2, options.size(), 'Both unassociated installments should be returned');

        for (AssociatePaymentInstallmentsFromBp.PaymentInstallmentOption opt : options) {
            System.assertEquals('Test Project', opt.projectName);
            System.assertEquals('Test Phase', opt.phaseName);
        }
    }

    @isTest
    static void testGetEligiblePaymentInstallmentsFlagsAlreadyAssociated() {

        Business_Process__c bp = [
            SELECT Id, Milestone__c FROM Business_Process__c
            WHERE Type__c = 'Project Milestone Confirmation' AND Milestone__c != null
            LIMIT 1
        ];

        PaymentInstallements__c firstInstallment = [
            SELECT Id FROM PaymentInstallements__c ORDER BY MilestoneNumber__c ASC LIMIT 1
        ];

        firstInstallment.MilestoneInstallment__c = bp.Milestone__c;
        update firstInstallment;

        Test.startTest();
        List<AssociatePaymentInstallmentsFromBp.PaymentInstallmentOption> options =
            AssociatePaymentInstallmentsFromBp.getEligiblePaymentInstallments(bp.Id);
        Test.stopTest();

        System.assertEquals(
            2, options.size(),
            'Installments already linked to this milestone should still be returned, not hidden'
        );

        Integer flaggedCount = 0;

        for (AssociatePaymentInstallmentsFromBp.PaymentInstallmentOption opt : options) {
            if (opt.id == firstInstallment.Id) {
                System.assertEquals(true, opt.alreadyAssociated, 'Linked installment should be flagged');
                flaggedCount++;
            }
            else {
                System.assertEquals(false, opt.alreadyAssociated, 'Unlinked installment should not be flagged');
            }
        }

        System.assertEquals(1, flaggedCount, 'Exactly one installment should be flagged as already associated');
    }

    @isTest
    static void testGetEligibleExcludesInstallmentsLinkedToOtherMilestone() {

        Business_Process__c bp = [
            SELECT Id, Milestone__c FROM Business_Process__c
            WHERE Type__c = 'Project Milestone Confirmation' AND Milestone__c != null
            LIMIT 1
        ];

        Milestone__c otherMilestone = [
            SELECT Id FROM Milestone__c WHERE Id != :bp.Milestone__c LIMIT 1
        ];

        PaymentInstallements__c firstInstallment = [
            SELECT Id FROM PaymentInstallements__c ORDER BY MilestoneNumber__c ASC LIMIT 1
        ];

        firstInstallment.MilestoneInstallment__c = otherMilestone.Id;
        update firstInstallment;

        Test.startTest();
        List<AssociatePaymentInstallmentsFromBp.PaymentInstallmentOption> options =
            AssociatePaymentInstallmentsFromBp.getEligiblePaymentInstallments(bp.Id);
        Test.stopTest();

        System.assertEquals(
            1, options.size(),
            'Installments linked to a different milestone should be excluded entirely'
        );
        System.assertNotEquals(firstInstallment.Id, options[0].id);
    }

    @isTest
    static void testGetEligibleThrowsForWrongType() {

        Business_Process__c bp = [
            SELECT Id FROM Business_Process__c WHERE Type__c = 'Handover Units' LIMIT 1
        ];

        Boolean threw = false;

        Test.startTest();
        try {
            AssociatePaymentInstallmentsFromBp.getEligiblePaymentInstallments(bp.Id);
        }
        catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assertEquals(true, threw, 'Should reject Business Processes of the wrong Type');
    }

    @isTest
    static void testGetEligibleThrowsWhenNoMilestone() {

        Business_Process__c bp = [
            SELECT Id FROM Business_Process__c
            WHERE Type__c = 'Project Milestone Confirmation' AND Milestone__c = null
            LIMIT 1
        ];

        Boolean threw = false;

        Test.startTest();
        try {
            AssociatePaymentInstallmentsFromBp.getEligiblePaymentInstallments(bp.Id);
        }
        catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assertEquals(true, threw, 'Should reject Business Processes without a linked Milestone');
    }

    @isTest
    static void testAssociatePaymentInstallmentsLinksRecords() {

        Business_Process__c bp = [
            SELECT Id, Milestone__c FROM Business_Process__c
            WHERE Type__c = 'Project Milestone Confirmation' AND Milestone__c != null
            LIMIT 1
        ];

        List<Id> installmentIds = new List<Id>();

        for (PaymentInstallements__c pi : [SELECT Id FROM PaymentInstallements__c]) {
            installmentIds.add(pi.Id);
        }

        Test.startTest();
        AssociatePaymentInstallmentsFromBp.associatePaymentInstallments(bp.Id, installmentIds);
        Test.stopTest();

        List<PaymentInstallements__c> updated = [
            SELECT Id, MilestoneInstallment__c FROM PaymentInstallements__c
        ];

        for (PaymentInstallements__c pi : updated) {
            System.assertEquals(bp.Milestone__c, pi.MilestoneInstallment__c);
        }
    }

    @isTest
    static void testAssociateThrowsWhenNoIdsSelected() {

        Business_Process__c bp = [
            SELECT Id FROM Business_Process__c
            WHERE Type__c = 'Project Milestone Confirmation' AND Milestone__c != null
            LIMIT 1
        ];

        Boolean threw = false;

        Test.startTest();
        try {
            AssociatePaymentInstallmentsFromBp.associatePaymentInstallments(bp.Id, new List<Id>());
        }
        catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assertEquals(true, threw, 'Should reject an empty selection');
    }

    @isTest
    static void testRemovePaymentInstallments() {
        Business_Process__c bp = [
            SELECT Id, Milestone__c FROM Business_Process__c
            WHERE Type__c = 'Project Milestone Confirmation' AND Milestone__c != null
            LIMIT 1
        ];

        PaymentInstallements__c pi = [
            SELECT Id FROM PaymentInstallements__c LIMIT 1
        ];
        pi.MilestoneInstallment__c = bp.Milestone__c;
        update pi;

        Test.startTest();
        AssociatePaymentInstallmentsFromBp.removePaymentInstallments(bp.Id, new List<Id>{ pi.Id });
        try {
            AssociatePaymentInstallmentsFromBp.removePaymentInstallments(bp.Id, new List<Id>());
        } catch (Exception e) {}
        Test.stopTest();

        PaymentInstallements__c refreshed = [SELECT MilestoneInstallment__c FROM PaymentInstallements__c WHERE Id = :pi.Id];
        System.assertEquals(null, refreshed.MilestoneInstallment__c);
    }
}