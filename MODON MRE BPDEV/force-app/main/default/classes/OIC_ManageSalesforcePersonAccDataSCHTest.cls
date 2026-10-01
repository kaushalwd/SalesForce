@isTest
public class OIC_ManageSalesforcePersonAccDataSCHTest {
    
    @isTest static void test(){
        
        String CRON_EXP = '0 0 0 15 3 ? *';
        
        OIC_ManageSalesforcePersonAccDataSCH t1= new OIC_ManageSalesforcePersonAccDataSCH();
        System.schedule('TestClass',CRON_EXP, t1);
    }
}