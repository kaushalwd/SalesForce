/**********************************************************************************************************************
 * Name               : ModonEgypt_CurrencyConversionTest
 * Description        : Test class for ModonEgypt_CurrencyConversion utility class.
 * Created By         : Shahil Sinha (Horizontal)
 * --------------------------------------------------------------------------------------------------------------------
 * Version       Author                              Date            Comment
 * 1.0           Shahil Sinha (Horizontal)           16-12-2025      Initial Draft
 * 2.0           Shahil Sinha (Horizontal)           09-01-2026      Updated for ConversionRateWrapper and CONVERSION_THRESHOLD
 **********************************************************************************************************************/

@isTest
private class ModonEgypt_CurrencyConversionTest {

    @TestSetup
    static void setupTestData() {
        List<Currency_Conversion_Rate__c> conversionRates = new List<Currency_Conversion_Rate__c>{
            new Currency_Conversion_Rate__c(
                Name = 'USD-EGP', 
                CurrencyIsoCode = 'USD', 
                Target_Currency__c = 'EGP', 
                Conversion_Rate__c = 30.90, 
                Inverse_Conversion_Rate__c = 0.0324,
                Rate_Date__c = System.today()
            ),
            new Currency_Conversion_Rate__c(
                Name = 'EGP-USD', 
                CurrencyIsoCode = 'EGP', 
                Target_Currency__c = 'USD', 
                Conversion_Rate__c = 0.0324, 
                Inverse_Conversion_Rate__c = 30.90,
                Rate_Date__c = System.today()
            ),
            new Currency_Conversion_Rate__c(
                Name = 'EUR-AED', 
                CurrencyIsoCode = 'EUR', 
                Target_Currency__c = 'AED', 
                Conversion_Rate__c = 4.32, 
                Inverse_Conversion_Rate__c = 0.23148148,
                Rate_Date__c = System.today()
            ),
            new Currency_Conversion_Rate__c(
                Name = 'AED-EUR', 
                CurrencyIsoCode = 'AED', 
                Target_Currency__c = 'EUR', 
                Conversion_Rate__c = 0.23148148, 
                Inverse_Conversion_Rate__c = 4.32,
                Rate_Date__c = System.today()
            )
        };
        insert conversionRates;
    }

    @isTest
    static void testGetConversionRate_SameCurrency() {
        Test.startTest();
        ModonEgypt_CurrencyConversion.ConversionRateWrapper wrapper = 
            ModonEgypt_CurrencyConversion.getConversionRate('USD', 'USD');
        Test.stopTest();
        
        System.assertNotEquals(null, wrapper, 'Wrapper should not be null for same currency');
        System.assertEquals(1, wrapper.conversionRate, 'Same currency conversionRate should be 1');
        System.assertEquals(1, wrapper.inverseConversionRate, 'Same currency inverseConversionRate should be 1');
    }

    @isTest
    static void testGetConversionRate_DifferentCurrency() {
        Test.startTest();
        ModonEgypt_CurrencyConversion.ConversionRateWrapper usdToEgp = 
            ModonEgypt_CurrencyConversion.getConversionRate('USD', 'EGP');
        ModonEgypt_CurrencyConversion.ConversionRateWrapper egpToUsd = 
            ModonEgypt_CurrencyConversion.getConversionRate('EGP', 'USD');
        ModonEgypt_CurrencyConversion.ConversionRateWrapper eurToAed = 
            ModonEgypt_CurrencyConversion.getConversionRate('EUR', 'AED');
        Test.stopTest();
        
        // USD to EGP
        System.assertNotEquals(null, usdToEgp, 'USD-EGP wrapper should not be null');
        System.assertEquals(30.90, usdToEgp.conversionRate, 'USD to EGP conversionRate should be 30.90');
        System.assertEquals(0.0324, usdToEgp.inverseConversionRate, 'USD to EGP inverseConversionRate should be 0.0324');
        
        // EGP to USD
        System.assertNotEquals(null, egpToUsd, 'EGP-USD wrapper should not be null');
        System.assertEquals(0.0324, egpToUsd.conversionRate, 'EGP to USD conversionRate should be 0.0324');
        System.assertEquals(30.90, egpToUsd.inverseConversionRate, 'EGP to USD inverseConversionRate should be 30.90');
        
        // EUR to AED
        System.assertNotEquals(null, eurToAed, 'EUR-AED wrapper should not be null');
        System.assertEquals(4.32, eurToAed.conversionRate, 'EUR to AED conversionRate should be 4.32');
        System.assertEquals(0.23148148, eurToAed.inverseConversionRate, 'EUR to AED inverseConversionRate should be 0.23148148');
    }

    @isTest
    static void testGetConversionRate_NotFound() {
        Test.startTest();
        ModonEgypt_CurrencyConversion.ConversionRateWrapper wrapper = 
            ModonEgypt_CurrencyConversion.getConversionRate('GBP', 'USD');
        Test.stopTest();
        
        System.assertEquals(null, wrapper, 'Should return null when rate not found');
    }

    @isTest
    static void testGetConversionRate_WithProvidedMap() {
        // Create a custom map
        Map<String, ModonEgypt_CurrencyConversion.ConversionRateWrapper> customMap = 
            new Map<String, ModonEgypt_CurrencyConversion.ConversionRateWrapper>();
        customMap.put('SAR-AED', new ModonEgypt_CurrencyConversion.ConversionRateWrapper(0.98, 1.02040816));
        
        Test.startTest();
        // Test with provided map
        ModonEgypt_CurrencyConversion.ConversionRateWrapper wrapper = 
            ModonEgypt_CurrencyConversion.getConversionRate('SAR', 'AED', customMap);
        // Test same currency with provided map
        ModonEgypt_CurrencyConversion.ConversionRateWrapper sameCurrency = 
            ModonEgypt_CurrencyConversion.getConversionRate('SAR', 'SAR', customMap);
        // Test not found with provided map
        ModonEgypt_CurrencyConversion.ConversionRateWrapper notFound = 
            ModonEgypt_CurrencyConversion.getConversionRate('GBP', 'AED', customMap);
        Test.stopTest();
        
        System.assertNotEquals(null, wrapper, 'SAR-AED wrapper should not be null');
        System.assertEquals(0.98, wrapper.conversionRate, 'SAR to AED conversionRate should be 0.98');
        System.assertEquals(1.02040816, wrapper.inverseConversionRate, 'SAR to AED inverseConversionRate should be 1.02040816');
        
        System.assertNotEquals(null, sameCurrency, 'Same currency wrapper should not be null');
        System.assertEquals(1, sameCurrency.conversionRate, 'Same currency should return 1');
        
        System.assertEquals(null, notFound, 'Should return null when rate not found in provided map');
    }

    @isTest
    static void testGetTodaysConversionRateMap() {
        Test.startTest();
        Map<String, ModonEgypt_CurrencyConversion.ConversionRateWrapper> rateMap = 
            ModonEgypt_CurrencyConversion.getTodaysConversionRateMap();
        Test.stopTest();
        
        System.assertNotEquals(null, rateMap, 'Rate map should not be null');
        System.assertEquals(4, rateMap.size(), 'Rate map should contain 4 entries');
        System.assert(rateMap.containsKey('USD-EGP'), 'Rate map should contain USD-EGP');
        System.assert(rateMap.containsKey('EGP-USD'), 'Rate map should contain EGP-USD');
        System.assert(rateMap.containsKey('EUR-AED'), 'Rate map should contain EUR-AED');
        System.assert(rateMap.containsKey('AED-EUR'), 'Rate map should contain AED-EUR');
    }

    @isTest
    static void testCaching() {
        Test.startTest();
        // First call - should query database
        ModonEgypt_CurrencyConversion.getConversionRate('USD', 'EGP');
        Integer queriesAfterFirst = Limits.getQueries();
        
        // Subsequent calls - should use cache
        ModonEgypt_CurrencyConversion.getConversionRate('EGP', 'USD');
        ModonEgypt_CurrencyConversion.getConversionRate('EUR', 'AED');
        ModonEgypt_CurrencyConversion.getConversionRate('USD', 'USD');
        ModonEgypt_CurrencyConversion.getTodaysConversionRateMap();
        Integer queriesAfterMultiple = Limits.getQueries();
        Test.stopTest();
        
        // Should only use 1 SOQL query due to caching
        System.assertEquals(1, queriesAfterFirst, 'First call should use 1 SOQL query');
        System.assertEquals(1, queriesAfterMultiple, 'Subsequent calls should not increase query count due to caching');
    }

    @isTest
    static void testClearCache() {
        Test.startTest();
        // First call - populates cache
        ModonEgypt_CurrencyConversion.getConversionRate('USD', 'EGP');
        Integer queriesAfterFirst = Limits.getQueries();
        
        // Clear cache
        ModonEgypt_CurrencyConversion.clearCache();
        
        // Next call - should query database again
        ModonEgypt_CurrencyConversion.getConversionRate('USD', 'EGP');
        Integer queriesAfterClear = Limits.getQueries();
        Test.stopTest();
        
        System.assertEquals(1, queriesAfterFirst, 'First call should use 1 SOQL query');
        System.assertEquals(2, queriesAfterClear, 'After cache clear, should query database again');
    }

    @isTest
    static void testConversionThreshold() {
        Test.startTest();
        Decimal threshold = ModonEgypt_CurrencyConversion.CONVERSION_THRESHOLD;
        Test.stopTest();
        
        System.assertEquals(0.10, threshold, 'CONVERSION_THRESHOLD should be 0.10');
    }

    @isTest
    static void testConversionRateWrapper() {
        Test.startTest();
        // Test wrapper constructor
        ModonEgypt_CurrencyConversion.ConversionRateWrapper wrapper = 
            new ModonEgypt_CurrencyConversion.ConversionRateWrapper(4.32, 0.23148148);
        Test.stopTest();
        
        System.assertEquals(4.32, wrapper.conversionRate, 'Wrapper conversionRate should be 4.32');
        System.assertEquals(0.23148148, wrapper.inverseConversionRate, 'Wrapper inverseConversionRate should be 0.23148148');
    }

    @isTest
    static void testNoRatesForToday() {
        // Delete all test data created in setup
        delete [SELECT Id FROM Currency_Conversion_Rate__c];
        
        // Clear cache to force re-query
        ModonEgypt_CurrencyConversion.clearCache();
        
        Test.startTest();
        Map<String, ModonEgypt_CurrencyConversion.ConversionRateWrapper> rateMap = 
            ModonEgypt_CurrencyConversion.getTodaysConversionRateMap();
        ModonEgypt_CurrencyConversion.ConversionRateWrapper wrapper = 
            ModonEgypt_CurrencyConversion.getConversionRate('USD', 'EGP');
        Test.stopTest();
        
        System.assertNotEquals(null, rateMap, 'Rate map should not be null even when empty');
        System.assertEquals(0, rateMap.size(), 'Rate map should be empty when no rates exist');
        System.assertEquals(null, wrapper, 'Should return null when no rates exist for today');
    }

    @isTest
    static void testRatesForDifferentDate() {
        // Create rate for yesterday (should not be returned)
        Currency_Conversion_Rate__c yesterdayRate = new Currency_Conversion_Rate__c(
            Name = 'EGP-USD', 
            CurrencyIsoCode = 'EGP', 
            Target_Currency__c = 'USD', 
            Conversion_Rate__c = 1.25, 
            Inverse_Conversion_Rate__c = 0.80,
            Rate_Date__c = System.today().addDays(-1)
        );
        insert yesterdayRate;
        
        // Clear cache
        ModonEgypt_CurrencyConversion.clearCache();
        
        Test.startTest();
        ModonEgypt_CurrencyConversion.ConversionRateWrapper wrapper = 
            ModonEgypt_CurrencyConversion.getConversionRate('GBP', 'USD');
        Test.stopTest();
        
        System.assertEquals(null, wrapper, 'Should not return rate for different date');
    }
}