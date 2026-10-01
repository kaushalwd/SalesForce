/**********************************************************************************************************************
 * Name               : PushToebsSO
 * Description        : This class is helper for Repush all the so api to EBS
 * Usage              : Called from screen flows from Quick Action buttons
 * Created By         : Kumaravel 
 * --------------------------------------------------------------------------------------------------------------------
 * Version       Author                              Date            Comment
 * 1.0           Kumaravel                         12 Jan 2025       Initial Draft
******************************************************************************************************************/

public class PushToebsSO {
    public PushToebsSO() {

    }

	// Sales orders
    @InvocableMethod(label='SO OIC Callout' description='details page callout')
    public static void soCalloutInvokeFromFlowDetailsPageAction(list<string> recordId) {
        set<string> recIds = new set<string>(recordId);
        sendSOToOracle_Future(recIds);
    }
    
    @future(callout = true)
    public static void sendSOToOracle_Future(set<string> recIds){
        OIC_ManageSalesforceDataController.createSalesOrderAndSOInstallments(recIds);
    }
        
}