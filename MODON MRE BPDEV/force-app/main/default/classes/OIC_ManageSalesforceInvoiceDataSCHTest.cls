@isTest
public class OIC_ManageSalesforceInvoiceDataSCHTest {
    
    @isTest static void test(){
        
        String CRON_EXP = '0 0 0 15 3 ? *';
        
        OIC_ManageSalesforceInvoiceDataSCH t1= new OIC_ManageSalesforceInvoiceDataSCH();
        System.schedule('TestClass',CRON_EXP, t1);
    }
}