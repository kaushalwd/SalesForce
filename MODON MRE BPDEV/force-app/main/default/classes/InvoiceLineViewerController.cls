/**
 * @description       : 
 * @author            : ChangeMeIn@UserSettingsUnder.SFDoc
 * @group             : 
 * @last modified on  : 06-11-2025
 * @last modified by  : ChangeMeIn@UserSettingsUnder.SFDoc
**/
public with sharing class InvoiceLineViewerController {
    @AuraEnabled
    public static List<Invoice_Line__c> getInvoiceLines(Id bundleId) {
        return [
            SELECT Commission_Line__r.Broker_Agency_Agent__c,   
                   Sales_Agent__c,
                   Sales_Manager__c,
                   Category_Of_Sale__c, 
                   Type_Of_Commission__c,
            		Total_Unit_Price__c,
                  Total_Commission_Amount__c,
                   Current_Commission_Payout_Now__c,
                   Is_Hold__c,
                   Hold_Reason__c,
                   Unit_Name__c,Pending_Commission_Amount__c,Commission_Payout_Percent__c,Commission_Line_Name__c,
            Commission_Amount_Already_Paid__c,Commission_Line__c
            FROM Invoice_Line__c
            WHERE Invoice_Bundle__c = :bundleId
        ];
    }

    @AuraEnabled
    public static void updateHoldStatus(Id invoiceLineId, Boolean onHold, String holdReason) {
        Invoice_Line__c line = [
            SELECT Id, Is_Hold__c, Hold_Reason__c,Total_Commission_Amount__c,Current_Commission_Payout_Now__c,Total_Unit_Price__c,Pending_Commission_Amount__c,Commission_Amount_Already_Paid__c,Commission_Payout_Percent__c,Commission_Line__c,Commission_Line_Name__c
            FROM Invoice_Line__c
            WHERE Id = :invoiceLineId
            LIMIT 1
        ];
        line.Is_Hold__c = onHold;
        line.Hold_Reason__c = onHold ? holdReason : null;
        update line;
    }
}