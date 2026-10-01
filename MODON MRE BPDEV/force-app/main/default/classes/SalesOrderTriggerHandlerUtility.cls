/**********************************************************************************************************************
* Name               : SalesOrderTriggerHandlerUtility
* Description        : This utility class publishes Platform Events (SalesOrderEvent__e) to sync unit data from Salesforce 
*                      to external systems (Sakneen) for Egypt sales process. Handles event publishing, 
*                      status updates, and integration logging.
* Usage              : Called from SalesOrderTriggerHandler
* Created By         : Shahil Sinha (Horizontal)
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment  
* 1.0           Shahil Sinha (Horizontal)        30 Dec 2025        Initial Draft
* 1.1           Shahil Sinha (Horizontal)        23 Jan 2026        Added functional level comments
* 1.2           Shahil Sinha (Horizontal)        06 Feb 2026        Added flag to simulate testing failures
**********************************************************************************************************************/

public with sharing class SalesOrderTriggerHandlerUtility {
    
    //v1.2 (line 18) Flag to simulate EventBus.publish failure in test context for code coverage
    @TestVisible private static Boolean simulatePublishFailure = false;
    
    //Publishes Sales Order data to Sakneen via Platform Events
    public static void publishSalesOrdersToSakneen(List<SalesOrder__c> salesOrders , String OperationType) {
        List<SalesOrderEvent__e> events = new List<SalesOrderEvent__e>();
        List<Logger__c> logsToInsert = new List<Logger__c>();
        if(OperationType != 'DELETE') {
            List<SalesOrder__c> salesOrderToUpdate = new List<SalesOrder__c>();
            
            //Fetch owner details for event payload
            Set<Id> ownerIds = new Set<Id>();
            for (SalesOrder__c so : salesOrders) {
                ownerIds.add(so.OwnerId);
            }
            
            Map<Id, User> userMap = new Map<Id, User>([SELECT Id, Name, Email FROM User WHERE Id IN :ownerIds]);

            //Build Platform event for each sales order
            for (SalesOrder__c salesOrder : salesOrders) {
               events.add(mapSalesOrdersToSakneenPayload(salesOrder, OperationType, userMap));
            }

            if (!events.isEmpty()) {
                List<Database.SaveResult> results = EventBus.publish(events);

                for (Integer i = 0; i < results.size(); i++) {
                     //v1.2 (line 45) Flag to simulate EventBus.publish failure in test context for code coverage
                    if (results[i].isSuccess() && !simulatePublishFailure) {
                        // Mark the Sakneen_Status__c Success if the event was published successfully
                        SalesOrder__c updatedSalesOrder = new SalesOrder__c(
                            Id = salesOrders[i].Id,
                            Sakneen_Status__c = 'Success'
                        );
                        salesOrderToUpdate.add(updatedSalesOrder);
                    } else {
                        // Mark the Sakneen_Status__c Failure if the event was published failed
                        SalesOrder__c updatedSalesOrder = new SalesOrder__c(
                            Id = salesOrders[i].Id,
                            Sakneen_Status__c = 'Failure'
                        );
                        salesOrderToUpdate.add(updatedSalesOrder);

                        //Capture logs when failure
                        String processName = 'Sakneen - SalesOrderSync';
                        String className   = 'Modon_Egypt_SakneenIntegration';
                        String methodName  = 'publishSalesOrdersToSakneen';
                        String requestBody = JSON.serialize(events);
                        String responseBody= JSON.serialize(results);
                        String statusCode  = getStatusCode(results);
                        String logType     = 'Integration';
                        
                        Logger__c logEntry = LoggerService.createAPILog(
                            processName,
                            className,
                            methodName,
                            requestBody,
                            responseBody,
                            statusCode,
                            logType
                        );
                        
                        logsToInsert.add(logEntry);
                    }
                }

                //Update sales orders with sync status
                if (!salesOrderToUpdate.isEmpty()) {
                    try {
                        update salesOrderToUpdate;
                    } catch (DmlException ex) {
                        System.debug('Error updating Sakneen_Status__c: ' + ex.getMessage());
                    }
                }

                //Insert failure logs
                if (!logsToInsert.isEmpty()) {
                    try {
                        insert logsToInsert;
                    } catch (DmlException ex) {
                        System.debug('Error inserting failure logs: ' + ex.getMessage());
                    }
                }
            }
        }
    }

    // Maps Sales Order fields to Platform Event payload for Sakneen
    private static SalesOrderEvent__e mapSalesOrdersToSakneenPayload(SalesOrder__c salesOrder , String OperationType, Map<Id, User> userMap) {
        User ownerUser = userMap.get(salesOrder.OwnerId);
        
        return new SalesOrderEvent__e(
            SalesOrderId__c = salesOrder.Id,
            Status__c = salesOrder.Status__c,
            UnitId__c = salesOrder.Unit__c,
            Unit_Name__c = salesOrder.Unit_Name__c,
            OwnerId__c = salesOrder.OwnerId,
            Owner_Email__c = ownerUser != null ? ownerUser.Email : null,
            Owner_Name__c = ownerUser != null ? ownerUser.Name : null,
            Operation_Type__c = OperationType
        );
    }

    private static String getStatusCode(List<Database.SaveResult> results) {
        for (Database.SaveResult r : results) {
            if (!r.isSuccess()) {
                return 'ERROR';
            }
        }
        return 'SUCCESS';
    }
    
    // Filter SalesOrders applicable for Sakneen sync
    public static List<SalesOrder__c> filterSalesOrderForSakneenSync(List<SalesOrder__c> modonEgyptSalesOrders, Map<ID, SObject> newMap, Map<ID, SObject> oldMap) {
        List<SalesOrder__c> modonEgyptSalesOrdersForSakneen = new List<SalesOrder__c>();
        for (SalesOrder__c record : modonEgyptSalesOrders) {
            SalesOrder__c newSalesOrder = (SalesOrder__c) newMap.get(record.Id);
            SalesOrder__c oldSalesOrder = (SalesOrder__c) oldMap.get(record.Id);

            if (hasTrackedFieldChanged(newSalesOrder, oldSalesOrder)) {
                modonEgyptSalesOrdersForSakneen.add(newSalesOrder);
            } 
        }
        return modonEgyptSalesOrdersForSakneen;
    }

    
    
    // Helper to check tracked field changes (aligned with Sakneen payload fields)
    private static Boolean hasTrackedFieldChanged(SalesOrder__c newSalesOrder, SalesOrder__c oldSalesOrder) {
        return newSalesOrder.Status__c != oldSalesOrder.Status__c ||
            newSalesOrder.Unit__c != oldSalesOrder.Unit__c ||
            newSalesOrder.OwnerId != oldSalesOrder.OwnerId;
    }

}