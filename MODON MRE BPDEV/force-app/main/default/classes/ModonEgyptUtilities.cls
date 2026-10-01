/**********************************************************************************************************************
* Name               : ModonEgyptUtilities                                                        
* Description        : This class is used as a helper class to provide utility methods specific to Modon Egypt
* Usage              : Accross various classes in the codebase to handle Egypt specific logic
* Created By         : Horizontal Digital                                                    
* --------------------------------------------------------------------------------------------------------------------
* Version       Author           Date            Comment                                                                       
* 1.0           mkapatel         06 Mar 2023     Initial Draft
* 2.0           mkapatel         22 Apr 2026     New methods translateMilestoneDescriptionToArabic, convertAmountInWordsTextArabic and convertAreaInWordsSqMtrSqCmtrTextArabic + renamed methods convertAmountInWordsTextEnglish, convertAreaInWordsSqMtrSqCmtrTextEnglish + updated method getCurrencyUnitAndSubUnit
* 2.1           mkapatel         24 Apr 2026     Updated translateMilestoneDescriptionToArabic method to replace 'maintenance' word
* 2.2           mkapatel         28 Apr 2026     Updated translateMilestoneDescriptionToArabic method to use Installment Map Constant
* 2.3           mkapatel         05 May 2026     Updated translateMilestoneDescriptionToArabic method to replace multiple spaces with single space and defination change of convertAmountInWordsTextArabic and convertAreaInWordsSqMtrSqCmtrTextArabic methods from string to decimal
* 2.4           mkapatel         05 May 2026     Added hasDecimalValueChanged method
* 2.5           mkapatel         18 May 2026     Bug Fix: For AED currency,'ModonEgyptConstants.CURRENCY_AR_UNIT_EMIRATI' was giving incorrect currency (إماراتيي), So, explicitly replacing it with the correct unit 'unitAr' (إماراتي)
* 2.6           mkapatel         29 May 2026     Added CreateSalesOrderInstallments method
* 2.7           mkapatel         05 Jun 2026     Adjusting Maintenance Fees difference in last Maintenance Installment
* 2.8           mkapatel         23 Jun 2026     Quering PaymentInstallements__c records in ascending order of MilestoneNumber__c in createSalesOrderInstallments method
* 2.9           Narendra Agrawal 29 Jun 2026     Updated convertAmountInWordsTextEnglish to pass digits to NumberToText as String to prevent Integer overflow
******************************************************************************************************************/
public with sharing class ModonEgyptUtilities {

    /**
     * getCurrencyUnitAndSubUnit
     * @description Returns a map of main and sub currency unit labels for ISO code and language.
     * @param String currencyIsoCode, String language
     * @return Map<String, String>
     */
    private static Map<String, String> getCurrencyUnitAndSubUnit(String currencyIsoCode, String language) {
        Map<String, String> result = new Map<String, String>();
        if (language == ModonEgyptConstants.LABEL_LANGUAGE_ENGLISH) {
            if (currencyISOCode == ModonEgyptConstants.CURRENCY_ISOCODE_AED) {
                result.put(ModonEgyptConstants.CURRENCY_UNIT, ModonEgyptConstants.CURRENCY_UNIT_DIRHAM);
                result.put(ModonEgyptConstants.CURRENCY_SUB_UNIT, ModonEgyptConstants.CURRENCY_SUB_UNIT_FILS);
            }
            else if( currencyISOCode == ModonEgyptConstants.CURRENCY_ISOCODE_EGP ){
                result.put(ModonEgyptConstants.CURRENCY_UNIT, ModonEgyptConstants.CURRENCY_UNIT_EGP_POUND);
                result.put(ModonEgyptConstants.CURRENCY_SUB_UNIT, ModonEgyptConstants.CURRENCY_SUB_UNIT_PIASTRES);
            }
            else if (currencyISOCode == ModonEgyptConstants.CURRENCY_ISOCODE_USD) {
                result.put(ModonEgyptConstants.CURRENCY_UNIT, ModonEgyptConstants.CURRENCY_UNIT_EGP_US_DOLLAR);
                result.put(ModonEgyptConstants.CURRENCY_SUB_UNIT, ModonEgyptConstants.CURRENCY_SUB_UNIT_CENTS);
            }
            else if( currencyISOCode == ModonEgyptConstants.CURRENCY_ISOCODE_EUR ){
                result.put(ModonEgyptConstants.CURRENCY_UNIT, ModonEgyptConstants.CURRENCY_UNIT_EGP_EURO);
                result.put(ModonEgyptConstants.CURRENCY_SUB_UNIT, ModonEgyptConstants.CURRENCY_SUB_UNIT_CENTS);
            }
            else if( currencyISOCode == ModonEgyptConstants.CURRENCY_ISOCODE_SAR ){
                result.put(ModonEgyptConstants.CURRENCY_UNIT, ModonEgyptConstants.CURRENCY_UNIT_EGP_SAUDI_RIYAL);
                result.put(ModonEgyptConstants.CURRENCY_SUB_UNIT, ModonEgyptConstants.CURRENCY_SUB_UNIT_HALALAS);
            }
        } else if (language == ModonEgyptConstants.LABEL_LANGUAGE_ARABIC) {
            if (currencyIsoCode == ModonEgyptConstants.CURRENCY_ISOCODE_AED) {
                result.put(ModonEgyptConstants.CURRENCY_UNIT, ModonEgyptConstants.CURRENCY_AR_UNIT_AED);
                result.put(ModonEgyptConstants.CURRENCY_SUB_UNIT, ModonEgyptConstants.CURRENCY_AR_SUBUNIT_AED);
            } else if (currencyIsoCode == ModonEgyptConstants.CURRENCY_ISOCODE_EGP) {
                result.put(ModonEgyptConstants.CURRENCY_UNIT, ModonEgyptConstants.CURRENCY_AR_UNIT_EGP);
                result.put(ModonEgyptConstants.CURRENCY_SUB_UNIT, ModonEgyptConstants.CURRENCY_AR_SUBUNIT_EGP);
            } else if (currencyIsoCode == ModonEgyptConstants.CURRENCY_ISOCODE_USD) {
                result.put(ModonEgyptConstants.CURRENCY_UNIT, ModonEgyptConstants.CURRENCY_AR_UNIT_USD);
                result.put(ModonEgyptConstants.CURRENCY_SUB_UNIT, ModonEgyptConstants.CURRENCY_AR_SUBUNIT_USD);
            } else if (currencyIsoCode == ModonEgyptConstants.CURRENCY_ISOCODE_EUR) {
                result.put(ModonEgyptConstants.CURRENCY_UNIT, ModonEgyptConstants.CURRENCY_AR_UNIT_EUR);
                result.put(ModonEgyptConstants.CURRENCY_SUB_UNIT, ModonEgyptConstants.CURRENCY_AR_SUBUNIT_EUR);
            } else if (currencyIsoCode == ModonEgyptConstants.CURRENCY_ISOCODE_SAR) {
                result.put(ModonEgyptConstants.CURRENCY_UNIT, ModonEgyptConstants.CURRENCY_AR_UNIT_SAR);
                result.put(ModonEgyptConstants.CURRENCY_SUB_UNIT, ModonEgyptConstants.CURRENCY_AR_SUBUNIT_SAR);
            }
        }
        
        return result;
    }

    /**
     * convertAmountInWordsTextEnglish
     * @description Converts a decimal amount to uppercase English words with main and sub currency unit labels.
     * @param Decimal amount, String currencyISOCode
     * @return String
     */
    public static string convertAmountInWordsTextEnglish(decimal amount, string currencyISOCode){

        if(String.isBlank(currencyISOCode)){
            return 'Populate Currency to get amount in words'.toUpperCase();
        }
        else if(amount == null || amount == 0){
            return 'Populate Amount to get amount in words'.toUpperCase();
        }

        Map<String, String> currencyInfo = getCurrencyUnitAndSubUnit(currencyISOCode, ModonEgyptConstants.LABEL_LANGUAGE_ENGLISH);
        String currencyUnit = currencyInfo.get(ModonEgyptConstants.CURRENCY_UNIT);
        String currencySubUnit = currencyInfo.get(ModonEgyptConstants.CURRENCY_SUB_UNIT);

        if(String.isBlank(currencyUnit) || String.isBlank(currencySubUnit)){
            return 'Currency not supported for amount in words'.toUpperCase();
        }

        String amountInWords = '';
        if(amount !=null){
            Decimal totalAmount = amount.setScale(2, System.RoundingMode.HALF_UP) ;
            String totalAmountString = String.valueOf(totalAmount);
            String beforeDecimal='';
            String afterDecimal='';
            
            //v2.9 START
            if(totalAmountString.contains('.')){
                beforeDecimal = totalAmountString.substringBefore('.');
                beforeDecimal = NumberToText.convert(beforeDecimal);

                afterDecimal = totalAmountString.substringAfter('.');
                afterDecimal = NumberToText.convert(afterDecimal);
                
            }else{
                beforeDecimal = NumberToText.convert(totalAmountString);
            }
            //v2.9 END
            
            if(String.isNotBlank(beforeDecimal)){
                amountInWords =  beforeDecimal + ' '+currencyUnit+' ';
            }
            if(String.isNotBlank(afterDecimal) && afterDecimal != ModonEgyptConstants.LABEL_ZERO_ENGLISH){
                amountInWords = amountInWords + ModonEgyptConstants.LABEL_AND_ENGLISH.toLowerCase() + ' ' +afterDecimal + ' '+currencySubUnit+' ';
            }
            amountInWords = amountInWords + ModonEgyptConstants.LABEL_ONLY_ENGLISH ;
        }
        return amountInWords.toUpperCase();
    }

    /**
     * translateMilestoneDescriptionToArabic
     * @description Replaces down payment and installment English milestone text with the matching Arabic text when applicable.
     * @param String milestoneDescription
     * @return String
     */
    public static String translateMilestoneDescriptionToArabic(String milestoneDescription) {
        if (String.isBlank(milestoneDescription)) {
            return milestoneDescription;
        }
        return ModonEgyptConstants.PP_INSTALLMENT_MAP.get(milestoneDescription.trim().replaceAll(' ', '').toLowerCase());
    }

    /**
     * convertAmountInWordsTextArabic
     * @description Calls the Arabic number-to-words service and applies Arabic main and sub currency unit text.
     * @param Decimal amount, String currencyIsoCode
     * @return String
     */
    public static String convertAmountInWordsTextArabic(Decimal amount, String currencyIsoCode) {
        String result;
        if (String.isBlank(currencyIsoCode)) {
            currencyIsoCode = ModonEgyptConstants.CURRENCY_ISOCODE_AED;
        }
        
        String amountInString = String.valueOf(amount.setScale(2, System.RoundingMode.HALF_UP)) ;

        Map<String, String> arabicCurrency = getCurrencyUnitAndSubUnit(currencyIsoCode, ModonEgyptConstants.LABEL_LANGUAGE_ARABIC);
        String unitAr  = arabicCurrency.get(ModonEgyptConstants.CURRENCY_UNIT);
        String subAr   = arabicCurrency.get(ModonEgyptConstants.CURRENCY_SUB_UNIT);

        Arabic_Translation_Settings__mdt ArabicSettings = Arabic_Translation_Settings__mdt.getInstance('Number_to_ArabicWord');
        String end_piont = ArabicSettings.Endpoint_URL__c + '?inputNumber=' + amountInString;
        Http insHttp = new Http();
        HttpRequest httpReq = new HttpRequest();
        httpReq.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        httpReq.setHeader('Accept', '*/*');
        httpReq.setHeader('Accept-Encoding', 'gzip, deflate, br');
        httpReq.setHeader('Connection', 'keep-alive');
        httpReq.setHeader('Authorization', ArabicSettings.Authorization__c);
        httpReq.setMethod('GET');
        httpReq.setTimeout(120000);
        httpReq.setEndpoint(end_piont);

        HttpResponse httpResponse = new HttpResponse();
        try {
            httpResponse = insHttp.send(httpReq);
            System.debug('httpResponse: ' + httpResponse);
            System.debug('httpResponse: ' + httpResponse.getBody());
            for (String headerKey : httpResponse.getHeaderKeys()) {
                System.debug('httpResponse.getHeader(' + headerKey + '): ' + httpResponse.getHeader(headerKey));
            }

            if (httpResponse.getStatusCode() == 200) {
                result = httpResponse.getBody();
                if (String.isNotBlank(unitAr) && String.isNotBlank(subAr)) {
                    result = result.replaceAll(ModonEgyptConstants.CURRENCY_AR_API_DEFAULT_UNIT, unitAr);
                    result = result.replaceAll(ModonEgyptConstants.CURRENCY_AR_UNIT_AED, unitAr);
                    //v2.5 Bug Fix: For AED currency,'ModonEgyptConstants.CURRENCY_AR_UNIT_EMIRATI' was giving incorrect currency (إماراتيي), So, explicitly replacing it with the correct unit 'unitAr' (إماراتي)
                    result = result.replaceAll(ModonEgyptConstants.CURRENCY_AR_UNIT_EMIRATI, unitAr);
                    result = result.replaceAll(ModonEgyptConstants.CURRENCY_AR_API_DEFAULT_SUBUNIT, subAr);
                }
            }
        } catch (Exception ex) {
            System.debug('Exception number to arabic: ' + ex);
        }

        return String.isNotBlank(result) ? (result + ModonEgyptConstants.LABEL_ONLY_AR) : null;
    }

    /**
     * convertAreaInWordsSqMtrSqCmtrTextEnglish
     * @description Converts an area value to uppercase English words in square meters and square centimeters.
     * @param Decimal area
     * @return String
     */
    public static String convertAreaInWordsSqMtrSqCmtrTextEnglish(Decimal area) {
        String areaInWords = '';
        if (area == null || area == 0) {
            return (ModonEgyptConstants.LABEL_ZERO_ENGLISH + ' ' + ModonEgyptConstants.LABEL_SQUARE_METER_ENGLISH + ' ' + ModonEgyptConstants.LABEL_AND_ENGLISH + ' ' + ModonEgyptConstants.LABEL_ZERO_ENGLISH + ' ' + ModonEgyptConstants.LABEL_SQUARE_CENTIMETER_ENGLISH).toUpperCase();
        }
        if(area != null) {
            Decimal totalArea = area.setScale(2, System.RoundingMode.HALF_UP) ;
            String totalAreaString = String.valueOf(totalArea);
            String beforeDecimal='';
            String afterDecimal='';
            
            if(totalAreaString.contains('.')){
                beforeDecimal = totalAreaString.substringBefore('.');
                beforeDecimal = NumberToText.convert(Integer.valueOf(beforeDecimal));

                afterDecimal = totalAreaString.substringAfter('.');
                afterDecimal = NumberToText.convert(Integer.valueOf(afterDecimal));
                
            }else{
                beforeDecimal = NumberToText.convert(Integer.valueOf(totalArea));
            }
            
            if(String.isNotBlank(beforeDecimal)){
                areaInWords =  beforeDecimal + ' ' + ModonEgyptConstants.LABEL_SQUARE_METER_ENGLISH.toLowerCase();
            }
            if(String.isNotBlank(afterDecimal) && afterDecimal != ModonEgyptConstants.LABEL_ZERO_ENGLISH){
                areaInWords = areaInWords + ' ' + ModonEgyptConstants.LABEL_AND_ENGLISH.toLowerCase() + ' ' + afterDecimal + ' ' + ModonEgyptConstants.LABEL_SQUARE_CENTIMETER_ENGLISH.toLowerCase();
            }
        }
        return areaInWords.toUpperCase();
    }

    /**
     * convertAreaInWordsSqMtrSqCmtrTextArabic
     * @description Fetches Arabic area words and swaps default units to Arabic square meter and centimeter labels.
     * @param Decimal area
     * @return String
     */
    public static String convertAreaInWordsSqMtrSqCmtrTextArabic(Decimal area){
        String result;
        String areaInString = String.valueOf(area.setScale(2, System.RoundingMode.HALF_UP)) ;
        Arabic_Translation_Settings__mdt ArabicSettings = Arabic_Translation_Settings__mdt.getInstance('Number_to_ArabicWord');
        String end_piont = ArabicSettings.Endpoint_URL__c + '?inputNumber='+areaInString;
        http insHttp = new Http();
        HttpRequest httpReq = new HttpRequest();
        httpReq.setHeader('Content-Type','application/x-www-form-urlencoded');
        httpReq.setHeader('Accept','*/*');
        httpReq.setHeader('Accept-Encoding','gzip, deflate, br');
        httpReq.setHeader('Connection','keep-alive');
        httpReq.setHeader('Authorization', ArabicSettings.Authorization__c);
        httpReq.setMethod('GET');
        httpReq.setTimeout(120000);
        httpReq.setEndpoint(end_piont);
        
        HttpResponse httpResponse = new HttpResponse();
        try{
            httpResponse = insHttp.send(httpReq);
            system.debug('httpResponse: ' + httpResponse);
            system.debug('httpResponse: ' + httpResponse.getBody());
            for (String headerKey : httpResponse.getHeaderKeys()) {
                System.debug('httpResponse.getHeader(' + headerKey + '): ' + httpResponse.getHeader(headerKey));
            }
            
            if(httpResponse.getStatusCode() == 200){
                
                result = httpResponse.getBody();
                result = result.replaceAll(ModonEgyptConstants.CURRENCY_AR_API_DEFAULT_UNIT, ModonEgyptConstants.AREA_AR_SQ_MTR);
                result = result.replaceAll(ModonEgyptConstants.CURRENCY_AR_UNIT_AED, ModonEgyptConstants.AREA_AR_SQ_MTR);
                result = result.replaceAll(ModonEgyptConstants.CURRENCY_AR_API_DEFAULT_SUBUNIT, ModonEgyptConstants.AREA_AR_SQ_CMTR);
            }
        }Catch (Exception ex){
            system.debug('Exception number to arabic: ' + ex);
        }
        
        return result;
    }

    /**
     * hasDecimalValueChanged
     * @description Helper method to check if a decimal value has changed
     * @param Decimal newVal, Decimal oldVal (new and old values to compare)
     * @return Boolean
     */
    public static Boolean hasDecimalValueChanged(Decimal newVal, Decimal oldVal) {
        if (newVal == null && oldVal == null) return false;
        if (newVal == null || oldVal == null) return true;
        return newVal != oldVal;
    }







    /**************************************************************************************************************************************************************************************
     * Method		 :	createSalesOrderInstallments
     * Description	 :	This method is used to create sales order installments for sales orders (Supports Standard and Flexible Plans)
     * Parameters	 :  List<SalesOrder__c> salesOrderList, Map<Id, List<CustomInstallment>> flexInstallmentMap
     * Returns		 :	void
    ***************************************************************************************************************************************************************************************/
    public static String createSalesOrderInstallments(List<SalesOrder__c> salesOrderList, Map<Id, List<CustomInstallment>> flexInstallmentMap){
        
        Set<Id> unitIds = new Set<Id>();
        Set<String> currencyList = new Set<String>();
        Map<String, String> salesOrderPaymentPlanMap = new Map<String, String>();
        set<Id> paymentSet = new set<Id>();

        // 1. Collect standard data sets
        for(SalesOrder__c soObj : salesOrderList){
            unitIds.add(soObj.Unit__c);
            currencyList.add(soObj.CurrencyIsoCode);
            
            // Only add to the standard query set if it is a Standard Plan
            if(soObj.PaymentPlan__c != null) {
                salesOrderPaymentPlanMap.put(soObj.Id, soObj.PaymentPlan__c);
                paymentSet.add(soObj.PaymentPlan__c);
            }
        }
        
        try {

        // 2. Query Base Prices (Used for Standard Maintenance Fee calculation)
        List<UnitPaymentPlanMapping__c> unitPaymentPlanMappingList = [
            SELECT Id, Base_Price__c, Unit__c, Payment_Plan__c, CurrencyIsoCode 
            FROM UnitPaymentPlanMapping__c 
            WHERE Unit__c IN :unitIds 
            AND CurrencyIsoCode IN :currencyList 
            AND Payment_Plan__r.Name LIKE '%8 Year%' 
            AND Payment_Plan__r.isDefault__c = true
            AND Payment_Plan__r.isFurnishedPaymentPlan__c = false
            AND (NOT(Payment_Plan__r.Name LIKE '%Cash%' OR Payment_Plan__r.Name LIKE '%cash%'))
        ];

        List<SalesOrderInstallments__c> salesOrderInstallmentLst = new List<SalesOrderInstallments__c>(); 
        Map<String, List<PaymentInstallements__c>> paymentPlanInstallmentMap = new Map<String, List<PaymentInstallements__c>>();
        
        // 3. Query Standard Installment templates (ONLY if standard plans exist in the cart)
        if(!paymentSet.isEmpty()) {
            for(PaymentInstallements__c piObj : [
                SELECT Id, Name, PaymentInstallment__c, BrokerPayout__c, IsHandoverPayment__c, Milestone__c, 
                Milestone_Egypt_Percent__c, PaymentInstallment__r.Maintenance_Fee__c, MilestoneDate__c, 
                MilestoneDescription__c, MilestoneNumber__c, SalesAgentPayout__c, Is_Maintenance_Installment__c, 
                PaymentInstallment__r.Number_of_Maintenance_Fee__c, No_Of_Months_To_Add_From_Last_Date__c 
                FROM PaymentInstallements__c 
                WHERE PaymentInstallment__c IN : paymentSet
                ORDER BY MilestoneNumber__c ASC //v2.8
            ]){
                List<PaymentInstallements__c> tempInstallment = paymentPlanInstallmentMap.get(piObj.PaymentInstallment__c);
                if(tempInstallment == null){
                    tempInstallment = new List<PaymentInstallements__c>();
                }
                tempInstallment.add(piObj);
                paymentPlanInstallmentMap.put(piObj.PaymentInstallment__c, tempInstallment);
            }
        }
        
        // 4. Generate the actual Sales Order Installment records
        for(SalesOrder__c soObj : salesOrderList){
            
            // ==========================================
            // CASE A: FLEXIBLE PAYMENT PLAN
            // ==========================================
            if(soObj.PaymentPlan__c == null && flexInstallmentMap != null && flexInstallmentMap.containsKey(soObj.Id)) {
                List<CustomInstallment> customList = flexInstallmentMap.get(soObj.Id);
                
                for(CustomInstallment flex : customList) {
                    SalesOrderInstallments__c soiObj = new SalesOrderInstallments__c();
                    soiObj.SalesOrder__c = soObj.Id;
                    soiObj.Milestone_Egypt_Percent__c = flex.milestoneEgyptPercent;
                    soiObj.MilestoneDate__c = flex.milestoneDate;
                    soiObj.MilestoneDescription__c = flex.milestoneDescription;
                    soiObj.MilestoneNumber__c = flex.milestoneNumber;
                    soiObj.InstallmentAmount__c = flex.amount;
                    soiObj.Maintenance_Fee__c = flex.maintainancefee != null ? flex.maintainancefee : 0;
                    soiObj.CurrencyIsoCode = soObj.CurrencyIsoCode;
                    
                    salesOrderInstallmentLst.add(soiObj);
                }
            }
            // ==========================================
            // CASE B: STANDARD PAYMENT PLAN (Your Existing Logic)
            // ==========================================
            else if (soObj.PaymentPlan__c != null && paymentPlanInstallmentMap.containsKey(soObj.PaymentPlan__c)) {
                Integer monthsCounter = 0;
                Decimal basePrice8Year = 0;
                
                Date bookingDate = soObj.ExactBookingDate_Egypt__c != null ? soObj.ExactBookingDate_Egypt__c : Date.today(); 
                
                for(UnitPaymentPlanMapping__c unitPaymentPlanMappingObj : unitPaymentPlanMappingList) {
                    if(unitPaymentPlanMappingObj.Unit__c == soObj.Unit__c && unitPaymentPlanMappingObj.CurrencyIsoCode == soObj.CurrencyIsoCode) {
                        basePrice8Year = unitPaymentPlanMappingObj.Base_Price__c;
                    }
                }
                Decimal sumOfAllInstallmentAmounts = 0;

                // Maintenance fee adjustment tracking
                Decimal sumOfAllMaintenanceFees = 0;
                Decimal derivedMaintenanceTotal = 0;
                Integer lastMaintenanceSOIIndex = -1;
                
                for(PaymentInstallements__c piObj : paymentPlanInstallmentMap.get(salesOrderPaymentPlanMap.get(soObj.Id))){
                    SalesOrderInstallments__c soiObj = new SalesOrderInstallments__c();
                    Decimal milestonePercent = piObj.Milestone_Egypt_Percent__c;
                    
                    soiObj.SalesOrder__c = soObj.Id;
                    soiObj.PaymentInstallments__c = piObj.Id;
                    soiObj.BrokerPayout__c = piObj.BrokerPayout__c;
                    soiObj.IsHandoverPayment__c = piObj.IsHandoverPayment__c ;
                    soiObj.Milestone_Egypt_Percent__c = milestonePercent;  
                    
                    monthsCounter += piObj.MilestoneNumber__c == 1 ? 0 : (piObj.No_Of_Months_To_Add_From_Last_Date__c != null ? Integer.valueOf(piObj.No_Of_Months_To_Add_From_Last_Date__c) : 3);            
                    soiObj.MilestoneDate__c = piObj.MilestoneNumber__c == 1 ? bookingDate : bookingDate.addMonths(monthsCounter); 
                    soiObj.MilestoneDescription__c = piObj.MilestoneDescription__c;
                    soiObj.MilestoneNumber__c = piObj.MilestoneNumber__c;
                    soiObj.SalesAgentPayout__c = piObj.SalesAgentPayout__c;
                    
                    Decimal installmentAmount = (soObj.TotalAmount__c) * (milestonePercent / 100);
                    soiObj.InstallmentAmount__c = installmentAmount.setScale(2, System.RoundingMode.HALF_UP);
                    sumOfAllInstallmentAmounts += installmentAmount.setScale(2, System.RoundingMode.HALF_UP); 
                    if(piObj.Is_Maintenance_Installment__c){
                        soiObj.Maintenance_Fee__c = basePrice8Year > 0 ? (((basePrice8Year) * (piObj.PaymentInstallment__r.Maintenance_Fee__c/100)) / piObj.PaymentInstallment__r.Number_of_Maintenance_Fee__c).setScale(2, System.RoundingMode.HALF_UP) : 0;

                        // Track for maintenance fee adjustment
                        if (derivedMaintenanceTotal == 0 && basePrice8Year > 0) {
                            derivedMaintenanceTotal = (piObj.PaymentInstallment__r.Maintenance_Fee__c / 100) * basePrice8Year;
                        }
                        sumOfAllMaintenanceFees += soiObj.Maintenance_Fee__c.setScale(2, System.RoundingMode.HALF_UP);
                        lastMaintenanceSOIIndex = salesOrderInstallmentLst.size(); // index after add
                    }else{
                        soiObj.Maintenance_Fee__c = 0;
                    }
                    soiObj.CurrencyIsoCode = soObj.CurrencyIsoCode;

                    salesOrderInstallmentLst.add(soiObj);
                }

                if(sumOfAllInstallmentAmounts != soObj.TotalAmount__c) {
                    Decimal difference = soObj.TotalAmount__c - sumOfAllInstallmentAmounts;
                    Decimal updatedLastInstallmentAmount = salesOrderInstallmentLst[salesOrderInstallmentLst.size() - 1].InstallmentAmount__c + difference;
                    salesOrderInstallmentLst[salesOrderInstallmentLst.size() - 1].InstallmentAmount__c = updatedLastInstallmentAmount.setScale(2, System.RoundingMode.HALF_UP);
                }

                // Adjust last maintenance installment to absorb rounding difference
                if (lastMaintenanceSOIIndex >= 0 && derivedMaintenanceTotal > 0 && sumOfAllMaintenanceFees != derivedMaintenanceTotal) {
                    Decimal maintenanceDifference = derivedMaintenanceTotal - sumOfAllMaintenanceFees;
                    Decimal updatedLastMaintenanceFee = salesOrderInstallmentLst[lastMaintenanceSOIIndex].Maintenance_Fee__c + maintenanceDifference;
                    salesOrderInstallmentLst[lastMaintenanceSOIIndex].Maintenance_Fee__c = updatedLastMaintenanceFee.setScale(2, System.RoundingMode.HALF_UP);
                }
            }            
        }
        
        // 5. Insert all generated installments (both Standard and Flexible combined)
        if(!salesOrderInstallmentLst.isEmpty()){
            INSERT salesOrderInstallmentLst;
        }

        } catch (Exception e) {
            System.debug('Exception in createSalesOrderInstallments: ' + e);
            return e.getMessage();
        }

        return ModonEgyptConstants.MSG_SUCCESS;
    }

    /**
     * updateExistingSalesOrderAndCreateInstallments
     * Helper method to update an existing Sales Order and rebuild its installments.
     */



    // ================== WRAPPER CLASSES ================== //

    public class CustomInstallment {
        @AuraEnabled public String id {get;set;}
        @AuraEnabled public Integer milestoneNumber {get;set;}
        @AuraEnabled public String milestoneDescription {get;set;}
        @AuraEnabled public Decimal milestoneEgyptPercent {get;set;}
        @AuraEnabled public Decimal maintainancefee {get;set;}
        @AuraEnabled public Decimal amount {get;set;}
        @AuraEnabled public Date milestoneDate {get;set;}
        @AuraEnabled public String currencyCode {get;set;} 
    }
}