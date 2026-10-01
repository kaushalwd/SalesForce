/**
 *  Name               :AccountMergeApprovalHandler                                                       
* 	Description        : This class is used  finds pending victims, sets Approved, enqueues Queueable
*	Usage              :Merge Approval Request                                                   
* 	Created By         :Arvind Kesharwani

 *	Version       			Author                          Date            Comment   
 	1.0            		Arvind Kesharwani             04/29/2026       Intial Dreaft

 * @description Invocable called by the Record-Triggered Flow
 *   (Account_Merge_Status_Handler) when the Approval Process Field Update
 *   sets Merge_Status__c to Approved, Rejected, or Recalled.
 *
 * FLOW SETUP REMINDER:
 *   Trigger  : Account updated, Master_Account__c Is Null = True, Every time
 *   Decision : $Record.Merge_Status__c equals Approved / Rejected / Recalled
 *   Action   : Call this class
 *              accountId = {!$Record.Id}
 *              decision  = Approved   ← PLAIN STRING LITERAL, NOT a reference chip
 *
 * Approved  → marks victims Approved, fires AccountMergeQueueable
 * Rejected  → resets all victim flags, clears Merge_Error__c + Merge_Comment__c
 * Recalled  → resets all victim flags, clears Merge_Error__c + Merge_Comment__c
 */
public with sharing class AccountMergeApprovalHandler {

    public class ApprovalInput {
        @InvocableVariable(required=true label='Account Id')
        public Id accountId;

        @InvocableVariable(required=true label='Decision (Approved / Rejected / Recalled)')
        public String decision;
    }

    @InvocableMethod(
        label       = 'Handle Merge Approval Decision'
        description = 'Fires AccountMergeQueueable on Approved; resets flags on Rejected or Recalled.'
    )
    public static void handleDecision(List<ApprovalInput> inputs) {
        for (ApprovalInput input : inputs) {
            if (input == null || input.accountId == null) {
                System.debug('AccountMergeApprovalHandler: null input — skipping');
                continue;
            }
            System.debug('AccountMergeApprovalHandler: accountId='
                       + input.accountId + ' decision=' + input.decision);

            if      (input.decision == 'Approved') processApproval(input.accountId);
            else if (input.decision == 'Rejected') processReset(input.accountId, 'Rejected');
            else if (input.decision == 'Recalled') processReset(input.accountId, 'Recalled');
            else System.debug('AccountMergeApprovalHandler: unrecognised decision: '
                            + input.decision);
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // APPROVED — find pending victims → set Approved → enqueue Queueable
    // ─────────────────────────────────────────────────────────────────────

    private static void processApproval(Id masterAccountId) {
        List<Account> victims = [
            SELECT Id FROM Account
            WHERE  Master_Account__c     = :masterAccountId
            AND    Eligible_For_Merge__c = true
            AND    Merge_Status__c       = 'Pending'
        ];

        System.debug('processApproval: master=' + masterAccountId
                   + ' victims found=' + victims.size());

        if (victims.isEmpty()) {
            System.debug('processApproval: no eligible victims — aborting');
            return;
        }

        List<Id>      victimIds = new List<Id>();
        List<Account> toUpdate  = new List<Account>();
        for (Account v : victims) {
            victimIds.add(v.Id);
            toUpdate.add(new Account(
                Id              = v.Id,
                Merge_Status__c = 'Approved',
                Merge_Error__c  = null       // clear any stale error on victim
            ));
        }
        update toUpdate;

        System.debug('processApproval: victims set to Approved — enqueuing Queueable');
        System.enqueueJob(new AccountMergeQueueable(masterAccountId, victimIds));
    }

    // ─────────────────────────────────────────────────────────────────────
    // REJECTED / RECALLED — reset victims, clear error and comment fields
    // ─────────────────────────────────────────────────────────────────────

    private static void processReset(Id masterAccountId, String status) {
        List<Account> victims = [
            SELECT Id FROM Account
            WHERE  Master_Account__c     = :masterAccountId
            AND    Eligible_For_Merge__c = true
        ];

        if (!victims.isEmpty()) {
            List<Account> toReset = new List<Account>();
            for (Account v : victims) {
                toReset.add(new Account(
                    Id                      = v.Id,
                    Eligible_For_Merge__c   = false,
                    Master_Account__c       = null,
                    Merge_Status__c         = status,
                    Merge_Error__c          = null,
                    Merge_Comment__c        = null,
                    Merge_Requested_By__c   = null,
                    Merge_Requested_Date__c = null
                ));
            }
            update toReset;
        }

        update new Account(
            Id               = masterAccountId,
            Merge_Status__c  = status,
            Merge_Error__c   = null,
            Merge_Comment__c = null
        );

       // System.debug('processReset: master=' + masterAccountId + ' → ' + status);
    }
}