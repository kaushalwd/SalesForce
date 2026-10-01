/**********************************************************************************************************************
* Name               : SalesOrderCMAAssignController                                                        
* Description        : This class is used as a helper for salesOrderCMAAssign, to assign CM Associates to sales orders.
* Created By         : ActiveMinds                                                
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                               
* 1.0           Fatima Khan                         9 Apr 2026     Initial Draft 
* 2.0           Dselvam                             28 Apr 2026    Excluded the "Cancelled" Sales Order
******************************************************************************************************************/
public with sharing class SalesOrderCMAAssignController {
    /* 1.0: Fetches Sales Orders (rows) plus distinct pick-list/filter values, honoring scope (“Assigned/Unassigned”) and an optional search key.*/
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getSalesOrders(
        String scopeFilter,
        String searchKey
    ) {

        final String TAG = '[SalesOrderCMAAssignController.getSalesOrders] ';
        System.debug(TAG + 'START  scope=' + scopeFilter + '  search=' + searchKey);

        Map<String, Object> cfg =
            (Map<String, Object>) JSON.deserializeUntyped(System.Label.SO_CM_Associate_Fields);

        List<Object> rawCols    = (List<Object>) cfg.get('Columns');
        List<Object> rawFilters = (List<Object>) cfg.get('Filters');

        /* SELECT */
        Set<String> selectSet = new Set<String>{ 'Id' };
        for (Object o : rawCols) {
            String path = (String)((Map<String,Object>)o).get('field');
            selectSet.add(path);
            if (path.contains('.')) selectSet.add(path.substring(0, path.indexOf('.')).replace('__r','__c'));
        }
        for (Object o : rawFilters)
            selectSet.add((String)((Map<String,Object>)o).get('field'));
        System.debug(TAG + 'SELECT  ' + selectSet);
        String PENDING_WITH_CM = Constants.PENDING_WITH_CM;
        List<String> cancellStatus = System.label.CommissionCancelStatus.contains(',')?System.label.CommissionCancelStatus.split(','):new List<String>{System.label.CommissionCancelStatus};
        String whereClause = 'Sub_Status__c =:PENDING_WITH_CM AND (NOT(Status__c IN: cancellStatus))';
        if (scopeFilter == 'Unassigned') whereClause += ' AND Customer_Management_Associate__c = NULL';
        if (scopeFilter == 'Assigned')   whereClause += ' AND Customer_Management_Associate__c != NULL';

        String searchKeyLike = String.isBlank(searchKey) ? null : '%' + searchKey + '%';
        if (!String.isBlank(searchKey)) {
            List<String> likes = new List<String>();
            for (Object o : rawCols) {
                String f = (String)((Map<String,Object>)o).get('field');
                if (!f.contains('.'))
                    likes.add(f + ' LIKE :searchKeyLike');
            }
            if (!likes.isEmpty()) whereClause += ' AND (' + String.join(likes, ' OR ') + ')';
        }
        System.debug(TAG + 'WHERE  ' + whereClause);

        String soql = 'SELECT ' + String.join(new List<String>(selectSet), ',') +
                      ' FROM SalesOrder__c WHERE ' + whereClause + ' LIMIT 2000';
        System.debug(TAG + 'SOQL   ' + soql);

        Map<String, Object> binds = new Map<String, Object>{
            'PENDING_WITH_CM' => PENDING_WITH_CM,
            'cancellStatus' => cancellStatus
        };
        if (!String.isBlank(searchKey)) {
            binds.put('searchKeyLike', searchKeyLike);
        }

        List<SalesOrder__c> rows = Database.queryWithBinds(soql, binds, AccessLevel.SYSTEM_MODE);
        System.debug(TAG + 'rows=' + rows.size());

        
        Map<String, Set<String>> filterVals = new Map<String, Set<String>>();
        for (Object o : rawFilters)
            filterVals.put((String)((Map<String,Object>)o).get('field'), new Set<String>());

        for (SalesOrder__c so : rows) {
            for (String api : filterVals.keySet()) {
                Object v;
                if (api.contains('.')) {
                    List<String> p = api.split('\\.');
                    SObject rel   = so.getSObject(p[0]);
                    v             = rel != null ? rel.get(p[1]) : null;
                } else {
                    v = so.get(api);
                }
                if (v != null) filterVals.get(api).add(String.valueOf(v));
            }
        }
        System.debug(TAG + 'filterVals=' + filterVals);
        System.debug(TAG + 'END');

        return new Map<String, Object>{
            'rows'         => rows,
            'filterValues' => filterVals
        };
    }

    /*1.0 Bulk-assigns a Customer-Management Associate to the specified Sales Orders, skipping or overriding existing assignments per flag. */
    @AuraEnabled
    public static void assignCMAssociate(
        List<Id> orderIds,
        Id       associateId,
        Boolean  overrideExisting
    ) {

        final String TAG = '[SalesOrderCMAAssignController.assignCMAssociate] ';
        System.debug(TAG + 'START  orders=' + orderIds +
                      '  associate=' + associateId +
                      '  override=' + overrideExisting);

        if (orderIds.isEmpty()) {
            System.debug(TAG + 'no orderIds, EXIT');
            return;
        }

        Map<Id, SalesOrder__c> existing = new Map<Id, SalesOrder__c>(
            [SELECT Id, Customer_Management_Associate__c
             FROM   SalesOrder__c
             WHERE  Id IN :orderIds]);

        List<SalesOrder__c> updates = new List<SalesOrder__c>();
        for (Id soId : orderIds) {
            SalesOrder__c rec = existing.get(soId);
            if (!overrideExisting && rec.Customer_Management_Associate__c != null) {
                System.debug(TAG + 'skip ' + soId + ' (already set)');
                continue;
            }
            updates.add(new SalesOrder__c(
                Id = soId,
                Customer_Management_Associate__c = associateId
            ));
        }

        if (!updates.isEmpty()) {
            update updates;
            System.debug(TAG + 'updated=' + updates.size());
        } else {
            System.debug(TAG + 'no rows updated');
        }
        System.debug(TAG + 'END');
    }
}