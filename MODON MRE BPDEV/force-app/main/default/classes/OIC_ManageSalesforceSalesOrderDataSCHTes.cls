@isTest
public class OIC_ManageSalesforceSalesOrderDataSCHTes {
    
    @isTest static void test(){
        
        String CRON_EXP = '0 0 0 15 3 ? *';
        
        OIC_ManageSalesforceSalesOrderDataSCH t1= new OIC_ManageSalesforceSalesOrderDataSCH();
        System.schedule('TestClass',CRON_EXP, t1);
    }
}