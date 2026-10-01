public class SalesOrderHistoricalUpdateHelper {
    public static void checkADMStatus(Set<Id> salesOrderIdSet){
        
        Set<Id> salesOrderIdsetADMCollected= new Set<Id>();
        Set<Id> salesOrderIdsetADMPaid= new Set<Id>();
        
        if(!salesOrderIdSet.isEmpty()){
            List<Invoice__c> invoiceObjLst = [SELECT Id, Name, InvoiceStatus__c, AppliedAmount__c, InvoiceAmount__c,Sales_Order__c FROM Invoice__c WHERE Sales_Order__c =: salesOrderIdSet AND Is_ADM_Fees_and_Dari_charges__c = true];
            Map<Id,Invoice__c> invoiceMap = new Map<Id,Invoice__c>();
            for(Invoice__c inv: invoiceObjLst){
                invoiceMap.put(inv.Id,inv);
            }
            List<SalesOrder__c> salesOrderListUpdate = new List<SalesOrder__c>();
            List<Logger__c> logUpdate = new List<Logger__c>();
            if(!invoiceObjLst.isEmpty()){
                for(Invoice__c invObj: invoiceObjLst){
                    if(invObj.InvoiceStatus__c == 'Paid'){
                        Logger__c log = new Logger__c();
                        log.Sales_Order__c = invoiceMap.get(invObj.Id).Sales_Order__c;
                        log.UUID__c = 'Paid';
                        log.Actual_ADM_Charge_Without_Discount__c = invObj.InvoiceAmount__c;
                        log.Collected_ADM_Amount__c = invObj.AppliedAmount__c;
                        log.externalUpdate__c = invoiceMap.get(invObj.Id).Sales_Order__c;
                        logUpdate.add(log);
                    }else if(invObj.InvoiceStatus__c == 'Partially Paid'){ 
                        Logger__c log = new Logger__c();
                        log.Sales_Order__c = invoiceMap.get(invObj.Id).Sales_Order__c;
                        log.UUID__c = 'Partially Paid';
                        log.Collected_ADM_Amount__c = invObj.AppliedAmount__c;
                        log.externalUpdate__c = invoiceMap.get(invObj.Id).Sales_Order__c;
                        log.Actual_ADM_Charge_Without_Discount__c = invObj.InvoiceAmount__c;
                        logUpdate.add(log);
                        
                    }else if(invObj.InvoiceStatus__c == 'Cancelled'){
                        Logger__c log = new Logger__c();
                        log.Sales_Order__c = invoiceMap.get(invObj.Id).Sales_Order__c;
                        log.UUID__c = 'Cancelled';
                        log.Collected_ADM_Amount__c = invObj.AppliedAmount__c;
                        log.Actual_ADM_Charge_Without_Discount__c = invObj.InvoiceAmount__c;
                        log.externalUpdate__c = invoiceMap.get(invObj.Id).Sales_Order__c;
                        logUpdate.add(log);
                    }else if((invObj.AppliedAmount__c + (Decimal.valueOf(System.label.ADMBufferAmount))) >= invObj.InvoiceAmount__c){
                        Logger__c log = new Logger__c();
                        log.Sales_Order__c = invoiceMap.get(invObj.Id).Sales_Order__c;
                        log.UUID__c = 'Collected';
                        log.Collected_ADM_Amount__c = invObj.AppliedAmount__c;
                        log.Actual_ADM_Charge_Without_Discount__c = invObj.InvoiceAmount__c;
                        log.externalUpdate__c = invoiceMap.get(invObj.Id).Sales_Order__c;
                        logUpdate.add(log);
                       
                    }else if(invObj.AppliedAmount__c > 0 && (invObj.AppliedAmount__c + (Decimal.valueOf(System.label.ADMBufferAmount))) < invObj.InvoiceAmount__c){
                        Logger__c log = new Logger__c();
                        log.Sales_Order__c = invoiceMap.get(invObj.Id).Sales_Order__c;
                        log.UUID__c = 'Partially Collected';
                        log.Collected_ADM_Amount__c = invObj.AppliedAmount__c;
                        log.externalUpdate__c = invoiceMap.get(invObj.Id).Sales_Order__c;
                        log.Actual_ADM_Charge_Without_Discount__c = invObj.InvoiceAmount__c;
                        logUpdate.add(log);
                       
                    }else{
                        Logger__c log = new Logger__c();
                        log.Sales_Order__c = invoiceMap.get(invObj.Id).Sales_Order__c;
                        log.UUID__c = 'Generated';
                        log.Actual_ADM_Charge_Without_Discount__c = invObj.InvoiceAmount__c;
                        log.Collected_ADM_Amount__c = invObj.AppliedAmount__c;
                        log.externalUpdate__c = invoiceMap.get(invObj.Id).Sales_Order__c;
                        logUpdate.add(log);
                    }
                }
                if(!logUpdate.isEmpty()){
                    upsert logUpdate externalUpdate__c;
                } 
            } 
        }
        
    }
    public static void checkDownPaymentStatus(Set<Id> salesOrderIdSet){
        Set<Id> salesOrderIdsetDPCollected= new Set<Id>();
        Set<Id> salesOrderIdsetDPPaid= new Set<Id>();
        List<SalesOrderInstallments__c> salesOrderInstallements = [SELECT Id, Name, Milestone__c FROM SalesOrderInstallments__c WHERE SalesOrder__c IN: salesOrderIdSet AND MilestoneNumber__c = 1];
        if(!salesOrderInstallements.isEmpty()){
            Set<Id> soInstallmentIdset = new Set<Id>();
            for(SalesOrderInstallments__c soId: salesOrderInstallements){
                soInstallmentIdset.add(soId.Id);
            }
            List<Invoice__c> invoiceObjLst = [SELECT Id, Name, InvoiceStatus__c, AppliedAmount__c, InvoiceAmount__c,SalesOrderInstallment__c,SalesOrderInstallment__r.SalesOrder__c FROM Invoice__c WHERE SalesOrderInstallment__c =: soInstallmentIdset];
            Map<Id,Invoice__c> invoiceMap = new Map<Id,Invoice__c>();
            for(Invoice__c inv: invoiceObjLst){
                invoiceMap.put(inv.Id,inv);
            }
            Map<Id,SalesOrder__c> salesOrderUpdateMap = new Map<Id,SalesOrder__c>();
            List<Logger__c> logUpdate = new List<Logger__c>();
            if(!invoiceObjLst.isEmpty()){
                for(Invoice__c invObj: invoiceObjLst){
                    if(invObj.InvoiceStatus__c == 'Paid'){
                        Logger__c log = new Logger__c();
                        log.externalUpdate__c = invoiceMap.get(invObj.Id).SalesOrderInstallment__r.SalesOrder__c;
                        log.Sales_Order__c = invoiceMap.get(invObj.Id).SalesOrderInstallment__r.SalesOrder__c;
                        log.ClassName__c = 'Paid';
                        log.Collected_Down_Payment_Amount__c = invObj.AppliedAmount__c;
                        log.Total_Down_Payment__c = invObj.InvoiceAmount__c;
                        logUpdate.add(log);
                    }else if(invObj.InvoiceStatus__c == 'Partially Paid'){ 
                        Logger__c log = new Logger__c();
                        log.externalUpdate__c = invoiceMap.get(invObj.Id).SalesOrderInstallment__r.SalesOrder__c;
                        log.Sales_Order__c = invoiceMap.get(invObj.Id).SalesOrderInstallment__r.SalesOrder__c;
                        log.ClassName__c = 'Partially Paid';
                        log.Collected_Down_Payment_Amount__c = invObj.AppliedAmount__c;
                        log.Total_Down_Payment__c = invObj.InvoiceAmount__c;
                        logUpdate.add(log);
                    }else if(invObj.InvoiceStatus__c == 'Cancelled'){
                        Logger__c log = new Logger__c();
                        log.externalUpdate__c = invoiceMap.get(invObj.Id).SalesOrderInstallment__r.SalesOrder__c;
                        log.Sales_Order__c = invoiceMap.get(invObj.Id).SalesOrderInstallment__r.SalesOrder__c;
                        log.ClassName__c = 'Cancelled';
                        log.Collected_Down_Payment_Amount__c = invObj.AppliedAmount__c;
                        log.Total_Down_Payment__c = invObj.InvoiceAmount__c;
                        logUpdate.add(log);
				  }else if((invObj.AppliedAmount__c + (Decimal.valueOf(System.Label.DownpaymentBufferAmount))) >= invObj.InvoiceAmount__c){
                        Logger__c log = new Logger__c();
                        log.ClassName__c = 'Collected';
                        log.externalUpdate__c = invoiceMap.get(invObj.Id).SalesOrderInstallment__r.SalesOrder__c;
                        log.Sales_Order__c = invoiceMap.get(invObj.Id).SalesOrderInstallment__r.SalesOrder__c;
                        log.Collected_Down_Payment_Amount__c = invObj.AppliedAmount__c;
                        log.Total_Down_Payment__c = invObj.InvoiceAmount__c;
                        logUpdate.add(log);
                    }else if(invObj.AppliedAmount__c > 0 && (invObj.AppliedAmount__c + (Decimal.valueOf(System.Label.DownpaymentBufferAmount))) < invObj.InvoiceAmount__c){
                        Logger__c log = new Logger__c();
                        log.Sales_Order__c = invoiceMap.get(invObj.Id).SalesOrderInstallment__r.SalesOrder__c;
                        log.externalUpdate__c = invoiceMap.get(invObj.Id).SalesOrderInstallment__r.SalesOrder__c;
                        log.ClassName__c = 'Partially Collected';
                        log.Collected_Down_Payment_Amount__c = invObj.AppliedAmount__c;
                        log.Total_Down_Payment__c = invObj.InvoiceAmount__c;
                        logUpdate.add(log);
                    }else{
                        Logger__c log = new Logger__c();
                        log.Sales_Order__c = invoiceMap.get(invObj.Id).SalesOrderInstallment__r.SalesOrder__c;
                        log.externalUpdate__c = invoiceMap.get(invObj.Id).SalesOrderInstallment__r.SalesOrder__c;
                        log.ClassName__c = 'Generated';
                        log.Collected_Down_Payment_Amount__c = invObj.AppliedAmount__c;
                        log.Total_Down_Payment__c = invObj.InvoiceAmount__c;
                        logUpdate.add(log);
                    }
                }
                if(!logUpdate.isEmpty()){
                    try{
                    	upsert logUpdate externalUpdate__c;
                    }catch(Exception e){}
                } 
            } 
        }
    }
    public static void checkSPAStatus(Set<Id> salesOrderIdSet){
        List<Documents__c> salesOrderDocs = [SELECT Id, Name, SalesOrder__c, Status__c FROM Documents__c WHERE SalesOrder__c =: salesOrderIdSet AND Name LIKE '%SPA%' AND Status__c = 'Uploaded' ORDER BY Name];
        if(!salesOrderDocs.isEmpty()){
            Set<Id> spaStsstepCloseId = new Set<Id>();
            Set<Id> spaSignedCustomerStsstepCloseId = new Set<Id>();
            Set<Id> spaSignedMODONStsstepCloseId = new Set<Id>();
            Map<Id,List<Documents__c>> spaDocMap = new Map<Id,List<Documents__c>>();
            for(Documents__c doc:salesOrderDocs){
                if(spaDocMap.containsKey(doc.SalesOrder__c)){
                    spaDocMap.get(doc.SalesOrder__c).add(doc);
                }else{
                    spaDocMap.put(doc.SalesOrder__c,new List<Documents__c>{doc});
                }
            }
            System.debug('spaDocMap::'+spaDocMap);
            Map<Id,SalesOrder__c> soUpdateMap = new Map<Id,SalesOrder__c>();
            for(Id soId: spaDocMap.keySet()){
                for(Documents__c doc:spaDocMap.get(soId)){
                    System.debug('docName:'+doc.Name);
                    if(doc.Name == 'Signed SPA (Modon)' && doc.Status__c == 'Uploaded'){
                        spaSignedMODONStsstepCloseId.add(soId);
                    }
                    if(doc.Name == 'Signed SPA (Customer)' && doc.Status__c == 'Uploaded'){
                        spaSignedCustomerStsstepCloseId.add(soId);
                    }
                    if(doc.Name == 'SPA' && doc.Status__c == 'Uploaded'){
                        spaStsstepCloseId.add(soId);
                    }
                    System.debug('spaStsstepCloseId:'+spaStsstepCloseId);
                }
            }
            List<Logger__c> logUpdate = new List<Logger__c>();
            if(!spaStsstepCloseId.isEmpty()){
                logUpdate.clear();
                for(SalesOrder__c so:[SELECT Id,SPAStatus__c FROM SalesOrder__c WHERE Id IN: spaStsstepCloseId]){
                    Logger__c log = new Logger__c();
                    log.Sales_Order__c = so.id;
                    log.ExecutingProcessName__c = 'SPA Generated';
                    log.externalUpdate__c = so.Id;
                    logUpdate.add(log);
                }
            }
            if(!spaSignedCustomerStsstepCloseId.isEmpty()){
                logUpdate.clear();
                for(SalesOrder__c so:[SELECT Id FROM SalesOrder__c WHERE Id IN: spaStsstepCloseId]){
                    Logger__c log = new Logger__c();
                    log.Sales_Order__c = so.id;
                    log.ExecutingProcessName__c = 'Pending for Validation';
                    log.externalUpdate__c = so.Id;
                    logUpdate.add(log);
                }
            }
            if(!spaSignedMODONStsstepCloseId.isEmpty()){
                logUpdate.clear();
                for(SalesOrder__c so:[SELECT Id FROM SalesOrder__c WHERE Id IN: spaStsstepCloseId]){
                    Logger__c log = new Logger__c();
                    log.Sales_Order__c = so.id;
                    log.ExecutingProcessName__c = 'SPA Signed (Modon)';
                    log.externalUpdate__c = so.Id;
                    logUpdate.add(log);
                }
            }
            if(!logUpdate.isEmpty()){
                upsert logUpdate externalUpdate__c;
            }
            
        }
    }
    public static void updatePDCStatus(Set<Id> soIdset){
        Set<Id> receiptIdset = new Set<Id>();
        for(Receipt__c rc:[SELECT Id FROM Receipt__c WHERE SalesOrder__c IN:soIdset AND SalesOrderInstallment__c != null]){
            receiptIdset.add(rc.Id);
        }
        Set<Id> invoiceIdset = new Set<Id>();
        Map<Id,decimal> soTotalAmt = new Map<Id,decimal>();
        for(Allocation__c alloc:[SELECT Id,Invoice__c,Invoice__r.Sales_Order__c,Invoice__r.SalesOrderInstallment__r.SalesOrder__c,Receipt__c,Invoice__r.SalesOrderInstallment__r.SalesOrder__r.TotalAmount__c FROM Allocation__c WHERE Receipt__c IN: receiptIdset AND Invoice__r.SalesOrderInstallment__c <> null AND Invoice__r.SalesOrderInstallment__r.SalesOrder__r.UAE_Resident_Status__c !='Non-Resident']){
            if(alloc.Invoice__r.SalesOrderInstallment__r.SalesOrder__c <> null){
                soTotalAmt.put(alloc.Invoice__r.SalesOrderInstallment__r.SalesOrder__c,alloc.Invoice__r.SalesOrderInstallment__r.SalesOrder__r.TotalAmount__c);
                invoiceIdset.add(alloc.Invoice__c);
            }
        }
        Map<Id,decimal> pdcCount = new Map<Id,decimal>();
        Map<Id,Set<Id>> pdcReceiptMap = new Map<Id,Set<Id>>();
        if(!soIdset.isEmpty()){
            for(Allocation__c alloc:[SELECT Id,Invoice__c,Invoice__r.Sales_Order__c,Invoice__r.SalesOrderInstallment__r.SalesOrder__c,Receipt__c FROM Allocation__c WHERE Invoice__r.SalesOrderInstallment__r.SalesOrder__c IN:soIdset AND Receipt__r.Is_PDC__c = true]){
                if(alloc.Invoice__r.SalesOrderInstallment__c <> null && alloc.Invoice__r.SalesOrderInstallment__r.SalesOrder__c <> null && pdcReceiptMap.containsKey(alloc.Invoice__r.SalesOrderInstallment__r.SalesOrder__c)){
                    pdcReceiptMap.get(alloc.Invoice__r.SalesOrderInstallment__r.SalesOrder__c).add(alloc.Receipt__c);  
                }else if(alloc.Invoice__r.SalesOrderInstallment__c <> null && alloc.Invoice__r.SalesOrderInstallment__r.SalesOrder__c <> null){
                    pdcReceiptMap.put(alloc.Invoice__r.SalesOrderInstallment__r.SalesOrder__c,new Set<Id>{alloc.Receipt__c}); 
                }
            }
            Map<Id,decimal> overAllPDCAmount = new Map<Id,Decimal>();
            for(AggregateResult agg: [SELECT SUM(Invoice__r.AppliedAmount__c) SUMVAL,Invoice__r.SalesOrderInstallment__r.SalesOrder__c SOID FROM Allocation__c WHERE Invoice__r.SalesOrderInstallment__r.SalesOrder__c IN:soIdset AND Receipt__r.Is_PDC__c = true GROUP BY Invoice__r.SalesOrderInstallment__r.SalesOrder__c]){
                overAllPDCAmount.put((Id)agg.get('SOID'), (Decimal) agg.get('SUMVAL'));
            }
            List<Logger__c> logUpdate = new List<Logger__c>();
            for(Id soId: soIdset){
                Logger__c log = new Logger__c();
                log.externalUpdate__c = soId;
                log.No_Of_PDC_Collected__c = pdcReceiptMap.containsKey(soId) ? pdcReceiptMap.get(soId).size():0;
                log.Integration_Status_Code__c = log.No_Of_PDC_Collected__c > 0 ? 'Yes' : 'No';
                log.Applied_PDC_Amount__c = overAllPDCAmount.containsKey(soId) ? overAllPDCAmount.get(soId) : 0;
                logUpdate.add(log);
            }
            if(!logUpdate.isEmpty()){
                upsert logUpdate externalUpdate__c;
            }
        }
    }
}