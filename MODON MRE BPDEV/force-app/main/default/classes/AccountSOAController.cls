/*
@description       : Account-level Statement of Account (multi-SO)
@author            : Raghu Gajjela
@group             : 
@last modified on  : 23-02-2026
@last modified by  : Raghu Gajjela.
*/
public with sharing class AccountSOAController {
    
    public Id inputId { get; set; }
    public Boolean isAccountMode { get; set; }
    public Date Today { get { return Date.today(); } }
    
    public static final Set<String> EXCLUDE_STATUSES =
        new Set<String>{
            'Cancelled','Cancelled SR','Voided','Property Transfer Cancelled - SR',
                'Unit Swap Cancelled - SR','Unit Upgrade Cancelled - SR',
                'Unit Cancellation Cancelled - SR','Unit Consolidation Cancelled - SR',
                'Property Transfer Title Deed Cancelled - SR'
                };
                    
                    public class SOWrapper {
                        public SalesOrder__c salesOrder { get; set; }
                        public List<Invoice__c> PayemntSalesList { get; set; }
                        public List<Invoice__c> OtherPayemntSalesList { get; set; }
                        public String jointOwnerNames { get; set; }
                        public Map<Id, Decimal> invoiceClearedBalanceMap { get; set; }
                        public Decimal totalAmount { get; set; }
                        public Decimal totalAmountCollected { get; set; }
                        public Decimal totalAmountOutstanding { get; set; }
                        public Decimal totalOtherAmount { get; set; }
                        public Decimal totalLatePayment { get; set; }
                        public Decimal totalPercentage { get; set; }
                        public Decimal totalOtherAmountCollected { get; set; }
                        public Decimal totalOtherAmountOutstanding { get; set; }
                        public Decimal grandTotalOutstanding { get; set; }
                        
                        public SOWrapper() {
                            invoiceClearedBalanceMap = new Map<Id, Decimal>();
                            PayemntSalesList = new List<Invoice__c>();
                            OtherPayemntSalesList = new List<Invoice__c>();
                            totalAmount = 0;
                            totalAmountCollected = 0;
                            totalAmountOutstanding = 0;
                            totalOtherAmount = 0;
                            totalOtherAmountCollected = 0;
                            totalOtherAmountOutstanding = 0;
                            totalLatePayment = 0;
                            totalPercentage = 0;
                        }
                    }
    
    public List<SOWrapper> allSOARecords { get; set; }
    
    public AccountSOAController() {
        inputId = ApexPages.currentPage().getParameters().get('id');
        allSOARecords = new List<SOWrapper>();
        
        if (inputId == null) return;
        
        determineModeAndLoad();
    }
    
    private void determineModeAndLoad() {
        
        List<SalesOrder__c> soCheck = [SELECT Id FROM SalesOrder__c WHERE Id = :inputId LIMIT 1];
        
        if (!soCheck.isEmpty()) {
            isAccountMode = false;
            loadSOAForSalesOrder(inputId);
        } else {
            isAccountMode = true;
            loadAllSOAsForAccount(inputId);
        }
    }
    
    private void loadSOAForSalesOrder(Id soId) {
        loadSalesOrders(new Set<Id>{soId});
    }
    
    private void loadAllSOAsForAccount(Id accountId) {
        
        List<SalesOrder__c> soList = [SELECT Id, SOCreationDate__c, SPACustomerSignedDate__c,ProjectName__c, TotalAmount__c,CustomerAccount__r.Name,
                                      Unit__r.Type__c, Unit__r.Name,Unit__r.PlotNo__c, Unit__r.District__c,VirtualAccount__r.ESCROWAccountName__c,
                                      VirtualAccount__r.Escrow_Bank_Name__c,VirtualAccount__r.VirtualIBANNumber__c,VirtualAccount__r.Swift_Code__c,
                                      VirtualAccount__r.VirtualAccountNumber__c FROM SalesOrder__c WHERE CustomerAccount__c = :accountId AND Status__c NOT IN :EXCLUDE_STATUSES];
        
        Set<Id> soIds = new Set<Id>();
        for (SalesOrder__c so : soList) {
            soIds.add(so.Id);
        }
        
        loadSalesOrders(soIds);
    }
    
    private void loadSalesOrders(Set<Id> soIds) {
        
        if (soIds.isEmpty()) return;
        
        // Query SalesOrders
        List<SalesOrder__c> soList = [SELECT Id, SOCreationDate__c, SPACustomerSignedDate__c,ProjectName__c, TotalAmount__c,CustomerAccount__r.Name,
                                      Unit__r.Type__c, Unit__r.Name,Unit__r.PlotNo__c, Unit__r.District__c,VirtualAccount__r.ESCROWAccountName__c,
                                      VirtualAccount__r.Escrow_Bank_Name__c,VirtualAccount__r.VirtualIBANNumber__c,VirtualAccount__r.Swift_Code__c,
                                      VirtualAccount__r.VirtualAccountNumber__c FROM SalesOrder__c WHERE Id IN :soIds];
        
        Map<Id, SOWrapper> wrapperMap = new Map<Id, SOWrapper>();
        
        for (SalesOrder__c so : soList) {
            SOWrapper w = new SOWrapper();
            w.salesOrder = so;
            wrapperMap.put(so.Id, w);
        }
        
        // Joint Owners (1 query)
        for (JointOwner__c jo : [SELECT SalesOrder__c, JointOwnerAccount__r.Name FROM JointOwner__c WHERE SalesOrder__c IN :soIds]) {
            if (wrapperMap.containsKey(jo.SalesOrder__c)) {
                SOWrapper w = wrapperMap.get(jo.SalesOrder__c);
                if (w.jointOwnerNames == null)
                    w.jointOwnerNames = jo.JointOwnerAccount__r.Name;
                else
                    w.jointOwnerNames += ', ' + jo.JointOwnerAccount__r.Name;
            }
        }
        
        // Installment Invoices 
        List<Invoice__c> installmentInvoices = [SELECT Id,Name,InvoiceAmount__c,AppliedAmount__c,InvoiceBalance__c,Applied_Percentage__c,InvoiceDate__c,
                                                SalesOrderInstallment__r.SalesOrder__c,SalesOrderInstallment__r.MilestoneNumber__c,SalesOrderInstallment__r.Milestone__c,
                                                SalesOrderInstallment__r.MilestoneDate__c,SalesOrderInstallment__r.IsHandoverPayment__c,
                                                (SELECT Id,AllocationAmount__c,AllocationDate__c,Receipt__r.TransactionNumber__c,Receipt__r.Status__c,
                                                 Receipt__r.Modeofpayment__c,Receipt__r.Name FROM Allocations__r WHERE Receipt__r.Status__c = 'Cleared')
                                                FROM Invoice__c WHERE SalesOrderInstallment__r.SalesOrder__c IN :soIds AND Sales_Order__c = null AND SalesOrderInstallment__c != null];
        
        
        for (Invoice__c inv : installmentInvoices) {
            Id soId = inv.SalesOrderInstallment__r.SalesOrder__c;
            SOWrapper w = wrapperMap.get(soId);
            
            w.PayemntSalesList.add(inv);
            
            Decimal invAmt = inv.InvoiceAmount__c == null ? 0 : inv.InvoiceAmount__c;
            w.totalAmount += invAmt;
            
            Decimal collected = 0;
            for (Allocation__c a : inv.Allocations__r)
                collected += a.AllocationAmount__c == null ? 0 : a.AllocationAmount__c;
            
            w.totalAmountCollected += collected;
            Decimal balance = invAmt - collected;
            w.invoiceClearedBalanceMap.put(inv.Id, balance);
            
            if (inv.SalesOrderInstallment__r.MilestoneDate__c != null &&
                inv.SalesOrderInstallment__r.MilestoneDate__c < Today)
                w.totalAmountOutstanding += balance;
        }
        for (Invoice__c other : [SELECT Id,Name,InvoiceAmount__c,AppliedAmount__c,InvoiceBalance__c,InvoiceDate__c,Charge__r.Name,
                                 Is_ADM_Fees_and_Dari_charges__c,Sales_Order__c,
                                 (SELECT Id,AllocationAmount__c,AllocationDate__c,Receipt__r.TransactionNumber__c,Receipt__r.Status__c,Receipt__r.Modeofpayment__c,
                                  Receipt__r.Name FROM Allocations__r WHERE Receipt__r.Status__c = 'Cleared') FROM Invoice__c
                                 WHERE Sales_Order__c IN :soIds AND SalesOrderInstallment__c = null]) {
                                     
                                     SOWrapper w = wrapperMap.get(other.Sales_Order__c);
                                     
                                     w.OtherPayemntSalesList.add(other);
                                     
                                     w.totalOtherAmount += other.InvoiceAmount__c == null ? 0 : other.InvoiceAmount__c;
                                     w.totalOtherAmountCollected += other.AppliedAmount__c == null ? 0 : other.AppliedAmount__c;
                                     
                                     if (other.InvoiceBalance__c != null)
                                         w.totalOtherAmountOutstanding += other.InvoiceBalance__c;
                                 }
        
        for (SOWrapper w : wrapperMap.values()) {
            w.grandTotalOutstanding =
                w.totalAmountOutstanding + w.totalOtherAmountOutstanding;
            allSOARecords.add(w);
        }
    }
}