/**
 * @description       : This is Update legacy Sales Orders which are in Completed status to recalculate the amounts
 * @author            : Krishna Chaitanya
 * @group             : AMGS
 * @last modified on  : 12-08-2025
 * @last modified by  : Krishna Chaitanya
**/
public with sharing class SalesOrderCompletedRecalcBatch 
    implements Database.Batchable<SObject>, Database.Stateful {

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id
            FROM SalesOrder__c
            WHERE Status__c = 'Completed'
        ]);
    }

    public void execute(Database.BatchableContext bc, List<SalesOrder__c> scope) {
        Set<Id> soIds = new Set<Id>();
        for (SalesOrder__c so : scope) {
            soIds.add(so.Id);
        }

        if (!soIds.isEmpty()) {
            SalesOrderCollectionsServiceController.recalcForSalesOrders(soIds);
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug('Completed recalculation for completed SalesOrders.');
    }
}