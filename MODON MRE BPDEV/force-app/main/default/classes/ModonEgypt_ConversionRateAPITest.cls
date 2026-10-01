/**********************************************************************************************************************
 * Name               : ModonEgypt_ConversionRateAPITest
 * Description        : Test class for ModonEgypt_ConversionRateAPI REST API class.
 * Created By         : Shahil Sinha (Horizontal)
 * --------------------------------------------------------------------------------------------------------------------
 * Version       Author                              Date            Comment
 * 1.0           Shahil Sinha (Horizontal)           16-12-2025      Initial Draft
 * 2.0           Shahil Sinha (Horizontal)           17-12-2025      Updated for upsert logic and 6 months delete
 * 3.0           Shahil Sinha (Horizontal)           21-01-2026      Added tests for supported currencies filter
 **********************************************************************************************************************/
@isTest
private class ModonEgypt_ConversionRateAPITest {

    @TestSetup
    static void setupTestData() {
        // Create old conversion rate (older than 6 months - should be deleted after API call)
        Currency_Conversion_Rate__c oldRate = new Currency_Conversion_Rate__c(
            Name = 'OLD-RATE',
            CurrencyIsoCode = 'USD',
            Target_Currency__c = 'EGP',
            Conversion_Rate__c = 25.00,
            Rate_Date__c = System.today().addMonths(-7)
        );
        insert oldRate;
    }

    @isTest
    static void testHandleConversionRates_Success() {
        ModonEgypt_ConversionRateAPI.recordsToInsert.clear();
        ModonEgypt_ConversionRateAPI.recordsToUpdate.clear();
        
        List<ModonEgypt_ConversionRateAPI.Request> requests = new List<ModonEgypt_ConversionRateAPI.Request>();
        
        ModonEgypt_ConversionRateAPI.Request req1 = new ModonEgypt_ConversionRateAPI.Request();
        req1.fromCurrency = 'USD';
        req1.toCurrency = 'EGP';
        req1.rate = 30.90;
        req1.inverseRate = 0.0324;
        req1.rateDate = System.today();
        requests.add(req1);
        
        Test.startTest();
        ModonEgypt_ConversionRateAPI.Response response = ModonEgypt_ConversionRateAPI.handleConversionRates(requests);
        Test.stopTest();
        
        System.assertEquals(200, response.statusCode, 'Status code should be 200');
        
        // Verify new record was created
        List<Currency_Conversion_Rate__c> newRates = [SELECT Id, Conversion_Rate__c FROM Currency_Conversion_Rate__c WHERE Name = 'USD-EGP'];
        System.assertEquals(1, newRates.size(), 'New conversion rate should be created');
        
        // Verify old records (older than 6 months) were deleted
        Date sixMonthsAgo = System.today().addMonths(-6);
        List<Currency_Conversion_Rate__c> oldRates = [SELECT Id FROM Currency_Conversion_Rate__c WHERE Rate_Date__c < :sixMonthsAgo];
        System.assertEquals(0, oldRates.size(), 'Old conversion rates should be deleted');
    }

    @isTest
    static void testHandleConversionRates_UpdateExistingRecord() {
        ModonEgypt_ConversionRateAPI.recordsToInsert.clear();
        ModonEgypt_ConversionRateAPI.recordsToUpdate.clear();
        
        // Create existing record
        Currency_Conversion_Rate__c existingRate = new Currency_Conversion_Rate__c(
            Name = 'USD-EGP',
            CurrencyIsoCode = 'USD',
            Target_Currency__c = 'EGP',
            Conversion_Rate__c = 28.00,
            Inverse_Conversion_Rate__c = 0.0357,
            Rate_Date__c = System.today()
        );
        insert existingRate;
        
        List<ModonEgypt_ConversionRateAPI.Request> requests = new List<ModonEgypt_ConversionRateAPI.Request>();
        
        ModonEgypt_ConversionRateAPI.Request req1 = new ModonEgypt_ConversionRateAPI.Request();
        req1.fromCurrency = 'USD';
        req1.toCurrency = 'EGP';
        req1.rate = 30.90;
        req1.inverseRate = 0.0324;
        req1.rateDate = System.today();
        requests.add(req1);
        
        Test.startTest();
        ModonEgypt_ConversionRateAPI.Response response = ModonEgypt_ConversionRateAPI.handleConversionRates(requests);
        Test.stopTest();
        
        System.assertEquals(200, response.statusCode, 'Status code should be 200');
        
        // Verify record was updated (not duplicated)
        List<Currency_Conversion_Rate__c> rates = [SELECT Id, Conversion_Rate__c FROM Currency_Conversion_Rate__c WHERE Name = 'USD-EGP' AND Rate_Date__c = :System.today()];
        System.assertEquals(1, rates.size(), 'Should have only one record');
        System.assertEquals(30.90, rates[0].Conversion_Rate__c, 'Rate should be updated');
    }

    @isTest
    static void testHandleConversionRates_NoUpdateWhenRatesUnchanged() {
        ModonEgypt_ConversionRateAPI.recordsToInsert.clear();
        ModonEgypt_ConversionRateAPI.recordsToUpdate.clear();
        
        // Create existing record with same rates
        Currency_Conversion_Rate__c existingRate = new Currency_Conversion_Rate__c(
            Name = 'USD-EGP',
            CurrencyIsoCode = 'USD',
            Target_Currency__c = 'EGP',
            Conversion_Rate__c = 30.90,
            Inverse_Conversion_Rate__c = 0.0324,
            Rate_Date__c = System.today()
        );
        insert existingRate;
        
        List<ModonEgypt_ConversionRateAPI.Request> requests = new List<ModonEgypt_ConversionRateAPI.Request>();
        
        ModonEgypt_ConversionRateAPI.Request req1 = new ModonEgypt_ConversionRateAPI.Request();
        req1.fromCurrency = 'USD';
        req1.toCurrency = 'EGP';
        req1.rate = 30.90;
        req1.inverseRate = 0.0324;
        req1.rateDate = System.today();
        requests.add(req1);
        
        Test.startTest();
        ModonEgypt_ConversionRateAPI.Response response = ModonEgypt_ConversionRateAPI.handleConversionRates(requests);
        Test.stopTest();
        
        System.assertEquals(200, response.statusCode, 'Status code should be 200');
        System.assertEquals(0, ModonEgypt_ConversionRateAPI.recordsToUpdate.size(), 'No records should be updated');
    }

    @isTest
    static void testHandleConversionRates_UnsupportedCurrencyBypassed() {
        ModonEgypt_ConversionRateAPI.recordsToInsert.clear();
        ModonEgypt_ConversionRateAPI.recordsToUpdate.clear();
        
        List<ModonEgypt_ConversionRateAPI.Request> requests = new List<ModonEgypt_ConversionRateAPI.Request>();
        
        // Unsupported currency (GBP)
        ModonEgypt_ConversionRateAPI.Request req1 = new ModonEgypt_ConversionRateAPI.Request();
        req1.fromCurrency = 'GBP';
        req1.toCurrency = 'INR';
        req1.rate = 100.50;
        req1.inverseRate = 0.00995;
        req1.rateDate = System.today();
        requests.add(req1);
        
        Test.startTest();
        ModonEgypt_ConversionRateAPI.Response response = ModonEgypt_ConversionRateAPI.handleConversionRates(requests);
        Test.stopTest();
        
        System.assertEquals(200, response.statusCode, 'Status code should be 200');
        System.assertEquals(0, ModonEgypt_ConversionRateAPI.recordsToInsert.size(), 'No records should be created for unsupported currency');
    }

    @isTest
    static void testHandleConversionRates_EmptyRequest() {
        Test.startTest();
        ModonEgypt_ConversionRateAPI.Response response1 = ModonEgypt_ConversionRateAPI.handleConversionRates(null);
        ModonEgypt_ConversionRateAPI.Response response2 = ModonEgypt_ConversionRateAPI.handleConversionRates(new List<ModonEgypt_ConversionRateAPI.Request>());
        Test.stopTest();
        
        System.assertEquals(400, response1.statusCode, 'Null request should return 400');
        System.assertEquals(400, response2.statusCode, 'Empty list should return 400');
    }

    @isTest
    static void testHandleConversionRates_ValidationErrors() {
        ModonEgypt_ConversionRateAPI.recordsToInsert.clear();
        ModonEgypt_ConversionRateAPI.recordsToUpdate.clear();
        
        // Missing fromCurrency
        ModonEgypt_ConversionRateAPI.Request req1 = new ModonEgypt_ConversionRateAPI.Request();
        req1.fromCurrency = '';
        req1.toCurrency = 'EGP';
        req1.rate = 30.90;
        req1.rateDate = System.today();
        
        Test.startTest();
        ModonEgypt_ConversionRateAPI.Response response1 = ModonEgypt_ConversionRateAPI.handleConversionRates(new List<ModonEgypt_ConversionRateAPI.Request>{req1});
        
        // Missing toCurrency
        ModonEgypt_ConversionRateAPI.Request req2 = new ModonEgypt_ConversionRateAPI.Request();
        req2.fromCurrency = 'USD';
        req2.toCurrency = '';
        req2.rate = 30.90;
        req2.rateDate = System.today();
        ModonEgypt_ConversionRateAPI.Response response2 = ModonEgypt_ConversionRateAPI.handleConversionRates(new List<ModonEgypt_ConversionRateAPI.Request>{req2});
        
        // Invalid rate
        ModonEgypt_ConversionRateAPI.Request req3 = new ModonEgypt_ConversionRateAPI.Request();
        req3.fromCurrency = 'USD';
        req3.toCurrency = 'EGP';
        req3.rate = -10;
        req3.rateDate = System.today();
        ModonEgypt_ConversionRateAPI.Response response3 = ModonEgypt_ConversionRateAPI.handleConversionRates(new List<ModonEgypt_ConversionRateAPI.Request>{req3});
        Test.stopTest();
        
        System.assertEquals(400, response1.statusCode, 'Missing fromCurrency should return 400');
        System.assertEquals(400, response2.statusCode, 'Missing toCurrency should return 400');
        System.assertEquals(400, response3.statusCode, 'Invalid rate should return 400');
    }
}