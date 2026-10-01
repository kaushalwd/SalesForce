@RestResource(urlMapping='/handoverServiceCharge/*')
global with sharing class HandoverServiceChargeAPI {

    global class HandoverServiceChargeRequest {
        public String unitName;
        public Decimal firstYearServiceCharge;
        public Boolean isServiceChargePaid;
    }

    global class HandoverServiceChargeResponse {
        public Boolean success;
        public String message;
        public String handoverDetailsId;
        public String unitName;
        public Decimal firstYearServiceCharge;
        public Boolean isServiceChargePaid;
    }

    @HttpPatch
    global static HandoverServiceChargeResponse updateHandoverDetails() {

        RestRequest restRequest = RestContext.request;
        RestResponse restResponse = RestContext.response;

        HandoverServiceChargeResponse response =
            new HandoverServiceChargeResponse();

        try {
            // Validate request body
            if (restRequest.requestBody == null ||
                String.isBlank(restRequest.requestBody.toString())) {

                restResponse.statusCode = 400;
                response.success = false;
                response.message = 'Request body is required.';
                return response;
            }

            HandoverServiceChargeRequest requestData =
                (HandoverServiceChargeRequest) JSON.deserialize(
                    restRequest.requestBody.toString(),
                    HandoverServiceChargeRequest.class
                );

            // Validate Unit Name
            if (requestData == null || String.isBlank(requestData.unitName)) {
                restResponse.statusCode = 400;
                response.success = false;
                response.message = 'Unit Name is required.';
                return response;
            }

            // At least one update value must be provided
            if (requestData.firstYearServiceCharge == null &&
                requestData.isServiceChargePaid == null) {

                restResponse.statusCode = 400;
                response.success = false;
                response.message =
                    'At least one value must be provided: ' +
                    'firstYearServiceCharge or isServiceChargePaid.';

                return response;
            }

            List<Handover_Details__c> handoverDetailsList = [
                SELECT Id,
                       First_Year_Service_Charge__c,
                       Is_Service_Charge_Paid__c,
                       Business_Process__r.Sales_Order__r.Unit__r.Name
                FROM Handover_Details__c
                WHERE Business_Process__r.Sales_Order__r.Unit__r.Name =
                    :requestData.unitName
                LIMIT 2
            ];

            if (handoverDetailsList.isEmpty()) {
                restResponse.statusCode = 404;
                response.success = false;
                response.message =
                    'No Handover Details record found for Unit Name: ' +
                    requestData.unitName;

                return response;
            }

            /*
             * Avoid updating an incorrect record if duplicate Handover Details
             * records exist for the same Unit Name.
             */
            if (handoverDetailsList.size() > 1) {
                restResponse.statusCode = 409;
                response.success = false;
                response.message =
                    'Multiple Handover Details records were found for Unit Name: ' +
                    requestData.unitName;

                return response;
            }

            Handover_Details__c handoverDetails =
                handoverDetailsList[0];

            Boolean hasChanges = false;

            // Update only when a non-null value is received
            if (requestData.firstYearServiceCharge != null) {
                handoverDetails.First_Year_Service_Charge__c =
                    requestData.firstYearServiceCharge;

                hasChanges = true;
            }

            if (requestData.isServiceChargePaid != null) {
                handoverDetails.Is_Service_Charge_Paid__c =
                    requestData.isServiceChargePaid;

                hasChanges = true;
            }

            if (hasChanges) {
                update handoverDetails;
            }

            restResponse.statusCode = 200;

            response.success = true;
            response.message = 'Handover Details updated successfully.';
            response.handoverDetailsId = handoverDetails.Id;
            response.unitName = requestData.unitName;
            response.firstYearServiceCharge =
                handoverDetails.First_Year_Service_Charge__c;
            response.isServiceChargePaid =
                handoverDetails.Is_Service_Charge_Paid__c;

            return response;

        } catch (System.JSONException ex) {
            restResponse.statusCode = 400;
            response.success = false;
            response.message =
                'Invalid JSON request: ' + ex.getMessage();

            return response;

        } catch (DmlException ex) {
            restResponse.statusCode = 500;
            response.success = false;
            response.message =
                'Unable to update Handover Details: ' +
                ex.getDmlMessage(0);

            return response;

        } catch (Exception ex) {
            restResponse.statusCode = 500;
            response.success = false;
            response.message =
                'Unexpected error: ' + ex.getMessage();

            return response;
        }
    }
}