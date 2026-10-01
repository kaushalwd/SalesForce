global class OIC_ManageSalesforceReceiptDataSCH implements Schedulable{
    
    global void execute(SchedulableContext sc) 
    {        
        OIC_Query_Parameters__mdt oicParams = OIC_Query_Parameters__mdt.getInstance('BatchScope_SendReceiptsToOracle');
        String scopeStr = oicParams.Value__c;
        Database.executeBatch(new OIC_ManageSalesforceReceiptDataBatch(), Integer.valueOf(scopeStr));
    }    
}