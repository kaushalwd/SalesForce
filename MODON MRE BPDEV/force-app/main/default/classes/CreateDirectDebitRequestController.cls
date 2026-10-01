/**********************************************************************************************************************
* Name               : CreateDirectDebitRequestController
* Description        : Controller for the FAB direct debit capture screen. Reads the Sales Order and its customer for
*                      the form, and refuses when the Sales Order already carries a live mandate.
* Usage              : Called from the createDirectDebitRequest LWC
* Created By         : Admin ActiveMinds
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment
* 1.0           Admin ActiveMinds           16-06-2025      Initial version. Header written 26-08-2026; the history
*                                                           before that date was never recorded.
* 1.1           Prateek Bansal              26-08-2026      Discarded exempted from the one mandate per Sales Order check
******************************************************************************************************************/
public with sharing class CreateDirectDebitRequestController {

    @AuraEnabled
    public static void createDirectDebitRequest(String directDebitRequestMsg) {
        
    }
	@AuraEnabled(cacheable=true)
	public static ResponseWrapper getSalesOrderAccDetails(Id salesOrderId){
        System.debug('CreateDirectDebitRequestController >>>>  '+salesOrderId);
		ResponseWrapper obj_ResponseWrapper = new ResponseWrapper();
        obj_ResponseWrapper.salesOrderRecord = getSalesOrderDetailsForDDS(salesOrderId);
        System.debug('CreateDirectDebitRequestController >>>>  '+System.JSON.serialize(obj_ResponseWrapper));
		return 	obj_ResponseWrapper;
	}
    
    @AuraEnabled
    public static SalesOrder__c getSalesOrderDetailsForDDS(Id salesOrderId){
        Boolean isNewDDReg = validateDirectDebitRequestUniqueValidation(salesOrderId);
       if(!isNewDDReg){
            SalesOrder__c obj_SalesOrder = new SalesOrder__c();
            List<SalesOrder__c> lst_SalesOrder =  [select Id, CustomerAccount__c, Name, CustomerAccount__r.IsPersonAccount,
                                                   CustomerAccount__r.FirstName, CustomerAccount__r.MiddleName, CustomerAccount__r.LastName,
                                                   CustomerAccount__r.Name, CustomerAccount__r.UAEVATRegisterNumber__c,
                                                   CustomerAccount__r.EIDNumber__pc, CustomerAccount__r.PersonMobilePhone,CustomerAccount__r.TradeName__c,CustomerAccount__r.TradeLicenseNumber__c FROM SalesOrder__c 
                                                   where Id = :salesOrderId]; 
            if(lst_SalesOrder.size() > 0){
                obj_SalesOrder = lst_SalesOrder.get(0);
            }
            return obj_SalesOrder;
       }
       return null;
    }
    public static boolean validateDirectDebitRequestUniqueValidation(Id SalesOrderId){
      if(SalesOrderId <> null){
            for(DirectDebitRequest__c dd:[SELECT Id,SalesOrder__c FROM DirectDebitRequest__c WHERE SalesOrder__c =: SalesOrderId AND ( NOT Status__c IN ('Cancelled','Rejected By Bank','Discarded'))]){
              return true;
            }
        }
        return false;
    }
    public class ResponseWrapper{
        @AuraEnabled
        public SalesOrder__c salesOrderRecord;
    }
    
}