/**
 * @***************************************           : ***************************************
 * @Name                                              : Enter description here
 * @Description                                       : Enter description here
 * @Usage                                             : Enter usage here
 * @Author                                            : AMGS
 * @------------------------------------------------  : ------------------------------------------------
 * @Version Comment                                   : 1.0
 * @Author                                            : Fatima Khan
 * @Date                                              : 10-10-2025
 * @***************************************           : ***************************************
**/
public with sharing class SalesOrderSPAApprovalController {

    @AuraEnabled(cacheable=true)
    public static List<SalesOrder__c> getPendingSPAApprovals() {
        return [
            SELECT Id, Name, Unit__r.Name, SPAStatus__c, SPA_Voided_Approval_Status__c, SPA_Voided_Approve_Reject_Comments__c, SPA_Voided_By__r.Name,SPAVoidedReason__c
            FROM SalesOrder__c
            WHERE SPA_Voided_Approval_Status__c ='Submitted'
        ];
    }

    @AuraEnabled
    public static void approveSPA(Id salesOrderId) {
        SalesOrder__c so = [SELECT Id FROM SalesOrder__c WHERE Id = :salesOrderId LIMIT 1];
        so.SPA_Voided_Approval_Status__c = 'Approved';
        update so;
    }

    @AuraEnabled
    public static void rejectSPA(Id salesOrderId, String comments) {
        SalesOrder__c so = [SELECT Id FROM SalesOrder__c WHERE Id = :salesOrderId LIMIT 1];
        so.SPA_Voided_Approval_Status__c = 'Rejected';
        so.SPA_Voided_Approve_Reject_Comments__c = comments;
        update so;
    }
}