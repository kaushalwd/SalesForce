public class AssociatePaymentInstallmentsFromBp {

    private static final String VALID_TYPE = 'Project Milestone Confirmation';

    public class PaymentInstallmentOption {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public Decimal milestoneNumber;
        @AuraEnabled public String milestoneDescription;
        @AuraEnabled public Date milestoneDate;
        @AuraEnabled public String projectName;
        @AuraEnabled public String phaseName;
        @AuraEnabled public Boolean alreadyAssociated;
    }

    private static Milestone__c getMilestone(Id businessProcessId) {

        if (String.isBlank(businessProcessId)) {
            throw new AuraHandledException('Missing Business Process record.');
        }

        List<Business_Process__c> bps = [
            SELECT Id, Type__c, Milestone__c,
                   Milestone__r.Id, Milestone__r.Project__c, Milestone__r.Phase__c
            FROM Business_Process__c
            WHERE Id = :businessProcessId
            LIMIT 1
        ];

        if (bps.isEmpty()) {
            throw new AuraHandledException('Business Process record not found.');
        }

        Business_Process__c bp = bps[0];

        if (bp.Type__c != VALID_TYPE) {
            throw new AuraHandledException(
                'This action is only available for ' + VALID_TYPE + ' business processes.'
            );
        }

        if (bp.Milestone__c == null) {
            throw new AuraHandledException('This Business Process is not linked to a Milestone record.');
        }

        return bp.Milestone__r;
    }

    @AuraEnabled
    public static List<PaymentInstallmentOption> getEligiblePaymentInstallments(Id businessProcessId) {

        Milestone__c milestone = getMilestone(businessProcessId);

        Set<Id> projectIds = new Set<Id>();
        Set<Id> phaseIds = new Set<Id>();

        if (milestone.Project__c != null) {
            projectIds.add(milestone.Project__c);
        }
        if (milestone.Phase__c != null) {
            phaseIds.add(milestone.Phase__c);
        }

        List<PaymentInstallmentOption> options = new List<PaymentInstallmentOption>();

        Id milestoneId = milestone.Id;
        String query = System.Label.Eligible_Payment_Installments_Query;

        for (PaymentInstallements__c pi : (List<PaymentInstallements__c>) Database.query(query)) {

            PaymentInstallmentOption opt = new PaymentInstallmentOption();
            opt.id = pi.Id;
            opt.name = pi.Name;
            opt.milestoneNumber = pi.MilestoneNumber__c;
            opt.milestoneDescription = pi.MilestoneDescription__c;
            opt.milestoneDate = pi.MilestoneDate__c;
            opt.projectName = pi.PaymentInstallment__r?.Project__r?.Name;
            opt.phaseName = pi.PaymentInstallment__r?.Phase__r?.Name;
            opt.alreadyAssociated = (pi.MilestoneInstallment__c == milestone.Id);
            options.add(opt);
        }

        return options;
    }

    @AuraEnabled
    public static void associatePaymentInstallments(Id businessProcessId, List<Id> paymentInstallmentIds) {

        Milestone__c milestone = getMilestone(businessProcessId);

        if (paymentInstallmentIds == null || paymentInstallmentIds.isEmpty()) {
            throw new AuraHandledException('Select at least one Payment Installment to associate.');
        }

        List<PaymentInstallements__c> toUpdate = new List<PaymentInstallements__c>();

        for (Id piId : paymentInstallmentIds) {
            toUpdate.add(new PaymentInstallements__c(
                Id = piId,
                MilestoneInstallment__c = milestone.Id
            ));
        }

        update toUpdate;
    }

    @AuraEnabled
    public static void removePaymentInstallments(Id businessProcessId, List<Id> paymentInstallmentIds) {

        Milestone__c milestone = getMilestone(businessProcessId);

        if (paymentInstallmentIds == null || paymentInstallmentIds.isEmpty()) {
            throw new AuraHandledException('Select at least one Payment Installment to remove.');
        }

        List<PaymentInstallements__c> toUpdate = new List<PaymentInstallements__c>();

        for (PaymentInstallements__c pi : [
            SELECT Id
            FROM PaymentInstallements__c
            WHERE Id IN :paymentInstallmentIds
              AND MilestoneInstallment__c = :milestone.Id
        ]) {
            toUpdate.add(new PaymentInstallements__c(
                Id = pi.Id,
                MilestoneInstallment__c = null
            ));
        }

        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }
}