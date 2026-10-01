global class OIC_ManageSalesforceAllocationDataSCH implements Schedulable{
    
    global void execute(SchedulableContext sc) 
    {        
        OIC_Query_Parameters__mdt oicParams = OIC_Query_Parameters__mdt.getInstance('BatchScope_SendAllocationsToOracle');
        String scopeStr = oicParams.Value__c;
        Database.executeBatch(new OIC_ManageSalesforceAllocationDataBatch(), Integer.valueOf(scopeStr));
    }    
}