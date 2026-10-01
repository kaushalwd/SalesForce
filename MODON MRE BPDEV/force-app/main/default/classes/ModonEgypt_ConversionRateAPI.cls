/**********************************************************************************************************************
 * Name               : ModonEgypt_ConversionRateAPI
 * Description        : Apex REST API for syncing currency conversion rates from external system
 * Usage              : REST API endpoint - /services/apexrest/ConversionRate/
 * Created By         : Gautam Mishra (Horizontal)
 * --------------------------------------------------------------------------------------------------------------------
 * Version       Author                                   Date            Comment
 * 1.0           Gautam Mishra (Horizontal)               29-10-2025      Initial Version
 * 2.0           Narendra Kumar Agrawal (Horizontal)      29-11-2025      Last Updated
 * 3.0           Shahil Sinha (Horizontal)                17-12-25        Handled the code to check if conversion rates already exists for same Name and Rate Date combination
 * 3.1           Shahil Sinha (Horizontal)                26-12-25        Added logic to update the record only if rate gets changed
 * 3.2           Narendra Agrawal (Horizontal)            21-01-26        Added logic to allow only 5 supported currency, and bypass other currecies conversion rates.
 * 3.3           Jay Patel                                  21 Sep 2026     MCR-73 — USER_MODE SOQL/DML, createApexLog
 **********************************************************************************************************************/

@RestResource(urlMapping='/ConversionRate/*')
global with sharing class ModonEgypt_ConversionRateAPI {
    global class Request {
        global String fromCurrency;
        global String toCurrency;
        global Decimal rate;
        global Date rateDate;
        global Decimal inverseRate;
    }

    global class Response {
        public Integer statusCode;
        public String message;

        global Response(Integer code, String msg) {
            this.statusCode = code;
            this.message = msg;
        }
    }

	public static List<Currency_Conversion_Rate__c> recordsToInsert = new List<Currency_Conversion_Rate__c>();
    public static List<Currency_Conversion_Rate__c> recordsToUpdate = new List<Currency_Conversion_Rate__c>();

    //V3.2 -- (line 38)
    public static set<String> supportedCurrencies = new Set<String> {'AED', 'USD', 'EGP', 'EUR', 'SAR'};

    @HttpPost
    global static Response handleConversionRates(List<Request> requests) {
        Response response;
        try {
            if (requests == null || requests.isEmpty()) {
                return new Response(400, 'Request body cannot be empty.');
            }

            // Query all existing Currency Conversion Rate records and create a map
            // Key: Name + '_' + Rate_Date (e.g., 'USD-EGP_2025-12-17')
            Map<String, Currency_Conversion_Rate__c> existingRecordsMap = new Map<String, Currency_Conversion_Rate__c>();
            //3.3 MCR-73: Enforce CRUD/FLS via USER_MODE on Currency_Conversion_Rate__c query
            for (Currency_Conversion_Rate__c existingRecord : [
                SELECT Id, Name, Rate_Date__c, CurrencyIsoCode, Target_Currency__c, 
                       Conversion_Rate__c, Inverse_Conversion_Rate__c 
                FROM Currency_Conversion_Rate__c
                WITH USER_MODE
            ]) {
                String mapKey = existingRecord.Name + '_' + String.valueOf(existingRecord.Rate_Date__c);
                existingRecordsMap.put(mapKey, existingRecord);
            }

			Map<String, Decimal> inputConversionRateMap = new Map<String, Decimal>();
            for (Request req : requests) {
                if (String.isBlank(req.fromCurrency)) {
                    return new Response(400, 'Please provide value in fromCurrency.');
                }

				if (String.isBlank(req.toCurrency)) {
                    return new Response(400, 'Please provide value in toCurrecny.');
                }

				if (req.rate == null || req.rate <= 0) {
                    return new Response(400, 'Please provide a valid positive conversion rate.');
                }

                //V3.2 -- (line 75) added this if condition to allow creation/updation of conversion rates for supported currencies only.
                if(supportedCurrencies.contains(req.fromCurrency) && supportedCurrencies.contains(req.toCurrency)) {
                    String recordName = req.fromCurrency.trim().toUpperCase() + '-' + req.toCurrency.trim().toUpperCase();
                    String mapKey = recordName + '_' + String.valueOf(req.rateDate);

                    // Check if record already exists for this Name and Rate Date combination
                    if (existingRecordsMap.containsKey(mapKey)) {
                        // Update existing record
                        Currency_Conversion_Rate__c existingRecord = existingRecordsMap.get(mapKey);
                        if (existingRecord.Conversion_Rate__c != req.rate || existingRecord.Inverse_Conversion_Rate__c != req.inverseRate) {
                            existingRecord.CurrencyIsoCode = req.fromCurrency.trim().toUpperCase();
                            existingRecord.Target_Currency__c = req.toCurrency.trim().toUpperCase();
                            existingRecord.Conversion_Rate__c = req.rate;
                            existingRecord.Inverse_Conversion_Rate__c = req.inverseRate;
                            recordsToUpdate.add(existingRecord);
                        }
                    } else {
                        // Create new record
                        Currency_Conversion_Rate__c newRecord = new Currency_Conversion_Rate__c();
                        newRecord.Name = req.fromCurrency.trim().toUpperCase() + '-' + req.toCurrency.trim().toUpperCase();
                        newRecord.CurrencyIsoCode = req.fromCurrency.trim().toUpperCase();
                        newRecord.Target_Currency__c = req.toCurrency.trim().toUpperCase();
                        newRecord.Conversion_Rate__c = req.rate;
                        newRecord.Inverse_Conversion_Rate__c = req.inverseRate;
                        newRecord.Rate_Date__c = req.rateDate;
                        recordsToInsert.add(newRecord);
                    }
                }
            }

            if (!recordsToUpdate.isEmpty()) {
                //3.3 MCR-73: Enforce CRUD/FLS via USER_MODE on Currency_Conversion_Rate update
                Database.update(recordsToUpdate, AccessLevel.USER_MODE);
            }
            
            if(!recordsToInsert.isEmpty()) {
                //3.3 MCR-73: Enforce CRUD/FLS via USER_MODE on Currency_Conversion_Rate insert
                Database.insert(recordsToInsert, AccessLevel.USER_MODE);
            }

            //Delete old conversion rates that are 6 months older
            Date sixMonthsOld = System.today().addMonths(-6);
            //3.3 MCR-73: Enforce CRUD/FLS via USER_MODE on Currency_Conversion_Rate delete
            List<Currency_Conversion_Rate__c> oldRates = [
                SELECT Id FROM Currency_Conversion_Rate__c WHERE Rate_Date__c < :sixMonthsOld WITH USER_MODE
            ];
            if (!oldRates.isEmpty()) {
                Database.delete(oldRates, AccessLevel.USER_MODE);
            }

			return new Response(200, 'All conversion rates synced successfully in Salesforce.');
		}  catch (Exception ex) {
            //3.3 MCR-73: Log unexpected failures via LoggerService.createApexLog
            LoggerService.save(LoggerService.createApexLog(
                ex,
                'Modon Egypt Conversion Rate API',
                'ModonEgypt_ConversionRateAPI',
                'handleConversionRates'
            ));
            return new Response(500, 'Error Occured: ' + ex.getMessage());
        }
	}
}