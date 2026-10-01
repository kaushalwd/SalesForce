/**********************************************************************************************************************
* Name               : ManageReceiptAllocationController                                                        
* Description        : This class is used as controller for LWC (Manage receipt allocation action button on account)
* Usage              : manageReceiptAllocation LWC                                                          
* Created By         : PWC Digital Middle East                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                          Date            Comment                                                                       
* 1.0           prateek.b.bansal@pwc.com     25 Jan 2024      Initial Draft       
******************************************************************************************************************/
public with sharing class ManageReceiptAllocationController {

    //Method to get open receipts
    @AuraEnabled
    public static ResponseWrapper getAvailableReceiptsInvoices(Id recordId){
        ResponseWrapper respWrap = new ResponseWrapper();
        String objectType = recordId.getsobjecttype().getDescribe().getName();
        if(objectType == 'Account'){
        }else if(objectType == 'SalesOrder__c'){
            String accId = [SELECT Id, CustomerAccount__c FROM SalesOrder__c WHERE Id = :recordId LIMIT 1].CustomerAccount__c;
            recordId = accId;
        }else{
            respWrap.isSuccess = false;respWrap.errorMsg = 'This functionality is available for account and sales order object.';respWrap.messageVariant = 'Error';return respWrap;
        }
        Map<String, Receipt__c> recMap = getOpenReceipts(recordId);
        Map<String, Invoice__c> invMap = getOpenInvoices(recordId);
        List<Map<String,String>> invNameMap = getInvNameMap(invMap);
        List<Map<String,String>> recNameMap = getRecNameMap(recMap);
        respWrap.invoiceMap = invMap;
        respWrap.receiptMap = recMap;
        respWrap.invLstMap = invNameMap;
        respWrap.recLstMap = recNameMap;
        return respWrap;
    }

    static List<Map<String,String>> getRecNameMap(Map<String, Receipt__c> recMap){
        List<Map<String,String>> recNameMap = new List<Map<String,String>>();
        for(String key : recMap.keySet()){
            recNameMap.add(new map<string,string>{'label' => recMap.get(key).Name + ' (' + recMap.get(key).RemainingAmount__c + ')' , 'value' => key});
        }
        return recNameMap;
    }

    static List<Map<String,String>> getInvNameMap(Map<String, Invoice__c> invMap){
        List<Map<String,String>> invNameMap = new List<Map<String,String>>();
        for(String key : invMap.keySet()){
            Invoice__c invObj = invMap.get(key);
            if(String.isNotBlank(invObj.ExpressionOfInterest__c)){
                invNameMap.add(new map<string,string>{'label' => invMap.get(key).ExpressionOfInterest__r.Name + ' (' + invMap.get(key).InvoiceBalance__c + ')' , 'value' => key});
            }else if(String.isNotBlank(invObj.SalesOrderInstallment__c)){
                invNameMap.add(new map<string,string>{'label' => invMap.get(key).SalesOrderInstallment__r.SalesOrder__r.Name + '/' + invMap.get(key).SalesOrderInstallment__r.MilestoneNumber__c + ' (' + invMap.get(key).InvoiceBalance__c + ')' , 'value' => key});
            }else{
                invNameMap.add(new map<string,string>{'label' => invMap.get(key).Name + ' (' + invMap.get(key).InvoiceBalance__c + ')' , 'value' => key});
            }
        }
        return invNameMap;
    }


    static Map<String, Receipt__c> getOpenReceipts(String accountId){
        Map<String, Receipt__c> receiptMap = new Map<String, Receipt__c>();
        List<Receipt__c> recLst = [SELECT Id, Name, RemainingAmount__c, ModeOfPayment__c, ReceiptDate__c
                                    FROM Receipt__c 
                                    WHERE Account__c = :accountId AND RemainingAmount__c > 0 AND Status__c NOT IN ('Draft', 'Rejected')];
        for(Receipt__c recObj : recLst){
            receiptMap.put(recObj.Id, recObj);
        }
        return receiptMap;
    }

    static Map<String, Invoice__c> getOpenInvoices(String accountId){
        Map<String, Invoice__c> invoiceMap = new Map<String, Invoice__c>();
        List<Invoice__c> invLst = [SELECT Id, Name, InvoiceBalance__c, ExpressionOfInterest__c, 
                                    ExpressionOfInterest__r.Name, SalesOrderInstallment__c, SalesOrderInstallment__r.SalesOrder__r.Name, 
                                    SalesOrderInstallment__r.MilestoneNumber__c 
                                        FROM Invoice__c 
                                        WHERE Account__c = :accountId AND InvoiceBalance__c > 0 AND InvoiceStatus__c != 'Cancelled'];
        for(Invoice__c invObj : invLst){
            invoiceMap.put(invObj.Id, invObj);
        }
        return invoiceMap;
    }

    //Method to get all allocation related to account Id
    @AuraEnabled
    public static ResponseWrapper getAllAllocations(Id recordId){
        ResponseWrapper respWrap = new ResponseWrapper();
        String objectType = recordId.getsobjecttype().getDescribe().getName();
        if(objectType == 'Account'){
            List<Allocation__c> allocationList = getAllocationRecords(recordId);
            respWrap.allLst = allocationList;
        }else if(objectType == 'SalesOrder__c'){
            String accId = [SELECT Id, CustomerAccount__c FROM SalesOrder__c WHERE Id = :recordId LIMIT 1].CustomerAccount__c;
            List<Allocation__c> allocationList = getAllocationRecords(accId);
            respWrap.allLst = allocationList;
        }else{
            respWrap.isSuccess = false;respWrap.errorMsg = 'This functionality is available for account and sales order object.';respWrap.messageVariant = 'Error';
        }
        return respWrap;
    }

    static List<Allocation__c> getAllocationRecords(String accountId){
        List<Allocation__c> allocationLst = [SELECT Id, Name, Receipt__r.Name, Receipt__r.ModeOfPayment__c, Status__c,AllocationAmount__c,
                                                Invoice__r.InvoiceBalance__c, Invoice__c, Invoice__r.Name, 
                                                Invoice__r.ExpressionofInterest__r.Name, Invoice__r.SalesOrderInstallment__r.Name, 
                                                Invoice__r.SalesOrderInstallment__r.SalesOrder__r.Name, Invoice__r.SalesOrderInstallment__r.MilestoneNumber__c
                                            FROM Allocation__c 
                                            WHERE Status__c = 'Applied' AND (Receipt__r.Account__c = :accountId)];
        return allocationLst;
    }

    @AuraEnabled
    public static ResponseWrapper unapplyAllocationRecord(Id allId){
        Allocation__c allObj = new Allocation__c();
        allObj.Id = allId;
        allObj.Status__c = 'Unapplied';
        ResponseWrapper respWrap = new ResponseWrapper();
        try{
            UPDATE allObj;
        }catch(Exception ex){
            system.debug(ex.getMessage()); respWrap.errorMsg = ex.getMessage(); respWrap.isSuccess = false; respWrap.messageVariant = 'Error';
        }
        return respWrap;
    }

    @AuraEnabled
    public static ResponseWrapper saveAllocationRecord(String invoiceId, String receiptId, Integer allocateAmnt){
        Allocation__c allObj = new Allocation__c();
        allObj.Invoice__c = invoiceId;
        allObj.Receipt__c = receiptId;
        allObj.AllocationAmount__c = allocateAmnt;
        allObj.AllocationDate__c = System.today();
        allObj.Status__c = 'Applied';
        ResponseWrapper respWrap = new ResponseWrapper();
        try{
            INSERT allObj;
        }catch(Exception ex){
            system.debug(ex.getMessage());
            respWrap.errorMsg = ex.getMessage();
            respWrap.isSuccess = false;
            respWrap.messageVariant = 'Error';
        }
        return respWrap;
    }

    public class ResponseWrapper{
        @AuraEnabled public Boolean isSuccess;
        @AuraEnabled public String errorMsg;
        @AuraEnabled public String messageVariant;
        @AuraEnabled public List<Allocation__c> allLst;
        @AuraEnabled public Map<String, Invoice__c> invoiceMap;
        @AuraEnabled public Map<String, Receipt__c> receiptMap;
        @AuraEnabled public List<Map<String,String>> invLstMap;
        @AuraEnabled public List<Map<String,String>> recLstMap;

        public ResponseWrapper(){
            isSuccess = true;
        }
    }
}