/**********************************************************************************************************************
* Name               : MBP_manageDashboardcontroller
* Description        : This class is used as the Apex controller for Broker Portal Dashboard Management.
* Usage              : LWC components related to Broker Dashboard
* Created By         : Upendra Reddy
* --------------------------------------------------------------------------------------------------------------------
* Version     Author                          Date             Comment
* 1.0         upendra.asam@modon.com        27 Oct 2025      Initial Draft – Core logic for Dashboard Management,
*                                                               
* 1.1         upendra.asam@modon.com        18 Aug 2026      updated logic to exclude the neccery status and which matches to aspire program and updated filter logic as well                                                                                                                                                                             
**********************************************************************************************************************/

public without sharing class MBP_manageDashboardcontroller {

    // Only Sold units should count toward these dashboards.
    private static Set<String> getAllowedUnitStatuses() {
        return new Set<String>{ 'Sold' };
    }

   
    private static Set<String> getExcludedSOStatuses() {
        return new Set<String>{
            'Cancelled',
            'System cancelled',
            'Cancelled SR',
            'Voided',
            'Pending Blocking Fees',
            'Blocking Fees Collected',
            'Unit Swap Cancelled - SR',
                'Property Transfer Cancelled - SR',
            'Unit Upgrade Cancelled - SR',
            'Unit Cancellation Cancelled - SR',
            'Unit Consolidation Cancelled - SR',
            'Property Transfer Title Deed Cancelled - SR'
        };
    }

    // Sales orders sourced from Modon - Egypt are always excluded from these dashboards.
    private static final String EXCLUDED_SOURCE_ENTITY = 'Modon - Egypt';

    private class UserInfo {
        public String brokerType;
        public Id accountId;
        public Id contactId;
        public UserInfo(User u) {
            this.brokerType = u.Contact != null ? u.Contact.Broker_Type__c : null;
            this.accountId = u.AccountId;
            this.contactId = u.ContactId;
        }
    }

    private static UserInfo getCurrentUserInfo() {
        User u = MBP_UtilityClass.getCurrentUser();
        return new UserInfo(u);
    }

    private static void aggregateData(Map<String, Map<String, Object>> result, String key, Decimal price) {
        if (!result.containsKey(key)) {
            result.put(key, new Map<String, Object>{ 'unitCount' => 0, 'totalSales' => 0.0 });
        }
        Map<String, Object> data = result.get(key);
        data.put('unitCount', (Integer)data.get('unitCount') + 1);
        data.put('totalSales', (Decimal)data.get('totalSales') + (price != null ? price : 0));
    }

  private static String getBrokerCondition(UserInfo uInfo) {
    if (uInfo.brokerType == 'Agency Admin' || uInfo.brokerType == 'Owner') {
        return ' AND (Opportunity__r.BrokerAgency__c = :brokerAgencyId' +
               ' OR Old_Opportunity__r.BrokerAgency__c = :brokerAgencyId)';
    } else if (uInfo.brokerType == 'Agent') {
        return ' AND ((Opportunity__r.BrokerAgency__c = :brokerAgencyId' +
               ' AND Opportunity__r.BrokerAgent__c = :brokerAgentId)' +
               ' OR (Old_Opportunity__r.BrokerAgency__c = :brokerAgencyId' +
               ' AND Old_Opportunity__r.BrokerAgent__c = :brokerAgentId))';
    }
    return '';
}

    // Computes a 12-full-month range that EXCLUDES the current month:
    // end date = last day of last month, start date = first day of the month 11 months before that.
    // e.g. if today is in August 2026 -> range is Aug 1 2025 - Jul 31 2026.
    private static Date getLast12MonthsStart(Date today) {
        Date last12End = getLast12MonthsEnd(today);
        return Date.newInstance(last12End.year(), last12End.month(), 1).addMonths(-11);
    }
    private static Date getLast12MonthsEnd(Date today) {
        return Date.newInstance(today.year(), today.month(), 1).addDays(-1);
    }

    // CreatedDate (the Sales Order's own creation date) is a DateTime field, so every
    // upper bound below is stored as the day AFTER the end date and applied with "<"
    // in appendDateFilter() -- an inclusive "<= endOfRangeDate" would silently drop
    // any Sales Order created later that same day.
    private static Map<String, Object> dashboardBinds(UserInfo uInfo, Set<String> excludedSOStatuses, Date startDate, Date endDate) {
        Date today = Date.today();
        Date fyStart = Date.newInstance(today.year(), 4, 1);
        if (today.month() < 4) fyStart = Date.newInstance(today.year() - 1, 4, 1);
        Date fyEnd = fyStart.addYears(1).addDays(-1);
        Date prevFyStart = fyStart.addYears(-1);
        Date prevFyEnd = fyStart.addDays(-1);
        Date cyEnd = Date.newInstance(today.year(), 12, 31);
        Date pyEnd = Date.newInstance(today.year() - 1, 12, 31);
        Date last12End = getLast12MonthsEnd(today);
        return new Map<String, Object>{
            'excludedSOStatuses' => excludedSOStatuses,
            'brokerAgencyId' => uInfo.accountId,
            'brokerAgentId' => uInfo.contactId,
            'fyStart' => fyStart,
            'fyEndExclusive' => fyEnd.addDays(1),
            'prevFyStart' => prevFyStart,
            'prevFyEndExclusive' => prevFyEnd.addDays(1),
            'cyStart' => Date.newInstance(today.year(), 1, 1),
            'cyEndExclusive' => cyEnd.addDays(1),
            'pyStart' => Date.newInstance(today.year() - 1, 1, 1),
            'pyEndExclusive' => pyEnd.addDays(1),
            'last12Start' => getLast12MonthsStart(today),
            'last12EndExclusive' => last12End.addDays(1),
            'startDate' => startDate,
            'endDateExclusive' => (endDate == null ? null : endDate.addDays(1))
        };
    }

    private static List<SalesOrder__c> queryDashboardOrders(String query, UserInfo uInfo, Set<String> excludedSOStatuses, Date startDate, Date endDate) {
        return (List<SalesOrder__c>) Database.queryWithBinds(
            query,
            dashboardBinds(uInfo, excludedSOStatuses, startDate, endDate),
            AccessLevel.SYSTEM_MODE
        );
    }

    // Appends the correct date-range condition for the given filterType, filtering on
    // the Sales Order's own CreatedDate (SO creation date) rather than the unit's sold date.
    // 'All Time' (and anything unrecognized) deliberately adds no date condition.
    private static String appendDateFilter(String query, String filterType, Date today) {
        if (filterType == 'Current FY') {
            query += ' AND CreatedDate >= :fyStart AND CreatedDate < :fyEndExclusive';
        } else if (filterType == 'Previous FY') {
            query += ' AND CreatedDate >= :prevFyStart AND CreatedDate < :prevFyEndExclusive';
        } else if (filterType == 'Current Year') {
            query += ' AND CreatedDate >= :cyStart AND CreatedDate < :cyEndExclusive';
        } else if (filterType == 'Previous Year') {
            query += ' AND CreatedDate >= :pyStart AND CreatedDate < :pyEndExclusive';
        } else if (filterType == 'Last 12 Months') {
            query += ' AND CreatedDate >= :last12Start AND CreatedDate < :last12EndExclusive';
        }
        // 'All Time' and 'Custom' (handled separately by callers with startDate/endDate) fall through with no change here.
        return query;
    }

  @AuraEnabled
public static Map<String, Map<String, Object>> getUnitsByNationalityData(String filterType, Date startDate, Date endDate) {
    Set<String> allowedUnitStatuses = getAllowedUnitStatuses();
    Set<String> excludedSOStatuses = getExcludedSOStatuses();

    UserInfo uInfo = getCurrentUserInfo();
    Id brokerAgencyId = uInfo.accountId;
    Id brokerAgentId = uInfo.contactId;
    Map<String, Map<String, Object>> result = new Map<String, Map<String, Object>>();

    String query = 'SELECT Unit__r.Id,TotalAmount__c, Unit__r.Status__c, Unit__r.TotalPrice__c,Unit__r.Unit_Sold_Date__c,' +
                   ' Opportunity__r.Nationality__c, CreatedDate' +
                   ' FROM SalesOrder__c' +
                   ' WHERE Status__c NOT IN :excludedSOStatuses' +
                   ' AND Sales_Type__c = \'Indirect\'' +
                   ' AND Source_Entity__c != \'' + EXCLUDED_SOURCE_ENTITY + '\'' +
                   ' AND UAE_Resident_Status__c = \'Resident\'' +
                   ' AND Unit__c != null' +
                   getBrokerCondition(uInfo);

    Date today = Date.today();

    if (filterType == 'Custom' && startDate != null && endDate != null) {
        query += ' AND CreatedDate >= :startDate AND CreatedDate < :endDateExclusive';
    } else {
        query = appendDateFilter(query, filterType, today);
    }

    for (SalesOrder__c so : queryDashboardOrders(query, uInfo, excludedSOStatuses, startDate, endDate)) {
    if (so.Unit__r == null || !allowedUnitStatuses.contains(so.Unit__r.Status__c)) continue;

    
    if (String.isNotBlank(so.Opportunity__r?.Nationality__c)) {
        aggregateData(result, so.Opportunity__r.Nationality__c, so.TotalAmount__c != null ? so.TotalAmount__c : 0);
    }
}


    return result;
}
@AuraEnabled
public static Map<String, Map<String, Decimal>> getMonthlySalesByProject(String filterType, Date startDate, Date endDate) {
    Set<String> allowedUnitStatuses = getAllowedUnitStatuses();
    Set<String> excludedSOStatuses = getExcludedSOStatuses();

    UserInfo uInfo = getCurrentUserInfo();
    Id brokerAgencyId = uInfo.accountId;
    Id brokerAgentId = uInfo.contactId;
    Map<String, Map<String, Decimal>> result = new Map<String, Map<String, Decimal>>();
    List<String> months = new List<String>{'January','February','March','April','May','June','July','August','September','October','November','December'};

    String query = 'SELECT Unit__r.TotalPrice__c,TotalAmount__c, Unit__r.Unit_Sold_Date__c, Unit__r.Status__c, Unit__r.Phase__r.Project__r.Name, CreatedDate' +
                   ' FROM SalesOrder__c' +
                   ' WHERE Status__c NOT IN :excludedSOStatuses' +
                   ' AND Sales_Type__c = \'Indirect\'' +
                   ' AND Source_Entity__c != \'' + EXCLUDED_SOURCE_ENTITY + '\'' +
                   ' AND Unit__c != null' +
                   getBrokerCondition(uInfo);

    Date today = Date.today();

    if (filterType == 'Custom' && startDate != null && endDate != null) {
        query += ' AND CreatedDate >= :startDate AND CreatedDate < :endDateExclusive';
    } else {
        query = appendDateFilter(query, filterType, today);
    }


   for (SalesOrder__c so : queryDashboardOrders(query, uInfo, excludedSOStatuses, startDate, endDate)) {
    if (so.Unit__r == null || !allowedUnitStatuses.contains(so.Unit__r.Status__c)) continue;

    Date soldDate = so.CreatedDate != null ? so.CreatedDate.date() : null;
    String projectName = so.Unit__r.Phase__r?.Project__r?.Name;

    if (soldDate != null && String.isNotBlank(projectName)) {
        String monthLabel = months[soldDate.month() - 1] + ' ' + soldDate.year();

        if (!result.containsKey(monthLabel)) {
            result.put(monthLabel, new Map<String, Decimal>());
        }

        Map<String, Decimal> projectMap = result.get(monthLabel);
        Decimal totalPrice = (so.TotalAmount__c != null) ? so.TotalAmount__c : 0;

        projectMap.put(
            projectName,
            (projectMap.containsKey(projectName) ? projectMap.get(projectName) : 0) + totalPrice
        );
    }
}


    return result;
}
@AuraEnabled
public static Map<String, Map<String, Object>> getSalesByResidence(String filterType, Date startDate, Date endDate) {
    Set<String> allowedUnitStatuses = getAllowedUnitStatuses();
    Set<String> excludedSOStatuses = getExcludedSOStatuses();
  
    UserInfo uInfo = getCurrentUserInfo();
    Id brokerAgencyId = uInfo.accountId;
    Id brokerAgentId = uInfo.contactId;
    Map<String, Map<String, Object>> result = new Map<String, Map<String, Object>>();

    String query = 'SELECT Unit__r.Id, Unit__r.Status__c, Unit__r.TotalPrice__c,TotalAmount__c, UAE_Resident_Status__c, Unit__r.Unit_Sold_Date__c,CreatedDate' +
                   ' FROM SalesOrder__c' +
                   ' WHERE Status__c NOT IN :excludedSOStatuses' +
                   ' AND Sales_Type__c = \'Indirect\'' +
                   ' AND Source_Entity__c != \'' + EXCLUDED_SOURCE_ENTITY + '\'' +
                   ' AND Unit__c != null' +
                   getBrokerCondition(uInfo);

    Date today = Date.today();

    if (filterType == 'Custom' && startDate != null && endDate != null) {
        query += ' AND CreatedDate >= :startDate AND CreatedDate < :endDateExclusive';
    } else {
        query = appendDateFilter(query, filterType, today);
    }

   for (SalesOrder__c so : queryDashboardOrders(query, uInfo, excludedSOStatuses, startDate, endDate)) {
    if (so.Unit__r == null || !allowedUnitStatuses.contains(so.Unit__r.Status__c)) continue;
    
    if (String.isNotBlank(so.UAE_Resident_Status__c)) {
        aggregateData(result, so.UAE_Resident_Status__c, so.TotalAmount__c);
    }
}


    return result;
}


    @AuraEnabled
    public static Map<String, Map<String, Object>> getSalesByBedrooms(String filterType, Date startDate, Date endDate) {
        Set<String> allowedUnitStatuses = getAllowedUnitStatuses();
        Set<String> excludedSOStatuses = getExcludedSOStatuses();
      
  UserInfo uInfo = getCurrentUserInfo();
        Id brokerAgencyId = uInfo.accountId;
        Id brokerAgentId = uInfo.contactId;
        Map<String, Map<String, Object>> result = new Map<String, Map<String, Object>>();
        
        // Build base query
    String query = 'SELECT Unit__r.Id, Unit__r.Status__c, Unit__r.TotalPrice__c,TotalAmount__c, Unit__r.Number_of_Bedrooms__c,Unit__r.Unit_Sold_Date__c, CreatedDate' +
                   ' FROM SalesOrder__c' +
                   ' WHERE Status__c NOT IN :excludedSOStatuses' +
                   ' AND Sales_Type__c = \'Indirect\'' +
                   ' AND Source_Entity__c != \'' + EXCLUDED_SOURCE_ENTITY + '\'' +
                   ' AND Unit__c != null' +
                   getBrokerCondition(uInfo);

    Date today = Date.today();

    if (filterType == 'Custom' && startDate != null && endDate != null) {
        query += ' AND CreatedDate >= :startDate AND CreatedDate < :endDateExclusive';
    } else {
        query = appendDateFilter(query, filterType, today);
    }

    // Execute query
    for (SalesOrder__c so : queryDashboardOrders(query, uInfo, excludedSOStatuses, startDate, endDate)) {
        if (so.Unit__r == null || !allowedUnitStatuses.contains(so.Unit__r.Status__c)) continue;
        String bedrooms = so.Unit__r.Number_of_Bedrooms__c != null ? String.valueOf(so.Unit__r.Number_of_Bedrooms__c) : '0';
        aggregateData(result, bedrooms, so.TotalAmount__c);
    }

    return result;
}


    @AuraEnabled
    public static Map<String, Map<String, Object>> getSalesByNationality(String filterType, Date startDate, Date endDate) {
        Set<String> allowedUnitStatuses = getAllowedUnitStatuses();
        Set<String> excludedSOStatuses = getExcludedSOStatuses();
       
        UserInfo uInfo = getCurrentUserInfo();
        Id brokerAgencyId = uInfo.accountId;
        Id brokerAgentId = uInfo.contactId;
        Map<String, Map<String, Object>> result = new Map<String, Map<String, Object>>();

        String query = 'SELECT Unit__r.Id, Unit__r.Status__c, Unit__r.TotalPrice__c,TotalAmount__c, Opportunity__r.Nationality__c,Unit__r.Unit_Sold_Date__c, CreatedDate' +
                       ' FROM SalesOrder__c' +
                       ' WHERE Status__c NOT IN :excludedSOStatuses' +
                       ' AND Sales_Type__c = \'Indirect\'' +
                       ' AND Source_Entity__c != \'' + EXCLUDED_SOURCE_ENTITY + '\'' +
                       ' AND Unit__c != null' +
                       getBrokerCondition(uInfo);

        Date today = Date.today();

        if (filterType == 'Custom' && startDate != null && endDate != null) {
            query += ' AND CreatedDate >= :startDate AND CreatedDate < :endDateExclusive';
        } else {
            query = appendDateFilter(query, filterType, today);
        }

        for (SalesOrder__c so : queryDashboardOrders(query, uInfo, excludedSOStatuses, startDate, endDate)) {
    if (so.Unit__r == null || !allowedUnitStatuses.contains(so.Unit__r.Status__c)) continue;

    if (String.isNotBlank(so.Opportunity__r?.Nationality__c)) {
        aggregateData(result, so.Opportunity__r.Nationality__c, so.TotalAmount__c);
    }
}

        return result;
    }

@AuraEnabled
public static Map<String, Map<String, Map<String, Map<String, Object>>>> getProjectUnitClassificationBedroomData(String filterType, Date startDate, Date endDate) {
    Set<String> allowedUnitStatuses = getAllowedUnitStatuses();
    Set<String> excludedSOStatuses = getExcludedSOStatuses();
    
    UserInfo uInfo = getCurrentUserInfo();
    Id brokerAgencyId = uInfo.accountId;
    Id brokerAgentId = uInfo.contactId;
    Map<String, Map<String, Map<String, Map<String, Object>>>> result = new Map<String, Map<String, Map<String, Map<String, Object>>>>();

    String query = 'SELECT Unit__r.Id, Unit__r.Status__c, TotalAmount__c,Unit__r.TotalPrice__c,' +
                   ' Unit__r.UnitClassification__c, Unit__r.Number_of_Bedrooms__c, Unit__r.Phase__r.Project__r.Name,Unit__r.Unit_Sold_Date__c, CreatedDate' +
                   ' FROM SalesOrder__c' +
                   ' WHERE Status__c NOT IN :excludedSOStatuses' +
                   ' AND Sales_Type__c = \'Indirect\'' +
                   ' AND Source_Entity__c != \'' + EXCLUDED_SOURCE_ENTITY + '\'' +
                   ' AND Unit__c != null' +
                   getBrokerCondition(uInfo);

    Date today = Date.today();

    if (filterType == 'Custom' && startDate != null && endDate != null) {
        query += ' AND CreatedDate >= :startDate AND CreatedDate < :endDateExclusive';
    } else {
        query = appendDateFilter(query, filterType, today);
    }

    for (SalesOrder__c so : queryDashboardOrders(query, uInfo, excludedSOStatuses, startDate, endDate)) {
    Unit__c unit = so.Unit__r;
    if (unit == null || !allowedUnitStatuses.contains(unit.Status__c)) continue;

    String project = unit.Phase__r?.Project__r?.Name;
    String classification = unit.UnitClassification__c;
    String bedrooms = (unit.Number_of_Bedrooms__c != null) ? String.valueOf(unit.Number_of_Bedrooms__c) : null;

    if (String.isBlank(project) || String.isBlank(classification) || String.isBlank(bedrooms)) {
        continue;
    }

    if (!result.containsKey(project)) {
        result.put(project, new Map<String, Map<String, Map<String, Object>>>());
    }
    if (!result.get(project).containsKey(classification)) {
        result.get(project).put(classification, new Map<String, Map<String, Object>>());
    }
    if (!result.get(project).get(classification).containsKey(bedrooms)) {
        result.get(project).get(classification).put(
            bedrooms, 
            new Map<String, Object>{ 'unitCount' => 0, 'totalSales' => 0 }
        );
    }

    Map<String, Object> data = result.get(project).get(classification).get(bedrooms);
    data.put('unitCount', (Integer)data.get('unitCount') + 1);
    data.put('totalSales', (Decimal)data.get('totalSales') + (so.TotalAmount__c != null ? so.TotalAmount__c : 0));
}


    return result;
}


   @AuraEnabled
public static Map<String, Map<String, Object>> getGroupedProjectSalesData(String filterType, Date startDate, Date endDate) {
    Set<String> allowedUnitStatuses = getAllowedUnitStatuses();
    Set<String> excludedSOStatuses = getExcludedSOStatuses();
   
    UserInfo uInfo = getCurrentUserInfo();
    Id brokerAgencyId = uInfo.accountId;
    Id brokerAgentId = uInfo.contactId;
    Map<String, Map<String, Object>> result = new Map<String, Map<String, Object>>();

    String query = 'SELECT Unit__r.Id, Unit__r.Status__c, Unit__r.TotalPrice__c,TotalAmount__c, Unit__r.Phase__r.Project__r.Name,Unit__r.Unit_Sold_Date__c, CreatedDate' +
                   ' FROM SalesOrder__c' +
                   ' WHERE Status__c NOT IN :excludedSOStatuses' +
                   ' AND Sales_Type__c = \'Indirect\'' +
                   ' AND Source_Entity__c != \'' + EXCLUDED_SOURCE_ENTITY + '\'' +
                   ' AND Unit__c != null' +
                   getBrokerCondition(uInfo);

    Date today = Date.today();

    if (filterType == 'Custom' && startDate != null && endDate != null) {
        query += ' AND CreatedDate >= :startDate AND CreatedDate < :endDateExclusive';
    } else {
        query = appendDateFilter(query, filterType, today);
    }

   for (SalesOrder__c so : queryDashboardOrders(query, uInfo, excludedSOStatuses, startDate, endDate)) {
    Unit__c unit = so.Unit__r;
    if (unit == null || !allowedUnitStatuses.contains(unit.Status__c)) continue;

    String project = unit.Phase__r?.Project__r?.Name;

    if (String.isNotBlank(project)) {
        aggregateData(result, project, so.TotalAmount__c != null ? so.TotalAmount__c : 0);
    }
}


    return result;
}

   @AuraEnabled
public static Decimal getTotalSalesAmount(String filterType, Date startDate, Date endDate) {
    Set<String> allowedUnitStatuses = getAllowedUnitStatuses();
    Set<String> excludedSOStatuses = getExcludedSOStatuses();
   
    UserInfo uInfo = getCurrentUserInfo();
    Id brokerAgencyId = uInfo.accountId;
    Id brokerAgentId = uInfo.contactId;
    Decimal totalSales = 0;

    String query = 'SELECT Unit__r.TotalPrice__c,TotalAmount__c, Unit__r.Status__c, CreatedDate,Unit__r.Unit_Sold_Date__c' +
                   ' FROM SalesOrder__c' +
                   ' WHERE Status__c NOT IN :excludedSOStatuses' +
                   ' AND Sales_Type__c = \'Indirect\'' +
                   ' AND Source_Entity__c != \'' + EXCLUDED_SOURCE_ENTITY + '\'' +
                   ' AND Unit__c != null' +
                   getBrokerCondition(uInfo);

    Date today = Date.today();

    if (filterType == 'Custom' && startDate != null && endDate != null) {
        query += ' AND CreatedDate >= :startDate AND CreatedDate < :endDateExclusive';
    } else {
        query = appendDateFilter(query, filterType, today);
    }

    for (SalesOrder__c so : queryDashboardOrders(query, uInfo, excludedSOStatuses, startDate, endDate)) {
        if (so.Unit__r != null && allowedUnitStatuses.contains(so.Unit__r.Status__c)) {
            totalSales += (so.TotalAmount__c != null ? so.TotalAmount__c : 0);
        }
    }

    return totalSales;
}

@AuraEnabled(cacheable=true)   
public static Map<String, Decimal> getCommissionSummary(
    Id accountId,
    Id contactId,
    String filterType,
    Date startDate,
    Date endDate
) {
    Map<String, Decimal> summary = new Map<String, Decimal>{
        'Paid' => 0,
        'Pending' => 0,
        'Total' => 0,
        'eligible'=>0
    };

    if (accountId == null || contactId == null) {
        return summary;
    }

    Date today = Date.today();
    Date fyStart;
    Date fyEnd;

    // Handle date filters
    if (String.isNotBlank(filterType)) {
        if (filterType == 'Current FY') {
            fyStart = Date.newInstance(today.year(), 4, 1);
            if (today.month() < 4) fyStart = Date.newInstance(today.year() - 1, 4, 1);
            fyEnd = fyStart.addYears(1).addDays(-1);
            startDate = fyStart;
            endDate = fyEnd;
        } else if (filterType == 'Previous FY') {
            fyStart = Date.newInstance(today.year(), 4, 1);
            if (today.month() < 4) fyStart = Date.newInstance(today.year() - 1, 4, 1);
            Date prevFyStart = fyStart.addYears(-1);
            Date prevFyEnd = fyStart.addDays(-1);
            startDate = prevFyStart;
            endDate = prevFyEnd;
        } else if (filterType == 'Current Year') {
            startDate = Date.newInstance(today.year(), 1, 1);
            endDate = Date.newInstance(today.year(), 12, 31);
        } else if (filterType == 'Previous Year') {
            startDate = Date.newInstance(today.year() - 1, 1, 1);
            endDate = Date.newInstance(today.year() - 1, 12, 31);
        } else if (filterType == 'Last 12 Months') {
            startDate = getLast12MonthsStart(today);
            endDate = getLast12MonthsEnd(today);
        } else if (filterType == 'All Time') {
            startDate = null;
            endDate = null;
        }
        // 'Custom' keeps startDate & endDate as provided
    }

    String query = 'SELECT Total_Commission_Amount_Paid__c, Total_Commission_Amount_Pending__c, Current_Commission_Payout_Now__c, Commission_Amount__c ' +
                   'FROM Commission_Line__c ' +
                   'WHERE Sales_Order__r.Unit__c != null ' +
                   'AND Commission_Line_Type__c = \'External\' ' +
                   'AND Broker_Agency__c = :accountId';

    if (startDate != null && endDate != null) {
        query += ' AND CreatedDate >= :startDate AND CreatedDate <= :endDate';
    }

    List<Commission_Line__c> comms = (List<Commission_Line__c>) Database.queryWithBinds(
        query,
        new Map<String, Object>{
            'accountId' => accountId,
            'startDate' => startDate,
            'endDate' => endDate
        },
        AccessLevel.SYSTEM_MODE
    );

    for (Commission_Line__c c : comms) {
        summary.put('Paid', summary.get('Paid') + (c.Total_Commission_Amount_Paid__c != null ? c.Total_Commission_Amount_Paid__c : 0));
        summary.put('Pending', summary.get('Pending') + (c.Total_Commission_Amount_Pending__c != null ? c.Total_Commission_Amount_Pending__c : 0));
        summary.put('Total', summary.get('Total') + (c.Commission_Amount__c != null ? c.Commission_Amount__c : 0));
        summary.put('eligible', summary.get('eligible') + (c.Current_Commission_Payout_Now__c != null ? c.Current_Commission_Payout_Now__c : 0));
    }

    return summary;
}

}