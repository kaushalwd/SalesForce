/**********************************************************************************************************************
* Name               : Egypt_StandardPaymentPlanController
* Description        : Controller for standard payment plan calculations in Modon Egypt.
* Created By         : Shahil Sinha
* --------------------------------------------------------------------------------------------------------------------
* Version       Author           Date            Comment
* 1.0           Milin Kapatel    01 Jun 2026     Initial version.
* 1.1           Shahil Sinha     02 Jun 2026     Refactored to delegate queries to Egypt_DataAccessLayer
* 1.2           Milin Kapatel    05 Jun 2026     Adjusting Maintenance Fees difference in last Maintenance Installment
* 1.3           Milin Kapatel    08 Jun 2026     Bug fix: Setting correct Total Maintenance Amount in PaymentDetails wrapper
* 1.4           Shahil Sinha     09 Jun 2026     Refactored database queries to use the generic DataAccessLayer query method
* 1.5           Milin Kapatel    02 Jun 2026     Rounding issue error fix
******************************************************************************************************************/
public with sharing class Egypt_StandardPaymentPlanController {
    /**************************************************************************************************************************************************************************************
     * Method		 :	buildSalesOrderInstance
     * Description	 :	This method is used to fetch payment plan and unit payment plan mapping records for selected unit
     * Parameters	 :  String selectedUnitId
     * Returns		 :	UnitDetailsWrapper
     * V3.0          :  Added Payment_Plan__r.Name in buildSalesOrderInstance's UnitPaymentPlanMapping's query
     ***************************************************************************************************************************************************************************************/
    @AuraEnabled
    public static UnitDetailsWrapper buildSalesOrderInstance(String selectedUnitId, String exactBookingDateStr) {
    
        UnitDetailsWrapper udObj = new UnitDetailsWrapper();
    
        if (String.isBlank(selectedUnitId)) {
            return udObj;
        }

        String phaseId   = ModonEgyptConstants.EMPTY_STRING;
        String projectId = ModonEgyptConstants.EMPTY_STRING;
    
        // Fetch Unit via Data Access Layer - Refactored to generic query by Shahil Sinha
        List<Unit__c> unitList = (List<Unit__c>) Egypt_DataAccessLayer.query(
            'Unit__c',
            'Id = :unitId',
            null,
            null,
            new Map<String, Object>{ 'unitId' => selectedUnitId }
        );
        for (Unit__c unitObj : unitList) {
            if (String.isNotBlank(unitObj.Phase__c)) {
                phaseId = unitObj.Phase__c;
                if (String.isNotBlank(unitObj.Phase__r.Project__c)) {
                    projectId = unitObj.Phase__r.Project__c;
                }
            }
        }
    
        // Fetch Mappings via Data Access Layer - Refactored to generic query by Shahil Sinha
        List<UnitPaymentPlanMapping__c> mappingLst = (List<UnitPaymentPlanMapping__c>) Egypt_DataAccessLayer.query(
            'UnitPaymentPlanMapping__c',
            'Unit__c = :unitId',
            null,
            null,
            new Map<String, Object>{ 'unitId' => selectedUnitId }
        );
        udObj.unitPaymentPlanOptions = mappingLst;
 
        Set<Id> paymentPlanIds = new Set<Id>();    
        for(UnitPaymentPlanMapping__c unitPaymentPlanMapping : mappingLst) {
            paymentPlanIds.add(unitPaymentPlanMapping.Payment_Plan__c);
        }
    
        // Fetch Payment Plans via Data Access Layer - Refactored to generic query by Shahil Sinha
        List<PaymentPlan__c> paymentPlanLst = new List<PaymentPlan__c>();
        List<PaymentPlan__c> queriedPlans = (List<PaymentPlan__c>) Egypt_DataAccessLayer.query(
            'PaymentPlan__c',
            'Id IN :paymentPlanIds',
            null,
            null,
            new Map<String, Object>{ 'paymentPlanIds' => paymentPlanIds }
        );
        for (PaymentPlan__c pp : queriedPlans) {
            if (pp.isActive__c) {
                paymentPlanLst.add(pp);
            }
        }
    
        Date bookingDate = Date.today();
        if (String.isNotBlank(exactBookingDateStr)) {
            try {
                bookingDate = Date.valueOf(exactBookingDateStr);
            } catch (Exception e) {
                bookingDate = Date.today();
            }
        }
    
        Map<String, Decimal> mappingPriceMap = new Map<String, Decimal>();
        Map<String, UnitPaymentPlanMapping__c> mappingByPlanId = new Map<String, UnitPaymentPlanMapping__c>();
        //7.8
        Decimal basePrice8YearPlanEGP = 0;
        Decimal furnishedBasePrice8YearPlanEGP = 0;
        Decimal basePrice8YearPlanUSD = 0;
        Decimal furnishedBasePrice8YearPlanUSD = 0;
        Decimal basePrice8YearPlanAED = 0;
        Decimal furnishedBasePrice8YearPlanAED = 0;
    
        //v7.6
        for (UnitPaymentPlanMapping__c mapping : mappingLst) {
            String compositeKey = mapping.Payment_Plan__c + '|' + mapping.CurrencyIsoCode;
            mappingPriceMap.put(compositeKey, mapping.Base_Price__c);
            mappingByPlanId.put(mapping.Payment_Plan__c, mapping);

            String planNameLower = mapping.Payment_Plan__r.Name != null ? mapping.Payment_Plan__r.Name.toLowerCase() : ModonEgyptConstants.EMPTY_STRING;
            //v7.8
            if (mapping.Payment_Plan__r.isDefault__c && planNameLower.contains('8')) {
                if (mapping.CurrencyIsoCode == ModonEgyptConstants.CURRENCY_ISOCODE_EGP) {
                    if (!mapping.Payment_Plan__r.isFurnishedPaymentPlan__c) {
                        basePrice8YearPlanEGP = mapping.Base_Price__c != null ? mapping.Base_Price__c : 0;
                    } else if (mapping.Payment_Plan__r.isFurnishedPaymentPlan__c) {
                        furnishedBasePrice8YearPlanEGP = mapping.Base_Price__c != null ? mapping.Base_Price__c : 0;
                    }
                } else if (mapping.CurrencyIsoCode == ModonEgyptConstants.CURRENCY_ISOCODE_USD) {
                    if (!mapping.Payment_Plan__r.isFurnishedPaymentPlan__c) {
                        basePrice8YearPlanUSD = mapping.Base_Price__c != null ? mapping.Base_Price__c : 0;
                    } else if (mapping.Payment_Plan__r.isFurnishedPaymentPlan__c) {
                        furnishedBasePrice8YearPlanUSD = mapping.Base_Price__c != null ? mapping.Base_Price__c : 0;
                    }
                } else if (mapping.CurrencyIsoCode == ModonEgyptConstants.CURRENCY_ISOCODE_AED) {
                    if (!mapping.Payment_Plan__r.isFurnishedPaymentPlan__c) {
                        basePrice8YearPlanAED = mapping.Base_Price__c != null ? mapping.Base_Price__c : 0;
                    } else if (mapping.Payment_Plan__r.isFurnishedPaymentPlan__c) {
                        furnishedBasePrice8YearPlanAED = mapping.Base_Price__c != null ? mapping.Base_Price__c : 0;
                    }
                }
            } 
        }
    
    
        List<PaymentDetails>          paymentLst         = new List<PaymentDetails>();
        List<Map<String, String>>     availablePaymentPlan = new List<Map<String, String>>();
    
        for (PaymentPlan__c pp : paymentPlanLst) {
    
            PaymentDetails paymentObj = new PaymentDetails();
            paymentObj.paymentObj    = pp;
    
            paymentObj.paymentPlanId              = pp.Id;
            paymentObj.paymentPlanName            = pp.Name;
            paymentObj.paymentPlanCurrency        = pp.CurrencyIsoCode;
            paymentObj.paymentPlanDiscountPercent = pp.Discount_Percent__c != null ? pp.Discount_Percent__c : 0;
            paymentObj.maintenanceFeePercent      = pp.Maintenance_Fee__c != null ? pp.Maintenance_Fee__c : 0;
            paymentObj.numberOfMaintenanceFee     = pp.Number_of_Maintenance_Fee__c != null
                                                        ? Integer.valueOf(pp.Number_of_Maintenance_Fee__c) : 0;
    
            String priceKey = pp.Id + '|' + pp.CurrencyIsoCode;
            Decimal basePriceFromMapping = mappingPriceMap.containsKey(priceKey)
                                                ? mappingPriceMap.get(priceKey) : 0;
            Decimal maintenanceAmountBasePrice;
            paymentObj.basePriceFromMapping = basePriceFromMapping;
            
            //v7.8
            paymentObj.basePrice8YearPlanEGP = pp.isFurnishedPaymentPlan__c ? furnishedBasePrice8YearPlanEGP : basePrice8YearPlanEGP;
            paymentObj.basePrice8YearPlanAED = pp.isFurnishedPaymentPlan__c ? furnishedBasePrice8YearPlanAED : basePrice8YearPlanAED;
            
            if(pp.CurrencyIsoCode == ModonEgyptConstants.CURRENCY_ISOCODE_EGP) {
                paymentObj.basePrice8YearPlan = pp.isFurnishedPaymentPlan__c ? furnishedBasePrice8YearPlanEGP : basePrice8YearPlanEGP;
                maintenanceAmountBasePrice = basePrice8YearPlanEGP;
            } else if(pp.CurrencyIsoCode == ModonEgyptConstants.CURRENCY_ISOCODE_USD) {
                paymentObj.basePrice8YearPlan = pp.isFurnishedPaymentPlan__c ? furnishedBasePrice8YearPlanUSD : basePrice8YearPlanUSD;
                maintenanceAmountBasePrice = basePrice8YearPlanUSD;
            } else if(pp.CurrencyIsoCode == ModonEgyptConstants.CURRENCY_ISOCODE_AED) {
                paymentObj.basePrice8YearPlan = pp.isFurnishedPaymentPlan__c ? furnishedBasePrice8YearPlanAED : basePrice8YearPlanAED;
                maintenanceAmountBasePrice = basePrice8YearPlanAED;
            }
    
            Decimal totalMaintenanceFees = 0;
            //v1.3
            if (paymentObj.numberOfMaintenanceFee > 0 && maintenanceAmountBasePrice > 0) {
                totalMaintenanceFees = (paymentObj.maintenanceFeePercent / 100) * maintenanceAmountBasePrice;
            }
            paymentObj.totalMaintenanceFees = totalMaintenanceFees;
    
            Integer counter = 0;
            Decimal sumOfAllInstallmentAmounts = 0;

            // Maintenance fee adjustment tracking
            Decimal sumOfAllMaintenanceFees = 0;
            Decimal derivedMaintenanceTotal = 0;
            Integer lastMaintenanceIndex = -1;

            List<PaymentInstallmentWrapper> installmentWrappers = new List<PaymentInstallmentWrapper>();
    
            for (PaymentInstallements__c pi : pp.Payment_Installments__r) {
    
                PaymentInstallmentWrapper piw = new PaymentInstallmentWrapper();
    
                piw.id                                  = pi.Id;
                piw.name                                = pi.Name;
                piw.milestoneNumber                     = pi.MilestoneNumber__c != null
                                                            ? Integer.valueOf(pi.MilestoneNumber__c) : 0;
                piw.milestoneDescription                = pi.MilestoneDescription__c;
                piw.milestonePercent                    = pi.Milestone_Egypt_Percent__c != null
                                                            ? pi.Milestone_Egypt_Percent__c
                                                            : (pi.Milestone__c != null ? pi.Milestone__c : 0);
                piw.brokerPayout                        = pi.BrokerPayout__c;
                piw.salesAgentPayout                    = pi.SalesAgentPayout__c;
                piw.isHandoverPayment                   = pi.IsHandoverPayment__c;
                piw.isMaintenanceInstallment            = pi.Is_Maintenance_Installment__c;
                piw.noOfMonthsToAddFromLastDate         = pi.No_Of_Months_To_Add_From_Last_Date__c != null
                                                            ? Integer.valueOf(pi.No_Of_Months_To_Add_From_Last_Date__c) : 3;
    
                piw.currencyCode = pp.CurrencyIsoCode;
    
                if (piw.milestoneNumber != 1) {
                    counter += piw.noOfMonthsToAddFromLastDate;
                }
                piw.milestoneDate = bookingDate.addMonths(counter);
    
                piw.amount = ((piw.milestonePercent / 100) * basePriceFromMapping).setScale(2, System.RoundingMode.HALF_UP); // v1.5
                sumOfAllInstallmentAmounts += piw.amount.setScale(2, System.RoundingMode.HALF_UP);
                piw.amountText = piw.currencyCode + ' ' + piw.amount.setScale(2, System.RoundingMode.HALF_UP).toPlainString();
                
                if (pi.Is_Maintenance_Installment__c && paymentObj.numberOfMaintenanceFee > 0 && maintenanceAmountBasePrice > 0) {
                    piw.maintainancefee = (((paymentObj.maintenanceFeePercent / 100) * maintenanceAmountBasePrice) / paymentObj.numberOfMaintenanceFee).setScale(2, System.RoundingMode.HALF_UP); // v1.5

                    // Track for maintenance fee adjustment
                    if (derivedMaintenanceTotal == 0) {
                        derivedMaintenanceTotal = (paymentObj.maintenanceFeePercent / 100) * maintenanceAmountBasePrice;
                    }
                    sumOfAllMaintenanceFees += piw.maintainancefee.setScale(2, System.RoundingMode.HALF_UP);
                    lastMaintenanceIndex = installmentWrappers.size(); // index at which this wrapper will be added
                } else {
                    piw.maintainancefee = 0;
                }
                piw.maintainancefeeText = piw.currencyCode + ' ' + piw.maintainancefee.setScale(2, System.RoundingMode.HALF_UP).toPlainString();

                installmentWrappers.add(piw);
            }

            //v7.8
            if(sumOfAllInstallmentAmounts != basePriceFromMapping) {
                Decimal difference = basePriceFromMapping - sumOfAllInstallmentAmounts;
                installmentWrappers[installmentWrappers.size() - 1].amount += difference;
                installmentWrappers[installmentWrappers.size() - 1].amountText = installmentWrappers[installmentWrappers.size() - 1].currencyCode + ' ' + installmentWrappers[installmentWrappers.size() - 1].amount.setScale(2, System.RoundingMode.HALF_UP).toPlainString();
            }

            // Adjust last maintenance installment to absorb rounding difference
            if (lastMaintenanceIndex >= 0 && derivedMaintenanceTotal > 0 && sumOfAllMaintenanceFees != derivedMaintenanceTotal) {
                Decimal maintenanceDifference = derivedMaintenanceTotal - sumOfAllMaintenanceFees;
                installmentWrappers[lastMaintenanceIndex].maintainancefee += maintenanceDifference;
                installmentWrappers[lastMaintenanceIndex].maintainancefeeText =
                    installmentWrappers[lastMaintenanceIndex].currencyCode + ' ' +
                    installmentWrappers[lastMaintenanceIndex].maintainancefee.setScale(2, System.RoundingMode.HALF_UP).toPlainString();
            }
    
            paymentObj.paymentInstallmentWrappers = installmentWrappers;
    
            paymentObj.totalEGPPrice = 0;
            paymentObj.totalUSDPrice = 0;
            paymentObj.totalAEDPrice = 0;
    
            String planNameLower = pp.Name != null ? pp.Name.toLowerCase() : ModonEgyptConstants.EMPTY_STRING;
            //v7.8
            String planKey = ModonEgyptConstants.EMPTY_STRING;
            Boolean isCashPaymentPlan = false;
            Boolean isFurnishedPaymentPlan = false;

            if (planNameLower.contains('cash')) {
                planKey = 'cash';
                isCashPaymentPlan = true;
            } else if (planNameLower.contains('8 year')) {
                planKey = '8 year';
            } else if (planNameLower.contains('6 year')) {
                planKey = '6 year';
            } else if (planNameLower.contains('4 year')) {
                planKey = '4 year';
            }

            if(pp.isFurnishedPaymentPlan__c) {
                isFurnishedPaymentPlan = true;
            }

            for (UnitPaymentPlanMapping__c m : mappingLst) {
                if (isFurnishedPaymentPlan != m.Payment_Plan__r.isFurnishedPaymentPlan__c) continue;

                String mPlanName = m.Payment_Plan__r.Name != null ? m.Payment_Plan__r.Name.toLowerCase() : ModonEgyptConstants.EMPTY_STRING;
    
                Boolean nameMatch = isCashPaymentPlan ? mPlanName.contains(planKey) : (mPlanName.contains(planKey) && !mPlanName.contains('cash'));
                if (!nameMatch) continue;
    
                if (m.CurrencyIsoCode == ModonEgyptConstants.CURRENCY_ISOCODE_EGP) { paymentObj.totalEGPPrice = m.Base_Price__c != null ? m.Base_Price__c : 0; }
                if (m.CurrencyIsoCode == ModonEgyptConstants.CURRENCY_ISOCODE_USD) { paymentObj.totalUSDPrice = m.Base_Price__c != null ? m.Base_Price__c : 0; }
                if (m.CurrencyIsoCode == ModonEgyptConstants.CURRENCY_ISOCODE_AED) { paymentObj.totalAEDPrice = m.Base_Price__c != null ? m.Base_Price__c : 0; }
            }
    
            paymentLst.add(paymentObj);
            availablePaymentPlan.add(new Map<String, String>{
                ModonEgyptConstants.KEY_LABEL => pp.Name,
                ModonEgyptConstants.KEY_VALUE => pp.Id
            });
        }
    
        UnitPaymentDetails paymentDetailsWrapper = new UnitPaymentDetails();
        if (!paymentLst.isEmpty()) {
            paymentLst[0].isSelected              = true;
            paymentDetailsWrapper.paymentLst      = paymentLst;
            paymentDetailsWrapper.availablePaymentPlans = availablePaymentPlan;
            paymentDetailsWrapper.selectedPayment = availablePaymentPlan[0].get(ModonEgyptConstants.KEY_VALUE);
        }
        udObj.unitPaymentDetailObj = paymentDetailsWrapper;
    
        return udObj;
    }

    // ================== WRAPPER CLASSES ================== //

    public class UnitDetailsWrapper {
        @AuraEnabled public UnitPaymentDetails unitPaymentDetailObj;
        @AuraEnabled public List<UnitPaymentPlanMapping__c> unitPaymentPlanOptions;
    }
    
    public class UnitPaymentDetails {
        @AuraEnabled public String selectedPayment;
        @AuraEnabled public List<Map<String, String>> availablePaymentPlans;
        @AuraEnabled public List<PaymentDetails> paymentLst;
    }
    
    public class PaymentDetails {
    
        @AuraEnabled public PaymentPlan__c paymentObj;
    
        @AuraEnabled public String  paymentPlanId;
        @AuraEnabled public String  paymentPlanName;
        @AuraEnabled public String  paymentPlanCurrency;
        @AuraEnabled public Boolean isSelected;
    
        @AuraEnabled public Decimal paymentPlanDiscountPercent;
        @AuraEnabled public Decimal maintenanceFeePercent;
        @AuraEnabled public Integer numberOfMaintenanceFee;
        @AuraEnabled public Decimal basePriceFromMapping;
        @AuraEnabled public Decimal basePrice8YearPlan;
        @AuraEnabled public Decimal basePrice8YearPlanEGP; //v7.8
        @AuraEnabled public Decimal basePrice8YearPlanAED; //v7.8
        @AuraEnabled public Decimal totalMaintenanceFees;
    
        @AuraEnabled public Decimal totalEGPPrice;
        @AuraEnabled public Decimal totalUSDPrice;
        @AuraEnabled public Decimal totalAEDPrice;
    
        @AuraEnabled public List<PaymentInstallements__c>    paymentInstallment {
            get { return paymentObj != null ? paymentObj.Payment_Installments__r : null; }
        }
        @AuraEnabled public List<PaymentInstallmentWrapper>  paymentInstallmentWrappers;
    
        public PaymentDetails() {
            isSelected    = false;
            totalEGPPrice = 0;
            totalUSDPrice = 0;
            totalAEDPrice = 0;
        }
    }
    
    public class PaymentInstallmentWrapper {
        @AuraEnabled public String  id;
        @AuraEnabled public String  name;
        @AuraEnabled public Integer milestoneNumber;
        @AuraEnabled public String  milestoneDescription;
        @AuraEnabled public Decimal milestonePercent;           
        @AuraEnabled public Decimal brokerPayout;
        @AuraEnabled public Decimal salesAgentPayout;
        @AuraEnabled public Boolean isHandoverPayment;
        @AuraEnabled public Boolean isMaintenanceInstallment;
        @AuraEnabled public Integer noOfMonthsToAddFromLastDate;
        @AuraEnabled public String  currencyCode;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public Date    milestoneDate;
        @AuraEnabled public Decimal maintainancefee;
        @AuraEnabled public String maintainancefeeText;
        @AuraEnabled public String amountText;
    }
}