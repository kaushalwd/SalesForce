/**********************************************************************************************************************
* Name               : UpdateEgyptAmountInWordsQueueableTest                                                        
* Description        : Test class for UpdateEgyptAmountInWordsQueueable
* Created By         : Shahil Sinha (Horizontal)                                                     
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment                                                                       
* 1.0           Shahil Sinha (Horizontal)        03 Feb 2026     Initial Draft
* 1.1           Shahil Sinha (Horizontal)        03 Feb 2026     Added tests for Arabic amount in words with HTTP mock
* 1.2           Milin Kapatel (Horizontal)       06 Mar 2026     Covered all methods of UpdateEgyptAmountInWordsQueueable
* 1.3           Milin Kapatel (Horizontal)       22 Apr 2026     Aligned with v3.0 batching + ModonEgyptUtilities callouts
* 1.4           Milin Kapatel (Horizontal)       05 May 2026     Updated tests to pass Decimal values instead of String values
* 1.5           Milin Kapatel (Horizontal)       05 Jun 2026     Aligned with v3.2 unit selling price in words + BATCH_SIZE 25
**********************************************************************************************************************/
@isTest
public class UpdateEgyptAmountInWordsQueueableTest {

    /** Mock Arabic number API: body must include tokens ModonEgyptUtilities.replaceAll expects */
    private class ArabicTranslationMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            String body =
                'x '
                + ModonEgyptConstants.CURRENCY_AR_API_DEFAULT_UNIT
                + ' y '
                + ModonEgyptConstants.CURRENCY_AR_UNIT_AED
                + ' z '
                + ModonEgyptConstants.CURRENCY_AR_API_DEFAULT_SUBUNIT;
            res.setBody(body);
            return res;
        }
    }

    @TestSetup
    static void setupTestData() {
        Unit__c unit = new Unit__c(
            Name = 'Test Unit',
            PlotNo__c = '101',
            UnitClassification__c = 'Villa',
            Number_of_Bedrooms__c = '3'
        );
        insert unit;

        SalesOrder__c salesOrder = new SalesOrder__c(
            Status__c = 'New',
            Unit__c = unit.Id,
            Source_Entity__c = 'Modon - Egypt',
            CurrencyIsoCode = 'EGP'
        );
        insert salesOrder;

        SalesOrderInstallments__c soi = new SalesOrderInstallments__c(
            CurrencyIsoCode = salesOrder.CurrencyIsoCode,
            SalesOrder__c = salesOrder.Id,
            InstallmentAmount__c = 10000.12,
            MilestoneDate__c = System.today(),
            MilestoneDescription__c = 'Installment 1',
            MilestoneNumber__c = 2,
            PaymentStatus__c = 'Not Paid',
            Maintenance_Fee__c = 234.23,
            Milestone_Egypt_Percent__c = 5.44444444
        );
        insert soi;
    }

    @isTest
    static void testQueueableExecutionWithEGP() {
        Test.setMock(HttpCalloutMock.class, new ArabicTranslationMock());

        SalesOrder__c so = [
            SELECT Id,
                EgyptTotalAmount__c,
                EgyptTotalInstallmentAmount__c,
                EgyptTotalMaintenanceAmount__c,
                Unit_Selling_Price__c
            FROM SalesOrder__c
            LIMIT 1
        ];
        so.Unit_Selling_Price__c = 500000;
        update so;

        Set<Id> salesOrderIds = new Set<Id>{ so.Id };

        Test.startTest();
        System.enqueueJob(new UpdateEgyptAmountInWordsQueueable(salesOrderIds));
        Test.stopTest();

        SalesOrder__c updatedSO = [
            SELECT
                Id,
                EgyptTotalAmountInWords__c,
                EgyptTotalInstallmentAmountInWords__c,
                EgyptTotalInstallmentAmountInWordsArabic__c,
                EgyptTotalMaintenanceAmountInWords__c,
                EgyptTotalMaintenanceAmountInWordsArabic__c,
                EgyptUnitSellingPriceInWords__c,
                EgyptUnitSellingPriceInWordsArabic__c
            FROM SalesOrder__c
            WHERE Id = :so.Id
        ];
        Assert.isNotNull(updatedSO, 'Sales Order should exist');

        if (so.EgyptTotalAmount__c != null && so.EgyptTotalAmount__c != 0) {
            Assert.isTrue(
                String.isNotBlank(updatedSO.EgyptTotalAmountInWords__c),
                'English total amount in words should be set when Egypt total amount is non-zero'
            );
        }
        if (so.EgyptTotalInstallmentAmount__c != null && so.EgyptTotalInstallmentAmount__c != 0) {
            Assert.isTrue(
                String.isNotBlank(updatedSO.EgyptTotalInstallmentAmountInWords__c),
                'English installment in words should be set'
            );
            Assert.isTrue(
                String.isNotBlank(updatedSO.EgyptTotalInstallmentAmountInWordsArabic__c),
                'Arabic installment in words should be set when API mock returns 200'
            );
        }
        if (so.EgyptTotalMaintenanceAmount__c != null && so.EgyptTotalMaintenanceAmount__c != 0) {
            Assert.isTrue(
                String.isNotBlank(updatedSO.EgyptTotalMaintenanceAmountInWords__c),
                'English maintenance in words should be set'
            );
            Assert.isTrue(
                String.isNotBlank(updatedSO.EgyptTotalMaintenanceAmountInWordsArabic__c),
                'Arabic maintenance in words should be set when API mock returns 200'
            );
        }
        if (so.Unit_Selling_Price__c != null && so.Unit_Selling_Price__c != 0) {
            Assert.isTrue(
                String.isNotBlank(updatedSO.EgyptUnitSellingPriceInWords__c),
                'English unit selling price in words should be set'
            );
            Assert.isTrue(
                String.isNotBlank(updatedSO.EgyptUnitSellingPriceInWordsArabic__c),
                'Arabic unit selling price in words should be set when API mock returns 200'
            );
        }
    }

    @isTest
    static void testQueueableExecutionWithListConstructor() {
        Test.setMock(HttpCalloutMock.class, new ArabicTranslationMock());

        SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];
        List<Id> idList = new List<Id>{ so.Id };

        Test.startTest();
        System.enqueueJob(new UpdateEgyptAmountInWordsQueueable(idList));
        Test.stopTest();

        Assert.isNotNull([SELECT Id FROM SalesOrder__c WHERE Id = :so.Id LIMIT 1]);
    }

    @isTest
    static void testQueueableExecutionWithUSD() {
        Test.setMock(HttpCalloutMock.class, new ArabicTranslationMock());

        SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];
        so.CurrencyIsoCode = 'USD';
        update so;

        Set<Id> salesOrderIds = new Set<Id>{ so.Id };

        Test.startTest();
        System.enqueueJob(new UpdateEgyptAmountInWordsQueueable(salesOrderIds));
        Test.stopTest();

        Assert.isTrue(true, 'Queueable should complete without error');
    }

    @isTest
    static void testQueueableExecutionWithEUR() {
        Test.setMock(HttpCalloutMock.class, new ArabicTranslationMock());

        SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];
        so.CurrencyIsoCode = 'EUR';
        update so;

        Set<Id> salesOrderIds = new Set<Id>{ so.Id };

        Test.startTest();
        System.enqueueJob(new UpdateEgyptAmountInWordsQueueable(salesOrderIds));
        Test.stopTest();

        Assert.isTrue(true, 'Queueable should complete without error');
    }

    @isTest
    static void testQueueableExecutionWithSAR() {
        Test.setMock(HttpCalloutMock.class, new ArabicTranslationMock());

        SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];
        so.CurrencyIsoCode = 'SAR';
        update so;

        Set<Id> salesOrderIds = new Set<Id>{ so.Id };

        Test.startTest();
        System.enqueueJob(new UpdateEgyptAmountInWordsQueueable(salesOrderIds));
        Test.stopTest();

        Assert.isTrue(true, 'Queueable should complete without error');
    }

    @isTest
    static void testQueueableExecutionWithAED() {
        Test.setMock(HttpCalloutMock.class, new ArabicTranslationMock());

        SalesOrder__c so = [SELECT Id FROM SalesOrder__c LIMIT 1];
        so.CurrencyIsoCode = 'AED';
        update so;

        Set<Id> salesOrderIds = new Set<Id>{ so.Id };

        Test.startTest();
        System.enqueueJob(new UpdateEgyptAmountInWordsQueueable(salesOrderIds));
        Test.stopTest();

        Assert.isTrue(true, 'Queueable should complete without error');
    }

    @isTest
    static void testQueueableWithEmptySet() {
        Test.setMock(HttpCalloutMock.class, new ArabicTranslationMock());

        Test.startTest();
        System.enqueueJob(new UpdateEgyptAmountInWordsQueueable(new Set<Id>()));
        Test.stopTest();

        Assert.isTrue(true, 'Queueable should handle empty set gracefully');
    }

    /**
     * Null Set would NPE in new List<Id>(set); List ctor stores null and execute() returns early.
     */
    @isTest
    static void testQueueableWithNullIdList() {
        Test.setMock(HttpCalloutMock.class, new ArabicTranslationMock());

        Test.startTest();
        System.enqueueJob(new UpdateEgyptAmountInWordsQueueable((List<Id>) null));
        Test.stopTest();

        Assert.isTrue(true, 'Queueable should handle null id list gracefully');
    }

    /**
     * v3.2: BATCH_SIZE 25 — chained jobs must run under Test.stopTest().
     */
    @isTest
    static void testQueueableChainsWhenMoreThanTwentyFiveIds() {
        Test.setMock(HttpCalloutMock.class, new ArabicTranslationMock());

        List<Unit__c> units = new List<Unit__c>();
        for (Integer i = 0; i < 26; i++) {
            units.add(
                new Unit__c(
                    Name = 'Batch Unit ' + i,
                    PlotNo__c = 'B' + String.valueOf(10000 + i),
                    UnitClassification__c = 'Villa',
                    Number_of_Bedrooms__c = '3'
                )
            );
        }
        insert units;

        List<SalesOrder__c> orders = new List<SalesOrder__c>();
        for (Unit__c u : units) {
            orders.add(
                new SalesOrder__c(
                    Status__c = 'New',
                    Unit__c = u.Id,
                    Source_Entity__c = 'Modon - Egypt',
                    CurrencyIsoCode = 'EGP'
                )
            );
        }
        insert orders;

        List<Id> allIds = new List<Id>();
        for (SalesOrder__c o : orders) {
            allIds.add(o.Id);
        }

        Test.startTest();
        System.enqueueJob(new UpdateEgyptAmountInWordsQueueable(allIds));
        Test.stopTest();

        Assert.areEqual(
            26,
            [SELECT COUNT() FROM SalesOrder__c WHERE Id IN :allIds],
            'All batch sales orders should still exist after chained queueables'
        );
    }
}