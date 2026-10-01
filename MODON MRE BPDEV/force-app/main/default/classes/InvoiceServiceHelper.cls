public class InvoiceServiceHelper {
    
    @future(callout = true)
    public static void sendInvoiceToOracle_Future(set<string> recIds){
        OIC_ManageSalesforceDataController.createInstallment(recIds);
    }

}