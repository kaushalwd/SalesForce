/**********************************************************************************************************************
* Name               : InvoiceSelectorTest
* Description        : Test coverage for InvoiceSelector. Data is built through real DML so the InvoiceStatus__c
*                       formula (driven by isCancelled__c) resolves the same way it does in the org.
* Usage              : Test class for InvoiceSelector
**********************************************************************************************************************/
@isTest
private class InvoiceSelectorTest {

    @testSetup
    static void setupData() {
        Account acc = new Account(
            Name          = 'InvoiceSelectorTest Account',
            Bank_Account_Number__c = '123456789',
            IBAN_Number__c   = 'IBAN123456',
            Swift_Code__c    = 'SWIFT123',
            Bank_Name__c     = 'Test Bank',
            Beneficiary_Name__c = 'Test Beneficiary'
        );
        insert acc;

        // Not yet synced to Oracle -> matches getInvoicesByIds (OraclePartyId__c = null)
        Invoice__c invNotSynced = new Invoice__c(
            Account__c       = acc.Id,
            InvoiceAmount__c = 100
        );

        // Synced to Oracle but cancelled -> matches getInvoicesByIds (InvoiceStatus__c = 'Cancelled')
        Invoice__c invCancelledSynced = new Invoice__c(
            Account__c        = acc.Id,
            InvoiceAmount__c  = 100,
            OraclePartyId__c  = 'ORCL-CANCELLED',
            isCancelled__c    = true
        );

        // Synced to Oracle and not cancelled -> matches getInvoicesByIdsOracleId only
        Invoice__c invSyncedActive = new Invoice__c(
            Account__c       = acc.Id,
            InvoiceAmount__c = 100,
            OraclePartyId__c = 'ORCL-ACTIVE'
        );

        insert new List<Invoice__c>{ invNotSynced, invCancelledSynced, invSyncedActive };
    }

    private static Invoice__c getInvoiceByOraclePartyId(String oraclePartyId) {
        return [SELECT Id FROM Invoice__c WHERE OraclePartyId__c = :oraclePartyId LIMIT 1];
    }

    private static Invoice__c getNotSyncedInvoice() {
        return [SELECT Id FROM Invoice__c WHERE OraclePartyId__c = null LIMIT 1];
    }

    @isTest
    static void testGetInvoicesByIds_ReturnsNotSyncedAndCancelled() {
        Invoice__c notSynced = getNotSyncedInvoice();
        Invoice__c cancelledSynced = getInvoiceByOraclePartyId('ORCL-CANCELLED');
        Invoice__c syncedActive = getInvoiceByOraclePartyId('ORCL-ACTIVE');

        Set<String> ids = new Set<String>{ notSynced.Id, cancelledSynced.Id, syncedActive.Id };

        Test.startTest();
        List<Invoice__c> results = InvoiceSelector.getInvoicesByIds(ids);
        Test.stopTest();

        Set<Id> resultIds = new Set<Id>();
        for (Invoice__c inv : results) {
            resultIds.add(inv.Id);
        }

        System.assertEquals(2, results.size(), 'Only the not-synced and the cancelled invoices should be returned');
        System.assert(resultIds.contains(notSynced.Id), 'Not-synced invoice should be included');
        System.assert(resultIds.contains(cancelledSynced.Id), 'Cancelled invoice should be included even though it is synced');
        System.assert(!resultIds.contains(syncedActive.Id), 'Synced, non-cancelled invoice should be excluded');
    }

    @isTest
    static void testGetInvoicesByIdsOracleId_ReturnsOnlySyncedInvoices() {
        Invoice__c notSynced = getNotSyncedInvoice();
        Invoice__c cancelledSynced = getInvoiceByOraclePartyId('ORCL-CANCELLED');
        Invoice__c syncedActive = getInvoiceByOraclePartyId('ORCL-ACTIVE');

        Set<String> ids = new Set<String>{ notSynced.Id, cancelledSynced.Id, syncedActive.Id };

        Test.startTest();
        List<Invoice__c> results = InvoiceSelector.getInvoicesByIdsOracleId(ids);
        Test.stopTest();

        Set<Id> resultIds = new Set<Id>();
        for (Invoice__c inv : results) {
            resultIds.add(inv.Id);
        }

        System.assertEquals(2, results.size(), 'Both synced invoices (cancelled or not) should be returned');
        System.assert(resultIds.contains(cancelledSynced.Id), 'Synced, cancelled invoice should be included');
        System.assert(resultIds.contains(syncedActive.Id), 'Synced, active invoice should be included');
        System.assert(!resultIds.contains(notSynced.Id), 'Not-synced invoice should be excluded');
    }

    @isTest
    static void testGetInvoicesByIds_EmptySetReturnsNoRows() {
        Test.startTest();
        List<Invoice__c> results = InvoiceSelector.getInvoicesByIds(new Set<String>());
        Test.stopTest();

        System.assert(results.isEmpty(), 'No Ids passed in should mean no rows returned');
    }

    @isTest
    static void testGetInvoicesByIdsOracleId_EmptySetReturnsNoRows() {
        Test.startTest();
        List<Invoice__c> results = InvoiceSelector.getInvoicesByIdsOracleId(new Set<String>());
        Test.stopTest();

        System.assert(results.isEmpty(), 'No Ids passed in should mean no rows returned');
    }

    @isTest
    static void testGetInvoicesByIds_ReturnsAccountFieldsFromSelector() {
        Invoice__c notSynced = getNotSyncedInvoice();

        Test.startTest();
        List<Invoice__c> results = InvoiceSelector.getInvoicesByIds(new Set<String>{ notSynced.Id });
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Expected the single not-synced invoice to be returned');
        System.assertEquals('SWIFT123', results[0].Account__r.Swift_Code__c, 'Account relationship fields should be traversed by the selector query');
        System.assertEquals('Test Beneficiary', results[0].Account__r.Beneficiary_Name__c, 'Account relationship fields should be traversed by the selector query');
    }
}