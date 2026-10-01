/**
 * @description       : SOA data aggregation for LWC (updated for donut charts)
 * @author            : Krishna Chaitanya
 * @last modified on  : 05-13-2025
**/
public with sharing class SOAController {
    
    @AuraEnabled(cacheable=true)
    public static SOAWrapper getSOAData(Id salesOrderId) {
        SOAWrapper result = new SOAWrapper();

        // Get Sales Order
        result.salesOrder = [
            SELECT 
                Id, SOCreationDate__c, SPACustomerSignedDate__c, ProjectName__c, TotalAmount__c,
                CustomerAccount__r.Name, CustomerAccount__r.UnifiedNumber__c,
                Unit__r.Name, Unit__r.UnitClassification__c, Unit__r.PlotNo__c,
                Unit__r.Phase__r.Name, Unit__r.District__c,
                Unit__r.BuildingNo__c,
                VirtualAccount__r.ESCROWAccountName__c,
                VirtualAccount__r.VirtualIBANNumber__c,
                VirtualAccount__r.VirtualAccountNumber__c,
                VirtualAccount__r.SwiftCode__c,
                VirtualAccount__r.Escrow_Bank_Name__c
            FROM SalesOrder__c 
            WHERE Id = :salesOrderId
            LIMIT 1
        ];

        // Get Installments
        result.installments = [
            SELECT Id, InvoiceAmount__c, AppliedAmount__c, InvoiceBalance__c,InvoiceDate__c,
                   SalesOrderInstallment__r.MilestoneDescription__c,
                   SalesOrderInstallment__r.MilestoneNumber__c,
                   SalesOrderInstallment__r.Milestone__c,
                   SalesOrderInstallment__r.MilestoneDate__c,
                   (SELECT Id, AllocationAmount__c, AllocationDate__c FROM Allocations__r)
            FROM Invoice__c
            WHERE SalesOrderInstallment__c != null 
              AND Sales_Order__c = null
              AND SalesOrderInstallment__r.SalesOrder__c = :salesOrderId
            ORDER BY SalesOrderInstallment__r.MilestoneNumber__c
        ];

        // Get Other Payments
        result.otherPayments = [
            SELECT Id, Name, Charge__r.Type__c, InvoiceAmount__c, AppliedAmount__c, InvoiceBalance__c, InvoiceDate__c
            FROM Invoice__c
            WHERE SalesOrderInstallment__c = null 
              AND Sales_Order__c = :salesOrderId
        ];

        // Totals & Counters
        for (Invoice__c inv : result.installments) {
            result.totalInstallments++;
            result.totalAmount += inv.InvoiceAmount__c != null ? inv.InvoiceAmount__c : 0;
            result.totalCollected += inv.AppliedAmount__c;
                result.totalOutstanding += inv.InvoiceBalance__c;

            if (inv.AppliedAmount__c > 0) {
                result.totalPaidInstallments++;
            }
        }

        for (Invoice__c invOther : result.otherPayments) {
            result.totalOtherAmount += invOther.InvoiceAmount__c;
            result.totalOtherCollected += invOther.AppliedAmount__c;
            result.totalOtherOutstanding += invOther.InvoiceBalance__c;
        }

        result.grandTotalOutstanding = result.totalOutstanding + result.totalOtherOutstanding;

        // Fill Installment Summary
        result.installmentSummary = new SalesOrderInstallmentSummary();
        result.installmentSummary.totalPaidInstallments = result.totalPaidInstallments;
        result.installmentSummary.totalInstallments = result.totalInstallments;
        result.installmentSummary.totalCollectedAmount = result.totalCollected;
        result.installmentSummary.balanceAmount = result.totalOutstanding;
        if ((result.totalCollected + result.totalOutstanding) > 0) {
            result.installmentSummary.paidPercentage = (result.totalCollected / (result.totalCollected + result.totalOutstanding)) * 100;
        } else {
            result.installmentSummary.paidPercentage = 0;
        }

        return result;
    }

    public class SOAWrapper {
        @AuraEnabled public SalesOrder__c salesOrder;
        @AuraEnabled public List<Invoice__c> installments;
        @AuraEnabled public List<Invoice__c> otherPayments;

        @AuraEnabled public Decimal totalAmount = 0;
        @AuraEnabled public Decimal totalCollected = 0;
        @AuraEnabled public Decimal totalOutstanding = 0;
        @AuraEnabled public Decimal totalOtherAmount = 0;
        @AuraEnabled public Decimal totalOtherCollected = 0;
        @AuraEnabled public Decimal totalOtherOutstanding = 0;
        @AuraEnabled public Decimal grandTotalOutstanding = 0;
        @AuraEnabled public Date currentdate = system.today();

        @AuraEnabled public Integer totalInstallments = 0;
        @AuraEnabled public Integer totalPaidInstallments = 0;

        // New - Installment Summary for charts
        @AuraEnabled public SalesOrderInstallmentSummary installmentSummary;
    }

    public class SalesOrderInstallmentSummary {
        @AuraEnabled public Integer totalPaidInstallments = 0;
        @AuraEnabled public Integer totalInstallments = 0;
        @AuraEnabled public Decimal totalCollectedAmount = 0;
        @AuraEnabled public Decimal balanceAmount = 0;
        @AuraEnabled public Decimal paidPercentage = 0;
    }
}