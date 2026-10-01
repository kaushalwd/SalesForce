/**
* @description       : 
* @author            : Kumaravel Mathivanan
* @group             : 
* @Created modified on  : 07-01-2026 * 
* * --------------------------------------------------------------------------------------------------------------------
* Version       Author                      Date            Comment                                                                       
* 1.0           Kumaravel Mathivanan        07-01-2026     Initial Draft 
* 
**/

public with sharing class ReceiptProgressIndicatorController {
    public ReceiptProgressIndicatorController() {

    }

    @AuraEnabled(cacheable=true)
    public static String getCurrentStep(Id recordId) {
        Receipt__c rec = [
            SELECT Verified_Not_Sent_to_Oracle__c,
                   Ready_for_Approval_Oracle__c,
                   Ready_for_Remittance_Oracle__c,
                   Receipt_Cleared_Salesforce__c, Receipt_Approved_Checker__c
            FROM Receipt__c
            WHERE Id = :recordId
            LIMIT 1
        ];

        if(!rec.Receipt_Approved_Checker__c){
            return 'SF Approval Pending';
        }
        if(rec.Receipt_Approved_Checker__c){
            if(!rec.Verified_Not_Sent_to_Oracle__c && rec.Ready_for_Approval_Oracle__c){
                return 'Sent to EBS';
            }else if(rec.Verified_Not_Sent_to_Oracle__c){
                return 'Verified - Not Sent to Oracle'; 
            }
            if (rec.Receipt_Cleared_Salesforce__c) {
                return 'Cleared';
            }
            if (rec.Ready_for_Remittance_Oracle__c) {
                return 'Awaiting Remittance';
            }            
        }

        /*if (rec.Ready_for_Approval_Oracle__c) {
            return 'Ready for Approval';
        }
        if (rec.Verified_Not_Sent_to_Oracle__c) {
            return 'Verified - Not Sent to Oracle';
        }*/

        return 'Start';
    }   


}