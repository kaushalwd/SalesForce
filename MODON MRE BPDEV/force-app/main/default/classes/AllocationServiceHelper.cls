public class AllocationServiceHelper {
  
    @future(callout = true)
    public static void sendAllocationToOracle_Future(set<string> recIds){
        OIC_ManageSalesforceDataController.createAllocation(recIds);
    }

}