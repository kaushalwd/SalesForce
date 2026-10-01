/**********************************************************************************************************************
* Name               : SalesOrderSLAHelper                                                        
* Description        : This class is used as a helper for SLA and Associate Assignment for Sales Orders
* Created By         : ActiveMinds                                                
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* Version       Author                                      Date            Comment                                                                       
* 1.0           Fatima Khan                                 12 Jun 2025     Initial Draft 
* 2.0           Kumaravel                                   16 Feb 2026     null pointer exception issue
* 3.0           Fatima Khan                                 16 Feb 2026     Fix to stop round robin user mis-assignment
* 4.0           Fatima Khan                                 07 Apr 2024     Optimized Code overall, Removed Round Robin for Sales Operations(To Be done via matrix now) and Finance(to be = Sales Operations Associate), changed debug statements.
******************************************************************************************************************/

public without sharing class SalesOrderSLAHelper {

    /*4.0:
     * Global variables added: shared constants, caches, team names, sub-status values,
     * and business hours mappings used across SLA and associate assignment logic.
     */
    private static Integer dmlDepth = 0;

    private static List<Holiday> holidaysCache;
    private static Set<Date> holidayDatesCache;

    private static Map<Id, Id> soaaSalesToOpsCache;

    private static Map<String, BusinessHours> bhByTeamCache;
    private static Map<String, BusinessHours> bhByNameCache;
    private static BusinessHours defaultBhCache;

    private static Map<String, Master_SLA__c> masterByKeyCache;

    private static final String TEAM_SALES = 'Sales';
    private static final String TEAM_SALES_OPS = 'Sales Operation';
    private static final String TEAM_FINANCE = 'Finance';
    private static final String TEAM_CM = 'Customer Management';
    private static final String TEAM_UNKNOWN = 'Unknown';

    private static final String SUB_PENDING_SALES = 'Pending with Sales';
    private static final String SUB_PENDING_SALES_TEAM = 'Pending With Sales.';
    private static final String SUB_SPA_IN_PROGRESS = 'SPA In Progress';
    private static final String SUB_PENDING_SALES_OPS = 'Pending With Sales Operation';    
    private static final String SUB_UNDER_FINANCE = 'Under Finance Verification';
    private static final String SUB_PENDING_CM = 'Pending with CM';

    private static final Map<String, String> TEAM_TO_BH_NAME = new Map<String, String>{
        TEAM_SALES => 'Sales Team',
        TEAM_SALES_OPS => 'Sales Operation Team',
        TEAM_FINANCE => 'Finance Team',
        TEAM_CM => 'Customer Management Team'
    };

    /*4.0:
     * Functions added to prevent recursion when helper methods perform DML inside trigger execution.
     */
    private static Boolean isInRecursiveContext() {
        Boolean blocked = dmlDepth > 0;
        if (blocked) System.debug(LoggingLevel.WARN, '[SO_SLA][RECURSION_BLOCK] depth=' + dmlDepth);
        return blocked;
    }

    private static void beginDml(String ctx, Integer count) {
        dmlDepth++;
        System.debug(LoggingLevel.WARN, '[SO_SLA][DML_BEGIN] ctx=' + ctx + ' depth=' + dmlDepth + ' count=' + count);
    }
    private static void endDml(String ctx) {
        dmlDepth = Math.max(0, dmlDepth - 1);
        System.debug(LoggingLevel.WARN, '[SO_SLA][DML_END] ctx=' + ctx + ' depth=' + dmlDepth);
    }

    /*4.0:
     * Modified to cache Holiday records used for SLA date calculations instead of querying every time.
     */
    private static List<Holiday> getHolidays() {
        if (holidaysCache == null) {
            holidaysCache = [SELECT Id, ActivityDate FROM Holiday];
            holidayDatesCache = new Set<Date>();
            for (Holiday h : holidaysCache) if (h != null && h.ActivityDate != null) holidayDatesCache.add(h.ActivityDate);
            System.debug('[SO_SLA][getHolidays][QUERY] holidays=' + holidaysCache.size());
        } else {
            System.debug('[SO_SLA][getHolidays][CACHE] holidays=' + holidaysCache.size());
        }
        return holidaysCache;
    }

    /*4.0:
     * Function added for new requirement: To Sync Finance Associate with Sales Operations Associate when Sales Ops changes on update.
     */
    private static void syncFinanceToSalesOpsOnUpdate(
        List<SalesOrder__c> newList,
        Map<Id, SObject>    oldMap,
        List<SalesOrder__c> collector      
    ){
        if (newList == null || oldMap == null) return;

        for (SalesOrder__c soNew : newList){
            if (soNew == null || soNew.Id == null) continue;

            SalesOrder__c soOld = (SalesOrder__c)oldMap.get(soNew.Id);
            if (soOld == null) continue;

            Boolean salesOpsChanged =
                soNew.Sales_Operations_Associate__c != soOld.Sales_Operations_Associate__c;

            if (salesOpsChanged){
                collector.add(new SalesOrder__c(
                    Id                   = soNew.Id,
                    Finance_Associate__c = soNew.Sales_Operations_Associate__c
                ));
            }
        }
    }

    /*4.0:
     * Function added to Return the cached set of holiday dates for quick date checks.
     */
    private static Set<Date> getHolidayDates() {
        getHolidays();
        return holidayDatesCache == null ? new Set<Date>() : holidayDatesCache;
    }

    /*4.0:
     * Function added to load and cache business hours records specific to each team.
     */
    private static void warmBusinessHoursCache() {
        if (bhByNameCache != null) return;

        bhByNameCache = new Map<String, BusinessHours>();
        Set<String> names = new Set<String>();
        for (String v : TEAM_TO_BH_NAME.values()) if (!String.isBlank(v)) names.add(v);

        if (!names.isEmpty()) {
            List<BusinessHours> rows = [
                SELECT Id, Name, IsDefault
                FROM BusinessHours
                WHERE Name IN :names
            ];
            for (BusinessHours bh : rows) if (bh != null && !String.isBlank(bh.Name)) bhByNameCache.put(bh.Name, bh);
            System.debug('[SO_SLA][warmBusinessHoursCache][QUERY] names=' + names.size() + ' found=' + rows.size());
        } else {
            System.debug('[SO_SLA][warmBusinessHoursCache][SKIP] names=0');
        }
    }

    /*4.0:
     * Function added to Return the org default business hours in case no custom business hours are set up.
     */
    private static BusinessHours getDefaultBusinessHours() {
        if (defaultBhCache != null) {
            System.debug('[SO_SLA][getDefaultBusinessHours][CACHE] id=' + defaultBhCache.Id);
            return defaultBhCache;
        }
        List<BusinessHours> defaults = [
            SELECT Id, Name, IsDefault
            FROM BusinessHours
            WHERE IsDefault = true
            LIMIT 1
        ];
        defaultBhCache = defaults.isEmpty() ? null : defaults[0];
        System.debug('[SO_SLA][getDefaultBusinessHours][QUERY] found=' + (defaultBhCache != null));
        return defaultBhCache;
    }

    /*4.0:
     * Function modified to return business hours specific to a team and fall back on default when no such record exists.
     */
    private static BusinessHours getBusinessHours(String team) {
        if (bhByTeamCache == null) bhByTeamCache = new Map<String, BusinessHours>();
        if (String.isBlank(team)) return null;
        if (bhByTeamCache.containsKey(team)) {
            BusinessHours cached = bhByTeamCache.get(team);
            System.debug('[SO_SLA][getBusinessHours][CACHE] team=' + team + ' bhId=' + (cached != null ? cached.Id : null));
            return cached;
        }

        warmBusinessHoursCache();

        BusinessHours bh;
        String bhName = TEAM_TO_BH_NAME.get(team);

        if (!String.isBlank(bhName) && bhByNameCache != null && bhByNameCache.containsKey(bhName)) {
            bh = bhByNameCache.get(bhName);
            System.debug('[SO_SLA][getBusinessHours][HIT] team=' + team + ' name=' + bhName + ' bhId=' + bh.Id);
        } else {
            System.debug('[SO_SLA][getBusinessHours][MISS] team=' + team + ' name=' + bhName);
        }

        if (bh == null) {
            bh = getDefaultBusinessHours();
            System.debug('[SO_SLA][getBusinessHours][DEFAULT] team=' + team + ' bhId=' + (bh != null ? bh.Id : null));
        }

        bhByTeamCache.put(team, bh);
        return bh;
    }

    /*4.0:
     * Function modified to check whether a given datetime falls on a holiday date without requerying it.
     */
    private static Boolean isHoliday(Datetime dt, Set<Date> holidayDates) {
        if (dt == null || holidayDates == null || holidayDates.isEmpty()) return false;
        return holidayDates.contains(dt.date());
    }

    /*4.0:
     * Function modified to calculate the SLA due datetime based on business hours, holidays, and SLA duration stored from before.
     */
    private static Datetime calculateDueDate(Datetime startDate, Long slaMillis, BusinessHours bh, Set<Date> holidayDates) {
        if (startDate == null || bh == null || bh.Id == null || slaMillis == null) return null;

        Datetime start = startDate;
        while (isHoliday(start, holidayDates)) start = start.addDays(1);
        while (!BusinessHours.isWithin(bh.Id, start)) start = BusinessHours.nextStartDate(bh.Id, start);

        Datetime due = BusinessHours.add(bh.Id, start, slaMillis);

        Integer guard = 0;
        while (isHoliday(due, holidayDates) && guard < 10) {
            guard++;
            Datetime nextDay = DateTime.newInstance(due.date().addDays(1), Time.newInstance(0, 0, 0, 0));
            while (!BusinessHours.isWithin(bh.Id, nextDay)) nextDay = BusinessHours.nextStartDate(bh.Id, nextDay);
            due = BusinessHours.add(bh.Id, nextDay, 0);
        }
        return due;
    }

    /*4.0:
     * Function added to check whether a Sales Order status should be treated as closed for SLA handling.
     */
    private static Boolean isClosed(String statusVal) {
        return statusVal == 'Voided' || statusVal == 'Cancelled';
    }

    /*4.0:
     * Function added to check whether the Sales Journey Flow indicates reservation-based Sales Ops routing.
     */
    private static Boolean usesReservationForSalesOps(SalesOrder__c so) {
        return so != null &&
            !String.isBlank(so.Sales_Journey_Flow__c) &&
            so.Sales_Journey_Flow__c.toLowerCase().contains('reservation');
    }

    /*4.0:
     * Function added to determine the team responsible for associate(not SLA) assignment based on Sales Order status values.
     */
    private static String getAssignmentTeamFromSalesOrder(SalesOrder__c so) {
        if (so == null) return TEAM_UNKNOWN;

        if (
            (so.Sub_Status__c == SUB_PENDING_SALES && so.Is_Sales_Checklist_Completed__c == false) ||
            (so.Status__c == 'New' && String.isBlank(so.Sub_Status__c)) ||
            so.Sub_Status__c == 'Down Payment Collected' ||
            so.Sub_Status__c == 'ADM + Dari Fee Collected' ||
            so.Sub_Status__c == 'Reservation Form Generated' ||
            so.Sub_Status__c == 'Broker Form Generated' ||
            so.Sub_Status__c == SUB_PENDING_SALES_TEAM
        ) return TEAM_SALES;

        if (
            (usesReservationForSalesOps(so) && so.Sub_Status__c == SUB_PENDING_SALES_OPS) ||
            (!usesReservationForSalesOps(so) && (so.Sub_Status__c == SUB_SPA_IN_PROGRESS))
        ) {
            return TEAM_SALES_OPS;
        }

        if (so.Sub_Status__c == SUB_UNDER_FINANCE) return TEAM_FINANCE;
        if (so.Sub_Status__c == SUB_PENDING_CM) return TEAM_CM;

        return TEAM_UNKNOWN;
    }

    /*4.0:
     * Function added to determine the team category used for SLA creation and SLA ownership logic seperately from assignment logic.
     */
    private static String getSlaTeamFromSalesOrder(SalesOrder__c so) {
        if (so == null) return TEAM_UNKNOWN;

        if (
            (so.Sub_Status__c == SUB_PENDING_SALES && so.Is_Sales_Checklist_Completed__c == false) ||
            (so.Status__c == 'New' && String.isBlank(so.Sub_Status__c)) ||
            so.Sub_Status__c == 'Down Payment Collected' ||
            so.Sub_Status__c == 'ADM + Dari Fee Collected' ||
            so.Sub_Status__c == 'Reservation Form Generated' ||
            so.Sub_Status__c == 'Broker Form Generated' ||
            so.Sub_Status__c == SUB_PENDING_SALES_TEAM
        ) return TEAM_SALES;

        if (so.Sub_Status__c == SUB_PENDING_SALES_OPS) return TEAM_SALES_OPS;

        if (so.Sub_Status__c == SUB_UNDER_FINANCE) return TEAM_FINANCE;
        if (so.Sub_Status__c == SUB_PENDING_CM) return TEAM_CM;

        return TEAM_UNKNOWN;
    }

    /*4.0:
     * Function added to retuen the assigned user field value for the provided team on a Sales Order.
     */
    private static Id getAssociate(SalesOrder__c so, String team) {
        if (so == null || String.isBlank(team)) return null;
        if (team == TEAM_SALES) return so.SalesAssociate__c;
        if (team == TEAM_SALES_OPS) return so.Sales_Operations_Associate__c;
        if (team == TEAM_FINANCE) return so.Finance_Associate__c;
        if (team == TEAM_CM) return so.Customer_Management_Associate__c;
        return null;
    }

    /*4.0:
     * Function added to Load and cache active Master SLA records using category and subcategory as a key.
     */
    private static Map<String, Master_SLA__c> getMasterByKey() {
        if (masterByKeyCache == null) {
            masterByKeyCache = new Map<String, Master_SLA__c>();
            for (Master_SLA__c sla : [
                SELECT Id, Category__c, Sub_Category__c, SLA_Hrs__c, GroupName__c, Is_Available_For_Extension__c
                FROM Master_SLA__c
                WHERE IsActive__c = true
                  AND ObjectName__c = 'Sales Order'
            ]) {
                if (sla == null || String.isBlank(sla.Category__c)) continue;
                String key = sla.Category__c + '|' + (sla.Sub_Category__c != null ? sla.Sub_Category__c : '');
                masterByKeyCache.put(key, sla);
            }
            System.debug('[SO_SLA][getMasterByKey][QUERY] size=' + masterByKeyCache.size());
        } else {
            System.debug('[SO_SLA][getMasterByKey][CACHE] size=' + masterByKeyCache.size());
        }
        return masterByKeyCache;
    }

    /*4.0:
     * Function added to Load and cache Sales Associate to Sales Operations Associate matrix mappings.
     */
    private static void warmSoaaCache(Set<Id> salesAssociateIds) {
        if (soaaSalesToOpsCache == null) soaaSalesToOpsCache = new Map<Id, Id>();
        if (salesAssociateIds == null || salesAssociateIds.isEmpty()) return;
        Set<Id> missing = new Set<Id>();
        for (Id saId : salesAssociateIds) {
            if (saId != null && !soaaSalesToOpsCache.containsKey(saId)) missing.add(saId);
        }
        if (missing.isEmpty()) return;

        for (Sales_Operations_Associate_Assignment__c m : [
            SELECT Sales_Associate__c, Sales_Operations_Associate__c, Is_Active__c, Expiry_Date__c
            FROM Sales_Operations_Associate_Assignment__c
            WHERE Sales_Associate__c IN :missing
            AND Is_Active__c = true
            AND (Expiry_Date__c = null OR Expiry_Date__c >= :System.today())
            AND Sales_Operations_Associate__c != null
            ORDER BY LastModifiedDate DESC
        ]) {
            if (m.Sales_Associate__c != null && !soaaSalesToOpsCache.containsKey(m.Sales_Associate__c)) {
                soaaSalesToOpsCache.put(m.Sales_Associate__c, m.Sales_Operations_Associate__c);
            }
        }

        for (Id saId : missing) {
            if (!soaaSalesToOpsCache.containsKey(saId)) soaaSalesToOpsCache.put(saId, null);
        }
    }

    /*4.0:
     * Function added to assign the Sales Operations Associate from the active SOAA matrix mapping.
     */
    private static Id tryAssignSalesOpsFromSOAA(SalesOrder__c so) {
        if (so == null) return null;
        Id salesAssociateId = so.SalesAssociate__c != null ? so.SalesAssociate__c : so.OwnerId;
        if (salesAssociateId == null) return null;

        warmSoaaCache(new Set<Id>{ salesAssociateId });

        Id opsId = soaaSalesToOpsCache != null ? soaaSalesToOpsCache.get(salesAssociateId) : null;
        if (opsId != null) {
            so.Sales_Operations_Associate__c = opsId;
            System.debug('[SO_SLA][SOAA_ASSIGN] soId=' + so.Id + ' salesAssociate=' + salesAssociateId + ' ops=' + opsId);
        } else {
            System.debug('[SO_SLA][SOAA_ASSIGN][MISS] soId=' + so.Id + ' salesAssociate=' + salesAssociateId);
        }
        return opsId;
    }

    /*4.0:
     * Function added to Mirror Finance Associate from the Sales Operations Associate field when required.
     */
    private static void mirrorFinanceAssociate(SalesOrder__c so) {
        if (so == null) return;

        Id opsId = so.Sales_Operations_Associate__c;
        if (opsId == null) {
            if (so.Finance_Associate__c != null) {
                so.Finance_Associate__c = null;
                System.debug('[SO_SLA][MIRROR] cleared Finance because Sales-Ops is null');
            }
        } else if (so.Finance_Associate__c != opsId) {
            so.Finance_Associate__c = opsId;
            System.debug('[SO_SLA][MIRROR] synced Finance (' + opsId + ') from Sales-Ops');
        }
    }

    /*4.0:
     * Function added to Ensure the correct associate field is populated for the current team on the Sales Order.
     */
    private static Id ensureAssociateAssigned(
        SalesOrder__c so,
        String team
    ) {
        if (so == null || String.isBlank(team)) return null;

        if (team == TEAM_SALES) {
            if (so.SalesAssociate__c == null) {
                so.SalesAssociate__c = so.OwnerId;
                System.debug('[SO_SLA][ASSOC_SET] team=Sales soId=' + so.Id + ' salesAssociate=' + so.SalesAssociate__c + ' owner=' + so.OwnerId);
            } else {
                System.debug('[SO_SLA][ASSOC_KEEP] team=Sales soId=' + so.Id + ' salesAssociate=' + so.SalesAssociate__c);
            }
            return so.SalesAssociate__c;
        }

        if (team == TEAM_CM) {
            System.debug('[SO_SLA][ASSOC_SKIP] team=Customer Management soId=' + so.Id);
            return so.Customer_Management_Associate__c;
        }

        Id existing = getAssociate(so, team);
        if (existing != null) {
            System.debug('[SO_SLA][ASSOC_KEEP] team=' + team + ' soId=' + so.Id + ' associate=' + existing);
            return existing;
        }

        if (team == TEAM_SALES_OPS) {

            existing = so.Sales_Operations_Associate__c;
            if (existing != null) {
                mirrorFinanceAssociate(so);              
                return existing;
            }

            Id mapped = tryAssignSalesOpsFromSOAA(so);
            if (mapped != null) {
                mirrorFinanceAssociate(so);               
                return mapped;
            }

            mirrorFinanceAssociate(so);                   
            return null;
        }

        if (team == TEAM_FINANCE) {
            mirrorFinanceAssociate(so);                   
            return so.Finance_Associate__c;
        }

        return null;
    }

    /*4.0:
     * Function to Merge multiple Sales Order partial updates into a single update record per Sales Order.
     */
    private static Map<Id, SalesOrder__c> mergeSoUpdates(List<SalesOrder__c> updates) {
        Map<Id, SalesOrder__c> merged = new Map<Id, SalesOrder__c>();
        for (SalesOrder__c u : updates) {
            if (u == null || u.Id == null) continue;
            if (!merged.containsKey(u.Id)) {
                merged.put(u.Id, u);
            } else {
                SalesOrder__c e = merged.get(u.Id);
                if (u.SalesAssociate__c != null) e.SalesAssociate__c = u.SalesAssociate__c;
                if (u.Sales_Operations_Associate__c != null) e.Sales_Operations_Associate__c = u.Sales_Operations_Associate__c;
                if (u.Finance_Associate__c != null) e.Finance_Associate__c = u.Finance_Associate__c;
                if (u.Customer_Management_Associate__c != null) e.Customer_Management_Associate__c = u.Customer_Management_Associate__c;
                e.SLA_Hours__c = u.SLA_Hours__c;
                e.SLA_Start_Date_Time__c = u.SLA_Start_Date_Time__c;
                e.SLA_End_Date_Time__c = u.SLA_End_Date_Time__c;
            }
        }
        return merged;
    }

    /*4.0:
     * Function modified to use new functions for associate assignment
     */
    public static void assignToQueueMembers(List<SalesOrder__c> newList, Map<Id, SObject> oldMap, String triggerEvent) {
        System.debug('[SO_SLA][assignToQueueMembers][START] event=' + triggerEvent + ' size=' + (newList == null ? 0 : newList.size()));
        if (newList == null || newList.isEmpty()) return;
        if (isInRecursiveContext()) return;
        for (SalesOrder__c so : newList) {
            if (so == null) continue;
            if (isClosed(so.Status__c)) continue;

            String team = getAssignmentTeamFromSalesOrder(so);
            System.debug('[SO_SLA][assignToQueueMembers][TEAM] soId=' + so.Id + ' status=' + so.Status__c + ' subStatus=' + so.Sub_Status__c + ' team=' + team);

            if (team == TEAM_UNKNOWN) {
                System.debug('[SO_SLA][assignToQueueMembers][SKIP] soId=' + so.Id + ' team=Unknown');
                continue;
            }

            ensureAssociateAssigned(so, team);
        }

        System.debug('[SO_SLA][assignToQueueMembers][END]');
    }

    
    public static void createOrderCMSLA(List<SalesOrder__c> newList, Map<Id, SObject> oldMap) {
        if (newList == null || newList.isEmpty()) return;
        if (isInRecursiveContext()) return;

        List<SalesOrder__c> cmOrders = new List<SalesOrder__c>();
        for (SalesOrder__c so : newList) if (so != null && so.Sub_Status__c == SUB_PENDING_CM) cmOrders.add(so);
        if (!cmOrders.isEmpty()) createOrderSLAs(cmOrders, oldMap, false);
    }

    /*4.0:
     * Function modified to remove round robin and optimized.
     */
    public static void createOrderSLAs(List<SalesOrder__c> newList, Map<Id, SObject> oldMap, Boolean transferScenario) {
        System.debug('[SO_SLA][createOrderSLAs][START] size=' + (newList == null ? 0 : newList.size()) + ' transfer=' + transferScenario);
        if (newList == null || newList.isEmpty()) return;
        if (isInRecursiveContext()) return;

        Set<Id> orderIds = new Set<Id>();
        for (SalesOrder__c s : newList) if (s != null && s.Id != null) orderIds.add(s.Id);
        if (orderIds.isEmpty()) {
            System.debug('[SO_SLA][createOrderSLAs][EXIT] orderIds=0');
            return;
        }

        Map<Id, SalesOrder__c> soById = new Map<Id, SalesOrder__c>([
            SELECT Id, Status__c, Sub_Status__c, Is_Sales_Checklist_Completed__c, OwnerId,
                   SalesAssociate__c, Sales_Operations_Associate__c, Finance_Associate__c, Customer_Management_Associate__c,
                   UAE_Resident_Status__c, Sales_Journey_Flow__c
            FROM SalesOrder__c
            WHERE Id IN :orderIds AND Resale__c = FALSE
        ]);

        Boolean needsMaster = false;

        for (SalesOrder__c so : soById.values()) {
            if (so == null) continue;
            if (isClosed(so.Status__c)) continue;

            String team = getSlaTeamFromSalesOrder(so);
            if (team == TEAM_UNKNOWN) continue;

            needsMaster = true;
        }

        Map<String, Master_SLA__c> masterByKey = needsMaster ? getMasterByKey() : null;

        System.debug('[SO_SLA][createOrderSLAs][GATE] needsMaster=' + needsMaster +
                     ' masterKeyLoaded=' + (masterByKey != null) +
                     ' rrLoaded=false');

        Map<Id, List<CaseSLA__c>> activeSlaByOrder = new Map<Id, List<CaseSLA__c>>();
        if (needsMaster) {
            List<CaseSLA__c> actives = [
                SELECT Id, SalesOrder__c, Category__c, Status__c, SLA_User__c, IsReAssigned__c
                FROM CaseSLA__c
                WHERE SalesOrder__c IN :orderIds
                  AND Status__c IN ('OnTrack', 'Breached')
                ORDER BY CreatedDate DESC
            ];
            for (CaseSLA__c active : actives) {
                if (active == null || active.SalesOrder__c == null) continue;
                if (!activeSlaByOrder.containsKey(active.SalesOrder__c)) activeSlaByOrder.put(active.SalesOrder__c, new List<CaseSLA__c>());
                activeSlaByOrder.get(active.SalesOrder__c).add(active);
            }
            System.debug('[SO_SLA][createOrderSLAs][ACTIVE_SLA_QUERY] rows=' + actives.size() + ' orders=' + activeSlaByOrder.size());
        } else {
            System.debug('[SO_SLA][createOrderSLAs][ACTIVE_SLA_QUERY][SKIP] needsMaster=false');
        }

        List<CaseSLA__c> slasToInsert = new List<CaseSLA__c>();
        List<CaseSLA__c> slasToResolve = new List<CaseSLA__c>();
        List<SalesOrder__c> soUpdates = new List<SalesOrder__c>();
        Set<Id> closeSlaOrderIds = new Set<Id>();

        Set<Date> holidayDates;
        Boolean holidaysLoaded = false;

        for (Id soId : orderIds) {
            SalesOrder__c so = soById.get(soId);
            System.debug('[SO_SLA][createOrderSLAs][LOOP] soId=' + soId + ' exists=' + (so != null));
            if (so == null) continue;

            if (isClosed(so.Status__c)) {
                closeSlaOrderIds.add(so.Id);
                soUpdates.add(new SalesOrder__c(Id = so.Id, SLA_Hours__c = null, SLA_Start_Date_Time__c = null, SLA_End_Date_Time__c = null));
                System.debug('[SO_SLA][createOrderSLAs][CLOSED] soId=' + so.Id + ' status=' + so.Status__c);
                continue;
            }

            String team = getSlaTeamFromSalesOrder(so);
            System.debug('[SO_SLA][createOrderSLAs][TEAM] soId=' + so.Id + ' status=' + so.Status__c + ' subStatus=' + so.Sub_Status__c + ' team=' + team);

            if (team == TEAM_UNKNOWN || String.isBlank(team)) {
                closeSlaOrderIds.add(so.Id);
                soUpdates.add(new SalesOrder__c(Id = so.Id, SLA_Hours__c = null, SLA_Start_Date_Time__c = null, SLA_End_Date_Time__c = null));
                System.debug('[SO_SLA][createOrderSLAs][TEAM_UNKNOWN] soId=' + so.Id);
                continue;
            }

            Id associate = ensureAssociateAssigned(so, team);

            if (associate == null) {
                if (activeSlaByOrder.containsKey(so.Id)) {
                    for (CaseSLA__c existing : activeSlaByOrder.get(so.Id)) {
                        if (existing == null) continue;
                        existing.Status__c = 'Resolved';
                        existing.CompletionDate__c = System.now();
                        existing.EndTime__c = existing.CompletionDate__c;
                        slasToResolve.add(existing);
                    }
                }
                soUpdates.add(new SalesOrder__c(Id = so.Id, SLA_Hours__c = null, SLA_Start_Date_Time__c = null, SLA_End_Date_Time__c = null));
                System.debug(LoggingLevel.WARN, '[SO_SLA][createOrderSLAs][NO_ASSOC] soId=' + so.Id + ' team=' + team);
                continue;
            }

            Master_SLA__c matched = masterByKey != null ? masterByKey.get(team + '|') : null;
            if (team == TEAM_SALES && masterByKey != null) {
                matched = (so.UAE_Resident_Status__c == 'Non-Resident')
                    ? masterByKey.get('Sales|Non-Resident Sales')
                    : masterByKey.get('Sales|Resident Sales');
            }

            System.debug('[SO_SLA][createOrderSLAs][MASTER] soId=' + so.Id + ' team=' + team + ' masterId=' + (matched != null ? matched.Id : null) + ' associate=' + associate);

            if (matched == null) {
                if (activeSlaByOrder.containsKey(so.Id)) {
                    for (CaseSLA__c existing : activeSlaByOrder.get(so.Id)) {
                        if (existing == null) continue;
                        existing.Status__c = 'Resolved';
                        existing.CompletionDate__c = System.now();
                        existing.EndTime__c = existing.CompletionDate__c;
                        slasToResolve.add(existing);
                    }
                }

                SalesOrder__c assocOnly = new SalesOrder__c(Id = so.Id, SLA_Hours__c = null, SLA_Start_Date_Time__c = null, SLA_End_Date_Time__c = null);
                if (team == TEAM_SALES) assocOnly.SalesAssociate__c = so.SalesAssociate__c;
                else if (team == TEAM_SALES_OPS) assocOnly.Sales_Operations_Associate__c = so.Sales_Operations_Associate__c;
                else if (team == TEAM_FINANCE) assocOnly.Finance_Associate__c = so.Finance_Associate__c;
                else if (team == TEAM_CM) assocOnly.Customer_Management_Associate__c = so.Customer_Management_Associate__c;

                soUpdates.add(assocOnly);

                System.debug(LoggingLevel.WARN, '[SO_SLA][createOrderSLAs][NO_MASTER] soId=' + so.Id + ' team=' + team + ' persistedAssociate=' + associate);
                continue;
            }

            CaseSLA__c activeSameTeam;
            if (activeSlaByOrder.containsKey(so.Id)) {
                for (CaseSLA__c existing : activeSlaByOrder.get(so.Id)) {
                    if (existing != null && existing.Category__c == team && (existing.Status__c == 'OnTrack' || existing.Status__c == 'Breached')) {
                        activeSameTeam = existing;
                        break;
                    }
                }
            }

            if (activeSameTeam != null && activeSameTeam.SLA_User__c == associate) {
                System.debug('[SO_SLA][createOrderSLAs][SKIP] soId=' + so.Id + ' team=' + team + ' activeSla=' + activeSameTeam.Id + ' user=' + associate);
                continue;
            }

            if (activeSameTeam != null && activeSameTeam.SLA_User__c != associate) {
                activeSameTeam.Status__c = 'Resolved';
                activeSameTeam.CompletionDate__c = System.now();
                activeSameTeam.EndTime__c = activeSameTeam.CompletionDate__c;
                activeSameTeam.IsReAssigned__c = true;
                slasToResolve.add(activeSameTeam);
                System.debug('[SO_SLA][createOrderSLAs][REASSIGN] soId=' + so.Id + ' team=' + team + ' oldSla=' + activeSameTeam.Id + ' oldUser=' + activeSameTeam.SLA_User__c + ' newUser=' + associate);
            }

            BusinessHours bh = getBusinessHours(team);
            if (bh == null || bh.Id == null) {
                System.debug(LoggingLevel.WARN, '[SO_SLA][createOrderSLAs][NO_BH] soId=' + so.Id + ' team=' + team);
                continue;
            }

            if (!holidaysLoaded) {
                holidayDates = getHolidayDates();
                holidaysLoaded = true;
                System.debug('[SO_SLA][createOrderSLAs][HOLIDAYS_LOADED] size=' + (holidayDates != null ? holidayDates.size() : 0));
            }

            Datetime startTime = System.now();
            while (isHoliday(startTime, holidayDates)) startTime = startTime.addDays(1);
            while (!BusinessHours.isWithin(bh.Id, startTime)) startTime = BusinessHours.nextStartDate(bh.Id, startTime);

            Decimal hours = matched.SLA_Hrs__c != null ? matched.SLA_Hrs__c : 0;
            Long millis = Math.round(hours * 3600000);
            Datetime due = calculateDueDate(startTime, millis, bh, holidayDates);

            CaseSLA__c sla = new CaseSLA__c();
            sla.SalesOrder__c = so.Id;
            sla.Master_SLA__c = matched.Id;
            sla.Category__c = matched.Category__c;
            sla.Status__c = 'OnTrack';
            sla.StartTime__c = startTime;
            sla.DueTime__c = due;
            sla.Is_Extension_Allowed__c = matched.Is_Available_For_Extension__c;
            sla.SLA_User__c = associate;

            slasToInsert.add(sla);

            SalesOrder__c soUp = new SalesOrder__c(
                Id = so.Id,
                SLA_Hours__c = hours,
                SLA_Start_Date_Time__c = startTime,
                SLA_End_Date_Time__c = due
            );

            if (team == TEAM_SALES && so.SalesAssociate__c != null) soUp.SalesAssociate__c = so.SalesAssociate__c;
            if (team == TEAM_SALES_OPS && so.Sales_Operations_Associate__c != null) soUp.Sales_Operations_Associate__c = so.Sales_Operations_Associate__c;
            if (team == TEAM_FINANCE && so.Finance_Associate__c != null) soUp.Finance_Associate__c = so.Finance_Associate__c;

            soUpdates.add(soUp);

            System.debug('[SO_SLA][createOrderSLAs][BUILD] soId=' + so.Id + ' team=' + team + ' slaUser=' + associate + ' start=' + startTime + ' due=' + due);
        }

        if (!closeSlaOrderIds.isEmpty()) closeSLAs(closeSlaOrderIds);

        if (!slasToResolve.isEmpty()) {
            System.debug('[SO_SLA][createOrderSLAs][DML] resolveSLAs=' + slasToResolve.size());
            beginDml('createOrderSLAs_resolve', slasToResolve.size());
            update slasToResolve;
            endDml('createOrderSLAs_resolve');
        } else {
            System.debug('[SO_SLA][createOrderSLAs][DML] resolveSLAs=0');
        }

        if (!slasToInsert.isEmpty()) {
            System.debug('[SO_SLA][createOrderSLAs][DML] insertSLAs=' + slasToInsert.size());
            beginDml('createOrderSLAs_insert', slasToInsert.size());
            insert slasToInsert;
            endDml('createOrderSLAs_insert');
        } else {
            System.debug('[SO_SLA][createOrderSLAs][DML] insertSLAs=0');
        }

        if (!soUpdates.isEmpty()) {
            Map<Id, SalesOrder__c> merged = mergeSoUpdates(soUpdates);
            if (!merged.isEmpty()) {
                System.debug('[SO_SLA][createOrderSLAs][DML] updateSO=' + merged.size());
                beginDml('createOrderSLAs_updateSO', merged.size());
                update merged.values();
                endDml('createOrderSLAs_updateSO');
            } else {
                System.debug('[SO_SLA][createOrderSLAs][DML] updateSO=0 mergedEmpty=true');
            }
        } else {
            System.debug('[SO_SLA][createOrderSLAs][DML] updateSO=0 soUpdatesEmpty=true');
        }

        System.debug('[SO_SLA][createOrderSLAs][END]');
    }

    /*4.0:
     * Modified to use new sla substatus - team relationship .
     */
    public static void createOrderSLAWhenOwnerUpdated(List<SalesOrder__c> newList, Map<Id, SObject> oldMap) {
        System.debug('[SO_SLA][createOrderSLAWhenOwnerUpdated][START] size=' + (newList == null ? 0 : newList.size()));
        if (newList == null || newList.isEmpty() || oldMap == null || oldMap.isEmpty()) return;
        if (isInRecursiveContext()) return;

        Set<Id> candidateIds = new Set<Id>();
        Set<Id> checklistFlipCandidateIds = new Set<Id>();

        for (SalesOrder__c soNew : newList) {
            if (soNew == null || soNew.Id == null) continue;

            SalesOrder__c soOld = (SalesOrder__c) oldMap.get(soNew.Id);
            if (soOld == null) continue;

            Boolean assocChanged =
                soNew.SalesAssociate__c != soOld.SalesAssociate__c ||
                soNew.Sales_Operations_Associate__c != soOld.Sales_Operations_Associate__c ||
                soNew.Finance_Associate__c != soOld.Finance_Associate__c ||
                soNew.Customer_Management_Associate__c != soOld.Customer_Management_Associate__c;

            Boolean checklistFlipped =
                (soOld.Is_Sales_Checklist_Completed__c == false) &&
                (soNew.Is_Sales_Checklist_Completed__c == true) &&
                (soNew.Sub_Status__c == SUB_PENDING_SALES);

            if (assocChanged || checklistFlipped) candidateIds.add(soNew.Id);
            if (checklistFlipped) checklistFlipCandidateIds.add(soNew.Id);
        }

        System.debug('[SO_SLA][createOrderSLAWhenOwnerUpdated][GATE] candidates=' + candidateIds.size() + ' checklistFlip=' + checklistFlipCandidateIds.size());

        if (candidateIds.isEmpty()) {
            System.debug('[SO_SLA][createOrderSLAWhenOwnerUpdated][END]');
            return;
        }

        Map<Id, SalesOrder__c> freshById = new Map<Id, SalesOrder__c>([
            SELECT Id,
                SalesAssociate__c, Sales_Operations_Associate__c, Finance_Associate__c, Customer_Management_Associate__c,
                Is_Sales_Checklist_Completed__c, Sub_Status__c, Status__c, Sales_Journey_Flow__c
            FROM SalesOrder__c 
            WHERE Id IN :candidateIds AND Resale__c = FALSE
        ]);

        List<CaseSLA__c> activeSlas = [
            SELECT Id, SalesOrder__c, Category__c, Status__c, SLA_User__c,
                CompletionDate__c, EndTime__c, IsReAssigned__c
            FROM CaseSLA__c
            WHERE SalesOrder__c IN :candidateIds
              AND Status__c IN ('OnTrack', 'Breached')
        ];

        Map<Id, List<CaseSLA__c>> activeSlasByOrder = new Map<Id, List<CaseSLA__c>>();
        for (CaseSLA__c sla : activeSlas) {
            if (sla == null || sla.SalesOrder__c == null) continue;
            if (!activeSlasByOrder.containsKey(sla.SalesOrder__c)) {
                activeSlasByOrder.put(sla.SalesOrder__c, new List<CaseSLA__c>());
            }
            activeSlasByOrder.get(sla.SalesOrder__c).add(sla);
        }

        List<CaseSLA__c> slaToResolve = new List<CaseSLA__c>();
        List<SalesOrder__c> soToClearSlaFields = new List<SalesOrder__c>();
        Map<Id, SalesOrder__c> toCreateNewSla = new Map<Id, SalesOrder__c>();
        List<SalesOrder__c> financeMirrorUpdates = new List<SalesOrder__c>();

        syncFinanceToSalesOpsOnUpdate(newList, oldMap, financeMirrorUpdates);

        for (CaseSLA__c sla : activeSlas) {
            if (sla == null || sla.SalesOrder__c == null) continue;

            SalesOrder__c soFresh = freshById.get(sla.SalesOrder__c);
            if (soFresh == null) continue;

            if (checklistFlipCandidateIds.contains(sla.SalesOrder__c) && sla.Category__c == TEAM_SALES) {
                System.debug('[SO_SLA][createOrderSLAWhenOwnerUpdated][RESOLVE_ON_CHECKLIST] soId=' + sla.SalesOrder__c + ' slaId=' + sla.Id);

                sla.Status__c = 'Resolved';
                sla.CompletionDate__c = System.now();
                sla.EndTime__c = sla.CompletionDate__c;
                sla.IsReAssigned__c = false;
                slaToResolve.add(sla);

                soToClearSlaFields.add(new SalesOrder__c(
                    Id = sla.SalesOrder__c,
                    SLA_Start_Date_Time__c = null,
                    SLA_End_Date_Time__c = null,
                    SLA_Hours__c = null
                ));
                continue;
            }

            Id newUser = getAssociate(soFresh, sla.Category__c);

            System.debug('[SO_SLA][createOrderSLAWhenOwnerUpdated][COMPARE] soId=' + soFresh.Id +
                        ' team=' + sla.Category__c +
                        ' oldSlaUser=' + sla.SLA_User__c +
                        ' newAssociate=' + newUser);

            if (newUser == null) {
                sla.Status__c = 'Resolved';
                sla.CompletionDate__c = System.now();
                sla.EndTime__c = sla.CompletionDate__c;
                slaToResolve.add(sla);

                soToClearSlaFields.add(new SalesOrder__c(
                    Id = soFresh.Id,
                    SLA_Start_Date_Time__c = null,
                    SLA_End_Date_Time__c = null,
                    SLA_Hours__c = null
                ));
                continue;
            }

            if (sla.SLA_User__c != newUser) {
                sla.Status__c = 'Resolved';
                sla.CompletionDate__c = System.now();
                sla.EndTime__c = sla.CompletionDate__c;
                sla.IsReAssigned__c = true;
                slaToResolve.add(sla);

                toCreateNewSla.put(soFresh.Id, soFresh);
            }
        }

        for (Id soId : candidateIds) {
            SalesOrder__c soFresh = freshById.get(soId);
            if (soFresh == null) continue;

            String team = getSlaTeamFromSalesOrder(soFresh);
            if (team == TEAM_UNKNOWN || String.isBlank(team)) continue;

            Id associate = getAssociate(soFresh, team);
            if (associate == null) continue;

            Boolean hasActiveForSameTeam = false;
            if (activeSlasByOrder.containsKey(soId)) {
                for (CaseSLA__c existing : activeSlasByOrder.get(soId)) {
                    if (existing != null &&
                        existing.Category__c == team &&
                        (existing.Status__c == 'OnTrack' || existing.Status__c == 'Breached')) {
                        hasActiveForSameTeam = true;
                        break;
                    }
                }
            }

            if (!hasActiveForSameTeam) {
                toCreateNewSla.put(soFresh.Id, soFresh);
                System.debug('[SO_SLA][createOrderSLAWhenOwnerUpdated][FORCE_CREATE] soId=' + soId + ' team=' + team + ' associate=' + associate);
            }
        }

        if (!soToClearSlaFields.isEmpty()) {
            System.debug('[SO_SLA][createOrderSLAWhenOwnerUpdated][DML] clearSOFields=' + soToClearSlaFields.size());
            beginDml('createOrderSLAWhenOwnerUpdated_clearSO', soToClearSlaFields.size());
            update soToClearSlaFields;
            endDml('createOrderSLAWhenOwnerUpdated_clearSO');
        } else {
            System.debug('[SO_SLA][createOrderSLAWhenOwnerUpdated][DML] clearSOFields=0');
        }

        if (!slaToResolve.isEmpty()) {
            System.debug('[SO_SLA][createOrderSLAWhenOwnerUpdated][DML] resolveSLAs=' + slaToResolve.size());
            beginDml('createOrderSLAWhenOwnerUpdated_resolve', slaToResolve.size());
            update slaToResolve;
            endDml('createOrderSLAWhenOwnerUpdated_resolve');
        } else {
            System.debug('[SO_SLA][createOrderSLAWhenOwnerUpdated][DML] resolveSLAs=0');
        }

        if (!financeMirrorUpdates.isEmpty()) {
            System.debug('[SO_SLA][createOrderSLAWhenOwnerUpdated][DML] mirrorFin='
                        + financeMirrorUpdates.size());
            beginDml('createOrderSLAWhenOwnerUpdated_mirrorFin',
                    financeMirrorUpdates.size());
            update financeMirrorUpdates;
            endDml('createOrderSLAWhenOwnerUpdated_mirrorFin');
        } else {
            System.debug('[SO_SLA][createOrderSLAWhenOwnerUpdated][DML] mirrorFin=0');
        }

        if (!toCreateNewSla.isEmpty()) {
            System.debug('[SO_SLA][createOrderSLAWhenOwnerUpdated][CREATE] newSLAs=' + toCreateNewSla.size());
            createOrderSLAs(toCreateNewSla.values(), oldMap, true);
        } else {
            System.debug('[SO_SLA][createOrderSLAWhenOwnerUpdated][CREATE] newSLAs=0');
        }

        System.debug('[SO_SLA][createOrderSLAWhenOwnerUpdated][END]');
    }

    /*4.0:
     * Function optimized with more specific queries amd maps
     */
    public static void orderClosedCloseSLA(List<SalesOrder__c> newList, Map<Id, SObject> oldMap) {
        System.debug('[SO_SLA][orderClosedCloseSLA][START] size=' + (newList == null ? 0 : newList.size()));
        if (newList == null || newList.isEmpty() || oldMap == null || oldMap.isEmpty()) return;
        if (isInRecursiveContext()) return;

        Set<Id> closedIds = new Set<Id>();
        for (SalesOrder__c so : newList) {
            if (so == null || so.Id == null) continue;
            SalesOrder__c oldRec = (SalesOrder__c) oldMap.get(so.Id);
            if (oldRec == null) continue;
            if (isClosed(so.Status__c) && !isClosed(oldRec.Status__c)) closedIds.add(so.Id);
        }

        System.debug('[SO_SLA][orderClosedCloseSLA][GATE] closedIds=' + closedIds.size());
        if (closedIds.isEmpty()) return;

        List<CaseSLA__c> slas = [
            SELECT Id, CaseId__c, Status__c, EndTime__c, CompletionDate__c,SalesOrder__c
            FROM CaseSLA__c
            WHERE SalesOrder__c IN :closedIds
              AND Status__c != 'Resolved'
        ];

        List<SalesOrder__c> soUpdates = new List<SalesOrder__c>();
        for (CaseSLA__c sla : slas) {
            if (sla == null) continue;
            sla.Status__c = 'Resolved';
            sla.CompletionDate__c = System.now();
            sla.EndTime__c = sla.CompletionDate__c;
            soUpdates.add(new SalesOrder__c(Id = sla.SalesOrder__c, SLA_End_Date_Time__c = sla.CompletionDate__c));
        }

        if (!slas.isEmpty()) {
            beginDml('orderClosedCloseSLA_updateSLAs', slas.size());
            update slas;
            endDml('orderClosedCloseSLA_updateSLAs');
        } else {
            System.debug('[SO_SLA][orderClosedCloseSLA][DML] slas=0');
        }

        if (!soUpdates.isEmpty()) {
            beginDml('orderClosedCloseSLA_updateSO', soUpdates.size());
            try{
            update soUpdates;
            }catch(Exception e){}
            endDml('orderClosedCloseSLA_updateSO');
        } else {
            System.debug('[SO_SLA][orderClosedCloseSLA][DML] soUpdates=0');
        }

        System.debug('[SO_SLA][orderClosedCloseSLA][END]');
    }


    private static void closeSLAs(Set<Id> orderIds) {
        if (orderIds == null || orderIds.isEmpty()) return;

        List<CaseSLA__c> slas = [
            SELECT Id, Status__c, EndTime__c, CompletionDate__c
            FROM CaseSLA__c
            WHERE SalesOrder__c IN :orderIds
              AND Status__c != 'Resolved'
        ];

        for (CaseSLA__c sla : slas) {
            if (sla == null) continue;
            sla.Status__c = 'Resolved';
            sla.CompletionDate__c = System.now();
            sla.EndTime__c = sla.CompletionDate__c;
        }

        if (!slas.isEmpty()) {
            beginDml('closeSLAs', slas.size());
            update slas;
            endDml('closeSLAs');
        }
    }

    /*4.0:
     * Function modified to use new sla team logic
     */
    public static void closeSLAOnTeamChange(List<SalesOrder__c> newList, Map<Id, SObject> oldMap) {
        System.debug('[SO_SLA][closeSLAOnTeamChange][START] size=' + (newList == null ? 0 : newList.size()));
        if (newList == null || newList.isEmpty() || oldMap == null || oldMap.isEmpty()) return;
        if (isInRecursiveContext()) return;

        Map<Id, String> newTeamById = new Map<Id, String>();
        Set<Id> changedIds = new Set<Id>();

        for (SalesOrder__c so : newList) {
            if (so == null || so.Id == null) continue;
            SalesOrder__c oldSo = (SalesOrder__c) oldMap.get(so.Id);
            if (oldSo == null) continue;
            if (so.Sub_Status__c == oldSo.Sub_Status__c) continue;

            String oldTeam = getSlaTeamFromSalesOrder(oldSo);
            String newTeam = getSlaTeamFromSalesOrder(so);

            if (oldTeam != newTeam) {
                changedIds.add(so.Id);
                newTeamById.put(so.Id, newTeam);
                System.debug('[SO_SLA][closeSLAOnTeamChange][CHANGE] soId=' + so.Id + ' oldTeam=' + oldTeam + ' newTeam=' + newTeam);
            }
        }

        System.debug('[SO_SLA][closeSLAOnTeamChange][GATE] changedIds=' + changedIds.size());
        if (changedIds.isEmpty()) return;

        Map<Id, List<CaseSLA__c>> activeByOrder = new Map<Id, List<CaseSLA__c>>();
        List<CaseSLA__c> rows = [
            SELECT Id, Category__c, Status__c, EndTime__c, CompletionDate__c, SalesOrder__c
            FROM CaseSLA__c
            WHERE SalesOrder__c IN :changedIds
              AND Status__c IN ('OnTrack', 'Breached')
            ORDER BY CreatedDate DESC
        ];
        for (CaseSLA__c sla : rows) {
            if (sla == null || sla.SalesOrder__c == null) continue;
            if (!activeByOrder.containsKey(sla.SalesOrder__c)) activeByOrder.put(sla.SalesOrder__c, new List<CaseSLA__c>());
            activeByOrder.get(sla.SalesOrder__c).add(sla);
        }
        System.debug('[SO_SLA][closeSLAOnTeamChange][ACTIVE_QUERY] rows=' + rows.size() + ' orders=' + activeByOrder.size());

        List<CaseSLA__c> toResolve = new List<CaseSLA__c>();
        List<SalesOrder__c> toCreate = new List<SalesOrder__c>();

        for (Id soId : changedIds) {
            String newTeam = newTeamById.get(soId);
            List<CaseSLA__c> active = activeByOrder.containsKey(soId) ? activeByOrder.get(soId) : new List<CaseSLA__c>();

            Boolean hasActiveSameTeam = false;
            for (CaseSLA__c sla : active) {
                if (sla == null) continue;
                if (sla.Category__c == newTeam) {
                    hasActiveSameTeam = true;
                } else {
                    sla.Status__c = 'Resolved';
                    sla.EndTime__c = System.now();
                    sla.CompletionDate__c = sla.EndTime__c;
                    toResolve.add(sla);
                }
            }

            if (!hasActiveSameTeam) toCreate.add(new SalesOrder__c(Id = soId));
        }

        if (!toResolve.isEmpty()) {
            beginDml('closeSLAOnTeamChange_resolve', toResolve.size());
            update toResolve;
            endDml('closeSLAOnTeamChange_resolve');
        } else {
            System.debug('[SO_SLA][closeSLAOnTeamChange][DML] toResolve=0');
        }

        if (!toCreate.isEmpty()) {
            System.debug('[SO_SLA][closeSLAOnTeamChange][CREATE] toCreate=' + toCreate.size());
            createOrderSLAs(toCreate, oldMap, true);
        } else {
            System.debug('[SO_SLA][closeSLAOnTeamChange][CREATE] toCreate=0');
        }

        System.debug('[SO_SLA][closeSLAOnTeamChange][END]');
    }

    /*4.0:
     * Function modified to use new sla sub status to team logic
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getSLAConfig(Id salesOrderId) {
        Map<String, Object> result = new Map<String, Object>();
        if (salesOrderId == null) {
            result.put('Error', 'No recordId provided');
            return result;
        }

        SalesOrder__c so = [
            SELECT Id, Name, SLA_Start_Date_Time__c, SLA_End_Date_Time__c, Sub_Status__c, Is_Sales_Checklist_Completed__c, Customer_Management_Associate__c, Status__c, Sales_Journey_Flow__c
            FROM SalesOrder__c 
            WHERE Id = :salesOrderId AND Resale__c = FALSE
            LIMIT 1
        ];

        String team = getSlaTeamFromSalesOrder(so);
        BusinessHours bh = getBusinessHours(team);
        List<Holiday> holidays = getHolidays();

        result.put('SLA_Start', so.SLA_Start_Date_Time__c);
        result.put('SLA_End', so.SLA_End_Date_Time__c);
        result.put('SubStatus', so.Sub_Status__c);
        result.put('Team', team);

        result.put('BusinessHours', new Map<String, Object>{
            'Id' => bh != null ? bh.Id : null,
            'IsDefault' => bh != null ? bh.IsDefault : null
        });

        List<Date> holidayDates = new List<Date>();
        for (Holiday h : holidays) if (h != null) holidayDates.add(h.ActivityDate);
        result.put('Holidays', holidayDates);

        return result;
    }

    /*4.0:
     * Function modified to use new sla team logic
     */
    @AuraEnabled(cacheable=false)
    public static Long getBusinessTimeDiff(Id salesOrderId) {
        if (salesOrderId == null) return null;

        SalesOrder__c so = [
            SELECT Id, SLA_Start_Date_Time__c, SLA_End_Date_Time__c, Sub_Status__c, Is_Sales_Checklist_Completed__c, Customer_Management_Associate__c, Status__c, Sales_Journey_Flow__c
            FROM SalesOrder__c
            WHERE Id = :salesOrderId
            AND Resale__c = FALSE
            LIMIT 1
        ];

        String team = getSlaTeamFromSalesOrder(so);
        BusinessHours bh = getBusinessHours(team);
        if (bh == null || bh.Id == null || so.SLA_Start_Date_Time__c == null || so.SLA_End_Date_Time__c == null) return null;

        Datetime now = System.now();
        Datetime endt = so.SLA_End_Date_Time__c;

        Long diff = (now > endt) ? -BusinessHours.diff(bh.Id, endt, now) : BusinessHours.diff(bh.Id, now, endt);

        if (!BusinessHours.isWithin(bh.Id, now)) {
            Datetime nextStart = BusinessHours.nextStartDate(bh.Id, now);
            diff += (nextStart.getTime() - now.getTime());
        }

        return diff;
    }
}