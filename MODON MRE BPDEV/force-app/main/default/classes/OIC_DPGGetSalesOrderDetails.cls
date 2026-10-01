/**********************************************************************************************************************
* Name        : OIC_DPGGetSalesOrderDetails
* Description : Returns the status fields of a Sales Order, with the currency of its parent Project.
* Usage       : POST /services/apexrest/dpg/getSalesOrderDetails/
* --------------------------------------------------------------------------------------------------------------------
* Version   Author   Date           Comment
* 1.0       -        -              Initial.
* 2.0       Arvind   10 Jul 2026    Response handling delegated to OIC_RestResponse. Error paths now write a body.
*                                     Unknown / malformed salesOrderId returns 404 / 400 instead of 500.
*                                     CurrencyIsoCode sourced from Unit__r.Phase__r.Project__r.CurrencyIsoCode.
* 2.1       Jay Patel  18 Sep 2026    MCR-73 — USER_MODE SOQL, createApexLog
***********************************************************************************************************************/
@RestResource(urlMapping='/dpg/getSalesOrderDetails/*')
global with sharing class OIC_DPGGetSalesOrderDetails {

    private static final String DEFAULT_CURRENCY = 'AED';

    /* ====================================================================================
     *  ERROR CODES  (USR-001 / USR-002 / USR-004 already live in the shared registry)
     * ==================================================================================== */
    static {
        OIC_RestResponse.define('SOD-001', 400, 'salesOrderId is not a valid Salesforce Id.');
        OIC_RestResponse.define('SOD-999', 500, 'An unexpected error occurred.');
    }

    private static final String ERR_INVALID_ID = 'SOD-001';
    private static final String ERR_UNEXPECTED = 'SOD-999';

    /* ====================================================================================
     *  REST ENTRY POINT
     * ==================================================================================== */
    @HttpPost
    global static void getSalesOrderDetails() {
        try {
            RestRequest req = RestContext.request;

            if (req == null || req.requestBody == null || req.requestBody.size() == 0) {
                OIC_RestResponse.failure(OIC_RestResponse.INVALID_REQUEST_BODY).send();
                return;
            }

            Map<String, Object> input =
                (Map<String, Object>) JSON.deserializeUntyped(req.requestBody.toString());

            String salesOrderId = (String) input.get('salesOrderId');

            if (String.isBlank(salesOrderId)) {
                OIC_RestResponse.failure(
                    OIC_RestResponse.MISSING_REQUIRED_FIELD, 'salesOrderId is mandatory.'
                ).send();
                return;
            }

            // A malformed Id is the caller's fault -- a clean 400, not a 500.
            try {
                Id.valueOf(salesOrderId.trim());
            } catch (System.StringException se) {
                OIC_RestResponse.failure(ERR_INVALID_ID,
                    'Invalid salesOrderId: "' + salesOrderId + '" is not a valid Salesforce Id.').send();
                return;
            }

            //2.1 MCR-73: Enforce CRUD/FLS via USER_MODE on SalesOrder__c query
            List<SalesOrder__c> salesOrders = [SELECT 
                                               Id, 
                                               Name,  
                                               Down_Payment_Status__c,
                                               CustomerAccount__c,
                                               Opportunity__c,
                                               Status__c,
                                               UAE_Resident_Status__c,
                                               Unit_Allocated_Status__c, 
                                               Unit_Status__c,
                                               Unit__c,
                                               Unit__r.Phase__c,
                                               Unit__r.Phase__r.Project__c,
                                               Unit__r.Phase__r.Project__r.CurrencyIsoCode
                                               FROM SalesOrder__c
                                               WHERE Id = :salesOrderId
                                               WITH USER_MODE
                                               LIMIT 1];

            if (salesOrders.isEmpty()) {
                OIC_RestResponse.failure(
                    OIC_RestResponse.RECORD_NOT_FOUND, 'No Sales Order found for Id ' + salesOrderId
                ).send();
                return;
            }
            
            SalesOrder__c salesOrder = salesOrders[0];
            
            OIC_RestResponse.success()
                .put('Id',                       salesOrder.Id)
                .put('Name',                     salesOrder.Name)
                .put('DownPaymentStatus',   salesOrder.Down_Payment_Status__c)
                .put('CustomerAccount',       salesOrder.CustomerAccount__c)
                .put('Opportunity',           salesOrder.Opportunity__c)
                .put('Status',                salesOrder.Status__c)
                .put('UAEResidentStatus',   salesOrder.UAE_Resident_Status__c)
                .put('UnitAllocatedStatus', salesOrder.Unit_Allocated_Status__c)
                .put('UnitStatus',           salesOrder.Unit_Status__c)
                .put('Unit',                  salesOrder.Unit__c)
                .put('Phase',                 salesOrder.Unit__r.Phase__c)
                .put('Project',               salesOrder.Unit__r.Phase__r.Project__c)
                .put('CurrencyIsoCode',          resolveProjectCurrency(salesOrder))
                .flat()
                .send();

        } catch (Exception ex) {
            //2.1 MCR-73: Log unexpected failures via LoggerService.createApexLog
            LoggerService.save(LoggerService.createApexLog(
                ex,
                'DPG Get Sales Order Details API',
                'OIC_DPGGetSalesOrderDetails',
                'getSalesOrderDetails'
            ));
            OIC_RestResponse.fromException(ex, ERR_UNEXPECTED).send();
        }
    }

    /**
     * Walks SalesOrder -> Unit -> Phase -> Project for the currency.
     * Any of the three lookups may be null, and a null parent makes the whole chain null --
     * dereferencing it directly would throw. Falls back to AED when the chain is broken.
     */
    private static String resolveProjectCurrency(SalesOrder__c so) {
        if (so.Unit__c == null || so.Unit__r == null)                       return DEFAULT_CURRENCY;
        if (so.Unit__r.Phase__c == null || so.Unit__r.Phase__r == null)     return DEFAULT_CURRENCY;
        if (so.Unit__r.Phase__r.Project__c == null
            || so.Unit__r.Phase__r.Project__r == null)                      return DEFAULT_CURRENCY;

        String isoCode = so.Unit__r.Phase__r.Project__r.CurrencyIsoCode;
        return String.isNotBlank(isoCode) ? isoCode : DEFAULT_CURRENCY;
    }
}