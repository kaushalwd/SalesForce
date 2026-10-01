/**********************************************************************************************************************
* Name               : Modon_Egypt_BulkChequeEntryTest                                                        
* Description        : Test class for Modon_Egypt_BulkChequeEntry
* Usage              : Test coverage for Modon_Egypt_BulkChequeEntry methods
* Created By         : Horizontal Digital                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           Milin Kapatel (Horizontal Digital)             06-02-2025     Initial Draft   
******************************************************************************************************************/
@IsTest
private class Modon_Egypt_BulkChequeEntryTest {
    // Utility: create minimal data graph to support queries
    @TestSetup
    static void setupData() {

        Id personAccountRTID = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();
        
        // Account
        Account acc = new Account();
        acc.FirstName = 'Test';
        acc.LastName = 'Account';
        acc.RecordTypeId = personAccountRTID;
        acc.PersonEmail = 'test@test22.com';
        acc.Source_Entity__c = 'Modon - Egypt';
        insert acc;

        // Opportunity (referenced in controller via Sales_Order__r.Opportunity__r.AccountId in projection)
        Opportunity opp = new Opportunity(
            Name = 'Test Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            AccountId = acc.Id,
            Source_Entity__c = 'Modon - Egypt'
        );
        insert opp;

        // Sales Order (custom) referenced by Cheque_Entry__c and SalesOrderInstallments__c
        // Use a minimal shape with a lookup to Opportunity if exists in org
        SObject so = (SObject) Schema.getGlobalDescribe().get('SalesOrder__c').newSObject();
        // Set minimal required fields if any
        // Safely set lookup to Opportunity if field exists
        Map<String, Schema.SObjectField> soFields = Schema.getGlobalDescribe().get('SalesOrder__c').getDescribe().fields.getMap();
        if (soFields.containsKey('Opportunity__c')) so.put('Opportunity__c', opp.Id);
        so.put('CustomerAccount__c', acc.Id);
        so.put('TotalAmount__c', 100000);
        so.put('Source_Entity__c', 'Modon - Egypt');
        insert so;

        // SalesOrderInstallments__c records with nested Invoices__r child records
        // Create two installments: one with installment amount and one with maintenance amount
        List<SObject> sois = new List<SObject>();
        Schema.SObjectType soiType = Schema.getGlobalDescribe().get('SalesOrderInstallments__c');
        for (Integer i = 1; i <= 2; i++) {
            SObject soi = soiType.newSObject();
            Map<String, Schema.SObjectField> soiFields = soiType.getDescribe().fields.getMap();
            if (soiFields.containsKey('SalesOrder__c')) soi.put('SalesOrder__c', so.get('Id'));
            if (soiFields.containsKey('MilestoneNumber__c')) soi.put('MilestoneNumber__c', i);
            if (soiFields.containsKey('MilestoneDescription__c')) soi.put('MilestoneDescription__c', 'Milestone ' + i);
            if (soiFields.containsKey('MilestoneDate__c')) soi.put('MilestoneDate__c', Date.today().addDays(7 * i));
            if (soiFields.containsKey('CurrencyIsoCode')) soi.put('CurrencyIsoCode', 'EGP');
            soi.put('InstallmentAmount__c', 10000);
            soi.put('Maintenance_Fee__c', 2000);
            sois.add(soi);
        }
        insert sois;

        // Create Invoice__c child records for each SalesOrderInstallments__c using relationship Invoices__r
        // Simple loop: one Invoice__c per SOI with minimal required fields
        List<Invoice__c> invoices = new List<Invoice__c>();
        for (SObject soiRec : sois) {
            Invoice__c inv = new Invoice__c();
            inv.SalesOrderInstallment__c = (Id)soiRec.get('Id');
            // Populate minimal fields that are safe/available in test context
            // Account__c often required; set to the Person Account created above if field exists
            try {
                inv.Account__c = acc.Id;
            } catch (Exception e) {
                // ignore if field doesn't exist in this org
            }
            invoices.add(inv);
        }
        if (!invoices.isEmpty()) {
            insert invoices;
        }

        // Ensure custom object Cheque_Entry__c exists; no records yet (getBulkChequeEntries will create)
        // Ensure Receipt__c exists for insertReceipts path; records will be inserted by method.
    }

    @IsTest
    static void testLoadActiveCurrency() {
        Test.startTest();
        List<Map<String, String>> result = Modon_Egypt_BulkChequeEntryController.loadActiveCurrency();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        // If CurrencyType DML is not allowed, list may still be non-empty due to org data; simply assert type safety
        if (!result.isEmpty()) {
            System.assert(result[0].containsKey('label') && result[0].containsKey('value'), 'Each map must have label and value');
        }
    }

    @IsTest
    static void testGetBulkChequeEntries_createsFromSOI() {
        // Locate the created Sales Order
        Id soId = (Id) [SELECT Id FROM SalesOrder__c LIMIT 1].Id;
        System.debug('soId==>' + soId);

        Test.startTest();
        List<Cheque_Entry__c> firstCall = Modon_Egypt_BulkChequeEntryController.getBulkChequeEntries(soId);
        Test.stopTest();
		System.debug('firstCall==>'+ firstCall);
        // Expect up to 2 entries (Installment and Maintenance) given setup
        System.assert(firstCall != null, 'Should not be null');
        System.assert(firstCall.size() > 0, 'Should create cheque entries based on SOIs');
    }

    @IsTest
    static void testGetBulkChequeEntries_getExistingChequeEntries() {
        // Locate the created Sales Order
        Id soId = (Id) [SELECT Id FROM SalesOrder__c LIMIT 1].Id;

        List<Cheque_Entry__c> firstCall = Modon_Egypt_BulkChequeEntryController.getBulkChequeEntries(soId);


        // Call again should return existing records without inserting duplicates
        Test.startTest();
        List<Cheque_Entry__c> secondCall = Modon_Egypt_BulkChequeEntryController.getBulkChequeEntries(soId);
        Test.stopTest();

        System.assertEquals(firstCall.size(), secondCall.size(), 'Second call should return same number of existing entries');

    }
    
    @IsTest
    static void testUpdateChequeEntries_successAndNotUpdatedGuards() {
        // Seed one Cheque_Entry__c
        SObject ce = Schema.getGlobalDescribe().get('Cheque_Entry__c').newSObject();
        Map<String, Schema.SObjectField> ceFields = Schema.getGlobalDescribe().get('Cheque_Entry__c').getDescribe().fields.getMap();
        if (ceFields.containsKey('SalesOrder__c')) {
            ce.put('SalesOrder__c', [SELECT Id FROM SalesOrder__c LIMIT 1].Id);
        }
        if (ceFields.containsKey('Cheque_Amount__c')) {
            ce.put('Cheque_Amount__c', 10);
        }
        insert ce;

        // Build payload: update only chequeNumber, keep others as "not updated"
        String payload = JSON.serialize(new List<Object>{
            new Map<String, Object>{
                'id' => (Id)ce.get('Id'),
                'chequeNumber' => '12345',
                'chequeDueDate' => 'not updated',
                'mireBankName' => 'not updated',
                'approvalStatus' => 'not updated',
                'rejectionComments' => 'not updated'
            }
        });

        Test.startTest();
        String result = Modon_Egypt_BulkChequeEntryController.updateChequeEntries(payload);
        Test.stopTest();

        System.assertEquals('Success', result);

        Cheque_Entry__c reloaded = [SELECT Id, Cheque_Number__c, Cheque_Due_Date__c, MIRE_Bank__c, Approval_Status__c, Rejection_Comments__c FROM Cheque_Entry__c WHERE Id = :ce.Id];
        System.assertEquals('12345', reloaded.Cheque_Number__c, 'Cheque number should be updated');
        System.assertEquals(null, reloaded.Cheque_Due_Date__c, 'Due date untouched');
        System.assertEquals(null, reloaded.MIRE_Bank__c, 'Bank untouched');
        System.assertEquals(null, reloaded.Approval_Status__c, 'Approval status untouched');
        System.assertEquals(null, reloaded.Rejection_Comments__c, 'Rejection comments untouched');
    }

    @IsTest
    static void testInsertReceipts_successAndFlags() {
        // Prepare one Cheque_Entry__c with a file to test ContentDocumentLinks cloning
        Account acc = [SELECT Id FROM Account LIMIT 1];

        Id soId = [SELECT Id FROM SalesOrder__c LIMIT 1].Id;

        // Attach a ContentDocument to Cheque_Entry__c to simulate files
        

        Id accId = (Id) [SELECT Id FROM Account LIMIT 1].Id;

        List<Cheque_Entry__c> firstCall = Modon_Egypt_BulkChequeEntryController.getBulkChequeEntries(soId);
        
        ContentVersion cv = new ContentVersion(
            Title = 'testfile',
            PathOnClient = 'testfile.txt',
            VersionData = Blob.valueOf('file body')
        );
        insert cv;
        ContentVersion cvInserted = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Title = 'testfile' LIMIT 1];
		ContentDocument cd = [SELECT Id FROM ContentDocument WHERE Id = :cvInserted.ContentDocumentId];
        
        String payload;
        List<Modon_Egypt_BulkChequeEntryController.singleEntryForReceiptCreation> payloadList = new List<Modon_Egypt_BulkChequeEntryController.singleEntryForReceiptCreation>();
        List<ContentDocumentLink> cdList = new List<ContentDocumentLink>();
        for(Cheque_Entry__c r: firstCall) {
            
            cdList.add(new ContentDocumentLink(
                ContentDocumentId = cd.Id,
                LinkedEntityId = r.Id,
                ShareType = 'V',
                Visibility = 'AllUsers'
            ));	
            
            Modon_Egypt_BulkChequeEntryController.singleEntryForReceiptCreation tempMap = new Modon_Egypt_BulkChequeEntryController.singleEntryForReceiptCreation();
            tempMap.accountId = accId;
            tempMap.soId = soId;
            tempMap.soiId = r.Sales_Order_Installment__c;
            tempMap.chequeEntryId = r.Id;
            tempMap.chequeAmount = r.Cheque_Amount__c;
            tempMap.chequeNumber = 'cheque123';
            tempMap.chequeDueDate = String.valueOf(System.Today());
            tempMap.customerBank = 'First Abu Dhabi Bank';
            tempMap.mireBank = 'First Abu Dhabi Bank';
            tempMap.currencyIsoCode = String.valueOf(r.CurrencyIsoCode);
            tempMap.modeOfPayment = 'Cheque';
            tempMap.receiptType = String.valueOf(r.Receipt_Type__c + ' Receipt');
            payloadList.add(tempMap);
        }
        insert cdList;
        payload = JSON.serialize(payloadList);

        Test.startTest();
        String resp = Modon_Egypt_BulkChequeEntryController.insertReceipts(payload);
        Test.stopTest();
        System.assertEquals('Success', resp, 'Insert receipts should return Success');

        // Assert Receipt was created and linked
        Receipt__c rec = [SELECT Id, Account__c, SalesOrder__c, SalesOrderInstallment__c, TotalAmount__c, Receipt_Type__c, Status__c, Modeofpayment__c FROM Receipt__c LIMIT 1];
        System.assertEquals(acc.Id, rec.Account__c);
        System.assertEquals(soId, rec.SalesOrder__c);
        System.assertEquals('In Progress', rec.Status__c);
        System.assertEquals('Cheque', rec.Modeofpayment__c);


        // Assert content link cloned to Receipt
        List<ContentDocumentLink> recLinks = [
            SELECT Id, LinkedEntityId, ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :rec.Id
        ];
        System.assert(recLinks.size() > 0, 'Receipt should have cloned content document links');

    }

    @IsTest
    static void testgetRelatedFiles() {
        Id soId = [SELECT Id FROM SalesOrder__c LIMIT 1].Id;

        List<Cheque_Entry__c> firstCall = Modon_Egypt_BulkChequeEntryController.getBulkChequeEntries(soId);
        
        ContentVersion cv = new ContentVersion(
            Title = 'testfile',
            PathOnClient = 'testfile.txt',
            VersionData = Blob.valueOf('file body')
        );
        insert cv;
        ContentVersion cvInserted = [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Title = 'testfile' LIMIT 1];
		ContentDocument cd = [SELECT Id FROM ContentDocument WHERE Id = :cvInserted.ContentDocumentId];

        List<ContentDocumentLink> cdList = new List<ContentDocumentLink>();
        for(Cheque_Entry__c r: firstCall) {
            cdList.add(new ContentDocumentLink(
                ContentDocumentId = cd.Id,
                LinkedEntityId = r.Id,
                ShareType = 'V',
                Visibility = 'AllUsers'
            ));	
        }
        insert cdList;
        List<Modon_Egypt_FileUploadViewController.File> files = new List<Modon_Egypt_FileUploadViewController.File>();
        Test.startTest();
        files = Modon_Egypt_FileUploadViewController.getRelatedFiles(firstCall[0].Id);
        Test.stopTest();
        System.assertEquals(1, files.size(), 'Should return 1 file');

    }
}