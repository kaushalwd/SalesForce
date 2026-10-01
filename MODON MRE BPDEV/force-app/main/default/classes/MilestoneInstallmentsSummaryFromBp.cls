public class MilestoneInstallmentsSummaryFromBp {

    private static final String VALID_TYPE = 'Project Milestone Confirmation';

    public class InstallmentRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String salesOrderName;
        @AuraEnabled public String unitName;
        @AuraEnabled public String projectName;
        @AuraEnabled public String phaseName;
        @AuraEnabled public Date milestoneDate;
        @AuraEnabled public String paymentStatus;
        @AuraEnabled public String salesOrderStatus;
        @AuraEnabled public Decimal installmentAmount;
        @AuraEnabled public String currencyCode;
    }

    public class CurrencyTotal {
        @AuraEnabled public String currencyCode;
        @AuraEnabled public Decimal totalAmount;
        @AuraEnabled public Integer count;
    }

    public class MilestoneInstallmentsResult {
        @AuraEnabled public List<InstallmentRow> rows;
        @AuraEnabled public List<CurrencyTotal> totals;
        @AuraEnabled public Integer totalCount;
    }

    private static Milestone__c getMilestone(Id businessProcessId) {

        if (String.isBlank(businessProcessId)) {
            throw new AuraHandledException('Missing Business Process record.');
        }

        List<Business_Process__c> bps = [
            SELECT Id, Type__c, Milestone__c, Milestone__r.Id, Milestone__r.Phase__c
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

    // Phase__c of the Business Process, or null when it has none.
    private static Id getBusinessProcessPhaseId(Id businessProcessId) {
        List<Business_Process__c> bps = [
            SELECT Phase__c
            FROM Business_Process__c
            WHERE Id = :businessProcessId
            LIMIT 1
        ];
        return bps.isEmpty() ? null : bps[0].Phase__c;
    }

    @AuraEnabled
    public static MilestoneInstallmentsResult getMilestoneInstallments(Id businessProcessId) {

        Milestone__c milestone = getMilestone(businessProcessId);

        List<String> soStatuses = System.Label.Sales_Order_Status_Filter.split(',');
        for (Integer i = 0; i < soStatuses.size(); i++) {
            soStatuses[i] = soStatuses[i].trim();
        }

        List<InstallmentRow> rows = new List<InstallmentRow>();
        Map<String, CurrencyTotal> totalsByCurrency = new Map<String, CurrencyTotal>();

        // Same Sales Order Installment fetching logic as PaymentMilestoneSR (paymentMilestoneSR /
        // SRPaymentReadinessController.getInstallmentsByMilestone): resolve via
        // Milestone__c.Payment_Installments__r rather than filtering SOI directly on Milestone_Installment__c.
        Set<Id> paymentInstallmentIds = new Set<Id>();
        Id milestoneId = milestone.Id;
        String msQuery = System.Label.Milestone_Payment_Installments_Query;
        for (Milestone__c ms : (List<Milestone__c>) Database.query(msQuery)) {
            for (PaymentInstallements__c pi : ms.Payment_Installments__r) {
                paymentInstallmentIds.add(pi.Id);
            }
        }

        // Only units in the Business Process's Phase (no phase filter when the BP has no Phase).
        Id phaseId = getBusinessProcessPhaseId(businessProcessId);

        String soiQuery =
            'SELECT Id, MilestoneDate__c, PaymentStatus__c, InstallmentAmount__c, CurrencyIsoCode,' +
            '       SalesOrder__r.Name, SalesOrder__r.Status__c,' +
            '       SalesOrder__r.Unit__r.Name, SalesOrder__r.Unit__r.Project_Name__c,' +
            '       SalesOrder__r.Unit__r.Phase__r.Name' +
            ' FROM SalesOrderInstallments__c' +
            ' WHERE PaymentInstallments__c IN :paymentInstallmentIds' +
            '   AND SalesOrder__r.Status__c IN :soStatuses';
        if (phaseId != null) {
            soiQuery += ' AND SalesOrder__r.Unit__r.Phase__c = :phaseId';
        }
        soiQuery += ' ORDER BY MilestoneDate__c ASC NULLS LAST';

        List<SalesOrderInstallments__c> sois = Database.query(soiQuery);

        for (SalesOrderInstallments__c soi : sois) {

            InstallmentRow row = new InstallmentRow();
            row.id = soi.Id;
            row.salesOrderName = soi.SalesOrder__r?.Name;
            row.unitName = soi.SalesOrder__r?.Unit__r?.Name;
            row.projectName = soi.SalesOrder__r?.Unit__r?.Project_Name__c;
            row.phaseName = soi.SalesOrder__r?.Unit__r?.Phase__r?.Name;
            row.milestoneDate = soi.MilestoneDate__c;
            row.paymentStatus = soi.PaymentStatus__c;
            row.salesOrderStatus = soi.SalesOrder__r?.Status__c;
            row.installmentAmount = soi.InstallmentAmount__c;
            row.currencyCode = soi.CurrencyIsoCode;
            rows.add(row);

            CurrencyTotal total = totalsByCurrency.get(soi.CurrencyIsoCode);

            if (total == null) {
                total = new CurrencyTotal();
                total.currencyCode = soi.CurrencyIsoCode;
                total.totalAmount = 0;
                total.count = 0;
                totalsByCurrency.put(soi.CurrencyIsoCode, total);
            }

            total.totalAmount += (soi.InstallmentAmount__c != null ? soi.InstallmentAmount__c : 0);
            total.count++;
        }

        MilestoneInstallmentsResult result = new MilestoneInstallmentsResult();
        result.rows = rows;
        result.totals = totalsByCurrency.values();
        result.totalCount = rows.size();
        return result;
    }

    // Number of Units under the same Phase as the Milestone linked to this Business Process,
    // e.g. equivalent to SELECT Id FROM Unit__c WHERE Phase__r.Name = '<phase name>'.
    @AuraEnabled
    public static Integer getUnitCountForMilestone(Id businessProcessId) {

        Milestone__c milestone = getMilestone(businessProcessId);

        if (milestone.Phase__c == null) {
            return 0;
        }

        return [SELECT COUNT() FROM Unit__c WHERE Phase__c = :milestone.Phase__c];
    }
}