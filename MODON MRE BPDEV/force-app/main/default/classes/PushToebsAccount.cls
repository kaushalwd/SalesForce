/**********************************************************************************************************************
 * Name               : PushToebsAccount
 * Description        : This class is helper for Repush all the account api to EBS
 * Usage              : Called from screen flows from Quick Action buttons
 * Created By         : Kumaravel 
 * --------------------------------------------------------------------------------------------------------------------
 * Version       Author                              Date            Comment
 * 1.0           Kumaravel                         12 Jan 2025       Initial Draft
******************************************************************************************************************/

public class PushToebsAccount {

    @InvocableMethod(label='Account OIC Callout' description='details page callout')
    public static void accountCalloutInvokeFromFlowDetailsPageAction(list<string> recordId) {
        set<string> recIds = new set<string>(recordId);
        sendAccountToOracle_Future(recIds);
    }
    
    @future(callout = true)
    public static void sendAccountToOracle_Future(set<string> recIds){
        OIC_ManageSalesforceDataController.createAccount(recIds);
    }    
}