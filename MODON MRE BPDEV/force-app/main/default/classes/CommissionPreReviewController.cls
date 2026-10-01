/**********************************************************************************************************************
* Name               : CommissionPreReviewController                                                        
* Description        : This class is used to handle the External Commission Line Review by Broker Team
* Created By         : ActiveMinds                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           dinesh.selvam@modon.com             30/03/2026     Initial Draft
**********************************************************************************************************************/
public with sharing class CommissionPreReviewController {
    
    public class OptionDTO {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        
        public OptionDTO(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }
    
    public class CommissionRowDTO {
        @AuraEnabled public Id recordId;
        @AuraEnabled public String commissionLineName;
        @AuraEnabled public String projectName;
        @AuraEnabled public String unitName;
        @AuraEnabled public Date unitSoldDate;
        @AuraEnabled public Date launchDate;
        @AuraEnabled public String leadSource;
        @AuraEnabled public Decimal totalSalesValue;
        @AuraEnabled public String salesType;
        @AuraEnabled public String saleCategory;
        @AuraEnabled public Decimal commissionPercent;
        @AuraEnabled public Decimal commissionAmount;
        @AuraEnabled public String ownerName;
        @AuraEnabled public Id ownerId;
    }
    
    public class ResponseDTO {
        @AuraEnabled public List<CommissionRowDTO> rows;
        @AuraEnabled public Integer totalCount;
        @AuraEnabled public List<OptionDTO> leadSourceOptions;
        @AuraEnabled public List<OptionDTO> salesTypeOptions;
        @AuraEnabled public List<OptionDTO> saleCategoryOptions;
        @AuraEnabled public List<OptionDTO> projectOptions;
        @AuraEnabled public List<OptionDTO> ownerOptions;
    }
    
    @AuraEnabled
    public static ResponseDTO getCommissionRows(
        Integer pageSize,
    Integer pageNumber,
    String dateFilterType,
    Integer monthValue,
    Integer yearValue,
    Date fromDate,
    Date toDate,
    String projectName,
    String unitName
    ) {
        pageSize = (pageSize == null || pageSize <= 0) ? 10 : pageSize;
        pageNumber = (pageNumber == null || pageNumber <= 0) ? 1 : pageNumber;
        
        Integer offsetVal = (pageNumber - 1) * pageSize;
        
        Date startDate;
        Date endDate;
        
        Integer effectiveYear = (yearValue == null || yearValue <= 0) ? Date.today().year() : yearValue;
        Integer effectiveMonth = (monthValue == null || monthValue < 1 || monthValue > 12) ? Date.today().month() : monthValue;
        
        if (String.isBlank(dateFilterType)) {
            startDate = null;
            endDate = null;
        } else if (dateFilterType == 'year') {
            startDate = Date.newInstance(effectiveYear, 1, 1);
            endDate = Date.newInstance(effectiveYear, 12, 31);
        } else if (dateFilterType == 'custom') {
            startDate = fromDate;
            endDate = toDate;
        } else {
            startDate = Date.newInstance(effectiveYear, effectiveMonth, 1);
            endDate = startDate.addMonths(1).addDays(-1);
        }
        
        String unitLike = String.isBlank(unitName) ? null : '%' + unitName.trim() + '%';
        
        List<String> whereClauses = new List<String>();
        
        if (startDate != null) {
            whereClauses.add('Booking_Date__c >= :startDate');
        }
        if (endDate != null) {
            whereClauses.add('Booking_Date__c <= :endDate');
        }
        if (String.isNotBlank(projectName)) {
            whereClauses.add('Project__c = :projectName');
        }
        if (String.isNotBlank(unitLike)) {
            whereClauses.add('Unit__c LIKE :unitLike');
        }
        whereClauses.add('ShowReviewCommissionLine__c = true');
        String whereSoql = whereClauses.isEmpty() ? '' : ' WHERE ' + String.join(whereClauses, ' AND ');
        
        Integer totalCount = (Integer) Database.countQuery(
        'SELECT COUNT() FROM Commission_Line__c' + whereSoql
        );
        
        List<Commission_Line__c> recs = Database.query(
            'SELECT Id, ' +
            'Name, ' +
            'Project__c, ' +
            'Unit__c, ' +
            'Booking_Date__c, ' +
            'Unit_Launch_Date__c, ' +
            'Lead_Source__c, ' +
            'Total_Unit_Price__c, ' +
            'Category_Of_Sale__c, ' +
            'Commission_Type__c, ' +
            'Commission_Percent__c, ' +
            'Commission_Amount__c, ' +
            'Sales_Order__c, ' +
            'Sales_Order__r.OwnerId, ' +
            'Sales_Order__r.Owner.Name ' +
            'FROM Commission_Line__c' +
            whereSoql +
            ' ORDER BY Booking_Date__c DESC, CreatedDate DESC ' +
            'LIMIT :pageSize OFFSET :offsetVal'
            );
        
        ResponseDTO res = new ResponseDTO();
        res.totalCount = totalCount;
        res.rows = new List<CommissionRowDTO>();
        
        for (Commission_Line__c r : recs) {
            CommissionRowDTO dto = new CommissionRowDTO();
            dto.recordId = r.Id;
            dto.commissionLineName = r.Name;
            dto.projectName = r.Project__c;
            dto.unitName = r.Unit__c;
            dto.unitSoldDate = r.Booking_Date__c;
            dto.launchDate = r.Unit_Launch_Date__c;
            dto.leadSource = String.isBlank(r.Lead_Source__c) ? '' : r.Lead_Source__c.trim();
            dto.totalSalesValue = r.Total_Unit_Price__c;
            dto.salesType = r.Commission_Type__c;
            dto.saleCategory = String.isBlank(r.Category_Of_Sale__c) ? '' : r.Category_Of_Sale__c.trim();
            dto.commissionPercent = r.Commission_Percent__c;
            dto.commissionAmount = r.Commission_Amount__c;
            dto.ownerId = (r.Sales_Order__r != null) ? r.Sales_Order__r.OwnerId : null;
            dto.ownerName = (r.Sales_Order__r != null && r.Sales_Order__r.Owner != null)
                ? r.Sales_Order__r.Owner.Name
                : null;
            
            res.rows.add(dto);
        }
        
        res.leadSourceOptions = getPicklistOptions(Lead.LeadSource);
        res.salesTypeOptions = getPicklistOptions(Commission_Line__c.Commission_Type__c);
        res.saleCategoryOptions = getCategoryOptions();
        res.projectOptions = getDistinctTextFieldOptions('Project__c');
        res.ownerOptions = getActiveUserOptions();
        
        return res;
    }

    private static List<OptionDTO> getActiveUserOptions() {
        List<OptionDTO> opts = new List<OptionDTO>();

        for (User u : [
            SELECT Id, Name
            FROM User
            WHERE IsActive = true
            AND IsPortalEnabled = false
            ORDER BY Name
        ]) {
            opts.add(new OptionDTO(u.Name, String.valueOf(u.Id)));
        }

        return opts;
    }

    @AuraEnabled(cacheable=true)
    public static List<OptionDTO> searchActiveUsers(String searchKey) {
        List<OptionDTO> results = new List<OptionDTO>();

        if (String.isBlank(searchKey) || searchKey.trim().length() < 2) {
            return results;
        }

        String likeKey = searchKey.trim() + '%';

        for (User u : [
            SELECT Id, Name
            FROM User
            WHERE IsActive = true
            AND IsPortalEnabled = false
            AND Name LIKE :likeKey
            ORDER BY Name
            LIMIT 10
        ]) {
            results.add(new OptionDTO(u.Name, String.valueOf(u.Id)));
        }

        return results;
    }
    
    private static List<OptionDTO> getPicklistOptions(Schema.SObjectField fieldRef) {
        List<OptionDTO> opts = new List<OptionDTO>();
        
        for (Schema.PicklistEntry pe : fieldRef.getDescribe().getPicklistValues()) {
            if (pe.isActive()) {
                opts.add(new OptionDTO(pe.getLabel(), pe.getValue()));
            }
        }
        return opts;
    }
    
    private static List<OptionDTO> getCategoryOptions() {
        return new List<OptionDTO>{
            new OptionDTO('Launch Sales', 'Launch Sales'),
            new OptionDTO('Inventory Sales', 'Inventory Sales')
        };
    }
    
    private static List<OptionDTO> getDistinctTextFieldOptions(String fieldApiName) {
        List<OptionDTO> opts = new List<OptionDTO>();
        Set<String> uniqueValues = new Set<String>();
        
        String soql =
            'SELECT ' + fieldApiName +
            ' FROM Commission_Line__c ' +
            'WHERE ' + fieldApiName + ' != null';
        
        for (SObject row : Database.query(soql)) {
            String value = (String) row.get(fieldApiName);
            if (String.isNotBlank(value)) {
                uniqueValues.add(value.trim());
            }
        }
        
        List<String> sortedValues = new List<String>();
        sortedValues.addAll(uniqueValues);
        sortedValues.sort();
        
        for (String value : sortedValues) {
            opts.add(new OptionDTO(value, value));
        }
        
        return opts;
    }
    
    @AuraEnabled
    public static void updateCommissionRows(List<Map<String, Object>> updates) {
        if (updates == null || updates.isEmpty()) {
            return;
        }

        Map<Id, Map<String, Object>> updateById = new Map<Id, Map<String, Object>>();
        Set<Id> commissionLineIds = new Set<Id>();

        for (Map<String, Object> row : updates) {
            if (row == null || !row.containsKey('recordId') || row.get('recordId') == null) {
                continue;
            }

            Id recId = (Id) row.get('recordId');
            commissionLineIds.add(recId);
            updateById.put(recId, row);
        }

        if (commissionLineIds.isEmpty()) {
            return;
        }

        Map<Id, Commission_Line__c> existingCommissionLines = new Map<Id, Commission_Line__c>([
            SELECT Id,
                Name,
                Booking_Date__c,
                Unit_Launch_Date__c,
                Lead_Source__c,
                Category_Of_Sale__c,
                Commission_Type__c,
                Commission_Percent__c,
                Commission_Amount__c,
                Opportunity__c,
                Opportunity__r.LeadSource,
                Opportunity__r.BrokerAgency__c,
                Opportunity__r.BrokerAgent__c,
                Opportunity__r.BrokerAgentName__c,
                Opportunity__r.BrokerAgentMobile__c,
                Sales_Order__c,
                Sales_Order__r.Unit__c
            FROM Commission_Line__c
            WHERE Id IN :commissionLineIds
        ]);

        List<Commission_Line__c> commissionLinesToUpdate = new List<Commission_Line__c>();
        Map<Id, Opportunity> opportunitiesToUpdate = new Map<Id, Opportunity>();
        Map<Id, Unit__c> unitsToUpdate = new Map<Id, Unit__c>();
        Map<Id, SalesOrder__c> salesOrdersToUpdate = new Map<Id, SalesOrder__c>();

        Boolean canUpdateSalesType =
            Commission_Line__c.Commission_Type__c.getDescribe().isUpdateable() &&
            !Commission_Line__c.Commission_Type__c.getDescribe().isCalculated();

        for (Id commissionLineId : updateById.keySet()) {
            Commission_Line__c existingRec = existingCommissionLines.get(commissionLineId);
            if (existingRec == null) {
                continue;
            }

            Map<String, Object> row = updateById.get(commissionLineId);

            if (row.containsKey('ownerId')) {
                String finalOwnerId = normalizeString(row.get('ownerId'));

                if (String.isBlank(finalOwnerId)) {
                    throw new AuraHandledException('Owner is required.');
                }

                if (existingRec.Sales_Order__c != null) {
                    salesOrdersToUpdate.put(
                        existingRec.Sales_Order__c,
                        new SalesOrder__c(
                            Id = existingRec.Sales_Order__c,
                            OwnerId = (Id) finalOwnerId
                        )
                    );
                }
            }
            

            Date finalUnitSoldDate = row.containsKey('unitSoldDate')
                ? parseDateValue(row.get('unitSoldDate'))
                : existingRec.Booking_Date__c;

            Date finalLaunchDate = row.containsKey('launchDate')
                ? parseDateValue(row.get('launchDate'))
                : existingRec.Unit_Launch_Date__c;

            String finalLeadSource = row.containsKey('leadSource')
                ? normalizeString(row.get('leadSource'))
                : normalizeString(existingRec.Lead_Source__c);

            validateBrokerPortalDetails(existingRec, finalLeadSource);

            Commission_Line__c clUpdate = new Commission_Line__c(Id = commissionLineId);
            Boolean hasChanges = false;

            if (row.containsKey('unitSoldDate')) {
                clUpdate.Booking_Date__c = finalUnitSoldDate;
                hasChanges = true;
            }

            if (row.containsKey('launchDate')) {
                clUpdate.Unit_Launch_Date__c = finalLaunchDate;
                hasChanges = true;

                if (existingRec.Sales_Order__r != null && existingRec.Sales_Order__r.Unit__c != null) {
                    unitsToUpdate.put(
                        existingRec.Sales_Order__r.Unit__c,
                        new Unit__c(
                            Id = existingRec.Sales_Order__r.Unit__c,
                            Unit_Launch_Date__c = finalLaunchDate
                        )
                    );
                }
            }

            if (row.containsKey('leadSource')) {
                clUpdate.Lead_Source__c = finalLeadSource;
                hasChanges = true;

                if (existingRec.Opportunity__c != null) {
                    opportunitiesToUpdate.put(
                        existingRec.Opportunity__c,
                        new Opportunity(
                            Id = existingRec.Opportunity__c,
                            LeadSource = finalLeadSource
                        )
                    );
                }
            }

            if (row.containsKey('commissionPercent')) {
                clUpdate.Commission_Percent__c = parseDecimalValue(row.get('commissionPercent'));
                hasChanges = true;
            }

            if (row.containsKey('commissionAmount')) {
                clUpdate.Commission_Amount__c = parseDecimalValue(row.get('commissionAmount'));
                hasChanges = true;
            }

            String derivedSalesType = deriveSalesType(finalLeadSource);
            if (canUpdateSalesType) {
                clUpdate.Commission_Type__c = derivedSalesType;
                hasChanges = true;
            }

            String derivedSaleCategory = deriveSaleCategory(finalLaunchDate, finalUnitSoldDate, existingRec.Category_Of_Sale__c);
            if (derivedSaleCategory != existingRec.Category_Of_Sale__c) {
                clUpdate.Category_Of_Sale__c = derivedSaleCategory;
                hasChanges = true;
            }

            if (hasChanges) {
                commissionLinesToUpdate.add(clUpdate);
            }
        }

        if (!opportunitiesToUpdate.isEmpty()) {
            List<Opportunity> oppList = opportunitiesToUpdate.values();
            SObjectAccessDecision oppDecision = Security.stripInaccessible(AccessType.UPDATABLE, oppList);
            update (List<Opportunity>) oppDecision.getRecords();
        }

        if (!salesOrdersToUpdate.isEmpty()) {
            List<SalesOrder__c> soList = salesOrdersToUpdate.values();
            SObjectAccessDecision soDecision = Security.stripInaccessible(AccessType.UPDATABLE, soList);
            update (List<SalesOrder__c>) soDecision.getRecords();
        }

        if (!unitsToUpdate.isEmpty()) {
            List<Unit__c> unitList = unitsToUpdate.values();
            SObjectAccessDecision unitDecision = Security.stripInaccessible(AccessType.UPDATABLE, unitList);
            update (List<Unit__c>) unitDecision.getRecords();
        }

        if (!commissionLinesToUpdate.isEmpty()) {
            SObjectAccessDecision clDecision = Security.stripInaccessible(AccessType.UPDATABLE, commissionLinesToUpdate);
            List<Commission_Line__c> sanitizedUpdates = (List<Commission_Line__c>) clDecision.getRecords();
            update sanitizedUpdates;

            List<Commission_Audit__c> auditRecords = new List<Commission_Audit__c>();
            for (Commission_Line__c updatedRec : sanitizedUpdates) {
                auditRecords.add(new Commission_Audit__c(
                    Commission_Line__c = updatedRec.Id
                ));
            }

            if (!auditRecords.isEmpty()) {
                insert auditRecords;
            }
        }
    }

    private static Date parseDateValue(Object value) {
        if (value == null) {
            return null;
        }
        return Date.valueOf(String.valueOf(value));
    }

    private static Decimal parseDecimalValue(Object value) {
        if (value == null || String.isBlank(String.valueOf(value))) {
            return null;
        }
        return Decimal.valueOf(String.valueOf(value));
    }

    private static String normalizeString(Object value) {
        return value == null ? null : String.valueOf(value).trim();
    }

    private static void validateBrokerPortalDetails(Commission_Line__c commissionLineRec, String leadSourceValue) {
        if (leadSourceValue != 'Broker Portal') {
            return;
        }

        Opportunity opp = commissionLineRec.Opportunity__r;

        Boolean missingBrokerInfo =
            opp == null ||
            opp.BrokerAgency__c == null ||
            opp.BrokerAgent__c == null ||
            String.isBlank(opp.BrokerAgentName__c) ||
            String.isBlank(opp.BrokerAgentMobile__c);

        if (missingBrokerInfo) {
            throw new AuraHandledException(
                'Broker portal lead should have a broker agency information filled in Opportunity, kindly reach out to the support team.'
            );
        }
    }

    private static String deriveSalesType(String leadSourceValue) {
        return leadSourceValue == 'Broker Portal' ? 'Indirect' : 'Direct';
    }

    private static String deriveSaleCategory(Date launchDate, Date soldDate, String existingCategory) {
        if (launchDate == null || soldDate == null) {
            return existingCategory;
        }

        Integer diffInDays = Math.abs(launchDate.daysBetween(soldDate));
        return diffInDays > 14 ? 'Inventory Sales' : 'Launch Sales';
    }
}