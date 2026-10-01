/**********************************************************************************************************************
* Name               : SalesOrderSOAAController                                                        
* Description        : This class is used as a helper for Sales Ops User Assignment
* Created By         : ActiveMinds                                                
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           Fatima Khan                         28 Mar 2026     Initial Draft 
******************************************************************************************************************/
public with sharing class SalesOrderSOAAController {

    public class MatrixRowDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public Id salesAssociateId;
        @AuraEnabled public String salesAssociateName;
        @AuraEnabled public Boolean salesAssociateIsActive;
        @AuraEnabled public Id salesOpsId;
        @AuraEnabled public String salesOpsName;
        @AuraEnabled public Boolean isActive;
        @AuraEnabled public Date expiryDate;
/*         @AuraEnabled public Integer pendingSalesOrders;
 */    }

    public class UpsertRequest {
        @AuraEnabled public Id id;
        @AuraEnabled public Id salesAssociateId;
        @AuraEnabled public Id salesOpsId;
        @AuraEnabled public Boolean isActive;
        @AuraEnabled public Date expiryDate;
    }

    public class InitDTO {
        @AuraEnabled public List<MatrixRowDTO> rows;
        @AuraEnabled public Object perms;
        @AuraEnabled public Map<String, Id> emailToUserId;
        @AuraEnabled public List<Id> excludedUserIds; 
    }

    @AuraEnabled(cacheable=true)
    public static InitDTO getInit(String cacheKey) {
        InitDTO out = new InitDTO();
        out.rows = getMatrixRowsInternal();
        Map<String, Object> accessParsed = parseAccessLabel();
        out.perms = accessParsed;
        out.emailToUserId = resolveEmailsToActiveUserIds(accessParsed);

        out.excludedUserIds = getUsersFromInactiveAssignments(); // NEW

        System.debug(LoggingLevel.WARN,
            '[SOAA][getInit] cacheKey=' + cacheKey +
            ' rows=' + out.rows.size() +
            ' emailsResolved=' + out.emailToUserId.size() +
            ' excludedUserIds=' + (out.excludedUserIds == null ? 0 : out.excludedUserIds.size())
        );
        return out;
    }

    private static List<Id> getUsersFromInactiveAssignments() {
        Set<Id> excluded = new Set<Id>();

        for (Sales_Operations_Associate_Assignment__c r : [
            SELECT Sales_Associate__c, Sales_Operations_Associate__c
            FROM Sales_Operations_Associate_Assignment__c
            WHERE Is_Active__c = FALSE
            
        ]) {
            if (r.Sales_Associate__c != null) excluded.add(r.Sales_Associate__c);
            if (r.Sales_Operations_Associate__c != null) excluded.add(r.Sales_Operations_Associate__c);
        }

        return new List<Id>(excluded);
    }

    private static List<MatrixRowDTO> getMatrixRowsInternal() {
        List<Sales_Operations_Associate_Assignment__c> rows = [
            SELECT Id,
                   Sales_Associate__c,
                   Sales_Associate__r.Name,
                   Sales_Associate__r.IsActive,
                   Sales_Operations_Associate__c,
                   Sales_Operations_Associate__r.Name,
                   Is_Active__c,
                   Expiry_Date__c
            FROM Sales_Operations_Associate_Assignment__c
            ORDER BY LastModifiedDate DESC
           
        ];

        Set<Id> opsIds = new Set<Id>();
        for (Sales_Operations_Associate_Assignment__c r : rows) {
            if (r.Sales_Operations_Associate__c != null) opsIds.add(r.Sales_Operations_Associate__c);
        }

       /*  Map<Id, Integer> pendingByOps = new Map<Id, Integer>();
        if (!opsIds.isEmpty()) {
            for (AggregateResult ar : [
                SELECT Sales_Operations_Associate__c opsId, COUNT(Id) cnt
                FROM SalesOrder__c
                WHERE Sales_Operations_Associate__c IN :opsIds
                  AND Sub_Status__c = 'Pending With Sales Operation'
                  AND Resale__c = FALSE
                  AND Status__c NOT IN ('Voided','Cancelled')
                GROUP BY Sales_Operations_Associate__c
            ]) {
                pendingByOps.put((Id)ar.get('opsId'), (Integer)ar.get('cnt'));
            }
        } */

        List<MatrixRowDTO> out = new List<MatrixRowDTO>();

        for (Sales_Operations_Associate_Assignment__c r : rows) {
            MatrixRowDTO dto = new MatrixRowDTO();
            dto.id = r.Id;
            dto.salesAssociateId = r.Sales_Associate__c;
            dto.salesAssociateName = r.Sales_Associate__r != null ? r.Sales_Associate__r.Name : null;
            dto.salesAssociateIsActive = r.Sales_Associate__r != null ? r.Sales_Associate__r.IsActive : null;
            dto.salesOpsId = r.Sales_Operations_Associate__c;
            dto.salesOpsName = r.Sales_Operations_Associate__r != null ? r.Sales_Operations_Associate__r.Name : null;
            dto.isActive = r.Is_Active__c;
            dto.expiryDate = r.Expiry_Date__c;
            /* dto.pendingSalesOrders = (r.Sales_Operations_Associate__c != null && pendingByOps.containsKey(r.Sales_Operations_Associate__c))
                ? pendingByOps.get(r.Sales_Operations_Associate__c)
                : 0; */
            out.add(dto);
        }
        return out;
    }

    @AuraEnabled
    public static MatrixRowDTO createRow(Id salesAssociateId, Id salesOpsId, Boolean isActive, Date expiryDate) {
        System.debug(LoggingLevel.WARN,
            '[SOAA][createRowV2] salesAssociateId=' + salesAssociateId +
            ' salesOpsId=' + salesOpsId +
            ' isActive=' + isActive +
            ' expiryDate=' + expiryDate
        );

        if (salesAssociateId == null) throw new AuraHandledException('Sales User (Sales Associate) is required.');
        if (salesOpsId == null) throw new AuraHandledException('Sales Operations User is required.');

        Integer dupCount = [
            SELECT COUNT()
            FROM Sales_Operations_Associate_Assignment__c
            WHERE Sales_Associate__c = :salesAssociateId
              AND Sales_Associate__r.IsActive = true
        ];
        System.debug(LoggingLevel.WARN, '[SOAA][createRow] dupCount(activeOnly)=' + dupCount);
        if (dupCount > 0) throw new AuraHandledException('Duplicate Sales User: this Sales Associate already exists in the matrix.');

        Sales_Operations_Associate_Assignment__c rec = new Sales_Operations_Associate_Assignment__c();
        rec.Sales_Associate__c = salesAssociateId;
        rec.Sales_Operations_Associate__c = salesOpsId;
        rec.Is_Active__c = (isActive == null ? true : isActive);
        rec.Expiry_Date__c = expiryDate;
        insert rec;

        Sales_Operations_Associate_Assignment__c fresh = [
            SELECT Id,
                   Sales_Associate__c,
                   Sales_Associate__r.Name,
                   Sales_Associate__r.IsActive,
                   Sales_Operations_Associate__c,
                   Sales_Operations_Associate__r.Name,
                   Is_Active__c,
                   Expiry_Date__c
            FROM Sales_Operations_Associate_Assignment__c
            WHERE Id = :rec.Id
           
        ];

        MatrixRowDTO dto = new MatrixRowDTO();
        dto.id = fresh.Id;
        dto.salesAssociateId = fresh.Sales_Associate__c;
        dto.salesAssociateName = fresh.Sales_Associate__r != null ? fresh.Sales_Associate__r.Name : null;
        dto.salesAssociateIsActive = fresh.Sales_Associate__r != null ? fresh.Sales_Associate__r.IsActive : null;
        dto.salesOpsId = fresh.Sales_Operations_Associate__c;
        dto.salesOpsName = fresh.Sales_Operations_Associate__r != null ? fresh.Sales_Operations_Associate__r.Name : null;
        dto.isActive = fresh.Is_Active__c;
        dto.expiryDate = fresh.Expiry_Date__c;
/*         dto.pendingSalesOrders = 0;
 */
        System.debug(LoggingLevel.WARN, '[SOAA][createRow] insertedId=' + dto.id);
        return dto;
    }

    @AuraEnabled
public static List<MatrixRowDTO> updateRows(List<UpsertRequest> reqs) {
    if (reqs == null || reqs.isEmpty()) return new List<MatrixRowDTO>();

    Map<Id, UpsertRequest> byId = new Map<Id, UpsertRequest>();
    for (UpsertRequest r : reqs) {
        if (r != null && r.id != null) byId.put(r.id, r);
    }
    if (byId.isEmpty()) return new List<MatrixRowDTO>();

    List<Sales_Operations_Associate_Assignment__c> existing = [
        SELECT Id, Sales_Operations_Associate__c, Is_Active__c, Expiry_Date__c
        FROM Sales_Operations_Associate_Assignment__c
        WHERE Id IN :byId.keySet()
    ];

    List<Sales_Operations_Associate_Assignment__c> toUpdate = new List<Sales_Operations_Associate_Assignment__c>();
    for (Sales_Operations_Associate_Assignment__c cur : existing) {
        UpsertRequest r = byId.get(cur.Id);
        if (r == null) continue;

        Boolean changed = false;

        if (r.salesOpsId != null && r.salesOpsId != cur.Sales_Operations_Associate__c) {
            cur.Sales_Operations_Associate__c = r.salesOpsId;
            changed = true;
        }

        if (r.isActive != null && r.isActive != cur.Is_Active__c) {
            cur.Is_Active__c = r.isActive;
            changed = true;
        }

        if (r.expiryDate != cur.Expiry_Date__c) {
            cur.Expiry_Date__c = r.expiryDate;
            changed = true;
        }

        if (changed) toUpdate.add(cur);
    }

    System.debug(LoggingLevel.WARN, '[SOAA][updateRows] requested=' + reqs.size() + ' updating=' + toUpdate.size());

    if (!toUpdate.isEmpty()) {
        update toUpdate;
    }

    List<Sales_Operations_Associate_Assignment__c> fresh = [
        SELECT Id,
               Sales_Associate__c,
               Sales_Associate__r.Name,
               Sales_Associate__r.IsActive,
               Sales_Operations_Associate__c,
               Sales_Operations_Associate__r.Name,
               Is_Active__c,
               Expiry_Date__c
        FROM Sales_Operations_Associate_Assignment__c
        WHERE Id IN :byId.keySet()
    ];

    for (Sales_Operations_Associate_Assignment__c f : fresh) {
        UpsertRequest r = byId.get(f.Id);
        if (r == null) continue;

        if (r.salesOpsId != null && f.Sales_Operations_Associate__c != r.salesOpsId) {
            System.debug(LoggingLevel.WARN,
                '[SOAA][updateRows] mismatch after update. id=' + f.Id +
                ' requestedSalesOps=' + r.salesOpsId +
                ' actualSalesOps=' + f.Sales_Operations_Associate__c
            );
            throw new AuraHandledException('Update did not persist. A Trigger/Flow is likely overwriting the Sales Operations User.');
        }

        if (r.isActive != null && f.Is_Active__c != r.isActive) {
            throw new AuraHandledException('Update did not persist. A Trigger/Flow is likely overwriting the Active value.');
        }

        if (f.Expiry_Date__c != r.expiryDate) {
            throw new AuraHandledException('Update did not persist. A Trigger/Flow is likely overwriting the Expiry Date.');
        }
    }

    Set<Id> opsIds = new Set<Id>();
    for (Sales_Operations_Associate_Assignment__c f : fresh) {
        if (f.Sales_Operations_Associate__c != null) opsIds.add(f.Sales_Operations_Associate__c);
    }

    /* Map<Id, Integer> pendingByOps = new Map<Id, Integer>();
    if (!opsIds.isEmpty()) {
        for (AggregateResult ar : [
            SELECT Sales_Operations_Associate__c opsId, COUNT(Id) cnt
            FROM SalesOrder__c
            WHERE Sales_Operations_Associate__c IN :opsIds
              AND Sub_Status__c = 'Pending With Sales Operation'
              AND Status__c NOT IN ('Voided','Cancelled')
              AND Resale__c = FALSE
            GROUP BY Sales_Operations_Associate__c
        ]) {
            pendingByOps.put((Id)ar.get('opsId'), (Integer)ar.get('cnt'));
        } 
    } */

    List<MatrixRowDTO> out = new List<MatrixRowDTO>();
    for (Sales_Operations_Associate_Assignment__c f : fresh) {
        MatrixRowDTO dto = new MatrixRowDTO();
        dto.id = f.Id;
        dto.salesAssociateId = f.Sales_Associate__c;
        dto.salesAssociateName = f.Sales_Associate__r != null ? f.Sales_Associate__r.Name : null;
        dto.salesAssociateIsActive = f.Sales_Associate__r != null ? f.Sales_Associate__r.IsActive : null;
        dto.salesOpsId = f.Sales_Operations_Associate__c;
        dto.salesOpsName = f.Sales_Operations_Associate__r != null ? f.Sales_Operations_Associate__r.Name : null;
        dto.isActive = f.Is_Active__c;
        dto.expiryDate = f.Expiry_Date__c;
        /* dto.pendingSalesOrders = (f.Sales_Operations_Associate__c != null && pendingByOps.containsKey(f.Sales_Operations_Associate__c))
            ? pendingByOps.get(f.Sales_Operations_Associate__c)
            : 0; */
        out.add(dto);
    }

    System.debug(LoggingLevel.WARN, '[SOAA][updateRows] returning dtos=' + out.size());
    return out;
}

@AuraEnabled
public static MatrixRowDTO updateRow(Id rowId, Id salesOpsId, Boolean isActive, Date expiryDate) {
    System.debug(LoggingLevel.WARN, '[SOAA][updateRow] input rowId=' + rowId + ' salesOpsId=' + salesOpsId + ' isActive=' + isActive + ' expiryDate=' + expiryDate);

    if (rowId == null) throw new AuraHandledException('Row Id is required.');
    if (salesOpsId == null) throw new AuraHandledException('Sales Operations User is required.');

    Sales_Operations_Associate_Assignment__c rec = [
        SELECT Id, Sales_Operations_Associate__c, Is_Active__c, Expiry_Date__c
        FROM Sales_Operations_Associate_Assignment__c
        WHERE Id = :rowId
        FOR UPDATE
    ];

    rec.Sales_Operations_Associate__c = salesOpsId;
    rec.Is_Active__c = (isActive == null ? rec.Is_Active__c : isActive);
    rec.Expiry_Date__c = expiryDate;
    update rec;

    Sales_Operations_Associate_Assignment__c fresh = [
        SELECT Id,
               Sales_Associate__c,
               Sales_Associate__r.Name,
               Sales_Associate__r.IsActive,
               Sales_Operations_Associate__c,
               Sales_Operations_Associate__r.Name,
               Is_Active__c,
               Expiry_Date__c
        FROM Sales_Operations_Associate_Assignment__c
        WHERE Id = :rowId
    ];

    Integer pending = 0;
    if (fresh.Sales_Operations_Associate__c != null) {
        List<AggregateResult> ars = [
            SELECT COUNT(Id) cnt
            FROM SalesOrder__c
            WHERE Sales_Operations_Associate__c = :fresh.Sales_Operations_Associate__c
              AND Sub_Status__c = 'Pending With Sales Operation'
              AND Status__c NOT IN ('Voided','Cancelled')
              AND Resale__c = FALSE
        ];
        if (!ars.isEmpty()) pending = (Integer)ars[0].get('cnt');
    }

    System.debug(LoggingLevel.WARN, '[SOAA][updateRow] post salesOpsId=' + fresh.Sales_Operations_Associate__c + ' isActive=' + fresh.Is_Active__c + ' expiryDate=' + fresh.Expiry_Date__c + ' pending=' + pending);

    MatrixRowDTO dto = new MatrixRowDTO();
    dto.id = fresh.Id;
    dto.salesAssociateId = fresh.Sales_Associate__c;
    dto.salesAssociateName = fresh.Sales_Associate__r != null ? fresh.Sales_Associate__r.Name : null;
    dto.salesAssociateIsActive = fresh.Sales_Associate__r != null ? fresh.Sales_Associate__r.IsActive : null;
    dto.salesOpsId = fresh.Sales_Operations_Associate__c;
    dto.salesOpsName = fresh.Sales_Operations_Associate__r != null ? fresh.Sales_Operations_Associate__r.Name : null;
    dto.isActive = fresh.Is_Active__c;
    dto.expiryDate = fresh.Expiry_Date__c;
/*     dto.pendingSalesOrders = pending;
 */    return dto;
}

    @AuraEnabled
    public static void deleteRow(Id rowId) {
        if (rowId == null) return;
        System.debug(LoggingLevel.WARN, '[SOAA][deleteRow] rowId=' + rowId);
        delete new Sales_Operations_Associate_Assignment__c(Id = rowId);
    }

    private static Map<String, Object> parseAccessLabel() {
        String raw = null;
        try {
            raw = System.Label.Operations_Assignment_Access;
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, '[SOAA][parseAccessLabel] label missing');
            return null;
        }

        if (String.isBlank(raw)) {
            System.debug(LoggingLevel.WARN, '[SOAA][parseAccessLabel] label blank => all access');
            return null;
        }

        try {
            Object o = JSON.deserializeUntyped(raw);
            if (o instanceof Map<String, Object>) {
                return (Map<String, Object>)o;
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, '[SOAA][parseAccessLabel] invalid json => all access. err=' + e.getMessage());
        }
        return null;
    }

    private static Map<String, Id> resolveEmailsToActiveUserIds(Map<String, Object> parsed) {
        Map<String, Id> out = new Map<String, Id>();
        if (parsed == null) return out;

        Set<String> emails = new Set<String>();
        collectEmails(parsed, emails);

        if (emails.isEmpty()) return out;

        for (User u : [
            SELECT Id, Email
            FROM User
            WHERE IsActive = true
              AND Email IN :emails
        ]) {
            if (!String.isBlank(u.Email)) out.put(u.Email, u.Id);
        }

        System.debug(LoggingLevel.WARN, '[SOAA][resolveEmailsToActiveUserIds] emails=' + emails.size() + ' matched=' + out.size());
        return out;
    }

    private static void collectEmails(Object node, Set<String> emails) {
        if (node == null) return;

        if (node instanceof Map<String, Object>) {
            Map<String, Object> m = (Map<String, Object>)node;
            for (Object v : m.values()) collectEmails(v, emails);
            return;
        }

        if (node instanceof List<Object>) {
            for (Object v : (List<Object>)node) collectEmails(v, emails);
            return;
        }

        if (node instanceof String) {
            String s = (String)node;
            if (s != null && s.contains('@')) emails.add(s);
        }
    }
}