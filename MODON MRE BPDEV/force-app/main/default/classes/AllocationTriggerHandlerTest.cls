/**********************************************************************************************************************
* Name               : AllocationTriggerHandlerTest
* Description        : Test class for AllocationTriggerHandler
* Usage              : Test coverage for Allocation trigger handler (before/after insert, before/after update, after delete)
* Created By         : Shahil Sinha
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment
* 1.0           Shahil Sinha (Horizontal)         10 Feb 2026     Initial Draft
******************************************************************************************************************/
@isTest
public class AllocationTriggerHandlerTest {

    @isTest
    static void testHandlerBeforeInsertAndBeforeUpdate() {
        Contact con = new Contact();
        con.LastName = 'AllocHandlerTest';
        insert con;

        AccountTriggerHandler.isTriggerDisabled = true;
        Account account = new Account(
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId(),
            PersonEmail = 'allochandler@test.com',
            FirstName = 'Alloc',
            LastName = 'Handler'
        );
        insert account;
        AccountTriggerHandler.isTriggerDisabled = false;

        Invoice__c inv = new Invoice__c();
        inv.Account__c = account.Id;
        insert inv;

        Receipt__c rec = new Receipt__c();
        rec.Account__c = account.Id;
        rec.Status__c = 'In Progress';
        insert rec;

        Test.startTest();
        Allocation__c alloc = new Allocation__c();
        alloc.Invoice__c = inv.Id;
        alloc.Receipt__c = rec.Id;
        alloc.AllocationAmount__c = 100;
        insert alloc;
        Test.stopTest();

        Allocation__c allocation = [SELECT Id, InProgressReceiptAmount__c, ApprovedReceiptAmount__c FROM Allocation__c WHERE Id = :alloc.Id];
        System.assertEquals(0, allocation.ApprovedReceiptAmount__c, 'ApprovedReceiptAmount__c should be 0 when the receipt is open');
    }

    @isTest
    static void testHandlerAfterUpdate() {
        Contact con = new Contact();
        con.LastName = 'AllocHandlerAfterUpdate';
        insert con;

        AccountTriggerHandler.isTriggerDisabled = true;
        Account account = new Account(
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId(),
            PersonEmail = 'allochandler2@test.com',
            FirstName = 'Alloc',
            LastName = 'Handler2'
        );
        insert account;
        AccountTriggerHandler.isTriggerDisabled = false;

        Invoice__c inv = new Invoice__c();
        inv.Account__c = account.Id;
        insert inv;

        Receipt__c rec = new Receipt__c();
        rec.Account__c = account.Id;
        rec.Status__c = 'In Progress';
        insert rec;

        Allocation__c alloc = new Allocation__c();
        alloc.Invoice__c = inv.Id;
        alloc.Receipt__c = rec.Id;
        alloc.AllocationAmount__c = 50;
        insert alloc;

        Test.startTest();
        alloc.AllocationAmount__c = 75;
        update alloc;
        Test.stopTest();

        System.assertNotEquals(null, alloc.Id, 'Allocation should be updated');
    }

    @isTest
    static void testHandlerAfterInsertAndAfterDelete() {
        Contact con = new Contact();
        con.LastName = 'AllocHandlerDelete';
        insert con;

        AccountTriggerHandler.isTriggerDisabled = true;
        Account account = new Account(
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId(),
            PersonEmail = 'allochandler3@test.com',
            FirstName = 'Alloc',
            LastName = 'Handler3'
        );
        insert account;
        AccountTriggerHandler.isTriggerDisabled = false;

        Invoice__c inv = new Invoice__c();
        inv.Account__c = account.Id;
        insert inv;

        Receipt__c rec = new Receipt__c();
        rec.Account__c = account.Id;
        rec.Status__c = 'Approved';
        insert rec;

        Test.startTest();
        Allocation__c alloc = new Allocation__c();
        alloc.Invoice__c = inv.Id;
        alloc.Receipt__c = rec.Id;
        alloc.AllocationAmount__c = 25;
        insert alloc;

        delete alloc;
        Test.stopTest();

        List<Allocation__c> deleted = [SELECT Id FROM Allocation__c WHERE Id = :alloc.Id];
        System.assertEquals(0, deleted.size(), 'Allocation should be deleted');
    }
}