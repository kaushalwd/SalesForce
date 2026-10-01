/**
 * @description Controller class for manually running broker classification batch with custom date range
 * @author Sanath Manohar
 * @date June 2026
 */
public with sharing class MBP_BrokerClassificationRunner {

    /**
     * @description Runs the broker classification batch for a specific period
     * @param startDateStr Start date in YYYY-MM-DD format
     * @param endDateStr End date in YYYY-MM-DD format
     * @return Map containing jobId and accountCount
     */
    @AuraEnabled
    public static Map<String, Object> runBatchForPeriod(String startDateStr, String endDateStr) {
        try {
            // Parse dates
            Date startDate = Date.valueOf(startDateStr);
            Date endDate = Date.valueOf(endDateStr);

            // Validate dates
            validateDates(startDate, endDate);

            // Count broker accounts to process
            Id brokerRecordTypeId = Schema.SObjectType.Account
                .getRecordTypeInfosByDeveloperName()
                .get('Broker_Agency')
                .getRecordTypeId();

            Integer accountCount = [
                SELECT COUNT()
                FROM Account
                WHERE RecordTypeId = :brokerRecordTypeId
            ];

            // Execute batch with custom date range
            MBP_BrokerClassificationProgram_Custom batch =
                new MBP_BrokerClassificationProgram_Custom(startDate, endDate);
            Id jobId = Database.executeBatch(batch, 50);

            // Return result
            Map<String, Object> result = new Map<String, Object>();
            result.put('jobId', jobId);
            result.put('accountCount', accountCount);
            result.put('startDate', startDate);
            result.put('endDate', endDate);

            return result;

        } catch (Exception e) {
            throw new AuraHandledException('Error starting batch: ' + e.getMessage());
        }
    }

    /**
     * @description Gets the current classification summary across all brokers
     * @return List of classification tier summaries with count
     */
    @AuraEnabled(cacheable=false)
public static List<Map<String, Object>> getClassificationSummary() {
    try {
        Id brokerRecordTypeId = Schema.SObjectType.Account
            .getRecordTypeInfosByDeveloperName()
            .get('Broker_Agency')
            .getRecordTypeId();

        List<Map<String, Object>> summary = new List<Map<String, Object>>();

        // Count classified brokers by classification Id
        List<AggregateResult> results = [
            SELECT Broker_Classification__c classificationId, COUNT(Id) tierCount
            FROM Account
            WHERE RecordTypeId = :brokerRecordTypeId
            AND Broker_Classification__c != null
            GROUP BY Broker_Classification__c
        ];

        // Build map of classification Id -> broker count
        Map<Id, Integer> classificationCounts = new Map<Id, Integer>();
        Set<Id> classificationIds = new Set<Id>();

        for (AggregateResult ar : results) {
            Id classificationId = (Id) ar.get('classificationId');
            Integer countVal = (Integer) ar.get('tierCount');

            classificationCounts.put(classificationId, countVal);
            classificationIds.add(classificationId);
        }

        // Query classification records so we can return tier names in sorted order
        if (!classificationIds.isEmpty()) {
            List<Broker_Classification__c> tiers = [
                SELECT Id, Name, AnnualSalesTargetFrom__c
                FROM Broker_Classification__c
                WHERE Id IN :classificationIds
                ORDER BY AnnualSalesTargetFrom__c
            ];

            for (Broker_Classification__c tierRec : tiers) {
                Map<String, Object> tier = new Map<String, Object>();
                tier.put('tierName', tierRec.Name);
                tier.put('count', classificationCounts.get(tierRec.Id));
                summary.add(tier);
            }
        }

        // Add unclassified count
        Integer unclassifiedCount = [
            SELECT COUNT()
            FROM Account
            WHERE RecordTypeId = :brokerRecordTypeId
            AND Broker_Classification__c = null
        ];

        if (unclassifiedCount > 0) {
            Map<String, Object> unclassified = new Map<String, Object>();
            unclassified.put('tierName', 'Unclassified');
            unclassified.put('count', unclassifiedCount);
            summary.add(unclassified);
        }

        return summary;

    } catch (Exception e) {
        throw new AuraHandledException('Error getting classification summary: ' + e.getMessage());
    }
}

    /**
     * @description Validates the date range
     */
    private static void validateDates(Date startDate, Date endDate) {
        Date today = System.today();
        Date lastAllowedDate = today.toStartOfMonth().addDays(-1); // Last day of previous month

        // Check if end date is in the future
        if (endDate > lastAllowedDate) {
            throw new AuraHandledException('End date cannot be in the future or current month');
        }

        // Check if start date is after end date
        if (startDate > endDate) {
            throw new AuraHandledException('Start date must be before end date');
        }

        // Check if period is exactly 12 months
        Integer monthsDiff = startDate.monthsBetween(endDate);
        if (monthsDiff != 11) {
            throw new AuraHandledException('Period must be exactly 12 months (e.g., Jan 2025 to Dec 2025)');
        }
    }
}