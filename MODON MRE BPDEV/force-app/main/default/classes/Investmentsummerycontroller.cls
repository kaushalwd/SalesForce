/*
@description       : Investment summary controller for customer360 dashboard
@author            : Chaitanya N
@group             : 
@last modified on  : 22-05-2026
@last modified by  : Chaitanya N.
*/
public with sharing class Investmentsummerycontroller {
    
@AuraEnabled(cacheable=true)
public static Map<String, Decimal> getProjectWiseAmounts(Id accountId, Date startDate, Date endDate, String projectName, String unitName) {
    
    Map<String, Decimal> projectMap = new Map<String, Decimal>();
    Date today = System.today();

    Date defaultStart = Date.newInstance(today.year(), 1, 1);
    Date defaultEnd = Date.newInstance(today.year(), 12, 31);

    Date effectiveStart = (startDate == null) ? defaultStart : startDate;
    Date effectiveEnd = (endDate == null) ? defaultEnd : endDate;

    Datetime startDT = Datetime.newInstance(effectiveStart, Time.newInstance(0,0,0,0));
    Datetime endDTExclusive = Datetime.newInstance(effectiveEnd.addDays(1), Time.newInstance(0,0,0,0));



    Account acc = [
        SELECT Id, RecordType.DeveloperName 
        FROM Account 
        WHERE Id = :accountId 
        LIMIT 1
    ];

    List<Id> targetAccountIds = new List<Id>{ accountId };


    if (targetAccountIds.isEmpty()) {
        return new Map<String, Decimal>();
    }

    // SOQL injection fix: LWC filters bound via queryWithBinds (no string concat of values).
    Map<String, Object> soBinds = new Map<String, Object>{
        'targetAccountIds' => targetAccountIds,
        'startDT' => startDT,
        'endDTExclusive' => endDTExclusive
    };

    String directQuery = 
        'SELECT Id, Name, TotalAmount__c, Opportunity__r.LanguagePreference__c, CustomerAccount__r.Name,' +
        ' Unit__r.Status__c, PrimaryContact__r.Name, ProjectName__c, Phase_Name__c,' +
        ' Totalpaidamount__c, PaymentPlan__r.Name, Unit_Name__c,' +
        ' Unit__r.UnitClassification__c, Unit__r.Unit_Sold_Date__c,' +
        ' Number_of_JointOwners__c, CreatedDate ' +
        'FROM SalesOrder__c ' +
        'WHERE CustomerAccount__c IN :targetAccountIds ' +
        'AND ProjectName__c != NULL ' +
        'AND CreatedDate >= :startDT ' +
        'AND CreatedDate < :endDTExclusive ' +
        'AND Status__c NOT IN (' +
        '\'Cancelled\', \'System cancelled\', \'Cancelled SR\', \'Voided\', ' +
        '\'Property Transfer Cancelled - SR\', \'Unit Swap Cancelled - SR\', ' +
        '\'Unit Upgrade Cancelled - SR\', \'Unit Cancellation Cancelled - SR\', ' +
        '\'Unit Consolidation Cancelled - SR\', \'Property Transfer Title Deed Cancelled - SR\'' +
        ')';

    if (String.isNotBlank(projectName)) {
        directQuery += ' AND ProjectName__c = :projectName';
        soBinds.put('projectName', projectName);
    }
    if (String.isNotBlank(unitName)) {
        directQuery += ' AND Unit_Name__c = :unitName';
        soBinds.put('unitName', unitName);
    }

    List<SalesOrder__c> directOrders = Database.queryWithBinds(directQuery, soBinds, AccessLevel.SYSTEM_MODE);

    // Fetch via Joint Owners
    String jointQuery = 
        'SELECT Id, Name, TotalAmount__c, Opportunity__r.LanguagePreference__c, CustomerAccount__r.Name,' +
        ' Unit__r.Status__c, PrimaryContact__r.Name, ProjectName__c, Phase_Name__c,' +
        ' Totalpaidamount__c, PaymentPlan__r.Name, Unit_Name__c,' +
        ' Unit__r.UnitClassification__c, Unit__r.Unit_Sold_Date__c,' +
        ' Number_of_JointOwners__c, CreatedDate ' +
        'FROM SalesOrder__c ' +
        'WHERE Id IN (SELECT SalesOrder__c FROM JointOwner__c WHERE JointOwnerAccount__c IN :targetAccountIds) ' +
        'AND ProjectName__c != NULL ' +
        'AND CreatedDate >= :startDT ' +
        'AND CreatedDate < :endDTExclusive ' +
        'AND Status__c NOT IN (' +
        '\'Cancelled\', \'System cancelled\', \'Cancelled SR\', \'Voided\', ' +
        '\'Property Transfer Cancelled - SR\', \'Unit Swap Cancelled - SR\', ' +
        '\'Unit Upgrade Cancelled - SR\', \'Unit Cancellation Cancelled - SR\', ' +
        '\'Unit Consolidation Cancelled - SR\', \'Property Transfer Title Deed Cancelled - SR\'' +
        ')';

    if (String.isNotBlank(projectName)) {
        jointQuery += ' AND ProjectName__c = :projectName';
    }
    if (String.isNotBlank(unitName)) {
        jointQuery += ' AND Unit_Name__c = :unitName';
    }

    List<SalesOrder__c> jointOrders = Database.queryWithBinds(jointQuery, soBinds, AccessLevel.SYSTEM_MODE);

    // Combine both results
    List<SalesOrder__c> allOrders = new List<SalesOrder__c>();
    allOrders.addAll(directOrders);
    allOrders.addAll(jointOrders);

    // Fetch Joint Owners for all related SalesOrders
    Map<Id, List<JointOwner__c>> jointOwnerMap = new Map<Id, List<JointOwner__c>>();
    if (!allOrders.isEmpty()) {
        List<JointOwner__c> jointOwners = [
            SELECT Id, OwnershipPercentage__c, RelationshipType__c, RelationshipSubType__c,
                   JointOwnerAccount__r.Name, Opportunity__r.Name, SalesOrder__c
            FROM JointOwner__c
            WHERE SalesOrder__c IN :allOrders
        ];
        for (JointOwner__c jo : jointOwners) {
            if (!jointOwnerMap.containsKey(jo.SalesOrder__c)) {
                jointOwnerMap.put(jo.SalesOrder__c, new List<JointOwner__c>());
            }
            jointOwnerMap.get(jo.SalesOrder__c).add(jo);
        }
    }

    // Aggregate total amount by project
    for (SalesOrder__c order : allOrders) {
        String project = order.ProjectName__c;
        Decimal amount = order.TotalAmount__c != null ? order.TotalAmount__c : 0;

        if (projectMap.containsKey(project)) {
            projectMap.put(project, projectMap.get(project) + amount);
        } else {
            projectMap.put(project, amount);
        }
    }
    return projectMap;
}

@AuraEnabled(cacheable=true)  
public static Map<String, Map<String, Integer>> getUnitClassificationCounts(
    Id accountId,
    Date startDate,
    Date endDate,
    String projectName,
    String unitName
) {
    Map<String, Map<String, Integer>> unitMap = new Map<String, Map<String, Integer>>();
    Date today = System.today();

    // Default Dates
    Date defaultStart = Date.newInstance(today.year(), 1, 1);
    Date defaultEnd = Date.newInstance(today.year(), 12, 31);
    Date effectiveStart = (startDate == null) ? defaultStart : startDate;
    Date effectiveEnd = (endDate == null) ? defaultEnd : endDate;

    Datetime startDT = Datetime.newInstance(effectiveStart, Time.newInstance(0,0,0,0));
    Datetime endDTExclusive = Datetime.newInstance(effectiveEnd.addDays(1), Time.newInstance(0,0,0,0));


    // Identify Account Type
    Account acc = [
        SELECT Id, RecordType.DeveloperName
        FROM Account
        WHERE Id = :accountId
        LIMIT 1
    ];

    List<Id> targetAccountIds = new List<Id>();

    if (acc.RecordType.DeveloperName == 'PersonAccount') {
        targetAccountIds.add(acc.Id);
    } else if (acc.RecordType.DeveloperName == 'OrganizationAccount') {
        for (Contact con : [
            SELECT AccountId
            FROM Contact
            WHERE AccountId = :accountId
            AND Primary_Owner__c = TRUE
        ]) {
            targetAccountIds.add(con.AccountId);
        }
    }

    if (targetAccountIds.isEmpty()) {
        return unitMap;
    }

    // SOQL injection fix: LWC filters bound via queryWithBinds (no string concat of values).
    Map<String, Object> soBinds = new Map<String, Object>{
        'targetAccountIds' => targetAccountIds,
        'startDT' => startDT,
        'endDTExclusive' => endDTExclusive
    };

    // Fetch direct Sales Orders
    String directQuery = 
        'SELECT Id, Name, TotalAmount__c, Opportunity__r.LanguagePreference__c, CustomerAccount__r.Name,' +
        ' Unit__r.Status__c, PrimaryContact__r.Name, ProjectName__c, Phase_Name__c,' +
        ' Totalpaidamount__c, PaymentPlan__r.Name, Unit_Name__c, Unit__r.Name,' +
        ' Unit__r.UnitClassification__c, Unit__r.Unit_Sold_Date__c,' +
        ' Number_of_JointOwners__c, CreatedDate ' +
        'FROM SalesOrder__c ' +
        'WHERE CustomerAccount__c IN :targetAccountIds ' +
        'AND ProjectName__c != NULL ' +
        'AND CreatedDate >= :startDT ' +
        'AND CreatedDate < :endDTExclusive ' +
        'AND Status__c NOT IN (' +
        '\'Cancelled\', \'System cancelled\', \'Cancelled SR\', \'Voided\', ' +
        '\'Property Transfer Cancelled - SR\', \'Unit Swap Cancelled - SR\', ' +
        '\'Unit Upgrade Cancelled - SR\', \'Unit Cancellation Cancelled - SR\', ' +
        '\'Unit Consolidation Cancelled - SR\', \'Property Transfer Title Deed Cancelled - SR\'' +
        ')';

    //Added Filters same as getProjectWiseAmounts
    if (String.isNotBlank(projectName)) {
        directQuery += ' AND ProjectName__c = :projectName';
        soBinds.put('projectName', projectName);
    }
    if (String.isNotBlank(unitName)) {
        directQuery += ' AND Unit_Name__c = :unitName';
        soBinds.put('unitName', unitName);
    }

    List<SalesOrder__c> directOrders = Database.queryWithBinds(directQuery, soBinds, AccessLevel.SYSTEM_MODE);

    // Fetch via Joint Owners
    String jointQuery = 
        'SELECT Id, Name, TotalAmount__c, Opportunity__r.LanguagePreference__c, CustomerAccount__r.Name,' +
        ' Unit__r.Status__c, PrimaryContact__r.Name, ProjectName__c, Phase_Name__c,' +
        ' Totalpaidamount__c, PaymentPlan__r.Name, Unit_Name__c, Unit__r.Name,' +
        ' Unit__r.UnitClassification__c, Unit__r.Unit_Sold_Date__c,' +
        ' Number_of_JointOwners__c, CreatedDate ' +
        'FROM SalesOrder__c ' +
        'WHERE Id IN (SELECT SalesOrder__c FROM JointOwner__c WHERE JointOwnerAccount__c IN :targetAccountIds) ' +
        'AND ProjectName__c != NULL ' +
        'AND CreatedDate >= :startDT ' +
        'AND CreatedDate < :endDTExclusive ' +
        'AND Status__c NOT IN (' +
        '\'Cancelled\', \'System cancelled\', \'Cancelled SR\', \'Voided\', ' +
        '\'Property Transfer Cancelled - SR\', \'Unit Swap Cancelled - SR\', ' +
        '\'Unit Upgrade Cancelled - SR\', \'Unit Cancellation Cancelled - SR\', ' +
        '\'Unit Consolidation Cancelled - SR\', \'Property Transfer Title Deed Cancelled - SR\'' +
        ')';

    // Added Filters same as getProjectWiseAmounts
    if (String.isNotBlank(projectName)) {
        jointQuery += ' AND ProjectName__c = :projectName';
    }
    if (String.isNotBlank(unitName)) {
        jointQuery += ' AND Unit_Name__c = :unitName';
    }

    List<SalesOrder__c> jointOrders = Database.queryWithBinds(jointQuery, soBinds, AccessLevel.SYSTEM_MODE);

    //  Combine both results
    List<SalesOrder__c> allOrders = new List<SalesOrder__c>();
    allOrders.addAll(directOrders);
    allOrders.addAll(jointOrders);

    // Fetch Joint Owners for all related SalesOrders
    Map<Id, List<JointOwner__c>> jointOwnerMap = new Map<Id, List<JointOwner__c>>();
    if (!allOrders.isEmpty()) {
        List<JointOwner__c> jointOwners = [
            SELECT Id, OwnershipPercentage__c, RelationshipType__c, RelationshipSubType__c,
                   JointOwnerAccount__r.Name, Opportunity__r.Name, SalesOrder__c
            FROM JointOwner__c
            WHERE SalesOrder__c IN :allOrders
        ];
        for (JointOwner__c jo : jointOwners) {
            if (!jointOwnerMap.containsKey(jo.SalesOrder__c)) {
                jointOwnerMap.put(jo.SalesOrder__c, new List<JointOwner__c>());
            }
            jointOwnerMap.get(jo.SalesOrder__c).add(jo);
        }
    }

    //  Group by Unit Name → Classification
    for (SalesOrder__c order : allOrders) {
        if (order.Unit__r == null) continue;

        String uName = order.Unit__r.Name;
        String classification = order.Unit__r.UnitClassification__c;

        if (String.isBlank(classification)) classification = 'N/A';
        if (String.isBlank(uName)) continue;

        if (!unitMap.containsKey(uName)) {
            unitMap.put(uName, new Map<String, Integer>());
        }

        Map<String, Integer> classificationMap = unitMap.get(uName);

        if (classificationMap.containsKey(classification)) {
            classificationMap.put(classification, classificationMap.get(classification) + 1);
        } else {
            classificationMap.put(classification, 1);
        }

        unitMap.put(uName, classificationMap);
    }

    return unitMap;
}


    /*@AuraEnabled(cacheable=true)
    public static Map<String, List<String>> getProjectAndUnitNames(Id accountId) {
        Map<String, List<String>> resultMap = new Map<String, List<String>>();
        Set<String> projectNames = new Set<String>();
        Set<String> unitNames = new Set<String>();

        if (accountId == null) {
            return resultMap;
        }

        //Fetch Account and determine target accounts (same logic as getProjectWiseAmounts)
        Account acc = [
            SELECT Id, RecordType.DeveloperName 
            FROM Account 
            WHERE Id = :accountId 
            LIMIT 1
        ];

        List<Id> targetAccountIds = new List<Id>();

        if (acc.RecordType.DeveloperName == 'PersonAccount') {
            targetAccountIds.add(acc.Id);
        } 
        else if (acc.RecordType.DeveloperName == 'OrganizationAccount') {
            for (Contact con : [
                SELECT AccountId 
                FROM Contact 
                WHERE AccountId = :accountId 
                AND Primary_Owner__c = TRUE
            ]) {
                targetAccountIds.add(con.AccountId);
            }
        }

        if (targetAccountIds.isEmpty()) {
            return resultMap;
        }

        // Direct Sales Orders
        List<SalesOrder__c> directOrders = [
            SELECT ProjectName__c, Unit_Name__c
            FROM SalesOrder__c
            WHERE CustomerAccount__c IN :targetAccountIds
            AND Status__c NOT IN (
                'Cancelled','System cancelled','Cancelled SR','Voided',
                'Property Transfer Cancelled - SR','Unit Swap Cancelled - SR',
                'Unit Upgrade Cancelled - SR','Unit Cancellation Cancelled - SR',
                'Unit Consolidation Cancelled - SR','Property Transfer Title Deed Cancelled - SR'
            )
        ];

        // Joint Owner Sales Orders
        List<SalesOrder__c> jointOrders = [
            SELECT ProjectName__c, Unit_Name__c
            FROM SalesOrder__c
            WHERE Id IN (
                SELECT SalesOrder__c 
                FROM JointOwner__c 
                WHERE JointOwnerAccount__c IN :targetAccountIds
            )
            AND Status__c NOT IN (
                'Cancelled','System cancelled','Cancelled SR','Voided',
                'Property Transfer Cancelled - SR','Unit Swap Cancelled - SR',
                'Unit Upgrade Cancelled - SR','Unit Cancellation Cancelled - SR',
                'Unit Consolidation Cancelled - SR','Property Transfer Title Deed Cancelled - SR'
            )
        ];

        List<SalesOrder__c> allOrders = new List<SalesOrder__c>();
        allOrders.addAll(directOrders);
        allOrders.addAll(jointOrders);

        List<String> projectUnitPairs = new List<String>();
        resultMap.put('projectToUnits', new List<String>(projectUnitPairs));

        for (SalesOrder__c so : allOrders) {
            if (String.isNotBlank(so.ProjectName__c)) {
                projectNames.add(so.ProjectName__c);
            }
            if (String.isNotBlank(so.Unit_Name__c)) {
                unitNames.add(so.Unit_Name__c);
            }

            // Dependency pair (only when both present)
            if (String.isNotBlank(so.ProjectName__c) && String.isNotBlank(so.Unit_Name__c)) {
                projectUnitPairs.add(so.ProjectName__c + '|' + so.Unit_Name__c);
            }
        }

        resultMap.put('projects', new List<String>(projectNames));
        resultMap.put('units', new List<String>(unitNames));
        resultMap.put('projectToUnits', projectUnitPairs);


        return resultMap;
    }*/
    @AuraEnabled(cacheable=true)
    public static Map<String, List<String>> getProjectAndUnitNames(Id accountId) {
        Map<String, List<String>> resultMap = new Map<String, List<String>>();
        Set<String> projectNames = new Set<String>();
        Set<String> unitNames = new Set<String>();
        Set<String> projectUnitPairSet = new Set<String>();

        resultMap.put('projects', new List<String>());
        resultMap.put('units', new List<String>());
        resultMap.put('projectToUnits', new List<String>());

        if (accountId == null) {
            return resultMap;
        }

        List<Id> targetAccountIds = new List<Id>{ accountId };

        List<SalesOrder__c> directOrders = [
            SELECT ProjectName__c, Unit_Name__c
            FROM SalesOrder__c
            WHERE CustomerAccount__c IN :targetAccountIds
            AND ProjectName__c != null
            AND Status__c NOT IN (
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
            )
        ];

        List<SalesOrder__c> jointOrders = [
            SELECT ProjectName__c, Unit_Name__c
            FROM SalesOrder__c
            WHERE Id IN (
                SELECT SalesOrder__c
                FROM JointOwner__c
                WHERE JointOwnerAccount__c IN :targetAccountIds
            )
            AND ProjectName__c != null
            AND Status__c NOT IN (
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
            )
        ];

        List<SalesOrder__c> allOrders = new List<SalesOrder__c>();
        allOrders.addAll(directOrders);
        allOrders.addAll(jointOrders);

        for (SalesOrder__c so : allOrders) {
            if (String.isNotBlank(so.ProjectName__c)) {
                projectNames.add(so.ProjectName__c);
            }

            if (String.isNotBlank(so.Unit_Name__c)) {
                unitNames.add(so.Unit_Name__c);
            }

            if (String.isNotBlank(so.ProjectName__c) && String.isNotBlank(so.Unit_Name__c)) {
                projectUnitPairSet.add(so.ProjectName__c + '|' + so.Unit_Name__c);
            }
        }

        List<String> projectList = new List<String>(projectNames);
        projectList.sort();

        List<String> unitList = new List<String>(unitNames);
        unitList.sort();

        List<String> projectUnitPairs = new List<String>(projectUnitPairSet);
        projectUnitPairs.sort();

        resultMap.put('projects', projectList);
        resultMap.put('units', unitList);
        resultMap.put('projectToUnits', projectUnitPairs);

        return resultMap;
    }
    
    @AuraEnabled(cacheable=true)
    public static Decimal getTotalInvestmentValue(
        Id accountId,
        Date startDate,
        Date endDate,
        String projectName,
        String unitName
    ) {
        Map<String, Decimal> projectMap =
            getProjectWiseAmounts(accountId, startDate, endDate, projectName, unitName);

        Decimal total = 0;
        for (Decimal amt : projectMap.values()) total += (amt == null ? 0 : amt);
        return total;
    }

    @AuraEnabled(cacheable=true)
    public static Integer getTotalUnitsPurchased(
        Id accountId,
        String startDate,
        String endDate,
        String projectName,
        String unitName
    ) {
        if (accountId == null) return 0;

        Date sDate = String.isBlank(startDate) ? null : Date.valueOf(startDate);
        Date eDate = String.isBlank(endDate) ? null : Date.valueOf(endDate);

        // Use end-exclusive for CreatedDate filtering
        Datetime startDt = (sDate == null) ? null : Datetime.newInstance(sDate, Time.newInstance(0, 0, 0, 0));
        Datetime endExclusive = (eDate == null) ? null : Datetime.newInstance(eDate.addDays(1), Time.newInstance(0, 0, 0, 0));

        // SOQL injection fix: date/project/unit filters bound via queryWithBinds.
        Map<String, Object> binds = new Map<String, Object>{ 'accountId' => accountId };
        String soql =
            'SELECT COUNT_DISTINCT(Unit__c) cnt ' +
            'FROM SalesOrder__c ' +
            'WHERE CustomerAccount__c = :accountId ' +
            'AND Status__c IN (\'Completed\', \'Sold\') ';

        if (startDt != null) {
            soql += ' AND CreatedDate >= :startDt';
            binds.put('startDt', startDt);
        }
        if (endExclusive != null) {
            soql += ' AND CreatedDate < :endExclusive';
            binds.put('endExclusive', endExclusive);
        }

        if (!String.isBlank(projectName)) {
            soql += ' AND ProjectName__c = :projectName';
            binds.put('projectName', projectName);
        }
        if (!String.isBlank(unitName)) {
            soql += ' AND Unit_Name__c = :unitName';
            binds.put('unitName', unitName);
        }

        List<AggregateResult> results = Database.queryWithBinds(soql, binds, AccessLevel.SYSTEM_MODE);
        Integer cnt = 0;

        if (!results.isEmpty()) {
            Object v = results[0].get('cnt');
            cnt = (v == null) ? 0 : Integer.valueOf(String.valueOf(v));
        }

        return cnt;

    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Integer> getUnitTypeCounts(
        Id accountId,
        Date startDate,
        Date endDate,
        String projectName,
        String unitName
    ) {


        Map<String, Integer> typeMap = new Map<String, Integer>();
        Date today = System.today();

        Date defaultStart = Date.newInstance(today.year(), 1, 1);
        Date defaultEnd   = Date.newInstance(today.year(), 12, 31);

        Date effectiveStart = (startDate == null) ? defaultStart : startDate;
        Date effectiveEnd   = (endDate == null) ? defaultEnd   : endDate;

        Datetime startDT = Datetime.newInstance(effectiveStart, Time.newInstance(0,0,0,0));
        Datetime endDTExclusive = Datetime.newInstance(effectiveEnd.addDays(1), Time.newInstance(0,0,0,0));

        Account acc = [
            SELECT Id, RecordType.DeveloperName
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];

        List<Id> targetAccountIds = new List<Id>{ accountId };

        // SOQL injection fix: LWC filters bound via queryWithBinds (no string concat of values).
        Map<String, Object> soBinds = new Map<String, Object>{
            'targetAccountIds' => targetAccountIds,
            'startDT' => startDT,
            'endDTExclusive' => endDTExclusive
        };

        String baseQuery =
            'SELECT Id, Unit__r.UnitClassification__c, Unit__r.Name, CreatedDate ' +
            'FROM SalesOrder__c ' +
            'WHERE ProjectName__c != NULL ' +
            'AND CreatedDate >= :startDT ' +
            'AND CreatedDate < :endDTExclusive ' +
            'AND Status__c NOT IN (' +
            '\'Cancelled\', \'System cancelled\', \'Cancelled SR\', \'Voided\', ' +
            '\'Property Transfer Cancelled - SR\', \'Unit Swap Cancelled - SR\', ' +
            '\'Unit Upgrade Cancelled - SR\', \'Unit Cancellation Cancelled - SR\', ' +
            '\'Unit Consolidation Cancelled - SR\', \'Property Transfer Title Deed Cancelled - SR\'' +
            ') ';

        String directQuery = baseQuery + ' AND CustomerAccount__c IN :targetAccountIds';
        if (String.isNotBlank(projectName)) {
            directQuery += ' AND ProjectName__c = :projectName';
            soBinds.put('projectName', projectName);
        }
        if (String.isNotBlank(unitName)) {
            directQuery += ' AND Unit_Name__c = :unitName';
            soBinds.put('unitName', unitName);
        }

        String jointQuery  = baseQuery +
            ' AND Id IN (SELECT SalesOrder__c FROM JointOwner__c WHERE JointOwnerAccount__c IN :targetAccountIds)';
        if (String.isNotBlank(projectName)) jointQuery += ' AND ProjectName__c = :projectName';
        if (String.isNotBlank(unitName))    jointQuery += ' AND Unit_Name__c = :unitName';

        List<SalesOrder__c> allOrders = new List<SalesOrder__c>();
        allOrders.addAll((List<SalesOrder__c>) Database.queryWithBinds(directQuery, soBinds, AccessLevel.SYSTEM_MODE));
        allOrders.addAll((List<SalesOrder__c>) Database.queryWithBinds(jointQuery, soBinds, AccessLevel.SYSTEM_MODE));


        for (SalesOrder__c so : allOrders) {
            if (so.Unit__r == null) continue;

            String unitType = so.Unit__r.UnitClassification__c;
            if (String.isBlank(unitType)) unitType = 'N/A';

            typeMap.put(unitType, (typeMap.containsKey(unitType) ? typeMap.get(unitType) : 0) + 1);
        }

        return typeMap;
    }




}