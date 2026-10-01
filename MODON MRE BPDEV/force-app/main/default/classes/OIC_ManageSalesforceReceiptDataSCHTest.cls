@isTest
public class OIC_ManageSalesforceReceiptDataSCHTest {
    
    @isTest static void test(){
        
        String CRON_EXP = '0 0 0 15 3 ? *';
        
        OIC_ManageSalesforceReceiptDataSCH t1= new OIC_ManageSalesforceReceiptDataSCH();
        System.schedule('TestClass',CRON_EXP, t1);
    }
}