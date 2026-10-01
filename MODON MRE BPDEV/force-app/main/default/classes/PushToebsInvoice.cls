/**********************************************************************************************************************
 * Name               : PushToebsInvoice
 * Description        : This class is helper for Repush all the invoice api to EBS
 * Usage              : Called from screen flows from Quick Action buttons
 * Created By         : Kumaravel 
 * --------------------------------------------------------------------------------------------------------------------
 * Version       Author                              Date            Comment
 * 1.0           Kumaravel                         12 Jan 2025       Initial Draft
******************************************************************************************************************/

public class PushToebsInvoice {
    public PushToebsInvoice() {

    }
	// Invoice
    @InvocableMethod(label='Invoice OIC Callout' description='details page callout')
    public static void invoiceCalloutInvokeFromFlowDetailsPageAction(list<string> recordId) {
        set<string> recIds = new set<string>(recordId);
        sendInvoiceToOracle_Future(recIds);
    }
    
    @future(callout = true)
    public static void sendInvoiceToOracle_Future(set<string> recIds){
        OIC_ManageSalesforceDataController.createInstallment(recIds);
    }

}