global class OIC_ManageSalesforceBusinessAccDataSCH implements Schedulable{
    
    global void execute(SchedulableContext sc) 
    {        
        OIC_Query_Parameters__mdt oicParams = OIC_Query_Parameters__mdt.getInstance('BatchScope_SendBusinessAccountToOracle');
        String scopeStr = oicParams.Value__c;
        Database.executeBatch(new OIC_ManageSalesforceBusinessAccDataBatch(), Integer.valueOf(scopeStr));
    }    
}