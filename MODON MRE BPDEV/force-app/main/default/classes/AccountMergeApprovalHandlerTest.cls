/**
 *  *Name               :AccountMergeApprovalHandler                                                       
* 	Description        : This class is used  finds pending victims, sets Approved, enqueues Queueable
*	 Usage              :Merge Approval Request                                                   
* 	Created By         :Arvind Kesharwani

 *	Version       			Author                          Date            Comment   
 	1.0            		Arvind Kesharwani             04/29/2026       Intial Dreaft

 * @description Test class for AccountMergeApprovalHandler.
 *
 * Coverage targets:
 *   handleDecision('Approved')  — finds pending victims, sets Approved, enqueues Queueable
 *   handleDecision('Rejected')  — resets all victim flags + clears master
 *   handleDecision('Recalled')  — same reset logic as Rejected
 *   handleDecision(unknown)     — unknown decision logs and does nothing
 *   handleDecision(null input)  — null input skipped gracefully
 *   handleDecision('Approved') with no victims — exits silently
 */
@IsTest
private class AccountMergeApprovalHandlerTest {

    // ─────────────────────────────────────────────────────────────────────
    // Helpers
    // ─────────────────────────────────────────────────────────────────────

    private static Account makeOrgAccount(String name, String erpId) {
        List<RecordType> rts = [
            SELECT Id FROM RecordType
            WHERE  SObjectType = 'Account'
            AND    IsPersonType = false
            AND    IsActive = true
            LIMIT  1
        ];
        Account a = new Account(Name = name);
        if (!rts.isEmpty()) a.RecordTypeId = rts[0].Id;
        if (String.isNotBlank(erpId)) a.OraclePartyId__c = erpId;
        return a;
    }

    /**
     * Set a victim account as a pending merge candidate for a given master.
     */
    private static Account setupPendingVictim(Id masterId, String name) {
        Account victim = makeOrgAccount(name, null);
        insert victim;
        victim.Eligible_For_Merge__c = true;
        victim.Master_Account__c     = masterId;
        victim.Merge_Status__c       = 'Pending';
        update victim;
        return victim;
    }

    private static AccountMergeApprovalHandler.ApprovalInput makeInput(Id accountId, String decision) {
        AccountMergeApprovalHandler.ApprovalInput inp = new AccountMergeApprovalHandler.ApprovalInput();
        inp.accountId = accountId;
        inp.decision  = decision;
        return inp;
    }

    // ─────────────────────────────────────────────────────────────────────
    // Null / invalid input
    // ─────────────────────────────────────────────────────────────────────

    @IsTest
    static void testHandleDecision_nullInput_noException() {
        AccountMergeApprovalHandler.ApprovalInput nullInp =
            new AccountMergeApprovalHandler.ApprovalInput();
        // accountId left null intentionally

        Test.startTest();
        try {
            AccountMergeApprovalHandler.handleDecision(
                new List<AccountMergeApprovalHandler.ApprovalInput>{ nullInp }
            );
        } catch (Exception e) {
            Assert.fail('Null input should not throw: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testHandleDecision_emptyList_noException() {
        Test.startTest();
        try {
            AccountMergeApprovalHandler.handleDecision(
                new List<AccountMergeApprovalHandler.ApprovalInput>()
            );
        } catch (Exception e) {
            Assert.fail('Empty list should not throw: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testHandleDecision_unknownDecision_noException() {
        Account master = makeOrgAccount('Unknown Decision Master', 'ERP001');
        insert master;

        Test.startTest();
        try {
            AccountMergeApprovalHandler.handleDecision(
                new List<AccountMergeApprovalHandler.ApprovalInput>{
                    makeInput(master.Id, 'Banana')
                }
            );
        } catch (Exception e) {
            Assert.fail('Unknown decision should not throw: ' + e.getMessage());
        }
        Test.stopTest();
    }

    // ─────────────────────────────────────────────────────────────────────
    // Approved
    // ─────────────────────────────────────────────────────────────────────

    @IsTest
    static void testHandleDecision_approved_setsVictimsAndEnqueues() {
        Account master = makeOrgAccount('Approved Master', 'ERP100');
        insert master;
        Account victim = setupPendingVictim(master.Id, 'Approved Victim');

        Test.startTest();
        AccountMergeApprovalHandler.handleDecision(
            new List<AccountMergeApprovalHandler.ApprovalInput>{
                makeInput(master.Id, 'Approved')
            }
        );
        Test.stopTest();

        // After handleDecision + Queueable executes synchronously in Test.stopTest()
        Account victimAfter = [
            SELECT Merge_Status__c, Is_Merged__c, Eligible_For_Merge__c
            FROM   Account WHERE Id = :victim.Id
        ];

        // Queueable runs synchronously in test — victim should be Merged
        Assert.areEqual('Merged', victimAfter.Merge_Status__c,
            'Victim should be Merged after approved + Queueable');
        Assert.isTrue(victimAfter.Is_Merged__c,           'Is_Merged__c should be true');
        Assert.isFalse(victimAfter.Eligible_For_Merge__c, 'Eligible flag should be false');

        Account masterAfter = [SELECT Merge_Status__c FROM Account WHERE Id = :master.Id];
        Assert.areEqual('Merged', masterAfter.Merge_Status__c,
            'Master should be Merged after Queueable completes');
    }

    @IsTest
    static void testHandleDecision_approved_noVictims_noException() {
        Account master = makeOrgAccount('No Victims Approved', 'ERP101');
        insert master;

        Test.startTest();
        try {
            AccountMergeApprovalHandler.handleDecision(
                new List<AccountMergeApprovalHandler.ApprovalInput>{
                    makeInput(master.Id, 'Approved')
                }
            );
        } catch (Exception e) {
            Assert.fail('No-victim Approved should not throw: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testHandleDecision_approved_multipleVictims() {
        Account master  = makeOrgAccount('Multi Approved Master', 'ERP102');
        insert master;
        Account victim1 = setupPendingVictim(master.Id, 'Multi Victim 1');
        Account victim2 = setupPendingVictim(master.Id, 'Multi Victim 2');

        Test.startTest();
        AccountMergeApprovalHandler.handleDecision(
            new List<AccountMergeApprovalHandler.ApprovalInput>{
                makeInput(master.Id, 'Approved')
            }
        );
        Test.stopTest();

        List<Account> victims = [
            SELECT Merge_Status__c, Is_Merged__c
            FROM   Account WHERE Id IN (:victim1.Id, :victim2.Id)
        ];
        for (Account v : victims) {
            Assert.areEqual('Merged', v.Merge_Status__c,
                'All victims should be Merged');
            Assert.isTrue(v.Is_Merged__c, 'All victims should have Is_Merged__c = true');
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // Rejected
    // ─────────────────────────────────────────────────────────────────────

    @IsTest
    static void testHandleDecision_rejected_resetsVictims() {
        Account master = makeOrgAccount('Rejected Master', 'ERP200');
        insert master;
        Account victim = setupPendingVictim(master.Id, 'Rejected Victim');

        Test.startTest();
        AccountMergeApprovalHandler.handleDecision(
            new List<AccountMergeApprovalHandler.ApprovalInput>{
                makeInput(master.Id, 'Rejected')
            }
        );
        Test.stopTest();

        Account victimAfter = [
            SELECT Merge_Status__c, Eligible_For_Merge__c,
                   Master_Account__c, Merge_Error__c, Merge_Comment__c
            FROM   Account WHERE Id = :victim.Id
        ];
        Assert.areEqual('Rejected', victimAfter.Merge_Status__c,  'Victim status = Rejected');
        Assert.isFalse(victimAfter.Eligible_For_Merge__c,         'Eligible flag cleared');
        Assert.isNull(victimAfter.Master_Account__c,              'Master link cleared');
        Assert.isNull(victimAfter.Merge_Error__c,                 'Error cleared');
        Assert.isNull(victimAfter.Merge_Comment__c,               'Comment cleared');

        Account masterAfter = [
            SELECT Merge_Status__c, Merge_Error__c, Merge_Comment__c
            FROM   Account WHERE Id = :master.Id
        ];
        Assert.areEqual('Rejected', masterAfter.Merge_Status__c, 'Master status = Rejected');
        Assert.isNull(masterAfter.Merge_Error__c,                'Master error cleared');
        Assert.isNull(masterAfter.Merge_Comment__c,              'Master comment cleared');
    }

    @IsTest
    static void testHandleDecision_rejected_noVictims_succeeds() {
        Account master = makeOrgAccount('Rejected No Victims', 'ERP201');
        insert master;

        Test.startTest();
        AccountMergeApprovalHandler.handleDecision(
            new List<AccountMergeApprovalHandler.ApprovalInput>{
                makeInput(master.Id, 'Rejected')
            }
        );
        Test.stopTest();

        Account after = [SELECT Merge_Status__c FROM Account WHERE Id = :master.Id];
        Assert.areEqual('Rejected', after.Merge_Status__c);
    }

    // ─────────────────────────────────────────────────────────────────────
    // Recalled
    // ─────────────────────────────────────────────────────────────────────

    @IsTest
    static void testHandleDecision_recalled_resetsVictims() {
        Account master = makeOrgAccount('Recalled Master', 'ERP300');
        insert master;
        Account victim = setupPendingVictim(master.Id, 'Recalled Victim');

        Test.startTest();
        AccountMergeApprovalHandler.handleDecision(
            new List<AccountMergeApprovalHandler.ApprovalInput>{
                makeInput(master.Id, 'Recalled')
            }
        );
        Test.stopTest();

        Account victimAfter = [
            SELECT Merge_Status__c, Eligible_For_Merge__c, Master_Account__c
            FROM   Account WHERE Id = :victim.Id
        ];
        Assert.areEqual('Recalled', victimAfter.Merge_Status__c, 'Victim status = Recalled');
        Assert.isFalse(victimAfter.Eligible_For_Merge__c,        'Eligible flag cleared');
        Assert.isNull(victimAfter.Master_Account__c,             'Master link cleared');

        Account masterAfter = [SELECT Merge_Status__c FROM Account WHERE Id = :master.Id];
        Assert.areEqual('Recalled', masterAfter.Merge_Status__c, 'Master status = Recalled');
    }

    @IsTest
    static void testHandleDecision_recalled_clearsErrorAndComment() {
        Account master = makeOrgAccount('Recalled With Error', 'ERP301');
        insert master;
        master.Merge_Error__c   = 'Previous error';
        master.Merge_Comment__c = 'Old comment';
        update master;

        Account victim = setupPendingVictim(master.Id, 'Error Victim');

        Test.startTest();
        AccountMergeApprovalHandler.handleDecision(
            new List<AccountMergeApprovalHandler.ApprovalInput>{
                makeInput(master.Id, 'Recalled')
            }
        );
        Test.stopTest();

        Account masterAfter = [
            SELECT Merge_Error__c, Merge_Comment__c
            FROM   Account WHERE Id = :master.Id
        ];
        Assert.isNull(masterAfter.Merge_Error__c,   'Merge_Error__c should be null after Recalled');
        Assert.isNull(masterAfter.Merge_Comment__c, 'Merge_Comment__c should be null after Recalled');
    }

    // ─────────────────────────────────────────────────────────────────────
    // Invocable method metadata
    // ─────────────────────────────────────────────────────────────────────

    @IsTest
    static void testHandleDecision_multipleInputsProcessedIndependently() {
        Account master1 = makeOrgAccount('Batch Master 1', 'ERP400');
        Account master2 = makeOrgAccount('Batch Master 2', 'ERP401');
        insert new List<Account>{ master1, master2 };

        Account victim1 = setupPendingVictim(master1.Id, 'Batch Victim 1');
        Account victim2 = setupPendingVictim(master2.Id, 'Batch Victim 2');

        List<AccountMergeApprovalHandler.ApprovalInput> inputs =
            new List<AccountMergeApprovalHandler.ApprovalInput>{
                makeInput(master1.Id, 'Rejected'),
                makeInput(master2.Id, 'Recalled')
            };

        Test.startTest();
        AccountMergeApprovalHandler.handleDecision(inputs);
        Test.stopTest();

        Account v1 = [SELECT Merge_Status__c FROM Account WHERE Id = :victim1.Id];
        Account v2 = [SELECT Merge_Status__c FROM Account WHERE Id = :victim2.Id];

        Assert.areEqual('Rejected', v1.Merge_Status__c, 'Victim 1 should be Rejected');
        Assert.areEqual('Recalled', v2.Merge_Status__c, 'Victim 2 should be Recalled');
    }
}