/**********************************************************************************************************************
 * Name               : Egypt_FlexiblePaymentPlanController
 * Description        : Controller class for the Custom Payment Plan LWC component.
 *                      1. Fetches 8-year unit price from UnitPaymentPlanMapping for a given Unit & Currency.
 *                      2. Calculates PV-anchored standard payment plan values (Anchor PV, installments, interest).
 *                      3. Supports Flexible payment plan calculation by Amount, by Years, or by Installment count.
 *                      4. Uses Present Value discounting at 10.5% annual (2.625% quarterly) rate.
 *                      5. Supports Quarterly, Semi-Annual, and Annual payment frequencies.
 *                      6. Single Downpayment at Q0, installments from Q(1 × qpp) onward.
 *                      7. No rounding is applied anywhere — all values are raw Decimal precision.
 * Usage              : Called from Custom Payment Plan LWC component.
 * Created By         : Shahil Sinha (Horizontal)
 * --------------------------------------------------------------------------------------------------------------------
 * Version       Author                              Date            Comment
 * 1.0           Shahil Sinha (Horizontal)           01-04-2026      Initial Draft
 * 2.0           Shahil Sinha (Horizontal)           02-04-2026      Revised — single method, Standard/Flexible,
 *                                                                    no rounding
 * 2.1           Shahil Sinha (Horizontal)           02-04-2026      Simplified — single Downpayment(Q0),
 *                                                                    removed Reservation/SPA split
 * 3.0           Milin Kapatel (Horizontal)          20-04-2026      Maintenance fees calculation logic implementation, calculation logic update and Code Optimization
 * 4.0           Milin Kapatel (Horizontal)          24-04-2026      calcAnchor and calculateByAmount logic update and Payment_Plan__r.isDefault__c = true in unit payment plan mapping query
 * 4.1           Milin Kapatel (Horizontal)          28-04-2026      calculateByAmount logic update
 * 4.2           Milin Kapatel (Horizontal)          11-05-2026      Reuse SOQL via StandardDownpaymentBenchmark context in calculatePaymentPlan
 * 4.3           Milin Kapatel (Horizontal)          13-05-2026      Opened up Downpayment % range from 1% to 100% and bug fix for Downpayment Amount lower limit validation
 * 4.4           Milin Kapatel (Horizontal)          20-05-2026      Grace period support: Installment 1 date = exactBookingDate + GRACE_PERIOD; subsequent installments add frequency months from Installment 1
 * 4.5           Milin Kapatel (Horizontal)          25-05-2026      Compute flexiblePaymentPlanName (Phase + Frequency + TotalYears + Currency) and return it on PaymentPlanResultWrapper
 * 4.6           Milin Kapatel (Horizontal)          05-06-2026      Adjust last maintenance installment to absorb rounding difference vs total maintenance amount
 * 4.7           Milin Kapatel (Horizontal)          09-06-2026      Remove last installment if it's beyond maximum allowed installment and less or equal to 1
 * 4.8           Milin Kapatel (Horizontal)          15-06-2026      Rounding issue error fix
 **********************************************************************************************************************/
public with sharing class Egypt_FlexiblePaymentPlanController {

    /**
     * Method: getActiveCurrencyIsoCodes
     * Description: Loads active CurrencyType records for payment plan currency picklists.
     * Parameters: none
     * return: List<Map<String,String>>
     */
    @AuraEnabled
    public static List<Map<String,String>> getActiveCurrencyIsoCodes(){
        List<CurrencyType> currencyIsoCodes = [SELECT IsoCode FROM CurrencyType WHERE IsActive = true];
        List<map<String,string>> filtersToReturn = new list<map<String,string>>();
        
        if (!currencyIsoCodes.isEmpty()) {
            for (CurrencyType cic : currencyIsoCodes) {
                Map<String, String> tempMap = new Map<String, String>();
                tempMap.put(ModonEgyptConstants.KEY_LABEL, cic.IsoCode);
                tempMap.put(ModonEgyptConstants.KEY_VALUE, cic.IsoCode);
                filtersToReturn.add(tempMap);
            }
        }
        return filtersToReturn;
    }

    /**
     * Method: getStandardDownpaymentBenchmarksByCurrency
     * Description: For each default 8-year UnitPaymentPlanMapping on the unit, returns the standard-plan down payment
     *              percentage (Downpayment milestone), derived amount on base price, and the ordered standard
     *              installment milestone percentages so the same data can be passed back into calculatePaymentPlan
     *              and re-used (avoiding a duplicate SOQL round-trip per recalculation).
     * Parameters: String unitId
     * return: List<StandardDownpaymentBenchmark>
     */
    @AuraEnabled(cacheable=true)
    public static List<StandardDownpaymentBenchmark> getStandardDownpaymentBenchmarksByCurrency(String unitId) {
        List<StandardDownpaymentBenchmark> results = new List<StandardDownpaymentBenchmark>();

        if (String.isBlank(unitId)) {
            return results;
        }

        List<UnitPaymentPlanMapping__c> mappings = [
            SELECT Base_Price__c, CurrencyIsoCode, Payment_Plan__c
            FROM   UnitPaymentPlanMapping__c
            WHERE  Unit__c = :unitId
              AND  Payment_Plan__r.Name LIKE :ModonEgyptConstants.LIKE_8_YEAR
              AND  Payment_Plan__r.isDefault__c = true
        ];

        if (mappings.isEmpty()) {
            return results;
        }

        Set<Id> planIds = new Set<Id>();
        for (UnitPaymentPlanMapping__c mapping : mappings) {
            if (mapping.Payment_Plan__c != null) {
                planIds.add(mapping.Payment_Plan__c);
            }
        }

        if (planIds.isEmpty()) {
            return results;
        }

        List<PaymentInstallements__c> allInst = [
            SELECT PaymentInstallment__c, Milestone_Egypt_Percent__c, MilestoneNumber__c, MilestoneDescription__c
            FROM   PaymentInstallements__c
            WHERE  PaymentInstallment__c IN :planIds
            ORDER BY PaymentInstallment__c, MilestoneNumber__c ASC
        ];

        Map<Id, List<PaymentInstallements__c>> installmentsByPlan = new Map<Id, List<PaymentInstallements__c>>();
        for (PaymentInstallements__c pi : allInst) {
            if (!installmentsByPlan.containsKey(pi.PaymentInstallment__c)) {
                installmentsByPlan.put(pi.PaymentInstallment__c, new List<PaymentInstallements__c>());
            }
            installmentsByPlan.get(pi.PaymentInstallment__c).add(pi);
        }

        for (UnitPaymentPlanMapping__c mapping : mappings) {
            if (mapping.Base_Price__c == null || String.isBlank(mapping.CurrencyIsoCode) || mapping.Payment_Plan__c == null) {
                continue;
            }

            List<PaymentInstallements__c> stdInst = installmentsByPlan.get(mapping.Payment_Plan__c);
            if (stdInst == null || stdInst.isEmpty()) {
                continue;
            }

            Decimal standardDownpaymentPct = 0;
            List<Decimal> milestonePercentages = new List<Decimal>();
            for (PaymentInstallements__c inst : stdInst) {
                milestonePercentages.add(inst.Milestone_Egypt_Percent__c);
                if (standardDownpaymentPct == 0 && inst.MilestoneDescription__c == ModonEgyptConstants.PP_DOWNPAYMENT_LABEL) {
                    standardDownpaymentPct = inst.Milestone_Egypt_Percent__c != null ? inst.Milestone_Egypt_Percent__c : 0;
                }
            }

            StandardDownpaymentBenchmark benchmark = new StandardDownpaymentBenchmark();
            benchmark.currencyIsoCode              = mapping.CurrencyIsoCode;
            benchmark.basePrice                    = mapping.Base_Price__c;
            benchmark.standardDownpaymentPercent   = standardDownpaymentPct;
            benchmark.standardDownpaymentAmount    = mapping.Base_Price__c * (standardDownpaymentPct / 100);
            benchmark.standardMilestonePercentages = milestonePercentages;

            results.add(benchmark);
        }

        return results;
    }

    //v4.0
    /**
     * Method: calculatePaymentPlan
     * Description: Entry point for flexible payment plan: loads 8-year price, builds line items and totals.
     * Parameters: String unitId, String planType, String currencyIsoCode, String mode, String frequency, Decimal downpaymentPct, Decimal modeValue, Date exactBookingDate, Integer noOfMaintenanceYears, Decimal maintenancePercentage
     * return: PaymentPlanResultWrapper
     */
    @AuraEnabled
    public static PaymentPlanResultWrapper calculatePaymentPlan(
        String  unitId,
        String  planType,
        String  currencyIsoCode,
        String  mode,
        String  frequency,
        Decimal downpaymentPct,
        String  downpaymentMode,
        Decimal modeValue,
        Date    exactBookingDate,
        Integer noOfMaintenanceYears,
        Decimal maintenancePercentage,
        Decimal downpaymentAmount,
        Integer maintenanceStartingInstallmentNumber,
        Integer totalMaintenanceInstallmentCount,
        StandardDownpaymentBenchmark standardPlanContext
    ) {

        if (String.isBlank(frequency))                       { frequency = ModonEgyptConstants.FREQ_QUARTERLY; }
        if (downpaymentPct == null || downpaymentPct <= 0)   { downpaymentPct = 10; }
        if (String.isBlank(planType))                        { planType = ModonEgyptConstants.PLAN_STANDARD; }
        if (exactBookingDate == null)                        { exactBookingDate = Date.today(); }

        // v4.5 — Fetch the unit's phase name once; used later for flexiblePaymentPlanName
        String phaseName = '';
        if (String.isNotBlank(unitId)) {
            List<Unit__c> unitRows = [SELECT Phase__r.Name FROM Unit__c WHERE Id = :unitId LIMIT 1];
            if (!unitRows.isEmpty() && unitRows[0].Phase__r != null && unitRows[0].Phase__r.Name != null) {
                phaseName = unitRows[0].Phase__r.Name;
            }
        }

        if (!ModonEgyptConstants.FREQUENCY_MAP.containsKey(frequency)) {
            throw new AuraHandledException(
                ModonEgyptConstants.PP_ERR_INVALID_FREQUENCY.replace('{0}', frequency != null ? frequency : '')
            );
        }

        Integer maxMaintenanceStartingInstallment = ModonEgyptConstants.FREQUENCY_MAP.containsKey(frequency)
            ? ModonEgyptConstants.FREQUENCY_MAP.get(frequency) * 8
            : getInstallmentCount(STANDARD_YEARS, frequency);

        if (maintenanceStartingInstallmentNumber == null
                || maintenanceStartingInstallmentNumber < 1
                || maintenanceStartingInstallmentNumber > maxMaintenanceStartingInstallment) {
            throw new AuraHandledException(
                ModonEgyptConstants.PP_ERR_INVALID_MAINT_START.replace(
                    '{0}', String.valueOf(maxMaintenanceStartingInstallment)
                )
            );
        }

        Integer maxMaintenanceInstallmentCount = maxMaintenanceStartingInstallment - maintenanceStartingInstallmentNumber + 1;
        if (totalMaintenanceInstallmentCount == null
                || totalMaintenanceInstallmentCount < 1
                || totalMaintenanceInstallmentCount > maxMaintenanceInstallmentCount) {
            throw new AuraHandledException(
                ModonEgyptConstants.PP_ERR_INVALID_MAINT_COUNT.replace(
                    '{0}', String.valueOf(maxMaintenanceInstallmentCount)
                )
            );
        }

        Decimal unitPrice;
        AnchorResult anchor;
        Decimal standardDownpaymentPct;

        Boolean hasReusableContext = standardPlanContext != null
            && standardPlanContext.basePrice != null
            && standardPlanContext.standardMilestonePercentages != null
            && !standardPlanContext.standardMilestonePercentages.isEmpty()
            && currencyIsoCode != null
            && currencyIsoCode.equalsIgnoreCase(standardPlanContext.currencyIsoCode);

        if (hasReusableContext) {
            unitPrice = standardPlanContext.basePrice;
            anchor    = calcAnchorFromPercents(unitPrice, standardPlanContext.standardMilestonePercentages);
            standardDownpaymentPct = standardPlanContext.standardDownpaymentPercent != null
                ? standardPlanContext.standardDownpaymentPercent
                : 0;
        } else {
            //v4.0
            List<UnitPaymentPlanMapping__c> mappings = [
                SELECT Id, Base_Price__c, Unit__c, Payment_Plan__c,
                       Payment_Plan__r.Name, CurrencyIsoCode
                FROM   UnitPaymentPlanMapping__c
                WHERE  Unit__c         = :unitId
                  AND  CurrencyIsoCode = :currencyIsoCode
                  AND  Payment_Plan__r.Name LIKE :ModonEgyptConstants.LIKE_8_YEAR
                  AND  Payment_Plan__r.isDefault__c = true
                LIMIT 1
            ];

            if (mappings.isEmpty() || mappings[0].Base_Price__c == null) {
                throw new AuraHandledException(
                    ModonEgyptConstants.PP_ERR_NO_8YEAR_MAPPING.replace(
                        '{0}', currencyIsoCode != null ? currencyIsoCode : ''
                    )
                );
            }

            Id standardPaymentPlanId = mappings[0].Payment_Plan__c;

            List<PaymentInstallements__c> standardInstallments = [
                SELECT Id, Milestone_Egypt_Percent__c, MilestoneNumber__c, MilestoneDescription__c
                FROM   PaymentInstallements__c
                WHERE  PaymentInstallment__c = :standardPaymentPlanId
                ORDER BY MilestoneNumber__c ASC
            ];

            if (standardInstallments.isEmpty()) {
                throw new AuraHandledException(
                    ModonEgyptConstants.PP_ERR_NO_8YEAR_MAPPING.replace(
                        '{0}', currencyIsoCode != null ? currencyIsoCode : ''
                    )
                );
            }

            unitPrice = mappings[0].Base_Price__c;
            anchor    = calcAnchor(unitPrice, standardInstallments);

            standardDownpaymentPct = 0;
            for (PaymentInstallements__c inst : standardInstallments) {
                if (inst.MilestoneDescription__c == ModonEgyptConstants.PP_DOWNPAYMENT_LABEL) {
                    standardDownpaymentPct = inst.Milestone_Egypt_Percent__c != null ? inst.Milestone_Egypt_Percent__c : 0;
                    break;
                }
            }
        }

        Integer qpp = getQuartersPerPayment(frequency);

        Decimal totalMaintenanceAmount = unitPrice * (maintenancePercentage / 100);
        Decimal maintenancePerPart     = totalMaintenanceAmount / totalMaintenanceInstallmentCount;

        List<PaymentLineItem> lineItems;

        if (planType == ModonEgyptConstants.PLAN_FLEXIBLE) {
            if (String.isBlank(mode)) {
                throw new AuraHandledException(
                    ModonEgyptConstants.PP_ERR_MODE_REQUIRED
                );
            }

            if (downpaymentMode == ModonEgyptConstants.DOWN_PAYMENT_MODE_AMOUNT) {
                /* Commented as requested by @Anshul for testing of Change payment plan
                Decimal minDownpaymentAmount = unitPrice * (standardDownpaymentPct / 100);
                //v4.7
                if (downpaymentAmount == null || downpaymentAmount < (minDownpaymentAmount).setScale(2, System.RoundingMode.HALF_UP)) {
                    throw new AuraHandledException(
                        ModonEgyptConstants.PP_ERR_DOWNPAYMENT_AMOUNT_BELOW_MIN.replace(
                            '{0}', (minDownpaymentAmount).setScale(2, System.RoundingMode.HALF_UP).toPlainString()
                        )
                    );
                } else if (downpaymentAmount > anchor.anchorPV) {
                    throw new AuraHandledException(
                        ModonEgyptConstants.PP_ERR_DOWNPAYMENT_AMOUNT_ABOVE_MAX.replace(
                            '{0}', anchor.anchorPV.setScale(2, System.RoundingMode.HALF_UP).toPlainString()
                        )
                    );
                }
                */
            } else {
                if (downpaymentPct < 1) {
                    throw new AuraHandledException(
                        ModonEgyptConstants.PP_ERR_DOWNPAYMENT_PCT_BELOW_MIN.replace(
                            '{0}', String.valueOf(1)
                        )
                    );
                } else if (downpaymentPct > 100) {
                    throw new AuraHandledException(
                        ModonEgyptConstants.PP_ERR_DOWNPAYMENT_PCT_ABOVE_MAX.replace('{0}', '100')
                    );
                }
            }

            if (mode == ModonEgyptConstants.MODE_BY_AMOUNT) {
                if (modeValue == null || modeValue <= 0) {
                    throw new AuraHandledException(ModonEgyptConstants.PP_ERR_INSTALLMENT_AMOUNT_GT_ZERO);
                }
                CalculateByAmountInput amountInput = new CalculateByAmountInput();
                amountInput.anchor             = anchor;
                amountInput.downpaymentPct     = downpaymentPct;
                amountInput.downpaymentMode    = downpaymentMode;
                amountInput.downpaymentAmount  = downpaymentAmount;
                amountInput.qpp                = qpp;
                amountInput.frequency          = frequency;
                amountInput.instAmt            = modeValue;
                amountInput.exactBookingDate   = exactBookingDate;
                amountInput.currencyIsoCode    = currencyIsoCode;
                lineItems = calculateByAmount(amountInput);

            } else if (mode == ModonEgyptConstants.MODE_BY_YEARS) {
                Integer years = (modeValue != null && modeValue > 0) ? modeValue.intValue() : STANDARD_YEARS;
                Boolean isGreaterYears = years > STANDARD_YEARS;
                Integer count = getInstallmentCount(years, frequency);
                if(isGreaterYears) {
                    throw new AuraHandledException(
                        ModonEgyptConstants.PP_ERR_YEARS_CAP.replace('{0}', String.valueOf(STANDARD_YEARS))
                    );
                }
                else if (count <= 0) {
                    throw new AuraHandledException(
                        ModonEgyptConstants.PP_ERR_COUNT_ZERO
                    );
                }
                CalculateByDurationInput durationInput = new CalculateByDurationInput();
                durationInput.anchor             = anchor;
                durationInput.downpaymentPct     = downpaymentPct;
                durationInput.downpaymentMode    = downpaymentMode;
                durationInput.downpaymentAmount  = downpaymentAmount;
                durationInput.qpp                = qpp;
                durationInput.frequency          = frequency;
                durationInput.count              = count;
                durationInput.exactBookingDate   = exactBookingDate;
                durationInput.currencyIsoCode    = currencyIsoCode;
                lineItems = calculateByDuration(durationInput);
                enforcePvLimit(lineItems, anchor.anchorPV, true);

            } else if (mode == ModonEgyptConstants.MODE_BY_INSTALLMENTS) {
                Integer count = (modeValue != null && modeValue > 0)
                    ? modeValue.intValue()
                    : getInstallmentCount(STANDARD_YEARS, frequency);
                Integer maxInstallmentsForStdPlanYears = getInstallmentCount(STANDARD_YEARS, frequency);
                if (count > maxInstallmentsForStdPlanYears) {
                    String capSuffix = ModonEgyptConstants.PP_ERR_INSTALLMENT_COUNT_CAP_SUFFIX_BY_FREQUENCY.get(frequency);
                    if (String.isBlank(capSuffix)) {
                        capSuffix = ' for the selected payment plan';
                    }
                    throw new AuraHandledException(
                        ModonEgyptConstants.PP_ERR_INSTALLMENT_COUNT_CAP
                            .replace('{0}', String.valueOf(maxInstallmentsForStdPlanYears))
                    );
                }
                else if (count <= 0) {
                    throw new AuraHandledException(ModonEgyptConstants.PP_ERR_INSTALLMENT_MIN);
                }
                CalculateByDurationInput durationInput2 = new CalculateByDurationInput();
                durationInput2.anchor             = anchor;
                durationInput2.downpaymentPct     = downpaymentPct;
                durationInput2.downpaymentMode    = downpaymentMode;
                durationInput2.downpaymentAmount  = downpaymentAmount;
                durationInput2.qpp                = qpp;
                durationInput2.frequency          = frequency;
                durationInput2.count              = count;
                durationInput2.exactBookingDate   = exactBookingDate;
                durationInput2.currencyIsoCode    = currencyIsoCode;
                lineItems = calculateByDuration(durationInput2);
                enforcePvLimit(lineItems, anchor.anchorPV, true);

            } else {
                throw new AuraHandledException(
                    ModonEgyptConstants.PP_ERR_INVALID_MODE.replace('{0}', mode != null ? mode : '')
                );
            }
        } else {
            throw new AuraHandledException(
                ModonEgyptConstants.PP_ERR_INVALID_PLAN_TYPE.replace('{0}', planType != null ? planType : '')
            );
        }

        lineItems = applyMaintenanceInstallments(
            lineItems,
            frequency,
            qpp,
            exactBookingDate,
            currencyIsoCode,
            maintenancePerPart,
            totalMaintenanceAmount,
            maintenanceStartingInstallmentNumber,
            totalMaintenanceInstallmentCount
        );

        Decimal totalAmount   = 0;
        Decimal totalPVAmount = 0;
        Decimal totalInterest = 0;

        for (PaymentLineItem item : lineItems) {
            totalAmount   += item.amount;
            totalPVAmount += item.pvAmount;
            totalInterest += item.interest;
        }

        for (PaymentLineItem item : lineItems) {
            item.milestoneEgyptPercent = (totalAmount > 0) ? ((item.amount / totalAmount) * 100).setScale(6, System.RoundingMode.HALF_UP) : 0;
            item.milestoneEgyptPercentText = item.milestoneEgyptPercent + '%';
        }

        if(totalPVAmount < anchor.anchorPV - PV_TOLERANCE) {
            throw new AuraHandledException(
                ModonEgyptConstants.PP_ERR_PV_TOTAL_TOO_LOW.replace(
                    '{0}', anchor.anchorPV.setScale(2, System.RoundingMode.HALF_UP).toPlainString()
                )
            );
        } else if(totalPVAmount > anchor.anchorPV + PV_TOLERANCE) {
            throw new AuraHandledException(
                ModonEgyptConstants.PP_ERR_PV_TOTAL_TOO_HIGH.replace(
                    '{0}', anchor.anchorPV.setScale(2, System.RoundingMode.HALF_UP).toPlainString()
                )
            );
        }


        PaymentPlanResultWrapper result = new PaymentPlanResultWrapper();
        result.unitPrice              = unitPrice;
        result.totalPayableAmount     = totalAmount;
        result.discount               = unitPrice - totalAmount;
        result.pvValue                = totalPVAmount;
        result.anchorPV               = anchor.anchorPV;
        result.standardYears          = STANDARD_YEARS;
        result.lineItems              = lineItems;
        result.frequency              = frequency;
        result.downpaymentPct         = downpaymentPct;
        result.currencyIsoCode        = currencyIsoCode;
        result.unitBasePrice          = unitPrice;
        result.totalMaintenanceAmount = totalMaintenanceAmount;
        result.flexiblePaymentPlanName = computeFlexiblePlanName(phaseName, frequency, lineItems, currencyIsoCode); // v4.5

        return result;
    }


    // ── PV Calculation Constants (moved to ModonEgyptConstants) ──
    private static final Decimal ANNUAL_RATE    = ModonEgyptConstants.PP_ANNUAL_RATE;
    private static final Decimal QUARTERLY_RATE = ModonEgyptConstants.PP_QUARTERLY_RATE;
    private static final Integer STANDARD_YEARS = ModonEgyptConstants.PP_STANDARD_YEARS;
    private static final Decimal PV_TOLERANCE   = ModonEgyptConstants.PP_PV_TOLERANCE;

    /**
     * Method: getPVFactor
     * Description: Present value discount factor for one period at the frequency-adjusted annual rate.
     * Parameters: String frequency, Integer timePeriod
     * return: Decimal
     */
    private static Decimal getPVFactor(String frequency, Integer timePeriod) {
        if (timePeriod <= 0) {
            return 1;
        }
        Decimal rate = 1 + (ModonEgyptConstants.PP_ANNUAL_RATE / ModonEgyptConstants.FREQUENCY_MAP.get(frequency));
        Decimal timePeriodValue = Decimal.valueOf(timePeriod);
        Double result = Math.pow(rate.doubleValue(), timePeriodValue.doubleValue());
        
        return Decimal.valueOf(1 / result);
    }

    /**
     * Method: getQuartersPerPayment
     * Description: Maps payment frequency to quarter offset per installment (for milestone dates).
     * Parameters: String frequency
     * return: Integer
     */
    private static Integer getQuartersPerPayment(String frequency) {
        Integer freqValue = ModonEgyptConstants.FREQUENCY_MAP.containsKey(frequency) ? ModonEgyptConstants.FREQUENCY_MAP.get(frequency) : 4;
        return 4 / freqValue;
    }

    /**
     * Method: getInstallmentCount
     * Description: Total installments for a duration in years at the given payment frequency.
     * Parameters: Integer years, String frequency
     * return: Integer
     */
    private static Integer getInstallmentCount(Integer years, String frequency) {
        Integer qpp = getQuartersPerPayment(frequency);
        return (years * 4) / qpp;
    }

    //v4.0
    /**
     * Method: calcAnchor
     * Description: Anchor PV derived from the Standard Payment Plan's Payment Installments.
     *              Each installment amount = Base_Price__c * (Milestone_Egypt_Percent__c / 100). The first
     *              record (lowest MilestoneNumber__c) is treated as the downpayment at period 0
     *              (PV factor = 1); subsequent records are discounted at periods 1..N using the
     *              quarterly frequency. stdInstAmt returns the average non-DP installment
     *              amount and stdCount the number of non-DP installments for flexible-mode caps.
     * Parameters: Decimal unitPrice, List<PaymentInstallements__c> stdInstallments
     * return: AnchorResult
     */
    private static AnchorResult calcAnchor(
        Decimal unitPrice, List<PaymentInstallements__c> stdInstallments
    ) {
        List<Decimal> milestonePercentages = new List<Decimal>();
        for (PaymentInstallements__c inst : stdInstallments) {
            milestonePercentages.add(inst.Milestone_Egypt_Percent__c);
        }
        return calcAnchorFromPercents(unitPrice, milestonePercentages);
    }

    /**
     * Method: calcAnchorFromPercents
     * Description: Same anchor PV math as calcAnchor but driven from an ordered list of milestone percentages
     *              (index 0 = downpayment at t0, rest discounted at quarterly periods 1..N).
     * Parameters: Decimal unitPrice, List<Decimal> milestonePercentages
     * return: AnchorResult
     */
    private static AnchorResult calcAnchorFromPercents(
        Decimal unitPrice, List<Decimal> milestonePercentages
    ) {
        Decimal anchorPV     = 0;
        Decimal totalInstAmt = 0;
        Integer nonDpCount   = 0;

        for (Integer i = 0; i < milestonePercentages.size(); i++) {
            Decimal milestonePct = milestonePercentages[i] != null ? milestonePercentages[i] : 0;
            Decimal instAmt = unitPrice * (milestonePct / 100);

            if (i == 0) {
                anchorPV += instAmt;
            } else {
                anchorPV     += instAmt * getPVFactor(ModonEgyptConstants.FREQ_QUARTERLY, i);
                totalInstAmt += instAmt;
                nonDpCount++;
            }
        }

        Decimal stdInstAmt = nonDpCount > 0 ? totalInstAmt / nonDpCount : 0;

        AnchorResult r = new AnchorResult();
        r.anchorPV     = anchorPV;
        r.unitPrice    = unitPrice;
        r.stdInstAmt   = stdInstAmt;
        r.stdCount     = nonDpCount;
        return r;
    }
    

    /**
     * Method: calculateByDuration
     * Description: Equal installments for a fixed count; DP as share of total payable
     * Parameters: CalculateByDurationInput input
     * return: List<PaymentLineItem>
     */
    private static List<PaymentLineItem> calculateByDuration(CalculateByDurationInput input) {
        List<PaymentLineItem> items = new List<PaymentLineItem>();

        AnchorResult anchor = input.anchor;
        Integer qpp         = input.qpp;
        Integer count       = input.count;

        Decimal pvFactorSum = 0;
        for (Integer i = 1; i <= count; i++) {
            pvFactorSum += getPVFactor(input.frequency, i);
        }

        Boolean isDownpaymentAmountMode = input.downpaymentMode == ModonEgyptConstants.DOWN_PAYMENT_MODE_AMOUNT;

        Decimal instAmt;
        Decimal downpaymentAmt;

        if (isDownpaymentAmountMode) {
            Decimal downpaymentAmount = input.downpaymentAmount;

            if (downpaymentAmount == null || downpaymentAmount <= 0) {
                throw new AuraHandledException(ModonEgyptConstants.PP_ERR_INSTALLMENT_AMOUNT_GT_ZERO);
            }

            if (downpaymentAmount >= anchor.anchorPV) {
                items.add(createLineItem(ModonEgyptConstants.PP_DOWNPAYMENT_LABEL, 0, anchor.anchorPV, 0, input.frequency, ModonEgyptConstants.PP_STATUS_UNCHANGED, input.exactBookingDate, input.currencyIsoCode));
                return items;
            }

            Decimal availablePVAmount = anchor.anchorPV - downpaymentAmount;
            instAmt        = availablePVAmount / pvFactorSum;
            downpaymentAmt = downpaymentAmount;
        } else {
            Decimal dpFraction = input.downpaymentPct / 100;

            if (dpFraction >= 1) {
                items.add(createLineItem(ModonEgyptConstants.PP_DOWNPAYMENT_LABEL, 0, anchor.anchorPV, 0, input.frequency, ModonEgyptConstants.PP_STATUS_UNCHANGED, input.exactBookingDate, input.currencyIsoCode));
                return items;
            }

            Decimal multiplier = (count * dpFraction) / (1 - dpFraction);
            instAmt        = anchor.anchorPV / (multiplier + pvFactorSum);
            downpaymentAmt = multiplier * instAmt;
        }

        items.add(createLineItem(ModonEgyptConstants.PP_DOWNPAYMENT_LABEL, 0, downpaymentAmt, 0, input.frequency, ModonEgyptConstants.PP_STATUS_UNCHANGED, input.exactBookingDate, input.currencyIsoCode));

        for (Integer i = 1; i <= count; i++) {
            Integer quarter = i * qpp;
            items.add(createLineItem(ModonEgyptConstants.PP_INSTALLMENT_PREFIX + i, i, instAmt, quarter, input.frequency, ModonEgyptConstants.PP_STATUS_UNCHANGED, input.exactBookingDate, input.currencyIsoCode));
        }

        return items;
    }

    //v4.0
    /**
     * Method: calculateByAmount
     * Description: Fixed user installment amount; derives full count, partial tail and exact DP vs anchor PV.
     * Parameters: CalculateByAmountInput input
     * return: List<PaymentLineItem>
     */
    private static List<PaymentLineItem> calculateByAmount(CalculateByAmountInput input) {
        List<PaymentLineItem> items = new List<PaymentLineItem>();

        AnchorResult anchor = input.anchor;
        Integer qpp         = input.qpp;
        Decimal instAmt     = input.instAmt;

        Decimal rate                   = ModonEgyptConstants.PP_ANNUAL_RATE / ModonEgyptConstants.FREQUENCY_MAP.get(input.frequency);
        Integer maxAllowedInstallments = getInstallmentCount(ModonEgyptConstants.PP_STANDARD_YEARS, input.frequency);

        Decimal sumPVFactorMax = 0;
        for (Integer i = 1; i <= maxAllowedInstallments; i++) {
            sumPVFactorMax += getPVFactor(input.frequency, i);
        }

        Boolean isDownpaymentAmountMode = input.downpaymentMode == ModonEgyptConstants.DOWN_PAYMENT_MODE_AMOUNT;

        Integer finalN = 0;
        Decimal sumPVFactorN = 0;
        Decimal partialPVFactor = 0;
        Decimal partialInstallmentAmount = 0;
        Decimal exactDownpayment;

        if (isDownpaymentAmountMode) {
            Decimal downpaymentAmount = input.downpaymentAmount;

            if (downpaymentAmount == null || downpaymentAmount <= 0) {
                throw new AuraHandledException(ModonEgyptConstants.PP_ERR_INSTALLMENT_AMOUNT_GT_ZERO);
            }

            if (downpaymentAmount >= anchor.anchorPV) {
                items.add(createLineItem(ModonEgyptConstants.PP_DOWNPAYMENT_LABEL, 0, anchor.anchorPV, 0, input.frequency, ModonEgyptConstants.PP_STATUS_UNCHANGED, input.exactBookingDate, input.currencyIsoCode));
                return items;
            }

            Decimal minAllowedAmount = (anchor.anchorPV - downpaymentAmount) / sumPVFactorMax;
            Decimal maxAllowedAmount = (anchor.anchorPV - downpaymentAmount) / (1 / (1 + rate));

            for (Integer i = 1; i <= maxAllowedInstallments; i++) {
                partialPVFactor = getPVFactor(input.frequency, i);
                sumPVFactorN += partialPVFactor;
                Decimal partialInstallmentAmountI = (anchor.anchorPV - downpaymentAmount - (instAmt * sumPVFactorN)) / getPVFactor(input.frequency, i + 1);
                if (partialInstallmentAmountI > ModonEgyptConstants.PP_AMOUNT_TOLERANCE && partialInstallmentAmountI <= instAmt + ModonEgyptConstants.PP_AMOUNT_TOLERANCE) {
                    finalN = i;
                    partialInstallmentAmount = partialInstallmentAmountI;
                    break;
                }
            }

            exactDownpayment = downpaymentAmount;
            //v4.7
            if (exactDownpayment < anchor.anchorPV - ModonEgyptConstants.PP_AMOUNT_TOLERANCE) {
                if (instAmt < minAllowedAmount.setScale(2, System.RoundingMode.HALF_UP)) {
                    throw new AuraHandledException(
                        ModonEgyptConstants.PP_ERR_INSTALLMENT_LOWER_LIMIT.replace(
                            '{0}', (minAllowedAmount).setScale(2, System.RoundingMode.HALF_UP).toPlainString()
                        )
                    );
                } else if (instAmt > maxAllowedAmount) {
                    throw new AuraHandledException(
                        ModonEgyptConstants.PP_ERR_INSTALLMENT_UPPER_LIMIT.replace(
                            '{0}', (maxAllowedAmount.setScale(2, System.RoundingMode.HALF_UP)).toPlainString()
                        )
                    );
                } else if (finalN == 0) {
                    throw new AuraHandledException(ModonEgyptConstants.PP_ERR_INSTALLMENT_AMOUNT_GT_ZERO);
                }
            }

        } else {
            Decimal dpFraction = input.downpaymentPct / 100;

            if (dpFraction >= 1) {
                items.add(createLineItem(ModonEgyptConstants.PP_DOWNPAYMENT_LABEL, 0, anchor.anchorPV, 0, input.frequency, ModonEgyptConstants.PP_STATUS_UNCHANGED, input.exactBookingDate, input.currencyIsoCode));
                return items;
            }

            Decimal k = dpFraction / (1 - dpFraction);

            Decimal minAllowedAmount = anchor.anchorPV / ((k * maxAllowedInstallments) + sumPVFactorMax);
            Decimal maxAllowedAmount = anchor.anchorPV / (k + (1 / (1 + rate)));

            for (Integer i = 1; i <= maxAllowedInstallments; i++) {
                partialPVFactor = getPVFactor(input.frequency, i);
                sumPVFactorN += partialPVFactor;
                Decimal partialInstallmentAmountI = ( anchor.anchorPV - (k * i * instAmt) - (instAmt * sumPVFactorN) ) / (k + (1 / Math.pow(Double.valueOf(1 + rate), Double.valueOf( i + 1 ))));
                if (partialInstallmentAmountI > ModonEgyptConstants.PP_AMOUNT_TOLERANCE && partialInstallmentAmountI <= instAmt + ModonEgyptConstants.PP_AMOUNT_TOLERANCE) {
                    finalN = i;
                    partialInstallmentAmount = partialInstallmentAmountI;
                    break;
                }
            }

            exactDownpayment = k * ((finalN * instAmt) + partialInstallmentAmount);
            //v4.7
            if (exactDownpayment < anchor.anchorPV - ModonEgyptConstants.PP_AMOUNT_TOLERANCE) {
                if (instAmt < minAllowedAmount) {
                    throw new AuraHandledException(
                        ModonEgyptConstants.PP_ERR_INSTALLMENT_LOWER_LIMIT.replace(
                            '{0}', minAllowedAmount.setScale(2, System.RoundingMode.HALF_UP).toPlainString()
                        )
                    );
                } else if (instAmt > maxAllowedAmount) {
                    throw new AuraHandledException(
                        ModonEgyptConstants.PP_ERR_INSTALLMENT_UPPER_LIMIT.replace(
                            '{0}', (maxAllowedAmount.setScale(2, System.RoundingMode.HALF_UP)).toPlainString()
                        )
                    );
                } else if (finalN == 0) {
                    throw new AuraHandledException(ModonEgyptConstants.PP_ERR_INSTALLMENT_AMOUNT_GT_ZERO);
                }
            }
        }

        items.add(createLineItem(
            ModonEgyptConstants.PP_DOWNPAYMENT_LABEL, 0, exactDownpayment, 0,
            input.frequency, ModonEgyptConstants.PP_STATUS_UNCHANGED, input.exactBookingDate,
            input.currencyIsoCode
        ));

        for (Integer i = 1; i <= finalN; i++) {
            Integer quarter = i * qpp;
            items.add(createLineItem(
                ModonEgyptConstants.PP_INSTALLMENT_PREFIX + i, i, instAmt, quarter,
                input.frequency, ModonEgyptConstants.PP_STATUS_UNCHANGED, input.exactBookingDate,
                input.currencyIsoCode
            ));
        }

        items.add(createLineItem(
            ModonEgyptConstants.PP_INSTALLMENT_PREFIX + (finalN + 1), finalN + 1,
            partialInstallmentAmount, (finalN + 1) * qpp, input.frequency,
            ModonEgyptConstants.PP_STATUS_ADJUSTED_PARTIAL, input.exactBookingDate,
            input.currencyIsoCode
        ));

        //v4.7
        if(items.size() > maxAllowedInstallments + 1 && partialInstallmentAmount > 0 && partialInstallmentAmount <= 1) {
            items.remove(items.size() - 1);
        }

        return items;
    }

    /**
     * Method: enforcePvLimit
     * Description: Rebalances last installment so total PV matches anchor when within tolerance rules.
     * Parameters: List<PaymentLineItem> items, Decimal anchorPV, Boolean enforceExactMatch
     * return: void
     */
    private static void enforcePvLimit(
        List<PaymentLineItem> items, Decimal anchorPV, Boolean enforceExactMatch
    ) {
        if (items == null || items.isEmpty()) {
            return;
        }

        Decimal totalPV = 0;
        for (PaymentLineItem item : items) {
            totalPV += item.pvAmount;
        }

        Decimal deltaPV = anchorPV - totalPV;
        Boolean needsReduction = totalPV > (anchorPV + PV_TOLERANCE);
        Boolean needsRebalance = enforceExactMatch && (deltaPV.abs() > PV_TOLERANCE);
        if (!needsReduction && !needsRebalance) {
            return;
        }

        Integer idx = items.size() - 1;
        while (idx >= 0 && items[idx].milestoneNumber == 1) {
            idx--;
        }
        if (idx < 0) {
            return;
        }

        PaymentLineItem lastItem = items[idx];
        Decimal pvFactor = lastItem.pvFactor;
        if (pvFactor <= 0) {
            return;
        }

        Decimal adjustmentAmount = deltaPV / pvFactor;
        Decimal newAmount = lastItem.amount + adjustmentAmount;
        if (newAmount < 0) {
            newAmount = 0;
        }

        lastItem.amount = newAmount;
        lastItem.pvAmount = newAmount * pvFactor;
        lastItem.interest = newAmount * (1 - pvFactor);
        if (String.isBlank(lastItem.status) || lastItem.status == ModonEgyptConstants.PP_STATUS_UNCHANGED) {
            lastItem.status = ModonEgyptConstants.PP_STATUS_ADJUSTED;
        } else {
            lastItem.status = lastItem.status + ModonEgyptConstants.PP_STATUS_PV_ADJUSTED_SUFFIX;
        }
    }

    //v4.5
    /**
     * Method: computeFlexiblePlanName
     * Description: Builds the display name for a generated Flexible Payment Plan.
     *              Format: Flexible_<PhaseName>_<Frequency>_<TotalYears> Years(<CurrencyIsoCode>)
     *              TotalYears = months between the first and last line item milestone dates divided by 12.
     *              If the result is a whole number it is rendered without decimals; otherwise rounded to 2 d.p.
     * Parameters: String phaseName, String frequency, List<PaymentLineItem> lineItems, String currencyIsoCode
     * return: String
     */
    private static String computeFlexiblePlanName(
        String phaseName, String frequency, List<PaymentLineItem> lineItems, String currencyIsoCode
    ) {
        String phase    = String.isNotBlank(phaseName)     ? phaseName     : '';
        String currencyCode = String.isNotBlank(currencyIsoCode) ? currencyIsoCode : '';
        String freq     = String.isNotBlank(frequency)     ? frequency     : '';

        Integer totalMonths = 0;
        if (lineItems != null && lineItems.size() > 1) {
            Date firstDate = lineItems[0].milestoneDate;
            Date lastDate  = lineItems[lineItems.size() - 1].milestoneDate;
            if (firstDate != null && lastDate != null) {
                totalMonths = firstDate.monthsBetween(lastDate);
            }
        }

        String totalYearsStr;
        if (totalMonths == 0) {
            totalYearsStr = '0';
        } else if (Math.mod(totalMonths, 12) == 0) {
            totalYearsStr = String.valueOf(totalMonths / 12);
        } else {
            totalYearsStr = (Decimal.valueOf(totalMonths) / 12).setScale(2, System.RoundingMode.HALF_UP).toPlainString();
        }

        return 'Flexible_' + phase + '_' + freq + '_' + totalYearsStr + ' Years(' + currencyCode + ')';
    }

    //v4.4
    /**
     * Method: computeMilestoneDate
     * Description: Calculates the milestone date for a given installment number using grace period logic.
     *              Downpayment (lineItemIndex=0) receives exactBookingDate.
     *              Installment 1 (lineItemIndex=1) receives exactBookingDate + GRACE_PERIOD for the frequency.
     *              Installment N (lineItemIndex>=2) receives exactBookingDate + GRACE_PERIOD + (N-1) * freqMonths.
     * Parameters: Integer lineItemIndex, String frequency, Date exactBookingDate
     * return: Date
     */
    private static Date computeMilestoneDate(Integer lineItemIndex, String frequency, Date exactBookingDate) {
        if (exactBookingDate == null) { return null; }
        if (lineItemIndex == 0)     { return exactBookingDate; }

        Integer gracePeriodMonths;
        Integer freqMonths;

        if (frequency == ModonEgyptConstants.FREQ_QUARTERLY) {
            gracePeriodMonths = 3;
            freqMonths        = 3;
        } else if (frequency == ModonEgyptConstants.FREQ_SEMI_ANNUAL) {
            gracePeriodMonths = 4;
            freqMonths        = 6;
        } else {
            gracePeriodMonths = 6;
            freqMonths        = 12;
        }

        return exactBookingDate.addMonths(gracePeriodMonths + (lineItemIndex - 1) * freqMonths);
    }

    /**
     * Method: createLineItem
     * Description: Builds one line item with PV, interest and milestone date. Maintenance fee is set later by applyMaintenanceInstallments().
     * Parameters: String milestoneDescription, Integer lineItemIndex, Decimal amount, Integer quarter, String frequency, String status, Date exactBookingDate, String currencyIsoCode
     * return: PaymentLineItem
     */
    private static PaymentLineItem createLineItem(
        String milestoneDescription, Integer lineItemIndex, Decimal amount, Integer quarter, String frequency, String status, Date exactBookingDate,
        String currencyIsoCode
    ) {
        PaymentLineItem item = new PaymentLineItem();
        item.id                   = String.valueOf(lineItemIndex + 1);
        item.milestoneDescription = milestoneDescription;
        item.milestoneNumber      = lineItemIndex + 1;
        item.amount               = amount.setScale(2, System.RoundingMode.HALF_UP);
        item.quarter              = quarter;
        item.pvFactor             = getPVFactor(frequency, lineItemIndex);
        item.pvAmount             = amount * item.pvFactor;
        item.interest             = amount * (1 - item.pvFactor);
        item.status               = status;
        item.milestoneDate        = computeMilestoneDate(lineItemIndex, frequency, exactBookingDate);
        item.maintainancefee      = 0;
        item.maintainancefeeText  = currencyIsoCode + ' ' + item.maintainancefee.setScale(2, System.RoundingMode.HALF_UP).toPlainString();
        item.amountText           = currencyIsoCode + ' ' + amount.setScale(2, System.RoundingMode.HALF_UP).toPlainString();
        item.pvAmountText         = currencyIsoCode + ' ' + (amount * item.pvFactor).setScale(2, System.RoundingMode.HALF_UP).toPlainString();
        return item;
    }

    /**
     * Method: applyMaintenanceInstallments
     * Description: Returns a new list with maintenance fees applied to the configured installment window and pads zero-amount
     *              installments when the existing list does not cover the maintenance range (start + count - 1).
     * Parameters: List<PaymentLineItem> items, String frequency, Integer qpp, Date exactBookingDate, String currencyIsoCode,
     *             Decimal maintenancePerPart, Decimal totalMaintenanceAmount, Integer maintenanceStartingInstallmentNumber,
     *             Integer totalMaintenanceInstallmentCount
     * return: List<PaymentLineItem>
     */
    private static List<PaymentLineItem> applyMaintenanceInstallments(
        List<PaymentLineItem> items,
        String  frequency,
        Integer qpp,
        Date    exactBookingDate,
        String  currencyIsoCode,
        Decimal maintenancePerPart,
        Decimal totalMaintenanceAmount,
        Integer maintenanceStartingInstallmentNumber,
        Integer totalMaintenanceInstallmentCount
    ) {
        List<PaymentLineItem> result = new List<PaymentLineItem>();
        if (items != null) {
            result.addAll(items);
        }

        Integer highestInstallmentIdx = 0;
        for (PaymentLineItem item : result) {
            Integer installmentIdx = item.milestoneNumber - 1;
            if (installmentIdx > highestInstallmentIdx) {
                highestInstallmentIdx = installmentIdx;
            }
        }

        Integer maintenanceEndInstallmentIdx = maintenanceStartingInstallmentNumber + totalMaintenanceInstallmentCount - 1;

        for (Integer i = highestInstallmentIdx + 1; i <= maintenanceEndInstallmentIdx; i++) {
            Integer quarter = i * qpp;
            result.add(createLineItem(
                ModonEgyptConstants.PP_INSTALLMENT_PREFIX + i, i, 0, quarter,
                frequency, ModonEgyptConstants.PP_STATUS_UNCHANGED, exactBookingDate,
                currencyIsoCode
            ));
        }

        Decimal sumOfAllMaintenanceFees = 0;
        Integer lastMaintenanceIndex = -1;

        for (Integer idx = 0; idx < result.size(); idx++) {
            PaymentLineItem item = result[idx];
            Integer installmentIdx = item.milestoneNumber - 1;
            if (installmentIdx >= maintenanceStartingInstallmentNumber
                    && installmentIdx <= maintenanceEndInstallmentIdx) {
                item.maintainancefee     = maintenancePerPart.setScale(2, System.RoundingMode.HALF_UP);
                item.maintainancefeeText = currencyIsoCode + ' ' + maintenancePerPart.setScale(2, System.RoundingMode.HALF_UP).toPlainString();

                sumOfAllMaintenanceFees += maintenancePerPart.setScale(2, System.RoundingMode.HALF_UP);
                lastMaintenanceIndex = idx;
            }
        }

        // Adjust last maintenance installment to absorb rounding difference
        if (lastMaintenanceIndex >= 0
                && totalMaintenanceAmount > 0
                && sumOfAllMaintenanceFees != totalMaintenanceAmount) {
            Decimal maintenanceDifference = totalMaintenanceAmount - sumOfAllMaintenanceFees;
            result[lastMaintenanceIndex].maintainancefee += maintenanceDifference;
            result[lastMaintenanceIndex].maintainancefeeText =
                currencyIsoCode + ' ' +
                result[lastMaintenanceIndex].maintainancefee.setScale(2, System.RoundingMode.HALF_UP).toPlainString();
        }

        return result;
    }




    private class CalculateByDurationInput {
        AnchorResult anchor;
        Decimal downpaymentPct;
        String  downpaymentMode;
        Decimal downpaymentAmount;
        Integer qpp;
        String  frequency;
        Integer count;
        Date    exactBookingDate;
        String  currencyIsoCode;
    }

    private class CalculateByAmountInput {
        AnchorResult anchor;
        Decimal downpaymentPct;
        String  downpaymentMode;
        Decimal downpaymentAmount;
        Integer qpp;
        String  frequency;
        Decimal instAmt;
        Date    exactBookingDate;
        String  currencyIsoCode;
    }

    private class AnchorResult {
        Decimal anchorPV;
        Decimal unitPrice;
        Decimal stdInstAmt;
        Integer stdCount;
    }


    public class StandardDownpaymentBenchmark {
        @AuraEnabled public String  currencyIsoCode;
        @AuraEnabled public Decimal basePrice;
        @AuraEnabled public Decimal standardDownpaymentPercent;
        @AuraEnabled public Decimal standardDownpaymentAmount;
        @AuraEnabled public List<Decimal> standardMilestonePercentages;
    }

    public class PaymentPlanResultWrapper {
        @AuraEnabled public Decimal unitPrice;
        @AuraEnabled public Decimal totalPayableAmount;
        @AuraEnabled public Decimal discount;
        @AuraEnabled public Decimal pvValue;
        @AuraEnabled public Decimal anchorPV;
        @AuraEnabled public Integer standardYears;
        @AuraEnabled public List<PaymentLineItem> lineItems;
        @AuraEnabled public String  frequency;
        @AuraEnabled public Decimal downpaymentPct;
        @AuraEnabled public String  currencyIsoCode;
        @AuraEnabled public Decimal unitBasePrice;
        @AuraEnabled public Decimal totalMaintenanceAmount;
        @AuraEnabled public String  flexiblePaymentPlanName; // v4.5
    }


    public class PaymentLineItem {
        @AuraEnabled public String  id;
        @AuraEnabled public String  milestoneDescription;
        @AuraEnabled public Integer milestoneNumber;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public Decimal milestoneEgyptPercent;
        @AuraEnabled public String milestoneEgyptPercentText;
        @AuraEnabled public Integer quarter;
        @AuraEnabled public Decimal pvFactor;
        @AuraEnabled public Decimal pvAmount;
        @AuraEnabled public Decimal interest;
        @AuraEnabled public String  status;
        @AuraEnabled public Date milestoneDate;
        @AuraEnabled public Decimal maintainancefee;
        @AuraEnabled public String maintainancefeeText;
        @AuraEnabled public String amountText;
        @AuraEnabled public String pvAmountText;
    }
}