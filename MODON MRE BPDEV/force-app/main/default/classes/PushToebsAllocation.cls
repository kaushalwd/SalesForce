/**********************************************************************************************************************
 * Name               : PushToebsAllocation
 * Description        : This class is helper for Repush all the allocation api to EBS
 * Usage              : Called from screen flows from Quick Action buttons
 * Created By         : Kumaravel 
 * --------------------------------------------------------------------------------------------------------------------
 * Version       Author                              Date            Comment
 * 1.0           Kumaravel                         12 Jan 2025       Initial Draft
******************************************************************************************************************/


public class PushToebsAllocation {

    @InvocableMethod(label='Allocation OIC Callout' description='details page callout')
    public static void allocationCalloutInvokeFromFlowDetailsPageAction(list<string> recordId) {
        set<string> recIds = new set<string>(recordId);
        sendAllocationToOracle_Future(recIds);
    }
    
    @future(callout = true)
    public static void sendAllocationToOracle_Future(set<string> recIds){
        OIC_ManageSalesforceDataController.createAllocation(recIds);
    }    
}