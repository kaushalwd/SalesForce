@isTest
public class OIC_ManageSalesforceBusinAccDataSCHTest {
    
    @isTest static void test(){
        
        String CRON_EXP = '0 0 0 15 3 ? *';
        
        OIC_ManageSalesforceBusinessAccDataSCH t1= new OIC_ManageSalesforceBusinessAccDataSCH();
        System.schedule('TestClass',CRON_EXP, t1);
    }
}