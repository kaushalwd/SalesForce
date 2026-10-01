/**********************************************************************************************************************
* Name               : ModonEgypt_SalesOrderAPI
* Description        : REST API to expose Modon Egypt Sales Order data to Sakneen. Returns Sales Orders where Source_Entity__c = 'Modon - Egypt'.
* Usage              : Called as REST API endpoint (/SalesOrderAPI/*) via HTTP GET method
* Created By         : Shahil Sinha (Horizontal)
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment
* 1.0           Shahil Sinha (Horizontal)        11 Dec 2025     Initial Version
* 1.1           Gautam Mishra (Horizontal)       26 Dec 2025     Changed lookup from Name to Id parameter, renamed Id 
*                                                                to SalesOrderId in response, added OwnerEmail field.
* 1.2           Shahil Sinha (Horizontal)        19 Jan 2026     Bulkified API - accepts optional JSON body with Sales Order IDs,
*                                                                returns all Egypt Sales Orders if no filter provided.
* 1.3           Shahil Sinha (Horizontal)        23 Jan 2026     Refactored to use dynamic SOQL query and set limit to return 50k records max.
**********************************************************************************************************************/
@RestResource(urlMapping='/SalesOrderAPI/*')
global with sharing class ModonEgypt_SalesOrderAPI {

    //v1.2 (line 19 - 94)
    // ----------- CONSTANTS -----------
    private static final String SOURCE_ENTITY_EGYPT = 'Modon - Egypt';
    private static final Integer QUERY_LIMIT = 50000;
    
    // ----------- INPUT WRAPPER -----------
    global class SalesOrderInput {
        public String salesOrderRecordId;
    }

    // ----------- OUTPUT WRAPPER -----------
    global class SalesOrderResponse {
        public Id SalesOrderId;
        public String Status;
        public Id UnitId;
        public String UnitName;
        public Id OwnerId;
        public String OwnerName;
        public String OwnerEmail;
    }

    @HttpGet
    global static List<SalesOrderResponse> getSalesOrders() {
        RestRequest req = RestContext.request;
        String body = req.requestBody?.toString();

        Set<String> salesOrderIds = new Set<String>();
        
        if (String.isNotBlank(body)) {
            try { 
                List<SalesOrderInput> inputList = (List<SalesOrderInput>) JSON.deserialize(body, List<SalesOrderInput>.class);
                for (SalesOrderInput item : inputList) {
                    if (String.isNotBlank(item.salesOrderRecordId)) {
                        salesOrderIds.add(item.salesOrderRecordId);
                    }
                }
            } catch (Exception ex) {
                // Do nothing - all Sales Orders will be returned
            }
        }

        //v1.3 (line 59 - 72) Build dynamic query
        String query = 'SELECT Id, Name, Status__c, Unit__c, Unit__r.Name, OwnerId, Owner.Name, Owner.Email, ' +
                       'CustomerAccount__c, CustomerAccount__r.Name, TotalAmount__c, Booking_Date__c ' +
                       'FROM SalesOrder__c ' +
                       'WHERE Source_Entity__c = :SOURCE_ENTITY_EGYPT';
        
        // Add ID filter if specific IDs are provided
        if (!salesOrderIds.isEmpty()) {
            query += ' AND Id IN :salesOrderIds';
        }
        
        query += ' ORDER BY Id ASC Limit :QUERY_LIMIT';

        // Execute dynamic query
        List<SalesOrder__c> salesOrders = Database.query(query);

        // Build response
        List<SalesOrderResponse> responseList = new List<SalesOrderResponse>();

        for (SalesOrder__c so : salesOrders) {
            SalesOrderResponse res = new SalesOrderResponse();

            res.SalesOrderId = so.Id;
            res.Status = so.Status__c;
            res.UnitId = so.Unit__c;
            res.UnitName = so.Unit__r.Name;
            res.OwnerId = so.OwnerId;
            res.OwnerName = so.Owner.Name;
            res.OwnerEmail = so.Owner.Email;

            responseList.add(res);
        }

        return responseList;
    }
}