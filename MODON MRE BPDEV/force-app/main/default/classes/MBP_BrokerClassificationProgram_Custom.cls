/* Version       Author                              Date                 Comment
* 1.0           sanath.manohar@modon.com             June 2026            Initial Draft - custom version of broker classification
*                                                                          batch that accepts a custom date range.
* 1.1           sanath.manohar@modon.com             07 July 2026         Broker_Monthly_Performance__c dedupe logic aligned exactly with
*                                                                          MBP_BrokerClassificationProgram so both classes build/match the
*                                                                          Broker_Agency__c-Month__c-Year__c key the same way. Both now fetch
*                                                                          the FULL existing record (not just Id) and refresh its fields in
*                                                                          place before upserting, so whichever class runs second for a given
*                                                                          agency/month/year always finds and updates the same row instead of
*                                                                          inserting a duplicate.
* 1.2           sanath.manohar@modon.com,            21 July 2026         Both sales aggregate queries (period sales, monthly sales) now
*                                         filter on Unit_Status__c = 'Sold' instead of Status__c = 'completed',
*                                                                          and both add two extra exclusion filters, kept IDENTICAL to
*                                                                          MBP_BrokerClassificationProgram:
*                                                                            (a) Status__c NOT IN (Cancelled, System cancelled, Cancelled SR,
*                                                                                Voided, Property Transfer Cancelled - SR, Unit Swap
*                                                                                Cancelled - SR, Unit Upgrade Cancelled - SR, Unit Cancellation
*                                                                                Cancelled - SR, Unit Consolidation Cancelled - SR, Property
*                                                                                Transfer Title Deed Cancelled - SR) -- via shared
*                                                                                EXCLUDED_SO_STATUSES set.
*                                                                            (b) Source_Entity__c != 'Modon - Egypt' -- via
*                                                                                EXCLUDED_SOURCE_ENTITY.
*                                                                          No other logic changed.
*/
global class MBP_BrokerClassificationProgram_Custom implements Database.Batchable<sObject>, Database.Stateful, database.allowscallouts {

    public List<Broker_Classification__c> classificationTiers;
    public Date customStartDate;
    public Date customEndDate;
    public String periodValue;

    /* ------------------------------------------------------------------
* Update 21 July 2026 -- SalesOrder__c Status__c values that must be
* EXCLUDED from every sales aggregate query in this class. Kept IDENTICAL
* to the shared set in MBP_BrokerClassificationProgram so both classes
* stay in sync if this list ever changes.
* ------------------------------------------------------------------ */
    private static final Set<String> EXCLUDED_SO_STATUSES = new Set<String>{
        'Cancelled',
        'System cancelled',
        'Cancelled SR',
        'Voided',
        'Property Transfer Cancelled - SR',
        'Unit Swap Cancelled - SR',
        'Unit Upgrade Cancelled - SR',
        'Unit Cancellation Cancelled - SR',
        'Unit Consolidation Cancelled - SR',
        'Property Transfer Title Deed Cancelled - SR'
    };

    /* Update 21 July 2026 -- Source_Entity__c value to exclude from every
* sales aggregate query in this class. */
    private static final String EXCLUDED_SOURCE_ENTITY = 'Modon - Egypt';

    /**
* Constructor for custom date range
*/
    public MBP_BrokerClassificationProgram_Custom(Date startDate, Date endDate) {
        this.customStartDate = startDate;
        this.customEndDate = endDate;

        // Format period string
        String startMonth = Datetime.newInstance(startDate, Time.newInstance(0,0,0,0)).format('MMMM yyyy');
        String endMonth = Datetime.newInstance(endDate, Time.newInstance(0,0,0,0)).format('MMMM yyyy');
        this.periodValue = startMonth + ' - ' + endMonth;

        System.debug('Custom Period: ' + this.periodValue);
    }

    global List<Account> start(Database.BatchableContext context) {
        // Use the year from the end date for classification tiers
        String targetYear = String.valueOf(customEndDate.year());

        classificationTiers = [
            SELECT Id, AnnualSalesTargetFrom__c, AnnualSalesTargetTo__c,
            AnnualSalesTargetFromInternational__c, AnnualSalesTargetToInternational__c, Name
            FROM Broker_Classification__c
            WHERE Year__c = :targetYear
            ORDER BY AnnualSalesTargetFrom__c
        ];

        Id brokerRecordTypeId = Schema.SObjectType.Account
            .getRecordTypeInfosByDeveloperName()
            .get('Broker_Agency')
            .getRecordTypeId();

        return [
            SELECT Id, Name, Broker_Classification__c, ParentId, Agency_Region__c,
            Parent.Broker_Classification__c, ClassificationSalesAmount__c,
            Downgrade_Warning_Date__c, Company_Email_Address__c
            FROM Account
            WHERE RecordTypeId = :brokerRecordTypeId
        ];
    }

    global void execute(Database.BatchableContext context, List<Account> brokerAccounts) {

        final String REGION_DOMESTIC = 'Domestic';
        final String REGION_INTERNATIONAL = 'International';

        Map<Id, Account> accountMap = new Map<Id, Account>(brokerAccounts);
        Map<Id, Set<Id>> childAccountsMap = new Map<Id, Set<Id>>();
        Set<Id> allAccountIds = new Set<Id>(accountMap.keySet());

        for (Account child : [
            SELECT Id, ParentId FROM Account
            WHERE ParentId IN :accountMap.keySet()
        ]) {
            allAccountIds.add(child.Id);
            if (!childAccountsMap.containsKey(child.ParentId)) {
                childAccountsMap.put(child.ParentId, new Set<Id>());
            }
            childAccountsMap.get(child.ParentId).add(child.Id);
        }

        // Calculate sales for custom period
        // Update 21 July 2026: filter on Unit_Status__c = 'Sold' instead of
        // Status__c = 'completed', plus the two exclusion filters.
        Map<Id, SalesInfo> agencySalesMap = new Map<Id, SalesInfo>();

        for (AggregateResult ar : [
            SELECT Opportunity__r.BrokerAgency__c agencyId,
            SUM(TotalAmount__c) totalSales,
            COUNT(Id) saleCount
            FROM SalesOrder__c
            WHERE Opportunity__r.BrokerAgency__c IN :allAccountIds
            AND SOCreationDate__c >= :customStartDate
            AND SOCreationDate__c <= :customEndDate
            AND Unit_Status__c = 'Sold'
            AND Status__c NOT IN :EXCLUDED_SO_STATUSES
            AND Source_Entity__c != :EXCLUDED_SOURCE_ENTITY
            GROUP BY Opportunity__r.BrokerAgency__c
        ]) {
            agencySalesMap.put((Id) ar.get('agencyId'),
                               new SalesInfo((Integer) ar.get('saleCount'),
                                             (Decimal) ar.get('totalSales')));
        }

        // Calculate monthly sales for the last month of the period
        // Update 21 July 2026: filter on Unit_Status__c = 'Sold' instead of
        // Status__c = 'completed', plus the two exclusion filters.
        Date lastMonthStart = customEndDate.toStartOfMonth();
        Date lastMonthEnd = customEndDate;

        Map<Id, Decimal> monthlySalesMap = new Map<Id, Decimal>();

        for (AggregateResult ar : [
            SELECT Opportunity__r.BrokerAgency__c agencyId,
            SUM(TotalAmount__c) totalSales
            FROM SalesOrder__c
            WHERE Opportunity__r.BrokerAgency__c IN :allAccountIds
            AND SOCreationDate__c >= :lastMonthStart
            AND SOCreationDate__c <= :lastMonthEnd
            AND Unit_Status__c = 'Sold'
            AND Status__c NOT IN :EXCLUDED_SO_STATUSES
            AND Source_Entity__c != :EXCLUDED_SOURCE_ENTITY
            GROUP BY Opportunity__r.BrokerAgency__c
        ]) {
            monthlySalesMap.put((Id)ar.get('agencyId'), (Decimal)ar.get('totalSales'));
        }

        Map<Id, Id> oldClassificationMap = new Map<Id, Id>();
        Map<Id, Id> newClassificationMapForPeriod = new Map<Id, Id>();

        // Determine if this is a historical run or latest period
        Date today = System.today();
        Date latestPeriodEnd = today.toStartOfMonth().addDays(-1); // Last day of previous month
        Boolean isLatestPeriod = (customEndDate >= latestPeriodEnd.addDays(-31) && customEndDate <= latestPeriodEnd);

        for (Account acc : accountMap.values()) {

            Decimal netSales = agencySalesMap.containsKey(acc.Id)
                ? agencySalesMap.get(acc.Id).totalSalesAmount
                : 0;

            Id oldClassification = acc.Broker_Classification__c;
            oldClassificationMap.put(acc.Id, oldClassification);

            Id newClassification;

            for (Broker_Classification__c tier : classificationTiers) {

                if (acc.Agency_Region__c == REGION_DOMESTIC &&
                    netSales >= tier.AnnualSalesTargetFrom__c &&
                    netSales <= tier.AnnualSalesTargetTo__c) {
                        newClassification = tier.Id;
                        break;
                    }
                if (acc.Agency_Region__c == REGION_INTERNATIONAL &&
                    netSales >= tier.AnnualSalesTargetFromInternational__c &&
                    netSales <= tier.AnnualSalesTargetToInternational__c) {
                        newClassification = tier.Id;
                        break;
                    }
            }

            newClassificationMapForPeriod.put(acc.Id, newClassification);

            // Only update Account classification if this is the latest period
            if (isLatestPeriod && newClassification != null) {
                acc.Broker_Classification__c = newClassification;
                acc.ClassificationSalesAmount__c = netSales;
            }
        }

        // Update accounts only if this is the latest period
        if (isLatestPeriod) {
            Database.update(accountMap.values(), false);
        }

        // ------------------------------------------------------------------
        // Broker_Monthly_Performance__c dedupe — kept IDENTICAL in shape to
        // MBP_BrokerClassificationProgram: same key format
        // (Broker_Agency__c-Month__c-Year__c), same "fetch full record,
        // refresh fields in place, then upsert" approach. Whichever class
        // runs for a given agency/month/year second will find this same
        // record and update it instead of creating a duplicate.
        // ------------------------------------------------------------------
        List<Broker_Monthly_Performance__c> monthlyList = new List<Broker_Monthly_Performance__c>();
        String lastMonth = Datetime.newInstance(customEndDate, Time.newInstance(0,0,0,0)).format('MMMM');
        String year = String.valueOf(customEndDate.year());

        Map<String, Broker_Monthly_Performance__c> existingRecords = new Map<String, Broker_Monthly_Performance__c>();

        for (Broker_Monthly_Performance__c rec : [
            SELECT Id, Broker_Agency__c, Name, Month__c, Year__c,
            Current_Classification__c, Previous_Classification__c,
            Monthly_Sales__c, Rolling_12M_Sales__c, Period__c, Change_Type__c
            FROM Broker_Monthly_Performance__c
            WHERE Broker_Agency__c IN :allAccountIds
            AND Period__c = :periodValue           // <-- same: Period__c, not Year__c
        ]) {
            String key = buildDedupeKey(rec.Broker_Agency__c, rec.Period__c);
            existingRecords.put(key, rec);
        }

        for (Account acc : accountMap.values()) {

            String key = buildDedupeKey(acc.Id, periodValue);

            Broker_Monthly_Performance__c rec = existingRecords.containsKey(key)
                ? existingRecords.get(key)
                : new Broker_Monthly_Performance__c();

            if (rec.Id == null) {
                rec.Broker_Agency__c = acc.Id;
                rec.Month__c = lastMonth;
                rec.Year__c = year;
            }

            rec.Current_Classification__c = newClassificationMapForPeriod.get(acc.Id);
            rec.Previous_Classification__c = oldClassificationMap.get(acc.Id);
            rec.Monthly_Sales__c = monthlySalesMap.containsKey(acc.Id) ? monthlySalesMap.get(acc.Id) : 0;

            Decimal periodSales = agencySalesMap.containsKey(acc.Id) ? agencySalesMap.get(acc.Id).totalSalesAmount : 0;
            rec.Rolling_12M_Sales__c = periodSales;
            rec.Period__c = periodValue;

            Id oldClass = oldClassificationMap.get(acc.Id);
            Id newClass = newClassificationMapForPeriod.get(acc.Id);

            if (oldClass == newClass) {
                rec.Change_Type__c = 'No Change';
            } else {
                Integer oldIndex = getTierIndex(oldClass);
                Integer newIndex = getTierIndex(newClass);
                if (newIndex > oldIndex) rec.Change_Type__c = 'Upgrade';
                else if (newIndex < oldIndex) rec.Change_Type__c = 'Downgrade';
            }

            monthlyList.add(rec);
        }

        if (!monthlyList.isEmpty()) {
            // Records with an existing Id are updated in place; records without
            // an Id (new agency/month/year combinations) are inserted — same
            // Database.upsert pattern used in MBP_BrokerClassificationProgram.
            Database.upsert(monthlyList, false);
        }
    }

    global void finish(Database.BatchableContext context) {
        System.debug('Broker Classification batch completed for period: ' + periodValue);
    }

    public Integer getTierIndex(Id tierId) {
        for (Integer i = 0; i < classificationTiers.size(); i++) {
            if (classificationTiers[i].Id == tierId) {
                return i;
            }
        }
        return -1;
    }

    public class SalesInfo {
        public Integer totalSaleCount;
        public Decimal totalSalesAmount;

        public SalesInfo(Integer count, Decimal amount) {
            this.totalSaleCount = count != null ? count : 0;
            this.totalSalesAmount = amount != null ? amount : 0;
        }
    }
    private static String buildDedupeKey(Id agencyId, String period) {
        return String.valueOf(agencyId) + '-' + (period == null ? '' : period.trim());
    }
}