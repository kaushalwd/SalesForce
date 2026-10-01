/**********************************************************************************************************************
* Name        : OIC_DPGGetVirtualAccount
* Description : Returns the escrow Virtual Account for a Unit, along with the reservation amount payable up-front
*               (50% of the first payment milestone + 75% of the 2% ADM fee).
* Usage       : POST/GET /services/apexrest/dpg/getUnitVirtualAccount/
* --------------------------------------------------------------------------------------------------------------------
* Version   Author   Date           Comment
* 1.0       -        -              Initial.
* 2.0       sanath   10 Jul 2026    Response handling delegated to OIC_RestResponse. Error paths now actually write a
*                                     body. Missing Unit / VirtualAccount return 404 instead of 500. TotalPrice__c
*                                     null-guarded before the ADM calculation. Decimal instead of Double.
* 2.1       -        13 Jul 2026    Reworded all client-facing messages to be clear, high-level and meaningful.
*                                     The "no Virtual Account" path now explains what happened and what to do next.
* 2.2       MODON    25 Aug 2026    Added @HttpGet and resilient multi-channel UnitId extraction.
* 2.3       Jay Patel 18 Sep 2026   MCR-73 — USER_MODE SOQL, createApexLog
***********************************************************************************************************************/
@RestResource(urlMapping='/dpg/getUnitVirtualAccount/*')
global with sharing class OIC_DPGGetVirtualAccount {
    
    private static final Decimal ADM_FEE_PERCENT          = 2;   // ADM fee = 2% of total price
    private static final Decimal ADM_PORTION_PERCENT      = 75;  // 75% of the ADM fee is payable up-front
    private static final Decimal MILESTONE_PORTION_PERCENT = 50; // 50% of milestone 1 is payable up-front
    
    /* ====================================================================================
     *  ERROR CODES
     *  USR-001 / USR-004 / USR-500 already exist in the shared registry.
     * ==================================================================================== */
    static {
        OIC_RestResponse.define('VA-001', 404,
                                'This Unit does not yet have an escrow Virtual Account set up.');
    }
    
    private static final String ERR_NO_VIRTUAL_ACCOUNT = 'VA-001';
    
    /* ====================================================================================
     *  REST ENTRY POINTS
     * ==================================================================================== */
    @HttpGet
    global static void getVirtualAccountGet() {
        processRequest();
    }

    @HttpPost
    global static void getVirtualAccount() {
        processRequest();
    }

    private static void processRequest() {
        try {
            RestRequest req = RestContext.request;
            String unitId = extractUnitId(req);
            
            if (String.isBlank(unitId)) {
                OIC_RestResponse.failure(
                    OIC_RestResponse.MISSING_REQUIRED_FIELD,
                    'A Unit Id is required to look up the escrow Virtual Account. ' +
                    'Please include a valid "UnitId" in the request.'
                ).send();
                return;
            }
            
            //2.3 MCR-73: Enforce CRUD/FLS via USER_MODE on Unit__c query
            List<Unit__c> units = [
                SELECT Id, Name, TotalPrice__c, Phase__c,
                Phase__r.ReservationAmount__c, 
                Phase__r.Project__c, 
                Phase__r.EscrowAccount__r.BankName__c,
                Phase__r.EscrowAccount__r.BeneficiaryName__c,
                Phase__r.EscrowAccount__r.Branch__c,
                Phase__r.EscrowAccount__r.IBANNo__c,
                Phase__r.EscrowAccount__r.SwiftCode__c,
                Phase__r.EscrowAccount__r.AccountNumber__c
                FROM Unit__c
                WHERE Id = :unitId
                WITH USER_MODE
                LIMIT 1
            ];
            
            if (units.isEmpty()) {
                OIC_RestResponse.failure(
                    OIC_RestResponse.RECORD_NOT_FOUND,
                    'We could not find a Unit for the Id provided. ' +
                    'Please check the Unit Id and try again.'
                ).send();
                return;
            }
            Unit__c unit = units[0];
            
            //2.3 MCR-73: Enforce CRUD/FLS via USER_MODE on VirtualAccount__c query
            List<VirtualAccount__c> virtualAccounts = [
                SELECT Id, Name,
                VirtualAccountNumber__c,
                VirtualIBANNumber__c,
                Status__c
                FROM VirtualAccount__c
                WHERE Unit__c = :unitId
                WITH USER_MODE
                LIMIT 1
            ];
            
            if (virtualAccounts.isEmpty()) {
                
                if (unit.Phase__c == null || unit.Phase__r.EscrowAccount__c == null) {
                    OIC_RestResponse.failure(
                        ERR_NO_VIRTUAL_ACCOUNT,
                        'This Unit does not yet have an escrow Virtual Account set up, so reservation ' +
                        'details cannot be provided. '
                    ).send();
                    return;
                }
                
                OIC_RestResponse.success()
                    .put('UnitId',            unit.Id)
                    .put('ReservationAmount', calculateReservationAmount(unit))
                    .put('BankName',          unit.Phase__r.EscrowAccount__r.BankName__c)
                    .put('BeneficiaryName',   unit.Phase__r.EscrowAccount__r.BeneficiaryName__c)
                    .put('Branch',            unit.Phase__r.EscrowAccount__r.Branch__c)
                    .put('IBANNo',            unit.Phase__r.EscrowAccount__r.IBANNo__c)
                    .put('SwiftCode',         unit.Phase__r.EscrowAccount__r.SwiftCode__c)
                    .put('AccountNumber',     unit.Phase__r.EscrowAccount__r.AccountNumber__c)
                    .flat()
                    .send();
                return;
            }
            
            OIC_RestResponse.success()
                .put('UnitId',            unit.Id)
                .put('ReservationAmount', calculateReservationAmount(unit))
                .put('BankName',          unit.Phase__r.EscrowAccount__r.BankName__c)
                .put('BeneficiaryName',   unit.Phase__r.EscrowAccount__r.BeneficiaryName__c)
                .put('Branch',            unit.Phase__r.EscrowAccount__r.Branch__c)
                .put('IBANNo',            virtualAccounts[0].VirtualIBANNumber__c)
                .put('SwiftCode',         unit.Phase__r.EscrowAccount__r.SwiftCode__c)
                .put('AccountNumber',     virtualAccounts[0].VirtualAccountNumber__c)
                .flat()
                .send();
            
        } catch (Exception ex) {
            //2.3 MCR-73: Log unexpected failures via LoggerService.createApexLog
            LoggerService.save(LoggerService.createApexLog(
                ex,
                'DPG Get Virtual Account API',
                'OIC_DPGGetVirtualAccount',
                'processRequest'
            ));
            OIC_RestResponse.fromException(ex).send();
        }
    }

    private static String extractUnitId(RestRequest req) {
        if (req == null) return null;

        // 1. Check URL path (e.g. /dpg/getUnitVirtualAccount/a03...)
        if (String.isNotBlank(req.requestURI)) {
            String lastSegment = req.requestURI.substringAfterLast('/');
            if (String.isNotBlank(lastSegment) && !lastSegment.equalsIgnoreCase('getUnitVirtualAccount') && (lastSegment.startsWithIgnoreCase('a03') || lastSegment.length() == 15 || lastSegment.length() == 18)) {
                return lastSegment.trim();
            }
        }

        // 2. Check Query Parameters
        if (req.params != null && !req.params.isEmpty()) {
            for (String key : req.params.keySet()) {
                String val = req.params.get(key);
                if (String.isNotBlank(val)) {
                    val = val.trim();
                    if (key.equalsIgnoreCase('UnitId') || key.equalsIgnoreCase('unit_id') || key.equalsIgnoreCase('id') || key.equalsIgnoreCase('unit')) {
                        return val;
                    }
                    if (val.startsWithIgnoreCase('a03') && (val.length() == 15 || val.length() == 18)) {
                        return val;
                    }
                }
            }
        }

        // 3. Check Request Body JSON & Regex
        if (req.requestBody != null && req.requestBody.size() > 0) {
            String bodyStr = req.requestBody.toString();
            if (String.isNotBlank(bodyStr)) {
                try {
                    Object parsed = JSON.deserializeUntyped(bodyStr);
                    String found = findValueRecursively(parsed, new Set<String>{
                        'unitid', 'unit_id', 'id', 'unit', 'unitcode'
                    });
                    if (String.isNotBlank(found)) return found;
                } catch (Exception e) {
                    System.debug(LoggingLevel.WARN, 'JSON parse warning in extractUnitId: ' + e.getMessage());
                }

                // Fallback: Regex scan for Unit__c ID (starts with a03)
                Pattern p = Pattern.compile('(?i)\\b(a03[a-zA-Z0-9]{12,15})\\b');
                Matcher m = p.matcher(bodyStr);
                if (m.find()) {
                    return m.group(1);
                }
            }
        }

        return null;
    }

    private static String findValueRecursively(Object jsonObj, Set<String> targetKeys) {
        if (jsonObj == null) return null;
        if (jsonObj instanceof Map<String, Object>) {
            Map<String, Object> m = (Map<String, Object>) jsonObj;
            for (String key : m.keySet()) {
                if (targetKeys.contains(key.toLowerCase())) {
                    Object val = m.get(key);
                    if (val != null && !(val instanceof Map<String, Object>) && !(val instanceof List<Object>)) {
                        String s = String.valueOf(val).trim();
                        if (String.isNotBlank(s)) return s;
                    }
                }
            }
            for (String key : m.keySet()) {
                String found = findValueRecursively(m.get(key), targetKeys);
                if (String.isNotBlank(found)) return found;
            }
        } else if (jsonObj instanceof List<Object>) {
            for (Object item : (List<Object>) jsonObj) {
                String found = findValueRecursively(item, targetKeys);
                if (String.isNotBlank(found)) return found;
            }
        }
        return null;
    }
    
    /* ====================================================================================
     *  BUSINESS LOGIC  -- no RestContext, easy to unit test
     * ==================================================================================== */
    private static Decimal calculateReservationAmount(Unit__c unit) {
        // A reservation amount set on the Phase wins outright.
        Decimal phaseReservationAmount =
            (unit.Phase__c != null) ? unit.Phase__r.ReservationAmount__c : null;
        
        if (phaseReservationAmount != null) {
            return phaseReservationAmount;
        }
        
        if (unit.Phase__c == null || unit.Phase__r.Project__c == null) {
            return 0;
        }
        
        //2.3 MCR-73: Enforce CRUD/FLS via USER_MODE on PaymentPlan__c query
        List<PaymentPlan__c> paymentPlans = [
            SELECT Id FROM PaymentPlan__c
            WHERE Project__c = :unit.Phase__r.Project__c
            WITH USER_MODE
            LIMIT 1
        ];
        if (paymentPlans.isEmpty()) {
            return 0;
        }
        
        //2.3 MCR-73: Enforce CRUD/FLS via USER_MODE on PaymentInstallements__c query
        List<PaymentInstallements__c> installments = [
            SELECT Id, Milestone__c
            FROM PaymentInstallements__c
            WHERE PaymentInstallment__c = :paymentPlans[0].Id
            AND MilestoneNumber__c = 1
            WITH USER_MODE
            LIMIT 1
        ];
        if (installments.isEmpty()) {
            return 0;
        }
        
        // Null-guard BEFORE the arithmetic. v1.0 computed admAmount from a possibly-null
        // TotalPrice__c one line above its own null check, which NPE'd into a 500.
        Decimal totalPrice = (unit.TotalPrice__c != null) ? unit.TotalPrice__c : 0;
        Decimal milestonePercent = (installments[0].Milestone__c != null)
            ? installments[0].Milestone__c : 0;
        
        Decimal milestoneAmount = (milestonePercent / 100) * totalPrice;
        Decimal admAmount       = (totalPrice * ADM_FEE_PERCENT) / 100;
        
        Decimal payableMilestone = (milestoneAmount * MILESTONE_PORTION_PERCENT) / 100;
        Decimal payableAdm       = (admAmount * ADM_PORTION_PERCENT) / 100;
        
        return payableMilestone + payableAdm;
    }
}