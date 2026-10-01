/**
* @description       : combined SOA for all the SO's
* @author            : Kumaravel Mathivanan
* @group             : 
* @created on        : 02-18-2026
**/
public with sharing class CombinedSOAController {

    public List<Invoice__c> PayemntSalesList {get; set;}
    public List<Invoice__c> PayemntSalesListSOAAll {get; set;}
    public List<SalesOrder__c> PayemntSalesListAll {get; set;}

    public Date Today { get { return Date.today(); } }
    public SalesOrder__c salesOrder {get; set;}

    public Decimal totalAmountSOA {get; set;}
    public Decimal totalAmountCollectedSOA {get; set;}
    public Decimal totalAmountOutstandingSOA {get; set;}

    public Decimal totalLatePayment {get; set;}
    public String currentRecordId {get; set;}
    
    //  Custom Map for computed balances (only cleared allocations)
    public Map<Id, Decimal> invoiceClearedBalanceMap { get; set; }

    public Map<Id, Decimal> invoiceTotalAmountMap { get; set; }
    public Map<Id, Decimal> invoiceClearedAmountMap { get; set; }
    public Map<Id, Decimal> invoiceOutstandingAmountMap { get; set; }
    
    public CombinedSOAController() {
        currentRecordId = ApexPages.CurrentPage().getParameters().get('id');
        invoiceClearedBalanceMap = new Map<Id, Decimal>();
        invoiceTotalAmountMap = new Map<Id, Decimal>();
        invoiceClearedAmountMap = new Map<Id, Decimal>();
        invoiceOutstandingAmountMap = new Map<Id, Decimal>();
        if (currentRecordId != null) {
            getAllSOA();
        }
    }
    
    public void getAllSOA() {
        String SOstatusExcludeLst = System.Label.SO_Status_List;
        List<String> SOList = new List<String>();
        for (String c : SOstatusExcludeLst.split(',')) SOList.add(c.trim());

        /*salesOrder = [ SELECT Id,CustomerAccount__r.Name 
            FROM Salesorder__c
            WHERE CustomerAccount__c  =:currentRecordId  and Status__c NOT IN :SOList
            ORDER BY  name DESC  limit 1 ];*/

        if (currentRecordId != null) {
            List<SalesOrder__c> soList1 = [
                SELECT Id, CustomerAccount__r.Name
                FROM Salesorder__c
                WHERE CustomerAccount__c = :currentRecordId
                AND Status__c NOT IN :SOList
                ORDER BY Name DESC
                LIMIT 1
            ];

            if (!soList1.isEmpty()) {
                salesOrder = soList1[0];
            }
        }



        PayemntSalesListSOAAll = [SELECT Id, InvoiceAmount__c, SalesOrderInstallment__r.SalesOrder__c,  
            (SELECT Id, AllocationAmount__c,Receipt__r.Status__c
             FROM Allocations__r
             WHERE Receipt__r.Status__c = 'Cleared') 
            FROM Invoice__c
            WHERE SalesOrderInstallment__c != null
            AND Sales_Order__c = null
            AND SalesOrderInstallment__r.SalesOrder__r.CustomerAccount__c  =: currentRecordId
            AND Sales_Order__r.Status__c NOT IN :SOList
            ORDER BY  SalesOrderInstallment__r.SalesOrder__r.name Desc] ;
        
        
        PayemntSalesListAll = [ SELECT Id,Unit__r.name, Unit__r.UnitClassification__c, ProjectName__c, TotalAmount__c,  Status__c 
            FROM Salesorder__c
            WHERE CustomerAccount__c  =:currentRecordId  and Status__c NOT IN :SOList
            ORDER BY  name DESC   ];



        totalAmountSOA = 0;
        totalAmountCollectedSOA = 0;
        totalAmountOutstandingSOA = 0;
        totalLatePayment = 0;
                
        for (Invoice__c invRec : PayemntSalesListSOAAll) {
                Decimal clearedAllocSOA = 0;
                for (Allocation__c all : invRec.Allocations__r) {
                    if (all.Receipt__r != null && all.Receipt__r.Status__c =='Cleared') {
                        clearedAllocSOA += (all.AllocationAmount__c != null ? all.AllocationAmount__c : 0);
                    }
                }
                Decimal existingAmount = invoiceClearedAmountMap.containsKey(invRec.SalesOrderInstallment__r.SalesOrder__c) ? invoiceClearedAmountMap.get(invRec.SalesOrderInstallment__r.SalesOrder__c) : 0;            
                
                invoiceClearedAmountMap.put(invRec.SalesOrderInstallment__r.SalesOrder__c, existingAmount + clearedAllocSOA);
                
                Decimal invAmtCleared = clearedAllocSOA != null ? clearedAllocSOA : 0;
                totalAmountCollectedSOA = totalAmountCollectedSOA == null ? invAmtCleared : totalAmountCollectedSOA + invAmtCleared;
            
        }
        
        for(SalesOrder__c soRec: PayemntSalesListAll){
            Decimal invAmt = soRec.TotalAmount__c != null ? soRec.TotalAmount__c : 0;
            totalAmountSOA = totalAmountSOA == null ? invAmt : totalAmountSOA + invAmt;
        }
            
        
    }
    

    /** 1.0 Added Mobile PDF Download Option START **********/ 
    public PageReference downloadPDF() {
        
        
        PageReference pdfPage = Page.SOA3;
        pdfPage.getParameters().put('id', currentRecordId);
        
        Blob pdfBlob;
        
        if (!Test.isRunningTest()) {
            pdfBlob = pdfPage.getContentAsPDF();
        }else {
            pdfBlob = Blob.valueOf('Dummy PDF content');
        }
        
        
        ContentVersion cv = new ContentVersion();
        cv.Title = 'Statement_of_Account';
        cv.PathOnClient = 'StatementOfAccount.pdf';
        cv.VersionData = pdfBlob;
        insert cv;
        
        
        ContentVersion savedCV = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
        ];
        
        
        String baseUrl = URL.getOrgDomainUrl().toExternalForm();
        String downloadUrl =
            baseUrl +
            '/sfc/servlet.shepherd/document/download/' +
            savedCV.ContentDocumentId;
        
        
        PageReference pr = new PageReference(downloadUrl);
        pr.setRedirect(true);
        return pr;
    }  
    /** 1.0 Added Mobile PDF Download Option END **********/ 
}