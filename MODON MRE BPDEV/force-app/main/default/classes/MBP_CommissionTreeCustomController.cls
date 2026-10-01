/**********************************************************************************************************************
* Name               : MBP_CommissionTreeCustomController
* Description        : This class is used as the Apex controller for the Broker Portal Commissions tab.
* Usage              : LWC components related to Broker Commissions (commissionspage)
* Created By         : Upendra Asam
* --------------------------------------------------------------------------------------------------------------------
* Version     Author                                  Date             Comment
* 1.0         upendra.asam@modon.com          24 aug 2026        Initial Draft – Core logic for fetching and
*                                                                       preparing commission line data, including
*                                                                       date-range filtering, VAT-based eligible
*                                                                       amount calculation, status-based sorting,
*                                                                       and picklist value retrieval for filters.
**********************************************************************************************************************/
public without sharing class MBP_CommissionTreeCustomController {
    
    @AuraEnabled(cacheable=true)
    public static List<CommissionWrapper> getCommissionData(String startDateStr, String endDateStr) {
        List<CommissionWrapper> finalList = new List<CommissionWrapper>();
        
        Date startDate = startDateStr != null ? Date.valueOf(startDateStr) : Date.newInstance(Date.today().year(),1,1);
        Date endDate = endDateStr != null ? Date.valueOf(endDateStr) : Date.today();
        
        DateTime startDT = DateTime.newInstance(startDate.year(), startDate.month(), startDate.day());
        DateTime endDT = DateTime.newInstance(endDate.year(), endDate.month(), endDate.day()).addDays(1).addSeconds(-1);
        
        User currentUser = [SELECT Id, ContactId, AccountId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        if (currentUser.ContactId == null || currentUser.AccountId == null) return finalList;
        
        Boolean canAcceptCommission = [SELECT Bank_Account_Number__c FROM Account WHERE Id = :currentUser.AccountId].Bank_Account_Number__c != null;
        
        List<Commission_Line__c> comms = [
            SELECT Id, Project__c, Name, Broker_Agent__r.Name, Total_Commission_Amount_Pending__c, Total_Unit_Price__c, Commission_Percent__c,Broker_Agency__r.UAEVATRegisterNumber__c,
            Total_Commission_Amount_Paid__c, Commission_Amount__c, Commission_Payout_Amount_Now__c, Status__c, Current_Commission_Payout_Now__c,
            Equity__c, Payout_Equity__c, Sales_Order__c, Sales_Order__r.Status__c,OIC_COMMISSION_CLEARANCE_DATE__c,
            Broker_Agent__c, Broker_Agency__c, Invoice_Status__c, Comments__c,Invoice_Date__c,
            Sales_Order__r.Down_Payment_Status__c,ADM_Fee_Status__c, Sales_Order__r.SPAStatus__c, Unit__c, Sales_Order__r.Unit__r.Name, Sales_Order__r.Unit__r.Phase__r.Project__r.Name,
            Tax_Invoice_Number__c,Sales_Order__r.Unit__c,Sales_Order__r.TotalAmount__c, CreatedDate, Sales_Order__r.Opportunity__r.Account.Name, Broker_Agency__r.Name,Sales_Order__r.CustomerAccount__r.Name
            FROM Commission_Line__c
            WHERE Commission_Line_Type__c = 'External'
            AND Broker_Agency__c = :currentUser.AccountId
            AND Sales_Order__r.Unit__c != null
            AND CreatedDate >= :startDT
            AND CreatedDate <= :endDT
            AND Status__c!='Internal Review In-Progress' AND  Status__c!='Not Reviewed' AND  Status__c!='Re-Calculated'
            ORDER BY Sales_Order__c, CreatedDate ASC
        ];
        
        for (Commission_Line__c cl : comms) {
            CommissionWrapper cw = new CommissionWrapper();
            cw.commissionId = cl.Id;
            cw.project = cl.Sales_Order__r.Unit__r.Phase__r.Project__r.Name;
            cw.unitNumber = cl.Sales_Order__r.Unit__r.Name;
            cw.unitPrice = cl.Sales_Order__r != null && cl.Sales_Order__r.Unit__r != null ? cl.Sales_Order__r.Unit__r.Name : null;
            cw.commissionPercent = cl.Commission_Percent__c != null ? String.valueOf(cl.Commission_Percent__c) : null;
            cw.totalCommission = cl.Commission_Amount__c;
            cw.paidAmount = cl.Total_Commission_Amount_Paid__c;
            cw.pendingAmount = cl.Total_Commission_Amount_Pending__c;
            cw.currentPayout = cl.Current_Commission_Payout_Now__c;
            cw.admFeeStatus = cl.ADM_Fee_Status__c;
            cw.clearanceDate = cl.OIC_COMMISSION_CLEARANCE_DATE__c;
            Decimal commission = cl.Commission_Amount__c != null ? cl.Commission_Amount__c : 0;
            
         if (cl.Broker_Agency__r != null &&
    String.isNotBlank(cl.Broker_Agency__r.UAEVATRegisterNumber__c)) {
        
    Decimal vat = commission * 0.05;
    cw.futureEligibleAmount = commission + vat;

} else {
    cw.futureEligibleAmount = null; 
}
            
            cw.brokerAgent = cl.Broker_Agent__r.Name;
            cw.status = cl.Status__c;
            cw.salesOrderId = cl.Sales_Order__c;
            cw.salesOrderStatus = cl.Sales_Order__r != null ? cl.Sales_Order__r.Status__c : null;
            cw.downPaymentStatus = cl.Sales_Order__r != null ? cl.Sales_Order__r.Down_Payment_Status__c : null;
            cw.spaStatus = cl.Sales_Order__r != null ? cl.Sales_Order__r.SPAStatus__c : null;
            cw.equity = cl.Equity__c;
            cw.payoutEquity = cl.Payout_Equity__c;
            cw.invoiceStatus = cl.Invoice_Status__c;
            cw.canAcceptCommission = canAcceptCommission;
            cw.taxInvoiceNumber = cl.Tax_Invoice_Number__c;
            cw.customerName = cl.Sales_Order__r.CustomerAccount__r.Name;
            cw.invoiceDate = cl.Invoice_Date__c;
            cw.totalunitprice = cl.Sales_Order__r.TotalAmount__c;
            finalList.add(cw);
        }
        
        finalList.sort(new StatusComparator());
        
        return finalList;
    }
    
    public class StatusComparator implements System.Comparator<CommissionWrapper> {
        Map<String, Integer> statusOrder = new Map<String, Integer>{
            'Fixed' => 1,  
                
                'Not Reviewed' => 2,
                'Ready To Process' => 3,
                'In Progress' => 4,
                'Completed - Partially' => 5,
                'Pending Invoice Verification' => 6,
                'Pending Finance Verification' => 7,
                'Completed' => 8,
                'Rejected' => 9
                };
                    
                    public Integer compare(CommissionWrapper a, CommissionWrapper b) {
                        Integer aOrder = statusOrder.containsKey(a.status) ? statusOrder.get(a.status) : 999;
                        Integer bOrder = statusOrder.containsKey(b.status) ? statusOrder.get(b.status) : 999;
                        if (aOrder == bOrder) return 0;
                        return aOrder < bOrder ? -1 : 1;
                    }
    }
    
    @AuraEnabled(cacheable=true)
    public static Map<String, List<Map<String, String>>> getPicklistValues() {
        Map<String, List<Map<String, String>>> picklistValues = new Map<String, List<Map<String, String>>>();
        picklistValues.put('spaStatus', getPicklistOptions('SalesOrder__c', 'SPAStatus__c'));
        picklistValues.put('downPaymentStatus', getPicklistOptions('SalesOrder__c', 'Down_Payment_Status__c'));
        picklistValues.put('status', getPicklistOptions('Commission_Line__c', 'Status__c'));
        return picklistValues;
    }
    
    private static List<Map<String, String>> getPicklistOptions(String objectName, String fieldName) {
        List<Map<String, String>> options = new List<Map<String, String>>();
        Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectName);
        Schema.DescribeSObjectResult objDescribe = objType.getDescribe();
        Map<String, Schema.SObjectField> fieldMap = objDescribe.fields.getMap();
        Schema.DescribeFieldResult fieldResult = fieldMap.get(fieldName).getDescribe();
        for (Schema.PicklistEntry entry : fieldResult.getPicklistValues()) {
            if (entry.isActive()) {
                options.add(new Map<String, String>{
                    'label' => entry.getLabel(),
                        'value' => entry.getValue()
                        });
            }
        }
        return options;
    }
    
    public class CommissionWrapper {
        @AuraEnabled public Decimal currentPayout;
        @AuraEnabled public Decimal futureEligibleAmount;
        @AuraEnabled public Id commissionId;
        @AuraEnabled public String project;
        @AuraEnabled public String brokerAgent;
        @AuraEnabled public String unitPrice;
        @AuraEnabled public String unitNumber;   
        @AuraEnabled public String commissionPercent;
        @AuraEnabled public Decimal paidAmount;
        /* BP-068: the same stored field the dashboard totals as Pending
           (MBP_manageDashboardcontroller), so the two screens agree by construction.
           Already in the SOQL above - only the wrapper was missing. */
        @AuraEnabled public Decimal pendingAmount;
        @AuraEnabled public String admFeeStatus;
        @AuraEnabled public Decimal totalunitprice;
        @AuraEnabled public Decimal totalCommission;
        @AuraEnabled public Decimal payoutNow;
        @AuraEnabled public String status;
        @AuraEnabled public Decimal equity;
        @AuraEnabled public Decimal payoutEquity;
        @AuraEnabled public String invoiceStatus;
        @AuraEnabled public Date clearanceDate;
        @AuraEnabled public String comments;
        @AuraEnabled public Id salesOrderId;
        @AuraEnabled public String salesOrderStatus;
        @AuraEnabled public String downPaymentStatus;
        @AuraEnabled public String spaStatus;
        @AuraEnabled public Boolean canAcceptCommission;
        @AuraEnabled public String taxInvoiceNumber;
        @AuraEnabled public String customerName;
        @AuraEnabled public Date invoiceDate;
    }
}