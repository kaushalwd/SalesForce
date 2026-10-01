global class OIC_ManageSalesforceSalesOrderDataSCH implements Schedulable{
    
    global void execute(SchedulableContext sc) 
    {        
        OIC_Query_Parameters__mdt oicParams = OIC_Query_Parameters__mdt.getInstance('BatchScope_SendSalesOrdersToOracle');
        String scopeStr = oicParams.Value__c;
        Database.executeBatch(new OIC_ManageSalesforceSalesOrderDataBatch(), Integer.valueOf(scopeStr));
    }    
}