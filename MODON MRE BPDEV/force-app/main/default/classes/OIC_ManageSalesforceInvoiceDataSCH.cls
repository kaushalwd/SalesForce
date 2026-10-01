global class OIC_ManageSalesforceInvoiceDataSCH implements Schedulable{
    
    global void execute(SchedulableContext sc) 
    {        
        OIC_Query_Parameters__mdt oicParams = OIC_Query_Parameters__mdt.getInstance('BatchScope_SendInvoiceToOracle');
        String scopeStr = oicParams.Value__c;
        Database.executeBatch(new OIC_ManageSalesforceInvoiceDataBatch(), Integer.valueOf(scopeStr));
    }    
}