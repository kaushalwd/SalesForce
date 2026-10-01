/**
 * @description  FastTrack KYC — Approval Outcome Handler (Flow entry point).
 *
 *               Apex only allows one @InvocableMethod per class.
 *               FastTrackKYCService already uses its slot for checkFromFlow,
 *               so this small class owns the approval outcome invocable.
 *
 *  Flow setup (Record-Triggered Flow on Lead):
 *    Trigger:  A record is updated
 *    Criteria: New_Account_Exception_Status__c CHANGED
 *              AND New_Account_Exception_Status__c IN ('Approved', 'Rejected')
 *    Action:   Apex Action → FastTrackKYCApprovalHandler.handleOutcome
 *    Input:    leadId  = {!$Record.Id}
 *              newStatus = {!$Record.New_Account_Exception_Status__c}
 *              ownerId   = {!$Record.OwnerId}
 *
 *  Alternatively, call FastTrackKYCService.handleApprovalOutcome()
 *  from your LeadTriggerHandler after update — no Flow needed.
 *
 * @group   KYC
 */
public without sharing class FastTrackKYCApprovalHandler {

    @InvocableMethod(
        label='FastTrack KYC — Handle Approval Outcome'
        description='Updates the lead when a KYC exception is approved or rejected. Call from a Record-Triggered Flow on Lead.'
    )
    public static void handleOutcome(List<ApprovalOutcomeInput> inputs) {
        for (ApprovalOutcomeInput inp : inputs) {
            if (String.isBlank(inp.newStatus) || inp.leadId == null) {
                continue;
            }

            if (inp.newStatus == 'Approved') {
                // Ensure Existing_Account__c is null so Database.convertLead()
                // creates a new account rather than reusing the old one.
                update new Lead(
                    Id                  = inp.leadId,
                    Existing_Account__c = null
                );
                FastTrackKYCService.notifySalesAssociate(inp.leadId, inp.ownerId, 'approved');
            } else if (inp.newStatus == 'Rejected') {
                FastTrackKYCService.notifySalesAssociate(inp.leadId, inp.ownerId, 'rejected');
            }
        }
    }

    public class ApprovalOutcomeInput {
        @InvocableVariable(label='Lead Id' required=true)
        public Id leadId;

        @InvocableVariable(label='New Status (Approved or Rejected)' required=true)
        public String newStatus;

        @InvocableVariable(label='Lead Owner Id')
        public Id ownerId;
    }
}