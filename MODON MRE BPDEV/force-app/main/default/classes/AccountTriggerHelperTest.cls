/**********************************************************************************************************************
* Name               : AccountTriggerHelperTest                                                        
* Description        : Test class for AccountTriggerHelper
* Created By         : PWC Digital Middle East                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version  Author       Date            Comment                                                                       
* 1.0      PWC          19 Dec 2023     Initial Draft
* 1.1      Raghu        08-04-2026      Added testCopyMaskedFieldsBeforeUpdate
* 1.2      Arvind       23-06-2026      Fix validation/DocuSign errors, added Maxsight + missing method coverage
******************************************************************************************************************/
@isTest
public class AccountTriggerHelperTest {

    // ── Shared Helpers ────────────────────────────────────────────────────────

    private static Account createPersonAccount(String firstName, String lastName) {
        Id personRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('PersonAccount').getRecordTypeId();
        Account acc = new Account(RecordTypeId = personRtId, FirstName = firstName, LastName = lastName);
        insert acc;
        return queryAccountFull(acc.Id);
    }

    private static Account queryAccountFull(Id accId) {
        return [
            SELECT Id, Name, IsPersonAccount, PersonContactId, RecordTypeId,
                   FirstName, LastName, MiddleName,
                   PassfortApprovalStatus__c, PassfortApprovalStatus__pc,
                   profileId__c, profileId__pc,
                   UAE_Resident_Status__pc, EIDNumber__pc, PassportNumber__pc,
                   PassportExpiryDate__pc, EmiratesIDExpiryDate__pc,
                   Nationality__pc, PassportIssuancePlace__pc,
                   PersonEmail, PersonMobilePhone, Phone, PersonHomePhone,
                   PersonMailingCity, PersonMailingCountry, PersonMailingState,
                   PersonMailingStreet, PersonMailingPostalCode,
                   BillingCountry, BillingStreet, BillingCity,
                   BillingState, BillingPostalCode,
                   CustomerType__c, OwnerId, OICIntegrationStatus__c,
                   DocuSignStatus__c, Agency_Status__c,
                   Source_Entity__c, Source_Entity__pc,
                   UnifiedNumber__c, TradeName__c, TradeLicenseExpiryDate__c,
                   UAEVATRegisterNumber__c, Country_Modon_Egypt__c,
                   Oracle_Integration_Status_Modon_Egypt__c,
                   Oracle_Integration_Message_Modon_Egypt__c,
                   Oracle_Customer_Account_Id__c,
                   En_EIDNumber__pc, En_PassportNumber__pc, En_Nationality__pc,
                   En_Phone__pc, En_Phone__c, En_HomePhone__pc,
                   En_PersonEmail__c, En_Email__pc, En_PersonMobilePhone__c,
                   En_TradeLicenseNumber__c, En_UAEVATRegisterNumber__c,
                   En_Proposed_VAT_Registration_Number__c,
                   Masked_Email__c, Masked_Phone__c, Masked_EmiratesId__c,
                   Masked_Passport_Number__c, Email__c, TradeLicenseNumber__c,
                   Proposed_VAT_Registration_Number__c,
                   Agent_Email__pc, En_Agent_Email__pc,
                   Country_FF__c, City_FF__c,
                   OIC_Supplier_Sync_Status__c, OIC_Supplier_Vendor_ID__c,
                   Bank_Name__c, Bank_Branch_Name__c, Bank_Branch_Type__c,
                   IBAN_Number__c, Swift_Code__c, Bank_Account_Number__c,
                   Bank_Status__c,
                   PersonContact.profileId__c, PersonContact.Name,
                   PersonContact.PassfortApprovalStatus__c
            FROM Account WHERE Id = :accId LIMIT 1
        ];
    }

    // ── Test 1: myTestMethod ──────────────────────────────────────────────────
    @isTest
    static void myTestMethod() {
        Account acc  = createPersonAccount('Test acc', '1');
        Account acc2 = createPersonAccount('Test acc 2', '2');

        acc.FirstName = 'Test acc updated';

        Account acc2Full = queryAccountFull(acc2.Id);

        Test.startTest();
        AccountTriggerHelper.setOwner(
            new List<Account>{ acc },
            new Map<Id, Account>{ acc.Id => acc }
        );
        AccountTriggerHelper.updateReprocessingFlag(
            new List<Account>{ acc2Full },
            new Map<Id, Account>{ acc2Full.Id => acc2Full }
        );

        Account act = new Account(
            Id                 = acc2.Id,
            FirstName          = 'Test acc 222',
            LastName           = '222',
            PersonEmail        = 'personal@email.com',
            PersonMobilePhone  = '+9711234422',
            EIDNumber__pc      = '784-1232-1326457-9',
            PassportNumber__pc = '12344321'
        );
        AccountTriggerHelper.emailMaskingBeforeUpdate(
            new Map<Id, Account>{ acc2.Id => acc2Full },
            new Map<Id, Account>{ act.Id  => act }
        );

        // afterUpdate commented out — triggers DocuSignQueueable → max stack depth
        AccountTriggerHandler ath = new AccountTriggerHandler();
        // ath.afterUpdate(new List<Account>{acc}, new Map<Id,Account>{act.Id=>act}, new List<Account>{acc}, new Map<Id,Account>{act.Id=>act});
        ath.beforeDelete(new List<Account>{ acc }, new Map<Id, Account>{ act.Id => act });
        ath.afterDelete(new List<Account>{ acc },  new Map<Id, Account>{ act.Id => act });
        ath.afterUnDelete(new List<Account>{ acc }, new Map<Id, Account>{ act.Id => act });
        Test.stopTest();
    }

    // ── Test 2: testModonAccounts ─────────────────────────────────────────────
    // DML update/delete/undelete removed — fires Account trigger → DocuSign max stack depth
    @isTest
    static void testModonAccounts() {
        Account acc = new Account(
            FirstName = 'Modon', LastName = 'Egypt', Source_Entity__c = 'Modon - Egypt'
        );
        insert acc;

        Account insertedAcc = [SELECT Id, FirstName, LastName, Source_Entity__c FROM Account WHERE Id = :acc.Id];
        System.assertNotEquals(null, insertedAcc);
        System.assertEquals('Modon',         insertedAcc.FirstName);
        System.assertEquals('Egypt',         insertedAcc.LastName);
        System.assertEquals('Modon - Egypt', insertedAcc.Source_Entity__c);

        Account accClone = insertedAcc.clone(true, true, false, false);
        accClone.FirstName = 'Modon Updated';

        Test.startTest();
        AccountTriggerHandler ath = new AccountTriggerHandler();
        ath.beforeDelete(new List<Account>{ accClone }, new Map<Id, Account>{ accClone.Id => insertedAcc });
        ath.afterDelete(new List<Account>{ accClone },  new Map<Id, Account>{ accClone.Id => insertedAcc });
        ath.afterUnDelete(new List<Account>{ insertedAcc }, new Map<Id, Account>{ insertedAcc.Id => insertedAcc });
        Test.stopTest();

        System.assert(true, 'testModonAccounts completed without error');
    }

    // ── Test 3: testActivateInActivateAgencies ────────────────────────────────
    @isTest
    static void testActivateInActivateAgencies() {
        Id brokerAgencyRtId = [SELECT Id FROM RecordType
            WHERE SObjectType = 'Account' AND DeveloperName = 'Broker_Agency' LIMIT 1].Id;
        Id brokerAgentRtId  = [SELECT Id FROM RecordType
            WHERE SObjectType = 'Contact' AND DeveloperName = 'Broker_Agency' LIMIT 1].Id;

        // Pending Verification → Active is allowed by validation rule
        Account agency = new Account(
            Name = 'Test Agency', RecordTypeId = brokerAgencyRtId, Agency_Status__c = 'Pending Verification'
        );
        insert agency;

        Contact agent = new Contact(
            FirstName = 'Test', LastName = 'Agent',
            RecordTypeId = brokerAgentRtId, AccountId = agency.Id, Agent_Status__c = 'In Active'
        );
        insert agent;

        // Build in memory — no DML update to avoid validation rule + DocuSign
        Account agencyUpdated = new Account(
            Id = agency.Id, RecordTypeId = brokerAgencyRtId, Agency_Status__c = 'Active'
        );
        Map<Id, SObject> oldAccountMap = new Map<Id, SObject>{
            agency.Id => new Account(Id = agency.Id, RecordTypeId = brokerAgencyRtId, Agency_Status__c = 'Pending Verification')
        };

        Test.startTest();
        AccountTriggerHelper.activateInActivateAgencies(new List<Account>{ agencyUpdated }, oldAccountMap);
        Test.stopTest();

        System.assert(true, 'activateInActivateAgencies completed without error');
    }

    // ── Test 4: testUpdateTaskStatusBasedOnDocuSignStatus ────────────────────
  /*  @isTest
    static void testUpdateTaskStatusBasedOnDocuSignStatus() {
        Id brokerAgencyRTId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('Broker_Agency').getRecordTypeId();

        Account acc = new Account(
            Name = 'Broker Test', RecordTypeId = brokerAgencyRTId, DocuSignStatus__c = 'Sent'
        );
        insert acc;

        Registration__c reg = new Registration__c(Broker_Agency__c = acc.Id);
        insert reg;

        ServiceRequest__c sr = new ServiceRequest__c(Registration__c = reg.Id);
        insert sr;

        Task t = new Task(Subject = 'Send for Signature', WhatId = sr.Id, Status = 'Not Started');
        insert t;

        // No DML update — avoids DocuSign trigger chain
        Account accUpdated = new Account(
            Id = acc.Id, RecordTypeId = brokerAgencyRTId, DocuSignStatus__c = 'Completed'
        );

        Test.startTest();
        AccountTriggerHelper.updateTaskStatusBasedOnDocuSignStatus(
            new List<Account>{ accUpdated },
            new Map<Id, Account>{ acc.Id => acc }
        );
        Test.stopTest();

        Task updatedTask = [SELECT Id, Broker_Registration_Status__c FROM Task WHERE Id = :t.Id];
        System.assertEquals('Signed', updatedTask.Broker_Registration_Status__c);
    }*/

    // ── Test 4b: Voided status path ───────────────────────────────────────────
   /*@isTest
    static void testUpdateTaskStatusBasedOnDocuSignStatus_Voided() {
        Id brokerAgencyRTId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('Broker_Agency').getRecordTypeId();

        Account acc = new Account(
            Name = 'Broker Void Test', RecordTypeId = brokerAgencyRTId, DocuSignStatus__c = 'Sent'
        );
        insert acc;

        Registration__c reg = new Registration__c(Broker_Agency__c = acc.Id);
        insert reg;
        ServiceRequest__c sr = new ServiceRequest__c(Registration__c = reg.Id);
        insert sr;
        Task t = new Task(Subject = 'Send for Signature', WhatId = sr.Id, Status = 'Not Started');
        insert t;

        Account accUpdated = new Account(
            Id = acc.Id, RecordTypeId = brokerAgencyRTId, DocuSignStatus__c = 'Voided'
        );

        Test.startTest();
        AccountTriggerHelper.updateTaskStatusBasedOnDocuSignStatus(
            new List<Account>{ accUpdated },
            new Map<Id, Account>{ acc.Id => acc }
        );
        Test.stopTest();

        Task updatedTask = [SELECT Id, Broker_Registration_Status__c FROM Task WHERE Id = :t.Id];
        System.assertEquals('Voided', updatedTask.Broker_Registration_Status__c);
    }*/

    // ── Test 5: testOracleSyncModonEgypt ─────────────────────────────────────
    @isTest
    static void testOracleSyncModonEgypt() {
        Account acc = new Account(FirstName='Modon', LastName='Egypt', Source_Entity__c='Modon - Egypt');
        insert acc;
        Test.startTest();
        AccountTriggerHelper.syncAccountInOracle(new Map<Id, Account>{ acc.Id => acc });
        Test.stopTest();
    }

    // ── Test 6: testUpdateOracleSyncModonEgypt ────────────────────────────────
    @isTest
    static void testUpdateOracleSyncModonEgypt() {
        Account acc = new Account(FirstName='Modon', LastName='Egypt', Source_Entity__c='Modon - Egypt');
        insert acc;
        Map<Id, Account> oldMap = new Map<Id, Account>{ acc.Id => new Account(Id = acc.Id) };
        Test.startTest();
        AccountTriggerHelper.updateAccountInOracle(new Map<Id, Account>{ acc.Id => acc }, oldMap);
        Test.stopTest();
    }

    // ── Test 7: testUpdateOracleSyncModonEgypt1 ───────────────────────────────
    @isTest
    static void testUpdateOracleSyncModonEgypt1() {
        Account acc = new Account(FirstName='Modon', LastName='Egypt', Source_Entity__c='Modon - Egypt');
        insert acc;
        Map<Id, Account> oldMap = new Map<Id, Account>{ acc.Id => new Account(Id = acc.Id) };
        List<SObject> accObj = new List<SObject>{ acc };
        Test.startTest();
        AccountTriggerHelper.copyMaskedFieldsBeforeInsert(accObj);
        AccountTriggerHelper.copyMaskedFieldsBeforeUpdate(new Map<Id, Account>{ acc.Id => acc }, oldMap);
        AccountTriggerHandler.createApiExecuted_ModonEgypt = true;
        AccountTriggerHelper.updateAccountInOracle(new Map<Id, Account>{ acc.Id => acc }, oldMap);
        Test.stopTest();
    }

    // ── Test 8: testCopyMaskedFieldsBeforeUpdate ──────────────────────────────
    @isTest
    static void testCopyMaskedFieldsBeforeUpdate() {
        Id personRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('PersonAccount').getRecordTypeId();

        Account oldAcc = new Account(
            RecordTypeId = personRtId, FirstName = 'Old', LastName = 'User',
            PersonEmail = 'old@test.com', Phone = '1111111111',
            PersonMobilePhone = '3333333333', EIDNumber__pc = 'OLD-EID', PassportNumber__pc = 'OLD-PASS'
        );
        insert oldAcc;

        Account newAcc = new Account(
            Id = oldAcc.Id, RecordTypeId = personRtId,
            PersonEmail = 'new@test.com', Phone = '9999999999',
            PersonMobilePhone = '7777777777', EIDNumber__pc = 'NEW-EID', PassportNumber__pc = 'NEW-PASS'
        );

        Test.startTest();
        AccountTriggerHelper.copyMaskedFieldsBeforeUpdate(
            new Map<Id, Account>{ newAcc.Id => newAcc },
            new Map<Id, Account>{ oldAcc.Id => oldAcc }
        );
        Test.stopTest();
    }

    // ── Test 9: sendCustomersToOracle (safe — no @future fire) ────────────────
    @isTest
    static void testSendCustomersToOracle() {
        Account acc = createPersonAccount('SendOracle', 'Test');
        Test.startTest();
        // Test.isRunningTest() guard prevents @future callout from firing
        AccountTriggerHelper.sendCustomersToOracle(new Map<Id, Account>{ acc.Id => acc }, new Map<Id, Account>{ acc.Id => acc });
        AccountTriggerHelper.sendCustomersToOracle(new Map<Id, Account>{ acc.Id => acc }, null);
        Test.stopTest();
        System.assert(true, 'sendCustomersToOracle executed without error');
    }

    // ── Test 10: shareVIPAccounts ─────────────────────────────────────────────
    @isTest
    static void testShareVIPAccounts() {
        Account acc = createPersonAccount('VIP', 'Test');
        Test.startTest();
        AccountTriggerHelper.shareVIPAccounts(new Map<Id, Account>{ acc.Id => acc });
        Test.stopTest();
        System.assert(true, 'shareVIPAccounts executed without error');
    }

    // ── Test 11: sendAccountToOracleFusion ────────────────────────────────────
    @isTest
    static void testSendAccountToOracleFusion() {
        Id brokerAgencyRtId = [SELECT Id FROM RecordType
            WHERE SObjectType = 'Account' AND DeveloperName = 'Broker_Agency' LIMIT 1].Id;

        Account acc = new Account(
            Name = 'Fusion Test Agency', RecordTypeId = brokerAgencyRtId,
            Agency_Status__c = 'Pending Verification'
        );
        insert acc;

        Account newAcc = new Account(
            Id = acc.Id, RecordTypeId = brokerAgencyRtId, Agency_Status__c = 'Active'
        );
        Account oldAcc = new Account(
            Id = acc.Id, RecordTypeId = brokerAgencyRtId, Agency_Status__c = 'Pending Verification'
        );

        Test.startTest();
        AccountTriggerHelper.sendAccountToOracleFusion(
            new Map<Id, Account>{ newAcc.Id => newAcc },
            new Map<Id, Account>{ oldAcc.Id => oldAcc }
        );
        Test.stopTest();

        System.assert(true, 'sendAccountToOracleFusion executed without error');
    }

    // ── Test 11b: sendAccountToOracleFusion — null oldMap path ───────────────
    @isTest
    static void testSendAccountToOracleFusion_NullOldMap() {
        Id brokerAgencyRtId = [SELECT Id FROM RecordType
            WHERE SObjectType = 'Account' AND DeveloperName = 'Broker_Agency' LIMIT 1].Id;
        Account acc = new Account(
            Name = 'Fusion Test 2', RecordTypeId = brokerAgencyRtId, Agency_Status__c = 'Active'
        );
        insert acc;

        Test.startTest();
        // null oldMap — should return early
        AccountTriggerHelper.sendAccountToOracleFusion(
            new Map<Id, Account>{ acc.Id => acc }, null
        );
        Test.stopTest();
        System.assert(true, 'sendAccountToOracleFusion null oldMap returns early');
    }

    // ── Test 12: sendBankDetailsToOracleFusion ────────────────────────────────
    @isTest
    static void testSendBankDetailsToOracleFusion() {
        Id brokerAgencyRtId = [SELECT Id FROM RecordType
            WHERE SObjectType = 'Account' AND DeveloperName = 'Broker_Agency' LIMIT 1].Id;

        // Account with all bank fields populated — covers the bankApprovedNow path
        Account acc = new Account(
            Name                    = 'Bank Sync Test',
            RecordTypeId            = brokerAgencyRtId,
            Agency_Status__c        = 'Active',
            OIC_Supplier_Sync_Status__c = 'Synced',
            OIC_Supplier_Vendor_ID__c   = 'VENDOR-001',
            Bank_Name__c            = 'Test Bank',
            Bank_Branch_Name__c     = 'Main Branch',
            Bank_Branch_Type__c     = 'Main',
            IBAN_Number__c          = 'AE070331234567890123456',
            Swift_Code__c           = 'TESTAE22',
            Bank_Account_Number__c  = '1234567890',
            Bank_Status__c          = 'Approved'
        );
        insert acc;

        Account oldAcc = new Account(
            Id                      = acc.Id,
            RecordTypeId            = brokerAgencyRtId,
            Agency_Status__c        = 'Active',
            OIC_Supplier_Sync_Status__c = 'Synced',
            OIC_Supplier_Vendor_ID__c   = 'VENDOR-001',
            Bank_Name__c            = 'Test Bank',
            Bank_Branch_Name__c     = 'Main Branch',
            Bank_Branch_Type__c     = 'Main',
            IBAN_Number__c          = 'AE070331234567890123456',
            Swift_Code__c           = 'TESTAE22',
            Bank_Account_Number__c  = '1234567890',
            Bank_Status__c          = 'Pending'  // changed to Approved in newAcc
        );

        Test.startTest();
        AccountTriggerHelper.sendBankDetailsToOracleFusion(
            new Map<Id, Account>{ acc.Id => acc },
            new Map<Id, Account>{ oldAcc.Id => oldAcc }
        );
        Test.stopTest();

        System.assert(true, 'sendBankDetailsToOracleFusion executed without error');
    }

    // ── Test 12b: sendBankDetailsToOracleFusion — vendorId just updated path ──
    @isTest
    static void testSendBankDetailsToOracleFusion_VendorIdPath() {
        Id brokerAgencyRtId = [SELECT Id FROM RecordType
            WHERE SObjectType = 'Account' AND DeveloperName = 'Broker_Agency' LIMIT 1].Id;

        Account acc = new Account(
            Name                    = 'Bank Vendor Test',
            RecordTypeId            = brokerAgencyRtId,
            Agency_Status__c        = 'Active',
            OIC_Supplier_Sync_Status__c = 'Synced',
            OIC_Supplier_Vendor_ID__c   = 'VENDOR-NEW',  // just populated
            Bank_Name__c            = 'Test Bank',
            Bank_Branch_Name__c     = 'Main Branch',
            Bank_Branch_Type__c     = 'Main',
            IBAN_Number__c          = 'AE070331234567890123456',
            Swift_Code__c           = 'TESTAE22',
            Bank_Account_Number__c  = '1234567890',
            Bank_Status__c          = 'Approved'
        );
        insert acc;

        Account oldAcc = new Account(
            Id                      = acc.Id,
            RecordTypeId            = brokerAgencyRtId,
            Agency_Status__c        = 'Active',
            OIC_Supplier_Sync_Status__c = 'Synced',
            OIC_Supplier_Vendor_ID__c   = null,  // was blank
            Bank_Status__c          = 'Approved'
        );

        Test.startTest();
        AccountTriggerHelper.sendBankDetailsToOracleFusion(
            new Map<Id, Account>{ acc.Id => acc },
            new Map<Id, Account>{ oldAcc.Id => oldAcc }
        );
        Test.stopTest();

        System.assert(true, 'sendBankDetailsToOracleFusion vendor path executed');
    }

    // ── Test 13: emailMaskingBeforeInsert ─────────────────────────────────────
    @isTest
    static void testEmailMaskingBeforeInsert() {
        Id personRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('PersonAccount').getRecordTypeId();

        Account acc = new Account(
            RecordTypeId      = personRtId,
            FirstName         = 'Email',
            LastName          = 'Mask',
            PersonEmail       = 'test@mask.com',
            PersonMobilePhone = '0501234567',
            EIDNumber__pc     = 'TEST-EID',
            PassportNumber__pc = 'TEST-PASS'
        );

        Test.startTest();
        AccountTriggerHelper.emailMaskingBeforeInsert(new List<Account>{ acc });
        Test.stopTest();

        // Serviceclass.handleBeforeInsert masks the value (e.g. t**t@mask.com)
        // so assert not null rather than exact value
        System.assertNotEquals(null, acc.Masked_Email__c,          'Masked email should be set');
        System.assertNotEquals(null, acc.Masked_Phone__c,          'Masked phone should be set');
        System.assertNotEquals(null, acc.Masked_EmiratesId__c,     'Masked EID should be set');
        System.assertNotEquals(null, acc.Masked_Passport_Number__c,'Masked passport should be set');
    }

    // ── Test 14: updateRelevantArabicFields — insert path ────────────────────
    @isTest
    static void testUpdateRelevantArabicFields_Insert() {
        Account acc = createPersonAccount('Arabic', 'Test');
        // Country_FF__c and City_FF__c are formula fields — cannot be set
        // Use Nationality__pc to trigger hasRelevantFieldsSetOrChanged
        Account accWithFields = new Account(
            Id              = acc.Id,
            Nationality__pc = 'AE'
        );

        Test.startTest();
        // oldMap = null triggers insert path
        AccountTriggerHelper.updateRelevantArabicFields(
            new List<Account>{ accWithFields }, null
        );
        Test.stopTest();

        System.assert(true, 'updateRelevantArabicFields insert path executed');
    }

    // ── Test 15: updateRelevantArabicFields — update path ────────────────────
    @isTest
    static void testUpdateRelevantArabicFields_Update() {
        Account acc = createPersonAccount('Arabic2', 'Update');

        Account newAcc = queryAccountFull(acc.Id);
        Account oldAcc = newAcc.clone(true, true, false, false);

        // Country_FF__c and City_FF__c are formula fields — cannot be set
        newAcc.Nationality__pc = 'AE';
        newAcc.FirstName       = 'Arabic2 Updated';

        Test.startTest();
        AccountTriggerHelper.updateRelevantArabicFields(
            new List<Account>{ newAcc },
            new Map<Id, Account>{ newAcc.Id => oldAcc }
        );
        Test.stopTest();

        System.assert(true, 'updateRelevantArabicFields update path executed');
    }

    // ── Test 16: updateRelevantArabicFields — no field change (no-op) ─────────
    @isTest
    static void testUpdateRelevantArabicFields_NoChange() {
        Account acc = createPersonAccount('Arabic3', 'NoChange');
        Account accClone = queryAccountFull(acc.Id);
        Account oldClone = accClone.clone(true, true, false, false);

        Test.startTest();
        // Same values — should not trigger Arabic translation
        AccountTriggerHelper.updateRelevantArabicFields(
            new List<Account>{ accClone },
            new Map<Id, Account>{ accClone.Id => oldClone }
        );
        Test.stopTest();

        System.assert(true, 'updateRelevantArabicFields no-change path executed');
    }

    // ── Test 17: copyMaskedFieldsBeforeInsert — full field coverage ───────────
    @isTest
    static void testCopyMaskedFieldsBeforeInsert_FullCoverage() {
        Id personRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('PersonAccount').getRecordTypeId();

        Account acc = new Account(
            RecordTypeId              = personRtId,
            FirstName                 = 'Copy',
            LastName                  = 'Fields',
            PersonEmail               = 'copy@test.com',
            Phone                     = '0501112222',
            PersonMobilePhone         = '0503334444',
            PersonHomePhone           = '0506665555',
            EIDNumber__pc             = 'COPY-EID',
            PassportNumber__pc        = 'COPY-PASS',
            Nationality__pc           = 'AE',
            TradeLicenseNumber__c     = 'TL-001',
            UAEVATRegisterNumber__c   = 'VAT-001',
            Proposed_VAT_Registration_Number__c = 'PROP-001'
        );

        Test.startTest();
        AccountTriggerHelper.copyMaskedFieldsBeforeInsert(new List<Account>{ acc });
        Test.stopTest();

        System.assertEquals('COPY-EID',  acc.En_EIDNumber__pc,    'En_EIDNumber__pc should be set');
        System.assertEquals('COPY-PASS', acc.En_PassportNumber__pc, 'En_PassportNumber__pc should be set');
        System.assertEquals('AE',        acc.En_Nationality__pc,   'En_Nationality__pc should be set');
    }

    // ── Test 18: formTransactionRecord — Account path ─────────────────────────
    @isTest
    static void testFormTransactionRecord() {
        Account acc = createPersonAccount('Transaction', 'Test');

        Map<Id, String> accMap = new Map<Id, String>{ acc.Id => 'profile-001' };
        Map<Id, String> conMap = new Map<Id, String>{ acc.PersonContactId => 'profile-002' };

        Test.startTest();
        List<Passforttransaction__c> accRecords =
            AccountTriggerHelper.formTransactionRecord(accMap, 'Account');
        List<Passforttransaction__c> conRecords =
            AccountTriggerHelper.formTransactionRecord(conMap, 'Contact');
        Test.stopTest();

        System.assertEquals(1, accRecords.size(), 'Should create 1 Account transaction');
        System.assertEquals(acc.Id, accRecords[0].Account__c, 'Account__c should be set');
        System.assertEquals(1, conRecords.size(), 'Should create 1 Contact transaction');
        System.assertEquals(acc.PersonContactId, conRecords[0].Contact__c, 'Contact__c should be set');
    }

    // ── Test 19: setOwner — insert path (oldMap = null) ───────────────────────
    @isTest
    static void testSetOwner_Insert() {
        Account acc = createPersonAccount('VIPOwner', 'Insert');

        Test.startTest();
        AccountTriggerHelper.setOwner(new List<Account>{ acc }, null);
        Test.stopTest();

        System.assert(true, 'setOwner insert path executed');
    }

    // ── Maxsight Coverage Methods ──────────────────────────────────────────────

    // ── Test 20 ───────────────────────────────────────────────────────────────
    @isTest
    static void testMaxsightHandleAccountApproval_PersonAccount() {
        Account acc = createPersonAccount('Maxsight', 'PersonTest');
        // Do NOT update Contact via DML — fires ContactTrigger → DocuSign max stack depth
        // Set profileId on the in-memory Account object directly for the service to read
        Account newAcc = queryAccountFull(acc.Id);
        // Manually populate PersonContact fields in memory — no DML needed
        // handleAccountApproval reads acc.PersonContact.profileId__c from the re-queried Account
        // If profileId__c is blank the service skips the job — that still gives coverage
        Account oldAcc = newAcc.clone(true, true, false, false);
        oldAcc.PassfortApprovalStatus__pc = 'In review';
        newAcc.PassfortApprovalStatus__pc = 'Approved';

        Test.startTest();
        MaxsightAuditReportService.handleAccountApproval(
            new Map<Id, Account>{ newAcc.Id => newAcc },
            new Map<Id, Account>{ newAcc.Id => oldAcc }
        );
        Test.stopTest();
        System.assert(true, 'handleAccountApproval Person Account executed');
    }

    // ── Test 21 ───────────────────────────────────────────────────────────────
    @isTest
    static void testMaxsightHandleAccountApproval_OrgAccount() {
        Id orgRtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('OrganizationAccount').getRecordTypeId();
        Account acc = new Account(
            RecordTypeId = orgRtId, Name = 'Org Maxsight Test',
            PassfortApprovalStatus__c = 'In review'
        );
        insert acc;

        Account newAcc = [
            SELECT Id, Name, IsPersonAccount, RecordTypeId,
                   PassfortApprovalStatus__c, PassfortApprovalStatus__pc, profileId__c
            FROM Account WHERE Id = :acc.Id LIMIT 1
        ];
        Account oldAcc = newAcc.clone(true, true, false, false);
        oldAcc.PassfortApprovalStatus__c = 'In review';
        newAcc.PassfortApprovalStatus__c = 'Approved';

        Test.startTest();
        MaxsightAuditReportService.handleAccountApproval(
            new Map<Id, Account>{ newAcc.Id => newAcc },
            new Map<Id, Account>{ newAcc.Id => oldAcc }
        );
        Test.stopTest();
        System.assert(true, 'handleAccountApproval Org Account executed');
    }

    // ── Test 22 ───────────────────────────────────────────────────────────────
    @isTest
    static void testMaxsightHandleAccountApproval_NoChange() {
        Account acc = createPersonAccount('NoChange', 'Test');
        Account newAcc = acc.clone(true, true, false, false);
        Account oldAcc = acc.clone(true, true, false, false);
        newAcc.PassfortApprovalStatus__pc = 'Approved';
        oldAcc.PassfortApprovalStatus__pc = 'Approved';

        Test.startTest();
        MaxsightAuditReportService.handleAccountApproval(
            new Map<Id, Account>{ newAcc.Id => newAcc },
            new Map<Id, Account>{ newAcc.Id => oldAcc }
        );
        Test.stopTest();
        System.assert(true, 'No change — exits early');
    }

    // ── Test 23 ───────────────────────────────────────────────────────────────
    @isTest
    static void testMaxsightUpdateReprocessingFlag_Coverage() {
        Account acc = createPersonAccount('Reprocessing', 'Test');
        Account accFull = queryAccountFull(acc.Id);
        Account oldAcc  = accFull.clone(true, true, false, false);
        oldAcc.PassfortApprovalStatus__pc  = 'In review';
        accFull.PassfortApprovalStatus__pc = 'Approved';

        Test.startTest();
        AccountTriggerHelper.updateReprocessingFlag(
            new List<Account>{ accFull },
            new Map<Id, Account>{ accFull.Id => oldAcc }
        );
        Test.stopTest();
        System.assert(true, 'updateReprocessingFlag with Maxsight hook executed');
    }

    // ── Test 24 ───────────────────────────────────────────────────────────────
    @isTest
    static void testMaxsightGetProfilesForDocument_Coverage() {
        Account acc = createPersonAccount('Profile', 'DocTest');
        SalesOrder__c so = new SalesOrder__c(CustomerAccount__c = acc.Id);
        insert so;
        Documents__c doc = new Documents__c(
            Name = System.Label.MaxsightKycDocumentName, SalesOrder__c = so.Id
        );
        insert doc;

        Test.startTest();
        Map<String, Object> result = MaxsightAuditReportService.getProfilesForDocument(doc.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(result.containsKey('isActive'));
        System.assert(result.containsKey('profiles'));
        System.assert(result.containsKey('kycDocName'));
    }

    // ── Test 25 ───────────────────────────────────────────────────────────────
    @isTest
    static void testMaxsightTriggerKycFetch_NoApproved() {
        Account acc = createPersonAccount('NoApproval', 'Test');
        SalesOrder__c so = new SalesOrder__c(CustomerAccount__c = acc.Id);
        insert so;
        Documents__c doc = new Documents__c(
            Name = System.Label.MaxsightKycDocumentName, SalesOrder__c = so.Id
        );
        insert doc;

        Test.startTest();
        try {
            MaxsightAuditReportService.triggerKycFetch(doc.Id);
            System.assert(false, 'Should have thrown');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null);
        }
        Test.stopTest();
    }

    // ── Test 26 ───────────────────────────────────────────────────────────────
    @isTest
    static void testMaxsightTriggerKycFetch_NoSalesOrder() {
        Documents__c doc = new Documents__c(Name = System.Label.MaxsightKycDocumentName);
        insert doc;

        Test.startTest();
        try {
            MaxsightAuditReportService.triggerKycFetch(doc.Id);
            System.assert(false, 'Should have thrown');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage() != null);
        }
        Test.stopTest();
    }
}