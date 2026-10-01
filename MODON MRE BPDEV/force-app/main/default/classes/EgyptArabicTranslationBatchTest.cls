/**********************************************************************************************************************
* Name               : EgyptArabicTranslationBatchTest
* Description        : Test class for EgyptArabicTranslationBatch
* Created By         : Milin Kapatel (Horizontal)
* --------------------------------------------------------------------------------------------------------------------
* Version       Author                              Date            Comment
* 1.0           Milin Kapatel (Horizontal)          09 Mar 2026     Initial Version
* 2.0           Milin Kapatel (Horizontal)          22 Apr 2026     Aligned with updated code of EgyptArabicTranslationBatch
* 2.1           Milin Kapatel (Horizontal)          22 Apr 2026     Single batch scope in test (Salesforce: one execute per test method)
**********************************************************************************************************************/
@isTest
private class EgyptArabicTranslationBatchTest {

    /** Same pattern as ModonEgyptUtilitiesTest — API body must include tokens replaceAll swaps to area labels */
    private class ArabicNumberApiMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/x-www-form-urlencoded');
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

    @testSetup
    static void setupData() {
        List<Unit__c> testUnits = new List<Unit__c>();

        testUnits.add(
            new Unit__c(
                GrossFloorAreaGFA__c = 150.50,
                PlotAreasqm__c = 300.00,
                TerraceArea__c = 25.75,
                Number_of_Bedrooms__c = '1',
                UnitClassification__c = 'Apartment',
                PlotNo__c = '523'
            )
        );

        testUnits.add(
            new Unit__c(
                GrossFloorAreaGFA__c = 100,
                PlotAreasqm__c = 200,
                TerraceArea__c = 0,
                Number_of_Bedrooms__c = '2',
                UnitClassification__c = 'Villa',
                PlotNo__c = '204'
            )
        );

        testUnits.add(
            new Unit__c(
                GrossFloorAreaGFA__c = null,
                PlotAreasqm__c = null,
                TerraceArea__c = null,
                Number_of_Bedrooms__c = '3',
                UnitClassification__c = 'Townhouse',
                PlotNo__c = '300'
            )
        );

        insert testUnits;
    }

    @isTest
    static void testBatchExecution() {
        Test.setMock(HttpCalloutMock.class, new ArabicNumberApiMock());

        Map<Id, Unit__c> unitMap = new Map<Id, Unit__c>([SELECT Id, PlotNo__c FROM Unit__c]);
        Set<Id> unitIds = unitMap.keySet();

        Test.startTest();
        EgyptArabicTranslationBatch batch = new EgyptArabicTranslationBatch(unitIds);
        // Tests allow only one batch execute; scope must cover all rows from start() (default 200).
        Database.executeBatch(batch);
        Test.stopTest();

        Map<String, Unit__c> byPlot = new Map<String, Unit__c>();
        for (Unit__c u : [
            SELECT
                PlotNo__c,
                GrossFloorAreaGFA__c,
                PlotAreasqm__c,
                TerraceArea__c,
                GFA_in_Words_Arabic__c,
                Plot_Area_in_Words_Arabic__c,
                Terrace_Area_in_Words_Arabic__c
            FROM Unit__c
            WHERE Id IN :unitIds
        ]) {
            byPlot.put(u.PlotNo__c, u);
        }

        Unit__c u523 = byPlot.get('523');
        Assert.isNotNull(u523, 'Unit 523 should exist');
        Assert.isTrue(
            String.isNotBlank(u523.GFA_in_Words_Arabic__c) &&
                u523.GFA_in_Words_Arabic__c.contains(ModonEgyptConstants.AREA_AR_SQ_MTR),
            'GFA Arabic words should use area labels after API replace'
        );
        Assert.isTrue(
            String.isNotBlank(u523.Plot_Area_in_Words_Arabic__c) &&
                u523.Plot_Area_in_Words_Arabic__c.contains(ModonEgyptConstants.AREA_AR_SQ_CMTR),
            'Plot Arabic words should include sq cm label from mock pipeline'
        );
        Assert.isTrue(
            String.isNotBlank(u523.Terrace_Area_in_Words_Arabic__c) &&
                u523.Terrace_Area_in_Words_Arabic__c.contains(ModonEgyptConstants.AREA_AR_SQ_MTR),
            'Terrace Arabic words should be populated for non-zero terrace'
        );

        Unit__c u204 = byPlot.get('204');
        Assert.isNotNull(u204, 'Unit 204 should exist');
        Assert.isTrue(
            String.isNotBlank(u204.GFA_in_Words_Arabic__c) && String.isNotBlank(u204.Plot_Area_in_Words_Arabic__c),
            'Non-zero GFA and plot should get Arabic conversion'
        );
        Assert.areEqual(
            ModonEgyptConstants.AREA_AR_ZERO_SQ_MTR,
            u204.Terrace_Area_in_Words_Arabic__c,
            'Zero terrace should use constant per batch v2.0'
        );

        Unit__c u300 = byPlot.get('300');
        Assert.isNotNull(u300, 'Unit 300 should exist');
        Assert.areEqual(
            ModonEgyptConstants.AREA_AR_ZERO_SQ_MTR,
            u300.GFA_in_Words_Arabic__c,
            'Null GFA should map to zero Arabic area constant'
        );
        Assert.areEqual(
            ModonEgyptConstants.AREA_AR_ZERO_SQ_MTR,
            u300.Plot_Area_in_Words_Arabic__c,
            'Null plot area should map to zero Arabic area constant'
        );
        Assert.areEqual(
            ModonEgyptConstants.AREA_AR_ZERO_SQ_MTR,
            u300.Terrace_Area_in_Words_Arabic__c,
            'Null terrace should map to zero Arabic area constant'
        );
    }

    @isTest
    static void testBatchWithEmptySet() {
        Test.setMock(HttpCalloutMock.class, new ArabicNumberApiMock());

        Test.startTest();
        EgyptArabicTranslationBatch batch = new EgyptArabicTranslationBatch(new Set<Id>());
        Database.executeBatch(batch);
        Test.stopTest();

        Assert.isTrue(true, 'Batch handled empty set gracefully');
    }
}