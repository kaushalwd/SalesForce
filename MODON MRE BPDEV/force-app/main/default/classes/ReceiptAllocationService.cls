public without sharing class ReceiptAllocationService {

    public static List<Allocation__c> getReceiptAllocationsByReceiptIds(Set<Id> receiptIds){

        List<Allocation__c> receiptApplicationList = new List<Allocation__c>();
        receiptApplicationList = [
            select id,AllocationAmount__c,AllocationDate__c,ApprovedReceiptAmount__c,InProgressReceiptAmount__c,
            Invoice__c,OICIntegrationMessage__c,OICIntegrationStatus__c,
            OICNoOfRetries__c,OraclePartyId__c,OracleSyncStatus__c,
            Receipt__c,Status__c,Invoice__r.SalesOrderInstallment__c
            FROM Allocation__c
            WHERE Receipt__c IN :receiptIds AND (
                (Receipt__r.Status__c = 'Approved'
                OR Receipt__r.Status__c = 'Cleared')
            ) and AllocationAmount__c >0
            order by Invoice__c
        ];
          
        return receiptApplicationList;
    }
    
    public static List<Allocation__c> getUnAppliedChargeReceiptAllocationsByReceiptIds(Set<Id> receiptIds){
            List<Allocation__c> receiptApplicationList = new List<Allocation__c>();
            receiptApplicationList = [
                select id,AllocationAmount__c,AllocationDate__c,ApprovedReceiptAmount__c,InProgressReceiptAmount__c,
                Invoice__c,OICIntegrationMessage__c,OICIntegrationStatus__c,
                OICNoOfRetries__c,OraclePartyId__c,OracleSyncStatus__c,Invoice__r.Charge__r.PaymentStatus__c,
                Receipt__c,Status__c,Invoice__r.SalesOrderInstallment__c from  Allocation__c
                WHERE Receipt__c IN :receiptIds AND AllocationAmount__c = 0 AND srInitiated__c = TRUE
                AND  Invoice__r.Charge__c != NULL  FOR UPDATE
            ];
            return receiptApplicationList;
    }
    
    public static List<Allocation__c> getReceiptAllocationsByReceipts(Set<Id> receiptIds){

        List<Allocation__c> receiptApplicationList = new List<Allocation__c>();
        receiptApplicationList = [select id,AllocationAmount__c,AllocationDate__c,ApprovedReceiptAmount__c,InProgressReceiptAmount__c,
                Invoice__c,OICIntegrationMessage__c,OICIntegrationStatus__c,
                OICNoOfRetries__c,OraclePartyId__c,OracleSyncStatus__c,Invoice__r.Charge__r.PaymentStatus__c,
                Receipt__c,Status__c,Invoice__r.SalesOrderInstallment__c from  Allocation__c
        WHERE Receipt__c IN :receiptIds AND (
                (Receipt__r.Status__c = 'Approved'
                OR Receipt__r.Status__c = 'Cleared')
            )
    ];
          
        return receiptApplicationList;
    }
    
    public static void unapplyReceiptApplications(ServiceRequest__c objSR){
        
        String receptIDs ;
        Decimal debitNoteAmount = 0;
        system.debug('-----------unapplyReceiptApplications------------');
        List<Receipt__c> receiptList = ReceiptService.getClearedAndConfirmedReceiptsBySalesOrderIds(
            new Set<Id>{objSR.SalesOrder__c}
        );
        system.debug('-----------unapplyReceiptApplications----receiptList --------'+receiptList );
        List<Allocation__c> unapplyReceiptAllocationList = new List<Allocation__c>();
        
        Map<Id, Receipt__c> receiptmap = new Map<Id, Receipt__c>(receiptList);
        
        Map<Id, Decimal> receiptAllocationAmountTransferMap = new Map<Id, Decimal>();
        
        List<Allocation__c> receiptApplicationList = ReceiptAllocationService.getReceiptAllocationsByReceiptIds(receiptmap.keySet());
        system.debug('-----------unapplyReceiptApplications----receiptApplicationList --------'+receiptApplicationList );
        
        for(Allocation__c receiptAllocation :receiptApplicationList){
            if(receiptAllocation.AllocationAmount__c > 0 && (receiptAllocation.Invoice__r.SalesOrderInstallment__c != NULL)){
                debitNoteAmount = debitNoteAmount+receiptAllocation.AllocationAmount__c;
                if(receiptAllocationAmountTransferMap.containsKey(receiptAllocation.Receipt__c)){
                    Decimal allocationAmount = receiptAllocationAmountTransferMap.get(receiptAllocation.Receipt__c)+receiptAllocation.AllocationAmount__c;
                    receiptAllocationAmountTransferMap.put(receiptAllocation.Receipt__c,allocationAmount);
                }else{
                    receiptAllocationAmountTransferMap.put(receiptAllocation.Receipt__c,receiptAllocation.AllocationAmount__c);
                }
                unapplyReceiptAllocationList.add(receiptAllocation);
            }
        }
        system.debug('-----------unapplyReceiptApplications----debitNoteAmount --------'+debitNoteAmount);

        if(debitNoteAmount != NULL && debitNoteAmount >0){
            objSR.DebitNoteAmount__c = debitNoteAmount;
            update objSR;
        }
        system.debug('-----------unapplyReceiptApplications----objSR--------'+objSR);
       
        List<Receipt__c> recToUpdate = new  List<Receipt__c>();
        if(receiptAllocationAmountTransferMap != null){
            for(Receipt__c rec : [SELECT id , Allocation_Amount_on_Transfer__c from Receipt__c where id in :receiptAllocationAmountTransferMap.keySet()]){
                if(receiptAllocationAmountTransferMap.containsKey(rec.Id)){
                    rec.Allocation_Amount_on_Transfer__c = receiptAllocationAmountTransferMap.get(rec.Id);
                    recToUpdate.add(rec);
                }
            }
        }
        System.debug('-----------recToUpdate----------------'+recToUpdate);
        if(!recToUpdate.isEmpty()){
            update recToUpdate;
        }
        if(!unapplyReceiptAllocationList.isEmpty()){
            unapplyReceiptApplications(unapplyReceiptAllocationList);
        }
    }
    
    public static List<Allocation__c> unapplyReceiptApplications(List<Allocation__c> receiptApplicationList){
        if(!receiptApplicationList.isEmpty()){
            for(Allocation__c receiptApplication : receiptApplicationList){
                receiptApplication.AllocationDate__c= Date.today();
                receiptApplication.AllocationAmount__c= 0;
                receiptApplication.OICIntegrationMessage__c= NULL;
                receiptApplication.OICIntegrationStatus__c= Constants.SUCCESS_STATUS;
                receiptApplication.srInitiated__c = TRUE;
            }
            if(receiptApplicationList.size()>0)update receiptApplicationList;
            System.debug('-----------receiptApplicationList--unapplied--------------'+receiptApplicationList);
        }
        return receiptApplicationList;
    }
    
    public static void UnApplyChargeReceiptApplicationAndValidateSync(ServiceRequest__c objSR){
              
        List<Receipt__c> receiptList = ReceiptService.getClearedAndConfirmedReceiptsBySalesOrderIds(
            new Set<Id>{objSR.SalesOrder__c}
        );
        
        Map<Id, Receipt__c> receiptmap = new Map<Id, Receipt__c>(receiptList);
        
        List<Allocation__c> receiptApplicationList = ReceiptAllocationService.getUnAppliedChargeReceiptAllocationsByReceiptIds(receiptmap.keySet());
        if(receiptApplicationList.size() > 0){
        
            //Validating the Receipts Allocation
        }else {
            unapplyReceiptApplicationsRelatedToCharge(objSR);
        }
    }
    
    public static void unapplyReceiptApplicationsRelatedToCharge(ServiceRequest__c objSR){
        
        Decimal chargeAmount = 0;
        List<Receipt__c> receiptList = ReceiptService.getClearedAndConfirmedReceiptsBySalesOrderIds(
            new Set<Id>{objSR.SalesOrder__c}
        );
        List<Allocation__c> unapplyReceiptAllocationList = new List<Allocation__c>();
        
        Map<Id, Receipt__c> receiptmap = new Map<Id, Receipt__c>(receiptList);
        
        List<Allocation__c> receiptApplicationList = ReceiptAllocationService.getReceiptAllocationsByReceiptIds(receiptmap.keySet());
        
        for(Allocation__c receiptAllocation :receiptApplicationList){
            if(receiptAllocation.AllocationAmount__c > 0 && receiptAllocation.Invoice__r.Charge__c != NULL
                && receiptAllocation.Invoice__r.Charge__r.PaymentStatus__c !='Cancelled'
            ){
               chargeAmount = chargeAmount + receiptAllocation.AllocationAmount__c ;
               unapplyReceiptAllocationList.add(receiptAllocation);
            }
        }
        
        if(chargeAmount != NULL && chargeAmount != 0)
        {
            objSR.ChargeAmount__c = chargeAmount;
            update objSR;
        }
        if(!unapplyReceiptAllocationList.isEmpty()){
            unapplyReceiptApplications(unapplyReceiptAllocationList);
        }
    }
    
    public static List<Allocation__c> createLogicalReceiptAllocations(String receiptId, decimal allocateAmnt,string salesOrderId){
        
        List<Invoice__c> invoices = [SELECT Id,InvoiceBalance__c,TotalPaidAmount__c,InvoiceAmount__c,SalesOrderInstallment__c,
            SalesOrderInstallment__r.MilestoneNumber__c FROM Invoice__c 
            where SalesOrderInstallment__r.SalesOrder__c =:salesOrderId 
            and InvoiceBalance__c >0 
            and isCancelled__c = false
            order by SalesOrderInstallment__r.MilestoneNumber__c asc
        ];
        return createLogicalReceiptAllocations(receiptId, allocateAmnt, invoices);
    }

    // Same split as createLogicalReceiptAllocations(receiptId, amount, salesOrderId): walk installment
    // invoices in milestone order and consume allocateAmnt. No SOQL — callers bulk-query first.
    public static List<Allocation__c> createLogicalReceiptAllocations(String receiptId, decimal allocateAmnt, List<Invoice__c> invoices){
        List<Allocation__c> allocationList = new List<Allocation__c>();
        if (invoices == null || invoices.isEmpty() || allocateAmnt == null) {
            return allocationList;
        }

        for(Invoice__c inv : invoices){
            if(allocateAmnt>0 && inv.InvoiceBalance__c >0){
                
                decimal allocationAmount = allocateAmnt > inv.InvoiceBalance__c ?  inv.InvoiceBalance__c : allocateAmnt ;
                allocateAmnt = allocateAmnt - allocationAmount;                
                system.debug('-----------allocationAmount ----------------'+allocationAmount );
                system.debug('-----------allocateAmnt ----------------'+allocateAmnt);

                Allocation__c allObj = new Allocation__c();
                allObj.Invoice__c = inv.Id;
                allObj.Receipt__c = receiptId;
                allObj.AllocationAmount__c = allocationAmount;
                allObj.AllocationDate__c = System.today();
                allObj.Status__c = 'Applied';
                allocationList.add(allObj);
            }
        }
        system.debug('-----------allocationList----------------'+allocationList);
        return allocationList;
    }
    
}