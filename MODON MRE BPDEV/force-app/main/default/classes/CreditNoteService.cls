public class CreditNoteService {
    
    public static List<Invoice__c> getSalesOrderTaxInvoiceAndCreditNotes(Id SalesOrderId,set<string> status){
        List<Invoice__c> invoiceList = [SELECT Id, InvoiceAmount__c, SalesOrderInstallment__r.SalesOrder__c
            ,RecordTypeId,OICIntegrationStatus__c,
            (SELECT Id,Amount__c FROM Credit_Notes__r)
            FROM Invoice__c WHERE 
            SalesOrderInstallment__r.SalesOrder__c = :SalesOrderId
            AND Charge__c = NULL 
            and SalesOrderInstallment__c != null
            AND OICIntegrationStatus__c IN :status 
            AND recordtype.developerName = :Constants.INVOICE_RT_TAX_INVOICE
            AND isCancelled__c = false
        ];
        return invoiceList;
    }
    
    public static List<Invoice__c> getSalesOrderTaxInvoiceNotSynced(Id SalesOrderId,set<string> status){
        List<Invoice__c> invoiceList = [SELECT Id, InvoiceAmount__c, SalesOrderInstallment__r.SalesOrder__c
            ,RecordTypeId,OICIntegrationStatus__c,
            (SELECT Id,Amount__c FROM Credit_Notes__r)
            FROM Invoice__c WHERE SalesOrderInstallment__r.SalesOrder__c= :SalesOrderId
            AND Charge__c = NULL 
            and SalesOrderInstallment__c != null
            AND (NOT OICIntegrationStatus__c IN :status)
            AND recordtype.developerName = :Constants.INVOICE_RT_TAX_INVOICE
            AND isCancelled__c = false
        ];
        return invoiceList;
    }
    
    public static Boolean validateInProgressCreditNotesByOpportunityId(Id SalesOrderId,Set<string>status){
        Boolean isValidated = true;
        List<Invoice__c> invoiceList = getSalesOrderTaxInvoiceAndCreditNotes(SalesOrderId,status);
        for(Invoice__c inv : invoiceList){
            if(inv.Credit_Notes__r.isEmpty()){
                isValidated = false;
                break;
            }
        }
        return isValidated;
    }
    
/**
 * @description This method takes a SR as input and creates a creadit notes for synced "Tax invoice" records with Oracle.
 * system will check if any credit notes are not present for that invoice, it will create and proceed further
 * @param SR record and "Synced Status" 
 */
    
    public static void createCNForInstallmentInvoicesSynced(ServiceRequest__c objSR,Set<string>status){
          
        Boolean isValidated = CreditNoteService.validateInProgressCreditNotesByOpportunityId(objSR.SalesOrder__c,status);//new Set<string>{Constants.SUCCESS_STATUS}
        system.debug('---------isValidated --------------'+isValidated );
        if(isValidated){
            //validateCreditNoteSync(objSR);
            system.debug('-----11111----isValidated --------------'+isValidated );
        }else{
            system.debug('-----2222----isValidated --------------'+isValidated );
            List<Invoice__c> invoiceList = CreditNoteService.getSalesOrderTaxInvoiceAndCreditNotes(objSR.SalesOrder__c,status);  
           //Create credit notes
            createCreditNotes(invoiceList,null);
            // Validate Credit Note Sync
            //validateCreditNoteSync(objSR);
        }
        
    }
    
    /**
         * @description This method takes a SR as input and cancel the not synced "Tax invoice" records with Oracle.
         * system will update the status as cancelled of the invoice record
         * @param SR record and pass the excluded the status in the query
     */
    
    public static void createCNForInstallmentInvoicesNotSynced(ServiceRequest__c objSR,Set<string>status){
       
        List<Invoice__c> invoiceList = CreditNoteService.getSalesOrderTaxInvoiceNotSynced(objSR.SalesOrder__c,status);  
        system.debug('------createCNForInstallmentInvoicesNotSynced---------------------------'+invoiceList);
        if(invoiceList.size()>0 && invoiceList != null)updateInvoicesToCancelled(invoiceList);
        
    }
    
    public static List<Invoice__c> updateInvoicesToCancelled(List<Invoice__c> invoiceList){
    
        List<Invoice__c > updateInvList= new List<Invoice__c >();

        for(Invoice__c invoice :invoiceList){
            invoice.isCancelled__c = true;
            updateInvList.add(invoice);
        }
        if(updateInvList.size()>0) update updateInvList;
        system.debug('updateInvList->'+updateInvList);
        return updateInvList;
    }
    
    
    public static List<CreditNote__c> createCreditNotes(List<Invoice__c> invoiceList, Id phaseId){
    
        List<CreditNote__c> creditNoteList = new List<CreditNote__c>();

        for(Invoice__c invoice :invoiceList){
            CreditNote__c cn = new CreditNote__c();
            cn.Invoice__c = invoice.id;
            cn.Amount__c = invoice.InvoiceAmount__c;            
            System.debug('cn.Amount__c '+cn.Amount__c);
            cn.Source__c = 'Property Sales Invoice';
            cn.Sales_Order__c = invoice.SalesOrderInstallment__r.SalesOrder__c;
            cn.Approval_Status__c = 'Approved';
            cn.ApprovalDate__c = Date.today();
            cn.IntegrationStatus__c = 'Success'; //'Not Integrated';
            creditNoteList.add(cn);
        }
        if(creditNoteList.size()>0) insert creditNoteList;
        system.debug('creditNoteList->'+creditNoteList);
        return creditNoteList;
    }
}