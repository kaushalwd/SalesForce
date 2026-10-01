@IsTest
private with sharing class ModonEgypt_OracleIntegration_Test {
    /* =========================================================
       HTTP MOCK
       ========================================================= */
    private class OracleAccountHttpMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');

            if (req.getBody().contains('CustomerNumber') && !req.getBody().contains('"IsPersonAccount":"FALSE"')) {
                // INSERT Account response
                res.setStatusCode(200);
                res.setBody(
                    '[{' +
                    '"Status":"Success",' +
                    '"Message":"Account Created",' +
                    '"StatusCode":"200",' +
                    '"CustomerAccountId":"300000009999",' +
                    '"Sites":[{' +
                        '"ContactStatus":"Success",' +
                        '"TaxStatus":"Success"' +
                    '}]' +
                    '}]'
                );
            } else {
                // UPDATE Account response
                res.setStatusCode(200);
                res.setBody(
                    '[{' +
                    '"Status":"Success",' +
                    '"Message":"Account Updated"' +
                    '}]'
                );
            }
            return res;
        }
    }
    
    private class OracleReceipttHttpMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
    
            String body = req.getBody();
    
            /* ================= RECEIPT ================= */
            if (body.contains('ReceiptNumber')) {
                res.setStatusCode(200);
                res.setBody(
                    '{' +
                    '"StandardReceiptId":"ORC-REC-123"' +
                    '}'
                );
                return res;
            }
    
            /* ================= DEFAULT ================= */
            res.setStatusCode(200);
            res.setBody(
                '[{' +
                '"Status":"Success",' +
                '"Message":"Account Updated"' +
                '}]'
            );
            return res;
        }
    }
    
    private class OracleInvoicetHttpMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
    
            String body = req.getBody();
    
            /* ================= INVOICE ================= */
            if (body.contains('Invoice')) {
                res.setStatusCode(200);
                res.setBody(
                    '{' +
                    	'"Status":"Success",' +
                        '"CustomerTransactionId":"INV-101236"' +
                    '}'
                );
                return res;
            }
    
            /* ================= DEFAULT ================= */
            res.setStatusCode(200);
            res.setBody(
                '[{' +
                    '"Status":"Success"' +
                '}]'
            );
            return res;
        }
    }


    /* =========================================================
       TEST DATA FACTORY
       ========================================================= */
    private static Account createPersonAccount() {
        Account acc = new Account();
        acc.RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName()
            .get('Person Account').getRecordTypeId();

        acc.FirstName = 'Test';
        acc.LastName = 'Customer';
        acc.PersonEmail = 'test@test.com';
        acc.PersonMobilePhone = '9999999999';
        acc.PersonMailingCity = 'Cairo';
        acc.Country_Modon_Egypt__c = 'EG';
        acc.Source_Entity__pc = 'Modon - Egypt';
        acc.TradeName__c = 'Test Trade';

        return acc;
    }
    
    private static Account createBusinessAccount() {
        Account acc = new Account();
    
        acc.Name = 'Test Business Account';
        acc.BillingCity = 'Cairo';
        acc.BillingCountry = 'Egypt';
        acc.Country_Modon_Egypt__c = 'EG';
        acc.Source_Entity__c = 'Modon - Egypt';
        acc.TradeName__c = 'Test Business Trade';
    
        return acc;
    }
    
    private static SalesOrder__c createSalesOrder(Account acc) {
        SalesOrder__c so = new SalesOrder__c();
        so.CustomerAccount__c = acc.Id;
        so.TotalAmount__c = 10000;
        so.Status__c = 'In Progress';
        insert so;
        return so;
    }
    
    private static SalesOrderInstallments__c createSalesOrderInstallment(SalesOrder__c so) {
        SalesOrderInstallments__c soi = new SalesOrderInstallments__c();
        soi.SalesOrder__c = so.Id;
        soi.InstallmentAmount__c = 5000;
        soi.Maintenance_Fee__c = 2000;
        soi.CurrencyIsoCode = 'AED';
        soi.MilestoneDescription__c = 'Downpayment';
        insert soi;
        return soi;
    }



    /* =========================================================
       TEST: ACCOUNT INSERT SYNC
       ========================================================= */
    @IsTest
    static void testAccountInsertOracleSync() {
        Test.setMock(HttpCalloutMock.class, new OracleAccountHttpMock());

        Account acc = createPersonAccount();
        insert acc;

        Test.startTest();
            System.enqueueJob(
                new ModonEgypt_AccountInsertSyncQueueable(
                    new Set<Id>{ acc.Id }
                )
            );
        Test.stopTest();

        Account updatedAcc = [
            SELECT Oracle_Customer_Account_Id__c,
                   Oracle_Integration_Status_Modon_Egypt__c,
                   Oracle_Integration_Message_Modon_Egypt__c,
                   Oracle_Account_Contact_Status__c,
                   Oracle_Account_Tax_Status__c
            FROM Account
            WHERE Id = :acc.Id
        ];

        System.assertEquals(
            '300000009999',
            updatedAcc.Oracle_Customer_Account_Id__c,
            'Oracle Account ID should be populated'
        );
        System.assertEquals(
            'Success',
            updatedAcc.Oracle_Integration_Status_Modon_Egypt__c
        );
        System.assertEquals(
            'Success',
            updatedAcc.Oracle_Account_Contact_Status__c
        );
        System.assertEquals(
            'Success',
            updatedAcc.Oracle_Account_Tax_Status__c
        );
    }

    /* =========================================================
       TEST: ACCOUNT UPDATE SYNC
       ========================================================= */
    @IsTest
    static void testAccountUpdateOracleSync() {
        Test.setMock(HttpCalloutMock.class, new OracleAccountHttpMock());

        Account acc = createPersonAccount();
        insert acc;

        // Change tracked field to trigger update sync
        acc.PersonMailingCity = 'Alexandria';
        update acc;

        Test.startTest();
            System.enqueueJob(
                new ModonEgypt_AccountUpdateSyncQueueable(
                    new Set<Id>{ acc.Id }
                )
            );
        Test.stopTest();

        Account updatedAcc = [
            SELECT Oracle_Integration_Status_Modon_Egypt__c,
                   Oracle_Integration_Message_Modon_Egypt__c
            FROM Account
            WHERE Id = :acc.Id
        ];

        System.assertEquals(
            'Success',
            updatedAcc.Oracle_Integration_Status_Modon_Egypt__c
        );
        System.assert(
            updatedAcc.Oracle_Integration_Message_Modon_Egypt__c.contains('Updated'),
            'Update success message expected'
        );
    }
    
    @IsTest
    static void testBusinessAccountInsertOracleSync() {
        Test.setMock(HttpCalloutMock.class, new OracleAccountHttpMock());
    
        Account acc = createBusinessAccount();
        insert acc;
    
        Test.startTest();
            System.enqueueJob(
                new ModonEgypt_AccountInsertSyncQueueable(
                    new Set<Id>{ acc.Id }
                )
            );
        Test.stopTest();
    
        Account updatedAcc = [
            SELECT Oracle_Customer_Account_Id__c,
                   Oracle_Integration_Status_Modon_Egypt__c,
                   Oracle_Integration_Message_Modon_Egypt__c
            FROM Account
            WHERE Id = :acc.Id
        ];
    
        System.assertEquals(
            '300000009999',
            updatedAcc.Oracle_Customer_Account_Id__c
        );
        System.assertEquals(
            'Success',
            updatedAcc.Oracle_Integration_Status_Modon_Egypt__c
        );
    }
    
    @IsTest
    static void testBusinessAccountUpdateOracleSync() {
        Test.setMock(HttpCalloutMock.class, new OracleAccountHttpMock());
    
        Account acc = createBusinessAccount();
        insert acc;
    
        acc.BillingCity = 'Alexandria';
        update acc;
    
        Test.startTest();
            System.enqueueJob(
                new ModonEgypt_AccountUpdateSyncQueueable(
                    new Set<Id>{ acc.Id }
                )
            );
        Test.stopTest();
    
        Account updatedAcc = [
            SELECT Oracle_Integration_Status_Modon_Egypt__c,
                   Oracle_Integration_Message_Modon_Egypt__c
            FROM Account
            WHERE Id = :acc.Id
        ];
    
        System.assertEquals(
            'Success',
            updatedAcc.Oracle_Integration_Status_Modon_Egypt__c
        );
        System.assert(
            updatedAcc.Oracle_Integration_Message_Modon_Egypt__c.contains('Updated')
        );
    }
    
    @IsTest(SeeAllData=true)
    static void testReceiptInsertOracleSync() {
    
        Test.setMock(HttpCalloutMock.class, new OracleReceipttHttpMock());
    
        Account acc = createPersonAccount();
        insert acc;
    
        SalesOrder__c so = createSalesOrder(acc);
        
        SalesOrderInstallments__c soi = createSalesOrderInstallment(so);
    
        Receipt__c rec = new Receipt__c();
        rec.Account__c = acc.Id;
        rec.SalesOrder__c = so.Id;
        rec.SalesOrderInstallment__c = soi.Id;
        rec.Modeofpayment__c = 'Bank Transfer';
        rec.Bank__c = 'Banque Misr';
        rec.CurrencyISOCode = 'AED';
        rec.TotalAmount__c = 1000;
        rec.Status__c = 'In Progress';
    
        insert rec;
    
        Test.startTest();
            System.enqueueJob(
                new ModonEgypt_ReceiptInsertOracleQueueable(
                    new Set<Id>{ rec.Id }
                )
            );
        //insert rec;
        Test.stopTest();
    
        Receipt__c updatedRec = [
            SELECT Oracle_Receipt_Id__c,
                   Oracle_Integration_Status_Modon_Egypt__c,
                   Oracle_Integration_Message_Modon_Egypt__c
            FROM Receipt__c
            WHERE Id = :rec.Id
        ];
    
        System.assertEquals(
            'ORC-REC-123',
            updatedRec.Oracle_Receipt_Id__c,
            'Oracle Receipt ID should be populated'
        );
        System.assertEquals(
            'Success',
            updatedRec.Oracle_Integration_Status_Modon_Egypt__c
        );
    }
    
    @IsTest
    static void testInvoiceInsertOracleSync_Egypt() {

        Test.setMock(HttpCalloutMock.class, new OracleInvoicetHttpMock());

        // Account
        Account acc = createPersonAccount();
        insert acc;

        // Sales Order (Egypt)
        SalesOrder__c so = createSalesOrder(acc);
        // Make sure the Sales Order has the Source_Entity__c set to 'Modon - Egypt'
        so.Source_Entity__c = 'Modon - Egypt';
        update so;

        // Installment
        SalesOrderInstallments__c inst = createSalesOrderInstallment(so);

        // Invoice
        Invoice__c inv = new Invoice__c();
        inv.SalesOrderInstallment__c = inst.Id;
        inv.InvoiceAmount__c = 1000;
        inv.Account__c = acc.id;
        //inv.Status__c = 'Open';
        insert inv;
        
        so.Status__c = 'SPA Signed (Customer)';
        update so;

        // Force the trigger to fire by using Test.startTest() and Test.stopTest()
        Test.startTest();
        	
            // The trigger should have fired during insert, setting the Oracle status to 'Pending'
            Invoice__c updatedInv = [
                SELECT Oracle_Integration_Status_Modon_Egypt__c,
                       Oracle_Integration_Message_Modon_Egypt__c
                FROM Invoice__c
                WHERE Id = :inv.Id
            ];

            /*System.assertEquals(
                'Pending',
                updatedInv.Oracle_Integration_Status_Modon_Egypt__c,
                'Invoice should be marked Pending for Oracle sync'
            );

            System.assertEquals(
                'Oracle insert sync pending',
                updatedInv.Oracle_Integration_Message_Modon_Egypt__c
            );*/
            
            // Now test the queueable job
            System.enqueueJob(
                new ModonEgypt_InvoiceSyncQueueable(
                    new Set<Id>{ inv.Id }
                )
            );
        Test.stopTest();
        
        Invoice__c updatedInv2 = [
            SELECT Oracle_Integration_Status_Modon_Egypt__c,
            Oracle_Integration_Message_Modon_Egypt__c, Oracle_Installment_Invoice_Id__c
            FROM Invoice__c
            WHERE Id = :inv.Id
        ];
        
       /* System.assertEquals(
            'INV-101236',
            updatedInv2.Oracle_Installment_Invoice_Id__c,
            'Invoice Id should be INV-101236'
        );*/
    }
}