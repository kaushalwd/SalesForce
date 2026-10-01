/**********************************************************************************************************************
 * Name               : ModonEgypt_CurrencyConversion
 * Description        : Utility class for handling currency conversion rate operations.
 *                      1. Fetches Currency_Conversion_Rate__c records for today's date.
 *                      2. Provides method to get conversion rate between two currencies.
 *                      3. Uses caching to prevent multiple SOQL queries in same transaction.
 *                      4. Returns both direct and inverse conversion rates.
 * Usage              : Used across multiple classes that require currency conversion logic.
 * Created By         : Shahil Sinha (Horizontal)
 * --------------------------------------------------------------------------------------------------------------------
 * Version       Author                              Date            Comment
 * 1.0           Shahil Sinha (Horizontal)           16-12-2025      Initial Draft
 * 1.1           Shahil Sinha (Horizontal)           19-12-2025      Added caching to prevent Too Many SOQL Queries error
 * 1.2           Shahil Sinha (Horizontal)           06-01-2026      Added Inverse_Conversion_Rate__c support
 * 1.3           Shahil Sinha (Horizontal)           07-01-2026      Added CONVERSION_THRESHOLD constant for accuracy checks
 * 2.0           Mirza Baig                          02-06-2026      Added getConversionRateBasedOnDates method to retrieve all rates based on the rate dates
 **********************************************************************************************************************/
public with sharing class ModonEgypt_CurrencyConversion {
    
    //v1.3 (line 20) Threshold for currency conversion accuracy - if difference is within this range, use exact balance
    public static final Decimal CONVERSION_THRESHOLD = 0.10;

    // Wrapper class to hold both conversion rates
    public class ConversionRateWrapper {
        public Decimal conversionRate;
        public Decimal inverseConversionRate;
        
        public ConversionRateWrapper(Decimal conversionRate, Decimal inverseConversionRate) {
            this.conversionRate = conversionRate;
            this.inverseConversionRate = inverseConversionRate;
        }
    }

    // Cache to store conversion rates - prevents multiple SOQL queries in same transaction
    private static Map<String, ConversionRateWrapper> cachedConversionRates;

    public static Map<String, ConversionRateWrapper> getTodaysConversionRateMap() {
        // Return cached rates if already fetched in this transaction
        if (cachedConversionRates != null) {
            return cachedConversionRates;
        }

        //v1.2 (line 44) Added Inverse_Conversion_Rate__c support
        List<Currency_Conversion_Rate__c> conversionRates = [
            SELECT Name, CurrencyIsoCode, Target_Currency__c, Conversion_Rate__c, Inverse_Conversion_Rate__c
            FROM Currency_Conversion_Rate__c 
            WHERE Rate_Date__c = :System.today()
        ];

        cachedConversionRates = new Map<String, ConversionRateWrapper>();
        for (Currency_Conversion_Rate__c ccr : conversionRates) {
            ConversionRateWrapper wrapper = new ConversionRateWrapper(
                ccr.Conversion_Rate__c,
                ccr.Inverse_Conversion_Rate__c
            );
            cachedConversionRates.put(ccr.Name, wrapper);
        }
        return cachedConversionRates;
    }

    //v2.0
    /**
    * Retrieves currency conversion rates for the specified dates and
    * groups them by Rate Date for efficient lookup.
    */
    public static Map<Date, List<Currency_Conversion_Rate__c>> getConversionRateBasedOnDates(
        Set<Date> rateDates
    ) {
        Map<Date, List<Currency_Conversion_Rate__c>> dateWithRatesMap =
            new Map<Date, List<Currency_Conversion_Rate__c>>();

        if (rateDates == null || rateDates.isEmpty()) {
            return dateWithRatesMap;
        }

        // Group conversion rates by their effective date
        for (Currency_Conversion_Rate__c rate : [
            SELECT Name,
                CurrencyIsoCode,
                Target_Currency__c,
                Conversion_Rate__c,
                Inverse_Conversion_Rate__c,
                Rate_Date__c
            FROM Currency_Conversion_Rate__c
            WHERE Rate_Date__c IN :rateDates
        ]) {

            // Initialize the collection for the date if it does not exist
            if (!dateWithRatesMap.containsKey(rate.Rate_Date__c)) {
                dateWithRatesMap.put(
                    rate.Rate_Date__c,
                    new List<Currency_Conversion_Rate__c>()
                );
            }

            dateWithRatesMap.get(rate.Rate_Date__c).add(rate);
        }

        return dateWithRatesMap;
    }

    public static ConversionRateWrapper getConversionRate(String sourceCurrencyIsoCode, String targetCurrencyIsoCode, Map<String, ConversionRateWrapper> conversionRateMap) {
        if (sourceCurrencyIsoCode == targetCurrencyIsoCode) {
            return new ConversionRateWrapper(1, 1);
        }
        
        String key = sourceCurrencyIsoCode + '-' + targetCurrencyIsoCode;
        return conversionRateMap.get(key);  // Returns null if not found
    }

    public static ConversionRateWrapper getConversionRate(String sourceCurrencyIsoCode, String targetCurrencyIsoCode) {
        Map<String, ConversionRateWrapper> conversionRateMap = getTodaysConversionRateMap();
        return getConversionRate(sourceCurrencyIsoCode, targetCurrencyIsoCode, conversionRateMap);
    }

    @TestVisible
    private static void clearCache() {
        cachedConversionRates = null;
    }
}