/**********************************************************************************************************************
* Name        : OIC_DPGGetReservationAmount
* Description : Returns the reservation amount payable for a Unit, in the Unit's own currency.
* Usage       : POST/GET /services/apexrest/dpg/getReservationAmount/
* --------------------------------------------------------------------------------------------------------------------
* Version   Author   Date           Comment
* 1.0       -        -              Initial.
* 2.0       Arvind   10 Jul 2026    Response handling delegated to OIC_RestResponse.
* 2.1       Arvind   10 Jul 2026    CurrencyIsoCode read off the Unit and returned with the amount.
* 2.2       MODON    25 Aug 2026    Added @HttpGet and support for reading UnitId from both Query Params and JSON Body.
* 2.3       Jay Patel 18 Sep 2026   MCR-73 — USER_MODE SOQL, createApexLog
***********************************************************************************************************************/
@RestResource(urlMapping='/dpg/getReservationAmount/*')
global with sharing class OIC_DPGGetReservationAmount {

    @HttpGet
    global static void getReservationAmountGet() {
        processRequest();
    }

    @HttpPost
    global static void getReservationAmount() {
        processRequest();
    }

    private static void processRequest() {
        try {
            RestRequest req = RestContext.request;
            String unitId = extractUnitId(req);

            if (String.isBlank(unitId)) {
                OIC_RestResponse.failure(
                    OIC_RestResponse.MISSING_REQUIRED_FIELD, 'UnitId is mandatory.'
                ).send();
                return;
            }

            // An amount without its currency is meaningless, so CurrencyIsoCode travels with it.
            //2.3 MCR-73: Enforce CRUD/FLS via USER_MODE on Unit__c query
            List<Unit__c> units = [
                SELECT Id, Name, TotalPrice__c, CurrencyIsoCode,
                       Phase__c, Phase__r.ReservationAmount__c
                FROM Unit__c
                WHERE Id = :unitId
                WITH USER_MODE
                LIMIT 1
            ];

            if (units.isEmpty()) {
                OIC_RestResponse.failure(
                    OIC_RestResponse.RECORD_NOT_FOUND, 'No Unit found for Id ' + unitId
                ).send();
                return;
            }

            OIC_RestResponse.success(buildPayload(units[0])).send();

        } catch (Exception ex) {
            //2.3 MCR-73: Log unexpected failures via LoggerService.createApexLog
            LoggerService.save(LoggerService.createApexLog(
                ex,
                'DPG Get Reservation Amount API',
                'OIC_DPGGetReservationAmount',
                'processRequest'
            ));
            OIC_RestResponse.fromException(ex).send();
        }
    }

    private static String extractUnitId(RestRequest req) {
        if (req == null) return null;

        // 1. Query Parameters
        if (req.params != null && !req.params.isEmpty()) {
            for (String key : req.params.keySet()) {
                if (key.equalsIgnoreCase('UnitId') || key.equalsIgnoreCase('unit_id') || key.equalsIgnoreCase('id')) {
                    String val = req.params.get(key);
                    if (String.isNotBlank(val)) return val.trim();
                }
            }
        }

        // 2. Request Body JSON
        if (req.requestBody != null && req.requestBody.size() > 0) {
            try {
                String bodyStr = req.requestBody.toString();
                if (String.isNotBlank(bodyStr)) {
                    Map<String, Object> input = (Map<String, Object>) JSON.deserializeUntyped(bodyStr);
                    if (input != null) {
                        for (String key : input.keySet()) {
                            if (key.equalsIgnoreCase('UnitId') || key.equalsIgnoreCase('unit_id') || key.equalsIgnoreCase('id')) {
                                Object valObj = input.get(key);
                                if (valObj != null && String.isNotBlank(String.valueOf(valObj))) {
                                    return String.valueOf(valObj).trim();
                                }
                            }
                        }
                    }
                }
            } catch (Exception e) {
                System.debug(LoggingLevel.WARN, 'extractUnitId JSON parse warning: ' + e.getMessage());
            }
        }

        return null;
    }

    /** Pure-ish helper: all the business logic, no RestContext. Easy to unit test. */
    private static UnitReservation buildPayload(Unit__c unit) {
        Decimal phaseReservationAmount =
            (unit.Phase__c != null) ? unit.Phase__r.ReservationAmount__c : null;

        Decimal reservationAmount = (phaseReservationAmount != null)
            ? phaseReservationAmount
            : firstMilestoneAmount(unit);

        UnitReservation payload   = new UnitReservation();
        payload.UnitId            = unit.Id;
        payload.Name              = unit.Name;
        payload.ReservationAmount = reservationAmount;
        payload.CurrencyIsoCode   = unit.CurrencyIsoCode;
        return payload;
    }

    private static Decimal firstMilestoneAmount(Unit__c unit) {
        //2.3 MCR-73: Enforce CRUD/FLS via USER_MODE on PaymentInstallements__c query
        List<PaymentInstallements__c> installments = [
            SELECT Id, Milestone__c
            FROM PaymentInstallements__c
            WHERE PaymentInstallment__r.Unit__c = :unit.Id
              AND MilestoneNumber__c = 1
            WITH USER_MODE
            LIMIT 1
        ];
        if (installments.isEmpty()) {
            return 0;
        }

        Decimal milestonePercent = (installments[0].Milestone__c != null)
            ? installments[0].Milestone__c : 0;
        Decimal totalPrice = (unit.TotalPrice__c != null) ? unit.TotalPrice__c : 0;

        return (milestonePercent / 100) * totalPrice;
    }

    /** Payload only -- Status/ErrorCode/ErrorMessage now live on OIC_RestResponse. */
    global class UnitReservation {
        public String  UnitId;
        public String  Name;
        public Decimal ReservationAmount;
        public String  CurrencyIsoCode;
    }
}