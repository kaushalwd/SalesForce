global class OIC_ManageSalesforcePersonAccDataSCH implements Schedulable{
    
    global void execute(SchedulableContext sc) 
    {        
        OIC_Query_Parameters__mdt oicParams = OIC_Query_Parameters__mdt.getInstance('BatchScope_SendPersonAccountToOracle');
        String scopeStr = oicParams.Value__c;
        Database.executeBatch(new OIC_ManageSalesforcePersonAccDataBatch(), Integer.valueOf(scopeStr));
    }    
}