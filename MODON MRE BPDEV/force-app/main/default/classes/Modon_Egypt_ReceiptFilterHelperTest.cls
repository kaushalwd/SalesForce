/**********************************************************************************************************************
* Name               : Modon_Egypt_ReceiptFilterHelperTest
* Description        : Test class for Modon_Egypt_ReceiptFilterHelper
* Usage              : Test coverage for filter methods (before/after insert, before/after update, before delete)
* Created By         : Shahil Sinha (Horizontal)
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment
* 1.0           Shahil Sinha (Horizontal)                            Initial Version
**********************************************************************************************************************/
@isTest
public class Modon_Egypt_ReceiptFilterHelperTest {

    @TestSetup
    static void setupTestData() {
        Id personAccountRTID = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();
        Account testAccount = new Account(
            FirstName = 'Filter',
            LastName = 'TestAccount',
            RecordTypeId = personAccountRTID,
            PersonEmail = 'filterhelper@test.com'
        );
        insert testAccount;

        Unit__c unit = new Unit__c(
            Name = 'Test Unit',
            PlotNo__c = '101',
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '3'
        );
        insert unit;

        insert new List<SalesOrder__c>{
            new SalesOrder__c(Status__c = 'New', Unit__c = unit.Id, CustomerAccount__c = testAccount.Id, TotalAmount__c = 100, Source_Entity__c = 'Modon - Egypt'),
            new SalesOrder__c(Status__c = 'New', Unit__c = unit.Id, CustomerAccount__c = testAccount.Id, TotalAmount__c = 100, Source_Entity__c = 'Modon - UAE')
        };

        List<SalesOrder__c> salesOrders = [SELECT Id, Source_Entity__c FROM SalesOrder__c ORDER BY Source_Entity__c];
        List<SalesOrderInstallments__c> soiList = new List<SalesOrderInstallments__c>();
        for (SalesOrder__c so : salesOrders) {
            soiList.add(new SalesOrderInstallments__c(
                SalesOrder__c = so.Id,
                InstallmentAmount__c = 10000,
                MilestoneDate__c = Date.today().addDays(30)
            ));
        }
        insert soiList;

        List<Receipt__c> receipts = new List<Receipt__c>();
        for (Integer i = 0; i < salesOrders.size(); i++) {
            receipts.add(new Receipt__c(
                Account__c = testAccount.Id,
                SalesOrder__c = salesOrders[i].Id,
                SalesOrderInstallment__c = soiList[i].Id,
                TotalAmount__c = 20000,
                Status__c = 'Cleared',
                Conversion_Rate__c = 0.27,
                CurrencyIsoCode = 'USD',
                Bank__c = 'First Abu Dhabi Bank',
                MIRE_Bank__c = 'First Abu Dhabi Bank',
                Modeofpayment__c = 'POS',
                TransactionNumber__c = 'TXN-003',
                TransactionDate__c = DateTime.now(),
                Last4DigitString__c = '9012',
                Receipt_Type__c = 'Installment Receipt',
                EBS_Clearing_Date__c = Date.today()
            ));
        }
        insert receipts;
    }   

    @isTest
    static void testFilterBeforeInsert() {
        List<Receipt__c> receipts = [SELECT Id, Source_Entity__c FROM Receipt__c ORDER BY Source_Entity__c];
        List<SObject> newList = toSObjectList(receipts);

        Test.startTest();
        Map<String, Object> results = Modon_Egypt_ReceiptFilterHelper.filterBeforeInsert(newList);
        Test.stopTest();

        assertBeforeFilterResults(results);
    }

    @isTest
    static void testFilterBeforeUpdate() {
        List<Receipt__c> receipts = [SELECT Id, Source_Entity__c FROM Receipt__c ORDER BY Source_Entity__c];
        List<SObject> newList = toSObjectList(receipts);
        List<SObject> oldList = toSObjectList(receipts);

        Test.startTest();
        Map<String, Object> results = Modon_Egypt_ReceiptFilterHelper.filterBeforeUpdate(newList, oldList);
        Test.stopTest();

        assertBeforeFilterResults(results);
    }

    @isTest
    static void testFilterBeforeDelete() {
        List<Receipt__c> receipts = [SELECT Id, Source_Entity__c FROM Receipt__c ORDER BY Source_Entity__c];
        List<SObject> oldList = toSObjectList(receipts);

        Test.startTest();
        Map<String, Object> results = Modon_Egypt_ReceiptFilterHelper.filterBeforeDelete(oldList);
        Test.stopTest();

        assertBeforeFilterResults(results);
    }

    @isTest
    static void testFilterAfterInsert() {
        List<Receipt__c> receipts = [SELECT Id, Source_Entity__c FROM Receipt__c ORDER BY Source_Entity__c];
        List<SObject> newList = toSObjectList(receipts);
        Map<Id, SObject> newMap = toSObjectMap(receipts);

        Test.startTest();
        Map<String, Object> results = Modon_Egypt_ReceiptFilterHelper.filterAfterInsert(newList, newMap);
        Test.stopTest();

        assertBeforeFilterResults(results);
        List<Receipt__c> modonEgyptReceipts = (List<Receipt__c>) results.get('ModonEgyptReceipts');
        List<Receipt__c> otherReceipts = (List<Receipt__c>) results.get('OtherReceipts');
        Map<Id, SObject> modonEgyptMap = (Map<Id, SObject>) results.get('ModonEgyptReceiptsMap');
        Map<Id, SObject> otherMap = (Map<Id, SObject>) results.get('OtherReceiptsMap');
        System.assertEquals(modonEgyptReceipts.size(), modonEgyptMap.size(), 'Modon Egypt map size should match list');
        System.assertEquals(otherReceipts.size(), otherMap.size(), 'Other receipts map size should match list');
    }

    @isTest
    static void testFilterAfterUpdate() {
        List<Receipt__c> receipts = [SELECT Id, Source_Entity__c FROM Receipt__c ORDER BY Source_Entity__c];
        List<SObject> newList = toSObjectList(receipts);
        Map<Id, SObject> newMap = toSObjectMap(receipts);
        List<SObject> oldList = toSObjectList(receipts);
        Map<Id, SObject> oldMap = toSObjectMap(receipts);

        Test.startTest();
        Map<String, Object> results = Modon_Egypt_ReceiptFilterHelper.filterAfterUpdate(newList, newMap, oldList, oldMap);
        Test.stopTest();

        assertBeforeFilterResults(results);
        System.assert(results.containsKey('ModonEgyptOldReceiptsMap'), 'Should contain Modon Egypt old map');
        System.assert(results.containsKey('ModonEgyptNewReceiptsMap'), 'Should contain Modon Egypt new map');
        System.assert(results.containsKey('OtherOldReceiptsMap'), 'Should contain other old map');
    }

    @isTest
    static void testEmptyList() {
        Test.startTest();
        Map<String, Object> beforeInsertResults = Modon_Egypt_ReceiptFilterHelper.filterBeforeInsert(new List<SObject>());
        Map<String, Object> beforeDeleteResults = Modon_Egypt_ReceiptFilterHelper.filterBeforeDelete(new List<SObject>());
        Map<String, Object> afterInsertResults = Modon_Egypt_ReceiptFilterHelper.filterAfterInsert(new List<SObject>(), new Map<Id, SObject>());
        Map<String, Object> afterUpdateResults = Modon_Egypt_ReceiptFilterHelper.filterAfterUpdate(
            new List<SObject>(), new Map<Id, SObject>(), new List<SObject>(), new Map<Id, SObject>()
        );
        Test.stopTest();

        System.assertEquals(0, ((List<SObject>) beforeInsertResults.get('ModonEgyptReceipts')).size());
        System.assertEquals(0, ((List<SObject>) beforeInsertResults.get('OtherReceipts')).size());
        System.assertEquals(0, ((List<SObject>) beforeDeleteResults.get('ModonEgyptReceipts')).size());
        System.assertEquals(0, ((List<SObject>) beforeDeleteResults.get('OtherReceipts')).size());
        System.assertEquals(0, ((List<SObject>) afterInsertResults.get('ModonEgyptReceipts')).size());
        System.assertEquals(0, ((List<SObject>) afterInsertResults.get('OtherReceipts')).size());
        System.assertEquals(0, ((List<SObject>) afterUpdateResults.get('ModonEgyptReceipts')).size());
        System.assertEquals(0, ((List<SObject>) afterUpdateResults.get('OtherReceipts')).size());
    }

    private static void assertBeforeFilterResults(Map<String, Object> results) {
        List<SObject> modonEgyptReceipts = (List<SObject>) results.get('ModonEgyptReceipts');
        List<SObject> otherReceipts = (List<SObject>) results.get('OtherReceipts');
        System.assertNotEquals(null, modonEgyptReceipts, 'ModonEgyptReceipts should not be null');
        System.assertNotEquals(null, otherReceipts, 'OtherReceipts should not be null');
        System.assertEquals(1, modonEgyptReceipts.size(), 'Should have 1 Modon Egypt receipt');
        System.assertEquals(1, otherReceipts.size(), 'Should have 1 other receipt');
        System.assertEquals('Modon - Egypt', modonEgyptReceipts[0].get('Source_Entity__c'), 'Egypt receipt should have correct source entity');
        System.assertNotEquals('Modon - Egypt', otherReceipts[0].get('Source_Entity__c'), 'Other receipt should not be Modon - Egypt');
    }

    private static List<SObject> toSObjectList(List<Receipt__c> receipts) {
        List<SObject> result = new List<SObject>();
        for (Receipt__c r : receipts) {
            result.add(r);
        }
        return result;
    }

    private static Map<Id, SObject> toSObjectMap(List<Receipt__c> receipts) {
        Map<Id, SObject> result = new Map<Id, SObject>();
        for (Receipt__c r : receipts) {
            result.put(r.Id, r);
        }
        return result;
    }
}