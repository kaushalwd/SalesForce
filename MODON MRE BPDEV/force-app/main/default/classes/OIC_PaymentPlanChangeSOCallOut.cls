/**
 * @description Invocable action to create Sales Orders and SO Installments.
 *
 * @author      Modon IT
 * @created     02-08-2026
 * @V1.0		Modon IT 		Initial version
 ************************************************************************************/
public without sharing class OIC_PaymentPlanChangeSOCallOut {

    public class Request {

        @InvocableVariable(
            required=true
            label='SalesOrder Id'
            description='Sales Order Id to process'
        )
        public Id recordId;
    }

    @InvocableMethod(
        label='Callout Sales Order and SOI on Payment plan change'
        description='Calls OIC_ManageSalesforceDataController to create Sales Orders and SO Installments.'
    )
    public static void createSalesOrders(List<Request> requests) {

        Set<String> recordIds = new Set<String>();

        for (Request req : requests) {
            if (req != null && req.recordId != null) {
                recordIds.add(req.recordId);
            }
        }

        if (!recordIds.isEmpty()) {
            System.enqueueJob(new SalesOrderCallout_Queable(recordIds));
        }
    }
}