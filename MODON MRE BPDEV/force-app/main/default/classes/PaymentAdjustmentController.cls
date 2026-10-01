public without sharing class PaymentAdjustmentController {
    @AuraEnabled
    public static List<salesOrderOptions> getRelatedSalesOrder(Id recordId){
        system.debug('recordId:'+recordId);
        if(recordId <> null){
            String objectName = getObjectNameFromId(recordId);
            System.debug('objectName: '+objectName);
            Id customerAccount,SalesOrderId;
            String projectName = '';
            if(objectName == 'Receipt__c'){
                customerAccount = [SELECT Id,SalesOrder__r.CustomerAccount__c 
                                   FROM Receipt__c WHERE Id =:recordId LIMIT 1].SalesOrder__r.CustomerAccount__c;
                projectName = [SELECT Id,SalesOrder__r.CustomerAccount__c, ProjectName__c 
                                FROM Receipt__c WHERE Id =:recordId LIMIT 1].ProjectName__c;
                
			system.debug('customerAccount in Reciept__c: '+customerAccount);
            system.debug('projectName in Receipt__c: '+projectName);
                List<SalesOrder__c> debugOrders = [
                    SELECT Id, ProjectName__c, CustomerAccount__c, Status__c
                    FROM SalesOrder__c
                    WHERE CustomerAccount__c = :customerAccount and Status__c NOT IN ('Cancelled', 'Cancelled SR', 'Voided')
                ];
                system.debug('SalesOrders for Receipt Account: ' + debugOrders);
                //SalesOrderId = debugOrders[0].Id;
            }else if(objectName == 'Invoice__c'){
                /*List<Invoice__c> lst_Invoice = [SELECT Id,Sales_Order__r.CustomerAccount__c, Sales_Order__c, Sales_Order__r.ProjectName__c, 
                                                SalesOrderInstallment__r.SalesOrder__r.CustomerAccount__c, 
                                                SalesOrderInstallment__r.SalesOrder__c, SalesOrderInstallment__r.SalesOrder__r.ProjectName__c 
                                                FROM Invoice__c WHERE Id =:recordId];
                Invoice__c obj_Invoice = new Invoice__c();
                if(lst_Invoice != null && lst_Invoice.size() > 0){
                    obj_Invoice = lst_Invoice.get(0);
                }
                if(!String.isBlank(obj_Invoice.Sales_Order__c)){
                    customerAccount = obj_Invoice.Sales_Order__r.CustomerAccount__c;
                	SalesOrderId = obj_Invoice.Sales_Order__c;
                	projectName =  obj_Invoice.Sales_Order__r.ProjectName__c; 
                } else if(!String.isBlank(obj_Invoice.SalesOrderInstallment__r.SalesOrder__c)){
                    customerAccount = obj_Invoice.SalesOrderInstallment__r.SalesOrder__r.CustomerAccount__c;
                	SalesOrderId = obj_Invoice.SalesOrderInstallment__r.SalesOrder__c;
                	projectName =  obj_Invoice.SalesOrderInstallment__r.SalesOrder__r.ProjectName__c; 
                }
                 
            system.debug('customerAccount in Invoice: '+customerAccount);
            system.debug('projectName in Invoice: '+projectName);
            system.debug('SalesOrderId in Invoice: '+ SalesOrderId);
               List<SalesOrder__c> debugOrders = [
                SELECT Id, ProjectName__c, CustomerAccount__c
                FROM SalesOrder__c
                WHERE CustomerAccount__c = :customerAccount and Status__c NOT IN ('Cancelled', 'Sold', 'Completed', 'Cancelled SR', 'Voided')
            ];
            system.debug('SalesOrders for Invoice Account: ' + debugOrders);*/
            }
            
            Set<Id> accountIds = new Set<Id>{ customerAccount };
            Set<Id> relatedSalesOrderIds = new Set<Id>();
            for(SalesOrderRelationship__c sor : [SELECT SalesOrder__c FROM SalesOrderRelationship__c WHERE ThridPartyCustomer__c IN: accountIds
                                                 AND Compliance_Status__c = 'Approved' AND NOCStatus__c = 'Signed']){
                if(sor.SalesOrder__c != null){
                    relatedSalesOrderIds.add(sor.SalesOrder__c);
                }
            }
            System.debug('Print relatedSalesOrderIds '+relatedSalesOrderIds);

            List<salesOrderOptions> soOptionsList = new List<salesOrderOptions>();
            for(SalesOrderInstallments__c soInst:[SELECT Id,SalesOrder__r.Name,SalesOrder__r.Unit__r.Name,SalesOrder__c
                                                  FROM SalesOrderInstallments__c
                                                  WHERE (NOT PaymentStatus__c IN ('Cancelled','Paid'))
                                                  AND (SalesOrder__r.CustomerAccount__c IN: accountIds OR SalesOrder__c IN: relatedSalesOrderIds)
                                                  AND SalesOrder__r.ProjectName__c =: projectName
                                                  AND SalesOrder__r.Status__c NOT IN('Cancelled', 'Cancelled SR', 'Voided') ]){
                salesOrderOptions soOptions = new salesOrderOptions(); 
                soOptions.Label = soInst.SalesOrder__r.Unit__r.Name;
                soOptions.value = soInst.SalesOrder__c;
                soOptionsList.add(soOptions);                                                  
                                                      
            }
            system.debug('soOptionsList:'+soOptionsList);
            return soOptionsList;
        }
        return null;
    }
    @AuraEnabled
    public static SOIPaymentWrapper createPayment(String recordId, String SOInstallmentId,decimal adjustmentAmount) {
        SOIPaymentWrapper soWrapper = new SOIPaymentWrapper();
        try{
            if(!String.isBlank(recordId) && !String.isBlank(SOInstallmentId)){
                String objectName = getObjectNameFromId(recordId);
                String SOInstallmentIdObjName = getObjectNameFromId(SOInstallmentId);
                if(objectName == 'Receipt__c'){
                    Receipt__c obj_Receipt = new Receipt__c();
                    Invoice__c obj_Invoice = new Invoice__c();
                    List<Invoice__c> lst_Invoice = new List<Invoice__c>();
                    List<Receipt__c> lst_Receipt = [SELECT Id, SalesOrder__r.CustomerAccount__c, 
                                                    SalesOrderInstallment__r.SalesOrder__r.CustomerAccount__c, 
                                                    Bank__c, ChequeDate__c, Last4Digit__c,TotalAmount__c,
                                                    Receipt_Amount__c, Receipt_Excess_Amount__c,
                                                    Modeofpayment__c, ReceiptDate__c, SalesOrder__c, TransactionDate__c, RemainingAmount__c,  
                                                    TransactionNumber__c, AppliedAmount__c from Receipt__c where Id = :recordId];
                    if(SOInstallmentIdObjName == 'Invoice__c'){
                        lst_Invoice = [SELECT Id, Name, Description__c, InvoiceDate__c, InvoiceStatus__c, InvoiceAmount__c, 
                                                    InvoiceBalance__c, Account__c, Sales_Order__r.ProjectName__c, Sales_Order__c, 
                                                    Is_ADM_Fees_and_Dari_charges__c  FROM Invoice__c 
                                                    where Id = :SOInstallmentId and Is_ADM_Fees_and_Dari_charges__c = true 
                                                    and InvoiceStatus__c IN ('Generated', 'Partially Paid')];
                    } else {
                        lst_Invoice = [SELECT Id,SalesOrderInstallment__c,Sales_Order__c, InvoiceBalance__c,Account__c, 
                                                          Sales_Order__r.ProjectName__c, SalesOrderInstallment__r.SalesOrder__c, 
                                                          SalesOrderInstallment__r.SalesOrder__r.ProjectName__c 
                                                          FROM Invoice__c WHERE SalesOrderInstallment__r.Id = :SOInstallmentId];
                    }
                    
                    if(lst_Receipt.size() > 0 && lst_Invoice.size() > 0){
                        obj_Receipt = lst_Receipt.get(0);
                        obj_Invoice = lst_Invoice.get(0);
                        Allocation__c obj_Allocation = new Allocation__c();
                        if(obj_Receipt.Receipt_Excess_Amount__c > 0){
                            obj_Allocation.Receipt__c = obj_Receipt.Id;
                            obj_Allocation.Invoice__c = obj_Invoice.Id;
                            obj_Allocation.AllocationDate__c = System.today();
                            obj_Allocation.AllocationAmount__c = adjustmentAmount;
                            obj_Allocation.Status__c = 'Applied';
                            obj_Allocation.InProgressReceiptAmount__c = adjustmentAmount;
                            insert obj_Allocation;
                            system.debug('obj_Allocation: '+obj_Allocation);
                        }
                    }     
                }
            }
            soWrapper = getRelatedSOInstallments(recordId,null);
            return soWrapper;  
        }catch(Exception exe){
            System.debug('Error in getRelatedSOInstallments: ' + exe.getMessage());
            throw new AuraHandledException(exe.getMessage());
        }
        
    }  
    
    @AuraEnabled
    public static SOIPaymentWrapper getSOInstallmentsDetails(String recordId,Id SOId) {
        SOIPaymentWrapper soWrapper = new SOIPaymentWrapper();
        List<SOInstallments> lst_SOInstallmentWrapper = new List<SOInstallments>();
        List<SalesOrderInstallments__c> lst_SalesOrderInstallments = new List<SalesOrderInstallments__c>();
        Map<Id,Invoice__c> invoiceMap = new Map<Id,Invoice__c>();
        Set<Id> installmentIdset = new Set<Id>();
        Id ignoreSalesOrderId = null;
        try{
            if(!String.isBlank(recordId)){
                Id SalesOrderInstallmentId,customerAccount;
                String objectName = getObjectNameFromId(recordId);
                String projectName;
                if(objectName == 'Receipt__c'){
                    Receipt__c obj_Receipt = new Receipt__c();
                    List<Receipt__c> lst_Receipts = [SELECT Id, SalesOrderInstallment__r.SalesOrder__c, 
                                                     SalesOrderInstallment__r.Id, RemainingAmount__c, ProjectName__c,
                                                     Receipt_Amount__c, Receipt_Excess_Amount__c,
                                                     SalesOrder__r.CustomerAccount__c
                                                     FROM Receipt__c WHERE Id = :recordId];
                    if(lst_Receipts.size() > 0) {
                        obj_Receipt = lst_Receipts.get(0);
                        SalesOrderInstallmentId = obj_Receipt.SalesOrderInstallment__r != null?obj_Receipt.SalesOrderInstallment__r.Id:null;
                        SOId = SOId <> null ? SOId:obj_Receipt.SalesOrderInstallment__r.SalesOrder__c;
                        soWrapper.balanceAmountonPayment = obj_Receipt.Receipt_Excess_Amount__c;
                        projectName = obj_Receipt.ProjectName__c;
                        customerAccount = obj_Receipt.SalesOrder__r.CustomerAccount__c;
                    }
                    }else if(objectName == 'Invoice__c'){
                        /*List<Invoice__c> invoicelst = [SELECT Id,SalesOrderInstallment__c,Sales_Order__c, InvoiceBalance__c,Account__c, 
                                                       Sales_Order__r.ProjectName__c, SalesOrderInstallment__r.SalesOrder__c, 
                                                       SalesOrderInstallment__r.SalesOrder__r.ProjectName__c 
                                                       FROM Invoice__c WHERE Id = :recordId];
                        if(!invoicelst.isEmpty()){
                           SOId = SOId <> null ?SOId : invoicelst[0].Sales_Order__c; 
                            if(SOId == null){
                                SOId = invoicelst[0].SalesOrderInstallment__r.SalesOrder__c;
                            } 
                           soWrapper.balanceAmountonPayment = invoicelst[0].InvoiceBalance__c;
                           SalesOrderInstallmentId = invoicelst[0].SalesOrderInstallment__c;
                           //ignoreSalesOrderId = invoicelst[0].Sales_Order__c;
                           customerAccount = invoicelst[0].Account__c;
                           projectName = invoicelst[0].Sales_Order__r.ProjectName__c; 
                           if(!String.isBlank(projectName)){
                                projectName = invoicelst[0].SalesOrderInstallment__r.SalesOrder__r.ProjectName__c;
                           } 
                        }*/
	                     
                    }
                    
                    if(!String.isBlank(SOId)){
                        Integer indexValue =0;
                        lst_SalesOrderInstallments = [SELECT Id, Name, MilestoneDescription__c, MilestoneNumber__c, MilestoneDate__c, 
                                                      PaymentStatus__c, InstallmentAmount__c  FROM SalesOrderInstallments__c 
                                                      where PaymentStatus__c IN ('Not Paid', 'Partially Paid') 
                                                      AND SalesOrder__r.CustomerAccount__c != null
                                                      AND SalesOrder__r.Status__c NOT IN ('Cancelled', 'Cancelled SR', 'Voided')
                                                      AND SalesOrder__c = :SOId
                                                      order by MilestoneNumber__c asc];
                        
                        for(SalesOrderInstallments__c obj_Installment : lst_SalesOrderInstallments){
                            installmentIdset.add(obj_Installment.Id);
                        }
                        for(Invoice__c inv:[SELECT Id,InvoiceBalance__c,SalesOrderInstallment__c FROM Invoice__c 
                                            WHERE SalesOrderInstallment__c IN:installmentIdset ]){
                            invoiceMap.put(inv.SalesOrderInstallment__c,inv);
                        }
                        for(SalesOrderInstallments__c obj_Installment : lst_SalesOrderInstallments){
                                   SOInstallments obj_SOInstallments = new SOInstallments();
                                   obj_SOInstallments.Index = indexValue;
                                   obj_SOInstallments.SOInstallmentId = obj_Installment.Id;   
                                   obj_SOInstallments.Name = obj_Installment.Name;
                                   obj_SOInstallments.MilestoneDescription = obj_Installment.MilestoneDescription__c;
                                   obj_SOInstallments.MilestoneNumber = obj_Installment.MilestoneNumber__c;
                                   obj_SOInstallments.MilestoneDate = obj_Installment.MilestoneDate__c;
                                   obj_SOInstallments.PaymentStatus = obj_Installment.PaymentStatus__c;
                                   obj_SOInstallments.InstallmentAmount = obj_Installment.InstallmentAmount__c;
                                   obj_SOInstallments.adjustmentAmount = 0;
                                   obj_SOInstallments.adjustPayment = true;
                                   obj_SOInstallments.outstandingAmount = invoiceMap.containsKey(obj_Installment.Id)?invoiceMap.get(obj_Installment.Id).InvoiceBalance__c:0;
                                   
                                   lst_SOInstallmentWrapper.add(obj_SOInstallments);   
                       }
                    }
                    List<Invoice__c> lst_Invoice = [SELECT Id, Name, Description__c, InvoiceDate__c, InvoiceStatus__c, InvoiceAmount__c, 
                                                    InvoiceBalance__c, Account__c, Sales_Order__r.ProjectName__c, Sales_Order__c, 
                                                    Is_ADM_Fees_and_Dari_charges__c  FROM Invoice__c 
                                                    where Sales_Order__c = :SOId and Is_ADM_Fees_and_Dari_charges__c = true 
                                                    and InvoiceStatus__c IN ('Generated', 'Partially Paid')];
                
                    for(Invoice__c obj_Invoice : lst_Invoice){
                        		SOInstallments obj_SOInstallments = new SOInstallments();
                                   obj_SOInstallments.Index = 0;
                                   obj_SOInstallments.SOInstallmentId = obj_Invoice.Id;   
                                   obj_SOInstallments.Name = obj_Invoice.Name;
                                   obj_SOInstallments.MilestoneDescription = obj_Invoice.Description__c;
                                   obj_SOInstallments.MilestoneNumber = 0;
                                   obj_SOInstallments.MilestoneDate = obj_Invoice.InvoiceDate__c;
                                   obj_SOInstallments.PaymentStatus = obj_Invoice.InvoiceStatus__c;
                                   obj_SOInstallments.InstallmentAmount = obj_Invoice.InvoiceAmount__c;
                                   obj_SOInstallments.adjustmentAmount = 0;
                                   obj_SOInstallments.adjustPayment = true;
                                   obj_SOInstallments.outstandingAmount = obj_Invoice.InvoiceBalance__c;
                                   
                                   lst_SOInstallmentWrapper.add(obj_SOInstallments);
                    }	                    
                    soWrapper.soInstallments = lst_SOInstallmentWrapper;
                              
            }   
            return soWrapper;
        }catch (Exception e) {
            System.debug('Error in getRelatedSOInstallments: ' + e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static SOIPaymentWrapper getRelatedSOInstallments(String recordId,String SOId) {
        SOIPaymentWrapper soWrapper = new SOIPaymentWrapper();
        List<SOInstallments> lst_SOInstallmentWrapper = new List<SOInstallments>();
        List<SalesOrderInstallments__c> lst_SalesOrderInstallments = new List<SalesOrderInstallments__c>();
        Set<Id> installmentIdset = new Set<Id>();
        Id ignoreSalesOrderId = null;
        try{
            if(!String.isBlank(recordId)){
                 Id SalesOrderInstallmentId,customerAccount;
                 String objectName = getObjectNameFromId(recordId);
                 String projectName;
                if(objectName == 'Receipt__c'){
                    Receipt__c obj_Receipt = new Receipt__c();
                    List<Receipt__c> lst_Receipts = [SELECT Id, SalesOrderInstallment__r.SalesOrder__c, 
                                                     SalesOrderInstallment__r.Id,RemainingAmount__c, ProjectName__c,
                                                     Receipt_Amount__c, Receipt_Excess_Amount__c,
                                                     SalesOrder__r.CustomerAccount__c
                                                     FROM Receipt__c WHERE Id = :recordId];
                    if(lst_Receipts.size() > 0) {
                        obj_Receipt = lst_Receipts.get(0);
                        SalesOrderInstallmentId = obj_Receipt.SalesOrderInstallment__r.Id;
                        SOId = SOId <> null ? SOId:obj_Receipt.SalesOrderInstallment__r.SalesOrder__c;
                        projectName = obj_Receipt.ProjectName__c;
                        soWrapper.balanceAmountonPayment = obj_Receipt.Receipt_Excess_Amount__c;
                        customerAccount = obj_Receipt.SalesOrder__r.CustomerAccount__c;
                    }
                    }else if(objectName == 'Invoice__c'){
                        List<Invoice__c> invoicelst = [SELECT Id,SalesOrderInstallment__c,Sales_Order__c, InvoiceBalance__c,Account__c, 
                                                       Sales_Order__r.ProjectName__c, SalesOrderInstallment__r.SalesOrder__c, 
                                                       SalesOrderInstallment__r.SalesOrder__r.ProjectName__c 
                                                       FROM Invoice__c WHERE Id = :recordId];
                        if(!invoicelst.isEmpty()){
                           customerAccount = invoicelst[0].Account__c;
                           SOId = SOId <> null ?SOId : invoicelst[0].Sales_Order__c;
                            if(String.isBlank(SOId)){
                                SOId = invoicelst[0].SalesOrderInstallment__r.SalesOrder__c;
                            } 
                           soWrapper.balanceAmountonPayment = invoicelst[0].InvoiceBalance__c;
                           SalesOrderInstallmentId = invoicelst[0].SalesOrderInstallment__c;
                           //ignoreSalesOrderId = invoicelst[0].Sales_Order__c;
                           projectName = invoicelst[0].Sales_Order__r.ProjectName__c;  
                           if(String.isBlank(projectName)){
                                projectName = invoicelst[0].SalesOrderInstallment__r.SalesOrder__r.ProjectName__c; 
                           } 
                        }
	                     
                    }
               
                    if(!String.isBlank(SOId)){
                        Map<Id,Invoice__c> invoiceMap = new Map<Id,Invoice__c>();
                        Integer indexValue =0;
                        lst_SalesOrderInstallments = [SELECT Id, Name, MilestoneDescription__c, MilestoneNumber__c, MilestoneDate__c, 
                                                      PaymentStatus__c, InstallmentAmount__c  FROM SalesOrderInstallments__c 
                                                      where PaymentStatus__c IN ('Not Paid', 'Partially Paid') 
                                                      AND SalesOrder__r.CustomerAccount__c != null
                                                      AND SalesOrder__r.Status__c NOT IN ('Cancelled', 'Cancelled SR', 'Voided')
                                                      AND SalesOrder__c = :SOId
                                                      order by MilestoneNumber__c asc];
                        for(SalesOrderInstallments__c obj_Installment : lst_SalesOrderInstallments){
                            installmentIdset.add(obj_Installment.Id);
                        }
                        for(Invoice__c inv:[SELECT Id,InvoiceBalance__c,SalesOrderInstallment__c FROM Invoice__c WHERE SalesOrderInstallment__c IN:installmentIdset ]){
                            invoiceMap.put(inv.SalesOrderInstallment__c,inv);
                        }
                        for(SalesOrderInstallments__c obj_Installment : lst_SalesOrderInstallments){
                                   SOInstallments obj_SOInstallments = new SOInstallments();
                                   obj_SOInstallments.Index = indexValue;
                                   obj_SOInstallments.SOInstallmentId = obj_Installment.Id;   
                                   obj_SOInstallments.Name = obj_Installment.Name;
                                   obj_SOInstallments.MilestoneDescription = obj_Installment.MilestoneDescription__c;
                                   obj_SOInstallments.MilestoneNumber = obj_Installment.MilestoneNumber__c;
                                   obj_SOInstallments.MilestoneDate = obj_Installment.MilestoneDate__c;
                                   obj_SOInstallments.PaymentStatus = obj_Installment.PaymentStatus__c;
                                   obj_SOInstallments.InstallmentAmount = obj_Installment.InstallmentAmount__c;  
                                   obj_SOInstallments.adjustmentAmount = 0;
                                   obj_SOInstallments.adjustPayment = true;
                                   obj_SOInstallments.outstandingAmount = invoiceMap.containsKey(obj_Installment.Id)?invoiceMap.get(obj_Installment.Id).InvoiceBalance__c:0;
                                   lst_SOInstallmentWrapper.add(obj_SOInstallments);   
                         }
                        List<Invoice__c> lst_Invoice = [SELECT Id, Name, Description__c, InvoiceDate__c, InvoiceStatus__c, InvoiceAmount__c, 
                                                    InvoiceBalance__c, Account__c, Sales_Order__r.ProjectName__c, Sales_Order__c, 
                                                    Is_ADM_Fees_and_Dari_charges__c  FROM Invoice__c 
                                                    where Sales_Order__c = :SOId and Is_ADM_Fees_and_Dari_charges__c = true 
                                                    and InvoiceStatus__c IN ('Generated', 'Partially Paid')];
                
                        for(Invoice__c obj_Invoice : lst_Invoice){
                                    SOInstallments obj_SOInstallments = new SOInstallments();
                                       obj_SOInstallments.Index = 0;
                                       obj_SOInstallments.SOInstallmentId = obj_Invoice.Id;   
                                       obj_SOInstallments.Name = obj_Invoice.Name;
                                       obj_SOInstallments.MilestoneDescription = obj_Invoice.Description__c;
                                       obj_SOInstallments.MilestoneNumber = 0;
                                       obj_SOInstallments.MilestoneDate = obj_Invoice.InvoiceDate__c;
                                       obj_SOInstallments.PaymentStatus = obj_Invoice.InvoiceStatus__c;
                                       obj_SOInstallments.InstallmentAmount = obj_Invoice.InvoiceAmount__c;
                                       obj_SOInstallments.adjustmentAmount = 0;
                                       obj_SOInstallments.adjustPayment = true;
                                       obj_SOInstallments.outstandingAmount = obj_Invoice.InvoiceBalance__c;
                                       
                                       lst_SOInstallmentWrapper.add(obj_SOInstallments);
                        }
                    } 
                    soWrapper.soInstallments = lst_SOInstallmentWrapper;
                }                
             
            return soWrapper;
        }catch (Exception e) {
            System.debug('Error in getRelatedSOInstallments: ' + e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }
 
    public static String getObjectNameFromId(Id recordId) {
    if (recordId == null) {
        return null;
    }
    
    Schema.SObjectType objType = recordId.getSObjectType();
    return objType.getDescribe().getName();
}

    
    public class SOInstallments{
        @AuraEnabled public String SOInstallmentId{get;set;}
        @AuraEnabled public Integer Index{get;set;}
        @AuraEnabled public String Name{get;set;}
        @AuraEnabled public String MilestoneDescription{get;set;}
        @AuraEnabled public Decimal MilestoneNumber{get;set;}
        @AuraEnabled public Date MilestoneDate{get;set;}
        @AuraEnabled public String PaymentStatus{get;set;}
        @AuraEnabled public Double InstallmentAmount{get;set;}
        @AuraEnabled public Double adjustmentAmount{get;set;}
        @AuraEnabled public boolean adjustPayment{get;set;}
        @AuraEnabled public Double outstandingAmount{get;set;}
    }
    public class SOIPaymentWrapper{
        @AuraEnabled public decimal balanceAmountonPayment {get;set;}
        @AuraEnabled public List<SOInstallments> soInstallments {get;set;}
        public SOIPaymentWrapper(){
            soInstallments = new List<SOInstallments>();
        }
    }  
    public class salesOrderOptions{
        @AuraEnabled public string label {get;set;}
        @AuraEnabled public string value {get;set;}
    }
}