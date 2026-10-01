@isTest
public class OIC_ManageSalesforceAllocatioDataSCHTest {
    
    @isTest static void test(){
        
        String CRON_EXP = '0 0 0 15 3 ? *';
        
        OIC_ManageSalesforceAllocationDataSCH t1= new OIC_ManageSalesforceAllocationDataSCH();
        System.schedule('TestClass',CRON_EXP, t1);
    }
}